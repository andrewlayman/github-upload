IMPLEMENTATION MODULE DBToInt;

(*  =========================================================================
    Last Edit : November 15, 1990 8:51AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Import dBase records.

    MODIFICATION HISTORY:

        09-Mar-89 MWP   In the beginning...
        27-Jul-89 MWP   Display Messages to inform the user what Import is
                        currently doing. During periods of lengthy processing,
                        this will at least show them that Timeline is alive.
        31-Aug-89 LAA   Added a new parameter to ParseAmountToReal.
         1-Sep-89 MWP   Write the ColumnDataType in the predicate record for
                        the back end.
         1-Sep-89 MWP   Remove text literals.
         5-Sep-89 MWP   Clear messages from screen, and correctly use
                        SetLengthOf.
         6-Sep-89 MWP   Better processing of dates and recognizing null data
                        fields.
        11-Sep-89 MWP   When reading a date value, validate the date.
        17-Sep-89 MWP   If a date field is blank, report the error.
        19-Sep-89 MWP   Implement break requested processing.
        22-Sep-89 MWP   Changed the return logic checking of StopImport.
        27-Sep-89 MWP   Don't supply defaults for hours and minutes
                        in dates.
         3-Oct-89 MWP   If a date contains invalid values, pass this on
                        to the back end for processing so it can generate
                        a warning message. Otherwise, we will skip over
                        invalid dates and never inform the user!
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        23-Jul-90 LAA   dBase records are always exported with numbers in
                        US standard format.  Therefore, they must be read
                        back in in that way.  Created a new amount format
                        for this, and used it in GetDBase.
         7-Nov-90 PFG   Made adjustments so we switch to fiscal year from
                        calendar year when we import dates.
        13-Nov-90 TGS   Merge changes made to 4.03.
        06-Sep-91 LAA   Removed several globals which were in the .DEF
                        and move them here, where they should be.
    ========================================================================
*)


FROM ASCII          IMPORT
                            EOL, cr;

FROM BitByteOps     IMPORT
    (* PROC *)              ByteAnd;

FROM Dialog         IMPORT
    (* PROC *)              Message, FatalError;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile;

FROM FileSystem     IMPORT
    (* PROC *)              File, SetPos,
                            ReadChar, ReadByte, SetRead,
                            ReadNBytes;

FROM AllFormalName   IMPORT
                            PurgeCache;

FROM FormalName      IMPORT
    (* PROC *)              IsFormalNameOurs,                     (* 27-Aug-89 MWP *)
                            SetupFormalNameCache;

FROM ImPorTable      IMPORT
                            AnStoreFormalNameProc,
    (* VAR  *)              ImportLineNumber,
                            ErrorsHaveOccured,
                            FileType,                             (* 29-Aug-89 MWP *)
    (* PROC *)              LogAnError,     CheckDateValues,
                            CheckFileStatus;

FROM ImportCommon   IMPORT
                            StopImport;

FROM IntFileIO      IMPORT
                            TextType,                RealNumberType,
                            CardinalType,            BooleanType,
                            PredicateRecordType,     EnumeratedType,
                            SkipRecordType,
                            RepeatRecordType,
                            BigStartTimeType,        BigEndTimeType,
                            StartDateType,           EndDateType,
                            IntegerType,
                            APredicateRecord,
                            AnIntDataRecord,
    (* PROC *)              WriteIntData;

FROM LStrings       IMPORT
                            ConcatLS,         Copy,
                            ConcatS,          SetLengthOf,
                            TStringToLString, LengthOf,
                            TrimFront,        SetString,
                            TrimRear,         StoC;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM ParseReal      IMPORT
    (* PROC *)              ParseAmountToReal;

FROM Progress       IMPORT
    (* TYPE *)              AThermometer,
    (* PROCS *)             CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat,
    (* VAR  *)              DefaultAmountFormat;

FROM RecordIO       IMPORT
    (* PROCS *)             WriteRecord;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, ADR, BYTE;

FROM TimeFormat     IMPORT
                            DtoS;

FROM Timei          IMPORT
    (* TYPE *)              ATimeInfo, ADate,
    (* PROC *)              TtoAbsTimeU, TimeUtoT;


CONST
    ModuleNumber        = 5800; (* Same as TLDB3IMP *)
    NormalFont          = 0C;
    MAXCARDINAL         = 65535;
    Zero                = 0.0;
    MAXDB3FIELDS        = 129;

VAR
    FieldCount              : CARDINAL;

    FormalColumnNameID      : ARRAY [0..MAXDB3FIELDS]  OF CARDINAL;
    FormalColumnType        : ARRAY [0..MAXDB3FIELDS]  OF CARDINAL;
    ColWidth                : ARRAY [0..MAXDB3FIELDS] OF CARDINAL;

    Rows                    : CARDINAL;
    NRec                    : LONGINT;
    CurrentRecord           : LONGINT;
    RecSize                 : CARDINAL;
    Thermometer             : AThermometer;
    dbVersion               : CARDINAL;
    TreeBuilt               : BOOLEAN;
    dB3FieldRecord          : AFieldRecord;



PROCEDURE CheckForCorrectFormat ( VAR  f : File ) : BOOLEAN;
VAR
     ch                  : CHAR;
     TempByte            : BYTE;
     ok                  : BOOLEAN;
     s                   : ARRAY [0..255] OF CHAR;
BEGIN
   ReadByte ( f, ch);

   ok := CheckFileStatus (f);

   IF ( ok ) THEN
      TempByte := ByteAnd ( ch, 07H );

      dbVersion := ORD(TempByte);
      IF ( dbVersion <> DBASE3 ) AND ( dbVersion <> DBASE4 ) THEN
           GetMessage ( ModuleNumber + 3, s );
           (* "Unknown dBase version" *)
           LogAnError ( s );
           ok := FALSE;
      END;
   END;

   RETURN ( ok );

END CheckForCorrectFormat;


PROCEDURE GetDBHeaderData ( VAR f             : File ) : BOOLEAN;
VAR
    ok : BOOLEAN;
BEGIN

    SetRead(f);

    TreeBuilt :=  SetupFormalNameCache ( FileType );               (* 27-Aug-89 MWP *)

    IF ( NOT CheckFileStatus ( f ) ) OR ( NOT ReadDB3Header ( f ) ) THEN
       ok := FALSE;
    END;

    IF ( TreeBuilt ) THEN                                         (* 27-Aug-89 MWP *)
       PurgeCache ();
    END;

    RETURN ( ok );

END GetDBHeaderData;


(*==========================================================================
 *  ReadDB3Header - Read in a dBase lll header, storing field information.
 *  -------------
 *=========================================================================*)
PROCEDURE ReadDB3Header ( VAR f  : File ) : BOOLEAN;
VAR
    i                       : CARDINAL;
    HdrSize                 : CARDINAL;
    Result                  : BOOLEAN;
    PredicateRecord         : APredicateRecord;
    DataRecord              : AnIntDataRecord;
    HeaderRecord            : AHeaderRecord;
    s                       : ARRAY [0..255] OF CHAR;
BEGIN

   Result := DoDb3Header ( f, HeaderRecord );

   IF ( Result ) THEN
       IF ( dbVersion = DBASE4 ) AND
          ( HeaderRecord.Encrypted = CHR(1) ) THEN             (* 06-Sep-91 *)
           GetMessage ( ModuleNumber + 4, s );
           (* "dBase file is encrypted." *)
           LogAnError ( s );
           RETURN FALSE;
       END;

       NRec    := HeaderRecord.NRecs;                          (* 06-Sep-91 *)

       Rows := VAL(CARDINAL, NRec);

       RecSize := HeaderRecord.RecSize;                        (* 06-Sep-91 *)
       HdrSize := HeaderRecord.HeaderLength;
   END;

   FOR i := 0 TO MAXDB3FIELDS DO

      IF ( NOT Result ) THEN
         RETURN FALSE;
      END;

      IF ( IsEndOfHeader ( f ) ) THEN
          FieldCount := i;
          RETURN TRUE;
      END;

      Result := DoDb3Field ( f );

      IF ( NOT Result ) THEN
         RETURN FALSE;
      END;

      WITH dB3FieldRecord DO
         CASE FieldType OF
              "C"       :
                   FormalColumnType[ i ] := 1;
           |  "N"       :

                   IF ( ORD(NDecimals) = 0 ) THEN
                       FormalColumnType[ i ] := 4;
                   ELSE
                       FormalColumnType[ i ] := 2;
                   END;
           |  "D"       :
                   FormalColumnType[ i ] := 9;
           |  "L"       :
                   FormalColumnType[ i ] := 5;
           |  "M"       :
                   FormalColumnType[ i ] := 1;
           |  "F"       :
                   IF ( ORD(NDecimals) = 0 ) THEN
                       FormalColumnType[ i ] := 4;
                   ELSE
                       FormalColumnType[ i ] := 2;
                   END;
         ELSE
           GetMessage ( ModuleNumber + 5, s );
           (* "Unknown dBase field type." *)
           LogAnError ( s );
           RETURN FALSE;
         END;
      END;

      ColWidth[i] := ORD(dB3FieldRecord.FieldSize);

      TStringToLString ( dB3FieldRecord.Name , s );

      IF ( NOT IsFormalNameOurs ( s,
                                  PredicateRecord.DataType,
                                  FileType ) ) THEN                  (* 29-Aug-89 MWP *)
          GetMessage ( ModuleNumber + 10, s );
          (* "Timeline column name not recognized : " *)
          ConcatS ( s, dB3FieldRecord.Name );
          LogAnError ( s );
          PredicateRecord.DataType :=  FormalColumnType[ i ];
      END;


      WITH PredicateRecord DO
          TStringToLString ( dB3FieldRecord.Name , Name );
          TrimFront ( Name );
          TrimRear  ( Name );

          GetMessage ( ModuleNumber + 11, s );
          (* "Reading Column Name " *)
          ConcatLS ( s, Name );
          Message ( s );

          ID           := i;
          HeadingDepth := 2; (* Always? *)
          Width        := 10;
      END;

      WriteRecord( InterFile, PredicateRecordType, ADR(PredicateRecord), SIZE(PredicateRecord) );

      WITH DataRecord DO
          Font := 0C; (* Default Font *)

          SetLengthOf ( LString, 0 );
          WriteIntData( TextType, DataRecord );
          WriteIntData( TextType, DataRecord );
      END;
   END;

   IF ( Result ) THEN
      IF ( FieldCount <> i) THEN
         Result := FALSE;
      ELSE
         SetPos ( f, 0, HdrSize );
      END;
   END;

   SetLengthOf ( s, 0 );                                           (* 5-Sep-89 MWP *)
   Message ( s );

   RETURN ( Result );

END ReadDB3Header;

(*==========================================================================
 *  DoDB3Header - Read in the dBase lll header control record.
 *  ------------
 *========================================================================*)
PROCEDURE DoDb3Header ( VAR   f            : File;
                        VAR   HeaderRecord : AHeaderRecord ) : BOOLEAN;
VAR
    i,
    Length : CARDINAL;
    ok     : BOOLEAN;
    s      : ARRAY [0..255] OF CHAR;
BEGIN

    ok := TRUE;

    Length := SIZE ( HeaderRecord );                           (* 06-Sep-91 *)

    ReadNBytes( f, ADR(HeaderRecord), Length, i );

    ok := CheckFileStatus ( f );

    IF (i < Length) AND ( ok ) THEN
        GetMessage ( ModuleNumber + 6, s );
        (* "Error reading dB3 field data" *)
        LogAnError ( s );
        ok := FALSE;
    END;

    RETURN ok;

END DoDb3Header;


(*==========================================================================
 *  IsEndOfHeader   - Check to see if we are at the end of the dBase header
 *  -------------     information structures. dBase signals the end by inserting
 *                    a CR (0x0d) immediately following the last field
 *                    definition. dBase records start at CR byte + 1.
 *                    The reason we go through this rigormorolle to determine
 *                    if we have reached the end, is the storage method that
 *                    various versions of dBase, both major and minor, have
 *                    employed for storing the CR character. In early versions
 *                    of dBase, the CR was stored as an 'int' i.e 2 bytes.
 *                    In more recent times, they have changed to storing the
 *                    CR correctly as a 'char' or single byte.
 *  Note: If the byte read in is NOT the EOF char, then we store this char in
 *        first element of the FieldName array. The appropriate routines
 *        to read in the field data, begin storage at the second byte of
 *        the structure. (See DoDB3Field and DoDB2Field above.)
 *========================================================================*)
PROCEDURE IsEndOfHeader ( VAR f : File ) : BOOLEAN;
VAR
     ch                  : CHAR;
BEGIN

        (*  This is ReadChar instead of ReadByte so that a cr,lf sequence
            will be translated into EOL.
        *)
    ReadChar ( f, ch );

    IF ( NOT CheckFileStatus (f) ) THEN
       RETURN TRUE;
    END;

    IF ( ch = EOL ) OR
       ( ch = cr ) THEN
      RETURN TRUE;
    END;

    dB3FieldRecord.Name[0] := ch;

    RETURN FALSE;

END IsEndOfHeader;


(*==========================================================================
 *  DoDB3Field - Read in a dBase lll field definition from the header.
 *  -----------
 *========================================================================*)
PROCEDURE DoDb3Field ( VAR  f  : File ) : BOOLEAN;
VAR
    i,
    Length : CARDINAL;
    ok     : BOOLEAN;
    s      : ARRAY [0..255] OF CHAR;
BEGIN

    ok := TRUE;

    Length := SIZE ( dB3FieldRecord ) - 1;

    ReadNBytes( f,
                ADR(dB3FieldRecord.Name[1]),
                Length,
                i );

    ok := CheckFileStatus ( f );

    IF (i < Length) AND ( ok ) THEN
        GetMessage( ModuleNumber + 6, s );
        (* "Error reading dB3 field data" *)
        LogAnError ( s );
        ok := FALSE;
    END;

   RETURN ok;

END DoDb3Field;


PROCEDURE GetDBData ( VAR f             : File ) : BOOLEAN;
VAR
    ok   :  BOOLEAN;
    s    :  ARRAY [0..255] OF CHAR;
BEGIN

    ok := CheckFileStatus ( f );

    IF ( ok ) THEN
        GetMessage ( ModuleNumber + 7, s );
        (* "Records read" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );
        ok := GetDBase ( f );
        DiscardThermometer ( Thermometer );
    END;

    RETURN ok;

END GetDBData;



(*==========================================================================
 * GetDBase - read in a DBase II or III file.
 * --------   Note that we ignore deleted records, and records which are
 *            blank. If a field is marked as a memo field, we place a space
 *            character for data.
 *========================================================================*)
PROCEDURE GetDBase ( VAR f : File ) : BOOLEAN;
VAR
    DeleteChar  : CHAR;
    DeleteFlag  : BOOLEAN;
    bResult     : BOOLEAN;
    ColumnValue : ARRAY [0..255] OF CHAR;
    Type        : CARDINAL;
    DataRecord  : AnIntDataRecord;
    Font        : CHAR;
    Start       : BOOLEAN;
    ThermCount  : CARDINAL;
    USAmountFormat : AnAmountFormat;


    PROCEDURE SetupUSFormat(VAR USAmountFormat : AnAmountFormat);

    BEGIN                   (* SetupUSFormat *)

        USAmountFormat := DefaultAmountFormat;                 (* 23-Jul-90 *)
        WITH USAmountFormat DO                             (* 18-Jul-90 MWP *)
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


BEGIN

   Start := TRUE;
   (*
    * This Module is responsible for reading in an entire dBase record.
    * If the record is marked as deleted, we continue reading until we
    * do have a complete record. This means that we have to have the capability
    * of storing an entire dBase record internally, and this can consume a
    * LOT of memory. Max. of 128 fields, or 4000 bytes per record. We have to
    * allocate 4130 bytes for our maximum, to allow for field seperators
    * and NULL.
   *)

   (* Always use US formatting rules for parsing dBase records *)
    SetupUSFormat( USAmountFormat );

   (* Loop until we have a valid record, or have reached end of records *)

    Type     := TextType;
    Font     := 0C;
    ThermCount := 0;

    bResult := TRUE;

    LOOP
        CurrentRecord := VAL(LONGINT, CurrentRecord) + VAL( LONGINT, 1 );
        UpdateThermometer( Thermometer, ThermCount );

        IF ( CurrentRecord <= NRec ) THEN
            (*
             * Read first byte of record. If = '*', it is deleted. If = ' ' it's
             * a valid record.
            *)
            IF ( ReadDbRecord ( ColumnValue, f, 1 ) ) THEN
(**
                DeleteChar := ColumnValue[0];
***)
                DeleteFlag := ColumnValue[0] = '*';
                (*
                 * Read in the fields. Note that fields are streamed together, padded
                 * with space chars if the text is less than field width.
                *)

                FOR i := 0 TO FieldCount - 1 DO

                      bResult := ReadDbRecord ( ColumnValue, f, ColWidth[i] );

                      IF ( NOT bResult ) THEN
                         EXIT;
                      END;


                      (*Transfer characters to our buffer *)
                      IF ( NOT DeleteFlag ) THEN
                         Type := FormalColumnType[ i ];

                         IF ( Type = 9 ) THEN
                            ReadDate ( ColumnValue );
                         ELSE
                            TStringToLString ( ColumnValue , ColumnValue );
                         END;

                         TrimFront ( ColumnValue );
                         TrimRear ( ColumnValue );

                         IF ( LengthOf ( ColumnValue ) > 0 ) THEN
                              DigestColumn ( ColumnValue, Type, DataRecord, USAmountFormat );
                         ELSE
                              Type := MAXCARDINAL;
                         END;

                         IF (Type = MAXCARDINAL) THEN
                            WriteIntData( SkipRecordType, DataRecord );
                         ELSE
                            WriteIntData( Type, DataRecord );
                         END;
                      END;
                END;
            ELSE
               bResult := FALSE;
            END;
        ELSE
            EXIT;
        END;

        IF ( NOT bResult  ) THEN
             EXIT;
        END;


        IF ( StopImport () ) THEN                               (* 20-Sep-89 MWP *)
           RETURN FALSE;
        END;

      (***
        IF ( ( DeleteChar = " " ) OR ( NOT bResult ) ) THEN
             EXIT;
        END;
      ***)

        INC( ThermCount );
    END;

   RETURN bResult;

END GetDBase;


(*=============================================================================
 *   ReadDbRecord - Read in a field of RecSize from dBase data file.
 *   -------------
 *===========================================================================*)
PROCEDURE ReadDbRecord ( VAR Buffer   : ARRAY OF CHAR;
                         VAR f        : File;
                             Length   : CARDINAL ) : BOOLEAN;
VAR
     i    : CARDINAL;
     ok   : BOOLEAN;
     s    : ARRAY [0..255] OF CHAR;
BEGIN

   ReadNBytes( f,
               ADR(Buffer),
               Length,
               i );

    ok := CheckFileStatus ( f );

    IF ( i < Length ) AND ( ok ) THEN
        GetMessage ( ModuleNumber + 8, s );
        (* "Error reading dB3 data record" *)
        LogAnError ( s );
        ok := FALSE;
    END;

    Buffer[ Length ] := CHR(0);

    RETURN ok;

END ReadDbRecord;


PROCEDURE ReadDate ( VAR ColumnValue : ARRAY OF CHAR );           (* 6Sep-89 MWP *)
VAR
    TimeInfo    : ATimeInfo;
    i, Index    : CARDINAL;
    TempDate    : ADate;
    ok          : BOOLEAN;
    Buffer      : ARRAY [0..10] OF CHAR;
    s           : ARRAY [0..255] OF CHAR;
BEGIN


    Copy ( ColumnValue, s );
    SetLengthOf ( ColumnValue, 0 );

    (* First, the year. *)
    Index := 0;
    FOR i := 0 TO 3 DO
       Buffer[i] := s[ Index ];
       INC(Index);
    END;

    Buffer[i+1] := CHR(0);

    TStringToLString ( Buffer , Buffer );
    TrimFront ( Buffer );
    TrimRear ( Buffer );

    IF ( LengthOf ( Buffer ) = 0 ) THEN
        RETURN;
    END;

    i       := 1;
    TimeInfo.tiYear    := StoC( Buffer, i );
    ok      := (i > 1);  (* Ok not to grab
                                  decimals *)

    Index := 4;
    FOR i := 0 TO 1 DO
       Buffer[i] := s[ Index ];
       INC(Index);
    END;

    Buffer[i+1] := CHR(0);

    TStringToLString ( Buffer , Buffer );
    TrimFront ( Buffer );
    TrimRear ( Buffer );

    IF ( LengthOf ( Buffer ) = 0 ) THEN
        RETURN;
    END;

    i       := 1;
    TimeInfo.tiMonth   := StoC( Buffer, i );
    ok      := (i > 1);

    Index := 6;
    FOR i := 0 TO 1 DO
       Buffer[i] := s[ Index ];
       INC(Index);
    END;

    Buffer[i+1] := CHR(0);

    TStringToLString ( Buffer , Buffer );
    TrimFront ( Buffer );
    TrimRear ( Buffer );

    IF ( LengthOf ( Buffer ) = 0 ) THEN
        RETURN;
    END;

    i       := 1;
    TimeInfo.tiDay     := StoC( Buffer, i );
    ok      := (i > 1);

    TimeInfo.tiHour   := 0;
    TimeInfo.tiMinute := 0;

    IF ( TimeInfo.tiMonth > 0 ) THEN
       DEC(TimeInfo.tiMonth);
    END;

    ok := TtoAbsTimeU(TimeInfo, TempDate);
    TimeUtoT(TempDate, TimeInfo);       (* 7-Nov-90 PFG fiscal yr *)

    ok := CheckDateValues ( TimeInfo );         (* 11-Sep-89 MWP *)

    IF ( ok ) THEN
       DtoS(  TimeInfo, ColumnValue );
    ELSE
       SetLengthOf ( ColumnValue, 1 );
       ColumnValue[1] := '*';
    END;

END ReadDate;


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

        ParseAmountToReal( ColumnValue, AmountFormat, TheData.Real, ok,
                           StoppedAt );

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


VAR
    i  : CARDINAL;

BEGIN
     CurrentRecord      := VAL(LONGINT, 0);
     ImportLineNumber    := 0;
     ErrorsHaveOccured   := FALSE;

     FOR i := 0 TO MAXDB3FIELDS DO
         FormalColumnNameID[i] := 99;
         ColWidth[i] := 0;
     END;


END DBToInt.

