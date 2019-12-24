IMPLEMENTATION MODULE Allocs;

    (* MODIFICATION HISTORY

       Dec. 4, 1985, AJL - Expanded size of some text buffers.
       May  1, 1986  LAA - Changes notes and summarizes to AText.
       May  9, 1986  LAA - Changed CopyText to copy texts along with the
                           other fields.
       May  6, 1987  RSC - Removed references to "PlannedDates", as these
                           have been removed from the record.
       May 11, 1987  RSC - Made RemoveAssignmentsAndExpenses exportable.
       May 12, 1987  EGK - Create task tree in initialization section.
       28-May-87 LAA    Moved the creation of the task tree into the
                        InitializeAllocs procedure.  Removed all usage of the
                        task list.
       Jun  5, 1987  RSC - Added BaseLine to "CopyAssignments".  Added both
                           assignment summaries to the task record initialization.
       Jun 17, 1987  RSC - Added explicit procedures "InitializeTaskRecord" and
                           "CopyOneAssignmentWithSpeed".  Initialized
                           "BaseLineSummary" and BigTime.
       20-Jun-87 LAA    Commented out call to TimeUtoT, because it's wrong to
                        call that procedure before TLINIT has done its thing.
        9-Jul-87 RSC    Removed references to MustStartBy/MustEndBy.
       14-Sep-87 EGK    Added AddTask, RemoveTask, AddEdge, RemoveEdge
                        procedures.  These are designed to separate the
                        user interface routines from those which just
                        manipulate the task tree and the chart state.
       13-Oct-87 RSC    Added BCWSDollars to task record as per AJL.
       30-Oct-87 RSC    Bumped up default priority from 2 to 20, so it comes
                        out as 2.0 on the task form.
        8-Dec-87 RSC    Converted tasks to flexstor.
       28-Dec-87 LAA    In DeleteEdges, the task ptr had been used after it
                        was unlocked.  Also set all task ptr's to NIL after
                        they are unlocked.
       11-Jan-88 LAA    Changed UnlockFlexStorDataObject to UnlockUnchanged
                        where appropriate.
       19-Jan-88 AJL    Changed calls to HeapAvailable to Space.Available.
                        This because Planner creates phantom nodes even when
                        space is low.
       28-Jan-88 RSC    Ajusted Andrews change, above, to properly deallocate
                        a task tree node if the flexstor allocation fails.
        9-Feb-88 RSC/LAA   In CreateTaskWithSpeed, simplified the boolean
                           expression in an effort to help Logitek's compiler.
       23-Feb-88 LAA    Put up an error box instead of a message when trying
                        to create an edge between tasks which are already
                        joined.
        2-Mar-88 AJL/LAA modified RemoveEdge to call FatalError if there
                         is an edge that references a task that doesn't
                         link to that edge.
       10-Aug-88 AJL    -Added extra debugging code controlled by the DEBUG
                         version toggle.
       10-Jan-89 RSC    -Changed Storage to Space.
       05-May-89 EGK     Changed InitializeTaskRecord to set the Coding
                         text to NIL; removed references to WBS, OBS, and AUX.
       25-May-89 EGK     Changed DelTask and RemoveTaskData to get rid of
                         the Coding text when they delete tasks.
       21-Aug-89 RSC     Added check in CreateTaskWithSpeed() to make sure
                         that there is room for the task being added to the
                         model by inquiring ExtStatus.  If Status is GOOD,
                         then we can add to the model.
       31-Aug-89 RSC     Don't create a text record for coding fields unless
                         the coding field is non-blank.
       15-Sep-89 MWP     If a coding field string is empty, and the text
                         record exists, update the coding field.
       21-Feb-90 KKC     Remove all unreferenced id from Timeu.
       29-May-90 AJL     Import ACostPlace from Accruals.  
       07-Jun-90 AJL     Reinstalled references to MinDate. 
       11-Sep-90 RSC     Fixed up as per AJL's changes to Allocs.Def
        9-Oct-90 AJL   - Added SequenceNumber.
     26-Mar-91   AJL - Added QueryNumberOfTasks.
     24-Apr-91   AJL   - Changed QueryNumberOfTasks to only return tasks
                         in the TaskTree.
     22-May-91   EGK     Add LateIndStart and LateIndEnd to the set of
                         dates initialized by InitializeTaskRecord.
    *)

FROM Accruals               IMPORT
    (* TYPE *)                  ACostPlace;

FROM AsOf           IMPORT
        (* VAR *)       AsOfDate;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)                  RemoveAssignmentsAndExpenses,
                                CopyOneAssignmentWithSpeed;

FROM BigTimeU        IMPORT
   (* TYPES *)           ABigTime,
   (* VAR   *)           MINBIGTIME;

FROM Chart                  IMPORT
    (* VAR *)                   GanttChart, CursorTask,
    (* PROC *)                  ChartNotifyDeleted;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog          IMPORT
   (* PROCS *)           NotYetImplemented, Message, Error, FatalError, Burp;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr,
    (* PROC *)                  RemoveEdge;

FROM FilterRc               IMPORT
    (* PROC *)                  FiltersNotifyDeleted;

FROM FlexStor        IMPORT
   (* TYPES *)           AnExtHandle, AnExtStoragePreference,
                         AnExtStatus,
   (* PROCS *)           HandleIsValid, DiscardExtObject, GetExtStatus,
                         CopyExtObject, CreateExtObjectWithSize,
                         LockObjectArray, ReleaseObject, ReleaseUnchangedObject;

FROM LStrings        IMPORT
   (* PROCS *)           SetString, SubStr, TrimRear, ConcatS, ConcatLS,
                         Compare, Fill, CtoS, SetLengthOf, LengthOf, Copy;

FROM MsgFile         IMPORT
   (* PROCS *)           GetMessage, DisplayMessage, ConcatMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM RsrcMod         IMPORT
   (* TYPES *)           AResourcePointer,
   (* PROCS *)           CheckResourceValid;

FROM Space           IMPORT
  (* PROCS *)            ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM          IMPORT
  (* TYPES *)            ADDRESS,
  (* PROCS *)            TSIZE, ADR;

FROM Text            IMPORT
  (* TYPES *)            AText,
  (* PROCS *)            TextExists, DiscardText, AssignText, CreateText,
                         CopyLine, AssignLine;

FROM Timei           IMPORT
  (* TYPES *)            ADurationUnit,
  (* CONST *)            MinDate, NoDuration;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode, ATreeOrder, ATree,
    (* PROC *)          CreateTree, CreateTreeNode, ValidateTreeNode;



(*<TRACE
FROM Codes  IMPORT    ACode, ASetOfCodes;
FROM Dialog IMPORT MessageBox;
FROM Kbio   IMPORT KeyPress, GetAnyCode;
FROM FlexDisp IMPORT HandleToString;
TRACE>*)


CONST
    ModuleNumber = 0700;  (* For GetMessage *)
    TaskRecTag = 111; (* Code confirms that this is a task record. *)
    ResourceNodeTag = 17171;

    Zero = 0.0;  (* Because Logitek cares *)

    MAXDATE    = 65535;

    MinSpace   = 500;   (* Minimum Heap Space we'll tolerate. *)

VAR
    InitFlag  : BOOLEAN;
    CheckDepth : CARDINAL;
    NumberOfTasks : CARDINAL;




 (* Make a copy of the assignments and expenses array *)

PROCEDURE CopyAssignments(FromNode, ToNode:ATreeNode);

VAR
    FromTask                : ATaskPtr;
    ToTask                  : ATaskPtr;
    FromHandle,
    BFromHandle,
    ToHandle,
    BToHandle               : AnExtHandle;

BEGIN

    FromTask    := FromNode^.Methods^.LockFlexStorDataObject(FromNode);
    FromHandle  := FromTask^.Plan.Assignments;
    BFromHandle := FromTask^.BaseLine.Assignments;
    FromNode^.Methods^.UnlockUnchangedDataObject(FromNode);       (* 11-Jan-88 LAA *)
    FromTask    := NIL;                                           (* 28-Dec-87 LAA *)

    CopyOneAssignmentWithSpeed( FromHandle ,
                                ToHandle   , ExtMedium );
    CopyOneAssignmentWithSpeed( BFromHandle,
                                BToHandle  , ExtSlow );
    ToTask   :=   ToNode^.Methods^.LockFlexStorDataObject(ToNode);
    ToTask^.Plan.Assignments     := ToHandle;
    ToTask^.BaseLine.Assignments := BToHandle;
    ToNode^.Methods^.UnlockFlexStorDataObject( ToNode );
    ToTask   := NIL;                                              (* 28-Dec-87 LAA *)

END CopyAssignments;



(*----------------------------------------------------------------------------
   RemoveTaskData --

    Remove the resources and texts from the given task.
----------------------------------------------------------------------------*)

PROCEDURE RemoveTaskData(    TaskNode       : ATreeNode);

VAR
    Task                    : ATaskPtr;
    Handle,
    BHandle                 : AnExtHandle;
    NotesText               : AText;
    SummarizesText          : AText;
    CodingText              : AText;

BEGIN                         (* RemoveTaskData *)

    Task           := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Handle         := Task^.Plan.Assignments;
    BHandle        := Task^.BaseLine.Assignments;
    NotesText      := Task^.notes;
    SummarizesText := Task^.summarizes;
    CodingText     := Task^.Coding;
    Task^.Plan.Assignments     := AnExtHandle(NIL);
    Task^.BaseLine.Assignments := AnExtHandle(NIL);
    Task^.notes                := AText(NIL);
    Task^.summarizes           := AText(NIL);
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    Task := NIL;                                                  (* 28-Dec-87 LAA *)

    RemoveAssignmentsAndExpenses( Handle  );
    RemoveAssignmentsAndExpenses( BHandle );
    DiscardText( NotesText      );
    DiscardText( SummarizesText );
    DiscardText( CodingText     );              (* 5/25/89 EGK *)

END RemoveTaskData;



    (* COPYTASK -- Copy fields from one task to another, but not
                   the links. *)

PROCEDURE  CopyTask (SourceTask:ATreeNode; DestTask:ATreeNode );

VAR
    TempTask                : ATask;
    DTask                   : ATaskPtr;
    STask                   : ATaskPtr;
    s                       : ARRAY [0..81] OF CHAR;

BEGIN
    CheckTaskValid(DestTask);
    RemoveTaskData(DestTask);

    (* Save off the source task *)

    STask                := SourceTask^.Methods^.LockFlexStorDataObject( SourceTask );
    TempTask             := STask^; (* Make a copy of the task. *)
    SourceTask^.Methods^.UnlockUnchangedDataObject( SourceTask ); (* 11-Jan-88 LAA *)
    STask := NIL;                                                 (* 28-Dec-87 LAA *)

    (* Set up the dest task *)

    DTask               := DestTask^.Methods^.LockFlexStorDataObject( DestTask );
    TempTask.rectag     := DTask^.rectag;
    TempTask.antetasks  := DTask^.antetasks;   (* Restore the links. *)
    TempTask.desctasks  := DTask^.desctasks;
    TempTask.Prevlink   := DTask^.Prevlink;
    TempTask.Nextlink   := DTask^.Nextlink;
    TempTask.WorkSpace  := DTask^.WorkSpace;
    DTask^              := TempTask;       (* And save the modified source *)
    IF NOT AssignText(TempTask.notes, DTask^.notes) THEN
        GetMessage(ModuleNumber + 30, s);
        Error(s);
    END;
    IF NOT AssignText(TempTask.Coding, DTask^.Coding) THEN      (* 5/3/89 EGK *)
        GetMessage(ModuleNumber + 30, s);
        Error(s);
    END;
    IF NOT AssignText(TempTask.summarizes, DTask^.summarizes) THEN
        GetMessage(ModuleNumber + 30, s);
        Error(s);
    END;

    DestTask^.Methods^.UnlockFlexStorDataObject( DestTask );
    DTask := NIL;                                                 (* 28-Dec-87 LAA *)

    CopyAssignments(SourceTask, DestTask);

END CopyTask;




  (* InitializeTaskRecord - Initialize one task record's contents to
                            0, NIL, Spaces, and whatever else seems
                            appropriate.

       Preconditions  - The Task record has no valid data in it.  That is,
                        it does not have ALLOCATEd spaces that could be lost
                        by this procedure.  It is as if you just said this:
                        NEW(TaskPtr);
                        InitializeTaskRecord( TaskPtr^ );

       Postconditions - The task record has all its values initialized.
                        Pointers are set to NIL, counters to 0 or 0.0,
                        Other special fields initialized to some "empty"
                        value as appropriate.

      DANGER!!  When updating the definition of ATask, be sure to add all
                new fields into this procedure so that the fields are set
                to some reasonable start value.  This way, tasks can be
                created from different areas (Task form, importing, etc),
                and all come out OK.
  *)

PROCEDURE InitializeTaskRecord( VAR Task : ATask );
VAR
    TempDateBlock  : ADateBlock;
    s               : ARRAY [0..10] OF CHAR;

BEGIN

    WITH TempDateBlock DO
       EarlyStart     := MinDate;
       EarlyEnd       := MinDate;
       LateFreeStart  := MinDate;
       LateFreeEnd    := MinDate;
       LateTotalStart := MinDate;
       LateTotalEnd   := MinDate;
       LateIndStart   := MinDate;       (* 22-May-91 EGK *)
       LateIndEnd     := MinDate;
    END;

    WITH Task DO
        rectag                  := TaskRecTag;
        SetLengthOf(taskname, 0);
        antetasks               := NIL;
        desctasks               := NIL;
        notes                   := AText(NIL);
        summarizes              := AText(NIL);
        TaskFlags               := ATaskFlagSet{};
        TaskStatusSet           := ATaskStatusSet{NeedsRecalculate};
        count                   := 0;
        count2                  := 0;
        WorkSpace               := NIL;
        Prevlink                := AnExtHandle(NIL);
        Nextlink                := AnExtHandle(NIL);
        DurationMethod          := DurationDriven;
        XX                      := 0;
        YY                      := 0;
        PercentComplete         := 0;
        fixation                := FixedDate;
        TaskID                  := 0;
        TaskSortOrder           := 0;
        priority                := 20; (* RSC 10/30/87 *)
        duration                := NoDuration;
        scale                   := Days;
        EffortScale             := Days;
        FilterSet               := ATaskFilterSet{};
        StartStatus             := FutureS;
        rollupstatus            := NotRollup;
        Coding                  := AText(NIL);      (* 5/3/89 EGK *)
        ToGoSummary.Time        := Zero;
        ToGoSummary.Amount      := Zero;
        CompletedSummary.Time   := Zero;
        CompletedSummary.Amount := Zero;
        BaseLineSummary.Time    := Zero;
        BaseLineSummary.Amount  := Zero;
        CostPlace               := 0C;
        Plan.Dates              := TempDateBlock;
        BaseLine.Dates          := TempDateBlock;
        BaseLine.Assignments    := AnExtHandle( NIL );
        Plan.Assignments        := AnExtHandle( NIL );
        BCWSDollars             := Zero;  (* RSC 10/13/87 *)
        BCWP                    := Zero;  (* RSC  2/01/88 *)
        SplittingRule           := Delay;
        UserEnteredStartDate    := MINBIGTIME;  (* 11-Sep-90 RSC  *)
        UserEnteredEndDate      := MINBIGTIME;  (* 11-Sep-90 RSC  *)
        SupposedToStart         := MINBIGTIME;  (* 11-Sep-90 RSC  *)
        SequenceNumber          := 0;
    END;

END InitializeTaskRecord;




  (* CreateTask - This procedure creates a new Task record and initializes it.
                  It sticks it into a TreeNode.  It does not insert it into
                  the TaskTree.

                  21-Aug-89 RSC  Check ExtStatus to make sure we can add
                                 to the model.
  *)

PROCEDURE CreateTaskWithSpeed( Speed : AnExtStoragePreference ) : ATreeNode;

VAR
    NewTaskNode             : ATreeNode;
    NewTask                 : ATaskPtr;
    Handle                  : AnExtHandle;
BEGIN
    NewTaskNode := NIL;

    IF (Available(MinSpace)) AND
       (GetExtStatus() = ExtGood) AND  (* RSC 21-Aug-89 *)
       (CreateTreeNode(NewTaskNode)) THEN
        IF (CreateExtObjectWithSize( Handle, Speed, TSIZE( ATask ) )) THEN
            NewTaskNode^.Methods^.SetDataObject(NewTaskNode, ADDRESS(Handle));
            NewTask := NewTaskNode^.Methods^.LockFlexStorDataObject( NewTaskNode );
            InitializeTaskRecord( NewTask^ );
            NewTaskNode^.Methods^.UnlockFlexStorDataObject( NewTaskNode );
            NewTask := NIL;  (* 28-Dec-87 LAA *)
            INC(NumberOfTasks);
        ELSE
            NewTaskNode^.Methods^.Discard(NewTaskNode);
            NewTaskNode := NIL;  (* Just to be sure! *)
        END;
    END;

    RETURN NewTaskNode;

END CreateTaskWithSpeed;



  (* CreateTask - This procedure creates a new Task record and initializes it.
                  It sticks it into a TreeNode.  It does not insert it into
                  the TaskTree.  Speed defaults to MEDIUM.
  *)

PROCEDURE CreateTask() : ATreeNode;
BEGIN
    RETURN CreateTaskWithSpeed( ExtMedium );
END CreateTask;









PROCEDURE AddTask   (   NewTask         : ATreeNode;
                        ParentTask      : ATreeNode;
                        PriorTask       : ATreeNode     );
BEGIN
    IF (PriorTask <> NIL) THEN
        PriorTask^.Methods^.AddAfter (PriorTask, NewTask);
    ELSIF (ParentTask <> NIL) THEN
        ParentTask^.Methods^.AddAsFirstChild (ParentTask, NewTask);
    ELSE
        TaskTree^.Methods^.AddFirst (TaskTree, NewTask);
    END;
    SendNotices (AddATask, AfterActing, NewTask);        (* 6/4/89 EGK *)
END AddTask;




PROCEDURE RemoveTask(   VAR TaskNode        : ATreeNode     );
BEGIN
    FiltersNotifyDeleted (TaskNode);
    DeleteEdges (TaskNode);
    SendNotices (DeleteATask, BeforeActing, TaskNode);       (* 6/4/89 EGK *)
    TaskNode^.Methods^.DeList (TaskNode);
    GanttChart^.Methods^.NotifyNodeDeleted(GanttChart, TaskNode);
    ChartNotifyDeleted (TaskNode);
    DelTask (TaskNode);
END RemoveTask;




PROCEDURE DeleteEdges   (TaskNode : ATreeNode);

VAR
    EdgePtr                    : AnEdgePtr;
    DEdge                   : AnEdgePtr;
    Task                    : ATaskPtr;
    EdgeToGo                : AnEdgePtr;

BEGIN

    CheckTaskValid(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    EdgePtr := Task^.antetasks;
    DEdge := Task^.desctasks;                                     (* 28-Dec-87 LAA *)
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );     (* 11-Jan-88 LAA *)
    Task := NIL;                                                  (* 28-Dec-87 LAA *)

    WHILE (EdgePtr <> NIL) DO
        EdgeToGo := EdgePtr;
        EdgePtr := EdgePtr^.taillink;
        SendNotices (DeleteAnEdge, BeforeActing, EdgeToGo);       (* 6/4/89 EGK *)
        RemoveEdge (EdgeToGo);
    END;

    EdgePtr := DEdge;                                                (* 28-Dec-87 LAA *)
    WHILE (EdgePtr <> NIL) DO
        EdgeToGo :=EdgePtr;
        EdgePtr := EdgePtr^.headlink;
        SendNotices (DeleteAnEdge, BeforeActing, EdgeToGo);       (* 6/4/89 EGK *)
        RemoveEdge (EdgeToGo);
    END;

END DeleteEdges;





    (* DELTASK -- Remove a task. *)

PROCEDURE DelTask( VAR TaskNode : ATreeNode );

VAR
    Plan,
    BaseLine           : AnExtHandle;
    Task               : ATaskPtr;
    Notes,
    Summary,
    Coding             : AText;

BEGIN
    CheckTaskValid(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);

    BaseLine := Task^.BaseLine.Assignments;
    Plan     := Task^.Plan.Assignments;
    Notes    := Task^.notes;
    Summary  := Task^.summarizes;
    Coding   := Task^.Coding;
    TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);      (* 11-Jan-88 LAA *)
    Task     := NIL;                                              (* 28-Dec-87 LAA *)

        (* Remove any resource attachments. *)

    RemoveAssignmentsAndExpenses( BaseLine );
    RemoveAssignmentsAndExpenses( Plan     );

        (*  Discard all the texts pointed to by this task *)

    DiscardText(Notes);
    DiscardText(Summary);
    DiscardText(Coding);
    DeleteEdges(TaskNode);

    DiscardTask(TaskNode, NIL); (* And delete the task. *)

END DelTask;





PROCEDURE DiscardTask(VAR TaskNode          : ATreeNode;
                          Context           : ADDRESS  );
VAR
    Handle : AnExtHandle;
BEGIN                       (* DiscardTask *)

    Handle := AnExtHandle(TaskNode^.Methods^.GetDataObject(TaskNode));
    DiscardExtObject( Handle );
    TaskNode^.Methods^.Discard(TaskNode);

    DEC(NumberOfTasks);

END DiscardTask;




PROCEDURE FindTaskByNumber( MatchID  : INTEGER ) : ATreeNode;
VAR
    Task     : ATaskPtr;
    TaskNode : ATreeNode;
    TaskID   : INTEGER;
BEGIN
    TaskNode := TaskTree^.Methods^.GetFirst(TaskTree);
    LOOP
        IF (TaskNode = NIL) THEN
            EXIT;
        END;
        Task   := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        TaskID := Task^.TaskID;
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);   (* 11-Jan-88 LAA *)
        Task   := NIL;                                            (* 28-Dec-87 LAA *)

        IF (TaskID = MatchID) THEN
            EXIT;
        END;
        TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode);
    END;
    RETURN TaskNode;
END FindTaskByNumber;

(*<DEBUG


PROCEDURE CheckAssignmentsValid( Assignments : AnExtHandle );
VAR
    Count, i : CARDINAL;
    AssignmentArray     : AnAssignmentArray;
    Resource            : AResourcePointer;
BEGIN
    INC(CheckDepth);
    IF (Assignments = AnExtHandle(NIL)) THEN RETURN; END;
    Count := LockObjectArray(Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));
    IF (Count > 0) THEN
        FOR i := 0 TO Count-1 DO
            Resource := AssignmentArray^[i].Resource;
            CheckResourceValid(Resource);
        END;
    END;
    ReleaseUnchangedObject(Assignments);
    DEC(CheckDepth);

END CheckAssignmentsValid;

DEBUG>*)





PROCEDURE XCheckTaskValid(TaskNode:ATreeNode);

VAR
    Task                    : ATaskPtr;
    Edge                    : AnEdgePtr;
BEGIN
    IF (TaskNode = NIL) THEN FatalError(); END;
    ValidateTreeNode(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    IF (Task^.rectag <> TaskRecTag) THEN FatalError END;

    (*<DEBUG

        (* Debugging 2/2/88 AJL  *)
    INC(CheckDepth);
    IF (CheckDepth <= 1) THEN
        Edge := Task^.desctasks;
        LOOP
            IF (Edge = NIL) THEN
                EXIT;
            ELSE
                IF (Edge^.headtask <> TaskNode) THEN FatalError(); END;
            END;
            Edge := Edge^.headlink;
        END;
        Edge := Task^.antetasks;
        LOOP
            IF (Edge = NIL) THEN
                EXIT;
            ELSE
                IF (Edge^.tailtask <> TaskNode) THEN FatalError(); END;
            END;
            Edge := Edge^.taillink;
        END;
        CheckAssignmentsValid(Task^.Plan.Assignments);
        CheckAssignmentsValid(Task^.BaseLine.Assignments);
    END;

    DEC(CheckDepth);

    DEBUG>*)


    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);       (* 11-Jan-88 LAA *)
END XCheckTaskValid;



(*******
PROCEDURE SetCodingField (  VAR Task    : ATask;
                                LineNo  : CARDINAL;
                            VAR s       : ARRAY OF CHAR );
VAR
    LocalString     : ARRAY [0..255] OF CHAR;
    OK              : BOOLEAN;
BEGIN
    Copy(s, LocalString );
    TrimRear( LocalString );

    IF (LengthOf( LocalString ) <> 0) THEN
        WITH Task DO
            IF (NOT TextExists (Coding)) THEN
                Coding := CreateText();
            END;
            OK := AssignLine (s, LineNo, Coding);
        END;
    END;

END SetCodingField;
********)

PROCEDURE SetCodingField (  VAR Task    : ATask;                (* 15-Sep-89 MWP *)
                                LineNo  : CARDINAL;
                            VAR s       : ARRAY OF CHAR );
VAR
    LocalString     : ARRAY [0..255] OF CHAR;
    OK              : BOOLEAN;
BEGIN
    Copy(s, LocalString );
    TrimRear( LocalString );

    OK := TRUE;

    WITH Task DO
        IF (NOT TextExists (Coding)) THEN
            IF ( LengthOf( LocalString ) <> 0 ) THEN
                Coding := CreateText();
            ELSE
                OK := FALSE;
            END;
        END;

        IF ( OK ) THEN
           OK := AssignLine (s, LineNo, Coding);
        END;
    END;

END SetCodingField;




PROCEDURE GetCodingField (  VAR Task    : ATask;
                                LineNo  : CARDINAL;
                            VAR s       : ARRAY OF CHAR );

BEGIN
    WITH Task DO
        CopyLine (Coding, LineNo, s);
    END;
END GetCodingField;



    (* InitializeAllocs -- If the module has not yet been initialized, do so. *)

PROCEDURE InitializeAllocs;
VAR
    StartStatus : AStartStatus;
    Fixation    : AFixType;
BEGIN
    IF (InitFlag) THEN RETURN; END;

    FOR StartStatus := FutureS TO DoneS DO
        GetMessage(ModuleNumber+10+ORD(StartStatus),  StartStatusName[StartStatus] );
    END;

    FOR Fixation := FixedDate TO Span DO
        GetMessage(ModuleNumber+20+ORD(Fixation),  FixationName[Fixation] );
    END;

    IF (NOT CreateTree (TaskTree)) THEN
        FatalError ();
    END;

    InitFlag := TRUE;

END InitializeAllocs;


PROCEDURE AddOne  (VAR TaskTreeNode : ATreeNode;
                       Context      : ADDRESS);
VAR
    Count : POINTER TO CARDINAL;
BEGIN
    Count := Context;
    INC(Count^);
END AddOne;



    (* Returns the number of tasks that exist in the task tree.   This
       may be different from the total tasks created, because the Undo
       system could have tasks also.  *)

PROCEDURE QueryNumberOfTasks(): CARDINAL;
VAR
    Count : CARDINAL;
BEGIN
    Count := 0;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    AddOne, ADR(Count));
    RETURN Count;
END QueryNumberOfTasks;


BEGIN
    InitFlag := FALSE;
    CheckDepth := 0;
    TaskTree := NIL;
    CheckTaskValid := XCheckTaskValid;
    NumberOfTasks := 0;
END Allocs.

