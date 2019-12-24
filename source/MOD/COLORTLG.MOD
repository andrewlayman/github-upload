IMPLEMENTATION MODULE ColorTLGS;

    (*  MODIFICATION HISTORY
        15-Feb-89 CMH   Fixed "Name" field in color assignment record, 
        		from CARDINAL to CHAR;
        28-Feb-89 CMH   Added two new procedures, GetFGColor and
        		InitNodeChartColors;
        26-May-89 LAA   The color assignments are now stored in FlexStor.
        30-May-89 CMH   The horizontal grid color now takes on the 
                        borders color.
        15-Jun-89 CMH   Changes for a new color form
        15-Jun-89 LAA   Changed from using LockTLGSColorAssignment ... to
                        picking up the Palette name from the appropriate
                        record.
        27-Jun-89 LAA   Merged Carol's changes of the 24th with mine of the
                        15th.
        17-Jul-89 CMH   Made horizontal grid the same color as major 
                        vertical grid.
         8-Sep-89 CMH   Using new WriteCardinal procedure.
        01-Dec-89 LAA   Having just one default palette didn't work, so I
                        made it an array of default palettes.
         5-Dec-89 CMH   Fixed critical path line color bug.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;
    
FROM CritFilt		    IMPORT 
    (* PROC *)                  QueryCriticalPathFilter;

FROM FilterRc		    IMPORT
    (* TYPE *)                  AFilterRecordPointer, AFilterRecord,
    (* VAR *)                   HighlightFilter;
    
FROM IlsaStatic		    IMPORT
    (* CONST *)              (* Gantt Chart Colors *)
                                TILG, (* Title & Legend           *)
                                TXHD, (* Text Heading             *)
                                BRDR, (* Borders                  *)
                                ASOF, (* As-of date               *)
                                MJGD, (* Major grid               *)
                                MNGD, (* Minor grid               *)
                                PAGE, (* Page                     *)
                                BKHD, (* Background Heading       *)
                                DATA, (* Data Columns             *)
                                TKBR, (* Task Bars                *)
                                F1FG, (* Filter 1 Foreground      *)
                                F1BG, (* Filter 1 Background      *)
                                F2FG, (* Filter 2 Foreground      *)
                                F2BG, (* Filter 2 Background      *)
                                F3FG, (* Filter 3 Foreground      *)
                                F3BG, (* Filter 3 Background      *)
                                OSTK, (* Open Summary Tasks       *)
                                AOTK, (* All Other Tasks          *)
                                OSBR, (* Open Summary Bars        *)
                                AOTB, (* All Other Task Bars      *)
                                MILE, (* MileStones               *)
                                BASE, (* Baseline                 *)
                                ACMT, (* Achievement              *)
                                SLAK, (* Slack                    *)
                                
                             (* Pert Chart Colors *)
                                PTILG, (* Title & Legend           *)
                                PTXHD, (* Text Heading             *)
                                PBRDR, (* Borders                  *)
                                PPAGE, (* Background Page          *)
                                PBKHD, (* Background Heading       *)
                                PBKCH, (* Background Chart         *)
                                PBKTB, (* Background Task Boxes    *)
                                PF1FG, (* Filter 1 Foreground      *)
                                PF1BG, (* Filter 1 Background      *)
                                PF2FG, (* Filter 2 Foreground      *)
                                PF2BG, (* Filter 2 Background      *)
                                PF3FG, (* Filter 3 Foreground      *)
                                PF3BG, (* Filter 3 Background      *)
                                POPST, (* Open Summary Tasks       *)
                                PAOTK, (* All Other Tasks          *)
                                POPSB, (* Open Summary Boxes       *)
                                PAOBX, (* All Other Boxes          *)
                                PMSBX, (* Milestone Boxes          *)
                                PPTDP, (* PERT Dependencies        *)
   
    (* VAR *)                   DefaultPalette,
    (* TYPE *)                  ATLGSColorAssignmentPtr, ATLGSChartType,
                                ATLGSPertRecordPtr, ATLGSGanttRecordPtr,
                                ATLGSTreeRecordPtr,
    (* PROC *)                  TLGSPertRecord, TLGSGanttRecord, 
                                TLGSTreeRecord;
    
FROM LStrings		    IMPORT
    (* PROC *)			SetString;

FROM Palettes               IMPORT
    (* PROC *)                  FindPaletteByName;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM TSEDData		    IMPORT
    (* CONST *)                 GANTT, TREE,
    (* VAR *)                 	ChartType;

FROM TSEDObjectWrite	    IMPORT
    (* PROC *)			WriteCardinal, WriteText;

FROM TSEDWrite		    IMPORT
    (* PROC *)                 	WriteToTLGSFile;

    
(*--------------------------------------------------------------------------*)
        (*  
            GetFGColor            
            
            Used for TLGraphics Network and Tree charts.
        
         *)

PROCEDURE GetFGColor(VAR FGFilter,BGFilter : CARDINAL;
                     TaskTreeNode : ATreeNode);
                                
VAR
      FilterColor : CARDINAL;
      filter      : ATaskFilterSet;
      task        : ATaskPtr; 

BEGIN
 
 (* get the filter set for this task *)
    task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    filter:= task^.FilterSet;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
    
 (* apply the filtering *)
    IF (Highlight3 IN filter) THEN 
        FGFilter:= HL3ColorFG;
        BGFilter:= HL3ColorBG;
    ELSIF Highlight4 IN filter THEN 
        FGFilter:= HL4ColorFG;
        BGFilter:= HL4ColorBG;
    ELSIF Highlight5 IN filter THEN 
        FGFilter:= HL5ColorFG;
        BGFilter:= HL5ColorBG;
    END; 
  
END GetFGColor;


(*--------------------------------------------------------------------------*)
        (*  
            InitNodeChartColors 
         *)
         
PROCEDURE InitNodeChartColors();

VAR
    FilterNumber      : CARDINAL; 
    TLGSColorInfo : ATLGSColorAssignmentPtr;
    ColorNode     : ATreeNode;
    GanttRecord   : ATLGSGanttRecordPtr;
    PertRecord    : ATLGSPertRecordPtr;
    TreeRecord    : ATLGSTreeRecordPtr;
    CriticalFilterSet : BOOLEAN;
    
BEGIN

 (* look for a color selection holder record *)  
    IF (ChartType = GANTT) THEN                                   (* 15-Jun-89 LAA *)
        GanttRecord := TLGSGanttRecord(0.0);
        ColorNode := FindPaletteByName(TLGSGanttChart, GanttRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN                      (* 01-Dec-89 LAA *)
            ColorNode := DefaultPalette[TLGSGanttChart];
        END;
    ELSIF (ChartType = TREE) THEN
        TreeRecord := TLGSTreeRecord();
        ColorNode := FindPaletteByName(TLGSTreeChart, TreeRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN
            ColorNode := DefaultPalette[TLGSTreeChart];
        END;
    ELSE			
        PertRecord := TLGSPertRecord();
        ColorNode := FindPaletteByName(TLGSPertChart, PertRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN
            ColorNode := DefaultPalette[TLGSPertChart];
        END;
    END; 

    TLGSColorInfo := ColorNode^.Methods^.LockFlexStorDataObject(ColorNode);

    IF (TLGSColorInfo <> NIL) THEN

     (* Open Summary Task Data Text *)
        OpenSummaryDataColor:= TLGSColorInfo^.ColorFor[POPST];
       
     (* All Other Task Data Text *)
        AllOtherDataColor:= TLGSColorInfo^.ColorFor[PAOTK];
       
(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |   (* Open Summary Task Bar Future *)
 |      OpenSummaryBarColor:= TLGSColorInfo^.ColorFor[OSBR];
 |    
 |   (* All Other Task Bar Future *)
 |      AllOtherBarColor:= TLGSColorInfo^.ColorFor[AOTB];
 |      
 |   (* Achievement Task Bar *)
 |      AchievementBarColor:= TLGSColorInfo^.ColorFor[ACMT];
 |      
 |   (* Baseline Bar *)
 |      BaseLineBarColor:= TLGSColorInfo^.ColorFor[BASE];
 *)

     (* dependency lines *)
        DepLineColor:= TLGSColorInfo^.ColorFor[PPTDP];
        
     (* open master task outlines *)
        MTOpenLineColor:= TLGSColorInfo^.ColorFor[POPSB];
       
     (* crate frames *)
        NormalCrateFrameColor:= TLGSColorInfo^.ColorFor[PAOBX];
     
     (* crate background *)
        NormalCrateBGColor:= TLGSColorInfo^.ColorFor[PBKTB];
       
     (* milestone crate frames *)
        MilestoneCrateFrameColor:= TLGSColorInfo^.ColorFor[PMSBX];
       
     (* highlight filter 3 *)
        HL3ColorFG:= TLGSColorInfo^.ColorFor[PF1FG];
        HL3ColorBG:= TLGSColorInfo^.ColorFor[PF1BG];
       
     (* highlight filter 4 *)
        HL4ColorFG:= TLGSColorInfo^.ColorFor[PF2FG];
        HL4ColorBG:= TLGSColorInfo^.ColorFor[PF2BG];
       
     (* highlight filter 5 *)
        HL5ColorFG:= TLGSColorInfo^.ColorFor[PF3FG];
        HL5ColorBG:= TLGSColorInfo^.ColorFor[PF3BG];
       
     (* critical path dependency lines *)  (* 24-Jun-89 CMH *)
        FilterNumber := 0;
        CriticalFilterSet := QueryCriticalPathFilter(FilterNumber); 
        CASE FilterNumber OF
             3: CritDepLineColor := HL3ColorFG; 
           | 4: CritDepLineColor := HL4ColorFG; 
           | 5: CritDepLineColor := HL5ColorFG; 
        ELSE
                CritDepLineColor := DepLineColor; 
        END;
        
    ELSE
    
     (* Open Summary Task Data Text *)
        OpenSummaryDataColor:= 1;
       
     (* All Other Task Data Text *)
        AllOtherDataColor:= 1;

(* for duration bar networks - not avaliable in TL version 4.0  
 |
 |   (* Open Summary Task Bar Future *)
 |      OpenSummaryBarColor:= 17;
 |     
 |   (* All Other Task Bar Future *)
 |      AllOtherBarColor:= 17;
 |     
 |   (* Achievement Task Bar *)
 |      AchievementBarColor:= 18;
 |     
 |   (* Baseline Bar *)
 |      BaseLineBarColor:= 21;
 |
 *)        
     (* dependency lines *)
        DepLineColor:= 1;
       
     (* highlight filter 1 *)
        HL3ColorFG:= 13;
        HL3ColorBG:= 2;
       
     (* highlight filter 4 *)
        HL4ColorFG:= 18;
        HL4ColorBG:= 2;
       
     (* highlight filter 5 *)
        HL5ColorFG:= 21;
        HL5ColorBG:= 2;
    
    END;

    ColorNode^.Methods^.UnlockUnchangedDataObject(ColorNode);

END InitNodeChartColors;

       
(*--------------------------------------------------------------------------*)
        (*  
            WriteFilterSelections 
         *)
         
PROCEDURE WriteFilterSelections();

VAR
    i      : CARDINAL;
    filter : AFilterRecordPointer;
    s      : ARRAY [0..255] OF CHAR;
    
BEGIN

 (* tag *)
    SetString(s,"FILTERS");
    WriteToTLGSFile(s);
    
 (* filter existence *)   
    FOR i:= 3 TO 5 DO
        IF (HighlightFilter[i] = NIL) THEN
            WriteCardinal(0);
        ELSE
            WriteCardinal(1);
        END;
    END;
    
 (* filter names *)   
    FOR i:= 3 TO 5 DO
        IF (HighlightFilter[i] <> NIL) THEN
            filter:=HighlightFilter[i]^.Methods^.LockFlexStorDataObject(HighlightFilter[i]);
            WriteText(filter^.Name,0,0);
            HighlightFilter[i]^.Methods^.UnlockUnchangedDataObject(HighlightFilter[i]);
        END;
    END;

END WriteFilterSelections;


(*--------------------------------------------------------------------------*)
        (*  
            WriteGanttColorSelections 
         *)
         
PROCEDURE WriteGanttColorSelections(TLGSColorInfo : ATLGSColorAssignmentPtr);

CONST
    NOTUSED = 40;
     (* attribute of color table not available in network -
        set = 40 which means invisible *)  

BEGIN

 (* title and legend*)
    WriteCardinal(TLGSColorInfo^.ColorFor[TILG]);
       
 (* cap heading *)
    WriteCardinal(TLGSColorInfo^.ColorFor[TXHD]);
       
 (* borders *)
    WriteCardinal(TLGSColorInfo^.ColorFor[BRDR]);
       
 (* as of date line *)
    WriteCardinal(TLGSColorInfo^.ColorFor[ASOF]);
       
 (* horizontal grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[MJGD]);
       
 (* major vertical grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[MJGD]);
       
 (* minor vertical grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[MNGD]);
       
 (* open summary task data text *)
    WriteCardinal(TLGSColorInfo^.ColorFor[OSTK]);
       
 (* all other task data text *)
    WriteCardinal(TLGSColorInfo^.ColorFor[AOTK]);
       
 (* axis background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[BKHD]);
       
 (* data column background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[DATA]);
      
 (* plot background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[TKBR]);
       
 (* page background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PAGE]);
      
 (* open summay task bar future *)
    WriteCardinal(TLGSColorInfo^.ColorFor[OSBR]);
       
 (* open summary task bar achievement *)
    WriteCardinal(TLGSColorInfo^.ColorFor[ACMT]);
       
 (* all other task bar future *)
    WriteCardinal(TLGSColorInfo^.ColorFor[AOTB]);
      
 (* all other task bar achievement *)
    WriteCardinal(TLGSColorInfo^.ColorFor[ACMT]);
       
 (* baseline bar *)
    WriteCardinal(TLGSColorInfo^.ColorFor[BASE]);
       
 (* future milestone *)
    WriteCardinal(TLGSColorInfo^.ColorFor[MILE]);
       
 (* complete milestone *)
    WriteCardinal(TLGSColorInfo^.ColorFor[ACMT]);
       
 (* slack *)
    WriteCardinal(TLGSColorInfo^.ColorFor[SLAK]);
       
 (* dependency lines *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* highlight filter 3 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[F1FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[F1BG]);
       
 (* highlight filter 4 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[F2FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[F2BG]);
       
 (* highlight filter 5 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[F3FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[F3BG]);
       
END WriteGanttColorSelections;

       
(*--------------------------------------------------------------------------*)
        (*  
            WriteNetworkColorSelections 
         *)
         
PROCEDURE WriteNetworkColorSelections(TLGSColorInfo : ATLGSColorAssignmentPtr);

CONST
    NOTUSED = 40;
     (* attribute of color table not available in network -
        set = 40 which means invisible *)  

BEGIN

 (* title and legend*)
    WriteCardinal(TLGSColorInfo^.ColorFor[PTILG]);
       
 (* cap heading *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PTXHD]);
       
 (* borders *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PBRDR]);
       
 (* as of date line *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* horizontal grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PBRDR]);
      
 (* major vertical grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* minor vertical grid *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* open summary task data text *)
    WriteCardinal(TLGSColorInfo^.ColorFor[POPST]);
       
 (* all other task data text *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PAOTK]);
       
 (* axis background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PBKHD]);
       
 (* data column background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
      
 (* plot background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PBKCH]);
       
 (* page background *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PPAGE]);
      
 (* open summay task bar future *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* open summary task bar achievement *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
     
 (* all other task bar future *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
      
 (* all other task bar achievement *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* baseline bar *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* future milestone *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* complete milestone *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* slack *)
    WriteCardinal(TLGSColorInfo^.ColorFor[NOTUSED]);
       
 (* dependency lines *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PPTDP]);
       
 (* highlight filter 3 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PF1FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[PF1BG]);
       
 (* highlight filter 4 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PF2FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[PF2BG]);
       
 (* highlight filter 5 *)
    WriteCardinal(TLGSColorInfo^.ColorFor[PF3FG]);
    WriteCardinal(TLGSColorInfo^.ColorFor[PF3BG]);
       
END WriteNetworkColorSelections;

       
(*--------------------------------------------------------------------------*)
        (*  
            WriteColorSelections 
         *)
         
PROCEDURE WriteColorSelections();

VAR
    TLGSColorInfo : ATLGSColorAssignmentPtr;
    ColorNode     : ATreeNode;
    GanttRecord   : ATLGSGanttRecordPtr;
    PertRecord    : ATLGSPertRecordPtr;
    TreeRecord    : ATLGSTreeRecordPtr;
    s             : ARRAY [0..255] OF CHAR;
    
BEGIN

 (* tag *)
    SetString(s,"COLORSELECTIONS");
    WriteToTLGSFile(s);
    
 (* look for a color selection holder record *)   
    IF (ChartType = GANTT) THEN                                   (* 15-Jun-89 LAA *)
        GanttRecord := TLGSGanttRecord(0.0);
        ColorNode := FindPaletteByName(TLGSGanttChart, GanttRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN                      (* 01-Dec-89 LAA *)
            ColorNode := DefaultPalette[TLGSGanttChart];
        END;
    ELSIF (ChartType = TREE) THEN
        TreeRecord := TLGSTreeRecord();
        ColorNode := FindPaletteByName(TLGSTreeChart, TreeRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN
            ColorNode := DefaultPalette[TLGSTreeChart];
        END;
    ELSE			
        PertRecord := TLGSPertRecord();
        ColorNode := FindPaletteByName(TLGSPertChart, PertRecord^.Palette);
        IF (ColorNode = ATreeNode(NIL)) THEN
            ColorNode := DefaultPalette[TLGSPertChart];
        END;
    END; 

    TLGSColorInfo := ColorNode^.Methods^.LockFlexStorDataObject(ColorNode);

    IF (TLGSColorInfo <> NIL) THEN
        IF (ChartType = GANTT) THEN
            WriteGanttColorSelections(TLGSColorInfo);
        ELSIF (ChartType = TREE) THEN
            WriteNetworkColorSelections(TLGSColorInfo);
        ELSE			
            WriteNetworkColorSelections(TLGSColorInfo);
        END; 
     
    ELSE
    
     (* title and legend *)
        WriteCardinal(1);
       
     (* notes *)
        WriteCardinal(1);
       
     (* borders *)
        WriteCardinal(1);
       
     (* today line *)
        WriteCardinal(3);
       
     (* horizontal grid *)
        WriteCardinal(1);
       
     (* major vertical grid *)
        WriteCardinal(1);
       
     (* minor vertical grid *)
        WriteCardinal(1);
       
     (* open summary task data text *)
        WriteCardinal(1);
       
     (* all other task data text *)
        WriteCardinal(1);
       
     (* axis background *)
        WriteCardinal(21);
       
     (* data column background *)
        WriteCardinal(2);
       
     (* plot background *)
        WriteCardinal(2);
       
     (* page background *)
        WriteCardinal(22);
       
     (* open summary task duration bar future *)
        WriteCardinal(15);
       
     (* open summary task duration bar complete *)
        WriteCardinal(16);
       
     (* all other task duration bar future *)
        WriteCardinal(15);
       
     (* all other task duration bar complete *)
        WriteCardinal(16);
       
     (* baseline duration bar *)
        WriteCardinal(19);
       
     (* future milestone *)
        WriteCardinal(11);
       
     (* complete milestone *)
        WriteCardinal(16);
       
     (* slack *)
        WriteCardinal(6);
       
     (* dependency lines *)
        WriteCardinal(1);
       
     (* highlight filter 3 *)
        WriteCardinal(19);
        WriteCardinal(2);
       
     (* highlight filter 4 *)
        WriteCardinal(6);
        WriteCardinal(2);

     (* highlight filter 5 *)
        WriteCardinal(4);
        WriteCardinal(2);
       
    END;
       
    ColorNode^.Methods^.UnlockUnchangedDataObject(ColorNode);

END WriteColorSelections;


(*--------------------------------------------------------------------------*)

BEGIN                       (* ColorTLGS *)

END ColorTLGS.
