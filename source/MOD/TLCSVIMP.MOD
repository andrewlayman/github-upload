MODULE TLCSVImport;

    (*
        Import records from a comma delimited export file, converting and
        storing in intermediate file format.

        Modification History:


         15-Mar-89  MWP  In the beginning...
         10-Aug-89  KKC  Add copyright message.
         28-Aug-89  KKC  Remove DigestReportHolderRecord and
                         BuildReportHolderRecord from the import statements.
         29-Aug-89  MWP  Improved error and message reporting.
          2-Oct-89  MWP  Removed the pre-processing pass which determined
                         the number of records to import. This 'analyze'
                         phase is now included in the actual data import.
                         This allows us to detect an incorrect record, and
                         continue on to the back end processing without
                         generating a fatal error.
         6-Oct-89  MWP  Use LogAMessage and LogSignOnMessage to place
                        information into the Import journal.
        25-Oct-89  MWP  If the row count from the csv translator is equal
                        to zero, bail out without calling the back end.
        11-Mar-91  RSC  Changed file open to be ReadOnlyMode.
    *)

FROM CSVToInt       IMPORT
    (* VAR *)               ImportTableP,
    (* PROC *)              WriteCSVHeaderData, WriteCSVData;

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
    (* PROCS *)             Close, OpenFile, GetPos, SetPos, SetRead;

FROM ImPorTable      IMPORT
    (* CONST *)             ImportOverall,       ImportPredicate,
                            ImportData,
                            ErrorsHaveOccured,
                            FileNotFound,
    (* PROC *)              LogAnError,         LogSignOnMsg,
    (* PROC *)              LogAMessage;

FROM IntFileIO      IMPORT
    (* TYPE *)              APredicateHeadingRecord, ADomainRecord,
                            AnOverallRecord;

FROM LStrings       IMPORT
    (* PROCS *)             SetString, LengthOf, Fill,
                            Copy,
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
    (* PROCS *)             GenerateFileTrailers, CreateTheFile;

FROM Subfiles       IMPORT
    (* PROCS *)             StartFileOutput,
                            StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, ADR;

CONST
    ModuleNumber        = 5700;
    VersionNumber       = 1; (* For subfiles *)

VAR
    f                       : File;
    RowsCount               : CARDINAL;
    OverallHigh, OverallLow : CARDINAL;


PROCEDURE RewriteOverallRecord ( RowsImported : CARDINAL );
VAR
    OverallRecord   : AnOverallRecord;
    High, Low       : CARDINAL;
BEGIN

    GetPos ( InterFile, High, Low );

    SetPos ( InterFile, OverallHigh, OverallLow );

    WITH OverallRecord DO
         Revision     := RowsImported;                               (* 17-Sep-89 MWP *)
         Dimensions   := 1;
         Font         := 0C;
         SetLengthOf ( ReportName, 0 );
    END;

    WriteRecord( InterFile, 1, ADR(OverallRecord), SIZE(OverallRecord) );

    SetPos ( InterFile, High, Low );

END RewriteOverallRecord;


PROCEDURE GenerateCSVHeaders () : BOOLEAN;
CONST
    MaxSubfileCount = 25;
VAR
    OverallRecord          : AnOverallRecord;
    PredicateHeadingRecord : APredicateHeadingRecord;
    DomainRecord           : ADomainRecord;

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

    SetRead(f);

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
       RETURN FALSE;
    END;

    IF ( NOT WriteCSVHeaderData ( f ) ) THEN
       EndSubfileOutput( InterFile, ImportPredicate );
       RETURN FALSE;
    END;

    EndSubfileOutput( InterFile, ImportPredicate );

    RETURN (CheckIO( InterFile ) = done);

END GenerateCSVHeaders;


PROCEDURE DoTLCSVTable () : BOOLEAN;

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

        ok := ( ok AND WriteCSVData ( f, RowsCount ) );

        IF ( RowsCount = 0 ) THEN
            ok := FALSE;
        END;

        ok := ( ok AND CheckFileStatus ( InterFile ) );

        IF ( ok ) THEN
            EndSubfileOutput( InterFile, ImportData );
            RewriteOverallRecord( RowsCount );                      (* 2-Oct-89 MWP *)
        END;

        RETURN ( ok );

    END GenerateData;


BEGIN
    PackageOK := Setup ();

    PackageOK := ( PackageOK AND GenerateCSVHeaders() );

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

END DoTLCSVTable;


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
    ImportTableP := OverlayContext();                             (* 31-Aug-89 MWP *)

    LogSignOnMsg ();                                           (* 30-Aug-89 MWP *)

    RowsCount := 0;

    ok := DoTLCSVTable();

    IF ( NOT ok ) THEN
       GetMessage ( ModuleNumber + 10, s );
       LogAnError ( s );
    END;

    IF ( ErrorsHaveOccured ) OR
       ( NOT ok ) OR ( NOT PackageOK ) THEN
       ImportTableP^.ErrorOccured := TRUE;
       SetLengthOf ( s, 0 );
       LogAMessage ( s );
    END;

END TLCSVImport.
