IMPLEMENTATION MODULE Changer;

    (* MODIFICATION HISTORY

       10/13/87 - RSC - Removed old history (9/3/85 to 7/31/87)

        05-Aug-87 LAA   Added use of Named Layouts.
        03-Sep-87 RSC   Additional "simple" task form.  some moved fields.
        08-Sep-87 RSC   Set rollup status on F10.  Protect lots of fields on
                        rollup tasks.
        14-Sep-87 EGK   Rewrote lots of stuff to use new ALLOCS procedures
                        for manipulating tasks and edges underneath the
                        user interface, primarily for use by undo.
         2-Oct-87 RSC   Bug fixes: Turn resting cursor off for Editor returns.
                        Redisplay of calc'd units not proper.
                        On Duration change when start date is blank refresh
                            start date, not end date.
                        Move most init code from InitializeChanger() to
                        the initialization section of this module.
        13-Oct-87 RSC   Bug fixes and remove references to TaskOnTheForm for
                        conversion to EMS Task storage.  Also added Shadows
                        to boxes and decoupled StartStatus from %Achieved.
                        Added param to EditText
        20-Oct-87 RSC   Change scale being passed to AssForms to EffortScale.
        26-Oct-87 RSC   misc bug fixes (again), including detecting resources
                        on the task form to interlock against deletion, and
                        telling forms that something has changed when the
                        notes text is updated.
        28-Oct-87 RSC   After EGK made a small change (Set(Filtering)), I
                        split off the task link form into an overlay (TLLINK).
         3-Nov-87 RSC   Warn for deletion of task with baseline info.  Allow
                        deleting link info via DELETE or ALT/F9 on link field.
         6-Nov-87 RSC   Warn for altering % achieved when no baseline and there
                        is a parent task.  ARGHHHHH!
        25-Nov-87 AJL   Added special processing for end dates.
        16-Dec-87 LAA   Commented out DuplicateTask, which is not used.
        28-Dec-87 RSC   Made Spent and ToGo percentages percents of BaseLine,
                        and they can be from 0-9999 (was 3 digits)
        11-Jan-88 RSC   Split out task form stuff into TLChanger, in prep
                        for eventual conversion to an overlay.
                        Also, made stuff into UnlockUnchanged as possible.
        14-Jan-88 LAA   In EditEdge, adjust Dur so that it won't be rounded
                        up to a number > 4 digits.
        21-Jan-88 LAA   Added calls to HeapAvailable, since Allocs no longer
                        checks this.  Also made changes for forms base layer.
        22-Jan-88 RSC   Fixed up Larry's change.
        02-Feb-88 LAA   Removed use of LowFuel.
        03-Feb-88 LAA   Per EGK, put in fix to ChangeEdge to keep machine
                        from hanging when re-joining already joined tasks.
        25-Feb-88 RSC   Save old priority and effort scale for next inserted
                        task.  Update way we determine initial defaults.
        02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
        07-Mar-88 LAA   Make TLCHANGE go into the reserve layer.
        16-Aug-88 RSC   Change reference to TLChange to be TLAssgn.
                        TLAssgn will call TLChange.
                        Also fix the bug where a JOIN is attempted where
                        there is no cursor task.
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        2-Jan-89  RSC   Removed references to Compare() (not used).
        18-Apr-89 EGK   Added "AddTaskCopy" procedure.
        25-Apr-89 RSC   Removed "ResourceIsOnTaskForm"; made it a notice
                        ("ResourceDeleted") insted.  For Spreadsheet view.
        03-May-89 EGK   Changed MakeCopyOfTask to use the new scheme for
                        accessing the WBS code.
         4-Jun-89 EGK   Changed ResourceIsUsed to take a tree node instead
                        of a resource pointer.  Changed calls to NotifyUndo
                        into calls to SendNotices.
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        14-Aug-89 EGK   Moved ResourceIsUsed to a new module, "RsrcUsed".
         2-Oct-89 MWP   Provide confirmation of dependency assignments and
                        removals. This was imporperly placed in dispatch.mod.
         8-Nov-89 EGK   In UnjoinTasks, set the two tasks' status bits so
                        that their status will display as "?".
        13-Nov-89 EGK   Changed EditEdge so that it returns whether or not
                        the form data was changed, as well as what key was
                        used to leave the form.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        11-Apr-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.

        11-Sep-90 RSC   Fixups for Andrew's Allocs DEF changes.
        21-Feb-91 RSC   Change call to TLCHANGE to eliminate TLASSGN.
        28-Mar-91 TGS   Add SplittingRule to defaults when adding a task.
        22-May-91 EGK   Set initial values for LateIndStart and LateIndEnd
                        for a new task.  Also SupposedToStart.
    *)




FROM Allocs                 IMPORT
    (* CONST *)                 TskNmLen, WBSLine, WBSLen,
    (* VAR  *)                  TaskTree,
    (* TYPE *)                  ATaskPtr, ATask, ATaskFilterSet, ATaskFilter,
                                ATaskName, AFixType, ARollupStatus,
                                ATaskFlag, ADurationMethod,
                                ATaskFlagSet, AStartStatus, ASplittingRule,
                                AnAssignmentSummary, ATaskStatus, ATaskStatusSet,
    (* PROC *)                  CopyTask, DelTask, CheckTaskValid,
                                RemoveTaskData,
                                CreateTask, AddTask, SetCodingField,
                                InitializeTaskRecord, RemoveTask;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)                  RemoveAssignmentsAndExpenses;

FROM CalShift               IMPORT
    (* VAR *)                   TimeSheet;

FROM Chart                  IMPORT
    (* VAR *)                   BugTaskA, BugTaskB, BugDayB, BugDayA,
                                CursorTask, CursorDay,
    (* PROC *)                  MChTask, MChTaskAndDay, ChartNotifyDeleted,
                                GanttChart;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  SetState, UnSetState;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, FatalError, Error, Burp, WarningBox,
                                ContinuationBox, MultipleChoiceBox;

FROM Duration               IMPORT
    (* TYPE *)                  FindDuration, AddWorkingTime,
                                SubtractWorkingTime;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr, AnEdge,
    (* PROC *)                  ItDepends, CheckEdgeValid, FindEdge,
                                CreateEdge, AddEdge, DelEdge, RemoveEdge;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, CancelKey;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatS, ConcatLS, SubStr,
                                LengthOf, Overlay, LJust, TrimRear, Insert, Procustes,
                                CtoS, RJust, TrimFront, Copy, SetLengthOf;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM ObjectID               IMPORT
    (* PROC *)                  NewID;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Schedule               IMPORT
    (* VARS *)                  ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable;

FROM Timei                  IMPORT
    (* CONST*)                  MaxDate, MinDate,
    (* TYPE *)                  ADate, ADurationUnit, ADuration, ASetOfADurationUnit,
    (* PROC *)                  TimeUtoT, TtoTimeU;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH,
    (* PROC *)                  UpScale, DownScale, FindCorrectScale;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATree,
    (* PROC *)                  ValidateTreeNode;

FROM SYSTEM                 IMPORT
    (* THING *)                 ADDRESS, TSIZE, ADR;

FROM Undo                   IMPORT
    (* PROC *)                  AbortTransactionSet;

CONST
    ModuleNumber = 3500;    (* For GetMessage - SAME # AS TLCHANGE FOR NOW!! *)



VAR
    OldPriority             : CARDINAL;
    OldDuration             : ADuration;
    OldDate                 : ADate;
    OldFixation             : AFixType;
    OldEffortScale,
    OldDurationScale        : ADurationUnit;
    OldDurationMethod       : ADurationMethod;
    OldSplittingRule        : ASplittingRule;





PROCEDURE TaskForm( TaskNode : ATreeNode ) : ACode;
VAR
    TaskFormContext : ATaskFormContext;
    TaskFormOverlay : ARRAY [0..21] OF CHAR;
BEGIN
    SetString( TaskFormOverlay, "\TLFBASE(TLCHANGE)" ); (* 21-Feb-91 RSC  *)
    TaskFormContext.TaskNode := TaskNode;
    IF (NOT CallOverlayWithContext( TaskFormOverlay, ADR( TaskFormContext ) )) THEN
        TaskFormContext.Code := CancelKey;
    END;
    RETURN TaskFormContext.Code;
END TaskForm;




PROCEDURE CheckMemoryWarning;
VAR
    Title : ARRAY [0..51] OF CHAR;
    s     : ARRAY [0..255] OF CHAR;
BEGIN
    IF (NOT HeapAvailable()) THEN                                 (* 02-Feb-88 LAA *)
        GetMessage(ModuleNumber+5,Title);  (* "Low Memory" *)
        GetMessage(ModuleNumber+6,s);
                 (* "You have filled up most of memory.  Please save your schedule. *)
                 (* "(Press [Esc])" *)
        WarningBox(s,Title,NoHelp);
    END;
END CheckMemoryWarning;







PROCEDURE MakeNewTask ( ModelTask  : ATreeNode ) : ATreeNode;

VAR
    ProposedTask            : ATaskPtr;
    ProposedNode            : ATreeNode;
    ModelTaskPtr            : ATaskPtr;
    FixedStart              : ADate;

BEGIN
        (* Try to allocate some space to create a template. *)

    ProposedNode := CreateTask();
    IF (ProposedNode = NIL) THEN
        CheckMemoryWarning;
        RETURN NIL;
    END;

        (*  Fill in the task form.  *)
    ProposedTask := ProposedNode^.Methods^.LockFlexStorDataObject(ProposedNode);
    WITH ProposedTask^ DO
        scale                 := OldDurationScale;     (* Use the same scale as previous. *)
        EffortScale           := OldEffortScale;
        priority              := OldPriority;

        IF (OldFixation = ALAP) THEN   (* RSC 12/30/87 *)
            fixation          := ALAP;
        ELSE
            fixation          := ASAP;
        END;

        StartStatus           := FutureS;   (* RSC 9/25/87 *)
        DurationMethod        := OldDurationMethod; (* RSC 10/30/87 *)
        IF (DurationMethod = DurationDriven) THEN
            duration          := OldDuration;
        END;

        SplittingRule         := OldSplittingRule; (* 28-Mar-91 TGS *)

        TaskID       := NewID();

        IF (ModelTask = NIL) THEN
            CalendarTimeToBigTime( CursorDay, TRUE, UserEnteredStartDate ); (* 12-Sep-90 RSC  *)
        ELSE
            ModelTaskPtr := ModelTask^.Methods^.LockFlexStorDataObject(ModelTask);
            CalendarTimeToBigTime( ModelTaskPtr^.Plan.Dates.EarlyEnd, TRUE, UserEnteredStartDate ); (* 12-Sep-90 RSC  *)
            ModelTask^.Methods^.UnlockUnchangedDataObject(ModelTask);
        END;

        FixedStart := BigTimeToCalendarTime( UserEnteredStartDate );    (* 12-Sep-90 RSC *)

        IF ( SubtractWorkingTime ( MaxDate, duration, TimeSheet ) < FixedStart ) THEN
            (* Too big of an old duration? *)
            duration := FindDuration( FixedStart, MaxDate, TimeSheet );
        END;

        WITH Plan.Dates DO
            EarlyStart     := FixedStart;
            EarlyEnd       := AddWorkingTime( EarlyStart, duration, TimeSheet );
            LateFreeStart  := EarlyStart;
            LateFreeEnd    := EarlyEnd;
            LateTotalStart := EarlyStart;
            LateTotalEnd   := EarlyEnd;
            LateIndStart   := EarlyStart;   (* 22-May-91 EGK *)
            LateIndEnd     := EarlyEnd;
            CalendarTimeToBigTime (EarlyStart, TRUE, SupposedToStart);
        END;
        FilterSet      := ATaskFilterSet{Selected};     (* 12/17/86 LAA *)
    END;
    ProposedNode^.Methods^.UnlockFlexStorDataObject(ProposedNode);

    RETURN ProposedNode;

END MakeNewTask;



PROCEDURE AddNewTask    ( ModelTask : ATreeNode ) : ATreeNode;
VAR
    NewNode         : ATreeNode;
BEGIN
    NewNode := MakeNewTask (ModelTask);
    IF (NewNode <> NIL) THEN
        AddTask (NewNode, NIL, ModelTask);
    END;
    RETURN NewNode;
END AddNewTask;



PROCEDURE AddTaskCopy ( ModelTask   : ATreeNode ) : ATreeNode;

VAR
    NewNode             : ATreeNode;
    TaskPtr             : ATaskPtr;
    Subtree             : ATree;
    CNode               : ATreeNode;
    ONode               : ATreeNode;
    OParent             : ATreeNode;
    OPrev               : ATreeNode;
    OEdge               : AnEdgePtr;
    CEdge               : AnEdgePtr;


    PROCEDURE MakeCopyOfTask (    Node       : ATreeNode;
                              VAR CopyOfNode : ATreeNode ) : BOOLEAN;
    VAR
        TaskPtr             : ATaskPtr;
        BHandle             : AnExtHandle;
        TempWBS             : ARRAY [0..WBSLen] OF CHAR;

    BEGIN
        CopyOfNode := CreateTask();
        IF (CopyOfNode = NIL) THEN
            RETURN FALSE;
        END;

        CopyTask (Node, CopyOfNode);
        TaskPtr := CopyOfNode^.Methods^.LockFlexStorDataObject (CopyOfNode);  (* 10-Dec-87 LAA *)
        TaskPtr^.TaskID := NewID();

        SetLengthOf (TempWBS, 0);
        SetCodingField (TaskPtr^, WBSLine, TempWBS);

        BHandle := TaskPtr^.BaseLine.Assignments;     (* 10-Feb-88 LAA *)
        TaskPtr^.BaseLine.Assignments := AnExtHandle(NIL);
        EXCL(TaskPtr^.TaskFlags, BaseLineExists);     (* 12-Feb-88 LAA *)
        CopyOfNode^.Methods^.UnlockFlexStorDataObject(CopyOfNode);  (* 10-Dec-87 LAA *)
        RemoveAssignmentsAndExpenses( BHandle );

            (*  Store the address of the copy in the workspace of
                the original.  This is so we can link the copy in
                the right place in its new tree (if a summary).  *)

        TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
        TaskPtr^.WorkSpace := CopyOfNode;
        Node^.Methods^.UnlockFlexStorDataObject (Node);

        RETURN TRUE;
    END MakeCopyOfTask;


            (* CloneOf -- Locate the copy of this task. *)

    PROCEDURE CloneOf   (   Node    : ATreeNode ) : ATreeNode;
    VAR
        CNode           : ATreeNode;
        TaskPtr             : ATaskPtr;
    BEGIN
        IF (Node = NIL) THEN
            CNode := NIL;
        ELSE
            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            CNode := TaskPtr^.WorkSpace;
            Node^.Methods^.UnlockUnchangedDataObject (Node);
        END;
        RETURN CNode;
    END CloneOf;


            (* InFamily -- is the Node a child (or grandchild, or ...)
                           of the ParentNode?       *)

    PROCEDURE InFamily (    Node        : ATreeNode;
                            ParentNode  : ATreeNode ) : BOOLEAN;
    BEGIN
        WHILE (Node <> NIL) DO
            Node := Node^.Methods^.Parent (Node);
            IF (Node = ParentNode) THEN
                RETURN TRUE;
            END;
        END;
        RETURN FALSE;
    END InFamily;


BEGIN
    IF (NOT MakeCopyOfTask (ModelTask, NewNode)) THEN
        RETURN NIL;
    END;
    AddTask (NewNode, NIL, ModelTask);

    Subtree := ModelTask^.Methods^.GetSubtree (ModelTask);
    IF (Subtree = NIL) THEN
        RETURN NewNode;    (* Not a summary -- nothing else to do *)
    END;

        (* Now make copies of all the kid tasks *)

    ONode := Subtree^.Methods^.GetFirst (Subtree);
    WHILE (ONode <> NewNode) DO
        IF (NOT MakeCopyOfTask (ONode, CNode)) THEN
            AbortTransactionSet();
            RETURN NIL;
        END;

        OParent := ONode^.Methods^.Parent (ONode);
        OPrev := ONode^.Methods^.GetPrev (ONode);
        AddTask (CNode, CloneOf(OParent), CloneOf(OPrev));

        ONode := ONode^.Methods^.NextPreOrder (ONode);
    END;

        (*  Now make copies of all the dependencies between the
            kid tasks *)

    ONode := Subtree^.Methods^.GetFirst (Subtree);
    WHILE (ONode <> NewNode) DO
        TaskPtr := ONode^.Methods^.LockFlexStorDataObject (ONode);
        OEdge := TaskPtr^.desctasks;
        ONode^.Methods^.UnlockUnchangedDataObject (ONode);

        WHILE (OEdge <> NIL) DO

                (*  If OEdge (original edge) joins this kid task
                    to another task that is also in this family, then
                    make a copy of it (as CEdge).
                *)

            IF (InFamily (OEdge^.tailtask, ModelTask)) THEN
                CNode := CloneOf(ONode);
                CEdge := CreateEdge (CNode, CloneOf(OEdge^.tailtask));
                IF (CEdge = NIL) THEN
                    AbortTransactionSet();
                    RETURN NIL;
                END;

                CEdge^ := OEdge^;
                CEdge^.headtask := CNode;
                CEdge^.tailtask := CloneOf(OEdge^.tailtask);
                AddEdge (CEdge, TRUE);
                SendNotices (AddAnEdge, AfterActing, CEdge);    (* 6/4/89 EGK *)
            END;
            OEdge := OEdge^.headlink;
        END;
        ONode := ONode^.Methods^.NextPreOrder (ONode);
    END;

    RETURN NewNode;
END AddTaskCopy;





PROCEDURE ChangeTask (TaskNode: ATreeNode) : BOOLEAN;

VAR
    TaskPtr                 : ATaskPtr;
    Code                    : ACode;
    ThisIsASummaryTask      : BOOLEAN;
BEGIN

    CheckTaskValid(TaskNode);

    SendNotices (ChangeATask, BeforeActing, TaskNode);   (* 6/4/89 EGK *)

    Code := TaskForm( TaskNode );

    IF (Code = ExitKey) THEN

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        WITH TaskPtr^ DO
            OldDurationScale  := scale;   (* Save the next task's defaults. *)
            OldEffortScale    := EffortScale;
            OldPriority       := priority;
            OldFixation       := fixation;
            OldDuration       := duration;
            OldDurationMethod := DurationMethod;
            OldSplittingRule  := SplittingRule; (* 28-Mar-91 TGS *)
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
        RETURN TRUE;
    END;
    RETURN FALSE;

END ChangeTask;





PROCEDURE ChangeEdge;

VAR
    EdgePtr                 : AnEdgePtr;
    TaskA                   : ATreeNode;
    TaskB                   : ATreeNode;
    Code                    : ACode;
    Changed                 : BOOLEAN;

BEGIN                       (* ChangeEdge *)

    TaskA := NIL;                                                 (* 22-Jul-87 LAA *)
    TaskB := NIL;
    CursorTask := GanttChart^.Methods^.GetCursorNode(GanttChart);
    IF (CursorTask = NIL) THEN
        RETURN;                 (* RSC 8/16/88 *)
    END;
    IF (BugTaskA <> NIL) THEN             (* Edge: BugTaskA -- Cursor *)
        TaskA := BugTaskA;
        TaskB := CursorTask;
    ELSIF (BugTaskB <> NIL) THEN          (* Edge: Cursor -- BugTaskB *)
        TaskA := CursorTask;
        TaskB := BugTaskB;
    END;


    IF (TaskA = TaskB) THEN               (* No bug, or same as cursor *)
        WarningBoxForJoin();
        RETURN;
    END;

    EdgePtr := FindEdge (TaskA, TaskB);
    IF (EdgePtr = NIL) THEN
        IF (HeapAvailable()) THEN                                 (* 21-Jan-88 LAA *)
            EdgePtr := CreateEdge (TaskA, TaskB);
            IF (EdgePtr = NIL) THEN                               (* 03-Feb-88 LAA *)
                RETURN;
            ELSIF (EditEdge (EdgePtr, Changed) = CancelKey) THEN    (* 11/13/89 EGK *)
                DelEdge (EdgePtr);
            ELSE
                AddEdge (EdgePtr, TRUE);
                SendNotices (AddAnEdge, AfterActing, EdgePtr);    (* 6/4/89 EGK *)
                UnSetState (Scheduled);
            END;
        END;
    ELSE
        SendNotices (ChangeAnEdge, BeforeActing, EdgePtr);    (* 6/4/89 EGK *)
        IF (EditEdge (EdgePtr, Changed) = CancelKey) OR (NOT Changed) THEN
            AbortTransactionSet();                        (*  11/13/89 EGK *)
        ELSE
            UnSetState(Scheduled);
        END;
    END;

END ChangeEdge;



    (*  EditEdge -- Change the edge connecting BugTaskA and BugTaskB *)

PROCEDURE EditEdge (    EdgePtr     : AnEdgePtr;
                    VAR Changed     : BOOLEAN   ) : ACode;
VAR
    ContextRecord           : RECORD
                                EdgePtr     : AnEdgePtr;
                                ReturnCode  : ACode;
                                EdgeChanged : BOOLEAN;
                              END;
    s                       : ARRAY [0..29] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    ContextRecord.EdgePtr     := EdgePtr;
    ContextRecord.ReturnCode  := CancelKey;
    ContextRecord.EdgeChanged := FALSE;

    SetString(s, "\TLFBASE(TLEDGE)");                             (* 02-Mar-88 LAA *)
    ok := CallOverlayWithContext( s, ADR(ContextRecord) );

    Changed := ContextRecord.EdgeChanged;

    RETURN ContextRecord.ReturnCode;

END EditEdge;









    (* BridgeTask -- Link every antecedant of the task to every
                     dependant. *)

PROCEDURE BridgeTask(TaskNode : ATreeNode);

VAR
    Task                         : ATaskPtr;
    EdgePtr                      : AnEdgePtr;
    MDependantEdge,
    AntecedantEdge, DependantEdge: AnEdgePtr;
    AntecedantTask, DependantTask: ATreeNode;
    s                            : ARRAY [0..80] OF CHAR;
    NotYetWarned                 : BOOLEAN;

BEGIN
    NotYetWarned := TRUE;

    CheckTaskValid(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    AntecedantEdge := Task^.antetasks;
    MDependantEdge := Task^.desctasks;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

    WHILE (AntecedantEdge <> NIL) DO
        AntecedantTask := AntecedantEdge^.headtask;
        DependantEdge  := MDependantEdge;
        WHILE (DependantEdge <> NIL) DO
            DependantTask := DependantEdge^.tailtask;
                (* Unless the tasks are already joined, join them. *)
            IF ItDepends(AntecedantTask,DependantTask) OR
               ItDepends(DependantTask,AntecedantTask) THEN
            ELSE
                EdgePtr := CreateEdge (AntecedantTask, DependantTask);
                IF (EdgePtr <> NIL) THEN
                    AddEdge (EdgePtr,TRUE);
                    SendNotices (AddAnEdge, AfterActing, EdgePtr);    (* 6/4/89 EGK *)
                END;
            END;
            DependantEdge := DependantEdge^.headlink;
        END;
        AntecedantEdge := AntecedantEdge^.taillink;
    END;

END BridgeTask;






PROCEDURE DeleteTask(VAR TaskNode : ATreeNode);

VAR
    Task                    : ATaskPtr;
    TaskFlags               : ATaskFlagSet;
    JoinsExist              : BOOLEAN;
    Bridge                  : BOOLEAN;
    Name                    : ARRAY [0..39]  OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    NullString              : ARRAY [0..0] OF CHAR;

BEGIN

    GetMessage(ModuleNumber+12,s);   (* 'Really DELETE "' *)
    CheckTaskValid(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Copy( Task^.taskname, Name );
    IF ((Task^.antetasks = NIL) AND (Task^.desctasks = NIL)) THEN (* 27-Feb-88 LAA *)
        JoinsExist := FALSE;
    ELSE
        JoinsExist := TRUE;
    END;
    TaskFlags := Task^.TaskFlags;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
    ConcatLS( s, Name );

    ConcatMessage(s,ModuleNumber+13);                             (* '"?' *)
    SetLengthOf(NullString, 0);
    IF ( ContinuationBox (s, NullString, NoHelp) ) THEN
        IF (TaskNode^.Methods^.FirstChild(TaskNode) <> NIL) THEN  (* 26-Jun-87 LAA *)
            Copy( Name, s );
            ConcatMessage(s, ModuleNumber + 74);                  (* " has subtasks which will also be deleted.  Continue?" *)
            IF ( NOT ContinuationBox (s, NullString, NoHelp) ) THEN
                DisplayMessage(ModuleNumber + 75);                (* "Ok.  Not deleted" *)
                RETURN;
            END;
        END;
        IF (BaseLineExists IN TaskFlags) THEN  (* 03-Nov-87 RSC *)
            Copy( Name, s);
            ConcatMessage(s, ModuleNumber + 73);                  (* " has BaseLine info.  Continue?" *)
            IF ( NOT ContinuationBox (s, NullString, NoHelp) ) THEN
                DisplayMessage(ModuleNumber + 75);                (* "Ok.  Not deleted" *)
                RETURN;
            END;
        END;
        IF (JoinsExist) THEN
            GetMessage(ModuleNumber+26,s);                            (* 'Automatically join dependent tasks?' *)
            Bridge := NoYes(s);
        ELSE
            Bridge := FALSE;
        END;
        DoTaskDeletion(TaskNode,Bridge);                          (* 27-Feb-88 LAA *)
        TaskNode := NIL;
        RETURN;
    END;
    DisplayMessage(ModuleNumber + 75);                            (* "Ok.  Not deleted" *)

END DeleteTask;





PROCEDURE DoTaskDeletion(VAR TaskNode   : ATreeNode;
                             Bridge     : BOOLEAN );
VAR
    TheNextTask             : ATreeNode;
    Task                    : ATaskPtr;
    Subtree                 : ATree;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..100] OF CHAR;

BEGIN

    CheckTaskValid(TaskNode);

        (* Reroute dependencies *)

    Subtree := TaskNode^.Methods^.GetSubtree(TaskNode);
    IF (Subtree <> NIL) THEN
        Subtree^.Methods^.
               TraverseTree(Subtree, ParentAfterChild, 999, ProcessForDelete,
                            ADR(Bridge));
    END;

    GetMessage(ModuleNumber+14,s);     (*    'Ok, I have deleted "' *)
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    ConcatLS(s, Task^.taskname);
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

    ConcatMessage(s,ModuleNumber+9);        (*    '".'  *)

    ProcessForDelete(TaskNode, ADR(Bridge));

    UnSetState(Scheduled);                                         (* LAA 11/04/86 *)

    ScheduleSaved := FALSE;
    Message(s);

END DoTaskDeletion;




PROCEDURE ProcessForDelete(VAR TaskNode     : ATreeNode;
                               Bridge       : ADDRESS);

VAR
    HandyBridge             : POINTER TO BOOLEAN;

BEGIN                       (* ProcessForDelete *)

    HandyBridge := Bridge;
    IF (HandyBridge^) THEN
        BridgeTask(TaskNode);
    END;
    RemoveTask (TaskNode);

END ProcessForDelete;




PROCEDURE WarningBoxForJoin;
VAR
    Title : ARRAY [0..50] OF CHAR;
    s     : ARRAY [0..255] OF CHAR;
BEGIN
    Burp;
    GetMessage(ModuleNumber+16,Title);   (* "Join Instructions" *)
    GetMessage(ModuleNumber+17,s);
        (*
        SetString(s,"Before you can JOIN or UNJOIN two tasks, you must mark the task ");
        ConcatS(s,'that comes first as "1" and the task that comes second ');
        ConcatS(s,'as "2".(Press [Esc] to continue.)');
        *)
    WarningBox(s,Title,OfferHelp);
END WarningBoxForJoin;





PROCEDURE CheckBoth(First,Second:ATreeNode):BOOLEAN;
BEGIN
    IF (First=NIL) OR (Second=NIL) OR (First=Second) THEN
        WarningBoxForJoin;
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END;
END CheckBoth;





PROCEDURE JoinTasks(First, Second : ATreeNode);

VAR
    EdgePtr                 : AnEdgePtr;
    s                       : ARRAY [0..255] OF CHAR;
BEGIN
    IF (NOT CheckBoth(First,Second)) THEN
        RETURN;
    END;
    IF (HeapAvailable()) THEN                                     (* 21-Jan-88 LAA *)
        EdgePtr := CreateEdge (First,Second);
        IF (EdgePtr <> NIL) THEN
            AddEdge (EdgePtr,TRUE);
            SendNotices (AddAnEdge, AfterActing, EdgePtr);        (* 6/4/89 EGK *)
            UnSetState (Scheduled);
            GetMessage ( ModuleNumber + 80, s );                     (* 2-Oct-89 MWP *)
            Message ( s );
        END;
    END;

END JoinTasks;





PROCEDURE UnjoinTasks(First, Second : ATreeNode);

VAR
    EdgePtr                 : AnEdgePtr;
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN
    IF (CheckBoth(First,Second)) THEN

        EdgePtr := FindEdge(First,Second);
        IF (EdgePtr = NIL) THEN
            EdgePtr := FindEdge(Second,First);
            IF (EdgePtr = NIL) THEN
                WarningBoxForJoin;
                RETURN;
            END;
        END;

        SendNotices (DeleteAnEdge, BeforeActing, EdgePtr);    (* 6/4/89 EGK *)
        RemoveEdge (EdgePtr);
        UnSetState (Scheduled);

            (* Flag the two tasks as needing recalculation.  -- 11/8/89 EGK *)

        TaskPtr := First^.Methods^.LockFlexStorDataObject (First);
        TaskPtr^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
        First^.Methods^.UnlockFlexStorDataObject (First);
        TaskPtr := Second^.Methods^.LockFlexStorDataObject (Second);
        TaskPtr^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
        Second^.Methods^.UnlockFlexStorDataObject (Second);

        GetMessage ( ModuleNumber + 81, s );                     (* 22-Sep-89 MWP *)
        Message ( s );

    END;
END UnjoinTasks;




PROCEDURE InitializeChanger();
VAR
    Task : ATask;
BEGIN
    InitializeTaskRecord( Task );

    WITH Task DO
        OldDurationScale  := scale;   (* Save the next task's defaults. *)
        OldEffortScale    := EffortScale;
        OldPriority       := priority;
        OldFixation       := fixation;
        OldDuration       := duration;
        OldDurationMethod := DurationMethod;
        OldSplittingRule  := SplittingRule; (* 28-Mar-91 TGS *)
    END;
END InitializeChanger;


BEGIN

    AdvancedTaskForm     := FALSE;
    UsesCostTracking     := FALSE;

END Changer.

