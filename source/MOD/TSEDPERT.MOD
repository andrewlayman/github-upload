IMPLEMENTATION MODULE TSEDPert;

   (*
    Modification History:
        22-Jun-89 CMH   Removed legend "symbols" title
        24-Jun-89 CMH   Added critical path dependency line color
        27-Jun-89 CMH   Removed space allocation for vertical dividing
                        lines (caused unequal horizontal boxes),
                        fixed legend crate frame for conventional pert
        28-Jun-89 CMH   Modified axis width calculation for network diagrams
         3-Jul-89 CMH   Removed obsolete GetConnector procedure
         5-Jul-89 CMH   Changed task^.count to task^.XX
         6-Jul-89 CMH   Modified line spacing
         9-Jul-89 CMH   Improved vertical master task outline spacing
        17-Jul-89 CMH   Removed plus corners for closed tasks in graphics.
        18-Jul-89 CMH   Eliminated plus signs from task names of closed
                        summaries.
        24-Jul-89 CMH   Fixed bug for conventional pert charts.
         4-Aug-89 CMH   More plus sign changes.
         9-Aug-89 CMH   More value formatting changed.
        18-Aug-89 CMH   Removed radius from the intersection of dependency
                        lines to task boxes.
        22-Aug-89 CMH   Fixed page size calculation problem with timescaling.
        23-Aug-89 CMH   Fixed more page size calculation problem with timescaling.
        24-Aug-89 LAA   Fixed calculations which were doing cardinal
                        multiplies before floating rather than after.  This
                        produces a CARDINAL OVERFLOW under some circumstances.
        25-Aug-89 CMH   Fixed WriteHorizPipes to take into account color bias
                        when looking at previous and next characters, adjusted
                        the pipe gap, renamed APageDescription variable to
                        PageDescription.
        28-Aug-89 CMH   Removed symbol name blanks.
         5-Sep-89 CMH   Removed unused import of UnitsForScaling from
                        TSEDTimescale.DEF.
         6-Sep-89 CMH   Moved AddTimescaling and AddTimeScalingVert from
                        TSEDTimescale to PertTimescale.
         7-Sep-89 CMH   Removed obsolete procedures to open, write and
                        close the matrix size file.
         8-Sep-89 CMH   Using new WriteBoolean, WriteCardinal, WriteReal
                        procedures.
        12-Sep-89 CMH   Added range checking for clipped master task outlines
                        in case of matrix overflow.
        19-Sep-89 CMH   Added summary color to traditional start and end
                        crates.
        22-Sep-89 CMH   Fixed uninitialized variable in InitCrateArrangement.
                        Added new variable for independant font height.
        28-Sep-89 EGK   If HaveInfLoop is set, act as if NetworkType was
                        Conventional.
         3-Oct-89 CMH   Fixed alignment of axis and margins in
                        timescaled network diagrams.
         1-Nov-89 CMH   Corrected page margin so all are equal. 
         5-Nov-89 CMH   Fixed WriteHorizPipes for bug when changing color
                        in timescaled pert. 
         9-Nov-89 CMH   Added a legend crate arrangement.
        14-Nov-89 CMH   Added code to bail out of TimeScaling when the
                        chart gets too wide for the SnetWidth spacing
                        array that is integer. Also bail out of calc
                        horizontal spacing if not-timescaled pert is 
                        too wide.
        15-Nov-89 EGK   For the previous fix, added code to get an
                        appropriate error message and display it if the
                        chart is too wide.
        16-Nov-89 CMH   Needed to allow a small margin at the bottom and
                        side of the chart.  Added a one character pad to 
                        the crate boxes.
        29-Nov-89 CMH   Adjusted vertical crate pipe lines. 
         7-Dec-89 CMH   Moved writing the compressed flag from PertTime.
        12-Dec-89 CMH   Added more space for master task outline names.
        21-Dec-89 CMH   Added another character to master task outline name
                        since box text now uses a full character each side.
         8-Jan-90 CMH   Changed WriteCrate to check the filters to determine
                        the task data color.
        10-Jan-90 CMH   Further to previous change, fixed the legend box text
                        to use the default text color instead of filter 
                        colors.                         
        11-Jan-90 CMH   Fixed bug where critical path line was drawing
                        through a task box.
        21-Mar-90 CMH   Fixed bug where legend task box was using filter
                        color for task data.
        28-Mar-90 KKC   Remove all unreferenced id from Timeu.
        23-Sep-90 PHR   Write DrawingScale as a real.
        12-Nov-90 TGS   Merge changes made to 4.03.
    *)

FROM AccessMatrix           IMPORT
    (* CONST *)                 COLORBIAS,
    (* PROC *)                  GetCellInfo;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  GetColumnInfo, GetColumnString;

FROM ColorTLGS              IMPORT
    (* VAR *)                   OpenSummaryDataColor,
                                AllOtherDataColor,
                                DepLineColor,
                                CritDepLineColor,
                                MilestoneCrateFrameColor,
                                NormalCrateFrameColor,
                                NormalCrateBGColor,
                                MTOpenLineColor,
(* for duration bar networks - not avaliable in TL version 4.0
 |                              AchievementBarColor,
 |                              OpenSummaryBarColor,
 |                              AllOtherBarColor,
 *)
    (* PROC *)                  GetFGColor,
                                InitNodeChartColors,
                                WriteColorSelections,
                                WriteFilterSelections;

FROM DataNetwork            IMPORT
    (* CONST *)                 TASKVALUE,    LEGEND,
    (* VAR *)                   ShowDependencyLines,
                                CompressAxis,
                                TimeScaleNetwork,
                                NetworkDiagramLayout,

                                NormalPipeWidth,
                                NormalPipeStyle,
                                NormalPipeHighlight,
                                NormalPipeRadius,

                                CrateFramePipeWidth,
                                CrateFramePipeStyle,
                                CrateFramePipeHighlight,
                                CrateFramePipeRadius,

                                CrateInteriorPipeWidth,
                                CrateInteriorPipeStyle,
                                CrateInteriorPipeHighlight,
                                CrateInteriorPipeRadius,

                                MasterPipeWidth,
                                MasterPipeStyle,
                                MasterPipeHighlight,
                                MasterPipeRadius,

                                HorizOffset,
                                LastRowPosition,
                                LastColPosition,
    (* PROC *)                  WriteNodeChartData;

FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM FontTLGS            IMPORT
    (* VAR *)                   FontHeight;

FROM FilterRc            IMPORT
    (* VAR *)                   HighlightFilter;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;


(* for duration bar networks - not avaliable in TL version 4.0
 | FROM GanttTimescale         IMPORT
 |                              GetDurationBarDates;
*)

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSPageRecord,
                                ATLGSPageRecordPtr,
                                AGraphStyle,
    (* PROC *)                  TLGSPageRecord;

FROM LStrings               IMPORT
    (* PROC *)                  Compare, ConcatLS, Copy, Fill, LengthOf,
                                LJust, Procustes, Search, SetLengthOf,
                                SetString, TrimFront, TrimRear;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank,
                                pastrUR,    pastrUL,
                                pastrLL,    pastrLR,
                                pVBar,      pHBar,
                                pRightTee,  pVDash,
                                pURC,       pLLC,
                                pBotTee,    pTopTeeDown,
                                pLeftTee,   pplus,
                                pLRC,       pULC,
                                pMTaskHBar, pMTaskVBar,
                                pDLeftTee,  pDRightTee,
                                pDPlus,     pDHPlus,
                                pTopTeeUp;

FROM NetStatic              IMPORT
    (* CONST *)                 taskdim, DimHeight,
    (* TYPE *)                  DiagramTask,
                                DiagramView,
    (* VAR *)                   SnetWidth, SnetHeight,
                                SnetRowOne, SnetColOne,
                                SnetRows, SnetCols,
                                maxtask, HaveInfLoop,
                                Ypos, Ymaxpos,
                                Utility, Xpos, Xmaxpos,
                                loopnode,
                                ViewType;

FROM NetUtility             IMPORT
    (* CONST *)                 STARTPHANTOM,
                                ENDPHANTOM,
    (* VAR *)                   BoxWidth, BoxHeight,
                                TLGSBoxWidth, TLGSBoxHeight,
                                CharWidth, CharHeight,
                                MasterTaskHeight,
   (* PROC *)                   GetBoxSize,
                                TaskInRange,
                                GetOutlineType,
                                InitSnetHandW,
                                GetMasterTaskLabel,
                                MasterTaskCheck;

FROM NetworkData            IMPORT
     (* TYPE *)                 ANetworkType,
     (* VAR *)                  NetworkType;

FROM Overlays               IMPORT
    (* VAR *)			PackageOK;
    
FROM Timei                IMPORT
    (* CONST *)                 NoDuration;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM TSEDData            IMPORT
    (* CONST *)                 NOFRAME,
                                PIPELINE,

                                SOLID,
                                DOTTED,
                                DASHED,

                                MAXCARDINAL,
                                TEXTLEFT,
                                DATE,
                                NUMERICONLY,
                                NUMERICANDTEXT,

    (* VAR *)                   ChartType,
                                BaseCharacterWidth,
                                BaseCharacterHeight,
                                RealCharacterWidth,
                                RealCharacterHeight,
                                RealVerticalGap,
                                VerticalGap,
                                DrawingScale,
    (* PROC *)                  GetDataJustification;

FROM TSEDNotation        IMPORT
    (* CONST *)                 GAPFORNOTATION,
    (* PROC *)                  BorderSizeCalc,
                                CheckForLegend,
                                NotateAChart;


FROM TSEDObjectWrite        IMPORT
    (* PROC *)                  WriteBoolean,
                                WriteBox,
                                WriteCardinal,
                                WriteChartType,
                                WriteDeviceInformation,

(* for duration bar networks - not avaliable in TL version 4.0
 |                              WriteDurationBar,
 *)
                                WritePipe,
                                WritePoint,
                                WriteReal,
                                WriteText;

FROM PertTimescale          IMPORT
    (* PROC *)                  AddTimescaling;

FROM TSEDTimescale        IMPORT
    (* VAR *)                   AxisHeight,
                                AxisLength,
                                MaxAxisDate,
                                SaveCalendar,
                                WriteScaleDates;

FROM TSEDWrite            IMPORT
    (* PROC *)                 WriteToTLGSFile;

CONST
 (* crate layout constants *)
    FIELDCOUNT = 6;
    MAXLAYOUTROWS = 3;
    EXISTENCE = 1;
    X1 = 2;
    Y1 = 3;
    X2 = 4;
    Y2 = 5;
    WIDTH = 6;
    VERTMARGIN = 4;
    HORIZMARGIN = 20;

    ModuleNumber    = 20200;

TYPE 
    AnArrangementType = (TaskBox,LegendBox);

VAR    
    Pass,
    PipeGap,
    TaskNameBox,
    TotalTopHeight,
    TotalBottomHeight : CARDINAL;
    DrawingYMax      : INTEGER;
    
(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |   AccumulatedSlide : CARDINAL; 
 |   VertDBPlacement  : ARRAY [1..16] OF CARDINAL;
 |   SlideAmount      : ARRAY [0..taskdim] OF CARDINAL;
 |
 *)
 
 (* crate layout variables *)
    NumberOfRows : CARDINAL;
    RowMidPoint  : ARRAY [1..3] OF CARDINAL;
    CrateLayout  : ARRAY [1..FIELDCOUNT] OF ARRAY [1..6] OF CARDINAL;


(*--------------------------------------------------------------------------*)
        (*  
            WriteCrate
            
            Write crate to TLGS interface file.
            Format:
             CRATE          -- class tag
             row,col      -- matrix location
             width
             height
             frame type   -- PIPELINE 
             task color   -- resulting color based on filtering
             arrangement
         *)
         
PROCEDURE WriteCrate(X, Y, X2, Y2,
		     CrateFrame,
		     CrateFrameColor, 
		     CrateBGColor : CARDINAL; 
                     cell         : INTEGER;
                     content      : CARDINAL);

CONST
    PIPELINE = 5;
    PIPESTARTPHANTOM = 6;
    PIPEENDPHANTOM = 7;

VAR 
    FrameOutlineType,
    CrateFrameStyle,
    BGColor,
    TextColor        : CARDINAL;
    s                : ARRAY [0..255] OF CHAR;

BEGIN        

 (* object tag *)
    SetString(s,"CRATE");
    WriteToTLGSFile(s);
  
 (* matrix location (x,y), lower left corner of box *)
    WritePoint(X,Y);
    
 (* matrix location (x2,y2), upper right corner of box *)
    WritePoint(X2,Y2);
    
 (* frame color *)
    WriteCardinal(CrateFrameColor);

 (* crate background color *)
    WriteCardinal(CrateBGColor);

 (* frame highlight *)
    WriteCardinal(CrateFramePipeHighlight);
    
 (* frame radius *)
    WriteCardinal(CrateFramePipeRadius);
    
 (* frame line type *)
    WriteCardinal(CrateFramePipeStyle);
    
 (* frame style *)
    IF (content = LEGEND ) THEN
        CrateFrameStyle := CrateFrame;
    ELSE
        FrameOutlineType := GetOutlineType(cell);
        IF (CrateFrame <> NOFRAME) THEN
            IF (FrameOutlineType = STARTPHANTOM) THEN
                CrateFrameStyle := PIPESTARTPHANTOM;
            ELSIF (FrameOutlineType = ENDPHANTOM) THEN
                CrateFrameStyle := PIPEENDPHANTOM;
            ELSE
                CrateFrameStyle := CrateFrame;
            END;
        ELSE
                CrateFrameStyle := CrateFrame;
        END;
    END;
    WriteCardinal(CrateFrameStyle);
    
    TextColor := AllOtherDataColor;
    IF (content = TASKVALUE ) THEN
        IF ((FrameOutlineType = STARTPHANTOM) OR
            (FrameOutlineType = ENDPHANTOM)) THEN
             TextColor := OpenSummaryDataColor;
        END;
    (* get filtered task data color if any , BG not used *)
       GetFGColor(TextColor,BGColor,loopnode^[cell]); 
    END;    
    
    WriteBoxContents(cell, content, TextColor);
   
END WriteCrate;


(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            DurationBar
 |            
 |            Determine placement of the duration bars.
 |         *)
 |
 |PROCEDURE DurationBar(row, col  : CARDINAL;
 |	 	      cell      : INTEGER;
 |	 	      VertSlide : CARDINAL);
 |
 |VAR 
 |    x1Plan,
 |    x2Plan,
 |    x1Actual,
 |    x2Actual,
 |    yDBarCenterLine,
 |    complete,
 |    CompleteBarColor,
 |    FutureBarColor  : CARDINAL;
 |    task            : ATaskPtr;
 |    slack           : ADate;
 |
 |BEGIN        
 |    
 |    GetDurationBarDates(loopnode^[cell],x1Plan,x2Plan,x1Actual,x2Actual,slack);
 |    yDBarCenterLine:= GetY(row)+BaseCharacterHeight-VertSlide;
 |
 | (* percent complete *)  
 |    task:= loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
 |    complete:= task^.PercentComplete;
 |    loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
 |    
 | (* bar color *)              
 |    IF (MasterTaskCheck(cell) = master) THEN
 |        CompleteBarColor:= AchievementBarColor;
 |        FutureBarColor:= OpenSummaryBarColor;
 |    ELSE
 |        CompleteBarColor:= AchievementBarColor;
 |        FutureBarColor:= AllOtherBarColor;
 |    END;
 |
 | (* write out to duration bar to the TLGS file *)   
 |    WriteDurationBar(x1Plan,x2Plan,x1Actual,x2Actual,yDBarCenterLine,
 |                     complete,CompleteBarColor,FutureBarColor);
 |
 |END DurationBar;    
 |
 |
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            WriteDBCrate  --  Duration Bar Crate
 |            
 |             DBCRATE		-- class tag
 |             ACrate		-- object
 |             ADurationBar	-- object
 |         *)
 |         
 |PROCEDURE WriteDBCrate(row, col, 
 |		      CrateFrame,
 |		      CrateFrameColor : CARDINAL; 
 |                      cell            : INTEGER;
 |                      content         : CARDINAL;
 |                      VertSlide       : CARDINAL);
 |VAR 
 |    X, Y : CARDINAL;
 |    s    : ARRAY [0..255] OF CHAR;
 |
 |BEGIN        
 |
 | (* object tag *)
 |    SetString(s,"DBCRATE");
 |    WriteToTLGSFile(s);
 |
 |    X:= ORD(SnetWidth^[col]);
 |    Y:= GetY(row)+BaseCharacterHeight;
 |    WriteCrate(X,Y,CrateFrame,CrateFrameColor,cell,TASKVALUE);
 |    
 |    DurationBar(row, col, cell, VertSlide);
 |    
 |END WriteDBCrate;
 |
 *)


(*--------------------------------------------------------------------------*)
        (*  
            WriteLegend
                        
            Write legend to TLGS interface file.
            Format:
               LEGEND       -- class tag
         *)
         
PROCEDURE WriteLegend();

VAR 
    i, x ,y, x2,
    CrateFrame 	: CARDINAL;
    cell        : INTEGER;
    task	: ATaskPtr;
    TaskType    : DiagramTask;
    SeeChildren : BOOLEAN;
    s  		: ARRAY [0..255] OF CHAR;

BEGIN   
       
    WriteArrangement();
 (* legend title *)
    SetString(s," ");                                   (* 22-Jun-89 CMH *)
    WriteText(s,AllOtherDataColor,FontHeight);

 (* task crate for legend *)   
    cell:= 1;
    TaskType:= normal;
    SeeChildren:= FALSE;
    CrateFrame:= GetFrame();
    x  := 0;
    y  := 0;
    x2 := 0;
    FOR i:= 1 TO MAXLAYOUTROWS DO
        IF (CrateLayout[i,EXISTENCE] = 1) THEN
            IF (x2 < CrateLayout[i,X2]) THEN
                x2 := CrateLayout[i,X2];
            END;
        END;
        IF (CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] = 1) THEN
            IF (x2 < CrateLayout[i+MAXLAYOUTROWS,X2]) THEN
                x2 := CrateLayout[i+MAXLAYOUTROWS,X2];
            END;
        END;
    END;
    WriteCrate(x, y, x2, ORD(TLGSBoxHeight), CrateFrame,
               NormalCrateFrameColor, NormalCrateBGColor,
               cell, LEGEND);
  
END WriteLegend;


(*--------------------------------------------------------------------------*)
        (*  
             InitCrateArrangement
         *)

PROCEDURE InitCrateArrangement(ArrangementType : AnArrangementType);

CONST
    MAXFIELDWIDTH = 80;
VAR 
    DataRecord        : AColumnDataRecord;
    task              : ATaskPtr;
    CrateBoxWidth,
    RowsInCrate,
    BoxStringWidth,
    LeftMax,
    LeftField,
    RightMax,
    RightField,
    MaxWidth,
    i, frame          : CARDINAL;
    outline           : BOOLEAN;
    
BEGIN

    outline:= NetworkDiagramLayout^.BoxOutline;
    frame:= 0;
 (* how many characters in the string *)
    BoxStringWidth:= ORD(TLGSBoxWidth) DIV BaseCharacterWidth + 1;
     
 (* determine how many characters per box *)
    LeftMax:= 0;
    RightMax:= 0;
    NumberOfRows:=0;
 (* set up left, right, and string maximums and how many rows of data in a crate *)
    FOR i:= 1 TO MAXLAYOUTROWS DO
        IF (ArrangementType = TaskBox) THEN  
            LeftField := NetworkDiagramLayout^.Fields[i].ColumnWidth;
            RightField:= NetworkDiagramLayout^.Fields[i+MAXLAYOUTROWS].ColumnWidth;
            IF (LeftField > 0) OR (RightField > 0) THEN
                INC(NumberOfRows);
            END;
            IF (LeftField > 0) AND (RightField > 0) THEN
                IF LeftField > LeftMax THEN
                   LeftMax:= LeftField;
                END; 
                IF RightField > RightMax THEN
                   RightMax:= RightField;
                END; 
            END;
            MaxWidth:= LeftMax+RightMax;   
            IF MaxWidth > BoxStringWidth THEN
               MaxWidth:= BoxStringWidth;
            END;
            CrateBoxWidth := TLGSBoxWidth; 
        ELSE (* ArrangementType = LegendBox *)
            LeftField := NetworkDiagramLayout^.Fields[i].ColumnWidth;
            RightField:= NetworkDiagramLayout^.Fields[i+MAXLAYOUTROWS].ColumnWidth;
            IF (LeftField > 0) OR (RightField > 0) THEN
                INC(NumberOfRows);
                task := NIL;         
                IF (LeftField > 0) THEN  
                    GetColumnInfo(NIL, task,
                              NetworkDiagramLayout^.Fields[i].ColumnID,
                              ColumnName,
                              MAXFIELDWIDTH,
                              DataRecord);
                    LJust(DataRecord.StringValue);
                    TrimRear(DataRecord.StringValue);
                    LeftField := LengthOf(DataRecord.StringValue);
                END;
                IF (RightField > 0) THEN  
                    GetColumnInfo(NIL, task,
                              NetworkDiagramLayout^.Fields[i+MAXLAYOUTROWS].ColumnID,
                              ColumnName,
                              MAXFIELDWIDTH,
                              DataRecord);
                    LJust(DataRecord.StringValue);
                    TrimRear(DataRecord.StringValue);
                    RightField := LengthOf(DataRecord.StringValue);
                END;
            END;
            IF LeftField > LeftMax THEN
               LeftMax:= LeftField;
            END; 
            IF RightField > RightMax THEN
               RightMax:= RightField;
            END; 
            MaxWidth := LeftMax + RightMax;  
            IF (MaxWidth < 1) THEN
                INC(MaxWidth);
            END; 
            BoxStringWidth := MaxWidth+1;   
            CrateBoxWidth := MaxWidth*BaseCharacterWidth; 
        END;
    END; (* for *)
    
 (* find row midpoint defining right and left fields *)
    FOR i:= 1 TO MAXLAYOUTROWS DO
        RowMidPoint[i]:=0;
        LeftField := NetworkDiagramLayout^.Fields[i].ColumnWidth;
        RightField:= NetworkDiagramLayout^.Fields[i+MAXLAYOUTROWS].ColumnWidth;
        IF (LeftField > 0) AND (RightField > 0) THEN
            IF (LeftField+RightField) < MaxWidth THEN
                RowMidPoint[i]:= LeftMax+((BoxStringWidth-MaxWidth) DIV 2);
            ELSE
                RowMidPoint[i]:= LeftMax;
            END;
        END;
    END;
    
    RowsInCrate := 0;
    FOR i:= MAXLAYOUTROWS TO 1 BY -1 DO
        LeftField := NetworkDiagramLayout^.Fields[i].ColumnWidth;
        RightField:= NetworkDiagramLayout^.Fields[i+MAXLAYOUTROWS].ColumnWidth;
        IF (LeftField > 0) AND (RightField > 0) THEN
         (* left field *)  
            CrateLayout[i,EXISTENCE] := 1;
            CrateLayout[i,X1]:=frame;
            CrateLayout[i,Y1]:=frame+RowsInCrate*(BaseCharacterHeight+VerticalGap);
            CrateLayout[i,X2]:=frame+(RowMidPoint[i])*BaseCharacterWidth;
            CrateLayout[i,Y2]:=CrateLayout[i,Y1]+(BaseCharacterHeight+VerticalGap);
            CrateLayout[i,WIDTH]:=RowMidPoint[i];
         (* right field *)  
            CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] := 1;
            CrateLayout[i+MAXLAYOUTROWS,X1]:=CrateLayout[i,X2];
            CrateLayout[i+MAXLAYOUTROWS,Y1]:=CrateLayout[i,Y1];
            CrateLayout[i+MAXLAYOUTROWS,X2]:=CrateBoxWidth-frame;
            CrateLayout[i+MAXLAYOUTROWS,Y2]:=CrateLayout[i,Y2];
            CrateLayout[i+MAXLAYOUTROWS,WIDTH]:=BoxStringWidth-RowMidPoint[i];
            INC(RowsInCrate);
        ELSIF (LeftField > 0) OR (RightField > 0) THEN
            IF (LeftField <> 0) THEN
             (* Left Field *)
                CrateLayout[i,EXISTENCE] := 1;
                CrateLayout[i,X1]:=frame;
                CrateLayout[i,Y1]:=frame+RowsInCrate*(BaseCharacterHeight+VerticalGap);
                CrateLayout[i,X2]:=CrateBoxWidth-frame;
                CrateLayout[i,Y2]:=CrateLayout[i,Y1]+(BaseCharacterHeight+VerticalGap);
                CrateLayout[i,WIDTH]:=BoxStringWidth;
             (* Right Field *)
                CrateLayout[i+MAXLAYOUTROWS,EXISTENCE]:= 0;
            END;
            IF (RightField <> 0) THEN 
             (* Right Field *)
                CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] := 1;
                CrateLayout[i+MAXLAYOUTROWS,X1]:=frame;
                CrateLayout[i+MAXLAYOUTROWS,Y1]:=frame+RowsInCrate*(BaseCharacterHeight+VerticalGap);
                CrateLayout[i+MAXLAYOUTROWS,X2]:=CrateBoxWidth-frame;
                CrateLayout[i+MAXLAYOUTROWS,Y2]:=CrateLayout[i+MAXLAYOUTROWS,Y1]+BaseCharacterHeight+VerticalGap;
                CrateLayout[i+MAXLAYOUTROWS,WIDTH]:=BoxStringWidth;
             (* Left Field *)
                CrateLayout[i,EXISTENCE]:= 0;
            END;
            INC(RowsInCrate);
        ELSE
            CrateLayout[i,EXISTENCE]:= 0;
            CrateLayout[i+MAXLAYOUTROWS,EXISTENCE]:= 0;
        END;
    END;       
 
END InitCrateArrangement;


(*--------------------------------------------------------------------------*)
        (*  
            WritePipeArrangement
             NumberOfPipess
             Pipes
            
         *)
         
PROCEDURE WritePipeArrangement();

VAR 
    i,
    c1x, c1y,
    c2x, c2y,
    NumberOfPipes,
    DividingLines,
    RowsInCrate,
    RowHeight,
    frame    	    : CARDINAL;
    outline 	    : BOOLEAN;

BEGIN
     
    outline:= NetworkDiagramLayout^.BoxOutline;
    frame:= 0;
    
 (* count number of pipes *)
    NumberOfPipes:= 0;
 (* vertical *)  
    FOR i:= 1 TO MAXLAYOUTROWS DO
        IF (RowMidPoint[i] <> 0) THEN
            INC(NumberOfPipes);
        END;
    END;
 (* horizontal *)
    IF (NumberOfRows = 2) THEN
        INC(NumberOfPipes);
    END;
    IF (NumberOfRows = 3) THEN
        INC(NumberOfPipes,2);
    END;
    WriteCardinal(NumberOfPipes);
    
    IF (NumberOfPipes > 0) THEN
    
     (* add pipe for vertical dividing lines *)
        RowsInCrate := 0;
        RowHeight:= (ORD(TLGSBoxHeight)-(frame*2)) DIV NumberOfRows;
        FOR i:= MAXLAYOUTROWS TO 1 BY -1 DO
            IF (RowMidPoint[i] > 0) THEN
                c1x:= frame+(RowMidPoint[i])*BaseCharacterWidth;
                c1y:= (RowsInCrate)*RowHeight+frame;
                c2x:= c1x;
                c2y:= c1y+RowHeight;
                WritePipe(c1x, c1y, c2x, c2y,
                          CrateInteriorPipeRadius, CrateInteriorPipeRadius,
                          CrateInteriorPipeWidth, CrateInteriorPipeStyle,
                          SOLID, CrateInteriorPipeHighlight, 
                          NormalCrateFrameColor);
            END;
            IF ((CrateLayout[i,EXISTENCE] > 0) OR 
                (CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] > 0)) THEN
                 INC(RowsInCrate);
            END;
         END;
     
     (* add pipe for horizontal dividing lines *)
        DividingLines := 0;
        FOR i := 1 TO MAXLAYOUTROWS DO
            IF (((CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] = 1) OR
                 (CrateLayout[i,EXISTENCE] = 1)) AND
                (DividingLines < (NumberOfRows-1))) THEN
                 INC(DividingLines);
                 c1x := 0;
                 c1y := frame + DividingLines*(BaseCharacterHeight+VerticalGap);
                 IF (CrateLayout[i+MAXLAYOUTROWS,EXISTENCE] = 1) THEN
                     c2x := CrateLayout[i+MAXLAYOUTROWS,X2];
                 ELSE
                     c2x := CrateLayout[i,X2];
                 END;
                 c2y := c1y;
                 WritePipe(c1x, c1y, c2x, c2y,
                           CrateInteriorPipeRadius, CrateInteriorPipeRadius,
                           CrateInteriorPipeWidth, CrateInteriorPipeStyle,
                           SOLID, CrateInteriorPipeHighlight,
                           NormalCrateFrameColor);
            END;
        END;
    
    END;   (* NumberOfPipes > 0 *)
      
END WritePipeArrangement;


(*--------------------------------------------------------------------------*)
        (*  
            WriteBoxContents
             NumberOfBoxes
             Boxes
            
         *)
         
PROCEDURE WriteBoxContents(cell : INTEGER; content, TextColor : CARDINAL);

CONST
    MAXFIELDWIDTH = 80;

VAR 
    i, 
    NumberOfBoxes : CARDINAL;
    s  		  : ARRAY [0..255] OF CHAR;
     
BEGIN

 (* get box count *)
    NumberOfBoxes:= 0;
    FOR i:= 1 TO FIELDCOUNT DO
        IF (CrateLayout[i,EXISTENCE]=1) THEN
            INC(NumberOfBoxes);
        END;
    END; (*for*)
    WriteCardinal(NumberOfBoxes);
    
 (* write content - text *)
    FOR i:= 1 TO FIELDCOUNT DO
        IF (CrateLayout[i,EXISTENCE]=1) THEN
            IF (content = TASKVALUE) THEN
                GetBoxContent(s,i,NetworkDiagramLayout^.Fields[i].ColumnWidth,cell);
            ELSIF (content = LEGEND) THEN
                GetLegendContent(s,i,MAXFIELDWIDTH,cell);
            END;   
            WriteText(s,TextColor,FontHeight);
        END;
    END;
    
END WriteBoxContents;


(*--------------------------------------------------------------------------*)
        (*  
            WriteBoxArrangement
             NumberOfBoxes
             Boxes
            
         *)
         
PROCEDURE WriteBoxArrangement();

VAR 
    i, NotUsed,
    NumberOfBoxes : CARDINAL;
    s 	          : ARRAY [0..255] OF CHAR;
     
BEGIN
    
    NotUsed:= 0;
     
 (* get box count *)
    NumberOfBoxes:= 0;
    FOR i:= 1 TO FIELDCOUNT DO
        IF (CrateLayout[i,EXISTENCE]=1) THEN
            INC(NumberOfBoxes);
        END;
    END; (*for*)
    
 (* write box count *)   
    WriteCardinal(NumberOfBoxes);
  
    SetString(s," ");
 (* write boxes *)
    FOR i:= 1 TO FIELDCOUNT DO
        IF (CrateLayout[i,EXISTENCE]=1) THEN
            WriteBox(CrateLayout[i,X1],
            	     CrateLayout[i,Y1],
            	     CrateLayout[i,X2],
            	     CrateLayout[i,Y2],
            	     NOFRAME, s,
            	     NotUsed,NotUsed);
        END;
    END;

END WriteBoxArrangement;


(*--------------------------------------------------------------------------*)
        (*  
            WriteArrangement
            
            Write arrangement, descibed as offset to x,y origin of a
            crate, to TLGS interface file.
            
            Format:
            
             ARRANGEMENT  -- class tag
             NumberOfPipes
             Pipes
             NumberOfBoxes
             Boxes
         *)
         
PROCEDURE WriteArrangement();

VAR 
    s : ARRAY [ 0..255] OF CHAR;
    
BEGIN

 (* write object tag *)
    SetString(s,"ARRANGEMENT");
    WriteToTLGSFile(s);

    WritePipeArrangement();   
    WriteBoxArrangement();

END WriteArrangement;


(*--------------------------------------------------------------------------*)
        (*  
            MasterTaskInRange 
            
            Verifies the input master task is within the drawing matrix.
         *)
    
    PROCEDURE MasterTaskInRange   (  TaskID   : INTEGER   ) : BOOLEAN;
    VAR
        OK          : BOOLEAN;
    BEGIN
        OK := (Xpos[TaskID] <= DimHeight);
        OK := OK AND (Ypos[TaskID] <= DimHeight);
    RETURN OK;
    END MasterTaskInRange;
    
    
(*--------------------------------------------------------------------------*)
        (*  
            WriteMasterOpen
            
            Write task to TLGS interface file.
            Format:
             MasterOPEN   -- class tag
             row,col      -- matrix location
             string       -- taskname 
         *)
         
PROCEDURE WriteMasterOpen(OrgRow,col : CARDINAL; cell : INTEGER);

CONST

    BASEMASTERCHARWIDTH = 3.6;  (* BaseCharacterWidth (of 4) * 0.9 (90%) *)

VAR 

    TempReal          : REAL;
    task              : ATaskPtr;
    FieldWidth,
    c1x, c1y,
    c2x, c2y,
    firstx, firsty,
    lastx, lasty,
    i, actual,
    FGColor,
    BGColor,
    row,
    index,
    MaxLabelWidth     : CARDINAL;
    s	  	      : ARRAY [0..255] OF CHAR;

BEGIN        

    row:= OrgRow;
    
 (* determine layout and get the layout pointer *)
    
 (* object tag *)
    SetString(s,"MASTEROPEN");
    WriteToTLGSFile(s);
    
    task:= loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
    index:= task^.XX;
    loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);

    IF (Xmaxpos[index] > DimHeight) THEN
        MaxLabelWidth := (ORD(SnetWidth^[Xmaxpos[DimHeight]] 
                            - SnetWidth^[col])) DIV BaseCharacterWidth;
    ELSE
        MaxLabelWidth := (ORD(SnetWidth^[Xmaxpos[index]] 
                            - SnetWidth^[col])) DIV BaseCharacterWidth;
    END;
    IF (MaxLabelWidth > 255) THEN
        MaxLabelWidth := 255;
    END; 
    GetMasterTaskLabel(s,loopnode^[cell],NetworkDiagramLayout,MaxLabelWidth);
    actual:= ORD(s[0]);
   
 (* master task name color *)  
    FGColor := OpenSummaryDataColor;
    BGColor := 0;(* not used for master open *)
    GetFGColor(FGColor,BGColor,loopnode^[cell]); (* task name color *)
    
 (* connector to start of master task name *)  
    firstx:= SnetWidth^[col];
    firsty:= GetY(row)+BaseCharacterHeight+(BaseCharacterHeight DIV 2);
    
 (* connector to end of master task name *)  
    IF ((actual < MaxLabelWidth) AND (actual > 0)) THEN
         INC(actual,2); (* allow for 1 character each side in box text *)
    END;
    TempReal := FLOAT(actual);
    lastx:= firstx + TRUNC(TempReal*BASEMASTERCHARWIDTH);
    lasty:= firsty;

 (* text box for master task name *)
    WritePoint(firstx, firsty-BaseCharacterHeight+(BaseCharacterHeight DIV 2));
    WritePoint(lastx,  firsty+BaseCharacterHeight+(BaseCharacterHeight DIV 2));
    WriteText(s,FGColor,FontHeight);


 (* first pipe *)
    col:= Utility[index];   (* Upper Left Corner *)
    c1x:= ORD(SnetWidth^[col]) +(GetColWidth (col) DIV 2);
    c1y:= firsty;
    
    WritePipe(c1x, c1y, firstx, firsty,
              MasterPipeRadius, MasterPipeRadius,
              MasterPipeWidth, MasterPipeStyle,
              DASHED, MasterPipeHighlight,
              MTOpenLineColor);
 
 (* second pipe *)
    c2x:= c1x;
    IF (Ymaxpos[index] > DimHeight) THEN
        c2y:= 0; (* draw off page to clip *)
    ELSE
        row:= Ymaxpos[index];  (* Lower Left Corner *)
        c2y:= GetY(row)+BaseCharacterHeight;
    END;
    WritePipe(c1x, c1y, c2x, c2y,
              MasterPipeRadius, MasterPipeRadius,
              MasterPipeWidth, MasterPipeStyle,
              DASHED, MasterPipeHighlight,
              MTOpenLineColor);
 
 (* third pipe *)
    c1x:= c2x;
    c1y:= c2y;
    c2y:= c1y;
    
    IF (Xmaxpos[index] > DimHeight) THEN
        c2x:= ORD(SnetWidth^[DimHeight]) + (GetColWidth (DimHeight) DIV 2)+100; (* draw off page to clip *)
    ELSE
        col:= Xmaxpos[index];  (* Lower Left corner *)    
        c2x:= ORD(SnetWidth^[col]) + (GetColWidth (col) DIV 2);
    END;

    WritePipe(c1x, c1y, c2x, c2y,
              MasterPipeRadius, MasterPipeRadius,
              MasterPipeWidth,MasterPipeStyle,
              DASHED, MasterPipeHighlight,
              MTOpenLineColor);
    
 (* fourth pipe *)
    row:= Ypos[index];  (* Upper Right Corner *) 
    c1x:= c2x;   
    c1y:= lasty;
    
    WritePipe(c1x, c1y, c2x, c2y,
              MasterPipeRadius, MasterPipeRadius,
              MasterPipeWidth, MasterPipeStyle,
              DASHED, MasterPipeHighlight,
              MTOpenLineColor);

 (* last pipe *)
    WritePipe(lastx, lasty, c1x, c1y,
              MasterPipeRadius, MasterPipeRadius,
              MasterPipeWidth, MasterPipeStyle,
              DASHED, MasterPipeHighlight,
              MTOpenLineColor);
    
END WriteMasterOpen;


(*--------------------------------------------------------------------------*)
        (*  
            WriteVertPipes
            
            Find and write vertical line information to TLGS interface file.
            The pipes are defined by the starting and ending connectors.  
            The connectors are output at the center point.

         *)
         
PROCEDURE WriteVertPipes();

VAR 
    row, col,
    c1x, c1y, 
    c2x, c2y, 
    RowHeight,
    Y, code,
    LineColor         : CARDINAL;
    cell              : INTEGER;
    LineStarted       : BOOLEAN;

BEGIN
  
    
    FOR col := SnetColOne TO SnetCols DO

        LineStarted:= FALSE;
        FOR row := SnetRowOne TO SnetRows DO

            cell:= GetCellInfo(row,col);
            Y:= GetY(row);
            RowHeight:= GetRowHeight(row)-BaseCharacterHeight; (* subtract cursor row *);
            c1x:= ORD(SnetWidth^[col]) + (GetColWidth(col) DIV 2);
            c2x:= c1x;
            
            IF  (cell < 0) THEN
              (* check for line color change, if so start a new line *)
                 IF (LineStarted) THEN
                     IF (GetLineColor(cell) <> LineColor) THEN
                      (* connector 2 *)
                         c2y:= Y + GetRowHeight(row); 
                         WritePipe(c1x, c1y, c2x, c2y,
                                   NormalPipeRadius, NormalPipeRadius,
                                   NormalPipeWidth, NormalPipeStyle,	
                      	           SOLID, NormalPipeHighlight, LineColor);
                         LineStarted:= FALSE;                
                     END;
                 END;
              (* remove color bias to get actual character *)    
                 IF (ABS(cell) > COLORBIAS) THEN
                     cell := cell + COLORBIAS;
                 END;
            END;    
                    
            
            CASE cell OF

                 pHBar :
              (* 
               *  Intersecting line, not a plus 
               *)  

                 IF (LineStarted) THEN
                  (* connector 2 *)
                     c2y:= Y+(RowHeight DIV 2) + PipeGap+(BaseCharacterHeight+VerticalGap);	(* back off some to show break *)
                     WritePipe(c1x, c1y, c2x, c2y,
                               NormalPipeRadius, NormalPipeRadius,
                               NormalPipeWidth, NormalPipeStyle,	
                      	       SOLID, NormalPipeHighlight, LineColor);
                     LineStarted:= FALSE;
                     
                  (* connector 1 *)
                     c1y:= Y + GetRowHeight(row)+BaseCharacterHeight - PipeGap;
                     LineStarted:= TRUE; 
                     LineColor := GetLineColor(GetCellInfo(row,col));                        
                 END;

              |  pTopTeeUp, pTopTeeDown, pURC, pULC :
              (* starting cells only 
               * -- always a starter, could be a starter and ender, 
               *    ie. only one cell describing pipe
               *)
                 
                 IF (NOT LineStarted) THEN    
                 (* connector 1 *)
                    c1y:= Y+(RowHeight DIV 2)+(BaseCharacterHeight);
                    LineStarted:= TRUE;                
                    LineColor := GetLineColor(GetCellInfo(row,col));                        
                  END;
                  
            |  pVBar, pMTaskVBar, pRightTee, pLeftTee, pplus:
              (* 
               * starting, middle and ending cells 
               *)
                 IF NOT (LineStarted) THEN                 
                  (* connector 1 *)
                     c1y:= Y + GetRowHeight(row)+BaseCharacterHeight;
                     LineStarted:= TRUE; 
                     LineColor := GetLineColor(GetCellInfo(row,col));                        
                  END;                                    

            | pBotTee, pLRC, pLLC :
              (* ending cells only,
               * -- always an ender, could be a starter and ender, 
               *    ie. only one cell describing pipe
               *)  
                 
                 IF (GetCellInfo(row-1,col) > 0) THEN (* task previous, start found*)
                  (* connector 1 *)
                     c1y:= Y + GetRowHeight(row)+BaseCharacterHeight;
                     LineStarted:= TRUE;
                     LineColor := GetLineColor(GetCellInfo(row,col));                        
                 END;
                 
                 IF (LineStarted) THEN
                  (* connector 2 *)
                     c2y:= Y+(RowHeight DIV 2)+(BaseCharacterHeight);
                     WritePipe(c1x, c1y, c2x, c2y,
                               NormalPipeRadius, NormalPipeRadius,
                               NormalPipeWidth, NormalPipeStyle,	
                      	       SOLID, NormalPipeHighlight, LineColor);
                     LineStarted:= FALSE;
                 END;

            ELSE
                 IF (cell > 0) THEN (* task found *)
                     IF (LineStarted) THEN
                   (* connector 2 *)
                      c2y:= Y + GetRowHeight(row); 
                      WritePipe(c1x, c1y, c2x, c2y,
                                NormalPipeRadius, NormalPipeRadius,
                                NormalPipeWidth, NormalPipeStyle,	
                      	        SOLID, NormalPipeHighlight, LineColor);
                        LineStarted:= FALSE;                
                     END;
                 END;
            END; (* case *)
            

        END; (* for *)

    END; (* for *)
    
END WriteVertPipes;


(*--------------------------------------------------------------------------*)
        (*  
            WriteHorizPipes
            
            Find and write horizontal line information to TLGS interface file.
            The pipes are defined by the starting and ending connectors.  
            The connectors are output at the center point.
         *)
         
PROCEDURE WriteHorizPipes();

CONST
    NORADIUS = 0;
    
VAR 
    row, col,
    c1x, c1y, 
    c2x, c2y, 
    c1radius, c2radius,
    RowHeight,
    Y,
    LineColor             : CARDINAL;
    NextCell,
    PrevCell,
    cell                  : INTEGER;
    ColorChange,
    LineStarted           : BOOLEAN;

BEGIN 

    c1radius:= NORADIUS;
    c2radius:= NORADIUS;
    
    FOR row := SnetRowOne TO SnetRows DO
       
        LineStarted := FALSE;
        ColorChange := FALSE;
        FOR col := SnetColOne TO SnetCols DO
    
            cell:= GetCellInfo(row,col);
            Y:= GetY(row);
            RowHeight:= GetRowHeight(row)-BaseCharacterHeight; (* subtract cursor row *);
            c1y:= Y+(RowHeight DIV 2)+BaseCharacterHeight;	
            c2y:= c1y;	
            
            IF  (cell < 0) THEN
              (* check for line color change, if so start a new line *)
                 IF (LineStarted) THEN
                     IF (GetLineColor(cell) <> LineColor) THEN
                         ColorChange := TRUE;
                     END;
                 END;
              (* remove color bias to get actual character *)    
                 IF (ABS(cell) > COLORBIAS) THEN
                     cell := cell + COLORBIAS;
                 END;
            END;    

            PrevCell:= GetCellInfo(row,col-1);
         (* remove color bias to get actual character *)    
            IF (ABS(PrevCell) > COLORBIAS) THEN
                PrevCell := PrevCell + COLORBIAS;
            END;
            NextCell:= GetCellInfo(row,col+1);
         (* remove color bias to get actual character *)    
            IF (ABS(NextCell) > COLORBIAS) THEN
                NextCell := NextCell + COLORBIAS;
            END;

            CASE cell OF
            
                pVBar :  (* ending character *)
                (* 
                 *  Intersecting line, not a plus 
                 *)  

                 IF (LineStarted) THEN
                     IF (col > ORD(SnetColOne)) THEN   (* not on left edge *)
                      (* connector 2 *)
                         c2x:= ORD(SnetWidth^[col]) +
                              (GetColWidth(col) DIV 2) - PipeGap;
                      (* if connecting to a task box, no radius wanted 
                         at that intersection *)
                         IF ((NextCell > 0) OR (NextCell = pVDash)) THEN 
                              c2radius:= NORADIUS;
                         ELSE
                              c2radius:= NormalPipeRadius;
                         END;
                         WritePipe(c1x, c1y, c2x, c2y,
                                   c1radius, c2radius,
                                   NormalPipeWidth, NormalPipeStyle,	
                                   SOLID, NormalPipeHighlight, LineColor);
                         LineStarted:= FALSE;
                         ColorChange:= FALSE;
                     END;
                 END;

              | pLeftTee, pDLeftTee, pULC, pLLC:

                (* starting cells  
                 * -- always a starter, could be a starter and ender, 
                 *    ie. only one cell describing pipe
                 *)
                    
                 IF ((LineStarted) OR (ColorChange)) THEN
                   (* connector 2 *)
                      c2x:= ORD(SnetWidth^[col]) +
                           (GetColWidth(col) DIV 2) - PipeGap;
                   (* if connecting to a task box, no radius wanted 
                      at that intersection *)
                      IF ((NextCell > 0) OR (NextCell = pVDash)) THEN 
                           c2radius:= NORADIUS;
                      ELSE
                           c2radius:= NormalPipeRadius;
                      END;
                      WritePipe(c1x, c1y, c2x, c2y,
                                c1radius, c2radius,
                                NormalPipeWidth, NormalPipeStyle,	
                                SOLID, NormalPipeHighlight, LineColor);
                      LineStarted:= FALSE;
                      ColorChange:= FALSE;
                  END;
              (* connector 1 *)
                 c1x:= ORD(SnetWidth^[col]) + (GetColWidth(col) DIV 2);
              (* if connecting to a task box, no radius wanted 
                 at that intersection *)
                 IF ((cell = pDLeftTee) OR (cell = pLeftTee)) THEN 
                     c1radius := NORADIUS;
                 ELSE
                     c1radius := NormalPipeRadius;
                 END;
                 LineStarted := TRUE;
                 LineColor := GetLineColor(GetCellInfo(row,col));                        

            | pHBar, pTopTeeUp, pTopTeeDown, 
              pBotTee, pplus, pDPlus, pMTaskHBar:

                (* 
                 * starting, middle or ending cells 
                 *)
                 IF ((ColorChange) AND (LineStarted)) THEN
                   (* connector 2 *)
                      c2x:= ORD(SnetWidth^[col]);
                   (* if connecting to a task box, no radius wanted 
                      at that intersection *)
                      IF (cell = pDRightTee) THEN 
                          c2radius:= NORADIUS;
                      ELSE
                          c2radius:= NormalPipeRadius;
                      END;
                      WritePipe(c1x, c1y, c2x, c2y, 
                                c1radius, c2radius,
                                NormalPipeWidth,NormalPipeStyle,	
                                SOLID,NormalPipeHighlight,LineColor);
                      ColorChange := FALSE;
                      LineStarted := FALSE;
                 END;
                 
                 IF (NOT LineStarted) THEN
                  (* connector 1 *)
                     c1x := SnetWidth^[col];
                     IF (PrevCell = pVBar) THEN
                         c1x := ORD(SnetWidth^[col-1]) + (GetColWidth(col-1) DIV 2) + PipeGap;
                     END;
		     IF (PrevCell = pVDash) THEN
		         c1x := c1x-GetColWidth (col-1) DIV 2;
		     END;
		     IF ((PrevCell = pURC) OR (PrevCell = pLRC)) THEN
		          c1x := c1x-GetColWidth (col-1) DIV 2 + PipeGap;
		     END;
                  (* if connecting to a task box, no radius wanted 
                     at that intersection *)
                     IF ((PrevCell > 0) OR (PrevCell = pVDash)) THEN 
                          c1radius := NORADIUS;
                     ELSE
                          c1radius := NormalPipeRadius;
                     END;
		     LineStarted := TRUE;
                     LineColor := GetLineColor(GetCellInfo(row,col));                        
		 END;
                
            | pURC, pLRC, pRightTee, pDRightTee:
           
                (* ending cells 
                 * -- always an ender, could be a starter and ender, 
                 *    ie. only one cell describing pipe
                 *)  
            
                 IF ((ColorChange) AND (LineStarted)) THEN
                   (* connector 2 *)
                      c2x:= ORD(SnetWidth^[col]);
                   (* if connecting to a task box, no radius wanted 
                      at that intersection *)
                      IF (cell = pDRightTee) THEN 
                          c2radius:= NORADIUS;
                      ELSE
                          c2radius:= NormalPipeRadius;
                      END;
                      WritePipe(c1x, c1y, c2x, c2y, 
                                c1radius, c2radius,
                                NormalPipeWidth,NormalPipeStyle,	
                                SOLID,NormalPipeHighlight,LineColor);
                      ColorChange := FALSE;
                      LineStarted := FALSE;
                 END;
                 
                 IF (NOT LineStarted) THEN
                  (* connector 1 *)
                     c1x:= SnetWidth^[col];
	             IF (PrevCell = pVDash) THEN
		         c1x:= c1x-GetColWidth (col-1) DIV 2;
		     END;
                     IF (PrevCell = pVBar) THEN
                         c1x:= ORD(SnetWidth^[col-1]) + (GetColWidth(col-1) DIV 2) + PipeGap;
                     END;
		     IF ((PrevCell = pURC) OR (PrevCell = pLRC)) THEN
		          c1x:= c1x-GetColWidth (col-1) DIV 2 + PipeGap;
		     END;
                  (* if connecting to a task box, no radius wanted 
                     at that intersection *)
                     IF ((PrevCell > 0) OR (PrevCell = pVDash)) THEN 
                          c1radius:= NORADIUS;
                     ELSE
                          c1radius:= NormalPipeRadius;
                     END;
                     LineStarted:= TRUE;
                     LineColor := GetLineColor(GetCellInfo(row,col));                        
                  END;
             
               (* connector 2 *)
                  c2x:= ORD(SnetWidth^[col]) +(GetColWidth(col) DIV 2);
               (* if connecting to a task box, no radius wanted 
                  at that intersection *)
                  IF (cell = pDRightTee) THEN 
                      c2radius:= NORADIUS;
                  ELSE
                      c2radius:= NormalPipeRadius;
                  END;
                  WritePipe(c1x, c1y, c2x, c2y, 
                            c1radius, c2radius,
                            NormalPipeWidth,NormalPipeStyle,	
                            SOLID,NormalPipeHighlight,LineColor);
                  LineStarted:= FALSE;
                 
            ELSE  
            
                 IF (cell > 0) THEN (* task found *)
                     IF (LineStarted) THEN
                     (* connector 2 *)
                        c2x:= SnetWidth^[col];
                        c2radius:= NORADIUS;
                        WritePipe(c1x, c1y, c2x, c2y,
                                  c1radius,c2radius,
                                  NormalPipeWidth, NormalPipeStyle,	
                        	  SOLID, NormalPipeHighlight, LineColor);
                        LineStarted:= FALSE;
                        ColorChange:= FALSE;
                     END;
                 END;
            
            END; (* case *)

        END; (* for *)

    END; (* for *)
    
END WriteHorizPipes;


(*--------------------------------------------------------------------------*)
        (*  
            GetLineColor
            Determines line color normal or critical  (* 24-Jun-89 CMH *)
         *)
         
PROCEDURE GetLineColor(cell : INTEGER) : CARDINAL; 

VAR
    LineColor : CARDINAL;  
       
BEGIN
 
    IF (ABS(cell) > COLORBIAS) THEN
        LineColor := CritDepLineColor;
    ELSE
        LineColor := DepLineColor;
    END;
    
    RETURN(LineColor);
            
END GetLineColor;
            

(*--------------------------------------------------------------------------*)
        (*  
            GetBoxContent
         *)
         
PROCEDURE GetBoxContent(VAR s 	       : ARRAY OF CHAR; 
			    field,
			    FieldWidth : CARDINAL;
			    cell       : INTEGER);
CONST
    MAXFIELDWIDTH = 80;
VAR
    index,
    DataWidth  : CARDINAL;
    task       : ATaskPtr;
    DataRecord : AColumnDataRecord;
    Found      : BOOLEAN;
    PlusSign   : ARRAY [0..5] OF CHAR;
        
BEGIN

    SetString(PlusSign,"+");
    
 (* get column data type - text, numeric, or date*)    (* 9-Aug-89 CMH *)
    task := NIL;
    GetColumnInfo(NIL, task, NetworkDiagramLayout^.Fields[field].ColumnID,
                  ColumnDataType, 0, DataRecord);

 (* if equal spacing send out the exact length
       else send out full string length *)
    CASE (GetDataJustification(DataRecord.CardinalValue)) OF
          DATE, NUMERICONLY :
          DataWidth:= FieldWidth;
    ELSE (* TEXTLEFT, NUMERICANDTEXT *)
          DataWidth:= MAXFIELDWIDTH;
    END;
    
    task := loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
    Found := GetColumnString(loopnode^[cell], task,
                             NetworkDiagramLayout^.Fields[field].ColumnID,
                             Plan,
                             DataWidth,
                             s);
    loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
    LJust(s);
    index := Search(s,PlusSign,0);
    IF (index = 1) THEN
        s[index] := blank;
    END;
    TrimFront(s);
    TrimRear(s);

END GetBoxContent;


(*--------------------------------------------------------------------------*)
        (*  
            GetLegendContent
         *)
         
PROCEDURE GetLegendContent(VAR s     	   : ARRAY OF CHAR; 
		   	       field,
			       FieldWidth : CARDINAL;
			       cell  	   : INTEGER);
VAR
    task                    : ATaskPtr;
    TempReal                : REAL;
    DataRecord              : AColumnDataRecord;    
BEGIN

    task := loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
    GetColumnInfo(loopnode^[cell], task,
                  NetworkDiagramLayout^.Fields[field].ColumnID,
                  ColumnName,
                  FieldWidth,
                  DataRecord);
    loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
    LJust(DataRecord.StringValue);
    TrimRear(DataRecord.StringValue); (* 28-Aug-89 CMH *)
    Copy(DataRecord.StringValue, s);
    
END GetLegendContent;


(*--------------------------------------------------------------------------*)
        (*  
            GetRowHeight
         *)
         
PROCEDURE GetRowHeight(row : CARDINAL) : CARDINAL;

VAR
     height : CARDINAL;

BEGIN

 (* row height *)   
    height:= 0;
   
    IF row = ORD(SnetRowOne) THEN
       height:= ORD((DrawingYMax-SnetHeight^[row]));
    ELSE
       height:= ORD((SnetHeight^[row-1]-SnetHeight^[row]));  
    
    (* for duration bar networks - not avaliable in TL version 4.0  
     |
     | height:= ORD((SnetHeight^[row-1]-SnetHeight^[row])) - SlideAmount[row-1];  
     |
     *) 
    END;
    
    RETURN(height);
    
END GetRowHeight;


(*--------------------------------------------------------------------------*)
        (*  
            GetColWidth
         *)
         
PROCEDURE GetColWidth(col : CARDINAL) : CARDINAL;

VAR
     width : CARDINAL;

BEGIN

 (* col width *)   
    width:= 0;

    IF col = ORD(SnetCols) THEN
       width:= LastColPosition-ORD(SnetWidth^[col]);
    ELSE
       width:= SnetWidth^[col+1]-SnetWidth^[col];  
    END;
    
    RETURN(width);
    
END GetColWidth;


(*--------------------------------------------------------------------------*)
        (*  
            GetY
         *)
         
PROCEDURE GetY(row : CARDINAL) : CARDINAL;

VAR
     y : CARDINAL;

BEGIN

      y:= ORD(SnetHeight^[row]);

    RETURN(y);
    
END GetY;


(*--------------------------------------------------------------------------*)
        (*  
            GetFrame
         *)
         
PROCEDURE GetFrame():CARDINAL;
BEGIN

 (* determine layout and get the layout pointer *)

    IF (NetworkDiagramLayout^.BoxOutline) THEN   
        RETURN(PIPELINE);
    ELSE
        RETURN(NOFRAME);
    END;
      
END GetFrame;


(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            Minimum
 |         *)
 |         
 |PROCEDURE Minimum(n1,n2 : CARDINAL) : CARDINAL;
 |
 |BEGIN
 |
 |    IF (n1 < n2) THEN
 |        RETURN(n1);
 |    ELSE
 |        RETURN(n2);
 |    END;
 |    
 |END Minimum;
 |
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            Maximum
 |         *)
 |         
 |PROCEDURE Maximum(n1,n2 : CARDINAL) : CARDINAL;
 |
 |BEGIN
 |
 |    IF (n1 > n2) THEN
 |        RETURN(n1);
 |    ELSE
 |        RETURN(n2);
 |    END;
 |    
 |END Maximum;
 |
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            SlideVerticalEdge
 |            
 |         *)
 |         
 |PROCEDURE SlideVerticalEdge(cell :INTEGER):CARDINAL;
 |
 |VAR 
 |    x1Plan,
 |    x2Plan,
 |    x1Actual,
 |    x2Actual,
 |    index,
 |    MaxIndex,
 |    CurrentXMin,
 |    CurrentXMax,
 |    VertSlide   : CARDINAL;
 |    slack       : ADate;
 |    done        : BOOLEAN;
 |
 |BEGIN
 |     
 |    VertSlide:= 0;
 |    GetDurationBarDates(loopnode^[cell],x1Plan,x2Plan,x1Actual,x2Actual,slack);
 |    CurrentXMin:= Minimum(x1Plan,x1Actual);
 |    CurrentXMax:= Maximum(x2Plan,x2Actual);
 |    index:=1;
 |    MaxIndex:= 16;
 |    done:= FALSE;
 |    REPEAT 
 |       IF (CurrentXMax <= VertDBPlacement[index]) THEN
 |           VertDBPlacement[index]:= CurrentXMin;
 |           done:= TRUE;
 |       ELSE
 |           INC(index);
 |           IF (index > MaxIndex) THEN
 |      	       done:= TRUE;
 |           END;
 |       END;
 |    UNTIL done;
 |    VertSlide:= index*(BaseCharacterHeight+VerticalGap);
 |
 |    RETURN(VertSlide);
 |        
 |END SlideVerticalEdge;
 |
 *)


(*--------------------------------------------------------------------------*)
        (*  
            CalcVerticalSpacing
            
            Calculates SnetHeight Spacing Vertically          
         *)
         
PROCEDURE CalcVerticalSpacing();

VAR 
    row,
    LastRowHeight,
    RowHeight : INTEGER;

BEGIN    

    LastRowHeight:= VERTMARGIN + TotalBottomHeight DIV (RealCharacterHeight+RealVerticalGap);
    FOR row:= SnetRows TO SnetRowOne BY -1 DO
        IF (SnetHeight^[row] = (BoxHeight+1)) THEN
            RowHeight := ORD(TLGSBoxHeight)+BaseCharacterHeight;
        ELSIF (SnetHeight^[row] = MasterTaskHeight) THEN
       	    RowHeight := BaseCharacterHeight*2; 
        ELSE
       	    RowHeight := BaseCharacterHeight;
        END;
        SnetHeight^[row]:= LastRowHeight;
        LastRowHeight:= LastRowHeight + RowHeight;
    END;
    DrawingYMax:= LastRowHeight;

END CalcVerticalSpacing;


(*--------------------------------------------------------------------------*)
        (*  
            CalcHorizontalSpacing
            
            Calculates SnetWidth Spacing Horizontally          
         
         *)
         
PROCEDURE CalcHorizontalSpacing() : CARDINAL;

CONST
    MAXINTEGER = 32768.0;

VAR 
    CheckDrawingWidth : REAL;
    col,
    MaxCols           : CARDINAL;
    SaveLast,
    SaveThis          : INTEGER;
    BailOut           : BOOLEAN;

BEGIN
    
    IF (SnetWidth^[SnetColOne] = BoxWidth) THEN
    	SaveLast := TLGSBoxWidth;
    ELSE  
        SaveLast:= NormalPipeWidth;
    END;
    
    SnetWidth^[SnetColOne]:= HorizOffset;
    col := SnetColOne;
    BailOut := FALSE;
    
    LOOP (* loop from SnetColOne+1 to SnetCols or until chart too big *)
        INC(col);
        IF (col > ORD(SnetCols)) THEN
            MaxCols := SnetCols; 
            EXIT;
        END;
        IF (SnetWidth^[col] = BoxWidth) THEN
   	    SaveThis:= TLGSBoxWidth;
        ELSE
            SaveThis:= NormalPipeWidth;
        END;
        CheckDrawingWidth := FLOAT(SnetWidth^[col-1]+SaveLast);
        IF (CheckDrawingWidth < MAXINTEGER) THEN
            SnetWidth^[col] := TRUNC(CheckDrawingWidth);
        ELSE
            MaxCols := col;
            BailOut := TRUE;
            EXIT;
        END; 
        SaveLast := SaveThis;
    END; (*loop*)
    IF (BailOut) THEN
        LastColPosition := SnetWidth^[MaxCols-1] + SaveLast + HORIZMARGIN;
    ELSE
        LastColPosition:= SnetWidth^[MaxCols] + SaveLast + HORIZMARGIN;
    END;
    
    RETURN(MaxCols);

END CalcHorizontalSpacing;


(*--------------------------------------------------------------------------*)
        (*  
            CountPriorLines
            
         *)
         
PROCEDURE CountPriorLines() : CARDINAL;

VAR 
    col,
    PriorLines : CARDINAL;
    done       : BOOLEAN;

BEGIN

    col:= SnetColOne;
    PriorLines:= 0;
    done:= FALSE;
    REPEAT
        IF (SnetWidth^[col] = BoxWidth) THEN
   	    done:=TRUE;
   	ELSE
     	    INC(PriorLines);
        END;
        INC(col);
    UNTIL ((done) OR (col = ORD(SnetCols)));
    
    RETURN(PriorLines);
    
END CountPriorLines;


(*--------------------------------------------------------------------------*)
        (*  
            BeginNodeCharts
            
         *)
         
PROCEDURE BeginNodeCharts() : BOOLEAN;

VAR
    i, j,
    TimescaleBy, 
    TimescaleMode,
    PriorLines,
    MaxLegendHeight,
    MaxCols             : CARDINAL;
    ChartWidthOkay,
    HaveLegendCrate,
    UsingFilters        : BOOLEAN;
    s                   : ARRAY [0..255] OF CHAR;

BEGIN

    LastColPosition:=0;
    LastRowPosition:=0;
    GetBoxSize(NetworkDiagramLayout);			
    InitSnetHandW();
    
    InitCrateArrangement(LegendBox);
    HaveLegendCrate := FALSE;
    FOR j := 1 TO FIELDCOUNT DO
        IF (CrateLayout[j,EXISTENCE] = 1) THEN
            HaveLegendCrate := TRUE;
        END;
    END;
    IF ((HighlightFilter[3] <> NIL) OR
        (HighlightFilter[4] <> NIL) OR
        (HighlightFilter[5] <> NIL)) THEN
         UsingFilters := TRUE;
    ELSE
         UsingFilters := FALSE;
    END;
    IF (UsingFilters) THEN
        MaxLegendHeight := (RealCharacterHeight+RealVerticalGap)*3;
    ELSE
        MaxLegendHeight := 0;
    END;
    IF (HaveLegendCrate) THEN
        MaxLegendHeight := MaxLegendHeight + 
                   ORD(TLGSBoxHeight+1)*(RealCharacterHeight+RealVerticalGap);
    END;
    BorderSizeCalc(MaxLegendHeight,TotalTopHeight,TotalBottomHeight);   
    TotalBottomHeight:= TotalBottomHeight+VERTMARGIN*(RealCharacterHeight+RealVerticalGap);
    TotalTopHeight:= TotalTopHeight+VERTMARGIN*(RealCharacterHeight+RealVerticalGap);

 (* build the chart descriptions, write the data into the interface files *)
   
    AxisLength:= 0;
    AxisHeight:= 0;
    HorizOffset:= HORIZMARGIN*2;
    IF (TimeScaleNetwork) THEN 
        MaxCols := AddTimescaling(Pass);
        CalcVerticalSpacing();
    ELSE (* compact network or tree *)
         MaxCols := CalcHorizontalSpacing();
         CalcVerticalSpacing();
    END;
    TotalTopHeight    := TotalTopHeight + AxisHeight;
    
    IF (MaxCols = ORD(SnetCols)) THEN 
        ChartWidthOkay := TRUE;
    ELSE
        ChartWidthOkay := FALSE;
        GetMessage (ModuleNumber+29, s);    (*  "The chart is too wide..." *)
        Error (s);                          (* 11/15/89 *)
    END;
    RETURN (ChartWidthOkay);
    
END BeginNodeCharts;


(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            SetUpSlideAmount
 |            
 |         *)
 |         
 |PROCEDURE SetUpSlideAmount();
 |
 |VAR  
 |    VertSlide,
 |    MaxVertSlide,
 |    row, col,i    : CARDINAL;
 |    cell          : INTEGER;
 |    SeeChildren   : BOOLEAN;
 |    TaskType 	  : DiagramTask;
 |
 |BEGIN
 |    
 | (* set up slide amount for duration bar networks *)
 |    FOR row:= SnetRows TO SnetRowOne BY -1 DO
 |     (* clear duration bar variables *)
 |        MaxVertSlide:= 0;
 |        FOR i:= 1 TO 16 DO
 |            VertDBPlacement[i]:= MAXCARDINAL;
 |        END;    
 |     (* look at the row column after column *)
 |        FOR col := SnetCols TO SnetColOne BY -1 DO
 |            cell:= GetCellInfo(row,col);
 |            IF (cell > 0) (* task *) THEN
 |                TaskType := MasterTaskCheck(cell);
 |                SeeChildren := loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell]);
 |                IF ((TaskType = normal) OR 
 |                   ((TaskType = master) AND (NOT SeeChildren))) THEN  
 |                     VertSlide:= SlideVerticalEdge(cell);
 |    	             IF (MaxVertSlide < VertSlide) THEN
 |      		         MaxVertSlide:= VertSlide;
 |   		     END;
 |                END;
 |            END;
 |        END; (* for col...*)
 |        IF (MaxVertSlide > 0) THEN
 |            MaxVertSlide:= MaxVertSlide + BaseCharacterHeight + VerticalGap; 
 |        END;
 |      	AccumulatedSlide:= AccumulatedSlide + MaxVertSlide;
 |        SlideAmount[row]:= MaxVertSlide; 
 |        SnetHeight^[row]:= ORD(SnetHeight^[row]) + AccumulatedSlide;
 |    END; (* for row...*)
 |    DrawingYMax:= ORD(DrawingYMax) + AccumulatedSlide;
 |    
 |END SetUpSlideAmount;
 |
 *)


(*--------------------------------------------------------------------------*)
        (*  
            WriteNodeGraphicsFile
            
         *)
PROCEDURE WriteNodeGraphicsFile();

VAR 
    DrawingXMax,
    TopBorder,
    BottomBorder,
    LeftBorder,
    RightBorder, 
    ImageY           : REAL;
    X, Y,
    j, 
    CrateFrame,
    FrameOutlineType,
    FGCrateFrameColor,
    BGCrateFrameColor,
    height,
    VertSlide,
    MaxLegendHeight  : CARDINAL;
    cell	     : INTEGER;
    okay,
    SeeChildren,
    HaveLegendCrate,
    UsingFilters,
    ChartWidthOkay   : BOOLEAN;    
    TaskType 	     : DiagramTask;
    task             : ATaskPtr;
    s                : ARRAY [0..255] OF CHAR;
    PageDescription  : ATLGSPageRecordPtr;

BEGIN
       
 (* chart type *)
    WriteChartType(ChartType);

 (* initialize the node chart *)   
    InitNodeChartColors();
    Pass:= 2; (* write *)
       
 (* type of axis *)      
    IF (CompressAxis) THEN
     (* write out begin compressed axis tag *)
        SetString(s,"COMPRESSED");
        WriteToTLGSFile(s);
    ELSE
     (* object tag *)
        SetString(s,"NOCOMPRESSED");
        WriteToTLGSFile(s);
    END;
    
    ChartWidthOkay := BeginNodeCharts();
    
 (* write out end compressed axis tag *)
    IF (CompressAxis) THEN
        SetString(s,"ENDCOMPRESSED");
        WriteToTLGSFile(s);   
    END;
    
    IF (ChartWidthOkay) THEN
    
     (* for duration bar networks - not avaliable in TL version 4.0  
      |
      | AccumulatedSlide:= 0;
      | FOR row := SnetRowOne TO SnetRows DO
      |     SlideAmount[row]:= 0;
      | END;
      |    
      |(* set up slide amount for duration bar networks *)
      | IF ((ShowDurationBars) AND (ViewType = NetworkView)) THEN
      |	     SetUpSlideAmount();
      | END;
      |
      *)
     
     (* node chart data *)
        WriteNodeChartData();
        PageDescription:= TLGSPageRecord();
        WITH PageDescription^ DO
             DrawingXMax:= ImageXVirtual;
             ImageY:= ImageYVirtual;
             LeftBorder:= Border1XVirtual;   (* Left border size in SU's *)
             RightBorder:= Border2XVirtual;  (* Right border size in SU's *)
             TopBorder:= Border1YVirtual;    (* Top border size in SU's *)
             BottomBorder:= Border2YVirtual; (* Bottom border size in SU's *)
        END;
 
     (* drawing width *)
        DrawingXMax :=  DrawingXMax * DrawingScale;
 
     (* drawing height *)
        ImageY := ImageY*DrawingScale;
 
     (* borders *)
        TopBorder    := TopBorder*DrawingScale;
        BottomBorder := BottomBorder*DrawingScale;
        LeftBorder   := LeftBorder*DrawingScale;
        RightBorder  := RightBorder*DrawingScale;

        WriteReal(ImageY);                (* drawing height *)
        WriteReal(DrawingXMax);           (* drawing width *)
        WriteReal(TopBorder);             (* top border height *)
        WriteReal(BottomBorder);          (* bottom border height *)
        WriteReal(LeftBorder);            (* left border width *)
        WriteReal(RightBorder);           (* right border width *)
    
        WriteReal(DrawingScale*100.0);    (* drawing scale *)

     (* no border repeat in networks or trees *)
        WriteBoolean(FALSE);			
    
     (* preview on screen first *)
        WriteBoolean(PageDescription^.Preview);	
    
     (* drawing mode *)
        IF (PageDescription^.GraphStyle = DraftQ) THEN
            WriteBoolean(FALSE);			
        ELSE (* = PresentationQ *)
            WriteBoolean(TRUE);			
        END;
    
     (* write device information *)
        WriteDeviceInformation();
    
     (* axis *)
        IF (TimeScaleNetwork) THEN 
            SetString(s,"AXIS");
            WriteToTLGSFile(s);
            WriteScaleDates();
            SaveCalendar;
        ELSE
         (* object tag *)
            SetString(s,"NOAXIS");
            WriteToTLGSFile(s);
        END;
        WriteCardinal(AxisLength);
        WriteCardinal(AxisHeight);

     (* crate arrangemet *)
        InitCrateArrangement(TaskBox);
        WriteArrangement();
    
     (* write filter selections *)
        WriteFilterSelections();
    
     (* write color selections *)
        WriteColorSelections();
    
     (* chart annotation *)  
        InitCrateArrangement(LegendBox);
        HaveLegendCrate := FALSE;
        FOR j := 1 TO FIELDCOUNT DO
            IF (CrateLayout[j,EXISTENCE] = 1) THEN
                HaveLegendCrate := TRUE;
            END;
        END;
        IF ((HighlightFilter[3] <> NIL) OR
            (HighlightFilter[4] <> NIL) OR
            (HighlightFilter[5] <> NIL)) THEN
             UsingFilters := TRUE;
        ELSE
             UsingFilters := FALSE;
        END;
        IF (UsingFilters) THEN
            MaxLegendHeight := (RealCharacterHeight + RealVerticalGap) * 3;
        ELSE
            MaxLegendHeight := 0;
        END;
        IF (HaveLegendCrate) THEN
            MaxLegendHeight := MaxLegendHeight + 
                       ORD(TLGSBoxHeight+1)*(RealCharacterHeight+RealVerticalGap);
        END;
        NotateAChart(MaxLegendHeight);
        IF (CheckForLegend()) THEN 
            WriteLegend();
        END;

     (* pipes *)
        IF (ShowDependencyLines) THEN
            PipeGap := BaseCharacterWidth DIV 2;
            WriteVertPipes();
            WriteHorizPipes();
        END;
   
     (* crates and master opens *)
        FOR cell:= 1 TO maxtask DO
            TaskType := MasterTaskCheck(cell);
            SeeChildren := loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell]);
            CrateFrame:= GetFrame();
            task := loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
            IF (task^.duration > NoDuration) THEN
                FrameOutlineType := GetOutlineType(cell);
                IF ((FrameOutlineType = STARTPHANTOM) OR
                    (FrameOutlineType = ENDPHANTOM)) THEN
                     FGCrateFrameColor:= MTOpenLineColor;
                ELSE
                     FGCrateFrameColor:= NormalCrateFrameColor;
                END;
            ELSE (* milestone crate *)
                FGCrateFrameColor:= MilestoneCrateFrameColor;
            END;
            loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
            BGCrateFrameColor:= NormalCrateBGColor;
            GetFGColor(FGCrateFrameColor,BGCrateFrameColor,loopnode^[cell]); (* crate frame color *)
            IF ((ViewType = NetworkView) AND 
                (NetworkType = Outline) AND   (* 24-Jul-89 CMH *)
                (TaskType = master) AND
                (NOT HaveInfLoop) AND          (* 9/28/89 EGK *)
                (SeeChildren)) THEN (* draw a master open *)
                 IF (Utility[cell] > 0) THEN  (* don't want the phantom *)
                     IF (MasterTaskInRange(cell)) THEN
                         WriteMasterOpen(Ypos[cell],Xpos[cell],cell);
                     END;
                 END;
            ELSE (* draw a crate *)
                 IF (TaskInRange(cell)) THEN
                     X:= ORD(SnetWidth^[Xpos[cell]]);
                     Y:= GetY(Ypos[cell])+BaseCharacterHeight;
                     WriteCrate(X, Y,
                                X+ORD(TLGSBoxWidth), Y+ORD(TLGSBoxHeight),
                                CrateFrame, 
                                FGCrateFrameColor, BGCrateFrameColor,
                                cell, TASKVALUE);
                 END;
            END;
        END; (* for *)
    ELSE
        PackageOK := FALSE;
    END;
    
END WriteNodeGraphicsFile;



(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |(*--------------------------------------------------------------------------*)
 |        (*  
 |            BuildNodeCharts
 |            
 |            TLGS network diagram.
 |         *)
 |         
 |PROCEDURE BuildNodeCharts();
 |
 |VAR 
 |    row : CARDINAL;  
 |
 |BEGIN
 |
 | (* calculate accumulated slide for duration bar charts *)
 |    AccumulatedSlide:= 0;
 |    FOR row := SnetRowOne TO SnetRows DO
 |        SlideAmount[row]:= 0;
 |    END;
 |    
 | (* set up slide amount for duration bar networks *)
 |    IF ((ShowDurationBars) AND (ViewType = NetworkView)) THEN
 |	 SetUpSlideAmount();
 |    END;
 |
 |END BuildNodeCharts;
 |
*)


(*--------------------------------------------------------------------------*)
        (*  
            TLGSNodeCharts
            
            Main procedure for TLGS Node Charts, tree and network.
         *)
         
PROCEDURE TLGSNodeCharts();

VAR
    DrawingY          : REAL;
    PageDescription   : ATLGSPageRecordPtr;
    ChartWidthOkay,
    Found             : BOOLEAN;

BEGIN 

 (* initialize the node chart *)   
    Pass:= 1; (* calculate *)
    ChartWidthOkay := BeginNodeCharts();
    IF (ChartWidthOkay) THEN
    
        InitCrateArrangement(TaskBox);

     (* for duration bar networks - not avaliable in TL version 4.0  
      |
      |(* determine drawing size of the node chart *)
      |   BuildNodeCharts();
      |  
      *)
 
        DrawingY := FLOAT(ORD(DrawingYMax) + BaseCharacterHeight + VerticalGap);
    	   			   
        PageDescription:= TLGSPageRecord();
        WITH PageDescription^ DO
             IF (TimeScaleNetwork) THEN 
                 ImageXVirtual:= FLOAT(AxisLength) *     (* 24-Aug-89 LAA *)
                                 FLOAT(RealCharacterWidth);
             ELSE
                 ImageXVirtual:= FLOAT(LastColPosition) *
                                 FLOAT(RealCharacterWidth);
             END;
         
             ImageYVirtual:= (DrawingY*FLOAT(RealCharacterHeight+RealVerticalGap)-
                              FLOAT(TotalBottomHeight));
    	 
          (* Left border size in SU's *)
             Border1XVirtual:= FLOAT(HORIZMARGIN) *
                               FLOAT(RealCharacterWidth);
   	 
          (* Right border size in SU's *)
   	     Border2XVirtual:= FLOAT(HORIZMARGIN) * 
                               FLOAT(RealCharacterWidth); 
         
          (* Top border size in SU's *)
             Border1YVirtual:= FLOAT(TotalTopHeight);                      
         
          (* Bottom border size in SU's *)
             Border2YVirtual:= FLOAT(TotalBottomHeight);                   
           
        END;
    ELSE
        PackageOK := FALSE;
    END;

END TLGSNodeCharts;

(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDPert *)

    
END TSEDPert.

