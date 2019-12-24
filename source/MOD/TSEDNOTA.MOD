IMPLEMENTATION MODULE TSEDNotation;

    (*  MODIFICATION HISTORY --
        29-May-89 LAA   Adjusted for the TitleBlock being stored in FlexStor.
         1-Jul-89 CMH   Fixed title vertical size calculation.
        26-Jul-89 CMH   Fixed title vertical size calculation for titles
                        including blank lines.
        14-Aug-89 CMH   Use new gap constant in border size calculations.
        23-Aug-89 AJL   Changed GAP_FOR_NOTATION to GAPFORNOTATION. 
                        Translate keywords in title and legend.
         8-Sep-89 CMH   Using new WriteCardinal procedure, added LJust
                        and TrimRear of title and note strings since
                        MakeSubstitutions pads with blanks.
        22-Sep-89 CMH   Added new variable for independant font height.
    *)

FROM FontTLGS               IMPORT
    (* VAR *)                   FontHeight;                

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATextLine, ATLGSScale, ATLGSChartType,
                                ATLGSTitlePlacement, ATLGSTitleBlockPtr,
                                ATLGSTitleBlock,
    (* PROC *)                  LockTLGSTitleBlock, UnlockTLGSTitleBlock;
    
FROM JustificationTLGS	    IMPORT
    (* CONST *)			LEFT,
    				CENTERED,
    				RIGHT;
    				
FROM KeywdSub               IMPORT
    (* PROC *)                     MakeSubstitutions;

FROM LStrings		    IMPORT
    (* PROC *) 			Copy, LJust, SetString, TrimRear;
    
FROM PositionTLGS	    IMPORT
    (* CONST *)			TL, TC, TR,
    				BL, BC, BR;

IMPORT SchedKey;

FROM TSEDData		    IMPORT
    (* CONST *)  		GANTT, 	
    		  		TREE,  	
    				
    (* VAR *)			ChartType;
    
FROM TSEDObjectWrite	    IMPORT
    (* PROC *)			WriteCardinal;
                                
FROM TSEDWrite		    IMPORT
    (* PROC *)		     	WriteToTLGSFile;


(*--------------------------------------------------------------------------*)

PROCEDURE ConvertedChartType(): ATLGSChartType;

VAR
    Client                  : ATLGSChartType;

BEGIN                       (* ConvertedChartType *)
    
    IF (ChartType = GANTT) THEN	
        Client := TLGSGanttChart;
    ELSIF (ChartType = TREE) THEN
        Client := TLGSTreeChart;
    ELSE			
        Client := TLGSPertChart;
    END; 

    RETURN Client;

END ConvertedChartType;


        (*  
            
         *)
         
PROCEDURE LockTitlePointer(): ATLGSTitleBlockPtr;

BEGIN        
   
    RETURN (LockTLGSTitleBlock(ConvertedChartType()));            (* 29-May-89 LAA *)
    
END LockTitlePointer;





PROCEDURE UnlockTitlePointer();

BEGIN                       (* UnlockTitlePointer *)

    UnlockTLGSTitleBlock(ConvertedChartType());

END UnlockTitlePointer;



(*--------------------------------------------------------------------------*)
        (*  
            GetNotationPosition
         *)
         
PROCEDURE GetNotationPosition(TLGSNotationPlacement : ATLGSTitlePlacement) : CARDINAL;

VAR 
    Placement : CARDINAL;
    
BEGIN        
    CASE TLGSNotationPlacement OF
         SUpCenter  : Placement := TC; (* top center *)
       | SUpRight   : Placement := TR; (* top right *)
       | SLowLeft   : Placement := BL; (* bottom left *)
       | SLowCenter : Placement := BC; (* bottom center *)
       | SLowRight  : Placement := BR; (* bottom right *)
    ELSE
         Placement := TL; (* top left *)
    END;
    
    RETURN (Placement);
    
END GetNotationPosition;


(*--------------------------------------------------------------------------*)
        (*  
            NotateAChart
                        
            Write title and legend (user notes) to TLGS interface file.
         *)
         
PROCEDURE NotateAChart(LegendHeight : CARDINAL);

VAR 
    TLGSTitleInfo      : ATLGSTitleBlockPtr;
    i,
    NumberOfLines,
    height,
    x, y               : CARDINAL;
    TotalTopHeight,
    TotalBottomHeight,
    TitleHeight,
    NotesHeight,
    NewCharacterHeight : CARDINAL;
    TempReal           : REAL;
    TextFound          : BOOLEAN;
    s  		       : ARRAY [0..255] OF CHAR;

BEGIN        

    TitleHeight:= 0;
    NotesHeight:= 0;
    TotalTopHeight:= 0;
    TotalBottomHeight:= 0;
    
    TLGSTitleInfo:= LockTitlePointer();
 
    IF (TLGSTitleInfo^.ExistTitle) THEN
           
    	 (* tag *)
     	    SetString(s,"TITLE");
            WriteToTLGSFile(s);
    
         (* number of lines of text in the title *)   
            NumberOfLines:= 0;
            TextFound:= FALSE;
            FOR i:= 3 TO 1 BY -1 DO 
                IF (ORD(TLGSTitleInfo^.Title[i].LineOfText[0]) > 0) THEN
                    INC(NumberOfLines);
                    TextFound:= TRUE;
                ELSIF (TextFound) THEN
                   INC(NumberOfLines);
                END;
            END;
            WriteCardinal(NumberOfLines);
        
         (* title text *)
            FOR i:= 1 TO NumberOfLines DO 
                IF (ORD(TLGSTitleInfo^.Title[i].LineOfText[0]) > 0) THEN
                    Copy(TLGSTitleInfo^.Title[i].LineOfText,s);
                ELSE
                    SetString(s," ");
                END;
                MakeSubstitutions(s,HIGH(TLGSTitleInfo^.Title[1].LineOfText),SchedKey.GetKeyWordValue,NIL);
                LJust(s);
                TrimRear(s);
                WriteToTLGSFile(s);
                IF (i=1) THEN
                    NewCharacterHeight:= TRUNC(1.5*FLOAT(FontHeight));
                ELSE
                    NewCharacterHeight:= TRUNC(1.2*FLOAT(FontHeight));
                END;
                TitleHeight:= TitleHeight + NewCharacterHeight + FontHeight;
            END;
         
         (* title position *)
            WriteCardinal(GetNotationPosition(TLGSTitleInfo^.TitlePlace));
               
         (* title justification *)
            WriteCardinal(CENTERED);
        
         (* title height *)
            WriteCardinal(TitleHeight);
        
         (* border height *)  
            IF ((TLGSTitleInfo^.TitlePlace = SUpLeft) OR
                (TLGSTitleInfo^.TitlePlace = SUpCenter) OR
                (TLGSTitleInfo^.TitlePlace = SUpRight)) THEN
                IF (TitleHeight > TotalTopHeight) THEN
                    TotalTopHeight:= TitleHeight;
                END;  
            ELSE 
                IF (TitleHeight > TotalBottomHeight) THEN
                    TotalBottomHeight:= TitleHeight;
                END;  
            END;

    END;  (* title exists *)
    
    
    IF (TLGSTitleInfo^.ExistLegend) THEN  (* user notes *)
           
         (* tag *)
            SetString(s,"NOTES");
            WriteToTLGSFile(s);

         (* number of lines of text in the note *)   
            NumberOfLines:= 0;
            TextFound:= FALSE;
            FOR i:= 5 TO 1 BY -1 DO 
                IF (ORD(TLGSTitleInfo^.Legend[i].LineOfText[0]) > 0) THEN
                    INC(NumberOfLines);
                    TextFound:= TRUE;
                ELSIF (TextFound) THEN
                   INC(NumberOfLines);
                END;
            END;
            WriteCardinal(NumberOfLines);

         (* note text *)
            FOR i:= 1 TO NumberOfLines DO 
                IF (ORD(TLGSTitleInfo^.Legend[i].LineOfText[0]) > 0) THEN
                    Copy(TLGSTitleInfo^.Legend[i].LineOfText,s);
                ELSE    
                    SetString(s," ");
                END;
                NotesHeight:= NotesHeight + FontHeight*2;
                MakeSubstitutions(s,HIGH(TLGSTitleInfo^.Legend[1].LineOfText),SchedKey.GetKeyWordValue,NIL);
                LJust(s);
                TrimRear(s);
                WriteToTLGSFile(s);
            END;
        
         (* note position *)
            WriteCardinal(GetNotationPosition(TLGSTitleInfo^.LegendPlace));
               
         (* note justification *)
            WriteCardinal(LEFT);
            
         (* note height *)
            WriteCardinal(NotesHeight);
        
         (* border height *)  
            IF ((TLGSTitleInfo^.LegendPlace = SUpLeft) OR
                (TLGSTitleInfo^.LegendPlace = SUpCenter) OR
                (TLGSTitleInfo^.LegendPlace = SUpRight)) THEN
                 IF (NotesHeight > TotalTopHeight) THEN
                     TotalTopHeight:= NotesHeight;
                 END;  
            ELSE
                 IF (NotesHeight > TotalBottomHeight) THEN
                     TotalBottomHeight:= NotesHeight;
                 END;  
            END;

    END;  (* legend (user notes) exists *)


    IF (TLGSTitleInfo^.ExistSymbol) THEN  (* legend *)
           
         (* tag *)
            SetString(s,"LEGEND");
            WriteToTLGSFile(s);
        
         (* legend position *)
            WriteCardinal(GetNotationPosition(TLGSTitleInfo^.SymbolPlace));

         (* legend height *)
            WriteCardinal(LegendHeight);
            
         (* border height *)  
            IF ((TLGSTitleInfo^.SymbolPlace = SUpLeft) OR
                (TLGSTitleInfo^.SymbolPlace = SUpCenter) OR
                (TLGSTitleInfo^.SymbolPlace = SUpRight)) THEN
                 IF (LegendHeight > TotalTopHeight) THEN
                     TotalTopHeight:= LegendHeight;
                 END;  
            ELSE
                 IF (LegendHeight > TotalBottomHeight) THEN
                     TotalBottomHeight:= LegendHeight;
                 END;  
            END;
            
    END;   (* symbols (legend) exists *) 

    UnlockTitlePointer();                                         (* 29-May-89 LAA *)

    IF (TotalTopHeight > 0) THEN
        TotalTopHeight:= TotalTopHeight + GAPFORNOTATION;
    END;
    IF (TotalBottomHeight > 0) THEN
        TotalBottomHeight:= TotalBottomHeight + GAPFORNOTATION;
    END;

END NotateAChart;


(*--------------------------------------------------------------------------*)
        (*  
            BorderSizeCalc
         *)
         
PROCEDURE BorderSizeCalc(LegendHeight : CARDINAL; VAR TotalTopHeight,TotalBottomHeight:CARDINAL);

VAR 
    TLGSTitleInfo      : ATLGSTitleBlockPtr;
    i,
    NumberOfSubtitles,
    NumberOfLines,
    height,
    x, y               : CARDINAL;
    TitleHeight,
    NotesHeight,
    NewCharacterHeight : CARDINAL;
    TempReal           : REAL;
    TextFound          : BOOLEAN;
    s  		       : ARRAY [0..255] OF CHAR;

BEGIN        

    TitleHeight:= 0;
    NotesHeight:= 0;
    TotalTopHeight:= 0;
    TotalBottomHeight:= 0;
    
    TLGSTitleInfo:= LockTitlePointer();
    
    IF (TLGSTitleInfo^.ExistTitle) THEN
           
         (* number of lines of text in the title *)   
            NumberOfLines:= 0;
            TextFound:= FALSE;
            FOR i:= 3 TO 1 BY -1 DO 
                IF (ORD(TLGSTitleInfo^.Title[i].LineOfText[0]) > 0) THEN
                    INC(NumberOfLines);
                    TextFound:= TRUE;
                ELSIF (TextFound) THEN
                   INC(NumberOfLines);
                END;
            END;

        
         (* title text height *)
            IF (NumberOfLines > 1)THEN
                NumberOfSubtitles:=NumberOfLines-1;
                TitleHeight:= (TRUNC(1.2*FLOAT(FontHeight))*
                              NumberOfSubtitles);
            END;
            IF (NumberOfLines >= 1) THEN
                TempReal:= 1.5*FLOAT(FontHeight);
                TitleHeight:= TitleHeight + TRUNC(TempReal);
            END;
            
            TitleHeight:=  TitleHeight + FontHeight*NumberOfLines; (* 1-Jul-89 CMH *)
            
         (* border height *)  
            IF ((TLGSTitleInfo^.TitlePlace = SUpLeft) OR
                (TLGSTitleInfo^.TitlePlace = SUpCenter) OR
                (TLGSTitleInfo^.TitlePlace = SUpRight)) THEN
                IF (TitleHeight > TotalTopHeight) THEN
                    TotalTopHeight:= TitleHeight;
                END;  
            ELSE 
                IF (TitleHeight > TotalBottomHeight) THEN
                    TotalBottomHeight:= TitleHeight;
                END;  
            END;

    END;  (* title exists *)
    
    
    IF (TLGSTitleInfo^.ExistLegend) THEN  (* user notes *)
           
         (* number of lines of text in the note *)   
            NumberOfLines:= 0;
            TextFound:= FALSE;
            FOR i:= 5 TO 1 BY -1 DO 
                IF (ORD(TLGSTitleInfo^.Legend[i].LineOfText[0]) > 0) THEN
                    INC(NumberOfLines);
                    TextFound:= TRUE;
                ELSIF (TextFound) THEN
                   INC(NumberOfLines);
                END;
            END;

         (* note text height *)
            NotesHeight:= NumberOfLines * FontHeight*2;
        
         (* border height *)  
            IF ((TLGSTitleInfo^.LegendPlace = SUpLeft) OR
                (TLGSTitleInfo^.LegendPlace = SUpCenter) OR
                (TLGSTitleInfo^.LegendPlace = SUpRight)) THEN
                 IF (NotesHeight > TotalTopHeight) THEN
                     TotalTopHeight:= NotesHeight;
                 END;  
            ELSE
                 IF (NotesHeight > TotalBottomHeight) THEN
                     TotalBottomHeight:= NotesHeight;
                 END;  
            END;

    END;  (* user notes exists *)


    IF (TLGSTitleInfo^.ExistSymbol) THEN  (* legend *)
           
         (* border height *)  
            IF ((TLGSTitleInfo^.SymbolPlace = SUpLeft) OR
                (TLGSTitleInfo^.SymbolPlace = SUpCenter) OR
                (TLGSTitleInfo^.SymbolPlace = SUpRight)) THEN
                 IF (LegendHeight > TotalTopHeight) THEN
                     TotalTopHeight:= LegendHeight;
                 END;  
            ELSE
                 IF (LegendHeight > TotalBottomHeight) THEN
                     TotalBottomHeight:= LegendHeight;
                 END;  
            END;
            
    END; (* symbols (legend) exists *) 

    UnlockTitlePointer();                                         (* 29-May-89 LAA *)

    IF (TotalTopHeight > 0) THEN
        TotalTopHeight:= TotalTopHeight + GAPFORNOTATION;
    END;
    IF (TotalBottomHeight > 0) THEN
        TotalBottomHeight:= TotalBottomHeight + GAPFORNOTATION;
    END;

END BorderSizeCalc;


(*--------------------------------------------------------------------------*)
        (*  
          CheckForTitle
         *)
         
PROCEDURE CheckForTitle() : BOOLEAN;

VAR 
    TLGSTitleInfo           : ATLGSTitleBlockPtr;
    Exists                  : BOOLEAN;

BEGIN        

    TLGSTitleInfo:= LockTitlePointer();                           (* 29-May-89 LAA *)
    Exists := TLGSTitleInfo^.ExistTitle;
    UnlockTitlePointer();

    RETURN Exists;
           
END CheckForTitle;


(*--------------------------------------------------------------------------*)
        (*  
          CheckForNotes
         *)
         
PROCEDURE CheckForNotes() : BOOLEAN;

VAR 
    TLGSTitleInfo           : ATLGSTitleBlockPtr;
    Exists                  : BOOLEAN;

BEGIN        

    TLGSTitleInfo:= LockTitlePointer();                           (* 29-May-89 LAA *)
    Exists := TLGSTitleInfo^.ExistLegend;
    UnlockTitlePointer();

    RETURN Exists;
           
END CheckForNotes;


(*--------------------------------------------------------------------------*)
        (*  
          CheckForLegend
         *)
         
PROCEDURE CheckForLegend() : BOOLEAN;

VAR 
    TLGSTitleInfo           : ATLGSTitleBlockPtr;
    Exists                  : BOOLEAN;

BEGIN        

    TLGSTitleInfo:= LockTitlePointer();                           (* 29-May-89 LAA *)
    Exists := TLGSTitleInfo^.ExistSymbol;
    UnlockTitlePointer();

    RETURN Exists;
           
END CheckForLegend;

(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDNotation *)


END TSEDNotation.
