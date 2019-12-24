IMPLEMENTATION MODULE NetTaskDraw;
    
    (*  MODIFICATION HISTORY
         6-Sep-89 CMH   Moved BoxString, MasterTaskExpand, BoxExpand, 
                        GetMasterTaskLabelWidth, and DrawMasterTaskExpansion
                        from NetUtility to new module NetTaskDraw, isolating
                        report printing data and code from TLNBUILD and 
                        graphics. 
         7-Sep-89 CMH   Moved PrintBuffer, FillPrinterBuffer to NetTaskDraw.
         8-Sep-89 CMH   Removed MasterTaskWidth variable;
        28-Sep-89 EGK   If HaveInfLoop is set, act as if NetworkType was
                        Conventional.
        05-Feb-90 EGK   Removed unused imports from NetCharacters.
        20-Mar-91 TGS   Arrgh! Yet another hard-coded string removed!
     *)
    
FROM AccessMatrix           IMPORT
    (* PROC *)			GetCellInfo;
    
FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,ATaskFlagSet,
                                ATaskFilter, ATaskFilterSet;
    
FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice,
    (* PROC *)                  GetColumnInfo, GetColumnString;
    
FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, 
    (* VAR *)                   maxrow,
    (* TYPE *)                  avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatS, ConcatLS,
                                CtoS, Fill, Copy, LengthOf,
                                Insert, LJust,
                                Overlay,
                                Procustes, 
                                Search,
                                SetLengthOf,
                                SetString, 
                                SubStr,
                                TrimRear; 

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM NetCharacters          IMPORT
    (* CONST *)                 pblank,   
                                pVBar,      pHBar, 
                                pVDash,     pdash,
                                pURC,       pLLC, 
                                pplus,
                                pLRC,       pULC, 
                                pastrUR,    pastrUL,
                                pastrLL,    pastrLR,
                                pMTaskHBar, pMTaskVBar, 
                                pDPlus,     
                                blank,
                                HBar2,      VBar2, 
                                TTee2,      BTee2,
                                ULC2,       URC2,    
                                LLC2,       LRC2,
                                VBar1,
                                SmallPlus;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* PROC *)                  GetNormalNetLayout, GetBigNetLayout;

FROM NetStatic              IMPORT
    (* CONST *)                 NetworkView, TreeView,
    (* TYPE *)                  DiagramTask, HaveInfLoop,
    (* VAR *)                   loopnode, MatrixOverflow,maxtask,
                                SnetRowOne, SnetColOne,
                                SnetRows, SnetCols,
                                SnetHeight, SnetWidth,
                                ViewType,Xpos,Ypos,Utility,Xmaxpos,Ymaxpos;
                                
FROM NetUtility              IMPORT
    (* CONST *)                  STARTPHANTOM, ENDPHANTOM,
                                 ToScreen, ToPrinter,
                                 NormalLayout, EnlargedLayout,                                 
                                 BoxLayout,
    (* VAR *)                    BoxWidth, BoxHeight,
                                 MasterTaskHeight,
                                 SnetColMax,
    (* PROC *)                   MasterTaskCheck,
                                 GetMasterTaskLabel;
    
FROM NetworkData             IMPORT
                                 AnnealingChoice, NetworkType, ANetworkType;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;


CONST
    ModuleNumber = 20200; (* Same as NetDraw *)

(*--------------------------------------------------------------------------*)
        (*  
            BoxString

            Outputs a string for the box expand procedure,
            to the screen or the print buffer.
         *)

  
  
PROCEDURE BoxString(s                 : ARRAY OF CHAR;
                    X, Y, 
                    OutputDirection   : CARDINAL;
                    VidMode           : avidmode);

BEGIN

   IF OutputDirection = ToScreen THEN
      PutString(s,X,Y,VidMode); 
   ELSIF OutputDirection = ToPrinter THEN
      FillPrinterBuffer(s,X,Y); 
   END; 

END BoxString;


(*--------------------------------------------------------------------------*)
        (*  
            MasterTaskExpand 
            
            Draws the master task name on open master task outlines.
         *)

  
  
PROCEDURE MasterTaskExpand(CellTreeNode    : ATreeNode;
		           BoxX, BoxY      : CARDINAL;
                           VidMode         : avidmode;
                           OutputDirection : CARDINAL);
VAR
     layout         : ANetworkLayout;
     task           : ATaskPtr;
     i,
     Y, 
     row, col, 
     MasterCol,
     TaskLabelLength: CARDINAL;
     MaxLabelWidth  : CARDINAL;
     cell           : INTEGER;
     s,
     TaskLabel              : ARRAY [0..255] OF CHAR;

BEGIN

    task:= CellTreeNode^.Methods^.LockFlexStorDataObject(CellTreeNode);
    row:=Ypos[task^.XX];
    col:=Xpos[task^.XX];
    Y:= BoxY + ORD(SnetHeight^[row] DIV 2) - 1;  
    MaxLabelWidth := GetMasterLabelWidth(task);
    CellTreeNode^.Methods^.UnlockUnchangedDataObject(CellTreeNode);
     
 (* determine layout and get the layout pointer *)
    IF (BoxLayout=NormalLayout) THEN
        layout:=GetNormalNetLayout();
    ELSE
        layout:=GetBigNetLayout();
    END;
    
 (* draw master task label *) 
    GetMasterTaskLabel(TaskLabel,CellTreeNode,layout,MaxLabelWidth); 

    Copy (TaskLabel, s);
    TaskLabelLength:= LengthOf(s);
    IF (TaskLabelLength > ORD(BoxWidth)) THEN
        TaskLabelLength:= BoxWidth;
    END;
    SetLengthOf (s, TaskLabelLength);
    BoxString(s,BoxX,Y,OutputDirection,VidMode);
    
 (* fill in HBar2 when task name is smaller than box width *) 
    IF (TaskLabelLength < ORD(SnetWidth^[col])) THEN (* 5-Sep-89 CMH *)
        Fill(s,HBar2,(ORD(SnetWidth^[col])-TaskLabelLength));
        BoxString(s,BoxX+TaskLabelLength,Y,OutputDirection,videonetwork);
    END;
    
    MasterCol := col;
    REPEAT
      BoxX:=BoxX+ORD(SnetWidth^[col]);
      INC(col);
      IF (col <= ORD(SnetColMax)) THEN
          cell:= GetCellInfo(row,col);
          IF ((cell <> pastrUR) AND (cell < 0)) THEN              (* 02-Nov-88 CMH *) (* 22-Nov-88 LAA/CMH *)
              DrawMasterTaskExtension ( row,col,
                                        MasterCol, TaskLabel,
                                        BoxX,Y,OutputDirection,VidMode );
          END;
      END;
    UNTIL ((cell = pastrUR) OR (col >= ORD(SnetColMax)) OR (cell > 0));(*22-Nov-88 LAA/CMH *)

END MasterTaskExpand;


(*--------------------------------------------------------------------------*)
        (*  
            BoxExpand 
            
            Draws the task box, using the active layout, for 
            open or closed master and normal tasks.
         *)

  
  
PROCEDURE BoxExpand(BoxX,BoxY : CARDINAL;
                         cell : INTEGER;
                  CursorVideo : BOOLEAN;
                NormalVidMode,
                CursorVidMode : avidmode;
              OutputDirection : CARDINAL;
              OutlineType     : CARDINAL);
  
CONST
     LayoutRows = 3;
     MAXFIELDWIDTH = 80;
       
VAR
     TempReal          : REAL;
     CellTreeNode      : ATreeNode;
     TaskType          : DiagramTask;
     VidMode           : avidmode;
     task              : ATaskPtr;
     layout            : ANetworkLayout;
     BoxStringWidth,
     BoxStringHeight   : INTEGER;
     index,
     X,
     i, j, k, l, 
     TopMostRow,
     BottomMostRow,
     TopRow,
     NextRow,
     LeftField, 
     RightField,
     FieldWidth,
     FirstRow,
     BottomRow,
     RowMidMax,
     LeftMax, 
     RightMax,
     MaxWidth          : CARDINAL;
     RowMidPoint       : ARRAY[1..3] OF CARDINAL;
     Found,
     FoundField,
     OpenTask          : BOOLEAN;
     s, 
     PlusSign,
     TempString     : ARRAY[0..255] OF CHAR;
     UpLCorner,
     UpRCorner,
     LowLCorner,
     LowRCorner,
     LSide, RSide      : CHAR;
     
  BEGIN

    IF (cell <= 0) THEN RETURN; END;
    
    SetString(PlusSign,"+");

    CellTreeNode:= loopnode^[cell];
    VidMode:=NormalVidMode;
    IF CursorVideo THEN
       VidMode:=CursorVidMode;
    END;

   OpenTask:= TRUE;
   TaskType := MasterTaskCheck(cell);

    (* determine layout and get the layout pointer *)
    IF (BoxLayout=NormalLayout) THEN
        layout:=GetNormalNetLayout();
    ELSE
        layout:=GetBigNetLayout();
    END;
    
    UpLCorner := ULC2;
    UpRCorner := URC2;
    LowLCorner:= LLC2;
    LowRCorner:= LRC2;
    IF (TaskType = master) THEN 
        OpenTask:= CellTreeNode^.Methods^.ChildrenVisible(CellTreeNode);
        IF NOT OpenTask THEN
           UpLCorner := SmallPlus;
           UpRCorner := SmallPlus;
           LowLCorner:= SmallPlus;
           LowRCorner:= SmallPlus;
           TaskType:= normal;
        END;
        IF ViewType = TreeView THEN 
           IF OpenTask THEN
              SetString(s,VBar1);
              X:=ORD(BoxWidth) DIV 2;
              BoxString(s,BoxX+X,BoxY+ORD(BoxHeight),OutputDirection,videonetwork); 
           END;
           TaskType:= normal;
        END;
    END;
   
 IF ((NetworkType = Outline) AND 
       (ViewType = NetworkView) AND
       (NOT HaveInfLoop) AND                (* 9/28/89 EGK *)
       (TaskType = master)) THEN
        MasterTaskExpand(CellTreeNode,BoxX,BoxY,VidMode,OutputDirection);
 ELSE 
    IF (layout^.BoxOutline) THEN
        s[0]:=CHR(1);
        j:= 2;
        BoxStringWidth:=BoxWidth-2;
        BoxStringHeight:=BoxHeight-2;
    ELSE
        s[0]:=CHR(0);
        j:= 1;
        BoxStringWidth:=BoxWidth;
        BoxStringHeight:=BoxHeight;
    END;
    FieldWidth:= BoxStringWidth;
    RowMidPoint[1] := 0;
    RowMidPoint[2] := 0;
    RowMidPoint[3] := 0;
    TopMostRow     := 0;
    BottomMostRow  := 0;
    l              := 0;
    FirstRow := 0;
    BottomRow := 0;
    RowMidMax:= 0;
    LeftMax:= 0;
    RightMax:= 0;
    FOR i:= 1 TO LayoutRows DO
        LeftField := layout^.Fields[i].ColumnWidth;
        RightField:= layout^.Fields[i+LayoutRows].ColumnWidth;
        IF (LeftField > 0) AND (RightField > 0) THEN
            IF LeftField > LeftMax THEN
               LeftMax:= LeftField;
            END; 
            IF RightField > RightMax THEN
               RightMax:= RightField;
           END; 
        END;
    END;
    MaxWidth:= LeftMax+RightMax+1;
    IF MaxWidth > ORD(BoxStringWidth) THEN
       MaxWidth:= ORD(BoxStringWidth);
    END;
    FOR i:= 1 TO LayoutRows DO
        LeftField := layout^.Fields[i].ColumnWidth;
        RightField:= layout^.Fields[i+LayoutRows].ColumnWidth;
        IF (LeftField > 0) OR (RightField > 0) THEN
            INC(BottomRow);
            IF FirstRow = 0 THEN
               FirstRow:= i;
            END; 
        END;
        IF (LeftField > 0) AND (RightField > 0) THEN
            IF (LeftField+RightField+1) < MaxWidth THEN
                RowMidPoint[i]:= LeftMax+j+((ORD(BoxStringWidth)-MaxWidth) DIV 2);
            ELSE
                RowMidPoint[i]:= LeftMax+j;
            END;
        END;
    END;

    FOR i:= 1 TO LayoutRows DO
        (* get rows of data *)

        Fill(s,blank,BoxWidth);
  
        LeftField := layout^.Fields[i].ColumnWidth;
        RightField:= layout^.Fields[i+LayoutRows].ColumnWidth;
        
        IF (LeftField > 0) OR (RightField > 0) THEN
            IF (TopMostRow = 0) THEN TopMostRow := i; END;
            BottomMostRow := i;
            INC(l);
            IF (LeftField > 0) AND (RightField > 0) THEN
                RightField:= ORD(BoxStringWidth)-(RowMidPoint[i])+(j-1);
                LeftField := ORD(BoxStringWidth)-RightField-1;
            ELSE
                IF (LeftField <> 0)  THEN 
                    LeftField:=  ORD(BoxStringWidth);
                END;
                IF (RightField <> 0) THEN 
                    RightField:= ORD(BoxStringWidth);
                END;
            END;      
            IF (LeftField <> 0) THEN
                task := CellTreeNode^.Methods^.LockFlexStorDataObject(CellTreeNode);
                Found := GetColumnString(CellTreeNode, task,
                                         layout^.Fields[i].ColumnID,
                                         Plan,
                                         MAXFIELDWIDTH,
                                         TempString);
                CellTreeNode^.Methods^.UnlockUnchangedDataObject(CellTreeNode);
                LJust(TempString);
                index := Search(TempString,PlusSign,0);
                IF (index = 1) THEN
                    TempString[index] := blank;
                END;
                Procustes(TempString,LeftField);
                Insert(s,TempString,1);
          (*    Insert(s,TempString,j); *)
            END; (* if LeftField... *)
              
            IF (RightField <> 0) THEN
                IF (RowMidPoint[i] <> 0) THEN 
                    s[RowMidPoint[i]]:=blank; 
                    s[0]:=CHR(RowMidPoint[i]); 
                    IF layout^.BoxOutline THEN
                       k:=RowMidPoint[i];
                    ELSE
                       k:=RowMidPoint[i]+1; 
                    END;
                 (* k:=RowMidPoint[i]+1; *)
                ELSE
                    k:=1;    
                (*  k:=j;*)    
                END;
                task := CellTreeNode^.Methods^.LockFlexStorDataObject(CellTreeNode);
                Found := GetColumnString(CellTreeNode, task,
                                         layout^.Fields[i+LayoutRows].ColumnID,
                                         Plan,
                                         MAXFIELDWIDTH,
                                         TempString);
                CellTreeNode^.Methods^.UnlockUnchangedDataObject(CellTreeNode);
                LJust(TempString);
                index := Search(TempString,PlusSign,0);
                IF (index = 1) THEN
                    TempString[index] := blank;
                END;
                Procustes(TempString,RightField);
                Insert(s,TempString,k);
            END; (* if RightField... *)
            
            s[0]:=CHR(BoxWidth);
            IF l > 1 THEN 
               VidMode:= NormalVidMode;
            END;
            X:= BoxX;
            IF layout^.BoxOutline THEN
               (*LJust(s);*)
               s[0]:= CHR(ORD(BoxStringWidth));
               X:=BoxX+1;
            END;
            VidMode:=NormalVidMode;
            IF CursorVideo THEN
               VidMode:=CursorVidMode;
            END;
        
            IF ((NOT OpenTask) AND (NOT layout^.BoxOutline)) THEN
                 IF (i = FirstRow) OR (i = BottomRow) THEN
                     TempString[0]:=CHR(1);
                     TempString[1]:= SmallPlus; 
                     Insert(s,TempString,j);
                     Insert(s,TempString,BoxStringWidth);
                     s[0]:= CHR(BoxStringWidth);
                 END;
            END;
            
            BoxString(s,X,BoxY+(j-1)+(l-1),OutputDirection,VidMode);
            IF (RowMidPoint[i] <> 0) THEN
                s[0]:=CHR(1);
                s[1]:= VBar1; 
                BoxString(s,BoxX+RowMidPoint[i]-1,BoxY+(j-1)+(l-1),OutputDirection,VidMode);
            END;
       END; 
    END;(*for*)  
    
 (* check for a box outline *)
    IF (layout^.BoxOutline) THEN
       
        IF (OutlineType = STARTPHANTOM) THEN
             LSide:= VBar2;
             RSide:= blank;
        ELSIF (OutlineType = ENDPHANTOM) THEN
             LSide:= blank;
             RSide:= VBar2;
        ELSE
             LSide:= VBar2;
             RSide:= VBar2;
        END;
        
    (*  add top of box *)
        IF (OutlineType = STARTPHANTOM) THEN
            Fill(s,HBar2,BoxWidth);
            SetString(s,UpLCorner);
            GetMessage(ModuleNumber + 40, TempString); (* 20-Mar-91 TGS *)
            (*
            SetString(TempString,"START");       
            *)
            Overlay (s,TempString, 2, ORD(TempString[0]));
        ELSIF (OutlineType = ENDPHANTOM) THEN
            Fill(s,HBar2,BoxWidth);
            s[BoxWidth]:=UpRCorner;
            GetMessage(ModuleNumber + 41, TempString); (* 20-Mar-91 TGS *)
            (*
            SetString(TempString,"END");       
            *)
            IF (BoxWidth < 4) THEN
                SetLengthOf(TempString,(BoxWidth-1));
            END;
            Overlay (s,TempString, (ORD(BoxWidth)-ORD(TempString[0])), ORD(TempString[0]));
        ELSE
            Fill(s,HBar2,BoxWidth);
            s[1]:=UpLCorner;
            s[BoxWidth]:=UpRCorner;
            IF (TopMostRow > 0) THEN
                IF (RowMidPoint[TopMostRow] <> 0) THEN
                    s[RowMidPoint[TopMostRow]]:=TTee2;
                END;
            END;
        END;
        s[0]:=CHR(BoxWidth);
        BoxString(s,BoxX,BoxY,OutputDirection,VidMode); 
        
        (* and BOTTOM of BOX *)
        Fill(s,HBar2,BoxWidth);
        IF (OutlineType = STARTPHANTOM) THEN
            s[1]:=LowLCorner;
        ELSIF (OutlineType = ENDPHANTOM) THEN
            s[BoxWidth]:=LowRCorner;
        ELSE
            s[1]:=LowLCorner;
            s[BoxWidth]:=LowRCorner;
            IF (BottomMostRow > 0) THEN
                IF (RowMidPoint[BottomMostRow] <> 0) THEN
                    s[RowMidPoint[BottomMostRow]]:=BTee2;
                END;
            END;
        END;
        BoxString(s,BoxX,BoxY+ORD(BoxHeight)-1,OutputDirection,VidMode); 
        
        (* and SIDES of BOX *)
        s[0]:=CHR(1);
        FOR i:= BoxY+1 TO BoxY+ORD(BoxHeight)-2 DO
            s[1]:=LSide;
            BoxString(s,BoxX,i,OutputDirection,VidMode);
            s[1]:=RSide;
            BoxString(s,BoxX+ORD(BoxWidth)-1,i,OutputDirection,VidMode);
        END;
    END; (* if box outline... *)

 END; (* if TaskType = normal... *) 

END BoxExpand;


(*--------------------------------------------------------------------------*)
        (*  
            GetMasterLabelWidth  
         *)

PROCEDURE GetMasterLabelWidth(task : ATaskPtr):CARDINAL;

VAR
    row,
    col,
    MaxLabelWidth : CARDINAL;
    
BEGIN

 (* determine width of string for master task label *)
    row:=Ypos[task^.XX];
    col:=Xpos[task^.XX];
    MaxLabelWidth:=0;
    WHILE ((GetCellInfo(row,col) <> pastrUR) AND (col <= ORD(SnetCols))) DO
       MaxLabelWidth:= MaxLabelWidth + ORD(SnetWidth^[col]);
       INC(col);
    END;
    IF (MaxLabelWidth > 255) THEN
        MaxLabelWidth:= 255;
    END;
    
    RETURN (MaxLabelWidth);
    
END GetMasterLabelWidth;


(*--------------------------------------------------------------------------*)
        (*  
            DrawMasterTaskExtension  
         *)

PROCEDURE DrawMasterTaskExtension ( row, col        : CARDINAL;
                                    MasterCol       : CARDINAL;
                                VAR TaskLabel       : ARRAY OF CHAR;
                                    X, Y            : CARDINAL;
		                            OutputDirection : CARDINAL;
			                        VidMode 	    : avidmode  );

VAR
    i,
    OriginalColumn,
    CurrentPosition,
    TaskLabelLength : CARDINAL;
    cell 	    : INTEGER;
    s           : ARRAY [0..255] OF CHAR;
    DrawBars,
    CursorMode 	    : BOOLEAN;

BEGIN

    DrawBars := FALSE;

     (* get current character position *)    
    CurrentPosition:= 0;
    FOR i:= MasterCol TO col-1 DO
        INC(CurrentPosition, ORD(SnetWidth^[i]));
    END;
    INC(CurrentPosition);
        
     (* get task label fragment as wide as the current cell *)  
    IF (LengthOf(TaskLabel) >= CurrentPosition) THEN
        SubStr(TaskLabel, s, CurrentPosition, ORD(SnetWidth^[col]));
     (* draw name fragment *)  
        BoxString(s,X,Y,OutputDirection,VidMode);
    END;
        
END DrawMasterTaskExtension;


(*--------------------------------------------------------------------------*)

        (*  
            FillPrinterBuffer
         
            Fills the print buffer with what is the
            equivalent of what is displayed on the 
            screen and is sent to the printer.  
         *)


PROCEDURE FillPrinterBuffer(s    : ARRAY OF CHAR;
                            col,
                            row  : CARDINAL);
VAR
   i, j, width   : CARDINAL;

BEGIN
    
    width:= ORD(s[0]);
    IF (width > 0) THEN
        FOR i:= 0 TO width-1 DO
            PrintBuffer[row,col+i]:= s[i+1];  
        END;
    END;
           
END FillPrinterBuffer;


(*--------------------------------------------------------------------------*)

 
BEGIN                       (* NetTaskDraw *)
   
    
END NetTaskDraw.
 

