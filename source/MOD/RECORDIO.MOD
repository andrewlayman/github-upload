IMPLEMENTATION MODULE RecordIO;

(* 27-Jan-91 RSC Tried to speed up record reading and writing. *)


FROM FileSystem   IMPORT File, Response, ReadByte, ReadWord,
                         WriteByte, WriteWord, ReadNBytes,
                         WriteNBytes;

FROM FileAux      IMPORT PrepareForIO, CheckIO, FileResultMeans;

FROM Dialog       IMPORT Error, FatalError, NotYetImplemented;

FROM LStrings     IMPORT SetString;

FROM SYSTEM       IMPORT ADDRESS, ADR, TSIZE;

FROM MsgFile      IMPORT GetMessage;

CONST
    ModuleNumber = 11100;    (* For GetMessage *)






CONST
     RecordTag   =  CHAR(55H);

    (* Records are composed, structurally, of two parts: a preface
       and a body.  The preface contains a Type code and a count
       of the number of bytes in the body of the record.

       Type codes are in the range of 0..EF hexadecimal.  Codes
       F0..FF are reserved for internal bookkeeping, though code
       FF indicates not a data record, but an end of a subfile.
    *)





PROCEDURE BadTag(VAR F:File);
VAR
    s : ARRAY [0..80] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);   (*  "Bad data file internal structure."  *)
    Error(s);
    F.eof := TRUE;
    F.res := notdone;
END BadTag;





PROCEDURE FileComplaint(VAR   F  :  File);
VAR
    s : ARRAY [0..80] OF CHAR;
BEGIN
    FileResultMeans(F,s);
    Error(s);
END FileComplaint;



TYPE
(*$A-*)
    ARecordHeader = RECORD
        TheRecordTag   : CHAR;
        TheType        : CHAR;
        TheLength      : CARDINAL;
    END;
(*$A=*)



PROCEDURE WriteRecord(VAR F             : File;
                          Type          : CARDINAL;
                          RecordAddress : ADDRESS;
                          Length        : CARDINAL);
VAR
    Header : ARecordHeader;
    j      : CARDINAL;
BEGIN
    IF (CheckIO(F) = done) THEN
        WITH Header DO
            TheRecordTag := RecordTag;
            TheType      := CHR(Type);
            TheLength    := Length;
        END;

(*        WriteByte(F,CHR(RecordTag));*)
(*        WriteByte(F,CHR(Type));*)
(*        WriteWord(F,Length);*)

        WriteNBytes(F,ADR(Header),TSIZE(ARecordHeader),j);

        WriteNBytes(F,RecordAddress,Length,j);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
        END;
    END;
END WriteRecord;







    (*  ReadRecord -- Reads a record into a buffer.  Also returns
                      the type code. *)

PROCEDURE ReadRecord (VAR F             : File;
                      VAR Type          : CARDINAL;
                          RecordAddress : ADDRESS;
                          MaxLength     : CARDINAL);
VAR
    Length : CARDINAL;
BEGIN
    ReadRecordPreface(F,Type,Length);
    ReadRecordBody(F,Length,RecordAddress,MaxLength);
END ReadRecord;











    (*  ReadRecordPreface -- Reads the preface of the record, returning
                             the Type and Length of the following record
                             body. *)

PROCEDURE ReadRecordPreface( VAR F      : File;
                             VAR Type   : CARDINAL;
                             VAR Length : CARDINAL    );
VAR
    Header : ARecordHeader;
    j      : CARDINAL;
BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    ReadNBytes(F,ADR(Header),TSIZE(ARecordHeader),j);

    WITH Header DO
        Type   := ORD(TheType);
        Length := TheLength;

        IF (TheRecordTag <> RecordTag) THEN
            BadTag(F);
            Length := 0;
            Type   := 255;
        END;

        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            Length := 0;
            Type   := 255;
        END;
    END;

(*    ReadByte(F,C);                   (* Tag Field *)*)
(*    IF (ORD(C) <> RecordTag) THEN*)
(*        BadTag(F);*)
(*        Type := 0FFH;*)
(*        Length := 0;*)
(*        RETURN;*)
(*    END;*)

(*    ReadByte(F,C);*)
(*    Type := ORD(C);*)

(*    ReadWord(F,Length);               (*  Count field in file. *)*)

(*    IF (CheckIO(F) <> done) THEN*)
(*        FileComplaint(F);*)
(*        Type := 0FFH;*)
(*        Length := 0;*)
(*    END;*)

END ReadRecordPreface;







    (*  ReadRecordBody -- After a call to ReadRecordPreface, reads
                          the record body. *)

PROCEDURE ReadRecordBody( VAR F             : File;
                              Length        : CARDINAL;
                              RecordAddress : ADDRESS;
                              MaxLength     : CARDINAL);
VAR
    p : POINTER TO CHAR;
    i : CARDINAL;
    C : CHAR;
    IgnoreN : CARDINAL;
BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    IgnoreN := 0;

    IF (Length > MaxLength) THEN
    	IgnoreN := Length-MaxLength;
        Length := MaxLength;
    END;

    ReadNBytes(F,RecordAddress,Length,i);
    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN;
    END;
    IF (i < Length) THEN
        BadTag(F);
        RETURN;
    END;

        (*  If the file structure has fewer bytes than were asked for,
            pad the structure will nulls. *)

    INC(RecordAddress,i);

    WHILE (i < MaxLength) DO
        p := RecordAddress;
        p^ := 0C;
        INC(i);
        INC(RecordAddress);
    END;

        (* In case there were more bytes in the file than we can
           find room for. *)

    WHILE (IgnoreN > 0) DO
        ReadByte(F,C);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            RETURN;
        END;
        DEC(IgnoreN);
    END;
END ReadRecordBody;











    (* WriteString -- Writes an LString to the file. *)

PROCEDURE WriteString(VAR F         : File;
                          Type      : CARDINAL;
                      VAR String    : ARRAY OF CHAR);
VAR
    Length : CARDINAL;
BEGIN
    Length := ORD(String[0])+1;
    WriteRecord(F,Type,ADR(String),Length);
END WriteString;







    (* ReadString -- Read an LString from the file, up to the
                     maximum room in String. *)

PROCEDURE ReadString (VAR F         : File;
                      VAR String    : ARRAY OF CHAR);
VAR
    Length : CARDINAL;
    Type   : CARDINAL;
BEGIN
    ReadRecordPreface(F,Type,Length);
    ReadStringBody(F,Length,String);
END ReadString;







    (* ReadStringBody -- Read an LString from the file, up to the
                         maximum room in String. *)

PROCEDURE ReadStringBody (VAR F         : File;
                              Length    : CARDINAL;
                          VAR String    : ARRAY OF CHAR);
BEGIN
    ReadRecordBody(F,Length,ADR(String),HIGH(String)+1);
        (* Trim any strings that are too long. *)
    IF (ORD(String[0]) > HIGH(String)) THEN
        String[0] := CHR(HIGH(String));
    END;
END ReadStringBody;







END RecordIO.
