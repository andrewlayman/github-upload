IMPLEMENTATION MODULE ExcelExport;

(*  =========================================================================
    Last Edit : November 12, 1990 3:13PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Export to Excel format from intermediate file.

    MODIFICATION HISTORY:

        05-Oct-88 WKH   Changes to all write modules to add a test to
                        see if there was an error on some previous write
                        and bug-out if there was one.  This is primarily
                        for errors like too many files open, disk drive
                        door not closed, and disk too full.
        03-Nov-88 WKH   Improvement to the 10/5/88 fix
        21-Mar-89 RSC   Use FSMUPH rather than FLOAT(SMUPH).
         8-Jul-89 MWP   Added support for percentage records.
        30-Jul-89 MWP   Use d/mmm/y format instead of d/m/yy.
         1-Sep-89 MWP   Added parameter to WriteTextRecord which tells whether
                        we are writing a header record or not.
         4-Sep-89 MWP   Write percentage recrds with zero decimal places.
        12-Sep-89 MWP   Trim trailing spaces from text cell output.
        13-Sep-89 MWP   If we are outputting an end date, call FormatAsEndDate
                        to retrieve values. This will give us correct date
                        values.
        14-Sep-89 MWP   Change currency format.
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
        27-Aug-91 TGS   Use a separate translation string for Excel (was
                        using Lotus'). The character sets are similar, but
                        not identical. And, with other Windows codepages,
                        they may not be similar at all (e.g. Cyrillic).
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
                                TrimRear, StoC, TrimFront;

FROM MagicNum               IMPORT
                                SaganConstant;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM SegWords               IMPORT
                                WordNumber;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR  *)                  EndDateStyle,
    (* PROC *)                  AbsTimeAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADuration, ADurationCounter, ATimeInfo,
    (* PROC *)                  DateToReal, DurationToReal, AbsKDay, KDay,
                                AbsKDate, AbsTimeUtoT;

FROM Timeu                  IMPORT
    (* VAR  *)                  FSMUPH, TimeTable;


CONST
    Zero            = 0.0;

    MaxTextLength   = 240;                                        (* 7-Oct-89 MWP *)

    ModuleNumber    =   6000;        (* For character translations *)

    ExcelModuleNumber = 5300;

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
    END;
END WriteRecordHeader;



PROCEDURE WriteByteRecord   ( Code      : CARDINAL;
                              Value     : CARDINAL  );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (Code, 1);
        WriteByte (f, CHR(Value));
    END;
END WriteByteRecord;



PROCEDURE WriteWordRecord   ( Code      : CARDINAL;
                              Value     : CARDINAL  );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (Code, 2);
        WriteWord (f, Value);
    END;
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

    WriteRecordHeader (BBOF, 4);               (* Exxcel format        *)
    WriteWord (f, VERSION);
    WriteWord (f, DOC_TYPE);

    WriteWordRecord (BCALCCOUNT, 1);             (* iteration count = 1 *)
    WriteWordRecord (BCALCMODE, 1);              (* calc = automatic    *)
    WriteWordRecord (BREFMODE, 1);              (* calc = automatic    *)

    WriteFormatRecords ();

    RETURN TRUE;
END OpenFile;


PROCEDURE CloseFile;
BEGIN
    IF (CheckFileStatus()) THEN END;  (* 10/5/88 WKH *)
    WriteRecordHeader (BEOF, 0);
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
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    Mode        : CHAR;

BEGIN
    IF (CheckFileStatus()) THEN
        TrimFront ( s );
        TrimRear ( s );

        IF ( LengthOf ( s ) > MaxTextLength ) THEN                (* 7-Oct-89  MWP *)
           SetLengthOf ( s, MaxTextLength );
        END;

        Format2 := F_FIXED;

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        IF ( Heading ) THEN
           Format3 := 2;
        ELSE
           IF (RightJust) THEN
               Format3 := 3;
           ELSE
               Format3 := 1;
           END;
        END;

        WriteRecordHeader (BLABEL, LengthOf(s)+8);
        WriteWord (f, Row);
        WriteWord (f, Col);

        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));
        WriteByte (f, CHR( LengthOf(s) ) );
        FOR i := 1 TO LengthOf(s) DO
            WriteByte (f, ConvertedCharacter (s[i], CharacterTable));
        END;
    END;

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
    GetMessageWord(ExcelModuleNumber + 60, ORD(Value)+1, S );
    WriteTextRecord(Col,Row,S,RightJust,Protect,Header);
END WriteBooleanRecord;






PROCEDURE WriteIntegerRecord    (     Col, Row  : CARDINAL;
                                      Number    : INTEGER;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    WriteIt     : BOOLEAN;

BEGIN
    IF (CheckFileStatus()) THEN

        Format2 := F_FIXED;

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format3 := 3;

        WriteIt := (WriteZero) OR (Number <> 0);

        IF (WriteIt) THEN
            WriteRecordHeader (BINTEGER, 9);
        ELSE
            WriteRecordHeader (BBLANK, 7);
        END;

        WriteWord (f, Row);
        WriteWord (f, Col);

        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));

        IF (WriteIt) THEN
            WriteWord (f, Number);
        END;

    END;
END WriteIntegerRecord;




PROCEDURE WriteRealRecord       (     Col, Row  : CARDINAL;
                                      Number    : REAL;
                                      Decimals  : CARDINAL;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN
(*
     This could prove difficult. What we have to do is use only Excel internal
     formatting codes, and they only allow up to a maximum of two decimal
     places for fixed formated numbers. We will follow this.
*)
        IF (Decimals > 2) THEN
            Decimals := 2;
        END;

        IF ( Number > SaganConstant ) THEN                        (* 25-Sep-89 MWP *)
            Number := 0.0
        END;

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        CASE Decimals OF
            0    :
              Format2 := F_FIXED;
        |   1    :
              Format2 := F_FIXED1;
        |   2    :
              Format2 := F_FIXED2;
        ELSE
              Format2 := F_FIXED;
        END;

        Format3 := 3;

        WriteIt := (WriteZero) OR (Number <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (BNUMBER, 15);
        ELSE
            WriteRecordHeader (BBLANK, 7);
        END;

        IF (CheckFileStatus()) THEN  END;

        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));

        IF (WriteIt) THEN
            WriteNBytes (f, ADR(Number), 8, Written);
        END;
    END;
END WriteRealRecord;




PROCEDURE WriteCurrencyRecord   (     Col, Row  : CARDINAL;
                                      Amount    : REAL;
                                      WriteZero : BOOLEAN;
                                      Protect   : BOOLEAN       );
VAR
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format2 := F_CURR3;                                       (* 14-Sep-89 MWP *)

        Format3 := 3;

        IF ( Amount > SaganConstant ) THEN                        (* 19-Oct-89 MWP *)
            Amount := 0.0
        END;


        WriteIt := (WriteZero) OR (Amount <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (BNUMBER, 15);
        ELSE
            WriteRecordHeader (BBLANK, 7);
        END;

        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));

        IF (WriteIt) THEN
            WriteNBytes (f, ADR(Amount), 8, Written);
        END;
    END;

END WriteCurrencyRecord;




PROCEDURE WritePercentageRecord   (     Col, Row  : CARDINAL;         (* 8-Jul-89 MWP *)
                                        Amount    : REAL;
                                        WriteZero : BOOLEAN;
                                        Protect   : BOOLEAN       );
VAR
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    Format              : CARDINAL;
    WriteIt             : BOOLEAN;
    Written             : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format2 := F_PERCENT1;                                    (* 4-Sep-89 MWP *)

        Format3 := 3;

        IF ( Amount > SaganConstant ) THEN                        (* 19-Oct-89 MWP *)
            Amount := 0.0
        END;

        WriteIt := (WriteZero) OR (Amount <> Zero);

        IF (WriteIt) THEN
            WriteRecordHeader (BNUMBER, 15);
        ELSE
            WriteRecordHeader (BBLANK, 7);
        END;

        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));

        IF (WriteIt) THEN
            WriteNBytes (f, ADR(Amount), 8, Written);
        END;
    END;

END WritePercentageRecord;



PROCEDURE WriteDateRecord       (     Col, Row  : CARDINAL;
                                      Date      : ADate;
                                      End       : BOOLEAN;
                                      Protect   : BOOLEAN       );
CONST
    LotusOffset = VAL( ADurationCounter, 29280);  (* Lotus starts counting with 1-jan-00 *)
VAR
    TimeInfo        : ATimeInfo;
    k               : ADurationCounter;
    RealDate        : REAL;
    Format          : CARDINAL;
    Format1         : CARDINAL;
    Format2         : CARDINAL;
    Format3         : CARDINAL;
    Written         : CARDINAL;

BEGIN

    WITH TimeInfo DO
        IF (CheckFileStatus()) THEN

            IF (Protect) THEN
                Format1 := 40H;
            ELSE
                Format1 := 0;
            END;

            Format2 := F_DATE_2;                                       (* 30-Jul-89 MWP *)

            Format3 := 3;

            IF (End) THEN
                AbsTimeAsEndDateStyle ( Date, EndDateStyle, TimeInfo ); (* 13-Sep-89 MWP *)
            ELSE
                AbsTimeUtoT(Date,TimeInfo);         (* 7-Nov-90 PFG calendar yr *)
            END;

            k := AbsKDay(tiYear,tiMonth,tiDay);     (* Sequential day number. *)
            RealDate := DurationToReal(k+LotusOffset);
            k := VAL( ADurationCounter, (tiHour * 60) + tiMinute );         (* Fractions of a day. *)
            RealDate := RealDate + (DurationToReal(k) / 1440.0);

            WriteRecordHeader (BNUMBER, 15);
            WriteWord (f, Row);
            WriteWord (f, Col);
            WriteByte (f, CHR(Format1));
            WriteByte (f, CHR(Format2));
            WriteByte (f, CHR(Format3));
            WriteNBytes (f, ADR(RealDate), 8, Written);
        END;
    END;

END WriteDateRecord;




PROCEDURE WriteDurationRecord   (     Col, Row  : CARDINAL;
                                      Dur       : ADuration;
                                      Protect   : BOOLEAN       );
VAR
    TimeInDays      : REAL;
    Format          : CARDINAL;
    Written         : CARDINAL;
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format2 := F_GENERAL;

        Format3 := 3;

        TimeInDays := DurationToReal(Dur) / SMUPerDay;
        WriteRecordHeader (BNUMBER, 15);
        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));
        WriteNBytes (f, ADR(TimeInDays), 8, Written);
    END;
END WriteDurationRecord;



PROCEDURE WriteBigTimeRecord    (     Col, Row  : CARDINAL;
                                      Time      : ABigTime;
                                      Protect   : BOOLEAN       );
CONST
    LotusOffset = VAL( ADurationCounter, 29280);  (* Lotus starts counting with 1-jan-00 *)
VAR
    Year, Month, Day, Hour, Minute, Second  : CARDINAL;
    k               : ADurationCounter;
    RealDate        : REAL;
    Format          : CARDINAL;
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;
    Written     : CARDINAL;
    CalDays     : CARDINAL;

BEGIN

    IF (CheckFileStatus()) THEN

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format2 := F_DATE_TIME;

        Format3 := 3;

        BigTimeToTime (Time, Year, Month, Day, Hour, Minute, Second);

        CalDays := KDay(Year, Month, Day);
        AbsKDate(CalDays, Year, Month, Day);    (* 7-Nov-90 PFG calendar yr *)

        k := AbsKDay(Year,Month,Day);         (* Sequential day number. *)
        RealDate := DateToReal(k+LotusOffset);
        k := VAL( ADurationCounter, (Hour * 60) + Minute );         (* Fractions of a day. *)
        RealDate := RealDate + (DurationToReal(k) / 1440.0);

        WriteRecordHeader (BNUMBER, 15);
        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));
        WriteNBytes (f, ADR(RealDate), 8, Written);
    END;
END WriteBigTimeRecord;





PROCEDURE WriteBlankRecord      (     Col, Row  : CARDINAL;
                                      Protect   : BOOLEAN       );
VAR
    Format          : CARDINAL;
    Format1     : CARDINAL;
    Format2     : CARDINAL;
    Format3     : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        IF (Protect) THEN
            Format1 := 40H;
        ELSE
            Format1 := 0;
        END;

        Format2 := F_GENERAL;

        Format3 := 3;

        WriteRecordHeader (BBLANK, 7);
        WriteWord (f, Row);
        WriteWord (f, Col);
        WriteByte (f, CHR(Format1));
        WriteByte (f, CHR(Format2));
        WriteByte (f, CHR(Format3));
    END;
END WriteBlankRecord;



PROCEDURE WriteActiveRange      (     FromCol   : CARDINAL;
                                      FromRow   : CARDINAL;
                                      ToCol     : CARDINAL;
                                      ToRow     : CARDINAL      );
BEGIN
    IF (CheckFileStatus()) THEN
        WriteRecordHeader (BDIMENSIONS, 8);
        WriteWord (f, FromRow);
        WriteWord (f, ToRow);
        WriteWord (f, FromCol);
        WriteWord (f, ToCol);
    END;
END WriteActiveRange;


PROCEDURE WriteFormatRecords ();
VAR
    NameLen,
    i,j         : CARDINAL;
    FormatCount : CARDINAL;
    s           : ARRAY [0..49] OF CHAR;

BEGIN
    IF (CheckFileStatus()) THEN

        GetMessage(ExcelModuleNumber, s);

        j := 1;
        FormatCount := StoC(s, j);

        WriteWordRecord ( BFORMATCNT, FormatCount );

        FOR j := 1 TO FormatCount DO
           GetMessage( ExcelModuleNumber + j, s );
           TrimRear ( s );

           NameLen := LengthOf ( s );
           WriteRecordHeader (BFORMAT, 1 + NameLen );

           WriteByte ( f, CHR(NameLen) );

           FOR i := 1 TO NameLen DO
               WriteByte (f, s[i]);
           END;
        END;
    END;
END WriteFormatRecords;



PROCEDURE WriteNameRange        ( VAR Name      : ARRAY OF CHAR;
                                      FromCol   : CARDINAL;
                                      FromRow   : CARDINAL;
                                      ToCol     : CARDINAL;
                                      ToRow     : CARDINAL      );
VAR
    NameLen,
    i           : CARDINAL;

BEGIN
    IF (CheckFileStatus()) THEN

        NameLen := LengthOf ( Name );

        WriteRecordHeader (BNAME, 13 + NameLen );
        (* grbit *)
        WriteByte (f, 0C);

        (* grbitPli *)
        WriteByte (f, 0C);

        (* chKey *)
        WriteByte (f, 0C);


        (* cch *)
        WriteByte ( f, CHR(NameLen) );
        (* cce *)
        WriteByte ( f, CHR(7) );

        FOR i := 1 TO NameLen DO
            WriteByte (f, Name[i]);
        END;

        WriteByte (f, CHR(2DH));
        WriteWord (f, FromRow);
        WriteWord (f, ToRow);
        WriteByte (f, CHR(FromCol));
        WriteByte (f, CHR(ToCol));

        (* cceDup *)
        WriteByte ( f, CHR(7) );
    END;

END WriteNameRange;



PROCEDURE WriteColumnWidth      (     Column    : CARDINAL;
                                      Width     : CARDINAL      );
VAR
    dxWidth : CARDINAL;
BEGIN

    IF (CheckFileStatus()) THEN
        WriteRecordHeader (BCOLWIDTH, 4);
        WriteByte (f, CHR(Column));
        WriteByte (f, CHR(Column));
        dxWidth := Width * 256;
        WriteWord ( f, dxWidth );
    END;
END WriteColumnWidth;



PROCEDURE BuildCharacterTable ();
VAR
    i               : CARDINAL;
    From            : ARRAY [0..199] OF CHAR;
    To              : ARRAY [0..127] OF CHAR;
    Pos             : CARDINAL;

BEGIN
    i   := 30;
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
    SMUPerDay := FLOAT(TimeTable.StdDayTics);   (* 1-Nov-90 RSC *)
    BuildCharacterTable();
END ExcelExport.


