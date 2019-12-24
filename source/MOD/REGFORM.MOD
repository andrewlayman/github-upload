IMPLEMENTATION MODULE RegForm;

(*  =========================================================================
    Last Edit : October 23, 1990 3:32PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        RegForm - Code that actually brings up the Login form and checks
                  the master file
        

    MODIFICATION HISTORY:

       20-Jun-89 WKH    Initial version
       25-Jun-89 WKH    Remove trailing blanks from UserName.
                        Add actual username validation.
       27-Jun-89 WKH    Don't allow access if $m$ file isn't found.
                        Have different message for blank user name.
                        Update UserSerialNumber correctly.
                        Update ProducnName correctly.
       01-Jul-89 WKH    Update UserName and serial number correctly for
                        single user versions.
                        Also peform semaphore file lock. 
       02-Jul-89 WKH    Put msgs into phrases.
       03-Jul-89 WKH    Clean up structure.
       06-Jul-89 WKH    Use new LockUser routine from Registry
       11-Jul-89 WKH    Add feature to support a USER= cmdline parm that 
                        allows specification of the username on the cmdline.
       22-Sep-89 WKH    Make me smart about reading from a file that is being
                        updated.
       25-Sep-89 WKH    TrimFront the UserName 
       13-Nov-89 RSC    Change BTStorage to Space.
       29-Nov-89 WKH    Now, if a user is already logged on, we give them a
                        chance to enter a different user name.
        3-Oct-90 DSL    Changed $'s to %'s in filenames for Unix.
       23-Oct-90 RSC    Changed %'s to 4's in filenames for Dos batch.
    =========================================================================
*)

FROM Clock                  IMPORT  
    (* PROC *)                  Delay;

FROM Codes                  IMPORT 
                                ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ABoxHandle,
    (* PROC *)                  Error, Burp, FatalError,ProgressBox, 
                                ReleaseBox;

FROM FileAux                IMPORT
    (* VAR  *)                  EXEPath;

FROM FileOpen               IMPORT
                                RequestFileOpenReadOnly;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, AFileAccessRight, AFileAccessRightSet,
    (* PROC *)                  Close;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
    (* PROC *)                  DoForm, NullCheckProc;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM GaGa                   IMPORT
    (* PROC *)                  GetGaGaMessage;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, VersionStringLength,
                                BreakRequested;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey;

FROM LANFile                IMPORT
    (* TYPE *)                  AUserRecord,
    (* PROC *)                  StartLANFileInput, SearchLANFile,
                                ReadLANFileRecord;

FROM Locks                  IMPORT
    (* TYPE *)                  AFileLockResult,
    (* PROC *)                  LockFile, UnLockFile;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, ConcatLS, ConcatS, Copy, TrimRear,
                                LStringToTString, LengthOf, SetLengthOf,
                                TStringToLString, Insert, Upshift, TrimFront;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  InstallNewProcedure;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;

IMPORT Registry;

FROM Registry               IMPORT
    (* CONST *)                 QProductPermission,
    (* TYPE *)                  ARegistryProc, ARegistryDataRecord,
    (* VAR  *)                  GetRegistryInfo, UserSerialNumber, LockUser;

FROM Schedule               IMPORT
    (* VAR *)                   CurrentFileExtension;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;




CONST
    ModuleNumber            = 7500;
    FormID                  = 67;
    FormWidth               = 55;
    FormHeight              = 7;

    (* FormValue indexes *)
    UNAM                    = 0;

    (* Phrases offsets   *)
    BadUserNameMsg          = 0;
    GetBumpDiskMsg          = 1;
    MUserPathMsg            = 2;
    BlankUserNameMsg        = 3;
    AlreadyLoggedOnMsg      = 4;
    NoRightsMsg1            = 5;
    NoRightsMsg2            = 6;
    UnknownErrorMsg1        = 7;
    UnknownErrorMsg2        = 8;
    LANFileCorruptedMsg     = 9;
    BadLANFileMsg           = 10;
    WaitMsg                 = 11;
    OpenErrorMsg            = 12;

    SleepTime               = 500;  (* 5 seconds *)

VAR
    MasterFilePath          : ARRAY [0..99] OF CHAR;
    MasterFileName          : ARRAY [0..13] OF CHAR;
    LocalSerialNumber       : ARRAY [0..VersionStringLength+1] OF CHAR;
    UserRecord              : AUserRecord;
    OldRegistryProc         : ARegistryProc;
    Strikes                 : CARDINAL;
    f                       : File;
    EarlyExit               : BOOLEAN;
    BoxShowing              : BOOLEAN;
    StatusBox               : ABoxHandle;
    Registration            : BOOLEAN;


PROCEDURE PanicButtonPressed() : BOOLEAN;

VAR
    Result              : BOOLEAN;

BEGIN
    IF (BreakRequested()) THEN
        Result       := TRUE;
        Registration := FALSE;
        EarlyExit    := TRUE;
    ELSE
        Result       := FALSE;
        EarlyExit    := FALSE;
    END;

    RETURN Result;
END PanicButtonPressed;


PROCEDURE CheckForm (    Form        : AForm;
                         FieldNo     : AFieldNo;
                     VAR FormValue   : ARRAY OF AFieldValue;
                         CheckReason : ACheckReason;
                     VAR Code        : CARDINAL ):BOOLEAN;

CONST
    StrikeLimit             = 3;

VAR
    CodeIn                  : CARDINAL;
    i                       : CARDINAL;
    NumUsers                : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..255]  OF CHAR;
    FName                   : ARRAY [0..79]  OF CHAR;
    LooksGood               : BOOLEAN;
    LockResult              : AFileLockResult;

BEGIN
    CodeIn    := Code;
    Code      := 0;
    LooksGood := TRUE;
    EarlyExit := FALSE;

    CASE CheckReason OF
        CheckFormEntry   :

    |   CheckFormExit    :
            IF (FieldNo = UNAM) THEN
                TrimRear(FormValue[UNAM].CharValue^);
                TrimFront(FormValue[UNAM].CharValue^);  (* 25-Sep-89 WKH  *)


                Copy(MasterFilePath, FName);
                ConcatLS(FName, MasterFileName);
                LStringToTString(FName, FName);


                LOOP
                    LockResult := LockFile(FName, f, AFileAccessRightSet{BTSLocked});

                    IF (LockResult = ReadLock) THEN
                        IF (BoxShowing) THEN
                            BoxShowing := FALSE;
                            ReleaseBox(StatusBox);
                        END;

                        IF (StartLANFileInput(f, NumUsers)) THEN
                            IF (LengthOf(FormValue[UNAM].CharValue^) > 0) THEN
                                LStringToTString(FormValue[UNAM].CharValue^, s);

                                IF (NOT SearchLANFile(f, s, UserRecord)) THEN
                                    INC(Strikes);
                                    IF (Strikes >= StrikeLimit) THEN
                                        LooksGood := TRUE;
                                    ELSE
                                        Copy(FormValue[UNAM].CharValue^, s);
                                        ConcatMessage(s, ModuleNumber + BadUserNameMsg);
                                        Error(s); (* invalid user msg *)
                                        LooksGood := FALSE;
                                    END;
                                ELSE    
                                    FOR i := 0 TO (VersionStringLength - 1) DO
                                        LocalSerialNumber[i+1] := UserRecord.SerialNumber[i];
                                    END;
                                    LocalSerialNumber[0] := CHR(VersionStringLength);
                                    TrimRear(LocalSerialNumber);
                                END;
                            ELSE
                                INC(Strikes);
                                IF (Strikes >= StrikeLimit) THEN
                                    LooksGood := TRUE;
                                ELSE
                                    GetMessage(ModuleNumber + BlankUserNameMsg, s);
                                    Error(s);
                                    LooksGood := FALSE;
                                END;
                            END;
                        ELSE
                            GetMessage(ModuleNumber + LANFileCorruptedMsg, s);
                            Error(s);
                            LooksGood := FALSE;
                        END;
                        UnLockFile(f);
                        EXIT;

                    ELSIF (LockResult = AlreadyLocked) THEN
                        (* Wait period *)
                        IF (NOT BoxShowing) THEN
                            BoxShowing := TRUE;
                            GetMessage(ModuleNumber + WaitMsg, s2);
                            StatusBox  := ProgressBox(s2);
                        END;

                        Delay(SleepTime, PanicButtonPressed);

                        IF (EarlyExit) THEN
                            EXIT;
                        END;
                    ELSE
                        (* SBT *)
                        IF (BoxShowing) THEN
                            BoxShowing := FALSE;
                            ReleaseBox(StatusBox);
                        END;
                        GetMessage(ModuleNumber + OpenErrorMsg, s2);
                        Error(s2);
                        Registration := FALSE;
                        EXIT;
                    END;
                END; (* LOOP *)
            END;
    |   CheckFieldEntry  :

    |   CheckFieldChange :

    |   CheckFieldExit   :

    |   CheckFieldKey    :

    ELSE
        FatalError();
    END;

    RETURN LooksGood;

END CheckForm;


PROCEDURE OurRegistryProc( VAR UserName    : ARRAY OF CHAR;
                           VAR ProductName : ARRAY OF CHAR;
                               InfoRequest : CARDINAL;
                           VAR ReturnValue : ARegistryDataRecord
                         ) : BOOLEAN;

VAR
    NumUsers                : CARDINAL;
    i                       : CARDINAL;
    Code                    : ACode;
    LockResult              : AFileLockResult;
    Priveleges              : AFileAccessRightSet;
    Found                   : BOOLEAN;
    FormValue               : ARRAY [0..UNAM] OF AFieldValue;
    s                       : ARRAY [0..255]  OF CHAR;
    s2                      : ARRAY [0..255]  OF CHAR;
    FName                   : ARRAY [0..79]   OF CHAR;

    
    PROCEDURE StartUserSession() : BOOLEAN;

    VAR
        Registration        : BOOLEAN;

    BEGIN
        Registration := TRUE;

        (* go for the lock *)

        (* get real path *)
        TStringToLString(UserRecord.UniqueFName, s);

        Insert(s, MasterFilePath, 1);

        LockResult := LockUser(UserName, s);

        (* add more result checking *)
        CASE LockResult OF
            FullLock :
                (* do nothing *)
            
        |   AlreadyLocked,
            ReadLock :
                Copy(UserName, s);
                ConcatMessage(s, ModuleNumber + AlreadyLoggedOnMsg);
                Error(s);
                Registration := FALSE;

        |   UnLockable :
                GetMessage(ModuleNumber + NoRightsMsg1, s); (* Unable to establish session for *)
                ConcatLS(s, UserName);
                ConcatMessage(s, ModuleNumber + NoRightsMsg2);
                Error(s);
                Registration := FALSE;

        ELSE
            GetMessage(ModuleNumber + UnknownErrorMsg1, s);
            ConcatLS(s, UserName);
            ConcatMessage(s, ModuleNumber + UnknownErrorMsg2);
            Error(s);
            Registration := FALSE;
        END;

        RETURN Registration;
    END StartUserSession;

BEGIN
    IF (InfoRequest = QProductPermission) THEN
        Strikes    := 0;
        BoxShowing := FALSE;

        Copy(EXEPath, MasterFilePath);
        ConcatMessage(MasterFilePath, ModuleNumber + MUserPathMsg);

        Copy(ProductName, MasterFileName);
        ConcatS(MasterFileName, ".%M%");

            (* 23-Oct-90 RSC Make into ".4M4" or whatever.
            *)
        i := LengthOf( MasterFileName );
        MasterFileName[ i - 2 ] := CurrentFileExtension[2]; (* ".4T0" *)
        MasterFileName[ i     ] := CurrentFileExtension[2]; (* ".4T0" *)


        (* assume the worst *)
        Registration := FALSE;  (* 27-Jun-89 WKH *)

        Copy(MasterFilePath, FName);
        ConcatLS(FName, MasterFileName);

        LStringToTString(FName, FName);

        LOOP
            LockResult := LockFile(FName, f, AFileAccessRightSet{BTSLocked});

            IF (LockResult = ReadLock) THEN
                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;

                IF (StartLANFileInput(f, NumUsers)) THEN

                    GetGaGaMessage(ModuleNumber, s2);  (* USER *)

                    GetOption(s2, Found, s);

                    IF (Found AND (NumUsers > 1)) THEN
                        Upshift(s);

                        LStringToTString(s, s);
                        IF (NOT SearchLANFile(f, s, UserRecord)) THEN
                            TStringToLString(s, s);
                            ConcatMessage(s, ModuleNumber + BadUserNameMsg);
                            Error(s); (* invalid user msg *)
                            Registration := FALSE;
                        ELSE    
                            FOR i := 0 TO (VersionStringLength - 1) DO
                                LocalSerialNumber[i+1] := 
                                    UserRecord.SerialNumber[i];
                            END;
                            LocalSerialNumber[0] := CHR(VersionStringLength);
                            TrimRear(LocalSerialNumber);
                            Copy(LocalSerialNumber, UserSerialNumber);
                            Copy(ProductName, Registry.ProductName);
                            TStringToLString(s, UserName);
                            Registration := StartUserSession();
                            IF Registration THEN
                                Close(f);
                            END;
                        END;
                    END;

                    IF (NOT Registration) THEN
                        IF (NumUsers > 1) THEN

                            Close(f);
                            NEW(FormValue[UNAM].CharValue);

                            Copy(UserName, FormValue[UNAM].CharValue^);

                            Code := DoForm((maxcol - FormWidth) DIV 2, 
                                            0, 
                                            maxcol, 
                                            maxrow - ((maxrow - FormHeight) DIV 2),
                                            FormID, 
                                            TRUE, 
                                            FormValue, 
                                            CheckForm);

                            IF ((Code = CancelKey) OR (Strikes >= 3)) THEN
                                GetMessage(ModuleNumber + GetBumpDiskMsg, s);
                                Error(s);    
                            ELSE
                                TrimRear(ProductName);
                                Copy(ProductName, Registry.ProductName);
                                Copy(FormValue[UNAM].CharValue^, UserName);
                                Copy(LocalSerialNumber, UserSerialNumber);
                                Registration := StartUserSession();
                            END;

                            DISPOSE(FormValue[UNAM].CharValue);

                        ELSIF (NumUsers = 1) THEN (* 1-Jul-89 WKH *)

                            IF (NOT ReadLANFileRecord(f, 0, UserRecord)) THEN
                                Registration := FALSE;
                                GetMessage(ModuleNumber + BadLANFileMsg, s);
                                Error(s);
                            ELSE
                                TStringToLString(UserRecord.UserName, UserName);

                                FOR i := 0 TO (VersionStringLength - 1) DO
                                    LocalSerialNumber[i+1] := 
                                                UserRecord.SerialNumber[i];
                                END;

                                LocalSerialNumber[0] := CHR(VersionStringLength);
                                TrimRear(LocalSerialNumber);
                                Copy(LocalSerialNumber, UserSerialNumber);
                                Copy(ProductName, Registry.ProductName);
                                Registration := StartUserSession();
                            END;

                            UnLockFile(f);
                        ELSE
                            FatalError();
                        END;
                    END;
                ELSE
                    GetMessage(ModuleNumber + LANFileCorruptedMsg, s);
                    Error(s);
                END;

                Close(f);
                EXIT;

            ELSIF (LockResult = AlreadyLocked) THEN
                (* Wait period *)
                IF (NOT BoxShowing) THEN
                    BoxShowing := TRUE;
                    GetMessage(ModuleNumber + WaitMsg, s2);
                    StatusBox  := ProgressBox(s2);
                END;

                Delay(SleepTime, PanicButtonPressed);

                IF (EarlyExit) THEN
                    EXIT;
                END;
            ELSE
                (* SBT *)
                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;
                GetMessage(ModuleNumber + OpenErrorMsg, s2);
                Error(s2);
                Registration := FALSE;
                EXIT;
            END;
        END;  (* LOOP *)
    ELSE
        Registration := OldRegistryProc(UserName, ProductName, InfoRequest,
                                        ReturnValue);
    END;

    RETURN Registration;
END OurRegistryProc;


PROCEDURE InitRegistryForm();

BEGIN
    InstallNewProcedure(ADR(GetRegistryInfo), PROC(OurRegistryProc), ADR(OldRegistryProc));
END InitRegistryForm;

BEGIN
END RegForm.
