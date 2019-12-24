 IMPLEMENTATION MODULE TSEDGantt;

    (*  MODIFICATION HISTORY
    07-Feb-89 LAA/CMH Made formatting of column types a little more
                    correct.  Have to be changed later when we merge
                    this into Lazlo.
     6-Jul-89 CMH   Changed retriving of percent achieved data to
                    use QueryPctComplete procedure.
    09-Jul-89 CMH   Corrected number of characters passed through
                    intermediate file for dates.
	10-Jul-89 CMH   Fixed bar labels passing through too many
        			characters for text strings.
    18-Jul-89 CMH   Eliminated plus signs from task names of closed
                    summaries.
     2-Aug-89 CMH   Fixed bar label bugs.
     6-Sep-89 CMH   Moved GanttTimescaling and GetDurationBarDates 
                    from TSEDTimescale to GanttTimescale.
     8-Sep-89 CMH   Using new WriteBoolean, WriteCardinal, WriteReal
                    procedures.
                    Renamed APageDescription variable to 
                    PageDescription. 
    19-Sep-89 CMH   Changed task parent flag to indicate whether or not
                    to use the summary color for text and bars.  Only
                    want to use summary color when parent and children
                    visible. Changed formating of task names, for plus
                    signs again.
    16-Oct-89 CMH   Trimming leading blanks from column cap names for
                    centering.
    23-Oct-89 CMH   Add a leading blank space in the first data column
                    for pipe system space when using round corners.
                    Make all columns one character wider.
                    Remove leading blanks from all columns excect 
                    task name.
                    No longer using TrimRear for data column values.
    24-Oct-89 CMH   If border repeat and user selected more columns 
                    than will fit on one page then set bar origin
                    to one page.
    21-Nov-89 CMH   Added new procedure GetBarLabelCounts. 
    29-Nov-89 CMH   Bumped up the delta for number of pages in 
                    rounding from 0.0 to 0.01 .
    19-Dec-89 CMH   Fixed above bar label not drawing bug. 
    21-Dec-89 CMH   Trim blanks for data column info. 
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
     6-Aug-90 RSC   Changed reference to TaskFlags to TempTaskFlags.
    23-Sep-90 PHR   Write drawing scale as a real.
    12-Nov-90 TGS   Merge changes made to 4.03.
     5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  GetColumnInfo, GetColumnString;

FROM ColorTLGS              IMPORT
    (* PROC *)			WriteColorSelections,
                                WriteFilterSelections;

FROM DataGantt		    IMPORT
    (* CONST *)	                LEFTOFBAR,
    				RIGHTOFBAR,
    				TOPOFBAR,
    				BOTTOMOFBAR,
    (* VAR *)		        BarLabel1ID,
                                BarLabel2ID,
                                BarLabel3ID,
                                BarLabel4ID,
                                BarLabel1Width,
                                BarLabel2Width,
                                BarLabel3Width,
                                BarLabel4Width,
                                BarLabel1Pos,
                                BarLabel2Pos,
                                BarLabel3Pos,
                                BarLabel4Pos,
                   		NumberOfLabels,
                   		LeftBarLabelSize,
                   		RightBarLabelSize,
                   		TopBarLabelSize,
                   		BottomBarLabelSize,
			        ShowGanttArea,
			        ExtraSpaceOnGantt,
			        ExtraSpaceLevel,
                                GanttChartLayout,
                                FrameCornerStyle,
    			        WriteGanttChartData;
    
  (* <DEBUGGING> 
FROM Dialog		    IMPORT
    (* PROC *)		       	Error;
FROM ErrorUtil		    IMPORT
    (* PROC *)		        PrintSMsg, PrintSCard;
     <DEBUGGING> *)

FROM FilterRc		    IMPORT
    (* VAR *)                   HighlightFilter;
    
FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM GanttOptions           IMPORT
    (* PROC *)                  QueryPctComplete;
    
FROM GanttTimescale	    IMPORT
    (* PROC *)			GanttTimescaling,
    				GetDurationBarDates; 
    			 	
FROM IlsaStatic             IMPORT
    (* TYPE *)      		ATLGSPageRecord,
                                ATLGSSetupRecord,
                                ATLGSCorner,
    	                        ATLGSPageRecordPtr,
    	                        ATLGSSetupRecordPtr,
                		AGraphStyle,
                		ATLGSPosition,
    (* PROC *)	                TLGSSetupRecord,
                		TLGSPageRecord;

FROM Indentation            IMPORT
    (* PROC *)                  SpacesPerLevel;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatLS, ConcatS, Copy, Fill, 
                                Insert, LJust, 
    				Search, SetString, 
    				TrimFront, TrimRear;

FROM NetCharacters     	    IMPORT
    (* CONST *)                 blank;
    
FROM Phantoms     	    IMPORT
    (* CONST *)                 SummaryFlag;
                                
FROM TaskColNumbers     IMPORT
    (* CONST *)                 TaskNameColumn;

FROM Timei		    IMPORT
    (* TYPE *)			ADate, ADuration;
    
FROM TSEDData		    IMPORT
    (* CONST *)			SINGLELINE,
    				TEXTLEFT,
                                MAXCARDINAL,
    				DATE,
    				NUMERICONLY,
    				NUMERICANDTEXT,
    (* VAR *)			ChartType,
    			 	BaseCharacterWidth,
    			        BaseCharacterHeight,
    			 	RealCharacterWidth,     
    				RealCharacterHeight,
    				VerticalGap,
    				RealVerticalGap,
			        DrawingScale,
    (* PROC *)			GetDataJustification,
    				ShowThisTask;

FROM TSEDNotation	    IMPORT
    (* PROC *)			BorderSizeCalc, NotateAChart;
    
FROM TSEDObjectWrite	    IMPORT
    (* PROC *)			WriteBoolean,
                                WriteBox,
                                WriteCardinal,
                     	 	WriteChartType,
                     	 	WriteDeviceInformation,
                     	 	WriteReal,
    				WriteText;
    				
FROM TSEDTimescale	    IMPORT
    (* VAR *)			AxisLength,
    				AxisHeight,
    (* PROC *)                  SaveCalendar,
    				WriteScaleDates;
 
FROM TSEDWrite		    IMPORT
    (* PROC *)                 	WriteToTLGSFile;
    
FROM SYSTEM                 IMPORT 
    (* TYPE *)			ADDRESS;
    
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;


CONST
    MARGIN = 2;
    
VAR
   MaxTask,
   NumberOfChannels,
   FirstColumnWidth,   
   BarOrigin 	    : CARDINAL; 
   BarLabelAbove,
   BarLabelBelow    : BOOLEAN;


(*--------------------------------------------------------------------------*)
   
        (*  
            GetFilterSetting
            
            Returns the filter setting for the input task;
            
         *)
  
PROCEDURE GetFilterSetting(TaskTreeNode : ATreeNode) : CARDINAL; 

CONST
 (* filters *) 
    NONE = 0;
    HL1  = 1;
    HL2  = 2;
    HL3  = 3;
    HL4  = 4;
    HL5  = 5;
    SEL  = 6;
                                
VAR
    FilterSetting  : CARDINAL;
    filter : ATaskFilterSet;
    task   : ATaskPtr; 

BEGIN
 
 (* get the filter set for this task *)
   
    task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    filter:= task^.FilterSet;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

 (* determine the FilterSetting *)
    FilterSetting:= NONE;
    IF Highlight1 IN filter THEN
      FilterSetting:= HL1;
    ELSIF Highlight2 IN filter THEN 
      FilterSetting:= HL2;
    ELSIF Highlight3 IN filter THEN 
      FilterSetting:= HL3;
    ELSIF Highlight4 IN filter THEN 
       FilterSetting:= HL4;
    ELSIF Highlight5 IN filter THEN 
       FilterSetting:= HL5;
    END; 
    IF NOT (Selected IN filter) THEN 
       FilterSetting:= SEL;
    END;
      
    RETURN (FilterSetting);
    
END GetFilterSetting;


(*--------------------------------------------------------------------------*)
        (*  
            GetBarLabelCounts
         *)
         
PROCEDURE GetBarLabelCounts(BarLabelPos : ATLGSPosition;
                            BarLabelWidth : CARDINAL;
                        VAR LeftLabelCount, RightLabelCount, 
                            TopLabelCount, BottomLabelCount: CARDINAL);

BEGIN

    IF (BarLabelWidth > 0) THEN
        
        CASE BarLabelPos OF

             SLeft:
               LeftBarLabelSize := LeftBarLabelSize + BarLabelWidth;
               INC(LeftLabelCount);
             
           | SRight:
               RightBarLabelSize := RightBarLabelSize + BarLabelWidth;
               INC(RightLabelCount);
             
           | SAbove:
               TopBarLabelSize := TopBarLabelSize + BarLabelWidth;
               INC(TopLabelCount);
               BarLabelAbove := TRUE;

           | SBelow:
               BottomBarLabelSize := BottomBarLabelSize + BarLabelWidth;
               INC(BottomLabelCount);
               BarLabelBelow := TRUE;
      
       END;  (* case *)     
   
    END; (* bar label *)

END GetBarLabelCounts;
   

(*--------------------------------------------------------------------------*)
        (*  
            GetBarLabelSizes
         *)
         
PROCEDURE GetBarLabelSizes();

VAR
    LeftLabelCount,
    RightLabelCount,
    TopLabelCount,
    BottomLabelCount : CARDINAL;

BEGIN
    
    LeftLabelCount   := 0;
    RightLabelCount  := 0;
    TopLabelCount    := 0;
    BottomLabelCount := 0;
    
    GetBarLabelCounts(BarLabel1Pos, BarLabel1Width,
                      LeftLabelCount, RightLabelCount,
                      TopLabelCount, BottomLabelCount);
                      
    GetBarLabelCounts(BarLabel2Pos, BarLabel2Width,
                      LeftLabelCount, RightLabelCount,
                      TopLabelCount, BottomLabelCount);
                      
    GetBarLabelCounts(BarLabel3Pos, BarLabel3Width,
                      LeftLabelCount, RightLabelCount,
                      TopLabelCount, BottomLabelCount);
                      
    GetBarLabelCounts(BarLabel4Pos, BarLabel4Width,
                      LeftLabelCount, RightLabelCount,
                      TopLabelCount, BottomLabelCount);
                      
    
 (* add extra characters for a comma and blank between labels *)
    IF (LeftLabelCount > 0) THEN
        INC(NumberOfLabels);
        LeftBarLabelSize := LeftBarLabelSize + (LeftLabelCount - 1) * 2;
    END;
            
    IF (RightLabelCount > 0) THEN
        INC(NumberOfLabels);
        RightBarLabelSize := RightBarLabelSize + (RightLabelCount - 1) * 2;
    END;
            
    IF (TopLabelCount > 0) THEN
        INC(NumberOfLabels);
        TopBarLabelSize := TopBarLabelSize + (TopLabelCount - 1) * 2;
    END;
            
    IF (BottomLabelCount > 0) THEN
        INC(NumberOfLabels);
        BottomBarLabelSize := BottomBarLabelSize + (BottomLabelCount - 1) * 2;
    END;
           
END GetBarLabelSizes;


(*--------------------------------------------------------------------------*)
        (*  
            WriteBarLabels
         *)

PROCEDURE WriteBarLabels(TaskTreeNode : ATreeNode);

CONST
    MAXWIDTH = 200; 
    
VAR
    LeftLabel,
    RightLabel,
    TopLabel,
    BottomLabel,
    SubString      : ARRAY [0..255] OF CHAR;
    HaveLeft,
    HaveRight,
    HaveTop,
    HaveBottom     : BOOLEAN;
    
BEGIN

    LeftLabel[0]   := CHR(0);
    RightLabel[0]  := CHR(0);
    TopLabel[0]    := CHR(0);
    BottomLabel[0] := CHR(0);
    SubString[0]   := CHR(0);
    HaveLeft   := FALSE;
    HaveRight  := FALSE;
    HaveTop    := FALSE;
    HaveBottom := FALSE;
    
    IF (BarLabel1Width > 0) THEN
        GetLabel(TaskTreeNode,BarLabel1Width,BarLabel1ID,SubString);
        CASE BarLabel1Pos OF
             SLeft:  ConcatLS(LeftLabel,SubString);
                     HaveLeft := TRUE;
           | SRight: ConcatLS(RightLabel,SubString);
                     HaveRight := TRUE;
           | SAbove: ConcatLS(TopLabel,SubString);
                     HaveTop := TRUE;
           | SBelow: ConcatLS(BottomLabel,SubString);
                     HaveBottom := TRUE;
        END;
    END;
    IF (BarLabel2Width > 0) THEN
        GetLabel(TaskTreeNode,BarLabel2Width,BarLabel2ID,SubString);
        CASE BarLabel2Pos OF
             SLeft:  IF (HaveLeft) THEN
                         ConcatS(LeftLabel,", ");
                     END;
                     HaveLeft := TRUE;
                     ConcatLS(LeftLabel,SubString);
           | SRight: 
                    IF (HaveRight) THEN
                        ConcatS(RightLabel,", ");
                     END;
                     HaveRight :=TRUE;
                     ConcatLS(RightLabel,SubString);
           | SAbove: 
                    IF (HaveTop) THEN
                        ConcatS(TopLabel,", ");
                     END;
                     HaveTop :=TRUE;
                     ConcatLS(TopLabel,SubString);
           | SBelow: 
                    IF (HaveBottom) THEN
                        ConcatS(BottomLabel,", ");
                     END;
                     HaveBottom :=TRUE;
                     ConcatLS(BottomLabel,SubString);
        END;
    END;
    IF (BarLabel3Width> 0) THEN
        GetLabel(TaskTreeNode,BarLabel3Width,BarLabel3ID,SubString);
        CASE BarLabel3Pos OF
             SLeft:  IF (HaveLeft) THEN
                         ConcatS(LeftLabel,", ");
                     END;
                     HaveLeft := TRUE;
                     ConcatLS(LeftLabel,SubString);
           | SRight: 
                    IF (HaveRight) THEN
                        ConcatS(RightLabel,", ");
                     END;
                     HaveRight :=TRUE;
                     ConcatLS(RightLabel,SubString);
           | SAbove: 
                    IF (HaveTop) THEN
                        ConcatS(TopLabel,", ");
                     END;
                     HaveTop :=TRUE;
                     ConcatLS(TopLabel,SubString);
           | SBelow: 
                    IF (HaveBottom) THEN
                        ConcatS(BottomLabel,", ");
                     END;
                     HaveBottom :=TRUE;
                     ConcatLS(BottomLabel,SubString);
        END;
    END;
    IF (BarLabel4Width > 0) THEN
        GetLabel(TaskTreeNode,BarLabel4Width,BarLabel4ID,SubString);
        CASE BarLabel4Pos OF
             SLeft:  IF (HaveLeft) THEN
                         ConcatS(LeftLabel,", ");
                     END;
                     HaveLeft := TRUE;
                     ConcatLS(LeftLabel,SubString);
           | SRight: 
                    IF (HaveRight) THEN
                        ConcatS(RightLabel,", ");
                     END;
                     HaveRight :=TRUE;
                     ConcatLS(RightLabel,SubString);
           | SAbove: 
                    IF (HaveTop) THEN
                        ConcatS(TopLabel,", ");
                     END;
                     HaveTop :=TRUE;
                     ConcatLS(TopLabel,SubString);
           | SBelow: 
                    IF (HaveBottom) THEN
                        ConcatS(BottomLabel,", ");
                     END;
                     HaveBottom :=TRUE;
                     ConcatLS(BottomLabel,SubString);
        END;
    END;
    
    IF (HaveLeft) THEN
        IF (ORD(LeftLabel[0]) > MAXWIDTH) THEN
            LeftLabel[0] := CHR(MAXWIDTH);
        END;
        WriteText(LeftLabel,0,0);
    END;
    IF (HaveRight) THEN
        IF (ORD(RightLabel[0]) > MAXWIDTH) THEN
            RightLabel[0] := CHR(MAXWIDTH);
        END;
        WriteText(RightLabel,0,0);
    END;
    IF (HaveTop) THEN
        IF (ORD(TopLabel[0]) > MAXWIDTH) THEN
            TopLabel[0] := CHR(MAXWIDTH);
        END;
        WriteText(TopLabel,0,0);
    END;
    IF (HaveBottom) THEN
        IF (ORD(BottomLabel[0]) > MAXWIDTH) THEN
            BottomLabel[0] := CHR(MAXWIDTH);
        END;
        WriteText(BottomLabel,0,0);
    END;
      
END WriteBarLabels;


(*--------------------------------------------------------------------------*)
        (*  
            GetBarOrigin
         *)

PROCEDURE  GetBarOrigin();

VAR
    PageDescription  : ATLGSPageRecordPtr;
    SetupDescription : ATLGSSetupRecordPtr;
    i,
    ExtraSpace,
    columns          : CARDINAL;
    
BEGIN
    
    BarOrigin        := 0;
    FirstColumnWidth := 0;
    columns          := GanttChartLayout^.ColumnCount;
    
    IF (columns > 0) THEN
    
        FOR i := 1 TO columns DO
            IF ((FrameCornerStyle = Round) AND (i = 1)) THEN 
                 ExtraSpace := 2;  (* 23-Oct-89 CMH *)
            ELSE
                 ExtraSpace := 1; 
            END;
            BarOrigin := BarOrigin + (GanttChartLayout^.ColumnSpec[i].Width +
                                      ExtraSpace) * BaseCharacterWidth;
            IF (i = 1) THEN
                FirstColumnWidth := (GanttChartLayout^.ColumnSpec[i].Width + 
                                     ExtraSpace) * BaseCharacterWidth;
            END;
        END;
        
        PageDescription := TLGSPageRecord();
        IF (PageDescription^.Borders) THEN  (* border repeat *)
            SetupDescription := TLGSSetupRecord();
            IF ((BarOrigin*RealCharacterWidth) > 
                (TRUNC(SetupDescription^.PlotAreaWide))) THEN
                BarOrigin := TRUNC(SetupDescription^.PlotAreaWide / 
                             FLOAT(RealCharacterWidth)) - 
                             MARGIN * 2;  (* 24-Oct-89 CMH *)
            END;
        END;
   
    END;
    
END GetBarOrigin;
     
            
(*--------------------------------------------------------------------------*)
        (*  
            GetLabel
         *)

PROCEDURE GetLabel(TaskTreeNode : ATreeNode; 
                   Width, ColumnId : CARDINAL;
               VAR s : ARRAY OF CHAR);

CONST
    MAXWIDTH = 75;
    
VAR
    index,
    DataWidth         : CARDINAL; 
    task              : ATaskPtr;
    DataRecord        : AColumnDataRecord;
    Found             : BOOLEAN;
    PlusSign          : ARRAY [0..1] OF CHAR;
    
BEGIN

    SetString(PlusSign,"+");

 (* get column data type - text, numeric, or date*)
    task := NIL;
    GetColumnInfo(NIL, task, ColumnId,
                  ColumnDataType, 0, DataRecord);

 (* if equal spacing send out the exact length
       else send out full string length *)
    CASE (GetDataJustification(DataRecord.CardinalValue)) OF
          DATE, NUMERICONLY :
          DataWidth:= Width;
    ELSE (* TEXTLEFT, NUMERICANDTEXT *)
          DataWidth:= MAXWIDTH;
    END;

 (* column value *)
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    Found := GetColumnString(TaskTreeNode, task,
                             ColumnId,
                             Plan,
                             DataWidth,
                             s);
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    TrimFront(s);
    index := Search(s,PlusSign,0);
    IF (index = 1) THEN
        s[index] := blank;
    END;
    TrimFront(s);
    TrimRear(s);
    IF (ORD(s[0]) > Width) THEN
        s[0] := CHR(Width);
    END;

END GetLabel;


(*--------------------------------------------------------------------------*)
        (*
            WriteColumnHeadings
         *)

PROCEDURE WriteColumnHeadings();

CONST
    MAXFIELDWIDTH = 80;
VAR
    ExtraSpace,
    i, j,
    x1,x2,
    y1,y2,
    columns,
    NotUsed,
    DataJustification : CARDINAL;
    task              : ATaskPtr;
    TaskTreeNode      : ATreeNode;
    s                 : ARRAY [0..255] OF CHAR;
    TempReal          : REAL;
    T                 : ATaskPtr;
    DataRecord        : AColumnDataRecord;
    
BEGIN
    
    NotUsed := 0;
    columns:= 0;
 
 (* find out how many columns to draw *)  
    FOR i := 1 TO GanttChartLayout^.ColumnCount DO
        IF (GanttChartLayout^.ColumnSpec[i].Width > 0) THEN
            INC(columns);
        END;
    END;
       
 (* write out cap object tag *)
    SetString(s,"CAP");      
    WriteToTLGSFile(s);

 (* write out number of caps *)
    WriteCardinal(columns);      
        
 (* write out number of boxes/names within each cap *)
    WriteCardinal(2);      
        
    TaskTreeNode:= TaskTree^.Methods^.GetFirst(TaskTree);
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    
 (* get the data column headings *)   
    FOR i := 1 TO GanttChartLayout^.ColumnCount DO
 
        IF (GanttChartLayout^.ColumnSpec[i].Width > 0) THEN
 
         (* get column data type - text, numeric, or date*) 
            T := NIL;
            GetColumnInfo(NIL, T, GanttChartLayout^.ColumnSpec[i].ColumnID,
                          ColumnDataType, 0, DataRecord);
            DataJustification:= GetDataJustification(DataRecord.CardinalValue);

         (* column heading 1 *)
            GetColumnInfo(TaskTreeNode, task,
                      GanttChartLayout^.ColumnSpec[i].ColumnID,
                      ColumnHeading1,
                      GanttChartLayout^.ColumnSpec[i].Width,
                      DataRecord);
            Copy(DataRecord.StringValue, s);
            TrimFront(s);
            TrimRear(s);

         (* cap heading box 1 *)  
            x1:= 0;
            IF ((FrameCornerStyle = Round) AND (i = 1)) THEN 
                 ExtraSpace := 2;  (* 23-Oct-89 CMH *)
            ELSE
                 ExtraSpace := 1; 
            END;
            x2:= (GanttChartLayout^.ColumnSpec[i].Width + ExtraSpace) * BaseCharacterWidth;
            y1:= RealCharacterHeight + RealVerticalGap;
            y2:= (RealCharacterHeight + RealVerticalGap)*2;

         (* write column cap heading 1 *)        
            WriteBox(x1, y1, x2, y2, SINGLELINE, s, NotUsed, NotUsed);
            WriteCardinal(DataJustification);
        
         (* column heading 2 *)
            GetColumnInfo(TaskTreeNode, task,
                      GanttChartLayout^.ColumnSpec[i].ColumnID,
                      ColumnHeading2,
                      GanttChartLayout^.ColumnSpec[i].Width,
                      DataRecord);
            Copy(DataRecord.StringValue, s);
            TrimFront(s);
            TrimRear(s);

         (* cap heading box 2 *)  
            y1:= 0;
            y2:= RealCharacterHeight + RealVerticalGap;
            
         (* write column cap heading 2 *)        
            WriteBox(x1, y1, x2, y2, SINGLELINE, s, NotUsed, NotUsed);
            WriteCardinal(DataJustification);

        END;

    END; (* for *)
 
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

END WriteColumnHeadings;


(*--------------------------------------------------------------------------*)
        (*  
            WriteChannelValues
         *)
         
PROCEDURE WriteChannelValues(TaskTreeNode : ATreeNode);

CONST
    MAXFIELDWIDTH = 80;

VAR
    i, 
    index,
    FilterSetting,
    columns,
    DataJustification,
    DataWidth         : CARDINAL;
    T,
    task              : ATaskPtr;
    TempReal          : REAL;
    DataRecord        : AColumnDataRecord;
    Found             : BOOLEAN;
    BlankSpace,
    PlusSign          : ARRAY [0..1] OF CHAR;
    s,
    sTemp             : ARRAY [0..255] OF CHAR;
    
BEGIN

    SetString(PlusSign,"+");
    SetString(BlankSpace," ");
    
    columns:= GanttChartLayout^.ColumnCount;
  
    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
  
    FOR i := 1 TO columns DO

        IF (GanttChartLayout^.ColumnSpec[i].Width > 0) THEN

         (* get column data type - text, numeric, or date*) 
            T := NIL;
            GetColumnInfo(NIL, T, GanttChartLayout^.ColumnSpec[i].ColumnID,
                          ColumnDataType, 0, DataRecord);
            DataJustification:= GetDataJustification(DataRecord.CardinalValue);

         (* if equal spacing send out the exact length 
            else send out full string length *)
            CASE DataJustification OF
                 DATE, NUMERICONLY, NUMERICANDTEXT :
                 DataWidth:= GanttChartLayout^.ColumnSpec[i].Width - 1; 
            ELSE  (* TEXTLEFT *) 
                 DataWidth:= MAXFIELDWIDTH; 
            END;             
            
         (* column value *)   
            Found := GetColumnString(TaskTreeNode, task,
                                     GanttChartLayout^.ColumnSpec[i].ColumnID,
                                     Plan,
                                     DataWidth,
                                     s);
  
            
            IF (GanttChartLayout^.ColumnSpec[i].ColumnID  = TaskNameColumn) THEN
                LJust(s);
                index := Search(s,PlusSign,0);
                IF (index = 1) THEN
                    s[index] := blank;
                    LJust(s);
                END;
                Fill(sTemp,blank,
                     TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode)*
                     SpacesPerLevel);
                Insert(s,sTemp,1);
            END;
            IF ((FrameCornerStyle = Round) AND (i = 1)) THEN 
                 Insert(s,BlankSpace,1);  (* 23-Oct-89 CMH *)
            END;
            
            IF (DataJustification = DATE) THEN
                TrimFront(s);
                TrimRear(s);
            ELSIF (DataJustification = NUMERICONLY) THEN
                TrimFront(s);
            ELSE
                TrimRear(s);
            END;
            
         (* string *)
            WriteText(s,0,0);
            
        END;
    END; (* for *)

 (* level *)
    WriteCardinal(TaskTreeNode^.Methods^.IndentationLevel(TaskTreeNode));
      
 (* parent color *) (* 19-Sep-89 CMH *)
    WriteBoolean((SummaryFlag IN task^.TempTaskFlags) AND
                 (TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode)));
       
 (* filter *)
    FilterSetting:= GetFilterSetting(TaskTreeNode);
    WriteCardinal(FilterSetting);
  
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

END WriteChannelValues;


(*--------------------------------------------------------------------------*)

        (*  
            BreakBefore
            Should we send out an extra space before this node?  
         *)

PROCEDURE BreakBefore   (   Node    : ATreeNode )   : BOOLEAN;

VAR
    PrevNode        : ATreeNode;
    PrevTask        : ATaskPtr;
    OurLevel        : CARDINAL;

BEGIN

    IF (NOT ExtraSpaceOnGantt) THEN
        RETURN FALSE;			(* User doesn't want extra space *)
    END;

    PrevNode := Node^.Methods^.PrevForDisplay (Node);
    IF (PrevNode = NIL) THEN
        RETURN FALSE;                   (* Never skip before the first one *)
    END;

    IF (ExtraSpaceLevel > 0) THEN
        OurLevel := Node^.Methods^.IndentationLevel (Node);
        RETURN (OurLevel <= ExtraSpaceLevel - 1);
    ELSE
        RETURN FALSE;
    END;

END BreakBefore;


(*--------------------------------------------------------------------------*)
        (*  
            WriteTaskList
         *)

PROCEDURE WriteTaskList(VAR TaskTreeNode : ATreeNode;
                                Context      : ADDRESS);
VAR
    task            : ATaskPtr;
    x1Plan,
    x2Plan,
    x1Actual,
    x2Actual,
    slack	    : ADate;
    DataRecord      : AColumnDataRecord;
    complete        : CARDINAL;
    duration        : ADuration;
    s               : ARRAY [0..255] OF CHAR;
    
BEGIN

    IF (ShowThisTask(TaskTreeNode)) THEN
       IF (BreakBefore(TaskTreeNode)) THEN
           INC(NumberOfChannels);
       END;
       INC(NumberOfChannels);
       INC(MaxTask);
       
    (* task record *)    
       SetString(s,"TASK");      
       WriteToTLGSFile(s);
       WriteChannelValues(TaskTreeNode);
       GetDurationBarDates(TaskTreeNode,x1Plan,x2Plan,
                                        x1Actual,x2Actual,
                                        slack);
    (* duration *) 
       task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
       duration:= task^.duration;
       TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
       WriteCardinal(duration);

    (* x1 plan *)
       WriteCardinal(x1Plan);

    (* x2 plan *)
       WriteCardinal(x2Plan);

    (* x1 actual *)
       WriteCardinal(x1Actual); 

    (* x2 Actual *)
       WriteCardinal(x2Actual);

    (* milestone position *)
       WriteCardinal(x1Actual); 

    (* slack position *)
       WriteCardinal(slack);

    (* percent complete *)
       complete:= QueryPctComplete(TaskTreeNode);  (* 6-Jul-89 CMH *)
       WriteCardinal(complete);

    (* bar labels *)    
       SetString(s,"LABEL"); 
       WriteToTLGSFile(s);
       WriteCardinal(NumberOfLabels);
       IF (NumberOfLabels > 0) THEN
           WriteBarLabels(TaskTreeNode);
       END;
    END;
    
END WriteTaskList;    


(*--------------------------------------------------------------------------*)
        (*  
            AnalyzeTaskList
            Analyze task list to determine plot area size
         *)

PROCEDURE AnalyzeTaskList(VAR TaskTreeNode : ATreeNode;
                                Context      : ADDRESS);
VAR
    task : ATaskPtr;
    
BEGIN

 (* is this task visible ? if so, then draw it *)
    IF (ShowThisTask(TaskTreeNode)) THEN
       IF (BreakBefore(TaskTreeNode)) THEN
           INC(NumberOfChannels);
       END;
       INC(NumberOfChannels);
       INC(MaxTask);
    
    END;  
    
END AnalyzeTaskList;    


(*--------------------------------------------------------------------------*)
        (*  
            TLGSGanttCalc
            Calculates gantt chart drawing sizes for borders 
            and plot area
         *)
         
PROCEDURE TLGSGanttCalc();
VAR
    
BEGIN 

 (* analyze task information for vertical drawing height *)
    NumberOfChannels:= 0;
    MaxTask:= 0;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                     AnalyzeTaskList, NIL);
    
END TLGSGanttCalc;


(*--------------------------------------------------------------------------*)
        (*  
            WriteGanttGraphicsFile
            
            Procedure to write the TLGS Gantt charts interface file.
         *)
         
PROCEDURE WriteGanttGraphicsFile();
  
VAR
    DrawingXMax,
    DrawingYMax,
    TotalLeftWidth,
    TotalRightWidth,
    TotalTopHeight,
    TotalBottomHeight : REAL;
    PageDescription   : ATLGSPageRecordPtr;
    TempReal          : REAL;
    NumberOfXPages,
    NumberOfYPages,
    MaxLegendHeight   : CARDINAL;
    s                 : ARRAY [0..255] OF CHAR;
    DataRecord        : AColumnDataRecord;
    UsingFilters      : BOOLEAN;    

BEGIN 

    GetBarOrigin();

 (* axis *)
    AxisLength:=0;   
    AxisHeight:= 2*(RealVerticalGap+RealCharacterHeight);

 (* initialize label sizes *)  
    BarLabelAbove := FALSE;
    BarLabelBelow := FALSE;
    LeftBarLabelSize := 0;
    RightBarLabelSize := 0;
    TopBarLabelSize := 0;
    BottomBarLabelSize := 0;
    NumberOfLabels := 0;
    IF (ShowGanttArea) THEN
        GetBarLabelSizes();
        GanttTimescaling();
    END;
     
 (* chart type *)
    WriteChartType(ChartType);
 
 (* write gantt chart data selections *)
    WriteGanttChartData();

    PageDescription:= TLGSPageRecord();
    WITH PageDescription^ DO
         DrawingXMax:= ImageXVirtual;
         DrawingYMax:= ImageYVirtual;
         TotalLeftWidth:= Border1XVirtual;    (* Left border size in SU's *)
         TotalRightWidth:= Border2XVirtual;   (* Right border size in SU's *)
         TotalTopHeight:= Border1YVirtual;    (* Top border size in SU's *)
         TotalBottomHeight:= Border2YVirtual; (* Bottom border size in SU's *)
    END;
    TLGSGanttCalc();

    DrawingXMax:= DrawingXMax;
    DrawingYMax:= DrawingYMax;
    TotalTopHeight:= TotalTopHeight;
    TotalBottomHeight:= TotalBottomHeight;
    TotalLeftWidth:= TotalLeftWidth;
    TotalRightWidth:= TotalRightWidth;

    WriteReal(DrawingYMax);                 (* drawing height *)
    WriteReal(DrawingXMax);                 (* drawing width *)
    WriteReal(TotalTopHeight);              (* top border height *)
    WriteReal(TotalBottomHeight);           (* bottom border height *)
    WriteReal(TotalLeftWidth);              (* left border width *)
    WriteReal(TotalRightWidth);             (* right border width *)
    WriteReal(FLOAT(FirstColumnWidth * RealCharacterWidth)); (* first column width *)
   
    NumberOfXPages:= TRUNC(PageDescription^.PagesAcross);
    IF (PageDescription^.PagesAcross-FLOAT(NumberOfXPages) > 0.01) THEN
        INC(NumberOfXPages);
    END;
    WriteCardinal(NumberOfXPages); 		(* number of x pages *)
    
    NumberOfYPages:= TRUNC(PageDescription^.PagesDown);
    IF (PageDescription^.PagesDown-FLOAT(NumberOfYPages) > 0.01) THEN
        INC(NumberOfYPages);
    END;
    WriteCardinal(NumberOfYPages);   		(* number of y pages *)
   
    WriteBoolean(PageDescription^.Borders);    (* border repeat *)
    
    WriteBoolean(PageDescription^.Preview);    (* preview on screen first *)
    
    WriteBoolean(PageDescription^.On1Page);    (* draw on one page *)
    
    IF (PageDescription^.GraphStyle = DraftQ) THEN   (* drawing mode *)
        WriteBoolean(FALSE);			
    ELSE (* = PresentationQ *)
        WriteBoolean(TRUE);			
    END;
    
 (* bar labels existence *)
    IF (LeftBarLabelSize > 0) THEN   (* have a left label *)
        WriteBoolean(TRUE);			
    ELSE		
        WriteBoolean(FALSE);			
    END;
    
    IF (RightBarLabelSize > 0) THEN  (* have a right label *)
        WriteBoolean(TRUE);			
    ELSE		
        WriteBoolean(FALSE);			
    END;
    
    IF (TopBarLabelSize > 0) THEN    (* have a top label *)
        WriteBoolean(TRUE);			
    ELSE		
        WriteBoolean(FALSE);			
    END;
    
    IF (BottomBarLabelSize > 0) THEN (* have a bottom label *)
        WriteBoolean(TRUE);			
    ELSE		
        WriteBoolean(FALSE);			
    END;
    
 (* number of channels, tasks and blank channels *)
    WriteCardinal(NumberOfChannels);			
   
 (* drawing scale *) 
    WriteReal(DrawingScale*100.0);                     (* PHR 9/23/90 *)

 (* write number of tasks *)
    WriteCardinal(MaxTask);			
    
    
 (* write device information *)
    WriteDeviceInformation();
    
 (* axis *)
    IF (ShowGanttArea) THEN
     (* object tag *)
        SetString(s,"AXIS");
        WriteToTLGSFile(s);
        WriteScaleDates();
        SaveCalendar();
    ELSE
     (* object tag *)
        SetString(s,"NOAXIS");
        WriteToTLGSFile(s);
    END;

    WriteCardinal(AxisLength);
    WriteCardinal(AxisHeight);

 (* write filter selections *)
    WriteFilterSelections();
    
 (* write color selections *)
    WriteColorSelections();
    
 (* title and notes *)   
    IF ((HighlightFilter[3] <> NIL) OR
        (HighlightFilter[4] <> NIL) OR
        (HighlightFilter[5] <> NIL)) THEN
         UsingFilters := TRUE;
    ELSE
         UsingFilters := FALSE;
    END;
    IF (UsingFilters) THEN
        MaxLegendHeight := (RealCharacterHeight+RealVerticalGap)*3+RealVerticalGap;
    ELSE
        MaxLegendHeight := (RealCharacterHeight+RealVerticalGap)*2;
    END;
    NotateAChart(MaxLegendHeight);

 (* write column caps *)
    WriteColumnHeadings();
    
  (* <DEBUGGING> 
        PrintSCard(BarLabelLeft,"Bar Label Left ");
        PrintSCard(BarLabelRight,"Bar Label Right ");
        PrintSCard(BarLabelAbove,"Bar Label Above ");
        PrintSCard(BarLabelBelow,"Bar Label Below ");
        
        PrintSCard(LEFTOFBAR,"Position Bar Label Left ");
        PrintSCard(RIGHTOFBAR,"Position Bar Label Right ");
        PrintSCard(TOPOFBAR,"Position Bar Label Above ");
        PrintSCard(BOTTOMOFBAR,"Position Bar Label Below ");
     <DEBUGGING> *)

 (* write task information *)
    NumberOfChannels:= 0;
    MaxTask:= 0;
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,65535,
                                     WriteTaskList, NIL);
    
END WriteGanttGraphicsFile;


(*--------------------------------------------------------------------------*)
        (*  
            TLGS Gantt Chart Main
         *)
         
PROCEDURE CalcTLGSGanttChart();

VAR
    DrawingXMax,
    DrawingYMax            : REAL;
    PageDescription        : ATLGSPageRecordPtr;
    BorderRepeatLeftWidth,
    BorderRepeatDrawingX,
    ChannelHeight,
    TotalTopHeight,
    TotalBottomHeight,
    TotalLeftWidth,
    TotalRightWidth,
    MaxLegendHeight        : CARDINAL;
    UsingFilters,
    okay                   : BOOLEAN;
    
BEGIN 
    
    GetBarOrigin();

 (* axis *)
    AxisLength:=0;   
    AxisHeight:= 2*(RealVerticalGap+RealCharacterHeight);

 (* initialize label sizes *)  
    BarLabelAbove := FALSE;
    BarLabelBelow := FALSE;
    LeftBarLabelSize := 0;
    RightBarLabelSize := 0;
    TopBarLabelSize := 0;
    BottomBarLabelSize := 0;
    NumberOfLabels := 0;
    IF (ShowGanttArea) THEN
        GetBarLabelSizes();
        GanttTimescaling();
    END;
     
    TLGSGanttCalc();
    DrawingXMax:= FLOAT(BarOrigin) + FLOAT(AxisLength);
    ChannelHeight:= 1;
    IF(BarLabelAbove)THEN
       INC(ChannelHeight);
    END;
    IF(BarLabelBelow)THEN
       INC(ChannelHeight);
    END;
    DrawingYMax:= FLOAT(NumberOfChannels * ChannelHeight); 
    IF ((HighlightFilter[3] <> NIL) OR
        (HighlightFilter[4] <> NIL) OR
        (HighlightFilter[5] <> NIL)) THEN
         UsingFilters := TRUE;
    ELSE
         UsingFilters := FALSE;
    END;
    IF (UsingFilters) THEN
        MaxLegendHeight := (RealCharacterHeight+RealVerticalGap)*3+RealVerticalGap;
    ELSE
        MaxLegendHeight := (RealCharacterHeight+RealVerticalGap)*2;
    END;
    BorderSizeCalc(MaxLegendHeight,TotalTopHeight,TotalBottomHeight);   
                   
 (* borders in sedona units *)   
    TotalTopHeight:= TotalTopHeight 
                   + AxisHeight 
                   + MARGIN*RealCharacterHeight;
    TotalBottomHeight:= TotalBottomHeight 
                      + MARGIN*RealCharacterHeight;
    
    TotalLeftWidth:= (MARGIN + FirstColumnWidth)*RealCharacterWidth;
    TotalRightWidth:= MARGIN*RealCharacterWidth;
    DrawingXMax:= DrawingXMax-FLOAT(FirstColumnWidth);
    
    PageDescription:= TLGSPageRecord();
    WITH PageDescription^ DO
         ImageXVirtual:= DrawingXMax*FLOAT(RealCharacterWidth);
         ImageYVirtual:= DrawingYMax*FLOAT(RealCharacterHeight+RealVerticalGap);
      	 Border1XVirtual:= FLOAT(TotalLeftWidth);    (* Left border size in SU's *)
   	 Border2XVirtual:= FLOAT(TotalRightWidth);   (* Right border size in SU's *)
         Border1YVirtual:= FLOAT(TotalTopHeight);    (* Top border size in SU's *)
         Border2YVirtual:= FLOAT(TotalBottomHeight); (* Bottom border size in SU's *)
    END;
    
END CalcTLGSGanttChart;

(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDGantt *)

END TSEDGantt.

