IMPLEMENTATION MODULE PrintSupport;

    (* MODIFICATION HISTORY:

       Sept. 12, 1985 AJL - Use BreakRequested to cause a pause of
                            the report.  Do not allow CancelKey for
                            go on to next page when printing to screen.
       Dec. 7, 1985, AJL  - Use Length procedure to position directly
                            to the end of the file when adding text
                            to the end.
                          - Modify MarginCheck procedure to not allow
                            a very large right margin, regardless of
                            left margin setting.  Left margin may be
                            disabled, after all.
                          - Don't output to blank file name. Instead
                            substitute a good file name.
                          - StopTest only erases message if Cancel
                            is chosen.
        11/19/86 LAA    NoCursor is now a type, to be used with SetCursorType.
        01/03/87 LAA    Removed call to SetPageSettings from the initialization
                        of this module, since the data it needs isn't available
                        at initialization time, because this module is now part
                        of the root, and the data is read by TLINIT.
        01/08/86 LAA    Incorporated Andrew's latest changes from TL vers. 2.
        06/19/87 RSC    Made changes (AGAIN) to support bold screen printing.
        07/03/87 RSC    Fixed bug where screen displays tried to go past maxcol.
        07/16/87 RSC    Changed BIOS calls for printer IO to be DOS calls.
        08/02/87 RSC    Added Terminate string.
        10-Sep-87 LAA   In MarginCheck, changed order of checks to catch the
                        case where both left and right margins are zero.
        18-Jan-88 RSC   Changed menus to dialog boxes.
        22-Feb-88 RSC   Help disk file handling:
                        1) Call Andrew's new procedure in FileAux for reporting.
                        2) Dont alter the report disk file name.
                        3) Don't bitch at them for PRN:, CON:, etc.
        24-Feb-88 RSC   Fix a concat of carrige return in OpenDiskFile().
        24-Feb-88 EGK   Added CheckForTranslation procedure.
        28-Feb-88 AJL   When printing to the screen, take a rug prior to
                        printing, and restore the screen when printing is ended.
         1-Mar-88 AJL  -Modify StopTest to take a text string to display in the
                        box identifying why we are asking to stop.  Make an
                        internal StopTestProc for this.
                       -Modify the error handling for serial, parallel and DOS
                        printer output to use the new IStopTest.
                       -Serial output now waits 2 seconds before timing out.
                       -Break pressing has its own message now.
         2-Mar-88 AJL  -Moved the end of report to screen message to before
                        we erase the screen.
                       -Really delete the disk file when that option is
                        chosen, and check for errors.
        13-Sep-88 AJL  -Revised so that we no longer use the EOL character
                        to signify End-of-line.  This repairs the program
                        so that our standard symbol for done milestones will
                        print.  We now use WriteByte for output instead of
                        WriteChar, and reset the screen within the NewLine
                        proc.
        22-Feb-89 AJL  -Use Printers module.
                       -If the user cancels print to screen, don't put up an
                        error box informing them that the report has ended.
        20-Apr-89 KKC  -Add new procedure CreateReportHeader.  It creates
                        a default report header and stores it in
                        ReportHeaderTextIn.
                       -Add new procedure GenerateReportHeader.  It generates
                        ReportHeaderTextGen based on ReportHeaderTextIn.
                       -Calls GenerateReportHeader in StartReport.
        4-May-89  KKC  -Move GenerateReportHeader to PrintCaptions
        4-May-89 MWP   -Implement use of second serial port direct access.
        08-Jun-89 KKC  -Add new function GetCurrentPrintRow.
        17-Jun-89 KKC  - Take out the call to EndReport in IStopTest.  The
                         call of EndReport cause a problem in restoring the
                         status line.
        05-Jul-89 WKH  -Changed VMaxPageLength from a CONST to a VAR so that
                        we can display full page reports in compressed video
                        mode.
        06-Jul-89 WKH  -Turns out I was duped into believing I had changed
                        the right code for reports to fill the whole screen
                        in compressed mode.  WRONG!!!  This time I've got it.
        13-Jul-89 KKC  - Call DiscardReportHeader in EndReport.
        03-Aug-89 MWP  - Added new function PrintInitOrTerminateString to
                         allow printing multi-line strings of form AText.
        12-Sep-89 AJL  - Don't open any printers until TLMain is started.
        27-Aug-89 MWP  - Start using GlobalTimeOut.
        14-Dec-89 RSC  - Remove GetAnyCode in preference to GetNextEvent
                         for mouse stuff.
        21-Dec-89 AJL  - Added mouse Buttons for Resume and Cancel.
        10-Jan-90 EGK  - Removed the "geiger counter effect" in PageTop's
                         event loop by reversing the order of the two IF's
                         that test whether we got a MouseUp in the button
                         area.  Don't put up the "Proceed, Cancel" dialog
                         if the user cancelled the report with the mouse.
         2-May-91 RSC  - upon open of a file that does not exist, check
                         not just for "notdone" but also for "unknownfile".
         3-Jul-91 AJL  - Use videofilter3 for bold text.
        23-Jul-91 AJL  - Get a rug before any output, restore at end.
    *)

FROM Boxes      IMPORT
    (* TYPE *)         ABoxType, ABoxAttribute;

FROM Buttons    IMPORT
    (* TYPE *)         AButtonCollection, AnOrientation,
                       CreateButtonCollection, DisposeButtonCollection,
                       CorrelateMouseToButton;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  SetState;

FROM   Clock     IMPORT
    (* PROC *)           Delay, NoEarlyExit;

FROM   Codes     IMPORT
    (* TYPE *)           ACode;

FROM   Dialog    IMPORT  Message, Error, FatalError, Burp, WarningBox,
                         MultipleChoiceBox, ADialogOption;

FROM   Events    IMPORT
    (* TYPE *)           AnEvent, AnEventType,
    (* PROC *)           GetNextEvent;

FROM   Kbio      IMPORT  BreakRequested, ClearBreak,
                         EraseScreen, maxcol, SetCursorType, ascreenx,
                         PutString, avidmode, EraseLn, maxrow, ascreeny;

FROM   Keys      IMPORT  CancelKey, DoIt, MouseUp;

FROM   LStrings  IMPORT  SubStr, ConcatLS, Fill,
                         TrimRear, ConcatS,
                         Search,  Copy, SetLengthOf,
                         LStringToTString, LengthOf;

FROM   FileSystem IMPORT File, Response, Lookup, Delete,
                         Close, WriteByte, ReadChar,  SetModify,
                         SetPos, Length;

FROM   FileAux    IMPORT FileResultMeans, FlushBuffer, PrepareForIO,
                         DisplayFileError, CheckIO;

FROM   SYSTEM     IMPORT DOSCALL, SETREG, SWI, GETREG, CODE, AX, DX;

FROM   Directory  IMPORT  DirectoryIsReachable, NormalizeFileName,
                          ExtractFileNameParts, AFileNamePart, ASetOfFileNameParts;

FROM   Lights     IMPORT  EnableLights;

FROM Mouse      IMPORT
    (* PROC *)          CancelDoubleClick, MousePresent;

FROM   MsgFile    IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM   PrintStatic IMPORT  PrintCB, PrintDiskFileName,
                           ReportFinishedOK,
                           TranslateOverlay,
                           GlobalTimeOut,                         (* 27-Sep-89 MWP *)
                           AControlGroup, AControlStyle,
                           APrinterStyle, APortType,
                           AProtocol, PrintXLAT;
                           (* We assume here that the protocols are
                              ordered so that all those that need
                              input are >= XonXoff. *)

FROM Rugs  IMPORT ARug, GetRug, PutRug;

FROM Overlays       IMPORT CallOverlay;

FROM Paranoia               IMPORT
        (* TYPE *)              AProgramState, ProgramState;

FROM PrintCaptions          IMPORT
    (* PROCS *)                 GenerateReportHeader, DiscardReportHeader;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia, ProjectName, Author,
                                FullScheduleName;

FROM Text                   IMPORT
    (* PROC *)                  CopyLine, AssignLine, Compress, CreateText,
                                LineExists, TextExists, AText, SizeOfText,
                                DiscardText;

FROM TimeFormat             IMPORT
    (* PROCS *)                 DtoS;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;


IMPORT Printers;





CONST
    ModuleNumber = 10900;          (* For GetMessage  *)
    DefaultPrintFileName = 13202;  (* "DK:REPORT.TXT" *)


VAR
    TopOfPageProc,
    EndOfPageProc    : APageCaptionProcedure;
    FootingRows      : CARDINAL;
    PageBreakEnabled : BOOLEAN;

    Rug               : ARug;     (* Original screen when output = screen. *)
    NillString : ARRAY [0..1] OF CHAR;



CONST
    MAXCARDINAL    = 65535;
    MinPageLength  = 20;
    CMaxPageLength = MAXCARDINAL;
    VMaxLineSize   = 79;
    CMaxLineSize   = 230;
    MinLineSize    = 70;

    ScreenTop       = 1;  (* Row 0 is the message line. *)
    MaxScreenLength = 22; (* Leave room for footing (2 lines) *)

VAR
    CurrentMode     : CARDINAL;
    Row             :  CARDINAL;
    MaxPageLength   : CARDINAL;
    MaxLineSize     : CARDINAL;
    VMaxPageLength  : CARDINAL;  (* 05-Jul-89 WKH *)
    GlobalX         : ascreenx;  (* Where we are on the screen output. *)
    GlobalY         : ascreeny;
    ML              : ascreeny;     (* Message Line *)
    CCG             : AControlGroup;
    PrintFile       : File;
    GlobalVideomode : avidmode;  (* What videomode we are in *)
    PrinterIsAtTopOfPage  : BOOLEAN;
    FileIsOpen            : BOOLEAN;
    PageLengthIsUnlimited : BOOLEAN;
    LeftMarginIsWanted    : BOOLEAN;
    AtLeftEdge            : BOOLEAN;
    ThePrinter            : Printers.APrinterConnection;






    (*  RowsLeft  --  Tells how many rows are left on the current
                      page.    In the case where the page length is
                      theoretically unlimited, return how many rows
                      would be left on the page if the page were
                      very long.  We still want the number of rows
                      to decrease since some of our clients use this
                      to horizontally align pages.  *)

PROCEDURE  RowsLeft():CARDINAL;
CONST
    Minimum = 100;
BEGIN
    IF (Stopped) THEN
        RETURN 0;
    ELSIF (PageLengthIsUnlimited)  AND  (PrintCB.Style <> OutToScreen) THEN
        IF (Row < MAXCARDINAL - Minimum + 1) THEN
            RETURN MAXCARDINAL - Row + 1;
        ELSE
            RETURN Minimum;
        END;
    ELSIF (Row <= PrintCB.BottomMargin+1) THEN
        RETURN PrintCB.BottomMargin + 1 - Row;
    ELSE
        RETURN 0;
    END;
END RowsLeft;


PROCEDURE GetCurrentPrintRow():CARDINAL;
VAR
    i : CARDINAL;
BEGIN
    IF (PrintCB.Style <> OutToScreen) THEN
        i := Row;
    ELSE
        i := GlobalY;
    END;
    RETURN i;
END GetCurrentPrintRow;


    (*  PageWidth  -- Tells the current page width.  *)

PROCEDURE PageWidth():CARDINAL;
VAR
    i : CARDINAL;
BEGIN
    i := PrintCB.RightMargin;
    IF (LeftMarginIsWanted) THEN
        INC(i);
        DEC(i,PrintCB.LeftMargin);
    END;
    RETURN i;
END PageWidth;




PROCEDURE ProgressMessage(VAR s: ARRAY OF CHAR);
BEGIN
        (*  If the output is going to the screen, suppress the message,
            since progress is probably evident, and the direct video i/o
            tends to overwrite the report, and then get scrolled into it,
            and it looks quite ugly. *)
    IF (PrintCB.Style <> OutToScreen) THEN
        Message(s);
    END;
END ProgressMessage;





PROCEDURE MarginCheck(VAR LeftMargin,RightMargin:CARDINAL;
                      MinSize,MaxSize:CARDINAL);
VAR
    i       : CARDINAL;
    Changed : BOOLEAN;
    s       : ARRAY [0..255] OF CHAR;
    Title   : ARRAY [0..40] OF CHAR;
BEGIN
    Changed := FALSE;
    IF (RightMargin < LeftMargin) THEN
        i := RightMargin;
        RightMargin := LeftMargin;
        LeftMargin := i;
        Changed := TRUE;
    END;
    IF (LeftMargin < 1) THEN                                      (* 10-Sep-87 LAA *)
        LeftMargin := 1;
        Changed := TRUE;
    END;
    IF (RightMargin > MaxSize) THEN    (* 12/7/85 AJL *)
        RightMargin := MaxSize;        (* 12/7/85 AJL *)
        Changed := TRUE;
    END;
    IF (RightMargin < MinSize) THEN
        RightMargin := MinSize;
        Changed := TRUE;
    END;
    IF (LeftMargin >= RightMargin) THEN
        LeftMargin := 1;
        Changed := TRUE;
    END;
    IF (RightMargin-LeftMargin+1 < MinSize) THEN
        LeftMargin := RightMargin-MinSize+1;
        Changed := TRUE;
    END;
    IF (Changed) THEN
        GetMessage(ModuleNumber+1,Title);  (* "Page Size Changed" *)
        GetMessage(ModuleNumber+2,s);      (* "Page size has been changed. *)
        WarningBox(s,Title,NoHelp);
    END;
END MarginCheck;



PROCEDURE FileComplaint;
BEGIN
    DisplayFileError( PrintFile, PrintDiskFileName );
END FileComplaint;







PROCEDURE PrintACharacter(TheChar:CHAR):BOOLEAN;
CONST
    Good = 0;
    Die  = 1;
    Retry = 2;
VAR
    ErrorNumber   : CARDINAL;
    C             : CARDINAL;
    Ch            : CHAR;
    ms            : ARRAY [0..60] OF CHAR;

BEGIN
    Ch := TheChar; (* Local variable *)

    IF (NOT FileIsOpen) THEN
        (* If not open, do not attempt to print. *)
    ELSIF (PrintCB.Style = OutToPrinter) THEN
        FileIsOpen := Printers.PrintACharacter(ThePrinter,Ch);
        RETURN FileIsOpen;
    ELSIF (PrintCB.Style = OutToDisk) THEN
        PrepareForIO(PrintFile);

        WriteByte(PrintFile,Ch);
        IF (CheckIO(PrintFile) <> done) THEN
               (*  On a file, recovery is not possible. *)
            EmergencyStop;
            RETURN FALSE;
        END;
    ELSE  (* Screen *)
        IF (PrinterIsAtTopOfPage) THEN
            EraseScreen;
            ms[0] := 0C; (* Erase any messages *)
            Message(ms);
            GlobalY := ScreenTop;
            PrinterIsAtTopOfPage := FALSE;
        END;
        IF (AtLeftEdge) THEN
            GlobalX := 0;
            AtLeftEdge := FALSE;
        END;
        ms[0] := 1C;
        ms[1] := Ch;
        IF (Ch <> 0C)  AND  (GlobalX <= maxcol)  THEN
            PutString( ms, GlobalX, GlobalY, GlobalVideomode );
            INC(GlobalX);
        END;
    END;
    RETURN TRUE;
END PrintACharacter;

PROCEDURE PrintString(VAR s:ARRAY OF CHAR);
VAR
    i, count : CARDINAL;
BEGIN
    count := ORD(s[0]);

    IF (NOT FileIsOpen) THEN
        (* If not open, do not attempt to print. *)
    ELSE
        i := 1;
        WHILE (i <= count) AND (PrintACharacter(s[i])) DO
            INC(i);
        END;
    END;
END PrintString;



PROCEDURE EmergencyStop;
BEGIN
    FileComplaint;
    Stopped    := TRUE;
    FileIsOpen := FALSE;
END EmergencyStop;




    (*  NextLine -- Advance the paper one line. *)

PROCEDURE NextLine;
VAR
    s : ARRAY [0..61] OF CHAR;
BEGIN
    IF (PrintCB.Style = OutToScreen) THEN
        GlobalX := 0;
        IF (GlobalY < maxrow) THEN
            INC(GlobalY);
        END;
    ELSE
        SubStr(CCG.NewLine,s,1,100);
        PrintString( s );
    END;
    INC(Row);
    AtLeftEdge := TRUE;
END NextLine;





    (*  PageTop --  Advance printing on screen to a new page.  *)

PROCEDURE PageTop;
CONST
    PageSeparatorChar = 261C;
VAR
    Event : AnEvent;
    ButtonCollection : AButtonCollection;
    ButtonNumber     : CARDINAL;
    Code             : ACode;
    s     : ARRAY [0..maxcol+2] OF CHAR;
BEGIN
    IF (NOT FileIsOpen) THEN RETURN; END;
    SubStr(CCG.NewPage,s,1,HIGH(s));
    IF (PrintCB.Style = OutToScreen) THEN
        Fill(s,PageSeparatorChar,maxcol+1);
    END;
    IF (s[0] <> 0C) THEN
        PrintString(s);
    ELSE
        NextLine;
    END;
    Row := 1;
    IF ((CCG.Pause) OR (PrintCB.Style = OutToScreen))
       AND (NOT Stopped) THEN
        EraseLn(ML);

        IF (NOT MousePresent()) THEN
            GetMessage(ModuleNumber+8,s);   (*  "End of page.    Press any key to continue."  *)
            PutString(s,0,ML,cvideomessage);
        END;

        GetMessage(ModuleNumber+17,s);      (* Resume report, Cancel Report *)
        IF CreateButtonCollection(2,ML,maxcol,ML,ABoxType{NoBox},Horizontal,s,
                                  ButtonCollection) THEN
        END;

        REPEAT  (* 15-Dec-89 RSC mouse stuff. *)
            GetNextEvent(Event);
            Code := Event.EventCode;
            IF (Event.EventType = MouseEvent) THEN
                IF (Event.EventCode = MouseUp) THEN     (* 1/10/90 EGK *)
                    IF CorrelateMouseToButton(ButtonCollection,Event.EventX,
                                              Event.EventY,ButtonNumber) THEN
                        CASE ButtonNumber OF
                            1 : Code := DoIt;
                           |2 : Code := CancelKey;
                           ELSE
                        END; 
                    ELSE
                        Code := 0;
                        Burp();
                    END;
                ELSE
                    Code := 0;
                END;
            END;

        UNTIL (Code <> 0);

        IF (Code = CancelKey) THEN
            IF (Event.EventType = KeyboardEvent) THEN    (* 1/10/90 EGK *)
                IF (IStopTest(NillString)) THEN
                END;
            ELSE
                Stopped := TRUE;
            END;
        END;

        DisposeButtonCollection(ButtonCollection);

        EraseLn(ML);
    END;
    PrinterIsAtTopOfPage := TRUE;
    AtLeftEdge           := TRUE;
END PageTop;



PROCEDURE SkipTopMargin;
BEGIN
        (*  Skip top margin. *)
        (*  We used to only do this if style = OutToPrinter. *)
    WITH PrintCB DO
        WHILE (Row < TopMargin) DO
            NextLine;
        END;
    END;
END SkipTopMargin;



    (*  StartPage  -- Call this at the start of each printed page.
                      This will advance the paper to a new page,
                      and will call the EndOfPageProc and TopOfPageProc
                      if necessary. *)

PROCEDURE StartPage;
BEGIN
    IF (PageBreakEnabled) THEN
        PageBreakEnabled := FALSE;  (* Prevent recursion. *)
        IF (Row > PrintCB.TopMargin) THEN
            EndOfPageProc;  (* User-installed procedure. *)
            PageTop;
        END;
        SkipTopMargin;
        TopOfPageProc;  (* User-installed procedure. *)
        PageBreakEnabled := TRUE;
    END;
END StartPage;






    (* OpenScreen -- Get ready for print to screen. *)


PROCEDURE OpenScreen;
BEGIN
    SetState(Formatted);
    EnableLights(FALSE);   (* Turn off the status lights. *)
    EraseScreen;
    GlobalX := 0;
    GlobalY := ScreenTop;
    GlobalVideomode := videonormal;
    FileIsOpen := TRUE;
END OpenScreen;



    (*  OpenPrinter -- Attempt to open the printer.  Set
                       FileIsOpen to TRUE iff successful.   *)


PROCEDURE OpenPrinter;
VAR
    PrinterOptions : Printers.APrinterOptionsBlock;
BEGIN
        (* Fill in all printer options even though only one is relevant. *)
    WITH PrinterOptions DO
        Method := VAL( Printers.APrintMethod, ORD(PrintCB.PortType) );
            (* Parallel Data *)
        ParallelPort := PrintCB.PrinterNumber;
            (* Serial Data *)
(*
        SerialPort := 1;    (* Only one we support. *)
*)
        SerialPort := PrintCB.PrinterNumber;   (* MWP 6-May-89 *)
        BaudRate := PrintCB.BaudRate;
        DataBits := PrintCB.NumberOfBits;
        StopBits := PrintCB.StopBits;
        ParityBit := PrintCB.ParityBit;
        EvenParity := PrintCB.EvenParity;
        Protocol := VAL( Printers.AProtocol, ORD(PrintCB.Protocol) );

        TimeOut  := GlobalTimeOut;         (* 100ths of second *)  (* 27-Sep-89 MWP *)

            (* DOS Device Data *)
        DOSDevice :=  PrintCB.PrinterNumber;
    END;
    FileIsOpen := Printers.OpenPrinter(ThePrinter,PrinterOptions,IStopTest);
END OpenPrinter;






    (*  OpenDiskFile -- Attempt to open the disk file.  Set
                        FileIsOpen to TRUE iff successful.   *)


PROCEDURE OpenDiskFile;
VAR
    Choice, i  : CARDINAL;
    High, Low  : CARDINAL;
    C, C2      : CHAR;
    TLocalName,
    LocalName  : ARRAY [0..99]  OF CHAR;
    Choices    : ARRAY [0..255] OF CHAR;
    Prefix     : ARRAY [0..81]  OF CHAR;
    FileOpen   : BOOLEAN;

    PROCEDURE OpenIt(VAR Name:ARRAY OF CHAR;CreateIt:BOOLEAN):BOOLEAN;
    BEGIN
        FileOpen := FALSE;
        PrepareForIO(PrintFile);
        Lookup(PrintFile,Name,CreateIt);
        IF (CheckIO(PrintFile) = done) THEN
            FileOpen := TRUE;
            RETURN TRUE;
                (* 2-May-91 RSC change response we look for: *)
        ELSIF (CreateIt) OR (CheckIO(PrintFile) <> unknownfile) THEN
            FileComplaint;
        END;
        RETURN FALSE;
    END OpenIt;


    PROCEDURE NotADevice( VAR Name : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        Device     : ARRAY [0..3]  OF CHAR;
        NewName    : ARRAY [0..9]  OF CHAR;
        s          : ARRAY [0..99] OF CHAR;
    BEGIN
        ExtractFileNameParts( Name, Device, s, NewName, s);
        ConcatS( NewName, ":" );
        GetMessage ( ModuleNumber + 45, s); (* "CON: PRN: LPT1: NUL: LPT2: AUX: LPT:" *)
        RETURN (Search( s, Device, 1 ) = 0) AND (Search( s, NewName, 1 ) = 0);
    END NotADevice;

BEGIN
        (* If the file name is empty, substitute a good name. *)

    Copy( PrintDiskFileName, LocalName );  (* Make local copy.  RSC 2/16/88 *)
    TrimRear( LocalName );        (* 12/7/85 AJL *)
    IF (LocalName[0] = 0C) THEN
        GetMessage(DefaultPrintFileName,LocalName);
    END;
        (* Make the name legal.  This may also have the side effect of
           curing a Logitech file system error with disk names terminated
           with nulls on Lookup. *)
    NormalizeFileName( LocalName,
                       ASetOfFileNameParts{DevicePart,DirectoryPart,FileNamePart,ExtensionPart});

        (*  Make sure that the subdirectory exists. *)
    IF (NOT DirectoryIsReachable( LocalName )) THEN
        GetMessage(ModuleNumber+9,Choices);   (*  'I cannot find directory '  *)
        ConcatLS( Choices, LocalName );
        Error( Choices );
        RETURN;
    END;
        (*  See if the file exists. *)
    LStringToTString( LocalName, TLocalName );

    PrinterIsAtTopOfPage := TRUE;

    IF (OpenIt( TLocalName, FALSE )) AND (NotADevice( LocalName )) THEN
        Message( LocalName );
        Copy(    LocalName, Prefix );
        ConcatS( Prefix, "ü" );  (* RSC 2/24/88 *)
        ConcatMessage( Prefix, ModuleNumber+10 );   (*  "Report file already exists.  Shall I"  *)
        GetMessage(ModuleNumber+11,Choices);   (*  "Cancel the report,Erase old file"  *)
            (* Only allow add at end if no file conversion is to be
               done. *)
        IF (PrintCB.ControlStyle <> WPNormal) OR
           (TranslateOverlay[0] = 0C) THEN
            ConcatMessage(Choices,ModuleNumber+12);   (*  ",Add this to end"  *)
        END;
        Choice := 1;
        IF (NOT MultipleChoiceBox( Prefix, PrintDiskFileName, NoHelp, NillString, Choices, Choice )) OR
           (Choice = 1) THEN
            Close(PrintFile);
            DisplayMessage(ModuleNumber+13);   (*  "Ok, Report cancelled."  *)
            RETURN;
        ELSIF (Choice=2) THEN
            Close(PrintFile);                   (* AJL 12/1/86 *)
            PrepareForIO(PrintFile);
            Delete(TLocalName,PrintFile);
            IF (CheckIO(PrintFile)<>done) THEN
                DisplayFileError(PrintFile,LocalName);
            END;
            IF (NOT OpenIt(TLocalName,TRUE)) THEN
                RETURN;
            END;
        ELSE
            DisplayMessage(ModuleNumber+14);   (*  "A moment, please . . ."  *)
                (* Find current file length. *)
            SetModify(PrintFile);
            Length(PrintFile,High,Low);
                (* DOS stores a CTRL-Z at the last character of text files.
                   Back up one character position. *)
            IF (Low = 0) THEN
                IF (High > 0) THEN
                    DEC(High);
                    Low := MAXCARDINAL;
                END;
            ELSE
                DEC(Low);
            END;
                (* Position to the end of the file. *)
            SetPos(PrintFile,High,Low);
            PrinterIsAtTopOfPage := FALSE;
        END;
    ELSIF (NOT FileOpen) THEN
        IF (NOT OpenIt(TLocalName,TRUE)) THEN
            RETURN;
        END;
    END;

    FileIsOpen := TRUE;

END OpenDiskFile;




    (* CloseFile -- If the printer file is open, close it. *)

PROCEDURE CloseFile;
VAR
    ErrorNumber : CARDINAL;
    S : ARRAY [0..255] OF CHAR;
BEGIN
    IF (FileIsOpen) THEN
        CASE PrintCB.Style OF
            OutToDisk:
                WriteByte(PrintFile,CHR(26)); (* 2-May-91 RSC EOF *)
                FlushBuffer(PrintFile);
                IF (CheckIO(PrintFile) <> done) THEN
                    FileComplaint;
                END;
                Close(PrintFile);
          | OutToPrinter:
                Printers.ClosePrinter(ThePrinter);
          | OutToScreen:
                IF (NOT Stopped) THEN
                    GetMessage(ModuleNumber+19,S);   (* "That's all, folks!" *)
                    Error(S);
                END;
            ELSE
            END;
    END;

    IF (Rug <> ARug(NIL)) THEN
        PutRug(0,0,maxcol,maxrow,Rug);  (* Restore the screen *)
    END;

    EnableLights(TRUE);

        (* Clear any optional page header and footer controls. *)
    TopOfPageProc := NullProcedure;
    EndOfPageProc := NullProcedure;
    FootingRows   := 0;

    FileIsOpen := FALSE;
END CloseFile;



PROCEDURE SetPageSettings;
BEGIN
    PageLengthIsUnlimited := FALSE;
    LeftMarginIsWanted    := TRUE;
    AtLeftEdge            := TRUE;
    CurrentMode := 0;       (*  Assume that we start as normal.  *)
    Row := 1;
    IF (PrintCB.Style = OutToScreen) THEN
        MaxPageLength := VMaxPageLength;
        MaxLineSize   := VMaxLineSize;
    ELSE
        MaxPageLength := CMaxPageLength;
        MaxLineSize   := CMaxLineSize;
    END;
    WITH PrintCB.ControlStrings[PrintCB.ControlStyle] DO
            (* Force certain ranges. *)
        MarginCheck(TopMargin,BottomMargin,MinPageLength,MaxPageLength);
        MarginCheck(LeftMargin,RightMargin,MinLineSize,MaxLineSize);
    END;
    WITH PrintCB DO
        IF (Style = OutToScreen) THEN
            ML := maxrow;                         (* Print at bottom. *)
            ControlStrings[ControlStyle].BottomMargin := VMaxPageLength;  (* 06-Jul-89 WKH *)
        ELSE
            ML := 0;                              (* At top of screen. *)
        END;
        CCG := ControlStrings[ControlStyle];             (* Current control group. *)
        TopMargin := CCG.TopMargin;
        BottomMargin := CCG.BottomMargin;
        LeftMargin := CCG.LeftMargin;
        RightMargin := CCG.RightMargin;
    END;
END SetPageSettings;

    (*  StartReport -- Call this once at the start of a report.
                       A FALSE return indicates that an error occurred. *)

PROCEDURE StartReport():BOOLEAN;
VAR
    s : ARRAY [0..99] OF CHAR;
BEGIN
    Stopped := FALSE;
        (* If the file was left open, close it. *)
    IF (FileIsOpen) THEN CloseFile; END;

    IF (ProgramState < TLMainRunning) THEN
        RETURN FALSE;
    END;

    SetPageSettings;
    GenerateReportHeader(); (* KKC Apr 20, 1989 *)

    WITH PrintCB DO
        IF (NOT FileIsOpen) THEN
            IF (NOT GetRug(0,0,maxcol,maxrow,Rug)) THEN 
                Rug := ARug(NIL);
            END;
            IF (Style = OutToScreen) THEN
                OpenScreen;
            ELSIF (Style = OutToPrinter) THEN
                OpenPrinter;
            ELSE
                OpenDiskFile;
            END;
        END;
        Stopped := NOT FileIsOpen;
        IF NOT ((PrinterIsAtTopOfPage) OR (CCG.Pause)) THEN
            PageTop;
        END;
    END;

    IF (Stopped) THEN
        CloseFile;   (* Security check.  *)
    ELSE
        GetMessage(ModuleNumber+15,s);   (*  "Writing report.  Press any key to pause . . ."  *)
        ProgressMessage(s);
(**
        PrintString(CCG.Init);
***)
        PrintInitOrTerminateString ( CCG.Init );                    (* 3-Aug-89 MWP *)
        PageBreakEnabled := FALSE;  (* Always bracket the user procs to prevent recursion. *)
        SkipTopMargin;
        TopOfPageProc;  (* User-installed procedure. *)
        PageBreakEnabled := TRUE;
    END;

    RETURN NOT Stopped;
END StartReport;







    (*  EndReport  -- Call this when the report is done. *)

PROCEDURE EndReport;
VAR
    LocalName : ARRAY [0..1] OF CHAR;
BEGIN
    IF (FileIsOpen) THEN
            (* Restore normal print mode. *)
        SetMode(0);
            (* If we are not at the top of a page, do a page-eject.
               (except at the end of a word-processing document.)   *)
        IF (Row > 1) THEN
            IF (  (PrintCB.Style = OutToScreen) OR (PrintCB.ControlStyle <> WPNormal) )  THEN
                PageBreakEnabled := FALSE;  (* Don't break on footer. *)
                EndOfPageProc;              (* User-installed procedure. *)
                PageTop;                    (* Advance paper to new sheet. *)
            END;
        END;
(*
        PrintString( PrintCB.ControlStrings[PrintCB.ControlStyle].Terminate);
*)
        (* 3-Aug-89 MWP *)
        PrintInitOrTerminateString ( PrintCB.ControlStrings[PrintCB.ControlStyle].Terminate );
        ReportFinishedOK := TRUE;    (* Note our success. *)
    END;
    CloseFile;
    SetPageSettings;      (* Restore layout defaults. *)
    DiscardReportHeader();
END EndReport;


PROCEDURE PrintInitOrTerminateString ( VAR  Contents : AText );    (* 3-Aug-89 MWP *)
VAR
    Line                    : ARRAY [0..255] OF CHAR;
    i                       : CARDINAL;
BEGIN

    i := 0;

    WHILE ( LineExists ( Contents, i ) ) DO
        CopyLine ( Contents, i, Line );
        TrimRear ( Line );
        IF ( LengthOf( Line ) > 0 ) THEN
            PrintString ( Line );
        END;
        INC (i);
    END;

END PrintInitOrTerminateString;







    (*  IStopTest  --  Allow the user to cancel or resume the
                      report.   TRUE means Cancel. *)

PROCEDURE IStopTest(VAR S:ARRAY OF CHAR):BOOLEAN;
VAR
    Choice     : CARDINAL;
    Prefix     : ARRAY [0..41] OF CHAR;
    Choices    : ARRAY [0..255] OF CHAR;
BEGIN
    IF (NOT Stopped) THEN
        GetMessage(ModuleNumber+16,Prefix);   (* "Shall I" *)
        GetMessage(ModuleNumber+17,Choices);   (*  "Resume printing, Cancel printing"  *)
        Choice := 1;
           (* Find out what they want.  Do not allow the CancelKey
              since its meaning is unclear in this context. *)
        REPEAT
        UNTIL (MultipleChoiceBox( S, NillString, NoHelp, Prefix, Choices, Choice ));
        IF (Choice=2) THEN
            Choices[0] := 0C;               (* 12/7/85 AJL *)
            Message(Choices);               (* 12/7/85 AJL *)
            Stopped := TRUE;                (* Must set before any further action! *)
(*
            EndReport;
*)
        END;
    END;
    RETURN Stopped;
END IStopTest;



    (* StopTest, without any input parameter, to conform with the
       definition. *)

PROCEDURE StopTest():BOOLEAN;
BEGIN
    RETURN IStopTest(NillString);
END StopTest;






    (* SetMode -- Sets the current printer mode.
                  Must attempt output even if Stopped flag is TRUE. *)

PROCEDURE SetMode(Mode:CARDINAL);
BEGIN
    IF (CurrentMode <> Mode) THEN
        IF (Mode=0) THEN
            IF (PrintCB.Style = OutToScreen) THEN
                GlobalVideomode := videonormal;
            ELSE
                PrintString(CCG.Normal);
            END;
        ELSE
            IF (PrintCB.Style = OutToScreen) THEN
                GlobalVideomode := videofilter3;    (* Always a good contrast to videonormal. *)
            ELSE
                PrintString(CCG.Bold);
            END;
        END;
    END;
    CurrentMode := Mode;
END SetMode;




    (* TranslatedCharacter -- Converts the character as appropriate
                              to the printer or word processor's
                              character set. *)


PROCEDURE TranslateString(VAR S:ARRAY OF CHAR);
VAR
    Style : APrinterStyle;
    i,Len : CARDINAL;
BEGIN
    CASE PrintCB.ControlStyle OF
        PrinterNormal,
        PrinterCompressed :  Style := OutToPrinter;
     |  WPNormal          :  Style := OutToDisk;
        ELSE                 RETURN;
    END;


    Len := ORD(S[0]);
    i := 1;
    WHILE (i <= Len) DO
        S[i] := PrintXLAT[Style,ORD(S[i])];
        INC(i);
    END;
END TranslateString;




    (*  PrintText -- Print an LString to the print device.
                     If Stopped is returned as TRUE, the operator
                     has cancelled the printing.
                     PrintMode controls printer font. *)

PROCEDURE PrintText(VAR Line:ARRAY OF CHAR;
                    PrintMode : CARDINAL );
VAR
    i           : CARDINAL;
    s1          : ARRAY [0..1] OF CHAR;
    Line2       : ARRAY [0..255] OF CHAR;
    BlanksOnly  : BOOLEAN;
BEGIN
    IF (Stopped) THEN RETURN; END;

    IF (BreakRequested()) THEN
        ClearBreak();
        GetMessage(ModuleNumber+18,Line2);         (* "You pressed Break." *)
        IF (IStopTest(Line2)) THEN RETURN; END;
    END;

    Fill(s1," ",1);
    WITH PrintCB DO
        IF (RowsLeft()<=FootingRows) AND (PageBreakEnabled) THEN
            PageBreakEnabled := FALSE;  (* Prevent recursion. *)
            EndOfPageProc;  (* User-installed procedure. *)
            PageTop;
            SkipTopMargin;
            TopOfPageProc;  (* User-installed procedure. *)
            PageBreakEnabled := TRUE;
        END;
        IF (Line[0] > 0C) THEN
            SetMode(PrintMode);
            SubStr(Line,Line2,1,HIGH(Line2));
            TranslateString(Line2);
                (* See if it is only blanks.  *)    (* AJL Mar. 15, 1986 *)
            BlanksOnly := TRUE;
            i := 1;
            WHILE (i <= ORD(Line2[0])) AND (BlanksOnly) DO
                IF (Line2[i] <> " ") THEN
                    BlanksOnly := FALSE;
                END;
                INC(i);
            END;
                (* If it is printable stuff, then establish the mode. *)
            IF (NOT BlanksOnly) THEN
                SetMode(PrintMode);
            END;
                (* Print any needed margin. *)
            IF (AtLeftEdge) AND (LeftMarginIsWanted) THEN
                FOR i := 1 TO LeftMargin-1 DO
                    PrintString(s1);
                END;
            END;
                (* Print the text. *)
            PrintString(Line2);
            AtLeftEdge := FALSE;
        END;
    END;
END PrintText;





PROCEDURE PrintLine(VAR Line:ARRAY OF CHAR;
                    PrintMode : CARDINAL );
VAR
    LocalString         : ARRAY [0..CMaxLineSize] OF CHAR;

BEGIN
    Copy (Line, LocalString);
    TrimRear(LocalString);
    PrintText(LocalString,PrintMode);
    NextLine;
END PrintLine;










PROCEDURE AllowUnlimitedPageLength(Ok:BOOLEAN);
BEGIN
    PageLengthIsUnlimited := Ok;
END AllowUnlimitedPageLength;






PROCEDURE AllowLeftMargin(Ok:BOOLEAN);
BEGIN
    LeftMarginIsWanted := Ok;
END AllowLeftMargin;


PROCEDURE SetPageCaptionProcedures( AtTopOfPage,
                                    AtEndOfPage  : APageCaptionProcedure;
                                    FootRows     : CARDINAL );
BEGIN
    TopOfPageProc := AtTopOfPage;
    EndOfPageProc := AtEndOfPage;
    FootingRows   := FootRows;
END SetPageCaptionProcedures;


PROCEDURE NullProcedure;
BEGIN
END NullProcedure;



PROCEDURE CheckForTranslation();
BEGIN
    IF (PrintCB.Style = OutToDisk) AND
       (PrintCB.ControlStyle = WPNormal) AND
       (TranslateOverlay[0] > 0C) THEN
            IF (CallOverlay(TranslateOverlay)) THEN;END;
    END;
END CheckForTranslation;



BEGIN
    TopOfPageProc := NullProcedure;
    EndOfPageProc := NullProcedure;
    FootingRows   := 0;
    Stopped := TRUE;
    FileIsOpen := FALSE;
    PrinterIsAtTopOfPage := TRUE;
    SetLengthOf(NillString,0);
    VMaxPageLength := maxrow - 2;  (* 05-Jul-89 WKH *)
END PrintSupport.
