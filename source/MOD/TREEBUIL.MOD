IMPLEMENTATION MODULE TreeBuild;

    (*  MODIFICATION HISTORY
        11-Jul-88 LAA   Improved error checking before setting up matrix. 
                        Detected empty task tree; if so, return to Gantt. 
                        Bug #8175.
        12-Jul-88 LAA   Exit Tree View if out of matrix space.
        17-Oct-88 CMH   Added calls to SetCell and GetCellInfo, removed 
                        all direct references to SnetMatrix, for the new
                        character drawing matrix scheme.  
        18-Oct-88 CMH   Added measure routines to calc exact matrix size 
        		needed. No longer exit tree view when not enough
        		matrix space. Now show what we can.
        04-Nov-88 CMH   If number of tasks is greater than task list then
        		can't draw anything. 
        24-Jun-89 CMH   Moved initialization of SnetRowOne and SnetColOne
        07-Nov-89 EGK   At the end of TreeMain, call DiscardData to
                        invalidate the PERT's saved data.  This is because
                        we mess up the contents of the XX field, which
                        would confuse the PERT data loading/saving code.
        12-Dec-89 CMH   Made changes to building the task list so that 
                        if a schedule exceed DimHeight (800) tasks, some
                        can be closed to allow the tree to draw.
        12-Sep-90 CL    Add IMPORT ATempTaskFlag.
    *)

FROM AccessMatrix	    IMPORT
    (* CONST *)			MAXCHAR,
    (* PROC *)			GetCellInfo, SetCell;
    
FROM Allocs                 IMPORT   
    (* TYPE *)                  ATaskPtr, 
                                ATaskFlag,
                                ATempTaskFlag,
    (* VAR *)                   TaskTree;

FROM Dialog                 IMPORT
    (* PROC *)                  Burp, Error;

(*
FROM ErrorUtil              IMPORT
    (* PROC *)			PrintSCard, PrintSMsg;
*)
    
FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, CtoS, Procustes, 
                                ConcatLS, Insert, Overlay ;

FROM MsgFile                IMPORT 
    (* PROC *)                  GetMessage;

FROM NetCharacters          IMPORT 
    (* CONST *)                 pblank, pVBar, pHBar, pVDash, pdash,
                                pRightTee, pURC, pLLC, pBotTee,
                                pTopTeeDown,
                                pLeftTee, pplus, pLRC, pULC, 
                                pastrLL, pastrLR, pastrUR, pastrUL, 
                                pMTaskHBar, pMTaskVBar, 
                                pTopTeeUp;

FROM NetSave                IMPORT
    (* PROC *)                  DiscardData;

FROM NetStatic              IMPORT 
    (* CONST *)                 DimHeight, DimWidth, taskdim,
    (* TYPE *)                  DiagramTask,
    (* VAR *)                   maxtask,
                                SnetRowOne, SnetColOne,  
                                SnetRows, SnetCols,  
                                loopnode, NetworkDone,
                                Xpos, Ypos;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext; 

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR, 
    (* PROC *)                  DOSCALL;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  ValidateTree, ValidateTreeNode;

CONST
    ModuleNumber            = 20400;  (* For GetMessage *)
    SPACING = 2;
    SummaryFlag = TempTaskFlag3;
   
VAR
   OutOfMatrixSpace : BOOLEAN;


(*--------------------------------------------------------------------------*)
        (*  
            GetWBSTreeNodes
         *)

  
  
PROCEDURE GetWBSTreeNodes(VAR TaskTreeNode : ATreeNode;
                              Context      : ADDRESS);
BEGIN

 (* add task tree nodes to list of tasks *)

    IF (maxtask < DimHeight)  THEN		(* check bounds of list *)
        IF (TaskFilteredIn(TaskTreeNode)) THEN	
            INC(maxtask);
            loopnode^[maxtask]:= TaskTreeNode;
        END;
    ELSE
     (* task list full, can't hold all tasks, can't draw *)(* 04-Nov-88 CMH *) 
        NetworkDone:= TRUE;
    END; 
    
END GetWBSTreeNodes;    


(*--------------------------------------------------------------------------*)
        (*
            TaskFilteredIn

            Determine if the given task tree node is filtered
            in (showing) or not, as determined by that task's
            visibility, and the visibility of its parents.
         *)

PROCEDURE TaskFilteredIn(TaskTreeNode : ATreeNode) : BOOLEAN;

VAR
    ParentNode,
    GrandParentNode : ATreeNode;
    In              : BOOLEAN;

BEGIN                       (* TaskFilteredIn *)

       In := TRUE;
       ParentNode := TaskTreeNode^.Methods^.Parent(TaskTreeNode);
       GrandParentNode := ParentNode;
       IF GrandParentNode <> NIL THEN
          REPEAT
            In := GrandParentNode^.Methods^.ChildrenVisible(GrandParentNode);
            GrandParentNode:= GrandParentNode^.Methods^.Parent(GrandParentNode);
          UNTIL (GrandParentNode = NIL) OR (In = FALSE);
       END;

    RETURN In;

END TaskFilteredIn;


(*--------------------------------------------------------------------------*)
        (*  
            BuildTaskList
           
            Build list (loopnode) of task tree nodes, children 
            before parents.
         
         *)

PROCEDURE BuildTaskList();

VAR
    
    s                       : ARRAY [0..255] OF CHAR; 

BEGIN

    maxtask:= 0;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                    GetWBSTreeNodes, NIL);

END BuildTaskList;             


(*--------------------------------------------------------------------------*)
        (*  
            DetermineChildren
         *)

PROCEDURE DetermineChildren();

VAR
    cell             : INTEGER;
    task, ParentTask : ATaskPtr;
    ParentNode       : ATreeNode;
    
BEGIN
        
 (* clear count variables in task records *)
    FOR cell:= 1 TO maxtask DO
        task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
        task^.count:= 0;  (* number of children *)
        task^.count2:= 0; (* program counter of children as processed *)
        task^.YY:= 0;      (* Y / row     position of cell in drawing matrix *)
        task^.XX:= 0;      (* X / column position of cell in drawing matrix *)
        loopnode^[cell]^.Methods^.UnlockFlexStorDataObject(loopnode^[cell]);
        Xpos[cell]:= 0;
        Ypos[cell]:= 0;
    END;  (* for *)   
    
 (* get children count for each parent in loopnode/task list *)
    FOR cell:= 1 TO maxtask DO       
        ParentNode:= loopnode^[cell]^.Methods^.Parent(loopnode^[cell]);
        IF ParentNode <> NIL THEN 
           ParentTask:=ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
           INC(ParentTask^.count);
           ParentNode^.Methods^.UnlockFlexStorDataObject(ParentNode);
        END;
    END;
    
END DetermineChildren;             
        
        
(*--------------------------------------------------------------------------*)
        (*  
            MeasureTallTree
         *)


PROCEDURE MeasureTallTree();	(*18-Oct-88 CMH *)

VAR
    parent,
    LowestBranch     : BOOLEAN;
    row,
    MaxRow,
    indent,
    LastIndent,
    col, 
    MaxCol,
    cell,
    i,
    NumberOfChildren,
    sibling,
    NumberOfSiblings,
    FirstRow,
    FirstCol,
    LastCol,
    CurrentCol,
    ElderCol         : CARDINAL;
    task,
    GPtask           : ATaskPtr;
    ParentNode,
    GrandParentNode,
    FirstSibling,
    LastSibling,
    NextSibling,
    ElderChild,
    TaskTreeNode     : ATreeNode;

BEGIN

    col:=0;
    MaxCol:=0;
    indent:=0;
    LastIndent:=0;
    row:=0;
    MaxRow:=0;
    CurrentCol:=0;
   
    FOR cell := 1 TO maxtask DO

        TaskTreeNode:= loopnode^[cell];

     (* determine task's family *)
        task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        NumberOfChildren:= task^.count;    
        parent:=FALSE;
        IF NumberOfChildren > 0 THEN 
           parent:= TRUE;
        END;
        TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
    
     (* get task row and column *)
        col:= CurrentCol;
        col:= col + SPACING; 
        indent:= TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode);
        row:= indent * SPACING;
        IF row > MaxRow THEN 
           MaxRow:=row; 
        END;
        IF ((indent <> LastIndent) OR (indent = 0)) THEN  (*level change or at top *)
             col:= MaxCol + SPACING;
        END;
        LastIndent:= indent;
      
     (* modify parent's column to center above the children *)
        IF (parent) THEN          
            FirstSibling:=TaskTreeNode^.Methods^.FirstChild(TaskTreeNode);
            task:=FirstSibling^.Methods^.LockFlexStorDataObject(FirstSibling);
            FirstCol:=task^.XX;
            FirstRow:=task^.YY;
            FirstSibling^.Methods^.UnlockUnchangedDataObject(FirstSibling);
         
            LastSibling:=TaskTreeNode^.Methods^.LastChild(TaskTreeNode);
            task:=LastSibling^.Methods^.LockFlexStorDataObject(LastSibling);
            LastCol:= task^.XX;
            LastSibling^.Methods^.UnlockUnchangedDataObject(LastSibling);
             
            col:= ((LastCol - FirstCol) DIV 2) + FirstCol;
            IF ((col MOD 2) = 1) THEN 
                 DEC(col);
            END;
            CurrentCol:= col;           (* changed for parent placement *) 
        ELSE
            CurrentCol:= col; 	     (* no - change *)
        END;  (* if parent *)

        IF (CurrentCol > MaxCol) THEN 
            MaxCol:=CurrentCol; 
        END;
          
     (* tell child's parent that child has been processed *) 
         ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
         sibling:=0;
         NumberOfSiblings:=0;
         ElderCol:= 0;
         ElderChild:= NIL;
         IF (ParentNode <> NIL) THEN
             GPtask:=ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
             INC(GPtask^.count2);
             sibling:= GPtask^.count2;
             NumberOfSiblings:= GPtask^.count;
             ParentNode^.Methods^.UnlockFlexStorDataObject(ParentNode);

             ElderChild:=ParentNode^.Methods^.FirstChild(ParentNode);
             task:=ElderChild^.Methods^.LockFlexStorDataObject(ElderChild);
             ElderCol:=task^.XX;
             ElderChild^.Methods^.UnlockUnchangedDataObject(ElderChild);
         END;
        
         IF (ElderChild <> NIL) THEN
             NextSibling:= ElderChild;
         ELSE
             NextSibling:= TaskTreeNode;
         END;
            
      (* is this the lowest branch ? *)
              LowestBranch:= TRUE; 
              REPEAT 
                 task:=NextSibling^.Methods^.LockFlexStorDataObject(NextSibling);
                 IF task^.count > 0 THEN 
                    LowestBranch:= FALSE;
                 END;
                 NextSibling^.Methods^.UnlockUnchangedDataObject(NextSibling);
                 NextSibling:= NextSibling^.Methods^.GetNext(NextSibling);
              UNTIL NextSibling = NIL;
            
      (* if lowest level - draw vertically *)
              IF LowestBranch THEN 
                 IF sibling = 1 THEN
                    IF ((col MOD 2) = 1) THEN 
                         INC(col);
                    END;
                    INC(col); 
                    CurrentCol:= col;
                 ELSIF sibling > 1 THEN
                    col:= col - (SPACING * (sibling-1));
                    row:= row + (SPACING * (sibling-1));
                    IF row > MaxRow THEN
                       MaxRow:= row;
                    END;
                 END; 
              END;
              
              IF CurrentCol > MaxCol THEN 
                 MaxCol:=CurrentCol; 
              END;
          
    END;  (* for cell... *)             
   
 (* drawing matrix maximum row and column *)
    
    SnetRows:=MaxRow;
    SnetCols:=MaxCol;
    
 (* reset program counter of children as processed *)
    FOR cell:= 1 TO maxtask DO   
        task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
        task^.count2:= 0;
        loopnode^[cell]^.Methods^.UnlockFlexStorDataObject(loopnode^[cell]);
   END;

END MeasureTallTree;             


(*--------------------------------------------------------------------------*)
        (*  
            LayoutTallTreeMatrix
         
         *)


PROCEDURE LayoutTallTreeMatrix();

VAR
    done,
    parent,
    DrawTask,
    LowestBranch     : BOOLEAN;
    row,
    MaxRow,
    indent,
    LastIndent,
    col, 
    MaxCol,
    cell,
    i,
    NumberOfChildren,
    sibling,
    NumberOfSiblings,
    FirstRow,
    FirstCol,
    LastCol,
    CurrentCol,
    ElderCol,
    middle           : CARDINAL;
    task,
    GPtask           : ATaskPtr;
    StartChar, 
    EndChar          : INTEGER;    
    ParentNode,
    GrandParentNode,
    FirstSibling,
    LastSibling,
    NextSibling,
    ElderChild,
    TaskTreeNode     : ATreeNode;

BEGIN

    col:=0;
    MaxCol:=0;
    indent:=0;
    LastIndent:=0;
    row:=0;
    MaxRow:=0;
    CurrentCol:=0;
   
    FOR cell := 1 TO maxtask DO

        TaskTreeNode:= loopnode^[cell];
          
     (* determine task's family *)

        task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        
        NumberOfChildren:= task^.count;    
        parent:=FALSE;
        IF (TaskTreeNode^.Methods^.FirstChild(TaskTreeNode) <> NIL) THEN 
            parent:= TRUE;
            INCL(task^.TempTaskFlags,SummaryFlag); 
        ELSE
            EXCL(task^.TempTaskFlags,SummaryFlag);   
        END;
        TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
    
     (* get task row and column, put task into drawing matrix *)

        col:= CurrentCol;
        col:= col + SPACING; 
        indent:= TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode);
        row:= indent * SPACING;
        IF row > MaxRow THEN 
           MaxRow:=row; 
        END;
        IF ((indent <> LastIndent) OR (indent = 0)) THEN  (*level change or at top *)
             col:= MaxCol + SPACING;
        END;
        LastIndent:= indent;
      
        IF (parent) THEN 
             
              (* modify parent's column to center above the children *)
             
                 FirstSibling:=TaskTreeNode^.Methods^.FirstChild(TaskTreeNode);
                 task:=FirstSibling^.Methods^.LockFlexStorDataObject(FirstSibling);
                 FirstCol:=task^.XX;
                 FirstRow:=task^.YY;
                 FirstSibling^.Methods^.UnlockUnchangedDataObject(FirstSibling);
                 
                 LastSibling:=TaskTreeNode^.Methods^.LastChild(TaskTreeNode);
                 task:=LastSibling^.Methods^.LockFlexStorDataObject(LastSibling);
                 LastCol:= task^.XX;
                 LastSibling^.Methods^.UnlockUnchangedDataObject(LastSibling);
             
                 col:= ((LastCol - FirstCol) DIV 2) + FirstCol;
                 IF ((col MOD 2) = 1) THEN 
                      DEC(col);
                 END;
                 IF FirstCol = col THEN (* parent directly above child *)
                    IF NumberOfChildren > 1 THEN 
                       IF TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode) THEN
                          SetCell(FirstRow-1,col,pLeftTee);  (* change char if child below *)                  
                       END;
                    END;
                 END;
                 CurrentCol:= col;           (* changed for parent placement *) 
              ELSE
                 CurrentCol:= col; 	     (* no - change *)
        END;  (* if parent *)

        IF CurrentCol > MaxCol THEN 
                 MaxCol:=CurrentCol; 
        END;
          
    (* tell child's parent that child has been processed *) 

        ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
        sibling:=0;
        NumberOfSiblings:=0;
        ElderCol:= 0;
        ElderChild:= NIL;
        IF ParentNode <> NIL THEN
                 GPtask:=ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
                 INC(GPtask^.count2);
                 sibling:= GPtask^.count2;
                 NumberOfSiblings:= GPtask^.count;
                 ParentNode^.Methods^.UnlockFlexStorDataObject(ParentNode);
                 ElderChild:=ParentNode^.Methods^.FirstChild(ParentNode);
                 task:=ElderChild^.Methods^.LockFlexStorDataObject(ElderChild);
                 ElderCol:=task^.XX;
                 ElderChild^.Methods^.UnlockUnchangedDataObject(ElderChild);
       END;
        
       IF ElderChild <> NIL THEN
                NextSibling:= ElderChild;
       ELSE
                NextSibling:= TaskTreeNode;
       END;
            
    (* is this the lowest branch ? *)
            
       LowestBranch:= TRUE; 
       REPEAT 
                 task:=NextSibling^.Methods^.LockFlexStorDataObject(NextSibling);
                 IF task^.count > 0 THEN 
                    LowestBranch:= FALSE;
                 END;
                 NextSibling^.Methods^.UnlockUnchangedDataObject(NextSibling);
                 NextSibling:= NextSibling^.Methods^.GetNext(NextSibling);
       UNTIL NextSibling = NIL;
            
    (* if lowest level - draw vertically *)
           
       IF LowestBranch THEN 
                 IF sibling = 1 THEN
                    IF ((col MOD 2) = 1) THEN 
                         INC(col);
                    END;
                    INC(col); 
                    CurrentCol:= col;
                 ELSIF sibling > 1 THEN
                    col:= col - (SPACING * (sibling-1));
                    row:= row + (SPACING * (sibling-1));
                    IF row > MaxRow THEN
                       MaxRow:= row;
                    END;
                 END; 
       END;
              
       IF CurrentCol > MaxCol THEN 
                 MaxCol:=CurrentCol; 
       END;
          
    (* update task record with the matrix location *)
              
       task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
       task^.XX:= col;
       task^.YY:= row;
       TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
       Xpos[cell]:= col;
       Ypos[cell]:= row;
          
    (* is this task visible ? *)
             
       DrawTask:= TRUE;
       ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
       GrandParentNode:= ParentNode;
       IF GrandParentNode <> NIL THEN
                 REPEAT
                    DrawTask:= GrandParentNode^.Methods^.ChildrenVisible(GrandParentNode);
                    GrandParentNode:= GrandParentNode^.Methods^.Parent(GrandParentNode);
                 UNTIL (GrandParentNode = NIL) OR (DrawTask = FALSE);
       END;
        
           (* if so, then draw it *)

       IF DrawTask THEN

                 SetCell(row,col,cell);
                 Xpos[cell]:= col;
                 Ypos[cell]:= row;
            
              (* set up start and end characters based on number of children *)   
    
                 StartChar:=pblank;
                 EndChar:=  pblank;
                 IF NumberOfSiblings = 1 THEN 
                    StartChar:= pVBar; 
                    EndChar:=   pblank;     
                 ELSE
                    StartChar:= pULC; 
                    EndChar:=   pURC; 
                 END;
    
              (* place character in drawing matrix *) 
           
                 IF NOT LowestBranch THEN
                 
                    IF sibling = 1 THEN 
                       SetCell(row-1,col,StartChar);
                    ELSIF ((sibling = NumberOfSiblings) AND (sibling > 0)) THEN
                       SetCell(row-1,col-1,pHBar); 
                       SetCell(row-1,col,EndChar); 
                       IF indent > 0 THEN
                          done:= FALSE;
                          i:=0;
                          middle:= ((col- ElderCol) DIV 2) + ElderCol;   
                          IF ((middle MOD 2) = 1) THEN 
                               DEC(middle);
                          END;
                          IF ElderCol <> 0 THEN
                             StartChar:= GetCellInfo(row-1,ElderCol);
                          END;
                          REPEAT
                             INC(i);
                             IF GetCellInfo(row-1,col-i) = StartChar THEN
                                done:= TRUE;
                             ELSIF (col - i) = middle THEN
                                SetCell(row-1,col-i,pBotTee);
                                IF GetCellInfo(row,col-i) > 0 THEN
                                   SetCell(row-1,col-i,pplus);
                                END;
                             ELSE
                                SetCell(row-1,col-i,pHBar);
                                IF GetCellInfo(row,col-i) > 0 THEN
                                   SetCell(row-1,col-i,pTopTeeUp);
                                END;
                             END;
                          UNTIL done;
                       END; (* if indent... *)
                    END;  (* if sibling = 1... *)
                 
                 ELSE  (* lowest branch *)
                 
                    IF (NOT parent) AND ((sibling = NumberOfSiblings) AND (sibling > 0)) THEN
                        SetCell(row,col-1,pLLC); 
                        SetCell(row-1,col-1,pVBar); 
                    ELSIF (sibling < NumberOfSiblings) THEN
                        SetCell(row,col-1,pLeftTee); 
                        SetCell(row-1,col-1,pVBar); 
                    END; 
                
                 END; (* if not lowestbranch... *)
              
       END; (* if DrawTask... *) 

    END;  (* for cell... *)             
   
 (* drawing matrix maximum row and column *)
    
    SnetRows:=MaxRow;
    SnetCols:=MaxCol;
    IF SnetRows > DimHeight THEN
       SnetRows:= DimHeight;
    END; 
    IF SnetCols > DimWidth THEN
       SnetCols:= DimWidth;
    END; 
       
END LayoutTallTreeMatrix;             


(*--------------------------------------------------------------------------*)
        (*  
            MeasureWideTree
         *)

PROCEDURE MeasureWideTree();

VAR
    parent           : BOOLEAN;
    row,
    MaxRow,
    indent,
    LastIndent,
    col, 
    MaxCol,
    cell,
    i,
    NumberOfChildren,
    sibling,
    NumberOfSiblings,
    FirstRow,
    FirstCol,
    LastCol,
    CurrentCol,
    ElderCol         : CARDINAL;
    task,
    GPtask           : ATaskPtr;
    ParentNode,
    GrandParentNode,
    FirstSibling,
    LastSibling,
    ElderChild,
    TaskTreeNode     : ATreeNode;

BEGIN

    col:=0;
    MaxCol:=0;
    indent:=0;
    LastIndent:=0;
    row:=0;
    MaxRow:=0;
    CurrentCol:=0;
   
    FOR cell := 1 TO maxtask DO
       
        TaskTreeNode:= loopnode^[cell];

     (* determine task's family *)
        task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        NumberOfChildren:= task^.count;    
        parent:=FALSE;
        IF NumberOfChildren > 0 THEN 
           parent:= TRUE;
        END;
        TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
    
     (* get task row and column *)
        col:=CurrentCol;
        col:= col + SPACING; 
        indent:=TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode);
        row:= indent * SPACING;
        IF row > MaxRow THEN 
           MaxRow:=row; 
        END;
        IF ((indent <> LastIndent) OR (indent = 0)) THEN  (*level change or at top *)
             col:= MaxCol + SPACING;
        END;
        LastIndent:= indent;

     (* modify parent's column to center above the children *)
        IF (parent) THEN 
            FirstSibling:=TaskTreeNode^.Methods^.FirstChild(TaskTreeNode);
            task:=FirstSibling^.Methods^.LockFlexStorDataObject(FirstSibling);
            FirstCol:=task^.XX;
            FirstRow:=task^.YY;
            FirstSibling^.Methods^.UnlockUnchangedDataObject(FirstSibling);
         
            LastSibling:=TaskTreeNode^.Methods^.LastChild(TaskTreeNode);
            task:=LastSibling^.Methods^.LockFlexStorDataObject(LastSibling);
            LastCol:= task^.XX;
            LastSibling^.Methods^.UnlockUnchangedDataObject(LastSibling);
             
            col:= ((LastCol - FirstCol) DIV 2) + FirstCol;
            IF ((col MOD 2) = 1) THEN 
                 DEC(col);
            END;
            CurrentCol:= col;           (* changed for parent placement *) 
        ELSE
            CurrentCol:=col; (* no - change *)
        END;  (* if parent *)

        IF (CurrentCol > MaxCol) THEN 
            MaxCol:=CurrentCol; 
        END;
        
     (* tell child's parent that child has been processed *) 
        ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
        sibling:=0;
        NumberOfSiblings:=0;
        ElderCol:= 0;
        IF (ParentNode <> NIL) THEN
            GPtask:=ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
            INC(GPtask^.count2);
            sibling:= GPtask^.count2;
            NumberOfSiblings:= GPtask^.count;
            ParentNode^.Methods^.UnlockFlexStorDataObject(ParentNode);
            ElderChild:=ParentNode^.Methods^.FirstChild(ParentNode);
            task:=ElderChild^.Methods^.LockFlexStorDataObject(ElderChild);
            ElderCol:=task^.XX;
            ElderChild^.Methods^.UnlockUnchangedDataObject(ElderChild);
        END;
          
    END;  (* for cell... *)             
   
 (* drawing matrix maximum row and column *)
    SnetRows:=MaxRow;
    SnetCols:=MaxCol;
   
 (* reset program counter of children as processed *)
    FOR cell:= 1 TO maxtask DO   
        task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
        task^.count2:= 0;
        loopnode^[cell]^.Methods^.UnlockFlexStorDataObject(loopnode^[cell]);
   END;
       
END MeasureWideTree;       

      
(*--------------------------------------------------------------------------*)
        (*  
            LayoutWideTreeMatrix
         
         *)


PROCEDURE LayoutWideTreeMatrix();

VAR
    done,
    parent,
    DrawTask         : BOOLEAN;
    row,
    MaxRow,
    indent,
    LastIndent,
    col, 
    MaxCol,
    cell,
    i,
    NumberOfChildren,
    sibling,
    NumberOfSiblings,
    FirstRow,
    FirstCol,
    LastCol,
    CurrentCol,
    ElderCol,
    middle           : CARDINAL;
    task,
    GPtask           : ATaskPtr;
    StartChar, 
    EndChar          : INTEGER;    
    ParentNode,
    GrandParentNode,
    FirstSibling,
    LastSibling,
    ElderChild,
    TaskTreeNode     : ATreeNode;

BEGIN

    col:=0;
    MaxCol:=0;
    indent:=0;
    LastIndent:=0;
    row:=0;
    MaxRow:=0;
    CurrentCol:=0;
   
    FOR cell := 1 TO maxtask DO
       
        TaskTreeNode:= loopnode^[cell];

     (* determine task's family *)
   
        task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        NumberOfChildren:= task^.count;    
        parent:=FALSE;
        IF (TaskTreeNode^.Methods^.FirstChild(TaskTreeNode) <> NIL) THEN 
            parent:= TRUE;
            INCL(task^.TempTaskFlags,SummaryFlag); 
        ELSE
            EXCL(task^.TempTaskFlags,SummaryFlag);   
        END;
        TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
            
    
     (* get task row and column, put task into drawing matrix *)
   
        col:= CurrentCol + SPACING; 
        indent:=TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode);
        row:= indent * SPACING;
        IF row > MaxRow THEN 
           MaxRow:=row; 
        END;
        IF ((indent <> LastIndent) OR (indent = 0)) THEN  (*level change or at top *)
             col:= MaxCol + SPACING;
        END;
        LastIndent:= indent;

        IF ((parent) AND 
            (TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode))) THEN 

             (* modify parent's column to center above the children *)
             
                FirstSibling:=TaskTreeNode^.Methods^.FirstChild(TaskTreeNode);
                task:=FirstSibling^.Methods^.LockFlexStorDataObject(FirstSibling);
                FirstCol:=task^.XX;
                FirstRow:=task^.YY;
                FirstSibling^.Methods^.UnlockUnchangedDataObject(FirstSibling);
         
                LastSibling:=TaskTreeNode^.Methods^.LastChild(TaskTreeNode);
                task:=LastSibling^.Methods^.LockFlexStorDataObject(LastSibling);
                LastCol:= task^.XX;
                LastSibling^.Methods^.UnlockUnchangedDataObject(LastSibling);
             
                col:= ((LastCol - FirstCol) DIV 2) + FirstCol;
                IF ((col MOD 2) = 1) THEN 
                     DEC(col);
                END;
                IF FirstCol = col THEN (* parent directly above child *)
                   IF NumberOfChildren > 1 THEN 
                      IF TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode) THEN
                         SetCell(FirstRow-1,col,pLeftTee);  (* change char if child below *)                  
                      END;
                   END;
                END;
                CurrentCol:= col;           (* changed for parent placement *) 
        ELSE
                CurrentCol:=col; (* no - change *)
        END;  (* if parent *)

        IF CurrentCol > MaxCol THEN 
                MaxCol:=CurrentCol; 
        END;
        
     (* tell child's parent that child has been processed *) 

        ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
        sibling:=0;
        NumberOfSiblings:=0;
        ElderCol:= 0;
        IF ParentNode <> NIL THEN
                GPtask:=ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
                INC(GPtask^.count2);
                sibling:= GPtask^.count2;
                NumberOfSiblings:= GPtask^.count;
                ParentNode^.Methods^.UnlockFlexStorDataObject(ParentNode);
                ElderChild:=ParentNode^.Methods^.FirstChild(ParentNode);
                task:=ElderChild^.Methods^.LockFlexStorDataObject(ElderChild);
                ElderCol:=task^.XX;
                ElderChild^.Methods^.UnlockUnchangedDataObject(ElderChild);
        END;
          
     (* update task record with the matrix location *)
        
        task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        task^.XX:= col;
        task^.YY:= row;
        TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
        Xpos[cell]:= col;
        Ypos[cell]:= row;
       
     (* is this task visible ? *)
             
        DrawTask:= TRUE;
        ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
        GrandParentNode:= ParentNode;
        IF GrandParentNode <> NIL THEN
                REPEAT
                   DrawTask:= GrandParentNode^.Methods^.ChildrenVisible(GrandParentNode);
                   GrandParentNode:= GrandParentNode^.Methods^.Parent(GrandParentNode);
                UNTIL (GrandParentNode = NIL) OR (DrawTask = FALSE);
        END;
             
     (* if so, then draw it *)
         
        IF DrawTask THEN
             
                SetCell(row,col,cell);
                Xpos[cell]:= col;
                Ypos[cell]:= row;

             (* set up start and end characters based on number of children *)   
        
                StartChar:=pblank;
                EndChar:=  pblank;
                IF NumberOfSiblings = 1 THEN 
                   StartChar:= pVBar; 
                   EndChar:=   pblank;     
                ELSE
                   StartChar:= pULC; 
                   EndChar:=   pURC; 
                END;
      
             (* place character in drawing matrix *) 
       
                IF sibling = 1 THEN 
                   SetCell(row-1,col,StartChar);
                ELSIF ((sibling = NumberOfSiblings) AND (sibling > 0)) THEN
                   SetCell(row-1,col-1,pHBar); 
                   SetCell(row-1,col,EndChar); 
                   IF indent > 0 THEN
                      done:= FALSE;
                      i:=0;
                      middle:= ((col- ElderCol) DIV 2) + ElderCol;   
                      IF ((middle MOD 2) = 1) THEN 
                           DEC(middle); 
                      END;
                      IF ElderCol <> 0 THEN
                         StartChar:= GetCellInfo(row-1,ElderCol);
                      END;
                      REPEAT
                         INC(i);
                         IF GetCellInfo(row-1,col-i) = StartChar THEN
                            done:= TRUE;
                         ELSIF (col - i) = middle THEN
                            SetCell(row-1,col-i,pBotTee);
                            IF GetCellInfo(row,col-i) > 0 THEN
                               SetCell(row-1,col-i,pplus);
                            END;
                         ELSE
                            SetCell(row-1,col-i,pHBar);
                            IF GetCellInfo(row,col-i) > 0 THEN
                               SetCell(row-1,col-i,pTopTeeUp);
                            END;
                         END;
                      UNTIL done;
                   END; (* if indent... *)
                   
                END;  (* if sibling = 1... *)
             
        END; (* if DrawTask... *) 
      
    END;  (* for cell... *)             
   
 (* drawing matrix maximum row and column *)
    SnetRows:=MaxRow;
    SnetCols:=MaxCol;
   
    IF SnetRows > DimHeight THEN
       SnetRows:= DimHeight;
    END; 
    IF SnetCols > DimWidth THEN
       SnetCols:= DimWidth;
    END; 
       
END LayoutWideTreeMatrix;       


(*--------------------------------------------------------------------------*)
        (*  
            TasksNotVisible - closed tasks
         *)

PROCEDURE TasksNotVisible();

VAR
    DrawTask                : BOOLEAN;
    row, col,
    cell                    : INTEGER;
    task                    : ATaskPtr; 
    GrandParentNode, 
    ParentNode              : ATreeNode;

BEGIN
    FOR cell := 1 TO maxtask DO 
     
     (* check if out of bounds *)
     
        task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
        row:= task^.YY;
        col:= task^.XX;
        IF ((col >= DimWidth) OR (row >= DimHeight)) THEN 
           (* say these are out of range for later "goto" type keys *)
              OutOfMatrixSpace:= TRUE;
              task^.XX:= 9999;
              task^.YY:= 9999;
        END;
        loopnode^[cell]^.Methods^.UnlockFlexStorDataObject(loopnode^[cell]);
     
     (* check for closed children *)
     
        DrawTask := TRUE; 
        ParentNode := loopnode^[cell]^.Methods^.Parent(loopnode^[cell]);
        GrandParentNode := ParentNode;
        IF GrandParentNode <> NIL THEN
          REPEAT
             DrawTask:= GrandParentNode^.Methods^.ChildrenVisible(GrandParentNode); 
             GrandParentNode:= GrandParentNode^.Methods^.Parent(GrandParentNode); 
          UNTIL (GrandParentNode = NIL) OR (DrawTask = FALSE);
        END; 
        IF (NOT DrawTask) THEN 
            task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]); 
         (* say these are out of range for later "goto" type keys *) 
            task^.XX:= 9999;
            task^.YY:= 9999;
            loopnode^[cell]^.Methods^.UnlockFlexStorDataObject(loopnode^[cell]); 
        END; 

    END; (*for*) 

END TasksNotVisible;


(*--------------------------------------------------------------------------*)
        (*  
            TreeMain
         *)

  
PROCEDURE TreeMain(    TreeType             : CARDINAL);

VAR 
    s                       : ARRAY [0..255] OF CHAR; 

BEGIN 

    OutOfMatrixSpace := FALSE;
    
 (* build list of tasks, loopnode, in "ChildBeforeParent" form *) 
    BuildTaskList();        
    
 (* be sure task list could hold all tasks, max DimHeight *)(* 04-Nov-88 CMH *) 
    IF (NOT NetworkDone) THEN      
  
 (* be sure there are some tasks to draw *) 		(* 11-Jul-88 LAA *) 
    IF (maxtask > 0) THEN      
        
     (* set subtask count for each task in each task record *) 
        DetermineChildren();                               

     (* mesure then layout the tree diagram *)
        IF (TreeType = 1) THEN  
            MeasureTallTree(); 		  		(* 18-Oct-88 CMH *)
            LayoutTallTreeMatrix();
        ELSE
            MeasureWideTree(); 		  		(* 18-Oct-88 CMH *)
            LayoutWideTreeMatrix(); 
        END;
 
     (* de-activate those tasks that are not visible - closed tasks *) 
        TasksNotVisible();
        
    ELSE                                        	(* 11-Jul-88 LAA *) 
       
     (* no tasks to draw, can't display tree view*)
        GetMessage(ModuleNumber + 1, s);		
        Error(s); 
        NetworkDone := TRUE;

    END; (* if maxtask... *)

    IF OutOfMatrixSpace THEN
     (* drawing area space exceeded,  message show what can *)
        GetMessage(ModuleNumber,s);        
        Error(s); 
    END;
    
    ELSE      
     (* Loopnode full, not enough memory to draw tree *)
        GetMessage(ModuleNumber+2,s);      (* 04-Nov-88 CMH *)
        Error(s); 
    END;
                               
    DiscardData();              (* 11/7/89 EGK *)

END TreeMain;    


(*--------------------------------------------------------------------------*)

BEGIN                           (* TreeBuild *)

    SnetRowOne:= 0; (* 24-Jun-89 CMH *)
    SnetColOne:= 0;
    
END TreeBuild.
