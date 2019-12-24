IMPLEMENTATION MODULE NetUtility;
    
    (*  MODIFICATION HISTORY
        19-Oct-88 CMH   Added DrawMasterTaskExtension procedure to extend 
          SPIKE		master task names on the network view. 
         ENHANCE
        20-Oct-88 CMH   Moved GetCell to AccessMatrix module.
          SPIKE
         ENHANCE
        21-Oct-88 CMH   (18-Jun-88) Made MasterTaskWidth and MasterTaskHeight
           TLGS         variables they can be set a different width from the 
                        task box. 
                        (04-Aug-88) Added special box width and height for 
                        TLGS.  Don't want to use full character size for 
                        frames and dividing lines as did in spike. 
 	                (14-Sep-88) Changed call to GetBoxSize to take the 
 	                layout pointer as a parameter so it can be used by 
 	                SPIKE and TLGS.
                        (22-Sep-88) Changed pipe and frame thickness from 
                        constants to variables.
        02-Nov-88 CMH   Changed DrawMasterTaskExtension and MasterTaskExpand
           SPIKE       	to draw name over any crossing dependency lines. 
          ENHANCE   
        03-Nov-88 CMH   Changed ChildrenCruncher to look past vertical 
           SPIKE	dependency lines that cross the top edge of the 
          ENHANCE	master task outline for better drawing alignment.
        22-Nov-88 LAA/CMH   In a loop, a long task name was overwriting task
                            boxes to the right of it.
        09-Feb-89 CMH   Changed units to determine box height to include both 
        		base character height and vertical gap, as input by 
        		the user on the TLGS network form. 
        15-Jun-89 KWC   Added flag for conventional/outline pert  		                    
        15-Jun-89 CMH   Changes for a critical path character
        15-Jun-89 WKH   Added support for variable screen rows
        24-Jun-89 CMH   Fixed phantom summary task frames to be drawn
                        only in network view, not tree view
        24-Jun-89 CMH   Removed InitSnetMatrix procedure
        26-Jun-89 CMH   Modified a drawing matrix character expansion,
                        removed underscores from constant name
        03-Jul-89 LAA/CMH Changed occurances of count to XX.
         5-Jul-89 KWC/CMH Added indicator of phantom task to Utility array
         18-Jul-89 CMH    Eliminated plus signs from task names of closed
                          summaries.
        24-Jul-89 EGK   Added parameters to DrawMasterTaskExtension that
                        allow it to run faster when called many times, and
                        changed MasterTaskExpand to provide values for them.
         4-Aug-89 CMH   More plus sign changes.
         5-Sep-89 CMH   Fixed a bug with master task labels leaving a blank
                        when layout is structure only.
         6-Sep-89 CMH   Moved BoxString, MasterTaskExpand, BoxExpand, 
                        GetMasterTaskLabelWidth, and DrawMasterTaskExpansion
                        from NetUtility to new module NetTaskDraw, isolating
                        report printing data and code from TLNBUILD and 
                        graphics. 
         8-Sep-89 CMH   Removed MasterTaskWidth variable;
        12-Sep-89 CMH   Added Ed's TaskInRange procedure, included it in the
                        DEF so TSEDPert can use it in graphics.
        19-Sep-89 CMH   Added error check for TLGSBox sizes, can't be less
                        than one unit by one unit.
        28-Sep-89 EGK   If HaveInfLoop is set, act as if NetworkType was
                        Conventional.
        20-Oct-89 EGK   Removed code in GetOutlineType that was needlessly
                        changing the NetworkType before and after calling
                        MasterTaskCheck.
        15-Dec-89 EGK   For mouse support, make use of new "NetXMax" and
                        "NetYMax".
        05-Feb-90 EGK   Removed unused imports from NetCharacters.
        10-Aug-90 RSC   Changed TaskFlags to TempTaskFlags.
     *)
    
FROM AccessMatrix           IMPORT
    (* PROC *)			GetCellInfo, SetCell;
    
FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree,
                                ATaskFilter, ATaskFilterSet,
                                ATempTaskFlag, ATempTaskFlagSet;
    
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

FROM Mouse                  IMPORT
    (* PROC *)                  MousePresent;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank,
                                HBar2,      VBar2, 
                                ULC2,       URC2,    
                                LLC2,       LRC2,
                                HBar1,      VBar1,
                                ULC1,       URC1,
                                LLC1,       LRC1,
                                TopTee,     BotTee,
                                LeftTee,    RightTee,
                                plus,       UpArrow,
                                DownArrow,
                                DoubleLeftTee,
                                DoubleRightTee,
                                DoubleVertPlus,
                                DoubleHorPlus,
                                PoundSign;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* PROC *)                  GetNormalNetLayout, GetBigNetLayout;

FROM NetStatic              IMPORT
    (* CONST *)                 NetworkView, TreeView, DimHeight,
    (* TYPE *)                  DiagramTask, HaveInfLoop,
    (* VAR *)                   loopnode, MatrixOverflow,maxtask,
                                SnetRowOne, SnetColOne,
                                SnetRows, SnetCols,
                                SnetHeight, SnetWidth,
                                ViewType,Xpos,Ypos,Utility,Xmaxpos,Ymaxpos;
FROM NetworkData     IMPORT
                        AnnealingChoice,NetworkType,ANetworkType;

FROM TSEDData		    IMPORT
    (* VAR *)			BaseCharacterHeight,
    				VerticalGap,	     (* 09-FEBRUAY-1989 CMH *)
    			 	BaseCharacterWidth;     (* 04-AUGUST-1988 CMH *)
 
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

                                
CONST  
    SummaryFlag  = TempTaskFlag3;

(*--------------------------------------------------------------------------*)
        (*  
            SetFilterVideoModes
            
            Sets up the normal and cursor video modes for a task.
            First, the default videomodes for normal and master 
            tasks are set.  Normal tasks use the foreground network 
            color.  Master tasks use the background network color.      
            Next, filtering, if any, is applied.  Select filtering
            has the highest priority, followed by highlight 1 
            down to highlight 5. 
         *)

  
  
PROCEDURE SetFilterVideoModes(    cell          : INTEGER; 
                              VAR NormalVidMode, 
                                  CursorVidMode : avidmode);
                                
VAR
      filter            : ATaskFilterSet;
      TaskType          : DiagramTask;
      task              : ATaskPtr; 

BEGIN
 
   IF (cell <= 0) THEN RETURN; END;

   (* determine task type, normal or master *)
      
      TaskType:= MasterTaskCheck(cell);
      IF TaskType = master THEN
         IF NOT (loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell])) THEN
            TaskType:= normal;
         END;
      END;
      IF ViewType = TreeView THEN 
         TaskType:= normal; 
      END;
      
   (* get the filter set for this task *)
   
      task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
      filter:= task^.FilterSet;
      loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);

   (* set the default videomodes *)
   
      NormalVidMode:= videonetwork;		(* 24-APR-89 CMH *)
      CursorVidMode:= cvnetwork;
   (*
    ! NormalVidMode:= videonormal;  
    ! CursorVidMode:= cvideonormal;                               (* 31-Mar-88 LAA *)
    ! IF TaskType = master THEN
    !    NormalVidMode:= videonetwork;
    !    CursorVidMode:= cvnetwork;
    ! END;
    *)
      
   (* apply the filtering *)
   
      IF Highlight1 IN filter THEN
         NormalVidMode:= videofilter1;
         CursorVidMode:= cvf1;
      ELSIF Highlight2 IN filter THEN 
         NormalVidMode:= videofilter2;
         CursorVidMode:= cvf2;
      ELSIF Highlight3 IN filter THEN 
         NormalVidMode:= videofilter3;
         CursorVidMode:= cvf3;
      ELSIF Highlight4 IN filter THEN 
         NormalVidMode:= videofilter4;
         CursorVidMode:= cvf4;
      ELSIF Highlight5 IN filter THEN 
         NormalVidMode:= videofilter5;
         CursorVidMode:= cvf5;
      END; 
      IF NOT (Selected IN filter) THEN 
         NormalVidMode:= videovanish;
         CursorVidMode:= cvvanish;
      END;

END SetFilterVideoModes;


(*--------------------------------------------------------------------------*)
        (*  
            GetBoxSize 
            
            Takes a look at the active layout and determines
            the box height and width.;
         *)


PROCEDURE GetBoxSize(layout : ANetworkLayout);	(* 14-SEPTEMBER-1988 CMH *)
  
VAR
     i,
     LeftField, 
     RightField,
     LeftMax,
     RightMax,
     MaxLineWidth,
     DivideLine    : CARDINAL;
  
  BEGIN
   
 (* initialize box size *)
    BoxWidth:=  0;
    BoxHeight:= 0;
   
 (* count rows and columns of data for box, adding vertical dividing
    lines between fields *)
    DivideLine:= 0;
    LeftMax:= 0;
    RightMax:= 0;
    MaxLineWidth:= 0;
    FOR i:= 1 TO 3 DO
        LeftField := layout^.Fields[i].ColumnWidth;
        RightField:= layout^.Fields[i+3].ColumnWidth;
        IF (LeftField > 0) AND (RightField > 0) THEN 
            IF LeftField > LeftMax THEN
               LeftMax:= LeftField;
            END; 
            IF RightField > RightMax THEN
               RightMax:= RightField;
            END; 
            DivideLine:= 1; 
        ELSE
            IF MaxLineWidth < (LeftField+RightField) THEN
               MaxLineWidth:= LeftField+RightField;
            END;
        END;
        IF (LeftField > 0) OR (RightField > 0) THEN 
            INC(BoxHeight); 
        END;
    END;
   
    BoxWidth:= LeftMax + RightMax + DivideLine;
    TLGSBoxWidth:= ((LeftMax+RightMax)*BaseCharacterWidth); 	(* 04-AUGUST-1988 CMH *)
    IF MaxLineWidth > (LeftMax + RightMax) THEN
       BoxWidth:= MaxLineWidth + DivideLine;
       TLGSBoxWidth:= (MaxLineWidth*BaseCharacterWidth); 
    END;
    TLGSBoxHeight:= ORD(BoxHeight)*(BaseCharacterHeight+VerticalGap);(* 04-AUGUST-1988 CMH *)(* 09-FEBRUARY-1989 CMH *)
    IF (TLGSBoxWidth < 1) THEN
        TLGSBoxWidth := BaseCharacterWidth;
    END;
    IF (TLGSBoxHeight < 1) THEN
        TLGSBoxHeight := BaseCharacterHeight+VerticalGap;
    END;
    
 (* add box edges if box outline is YES *)
    IF (layout^.BoxOutline) THEN
        INC(BoxWidth,2);
        INC(BoxHeight,2);
    END;
 
    IF BoxWidth > INTEGER(NetXMax+1) THEN                 (* 12/15/89 EGK *)
       BoxWidth:= INTEGER(NetXMax+1);
    END;
    IF BoxWidth <= 0THEN
       BoxWidth:= 1;
    END;
    IF BoxHeight > INTEGER(NetYMax-SeperatorLine) THEN    (* 12/15/89 EGK *)
       BoxHeight:= INTEGER(NetYMax-SeperatorLine);
    END;
    IF BoxHeight <= 0 THEN
       BoxHeight:= 1;
    END;
              
END GetBoxSize;



(*--------------------------------------------------------------------------*)
        (*  
            GetPad
            
            Used to fill in the connecting lines on the
            screen or in the print buffer. Inputing the
            character number and the connection direction,
            top, bottom, left, right, or the request for
            the actual character, the appropriate character 
            is returned.
         *)


PROCEDURE GetPad(PadSide:CHAR;PadChar:CARDINAL):CHAR;
  
VAR
     PadValue : CHAR;
 
BEGIN
     
     CASE PadSide OF
       'A' :  (*actual character itself*)
              PadValue := SnetChars[PadChar].TheChar; |  
       'T' :  (*top*)
              PadValue := SnetChars[PadChar].TopPad;  |  
       'B' :  (*bottom*)
              PadValue := SnetChars[PadChar].BotPad;  |
       'L' :  (*left*)
              PadValue := SnetChars[PadChar].LeftPad; |
       'R' :  (*right*)
              PadValue := SnetChars[PadChar].RightPad;
      END; (*case*)
     
      RETURN PadValue;
  
END GetPad;


(*--------------------------------------------------------------------------*)
        (*  
            GetOutlineType 
         *)
  
PROCEDURE GetOutlineType(cell : INTEGER) : CARDINAL;

VAR
   TaskType          : DiagramTask;
   i,
   OutlineType       : CARDINAL;
   MatchingNodeFound : BOOLEAN;

BEGIN
    
    OutlineType:= 0;
    IF (ViewType = NetworkView) THEN
        IF (NetworkType = Conventional) OR (HaveInfLoop) THEN   (* 9/28/89 EGK *)
            IF (loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell])) THEN
                TaskType:= MasterTaskCheck(cell);
                IF (TaskType = master) THEN
                    IF (Utility[cell] = -1) THEN
                        OutlineType:= ENDPHANTOM;
                    ELSE
                        OutlineType:= STARTPHANTOM
                    END;
                END;
            END;
        END;
    END;
    
    RETURN(OutlineType);
    
END GetOutlineType;


(*--------------------------------------------------------------------------*)
        (*  
            GetHorizMin
           
            Determines the minimum edge of internal 
            matrix columns that can be shown on the screen
            horizontally.  Uses global SnetColMax as "input" 
            and sets SnetColMin as "output".
         *)

PROCEDURE GetHorizMin();

VAR

        done              : BOOLEAN;
        HorizScreenPos,
        HorizScreenMin,
        HorizScreenMax    : INTEGER;

BEGIN
        done:= FALSE;
        HorizScreenMin:= ULX;
        HorizScreenMax:= NetXMax;               (* 12/15/89 EGK *)
        HorizScreenPos:= NetXMax;
        SnetColMin:= SnetColMax;
        
        REPEAT 
          HorizScreenPos:= HorizScreenPos - SnetWidth^[SnetColMin];
          IF (SnetColMin = SnetColOne) OR (HorizScreenPos = HorizScreenMin) THEN
              done:= TRUE;
              END;
          IF (HorizScreenPos > HorizScreenMin) AND (NOT done) THEN
              DEC(SnetColMin);
              END;
          IF (HorizScreenPos < HorizScreenMin) THEN
              INC(SnetColMin);
              done:= TRUE;
              END;
        UNTIL (done); 

END GetHorizMin;



(*--------------------------------------------------------------------------*)
        (*  
            GetVertMin
           
            Determines the minimum edge of internal 
            matrix rows that can be shown on the screen
            vertically.  Uses global SnetRowMax as "input" 
            and sets SnetRowMin as "output".
         *)

PROCEDURE GetVertMin();

     VAR

        done              : BOOLEAN;
        VertScreenPos,
        VertScreenMin,
        VertScreenMax    : INTEGER;
     
     BEGIN
        
        done:= FALSE;
        VertScreenMin:= 0;

        VertScreenMax:= NetYMax - ULY;          (* 12/15/89 EGK *)
        VertScreenPos:= NetYMax - ULY;
      
        SnetRowMin:= SnetRowMax;
        
        REPEAT 
          VertScreenPos:= VertScreenPos - SnetHeight^[SnetRowMin];
          IF (SnetRowMin = SnetRowOne) OR (VertScreenPos = VertScreenMin) THEN
              done:= TRUE;
              END;
          IF (VertScreenPos > VertScreenMin) AND (NOT done) THEN
              DEC(SnetRowMin);
              END;
          IF (VertScreenPos < VertScreenMin) THEN
              INC(SnetRowMin);
              done:= TRUE;
              END;
        UNTIL (done); 

END GetVertMin;




(*--------------------------------------------------------------------------*)
        (*  
            GetHorizMax
           
            Determines the maximum edge of internal 
            matrix rows that can be shown on the screen
            horizontally.  Uses global SnetColMin as 
            "input" and sets SnetColMax as "output".
         *)


PROCEDURE GetHorizMax(HorizScreenPos,HorizScreenMax : INTEGER);

     VAR

        done : BOOLEAN;
            
     BEGIN
        
        done:= FALSE;
        SnetColMax:= SnetColMin;
        
        REPEAT 
          HorizScreenPos:= HorizScreenPos + SnetWidth^[SnetColMax];
          IF (SnetColMax = SnetCols) OR (HorizScreenPos = HorizScreenMax) THEN
              done:= TRUE;
              END;
          IF (HorizScreenPos < HorizScreenMax) AND (NOT done) THEN
              INC(SnetColMax);
              END;
          IF (HorizScreenPos > HorizScreenMax) THEN
              DEC(SnetColMax);
              done:= TRUE;
              END;
        UNTIL (done); 

END GetHorizMax;


(*--------------------------------------------------------------------------*)
        (*  
            GetVertMax 
           
            Determines the maximum edge of internal 
            matrix rows that can be shown on the screen 
            vertically.  Uses global SnetRowMin as "input" 
            and sets SnetRowMax as "output".
         *)


PROCEDURE GetVertMax(VertScreenPos,VertScreenMax : INTEGER);

     VAR
        done : BOOLEAN;
             
     BEGIN

        done:= FALSE;
        SnetRowMax:= SnetRowMin;
        
        REPEAT 
          VertScreenPos:= VertScreenPos + SnetHeight^[SnetRowMax];
          IF (SnetRowMax = SnetRows) OR (VertScreenPos = VertScreenMax) THEN
              done:= TRUE;
              END;
          IF (VertScreenPos < VertScreenMax) AND (NOT done) THEN
              INC(SnetRowMax);
              END;
          IF (VertScreenPos > VertScreenMax) THEN
              DEC(SnetRowMax);
              done:= TRUE;
              END;
        UNTIL (done) 

END GetVertMax;


(*--------------------------------------------------------------------------*)
        (*  
            ISnetChars 
            
            Sets up the data needed for the GetPad procedure.
         *)



PROCEDURE ISnetChars();
   
BEGIN
   
      SnetChars[2].TheChar  := VBar1;
      SnetChars[2].TopPad   := VBar1;
      SnetChars[2].BotPad   := VBar1;
      SnetChars[2].LeftPad  := blank;
      SnetChars[2].RightPad := blank;
   
      SnetChars[3].TheChar  := HBar1;
      SnetChars[3].TopPad   := blank;
      SnetChars[3].BotPad   := blank;
      SnetChars[3].LeftPad  := HBar1;
      SnetChars[3].RightPad := HBar1;
   
      SnetChars[4].TheChar  := VBar2; (*VDash*)
      SnetChars[4].TopPad   := VBar2; (*VDash*)
      SnetChars[4].BotPad   := VBar2; (*VDash*)
      SnetChars[4].LeftPad  := blank;
      SnetChars[4].RightPad := blank;
   
      SnetChars[5].TheChar  := HBar2; (*dash*)
      SnetChars[5].TopPad   := blank;
      SnetChars[5].BotPad   := blank;
      SnetChars[5].LeftPad  := HBar2; (*dash*)
      SnetChars[5].RightPad := HBar2; (*dash*)
   
      SnetChars[6].TheChar  := RightTee;
      SnetChars[6].TopPad   := VBar1;
      SnetChars[6].BotPad   := VBar1;
      SnetChars[6].LeftPad  := HBar1;
      SnetChars[6].RightPad := blank;
   
      SnetChars[7].TheChar  := URC1;
      SnetChars[7].TopPad   := blank;
      SnetChars[7].BotPad   := DownArrow;
      SnetChars[7].LeftPad  := HBar1;
      SnetChars[7].RightPad := blank;
   
      SnetChars[8].TheChar  := LLC1;
      SnetChars[8].TopPad   := VBar1;
      SnetChars[8].BotPad   := blank;
      SnetChars[8].LeftPad  := blank;
      SnetChars[8].RightPad := HBar1;
   
      SnetChars[9].TheChar  := BotTee;
      SnetChars[9].TopPad   := VBar1;
      SnetChars[9].BotPad   := blank;
      SnetChars[9].LeftPad  := HBar1;
      SnetChars[9].RightPad := HBar1;
   
      SnetChars[10].TheChar  := TopTee;
      SnetChars[10].TopPad   := blank;
      SnetChars[10].BotPad   := DownArrow;
      SnetChars[10].LeftPad  := HBar1;
      SnetChars[10].RightPad := HBar1;
   
      SnetChars[11].TheChar  := LeftTee;
      SnetChars[11].TopPad   := VBar1;
      SnetChars[11].BotPad   := VBar1;
      SnetChars[11].LeftPad  := blank;
      SnetChars[11].RightPad := HBar1;
   
      SnetChars[12].TheChar  := plus;
      SnetChars[12].TopPad   := VBar1;
      SnetChars[12].BotPad   := VBar1;
      SnetChars[12].LeftPad  := HBar1;
      SnetChars[12].RightPad := HBar1;
   
      SnetChars[13].TheChar  := LRC1;
      SnetChars[13].TopPad   := VBar1;
      SnetChars[13].BotPad   := blank;
      SnetChars[13].LeftPad  := HBar1;
      SnetChars[13].RightPad := blank;
   
      SnetChars[14].TheChar  := ULC1;
      SnetChars[14].TopPad   := blank;
      SnetChars[14].BotPad   := UpArrow;
      SnetChars[14].LeftPad  := blank;
      SnetChars[14].RightPad := HBar1;
   
      SnetChars[15].TheChar  := ULC2;  (*asterick*)
      SnetChars[15].TopPad   := blank;
      SnetChars[15].BotPad   := VBar2; (*VDash*)
      SnetChars[15].LeftPad  := blank;
      SnetChars[15].RightPad := HBar2; (*dash*)
   
      SnetChars[16].TheChar  := URC2;  (*asterick*)
      SnetChars[16].TopPad   := blank;
      SnetChars[16].BotPad   := VBar2; (*VDash*)
      SnetChars[16].LeftPad  := HBar2; (*dash*)
      SnetChars[16].RightPad := blank;
   
      SnetChars[17].TheChar  := LLC2;  (*asterick*)
      SnetChars[17].TopPad   := VBar2; (*VDash*)
      SnetChars[17].BotPad   := blank;
      SnetChars[17].LeftPad  := blank;
      SnetChars[17].RightPad := HBar2; (*dash*)
   
      SnetChars[18].TheChar  := LRC2;  (*asterick*)
      SnetChars[18].TopPad   := VBar2; (*VDash*)
      SnetChars[18].BotPad   := blank;
      SnetChars[18].LeftPad  := HBar2; (*dash*)
      SnetChars[18].RightPad := blank;
   
      SnetChars[19].TheChar  := HBar1;
      SnetChars[19].TopPad   := VBar2; (*VDash*)
      SnetChars[19].BotPad   := VBar2; (*VDash*)
      SnetChars[19].LeftPad  := HBar1;
      SnetChars[19].RightPad := HBar1;
   
      SnetChars[20].TheChar  := VBar1;
      SnetChars[20].TopPad   := VBar1;
      SnetChars[20].BotPad   := VBar1;
      SnetChars[20].LeftPad  := HBar2; (*dash*)
      SnetChars[20].RightPad := HBar2; (*dash*)

      SnetChars[21].TheChar  := TopTee;
      SnetChars[21].TopPad   := blank;
      SnetChars[21].BotPad   := UpArrow;
      SnetChars[21].LeftPad  := HBar1;
      SnetChars[21].RightPad := HBar1;
   
      SnetChars[22].TheChar  := DoubleLeftTee;
      SnetChars[22].TopPad   := VBar2;
      SnetChars[22].BotPad   := VBar2;
      SnetChars[22].LeftPad  := blank;
      SnetChars[22].RightPad := HBar1;
   
      SnetChars[23].TheChar  := DoubleRightTee;
      SnetChars[23].TopPad   := VBar2;
      SnetChars[23].BotPad   := VBar2;
      SnetChars[23].LeftPad  := HBar1;
      SnetChars[23].RightPad := blank;
   
      SnetChars[24].TheChar  := DoubleVertPlus;
      SnetChars[24].TopPad   := VBar2;
      SnetChars[24].BotPad   := VBar2;
      SnetChars[24].LeftPad  := HBar1;
      SnetChars[24].RightPad := HBar1;
   
      SnetChars[25].TheChar  := DoubleHorPlus;
      SnetChars[25].TopPad   := VBar1;
      SnetChars[25].BotPad   := VBar1;
      SnetChars[25].LeftPad  := HBar2;
      SnetChars[25].RightPad := HBar2;
   
      SnetChars[26].TheChar  := PoundSign;    (* 15-Jun-89 CMH *)
      SnetChars[26].TopPad   := PoundSign;
      SnetChars[26].BotPad   := PoundSign;
      SnetChars[26].LeftPad  := blank;
      SnetChars[26].RightPad := blank;
      
      SnetChars[27].TheChar  := PoundSign;    (* 15-Jun-89 CMH *)
      SnetChars[27].TopPad   := blank;
      SnetChars[27].BotPad   := blank;
      SnetChars[27].LeftPad  := PoundSign;
      SnetChars[27].RightPad := PoundSign;
      
END ISnetChars;
   
   
(*--------------------------------------------------------------------------*)
        (*  
            TaskInRange 
            
            Verifies the input task is within the drawing matrix.
         *)
    
    PROCEDURE TaskInRange   (  TaskID   : INTEGER   ) : BOOLEAN;
    VAR
        OK          : BOOLEAN;
    BEGIN
        OK := (Xpos[TaskID] <= DimHeight);
        OK := OK AND (Ypos[TaskID] <= DimHeight);
        OK := OK AND (Xmaxpos[TaskID] <= DimHeight);
        OK := OK AND (Ymaxpos[TaskID] <= DimHeight);
        OK := OK AND (Utility[TaskID] <= DimHeight);
        RETURN OK;
    END TaskInRange;


(*--------------------------------------------------------------------------*)
        (*  
            InitSnetHandW 
            
            Initializes the Height and Width arrays that
            correspond to the internal matrix.  The arrays
            are used to layout the screen.
         *)
    
PROCEDURE InitSnetHandW();
     
VAR
        TaskType         : DiagramTask;
        task             : ATaskPtr;
        cell             : INTEGER;
        i, row, col      : CARDINAL;
        TaskIsOpen       : BOOLEAN;

BEGIN
        
        MasterTaskHeight := 2;	
        CharHeight := 1;

        IF (BoxWidth = 1) THEN
            CharWidth := 2;
        ELSE
            CharWidth := 1;
        END;
        
     (* preset width and height arrays to minimum *)
     
        IF (SnetRows > DimHeight) THEN          (* 9/11/89 EGK *)
            SnetRows := DimHeight;
        END;
        IF (SnetCols > DimHeight) THEN
            SnetCols := DimHeight;
        END;
     
        FOR i:= SnetRowOne TO SnetRows DO 
            SnetHeight^[i]:= CharHeight; 
        END;   
        FOR i:= SnetColOne TO SnetCols DO 
            SnetWidth^[i]:= CharWidth;
        END; 
    
        IF (ViewType = NetworkView) THEN
            FOR i:=1 TO maxtask DO
                IF (TaskInRange(i)) THEN            (* 9/11/89 EGK *)
                    IF ((Utility[i] = -1) AND ((NetworkType = Conventional) OR (HaveInfLoop))) THEN
                         SnetHeight^[Ypos[i]] := BoxHeight+1;
                         SnetWidth^[Xpos[i]] := BoxWidth;
                    END;
                    IF (Utility[i] > 0) THEN
                        IF (Utility[i] = Xmaxpos[i]) THEN (* Its a  child task *)
                           SnetHeight^[Ypos[i]] := BoxHeight+1;
                           SnetWidth^[Utility[i]] := BoxWidth;
                        ELSE  (* Master Task and Lines *)
                           SnetHeight^[Ypos[i]] := MasterTaskHeight;
                          (*
                           SnetHeight^[Ymaxpos[i]]:=MasterTaskHeight;
                           *)
                        END;
                    END;
                END;   
            END;      
        ELSE (* ViewType = TreeView *)
            FOR i:=1 TO maxtask DO
                task:=loopnode^[i]^.Methods^.LockFlexStorDataObject(loopnode^[i]);
                IF (task^.YY <= DimHeight) THEN
                    SnetHeight^[task^.YY]:=BoxHeight+1;
                END;
                IF (task^.XX <= DimHeight) THEN
                    SnetWidth^[task^.XX]:=BoxWidth;
                END;
                loopnode^[i]^.Methods^.UnlockUnchangedDataObject(loopnode^[i]);
            END;
        END;
        
     (* get the maximum expanded drawing width and height *)
        ExpandedSnetHeight:=0;
        ExpandedSnetWidth:=0;
        FOR i:= SnetRowOne TO SnetRows DO 
            ExpandedSnetHeight:=ExpandedSnetHeight+SnetHeight^[i];
        END;   
        FOR i:= SnetColOne TO SnetCols DO 
            ExpandedSnetWidth:=ExpandedSnetWidth+SnetWidth^[i];
        END; 
        
END InitSnetHandW;


(*--------------------------------------------------------------------------*)
        (*  
            GetMasterTaskLabel  
         *)

PROCEDURE GetMasterTaskLabel(VAR s : ARRAY OF CHAR; 
		             TaskTreeNode : ATreeNode;
		             layout : ANetworkLayout;
		             MaxLabelWidth : CARDINAL);
VAR
    index,
    RightField,
    LeftField     : CARDINAL;
    task   	  : ATaskPtr;
    TempReal      : REAL;
    Found         : BOOLEAN;
    PlusSign,
    TempString    : ARRAY [0..255] OF CHAR;
    
BEGIN

    SetString(PlusSign,"+");

    task:= TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);

    SetLengthOf(s,0);
    LeftField := layout^.Fields[1].ColumnWidth;
    RightField:= layout^.Fields[4].ColumnWidth;
    IF (LeftField > 0) THEN
     (* field value *)   
        Found := GetColumnString(TaskTreeNode, task,
                                 layout^.Fields[1].ColumnID,
                                 Plan,
                                 NetXMax + 1,       (* 12/15/89 EGK *)
                                 TempString);
        LJust(TempString);
        index := Search(TempString,PlusSign,0);
        IF (index = 1) THEN
            TempString[index] := blank;
        END;
        Procustes(TempString,MaxLabelWidth);
        TrimRear(TempString);
        ConcatLS(s,TempString);
    END; (* if LeftField... *)
              
    IF (RightField > 0) THEN
        IF (LeftField > 0) THEN
            ConcatS(s," ");
            ConcatS(s,VBar1);
            ConcatS(s," ");
            IF (ORD(s[0]) >= MaxLabelWidth) THEN
                MaxLabelWidth:= 0;
            ELSE
                MaxLabelWidth:= MaxLabelWidth-ORD(s[0]);
            END;
        END;
     (* field value *)   
        Found := GetColumnString(TaskTreeNode, task,
                                 layout^.Fields[4].ColumnID,
                                 Plan,
                                 NetXMax + 1,       (* 12/15/89 EGK *)
                                 TempString);
        LJust(TempString);
        index := Search(TempString,PlusSign,0);
        IF (index = 1) THEN
            TempString[index] := blank;
        END;
        Procustes(TempString,MaxLabelWidth);
        TrimRear(TempString);
        ConcatLS(s,TempString);
    END; (* if RightField... *)

    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
    
END GetMasterTaskLabel;



(*--------------------------------------------------------------------------*)
        (*  
            MasterTaskCheck
            
            Checks to see if the input task is a master/summary or 
            normal/leaf task.
         *)

  
  
PROCEDURE MasterTaskCheck(cell : INTEGER) : DiagramTask;
                  
VAR
   task     : ATaskPtr;
   TaskType : DiagramTask;
   
BEGIN                
   
   IF (cell <= 0) THEN RETURN normal; END;
   
(* use normal as a default *)
   TaskType := normal; 
   
   IF (ViewType = NetworkView) THEN
       IF (loopnode^[cell]^.Methods^.FirstChild(loopnode^[cell]) <> NIL) THEN
           TaskType:=master; 
       END;
   END;
   
   IF (ViewType = TreeView) THEN
       task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
       IF SummaryFlag IN task^.TempTaskFlags THEN 
          TaskType:=master; 
       END;
       loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
   END;
  
   RETURN (TaskType);

END MasterTaskCheck;


(*--------------------------------------------------------------------------*)

 
BEGIN                       (* NetUtility *)
   
    NetXMax := maxcol;
    NetYMax := maxrow - 1;

    IF (MousePresent()) THEN                    (* 12/15/89 EGK *)
        DEC (NetXMax);
        DEC (NetYMax);
    END;
    
END NetUtility.
