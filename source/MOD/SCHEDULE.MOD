IMPLEMENTATION MODULE Schedule;

(*  =========================================================================
    Last Edit : January 22, 1991 12:58PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 


    MODIFICATION HISTORY:

    07/23/86 LAA    Change the type of Code to CARDINAL in CheckScheduleForm.
    07/30/86 LAA    Removed usage of HotLinkedProjectName.
    11/04/86 LAA    ChartState is now a set, so the usage of SetState and
                    UnSetState has changed.
    11/25/86 LAA    Modified for new Lights module.  Exported new procedure
                    to display the schedule light.
    12/03/86 LAA    Only one line of project notes is now displayed on the
                    form.
    12/16/86 LAA    Incorporated new version of Edit.
    12/31/86 LAA    Changed screen coordinates of edit window.
    03/18/87 EGK    Added code for new As-of setting field.  The As-of date
                    is set from the form value only if "Manual" is selected.
                    Otherwise, the As-of date field is protected and set
                    externally by SetAsOfDate.
    03/30/87 EGK    As-of date value (on form) changes appropriately as
                    different as-of settings are selected.
    30-Mar-87 LAA   Incorporated second version of editor, which uses object
                    oriented concepts.
    07-Aug-87 EGK   Moved lots of fields from the schedule form to the
                    options form.
    18-Sep-87 RSC   Altered form string value initialization and editing of
                    the schedule form.
     8-Oct-87 RSC   Altered the Options Form check proc a little because of
                    a changed Options Form.  Fields moved around, (Yes,No)
                    became (No,Yes) for consistancy, and added the "undo
                    steps" field.  Also squish out spaces in the file name
                    fields in the project form.
    13-Oct-87 RSC   Added 'Set as Highest Priority' field to optns form.
    15-Oct-87 RSC   Changed param to EditText.  Added Shadows.
    28-Oct-87 RSC   Notify Forms when text has been edited to prevent
                    accidental ESCs.
    21-Dec-87 EGK   Moved DoOptionsForm into TLSCHFOR overlay.
    20-Jan-88 RSC   Moved ScheduleForm into TLFFORM overlay.
    11-Feb-88 LAA   Changed SortSelection to default to EarlyStartDate.
    02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
    04-Apr-89 WKH   Added schedule file locking capabilities to support LAN's
    06-Apr-89 WKH   Added AllowReadLock var to ScheduleLock.
    07-Apr-89 WKH   Added proc IsScheduleLocked and erase any 0 length scheds
                    when we unlock it.  Also record DOS timestamp.
    11-Apr-89 WKH   Forgot Logitech routines don't like LStrings.
    12-Apr-89 WKH   Moved ScheduleDOSTimeStamp from here to def
    20-Apr-89 WKH   Detect locking error due to write protected device.
                    Also, don't retrieve timestamp of read only lock.
     1-May-89 WKH   Changed Lock/UnLockSchedule so they don't really lock a
                    file on a device with removable media.
    07-May-89 WKH   Added a "shadow" lock so we can release a lock during
                    renaming of files, and still have other sessions of
                    Time Line locked out.
    08-May-89 WKH   Actually add code to support this "Shadow lock"
    12-May-89 WKH   Well, the shadow lock bit me in the b__.  But after
                    these changes, all should be as was before.
    05-Jun-89 WKH   Always show the schedule name light if the name exists.
    20-Jun-89 WKH   Initialize ProductName variable to TimeLine.
    25-Jun-89 WKH   Moved initialization of removed varialbes(listed in DEF)
                    from here into Registry.DEF
    07-Jul-89 WKH   Expanded the path used to delete the shadow and schedule
                    file if it's 0 length.  Also, on floppy based files, we
                    weren't initializing the shadowlock var correctly.
    11-Sep-89 AJL   Initialize FullScheduleName and Author.
    02-Nov-89 WKH   Make UnLockSchedule aware of LockClasses for floppy disks.
    06-Dec-89 WKH   Use MAXCARDINAL for bad file tag instead of 0.  This
                    is MUCH safer.  What was happening was that we(ok, I)
                    were assuming that slot 0 in the files[] data
                    structure in DiskFiles was always occupied by
                    TLPHRAS4.DAT.  Well, I assumed incorrectly.  Shame on
                    me.  Roger removed MsgFile's reliance on FileSystem
                    and moved it to DOSIO.  Thus, slot 0 could be anyone
                    nowadays.  So, I decided to use a flag that was
                    a little more safer, thus MAXCARDINAL (this is well
                    outside the range of valid file slots).
    05-Jun-90 AJL - Add Revision number.
                  - Add an asterisk to the project name when modified.
    07-Jun-90 AJL - Fixed a typo which caused a FatalError.
    10-Sep-90 RSC - Update "$" to "%".
    14-Sep-90 RSC   Added file extensions to parameterize those that
                    are not easily added to the phrases file.
    24-Oct-90  PFG  Added StartDateMustStart and ForceCritical for
                    the Options form.
     2-Nov-90  AJL  Put those options into a record, FixedDateRules.
     5-Nov-90  AJL  The character which follows the schedule name light to
                    indicate that the schedule has been changed is now
                    phrase #11.
    22-Jan-91  RSC  Change fHint to mHint for new file system.
    =========================================================================
*)



FROM BigTimeU               IMPORT
                                ABigTime;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Directory              IMPORT
    (* TYPE *)                  AFileNameRecord, AFileAttribute, AFileAttributeSet,
    (* PROC *)                  StartFileNodeLookup, RemovableMedia,
                                ExtractFileNameParts, ExpandPath;


FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  WarningBox, Error, FatalError, ContinuationBox;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, AFileAccessRight, AFileAccessRightSet,
    (* PROC *)                  Length, Delete;

FROM GaGa                   IMPORT
    (* PROC *)                  GetGaGaMessage;

FROM Keys                   IMPORT 
    (* CONST *)                 CancelKey;

FROM Lights                 IMPORT 
    (* TYPE *)                  ALight, 
    (* PROC *)                  ActiveLightRegion, InstallLight, DisplayLight;

FROM Locks                  IMPORT
    (* TYPE *)                  AFileLockResult,
    (* PROC *)                  LockFile, UnLockFile;

FROM LStrings               IMPORT 
    (* PROC *)                  Fill, SubStr, SetString, ConcatLS, LengthOf,
                                TrimRear, LJust, LStringToTString, Procustes,
                                Search, Insert, Remove, Copy, SetLengthOf,
                                TStringToLString;

FROM Kbio                   IMPORT 
    (* TYPE *)                  avidmode;

FROM MsgFile                IMPORT 
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT 
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT 
    (* PROC *)                  ADR;

FROM Text                   IMPORT 
    (* TYPE *)                  AText;

FROM Timei                  IMPORT 
    (* VAR  *)                  Today;



CONST
    ModuleNumber            = 4600;
    ScheduleLightPriority   = 50;
    ScheduleIsLockedMsg     = 7;
    ScheduleIsLockedTitle   = 8;
    ScheduleUnLockableMsg   = 9;
    MAXCARDINAL             = 65535;    (* 6-Dec-89 WKH  *)

VAR
    ScheduleLight           : ALight;
    LightInstalled          : BOOLEAN;
    ScheduleFileRecord      : File;
    ScheduleShadowRecord    : File;
    WeIsUsingFloppys        : BOOLEAN;

PROCEDURE DoOptionsForm;

VAR
    OverlayName                 : ARRAY [0..29] OF CHAR;
    Result                      : BOOLEAN;

BEGIN

    SetString (OverlayName, "\TLFBASE(TLSCHFOR)");                (* 02-Mar-88 LAA *)
    Result := CallOverlayWithContext (OverlayName, NIL);

END DoOptionsForm;





PROCEDURE ScheduleForm(): ACode;
VAR
    Context                     : ACode;
    OverlayName                 : ARRAY [0..29] OF CHAR;
    Result                      : BOOLEAN;
BEGIN

    SetString (OverlayName, "!TLFBASE(TLFFORM)");                 (* 02-Mar-88 LAA *)
    Result := CallOverlayWithContext (OverlayName, ADR(Context) );
    IF (NOT Result) THEN
        Context := CancelKey;  (* Overlay fail? *)
    END;
    RETURN Context;

END ScheduleForm;







PROCEDURE DisplayScheduleLight();

VAR
    S                       : ARRAY [0..20] OF CHAR;

BEGIN

    IF (NOT LightInstalled) THEN
        LightInstalled := TRUE;
        InstallLight(ActiveLightRegion, ScheduleLightPriority, 8, 20, ScheduleLight);
    END;

    Copy (ProjectName, S); (* WKH 6/5/89, used to only happen if Loaded *)
    IF (NOT ScheduleSaved) THEN
        ConcatMessage(S,ModuleNumber+11);
    END;

    DisplayLight (ScheduleLight, S, videolights);

END DisplayScheduleLight;


PROCEDURE LockSchedule(VAR SchedulePath      : ARRAY OF CHAR;
                       VAR ScheduleName      : ARRAY OF CHAR;
                           AllowReadLock     : BOOLEAN;
                           ScheduleLockClass : AScheduleLockClass) : BOOLEAN;

VAR
    LocalFileRecord         : File;
    LocalShadowRecord       : File;
    s                       : ARRAY [0..100] OF CHAR;
    s1                      : ARRAY [0..100] OF CHAR;
    Msg                     : ARRAY [0..255] OF CHAR;
    Title                   : ARRAY [0..80]  OF CHAR;
    Device                  : ARRAY [0..2]   OF CHAR;
    Path                    : ARRAY [0..66]  OF CHAR;
    FName                   : ARRAY [0..8]   OF CHAR;
    Ext                     : ARRAY [0..3]   OF CHAR;
    FileNameRecord          : AFileNameRecord;
    AccessPrivelege         : AFileAccessRightSet;
    LockResult              : AFileLockResult;
    ShadowLockResult        : AFileLockResult;

BEGIN
    WeIsUsingFloppys := RemovableMedia(SchedulePath);

    LocalFileRecord   := ScheduleFileRecord;
    LocalShadowRecord := ScheduleShadowRecord;
    AccessPrivelege   := AFileAccessRightSet{BTSFullAccess};

    Copy(SchedulePath, s);
    ConcatLS(s, ScheduleName);

    IF (ScheduleLockClass = DualLock) THEN
        ExtractFileNameParts(s, Device, Path, FName, Ext);
        Copy(Device, s1);
        ConcatLS(s1, Path);
        ConcatLS(s1, FName);
        ConcatLS(s1, CurrentFileExtension);
        s1[LengthOf(s1)] := "_";
        LStringToTString(s1, s1);
    END;

    LStringToTString(s, s);

    IF (WeIsUsingFloppys) THEN
        LockResult := FullLock;
        WITH LocalFileRecord DO
            FileAccessRight := AFileAccessRightSet{BTSFullAccess, BTSLocked};
            mHint           := MAXCARDINAL; (* 6-Dec-89 WKH  *)
        END;

        ShadowLockResult := FullLock;   (* 07-Jul-89 WKH *)
        WITH LocalShadowRecord DO
            FileAccessRight := AFileAccessRightSet{BTSFullAccess, BTSLocked};
            mHint           := MAXCARDINAL; (* 6-Dec-89 WKH  *)
        END;
    ELSE
        LockResult       := LockFile(s, LocalFileRecord, AccessPrivelege);
        IF (ScheduleLockClass = DualLock) THEN
            ShadowLockResult := LockFile(s1, LocalShadowRecord, AccessPrivelege);
        ELSE
            ShadowLockResult := FullLock;
        END;
    END;

    IF (LockResult <> FullLock) OR (ShadowLockResult <> FullLock) THEN
        IF (AllowReadLock) THEN
            GetMessage(ModuleNumber + ScheduleIsLockedTitle, Title);
            IF (LockResult = AlreadyLocked) OR 
               (ShadowLockResult = AlreadyLocked) THEN
                (* message about someone is using this already, do you wish to retrieve
                read only *)
                GetMessage(ModuleNumber + ScheduleIsLockedMsg, Msg);
                IF (ContinuationBox(Msg, Title, OfferHelp)) THEN
                    LocalFileRecord.FileAccessRight := AFileAccessRightSet{};
                    LocalFileRecord.mHint           := MAXCARDINAL; (* 6-Dec-89 WKH  *)
                    IF (ScheduleLockClass = DualLock) THEN
                        LocalShadowRecord.FileAccessRight := AFileAccessRightSet{};
                        LocalShadowRecord.mHint           := MAXCARDINAL;  (* 6-Dec-89 WKH  *)
                    END;
                    LockResult := ReadLock;
                END;
            ELSIF (LockResult = UnLockable) OR (ShadowLockResult = UnLockable) THEN
                (* message to let user know file is write protected *)
                GetMessage(ModuleNumber + ScheduleUnLockableMsg, Msg);
                IF (ContinuationBox(Msg, Title, OfferHelp)) THEN
                    LocalFileRecord.FileAccessRight := AFileAccessRightSet{};
                    LocalFileRecord.mHint           := MAXCARDINAL; (* 6-Dec-89 WKH  *)
                    IF (ScheduleLockClass = DualLock) THEN
                        LocalShadowRecord.FileAccessRight := AFileAccessRightSet{};
                        LocalShadowRecord.mHint           := MAXCARDINAL; (* 6-Dec-89 WKH  *)
                    END;
                    LockResult := ReadLock;
                END;
            END;
        END;
    END;

    IF ((LockResult = FullLock) OR (LockResult = ReadLock)) THEN
        IF (BTSLocked IN ScheduleFileRecord.FileAccessRight) OR
           (BTSLocked IN ScheduleShadowRecord.FileAccessRight) THEN
            UnLockSchedule(ScheduleLockClass);
        END;
        IF (ScheduleFileRecord.mHint = MAXCARDINAL) THEN
            ScheduleFileRecord   := LocalFileRecord;
            IF (ScheduleLockClass = DualLock) THEN
                ScheduleShadowRecord := LocalShadowRecord;
            END;

            IF ( (LockResult = FullLock) AND (NOT WeIsUsingFloppys) )THEN (* 4/20/89 WKH *) (* 5/1/89 WKH *)
                TStringToLString(s, s);
                FileNameRecord.Attributes := AFileAttributeSet{ReadOnlyAttribute,
                                                                   ArchiveAttribute};
                IF (NOT StartFileNodeLookup(s, FileNameRecord)) THEN   (* WKH 4/7/89 *)
                    FatalError();
                END;
                ScheduleDOSTimeStamp := FileNameRecord.TimeStamp;      
            END;
        ELSE
            FatalError(); (* Something is really wrong, value not null *)
        END;
    END;

    RETURN ((LockResult = FullLock) OR (LockResult = ReadLock));
END LockSchedule;

PROCEDURE UnLockSchedule(ScheduleLockClass : AScheduleLockClass);

VAR
    LengthHigh              : CARDINAL;
    LengthLow               : CARDINAL;
    ZapString               : ARRAY [0..99] OF CHAR;
    f                       : File;
    s                       : ARRAY [0..1] OF CHAR;

BEGIN
    IF (BTSLocked IN ScheduleShadowRecord.FileAccessRight) THEN
        IF (WeIsUsingFloppys) THEN   (* 5/1/89 WKH *)
            ScheduleFileRecord.mHint := MAXCARDINAL;    (* 6-Dec-89 WKH  *)
            ScheduleFileRecord.FileAccessRight := AFileAccessRightSet{};
            IF (ScheduleLockClass = DualLock) THEN  (* 2-Nov-89 WKH  *)
                ScheduleShadowRecord.mHint := MAXCARDINAL; (* 6-Dec-89 WKH  *)
                ScheduleShadowRecord.FileAccessRight := AFileAccessRightSet{};
            END;
        ELSE
            SetLengthOf(s, 0);
            IF (ScheduleFileRecord.mHint <> MAXCARDINAL) THEN  (* 5/12/89 WKH *)
                Length(ScheduleFileRecord, LengthHigh, LengthLow); (* 4/7/89 WKH *)
                UnLockFile(ScheduleFileRecord);
                ScheduleFileRecord.mHint := MAXCARDINAL;

                IF ((LengthHigh = 0) AND (LengthLow = 0)) THEN  (* 4/7/89 WKH *)
                    ExpandPath(ProjectMedia, s, ZapString);
                    ConcatLS(ZapString, ProjectName);
                    ConcatLS(ZapString, CurrentFileExtension );
                    LStringToTString(ZapString, ZapString); (* 4/11/89 WKH *)
                    Delete(ZapString, f);
                END;    
            END;

            IF (ScheduleLockClass = DualLock) THEN
                UnLockFile(ScheduleShadowRecord);
                ScheduleShadowRecord.mHint := MAXCARDINAL;  (* 6-Dec-89 WKH  *)
                ExpandPath(ProjectMedia, s, ZapString);
                ConcatLS(ZapString, ProjectName);
                ConcatLS(ZapString, CurrentFileExtension);
                ZapString[LengthOf(ZapString)] := "_";
                LStringToTString(ZapString, ZapString); (* 4/11/89 WKH *)
                Delete(ZapString, f);
            END;
        END;
    END;
END UnLockSchedule;

PROCEDURE IsScheduleLocked() : BOOLEAN;
BEGIN
    RETURN (BTSLocked IN ScheduleShadowRecord.FileAccessRight); (* 5/7/89 WKH *)
END IsScheduleLocked;

BEGIN
        (* 14-Sep-90 RSC *)
    GetGaGaMessage( ModuleNumber + 1, CurrentFileExtension); (* ".T?0" *)

    InstalledFlag            := FALSE;
    Loaded                   := FALSE;
    ScheduleSaved            := TRUE;
    ConfigSaved              := TRUE;
    ProjectName[0]           := 0C;
    PlannedProjectName[0]    := 0C;
    RetrievalName[0]         := 0C;
    FullScheduleName[0]      := 0C;            (* 11-Sep-89 AJL *)
    Author[0]                := 0C;            (* 11-Sep-89 AJL *)
    RevisionNumber           := 0;
    SetString(ProjectMedia,     "DK:");
    ProjectStartDate         := Today;
    ProjectText              := AText(NIL);
    ZeroIsLowestPriority     := TRUE;
    LightInstalled           := FALSE;
    SortSelection            := 4;                                (* 11-Feb-88 LAA *)
    SortOrderManuallyAltered := TRUE;
    WarnBeforeManualChange   := FALSE;
    WITH FixedDateRules DO
        StartDateMustStart       := FALSE;                            (* 24-Oct-90 PFG *)
        ForceCritical            := TRUE;                             (* 24-Oct-90 PFG *)
    END;
    WITH ScheduleFileRecord DO
        mHint           := MAXCARDINAL;                           (* 03-Apr-89 WKH *)
        FileAccessRight := AFileAccessRightSet{};                 (* 03-Apr-89 WKH *)
    END;

    WITH ScheduleShadowRecord DO
        mHint           := MAXCARDINAL;                           (* 08-May-89 WKH *)
        FileAccessRight := AFileAccessRightSet{};                 (* 08-May-89 WKH *)
    END;

    WeIsUsingFloppys         := FALSE;                            (* 01-May-89 WKH *)

END Schedule.

