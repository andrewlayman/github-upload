IMPLEMENTATION MODULE TSEDObjectWrite;

   (*
    Modification History:
         8-Sep-89 CMH   Added new WriteBoolean, WriteCardinal, WriteReal
                        procedures.  
                        Renamed APageDescription to PageDescription and 
                        ASetupDescription to SetupDescription.
        16-Oct-89 CMH   Tell TLGS the mono board type is hercules.
        15-Nov-89 CMH   Added new screen driver types.
        17-Nov-89 CMH   Further to previous modification.
        23-Sep-90 PHR   Write reals as reals, with decimal point.
        12-Nov-90 TGS   Made the change I think PHR wanted to make, but
                        didn't (the change comment was not accompanied by
                        any changes). Changed the WriteCardinal(TRUNC(..))
                        statements to WriteReal(..).
    *)

FROM ColorTLGS		    IMPORT
    (* VAR *)	    		AllOtherDataColor;
    
(* for duration bar networks - not avaliable in TL version 4.0  
 |   				BaseLineBarColor;
 *)
 
FROM IlsaStatic             IMPORT
    (* TYPE *)             	ATLGSSetupRecord,
    	                        ATLGSSetupRecordPtr,
                 		ATLGSPageRecord,
    	                        ATLGSPageRecordPtr,
    (* PROC *)	                TLGSSetupRecord,
        	                TLGSPageRecord;
    
FROM LStrings               IMPORT
    (* PROC *)                  ConcatLS, CtoS, SetString;
    
FROM RealFormat             IMPORT 
     (* PROC *)                 RealToLStrings;

FROM TSEDData 		    IMPORT
    (* CONST *)			GANTT,
    				TREE,
    (* VAR *)			RealCharacterHeight;
    				
FROM TSEDWrite		    IMPORT
    (* PROC *)			WriteToTLGSFile;
    				
FROM VidType		    IMPORT
    (* TYPE *)                  ABoardType, ATubeType, AVideoConfiguration,
    (* VAR *)                   VideoConfiguration;
    
    
(*--------------------------------------------------------------------------*)
        (*  
            WriteBoolean
            
            Write a boolean value as 1 or 0  to TLGS interface file.
         *)
         
PROCEDURE WriteBoolean(BooleanValue : BOOLEAN);

BEGIN
    
    IF (BooleanValue) THEN	
        WriteCardinal(1);
    ELSE 
        WriteCardinal(0);
    END;
    
END WriteBoolean;


(*--------------------------------------------------------------------------*)
        (*  
            WriteBox
            
            Write task to TLGS interface file.
            Format:
             BOX          -- class tag
             x1,y1        -- box position
             x2,y2
             frame type   
             box contents  -- task information for each field used for normal tasks
         *)
         
PROCEDURE WriteBox(x1, y1, x2, y2, frame : CARDINAL; 
                   BoxContents           : ARRAY OF CHAR;
                   FGColor,BGColor       : CARDINAL);


VAR 
 
    s                 : ARRAY [0..255] OF CHAR;

BEGIN        

 (* object tag *)
    SetString(s,"BOX");
    WriteToTLGSFile(s);
  
 (* matrix location, lower left corner of box *)
    WritePoint(x1,y1);

 (* matrix location, upper right corner of box *)
    WritePoint(x2,y2);

 (* frame type *)
    WriteCardinal(frame);

 (* frame color *)
    WriteCardinal(FGColor);
    
 (* Background Color *)
    WriteCardinal(BGColor);

 (* box contents - text *) 
    WriteText(BoxContents,AllOtherDataColor,RealCharacterHeight);
    
END WriteBox;


(*--------------------------------------------------------------------------*)
        (*  
            WriteCardinal
            
            Write a cardinal value to TLGS interface file.
         *)
         
PROCEDURE WriteCardinal(CardinalValue : CARDINAL);

VAR
    s : ARRAY [0..255] OF CHAR;
    
BEGIN
    
    CtoS(CardinalValue,s);			
    WriteToTLGSFile(s);
    
END WriteCardinal;


(*--------------------------------------------------------------------------*)
        (*  
            WriteChartType

            Write chart type to TLGS interface file.
            Format:
             CHARTTYPE   -- class tag
             type        -- chart type
            
         *)
         
PROCEDURE WriteChartType(type : CARDINAL);
    
VAR 
    s : ARRAY[0..255] OF CHAR;

BEGIN
    IF (type = TREE) THEN
        SetString(s,"TREE");
    ELSIF (type = GANTT) THEN
        SetString(s,"GANTT");
    ELSE
        SetString(s,"NETWORK");
    END;    
    WriteToTLGSFile(s);
        
END WriteChartType;
  

(*--------------------------------------------------------------------------*)
        (*  
            WriteCrateHeight
            
            Write drawing dimensions to TLGS interface file.
            Format:
             CRATEHEIGHT
             number
         *)
         
PROCEDURE WriteCrateHeight(height:CARDINAL);

VAR
    s   : ARRAY [0..255] OF CHAR;
      
BEGIN        

    SetString(s,"HEIGHTOFCRATE");
    WriteToTLGSFile(s);
   
 (* height *)
    WriteCardinal(height);
    
END WriteCrateHeight;


(*--------------------------------------------------------------------------*)
        (*  
            WriteDeviceInformation
         *)
         
PROCEDURE WriteDeviceInformation();

VAR
    SetupDescription : ATLGSSetupRecordPtr;
    PageDescription  : ATLGSPageRecordPtr;
      
BEGIN        

    SetupDescription:= TLGSSetupRecord();
    PageDescription:= TLGSPageRecord();

 (* actual plot x *)
    WriteReal(SetupDescription^.PlotAreaWide); (* 12-Nov-90 TGS *)
(*  WriteCardinal(TRUNC(SetupDescription^.PlotAreaWide)); *)
    
 (* actual plot y *)
    WriteReal(SetupDescription^.PlotAreaHigh); (* 12-Nov-90 TGS *)
(*  WriteCardinal(TRUNC(SetupDescription^.PlotAreaHigh)); *)
    
 (* continuous feed  *)
    WriteBoolean(SetupDescription^.ContinuousPrint);
    
 (* rotate *)
    WriteBoolean(PageDescription^.Rotated);
    
 (* screen driver *)
    IF (VideoConfiguration.AutoDetect) THEN
        IF (VideoConfiguration.TubeType = ColorTube) THEN
            WriteCardinal(0);
        ELSE
            WriteCardinal(50);
        END;
    ELSE
        CASE VideoConfiguration.BoardType OF
        
             MonoBoard           : WriteCardinal(2);(* treat mono like herc *)
          
           | CompaqPortableBoard,
             GenericColorBoard, 
             CGABoard            : WriteCardinal(3);
          
           | MCGABoard           : WriteCardinal(4);
          
           | EGABoard            : IF (VideoConfiguration.TubeType = ColorTube) THEN
                                       WriteCardinal(5);
                                   ELSE
                                       WriteCardinal(10);
                                   END;
          
           | VGABoard            : IF (VideoConfiguration.TubeType = ColorTube) THEN
                                       WriteCardinal(6);
                                   ELSE
                                       WriteCardinal(11);
                                   END;
          
           | ATTBoard            : IF (VideoConfiguration.TubeType = ColorTube) THEN
                                       WriteCardinal(8);
                                   ELSE
                                       WriteCardinal(9);
                                   END;
        ELSE (* use auto detect *)
             IF (VideoConfiguration.TubeType = ColorTube) THEN
                 WriteCardinal(0);
             ELSE
                 WriteCardinal(50);
             END;
        END;
    END;
    
END WriteDeviceInformation;


(* for duration bar networks - not avaliable in TL version 4.0  
 |(*--------------------------------------------------------------------------*)
 |       (*  
 |           WriteDurationBar
 |           
 |           Write duration bar to TLGS interface file.
 |           Format:
 |            	DURATIONBAR	-- class tag
 |   		x1 Plan
 |   		x2 Plan
 |   		Plan Bar Thickness
 |   		Plan Bar Color
 |   		x1 Actual
 |   		x2 Actual
 |   		Actual Bar Thickness
 |   		Actual Bar Color
 |   		y at Center Line
 |   		left edge of middle block
 |   		right edge of middle block
 |   		List of Pipes  (connect to crate)         
 |        *)
 |
 |PROCEDURE WriteDurationBar(x1Plan, x2Plan,
 |			   x1Actual, x2Actual,
 |			   yDBarCenterLine,
 |			   complete,
 |			   CompleteBarColor,
 |			   FutureBarColor       : CARDINAL);
 |
 |VAR 
 |    s                   : ARRAY [0..255] OF CHAR;
 |    
 |BEGIN        
 |
 | (* object tag *)
 |    SetString(s,"DURATIONBAR");
 |   WriteToTLGSFile(s);
 |   
 |   IF (ShowBaseLineBars) THEN  
 |    (* number of bars to draw *)
 |       WriteCardinal(2);
 |
 |    (* x1 planned *)
 |       WriteCardinal(x1Plan);
 |
 |    (* x2 planned *)
 |       WriteCardinal(x2Plan);
 | 
 |    (* bar thickness planned *)
 |       WriteCardinal(PlanBarThickness);
 |
 |    (* bar color planned *)
 |       WriteCardinal(BaseLineBarColor);
 |   ELSE
 |    (* number of bars to draw *)
 |       WriteCardinal(1);
 |
 |   END;
 |      
 |(* x1 actual *)
 |   WriteCardinal(x1Actual);
 |
 |(* x2 actual *)
 |   WriteCardinal(x2Actual);
 |
 |(* bar thickness actual *)
 |   WriteCardianl(ActualBarThickness);
 |
 |(* bar color complete actual *)
 |   WriteCardinal(CompleteBarColor);
 |   
 |(* bar color future actual *)
 |   WriteCardinal(FutureBarColor);
 |   
 | (* y center line of both plan and actual bars *)
 |    WriteCardinal(yDBarCenterLine);
 |
 |(* percent complete *)
 |   WriteCardinal(complete);
 |
 |END WriteDurationBar;
 |
 *)


(*--------------------------------------------------------------------------*)
        (*  
            WritePipe

            Write pipe to TLGS interface file.
            Format:
                    PIPE        - Tag
                    x1, y1,
                    x2, y2	- position
                    r1, r2      - radius at ends
                    width       - width of the pipe lines
                    style       - pipe style (line, tube etc.)
                    pattern     - line pattern 
                    highlight   - line drop shadow
                    color       - line color
            
         *)
         
PROCEDURE WritePipe(x1, y1, x2, y2, r1, r2, width, style, pattern, highlight, color:CARDINAL); 
    
VAR 
    s : ARRAY[0..255] OF CHAR;
   
BEGIN    

 (* object tag *)
    SetString(s,"PIPE");
    WriteToTLGSFile(s);
   
 (* pipe position *)
    WritePoint(x1,y1);
    WritePoint(x2,y2);
    
 (* pipe radius *)
    WriteCardinal(r1);
    WriteCardinal(r2);
                 
 (* pipe width *)
    WriteCardinal(width);
                 
 (* pipe style *)
    WriteCardinal(style);
                 
 (* pipe pattern *)
    WriteCardinal(pattern);

 (* write highlight *)  
    WriteCardinal(highlight);
                     
 (* write color *)  
    WriteCardinal(color);
                     
END WritePipe;


(*--------------------------------------------------------------------------*)
        (*  
            WritePoint
            
         *)
         
PROCEDURE WritePoint(x,y:CARDINAL);

VAR 
    comma,
    blank       : ARRAY [0..2] OF CHAR;
    string1     : ARRAY[0..80] OF CHAR;
    string2     : ARRAY[0..80] OF CHAR;
       
BEGIN
        
    SetString(comma,",");
    SetString(blank," ");
    SetString(string1," ");
    SetString(string2," ");

 (* x,y -- a point *)
    CtoS(x,string1);
    ConcatLS(string1,comma);
    CtoS(y,string2);
    ConcatLS(string1,string2);
    ConcatLS(string1,blank); 
    WriteToTLGSFile(string1);
                           
END WritePoint;


(*--------------------------------------------------------------------------*)
        (*  
            WriteReal
            
            Write a real value to TLGS interface file.
         *)
         
PROCEDURE WriteReal(RealValue : REAL);

VAR
   s, s2 : ARRAY [0..255] OF CHAR;
   
BEGIN
    
    RealToLStrings(RealValue,0,8,s,s2);                (* drawing height *)
    WriteToTLGSFile(s);
    
END WriteReal;


(*--------------------------------------------------------------------------*)
        (*  
            WriteText
            
            Write text to TLGS interface file.
            Format:
             TEXT          -- class tag
             string
             text color
         *)
         
PROCEDURE WriteText(string        : ARRAY OF CHAR; 
                    color, height : CARDINAL);

VAR 
    s : ARRAY [0..255] OF CHAR;
   
BEGIN       
 
 (* object tag *)
    SetString(s,"TEXT");
    WriteToTLGSFile(s);
 
 (* string *)
    WriteToTLGSFile(string);

 (* color *)
    WriteCardinal(color);
 
 (* height *)
    WriteCardinal(height);
 
END WriteText;



(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDObjectWrite *)


END TSEDObjectWrite.

