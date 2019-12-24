MODULE TLLink;

    (*V1=DEBUG*)


    (* TLLink

       Put up a dialog form which allows the user to define a link from
       a task in the current schedule to a task in another schedule, or
       the entirety of another schedule.

       For description of the contents of the text which defines the link,
       see the notes at the end of the module.

       Much of the behavior of the link is controlled by some phrases in
       the phrase file beginning at #20650.  These control what overlay
       will be called to perform the link, which overlay allows the user
       to select WBS numbers, and whether resource linking is allowed.

    *)

    (* MODIFICATION HISTORY:

         Oct 29, 1987 - Moved here from CHANGER.
         20-Jan-88 LAA  Made this an installable overlay.
          2-Jan-89 RSC  Added references to StringsEqual() rather than Compare().
          6-Jan-89 RSC  Moved "AnOverlayProc" reference.
          8-Feb-89 EGK  Completely rewrote this to put up its own form
                        instead of using GetInputFile.  Added 5 new
                        fields for specific task links.
          4-Apr-89 EGK  always refresh the directory field on
                        CheckFieldChange.
          7-Apr-89 EGK  Removed the "billable effort" field.
         28-Apr-89 EGK  Check for form changes before actually setting
                        "Changed" to TRUE.
         07-May-89 WKH  Don't allow display of 0 length files.
         08-May-89 WKH  Changed VerifyFileExists to use StartFileNodeLookup
                        instead of Lookup.  Also, disable link if link file-
                        name is blank.
         09-May-89 WKH  Make sure a change is registered for F10 from the form.
         31-May-89 EGK  Reject F2 from fields other than PATH or NAME.
         12-Jun-89 EGK  Changed length of WBS to 30.
         09-Aug-89 KKC - Add copyright message.
         21-Aug-89 EGK   Changed vertical max and min of scrolling file list.
         14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
                         Eliminated the duplicated code in FormValueToText
                         (honestly, I don't know how it got there) by
                         remembering whether the file name is blank and
                         waiting until the holder info is saved before
                         blasting the task's link text.
         17-Sep-90 RSC   Import the file extension rather than hardcoding it.
          3-Nov-90 AJL   Use the Dialog.Error procedure for message #6.
         16-Nov-90 AJL  -Add documentation for the link text format.
                        -Allow rollup of resources even when doing a task
                         link.  Formerly, only a link to a full shedule allowed
                         resource rollup.
                        -For full schedule rollup, set the WBS code line to blank.
                        -Changed the rules of when the Resources link field is
                         protectd.  We now protect it, and set it to "No" when
                         the result is to be a milestone.
          30-Jan-91 AJL -Pressing F2 brings up a list of all the files in the 
                         source directory, since we don't know in advance what 
                         extension, or file name, is wanted.
           4-Feb-91 AJL -Allow the F2 key from the WBS field to call an 
                         overlay to help the user select a WBS number.
                        -Optionally allow or disallow linking of resources.
    *)

FROM Allocs                 IMPORT
    (* CONST *)                 WBSLen;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, WarningBox, FatalError;

FROM Direct411              IMPORT
    (* PROC *)                  GiveDirectoryAssistance, AlwaysApprove,
                                DontAllowZero;

FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
        (* TYPES *)             AFileNameRecord,
                                ASetOfFileNameParts, AFileNamePart,
                                AFileAttribute, AFileAttributeSet,
        (* PROCS *)             StartFileNodeLookup, ContinueFileNodeLookup,
                                ExtractDeviceName, NumberOfDiskettes,
                                ExtractFileNameParts, DiskFreeSpace,
                                FileLookupStart, ExpandPath,
                                NormalizeFileName,
                                DirectoryIsReachable;

FROM FileAux                IMPORT FileResultMeans, PrepareForIO, CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  Lookup, Close;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, ACheckReason, AForm,
                                ACursorAttribute,
    (* PROC *)                  DoForm, NullCheckProc, ShowValue,
                                HighlightField,
                                SetFieldProtection, SetFieldHidden;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  LocateHeldItem, HoldThis;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey;

FROM Layout                 IMPORT
    (* VAR *)                   MenuStart, MenuEnd, GanttWEnd, GanttWStart;

FROM Links           IMPORT
        (* CONST *)     LinkOverlayNameLine, LinkFileTypeLine, LinkPathLine,
                        LinkActionForm,
        (* TYPES *)     AGetDisplayableLinkProc, ALinkInterface;

FROM LStrings       IMPORT
        (* PROCS *)     ConcatS, ConcatLS, Copy, LengthOf, LJust, TrimRear,
                        StringsEqual, SetLengthOf, SetString, Fill, TrimFront,
                        Procustes, Remove, Search, Upshift, Compare, 
                        CtoS, StoC,
                        LStringToTString, SubStr, InsertWithOverflow;

FROM MsgFile        IMPORT 
        (* PROCS *)     GetMessage, DisplayMessage;

FROM Overlays       IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROCS *)     OverlayContext, ImAnInstallableOverlay,
                        CallOverlayWithContext;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM Schedule       IMPORT
    (* VAR *)           ProjectMedia, CurrentFileExtension;

FROM Searcher     IMPORT
    (* PROC *)           PatternSearch;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, Available;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, SIZE;

FROM Text           IMPORT
        (* PROCS *)     DiscardText, AssignText, TextExists, SizeOfText, 
                        LineExists, CopyLine, AText, Compress, CreateText,
                        AssignLine;

FROM Words        IMPORT
    (* PROC *)             ParseBal;



(*<DEBUG
FROM Boxes IMPORT ABoxAttribute, ABoxType;
FROM Edits IMPORT EditText;
DEBUG>*)




CONST
    ModuleNumber = 20600;

    WrongLinkVersion = ModuleNumber + 7; (* "Wrong LINK product installed." *)

    Dot                     = ".";

    FormID              = 60;

    LinkFlagsLine       = 3;  (* Choice field settings on link form *)
    LinkWBSLine         = 4;

    PATH    = 0;    (* Drive and directory                      *)
    NAME    = 1;    (* File and extension                       *)
    LTYP    = 2;    (* Link type (0=schedule, 1=task)           *)
    LWBS    = 3;    (* Link WBS code                            *)
    LDAT    = 4;    (* Copy (Start date + duration, end date)   *)
    RCOP    = 5;    (* Copy resources? (No, Yes)                *)

    ResCopyFlag     = 1;    (* TRUE iff should copy resources *)
    EffortFlag      = 2;    (* TRUE iff roll up all efforts   *)
    LinkDateFlag    = 3;    (* TRUE iff end date only         *)

    HeldLinkFlagsName   = "LinkFlags";
    HeldLinkFlagsClass  = 512;          (* Catalog number of "Spleen and Ideal" *)

    GotoCode            = CARDINAL(BITSET{15});

TYPE
    ASettingsPtr            = POINTER TO ASettingsRecord;

    ASettingsRecord         = RECORD
                                OverlayName     : ARRAY [0..20] OF CHAR;
                                FileType        : ARRAY [0..5]  OF CHAR;
                                Path            : ARRAY [0..80] OF CHAR;
                                WBSCode         : ARRAY [0..WBSLen] OF CHAR;
                                Flags           : ARRAY [0..20] OF CHAR;
                              END;

    ASource                 = (TimeLine, OnTarget);    

    ASourceTypeRecord       = RECORD
                                  ExtTemplate   : ARRAY [0..MaximumExtensionLength] OF CHAR;
                                  ViewerName,
                                  LinkerName    : ARRAY [0..MaximumFileNameLength] OF CHAR;
                                  Source        : ASource;
                                  ResourcesAllowed : BOOLEAN;
                              END;


VAR
    OverlayID               : AnOverlayID;

    SourceTypes             : ARRAY [1..9] OF ASourceTypeRecord;
    MaxSources              : CARDINAL;

    FlagChar                : ARRAY BOOLEAN OF CHAR;
    GlobalChangeMade        : BOOLEAN;




PROCEDURE PrepareSources();
VAR
    SourceTypeS       : ARRAY [0..5] OF CHAR;
    TempS             : ARRAY [0..255] OF CHAR;
    ExtensionIndex, i, j : CARDINAL;
BEGIN
    MaxSources := 0;
    LOOP
        GetMessage(ModuleNumber+50+MaxSources,TempS);
           (* (<Extension>)(<Viewer>)(<Linker>)(<SourceType>)(<Resources>) *)
        IF (LengthOf(TempS)=0) THEN
            EXIT;
        END;
        INC(MaxSources);
        i := 1;
        WITH SourceTypes[MaxSources] DO
            ParseBal(TempS,i,ExtTemplate);
            ParseBal(TempS,i,ViewerName);
            ParseBal(TempS,i,LinkerName);
                (* SourceType *)
            ParseBal(TempS,i,SourceTypeS);
            j := 1;
            Source := VAL(ASource,StoC(SourceTypeS,j));
                (* Resources allowed? *)
            ParseBal(TempS,i,SourceTypeS);
            j := 1;
            ResourcesAllowed := VAL(BOOLEAN,StoC(SourceTypeS,j));
        END;
    END;
END PrepareSources;
 



  (* Analyze Extension For Linker Name -

        Given an extension, figure out which linker ought to be called.
  *)
PROCEDURE AnalyzeExtension( VAR Extension  : ARRAY OF CHAR;
                            VAR Index      : CARDINAL
                          ) : BOOLEAN;
BEGIN
    Upshift(   Extension );
    Procustes( Extension, 3 );

        (* Get a list of extension templates and the overlay to read them. *)
        (* Compare each template against the actual extension.  If they match, *)
        (* use that linker. *)

    Index := 1;
    WHILE (Index <= MaxSources) DO
        WITH SourceTypes[Index] DO
            IF (PatternSearch(Extension,ExtTemplate)=1) THEN
                RETURN TRUE;
            END;
        END;
        INC(Index);
    END;

    RETURN FALSE;
END AnalyzeExtension;






PROCEDURE LinkFlagSet (  VAR s        : ARRAY OF CHAR;
                             FlagNo   : CARDINAL      ) : BOOLEAN;
BEGIN
    RETURN (LengthOf(s) >= FlagNo) AND (s[FlagNo] = FlagChar[TRUE]);
END LinkFlagSet;



PROCEDURE SetLinkFlag ( VAR s           : ARRAY OF CHAR;
                            CardValue   : CARDINAL;
                            FlagNo      : CARDINAL      );
BEGIN
    s[FlagNo] := FlagChar[VAL(BOOLEAN, CardValue)];
END SetLinkFlag;



PROCEDURE GetHeldLine   (    LineNo     : CARDINAL;
                         VAR s          : ARRAY OF CHAR ) : BOOLEAN;
VAR
    Name            : ARRAY [0..20] OF CHAR;
    Class           : CARDINAL;
    Category        : AHoldTypeSet;
    Size            : CARDINAL;
    SettingsPtr     : ASettingsPtr;
    ok              : BOOLEAN;

BEGIN
    SetString (Name, HeldLinkFlagsName);
    Class := HeldLinkFlagsClass;
    ok := (LocateHeldItem (Name, Class, Category, SettingsPtr, Size));
    IF (ok) THEN
        CASE LineNo OF
            LinkOverlayNameLine :
                Copy (SettingsPtr^.OverlayName, s);
        |   LinkFileTypeLine :
                Copy (SettingsPtr^.FileType, s);
        |   LinkPathLine :
                Copy (SettingsPtr^.Path, s);
        |   LinkWBSLine :
                Copy (SettingsPtr^.WBSCode, s);
        |   LinkFlagsLine :
                Copy (SettingsPtr^.Flags, s);
        ELSE
            FatalError();
        END;
    END;

    RETURN ok;
END GetHeldLine;




PROCEDURE GetLine  (    Text        : AText;
                        LineNo      : CARDINAL;
                    VAR s           : ARRAY OF CHAR );
VAR
    s2          : ARRAY [0..80] OF CHAR;

BEGIN
    IF (TextExists (Text)) THEN
        CopyLine (Text, LineNo, s);
        IF (LineNo = LinkOverlayNameLine) THEN
            SetString (s2, "TLROLLEM");
            IF (StringsEqual (s, s2)) THEN
                SetString (s, "TLLNKSUM");
            END;
        END;
    ELSIF (NOT GetHeldLine (LineNo, s)) THEN
        CASE LineNo OF
            LinkOverlayNameLine :
                SetString (s, "TLLNKSUM");
        |   LinkFileTypeLine :
                SetString (s, "0");     (* Time Line *)
        |   LinkPathLine :
                Copy (ProjectMedia, s);
                ConcatS (s, "*");
                ConcatLS(s, CurrentFileExtension);  (* 17-Sep-90 RSC *)
        |   LinkWBSLine :
                SetLengthOf (s, 0);
        |   LinkFlagsLine :
                SetString (s, "100");
        ELSE
            FatalError();
        END;
    END;
END GetLine;




PROCEDURE TextToFormValue (     Text        : AText;
                            VAR FormValue   : ARRAY OF AFieldValue  );
VAR
    s, s2           : ARRAY [0..80] OF CHAR;
    Drive, Path     : ARRAY [0..80] OF CHAR;
    Name, Ext       : ARRAY [0..20] OF CHAR;

BEGIN
    GetLine(Text, LinkPathLine, s);
    ExtractFileNameParts( s, Drive, Path, Name, Ext );

    ConcatLS (Drive, Path);
    Copy (Drive, FormValue[PATH].CharValue^);

    ConcatS ( Name, "." );
    ConcatLS( Name, Ext );
    Copy (Name, FormValue[NAME].CharValue^);

    GetLine (Text, LinkWBSLine, s);
    Copy(s, FormValue[LWBS].CharValue^);

        (* If the WBS field is blank, then we have a schedule link. *)
    FormValue[LTYP].CardValue := ORD(LengthOf(s) <> 0);

    GetLine (Text, LinkFlagsLine, s);
    FormValue[RCOP].CardValue := ORD(LinkFlagSet (s, ResCopyFlag));
    FormValue[LDAT].CardValue := ORD(LinkFlagSet (s, LinkDateFlag));
END TextToFormValue;





PROCEDURE FormValueToText ( VAR FormValue       : ARRAY OF AFieldValue;
                            VAR Text            : AText;
                            VAR Changed         : BOOLEAN               );
VAR
    s               : ARRAY [0..80] OF CHAR;
    Name            : ARRAY [0..20] OF CHAR;
    Class           : CARDINAL;
    Category        : AHoldTypeSet;
    Size            : CARDINAL;
    Settings        : ASettingsRecord;
    SettingsPtr     : ASettingsPtr;
    Index           : CARDINAL;
    Source          : ASource;
    LinkerName      : ARRAY [0..MaximumFileNameLength] OF CHAR;
    SaveIt          : BOOLEAN;

BEGIN
    TrimRear(FormValue[NAME].CharValue^);

    SaveIt := (LengthOf(FormValue[NAME].CharValue^) > 0);       (* 9/14/89 EGK *)

    IF (NOT TextExists (Text)) THEN
        Text := CreateText();
    END;

            (* Check the directory and file name *)

    Copy (FormValue[PATH].CharValue^, s);
    IF (SaveIt) THEN
        ConcatLS (s, FormValue[NAME].CharValue^);
    ELSE
        ConcatS (s, "*");
        ConcatLS(s, CurrentFileExtension ); (* 17-Sep-90 RSC *)
    END;

    IF NOT AssignLine(s, LinkPathLine, Text) THEN END;
    Copy (s, Settings.Path);


           (* What kind of file is it?  What is the overlay that 
              links that type of file? *)

    IF NOT ValidFileName( FormValue[NAME].CharValue^, Index ) THEN
        RETURN;
    END;


    Copy(SourceTypes[Index].LinkerName, LinkerName);
    Source := SourceTypes[Index].Source;


            (* Store the file type code.  0 = Time Line, 1 = On Target *)

    CtoS(ORD(Source),s);   
    IF (NOT AssignLine (s, LinkFileTypeLine, Text)) THEN END;
    Copy (s, Settings.FileType);

            (* Check the link type *)

    IF (NOT AssignLine (LinkerName, LinkOverlayNameLine, Text)) THEN END;
    Copy (LinkerName, Settings.OverlayName);

            (* Check the WBS *)

    IF (FormValue[LTYP].CardValue = 0) THEN
        SetLengthOf(s,0);
    ELSE
        Copy (FormValue[LWBS].CharValue^, s);
    END;
    IF (NOT AssignLine (s, LinkWBSLine, Text)) THEN END;
    Copy (s, Settings.WBSCode);

    Fill (s, " ", 10);
    SetLinkFlag (s, FormValue[RCOP].CardValue, ResCopyFlag);
    SetLinkFlag (s, FormValue[LDAT].CardValue, LinkDateFlag);
    IF (NOT AssignLine (s, LinkFlagsLine, Text)) THEN END;
    Copy (s, Settings.Flags);

        (* Save the flag settings, if possible *)

    Size := SIZE(Settings);
    IF (Available (Size)) THEN
        NEW (SettingsPtr);
        SettingsPtr^ := Settings;
        SetString (Name, HeldLinkFlagsName);
        Class := HeldLinkFlagsClass;
        HoldThis (Name, Class,
                  AHoldTypeSet{HeapNoOwner,HoldInConfig,HoldInDataFile},    (* 9/14/89 EGK *)
                  SettingsPtr, Size);
    END;

    Compress(Text);

        (*  All that work for nothing?  Well, at least we saved the
            settings in holder.  Unfortunately, the user blanked out
            the file name, so we have to zap the link text.
        *)

    IF (NOT SaveIt) THEN            (* 9/14/89 EGK *)
        IF (TextExists (Text)) THEN (* 5/8/89 WKH *)
            DiscardText(Text);
        END;
    END;

    Changed := GlobalChangeMade;

END FormValueToText;




  (* Edit the file name entered on a form. *)

PROCEDURE EditFileName( VAR Name           : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i : CARDINAL;
    Title,
    s : ARRAY [0..99] OF CHAR;
BEGIN
    TrimFront(Name);
    TrimRear(Name);
    SetString(s,Dot);
    i := Search( Name, s, 1 );
    IF (i > 0) THEN  (* extension? *)
        IF (i = 1)                      OR   (* Dot first (or only) byte? *)
           (Search( Name, s, i+1 ) > 0) THEN (* Another dot? *)
            DisplayMessage (ModuleNumber+2);   (* "Illegal filename" *)
            RETURN FALSE;
        END;
    END;
    SetString(s,"*");
    i := Search( Name, s, 1 );
    SetString(s,"?");
    IF (i <> 0) OR (Search( Name, s, 1 ) <> 0) THEN
        GetMessage (ModuleNumber+3, s);   (* "wildcards not allowed" *)
        SetLengthOf (Title, 0);
        WarningBox (s, Title, NoHelp);
        RETURN FALSE;
    END;
    RETURN TRUE;
END EditFileName;



  (* Edit the file name entered on a form. *)

PROCEDURE ValidFileName( VAR Name           : ARRAY OF CHAR;
                         VAR Index          : CARDINAL
                        ) : BOOLEAN;
VAR
    Drive     : ARRAY [0..3] OF CHAR;
    S         : ARRAY [0..255] OF CHAR;
    FileName  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    Extension : ARRAY [0..MaximumExtensionLength] OF CHAR;
    ok        : BOOLEAN;
BEGIN
    ExtractFileNameParts( Name, Drive, S, FileName, Extension );
    ok := AnalyzeExtension(Extension,Index);
    IF (NOT ok) THEN
        GetMessage (ModuleNumber+9, S);    
        ConcatLS(S,Extension);
        SetLengthOf (Drive, 0);
        WarningBox (S, Drive, NoHelp);
    END;
    RETURN ok;
END ValidFileName;





 (* Verify File Exists - Insure that the file name passed exists. *)

PROCEDURE VerifyFileExists( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;
VAR 
    FileNameRecord : AFileNameRecord;
    s              : ARRAY [0..199] OF CHAR;
    Title          : ARRAY [0..29]  OF CHAR;
BEGIN
    FileNameRecord.Attributes := AFileAttributeSet{ReadOnlyAttribute,
                                                   ArchiveAttribute};
    IF (NOT StartFileNodeLookup(FileName, FileNameRecord)) THEN
        GetMessage (ModuleNumber+4, s);    (* "No file by that name" *)
        SetLengthOf (Title, 0);
        WarningBox (s, Title, NoHelp);
        RETURN FALSE;
    END;
    RETURN TRUE;
END VerifyFileExists;



PROCEDURE FilterValidFiles( FileNameRecord : AFileNameRecord ) : BOOLEAN;
VAR
    Index           : CARDINAL; 
BEGIN
    IF (FileNameRecord.Size =  0) THEN
        RETURN FALSE;
    ELSE
        RETURN AnalyzeExtension( FileNameRecord.Extension,
                                 Index );
    END;
END FilterValidFiles;





PROCEDURE CheckLinkForm (    Form            : AForm;
                             FieldNo         : AFieldNo;
                         VAR FormValue       : ARRAY OF AFieldValue;
                             CheckReason     : ACheckReason;
                         VAR Code            : CARDINAL ):BOOLEAN;
CONST
    TopY    = 3;
    BottomY = 14;

VAR
    Protect     : BOOLEAN;
    CodeIn      : CARDINAL;
    Changed,
    ok          : BOOLEAN;
    i           : CARDINAL;
    s           : ARRAY [0..255] OF CHAR;
    s2          : ARRAY [0..99] OF CHAR;
    FileRecord  : AFileNameRecord;
    OldExt,
    OldFileName,
    Title       : ARRAY [0..39]  OF CHAR;
    TempExt     : ARRAY [0..3] OF CHAR;
    Index       : CARDINAL;


    PROCEDURE Squish( VAR s : ARRAY OF CHAR );
    VAR
        i,
        Loop : CARDINAL;
    BEGIN
        i := 0;
        FOR Loop := 1 TO ORD(s[0]) DO
            IF (s[Loop] <> " ") THEN
                INC(i);
                IF (i <> Loop)  THEN
                    s[i] := s[Loop];
                END;
            END;
        END;
        SetLengthOf(s,i);
        ShowValue( Form, FieldNo, FormValue );
    END Squish;


    PROCEDURE ChooseResourceProtection();
    VAR
        Protect : BOOLEAN;
        Index   : CARDINAL;
    BEGIN
        Protect := (FormValue[LDAT].CardValue = 1);     (* Zero-Length? *)
        IF (NOT Protect) THEN
            IF ValidFileName( FormValue[NAME].CharValue^, Index) THEN
                Protect := (NOT SourceTypes[Index].ResourcesAllowed);
            END;
        END;

        IF (Protect) THEN
            FormValue[RCOP].CardValue := 0;    (* No *)
        END;
        SetFieldProtection (Form,RCOP,FormValue,Protect);
        ShowValue(Form,RCOP,FormValue);
    END ChooseResourceProtection;

        (* ViewSourceFile -- Display the contents of the source
                             file.  Return with an identifying WBS
                             number in the WBS field. 
                             *)

    PROCEDURE ViewSourceFile();
    VAR
        Index   : CARDINAL;
        Viewer  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    BEGIN
        IF ValidFileName( FormValue[NAME].CharValue^, Index) THEN
            Copy(SourceTypes[Index].ViewerName,Viewer);
            IF (LengthOf(Viewer) > 0) THEN
                IF CallOverlayWithContext(Viewer,ADR(FormValue)) THEN
                    ShowValue(Form,LWBS,FormValue);
                END;
            ELSE
                Burp();
            END;
        END;
    END ViewSourceFile;

BEGIN

    CodeIn := Code;
    Code := 0;  (* For safety on return. *)

    IF (CheckReason = CheckFieldChange) THEN        (* 4/28/89 EGK *)
        GlobalChangeMade := TRUE;
    ELSIF (CheckReason = CheckFieldKey) THEN
        IF (NOT (FieldNo IN {PATH,NAME,LWBS})) THEN
            Burp();             (* 5/31/89 EGK *)
            RETURN FALSE;
        END;
    END;

    CASE FieldNo OF

        LTYP :
                (* Link type (0=schedule, 1=task)           *)
                (* If we are linking to the whole schedule, disable
                   and hide the WBS field. *)
            Protect := (FormValue[LTYP].CardValue = 0);
            SetFieldProtection (Form,LWBS,FormValue,Protect);
            SetFieldHidden (Form,LWBS,FormValue,Protect);

    |   LDAT :
                (* Copy (0: Start date + duration, 1: end date)   *)
                (* If we are going to turn the linked task into a 
                   milestone, set the Copy Resources field to "No" and
                   protect it. *)
            ChooseResourceProtection();

    |   LWBS :
            WITH FormValue[LWBS] DO
                LJust (CharValue^);
                TrimRear (CharValue^);
                IF (CheckReason = CheckFieldKey) THEN
                    ViewSourceFile();
                ELSIF (CheckReason = CheckFormExit) THEN
                    IF (LengthOf(CharValue^) = 0) AND
                       (FormValue[LTYP].CardValue = 1) THEN
                        GetMessage (ModuleNumber+1, s);        (* "WBS empty" *)
                        SetLengthOf (Title, 0);
                        WarningBox (s, Title, NoHelp);
                        Code := GotoCode + FieldNo; (* Go to this field *)
                        RETURN FALSE;
                    END;
                END;
            END;

    |   PATH, NAME :
            Squish (FormValue[FieldNo].CharValue^);
            IF (CheckReason = CheckFieldEntry) THEN
                RETURN TRUE;
            ELSIF (CheckReason = CheckFieldKey) THEN
                HighlightField(Form,FormValue,FieldNo, CursorResting );
                WITH FormValue[PATH] DO
                    SetLengthOf(OldFileName, 0);
                    ExpandPath( CharValue^, OldFileName, s );
                    IF (NOT DirectoryIsReachable(s)) THEN  (* Current dir invalid? *)
                        ExpandPath( OldFileName, OldFileName, s );
                        IF (NOT DirectoryIsReachable(s)) THEN  (* DK: bad? *)
                            SetString( s, "A:\" );
                        END;
                    END;
                    WITH FileRecord DO
                        ExtractFileNameParts( FormValue[NAME].CharValue^, s2, s2,
                                              OldFileName,
                                              OldExt );
                            (* Look up all similar files.  Because of our 
                               ability to link to TL files with different
                               extensions, plus On Target files, we look for
                               "*.*"--all files.  *)
                        SetString(FileName,"*");                  (* AJL 1/30/91 *)
                        SetString(Extension,"*");                  (* AJL 1/30/91 *)
                        ConcatS (s, "*.*");
                    END;
                    GetMessage( ModuleNumber + 5, Title );  (* "~ Directory of ~" *)
                    IF (NOT GiveDirectoryAssistance( TopY, BottomY, Title,
                                                     s,
                                                     OldFileName, (* CURSOR NAME *)
                                                     FilterValidFiles)) THEN
                        HighlightField(Form,FormValue,FieldNo, CursorOff );
                        RETURN FALSE;
                    END;
                    WITH FileRecord DO
                        ExtractFileNameParts (s, Device, Path, FileName, Extension);
                        TrimRear( FileName  );
                        TrimRear( Extension );
                        SetString( s2, "*" );
                        IF (LengthOf( FileName ) = 0)  OR
                           (StringsEqual( s2, FileName )) THEN
                            Copy( OldFileName, FileName );
                        END;
                        IF (LengthOf( Extension ) = 0) THEN
                            Copy( OldExt, Extension );
                        END;
                        Copy( Device, CharValue^ );
                        ConcatLS( CharValue^, Path );
                        Copy( FileName, FormValue[NAME].CharValue^ );
                        IF (LengthOf(Extension) > 0) THEN
                            ConcatS( FormValue[NAME].CharValue^, Dot );
                        END;
                        ConcatLS( FormValue[NAME].CharValue^, Extension );
                        ShowValue( Form, NAME, FormValue );
                        ShowValue( Form, PATH, FormValue );
                    END;
                END;
                HighlightField(Form,FormValue,FieldNo, CursorOff );
                RETURN TRUE;
            ELSIF (CheckReason = CheckFormExit) AND (FieldNo = PATH) THEN
                WITH FormValue[PATH] DO
                    TrimRear( CharValue^ );
                    TrimRear( FormValue[NAME].CharValue^ );
                    IF (LengthOf( CharValue^ ) = 0) THEN (* 5/8/89 WKH *)
                        RETURN FALSE;
                    END;
                    SetLengthOf( OldFileName, 0 );
                    ExpandPath(CharValue^, OldFileName, s );
                END;
                ConcatLS( s, FormValue[NAME].CharValue^ );
                (* Return true if wildcards allowed or if file is there. *)
            
                WITH FormValue[NAME] DO
                    TrimFront(CharValue^);
                    TrimRear(CharValue^);

                    IF (LengthOf(CharValue^) > 0) THEN (* 5/8/89 WKH *)
                        ok := (EditFileName( CharValue^ ));
                        ok := (ok AND (VerifyFileExists(s)));
                        IF (NOT ok) THEN
                            Code := GotoCode + NAME;
                        END;
                        IF ok THEN GlobalChangeMade := TRUE; END;(* 5/9/89 WKH *)
                        RETURN ok;
                    ELSE
                        GlobalChangeMade := TRUE; (* 5/9/89 WKH *)
                        RETURN TRUE; (* 5/8/89 WKH *)
                    END;
                END;
            ELSIF (CheckReason <> CheckFieldChange) THEN
                RETURN TRUE;
            END;

            WITH FormValue[FieldNo] DO
                TrimFront( CharValue^ );
                TrimRear(  CharValue^ );
                IF (LengthOf(CharValue^) > 0) THEN
                    IF (FieldNo = PATH) THEN
                        ExpandPath( CharValue^, Title, s );
                        Copy (s, CharValue^);           (* 4/4/89 EGK *)
                        SetLengthOf(Title,0);
                           (* If the user entered a bad directory, warn them. *)
                        IF (NOT DirectoryIsReachable(s)) THEN
                            Copy(s,s2);
                            GetMessage(ModuleNumber+6,s);
                            ConcatLS(s,s2);
                            Error(s);
                            RETURN FALSE;
                        END;
                    ELSE
                        IF (NOT EditFileName( CharValue^ )) OR 
                           (NOT ValidFileName( CharValue^, Index)) THEN
                            Code := GotoCode + NAME;
                            RETURN FALSE;
                        END;
                    END;
                END;
            END;
            ChooseResourceProtection();
            ShowValue( Form, FieldNo, FormValue );
            RETURN TRUE;
    ELSE
    END;

    RETURN TRUE;
END CheckLinkForm;



   (* Do The Task Link Form - This is invoked from Changer.  You are on the
      Advanced Task Form and the customer has pressed F2 from the Link field.

      Our job is to fill in the summarizes field.

   *)
PROCEDURE DoTaskLinkForm( VAR LinkInterface : ALinkInterface );

VAR 
    OldName,
    s, s1, s2        : ARRAY [0..99] OF CHAR;
    Ext,
    Name             : ARRAY [0..13] OF CHAR;
    Path             : ARRAY [0..99] OF CHAR;
    WBS              : ARRAY [0..WBSLen] OF CHAR;
    OverlayName      : ARRAY [0..13] OF CHAR;
    FormValue        : ARRAY [PATH..RCOP] OF AFieldValue;

BEGIN
    WITH LinkInterface DO

        FormValue[PATH].CharValue := ADR(Path);
        FormValue[NAME].CharValue := ADR(Name);
        FormValue[LWBS].CharValue := ADR(WBS);
    
        TextToFormValue (LinkText, FormValue);
        GlobalChangeMade := FALSE;

        IF (DoForm (0, GanttWEnd, maxcol, maxrow-1,
                    FormID, TRUE, FormValue, CheckLinkForm) <> CancelKey) THEN
            FormValueToText (FormValue, LinkText, ChangesMade);
        END;
        CompletedOK := TRUE;
    END;
END DoTaskLinkForm;









 (* Process A Link Request - handle one of the requests made to us.

        Preconditions  - We have been invoked via InvokeTLLink().
                         Context area contains a valid Link Interface.
                         Caller is compatible with this version of the
                         linking overlay.
        Postconditions - The request, if valid, is processed.
 *)
PROCEDURE ProcessALinkRequest();
VAR
    LinkInterfaceP : POINTER TO ALinkInterface;
    Copyright      : ARRAY[0..50] OF CHAR;

    PROCEDURE BadVersion(); (* Here to reduce overall stack space. *)
    VAR
        Msg        : ARRAY [0..255] OF CHAR;
    BEGIN
        GetMessage( WrongLinkVersion, Msg );
        Error(Msg);
    END BadVersion;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    PrepareSources();

    LinkInterfaceP := OverlayContext();
    IF (LinkInterfaceP <> NIL) THEN
        CASE LinkInterfaceP^.DesiredAction OF
            LinkActionForm  : DoTaskLinkForm( LinkInterfaceP^ );
        ELSE
            BadVersion();
        END;
    END;

END ProcessALinkRequest;




BEGIN
    FlagChar[TRUE] := "1";
    FlagChar[FALSE] := "0";

    OverlayID := ImAnInstallableOverlay(ProcessALinkRequest, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    ProcessALinkRequest();

END TLLink.



The links supported by Time Line version 4.0 and following are described
in a text record associated with each linked task.

All linked tasks, regardless of the linking method, have their first 
three lines identical.  The lines contain:

0:  LinkOverlayNameLine   (* Which overlay handles this *)
1:  LinkFileTypeLine      (* Version number/file type.  Time Line is 0 *)
                          (*                            On Target is 1 *)
2:  LinkPathLine          (* Dev:Path\Name.Ext of other schedule. *)

The Link Path Name Line is the line we display on the screen as the
'Link to' column.  If a new scheme comes in and wants something different,
Line 3 still must be preserved such that Time Line users without the
add-in product can still at least DISPLAY the link, if not actually use it.

Initial SPIKE notes:

  > As I just said, Line 2 must ALWAYS be displayable as a column for
    backwards compatability.

  > If the LinkOverlayNameLine file does not exist, we reject any try at
    rolling up the task.  See the TLLink module for that.

Each linking overlay can define the remaining lines.  The following
are the ones used by the TLLNKSUM overlay, which links tasks to other 
Time Line schedules:

3:  LinkFlagsLine         (* Choice field settings on link form *)

The flags in line 3 are
    ResCopyFlag     = 1;    (* TRUE iff should copy resources *)
    EffortFlag      = 2;    (* TRUE iff roll up all efforts   *)
    LinkDateFlag    = 3;    (* TRUE iff end date only         *)

4:  LinkWBSLine           (* WBS code (15 chars max).  *)
    If blank, it means to rollup the entire schedule.


