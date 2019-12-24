IMPLEMENTATION MODULE CSVExport;

(*  =========================================================================
    Last Edit : November 12, 1990 3:14PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Export to CSV format from intermediate file.

    MODIFICATION HISTORY:

        05-Oct-88 WKH   Changes to all write modules to add a test to
                        see if there was an error on some previous write
                        and bug-out if there was one.  This is primarily
                        for errors like too many files open, disk drive
                        door not closed, and disk too full.
        03-Nov-88 WKH   Improvement to the 10/5/88 fix
         2-Mar-89 AJL   If the DefaultAmountFormat radix character is a
                        comma, use a semicolon as the field separator.
        03-May-89 MWP   Included ability to read the field seperator from
                        the phrases file.
        05-Jul-89 MWP   Changed WriteReal to more accurately output Real
                        number information.
        05-Jul-89 MWP   Some Module Maintenance. ( Formatting etc. )
         5-Sep-89 MWP   Allow writing out of true null fields. ( ',,' )
         6-Sep-89 MWP   Before advancing to a newline to write out a field,
                        check if the previous record written was a null field.
                        If so, ensure we write out a terminating field
                        delimiter.
        10-Sep-89 MWP   Better error handling on real number conversions.
        12-Sep-89 MWP   When checking whether a field will fit according to
                        the line len selected by the user, take unlimited
                        line length into account.
        14-Sep-89 MWP   If a single character field exceeds the line len,
                        place an error message the first time encountered
                        and truncate ruthlessly.
        25-Sep-89 MWP   Use the SaganConstant for testing the upper boundaries
                        of real numbers.
         7-Oct-89 MWP   Make sure we check for text truncation for all line
                        lengths other than unlimited.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        27-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
         7-Nov-90 PFG   Made adjustments so we always export calendar year,
                        not fiscal year.
        17-Sep-91 AJL   Add WriteBoolean.
    =========================================================================
*)


FROM BigTimeU       IMPORT
    (* TYPE *)              ABigTime,
    (* PROC *)              BigTimeToTime;

FROM Dialog         IMPORT
                            Error;

FROM FileSystem     IMPORT
    (* CONST *)             ArchiveAttribute,
    (* TYPE *)              File, Response,
    (* PROC *)              Lookup, WriteByte, Close, Delete,
                            SetAttribute;

FROM FileAux        IMPORT
    (* PROC *)              DisplayFileError, PrepareForIO, CheckIO;

FROM IntFileIO      IMPORT
    (* TYPE *)              ADataType;


FROM LStrings       IMPORT
    (* PROC *)              Fill, LJust, TrimRear, SetString, Search,
                            LStringToTString, CtoS, SetLengthOf, TrimFront,
                            LengthOf, ConcatLS, Copy, ConcatS;

FROM MagicNum               IMPORT
                                SaganConstant;

FROM MsgFile        IMPORT
    (* PROCS *)             GetMessage;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat,
    (* VAR *)               DefaultAmountFormat,
    (* PROC *)              FormatAsAmount,
                            RealToLStrings;

FROM SegWords               IMPORT
                                WordNumber;

FROM TimeFormat      IMPORT
    (* TYPE *)              AnEndDateStyle,
    (* VAR  *)              EndDateStyle,
    (* PROC *)              AbsTimeAsEndDateStyle;

FROM Timei           IMPORT
    (* TYPE *)              ADuration, ADate, ATimeInfo,
    (* PROC *)              AbsTimeUtoT, AbsKDate, KDay, 
                            DurationToReal;

FROM Timeu          IMPORT
    (* VAR *)               TimeTable, SMUPH;





CONST
    cCarriageReturn = 15C;
    cLineFeed       = 12C;
    HeaderLength    = 3;        (* Leading spaces on second lines *)
    ModuleNumber    = 24400;

VAR
    f               : File;
    LineLength      : CARDINAL;
    MaxLineLength   : CARDINAL;
    MaxCharacters   : CARDINAL;
    TName           : ARRAY [0..99] OF CHAR;    (* TString *)
    Warned          : BOOLEAN;                  (* 10/6/88 WKH *)
    FirstTimeTruncating : BOOLEAN;


PROCEDURE CheckFileStatus ()    : BOOLEAN;

VAR
    s               : ARRAY [0..99] OF CHAR;

BEGIN
    IF (CheckIO(f) = done) THEN
        RETURN TRUE;
    ELSE
        IF (NOT Warned) THEN
            SetLengthOf (s,0);
            DisplayFileError (f,s);
            Warned := TRUE;
        END;
        RETURN FALSE;
    END;
END CheckFileStatus;





PROCEDURE OpenFile      ( VAR   Name        : ARRAY OF CHAR;
                                LineLength  : CARDINAL      ) : BOOLEAN;
BEGIN
    MaxLineLength := LineLength;

    MaxCharacters := (MaxLineLength - HeaderLength) - 3;

    LStringToTString (Name, TName);
    PrepareForIO (f);
    Delete (TName, f);
    PrepareForIO (f);
    Lookup (f, TName, TRUE);
    RETURN CheckFileStatus();

END OpenFile;



PROCEDURE CloseFile();
BEGIN
    IF (CheckFileStatus()) THEN END;
    Close (f);
    SetAttribute (TName, ArchiveAttribute, f);
END CloseFile;



PROCEDURE StartRecord();
BEGIN
    LineLength := 0;
END StartRecord;



PROCEDURE EndRecord();
BEGIN
    IF ( LastFieldNull ) THEN
       WriteByte(f,FieldDelimiter);
       LastFieldNull := FALSE;
    END;

    WriteNewline ();

END EndRecord;




PROCEDURE OutputLString (VAR s : ARRAY OF CHAR);

VAR
    i : CARDINAL;
    C : CHAR;

BEGIN
    IF (CheckFileStatus()) THEN END;
    FOR i := 1 TO ORD(s[0]) DO
        C := s[i];
        IF (C='"') THEN
            C := "'";
        END;
        WriteByte(f,C);
    END;
END OutputLString;



PROCEDURE WriteNewline();

BEGIN
    IF (CheckFileStatus()) THEN
        WriteByte(f, cCarriageReturn);
        WriteByte(f, cLineFeed);
    END;
END WriteNewline;




PROCEDURE CheckLineLength(i : CARDINAL);

VAR
    s               : ARRAY [0..20] OF CHAR;

BEGIN

    IF (LineLength > 0) THEN
        IF (MaxLineLength > 0) AND (LineLength + i >= MaxLineLength) THEN
            IF ( LastFieldNull ) THEN                             (* 6-Sep-89 MWP *)
                WriteByte(f,FieldDelimiter);
            END;

            Advance ();
        ELSE
            IF (CheckFileStatus()) THEN END;
                WriteByte(f,FieldDelimiter);
            INC(LineLength);
        END;
    END;

    INC(LineLength,i);
END CheckLineLength;

PROCEDURE Advance ();
VAR
    s               : ARRAY [0..20] OF CHAR;
BEGIN

    WriteNewline ();
    Fill (s, " ", HeaderLength);
    OutputLString (s);
    LineLength := HeaderLength;

END Advance;


PROCEDURE WriteCardinal(c: CARDINAL);
VAR
    s           : ARRAY [0..30] OF CHAR;
BEGIN
    CtoS(c,s);
    CheckLineLength(ORD(s[0]));
    OutputLString(s);
END WriteCardinal;


PROCEDURE WriteReal(     Value  : REAL;
                         Digits : CARDINAL);
CONST
    Filler = " ";
VAR
    S        : ARRAY[0..255] OF CHAR;
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

    IF ( Value > SaganConstant ) THEN
        Value := 0.0
    END;

    FormatAsAmount ( Value,
                     DefaultAmountFormat,
                     S, 10, 0, Digits, FALSE);

    IF ( S[1] = '*' ) THEN
       SetLengthOf ( S, 0 );
    ELSE
       RealToLStrings( Value, Digits, Digits, Leading, Trailing );
       IF Neg THEN
           SetString( S, "-" );
           ConcatLS(  S, Leading );
       ELSE
           Copy( Leading, S );
       END;
       IF ( LengthOf ( Trailing ) > 0 ) THEN
          ConcatS(  S, "." );
          ConcatLS( S, Trailing );
       END;
    END;

    CheckLineLength ( ORD ( S[0] ) );

    OutputLString ( S );

END WriteReal;



PROCEDURE WriteText ( VAR s    : ARRAY OF CHAR );
VAR
    ErrorMsg  :  ARRAY [0..255] OF CHAR;
BEGIN
    IF (CheckFileStatus()) THEN
        IF ( MaxLineLength > 0 ) THEN
           IF ( LengthOf ( s ) >= MaxCharacters ) THEN
              SetLengthOf ( s, MaxCharacters - 1 );
              IF ( FirstTimeTruncating ) THEN
                 GetMessage ( ModuleNumber + 6, ErrorMsg );
                 Error ( ErrorMsg );
                 FirstTimeTruncating := FALSE;
              END;
           END;
        END;

        CheckLineLength(ORD(s[0])+2);
        WriteByte(f, '"');
        OutputLString(s);
        WriteByte(f, '"');
    END;
END WriteText;





PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber, ReturnValue );
END GetMessageWord;








PROCEDURE WriteBoolean  ( VAR   Value       : BOOLEAN );
VAR
    S : ARRAY [0..31] OF CHAR;
BEGIN
    GetMessageWord(ModuleNumber + 60, ORD(Value)+1, S );
    WriteText(S);
END WriteBoolean;





PROCEDURE WriteEmpty ( NumberOfFields : CARDINAL  );               (* 5-Sep-89 MWP *)
VAR
    i : CARDINAL;
BEGIN

    IF ( NOT CheckEmptyLength ( NumberOfFields ) ) THEN
       Advance ();
    END;

    FOR i := 1 TO NumberOfFields DO
       IF ( CheckFileStatus () ) THEN
           CheckLineLength ( 0 );
       END;
    END;

END WriteEmpty;


PROCEDURE CheckEmptyLength ( i : CARDINAL ) : BOOLEAN;
VAR
    s               : ARRAY [0..20] OF CHAR;
    ok              : BOOLEAN;
BEGIN

    ok := TRUE;
    INC(i);  (* Account for last written fields delimiter. *)

    (* Make sure we are not exporting unlimited *)
    IF ( MaxLineLength > 0 ) THEN
       IF (LineLength > 0) THEN
           IF ( LineLength + i >= MaxLineLength ) THEN
              ok := FALSE;
           END;
       END;
    END;

    RETURN ( ok );

END CheckEmptyLength;





PROCEDURE WriteStartDate    (   Date        : ADate         );

VAR
    TimeInfo        :       ATimeInfo;

BEGIN
    AbsTimeUtoT(Date, TimeInfo);                (* 7-Nov-90 PFG calendar yr *)
    WriteCardinal(TimeInfo.tiYear);
    WriteCardinal(TimeInfo.tiMonth+1);
    WriteCardinal(TimeInfo.tiDay);
    WriteCardinal(TimeInfo.tiHour);
    WriteCardinal(TimeInfo.tiMinute);
END WriteStartDate;




PROCEDURE WriteEndDate    (   Date        : ADate         );

VAR
    TimeInfo    :   ATimeInfo;

BEGIN
    AbsTimeAsEndDateStyle (Date, EndDateStyle, TimeInfo);

    WriteCardinal(TimeInfo.tiYear);
    WriteCardinal(TimeInfo.tiMonth+1);
    WriteCardinal(TimeInfo.tiDay);
    WriteCardinal(TimeInfo.tiHour);
    WriteCardinal(TimeInfo.tiMinute);
END WriteEndDate;





PROCEDURE WriteBigTime      (   Time        : ABigTime      );
VAR
    year, month, day, hour, minute, second    : CARDINAL;
    CalDays     :   CARDINAL;

BEGIN
    BigTimeToTime (Time, year, month, day, hour, minute, second);

    CalDays := KDay(year, month, day);
    AbsKDate(CalDays, year, month, day);        (* 7-Nov-90 PFG calendar yr *)

    WriteCardinal(year);
    WriteCardinal(month+1);
    WriteCardinal(day);
    WriteCardinal(hour);
    WriteCardinal(minute);
END WriteBigTime;




PROCEDURE WriteDuration(Time:ADuration);
VAR
    NumberOfDays, SMUPerDay : REAL;
    x                       : ADuration;
BEGIN
    x := TimeTable.StdDayTics;      (* 1-Nov-90 RSC removed SMUPH *)
    SMUPerDay := DurationToReal( x );
    NumberOfDays := DurationToReal(Time) / SMUPerDay;
    WriteReal(NumberOfDays,7);     (* Lots of fractional digits, if necessary. *)
END WriteDuration;


VAR
    s                       : ARRAY [0..10] OF CHAR;

BEGIN

    GetMessage( ModuleNumber + 5, s ); (* Field Seperator *)
    TrimFront ( s );
    TrimRear( s );
    IF ( LengthOf ( s ) > 0 ) AND
       ( s[1] <> " " ) THEN
       FieldDelimiter := s[1];
    ELSE
       IF (DefaultAmountFormat.RadixSymbol <> ",") THEN
           FieldDelimiter := ",";
       ELSE
           FieldDelimiter := ";";
       END;
    END;

    FirstTimeTruncating := TRUE;
    MaxCharacters   := 76 - HeaderLength;

    Warned := FALSE;  (* 10/6/88 WKH *)
    LastFieldNull := FALSE;
END CSVExport.
