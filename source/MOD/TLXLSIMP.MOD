MODULE TLXLSImport;

    (*
        TL Excel Import - Excel Import front end.

            This module provides the ability to read a Lotus file containing
            exported TimeLine data, and convert the data into an
            intermediate file format for proccessing by importer back
            end overlays.


        Terminology:

            For this module, we view the Lotus file as a continuous stream
            of columns. We make no effort to distinguish between rows.

            In order to extract the correct information from the Excel file for
            the back end, there are several cavaets which apply to the
            structure of the Excel file that the user must adhere to.

            We extract, essentially, 2 main sets of data from the file:
               - The column headings.
               - The actual data.

            Column Headings:
            ================

            The column headings are stored as Range Names in the file. This
            modules' first task is to pre-process the Excel file looking for
            all Range Names. Any that are found are saved in a simple list.
            This list is ordered by ascending column number ( so that the
            Range Names correspond to the information found within the rows. )

            We DO NOT pre-process the Range Names for validity. This means
            that only Range Names exported by Timeline be present within
            the Excel file. The user should not have other ranges created, or
            we may try to import this data also. ( Though it will not be
            fatal, it may cause data to be missed or erroneously interpreted. )

            ONLY Columns associated with these Range Names will be imported.
            Other columns will be ignored during the import.

            Hidden columns WILL BE imported. This allows the user to "fold"
            the spreadsheet by hiding sets of columns, and still have this
            information imported.

            We assume that each Range Name covers only a single column.
            If we discover that the co-ordinates for a range cover mulitple
            columns, we will not import that Range.

            Data Import:
            ============

            In order to intellegintly retrieve only those records associated
            with the Ranges, we must know the Start and End rows. These are
            calculated during the Column pre-processing. We use the Start
            and End rows for each valid Range Name record. ( The way
            we currently perform it, the last valid range name record's
            read in will have it's Start and End row values used. )

        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Related Modules:

            Lotusint     is used to read the actual file contents, and write
                         them to the intermediate file.

        Modification History:


         1-Apr-89  MWP  In the beginning...
         6-Jul-89  MWP  We were reporting that N + 1 records were being output
                        to the intermediate file, rather than the more
                        precise N records. ( But, we were close! )
        10-Aug-89  KKC  Add copyright message.
        28-Aug-89  KKC  Remove DigestReportHolderRecord and
                        BuildReportHolderRecord from the import statements.
        30-Aug-89  MWP  Improved error and message reporting.
        17-Sep-89  MWP  Pass on the actual number of records read in to
                        intermediate file.
         6-Oct-89  MWP  Use LogAMessage and LogSignOnMessage to place
                        information into the Import journal.
        11-Mar-91  RSC  Made file read-only.
    *)

FROM Dialog         IMPORT
    (* PROC *)              Error;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile, ExportName, ExportMedia;

FROM FileAux        IMPORT
    (* PROCS *)             PrepareForIO, CheckIO,
                            FileResultMeans;

FROM FileSystem     IMPORT
    (* TYPE *)              File, Response,
    (* CONST *)             ReadOnlyMode,
    (* PROCS *)             Close, OpenFile, SetRead, SetPos, GetPos;

FROM ImPorTable      IMPORT
    (* CONST *)             ImportOverall,       ImportPredicate,
                            ImportData,
                            ErrorsHaveOccured,
    (* PROC *)              LogAnError,
                            LogSignOnMsg,
                            LogAMessage,
                            FileNotFound;

FROM IntFileIO      IMPORT
    (* TYPE *)              AnOverallRecord,
                            APredicateHeadingRecord, ADomainRecord;

FROM ExcelInt       IMPORT
    (* PROC *)              ReadExcelRangeNames, ReadExcelData,
                            CheckForValidExcelFile,
    (* VAR *)               DataEndRow, DataStartRow,
                            ImportTableP;

FROM LStrings       IMPORT
    (* PROCS *)             SetString, Copy, LengthOf, Fill,
                            LStringToTString, SetLengthOf, ConcatLS;

FROM MsgFile        IMPORT
    (* PROCS *)             GetMessage;

FROM Overlays       IMPORT
    (* VAR *)               PackageOK,
    (* PROCS *)             OverlayContext;

FROM RecordIO       IMPORT
    (* PROCS *)             WriteRecord;

FROM RptCommon      IMPORT
    (* PROCS *)             GenerateFileTrailers,
                            CreateTheFile;

FROM Subfiles       IMPORT
    (* PROCS *)             StartFileOutput,
                            StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, ADR;

CONST
    ModuleNumber            = 6000;
    VersionNumber           = 1; (* For subfiles *)

VAR
    f                       : File;
    OverallHigh, OverallLow : CARDINAL;


PROCEDURE RewriteOverallRecord ( RowsImported : CARDINAL );
VAR
    OverallRecord   : AnOverallRecord;
    High, Low       : CARDINAL;
BEGIN

    GetPos ( InterFile, High, Low );

    SetPos ( InterFile, OverallHigh, OverallLow );

    WITH OverallRecord DO
(***
         Revision     := DataEndRow - DataStartRow;                  (* 6-Jul-89 MWP *)
***)
         Revision     := RowsImported;                               (* 17-Sep-89 MWP *)
         Dimensions   := 1;
         Font         := 0C;
         SetLengthOf ( ReportName, 0 );
    END;

    WriteRecord( InterFile, 1, ADR(OverallRecord), SIZE(OverallRecord) );

    SetPos ( InterFile, High, Low );

END RewriteOverallRecord;


PROCEDURE GenerateExcelHeaders () : BOOLEAN;
CONST
    MaxSubfileCount         = 25;
VAR
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    DomainRecord            : ADomainRecord;

    PROCEDURE ReadOverallRecord ( VAR OverallRec : AnOverallRecord );
    BEGIN
        WITH OverallRec DO
            Revision     := 0;
            Dimensions   := 1;
            Font         := 0C;
            SetLengthOf ( ReportName, 0 );
        END;
    END ReadOverallRecord;


    PROCEDURE ReadDomainRecord ( VAR DomainRec : ADomainRecord );
    BEGIN
        WITH DomainRec DO
            HeadingDepth := 1;
            Discrete     := TRUE;
            SetLengthOf ( DimensionName, 0 );
            Width        := 10;
        END;
    END ReadDomainRecord;

BEGIN

    StartFileOutput( InterFile, MaxSubfileCount );

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
       RETURN FALSE;
    END;

    StartSubfileOutput( InterFile, ImportOverall, VersionNumber );

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
       RETURN FALSE;
    END;

    ReadOverallRecord ( OverallRecord );

    GetPos ( InterFile, OverallHigh, OverallLow );

    WriteRecord( InterFile, 1, ADR(OverallRecord), SIZE(OverallRecord) );

    PredicateHeadingRecord.HeadingDepth := 2;

    WriteRecord( InterFile, 2, ADR(PredicateHeadingRecord), SIZE(PredicateHeadingRecord) );

    ReadDomainRecord ( DomainRecord );

    WriteRecord(InterFile, 3, ADR(DomainRecord), SIZE(DomainRecord) );

    EndSubfileOutput( InterFile, ImportOverall );

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
       RETURN FALSE;
    END;

    StartSubfileOutput( InterFile, ImportPredicate, VersionNumber );

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
       RETURN FALSE
    END;

    IF ( NOT ReadExcelRangeNames ( f ) ) THEN
       EndSubfileOutput( InterFile, ImportPredicate );
       RETURN FALSE;
    END;

    EndSubfileOutput( InterFile, ImportPredicate );

(*******
    RewriteOverallRecord();
*******)

    RETURN (CheckIO( InterFile ) = done);

END GenerateExcelHeaders;


PROCEDURE DoTLExcelTable() : BOOLEAN;

    PROCEDURE Setup() : BOOLEAN;
    VAR
        s  : ARRAY [0..255] OF CHAR;
        ok : BOOLEAN;
    BEGIN

        SetLengthOf (s,0);

        ok := CreateTheFile ( s );

        IF ( NOT ok ) THEN
          GetMessage ( ModuleNumber, s );
          (* "Error creating temporary file" *)
          LogAnError ( s );
        END;

        ok := ( ok AND GetFile ( s ) );

        RETURN ( ok );

    END Setup;


    PROCEDURE GetFile ( VAR FileName : ARRAY OF CHAR ):BOOLEAN;
    BEGIN
        Copy (ExportMedia, FileName);
        ConcatLS (FileName, ExportName);

        LStringToTString( FileName, FileName );
        PrepareForIO( f );
        OpenFile( f, FileName, ReadOnlyMode );  (* 12-Mar-91 RSC  *)
(*        Lookup( f, FileName, FALSE );*)

        IF (CheckIO(f) <> done) THEN
           FileNotFound ( FileName );
           RETURN FALSE;
        END;

        SetRead(f);

        IF ( NOT CheckForValidExcelFile ( f ) ) THEN
           RETURN FALSE;
        END;

        RETURN TRUE;

    END GetFile;


    PROCEDURE GenerateData() : BOOLEAN;
    VAR
        ok           : BOOLEAN;
        RowsIn        : CARDINAL;
    BEGIN

        IF NOT ( CheckFileStatus ( InterFile ) ) THEN
           RETURN FALSE;
        END;

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, ImportData, VersionNumber );

        IF ( CheckFileStatus ( InterFile ) ) THEN
            ok := ReadExcelData ( f, RowsIn );
        END;

        ok := ( ok AND CheckFileStatus ( InterFile ) );

        IF ( ok ) THEN
            EndSubfileOutput( InterFile, ImportData );

            RewriteOverallRecord( RowsIn );                         (* 17-Sep-89 MWP *)
        END;

        RETURN ( ok );

    END GenerateData;


BEGIN
    PackageOK := Setup ();

    PackageOK := ( PackageOK AND GenerateExcelHeaders() );

    PackageOK := ( PackageOK AND GenerateData() );

    IF ( PackageOK ) THEN
        PackageOK := ( ( CheckIO ( InterFile ) = done) AND
                         GenerateFileTrailers() );
    END;

    Close ( f );

    RETURN ( PackageOK );

END DoTLExcelTable;


PROCEDURE CheckFileStatus ( VAR f : File ) : BOOLEAN;
VAR
    s           : ARRAY [0..255] OF CHAR;
    Copyright   : ARRAY [0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IF (CheckIO(f) = done) THEN
        RETURN TRUE;
    END;

    FileResultMeans(f,s);
    Error(s);
    LogAnError ( s );

    RETURN FALSE;

END CheckFileStatus;

VAR
    s         : ARRAY [0..255] OF CHAR;
    ok        : BOOLEAN;
    Len       : CARDINAL;

BEGIN
    ImportTableP := OverlayContext();

    LogSignOnMsg ();                                           (* 30-Aug-89 MWP *)
(*********
    GetSignOnMsg ( s );                                           (* 30-Aug-89 MWP *)

    ok := AppendLine( s, ImportNote );

    Len := LengthOf ( s );

    Fill ( s, 'Ä', Len );
    ok := AppendLine( s, ImportNote );
**********)

    ok := DoTLExcelTable();

    IF ( NOT ok ) THEN
       GetMessage ( ModuleNumber + 13, s );
       LogAnError ( s );
    END;

    IF ( ErrorsHaveOccured ) OR
       ( NOT ok ) OR ( NOT PackageOK ) THEN
       ImportTableP^.ErrorOccured := TRUE;
       SetLengthOf ( s, 0 );
       LogAMessage ( s );
(********
       ok := AppendLine( s, ImportNote );
********)
    END;

END TLXLSImport.
