MODULE TLXPrep;

(*  =========================================================================
    Last Edit : September 17, 1990 11:40AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
        10-Nov-87 RSC    First version from TLXTL3.
        13-Nov-87 RSC    Add extra dialog for non-model save.
        28-Jan-88 LAA    If the save flag from TLWHAT was Y, the logic was
                         wrong.
        29-Jan-88 RSC    1) If directory is missing on file lookup, dialog
                            box said "Name missing from file form".
                         2) iff project name is blank, the 'name this
                            schedule' logic will save the project name.
         3-Feb-88 RSC    1) Re-fix fix # 2, above.  Oops.
        12-Feb-88 RSC    Allow "First Time" flag so we can reset 'InstalledFlag'.
        24-Feb-88 LAA    Turned stack checking on.
        25-Feb-88 RSC    Added more batch file items.
        27-Feb-88 RSC    FORCE the saving of the config file on "Replace".
        16-May-88 EGK    PrimarySave = "?" asks for confirmation before
                         saving current schedule.  (Not really save-dammit)
        21-Dec-88 LAA    Changed imports for Lazlo reorganization.
         2-Jan-89 RSC    Added references to StringsEqual() rather than Compare().
         2-Feb-89 RSC    Changed ParseCallChain to ParseString.
         6-Feb-89 RSC    Change "ExportersOK" to "PackageOK".
                         Added better ability to find the EXE directory for use
                         by ILSA.
        15-Mar-89 EGK    Sets the "SelectiveSave" boolean if the "Xtract"
                         choice is made.
        10-Apr-89 WKH    Disallow saving of a schedule that has been read as read 
                         only.
        13-Apr-89 WKH    Use StartFileNodeLookup to check if new file.
                         Also consider a zero length file as non-existant.
        12-May-89 WKH    Well, if we imported a schedule from a read only 
                         directory, and then tried to save to the same 
                         directory, she a no work.  Test to see if the target
                         directory is writeable to first.
         4-Jun-89 EGK    Put in explicit calls to SendNotices, since
                         Permission no longer sends a BeforeActing for us.
        12-Jun-89 RSC    1) Removed reference to LoadPath.  Replaced with
                            EXEPath.
                         2) Added a dialog when you do a /File,Save and there
                            IS a name on the file form, but is NOT a file
                            already existing.
                         3) When doing a RECALC=xxxx, ignore the question
                            saying "we are about to save the schedule, ok?"
                            because it shouldn't be there.  This message now
                            comes up only when you say PrimarySave="?" and
                            ConfigSave<>"Y".
        29-Jun-89 WKH    Check results of lock more precisely.
        30-Jun-89 WKH    Have ability to save options even when schedule
                         loaded is read-only.
         5-Jul-89 EGK    Modified CheckForOption so that File-Extract blanks
                         out the file name on the save form.
        07-Jul-89 LAA    Display the file name which is about to be saved to,
                         even when it's a new file.
        10-Jul-89 EGK    Fixed my fix of 7/5/89.  Now we just blank out the
                         file name portion, leaving the extension intact.
                         This happens for both "make copy" and "extract".
        11-Jul-89 WKH    Restructured way we handle a Save-Dammit situation
                         so that we will correctly handle the RECALC=xxxx
                         command line flag.  Also make sure we ALWAYS save
                         the options file whenever we save a schedule even
                         if options weren't changed(since the name of the
                         last saved file is itself an option).
        31-Jul-89 KKC    Call ContinuationBox instead of NoYes.
        09-Aug-89 KKC    Add copyright message.
        18-Aug-89 KKC    Make 'Save' instead of 'Cancel' as the default 
                         for saveing new file.
        05-Sep-89 WKH    So, in our attempt to determine if the destination
                         directory is "writable to", we attempt to lock our
                         destination file.  So far so good.  However, if we
                         didn't have a pre-existing lock(as is the case with
                         files on floppy disks), then we would leave a 0 
                         length file on the destination directory.  Well,
                         when the renaming of old files comes along, this 0
                         length file gets "aged" also.  So let's be a little
                         smarter and clean up after ourselves.
        06-Sep-89 WKH    Get rid of 0 length file archive with a file import.
        21-Sep-89 WKH    Hope commenting out this line won't hurt anything.
        26-Sep-89 LAA    Uncommented the line that Wayne had commented out,
                         as it was causing a FatalError when doing /File/Save.
                         The circumstance was: create a new file from scratch,
                         save it (naming it as you go).  Change the directory
                         where it'll be saved, and save again.  Kaboom!!!
                         The error showed up in TLXTL4, because it thought it
                         was doing a replace of an existing file.
                         I worry that we may no longer understand the 
                         difference between ProjectName and ExportName.  I'm
                         not sure I do.
        20-Nov-89 WKH    Re-comment out the above line.  This is so that we
                         can preserve DK: in the users config file.  I have
                         tested the above scenario and it does not cause a
                         FatalError for me.
        01-Dec-89 WKH    OKAY!!  We're gonna fix this bastard for good!!  If
                         we detect that the actual expanded directories have
                         changed, then copy it over.  This way we can preserve
                         DK: and support the File Access form.  If I had it
                         my way, we would re-think and re-work this whole 
                         business of file saving so that it's less convoluted.
        12-Dec-89 RSC    Reconstruct Wayne's changes that were blasted
                         by a bad sector on the disk.  I hate hardware.
        25-May-90 WKH    In some cases, Lookup on TLNEXT wasn't positioning
                         us to the beginning of the file so we were getting
                         duplicate lines, garbage lines, multiple eof's, all
                         kinds of weird stuff.  So rather than try to make
                         the world perfect, I decided to delete TLNEXT before
                         I create it so I'd have a clean slate to work off
                         of.  I'm not even checking if it's successful 
                         because it won't be if the file wasn't there to
                         start with and if it's not successful because the
                         disk is el-flako, then the Lookup success check
                         should catch that!
        17-Sep-90 RSC    Import the file extension rather than hardcoding it.
    =========================================================================
*)

FROM Allocs        IMPORT
        (* VAR *)       TaskTree;

FROM ASCII         IMPORT
        (* CONST *)     EOL;

FROM AsOf          IMPORT
        (* PROC *)      AsOfDate;

FROM ChartControl  IMPORT
        (* TYPE *)      AChartState,
        (* VARS *)      ChartState;

FROM Codes         IMPORT
    (* TYPE *)              ASetOfCodes,
    (* VAR *)               EmptyCodeSet,
    (* PROC *)              SetCodeBits;

FROM Dialog       IMPORT
        (* PROCS *)     NotYetImplemented, Message, Error, FatalError,
                        WarningBox, ADialogOption, ContinuationBox,
                        MultipleChoiceBox;

FROM Direct411    IMPORT
        (* PROC *)      GetOutputFile;

FROM Directory    IMPORT
        (* TYPES *)     AFileNamePart, ASetOfFileNameParts, AFileNameRecord,
                        AFileAttribute, AFileAttributeSet,
        (* PROCS *)     ExtractDeviceName, ExtractFileNameParts,
                        DOSVersion, NormalizeFileName, ExpandPath,
                        DirectoryIsReachable, StartFileNodeLookup;

FROM Dispatcher    IMPORT
        (* PROCS *)     Dispatch;

FROM ExportLinkage IMPORT
        (* VARS *)      ExportMedia, ExportName, NewFile,
                        SaveConfiguration, SaveSchedule,
                        SelectiveSave,
        (* PROCS *)     ParseAFlag;

FROM FileAux      IMPORT
        (* VARS  *)     EXEPath,
        (* PROCS *)     DisplayFileError,
                        PrepareForIO, CheckIO;

FROM FileOpen     IMPORT
        (* PROC *)      RequestFileFind;

FROM FileSystem   IMPORT
        (* TYPES *)     AFileAccessRightSet, AFileAccessRight,
        (* PROCS *)     File, Lookup, Response, Close,
                        WriteChar, Create, Rename, Delete;

FROM Holder       IMPORT
    (* TYPE *)          AHoldTypeSet, AHoldType,
    (* PROC *)          LocateHeldItem;

FROM Kbio         IMPORT
        (* VAR *)       VersionString;

FROM Keys         IMPORT
        (* CONST *)     ComputeKey;

FROM Locks        IMPORT
        (* TYPES *)     AFileLockResult,
        (* PROCS *)     LockFile, UnLockFile;

FROM LStrings     IMPORT
        (* PROCS *)     SetString, ConcatLS, ConcatS, CtoS, StoC,
                        SubStr, LStringToTString, TStringToLString,
                        Insert, Fill, StringsEqual, Upshift, TrimRear, Copy,
                        Procustes, LengthOf, Search, Remove, SetLengthOf;

FROM Menus        IMPORT
        (* PROCS *)     NoYes, MenuWithPrompts, WordNumber;

FROM MsgFile      IMPORT
        (* PROCS *)     GetMessage, ConcatMessage, DisplayMessage;

FROM Notices      IMPORT
        (* TYPE *)      AnOccasion, AStep,
        (* PROC *)      Permission, SendNotices;

FROM Overlays     IMPORT
        (* VARS  *)     PackageOK,
        (* PROCS *)     CallOverlay, CallOverlayWithContext, OverlayContext;

FROM Schedule     IMPORT
        (* VARS  *)     ProjectText, ProjectStartDate, CurrentFileExtension,
                        Author, FullScheduleName, ZeroIsLowestPriority,
                        ConfigSaved, ScheduleSaved, ProjectMedia,
                        InstalledFlag, RetrievalName, ProjectName, Loaded,
        (* PROCS *)     DisplayScheduleLight, IsScheduleLocked;

FROM Space        IMPORT
        (* PROCS *)     HeapAvailable;

FROM SSaveOptions           IMPORT
    (* PROC *)                  DoSaveDialog;

FROM SYSTEM       IMPORT
        (* PROCS *)     TSIZE, SIZE, ADR, ADDRESS;

FROM TimeFormat   IMPORT
        (* PROC *)      TimeUtoS;

FROM TreeObjects  IMPORT
        (* TYPE *)      ATree, ATreeNode, ATreeOrder,
                        ATreeNodeProcessingProc,
        (* PROC *)      ValidateTree, ValidateTreeNode;

FROM Words          IMPORT
        (* PROC *)      ParseString;




CONST
    ModuleNumber            = 21200;   (* For GetMessage. *)
    ReadOnlyMsg             = 15;

VAR
    Name                    : ARRAY [0..20] OF CHAR;
    Class                   : CARDINAL;
    Category                : AHoldTypeSet;
    Where                   : ADDRESS;
    Size                    : CARDINAL;



PROCEDURE EraseFileName (   VAR s             : ARRAY OF CHAR );

VAR
    Dev                 : ARRAY [0..5] OF CHAR;
    Path                : ARRAY [0..5] OF CHAR;
    FileName            : ARRAY [0..15] OF CHAR;
    Ext                 : ARRAY [0..5] OF CHAR;

BEGIN
    ExtractFileNameParts (s, Dev, Path, FileName, Ext);
    SetString (s, ".");
    ConcatLS (s, Ext);
END EraseFileName;



PROCEDURE CheckForOption(   PrimarySave,
                            SaveFlag          : CHAR;
                            FileFormExists,
                            NewFile           : BOOLEAN;
                        VAR ExportNameOnly    : ARRAY OF CHAR;
                        VAR SaveConfiguration,                    (* 07-Jul-87 LAA *)
                            SaveSchedule,
                            SelectiveSave     : BOOLEAN ) : BOOLEAN;
VAR
    MessagePhrase,
    ChoicePhrase,
    TitlePhrase,
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..29] OF CHAR;
    Prefix,
    Choices                 : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..1]   OF CHAR;

BEGIN
    IF (FileFormExists) THEN
        Copy( ExportMedia, Prefix );                              (* 07-Jul-89 LAA *)
        ConcatLS(  Prefix, ExportNameOnly );
        ConcatS(Prefix, "ü");     (* Line break char. *)
        IF (NewFile) THEN   (* RSC 12-Jun-89 *)
            Choice := 2;        (* KKC Aug 18, 1989 *)
            MessagePhrase := 16;      (* "Shall I save this file?" *)
            ChoicePhrase  := 17;      (* "Cancel,Save,Make Copy,Xtract,Save Options only" *)
            TitlePhrase   := 18;      (* "Save file?" *)
            IF (SaveFlag = "N") OR (PrimarySave = "N") THEN           (* 28-Jan-88 LAA *)
                SaveSchedule      := TRUE;
                SelectiveSave     := FALSE;
                SaveConfiguration := TRUE;
                RETURN TRUE;
            END;
        ELSE
            Choice := 1;            (* KKC Aug 18, 1989 *)
            MessagePhrase := 4;       (* "Shall I replace the old version on the disk with this new one?" *)
            ChoicePhrase  := 5;       (* "Cancel,Replace,Make Copy,Xtract,Save Options only" *)
            TitlePhrase   := 6;       (* "Replace file?" *)
            IF (SaveFlag = "N") OR (PrimarySave = "N") THEN           (* 28-Jan-88 LAA *)
                ChoicePhrase := 10;   (* "Cancel,Replace,Export under a different name" *)
            END;
        END;
    ELSE
        Choice := 2;        (* KKC Aug 18, 1989 *)
        MessagePhrase := 1;       (* "There is no name on the file form" *)
        ChoicePhrase  := 2;       (* "Cancel,Name It,Save Options only" *)
        TitlePhrase   := 3;       (* "No FileName" *)
        IF (SaveFlag = "N") OR (PrimarySave = "N") THEN           (* 28-Jan-88 LAA *)
            ChoicePhrase := 9;    (* "Cancel,Name this exported file" *)
        END;
        SetLengthOf( Prefix, 0 );
    END;
    ConcatMessage(Prefix, ModuleNumber + MessagePhrase);
    GetMessage(ModuleNumber+ChoicePhrase,Choices); (* (see above) *)
    GetMessage(ModuleNumber+TitlePhrase, Title  ); (* Replace File *)

    SaveSchedule      := FALSE;

    SetLengthOf(s, 0);
    IF (MultipleChoiceBox(Prefix, Title, OfferHelp, s, Choices, Choice)) THEN
        IF (NOT FileFormExists) AND (Choice > 1) THEN
                (* Adjust for the missing 'Replace' and 'Extract' options *)
            Choice := 2 * (Choice - 1) + 1;
        END;
        CASE Choice OF
            1 : RETURN FALSE;        (* "No" *)

        |   2 : IF (TaskTree^.Methods^.GetFirst(TaskTree) = NIL) THEN
                    GetMessage(ModuleNumber + 7, Prefix);   (* "?? Even though there are no tasks in this schedule? " *)
                    IF (NOT ContinuationBox(Prefix,s,NoHelp)) THEN
                        RETURN FALSE;
                    END;
                END;
                SaveSchedule      := TRUE;  (* "Replace" *)
                SelectiveSave     := FALSE; (* The whole thing *)
                SaveConfiguration := TRUE;
                ConfigSaved       := FALSE;
                (* *** ConfigSaved       := FALSE; RSC 12-Jun-89 *)

        | 3,4 : SelectiveSave := (Choice = 4);
                EraseFileName (ExportName);

                IF (GetOutputFile(ExportMedia, ExportName,
                                  ExportMedia, ExportName,
                                  TRUE (* Offer assistance *) ))  THEN

                    IF (SelectiveSave) THEN
                        IF (NOT DoSaveDialog ()) THEN
                            RETURN FALSE;
                        END;
                    END;

                    SaveSchedule      := TRUE;  (* "Make Copy/Different Name" *)
                    SaveConfiguration := FALSE;
                    (* RSC 2/3/88: *)
                    ExtractFileNameParts( ExportName,
                                          Prefix, Prefix,  (* Place holders *)
                                          ExportNameOnly,  (* Just the name *)
                                          Prefix           (* Place holder  *)
                                         );
                ELSE
                    RETURN FALSE;
                END;

        |   5 : SaveConfiguration := TRUE;  (* "Save options only" *)
                ConfigSaved       := FALSE;
        ELSE
                FatalError;
        END;
    ELSE
        RETURN FALSE;
    END;

    RETURN TRUE;

END CheckForOption;



MODULE Tokens;

IMPORT
    (* PROC *)              AsOfDate;

IMPORT
    (* CONST *)             ModuleNumber;

IMPORT
    (* TYPE *)              ASetOfCodes,
    (* VAR *)               EmptyCodeSet,
    (* PROC *)              SetCodeBits;

IMPORT
    (* PROC *)              SetString, Search, LengthOf, Copy, ConcatLS,
                            TStringToLString, SetLengthOf, Upshift, CtoS,
                            StringsEqual, ConcatS;

IMPORT
    (* PROC *)              WordNumber;

IMPORT
    (* PROC *)              GetMessage;

IMPORT
    (* VAR *)               ProjectMedia, VersionString,
                            EXEPath, ExportMedia, ExportName;

IMPORT
    (* TYPE *)              AHoldTypeSet, AHoldType,
    (* PROC *)              LocateHeldItem;

IMPORT
    (* TYPE *)              ADDRESS;

IMPORT
    (* PROC *)              ExpandPath, DOSVersion;

IMPORT
    (* PROCS *)             TimeUtoS;

IMPORT
    (* PROC *)              RequestFileFind;





EXPORT                      FindToken, SkipToken, GetTokenValue;


CONST
    TLWhatUse               = 10000;

VAR
    ValidTokenChar          : ASetOfCodes;


PROCEDURE FindToken(VAR String              : ARRAY OF CHAR;
                        Start               : CARDINAL     )
                                                            : CARDINAL;

VAR
    s1                      : ARRAY [0..1] OF CHAR;

BEGIN                       (* FindToken *)

    SetString(s1, "@");
    RETURN Search(String, s1, Start);

END FindToken;


PROCEDURE SkipToken(VAR String              : ARRAY OF CHAR;
                        Start               : CARDINAL     )
                                                            : CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* SkipToken *)

    IF (Start > LengthOf(String)) THEN
        RETURN LengthOf(String) + 1;
    END;

    INC(Start);
    LOOP
        IF (Start > LengthOf(String)) THEN
            EXIT;
        END;
        i := ORD(String[Start]);
        IF (NOT ((i MOD 16) IN ValidTokenChar[i DIV 16])) THEN
            EXIT;
        END;
        INC(Start);
    END;

    RETURN Start;

END SkipToken;


PROCEDURE GetTokenValue(VAR Token           : ARRAY OF CHAR;
                        VAR Value           : ARRAY OF CHAR);

TYPE
    AHolderProc             = PROCEDURE(VAR ARRAY OF CHAR);

VAR
    i                       : CARDINAL;
    Size                    : CARDINAL;
    Where                   : ADDRESS;
    LStringPtr              : POINTER TO ARRAY [0..255] OF CHAR;
    HoldProc                : AHolderProc;
    Category                : AHoldTypeSet;
    TokenNames              : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..99]  OF CHAR;
    s2                      : ARRAY [0..99]  OF CHAR;

    PROCEDURE GetCurrentDir( VAR s : ARRAY OF CHAR );
    VAR
        SNil : ARRAY [0..1] OF CHAR;
    BEGIN
        SetLengthOf( SNil, 0 );
        ExpandPath(  SNil, SNil, s );
    END GetCurrentDir;

BEGIN                       (* GetTokenValue *)

    SetLengthOf(Value, 0);
    IF (LengthOf(Token) > 0) THEN
        GetMessage(ModuleNumber + 13, TokenNames);
        Copy(Token, s);
        Upshift(s);

        i := 0;
        REPEAT
            INC(i);
            WordNumber(TokenNames, i, s2);
        UNTIL ((LengthOf(s2) = 0) OR (StringsEqual(s2, s)));        (* RSC 1/2/88 *)

        IF (LengthOf(s2) = 0) THEN
            IF (LocateHeldItem(s, TLWhatUse, Category, Where, Size)) THEN
                IF (HoldsLString IN Category) THEN
                    LStringPtr := Where;
                    Copy(LStringPtr^, Value);
                ELSIF (HoldsProc IN Category) THEN
                    HoldProc := AHolderProc(Where);
                    HoldProc(Value);
                ELSIF (HoldsNumber IN Category) THEN
                    CtoS(Size, Value);
                END;
            END;
        ELSE
            CASE i OF
                1 :         (*  @SCHEDULEFILE       *)
                    Copy(ExportMedia, Value);
                    ConcatLS(Value, ExportName);
(*            |   2 :         (*  @PLOTTERNAME        *)*)
(*                    Copy(PlotterRecord.Name, Value);*)
(*            |   3 :         (*  @PLOTTEREQUIVALENT  *)*)
(*                    Copy(PlotterRecord.EquivalentTo, Value);*)
            |   4 :         (*  @DK    (curr dir)   *)
                    GetCurrentDir( Value );
            |   5 :         (*  @PROJECTDIR         *)
                    Copy( ProjectMedia, Value );
            |   6 :         (*  @EXEDIRECTORY       *)
                    Copy( EXEPath, Value );
            |   7 :         (*  @DOSVERSION         *)
                    CtoS( DOSVersion(), Value );
            |   8 :         (*  @DATEANDTIME        *)
                    TimeUtoS( AsOfDate , Value );
            |   9 :         (*  @SERIALNUMBER       *)
                    Copy( VersionString, Value );
            ELSE
            END;
        END;
    END;

END GetTokenValue;


BEGIN                       (* Tokens *)

    ValidTokenChar := EmptyCodeSet;
    SetCodeBits(ValidTokenChar, ORD("0"), ORD("9"), TRUE);
    SetCodeBits(ValidTokenChar, ORD("a"), ORD("z"), TRUE);
    SetCodeBits(ValidTokenChar, ORD("A"), ORD("Z"), TRUE);

END Tokens;






PROCEDURE MakeBatchFile( VAR ContextString : ARRAY OF CHAR;
                             ParseLocation : CARDINAL );
CONST
    InterfaceFileName = ".\TLNEXT.BAT";
VAR
    i  : CARDINAL;
    j  : CARDINAL;
    f  : File;
    s  : ARRAY [0..99] OF CHAR;
    s2 : ARRAY [0..99]  OF CHAR;
    Token : ARRAY [0..99] OF CHAR;

    PROCEDURE FileComplaint;
    BEGIN
        SetString(s,InterfaceFileName);
        DisplayFileError( f, s );
    END FileComplaint;


    PROCEDURE Print( VAR s : ARRAY OF CHAR );
    BEGIN
        i := 1;
        WHILE (i <= ORD(s[0]) ) AND (CheckIO(f) = done) DO
            WriteChar(f,s[i]);
            IF (CheckIO(f) <> done) THEN
                FileComplaint;
                f.res := notdone; (* So we don't try again. *)
                RETURN;
            END;
            INC(i);
        END;
    END Print;

BEGIN

    (* If there is nothing to put into the batch file, don't create it. *)

    i := ParseLocation;  (* Don't lose our place here. *)
    ParseString( ContextString, i, s );
    IF (s[0] = 0C) THEN
        RETURN;
    END;

    Delete(InterfaceFileName, f);           (* 25-May-90 WKH *)

        (* Create a new file with a set name. *)

    PrepareForIO(f);
    Lookup(f,InterfaceFileName,TRUE);
    IF (CheckIO(f) <> done) THEN
        FileComplaint;
        RETURN;
    END;

        (* Write out all lines of text to the TLNEXT file, substituting in
           the schedule name as appropriate.
        *)

        (*  Added token substitution, removed use of tilde.  *)   (* 24-Feb-88 LAA *)

    WHILE (ParseLocation < ORD(ContextString[0])) DO
        ParseString( ContextString, ParseLocation, s );
        i := FindToken( s, 1 );
        WHILE (i <> 0) DO
            j := SkipToken(s, i);
            SubStr(s, Token, i + 1, j - (i + 1));
            Remove( s, i, j - i );                   (* Remove the name to be substituted *)
            GetTokenValue(Token, s2);
            Insert( s, s2, i );
            i := FindToken( s, i );
        END;
        Print(s);
        IF (CheckIO(f)=done) THEN
            WriteChar(f,EOL);
        END;
    END;

        (* Always close our files. *)

    Close(f);

END MakeBatchFile;





    (* 17-Sep-90 RSC:

       Set up the file save and the config save.
       Do this here to save stack space.   Prior to 17-Sep-90, this
       was being done in SaveCurrentProject, which cost some
       stack space.  This could be a problem when we call who-knows-what
       saving overlay.
    *)
PROCEDURE SetUpSave( VAR RecomputeSchedule   : BOOLEAN;
                     VAR TInstalledFlag      : CHAR     );

VAR
    Context                 : POINTER TO ARRAY [0..255] OF CHAR;
    Choice                  : CARDINAL;
    i                       : CARDINAL;
    ParseLocation           : CARDINAL;
    f                       : File;
    LockResult              : AFileLockResult;
    ok                      : BOOLEAN;
    FileNameRecord          : AFileNameRecord;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..99]  OF CHAR;
    s3                      : ARRAY [0..99]  OF CHAR;
    ExportNameOnly          : ARRAY [0..8]   OF CHAR;
    Extension               : ARRAY [0..4]   OF CHAR;
    NullString              : ARRAY [0..0]   OF CHAR;
    SaveFlag,
    PrimarySave             : CHAR;

BEGIN

    s := "Program Copyright (c) 1989 Symantec Corporation.";

    RecomputeSchedule := FALSE;




 (* Our overlay context can be:

        <Nil>, which defaults to "? T?0" (file save)
     or
        <Primary Save> <Save Flag> <Extension> <First Time Flag>

           Where <Primary Save> is Y=Model save, N=an export.
                                   ?=SAVE DAMMIT!  Dont ask me any questions!
                 <Save flag>    is Y=ALWAYS save config file.
                                   N=NEVER save config file.
                                   ?=Save if 'ConfigSaved' is FALSE.
                 <Extension>    is the default extension for the save.
                 <First Time>   is Y=Set InstalledFlag to FALSE
 *)
    Context := OverlayContext();
    IF (Context = NIL) THEN
        Copy( CurrentFileExtension, Extension ); (* 17-Sep-90 RSC *)
        Remove(    Extension, 1, 1 );            (* Remove "." of ".T?0" *)
        SetString( SaveFlag,       "?"  );
        SetString( PrimarySave,    "Y"  );
        SetString( TInstalledFlag, "Y"  );
    ELSE
        ParseLocation := 1;
        ParseAFlag( Context^, PrimarySave,    ParseLocation );
        ParseAFlag( Context^, SaveFlag,       ParseLocation );
        ParseString(Context^, ParseLocation,  s             );
        ParseAFlag( Context^, TInstalledFlag, ParseLocation );
        Copy( s, Extension );
        IF (SaveFlag     = 0C) OR
           (PrimarySave  = 0C) OR
           (Extension[0] = 0C)  THEN
            GetMessage( ModuleNumber+12, s ); (* "tlxprep:Error in tlwhat!" *)
            Error(s);
            PackageOK := FALSE;
            RETURN;
        END;
    END;




    (* If the Save Flag is TRUE, we want to FORCE a config save.
       If it is TRUE OR MAYBE (?), We want to set the
                'Maybe save config' flag.
    *)
    SaveConfiguration := (SaveFlag <> "N"); (* Do we want to save? *)
    IF (SaveFlag = "Y") THEN
        ConfigSaved := FALSE; (* Force a config save? *)
    END;

       (*  Determine if the file already exists, but use 'ExportName' rather
           than ProjectName in case we have as 'Save As ....' situation.
       *)
    SetLengthOf( s, 0 );
    ExpandPath( ProjectMedia, s, ExportMedia );
    TrimRear( ProjectName );
    Copy(ProjectName,  ExportNameOnly );
    ok := (LengthOf( ExportNameOnly ) > 0);
    Copy( ExportNameOnly, ExportName );
    ConcatS(  ExportName, "."        );
    ConcatLS( ExportName, Extension  );

    IF (NOT ok) THEN
        IF (NOT CheckForOption( PrimarySave, SaveFlag,
                                FALSE, FALSE,
                                ExportNameOnly, SaveConfiguration,
                                SaveSchedule, SelectiveSave )) THEN
            PackageOK := FALSE;
            RETURN;
        END;
        IF (ProjectName[0] = 0C) THEN             (* save file form name iff it was empty. *)
            Copy( ExportNameOnly, ProjectName );  (* RSC 1/28/88 *)

            SetLengthOf(s, 0);                     (* 1-Dec-89 WKH  *)
            ExpandPath(ExportMedia, s, s2);
            ExpandPath(ProjectMedia, s, s3);
            IF (NOT StringsEqual(s2, s3)) THEN
                Copy( ExportMedia,    ProjectMedia ); (* RSC 2/3/88 *)  (* 26-Sep-89 LAA *)(* 20-Nov-89 WKH  *)
            END;

            Loaded := TRUE;                       (* RSC 2/3/88 So the light turns on. *)
            DisplayScheduleLight();               (* RSC 2/3/88 *)
            SaveConfiguration := TRUE;            (* RSC 2/3/88 *)
            ConfigSaved       := FALSE;           (* RSC 2/3/88 *)
        END;
        ok := TRUE;
    ELSE
        IF (NOT DirectoryIsReachable( ExportMedia )) THEN
            GetMessage(ModuleNumber + 11,s ); (* "Disk gone or directory unreachable:" *)
            ConcatLS(s,ExportMedia);
            Error(s);
            PackageOK := FALSE;
            RETURN;
        END;
        Copy( ExportMedia, s );
        ConcatLS( s, ExportName );

        FileNameRecord.Attributes := AFileAttributeSet{ReadOnlyAttribute,  (* 4/13/89 WKH *)
                                                       ArchiveAttribute};

        (* So, we try to see if it is a new file by seeing if it exists *)
        NewFile := (NOT StartFileNodeLookup(s, FileNameRecord));

        (* If it already exists, then let's check to see if it's zero length*)
        (* If it exists and is zero length, then it could be a locked file *)
        IF (NOT NewFile) THEN
            NewFile := (FileNameRecord.Size = 0);
        END;

        (* Let's see if we can write to the directory, 29-Jun-89 *)

        IF (NewFile) THEN (* 5/12/89 WKH *)
            Copy(ExportMedia, s);
            ConcatS(s, "!TEST!ZM.!!!"); (* 17-Sep-90 RSC Unix doesn't like "$" *)
            LStringToTString(s, s);
            LockResult := LockFile(s, f, AFileAccessRightSet{BTSFullAccess});

            CASE LockResult OF
                UnLockable :
                    NewFile := FALSE;

            |   ReadLock :
                    NewFile := FALSE;
                    UnLockFile(f);

            |   FullLock :      (* 05-Sep-89 WKH *)
                    UnLockFile(f);
                    Delete(s, f);

            |   AlreadyLocked,
                NoSuchFile :
                    UnLockFile(f);
            ELSE
                FatalError();
            END;

        END;

        IF (NewFile) THEN
            IF (NOT CheckForOption( PrimarySave, SaveFlag,
                                    TRUE, NewFile,
                                    ExportNameOnly, SaveConfiguration,
                                    SaveSchedule, SelectiveSave )) THEN
                PackageOK := FALSE;
                RETURN;
            END;
        ELSE
            IF (IsScheduleLocked()) THEN    (* 4/10/89 WKH *)
                IF (PrimarySave = "?") THEN (* 11-Jul-89 WKH *)
                    IF (SaveFlag <> "Y") THEN (* RSC 12-Jun-89 *)
                        GetMessage (ModuleNumber+14, s);    (* "Save the schedule?" *)
                        SetLengthOf(NullString, 0);
                        IF ( ContinuationBox (s, NullString, NoHelp) ) THEN
                            SaveSchedule      := TRUE;
                            SaveConfiguration := TRUE;
                        ELSE
                            PackageOK := FALSE;
                            RETURN;
                        END;
                    ELSE
                        SaveSchedule      := TRUE;
                        SaveConfiguration := TRUE;
                    END;
                ELSE
                    IF (NOT CheckForOption( PrimarySave, SaveFlag,
                                            TRUE, NewFile,
                                            ExportNameOnly, SaveConfiguration,
                                            SaveSchedule, SelectiveSave )) THEN
                        PackageOK := FALSE;
                        RETURN;
                    END;
                END;
            ELSE
                IF (NOT CheckForOption( PrimarySave, SaveFlag,
                                        TRUE, FALSE,
                                        ExportNameOnly, SaveConfiguration,
                                        SaveSchedule, SelectiveSave )) THEN
                    PackageOK := FALSE;
                    RETURN;
                ELSIF (SaveSchedule) THEN
                    SetLengthOf(s, 0);
                    ExpandPath(ProjectMedia, s, s3);

                    IF (StringsEqual(s3, ExportMedia) AND
                        StringsEqual(ExportNameOnly, ProjectName)) THEN
                        GetMessage(ModuleNumber + ReadOnlyMsg, s);
                        Error(s);
                        PackageOK := FALSE;
                        RETURN;
                    END;
                END;
            END;
        END;
    END;

    IF (SaveSchedule) THEN
        GetMessage(ModuleNumber + 8, s);   (* "Recompute before saving your project file? " *)
        IF (NOT(Scheduled IN ChartState)) AND (NoYes(s)) THEN
            RecomputeSchedule := TRUE;
        END;
    ELSIF (SaveConfiguration) THEN
        Copy( ProjectMedia, ExportMedia ); (* Preserve orig. phrasing, like "DK:" *)
    END;

        (* Store the name of the file we just saved into a
           specially-named file in the current directory.  This
           is so that the plotter back-end can read it and locate
           the actual data file. *)

    MakeBatchFile( Context^, ParseLocation );

END SetUpSave;







PROCEDURE SaveCurrentProject();
VAR
    ConfigOverlay       : ARRAY [0..8] OF CHAR;
    RecomputeSchedule   : BOOLEAN;
    TInstalledFlag      : CHAR;
BEGIN

    SetUpSave( RecomputeSchedule, TInstalledFlag );

    IF (RecomputeSchedule) THEN
        Dispatch(ComputeKey);
    END;

    IF (PackageOK AND SaveConfiguration AND (NOT ConfigSaved)) THEN
        InstalledFlag := (TInstalledFlag <> "Y");
        SetString( ConfigOverlay, "|TLXCNFG" );
        PackageOK := CallOverlay( ConfigOverlay );
    END;

END SaveCurrentProject;









BEGIN

    IF (Permission(ModelSave,NIL)) THEN         (* OK to save or export? *)
        SendNotices (ModelSave, BeforeActing, NIL);     (* 6/4/89 EGK *)
        SaveCurrentProject;                     (* Do what is appropriate. *)
        SendNotices(ModelSave,AfterActing,NIL); (* Tell 'em we did it. *)
    END;

END TLXPrep.
