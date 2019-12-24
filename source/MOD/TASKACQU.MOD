IMPLEMENTATION MODULE TaskAcquire;


    (*
        Task Acquire - Acquire a task record

            This module, given "columns" of information, attempts to find
            an existing task record or create a new record with appropriate
            defaults.


        Terminology:

            For this module, we view the Task Tree as if it were a giant TABLE
            of records, where each TASK is a ROW in the table.  Each FIELD in
            a task record is a COLUMN in the table.


        Procedure Overview:

            AnalyzeTaskColumn()

                    Look at each column being read in from a file to see if
                    we have the columns needed to determine if the record
                    exists.

            AnalyzeTaskResult()

                    This inquires as to what was found out from
                    "AnalyzeTaskColumn".  Its use is optional, used mainly to
                    override decisions about using existing tasks and
                    parentage.

            AcquireTask()

                    Once "AnalyzeTaskColumn" is called for each available
                    column, this is used to actually create or find a task.

            ResetDefaultTaskColumns()

                    Resets the user-defined default columns.  When a record
                    is created, SYSTEM defaults are applied, then any user-
                    defined columns are applied.

            DefaultTaskColumn()

                    Set a default task column.  The next time a task record
                    is created, all default columns are applied first, and
                    then the task is ready for changes.


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
                    Call TaskAquire to get    the task
                    Call TaskChange to change the task
                End Undo Transaction.


        Modification History:


         15-Feb-89  RSC  First version.
          4-Jun-89  EGK  Removed unnecessary calls to NotifyUndo.
         12-Sep-89  MWP  Better handling of checking for presence of WBS
                         numbers, and creating orphan tasks.
         14-Sep-89  MWP  Fixed bug where Orphan Node was not being placed
                         at bottom of import task tree.
          6-Oct-89  MWP  When analyzing data for control column information,
                         log the resource name.
                         This could have caused a fatal error!
         16-Oct-89 MWP   Implemented faster searching for finding an existing
                         task to edit.
         16-Nov-89 MWP   When we find a key column, do not force it to upper
                         case.
          5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
    *)

FROM Allocs         IMPORT
    (* TYPE *)              ATask,   ATaskPtr,
    (* VAR  *)              TaskTree,
    (* PROC *)              AddTask, DelTask, CreateTask, CopyTask;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord;

FROM EditCommon     IMPORT
    (* PROC *)              FindTaskWithWBS;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               ExportName;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear, Copy, SetLengthOf, ConcatLS,
                            StringsEqual, Upshift, SetString, LengthOf, CtoS;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM RTSMain        IMPORT
    (* PROCS *)             InstallTermProc;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR, TSIZE;



FROM TaskChange     IMPORT
    (* VAR *)               OrphanNode, CurrentTskNm,
    (* TYPE *)              ATaskEditContext, AWhatsBeenSeenSet,
    (* PROC *)              ChangeTaskRecord;

FROM TaskColNumbers IMPORT
    (* CONST *)             WBSColumn, ParentWBS, TaskNameColumn;

FROM TaskDictionary IMPORT
                            IsInDict, DictionaryInUse;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder;

FROM Undo           IMPORT
    (* TYPE *)              AnUndoableObject, AnUndoAction,
    (* PROC *)              NotifyUndo;

CONST
    ModuleNumber            = 6200;  (* Same as Tlitasks *)
    TLCaptionsModuleNumber  = 27300;  (* THIS IS SHARED WITH TLCAPTIONS!! *)


TYPE
    AnIdentifyingColumn      = ( TaskWBS, TheParentWBS, TaskNm );

    ASetOfIdentifyingColumns = SET OF AnIdentifyingColumn;

    (* Could be dangerous! What if the string is larger than a 100 chars.
       I know that is unlikely, but we don't want fatal errors, and
       we do not check this.
    *)
    AnLString                = ARRAY [0..99] OF CHAR;


VAR
    DefaultTaskNode         : ATreeNode;
    TaskEditContext         : ATaskEditContext;
    WhatWeveGot             : ASetOfIdentifyingColumns;
    KeyValues               : ARRAY AnIdentifyingColumn OF AnLString;
    NilString               : ARRAY [0..1] OF CHAR;
    UnNamedNumber           : CARDINAL;


(*
    Analyze Task Column

        Preconditions
                        > ColumnID is within range for a task column.
                        > ColumnData contains the data to be changed.

        Postconditions
                        > The data has been analized for usability in
                          defining a task record to edit.
*)
PROCEDURE AnalyzeTaskColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord );


    PROCEDURE GrabIt( WhatItIs   : AnIdentifyingColumn;
                      IsTaskName : BOOLEAN );
    BEGIN
        WITH ColumnData DO
            TrimFront( StringValue );
            TrimRear(  StringValue );

            IF ( LengthOf ( StringValue ) > 0 ) THEN
               IF ( IsTaskName ) THEN
                  Copy( StringValue, CurrentTskNm );
               ELSE
(*
                  Upshift(   StringValue );
*)
                  INCL( WhatWeveGot, WhatItIs );
                  Copy( StringValue, KeyValues[ WhatItIs ] );
               END;
            END;
        END;
    END GrabIt;


BEGIN
    CASE ColumnID OF

        WBSColumn :

            GrabIt( TaskWBS, FALSE );

      | ParentWBS :

            GrabIt( TheParentWBS, FALSE );

      | TaskNameColumn :
            GrabIt ( TaskNm, TRUE );
    ELSE
    END;

END AnalyzeTaskColumn;



PROCEDURE IsControllingColumn ( ColumnID    : CARDINAL ) : BOOLEAN;  (* 6-Sep-89 MWP *)
VAR
    ok : BOOLEAN;
BEGIN

    ok := FALSE;

    CASE ColumnID OF

        WBSColumn,
        ParentWBS,
        TaskNameColumn :
            ok := TRUE;
    ELSE
    END;

    RETURN ( ok );

END IsControllingColumn;


(*
    Analyze Task Result

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
                        > IntendedAction tells you what AcquireTask
                          would do if passed "DefaultTaskAction".

                          This step is optional, and is intended for
                          clients like the outline importer who want
                          to do their own parental management.
*)
PROCEDURE AnalyzeTaskResult( VAR IntendedAction : ATaskActionSet );
VAR
    TaskNode    : ATreeNode;
BEGIN

    IntendedAction := ATaskActionSet{CreateATask}; (* Assume no mom, no task *)

    IF (TaskWBS IN WhatWeveGot) THEN
        FindTaskWithWBS( KeyValues[ TaskWBS ], TaskNode );
        IF (TaskNode <> ATreeNode(NIL)) THEN
            EXCL( IntendedAction, CreateATask ); (* We found one *)
        END;
    END;

    IF (TheParentWBS IN WhatWeveGot) THEN
        FindTaskWithWBS( KeyValues[ TheParentWBS ], TaskNode );
        IF (TaskNode <> ATreeNode(NIL)) THEN
            INCL( IntendedAction, HookToParent ); (* We found one *)
        END;
    END;

END AnalyzeTaskResult;



(*
    Acquire Task

        Preconditions
                        > All columns have been passed through
                          "AnalyzeTaskColumn"

                        > DesiredTaskAction describes the policy to
                          follow regarding task creation and parenting.

        Postconditions
                        > If TRUE is returned, a task node is returned.

                        > If there was a system error, the ErrorHandler
                          is called, and FALSE is returned.

                        > Undo is called to notify it of the Add or Change.
                          The client must start and end the Undo transaction.
*)
PROCEDURE AcquireTask( VAR TaskNode          : ATreeNode;
                           DesiredTaskAction : ATaskActionSet;
                           ErrorHandler      : AnErrorHandlerProc;
                           HandlersContext   : ADDRESS          )  : BOOLEAN;
VAR
    PriorNode,
    ParentNode  : ATreeNode;
    TaskPtr     : ATaskPtr;
    ok          : BOOLEAN;
    s           : ARRAY [0..10] OF CHAR;
BEGIN

    TaskNode := ATreeNode(NIL);

    IF (TaskWBS         IN WhatWeveGot) AND
       (NOT (CreateATask IN DesiredTaskAction)) THEN
        IF ( DictionaryInUse ) THEN                                 (* 16-Oct-89 MWP *)
           ok := IsInDict ( KeyValues[ TaskWBS ], TaskNode );
        ELSE
           FindTaskWithWBS( KeyValues[ TaskWBS ], TaskNode );
        END;
    END;

    (* If we have a tasknode, we are updating an existing task. *)
    IF (TaskNode = ATreeNode(NIL)) THEN      (* None found yet? *)

        TaskNode := CreateTask();
        IF (TaskNode = ATreeNode(NIL)) THEN      (* No memory? *)
            ok := ErrorHandler( SystemError,
                                NoMemoryForEdit,
                                0,
                                NilString,
                                HandlersContext );
            RETURN FALSE;
        END;
        CopyTask( DefaultTaskNode, TaskNode );

        ParentNode := ATreeNode(NIL);

        PriorNode := ATreeNode(NIL);

        (* If WBS has been seen then by now it doesn't match an existing
           record's WBS. We have to look at the parent WBS condition
           to decide on further actions.
        *)
        IF ( TaskWBS IN WhatWeveGot ) THEN

            IF (TheParentWBS    IN WhatWeveGot) AND
               (HookToParent IN DesiredTaskAction) THEN
                IF ( DictionaryInUse ) THEN                         (* 16-Oct-89 MWP *)
                    ok := IsInDict ( KeyValues[ TheParentWBS ], ParentNode );
                ELSE
                    FindTaskWithWBS( KeyValues[ TheParentWBS ], ParentNode );
                END;
            END;


            (* We have a WBS code, and the parent matches, so add a new
               child to parent task.
            *)
            IF (ParentNode <> ATreeNode(NIL)) THEN
                PriorNode := ParentNode^.Methods^.LastChild( ParentNode );
            ELSE
               IF ( TheParentWBS IN WhatWeveGot  ) THEN
                   (* If we have a parent WBS, and by now we couldn't match the
                      WBS - it becomes an orphan. *)
                   SetupOrphan ( ParentNode, PriorNode );
               ELSE
                   (* If the parent was missing, but we have a WBS,
                      it becomes a top level task.
                   *)
                   PriorNode := TaskTree^.Methods^.GetLast( TaskTree );
               END;
            END;
        ELSE
           (* WBS code missing. Automatically becomes an orphan task. *)
           SetupOrphan ( ParentNode, PriorNode );
        END;

        AddTask( TaskNode, ParentNode, PriorNode );
    END;

    (* We did not see the task name in the import list. See if one exists
       in the task node. If it doesn't, create our own.
    *)
    IF ( LengthOf ( CurrentTskNm ) = 0 ) THEN
       TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
       IF ( LengthOf ( TaskPtr^.taskname ) = 0 ) THEN
           GetMessage( TLCaptionsModuleNumber + 11, TaskPtr^.taskname );
           CtoS ( UnNamedNumber, s );
           ConcatLS ( TaskPtr^.taskname, s );
           INC(UnNamedNumber);
       END;
       Copy ( TaskPtr^.taskname, CurrentTskNm );
       TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);
    END;

    WhatWeveGot := ASetOfIdentifyingColumns{};

    SendNotices (ChangeATask, BeforeActing, TaskNode);       (* 6/4/89 EGK *)

    RETURN TRUE;

END AcquireTask;


PROCEDURE  SetupOrphan ( VAR ParentNode : ATreeNode;
                         VAR PriorNode  : ATreeNode );
BEGIN
    IF ( OrphanNode = ATreeNode(NIL) ) THEN
        CreateOrphan ( OrphanNode );
    END;

    IF ( OrphanNode <> ATreeNode(NIL) ) THEN
       PriorNode  := OrphanNode^.Methods^.LastChild( OrphanNode );
       ParentNode := OrphanNode;
    END;

END SetupOrphan;


PROCEDURE  CreateOrphan ( VAR OrphanNode : ATreeNode);
VAR
    CurrentTask             : ATaskPtr;
    s, s1                   : ARRAY[0..255] OF CHAR;
BEGIN
     OrphanNode := ATreeNode(NIL);

     OrphanNode := CreateTask();

     IF ( OrphanNode <> ATreeNode(NIL) ) THEN
        CurrentTask := OrphanNode^.Methods^.LockFlexStorDataObject (OrphanNode);

        GetMessage ( ModuleNumber + 6, s );

        ConcatLS ( s, ExportName );

        IF ( LengthOf ( s ) > HIGH(CurrentTask^.taskname) ) THEN
           SetLengthOf ( s, HIGH(CurrentTask^.taskname) );
        END;

        Copy ( s, CurrentTask^.taskname );

        OrphanNode^.Methods^.UnlockFlexStorDataObject (OrphanNode);
        TaskTree^.Methods^.AddLast (TaskTree, OrphanNode);
     END;

END CreateOrphan;



(*
    Error Handler

        An error handler for the "Default" setting operations.  Fix anything
        possible.
*)
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
    Reset Default Task Columns

        Reset the default values for task columns.

        Preconditions
                        > none.

        Postconditions
                        > The next task that is created will have all of its
                          fields set to the system defaults, not any client
                          defaults.
*)
PROCEDURE ResetDefaultTaskColumns();
BEGIN
    IF (DefaultTaskNode <> ATreeNode(NIL)) THEN
        DelTask( DefaultTaskNode );     (* Delete the old one. *)
    END;
    DefaultTaskNode := CreateTask();    (* If no memory, this will be NIL *)
    WITH TaskEditContext DO
        ErrorHandler      := ErrorHandlerProc;
        HandlersContext   := NIL;
        NeedsRecalc       := FALSE;
        WhatsBeenSeen     := AWhatsBeenSeenSet{};
    END;

END ResetDefaultTaskColumns;



(*
    Default Task Column

        Sets up defaults for task columns.  These defaults are used whenever
        creating a new task.

        Preconditions
                        > Column ID is within range

                        > ColumnData is properly formatted for the column
                          being defined.

        Postconditions
                        > Any task that is created has values applied in this
                          order:

                                System defaults
                                Client defaults, defined with this procedure
                                Any edits given to TaskEdit.

                        > Reset this action with "ResetDefaultTaskColumns"

*)
PROCEDURE DefaultTaskColumn(     ColumnID    : CARDINAL;
                             VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
BEGIN
    RETURN TRUE;
END DefaultTaskColumn;




PROCEDURE TaskAcquireTerminate();
BEGIN
    IF (DefaultTaskNode <> ATreeNode(NIL)) THEN
        DelTask( DefaultTaskNode );     (* Delete the old one. *)
    END;
END TaskAcquireTerminate;


BEGIN

    OrphanNode := ATreeNode(NIL);
    WhatWeveGot := ASetOfIdentifyingColumns{};
    SetLengthOf( NilString, 0 );
    DefaultTaskNode := ATreeNode(NIL);
    ResetDefaultTaskColumns();
    InstallTermProc( TaskAcquireTerminate );
    UnNamedNumber := 1;

END TaskAcquire.

