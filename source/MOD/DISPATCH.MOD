(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    07/25/86 LAA    Added functions from old KeyCommander.
    11/11/86 LAA    The call to Pert for the compute key now uses AsOfDate
                    rather than Today.
    11/27/86 LAA    Removed NeedRecompute, whose function is now handled by
                    ChartState.
    12/15/86 LAA    Access the FilterNames form.  Added F7 filtering.
    21-May-87 LAA   Removed the ability of Dispatch to handle insert, delete,
                    copy and F2 keys.
    24-Jun-87 LAA   Call CheckAlarms for the ComputeKey, before calling Pert.
    25-Jun-87 LAA   We're no longer using BugDays, so the GotoBug processing
                    moves the cursor to the start of the task.
    22-Jul-87 LAA   Changed UnJoin case to use the cursor task, like the Join
                    does.  Moved procedure IncestuousRelations here from
                    GanttOutlines, since it's only used for joins.
    29-Jul-87 EGK   Removed use of ManuallyFilterKey and ManuallyFilter
                    procedure, since they are now obsolete. Also added the
                    sort options.
    04-Aug-87 LAA   Incorporated named layouts.
    06-Aug-87 LAA   Added Ed's changes for multiple highlight filters, and
                    removal of sorting options.
    01-Sep-87 LAA   Added new codes for reassigned function keys.
    28-Sep-87 EGK   Removed calls to UndoTaskChange; it ain't used no more.
     2-Oct-87 RSC   Added NoYes() box before schedule erase.  Its here rather
                    than in Tran2 because importers call it after doing their
                    own prompts.
    12-Oct-87 EGK   Added call to PickAndEditMemo for Project notes.
    14-Oct-87 EGK   Added call to Helper to handle help index key.
    16-Oct-87 EGK   Removed references to ChangeFiltersKey and Actions.FileForm.
                    PrjtFormKey is now FileFormKey.
    12-Nov-87 LAA   Put in procedure variable through which the layouts are
                    invoked.
    25-Nov-87 LAA   Cleaned up some old code.
    29-Dec-87 LAA   Keep the attempt to join a task to itself from setting
                    recalc on.
    06-Jan-88 LAA   Recalc was set on even if an unjoin failed due to no bugs
                    having been set.
    14-Jan-88 LAA   Removed calls to UnSetState when joining and unjoining
                    tasks, since this is done in Changer.
    20-Jan-88 RSC   Removed reference to Forms (it was unused).
    10-Feb-88 LAA   Allow the network key to bring up the network.
    26-Feb-88 EGK   Removed calc check before bringing up alternate views.
    29-Feb-88 LAA   Removed calc check before bringing up Network View.
    31-Oct-88 LAA   Check ScheduleComputedOk so that F9 will cause a recalc
                    if there was a calc error.
    21-Dec-88 LAA   Changed imports for Lazlo reorganization.
     5-Jan-89 RSC   Moved Actions into Keys.
    14-May-89 AJL   Removed Alarms.
    25-May-89 EGK   Bring up journal notes on ALT-F2 (ReInsertKey).
    07-Jun-89 LAA   Removed import of FilterRc, and of ShowJoin.  Called a
                    new overlay (TLShowJoins) to do the ShowJoin work.  Also
                    removed an unused constant: OurFilterBorrowingID.
    19-Jun-89 AJL   Removed FiltersOn boolean.
    31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
    17-Aug-89 EGK   Removed handling of "FileErase" code.  This is now done
                    in the TLErase overlay.
    22-Sep-89 MWP   Provide confirmation of dependency assignments and
                    removals.
     2-Oct-89 MWP   Remove confirmation of dependency assignments and
                    removals to changer module where they belong.
     9-Oct-89 MWP   Removed text literal.
    12-Dec-89 LAA   Removed all references to Caching.
    21-Feb-90 KKC   Remove import of Timeu.
    01-Jun-90 AJL   Removed use of the PlanLevel variables from Planner.
    15-Oct-90 RSC   Added SoundOn and SoundOff.
    24-Jan-91 AJL   Add support for the HistSynchKey to bring up the 
                    histograms of the cursor task.
                    Use OverlayPackage to run the histograms.
    15-Feb-91 AJL   Remove ChartCodeSet.
----------------------------------------------------------------------------*)


IMPLEMENTATION MODULE Dispatcher;


FROM Allocs                 IMPORT
        (* TYPE *)              ATaskFilter;

FROM AsOf                   IMPORT AsOfDate;

FROM Changer                IMPORT
    (* PROC *)                  AddNewTask, JoinTasks,
                                UnjoinTasks, ChangeEdge;

FROM Chart                  IMPORT MChTaskAndDay,
                                   MChDay, MChToday,
                                   BugTaskA, BugTaskB,
                                   BugDayA, BugDayB, MChTask,
                                   CursorTask, CursorDay, GanttChart,
                                   MChCurrentTask;

FROM ChartControl           IMPORT DisplayTheChart, AChartState, UnSetState,
                                   ChartState;

FROM ChartForms             IMPORT SelectLayout, CurrentChartFormat;

FROM ChartMgr               IMPORT
    (* PROC *)                  ResetChartStack;

FROM Codes                  IMPORT ACode, ASetOfCodes, SetCodeBits, MaxCode,
                                   EmptyCodeSet;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Error, Burp, FatalError, Message,
                                ContinuationBox;

FROM Filters                IMPORT ResetFilters;

FROM FilterSelect           IMPORT
    (* PROC *)                  ChooseFilter;

IMPORT Keys;

FROM Keys                   IMPORT HelpKey, EditKey, ExitKey, DoIt, CancelKey, Up, Down,
                                   Fwrd, Reverse, ComputeKey, GotoKey, NewProjectKey,
                                   OnMenu, AnteKey, AddTaskKey, CopyKey,
                                   JoinKey, UnJoinKey, ChngTskKey, DelTaskKey,
                                   OnChart, ResourceFormKey,
                                   OptionsFormKey, DaysKey,
                                   AlternateDisplayKey,
                                   FileFormKey,
                                   JoinPartialKey, HistKey, HistSynchKey, SelListKey,
                                   HighListKey, HighList2Key, HighList3Key,
                                   DependViewKey, ReInsertKey,  (* 5/25/89 EGK *)
                                   HelpIndexKey, NetworkKey,
                                   SoundOn, SoundOff;

FROM Kbio                   IMPORT ascreeny, avidmode, vidctrl,
                                   ascreenx, maxcol, maxrow, EraseScreen,
                                   GetAnyCode,  PushCode, soundon;

FROM Layout                 IMPORT MenuStart, GanttWEnd;

FROM LStrings               IMPORT CtoS, ConcatLS, Remove, Fill, Search,
                                   SetString, SubStr, SetLengthOf;

FROM Memos                  IMPORT
    (* PROC *)                  PickAndEditMemo;

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlay, OverlayPackage;

FROM Planner                IMPORT 
    (* TYPE *)                     ACalcComponent, AWhenToCalc,
    (* VAR *)                      ScheduleComputedOk, ScheduleEndDate,
                                   CalculationState,
    (* PROC *)                     Pert, WeShouldRecalc; 

FROM RsrcEdit               IMPORT
    (* PROC *)                  EditResources;

FROM RunMenu                IMPORT SelectAndRunMenu, ExecuteMenu;

FROM Schedule               IMPORT
    (* PROC *)                  ScheduleForm, DoOptionsForm;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;



CONST
    ModuleNumber  = 3100;   (* For GetMessage *)

CONST
    GotoCurrent   = Keys.GotoCurrentTaskKey;
    GotoToday     = Keys.GotoTodayKey;
    DisplayForm   = Keys.DsplyKey;










PROCEDURE IncestuousRelations(    TaskANode : ATreeNode;
                                  TaskBNode : ATreeNode)
                                                        : BOOLEAN;

VAR
    TempNode                : ATreeNode;

BEGIN                       (* IncestuousRelations *)

    IF (TaskANode <> TaskBNode) THEN
        IF ((TaskANode <> NIL) AND (TaskBNode <> NIL)) THEN
            TempNode := TaskANode;
            WHILE (TempNode <> NIL) DO
                TempNode := TempNode^.Methods^.Parent(TempNode);
                IF (TempNode = TaskBNode) THEN
                    RETURN TRUE;
                END;
            END;

            TempNode := TaskBNode;
            WHILE (TempNode <> NIL) DO
                TempNode := TempNode^.Methods^.Parent(TempNode);
                IF (TempNode = TaskANode) THEN
                    RETURN TRUE;
                END;
            END;
        END;
    END;

    RETURN FALSE;

END IncestuousRelations;





PROCEDURE DefaultLayoutProc();

BEGIN                       (* DefaultLayoutProc *)

    IF (SelectLayout(CurrentChartFormat) <> CancelKey) THEN END;  (* 04-Aug-87 LAA *)
    GanttChart^.Methods^.NotifyOfChange(GanttChart);

END DefaultLayoutProc;







PROCEDURE Dispatch( ToDo : CARDINAL );
VAR
    S        : ARRAY [0..19] OF CHAR;


    PROCEDURE DoJoin();
    VAR
        TaskNode : ATreeNode;
        S1       : ARRAY [0..199] OF CHAR;
    BEGIN
        CursorTask := GanttChart^.Methods^.GetCursorNode(GanttChart);
        IF (BugTaskA <> NIL) THEN
            IF (BugTaskA = CursorTask) THEN
                   (*  "A task cannot be joined to itself." *)
                GetMessage(ModuleNumber + 26, S1);
                Error(S1);
            ELSIF (IncestuousRelations(BugTaskA, CursorTask)) THEN
                   (*  "It's neither necessary nor possible to join a task to its summary task."  *)
                GetMessage(ModuleNumber + 24, S1);
                Error(S1);
            ELSE
                IF (ToDo = JoinKey) THEN
                    JoinTasks(BugTaskA, CursorTask);
                ELSE
                    ChangeEdge();
                END;
            END;
        ELSIF (BugTaskB <> NIL) THEN
            IF (CursorTask = BugTaskB) THEN
                   (*  "A task cannot be joined to itself." *)
                GetMessage(ModuleNumber + 26, S1);
                Error(S1);
            ELSIF (IncestuousRelations(CursorTask, BugTaskB)) THEN
                GetMessage(ModuleNumber + 24, S1);     (*  "It's neither necessary nor possible to
                                                          join a task to its summary task."  *)
                Error(S1);
            ELSE
                IF (ToDo = JoinKey) THEN
                    JoinTasks(CursorTask, BugTaskB);
                ELSE
                    ChangeEdge();
                END;
            END;
        ELSE
            GetMessage(ModuleNumber+22, S1);
            Error(S1);
        END;
    END DoJoin;



    PROCEDURE DoUnJoin();
    VAR
        TaskNode : ATreeNode;
        S1       : ARRAY [0..199] OF CHAR;
    BEGIN
        CursorTask := GanttChart^.Methods^.GetCursorNode(GanttChart);
        IF (BugTaskA <> NIL) THEN
            UnjoinTasks(BugTaskA, CursorTask);
        ELSIF (BugTaskB <> NIL) THEN
            UnjoinTasks(CursorTask, BugTaskB);
        ELSE
            GetMessage(ModuleNumber+23, S1);
            Error(S1);
        END;
    END DoUnJoin;


    PROCEDURE Die();
    VAR
        S1       : ARRAY [0..199] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber + 1, S1);  (* "Unknown TLWHAT.CFG Dispatch call; code " *)
        CtoS(ToDo,S);
        ConcatLS(S1,S);
        Error(S1);
    END Die;


BEGIN

    CASE (ToDo) OF

        Keys.FileRetrieve       :
                                   GetMessage(ModuleNumber + 28, S);  (* 9-Oct-89 WMP *)
                                   (* "RETRIEVE" *)
                                   ExecuteMenu(S,S);

     |  SelListKey              :  ChooseFilter (Selected);
     |  HighListKey             :  ChooseFilter (Highlight3);
     |  HighList2Key            :  ChooseFilter (Highlight4);
     |  HighList3Key            :  ChooseFilter (Highlight5);
     |  Keys.FiltersClear       :  ResetFilters;

     |  GotoCurrent             :  MChCurrentTask;
     |  GotoToday               :  MChToday;

     |  JoinKey, JoinPartialKey :  DoJoin();

     |  UnJoinKey               :  DoUnJoin();

     |  DisplayForm             :  CurrentLayoutProc();

     |  Keys.ResetProgram       :  (* Nothing *)
     |  Keys.ResetScreen        :  UnSetState(Showing);
     |  ComputeKey              :  IF (NOT (Scheduled IN ChartState) OR
                                      WeShouldRecalc(CalculationState,ManualCalc)) AND
                                      (Pert(AsOfDate,ManualCalc)) THEN
                                   END;

     |  OptionsFormKey          :  DoOptionsForm();
     |  ResourceFormKey         :  EditResources;

     |  DaysKey                 :  (* Calendar *)
                                   GetMessage(ModuleNumber + 15, S);
                                   ExecuteMenu(S,S);

     |  NewProjectKey           :  GetMessage(ModuleNumber + 16, S);
                                   ExecuteMenu(S,S);

     |  AlternateDisplayKey,
        HistSynchKey,
        HistKey                 :
                                   IF (ToDo = HistSynchKey) THEN
                                       GetMessage(ModuleNumber + 29, S);
                                   ELSE
                                       GetMessage(ModuleNumber + 17, S);
                                   END;
                                   IF OverlayPackage(S) THEN; END;
                                   ResetChartStack; (* In case of abend. *)
                                   MChTaskAndDay(CursorTask,CursorDay);

     |  NetworkKey :                                              (* 10-Feb-88 LAA *)
                GetMessage(ModuleNumber + 27, S);    (* TLNET *)
                ExecuteMenu(S,S);
                ResetChartStack; (* In case of abend. *)
                MChTaskAndDay(CursorTask,CursorDay);

     |  FileFormKey:
                                   IF (ScheduleForm() = 0) THEN END;

     |  AnteKey                 :  SetString(S, "|TLSHOWJO");     (* 07-Jun-89 LAA *)
                                   IF (OverlayPackage(S)) THEN END;

     |  ReInsertKey             :  PickAndEditMemo();       (* 5/25/89 EGK *)

     |  DependViewKey           :  GetMessage(ModuleNumber + 25, S);
                                   ExecuteMenu(S, S);

     |  SoundOn                 :  soundon := TRUE;
     |  SoundOff                :  soundon := FALSE;
    ELSE
        Die();
    END;

END Dispatch;







BEGIN
    CurrentLayoutProc := DefaultLayoutProc;
END Dispatcher.
