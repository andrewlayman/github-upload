IMPLEMENTATION MODULE Registry;


    (* Registry - Allow registry of add in products.

        Idea:           AJL 4/27/89
        Code:           RSC 8/16/89
        Radical Change: WKH 6/07/89

    This allows loaded overlays to steal this vector and answer the question,

        "Is this copy of Time Line allowed to run this product?"

       MODIFICATION HISTORY:
       07-May-89 WKH    Added checking of product code.
       07-Jun-89 WKH    Added support for super flexibility
       21-Jun-89 WKH    Adjust incorrect ProductTypeOffset
       25-Jun-89 WKH    Moved initialization of removed varialbes(listed in 
                        DEF) to here from Registry.DEF
       26-Jun-89 WKH    Initialize SemaphoreFile var
       05-Jul-89 WKH    Added procedures to handle locking of usernames.
       03-Nov-89 WKH    Removed call to Delete in UnLockUser.  This is under
                        the notion that we will not have delete access to the
                        MUSER directory(to prevent accidental erasure of the
                        TIMELINE.$M$ file) and that we don't really care that
                        a bunch of 0 length semaphore files will be left in
                        that directory(they don't actually take up any disk
                        space, just directory space).
       06-Dec-89 WKH    Use MAXCARDINAL for bad file tag instead of 0.  This
                        is MUCH safer.  What was happening was that we(ok, I)
                        were assuming that slot 0 in the files[] data
                        structure in DiskFiles was always occupied by
                        TLPHRAS4.DAT.  Well, I assumed incorrectly.  Shame on
                        me.  Roger removed MsgFile's reliance on FileSystem
                        and moved it to DOSIO.  Thus, slot 0 could be anyone
                        nowadays.  So, I decided to use a flag that was
                        a little more safer, thus MAXCARDINAL (this is well
                        outside the range of valid file slots).
       22-Jan-91 RSC    fHint becomes mHint for the new file system.
    *)

FROM FileSystem             IMPORT
    (* TYPE *)                  File, AFileAccessRight, AFileAccessRightSet,
    (* PROC *)                  Delete;

FROM Kbio                   IMPORT
    (* VAR *)                   VersionString;

FROM Locks                  IMPORT
    (* TYPE *)                  AFileLockResult,
    (* PROC *)                  LockFile, UnLockFile;

FROM LStrings               IMPORT
    (* PROC *)                  LStringToTString;

FROM MagicNum               IMPORT
    (* CONST *)                 IsCardValue;


CONST
    MAXCARDINAL             = 65535;    (* 6-Dec-89 WKH  *)
    ProductTypeOffset       = 25;

VAR
    SemaphoreFile           : File;
    SemaphoreName           : ARRAY[0..99] OF CHAR; (* WARNING!!  This is a *)
                                                    (* TString, not LString *)


PROCEDURE OurRegistryProc( VAR UserName    : ARRAY OF CHAR;
                           VAR ProductName : ARRAY OF CHAR;
                               InfoRequest : CARDINAL;
                           VAR ReturnValue : ARegistryDataRecord
                         ) : BOOLEAN;

VAR
    WeBeCool                : BOOLEAN;

BEGIN
    IF (InfoRequest = QProductType) THEN
        ReturnValue.DataType := IsCardValue;
        ReturnValue.CardinalValue := ORD(VersionString[ProductTypeOffset+1]) -
                                     ORD("0");
        WeBeCool := TRUE;
    ELSE
        WeBeCool := FALSE;
    END;

    RETURN WeBeCool;
END OurRegistryProc;


PROCEDURE LockUser(VAR UserName          : ARRAY OF CHAR;
                   VAR SemaphoreFileName : ARRAY OF CHAR) : AFileLockResult;

VAR
    LockResult              : AFileLockResult;
    Priveleges              : AFileAccessRightSet;

BEGIN
    IF (SemaphoreFile.mHint <> MAXCARDINAL) THEN  (* Already been called once *)
        LockResult := AlreadyLocked;
    ELSE
        LStringToTString(SemaphoreFileName, SemaphoreName);

        Priveleges := AFileAccessRightSet{BTSFullAccess};
        LockResult := LockFile(SemaphoreName, SemaphoreFile, Priveleges);

        IF (LockResult <> FullLock) THEN
            SemaphoreFile.mHint := MAXCARDINAL;  (* make damn sure it's invalid!!! *)
            SemaphoreName[0]    := 0C;
        END;
    END;

    RETURN (LockResult);
END LockUser;


PROCEDURE UnLockUser();                   

BEGIN
    IF (SemaphoreFile.mHint <> MAXCARDINAL) THEN  (* check to see that we have a lock *)
        UnLockFile(SemaphoreFile);
        SemaphoreFile.mHint := MAXCARDINAL;  (* make damn sure it's invalid!!! *)
    END;
END UnLockUser;


BEGIN
    GetRegistryInfo     := OurRegistryProc;  (* Take my vector .... PLEASE! *)
    ProductName[0]      := 0C;               (* 20-Jun-89 WKH *)
    UserName[0]         := 0C;               (* 07-Jun-89 WKH *)
    UserSerialNumber[0] := 0C;
    SemaphoreName[0]    := 0C;               (* 05-Jul-89 WKH , TString *) 

    WITH SemaphoreFile DO  (* 26-Jun-89 WKH *)
        mHint           := MAXCARDINAL;
        FileAccessRight := AFileAccessRightSet{};
    END;

END Registry.
