IMPLEMENTATION MODULE BuildMatrix;

(*  Modification history:

        3/11/88 EGK     Check for TGroup overflow in SpreadTasks; put up
                        error if it fails.
        3/14/88 EGK     Modified MasterBox and DrawDep Lines so that they
                        never lock down more than one task at a time.
       10/16/88 KWC     Added FixMaster to adjust master task xpos ypos
                        so they would match their matrix position                 
         1-Jun-89 KWC   Totaly  reworked code 
        28-Jun-89 KWC   removed underscores 
        29-Jun-89 KWC   increased matrix size 
        29-Jun-89 KWC   deleted flexstore buffers
        02-Jul-89 KWC   moved x sorting to tsort 
        03-Jul-89 LAA/CMH Changed occurances of count to XX.
         5-Jul-89 KWC/CMH Added indicator of phantom task to Utility array
        20-Jul-89 KWC   replaced 300 with correct constents  
        22-Jul-89 KWC   Searched for first visible subtask under master
                        label
        31-Jul-89 KWC  Changed 50 to HARNESSDIM  the max harness size     
         1-Aug-89 KWC  Changed the way FindMasterNode is used      
         8-Aug-89 KWC  Made half fact a constant     
         8-Aug-89 CMH  Removed obsolete variables.
         5-Sep-89 EGK  Merged in Andrew's change to EdgeIsCritical calls,
                       and saved space by removing unused globals.
                       Rearranged DrawInfLoop to minimize flexstor locks.
         8-Sep-89 EGK  Rearranged SortVertLines and SortHorzLines to
                       minimize flexstor locks and to exit early from
                       both inner loops if the "wiring harness" is exceeded.
        12-Sep-89 KWC  Added LEADHORZSPACE
        12-Sep-89 KWC  Added Changed the spacing between tasks
        12-Sep-89 KWC  Added pDLeftTee
        13-Sep-89 EGK  Changed SMatrixAdd to exit gracefully if flexstor
                       space runs low, and modified its client procedures
                       to handle the case when it returns a NIL.  Put
                       up another dialog box in DrawLoops if we run out of
                       flexstor space anywhere during placement.
        14-Sep-89 EGK  Put up a progress box instead of just flashing a
                       message on the top line.
        19-Sep-89 EGK  Changed users of "MemoryError" to just use
                       FatalNetError instead.  In BuildMat, FatalNetError
                       means that there isn't enough memory to do placement,
                       for any reason (including failure to create more
                       matrix space in AccessMatrix).
        25-Sep-89 CMH  Removed additional rows and columns for incremental
                       redraw.
        28-Sep-89 EGK  In DrawInfLoop, draw the phantom ender of a summary
                       task as if it were a regular task with its own
                       number.  Put a check into AdjustCell to catch NIL
                       values (caused by low-memory conditions).
         4-Oct-89 EGK  Put in checking to make sure that the sparse matrix
                       SMatrixArrayX and SMatrixArrayY doesn't overflow in
                       either dimension.  Bumped UpperYDim up to 600.
         6-Nov-89 KWC/EGK  Put in Ken's changes to use "LastWasTask" in
                       SortVertLinesInMatrix.
         8-Nov-89 KWC  Added the VLineType to solve the line kink problem
                       and the master task box alignment problem
       11-Nov-89  KWC  Recoded the AssignOffsets routine to remove kinks in
                       line drawing code
       21-Nov-89  EGK  Took out progress box code, and replaced with
                       progress thermometer in DrawLoops.  Each "tick" of
                       the thermometer represents a major section of code
                       in that procedure.  Put in Ken's change which
                       commented out the updating of SnetCols and SnetRows
                       in DrawLoops.
       1-Dec-89        Changed assigned offset to not always skip                
       4-Dec-89   EGK  Found problem in AdjustMasterTasks which would fail
                       to exit the loop if the list ended unexpectedly
                       (if there wasn't enough memory for a complete list).
                       Made a similar, but more cosmetic, improvement in
                       AdjConnect.
      6-Dec-89    KWC  Changed the extra line additions                  
*)


FROM AccessMatrix       IMPORT
    (* CONST *)             COLORBIAS,
    (* PROC *)              GetCell, SetCell;

FROM Allocs             IMPORT   
                            ATaskPtr, TaskTree, ATaskFlag;

FROM Dialog             IMPORT   
                            Message, Error, FatalError;

FROM Edges              IMPORT
    (* TYPE *)              AnEdge, AnEdgePtr, ASetOfEdgeAttributes,
                            InvisibleEdge, PhantomPredecessor,
                            PhantomSuccessor;

FROM EdgeInfo           IMPORT
                            EdgeIsCritical;                           

(* FROM ErrorUtil              IMPORT   
                                PrintMsg,PrintCard,PrintTask,
                                PrintSMsg,PrintSCard,PrintSTask; *)

FROM FlexStor           IMPORT
    (* TYPE *)              AnExtHandle, AnExtStatus, AnExtStoragePreference,
    (* PROC *)              LockObject, ReleaseObject, ReleaseUnchangedObject,
                            CreateExtObjectWithSize, GetExtStatus,
                            ObjectsAreSame, DiscardExtObject;

FROM Kbio                   IMPORT
    (* PROC *)                  BreakRequested, ClearBreak;

FROM LStrings           IMPORT   
                            SetString, ConcatS, ConcatLS, CtoS, Compare,
                            SubStr, Fill, TrimFront, Copy,LStringToTString;

FROM MsgFile            IMPORT 
                            GetMessage;

FROM NetBData           IMPORT   
                            TaskCount,
                            infloopcount,
                            NetFlags, NetFlagType, inflooptaskhandle;
                           
FROM NetCharacters      IMPORT
                            pblank, pVBar,pHBar,pVDash,pdash,pRightTee,
                            pURC,pLLC,pBotTee,pTopTeeUp,pTopTeeDown,
                            pLeftTee,pplus,pLRC,pULC,pDPlus,pDHPlus,
                            pastrLL,pastrLR,pastrUR,pastrUL,pMTaskHBar,pMTaskVBar,
                            pDLeftTee,pDRightTee;

FROM NetStatic          IMPORT 
                            MatrixOverflow, NetworkDone,
                            SnetWidth,SnetHeight,loopnode,maxtask,Xpos,Ypos,
                            SnetRows,SnetCols,HaveInfLoop,FatalNetError,
                            SnetColOne,SnetRowOne,
                            DimWidth, DimHeight,
                            Xmaxpos, Ymaxpos, Utility;
                           
FROM NetPhantoms        IMPORT
    (* PROC *)              DiscardSummaryPhantoms;
    
FROM NetworkData        IMPORT
                            AnnealingChoice,NetworkType,ANetworkType;

FROM Progress               IMPORT
    (* TYPE *)                  AThermometer,
    (* PROC *)                  CreateThermometer, UpdateThermometer,
                                DiscardThermometer;

FROM SYSTEM             IMPORT   
                            TSIZE, ADDRESS;

FROM TreeObjects        IMPORT
    (* TYPE *)              ATree, ATreeNode, ATreeOrder, TempFlag4;


TYPE 

    LineDrawingRecPnt = POINTER TO LineDrawingRec;
    LineDrawingRec =    RECORD
                          StartTask    :INTEGER;
                          EndTask      :INTEGER;
                          EndX         :INTEGER;
                          EndY         :INTEGER;
                          LineOffset   :INTEGER;
                          StartOffset  :INTEGER;
                          EndOffset    :INTEGER;
                          EndChar      :INTEGER;
                          Type         :INTEGER;
                          LineGroup    :INTEGER;
                          NextNode     :AnExtHandle;
                          NextInSeq    :AnExtHandle;
                          Critical     :BOOLEAN;
                        END;

    SMatrixCellPtr=     POINTER TO SMatrixCell;
    SMatrixCell =       RECORD
                          NextX         :AnExtHandle;
                          NextY         :AnExtHandle;
                          XValue        :INTEGER;
                          YValue        :INTEGER;
                          TaskId        :INTEGER;
                          NextLine      :AnExtHandle;
                        END;
CONST
    ModuleNumber        = 20250;  (* For GetMessage *)
    MaxInt              = 32000;
    UpperXDim           = 600;    (* Max X width of internal matrix *)
    UpperYDim           = 600;    (* Max Y width of internal matrix *)
    InvisibleNode       = TempFlag4;

    HORZLINE            = 1;
    HORZLINEUP          = 2;
    HORZSPACE           = 10;
    LEADHORZSPACE       = 11;
    VERTUP              = 4;
    VERTDOWN            = 5;
    PLINE               = 2;
    SLINE               = 3;
    TASKTOP             = 6;
    TASKRT              = 7;
    TASKBOT             = 8;
    TASKLT              = 9;
    HARNESSDIM          = 100;
    HALFFACT            = 1; 
    VMasterLine         = 30000; (* code to represent a vertical master line *)

VAR
    SMatrixArrayX   : ARRAY[0..UpperXDim] OF AnExtHandle;
    SMatrixArrayY   : ARRAY[0..UpperYDim] OF AnExtHandle;
    XColOffset      : ARRAY[0..UpperXDim] OF INTEGER;
    YRowOffset      : ARRAY[0..UpperYDim] OF INTEGER;

    LineObj         : ARRAY[0..HARNESSDIM] OF AnExtHandle;
    VLineType       : ARRAY[0..HARNESSDIM] OF INTEGER;
    NextNo          : ARRAY[0..HARNESSDIM] OF INTEGER;
    ChanNo          : ARRAY[0..HARNESSDIM] OF INTEGER;
    StartPos        : ARRAY[0..HARNESSDIM] OF INTEGER;
    EndPos          : ARRAY[0..HARNESSDIM] OF INTEGER;
    Sort1           : ARRAY[0..HARNESSDIM] OF INTEGER;
    Sort2           : ARRAY[0..HARNESSDIM] OF INTEGER;
    Sort3           : ARRAY[0..HARNESSDIM] OF INTEGER;
    Sort4           : ARRAY[0..HARNESSDIM] OF INTEGER;

    MaxLines        : INTEGER;
    LineGroupID     : INTEGER;
    BreakHit        : BOOLEAN;

    Thermometer     : AThermometer;
    PassIndex       : CARDINAL;
    PassCount       : CARDINAL;


PROCEDURE CheckForBreak ();
BEGIN
    IF (BreakRequested()) THEN
        FatalNetError := TRUE;
        BreakHit := TRUE;
    END;
END CheckForBreak;



PROCEDURE StartThermometer ( VAR Thermometer    : AThermometer );
VAR
    s               : ARRAY [0..255] OF CHAR;
    OK              : BOOLEAN;
BEGIN
    GetMessage (ModuleNumber+3, s);     (* "Calculating placement" *)
    OK := CreateThermometer (Thermometer, 0, 0, s, PassCount);
    PassIndex := 0;
END StartThermometer;



PROCEDURE Tick();
BEGIN
    INC (PassIndex);
    UpdateThermometer (Thermometer, PassIndex);
END Tick;



PROCEDURE BuildMatrix;

VAR
    s                   : ARRAY [0..255] OF CHAR;

BEGIN
    maxtask := TaskCount;
    BreakHit := FALSE;                  (* 9/19/89 EGK *)

    IF (HaveInfLoop) THEN
        DrawInfLoop();
    ELSE 
        DrawLoops();

        IF (MatrixOverflow) THEN
            GetMessage(ModuleNumber,s);
            (* The Plan is too large for the display Matrix *)
            Error(s);
        END;

        IF (FatalNetError) AND (NOT BreakHit) THEN
            GetMessage (ModuleNumber+2, s);     (* "Not enough memory" *)
            Error (s);
        END;
    END;

    ClearBreak();

END BuildMatrix;



PROCEDURE DrawInfLoop;

VAR
    descendantcount,i   : INTEGER;
    TaskID              : INTEGER;
    currtaskhandle,
    descendanthandle    : AnExtHandle;
    Node                : ATreeNode;
    TaskPtr             : ATaskPtr;
    EdgePtr             : AnEdgePtr;
    row, col            : INTEGER;
    htemp               : INTEGER;
    itask               : INTEGER;

BEGIN 

    FOR i:=0 TO TaskCount DO
        (* Clear corners for master task bounderies *)
        Utility[i]:=0;
        Xmaxpos[i]:=0;
        Ymaxpos[i]:=0;
    END;

    row := 1;
    col := 4;

    SnetCols    := col;
    SnetRows    := row;
    SnetColOne  := 2;
    SnetRowOne  := row; 

    FOR itask :=1 TO TaskCount DO
        IF (NetPhantomFlag IN NetFlags[itask]) THEN
            Utility[itask] := -1;
            Node := loopnode^[itask];
            Node := Node^.Methods^.GetPrev (Node);

            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            loopnode^[itask] := loopnode^[TaskPtr^.XX];
            Node^.Methods^.UnlockUnchangedDataObject (Node);
        END;
    END;


    currtaskhandle := inflooptaskhandle;

    LOOP
        IF (LockObject (currtaskhandle, TaskPtr) = 0) THEN
            FatalError();
        END;
        EdgePtr := TaskPtr^.desctasks;
        ReleaseUnchangedObject(currtaskhandle);

        LOOP
            Node := EdgePtr^.tailtask;
            descendanthandle := AnExtHandle(Node^.Methods^.GetDataObject(Node));
            IF (LockObject (descendanthandle, TaskPtr) = 0) THEN
                FatalError();
            END;
            descendantcount := TaskPtr^.XX;
            ReleaseUnchangedObject(descendanthandle);

            IF (Xpos[descendantcount] = -infloopcount) THEN
(*
                IF (NetPhantomFlag IN NetFlags[descendantcount]) THEN
                    Node := Node^.Methods^.GetPrev (Node);
                    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
                    TaskID := TaskPtr^.XX;
                    Node^.Methods^.UnlockUnchangedDataObject (Node);
                ELSE
                    TaskID := descendantcount;
                END; 
*)
                TaskID := descendantcount;
                SetCell(row,col,TaskID);
                Xpos[TaskID] := col;
                IF NOT (NetPhantomFlag IN NetFlags[TaskID]) THEN    (* 9/28/89 EGK *)
                    Utility[TaskID] := col;
                END;
                Ypos[TaskID] := row;
                Xmaxpos[TaskID] := col;
                Ymaxpos[TaskID] := row;

                INC(col);
                SetCell(row,col,pHBar);

                INC(col);
                IF (col > SnetCols) THEN
                    SnetCols := col;
                END;

                IF(col > DimWidth-4) THEN
                (* Draw return line *)
                    INC(row);
                    SetCell(row-1,col,pURC);
                    SetCell(row,col,pLRC);
                    htemp := col-1;
                    DrawHorz(3,row,htemp,pHBar);
                    SetCell(row,3,pULC);
                    INC(row);
                    SetCell(row,3,pLLC);
                    col := 4;
                END;
                IF (row > SnetRows) THEN
                    SnetRows := row;
                END;

                EXIT;        
            END;
            EdgePtr := EdgePtr^.headlink;
        END;
        IF (ObjectsAreSame (descendanthandle, inflooptaskhandle)) THEN
            EXIT; 
        END;
        currtaskhandle := descendanthandle;
    END;      
    
    (* Draw return line *)
    SetCell(row,col,pURC);
    INC(row);
    SetCell(row,col,pLRC);
    htemp := col-1;
    DrawHorz(3,row,htemp,pHBar);
    SetCell(row,2,pLLC);
    DrawVert(2,2,row-1,pVBar);
    SetCell(1,3,pHBar);
    SetCell(1,2,pULC);
    IF (row > SnetRows) THEN
        SnetRows := row;
    END;

END DrawInfLoop;
  
       

       
PROCEDURE DrawLoops;

VAR
    Node        : ATreeNode;
    cellobj     : AnExtHandle;
    cell        : SMatrixCellPtr;
    i,j         : INTEGER;
    TaskPtr     : ATaskPtr;
    EdgePtr     : AnEdgePtr;
    TaskID      : INTEGER;
    itask       : INTEGER;
    row1        : INTEGER;
    col1        : INTEGER;

BEGIN

        (*  PassCount is the total number of "passes" in DrawLoops.  Each
            time one is finished, we call the Tick procedure.  Of course,
            some passes take much longer than others, but this still gives
            the user a pretty good idea that something is happening.

            Outline mode takes 12 passes, but traditional takes only 10
            since it omits the MasterBox and AdjOutlineLines sections.
        *)

    IF (NetworkType = Outline) THEN
        PassCount := 12;
    ELSE
        PassCount := 10;
    END;
    StartThermometer (Thermometer);

    FOR i := 0 TO TaskCount DO
        (* Clear corners for master task bounderies *)
        Utility[i] := 0;
        Xmaxpos[i] := 0;
        Ymaxpos[i] := 0;
        (* Init sparse matrix *)
    END;

    FOR i := 0 TO UpperXDim DO
        SMatrixArrayX[i] := AnExtHandle(NIL);
        XColOffset[i] := 0;
    END;

    FOR i := 0 TO UpperYDim  DO
        SMatrixArrayY[i] := AnExtHandle(NIL);
        YRowOffset[i] := 0;
    END;

    FOR i := 0 TO DimHeight DO
        SnetHeight^[i] := 0;
    END;

    SnetRows := 0;
    SnetColOne := MaxInt;
    SnetRowOne := MaxInt;

    FOR itask := 1 TO TaskCount  DO
        IF (ShouldDrawFlag IN NetFlags[itask]) THEN
            SortinY(Ypos[itask]);
        END;
    END;

    FOR itask := 1 TO TaskCount DO
        IF (ShouldDrawFlag IN NetFlags[itask]) THEN
            FindY(Ypos[itask],Ypos[itask]);
        END;
    END;


    (* Clear pointer matrix *)

    FOR i := 0 TO DimWidth DO
        SnetWidth^[i] := 0;
    END;                                     
    FOR i := 0 TO DimHeight DO
        SnetHeight^[i] := 0;
    END;

       (* Place infor in matrix after spread *)

    SnetCols := 0;
    SnetRows := 0;

    Tick();

    FOR itask := 1 TO TaskCount  DO
        IF (ShouldDrawFlag IN NetFlags[itask]) THEN

            col1 := Xpos[itask];
            row1 := Ypos[itask];

(*          IF (col1 > SnetCols) THEN
                SnetCols := col1;
            END;
            IF (row1 > SnetRows) THEN
                SnetRows := row1;
            END;  *)

            IF (NetSummaryFlag IN NetFlags[itask]) THEN
                IF (NetPhantomFlag IN NetFlags[itask]) THEN

            (* Must place all nodes in matrix so drawing logic can
               avoid master task intersection points *)

                    Node := loopnode^[itask];
                    TaskPtr := Node^.Methods^.LockFlexStorDataObject(Node);
                    EdgePtr := TaskPtr^.desctasks;
                    Node^.Methods^.UnlockUnchangedDataObject(Node);

                    LOOP
                        IF (EdgePtr = NIL) THEN
                            EXIT;
                        END;
                        IF( NOT(InvisibleEdge IN EdgePtr^.Attributes)) THEN

                            WITH EdgePtr^ DO
                                TaskPtr := tailtask^.Methods^.
                                        LockFlexStorDataObject(tailtask);
                                i := TaskPtr^.XX;
                                tailtask^.Methods^.UnlockUnchangedDataObject(tailtask);
                            END;

                            IF((ShouldDrawFlag IN NetFlags[i]) AND
                                    (NOT(NetPhantomFlag IN NetFlags[i]))) THEN

                                Node := loopnode^[itask];
                                Node := Node^.Methods^.GetPrev (Node);
                                TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
                                TaskID := TaskPtr^.XX;
                                Node^.Methods^.UnlockUnchangedDataObject (Node);

                                cellobj := SMatrixAdd(col1,Ypos[TaskID]);
                                IF (cellobj <> AnExtHandle(NIL)) THEN        (* 9/13/89 EGK *)
                                    IF (LockObject(cellobj,cell) = 0) THEN
                                        FatalError();
                                    END;
                                    cell^.TaskId := MaxInt;
                                    ReleaseObject(cellobj);
                                END;
                                EXIT;
                            END;
                        END;
                        EdgePtr := EdgePtr^.headlink;
                    END;
                ELSE

                    Node := loopnode^[itask];
                    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
                    EdgePtr := TaskPtr^.antetasks;
                    Node^.Methods^.UnlockUnchangedDataObject (Node);

                    LOOP
                        IF (EdgePtr = NIL) THEN 
                            EXIT;
                        END;
                        IF( NOT(InvisibleEdge IN EdgePtr^.Attributes)) THEN
                            WITH EdgePtr^ DO
                                TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
                                i:= TaskPtr^.XX;
                                headtask^.Methods^.UnlockUnchangedDataObject (headtask);
                            END;
                            IF(ShouldDrawFlag IN NetFlags[i]) THEN
                                IF(NetSummaryFlag IN NetFlags[i]) THEN
                                    IF(NetPhantomFlag IN NetFlags[i]) THEN
                                        cellobj := SMatrixAdd(col1,row1);
                                        IF (cellobj <> AnExtHandle(NIL)) THEN        (* 9/13/89 EGK *)
                                            IF (LockObject(cellobj,cell) = 0) THEN
                                                FatalError();
                                            END;
                                            cell^.TaskId := MaxInt;
                                            ReleaseObject(cellobj);
                                        END;
                                        EXIT;
                                    END;
                                ELSE
                                    cellobj := SMatrixAdd(col1,row1);
                                    IF (cellobj <> AnExtHandle(NIL)) THEN        (* 9/13/89 EGK *)
                                        IF (LockObject(cellobj,cell) = 0) THEN
                                            FatalError();
                                        END;
                                        cell^.TaskId:=MaxInt;
                                        ReleaseObject(cellobj);
                                    END;
                                    EXIT;
                                END;
                            END;
                        END;
                        EdgePtr := EdgePtr^.taillink;
                    END;
                END;  
            ELSE
                cellobj := SMatrixAdd(col1,row1);
                IF (cellobj <> AnExtHandle(NIL)) THEN       (* 9/13/89 EGK *)
                    IF (LockObject(cellobj,cell) = 0) THEN
                        FatalError();
                    END;
                    cell^.TaskId := itask;
                    ReleaseObject(cellobj);
                END;
            END;
        END;
    END;

    Tick();

    CheckForBreak();

(* Draw all the dependency lines *)

    IF (NetworkType = Outline) THEN

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        MasterBox, NIL);
        Tick();

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        DrawDepLinesOutline, NIL);

        Tick();
        IF (NOT FatalNetError) THEN               (* 9/13/89 EGK *)
            SortHorzLinesInMatrix;
            Tick();
            SortVertLinesInMatrix;
            Tick();
        END;

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        AdjDepLines, NIL);
        Tick();

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        AdjOutlineLines, NIL);
        Tick();
    ELSE

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        DrawDepLinesPert, NIL);

        Tick();
        IF (NOT FatalNetError) THEN               (* 9/13/89 EGK *)
            SortHorzLinesInMatrix;
            Tick();
            SortVertLinesInMatrix;
            Tick();
        END;

        TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                        AdjDepLinesPert, NIL);
        Tick();
    END;

    CheckForBreak();

    PutVertLinesInMatrix;
    Tick();
    PutHorzLinesInMatrix;
    Tick();

    DiscardSMatrix();
    Tick();

    FOR itask :=1 TO TaskCount DO
        IF (NetPhantomFlag IN NetFlags[itask]) THEN
            Utility[itask] := -1;
            Node := loopnode^[itask];
            Node := Node^.Methods^.GetPrev (Node);

            TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
            loopnode^[itask] := loopnode^[TaskPtr^.XX];
            Node^.Methods^.UnlockUnchangedDataObject (Node);
        END;
    END;

    Tick();

    DiscardThermometer (Thermometer);
                                      
END DrawLoops;



PROCEDURE FindY(VAR Ypos1,Ypos2: INTEGER);
VAR
    i           : INTEGER;
BEGIN
    i := 0;
    LOOP
        IF(SnetHeight^[i] = Ypos1) THEN
            Ypos2 := i*2+6;
            EXIT;
        END;    
        INC(i);
    END;
END FindY;



PROCEDURE SortinY(Ypos: INTEGER);
VAR
    i,j     : INTEGER;
BEGIN
    i := 0;
    LOOP
        IF(i>=SnetRows) THEN
            SnetHeight^[i]:=Ypos;
            INC(SnetRows);
            EXIT;
        END;    
        IF(SnetHeight^[i]=Ypos) THEN EXIT; END;    
        IF(SnetHeight^[i]>Ypos) THEN
            FOR j:=SnetRows TO i BY -1 DO
                SnetHeight^[j+1]:=SnetHeight^[j];
            END;
            SnetHeight^[i]:=Ypos;       
            INC(SnetRows);
            EXIT;
        END;
        INC(i);
    END;
END SortinY;




PROCEDURE DrawDepLinesOutline(VAR TaskTreeNode : ATreeNode;
                               Context      : ADDRESS);
VAR
    k,i,row1,col1,row2,col2:  INTEGER;
    edge: AnEdgePtr;
    task            : ATaskPtr;
    ptask,stask          : INTEGER;
    TDesctasks      : AnEdgePtr;
    critical        : BOOLEAN;

BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    ptask := task^.XX;
    TDesctasks := task^.desctasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

    IF (NOT (ShouldDrawFlag IN NetFlags[ptask])) THEN
        RETURN;
    END;


    IF ((NetSummaryFlag IN NetFlags[ptask]) AND
       (NOT( NetPhantomFlag IN NetFlags[ptask]))) THEN
            RETURN;
    END;        
    edge := TDesctasks;
    WHILE (edge <> NIL) DO
    
        IF((ASetOfEdgeAttributes{InvisibleEdge,PhantomPredecessor,
                                 PhantomSuccessor} * edge^.Attributes)
                                 =ASetOfEdgeAttributes{})  THEN
           WITH edge^ DO  
               task:=tailtask^.Methods^.LockFlexStorDataObject(tailtask);
               stask:=task^.XX;
               tailtask^.Methods^.UnlockUnchangedDataObject(tailtask);  
           END;   
           critical:=EdgeIsCritical(edge,TRUE);   (* Treating summaries as milestones. *)
           Connect(ptask,stask,critical);
        END;

        edge := edge^.headlink;
    END;    
        
END DrawDepLinesOutline;



PROCEDURE AdjDepLines(VAR TaskTreeNode : ATreeNode;
                               Context      : ADDRESS);
VAR
    k,i,row1,col1,row2,col2:  INTEGER;
    edge: AnEdgePtr;
    task            : ATaskPtr;
    ptask,stask          : INTEGER;
    TDesctasks      : AnEdgePtr;

BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    ptask := task^.XX;
    TDesctasks := task^.desctasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

    IF (NOT (ShouldDrawFlag IN NetFlags[ptask])) THEN
        RETURN;
    END;


    IF ((NetSummaryFlag IN NetFlags[ptask]) AND
       (NOT( NetPhantomFlag IN NetFlags[ptask]))) THEN
            RETURN;
    END;        
    edge := TDesctasks;
    WHILE (edge <> NIL) DO
        IF((ASetOfEdgeAttributes{InvisibleEdge,PhantomPredecessor,
                                 PhantomSuccessor} * edge^.Attributes)
                                 =ASetOfEdgeAttributes{})  THEN
            WITH edge^ DO  
                task:=tailtask^.Methods^.LockFlexStorDataObject(tailtask);
                stask:=task^.XX;
                tailtask^.Methods^.UnlockUnchangedDataObject(tailtask);  
            END;                      
            AdjConnect(ptask,stask);
        END;

        edge := edge^.headlink;
    END;
END AdjDepLines;



PROCEDURE DrawDepLinesPert(VAR TaskTreeNode : ATreeNode;
                               Context      : ADDRESS);
VAR
    k,i,row1,col1,row2,col2:  INTEGER;
    edge: AnEdgePtr;
    task           : ATaskPtr;
    ptask,stask    : INTEGER;
    TDesctasks     : AnEdgePtr;
    critical       : BOOLEAN;

BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    ptask := task^.XX;
    TDesctasks := task^.desctasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

   IF (NOT (ShouldDrawFlag IN NetFlags[ptask])) THEN
        RETURN;
    END; 
    edge := TDesctasks;
    WHILE (edge <> NIL) DO
 
        (* Draw the sucker *)
 
        IF( NOT(InvisibleEdge IN edge^.Attributes)) THEN
           WITH edge^ DO
                task := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
                stask := task^.XX;
                tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
            END;
            critical:=EdgeIsCritical(edge,TRUE);   (* Treating summaries as milestones. *)
            Connect(ptask,stask,critical);
        END;

        edge := edge^.headlink;
    END;
END DrawDepLinesPert;



PROCEDURE AdjDepLinesPert(VAR TaskTreeNode : ATreeNode;
                               Context      : ADDRESS);
VAR
    k,i,row1,col1,row2,col2:  INTEGER;
    edge: AnEdgePtr;
    task           : ATaskPtr;
    ptask,stask    : INTEGER;
    TDesctasks     : AnEdgePtr;

BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    ptask := task^.XX;
    TDesctasks := task^.desctasks;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

   IF (NOT (ShouldDrawFlag IN NetFlags[ptask])) THEN
        RETURN;
    END; 
    edge := TDesctasks;
    WHILE (edge <> NIL) DO
 
        (* Draw the sucker *)
 
        IF( NOT(InvisibleEdge IN edge^.Attributes)) THEN
            WITH edge^ DO
                task := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
                stask := task^.XX;
                tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
            END;
            AdjConnect(ptask,stask);
        END;

        edge := edge^.headlink;
    END;
END AdjDepLinesPert;


  
PROCEDURE AdjConnect( ptask,stask: INTEGER );
VAR
    x1,y1,x2,y2         : INTEGER;
    hitstask            : BOOLEAN;
    TaskNode            : ATreeNode;
    cell                : SMatrixCellPtr;
    task                : ATaskPtr;
    line1               : LineDrawingRecPnt;
    cellobj,
    nextlineobj1,
    lastlineobj         : AnExtHandle;

BEGIN
    x1 := Xpos[ptask];
    y1 := Ypos[ptask];
    IF ((NetPhantomFlag IN NetFlags[ptask]) AND (NetworkType = Outline)) THEN
        TaskNode := loopnode^[ptask]^.Methods^.GetPrev(loopnode^[ptask]);
        task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
        y1 := Ypos[task^.XX];
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
    END;
    x2 := Xpos[stask];
    y2 := Ypos[stask];
      
(* Look up starting cell *)      
      
    cellobj := SMatrixAdd(x1,y1);
    IF (cellobj = AnExtHandle(NIL)) THEN                 (* 9/13/89 EGK *)
        RETURN;
    END;

    IF (LockObject(cellobj,cell) = 0) THEN
        FatalError();
    END;
    nextlineobj1 := cell^.NextLine;    
    ReleaseUnchangedObject(cellobj);

    LOOP
        IF (nextlineobj1 = AnExtHandle(NIL)) THEN       (* 12/4/89 EGK *)
            RETURN;
        END;
        IF (LockObject(nextlineobj1,line1) = 0) THEN
            FatalError();
        END;
        IF ((line1^.StartTask = ptask) AND
            (line1^.EndTask = stask)) THEN
            ReleaseUnchangedObject(nextlineobj1);
            EXIT;
        END;
        lastlineobj := nextlineobj1;
        nextlineobj1 := line1^.NextNode;
        ReleaseUnchangedObject(lastlineobj);
    END;  
   
    IF (y1 = y2) THEN (* same level *)
        hitstask := CheckPath(x1,y1,x2,y2);
        IF (NOT hitstask) THEN
            IF (NetBranchFlag IN NetFlags[ptask]) THEN
                nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
	            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,LEADHORZSPACE);
                nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
            ELSE
                nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
                nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZSPACE);
                nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
            END;
        ELSE    
            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTDOWN);
            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINEUP);
            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTUP);
            nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
        END;

    ELSIF (y1 > y2) THEN (* second node above *)
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTUP);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTUP);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
            
    ELSE    (* second node below *)
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTDOWN);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,VERTDOWN);
        nextlineobj1 := AdjustCell(nextlineobj1,y1,stask,HORZLINE);
    END;
END AdjConnect;    


PROCEDURE Connect( ptask,stask :INTEGER; critical :BOOLEAN );
VAR
    x1,y1,x2,y2     : INTEGER;
    hitstask        : BOOLEAN;
    lineobj         : AnExtHandle;
    TaskNode        : ATreeNode;
    task            : ATaskPtr;
    lastline        : AnExtHandle;

BEGIN
    lastline := AnExtHandle(NIL);

    x1 := Xpos[ptask];
    y1 := Ypos[ptask];

    IF (NetPhantomFlag IN NetFlags[ptask]) AND (NetworkType = Outline) THEN
        TaskNode := loopnode^[ptask]^.Methods^.GetPrev(loopnode^[ptask]);
        task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
        y1 := Ypos[task^.XX];
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
    END;

    x2 := Xpos[stask];
    y2 := Ypos[stask];
    INC(LineGroupID);
    IF (y1 = y2) THEN (* same level *)

        hitstask := CheckPath(x1,y1,x2,y2);
        IF (NOT hitstask) THEN
            IF(NetBranchFlag IN NetFlags[ptask]) THEN
                lastline := MarkCell(LineGroupID,x1,y1,x1+HALFFACT,y2,ptask,stask,HORZLINE,critical,lastline);
	        lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2,ptask,stask,
	                                 LEADHORZSPACE,critical,lastline);
                lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x2,y2,ptask,stask,HORZLINE,critical,lastline);
            ELSE
                lastline := MarkCell(LineGroupID,x1,y1,x1+HALFFACT,y2,ptask,stask,HORZLINE,critical,lastline);
                lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2,ptask,stask,HORZSPACE,critical,lastline);
                lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x2,y2,ptask,stask,HORZLINE,critical,lastline);
            END;
        ELSE    
            lastline := MarkCell(LineGroupID,x1,y1,x1+HALFFACT,y1,ptask,stask,HORZLINE,critical,lastline);
            
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y1+HALFFACT,
                                 ptask,stask,PLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1+HALFFACT,x2-HALFFACT,y1+HALFFACT,
                                 ptask,stask,HORZLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y1+HALFFACT,x2-HALFFACT,y1,
                                 ptask,stask,SLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y1,x2,y1,ptask,stask,HORZLINE,critical,lastline);
        END;

    ELSIF (y1 > y2) THEN (* second node above *)
        lastline := MarkCell(LineGroupID,x1,y1,x1+HALFFACT,y1,ptask,stask,HORZLINE,critical,lastline);
        hitstask := CheckPath(x1+HALFFACT,y2,x2,y2);
        IF ((NOT hitstask) AND ((x1+HALFFACT)<>(x2-HALFFACT))) THEN
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2+HALFFACT,
                                 ptask,stask,PLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2+HALFFACT,x1+HALFFACT,y2+HALFFACT,
                                 ptask,stask,HORZLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2+HALFFACT,x1+HALFFACT,y2,
                                 ptask,stask,SLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2,x2,y2,
                                 ptask,stask,HORZLINE,critical,lastline);
        ELSE          
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2+HALFFACT,
                                 ptask,stask,PLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2+HALFFACT,x2-HALFFACT,y2+HALFFACT,
                                 ptask,stask,HORZLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y2+HALFFACT,x2-HALFFACT,y2,
                                 ptask,stask,SLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y2,x2,y2,
                                 ptask,stask,HORZLINE,critical,lastline);
              
        END;
    ELSE    (* second node below *)
        lastline := MarkCell(LineGroupID,x1,y1,x1+HALFFACT,y1,ptask,stask,HORZLINE,critical,lastline);
        hitstask := CheckPath(x1+HALFFACT,y2,x2,y2);
        IF ((NOT hitstask) AND ((x1+HALFFACT)<>(x2-HALFFACT))) THEN
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2-HALFFACT,
                                 ptask,stask,PLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2-HALFFACT,x1+HALFFACT,y2-HALFFACT,
                                 ptask,stask,HORZLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2-HALFFACT,x1+HALFFACT,y2,
                                 ptask,stask,SLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2,x2,y2,
                                 ptask,stask,HORZLINE,critical,lastline);
        ELSE
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y1,x1+HALFFACT,y2-HALFFACT,
                                 ptask,stask,PLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x1+HALFFACT,y2-HALFFACT,x2-HALFFACT,y2-HALFFACT,
                                 ptask,stask,HORZLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y2-HALFFACT,x2-HALFFACT,y2,
                                 ptask,stask,SLINE,critical,lastline);
            lastline := MarkCell(LineGroupID,x2-HALFFACT,y2,x2,y2,
                                 ptask,stask,HORZLINE,critical,lastline);
        END;
    END;
END Connect;    
     


PROCEDURE CheckPath(x1,y1,x2,y2:INTEGER): BOOLEAN;
VAR
    lastcellobj,
    nextcellobj             : AnExtHandle;
    cell                    : SMatrixCellPtr;
    XValue, YValue          : INTEGER;
    TaskID                  : INTEGER;

BEGIN

    IF (x1 > UpperXDim) OR (y1 > UpperYDim) THEN        (* 10/4/89 EGK *)
        MatrixOverflow := TRUE;
        RETURN FALSE;
    END;

  (* First see if the cell is already there *)

    IF (x1 = x2) THEN 
        nextcellobj := SMatrixArrayX[x1];
        LOOP
            IF (nextcellobj = AnExtHandle(NIL)) THEN
                RETURN FALSE;
            END;

            IF (LockObject(nextcellobj,cell) = 0) THEN
                FatalError();
            END;
            lastcellobj := nextcellobj;
            YValue := cell^.YValue;
            TaskID := cell^.TaskId;
            nextcellobj := cell^.NextY;   
            ReleaseUnchangedObject(lastcellobj);

            IF (YValue >= y2) THEN
                RETURN FALSE;
            ELSIF ((YValue > y1) AND (TaskID <> 0)) THEN
                RETURN TRUE;
            END;
        END;
    END;

    IF (y1 = y2) THEN 
        nextcellobj := SMatrixArrayY[y1];
        LOOP
            IF (nextcellobj = AnExtHandle(NIL)) THEN
                RETURN FALSE;
            END;

            IF (LockObject(nextcellobj,cell) = 0) THEN
                FatalError();
            END;
            lastcellobj := nextcellobj;
            XValue := cell^.XValue;
            TaskID := cell^.TaskId;
            nextcellobj := cell^.NextX;
            ReleaseUnchangedObject(lastcellobj);

            IF (XValue >= x2) THEN
                RETURN FALSE;
            ELSIF ((XValue > x1) AND (TaskID <> 0)) THEN
                RETURN TRUE;
            END;
        END;
    END;    

    RETURN FALSE;               (* 10/4/89 EGK *)

END CheckPath;



PROCEDURE AdjustCell (nextlineobj1 : AnExtHandle;
                      y1,stask,
                      ltype        : INTEGER     ) : AnExtHandle;
VAR
    lineobj1,
    nextlineobj2    : AnExtHandle;
    line1,line2     : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;
    temp            : INTEGER;

BEGIN
    IF (nextlineobj1 = AnExtHandle(NIL)) THEN       (* 9/28/89 EGK *)
        RETURN nextlineobj1;
    END;

    IF (LockObject(nextlineobj1,line1) = 0) THEN
        FatalError();
    END;

    nextlineobj2 := line1^.NextInSeq;
    IF (nextlineobj2 = AnExtHandle(NIL)) THEN 
        IF (NetSummaryFlag IN NetFlags[stask]) THEN
            line1^.EndChar := pDRightTee;
        END;
        ReleaseUnchangedObject(nextlineobj1);
        RETURN AnExtHandle(NIL);
    END;

    IF (LockObject(nextlineobj2,line2) = 0) THEN
        FatalError();
    END;
    line1^.Type := ltype;
    line1^.EndOffset := line2^.LineOffset;
    line2^.StartOffset := line1^.LineOffset;

    CASE line1^.Type  OF
        HORZLINE:
            IF (line2^.EndY > y1) THEN
                line1^.EndChar := pURC;
            ELSIF (line2^.EndY < y1) THEN
                line1^.EndChar := pLRC;
            END;
    |   HORZLINEUP:
            line1^.Type := HORZLINE;
            line1^.EndChar := pLRC;
    |   VERTUP:
            line1^.EndChar := pULC;
    |   VERTDOWN:
            line1^.EndChar := pLLC;
    |   HORZSPACE:
            line1^.EndChar := pHBar;
    |   LEADHORZSPACE:
            line1^.EndChar := pHBar;
    ELSE
    END; (* End of case *)

    ReleaseObject(nextlineobj1);
    ReleaseObject(nextlineobj2);

    RETURN nextlineobj2;

END AdjustCell;



PROCEDURE AdjustMasterTasks(x1,y1,ptask,stask,ltype:INTEGER);
VAR
    cellobj,
    lineobj1,
    nextlineobj1,
    nextlineobj2        : AnExtHandle;
    lastlineobj         : AnExtHandle;
    line1,line2         : LineDrawingRecPnt;
    cell                : SMatrixCellPtr;
    temp                : INTEGER;

BEGIN
    cellobj := SMatrixAdd(x1,y1);
    IF (cellobj = AnExtHandle(NIL)) THEN
        RETURN;
    END;

    IF (LockObject(cellobj,cell) = 0) THEN
        FatalError();
    END;
    nextlineobj1 := cell^.NextLine;    
    ReleaseUnchangedObject(cellobj);

    LOOP
        IF (nextlineobj1 = AnExtHandle(NIL)) THEN       (* 12/4/89 EGK *)
            RETURN;
        END;
        IF (LockObject(nextlineobj1,line1) = 0) THEN
            FatalError();
        END;
        IF ((line1^.StartTask = ptask) AND
            (line1^.EndTask = stask)) THEN
            EXIT;
        END;
        lastlineobj := nextlineobj1;
        nextlineobj1 := line1^.NextNode;
        ReleaseUnchangedObject(lastlineobj);
    END;

    CASE line1^.Type  OF
        TASKTOP:
            Ypos[line1^.StartTask] := YRowOffset[y1-1]+line1^.LineOffset;
    |   TASKRT:
            Xpos[line1^.EndTask] := XColOffset[x1-1]+line1^.LineOffset;
    |   TASKBOT:
            Ypos[line1^.EndTask] := YRowOffset[y1-1]+line1^.LineOffset;
    |   TASKLT:
            Xpos[line1^.StartTask] := XColOffset[x1-1]+line1^.LineOffset;
    ELSE
    END; (* End of case *) 

    ReleaseObject(nextlineobj1);

END AdjustMasterTasks;



PROCEDURE MarkCell(LineGroupID,x1,y1,x2,y2,ptask,stask,ltype:INTEGER; 
                                       critical :BOOLEAN;
                                       lastline :AnExtHandle) :AnExtHandle;
VAR
    cellobj1,
    cellobj2,
    lineobj         : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;

BEGIN
    cellobj1 := SMatrixAdd(x1,y1);
    IF (cellobj1 = AnExtHandle(NIL)) THEN           (* 9/13/89 EGK *)
        RETURN AnExtHandle(NIL);
    END;

    IF (GetExtStatus() = ExtGood) AND       (* 9/13/89 EGK *)
       (CreateExtObjectWithSize(lineobj,ExtSlow,TSIZE(LineDrawingRec))) THEN

        IF (LockObject (lineobj,line) = 0) THEN
            FatalError();
        END;
        line^.EndX := x2;
        line^.EndY := y2;
        line^.StartTask := ptask;
        line^.EndTask := stask;
        line^.LineOffset := 0;
        line^.StartOffset := 0;         (* KWC 12-Sept-89 *)
        line^.EndOffset := 0;
        line^.LineGroup:=LineGroupID;
        line^.Type := ltype;
        line^.NextInSeq := AnExtHandle(NIL);
        line^.Critical := critical;

        CASE line^.Type  OF
            HORZLINE:    line^.EndChar := pHBar;
        |   TASKTOP:     line^.EndChar := pastrUR;
        |   TASKRT:      line^.EndChar := pastrLR;
        |   TASKBOT:     line^.EndChar := pastrLL;
        |   TASKLT:      line^.EndChar := pastrUL;
        ELSE
            line^.EndChar := pVBar; (* vertical line *)
        END; (* End of case *)                      
        
        IF (LockObject(cellobj1,cell) = 0) THEN
            FatalError();
        END;
        line^.NextNode := cell^.NextLine;
        cell^.NextLine := lineobj;
        ReleaseObject(cellobj1);
        ReleaseObject(lineobj);
       
    ELSE
        FatalNetError := TRUE;                (* 9/13/89 EGK *)
        RETURN AnExtHandle(NIL);
    END; 

    IF (lastline <> AnExtHandle(NIL)) THEN
        IF (LockObject(lastline,line) = 0) THEN
            FatalError();
        END;
        line^.NextInSeq := lineobj; 
        ReleaseObject(lastline);
    END;    

    RETURN lineobj;

END MarkCell;



PROCEDURE AdjOutlineLines (VAR TaskTreeNode : ATreeNode;
                         Context      : ADDRESS     );
VAR
    i,savetask,x1,y1,x2,y2:  INTEGER;
    Node                : ATreeNode;
    task                : ATaskPtr;
    stask              : INTEGER;
    ptask              : INTEGER;
    lineobj            : AnExtHandle;
BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject (TaskTreeNode);
    stask := task^.XX;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

    IF (NOT (ShouldDrawFlag IN NetFlags[stask]) OR
        NOT ( NetPhantomFlag IN NetFlags[stask]) OR
         NOT ( NetSummaryFlag IN NetFlags[stask]) ) THEN
        RETURN;
    END;

    Node := TaskTreeNode^.Methods^.GetPrev(TaskTreeNode);   (* phantom *)
    task := Node^.Methods^.LockFlexStorDataObject (Node);
    ptask := task^.XX;
    Node^.Methods^.UnlockUnchangedDataObject (Node);

    y1:=Ypos[ptask];
    x1:=Xpos[ptask];
    y2:=Ypos[stask];
    x2:=Xpos[stask];
  
    AdjustMasterTasks(x1,y1-HALFFACT,ptask,stask,TASKTOP);

    AdjustMasterTasks(x2,y1-HALFFACT,ptask,stask,TASKRT);

    AdjustMasterTasks(x2,y2+HALFFACT,ptask,stask,TASKBOT);

    AdjustMasterTasks(x1,y2+HALFFACT,ptask,stask,TASKLT);

END AdjOutlineLines;



PROCEDURE MasterBox (VAR TaskTreeNode : ATreeNode;
                         Context      : ADDRESS     );
VAR
    i,savetask,x1,y1,x2,y2:  INTEGER;
    Node                : ATreeNode;
    task                : ATaskPtr;
    stask              : INTEGER;
    ptask              : INTEGER;
    lineobj            : AnExtHandle;
    lastline           :AnExtHandle;
    critical           : BOOLEAN;
BEGIN
    IF(TaskTreeNode^.Methods^.TestAttributeBit(TaskTreeNode,InvisibleNode)) THEN RETURN END;

    task := TaskTreeNode^.Methods^.LockFlexStorDataObject (TaskTreeNode);
    stask := task^.XX;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject (TaskTreeNode);

    IF (NOT (ShouldDrawFlag IN NetFlags[stask]) OR
        NOT ( NetPhantomFlag IN NetFlags[stask]) OR
         NOT ( NetSummaryFlag IN NetFlags[stask]) ) THEN
        RETURN;
    END;

    Node := TaskTreeNode^.Methods^.GetPrev(TaskTreeNode);   (* phantom *)
    task := Node^.Methods^.LockFlexStorDataObject (Node);
    ptask := task^.XX;
    Node^.Methods^.UnlockUnchangedDataObject (Node);

    y1:=Ypos[ptask];
    x1:=Xpos[ptask];
    y2:=Ypos[stask];
    x2:=Xpos[stask];
    INC(LineGroupID);

    critical:=FALSE;
    lastline:=MarkCell(LineGroupID,x1,y1-HALFFACT,x2,y1-HALFFACT,
                                            ptask,stask,TASKTOP,critical,AnExtHandle(NIL));

    lastline:=MarkCell(LineGroupID,x2,y1-HALFFACT,x2,y2+HALFFACT,
                                            ptask,stask,TASKRT,critical,AnExtHandle(NIL));

    lastline:=MarkCell(LineGroupID,x2,y2+HALFFACT,x1,y2+HALFFACT,
                                            ptask,stask,TASKBOT,critical,AnExtHandle(NIL));

    lastline:=MarkCell(LineGroupID,x1,y2+HALFFACT,x1,y1-HALFFACT,
                                            ptask,stask,TASKLT,critical,AnExtHandle(NIL));

END MasterBox;




PROCEDURE SMatrixAdd( xpos,ypos: INTEGER) : AnExtHandle;
VAR
    newcellobj,
    lastcellobj,
    nextcellobj             : AnExtHandle;
    newcell,cell            : SMatrixCellPtr;
    NextX, NextY            : AnExtHandle;
    XValue, YValue          : INTEGER;

BEGIN

    IF (xpos > UpperXDim) OR (ypos > UpperYDim) THEN    (* 10/4/89 EGK *)
        MatrixOverflow := TRUE;
        RETURN AnExtHandle(NIL);
    END;

    (* First see if the cell is already there *)

    IF (SMatrixArrayX[xpos] = AnExtHandle(NIL)) THEN  (* nothing in that col *)

        IF (GetExtStatus() = ExtGood) AND           (* 9/13/89 EGK *)
           (CreateExtObjectWithSize(newcellobj,ExtSlow,TSIZE(SMatrixCell))) THEN

            IF (LockObject(newcellobj,newcell) = 0) THEN
                FatalError();
            END;
            newcell^.YValue := ypos;
            newcell^.XValue := xpos;
            newcell^.TaskId := 0;
            newcell^.NextY  := AnExtHandle(NIL);
            newcell^.NextX  := AnExtHandle(NIL);
            newcell^.NextLine := AnExtHandle(NIL);
            ReleaseObject (newcellobj);

            SMatrixArrayX[xpos] := newcellobj;
        ELSE
            FatalNetError := TRUE;                (* 9/13/89 EGK *)
            RETURN AnExtHandle(NIL);
        END;

    ELSE
        nextcellobj := SMatrixArrayX[xpos];
        lastcellobj := AnExtHandle(NIL);

        LOOP
            IF (LockObject(nextcellobj,cell) = 0) THEN
                FatalError();
            END;
            YValue := cell^.YValue;
            NextY := cell^.NextY;
            ReleaseUnchangedObject (nextcellobj);

            IF (YValue = ypos) THEN
                RETURN nextcellobj;
            END;
            IF (YValue > ypos) THEN
                EXIT;
            END;

            lastcellobj := nextcellobj;
            nextcellobj := NextY;

            IF (nextcellobj = AnExtHandle(NIL)) THEN
                EXIT;
            END;
        END;

        (* Make new cell *)

        IF (GetExtStatus() = ExtGood) AND           (* 9/13/89 EGK *)
           (CreateExtObjectWithSize(newcellobj,ExtSlow,TSIZE(SMatrixCell))) THEN

            IF (LockObject(newcellobj,newcell) = 0) THEN
                FatalError();
            END;
            newcell^.YValue := ypos;
            newcell^.XValue := xpos;
            newcell^.NextX := AnExtHandle(NIL);
            newcell^.TaskId := 0;
            newcell^.NextLine := AnExtHandle(NIL);

            IF (lastcellobj = AnExtHandle(NIL)) THEN
                SMatrixArrayX[xpos] := newcellobj;
                newcell^.NextY := nextcellobj;
            ELSE  
                IF (nextcellobj = AnExtHandle(NIL)) THEN
                    newcell^.NextY := AnExtHandle(NIL);
                ELSE 
                    newcell^.NextY := nextcellobj;
                END; 

                IF (LockObject (lastcellobj,cell) = 0) THEN
                    FatalError();
                END;
                cell^.NextY := newcellobj;
                ReleaseObject(lastcellobj);
            END;  
            ReleaseObject (newcellobj);
        ELSE
            FatalNetError := TRUE;
            RETURN AnExtHandle(NIL);
        END;  
    END;
  
    IF (SMatrixArrayY[ypos] = AnExtHandle(NIL)) THEN  (* nothing in that col *)
        SMatrixArrayY[ypos] := newcellobj;
        RETURN newcellobj;
    ELSE
        nextcellobj := SMatrixArrayY[ypos];
        lastcellobj := AnExtHandle(NIL);

        LOOP
            IF (LockObject(nextcellobj,cell) = 0) THEN
                FatalError();
            END;
            XValue := cell^.XValue;
            NextX := cell^.NextX;
            ReleaseUnchangedObject (nextcellobj);

            IF (XValue > xpos) THEN
                EXIT;
            END;

            lastcellobj := nextcellobj;
            nextcellobj := NextX;

            IF (nextcellobj = AnExtHandle(NIL)) THEN
                EXIT;
            END;
        END;

        (* Make new cell *)

        IF (LockObject (newcellobj,newcell) = 0) THEN
            FatalError();
        END;

        IF (lastcellobj = AnExtHandle(NIL)) THEN
            newcell^.NextX := SMatrixArrayY[ypos];
            SMatrixArrayY[ypos] := newcellobj;
        ELSE  
            IF (nextcellobj = AnExtHandle(NIL)) THEN
                newcell^.NextX := AnExtHandle(NIL);
            ELSE 
                newcell^.NextX := nextcellobj;
            END;

            IF (LockObject(lastcellobj,cell) = 0) THEN
                FatalError();
            END;
            cell^.NextX := newcellobj;
            ReleaseObject(lastcellobj);
        END;
        ReleaseObject(newcellobj);
    END;

    RETURN newcellobj;

END SMatrixAdd;



PROCEDURE SortVertLinesInMatrix;
VAR
    i,extralines    : INTEGER;
    nextcellobj,
    lastcellobj,
    nextlineobj,
    lastlineobj     : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;
    xx1,yy1,
    xx2,yy2         : INTEGER;
    x1,y1,x2,y2,
    FirstInList,
    k,
    deltay          : INTEGER;
    LastWasTask     : BOOLEAN;

BEGIN
    (* Put out vert lines *)
    i := 1;
    XColOffset[0] := 1;
    LastWasTask := FALSE;

    LOOP
        (* Clear wiring harness *)
        FirstInList := 0;
        k := 0;
        MaxLines := 0;
        extralines:= 0;

        IF ((SMatrixArrayX[i] <> AnExtHandle(NIL))) THEN
            (*     (( i MOD 2)=1) ) THEN    *)
            nextcellobj := SMatrixArrayX[i];
            MaxLines := 1;
            LOOP
                IF (k > HARNESSDIM) THEN        (* 9/8/89 EGK *)
                    EXIT;
                END;

                IF (LockObject(nextcellobj,cell) = 0) THEN
                    FatalError();
                END;
                lastcellobj := nextcellobj;

                IF (cell^.TaskId <> 0) THEN
                    IF(LastWasTask) THEN
                       INC(XColOffset[i-1]);            (* 11/6/89 KWC/EGK *)
                    END;
                    LastWasTask:=TRUE;
                    ReleaseUnchangedObject(nextcellobj);
                    EXIT;
                END;
                LastWasTask:=FALSE;
                x1 := cell^.XValue;
                y1 := cell^.YValue;

                nextlineobj := cell^.NextLine;
                nextcellobj := cell^.NextY;
                ReleaseUnchangedObject(lastcellobj);

                (*  for each line that starts here *)
                LOOP
                    IF (nextlineobj = AnExtHandle(NIL)) THEN
                        EXIT;
                    END;

                    IF (LockObject(nextlineobj,line) = 0) THEN
                        FatalError();
                    END;

                    (* Find a slot for this line *)
                    IF ((line^.Type = SLINE) OR
                        (line^.Type = PLINE) OR
                        (line^.Type = HORZSPACE) OR
                        (line^.Type = LEADHORZSPACE) OR
                        (line^.Type = TASKRT) OR
                        (line^.Type = TASKLT) )THEN
                        IF(line^.Type = HORZSPACE) THEN extralines:=1; END;
                        INC(k);
                        IF (k > HARNESSDIM) THEN
                            ReleaseUnchangedObject (nextlineobj);
                            EXIT;                   (* 9/8/89 EGK *)
                        END;

                        NextNo[k] := 0;
                        ChanNo[k] := 0;
                        VLineType[k]:=line^.LineGroup;
                        StartPos[k] := y1 ;
                        LineObj[k] := nextlineobj;
                        EndPos[k] := line^.EndY;
                        IF (EndPos[k] < StartPos[k]) THEN
                            StartPos[k] := line^.EndY;
                            EndPos[k] := y1;
                        END;

                        xx1 := Xpos[line^.StartTask];
                        yy1 := Ypos[line^.StartTask];
                        xx2 := Xpos[line^.EndTask];
                        yy2 := Ypos[line^.EndTask];
                        deltay := yy2-yy1;

                        IF (deltay > 0) THEN  (* Drawing down *)
                            IF(line^.Type = SLINE) THEN
                                Sort1[k] := 7;
                                Sort2[k] := xx1;
                                Sort3[k] := MaxInt-yy1;
                                Sort4[k] := 0;
                     (*         IF((xx1+HALFFACT)=(xx2-HALFFACT)) THEN
                                    StartPos[k] := -StartPos[k];
                                END; *)

                                StartPos[k] := -StartPos[k];

                            ELSE
                                Sort1[k] := 2;
                                Sort2[k] := MaxInt-yy2;
                                Sort3[k] := MaxInt-yy1;
                                Sort4[k] := xx2;
                   (*           IF((xx1+HALFFACT)=(xx2-HALFFACT)) THEN
                                    EndPos[k] := -EndPos[k];
                                END; *)

                                EndPos[k] := -EndPos[k];

                            END;
                        ELSIF (deltay < 0) THEN    (* Drawing Up *)
                            IF (line^.Type = SLINE) THEN
                                Sort1[k] := 6;
                                Sort2[k] := xx1;
                                Sort3[k] := yy1;
                                Sort4[k] := yy2;
                        (*      IF((xx1+HALFFACT)=(xx2-HALFFACT)) THEN
                                    EndPos[k] := -EndPos[k];
                                END;  *)
                                EndPos[k] := -EndPos[k];

                            ELSE
                                Sort1[k] := 1;
                                Sort2[k] := yy2;
                                Sort3[k] := yy1;
                                Sort4[k] := xx2;
                         (*     IF((xx1+HALFFACT)=(xx2-HALFFACT)) THEN
                                    StartPos[k] := -StartPos[k];
                                END; *)

                                StartPos[k] := -StartPos[k];

                            END;
                        ELSE
                            IF (line^.Type = SLINE) THEN
                                Sort1[k] := 5;
                                Sort2[k] := MaxInt-xx1;
                                Sort3[k] := 0;
                                Sort4[k] := 0;
                            ELSE
                                Sort1[k] := 3;
                                Sort2[k] := 0;
                                Sort3[k] := 0;
                                Sort4[k] := MaxInt-xx2;
                            END;
                        END;

                        IF (line^.Type = TASKLT) THEN
                            VLineType[k]:=VMasterLine;
                            Sort1[k] := 8;
                            Sort2[k] := loopnode^[line^.StartTask]^.Methods^.
                                        IndentationLevel(loopnode^[line^.StartTask]);
                            Sort3[k] := 0;
                            Sort4[k] := 0;
                            StartPos[k] := StartPos[k]+1;
                            EndPos[k] := EndPos[k]-1;
                        ELSIF (line^.Type = TASKRT) THEN
                            VLineType[k]:=VMasterLine;
                            Sort1[k] := 1;
                            Sort2[k] := MaxInt-loopnode^[line^.StartTask]^.Methods^.
                                        IndentationLevel(loopnode^[line^.StartTask]);
                            Sort3[k] := 0;
                            Sort4[k] := 0;
                            StartPos[k] := StartPos[k]+1;
                            EndPos[k] := EndPos[k]-1;
                        END;

                        IF (line^.Type = HORZSPACE) THEN
                            Sort1[k] := 4;
                        END;
                        IF (line^.Type = LEADHORZSPACE) THEN
                            Sort1[k] := 1;
                        END;

                        SortInList(FirstInList,k);
                    END;

                    lastlineobj := nextlineobj;
                    nextlineobj := line^.NextNode;
                    ReleaseUnchangedObject(lastlineobj);
                END;

                IF (nextcellobj = AnExtHandle(NIL)) THEN
                    EXIT;
                END;
            END;
        END;

        IF (FirstInList > 0) THEN
         (*   PrintSCard(ORD(i),"Vert lines "); *)
            AssignOffsets(FirstInList);
        END;

        XColOffset[i] := XColOffset[i-1]+MaxLines+extralines;      (* KWC 12-Sep-89 *)
        INC(i);
        IF (i = UpperXDim)  THEN
            EXIT;
        END;
    END;
END SortVertLinesInMatrix;



PROCEDURE SortHorzLinesInMatrix;
VAR
    i               : INTEGER;
    nextcellobj,
    lastcellobj,
    nextlineobj,
    lastlineobj     : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;
    x1,y1,x2,y2,
    FirstInList,
    k,deltay        : INTEGER;
    xx1,yy1,
    xx2,yy2         : INTEGER;

BEGIN
    (* Put out horz lines *)
    i := 1;
    YRowOffset[0] := 1;

    LOOP  (* For each row *)
        (* Clear wiring harness *)
        k := 0;
        FirstInList := 0;
        MaxLines := 0;

        IF ((SMatrixArrayY[i] <> AnExtHandle(NIL))) THEN
        (*     (( i MOD 2)=1) ) THEN    *)
            MaxLines := 1;
            nextcellobj := SMatrixArrayY[i];

            LOOP (* For each cell *)
                IF (k > HARNESSDIM) THEN        (* 9/8/89 EGK *)
                    EXIT;
                END;

                IF (LockObject(nextcellobj,cell) = 0) THEN
                    FatalError();
                END;

                lastcellobj := nextcellobj;
                x1 := cell^.XValue;
                y1 := cell^.YValue;

                IF (cell^.TaskId <> 0) THEN
                    FirstInList := 0;
                    ReleaseUnchangedObject(nextcellobj);
                    EXIT; (* Loop for each cell *)
                END;

                nextlineobj := cell^.NextLine;
                nextcellobj := cell^.NextX;
                ReleaseUnchangedObject(lastcellobj);

                (*  for each line that starts or end here *)
                LOOP  (* For each line *)
                    IF (nextlineobj = AnExtHandle(NIL)) THEN
                        EXIT; (* Exit loop for each line *)
                    END;

                    IF (LockObject(nextlineobj,line) = 0) THEN
                        FatalError();
                    END;

                    (* Find a slot for this line *)
                    IF((line^.Type = HORZLINE) OR
                        (line^.Type = TASKTOP) OR
                        (line^.Type = TASKBOT) ) THEN

                        INC(k);
                        IF (k > HARNESSDIM) THEN        (* 9/8/89 EGK *)
                            ReleaseUnchangedObject (nextlineobj);
                            EXIT;
                        END;
                        VLineType[k]:=line^.LineGroup;
                        NextNo[k] := 0;
                        ChanNo[k] := 0;
                        StartPos[k] := x1;
                        LineObj[k] := nextlineobj;
                        EndPos[k] := line^.EndX;
                        IF (EndPos[k] < StartPos[k]) THEN
                            StartPos[k] := line^.EndX;
                            EndPos[k] := x1;
                        END;

                        xx1 := Xpos[line^.StartTask];
                        yy1 := Ypos[line^.StartTask];
                        xx2 := Xpos[line^.EndTask];
                        yy2 := Ypos[line^.EndTask];
                        deltay := yy2-yy1;

                        IF (deltay > 0) THEN  (* drawing up *)
                            Sort1[k] := 4;
                            Sort2[k] := MaxInt-xx1;
                            Sort3[k] := MaxInt-xx2;
                            Sort4[k] := yy1;
                        ELSIF (deltay < 0) THEN  (* drawing up *)
                            Sort1[k] := 1;
                            Sort2[k] := xx1;
                            Sort3[k] := xx2;
                            Sort4[k] := yy1;
                        ELSE
                            Sort1[k] := 0;
                            Sort2[k] := MaxInt-xx1;
                            Sort3[k] := xx2;
                            Sort4[k] := yy1;
                        END;

                        IF (line^.Type = TASKTOP) THEN
                            Sort1[k] := 5;
                            Sort2[k] := loopnode^[line^.StartTask]^.Methods^.
                                        IndentationLevel(loopnode^[line^.StartTask]);
                            Sort3[k] := 0;
                            Sort4[k] := 0;
                            StartPos[k] := StartPos[k]+1;
                            EndPos[k] := EndPos[k]-1;
                        ELSIF (line^.Type = TASKBOT) THEN
                            Sort1[k] := 3;
                            Sort2[k] := MaxInt-loopnode^[line^.StartTask]^.Methods^.
                                        IndentationLevel(loopnode^[line^.StartTask]);
                            Sort3[k] := 0;
                            Sort4[k] := 0;
                            StartPos[k] := StartPos[k]+1;
                            EndPos[k] := EndPos[k]-1;
                        END;

                        SortInList(FirstInList,k);
                    END;

                    lastlineobj := nextlineobj;
                    nextlineobj := line^.NextNode;
                    ReleaseUnchangedObject(lastlineobj);
                END;  (* End loop for each line *)

                IF (nextcellobj = AnExtHandle(NIL)) THEN
                    EXIT; (* Exit loop for each cell *)
                END;

            END;(* End loop for each cell *)
        END; (* End check for nil cell *)

    (* Now we assign channels *)

        IF (FirstInList > 0) THEN
          (*  PrintSCard(ORD(i),"Horz lines "); *)
            AssignOffsets(FirstInList);
        END;

        YRowOffset[i] := YRowOffset[i-1]+MaxLines;

        INC(i);
        IF (i = UpperYDim)  THEN
            EXIT;
        END;
    END;
END SortHorzLinesInMatrix;



PROCEDURE SortInList(VAR firstinlist,k :INTEGER);
VAR
    i,lastinlist,nextinlist: INTEGER;
BEGIN
  IF(firstinlist=0) THEN
    firstinlist:=k;
    RETURN;
  END;
  IF(Sort1[firstinlist]=Sort1[k]) THEN  
    IF(Sort2[firstinlist]=Sort2[k]) THEN  
      IF(Sort3[firstinlist]=Sort3[k]) THEN  
        IF(Sort4[firstinlist]>Sort4[k]) THEN
          NextNo[k]:=firstinlist;
          firstinlist:=k;
          RETURN;
        END;
      ELSE
        IF(Sort3[firstinlist]>Sort3[k]) THEN
          NextNo[k]:=firstinlist;
          firstinlist:=k;
          RETURN;
        END;
      END;
    ELSE
      IF(Sort2[firstinlist]>Sort2[k]) THEN
         NextNo[k]:=firstinlist;
         firstinlist:=k;
         RETURN;
      END;
    END;
  ELSE
    IF(Sort1[firstinlist]>Sort1[k]) THEN
      NextNo[k]:=firstinlist;
      firstinlist:=k;
      RETURN;
    END;
  END;
  lastinlist:=firstinlist;
  nextinlist:=NextNo[firstinlist];
  LOOP
     IF(nextinlist=0) THEN
      NextNo[lastinlist]:=k;
      RETURN;
    END;  
    IF(Sort1[nextinlist]=Sort1[k]) THEN  
      IF(Sort2[nextinlist]=Sort2[k]) THEN  
        IF(Sort3[nextinlist]=Sort3[k]) THEN  
          IF(Sort4[nextinlist]>Sort4[k]) THEN
            NextNo[lastinlist]:=k;
            NextNo[k]:=nextinlist;
            RETURN;
             
          END;
        ELSE
          IF(Sort3[nextinlist]>Sort3[k]) THEN
            NextNo[lastinlist]:=k;
            NextNo[k]:=nextinlist;
            RETURN;
          END;
        END;
      ELSE
        IF(Sort2[nextinlist]>Sort2[k]) THEN
          NextNo[lastinlist]:=k;
          NextNo[k]:=nextinlist;
          RETURN;
        END;
      END;
    ELSE
      IF(Sort1[nextinlist]>Sort1[k]) THEN
        NextNo[lastinlist]:=k;
        NextNo[k]:=nextinlist;
        RETURN;
      END;
    END;
    lastinlist:=nextinlist;
    nextinlist:=NextNo[nextinlist];
  END;
END SortInList;



PROCEDURE AssignOffsets(FirstInList:INTEGER);    (* 11-Nov-89 *)
VAR
    nextinlist,nexttomove:INTEGER;
    line :LineDrawingRecPnt;
    lastinlist,lastused,nexttocheck :INTEGER;
    Adjustlineoffset,FoundEnd: BOOLEAN;
BEGIN
   nextinlist:=FirstInList;
   nexttomove:=NextNo[nextinlist];
   
   
   IF(nexttomove=0) THEN
   RETURN;
   END;
   REPEAT
     WHILE nexttomove<>nextinlist  DO
       IF(NOT ((ABS(EndPos[nexttomove])<ABS(StartPos[nextinlist])) OR
             (ABS(StartPos[nexttomove])>ABS(EndPos[nextinlist])))) THEN
           IF(ChanNo[nexttomove]<=ChanNo[nextinlist]) THEN 
           (* move it *) 
           IF(ABS(EndPos[nexttomove])=ABS(StartPos[nextinlist])) THEN
             ChanNo[nexttomove]:=ChanNo[nextinlist];
             IF(NOT (VLineType[nexttomove]=VLineType[nextinlist])) THEN
                INC(ChanNo[nexttomove]); 
             END;
           ELSIF(ABS(EndPos[nextinlist])=ABS(StartPos[nexttomove])) THEN
             ChanNo[nexttomove]:=ChanNo[nextinlist];
             IF(NOT(VLineType[nexttomove]=VLineType[nextinlist])) THEN
                INC(ChanNo[nexttomove]); 
             END;
           ELSE
             ChanNo[nexttomove]:=ChanNo[nextinlist]+1;
           END;  
         END;  
      END; 
       nextinlist:=NextNo[nextinlist];
     END;
     nextinlist:=FirstInList;
     lastinlist:=nexttomove;
     nexttomove:=NextNo[nexttomove];
   UNTIL nexttomove=0; 
   (*  Scan backwords to adjust lines *) 
   
   REPEAT
      nexttocheck:=FirstInList;
      nexttomove:=0;
      
  (*    PrintSCard(ORD(lastinlist),"last in list at top ");
      PrintSCard(ORD(ChanNo[lastinlist]),"Ch last in list at top"); *)
      
      
      Adjustlineoffset:=FALSE;
      (* See if there is a line that might be moved *)
      LOOP
          IF((VLineType[nexttocheck]=VLineType[lastinlist]) AND
             (VLineType[nexttocheck]<>VMasterLine)) THEN
              IF((ABS(EndPos[nexttocheck])=ABS(StartPos[lastinlist])) OR
                 (ABS(EndPos[lastinlist])=ABS(StartPos[nexttocheck]))) THEN
                  nexttomove:=nexttocheck;
      EXIT;            
              END;
          END;   
         lastused:=nexttocheck;
         nexttocheck:=NextNo[nexttocheck];
         IF(nexttocheck=lastinlist) THEN
      EXIT; 
         END;
      END;  
      FoundEnd:=FALSE; 
      IF(nexttomove<>0) THEN
         Adjustlineoffset:=TRUE;
         (*   PrintSCard(ORD(lastinlist),"last in list ");
            PrintSCard(ORD(ChanNo[lastinlist]),"Ch last in list ");
            PrintSCard(ORD(ChanNo[nexttomove]),"Ch next to move ");
            PrintSCard(ORD(ABS(StartPos[nexttomove])),"Start next to move ");
            PrintSCard(ORD(ABS(EndPos[nexttomove])),"End next to move "); *)
         REPEAT
             IF(NOT((ABS(EndPos[nexttomove])<ABS(StartPos[nexttocheck])) OR
                 (ABS(StartPos[nexttomove])>ABS(EndPos[nexttocheck])))) THEN
            
                  IF((nexttomove<>nexttocheck) AND (nexttocheck<>lastinlist)) THEN 
                     IF(ABS(EndPos[nexttomove])=ABS(StartPos[nexttocheck])) THEN
                         IF(ChanNo[lastinlist]=ChanNo[nexttocheck]) THEN
                               Adjustlineoffset:=FALSE; 
                         END;
                     ELSIF(ABS(EndPos[nexttocheck])=ABS(StartPos[nexttomove])) THEN
                         IF(ChanNo[lastinlist]=ChanNo[nexttocheck]) THEN
  (*                          PrintSMsg("Place 2");
             PrintSCard(ORD(lastinlist),"last in list ");
            PrintSCard(ORD(ChanNo[lastinlist]),"Ch last in list ");
            PrintSCard(ORD(ChanNo[nexttomove]),"Ch next to move ");
            PrintSCard(ORD(ABS(StartPos[nexttomove])),"Start next to move ");
            PrintSCard(ORD(ABS(EndPos[nexttomove])),"End next to move "); 
            PrintSCard(ORD(ChanNo[nexttocheck]),"Ch next to check ");
            PrintSCard(ORD(ABS(StartPos[nexttocheck])),"Start next to move ");
            PrintSCard(ORD(ABS(EndPos[nexttocheck])),"End next to move "); *) 
                               Adjustlineoffset:=FALSE; 
                         END;
                     ELSE
                         IF(ChanNo[nexttocheck]<=ChanNo[lastinlist]) THEN
                         (*   PrintSMsg("Place 3"); *)
                            Adjustlineoffset:=FALSE; 
                         END;
                     END;  
                  END;  
             END;       
         IF(FoundEnd=FALSE) THEN lastused:=nexttocheck; END;
         nexttocheck:=NextNo[nexttocheck];
         IF(nexttocheck=lastinlist) THEN 
           FoundEnd:=TRUE; 
         END;
      UNTIL((nexttocheck=0) OR 
               ((ChanNo[nexttocheck]>ChanNo[lastinlist]) AND
                (FoundEnd=TRUE)));
      END;
      IF(Adjustlineoffset=TRUE) THEN
         ChanNo[nexttomove]:=ChanNo[lastinlist];
      END;
      lastinlist:=lastused;
   UNTIL lastinlist=FirstInList; 
   nextinlist:=FirstInList;
   REPEAT
     IF(LockObject(LineObj[nextinlist],line)=0) THEN
        FatalError(); END;
     line^.LineOffset:=ChanNo[nextinlist];
     IF(ChanNo[nextinlist]>(MaxLines-1)) THEN MaxLines:=ChanNo[nextinlist]+1; END;
     ReleaseObject(LineObj[nextinlist]);
     nextinlist:=NextNo[nextinlist];
   UNTIL nextinlist=0;  
END AssignOffsets;



PROCEDURE PutVertLinesInMatrix;

VAR
    i               : INTEGER;
    nextcellobj,
    lastcellobj,
    nextlineobj,
    lastlineobj     : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;
    x1,y1,x2,y2,
    yout,xout       : INTEGER;
    TaskID          : INTEGER;
    ch              : INTEGER;

BEGIN
  (* Put out vertical lines *)

    i := 0;

    LOOP
        IF (SMatrixArrayX[i] <> AnExtHandle(NIL)) THEN  (* something in that col *)

            CheckForBreak();                    (* 9/19/89 EGK *)
            IF (FatalNetError) THEN
                RETURN;
            END;

            nextcellobj := SMatrixArrayX[i];

            LOOP

                IF (LockObject(nextcellobj,cell) = 0) THEN
                    FatalError();
                END;
                lastcellobj := nextcellobj;
                x1 := cell^.XValue;
                y1 := cell^.YValue;
                nextlineobj := cell^.NextLine;    
                nextcellobj := cell^.NextY;   
                TaskID := cell^.TaskId;
                ReleaseUnchangedObject(lastcellobj);
        
                IF ((TaskID > 0) AND (TaskID < MaxInt)) THEN

                    SetCell(YRowOffset[y1-1],XColOffset[x1-1],TaskID);
                    Xpos[TaskID]    := XColOffset[x1-1];
                    Utility[TaskID] := XColOffset[x1-1];
                    Xmaxpos[TaskID] := XColOffset[x1-1];
                    Ypos[TaskID]    := YRowOffset[y1-1];

                    IF (Xpos[TaskID] > SnetCols) THEN
                        SnetCols := Xpos[TaskID];
                    END;
                    IF (Ypos[TaskID] > SnetRows) THEN
                        SnetRows := Ypos[TaskID];
                    END;
                    IF (Xpos[TaskID] < SnetColOne) THEN
                        SnetColOne := Xpos[TaskID];
                    END;
                    IF (Ypos[TaskID] < SnetRowOne) THEN
                        SnetRowOne := Ypos[TaskID];
                    END;
                END;

                IF (nextlineobj <> AnExtHandle(NIL)) THEN
                    LOOP
                        IF (LockObject(nextlineobj,line) = 0) THEN
                            FatalError();
                        END;
                        xout := XColOffset[x1-1]+line^.LineOffset;
                        y2 := line^.EndY;

                        IF ((line^.Type = VERTDOWN) OR (line^.Type = VERTUP)) THEN

                            yout := YRowOffset[y2-1]+line^.EndOffset;
                            IF (GetCell(yout,xout) <= 0) THEN 
                                ch := line^.EndChar;
                                IF (line^.Critical) THEN
                                    DEC (ch, COLORBIAS);
                                END;
                                SetCell (yout, xout, ch);
                            END; 
                            ch := pVBar;
                            IF (line^.Critical) THEN
                                DEC (ch, COLORBIAS);
                            END;
                            DrawVert (xout,YRowOffset[y1-1]+line^.StartOffset,yout,ch);


                        ELSIF (line^.Type = TASKRT) THEN

                            IF ((GetCell(Ypos[line^.EndTask],Xpos[line^.EndTask])<=0)) THEN
                                SetCell(Ypos[line^.EndTask],Xpos[line^.EndTask],line^.EndChar);
                            END;
                            DrawVert(Xpos[line^.EndTask],Ypos[line^.StartTask],
                                     Ypos[line^.EndTask],pVDash);

                        ELSIF (line^.Type = TASKLT) THEN 

                            IF ((GetCell(Ypos[line^.StartTask],Xpos[line^.StartTask])<=0)) THEN
                                SetCell(Ypos[line^.StartTask],Xpos[line^.StartTask],line^.EndChar);
                            END; 
                            DrawVert(Xpos[line^.StartTask],Ypos[line^.StartTask],
                                     Ypos[line^.EndTask],pVDash); 
        
                        END;

                        lastlineobj := nextlineobj; 
                        nextlineobj := line^.NextNode;
                        ReleaseUnchangedObject(lastlineobj);

                        IF (nextlineobj = AnExtHandle(NIL)) THEN
                            EXIT; 
                        END;
                    END;  
                END; 
                IF (nextcellobj = AnExtHandle(NIL)) THEN
                    EXIT;
                END;
            END;
        END;

        INC(i);
        IF (i = UpperXDim)  THEN
            EXIT;
        END;
    END;  
END PutVertLinesInMatrix;


 
PROCEDURE PutHorzLinesInMatrix;

VAR
    i               : INTEGER;
    nextcellobj,
    lastcellobj,
    nextlineobj,
    lastlineobj     : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;
    x1,y1,x2,y2,
    yout,xout,
    check           : INTEGER;
    ch              : INTEGER;

BEGIN
    (* Put out horz lines *)
    i := 0;
    LOOP
        IF(SMatrixArrayY[i]<>AnExtHandle(NIL)) THEN  (* soomthing in that col *)

            CheckForBreak();                    (* 9/19/89 EGK *)
            IF (FatalNetError) THEN
                RETURN;
            END;

            nextcellobj:=SMatrixArrayY[i];

            LOOP

                IF (LockObject(nextcellobj,cell) = 0) THEN
                    FatalError();
                END;
                lastcellobj := nextcellobj;
                y1 := cell^.YValue;
                x1 := cell^.XValue;
                nextlineobj := cell^.NextLine;
                nextcellobj := cell^.NextX;
                ReleaseUnchangedObject(lastcellobj);

                IF (nextlineobj <> AnExtHandle(NIL)) THEN
                    LOOP
                        IF (LockObject(nextlineobj,line) = 0) THEN
                            FatalError();
                        END;
                        yout := YRowOffset[y1-1]+line^.LineOffset;
                        x2 := line^.EndX;

                        IF (line^.Type = HORZLINE) THEN

                            xout := XColOffset[x2-1]+line^.EndOffset;
                            check := XColOffset[x2-1]-XColOffset[x1-1]
                                       -line^.StartOffset+line^.EndOffset;

                            IF (check <> 0) THEN
                                IF ((GetCell(yout,xout) <= 0) AND
                                        (line^.EndChar <> pHBar)) THEN
                                    ch := line^.EndChar;
                                    IF (line^.Critical) THEN
                                        DEC (ch, COLORBIAS);
                                    END;
                                    SetCell(yout,xout,ch);
                                END;
                                ch := pHBar;
                                IF (line^.Critical) THEN
                                    DEC (ch, COLORBIAS);
                                END;
                                DrawHorz (XColOffset[x1-1]+line^.StartOffset,yout,xout,ch);
                            ELSE
                                ch := pVBar;
                                IF (line^.Critical) THEN
                                    DEC (ch, COLORBIAS);
                                END;
                                SetCell(yout,xout,ch);
                            END;

                        ELSIF (line^.Type = TASKTOP) THEN

                            IF ((GetCell(Ypos[line^.StartTask],Xpos[line^.EndTask])<=0)) THEN
                                SetCell(Ypos[line^.StartTask],Xpos[line^.EndTask],line^.EndChar);
                            END;
                                (* Fill in Master Task Corners *)
                            Utility[line^.StartTask] := Xpos[line^.StartTask];
                            Xmaxpos[line^.StartTask] := Xpos[line^.EndTask];
                            Ymaxpos[line^.StartTask] := Ypos[line^.EndTask];
                            DrawHorz(Xpos[line^.StartTask],Ypos[line^.StartTask],
                                     Xpos[line^.EndTask],pdash);
                            Xpos[line^.StartTask] := FindMasterXpos(line^.StartTask);
                            SetCell(Ypos[line^.StartTask],
                                    Xpos[line^.StartTask],line^.StartTask);

                        ELSIF (line^.Type = TASKBOT) THEN

                            IF ((GetCell(Ypos[line^.EndTask],Utility[line^.StartTask])<=0)) THEN
                                SetCell(Ypos[line^.EndTask],Utility[line^.StartTask],line^.EndChar);
                            END;
                            DrawHorz(Utility[line^.StartTask],Ypos[line^.EndTask],
                                     Xpos[line^.EndTask],pdash);

                        END;

                        lastlineobj := nextlineobj;
                        nextlineobj := line^.NextNode;
                        ReleaseUnchangedObject(lastlineobj);

                        IF (nextlineobj = AnExtHandle(NIL)) THEN
                            EXIT;
                        END;
                    END;
                END;
                IF (nextcellobj = AnExtHandle(NIL)) THEN
                    EXIT;
                END;
            END;
        END;

        INC(i);
        IF(i = UpperYDim)  THEN
            EXIT;
        END;
    END;
END PutHorzLinesInMatrix;



PROCEDURE DiscardSMatrix ();

VAR
    i               : INTEGER;
    nextcellobj,
    lastcellobj,
    nextlineobj,
    lastlineobj     : AnExtHandle;
    line            : LineDrawingRecPnt;
    cell            : SMatrixCellPtr;

BEGIN

    i := 0;
    LOOP
        nextcellobj := SMatrixArrayY[i];

        LOOP
            IF (nextcellobj = AnExtHandle(NIL)) THEN
                EXIT;
            END;

            IF (LockObject(nextcellobj,cell) = 0) THEN
                FatalError();
            END;
            lastcellobj := nextcellobj;
            nextlineobj := cell^.NextLine;    
            nextcellobj := cell^.NextX;   
            ReleaseUnchangedObject(lastcellobj);
            DiscardExtObject(lastcellobj);

            LOOP
                IF (nextlineobj = AnExtHandle(NIL)) THEN
                    EXIT; 
                END;

                IF (LockObject(nextlineobj,line) = 0) THEN
                    FatalError();
                END;
                lastlineobj := nextlineobj;
                nextlineobj := line^.NextNode;
                ReleaseUnchangedObject(lastlineobj);
                DiscardExtObject(lastlineobj);
            END;  

        END;

        INC(i);
        IF (i >= UpperYDim)  THEN
            EXIT;
        END;
    END;  
END DiscardSMatrix;




PROCEDURE LeftmostChild (   Node    : ATreeNode ) : ATreeNode;

VAR
    ChildNode           : ATreeNode;
    BestNode            : ATreeNode;
    X                   : INTEGER;
    BestX               : INTEGER;
    TaskPtr             : ATaskPtr;


BEGIN
    BestNode := Node^.Methods^.FirstChild (Node);
    IF (BestNode <> NIL) THEN
        TaskPtr := BestNode^.Methods^.LockFlexStorDataObject (BestNode);
        BestX := Xpos[TaskPtr^.XX];
        BestNode^.Methods^.UnlockUnchangedDataObject (BestNode);

        ChildNode := BestNode^.Methods^.GetNext (BestNode);

        WHILE (ChildNode <> NIL) DO
            TaskPtr := ChildNode^.Methods^.LockFlexStorDataObject (ChildNode);
            IF NOT (NetPhantomFlag IN NetFlags[TaskPtr^.XX]) THEN
                X := Xpos[TaskPtr^.XX];
                IF (X < BestX) THEN
                    BestNode := ChildNode;
                    BestX := X;
                END;
            END;
            ChildNode^.Methods^.UnlockUnchangedDataObject (ChildNode);
            ChildNode := ChildNode^.Methods^.GetNext (ChildNode);
        END;
    END;
    RETURN BestNode;
END LeftmostChild;




PROCEDURE FindMasterXpos (itask : INTEGER) : INTEGER;
VAR
    task                : ATaskPtr;
    stask               : INTEGER;
    NextNode,LastNode   : ATreeNode;
BEGIN
    NextNode := loopnode^[itask];
    LOOP
        LastNode := NextNode;
        IF NOT (LastNode^.Methods^.ChildrenVisible (LastNode)) THEN     (* 7/20/89 EGK *)
            EXIT;
        END;
        NextNode := LeftmostChild (LastNode);
        IF (NextNode = NIL) THEN
            EXIT;
        END;
    END;

    task := LastNode^.Methods^.LockFlexStorDataObject (LastNode);
    stask := task^.XX;
    LastNode^.Methods^.UnlockUnchangedDataObject (LastNode);

    RETURN(Xpos[stask]);
END FindMasterXpos;



PROCEDURE DrawVert(col1,row1,row2,char: INTEGER);
VAR
    irow            : INTEGER;
    Lower, Higher   : INTEGER;
BEGIN
    IF (col1 > SnetCols) THEN
        SnetCols := col1;
    END;
    IF (col1 < SnetColOne) THEN
        SnetColOne := col1;
    END;

    IF (row2 > row1) THEN
        Lower := row1;
        Higher := row2;
    ELSE
        Lower := row2;
        Higher := row1;
    END;

    IF (Lower < SnetRowOne) THEN
        SnetRowOne := Lower;
    END;
    IF (Higher > SnetRows) THEN
        SnetRows := Higher;
    END;

    FOR irow := Lower TO Higher DO
        IF (GetCell(irow,col1)=0) THEN
            SetCell(irow,col1,char);
        END;
    END;

END DrawVert;



PROCEDURE DrawHorz(col1,row1,col2,char: INTEGER);
VAR
    icol,tchar      : INTEGER;
    Lower, Higher   : INTEGER;
BEGIN
    IF (row1 < SnetRowOne) THEN
        SnetRowOne := row1;
    END;
    IF (row1 > SnetRows) THEN
        SnetRows := row1;
    END;

    IF (col2 > col1) THEN
        Lower := col1;
        Higher := col2;
    ELSE
        Lower := col2;
        Higher := col1;
    END;

    IF (Lower < SnetColOne) THEN
        SnetColOne := Lower;
    END;
    IF (Higher > SnetCols) THEN
        SnetCols := Higher;
    END;

    FOR icol := Lower TO Higher DO
        tchar := GetCell(row1,icol);
        IF (tchar = 0) THEN
            tchar := char;
        ELSIF (tchar = pVDash)  THEN
            IF (icol = col1) THEN
                tchar := pDLeftTee;
            ELSE
                IF (char = (pHBar-COLORBIAS)) THEN
                    tchar := pMTaskHBar - COLORBIAS;
                ELSE
                    tchar := pMTaskHBar;
                END;
            END;
        END;
        SetCell(row1,icol,tchar);
    END;
END DrawHorz;



BEGIN
    LineGroupID:=0;
END BuildMatrix.
