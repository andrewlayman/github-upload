MODULE TLDB3Import;

    (*
        TL dB3 Import - dBase Import front end.

            This module provides the ability to read a Lotus file containing
            exported TimeLine data, and convert the data into an
            intermediate file format for proccessing by importer back
            end overlays.


        Terminology:

            For this module, we view the Lotus file as a continuous stream
            of columns. We make no effort to distinguish between rows.

            In order to extract the correct information from the 123 file for
            the back end, there are several cavaets which apply to the
            structure of the 123 file that the user must adhere to.

            We extract, essentially, 2 main sets of data from the file:
               - The column headings.
               - The actual data.

            Column Headings:
            ================

            The column headings are stored as Range Names in the file. This
            modules' first task is to pre-process the 123 file looking for
            all Range Names. Any that are found are saved in a simple list.
            This list is ordered by ascending column number ( so that the
            Range Names correspond to the information found within the rows. )

            We DO NOT pre-process the Range Names for validity. This means
            that only Range Names exported by Timeline be present within
            the 123 file. The user should not have other ranges created, or
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

            dbtoint     is used to read the actual file contents, and write
                        them to the intermediate file.

        Modification History:


        31-Mar-89  MWP  In the beginning...
        10-Aug-89  KKC  Add copyright message.
        28-Aug-89  KKC  Remove DigestReportHolderRecord and
                        BuildReportHolderRecord from the import statements.
        30-Aug-89  MWP  Improved error and message reporting.
        22-Sep-89  MWP  We were trying to retrive a non-existent phrase.
         6-Oct-89  MWP  Use LogAMessage and LogSignOnMessage to place
                        information into the Import journal.
        11-Mar-91  RSC  Open file in read-only mode.
        06-Sep-91  LAA  Removed use of dB3HeaderRecord global, which had
                        been superceeded by use of parameters.  Took 
                        ImportTableP out of DBToInt.DEF and moved it here.
    *)

FROM DBToInt        IMPORT
                            GetDBHeaderData, GetDBData,
                            CheckForCorrectFormat,
                            AHeaderRecord,
                            DoDb3Header;

FROM Dialog         IMPORT
    (* PROC *)              Error;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile, ExportName, ExportMedia;

FROM FileAux        IMPORT
    (* PROCS *)             PrepareForIO, CheckIO,
                            FileResultMeans;

FROM FileSystem     IMPORT
    (* TYPE *)              File,  Response,
    (* CONST *)             ReadOnlyMode,
    (* PROCS *)             Close, OpenFile, SetRead, GetPos, SetPos;

FROM ImPorTable      IMPORT
    (* CONST *)             ImportOverall,       ImportPredicate,
                            ImportData,
                            ErrorsHaveOccured,
    (* TYPE *)              AImportTable,
    (* PROC *)              LogAnError,
                            LogSignOnMsg,
                            LogAMessage,
                            FileNotFound;

FROM IntFileIO      IMPORT
                            AnOverallRecord,
                            APredicateHeadingRecord, ADomainRecord;

FROM LStrings       IMPORT
    (* PROCS *)             SetString,        Copy,LengthOf, Fill,
                            LStringToTString, SetLengthOf,
                            ConcatLS;

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
    ModuleNumber            = 5800;
    (* Subfile IO version number:   *)

    VersionNumber           = 1; (* For subfiles *)

VAR
    f                       : File;
    ImportTableP            : POINTER TO AImportTable;

PROCEDURE GenerateDBHeaders() : BOOLEAN;
CONST
    MaxSubfileCount         = 25;
VAR
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    DomainRecord            : ADomainRecord;

    ok                      : BOOLEAN;
    HeaderRecord            : AHeaderRecord;
    High, Low               : CARDINAL;
    Rows                    : CARDINAL;

    PROCEDURE ReadOverallRecord ( VAR OverallRec : AnOverallRecord );
    BEGIN
        WITH OverallRec DO
            Revision     := Rows;
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
            Width        :=  10;
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

    SetRead(f);

    GetPos ( f, High, Low );

    IF ( NOT DoDb3Header ( f, HeaderRecord ) ) THEN
       RETURN FALSE;
    END;

    SetPos ( f, High, Low );

    Rows :=  VAL( CARDINAL, HeaderRecord.NRecs );              (* 06-Sep-91 *)

    ReadOverallRecord ( OverallRecord );

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
       RETURN FALSE;
    END;

    IF ( NOT GetDBHeaderData ( f ) ) THEN
       EndSubfileOutput( InterFile, ImportPredicate );
       RETURN FALSE;
    END;

    EndSubfileOutput( InterFile, ImportPredicate );

    RETURN  CheckFileStatus(  InterFile );

END GenerateDBHeaders;


PROCEDURE DoTLDBTable() : BOOLEAN;

    PROCEDURE Setup () : BOOLEAN;
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

        IF ( NOT CheckForCorrectFormat ( f ) ) THEN
           RETURN FALSE;
        END;

        RETURN TRUE;

    END GetFile;


    PROCEDURE GenerateData() : BOOLEAN;
    VAR
        ok           : BOOLEAN;
    BEGIN

        ok := CheckFileStatus ( InterFile );

        (* Generate the data section of the file. *)

        IF ( ok ) THEN
           StartSubfileOutput( InterFile, ImportData, VersionNumber );
        END;

        ok := ( ok AND CheckFileStatus ( InterFile ) );

        ok := ( ok AND GetDBData ( f ) );

        ok := ( ok AND CheckFileStatus ( InterFile ) );

        IF ( ok ) THEN
            EndSubfileOutput( InterFile, ImportData );
        END;

        RETURN ( ok );

    END GenerateData;


BEGIN
    PackageOK := Setup ();

    PackageOK := ( PackageOK AND GenerateDBHeaders() );

    PackageOK := ( PackageOK AND GenerateData() );

    IF ( PackageOK ) THEN
       IF ( CheckIO( InterFile ) = done ) THEN
          PackageOK := GenerateFileTrailers();
       ELSE
          PackageOK := FALSE;
       END;
    END;

    Close ( f );

    RETURN ( PackageOK );

END DoTLDBTable;


PROCEDURE CheckFileStatus(VAR f: File):BOOLEAN;
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

    ok := DoTLDBTable();

    IF ( NOT ok ) THEN
       GetMessage ( ModuleNumber + 9, s );                        (* 20-Sep-89 MWP *)
       LogAnError ( s );
    END;

    IF ( ErrorsHaveOccured ) OR
       ( NOT ok ) OR ( NOT PackageOK ) THEN
       ImportTableP^.ErrorOccured := TRUE;
       SetLengthOf ( s, 0 );
       LogAMessage ( s );
    END;

END TLDB3Import.
