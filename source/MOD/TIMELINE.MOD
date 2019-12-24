    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

MODULE TimeLine;

    (***************************************************************)
    (*                                                             *)
    (*   TimeLine                                                  *)
    (*                                                             *)
    (***************************************************************)

    (* 
        MODIFICATION HISTORY

        28-May-87 LAA   Called InitializeChanger from here.
        16-Jun-87 LAA   Don't take a rug when creating the GanttChart.
        29-Jun-87 AJL   Add notices.
        23-Jul-87 AJL   Intercept several hot keys.
        04-Aug-87 LAA   Call InitializeChartForms for named layouts.  Moved
                        InitializeChart to Chart module.
        19-Aug-87 AJL   Moved the hot keys to TLMAIN.
        28-Sep-87 RSC   Added the initial logo display here from TlInit.
        27-Oct-87 LAA   Imported NetLayouts so it'll be in the root.
        31-Oct-87 RSC   Imported ParmLine so Andrew can get it and so we can
                        get the overlays path initially.
         6-Nov-87 RSC   change bottom logo line away from REVERSE.
                        improve documentation on EXIT CODEs.
        10-Nov-87 LAA   Called InitializeNetLayouts from here.
        20-Jan-88 LAA   Imported NetStatic for network view.
        22-Jan-88 RSC   Added import of transfer, made files be xxxx3.xxx
        29-Jan-88 RSC   Added call to DisplayScheduleLight from Schedule,
                        in order to allocate the 100 bytes early on.
        04-Feb-88 EGK   If DOS version is 3.1 or greater, ignore the PATH=
                        command line parameter and use the directory where
                        the EXE file was found as the overlays path.
        16-Feb-88 AJL   Explicitly call LoadMenuTree. 
        22-Feb-88 RSC   Move startup params into GaGa.
        27-Feb-88 RSC   Allow nuts with 2 floppy systems to run if their
                        path=a:;b:
        16-Aug-88 RSC   Import Registry and Kluges so they are in the root.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
        10-Jan-89 RSC   Changed FormRead to FormStatic.
        24-Jan-89 RSC   Added an init of the default page supply.
         2-Feb-89 RSC   Unload locked overlays upon exit of the program.
                        This allows their termination procs to run.
         3-Feb-89 RSC   Added ExportLinkage to the root.  Changed parms to
                        LoadMenu.  Changed file names to xxxx4 from xxxx3.
        07-May-89 WKH   Unlock any locked schedules on normal termination.
        09-May-89 WKH   IMPORT moudle to transfer data to and from network view
        17-May-89 RSC   Ajust the constant that reads the startup screen.
        19-May-89 LAA   Made Roger's change to fix the logo, and imported
                        IlsaStatic so the TLG/S device setup will work.
        25-May-89 AJL   Import VidType to make it static.
        30-May-89 RSC   1) Check for a CTRL-BREAK before running most of
                           the program.  Situation is:  Type TIMELINE.
                           "Oops!  I didn't want to do that!".  CTRL-BREAK.
                           Time Line still comes up.
                        2) Clean up the overlay path rules:

                        OVERLAY PATH:

                            If there is a PATH= statement, then
                                If the path is "A:;B:", or
                                   this is a programmer version, then
                                    allow the full path statement.
                                Otherwise, take only the FIRST path
                                    entry in the string.
                            Else
                                If this is DOS 3.1+ and there is a load path,
                                    use that for the overlay path.
                                    Secret back door for programmers:  DK:; is
                                    automaticly prepended.
                                Otherwise, use "DK:".
                            End
         7-Jun-89 RSC   1) There are two new paths exported from "FileAux".
                           They are "EXEPath" and "TextPath".  Fill them
                           in.
                        2) Fill in the OverlayPath with the appropriate new
                           path.

                        NEW OVERLAY RULES:  (boy things change fast here!)

                            Get the load path.
                            No load path?  Must be DOS 3.0 or less....
                                If there is a PATH= statement, then
                                    Assume that the first path segment in the
                                    PATH statement is the load path.
                                Else
                                    The load path must be DK:.
                            The TextPath is <LoadPath>TEXT\
                            The OverlaysPath is <LoadPath>PROGRAMS\
                                (And for now, the text path is appended
                                 onto the overlay path).
                            If this is a programmer version, then
                                If a PATH= statement is present, prepend the
                                    PATH statement into both TextPath and
                                    OverlayPath.
                                Else
                                    Prepend a "DK:;" into the two paths.
                                NOTE THAT THE LOADPATH IS NOT CHANGED!
         6-Jun-89 EGK   Call new InitUndo procedure.
        10-Jun-89 WKH   Added support for varible screen rows
        13-Jun-89 WKH   Fix logo for compressed display mode. Init compressed
                        display mode.
        20-Jun-89 RSC   Use new Registry module for "programmer mode"
                        detection.
        05-Jul-89 WKH   Removed IMPORT of Registry to force the DEF to be
                        imported.  We now explicitly import types and procs
                        from Registry so there is no longer any need for this.
                        Also, UnLock UserName.
        19-Jul-89 RSC   Support for new message file stuff and new RunMenu.
        04-Aug-89 WKH   First edits for OS/2 support.
        09-Aug-89 KKC   Add copyright message.
        01-Sep-89 LAA   Removed the import of PlotStatic, because we no longer
                        support the old SoftTrak TLG.
        21-Sep-89 AJL   Import EmsStorage so that the vectors are static.    
        01-Nov-89 EGK   Added new InitNetSave procedure.
        15-Nov-89 EGK   Changed SetupPaths to look for an EXEPath like
                        "C:\\" and remove the second backslash if present.
                        This was a problem when running with the RTD with
                        TIMELINE.EXE in the root directory of a drive.
        30-Nov-89 RSC   Ajust the length tests in SetupPaths so that Andrew's
                        test of "PATH=<huge string>" works.  This only stops
                        DOS 2.0 customers with paths > about 68 chars.
        02-Apr-90 MWP   Include week number support.
         9-Apr-90 RSC   Timei/TimeFormat changes.
        31-Aug-90 PFG   Import data for storing user-modified column headings.
        21-Jan-91 RSC   Removed fiscal calendar.
        30-Jan-91 RSC   Added Exit2Dos import.
         6-Feb-91 RSC   Added a call to Message() to force Dialog to validate
                        serial numbers and register for notices early.
        12-Feb-91 RSC   Import RealFormat to hold it in the root.
        14-Feb-91 RSC   Call assignment's init proc.
         5-Mar-91 RSC   Import SubStub.
         2-Apr-91 TGS   Look for TLFORMS5 & TLPHRAS5. This is "5.0" now...

    *)



(*<DOS*)
IMPORT DebugPMD;  (* IF PRESENT, MUST BE FIRST *)
(*DOS>*)

(*<OS2
IMPORT MEDInit;
OS2>*)

(*<OS2
FROM Bind IMPORT BindInit;
OS2>*)


(*<DOS*)
IMPORT MemCheck;  (* THEN THIS NEXT *)
(*DOS>*)


(*<DOS*)
FROM PreSwap        IMPORT
    (* PROC *)          PrepareForMemSwap;
(*DOS>*)

FROM Allocs         IMPORT
    (* PROC *)          InitializeAllocs;

FROM Assignments    IMPORT
    (* PROC *)          InitializeAssignments;

FROM Chainer        IMPORT
    (* PROC *)          Chain;

FROM Changer        IMPORT
    (* PROC *)          InitializeChanger;

FROM Chart          IMPORT
    (* VAR *)           GanttChart,
    (* PROC *)          InitializeChart;

FROM ChartForms     IMPORT
    (* VAR *)           CurrentChartFormat,
    (* PROC *)          InitializeChartForms;

FROM ColData        IMPORT
    (* VAR  *)          ColumnTable;

FROM Dialog         IMPORT
    (* PROC *)          Burp, Error, FatalError, Message;

FROM Directory      IMPORT
    (* PROC *)          DOSVersion, GetPathEntry;

FROM Edges          IMPORT
    (* PROC *)          InitializeEdges;

FROM Endings        IMPORT
    (* VAR *)           CompletionCode,
    (* PROC *)          EndWithErrorLevel;

(*<OS2
FROM ErrHandler     IMPORT 
    (* TYPE *)          HardErrNotifyFlags, HardErrNotifySet,
    (* PROC *)          DosError;
OS2>*)

FROM FileAux        IMPORT
    (* VARS *)          OverlayPath, EXEPath, TextPath,
    (* PROC *)          InitializeFiles, TerminateFiles;

FROM FileOpen       IMPORT
    (* PROC *)          RequestFileFind;

FROM Filters        IMPORT
    (* PROC *)          ResetFilters;

FROM FlexStor       IMPORT
    (* PROC *)          InitExtStorage;

FROM FormStatic     IMPORT
    (* PROC *)          SetFormFileName;

FROM GanttOutlines  IMPORT
    (* PROC *)          CreateGanttOutline;

FROM GaGa           IMPORT
    (* PROC *)          GetGaGaMessage, ConcatGaGaMessage;

FROM Kbio           IMPORT
                        KbioInit, KbioTerminate, PushCode, KeyPress,
                        ascreeny, avidmode, vidctrl,
                        PutString, maxcol, maxrow, ascreenx,
                        SetCursorType, ACursorType, VersionString,
                        BreakRequested, ClearBreak, CheckForCompressedMode,
                        PrepareVideoForExit;

FROM Layout         IMPORT
    (* CONST *)         GanttWStart, GanttWEnd, MaxRow;

FROM LoadPath       IMPORT
    (* PROC *)          GetLoadDir;

FROM LStrings       IMPORT
    (* PROC *)          SetString, CtoS, ConcatLS, Remove, Fill, Search,
                        LengthOf, Copy, Procustes, SubStr, TStringToLString,
                        Insert, ConcatS, Upshift, StringsEqual, SetLengthOf;

FROM MsgFile        IMPORT
    (* PROC *)          OpenMsgFile, GetMessage;

FROM NetLayouts     IMPORT
    (* PROC *)          InitializeNetLayouts, TerminateNetLayouts;

FROM NetSave        IMPORT
    (* PROC *)          InitNetSave;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          SendNotices;

FROM Overlays       IMPORT
    (* PROC *)          RemoveLockedOverlays;

FROM Paranoia       IMPORT
    (* TYPES *)         AProgramState,
    (* VARS  *)         ProgramState, InitializationOK;

FROM ParmLine       IMPORT
    (* PROCS *)         GetOption;

FROM Registry       IMPORT
    (* CONST *)         QProductType, TLProgrammer,
    (* TYPE *)          ARegistryDataRecord,
    (* PROC *)          GetRegistryInfo, UnLockUser;

FROM RunMenu        IMPORT
    (* PROC *)          LoadMenuTree;

FROM Schedule       IMPORT
    (* TYPE *)          AScheduleLockClass,
    (* PROC *)          DisplayScheduleLight, UnLockSchedule;

FROM SYSTEM         IMPORT
    (* PROC *)          ADR;

FROM TimeFormat     IMPORT
    (* PROC *)          InitializeTimeFormat;

FROM Undo           IMPORT
    (* PROC *)          InitUndo;

FROM Video          IMPORT
    (* PROC *)          PutStringWithAttribute;


    (* Make sure that these guys are linked in. *)

IMPORT Exit2Dos;                (* 30-Jan-91 RSC  *)

IMPORT HistStat;

IMPORT Kluges;    (* RSC 8/16/88 *)

IMPORT PrintStatic;

IMPORT Transfer;  (* RSC 1/22/88 *)

IMPORT RealFormat;              (* 12-Feb-91 RSC  *)

IMPORT ExportLinkage;  (* RSC 3-Feb-89 *)

IMPORT NetworkData;  (* WKH 5/9/89 *)

IMPORT IlsaStatic;   (* LAA 19-May-89 *)

IMPORT VidType;      (* AJL 25-May-89 *)

(*<DOS*)
IMPORT EmsStorage;   (* AJL 21-Sep-89 *)
(*DOS>*)

IMPORT WeekNumberInfo;                                              (* 2-Apr-90 MWP *)

IMPORT SubStub;                 (* 5-Mar-91 RSC  *)
 

CONST
    DefaultFormFileName = "TLFORMS5.DAT";
    PhraseFileName      = "TLPHRAS5.DAT";
    ModuleNumber        = 4500; (* For GetMessage *)
    LogoModuleNumber    = 5100; (* LOGO.MOD's module number. *)


(*<OS2
VAR
    err                     : CARDINAL;
OS2>*)







 (* Put up the initial logo from the phrases file.  RSC 9/28/87

    Note that here KbioInit() has been called, but we do not have the
    tlwhat file open, we are in clean mode, and a whole lot of things 
    have not yet been initialized!
 *)
PROCEDURE DoInitialLogo();

CONST Offset = 9;  (* First Message number for logo - 1 *)

VAR
    i         : CARDINAL;
    VideoMode : BITSET;
    Logo      : ARRAY [0..maxcol+1] OF CHAR;
    Copyright : ARRAY [0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Copyright[0] := 0C;         (* 6-Feb-91 RSC  *)
    Message(Copyright);         (* 6-Feb-91 RSC  *)
    Fill( Logo, " ", maxcol+1 );
    PutStringWithAttribute( Logo, 0, 0, BITSET( 07H ) );
    FOR i := 1 TO 24 DO  (* 13-Jun-89 WKH *)
        GetMessage(LogoModuleNumber+Offset+i, Logo);
        Procustes( Logo, maxcol+1 );
        VideoMode  := BITSET( 07H );   (* White on Black *)
        IF (i = 3) OR (i = 4) THEN
            VideoMode  := BITSET( 70H ); (* Black on White *)
        END;
        PutStringWithAttribute( Logo, 0, i, VideoMode  );
    END;

    Fill( Logo, " ", maxcol+1 );
    FOR i := 25 TO maxrow DO    (* RSC 20-Jun-89 *)
        PutStringWithAttribute( Logo, 0, i, BITSET( 07H ) );
    END;

END DoInitialLogo;




PROCEDURE SetupPaths();
VAR
    RegistryDataRecord  : ARegistryDataRecord;
    UserName,
    ProductName         : ARRAY [0..99] OF CHAR;
    OverlayOption,
    s                   : ARRAY [0..255] OF CHAR;   (* 30-Nov-89 RSC from 99 *)
    ProgrammerMode,
    ok                  : BOOLEAN;
    len                 : CARDINAL;

BEGIN

   (* See if they want to override the overlay search path.  This
      affects all file opens, incl. help text, phrases, etc.
   *)

    GetGaGaMessage( ModuleNumber + 2, s );  (* "PATH" *)
    GetOption(s,ok,OverlayOption);
    Upshift( OverlayOption );
    ok := ok AND (LengthOf(OverlayOption) > 0)
             AND (LengthOf(OverlayOption) < HIGH(EXEPath)); (* 30-Nov-89 RSC *)

    (* RSC 20-Jun-89 *)

    SetLengthOf( UserName, 0 );
    SetLengthOf( ProductName, 0 );
    ProgrammerMode := (GetRegistryInfo( UserName,
                                        ProductName,
                                        QProductType,
                                        RegistryDataRecord ) AND
                      (RegistryDataRecord.CardinalValue = TLProgrammer));

    (* RSC 7-Jun-89

        1) Get the load path.
        2) No load path?  (Most likely DOS 3.0 or 2.x)
            If a PATH= is specified, then
                Use it.
            Else
                Assume DK:
            End
        3) Build the text and overlays path from the load path.
    *)
    GetLoadDir( EXEPath );
    TStringToLString( EXEPath, EXEPath );
    len := LengthOf(EXEPath);

    IF (len >= 4) THEN
            (*  Sometimes (such as when the RTD is running), EXEPath will
                contain two trailing backslashes.  We need to remove
                the second one so that subsequent file lookups will work.  *)
        IF (EXEPath[len] = "\") AND (EXEPath[len-1] = "\") THEN
            SetLengthOf (EXEPath, len-1);
        END;
    ELSIF (len = 0) THEN
        IF (NOT ok) OR
           (NOT GetPathEntry(OverlayOption, 0, EXEPath)) THEN
            SetString( EXEPath, "DK:" );
        END;
    END;

    Copy( EXEPath, TextPath );
    ConcatGaGaMessage( ModuleNumber+3, TextPath );  (* "TEXT\" *)

    Copy( EXEPath, OverlayPath );
    ConcatGaGaMessage( ModuleNumber+4, OverlayPath ); (* "PROGRAMS\" *)

    (* Temporary, until everyone uses "TextPath" .... *)
    ConcatS( OverlayPath, ";" );
    ConcatLS(OverlayPath, TextPath );

    IF (ProgrammerMode) THEN
        IF (ok) THEN
            Copy( OverlayOption, s );
            ConcatS( s, ";" );
        ELSE
            SetString(s, "DK:;" );
        END;

        (* 30-Nov-89 RSC Added this as per AJL's 11-30 EMail: *)

        len := LengthOf(s);
        IF ((len + LengthOf(TextPath)) <= HIGH(TextPath)) THEN
            Insert( TextPath,    s, 1 );
        END;
        IF ((len + LengthOf(OverlayPath)) <= HIGH(OverlayPath)) THEN
            Insert( OverlayPath, s, 1 );
        END;
    END;

END SetupPaths;





PROCEDURE SetupTimeLine() : BOOLEAN;
VAR
    s              : ARRAY [0..99] OF CHAR;
BEGIN
   (* RSC 1/28/88 - At this point the schedule name is nil (0C), but even so
                    we want to try to display the schedule light.  This causes
                    space to be allocated (about 100 bytes), that, if not
                    allocated here, would be allocated at the END of loading
                    a schedule, causing the heap to have a 16KB chunk in high
                    memory that cannot be freed up with a schedule erase.
    *)
    CheckForCompressedMode();  (* WKH 13-Jun-89 *)
    DisplayScheduleLight();

    KbioInit;

    SetCursorType( NoCursor ); (* RSC 11/5/87 *)

    SetupPaths();

    SetString(s,DefaultFormFileName);
    SetFormFileName(s);               (* Set the form file name *)
    SetString(s,PhraseFileName);

    RETURN (InitializeFiles() AND OpenMsgFile(s));

END SetupTimeLine;




BEGIN
    CompletionCode := 1; (* Unless reset, exit with non-zero (error) code. *)
                         (* Moved here so it REALLY gets initialized by RSC 30-May-89. *)

(*<OS2
    err := DosError(HardErrNotifySet{});  (* 4-Aug-89 WKH Disable OS/2 error handler *)
OS2>*)

(*<DOS*)
    PrepareForMemSwap();
(*DOS>*)

    ProgramState := RootInit;
    IF (InitExtStorage( 100 )) THEN END;  (* Get Default Page Supply working. RSC 1/24/89 *)


    IF ((InitializationOK) AND
        (NOT BreakRequested())  AND                     (* 30-May-89 RSC *)
        (SetupTimeLine())) THEN
        DoInitialLogo();
        InitializeEdges();                              (* RSC 16-Jun-89 *)
        InitializeTimeFormat();
        InitializeAllocs();
        InitializeChanger();                                      (* 28-May-87 LAA *)
        ResetFilters;
        InitializeChartForms();                                   (* 04-Aug-87 LAA *)

        InitializeChart();

        InitializeNetLayouts();                                   (* 10-Nov-87 LAA *)
        InitUndo();                                               (* 06-Jun-89 EGK *)
        InitNetSave();                              (* 11/1/89 EGK *)
        InitializeAssignments();

        SendNotices(ProgramStart,AfterActing,NIL);

        IF (InitializationOK) THEN
            LoadMenuTree();   (* Load the CHAINER overlay list. RSC 24-Jul-89 *)
            ProgramState := RootRunning;
(*<OS2
    	    BindInit ();
OS2>*)
            Chain();
        END;

        RemoveLockedOverlays();             (* RSC 2/1/89 *)
        UnLockSchedule(DualLock);           (* WKH 5/7/89 *)       
        UnLockUser();                       (* WKH 7/5/89 *)

        SendNotices(ProgramEnd,BeforeActing,NIL);
        TerminateFiles;
    END;

    ClearBreak();
    KbioTerminate;
    TerminateNetLayouts();                                        (* 10-Nov-87 LAA *)
    PrepareVideoForExit();                                        (* 12-Jun-89 WKH *)

        (* The completion code is used to communicate with a
           controlling DOS program.

             0 - EXIT Time Line and go to a back end product (like PlotLine)
             1 - EXIT Time Line normally.
            >1 - real error occured.
        *)

    IF (CompletionCode <> 0) THEN
        EndWithErrorLevel(CompletionCode);
    END;

END TimeLine.
