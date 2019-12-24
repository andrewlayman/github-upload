IMPLEMENTATION MODULE NetPrint;

    (*  MODIFICATION HISTORY
        19-Oct-88 CMH   Added call to new DrawMasterTaskExtension, a utility
                        to get either master task outline charaters or an 
                        extended master task name characters. 
        06-Jun-89 KKC - Print Select filter and highlight filters.
        28-Jun-89 CMH - Removed ChildrenCruncher and InitSnetMatrix 
                        procedures, moved SnetColOne and SnetRowOne
                        to be imported from NetStatic, added critical 
                        path dependency line highlight support.    
        10-Jul-89 EGK   Print a banner only on the first page (strip).
        14-Jul-89 EGK   Get footer text from the phrase file.  Removed
                        redundant calls to DrawMasterTaskExtension.
        31-Jul-89 EGK   Put back call to DrawMasterTaskExtension, to handle
                        cases where the master task column is not on the
                        page.
        25-Jul-89 CMH   Now importing ALLOCATE, DEALLOCATE from Space.
         5-Sep-89 CMH   Added a blank row after the filter notes.
         6-Sep-89 CMH   Moved FillPrinterBuffer here from NetUtility.
         7-Sep-89 CMH   Moved PrintBuffer, FillPrinterBuffer to NetTaskDraw.
        26-Nov-89 EGK   In PrintNetwork, put in a check for whether
                        NormalLayoutActive is set, and use either the normal
                        or alternate layout as appropriate.
        05-Feb-90 EGK   Removed unused imports from NetCharacters.
        2-Jul-91  AJL - Added parameters to FilterNotes.
    *)

FROM AccessMatrix	    IMPORT
    (* CONST *)                 COLORBIAS,
    (* PROC *)		 	GetCellInfo;
    
FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree,ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol, maxrow,
    (* PROC *)                  PutString, GetAnyCode;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, SetString, CtoS, Procustes, 
                                ConcatLS, Insert, LJust, Overlay, SetLengthOf;

FROM MsgFile                IMPORT GetMessage;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank,
                                HBar2,
                                VBar1,
                                pdash,
                                UpArrow,
                                DownArrow;
                                
FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NormalLayoutActive,
    (* PROC *)                  GetNormalNetLayout, GetBigNetLayout;

FROM NetStatic              IMPORT
    (* TYPE *)                  DiagramView,
                                DiagramTask,
    (* VAR *)                   SnetRows, SnetCols, 
                                SnetRowOne,    SnetColOne,
                                SnetHeight, SnetWidth, 
                                ViewType, loopnode;    
     
FROM NetTaskDraw            IMPORT
    (* CONST *)                 MaxBufferLines,
    (* VAR *)                   PrintBuffer,
    (* PROC *)                  BoxExpand,
                                FillPrinterBuffer,
                                DrawMasterTaskExtension;

FROM NetUtility             IMPORT
    (* CONST *)                 ToScreen, ToPrinter,
                                NormalLayout,  EnlargedLayout, 
    (* VAR *)                   BoxLayout, 
                                BoxWidth,
                                SnetRowMin,    SnetRowMax,
                                SnetColMin,    SnetColMax,
                                SnetChars,
                                ExpandedSnetHeight, ExpandedSnetWidth,
    (* PROC *)                  MasterTaskCheck,
                                GetMasterTaskLabel,
                                GetOutlineType, GetBoxSize, GetHorizMax,
                                GetVertMax, GetPad,
                                ISnetChars, InitSnetHandW;

FROM PrintCaptions          IMPORT
    (* PROC  *)                 FilterNotes, PageHead;

FROM PrintStatic            IMPORT
                                APrinterStyle, PrintXLAT;
                                      
FROM PrintSupport           IMPORT
    (* VAR *)                   Stopped,
    (* PROC *)                  AllowLeftMargin, AllowUnlimitedPageLength, 
                                EndReport, PageWidth, PageTop, PrintLine,
                                StartPage, StartReport, CheckForTranslation,
                                RowsLeft;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;   (* 25-Jul-89 CMH *) 

CONST
    ULX = 0;
    ULY = 4;
    ULYMAX = 23;
    ModuleNumber = 20375;
VAR
    
    MaxPaperWidth : INTEGER;
    UpChar,     
    DownChar      : CHAR;
    DateRow1      : CARDINAL;
    BlankLine     : ARRAY [0..1] OF CHAR;
    layout        : ANetworkLayout;

(*--------------------------------------------------------------------------*)

        (*  
            PrintNetwork is the main procedure used to print
            a network diagram.
         *)


PROCEDURE PrintNetwork();

VAR
    HorizSectionsDone,
    VertSectionsDone    : BOOLEAN;
    s,s2,s3             : ARRAY [0..255] OF CHAR;
    PageNumber          : CARDINAL;
    MaxY                : INTEGER;
     
BEGIN

    IF StartReport() THEN   
       
       MaxPaperWidth:= PageWidth();
       IF MaxPaperWidth > 255 THEN
          MaxPaperWidth:= 255;
          END;

        IF NormalLayoutActive THEN              (* 11/26/89 EGK *)
            BoxLayout:= NormalLayout;
            layout:= GetNormalNetLayout();
        ELSE
            BoxLayout:= EnlargedLayout;
            layout:= GetBigNetLayout();
        END;

       GetBoxSize(layout);
       IF BoxWidth > MaxPaperWidth THEN
          BoxWidth:= MaxPaperWidth;
       END;
       InitSnetHandW();
       ISnetChars();
    (*
    (* get up and down arrow symbol from phrase file *)
       GetMessage(ModuleNumber,s);
       UpChar:= s[1];
       DownChar:= s[2];
       SnetChars[7].BotPad := DownChar;
       SnetChars[10].BotPad:= DownChar;
       SnetChars[14].BotPad:= UpChar;
       SnetChars[21].BotPad:= UpChar;
     *)
       SnetRowMin:= SnetRowOne;
       SnetColMin:= SnetColOne;
       SnetRowMax:= 0;
       SnetColMax:= 0;
       GetHorizMax(0,MaxPaperWidth);
       GetVertMax(0,MaxBufferLines);
       
       HorizSectionsDone:= FALSE;
       PageNumber:= 0;
       SetLengthOf (BlankLine, 0);          (* 7/10/89 EGK *)

       REPEAT

          AllowUnlimitedPageLength(FALSE);

          IF (PageNumber = 0) THEN          (* 7/10/89 EGK *)
             PageHead;
             FilterNotes(TRUE,    (* Select Filters *)
                         TRUE);   (* Highlight Filters *)
             PrintLine(BlankLine,0);        (* 5-Sep-89 CMH*)
             DateRow1 := RowsLeft();
          ELSE
             StartPage;
             WHILE (RowsLeft() > DateRow1) DO
                PrintLine(BlankLine,0);
             END;
          END;

          AllowLeftMargin(FALSE);
          AllowUnlimitedPageLength(TRUE);  
          VertSectionsDone:= FALSE;
          REPEAT
             MaxY:= BuildNetworkSection();
             PrintNetworkSection(MaxY);     
             IF Stopped THEN
                VertSectionsDone:= TRUE;
                HorizSectionsDone:= TRUE;
                END;                                
             IF SnetRowMax = SnetRows THEN
                VertSectionsDone:= TRUE;
             ELSE
                SnetRowMin:=SnetRowMax+1;
                GetVertMax(0,MaxBufferLines);
             END;
          UNTIL VertSectionsDone;
          IF SnetColMax = SnetCols THEN
             HorizSectionsDone:= TRUE;
          ELSE
             SnetRowMin:=SnetRowOne;
             GetVertMax(0,MaxBufferLines);
             SnetColMin:=SnetColMax+1;
             GetHorizMax(0,MaxPaperWidth);
          END;
          INC(PageNumber);
          IF ViewType = NetworkView THEN
             GetMessage (ModuleNumber+1, s2);       (* "TIME LINE Pert Diagram Report" *)   (* 7/14/89 EGK *)
          ELSIF ViewType = TreeView THEN
             GetMessage (ModuleNumber+2, s2);       (* "TIME LINE Tree Diagram Report" *)
          END;
          CtoS(PageNumber,s3);
          ConcatLS(s2,s3);
          PrintLine(s2,0);
       UNTIL HorizSectionsDone;
       
       EndReport();
       CheckForTranslation();

    (*
    (* restore up and down arrows *)

       SnetChars[7].BotPad := DownArrow;
       SnetChars[10].BotPad:= DownArrow;
       SnetChars[14].BotPad:= UpArrow;
       SnetChars[21].BotPad:= UpArrow;
     *)

       END;   

END PrintNetwork;


(*--------------------------------------------------------------------------*)

        (*  
            BuildNetworkSection
         *)


PROCEDURE BuildNetworkSection() : INTEGER;

CONST
    LRX = 15;
    LRY = 15;
    SeperatorLine    = ULY-1; (* First line of your stuff. *)

VAR    
    BailOut : BOOLEAN;
    X, i, j, 
    row, col, MTCol,
    erow, ecol,
    rowcl, colcl,
    BoxX, BoxY,
    sOutPos, sEndPos    : CARDINAL;
    ScreenY,
    MiddleY, cell, k    : INTEGER;
    s                   : ARRAY [0..255] OF CHAR;
    left, middle, 
    right, bottom       : CHAR;
    NormalVidMode, 
    CursorVidMode       : avidmode;

BEGIN  
   
        
    NormalVidMode:= videonormal;  (* not used, preset for pamameter passing *)
    CursorVidMode:= videonormal;
    Fill(s,blank,MaxPaperWidth+1);
    BoxY:=0;
    ScreenY := 0;
    
    FOR row := SnetRowMin TO SnetRowMax DO (* Do for each SnetMatrix Row    *)
       erow:= SnetHeight^[row];             (*  Set number of expansion rows *)    
       FOR i := 1 TO erow DO               (*  Do for each expansion Row    *)
          sOutPos := 1;    
          sEndPos := 0;    
          Fill(s,blank,MaxPaperWidth+1);            (* Set output string to blank   *)    
          s[0] := CHR(MaxPaperWidth);
          rowcl:= (erow DIV 2);            (* Set row CenterLine           *)
          IF (rowcl = 0 ) THEN rowcl:=1; END;
          FOR col:= SnetColMin TO SnetColMax DO (*Do for each SnetMatrix Column*)
             ecol:= SnetWidth^[col];           (*   Set num of expansion cols*)    
             colcl:= (ecol DIV 2 ) + sOutPos; (*   Set col CenterLine       *)
             sEndPos:= sOutPos+ecol;          (*   Set end of this expan col*)
             cell := GetCellInfo(row,col);        (*   Get SnetMatrix cell value*) 
             IF cell = 0 THEN                 (*   If cell is " "  *)    
                sOutPos:= sEndPos;            (*     do nothing, incr to end*)
                right:= blank;
             ELSIF cell > 0 THEN              (*   If cell is taskid *)    
                IF MasterTaskCheck(cell) = master THEN
                   right:= blank;
                   IF ViewType = NetworkView THEN
                      IF i = rowcl THEN          (*     IF at row CL ...       *)              
                         right:= HBar2;
                      END;
                   END;   
                   WHILE sOutPos < sEndPos DO  
                         s[sOutPos]:= right;   (* master task, add dashes *)
                         INC (sOutPos);
                         END;
                ELSE
                   sOutPos:= sEndPos;        (* regular task, do nothing *)
                   right:= blank;
                END;  
             ELSE                            (* network character found*)
                cell:= ABS(cell);            (* make cell a valid index*)
             (* check for critcal path color bias *)  
                IF (cell > COLORBIAS) THEN
                    cell := cell-COLORBIAS;
                END; 
             (* expand characters above, at and below row centerline *)
                X:= sOutPos;
                IF i < rowcl THEN            (* IF above row CL ...    *)              
                   left  := blank;
                   right := blank;
                   middle:= GetPad('T',cell); 
                END; (*if above row CL*)
                IF i = rowcl THEN             (*     IF at row CL ...       *)              
                   MiddleY:= ScreenY;
                   left   := GetPad('L',cell);  
                   middle := GetPad('A',cell); 
                   right  := GetPad('R',cell);  
                END; (*if at row CL*)
                IF i > rowcl THEN             (*     IF below row CL ...    *)              
                   left  := blank;
                   right := blank;
                   middle := GetPad('B',cell);
                   IF (middle = UpArrow) OR (middle = DownArrow) THEN
                       IF (i-rowcl)>1 THEN
                           middle:= VBar1;
                           END;
                       END;
                END; (*if below row CL*)
            
             (* expand characters left, middle and right of col centerline *)
                WHILE sOutPos < colcl DO    (* pad left side of char in    *)
                      s[sOutPos] := left;   (* output string s and         *) 
                      sOutPos := sOutPos+1; (* increment s string position *)
                END; (*while*)         
                IF sOutPos = colcl THEN     (* output middle char into     *)
                   s[sOutPos] := middle;    (* output string s and         *) 
                   sOutPos := sOutPos+1;    (* increment s string position *)
                END; (*while*)         
                WHILE sOutPos < sEndPos DO  (* pad right side of char in   *)
                      s[sOutPos] := right;  (* output string s and         *) 
                      sOutPos := sOutPos+1; (* increment s string position *)
                END; (*while*)         
             END; (* if cell...*)   
          END; (*for col...*)   
         
         (*
          IF SnetColMax < SnetCols THEN
             FOR j:= sOutPos TO MaxPaperWidth DO
                 (* extend dependency lines to edge of screen *)
                 s[j]:=right;
             END;
          END;
          *)           
          s[0]:= CHR(MaxPaperWidth);
          FillPrinterBuffer(s,0,ScreenY);  (*Output a string *)
          ScreenY := ScreenY+1;                  (*Increment screen position*)
       
       END; (*for i...*)   
       
       BoxX     := 0;
       
       FOR col := SnetColMin TO SnetColMax DO (*Do for each SnetMatrix Column*)
           
           cell:= GetCellInfo(row,col);              (*Get SnetMatrix cell value*) 
           ecol:= SnetWidth^[col];                (*Set num of expansion cols*)    
          
           IF cell > 0  THEN               (* if cell is a taskid then ...  *)
              BoxExpand(BoxX,BoxY,cell,
                        FALSE,NormalVidMode,CursorVidMode,
                        ToPrinter,
                        GetOutlineType(cell)); 
           ELSIF (cell = pdash) THEN
              MTCol := col;
              WHILE (cell = pdash) DO
                DEC(MTCol);
                cell := GetCellInfo(row,MTCol);
              END;
              IF (cell > 0) THEN
                GetMasterTaskLabel (s, loopnode^[cell], layout, HIGH(s));
                DrawMasterTaskExtension(row,col,MTCol,s,BoxX,MiddleY,
                                        ToPrinter,videonetwork);    (* 19-Oct-88 CMH *)
              END;
           END;                         (* expand task into box *)

           BoxX := BoxX+ecol;
       
       END; (*for col...*)          
       
       
       BoxY:= BoxY+erow;
    
    END; (*for row...*)   

    RETURN (ScreenY-1);

END BuildNetworkSection;



(*--------------------------------------------------------------------------*)

        (*  
            PrintNetworkSection
         *)


PROCEDURE PrintNetworkSection(MaxY : INTEGER);

VAR
   PrinterString       : ARRAY[0..255] OF CHAR;
   BufferLine          : INTEGER;
   j                   : CARDINAL;

BEGIN

    BufferLine:=0;
    LOOP
      FOR j:= 0 TO MaxPaperWidth-1 DO         
          (* build Lstring from buffer *)
          PrinterString[j+1]:=PrintBuffer[BufferLine,j];
          END;
      IF Stopped THEN 
         EXIT;(* user stops printing *)
         END; 
      PrinterString[0]:=CHR(MaxPaperWidth);   
      PrintLine(PrinterString,0);
      INC(BufferLine);
      IF BufferLine > MaxY THEN 
         EXIT;  (* all buffer lines printed *)
         END;                                 
    END;
    
END PrintNetworkSection;


(*--------------------------------------------------------------------------*)

 
BEGIN                       (* NetPrint *)

END NetPrint.
 
