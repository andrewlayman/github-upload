IMPLEMENTATION MODULE OTFiles;



    (* Definition of records in the OnTarget file format.
       See also the implementation module for additional, internally
       used records.

       MODIFICATION HISTORY:

       26-Feb-91 AJL  Changed the record formats.


    *)


FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM FileAux                IMPORT 
    (* PROC *)                  PrepareForIO, CheckIO, FileResultMeans,
                                DisplayFileError;

FROM FileSystem             IMPORT
                                File, Response, Close,
                                OpenFile, ReadNBytes, 
                                FullAccessMode, ReadOnlyMode, 
                                ReadByte, ReadWord, SetRead, SetPos,
                                Reset;

FROM MsgFile                IMPORT  GetMessage;

FROM SYSTEM                 IMPORT    
    (* TYPE *)                  BYTE,
    (* PROC *)                  ADR, SIZE;



CONST
    ModuleNumber = 16600;   (* Share with TLLnkOT and TLViewOT?? *)


TYPE
    (*$A- *)   (* Alignment off *)

    AFileHeaderRecord = RECORD
                          VersionMinor    : CHAR;
                          VersionMajor    : CHAR;
                          NumberOfTasks,
                          NumberOfResources     : INTEGER;
                          Checksum              : CARDINAL;
                          NumberOfPredecessors,
                          NumberOfAssignments,
                          Dummy1,
                          MaximumTaskID,
                          MaximumResourceID,
                          Dummy2,
                          MaximumPredecessorID,
                          MaximumAssignmentID,
                          Dummy3                : INTEGER;
                          Flags                 : BITSET;
                          TenthHoursPerWorkDay,
                          TenthHoursPerWorkWeek,
                          TenthHoursPerWorkMonth,
                          TenthHoursPerWorkYear : LONGINT;
                          AsOfDate              : LONGINT;
                          Dummy4                : ARRAY [0..7] OF CHAR;
                          CanRead,
                          CantRead              : CHAR;
                          Reserved1             : ARRAY [0..1] OF INTEGER;
                          RecalcRequired        : INTEGER;
                          Date                  : CARDINAL;
                          NumberOfFonts         : INTEGER;
                          Reserved2             : ARRAY [0..15] OF INTEGER;
                      END;

    (*$A= *)   (* Alignment restore *)





PROCEDURE FileComplaint(VAR F:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Detail file " *)
    DisplayFileError( F, s );        (* RSC 2/19/88    *)
END FileComplaint;


PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;



    (*  ReadRecordPreface -- Reads the preface of the record, returning
                             the Type and Length of the following record
                             body. *)

PROCEDURE ReadRecordPreface( VAR F      : File;
                             VAR Type   : CARDINAL;
                             VAR ID     : CARDINAL;
                             VAR Length : CARDINAL    );
VAR
    i       : CARDINAL;
    Preface : RECORD
                  Type   : CARDINAL;
                  ID     : CARDINAL;
                  Length : CARDINAL;
              END;
BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    PrepareForIO(F);

    ReadNBytes(F,ADR(Preface),SIZE(Preface),i);
    IF (CheckIO(F) <> done) OR (i < SIZE(Preface)) THEN
        FileComplaint(F);
        Type := 0FFH;
        Length := 0;
        RETURN;
    END;

    Type   := Preface.Type;
    ID     := Preface.ID;
    Length := Preface.Length;


END ReadRecordPreface;





    (*  ReadRecordBody -- After a call to ReadRecordPreface, reads
                          the record body. *)

PROCEDURE ReadRecordBody( VAR F             : File;
                              Length        : CARDINAL;
                          VAR Record        : ARRAY OF BYTE);
VAR
    p : POINTER TO ARRAY [0..32767] OF CHAR;
    i : CARDINAL;
    C : CHAR;
    IgnoreN : CARDINAL;
BEGIN
    IF (CheckIO(F) <> done) THEN RETURN; END;

    PrepareForIO(F);

    IgnoreN := 0;

    IF (Length > HIGH(Record)+1) THEN
    	IgnoreN := Length-HIGH(Record)-1;
        Length := HIGH(Record)+1;
    END;

    p := ADR(Record);

    ReadNBytes(F,p,Length,i);
    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN;
    END;
    IF (i < Length) THEN
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





PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    b : ARRAY [0..0] OF CHAR;
BEGIN
    ReadRecordBody(F,Length,b);
END SkipRecordBody;







    (* StartFileInput -- Check the file for valid format *)

PROCEDURE StartFileInput      (VAR F               : File;
                               VAR MaxTaskNumber   : CARDINAL ):BOOLEAN;
CONST
    WhatVersionWeAre  = 1C;
VAR
    Type              : CARDINAL;
    ID                : CARDINAL;
    Length            : CARDINAL;
    FileHeaderRecord  : AFileHeaderRecord;
BEGIN
    PrepareForIO(F);                                               (* 11/12/86 LAA *)
    Reset(F);                   (* 2/8/89 EGK *)
    SetRead(F);
    ReadRecordPreface(F,Type,ID,Length);
    IF (Type <> 3) THEN
        Complain(ModuleNumber+8);
        RETURN FALSE;
    ELSIF (Length <> SIZE(FileHeaderRecord)) THEN
        Complain(ModuleNumber+9);
        RETURN FALSE;
    END;

    ReadRecordBody(F,Length,FileHeaderRecord);
    IF (CheckIO(F) <> done) THEN
        RETURN FALSE;
    END;

    WITH FileHeaderRecord DO
        IF (CanRead > WhatVersionWeAre) THEN
            Complain(ModuleNumber+10);
            RETURN FALSE;
        ELSIF (Checksum <> 0ABABH) THEN
            Complain(ModuleNumber+11);
            RETURN FALSE;
        END;
        MaxTaskNumber := MaximumTaskID;
    END;


    RETURN TRUE;
END StartFileInput;



END OTFiles.

