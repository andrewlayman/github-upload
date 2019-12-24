IMPLEMENTATION MODULE LANFile;

    (*  LANFile - provides access to LAN master files used by Time Line and
                  Time Line related products.


        MODIFICATION HISTORY :

        22-Jun-89 WKH   Initial version adapted from code written by MWP at
                        Synex Systems.
        21-Sep-89 RSC   Added local ByteXor, removing the need for
                        BitBlockOps.  Even though optimized, there was
                        still a fair amount of residual code left.
                        As this is used in TLITL4, that hurt us a little bit.
        28-Sep-89 LAA   Removed the use of Strings in favor of LString.
    *)

FROM SYSTEM                 IMPORT
    (* TYPE *)                  BYTE, 
    (* PROC *)                  ADR, TSIZE;

FROM LStrings               IMPORT
    (* PROC *)                  StringsEqual, TStringToLString;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  Lookup, SetRead, Close, ReadNBytes, SetPos,
                                GetPos;


CONST
    ModuleNumber            = 7700;

    XORPat                  = 055H;

VAR
    ActualStartOfRecordHigh : CARDINAL;
    ActualStartOfRecordLow  : CARDINAL;
    LocalNumUsers           : CARDINAL;




PROCEDURE ByteXor( SourceByte, XORWith : BYTE ) : BYTE;
BEGIN
    RETURN BYTE(CHR(CARDINAL(BITSET(ORD(SourceByte)) / BITSET(ORD(XORWith)))));
END ByteXor;






PROCEDURE DecodeLANFileHeader(VAR Header : CARDINAL);

TYPE
    AFakeOutRecord          = RECORD
                                HighByte : BYTE;
                                LowByte  : BYTE;
                              END;

VAR
    Temp                    : AFakeOutRecord;

BEGIN
    (* decode count *)
    Temp := AFakeOutRecord(Header);

    Temp.HighByte := ByteXor(Temp.HighByte, XORPat);
    Temp.LowByte  := ByteXor(Temp.LowByte,  XORPat);

    Header := CARDINAL(Temp);
END DecodeLANFileHeader;


PROCEDURE DecodeUserRecord(VAR UserRecord : AUserRecord);

VAR 
    i                       : CARDINAL;

BEGIN
    WITH UserRecord DO
        FOR i := 0 TO (UserNameSize - 1) DO
            UserName[i] := CHAR(ByteXor(BYTE(UserName[i]), XORPat));
        END;

        FOR i := 0 TO (SerialNumSize - 1) DO
            SerialNumber[i] := CHAR(ByteXor(BYTE(SerialNumber[i]), XORPat));
        END;

        FOR i := 0 TO (SemaphoreFileNameSize - 1) DO
            UniqueFName[i] := CHAR(ByteXor(BYTE(UniqueFName[i]), XORPat));
        END;

        FOR i := 0 TO (PasswordSize - 1) DO
            Password[i] := CHAR(ByteXor(BYTE(Password[i]), XORPat));
        END;

        FOR i := 0 TO (ReservedBytesSize - 1) DO
            Reserved[i] := CHAR(ByteXor(BYTE(Reserved[i]), XORPat));
        END;
    END;
END DecodeUserRecord;


PROCEDURE ComputeFilePos(    RecNum : CARDINAL;
                         VAR High   : CARDINAL;
                         VAR Low    : CARDINAL);

CONST
    MAXREALCARDINAL         = 65536.0;

VAR
    NormalizedFilePos       : REAL;
    NormalizedOffset        : REAL;

BEGIN
    (* Compute the start of our data *)
    NormalizedFilePos := FLOAT(ActualStartOfRecordHigh);
    NormalizedFilePos := NormalizedFilePos * MAXREALCARDINAL;
    NormalizedFilePos := NormalizedFilePos + FLOAT(ActualStartOfRecordLow);

    (* Compute offset we want *)
    NormalizedOffset  := FLOAT(RecNum);
    NormalizedOffset  := NormalizedOffset * FLOAT(TSIZE(AUserRecord));

    (* Combine offset with starting file pos *)
    NormalizedFilePos := NormalizedFilePos + NormalizedOffset;

    (* Re-segment normalized file position *)
    High              := TRUNC(NormalizedFilePos / MAXREALCARDINAL);
    NormalizedFilePos := NormalizedFilePos - (FLOAT(High) * MAXREALCARDINAL);
    Low               := TRUNC(NormalizedFilePos);
END ComputeFilePos;


PROCEDURE StartLANFileInput(VAR f          : File;
                            VAR NumUsers   : CARDINAL) : BOOLEAN;

VAR
    LocalCard               : CARDINAL;
    BytesRead               : CARDINAL;
    AOk                     : BOOLEAN;

BEGIN
    AOk := TRUE;  (* let's be optimistic... *)

    (* PrepareForIO(f); *)
    ReadNBytes(f, ADR(LocalCard), TSIZE(CARDINAL), BytesRead);

    IF (f.res <> done) THEN  (* use CheckIO *)
        AOk := FALSE;
    ELSE
        GetPos(f, ActualStartOfRecordHigh, ActualStartOfRecordLow);
        DecodeLANFileHeader(LocalCard);
        NumUsers      := LocalCard;
        LocalNumUsers := NumUsers;
    END;

    RETURN AOk;
END StartLANFileInput;


PROCEDURE SearchLANFile(VAR f              : File;
                        VAR UserName       : ARRAY OF CHAR;
                        VAR UserRecord     : AUserRecord) : BOOLEAN;

VAR
    i                       : CARDINAL;
    CompareVal              : INTEGER;
    LocalUserRecord         : AUserRecord;
    Found                   : BOOLEAN;
    s, s2                   : ARRAY [0..255] OF CHAR;

BEGIN
    i     := 0;
    Found := FALSE;

    (* do sequential search for now, replace with binary later *)
    LOOP
        IF (i >= LocalNumUsers) OR (Found) THEN
            EXIT;
        END;

        IF (NOT ReadLANFileRecord(f, i, LocalUserRecord)) THEN
            Found := FALSE;
            i     := LocalNumUsers; (* force an exit *)
        ELSE
            TStringToLString(UserName, s);                        (* 28-Sep-89 LAA *)
            TStringToLString(LocalUserRecord.UserName, s2);
            IF (StringsEqual(s, s2)) THEN
                Found      := TRUE;
                UserRecord := LocalUserRecord;
            ELSE
                INC(i);
            END;
        END;
    END;

    RETURN Found;
END SearchLANFile;


PROCEDURE ReadLANFileRecord(VAR f          : File;
                                RecNum     : CARDINAL;
                            VAR UserRecord : AUserRecord) : BOOLEAN;

VAR
    FilePosHigh             : CARDINAL;
    FilePosLow              : CARDINAL;
    BytesRead               : CARDINAL;
    LocalUserRecord         : AUserRecord;
    AOk                     : BOOLEAN;

BEGIN
    AOk := TRUE;  (* let's be optimistic... *)

    ComputeFilePos(RecNum, FilePosHigh, FilePosLow);

    (* PrepareForIO(f); *)
    SetPos(f, FilePosHigh, FilePosLow);

    IF (f.res <> done) THEN  (* use CheckIO *)
        AOk := FALSE;
    ELSE
        (* PrepareForIO(f); *)
        ReadNBytes(f, ADR(LocalUserRecord), TSIZE(AUserRecord), BytesRead);
    
        IF (f.res <> done) THEN  (* use CheckIO *)
            AOk := FALSE;
        ELSE
            DecodeUserRecord(LocalUserRecord);
            UserRecord := LocalUserRecord;
        END;
    END;

    RETURN AOk;
END ReadLANFileRecord;


BEGIN
    ActualStartOfRecordHigh := 0;
    ActualStartOfRecordLow  := 0;
    LocalNumUsers           := 0;
END LANFile.
