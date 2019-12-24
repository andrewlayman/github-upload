    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
(* T-*)
(* R-*)
(* O-*)
(****************************************************************)
(*                                                              *)
(*      MODULA-2/86 Library                                     *)
(*                                                              *)
(*        LOGITECH SA.,  CH-1143 Apples   (Switzerland)         *)
(*                                                              *)
(*      Module: DiskFiles                                       *)
(*        Provides the basic functions, needed by FileSystem,   *)
(*        for disk files. Files are implemented on MSDOS 2.0.   *)
(*        Drives "A" through "P" and the default drive are      *)
(*        supported by this driver. The corresponding medium    *)
(*        names are "A".."P" for specific drives and "DK" for   *)
(*        the default drive.                                    *)
(*        In the current implementation, there is a buffer of   *)
(*        512 bytes per opened file.                            *)
(*                                                              *)
(*      Version  2.02  (Feb '86)   for MS-DOS 2.0               *)
(*      Version  3.00  (July 87)                                *)
(*                                                              *)
(*      (C) Copyright 1983, 1984 Logitech,  All Rights Reserved *)
(*                                                              *)
(*      This program is a trade secret of Logitech, and it is   *)
(*      not to be reproduced, published, disclosed to others,   *)
(*      copied, adapted, distributed or displayed without the   *)
(*      prior authorization of Logitech.                        *)
(*                                                              *)
(*      Licensee agrees to attach or embed this notice on all   *)
(*      copies of the program, including partial copies or      *)
(*      modified versions thereof.                              *)
(****************************************************************)

(****************************************************************
    Modification History :
        14-Sep-88 WKH   Allocate file buffers dynamically instead of 
                        statically.
        27-Oct-88 WKH   Allocate entire file structure dynamically!!
        02-Nov-88 WKH   Give back file block after Get/SetAttrib
                        steals it.
        08-Nov-88 WKH   Fix GetFree so it really tells us that we're
                        out of memory for file block creation.
                        Also test first to see if a pointer is <> NIL
                        before we deallocate it.
        09-Nov-88 WKH   Added proc MakeSureNotOpen to disallow creates,
                        lookups, deletes, createfiles, openfiles,
                        getattribs, and setattribs on already open files.
        11-Nov-88 WKH   Set fHint = MAXCARDINAL after a successful operation.
                        Also set mHint to our "secret magic number" after a
                        GetFreeFile so that we can distinguish a valid file
                        handle from a non-initialized one.
        15-Nov-88 WKH   Nullify MakeSureNotOpen, too stringent.
        23-Jan-89 RSC   Changed Storage to Space    .
        05-Mar-89 WKH   Make this module "prettier".  Also make InitFile
                        handle new file locking field.
*****************************************************************)

IMPLEMENTATION MODULE DiskFiles;                (* WS, opje, AW *)

IMPORT RTSMain;

FROM SYSTEM                 IMPORT 
                                ADDRESS, DOSCALL, ADR, WORD, CODE, BX, CX, DI, 
                                GETREG, TSIZE;

FROM FileSystem             IMPORT 
                                File, Command, Response, Flag, FlagSet,
                                MediumType, CreateMedium, FileNameChar,
                                ReadWriteMode, NormalAttribute, ReadOnlyMode,
                                WriteOnlyMode, ExclusiveAccessMode,
                                AFileAccessRightSet, AFileAccessRight;

FROM Space                  IMPORT 
                                ALLOCATE, DEALLOCATE, Available;

CONST                         
    nul = 0C;

    MaxFiles     = 15; (* maximal number of opened files *)
     (* maximum of file handles under DOS, 20 minus 5 predefined *)
     (* Note: this limit could be removed by using dynamic variable
        ****  for the file-descriptors and the buffers.
     *)

    BufSize      = 100; (*bytes per buffer*)

    namelength   =79; (*maximum length for full file specification*)

    (* The function calls for the Operating System: *)
    CreateFct    = 3CH;
    OpenFct      = 3DH;
    CloseFct     = 3EH;
    ReadFct      = 3FH;
    WriteFct     = 40H;
    DeleteFct    = 41H;
    SetPosFct    = 42H;
    GetSetAttFct = 43H;
    RenameFct    = 56H;

    (* 10/27/88 Define some constants so things look a little nicer *)
    MAXCARDINAL  = 65535;

    (* 11/10/88 Here's our "secret magic tag number " *)
    SecretNumber = 2145;  (* Tom's girlfriend *)

TYPE
    (* Sep. 14, 1988 - WKH - buffers used to be statically allocated thus always
                        occupying a fixed amount of memory.  Now buffer memory
                        is dynamically allocated.
    *)
    Buffer      = ARRAY[0..BufSize-1] OF CHAR;

    FileStatus  = (opened, reading, modifying, writing);

    FileName    = ARRAY [0..namelength-1] OF CHAR;

    FileDesc    = RECORD
                    inUse      : BOOLEAN;    (* indicates, if this descriptor
                                                is used *)
                    tempFile   : BOOLEAN;    (* if TRUE, the file will be 
                                                destroyed upon a close *)
                    FileHandle : WORD;       (* used by DOS 2.0 for all calls
                                                to an open file*)
                    eofh       : CARDINAL;   (* high and low parts of eof 
                                                pointer, used...*)
                    eofl       : CARDINAL;   (* by length function and by setpos*)
                    FileDesig  : FileName;   (* actual file specification*)
                    state      : FileStatus; (* redundant, derived from "flags" *)
                    owner      : CARDINAL;   (* program identifier of the current
                                                layer, when the file was opened *)
                    written    : BOOLEAN;    (* TRUE, if the file was once in 
                                                writing state *)
                    buffer     : Buffer;     (* its data is the 512 byte block 
                                                read/written to the file*)
                    count      : CARDINAL;   (* buffer count so we don't have to 
                                                emulate CP/M!*)
                  END;

    FileDescPtr = POINTER TO FileDesc;

    BufAddr     = RECORD
                    CASE BOOLEAN OF
                      TRUE  : addr         : ADDRESS;
                    | FALSE : offset, base : CARDINAL
                    END
                  END;


VAR
  files                     : ARRAY [0..MaxFiles-1] OF FileDescPtr;
  dosMajor, dosMinor        : CHAR;
  dos2                      : BOOLEAN; (* will be TRUE if DOS version less than 3.0 *)


(******************************************************************)

PROCEDURE ValidateFile(index : CARDINAL);

BEGIN
    IF (files[index] = NIL) THEN
        HALT;
    END;
END ValidateFile;


PROCEDURE InitDiskSystem;

VAR 
    i                       : CARDINAL;
    response                : BOOLEAN;
    drive                   : MediumType;

BEGIN
    (* Install the mediums. 'DK' is the name of the default drive: *)
    CreateMedium ('DK ', DiskFileProc, DiskDirProc, response);

    (* The other 16 drives, supported by MSDOS are 'A' through 'P': *)
    drive[0] := 'A';  drive[1] := ' ';  drive [2] := ' ';

    (* MOE Feb 6'86 *)
    FOR i:=0 TO (ORD('Z') - ORD('A')) DO
        CreateMedium (drive, DiskFileProc, DiskDirProc, response);
        INC (drive[0]);
    END;

    (* If the program of this level (usually resident part) terminates,
        we have to remove all the mediums: *)
    RTSMain.InstallTermProc (TerminateLevel);

    FOR i:=0 TO MaxFiles-1 DO
        files[i] := NIL;  (* 10/27/88 WKH *)
    END;
END InitDiskSystem;


PROCEDURE TerminateLevel;

VAR 
    i, curProg, result      : CARDINAL;
    fAddr                   : BufAddr;

BEGIN
    curProg := RTSMain.curProcess^^.currOverlay^.programLevel;
    FOR i := 0 TO MaxFiles-1 DO
        IF (files[i] <> NIL) THEN (* 10/27/88 WKH *)
            WITH files[i]^ DO
                IF inUse THEN
                    (*IF owner = curProg THEN*)
                    (* we have to close it and to free its descriptor: *)
                    IF (NOT tempFile) AND written THEN 
                        ValidateFile(i);   (* 10/27/88 WKH  DEBUGGING *)
                        WriteBuffer (files[i]^, ADR(buffer), BufSize, result); (* 9/14/88 - WKH - Changed ADR(buffer) to buffer *)
                        (* since we don't have access to the 'File'
                        from 'FileSystem', we try to do the safest
                        operation: write default buffer, length=max.
                        *)
                    END;

                    DOSCALL(CloseFct,FileHandle,result);

                    IF tempFile THEN
                        DOSCALL(DeleteFct,ADR(FileDesig),result);
                    END;

                    inUse := FALSE;          

                    IF (files[i] <> NIL) THEN  (* 11/8/88 WKH *)
                        DEALLOCATE(files[i], TSIZE(FileDesc));
                    END;
                    (*END;*)
                END;
            END; (* WITH *)
        END;
    END; (* FOR *)
END TerminateLevel;


(******************************************************************)

MODULE FileOperations;

IMPORT 
    ADDRESS, DOSCALL, ADR, WORD,
    files, File, FileDesc, FileStatus,
    Command, Response, Flag, FlagSet,
    MaxFiles, ReadFct, WriteFct, SetPosFct,
    BufAddr, BufSize, ReadOnlyMode, WriteOnlyMode, ValidateFile, MAXCARDINAL, TSIZE;

EXPORT 
    WriteBuffer, DiskFileProc;


PROCEDURE SetError (VAR f: File; errorCode: Response);
BEGIN
    WITH f DO
        res         := errorCode;
        eof         := TRUE;
        validlength := 0;
        flags       := FlagSet {er,ef};
        ValidateFile(fHint);     (* 10/27/88 WKH  DEBUGGING *)
        files[fHint]^.state := opened;
    END;
END SetError;


PROCEDURE RePos(VAR f:File); 
(* Reposition a file at point before last read *)
(* The effect is that the current position (known by the OS)
   is the one of the first byte in the buffer of DiskFile.
   If later we are going to write the buffer to the file, it
   will be placed there with the right offset.
*)
VAR 
    high, low, n, error     : CARDINAL; 
    handle                  : WORD;

BEGIN
    ValidateFile(f.fHint);  (* 10/27/88 WKH  DEBUGGING *)  
    n:=files[f.fHint]^.count;
    IF n>0 THEN
        handle := files[f.fHint]^.FileHandle;
        DOSCALL (SetPosFct, handle, 01, 0,0, high,low, error);
        (* position file at zero offset from current place *)
        IF low<n THEN 
            DEC(high) 
        END;    
        low:=low-n;
        DOSCALL (SetPosFct, handle, 00, high,low, high,low, error);
        (* position file at absolute position 'high,low' *)
    END
END RePos;

 
(****************************************************************)

PROCEDURE WriteBuffer (VAR fDesc     : FileDesc; 
                           bufptr    : ADDRESS; 
                           bufLength : CARDINAL; 
                       VAR response  : CARDINAL);

VAR 
    error                   : CARDINAL;

BEGIN
    response:=0;
    IF bufLength>0 THEN
        DOSCALL (WriteFct, fDesc.FileHandle, bufLength, bufptr,
                response, error);
        IF error=0 THEN 
            IF response=bufLength THEN 
                response:=0
            ELSE
                response:=1;
            END;
        ELSE 
            response := error;
        END;
    END;
END WriteBuffer;

PROCEDURE ReadBuffer (VAR f: File);

VAR 
    result, error           : CARDINAL;

BEGIN
    ValidateFile(f.fHint);  (* 10/27/88 WKH  DEBUGGING *)
    DOSCALL (ReadFct, files[f.fHint]^.FileHandle, f.buflength, f.bufa, (* AW June 5th, 87 *)
            result, error);
    IF (error<>0) THEN
        IF (error=5) THEN
            f.res:=accesserror;
        ELSE
            f.res:=notdone;
        END;
        f.eof:=TRUE;
        result := 0;
        INCL (f.flags,ef);
    ELSIF (result=0) THEN
        f.eof:=TRUE;
        INCL (f.flags,ef);
    END;
    f.validlength:=result;
    files[f.fHint]^.count:=result
END ReadBuffer;


PROCEDURE DiskFileProc (VAR f: File);

VAR 
    response, index, cposL, cposH, error : CARDINAL;

BEGIN
    WITH f DO
        IF ((fHint >= MaxFiles) OR (files[fHint] = NIL)) THEN
            res := paramerror;
            flags := FlagSet {er,ef};
            RETURN;
        END;

        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)

        WITH files[fHint]^ DO
            CASE com OF
                setread   : IF (fMode MOD 8) = WriteOnlyMode THEN
                                SetError( f, accesserror );
                            ELSE
                                res := done;  
                                EXCL (flags, er);
                                CASE state OF
                                    opened    : ReadBuffer (f);
                                |   reading   : INCL(flags, rd); RETURN;
                                |   writing, 
                                    modifying : WriteBuffer (files[fHint]^, bufa,
                                                              bufind, response);
                                                (* we write the buffer back in any case *)
                                                count := bufind;
                                                IF (response=5) THEN
                                                    res := accesserror; 
                                                ELSIF (response=6) THEN
                                                    res:=notdone; 
                                                ELSIF (response <> 0) THEN
                                                    res := eom;
                                                ELSE
    (* May 24'85 MOE *)
                                                    IF bufind >= BufSize THEN
                                                        (* current pos is not in the buffer *)
                                                        ReadBuffer (f);
                                                        bufind:=0; (* as for doio *)
                                                    ELSIF (state=modifying) THEN
                                                        (* simulate sequential reading: *)
                                                        DOSCALL (SetPosFct, FileHandle, 01,
                                                                 0, validlength-bufind, cposH, cposL, error);
                                                        (* set DOS position to the last read
                                                                       byte in buffer. *)
                                                   END;
    (* May 24'85 MOE *)
                                                END;
                                END; (* CASE *)
                                IF res = done THEN
                                    flags := FlagSet {rd};
                                    state := reading;
                                    eof := FALSE;
                                ELSE 
                                    SetError (f, res);
                                END;
                            END;

            |   setwrite  : IF (fMode MOD 8) = ReadOnlyMode THEN
                                SetError( f, accesserror );
                            ELSE
                                IF state = reading THEN 
                                    RePos(f) 
                                END;
                                res         := done;
                                flags       := FlagSet {ef, wr};
                                eof         := TRUE;
                                state       := writing;
                                written     := TRUE;
                                validlength := bufind; (* soft truncate *)
                                (* truncate the file physically! (not yet implem.) *)
                            END;

            |   setmodify : IF ( (fMode MOD 8 ) = ReadOnlyMode  ) OR
                                ( (fMode MOD 8 ) = WriteOnlyMode ) THEN
                                SetError( f, accesserror );
                            ELSE
                                res := done;  
                                EXCL (flags, er);
                                IF state = reading THEN 
                                    RePos(f) 
                                END;
                                IF state = opened THEN
                                    ReadBuffer (f); 
                                    RePos(f) (*set file back for write*)
                                END;
                                IF res = done THEN
                                    eof     := FALSE;
                                    flags   := FlagSet {rd, wr};
                                    state   := modifying;
                                    written := TRUE;
                                ELSE
                                    SetError (f, res)
                                END;
                            END;

            |   setopen   : response := 0;
                            IF (wr IN flags) THEN
                                WriteBuffer (files[fHint]^,bufa,
                                            bufind, response);
                                validlength := 0;
                                bufind      := 0;
                                (* the buffer will be considered non-initialized *)
                            END;
                            IF (response=5) THEN
                                res:=accesserror;
                            ELSIF (response=6) THEN
                                res:=notdone;
                            ELSIF (response <> 0) THEN  
                                SetError (f, eom);
                            ELSE
                                IF res <> eom THEN
                                    (* keep the result 'eom', because the 'setopen' can
                                       be used as a sort of flush (force the writing of
                                       buffers).
                                    *)
                                    res   := done;
                                    eof   := FALSE;
                                    flags := FlagSet {};
                                END;
                            state := opened
                            END;

            |   doio      : IF res <> eom THEN
                                res := done;  
                                EXCL (flags, er);
                            END;
                            IF (wr IN flags) THEN
                                WriteBuffer (files[fHint]^,bufa, bufind, response);
                                IF (response=5) THEN
                                    res    := accesserror;
                                ELSIF (response=6) THEN 
                                    res    :=notdone;
                                ELSIF response <> 0 THEN
                                    res    := eom
                                ELSE 
                                    bufind := 0
                                END
                            END;
                            IF (rd IN flags) THEN
                                IF bufind=BufSize THEN
                                    bufind:=0
                                END;
                                ReadBuffer (f);
                                IF state=modifying THEN 
                                    RePos(f) 
                                END
                            END;
                            IF res <> done THEN 
                                SetError (f, res); 
                            END;

            |   setpos    : res := done;  
                            EXCL (flags, er);
                            IF (wr IN flags) THEN
                                WriteBuffer(files[fHint]^,bufa,bufind,response);
                                IF (response=5) THEN
                                    res:=accesserror;
                                ELSIF (response=6) THEN
                                    res:=notdone;
                                ELSIF response<>0 THEN 
                                    res:=eom 
                                END
                            END;
                            IF res=done THEN
                                bufind:=0;
                                DOSCALL (SetPosFct, FileHandle, 02 (*eof*),
                                         0,0, eofh,eofl, error);
                                IF ((lowpos>eofl) AND (highpos=eofh)) OR
                                    (highpos>eofh) THEN
                                    (*if you tried to position past eof...*)
                                    SetError(f,paramerror); (* set the error flags *)
                                    highpos := eofh; (*and reset your call values*)
                                    lowpos  := eofl;  (*to position AT eof.*)
                                ELSIF state=writing THEN  (* writing always at EOF *)
                                    eof:=TRUE;  
                                    INCL (flags, ef);
                                ELSE
                                    eof:=FALSE;  
                                    EXCL (flags, ef);
                                END;
                                cposH:=highpos; cposL:=lowpos; (* it's easier for compiler! *)
                                DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
                                                                   cposH,cposL, eofh,eofl, error);
                                IF error <> 0 THEN 
                                    res:=notdone;
                                ELSIF (rd IN flags) THEN
                                    ReadBuffer (f);
                                    eof:=FALSE; EXCL(flags,ef);  (* per definition *)
                                    IF state=modifying THEN 
                                        RePos(f) 
                                    END
                                ELSIF state = writing THEN
                                    validlength := bufind; (* soft truncate *)
                                    (* truncate the file physically! (not yet implem.) *)
                                END;
                            END;
                            IF res <> done THEN 
                                SetError (f, res); 
                            END;
                     
            |   getpos    : DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
                                     0,0,(*offset 0*) highpos,lowpos, error);
                            IF (wr IN flags) THEN
                                (* The physical position is the one of last writing,
                                   i.e we have to add the number of bytes in buffer: *)
                                (*$R-  wrap around: *) lowpos:=lowpos+bufind; (*$R=*)
                                IF lowpos<bufind THEN 
                                    highpos:=highpos+1 
                                END
                            ELSIF (rd IN flags) THEN
                                (* If sequential reading, the physical position is
                                   the one of the last byte in buffer: *)
                                IF lowpos < (validlength-bufind) THEN
                                    highpos:=highpos-1; (* there is a wrap-around *)
                                END;
                                (*$R-*) lowpos:=lowpos-(validlength-bufind); (*$R=*)
                            END;
                            res := done;  
                            EXCL (flags, er);

            |   length    : DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
                                     0,0,(*offset 0*) cposH,cposL, error);
                            IF (wr IN flags) THEN
                                (* add the bytes in the buffer to be written: *)
                                (*$R-*) lowpos := cposL + bufind; (*$R=*)
                                IF lowpos < cposL THEN 
                                    highpos:=cposH+1;
                                ELSE 
                                    highpos:=cposH; 
                                END
                            END;

                            IF state <> writing THEN
                                DOSCALL (SetPosFct, FileHandle, 02 (*eof*),
                                         0,0,(*offset 0*) eofh,eofl, error);
                                IF state = modifying THEN
                                    (* take the larger of the 2 pos (current or eof): *)
                                    IF eofh > highpos THEN 
                                        highpos := eofh; 
                                        lowpos  := eofl;
                                    ELSIF eofh=highpos THEN
                                        IF eofl>lowpos THEN 
                                            lowpos:=eofl 
                                        END;
                                    END;
                                ELSE (* reading or opened *)
                                    highpos := eofh; lowpos := eofl;
                                END;
                                DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
                                         cposH,cposL, cposH,cposL, error);
                            END;
                            res:=done;  
                            EXCL (flags, er);
            ELSE  
                res := notsupported;  
                INCL (flags, er);
            END; (* CASE *)
        END; (* WITH *)
    END; (* WITH *)
END DiskFileProc;

END FileOperations;


(**********************************************************************)


MODULE DirOperations;

IMPORT 
    RTSMain;

IMPORT 
    WriteBuffer, DOSCALL, ADR, WORD, ADDRESS, 
    CreateFct, OpenFct, CloseFct, DeleteFct, RenameFct, SetPosFct,
    GetSetAttFct, dos2,
    files, Flag, FlagSet, MediumType,
    File, FileName, FileDesc, FileStatus, Command, Response,
    FileNameChar, MaxFiles, nul, BufSize, namelength,
    ReadWriteMode, ExclusiveAccessMode, NormalAttribute,
    CODE, BX, CX, DI, GETREG, ValidateFile, MAXCARDINAL, TSIZE,
    SecretNumber, AFileAccessRight, AFileAccessRightSet;

IMPORT 
    ALLOCATE, DEALLOCATE, Available;

EXPORT 
    DiskDirProc;


PROCEDURE GetFreeFile (VAR f: File): BOOLEAN;

BEGIN
    WITH f DO
        fHint := 0;
        LOOP
            IF fHint = MaxFiles THEN
                res         := toomanyfiles;
                eof         := TRUE;
                validlength := 0;
                flags       := FlagSet {er,ef};
                EXIT;
            END;
        (*      IF NOT files [fHint].inUse THEN EXIT; END; *)
            IF (files[fHint] = NIL) THEN 
                IF (Available(TSIZE(FileDesc))) THEN
                    ALLOCATE(files[fHint], TSIZE(FileDesc));  (* 10/27/88 WKH *)
                    IF (files[fHint] = NIL) THEN 
                        HALT; 
                    END;
                    mHint := SecretNumber;  (* 11/11/88 WKH *)
                ELSE
                    res         := toomanyfiles;
                    eof         := TRUE;
                    validlength := 0;
                    flags       := FlagSet {er,ef};
                END;
                EXIT; 
            END;   (* 10/27/88 WKH  DEBUGGING *)
            INC (fHint);
        END;

        RETURN ((fHint < MaxFiles) AND (files[fHint] <> NIL));  (* 11/8/88 WKH *)
    END; (* WITH *)
END GetFreeFile;


PROCEDURE SetEmptyName (    f    : File; 
                            fno  : CARDINAL; 
                        VAR name : ARRAY OF CHAR);
(* sets the filename for a temporary file in the string "name",
   including drive, filename and type "$$$".
   In the filename is encoded the internal number of the file,
   given in the parameter "fno".
*)
VAR 
    ind                     : CARDINAL;

BEGIN
    IF (f.mt[0]="D") AND (f.mt[1]="K") THEN (*default drive*)
        ind := 0
    ELSE
        name[0] := f.mt[0];
        name[1] := ":";
        ind     := 2
    END;

    name[ind+0] := 'T';
    name[ind+1] := 'E';
    name[ind+2] := 'M';
    name[ind+3] := 'P';
    name[ind+4] := CHR (fno DIV 10 + ORD('0'));
        (* we assume that fno < 100 ! *)
    name[ind+5] := CHR (fno MOD 10 + ORD('0'));
    name[ind+6] := '.';
    name[ind+7] := '$';
    name[ind+8] := '$';
    name[ind+9] := '$';
    name[ind+10] := nul;
END SetEmptyName;



PROCEDURE InitFile (VAR f: File);
(* Initializes "f" and its FileDescriptor to be "opened"
   and positioned at the beginning of the file.
   Undefined are: eof.
*)
BEGIN
    WITH f DO
        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)
        WITH files[fHint]^ DO
            (* initialise f: *)
            res             := done;
            bufa            := ADR(buffer);  
            validlength     := 0;
            buflength       := BufSize;
            bufind          := 0;
            flags           := FlagSet {};
            FileAccessRight := AFileAccessRightSet{BTSFullAccess}; (* 3/5/89 WKH *)

            (* initialise files: *)
            inUse           := TRUE;
            owner           := 1; (* 2.05 curProcess^^.sharedId *)
            state           := opened;
            written         := FALSE;
        END; (* WITH *)
    END; (* WITH *)
END InitFile;


PROCEDURE CreateFile (VAR f: File);
(* Creates a file on the disk. "f" has to contain a
   valid "fHint" and the corresponding FileDesig has to be
   initialized. Upon return, "f" and its FileDescriptor
   are initialized, except the fields "eof" and "tempFile".
   The caller has to make sure, that a file with the
   same name does not already exist on the same drive.
*)
VAR 
    result, error           : CARDINAL;

BEGIN
    WITH f DO
        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)
        WITH files[fHint]^ DO
            DOSCALL (CreateFct, ADR(FileDesig), 0(*attributes*),
                     result (*handle*), error);

            IF error<>0 THEN
                IF error = 4 THEN
                   res := toomanyfiles;
                ELSIF error = 5 THEN
                    res := accesserror;
                ELSE
                    res:=notdone;         
                END; (* IF *)
                    flags := FlagSet {er, ef};
                    eof   := TRUE;
                RETURN;
            END; (* if *)

            FileHandle:=WORD(result);
            InitFile (f);
            fMode   := ReadWriteMode;
            fCreate := TRUE;
            fAttribAfterCreation := fileCreationAttribute;
        END; (* WITH *)
    END; (* WITH *)
END CreateFile;


PROCEDURE PrePend(VAR s     : ARRAY OF CHAR);

VAR
    StartPos                : CARDINAL;
    EndPos                  : CARDINAL;
    i                       : CARDINAL;

BEGIN
    IF (s[1] = ':') THEN (* we have a leading drive *)
        StartPos := 2;
    ELSE
        StartPos := 0;
    END;

    IF (s[StartPos] <> '\') THEN (* non fully qualified filename *)
        i := StartPos;
        WHILE ((s[i] <> 0C) AND (i < HIGH(s))) DO 
            INC(i);
        END;
        EndPos := i;

        IF ((HIGH(s) - EndPos) >= 2) THEN (* now if we have enough space *)
            FOR i := (EndPos+2) TO (StartPos+2) BY -1 DO
                s[i] := s[i-2];
            END;
            s[StartPos]   := '.';
            s[StartPos+1] := '\';
        END;
    END;
END PrePend;


PROCEDURE RenameTheFile (VAR f       : File; 
                             newName : ARRAY OF CHAR);
(* change the name of the existing and open file "f"
   into "newName".
*)
VAR 
    names                   : FileName;
    (* used as local copy to assure that name terminates with 0C *)

    answer, i, ind, result  : CARDINAL; 
    empty                   : BOOLEAN;
    high, low               : CARDINAL;
    tMode                   : CARDINAL;

BEGIN
    (* copy and truncate original name; if truncated it was anyway too long *)
    (* because 'names' holds the longest possible filename under DOS 2.0    *)
    i := 0;
    WHILE (i <= HIGH(newName)) AND (i < HIGH(names)) DO
        names[i] := newName[i];
        INC(i);
    END;
    names[i] := 0C;
    WITH f DO
        IF ((fHint >= MaxFiles) OR (files[fHint] = NIL)) THEN
            res := paramerror;
            INCL(flags, er);
            RETURN;
        END;

        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)

        WITH files[fHint]^ DO
            i:=0;

            WHILE (i#4) AND (names[i]#0C) DO
                i:=i+1
            END;  

            IF (i=0) OR ((names[i-1]=":") AND (names[i]=nul)) THEN
                (* this is a rename into a empty name: *)
                empty := TRUE;
                SetEmptyName (f, fHint, names);
            ELSE
                empty := FALSE;
            END;

            res := notdone; (* initial value; set to done when ok *)
            PrePend(names); (* WKH*)
            tMode := ReadWriteMode + ExclusiveAccessMode;

            IF dos2 THEN 
                tMode := tMode MOD 4 
            END;

            DOSCALL (OpenFct, ADR(names), tMode, answer, result);

            IF result=0 THEN  (* the file exists already *)
                DOSCALL (CloseFct, answer, result);
            ELSE (* let's try to rename it *)
                (* first we get the current DOS-fileposition *)
                DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
                        0,0,(*offset 0*) high,low, result);
                IF result = 0 THEN
                    (* second we close the original file *)
                    DOSCALL (CloseFct, FileHandle, result);

                    IF result = 0 THEN
                        (* then we rename the closed file *)
                        DOSCALL (RenameFct, ADR(FileDesig), ADR(names), result);
                        IF result = 0 THEN
                            FileDesig := names;
                            tempFile  := empty;
                            res       := done;
                        END;
                    END;

                    (* re-open the file in any case *)
                    IF dos2 THEN 
                        fMode := fMode MOD 4 
                    END;

                    DOSCALL (OpenFct, ADR(FileDesig), fMode, FileHandle, result);
                    IF result = 0 THEN
                        DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
                                high, low, high, low, result);
                    END;

                    IF (result <> 0) THEN
                        res := notdone;
                    END;
                END;
            END;
        END;

        IF res <> done THEN
            INCL(flags, er);
        END;
    END; (* WITH *)
END RenameTheFile;


PROCEDURE FileAttribute ( set: BOOLEAN; VAR f: File );

CONST
    PushF = 09CH;
    PopBX = 05BH;
    Carry = 0;

VAR
    cpuFlag                 : BITSET;
    result                  : CARDINAL;
    localAttrib             : CARDINAL;

BEGIN
    WITH f DO
        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)

        WITH files[fHint]^ DO
            localAttrib := fileAttribute;  (* 11/01/88 WKH  Compiler problem *)
            IF set THEN
                DOSCALL (GetSetAttFct, ADR(FileDesig), 1, localAttrib, result);
            ELSE
                DOSCALL (GetSetAttFct, ADR(FileDesig), 0, localAttrib, result);
            END;
        END;

        res := done;
        IF result<>0 THEN
            CASE result OF
                1  : res := callerror;
            |   2,
                3  : res := unknownfile;
            |   5  : res := accesserror;
            ELSE    
                res := notdone;
            END;
            flags := FlagSet {er};
        END;
    END;
END FileAttribute;


PROCEDURE MakeSureNotOpen(f : File);
BEGIN
(*    IF ((f.fHint < MaxFiles) AND (files[f.fHint] <> NIL) 
        AND (f.mHint = SecretNumber)) THEN 
        HALT;
    END;*)  (* 11/15/88 WKH *)
END MakeSureNotOpen;


PROCEDURE DiskDirProc (VAR f: File; name: ARRAY OF CHAR);
(* Treats the commands:
     create: "name" is not used, field "mt" in "f" is used instead.
     close : "name" is not used.
     lookup: "name" contains the drive plus filename plus type.
     rename: "name" may be empty, which sets the renamed file
             to be temporary.
     delete: "name" contains the drive plus filename plus type.
*)
(* June 6'85 V 1.14 begin changes *)
VAR 
    result, result1, i, namelast : CARDINAL;

BEGIN
    IF (name[0]="D") AND (name[1]="K") AND (name[2]=":") THEN
        i:=3;
        WHILE (i<=HIGH(name)) AND (name[i]#" ") AND (name[i]#0C) DO
            name[i-3]:=name[i];
            INC(i);
        END;
        name[i-3]:=0C;
    END;

    (* June 6'85 V 1.14 end changes *)
    namelast:=HIGH(name);

    IF namelast>=namelength THEN 
        namelast:=namelength-1 
    END;

    WITH f DO
        IF (com = create) OR (com = lookup) OR (com = delete) OR
           (com = createfile) OR (com = openfile) OR
           (com = getattrib ) OR (com = setattrib) THEN
            MakeSureNotOpen(f);  (* 11/9/88 WKH *)
            IF NOT GetFreeFile (f) THEN
                (* the error code is already set in GetFreeFile *)
                RETURN;
            END; (* IF *)
        END;

        IF ((fHint >= MaxFiles) OR (files[fHint] = NIL)) THEN
            res   := notdone;
            eof   := TRUE;
            flags := FlagSet {er,ef};
            RETURN;
        END;

        ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)

        WITH files[fHint]^ DO
            CASE com OF
                createfile,
                create     : IF (com = create) THEN
                                 (* Creates a temporary file, with the name "TEMPXX.$$$"
                                 on the drive, specified by "mt" in "f". XX in the
                                 filename is the internal filenumber in BCD.
                                 If such a file exists already, it is deleted before
                                 the new-one is created.
                                 *)
                                 SetEmptyName (f, fHint, FileDesig);
                                 (* we use "mt" from "f"; alternatively we could
                                 use the parameter "name", but "mt" is assumed
                                 to be a correct name. *)
                             ELSE
                                 FOR i:=0 TO namelast DO
                                     FileDesig[i]:=name[i];
                                 END;
                                 IF namelast<HIGH(FileDesig) THEN
                                     FileDesig[namelast+1]:=0C;
                                 END;
                             END;

                             DOSCALL (DeleteFct, ADR(FileDesig), result);
                             (* delete it, in case it exists already *)
                             CreateFile (f);

                             IF res <> done THEN
                                 inUse := FALSE;
                                 IF (files[fHint] <> NIL) THEN  (* 11/8/88 WKH *)
                                     DEALLOCATE(files[fHint], TSIZE(FileDesc));
                                 END;
                                 flags := FlagSet {er,ef};
                                 fHint := MAXCARDINAL; (* for sure not valid *) (* 10/27/88 WKH *)
                                 RETURN;
                             END;

                             tempFile := (com = create);
                             flags := FlagSet {ef}; (* opened state, empty file *)
                             eof := TRUE;

            |   close      : IF res<>eom THEN 
                                 res := done; 
                             END; (*keep eom indicator*)

                             IF (NOT tempFile) AND (wr IN flags) AND (bufind <> 0) THEN
                                 ValidateFile(fHint);  (* 10/27/88 WKH  DEBUGGING *)
                                 WriteBuffer (files[fHint]^, bufa,bufind, result);

                                 IF (result=5) THEN
                                     res:=accesserror;
                                 ELSIF (result=6) THEN
                                     res:=notdone;
                                 ELSIF result <> 0 THEN
                                     res := eom; (* usually disk full *)
                                 END;
                             END;

                             DOSCALL (CloseFct, FileHandle, result);
                                 (* The file is closed, even if there was an error in the
                                 last writing, to save the previously written data: *)

                             IF result=6 THEN
                                 res := notdone; (* invalid handle *)
                             ELSIF tempFile THEN
                                 (* We have to close the file first, the DELETE function
                                 frees only the blocks that are marked in the directory.
                                 *)
                                 DOSCALL (DeleteFct, ADR(FileDesig), result);
                                 res := done;
                             ELSIF fCreate THEN
                                 fileAttribute := fAttribAfterCreation;
                                 FileAttribute( TRUE, f );
                             END;

                             inUse := FALSE;

                             IF (files[fHint] <> NIL) THEN  (* 11/8/88 WKH *)
                                 DEALLOCATE(files[fHint], TSIZE(FileDesc));
                             END;

                             eof := TRUE;
                             flags := FlagSet {ef};

                             IF res<>done THEN 
                                 INCL (flags,er) 
                             END;

                             fHint := MAXCARDINAL; (* -1; *) (* out of usefull range *)

            |   openfile,
                lookup     : res := done;

                             FOR i:=0 TO namelast DO
                                 FileDesig[i]:=name[i];
                             END;

                             IF namelast<HIGH(FileDesig) THEN 
                                 FileDesig[namelast+1] := 0C;
                             END;

                             fCreate := FALSE;

                             IF (com = lookup) THEN
                                 IF new THEN
                                     fMode := ReadWriteMode + ExclusiveAccessMode;
                                 ELSE
                                     fMode := ReadWriteMode;
                                 END;
                             ELSE
                                 fMode := fileMode;
                             END;

                             IF dos2 THEN 
                                 fMode := fMode MOD 4 
                             END;

                             DOSCALL (OpenFct, ADR(FileDesig), fMode, FileHandle, result);
                             IF (result=2) OR (result=18 (*too many file*)) THEN
                                 IF (com = lookup) AND new THEN
                                     fileCreationAttribute := NormalAttribute;
                                     CreateFile(f); (*file not found, create it*)
                                     new := TRUE; (* overlap with fileCreationAttribute !!! *)
                                 ELSE
                                     res:=notdone; (*file not found, no create specified*)
                                 END
                             ELSIF result=4 THEN 
                                 res   := toomanyfiles;
                                 flags := FlagSet {er,ef};
                                 inUse := FALSE;
                                 IF (files[fHint] <> NIL) THEN  (* 11/8/88 WKH *)
                                     DEALLOCATE(files[fHint], TSIZE(FileDesc));
                                 END;
                             ELSIF result=5 THEN
                                 res := accesserror;
                             ELSIF result#0 THEN
                                 res := notdone;
                             ELSE
                                 new := FALSE;
                                 InitFile(f)
                             END;

                             IF res=done THEN
                                 flags    := FlagSet {}; (* opened state *)
                                 eof      := FALSE;
                                 tempFile := FALSE
                             ELSE
                                 inUse := FALSE;
                                 IF (files[fHint] <> NIL) THEN  (* 11/8/88 WKH *)
                                     DEALLOCATE(files[fHint], TSIZE(FileDesc));
                                 END;
                                 flags := FlagSet {er,ef};
                                 fHint := MAXCARDINAL; (* for sure not valid *)
                             END;

            |   rename     : RenameTheFile (f, name);

            |   getattrib,
                setattrib  : FOR i:=0 TO namelast DO
                                 FileDesig[i]:=name[i];
                             END;

                             IF namelast<HIGH(FileDesig) THEN
                                 FileDesig[namelast+1]:=0C;
                             END;

                             FileAttribute( (com = setattrib), f );
                             ValidateFile(fHint);  (* 11/2/88 WKH  DEBUGGING *)

                             IF (files[fHint] <> NIL) THEN  (* 11/2/88 WKH *)
                                 DEALLOCATE(files[fHint], TSIZE(FileDesc));
                                 fHint := MAXCARDINAL;  (* 11/11/88 WKH *)
                             END;

            |   delete     : FOR i:=0 TO namelast DO
                                 FileDesig[i]:=name[i];
                             END;

                             IF namelast<HIGH(FileDesig) THEN
                                 FileDesig[namelast+1]:=0C;
                             END;

                             DOSCALL (DeleteFct, ADR(FileDesig), result);
                             flags := FlagSet {ef};
                             eof := TRUE;

                             IF result=2 THEN
                                 res := unknownfile;
                                 INCL (flags, er);
                             ELSIF result=5 THEN
                                 res := accesserror;
                             ELSE
                                 res := done;
                             END;

                             inUse := FALSE; (* release the file descriptor *)

                             IF (files[fHint] <> NIL) THEN  (* 11/8/88 WKH *)
                                 DEALLOCATE(files[fHint], TSIZE(FileDesc));
                                 fHint := MAXCARDINAL;  (* 11/11/88 WKH *)
                             END;

                             fHint := MAXCARDINAL; (* some out-of-range value *)
            ELSE      
                res := paramerror;
            END; (* CASE *)
        END; (* WITH *)
    END; (* WITH *)
END DiskDirProc;

END DirOperations; (*************************************************)

BEGIN
    DOSCALL(30H, dosMajor, dosMinor);
    dos2 := ORD(dosMajor) < 3;
END DiskFiles.
(*DOS>*)

(*<OS2
(* T-*)
(* R-*)
(****************************************************************)
(*                                                              *)
(*      MODULA-2/86 Library                                     *)
(*                                                              *)
(*        LOGITECH SA.,  CH-1143 Apples   (Switzerland)         *)
(*                                                              *)
(*      Module: DiskFiles                                       *)
(*        Provides the basic functions, needed by FileSystem,   *)
(*        for disk files. Files are implemented on MSDOS 2.0.   *)
(*        Drives "A" through "P" and the default drive are      *)
(*        supported by this driver. The corresponding medium    *)
(*        names are "A".."P" for specific drives and "DK" for   *)
(*        the default drive.                                    *)
(*        In the current implementation, there is a buffer of   *)
(*        512 bytes per opened file.                            *)
(*                                                              *)
(*      Version  2.02  (Feb '86)   for MS-DOS 2.0               *)
(*      Version  3.00  (July 87)                                *)
(*                                                              *)
(*      (C) Copyright 1983, 1984 Logitech,  All Rights Reserved *)
(*                                                              *)
(*      This program is a trade secret of Logitech, and it is   *)
(*      not to be reproduced, published, disclosed to others,   *)
(*      copied, adapted, distributed or displayed without the   *)
(*      prior authorization of Logitech.                        *)
(*                                                              *)
(*      Licensee agrees to attach or embed this notice on all   *)
(*      copies of the program, including partial copies or      *)
(*      modified versions thereof.                              *)
(****************************************************************)

IMPLEMENTATION MODULE DiskFiles;                (* WS, opje, AW *)

  FROM RTSTerm IMPORT InstallTermProc;
  
  FROM FileIO IMPORT DosOpen, DosClose, DosMove, DosDelete, DosWrite,
                     DosRead, DosChgFilePtr, DosSetFileMode, DosQFileMode,
                     FileAttrSet, NormalFile;
  FROM SYSTEM IMPORT ADDRESS, (*DOSCALL*) ADR, WORD (*CODE*) (*BX*) (*CX*)
                     (*DI*) (*GETREG*);
  FROM FileSystem IMPORT File, Command, Response, Flag, FlagSet,
                         MediumType, CreateMedium, FileNameChar,
                         NormalAttribute,
                         ReadWriteMode, ReadOnlyMode, WriteOnlyMode,
                         ExclusiveAccessMode, ReadOnlyAccessMode,
                         WriteOnlyAcessMode, FullAccessMode,
                         PrivateFileMode, InheritedFileMode;

  FROM FileSystem IMPORT
                         AFileAccessRightSet, AFileAccessRight;

  CONST                         
    nul = 0C;
    MaxFiles = 15; (* maximal number of opened files *)
       (* maximum of file handles under DOS, 20 minus 5 predefined *)
       (* Note: this limit could be removed by using dynamic variable
          ****  for the file-descriptors and the buffers.
       *)

    BufSize   = 512; (*bytes per buffer*)

    namelength=79; (*maximum length for full file specification*)

    (* The function calls for the Operating System: *)
    CreateFct = 3CH;
    OpenFct   = 3DH;
    CloseFct  = 3EH;
    ReadFct   = 3FH;
    WriteFct  = 40H;
    DeleteFct = 41H;
    SetPosFct = 42H;
    GetSetAttFct = 43H;
    RenameFct = 56H;
    CreateFlag = BITSET{1,4}; (* if file exists then truncate it *)
    OpenFlag   = BITSET{0};   (* just open file *)
    OModeRWExcl = BITSET{1,4,7,13};
    OModeRWNoExcl = BITSET{1,6,13};
    Reserved   = VAL(LONGINT,0);


  TYPE

    Buffer = ARRAY [0..BufSize-1] OF CHAR;

    FileStatus = (opened, reading, modifying, writing);

    FileName = ARRAY [0..namelength-1] OF CHAR;

    FileDesc = RECORD
                 inUse: BOOLEAN;
                   (* indicates, if this descriptor is used *)
                 tempFile: BOOLEAN;
                   (* if TRUE, the file will be destroyed upon a close *)
                 FileHandle: CARDINAL;
                   (* used by OS/2 to specify a file for fileIO functions *)
                 eofh: CARDINAL;
                   (*high and low parts of eof pointer, used...*)
                 eofl: CARDINAL; (*by length function and by setpos*)
                 FileDesig: FileName; (*actual file specification*)
                 state: FileStatus; (* redundant, derived from "flags" *)
                 owner: CARDINAL;
                   (* program identifier of the current layer,
                      when the file was opened *)
                 written: BOOLEAN;
                   (* TRUE, if the file was once in writing state *)
                 buffer: Buffer;
                   (* its data is the 512 byte block read/written to the file*)
                 count: CARDINAL;
                   (*buffer count so we don't have to emulate CP/M!*)
               END;

  BufAddr = RECORD
               CASE BOOLEAN OF
                 TRUE: addr: ADDRESS;
               | FALSE: offset,base: CARDINAL
               END
            END;

  PosType = RECORD CASE BOOLEAN OF
                    TRUE  : ent(*ire*) : LONGINT;
                  | FALSE : lo, hi     : CARDINAL;
                   END;
                 END;
                 
  VAR
    files:   ARRAY [0..MaxFiles-1] OF FileDesc;
    dosMajor, dosMinor: CHAR;
    OpenMode : BITSET;
(*
 *   dos2 : BOOLEAN; (* will be TRUE if DOS version less than 3.0 *)
 *)

(******************************************************************)

PROCEDURE InitDiskSystem;
  VAR i: CARDINAL;
      response: BOOLEAN;
      drive: MediumType;
BEGIN
  (* Install the mediums. 'DK' is the name of the default drive: *)
  CreateMedium ('DK ', DiskFileProc, DiskDirProc, response);
  (* The other 16 drives, supported by MSDOS are 'A' through 'P': *)
  drive[0] := 'A';  drive[1] := ' ';  drive [2] := ' ';
(* MOE Feb 6'86 *)
  FOR i:=0 TO (ORD('Z') - ORD('A')) DO
    CreateMedium (drive, DiskFileProc, DiskDirProc, response);
    INC (drive[0]);
  END;
  (* If the program of this level (usually resident part) terminates,
     we have to remove all the mediums: *)
  InstallTermProc (TerminateLevel);
  FOR i:=0 TO MaxFiles-1 DO
    files[i].inUse := FALSE;
  END;
END InitDiskSystem;


PROCEDURE TerminateLevel;
  VAR i, curProg, result: CARDINAL;
      fAddr:BufAddr;
BEGIN
(* OS/2
  curProg := RTSMain.curProcess^^.currOverlay^.programLevel;
*)
  FOR i := 0 TO MaxFiles-1 DO
    WITH files[i] DO
      IF inUse THEN
        (*IF owner = curProg THEN*)
          (* we have to close it and to free its descriptor: *)
          IF (NOT tempFile) AND written THEN 
            WriteBuffer (files[i], ADR(buffer),BufSize, result);
            (* since we don't have access to the 'File'
               from 'FileSystem', we try to do the safest
               operation: write default buffer, length=max.
            *)
          END;
          
          result := DosClose(FileHandle);
          
(*
 *          DOSCALL(CloseFct,FileHandle,result);
 *)
          IF tempFile THEN
            
             result := DosDelete(ADR(FileDesig),Reserved);
              
(*
 *           DOSCALL(DeleteFct,ADR(FileDesig),result);
 *)
          END;
          inUse := FALSE;
        (*END;*)
      END;
    END; (* WITH *)
  END; (* FOR *)
END TerminateLevel;


(******************************************************************)

MODULE FileOperations;

  IMPORT ADDRESS, (*DOSCALL*) ADR, WORD,
         files, File, FileDesc, FileStatus,
         Command, Response, Flag, FlagSet,
         MaxFiles, ReadFct, WriteFct, SetPosFct,
         BufAddr, BufSize, ReadOnlyMode, WriteOnlyMode,
         OpenFlag, OpenMode, CreateFlag, Reserved, PosType,
         OModeRWExcl, OModeRWNoExcl,
         DosOpen, DosClose, DosMove, DosDelete, DosWrite,
         DosRead, DosChgFilePtr,
         FileAttrSet, NormalFile;
         
  EXPORT WriteBuffer, DiskFileProc;


PROCEDURE SetError (VAR f: File; errorCode: Response);
BEGIN
  WITH f DO
    res := errorCode;
    eof := TRUE;
    validlength := 0;
    flags := FlagSet {er,ef};
    files[fHint].state := opened;
  END;
END SetError;


PROCEDURE RePos(VAR f:File); 
(* Reposition a file at point before last read *)
(* The effect is that the current position (known by the OS)
   is the one of the first byte in the buffer of DiskFile.
   If later we are going to write the buffer to the file, it
   will be placed there with the right offset.
*)
VAR (*high, low,*) n, error: CARDINAL; 
    handle: CARDINAL;
    NewPointer : LONGINT;
BEGIN
  n:=files[f.fHint].count;
  IF n>0 THEN
    handle := files[f.fHint].FileHandle;
    
     error := DosChgFilePtr(handle,VAL(LONGINT,0),01,NewPointer); 
(*
 *   DOSCALL (SetPosFct, handle, 01, 0,0, high,low, error);
 *)
      (* position file at zero offset from current place *)
(*
 *   IF low<n THEN DEC(high) END;
 *)   
     NewPointer := NewPointer - VAL(LONGINT,n);
     
     error := DosChgFilePtr(handle,NewPointer,00,NewPointer);
(*    
 *   low:=low-n;
 *   DOSCALL (SetPosFct, handle, 00, high,low, high,low, error);
 *)
      (* position file at absolute position 'high,low' *)
  END
END RePos;

 
(****************************************************************)

  PROCEDURE WriteBuffer (VAR fDesc: FileDesc; bufptr:ADDRESS; 
                         bufLength: CARDINAL; VAR response: CARDINAL);
    VAR error: CARDINAL;
  BEGIN
    response:=0;
    IF bufLength>0 THEN
    
      error := DosWrite(fDesc.FileHandle, bufptr, bufLength, response);
(*
 *     DOSCALL (WriteFct, fDesc.FileHandle, bufLength, bufptr,
 *              response, error);
 *)
      IF error=0 THEN 
        IF response=bufLength THEN 
          response:=0;
        ELSE
          response:=1;
        END;
      ELSE response := error;
      END;
    END;
  END WriteBuffer;

  PROCEDURE ReadBuffer (VAR f: File);
    VAR result, error : CARDINAL;
  BEGIN
    
    error := DosRead(files[f.fHint].FileHandle, f.bufa, f.buflength,
                     result);
(*
 *   DOSCALL (ReadFct, files[f.fHint].FileHandle, f.buflength, f.bufa, (* AW June 5th, 87 *)
 *            result, error);
 *)
    IF (error<>0) THEN
      IF (error=5) THEN
        f.res:=accesserror;
      ELSE
        f.res:=notdone;
      END;
      f.eof:=TRUE;
      result := 0;
      INCL (f.flags,ef);
    ELSIF (result=0) THEN
      f.eof:=TRUE;
      INCL (f.flags,ef);
    END;
    f.validlength:=result;
    files[f.fHint].count:=result
  END ReadBuffer;


PROCEDURE DiskFileProc (VAR f: File);

  VAR response, index, cposL, cposH, error: CARDINAL;
      EOFPos,NewPos : PosType;
      
BEGIN
  WITH f DO
    IF fHint >= MaxFiles THEN
      res := paramerror;
      flags := FlagSet {er,ef};
      RETURN;
    END;
    WITH files[fHint] DO
      CASE com OF
          setread:   IF (fMode MOD 8) = WriteOnlyMode THEN
                       SetError( f, accesserror );
                     ELSE
                       res := done;  EXCL (flags, er);
                       CASE state OF
                           opened:  ReadBuffer (f);
                         | reading: INCL(flags, rd); RETURN;
                         | writing, modifying:
                                    WriteBuffer (files[fHint], bufa,
                                      bufind, response);
                                    (* we write the buffer back in any case *)
                                    count := bufind;
                                    IF (response=5) THEN
                                      res:=accesserror; 
                                    ELSIF (response=6) THEN
                                      res:=notdone; 
                                    ELSIF (response <> 0) THEN
                                      res := eom;
                                    ELSE
(* May 24'85 MOE *)
                                      IF bufind >= BufSize THEN
                                        (* current pos is not in the buffer *)
                                        ReadBuffer (f);
                                        bufind:=0; (* as for doio *)
                                      ELSIF (state=modifying) THEN
                                        (* simulate sequential reading: *)
                                        
                                        error := DosChgFilePtr(FileHandle,
                                             VAL(LONGINT,validlength-bufind),
                                             01, NewPos.ent);
(*
 *                                        DOSCALL (SetPosFct, FileHandle, 01,
 *                                            0, validlength-bufind, cposH,
 *                                            cposL, error);
 *)                                      (* set DOS position to the last read
                                             byte in buffer. *)
                                      END;
(* May 24'85 MOE *)
                                    END;
                       END; (* CASE *)
                       IF res = done THEN
                         flags := FlagSet {rd};
                         state := reading;
                         eof := FALSE;
                       ELSE SetError (f, res);
                       END;
                     END;

        |  setwrite: IF (fMode MOD 8) = ReadOnlyMode THEN
                       SetError( f, accesserror );
                     ELSE
                       IF state = reading THEN RePos(f) END;
                       res := done;
                       flags := FlagSet {ef, wr};
                       eof := TRUE;
                       state := writing;
                       written := TRUE;
                       validlength := bufind; (* soft truncate *)
                       (* truncate the file physically! (not yet implem.) *)
                     END;

        | setmodify: IF ( (fMode MOD 8 ) = ReadOnlyMode  ) OR
                        ( (fMode MOD 8 ) = WriteOnlyMode ) THEN
                       SetError( f, accesserror );
                     ELSE
                       res := done;  EXCL (flags, er);
                       IF state = reading THEN RePos(f) END;
                       IF state = opened THEN
                         ReadBuffer (f); RePos(f) (*set file back for write*)
                       END;
                       IF res = done THEN
                         eof := FALSE;
                         flags := FlagSet {rd, wr};
                         state := modifying;
                         written := TRUE;
                       ELSE SetError (f, res)
                       END;
                     END;

        | setopen:   response := 0;
                     IF (wr IN flags) THEN
                       WriteBuffer (files[fHint],bufa,
                         bufind, response);
                       validlength := 0;
                       bufind := 0;
                       (* the buffer will be considered non-initialized *)
                     END;
                     IF (response=5) THEN
                       res:=accesserror;
                     ELSIF (response=6) THEN
                       res:=notdone;
                     ELSIF (response <> 0) THEN  
                       SetError (f, eom);
                     ELSE
                       IF res <> eom THEN
                         (* keep the result 'eom', because the 'setopen' can
                            be used as a sort of flush (force the writing of
                            buffers).
                         *)
                         res := done;
                         eof := FALSE;
                         flags := FlagSet {};
                       END;
                       state := opened
                     END;

        | doio:      IF res <> eom THEN
                       res := done;  EXCL (flags, er);
                     END;
                     IF (wr IN flags) THEN
                       WriteBuffer (files[fHint],bufa,
                         bufind, response);
                       IF (response=5) THEN
                         res := accesserror;
                       ELSIF (response=6) THEN 
                         res:=notdone;
                       ELSIF response <> 0 THEN
                         res := eom
                       ELSE bufind:=0
                       END
                     END;
                     IF (rd IN flags) THEN
                       IF bufind=BufSize THEN
                         bufind:=0
                       END;
                       ReadBuffer (f);
                       IF state=modifying THEN RePos(f) END
                     END;
                     IF res <> done THEN SetError (f, res); END;

        | setpos:    res:=done;  EXCL (flags, er);
                     IF (wr IN flags) THEN
                       WriteBuffer(files[fHint],bufa,bufind,response);
                       IF (response=5) THEN
                         res:=accesserror;
                       ELSIF (response=6) THEN
                         res:=notdone;
                       ELSIF response<>0 THEN 
                         res:=eom 
                       END
                     END;
                     IF res=done THEN
                       bufind:=0;
                       
                       error := DosChgFilePtr(FileHandle,VAL(LONGINT,0),
                                02,EOFPos.ent);
(*
 *                      DOSCALL (SetPosFct, FileHandle, 02 (*eof*),
 *                               0,0, eofh,eofl, error);
 *)
                       IF ((lowpos>EOFPos.lo) AND (highpos=EOFPos.hi)) OR
                          (highpos>EOFPos.hi) THEN
                         (*if you tried to position past eof...*)
                         SetError(f,paramerror); (* set the error flags *)
                         highpos:=EOFPos.hi; (*and reset your call values*)
                         lowpos:=EOFPos.lo;  (*to position AT eof.*)
                       ELSIF state=writing THEN  (* writing always at EOF *)
                         eof:=TRUE;  INCL (flags, ef);
                       ELSE
                         eof:=FALSE;  EXCL (flags, ef);
                       END;
                       NewPos.hi:=highpos; 
                       NewPos.lo:=lowpos; (* it's easier for compiler! *)
                       
                       error:=DosChgFilePtr(FileHandle,NewPos.ent,
                                            00,EOFPos.ent);
(*
 *                      DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
 *                               cposH,cposL, eofh,eofl, error);
 *)
                       IF error <> 0 THEN res:=notdone;
                       ELSIF (rd IN flags) THEN
                         ReadBuffer (f);
                         eof:=FALSE; EXCL(flags,ef);  (* per definition *)
                         IF state=modifying THEN RePos(f) END
                       ELSIF state = writing THEN
                         validlength := bufind; (* soft truncate *)
                         (* truncate the file physically! (not yet implem.) *)
                       END;
                     END;
                     IF res <> done THEN SetError (f, res); END;
                     
        | getpos:    error := DosChgFilePtr(FileHandle,VAL(LONGINT,0),
                                            01,NewPos.ent);
(*
 *       DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
 *                             0,0,(*offset 0*) highpos,lowpos, error);
 *)
                     IF (wr IN flags) THEN
                       (* The physical position is the one of last writing,
                          i.e we have to add the number of bytes in buffer: *)
                    
                       NewPos.ent := NewPos.ent + VAL(LONGINT,bufind);
                       lowpos  := NewPos.lo;
                       highpos := NewPos.hi;
(*                       
 *                      (*$R-  wrap around: *) lowpos:=lowpos+bufind; (*$R=*)
 *                      IF lowpos<bufind THEN highpos:=highpos+1 END
 *)                     
                     ELSIF (rd IN flags) THEN
                       (* If sequential reading, the physical position is
                          the one of the last byte in buffer: *)
                          
                       NewPos.ent:=NewPos.ent-VAL(LONGINT,validlength-bufind);
                       lowpos  := NewPos.lo;
                       highpos := NewPos.hi;
(*
 *                      IF lowpos < (validlength-bufind) THEN
 *                        highpos:=highpos-1; (* there is a wrap-around *)
 *                      END;
 *                      (*$R-*) lowpos:=lowpos-(validlength-bufind); (*$R=*)
 *)                      
                     END;
                     res := done;  EXCL (flags, er);

        | length:    error := DosChgFilePtr(FileHandle, VAL(LONGINT,0),
                                            01, NewPos.ent);
(*
 *       DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
 *                             0,0,(*offset 0*) cposH,cposL, error);
 *)
                     IF (wr IN flags) THEN
                       (* add the bytes in the buffer to be written: *)
                       
                       NewPos.ent  := NewPos.ent + VAL(LONGINT,bufind);
                       lowpos  := NewPos.lo;
                       highpos := NewPos.hi;
(*
 *                      (*$R-*) lowpos:=cposL + bufind; (*$R=*)
 *                      IF lowpos < cposL THEN highpos:=cposH+1;
 *                      ELSE highpos:=cposH; END
 *)                      
                     END;
                     IF state <> writing THEN
                     
                       error := DosChgFilePtr(FileHandle, VAL(LONGINT,0),
                                              02, EOFPos.ent);
(*
 *                      DOSCALL (SetPosFct, FileHandle, 02 (*eof*),
 *                               0,0,(*offset 0*) eofh,eofl, error);
 *)
                       IF state = modifying THEN
                         (* take the larger of the 2 pos (current or eof): *)
                         IF EOFPos.hi > highpos THEN 
                           highpos := EOFPos.hi; 
                           lowpos  := eofl;
                         ELSIF EOFPos.hi=highpos THEN
                           IF EOFPos.lo>lowpos THEN 
                           lowpos:=EOFPos.lo END;
                         END;
                       ELSE (* reading or opened *)
                         highpos := EOFPos.hi;
                         lowpos  := EOFPos.lo;
                       END;
                       
                       error := DosChgFilePtr(FileHandle,NewPos.ent,
                                              00,NewPos.ent);
(*
 *                      DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
 *                               cposH,cposL, cposH,cposL, error);
 *)
                     END;
                     res:=done;  EXCL (flags, er);

        ELSE  res := notsupported;  INCL (flags, er);
      END; (* CASE *)
    END; (* WITH *)
  END; (* WITH *)
END DiskFileProc;

END FileOperations;


(**********************************************************************)


MODULE DirOperations;

  IMPORT WriteBuffer, (*DOSCALL*) ADR, WORD, ADDRESS, 
         CreateFct, OpenFct, CloseFct, DeleteFct, RenameFct, SetPosFct,
         GetSetAttFct, (*dos2,*)
         files, Flag, FlagSet, MediumType,
         File, FileName, FileDesc, FileStatus, Command, Response,
         FileNameChar, MaxFiles, nul, BufSize, namelength,
         ReadOnlyMode, WriteOnlyMode, ReadWriteMode, 
         ExclusiveAccessMode, ReadOnlyAccessMode, WriteOnlyAcessMode,
         FullAccessMode, PrivateFileMode, InheritedFileMode,
         NormalAttribute,
         (*CODE*) (*BX*) (*CX*) (*DI*) (*GETREG*)
         OModeRWExcl, OModeRWNoExcl, OpenMode,
         OpenFlag, CreateFlag, Reserved, PosType,
         DosOpen, DosClose, DosMove, DosDelete, DosSetFileMode, 
         DosQFileMode, DosChgFilePtr,
         FileAttrSet, NormalFile, AFileAccessRight, AFileAccessRightSet;
         
  EXPORT DiskDirProc;


PROCEDURE GetFreeFile (VAR f: File): BOOLEAN;
BEGIN
  WITH f DO
    fHint := 0;
    LOOP
      IF fHint = MaxFiles THEN
        res := toomanyfiles;
        eof := TRUE;
        validlength := 0;
        flags := FlagSet {er,ef};
        EXIT;
      END;
      IF NOT files [fHint].inUse THEN EXIT; END;
      INC (fHint);
    END;
    RETURN (fHint < MaxFiles);
  END; (* WITH *)
END GetFreeFile;


PROCEDURE SetEmptyName (f:File; fno: CARDINAL; VAR name: ARRAY OF CHAR);
  (* sets the filename for a temporary file in the string "name",
     including drive, filename and type "$$$".
     In the filename is encoded the internal number of the file,
     given in the parameter "fno".
  *)
VAR ind:CARDINAL;
BEGIN
  IF (f.mt[0]="D") AND (f.mt[1]="K") THEN (*default drive*)
    ind:=0
  ELSE
    name[0]:=f.mt[0];
    name[1]:=":";
    ind:=2
  END;
  name[ind+0] := 'T';
  name[ind+1] := 'E';
  name[ind+2] := 'M';
  name[ind+3] := 'P';
  name[ind+4] := CHR (fno DIV 10 + ORD('0'));
    (* we assume that fno < 100 ! *)
  name[ind+5] := CHR (fno MOD 10 + ORD('0'));
  name[ind+6] := '.';
  name[ind+7] := '$';
  name[ind+8] := '$';
  name[ind+9] := '$';
  name[ind+10] := nul;
END SetEmptyName;



PROCEDURE InitFile (VAR f: File);
  (* Initializes "f" and its FileDescriptor to be "opened"
     and positioned at the beginning of the file.
     Undefined are: eof.
  *)
BEGIN
  WITH f DO
    WITH files[fHint] DO
      (* initialise f: *)
      res := done;
      bufa := ADR (buffer);
      validlength := 0;
      buflength := BufSize;
      bufind := 0;
      flags := FlagSet {};
      FileAccessRight := AFileAccessRightSet{BTSFullAccess}; (* 3/5/89 WKH *)
      (* initialise files: *)
      inUse := TRUE;
      owner := 1;               (* 2.05 curProcess^^.sharedId *)
      state := opened;
      written := FALSE;
    END; (* WITH *)
  END; (* WITH *)
END InitFile;


PROCEDURE CreateFile (VAR f: File);
  (* Creates a file on the disk. "f" has to contain a
     valid "fHint" and the corresponding FileDesig has to be
     initialized. Upon return, "f" and its FileDescriptor
     are initialized, except the fields "eof" and "tempFile".
     The caller has to make sure, that a file with the
     same name does not already exist on the same drive.
  *)
  VAR result, error, actiontaken: CARDINAL;
BEGIN
  WITH f DO
    WITH files[fHint] DO
    
      error := DosOpen(ADR(FileDesig), result, actiontaken, 
                       VAL(LONGINT,0)(*size*), NormalFile, 
                       CreateFlag, OModeRWNoExcl, Reserved); 
(*                        
 *     DOSCALL (CreateFct, ADR(FileDesig), 0(*attributes*),
 *              result (*handle*), error);
 *)
      IF error<>0 THEN
        IF error = 4 THEN
          res := toomanyfiles;
        ELSIF error = 5 THEN
          res := accesserror;
        ELSE
          res:=notdone;         
        END; (* IF *)
        flags:=FlagSet {er, ef};
        eof:=TRUE;
        RETURN;
      END; (* if *)
      FileHandle:=result;
      InitFile (f);
      fMode   := ReadWriteMode;
      fCreate := TRUE;
      fAttribAfterCreation := fileCreationAttribute;
    END; (* WITH *)
  END; (* WITH *)
END CreateFile;


PROCEDURE RenameTheFile (VAR f: File; newName: ARRAY OF CHAR);
  (* change the name of the existing and open file "f"
     into "newName".
  *)
  

  VAR names: FileName;
        (* used as local copy to assure that name terminates with 0C *)
      answer, i, ind, result: CARDINAL; empty: BOOLEAN;
      high, low: CARDINAL;
      tMode: CARDINAL;
      actiontaken : CARDINAL;
      NewPos : PosType;
BEGIN
  (* copy and truncate original name; if truncated it was anyway too long *)
  (* because 'names' holds the longest possible filename under DOS 2.0    *)
  i := 0;
  WHILE (i <= HIGH(newName)) AND (i < HIGH(names)) DO
    names[i] := newName[i];
    INC(i);
  END;
  names[i] := 0C;
  WITH f DO
    IF fHint >= MaxFiles THEN
      res := paramerror;
      INCL(flags, er);
      RETURN;
    END;
    WITH files[fHint] DO
      i:=0;
      WHILE (i#4) AND (names[i]#0C) DO
        i:=i+1
      END;  
      IF (i=0) OR ((names[i-1]=":") AND (names[i]=nul)) THEN
        (* this is a rename into a empty name: *)
        empty := TRUE;
        SetEmptyName (f, fHint, names);
      ELSE
        empty := FALSE;
      END;
      res := notdone; (* initial value; set to done when ok *)
      tMode := ReadWriteMode + ExclusiveAccessMode;
(*
 *     IF dos2 THEN tMode := tMode MOD 4 END;
 *)     
      result := DosOpen(ADR(names), answer, actiontaken, 
                        VAL(LONGINT,0)(*size*), NormalFile, 
                        OpenFlag, OModeRWNoExcl, Reserved); 
(*
 *     DOSCALL (OpenFct, ADR(names), tMode, answer, result);
 *)
      IF result=0 THEN  (* the file exists already *)
      
        result := DosClose(answer);
(*
 *                DOSCALL (CloseFct, answer, result);
 *)
      ELSE (* let's try to rename it *)
        (* first we get the current DOS-fileposition *)
        
        result := DosChgFilePtr(FileHandle, VAL(LONGINT,0), 01, NewPos.ent);
(*
 *       DOSCALL (SetPosFct, FileHandle, 01 (*current pos*),
 *                0,0,(*offset 0*) high,low, result);
 *)
        IF result = 0 THEN
          (* second we close the original file *)
          
          result := DosClose(FileHandle);
(*
 *         DOSCALL (CloseFct, FileHandle, result);
 *)
          IF result = 0 THEN
            (* then we rename the closed file *)
            
            result := DosMove(ADR(FileDesig), ADR(names), Reserved);
(*
 *           DOSCALL (RenameFct, ADR(FileDesig), ADR(names), result);
 *)
            IF result = 0 THEN
              FileDesig := names;
              tempFile := empty;
            END;
          END;
          (* re-open the file in any case *)
(*
 *         IF dos2 THEN fMode := fMode MOD 4 END;
 *)
          result := DosOpen(ADR(FileDesig), FileHandle, actiontaken,
                            VAL(LONGINT,0), NormalFile, OpenFlag,
                            OModeRWNoExcl, Reserved);
(*
 *         DOSCALL (OpenFct, ADR(FileDesig), fMode, FileHandle, result);
 *)
          IF result = 0 THEN
           
            result := DosChgFilePtr(FileHandle, NewPos.ent, 00 (*from SOF*),
                                    NewPos.ent);
(*
 *           DOSCALL (SetPosFct, FileHandle, 00 (*absolute*),
 *                    high, low, high, low, result);
 *)
            IF result = 0 THEN
              res := done; (* we did it *)
            END;
          END;
        END;
      END;
    END;
    IF res <> done THEN
      INCL(flags, er);
    END;
  END; (* WITH *)
END RenameTheFile;


PROCEDURE FileAttribute ( set: BOOLEAN; VAR f: File );

(*CONST
 * PushF = 09CH;
 * PopBX = 05BH;
 * Carry = 0;
 *)
 
VAR
(*
 *  cpuFlag     : BITSET;
 *)
  result      : CARDINAL;
(*
 * localAttrib : CARDINAL;
 *)
  localAttrib : FileAttrSet;
BEGIN
  WITH f DO
    WITH files[fHint] DO
      IF set THEN
      
        result := DosSetFileMode(ADR(FileDesig), FileAttrSet(fileAttribute),
                                 Reserved);
(*
 *       DOSCALL (GetSetAttFct, ADR(FileDesig), 1, fileAttribute, result);
 *)
      ELSE
        
        result := DosQFileMode(ADR(FileDesig), localAttrib,Reserved);
        fileAttribute := CARDINAL(localAttrib);
(*
 *       DOSCALL (GetSetAttFct, ADR(FileDesig), 0, fileAttribute, result);
 *)
      END;
    END;
    res := done;
    IF result<>0 THEN
       CASE result OF
         120       : res := callerror;
       | 1002      : res := unknownfile;
       | 1012,1013 : res := accesserror;
       ELSE          res := notdone;
       END;
       
(*      CASE result OF
 *       1   : res := callerror;
 *     | 2, 3: res := unknownfile;
 *     | 5   : res := accesserror;
 *     ELSE    res := notdone;
 *     END;
 *)
      flags := FlagSet {er};
    END;
  END;
END FileAttribute;


PROCEDURE DiskDirProc (VAR f: File; name: ARRAY OF CHAR);
  (* Treats the commands:
       create: "name" is not used, field "mt" in "f" is used instead.
       close : "name" is not used.
       lookup: "name" contains the drive plus filename plus type.
       rename: "name" may be empty, which sets the renamed file
               to be temporary.
       delete: "name" contains the drive plus filename plus type.
  *)
(* June 6'85 V 1.14 begin changes *)

  (* OS/2 *)
  CONST
       RAcc     = BITSET{};    (* Read only *)  
       WAcc     = BITSET{0};   (* Write only *)
       RWAcc    = BITSET{1};   (* Read/Write Access *)
       ExclRW   = BITSET{4};   (* Deny R/W Access *)
       ExclW    = BITSET{5};   (* Deny W Access *)
       ExclR    = BITSET{4,5}; (* Deny R Access *)
       NoExcl   = BITSET{6};   (* Deny none *)
       Priv     = BITSET{1};   (* Private file *)
       Inherit  = BITSET{};    (* inherited *)
       ErrToApp = BITSET{13};  (* Error to be send to application via 
                                  Return code *)
       
  VAR result, result1, i, namelast, actiontaken, m : CARDINAL;
BEGIN
  IF (name[0]="D") AND (name[1]="K") AND (name[2]=":") THEN
    i:=3;
    WHILE (i<=HIGH(name)) AND (name[i]#" ") AND (name[i]#0C) DO
      name[i-3]:=name[i];
      INC(i);
    END;
    name[i-3]:=0C;
  END;
(* June 6'85 V 1.14 end changes *)
  namelast:=HIGH(name);
  IF namelast>=namelength THEN namelast:=namelength-1 END;
  WITH f DO
    IF (com = create) OR (com = lookup) OR (com = delete) OR
       (com = createfile) OR (com = openfile) OR
       (com = getattrib ) OR (com = setattrib) THEN
      IF NOT GetFreeFile (f) THEN
        (* the error code is already set in GetFreeFile *)
        RETURN;
      END; (* IF *)
    END;
    IF fHint >= MaxFiles THEN
      res := notdone;
      eof := TRUE;
      flags := FlagSet {er,ef};
      RETURN;
    END;
    WITH files[fHint] DO
      CASE com OF
          createfile,
          create    : 
                  IF (com = create) THEN
                    (* Creates a temporary file, with the name "TEMPXX.$$$"
                       on the drive, specified by "mt" in "f". XX in the
                       filename is the internal filenumber in BCD.
                       If such a file exists already, it is deleted before
                       the new-one is created.
                    *)
                    SetEmptyName (f, fHint, FileDesig);
                    (* we use "mt" from "f"; alternatively we could
                       use the parameter "name", but "mt" is assumed
                       to be a correct name. *)
                  ELSE
                    FOR i:=0 TO namelast DO
                      FileDesig[i]:=name[i];
                    END;
                    IF namelast<HIGH(FileDesig) THEN
                      FileDesig[namelast+1]:=0C;
                    END;
                  END;
                  
                  result := DosDelete(ADR(FileDesig), Reserved);
(*
 *                 DOSCALL (DeleteFct, ADR(FileDesig), result);
 *)
                  (* delete it, in case it exists already *)
                  CreateFile (f);
                  IF res <> done THEN
                    inUse := FALSE;
                    flags := FlagSet {er,ef};
                    fHint := 0FFFFH; (* for sure not valid *)
                    RETURN;
                  END;
                  tempFile := (com = create);
                  flags := FlagSet {ef}; (* opened state, empty file *)
                  eof := TRUE;

        | close : IF res<>eom THEN res := done; END; (*keep eom indicator*)
                  IF (NOT tempFile) AND (wr IN flags) AND (bufind <> 0) THEN
                    WriteBuffer (files[fHint], bufa,bufind, result);
                    IF (result=5) THEN
                      res:=accesserror;
                    ELSIF (result=6) THEN
                      res:=notdone;
                    ELSIF result <> 0 THEN
                      res := eom; (* usually disk full *)
                    END;
                  END;
                  
                  result := DosClose(FileHandle);
(*
 *                 DOSCALL (CloseFct, FileHandle, result);
 *)
                    (* The file is closed, even if there was an error in the
                       last writing, to save the previously written data: *)
                  IF result=6 THEN
                    res := notdone; (* invalid handle *)
                  ELSIF tempFile THEN
                    (* We have to close the file first, the DELETE function
                       frees only the blocks that are marked in the directory.
                    *)
                    
                    result := DosDelete(ADR(FileDesig), Reserved);
(*
 *                   DOSCALL (DeleteFct, ADR(FileDesig), result);
 *)
                    res := done;
                  ELSIF fCreate THEN
                    fileAttribute := fAttribAfterCreation;
                    FileAttribute( TRUE, f );
                  END;
                  inUse := FALSE;
                  eof := TRUE;
                  flags := FlagSet {ef};
                  IF res<>done THEN INCL (flags,er) END;
                  fHint := 65535; (* -1; *) (* out of usefull range *)

        | openfile,
          lookup  : 
                  res:=done;
                  FOR i:=0 TO namelast DO
                    FileDesig[i]:=name[i];
                  END;
                  IF namelast<HIGH(FileDesig) THEN 
                    FileDesig[namelast+1]:=0C;
                  END;
                  fCreate := FALSE;
                  IF (com = lookup) THEN
                    IF new THEN
                      fMode := ReadWriteMode + ExclusiveAccessMode;
                      OpenMode := OModeRWExcl;
                    ELSE
                      fMode := ReadWriteMode;
                      OpenMode := OModeRWNoExcl;
                    END;
                  ELSE
                    fMode := fileMode;
                    
                    
                    (* OS/2 *)
                    m := fileMode MOD 16;
                    CASE m OF
                       ReadOnlyMode  : OpenMode := RAcc;
                      |WriteOnlyMode : OpenMode := WAcc;
                      |ReadWriteMode : OpenMode := RWAcc;  
                    END;
                    m := fileMode - m;
                    CASE m OF 
                       ExclusiveAccessMode : OpenMode := OpenMode+ExclRW;
                      |ReadOnlyAccessMode  : OpenMode := OpenMode+ExclR;
                      |WriteOnlyAcessMode  : OpenMode := OpenMode+ExclW;
                      |FullAccessMode      : OpenMode := OpenMode+NoExcl;
                    ELSE
                       OpenMode := OpenMode+NoExcl;
                    END;
                    IF m = PrivateFileMode THEN
                       OpenMode := OpenMode+Priv;
                    ELSIF m = InheritedFileMode THEN
                       OpenMode := OpenMode+Inherit;
                    END;
                    OpenMode := OpenMode+ErrToApp;
                    (* Default setting : Error code
                       is to be send to application *)
                       
                       
                  END;
(*
 *                 IF dos2 THEN fMode := fMode MOD 4 END;
 *)                 
                  result := DosOpen(ADR(FileDesig), FileHandle, actiontaken,
                                    VAL(LONGINT,0), NormalFile, OpenFlag,
                                    OpenMode, Reserved);
(*
 *                 DOSCALL (OpenFct, ADR(FileDesig), fMode, FileHandle,
 *                          result);
 *)
                  IF (result=110) OR (result=2) OR
                     (result=18 (*too many file*)) THEN
                    IF (com = lookup) AND new THEN
                      fileCreationAttribute := NormalAttribute;
                      CreateFile(f); (*file not found, create it*)
                      new:=TRUE; (* overlap with fileCreationAttribute !!! *)
                    ELSE
                      res:=notdone (*file not found, no create specified*)
                    END
                  ELSIF result=4 THEN 
                    res:=toomanyfiles;
                    flags:=FlagSet {er,ef};
                    inUse:=FALSE
                  ELSIF result=5 THEN
                    res:=accesserror;
                  ELSIF result#0 THEN
                    res:=notdone;
                  ELSE
                    new:=FALSE;
                    InitFile(f)
                  END;
                  IF res=done THEN
                    flags := FlagSet {}; (* opened state *)
                    eof := FALSE;
                    tempFile := FALSE
                  ELSE
                    inUse := FALSE;
                    flags := FlagSet {er,ef};
                    fHint := 0FFFFH; (* for sure not valid *)
                  END;

        | rename: RenameTheFile (f, name);

        | getattrib,
          setattrib:
                  FOR i:=0 TO namelast DO
                    FileDesig[i]:=name[i];
                  END;
                  IF namelast<HIGH(FileDesig) THEN
                    FileDesig[namelast+1]:=0C;
                  END;
                  FileAttribute( (com = setattrib), f );

        | delete: 
                  FOR i:=0 TO namelast DO
                    FileDesig[i]:=name[i];
                  END;
                  IF namelast<HIGH(FileDesig) THEN
                    FileDesig[namelast+1]:=0C;
                  END;
                  
                  result := DosDelete(ADR(FileDesig), Reserved);
(*
 *                 DOSCALL (DeleteFct, ADR(FileDesig), result);
 *)
                  flags := FlagSet {ef};
                  eof := TRUE;
                  IF result=2 THEN
                    res := unknownfile;
                    INCL (flags, er);
                  ELSIF result=5 THEN
                    res := accesserror;
                  ELSE
                    res := done;
                  END;
                  inUse := FALSE; (* release the file descriptor *)
                  fHint := 65535; (* some out-of-range value *)
        ELSE      res := paramerror;
      END; (* CASE *)
    END; (* WITH *)
  END; (* WITH *)
END DiskDirProc;

END DirOperations; (*************************************************)

(*BEGIN
 *
 * DOSCALL(30H, dosMajor, dosMinor);
 * dos2 := ORD(dosMajor) < 3;
 *)

END DiskFiles.
OS2>*)
