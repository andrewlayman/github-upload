IMPLEMENTATION MODULE RegSimultaneous;

(*  =========================================================================
    Last Edit : May 22, 1991 1:43PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        RegSimultaneous - Handles registration of network users using a
                          simultaneous user counter scheme.  Based on
                          RegForm module.  Also, we don't use the
                          serial number in the lan file anymore.  The 
                          serial number etched in the EXE is now king (or
                          queen as the case may be).

    MODIFICATION HISTORY:

       07-Sep-90 WKH    Initial version
       05-Nov-90 RSC    Parameterized for "$".
       17-Apr-91 RSC    Check for proper version of Time Line.
                        This includes checking that the serial number's
                        checksumms are both valid.   Heh, heh, heh.
       22-May-91 PFG    Separate file access errors from too-many-files 
                        errors.
       10-Jul-91 TGS    Set UserSerialNumber to UserRecord.SerialNumber
                        instead of VersionString, which has a garbage
                        character and isn't as useful to look at besides.
    =========================================================================
*)

FROM Clock                  IMPORT  
    (* PROC *)                  Delay;

FROM CRC16                  IMPORT
    (* PROC *)                  CheckSum;

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

FROM GaGa                   IMPORT
    (* PROC *)                  GetGaGaMessage;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow,
    (* VARS  *)                 VersionString, BreakRequested;

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
                                TStringToLString, Insert, Upshift, TrimFront,
                                StringsEqual;

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
    (* VAR  *)                  CurrentFileExtension;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

CONST
    ModuleNumber            = 14100;

    (* Phrases offsets   *)
    NoMoreUsersMsg          = 0;
    MUserPathMsg            = 1;
    UnknownErrorMsg1        = 2;
    LANFileCorruptedMsg     = 3;
    BadLANFileMsg           = 4;
    WaitMsg                 = 5;
    OpenErrorMsg            = 6;
    BadSerialNumbersMsg     = 7;
    NoAccessMsg             = 8;

    SleepTime               = 500;  (* 5 seconds *)


    VersionDigit            = 27;   (* 17-Apr-91 RSC  *)

VAR
    MasterFilePath          : ARRAY [0..99] OF CHAR;
    MasterFileName          : ARRAY [0..13] OF CHAR;
    UserRecord              : AUserRecord;
    OldRegistryProc         : ARegistryProc;
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


PROCEDURE OurRegistryProc( VAR UserName    : ARRAY OF CHAR;
                           VAR ProductName : ARRAY OF CHAR;
                               InfoRequest : CARDINAL;
                           VAR ReturnValue : ARegistryDataRecord
                         ) : BOOLEAN;

VAR
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..255]  OF CHAR;
    NumUsers                : CARDINAL;
    i                       : CARDINAL;
    LockResult              : AFileLockResult;
    Priveleges              : AFileAccessRightSet;
    FName                   : ARRAY[0..79] OF CHAR;
    BadSerialNumbers,
    Found                   : BOOLEAN;

    
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
            ReadLock,
            UnLockable :
                Registration := FALSE;

        ELSE
            GetMessage(ModuleNumber + UnknownErrorMsg1, s);
            Error(s);
            Registration := FALSE;
        END;

        RETURN Registration;
    END StartUserSession;

BEGIN
    IF (InfoRequest = QProductPermission) THEN
        BoxShowing := FALSE;

        Copy(EXEPath, MasterFilePath);
        ConcatMessage(MasterFilePath, ModuleNumber + MUserPathMsg);

        Copy(ProductName, MasterFileName);
        ConcatS(MasterFileName, ".$M$");
        i := LengthOf(MasterFileName);
        MasterFileName[i]   := CurrentFileExtension[2]; (* 5-Nov-90 RSC  *)
        MasterFileName[i-2] := CurrentFileExtension[2]; (* 5-Nov-90 RSC  *)


        (* assume the worst *)
        Registration := FALSE;  (* 27-Jun-89 WKH *)

        Copy(MasterFilePath, FName);
        ConcatLS(FName, MasterFileName);

        LStringToTString(FName, FName);

        BadSerialNumbers := FALSE;  (* 17-Apr-91 RSC  *)
        LOOP
            LockResult := LockFile(FName, f, AFileAccessRightSet{BTSLocked});

            IF (LockResult = ReadLock) THEN
                IF (BoxShowing) THEN
                    BoxShowing := FALSE;
                    ReleaseBox(StatusBox);
                END;

                IF (StartLANFileInput(f, NumUsers)) THEN

                    i := 0;
                    WHILE (i < NumUsers) AND (NOT Registration) DO
                        IF (NOT ReadLANFileRecord(f, i, UserRecord)) THEN
                            Registration := FALSE;
                            GetMessage(ModuleNumber + BadLANFileMsg, s);
                            Error(s);


                                (* RSC 17-Apr-91:

                                    Check for the version that applies to us.
                                    Customers can mix and match within a file
                                    (although they have to rename the file
                                    to $M$ or 5M5), but we only take numbers
                                    that apply to this version.
                                *)
                        ELSIF (UserRecord.SerialNumber[ VersionDigit ] = 
                               CurrentFileExtension[2]) THEN
                            TStringToLString( UserRecord.SerialNumber, s );
                            IF (CheckSerialNumber( s )) THEN
                                Registration := StartUserSession();
                            ELSE
                                BadSerialNumbers := TRUE;
                            END;
                        ELSE
                            BadSerialNumbers := TRUE;
                        END;
                        INC(i);
                    END;

                    IF Registration THEN
                        GetGaGaMessage(7500, s2);  (* USER *) (* WKH - Had to hard code the module number from RegForm *)

                        GetOption(s2, Found, s);

                        IF Found THEN
                            Upshift(s);
                            Copy(s, UserName);
                        ELSE
                            SetLengthOf(UserName, 0);
                        END;

                        TStringToLString(UserRecord.SerialNumber, UserSerialNumber); (* 10-Jul-91 TGS *)
                        Copy(ProductName, Registry.ProductName);
                    ELSE
                        IF (BadSerialNumbers) THEN
                            GetMessage(ModuleNumber + BadSerialNumbersMsg, s);
                        ELSE
                            (* 22-May-91 PFG  Distinguish file access error 
                                              from too-many-files error.  *)
                            IF (LockResult = UnLockable) THEN
                                GetMessage(ModuleNumber + NoAccessMsg, s);                                
                            ELSE
                                GetMessage(ModuleNumber + NoMoreUsersMsg, s);
                            END;
                        END;
                        Error(s);
                    END;
                ELSE
                    GetMessage(ModuleNumber + LANFileCorruptedMsg, s);
                    Error(s);
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

                (* Sleep for a while and try to lock master file again *)
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











(* In - RawNumber, in LString form, is the serial number with junk for
                   the checksum.
   Out - FinishedNumber, in LString form, is the checksummed serial number.
*)
PROCEDURE BuildSerialNumber( VAR RawNumber, FinishedNumber : ARRAY OF CHAR );
VAR
    Swapper         : ARRAY [0..29] OF CHAR;

    PROCEDURE DoSum( Length : CARDINAL ) : CARDINAL;
    VAR
        i               : CARDINAL;
        AllButChecksum  : ARRAY [0..31] OF CHAR;
    BEGIN
        FOR i := 1 TO Length DO
            AllButChecksum[i] := FinishedNumber[ORD(Swapper[i]) - (ORD("A") - 1)];
        END;

        RETURN CheckSum( ADR(AllButChecksum[1]), Length );

    END DoSum;


    PROCEDURE Cto3inS( C, Where : CARDINAL );
    VAR
        D,
        i     : CARDINAL;
    BEGIN

            (* Put out the number modulo 1000 into the string at Where.
            *)
        FOR i := 1 TO 3 DO
            D := C MOD 10;
            C := C DIV 10;
            FinishedNumber[ Where + 3 - i ] := CHR(D + ORD("0"));
        END;

    END Cto3inS;

BEGIN
    SetString(Swapper,"AJKOBLMDEINCFGPQUVWYX\]Z[^H"); (* Transmogrification table *)

    Copy(RawNumber, FinishedNumber);

    Cto3inS( DoSum(12), 6 );

    Cto3inS( DoSum(27), 18 );

END BuildSerialNumber;





(* Check the serial number for validity, if it is ok, return TRUE.
*)
PROCEDURE CheckSerialNumber( VAR CheckThis : ARRAY OF CHAR ) : BOOLEAN;
VAR
    AgainstThis : ARRAY [0..31] OF CHAR;
BEGIN
    BuildSerialNumber( CheckThis, AgainstThis );

    RETURN StringsEqual( CheckThis, AgainstThis );

END CheckSerialNumber;










PROCEDURE InitRegistrySimultaneous();

BEGIN
    InstallNewProcedure(ADR(GetRegistryInfo), PROC(OurRegistryProc), ADR(OldRegistryProc));
END InitRegistrySimultaneous;

BEGIN
END RegSimultaneous.

