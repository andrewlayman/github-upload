    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE DOSIO;


(*  =========================================================================
    Last Edit : September 11, 1991 10:46AM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        DOS IO  - Do file IO directly to DOS.  No Logitech I/O calls are used.
        
        Idea:

            IF you are doing full sector binary reads and writes, Logitech's
               file I/O system is a needless middleman, and will slow down
               our I/O.  Use this module to do all I/O directly.

            DANGER:

                DOS is at your mercy.  You have to remember to write all
                dirty buffers and close all files.



    MODIFICATION HISTORY:

        RSC 18-Aug-88 - Initial version, for TLSwapF.
        RSC 14-Nov-88 - Correct file open mode for extisting files.
        RSC 29-Nov-88 - When an OPEN fails, the Handle == ErrorCode.  There was
                        a case where the error code was 5, and we closed the
                        Message file, which happened to be file 5!!
        RSC 30-May-89 - With WKH's help, added File Locking code to open the
                        swap file with exclusive access so multiple copies
                        of Time Line in the same directory will fail in a
                        semi-reasonable way.
        WKH 06-Aug-89 - Initial OS/2 edits.  Map DOSCALLs to corresponding
                        OS/2 API calls.  Also change error handling.
        WKH 18-Sep-89 - Don't use exclusive access attribute on DOS 2.x
        RSC 20-Sep-89 - Removed FileNameZ from ADOSFileHandle.
        WKH 25-May-90 - OK, so we had to open the file in ReadOnlyDenyWrite
                        mode on networks because our previous method of just
                        using DOS 2.x compatibility mode wasn't working.
                        Sometimes it worked though, that was the problem.
                        This seems to work on all networks (except perhaps
                        those networks that are based on VAX's running
                        ULTRIX UNIX with PCNFS emulating DOS on top of it).
                        Turns out that some networks also need the Read Only
                        bit of the file set for this to work.  DOS, such a
                        joke.  Anyways, I also "restructured" the code and
                        reduced it from several procedure calls to one proc
                        call and a couple of assignments.  I hope net I was
                        able to not add and maybe even save some code space.

         9-Oct-90 RSC - Added support for caching and extra close-processing.
                        Also added a "Raw" open and support for file name
                        prep for DOS.

        10-Oct-90 RSC - RecordSize was not being used right in DOSOpen
                        due to changes I made yesterday.  Oops.
                        Also, added the ShortWrite procedure.
        31-Jul-91 PFG - Fixed a problem which caused us not to detect a disk
                        full on either reads or writes.  Changes to
                        DoReadOrWrite look to see if the number of bytes
                        requested is the number we got.  Changes to 
                        ErrorOccured (sic) recognize a new error code for
                        disk full.  Also cleaned up some of the places where
                        ErrorOccured was called--we should call it before
                        we check ErrorCode so that critical errors are
                        caught.  Also...called HALT if the handle in
                        InstallDOSCloseProc wasn't open.
         4-Sep-91 EGK - Logic error in DOSRefresh -- after opening a new file
                        handle to refresh the directory, we were closing it
                        only if the open failed!  Fixed this by removing a
                        spurious NOT.
        11-Sep-91 EGK - Put in an extra check in DOSOpenRaw to see if the
                        CreateFile DOSCALL fails, and set f.Handle to 0 if
                        it does.  We were already doing that at the end of
                        DOSOpenRaw, but we need it sooner than that,
                        because ErrorOccured will try to close f.Handle in
                        the course of reporting the error.  And, since DOS
                        will set f.Handle to the error value, we might end
                        up closing somebody else's file!  In one case, the
                        error was "accesserror", or 5, which was the same
                        as the handle to the already opened message file, so
                        we couldn't put up the "Access Error" dialog box,
                        because we accidentally closed the phrases file!
    =========================================================================
*)


FROM Dialog     IMPORT
    (* PROC *)      Error;

FROM Directory  IMPORT
    (* PROCS *)   ExtractFileNameParts, DOSVersion;

FROM FileSystem IMPORT
    (* TYPE *)    File, Response, FlagSet, AFileBufferPtr;

FROM FileAux    IMPORT
    (* PROCS *)   PrepareForIO, CheckIO, FileResultMeans;

FROM LStrings   IMPORT
    (* PROCS *)   Copy, ConcatLS, ConcatS, LStringToTString;

FROM SYSTEM     IMPORT
    (* TYPE  *)   ADDRESS,
    (* PROCS *)   ADR, DOSCALL;






PROCEDURE NillCloseProc( Context : ADDRESS );
BEGIN
END NillCloseProc;




 (* Error Occured  - Did a file system error occur?

        This is complicated by the fact that we want to reuse the code
        in FileAux that prints out nice error messages.

        Also, the Critical Error Handler in File Aux is geared around
        the Logitech file handle.

        So, to do a DOSCALL, you must:

            1) Allocate a local Logiitek File Handle
            2) Call Prepare For IO; which arms the critical error handler and
               resets the "res" (Response) variable in the file handle)
            3) Do the DOSCALL, saving the returned DOS ERROR CODE.
            4) Call this routine to sort out any errors, including
               wether there were any critical errors that may have gone
               unreported or poorly reported in res.
 *)
VAR
    Interlock   : CARDINAL;

PROCEDURE ErrorOccured( ErrorCode    : CARDINAL;
                    VAR f            : ADOSFileHandle;
                    VAR LogitechFile : File     ) : BOOLEAN;
CONST
    CloseFile  = 3EH;
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN

 (* Map any errors into the Logitech "res" (Response), so that our common
    routines in FileAux can handle things.
 *)
    IF (ErrorCode <> 0) THEN
        CASE ErrorCode OF
          1: LogitechFile.res := eom;           (* 31-Jul-91 PFG *)
        | 2,
          3: LogitechFile.res := unknownfile;
        | 4: LogitechFile.res := toomanyfiles;
        | 5: LogitechFile.res := accesserror;
        ELSE
             LogitechFile.res := notdone;
        END;
    END;

    f.FileError := CheckIO( LogitechFile );

    IF (f.FileError <> done) AND
       (f.DisplayErrors)     THEN  (* ERROR OCCURED! *)

        LogitechFile.bufa        := AFileBufferPtr(NIL); (* No buffer/filename. *)
        LogitechFile.eof         := FALSE;
        LogitechFile.flags       := FlagSet{};

        FileResultMeans( LogitechFile, s );
        IF (f.Handle <> 0) THEN
            f.CloseProc( f.CloseContext );
            f.CloseProc := NillCloseProc;
            DOSCALL( CloseFile, f.Handle, ErrorCode );
        END;
        IF (Interlock = 0) THEN
            INC(Interlock);
            Error(s);
            DEC(Interlock);
        END;
        f.Handle := 0;
    END;

    RETURN (f.FileError = done);

END ErrorOccured;





(* Translate File String For DOS

    Given an LString of the logical file name, create a DOS TString
    ready for DOSCALLs.  This also translates DK: to the current drive.
    The file name is returned both for DOSCALLs and in LString format
    in the passed string.

    Preconditions:

        A valid file name (fragment) is passed in.  No wildcards.

    Postconditions:

        A name ready to be passed to DOS.
        Another LString also expanded

    Input:  TheFileName     LString containing file name fragments

    Output: TheFileName     LString containing fully expanded name.
            DOSFileName     TString with fully expanded name.

*)
PROCEDURE TranslateFileStringForDOS( VAR TheFileName    : ARRAY OF CHAR;
                                     VAR DOSFileName    : ARRAY OF CHAR );
VAR
    DeviceName      : ARRAY [0..4]   OF CHAR;
    PathName        : ARRAY [0..127] OF CHAR;
    FileName        : ARRAY [0..8]   OF CHAR;
    Extension       : ARRAY [0..3]   OF CHAR;

BEGIN
    ExtractFileNameParts( TheFileName, DeviceName, PathName, FileName, Extension );
    Copy(     DeviceName, TheFileName );
    ConcatLS( TheFileName, PathName   );
    ConcatLS( TheFileName, FileName   );
    ConcatS(  TheFileName, "." );
    ConcatLS( TheFileName, Extension  );

    LStringToTString( TheFileName, DOSFileName );

END TranslateFileStringForDOS;











 (* DOS Open Raw - Open a file under direct DOS control, with attributes.

    Preconditions : FileName      - An LString with the file name.
                                    May need to be expanded, If so,
                                    I'll take care of that here.
                    Attributes    - Attribute bits for file.
                    Create        - Dispose of the file before opening??
                    RecordSize    - How big is one record?
                    DisplayErrors - Display file errors?

    Postconditions: f        - The file handle to pass to other IO routines.
                    RETURN is TRUE if file opened.  FALSE if not opened;
                              an error box was shown to customer!
 *)
PROCEDURE DOSOpenRaw( VAR TheFileName   : ARRAY OF CHAR;
                      VAR f             : ADOSFileHandle;
                          Attributes    : CARDINAL;
                          Create        : BOOLEAN;
                          TheRecordSize : CARDINAL;
                          DoWeDisplay   : BOOLEAN
                     ) : BOOLEAN;
CONST
    CreateAFile         = 3CH;
    OpenAFile           = 3DH;
    CloseFile           = 3EH;
    NormalAttribute     = 00H;
VAR
    ErrorCode       : CARDINAL;
    LogitechFile    : File;      (* For our Critical Error Handler only. *)
    FileNameZ       : ARRAY [0..127] OF CHAR;
    ok              : BOOLEAN;

BEGIN

    WITH f DO
        Handle          := 0;
        CloseProc       := NillCloseProc;
        CloseContext    := NIL;
        CachePriority   := 0;
        CacheRecords    := 0;
        CacheHint       := 0;
        DisplayErrors   := DoWeDisplay;
        FileError       := done;
        BytesRead       := 0;

        RecordSize      := TheRecordSize;
        RecsPerMaxcard  := (32768 DIV RecordSize) * 2; (* Avoid overflow (1) *)
        IF (((RecsPerMaxcard DIV 2) * RecordSize) <> 32768) THEN
            HALT;   (* Record Size must be a power of two > 1 *)
        END;

        PrepareForIO( LogitechFile );  (* Reset our critical error handler. *)

        Copy( TheFileName, FileName );
        TranslateFileStringForDOS( FileName, FileNameZ );
    END;

    ErrorCode := 0;

    IF (Create) THEN
        DOSCALL( CreateAFile, ADR( FileNameZ ), NormalAttribute,
                 f.Handle, ErrorCode );

        IF (ErrorCode <> 0) THEN        (* 9/11/91 EGK *)
            f.Handle := 0;
        END;

        IF (ErrorCode = 0) THEN
            DOSCALL( CloseFile, f.Handle, ErrorCode );
        END;
    END;

    IF (ErrorCode = 0) THEN
        DOSCALL( OpenAFile, ADR( FileNameZ ), Attributes,
                 f.Handle, ErrorCode );
    END;

    ok := ErrorOccured( ErrorCode, f, LogitechFile );
    IF (NOT ok) THEN
        f.Handle := 0;   (* No file, but the Handle will == ErrorCode due *)
                         (* to the way DOSCAL works.  RSC 11/29/88        *)
    END;

    RETURN ok;

END DOSOpenRaw;




 (* DOS Open - Open a file under direct DOS control.

    Preconditions : FileName   - an LString with the file name.  May need to be
                                 expanded, I'll take care of that here.
                    AccessType - Create it, Open it, or Open it read only?
                    RecordSize - How big is one record?  Can be any power of
                                 2 > 1.

    Postconditions: f        - The file handle to pass to other IO routines.
                    RETURN is TRUE if file opened.  FALSE if not opened;
                              an error box was shown to customer!
 *)
PROCEDURE DOSOpen( VAR TheFileName : ARRAY OF CHAR;
                   VAR f           : ADOSFileHandle;
                       AccessType  : AnAccessType;
                       RecordSize  : CARDINAL     ) : BOOLEAN;
CONST
    ReadWriteMode       =  2H;
    ReadOnlyMode        =  0H;
    ExclusiveAccessMode = 10H; (* network functions available only in DOS 3.0+ *)
    ReadOnlyDenyWrite   = 20H; (* 25-May-90 WKH *)
VAR
    Attributes : CARDINAL;
    Create     : BOOLEAN;
BEGIN
    Create     := (AccessType = CreateFile);

    IF (AccessType = OpenReadOnly) THEN
        Attributes := ReadOnlyMode;
        IF (DOSVersion() >= 0310H) THEN  (* 25-May-90 WKH *)
            Attributes := Attributes + ReadOnlyDenyWrite;
        END;
    ELSE
        Attributes := ReadWriteMode;
        IF (DOSVersion() >= 0310H) THEN  (* 25-May-90 WKH *)
            Attributes := Attributes + ExclusiveAccessMode;
        END;
    END;

    RETURN DOSOpenRaw( TheFileName, f, Attributes, Create, RecordSize, TRUE );

END DOSOpen;








 (* Do Read Or Write - Do a DOS Read or Write, as helpers to DOSRead
                       and DOSWrite.
    Preconditions : ReadIt   is TRUE if a READ, FALSE if a WRITE.
                    f        is the opened file handle.
                    Record   is the record number to read.
                    Address  is where to put the read record.

    Postcondition : I/O has been attempted.
                    Short    is TRUE if a short IO was done (EOF or Disk full).
                    RETURN   is TRUE if OK, FALSE if error was displayed.
 *)
PROCEDURE DoReadOrWrite(     ReadIt   : BOOLEAN;
                         VAR f        : ADOSFileHandle;
                             Record   : CARDINAL;
                             Address  : ADDRESS;
                             Length   : CARDINAL;
                         VAR Short    : BOOLEAN  ) : BOOLEAN;
CONST
    ReadRecord  = 3FH;
    WriteRecord = 40H;
    SetPos      = 42H;
VAR
    XferedBytes,
    High, OHigh,
    Low,  OLow,
    ErrorCode    : CARDINAL;
    LogitechFile : File;      (* For our Critical Error Handler only. *)
    ok           : BOOLEAN;
BEGIN
    IF (f.Handle = 0) THEN RETURN FALSE;  END;  (* File Closed! *)

    DEC(Record);     (* They start with number 1. *)
    Low  := (Record MOD f.RecsPerMaxcard) * f.RecordSize;
    High :=  Record DIV f.RecsPerMaxcard;

    PrepareForIO( LogitechFile );

    DOSCALL( SetPos, f.Handle, 0, High, Low, OHigh, OLow, ErrorCode );
    IF (ErrorCode = 0) THEN
        IF ReadIt THEN
            DOSCALL( ReadRecord,    f.Handle, Length, Address,
                     XferedBytes, ErrorCode );
        ELSE
            DOSCALL( WriteRecord,   f.Handle, Length, Address,
                     XferedBytes, ErrorCode );
        END;
    END;
    Short       := (XferedBytes <> Length);
    f.BytesRead := XferedBytes;

    IF (NOT ReadIt AND (ErrorCode = 0) AND Short) THEN      (* 31-Jul-91 PFG *)
        ErrorCode := 1;     (*  Disk full or EOF  *)
    END;

    ok    := ErrorOccured( ErrorCode, f, LogitechFile );

    RETURN ok;

END DoReadOrWrite;





 (* DOS Read - Read record number N from the file.

    Preconditions : f        is the opened file handle.
                    Record   is the record number to read.
                    Address  is where to put the read record.

    Postconditions: Address contains the data read from the file.
                    EOF is TRUE if we are at the end of the file.
                    RETURN is TRUE if ok, FALSE if error displayed.
 *)
PROCEDURE DOSRead( VAR f       : ADOSFileHandle;
                       Record  : CARDINAL;
                       Address : ADDRESS;
                   VAR EOF     : BOOLEAN    ) : BOOLEAN;
BEGIN
    RETURN DoReadOrWrite( TRUE, f, Record, Address, f.RecordSize, EOF );
END DOSRead;





 (* DOS Write - Write record number N to the file.

    Preconditions : f        is the opened file handle.
                    Record   is the record number to write.
                    Address  is where to get the written record.

    Postconditions: Full is TRUE if the disk is full.
                    RETURN is TRUE if ok, FALSE if error displayed.
 *)
PROCEDURE DOSWrite( VAR f       : ADOSFileHandle;
                        Record  : CARDINAL;
                        Address : ADDRESS;
                    VAR Full    : BOOLEAN     ) : BOOLEAN;
BEGIN
    RETURN DoReadOrWrite( FALSE, f, Record, Address, f.RecordSize, Full );
END DOSWrite;






 (* DOS Short Write - Write record number N to the file, for the
                      given number of bytes.

    Preconditions : f        is the opened file handle.
                    Record   is the record number to write.
                    Address  is where to get the written record.
                    Length   is the number of bytes to write.
                                It must be L.E. the recordsize.

    Postconditions: Full is TRUE if the disk is full.
                    RETURN is TRUE if ok, FALSE if error displayed.
 *)
PROCEDURE DOSShortWrite( VAR f       : ADOSFileHandle;
                             Record  : CARDINAL;
                             Address : ADDRESS;
                             Length  : CARDINAL;
                         VAR Full    : BOOLEAN     ) : BOOLEAN;
BEGIN
    RETURN DoReadOrWrite( FALSE, f, Record, Address, Length, Full );
END DOSShortWrite;







 (* DOS Close - Close A File Handle

    Preconditions  : f  - The handle returned from Open
    Postconditions : File is closed.  RETURNs TRUE if successfull,
                     FALSE if error occured.  Error was displayed.
 *)
PROCEDURE DOSClose( VAR f : ADOSFileHandle ) : BOOLEAN;
CONST
    CloseFile  = 3EH;
VAR
    ErrorCode    : CARDINAL;
    LogitechFile : File;      (* For our Critical Error Handler only. *)
BEGIN
    ErrorCode := 0;
    PrepareForIO( LogitechFile );
    IF (f.Handle <> 0) THEN
        f.CloseProc( f.CloseContext );
        f.CloseProc := NillCloseProc;
        DOSCALL( CloseFile, f.Handle, ErrorCode );
    END;
    f.Handle := 0;
    RETURN ErrorOccured( ErrorCode, f, LogitechFile );
END DOSClose;





 (* DOS Delete - Delete a file previously opened/created.  If the file is not
                 yet closed, it is closed for you.

    Preconditions  : f  - The handle returned from Open
    Postconditions : File is deleted.  RETURNs TRUE if successfull,
                     FALSE if error occured.  Error was displayed.
 *)
PROCEDURE DOSDelete( VAR f : ADOSFileHandle ) : BOOLEAN;
CONST
    DeleteFile  = 41H;
VAR
    ErrorCode    : CARDINAL;
    LogitechFile : File;      (* For our Critical Error Handler only. *)
    FileNameZ    : ARRAY [0..127] OF CHAR;

BEGIN
    PrepareForIO( LogitechFile );
    IF (f.Handle <> 0) THEN
        IF (NOT DOSClose( f )) THEN RETURN FALSE; END;
    END;

    LStringToTString( f.FileName, FileNameZ ); (* RSC 20-Sep-89 *)

    DOSCALL( DeleteFile, ADR(FileNameZ), ErrorCode );

    RETURN ErrorOccured( ErrorCode, f, LogitechFile );

END DOSDelete;




 (* DOS Refresh - Refresh the file directory.  This is done by making
                  a copy of the file handle and closing the copy.
 *)
PROCEDURE DOSRefresh( VAR f : ADOSFileHandle ) : BOOLEAN;
CONST
    DuplicateFile  = 45H;
    CloseFile      = 3EH;
    DiskReset      = 0DH;
VAR
    LocalHandle,
    HandleCopy,
    ErrorCode    : CARDINAL;
    LogitechFile : File;      (* For our Critical Error Handler only. *)
    ok           : BOOLEAN;

BEGIN
    PrepareForIO( LogitechFile );
    ErrorCode := 0;
    IF (f.Handle <> 0) THEN
        LocalHandle := f.Handle;  (* RSC 11/29/88 *)
        DOSCALL( DuplicateFile, LocalHandle, HandleCopy, ErrorCode );
        ok := ErrorOccured( ErrorCode, f, LogitechFile );
        IF (ok) THEN        (* 9/4/91 EGK *)
            DOSCALL( CloseFile, HandleCopy, ErrorCode );
            DOSCALL( DiskReset );  (* And don't buffer anything for me! *)
        END;
    ELSE
        ok := ErrorOccured( ErrorCode, f, LogitechFile );
    END;
    RETURN ok;
END DOSRefresh;







(* Install Close Proc - Install a procedure to be called upon closing
                        of the file.

    Preconditions:

        Handle is a handle of an OPEN file.
        CloseProc, if not NIL, is a procedure that will be around when
               the file is closed.

    Postconditions:

        When the file is closed, the CloseProc will be called with the
        CloseContext.

    Input:  Handle          The OPEN file handle
            CloseProc       NIL for "no proc" or a valid procedure to call
                            on close.
            CloseContext    the context to give to the CloseProc.

    Output: Handle          Updated with the new information.
*)
PROCEDURE InstallDOSCloseProc( VAR Handle          : ADOSFileHandle;
                                   CloseProc       : ACloseProc;
                                   CloseContext    : ADDRESS   );
BEGIN
    IF (Handle.Handle = 0) THEN        (* 1-Aug-91 PFG *)
        HALT;
    END;
    Handle.CloseProc    := CloseProc;
    Handle.CloseContext := CloseContext;
END InstallDOSCloseProc;









(* Cache File - Cache a DOS file, if possible, in EMS or XMS.

    Preconditions:

        Handle is a handle of an OPEN file.

    Postconditions:

        If possible, the file will be cached in EMS or XMS, given the
        priority and availability of EMS or XMS.

    Input:  Handle          The OPEN file handle

            CacheKB         Size in KB to allocate for the cache.
                            This is an UPPER LIMIT.

                            Setting this very high costs no permanant
                            space, just increases the total POSSIBLE
                            space to be cached.  This can be used as a
                            low number to cache, say, a file where you
                            write the index in the first KB or so.

            Priority        Where does this file rank with others over
                            who gets space first?

                            The HIGHER the number, the HIGHER the
                            priority.


    Output: Handle          Updated with the new information.

    Tech Note:

        Writes are cached in this manner:

            If the record would extend the file, then the write is
            applied to the disk AND the cache.

            Otherwise, the write is buffered until the cache is flushed
            or the file is closed.

*)
PROCEDURE CacheDOSFile( VAR Handle         : ADOSFileHandle;
                         CacheRecords   : CARDINAL;
                         Priority       : CARDINAL );
BEGIN
    Handle.CacheRecords  := CacheRecords;
    Handle.CachePriority := Priority;
    Handle.CacheHint     := 0;
END CacheDOSFile;











BEGIN
    Interlock := 0;
END DOSIO.
