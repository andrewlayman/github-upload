MODULE TLTTable;  (* TASK TABLE REPORT *)


    (*  MODIFICATION HISTORY:
        04-Mar-88 LAA   Copied from the Resource table report, TLRTABLE.
        16-Jun-88 RSC   Added Thermometer support.
        23-Jun-88 LAA   Updated documentation.
        28-Jun-88 EGK   Changed GenerateFileHeaders parameters to look like
                        those in RptCommon.
        05-Jul-88 LAA   Convert data type to export data type when defining
                        the predicate record for a column.
        13-Jul-88 LAA   Put up a message if the current layout doesn't have
                        any columns selected, and abort the report - rather
                        than generating a fatal error.  Sigh.  Bug #8301.
        18-Jul-88 LAA   Well, my fix of 13 July didn't work if you had
                        columns defined, but they had zero length.  So heres
                        a fixed fix (I hope).
        22-Dec-88 LAA   Import Captions rather than TableCaptions, since
                        they're now the same.
        10-Jan-89 RSC   Changed Storage to Space    .
        17-Mar-89 EGK   Put more checking into DoTLTTable to make sure
                        we don't leave the temp file open if the back
                        end (which would close it) isn't going to run.
        20-Mar-89 EGK   Get data types from MagicNum, and use
                        ExportDataType() in ColumnData.
        21-Mar-89 RSC   Get the captions conversion from IntFileIO.
                        Use more code from RptCommon.
        1-May-89  MWP   Allow writing of a SkipRecordType Int file record.
        2-May-89  MWP   Allow writing out ALL task data or task data based
                        on current layout.

        22-May-89 LAA   Fixed bug caused by not initializing the Columns array
                        correctly.  This was causing TLTTable to die, but only
                        when there was a layout which had a column of width 0.
                        The better solution is to pass another parameter to
                        GenerateFileHeaders indicating how many elements of
                        the Columns array are being used.
        24-May-89 LAA   Fixed up the usage of the OverlayContext in the Setup
                        procedure.  It used to specify the drive onto which to
                        write the intermediate file, but Matt changed the
                        usage when he shoud have added a new parameter.
        30-May-89 EGK   Fixed ColumnData() so that it actually uses the
                        font information (it wasn't).
        11-Jul-89 MWP   Changed checking for export mode.
        09-Aug-89 KKC   Add copyright message.
        20-Aug-89 MWP   Parse the context for two entries, the Task context
                        ( typically 'Tasks' retrieved from phrases ), and
                        the report format. The report format tells us
                        whether we are outputting Basic, Baseline, or current
                        Gantt format. If we are outputting Current Gantt
                        we also check to see if the data has been flagged as
                        being re-importable ( via export form. ). If it is,
                        then we must ensure that the Gantt contains the
                        WBS and Parent WBS columns.
        24-Aug-89  MWP  Don't display warning box about not exporting
                        WBS codes if Task report has called us.
        28-Aug-89  KKC  Remove DigestReportHolderRecord and
                        BuildReportHolderRecord from the import statements.
         1-Sep-89  MWP  If the report type is not recognizable, default to
                        reporting on the current gantt layout.
         2-Sep-89  MWP  If exporting, retrieve the ColumnExportWidth.
         4-Sep-89  MWP  If exporting current gantt layout, and baseline is
                        showing, do not export baseline info.
         9-Sep-89  MWP  Code cleanup.
        12-Sep-89  LAA  Removed import of Holder (no longer used).
        22-Sep-89  MWP  Check WBS and Parent WBS column widths on a gantt
                        export. If they are less than WBSLen, display
                        warning box.
        24-Sep-89  MWP  If exporting Gantt columns, and re-importable is
                        set to Yes, use the export column width.
        27-Sep-89  MWP  Removed the check for WBS column lengths, as it
                        is not used.
         9-Oct-89  MWP  Removed text literals.
         6-Aug-90  RSC  Fixed up imports for Andrew's Captions changes.
        14-Sep-90  AJL  This overlay used to crash by calling FatalError
                        if it every inquired about a column number that
                        was not defined (i.e. GetColumnInfo returned FALSE.)
                        Now we don't.
                        We also don't return FALSE if we call GetColumnInfo
                        for a column that is not currently defined.  Only if
                        we don't return and data values.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
        13-Sep-91 LAA   In SetUpColumns, I corrected a latent bug with the
                        CountOfColumns when adding the coding fields.  It was
                        benign, since all widths are pre-initialized to zero.
    *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr, ATaskFlag, ATaskFilter, ATaskFilterSet,
    (* VAR *)               TaskTree,
    (* PROC *)              CheckTaskValid;

FROM Captions       IMPORT
    (* TYPE *)              AColumnInfoChoice, AColumnDataRecord,
                            ASetOfColumnDataFields,
    (* VAR *)               GetColumnValue, GetColumnInfo;

FROM ChartForms     IMPORT
    (* TYPE *)              AChartFormatPtr,
    (* PROC *)              CurrentLayout;

FROM Dialog         IMPORT
   (* TYPE *)               ADialogOption,
   (* PROCS *)              FatalError,
                            MultipleChoiceBox;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile, InterFileOpen,
                            IsImportable;

FROM FileSystem     IMPORT
    (* TYPE *)              Response;

FROM FileAux        IMPORT
    (* PROCS *)             CheckIO;

FROM Gantt          IMPORT
                            AGanttLineType;

FROM IntFileIO      IMPORT
    (* CONST *)             PredicateSubfileNumber,
                            TextType,
                            HeadingRecordType, SkipRecordType,
                            AHeadingRecord, AnIntDataRecord,
    (* PROC *)              WriteIntData,
                            ConvertCaptionsToIntermediate;

FROM LStrings       IMPORT
        (* PROCS *)         SetString, Copy,
                            SetLengthOf,
                            StoC, Compare;

FROM MsgFile        IMPORT
        (* PROCS *)         GetMessage;

FROM Overlays       IMPORT
        (* PROCS *)         OverlayContext, PackageOK;

FROM Progress       IMPORT
        (* TYPE *)          AThermometer,
        (* PROCS *)         CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RecordIO       IMPORT
        (* PROCS *)         WriteRecord;

FROM RptCommon      IMPORT
        (* TYPES *)         AColumn, AGetInfoProc,
        (* PROCS *)         GenerateFileTrailers, GenerateFileHeaders,
                            DoDialog, CreateTheFile, GetMessageWord,
                            CommonCleanup;

FROM Subfiles       IMPORT
    (* PROC *)              StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, ADR;

FROM TaskColNumbers IMPORT
    (* CONST *)             WBSColumn, HighestRootColumn,
                            CodingField1, NumberOfCodingFields;

FROM TempFile       IMPORT
    (* PROC *)              DeleteTempFile;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode,
    (* PROCS *)             ValidateTree, ValidateTreeNode;

FROM Words          IMPORT
        (* PROC *)          ParseString;


CONST
    ModuleNumber            = 23700;  (* For GetMessage *)
    CaptionsModuleNumber    = 19200;
    MAXCARDINAL             = 65535;

    (* DoDialog() message constants:   *)

    NoTasks                 = 10; (* "There are no Tasks." *)
    NoBsLnTasks             = 11; (* "There are no Baseline Tasks." *)
    NoColumns               = 14; (* "There aren't any columns selected on the current layout. " *)

    (* Subfile IO version number:   *)

    VersionNumber           = 1; (* For subfiles *)

    (* Font constants for printing *)

    NormalFont = 0C;
    BoldFont   = 1C;

    Basic        = 1;
    IsBaseline   = 2;
    CurrentGantt = 3;
    ReportGantt  = 4;


VAR
    Columns                 : ARRAY [1..200] OF AColumn;
    CountOfColumns          : CARDINAL;
    Thermometer             : AThermometer;
    BaselineShowing         : BOOLEAN;
    CallerIsExporter        : BOOLEAN;

    ReportFormat            : CARDINAL;




PROCEDURE ColumnData(    TaskNode           : ATreeNode;
                         Task               : ATaskPtr;
                         ColumnID           : CARDINAL;
                         ColumnWidth        : CARDINAL;
                         PlanRow            : BOOLEAN;
                     VAR LDataType          : CARDINAL;
                     VAR DataRecord         : AnIntDataRecord;
                         Font               : CHAR              );

VAR
    Value                   : AColumnDataRecord;
    PlanOrBase              : AGanttLineType;

BEGIN                       (* ColumnData *)

    IF (PlanRow) THEN
        PlanOrBase := Plan;
    ELSE
        PlanOrBase := Baseline;
    END;

    LDataType := MAXCARDINAL;                                 (* 1-May-89 MWP *)
    DataRecord.Font := Font;                (* 5/30/89 EGK *)

    IF (GetColumnValue(TaskNode, Task, ColumnID, PlanOrBase, Value)) THEN
        ConvertCaptionsToIntermediate( Value, ColumnWidth, LDataType, DataRecord );
    END;

END ColumnData;







(*
    Get Task Info

    Preconditions
            > ColumnID  is the column to return information about.

            > InfoChoice is the kind of information you are
              interested in.  See Captions.Def for the choices.

            > Length is the length of the string to return,
              important mostly for Right Justified strings.

    Postconditions
            > If TRUE, InfoValue contains the desired information.
              If a string value is being returned, it may be right
              justified, and is always exactly "Length" bytes long.

            > If FALSE, The column does not exist.      This allows
              looking for information on ALL columns.
*)
PROCEDURE GetTaskInfo(  ColumnID    : CARDINAL;
                        InfoChoice  : AColumnInfoChoice;
                        Length      : CARDINAL;
                    VAR InfoValue   : AColumnDataRecord) : BOOLEAN;
VAR
    NilTask : ATaskPtr;
BEGIN
    NilTask := NIL;
    GetColumnInfo( ATreeNode(NIL),  NilTask,
                   ColumnID,        InfoChoice,
                   Length,          InfoValue );
    RETURN InfoValue.DataFields <> ASetOfColumnDataFields{};
END GetTaskInfo;







 (* GenerateOneTask - create the data records for one task.

        Preconditions  - A valid task node
        Postconditions - one or more data records have been written to the file.
 *)
PROCEDURE GenerateOneTasksData( VAR TaskNode : ATreeNode;
                                VAR Count    : CARDINAL  );

VAR
    Task                    : ATaskPtr;
    FilterSet               : ATaskFilterSet;
    Font                    : CHAR;


    PROCEDURE GenerateARow(    Plan         : BOOLEAN);

    VAR
        DataType,
        Loop                : CARDINAL;
        DataRecord          : AnIntDataRecord;

    BEGIN                   (* GenerateARow *)

        FOR Loop := 1 TO CountOfColumns DO
            IF (Columns[ Loop ].Width > 0) THEN
                ColumnData( TaskNode,
                            Task,
                            Columns[ Loop ].ColumnNumber,
                            Columns[ Loop ].Width,
                            Plan,
                            DataType,
                            DataRecord,
                            Font );
                IF (DataType = MAXCARDINAL) THEN
                    WriteIntData( SkipRecordType, DataRecord );
                ELSE
                    WriteIntData( DataType, DataRecord );
                END;
            END;
        END;

    END GenerateARow;


BEGIN                       (* GenerateOneTasksData *)

    (*<DEBUGGING*)
    ValidateTreeNode(TaskNode);
    (*DEBUGGING>*)

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

    FilterSet := Task^.FilterSet;

    Font     := NormalFont;
    IF ((FilterSet * ATaskFilterSet{Highlight1..Highlight5}) <> ATaskFilterSet{}) THEN
        Font     := BoldFont;
    END;

    INC(Count);
    UpdateThermometer( Thermometer, Count );

    GenerateARow(TRUE);
    IF (BaselineShowing) AND ( NOT CallerIsExporter ) THEN          (* 4-Sep-89 MWP *)
        GenerateARow(FALSE);
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

END GenerateOneTasksData;




PROCEDURE GetWidthAndDecimals(     ColumnNumber : CARDINAL;
                                   WhichWidth   : AColumnInfoChoice;
                               VAR Width        : CARDINAL;
                               VAR Decimals     : CARDINAL  
                              ) : BOOLEAN;
VAR
    DataRecord : AColumnDataRecord;
    ok         : BOOLEAN;
BEGIN
    Width := 0;
    Decimals := 0;

    ok := GetTaskInfo ( ColumnNumber, WhichWidth, 0, DataRecord );
    IF (ok) THEN
        Width        := DataRecord.CardinalValue;
        ok := GetTaskInfo( ColumnNumber, ColumnMaxDecimals, 0, DataRecord );
        IF (ok) THEN
            Decimals     := DataRecord.CardinalValue;
        END;
    END;

    RETURN ok;

END GetWidthAndDecimals;




PROCEDURE DoTLTTable();

VAR
    s,
    Copyright           : ARRAY[0..50] OF CHAR;


    PROCEDURE SetUpColumns ( Choice : CARDINAL );
    VAR
        i, j       : CARDINAL;
        ok         : BOOLEAN;
        CaptionLine,
        WhichCol     : CARDINAL;
        s                   : ARRAY [0..9] OF CHAR;
        RegurgitateAll : BOOLEAN;
    BEGIN

        FOR i := 1 TO HIGH(Columns) DO
            Columns[ i ].Width := 0;  (* RSC 21-Mar-89, for RptCommon *)
        END;

        (* Determine the Task Report type for column definitions. *)
        IF ( Choice = Basic ) THEN
            GetMessageWord( CaptionsModuleNumber + 190, 0, s );
            CaptionLine := CaptionsModuleNumber + 191;
        ELSE
            GetMessageWord( CaptionsModuleNumber + 190, 1, s );
            CaptionLine := CaptionsModuleNumber + 192;
        END;

        RegurgitateAll := FALSE;
        j := 1;

        CountOfColumns := StoC ( s, j );

        IF ( CountOfColumns = 999 ) THEN
            CountOfColumns := HighestRootColumn;
            RegurgitateAll := TRUE;
        END;


        FOR i := 1 TO CountOfColumns DO
            WITH Columns[i] DO
                IF ( RegurgitateAll ) THEN
                   WhichCol := i;
                ELSE
                   GetMessageWord( CaptionLine, i, s );
                   j := 1;
                   WhichCol := StoC ( s, j );
                END;

                ColumnNumber := WhichCol;

                IF ( CallerIsExporter ) THEN                      (* 2-Sep-89 MWP *)
                    ok := GetWidthAndDecimals( WhichCol, ColumnExportWidth,
                                               Width, Decimals );
                ELSE
                    ok := GetWidthAndDecimals( WhichCol, ColumnWidth,
                                               Width, Decimals );
                END;

            END;
        END;

        (* If user has selectged 'All Basic', then after loading the primary
           column data, load in the Aux columns.
        *)
        IF ( Choice = Basic ) THEN
           WhichCol := CodingField1;
           j := CountOfColumns + 1;                            (* 13-Sep-91 *)
           FOR i := j TO j + (NumberOfCodingFields - 1) DO
               WITH Columns[i] DO
                   ColumnNumber := WhichCol;
                   ok := GetWidthAndDecimals( WhichCol, ColumnExportWidth,
                                              Width, Decimals );
                   INC(WhichCol);
                   INC(CountOfColumns);
               END;
           END;
        END;

    END SetUpColumns;


    PROCEDURE AnyBaselineTaskData () : BOOLEAN;
    VAR
        Node                : ATreeNode ;
        BaseFound           : BOOLEAN;
    BEGIN

        BaseFound := FALSE;

        Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);

        WHILE ( NOT BaseFound ) AND (Node <> NIL) DO
            BaseFound := CheckForBsLn ( Node );
            Node := Node^.Methods^.NextForDisplay (Node);
        END;

        RETURN ( BaseFound );

    END AnyBaselineTaskData;

    PROCEDURE CheckForBsLn (VAR TaskNode : ATreeNode) : BOOLEAN;
    VAR
        TaskPtr          : ATaskPtr;
        BaseFound        : BOOLEAN;
    BEGIN
        BaseFound := FALSE;

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        IF ( BaseLineExists IN TaskPtr^.TaskFlags ) THEN
           BaseFound := TRUE;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        RETURN ( BaseFound );

    END CheckForBsLn;


    PROCEDURE Setup() : BOOLEAN;

    VAR
        i, j,
        WBSSize             : CARDINAL;
        Layout              : AChartFormatPtr;
        P                   : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
        s                   : ARRAY [0..9] OF CHAR;
        s1                  : ARRAY [0..19] OF CHAR;
        s2                  : ARRAY [0..19] OF CHAR;
        ok,
        ItsAlive,
        WBSAlive            : BOOLEAN;
        DataRecord          : AColumnDataRecord;

        Loop       : CARDINAL;
    BEGIN
        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            FatalError();
        END;

        Loop := 1;

        ParseString( P^, Loop, s1 );          (* ALLTASKS TASKS *)

        GetMessage( ModuleNumber + 1, s2 );
        (*  "EXPORT" *)

        IF ( Compare ( s1, s2 ) = 0 ) THEN
           CallerIsExporter := TRUE;
        END;

        ParseString( P^, Loop, s1 );

        j := 1;

        ReportFormat := StoC ( s1, j );

        IF ( ReportFormat < 1 ) OR ( ReportFormat > ReportGantt ) THEN
            ReportFormat := ReportGantt;                                (* 1-Sep-89 MWP *)
        END;


        (* Validate the resource tree.  Insure that there ARE some tasks. *)

        ValidateTree(TaskTree);
        IF (TaskTree^.Methods^.GetFirst( TaskTree ) = NIL) THEN
            DoDialog( ModuleNumber + NoTasks, TRUE );
            RETURN FALSE;
        END;

        IF ( ReportFormat = IsBaseline ) THEN
           IF ( NOT AnyBaselineTaskData () ) THEN
              DoDialog( ModuleNumber + NoBsLnTasks, TRUE );
              RETURN FALSE;
           END;
        END;


        IF ( ReportFormat >= CurrentGantt ) THEN       (* 20-Aug-89 MWP *)
           Layout   := CurrentLayout();
           ItsAlive := FALSE;
           WBSAlive := FALSE;

           WITH Layout^ DO                                         (* 18-Jul-88 LAA *)
               FOR i := 1 TO ColumnCount DO
                   IF (ColumnSpec[i].Width > 0) THEN
                       ItsAlive := TRUE;
                       IF ( ColumnSpec[i].ColumnID = WBSColumn ) THEN
                           WBSAlive := TRUE;
                           WBSSize := ColumnSpec[i].Width;
                       END;
                   END;
               END;

               IF (NOT ItsAlive) THEN                                (* 13-Jul-88 LAA *)
                       (* "There aren't any columns selected on the current layout. "*)
                   DoDialog(ModuleNumber + NoColumns, TRUE);
                   RETURN FALSE;
               END;

               IF ( IsImportable ) AND ( ReportFormat <> ReportGantt ) AND
                  ( ( NOT WBSAlive ) ) THEN
                  IF ( NOT NoWBSDialog () ) THEN
                     RETURN FALSE;
                  END;
               END;
           END;


           WITH Layout^ DO                                         (* 18-Jul-88 LAA *)
               FOR i := 1 TO ColumnCount DO
                   IF (ColumnSpec[i].Width > 0) THEN
                       ItsAlive := TRUE;
                   END;
               END;

               IF (NOT ItsAlive) THEN                                (* 13-Jul-88 LAA *)
                       (* "There aren't any columns selected on the current layout. "*)
                   DoDialog(ModuleNumber + NoColumns, TRUE);
                   RETURN FALSE;
               END;
           END;

           CountOfColumns := 0;
           WITH Layout^ DO
               FOR i := 1 TO ColumnCount DO
                   IF (ColumnSpec[i].Width > 0) THEN
                       INC(CountOfColumns);
                       Columns[CountOfColumns].ColumnNumber := ColumnSpec[i].ColumnID;

                       IF ( IsImportable ) AND ( ReportFormat <> ReportGantt ) THEN
                           ok := GetTaskInfo ( ColumnSpec[i].ColumnID,
                                               ColumnExportWidth,
                                               0, DataRecord );
                           Columns[CountOfColumns].Width :=  DataRecord.CardinalValue;
                       ELSE
                           Columns[CountOfColumns].Width := ColumnSpec[i].Width - 1;
                       END;

                       GetMessageWord(CaptionsModuleNumber
                                      + ColumnSpec[i].ColumnID, 10, s);
                       j := 1;
                       Columns[CountOfColumns].Decimals := StoC(s, j);
                   END;
               END;

               FOR i := CountOfColumns+1 TO HIGH(Columns) DO      (* 22-May-89 LAA *)
                   Columns[ i ].Width := 0;  (* RSC 21-Mar-89, for RptCommon *)
               END;
           END;

           BaselineShowing := Layout^.AVPShowing;

        ELSE
           SetUpColumns ( ReportFormat );
        END;

        SetLengthOf ( s1, 0 );

        RETURN ( CreateTheFile( s1 ));

    END Setup;



    PROCEDURE  NoWBSDialog () : BOOLEAN;
    VAR
        Prefix                  : ARRAY [0..255] OF CHAR;
        MenuPrefix              : ARRAY [0..29] OF CHAR;
        Choices                 : ARRAY [0..255] OF CHAR;
        Choice                  : CARDINAL;
        Title                   : ARRAY [0..29] OF CHAR;
        ok                      : BOOLEAN;
    BEGIN

        SetLengthOf ( Title, 0 );

        GetMessage( ModuleNumber + 15, Prefix );
        (*
         You are not exporting the WBS and Parent WBS gantt columns. +&+
         This will prevent proper import of this data.
        *)


        GetMessage( ModuleNumber + 16, MenuPrefix );
        (* "EXPORT ANYWAY" *)

        GetMessage( ModuleNumber + 17, Choices );
        (* "No,Yes" *)

        Choice := 1; (* Default is No *)

        ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, Choice);

        IF ( ok ) THEN
            ok := Choice = 2;
        END;

        RETURN ok;

    END NoWBSDialog;


     (* DoTaskHeader - create the header records, one per task.

            Preconditions  - A valid task node
                             Context is a CARDINAL ID # (unique)
            Postconditions - a header record has been written to the file.
     *)
    PROCEDURE DoTaskHeader( VAR TaskNode   : ATreeNode;
                            VAR ID         : CARDINAL   );

    VAR
        Task           : ATaskPtr;
        DataRecord     : AnIntDataRecord;
        HeadingRecord  : AHeadingRecord;
        DataExists     : BOOLEAN;

    BEGIN                   (* DoTaskHeader *)

      (* Here we act paranoid about the task tree node.  By the time we are
         outputting data, we won't have to worry.
      *)
        CheckTaskValid( TaskNode );

        WITH HeadingRecord DO
            INC( ID );
            UniqueID        :=  ID;
            HeadingDepth    :=  1;  (* just the task name *)
            DataIndentation :=  TaskNode^.Methods^.IndentationLevel( TaskNode );
            Summary         := (TaskNode^.Methods^.FirstChild(       TaskNode ) <> NIL);
        END;
        WriteRecord( InterFile, HeadingRecordType,
                     ADR(HeadingRecord), SIZE(HeadingRecord) );

        WITH DataRecord DO
            Font := 0C;
            Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
            Copy( Task^.taskname, LString );
            DataExists := (Task^.FilterSet *
                           ATaskFilterSet{Highlight1..Highlight5}) <> ATaskFilterSet{};
            IF (DataExists) THEN
                Font := 1C;
            END;
            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
        END;
        WriteIntData( TextType, DataRecord );
        (* errors are checked before writing in the WRITE procedures. *)

    END DoTaskHeader;




     (* Generate task headers for a task dimension *)

    PROCEDURE TaskHeaders( CModuleNumber,
                           HeaderNumber : CARDINAL) : CARDINAL;

    VAR
        ID          : CARDINAL;
        Node        : ATreeNode;

    BEGIN                   (* TaskHeaders *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
        IF (CheckIO( InterFile ) <> done) THEN RETURN 0; END;
        ID   := 0;
        Node := TaskTree^.Methods^.GetFirstVisible( TaskTree );
        WHILE (Node <> NIL) DO
            DoTaskHeader( Node, ID );
            IF (BaselineShowing) AND ( NOT CallerIsExporter ) THEN   (* 4-Sep-89 MWP *)
                DoTaskHeader(Node, ID);
            END;
            Node := Node^.Methods^.NextForDisplay( Node );
        END;
        EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

        RETURN ID;

    END TaskHeaders;



    PROCEDURE GenerateData();

    VAR
        Rows                : CARDINAL;
        TaskNode            : ATreeNode;
        Count               : CARDINAL;
        s                   : ARRAY [0..79] OF CHAR;
        ok                  : BOOLEAN;

    BEGIN                   (* GenerateData *)

        Rows := TaskHeaders( ModuleNumber, 1);
        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;

        GetMessage( ModuleNumber + 6, s ); (* "Tasks' data generated" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );
        IF (CheckIO( InterFile ) = done) THEN
            Count := 0;  (* For Thermometer *)
            TaskNode := TaskTree^.Methods^.GetFirstVisible(TaskTree);
            WHILE (TaskNode <> NIL) DO
                (*<DEBUGGING*)
                ValidateTreeNode(TaskNode);
                (*DEBUGGING>*)
                GenerateOneTasksData(TaskNode, Count);
                TaskNode := TaskNode^.Methods^.NextForDisplay(TaskNode);
            END;
        END;

        DiscardThermometer( Thermometer );

        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;
        EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );

    END GenerateData;


BEGIN                       (* TLTTABLE *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)

    (* Create the first part of the file (the non-data part) *)

    SetLengthOf (s,0);

    IF (NOT Setup()) THEN
        RETURN;
    END;

    IF (GenerateFileHeaders( AGetInfoProc(GetTaskInfo),
                             ModuleNumber + 2,  (* OverallPhrase         *)
                             2,                 (* PredicateHeadingDepth *)
                             ModuleNumber + 3,  (* DomainBase            *)
                             Columns,
                             s )) THEN

        GenerateData();

        (* Clean up the file and exit.  Do not close the file! *)

        IF ((CheckIO( InterFile ) = done) AND GenerateFileTrailers()) THEN
            PackageOK := TRUE;  (* Tell mom that we're OK down here. *)
        END;
    END;

    CommonCleanup();

    IF (NOT PackageOK) AND (InterFileOpen) THEN     (* 3/17/89 EGK *)
        DeleteTempFile (InterFile);
        InterFileOpen := FALSE;
    END;

END DoTLTTable;




BEGIN

    BaselineShowing    := FALSE;
    CallerIsExporter   := FALSE;

    DoTLTTable();

END TLTTable.

