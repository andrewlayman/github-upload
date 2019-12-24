IMPLEMENTATION MODULE TSort;

    (* MODIFICATION HISTORY:
       Will use many of planners routines to build data for snet
        11-Mar-88 LAA   Moved arrays from NetBData to here.
        14-Mar-88 EGK   Changed AdjSubtasks and SetupPass to lock only one
                        task handle down at a time.
        13-Jul-88 LAA   Move the call to SortForks up by one line, per Ken,
                        to correct bug which produced dump for 1 task sched.
         1-Jun-89 KWC   Totaly  reworked code
        28-Jun-89 KWC   removed underscores
        03-Jul-89 LAA/CMH Changed usage of Count to XX and Count2 to YY.
        21-Jul-89 KWC   Moved tasks that had a partial dependency
        21-Jul-89 KWC   Adjusted Annealing parms
         8-Aug-89 CMH   Removed obsolete variables.
         5-Sep-89 CMH   Moved UnitsForScaling, CharactersForScaling,
                        UnitsForGrouping and MilitaryTime to
                        TimeUnitsTLGS.DEF from TSEDTimescale.DEF so
                        TLNBUILD would not import from TSEDTimescale
                        since it has 1.6k bytes of data.
        18-Sep-89 EGK   FindKey was ignoring the InvisibleEdge attribute in
                        its traversals.  Added FirstVisibleDescendant
                        sub-procedure.  Also cleaned up FindKey for
                        indentation, unnecessary use of global vars, and
                        excessive Locks and Unlocks.  In TSort2, put up
                        a progress box instead of a top-line message.
        19-Sep-89 EGK   Added DiscardLists procedure.  Now TSort is
                        responsible for discarding PTaskList, since
                        BuildMat doesn't need it.
        20-Sep-89 EGK   Split off the annealing code into the TSort2 module.
        21-Sep-89 EGK   Make sure the overlay context points to a valid
                        string before looking for the "G".
        25-Sep-89 EGK   Convert calls to ListInit to check for a return
                        status.
        27-Sep-89 CMH   Considering the arrange by baseline or actual flag
                        for the timescaled pert.
        28-Sep-89 EGK   If HaveInfLoop is set, proceed as if the NetworkType
                        was Conventional.  Put in Ken's change to SetupPass
                        to omit certain kinds of dependencies from the
                        outline PERT.
        09-Nov-89 EGK   Added some temp variables to SetupPass so that we
                        can use fields from the task after it's released.
        11-Nov-89 KWC   Added a text to clear netbranch flag if a phantom
                        dependency was made invisible
        21-Nov-89 EGK   Moved the code that sets up the "YY" field of each
                        task into TimeSetupPass (from the TSort procedure),
                        so that even in traditional PERT mode we can find
                        the end box of a summary task.
         5-Dec-89 KWC   Removed time  from non-time scale charts
         5-Dec-89 KWC   Checked sooner for the case where start of
                        dependent task is befor end of task
         6-Dec-89 EGK   In SetupPass, use TempXX to hold othertask^.XX, to
                        avoid too many flexstor locks at once.
         9-Jan-90 EGK   In SetupPass, check for invisible edges before using
                        task^.XX, which not be valid.
        21-Feb-90 KKC   Remove all unreferenced id from Timeu.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
         7-Jun-90 EGK   Split SetupPass into two passes.  The first one
                        (the new CheckForInvisibleEdges) looks for all edges
                        which need to be marked invisible, and the other
                        (the old SetupPass) marks "fork tasks" and "branch
                        tasks".  Basically we were trying to do too much
                        work in a single pass.  By the time we marked some
                        edges as invisible, it was too late to go back and
                        move tasks that had been placed assuming those edges
                        were visible.
         9-Aug-90 RSC   Changed references as needed to refer to TempTaskFlags.
         9-Nov-90 TGS   Integrate changes made to 4.03.
        30-Apr-91 RSC   Some fixes from 9-Nov-90 seem to have been left out
                        accidentally.  I added the two places I found and
                        noted todays date.
     *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskFlag, ATaskFlagSet,
                                ATempTaskFlag, ATempTaskFlagSet,
                                ATaskStatusSet, ATaskStatus, ADurationMethod,
    (* VAR *)                   TaskTree;

FROM DataNetwork            IMPORT
    (* VAR *)                   TimeScaleNetwork,
    				ArrangeBy,
    (* PROC *)                  InitializeNetworkData;

FROM Dialog                 IMPORT
                                ABoxHandle, ProgressBox, ReleaseBox,
                                Message, Error, FatalError;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr,
                                InvisibleEdge,PhantomSuccessor,
                                PhantomPredecessor;

FROM ErrorUtil              IMPORT
                                PrintMsg,PrintCard,PrintTask,
                                PrintSMsg,PrintSCard,PrintSTask;


FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,ObjectsAreSame,DiscardExtObject,
    (* PROC *)                  LockObject,ReleaseObject,
                                ReleaseUnchangedObject;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSScale, ATLGSTaskArrangement;

FROM LStrings               IMPORT
    (* PROC *)                  LengthOf;

FROM MsgFile                IMPORT
                                GetMessage;

FROM NetBData               IMPORT
    (* VAR *)                   loopcnt,lowerloop,TaskCount,
                                infloopcount,upperloop,endloop,floodkey,
                                NetFlags,NetFlagType,NetFlagSetType,
                                inflooptaskhandle,
                                ForkListHandle,StackListHandle,
                                loopdim,nextgroup;

FROM NetStatic              IMPORT
    (* VAR *)                   taskdim,NetworkDone,MatrixOverflow,
                                HaveInfLoop,SnetWidth,
                                FatalNetError, Xpos, Ypos,
                                Xmaxpos, Ymaxpos, Utility,
                                loopnode, maxtask;

FROM NetworkData            IMPORT
    (* TYPE *)                  ANetworkType,AnAnnealingChoice,
    (* VAR *)                   AnnealingChoice,NetworkType;

FROM NetPhantoms            IMPORT
    (* CONST*)                  SummaryFlag, PhantomFlag,InvisibleFlag,
    (* TYPE *)                  AT2Proc,
    (* PROC *)                  Scan1, CreateSummaryPhantoms;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext;

FROM PTaskList              IMPORT
    (* VAR  *)                  PrivateTaskList,
    (* PROC *)                  ListInit, AddBefore,DeList;


FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,ATreeOrder,TempFlag4;


FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration,
    (* TYPE *)                  ADate, ATimeInfo,
    (* PROC *)                  KDay, TimeUtoT, DayOfWeek;

FROM Timeu                  IMPORT
    (* VAR *)                   WeeksBeginOn;

FROM TimeUnitsTLGS          IMPORT
    (* VAR *)                   UnitsForScaling;


CONST
    ModuleNumber        = 20300;  (* For GetMessage *)
    forkmax             = 400;
    ColStep             = 20;
    InvisibleNode       = TempFlag4;
    NoAdjust            = 0;
    SetXpos             = 1;
    IncXpos             = 2;
    MaxInt              = 32000;
    MaxIndent           = 9;

VAR

    TaskSave            : ARRAY [0..taskdim] OF AnExtHandle;

    ContextPointer      : POINTER TO ARRAY [0..255] OF CHAR;

    forktaskcount       : INTEGER;

    maxduration         : CARDINAL;
    longtask,
    forkcount           : INTEGER;
    infloopindex        : INTEGER;

    endtaskhandle,
    currtaskhandle,
    descendanthandle,
    taskhandle          : AnExtHandle;

    FirstWarning        : BOOLEAN;



(*     Outline Network System... The Bacic Approch

            1. Creat a list of all tasks
            2. Find all the tasks that have not predecessors
            3. Make a list for all task that have more then one
               dependency. This list is call the fork list it is
               used to generate the loops
            4. Find all the loops in the system
                a. Flood the tree with the upper members of the loop
                b. Now see        *)



PROCEDURE TooComplex;
VAR
    s       : ARRAY [0..255] OF CHAR;
BEGIN
    FatalNetError := TRUE;
    GetMessage(ModuleNumber+3,s);
    Error(s);
END TooComplex;



PROCEDURE AdjSubtasks(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    maxplace,minplace       : INTEGER;
    TaskPtr                 : ATaskPtr;
    EdgePtr                 : AnEdgePtr;
    TCount                  : INTEGER;
    TDesctasks              : AnEdgePtr;
    TAntetasks              : AnEdgePtr;

BEGIN
    IF (FatalNetError) THEN
        RETURN;
    END;

    (* Move the front of the master tasks into place *)
    TaskPtr := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    IF(InvisibleFlag IN TaskPtr^.TempTaskFlags )THEN
       TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
       RETURN;
    END;
    TCount := TaskPtr^.XX;
    TDesctasks := TaskPtr^.desctasks;
    TAntetasks := TaskPtr^.antetasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    IF (Xpos[TCount] = 0) THEN
        HaveInfLoop := TRUE;
        RETURN;
    END;

    IF ((NetSummaryFlag IN NetFlags[TCount]) AND
        (NOT (NetPhantomFlag IN NetFlags[TCount])))  THEN

        EdgePtr := TDesctasks;
        minplace:=30000;

        WHILE (EdgePtr <> NIL) DO
            WITH EdgePtr^ DO
                IF (NOT (InvisibleEdge IN Attributes)) THEN
                    TaskPtr := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
                    IF (Xpos[TaskPtr^.XX] < minplace) THEN
                        minplace := Xpos[TaskPtr^.XX];
                    END;
                    tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
                END;
            END;
            EdgePtr := EdgePtr^.headlink;
        END;

        Xpos[TCount] := minplace;
    END;

    IF (NetPhantomFlag IN NetFlags[TCount]) THEN

        EdgePtr := TAntetasks;
        maxplace := 0;

        WHILE (EdgePtr <> NIL) DO
            WITH EdgePtr^ DO
                IF (NOT (InvisibleEdge IN Attributes)) THEN
                    TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
                    IF (Xpos[TaskPtr^.XX] > maxplace) THEN
                        maxplace := Xpos[TaskPtr^.XX];
                    END;
                    headtask^.Methods^.UnlockUnchangedDataObject (headtask);
                END;
            END;
            EdgePtr := EdgePtr^.taillink;
        END;

        Xpos[TCount] := maxplace;
    END;

END AdjSubtasks;



PROCEDURE CheckVisible(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    s                       : ARRAY [0..255] OF CHAR;
    TaskPtr                 : ATaskPtr;
    TCount,indent           : INTEGER;
    ParentNode              : ATreeNode;

BEGIN
    IF (FatalNetError) THEN
        RETURN;
    END;

    (* Move the front of the master tasks into place *)
    TaskPtr := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    IF (InvisibleFlag IN TaskPtr^.TempTaskFlags) THEN
        TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
        RETURN;
    END;
    TCount := TaskPtr^.XX;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    indent := TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode);

    (* Record indents for latter processing *)

    IF (indent > MaxIndent) THEN
        FatalNetError := TRUE;
        GetMessage(ModuleNumber+4,s);
        Error(s);
    END;

    IF(NetworkType=Outline) THEN
        IF ((NetSummaryFlag IN NetFlags[TCount]) AND
            (NOT (NetPhantomFlag IN NetFlags[TCount])))  THEN
            Xpos[TCount] := Xpos[TCount]-MaxIndent+indent;
        END;
        IF (NetPhantomFlag IN NetFlags[TCount]) THEN
            Xpos[TCount] := Xpos[TCount]+MaxIndent-indent;
        END;
    END;

    INCL(NetFlags[TCount],ShouldDrawFlag);

    ParentNode := TaskTreeNode^.Methods^.Parent(TaskTreeNode);
    IF (ParentNode <> NIL) THEN
        IF (NOT(ParentNode^.Methods^.ChildrenVisible(ParentNode))) THEN
            EXCL(NetFlags[TCount],ShouldDrawFlag);
        END;
        TaskPtr := ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
        IF (NOT (ShouldDrawFlag IN NetFlags[TaskPtr^.XX])) THEN
            EXCL(NetFlags[TCount],ShouldDrawFlag);
        END;
        ParentNode^.Methods^.UnlockUnchangedDataObject(ParentNode);
    END;

    IF (NetworkType = Conventional) OR (HaveInfLoop) THEN   (* 9/28/89 EGK *)
        EXCL(NetFlags[TCount],NetSummaryFlag);
    END;

END CheckVisible;



PROCEDURE TimeSetupPass(VAR TaskTreeNode    : ATreeNode;
                           Context      : ADDRESS   );
VAR
    i, j, k, Temp   : INTEGER;
    edge            : AnEdgePtr;
    task            : ATaskPtr;
    taskhandle      : AnExtHandle;
    Count           : INTEGER;
    TimeInfo        : ATimeInfo;
    DateToUse       : ADate;
    OtherNode       : ATreeNode;
    othertask       : ATaskPtr;
    descendant      : ATaskPtr;
    s               : ARRAY [0..255] OF CHAR;

BEGIN
    IF (FatalNetError) THEN
        RETURN;
    END;
    NetFlags[TaskCount] := NetFlagSetType{};        (* 3/14/88 EGK *)
    taskhandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject (TaskTreeNode));
    IF (LockObject (taskhandle, task) = 0) THEN
        FatalError();
    END;
    TaskTreeNode^.Methods^.SetAttributeBit(TaskTreeNode,InvisibleNode,FALSE);
    IF(InvisibleFlag IN task^.TempTaskFlags ) THEN
        TaskTreeNode^.Methods^.SetAttributeBit(TaskTreeNode,InvisibleNode,TRUE);
        ReleaseUnchangedObject (taskhandle);         (* 3/14/88 EGK *)
       RETURN
    END;

    task^.XX:=TaskCount;     (* used to point to the task array *)
    task^.YY:=TaskCount;
 (* !!!!   task^.X:=MAXCARDINAL;  *)
    Xpos[TaskCount]:=0;         (* x box location *)
    Ypos[TaskCount]:=0;         (* y box location *)
    Utility[TaskCount]:=0;

    IF(PhantomFlag IN task^.TempTaskFlags) THEN
        OtherNode:=TaskTreeNode^.Methods^.GetPrev(TaskTreeNode);
        othertask:= OtherNode^.Methods^.LockFlexStorDataObject(OtherNode);
        othertask^.YY := TaskCount;         (* 11/21/89 EGK *)
        IF ((ArrangeBy = Baseline) AND (BaseLineExists IN othertask^.TaskFlags)) THEN
             DateToUse:=othertask^.BaseLine.Dates.EarlyEnd;
        ELSE (* ArrangeBy = Actual or baseline doesn't exist *)
             DateToUse:=othertask^.Plan.Dates.EarlyEnd;
        END;
        OtherNode^.Methods^.UnlockUnchangedDataObject(OtherNode);
    ELSE
        IF (SummaryFlag IN task^.TempTaskFlags) THEN    (* 11/21/89 EGK *)
            OtherNode := TaskTreeNode^.Methods^.GetNext (TaskTreeNode);
            othertask:= OtherNode^.Methods^.LockFlexStorDataObject(OtherNode);
            othertask^.YY := TaskCount;
            OtherNode^.Methods^.UnlockUnchangedDataObject(OtherNode);
        END;
        IF ((ArrangeBy = Baseline) AND (BaseLineExists IN task^.TaskFlags)) THEN
             DateToUse:=task^.BaseLine.Dates.EarlyStart;
        ELSE (* ArrangeBy = Actual or baseline doesn't exist *)
             DateToUse:=task^.Plan.Dates.EarlyStart;
        END;
    END;

    TimeUtoT (DateToUse,TimeInfo);
    WITH TimeInfo DO
        IF(TimeScaleNetwork) THEN
        CASE UnitsForScaling OF
                SHours,SDays:
                    Ypos[TaskCount]:=KDay(tiYear,tiMonth,tiDay);
            |    SWeeks:
                (* Need to do week calculation *)
                    Ypos[TaskCount]:=KDay(tiYear,tiMonth,tiDay)-
                    (7+DayOfWeek(tiYear,tiMonth,tiDay)-WeeksBeginOn) MOD 7;
            |    SMonths:
                    Ypos[TaskCount]:=KDay(tiYear,tiMonth,1);
            |    SQuarters:
                    Ypos[TaskCount]:=KDay(tiYear,(tiMonth DIV 3)*3,1);
            |    SYears:
                    Ypos[TaskCount]:=KDay(tiYear,0,1);
            ELSE
        END;
        ELSE (* Compressed Use Months  *)
            Ypos[TaskCount]:=0;
        END;
    END;

    loopnode^[TaskCount]:=TaskTreeNode;
    IF(NetworkType=Outline) THEN
       IF(SummaryFlag IN task^.TempTaskFlags) THEN
          INCL(NetFlags[TaskCount],NetSummaryFlag);
       END;
    END;
       IF( PhantomFlag IN task^.TempTaskFlags) THEN
          INCL(NetFlags[TaskCount],NetPhantomFlag);
       END;
    ReleaseObject(taskhandle);

    INC(TaskCount);
    (* This is the one place that we will write out the task record *)
    IF(TaskCount>=taskdim) THEN TooComplex(); END;
END TimeSetupPass;



PROCEDURE CheckForInvisibleEdges(VAR TaskTreeNode   : ATreeNode;
                                     Context        : ADDRESS   );
VAR
    edge            : AnEdgePtr;
    task            : ATaskPtr;
    taskhandle      : AnExtHandle;
    Count           : INTEGER;
    OtherNode       : ATreeNode;
    othertask       : ATaskPtr;
    descendant      : ATaskPtr;
    s               : ARRAY [0..255] OF CHAR;
    TempXX          : CARDINAL;
    TempTaskFlags   : ATempTaskFlagSet;

BEGIN
    IF (FatalNetError) THEN
        RETURN;
    END;

    IF (TaskTreeNode^.Methods^.TestAttributeBit (TaskTreeNode, InvisibleNode)) THEN
        RETURN;
    END;

    taskhandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject (TaskTreeNode));
    IF (LockObject (taskhandle, task) = 0) THEN
        FatalError();
    END;

    edge := task^.antetasks;
    (* See if this  task has any preceeding tasks *)

    WHILE (edge <> NIL) DO
        othertask:=edge^.headtask^.
                           Methods^.LockFlexStorDataObject(edge^.headtask);
        TempXX := othertask^.XX;
        edge^.headtask^.Methods^.
                            UnlockUnchangedDataObject(edge^.headtask);

        IF NOT (InvisibleEdge IN edge^.Attributes) THEN     (* 1/8/90 EGK *)
            IF (Ypos[task^.XX] < Ypos[TempXX]) THEN
                IF(TimeScaleNetwork) THEN
                    (* PrintSMsg("Marking dependentcies invisible at top"); *)
                    INCL(edge^.Attributes,InvisibleEdge);
                END;
            END;
        END;

        IF( NOT(InvisibleEdge IN edge^.Attributes)) THEN
            IF(PhantomFlag IN task^.TempTaskFlags) THEN (* check for end to end *)
                IF(NOT(PhantomSuccessor IN edge^.Attributes)) THEN
                    IF(NetworkType=Outline) THEN
                        INCL(edge^.Attributes,InvisibleEdge);   (* 9/28/89 KWC/EGK *)
                        IF(FirstWarning) THEN
                           FirstWarning:=FALSE;
                           GetMessage (ModuleNumber+5, s);     (* 9/18/89 EGK *)
                            (* "End-to-End dependencies cannot be honored" *)
                           Error (s);
                        END;   
                    END;
                END;
            END;
        END;  
        edge := edge^.taillink;
    END;

    edge := task^.desctasks;
    TempXX := task^.XX;                          (* 11/9/89 EGK *)
    TempTaskFlags := task^.TempTaskFlags;            (* 11/9/89 EGK *)
    ReleaseUnchangedObject (taskhandle);         (* 3/14/88 EGK *)

    WHILE (edge <> NIL) DO
        WITH edge^ DO
          descendant := tailtask^.Methods^.LockFlexStorDataObject (tailtask);

          IF NOT (InvisibleEdge IN Attributes) THEN     (* 1/8/90 EGK *)
              IF (Ypos[descendant^.XX] < Ypos[TempXX]) THEN  
                  IF (TimeScaleNetwork) THEN
                      (* PrintSMsg("Marking dependentcies invisible"); *)
                      INCL(Attributes,InvisibleEdge); 
                  END; 
              END;
          END;

          IF( NOT(InvisibleEdge IN Attributes)) THEN
               IF (SummaryFlag IN TempTaskFlags) THEN
                   IF(NOT(PhantomFlag IN TempTaskFlags)) THEN
                       IF(NOT(PhantomPredecessor IN Attributes)) THEN
                           IF(NetworkType=Outline) THEN
                               INCL(Attributes,InvisibleEdge);  (* 9/28/89 KWC/EGK *)
                               IF(FirstWarning) THEN
                                  FirstWarning:=FALSE;
                                  GetMessage (ModuleNumber+6, s);  (* 9/18/89 EGK *)
                                   (* "Start-to-Start dependencies cannot be honored" *)
                                  Error (s);
                               END;   
                           END;
                       END;
                   END;
               END;
           END;   
           tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
        END;                
       edge := edge^.headlink;
    END;
    
END CheckForInvisibleEdges;



PROCEDURE SetupPass(VAR TaskTreeNode    : ATreeNode;
                           Context      : ADDRESS   );
VAR
    i, j, k, Temp   : INTEGER;
    edge            : AnEdgePtr;
    task            : ATaskPtr;
    taskhandle      : AnExtHandle;
    Count           : INTEGER;
    OtherNode       : ATreeNode;
    othertask       : ATaskPtr;
    descendant      : ATaskPtr;
    TempXX          : CARDINAL;
    TempTaskFlags   : ATempTaskFlagSet;

BEGIN
    IF (FatalNetError) THEN
        RETURN;
    END;

        (* 30-Apr-91 RSC Seems to have been left out.
        *)
    IF (TaskTreeNode^.Methods^.TestAttributeBit (TaskTreeNode, InvisibleNode)) THEN
        RETURN;
    END;

    taskhandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject (TaskTreeNode));
    IF (LockObject (taskhandle, task) = 0) THEN
        FatalError();
    END;

    edge := task^.antetasks;

    (* See if this  task has any preceeding tasks *)
    i := 0;
    WHILE (edge <> NIL) DO
        othertask:=edge^.headtask^.
                           Methods^.LockFlexStorDataObject(edge^.headtask);
        TempXX := othertask^.XX;
        edge^.headtask^.Methods^.
                            UnlockUnchangedDataObject(edge^.headtask);

        IF (NOT (InvisibleEdge IN edge^.Attributes)) THEN
            INC(i);
        END;
        edge := edge^.taillink;
    END;

    (* i= 0 the this task is a starter *)

    IF (i = 1) THEN
        INCL (NetFlags[TaskCount],NetLeafFlag);
    ELSIF (i = 0) THEN
        TaskSave[forkcount] := taskhandle;
        IF (task^.duration > maxduration) THEN
            maxduration := task^.duration;
            longtask := forkcount;
         END;
         INC(forkcount);
         IF (forkcount >= forkmax) THEN
             TooComplex();
         END;
     END;
          
    (* check to see if this is a fork task *)

    edge := task^.desctasks;
    TempXX := task^.XX;                          (* 11/9/89 EGK *)
    TempTaskFlags := task^.TempTaskFlags;            (* 11/9/89 EGK *)
    ReleaseUnchangedObject (taskhandle);         (* 3/14/88 EGK *)

    i := 0;
    j := 0;

    WHILE (edge <> NIL) DO
        WITH edge^ DO
            IF ( NOT(InvisibleEdge IN Attributes)) THEN
                INC(j);
                    (* 30-Apr-91 RSC Seems to have been left out.
                    *)
                descendant := tailtask^.Methods^.LockFlexStorDataObject (tailtask); 
                IF (NOT (SummaryFlag IN descendant^.TempTaskFlags)) THEN
                    INC(i);
                END;
                tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
            END;
        END;
        edge := edge^.headlink;
    END;

    IF (j = 1) THEN   
        INCL(NetFlags[TaskCount],NetBranchFlag); 
    END;

    (* if i is greator then 1 then it is a fork task *)

    IF (i > 1) THEN
        IF ((NetworkType = Conventional) OR
            (NOT (NetSummaryFlag IN NetFlags[TaskCount]))) THEN
            DeList(taskhandle);
            AddBefore(ForkListHandle, taskhandle);
            INCL(NetFlags[TaskCount],ForkListFlag);
        END;
    END;

    INC(TaskCount);

    (* This is the one place that we will write out the task record *)

    IF (TaskCount >= taskdim) THEN 
        TooComplex(); 
    END;

END SetupPass;



PROCEDURE TEMP(TaskTreeNode : ATreeNode;
               TaskNode: ATaskPtr);
BEGIN
END TEMP;



PROCEDURE MarkInfLoopTasks ( VAR TaskTreeNode   : ATreeNode;
                                 Context        : ADDRESS   );
VAR
    TaskPtr         : ATaskPtr;
    TaskHandle      : AnExtHandle;

BEGIN
    TaskHandle := AnExtHandle(TaskTreeNode^.Methods^.
                              GetDataObject(TaskTreeNode));
    IF (LockObject(TaskHandle,TaskPtr) = 0) THEN
        FatalError();
    END;
    IF (InvisibleFlag IN TaskPtr^.TempTaskFlags ) THEN
        ReleaseUnchangedObject(TaskHandle);
        RETURN;
    END;

    IF (Xpos[TaskPtr^.XX] = 0) OR (Xpos[TaskPtr^.XX] >= infloopcount) THEN
        IF (TaskPtr^.desctasks <> NIL) THEN
            TaskSave[infloopindex] := TaskHandle;
            INC(infloopindex);
        END;
    END;

    Utility[TaskPtr^.XX] := 0;
    Xpos[TaskPtr^.XX] := 1;

    ReleaseUnchangedObject(TaskHandle);

    AddBefore(PrivateTaskList,TaskHandle);

END MarkInfLoopTasks;



PROCEDURE FindInfLoop;
VAR
    i                   : INTEGER;
    currtask            : ATaskPtr;
    EdgePtr             : AnEdgePtr;
    DescendantNode      : ATreeNode;
    descendantcount     : INTEGER;
    descendant          : ATaskPtr;

BEGIN
    infloopindex := 0;
    infloopcount := TaskCount*ColStep+ColStep;

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    MarkInfLoopTasks, NIL);

    DiscardExtObject(StackListHandle);
    IF (NOT ListInit(StackListHandle)) THEN         (* 9/25/89 EGK *)
        FatalNetError := TRUE;
    END;

    i := 0;
    LOOP
        IF (i >= infloopindex) THEN
            EXIT;
        END;

        DeList(TaskSave[i]);
        AddBefore(StackListHandle,TaskSave[i]);

        currtaskhandle := TaskSave[i];
        INC(floodkey);

        IF (LockObject(currtaskhandle,currtask) = 0) THEN
            FatalError();
        END;
        Utility[currtask^.XX] := floodkey;
        ReleaseUnchangedObject(currtaskhandle);

        FindKey;

        IF (endtaskhandle <> AnExtHandle(NIL)) THEN
            EXIT;
        END;
        INC(i);
    END;

    IF (endtaskhandle = AnExtHandle(NIL)) THEN
        (*<DEBUGGING PrintSMsg("Unable to process loop"); DEBUGGING>*)
        FatalNetError := TRUE;
        RETURN;
    END;
    DEC(lowerloop);

    (* PrintSCard(ORD(lowerloop),"The value of lower loop ");  *)
    FOR i := 1 TO lowerloop DO
        Xpos[Ymaxpos[i]] := -infloopcount;
        Ypos[Ymaxpos[i]] := 0;
    END;

    currtaskhandle := endtaskhandle;
    LOOP
        IF (LockObject(currtaskhandle,currtask) = 0) THEN
            FatalError();
        END;
        EdgePtr := currtask^.desctasks;
        ReleaseUnchangedObject(currtaskhandle);

        LOOP
            IF (NOT (InvisibleEdge IN EdgePtr^.Attributes)) THEN
                DescendantNode := EdgePtr^.tailtask;
                descendanthandle := AnExtHandle(DescendantNode^.Methods^.
                                                GetDataObject(DescendantNode));
                IF (LockObject(descendanthandle,descendant) = 0) THEN
                    FatalError();
                END;
                descendantcount := descendant^.XX;
                ReleaseUnchangedObject(descendanthandle);

                IF (Xpos[descendantcount] = -infloopcount) THEN
                    EXIT;
                END;
            END;
            EdgePtr := EdgePtr^.headlink;
        END;

        IF (Ypos[descendantcount] > 0) THEN
            inflooptaskhandle := descendanthandle;
            EXIT;
        END;
        Ypos[descendantcount] := 1;
        currtaskhandle := descendanthandle;
    END;

END FindInfLoop;



PROCEDURE InitLists();
VAR
    OK              : BOOLEAN;

BEGIN

    OK := ListInit(PrivateTaskList);                (* 9/25/89 EGK *)
    OK := OK AND ListInit(StackListHandle);
    OK := OK AND ListInit(ForkListHandle);

    FatalNetError := NOT OK;
    HaveInfLoop := FALSE;

END InitLists;



PROCEDURE DiscardLists();
BEGIN
    DiscardExtObject(PrivateTaskList);
    DiscardExtObject(ForkListHandle);
    DiscardExtObject(StackListHandle);
END DiscardLists;



PROCEDURE TSort;
VAR
    MaxColPos, Index    : CARDINAL;
    i,ii,j,Adjust,Hit   : INTEGER;
    maxcount,colpos,
    OldMaxT,OldMaxO,
    MaxO,MaxT           : INTEGER;
    OtherNode           : ATreeNode;
    othertask           : ATaskPtr;
    ErrorMessage        : ARRAY [ 0..255] OF CHAR;
    temptaskhandle      : AnExtHandle;
    StackList           : ATaskPtr;
    currtask            : ATaskPtr;
    EdgePtr             : AnEdgePtr;
    DescendantNode      : ATreeNode;
    descendant          : ATaskPtr;

BEGIN
  (*
  ****  Create a lists for processing  ****
                                  *)
    InitLists();

(* *********** Temp Code to simulate Time Scaling *** *)
    nextgroup:=0;
    i := 0;
    loopcnt := 0;
    upperloop:=0;
    lowerloop:=0;
    endloop := 0;
    Ymaxpos[0]:=0;

    Scan1(TEMP);

    IF (NOT CreateSummaryPhantoms()) THEN
        FatalNetError := TRUE;
        DiscardLists();
        RETURN;
    END;

    (* Link all of the tasks into a chain. *)
    maxduration := NoDuration;
    longtask := 0;
    TaskCount := 1;
    forkcount := 0;
    forktaskcount := 0;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    TimeSetupPass, NIL);

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    CheckForInvisibleEdges, NIL);   (* 6/7/90 EGK *)

    TaskCount := 1;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    SetupPass, NIL);
    IF (FatalNetError) THEN
        DiscardLists();
        RETURN;
    END;

    IF (TaskCount = 1) THEN
        GetMessage(ModuleNumber,ErrorMessage);
        (* No tasks found to place in network.*)
        Error(ErrorMessage);
        FatalNetError := TRUE;
        DiscardLists();
        RETURN;
    END;

    DEC(TaskCount);
(*
    FOR i := 1 TO TaskCount DO
        IF (NetSummaryFlag IN NetFlags[i]) THEN
            IF (NetPhantomFlag IN NetFlags[i]) THEN
                OtherNode := loopnode^[i]^.Methods^.GetPrev(loopnode^[i]);
            ELSE
                OtherNode := loopnode^[i]^.Methods^.GetNext(loopnode^[i]);
            END;
            othertask :=  OtherNode^.Methods^.
                                LockFlexStorDataObject(OtherNode);
            othertask^.YY := i;
            OtherNode^.Methods^.UnlockFlexStorDataObject(OtherNode);
        END;
    END;
*)


    (* swap the first task with the max task,
       try for the critical path  on the fork ends list *)

    IF (longtask <> 0) THEN
        temptaskhandle := TaskSave[0];
        TaskSave[0] := TaskSave[longtask];
        TaskSave[longtask] := temptaskhandle;
    END;

    floodkey := 0;

(*
   ****** Find the col position in the matrix ******
                                                       *)

    infloopcount := TRUNC(1.6*FLOAT(TaskCount*ColStep))+ColStep;
    IF (TaskCount < 100) THEN
        infloopcount := 2*TaskCount*ColStep+ColStep;
    END;

    IF (maxtask > 1000) THEN
        (*<DEBUGGING PrintSMsg("Too many tasks for integer loop detection "); DEBUGGING>*)
    END;

    IF (forkcount = 0) THEN
        (* PrintSMsg("No entry into system"); *)
        HaveInfLoop := TRUE;
        GetMessage(ModuleNumber+1,ErrorMessage);
        Error(ErrorMessage);
        (* Infinite Loop Found *)
        FindInfLoop();
        DiscardLists();
        RETURN;
    END;

    FOR i := 0 TO forkcount-1 DO
        DeList(TaskSave[i]);
        AddBefore(StackListHandle,TaskSave[i]);

        IF (LockObject(StackListHandle,StackList) = 0) THEN
            FatalError();
        END;
        currtaskhandle := StackList^.Prevlink;
        ReleaseUnchangedObject(StackListHandle);

        IF (LockObject(currtaskhandle,currtask) = 0) THEN
            FatalError();
        END;
        Xpos[currtask^.XX] := 1;
        ReleaseUnchangedObject(currtaskhandle);

        LOOP
            IF (ObjectsAreSame(currtaskhandle,StackListHandle)) THEN
                EXIT;
            END;

            IF (LockObject(currtaskhandle,currtask) = 0) THEN
                FatalError();
            END;
            EdgePtr := currtask^.desctasks;

            WHILE (EdgePtr <> NIL) DO
                IF (NOT (InvisibleEdge IN EdgePtr^.Attributes)) THEN
                    DescendantNode := EdgePtr^.tailtask;
                    descendanthandle := AnExtHandle(DescendantNode^.Methods^.
                                                    GetDataObject(DescendantNode));

                    IF (LockObject(descendanthandle,descendant) = 0) THEN
                        FatalError();
                    END;

                    IF (InvisibleFlag IN descendant^.TempTaskFlags ) THEN
                        (* PrintSMsg("Oops the decendent is not visable "); *)
                    END;

                    (* Check To See if this member needs to be Adjusted *)
                    Adjust := NoAdjust;
                    IF (Ypos[descendant^.XX] < Ypos[currtask^.XX]) THEN
                        IF(TimeScaleNetwork) THEN
                          (* PrintSMsg("Marking dependentcies invisible"); *)
                          INCL(EdgePtr^.Attributes,InvisibleEdge);
                          IF(Xpos[descendant^.XX]=0) THEN
                            Xpos[descendant^.XX]:=1;
                          END;
                        ELSE
                          Ypos[descendant^.XX] := Ypos[currtask^.XX];
                          Xpos[descendant^.XX] := Xpos[currtask^.XX];
                        END;
                    END;
                    IF ((Ypos[descendant^.XX] = Ypos[currtask^.XX]) AND
                        (Xpos[descendant^.XX] <=Xpos[currtask^.XX])) THEN
                       Adjust := IncXpos;
                    END;
                    IF ((Ypos[descendant^.XX] > Ypos[currtask^.XX]) AND
                        (Xpos[descendant^.XX] = 0))    THEN
                        Adjust := SetXpos;
                    END;

                    IF (Adjust <> NoAdjust) THEN

                        IF (Xpos[descendant^.XX] >= infloopcount) THEN
                            HaveInfLoop := TRUE;
                            ReleaseUnchangedObject(currtaskhandle);
                            ReleaseUnchangedObject(descendanthandle);
                            GetMessage(ModuleNumber+1,ErrorMessage);
                            Error(ErrorMessage);
                            (* PrintSMsg("Normal inf loop"); *)
                            (* Infinite Loop Found *)
                            FindInfLoop;
                            DiscardLists();
                            RETURN;
                        END;

                        DeList(descendanthandle);
                        AddBefore(StackListHandle,descendanthandle);
                        IF(NetSummaryFlag IN NetFlags[descendant^.XX]) THEN
                            IF (Adjust = IncXpos) THEN
                                Xpos[descendant^.XX] := Xpos[currtask^.XX];
                            ELSE
                                Xpos[descendant^.XX] := 1;
                            END;
                        ELSE
                            IF (Adjust = IncXpos) THEN
                                Xpos[descendant^.XX] := Xpos[currtask^.XX]+1;
                            ELSE
                                Xpos[descendant^.XX] := 1;
                            END;
                        END;

                    (* IF((Xpos[descendant^.XX]>infloopcount) AND
                       (HaveInfLoop=FALSE)) THEN
                       HaveInfLoop := TRUE;
                       inflooptask := descendant^.XX;
                    END; *)

                    (* PrintTask(descendant,"For ");
                    PrintCard(ORD(Xpos[descendant^.XX]),
                    "The Value is now "); *)

                    END;
                    ReleaseUnchangedObject(descendanthandle);
                END;
                EdgePtr := EdgePtr^.headlink;
            END;

            DeList(currtaskhandle);
            IF (ForkListFlag IN NetFlags[currtask^.XX] ) THEN
                AddBefore(ForkListHandle, currtaskhandle);
            ELSE
                AddBefore(PrivateTaskList, currtaskhandle);
            END;

            ReleaseUnchangedObject(currtaskhandle);

            IF (LockObject(StackListHandle,StackList) = 0) THEN
                FatalError();
            END;
            currtaskhandle := StackList^.Prevlink;
            ReleaseUnchangedObject(StackListHandle);
        END;
    END;

    (* Adjust to real column position *)

    OldMaxT := MaxInt;
    OldMaxO := MaxInt;
    MaxColPos := 0;
    colpos := 0;

    FOR i := 1 TO TaskCount DO
        MaxT := MaxInt-1;
        MaxO := MaxInt-1;
        Hit := 0;

        FOR j := 1 TO TaskCount DO
            IF (Xpos[j] = 0) THEN
                GetMessage(ModuleNumber+1,ErrorMessage);
                HaveInfLoop := TRUE;
                Error(ErrorMessage);
                (* Infinite Loop Found *)
                FindInfLoop;
                RETURN;
            END;

            IF (Ypos[j] < MaxT) THEN
                MaxT := Ypos[j];
                MaxO := Xpos[j];
                Hit := j;
            ELSIF ((Ypos[j] = MaxT) AND (Xpos[j] < MaxO)) THEN
                MaxO := Xpos[j];
                Hit := j;
            END;
        END;

        IF (Hit > 0) THEN
            IF ((OldMaxT <> MaxT) OR (OldMaxO <> MaxO)) THEN
                INC(colpos);
            END;
            Ypos[Hit] := MaxInt;
            Xpos[Hit] := colpos*ColStep;
            IF (ORD(Xpos[Hit]) > MaxColPos) THEN
                MaxColPos := Xpos[Hit];
            END;
            OldMaxT := MaxT;
            OldMaxO := MaxO;
        END;
    END;

    FOR i := 1 TO TaskCount DO
        Ypos[i] := 0;
    END;

    (* Adjust all the cols so that a subtask is in the proper place *)

    IF(NetworkType=Outline) THEN
        TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                      AdjSubtasks, NIL);
    END;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                      CheckVisible, NIL);

    IF (FatalNetError) THEN
        DiscardLists();
        RETURN;
    END;

    IF (HaveInfLoop) THEN
        GetMessage(ModuleNumber+1,ErrorMessage);
        Error(ErrorMessage);
        (* Infinite Loop Found *)
        (* PrintSMsg("Tree inf loop found"); *)
        FindInfLoop;
    END;

    DiscardLists();

END TSort;



PROCEDURE FindKey;

VAR
    i               : INTEGER;
    CDescTasks      : AnEdgePtr;
    CTaskNo         : INTEGER;
    TaskPtr         : ATaskPtr;
    EdgePtr         : AnEdgePtr;
    Node            : ATreeNode;
    DHandle         : AnExtHandle;
    DTaskNo         : INTEGER;


    PROCEDURE FirstVisibleDescendant ( TaskPtr      : ATaskPtr ) : AnEdgePtr;
    VAR
        EdgePtr             : AnEdgePtr;
    BEGIN
        EdgePtr := TaskPtr^.desctasks;
        LOOP
            IF (EdgePtr = NIL) OR
               (NOT (InvisibleEdge IN EdgePtr^.Attributes)) THEN
                EXIT;
            END;
            EdgePtr := EdgePtr^.headlink;
        END;
        RETURN EdgePtr;
    END FirstVisibleDescendant;


BEGIN
    endtaskhandle := AnExtHandle(NIL);
    lowerloop := 0;
    Ymaxpos[lowerloop] := forktaskcount;
    INC(lowerloop);

    LOOP
        IF (ObjectsAreSame(currtaskhandle,StackListHandle)) THEN
            EXIT;
        END;

        IF (LockObject(currtaskhandle,TaskPtr) = 0) THEN
            FatalError();
        END;
        EdgePtr := FirstVisibleDescendant (TaskPtr);        (* 9/18/89 EGK *)
        CTaskNo := TaskPtr^.XX;
        ReleaseUnchangedObject (currtaskhandle);

        WHILE (EdgePtr = NIL) DO

        (* We went to the end of the plan and did not find the floodkey *)
            (* PrintMsg("backtracking"); *)

            Ymaxpos[lowerloop] := CTaskNo;
            INC(lowerloop);

            IF (lowerloop >= loopdim) THEN
                IF (NOT HaveInfLoop) THEN
                    TooComplex();
                END;
                RETURN;
            END;

            i := lowerloop;
            WHILE (CTaskNo = Ymaxpos[i-1]) DO
                DEC(i);
                DeList(currtaskhandle);
                IF (ForkListFlag IN NetFlags[CTaskNo]) THEN
                    AddBefore(ForkListHandle, currtaskhandle);
                ELSE
                    AddBefore(PrivateTaskList,currtaskhandle);
                END;

                IF (i = 0) THEN
                    endtaskhandle:=AnExtHandle(NIL);
                    (* PrintSMsg("Using a Null endtask 2"); *)
                    EXIT;
                END;

                IF (LockObject(StackListHandle,TaskPtr) = 0) THEN
                    FatalError();
                END;
                currtaskhandle := TaskPtr^.Prevlink;
                ReleaseUnchangedObject(StackListHandle);

                IF (ObjectsAreSame(currtaskhandle,StackListHandle)) THEN
                    endtaskhandle := AnExtHandle(NIL);
                    (* PrintMsg("Using a Null endtask 1");  *)
                    EXIT;
                END;

                IF (LockObject(currtaskhandle,TaskPtr) = 0) THEN
                    FatalError();
                END;
                CDescTasks := FirstVisibleDescendant (TaskPtr);     (* 9/18/89 EGK *)
                CTaskNo := TaskPtr^.XX;
                ReleaseUnchangedObject (currtaskhandle);
            END;

            EdgePtr := CDescTasks;
            lowerloop := i;
        END;

        IF ((NOT HaveInfLoop) AND (Utility[CTaskNo] = floodkey)) THEN
            endtaskhandle := currtaskhandle;
            (* PrintSTask(currtask,"Current task is ender ");  *)
            EXIT;
        END;

        WHILE (EdgePtr <> NIL) DO

            IF NOT (InvisibleEdge IN EdgePtr^.Attributes) THEN      (* 9/18/89 EGK *)
                Node := EdgePtr^.tailtask;
                DHandle := AnExtHandle(Node^.Methods^.GetDataObject(Node));
                IF (LockObject(DHandle, TaskPtr) = 0) THEN
                    FatalError();
                END;
                DTaskNo := TaskPtr^.XX;
                ReleaseUnchangedObject (DHandle);

                (* PrintSTask(descendant,"Descendant in findkey "); *)
                IF (Utility[DTaskNo] = floodkey) THEN
                    Ymaxpos[lowerloop] := CTaskNo;
                    INC(lowerloop);
                    endtaskhandle := DHandle;
                    EXIT;
                END;

                DeList(DHandle);
                AddBefore(StackListHandle,DHandle);
            END;

            EdgePtr := EdgePtr^.headlink;
        END;

        Ymaxpos[lowerloop] := CTaskNo;
        INC(lowerloop);

        IF ((lowerloop > TaskCount) OR (lowerloop >= loopdim)) THEN
            endtaskhandle := AnExtHandle(NIL);
            IF (NOT HaveInfLoop) THEN
                TooComplex();
            END;

            FOR i := 1 TO TaskCount DO
                Node := loopnode^[i];
                DHandle := AnExtHandle (Node^.Methods^.GetDataObject (Node));
                AddBefore(PrivateTaskList,DHandle);
            END;

            DiscardExtObject(StackListHandle);
            IF (NOT ListInit(StackListHandle)) THEN     (* 9/25/89 EGK *)
                FatalNetError := TRUE;
            END;
            EXIT;
        END;

        IF (LockObject(StackListHandle,TaskPtr) = 0) THEN
            FatalError();
        END;
        currtaskhandle := TaskPtr^.Prevlink;
        ReleaseUnchangedObject(StackListHandle);
    END;
END FindKey;



BEGIN

    TimeScaleNetwork := FALSE;

    ContextPointer:= OverlayContext();   (* find out which tree they want *)
    IF (ContextPointer <> NIL) AND (LengthOf(ContextPointer^) > 0) THEN
        IF (ContextPointer^[1] = "G") THEN
            InitializeNetworkData();
        END;
    END;

    MatrixOverflow := FALSE;
    FirstWarning := TRUE;

END TSort.

