MODULE DumpSubfile;

FROM ASCII                  IMPORT
    (* CONST *)                 cr, lf;

FROM Directory              IMPORT
    (* PROC *)                  ExtractFileNameParts;
    
FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO, FileResultMeans;
    
FROM FileSystem             IMPORT
    (* TYPE *)                  Response, File,
    (* PROC *)                  Lookup, Close, SetRead, SetPos, GetPos;

FROM Kbio                   IMPORT
    (* PROC *)                  KbioInit, KbioTerminate, BreakRequested,
                                EraseScreen;

FROM Dialog                 IMPORT
                                FatalError, Error;
    
FROM LStrings               IMPORT
    (* PROC *)                  Fill, ConcatLS, ConcatS, Procustes, SetString,
                                CtoS, SubStr, LStringToTString, StoC, RJust,
                                TStringToLString;

FROM ProgArg                IMPORT
    (* VAR *)                   Count,
    (* PROC *)                  Get, Shift;
    
FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecordPreface, ReadRecordBody, ReadRecord;
    
FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;
    
FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  DOSCALL, ADR, SIZE;

CONST
    EOSF                    = 0FFH;         (* end of subfile *)

    (*  These declarations are used in setting the set of valid numeric
        responses. *)
CONST
    HighestNumberPossible  = 65500;
    BitsPerBitSet          = 16;
    BitSetsInASetOfNumbers = (HighestNumberPossible+BitsPerBitSet-1) DIV BitsPerBitSet;

TYPE
    ASetOfNumbers          = ARRAY [0..BitSetsInASetOfNumbers-1] OF BITSET;
    
VAR
    F                       : File;
    HexCharacters           : ARRAY [0..15] OF CHAR;
    FileName                : ARRAY [0..80] OF CHAR;
    LastSubfile             : CARDINAL;
    FirstTime               : BOOLEAN;
    NextSubfile             : CARDINAL;
    SubfileNumber           : CARDINAL;
    SubfileList             : ARRAY [1..500] OF CARDINAL;
    SubfilesWanted          : ASetOfNumbers;
    s                       : ARRAY [0..255] OF CHAR;
    ErrorFlag               : BOOLEAN;

    (*--------------- Start Module BigSets. -------------------*)


PROCEDURE ReportError(VAR Message: ARRAY OF CHAR);
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    ErrorFlag := TRUE;
    SubStr(Message,S,1,HIGH(S)-20);
    ConcatS(S,"$Press [Esc].");
    Error(S);
END ReportError;




MODULE BigSets;

    IMPORT FatalError;

    EXPORT SetBit, GetBit;




PROCEDURE SetBit ( VAR SetOfNumbers : ARRAY OF BITSET;
                       Number       : CARDINAL;
                       Value        : BOOLEAN        );
VAR
    SetNumber, BitNumber : CARDINAL;
BEGIN
    SetNumber  := Number DIV 16;
    BitNumber  := Number MOD 16;
    IF (SetNumber <= HIGH(SetOfNumbers)) THEN
        IF (Value) THEN
            INCL(SetOfNumbers[SetNumber], BitNumber)
        ELSE
            EXCL(SetOfNumbers[SetNumber], BitNumber)
        END
    ELSE
        FatalError();
    END;
END SetBit;





PROCEDURE  GetBit(      SetOfNumbers   : ARRAY OF BITSET;
                        Number         : CARDINAL
                   ) : BOOLEAN;
VAR
    SetNumber : CARDINAL;
BEGIN
    SetNumber  := Number DIV 16;
    IF (SetNumber <= HIGH(SetOfNumbers)) THEN
        RETURN ( (Number MOD 16) IN SetOfNumbers[SetNumber]);
    ELSE
        RETURN FALSE;
    END;
END GetBit;



END BigSets;


    (*------------ End module BigSets. ------------------------- *)













    (*------------ Start Module Expansion. --------------------- *)

MODULE Expansion;


IMPORT ReportError, StoC, SetBit;

EXPORT ExpandSet;

CONST
    DOT     = ".";

    (* All of this expand string stuff is the DoDash procedure from
       Kernigan and Plauger, Software Tools in Pascal.  The basic
       modifications are to use numbers instead of letters, use a
       state variable (NeedNext) instead of indented structure, take
       an LString as input, and not use special symbols for NEWLINE
       and TAB.  Also, we use ellipses ("..") instead of a dash.
    *)





PROCEDURE Numeric(   C  : CHAR  ) : BOOLEAN;
BEGIN
    RETURN (C >= "0") AND (C <= "9");
END Numeric;






    (* ExpandSet -- Translate source LString to a bitset.  *)

PROCEDURE ExpandSet(VAR Source   : ARRAY OF CHAR;
                    VAR Dest     : ARRAY OF BITSET  );
VAR
    Len            : CARDINAL;
    i,k            : CARDINAL;
    C              : CHAR;
    LastNumber     : CARDINAL;
    NeedNext       : BOOLEAN;
BEGIN
    FOR i := 0 TO HIGH(Dest) DO
        Dest[i] := {};
    END;

    LastNumber     := 0;
    NeedNext       := FALSE;
    Len := ORD(Source[0]);
    i := 1;

    WHILE (i <= Len) DO
        C := Source[i];
        IF (Numeric(C)) THEN
            k := StoC(Source,i);
            IF (NeedNext) THEN  (* End of a range. *)
                IF (k >= LastNumber) THEN
                    INC(LastNumber);
                    WHILE (LastNumber <= k) DO
                        SetBit(Dest,LastNumber,TRUE);
                        INC(LastNumber);
                    END;
                ELSE
                    ReportError(Source);
                    RETURN;
                END;
                NeedNext := FALSE;
            ELSE  (* A single number, or start of a range. *)
                LastNumber := k;
                SetBit(Dest,LastNumber,TRUE);
            END;
        ELSIF (C = DOT) THEN
            IF (Source[i+1] = DOT) THEN
                NeedNext := TRUE;
                INC(i,2);
            ELSE
                ReportError(Source);    (* Single dots are not allowed. *)
                RETURN;
            END;
        ELSIF (C = ",") OR (C = " ") THEN
            INC(i);
        ELSE
            ReportError(Source);
            RETURN;
        END;
    END;
END ExpandSet;


END Expansion;



  (* -------------- End Expansion Module ------------*)

PROCEDURE CharToHex(    Character           : CHAR;
                    VAR String              : ARRAY OF CHAR);
                    
BEGIN                   (* CharToHex *)

    Fill(String, " ", 2);
    String[1] := HexCharacters[ORD(Character) DIV 16];
    String[2] := HexCharacters[ORD(Character) MOD 16];
    
END CharToHex; 

PROCEDURE PrintableChar(    Character       : CHAR)
                                                   : CHAR;

BEGIN                   (* PrintableChar *)

    IF (ORD(Character) < 32) OR (ORD(Character) >= 127) THEN
        RETURN ".";
    ELSE
        RETURN Character;
    END;
    
END PrintableChar;

PROCEDURE WriteString(VAR String            : ARRAY OF CHAR);

VAR
    i                   : CARDINAL;
    
BEGIN                   (* WriteString *)

    FOR i := 1 TO ORD(String[0]) DO
        DOSCALL(2, String[i]);
    END;
    DOSCALL(2, cr);
    DOSCALL(2, lf);
    
END WriteString;

PROCEDURE CtoHex(    Value                  : CARDINAL;
                 VAR Hex                    : ARRAY OF CHAR);
                 
BEGIN                   (* CtoHex *)

    Fill(Hex, " ", 4);
    Hex[1] := HexCharacters[Value DIV 01000H];
    Hex[2] := HexCharacters[(Value MOD 01000H) DIV 0100H];
    Hex[3] := HexCharacters[(Value MOD 00100H) DIV 010H];
    Hex[4] := HexCharacters[Value MOD 00010H];
    
END CtoHex;

PROCEDURE FormatForOutput(    Offset        : CARDINAL;
                              Data          : ARRAY OF CHAR;
                          VAR String        : ARRAY OF CHAR);

VAR
    s                   : ARRAY [0..80] OF CHAR;
    i                   : CARDINAL;
    
BEGIN                   (* FormatForOutput *)

    Fill(String, " ", 5);
    CtoHex(Offset, s);
    ConcatLS(String, s);
    ConcatS(String, ": ");
    FOR i := 1 TO ORD(Data[0]) DO
        IF i = 9 THEN
            ConcatS(String, "-");
        ELSE
            ConcatS(String, " ");
        END;
        CharToHex(Data[i], s);
        ConcatLS(String, s);
    END;
    Procustes(String, 62);
    FOR i := 1 TO ORD(Data[0]) DO
        INC(String[0]);
        String[ORD(String[0])] := PrintableChar(Data[i]);
    END;
    
END FormatForOutput;

PROCEDURE PrintARecord(    Record           : ADDRESS;
                           Size             : CARDINAL);

VAR
    i                   : CARDINAL;
    s, s2               : ARRAY [0..80] OF CHAR;
    data                : POINTER TO CHAR;
    offset              : CARDINAL;
    
BEGIN                   (* PrintARecord *)

    i := 0;
    offset := 0;
    WHILE i < Size DO
        data := Record;
        s[(i MOD 16) + 1] := data^;
        INC(i);
        INC(Record);
        IF (i MOD 16) = 0 THEN
            s[0] := CHR(16);
            FormatForOutput(offset, s, s2);
            WriteString(s2);
            offset := i;
        END;
    END;
    IF (i MOD 16) > 0 THEN
        s[0] := CHR(i MOD 16);
        FormatForOutput(offset, s, s2);
        WriteString(s2);
    END;
    
END PrintARecord;

PROCEDURE PrintASubfile(VAR F               : File;
                            Subfile         : CARDINAL);

VAR
    i                   : CARDINAL;
    type                : CARDINAL;
    version             : CARDINAL;
    length              : CARDINAL;
    record              : ARRAY [0..8192] OF CHAR;
    s2                  : ARRAY [0..80] OF CHAR;
    h, l                : CARDINAL;
    
BEGIN                   (* PrintASubfile *)

    PrepareForIO(F);
    SetPos(F, 0, 0);

    IF StartFileInput(F) THEN
        IF StartSubfileInput(F, Subfile, version) THEN
            Fill(s, " ", 0);
            WriteString(s);
            WriteString(s);
            WriteString(s);
            WriteString(s);
            WriteString(s);
            SetString(s, "File: ");
            ConcatLS(s, FileName);
            ConcatS(s, "    Subfile: ");
            CtoS(Subfile, s2);
            ConcatLS(s, s2);
            ConcatS(s, "    Version: ");
            CtoS(version, s2);
            ConcatLS(s, s2);
            WriteString(s);
            Fill(s, " ", 0);
            WriteString(s);
            WriteString(s);
            i := 1;
            LOOP
                IF BreakRequested() OR ErrorFlag THEN
                    RETURN;
                END;

                GetPos(F, h, l);
                ReadRecordPreface(F, type, length);
                IF NOT F.eof AND (F.res = done) AND (type <> EOSF) THEN
                    ReadRecordBody(F, length, ADR(record), SIZE(record));
                    SetString(s, "Record: ");
                    CtoS(i, s2);
                    ConcatLS(s, s2);
                    ConcatS(s, "    Type: ");
                    CtoS(type, s2);
                    ConcatLS(s, s2);
                    ConcatS(s, "    Length: ");
                    CtoS(length, s2);
                    ConcatLS(s, s2);
                    WriteString(s);
                    Fill(s2, " ", 0);
                    WriteString(s2);
                    CtoHex(h, s);
                    ConcatS(s, ":");
                    CtoHex(l, s2);
                    ConcatLS(s, s2);
                    ConcatS(s, "    0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F");
                    IF length < 16 THEN
                        s[0] := CHR(3 * length + 11);
                    END;
                    WriteString(s);
                    SetString(s, "            -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --");
                    IF length < 16 THEN
                        s[0] := CHR(3 * length + 11);
                    END;
                    WriteString(s);
                    PrintARecord(ADR(record), length);
                    Fill(s2, " ", 0);
                    WriteString(s2);
                    WriteString(s2);
                    INC(i);
                ELSE
            EXIT;
                END;
            END;
            
            IF NOT (type = EOSF) THEN
                SetString(s, "Error reading file ");
                ConcatLS(s, FileName);
                ReportError(s);
            END;
        ELSE
            SetString(s, "Can't find subfile ");
            CtoS(Subfile, s2);
            ConcatLS(s, s2);
            ConcatS(s, " in file ");
            ConcatLS(s, FileName);
            ReportError(s);
        END;
    ELSE
        SubStr(FileName, s, 1, HIGH(s));
        ConcatS(s, " is not a file of subfiles.");
        ReportError(s);
    END;
         
END PrintASubfile;         

PROCEDURE GetFileName(VAR Filename          : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    device              : ARRAY [0..3] OF CHAR;
    path                : ARRAY [0..64] OF CHAR;
    file                : ARRAY [0..8] OF CHAR;
    extension           : ARRAY [0..3] OF CHAR;
    current             : ARRAY [0..64] OF CHAR;
    error               : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;
    
BEGIN                   (* GetFileName *)

    IF Count < 2 THEN
        SetString(s, "Usage:$dumpsubf filename num[..num]{,num[..num]}");
        ConcatS(s,   "$$e.g.:$dumpsubf   \tldata\fred.t@0   0..9999");
        ReportError(s);
        RETURN FALSE;
    ELSE
        Get(0, s);
        TStringToLString(s, Filename);
        ExtractFileNameParts(Filename, device, path, file, extension);
        SubStr(device, s, 1, HIGH(s));
        IF (ORD(path[0]) = 0) OR (path[1] <> "\") THEN
            DOSCALL(47H, (ORD(device[1]) - ORD("A")) + 1, ADR(current), error);
            ConcatS(s, "\");
            TStringToLString(current, current);
            ConcatLS(s, current);
            ConcatS(s, "\");
        END;
        ConcatLS(s, path);
        ConcatLS(s, file);
        ConcatS(s, ".");
        ConcatLS(s, extension);
        SubStr(s, Filename, 1, HIGH(Filename));
    END;
    
    RETURN TRUE;
    
END GetFileName;

PROCEDURE MakeSubfileList();

CONST
    DIRR            = 0F2H;

TYPE
    ADirectoryEntry = RECORD
                          SubfileNumber   : CARDINAL;
                          Low,
                          High            : CARDINAL;
                          VersionNo       : CARDINAL;
                      END;

VAR
    FileHeader       : CARDINAL;
    DirectoryEntry   : ADirectoryEntry;
    Type             : CARDINAL;
    s2               : ARRAY [0..80] OF CHAR;

    PROCEDURE PostError(VAR F               : File);
    
    VAR
        s                   : ARRAY [0..80] OF CHAR;
        s2                  : ARRAY [0..80] OF CHAR;
        h, l                : CARDINAL;
        
    BEGIN
        SetString(s, "File Error ");
        FileResultMeans(F, s2);
        ConcatLS(s, s2);
        ConcatS(s, " on ");
        ConcatLS(s, FileName);
        ReportError(s);
        GetPos(F, h, l);
    END PostError;
    
    
BEGIN                   (* MakeSubfileList *)

    Get(1, s2);
    TStringToLString(s2, s);
    REPEAT
        Shift();
        Get(1, s2);
        TStringToLString(s2, s2);
        IF ORD(s2[0]) > 0 THEN
            ConcatS(s, ",");
            ConcatLS(s, s2);
        END;
    UNTIL ORD(s2[0]) = 0;
    ExpandSet(s, SubfilesWanted);
    
    PrepareForIO(F);
    SetRead(F);
    SetPos(F,0,0);
    LastSubfile := 0;
    ReadRecord(F,Type,ADR(FileHeader),0);
    IF CheckIO(F) <> done THEN
        PostError(F);
        RETURN;
    END;
    LOOP
        ReadRecord(F,Type,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        IF CheckIO(F) <> done THEN
            PostError(F);
            RETURN;
        END;
        IF (Type <> DIRR) THEN
    EXIT;
        END;
        IF DirectoryEntry.SubfileNumber <> 65535 THEN
            INC(LastSubfile);
            SubfileList[LastSubfile] := DirectoryEntry.SubfileNumber;
        END;
    END;

END MakeSubfileList;

PROCEDURE PrintSubfileList();

VAR
    i                   : CARDINAL;
    s2                  : ARRAY [0..20] OF CHAR;
    
BEGIN                   (* PrintSubfileList *)

    SetString(s, "File ");
    ConcatLS(s, FileName);
    ConcatS(s, " contains the following subfiles:");
    WriteString(s);
    Fill(s, " ", 0);
    WriteString(s);
    FOR i := 1 TO LastSubfile DO
        CtoS(SubfileList[i], s2);
        Procustes(s2, 7);
        RJust(s2);
        ConcatLS(s, s2);
        IF ORD(s[0]) >= 70 THEN
            WriteString(s);
            Fill(s, " ", 0);
        END;
    END;

    IF ORD(s[0]) > 0 THEN
        WriteString(s);
    END;

END PrintSubfileList;

PROCEDURE SortSubfileList();

VAR
    i, j, k             : CARDINAL;
    changed             : BOOLEAN;
    
BEGIN                   (* SortSubfileList *)

    FOR i := 1 TO LastSubfile - 1 DO
        changed := FALSE;
        FOR j := LastSubfile TO i + 1 BY -1 DO
            IF SubfileList[j] < SubfileList[j - 1] THEN
                changed := TRUE;
                k := SubfileList[j];
                SubfileList[j] := SubfileList[j - 1];
                SubfileList[j - 1] := k;
            END;
        END;
        IF NOT changed THEN
            RETURN;
        END;
    END;
    
END SortSubfileList;

PROCEDURE GetSubfileNumber(VAR Subfile      : CARDINAL)
                                                       : BOOLEAN;
                                                       
VAR
    i                   : CARDINAL;
    s2                  : ARRAY [0..80] OF CHAR;
    
BEGIN                   (* GetSubfileNumber *)

    IF BreakRequested() THEN RETURN FALSE; END;
    
    REPEAT
        Subfile := SubfileList[NextSubfile];
        IF NextSubfile > LastSubfile THEN
            RETURN FALSE;
        END;
        INC(NextSubfile);
    UNTIL GetBit(SubfilesWanted, Subfile);
            
    RETURN TRUE;
    
END GetSubfileNumber;              

BEGIN                   (* DumpSubfile *)
    ErrorFlag := FALSE;

    KbioInit();
    EraseScreen;

    HexCharacters := "0123456789ABCDEF";
    NextSubfile := 1;

    IF GetFileName(FileName) THEN
        LStringToTString(FileName, s);
        Lookup(F, s, FALSE);
        IF F.res = done THEN
            MakeSubfileList();
            PrintSubfileList();
            SortSubfileList();
            WHILE (NOT ErrorFlag) AND GetSubfileNumber(SubfileNumber) DO
                PrintASubfile(F, SubfileNumber);
            END;
            Close(F);
        ELSE
            SetString(s, "Cannot open ");
            ConcatLS(s, FileName);
            ReportError(s);
        END;
    END;

    KbioTerminate();
    
END DumpSubfile.
