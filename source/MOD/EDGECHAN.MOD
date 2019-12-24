IMPLEMENTATION MODULE EdgeChange;


    (*
        Edge Change - Edit an edge record

            This module provides the ability to make changes to an edge
            record by changing "columns" of data.  It deals with the same
            columns as are output by the "Captions" module.  For this reason,
            this module and its cousins are sometimes refered to as
            "AntiCaptions".


        Terminology:

            A Column HEADING is the formal name a column goes by.  This is the
            name found in a Lotus, DBase, or CSV file.  This heading is
            translated into a ColumnID, a "magic number" used to identify the
            column.  Note that some exporters, notably DBase, may translate
            the official formal name into a new name that is more compatible
            with the external program.  It is the importer's job to translate
            those names BACK into the "official" formal name.


        Procedure Overview:

            GetEdgeColumnID()   Given a column's formal name, return the
                                internal Column ID.

            BeginEdgeEdit()     Start the editing of an edge.

            DigestEdgeString()  Change a text string into an internal format.

            ChangeEdgeColumn()  Change the value of a column.

            EndEdgeEdit()       End the editing of an edge, and commit the
                                changes if there were no serious errors.


        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Undo:

            This module does not use Undo.  It is the job of clients to
            back out records deemed not valid.


        Related Modules:

            EdgeAcquire  is used to find the edge record to be edited.
            TaskEdit     edits task records.
            AssEdit      edits assignment records.
            RsrcEdit     edits resource records.


        Modification History:


         13-Mar-89  MWP  First version.
         24-Apr-89  AJL  Removed four fields from edge records:
                         EdgeToPlus, EdgeToDuration, EdgeToTime and EdgeToScale.
                         These are no longer in the internal edge record.
         13-Jul-89  MWP  Removed ToTaskID and FromTaskID column support.
         27-Jul-89  MWP  If we have received the From Duration in hours, do
                         not overwrite it with FromTime and FromUnits. ( Except
                         if the duration is 0, then set the units to minutes.
                         This appears to be the default anyway. )
         10-Sep-89  MWP  Removed unnecessary calls to error handler.
         14-Sep-89  MWP  Use RealTimeToDuration to figure out From Dur.
         30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.

    *)

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord, AColumnInfoChoice,
                            AColumnDataField,  ASetOfColumnDataFields;

FROM Dialog         IMPORT
    (* PROC *)              FatalError;

FROM Edges          IMPORT
    (* TYPE *)              AnEdgePtr,
                            CreateEdge, ItDepends, FindEdge, AddEdge;

FROM EdgeFormat     IMPORT
    (* PROCS *)             GetEdgeInfo;

FROM EditCommon     IMPORT
    (* TYPE *)              AGetInfoProc,
    (* PROC *)              GetAColumnID, AjustName,
    (* PROC *)              DigestAIntString;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear,  Copy,     SetLengthOf,
                            StringsEqual, SetString, LengthOf, Upshift,
                            SubStr,       Search;

FROM IntFileIO      IMPORT
                            AnIntDataRecord;

FROM MagicNum       IMPORT
                            EdgeModuleNumber, EdgeFromTaskName,
                            EdgeFromTaskWBS,  EdgeToTaskName,
                            EdgeToTaskWBS,    EdgeFromStart,
                            EdgeFromDuration, EdgeFromTime,
                            EdgeFromScale,    EdgeFromPlus,
                            EdgeToStart,      EdgeToPlus,
                            EdgeToDuration,   EdgeToTime,
                            EdgeToScale;

FROM Matches        IMPORT
    (* PROC *)              MatchADurationUnit;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM Timei          IMPORT
    (* TYPE *)              ADuration, ADurationUnit;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;

FROM WorkHours      IMPORT
    (* PROCS *)             RealTimeToDuration;

CONST
    MAXCARDINAL             = 65535;
    FMAXCARDINAL            = 65535.0;
    Zero                    = 0.0;

TYPE
    AGlobalContext          = RECORD
                                 FromEdgeNode      : ATreeNode;
                                 ToEdgeNode        : ATreeNode;
                                 Edge              : AnEdgePtr;
                                 ContextReady      : BOOLEAN;
                                 EditError         : BOOLEAN;
                                 StateInfo         : AEdgeEditContext;
                              END;

VAR
    GlobalContext           : AGlobalContext;
    NilString               : ARRAY [0..1] OF CHAR;
    FromTimeVar             : REAL;
    TempScale               : ADurationUnit;


(*
    Get Edge Column ID

        Preconditions
                        > "ColumnName" is an LString containing the FORMAL
                          NAME of the edge column.
                          The caller must resolve any differences between
                          the name read in from a file and the "official"
                          formal name.  For example, DBase translates some
                          charactors.

        Postconditions
                        > Returns TRUE if the ColumnName is a known edge
                          column name, or FALSE if it is unknown.

                        > ColumnID is the internal number to use for
                          changing the data, if TRUE is returned.
*)
PROCEDURE GetEdgeColumnID( VAR ColumnName       : ARRAY OF CHAR;
                           VAR ColumnID         : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN GetAColumnID( AGetInfoProc(GetEdgeInfo), ColumnName, ColumnID );
END GetEdgeColumnID;


(*
    Begin Edge Edit

        Preconditions
                        > No edge is currently being edited (close off an edit
                          with EndEdgeEdit)

                        > FromTask and ToTask are the TreeNodes for the two
                          tasks involved.  There must be an edge already
                          existing between the two tasks.

                        > ErrorHandler is the procedure to be called when an
                          edit error occurs.

        Postconditions
                        > Edge is ready to be edited.
*)
PROCEDURE BeginEdgeEdit(     FromNode,
                             ToNode          : ATreeNode;
                             LErrorHandler    : AnErrorHandlerProc;
                             LHandlersContext : ADDRESS          );
BEGIN

    WITH GlobalContext DO

        IF ( FromNode = ATreeNode(NIL) ) OR
           ( ToNode = ATreeNode(NIL) ) THEN
           ContextReady := FALSE;
           EditError    := TRUE;
           RETURN;
        END;

        FromEdgeNode      := FromNode;
        ToEdgeNode        := ToNode;

        IF ( ItDepends( FromNode, ToNode ) ) THEN
           Edge := FindEdge ( FromNode, ToNode );
        ELSE
           Edge := CreateEdge ( FromNode, ToNode );
           AddEdge ( Edge, TRUE );
        END;

        IF ( Edge = NIL ) THEN
           ContextReady := FALSE;
           EditError    := TRUE;
           RETURN;
        END;

        EditError         := FALSE;
        ContextReady      := TRUE;

        TempScale := Edge^.FromOffset.Scale;

        WITH StateInfo DO
            ErrorHandler          := LErrorHandler;
            HandlersContext       := LHandlersContext;
            WhatsBeenSeen         := AWhatsBeenSeenSet{};
        END;
    END;
END BeginEdgeEdit;


(*
    Digest Edge String

        Convert a text string into the internal data record needed by
        "ChangeEdgeColumn".

        Preconditions
                        > "ColumnID" is a valid column id.

                        > "TextString" is the string to be digested into
                          "ColumnData".  It is not modified (VAR only for
                          efficiency).

                        > "Amount Format" is the real number format to use
                          in analizing REAL numbers.  It is not altered.
                          VAR is just for efficiency.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty text string.
                          This is not allowed for all columns.

        Postconditions
                        > "ColumnData" is the data to be applied to the
                          edge.

                        > The text is checked within the context of the
                          column in question, and the "ColumnData" record
                          is filled in appropriately.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error above "NoError" will cause FALSE
                          to be returned.  Errors would all be simple formatting
                          errors.

                        > Returns TRUE if there were no formatting errors,
                          FALSE if there were.
*)
(*********
PROCEDURE DigestEdgeString(     ColumnID     : CARDINAL;
                            VAR TextString   : ARRAY OF CHAR;
                            VAR AmountFormat : AnAmountFormat;
                            VAR ColumnData   : AColumnDataRecord;
                                LErrorHandler    : AnErrorHandlerProc;
                                LHandlersContext : ADDRESS          ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAString( AGetInfoProc(GetEdgeInfo),  ColumnID,
                               TextString,   AmountFormat,
                               ColumnData,
                               LErrorHandler,
                               LHandlersContext );

   IF ( NOT EditError ) THEN
       GlobalContext.EditError := TRUE;
   END;

   RETURN EditError;
END DigestEdgeString;
**********)

PROCEDURE DigestIntEdgeString(     ColumnID         : CARDINAL;
                                   Type             : CARDINAL;
                               VAR Data             : AnIntDataRecord;
                               VAR AmountFormat     : AnAmountFormat;
                               VAR ColumnData       : AColumnDataRecord;
                                   LErrorHandler    : AnErrorHandlerProc;
                                   LHandlersContext : ADDRESS  ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAIntString( AGetInfoProc(GetEdgeInfo),
                                  ColumnID,
                                  Type,
                                  Data,
                                  AmountFormat,
                                  ColumnData,
                                  LErrorHandler,
                                  LHandlersContext );

   IF ( NOT EditError ) THEN
       GlobalContext.EditError := TRUE;
   END;

   RETURN EditError;
END DigestIntEdgeString;


(*
    Change Edge Column

        Preconditions
                        > An Edge is being edited (BeginEdgeEdit has been
                          called).

                        > "ColumnID" is a valid column id.

                        > "ColumnData" is the data to be applied to the edge.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty "DataFields" inside
                          "ColumnData".  This is not allowed for all columns.

        Postconditions
                        > The data is checked within the context of the
                          column in question, and the changes are applied,
                          except as noted below.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error above "NoError" will cause FALSE
                          to be returned.

                        > If TRUE is returned, it is implied that no errors
                          have yet been detected.  A call to EndEdgeEdit MIGHT
                          succeed, unless other errors are encountered.

                        > If FALSE is returned, no further edits will
                          be accepted (further calls to "ChangeEdgeColumn"
                          will return FALSE).  The changes should be ABORTED
                          by the caller.
*)
PROCEDURE ChangeEdgeColumn(     ColumnID    : CARDINAL;
                            VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) AND  (* Ignore? *)
           (NOT EditError)                                     THEN

            EditError := ChangeEdgeRecord( ColumnID,
                                           Edge,
                                           ColumnData,
                                           StateInfo );
        END;
    END;

    RETURN GlobalContext.EditError;

END ChangeEdgeColumn;




PROCEDURE ChangeEdgeRecord(     ColumnID    : CARDINAL;
                                EdgePtr     : AnEdgePtr;
                            VAR ColumnData  : AColumnDataRecord;
                            VAR Context     : AEdgeEditContext
                           ) : BOOLEAN;
VAR
    Junk        : BOOLEAN;
    EditError   : BOOLEAN;

    PROCEDURE Assume( Field : AColumnDataField ) : BOOLEAN;
    VAR
        LocalError : BOOLEAN;
    BEGIN
        IF (NOT (Field IN ColumnData.DataFields)) THEN
            Junk      := Context.ErrorHandler( SeriousError,
                                               DataFieldsWrong,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            RETURN FALSE;
        END;

        RETURN TRUE;

    END Assume;

    PROCEDURE DoBoolean ( VAR Bool : BOOLEAN );
    BEGIN
        IF (Assume( BooleanInUse )) THEN
            WITH ColumnData DO
               IF (BooleanValue) THEN
                  Bool := TRUE;
               ELSE
                  Bool := FALSE;
               END;
            END;
        END;
    END DoBoolean;

    PROCEDURE DoDuration ( VAR Dur : ADuration );
    BEGIN
        IF (Assume( DurationInUse )) THEN
            WITH ColumnData DO
               Dur := DurationValue;
            END;
        END;
    END DoDuration;


    PROCEDURE RtoC( R : REAL; VAR C : CARDINAL ) : BOOLEAN;
    BEGIN
        IF (R > FMAXCARDINAL) OR (R < Zero) THEN
            EditError := Context.ErrorHandler( FormatError,
                                               NumberOutOfRange,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            RETURN FALSE;
        ELSE
            C := TRUNC( R + 0.5 );
        END;

        RETURN TRUE;

    END RtoC;



    PROCEDURE DoScale ( VAR Scale : ADurationUnit ) : BOOLEAN;
    VAR
        ok        :  BOOLEAN;
        TempScale : ADurationUnit;
        i         : CARDINAL;
    BEGIN
        ok := FALSE;

        IF ( Assume( StringInUse ) ) THEN
           ok := MatchADurationUnit( ColumnData.StringValue, 1, TempScale, i );

           IF ( NOT ok ) THEN
              Junk      := Context.ErrorHandler( FormatError,
                                                 EnumerationWrong,
                                                 ColumnID,
                                                 NilString,
                                                 Context.HandlersContext );
           ELSE
              Scale := TempScale;
           END;
        END;

        RETURN ok;

    END DoScale;

BEGIN
    WITH Context DO
        EditError := FALSE;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) THEN
            WITH EdgePtr^ DO
                WITH ColumnData  DO
                    CASE ColumnID OF

                        EdgeFromStart          :
                           DoBoolean ( FromOffset.Start );

                      | EdgeFromPlus           :
                           DoBoolean ( FromOffset.Plus );

                      | EdgeFromDuration       :

                           IF (Assume( RealInUse )) THEN
                                FromOffset.Dur := RealTimeToDuration ( RealValue,
                                                                       Hours );
                                INCL( Context.WhatsBeenSeen, FromDur );
                           END;

                      | EdgeFromTime           :

                           IF (Assume( RealInUse )) THEN
                               FromTimeVar :=  RealValue;
                               INCL( Context.WhatsBeenSeen, FromTime );
                           END;

                      | EdgeFromScale          :

                           (* Use this as the actual units. *)
                           IF (DoScale ( FromOffset.Scale ) ) THEN
                              INCL( Context.WhatsBeenSeen, FromUnits );
                           END;

                      | EdgeToStart            :
                           DoBoolean ( ToOffset.Start );
                    ELSE
                    END;
                END;
            END;
        END;
    END;


    RETURN EditError;

END ChangeEdgeRecord;


(*
    End Edge Edit

        Preconditions
                        > An edge is being edited (BeginEdgeEdit has been
                          called).

        Postconditions
                        > Any changes made to the edge after BeginEdgeEdit
                          have been applied to the edge node, or else the
                          ErrorHandler is called for each exception found.

                        > If any errors were found that were not fixable, or
                          where the error handler decided not to request
                          fixing, FALSE is returned.  Otherwise, TRUE is
                          returned.
*)
PROCEDURE EndEdgeEdit() : BOOLEAN;
BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        ContextReady := FALSE;

        WITH StateInfo DO

            IF ( FromTime  IN WhatsBeenSeen ) AND
               ( FromUnits IN WhatsBeenSeen)  AND
               ( NOT ( FromDur IN WhatsBeenSeen) ) THEN         (* 27-Jul-89 MWP *)
                WITH Edge^ DO
                     FromOffset.Dur := RealTimeToDuration ( FromTimeVar,
                                                            FromOffset.Scale );
                END;
            END;
        END;
    END;

    RETURN (NOT GlobalContext.EditError);

END EndEdgeEdit;


BEGIN
    GlobalContext.ContextReady := FALSE;
    SetLengthOf ( NilString, 0 );

END EdgeChange.
