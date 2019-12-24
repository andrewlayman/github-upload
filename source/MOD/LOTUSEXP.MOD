IMPLEMENTATION MODULE LotusExport;

(*  =========================================================================
    Last Edit : November 12, 1990 3:14PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Export to Lotus format from intermediate file.

    MODIFICATION HISTORY:

        05-Oct-88 WKH   Changes to all write modules to add a test to
                        see if there was an error on some previous write
                        and bug-out if there was one.  This is primarily
                        for errors like too many files open, disk drive
                        door not closed, and disk too full.
        03-Nov-88 WKH   Improvement to the 10/5/88 fix
        21-Mar-89 RSC   Use FSMUPH rather than FLOAT(SMUPH).
         8-Jul-89 MWP   Added support for percentage records.
         1-Sep-89 MWP   Added parameter to WriteTextRecord which tells whether
                        we are writing a header record or not.
         2-Sep-89 MWP   Write percentage recrds with zero decimal places.
        12-Sep-89 MWP   Trim trailing spaces from text cell output.
        13-Sep-89 MWP   If we are outputting an end date, call FormatAsEndDate
                        to retrieve values. This will give us correct date
                        values.
        25-Sep-89 MWP   Use the SaganConstant for testing the upper boundaries
                        of real numbers.
         7-Oct-89 MWP   When writing out label records, make sure the length is
                        less than 123 max label size of 240 characters.
        19-Oct-89 MWP   Check number value against Sagan constant for %
                        and currency fields.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        27-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
         7-Nov-90 PFG   Made adjustments so we always export calendar year,
                        not fiscal year.
        17-Sep-91 AJL   Add WriteBooleanRecord.
    =========================================================================
*)



FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  BigTimeToTime;

FROM FileAux                IMPORT
    (* PROC *)                  DisplayFileError, PrepareForIO, CheckIO;

FROM FileSystem             IMPORT
    (* CONST *)                 ArchiveAttribute,
    (* TYPE *)                  File, Response,
    (* PROC *)                  Lookup, WriteWord, WriteByte, WriteNBytes,
                                Close, Delete, SetAttribute;

FROM Foreign                IMPORT
    (* TYPE *)                  ACharacterConversionTable,
    (* PROC *)                  DecodeString, DoDash, ConvertedCharacter;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, LengthOf, LStringToTString,
                                TrimFront, TrimRear;

FROM MagicNum               IMPORT
                                SaganConstant;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM SegWords               IMPORT
                                WordNumber;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM TimeFormat             IMPORT
    (* VAR *)                   EndDateStyle,
    (* PROC *)                  AbsTimeAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADuration, ADurationCounter, ATimeInfo,
    (* PROC *)                  DurationToReal, AbsKDay, KDay, AbsKDate,
                                AbsTimeUtoT;

FROM Timeu                  IMPORT
    (* VAR  *)                  TimeTable, FSMUPH;

CONST
    cBOF            = 0;
    cEOF            = 1;
    cCalcMode       = 2;
    cCalcOrder      = 3;
    cActiveRange    = 6;
    cColWidth       = 8;
    cNamedRange     = 11;
    cBlank          = 12;
    cInteger        = 13;
    cReal           = 14;
    cLabel          = 15;
    cGlobalProtect  = 36;
    cGlobalJustify  = 41;
    cCalcCount      = 47;

    fFixed          = 0H;
    fCurrency       = 20H;
    fPercentage     = 30H;
    fGeneral        = 71H;
    fDate           = 72H;
    fProtect        = 80H;

    LeftJustify     = "'";
    RightJustify    = '"';
    Center          = '^';

    Zero            = 0.0;

    MaxTextLength   = 240;                                        (* 7-Oct-89 MWP *)

    ModuleNumber    = 25700;        (* For character translations *)

VAR
    f               : File;
    fName           : ARRAY [0..99] OF CHAR;    (* TString *)
    SMUPerDay       : REAL;
    CharacterTable  : ACharacterConversionTable;
    Warned          : BOOLEAN;                  (* 10/5/88 WKH *)


PROCEDURE WriteRecordHeader ( Code      : CARDINAL;
                              Length    : CARDINAL  );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteWord (f, Code);
        WriteWord (f, Length);
    END;  (* 10/5/88 WKH *)
END WriteRecordHeader;



PROCEDURE WriteByteRecord   ( Code      : CARDINAL;
                              Value     : CARDINAL  );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (Code, 1);
        WriteByte (f, CHR(Value));
    END;  (* 10/5/88 WKH *)
END WriteByteRecord;



PROCEDURE WriteWordRecord   ( Code      : CARDINAL;
                              Value     : CARDINAL  );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (Code, 2);
        WriteWord (f, Value);
    END;  (* 10/5/88 WKH *)
END WriteWordRecord;





PROCEDURE OpenFile  (   VAR Name        : ARRAY OF CHAR )   : BOOLEAN;

BEGIN
    Warned := FALSE;
    LStringToTString (Name, fName);
    PrepareForIO (f);
    Delete (fName, f);
    PrepareForIO (f);
    Lookup (f, fName, TRUE);
    IF (NOT CheckFileStatus()) THEN
        RETURN FALSE;
    END;

    WriteWordRecord (cBOF, 1028);               (* 1-2-3 format        *)
    WriteByteRecord (cCalcCount, 1);            (* iteration count = 1 *)
    WriteByteRecord (cCalcMode, 255);           (* calc = automatic    *)
    WriteByteRecord (cCalcOrder, 0);            (* mode = natural      *)
    WriteByteRecord (cGlobalProtect, 0);        (* protection ON       *)
    WriteByteRecord (cGlobalJustify, 39);       (* left-justified      *)
    RETURN TRUE;
END OpenFile;


PROCEDURE CloseFile;
BEGIN
    IF (CheckFileStatus()) THEN END;  (* 10/5/88 WKH *)
    WriteRecordHeader (cEOF, 0);
    IF (CheckFileStatus()) THEN END;
    Close (f);
    SetAttribute (fName, ArchiveAttribute, f);
END CloseFile;



PROCEDURE CheckFileStatus ()    : BOOLEAN;

VAR
    s               : ARRAY [0..1] OF CHAR;

BEGIN
    IF (CheckIO(f) = done) THEN
        RETURN TRUE;
    ELSE
        IF (NOT Warned) THEN
            SetLengthOf (s,0);
            DisplayFileError (f,s);
            Warned := TRUE;      (* 10/5/88 WKH *)
        END;
        RETURN FALSE;
    END;
END CheckFileStatus;





PROCEDURE WriteTextRecord       (     Col, Row  : CARDINAL;
                                  VAR s         : ARRAY OF CHAR;
                                      RightJust : BOOLEAN;
                                      Protect   : BOOLEAN;
                                      Heading   : BOOLEAN );
VAR
    i           : CARDINAL;
    Format      : CARDINAL;
    Mode        : CHAR;

BEGIN
    IF (CheckFileStatus()) THEN
        TrimFront ( s );                                          (* 12-Sep-89 MWP *)
        TrimRear ( s );

        IF ( LengthOf ( s ) > MaxTextLength ) THEN                (* 7-Oct-89  MWP *)
           SetLengthOf ( s, MaxTextLength );
        END;

        Format := fFixed;
        IF (Protect) THEN
            Format := fProtect;
        END;

        IF ( Heading ) THEN
           Mode := Center;
        ELSE
           IF (RightJust) THEN
               Mode := RightJustify;
           ELSE
               Mode := LeftJustify;
           END;
        END;

        WriteRecordHeader (cLabel, LengthOf(s)+7);
        WriteByte (f, CHR(Format));
        WriteWord (f, Col);
        WriteWord (f, Row);
        WriteByte (f, Mode);
        FOR i := 1 TO LengthOf(s) DO
            WriteByte (f, ConvertedCharacter (s[i], CharacterTable));
        END;
        WriteByte (f, 0C);
    END;  (* 10/5/88 WKH *)
END WriteTextRecord;





PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber, ReturnValue );
END GetMessageWord;






PROCEDURE WriteBooleanRecord    (     Col, Row  : CARDINAL;
                                  VAR Value     : BOOLEAN;
                                      RightJust : BOOLEAN;
                                      Protect   : BOOLEAN;
                                      Header    : BOOLEAN  );
VAR
    S : ARRAY [0..31] OF CHAR;
BEGIN
    GetMessageWord(ModuleNumber + 60, ORD(Value)+1, S );
    WriteTextRecord(Col,Row,S,RightJust,Protect,Header);
END WriteBooleanRecord;






PROCEDURE WriteIntegerRecord    (     Col, Row  : CARDINAL;
                                      Number    : INTEGER;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format          : CARDINAL;
    WriteIt         : BOOLEAN;

BEGIN
    IF (CheckFileStatus()) THEN
        Format := fFixed;
        IF (Protect) THEN
        INC (Format, fProtect);
        END;
        WriteIt := (WriteZero) OR (Number <> 0);

        IF (WriteIt) THEN
            WriteRecordHeader (cInteger, 7);
        ELSE
            WriteRecordHeader (cBlank, 5);
        END;

        WriteByte (f, CHR(Format));
        WriteWord (f, Col);
        WriteWord (f, Row);

        IF (WriteIt) THEN
            WriteWord (f, Number);
        END;
    END;  (* 10/5/88 WKH *)
END WriteIntegerRecord;




PROCEDURE WriteRealRecord       (     Col, Row  : CARDINAL;
                                      Number    : REAL;
                                      Decimals  : CARDINAL;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        IF (Decimals > 15) THEN
            Decimals := 15;
        END;

        IF ( Number > SaganConstant ) THEN                        (* 25-Sep-89 MWP *)
            Number := 0.0
        END;

        Format := fFixed + Decimals;
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        WriteIt := (WriteZero) OR (Number <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (cReal, 13);
        ELSE
            WriteRecordHeader (cBlank, 5);
        END;

        WriteByte (f, CHR(Format));

        IF (CheckFileStatus()) THEN  END;

        IF (WriteIt) THEN
            WriteWord (f, Col);
            WriteWord (f, Row);
            WriteNBytes (f, ADR(Number), 8, Written);
        ELSE
            WriteWord (f, Col);
            WriteWord (f, Row);
        END;

    END;  (* 10/5/88 WKH *)
END WriteRealRecord;




PROCEDURE WriteCurrencyRecord   (     Col, Row  : CARDINAL;
                                      Amount    : REAL;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
        Format := fCurrency + 2;
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        IF ( Amount > SaganConstant ) THEN                        (* 19-Oct-89 MWP *)
            Amount := 0.0
        END;

        WriteIt := (WriteZero) OR (Amount <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (cReal, 13);
        ELSE
            WriteRecordHeader (cBlank, 5);
        END;

        WriteByte (f, CHR(Format));
        IF (WriteIt) THEN
            WriteWord (f, Col);
            WriteWord (f, Row);
            WriteNBytes (f, ADR(Amount), 8, Written);
        ELSE
            WriteWord (f, Col);
            WriteWord (f, Row);
        END;

    END;  (* 10/5/88 WKH *)
END WriteCurrencyRecord;


PROCEDURE WritePercentageRecord   ( Col, Row  : CARDINAL;           (* 8-Jul-89 MWP *)
                                    Amount    : REAL;
                                    WriteZero : BOOLEAN;
                                    Protect   : BOOLEAN       );
VAR
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
        Format := fPercentage;                                    (* 2-Sep-89 MWP *)
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        IF ( Amount > SaganConstant ) THEN                        (* 19-Oct-89 MWP *)
            Amount := 0.0
        END;


        WriteIt := (WriteZero) OR (Amount <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (cReal, 13);
        ELSE
            WriteRecordHeader (cBlank, 5);
        END;

        WriteByte (f, CHR(Format));
        IF (WriteIt) THEN
            WriteWord (f, Col);
            WriteWord (f, Row);
            WriteNBytes (f, ADR(Amount), 8, Written);
        ELSE
            WriteWord (f, Col);
            WriteWord (f, Row);
        END;

    END;
END WritePercentageRecord;



PROCEDURE WriteDateRecord       (     Col, Row  : CARDINAL;
                                      Date      : ADate;
                                      End       : BOOLEAN;
                                      Protect   : BOOLEAN       );
CONST
    LotusOffset = VAL( ADurationCounter, 29280 );  (* Lotus starts counting with 1-jan-00 *)
VAR
    TimeInfo        : ATimeInfo;
    k               : ADurationCounter;
    RealDate        : REAL;
    Format          : CARDINAL;
    Written         : CARDINAL;

BEGIN

    WITH TimeInfo DO
        IF (CheckFileStatus()) THEN
            Format := fDate;
            IF (Protect) THEN
                INC (Format, fProtect);
            END;

            IF (End) THEN
                AbsTimeAsEndDateStyle ( Date, EndDateStyle, TimeInfo ); (* 13-Sep-89 MWP *)
            ELSE
                AbsTimeUtoT(Date,TimeInfo);         (* 7-Nov-90 PFG calendar yr *)
            END;

            k := AbsKDay(tiYear,tiMonth,tiDay);     (* Sequential day number. *)
            RealDate := DurationToReal(k+LotusOffset);
            k := (tiHour * 60) + tiMinute;         (* Fractions of a day. *)
            RealDate := RealDate + (DurationToReal(k) / 1440.0);

            WriteRecordHeader (cReal, 13);
            WriteByte (f, CHR(Format));
            WriteWord (f, Col);
            WriteWord (f, Row);
            WriteNBytes (f, ADR(RealDate), 8, Written);
        END;  (* 10/5/88 WKH *)
    END;
END WriteDateRecord;




PROCEDURE WriteDurationRecord   (     Col, Row  : CARDINAL;
                                      Dur       : ADuration;
                                      Protect   : BOOLEAN       );
VAR
    TimeInDays      : REAL;
    Format          : CARDINAL;
    Written         : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
        Format := fGeneral;
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        TimeInDays := DurationToReal(Dur) / SMUPerDay;
        WriteRecordHeader (cReal, 13);
        WriteByte (f, CHR(Format));
        WriteWord (f, Col);
        WriteWord (f, Row);
        WriteNBytes (f, ADR(TimeInDays), 8, Written);
    END;  (* 10/5/88 WKH *)
END WriteDurationRecord;



PROCEDURE WriteBigTimeRecord    (     Col, Row  : CARDINAL;
                                      Time      : ABigTime;
                                      Protect   : BOOLEAN       );
CONST
    LotusOffset = VAL( ADuration, 29280 );  (* Lotus starts counting with 1-jan-00 *)
VAR
    Year, Month, Day, Hour, Minute, Second  : CARDINAL;
    k               : ADurationCounter;
    RealDate        : REAL;
    Format          : CARDINAL;
    Written         : CARDINAL;
    CalDays         : CARDINAL;

BEGIN

    IF (CheckFileStatus()) THEN
        Format := fDate;
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        BigTimeToTime (Time, Year, Month, Day, Hour, Minute, Second);

        CalDays := KDay(Year, Month, Day);
        AbsKDate(CalDays, Year, Month, Day);    (* 7-Nov-90 PFG calendar yr *)

        k := AbsKDay(Year,Month,Day);         (* Sequential day number. *)
        RealDate := DurationToReal(k+LotusOffset);
        k := VAL( ADurationCounter, (Hour * 60) + Minute );         (* Fractions of a day. *)
        RealDate := RealDate + (DurationToReal(k) / 1440.0);

        WriteRecordHeader (cReal, 13);
        WriteByte (f, CHR(Format));
        WriteWord (f, Col);
        WriteWord (f, Row);
        WriteNBytes (f, ADR(RealDate), 8, Written);
    END;  (* 10/5/88 WKH *)
END WriteBigTimeRecord;





PROCEDURE WriteBlankRecord      (     Col, Row  : CARDINAL;
                                      Protect   : BOOLEAN       );
VAR
    Format          : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
        Format := fGeneral;
        IF (Protect) THEN
            INC (Format, fProtect);
        END;

        WriteRecordHeader (cBlank, 5);
        WriteByte (f, CHR(Format));
        WriteWord (f, Col);
        WriteWord (f, Row);
    END;  (* 10/5/88 WKH *)
END WriteBlankRecord;



PROCEDURE WriteActiveRange      (     FromCol   : CARDINAL;
                                      FromRow   : CARDINAL;
                                      ToCol     : CARDINAL;
                                      ToRow     : CARDINAL      );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (cActiveRange, 8);
        WriteWord (f, FromCol);
        WriteWord (f, FromRow);
        WriteWord (f, ToCol);
        WriteWord (f, ToRow);
    END;  (* 10/5/88 WKH *)
END WriteActiveRange;




PROCEDURE WriteNameRange        ( VAR Name      : ARRAY OF CHAR;
                                      FromCol   : CARDINAL;
                                      FromRow   : CARDINAL;
                                      ToCol     : CARDINAL;
                                      ToRow     : CARDINAL      );
VAR
    i           : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (cNamedRange, 24);
        FOR i := 1 TO 15 DO
            IF (i <= LengthOf(Name)) THEN
                WriteByte (f, Name[i]);
            ELSE
                WriteByte (f, 0C);
            END;
        END;
        WriteByte (f, 0C);
        WriteWord (f, FromCol);
        WriteWord (f, FromRow);
        WriteWord (f, ToCol);
        WriteWord (f, ToRow);
    END;  (* 10/5/88 WKH *)
END WriteNameRange;



PROCEDURE WriteColumnWidth      (     Column    : CARDINAL;
                                      Width     : CARDINAL      );

BEGIN

    IF (CheckFileStatus()) THEN
        WriteRecordHeader (cColWidth, 3);
        WriteWord (f, Column);
        WriteByte (f, CHR(Width));

    END;  (* 10/5/88 WKH *)
END WriteColumnWidth;



PROCEDURE BuildCharacterTable ();
VAR
    i               : CARDINAL;
    From            : ARRAY [0..199] OF CHAR;
    To              : ARRAY [0..127] OF CHAR;
    Pos             : CARDINAL;

BEGIN
    i := 1;
    Pos := 0;

    LOOP
        IF (Pos > 255) THEN
            EXIT;
        END;

        GetMessage (ModuleNumber+i, From);

        IF (LengthOf(From) = 0) THEN
            EXIT;
        END;
        DecodeString (From, To);
        DoDash (To, CharacterTable, Pos);
        INC (i);
    END;
END BuildCharacterTable;




BEGIN
    Warned := FALSE;  (* 10/5/88 WKH *)
    SMUPerDay := FLOAT(TimeTable.StdDayTics);   (* 1-Nov-90 RSC  *)
    BuildCharacterTable();
END LotusExport.
