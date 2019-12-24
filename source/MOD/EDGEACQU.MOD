IMPLEMENTATION MODULE EdgeAcquire;



    (*
        Edge Acquire - Acquire an edge record

            This module, given "columns" of information, attempts to find
            an existing edge record or create a new record with appropriate
            defaults.


        Procedure Overview:

            AnalyzeEdgeColumn()

                    Look at each column being read in from a file to see if
                    we have the columns needed to determine if the record
                    exists.

            AcquireEdge()

                    Once "AnalyzeEdgeColumn" is called for each available
                    column, this is used to actually create or find an edge.

            ResetDefaultEdgeColumns()

                    Resets the user-defined default columns.  When a record
                    is created, SYSTEM defaults are applied, then any user-
                    defined columns are applied.

            DefaultEdgeColumn()

                    Set a default edge column.  The next time an edge
                    record is created, all default columns are applied first,
                    and then the edge is ready for changes.


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
                    Call EdgeAquire to get    the edge
                    Call EdgeChange to change the edge
                End Undo Transaction.


        Modification History:


         15-Mar-89  MWP  First version.
          4-Jun-89  EGK  Added SendNotice calls to CreateOrFindEdge.
         13-Jul-89  MWP  Removed references to ToTaskID and FromTaskID.
          6-Sep-89  MWP  Added proc to test whether a column is needed
                         for editing. Does not grab the column value.
         12-Sep-89  MWP  IMporved testing for controlling columns existence.
         19-Sep-89  MWP  If no To WBS code found, we were logging the
                         wrong error message to the journal.
         22-Sep-89  MWP  If the To WBS code is not found, don't tell the
                         user we could not find the resource.
          3-Oct-89  MWP  Save the WBS codes, so that during warning or
                         error messages, we can tell the user which  edge
                         is at fault.
         16-Oct-89 MWP   Implemented faster searching for finding an existing
                         task to edit.
         16-Nov-89 MWP   When we find a key column, do not force it to upper
                         case.
    *)

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord;

FROM EdgeChange     IMPORT
                            FromWBSCode,
                            ToWBSCode,
    (* TYPE *)              AEdgeEditContext, AWhatsBeenSeenSet;

FROM Edges          IMPORT
    (* TYPE *)              AnEdgePtr,
                            CreateEdge, ItDepends, FindEdge, AddEdge;

FROM EditCommon     IMPORT
    (* PROC *)              FindTaskWithWBS;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear,  Copy,     SetLengthOf,
                            StringsEqual, SetString, LengthOf, Upshift,
                            SubStr,       Search;

FROM MagicNum       IMPORT
                            EdgeModuleNumber, EdgeFromTaskName,
                            EdgeFromTaskWBS,  EdgeToTaskName,
                            EdgeToTaskWBS,    EdgeFromStart,
                            EdgeFromDuration, EdgeFromTime,
                            EdgeFromScale,    EdgeFromPlus,
                            EdgeToStart,      EdgeToPlus,
                            EdgeToDuration,   EdgeToTime,
                            EdgeToScale;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM TaskDictionary IMPORT
                            IsInDict, DictionaryInUse;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;


FROM Undo           IMPORT
    (* TYPE *)              AnUndoableObject, AnUndoAction,
    (* PROC *)              NotifyUndo;


TYPE

    AnIdentifyingColumn      = ( FromTaskWBS, ToTaskWBS );

    ASetOfIdentifyingColumns = SET OF AnIdentifyingColumn;

    AnLString                = ARRAY [0..99] OF CHAR;

VAR
    DefaultEdgeNode         : ATreeNode;
    EdgeEditContext         : AEdgeEditContext;
    WhatWeveGot             : ASetOfIdentifyingColumns;
    WhatWeveSeen            : ASetOfIdentifyingColumns;
    KeyValues               : ARRAY AnIdentifyingColumn OF AnLString;

    NilString               : ARRAY [0..1] OF CHAR;

(*
    Analyze Edge Column

        Preconditions
                        > ColumnID is within range for an edge column.
                        > ColumnData contains the data to be changed.

        Postconditions
                        > The data has been analized for usability in
                          defining an edge record to edit.
*)
PROCEDURE AnalyzeEdgeColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord );

    PROCEDURE GrabIt( WhatItIs  : AnIdentifyingColumn;
                      IsFromWBS : BOOLEAN );
    BEGIN
        WITH ColumnData DO
            TrimFront( StringValue );
            TrimRear(  StringValue );
            IF ( LengthOf ( StringValue ) > 0 ) THEN
               IF ( IsFromWBS ) THEN
                   Copy ( StringValue, FromWBSCode );
               ELSE
                   Copy ( StringValue, ToWBSCode );
               END;
(*
               Upshift(   StringValue );
*)
               INCL( WhatWeveGot, WhatItIs );
               Copy( StringValue, KeyValues[ WhatItIs ] );
            END;
        END;
    END GrabIt;


BEGIN

    CASE ColumnID OF
        EdgeFromTaskWBS :
            GrabIt( FromTaskWBS, TRUE );

     |  EdgeToTaskWBS :
            GrabIt( ToTaskWBS, FALSE );

    ELSE
    END;

END AnalyzeEdgeColumn;


PROCEDURE IsControllingColumn ( ColumnID    : CARDINAL ) : BOOLEAN;  (* 6-Sep-89 MWP *)
VAR
    ok : BOOLEAN;
BEGIN

    ok := FALSE;

    CASE ColumnID OF
        EdgeFromTaskWBS  :
               INCL( WhatWeveSeen, FromTaskWBS );
               ok := TRUE;
     |  EdgeToTaskWBS :
               INCL( WhatWeveSeen, ToTaskWBS );
               ok := TRUE;
    ELSE
    END;


    RETURN ( ok );

END IsControllingColumn;


PROCEDURE AreAllControlsPresent () : BOOLEAN;
VAR
    ok : BOOLEAN;
BEGIN
    ok := ( WhatWeveSeen = ASetOfIdentifyingColumns{FromTaskWBS, ToTaskWBS} );

    WhatWeveSeen := ASetOfIdentifyingColumns{};

    RETURN ( ok );

END AreAllControlsPresent;



PROCEDURE CreateOrFindEdge(     FromNode,
                                ToNode        : ATreeNode;
                            VAR Edge          : AnEdgePtr ) : BOOLEAN;
VAR
    ok               : BOOLEAN;

BEGIN

    ok := TRUE;

    IF (ItDepends( FromNode, ToNode )) THEN
        Edge := FindEdge ( FromNode, ToNode );
    ELSE
        Edge := CreateEdge ( FromNode, ToNode );
        IF (Edge = NIL) THEN
            ok := FALSE;
        ELSE
            AddEdge (Edge, TRUE);
            SendNotices (AddAnEdge, AfterActing, Edge);    (* 6/4/89 EGK *)
        END;
    END;

    IF ( ok ) THEN
        IF (Edge = NIL) THEN
            ok := FALSE;
        ELSE
            SendNotices (ChangeAnEdge, BeforeActing, Edge);   (* 6/4/89 EGK *)
        END;
    END;

    RETURN ok;

END CreateOrFindEdge;


(*
    Acquire Edge

        Preconditions
                        > All columns have been passed through
                          "AnalyzeEdgeColumn"

        Postconditions
                        > If TRUE is returned, FromNode and ToNode
                          are the predecessor and successor tasks,
                          respectively.

                        > If there was a system error, or if the two
                          joined tasks could not be found, then the
                          ErrorHandler is called, and FALSE is returned.

                        > Undo is called to notify it of the Add or Change.
                          The client must start and end the Undo transaction.
*)
PROCEDURE AcquireEdge( VAR FromNode,
                           ToNode            : ATreeNode;
                           ErrorHandler      : AnErrorHandlerProc;
                           HandlersContext   : ADDRESS          )  : BOOLEAN;
VAR
    Junk,
    ok              : BOOLEAN;
    EdgeNode  : AnEdgePtr;
BEGIN

    FromNode := ATreeNode(NIL);
    ToNode   := ATreeNode(NIL);

    ok := (WhatWeveGot = ASetOfIdentifyingColumns{FromTaskWBS, ToTaskWBS} );

    IF (NOT ok) THEN
        IF (NOT (FromTaskWBS IN WhatWeveGot)) THEN
            Junk := ErrorHandler( ConnectionError,
                                  MissingTaskID,
                                  0,
                                  NilString,
                                  HandlersContext );
        END;

        IF (NOT (ToTaskWBS IN WhatWeveGot)) THEN
            Junk := ErrorHandler( ConnectionError,
                                  MissingTaskID,                  (* 19-Sep-89 MWP *)
                                  0,
                                  NilString,
                                  HandlersContext );
        END;

    ELSE
        (* Step 1:  Find the From task record by WBS *)

        IF ( DictionaryInUse ) THEN                                 (* 16-Oct-89 MWP *)
           ok := IsInDict ( KeyValues[ FromTaskWBS ], FromNode );
        ELSE
           FindTaskWithWBS( KeyValues[ FromTaskWBS ], FromNode );
        END;

        ok := (FromNode <> NIL);

        IF (NOT ok) THEN
            Junk := ErrorHandler( ConnectionError,
                                  TaskNotFound,
                                  0,
                                  NilString,
                                  HandlersContext );
        ELSE

            (* Step 2:  Find To Task record. *)

            IF ( DictionaryInUse ) THEN                                 (* 16-Oct-89 MWP *)
                 ok := IsInDict ( KeyValues[ ToTaskWBS ], ToNode );
            ELSE
                 FindTaskWithWBS( KeyValues[ ToTaskWBS ], ToNode );
            END;

            ok := (ToNode <> NIL);

            IF (NOT ok) THEN
                Junk := ErrorHandler( ConnectionError,
                                      TaskNotFound,               (* 20-Sep-89 MWP *)
                                      0,
                                      NilString,
                                      HandlersContext );
            END;
        END;
    END;

 (* Here, if "ok", we have both from and to tasks.  Find the appropriate
    edge, or create one.
 *)
    IF (ok AND (NOT CreateOrFindEdge( FromNode, ToNode, EdgeNode ))) THEN
        Junk := ErrorHandler( ConnectionError,
                              RecCannotBeCreated,
                              0,
                              NilString,
                              HandlersContext );
        ok   := FALSE;
    END;

    WhatWeveGot   := ASetOfIdentifyingColumns{};
    WhatWeveSeen  := ASetOfIdentifyingColumns{};

    RETURN ok;

END AcquireEdge;

(*
    Reset Default Edge Columns

        Reset the default values for edge columns.

        Preconditions
                        > none.

        Postconditions
                        > The next edge that is created will have all
                          of its fields set to the system defaults, not
                          any client defaults.
*)
PROCEDURE ResetDefaultEdgeColumns();
BEGIN
END ResetDefaultEdgeColumns;


(*
    Default Edge Column

        Sets up defaults for edge columns.  These defaults are used
        whenever creating a new edge.

        Preconditions
                        > Column ID is within range

                        > ColumnData is properly formatted for the column
                          being defined.

        Postconditions
                        > Any edge that is created has values applied
                          in this order:

                                System defaults
                                Client defaults, defined with this procedure
                                Any edits given to EdgeEdit.

                        > Reset this action with "ResetDefaultEdgeColumns"
*)
PROCEDURE DefaultEdgeColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
BEGIN
    RETURN FALSE;
END DefaultEdgeColumn;


BEGIN
    WhatWeveGot  := ASetOfIdentifyingColumns{};
    WhatWeveSeen := ASetOfIdentifyingColumns{};
    SetLengthOf( NilString, 0 );
    DefaultEdgeNode := ATreeNode(NIL);
END EdgeAcquire.
