(*----------------------------------------------------------------------------
    MODIFICATION HISTORY
    
    11/12/86 LAA    Added calls to PrepareForIO at various places.
     2/15/88 RSC    Cleaned up after Andrew's (unlisted) changes.
                    Specificly, changed "FileOK".
    1-Jan-89 RSC    Added "TraverseSubfiles".  Send a "SubfileRead" notice
                    when reading subfiles.
    8-Feb-89 EGK    StartFileInput calls Reset.  This allows it to work
                    with files that are open but not at BOF.
   31-Aug-89 RSC    Removed send of a notice.  This had been put in in
                    January for Foreign Subfiles, but we have changed the
                    way we do Foreign Subfiles.
   13-Feb-91 RSC    Allow a StartFileInput to be repeated.
                    This is used by printing overlays.
   18-Feb-91 AJL    Added a procedure, FlushDirectory, which writes out the
                    cached directory.  This is called when the file is closed,
                    as before, but also when the EndFileOutput procedure
                    is called.  Without it, the directory would not be 
                    accurate until the file was closed, which would prevent 
                    a file being held open as a way of communicating among
                    overlays, as it must be for exporters to work.
   20-Feb-91 RSC    "Sex32Positive", the global, was being unset when this
                    module was not resident but the file remained open.
                    This seems to only affect the FormsFile, but there could
                    be other clients with troubles.  In any case, the
                    Sex32Positive should be on a file-by file basis anyway,
                    so I added it to the file's context (the directory cache)
   21-Feb-91 AJL    Modified the setting of the SexWord for the file so
                    that we dynamically determine the high/low storage
                    format of the processor.
    4-Mar-91 RSC    Well, Andrew did not quite get it right.  The Intel
                    format for a longword is either different than what
                    Andrew thought, or the way he computed the longint
                    biased the equasion.  In any case, this code will need
                    to be re-written for byte order independance anyway.
                    Adjusted the SexWords record accordingly.
    5-Mar-91 RSC    The CLoseProc installed by StartFileOutput and
                    StartFileInput is a procedure pointer.  For at least
                    one client, the cross tabs, the copy of this module
                    linked to tlcr is no longer resident when tlprt2d
                    runs.  For this reason, when the close proc is called,
                    the machine jumps into hyperspace.  My fix for this is
                    to reset the close proc when the StartFileInput is called.
                    Also, put the close proc for reading in the root.
   31-May-91 RSC    Only read real directory entries, not empty ones.
                    Bug # 4456.  Fix is in StartFileInput.
   10-Jun-91 EGK    Made a similar fix to the one on 5-Mar-91, this time
                    for output files.  Again, the problem was that some
                    overlay swapping might occur between EndFileOutput
                    and the next attempt to close the file, thus rendering
                    the OutputCloseProc invalid.  Here we have EndFileOutput
                    reset the close proc to the InputCloseProc, which is
                    always in the root.  As long as nobody attempts to
                    write to the file again after EndFileOutput is called,
                    this should work fine.
     1-Aug-91 PFG   Saved the f.res on input in FlushDirectory.  This way,
                    if there was already an error, we don't lose track of it.
----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE Subfiles;



FROM RecordIO     IMPORT ReadRecord, WriteRecord;

FROM FileSystem   IMPORT File, Close, Response, SetPos, GetPos,
                         SetRead, SetWrite, SetModify, Reset,
                         InstallCloseProc, AFilePointer, Doio;

FROM FileAux      IMPORT PrepareForIO, CheckIO, FileResultMeans,
                         DisplayFileError;

FROM LStrings     IMPORT SetLengthOf, SetString;

FROM Dialog       IMPORT Error, FatalError;

FROM SubStub      IMPORT
    (* PROC *)          InputCloseProc; (* 5-Mar-91 RSC *)

FROM SYSTEM       IMPORT
                        ADDRESS, ADR, SIZE, TSIZE;

FROM MsgFile      IMPORT GetMessage;

FROM Space        IMPORT
    (* PROC *)       Available, ALLOCATE, DEALLOCATE;


CONST
    ModuleNumber = 114;    (* For GetMessage *)



CONST
    SOF      = 0F0H;
    SOSF     = 0F1H;
    EOF      = 0FEH;
    EOSF     = 0FFH;
    DIRR     = 0F2H;
    EmptySubfileNumber = 0FFFFH;

    MaxDirectoryEntries = 100;

TYPE
    ADirectoryEntry = RECORD
                          SubfileNumber   : CARDINAL;
                          Low,
                          High            : CARDINAL;
                          VersionNo       : CARDINAL;
                      END;
    ASubfileHeader  = RECORD
                          SubfileNumber   : CARDINAL;
                      END;
    AStartOfFileRecord = RECORD
                            SexWordLow,
                            SexWordHigh : CARDINAL;
                            Application : ARRAY [0..1] OF CHAR;
                            Version     : CARDINAL;
                        END;

        (* 5-Mar-91 RSC Added SizeInBytes.  This must be the FIRST
                        word in the cache.  "SubStub.Mod" will
                        do the deallocating of this entry, so
                        it needs a way of knowing a structure size
                        without knowing its contents, which are local
                        to this module.
        *)
    ADirectoryCache     = RECORD
        SizeInBytes    : CARDINAL;  (* Including this word *)
        HowManyEntries : CARDINAL;
        Entries        : ARRAY [1..MaxDirectoryEntries] OF ADirectoryEntry;
        Sex32Positive  : BOOLEAN; (* 20-Feb-91 RSC *) (* 32 Bit word stored low 16, high 16 *)
    END;

    ADirectoryCachePtr  = POINTER TO ADirectoryCache;






PROCEDURE BadStructure(VAR F:File);
VAR
    s : ARRAY [0..80] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);   (*  "Bad data file structure."  *)
    Error(s);
    F.eof := TRUE;
    F.res := notdone;
END BadStructure;



PROCEDURE FileOK(VAR F:File):BOOLEAN;
VAR
    S : ARRAY [0..0] OF CHAR;
    ok : BOOLEAN;
BEGIN
    ok := (CheckIO(F) = done);

    IF (NOT ok) THEN
        SetLengthOf(S,0);
        DisplayFileError(F,S);
    END;

    RETURN ok;

END FileOK;




    (*  StartFileOutput -- Write a header to the file and reserve
                           room for a subfile directory. *)

PROCEDURE StartFileOutput     (VAR F               : File;
                                   SubfileCount    : CARDINAL );
VAR
    DirectoryEntry    : ADirectoryEntry;
    StartOfFileRecord : AStartOfFileRecord;
    DirectoryCache    : ADirectoryCachePtr;
    i                 : CARDINAL;
    SexWords          : RECORD
                            CASE BOOLEAN OF
                               TRUE : LI : LONGINT;
                                       (* 4-Mar-91 RSC changed order: *)
                             | FALSE : WordHigh, WordLow : CARDINAL;
                            END;
                        END;

BEGIN
    SetWrite(F);

    SexWords.LI := 305419896L;    (* 12345678H *)
    StartOfFileRecord.SexWordLow  := SexWords.WordLow;
    StartOfFileRecord.SexWordHigh := SexWords.WordHigh;
    StartOfFileRecord.Application := "XX";  (* Invalid until it closes! *)
    StartOfFileRecord.Version     := 666;
    WriteRecord(F,SOF,ADR(StartOfFileRecord),SIZE(StartOfFileRecord));    (* File header. *)

    WITH DirectoryEntry DO
        SubfileNumber := EmptySubfileNumber;
        Low           := MAX(CARDINAL);
        High          := MAX(CARDINAL);
        VersionNo     := MAX(CARDINAL);
    END;

    (* 27-Jan-91 RSC Added the directory cache.
    *)
    IF (F.UserBuffer <> NIL) OR (SubfileCount > MaxDirectoryEntries) THEN
        FatalError();
    END;
    IF (NOT Available(TSIZE(ADirectoryCache))) THEN
        F.res := notdone;
        RETURN;
    END;
    NEW(DirectoryCache);
    F.UserBuffer := DirectoryCache;

    WITH DirectoryCache^ DO
        SizeInBytes    := TSIZE(ADirectoryCache);
        Sex32Positive  := (StartOfFileRecord.SexWordHigh = 5678H);  (* 20-Feb-91 RSC added. *)
        HowManyEntries := SubfileCount;
        FOR i := 1 TO HowManyEntries DO
            Entries[i] := DirectoryEntry;
        END;
    END;

    WHILE (SubfileCount > 0) DO
        WriteRecord(F,DIRR,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        DEC(SubfileCount);
    END;

    InstallCloseProc( F, OutputCloseProc );

END StartFileOutput;





PROCEDURE FlushDirectory( VAR F : File );
VAR
    DirectoryCache    : ADirectoryCachePtr;
    StartOfFileRecord : AStartOfFileRecord;
    i                 : CARDINAL;
    res               : Response;
BEGIN
    IF (F.UserBuffer <> NIL) THEN

        res := F.res;               (* 1-Aug-91 PFG  SetPos will clobber it. *)

        DirectoryCache := F.UserBuffer;

        SetWrite(F);
        SetPos( F, 0, 0 );

        StartOfFileRecord.SexWordLow  := 1234H;
        StartOfFileRecord.SexWordHigh := 5678H;
        StartOfFileRecord.Application := "TL";  (* Write correct header *)
        StartOfFileRecord.Version     := 0;
        WriteRecord(F,SOF,ADR(StartOfFileRecord),SIZE(StartOfFileRecord));    (* File header. *)

        WITH DirectoryCache^ DO
            FOR i := 1 TO HowManyEntries DO
                WriteRecord(F,DIRR,ADR(Entries[i]),SIZE(Entries[i]));
            END;
        END;

        IF (res <> done) THEN       (* 1-Aug-91 PFG  Restore the error.  *)
            F.res := res;
        END;
    END;
END FlushDirectory;



    (*  EndFileOutput  -- Write an end of file marker. *)

PROCEDURE EndFileOutput       (VAR F               : File );
VAR
    i   : CARDINAL;

BEGIN
    WriteRecord(F,EOF,ADR(i),0);    (* File ender. *)
    FlushDirectory( F );
    InstallCloseProc( F, InputCloseProc );      (* 10-Jun-91 EGK/RSC *)
END EndFileOutput;



    (*  StartSubfileOutput -- Fill in a directory entry for the
                              indicated subfile.  The position
                              recorded is the current file position.
                              Write a subfile header. *)

PROCEDURE StartSubfileOutput  (VAR F               : File;
                                   SubfileNumber   : CARDINAL;
                                   Version         : CARDINAL);
VAR
    WasHigh, WasLow  : CARDINAL;
    DirectoryEntry   : ADirectoryEntry;
    SubfileHeader    : ASubfileHeader;

    DirectoryCache   : ADirectoryCachePtr;

    PROCEDURE EmptyCell() : BOOLEAN;
    VAR
        i   : CARDINAL;
    BEGIN
        i := 1;
        WITH DirectoryCache^ DO
            WHILE (i <= HowManyEntries) AND
                  (Entries[i].SubfileNumber <> EmptySubfileNumber) DO
                INC(i);
            END;
            IF (i > HowManyEntries) THEN
                RETURN FALSE;
            END;
            Entries[i].SubfileNumber := SubfileNumber;
            WITH Entries[i] DO
                High      := WasHigh;
                Low       := WasLow;
                VersionNo := Version;
            END;
        END;
        RETURN TRUE;
    END EmptyCell;

BEGIN
    DirectoryCache := F.UserBuffer;
    IF (DirectoryCache = NIL) THEN
        FatalError();
    END;

    GetPos(F,WasHigh,WasLow);

    IF (EmptyCell()) THEN
        SubfileHeader.SubfileNumber := SubfileNumber;
        WriteRecord(F,SOSF,ADR(SubfileHeader),SIZE(SubfileHeader));
    ELSE
        BadStructure(F);   (* Not enough directory entries were preallocated. *)
    END;
END StartSubfileOutput;







    (* EndSubfileOutput -- Write an end of subfile mark. *)

PROCEDURE EndSubfileOutput  (VAR F               : File;
                                 SubfileNumber   : CARDINAL  );
BEGIN
    WriteRecord(F,EOSF,ADR(SubfileNumber),SIZE(SubfileNumber));
END EndSubfileOutput;





PROCEDURE OutputCloseProc( P : AFilePointer );
BEGIN
    IF (P^.UserBuffer <> NIL) THEN
             (* Write out the directory, which we have been keeping
                in memory until now. *)

        FlushDirectory(P^);

             (* This is needed to flush buffers, as FileSystem
                allready thinks it has done so!  (We are in the midst
                of Close() ing the file)
             *)
        Doio( P^ );

        DEALLOCATE( P^.UserBuffer, TSIZE(ADirectoryCache) );
    END;
END OutputCloseProc;








    (* StartFileInput -- Check the file for valid format *)

PROCEDURE StartFileInput      (VAR F               : File     ):BOOLEAN;
VAR
    Type              : CARDINAL;
    StartOfFileRecord : AStartOfFileRecord;
    DirectoryCache    : ADirectoryCachePtr;
    DirectoryEntry    : ADirectoryEntry;
BEGIN

    PrepareForIO(F);                                               (* 11/12/86 LAA *)
    Reset(F);                   (* 2/8/89 EGK *)
    SetRead(F);
    SetPos(F,0,0);

    (* 27-Jan-91 RSC Added the directory cache.
       13-Feb-91 RSC Allow for an allready-open file.  This is used by
                     printing overlays.
    *)
    IF (F.UserBuffer = NIL) THEN
        ReadRecord(F,Type,ADR(StartOfFileRecord),SIZE(StartOfFileRecord));
        IF (NOT FileOK(F)) THEN RETURN FALSE; END;
        IF (Type <> SOF) OR
           (StartOfFileRecord.Application[0] <> "T") OR
           (StartOfFileRecord.Application[1] <> "L") THEN
            BadStructure(F);
            RETURN FALSE;
        END;

        IF (NOT Available(TSIZE(ADirectoryCache))) THEN RETURN FALSE; END;
        NEW(DirectoryCache);
        F.UserBuffer := DirectoryCache;

        InstallCloseProc( F, InputCloseProc );

        WITH DirectoryCache^ DO
            SizeInBytes    := TSIZE(ADirectoryCache);
            Sex32Positive  := (StartOfFileRecord.SexWordHigh = 5678H);  (* 20-Feb-91 RSC moved from above *)
            HowManyEntries := 0;
            LOOP
                ReadRecord(F,Type,ADR(DirectoryEntry),
                               TSIZE(ADirectoryEntry));
                IF (NOT FileOK(F)) THEN
                    RETURN FALSE;
                END;
                IF (Type <> DIRR) OR
                        (* 31-May-91 RSC  *)
                   (DirectoryEntry.SubfileNumber = EmptySubfileNumber) THEN
                    RETURN TRUE;    (* We are done reading dir entries. *)
                END;

                INC(HowManyEntries);
                IF (HowManyEntries > MaxDirectoryEntries) THEN
                    FatalError();
                END;

                Entries[HowManyEntries] := DirectoryEntry;
            END;
        END;
    ELSE
        InstallCloseProc( F, InputCloseProc );  (* 5-Mar-91 RSC *)
    END;

    RETURN TRUE;

END StartFileInput;








    (* StartSubfileInput -- Position to the correct spot to begin
                            reading subfile data. *)

PROCEDURE StartSubfileInput   (VAR F               : File;
                                   SubfileNumber   : CARDINAL;
                               VAR Version         : CARDINAL):BOOLEAN;
VAR
    i               : CARDINAL;
    Type            : CARDINAL;
    DirectoryCache  : ADirectoryCachePtr;
    SubfileHeader   : ASubfileHeader;
BEGIN
    DirectoryCache := F.UserBuffer;
    IF (DirectoryCache = NIL) THEN
        FatalError();
    END;

    WITH DirectoryCache^ DO
        i := 1;
        WHILE (i <= HowManyEntries) AND
              (Entries[i].SubfileNumber <> SubfileNumber) DO
            INC(i);
        END;
        IF (i > HowManyEntries) THEN
            RETURN FALSE;
        END;
    END;

    WITH DirectoryCache^.Entries[i] DO
        Version := VersionNo;
            (* Set the position.  Make allowances for different orders
               of high-vs low 16 bits. *)
        IF (DirectoryCache^.Sex32Positive) THEN
            SetPos(F,High, Low);
        ELSE
            SetPos(F,Low, High);
        END;
        IF (NOT FileOK(F)) THEN
            RETURN FALSE;
        END;
        ReadRecord(F,Type,ADR(SubfileHeader),SIZE(SubfileHeader));
        IF (NOT FileOK(F)) THEN RETURN FALSE; END;
        IF (Type <> SOSF) OR (SubfileHeader.SubfileNumber <> SubfileNumber) THEN
            BadStructure(F);
            RETURN FALSE;   (* RSC 1/10/89 was TRUE. *)
        END;

        RETURN TRUE;
    END;

END StartSubfileInput;




  (* Traverse Subfiles - For each subfile in a file of subfiles,
                         invoke a client procedure to notify it of
                         the subfile's existance.  The client procedure
                         may make file accesses, as in to read the subfile.
                         RSC 1/10/89.
   *)
PROCEDURE TraverseSubfiles  ( VAR F         : File;
                                  CallMe    : ASubfileTraverseProc;
                                  Context   : ADDRESS );
VAR
    i               : CARDINAL;
    Type            : CARDINAL;
    DirectoryCache  : ADirectoryCachePtr;
    SubfileHeader   : ASubfileHeader;
BEGIN
    DirectoryCache := F.UserBuffer;
    IF (DirectoryCache = NIL) THEN
        FatalError();
    END;

    WITH DirectoryCache^ DO
        FOR i := 1 TO HowManyEntries DO
            IF (NOT CallMe( F, Entries[i].SubfileNumber,
                               Entries[i].VersionNo,
                               Context )) THEN
                RETURN;
            END;
        END;
    END;

END TraverseSubfiles;



END Subfiles.
