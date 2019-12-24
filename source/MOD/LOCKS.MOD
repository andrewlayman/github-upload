IMPLEMENTATION MODULE Locks;


(*  =========================================================================
    Last Edit : May 22, 1991 1:42PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Locks - Provides general file locking facilites.
        

    MODIFICATION HISTORY:

       05-Mar-89 WKH   Initial version.
       03-Apr-89 WKH   Changed UnLockFile so that trying to unlock a non-locked
                       file doesn't crash us.
       13-Apr-89 WKH   Removed hard-coded strings and moved them to phrases file.
       20-Apr-89 WKH   Changed LockFile to return an enumerated type so we 
                       can more accurately determine reason for failure
       05-Jun-89 WKH   We used to just Create a file if it didn't exist.
                       However, this wasn't using any of the sharing bits.  So,
                       what we do now is immediately close a created file and
                       re-open it using the sharing bits(DOS forces us to do
                       it this way!!).
       30-Jun-89 WKH   Don't check result of close.
       07-Aug-89 WKH   Removed an import that wasn't being used.
       22-Sep-89 WKH   Make locks semi-smart about what to do if we should
                       ever come across the unfortunate situation of running
                       DOS 2.0
       25-Sep-89 WKH   Whoops!!  Used the wrong boolean test for DOS 3.1.  
                       That's what I get for falling asleep in my boolean
                       algebra class.
       27-Sep-89 WKH   Make above test more efficient, as per RSC, Also used
                       wrong value to test DOS version.
       24-Jan-91 RSC   Removed extra Close() calls.
       22-May-91 PFG   Separate file access errors from too-many-files errors.
    =========================================================================
*)

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM Directory              IMPORT
    (* PROC *)                  DOSVersion;

FROM FileAux                IMPORT
    (* PROC *)                  FileResultMeans;

FROM FileSystem             IMPORT
    (* CONST *)                 ReadOnlyMode, WriteOnlyMode, ReadWriteMode,
                                ExclusiveAccessMode, ReadOnlyAccessMode,
                                FullAccessMode,
                                NormalAttribute,
    (* TYPE *)                  File, AFileAccessRight, AFileAccessRightSet,
                                Response,
    (* PROC *)                  OpenFile, CreateFile, Close;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatS, ConcatLS, SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

     (* DisplayFileError -- Display a dialog box describing the
                            error.  Description should be the name
                            of the file or some other description of
                            it. *)

CONST
    ModuleNumber            = 29700;
    LockErrMsg              = 1;

PROCEDURE DisplayFileError( VAR f           : File;
                            VAR Description : ARRAY OF CHAR );

CONST
    BreakChar = 374C;

VAR
    S     : ARRAY [0..255] OF CHAR;

BEGIN
        (* Get a description of the error. *)
    FileResultMeans(f,S);
    ConcatS(S,BreakChar);
    ConcatLS(S,Description);

    Close(f);

       (* Display the error box. *)
    Error(S);
END DisplayFileError;


(*
    PROCEDURE LockFile:
    Attempts to lock a file so that other programs/processes can't
    write to the designated file.

    Preconditions:
    FileName must contain a valid DOS filename.
    Privileges must contain the desired access rights for the file
    (i.e. {BTSFullAccess} or {}).

    Postconditions:
    If possible, FileName will be locked.  If it is, then LockFile
    will return TRUE and Handle will be initialized appropriately.
    If a lock could not be established, then false will be returned
    and Handle will be unchanged.

    Description:
    Depending on the Privileges requested, LockFile does different
    things.

    If BTSFullAccess is requested, then LockFile attempts to open
    the file in ReadOnlyAccessMode + ReadWriteMode.  This mode
    designation is used in the Logitech filesystem so I am using it
    here for a common frame of reference.  If successful, Handle
    will contain the File record that points to the file and the
    FileAccessRight field of Handle will be set to {BTSLocked,
    BTSFullAccess}.  If the designated file doesn't exist, it will
    be created and locked.  If the designated file is locked by
    another process, LockFile will fail and return AlreadyLocked.

    If BTSFullAccess is not requested, the LockFile attempts to open
    the file in ReadOnlyAccessMode + ReadOnlyMode.  If successful,
    Handle will contain the File record that points to the file and
    the FileAccessRight field of Handle will be set to {BTSLocked,
    BTSReadOnly}.  This means that the file is locked, the process
    that requested the lock may not write to the file, and neither
    can any other process.  If the designated file doesn't exist, it
    WILL NOT be created since there would be nothing to read anyway.
    This will result in LockFile returning NoSuchFile.  If the designated
    file is locked by another process LockFile will fail and return
    AlreadyLocked.

    LockFile should always be called either prior to or instead of
    opening the file.
*)
PROCEDURE LockFile(VAR FileName   : ARRAY OF CHAR;
                   VAR Handle     : File;
                       Privileges : AFileAccessRightSet) : AFileLockResult;

VAR
    IsFileLocked            : AFileLockResult;
    FileOpenMode            : CARDINAL;
    FullAccessRequested     : BOOLEAN;
    s                       : ARRAY [0..80] OF CHAR;
    NetWorkDOS              : BOOLEAN;

BEGIN
    FullAccessRequested := BTSFullAccess IN Privileges;

    NetWorkDOS := DOSVersion() >= 030AH;  (* 27-Sep-89 WKH *)

    IF (FullAccessRequested) THEN
        IF NetWorkDOS THEN
            FileOpenMode := ReadOnlyAccessMode + ReadWriteMode;
        ELSE
            FileOpenMode := ReadWriteMode;
        END;
        IsFileLocked := FullLock;
    ELSE
        IF NetWorkDOS THEN
            FileOpenMode := FullAccessMode + ReadOnlyMode;
        ELSE
            FileOpenMode := ReadOnlyMode;
        END;
        IsFileLocked := ReadLock;
    END;

    OpenFile(Handle, FileName, FileOpenMode);

    CASE Handle.res OF
        done : 
            INCL(Privileges, BTSLocked);
            Handle.FileAccessRight := Privileges;

    |   unknownfile,
        notdone :
            IF (FullAccessRequested) THEN
                CreateFile(Handle, FileName, NormalAttribute);

                IF (Handle.res <> done) THEN
                    (* 24-Jan-91 RSC Create file, if it fails,
                                     has not opened, so Close is irrelevent.
                    *)
(*                    IF (Handle.res <> toomanyfiles) THEN*)
(*                        Close(Handle);*)
(*                    END;*)

                    (* 22-May-91 PFG  Distinguish file access error from
                                      too-many-files problem.  *)
                    IF (Handle.res = toomanyfiles) THEN
                        IsFileLocked := AlreadyLocked;
                    ELSE    (*  access error  *)
                        IsFileLocked := UnLockable;
                    END;
                ELSE
                    Close(Handle);   (* WKH 6/5/89 *)

                    OpenFile(Handle, FileName, FileOpenMode);

                    CASE Handle.res OF
                        done : 
                            INCL(Privileges, BTSLocked);
                            Handle.FileAccessRight := Privileges;

                    |   accesserror :
                            IsFileLocked := AlreadyLocked;
                    ELSE
                        IF (Handle.res <> toomanyfiles) THEN
                            Close(Handle);
                        END;

                        GetMessage(ModuleNumber + LockErrMsg, s);
                        DisplayFileError(Handle, s);
                        IsFileLocked := UnknownError;
                    END;
                END;
            ELSE
                IsFileLocked := NoSuchFile;
            END;

    |   accesserror : 
            IF (Handle.res <> toomanyfiles) THEN
                Close(Handle);
            END;
            IsFileLocked := AlreadyLocked;
    ELSE
              (* 24-Jan-91 RSC Open file, if it fails,
                               has not opened, so Close is irrelevent.
              *)
(*        IF (Handle.res <> toomanyfiles) THEN*)
(*            Close(Handle);*)
(*        END;*)

        GetMessage(ModuleNumber + LockErrMsg, s);
        DisplayFileError(Handle, s);
        IsFileLocked := UnknownError;
    END;
    
    RETURN(IsFileLocked);
END LockFile;


(*
    PROCEDURE UnLockFile:
    Attempts to unlock a file.

    Preconditions:
    Handle should contain a previously locked handle.

    Postconditions:
    The file pointed to by Handle will be unlocked.

    Description:
    UnLockFile attempts to close the designated Handle.
*)

PROCEDURE UnLockFile(VAR Handle : File);
BEGIN
    IF (BTSLocked IN Handle.FileAccessRight) THEN
        Close(Handle);
        EXCL(Handle.FileAccessRight, BTSLocked);
    END;
END UnLockFile;

END Locks.

