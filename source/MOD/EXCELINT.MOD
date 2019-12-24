    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE ExcelInt;


(*  =========================================================================
    Last Edit : November 9, 1990 6:09PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        ExcelInt - Read Excel file data and convert to intermediate file
                   format.

    MODIFICATION HISTORY:

         01-Apr-89  MWP  In the beginning...
         06-Jul-89  MWP  Allow recognition of the range name "TLDATA". This
                         new range name fully describes the range of data that
                         timeline is to import. The column names are now picked
                         up from the first row of data within TLDATA range.
         08-Jul-89  MWP  Changed the call ReadChar to ReadByte so file read
                         mode remains in binary.
         27-Jul-89  MWP  Display Messages to inform the user what Import is
                         currently doing. During periods of lengthy processing,
                         this will at least show them that Timeline is alive.
         27-Aug-89  MWP  Do not attempt to validate any 123 ranges that are not
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
                         values.
         17-Sep-89  MWP  If fewer rows than indicated by TLTable or TLData are
                         read in, pass the actual number read back to client
                         and log an error. Also, check that the last row
                         read does not have any trailing cells that were not
                         processed.
         19-Sep-89  MWP  Implement break requested processing.
         20-Sep-89  MWP  Removed processing of TL_DATA range name.
         20-Sup-89  MWP  Changed the return logic checking of StopImport.
         22-Sep-89  MWP  When processing records, after we read in the the
                         record header, ALWAYS ensure you also read in the
                         body of the record. This was a really stupid
                         oversight of mine.
         25-Sep-89  MWP  When writing out blank record types,
                         write out SkipRecordType.
          3-Oct-89  MWP  If a date contains invalid values, pass this on
                         to the back end for processing so it can generate
                         a warning message. Otherwise, we will skip over
                         invalid dates and never inform the user!
          7-Oct-89  MWP  Due to what I consider a bug in 123, it is
                         possible to have a label string greater than 240
                         characters in length stored in the WKS file.
                         Because it may also be possible for this to
                         occur in Excel, I have placed a safeguard against
                         this.
         30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
         19-Apr-90  KKC  Grouped year, month, day, hour, minute into one
                         date structure, ATimeInfo. 
         4-May-90   MWP  Added recognition of Excel/OS2 file format. When
                         checking for range name TL_TABLE, ensure it is
                         upper case. ( Also, formal column names. ). When
                         receiving an integer, check if it is a date or not.
                         Excel will save dates as integers, and not floats, if
                         the date has no time value.
         9-Nov-90   PFG  Added the 4.0.3 changes:
                         18-Jul-90   MWP  
                            If a formal column name is blank, DO NOT process 
                             it!
                         20-Jul-90 MWP    
                            Removed OS/2 version code. 
                         24-Jul-90 LAA       
                            Put in character translations just like Lotus.  
                            God, I hope this works! 
                         End of 4.0.3 changes.
        01-Jul-91   LAA  Changed some of the phrase numbers to put out more
                         specific and correct messages when an error occurs.
        08-Jul-91   LAA  Turned off the OS2 comments.  These turn the module
                         initialization into a procedure, which kept important
                         variables from being initialized.  This, in turn,
                         caused bug #4645.
    =========================================================================
*)


FROM BitByteOps     IMPORT
    (* PROC *)              ByteAnd, ByteShr;

FROM Dialog         IMPORT
    (* PROC *)              Message, Error, FatalError;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile;

FROM FileSystem     IMPORT
    (* PROC *)              File, Reset,
                            SetRead,
                            ReadNBytes, ReadByte;

FROM AllFormalName   IMPORT
                            PurgeCache;

FROM Foreign         IMPORT                                    (* 24-Jul-90 *)
    (* TYPE *)              ACharacterConversionTable,
    (* PROC *)              DecodeString, DoDash, ConvertString;

FROM FormalName      IMPORT
    (* PROC *)              IsFormalNameOurs,                     (* 27-Aug-89 MWP *)
                            SetupFormalNameCache;

FROM ImPorTable      IMPORT
                            AnStoreFormalNameProc,
    (* VAR  *)              ImportLineNumber,
                            ErrorsHaveOccured,
                            FileType,                             (* 27-Aug-89 MWP *)
    (* PROC *)              LogAnError,     CheckDateValues,
                            CheckFileStatus;

FROM ImportCommon   IMPORT
                            StopImport;

FROM IntFileIO      IMPORT
                            TextType, RealNumberType, IntegerType,
                            SkipRecordType,
                            PredicateRecordType,
                            APredicateRecord,
                            AnIntDataRecord,
    (* PROC *)              WriteIntData;

FROM LStrings       IMPORT
    (* PROC *)              SetString, SetLengthOf,
                            ConcatLS, Copy, LengthOf,
                            TStringToLString,Upshift,
                            TrimFront, TrimRear, Compare;

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
    (* PROC *)              KDate, RealToDurationCounter,
                            DurationToReal;


CONST
    MaxTextLength           = 255;                                (* 7-Oct-89 MWP *)

    ModuleNumber            = 6000;  (* Shared with TLXEXCEL *)
    LotusModuleNumber       = 5500;  (* Shared with TLXEXCEL *)
    MAX123FIELDS            = 255;

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
    CharacterTable          : ACharacterConversionTable;       (* 24-Jul-90 *)            



PROCEDURE CheckForValidExcelFile ( VAR  f : File ) : BOOLEAN;
VAR
     Header              : ARecordPreface;
     BOFRecord           : ABOFRecord;
     ok                  : BOOLEAN;
     s                   : ARRAY [0..255] OF CHAR;
BEGIN

    ok := TRUE;

    IF ( NOT ReadHeader ( f, Header ) ) THEN
       ok := FALSE;
    ELSIF ( Header.RecordType <> BBOF ) OR
          ( Header.RecordLength <> TSIZE ( ABOFRecord ) ) THEN
       GetMessage ( ModuleNumber + 3, s );
       (* "Invalid record type in the Excel file." *)
       LogAnError ( s );
       ok := FALSE;
    ELSIF ( NOT ReadRecord ( f,
                             ADR(BOFRecord),
                             TSIZE ( ABOFRecord ) ) ) THEN
       ok := FALSE;
    END;

    IF ( ok ) THEN
       IF ( BOFRecord.Version <> VERSIONEXCEL ) AND
          ( BOFRecord.Version <> VERSIONEXCELOS2 ) THEN             (* 4-May-90 MWP *)
          GetMessage ( ModuleNumber + 6, s );
          (* "Incorrect Excel version identifier encountered." *)
          LogAnError ( s );
          ok := FALSE;
       ELSE
          CASE BOFRecord.DocType OF
                 EXCELWORKSHEET :
                      Model := EXCELWORKSHEET;
          ELSE
               GetMessage ( ModuleNumber + 4, s );
               (* "This is not an Excel worksheet." *)
               LogAnError ( s );
               ok := FALSE;
          END;
       END;
    END;
    RETURN ok;

END CheckForValidExcelFile;


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
          GetMessage ( ModuleNumber + 1, s );
          (* "Error reading Excel data record." *)
          LogAnError ( s );
          ok := FALSE;
       END;
    END;

    RETURN ok;
END ReadRecord;



(*==============================================================================
 *   ReadHeader - Read in a excel header.
 *   ----------
 *   The header of a excel file tells what kind of record it is.
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
        (* "Error reading Excel record header" *)
        LogAnError ( s );
        ok := FALSE;
    END;

    RETURN ok;

END ReadHeader;



PROCEDURE ReadExcelRangeNames ( VAR f : File ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
    s   : ARRAY [0..255] OF CHAR;
BEGIN

    ok := FALSE;

    GetMessage ( LotusModuleNumber + 13, TLTableName );
    (* TL_TABLE *)

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

END ReadExcelRangeNames;


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
     ok, EndOfRecords,
     CheckRange          : BOOLEAN;

BEGIN

    EndOfRecords := FALSE;
    ok           := TRUE;
    CheckRange   := FALSE;
 
    LOOP
    (* Make sure that the header was read correctly. *)

        IF ( NOT ReadHeader ( f, Header ) ) THEN
           ok := FALSE;
           EXIT;
        END;

        IF ( NOT ok ) THEN
           EXIT;
        END;

    (* Decide what to do with the record type we just found. *)
        WITH Header DO
            CASE RecordType OF

                 BNAME      :
                         ok := DoNameRange (  f, Range, CheckRange );
                         IF ( ok ) AND
                            ( CheckRange ) THEN
                             ok := ValidRange ( Range );
                         END;

              |  BFILEPASS:
                         GetMessage ( ModuleNumber + 7, s );
                         (* "Worksheet is Password Protected" *)
                         LogAnError ( s );
                         ok := FALSE;
                         EXIT;

              |  BLABEL  :
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

              |  BROW,
                 BBLANK,
                 BINTEGER,
                 BNUMBER,
                 BFORMULA,
                 BSTRING,
                 BBOOLERR,
                 BARRAY,
                 BTABLE,
                 BTABLE2   :
                          IF ( NOT GlobalRangeFound ) THEN
                              ok := FALSE;
                          ELSE
                              ReadUnknown ( f, RecordLength );    (* 21-Sep-89 MWP *)
                          END;
             |   BEOF      :

                         ok := FALSE;
            ELSE
                ReadUnknown ( f, RecordLength );
            END;
        END;
    END;

    RETURN ok;

END ReadRangeNames;

(*==============================================================================
 *   DoNameRange - Read in a Excel record header.
 *   -----------
 *   The header will determine the Excel record type.
 * RETURNS
 *     TRUE if record is read.
 *     FALSE otherwise.
 * NOTES:
 *     To determine if a NAME record is valid for us, ( i.e it refers to a
 *     indivisible rectangular region ) we examine the first byte of the
 *     RPN code. If it is 0x2D, indicating ptgAreaN, we have a valid
 *     reference and we then grab the co-ordinates, else we ignore it.
 *     Now - it is all too possible ( read: likely ) that there are other
 *     ptg tokens which indicate valid ranges. I will investigate, and return
 *     my results asap.
 *============================================================================*)
PROCEDURE DoNameRange (  VAR f          : File;
                         VAR Range      : ARangeNameRecord;
                         VAR CheckRange : BOOLEAN ) : BOOLEAN;
VAR
    ParseTotal : CARDINAL;
    TextTotal  : CARDINAL;
    RangeName  : ARRAY [ 0..255 ] OF CHAR;
    DumpByte   : CHAR;
    Ret        : BOOLEAN;
    XName      : ANameRecordOne;
    XNameCoord : ANameRecordTwo;

BEGIN
   Ret := TRUE;

   CheckRange := FALSE;

   IF ( NOT ReadRecord ( f, ADR(XName), TSIZE(ANameRecordOne ) ) )THEN
       RETURN FALSE;
   END;

   TextTotal  := ORD(XName.Name_Text_Len);
   ParseTotal := ORD(XName.Name_Parse_Len);

   IF ( NOT ReadRecord ( f, ADR(RangeName), TextTotal ) ) THEN
       RETURN FALSE;
   END;

   RangeName [ TextTotal ] := CHR(0);

   TStringToLString ( RangeName, RangeName );

   IF ( LengthOf ( RangeName ) > 15 ) THEN
       SetLengthOf ( RangeName, 15 );
   END;

   Copy ( RangeName, Range.Name );

   Upshift ( Range.Name );

   IF ( ParseTotal > 0 ) THEN
      DEC(ParseTotal);

      IF ( NOT ReadRecord ( f, ADR(DumpByte), 1 ) ) THEN
          RETURN FALSE;
      END;

      IF ( DumpByte = CHR(ptgAreaN) ) OR ( DumpByte = CHR(ptgArea) ) THEN
         IF ( NOT ReadRecord ( f, ADR(XNameCoord), TSIZE(ANameRecordTwo) ) ) THEN
             RETURN FALSE;
         END;

         Range.StartRow := XNameCoord.TopRow;
         Range.EndRow   := XNameCoord.LastRow;
         Range.StartCol := ORD(XNameCoord.FirstCol);
         Range.EndCol   := ORD(XNameCoord.LastCol);

         CheckRange := TRUE;
         Ret := TRUE;
      ELSE
         IF ( ParseTotal > 1 ) THEN
            DEC(ParseTotal);
            ReadUnknown ( f, ParseTotal );
         END;
      END;
   END;

   ReadUnknown ( f, 1 );

   RETURN ( Ret );

END DoNameRange;

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
    LabelRecord       : ALabelRecord;
    DataRecord        : AnIntDataRecord;
    PredicateRecord   : APredicateRecord;
    s                 : ARRAY [0..255] OF CHAR;
    s1                : ARRAY [0..255] OF CHAR;
BEGIN

    FinishedFlag := FALSE;

    IF ( NOT ReadRecord ( f, ADR(LabelRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    IF ( LabelRecord.Row < FormalColumnNameRow ) THEN
        RETURN TRUE;
    END;

    (* We ran out of Formal Names before we were supposed to! Catastrophy! *)

    IF ( LabelRecord.Row > FormalColumnNameRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( LabelRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    LabelRecord.Content[ ORD(LabelRecord.LabelLen) ] := CHR(0);

    TStringToLString ( LabelRecord.Content , s );
    ConvertString( s, CharacterTable );                        (* 24-Jul-90 *)
    GetMessage ( ModuleNumber + 15, s1 );
    (* "Analyzing Column Name " *)

    ConcatLS ( s1, s );
    Message ( s1 );

    IF ( LengthOf ( s ) > 0 ) AND                                 (* 18-Jul-90 MWP *) 
       ( IsFormalNameOurs ( s,
                            PredicateRecord.DataType,
                            FileType ) ) THEN
         INC ( FormalID );

         WITH PredicateRecord DO
             TStringToLString ( LabelRecord.Content , Name );
             TrimFront ( Name );
             TrimRear  ( Name );
             Upshift ( Name );

             ID           := FormalID;
             HeadingDepth := 2;
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
       GetMessage ( ModuleNumber + 16, s );
       (* "Column name not recognized :" *)
       ConcatLS ( s, LabelRecord.Content );
       LogAnError ( s );
    END;

    IF ( ( GlobalEndCol - GlobalStartCol ) + 1 = FormalID ) THEN
       FinishedFlag := TRUE;
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

    Copy ( Range.Name, FormalName );
    ConvertString (FormalName, CharacterTable);                (* 24-Jul-90 *)

    GetMessage ( ModuleNumber + 14, s );
    (* "Analyzing range name " *)
    ConcatLS ( s, FormalName );
    Message ( s );

    IF ( Compare ( TLTableName, FormalName ) = 0 ) THEN
       GlobalStartCol := Range.StartCol;
       GlobalEndCol   := Range.EndCol;
       GlobalStartRow := Range.StartRow;
       GlobalEndRow   := Range.EndRow;
       FormalColumnNameRow := GlobalStartRow;
       GlobalRangeFound := TRUE;
       TLTableFound := TRUE;

       FOR i := GlobalStartCol TO GlobalEndCol DO
          ValidColumns[ i ] := TRUE;
       END;

       DataStartRow := GlobalStartRow + 1;
       DataEndRow   := GlobalEndRow;
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



PROCEDURE ReadExcelData ( VAR f             : File;
                          VAR RowsImported  : CARDINAL ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
    s   :  ARRAY [0..255] OF CHAR;
    s1  :  ARRAY [0..255] OF CHAR;
    Rows : CARDINAL;
BEGIN

    RowsImported := 0;

    ok := CheckFileStatus( f );

    IF ( ok ) THEN
       GetMessage ( ModuleNumber + 9, s );
       (* "Records read" *)
       Rows    := ( DataEndRow - DataStartRow ) + 1 ;
       ok := CreateThermometer( Thermometer, 0, 0, s, Rows );
       ok := ReadRowData ( f );
       DiscardThermometer ( Thermometer );
    END;

    RowsImported := NRecImported;                                 (* 17-Sep-89 MWP *)

    (* If we did not read in the number of rows indicated by TL_TABLE or
       TL_DATA then notify the user.
    *)
    IF ( RowsImported <> Rows ) THEN                              (* 17-Sep-89 MWP *)
      GetMessage ( LotusModuleNumber + 19, s );
      (* " Fewer rows have been processed than indicated by ~ " *)
      GetMessage ( LotusModuleNumber + 13, s1 );
      (* "TL_TABLE" *)
      ConcatLS ( s, s1 );
      LogAnError ( s );
    END;

    RETURN ok;

END ReadExcelData;



PROCEDURE ReadRowData ( VAR f : File ) : BOOLEAN;
VAR
    EndOfRecords : BOOLEAN;
    Header       : ARecordPreface;
    ok           : BOOLEAN;
    Count        : CARDINAL;
BEGIN

    EndOfRecords := FALSE;
    ok := TRUE;
    Count := 0;

    LOOP
    (* Make sure that the header was read correctly. *)
        INC(Count);

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

                 BBLANK       :
                         ok := DoBlank ( f, RecordLength, EndOfRecords );

             |   BINTEGER     :
                         ok := DoInteger ( f, RecordLength, EndOfRecords );

             |   BLABEL       :
                         ok := DoLabel ( f, RecordLength, EndOfRecords );

             |   BNUMBER      :
                         ok := DoNumber ( f, RecordLength, EndOfRecords );

             |   BBOOLERR     :
                         ok :=  DoBool ( f, RecordLength, EndOfRecords );

             |   BEOF         :
                         CheckForTrailingCells ();
                         EXIT;
            ELSE
                (* Skip this record as it isn't needed. *)
                ReadUnknown ( f, RecordLength );
            END;
        END;
    END;

    RETURN ok;

END ReadRowData;


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

    WriteIntData( SkipRecordType, DataRecord );
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
    LabelRecord  : ALabelRecord;
    DataRecord   : AnIntDataRecord;
    LabelLen     : CARDINAL;
BEGIN

    FinishedFlag := FALSE;

(********
    IF ( Length > MaxTextLength ) THEN                            (* 7-Oct-89 MWP *)
       LabelLen := MaxTextLength;
    ELSE
       LabelLen := Length;
    END;
**********)

    IF ( NOT ReadRecord ( f, ADR(LabelRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    LabelRecord.Content[ ORD(LabelRecord.LabelLen) ] := CHR(0);


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

(*******
    LabelRecord.Content[ ORD(LabelRecord.LabelLen) ] := CHR(0);
******)

    TStringToLString ( LabelRecord.Content , DataRecord.LString );
    ConvertString( DataRecord.LString, CharacterTable );       (* 24-Jul-90 *)

    WriteIntData( TextType, DataRecord );

    IF ( LabelRecord.Row > CurrentRow ) THEN
       CurrentRow := LabelRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := LabelRecord.Column;

(*******
    IF ( LabelLen < Length ) THEN                                 (* 7-Oct-89 MWP *)
        ReadUnknown ( f, Length - LabelLen );
    END;
********)

    RETURN TRUE;

END DoLabel;


(*=============================================================================
 *  DoBool  - read in a boolean record.
 *  ------
 *
 *===========================================================================*)
PROCEDURE DoBool ( VAR  f            : File;
                         Length       : CARDINAL;
                    VAR  FinishedFlag : BOOLEAN ) : BOOLEAN;
VAR
    BoolRecord   : ABooleanRecord;
    DataRecord   : AnIntDataRecord;
BEGIN

    FinishedFlag := FALSE;

    IF ( NOT ReadRecord ( f, ADR(BoolRecord), Length ) ) THEN
       FinishedFlag := TRUE;
       RETURN FALSE;
    END;

    IF ( BoolRecord.Row < DataStartRow ) THEN
        RETURN TRUE;
    END;

    IF ( BoolRecord.Row > CurrentRow ) AND                       (* 29-Aug-89 MWP *)
       ( CurrentRow > DataStartRow ) THEN
       CheckForTrailingCells ();
    END;

    IF ( BoolRecord.Row > DataEndRow ) THEN
        FinishedFlag := TRUE;
        RETURN TRUE;
    END;

    IF ( NOT IsValidColumn ( BoolRecord.Column ) ) THEN
        RETURN TRUE;
    END;

    CheckForSkippedCells ( BoolRecord.Column );                    (* 29-Aug-89 MWP *)

    SetString ( DataRecord.LString, "" );

    IF ( BoolRecord.Bool_Or_Err = CHR(0) ) THEN
       IF ( BoolRecord.Value = CHR(1) ) THEN
          GetMessage ( ModuleNumber + 10, DataRecord.LString );
       ELSE
          GetMessage ( ModuleNumber + 11, DataRecord.LString );
       END;
    END;

    WriteIntData( TextType, DataRecord );

    IF ( BoolRecord.Row > CurrentRow ) THEN
       CurrentRow := BoolRecord.Row;
       UpDateTherm ();
    END;

    CurrentCol := BoolRecord.Column;

    RETURN TRUE;

END DoBool;


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

    IF ( NOT IsDateOrTime ( IntegerRecord.Cell2 ) ) THEN
       DataRecord.Integer := IntegerRecord.Value;
       WriteIntData( IntegerType, DataRecord );
    ELSE
        IF ( ConvertToDate ( FLOAT(IntegerRecord.Value), DataRecord.LString ) ) THEN
            WriteIntData  ( TextType, DataRecord );
        ELSE
            FatalError ();
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

    IF ( NOT IsDateOrTime ( NumeralRecord.Cell_Att2 ) ) THEN
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

    k := RealToDurationCounter(Value);

    WITH TimeInfo DO
        IF ( k > LotusOffset ) THEN
            KDate(k - LotusOffset, tiYear, tiMonth, tiDay);
            tiMinute := TRUNC((Value - DurationToReal(k)) * 1440.0);
            tiHour := tiMinute DIV 60;
            tiMinute := tiMinute - (tiHour * 60);

            ok := CheckDateValues ( TimeInfo );   (* 11-Sep-89 MWP *)

            IF ( ok ) THEN
            DtoS(  TimeInfo, ColumnValue );
            END;
        END;
    END;

    RETURN ( TRUE );

END ConvertToDate;




PROCEDURE IsDateOrTime ( Format : BYTE ) : BOOLEAN;
VAR
    TempFormat : BYTE;
    LeftByte   : BYTE;
    RightByte  : BYTE;
BEGIN
    TempFormat := ByteAnd ( Format, 3FH );

    CASE ORD(TempFormat) OF
              F_DATE_1,
              F_DATE_2,
              F_DATE_3,
              F_DATE_4,
              F_TIME_1,
              F_TIME_2,
              F_TIME_3,
              F_TIME_4,
              F_DATE_TIME   :

                     RETURN TRUE;
    ELSE
                  RETURN FALSE;
    END;

END IsDateOrTime;


PROCEDURE  UpDateTherm ();
BEGIN
    INC(NRecImported);
    UpdateThermometer( Thermometer, NRecImported);
END UpDateTherm;


(*<OS2
PROCEDURE ExcelIntInitForOS2 ();
OS2>*)

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

    FOR i := 0 TO MAX123FIELDS DO
        ValidColumns [i] := FALSE;
    END;

    BuildCharacterTable();                                     (* 24-Jul-90 *)

(*<OS2
END ExcelIntInitForOS2;
OS2>*)

END ExcelInt.
