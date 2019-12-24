IMPLEMENTATION MODULE TSort2;

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
        20-Sep-89 EGK   Created this from the TSort module, to allow the
                        annealing code to be separated from the rest of
                        TSort.
        25-Sep-89 EGK   Use a thermometer bar to indicate progress.  Check
                        for ctrl-break at the bottom of the main annealing
                        loop.   
        3-Nov-89  KWC   Linkrows was causing overlapping tasks                                      
       21-Nov-89  EGK   Moved TaskList from SpreadSubTasks to the global
                        area, allowing it to be expanded without chewing
                        up stack space, and set its upper limit to be
                        "taskdim".  Removed progress box code, since that's
                        now handled in TLNCALC.
      11-Dec-89   KWC   Fixed drooping tasks in outline mode                  
    *)

FROM Allocs          IMPORT
    (* TYPE *)          ATaskPtr,
                        ATaskFlag,
    (* VAR *)           TaskTree;

FROM Dialog          IMPORT   
                        Message, Error, FatalError;


FROM Edges           IMPORT
    (* TYPE *)          AnEdge, AnEdgePtr,
                        InvisibleEdge,PhantomSuccessor,PhantomPredecessor;

(*
*)
FROM ErrorUtil       IMPORT   
                        PrintMsg,PrintCard,PrintTask,
                        PrintSMsg,PrintSCard,PrintSTask;

FROM FlexStor        IMPORT
    (* TYPE *)          AnExtHandle,ObjectsAreSame,DiscardExtObject,
    (* Proc *)          LockObject,ReleaseObject,ReleaseUnchangedObject;
   
FROM Kbio                   IMPORT
    (* PROC *)                  BreakRequested, ClearBreak;

FROM LStrings        IMPORT
                        SetString, ConcatLS, CtoS;

FROM MsgFile         IMPORT 
                        GetMessage;
    
FROM MathLib0        IMPORT  
                        exp;

FROM NetBData        IMPORT   
                        TaskCount,
                        NetFlags,NetFlagType,NetFlagSetType;
   
FROM NetStatic       IMPORT
                        taskdim, SnetCols, DimWidth,
                        SnetWidth, HaveInfLoop,
                        FatalNetError, Xpos, Ypos,
                        Xmaxpos, Ymaxpos, Utility,
                        loopnode, maxtask;
                        
FROM NetworkData            IMPORT
    (* TYPE *)                  ANetworkType,AnAnnealingChoice,
    (* VAR *)                   AnnealingChoice,NetworkType;

FROM Progress               IMPORT
    (* TYPE *)                  AThermometer,
    (* PROC *)                  CreateThermometer, UpdateThermometer,
                                DiscardThermometer;

FROM TreeObjects     IMPORT
    (* TYPE *)          ATree, ATreeNode,ATreeOrder,TempFlag4;

     
FROM SYSTEM          IMPORT
                        ADDRESS;
    
    

CONST
    ModuleNumber            = 20300;  (* For GetMessage *)
    MaxInt                  = 32000;
    InvisibleNode           = TempFlag4;
    TaskBias                = 2000;

TYPE
    PassingRecord= RECORD
                     CASE  passvartype: BOOLEAN OF
                       TRUE: Integer: INTEGER; |
                       FALSE: TreeNode: ATreeNode
                     END;
                   END;   
    PassingRecord2= RECORD
                     CASE  passvartype: BOOLEAN OF
                       TRUE: Integer: INTEGER; |
                       FALSE: Address: ADDRESS
                     END;
                   END;   
VAR

(* Annealing Vars *)

    crosshit            : CARDINAL;
    lastpass            : INTEGER;
    RowsCounted         : INTEGER;

    TaskSave            : ARRAY [0..taskdim] OF AnExtHandle;
    TAntetasksArray     : ARRAY [0..taskdim] OF  AnEdgePtr;
    TDesctasksArray     : ARRAY [0..taskdim] OF  AnEdgePtr;
    TaskList            : ARRAY [0..taskdim] OF INTEGER;    (* 11/21/89 EGK *)
    
    SubtaskBias,YBias   : INTEGER;
    s1, s2, s3          : INTEGER;

    PassingVar          : PassingRecord;
    PassingVar2         : PassingRecord2;

    ProbFunc            : ARRAY [0..50] OF INTEGER;




PROCEDURE PrintSCardMsg(num : CARDINAL; Msg: ARRAY OF CHAR);
VAR
    s1          : ARRAY [0..255] OF CHAR;
    s2          : ARRAY [0..255] OF CHAR;
BEGIN
    CtoS(num,s2);
    SetString(s1,Msg);
    ConcatLS(s1,s2);
    Message(s1);  
END PrintSCardMsg;

    


PROCEDURE StartThermometer ( VAR Thermometer    : AThermometer;
                                 MaxCount       : CARDINAL      );
VAR
    s               : ARRAY [0..255] OF CHAR;
    OK              : BOOLEAN;
BEGIN
    GetMessage (ModuleNumber+7, s);     (* "iterations completed" *)
    OK := CreateThermometer (Thermometer, 0, 0, s, MaxCount);
END StartThermometer;



PROCEDURE TSort2;
VAR
    task        : ATaskPtr;
    k,i,j,indent,starttask: INTEGER;
    edge            : AnEdgePtr;
    CurrentRow,ThisRow :INTEGER;
    nexttask,lasttask,TaskID :INTEGER;
    InAChannel,Moved: BOOLEAN;
    stack: ARRAY [0..20] OF INTEGER;
    level,LastOnThread,FirstOnThread: CARDINAL;
    phantomnode     : ATreeNode;

BEGIN
    IF (HaveInfLoop) THEN
        RETURN;
    END;

    (* Sort x array to take out holes *)
      CompressArrays();

    (* Change the dependency pointers from tree nodes to indexes *)
      
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    DepList2Pointer, NIL);
    (* Change the tree pointers from task nodes to indexes *)

    TaskCount:=1;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    Tree2Pointer, NIL);
    FOR i:=0 TO TaskCount DO
      Ypos[i]:=0;
      Xmaxpos[i]:=0;
      Ymaxpos[i]:=0;
      Utility[i]:=0;
    END;
    
    DEC(TaskCount);
  
    (* Place tasks in channels *)
    FOR i:=0 TO taskdim  DO
      Xmaxpos[i]:=0;
    END;
    
    FOR j:=1 TO TaskCount DO
      IF(LockObject(TaskSave[j],task)=0) THEN
                        FatalError(); END;
      TDesctasksArray[j] := task^.desctasks;
      TAntetasksArray[j] := task^.antetasks;
      ReleaseUnchangedObject(TaskSave[j]);
    END;
(* Find threads and assign rows to them *)

    RowsCounted:=0;
    FOR j:=1 TO TaskCount DO
      Ypos[j]:=0;
      Ymaxpos[j]:=j;
      Utility[j]:=j;

      IF(NetBranchFlag IN NetFlags[j]) THEN
         nexttask:=j;
         LOOP
           edge := TDesctasksArray[nexttask];
           WHILE(InvisibleEdge IN edge^.Attributes) DO
              edge := edge^.headlink;
              IF(edge=NIL) THEN EXIT; END;
           END;
           PassingVar.TreeNode:=edge^.tailtask;
           lasttask:=nexttask;
           nexttask:=PassingVar.Integer;
        (*   PrintSCard(ORD(nexttask),"Next Dec task is "); *)
           IF((TDesctasksArray[nexttask]=NIL) OR
                (NOT(NetBranchFlag IN NetFlags[nexttask])) OR
                (NOT(NetLeafFlag IN NetFlags[nexttask]))) THEN EXIT; END;
         END;       
         Ymaxpos[j]:=nexttask;       
         IF(NOT(NetLeafFlag IN NetFlags[nexttask])) THEN
           Ymaxpos[j]:=lasttask;
         END;
      END;   
      IF (NetLeafFlag IN NetFlags[j]) THEN
         nexttask:=j;
         LOOP
           edge := TAntetasksArray[nexttask];
           WHILE(InvisibleEdge IN edge^.Attributes) DO
                 edge := edge^.taillink;
                 IF(edge=NIL) THEN EXIT; END;
           END;
           PassingVar.TreeNode:=edge^.headtask;
           lasttask:=nexttask;
           nexttask:=PassingVar.Integer;
        (*   PrintSCard(ORD(nexttask),"Next Ant task is "); *)
            IF((TAntetasksArray[nexttask]=NIL) OR
                (NOT(NetBranchFlag IN NetFlags[nexttask])) OR
                (NOT(NetLeafFlag IN NetFlags[nexttask]))) THEN EXIT; END;
         END;       
         Utility[j]:=nexttask;       
         IF(NOT(NetBranchFlag IN NetFlags[nexttask])) THEN
           Utility[j]:=lasttask;
         END;
       END;  
       IF(Utility[j]=j) THEN 
         Xmaxpos[j]:=j;
       END;
    END;
    (* Preform the actual calculations to determin box position *)
    RowsCounted:=0;
    FOR j:=1 TO TaskCount DO
      IF(Xmaxpos[j]<>0) THEN
        INC(RowsCounted);
        Xmaxpos[RowsCounted]:=Xmaxpos[j];
        Ypos[Ymaxpos[j]]:=RowsCounted;
        Ypos[Utility[j]]:=RowsCounted;
      END;
    END;
    IF(RowsCounted>1) THEN AnnealPlan; END;
    
(* Link Rows that have come appart *)
   IF((NetworkType<>Outline) AND (RowsCounted>1))THEN
      LinkRows; 
   END;
   
(* Fix threads so that they all have the same value *)

    FOR j:=1 TO taskdim  DO
      IF(Ymaxpos[j]>TaskBias) THEN DEC(Ymaxpos[j],TaskBias); END;
      IF(Utility[j]>TaskBias) THEN DEC(Utility[j],TaskBias); END;
      IF(Xmaxpos[j]<>0) THEN
         starttask:=Xmaxpos[j];
         nexttask:=starttask;
         (* PrintSCard(ORD(nexttask),"Next start task is "); *)
         IF(NetBranchFlag IN NetFlags[starttask]) THEN
           LOOP
             edge := TDesctasksArray[nexttask];
             IF(edge<>NIL) THEN
               WHILE(InvisibleEdge IN edge^.Attributes) DO
                  edge := edge^.headlink;
                  IF(edge=NIL) THEN EXIT; END;
               END;
               PassingVar.TreeNode:=edge^.tailtask;
               nexttask:=PassingVar.Integer;
               IF(NetLeafFlag IN NetFlags[nexttask]) THEN
                 Ypos[nexttask]:=Ypos[starttask];
               END; 
             END;
             (* PrintSCard(ORD(nexttask),"Next Dec task is "); *)
             IF((TDesctasksArray[nexttask]=NIL) OR
                (edge=NIL) OR
                (NOT(NetBranchFlag IN NetFlags[nexttask])) OR
                (NOT(NetLeafFlag IN NetFlags[nexttask]))) THEN EXIT; END;
          END;      
        END;        
      END;
    END; 
    FOR i:=0 TO TaskCount DO
      Xmaxpos[i]:=0;
      Ymaxpos[i]:=0;
      Utility[i]:=0;
    END;
   
    IF(NetworkType=Outline) THEN
      TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                    ComputeMaxMin, NIL);
      TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                    SpreadSubTasks, NIL);
      TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    SpreadSubTasksAdj, NIL);
    END;                                 
    (* Put back x values for drawing *)
    FOR j:=1 TO TaskCount DO
      IF(NetSummaryFlag IN NetFlags[j]) THEN 
        IF(NOT(NetPhantomFlag IN NetFlags[j])) THEN
          Ypos[j]:=20*Ypos[j];
          phantomnode:= loopnode^[j]^.Methods^.GetNext(loopnode^[j]);
          PassingVar2.Address:=phantomnode^.Methods^.GetDataObject(phantomnode);
          Ypos[PassingVar2.Integer]:=20*Ymaxpos[j];
        END; 
      ELSE
        Ypos[j]:=20*Ypos[j];
      END;
    END;
    TaskCount:=1;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    Pointer2Tree, NIL);
    DEC(TaskCount);

    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                    Pointer2DepList, NIL);

END TSort2;



PROCEDURE LinkRows;
VAR
    k,i,j,minrow,xstart,xend: INTEGER;
    edge            : AnEdgePtr;
    CurrentRow,ThisRow,NextRow :INTEGER;
    TaskID,NextTask,closetask,maxdiff,diff :INTEGER;
    Moved: BOOLEAN;
     
BEGIN
   
   (* Clear the width array *)
   
    FOR i := 0 TO DimWidth DO
        SnetWidth^[i] := -1;
    END;       
   (* Condense rows *)
   ThisRow:=1;
   REPEAT
       TaskID:=Xmaxpos[ThisRow];
       (* Is there a place to hook on to? *)
       NextTask:=TaskID;
       REPEAT
           closetask:=0;
           maxdiff:=MaxInt;
           IF(ORD(Utility[NextTask])<TaskBias) THEN
               edge := TAntetasksArray[Utility[NextTask]];
               (* Find the guy who is closest *)
               LOOP
                   IF(edge=NIL) THEN
               EXIT
                   END;   
                   WITH edge^ DO
                       IF(NOT(InvisibleEdge IN Attributes)) THEN
                           PassingVar.TreeNode:=headtask;
                           IF(ORD(Ymaxpos[PassingVar.Integer])<TaskBias) THEN
                               diff:=Ypos[Ymaxpos[PassingVar.Integer]]-ThisRow;
                               IF((diff>0) AND (diff<maxdiff)) THEN
                                   maxdiff:=diff;
                                   closetask:=PassingVar.Integer;
                               END;     
                           END;  
                       END;
                       edge := edge^.taillink;
                   END;
               END;
     
               IF(closetask<>0) THEN
                   Ypos[Ymaxpos[closetask]]:=ThisRow;
                   Ypos[Utility[closetask]]:=ThisRow;
                   INC(Utility[NextTask],TaskBias); (* KWC 11/3/89 *)
                   INC(Ymaxpos[Ymaxpos[closetask]],TaskBias);
                   INC(Ymaxpos[closetask],TaskBias);
                   NextTask:=closetask;
               END;
           END;    
       UNTIL closetask=0;



     (* Is there a place to hook on to? *)
     NextTask:=TaskID;
     REPEAT
         closetask:=0;
         maxdiff:=MaxInt;
         IF(ORD(Ymaxpos[NextTask])<TaskBias) THEN
             edge := TDesctasksArray[Ymaxpos[NextTask]];
             (* Find the guy who is closest *)
             LOOP
                IF(edge=NIL) THEN
             EXIT
                END;   
                WITH edge^ DO
                   IF(NOT(InvisibleEdge IN Attributes)) THEN
                     PassingVar.TreeNode:=tailtask;
                     IF(ORD(Utility[PassingVar.Integer])<TaskBias) THEN
                        diff:=Ypos[Utility[PassingVar.Integer]]-ThisRow;
                        IF((diff>0) AND (diff<maxdiff)) THEN
                          maxdiff:=diff;
                          closetask:=PassingVar.Integer;
                     END;     
                  END;  
               END;
               edge := edge^.headlink;
            END;
         END;
     
         IF(closetask<>0) THEN
             Ypos[Ymaxpos[closetask]]:=ThisRow;
             Ypos[Utility[closetask]]:=ThisRow;
             INC(Utility[closetask],TaskBias); (* KWC 11/3/89 *)
             INC(Ymaxpos[Ymaxpos[NextTask]],TaskBias);
             INC(Ymaxpos[NextTask],TaskBias);
             NextTask:=closetask;
         END;
         END;
      UNTIL closetask=0;
   INC(ThisRow); 
   UNTIL ThisRow>RowsCounted; 
 
   (* Condense rows *)
   ThisRow:=1;
   REPEAT
       TaskID:=Xmaxpos[ThisRow];
       IF(Ymaxpos[TaskID]>TaskBias) THEN Ymaxpos[TaskID]:=Ymaxpos[TaskID] MOD TaskBias; END;
       IF(Utility[TaskID]>TaskBias) THEN Utility[TaskID]:=Utility[TaskID] MOD TaskBias; END;
       INC(ThisRow);
   UNTIL ThisRow>RowsCounted; 
   ThisRow:=1;
   REPEAT
       TaskID:=Xmaxpos[ThisRow];
       IF(Ymaxpos[TaskID]<TaskBias) THEN 
           CurrentRow:=Ypos[Utility[TaskID]];
           NextRow:=1;
           minrow:=-1;
           REPEAT
               TaskID:=Xmaxpos[NextRow];
               IF((Ymaxpos[TaskID]<TaskBias) AND
                    (Ypos[Ymaxpos[TaskID]]=CurrentRow)) THEN 
                   xend:=Xpos[Ymaxpos[TaskID]];
                   xstart:=Xpos[Utility[TaskID]];
                   FOR i:=xstart TO xend DO
                      IF(SnetWidth^[i]>minrow) THEN
                          minrow:=SnetWidth^[i];
                      END;
                   END;
               END;
               INC(NextRow);       
           UNTIL NextRow>RowsCounted; 
           NextRow:=1;
           INC(minrow);
           REPEAT
               TaskID:=Xmaxpos[NextRow];
               IF((Ymaxpos[TaskID]<TaskBias) AND
                    (Ypos[Ymaxpos[TaskID]]=CurrentRow)) THEN 
                   Ypos[Ymaxpos[TaskID]]:=minrow;
                   Ypos[Utility[TaskID]]:=minrow;
                   xend:=Xpos[Ymaxpos[TaskID]];
                   xstart:=Xpos[Utility[TaskID]];
                   FOR i:=xstart TO xend DO
                      SnetWidth^[i]:=minrow;
                   END;
                   INC(Ymaxpos[TaskID],TaskBias); 
               END;          
               INC(NextRow); 
           UNTIL NextRow>RowsCounted; 
       END;   
       INC(ThisRow); 
   UNTIL ThisRow>RowsCounted; 
END LinkRows;



PROCEDURE CompressArrays;
VAR
    i,j,itask: INTEGER;
BEGIN

    SnetCols := 0;

    FOR i := 0 TO DimWidth DO
        SnetWidth^[i] := 0;
    END;                                     

    FOR itask := 1 TO TaskCount  DO
        i := 0;
        LOOP
            IF (NOT (ShouldDrawFlag IN NetFlags[itask])) THEN
                EXIT;
            END;
            IF(i >= SnetCols) THEN
                SnetWidth^[i] := Xpos[itask];
                INC(SnetCols);
                EXIT;
            END;      
            IF (SnetWidth^[i] = Xpos[itask]) THEN
                EXIT;
            END;    
            IF (SnetWidth^[i] > Xpos[itask]) THEN
                FOR j := SnetCols TO i BY -1  DO
                    SnetWidth^[j+1] := SnetWidth^[j];
                END;
                SnetWidth^[i] := Xpos[itask];       
                INC(SnetCols);
                EXIT;
            END;
            INC(i);
        END;
    END;    

    FOR itask := 1 TO TaskCount  DO
        i := 0;
        LOOP
            IF (NOT (ShouldDrawFlag IN NetFlags[itask])) THEN
                EXIT;
            END;
            IF (SnetWidth^[i] = Xpos[itask]) THEN
                Xpos[itask] := i*2+6;
                EXIT;
            END;
            INC(i);
        END;
    END;   
END CompressArrays;



PROCEDURE  SpreadSubTasks(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    TaskId,ParentId,i,j,k,TasksInList      : INTEGER;
    min,max,diff,xt1,xt2                   : INTEGER;
    task        : ATaskPtr;
    NextKid,ParentNode,NextNode          : ATreeNode;
BEGIN 
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;

    NextKid:=TaskTreeNode^.Methods^.GetNext(TaskTreeNode);
    IF(NextKid<>NIL) THEN RETURN; END;
    ParentNode:=TaskTreeNode^.Methods^.Parent(TaskTreeNode);
    IF(ParentNode<>NIL) THEN
      NextNode:=ParentNode^.Methods^.FirstChild(ParentNode);
      PassingVar2.Address:= ParentNode^.Methods^.GetDataObject(ParentNode);
      ParentId:=PassingVar2.Integer;
    ELSE
      NextNode:=TaskTree^.Methods^.GetFirst(TaskTree);
    END;        
    TasksInList:=0;
    
    (* Sort the tasks in this level by their y position *)
   
    REPEAT
      PassingVar2.Address:= NextNode^.Methods^.GetDataObject (NextNode);
      TaskId := PassingVar2.Integer;
      IF(NOT (NetSummaryFlag IN NetFlags[TaskId])) THEN 
        Ymaxpos[TaskId]:=Ypos[TaskId];
      END;
      IF(NOT (NetPhantomFlag IN NetFlags[TaskId])) THEN
        i:=0;
        LOOP
          IF(i>=TasksInList) THEN
            TaskList[i]:=TaskId;
            INC(TasksInList);
            (* !!! put in check for too many tasks *)
        EXIT;
          END;    
          IF(Ypos[TaskList[i]]>=Ypos[TaskId]) THEN
            FOR j:=TasksInList TO i BY -1 DO
              TaskList[j+1]:=TaskList[j];
            END;
            TaskList[i]:=TaskId;       
            INC(TasksInList);
        EXIT;
          END;
          INC(i);
        END;
      END;  
      NextNode:=NextNode^.Methods^.GetNext(NextNode);
    UNTIL NextNode=NIL;
    TasksInList:=TasksInList-1;
    min:=Ypos[TaskList[0]];
    FOR i:=0 TO TasksInList DO
      IF(NOT (NetSummaryFlag IN NetFlags[TaskList[i]])) THEN 
        Utility[TaskList[i]]:=Ypos[TaskList[i]];
      ELSE
        Utility[TaskList[i]]:=0;  
      END;
      Ymaxpos[TaskList[i]]:=Ymaxpos[TaskList[i]]-Ypos[TaskList[i]];
      Ypos[TaskList[i]]:=0;
    END;
    (* SpreadTasks from the top down *)
    
    FOR i:=0 TO TasksInList DO
      FOR k:=i+1 TO TasksInList DO
        IF(Ypos[TaskList[k]]<=Ymaxpos[TaskList[i]]) THEN
          xt1:=Xpos[TaskList[i]];
          xt2:=Xpos[TaskList[k]];
          IF((xt1>Xmaxpos[TaskList[k]]) OR  (Xmaxpos[TaskList[i]]<xt2))THEN
          ELSE   
           diff:=Ymaxpos[TaskList[i]]-Ypos[TaskList[k]]+1;
           Ypos[TaskList[k]]:=Ypos[TaskList[k]]+diff;
           Ymaxpos[TaskList[k]]:=Ymaxpos[TaskList[k]]+diff;
           IF(Utility[TaskList[k]]<>0) THEN
               FOR j:=0 TO TasksInList DO
                  IF(Utility[TaskList[j]]=Utility[TaskList[k]] )  THEN
                    Ypos[TaskList[j]]:=Ypos[TaskList[k]];
                    Ymaxpos[TaskList[j]]:=Ymaxpos[TaskList[k]];
                 END;   
               END;
             END;
           END;
        END;      
      END;  
    END; 
    
    (* If we have no parents no need to find extents *)
    IF(ParentNode=NIL) THEN RETURN; END;
    
    (* Tasks Extents *)  
    max:=0;
    FOR i:=0 TO TasksInList DO
      IF(Ymaxpos[TaskList[i]]>max) THEN max:=Ymaxpos[TaskList[i]]; END;
(*      Ypos[TaskList[i]]:=Ypos[TaskList[i]]-min;
      Ymaxpos[TaskList[i]]:=Ymaxpos[TaskList[i]]-min; *)
    END; 
    Ypos[ParentId]:=min;
    Ymaxpos[ParentId]:=max+min;
END  SpreadSubTasks;      



PROCEDURE  SpreadSubTasksAdj(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    TaskId,ParentId,i,j                  : INTEGER;
    task                               : ATaskPtr;
    NextKid,ParentNode                 : ATreeNode;

BEGIN 
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    ParentNode:=TaskTreeNode^.Methods^.Parent(TaskTreeNode);
    IF(ParentNode=NIL) THEN RETURN; END;
    PassingVar2.Address:= ParentNode^.Methods^.GetDataObject(ParentNode);
    ParentId:=PassingVar2.Integer;
    PassingVar2.Address:= TaskTreeNode^.Methods^.GetDataObject(TaskTreeNode);
    TaskId := PassingVar2.Integer;
    Ypos[TaskId]:=Ypos[TaskId]+Ypos[ParentId];
    Ymaxpos[TaskId]:=Ymaxpos[TaskId]+Ypos[ParentId];
END  SpreadSubTasksAdj;      


                     
PROCEDURE  ComputeMaxMin(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    edge                     : AnEdgePtr;
    task                     : ATaskPtr;
    TaskId                   : INTEGER;
    PhantomId                : INTEGER;
    PhantomNode              : ATreeNode;
    XposMin                  : INTEGER;

BEGIN                                        
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    PassingVar2.Address:= TaskTreeNode^.Methods^.GetDataObject (TaskTreeNode);
    TaskId := PassingVar2.Integer;
    IF(NetSummaryFlag IN NetFlags[TaskId]) THEN 
      IF(NOT(NetPhantomFlag IN NetFlags[TaskId])) THEN
        PhantomNode:=TaskTreeNode^.Methods^.GetNext(TaskTreeNode);
        PassingVar2.Address:=PhantomNode^.Methods^.GetDataObject(PhantomNode);
        PhantomId := PassingVar2.Integer;
        Xmaxpos[TaskId]:=Xpos[PhantomId];
      END
    ELSE
      (* Find the closest dependent task *)
      edge := TDesctasksArray[TaskId];
             (* Find the guy who is closest *)
      XposMin:=MaxInt; 
      WHILE (edge<>NIL) DO
          IF(NOT(InvisibleEdge IN edge^.Attributes)) THEN
              PassingVar.TreeNode:=edge^.tailtask;
              IF(Xpos[PassingVar.Integer]<XposMin) THEN 
                 IF(NOT(NetSummaryFlag IN NetFlags[PassingVar.Integer])) THEN 
                      XposMin:=Xpos[PassingVar.Integer]; 
                 END; 
              END;
          END;                                    
          edge := edge^.headlink;
      END;
      IF(XposMin=MaxInt) THEN
          Xmaxpos[TaskId]:=Xpos[TaskId];
      ELSE
          Xmaxpos[TaskId]:=XposMin-1;
      END;    
    END;  
END  ComputeMaxMin;  



PROCEDURE Tree2Pointer(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    task                    : ATaskPtr;
    taskhandle : AnExtHandle;

BEGIN 
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    taskhandle := AnExtHandle(TaskTreeNode^.Methods^.GetDataObject (TaskTreeNode));
    TaskSave[TaskCount]:= taskhandle;
    PassingVar2.Integer:=TaskCount;
    TaskTreeNode^.Methods^.SetDataObject(TaskTreeNode,PassingVar2.Address);
    INC(TaskCount);
END Tree2Pointer;  



PROCEDURE Pointer2Tree(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
BEGIN 
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    TaskTreeNode^.Methods^.SetDataObject(TaskTreeNode,
                                   ADDRESS(TaskSave[TaskCount]));
    INC(TaskCount);
END Pointer2Tree;  


  
PROCEDURE DepList2Pointer(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    i :  INTEGER;
    task             : ATaskPtr;
    TDesctasks              : AnEdgePtr;
    TAntetasks              : AnEdgePtr;
    EdgePtr                 : AnEdgePtr;
    TaskPtr                 : ATaskPtr;

BEGIN                                        
    (* Move the front of the master tasks into place *)
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    TDesctasks := task^.desctasks;
    TAntetasks := task^.antetasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    EdgePtr := TDesctasks;

    WHILE (EdgePtr <> NIL) DO
      WITH EdgePtr^ DO
        IF( NOT(InvisibleEdge IN Attributes)) THEN
          TaskPtr := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
          PassingVar.Integer:=TaskPtr^.XX;
          tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
          (* Make the pointer an index into the task list *)
          tailtask:=PassingVar.TreeNode;  
        END;  
      END;
      EdgePtr := EdgePtr^.headlink;
    END;

    EdgePtr := TAntetasks;
    WHILE (EdgePtr <> NIL) DO
      WITH EdgePtr^ DO
        IF( NOT(InvisibleEdge IN Attributes)) THEN
          TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
          PassingVar.Integer:=TaskPtr^.XX;
          headtask^.Methods^.UnlockUnchangedDataObject (headtask);
          headtask:=PassingVar.TreeNode;
        END;
      END;
      EdgePtr := EdgePtr^.taillink;
    END;
END DepList2Pointer;  



PROCEDURE Pointer2DepList(VAR TaskTreeNode  : ATreeNode;
                           Context      : ADDRESS   );
VAR
    i :  INTEGER;
    task             : ATaskPtr;
    TDesctasks              : AnEdgePtr;
    TAntetasks              : AnEdgePtr;
    EdgePtr                 : AnEdgePtr;

BEGIN                                        
    (* Move the front of the master tasks into place *)
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    TDesctasks := task^.desctasks;
    TAntetasks := task^.antetasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    EdgePtr := TDesctasks;

    WHILE (EdgePtr <> NIL) DO
      WITH EdgePtr^ DO
        IF( NOT(InvisibleEdge IN Attributes)) THEN
          PassingVar.TreeNode:=tailtask;
          tailtask:= loopnode^[PassingVar.Integer];
        END;  
      END;
      EdgePtr := EdgePtr^.headlink;
    END;

    EdgePtr := TAntetasks;
    WHILE (EdgePtr <> NIL) DO
      WITH EdgePtr^ DO
        IF( NOT(InvisibleEdge IN Attributes)) THEN
          PassingVar.TreeNode:=headtask;
          headtask:=loopnode^[PassingVar.Integer];
        END;  
      END;
      EdgePtr := EdgePtr^.taillink;
    END;
END Pointer2DepList;  


(***************************************************************

     Random Number proceedures

 **************************************************************)
  
  PROCEDURE FastRand(bound:INTEGER) : INTEGER;
  VAR
      Z, k : INTEGER;
  BEGIN
      k := s1 DIV 206;
      s1 := 157 * ( s1 - k * 206 ) - k * 21;
      IF (s1 < 0) THEN INC(s1,32363);  END;

      k := s2 DIV 217;
      s2 := 146 * ( s2 - k * 217 ) - k * 45;
      IF (s2 < 0) THEN INC(s2,31727);  END;

      k := s3 DIV 222;
      s3 := 142 * ( s3 - k * 222 ) - k * 133;
      IF (s3 < 0) THEN INC(s3,31657);  END;

      Z := s1 - s2;
      IF (Z > 706) THEN DEC(Z,32362); END;
      INC(Z,s3);
      IF (Z < 1) THEN INC(Z,32362); END;
      Z:=Z MOD bound;
      RETURN (Z);
  END FastRand;



  PROCEDURE RandomInit (seed : CARDINAL);
    BEGIN
          (* Any mechanical formula based on the seed would be no more
             random than simple reuse of the seed.  I have not analyzed 
             whether using the same seed for all three components of
             the number generator produces a degredation of randomness.
             I suspect that it does not.    AJL   *)      
      s1 := seed;
      s2 := seed;
      s3 := seed;
    END RandomInit;



 
 
(***************************************************************

     Anneal();

 **************************************************************)

PROCEDURE AnnealPlan;
VAR
  i,k,kk,ii,totalenergy: CARDINAL;
  rowspan,totalstartenergy,totalendenergy,halfrowspan: INTEGER;
  oldnextypos,oldotherypos,jumpdiff,limittouse: INTEGER;
  energy,nodeenergy,limit,nextnode,othernode,nextypos: INTEGER;
  NodeEnergynextnode,NodeEnergyothernode: INTEGER;
  oldnextenergy,oldotherenergy,bias,savetask: INTEGER;
  nextslot,otherslot :INTEGER;
  badmoves,badtrys,test,kstart: CARDINAL;
  t,value: REAL;
  temp: ARRAY [0..20] OF CARDINAL;
  prob :CARDINAL;

    ThermTotal          : CARDINAL;
    ThermCount          : CARDINAL;
    Thermometer         : AThermometer;

BEGIN

  lastpass:=0;
  temp[0]:=1;
  temp[1]:=20;
  temp[2]:=30;
  temp[3]:=50;
  temp[4]:=80;
  temp[5]:=120;
  temp[6]:=200;
  temp[7]:=300;
  temp[8]:=400;
  temp[9]:=550;
  temp[10]:=650;
  temp[11]:=800;
  temp[12]:=900;
  temp[13]:=900;
  RandomInit (1);
  FOR k:=0 TO 50 DO
    value:=-FLOAT(k*100)/(1000.0);
    prob:=TRUNC(exp(value)*1000.0);
    ProbFunc[k]:=VAL(INTEGER,prob); 
  END;
  ProbFunc[50]:=0;
  totalenergy:=0;
  SubtaskBias:=400;
    rowspan:=RowsCounted;
    IF((rowspan MOD 2)=0) THEN INC(rowspan); END;
    IF(rowspan>11) THEN rowspan:=11; END;
    limit:=RowsCounted; 
    IF(AnnealingChoice=Draft) THEN
      limit:=limit*2;
      kstart:=12;
    ELSIF(AnnealingChoice=Average) THEN
      limit:=limit*5;
      kstart:=0;  
    ELSE (* AnnealingChoice=Presentation  *)
      kstart:=0;  
      limit:=limit*3;
    END;  
    halfrowspan:=rowspan DIV 2;

    ThermTotal := 12 - kstart + 1;
    ThermCount := 0;
    StartThermometer (Thermometer, ThermTotal);

  FOR k:=kstart TO 12 DO
    crosshit:=0;
    badmoves:=0;
    badtrys:=0;
    limittouse:=limit;
    
    IF(k>=4) THEN limittouse:=limit*2; END;
    IF(k>=6) THEN  limittouse:=limit*3; END; 
    IF(k>=8) THEN 
       limittouse:=limit*4; 
       IF(AnnealingChoice<>Presentation) THEN 
         IF(rowspan>5) THEN 
            rowspan:=5;
            halfrowspan:=2;
         END; 
       END;
    END;  
    IF(k>=10) THEN 
        IF(AnnealingChoice<>Presentation) THEN 
          rowspan:=3;  
          halfrowspan:=1; 
        END;
      limittouse:=limit*6; 
      
    END; 
    FOR i:=0 TO limittouse  DO
      nextslot:=FastRand(RowsCounted)+1;
      IF(nextslot>RowsCounted) THEN nextslot:=RowsCounted; END;
      nextnode:=Xmaxpos[nextslot];
      NodeEnergynextnode:=ComputeNodeEnergy(nextslot);
     IF(k<=6) THEN
        bias:=nextslot-halfrowspan;
      ELSE
        bias:=nextslot;
        IF(YBias>0) THEN
          bias:=nextslot-rowspan;
        END; 
      END; 
     
     IF(AnnealingChoice=Presentation) THEN 
        bias:=nextslot-halfrowspan;
     END;   
      IF(bias<1) THEN bias:=1; END;
      IF(bias>=RowsCounted) THEN bias:=RowsCounted-1; END; 
      otherslot:=FastRand(rowspan)+bias;
      IF(otherslot<=0) THEN otherslot:=1; END;
      IF(otherslot>RowsCounted) THEN otherslot:=RowsCounted; END;
      IF(otherslot=nextslot) THEN
        IF(nextslot=1) THEN
          INC(otherslot);
        ELSE
          DEC(otherslot);
        END;     
      END;
      othernode:=Xmaxpos[otherslot];
      IF(othernode<>0) THEN
      
          NodeEnergyothernode:=ComputeNodeEnergy(otherslot);
          totalstartenergy:=NodeEnergynextnode+NodeEnergyothernode; 
     
          (* Switch y values *)
          
          Ypos[Utility[othernode]]:=nextslot;
          Ypos[Ymaxpos[othernode]]:=nextslot;
          
          Ypos[Utility[nextnode]]:=otherslot;
          Ypos[Ymaxpos[nextnode]]:=otherslot;
          (* Switch nodes *)
          savetask:=Xmaxpos[nextslot];
          Xmaxpos[nextslot]:=Xmaxpos[otherslot];
          Xmaxpos[otherslot]:=savetask;
          
          NodeEnergynextnode:=ComputeNodeEnergy(nextslot);
          NodeEnergyothernode:=ComputeNodeEnergy(otherslot);
          totalendenergy:=NodeEnergynextnode+NodeEnergyothernode; 
        
          jumpdiff:=totalendenergy-totalstartenergy;
          IF((jumpdiff>0) AND (k<=11) AND (jumpdiff<300)) THEN
          (*  PrintSCard(ORD(jumpdiff),"jump diff "); *)
            test:=ORD(jumpdiff DIV 5);
            test:=(test*temp[k]) DIV 100;
            IF(test>50) THEN test:=50; END;
            INC(badmoves);
            IF(ProbFunc[test]>FastRand(1000)) THEN
              totalendenergy:=totalstartenergy-1; 
            END;
          END;  
          IF(totalendenergy>=totalstartenergy) THEN
            (* put the node back *)
            Ypos[Utility[nextnode]]:=nextslot;
            Ypos[Ymaxpos[nextnode]]:=nextslot;
            Ypos[Utility[othernode]]:=otherslot;
            Ypos[Ymaxpos[othernode]]:=otherslot;
            (* Switch nodes *)
            savetask:=Xmaxpos[nextslot];
            Xmaxpos[nextslot]:=Xmaxpos[otherslot];
            Xmaxpos[otherslot]:=savetask;
          END;  
       END;  
    END; 
(*  PrintSCard(ORD(badtrys),"Total Bad Moves  ");  
  PrintSCard(ORD(badmoves),"Bad Moves rejected  ");  
  PrintSCard(crosshit,"Cross hits ");
  PrintSCardMsg(ORD(totalenergy),"Total Energy ");
  PrintSCardMsg(ORD(k),"End pass ");    *)

    INC (ThermCount);
    UpdateThermometer (Thermometer, ThermCount);

    IF (BreakRequested()) THEN
        ClearBreak();
        FatalNetError := TRUE;
        DiscardThermometer (Thermometer);
        RETURN;
    END;

  END;   

  crosshit:=0; 
  IF(k>10) THEN lastpass:=1; END; 
  totalenergy:=0;
  FOR i:=1 TO RowsCounted  DO
    IF(totalenergy<50000) THEN
      totalenergy:=ORD(ComputeNodeEnergy(i))+totalenergy;
    END;   
  END; 
  lastpass:=0;
(*  PrintSCard(ORD(totalenergy),"Total Energy at end");  
  PrintSCard(crosshit,"Cross hits "); *)
  
    DiscardThermometer (Thermometer);

END AnnealPlan; 
(***************************************************************

     ComputeNodeEnergy;

 **************************************************************)
PROCEDURE ComputeNodeEnergy(Slot:INTEGER): INTEGER;
VAR
    diff,TaskID,checktask,Slot2   : INTEGER;
    edge                         : AnEdgePtr;
    edge2                        : AnEdgePtr;
    NextInBuffer,delta1,delta2   : INTEGER;
    i,ii,j,k,nodetype,nodeenergy,look : INTEGER;
    xnode,ynode,xnode2,ynode2,xdiff,ydiff,y2diff : INTEGER;
    extraenergy,absYBias,x1,y1,x2,y2: INTEGER;
  BEGIN
  xdiff:=0;
  ydiff:=0;
  YBias:=0;
  TaskID:=Xmaxpos[Slot];
  xnode:=Xpos[Ymaxpos[TaskID]];
  ynode:=Ypos[Ymaxpos[TaskID]];
(*  PrintSCard(ORD(xnode),"xnode ");
  PrintSCard(ORD(ynode),"ynode "); *)
  (* PrintSMsg("Entering energy calc"); *)
 
  (* Consider All Tasks After this one *)
  edge := TDesctasksArray[Ymaxpos[TaskID]];
  WHILE (edge <> NIL) DO
     WITH edge^ DO
        IF( NOT(InvisibleEdge IN Attributes)) THEN
           PassingVar.TreeNode:=tailtask;
           diff:=ynode-Ypos[Utility[PassingVar.Integer]];
      (*   PrintSCard(ORD(xnode2),"xnode2 ");
           PrintSCard(ORD(ynode2),"ynode2 "); *)
           YBias:=YBias+diff;
           diff:=ABS(diff)-1;
           ydiff:=ydiff+diff;
           IF(AnnealingChoice=Presentation) THEN 
              xnode2:=Xpos[Utility[PassingVar.Integer]];
              ynode2:=Ypos[Utility[PassingVar.Integer]];

       (* Check this line with all other lines in the system for crossing *)
              FOR ii:=1 TO Slot-1 DO
                 checktask:=Xmaxpos[ii];
                 x1:=Xpos[Ymaxpos[checktask]];
                 y1:=Ypos[Ymaxpos[checktask]];
       (*        PrintSCard(ORD(x1),"x1 upper ");
                 PrintSCard(ORD(y1),"y1 upper "); *)

                 (* Check for crossings task groups *)
              
                 IF(Ymaxpos[checktask]<>Utility[checktask]) THEN
                   IF((Xpos[Utility[checktask]]<xnode2) AND
                       (x1>=xnode2)                      AND
                       (y1>ynode2)) THEN
                       ydiff:=ydiff+10;
                       (* IF(lastpass=1) THEN PrintSMsg("Hit"); END; *)
                       IF(crosshit<1000) THEN INC(crosshit) END;
                   END;    
                 END;
              
                 (* Check for crossings with other dependency lines *)

                 IF(x1<xnode2) THEN
                    edge2 := TDesctasksArray[Ymaxpos[checktask]];
                    WHILE (edge2 <> NIL) DO
                       WITH edge2^ DO
                          IF( NOT(InvisibleEdge IN Attributes)) THEN
                             PassingVar.TreeNode:=tailtask;
                             x2:=Xpos[Utility[PassingVar.Integer]];
                             y2:=Ypos[Utility[PassingVar.Integer]];
                         (*    PrintSCard(ORD(x2),"x2 ");
                             PrintSCard(ORD(y2),"y2 "); *)
                        
                 (* Check for crossings task groups *)
              
                            IF(Ymaxpos[TaskID]<>Utility[TaskID]) THEN
                                IF((ynode<y1) AND(ynode>y2))  THEN
                                   IF((xnode>=x2) AND (Xpos[Utility[TaskID]]<x2)) THEN
                                      ydiff:=ydiff+10;
                                    (*  IF(lastpass=1) THEN PrintSMsg("Hit");
                                               END; *)
                                      IF(crosshit<1000) THEN INC(crosshit) END;
                                   END;    
                                END;
                                IF((ynode>y1) AND(ynode<y2))  THEN
                                   IF((xnode>=x2) AND (Xpos[Utility[TaskID]]<x2)) THEN
                                      ydiff:=ydiff+10;
                                     (* IF(lastpass=1) THEN 
                                     PrintSMsg("Hit"); END; *)
                                      IF(crosshit<1000) THEN INC(crosshit) END;
                                   END;    
                                END;
                            END;  
                         
                            IF(x2>xnode) THEN
                                IF((x2<=xnode2) OR (y1>=ynode2)) THEN
                                  IF(y2>ynode2) THEN
                                     ydiff:=ydiff+10;
                                (*     IF(lastpass=1) THEN 
                                  PrintSMsg("Hit"); END; *)
                                     IF(crosshit<1000) THEN INC(crosshit) END;
                                  END;   
                                END;
                             END;
                          
                          END;  
                       END;
                       edge2 := edge2^.headlink;
                    END;
                 END;
              END;  
              FOR ii:=Slot+1 TO  RowsCounted DO  
                 checktask:=Xmaxpos[ii];
                 x1:=Xpos[Ymaxpos[checktask]];
                 y1:=Ypos[Ymaxpos[checktask]];
         (*      PrintSCard(ORD(x1),"x1 lower ");
                 PrintSCard(ORD(y1),"y1 lower "); *)

                 (* Check for crossings task groups *)
              
                 IF(Ymaxpos[checktask]<>Utility[checktask]) THEN
                   IF((Xpos[Utility[checktask]]<xnode2) AND
                       (x1>=xnode2)                      AND
                       (y1<ynode2)) THEN
                       ydiff:=ydiff+10;
                     (*  IF(lastpass=1) THEN PrintSMsg("Hit"); END; *)
                       IF(crosshit<1000) THEN INC(crosshit) END;
                   END;    
                 END;
              
              (* Check for crossings with other dependency lines *)
              
              IF(x1<xnode2) THEN
                 edge2 := TDesctasksArray[Ymaxpos[checktask]];
                 WHILE (edge2 <> NIL) DO
                    WITH edge2^ DO
                       IF( NOT(InvisibleEdge IN Attributes)) THEN
                          PassingVar.TreeNode:=tailtask;
                          x2:=Xpos[Utility[PassingVar.Integer]];
                          y2:=Ypos[Utility[PassingVar.Integer]];
                  (*      PrintSCard(ORD(x2),"x2 ");
                          PrintSCard(ORD(y2),"y2 "); *)
                       
                       
                        IF(Ymaxpos[TaskID]<>Utility[TaskID]) THEN
                             IF((ynode<y1) AND(ynode>y2))  THEN
                                IF((xnode>=x2) AND (Xpos[Utility[TaskID]]<x2)) THEN
                                   ydiff:=ydiff+10;
                         (*          IF(lastpass=1) THEN PrintSMsg("Hit");
                                         END; *)
                                   IF(crosshit<1000) THEN INC(crosshit) END;
                                END;    
                             END;
                             IF((ynode>y1) AND(ynode<y2))  THEN
                                IF((xnode>=x2) AND (Xpos[Utility[TaskID]]<x2)) THEN
                                   ydiff:=ydiff+10;
                               (*    IF(lastpass=1) THEN PrintSMsg("Hit"); 
                                    END; *)
                                   IF(crosshit<1000) THEN INC(crosshit) END;
                                END;    
                             END;
                         END; 
                       
                           IF( x2>xnode ) THEN
                              IF((x2<=xnode2) OR (y1<=ynode2)) THEN
                                IF(y2<ynode2) THEN
                                   ydiff:=ydiff+10;
                               (*    IF(lastpass=1) THEN PrintSMsg("Hit"); 
                                        END; *)
                                   IF(crosshit<1000) THEN INC(crosshit) END;
                                END;
                             END;
                          END;
                       END;  
                    END;
                    edge2 := edge2^.headlink;
                 END;
               END;
            END; 
          END;    
        END;
     END;
     edge := edge^.headlink;
  END;
  IF(AnnealingChoice=Presentation) THEN 
    ydiff:=ComputeLowerNodeEnergy(TaskID,ydiff); 
  ELSE
    ynode2:=Ypos[Utility[TaskID]];
    edge := TAntetasksArray[Utility[TaskID]];
    WHILE (edge <> NIL) DO
        WITH edge^ DO
          IF(NOT(InvisibleEdge IN Attributes)) THEN
            PassingVar.TreeNode:=headtask;
            diff:=ynode2-Ypos[Ymaxpos[PassingVar.Integer]];
            YBias:=YBias+diff;
            diff:=ABS(diff)-1;
            ydiff:=ydiff+diff;
          END;   
        END;   
       edge := edge^.taillink;
    END;
  END;  
    IF(ydiff>100) THEN 
    nodeenergy:=10000;
    RETURN(nodeenergy);
  END;
  absYBias:=ABS(YBias);
  (* nodeenergy:=ydiff*10+5*absYBias; *)
  nodeenergy:=ydiff*8+5*absYBias;
  RETURN(nodeenergy);  

END ComputeNodeEnergy;

(***************************************************************

     ComputeLowerNodeEnergy;

 **************************************************************)
PROCEDURE ComputeLowerNodeEnergy(TaskID,ydiff:INTEGER): INTEGER;
VAR
    diff,checktask,Slot2   : INTEGER;
    edge                         : AnEdgePtr;
    edge2                        : AnEdgePtr;
    NextInBuffer,delta1,delta2   : INTEGER;
    i,ii,j,k,nodetype,nodeenergy,look : INTEGER;
    xnode,ynode,xnode2,ynode2,xdiff,y2diff : INTEGER;
    extraenergy,absYBias,x1,y1,x2,y2: INTEGER;
  BEGIN
(* Consider All Tasks befor this one *)
  xnode2:=Xpos[Utility[TaskID]];
  ynode2:=Ypos[Utility[TaskID]];
  edge := TAntetasksArray[Utility[TaskID]];
  WHILE (edge <> NIL) DO
      WITH edge^ DO
        IF(NOT(InvisibleEdge IN Attributes)) THEN
          PassingVar.TreeNode:=headtask;
          diff:=ynode2-Ypos[Ymaxpos[PassingVar.Integer]];
          YBias:=YBias+diff;
          diff:=ABS(diff)-1;
          ydiff:=ydiff+diff;
          xnode:=Xpos[Ymaxpos[PassingVar.Integer]];
          ynode:=Ypos[Ymaxpos[PassingVar.Integer]];
          Slot2:=ynode;

        (* Check this line with all other lines in the system for crossing *)
  
       (* Check this line with all other lines in the system for crossing *)
       IF(AnnealingChoice=Presentation) THEN 
  
           FOR ii:=1 TO Slot2-1 DO
              checktask:=Xmaxpos[ii];
              x1:=Xpos[Ymaxpos[checktask]];
              y1:=Ypos[Ymaxpos[checktask]];
       (*       PrintSCard(ORD(x1),"x1 upper ");
              PrintSCard(ORD(y1),"y1 upper "); *)
 
              (* Check for crossings task groups *)
              
              IF(Ymaxpos[checktask]<>Utility[checktask]) THEN
                IF((Xpos[Utility[checktask]]<xnode2) AND
                    (x1>=xnode2)                      AND
                    (y1>ynode2)) THEN
                    ydiff:=ydiff+10;
                    (* IF(lastpass=1) THEN PrintSMsg("Hit"); END; *)
                    IF(crosshit<1000) THEN INC(crosshit) END;
                END;    
              END;
              
              (* Check for crossings with other dependency lines *)

              IF(x1<xnode2) THEN
                 edge2 := TDesctasksArray[Ymaxpos[checktask]];
                 WHILE (edge2 <> NIL) DO
                    WITH edge2^ DO
                       IF( NOT(InvisibleEdge IN Attributes)) THEN
                          PassingVar.TreeNode:=tailtask;
                          x2:=Xpos[Utility[PassingVar.Integer]];
                          y2:=Ypos[Utility[PassingVar.Integer]];
                      (*    PrintSCard(ORD(x2),"x2 ");
                          PrintSCard(ORD(y2),"y2 "); *)
           
           

                          IF(x2>xnode) THEN
                           IF((x2<=xnode2) OR (y1>=ynode2)) THEN
                               IF(y2>ynode2) THEN
                                  ydiff:=ydiff+10;
                             (*     IF(lastpass=1) THEN PrintSMsg("Hit"); 
                                    END; *)
                                  IF(crosshit<1000) THEN INC(crosshit) END;
                               END;   
                             END;
                          END;
                       END;  
                    END;
                    edge2 := edge2^.headlink;
                 END;
              END;
           END;  
           FOR ii:=Slot2+1 TO  RowsCounted DO  
              checktask:=Xmaxpos[ii];
              x1:=Xpos[Ymaxpos[checktask]];
              y1:=Ypos[Ymaxpos[checktask]];
         (*     PrintSCard(ORD(x1),"x1 lower ");
              PrintSCard(ORD(y1),"y1 lower "); *)

              (* Check for crossings task groups *)
              
              IF(Ymaxpos[checktask]<>Utility[checktask]) THEN
                IF((Xpos[Utility[checktask]]<xnode2) AND
                    (x1>=xnode2)                      AND
                    (y1<ynode2)) THEN
                    ydiff:=ydiff+10;
                  (*   IF(lastpass=1) THEN PrintSMsg("Hit"); END; *)
                    IF(crosshit<1000) THEN INC(crosshit) END;
                END;    
              END;
              
              (* Check for crossings with other dependency lines *)

              IF(x1<xnode2) THEN
                 edge2 := TDesctasksArray[Ymaxpos[checktask]];
                 WHILE (edge2 <> NIL) DO
                    WITH edge2^ DO
                       IF( NOT(InvisibleEdge IN Attributes)) THEN
                          PassingVar.TreeNode:=tailtask;
                          x2:=Xpos[Utility[PassingVar.Integer]];
                          y2:=Ypos[Utility[PassingVar.Integer]];
                  (*        PrintSCard(ORD(x2),"x2 ");
                          PrintSCard(ORD(y2),"y2 "); *)
     
                           IF( x2>xnode ) THEN
                              IF((x2<=xnode2) OR (y1<=ynode2)) THEN
                                IF(y2<ynode2) THEN
                                   ydiff:=ydiff+10;
                          (*         IF(lastpass=1) THEN 
                          PrintSMsg("Hit"); END; *)
                                   IF(crosshit<1000) THEN INC(crosshit) END;
                                END;
                             END;
                          END;
                       END;  
                    END;
                    edge2 := edge2^.headlink;
                 END;
              END;
           END;
         END;   
      END;   
    END;
    edge := edge^.taillink;
  END;
  RETURN(ydiff);
END ComputeLowerNodeEnergy;


BEGIN
END TSort2.
