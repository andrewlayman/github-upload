   (*
    Modification History:

        19-May-89 WKH   Made changes to support new pert record format
        15-Jun-89 CMH   New form changes 
        22-Jun-89 CMH   Changes to compress TLGS network views, modified
                        round corner radius 
        28-Jun-89 CMH   Allow more space for thin round lines
         6-Jul-89 CMH   Modify network line spacing
	 9-Aug-89 CMH   Importing FindNetLayoutByName procedure from LoadCommon.
	15-Aug-89 CMH   If no timescaling on pert then set compress axis to 
	                false also.
         5-Sep-89 CMH   Moved UnitsForScaling, CharactersForScaling,
                        UnitsForGrouping and MilitaryTime to 
                        TimeUnitsTLGS.DEF from TSEDTimescale.DEF so 
                        TLNBUILD would not import from TSEDTimescale 
                        since it has 1.6k bytes of data.
         8-Sep-89 CMH   Using new WriteBoolean, WriteCardinal procedures,
        22-Sep-89 CMH   Added new variable for independant font height.
        25-Sep-89 CMH   Font height equal to character height used for 
                        scaling.   
        25-Sep-89 EGK   Import FindNetLayoutByName from NetLUtility instead
                        of NetLayouts.
         1-Nov-89  CMH  Added border frame style to match the boxes,
                        thin, thick or hollow, and round or square. 
         2-Nov-89  CMH  Adjustements for line spacing.
    *)

IMPLEMENTATION MODULE DataNetwork;

FROM AsOf                   IMPORT
    (* PROC *)			AsOfDate;
    
FROM FontTLGS		    IMPORT 
    (* CONST *) 		HELVETICALIGHT,
    (* VAR *)			ActiveFont,
                                FontHeight,
    (* PROC *)			GetASedonaFontNumber;
        
FROM IlsaStatic             IMPORT
    (* TYPE *)			ATLGSGridStyle,       
    				ATLGSCorner,       
    				AnOrientation,   
    				ATLGSPertRecord,
				ATLGSPertRecordPtr,
				ATLGSScale,
    (* PROC *)  		TLGSPertRecord;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM NetLayouts		        IMPORT
    (* TYPE *)			        ANetworkLayout,
    (* VAR *)			        NetLayoutTree,
    (* PROC *)			        GetNormalNetLayout;

FROM NetLUtility            IMPORT 
    (* PROC *)                  FindNetLayoutByName;

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
  
    
FROM TSEDData               IMPORT
  (* CONST *)                (* pipe STYLE keywords *)
                                THINLINE,		
                                NORMALLINE,
                                FLOWLINE,
                                THICKTUBE,
                                FLOWTUBE,
       
                                INCHESPERPOINT,
    				SEDONAUNITPERINCH,
    
  (* VAR *)                     BaseCharacterHeight,
    				BaseCharacterWidth,
          			RealCharacterHeight,
    				RealCharacterWidth,
				VerticalGap,
				RealVerticalGap,
    				SpacePointSize,
    				CharPointSize;

FROM TSEDNotation	    IMPORT
    (* PROC *)			CheckForTitle,
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

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

(*--------------------------------------------------------------------------*)
         (*  
          InitializeNetworkData          
          *)
         
PROCEDURE InitializeNetworkData();
CONST
    DESCENDERADJUSTMENT = 1.45;

VAR 
    FontFamily,
    FontMember   : CARDINAL;
    Node         : ATreeNode;
    TLGSPertInfo : ATLGSPertRecordPtr;
    
BEGIN

    TLGSPertInfo:= TLGSPertRecord();
    
 (* character size in points *)
    SpacePointSize:= (TLGSPertInfo^.DefaultSpec.Leading) DIV 16;	       (* vertical spacing *) (* 5/19/89 WKH *)
    CharPointSize:= (TLGSPertInfo^.DefaultSpec.PointSize) DIV 16;  (* character size in points *)
     
 (* vertical gap in Sedona Units *)
    RealVerticalGap:= SpacePointSize-CharPointSize;
    RealVerticalGap:= CharPointSize DIV 5; (* 20% leading *) (* !!!! TEMP 22-Jun-89 CMH *)
    RealVerticalGap:=  TRUNC(FLOAT(RealVerticalGap)*INCHESPERPOINT*SEDONAUNITPERINCH/DESCENDERADJUSTMENT);
    VerticalGap := 1;
    
 (* character size in Sedona units *)  
    RealCharacterHeight:= TRUNC(FLOAT(CharPointSize)*INCHESPERPOINT*SEDONAUNITPERINCH/DESCENDERADJUSTMENT);
    RealCharacterWidth:= RealCharacterHeight DIV 4; (* 22-Jun-89 CMH *)
     
 (* font height equal to character height used for scaling *)   
    FontHeight := RealCharacterHeight;  (* 25-Sep-89 CMH *) 
     
 (* character size for scaling *)  
    BaseCharacterHeight:= 1; (* 22-Jun-89 CMH *)
    BaseCharacterWidth := 4;  

 (* crate frame style *)  
    
    CASE TLGSPertInfo^.TaskBoxStyle OF (* 5/19/89 WKH *)
            Thin:
               CrateFramePipeWidth := BaseCharacterWidth+(BaseCharacterWidth DIV 2);
               CrateFramePipeStyle := THINLINE;	
       |    Hollow :
               CrateFramePipeWidth := BaseCharacterWidth*3;
               CrateFramePipeStyle := THICKTUBE;	
    ELSE (* Thick *)
               CrateFramePipeWidth := BaseCharacterWidth*2;
               CrateFramePipeStyle := NORMALLINE;	
    END;
    
    CASE TLGSPertInfo^.TaskBoxCorners OF 
            Square:
               CrateFramePipeRadius := 0;
    ELSE (* Round *)
               CrateFramePipeRadius:= (RealCharacterHeight + RealVerticalGap) DIV 3; (* 33% of box text height *) (* 22-Jun-89 CMH *)
    END;
    
    IF (TLGSPertInfo^.TaskBoxShadows) THEN 
        CrateFramePipeHighlight:= 1;  
        CrateFramePipeWidth := CrateFramePipeWidth+BaseCharacterWidth;
    ELSE
        CrateFramePipeHighlight:= 0;
    END;
    
    CrateInteriorPipeWidth := BaseCharacterWidth;
    CrateInteriorPipeStyle:= THINLINE;	
    CrateInteriorPipeRadius := 0;
    CrateInteriorPipeHighlight:= 0;
    
    
 (* dependency line style *)  
    CASE TLGSPertInfo^.DependLineStyle OF 
            Thin:
               NormalPipeWidth := BaseCharacterWidth+(BaseCharacterWidth DIV 2);
               NormalPipeStyle := THINLINE;	
       |    Hollow :
               NormalPipeWidth := BaseCharacterWidth*3;
               NormalPipeStyle := THICKTUBE;	
    ELSE (* Thick *)
               NormalPipeWidth := BaseCharacterWidth*2;
               NormalPipeStyle := NORMALLINE;	
    END;
    
    IF (TLGSPertInfo^.DependLineCorners = Square) THEN 
        NormalPipeRadius := 0;
    ELSE (* Round *)
        NormalPipeRadius:= (RealCharacterHeight + RealVerticalGap) DIV 3; (* 33% of box text height *) (* 22-Jun-89 CMH *)
     (* allow more space for round thin dependency lines *) (* 14-Sep-89 CMH *)
        NormalPipeWidth := NormalPipeWidth + (BaseCharacterWidth DIV 2);
    END;
    
    IF ((TLGSPertInfo^.DependLineShadows) OR (TLGSPertInfo^.TaskBoxShadows))THEN 
         NormalPipeWidth := NormalPipeWidth + (BaseCharacterWidth DIV 2);(* 14-Sep-89 CMH *)
    END;
    
    IF (TLGSPertInfo^.DependLineShadows) THEN 
         NormalPipeHighlight:= 1;  
    ELSE
         NormalPipeHighlight:= 0;
    END;
    
 (* master task outline style *)  
    MasterPipeWidth := BaseCharacterWidth;
    MasterPipeStyle := THINLINE;	
    MasterPipeHighlight := 0;
    MasterPipeRadius := 0;
          
    WITH TLGSPertInfo^ DO
         CharactersForScaling:= 5.0; (* 5/19/89 WKH used to be TimeScale *)
         UnitsForScaling:= Group; (* 5/19/89 WKH used to be Group2 *)
         UnitsForGrouping:= Group;
         ArrangeBy := TaskArrangement;
         TimeScaleNetwork:= PeriodicPert; (* 5/19/89 WKH used to be Scaling *)
         IF (TimeScaleNetwork) THEN (* 15-Aug-1989 CMH *) 
             CompressAxis:= Compressed;
         ELSE
             CompressAxis:= FALSE;
         END;
         ShowDependencyLines:= TRUE; (* 5/19/89 WKH used to be dependencies *)
         FontFamily:= DefaultSpec.FontFamily;
         FontMember:= DefaultSpec.FontMember;
         ActiveFont:= GetASedonaFontNumber(FontFamily,FontMember);
    END;
    
    Node := FindNetLayoutByName(TLGSPertInfo^.Layout);
    IF (Node = NIL) THEN
        NetworkDiagramLayout := GetNormalNetLayout();
    ELSE
        NetworkDiagramLayout := Node^.Methods^.GetDataObject (Node);
    END;
      
       
END InitializeNetworkData;


(*--------------------------------------------------------------------------*)
         (*  
          WriteNodeChartData          
          *)
         
PROCEDURE WriteNodeChartData();

VAR 
    s : ARRAY [0..255] OF CHAR;
    
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

 (* time format *)
    WriteBoolean(MilitaryTime(DefaultDateAndTimeFormat));

 (* font *)
    WriteCardinal(ActiveFont);        
 
 (* font height for text *)
    WriteCardinal(FontHeight);        
 
 (* character height in sedona units for scaling chart *)  
    WriteCardinal(RealCharacterHeight);        
  
 (* character width in sedona units for scaling chart *)  
    WriteCardinal(RealCharacterWidth);        
  
 (* vertical gap between characters for scaling chart *)  
    WriteCardinal(RealVerticalGap); 
    
 (* title existence *) 
    WriteBoolean (CheckForTitle());

 (* note existence *) 
    WriteBoolean(CheckForNotes());
     
 (* legend existence *) 
    WriteBoolean(CheckForLegend());

 (* vertical gap from top of chart to title area *)
    WriteCardinal((RealCharacterHeight+RealVerticalGap));  (* one character with space *)
        
 (* vertical gap from bottom of chart to title area *)
    WriteCardinal((RealCharacterHeight+RealVerticalGap));  (* one character with space *)
        
 (* today line position *)
    WriteCardinal(AsOfDate); 
  
 (* network chart symbology - Piston *)
    WriteCardinal(1);
    
 (* frame line style *)
    WriteCardinal(CrateFramePipeStyle);
       
 (* frame corners style *)
    IF (CrateFramePipeRadius = 0) THEN
        WriteCardinal(0);
    ELSE
        WriteCardinal(1);
    END;
       
 (* bar to show percent complete - actual *)
    WriteCardinal(0);
    
END WriteNodeChartData;


(* for duration bar networks - not avaliable in TL version 4.0  
 |(*--------------------------------------------------------------------------*)
 |       (*  
 |           InitDurBarThickness
 |                       
 |        *)
 |        
 |PROCEDURE InitDurBarThickness();
 |
 |VAR 
 |    s            : ARRAY [0..255] OF CHAR;
 |    
 |BEGIN     
 |   
 |   IF (ShowBaseLineBars) THEN
 |       PlanBarThickness:= BaseCharacterHeight;
 |       ActualBarThickness:= PlanBarThickness DIV 2;
 |   ELSE
 |       PlanBarThickness:= 0;
 |       ActualBarThickness:= BaseCharacterHeight;
 |   END;
 |
 |END InitDurBarThickness;
 *)

(*--------------------------------------------------------------------------*)

BEGIN                       (* DataNetwork *)

END DataNetwork.
