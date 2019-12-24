IMPLEMENTATION MODULE RsrcAcquire;



    (*
        Rsrc Acquire - Acquire a resource record

            This module, given "columns" of information, attempts to find
            an existing resource record or create a new record with appropriate
            defaults.


        Terminology:

            For this module, we view the Rsrc Tree as if it were a giant TABLE
            of records, where each resource is a ROW in the table.  Each FIELD
            in a resource record is a COLUMN in the table.


        Procedure Overview:

            AnalyzeRsrcColumn()

                    Look at each column being read in from a file to see if
                    we have the columns needed to determine if the record
                    exists.

            AnalyzeRsrcResult()

                    This inquires as to what was found out from
                    "AnalyzeRsrcColumn".  Its use is optional, used mainly to
                    override decisions about using existing resources and
                    parantage.

            AcquireRsrc()

                    Resets the user-defined default columns.  When a record
                    is created, SYSTEM defaults are applied, then any user-
                    defined columns are applied.

            ResetDefaultRsrcColumns()

                    Reset default resource columns.  Default columns are used
                    whenever we create a resource.

            DefaultRsrcColumn()

                    Set a default resource column.  The next time a resource
                    record is created, all default columns are applied first,
                    and then the resource is ready for changes.


        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Undo:

            This module uses Undo to add and change records.  It does not begin
            or end the undo transaction.  The intent is that clients will:

                Begin Undo Transaction
                    Call RsrcAquire to get    the resource
                    Call RsrcChange to change the resource
                End Undo Transaction.


        Modification History:


         15-Feb-89  RSC  First version.
          4-Jun-89  EGK  Changed NotifyUndo calls into SendNotices calls.
          6-Sep-89  MWP  Added proc to test whether a column is needed
                         for editing. Does not grab the column value.
          6-Sep-89  MWP  If resource name is not supplied, abort the process.
          6-Oct-89  MWP  When analyzing data for control column information,
                         log the resource name.
                         This could have caused a fatal error!
         17-Oct-90  AJL  Remove unused import of the Rsrc ModuleNumber from
                         MagicNum.
    *)

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear, Copy, SetLengthOf, LengthOf,
                            StringsEqual, Upshift,  SetString, ConcatLS;

FROM   MagicNum     IMPORT
    (* TYPES *)             RsrcName,
                            RsrcFullName,          RsrcKeyword,
                            RsrcNotes,             RsrcType,
                            RsrcDefaultLimit,      RsrcDefaultPercent,
                            RsrcLevelingLimit,     RsrcLevelingPercent,
                            RsrcRate,              RsrcUnitCost,
                            RsrcUnitOfMeasure,     RsrcBaselineRate,
                            RsrcLevelingPermitted, RsrcLastColumn;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage, ConcatMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM ObjectID       IMPORT
    (* PROC *)              NewID;

FROM RsrcChange     IMPORT
    (* VAR *)               CurrentRsrcName,
    (* TYPE *)              ARsrcEditContext, AWhatsBeenSeenSet,
    (* PROC *)              ChangeRsrcRecord;

FROM RsrcMod        IMPORT
    (* CONST *)             ResourceNameLength,
    (* TYPES *)             AResourcePointer,   
                            ResourceTree,       AResourceType,
    (* PROCS *)             CreateResource,     ChangedResource,
                            FindResourceByName, AddResource,
                            InitializeResource, FindResourceByNumber,
                            DeleteResource;


FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;



TYPE

    AnIdentifyingColumn      = ( TaskWBS, ResourceName );

    ASetOfIdentifyingColumns = SET OF AnIdentifyingColumn;

    AnLString                = ARRAY [0..99] OF CHAR;

VAR
    DefaultRsrcNode         : ATreeNode;

    RsrcEditContext         : ARsrcEditContext;
    WhatWeveGot             : ASetOfIdentifyingColumns;
    KeyValues               : ARRAY AnIdentifyingColumn OF AnLString;

    NilString               : ARRAY [0..1] OF CHAR;





(*
    Analyze Rsrc Column

        Preconditions
                        > ColumnID is within range for a resource column.
                        > ColumnData contains the data to be changed.

        Postconditions
                        > The data has been analized for usability in
                          defining a resource record to edit.
*)
PROCEDURE AnalyzeRsrcColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord );

    PROCEDURE GrabIt( WhatItIs : AnIdentifyingColumn );
    BEGIN
        WITH ColumnData DO
            TrimFront( StringValue );
            TrimRear(  StringValue );
            IF ( LengthOf ( StringValue ) > 0 ) THEN
               Copy( StringValue, CurrentRsrcName );

               INCL( WhatWeveGot, WhatItIs );
               Upshift(   StringValue );
               Copy( StringValue, KeyValues[ WhatItIs ] );
            END;
        END;
    END GrabIt;


BEGIN
    CASE ColumnID OF
        RsrcName :
            GrabIt( ResourceName );
    ELSE
    END;

END AnalyzeRsrcColumn;



PROCEDURE IsControllingColumn ( ColumnID    : CARDINAL ) : BOOLEAN;  (* 6-Sep-89 MWP *)
VAR
    ok : BOOLEAN;
BEGIN

    ok := FALSE;

    CASE ColumnID OF
        RsrcName :
            ok := TRUE;
    ELSE
    END;

    RETURN ( ok );

END IsControllingColumn;



(*
    Analyze Rsrc Result

        Preconditions
                        > All columns have been passed through
                          "AnalyzeTaskColumn".  If only some columns
                          have been examined, it may be possible to
                          tell if, say, parentage is available, but
                          finding existing tasks is not.  So, while
                          it is not strictly a precondition that all
                          columns have bee seen, you may get a
                          misleading result.


        Postconditions
                        > IntendedAction tells you what AcquireRsrc
                          would do if passed "DefaultRsrcAction".

                          This step is optional, and is intended for
                          clients like the outline importer who want
                          to do their own parental management.

                            IMPLEMENTATION NOTE:

                                As of Time Line Version 4.0, resources
                                do not have parents.  However, this facility
                                is here for future expansion.

*)
PROCEDURE AnalyzeRsrcResult( VAR IntendedAction : ARsrcActionSet );
VAR
   RsrcNode :  ATreeNode;
BEGIN
    IntendedAction := ARsrcActionSet{};

    IF (ResourceName IN WhatWeveGot) THEN
        RsrcNode := FindResourceByName (KeyValues[ ResourceName ] );


        IF (RsrcNode <> ATreeNode(NIL)) THEN
            INCL( IntendedAction, HookToParent ); (* We found one *)
        END;
    END;

END AnalyzeRsrcResult;



(*
    Acquire Rsrc

        Preconditions
                        > All columns have been passed through
                          "AnalyzeRsrcColumn"

                        > DesiredRsrcAction describes the policy to
                          follow regarding resource creation and parenting.

        Postconditions
                        > If TRUE is returned, a resource node is returned.

                        > If there was a system error, the ErrorHandler
                          is called, and FALSE is returned.

                        > Undo is called to notify it of the Add or Change.
                          The client must start and end the Undo transaction.
*)
PROCEDURE AcquireRsrc( VAR RsrcNode          : ATreeNode;
                           DesiredRsrcAction : ARsrcActionSet;
                           ErrorHandler      : AnErrorHandlerProc;
                           HandlersContext   : ADDRESS          )  : BOOLEAN;
VAR
    ok              : BOOLEAN;
    ResourcePtr     : AResourcePointer;
BEGIN

    IF ( NOT ( ResourceName IN WhatWeveGot ) ) THEN                (* 6-Sep-89 MWP *)
          ok := ErrorHandler( ConnectionError,
                              ResourceNotFound,
                              0,
                              NilString,
                              HandlersContext );
          RETURN FALSE;
    END;

    RsrcNode := ATreeNode(NIL);

    IF (ResourceName IN WhatWeveGot) AND
       (NOT (CreateRsrc IN DesiredRsrcAction)) THEN
        RsrcNode := FindResourceByName (KeyValues[ ResourceName ] );
    END;

    IF (RsrcNode = ATreeNode(NIL)) THEN      (* None found yet? *)
       ok := CreateResource( RsrcNode );

       IF (RsrcNode = ATreeNode(NIL)) THEN      (* No memory? *)
          ok := ErrorHandler( SystemError,
                              NoMemoryForEdit,
                              0,
                              NilString,
                              HandlersContext );
          RETURN FALSE;
       END;

       ResourcePtr := RsrcNode^.Methods^.GetDataObject (RsrcNode);

       InitializeResource( ResourcePtr );

       ResourcePtr^.ID := CARDINAL( NewID() );

       (* For now, I am not giving the resource any family *)

       AddResource (RsrcNode, NIL,
                    ResourceTree^.Methods^.GetLast( ResourceTree ));
    END;

    SendNotices (ChangeAResource, BeforeActing, RsrcNode);   (* 6/4/89 EGK *)

    WhatWeveGot := ASetOfIdentifyingColumns{};

    RETURN TRUE;

END AcquireRsrc;



PROCEDURE ErrorHandlerProc( Severity        : AnErrorSeverity;
                            ErrorKind       : AKindOfError;
                            ColumnID        : CARDINAL;
                        VAR ErrorText       : ARRAY OF CHAR;
                            MyContext       : ADDRESS
                        ) : BOOLEAN;         (* Continue?         *)
BEGIN
    RETURN TRUE;  (* Fix it if you can. *)
END ErrorHandlerProc;





(*
    Reset Default Rsrc Columns

        Reset the default values for resource columns.

        Preconditions
                        > none.

        Postconditions
                        > The next resource that is created will have all
                          of its fields set to the system defaults, not
                          any client defaults.
*)
PROCEDURE ResetDefaultRsrcColumns();
VAR
    ok  : BOOLEAN;
BEGIN
    IF (DefaultRsrcNode <> ATreeNode(NIL)) THEN
        DeleteResource( DefaultRsrcNode );     (* Delete the old one. *)
    END;
    ok := CreateResource( DefaultRsrcNode );
    WITH RsrcEditContext DO
        ErrorHandler      := ErrorHandlerProc;
        HandlersContext   := NIL;
        WhatsBeenSeen     := AWhatsBeenSeenSet{};
    END;
END ResetDefaultRsrcColumns;





(*
    Default Rsrc Column

        Sets up defaults for resource columns.  These defaults are used
        whenever creating a new resource.

        Preconditions
                        > Column ID is within range

                        > ColumnData is properly formatted for the column
                          being defined.

        Postconditions
                        > Any resource that is created has values applied
                          in this order:

                                System defaults
                                Client defaults, defined with this procedure
                                Any edits given to RsrcEdit.

                        > Reset this action with "ResetDefaultRsrcColumns"
*)
PROCEDURE DefaultRsrcColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
VAR
    ResourcePtr : AResourcePointer;
    ok      : BOOLEAN;
BEGIN
    ok := FALSE;
    IF (DefaultRsrcNode <> ATreeNode(NIL)) THEN

        ResourcePtr := DefaultRsrcNode^.Methods^.GetDataObject (DefaultRsrcNode);
        ok := ChangeRsrcRecord( ColumnID,   ResourcePtr,
                                ColumnData, RsrcEditContext );
    END;
    RETURN ok;
END DefaultRsrcColumn;


BEGIN

    WhatWeveGot := ASetOfIdentifyingColumns{};
    SetLengthOf( NilString, 0 );
    DefaultRsrcNode := ATreeNode(NIL);
    ResetDefaultRsrcColumns();

END RsrcAcquire.

