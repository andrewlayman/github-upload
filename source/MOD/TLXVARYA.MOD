MODULE TLXVaryA;  (* Export Resource Varying Assignments *)


(*V1=TRACE*)


  (* TL X Vary A - Export Resource Varying Assignments

        MODIFICATION HISTORY:

        RSC  5/22/88   First version, from Tl4.02 TLXRSASS
        AJL  8-Apr-91  Get error message 24613 from phrases file.
        AJL 17-Jul-91  Remove an extra call to CreateTheFile.  Bug 4783.
        LAA  4-Feb-92  Changed to be compatible with the changes to
                       VaryAssgn, making the Rate a REAL.
   *)

FROM Allocs        IMPORT
        (* CONST *)     WBSLine,
        (* TYPE *)      ATaskFilter, ATaskFilterSet, ATaskPtr,
        (* VARS *)      TaskTree,
        (* PROC *)      CheckTaskValid, GetCodingField;

FROM Assignments   IMPORT
        (* TYPE *)      AnAssignmentRecord,
                        AnAssignmentArray;

FROM BigTimeU      IMPORT
    (* TYPE *)          ABigTime,
    (* VAR *)           MINBIGTIME, MAXBIGTIME;

FROM Captions      IMPORT
    (* TYPE *)          AColumnDataRecord, AColumnInfoChoice;

FROM ColData                IMPORT
    (* TYPE *)                  AColumnType;            (* 26-Sep-90 PFG  *)

FROM Dialog        IMPORT
    (* PROC *)         FatalError, Error;

FROM ExportLinkage IMPORT
    (* VAR *)           InterFile, InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      File,    Response;

FROM FileAux       IMPORT
        (* PROCS *)     CheckIO, DisplayFileError;

FROM Filter1       IMPORT
        (* PROCS *)     AssignmentFiltersPassed;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle,
        (* PROC *)      ReleaseUnchangedObject, LockObjectArray,
                        DiscardExtObject;

FROM FormatCommon  IMPORT
    (* PROC *)         ColumnInfo, GetValueInfo;

FROM GaGa          IMPORT
    (* PROC *)         GetGaGaMessage;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType,
                        CardinalType, BooleanType,
                        HeadingRecordType, SkipRecordType,
    (* TYPE *)          AHeadingRecord, AnIntDataRecord,
    (* PROC *)          WriteIntData,
                        ConvertCaptionsToIntermediate;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS,
                        StoC, ConcatS, TrimFront, Compare;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage;

FROM Overlays      IMPORT
        (* VARS  *)     PackageOK,
        (* PROCS *)     OverlayContext;

FROM Progress      IMPORT
        (* TYPE *)      AThermometer,
        (* PROCS *)     CreateThermometer, UpdateThermometer,
                        DiscardThermometer;

FROM RecordIO      IMPORT
        (* PROCS *)     WriteRecord;

FROM RptCommon     IMPORT
        (* TYPES *)     AColumn, AGetInfoProc,
        (* PROCS *)     GenerateFileTrailers,
                        GenerateFileHeaders,
                        CreateTheFile,
                        CommonCleanup;

FROM RsrcMod       IMPORT
        (* TYPE  *)     AResourcePointer,
                        AResourceType,
        (* PROC *)      CheckResourceValid;

FROM Space          IMPORT
    (* PROCS *)             HeapAvailable;

FROM Subfiles      IMPORT
        (* PROCS *)     StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADR, ADDRESS;

FROM TempFile      IMPORT
    (* PROC *)           DeleteTempFile;

FROM Timei         IMPORT
    (* TYPE *)         ADate;

FROM TimeFormat    IMPORT
    (* TYPE *)         ADateDisplayOption,
    (* VAR *)          DefaultDateOption, DefaultDateFormat,
                       DefaultTimeFormat, DefaultDateAndTimeFormat,
    (* PROC *)         TimeStringLength;

FROM TimeXlate      IMPORT
    (* PROC *)          CalendarTimeToBigTime;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATreeNode,
        (* PROCS *)     ValidateTree;

FROM Words          IMPORT
        (* PROC *)      ParseString;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnList,
    (* PROC *)                  NumberOfRatesInList, GetVaryingAssgnListEntry;

(*<TRACE
FROM Tracer IMPORT PrintString, EndTrace;
VAR
    TraceS, TraceS2 : ARRAY [0..255] OF CHAR;
TRACE>*)


TYPE
    AssDataPtr         =  POINTER TO AnExportRecord;

    AnExportRecord  =  RECORD
                          Resource       : AResourcePointer;
                          PlanAssign,
                          BsLnAssign     : AnAssignmentRecord;
                          NextRecord     : AssDataPtr;
                       END;

CONST   ModuleNumber     = 30300;  (* For GetMessage *)
        OverallPhrase    = ModuleNumber +  9;      (* Phrase describing the table. *)
        ColumnBaseMessage= ModuleNumber + 10 - 1;  (* Phrases that define columns. *)
        DomainBaseMessage= ModuleNumber + 30;      (* Phrase defining table type. *)

        (* Subfile IO version number:   *)

        VersionNumber    = 1; (* For subfiles *)

        NormalFont = 0C;
        BoldFont   = 1C;

        OneHundred = 100.0;
        Zero       = 0.0;

            (* Identifying numbers for each column. *)

        TaskNameColumn     = 1;
        WBSColumn          = 2;
        ResourceNameColumn = 3;
        StartDateColumn    = 4;
        EndDateColumn      = 5;
        WorkRateColumn     = 6;

        MaxReportColumns   = 6;

TYPE
    AColumnArray = ARRAY [1..MaxReportColumns] OF AColumn;

VAR
    Columns      : AColumnArray;

    Thermometer  : AThermometer;

    FirstDataRecordPtr   : AssDataPtr;

    CallerIsExporter        : BOOLEAN;


PROCEDURE FileComplaint();
VAR
    s : ARRAY [0..51] OF CHAR;
BEGIN
    GetMessage(24613,s);               (* "Export Interpass File" *)
    DisplayFileError(InterFile,s);
END FileComplaint;





(*
    Get Ass Info

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

                        > If FALSE, The column does not exist.  This allows
                          looking for information on ALL columns.
*)
PROCEDURE GetVaryAInfo   (     ColumnID      : CARDINAL;
                               InfoChoice    : AColumnInfoChoice;
                               Length        : CARDINAL;
                           VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > MaxReportColumns) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( ColumnBaseMessage,
                    ColumnID,
                    MaxReportColumns,
                    InfoChoice, 
                    Length, 
                    NotEditableColumn,          (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END GetVaryAInfo;








(*
    Get Ass Value

        Preconditions
                        > Resource is a pointer to a resource record.

                        > EndDate and StartDate are dates, with
                          StartDate < EndDate, and StartDate = the
                          EndDate the last time this procedure was 
                          called for this resource.

                        > ColumnID  is the column to return information about.

        Postconditions
                        > If TRUE, Value contains the desired information.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE GetVaryAValue(       Task         : ATaskPtr;
                               Resource     : AResourcePointer;
                               StartDate,
                               EndDate      : ABigTime;
                               WorkRate     : REAL;
                               ColumnID     : CARDINAL;
                           VAR Value        : AColumnDataRecord)
                                                              : BOOLEAN;
VAR
    ok                  : BOOLEAN;
BEGIN

    ok  := TRUE;

    WITH Value DO
        GetValueInfo( ColumnBaseMessage + ColumnID, DataType, DataFields );
        CASE ColumnID OF
          TaskNameColumn :
                Copy( Task^.taskname, StringValue );
        | WBSColumn :
                GetCodingField (Task^, WBSLine, StringValue);
        | ResourceNameColumn :
                Copy( Resource^.Name, StringValue );
        | StartDateColumn :
                BigTimeValue  := StartDate;
        | EndDateColumn :
                BigTimeValue  := EndDate;
        | WorkRateColumn  :
                RealValue :=     WorkRate / OneHundred;

        ELSE
            FatalError();  (* New column added? *)
        END;
    END;

    RETURN ok;

END GetVaryAValue;



















 (* Column Data - Given a resource, date range and rate,
                  return a single data item.

        Preconditions  - 
                        > Resource is a pointer to a resource record.

                        > EndDate and StartDate are dates, with
                          StartDate < EndDate, and StartDate = the
                          EndDate the last time this procedure was 
                          called for this resource.

                        > Column is the column number, one of the constants
                                   defined above.
                        > Width  is the maximum width of the resulting
                                   (string) field.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData (     Task         : ATaskPtr;
                           Resource     : AResourcePointer;
                           StartDate,
                           EndDate      : ABigTime;
                           WorkRate     : REAL;
                           Column   : CARDINAL;
                           Width    : CARDINAL; (* for strings only. *)
                       VAR DataType : CARDINAL;
                       VAR TheData  : AnIntDataRecord;
                           Font     : CHAR);
VAR
    Value   : AColumnDataRecord;
BEGIN

    DataType := MAX(CARDINAL);        (* 1-May-89 MWP *)

    IF (GetVaryAValue( Task, Resource, StartDate, EndDate, WorkRate,
                     Column, Value)) THEN
        TheData.Font := Font;           (* 5/30/89 EGK *)
        ConvertCaptionsToIntermediate( Value, Width, DataType, TheData );
    END;

END ColumnData;




TYPE
    ARowOutputProc = PROCEDURE ( ATaskPtr, AResourcePointer,
                                 ABigTime, ABigTime, REAL,
                                 ADDRESS );

    (* EnumerateVaryingAssignments -- Enumerate each of the 
         varying assignments of the passed assignment, calling
         the Output procedure for each one (whose rate is > 0). *)


PROCEDURE EnumerateVaryingAssignments(
                             Task       : ATaskPtr;
                             Resource   : AResourcePointer;
                         VAR Assignment : AnAssignmentRecord;
                             Output     : ARowOutputProc;
                             Context    : ADDRESS );
VAR
    i                  : CARDINAL;
    VaryingAssgnList   : AVaryingAssgnList;
    StartDate, EndDate : ADate;
    BigStartDate, BigEndDate : ABigTime;
    Rate               : REAL;
BEGIN
        (* During this procedure, we convert dates to BigTimes so that
           we can get a step ahead on eventual conversion to using
           BigTimes throughout TL.  The output format will not have
           to change.  *)

    VaryingAssgnList := Assignment.VaryingAssignment;

    IF (VaryingAssgnList <> AVaryingAssgnList(NIL)) THEN
        i := 1;
        WHILE GetVaryingAssgnListEntry(VaryingAssgnList, i,
                                       StartDate,EndDate,Rate) DO
            IF (Rate <> Zero) THEN
                CalendarTimeToBigTime( StartDate, TRUE,  BigStartDate );
                CalendarTimeToBigTime( EndDate,   FALSE, BigEndDate );
                Output(Task, Resource,
                       BigStartDate, BigEndDate, Rate, Context );
            END;
            INC(i);
        END;
    END;
END EnumerateVaryingAssignments;


    (*  Enumerate all the rows of output data.
        Call the Output procedure for each row of data. *)



PROCEDURE EnumerateRows(     Output     : ARowOutputProc;
                             Context    : ADDRESS );
VAR
    TaskNode       : ATreeNode;
    Count,i,Loop   : CARDINAL;
    Task           : ATaskPtr;
    DataRecord     : AnIntDataRecord;
    Resource       : AResourcePointer;
    AssignmentArray: AnAssignmentArray;
    FiltersPassed  : ATaskFilterSet;
    DataType       : CARDINAL;
    ThisAssignment : AnExtHandle;
    Assignment     : AnAssignmentRecord;

BEGIN
    TaskNode := TaskTree^.Methods^.GetFirstVisible( TaskTree );

    WHILE (TaskNode <> NIL) DO

        CheckTaskValid( TaskNode );

        Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        ThisAssignment := Task^.Plan.Assignments;

        IF (ThisAssignment <> AnExtHandle(NIL)) THEN
            Count := LockObjectArray( ThisAssignment, AssignmentArray, TSIZE(AnAssignmentRecord));
            FOR i := 1 TO Count DO
                Assignment := AssignmentArray^[i-1];
                Resource   := Assignment.Resource;
                IF (Resource^.Type <> AccountingOnly) THEN
                    FiltersPassed := AssignmentFiltersPassed( TaskNode, Assignment );
                    IF (Selected IN FiltersPassed) THEN
                        EnumerateVaryingAssignments(Task,Resource,Assignment,
                                                    Output, Context );
                    END;
                END;
            END;
            ReleaseUnchangedObject( ThisAssignment );
        END;
        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        TaskNode := TaskNode^.Methods^.NextForDisplay( TaskNode );
    END;

END EnumerateRows;






  (* Generate the headers for the assignment records attached to this task. *)


PROCEDURE WriteRowHeader( Task : ATaskPtr;
                          Resource : AResourcePointer;
                          StartDate, EndDate : ABigTime;
                          Level    : REAL;
                          Context  : ADDRESS);
VAR
    ID : POINTER TO CARDINAL;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    s              : ARRAY [0..255] OF CHAR;
BEGIN
    ID := Context;
    INC(ID^);

    WITH HeadingRecord DO
        UniqueID        :=  ID^;
        HeadingDepth    :=  1;  (* just the assignment name *)
        DataIndentation :=  0;
        Summary         :=  FALSE;
    END;
    WriteRecord( InterFile, HeadingRecordType,
                 ADR(HeadingRecord), SIZE(HeadingRecord) );
    WITH DataRecord DO
        Font := 1C;
        Copy( Task^.taskname, s );
        TrimRear(s);
        ConcatS(  s, "/" );
        ConcatLS( s, Resource^.Name );
        TrimRear(s);
        Copy( s, LString );
    END;
    WriteIntData( TextType, DataRecord );
END WriteRowHeader;




    (* Generate the headers for the tabular dimension. *)

PROCEDURE GenerateAssHeaders( HeaderNumber : CARDINAL ) : CARDINAL;
VAR
    ID          : CARDINAL;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );

    IF (CheckIO( InterFile ) <> done) THEN
        RETURN 0;
    END;

    ID := 0;
    EnumerateRows( WriteRowHeader, ADR(ID));

    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

    RETURN ID;
END GenerateAssHeaders;







TYPE 
    AColumnWidthCheckingRecord = RECORD
                                     Columns  : AColumnArray;
                                     CheckSet : BITSET;
                                 END;



PROCEDURE CheckColumnWidths( Task : ATaskPtr;
                             Resource : AResourcePointer;
                             StartDate, EndDate : ABigTime;
                             Level    : REAL;
                             Context  : ADDRESS);
CONST
    OutputFont = NormalFont;
VAR
    CheckingContextRecord : POINTER TO AColumnWidthCheckingRecord;
    i              : CARDINAL;
    DataType       : CARDINAL;
    CurrentWidth   : CARDINAL;
    DataRecord     : AnIntDataRecord;
BEGIN
    CheckingContextRecord := Context;

    WITH CheckingContextRecord^ DO
        FOR i := 1 TO MaxReportColumns DO
            IF (i IN CheckingContextRecord^.CheckSet) THEN
                ColumnData( Task, Resource,
                            StartDate, EndDate, Level,
                            Columns[ i ].ColumnNumber,
                            255 (* Width *),
                            DataType,
                            DataRecord,
                            OutputFont);
                    (* This procedure only works for text
                    columns! *)
                IF (DataType = TextType) THEN
                    TrimRear(DataRecord.LString);
                    CurrentWidth := LengthOf(DataRecord.LString);
                    IF (CurrentWidth > Columns[i].Width) THEN
                        Columns[i].Width := CurrentWidth;
                    END;
                END;
            END;
        END;
    END;
END CheckColumnWidths;


            (* How wide should name columns be?   Fill in the 
               maximum string width found for all checked columns. *)


PROCEDURE GetNameColumnWidths( VAR Columns : AColumnArray;
                                   CheckSet : BITSET );
CONST
    MinWidth   = 5;
VAR
    ContextRecord  : AColumnWidthCheckingRecord;
    i              : CARDINAL;
BEGIN
    FOR i := 1 TO MaxReportColumns DO
        IF (i IN CheckSet) THEN
            Columns[i].Width := MinWidth;
        END;
    END;

        (* Search all the rows of the table for the widest elements
           in each column. *)

    ContextRecord.Columns  := Columns;
    ContextRecord.CheckSet := CheckSet;

    EnumerateRows( CheckColumnWidths, ADR(ContextRecord) );

    Columns  := ContextRecord.Columns;

END GetNameColumnWidths;


    (* SetUpColumns -- Determine how wide each column should be,
                       and the decimal places. *)


PROCEDURE SetUpColumns();
VAR
    i          : CARDINAL;
    TaskNameWidth, WBSWidth, ResourceNameWidth,
    DateWidth  : CARDINAL;   (* How wide should date columns be? *)
    DataRecord : AColumnDataRecord;
    ok         : BOOLEAN;
BEGIN
        (* How wide should date columns be? *)
    CASE DefaultDateOption OF
        ShowDate :
                    DateWidth := TimeStringLength(DefaultDateFormat);
      | ShowTime :
                    DateWidth := TimeStringLength(DefaultTimeFormat);
        ELSE
                    DateWidth := TimeStringLength(DefaultDateAndTimeFormat);
    END;

    FOR i := 1 TO MaxReportColumns DO
        WITH Columns[i] DO
                (* Column widths differ for exporting vs. printing. *)
            IF ( CallerIsExporter ) THEN
                ok := GetVaryAInfo( i, ColumnExportWidth, 0, DataRecord );
                Width        := DataRecord.CardinalValue;
            ELSE
                    (* Some columns may have adjustable widths. *)
                ok := TRUE;
                CASE i OF
                    StartDateColumn,
                    EndDateColumn :
                        Width    := DateWidth;
                  ELSE
                        ok := GetVaryAInfo( i, ColumnWidth, 0, DataRecord );
                        Width    := DataRecord.CardinalValue;
                 END;
            END;

            IF (NOT ok) THEN FatalError(); END;  (* too few? *)

            ColumnNumber := i;
                
                (* Determine the number of decimals for this column. *)
            ok := GetVaryAInfo( i, ColumnMaxDecimals, 0, DataRecord );
            Decimals     := DataRecord.CardinalValue;
        END;
    END;


        (* How wide should name columns be? *)
    IF ( NOT CallerIsExporter ) THEN
        GetNameColumnWidths( Columns,
                             {TaskNameColumn,WBSColumn,ResourceNameColumn});
    END;

END SetUpColumns;




    (* WriteRow -- Write a row of data to the output file. *)


PROCEDURE WriteRow( Task : ATaskPtr;
                    Resource : AResourcePointer;
                    StartDate, EndDate : ABigTime;
                    Level    : REAL;
                    Context  : ADDRESS);
CONST
    OutputFont = NormalFont;
VAR
    ID : POINTER TO CARDINAL;
    Loop : CARDINAL;
    DataType       : CARDINAL;
    DataRecord     : AnIntDataRecord;
BEGIN
    FOR Loop := 1 TO MaxReportColumns DO
        ColumnData( Task, Resource,
                    StartDate, EndDate, Level,
                    Columns[ Loop ].ColumnNumber,
                    Columns[ Loop ].Width,
                    DataType,
                    DataRecord,
                    OutputFont);
        IF (DataType = MAX(CARDINAL)) THEN
            WriteIntData( SkipRecordType, DataRecord );
        ELSE
            WriteIntData( DataType, DataRecord );
        END;
    END;

    ID := Context;
    INC(ID^);
    UpdateThermometer( Thermometer, ID^ );
END WriteRow;



    (* GenerateData -- Write the row headers for the beginning of
                       each row, and then write the data for each row. *)


PROCEDURE GenerateData();
VAR
    TaskNode     : ATreeNode;
    Rows         : CARDINAL;
    Count        : CARDINAL;
    s            : ARRAY [0..69] OF CHAR;
    ok           : BOOLEAN;
BEGIN
     (*<TRACE
     SetString(TraceS,"Now in GenerateData");
     PrintString(TraceS);
     TRACE>*)

        (* Create the row headers.   Count the number of rows.  *)

    Rows := GenerateAssHeaders( 1 );
    IF (CheckIO( InterFile ) <> done) THEN
        RETURN;
    END;

     (*<TRACE
     SetString(TraceS,"Rows = "); CtoS(Rows,TraceS2); ConcatLS(TraceS,TraceS2);
     PrintString(TraceS);
     TRACE>*)


    GetMessage( ModuleNumber + 7, s ); (* "Joins' data generated" *)

    (* Generate the data section of the file. *)

    StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );

    IF (CheckIO( InterFile ) = done) THEN
        IF (Rows > 0) THEN
            ok := CreateThermometer( Thermometer, 0, 0, s, Rows );
                (* Output all the rows of data. *)
            Count := 0;
            EnumerateRows( WriteRow, ADR(Count) );

            DiscardThermometer ( Thermometer );
        END;
    ELSE
        FileComplaint();
    END;

    IF (CheckIO( InterFile ) = done) THEN
        EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );
    END;


END GenerateData;




 (* Main *)

PROCEDURE DoTLXVaryA();
VAR
    P                   : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
    s                   : ARRAY [0..51] OF CHAR;


    PROCEDURE Setup() : BOOLEAN;
    VAR
        s1         : ARRAY [0..19] OF CHAR;
        s2         : ARRAY [0..19] OF CHAR;
        j          : CARDINAL;
    BEGIN

        IF ( NOT HeapAvailable () ) THEN                                (* 18-Aug-89 MWP *)
           GetGaGaMessage( 501,s);
           Error(s);
           RETURN FALSE;
        END;

        (* Validate the task tree.  *)

        ValidateTree( TaskTree );

        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            FatalError();
        END;

        j := 1;

        ParseString( P^, j, s1 );

        GetMessage( 13807, s2 );        (* "EXPORT" *)

        CallerIsExporter := ( Compare ( s1, s2 ) = 0 );

        SetLengthOf ( s, 0 );
        RETURN ( CreateTheFile( s ) );

    END Setup;



BEGIN
    s         := "Program Copyright (c) 1991 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)

    SetLengthOf (s,0);

    IF (NOT Setup()) THEN
        RETURN;
    END;


    SetUpColumns();

    SetLengthOf (s,0);

    IF (GenerateFileHeaders( AGetInfoProc(GetVaryAInfo),
                             OverallPhrase,      (* OverallPhrase         *)
                             2,                  (* PredicateHeadingDepth *)
                             DomainBaseMessage,  (* DomainBase            *)
                             Columns,
                             s
                                )) THEN
        GenerateData();

        (* Clean up the file and exit.  Do not close the file! *)

        IF (CheckIO( InterFile ) <> done) THEN
            FileComplaint();
        ELSIF (GenerateFileTrailers()) THEN
            PackageOK := TRUE;  (* Tell mom that we're OK down here. *)
        END;
    ELSE
        FileComplaint();
    END;

    CommonCleanup();

    IF (NOT PackageOK) AND (InterFileOpen) THEN     (* 3/17/89 EGK *)
        DeleteTempFile (InterFile);
        InterFileOpen := FALSE;
    END;

END DoTLXVaryA;




BEGIN

    FirstDataRecordPtr := NIL;
    CallerIsExporter   := FALSE;
    DoTLXVaryA();

    (*<TRACE
    EndTrace();
    TRACE>*)

END TLXVaryA.
