MODULE TLIAss;

    (*
        Import assignment records from a comma delimited export file.

        Handling Errors:

            VerboseErrorHandler is called whenever an error is detected.
            Errors come in different severities and types, and the error
            handler is responsible for logging the errors and deciding the
            TRUE severity of the error.

        Modification History:


         09-Mar-89  MWP  In the beginning...
         27-Jul-89  MWP  Display Messages to inform the user what Import is
                         currently doing. During periods of lengthy processing,
                         this will at least show them that Timeline is alive.
         09-Aug-89  MWP  Allow importing of baseline assignment data.
         10-Aug-89  KKC  Add copyright message.
         27-Aug-89  MWP  Add new method for determining Column ID.
         27-Aug-89  MWP  Use MaxCardinal as flag for deciding whether a
                         column is valid or not.
         27-Aug-89  MWP  Allow reporting of field numbers in error messages.
         29-Aug-89  MWP  Incorporate local task error handler.
          5-Sep-89  MWP  Fixed bug in error reporting.
          6-Sep-89  MWP  When analyzing column's, only digest data pertaining
                         to a controlling column.
         10-Sep-89  MWP  Ignore SkipRecordType when reading intermediate data.
         11-Sep-89  MWP  Changed paramters in call to EndAssEdit.
         19-Sep-89  MWP  Implement break requested processing.
         22-Sep-89  MWP  Track the number of rows processed, as well as the
                         number of rows actually imported.
         22-Sup-89  MWP  Changed the return logic checking of StopImport.
          3-Oct-89  MWP  Removed the call to CleanUp. This is performed
                         at the end of import now, when it is safe to
                         perform.
          4-Oct-89  MWP  Track which assignment we are importing for error or
                          warning messages, so the user knows what record
                          the error occured in.
          9-Oct-89  MWP   Removed text literals.
         16-Oct-89 MWP   Implemented faster searching for finding an existing
                         task to edit.
         21-Feb-90  KKC   Remove import of Timeu.
          9-AUg-90  RSC   Removed planner references.
    *)

FROM AssAcquire     IMPORT
    (* PROC *)              AcquireAss,             AnalyzeAssColumn,
                            ResetDefaultAssColumns, DefaultAssColumn,
                            IsControllingColumn,    AreAllControlsPresent,
                            ResetAllAssignments;

FROM AssChange      IMPORT
                            TaskName,
                            ResourceNm,
    (* PROC *)              DigestAssString,    BeginAssEdit, GetAssColumnID,
                            ChangeAssColumn,    EndAssEdit,
    (* PROC *)              DigestIntAssString;

FROM Allocs         IMPORT
    (* TYPE *)              ATaskStatus, ATaskPtr,
    (* VAR  *)              TaskTree;

FROM AsOf           IMPORT
    (* PROC *)              AsOfDate, SetAsOfDate;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord;

FROM ChartControl   IMPORT
    (* PROC *)              UnSetState,
    (* TYPE *)              AChartState;

FROM Dialog         IMPORT
    (* PROC *)              Burp, Message, Error, FatalError, MessageBox;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               ExportMedia, ExportName, InterFile;

FROM FileAux        IMPORT
    (* PROC *)              DisplayFileError, FileResultMeans,
                            PrepareForIO,     CheckIO;

FROM FileSystem     IMPORT
    (* PROC *)              File,     Response,  Reset,     SetPos, GetPos,
                            ReadChar, SetRead,   Lookup,    Close,
                            Delete,   WriteChar, WriteByte, ReadByte;

FROM AllFormalName   IMPORT
                            PurgeCache;

FROM FormalAssName   IMPORT
                            SetupAssCache,
                            FindAssName,
                            CheckAssName;

FROM ImPorTable      IMPORT
    (* TYPE *)              AImportTable,        AFilePosition,
                            AnStoreFormalNameProc,
    (* CONST *)             ImportOverall,       ImportPredicate,
                            ImportData,
    (* VAR  *)              ImportNote,          ImportLineNumber,
                            ImportFieldNumber,
                            ErrorsHaveOccured,   RowsToImport,
                            FileType,
    (* PROC *)              LogAnError,
                            GetOverallInfo,
                            FindRecord,          GetFilePosition,
                            SetFilePosition,     Advance,
                            DoPredicateSetup,    FlushARecord,
                            AskAlterBaseline;                       (* 9-Aug-89 MWP *)

FROM ImportCommon   IMPORT
    (* VAR   *)             PrintErrorHeader,
                            ImportErrorHandler, AssignmentImport,
                            CompleteBEndImport, StopImport;

FROM IntFileIO      IMPORT
    (* CONST *)             OverallSubfileNumber, PredicateSubfileNumber,
                            TextType,             RealNumberType,
                            CardinalType,         BooleanType,
                            BigStartTimeType,     BigEndTimeType,
                            StartDateType,        EndDateType,
                            EnumeratedType,       PredicateRecordType,
                            HeadingRecordType,    SkipRecordType,
                            AggregatorRecordType, IntegerType,
    (* TYPE *)              AnOverallRecord,      APredicateHeadingRecord,
                            ADomainRecord,        APredicateRecord,
                            ADataType,            AHeadingRecord,
                            AnIntDataRecord,      AFormat,
                            AFormatType,          AnAggregatorRecord,
    (* PROC *)              ReadIntData;

FROM LStrings       IMPORT
    (* PROC *)              SetString,        Fill,
                            LStringToTString, TStringToLString,
                            CtoS,             Procustes,
                            SetLengthOf,      LJust,
                            ConcatLS,         Copy,
                            ConcatS,          Remove,
                            SubStr,           TrimFront,
                            LengthOf,         TrimRear,
                            StoC,             Insert;

FROM Memos          IMPORT
    (* TYPE *)              AMemoRecordPointer,
    (* VAR  *)              MemoTree,
    (* PROC *)              CreateMemo;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage, ConcatMessage, DisplayMessage;

FROM Notices        IMPORT
    (* TYPE *)              AnOccasion, AStep,
    (* PROC *)              Permission, SendNotices;

FROM Overlays     IMPORT
    (* PROC *)              OverlayContext;

FROM Progress      IMPORT
    (* TYPE *)              AThermometer,
    (* PROCS *)             CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat,
    (* VAR  *)              DefaultAmountFormat;

FROM RecordIO       IMPORT
    (* PROC *)              ReadRecord, ReadRecordPreface, ReadRecordBody;

FROM Schedule       IMPORT
    (* VAR  *)              ProjectName,   ProjectMedia,
                            Author,        FullScheduleName,
                            ProjectText,   ConfigSaved,
                            ScheduleSaved, Loaded,
                            RetrievalName,
    (* PROC *)              DisplayScheduleLight;

FROM Subfiles       IMPORT
    (* PROC *)              StartFileInput, StartSubfileInput;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS,
    (* PROC *)              ADR, TSIZE, SIZE;

FROM TaskDictionary IMPORT
    (* PROC *)              CreateWBSCodeDictionary,
                            DeleteWBSCodeDictionary,
                            PutInDict,
                            LoadWBSCodes;

FROM Text           IMPORT
    (* TYPE *)              AText,
    (* PROC *)              LineExists, TextExists, AppendLine, DiscardText,
    (* PROC *)              CopyLine,   Compress,   CreateText, AssignLine;

FROM TimeFormat     IMPORT
    (* PROC *)              DefaultDateAndTimeFormat,
                            TimeToString, DtoS, TimeUtoS;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder;

CONST
    ModuleNumber            = 5600;
    MaxCardinal             = 65535;                              (* 27-Aug-89 MWP *)

VAR
    FieldCount              : CARDINAL;
    FormalColumnNameID      : ARRAY [0..255] OF CARDINAL;

    CurrentIDCol            : CARDINAL;
    DataPos                 : AFilePosition;
    RowsRead                : CARDINAL;                           (* 20-Sep-89 MWP *)
    RowsImported            : CARDINAL;
    Thermometer             : AThermometer;
    ImportTableP            : POINTER TO AImportTable;
    TreeBuilt               : BOOLEAN;                            (* 27-Aug-89 MWP *)


PROCEDURE AssErrorHandler(     Severity        : AnErrorSeverity;
                               ErrorKind       : AKindOfError;
                               ColumnID        : CARDINAL;
                           VAR ErrorText       : ARRAY OF CHAR;
                               MyContext       : ADDRESS
                           ) : BOOLEAN;         (* Continue?         *)
VAR
    s, s1                   : ARRAY [0..255] OF CHAR;
BEGIN

    SetLengthOf ( s, 0 );
    SetLengthOf ( s1, 0 );

    IF ( ImportFieldNumber < MaxCardinal ) THEN                   (* 27-Aug-89 MWP *)

       IF ( LengthOf ( TaskName ) > 0 ) AND
          ( LengthOf ( ResourceNm ) > 0 ) THEN
          Copy ( ResourceNm, s1 );
          ConcatMessage ( s1, ModuleNumber + 2 );
          (*  " ÄÄÄ " *)
          ConcatLS ( s1, TaskName );
       END;

       IF ( NOT FindAssName ( ColumnID, s ) ) THEN
          CtoS ( ImportFieldNumber, s );
       END;
    END;

    RETURN ( ImportErrorHandler ( Severity,
                                  ErrorKind,
                                  ColumnID,
                                  s1,
                                  s ) );
END AssErrorHandler;


PROCEDURE StoreFormalName ( VAR ColumnName : ARRAY OF CHAR;
                                DataType   : CARDINAL );
VAR
    ColumnID   : CARDINAL;
    Dummy      : CARDINAL;
    ok         : BOOLEAN;
    s          : ARRAY [0..255] OF CHAR;
BEGIN

    GetMessage ( ModuleNumber + 4, s );
    (* "Analyzing Column Name "*)
    ConcatLS ( s, ColumnName );
    Message ( s );                                               (* 27-Jul-89 MWP *)

    INC( CurrentIDCol );
    INC( FieldCount );

    IF ( CheckAssName ( ColumnName,
                        Dummy,
                        ColumnID ) ) THEN    (* 27-Aug-89 MWP *)
        FormalColumnNameID[ CurrentIDCol ] := ColumnID;

        ok := IsControllingColumn ( ColumnID );
    ELSE
        FormalColumnNameID[ CurrentIDCol ] := MaxCardinal;
        GetMessage ( ModuleNumber, s );
        (* "Unknown Column Name : " *)
        ConcatLS ( s, ColumnName );
        LogAnError ( s );
    END;

END StoreFormalName;


PROCEDURE ImportAssData  ();
VAR
    Version         : CARDINAL;
    s               : ARRAY [0..255] OF CHAR;
    ok              : BOOLEAN;
BEGIN
    (* Retrieve the overall info *)

    IF ( NOT GetOverallInfo() ) THEN
        RETURN;
    END;

    TreeBuilt :=  SetupAssCache ();

    ok := DoPredicateSetup ( StoreFormalName );

    IF ( TreeBuilt ) THEN
       PurgeCache ();
    END;

    IF ( NOT ok ) THEN
       RETURN;
    END;

    SetLengthOf ( s , 0 );                                        (* 27-Jul-89 MWP *)
    Message ( s );

    IF ( NOT AreAllControlsPresent () ) THEN
        GetMessage ( ModuleNumber + 7, s );
        (* The resource name and task WBS must be present to import assignments. *)
        LogAnError ( s );
        RETURN;
    END;

    IF (NOT StartSubfileInput (InterFile, ImportData, Version)) THEN
        RETURN;
    END;

    GetFilePosition (DataPos);

    GetMessage ( ModuleNumber + 1, s );
    (* "Assignments' Data Imported" *)
    ok := CreateThermometer( Thermometer, 0, 0, s, RowsToImport );

    ok :=  CreateWBSCodeDictionary ();                              (* 16-Oct-89 MWP *)

    IF ( ok ) THEN
       LoadWBSCodes ();
    END;

    LOOP
        INC( ImportLineNumber );

        UpdateThermometer( Thermometer, RowsImported );

        RetrieveAssRecord ();

        INC(RowsImported);

        IF (NOT Advance()) THEN
            EXIT;                   (* All done! *)
        END;

        IF ( StopImport () ) THEN                               (* 20-Sep-89 MWP *)
           EXIT;
        END;
    END;

    DiscardThermometer ( Thermometer );

    DeleteWBSCodeDictionary ();                                     (* 16-Oct-89 MWP *)

END ImportAssData;


PROCEDURE RetrieveAssRecord ();
VAR
    s               : ARRAY [0..255] OF CHAR;
    s1              : ARRAY [0..10] OF CHAR;
    FromNode        : ATreeNode;
    ok              : BOOLEAN;
    AssignmentEntry : CARDINAL;
    BaseLineEntry   : CARDINAL;
BEGIN

    (* First, save the current file position so we can seek to it on the
       second pass. *)

    GetFilePosition (DataPos);

    SetLengthOf ( TaskName, 0 );
    SetLengthOf ( ResourceNm, 0 );

    PrintErrorHeader := TRUE;

    AnalyzePredicates ();

    (* Re-set file position for second pass. *)

    SetFilePosition (DataPos);

    ResetDefaultAssColumns();                                      (* 7-Sep-89 MWP *)

    (* Get a resource node for edit. *)

    IF ( AcquireAss( FromNode,
                     AssignmentEntry,
                     BaseLineEntry,
                     ImportTableP,                                 (* 9-Aug-89 MWP *)
                     AssErrorHandler,
                     NIL ) ) THEN

        BeginAssEdit( FromNode,
                      AssignmentEntry,
                      BaseLineEntry,
                      AskAlterBaseline,                            (* 9-Aug-89 MWP *)
                      ImportTableP,
                      AssErrorHandler,
                      NIL );
    ELSE
        FlushARecord ( FieldCount );
        RETURN;
    END;

    (*  Edit the task. *)
    ImportPredicates ();
    INC(RowsRead);

    ok := EndAssEdit ( FromNode, ImportTableP );                   (* 11-Sep-89 MWP *)

END RetrieveAssRecord;


PROCEDURE AnalyzePredicates ();
VAR
    CurCol              : CARDINAL;
    i                   : CARDINAL;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;
    ColumnID            : CARDINAL;
    ColumnData          : AColumnDataRecord;
BEGIN

    CurCol := 0;

    ImportFieldNumber := 1;                                       (* 27-Aug-89 MWP *)

    FOR i := 1 TO FieldCount DO
        INC( CurCol);

        ReadIntData (Type, Data);

        IF ( Type <> SkipRecordType ) THEN                            (* 10-Sep-89 MWP *)
            ColumnID := FormalColumnNameID[ CurCol ];

            IF ( ColumnID < MaxCardinal ) THEN                        (* 27-Aug-89 MWP *)
                IF ( IsControllingColumn ( ColumnID ) ) THEN          (* 6-Sep-89 MWP *)
                   IF ( DigestIntAssString( ColumnID,
                                            Type,
                                            Data,
                                            DefaultAmountFormat,
                                            ColumnData,
                                            AssErrorHandler, NIL )) THEN
                       AnalyzeAssColumn( ColumnID, ColumnData );
                   END;
                END;
            END;
        END;
        INC(ImportFieldNumber);                                  (* 27-Aug-89 MWP *)
    END;

    ImportFieldNumber := MaxCardinal;                             (* 27-Aug-89 MWP *)
END AnalyzePredicates;


PROCEDURE ImportPredicates ();
VAR
    CurCol              : CARDINAL;
    i                   : CARDINAL;
    Type                : CARDINAL;
    ColumnID            : CARDINAL;
    Data                : AnIntDataRecord;
    ColumnData          : AColumnDataRecord;
    ok                  : BOOLEAN;

BEGIN

    CurCol := 0;

    ImportFieldNumber := 1;                                       (* 27-Aug-89 MWP *)

    FOR i := 1 TO FieldCount DO
        INC( CurCol);

        ReadIntData (Type, Data);

        IF ( Type <> SkipRecordType ) THEN                          (* 10-Sep-89 MWP *)
           ColumnID := FormalColumnNameID[ CurCol ];

           IF ( ColumnID < MaxCardinal ) THEN                        (* 27-Aug-89 MWP *)
              IF (DigestIntAssString( ColumnID,
                                      Type,
                                      Data,
                                      DefaultAmountFormat,
                                      ColumnData,
                                      AssErrorHandler, NIL )) THEN
                  ok := ChangeAssColumn( ColumnID, ColumnData );
              END;
           END;
        END;
        INC(ImportFieldNumber);                                   (* 27-Aug-89 MWP *)
    END;

    ImportFieldNumber := MaxCardinal;                             (* 27-Aug-89 MWP *)
END ImportPredicates;


PROCEDURE ImportAssBody();
VAR
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    ResetAllAssignments ();                                        (* 7-Sep-89 MWP *)

    ImportAssData ();

END ImportAssBody;

BEGIN

    FieldCount         := 0;
    CurrentIDCol       := 0;
    ImportLineNumber   := 0;
    ImportFieldNumber  := MaxCardinal;                            (* 27-Aug-89 MWP *)
    RowsToImport       := 0;
    RowsImported       := 0;
    RowsRead           := 0;
    ErrorsHaveOccured  := FALSE;

    SetLengthOf ( TaskName, 0 );
    SetLengthOf ( ResourceNm, 0 );

    ImportTableP := OverlayContext();

    ImportAssBody();

    IF ( ErrorsHaveOccured ) THEN
       ImportTableP^.ErrorOccured := TRUE;
    END;

    CompleteBEndImport ( RowsImported, RowsRead, AssignmentImport );

END TLIAss.
