IMPLEMENTATION MODULE FileSystem;


(* --------------------------------------------------------------

    RSC 10/8/90

    This version of the file system is based on the underlying
    support of DOSIO.

    I use a small subset of the File structure in the old FileSystem.
    I preserve the meaning of "res" and "eof" for compatability
    with older client code.

    The "bufa" parameter points to the new structures.

    21-Jan-91 RSC Integrated into EVE.
    24-Jan-91 RSC Keep only one IO buffer on the theory that we
                  seldom have more than one file actually being
                  used at a time.  If we did, this could cause
                  excess flushing and re-reading of the buffer.
    25-Feb-91 RSC ReadNBytes could sometimes get into a loop at the end
                  of the file.
     6-Mar-91 RSC Tightened up EOF reading in text files.
    23-Apr-91 RSC When doing a SetPos, reset the EOF flag (be optimistic).
     1-May-91 RSC 1) On ReadChar, do not declare the file to be a text file.
                     Only WriteChar does this.  This is more of an optimization
                     than a logic fix, but should you ReadChar(file) and then
                     WriteNBytes(file) we will no longer put an EOF at the end.
                     Only if you WriteChar.

                  2) It is not always true that a text file being closed
                     is positioned at the end of the file.  Therefore,
                     writing an EOF at the CURRENT POSITION is a bad thing.
                     Now, I get the file length and set the position there.
                     THEN write the EOF (CTRL-Z)

                  3) When writing a partial buffer, remember that our
                     Offset values are 1 based, not 0 based.
    06-Sep-91 LAA SetRead was not setting the read flag, resulting in Again
                  never pushing a read-ahead character back for re-reading.
                  This was causing a problem with the dBase3 importer,
                  because it was using ReadChar.  I've re-instituted the use 
                  of the rd and wr flags, although they're mostly for 
                  informational purposes.  I also fixed ReadChar to
                  push back a read-ahead character by repositioning the file.
   -------------------------------------------------------------- *)




FROM Directory  IMPORT
    (* PROCS *)     DOSVersion;

FROM Dialog     IMPORT
    (* PROC *)      FatalError;

FROM DOSIO      IMPORT
    (* TYPE *)      ADOSFileHandle, ACloseProc,
    (* PROC *)      DOSRead, DOSWrite, DOSClose, DOSDelete,
                    DOSShortWrite, DOSOpenRaw, InstallDOSCloseProc,
                    CacheDOSFile, TranslateFileStringForDOS, DOSRefresh;

FROM LStrings   IMPORT
    (* PROC *)      ConcatS, CtoS, Overlay, LengthOf, LStringToTString,
                    TStringToLString;
     
FROM Space      IMPORT
    (* PROC *)      Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM     IMPORT
    (* CONST *)     CX,
    (* TYPE *)      WORD, BYTE, ADDRESS,
(*    REGISTERS, FLAGS,*)
    (* PROC *)      ADR, SIZE, TSIZE, DOSCALL, CODE, SETREG;
(*    INT;*)





CONST
    cr                = 15C;
    lf                = 12C;
    EOL               = 36C;


    RecordSize        =  1024; (* Any power of 2, pref. sector size *)

    LRecordSize       = VAL(LONGINT,RecordSize);

    ValidFileHandle   = 41665; (* Gale's birthday.  See Wayne. *)
    MAXCARDINAL       = 65535;
    OSEOF             =   32C; (* = 1AH; that's the eof code of the
                                         underlying operating system. *)



TYPE

    (* A File Buffer is what is pointed to by "bufa" in "File".
    *)
    AFileBuffer = RECORD

            (* The record that is now in the buffer is called the
               CurrentRecord.  If 0, there is no valid record in
               the buffer.

               The CurrentOffset is the valid number of bytes written
               into the buffer if in write mode, or the last read byte
               if in read mode.  If 0, no bytes have been read or
               written in this buffer.
            *)
        CurrentRecord,
        CurrentOffset   : CARDINAL;

            (* The desired next bytes to be read or written are to be
               at record NewRecord and offset NewOffset.

               Record 1 is the first record in the file.
               Offset 1 is the first byte in the record.

               This is explicitly set by SetPos and implicitly set
               by read and write operations to be the NEXT byte to
               be read or written.

               Reads read at the offset then increment it.
               Writes write to the offset then increment it.
               If the offset is RecordSize + 1, then
                   The RecordNumber is incremented and Offset set to 1.
            *)
        NewRecord,
        NewOffset       : CARDINAL;

        Handle          : ADOSFileHandle;

        BufferDirty,
        WriteMode       : BOOLEAN;
    END;

    AFileBufferPtr  = POINTER TO AFileBuffer;



VAR
    NextTempFile,
    CurrentTempFiles : CARDINAL;

    IOBuffer         : ARRAY [1..RecordSize] OF BYTE;
    IOBuffersFile    : AFileBufferPtr;





PROCEDURE SetResponse(VAR f: File; resp: Response);
BEGIN 
    WITH f DO 
        res := resp;
        IF resp <> done THEN  
            eof   := TRUE; 
            flags := flags + FlagSet{er, ef};
        ELSIF eof THEN
            flags := flags + FlagSet{er, ef};
            res   := notdone;
        END;
    END;
END SetResponse; 





  (* Valid Handle - Is the given File structure valid?  It is probably if
                    The tag we put there is there and the file is open
                    (DOS handle > 0).
                    A better scheme might be a CRC, but ....
  *)
PROCEDURE ValidHandle( VAR f : File;
                       VAR P : AFileBufferPtr ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
BEGIN
    WITH f DO
        P  := bufa;
        ok := (mHint = ValidFileHandle) AND
              (bufa <> NIL)             AND
              (bufa^.Handle.Handle > 0);

        IF (NOT ok) THEN
            res := unknownfile;
        END;
    END;

    RETURN ok;

END ValidHandle;








PROCEDURE InitializeHandle( VAR f : File;
                            VAR P : AFileBufferPtr ) : BOOLEAN;
BEGIN
    WITH f DO
        mHint                := ValidFileHandle; (* secret Tag to make valid *)

        bufa                 := NIL;             (* No buffer yet *)

        flags                := FlagSet{};       (* No flags yet *)

        fAttribAfterCreation := NormalAttribute; (* Change to this on CLOSE *)
        mt[0]                := "P";             (* Permanant file *)

        eof                  := FALSE;
        res                  := done;
        UserBuffer           := NIL;

        IF (Available(TSIZE(AFileBuffer))) THEN
            NEW( P );
            bufa := P;
            WITH P^ DO

                CurrentRecord := 0; (* No current record *)
                CurrentOffset := 0; (* No current offset *)
                NewRecord     := 1; (* An implicit "SetPos(f,0,0)" *)
                NewOffset     := 1;

                Handle.Handle := 0; (* Not open *)
                BufferDirty   := FALSE; (* Clean as a whistle  *)
                WriteMode     := FALSE; (* Read mode for now   *)
                Handle.FileError := done;
            END;
        ELSE
            res  := notdone;
        END;
    END;

    RETURN (f.bufa <> NIL);

END InitializeHandle;






PROCEDURE DeInitializeHandle( VAR f : File );
BEGIN
    WITH f DO
        IF (bufa <> NIL) AND
           (mHint = ValidFileHandle) THEN
            IF (IOBuffersFile = bufa) THEN
                IOBuffersFile := NIL;
            END;
            DISPOSE(bufa);
            bufa := NIL;
        END;

        mHint := 0; (* INVALIDATE FILE HANDLE *)
    END;

END DeInitializeHandle;







PROCEDURE Create (VAR f: File; mediumName: ARRAY OF CHAR); 
VAR
    LengthOfS   : CARDINAL;
    s           : ARRAY [0..9]  OF CHAR;
    TFileName,
    FileName    : ARRAY [0..99] OF CHAR;
BEGIN

    TStringToLString( mediumName, FileName );

    (*$R-*)
    INC(NextTempFile);
    (*$R=*)

    ConcatS( FileName, ".\TEMP0000.ZZZ" );
    CtoS(    NextTempFile, s );
    LengthOfS := LengthOf(s);
    Overlay( FileName, s, LengthOf(FileName) - (3 + LengthOfS), LengthOfS);

    LStringToTString( FileName, TFileName );

    CreateFile( f, TFileName, NormalAttribute );

    IF (f.res = done) THEN
        f.mt[0] := "T"; (* TEMP FILE - DELETE ON CLOSE! *)
        INC(CurrentTempFiles);
    END;

END Create;









PROCEDURE CreateFile (VAR f: File;     fileName  : ARRAY OF CHAR; 
                                       fileAttrib: CARDINAL     );
VAR
    P           : AFileBufferPtr;
    Attributes  : CARDINAL;
    FileName    : ARRAY [0..99] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    Attributes := ReadWriteMode;
    IF (DOSVersion() >= 0310H) THEN
        Attributes := Attributes + ExclusiveAccessMode;
    END;

    TStringToLString( fileName, FileName );

    IF (InitializeHandle( f, P )) THEN

        ok := DOSOpenRaw( FileName, P^.Handle,
                          Attributes,       TRUE, (* Create file? *)
                          RecordSize,       FALSE (* Display errors? *) );

        f.fAttribAfterCreation := fileAttrib;
        SetResponse( f, P^.Handle.FileError );
    END;

    IF (f.res <> done) THEN
        DeInitializeHandle( f );
    END;

END CreateFile;








(* Flush the current buffer if it is dirty, but do not alter the
   current buffer state or contents.
*)
PROCEDURE FlushIfDirtyBuffer();
VAR
    Size : CARDINAL;
    EOM  : BOOLEAN;
BEGIN

    IF (IOBuffersFile <> NIL) THEN
        WITH IOBuffersFile^ DO
            IF (BufferDirty) THEN

                Size := CurrentOffset;
                    (* 1-May-91 RSC *)
                IF (Size > 1) THEN
                    DEC(Size);      (* Our offsets are 1-based *)
                END;
                IF (Handle.BytesRead > Size) THEN
                    Size := Handle.BytesRead;
                ELSIF (Size > RecordSize) THEN
                    Size := RecordSize;
                END;

                BufferDirty := (NOT (DOSShortWrite( Handle,
                                                    CurrentRecord,
                                                    ADR(IOBuffer),
                                                    Size,
                                                    EOM ) AND
                                    (NOT EOM))
                               );
            END;
        END;
    END;

END FlushIfDirtyBuffer;





  
PROCEDURE Close (VAR f: File);
CONST
    GetSetAttFct = 43H;
VAR
    P             : AFileBufferPtr;
    H, L,
    ErrorCode     : CARDINAL;
(*    Regs          : REGISTERS;*)
(*    FileNameP     : ADDRESS;*)
    FileNameZ     : ARRAY [0..127] OF CHAR;
BEGIN
    f.res := done;

    IF (ValidHandle( f, P )) THEN

        WITH P^ DO
            IF (txt IN f.flags) AND (WriteMode) THEN

                  (* We are closing a TEXT-FILE after writing
                     at the eof-position (we hope).
                  *)
                Length(f,H,L);  (* 1-May-91 RSC go to the END *)
                SetPos(f,H,L);
                WriteByte( f, OSEOF );
            END;

            IF (P = IOBuffersFile) THEN
                FlushIfDirtyBuffer();
            END;

            IF (DOSClose( Handle )) THEN
                IF (f.mt[0] = "T") THEN (* Temp file. *)
                    IF (DOSDelete( Handle )) THEN
                        DEC(CurrentTempFiles);
                        IF (CurrentTempFiles = 0) THEN
                            NextTempFile    := 0; (* Reset next temp file number. *)
                        END;
                    END;
                ELSIF (f.fAttribAfterCreation <> NormalAttribute) THEN
                    LStringToTString( Handle.FileName, FileNameZ );

(*                    FileNameP := ADR(FileNameZ);*)
(*                    Regs.AH   := GetSetAttFct;*)
(*                    Regs.AL   := 1;  (* SET *)*)
(*                    Regs.CX   := f.fAttribAfterCreation;*)
(*                    Regs.DS   := FileNameP.SEGMENT;*)
(*                    Regs.DX   := FileNameP.OFFSET;*)

(*                    INT( 21H, Regs );*)

(*                    IF (CarryFlag IN Regs.FLAGSET) THEN*)
(*                        ErrorCode := Regs.AX;*)
(*                    ELSE*)
(*                        ErrorCode := 0;*)
(*                    END;*)

                    DOSCALL( GetSetAttFct, ADR(FileNameZ), 1 (* SET *), f.fAttribAfterCreation, ErrorCode );

                END;
            END;
        END;

        SetResponse( f, P^.Handle.FileError );
    END;

    DeInitializeHandle( f );

END Close;







PROCEDURE OpenFile (VAR f: File; fileName: ARRAY OF CHAR; fileMode: CARDINAL);
VAR
    P           : AFileBufferPtr;
    FileName    : ARRAY [0..99] OF CHAR;
    ok          : BOOLEAN;
BEGIN

    TStringToLString( fileName, FileName );

    IF (InitializeHandle( f, P )) THEN

        ok := DOSOpenRaw( FileName, P^.Handle,
                          fileMode,         FALSE, (* Create file? *)
                          RecordSize,       FALSE  (* Display errors? *) );

        SetResponse( f, P^.Handle.FileError );
    END;

    IF (f.res <> done) THEN
        DeInitializeHandle( f );
    END;

END OpenFile;







PROCEDURE Lookup (VAR f: File; fileName: ARRAY OF CHAR; newFile: BOOLEAN);
BEGIN
    OpenFile( f, fileName, ReadWriteMode );  (* Try to open it. *)

    (* If we could not open the file, and they said it could be a new
       file, then try to create it.
    *)
    IF ((newFile) AND (f.res = unknownfile)) THEN
        CreateFile( f, fileName, NormalAttribute );
    END;
END Lookup;







  
PROCEDURE Rename (VAR f: File; newName : ARRAY OF CHAR);
CONST
    RenameFile     = 56H;
VAR
    ErrorCode     : CARDINAL;
(*    Regs          : REGISTERS;*)
(*    FileNameP     : ADDRESS;*)
    P             : AFileBufferPtr;
    OldName       : ARRAY [0..127] OF CHAR;
BEGIN

    IF (ValidHandle( f, P )) THEN
        f.mt[0] := "P"; (* PERM FILE - Don't delete it!! *)
        TranslateFileStringForDOS( P^.Handle.FileName, OldName );
        Close(f);
        IF (f.res = done) THEN

(*            Regs.AH   := RenameFile;*)

(*            FileNameP := ADR(OldName);*)
(*            Regs.DS   := FileNameP.SEGMENT;*)
(*            Regs.DX   := FileNameP.OFFSET;*)

(*            FileNameP := ADR(newName);*)
(*            Regs.ES   := FileNameP.SEGMENT;*)
(*            Regs.DI   := FileNameP.OFFSET;*)

(*            INT( 21H, Regs );*)

(*            IF (CarryFlag IN Regs.FLAGSET) THEN*)
(*                ErrorCode := Regs.AX;*)
(*            ELSE*)
(*                ErrorCode := 0;*)
(*            END;*)

            DOSCALL( RenameFile, ADR( OldName ), ADR( newName ), ErrorCode );

            IF (ErrorCode = 0) THEN
                Lookup( f, newName, FALSE );
            ELSE
                Lookup( f, OldName, FALSE );
            END;
        END;

    END;

END Rename;







PROCEDURE Delete( name: ARRAY OF CHAR; VAR f: File);
CONST
    DeleteFile  = 41H;
VAR
    ErrorCode       : CARDINAL;
(*    Regs            : REGISTERS;*)
(*    FileNameP       : ADDRESS;*)
    LFileName,
    TFileName       : ARRAY [0..127] OF CHAR;
BEGIN

    TStringToLString( name, LFileName );
    TranslateFileStringForDOS( LFileName, TFileName );

(*    FileNameP := ADR(TFileName);*)
(*    Regs.AH   := DeleteFile;*)
(*    Regs.DS   := FileNameP.SEGMENT;*)
(*    Regs.DX   := FileNameP.OFFSET;*)

(*    INT( 21H, Regs );*)

(*    IF (CarryFlag IN Regs.FLAGSET) THEN*)
(*        ErrorCode := Regs.AX;*)
(*    ELSE*)
(*        ErrorCode := 0;*)
(*    END;*)

    DOSCALL( DeleteFile, ADR(TFileName), ErrorCode );
    
    IF (ErrorCode = 0) THEN
        WITH f DO
            eof := FALSE;
            res := done;
        END;
    ELSE
        SetResponse( f, notdone );
    END;

END Delete;







PROCEDURE GetOrSetAttribute(     fileName  : ARRAY OF CHAR; 
                             VAR fileAttrib: CARDINAL     ;
                             VAR f         : File         ;
                                 Get       : BOOLEAN     );
CONST
    GetSetAttFct = 43H;
VAR
    ErrorCode    : CARDINAL;
    GetOrSet     : CARDINAL;
(*    Regs         : REGISTERS;*)
(*    FileNameP    : ADDRESS;*)
BEGIN

(*    FileNameP := ADR(fileName);*)
(*    Regs.AH   := GetSetAttFct;*)
(*    IF (Get) THEN*)
(*        Regs.AL := 0; (* 0 = GET attr. *)*)
(*    ELSE*)
(*        Regs.AL := 1; (* 1 = SET attr. *)*)
(*    END;*)
(*    Regs.CX   := f.fAttribAfterCreation;*)
(*    Regs.DS   := FileNameP.SEGMENT;*)
(*    Regs.DX   := FileNameP.OFFSET;*)

(*    INT( 21H, Regs );*)

(*    IF (CarryFlag IN Regs.FLAGSET) THEN*)
(*        ErrorCode := Regs.AX;*)
(*    ELSE*)
(*        ErrorCode := 0;*)
(*    END;*)

    IF (Get) THEN
        GetOrSet := 0; (* 0 = GET attr. *)
    ELSE
        GetOrSet := 1; (* 1 = SET attr. *)
    END;
    DOSCALL( GetSetAttFct, ADR(fileName), GetOrSet, fileAttrib, ErrorCode );

    WITH f DO
        IF (ErrorCode <> 0) THEN
            CASE ErrorCode OF
                1  : res := callerror;
            |   2,
                3  : res := unknownfile;
            |   5  : res := accesserror;
            ELSE    
                res := notdone;
            END;
        ELSE
            res := done;
            eof := FALSE;
        END;
    END;

END GetOrSetAttribute;




  
PROCEDURE GetAttribute(     fileName  : ARRAY OF CHAR; 
                        VAR fileAttrib: CARDINAL     ;
                        VAR f         : File         );
BEGIN
    GetOrSetAttribute( fileName, fileAttrib, f, TRUE );
END GetAttribute;




  
PROCEDURE SetAttribute(     fileName  : ARRAY OF CHAR;
                            fileAttrib: CARDINAL     ;
                        VAR f         : File         );
BEGIN
    GetOrSetAttribute( fileName, fileAttrib, f, FALSE );
END SetAttribute;





PROCEDURE SetRead (VAR f: File);
BEGIN
    Doio(f);
    INCL(f.flags, rd);                                         (* 06-Sep-91 *)
    EXCL(f.flags, wr);
END SetRead;

  
PROCEDURE SetWrite (VAR f: File);
BEGIN
    Doio(f);
    EXCL(f.flags, rd);
    EXCL(f.flags, ag);
    INCL(f.flags, wr);
    (* TRUNCATE FILE AT CURRENT POSITION?? *)
END SetWrite;
  

PROCEDURE SetModify (VAR f: File);
BEGIN
    Doio(f);
    INCL(f.flags, rd);
    INCL(f.flags, wr);
END SetModify;

  
PROCEDURE SetOpen (VAR f: File);
BEGIN
    Doio(f);
    EXCL(f.flags, rd);
    EXCL(f.flags, ag);
    EXCL(f.flags, wr);
END SetOpen;




  
PROCEDURE Doio (VAR f: File);
VAR
    P   : AFileBufferPtr;
BEGIN
    IF (ValidHandle( f, P )) AND
       (P = IOBuffersFile) THEN
        FlushIfDirtyBuffer();
        SetResponse( f, P^.Handle.FileError );
    END;
END Doio;






PROCEDURE SetPos (VAR f: File; High, Low: CARDINAL);
VAR
    P           : AFileBufferPtr;
    RBA         : LONGINT;  (* Relative Byte Address *)
BEGIN

    RBA       := (VAL(LONGINT,High) * 65536L) + VAL(LONGINT,Low);

    IF (ValidHandle( f, P )) THEN
        P^.NewRecord := VAL(CARDINAL, RBA DIV LRecordSize ) + 1;
        P^.NewOffset := VAL(CARDINAL, RBA MOD LRecordSize ) + 1;
    END;

    f.res := done;  (* Give the file a new chance *)
    f.eof := FALSE;             (* 23-Apr-91 RSC ditto. *)

END SetPos;





PROCEDURE GetPos (VAR f: File; VAR High, Low: CARDINAL);
VAR
    P           : AFileBufferPtr;
    RBA         : LONGINT;  (* Relative Byte Address *)
BEGIN

    IF (ValidHandle( f, P )) THEN
        RBA :=  (VAL(LONGINT,P^.NewRecord - 1) * LRecordSize)
               + VAL(LONGINT,P^.NewOffset - 1);
    ELSE
        RBA := 0L;
    END;

    High := VAL(CARDINAL, RBA DIV 65536L );
    Low  := VAL(CARDINAL, RBA MOD 65536L );

END GetPos;







PROCEDURE Length (VAR f: File; VAR high, low: CARDINAL);
CONST
    SetPos      = 42H;
VAR
    ErrorCode   : CARDINAL;
(*    Regs        : REGISTERS;*)
    P           : AFileBufferPtr;
    CHigh,
    CLow        : CARDINAL; (* Current high and low *)
BEGIN

    IF (ValidHandle( f, P )) THEN
        WITH f DO

(*            Regs.AH   := SetPos;*)
(*            Regs.AL   := 2;  (* OFFSET FROM EOF *)*)
(*            Regs.BX   := P^.Handle.Handle;*)
(*            Regs.CX   := 0;*)
(*            Regs.DX   := 0;*)

(*            INT( 21H, Regs );*)

(*            IF (CarryFlag IN Regs.FLAGSET) THEN*)
(*                ErrorCode := Regs.AX;*)
(*            ELSE*)
(*                ErrorCode := 0;*)
(*                high      := Regs.DX;*)
(*                low       := Regs.AX;*)
(*            END;*)

            DOSCALL( SetPos, P^.Handle.Handle, 2, 0, 0,  high,  low, ErrorCode );

            IF (ErrorCode = 0) THEN
                IF (P^.WriteMode) THEN  (* May have written further *)
                    GetPos( f, CHigh, CLow );
                    IF (CHigh > high) OR
                      ((CHigh = high) AND (CLow > low)) THEN
                        high := CHigh;
                        low  := CLow;
                    END;
                END;
            ELSE
                SetResponse( f, notdone );
            END;
        END;
    END;

END Length;





PROCEDURE IWantTheBuffer( VAR f         : File;
                              P         : AFileBufferPtr ) : BOOLEAN;
BEGIN

    IF (P <> IOBuffersFile) THEN
        IF (IOBuffersFile <> NIL) THEN
            FlushIfDirtyBuffer();
        END;
        IOBuffersFile := P;
        WITH P^ DO
            CurrentOffset := 0;  (* Nothing of value in the buffer *)
            CurrentRecord := 0;

            (* If the buffer was not ours, then there may have
               prior errors flushing OUR buffer by the other
               user of the buffer.  Here we want to see if we
               had errors and save them into the file handle.
            *)
            SetResponse( f, Handle.FileError );
        END;
    END;

    RETURN (f.res = done);

END IWantTheBuffer;





PROCEDURE PositionBuffer( VAR f         : File;
                              P         : AFileBufferPtr;
                              ForWrite  : BOOLEAN );
VAR
    TempEof : BOOLEAN;

(* ******************
    PROCEDURE MaybeRead() : BOOLEAN;
    CONST
        SetPos      = 42H;
    VAR
        LastRecord,
        ErrorCode,
        High,
        Low         : CARDINAL;
        RBA         : LONGINT;
        TempEof,
        ok          : BOOLEAN;
    BEGIN
        DOSCALL( SetPos, P^.Handle.Handle, 2, 0, 0,  High,  Low, ErrorCode );
        IF (ErrorCode = 0) THEN
            RBA := (VAL(LONGINT,High) * 65536L) + VAL(LONGINT,Low);
        ELSE
            RBA := 0L;
        END;
        LastRecord := VAL(CARDINAL, RBA DIV LRecordSize ) + 1;

        WITH P^ DO
            IF (NewRecord > LastRecord) THEN
                Handle.BytesRead := 0;
                ok               := TRUE;
            ELSE
                ok := DOSRead( Handle, NewRecord, ADR(IOBuffer), TempEof );
            END;
        END;

        RETURN ok;

    END MaybeRead;
****************** *)

BEGIN
    IF (NOT IWantTheBuffer( f, P )) THEN
        RETURN;
    END;

    WITH P^ DO
        IF (NewOffset > RecordSize) THEN
            IF (NewOffset > (RecordSize + 1)) THEN
                FatalError();
            END; (* uh oh *)
            INC( NewRecord );
            NewOffset := 1;
        END;

        IF (CurrentRecord  = NewRecord) THEN
            CurrentOffset := NewOffset;
        ELSE
            FlushIfDirtyBuffer();
            IF (Handle.FileError = done) AND  (* My error? *)
               (DOSRead( Handle, NewRecord, ADR(IOBuffer), TempEof )) THEN

                    CurrentRecord := NewRecord;
                    CurrentOffset := NewOffset;

            ELSE
                SetResponse( f, Handle.FileError );
            END;
        END;

        IF (NOT ForWrite) AND (f.res = done) THEN
            f.eof := (NewOffset > Handle.BytesRead);
            IF (f.eof) THEN
                f.res := notdone;
            END;
        END;

            (* If we are writing, then we are probably at the end
               of the file, and so who cares!
            *)
    END;

END PositionBuffer;






PROCEDURE Reset(VAR f: File);
BEGIN 
    SetOpen(f);
    SetPos(f,0,0);
END Reset;







TYPE
    ResponseSet = SET OF Response; (* an auxiliary type *)



PROCEDURE MoveBlock ( src, dest : ADDRESS; count: CARDINAL);
CONST
    REPNZ   = 0F2H;
    MOVSB   = 0A4H;
    LDS     = 0C5H;
    LES     = 0C4H;
    SIviaBP = 76H;
    DIviaBP = 7EH;

BEGIN
    CODE (LDS, SIviaBP,10);
    CODE (LES, DIviaBP,6);
    SETREG (CX, count);
    CODE (REPNZ, MOVSB);
END MoveBlock;





PROCEDURE Again(VAR f: File);
BEGIN
    WITH f DO
        IF rd IN flags THEN
            INCL(flags, ag);
        END;
    END;
END Again;





PROCEDURE ReadByte (VAR f: File; VAR b: BYTE);
(*VAR*)
(*    P           : AFileBufferPtr;*)
BEGIN
(*    IF (ValidHandle( f, P )) THEN*)

    WITH f DO
        IF (NOT eof) AND (bufa <> NIL) THEN   (* 6-Mar-91 RSC  *)
            IF (ag IN flags) THEN
                EXCL(flags, ag);
                b := BYTE (CHR (lastRead));
            ELSE
                PositionBuffer( f, bufa, FALSE );
                IF (eof) THEN
                    b := BYTE(0);
                ELSE
                    WITH bufa^ DO
                        b := IOBuffer[CurrentOffset];
                        INC(NewOffset);  (* Request next byte for next time *)
                        CurrentOffset := NewOffset;
                    END;
                END;
                lastRead := ORD(b);
            END;
        ELSE
            b := BYTE(0);
        END;
    END;

END ReadByte;





PROCEDURE ReadChar (VAR f: File; VAR ch: CHAR);

VAR
    SaveHigh, SaveLow       : CARDINAL;

BEGIN
    ReadByte (f, ch);

    IF (ch = cr) THEN
        GetPos( f, SaveHigh, SaveLow );                        (* 06-Sep-91 *)
        ReadByte(f, ch); (* look ahead for a <lf> *)
        IF ch <> lf THEN (* too bad, no <lf>, so reset look ahead *)
            SetPos( f, SaveHigh, SaveLow );
            f.lastRead := ORD( cr );
        END;
        ch := EOL; (* map single <cr> or <cr><lf> into EOL *)
    ELSIF ch = lf THEN (* single <lf> mapped into EOL *)
        ch := EOL;
    ELSIF (ch = OSEOF) OR (f.eof) THEN  (* 6-Mar-91 RSC  *)
        f.eof := TRUE;
        ch    := 0C;
        f.lastRead := 0;
        INCL(f.flags, ef);
    END;

(*    INCL (f.flags, txt);*)    (* 1-May-91 RSC removed. *)

END ReadChar;





   
PROCEDURE ReadWord(VAR f: File; VAR w: WORD);

VAR 
    c : CHAR;

BEGIN
    IF (ag IN f.flags) THEN
        w := WORD(f.lastRead);
        EXCL (f.flags,ag);
    ELSE
        ReadByte (f, c);
        w := WORD(ORD (c));
        ReadByte (f, c);
        INC(w, ORD(c) * 256 );
        (* Note: a WORD is stored with lower byte first *)
        f.lastRead := CARDINAL(w);
    END;

END ReadWord;





PROCEDURE ReadNBytes (VAR f: File; bufPtr: ADDRESS;
                 requestedBytes: CARDINAL; VAR read: CARDINAL);
VAR
    P           : AFileBufferPtr;
    CopyCount   : CARDINAL;
BEGIN
    read := 0;

    IF (ag IN f.flags) THEN
        f.res := callerror; (* Caller code bug (Logi allowed this, though) *)
    END;

    IF (f.res = done) AND
       (ValidHandle( f, P )) THEN

            (* The requested bytes may span several buffers.
               So, figure out how many bytes are available to this
               buffer, and, if that is MORE than what we want, get
               the smaller amount.
            *)
        WITH f DO
            CopyCount := 1; (* Seed the loop  25-Feb-91 RSC *)
            WHILE (requestedBytes > 0) AND (NOT eof) AND (CopyCount > 0) DO
                PositionBuffer( f, P, FALSE );
                IF (NOT eof) THEN
                    WITH P^ DO
                        CopyCount := (Handle.BytesRead - CurrentOffset) + 1;
                        IF (CopyCount >  requestedBytes) THEN
                            CopyCount := requestedBytes;
                        END;
                        MoveBlock( ADR(IOBuffer[CurrentOffset]), bufPtr, CopyCount );
                        INC(bufPtr,CopyCount);           (* Increment the dest pointer *)
                        INC(NewOffset,      CopyCount);  (* New buffer position  *)
                        INC(read,           CopyCount);  (* We read more bytes   *)
                        DEC(requestedBytes, CopyCount);  (* And have fewer to go *)
                        CurrentOffset := NewOffset;
                    END;
                END;
            END;
        END;
    END;

END ReadNBytes;




PROCEDURE WriteByte(VAR f: File; b: BYTE);
(*VAR*)
(*    P           : AFileBufferPtr;*)
BEGIN
(*    IF (ValidHandle( f, P )) THEN*)

    WITH f DO
        IF (bufa <> NIL) THEN
            PositionBuffer( f, bufa, TRUE );

            (* SetResponse sets eof if res is not done
               everyone uses SetResponse, so.....
            *)
            IF (NOT eof) THEN
                WITH bufa^ DO
                    IOBuffer[CurrentOffset] := b;
                    INC(NewOffset);  (* Request next byte for next time *)
                    CurrentOffset := NewOffset;
                    WriteMode     := TRUE;
                    BufferDirty   := TRUE;
                END;
            END;
        END;
    END;

END WriteByte;





PROCEDURE WriteChar(VAR f: File; ch: CHAR);
BEGIN
    IF (ch = EOL) THEN
        WriteByte (f,cr);
        ch := lf;
    END;
    WriteByte (f, ch);

    INCL (f.flags, txt);

END WriteChar;





PROCEDURE WriteWord(VAR f: File; w: WORD);
BEGIN
    WriteByte (f, CHR (CARDINAL(w) MOD 256));
    WriteByte (f, CHR (CARDINAL(w) DIV 256));
END WriteWord;
   






PROCEDURE WriteNBytes (VAR f: File; bufPtr: ADDRESS;
            requestedBytes: CARDINAL; VAR written: CARDINAL);
VAR
    P           : AFileBufferPtr;
    CopyCount   : CARDINAL;
BEGIN
    written := 0;

    IF (ag IN f.flags) THEN
        f.res := callerror; (* Caller code bug (Logi allowed this, though) *)
    END;

    IF (f.res = done) AND
       (ValidHandle( f, P )) THEN

            (* The requested bytes may span several buffers.
               So, figure out how many bytes are available to this
               buffer, and, if that is MORE than what we want, use
               the smaller amount.
            *)
        WITH f DO
            WHILE (requestedBytes > 0) AND (res = done) DO (* 25-Feb-91 RSC *)
                PositionBuffer( f, P, TRUE );
                IF (res = done) THEN                       (* 25-Feb-91 RSC *)
                    WITH P^ DO
                        CopyCount := (RecordSize - CurrentOffset) + 1;
                        IF (CopyCount >  requestedBytes) THEN
                            CopyCount := requestedBytes;
                        END;
                        MoveBlock( bufPtr, ADR(IOBuffer[CurrentOffset]), CopyCount );
                        INC(bufPtr,CopyCount);           (* Increment the dest pointer *)
                        INC(NewOffset,      CopyCount);  (* New buffer position *)
                        INC(written,        CopyCount);  (* We wrote more bytes *)
                        DEC(requestedBytes, CopyCount);  (* And have fewer to go *)
                        CurrentOffset := NewOffset;
                        WriteMode     := TRUE;
                        BufferDirty   := TRUE;
                    END;
                END;
            END;
        END;
    END;

END WriteNBytes;








    PROCEDURE CreateMedium(mt: MediumType;
                           fproc: FileProc; dproc: DirectoryProc;
                           VAR done: BOOLEAN);
    BEGIN 
    END CreateMedium; 


    PROCEDURE RemoveMedium(mt: MediumType; VAR done: BOOLEAN);
    BEGIN
    END RemoveMedium; 







PROCEDURE FileNameChar (c: CHAR) : CHAR;
    (* Checks if 'c' is legal character for DOS-2.0 filename. *)
    (* Lowercase characters are transformed in uppercase.     *)
    (* Returns 0C if illegal                                  *)
BEGIN
    CASE c OF
      'A'..'Z', '0'..'9'  : RETURN (c);
    | 'a'..'z'            : RETURN (CAP(c));
    | '$', '&', '#', '@', '!', '%', "'", '`', '(', ')',
      '-', '_', '^', '~'  : RETURN (c);
    | '.', ':', '\'       : RETURN (c); (* for complete pathname *)
    ELSE                    RETURN (0C);
    END;
END FileNameChar;






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
PROCEDURE CacheFile( VAR Handle     : File;
                         CacheKB    : CARDINAL;
                         Priority   : CARDINAL );
VAR
    P           : AFileBufferPtr;
    Records     : CARDINAL;
BEGIN

    IF (ValidHandle( Handle, P )) THEN

        Records := VAL(CARDINAL,

                        (VAL(LONGINT, CacheKB) * 1024L) DIV LRecordSize

                      );

        CacheDOSFile( P^.Handle, Records, Priority );
    END;

END CacheFile;






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

    Output: Handle          Updated with the new information.
*)
PROCEDURE InstallCloseProc( VAR Handle          : File;
                                CloseProc       : AFileCloseProc );
VAR
    P           : AFileBufferPtr;
BEGIN

    IF (ValidHandle( Handle, P )) THEN

        InstallDOSCloseProc( P^.Handle, ACloseProc(CloseProc), ADR( Handle ) );
    END;

END InstallCloseProc;




BEGIN

    NextTempFile     := 0;
    CurrentTempFiles := 0;
    IOBuffersFile    := NIL;

END FileSystem.
