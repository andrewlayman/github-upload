IMPLEMENTATION MODULE MatrixPrint;

    (*  MODIFICATION HISTORY
        11-Sep-89 CMH Update imports to keep up with tlgs changes.
        21-Sep-89 LAA Removed all reference to Animation.
         9-Oct-89 MWP Moved text literals to the phrases file.
     *)

FROM AccessMatrix           IMPORT
    (* CONST *)                 COLORBIAS,
    (* PROC *)                  GetCellInfo;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, Message, MultipleChoiceBox;

FROM Dispatcher             IMPORT
    (* VAR *)                   CurrentLayoutProc;

FROM ErrorUtil              IMPORT
    (* PROC *)                  PrintSMsg;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange,
                                ValidateGanttOutline;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol,
    (* PROC *)                  EraseLn, FlushKeyboardBuffer, KeyPress,
                                PutString;

FROM Layout                 IMPORT GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetLengthOf, CtoS, Procustes,
                                ConcatLS, Insert, LJust, TrimRear, Overlay ;

FROM Menus                  IMPORT
    (* PROC *)                  Menu;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM NetBanners             IMPORT
    (* PROC *)                  ClearBanner, ClearMessage, DisplayBanner;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank,      asterick,
                                HBar2,      VBar2,
                                TTee2,      BTee2,
                                LTee2,      RTee2,
                                ULC2,       URC2,
                                LLC2,       LRC2,
                                IRC2,       ILC2,
                                HBar1,      VBar1,
                                ULC1,       URC1,
                                LLC1,       LRC1,
                                pastrUL,    pastrUR,
                                pastrLL,    pastrLR,
                                pDPlus,     pDHPlus,
                                pDLeftTee,  pDRightTee,
                                pdash,      pVDash,
                                dash,       VDash,
                                TopTee,     BotTee,
                                LeftTee,    RightTee,
                                plus,       UpArrow,
                                DownArrow,  pTopTeeUp,
                                ThickBar,
                                UpChar,     DownChar;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NormalLayoutActive, GetNormalNetLayout,
    (* PROC *)                  DisplayNetworkLight, GetBigNetLayout;


FROM NetStatic              IMPORT
    (* CONST *)                 DimHeight,   DimWidth,
    (* TYPE *)                  DiagramView,
                                DiagramTask,
    (* VAR *)                   SnetWidth,   SnetHeight,
                                loopnode,
                                SnetRowOne,  SnetColOne,
                                SnetRows,    SnetCols,
                                maxtask,
                                ViewType,
                                NetworkDone, EnoughMemory,
                                DeallocForRecalc;

FROM NetUtility             IMPORT
    (* CONST *)                 ToScreen, ToPrinter,
                                NormalLayout,  EnlargedLayout,
                                MasterTaskHeight,
                                ULX, ULY, ULYMAX,  SeperatorLine,
    (* VAR *)                   SnetChars,
                                BoxLayout,
                                CharWidth, CharHeight,
                                BoxWidth, BoxHeight,
                                SnetRowMin,    SnetRowMax,
                                SnetColMin,    SnetColMax,
                                ExpandedSnetHeight, ExpandedSnetWidth,
    (* PROC *)                  GetBoxSize,
                                GetPad,
                                ISnetChars, InitSnetHandW,
                                SetFilterVideoModes,
                                MasterTaskCheck;

FROM NetTaskDraw            IMPORT
    (* CONST *)                 MaxBufferLines,
    (* VAR *)                   PrintBuffer,
    (* PROC *)                  FillPrinterBuffer;

FROM PrintCaptions          IMPORT
    (* PROC *)                  PageHead;

FROM PrintStatic            IMPORT
                                APrinterStyle, PrintXLAT;

FROM PrintSupport           IMPORT
    (* VAR *)                   Stopped,
    (* PROC *)                  AllowLeftMargin, AllowUnlimitedPageLength,
                                EndReport, PageWidth, PageTop, PrintLine,
                                StartPage, StartReport, CheckForTranslation;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode,
    (* PROC *)                  ValidateTreeNode;

CONST
    ModuleNumber  = 9200;

VAR

    MaxPaperWidth : INTEGER;


(*--------------------------------------------------------------------------*)
        (*
            GetHorizPrintMax
         *)


PROCEDURE GetHorizPrintMax(HorizPrintMax : INTEGER);

BEGIN

    SnetColMax:= SnetColMin + HorizPrintMax;
    IF SnetColMax > SnetCols THEN
       SnetColMax:= SnetCols;
    END;

END GetHorizPrintMax;


(*--------------------------------------------------------------------------*)
        (*
            GetVertPrintMax
         *)


PROCEDURE GetVertPrintMax(VertPrintMax : INTEGER);

BEGIN

    SnetRowMax:= SnetRowMin + VertPrintMax;
    IF SnetRowMax > SnetRows THEN
       SnetRowMax:= SnetRows;
    END;

END GetVertPrintMax;


(*--------------------------------------------------------------------------*)
        (*
            ShowMatrix

            This is the main procedure used to access the internal
            matrix and draw a screen full of network diagram.
            First, the framwork is drawn, the master task outlines
            and the connecting dependency lines.  Next, the task boxes
            are expanded and draw over the framework.
         *)


PROCEDURE ShowMatrix() : INTEGER;

VAR
    row, col,
    sOutPos             : CARDINAL;
    ScreenY, cell       : INTEGER;
    layout              : ANetworkLayout;
    s                   : ARRAY [0..255] OF CHAR;

BEGIN                       (* ShowMatrix *)

  ScreenY := 0;

  FOR row := SnetRowMin TO SnetRowMax DO
      Fill(s,blank,MaxPaperWidth+1);
      sOutPos := 1;
      FOR col := SnetColMin TO SnetColMax DO
          cell := GetCellInfo(row,col);
          IF cell > 0 THEN     (* taskid *)
             s[sOutPos] := asterick;
          ELSIF cell < 0 THEN   (* network character *)
             cell := ABS(cell); (* make cell a valid index *)
             IF (cell > COLORBIAS) THEN
                 cell := cell-COLORBIAS;
             END;
             s[sOutPos]  := GetPad('A',cell);
          ELSE
          (* blank cell *)
          END;
          sOutPos := sOutPos+1;
      END; (* for col... *)

      FillPrinterBuffer(s,0,ScreenY);  (*Output a string *)
      ScreenY := ScreenY+1;
    END; (*for row...*)

    RETURN (ScreenY-1);

END ShowMatrix;


(*--------------------------------------------------------------------------*)

        (*
            PrintMatrix is the main procedure used to print
            a network drawing matrix.
         *)


PROCEDURE PrintMatrix();

VAR
    HorizSectionsDone,
    VertSectionsDone    : BOOLEAN;
    s,s2,s3             : ARRAY [0..255] OF CHAR;
    PageNumber          : CARDINAL;
    layout              : ANetworkLayout;
    MaxY                : INTEGER;

BEGIN

    IF StartReport() THEN

       MaxPaperWidth:= PageWidth();
       IF MaxPaperWidth > 255 THEN
          MaxPaperWidth:= 255;
       END;

       BoxLayout:=NormalLayout;
       layout:= GetNormalNetLayout();
       GetBoxSize(layout);
       IF BoxWidth > MaxPaperWidth THEN
          BoxWidth:= MaxPaperWidth;
       END;
       InitSnetHandW();
       ISnetChars();
       SnetRowMin:= SnetRowOne;
       SnetColMin:= SnetColOne;
       SnetRowMax:= 0;
       SnetColMax:= 0;
       GetHorizPrintMax(MaxPaperWidth);
       GetVertPrintMax(MaxBufferLines);

       HorizSectionsDone:= FALSE;
       PageNumber:= 0;

       REPEAT
          PageHead;
          AllowLeftMargin(FALSE);
          AllowUnlimitedPageLength(TRUE);
          VertSectionsDone:= FALSE;
          REPEAT
             MaxY:= ShowMatrix();
             PrintMatrixSection(MaxY);
             IF Stopped THEN
                VertSectionsDone:= TRUE;
                HorizSectionsDone:= TRUE;
                END;
             IF SnetRowMax = SnetRows THEN
                VertSectionsDone:= TRUE;
             ELSE
                SnetRowMin:=SnetRowMax+1;
                GetVertPrintMax(MaxBufferLines);
             END;
          UNTIL VertSectionsDone;
          IF SnetColMax = SnetCols THEN
             HorizSectionsDone:= TRUE;
          ELSE
             SnetRowMin:=SnetRowOne;
             GetVertPrintMax(MaxBufferLines);
             SnetColMin:=SnetColMax+1;
             GetHorizPrintMax(MaxPaperWidth);
          END;
          INC(PageNumber);
          GetMessage ( ModuleNumber, s2 );
          (* "TIME LINE DrawingMatrix Report, Strip " *)
          CtoS(PageNumber,s3);
          ConcatLS(s2,s3);
          PrintLine(s2,0);
       UNTIL HorizSectionsDone;

       EndReport();
       CheckForTranslation();

       END;

END PrintMatrix;


(*--------------------------------------------------------------------------*)

        (*
            PrintMatrixSection
         *)


PROCEDURE PrintMatrixSection(MaxY : INTEGER);

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

END PrintMatrixSection;

(*--------------------------------------------------------------------------*)


BEGIN                       (* MatrixPrint *)

END MatrixPrint.
