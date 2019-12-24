IMPLEMENTATION MODULE DataGantt;
   
    (*  MODIFICATION HISTORY
        15-Jun-89 CMH   New form changes 
         6-Jul-89 CMH   Changed retriving of bar to show percent achieved 
                        data to use QueryPctCompletePlace procedure.
    	17-Jul-89 CMH   If there is no layout specified on the gantt form,
    	                now will use the current gantt layout, not the
    	                default gantt layout.
    	26-Jul-89 CMH   Moved code to determine which Gantt layout to use 
    	                to GanttOptions so the QueryPctCompletePlace and
    	                QueryPctCompleteColumn could use the same code.
         1-Aug-89 CMH   Added variables to indicate whether or not a 
                        date range was input. 
         9-Aug-89 CMH   Initialize AllOtherDataColor for Gantt charts. 
        14-Aug-89 CMH   Add more room between notation area and graph 
                        for asof trigangle, SAMSO symboloyg, spacing
                        same top and bottom.
        23-Aug-89 AJL   Changed GAP_FOR_NOTATION to GAPFORNOTATION. 
         5-Sep-89 CMH   Moved UnitsForScaling, CharactersForScaling,
                        UnitsForGrouping and MilitaryTime to 
                        TimeUnitsTLGS.DEF from TSEDTimescale.DEF so 
                        TLNBUILD would not import from TSEDTimescale 
                        since it has 1.6k bytes of data.
         8-Sep-89 CMH   Using new WriteBoolean, WriteCardinal procedures,
                        renamed APageDescription variable name to 
                        PageDescription.
        15-Sep-89 CMH   Removed code that disabled bar labels in border
                        repeat mode.
        22-Sep-89 CMH   Added new variable for independant font height.
        25-Sep-89 CMH   Font height equal to character height used for 
                        scaling.   
        23-Oct-89 CMH   Allow more gap for channels when using hollow lines
                        or round corners;
     *)
     

FROM AsOf                   IMPORT
    (* PROC *)			AsOfDate;
    
FROM ChartForms		    IMPORT
     (* TYPE *)			AChartFormatPtr,
     (* VAR *)			CurrentChartFormat, 
                                DefaultChartFormat, LayoutTree;
     
FROM ColorTLGS              IMPORT
    (* VAR *)                   AllOtherDataColor;
    
FROM FontTLGS		    IMPORT 
    (* CONST *) 		HELVETICALIGHT,
    (* VAR *)			ActiveFont,
                                FontHeight,
    (* PROC *)			GetASedonaFontNumber;
        
FROM Gantt                  IMPORT 
    (* TYPE *)                  ASlackStyle, AGanttLineType;
  
FROM GanttOptions           IMPORT 
    (* PROC *)                  GetTLGSGanttLayout,
                                QueryPctCompletePlace;

FROM GanttTimescale         IMPORT 
    (* VAR *)                   StartDateToUse,
        		        EndDateToUse,
        		        StartingDateSelected,
        		        EndingDateSelected;
        		        
FROM IlsaStatic		    IMPORT 
    (* TYPE *)			ATLGSGridStyle,
    				ATLGSGanttRecord,
    				ATLGSCorner,    
    				ATLGSScale,         
    				ATLGSSymbology,         
   				ATLGSGanttRecordPtr,
   				ATLGSLabelRecord,
                 		ATLGSPageRecord,
    	                        ATLGSPageRecordPtr,
    (* PROC *)	                TLGSPageRecord,
    	                  	TLGSGanttRecord;
    
FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, Compare, CtoS, SetLengthOf,
                                LengthOf, TrimRear, ConcatLS;

FROM TSEDData               IMPORT
    (* CONST *)		     (* pipe STYLE keywords *)
    				THINLINE,		
    				NORMALLINE,
    				THICKTUBE,
    				INCHESPERPOINT,
    				SEDONAUNITPERINCH,
    				
    (* VAR *)                   SpacePointSize,
        			CharPointSize,
        			BaseCharacterHeight,
        			BaseCharacterWidth,
        			RealCharacterHeight,
        			RealCharacterWidth,
        			RealVerticalGap,
        			VerticalGap;

FROM TSEDNotation	    IMPORT
    (* CONST *)                 GAPFORNOTATION,
    (* PROC *)	                CheckForTitle,
    				CheckForNotes,
    				CheckForLegend;
    
FROM TSEDObjectWrite	    IMPORT
    (* PROC *)			WriteBoolean,
                                WriteCardinal;
                                
FROM TSEDWrite		    IMPORT
    (* PROC *)                 	WriteToTLGSFile;
    
FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
                                DefaultDateAndTimeFormat;

FROM TimeUnitsTLGS          IMPORT
    (* CONST *)			HOURS,
    				DAYS,
    				WEEKS,
    				MONTHS,
    				QUARTERS,
    				YEARS,
    (* VAR *) 			UnitsForScaling,
                                CharactersForScaling,
    				UnitsForGrouping,
    (* PROC *)                  MilitaryTime;
    
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

    

VAR
    BoxCornerStyle   : ATLGSCorner;
    FrameLineStyle   : ATLGSGridStyle;  
    BarSymbology     : ATLGSSymbology;
    BarForAchieved   : AGanttLineType;
    AlwaysShowActuals,
    VerticalGrid,
    HorizontalGrid   : BOOLEAN;
    
(*--------------------------------------------------------------------------*)
         (*  
          InitializeGanttData          
          *)
         
PROCEDURE InitializeGanttData();

CONST
    HoursMinChars = 3.0;
    DESCENDERADJUSTMENT = 1.45;
    
VAR 
    FontFamily,
    FontMember       : CARDINAL;
    TLGSGanttInfo    : ATLGSGanttRecordPtr;
    PageDescription  : ATLGSPageRecordPtr;

BEGIN

    BoxCornerStyle := Square;
    AllOtherDataColor := 1;

    TLGSGanttInfo := TLGSGanttRecord(HoursMinChars);

    GanttChartLayout := GetTLGSGanttLayout();
    WITH GanttChartLayout^ DO
         ShowBaseLineBars := AVPShowing;
         ShowGanttArea := GanttShowing;
         SlackType := slackstyle;
    END;

    BarForAchieved:=  QueryPctCompletePlace(); (* 6-Jul-89 CMH *)
    WITH TLGSGanttInfo^ DO
         FrameCornerStyle := Corners;
         FrameLineStyle := GridStyle;
         BarSymbology := Symbology;
         SpacePointSize := DefaultSpec.Leading DIV 16;  (* vertical spacing in points *)
         CharPointSize := DefaultSpec.PointSize DIV 16; (* character size in points *)
    END;
    
 (* vertical gap in Sedona Units *)
    RealVerticalGap := SpacePointSize-CharPointSize;
    RealVerticalGap := TRUNC(FLOAT(RealVerticalGap)*INCHESPERPOINT*SEDONAUNITPERINCH/DESCENDERADJUSTMENT);
    IF ((FrameLineStyle = Hollow) OR (FrameCornerStyle = Round)) THEN  (* 23-Oct-1989 CMH *)
        RealVerticalGap := TRUNC(FLOAT(RealVerticalGap) * 1.4); 
    END;
    VerticalGap := 1;
     
 (* character size in Sedona units *)  
    RealCharacterHeight := TRUNC(FLOAT(CharPointSize)*INCHESPERPOINT*SEDONAUNITPERINCH/DESCENDERADJUSTMENT);
    RealCharacterWidth := RealCharacterHeight;
   
 (* font height equal to character height used for scaling *)   
    FontHeight := RealCharacterHeight;  (* 25-Sep-89 CMH *) 
               
 (* character size for scaling *)  
    BaseCharacterHeight := 1;
    BaseCharacterWidth := 1;
      
    WITH TLGSGanttInfo^ DO  
         CharactersForScaling := TimeScale;
         UnitsForScaling := Group;
         UnitsForGrouping := Group;
         ExtraSpaceOnGantt := ExtraSpacing;
         ExtraSpaceLevel := IndentLevel;
         HorizontalGrid := HorizGrid;
         VerticalGrid := VertGrid;
         FontFamily := DefaultSpec.FontFamily;
         FontMember := DefaultSpec.FontMember;
         ActiveFont := GetASedonaFontNumber(FontFamily,FontMember);
         StartDateToUse := StartDate;
         EndDateToUse := EndDate;
         IF (ORD(Starting[0]) > 0) THEN
             StartingDateSelected := TRUE;
         ELSE
             StartingDateSelected := FALSE;
         END;
         IF (ORD(Ending[0]) > 0) THEN
             EndingDateSelected := TRUE;
         ELSE
             EndingDateSelected := FALSE;
         END;
         AlwaysShowActuals := ShowActuals;
         BarLabel1ID := Label1.ColumnID;
         BarLabel2ID := Label2.ColumnID;
         BarLabel3ID := Label3.ColumnID;
         BarLabel4ID := Label4.ColumnID;
         BarLabel1Width := Label1.Width;
         BarLabel2Width := Label2.Width;
         BarLabel3Width := Label3.Width;
         BarLabel4Width := Label4.Width;
         BarLabel1Pos := Label1.Position;
         BarLabel2Pos := Label2.Position;
         BarLabel3Pos := Label3.Position;
         BarLabel4Pos := Label4.Position;
    END;

END InitializeGanttData;


(*--------------------------------------------------------------------------*)
         (*  
          WriteGanttChartData          
          *)
         
PROCEDURE WriteGanttChartData();

CONST
    NOSLACK = 0;
    FREESLACK = 1;
    TOTALSLACK = 2;
    
    PISTONSYMBOLOGY = 1;
    SAMSOSYMBOLOGY = 2;
    
    SHOWPCONACTUAL = 0;
    SHOWPCONBASELINE = 1;
    
    SQUARE = 0;
    ROUND = 1;
    
VAR 
    SedonaUnitsPerUnit : CARDINAL;
    s                  : ARRAY [0..255] OF CHAR;
    
BEGIN
   
 (* tag *)
    SetString(s,"DATA");
    WriteToTLGSFile(s);
    
 (* time units for grouping *)
    CASE UnitsForGrouping OF
         SHours   : WriteCardinal(HOURS);
       | SWeeks   : WriteCardinal(WEEKS);
       | SMonths  : WriteCardinal(MONTHS);
       | SQuarters: WriteCardinal(QUARTERS);
       | SYears   : WriteCardinal(YEARS);
    ELSE
         WriteCardinal(DAYS);
    END;

 (* time units for scaling *)
    CASE UnitsForScaling OF
         SHours   : WriteCardinal(HOURS);
       | SWeeks   : WriteCardinal(WEEKS);
       | SMonths  : WriteCardinal(MONTHS);
       | SQuarters: WriteCardinal(QUARTERS);
       | SYears   : WriteCardinal(YEARS);
    ELSE
         WriteCardinal(DAYS);
    END;
    
 (* time format *)
    WriteBoolean(MilitaryTime(DefaultDateAndTimeFormat));

 (* font *)
    WriteCardinal(ActiveFont);        
 
 (* font height for text *)
    WriteCardinal(FontHeight);        
 
 (* frame line style *)
    CASE FrameLineStyle OF
         Thin   : WriteCardinal(THINLINE);
       | Hollow : WriteCardinal(THICKTUBE);
    ELSE
     (* Thick*)
        WriteCardinal(NORMALLINE);
    END;
       
 (* frame corners style *)
    IF (FrameCornerStyle = Round) THEN
        WriteCardinal(ROUND);
    ELSE
        WriteCardinal(SQUARE);
    END;
       
 (* box corners style *)
    IF (BoxCornerStyle = Round) THEN
        WriteCardinal(ROUND);
    ELSE
        WriteCardinal(SQUARE);
    END;
       
 (* base character height in sedona units *)  
    WriteCardinal(RealCharacterHeight);        
  
 (* base character width in sedona units *)  
    WriteCardinal(RealCharacterWidth);        
  
 (* vertical gap between characters *)  
    WriteCardinal(RealVerticalGap);	
    
 (* horizontal grid *)
    WriteBoolean(HorizontalGrid);
     
 (* major vertical grid *)  
    WriteBoolean(VerticalGrid);
     
 (* minor vertical grid *)  
    WriteBoolean(VerticalGrid);
     
 (* extra space on Gantt *)
    WriteBoolean(ExtraSpaceOnGantt);
     
 (* extra space at level *)
    WriteCardinal(ExtraSpaceLevel);

 (* show baseline bars *)
    WriteBoolean(ShowBaseLineBars);
     
  (* slack type *)
    IF (SlackType = TotalSlack) THEN
        WriteCardinal(TOTALSLACK);
    ELSIF (SlackType = FreeSlack) THEN
        WriteCardinal(FREESLACK);
    ELSE
        WriteCardinal(NOSLACK);
    END;
     
 (* show Gantt area *)
    WriteBoolean(ShowGanttArea);
     
 (* title existence *) 
    WriteBoolean(CheckForTitle());

 (* note existence *) 
    WriteBoolean(CheckForNotes());
     
 (* legend existence *) 
    WriteBoolean(CheckForLegend());

 (* vertical gap from top of chart to title area *)
    WriteCardinal(GAPFORNOTATION);     
    
 (* vertical gap from bottom of chart to title area *)
    WriteCardinal(GAPFORNOTATION);     
    
 (* as of date *)
    WriteCardinal(AsOfDate); 
    
 (* Gantt chart symbology - Piston or SAMSO *)
    IF (BarSymbology = SAMSO) THEN
        WriteCardinal(SAMSOSYMBOLOGY);
    ELSE
        WriteCardinal(PISTONSYMBOLOGY);
    END; 
     
 (* bar to show percent complete *)
    IF (BarForAchieved = Baseline) THEN
        WriteCardinal(SHOWPCONBASELINE); 
    ELSE
        WriteCardinal(SHOWPCONACTUAL);
    END; 
    
 (* always draw actual bars  *)
    WriteBoolean(AlwaysShowActuals);
     
END WriteGanttChartData;

(*--------------------------------------------------------------------------*)

BEGIN                       (* DataGantt *)

END DataGantt.
