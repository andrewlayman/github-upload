MODULE TLXCNFG;

(*  =========================================================================
    Last Edit : January 21, 1991 6:20PM by 
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Save config file.

    MODIFICATION HISTORY:
    
        4-Jan-90 AJL    Save mouse speeds.
       15-Aug-90 RSC    Updated file name to tlcnfg45
       27-Aug-90 PFG    Add user-defined column names.
       23-Oct-90 TGS    Save to CONFIG IS <path>.
       26-Oct-90 PFG    Move SaveColumnNames into SaveCommon so column names
                        can be saved in schedule files as well as config.
       10-Jan-91 AJL    Write new format text lines with new type codes.
       21-Jan-91 RSC    Remove fiscal calendars.
        2-Apr-91 TGS    4.5 --> 5.0 changes.
       17-Jun-91 AJL    Added some additional documentation.
    =========================================================================
*)


FROM Boxes         IMPORT TransparentShadow;

FROM Codes         IMPORT ASetOfCodes;

FROM CodeSets      IMPORT CommandCodes, MenuCodeSet, FormsCodeSet,
                           ChartCodeSet;

FROM Dialog        IMPORT Error, NotYetImplemented;

FROM Directory     IMPORT StartFileNodeLookup, AFileNameRecord,
                            AFileAttributeSet, AFileAttribute,
                            ExpandPath, ExtractDeviceName;

FROM FileSystem   IMPORT  File, Lookup, Response, Close,
                            SetAttribute,
                            WriteChar, Create, Rename, Delete;

IMPORT FileSystem;        (* For Archive Attribute *)

FROM FileAux      IMPORT FileResultMeans, FlushBuffer,
                            PrepareForIO, CheckIO, DisplayFileError;

FROM ForeignSubfiles IMPORT
    (* TYPE *)      AFileType,
    (* PROC *)      WriteAllForeignSubfiles;

FROM Gantt        IMPORT  ChartFont, SummaryFont, BaselineDetailFont,
                            BaselineSummaryFont;

FROM Holder       IMPORT LocateHeldItem, AHoldType, AHoldTypeSet;

FROM IlsaStatic   IMPORT
    (* TYPE *)           ATLGSConfigRecord, ATLGSConfigRecordPtr,
    (* PROC *)           TLGSConfigRecordExists, TLGSConfigRecord;

FROM Kbio         IMPORT soundon, CleanFlag, BlinkFlag,
                            Tone, vidctrl,
                            VersionString, TamperedFlag, maxcol;

FROM LStrings     IMPORT SetString, ConcatLS, ConcatS, CtoS, StoC,
                            SubStr, LStringToTString, TStringToLString,
                            Fill, Compare, Upshift, TrimRear, Copy,
                            Procustes, LengthOf, Search, Remove, SetLengthOf;

IMPORT Mouse;

FROM MsgFile      IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM ParmLine     IMPORT  GetOption;

FROM PrintStatic  IMPORT  PrintDiskFileName, PrintCB, APrinterStyle,
                            PrintXLAT, TranslateOverlay, ReportSettings,
                            ReportHeaderTextIn, OutputDeviceName,
                            AControlStyle, OutputDiskName,
                            GlobalTimeOut;

FROM RealFormat   IMPORT
                            DefaultAmountFormat,
                            DefaultCurrencyFormat;

FROM RecordIO     IMPORT  WriteRecord, WriteString;

FROM Registry     IMPORT  UserName;

FROM SaveCommon    IMPORT f, SaveCommonData, WriteText;

FROM Schedule   IMPORT ProjectText, ProjectStartDate,
                        Author, FullScheduleName, ZeroIsLowestPriority,
                        ConfigSaved, ScheduleSaved, ProjectMedia,
                        RetrievalName, ProjectName, Loaded,
                        InstalledFlag;

FROM Subfiles     IMPORT  StartFileOutput, EndFileOutput,
                            StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM     IMPORT TSIZE, SIZE, ADR, ADDRESS;

FROM TimeFormat   IMPORT
                            DefaultDateAndTimeFormat, DefaultDateFormat,
                            DefaultTimeFormat;

FROM Text       IMPORT
    (* TYPE *)      AText,
    (* PROC *)      LineExists, CopyLine, TextExists;

IMPORT VidType;





CONST
    ModuleNumber           = 21300;   (* For GetMessage. *)


CONST
     ProjectType           = 1;
     EnvironmentType       = 2;
     PrintFileType         = 3;
     SummaryType           = 4;
     ResourceType          = 5;
     TaskType              = 6;
     EdgeType              = 8;
     CalendarType          = 9;
     BugsType              = 10;
     SignatureType         = 11;
     PrinterTableType      = 12;
     FileNamesType         = 13;
     VideoType             = 14;
     PreferencesType       = 15;
     CodeSetsType          = 16;
     FontsType             = 17;
     PlotsType             = 18; (* RSC 8/14/87 from PlotGo *)
     FiltersType           = 19;
     HeldItemsType         = 20;
     MemosType             = 21;
     LayoutsType           = 23;
     NetLayoutsType        = 24;
     TLGSDeviceType        = 25;                                  (* 21-May-89 LAA *)
     ColumnNamesType       = 29;    (* 10-Sep-90 PFG  *)

     ResourceFileVersionNumber   = 1;
     TaskFileVersionNumber       = 9;
     EdgeFileVersionNumber       = 6;
     EnvironmentVersionNumber    = 17;
     CalendarFileVersionNumber   = 1;
     BugsFileVersionNumber       = 1;


     ProjectFileVersionNumber=  12;
     MAXCARDINAL             = 0FFFFH;
     MAXDATE                 = MAXCARDINAL;
     MaxSubfiles             = 25;                                (* 21-May-89 LAA *)

     DefaultConfigFileName   = "TLCNFG5.DAT";  (* 2-Apr-91 TGS *)        
     MaxWidth       = 255;              (* KKC  May 4, 1989 *)







PROCEDURE SavePrinterTable();
VAR
    Line        :       ARRAY[0..MaxWidth] OF CHAR;
    i           :       CARDINAL;
BEGIN
    StartSubfileOutput(f,PrinterTableType,1);

        (* The basic settings for which output device is selected, baud
           rates, ports, etc. *)
    WriteRecord ( f, 6, ADR(PrintCB), SIZE(PrintCB) );             (* 3-Aug-89 MWP *)
        (* Translation string to convert characters for printers which do
           not use the same mapping as the video display. *)
    WriteRecord(f,2,ADR(PrintXLAT[OutToPrinter]),SIZE(PrintXLAT[OutToPrinter]));
        (* Translation string to convert characters for word processors which
           do not use the same mapping as the video display. *)
    WriteRecord(f,3,ADR(PrintXLAT[OutToDisk]),SIZE(PrintXLAT[OutToDisk]));
        (* Name of an overlay, such as TLGLUE, which will be called to do
           further transformation on the output to disk file. *)
    WriteString(f,4,TranslateOverlay);
        (* Storage space used by the reports.  Divided into various sections
           with different parts used by different reports. *)
    WriteRecord(f,5,ADR(ReportSettings),SIZE(ReportSettings));
        (*  *)
    WriteString(f,7,OutputDeviceName);                            (* 3-Aug-89 MWP *)
    WriteString(f,8,OutputDiskName);                              (* 7-Sep-89 MWP *)
        (*  *)
    WriteRecord ( f, 9, ADR(GlobalTimeOut), SIZE(GlobalTimeOut) );(* 27-Sep-89 MWP *)

        (* Text of the report header.  This appears at the top of reports,
           and can contain keywords which get instantiated curing report output. *)

    WriteText(f, ReportHeaderTextIn, 110);                        (* 22-May-89 LAA *)

        (* Text (multiple lines of arrays of characters) containing
           the control strings which are sent to the printer to 
           initiate and terminate printing. *)

    WriteText ( f, PrintCB.ControlStrings[PrinterNormal].Init, 111);
    WriteText ( f, PrintCB.ControlStrings[PrinterNormal].Terminate, 112);
    WriteText ( f, PrintCB.ControlStrings[PrinterCompressed].Init, 113);
    WriteText ( f, PrintCB.ControlStrings[PrinterCompressed].Terminate, 114);
    WriteText ( f, PrintCB.ControlStrings[WPNormal].Init, 115);
    WriteText ( f, PrintCB.ControlStrings[WPNormal].Terminate, 116);
    WriteText ( f, PrintCB.ControlStrings[NoControls].Init, 117);
    WriteText ( f, PrintCB.ControlStrings[NoControls].Terminate, 118);

    EndSubfileOutput(f,PrinterTableType);
END SavePrinterTable;









PROCEDURE SaveTLGSDeviceSetup();

VAR
    DeviceSetup             : ATLGSConfigRecordPtr;

BEGIN                       (* SaveTLGSDeviceSetup *)

    IF (NOT TLGSConfigRecordExists()) THEN                        (* 01-Jun-89 LAA *)
        RETURN;
    END;

    DeviceSetup := TLGSConfigRecord();

    StartSubfileOutput(f,TLGSDeviceType,1);
    WriteRecord(f, 2, DeviceSetup, TSIZE(ATLGSConfigRecord));
    WriteText(f, DeviceSetup^.ConfigDescription, 102);
    EndSubfileOutput(f,TLGSDeviceType);

END SaveTLGSDeviceSetup;





PROCEDURE SaveVideo();
BEGIN
    StartSubfileOutput(f,VideoType,1);
    WriteRecord(f,1,ADR(vidctrl),SIZE(vidctrl));
    WriteRecord(f,2,ADR(TransparentShadow),SIZE(TransparentShadow));
    WriteRecord(f,3,ADR(VidType.VideoConfiguration),SIZE(VidType.VideoConfiguration));
    WriteRecord(f,4,ADR(VidType.Answers),SIZE(VidType.Answers));
    WriteRecord(f,5,ADR(CleanFlag),SIZE(CleanFlag));              (* 13-Sep-89 LAA *)
    WriteRecord(f,6,ADR(BlinkFlag),SIZE(BlinkFlag));
    EndSubfileOutput(f,VideoType);
END SaveVideo;





PROCEDURE SavePreferences();
BEGIN
    StartSubfileOutput(f,PreferencesType,1);
    WriteRecord(f,1,ADR(soundon),      SIZE(soundon)      );
    WriteRecord(f,2,ADR(InstalledFlag),SIZE(InstalledFlag));  (* Ever been seen? *)
    WriteRecord(f, 3, ADR(DefaultDateAndTimeFormat),              (* 09-Nov-88 LAA *)
                SIZE(DefaultDateAndTimeFormat));
    WriteRecord(f, 4, ADR(DefaultDateFormat),
                SIZE(DefaultDateFormat));
    WriteRecord(f, 5, ADR(DefaultTimeFormat),
                SIZE(DefaultTimeFormat));
    WriteRecord(f, 6, ADR(DefaultAmountFormat),
                SIZE(DefaultAmountFormat));
    WriteRecord(f, 7, ADR(DefaultCurrencyFormat),
                SIZE(DefaultCurrencyFormat));
    WriteRecord(f, 8, ADR(UserName),
                SIZE(UserName));
    WriteRecord(f, 9, ADR(Mouse.RepeatRate),
                SIZE(Mouse.RepeatRate));
    WriteRecord(f, 10, ADR(Mouse.DoubleClickRate),
                SIZE(Mouse.DoubleClickRate));
    EndSubfileOutput(f,PreferencesType);
END SavePreferences;





PROCEDURE SaveCodeSets();
    PROCEDURE SaveCodeSet (VAR CodeSet:ASetOfCodes);
    BEGIN
        WriteRecord(f,1,ADR(CodeSet),SIZE(CodeSet));
    END SaveCodeSet;
BEGIN
    StartSubfileOutput(f,CodeSetsType,1);
    SaveCodeSet(CommandCodes);
    SaveCodeSet(MenuCodeSet);
    SaveCodeSet(FormsCodeSet);
    SaveCodeSet(ChartCodeSet);
    EndSubfileOutput(f,CodeSetsType);
END SaveCodeSets;










PROCEDURE SaveFonts();
CONST
    FontsName       = "FontsInFile";
    FontsClass      = 1709;         (* Subfile and record number *)
VAR
    Where       : ADDRESS;
    Size        : CARDINAL;
    FontsInFile : BOOLEAN;
    s           : ARRAY [0..20] OF CHAR;
    Category    : AHoldTypeSet;

BEGIN
    SetString (s, FontsName);
    FontsInFile := LocateHeldItem (s, FontsClass, Category, Where, Size);

    StartSubfileOutput(f,FontsType,1);
    WriteRecord(f,2,ADR(ChartFont),SIZE(ChartFont));
    WriteRecord(f,3,ADR(SummaryFont),SIZE(SummaryFont));
    WriteRecord(f,4,ADR(BaselineDetailFont),SIZE(BaselineDetailFont));
    WriteRecord(f,5,ADR(BaselineSummaryFont),SIZE(BaselineSummaryFont));
    WriteRecord(f,9,ADR(FontsInFile),SIZE(FontsInFile));
    EndSubfileOutput(f,FontsType);
END SaveFonts;





PROCEDURE SaveCnfg () : BOOLEAN;
VAR
    i           : CARDINAL;
    oldfile     : File;
    res         : Response;
    OptionName  : ARRAY [0..9]  OF CHAR;
    DefaultPath, Device
                : ARRAY [0..3]  OF CHAR;
    ParmLinePath, FileName   
                : ARRAY [0..80] OF CHAR;
    tempstring  : ARRAY [0..80] OF CHAR;
    TempPhrase  : ARRAY [0..1] OF CHAR;
    FileNameRecord  : AFileNameRecord;
    ok          : BOOLEAN;
    Copyright   : ARRAY[0..50] OF CHAR;

    PROCEDURE FileComplaint(VAR name:ARRAY OF CHAR);
    VAR
       s, s2 : ARRAY [0..80] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber+1,s);   (*  "Config file "  *)
        ConcatLS(s,name);
        DisplayFileError(f,s);
    END FileComplaint;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    DisplayMessage( ModuleNumber + 2 ); (* "Saving options" *)

    (* 23-Oct-90 TGS *)
    SetString(DefaultPath, "DK:");
    SetString(OptionName, "CONFIG");
    GetOption(OptionName, ok, ParmLinePath);
    IF (ok) THEN
        ExpandPath(ParmLinePath, DefaultPath, tempstring);
    ELSE
        ExpandPath(DefaultPath, DefaultPath, tempstring);
    END;

    Copy(tempstring, FileName);
    ConcatS (FileName, DefaultConfigFileName);

    LStringToTString(FileName,tempstring);

    TempPhrase[0] := 0C;

    ExtractDeviceName(FileName, Device, i);
    LStringToTString(Device, Device);

    Create(f, Device); (* 24-Oct-90 TGS use Device instead of "DK:" as before *)

    IF (CheckIO(f) <> done) THEN
        FileComplaint(TempPhrase);
        RETURN FALSE;
    END;

    StartFileOutput(f,MaxSubfiles);

    i := 0;
    LOOP
        ok := (CheckIO(f) = done);
        IF (NOT ok) THEN EXIT; END;
        CASE i OF
            0:  SaveCommonData( HoldInConfig, 0 );
          | 1:  SavePrinterTable();
          | 2:  SaveVideo();
          | 3:  SaveCodeSets();
          | 4:  SaveFonts();
          | 5:  SavePreferences();
          | 6:  SaveTLGSDeviceSetup();
          | 7:  WriteAllForeignSubfiles( f, ConfigFile );   (* RSC 1-Sep-89 *)
          ELSE
                EXIT;
        END;
        INC(i);
    END;

    EndFileOutput(f);


    FlushBuffer(f);
    IF (CheckIO(f) <> done) THEN
        FileComplaint(TempPhrase);
        Close(f);
        RETURN FALSE;
    END;

    (* RSC 10/27/88: Do a DIR rather than a Lookup, to fool Novell Networks. *)

    FileNameRecord.Attributes := AFileAttributeSet{ReadOnlyAttribute}; (* RSC 12/7/88 *)
    IF (StartFileNodeLookup( FileName, FileNameRecord )) THEN
        PrepareForIO( oldfile );
        Delete( tempstring, oldfile );
        IF (CheckIO( oldfile ) <> done) THEN
            FileComplaint( FileName );
            Close( f );
            RETURN FALSE;
        END;
    END;


    (* RSC 10/20/88: *)

    PrepareForIO(f);
    Rename(f,tempstring);
    IF (CheckIO(f)= done) THEN
        Close(f);  (* 11/09/88 WKH *)
        SetAttribute( tempstring, FileSystem.ArchiveAttribute, f ); (* RSC 5/22/88 & 12/7/88 *)
        DisplayMessage(ModuleNumber + 3); (* 5/25/89 WKH *)
        RETURN TRUE;
    ELSE
        FileComplaint(FileName);
        DisplayMessage(ModuleNumber + 4);  (* 5/25/89 WKH *)
        RETURN FALSE;
    END;


END SaveCnfg;



BEGIN

    ConfigSaved := SaveCnfg();

END TLXCNFG.


