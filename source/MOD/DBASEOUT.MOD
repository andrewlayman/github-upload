IMPLEMENTATION MODULE dBaseOut;


     (**************************************************************)
     (*                                                            *)
     (*                                                            *)
     (*                                                            *)
     (*             Common routines for writing out in             *)
     (*                    dBase format.                           *)
     (*                                                            *)
     (*                                                            *)
     (*                                                            *)
     (**************************************************************)

(*  =========================================================================
    Last Edit : November 12, 1990 3:45PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Export to DBase format from intermediate file.

    MODIFICATION HISTORY:

        21-Mar-88 RSC   SPIKE upgrade.
        20-Sep-88 EGK   Update for dBase III Plus.  End-of-file mark is
                        now a single "1A".  Total record length is now
                        one more than the sum of the column widths.
        21-Mar-89 RSC   Changed FLOAT(SMUPH) to FSMUPH.
        21-Jun-89 LAA   Increased the upper limit of the Columns array within
                        the FileDescriptor array so it wouldn't bomb out when
                        exporting all task info.
        26-Jun-89 KKC   Import RealToLStrings from Num2Str.
        27-Jun-89 KKC   Import RealToLStrings from RealFormat.
         4-Sep-89 MWP   Allow field len of six for integer and cardinal types.
         6-Sep-89 MWP   Added procedure to write out a null record for all
                        data types.
       22-Sep-89  MWP   Corrected output of  milestone end dates.
       25-Sep-89  MWP   Use the SaganConstant for testing the upper boundaries
                        of real numbers.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        27-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
         7-Nov-90 PFG   Made adjustments so we always export calendar year,
                        not fiscal year.
    =========================================================================
*)


FROM AsOf            IMPORT AsOfDate;

FROM BigTimeU        IMPORT ABigTime, BigTimeToTime;

FROM Dialog          IMPORT Message, Error, FatalError;

FROM Directory       IMPORT ExpandPath;

FROM FileSystem      IMPORT File, Response, ArchiveAttribute,
                            Lookup, WriteWord, Delete, SetAttribute,
                            WriteByte, Close, GetPos, SetPos;

FROM FileAux         IMPORT DisplayFileError;

FROM IntFileIO       IMPORT
    (* TYPE *)              ADataType;

FROM Kbio            IMPORT BreakRequested;

FROM LStrings        IMPORT SetString, Insert, ConcatS, ConcatLS,
                            SubStr, LStringToTString, Fill, SetLengthOf,
                            TStringToLString, TrimFront, RJust,
                            Copy, LJust, TrimRear, CtoS, Procustes;

FROM MagicNum               IMPORT
                                SaganConstant;

FROM MsgFile         IMPORT GetMessage;

FROM RealFormat      IMPORT DefaultCurrencyFormat, RealToLStrings;

FROM Schedule        IMPORT ProjectMedia, ProjectName;

FROM SYSTEM          IMPORT TSIZE, ADDRESS;

FROM TimeFormat      IMPORT DefaultDateAndTimeFormat, DefaultDateFormat,
                            DefaultTimeFormat;

FROM TimeFormat      IMPORT
    (* VAR  *)          EndDateStyle,
    (* PROC *)          AbsTimeAsEndDateStyle;

FROM Timei           IMPORT
    (* TYPE *)          ADuration, ADate, ATimeInfo,
    (* PROC *)          AbsTimeUtoT, TtoTimeU, DurationToReal, 
                        KDay, AbsKDate;


FROM Timeu           IMPORT
    (* VAR *)           TimeTable, FSMUPH;



TYPE
    AColumn         = RECORD
        Name    : ARRAY [0..10] OF CHAR;  (* Ten bytes is dBase's max *)
        Type    : AColumnType;
        Length,
        Decimal : CARDINAL;
    END;

    AFileDescriptor = RECORD
        NumberOfFields,
        WhichOne        : CARDINAL;
        FileNumber      : CARDINAL;
        NumberOfRecords : CARDINAL;
        Columns         : ARRAY [1..200] OF AColumn;
        FileDescription : ARRAY [0..79] OF CHAR;
    END;


VAR
    f                       : File;         (* The worksheet file *)
    DataFileName            : ARRAY [0..99] OF CHAR;
    TFileName               : ARRAY [0..99] OF CHAR;    (* TString *)
    SMUPerDay               : REAL;
    FileDescriptor          : AFileDescriptor;
    TypeList                : ARRAY AColumnType OF CHAR;


CONST
    MAXCARDINAL             = 65535;
    cEOFMarker              = 032C;
    MaxStringLength         = 255;

    ModuleNumber            = 24300;


PROCEDURE CheckIO():BOOLEAN;
VAR
    s : ARRAY [0..99] OF CHAR;
BEGIN
    IF (f.res = done) THEN
        RETURN TRUE;
    ELSE
        GetMessage (ModuleNumber+2, s);     (* "dBase file " *)
        ConcatLS( s, DataFileName );
        DisplayFileError( f, s );
        RETURN FALSE;
    END;
END CheckIO;




PROCEDURE WriteBooleanRecord(X:BOOLEAN);
BEGIN
    IF (X) THEN
        WriteByte(f,"T");
    ELSE
        WriteByte(f,"F");
    END;
END WriteBooleanRecord;



PROCEDURE WriteTextRecord(VAR s:ARRAY OF CHAR; Length: CARDINAL);

VAR
    i     : CARDINAL;
    Limit : CARDINAL;
BEGIN
    Limit := ORD(s[0]);
    IF Limit > Length THEN
        Limit := Length;
    END;
    FOR i := 1 TO Limit DO
        WriteByte(f,s[i]);
    END;
    FOR i := (Limit + 1) TO Length DO   (* must pad the remainder of the *)
        WriteByte(f," ");               (* field length with blanks      *)
    END;
END WriteTextRecord;





PROCEDURE WriteNumericRecord(Value:CARDINAL; Length: CARDINAL; Filler:CHAR);

VAR     s2      : ARRAY [0..19] OF CHAR;
        i, j    : CARDINAL;

BEGIN
    CtoS(Value, s2);
    IF ORD(s2[0]) > Length THEN
        s2[0] := CHR(Length);
    END;
    i := Length - ORD(s2[0]);
    WHILE (i > 0) DO
        WriteByte(f, Filler);
        DEC(i);
    END;
    FOR i := 1 TO ORD(s2[0]) DO
        WriteByte(f, s2[i]);
    END;
END WriteNumericRecord;





PROCEDURE WriteRealRecord(     Value  : REAL;
                               Length : CARDINAL;
                               Digits : CARDINAL);
CONST
    Filler = " ";
VAR
    S,
    Leading,
    Trailing : ARRAY [0..81] OF CHAR;
    i        : CARDINAL;
    Neg      : BOOLEAN;
BEGIN
    Neg := FALSE;

    IF (Value < 0.0) THEN
        Neg   := TRUE;
        Value := -Value;
    END;

    IF ( Value > SaganConstant ) THEN                             (* 25-Sep-89 MWP *)
        Value := 0.0
    END;

    RealToLStrings( Value, Digits, Digits, Leading, Trailing );
    IF (Length < (ORD(Leading[0])+ORD(Neg))) THEN
       Fill(S,"*",Length);
    ELSE
        IF Neg THEN
            SetString( S, "-" );
            ConcatLS(  S, Leading );
        ELSE
            Copy( Leading, S );
        END;
        ConcatS(  S, "." );
        ConcatLS( S, Trailing );
        Procustes(S, Length);
        RJust(S);
    END;
        (* Write the number. *)
    FOR i := 1 TO ORD(S[0]) DO
        WriteByte(f, S[i]);
    END;
END WriteRealRecord;










PROCEDURE WriteDurationRecord(Time:ADuration);
BEGIN
    WriteRealRecord(DurationToReal(Time) / SMUPerDay, 8, 3);
END WriteDurationRecord;





PROCEDURE WriteBigTimeRecord    ( Time  : ABigTime);
VAR
    Year, Month, Day, Hour, Minute, Second  : CARDINAL;
    CalDays     :   CARDINAL;

BEGIN
    BigTimeToTime (Time, Year, Month, Day, Hour, Minute, Second);

    CalDays := KDay(Year, Month, Day);
    AbsKDate(CalDays, Year, Month, Day);    (* 7-Nov-90 PFG calendar yr *)

    WriteNumericRecord(Year,4,"0");
    WriteNumericRecord(Month+1,2,"0");
    WriteNumericRecord(Day,2,"0");
END WriteBigTimeRecord;






PROCEDURE WriteDateRecord(Date:ADate);
VAR
    TimeInfo    :   ATimeInfo;
BEGIN
    AbsTimeUtoT( Date, TimeInfo );          (* 7-Nov-90 PFG calendar yr *)
    WriteNumericRecord(TimeInfo.tiYear,4,"0");
    WriteNumericRecord(TimeInfo.tiMonth+1,2,"0");
    WriteNumericRecord(TimeInfo.tiDay,2,"0");
END WriteDateRecord;






PROCEDURE WriteEndDateRecord(Date:ADate);
VAR
    TimeInfo    :   ATimeInfo;

BEGIN
    AbsTimeAsEndDateStyle( Date, EndDateStyle, TimeInfo );

    WriteNumericRecord(TimeInfo.tiYear,4,"0");
    WriteNumericRecord(TimeInfo.tiMonth+1,2,"0");
    WriteNumericRecord(TimeInfo.tiDay,2,"0");
END WriteEndDateRecord;







PROCEDURE CreateDataFile ( VAR Name   : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    LStringToTString(Name,TFileName);
        (*  Delete the file before creation to be sure the file length is what
            we write into it this time.  *)
    Delete(TFileName, f);
    Lookup(f,TFileName,TRUE);
    RETURN CheckIO();
END CreateDataFile;






        (*-------------------------------------------------------------------*)
        (*                                                                   *)
        (*                        WriteFieldIdent                            *)
        (*                                                                   *)
        (*      This procedure writes to a dBASE file header the information *)
        (*      for one field of the data base.  The last such field must    *)
        (*      be followed by a carriage return character.                  *)
        (*                                                                   *)
        (*-------------------------------------------------------------------*)

PROCEDURE WriteFieldIdent(Name: ARRAY OF CHAR; Length: CARDINAL; Type: CHAR;
                          Decimal : CARDINAL);

VAR             i: CARDINAL;

BEGIN
        (* Field name in ASCII, zero-filled *)
    i := 1;
    WHILE (i <= ORD(Name[0])) AND (i <= 10) DO
        WriteByte(f, CAP(Name[i]));
        INC(i);
    END;
    WHILE i <= 11 DO
        WriteByte(f, 0C);
        INC(i);
    END;
        (*  Field type in ASCII  *)
    WriteByte(f, Type);
        (*  Field data address--32 bits. (filler, is set in memory.) *)
    WriteWord(f,0);
    WriteWord(f,0);
        (*  Field length        *)
    WriteByte(f, CHR(Length));
        (*  Field decimal count in binary. *)
    WriteByte(f, CHR(Decimal));
        (*  Reserved bytes. *)
    FOR i := 1 TO 14 DO
        WriteByte(f, 0C);                       (* Reserved bytes *)
    END;

END WriteFieldIdent;








PROCEDURE WriteFileHeader(    NumberOfFields,
                              RecordLength,
                              NumberOfRecords   : CARDINAL);
VAR
    i,
    HeaderLength    : CARDINAL;
    TimeInfo        :   ATimeInfo;
CONST
    FieldDescriptorLength = 32;
BEGIN
    WriteByte(f, 03C);             (* Version no. *)
    AbsTimeUtoT(AsOfDate, TimeInfo);  (* Date        *)
    WriteByte(f, CHR(TimeInfo.tiYear MOD 100));
    WriteByte(f, CHR(TimeInfo.tiMonth+1));
    WriteByte(f, CHR(TimeInfo.tiDay));
    WriteWord(f, NumberOfRecords);                   (* Records in file *)
    WriteWord(f, 0);                                 (* Records in file *)
    HeaderLength  := 32 + (NumberOfFields * FieldDescriptorLength) + 1;
    WriteWord(f, HeaderLength );                     (* Header Length   *)
    WriteWord(f, RecordLength );                     (* Record Length   *)

    FOR i := 1 TO 20 DO                              (* Reserved bytes (v 1.00) *)
        WriteByte(f, 0C);
    END;
END WriteFileHeader;



PROCEDURE RewriteNumberOfRecords(    NumberOfRecords : CARDINAL );
VAR
    High, Low : CARDINAL;
BEGIN
    GetPos(f,High,Low);
        (* Fix the record count. *)

    SetPos(f,0,4);
    WriteWord(f, NumberOfRecords);                   (* Records in file *)

    SetPos(f,High,Low);

END RewriteNumberOfRecords;




PROCEDURE WriteFileEnder(VAR Description:ARRAY OF CHAR);
BEGIN
    WriteByte(f, 32C);
    (*  WriteWord(f, 01A1AH);   *)          (* 9/20/88 EGK *)
    Close(f);
    SetAttribute (TFileName, ArchiveAttribute, f);
END WriteFileEnder;




 (* HIGH LEVEL ROUTINES.   RSC  3/22/88

 *)


  (* Define File

                Call this before defining any fields (columns).  Pass the
                file number you want appended to the project name, and
                the description to display when the file is done.
  *)
PROCEDURE DefineFile( C : CARDINAL; Description : ARRAY OF CHAR );
BEGIN
    WITH FileDescriptor DO
        FileNumber     := 0;
        NumberOfFields := 0;
        WhichOne       := 0;
        Copy (Description, FileDescription);
    END;
    Copy (Description, DataFileName);
END DefineFile;


  (* Define Column

                Define one column, or field, in this file.

                ColName   is a 1-10 char name to be given to dBase as the
                    column name.
                Size      is the column width, including any fractions, minus
                    signs, decimal points, etc. (the EXTERNAL representation).
                Digits    is for the number of digits for REALs.
                FieldType identifies the type of column we are dealing with.
  *)
PROCEDURE DefineColumn( ColName   : ARRAY OF CHAR;
                        Size      : CARDINAL;
                        Digits    : CARDINAL;
                        FieldType : AColumnType  );
BEGIN
    WITH FileDescriptor DO
        INC(NumberOfFields);
        IF (NumberOfFields > HIGH(Columns)) THEN FatalError; END;
        WITH Columns[ NumberOfFields ] DO
            Copy (ColName, Name);
            Type    := FieldType;
            Length  := Size;
            Decimal := Digits;
        END;
    END;
END DefineColumn;

  (* Define Default
                Define a column using defaults.  Doesn't work for Alpha
                columns or non-currency Reals.
   *)
PROCEDURE DefineDefault( ColName   : ARRAY OF CHAR;
                         FieldType : AColumnType  );
VAR
    Size,
    Digits : CARDINAL;
BEGIN
    Size   := 0;
    Digits := 0;
    CASE FieldType OF
     | Cardinal  : Size := 6;                                     (* 4-Sep-89 MWP *)
     | Numeric   : Size := 12;
     | StartDate : Size := 8;
     | EndDate   : Size := 8;
     | Duration  : Size := 8;  Digits := 3;
     | Currency  : Size := 12; Digits := DefaultCurrencyFormat.MaxTrailingDigits;
     | Boolean   : Size := 1;
    ELSE
        FatalError; (* Not allowed here *)
    END;
    DefineColumn( ColName, Size, Digits, FieldType );

END DefineDefault;



  (* Start File
                Create the file and write its header records.
  *)
PROCEDURE StartFile() : BOOLEAN;
CONST
    AsciiZero = 48;
VAR
    i,
    RecordLength      : CARDINAL;
BEGIN
    IF BreakRequested() THEN RETURN FALSE; END; (* Get out fast *)

    (*    RecordLength      := 0;   *)

    RecordLength      := 1;                 (* 9/20/88 EGK *)

    WITH FileDescriptor DO
        NumberOfRecords   := 0;
        WhichOne          := 0;
        IF (NOT CreateDataFile( FileDescription )) THEN RETURN FALSE; END;
        FOR i := 1 TO NumberOfFields DO
            INC( RecordLength, Columns[ i ].Length );
        END;
        WriteFileHeader( NumberOfFields, RecordLength, NumberOfRecords );
    END;
    IF (NOT CheckIO()) THEN RETURN FALSE; END;

    WITH FileDescriptor DO
        FOR i := 1 TO NumberOfFields DO
            WITH Columns[i] DO
                WriteFieldIdent( Name, Length, TypeList[ Type ], Decimal );
            END;
        END;
    END;
    WriteByte(f, 015C);   (* Header terminator *)

    RETURN CheckIO();

END StartFile;


  (* End File
                When all done with a file, call this to finish up the
                trailer of the file.
  *)
PROCEDURE EndFile();
BEGIN
    WITH FileDescriptor DO
        RewriteNumberOfRecords( NumberOfRecords );
        WriteFileEnder( FileDescription );
    END;
END EndFile;




PROCEDURE WriteField( VAR Data : ARRAY OF CHAR );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
        WITH Columns[ WhichOne ] DO
            IF (Type <> Alpha) THEN FatalError; END;
            WriteTextRecord( Data, Length );
        END;
    END;
END WriteField;


PROCEDURE WriteNullField ();                                      (* 6-Sep-89 MWP *)
VAR
    s               : ARRAY [0..1] OF CHAR;
BEGIN

    SetLengthOf (s,0);

    WITH FileDescriptor DO
        INC(WhichOne);

        IF (WhichOne > NumberOfFields) THEN
           FatalError ();
        END;

        WITH Columns[ WhichOne ] DO
            WriteTextRecord( s, Length );
        END;
    END;

END WriteNullField;



PROCEDURE WriteBigTime ( Data : ABigTime    );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
        WITH Columns[ WhichOne ] DO
            CASE Type OF
                StartDate, EndDate :
                    WriteBigTimeRecord (Data);
            ELSE
                FatalError;  (* Field types out of order? *)
            END;
        END;
    END;
END WriteBigTime;



PROCEDURE WriteCardinal( Data : CARDINAL );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
        WITH Columns[ WhichOne ] DO
            CASE Type OF
                Cardinal  : WriteNumericRecord( Data, Length, " " );
              | Numeric   : WriteNumericRecord( Data, Length, "0" );
              | StartDate : WriteDateRecord( ADate(Data) );
              | EndDate   : WriteEndDateRecord( ADate(Data) );
              | Duration  : WriteDurationRecord( ADuration(Data) );
            ELSE
                FatalError;  (* Field types out of order? *)
            END;
        END;
    END;
END WriteCardinal;


PROCEDURE WriteOutDateRecord ( Data : ADate;
                               InType : AColumnType );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
            CASE InType OF
                StartDate : WriteDateRecord( ADate(Data) );
              | EndDate   : WriteEndDateRecord( ADate(Data) );
            ELSE
                FatalError;  (* Field types out of order? *)
            END;
    END;
END WriteOutDateRecord;


PROCEDURE WriteReal( Data : REAL );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
        WITH Columns[ WhichOne ] DO
            CASE Type OF
                Currency : WriteRealRecord( Data, Length, DefaultCurrencyFormat.MaxTrailingDigits );
              | Real     : WriteRealRecord( Data, Length, Decimal );
            ELSE
                FatalError;  (* Field types out of order? *)
            END;
        END;
    END;
END WriteReal;



PROCEDURE WriteBoolean( Data : BOOLEAN );
BEGIN
    WITH FileDescriptor DO
        INC(WhichOne);
        IF (WhichOne > NumberOfFields) THEN FatalError; END;
        WITH Columns[ WhichOne ] DO
            IF (Type <> Boolean) THEN FatalError; END;
            WriteBooleanRecord( Data );
        END;
    END;
END WriteBoolean;




PROCEDURE StartRecord() : BOOLEAN;
BEGIN
    WriteByte(f, 40C);                  (* Valid record indicator        *)
    WITH FileDescriptor DO
        INC(NumberOfRecords);
        WhichOne := 0;
    END;

    RETURN CheckIO();

END StartRecord;




BEGIN
    TypeList[ Alpha     ] := "C";
    TypeList[ Boolean   ] := "L";
    TypeList[ Cardinal  ] := "N";
    TypeList[ Numeric   ] := "N";
    TypeList[ Duration  ] := "N";
    TypeList[ Currency  ] := "N";
    TypeList[ Real      ] := "N";
    TypeList[ StartDate ] := "D";
    TypeList[ EndDate   ] := "D";
    SMUPerDay := FLOAT(TimeTable.StdDayTics);  (* 1-Nov-90 RSC *)

END dBaseOut.
