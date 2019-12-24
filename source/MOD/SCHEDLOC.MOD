IMPLEMENTATION MODULE SchedLocks;

   (*   SchedLocks - Implement support routines for schedule locking.

        Modification History
        ====================
        18-Apr-89 WKH Initial Version
        07-May-89 WKh Locking class support
        30-Jun-89 WKH Initialize variable Title
   *)

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Error, ContinuationBox;

FROM Directory              IMPORT
    (* TYPE *)                  AFileAttribute, AFileAttributeSet,
    (* PROC *)                  FileLookupStart;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatLS, Copy, SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Schedule               IMPORT
    (* TYPE *)                  AScheduleLockClass,
    (* PROC *)                  LockSchedule;


CONST
    ModuleNumber            = 4800;
    ExistsMsg1              = 1;
    ExistsMsg2              = 2;
    InUseMsg                = 3;


(* NameAndLockSchedule - Attempt to name and lock a schedule *)

PROCEDURE NameAndLockSchedule(VAR PathName : ARRAY OF CHAR;
                              VAR FileName : ARRAY OF CHAR) : BOOLEAN;

VAR
    Attribute               : AFileAttributeSet;
    RealPathName            : ARRAY[0..80] OF CHAR;
    DummyPathName           : ARRAY[0..80] OF CHAR;
    Msg                     : ARRAY [0..255] OF CHAR;
    Title                   : ARRAY [0..40]  OF CHAR;
    NameOK                  : BOOLEAN;

BEGIN

    SetLengthOf(Title, 0);  (* 30-Jun-89 WKH *)

    Attribute := AFileAttributeSet{ReadOnlyAttribute, ArchiveAttribute};
    NameOK    := TRUE;
                        
    Copy(PathName, RealPathName);
    ConcatLS(RealPathName, FileName);

    IF (FileLookupStart(RealPathName, DummyPathName, Attribute)) THEN
        GetMessage(ModuleNumber + ExistsMsg1, Msg);
        ConcatLS(Msg, RealPathName);
        ConcatMessage(Msg, ModuleNumber + ExistsMsg2);
        IF (ContinuationBox(Msg, Title, OfferHelp)) THEN
            IF (NOT LockSchedule(PathName, FileName, FALSE, DualLock)) THEN (* 4/6/89 WKH *)
                GetMessage(ModuleNumber + InUseMsg, Msg);
                Error(Msg);
                NameOK := FALSE;
            END;
        ELSE
            NameOK := FALSE;
        END;
    ELSE
        IF (NOT LockSchedule(PathName, FileName, FALSE, DualLock)) THEN (* 4/6/89 WKH *)
            GetMessage(ModuleNumber + InUseMsg, Msg);
            Error(Msg);
            NameOK := FALSE;
        END;
    END;

    RETURN NameOK;

END NameAndLockSchedule;

END SchedLocks.
