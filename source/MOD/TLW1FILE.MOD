IMPLEMENTATION MODULE TLW1File;



    (* Definition of records in the Time Line Windows 1.0 file format.

    MODIFICATION HISTORY:

    13-Jan-92 AJL   Created from OTFIles.mod.
     4-Mar-92 TGS   Move ReadStringBody here. It now does ANSIToOEM
                    conversion.
    16-Mar-92 LAA   Defined the SetKindOfFile procedure and it's associated
                    enumeration type.
    *)


FROM Dialog                 IMPORT
    (* PROC *)                  ErrorPhrase;

FROM FileAux                IMPORT 
    (* PROC *)                  PrepareForIO, CheckIO,
                                DisplayFileError;

FROM FileSystem             IMPORT
                                File, Response, 
                                ReadNBytes, 
                                ReadByte, SetRead, GetPos,
                                SetPos, Reset;

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          DecodeString, DoDash, ConvertString;

FROM LStrings       IMPORT
                        Copy, TrimRear, SetLengthOf, LengthOf,
                        LJust, TStringToLString, Upshift;

FROM MsgFile                IMPORT  GetMessage;

FROM SYSTEM                 IMPORT    
    (* TYPE *)                  BYTE,
    (* PROC *)                  ADR, SIZE, TSIZE;



CONST
    ModuleNumber = 30600;   (* Share with TLLnkTW1 and TLVUTW1 *)


VAR
    CharacterTable          : ACharacterConversionTable;
    FileKind                : AKindOfFile;



PROCEDURE FileComplaint(VAR F:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Time Line Windows file " *)
    DisplayFileError( F, s );
END FileComplaint;



    (*  SetKindOfFile --
        Condition all other procedures here for reading the various kinds
        of Time Line for Windows files (including OnTarget).  The default
        if this procedure is not called is RockyFile.
    *)

PROCEDURE SetKindOfFile(     KindOfFile     : AKindOfFile );

BEGIN                       (* SetKindOfFile *)

    FileKind := KindOfFile;

END SetKindOfFile;



    (*  KindOfFile --
        Determine the kind of file currently being read with this module.
        This is set ONLY via SetKindOfFile, so this procedure just makes it
        possible to retain this information in just one place.
    *)

PROCEDURE KindOfFile() : AKindOfFile;

BEGIN                       (* KindOfFile *)

    RETURN FileKind;

END KindOfFile;


    (*  ReadRecordPreface -- Reads the preface of the record, returning
                             the Type and Length of the following record
                             body. *)

PROCEDURE ReadRecordPreface( VAR F      : File;
                             VAR Type   : CARDINAL;
                             VAR ID     : CARDINAL;
                             VAR Length : LONGINT    );
VAR
    i       : CARDINAL;
    size    : CARDINAL;
    Preface : RECORD
                  Type   : CARDINAL;
                  ID     : CARDINAL;
                  CASE AKindOfFile OF
                    OnTargetFile :
                        OTLength  : CARDINAL;
                  | RockyFile :
                        Length : LONGINT;
                  END;
              END;

BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    PrepareForIO(F);

    IF (FileKind = OnTargetFile) THEN
        size := SIZE(Preface) - TSIZE(CARDINAL);
    ELSE
        size := SIZE(Preface);
    END;
    ReadNBytes(F,ADR(Preface),size,i);

    IF (CheckIO(F) <> done) OR (i <> size) THEN
        FileComplaint(F);
        Type := 0FFH;
        Length := 0L;
        RETURN;
    END;

    Type   := Preface.Type;
    ID     := Preface.ID;
    IF (FileKind = OnTargetFile) THEN
        Length := VAL(LONGINT, Preface.OTLength);
    ELSE
        Length := Preface.Length;
    END;


END ReadRecordPreface;





    (*  ReadRecordBody -- After a call to ReadRecordPreface, reads
                          the record body.
                          
                          Implementation restriction: Length must be
                          <= 32768. 
                          
                          *)

PROCEDURE ReadRecordBody( VAR F             : File;
                              Length        : LONGINT;
                          VAR Record        : ARRAY OF BYTE);
VAR
    p : POINTER TO ARRAY [0..32767] OF CHAR;
    i : CARDINAL;
    C : CHAR;
    IgnoreN : CARDINAL;
    Len     : CARDINAL;
BEGIN
        (* Implementation restriction: Length must be <= 32768. *)
    IF (Length <= VAL(LONGINT,HIGH(p^))) THEN
        Len := VAL(CARDINAL,Length);
    ELSE
        ErrorPhrase(ModuleNumber + 18);
        Len := HIGH(p^);
    END;

    IF (CheckIO(F) <> done) THEN RETURN; END;

    PrepareForIO(F);

    IgnoreN := 0;

    IF (Len > HIGH(Record)+1) THEN
    	IgnoreN := Len-HIGH(Record)-1;
        Len := HIGH(Record)+1;
    END;

    p := ADR(Record);

    ReadNBytes(F,p,Len,i);
    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN;
    END;
    IF (i < Len) THEN
        FileComplaint(F);
        RETURN;
    END;

        (*  If the file structure has fewer bytes than were asked for,
            pad the structure will nulls. *)

    WHILE (i <= HIGH(Record)) DO
        p^[i] := 0C;
        INC(i);
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


    (* ReadStringBody -- Read a string in, do ANSIToOEM conversion. *)


PROCEDURE ReadStringBody( VAR F : File;
                              Length : LONGINT;
                          VAR S : ARRAY OF CHAR );

CONST
    MaxLength = 255L;
VAR
    LocalString : ARRAY [0..255] OF CHAR;
BEGIN
    IF (Length <= MaxLength) THEN
        ReadRecordBody(F,Length,LocalString);
    ELSE
        ReadRecordBody(F,MaxLength,LocalString);
        S[255] := 0C;
        SkipRecordBody(F,Length-MaxLength);
    END;
    TStringToLString(LocalString,LocalString);
    Copy( LocalString, S );
    ConvertString(S, CharacterTable);       (* 3-Mar-92 TGS *)
END ReadStringBody;


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : LONGINT );
VAR
    Trick : RECORD CASE BOOLEAN OF
                FALSE  :  Low, High : CARDINAL;
               |TRUE   :  Long      : LONGINT;
            END END;
BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    PrepareForIO(F);

        (* Advance the file pointer. *)

    WITH Trick DO
        GetPos (F, High, Low);
        Long := Long + Length;
        SetPos (F, High, Low);
    END;

    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN;
    END;
END SkipRecordBody;







    (* StartFileInput -- Check the file for valid format *)

PROCEDURE StartFileInput      (VAR F                : File;
                               VAR FileHeaderRecord : AFileHeaderRecord ):BOOLEAN;

CONST
    WhatVersionWeAre  = 3C;
VAR
    Type              : CARDINAL;
    ID                : CARDINAL;
    Length            : LONGINT;
BEGIN
    PrepareForIO(F);                                               (* 11/12/86 LAA *)
    Reset(F);                   (* 2/8/89 EGK *)
    SetRead(F);
    ReadRecordPreface(F,Type,ID,Length);
    IF (Type <> 3) THEN
        ErrorPhrase(ModuleNumber+8);
        RETURN FALSE;
    ELSIF (Length <> VAL(LONGINT,SIZE(FileHeaderRecord))) THEN
        ErrorPhrase(ModuleNumber+9);
        RETURN FALSE;
    END;

    ReadRecordBody(F,Length,FileHeaderRecord);
    IF (CheckIO(F) <> done) THEN
        RETURN FALSE;
    END;

    WITH FileHeaderRecord DO
        IF (CanRead > WhatVersionWeAre) THEN
            ErrorPhrase(ModuleNumber+10);
            RETURN FALSE;
        ELSIF (Checksum <> 0ABABH) THEN
            ErrorPhrase(ModuleNumber+11);
            RETURN FALSE;
        END;
    END;


    RETURN TRUE;
END StartFileInput;

    (* Build the character translation table used to do ANSIToOEM
        conversion. *)

PROCEDURE BuildCharacterTable ();
VAR 
    i               : CARDINAL; 
    From            : ARRAY [0..199] OF CHAR; 
    To              : ARRAY [0..127] OF CHAR; 
    Pos             : CARDINAL; 

BEGIN 
    i := 0;
    Pos := 0; 

    LOOP
        IF (Pos > 255) THEN 
            EXIT; 
        END;

        GetMessage (6020+i, From);  

        IF (LengthOf(From) = 0) THEN
            EXIT; 
        END;
        DecodeString (From, To);
        DoDash (To, CharacterTable, Pos); 
        INC (i);
    END;
END BuildCharacterTable;

BEGIN

    BuildCharacterTable();
    FileKind := RockyFile;

END TLW1File.



