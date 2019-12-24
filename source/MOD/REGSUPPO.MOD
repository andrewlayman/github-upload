IMPLEMENTATION MODULE RegSupport;

(*  =========================================================================
    Last Edit : October 23, 1990 3:37PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        RegSupport - Bulk of the Registry code for use by overlays.
        

    MODIFICATION HISTORY:

       08-Jun-89 WKH    Initial version
       19-Jun-89 WKH    Add support for QProductPermission call
       20-Jun-89 WKH    Moved code that brought up Login form to module
                        RegForm and just do non-form based support here.
       26-Jun-89 WKH    Add ModuleNumber, oops!!
       27-Jun-89 WKH    Add code to switch from actual TL serial num and
                        User's serial num.  Also, if product names don't
                        match, then must be a new product trying to
                        register itself, so go out and try to get new
                        serial number from file.
       05-Jul-89 WKH    Always get info from UserSerialNumber instead
                        of VersionString.  Theory is that UserSerialNumber
                        should ALWAYS be set up correctly before TL can run.
       21-Sep-89 WKH    Make us smart about the possibility that the master
                        file is being updated while we are trying to read it.
       25-Sep-89 WKH    Return lesser of two values for ProductType and
                        ProductCapacity.
       13-Nov-89 RSC    Removed references to BTStorage.
        3-Oct-90 DSL    Changed $'s to %'s in filenames for Unix 
                        compatability
       23-Oct-90 RSC    Changed %'s to 4's in filenames for Dos batch.
    =========================================================================
*)

FROM Clock                  IMPORT  
    (* PROC *)                  Delay;

FROM Codes                  IMPORT 
                                ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ABoxHandle,
    (* PROC *)                  Error, Burp, FatalError, ProgressBox,
                                ReleaseBox;

FROM FileAux                IMPORT
    (* VAR  *)                  EXEPath;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, AFileAccessRight, AFileAccessRightSet,
    (* PROC *)                  Close;

FROM Kbio                   IMPORT
    (* CONST*)                  maxcol, VersionStringLength,
    (* VAR  *)                  maxrow, VersionString,
    (* PROC *)                  BreakRequested;

FROM LANFile                IMPORT
    (* TYPE *)                  AUserRecord,
    (* PROC *)                  StartLANFileInput, SearchLANFile;

FROM Locks                  IMPORT
    (* TYPE *)                  AFileLockResult,
    (* PROC *)                  LockFile, UnLockFile;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, ConcatLS, ConcatS, Copy, SubStr,
                                StoC, StringsEqual, LengthOf, TrimRear,
                                Upshift, LStringToTString;

FROM MagicNum               IMPORT
    (* CONST *)                 IsStringValue, IsCardValue;

FROM MsgFile                IMPORT
    (* PROC *)                  ConcatMessage, GetMessage;

FROM Overlays               IMPORT
    (* PROC *)                  InstallNewProcedure;

IMPORT Registry;

FROM Registry               IMPORT
    (* CONST *)                 QProductSerial, QProductType, QCapacity,
                                QProductEquivalence, QProductGroup,
                                QProductMajorRelease, QProductSubRelease,
                                QProductSequence, QProductCountry,
                                QProductSecretInfo, QProductPermission,
    (* TYPE *)                  ARegistryProc, ARegistryDataRecord,
    (* VAR  *)                  GetRegistryInfo, ProductName, UserName,
                                UserSerialNumber;

FROM Schedule               IMPORT
    (* VAR *)                   CurrentFileExtension;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

CONST
    ModuleNumber            = 7800;

    OfsProductGroup         = 0;
    LenProductGroup         = 2;
    OfsProductSubRelease    = 8;
    LenProductSubRelease    = 2;
    OfsProductSequence      = 10;
    LenProductSequence      = 5;
    OfsProductCountry       = 22;
    LenProductCountry       = 2;
    OfsProductSecretInfo    = 24;
    LenProductSecretInfo    = 1;
    OfsProductType          = 25;
    LenProductType          = 1;
    OfsProductCapacity      = 26;
    LenProductCapacity      = 1;
    OfsProductEquivalence   = 27;
    LenProductEquivalence   = 3;


    MUserPathMsg            = 0;
    WaitMsg                 = 1;
    ErrorOpeningMsg         = 2;

    SleepTime               = 500;  (* 5 seconds *)

VAR
    OldRegistryProc         : ARegistryProc;
    Registration            : BOOLEAN;
    EarlyExit               : BOOLEAN;


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
    i                       : CARDINAL;
    NumUsers                : CARDINAL;
    BaseValue               : CARDINAL;
    UserValue               : CARDINAL;
    Code                    : ACode;
    StatusBox               : ABoxHandle;
    UserRecord              : AUserRecord;
    f                       : File;
    LockResult              : AFileLockResult;
    BoxShowing              : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..255] OF CHAR;
    CurrentProductName      : ARRAY [0..8]   OF CHAR;
    NewProductName          : ARRAY [0..8]   OF CHAR;


    PROCEDURE TwoToThe(n    : CARDINAL) : CARDINAL;

    VAR
        i                   : CARDINAL;
        ReturnVal           : CARDINAL;

    BEGIN
        ReturnVal := 1;
        FOR i := 1 TO n DO
            ReturnVal := ReturnVal * 2;
        END;

        RETURN(ReturnVal);
    END TwoToThe;

    PROCEDURE Min(i, j : CARDINAL) : CARDINAL;

    VAR
        k                   : CARDINAL;

    BEGIN
        k := j;
        IF (i < j) THEN
            k := i;
        END;

        RETURN (k);
    END Min;

BEGIN

    Registration := TRUE;
    BoxShowing   := FALSE;
    EarlyExit    := FALSE;

    IF ((NOT StringsEqual(UserName, Registry.UserName)) AND
        (InfoRequest <> QProductPermission)) THEN
        Registration := FALSE;
    END;

    IF (Registration) THEN
        Copy(ProductName, NewProductName);
        Copy(Registry.ProductName, CurrentProductName);

        TrimRear(NewProductName);
        TrimRear(CurrentProductName);


        IF ( (LengthOf(NewProductName)     = 0) OR 
            (LengthOf(CurrentProductName) = 0) ) THEN
            Registration := FALSE;
            FatalError();
        ELSE
            Upshift(NewProductName);
            Upshift(CurrentProductName);

            IF (NOT StringsEqual(NewProductName, CurrentProductName)) THEN
            
                (* Go get serial Number *)

                Copy(EXEPath, s);
                ConcatMessage(s, ModuleNumber + MUserPathMsg);
                ConcatLS(s, NewProductName);
                ConcatS(s, ".%M%");

                    (* 23-Oct-90 RSC Make into ".4M4" or whatever.
                    *)
                i := LengthOf( s );
                s[ i - 2 ] := CurrentFileExtension[2]; (* ".4T0" *)
                s[ i     ] := CurrentFileExtension[2]; (* ".4T0" *)


                (* assume the worst *)
                Registration := FALSE;  (* 27-Jun-89 WKH *)

                LStringToTString(s, s);

                LOOP
                    LockResult := LockFile(s, f, AFileAccessRightSet{BTSLocked});

                    IF (LockResult = ReadLock) THEN
                        IF (BoxShowing) THEN
                            BoxShowing := FALSE;
                            ReleaseBox(StatusBox);
                        END;

                        IF (StartLANFileInput(f, NumUsers)) THEN
                            IF (NumUsers > 0) THEN
                                IF (SearchLANFile(f, UserName, UserRecord)) THEN
                                    Registration := TRUE;

                                    FOR i := 0 TO (VersionStringLength - 1) DO
                                        UserSerialNumber[i+1] := 
                                            UserRecord.SerialNumber[i];
                                    END;

                                    UserSerialNumber[0] := CHR(VersionStringLength);
                                    TrimRear(UserSerialNumber);
                                    Copy(UserName, Registry.UserName);
                                    Copy(NewProductName, Registry.ProductName);
                                END;
                            ELSE
                                FatalError();  (* NumUsers = 0 *)
                            END;
                        ELSE
                            (* LANFile corrupted msg *)
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
                        GetMessage(ModuleNumber + ErrorOpeningMsg, s2);
                        Error(s2);
                        Registration := FALSE;
                        EXIT;
                    END;
                END; (* LOOP *)
            END;
        END;
    END;

    IF (BoxShowing) THEN
        BoxShowing := FALSE;
        ReleaseBox(StatusBox);
    END;

    IF (Registration) THEN
        CASE InfoRequest OF
            QProductSerial       :
                ReturnValue.DataType := IsStringValue;
                Copy(UserSerialNumber, ReturnValue.StringValue);

        |   QProductType         :
                ReturnValue.DataType      := IsCardValue;
                BaseValue                 := 
                    ORD(VersionString[OfsProductType+1]) - ORD("0");
                UserValue                 := 
                    ORD(UserSerialNumber[OfsProductType+1]) - ORD("0");
                ReturnValue.CardinalValue := Min(BaseValue, UserValue);

        |   QCapacity            :
                ReturnValue.DataType      := IsCardValue;
                BaseValue                 :=
                    ORD(VersionString[OfsProductCapacity+1]) - ORD("0");
                UserValue                 :=
                    ORD(UserSerialNumber[OfsProductCapacity+1]) - ORD("0");

                ReturnValue.CardinalValue := Min(BaseValue, UserValue);

                IF (ReturnValue.CardinalValue = 9) THEN (* TL thinks that 0 *)
                    ReturnValue.CardinalValue := 0;     (* means unlimited  *)
                ELSE
                    ReturnValue.CardinalValue := 
                        TwoToThe(ReturnValue.CardinalValue + 5);
                END;

        |   QProductEquivalence  :
                ReturnValue.DataType := IsStringValue;
                SubStr(UserSerialNumber, ReturnValue.StringValue,
                       OfsProductEquivalence + 1, LenProductEquivalence);

        |   QProductGroup        :
                ReturnValue.DataType := IsStringValue;
                SubStr(UserSerialNumber, ReturnValue.StringValue,
                       OfsProductGroup + 1, LenProductGroup);
            
        |   QProductMajorRelease :
                ReturnValue.DataType      := IsCardValue;
                ReturnValue.CardinalValue := 
                    ORD(UserSerialNumber[OfsProductEquivalence+3]) - ORD("0");

        |   QProductSubRelease   :
                ReturnValue.DataType      := IsCardValue;
                SubStr(UserSerialNumber, s, OfsProductSubRelease+1,
                       LenProductSubRelease);
                ReturnValue.CardinalValue := StoC(s, i);

        |   QProductSequence     :
                ReturnValue.DataType      := IsCardValue;
                SubStr(UserSerialNumber, s, OfsProductSequence+1,
                       LenProductSequence);
                ReturnValue.CardinalValue := StoC(s, i);

        |   QProductCountry      :
                ReturnValue.DataType := IsStringValue;
                SubStr(UserSerialNumber, ReturnValue.StringValue,
                       OfsProductCountry + 1, LenProductCountry);

        |   QProductSecretInfo   :
                ReturnValue.DataType      := IsCardValue;
                ReturnValue.CardinalValue := 
                    ORD(UserSerialNumber[OfsProductSecretInfo+3]) - ORD("0");

        |   QProductPermission   :

        ELSE
            Registration := OldRegistryProc(UserName, 
                                            ProductName, 
                                            InfoRequest,
                                            ReturnValue);
        END;
    END;

    RETURN Registration;
END OurRegistryProc;


PROCEDURE InitRegistrySupport();

BEGIN
    InstallNewProcedure(ADR(GetRegistryInfo), PROC(OurRegistryProc), ADR(OldRegistryProc));
END InitRegistrySupport;

BEGIN
END RegSupport.
