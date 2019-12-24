IMPLEMENTATION MODULE CSVToInt;

(*  =========================================================================
    Last Edit : November 15, 1990 8:42AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Import from CSV format to an intermediate file.

    MODIFICATION HISTORY:

         09-Mar-89  MWP  In the beginning...
         10-Jul-89  MWP  Handle incorrect row identifiers in a more robust
                         fashion. i.e try and recover.
         27-Jul-89  MWP  Display Messages to inform the user what Import is
                         currently doing. During periods of lengthy processing,
                         this will at least show them that Timeline is alive.
         31-Aug-89  LAA  Added a parameter to ParseAmountToReal.
          1-Sep-89  MWP  Removed unused code and data.
         10-Sep-89  MWP  Incorporate date validation routines.
         19-Sep-89  MWP  Implement break requested processing.
         22-Sep-89  MWP  Changed the return logic checking of StopImport.
         25-Sep-89  MWP  Missed two occurences of StopImport.
          2-Oct-89  MWP  Removed the pre-processing pass which determined
                         the number of records to import. This 'analyze'
                         phase is now included in the actual data import.
          3-Oct-89  MWP  If a date contains invalid values, pass this on
                         to the back end for processing so it can generate
                         a warning message. Otherwise, we will skip over
                         invalid dates and never inform the user!
          9-Oct-89  MWP  Removed text literal.
         14-Nov-89  MWP  Initialize ThermCount so error messages which report
                         a record number do not end up with random numbers.
                         Remove calls to Error, as these conditions are logged
                         to the import journal. Also, update the GetMessage
                         comments, which show the actual message, to correspond
                         to reality.
         19-Apr-90  KKC  Grouped year, month, day, hour, minute into one
                         date structure, ATimeInfo. 
         23-Jul-90  LAA  Because we always export numbers to CSV in US 
                         standard format, the importer must work with that
                         format, too - no matter what format has been set up
                         as standard by one of our international partners.
                         Changed a use of AmountToReal into ParseAmountToReal,
                         and defined a USAmountFormat record so that all
                         parsing is done according to that format.
          7-Nov-90 PFG   Made adjustments so we switch to fiscal year from
                         calendar year when we import dates.
         13-Nov-90 TGS   Merge changes made to 4.03.
         14-Nov-90 RSC   Fix syntax error.
    =========================================================================
*)


FROM ASCII          IMPORT
    (* TYPE *)              EOL;

FROM Dialog         IMPORT
    (* PROC *)              Message, Error;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile;

FROM FileSystem     IMPORT
                            File,     Response, SetPos, GetPos,
                            ReadChar, SetRead;

FROM AllFormalName   IMPORT
                            PurgeCache;

FROM FormalName      IMPORT
    (* PROC *)              IsFormalNameOurs,                     (* 27-Aug-89 MWP *)
                            SetupFormalNameCache;

FROM ImPorTable      IMPORT
    (* VAR  *)              ImportLineNumber,
                            FileType,                             (* 29-Aug-89 MWP *)
    (* PROC *)              LogAnError,              CheckDateValues,
                            CheckFileStatus;

FROM ImportCommon   IMPORT
                            StopImport;

FROM IntFileIO      IMPORT
                            TextType,                RealNumberType,
                            CardinalType,            BooleanType,
                            PredicateRecordType,     EnumeratedType,
                            SkipRecordType,
                            BigStartTimeType,        BigEndTimeType,
                            StartDateType,           EndDateType,
                            IntegerType,
                            APredicateRecord,
                            AnIntDataRecord,
    (* PROC *)              WriteIntData;

FROM LStrings       IMPORT
    (* PROC *)              SetString,
                            ConcatLS,         Copy,
                            Remove,           ConcatS,
                            CtoS,
                            TrimFront,        LengthOf,
                            SetLengthOf,      TrimRear,
                            StoC;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM ParseReal      IMPORT
    (* PROC *)              ParseAmountToReal;

FROM Progress      IMPORT
    (* TYPE *)              AThermometer,
    (* PROCS *)             CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat,
    (* VAR  *)              DefaultAmountFormat;

FROM RecordIO       IMPORT
    (* PROCS *)             WriteRecord;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, ADR;

FROM TimeFormat     IMPORT
                            DtoS;

FROM Timei          IMPORT
    (* TYPE *)              ATimeInfo, ADate,
    (* PROC *)              TtoAbsTimeU, TimeUtoT;

TYPE
    AWhatsBeenSeenItem = (FieldCountSeen,
                          FieldTypeSeen,
                          FieldNameSeen
                         );

    AWhatsBeenSeenSet = SET OF AWhatsBeenSeenItem;

CONST
    ModuleNumber            = 5700; (* Same as TLCSVIMP *)
    NormalFont              = 0C;
    MAXCARDINAL             = 65535;
    Zero                    = 0.0;
    MaxCard                 = 65535.0;
    MaxInt                  = 32767.0;
    MinInt                  = -32768.0;

VAR
    FieldCount              : CARDINAL;
    AbsFieldCount           : CARDINAL;

    FormalColumnType        : ARRAY [0..255] OF CARDINAL;

    Thermometer             : AThermometer;
    ThermCount              : CARDINAL;

    FieldDelimiter          : CHAR;
    TreeBuilt               : BOOLEAN;                            (* 27-Aug-89 MWP *)

    WhatsBeenSeen           : AWhatsBeenSeenSet;
    USAmountFormat          : AnAmountFormat;                  (* 23-Jul-90 *)
    FirstTime               : BOOLEAN;

              (* ------------ Module ------------------- *)

MODULE InputReading;

    IMPORT File, ReadChar, Response, EOL, Remove, ConcatLS;

    EXPORT HistoryString, ReadAChar, Again, AgainFlag, EOLCount;

    VAR
        HistoryString       : ARRAY [0..70] OF CHAR;
        LastCharacterRead   : CHAR;
        AgainFlag           : BOOLEAN;
        EOLCount            : CARDINAL;

        (*  ReadAChar -- Read a character from the file.  Keep a record of
                     characters read. *)

    PROCEDURE ReadAChar(VAR f:File; VAR ch:CHAR);
    VAR
        s1 : ARRAY [0..1] OF CHAR;
    BEGIN
        IF (NOT AgainFlag) THEN
            ReadChar(f,LastCharacterRead);
            IF (f.eof) OR (f.res <> done) THEN RETURN; END;

            IF ( LastCharacterRead = EOL ) THEN
                INC(EOLCount);
            END;

            IF (LastCharacterRead = 15C) OR (LastCharacterRead = 12C) THEN
                LastCharacterRead := EOL;
                INC(EOLCount);
            END;

            IF (ORD(HistoryString[0]) >= HIGH(HistoryString)) THEN
                Remove(HistoryString,1,1);
            END;

            s1[0] := 1C;
            s1[1] := LastCharacterRead;
            ConcatLS(HistoryString,s1);
        END;

        ch := LastCharacterRead;
        AgainFlag := FALSE;
    END ReadAChar;

    PROCEDURE Again(VAR f:File);
    BEGIN
        IF (NOT f.eof) THEN
            AgainFlag := TRUE;
        END;
    END Again;

BEGIN
    AgainFlag := FALSE;
    EOLCount := 0;
END InputReading;

              (* ------------ Module ------------------- *)


PROCEDURE WriteCSVHeaderData ( VAR f             : File ) : BOOLEAN;
VAR
    s               : ARRAY [0..255] OF CHAR;
    s2              : ARRAY [0..7] OF CHAR;
    i, LastRecord   : CARDINAL;
    ok, OutOfOrder  : BOOLEAN;
    TypeHigh,
    TypeLow,
    NameHigh,
    NameLow         : CARDINAL;
BEGIN

    LastRecord := 900;
(***
    ThermCount := 1;
***)
    EOLCount   := 0;

    IF (FirstTime) THEN
        (* Use the standard US number format for all CSV operations *)

        SetupUSFormat( USAmountFormat );                       (* 23-Jul-90 *)
        FirstTime := FALSE;
    END;

    SetRead(f);

    IF NOT(CheckFileStatus(f)) THEN
       RETURN FALSE
    END;


    LOOP
        IF ( NOT FlushARecord ( f, i ) ) THEN
            EXIT;
        END;

        IF ( NOT CheckFileStatus ( f ) ) THEN
           EXIT;
        END;

        IF ( StopImport () ) THEN                               (* 25-Sep-89 MWP *)
           RETURN FALSE;
        END;

        CASE i OF
              105:
                    ok := GetFieldSeperator ( f );
        |     110:
                    IF ( NOT GetFieldsCount ( f ) ) THEN
                       RETURN FALSE;
                    END;
                    INCL ( WhatsBeenSeen, FieldCountSeen );
        |     120:
                    IF ( NOT ( FieldCountSeen IN WhatsBeenSeen ) ) THEN
                       GetMessage ( ModuleNumber + 8, s );
                       (* Number of fields record has not been found. *)
                       LogAnError ( s );
                       RETURN FALSE;
                    END;

                    INCL ( WhatsBeenSeen, FieldNameSeen );


                (*  Save this position so we can seek back to it after we read
                    in the field types. *)

                    GetPos ( f, NameHigh, NameLow );

                (*  Skip over Name record to type record. *)
        |    130:

                    IF ( NOT ( FieldCountSeen IN WhatsBeenSeen ) ) THEN
                       GetMessage ( ModuleNumber + 8, s );
                       (* Number of fields record has not been found. *)
                       LogAnError ( s );
                       RETURN FALSE;
                    END;

                    IF ( NOT ( FieldNameSeen IN WhatsBeenSeen ) ) THEN
                       GetMessage ( ModuleNumber + 9, s );
                       (*  Field name type record has not been found. *)
                       LogAnError ( s );
                       RETURN FALSE;
                    END;

                    TreeBuilt := SetupFormalNameCache ( FileType );

                    GetPos ( f, TypeHigh, TypeLow );

                    ok := GetFieldTypes ( f );

                    SetPos ( f, NameHigh, NameLow );

                    AgainFlag := FALSE;

                    IF ( ok ) THEN
                       ok := WriteFieldNames ( f );
                    END;

                    IF ( TreeBuilt ) THEN                         (* 29-Aug-89 MWP *)
                        PurgeCache ();
                    END;

                    SetPos ( f, TypeHigh, TypeLow );
                    AgainFlag := FALSE;

                    RETURN ( ok );
        |    900:
                    GetMessage ( ModuleNumber + 11, s );
                    (*  Records are either out of order or missing. *)
                    LogAnError ( s );
                    RETURN FALSE;
        ELSE
                GetMessage ( ModuleNumber + 4, s );
                (* "An unknown record identifier has been encountered at line " *)
                CtoS ( EOLCount, s2 );
                ConcatLS ( s, s2 );
                LogAnError ( s );
                RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END WriteCSVHeaderData;



PROCEDURE WriteCSVData ( VAR f    : File;
                         VAR Rows : CARDINAL ) : BOOLEAN;
VAR
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    ok := CheckFileStatus(f);

    IF (FirstTime) THEN
        (* Use the standard US number format for all CSV operations *)

        SetupUSFormat( USAmountFormat );                       (* 23-Jul-90 *)
        FirstTime := FALSE;
    END;

    IF ( ok ) THEN
       ok := WriteData ( f, Rows );
       SetLengthOf ( s, 0 );
       Message ( s );
    END;

    RETURN ok;

END WriteCSVData;

PROCEDURE ValidateRecord ( VAR f : File ) : BOOLEAN;
VAR
    High, j, i,
    Low         : CARDINAL;
    ok,
    OutOfOrder  : BOOLEAN;
    DumpIt      : ARRAY [0..255] OF CHAR;
BEGIN
    GetPos ( f, High, Low );

    FOR j := 1 TO AbsFieldCount DO

        ok := ReadLString( f, DumpIt );

        IF ( NOT ok ) THEN
           RETURN FALSE;
        END;
    END;

    IF ( NOT AdvanceToNextRecord ( f, i, OutOfOrder ) ) THEN
         SetPos ( f, High, Low );
         RETURN TRUE;
    END;

    IF ( OutOfOrder ) THEN
       RETURN FALSE;
    END;

    SetPos ( f, High, Low );

    RETURN TRUE;

END ValidateRecord;



PROCEDURE WriteData ( VAR f        : File;
                      VAR RowsRead : CARDINAL ) : BOOLEAN;
VAR
    i, LastRecord           : CARDINAL;
    ok, OutOfOrder          : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..10] OF CHAR;
BEGIN

    LastRecord := 0;
    ThermCount := 1;
    EOLCount   := 0;

    IF NOT(CheckFileStatus(f)) THEN
       RETURN FALSE
    END;

    (* Make sure we are positioned correctly at the first record. *)
    IF ( NOT FlushARecord ( f, i ) ) THEN
         RETURN FALSE;
    END;

    LOOP

        IF ( NOT CheckFileStatus ( f ) ) THEN
           EXIT;
        END;

        IF ( StopImport () ) THEN                               (* 25-Sep-89 MWP *)
           RETURN FALSE;
        END;

        IF ( NOT ValidateRecord ( f ) ) THEN
            GetMessage ( ModuleNumber + 19, s );
            (* There are either too many or too few data fields within record ~ *)
            CtoS ( ThermCount, s1 );
            ConcatLS ( s, s1 );
            LogAnError ( s );
            RETURN TRUE;
        END;

        ok := FALSE;

        CASE i OF
             900:
                  INC(ImportLineNumber);
                  INC(ThermCount );
                  INC(RowsRead);
                  GetMessage ( ModuleNumber + 20, s );            (* 9-Oct-89 MWP *)
                  (* "Reading record " *)
                  CtoS ( RowsRead, s1 );
                  ConcatLS ( s, s1 );
                  Message ( s );
                  ok := WriteLineData ( f );
        ELSE
            GetMessage ( ModuleNumber + 4, s );
            (* "An unknown line identifier was encountered at line " *)
            CtoS ( EOLCount, s1 );
            ConcatLS ( s, s1 );
            LogAnError ( s );

            INC(ImportLineNumber);                              (* 10-Jul-89 MWP *)
        END;

        IF ( NOT AdvanceToNextRecord ( f, i, OutOfOrder ) ) THEN
            EXIT;
        END;

        IF ( NOT ok ) OR ( OutOfOrder ) THEN
            GetMessage ( ModuleNumber + 19, s );
            (* There are either too many or too few data fields within record ~ *)
            CtoS ( ThermCount, s1 );
            ConcatLS ( s, s1 );
            LogAnError ( s );
            RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END WriteData;



(*
    GetFieldsCount   - Read in the number of fields from a CSV export file.
                       Note - no error checking is done on calculated value.

*)
PROCEDURE GetFieldsCount ( VAR f : File ) : BOOLEAN;
VAR
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..10] OF CHAR;
    i                       : CARDINAL;
    ok, NullFound           : BOOLEAN;
BEGIN
    NullFound := FALSE;

    ok := ReadCardinal (f, i, NullFound );

    IF ( ok ) AND ( NOT NullFound ) THEN
       FieldCount := i;
    ELSE
       GetMessage ( ModuleNumber + 14, s );
       (* An error has been encountered reading the number of fields record ~ *)
       LogAnError ( s );
       ok := FALSE;
    END;

    RETURN ( ok );

END GetFieldsCount;


(*
    GetFieldTypes   - Read in the field types from a CSV export file.
                      Note - No error checking is performed on the
                             retrieved values.

*)
PROCEDURE GetFieldTypes ( VAR f : File ) : BOOLEAN;
VAR
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..10] OF CHAR;
    ok, NullFound           : BOOLEAN;
    i, j                    : CARDINAL;
BEGIN

    NullFound := FALSE;
    AbsFieldCount := 0;

    FOR j := 1 TO FieldCount DO
        ok := ReadCardinal ( f, i, NullFound );

        IF ( ok ) AND ( NOT NullFound ) THEN
            FormalColumnType[ j ] := i;
            IF ( i > 6 ) THEN
               INC(AbsFieldCount, 5 );
            ELSE
               INC(AbsFieldCount);
            END;
        ELSE
            GetMessage ( ModuleNumber + 15, s );
            (* An error has been encountered reading the field data type record ~ *)
            LogAnError ( s );
            RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END GetFieldTypes;


PROCEDURE GetFieldSeperator ( VAR f : File ) : BOOLEAN;
VAR
    i                       : CARDINAL;
    ok, NullFound           : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..10] OF CHAR;
BEGIN

    NullFound := FALSE;

    ok := ReadCardinal ( f, i, NullFound );

    IF ( ok ) AND ( NOT NullFound ) THEN
       FieldDelimiter := CHR(i);
    ELSE
       GetMessage ( ModuleNumber + 13, s );
       (* An error has been encountered reading the field separator record ~ *)
       LogAnError ( s );
       ok := FALSE;
    END;

    RETURN ( ok );

END GetFieldSeperator;




PROCEDURE WriteFieldNames ( VAR f  : File ) : BOOLEAN;
VAR
    i, j              : CARDINAL;
    ok                : BOOLEAN;
    ColumnName        : ARRAY [0..39] OF CHAR;
    s                 : ARRAY [0..255] OF CHAR;
    PredicateRecord   : APredicateRecord;
    DataRecord        : AnIntDataRecord;

BEGIN
    i := 1;

    FOR j := 1 TO FieldCount DO

      (*  Read in the FORMAL column name *)
      ok := ReadLString( f, ColumnName );

      IF ( NOT ok ) THEN
         RETURN FALSE;
      END;

      GetMessage ( ModuleNumber + 17, s );
      (*  Reading column name ~ *)
      ConcatLS  ( s, ColumnName );
      Message ( s );                                               (* 27-Jul-89 MWP *)

      ok := IsFormalNameOurs ( ColumnName,
                               PredicateRecord.DataType,
                               FileType );
      IF ( NOT ok ) THEN
          GetMessage ( ModuleNumber + 18, s );
          (* Field name not recognized : ~ *)
          ConcatLS ( s, ColumnName );
          LogAnError ( s );
          RETURN FALSE;
      ELSE
          FormalColumnType[ i ] := PredicateRecord.DataType;
          INC(i);

          WITH PredicateRecord DO
              Copy( ColumnName, Name );
              ID           := i;
              HeadingDepth := 2; (* Always? *)
              Width        := 10;
          END;

          WriteRecord( InterFile,
                       PredicateRecordType,
                       ADR(PredicateRecord),
                       SIZE(PredicateRecord) );

          WITH DataRecord DO
              Font := 0C; (* Default Font *)

              SetLengthOf ( LString, 0 );
              WriteIntData( TextType, DataRecord );
              WriteIntData( TextType, DataRecord );
          END;
      END;
    END;

    SetLengthOf ( ColumnName , 0 );                                         (* 27-Jul-89 MWP *)
    Message ( ColumnName );

    RETURN TRUE;

END WriteFieldNames;


PROCEDURE DigestColumn ( VAR ColumnValue   : ARRAY OF CHAR;
                         VAR Type          : CARDINAL;
                         VAR TheData       : AnIntDataRecord;
                         VAR AmountFormat  : AnAmountFormat );

VAR
    i                : CARDINAL;
    ok               : BOOLEAN;


    PROCEDURE GetReal ( VAR ColumnValue   : ARRAY OF CHAR;
                        VAR TheData       : AnIntDataRecord;
                        VAR AmountFormat  : AnAmountFormat ) : BOOLEAN;
    VAR
        StoppedAt        : CARDINAL;
        ok               : BOOLEAN;
    BEGIN

        ParseAmountToReal(ColumnValue,AmountFormat,TheData.Real,ok,StoppedAt);

        RETURN ( ok );

    END GetReal;


BEGIN
    TheData.Font       := NormalFont;
    TheData.LString[0] := 0C;

    WITH TheData DO
        CASE Type OF
            TextType,
            BooleanType,
            EnumeratedType,
            BigStartTimeType,
            BigEndTimeType,
            StartDateType,
            EndDateType         :
                    Copy ( ColumnValue, LString );
                    Type := TextType;

          | RealNumberType      :
                    ok := GetReal ( ColumnValue, TheData, AmountFormat );

          | IntegerType         :
                    ok := GetReal ( ColumnValue, TheData, AmountFormat );

                    IF ( ok ) THEN
                        ok := (Real >= -32768.0) AND (Real <= 32767.0);
                        IF (ok) THEN
                            IF (Real >= Zero) THEN
                                Integer := INTEGER(TRUNC(Real));
                            ELSE
                                Integer := 0 - INTEGER(TRUNC(ABS(Real)));
                            END;
                        ELSE
                            IF (Real > Zero) THEN
                                Integer :=  32767; (* MAXINT *)
                            ELSE
                                Integer := -32768; (* MININT *)
                            END;
                            ok := TRUE;
                        END;
                    END;

          | CardinalType        :
                        i             := 1;
                        Cardinal      := StoC( ColumnValue, i );
                        ok            := (i > 1);  (* Ok not to grab
                                                      decimals *)
        ELSE
            Type := MAXCARDINAL;
        END;
    END;

END DigestColumn;


PROCEDURE WriteLineData ( VAR f : File ) : BOOLEAN;
VAR
    ColumnValue : ARRAY [0..99] OF CHAR;
    j           : CARDINAL;
    Type        : CARDINAL;
    ok, NullValue : BOOLEAN;
    DataRecord  : AnIntDataRecord;

BEGIN

    FOR j := 1 TO FieldCount DO

      Type := FormalColumnType[ j ];

      NullValue := FALSE;

      IF ( Type > 6 ) THEN
          ok := ReadDate ( f, ColumnValue, NullValue );
      ELSE
          ok := ReadDataString( f, ColumnValue, NullValue );
      END;

      IF ( ok ) THEN
         IF ( NullValue ) THEN
             Type := MAXCARDINAL;
         ELSE
             DigestColumn ( ColumnValue, Type, DataRecord, USAmountFormat );  (* 23-Jul-90 *)
         END;
      ELSE
         RETURN FALSE;
      END;

      IF (Type = MAXCARDINAL) THEN
          WriteIntData( SkipRecordType, DataRecord );
      ELSE
          WriteIntData( Type, DataRecord );
      END;
    END;

    RETURN TRUE;

END WriteLineData;


PROCEDURE ReadDataString ( VAR f         : File;
                           VAR ls        : ARRAY OF CHAR;
                           VAR NullField : BOOLEAN ) : BOOLEAN;
VAR
    ch              : CHAR;
    i               : CARDINAL;
    ExpectQuote     : BOOLEAN;
    s,
    s1              : ARRAY [0..255] OF CHAR;

BEGIN

    SkipPrefixChars(f);

    ls[0] := 0C;
    i := 0;
    ReadAChar(f,ch);

    IF NOT ( CheckFileStatus(f) ) THEN
       RETURN TRUE;
    END;

    IF ch = '"' THEN
        ExpectQuote := TRUE;
    ELSE
        Again(f);
        ExpectQuote := FALSE;
    END;

        (*  We are ready to read the first char of the string. *)

    LOOP
        ReadAChar(f, ch);
        IF NOT(CheckFileStatus(f)) THEN
            IF (ExpectQuote) THEN
                GetMessage ( ModuleNumber + 7, s );
                (* Missing quotation mark within record ~ *)
                SetLengthOf ( ls, 0 );
                NullField := TRUE;
                CtoS ( ThermCount, s1 );
                ConcatLS ( s, s1 );
                LogAnError ( s );
                RETURN FALSE;
            END;
            EXIT;
        END;

        IF (ch = EOL) THEN
            IF (ExpectQuote) THEN
                GetMessage ( ModuleNumber + 7, s );
                (* Missing quotation mark within record ~ *)
                SetLengthOf ( ls, 0 );
                NullField := TRUE;
                CtoS ( ThermCount, s1 );
                ConcatLS ( s, s1 );
                LogAnError ( s );
                RETURN FALSE;
            END;

            Again(f);
            SkipTerminationChars(f);
            EXIT;

        ELSIF (ExpectQuote AND (ch = '"')) THEN
            SkipTerminationChars(f);
            EXIT;
        ELSIF (NOT ExpectQuote) AND (ch = FieldDelimiter) THEN
            Again(f);
            SkipTerminationChars(f);
            EXIT;
        END;
        IF (i < HIGH(ls)) THEN
            INC(i);
            ls[0] := CHR(i);
            ls[i] := ch;
        END;
    END;

    IF ( NOT ExpectQuote ) AND ( LengthOf ( ls ) = 0 ) THEN
       NullField := TRUE;
    END;

    RETURN TRUE;

END ReadDataString;



PROCEDURE ReadDate ( VAR f          : File;
                     VAR ColumnValue: ARRAY OF CHAR;
                     VAR NullField  : BOOLEAN ) : BOOLEAN;
VAR
    TimeInfo    : ATimeInfo;
    TempDate    : ADate;
    ok, ok1     : BOOLEAN;

BEGIN

    NullField := FALSE;

    SetLengthOf ( ColumnValue, 1 );
    ColumnValue[1] := '*';

    ok := ReadCardinal ( f, TimeInfo.tiYear, NullField );

    ok1 := ReadCardinal ( f, TimeInfo.tiMonth, NullField );

    IF ( NOT ok1 )  THEN
       ok := FALSE;
    ELSE
       IF ( TimeInfo.tiMonth > 0 ) THEN
          DEC(TimeInfo.tiMonth);
       ELSE
          ok := FALSE;
       END;
    END;

    ok1 := ReadCardinal ( f, TimeInfo.tiDay, NullField );
    IF ( NOT ok1 )  THEN
       ok := FALSE;
    END;

    ok1 := ReadCardinal ( f, TimeInfo.tiHour, NullField );
    IF ( NOT ok1 )  THEN
       ok := FALSE;
    END;

    ok1 := ReadCardinal ( f, TimeInfo.tiMinute, NullField );
    IF ( NOT ok1 )  THEN
       ok := FALSE;
    END;

    IF ( ok ) THEN
        IF ( NOT NullField ) THEN

            ok1 := TtoAbsTimeU(TimeInfo, TempDate);
            TimeUtoT(TempDate, TimeInfo);       (* 7-Nov-90 PFG fiscal yr *)
                                    
            IF ( CheckDateValues (  TimeInfo ) ) THEN   (* 10-Sep-89 MWP *)
                DtoS ( TimeInfo, ColumnValue );
            END;
        END;
    END;

    RETURN ( ok );

END ReadDate;


PROCEDURE FlushARecord ( VAR f             : File;
                         VAR Value         : CARDINAL ) : BOOLEAN;
VAR
    ch              : CHAR;
    Null            : BOOLEAN;
BEGIN

    LOOP
       REPEAT
           ReadAChar(f, ch);
           IF NOT(CheckFileStatus(f)) THEN
               RETURN ( FALSE );
           END;
       UNTIL ( ch = "-" );

       Null := FALSE;

       IF ( ReadCardinal ( f, Value, Null ) ) AND
          ( NOT Null )  THEN
          CASE Value OF
              900,
              105,
              110,
              120,
              130  :
                 RETURN TRUE;
           ELSE
           END;
       END;
    END;

END FlushARecord;

PROCEDURE AdvanceToNextRecord ( VAR f             : File;
                                VAR Value         : CARDINAL;
                                VAR FieldsSkipped : BOOLEAN ) : BOOLEAN;
VAR
    ch              : CHAR;
    Null            : BOOLEAN;
    s               : ARRAY [0..10] OF CHAR;
BEGIN

    FieldsSkipped := FALSE;

    LOOP
       REPEAT
           ReadAChar(f, ch);
           IF NOT(CheckFileStatus(f)) THEN
               RETURN ( FALSE );
           END;

           IF (ch <> EOL) AND
              (ch <> " ") AND
              (ch <> "-") THEN
               FieldsSkipped := TRUE;
               SetLengthOf ( s, 1 );
               s[1] := ch;
           END;

       UNTIL ( ch = "-" );

       Null := FALSE;

       IF ( ReadCardinal ( f, Value, Null ) ) AND
          ( NOT Null )  THEN
          CASE Value OF
              900,
              105,
              110,
              120,
              130  :
                 RETURN TRUE;
           ELSE
           END;
       END;
    END;

END AdvanceToNextRecord;


PROCEDURE ReadCardinal( VAR f : File;
                        VAR i : CARDINAL;
                        VAR NullValue : BOOLEAN ) : BOOLEAN;

VAR
    j               : CARDINAL;
    ok              : BOOLEAN;
    int             : ARRAY [0..9] OF CHAR;
    LocalNull       : BOOLEAN;
BEGIN

    LocalNull := FALSE;

    ok := ReadDataString ( f, int, LocalNull );

    IF ( LocalNull ) THEN
       NullValue := TRUE;
       i := MAXCARDINAL;
       RETURN ( TRUE );
    END;

    TrimFront(int);

    TrimRear(int);

    ok := CheckCardOrInt ( int, TRUE );

    IF ( ok ) THEN
       j := 1;

       i := StoC(int, j);

       IF ( j <= ORD( int[0] ) ) THEN
          i := 0;
          ok := FALSE;
       END;
    END;

    RETURN ( ok );

END ReadCardinal;


PROCEDURE ReadLString ( VAR f  : File;
                        VAR ls : ARRAY OF CHAR ) : BOOLEAN;

VAR
    ch              : CHAR;
    i               : CARDINAL;
    ExpectQuote     : BOOLEAN;
    s, s1           : ARRAY [0..255] OF CHAR;

BEGIN
    SkipPrefixChars(f);

    ls[0] := 0C;
    i := 0;
    ReadAChar(f,ch);

    IF NOT ( CheckFileStatus(f) ) THEN
       RETURN TRUE;
    END;

    IF ch = '"' THEN
        ExpectQuote := TRUE;
    ELSE
        Again(f);
        ExpectQuote := FALSE;
    END;

        (*  We are ready to read the first char of the string. *)

    LOOP
        ReadAChar(f, ch);
        IF NOT(CheckFileStatus(f)) THEN
            IF (ExpectQuote) THEN
                GetMessage ( ModuleNumber + 7, s );
                (* Missing quotation mark within record ~ *)
                SetLengthOf ( ls, 0 );
                CtoS ( ThermCount, s1 );
                ConcatLS ( s, s1 );
                LogAnError ( s );
                RETURN FALSE;
            END;
            EXIT;
        END;

        IF (ch = EOL) THEN
            IF (ExpectQuote) THEN
                GetMessage ( ModuleNumber + 7, s );
                (* Missing quotation mark within record ~ *)
                SetLengthOf ( ls, 0 );
                CtoS ( ThermCount, s1 );
                ConcatLS ( s, s1 );
                LogAnError ( s );
                RETURN FALSE;
            END;
            Again(f);
            SkipTerminationChars(f);
            EXIT;
        ELSIF (ExpectQuote AND (ch = '"')) THEN
            SkipTerminationChars(f);
            EXIT;
        ELSIF (NOT ExpectQuote) AND (ch = FieldDelimiter) THEN
            Again(f);
            SkipTerminationChars(f);
            EXIT;
        END;
        IF (i < HIGH(ls)) THEN
            INC(i);
            ls[0] := CHR(i);
            ls[i] := ch;
        END;
    END;

    RETURN TRUE;

END ReadLString;



PROCEDURE SetupUSFormat(VAR USAmountFormat : AnAmountFormat);  

BEGIN                   (* SetupUSFormat *)

    USAmountFormat := DefaultAmountFormat;                     (* 23-Jul-90 *)
    WITH USAmountFormat DO                                 
        RadixSymbol            := ".";
        SymbolForSignificance  := ",";
        DigitsForSignificance  := 9999;
        IncludeAtLeastOneDigit := TRUE;
        OverflowSymbol         := "*";
        SetString(Decorations.LeadingNegativeSymbol,"-");
        SetLengthOf(Decorations.TrailingNegativeSymbol,0);
        SetLengthOf(Decorations.LeadingPositiveSymbol, 0);
        SetLengthOf(Decorations.TrailingPositiveSymbol,0);
    END;

END SetupUSFormat;




PROCEDURE CheckCardOrInt ( VAR s        : ARRAY OF CHAR;
                               TestCard : BOOLEAN ) : BOOLEAN;
VAR
    r               : REAL;
    i               : CARDINAL;
    ok              : BOOLEAN;
BEGIN

    ParseAmountToReal ( s, USAmountFormat, r, ok, i );

    IF ( ok ) THEN
       IF ( TestCard ) THEN
          IF ( r >= MaxCard ) OR
             ( r <  Zero ) THEN
              ok := FALSE;
          END;
       ELSE
          IF ( r >= MaxInt ) OR
             ( r <  MinInt ) THEN
              ok := FALSE;
          END;
       END;
    END;

    RETURN ( ok );

END CheckCardOrInt;


    (*  SkipPrefixChars -- Skip over any characters that are allowed
                           to come before an item. *)

PROCEDURE SkipPrefixChars(VAR f:File);
VAR
    ch    : CHAR;
BEGIN
    LOOP
        ReadAChar(f,ch);
        IF (NOT CheckFileStatus(f)) THEN EXIT; END;
        IF (ch <> " ") AND (ch <> EOL) THEN
            Again(f);
            EXIT;
        END;
    END;
END SkipPrefixChars;


    (*  SkipTerminationChars -- Skip over any characters that are
                                the separators between items.
                                *)

PROCEDURE SkipTerminationChars(VAR f:File);
VAR
    ch    : CHAR;
BEGIN
    LOOP
        ReadAChar(f,ch);
        IF (NOT CheckFileStatus(f)) THEN EXIT; END;
        IF ( ch = FieldDelimiter ) THEN
            EXIT;
        ELSIF (ch <> " ") AND (ch <> EOL) THEN
            Again(f);
            EXIT;
        END;
    END;
END SkipTerminationChars;


BEGIN

    HistoryString[0] := 0C;
    ImportLineNumber := 0;
    ThermCount       := 0;
    EOLCount         := 0;
    WhatsBeenSeen    := AWhatsBeenSeenSet{};

    FieldDelimiter   := ",";
    FirstTime        := TRUE;                                  (* 23-Jul-90 *)
END CSVToInt.

