IMPLEMENTATION MODULE LotusInt;


    (*
        LotusInt - Read 123 file data and convert to intermediate file
                   format.

        Modification History:

         01-Apr-89  MWP  In the beginning...
         06-Jul-89  MWP  Allow recognition of the range names "TL_DATA" and
                         TL_TABLE .
                         New range nameS fully describes the range of data that
                         timeline is to import. The column names are now picked
                         up from the first row of data within TL_DATA range.
         08-Jul-89  MWP  Changed the call ReadChar to ReadByte so file read
                         mode remains in binary.
         27-Jul-89  MWP  Display Messages to inform the user what Import is
                         currently doing. During periods of lengthy processing,
                         this will at least show them that Timeline is alive.
         23-Aug-89  MWP  Do not attempt to validate any 123 ranges that are not
                         TL_DATA or TL_TABLE.
         27-Aug-89  MWP  Implement faster method of validating formal column
                         names.
         29-Aug-89  MWP  Allow recognizing 'gaps' between successive cells,
                         and write out 'n' int data records for the cell
                         gap interval.
         29-Aug-89  MWP  Write the ColumnDataType in the predicate record for
                         the back end.
          1-Sep-89  MWP  Remove text literals.
          5-Sep-89  MWP  Make sure message area is erased after reading header.
         11-Sep-89  MWP  When writing out blank cells, write out SkipRecordType.
         11-Sep-89  MWP  When reading an 123 date value, validate the date
         12-Sep-89  MWP  When reading an integer record, check if the format
                         is percent. If it is, cast to real, divide by 100
                         and write out a real record int type.
         17-Sep-89  MWP  If fewer rows than indicated by TLTable or TLData are
                         read in, pass the actual number read back to client
                         and log an error. Also, check that the last row
                         read does not have any trailing cells that were not
                         processed.
         19-Sep-89  MWP  Implement break requested processing.
         20-Sep-89  MWP  Removed processing of TL_DATA range name.
         22-Sup-89  MWP  Changed the return logic checking of StopImport.
         22-Sep-89  MWP  When reading range names, after we read in the the
                         record header, ALWAYS ensure you also read in the
                         body of the record. This was a really stupid
                         mistake by me.
         25-Sep-89  MWP  When writing out blank record types,
                         write out SkipRecordType.
          3-Oct-89  MWP  If a date contains invalid values, pass this on
                         to the back end for processing so it can generate
                         a warning message. Otherwise, we will skip over
                         invalid dates and never inform the user!
          7-Oct-89  MWP  Well, due to what I consider a bug in 123, it is
                         possible to have a label string greater than 240
                         characters in length stored in the WKS file. We
                         have to check for labels larger than 240 chars,
                         and truncate if necessary.
         30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
         19-Apr-90  KKC  Grouped year, month, day, hour, minute into one
                         date structure, ATimeInfo. 
          4-May-90  MWP  When checking for range name TL_TABLE, ensure it is
                         upper case. ( Also, formal column names. ).
        18-Jul-90   MWP  If a formal column name is blank, DO NOT process
                         it!
        20-Jul-90   MWP  Perform character set translation on import.
        23-Jul-90   LAA  Changed to use ConvertString rather than 
                         ConvertedCharacter in a loop.
         5-Apr-91   RSC  Fixed bug where ERASED columns caused fatal errors.
        18-Jun-91   RSC  Resynch 4.0 with EVE.
        06-Sep-91   LAA  Added "ONTARGET" as a synonoym for "TL_TABLE" to
                         identify a spreadsheet which we can import.
    *)

FROM BitByteOps     IMPORT
    (* PROC *)              ByteAnd, ByteShr;

FROM Dialog         IMPORT
    (* PROC *)              Message, Error;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile;

FROM FileSystem     IMPORT
    (* PROC *)              File, Reset,
                            SetRead,
                            ReadNBytes, ReadByte;

FROM Foreign                IMPORT                                  (* 20-Jul-90 MWP *)
    (* TYPE *)                  ACharacterConversionTable,
    (* PROC *)                  DecodeString, DoDash, ConvertString;

FROM AllFormalName   IMPORT
                            PurgeCache;

FROM FormalName      IMPORT
    (* PROC *)              IsFormalNameOurs,                     (* 27-Aug-89 MWP *)
                            SetupFormalNameCache;

FROM ImPorTable      IMPORT
                            AnStoreFormalNameProc,
    (* VAR  *)              ImportLineNumber,
                            ErrorsHaveOccured,
                            FileType,                             (* 27-Aug-89 MWP *)
    (* PROC *)              LogAnError,      CheckDateValues,
                            CheckFileStatus;

FROM ImportCommon   IMPORT
                            StopImport;

FROM IntFileIO      IMPORT
                            TextType, RealNumberType, IntegerType,
                            SkipRecordType,
                            CardinalType,
                            PredicateRecordType,
                            APredicateRecord,
                            AnIntDataRecord,
    (* PROC *)              WriteIntData;

FROM LStrings       IMPORT
    (* PROC *)              LStringToTString, SetLengthOf,
                            ConcatLS, Copy, LengthOf,
                            TStringToLString, Upshift,
                            SubStr, TrimFront, TrimRear, Compare;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Progress       IMPORT
    (* TYPE *)              AThermometer,
    (* PROCS *)             CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RecordIO       IMPORT
    (* PROCS *)             WriteRecord;

FROM Space          IMPORT
    (* PROCS *)             HeapAvailable;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, TSIZE, ADDRESS, ADR, BYTE;

FROM TimeFormat     IMPORT
                            DtoS;

FROM Timei          IMPORT
    (* TYPE *)              ADurationCounter, ATimeInfo,
    (* PROC *)              KDate, RealToDuration, DurationToReal;

CONST
    MAX123FIELDS            = 255;

    MaxTextLength           = 240;                                (* 7-Oct-89 MWP *)

    ModuleNumber            = 5500;

VAR
    ValidColumns            : ARRAY [ 0..MAX123FIELDS ] OF BOOLEAN;

    NRecImported            : CARDINAL;
    CurrentRow              : CARDINAL;
    CurrentCol              : CARDINAL;                           (* 29-Aug-89 MWP *)
    Model                   : CARDINAL;
    Thermometer             : AThermometer;
    FormalID,
    GlobalStartCol,
    GlobalEndCol,
    GlobalStartRow,
    GlobalEndRow,
    FormalColumnNameRow     : CARDINAL;
    GlobalRangeFound        : BOOLEAN;
    TreeBuilt               : BOOLEAN;                            (* 27-Aug-89 MWP *)
    TLTableFound            : BOOLEAN;
    TLTableName             : ARRAY [0..15] OF CHAR;
    OTTableName             : ARRAY [0..15] OF CHAR;           (* 06-Sep-91 *)
    CharacterTable          : ACharacterConversionTable;       (* 20-Jul-90 MWP *)



PROCEDURE CheckForCorrectFormat ( VAR  f : File ) : BOOLEAN;
VAR
     Header              : ARecordPreface;
     Version             : AVersionRecord;
     ok                  : BOOLEAN;
     s                   : ARRAY [0..255] OF CHAR;
BEGIN

    ok := TRUE;

    IF ( NOT ReadHeader ( f, Header ) ) THEN
       ok := FALSE;
    ELSIF ( Header.RecordType <> 0 ) OR ( Header.RecordLength <> 2 ) THEN
       GetMessage ( ModuleNumber + 3, s );
       (*  "Invalid Lotus file" *)
       LogAnError ( s );
       ok := FALSE;
    ELSIF ( NOT ReadRecord ( f,
                             ADR(Version),
                             TSIZE ( AVersionRecord ) ) ) THEN
       ok := FALSE;
    END;

    IF ( ok ) THEN
       CASE Version.Version OF
              L123v1a  :
                   Model := L123v1a;

            | SYMPHONY :
                   Model := SYMPHONY;

            | BOTH     :
                   Model := BOTH;
       ELSE
            GetMessage ( ModuleNumber + 4, s );
            (* "Unknown Lotus version" *)
            LogAnError ( s );
            ok := FALSE;
       END;
    END;

    RETURN ok;

END CheckForCorrectFormat;



PROCEDURE ReadRecord ( VAR f             : File;
                           RecordAddress : ADDRESS;
                           Length        : CARDINAL ) : BOOLEAN;
VAR
    i  : CARDINAL;
    ok : BOOLEAN;
    s  : ARRAY [0..255] OF CHAR;
BEGIN
    ok := FALSE;

    IF ( CheckFileStatus ( f ) ) THEN
       ReadNBytes ( f, RecordAddress, Length, i );

       ok := CheckFileStatus ( f );

       IF (i < Length) OR ( NOT ok ) THEN
           GetMessage ( ModuleNumber + 5, s );
           (* "Error reading 123 record header" *)
           LogAnError ( s );
           ok := FALSE;
       END;
    END;

    RETURN ok;
END ReadRecord;


(*=============================================================================
 *   ReadHeader - Read in a lotus header.
 *   ----------
 *   A header of a lotus file tells what kind of record it is.
 * RETURNS
 *     TRUE if record is read.
 *     FALSE otherwise.
 *============================================================================*)
PROCEDURE ReadHeader ( VAR  f      : File;
                       VAR  Header : ARecordPreface ) : BOOLEAN;
VAR
    i,
    Length : CARDINAL;
    s      : ARRAY [0..255] OF CHAR;
    ok     : BOOLEAN;
BEGIN

    ok := TRUE;
    Length  :=  TSIZE( ARecordPreface );

    ReadNBytes( f,
                ADR(Header),
                Length,
                i );

    ok := CheckFileStatus ( f );

    IF (i < Length) OR ( NOT ok ) THEN
        GetMessage ( ModuleNumber + 5, s );
        (* "Error reading 123 record header" *)
        LogAnError ( s );
        ok := FALSE;
    END;

    RETURN ok;

END ReadHeader;


PROCEDURE Get123HeaderData ( VAR f : File ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
    s   : ARRAY [0..255] OF CHAR;
BEGIN

    ok := FALSE;

    (* TL_TABLE *)
    GetMessage ( ModuleNumber + 13, TLTableName );
    (* ONTARGET *)
    GetMessage( ModuleNumber + 1, OTTableName );               (* 06-Sep-91 *)

    TreeBuilt :=  SetupFormalNameCache ( FileType );               (* 27-Aug-89 MWP *)

    SetRead ( f );

    IF ( CheckFileStatus ( f ) ) THEN
        ok := ReadRangeNames ( f );
    END;

    SetLengthOf ( s, 0 );                                         (* 5-Sep-89 MWP *)
    Message ( s );

    IF ( TreeBuilt ) THEN                                         (* 27-Aug-89 MWP *)
       PurgeCache ();
    END;

    Reset ( f );

    RETURN ok;

END Get123HeaderData;


(*==========================================================================
 *  ReadRangeNames - Read in Range records, which hopefully contain formal
 *  --------------   names.
 *
 *=========================================================================*)
PROCEDURE ReadRangeNames ( VAR f  : File ) : BOOLEAN;
VAR
     Header              : ARecordPreface;
     Range               : ARangeNameRecord;
     s                   : ARRAY [0..255] OF CHAR;
     ok, EndOfRecords    : BOOLEAN;
BEGIN

    EndOfRecords := FALSE;
    ok := TRUE;

    LOOP
    (* Make sure that the header was read correctly. *)

        IF ( NOT ReadHeader ( f, Header ) ) THEN
           EXIT;
        END;

        IF ( NOT ok ) THEN
           EXIT;
        END;

    (* Decide what to do with the record type we just found. *)
        WITH Header DO

            CASE RecordType OF

                 LNNAME     :
                         ok := ReadRecord ( f, ADR(Range), 25 );
                         ok := ( ok AND ValidRange ( Range ) );

              |  LNAME      :
                         ok := ReadRecord ( f, ADR(Range), 24 );
                         ok := ( ok AND ValidRange ( Range ) );


              |  LWKSPWORD:

                (* The worksheet file has been password protected and we can't
                   do anything with it. *)

                         GetMessage ( ModuleNumber + 7, s );
                         (* "Worksheet is Password Protected" *)
                         LogAnError ( s );
                         ok := FALSE;
                         EXIT;

              |  LLABEL    :
                          IF ( GlobalRangeFound ) THEN
                              ok := ReadColumnNames ( f,
                                                      RecordLength,
                                                      EndOfRecords );
                          ELSE
                             ok := FALSE;
                          END;

                          IF ( EndOfRecords ) THEN
                             RETURN TRUE;
                          END;

              |  LBLANK,
                 LINTEGER,
                 LNUMBER,
                 LFORMULA,
                 LSTRING   :
                          IF ( NOT GlobalRangeFound ) THEN
                              ok := FALSE;
                          ELSE
                              ReadUnknown ( f, RecordLength );
                          END;

              |  LEOF      :
                          ok := FALSE;

            ELSE
                 (* Skip this record as it isn't needed. *)
                ReadUnknown ( f, RecordLength );
            END;
        END;
    END;

    RETURN ok;

END ReadRangeNames;


(*=============================================================================
 *  ReadColumnNames - search for and readin the Timeline column names and
 *                    validate them.
 *  -------
 *
 *===========================================================================*)
PROCEDURE ReadColumnNames ( VAR  f            : File;
                                 Length       : CARDINAL;
                            VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    A1, A2           : ADDRESS;
    LabelLen , i     : CARDINAL;
    LabelRecord      : ALabelRecord;
    DataRecord       : AnIntDataRecord;
    PredicateRecord  : APredicateRecord;
    LabelString      : ARRAY [0..256] OF CHAR;
    s                : ARRAY [0..256] OF CHAR;
    s1               : ARRAY [0..255] OF CHAR;
BEGIN

    FinishedFlag := FALSE;

    IF ( Length > MaxTextLength ) THEN                            (* 7-Oct-89 MWP *)
       LabelLen := MaxTextLength;
    ELSE
       LabelLen := Length;
    END;

    IF ( NOT ReadRecord ( f, ADR(LabelRecord), LabelLen ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    A1 := ADR(LabelRecord);         (* 5-Apr-91 RSC  *)
    A2 := ADR(LabelRecord.Content); (* 5-Apr-91 RSC  *)
    i  := A2.OFFSET - A1.OFFSET;    (* 5-Apr-91 RSC  *)
    LabelRecord.Content[LabelLen - i] := 0C;    (* 5-Apr-91 RSC  *)

    IF ( LabelRecord.Row < FormalColumnNameRow ) THEN
        RETURN TRUE;
    END;

    (* We ran out of Formal Names before we were supposed to! Catastrophy! *)

    IF ( LabelRecord.Row > FormalColumnNameRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

        (* 18-Jun-91 RSC new method:
        *)
    IF (LabelRecord.Column < GlobalStartCol) OR
       (LabelRecord.Column > GlobalEndCol)   THEN
        RETURN TRUE;
    END;

    TStringToLString ( LabelRecord.Content , s );

    ConvertString (s, CharacterTable);                         (* 23-Jul-90 *)

    SubStr ( s,
             LabelString,
             2,
             LengthOf ( s ) );

    GetMessage ( ModuleNumber + 16, s1 );
    (*  "Analyzing Column Name " *)                   (* 27-Jul-89 MWP *)
    IF ( LengthOf ( LabelString ) > 70 ) THEN
       Copy ( LabelString, s );
       SetLengthOf ( s, 70 );
    ELSE
       Copy ( LabelString, s );
    END;

    ConcatLS ( s1, s );
    Message ( s1 );

    LStringToTString ( LabelString , s );

    IF ( LengthOf ( LabelString ) > 0 ) AND                                 (* 18-Jul-90 MWP *)
       ( IsFormalNameOurs ( LabelString,
                            PredicateRecord.DataType,
                            FileType ) ) THEN                  (* 29-Aug-89 MWP *)
         INC ( FormalID );
         ValidColumns[ LabelRecord.Column ] := TRUE;    (* 8-Apr-91 RSC *)

         WITH PredicateRecord DO
             Copy ( LabelString, Name );
             TrimFront ( Name );
             TrimRear  ( Name );
             Upshift ( Name );                                 (* 4-May-90 MWP *)

             ID           := FormalID;
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
    ELSE
       ValidColumns[ LabelRecord.Column ] := FALSE;
       GetMessage ( ModuleNumber + 12, s );
       (* Range name is not recognized as a Timeline column :" *)

       ConcatLS ( s, LabelString );
       LogAnError ( s );
    END;

    IF ( ( GlobalEndCol - GlobalStartCol ) + 1 = FormalID ) THEN
       FinishedFlag := TRUE;
    END;

    IF ( LabelLen < Length ) THEN                                 (* 7-Oct-89 MWP *)
        ReadUnknown ( f, Length - LabelLen );
    END;

    RETURN TRUE;

END ReadColumnNames;


PROCEDURE  ValidRange ( VAR Range : ARangeNameRecord ) : BOOLEAN;
VAR
    s           : ARRAY [ 0..255] OF CHAR;
    FormalName  : ARRAY [ 0..255] OF CHAR;
    i           : CARDINAL;
BEGIN

    IF ( GlobalRangeFound ) THEN
       RETURN TRUE;
    END;

    TStringToLString ( Range.Name, FormalName );
    Upshift ( FormalName );                                    (* 4-May-90 MWP *)

    ConvertString (FormalName, CharacterTable);                (* 23-Jul-90 *)

    GetMessage ( ModuleNumber + 17, s );
    (* "Analyzing 123 Range Name " *)
    ConcatLS ( s, FormalName );
    Message ( s );

    IF ( Compare ( TLTableName, FormalName ) = 0 )
       OR (Compare( OTTableName, FormalName ) = 0) THEN
       IF ( Range.EndCol >= 255 ) OR
          ( Range.EndRow >= 8191 ) THEN
             GetMessage ( ModuleNumber + 8, s );
             (* "Invalid Range Coordinates" *)
             ConcatLS ( s, FormalName );
             LogAnError ( s );
             RETURN FALSE;
       ELSIF ( Range.StartCol >= 255 ) OR
             ( Range.StartRow >= 8191 ) THEN
             GetMessage ( ModuleNumber + 8, s );
             (* "Invalid Range Coordinates" *)
             ConcatLS ( s, FormalName );
             LogAnError ( s );
             RETURN FALSE;
       ELSE
          GlobalStartCol := Range.StartCol;
          GlobalEndCol   := Range.EndCol;
          GlobalStartRow := Range.StartRow;
          GlobalEndRow   := Range.EndRow;
          FormalColumnNameRow := GlobalStartRow;
          GlobalRangeFound := TRUE;
          TLTableFound := TRUE;

            (* 18-Jun-91 RSC removed
            *)
(*          FOR i := GlobalStartCol TO GlobalEndCol DO*)
(*             ValidColumns[ i ] := TRUE;*)
(*          END;*)

          DataStartRow := GlobalStartRow + 1;
          DataEndRow   := GlobalEndRow;
       END;
    END;

    RETURN TRUE;

END ValidRange;


PROCEDURE  ReadUnknown ( VAR f            : File;
                             RecordLength : CARDINAL );
VAR
    i  : CARDINAL;
    ch : CHAR;
BEGIN
    i := 0;

    WHILE ( i < RecordLength ) DO
       ReadByte ( f, ch);
       INC(i);
    END;
END  ReadUnknown;



PROCEDURE Get123Data ( VAR f : File;
                       VAR RowsImported : CARDINAL ) : BOOLEAN;
VAR
    Rows : CARDINAL;
    ok  : BOOLEAN;
    s   :  ARRAY [0..255] OF CHAR;
    s1  :  ARRAY [0..255] OF CHAR;
BEGIN
    RowsImported := 0;

    ok := CheckFileStatus( f );

    IF ( ok ) THEN
       GetMessage ( ModuleNumber + 9, s );
       (* "Records read" *)
       Rows    := ( DataEndRow - DataStartRow ) + 1 ;
       ok := CreateThermometer( Thermometer, 0, 0, s, Rows );
       ok := GetLotusData ( f );
       DiscardThermometer ( Thermometer );
    END;

    RowsImported := NRecImported;                                 (* 17-Sep-89 MWP *)

    (* If we did not read in the number of rows indicated by TL_TABLE or
       TL_DATA then notify the user.
    *)
    IF ( RowsImported <> Rows ) THEN                              (* 17-Sep-89 MWP *)
      GetMessage ( ModuleNumber + 19, s );
      (* " Fewer rows have been processed than indicated by ~ " *)
      GetMessage ( ModuleNumber + 13, s1 );
      (* "TL_TABLE" *)

      ConcatLS ( s, s1 );
      LogAnError ( s );
    END;

    RETURN ok;

END Get123Data;

PROCEDURE GetLotusData ( VAR f : File ) : BOOLEAN;
VAR
    Type         : CARDINAL;
    Header       : ARecordPreface;
    Font         : CHAR;
    EndOfRecords : BOOLEAN;
    ok           : BOOLEAN;
BEGIN

    Type     := TextType;
    Font     := 0C;

    EndOfRecords := FALSE;
    ok := TRUE;

    LOOP
    (* Make sure that the header was read correctly. *)

        IF ( NOT ok ) THEN
           EXIT;
        END;

        IF ( EndOfRecords ) THEN
           ok := TRUE;
           EXIT;
        END;

        IF ( NOT ReadHeader ( f, Header ) ) THEN
           ok := FALSE;
           EXIT;
        END;


        IF ( StopImport () ) THEN                               (* 20-Sep-89 MWP *)
           ok := FALSE;
           EXIT;
        END;

    (* Decide what to do with the record type we just found. *)
        WITH Header DO

            CASE RecordType OF

                 LLABEL       :
                         ok := DoLabel ( f, RecordLength, EndOfRecords );

             |   LINTEGER     :
                         ok := DoInteger ( f, RecordLength, EndOfRecords );

             |   LNUMBER      :
                         ok := DoNumber ( f, RecordLength, EndOfRecords );

             |   LBLANK       :
                         ok := DoBlank ( f, RecordLength, EndOfRecords );

             |   LEOF         :
                         CheckForTrailingCells ();
                         EXIT;
            ELSE
                (* Skip this record as it isn't needed. *)
                ReadUnknown ( f, RecordLength );
            END;
        END;
    END;

    RETURN ok;
END GetLotusData;


(*=============================================================================
 *  CheckForSkippedCells
 *  --------------------
 * Check to see if there are missed cells between the current column and the
 * last column referenced. This is not as simple as it may appear at first
 * glance. We have to take into consideration that we are only concerned with
 * VALID columns. We also have to be cognisant of row changes. ( In this case,
 * New Column will be <= Old Column.
 *
 *===========================================================================*)
PROCEDURE CheckForSkippedCells ( NewCol : CARDINAL );
VAR
    i : CARDINAL;
BEGIN

    (* If the current column is greater than lastcolumn + one,
       then write out the intervening valid columns as blank int records.
    *)
    IF ( CurrentCol + 1 < NewCol ) THEN
       FOR i := CurrentCol + 1 TO NewCol - 1 DO
          IF ( IsValidColumn ( i ) ) THEN
             WriteBlankRecord ();
          END;
       END;
    END;

END CheckForSkippedCells;


PROCEDURE CheckForTrailingCells ();
VAR
    i : CARDINAL;
BEGIN
    (* If the last column referenced is less than the GlobalEndCol,
       then write out the intervening valid columns as blank int records.
    *)
    IF ( CurrentCol < GlobalEndCol ) THEN
       FOR i := CurrentCol + 1 TO GlobalEndCol DO
          IF ( IsValidColumn ( i ) ) THEN
             WriteBlankRecord ();
          END;
       END;
    END;

END CheckForTrailingCells;


PROCEDURE WriteBlankRecord ();
VAR
    DataRecord   : AnIntDataRecord;
BEGIN

    SetLengthOf ( DataRecord.LString, 0 );

    WriteIntData( SkipRecordType, DataRecord );                    (* 11-Sep-89 MWP *)

END WriteBlankRecord;



PROCEDURE IsValidColumn ( Column : CARDINAL ) : BOOLEAN;
BEGIN
     RETURN ( ValidColumns[Column] = TRUE );
END IsValidColumn;


(*=============================================================================
 *  DoLabel - read in a label
 *  -------
 * This function reads in a label from a lotus work sheet file.
 *
 *===========================================================================*)
PROCEDURE DoLabel ( VAR  f            : File;
                         Length       : CARDINAL;
                    VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    A1, A2       : ADDRESS;
    LabelLen, i  : CARDINAL;
    LabelRecord  : ALabelRecord;
    DataRecord   : AnIntDataRecord;
    LabelString  : ARRAY [0..256] OF CHAR;
BEGIN

    FinishedFlag := FALSE;

    IF ( Length > MaxTextLength ) THEN                            (* 7-Oct-89 MWP *)
       LabelLen := MaxTextLength;
    ELSE
       LabelLen := Length;
    END;

    IF ( NOT ReadRecord ( f, ADR(LabelRecord), LabelLen ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    A1 := ADR(LabelRecord);         (* 5-Apr-91 RSC  *)
    A2 := ADR(LabelRecord.Content); (* 5-Apr-91 RSC  *)
    i  := A2.OFFSET - A1.OFFSET;    (* 5-Apr-91 RSC  *)
    LabelRecord.Content[LabelLen - i] := 0C;    (* 5-Apr-91 RSC  *)

    IF ( LabelRecord.Row < DataStartRow ) THEN
        RETURN TRUE;
    END;

    IF ( LabelRecord.Row > CurrentRow ) AND                       (* 29-Aug-89 MWP *)
       ( CurrentRow > DataStartRow ) THEN
       CheckForTrailingCells ();
    END;

    IF ( LabelRecord.Row > DataEndRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( LabelRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    CheckForSkippedCells ( LabelRecord.Column );                    (* 29-Aug-89 MWP *)

    TStringToLString ( LabelRecord.Content , LabelRecord.Content );

    ConvertString (LabelRecord.Content, CharacterTable);       (* 23-Jul-90 *)

    SubStr ( LabelRecord.Content,
             LabelString,
             2,
             LengthOf ( LabelRecord.Content ) );

    Copy ( LabelString, DataRecord.LString );
    WriteIntData( TextType, DataRecord );

    IF ( LabelRecord.Row > CurrentRow ) THEN
       CurrentRow := LabelRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := LabelRecord.Column;

    IF ( LabelLen < Length ) THEN                                 (* 7-Oct-89 MWP *)
        ReadUnknown ( f, Length - LabelLen );
    END;

    RETURN TRUE;

END DoLabel;


PROCEDURE  UpDateTherm ();
BEGIN
    INC(NRecImported);
    UpdateThermometer( Thermometer, NRecImported);
END UpDateTherm;


(*==============================================================================
 *   DoBlank - read in an blank record
 *   -------
 *   This function reads in an blank from a lotus work sheet file.
 *
 *============================================================================*)
PROCEDURE DoBlank ( VAR  f            : File;
                         Length       : CARDINAL;
                    VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    BlankRecord    : ABlankRecord;
    DataRecord     : AnIntDataRecord;
BEGIN

    FinishedFlag := FALSE;

    IF ( NOT ReadRecord ( f, ADR(BlankRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    IF ( BlankRecord.Row < DataStartRow ) THEN
        RETURN TRUE;
    END;

    IF ( BlankRecord.Row > CurrentRow ) AND                       (* 29-Aug-89 MWP *)
       ( CurrentRow > DataStartRow ) THEN
       CheckForTrailingCells ();
    END;

    IF ( BlankRecord.Row > DataEndRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( BlankRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    CheckForSkippedCells ( BlankRecord.Column );                    (* 29-Aug-89 MWP *)

    SetLengthOf ( DataRecord.LString, 0 );
    WriteIntData( SkipRecordType, DataRecord );                     (* 25-Sep-89 MWP *)

    IF ( BlankRecord.Row > CurrentRow ) THEN
       CurrentRow := BlankRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := BlankRecord.Column;

    RETURN TRUE;

END DoBlank;



(*==============================================================================
 *   DoInteger - read in an integer record
 *   ---------
 *   This function reads in an integer from a lotus work sheet file.
 *
 *============================================================================*)
PROCEDURE DoInteger ( VAR  f            : File;
                           Length       : CARDINAL;
                      VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    IntegerRecord  : AIntegerRecord;
    DataRecord     : AnIntDataRecord;
    r              : REAL;
BEGIN

    FinishedFlag := FALSE;

    IF ( NOT ReadRecord ( f, ADR(IntegerRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    IF ( IntegerRecord.Row < DataStartRow ) THEN
        RETURN TRUE;
    END;

    IF ( IntegerRecord.Row > CurrentRow ) AND                       (* 29-Aug-89 MWP *)
       ( CurrentRow > DataStartRow ) THEN
       CheckForTrailingCells ();
    END;

    IF ( IntegerRecord.Row > DataEndRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( IntegerRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    CheckForSkippedCells ( IntegerRecord.Column );                    (* 29-Aug-89 MWP *)

    IF ( NOT IsDateOrTime ( IntegerRecord.Format ) ) THEN
       IF ( IsFormatPercent ( IntegerRecord.Format ) ) THEN           (* 12-Sep-89 MWP *)
         r := FLOAT(IntegerRecord.Value);
(***
         r := r / 100.0;
***)
         DataRecord.Real := r;
         WriteIntData( RealNumberType, DataRecord );
       ELSE
         DataRecord.Integer := IntegerRecord.Value;
         WriteIntData( IntegerType, DataRecord );
       END;
    ELSE
        IF ( ConvertIntToDate ( IntegerRecord.Value, DataRecord.LString ) ) THEN
            WriteIntData  ( TextType, DataRecord );
        ELSE
            WriteIntData  ( SkipRecordType, DataRecord );
        END;
    END;

    IF ( IntegerRecord.Row > CurrentRow ) THEN
       CurrentRow := IntegerRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := IntegerRecord.Column;

    RETURN TRUE;

END DoInteger;



(*=============================================================================
 *   DoNumber - read in a real number record
 *   --------
 *   This function reads in a real number from a lotus work sheet file.
 *===========================================================================*)
PROCEDURE DoNumber ( VAR  f            : File;
                          Length       : CARDINAL;
                     VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    NumeralRecord  : ANumericRecord;
    DataRecord     : AnIntDataRecord;
BEGIN

    FinishedFlag := FALSE;

    IF ( NOT ReadRecord ( f, ADR(NumeralRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    IF ( NumeralRecord.Row < DataStartRow ) THEN
        RETURN TRUE;
    END;

    IF ( NumeralRecord.Row > CurrentRow ) AND                       (* 29-Aug-89 MWP *)
       ( CurrentRow > DataStartRow ) THEN
       CheckForTrailingCells ();
    END;

    IF ( NumeralRecord.Row > DataEndRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( NumeralRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    CheckForSkippedCells ( NumeralRecord.Column );                    (* 29-Aug-89 MWP *)

    IF ( NOT IsDateOrTime ( NumeralRecord.Format ) ) THEN
           DataRecord.Real := NumeralRecord.Value;
           WriteIntData ( RealNumberType, DataRecord );
    ELSE
        IF ( ConvertToDate ( NumeralRecord.Value, DataRecord.LString ) ) THEN
            WriteIntData  ( TextType, DataRecord );
        ELSE
            WriteIntData  ( SkipRecordType, DataRecord );
        END;
    END;

    IF ( NumeralRecord.Row > CurrentRow ) THEN
       CurrentRow := NumeralRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := NumeralRecord.Column;

    RETURN TRUE;

END DoNumber;

PROCEDURE  ConvertIntToDate (     Value       : INTEGER;
                              VAR ColumnValue : ARRAY OF CHAR ) : BOOLEAN;
CONST
    LotusOffset         = VAL( ADurationCounter, 29280 );
VAR
    k                   : ADurationCounter;
    TimeInfo            : ATimeInfo;
    s                   : ARRAY [0..255] OF CHAR;
    ok                  : BOOLEAN;
BEGIN

    ok := FALSE;

    SetLengthOf ( ColumnValue, 1 );
    ColumnValue[1] := '*';

    k := VAL( ADurationCounter, Value);

    WITH TimeInfo DO
        IF ( k > LotusOffset ) THEN
            KDate(k - LotusOffset, tiYear, tiMonth, tiDay);
            tiHour := 9;
            tiMinute := 0;
            ok := CheckDateValues ( TimeInfo );       (* 11-Sep-89 MWP *)

            IF ( ok ) THEN
            DtoS(  TimeInfo, ColumnValue );
            END;
        END;
    END;

    RETURN ( TRUE );

END ConvertIntToDate;


PROCEDURE  ConvertToDate ( Value : REAL; VAR ColumnValue : ARRAY OF CHAR ) : BOOLEAN;
CONST
    LotusOffset         = VAL( ADurationCounter, 29280 );
VAR
    k                   : ADurationCounter;
    TimeInfo            : ATimeInfo;
    s                   : ARRAY [0..255] OF CHAR;
    ok                  : BOOLEAN;
BEGIN

    ok := FALSE;

    SetLengthOf ( ColumnValue, 1 );
    ColumnValue[1] := '*';

    k := RealToDuration(Value);
    WITH TimeInfo DO
        IF ( k > LotusOffset ) THEN
            KDate(k - LotusOffset, tiYear, tiMonth, tiDay);
            tiMinute := TRUNC((Value - DurationToReal(k)) * 1440.0);
            tiHour := tiMinute DIV 60;
            tiMinute := tiMinute - (tiHour * 60);

            ok := CheckDateValues (  TimeInfo );   (* 11-Sep-89 MWP *)
            IF ( ok ) THEN
            DtoS(  TimeInfo, ColumnValue );
            END;
        END;
    END;

    RETURN ( TRUE );

END ConvertToDate;


PROCEDURE IsRealFormat ( Format : BYTE ) : BOOLEAN;
VAR
    TempFormat : BYTE;
    LeftByte   : BYTE;
    RightByte  : BYTE;
BEGIN
    TempFormat := ByteAnd ( Format, 7FH );

    LeftByte   := ByteShr ( TempFormat, 4 );

    RightByte  := ByteAnd ( TempFormat, 0FH );

    IF ( ORD ( LeftByte ) <> L_SPECIAL ) AND ( ORD ( RightByte ) > 0 ) THEN
       RETURN TRUE;
    END;

    RETURN FALSE;

END IsRealFormat;


PROCEDURE IsDateOrTime ( Format : BYTE ) : BOOLEAN;
VAR
    TempFormat : BYTE;
    LeftByte   : BYTE;
    RightByte  : BYTE;
BEGIN
    TempFormat := ByteAnd ( Format, 7FH );

    LeftByte   := ByteShr ( TempFormat, 4 );

    RightByte  := ByteAnd ( TempFormat, 0FH );

    IF ( ORD(LeftByte) <> L_SPECIAL ) THEN
       RETURN FALSE;
    END;

    CASE ORD(RightByte) OF

                  L_DATE_DMY,
                  L_DATE_DM,
                  L_DATE_MY,
                  S_HR_MM_SEC,
                  S_HR_MM,
                  S_DATE_INT1,
                  S_DATE_INT2,
                  S_TIME_INT1,
                  S_TIME_INT2   :
                     RETURN TRUE;
    ELSE
                  RETURN FALSE;
    END;

END IsDateOrTime;



PROCEDURE IsFormatPercent ( Format : BYTE ) : BOOLEAN;
VAR
    TempFormat : BYTE;
    LeftByte   : BYTE;
    RightByte  : BYTE;
BEGIN
    TempFormat := ByteAnd ( Format, 7FH );

    LeftByte   := ByteShr ( TempFormat, 4 );

    RightByte  := ByteAnd ( TempFormat, 0FH );

    IF ( ORD(LeftByte) <> L_PERCENT ) THEN
       RETURN FALSE;
    END;

    RETURN TRUE;

END IsFormatPercent;


PROCEDURE BuildCharacterTable ();                                   (* 18-Jul-90 MWP *)
VAR
    i               : CARDINAL;
    From            : ARRAY [0..199] OF CHAR;
    To              : ARRAY [0..127] OF CHAR;
    Pos             : CARDINAL;

BEGIN
    i := 20;
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


VAR
    i  : CARDINAL;

BEGIN
    ImportLineNumber    := 0;
    DataStartRow        := 0;
    DataEndRow          := 0;
    CurrentRow          := 0;
    CurrentCol          := 0;
    NRecImported        := 0;
    ErrorsHaveOccured   := FALSE;
    GlobalRangeFound    := FALSE;
    FormalID            := 0;
    TLTableFound        := FALSE;
    GlobalStartCol      := 0;   (* 8-Apr-91 RSC Init these... *)
    GlobalEndCol        := 0;

    FOR i := 0 TO MAX123FIELDS DO
        ValidColumns [i] := FALSE;
    END;

    BuildCharacterTable();                                          (* 18-Jul-90 MWP *)

END LotusInt.
