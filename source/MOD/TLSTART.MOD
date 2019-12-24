    (*V1=OS2 OS2 code changes.    *)
    (*V2=DOS Regular DOS TL code. *)

(*<OS2
IMPLEMENTATION MODULE TLStart;
OS2>*)
(*<DOS*)
MODULE TLStart;
(*DOS>*)


(*  =========================================================================
    Last Edit : August 16, 1991 4:14PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Load the config file and initialize everything.        

    MODIFICATION HISTORY:
    
        4-Jan-90 AJL    Get mouse speeds.
       30-Mar-90 RSC    Made Timeu to Timei/TimeForm conversions.
       17-Apr-90 MWP    Initialize week number information.
       20-Apr-90 KKC    Use date structure SystemTime for GetDateAndTime.
       19-Jun-90 AJL    Allow wider range of file extensions on startup line.
       15-Aug-90 RSC    Updated version number to 4.5; speed up cal init.
       27-Aug-90 PFG    Add loading of user-modified column names.
       26-Sep-90 PFG    Added more column types.
       23-Oct-90 TGS    Implement CONFIG IS <path> command line option.
       26-Oct-90 PFG    Move GetColumnNames into LoadCommon so column names
                        can be saved in schedule files as well as config.
        1-Nov-90 RSC    Don't init the calendar.
       10-Jan-91 AJL    Read new format text lines (as well as old).
       21-Jan-91 RSC    Remove Fiscal Calendar.
       13-Feb-91 RSC    Read printer support lines better.
       15-Feb-91 AJL    Remove ChartCodeSet.
       20-Feb-91 RSC    Added VersionConflict because I got one.
        2-Apr-91 TGS    Update version number to 5.0; "TLCNFG5.DAT"
       16-Aug-91 PFG    Added a parameter to the Layout and Filter info
                        procs (in LoadCommon) so that previous versions
                        can notify the procs to update for changes to
                        column order.
        4-Sep-91 TGS    Read calendar before environment (in particular, 
                        the asof date).
       06-Sep-91 LAA    Use the CurrentFileExtension variable rather than
                        getting this info from the phrases file, in
                        AbsorbParametersLine.  This should make it easier to
                        maintain for version 6.
       12-Sep-91 LAA    Fix the above fix.  I'd copied CurrentFileExtension
                        into an array too short to hold it, and lost the last
                        character.
    =========================================================================
*)




FROM AsOf         IMPORT  SetAsOfDate;

FROM BalExpr      IMPORT
    (* PROC *)       ParseCardinal, ParseExpression;

FROM BigTimeU     IMPORT
    (* Type *)       ABigTime,
    (* Proc *)       TimeToBigTime;

FROM Boxes        IMPORT  TransparentShadow;

FROM Chart        IMPORT
    (* VAR *)           GanttChart;

FROM ChartControl IMPORT
    (* TYPE *)          AChartState,
    (* PROC *)          SetState;

FROM Clock        IMPORT  
    (* TYPE *)          ASystemTime,
    (* PROC *)          GetDateAndTime;

FROM Codes        IMPORT  ASetOfCodes, SetCodeBits, EmptyCodeSet;

FROM CodeSets     IMPORT  CommandCodes, MenuCodeSet, 
                          FormsCodeSet;

FROM Dialog       IMPORT  Message, WarningBox, ADialogOption,
                          FatalError, Error;

FROM Directory              IMPORT
        (* TYPE *)              AFileAttribute, AFileAttributeSet,
        (* PROCS *)             ExtractDeviceName, ExtractFileNameParts,
                                NormalizeFileName, DirectoryIsReachable,
                                DOSVersion, FileLookupStart, PathLookupStart,
                                ExpandPath;

FROM FileAux      IMPORT  FileResultMeans, DisplayFileError,
                          FlushBuffer, EXEPath,
                          PrepareForIO, CheckIO, TextPath;

FROM FileOpen     IMPORT
        (* PROCS *)       RequestFileFind, RequestFileOpenReadOnly;

FROM FileSystem   IMPORT  File, Response, Close, Lookup, ReadChar,
                          SetWrite, Create, Rename, Delete;

FROM FlexStor     IMPORT
    (* TYPE *)           AnExtStatus,
    (* PROC *)           GetExtStatus;

FROM Foreign      IMPORT ExpandStringToXLAT, UpshiftTable, SortOrderTable,
                         DoDash, DecodeString;

FROM ForeignSubfiles IMPORT
    (* TYPE *)          AFileType,
    (* PROC *)          DigestSubfile;

FROM Gantt        IMPORT  ChartFont, SummaryFont, BaselineDetailFont,
                          BaselineSummaryFont;

FROM GrafFile     IMPORT
    (* PROC *)            StartGrafFileInput, ReadGrafFileSection,
                          EndGrafFileInput;

FROM Holder       IMPORT  HoldThis, AHoldType, AHoldTypeSet,
                          LocateHeldItem, DeleteHeldItem;

FROM IlsaStatic   IMPORT
    (* TYPE *)            ATLGSConfigRecord, ATLGSConfigRecordPtr,
                          ATLGSSetupRecord, ATLGSSetupRecordPtr,
                          AGraphicsOrientation, ATLGSChartType,
    (* PROC *)            TLGSConfigRecord, TLGSSetupRecord;

FROM InitTL       IMPORT
    (* PROC *)            InitTimeLineModules;

FROM Kbio         IMPORT  vidctrl, soundon, PutAttribute, CleanFlag, BlinkFlag,
                          KbioInit, avidmode, maxcol, maxrow, ascreeny,
                          SetCursorType, ACursorType, ascreenx;

FROM Keys         IMPORT
    (* VARS *)            CancelKey, Up, Down, DoIt, ComputeKey, OnMenu,
                          InsertKey, DeleteKey, CopyKey, OpenKey, CloseKey,
                          MoveUpKey, MoveDownKey, PromoteKey, DemoteKey,
                          EditKey, HelpKey, ExitKey, HelpIndexKey, UndoKey,
                          ReInsertKey, AltUndoKey, DaysKey, RedoKey;

FROM Layout       IMPORT
    (* VAR *)             GanttWStart, GanttWEnd;

FROM Lights       IMPORT  ActiveLightRegion, ShowLights, EnableLights;

FROM LoadCommon   IMPORT  SkipRecordBody, GetCalendar,
                          GetSignature, GetTheEnvironment,
                          SignatureError,
                          GetFiltersInfo, GetLayoutsInfo, GetMemosInfo,
                          GetHeldItems, GetNetLayoutsInfo,
                          ReadManyOldTextLines, ReadManyTextLines,
                          GetPalettesInfo, GetColumnNames;

FROM Logo          IMPORT
    (* PROC *)            Banner, StartLogo;

FROM LStrings      IMPORT SetString, ConcatS, ConcatLS, SubStr,
                          StringsEqual, CtoS, Fill, Insert, TrimRear,
                          TrimFront, Procustes, Remove, Search,
                          LengthOf, SetLengthOf, Upshift, Copy,
                          TStringToLString, LStringToTString, Compare;

IMPORT Mouse;

FROM MsgFile      IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Menus        IMPORT NoYes;

FROM Overlays     IMPORT CallOverlay;

FROM Paranoia     IMPORT AProgramState, ProgramState, InitializationOK;

FROM ParmLine     IMPORT
       (* PROCS *)    GetOption, GetFileName;

FROM ParseReal    IMPORT
    (* PROC *)        AmountToReal;

FROM PrintStatic  IMPORT  PrintCB, APrinterStyle, PrintXLAT,
                          TranslateOverlay, ReportSettings,
                          ReportHeaderTextIn, OutputDeviceName, AControlStyle,
                          APortType, AProtocol, OutputDiskName,
                          GlobalTimeOut;

FROM RealFormat   IMPORT
    (* Var *)        DefaultAmountFormat,
                     DefaultCurrencyFormat;

FROM RecordIO     IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                          ReadRecordBody, ReadStringBody;

FROM Registry     IMPORT  UserName;

(*<DOS*)
FROM RTSMain      IMPORT  Terminate, Status;                       (* V3 *)
(*DOS>*)

(*<OS2
FROM RTSTerm      IMPORT  Terminate;

FROM RTSTypes     IMPORT  Status;
OS2>*)


FROM RunMenu        IMPORT
    (* PROC *)          AddToMenuTree;

FROM Schedule       IMPORT  
    (* VAR *)           CurrentFileExtension,
                        ProjectMedia, Author, InstalledFlag,
                        RetrievalName, FullScheduleName;

FROM Subfiles     IMPORT  StartFileInput, StartSubfileInput,
                          TraverseSubfiles;

FROM SYSTEM       IMPORT  SIZE, ADR, ADDRESS, TSIZE;

FROM Text                       IMPORT
    (* TYPE *)                      AText,
    (* PROC *)                      AppendLine, CreateText, TextExists,
                                    Compress, CopyLine, AssignLine, LineExists,
                                    DiscardText;

FROM TimeFormat   IMPORT
    (* TYPE *)       ADateString,
    (* Var *)        DefaultDateAndTimeFormat,
                     DefaultDateFormat,
                     DefaultTimeFormat,
    (* PROC *)       InitializeTimeFormat;

FROM Timei        IMPORT
    (* TYPE *)       ADate,
    (* CONST *)      Jan, Dec, Sun,Sat,
    (* PROC *)       DayOfWeek, DaysInMonth;

FROM Timeu        IMPORT
    (* CONST *)           YearsOnFile,
    (* TYPE *)            AYearTable, ATimeTable, 
    (* VARS *)            TimeTable, SMUPH, SMU;
                          
FROM Transfer     IMPORT  RetrieveDammit;

(*<DOS*)
IMPORT VidType;
(*DOS>*)

(*<OS2
FROM VidType                IMPORT
    (* TYPE *)                  AQuestionType,
    (* VARS *)                  VideoConfiguration, Answers;
OS2>*)

FROM WeekNumberInfo         IMPORT
                                InitWeekNumberInfo;

FROM VersionConflict        IMPORT
    (* PROC *)                  ConflictProc;



CONST
    ModuleNumber  = 12300;   (* For GetMessage. *)

CONST
(*     ProjectType           = 1;*)
(*     EnvironmentType       = 2;*)
(*     PrintFileType         = 3;*)
(*     SummaryType           = 4;*)
(*     ResourceType          = 5;*)
(*     TaskType              = 6;*)
(*     EdgeType              = 8;*)
(*     CalendarType          = 9;*)
(*     BugsType              = 10;*)
(*     SignatureType         = 11;*)
     PrinterTableType      = 12;
     FileNamesType         = 13;
     VideoType             = 14;
     PreferencesType       = 15;
     CodeSetsType          = 16;
     FontsType             = 17;
(*     PlotsType             = 18;*)
(*     FiltersType           = 19;*)
(*     HeldItemsType         = 20;*)
(*     MemosType             = 21;*)
(*     LayoutsType           = 23;*)
(*     NetLayoutsType        = 24;*)
     TLGSDeviceType        = 25;                                  (* 21-May-89 LAA *)
(*     ColumnNamesType       = 29;*)

(*     ResourceFileVersionNumber   = 1;*)
(*     TaskFileVersionNumber       = 9;*)
(*     EdgeFileVersionNumber       = 6;*)
(*     EnvironmentVersionNumber    = 17;*)
(*     CalendarFileVersionNumber   = 1;*)
(*     BugsFileVersionNumber       = 1;*)





CONST
    ConfigFileName              = "TLCNFG5.DAT";



VAR
    Size              : CARDINAL;
    Category          : AHoldTypeSet;
    CrudeVideo,
    GlobalFontsInFile : BOOLEAN;
    s                 : ARRAY [0..81] OF CHAR;




    (* If the run line contains any VIDEO= option, disable Blink, disable
       Fast. *)

PROCEDURE CheckVideoOff();
VAR
    i : CARDINAL;
    OptionName : ARRAY [0..9] OF CHAR;
    S : ARRAY [0..81] OF CHAR;
BEGIN
    SetString(OptionName,"VIDEO");
    GetOption(OptionName,CrudeVideo,S);
    IF (CrudeVideo) THEN
        BlinkFlag := FALSE;
        CleanFlag := TRUE;
    END;
END CheckVideoOff;



PROCEDURE GetTLGSConfigInfo(VAR F           : File);              (* 21-May-89 LAA *)

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    DeviceSetup             : ATLGSConfigRecordPtr;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* GetTLGSConfigInfo *)

    IF (NOT StartSubfileInput(F, TLGSDeviceType, Version)) THEN   (* 01-Jun-89 LAA *)
        RETURN;
    END;

    DeviceSetup := TLGSConfigRecord();
    IF (DeviceSetup = NIL) THEN
        FatalError();
    END;

    Copy( EXEPath, s ); (* RSC 12-Jun-89 *)
    ConcatMessage( s, ModuleNumber+8 ); (* "GDRIVERS\"  RSC 12-Jun-89 *)

    DeviceSetup^.ConfigDescription := CreateText();
    IF (AppendLine(s, DeviceSetup^.ConfigDescription)) THEN END;
    SetLengthOf(s, 0);
    IF (AppendLine(s, DeviceSetup^.ConfigDescription)) THEN END;

    LOOP
        ReadRecordPreface(F,Type,Length);
        CASE Type OF
            2  :  ReadRecordBody(F, Length, DeviceSetup,
                                 TSIZE(ATLGSConfigRecord));
                  DeviceSetup^.ConfigDescription := AText(NIL);
          | 100:  ReadManyOldTextLines(F, Length, 100, DeviceSetup^.ConfigDescription);
          | 102:  ReadManyTextLines(F, Length, 102, DeviceSetup^.ConfigDescription);
          | 0FFH : EXIT;
        ELSE    SkipRecordBody(F, Length);
        END;
    END;

END GetTLGSConfigInfo;




(* Scans a text looking for the Nth non-comment line.

    Preconditions
                    TheText     A text with lines in it.
                    LogicalLine desired line, starting with 1.
    Postconditions
                    PhysLine    physical line found on, starting at 0.
                    s           text found.
*)
PROCEDURE GetTextLine( VAR TheText      : AText;
                           LogicalLine  : CARDINAL;
                       VAR PhysLine     : CARDINAL;
                       VAR s            : ARRAY OF CHAR ) : BOOLEAN;
VAR
    ErrorText   : ARRAY [0..255] OF CHAR;

BEGIN
    PhysLine := 0;
    WHILE (LogicalLine > 0) DO
        IF (LineExists( TheText, PhysLine )) THEN
            CopyLine( TheText, PhysLine, s );
            IF (NOT ((LengthOf(s) > 1)    AND     (* IF not a comment, *)
                     (s[1] = "-")         AND
                     (s[2] = "-")))       THEN
                DEC(LogicalLine);                (* THEN dec count of lines *)
            END;
        ELSE
            RETURN FALSE;
        END;
        INC(PhysLine);                           (* and go on to the next.  *)
    END;

    DEC(PhysLine);  (* Oops.  We are one higher than we want. *)

    RETURN TRUE;

END GetTextLine;


(* Given a path and file name, try to open a file.
*)
PROCEDURE GetFile( VAR Path,
                       FileName,
                       Ext              : ARRAY OF CHAR;
                   VAR TheFile          : File;
                       CreateFile       : BOOLEAN;
                   VAR FileExists       : BOOLEAN
                                      ) : BOOLEAN;
VAR
    Attributes   : AFileAttributeSet;
    FullFileName : ARRAY [0..159] OF CHAR;
    FoundFile    : ARRAY [0..59]  OF CHAR;

BEGIN
    Copy( Path, FullFileName );
    ConcatLS(   FullFileName, FileName );
    ConcatS(    FullFileName, "." );
    ConcatLS(   FullFileName, Ext );

    Copy( FileName, FoundFile );
    Attributes := AFileAttributeSet{ReadOnlyAttribute};

    PrepareForIO( TheFile );

    (* Does the file already exist? *)
    FileExists := FileLookupStart( FullFileName, FoundFile, Attributes );

    LStringToTString( FullFileName, FullFileName );

    PrepareForIO( TheFile );
    Lookup( TheFile, FullFileName, CreateFile );

    (* If there was a file error, return FALSE. *)

    RETURN (CheckIO( TheFile ) = done);

END GetFile;




PROCEDURE GetTLGSValuesInfo();

VAR
    TheText                 : AText;
    i                       : CARDINAL;
    j                       : CARDINAL;
    Setup                   : ATLGSSetupRecordPtr;
    ConfigRecord            : ATLGSConfigRecordPtr;
    ValuFile                : File;
    PathName                : ARRAY [0..9] OF CHAR;
    FileName                : ARRAY [0..9] OF CHAR;
    Ext                     : ARRAY [0..3] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..255] OF CHAR;
    FileExists              : BOOLEAN;



    PROCEDURE InitPlotAreas();
    VAR
        PaperFeedOrientation    : AGraphicsOrientation;
    BEGIN
        WITH Setup^ DO
            IF (PhysPageWide <= PhysPageHigh) THEN        (* 09-Nov-89 LAA *)
                PaperFeedOrientation := Portrait;
            ELSE                                                      
                PaperFeedOrientation := Landscape;
            END;

            IF ((PhysPageWide <> PhysPageHigh) 
                 AND (Orientation <> PaperFeedOrientation)) THEN
                PlotAreaHigh := OrigPlotAreaWide;                     (* 22-Jun-89 LAA *)
                IF (ContinuousPrint) THEN
                    PlotAreaWide := PhysPageHigh;
                ELSE
                    PlotAreaWide := OrigPlotAreaHigh;
                END;
            ELSE
                PlotAreaWide := OrigPlotAreaWide;
                IF (ContinuousPrint) THEN
                    PlotAreaHigh := PhysPageHigh;
                ELSE
                    PlotAreaHigh := OrigPlotAreaHigh;
                END;
            END;
        END;
    END InitPlotAreas;




    PROCEDURE InitSetupField();

    VAR
        Id                  : CARDINAL;
        x                   : CARDINAL;
        ok                  : BOOLEAN;

    BEGIN                   (* InitSetupField *)

        IF (ParseCardinal(s, 1, Id)) THEN
            CASE Id OF
                1 : IF (ParseExpression(s, 3, s2)) THEN
                        AmountToReal(s2, Setup^.PhysPageWide, ok);
                    END;
            |   2 : IF (ParseExpression(s, 3, s2)) THEN
                        AmountToReal(s2, Setup^.PhysPageHigh, ok);
                    END;
            |   3 : IF (ParseExpression(s, 3, s2)) THEN
                        AmountToReal(s2, Setup^.OrigPlotAreaWide, ok);  (* 29-Jun-89 LAA *)
                    END;
            |   4 : IF (ParseExpression(s, 3, s2)) THEN
                        AmountToReal(s2, Setup^.OrigPlotAreaHigh, ok);  (* 29-Jun-89 LAA *)
                    END;
            |   5 : IF (ParseCardinal(s, 3, x)) THEN
                        Setup^.AskContinuous := (x = 1);
                    END;
            |   6 : IF (ParseCardinal(s, 3, x)) THEN
                        Setup^.ContinuousPrint := (x = 1);
                    END;
            |   7 : IF (ParseCardinal(s, 3, x)) THEN
                        Setup^.Orientation := VAL(AGraphicsOrientation, x);
                    END;
            |   8 : IF (ParseExpression(s, 3, s2)) THEN
                        IF (NOT TextExists(Setup^.DeviceDescription)) THEN
                            Setup^.DeviceDescription := CreateText();
                        END;
                        IF (AssignLine(s2, 1, Setup^.DeviceDescription)) THEN END;
                    END;
            ELSE
            END;
        END;

    END InitSetupField;



BEGIN                       (* GetTLGSValuesInfo *)

    ConfigRecord := TLGSConfigRecord();
    CopyLine(ConfigRecord^.ConfigDescription, 1, FileName);
    Setup := TLGSSetupRecord();
    IF (Setup = NIL) THEN
        FatalError();
    END;
    SetString(Ext, "%GV");
    Ext[1] := CurrentFileExtension[2]; (* "5" *) (* 4-Sep-91 TGS *)

    SetString(PathName, "DK:");
    IF (GetFile(PathName, FileName, Ext, ValuFile, FALSE, FileExists)) THEN
        IF (StartGrafFileInput(ValuFile)) THEN
            IF (ReadGrafFileSection(ValuFile, 1, TheText)) THEN
                IF (GetTextLine(TheText, 3, j, s)) THEN
                    IF (ParseExpression(s, 3, s2)) THEN
                        IF (NOT TextExists(Setup^.DeviceDescription)) THEN
                            Setup^.DeviceDescription := CreateText();
                        END;
                        IF (AssignLine(s2, 0, Setup^.DeviceDescription)) THEN END;
                    END;
                END;
            END;
            DiscardText(TheText);
            IF (ReadGrafFileSection(ValuFile, 2, TheText )) THEN
                i := 1;
                WHILE (GetTextLine(TheText, i, j, s)) DO
                    InitSetupField();
                    INC(i);
                END;
                InitPlotAreas();            (* 11/30/89 LAA/EGK *)
            END;
            DiscardText(TheText);
        END;
        Close(ValuFile);
    END;

END GetTLGSValuesInfo;




PROCEDURE GetPrinterTable(VAR f:File);
CONST
     MaxWidth                    = 255;  (* KKC  May 4, 1989 *)
VAR
    Type          : CARDINAL;
    Length        : CARDINAL;
    Version       : CARDINAL;
    TextPos       : CARDINAL;
    s             : ARRAY[0..MaxWidth] OF CHAR;


    PROCEDURE ReadOldPrintCBRecord();
    TYPE
        AnOldControlGroup = RECORD
                        Init         : ARRAY [0..80] OF CHAR;
                        Terminate    : ARRAY [0..80] OF CHAR;
                        NewPage      : ARRAY [0..20] OF CHAR;
                        NewLine      : ARRAY [0..20] OF CHAR;
                        Normal       : ARRAY [0..30] OF CHAR;
                        Bold         : ARRAY [0..30] OF CHAR;
                        TopMargin,
                        BottomMargin,
                        LeftMargin,
                        RightMargin  : CARDINAL;
                        Pause        : BOOLEAN;
                        FillerByte   : CHAR;    (* MAKE EVEN LENGTHED *)
                    END;

        AnOldPrintCBRecord = RECORD
                            (* Where is the output directed. *)
                        Style    : APrinterStyle;
                            (* Margins currently in use? *)
                        TopMargin,
                        BottomMargin,
                        LeftMargin,
                        RightMargin  : CARDINAL;
                            (* If a printer, which one. *)
                        PrinterNumber : CARDINAL;
                            (* What kind of control sequences. *)
                        ControlStyle      : AControlStyle;
                            (* Serial or parallel printer or DOS calls *)
                        PortType     : APortType;
                            (* These next fields are used only if
                               we are using a serial port.   The port
                               number is then stored in PrinterNumber. *)
                        BaudRate,
                        StopBits,
                        NumberOfBits : CARDINAL;
                        ParityBit,
                        EvenParity   : BOOLEAN;
                        Protocol     : AProtocol;
                            (* Some useful filler. *)
                        Filler1      : ARRAY [0..15] OF CARDINAL;
                            (* The secret controls. *)
                        ControlStrings : ARRAY AControlStyle OF AnOldControlGroup;
                    END;
    VAR
        i           : AControlStyle;
        OldPrintCB  : AnOldPrintCBRecord;
        ok          : BOOLEAN;
    BEGIN
        ReadRecordBody(f,Length,ADR(OldPrintCB),SIZE(OldPrintCB));
        WITH OldPrintCB DO
            PrintCB.Style           := Style;
            PrintCB.TopMargin       := TopMargin;
            PrintCB.BottomMargin    := BottomMargin;
            PrintCB.LeftMargin      := LeftMargin;
            PrintCB.RightMargin     := RightMargin;
            PrintCB.PrinterNumber   := PrinterNumber;
            PrintCB.ControlStyle    := ControlStyle;
            PrintCB.PortType        := PortType;
            PrintCB.BaudRate        := BaudRate;
            PrintCB.StopBits        := StopBits;
            PrintCB.NumberOfBits    := NumberOfBits;
            PrintCB.ParityBit       := ParityBit;
            PrintCB.EvenParity      := EvenParity;
            PrintCB.Protocol        := Protocol;
            FOR i := PrinterNormal TO NoControls DO
                WITH OldPrintCB.ControlStrings[i] DO
                    IF (LengthOf( Init ) = 0) THEN
                        PrintCB.ControlStrings[i].Init := AText(NIL);
                    ELSE
                        PrintCB.ControlStrings[i].Init := CreateText();
                        ok := AssignLine( Init, 0, PrintCB.ControlStrings[i].Init );
                    END;
                    IF (LengthOf( Terminate ) = 0) THEN
                        PrintCB.ControlStrings[i].Terminate := AText(NIL);
                    ELSE
                        PrintCB.ControlStrings[i].Terminate := CreateText();
                        ok := AssignLine( Terminate, 0, PrintCB.ControlStrings[i].Terminate );
                    END;
                    Copy( NewPage, PrintCB.ControlStrings[i].NewPage );
                    Copy( NewLine, PrintCB.ControlStrings[i].NewLine );
                    Copy( Normal,  PrintCB.ControlStrings[i].Normal  );
                    Copy( Bold,    PrintCB.ControlStrings[i].Bold    );
                    PrintCB.ControlStrings[i].TopMargin     := TopMargin;
                    PrintCB.ControlStrings[i].BottomMargin  := BottomMargin;
                    PrintCB.ControlStrings[i].LeftMargin    := LeftMargin;
                    PrintCB.ControlStrings[i].RightMargin   := RightMargin;
                    PrintCB.ControlStrings[i].Pause         := Pause;
                END;
            END;
        END;

    END ReadOldPrintCBRecord;


    PROCEDURE InitPrintCBTexts();
    VAR
        i : AControlStyle;
    BEGIN
        FOR  i := PrinterNormal TO NoControls DO
            PrintCB.ControlStrings[i].Init      := AText(NIL);
            PrintCB.ControlStrings[i].Terminate := AText(NIL);
        END;
    END InitPrintCBTexts;

    PROCEDURE ReadPrinterText(VAR f : File; Length : CARDINAL;
                                  Type      : CARDINAL;
                                  OldFormat : BOOLEAN );
    VAR
       Text : AText;
    BEGIN
        CASE Type OF
            100:  Text := ReportHeaderTextIn;
          | 101:  Text := PrintCB.ControlStrings[PrinterNormal].Init;
          | 102:  Text := PrintCB.ControlStrings[PrinterNormal].Terminate;
          | 103:  Text := PrintCB.ControlStrings[PrinterCompressed].Init;
          | 104:  Text := PrintCB.ControlStrings[PrinterCompressed].Terminate;
          | 105:  Text := PrintCB.ControlStrings[WPNormal].Init;
          | 106:  Text := PrintCB.ControlStrings[WPNormal].Terminate;
          | 107:  Text := PrintCB.ControlStrings[NoControls].Init;
          | 108:  Text := PrintCB.ControlStrings[NoControls].Terminate;
        ELSE
            SkipRecordBody(f,Length);
            RETURN;
        END;

        IF (OldFormat) THEN
            ReadManyOldTextLines(f, Length, Type, Text );
        ELSE
            ReadManyTextLines(   f, Length, Type+10, Text );    (* 13-Feb-91 RSC *)
        END;

        CASE Type OF
            100:  ReportHeaderTextIn := Text;
          | 101:  PrintCB.ControlStrings[PrinterNormal].Init := Text;
          | 102:  PrintCB.ControlStrings[PrinterNormal].Terminate := Text;
          | 103:  PrintCB.ControlStrings[PrinterCompressed].Init := Text;
          | 104:  PrintCB.ControlStrings[PrinterCompressed].Terminate := Text;
          | 105:  PrintCB.ControlStrings[WPNormal].Init := Text;
          | 106:  PrintCB.ControlStrings[WPNormal].Terminate := Text;
          | 107:  PrintCB.ControlStrings[NoControls].Init := Text;
          | 108:  PrintCB.ControlStrings[NoControls].Terminate := Text;
        END;

    END ReadPrinterText;

BEGIN

    IF (NOT StartSubfileInput(f,PrinterTableType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF

            1  :  ReadOldPrintCBRecord();
          | 2  :  ReadRecordBody(f,Length,ADR(PrintXLAT[OutToPrinter]),SIZE(PrintXLAT[OutToPrinter]));
          | 3  :  ReadRecordBody(f,Length,ADR(PrintXLAT[OutToDisk]),SIZE(PrintXLAT[OutToDisk]));
          | 4  :  ReadStringBody(f,Length,TranslateOverlay);
          | 5  :  ReadRecordBody(f,Length,ADR(ReportSettings),SIZE(ReportSettings));
          | 6  :  ReadRecordBody(f,Length,ADR(PrintCB),SIZE(PrintCB));   (* 3-Aug-89 MWP *)
                  InitPrintCBTexts();
          | 7  :  ReadStringBody(f,Length,OutputDeviceName );
          | 8  :  ReadStringBody(f,Length,OutputDiskName );
          | 9  :  ReadRecordBody(f,Length,ADR(GlobalTimeOut),SIZE(GlobalTimeOut));
          | 100..108: ReadPrinterText(f,Length,Type,TRUE);     (* Old format text. *)
          | 110..118: ReadPrinterText(f,Length,Type-10,FALSE); (* NewFormatText. *)
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetPrinterTable;












PROCEDURE GetFileNames(VAR f:File);
VAR
    Version       : CARDINAL;
    s             : ARRAY [0..19] OF CHAR;
BEGIN
    IF (StartSubfileInput(f,FileNamesType,Version)) THEN
        ReadString(f,RetrievalName);
        ReadString(f,ProjectMedia);

        (* Removed OverlayOption setup.  RSC 12-Jun-89 *)
    ELSE
        GetMessage(ModuleNumber+1,s);   (*  "Config file: missing file and path names."  *)
        Error(s);
    END;
END GetFileNames;





PROCEDURE GetVideo(VAR f:File);
VAR
    Version : CARDINAL;
    Type    : CARDINAL;
    Length  : CARDINAL;
BEGIN
    IF (StartSubfileInput(f,VideoType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1:    ReadRecordBody(f,Length,ADR(vidctrl),SIZE(vidctrl));
              | 2:    ReadRecordBody(f,Length,ADR(TransparentShadow),SIZE(TransparentShadow));
(*<DOS*)
              | 3:    ReadRecordBody(f,Length,ADR(VidType.VideoConfiguration),SIZE(VidType.VideoConfiguration));
              | 4:    ReadRecordBody(f,Length,ADR(VidType.Answers           ),SIZE(VidType.Answers           ));
(*DOS>*)
(*<OS2
              | 3:    ReadRecordBody(f,Length,ADR(VideoConfiguration),SIZE(VideoConfiguration));
              | 4:    ReadRecordBody(f,Length,ADR(Answers           ),SIZE(Answers           ));
OS2>*)
              | 5:    ReadRecordBody(f,Length,ADR(CleanFlag),SIZE(CleanFlag));  (* 13-Sep-89 LAA *)
              | 6:    ReadRecordBody(f,Length,ADR(BlinkFlag),SIZE(BlinkFlag));  (* 13-Sep-89 LAA *)
              | 0FFH : EXIT;
            ELSE
                SkipRecordBody (f, Length);         (* 12/6/88 EGK *)
            END;
        END;
    END;
END GetVideo;





PROCEDURE GetPreferences(VAR f:File);
VAR
    Version : CARDINAL;
    Type    : CARDINAL;
    Length  : CARDINAL;
BEGIN
    IF (StartSubfileInput(f,PreferencesType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1:    ReadRecordBody(f,Length,ADR(soundon),SIZE(soundon));
              | 2:    ReadRecordBody(f,Length,ADR(InstalledFlag),SIZE(InstalledFlag));
              | 3:    ReadRecordBody(f, Length, ADR(DefaultDateAndTimeFormat),          (* 09-Nov-88 LAA *)
                                     SIZE(DefaultDateAndTimeFormat));
              | 4:    ReadRecordBody(f, Length, ADR(DefaultDateFormat),
                                     SIZE(DefaultDateFormat));
              | 5:    ReadRecordBody(f, Length, ADR(DefaultTimeFormat),
                                     SIZE(DefaultTimeFormat));
              | 6:    ReadRecordBody(f, Length, ADR(DefaultAmountFormat),
                                     SIZE(DefaultAmountFormat));
              | 7:    ReadRecordBody(f, Length, ADR(DefaultCurrencyFormat),
                                     SIZE(DefaultCurrencyFormat));
              | 8:    ReadRecordBody(f, Length, ADR(UserName),
                                     SIZE(UserName));  (* 12-Jul-89 WKH *)
              | 9:    ReadRecordBody(f, Length, ADR(Mouse.RepeatRate),
                                     SIZE(Mouse.RepeatRate));
              | 10:   ReadRecordBody(f, Length, ADR(Mouse.DoubleClickRate),
                                     SIZE(Mouse.DoubleClickRate));
              | 0FFH : EXIT;
            ELSE
                SkipRecordBody (f, Length);         (* 12/6/88 EGK *)
            END;
        END;
    END;

END GetPreferences;









PROCEDURE GetCodeSets(VAR f:File);
VAR
    Version : CARDINAL;
    DummyCodeSet : ASetOfCodes;

    PROCEDURE GetCodeSet (VAR CodeSet:ASetOfCodes);
    VAR
        Type : CARDINAL;
    BEGIN
        ReadRecord(f,Type,ADR(CodeSet),SIZE(CodeSet));
    END GetCodeSet;

BEGIN
    IF (StartSubfileInput(f,CodeSetsType,Version)) THEN
        GetCodeSet(CommandCodes);
        GetCodeSet(MenuCodeSet);                                  (* 09-Nov-88 LAA *)
        GetCodeSet(FormsCodeSet);
        GetCodeSet(DummyCodeSet);
    ELSE
        GetMessage(ModuleNumber + 02, s);       (* "Config file: missing keyboard code sets." *)
        Error(s);
    END;
    MenuCodeSet := EmptyCodeSet;
    SetCodeBits(MenuCodeSet, OnMenu, OnMenu, TRUE);
    SetCodeBits(MenuCodeSet, InsertKey, InsertKey, TRUE);         (* 10-Feb-88 LAA *)
    SetCodeBits(MenuCodeSet, DeleteKey, DeleteKey, TRUE);
    SetCodeBits(MenuCodeSet, CopyKey, CopyKey, TRUE);
    SetCodeBits(MenuCodeSet, OpenKey, OpenKey, TRUE);
    SetCodeBits(MenuCodeSet, CloseKey, CloseKey, TRUE);
    SetCodeBits(MenuCodeSet, EditKey, ComputeKey, TRUE);          (* 11-Feb-88 LAA *)
    SetCodeBits(MenuCodeSet, HelpIndexKey, UndoKey, TRUE);
    SetCodeBits(MenuCodeSet, ReInsertKey, AltUndoKey, TRUE);
    SetCodeBits(MenuCodeSet, DaysKey, RedoKey, TRUE);
END GetCodeSets;





PROCEDURE GetFonts(VAR f:File);
CONST
    FontsName       = "FontsInFile";
    FontsClass      = 1709;         (* Subfile and record number *)
VAR
    Version : CARDINAL;
    Type    : CARDINAL;
    Length  : CARDINAL;
    s       : ARRAY [0..20] OF CHAR;

BEGIN
    GlobalFontsInFile := FALSE;
    SetString (s, FontsName);
    DeleteHeldItem (s, FontsClass);         (* 4/4/89 EGK *)

    IF (NOT StartSubfileInput(f,FontsType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
          | 9:    ReadRecordBody(f,Length,ADR(GlobalFontsInFile),SIZE(GlobalFontsInFile));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

    IF (GlobalFontsInFile) THEN
        HoldThis (s, FontsClass, AHoldTypeSet{}, NIL, 0);
    ELSE
        RETURN;     (*  Don't go any further, else you'll overwrite the
                        default fonts   *)
    END;

    IF (NOT StartSubfileInput(f,FontsType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
          | 2:    ReadRecordBody(f,Length,ADR(ChartFont),SIZE(ChartFont));
          | 3:    ReadRecordBody(f,Length,ADR(SummaryFont),SIZE(SummaryFont));
          | 4:    ReadRecordBody(f,Length,ADR(BaselineDetailFont),SIZE(BaselineDetailFont));
          | 5:    ReadRecordBody(f,Length,ADR(BaselineSummaryFont),SIZE(BaselineSummaryFont));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetFonts;





PROCEDURE DuplicatesOK( VAR z : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    RETURN TRUE;
END DuplicatesOK;






CONST
   FSIG     =  0;
   FNAMES   =  1;
   FCAL     =  2; (* <-- 4-Sep-91 TGS duplicate Ed's fix for TLITL5 *)
   FENV     =  3; (* <--          ..switch order these are read in  *)
   FFILTER  =  4;
   FMEMO    =  5;
   FLAYOUT  =  6;
   FPLOT    =  7;
   FCOLUMNS =  8;
   FPRINT   =  9;
   FCODES   = 10;
   FFONTS   = 11;
   FPREF    = 12;
   FNLAYOUT = 13;
   ALIEN    = 14; (* 1-Sep-89 RSC *)


PROCEDURE GetCnfg (VAR FileName   : ARRAY OF CHAR;
                       Selections : BITSET
                  ) : BOOLEAN;
VAR
    i, j        : CARDINAL;
    cnfgfile    : File;
    OptionName  : ARRAY [0..9] OF CHAR;
    TempTextPath, ParmLinePath, DefaultPath, SavePath
                : ARRAY [0..99] OF CHAR;
    s           : ARRAY [0..255] OF CHAR;
    ok          : BOOLEAN;
    NewUser     : BOOLEAN;
    FileType    : AFileType;

    PROCEDURE FileComplaint;
    BEGIN
        GetMessage(ModuleNumber+3,s);   (*  "Cnfg file "  *)
        ConcatLS(s,FileName);
        DisplayFileError( cnfgfile, s );
    END FileComplaint;

BEGIN
    SetString( DefaultPath, "DK:;" );  

    (* 23-Oct-90 TGS *)
    SetString(OptionName,"CONFIG");
    GetOption(OptionName,ok,ParmLinePath);
    IF (ok) THEN
        ExpandPath(ParmLinePath, DefaultPath, TempTextPath);
        ConcatS(TempTextPath, ";");
    ELSE
        Copy(DefaultPath, TempTextPath);
    END;

    Copy(TempTextPath, SavePath);

    NewUser := NOT PathLookupStart( TempTextPath, FileName, TempTextPath, s ); (* KKC Aug 22, 89 *)

    Copy( SavePath, TempTextPath );
    ConcatLS(  TempTextPath, TextPath );
    IF (NOT RequestFileOpenReadOnly(TempTextPath,FileName,s,cnfgfile)) THEN
        RETURN FALSE;
    END;

    IF (NOT StartFileInput(cnfgfile)) THEN
        Close(cnfgfile);
        RETURN FALSE;
    END;

    IF (CheckIO(cnfgfile) <> done) THEN
        FileComplaint;
        RETURN FALSE;
    END;

    GetVideo(cnfgfile);
         (* Allow tech support to disable fancy video options.
            Supercede and held items (blink, fast).   *)
    CheckVideoOff();         (* AJL 3/13/89 *)
    KbioInit();
    SetCursorType(NoCursor); (* RSC 11/5/87 *)
    StartLogo();
    Banner();

    ok := TRUE;
    i := 0;
    LOOP
        IF (NOT ok) THEN EXIT; END;
        IF (i > 15) THEN
            EXIT;
        ELSIF (i IN Selections) THEN
            CASE i OF
                FSIG   :  ok := GetSignature(cnfgfile,j); (* 26-Oct-89 RSC *)
                          IF (ok) THEN
                              ok := (j = 450) OR (j = 500); (* 2-Apr-91 TGS *)
                              IF (NOT ok) THEN
                                  SignatureError(500,j);
                              END;
                          END;

              | FNAMES :  GetFileNames(cnfgfile);
              | FENV   :  GetTheEnvironment(cnfgfile);
                          SetState(Scheduled);    (* 27-Sep-89 RSC *)
              | FCAL   :  GetCalendar(cnfgfile);
              | FPREF  :  GetPreferences(cnfgfile);
              | FCODES :  GetCodeSets(cnfgfile);
              | FFONTS :  GetFonts(cnfgfile);
              | FPLOT  :  GetTLGSConfigInfo(cnfgfile);            (* 21-May-89 LAA *)
                          GetPalettesInfo(cnfgfile,TLGSGanttChart,DuplicatesOK,TRUE);  (* 21-Jun-89 LAA *)
                          GetPalettesInfo(cnfgfile,TLGSPertChart,DuplicatesOK,TRUE);
                          GetPalettesInfo(cnfgfile,TLGSTreeChart,DuplicatesOK,TRUE);
              | FCOLUMNS: GetColumnNames(cnfgfile);     (* 10-Sep-90 PFG *)
              | FPRINT :  GetPrinterTable(cnfgfile);
              | FLAYOUT:  GetLayoutsInfo(cnfgfile,DuplicatesOK,TRUE,FALSE);  (* EGK 8/11/87 *)
              | FFILTER:  GetFiltersInfo(cnfgfile,DuplicatesOK,FALSE,FALSE);     (* EGK 8/12/87 *)
              | FMEMO  :  GetMemosInfo(cnfgfile);       (* EGK 8/13/87 *)
              | FNLAYOUT: GetNetLayoutsInfo(cnfgfile, DuplicatesOK,TRUE,FALSE);  (* 17-Nov-87 LAA *)
              | ALIEN:
                        FileType := ConfigFile;
                        TraverseSubfiles( cnfgfile, DigestSubfile, ADR( FileType ) );

              ELSE  ;
            END;
        END;
        IF (ok) THEN
            ok := (CheckIO(cnfgfile) = done);
        END;
        INC(i);
    END;

    InitWeekNumberInfo ();                                        (* 17-Apr-90 MWP *)

    GetHeldItems(cnfgfile);                                       (* 13-Sep-89 LAA *)

    Close(cnfgfile);
    IF (CheckIO(cnfgfile) <> done) THEN
        FileComplaint;
        RETURN FALSE;
    END;

    IF ( NewUser ) THEN
        InstalledFlag := FALSE;
    END;

    RETURN TRUE;
END GetCnfg;







    (*  SetClock -- Check that the current clock time is plausible.  If
                    not, get a new time from the user and set the system
                    clock. *)


PROCEDURE SetClock;
VAR
    SystemTime  :   ASystemTime;
    s  : ARRAY [0..29] OF CHAR;
    ok : BOOLEAN;
BEGIN
    GetDateAndTime( SystemTime );
    IF (SystemTime.SysYear < 1984) THEN
        SetString( s, "TLFBASE(TLSETCLK)" );
        ok := CallOverlay( s );
    END;
END SetClock;








PROCEDURE AbsorbParameterLine();
VAR i     : CARDINAL;
    s     : ARRAY [0..99]  OF CHAR;
    FName : ARRAY [0..128] OF CHAR;
    Drive : ARRAY [0..5]   OF CHAR;
    Path1,
    Path  : ARRAY [0..64]  OF CHAR;
    Name  : ARRAY [0..12]  OF CHAR;
    s1,
    Ext   : ARRAY [0..3]   OF CHAR;
    ok    : BOOLEAN;

BEGIN

   (* See if they want the dammit option, or have a real file name. *)

    SetString(s,  "!");
    SetString(Ext,"!?");
    GetFileName( FName );
    (* Compare() --> StringsEqual() by RSC 1/2/88 *)
    IF (StringsEqual( FName, s )) THEN  (* RETRIEVE, DAMMIT! *)
        RetrieveDammit := TRUE;
    ELSIF (StringsEqual( FName, Ext )) THEN  (* RETRIEVE, Maybe? *)
        GetMessage( ModuleNumber + 0, s ); (* "Would you like to reload the last schedule you worked on?" *)
        RetrieveDammit := NoYes( s );
    ELSIF (FName[0] <> 0C) THEN
        ExtractFileNameParts( FName, Drive, Path, Name, Ext );
        TrimRear(Name);
        IF (LengthOf(Name) = 0) THEN
           SetString(Name,"*");
        END;
        IF (LengthOf(Ext) > 0) THEN
            Copy( CurrentFileExtension, s );     (* ".5T0" --> "5T"  *)
            Remove( s, 1, 1 );
            SetLengthOf( s, 2 );
            i := 1;
            IF (Search(Ext,s,i) <> 1) THEN
                GetMessage( ModuleNumber + 50, FName ); (* Only 'T%0' allowed *)
                Error( FName );
                RETURN;
            END;
        ELSE
            SubStr( CurrentFileExtension, Ext, 2, 3 );  (* ".5T0 --> "5T0"  *)
        END;
        SetString( s,  "\" );
        SetString( s1, ":" );
        IF (Search(FName, s, 1)=0) AND (Search(FName, s1, 1)=0) THEN
            SetString( Path, "DK:;" );
            ConcatLS(  Path, ProjectMedia );
        ELSE
            Insert( Path, Drive, 1 );  (* Add directory to disc drive name *)
        END;
        Copy(Name,FName);
        ConcatS(FName,".");
        ConcatLS(FName,Ext);
        GetMessage(ModuleNumber + 7, s);                     (* "schedule" *)  (* 18-Jul-88 LAA *)
        IF ( RequestFileFind( Path, FName, s, Path1, Name ) ) THEN
            SetString(s,".");
            i := Search(Name,s,1);
            IF (i > 0) THEN
                Procustes(Name,i-1); (* Trim off any extension *)
            END;
            Copy(Name,RetrievalName);
            Copy(Path1,ProjectMedia);
            RetrieveDammit := TRUE;  (* Go get it! *)
        END;
    END;

END AbsorbParameterLine;





PROCEDURE CheckVirtualMemory():BOOLEAN;
VAR
    S       : ARRAY [0..255] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    ok := (GetExtStatus() = ExtGood);

    IF (NOT ok) THEN
        GetMessage(ModuleNumber+6,S);       (* Low on flexstor! *)
        Error(S); 
    END;

    RETURN ok;

END CheckVirtualMemory; 



PROCEDURE InitVidType();
VAR 
(*<DOS*)
    AnswerIndex : VidType.AQuestionType;
(*DOS>*)
(*<OS2
    AnswerIndex : AQuestionType;
OS2>*)
    Copyright           : ARRAY[0..51] OF CHAR; 
BEGIN 
        (* Set defaults for all answers. *) 
(*<DOS*)
    FOR AnswerIndex := MIN(VidType.AQuestionType) TO MAX(VidType.AQuestionType) DO
        VidType.Answers[AnswerIndex] := 1;
    END;
(*DOS>*)
(*<OS2
    FOR AnswerIndex := MIN(AQuestionType) TO MAX(AQuestionType) DO
        Answers[AnswerIndex] := 1;
    END;
OS2>*)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

END InitVidType;


(* *************************************
(* 2-Nov-90 RSC I don't this is needed anymore, as long as there
                is a calendar in the config file.
*)

       (* Initialize the calendar to no working time.   The actual calendar 
          will be read in from the configuration file.  However, it may 
          not have as many years, so we must put something into each
          YearTable.  I put one day into each month just so that nothing is 
          exactly zero, in case that would trigger some unpleasant boundary 
          condition.
       *) 

PROCEDURE InitCalendar(); 
CONST 
    firstyear       = 1983; 
    DefaultStdWeek  =   5;
    DefaultStdDay   =   8;
    Mon             =   Sun + 1;
    Fri             =   Mon + 4;
VAR 
    i                   : CARDINAL;
    DayOfTheWeek,
    Year,Month,Day      : CARDINAL; 
BEGIN 

    TimeTable.StdWeek    := DefaultStdWeek;   (* KKC Aug 22, 1989 *) 
    TimeTable.StdDayTics := DefaultStdDay * SMUPH;   (* KKC Aug 22, 1989 *)
    TimeTable.FirstYear  := firstyear; 

    FOR i := Mon TO Fri DO
        TimeTable.WeekTable[i].WeekMap := ADaySet{31..64};
    END;
    TimeTable.WeekTable[Sun].WeekMap := ADaySet{};
    TimeTable.WeekTable[Sat].WeekMap := ADaySet{};

    FOR i := 1 TO YearsOnFile DO
        Year := firstyear + i - 1;
        FOR Month := Jan TO Dec DO
            TimeTable.YearTable[i,Month].YearMap := AMonthSet{0..31};
        END;
    END;

    RecomputeTable(TimeTable, FALSE); 

END InitCalendar; 
********************************************** *)


(*<OS2
PROCEDURE TLStartBind();
OS2>*)

  (* MAIN OF TLStart *) 

BEGIN 
    ProgramState   := TLStartInit;
    RetrieveDammit := FALSE;

    InitVidType();

    InitTimeLineModules();  (* RSC 16-May-89; These don't need the config file. *)
(*    InitCalendar(); *)

        (* Initialize some global variables. *) 
    Author[0] := 0C;
    FullScheduleName[0] := 0C;

    EnableLights(FALSE);
        (* Read the TimeLine configuration file. *) 
    SetString(s,ConfigFileName);
    ProgramState   := TLStartRunning; 
    IF (NOT GetCnfg(s,{FSIG,FNAMES,FENV,FCAL,FPREF, 
                       FPLOT,FCODES,FFONTS, ALIEN,
                       FPRINT, FFILTER,
                       FMEMO, FLAYOUT, FNLAYOUT, FCOLUMNS})) THEN 
        GetMessage(ModuleNumber+22,s);   (*  "Configuration file could not be read."  *)
        Error(s); 
        InitializationOK := FALSE;
        Terminate(Warning); 
    END;

    InitializeTimeFormat;       (* Again, after we have read foreign upshift table. *)


    SetAsOfDate();              (* 3/20/87 EGK *) 
    SetClock(); 

    AbsorbParameterLine();
    EnableLights(TRUE); 
    ShowLights(ActiveLightRegion);

(*<DOS*)
    InitializationOK := (InitializationOK AND CheckVirtualMemory());
(*DOS>*)

    IF (InitializationOK) THEN
        AddToMenuTree();
        ProgramState := TLStartDone;

        GetTLGSValuesInfo();                                          (* 01-Jun-89 LAA *) 
    END;

    GanttChart^.Methods^.ChangeHeight( GanttChart, GanttWStart+2, GanttWEnd );  (* 13-Dec-89 *) 

    ConflictProc();             (* 20-Feb-91 RSC  *)
(*<OS2
END TLStartBind;
OS2>*)

END TLStart.




