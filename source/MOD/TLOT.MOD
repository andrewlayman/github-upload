MODULE TLOT;

(*  =========================================================================
    Last Edit : August 28, 1991 5:55PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Time Line On Target importer helper.  This overlay calls Steve
        Alexandar's On Target translator via Exit-To-DOS.

    MODIFICATION HISTORY:

     4-Jun-91 RSC First version.
    11-Jun-91 RSC Changed name to OT rather than ONTARGET.
    24-Jun-91 RSC Added the output file name.
    22-Jun-91 PFG Added support for OT error log.
    27-Aug-91 PFG We were relying on the caller of this (LoadAFile) to call
                  UnLockSchedule, but the temporary files weren't being
                  deleted, so we call it here instead.
    28-Aug-91 PFG Set the calculation state to Manual, even though the 
                  importer also sets this.  LoadAFile depends on knowing the
                  state of this field before we have the new schedule loaded.
    =========================================================================
*)


FROM ASCII              IMPORT
    (* CONST *)             EOL;

FROM Dialog             IMPORT
    (* PROC  *)             Error, FatalError;

FROM Directory          IMPORT
    (* PROC  *)             PathLookupStart, ExtractFileNameParts, 
    (* CONST *)             MaximumDeviceNameLength, MaximumPathNameLength,
                            MaximumFileNameLength, MaximumExtensionLength;

FROM MsgFile            IMPORT
    (* PROC  *)             GetMessage;

FROM FileAux            IMPORT
    (* PROC *)              CheckIO;

FROM FileOpen           IMPORT
    (* PROC *)              RequestFileOpenReadOnly;

FROM FileSystem         IMPORT
    (* TYPE *)              File, Response,
    (* PROC *)              Reset, SetRead, ReadChar, Close, Delete;

FROM LStrings           IMPORT
    (* PROC *)              SetString, ConcatS, ConcatLS, StoC, SetLengthOf,
                            Copy;

FROM Overlays           IMPORT
    (* PROC *)              OverlayContext, OverlayPackage, PackageOK;

FROM Planner            IMPORT
    (* TYPE  *)             AWhenToCalc, ACalcComponent,
    (* VAR   *)             CalculationState;

FROM Schedule           IMPORT
    (* TYPE  *)             AScheduleLockClass,
    (* PROC  *)             UnLockSchedule,
    (* VAR   *)             ProjectName, ProjectMedia;




CONST

    ModuleNumber = 16700;

    TempSchedName = "TEMPXXXX.5T0";
    ErrorLogName = "OT.LOG";

    (*  Error codes.  These must stay in synch with those in OT.EXE.  *)

    OT_MSG = 0;

    (*  If there is actually a zero in the log file, there were no errors,
        but we reuse the value of zero here to tell the error handler if
        there is no error log file, meaning that some really serious error
        happened.  *)

    SERIOUS = 0;

    (*  We forgot to pass either the OT, TL or error log file name:  *)
    MISSING_FILENAMES               = OT_MSG + 4;

    (*  File open or create errors:  *)
    CANNOT_OPEN_TIMELINE_FILE       = OT_MSG + 7;
    CANNOT_OPEN_ONTARGET_FILE       = OT_MSG + 8;

    (*  Importer ran out of memory:  *)
    CANNOT_ALLOCATE_MEMORY          = OT_MSG + 10;

    (*  File write errors:  *)
    CANNOT_WRITE_DIRECTORY          = OT_MSG + 15;
    CANNOT_WRITE_PROJECT            = OT_MSG + 16;
    CANNOT_WRITE_ENVIRONMENT        = OT_MSG + 17;
    CANNOT_WRITE_RESOURCES          = OT_MSG + 18;
    CANNOT_WRITE_TASKS              = OT_MSG + 19;
    CANNOT_WRITE_DEPENDENCIES       = OT_MSG + 20;
    CANNOT_WRITE_CALENDAR           = OT_MSG + 21;
    CANNOT_WRITE_SIGNATURE          = OT_MSG + 22;
    CANNOT_WRITE_COUNTS             = OT_MSG + 23;
    CANNOT_WRITE_EOF                = OT_MSG + 24;

    (*  File close errors.  Will only be reported if everything else okay:  *)
    FILE_CLOSE_ERROR                = OT_MSG + 30;
    CANNOT_CLOSE_TIMELINE_FILE      = FILE_CLOSE_ERROR + 1;
    CANNOT_CLOSE_ONTARGET_FILE      = FILE_CLOSE_ERROR + 2; (*  We ignore this one.  *)
    CANNOT_CLOSE_EITHER_DATA_FILE   = FILE_CLOSE_ERROR + 3;

    (*  Problem with On Target file header:  *)
    CANNOT_READ_ONTARGET_FILE       = OT_MSG + 49;

    (*  File content errors:  *)
    CONTENT_ERROR_RESOURCES         = OT_MSG + 63;
    CONTENT_ERROR_TASKS_DUR         = OT_MSG + 64;
    CONTENT_ERROR_TASKS_FIX         = OT_MSG + 65;
    CONTENT_ERROR_TASKS_SCALE       = OT_MSG + 66;
    CONTENT_ERROR_TASKS_ASSIGN      = OT_MSG + 67;
    CONTENT_ERROR_EDGES_TYPE        = OT_MSG + 70;
    CONTENT_ERROR_EDGES_LAG         = OT_MSG + 71;
    CONTENT_ERROR_EDGES_SCALE       = OT_MSG + 72;
    CONTENT_ERROR_ONTARGET_FILE     = OT_MSG + 80;


    (*  Error messages:  *)

    CantCreateTLFile                = 1;
    CantOpenOTFile                  = 2;
    NoMemory                        = 3;
    WriteError                      = 4;
    NotValidOTFile                  = 5;
    ContentError                    = 6;
    SeriousOTError                  = 7;

    Ignore                          = 0;






PROCEDURE DoTLOT();
VAR
    F   : File;
    P   : POINTER TO ARRAY [0..99] OF CHAR;
    s   : ARRAY [0..255] OF CHAR;
    ok  : BOOLEAN;
    NewProjectName       : ARRAY [0..MaximumFileNameLength] OF CHAR;
    NewProjectMedia      : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength+2] OF CHAR;
    Path                 : ARRAY [0..MaximumPathNameLength]  OF CHAR;
    Extension            : ARRAY [0..MaximumExtensionLength] OF CHAR;



    PROCEDURE DoOTError(ErrorNum : CARDINAL);

    VAR
        MsgNum : CARDINAL;

    BEGIN
        CASE ErrorNum OF
            
            (*  We forgot to pass either the OT, TL or error log file name:  *)
        |   MISSING_FILENAMES :             FatalError();

            (*  File open or create errors:  *)
        |   CANNOT_OPEN_TIMELINE_FILE :     MsgNum := CantCreateTLFile;

        |   CANNOT_OPEN_ONTARGET_FILE :     MsgNum := CantOpenOTFile;

            (*  Importer ran out of memory:  *)
        |   CANNOT_ALLOCATE_MEMORY    :     MsgNum := NoMemory;

            (*  File write errors:  *)
        |   CANNOT_WRITE_DIRECTORY,
            CANNOT_WRITE_PROJECT,
            CANNOT_WRITE_ENVIRONMENT,
            CANNOT_WRITE_RESOURCES,
            CANNOT_WRITE_TASKS,
            CANNOT_WRITE_DEPENDENCIES,
            CANNOT_WRITE_CALENDAR,
            CANNOT_WRITE_SIGNATURE,
            CANNOT_WRITE_COUNTS,
            CANNOT_WRITE_EOF          :     MsgNum := WriteError;

            (*  This isn't a good sign, but it has no effect on the TL
                file we created.  *)
        |   CANNOT_CLOSE_ONTARGET_FILE:     MsgNum := Ignore;

            (*  File content errors:  *)
        |   CONTENT_ERROR_RESOURCES,
            CONTENT_ERROR_TASKS_DUR,
            CONTENT_ERROR_TASKS_FIX,
            CONTENT_ERROR_TASKS_SCALE,
            CONTENT_ERROR_TASKS_ASSIGN,
            CONTENT_ERROR_EDGES_TYPE,
            CONTENT_ERROR_EDGES_LAG,
            CONTENT_ERROR_EDGES_SCALE,
            CONTENT_ERROR_ONTARGET_FILE:    MsgNum := ContentError;

        ELSE
            MsgNum := SeriousOTError;
        END;

        IF (MsgNum <> Ignore) THEN
            GetMessage(ModuleNumber + MsgNum, s);
            Error(s);
        END;
    END DoOTError;


    PROCEDURE CheckForOTErrors() : BOOLEAN;

    VAR
        i       : CARDINAL;
        Line    : ARRAY [0..9] OF CHAR;
        FileName: ARRAY [0..255] OF CHAR;
        s1      : ARRAY [0..13] OF CHAR;
        ch      : CHAR;
        Result  : CARDINAL;
        Stop    : BOOLEAN;
        Ok      : BOOLEAN;

    BEGIN

        (*  Detect and display On Target import errors.
        
            If there is no error log, there was a disk space or other
            serious error.  If there is an error log, and the error in 
            it is anything other than zero, the import was unsuccessful.  
            
            Returns TRUE if the import was successful; FALSE if there
            were errors.
        *)

        Ok := FALSE;        (*  Assume the worst.  *)

        SetLengthOf(s1, 0);
        SetString(FileName, ErrorLogName);
        IF (PathLookupStart(s1, FileName, s, s1)) THEN
            (*  The error log file exists.  *)
            SetLengthOf(s1, 0);
            IF (RequestFileOpenReadOnly(s1, FileName, s1, F)) THEN
                Reset(F);
                SetRead(F);

                IF (CheckIO(F) = done) THEN

                    i := 0;
                    Stop := FALSE;
                    SetLengthOf(Line, 0);
                    REPEAT
                        ReadChar(F, ch);

                        IF ((CheckIO(F) <> done) OR
                            (ch = EOL) OR
                            (ch = 0C) OR
                            (i >= HIGH(Line))) THEN
                            Stop := TRUE;
                        ELSE
                            INC(i);
                            Line[i] := ch;
                        END;

                    UNTIL (Stop);

                    IF (i > 0) THEN
                        SetLengthOf(Line, i);
                        i := 1;
                        Result := StoC(Line, i);
                        IF (Result <> 0) THEN
                            DoOTError(Result);
                        ELSE
                            Ok := TRUE;         (*  Zero means no error.  *)
                        END;
                    ELSE
                        DoOTError(SERIOUS);     (*  Error file empty.  *)
                    END;

                ELSE
                    (*  Yikes!  What went wrong?  The error log exists, but
                        there's nothing in it.  *)
                    DoOTError(SERIOUS);
                END;

                Close(F);

            END;

        ELSE
            (*  File doesn't exist.  Cause is serious error such as no
                disk space.  *)
            DoOTError(SERIOUS);
        END;

        RETURN (Ok);

    END CheckForOTErrors;



BEGIN
    P  := OverlayContext();

    (*  Remove the existing error log, if there is one.  22-Jul-91 PFG  *)
    Delete(ErrorLogName, F);

    SetString( s, "TLDOS(OT(" );    (* Name of the external importer *)
    ConcatLS(  s, P^ );             (* On Target file name *)
    ConcatS(   s, " ");             (* Separate by a space.  *)
    ConcatS(   s, TempSchedName);   (* output (temp) name 24-Jun-91 RSC  *)
    ConcatS(   s, " ");             (* Separate by a space.  *)
    ConcatS(   s, ErrorLogName);    (* error log file name 22-Jul-91 PFG *)
    ConcatS(   s, "))" );
    ok := OverlayPackage( s );

    IF (ok AND CheckForOTErrors()) THEN     (* 22-Jul-91 PFG *)
        P^[1] := "1";           (* no errors *)

        (*  This is a bit of a kludge, but...even though the OT schedules
            all come in with When set to ManualCalc, the LoadAFile proc checks
            to see if AutoCalc is on AND Levelling is on before we've had a
            chance to actually load the newly created schedule, so we need to
            set it to manual here, too.  *)
        CalculationState[Scheduling].When := ManualCalc;
    ELSE
        (*  Discontinue processing.  Don't try to load schedule.  *)
        PackageOK := FALSE;

        ExtractFileNameParts( P^, NewProjectMedia, Path, NewProjectName, Extension );
        ConcatLS( NewProjectMedia, Path );
        (*  Update the global versions of the project name and media so that
            UnLockSchedule will delete the temporary files.  *)
        Copy( NewProjectMedia, ProjectMedia );
        Copy( NewProjectName,  ProjectName  );
        UnLockSchedule(DualLock);
        ProjectName[0] := 0C;

        (*  Notify caller that schedule was not loaded AND we don't want 
            errors displayed.  *)
        P^[1] := "2";
    END;
    
END DoTLOT;




BEGIN

    DoTLOT();

END TLOT.

