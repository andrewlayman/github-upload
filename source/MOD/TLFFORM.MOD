MODULE TLFForm;

(*  =========================================================================
    Last Edit : October 25, 1990 11:45AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        TL F FOrm  -  Handle the File  Form

    MODIFICATION HISTORY:
        20-Jan-88 RSC First Version, from Schedule.mod
        22-Jan-88 RSC Removed 'OverlaysPath' field.
        21-Dec-88 LAA Changed imports for Lazlo reorganization.
         6-Jan-89 RSC Moved "AnOverlayProc" reference.
        06-Apr-89 WKH Added locking support
        18-Apr-89 WKH Removed code from CheckScheduleForm and placed it into
                      ShedLocks under the procedure name NameAndLockSchedule
                      so that TLDir411 could re-use the code.
        30-Apr-89 WKH Accepting the file form with either a blank filename or
                      an unchanged file name now do the appropriate things.
        02-May-89 WKH Added lock class support
        30-May-89 RSC Added F2 support.
         1-Jun-89 RSC Improved the F2 support.
        05-Jun-89 WKH Changed key used to test if form is accepted.
        07-Jun-89 RSC Removed reference to "ConfigPath".
        08-Jun-89 RSC Make sure the wildcard lookup always uses *.T$0.
        09-Aug-89 KKC - Add copyright message.
        25-Aug-89 WKH We now check to see if a directory name has changed
                      semantically as opposed to syntactically as we used to.
                      For example, C:\WORK is SEMANTICALLY equivalent to
                      C:\WORK\ but not SYNTACTICALLY.
        08-Sep-89 LAA In the check-proc, the FileNameExt variable was not
                      being initialized before a call to 
                      GiveDirectoryAssistance.  Now, this couldn't have 
                      worked for long, so it must once have been done
                      correctly.  Don't know how it got lost, but I fixed the
                      bug by copying the file name field value into this
                      variable before the call.177
        21-Sep-89 WKH Make list box bigger, also give box a title
        21-Feb-90 KKC Remove import of Timeu.
        04-Jun-90 AJL Remove import of Planner.
        14-Sep-90 RSC Import the file extension rather than hardcoding it.
        15-Oct-90 AJL Send a notice when the form is through.
        25-Oct-90 RSC Remove hardcoded extension from the form and made it
                      the fourth field, display only.

    =========================================================================
*)

FROM Codes        IMPORT  ACode;

FROM Dialog       IMPORT  ADialogOption, WarningBox, Error, FatalError;

FROM Direct411    IMPORT
    (* PROCS *)         GiveDirectoryAssistance, AlwaysApprove;

FROM Directory    IMPORT  NormalizeFileName, DirectoryIsReachable,
                          ExtractFileNameParts,
                          ExpandPath, AFileNamePart, ASetOfFileNameParts;

FROM FileAux      IMPORT  OverlayPath;

FROM FormCon      IMPORT  AFieldNo;

FROM Forms        IMPORT  DoForm, AFieldValue, ACheckReason, NullCheckProc,
                          AStringValue, ShowValue, AForm, SetFieldProtection,
                          SetFormChange;

FROM Kbio         IMPORT  maxcol, avidmode, soundon, maxrow;

FROM Keys         IMPORT  CancelKey, AddTaskKey, CopyKey, JoinKey, UnJoinKey,
                          UndoKey, ChngTskKey, DelTaskKey, SplitKey, 
                          JoinPartialKey;

FROM Layout       IMPORT  GanttWStart, GanttWEnd;

FROM Lights       IMPORT ALight, ActiveLightRegion, InstallLight, DisplayLight;

FROM LStrings     IMPORT  Fill, SubStr, ConcatLS, LengthOf, ConcatS, TrimFront,
                          TrimRear, LJust, LStringToTString, Procustes,
                          Search, Insert, Remove, Copy, SetLengthOf,
                          StringsEqual;

FROM MsgFile      IMPORT GetMessage, ConcatMessage;

FROM Notices      IMPORT 
    (* TYPE *)        AnOccasion, AStep,
    (* PROC *)        SendNotices;


FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM PickDirs     IMPORT
        (* PROCS *)      PickDirectory;

FROM Schedule               IMPORT
    (* TYPE *)                  AScheduleLockClass,
    (* VAR *)                   ConfigSaved, ScheduleSaved,
                                Loaded, ProjectName, RetrievalName,
                                ProjectMedia, ProjectStartDate,
                                PlannedProjectName,
                                SortSelection,
                                SortOrderManuallyAltered,
                                DisplayScheduleLight,
                                WarnBeforeManualChange,
                                CurrentFileExtension,   (* 14-Sep-90 RSC  *)
    (* PROC *)                  IsScheduleLocked, UnLockSchedule;

FROM SchedLocks             IMPORT
    (* PROC *)                  NameAndLockSchedule;

FROM Text         IMPORT  AText, CopyLine, AssignLine, Compress, CreateText,
                          LineExists, TextExists;

FROM Edits        IMPORT  EditText;

FROM Transfer     IMPORT  BackupsToKeep;

FROM SYSTEM       IMPORT  ADR;



CONST
    ModuleNumber            = 4600; (* same as TLSchFor and Schedule!! *)

VAR
    OverlayID : AnOverlayID;



CONST
    GFN   = 0;
    DDF   = 1;
    ARC   = 2;
    EXT   = 3;

    ScheduleStringFields = {GFN,DDF,EXT};
    ScheduleStringCount  = 3;



PROCEDURE CheckScheduleForm (   Form        : AForm;
                                FieldNo     : AFieldNo;
                            VAR FormValue   : ARRAY OF AFieldValue;
                                CheckReason : ACheckReason;
                            VAR Code        : CARDINAL ):BOOLEAN;
VAR
    S                   : ARRAY [0..255] OF CHAR;
    Drive               : ARRAY [0..3]   OF CHAR;
    Title               : ARRAY [0..49]  OF CHAR;
    Title2              : ARRAY [0..19]  OF CHAR;
    FileNameExt         : ARRAY [0..59]  OF CHAR;
    ShadowProjectMedia  : ARRAY [0..79]  OF CHAR;
    ShadowUserMedia     : ARRAY [0..79]  OF CHAR;
    Dummy               : ARRAY [0..1]   OF CHAR;
    ok                  : BOOLEAN;

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

BEGIN
    Code := 0;

    SetLengthOf( Title, 0 );

    IF (CheckReason = CheckFieldKey) THEN
        IF (FieldNo = GFN) THEN                     (*  File name          *)
            Copy( FormValue[ DDF ].CharValue^, S );
            IF (S[LengthOf(S)] <> "\") THEN
                ConcatS( S, "\" );
            END;

            ConcatS(  S, "*" );
            ConcatLS( S, CurrentFileExtension ); (* 14-Sep-90 RSC *)

            Copy(FormValue[GFN].CharValue^, FileNameExt);         (* 08-Sep-89 LAA *)

            GetMessage(ModuleNumber + 10, Title2);
            ok := GiveDirectoryAssistance( GanttWStart,
                                           maxrow - 6,
                                           Title2,
                                           S,
                                           FileNameExt,
                                           AlwaysApprove );
            IF (ok) THEN
                ExtractFileNameParts( S, Drive,
                                      FormValue[ DDF ].CharValue^,
                                      FormValue[ GFN ].CharValue^,
                                      FileNameExt );
                Insert( FormValue[ DDF ].CharValue^, Drive, 1 );
            END;
            ShowValue( Form, FieldNo, FormValue );
            ShowValue( Form, DDF,     FormValue );
            RETURN ok;
        ELSIF (FieldNo = DDF) THEN                  (*  Project directory. *)
            GetMessage(ModuleNumber + 10, Title2);
            ok := PickDirectory( GanttWStart,
                                 maxrow - 6,
                                 Title2,
                                 FormValue[ FieldNo ].CharValue^ );
            ShowValue( Form, FieldNo, FormValue );
            RETURN ok;
        ELSE
            RETURN FALSE;
        END;
    END;

    IF (CheckReason <> CheckFieldChange) AND
       (CheckReason <> CheckFormExit)    THEN
        RETURN TRUE;
    END;

    WITH FormValue[ FieldNo ] DO
        IF (FieldNo = GFN) THEN                     (*  File name          *)
            Squish( CharValue^ );
        ELSIF (FieldNo = DDF) THEN                  (*  Project directory. *)
            Squish( CharValue^ );
            ExpandPath( CharValue^, Title, S );
            IF (NOT DirectoryIsReachable(S)) THEN
                GetMessage(ModuleNumber+1,S);  (* "Illegal file path" *)
                GetMessage(ModuleNumber+2,Title); (* "Bad path" *)
                WarningBox(S,Title,NoHelp);
                RETURN FALSE;
            ELSIF (CheckReason = CheckFormExit) THEN
                TrimFront(FormValue[GFN].CharValue^); (* 4/30/89 WKH *)
                TrimRear(FormValue[GFN].CharValue^);
                TrimFront(FormValue[DDF].CharValue^); (* 4/30/89 WKH *)
                TrimRear(FormValue[DDF].CharValue^);

                IF (LengthOf(FormValue[GFN].CharValue^) > 0) THEN (* 4/30/89 WKH *)
                    SetLengthOf(Dummy, 0);                        (* 8/25/89 WKH *)
                    ExpandPath(ProjectMedia, Dummy, ShadowProjectMedia);
                    ExpandPath(FormValue[DDF].CharValue^, Dummy, ShadowUserMedia);

                    IF ( (NOT StringsEqual(FormValue[GFN].CharValue^, 
                                           ProjectName))    OR
                         (NOT StringsEqual(ShadowUserMedia, 
                                           ShadowProjectMedia)) ) THEN
                        Copy(FormValue[GFN].CharValue^, FileNameExt);
                        ConcatLS(FileNameExt, CurrentFileExtension);    (* 14-Sep-90 RSC *)

                        IF (NOT NameAndLockSchedule(S, FileNameExt)) THEN (* 4/18/89 WKH *)
                            RETURN FALSE;
                        END;
                    END;
                ELSE
                    IF (IsScheduleLocked()) THEN
                        UnLockSchedule(DualLock);
                    END;
                END;
            END;
        END;
    END;
    RETURN TRUE;
END CheckScheduleForm;







PROCEDURE ScheduleForm();
CONST
     FormID = 0; 
VAR
    Context      : POINTER TO ACode;
    Loop, i      : CARDINAL;
    FormValue    : ARRAY [GFN..EXT] OF AFieldValue;
    StringFields : ARRAY [1..ScheduleStringCount] OF AStringValue;
    Copyright    : ARRAY [0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();

    i := 0;
    FOR Loop := GFN TO EXT DO
        IF (Loop IN ScheduleStringFields) THEN
            INC(i);
            FormValue[Loop].CharValue := ADR( StringFields[i] );
            FormValue[Loop].CharValue^[0] := 0C;
        ELSE
            FormValue[Loop].CharValue := NIL;
        END;
    END;

    Copy (ProjectName,          FormValue[GFN].CharValue^);
    Copy (ProjectMedia,         FormValue[DDF].CharValue^);
    Copy (CurrentFileExtension, FormValue[EXT].CharValue^); (* 25-Oct-90 RSC Display only *)

    FormValue[ARC].CardValue := BackupsToKeep;

    Context^ := DoForm(0,0,maxcol,GanttWEnd,FormID,TRUE,FormValue,CheckScheduleForm);

    IF (Context^ <> CancelKey) THEN  (* WKH 6/5/89 *)
        Copy (FormValue[GFN].CharValue^, ProjectName);
        TrimRear(ProjectName);
        Copy (FormValue[DDF].CharValue^, ProjectMedia);
        TrimRear(ProjectMedia);
        BackupsToKeep := FormValue[ARC].CardValue;

        TrimRear(OverlayPath);
        ConfigSaved := FALSE;
        ScheduleSaved := FALSE;

        SendNotices( MiscSetupChange, AfterActing, NIL );
        DisplayScheduleLight();     (* Schedule name may have changed. *)
    END;

END ScheduleForm;



BEGIN

    OverlayID := ImAnInstallableOverlay(ScheduleForm, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    ScheduleForm();

END TLFForm.
