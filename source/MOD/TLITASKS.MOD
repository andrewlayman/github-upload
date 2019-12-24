MODULE TLITasks;

    (*
        Import task records from a Intermediate file.

        Handling Errors:

            VerboseErrorHandler is called whenever an error is detected.
            Errors come in different severities and types, and the error
            handler is responsible for logging the errors and deciding the
            TRUE severity of the error.

        Modification History:


         09-Mar-89  MWP  In the beginning...
         17-Mar-89  MWP  Massive changes to incorporate reading from
                         the Intermediate file format.
         26-Jun-89  LAA  Imported Space to resolve another of those nagging
                         version conflict errors.
         10-Jul-89  MWP  Some cleanup of module, and implement attempt at
                         recovery from receiving a bad data row identifier.
         27-Jul-89  MWP  Display Messages to inform the user what Import is
                         currently doing. During periods of lengthy processing,
                         this will at least show them that Timeline is alive.
         10-Aug-89  KKC  Add copyright message.
         27-Aug-89  MWP  Add new method for determining Column ID.
         27-Aug-89  MWP  Use MaxCardinal as flag for deciding whether a
                         column is valid or not.
         27-Aug-89  MWP  Allow reporting of field numbers in error messages.
         29-Aug-89  MWP  Incorporate local task error handler.
         30-Aug-89  MWP  Better error and message reporting.
          5-Sep-89  MWP  Fixed bug in error reporting.
          6-Sep-89  MWP  When analyzing column's, only digest data pertaining
                         to a controlling column.
         10-Sep-89  MWP  Ignore SkipRecordType when reading intermediate data.
         12-Sep-89  MWP  Don't ignore SkipRecordTypes totally when analyzing
                         record data.
         14-Sep-89  MWP  Check for orphan tasks after task import, and place at
                         end of current tree.
         19-Sep-89  MWP  Implement break requested processing.
         22-Sup-89  MWP  Track the number of rows processed, as well as the
                         number of rows actually imported.
         22-Sup-89  MWP  Changed the return logic checking of StopImport.
          3-Oct-89  MWP  Removed the Task sanitize routine, as it was being
                         at the end of import now, when it is safe to
                         perform.
          4-Oct-89  MWP  Track which task we are importing for error or
                         warning messages, so the user knows what record
                         the error occured in.
         16-Oct-89 MWP   Implemented faster searching for finding an existing
                         task to edit.
         21-Feb-90 KKC   Remove import of Timeu.
         07-Jun-90 AJL   Remove import of Planner. 
    *)

FROM Allocs         IMPORT
    (* CONST *)             TskNmLen,
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

FROM Dispatcher     IMPORT
    (* PROC *)              Dispatch;

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

FROM FormalTaskName  IMPORT
                            SetupTaskCache,
                            FindTaskName,
                            CheckTaskName;

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
                            AskAlterBaseline;

FROM ImportCommon   IMPORT
    (* CONST *)             TaskImport,
    (* VAR   *)             PrintErrorHeader,
    (* PROC *)              ImportErrorHandler,
                            CompleteBEndImport, StopImport;


FROM IntFileIO      IMPORT
    (* CONST *)             OverallSubfileNumber, PredicateSubfileNumber,
                            TextType,             RealNumberType,
                            IntegerType,          CardinalType,
                            BooleanType,          BigStartTimeType,
                            BigEndTimeType,       StartDateType,
                            EndDateType,          EnumeratedType,
                            PredicateRecordType,  HeadingRecordType,
                            SkipRecordType,       AggregatorRecordType,
    (* TYPE *)              AnOverallRecord,      APredicateHeadingRecord,
                            ADomainRecord,        APredicateRecord,
                            ADataType,            AHeadingRecord,
                            AnIntDataRecord,      AFormat,
                            AFormatType,          AnAggregatorRecord,
    (* PROC *)              ReadIntData;

FROM LStrings       IMPORT
    (* PROC *)              LStringToTString, TStringToLString,
                            SetString,        Fill,
                            SetLengthOf,      ConcatLS,
                            Copy,             ConcatS,
                            Remove,           LengthOf,
                            CtoS,             Procustes,
                            LJust,            SubStr,
                            TrimFront,        TrimRear,
                            StoC,             Insert ;

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

FROM Space          IMPORT
    (* PROC *)              Available;

FROM Subfiles       IMPORT
    (* PROC *)              StartFileInput, StartSubfileInput;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS,
    (* PROC *)              ADR, TSIZE, SIZE;

FROM TaskAcquire    IMPORT
    (* CONST *)             DefaultTaskAction,
    (* PROC *)              AnalyzeTaskColumn,       AcquireTask,
                            ResetDefaultTaskColumns, DefaultTaskColumn,
                            IsControllingColumn;


FROM TaskChange     IMPORT
    (* VAR *)               CurrentTskNm,        OrphanNode,
    (* PROC *)              DigestIntTaskString, BeginTaskEdit,
                            GetTaskColumnID,     ChangeTaskColumn,
                            EndTaskEdit,         SanitizeTask;

FROM TaskDictionary IMPORT
    (* PROC *)              CreateWBSCodeDictionary,
                            DeleteWBSCodeDictionary,
                            PutInDict,
                            LoadWBSCodes;



FROM Text           IMPORT
    (* TYPE *)              AText,
    (* PROC *)              LineExists, TextExists,
                            AppendLine, DiscardText,
                            CopyLine,   Compress,
                            CreateText, AssignLine;

FROM TimeFormat     IMPORT
    (* PROC *)              DefaultDateAndTimeFormat,
                            TimeToString, DtoS, TimeUtoS;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder;

CONST
    ModuleNumber            = 6200;
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


PROCEDURE TaskErrorHandler(    Severity        : AnErrorSeverity;
                               ErrorKind       : AKindOfError;
                               ColumnID        : CARDINAL;
                           VAR ErrorText       : ARRAY OF CHAR;
                               MyContext       : ADDRESS
                           ) : BOOLEAN;         (* Continue?         *)
VAR
    s, s1                   :   ARRAY [0..255] OF CHAR;
BEGIN

    SetLengthOf ( s, 0 );
    SetLengthOf ( s1, 0 );

    IF ( ImportFieldNumber < MaxCardinal ) THEN                   (* 27-Aug-89 MWP *)
       IF ( LengthOf ( CurrentTskNm ) > 0 ) THEN
          Copy ( CurrentTskNm, s1 );
       END;

       IF ( NOT FindTaskName ( ColumnID, s ) ) THEN
          CtoS ( ImportFieldNumber, s );
       END;
    END;

    RETURN ( ImportErrorHandler ( Severity,
                                  ErrorKind,
                                  ColumnID,
                                  s1,
                                  s ) );

END TaskErrorHandler;


PROCEDURE StoreFormalName ( VAR ColumnName : ARRAY OF CHAR;
                                DataType   : CARDINAL );
VAR
    ColumnID   : CARDINAL;
    Dummy      : CARDINAL;
    s          : ARRAY [0..255] OF CHAR;
BEGIN

    GetMessage ( ModuleNumber + 4, s );
    ConcatLS ( s, ColumnName );
    Message ( s );                                               (* 27-Jul-89 MWP *)

    INC( CurrentIDCol );
    INC( FieldCount );

    IF ( CheckTaskName ( ColumnName,
                         Dummy,
                         ColumnID ) ) THEN    (* 27-Aug-89 MWP *)
        FormalColumnNameID[ CurrentIDCol ] := ColumnID;

    ELSE
        FormalColumnNameID[ CurrentIDCol ] := MaxCardinal;
        GetMessage ( ModuleNumber, s );
        (* "Unknown Column Name : " *)
        ConcatLS ( s, ColumnName );
        LogAnError ( s );
    END;

END StoreFormalName;


PROCEDURE ImportTaskData  ();
VAR
    Version         : CARDINAL;
    s               : ARRAY [0..255] OF CHAR;
    ok              : BOOLEAN;
BEGIN
    (* Retrieve the overall info *)

    IF ( NOT GetOverallInfo() ) THEN
       RETURN;
    END;

    TreeBuilt :=  SetupTaskCache ();

    ok := DoPredicateSetup ( StoreFormalName );

    IF ( TreeBuilt ) THEN
       PurgeCache ();
    END;

    IF ( NOT ok ) THEN
       RETURN;
    END;

    SetLengthOf ( s , 0 );                                        (* 27-Jul-89 MWP *)
    Message ( s );

    IF (NOT StartSubfileInput (InterFile, ImportData, Version)) THEN
        RETURN;
    END;

    GetFilePosition (DataPos);

    GetMessage ( ModuleNumber + 1, s );
    (* "Tasks' Data Imported" *)
    ok := CreateThermometer( Thermometer, 0, 0, s, RowsToImport );

    ok :=  CreateWBSCodeDictionary ();                              (* 16-Oct-89 MWP *)

    IF ( ok ) THEN
       LoadWBSCodes ();
    END;

    LOOP
        INC( ImportLineNumber );

        UpdateThermometer( Thermometer, RowsImported );

        RetrieveTaskRecord ();

        INC(RowsImported);

        IF (NOT Advance()) THEN
            EXIT;                   (* All done! *)
        END;

        IF ( StopImport () ) THEN                               (* 20-Sep-89 MWP *)
           EXIT;
        END;
    END;

    IF ( OrphanNode <> NIL ) THEN
        OrphanNode^.Methods^.DeList (OrphanNode);
        TaskTree^.Methods^.AddLast (TaskTree, OrphanNode);
    END;

    DiscardThermometer ( Thermometer );

    DeleteWBSCodeDictionary ();                                     (* 16-Oct-89 MWP *)

END ImportTaskData;


PROCEDURE RetrieveTaskRecord ();
VAR
    s          : ARRAY [0..255] OF CHAR;
    s1         : ARRAY [0..10] OF CHAR;
    FromNode   : ATreeNode;
    ok         : BOOLEAN;
BEGIN

    (* First, save the current file position so we can seek to it on the
       second pass. *)

    GetFilePosition (DataPos);

    SetLengthOf ( CurrentTskNm, 0 );

    PrintErrorHeader := TRUE;

    AnalyzePredicates ();

    (* Re-set file position for second pass. *)

    SetFilePosition (DataPos);

    (* Get a task to edit. *)

    IF (AcquireTask(   FromNode, DefaultTaskAction, TaskErrorHandler, NIL )) THEN
        BeginTaskEdit( FromNode,
                       TaskErrorHandler,
                       NIL,
                       AskAlterBaseline,
                       ImportTableP );

    ELSE
        FlushARecord ( FieldCount );
        RETURN;
    END;

    (*  Edit the task. *)
    ImportTaskPredicates ();
    INC(RowsRead);

    ok := EndTaskEdit();

    ok := PutInDict ( FromNode );                                   (* 16-Oct-89 MWP *)
END RetrieveTaskRecord;


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

        ColumnID := FormalColumnNameID[ CurCol ];

        IF ( ColumnID < MaxCardinal ) THEN                        (* 27-Aug-89 MWP *)
            IF ( IsControllingColumn ( ColumnID ) ) THEN          (* 6-Sep-89 MWP *)
                 IF ( Type <> SkipRecordType ) THEN                        (* 10-Sep-89 MWP *)
                    IF ( DigestIntTaskString( ColumnID,
                                              Type,
                                              Data,
                                              DefaultAmountFormat,
                                              ColumnData,
                                              TaskErrorHandler, NIL )) THEN
                        AnalyzeTaskColumn( ColumnID, ColumnData );
                    END;
                 ELSE
                     SetLengthOf ( ColumnData.StringValue, 0 );
                     AnalyzeTaskColumn( ColumnID, ColumnData );
                 END;
            END;
        END;
        INC(ImportFieldNumber);                                  (* 27-Aug-89 MWP *)
    END;

    ImportFieldNumber := MaxCardinal;                             (* 27-Aug-89 MWP *)
END AnalyzePredicates;


PROCEDURE ImportTaskPredicates ();
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

        IF ( Type <> SkipRecordType ) THEN                           (* 10-Sep-89 MWP *)
           ColumnID := FormalColumnNameID[ CurCol ];

           IF ( ColumnID < MaxCardinal ) THEN                        (* 27-Aug-89 MWP *)
              IF (DigestIntTaskString( ColumnID,
                                       Type,
                                       Data,
                                       DefaultAmountFormat,
                                       ColumnData,
                                       TaskErrorHandler, NIL )) THEN
                  ok := ChangeTaskColumn( ColumnID, ColumnData );
              END;
           END;
        END;
        INC(ImportFieldNumber);                                   (* 27-Aug-89 MWP *)
    END;

    ImportFieldNumber := MaxCardinal;                             (* 27-Aug-89 MWP *)
END ImportTaskPredicates;


PROCEDURE ImportTaskBody();
VAR
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    ImportTaskData ();

END ImportTaskBody;

BEGIN

    FieldCount         := 0;
    CurrentIDCol       := 0;
    ImportLineNumber   := 0;
    ImportFieldNumber  := MaxCardinal;                            (* 27-Aug-89 MWP *)
    RowsToImport       := 0;
    RowsImported       := 0;
    RowsRead           := 0;
    ErrorsHaveOccured  := FALSE;

    SetLengthOf ( CurrentTskNm, 0 );

    ImportTableP := OverlayContext();

    ImportTaskBody();

    IF ( ErrorsHaveOccured ) THEN
       ImportTableP^.ErrorOccured := TRUE;
    END;

    CompleteBEndImport ( RowsImported, RowsRead, TaskImport );

END TLITasks.
