MODULE TLXRsAss;  (* Export Resource Assignments *)


  (* TL X Rs Ass - Export Resource Assignments

        MODIFICATION HISTORY:

        RSC  5/22/88   First version, from TLRTable.
        RSC  6/13/88   Changed columns to allow for better display of
                       unit and fixed costs.
        RSC 6/15/88    Added Thermometer.
        AJL 6/27/88    Added filters on assignments.
        LAA 7/19/88    Fixed bug with time being exported wrong (converting
                       to man-hours when already IN man-hours).  Added
                       selection for Baseline or Plan assignments.
        LAA 7/20/88    Don't continue with export if user presses ESC from
                       the Actual/Baseline dialog box.
        RSC 6-Feb-89   Change "ExportersOK" to "PackageOK"
        EGK 17-Mar-89     Put more checking into DoTLXRsass to make sure
                          we don't leave the temp file open if the back
                          end (which would close it) isn't going to run.
        RSC 21-Mar-89     Use new captions and columns modules, rather than
                          using RptCommon and built in routines.
        MWP  1-May-89     Allow writing of a SkipRecordType Int file record.
        MWP 23-Jun-89     Removed asking user whether to output Actual or
                          Baseline data. We now export ALL assignment data
                          for each record.
        KKC 09-Aug-89     Add copyright message.
        MWP 20-Aug-89     Large amount of changes to accomodate new Export
                          form.
        MWP 23-Aug-89     When checking for the existence of assignments to
                          export, only check visible tasks.
        MWP 24-Aug-89     Retrieve export report type before checking for
                          existence of assignment records.
        MWP  2-Sep-89     If exporting, retrieve the ColumnExportWidth.
        KKC 21-Feb-90     Remove import of Timeu.
        RSC  6-Aug-90     Fixup compile problems due to DEF changes.
        RSC 10-Aug-90     removed AssignmentCost.
        RSC 17-Oct-90     Patch for bug # 3206, where a baseline assignment
                          with no plan assignment on an "All" report shows
                          no task name, task wbs, and resource name col.
                          Not only was this annoying, it caused us to
                          miscount the number of records.  This is because
                          we would send an assignment record with a NIL
                          pointer off to Filters1 to see if the assignment
                          is filtered in.  If some random value in low
                          memory was a valid ID in the resource list,
                          PRESTO!  The item exists!

                          Is this any way to run an airline??

                          I try to get around this by using RTempFlag3
                          in the assignment attributes, but this needs
                          much more thought.
        AJL 24-Apr-91    -There were a number of procedures in this code that
                          were left over from when this was build out of
                          TLXEDGES.  These procedures were unused, and I 
                          removed them to make the code more understandable.
                         -Removed unused imports.
                         -Changed calls to FatalError to use ErrorPhrase();

   *)

FROM Allocs        IMPORT
        (* TYPE *)      ATaskFilter, ATaskFilterSet, ATaskPtr, ATaskFlag,
        (* VARS *)      TaskTree,
        (* PROC *)      CheckTaskValid;

FROM Assignments   IMPORT
        (* TYPE *)      AnAssignmentAttribute, AnAssignmentRecord,
                        AnAssignmentArray, AnAssignmentAttributeSet;

FROM AssFormat     IMPORT
    (* PROC *)          GetAssInfo, GetAssValue;

FROM Captions      IMPORT
    (* TYPE *)          AColumnDataRecord, AColumnInfoChoice;

FROM Dialog        IMPORT
        (* PROCS *)     ErrorPhrase;

FROM ExportLinkage IMPORT
    (* VAR *)           InterFile, InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      Response;

FROM FileAux       IMPORT
        (* PROCS *)     CheckIO;

FROM Filter1       IMPORT
        (* PROCS *)     AssignmentFiltersPassed;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle,
        (* PROC *)      ReleaseUnchangedObject, LockObjectArray,
                        ReleaseObject;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType,
                        CardinalType, BooleanType,
                        PredicateRecordType, EnumeratedType,
                        HeadingRecordType, SkipRecordType,
                        RepeatRecordType, AggregatorRecordType,
    (* TYPE *)          AFont, ADataType, AnOverallRecord,
                        APredicateHeadingRecord, ADomainRecord,
                        APredicateRecord, AFormatType, AFormat,
                        AnAggType, AnAggregatorRecord,
                        AHeadingRecord, AnIntDataRecord,
    (* PROC *)          WriteIntData, ReadIntData,
                        ConvertCaptionsToIntermediate;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS,
                        StoC, ConcatS, TrimFront, Compare;

FROM MagicNum      IMPORT
    (* CONST *)         AssLastColumn,
                        AssPlanStartColumn,
                        AssBsLnStartColumn,
                        AssPlanLastColumn,
                        AssBsLnLastColumn,
                        AssTaskName,
                        AssResourceName;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays      IMPORT
        (* VARS  *)     PackageOK,
        (* PROCS *)     OverlayContext;

FROM Progress      IMPORT
        (* TYPE *)      AThermometer,
        (* PROCS *)     CreateThermometer, UpdateThermometer,
                        DiscardThermometer;

FROM RecordIO      IMPORT
        (* PROCS *)     WriteRecord, WriteString;

FROM RptCommon     IMPORT
        (* TYPES *)     AColumn, AGetInfoProc,
        (* PROCS *)     GenerateFileTrailers, ColumnHeadings, ReleaseDialog,
                        GenerateFileHeaders,  DoDialog,
                        CreateTheFile, GetMessageWord, RsrcHeaders,
                        SetResourcesOnly, CommonCleanup;

FROM RsrcMod       IMPORT
        (* CONST *)     ResourceNameLength,
        (* TYPE  *)     AResourcePointer, AResourceType, ACostStyle,
        (* PROC *)      CheckResourceValid;

FROM SegWords      IMPORT
        (* PROCS *)     WordNumber;

FROM Space          IMPORT
    (* PROCS *)             HeapAvailable, Available, ALLOCATE, DEALLOCATE;

FROM Subfiles      IMPORT
        (* PROCS *)     StartFileOutput,    EndFileOutput,
                        StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM TempFile               IMPORT
    (* PROC *)                  DeleteTempFile;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATree, ATreeNode, ATreeOrder, ATreeNodeAttribute,
        (* PROCS *)     ValidateTree;

FROM Words          IMPORT
        (* PROC *)      ParseString;


TYPE
    AssDataPtr         =  POINTER TO AnExportRecord;

    AnExportRecord  =  RECORD
                          Resource       : AResourcePointer;
                          PlanAssign,
                          BsLnAssign     : AnAssignmentRecord;
                          NextRecord     : AssDataPtr;
                       END;

CONST   ModuleNumber     = 24000;  (* For GetMessage *)


        MAXCARDINAL      = 65535;
        MAXDATE          = MAXCARDINAL;

        (* Subfile IO version number:   *)

        VersionNumber    = 1; (* For subfiles *)

        MaxReportColumns = AssBsLnLastColumn; (* How many we allow accros the page. *)

        Zero  = 0.0;

        AddPlan = 1;
        AddBsLn = 2;

        ExportAll      = 1;
        ExportBaseline = 2;

VAR
    Columns      : ARRAY [1..MaxReportColumns] OF AColumn;

    Thermometer  : AThermometer;

    FirstDataRecordPtr   : AssDataPtr;

    ReportFormat            : CARDINAL;
    CallerIsExporter        : BOOLEAN;


 (* Column Data - Given a node, return a single data item.

        Preconditions  - Ass    is the assignment record.
                         Task   is the task pointer.
                         Column is the column number, one of the constants
                                   defined above.
                         Width  is the maximum width of the resulting
                                   (string) field.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData ( VAR Ass      : AnAssignmentRecord;
                           Task     : ATaskPtr;
                           Column   : CARDINAL;
                           Width    : CARDINAL; (* for strings only. *)
                       VAR DataType : CARDINAL;
                       VAR TheData  : AnIntDataRecord );
VAR
    Value   : AColumnDataRecord;
BEGIN

    DataType := MAXCARDINAL;                                 (* 1-May-89 MWP *)

    IF (GetAssValue( Ass, Task, Column, Value)) THEN
        ConvertCaptionsToIntermediate( Value, Width, DataType, TheData );
    END;

END ColumnData;





PROCEDURE DoCol(  VAR Ass       : AnAssignmentRecord;
                      Task      : ATaskPtr;
                      Column    : CARDINAL;
                      Font      : CHAR );
VAR
    DataType       : CARDINAL;
    DataRecord     : AnIntDataRecord;
BEGIN
    ColumnData( Ass,
                Task,
                Columns[ Column ].ColumnNumber,
                Columns[ Column ].Width,
                DataType,
                DataRecord );
    DataRecord.Font := Font;
    IF (DataType = MAXCARDINAL) THEN                         (* 1-May-89 MWP *)
        WriteIntData( SkipRecordType, DataRecord );
    ELSE
        WriteIntData( DataType, DataRecord );
    END;
END DoCol;




 (* GeneratePlanAssignmentData - create the 'Actual' data records for one resource.

        Preconditions  - A valid resource node
        Postconditions - one or more data records have been written to the file.
 *)

PROCEDURE GeneratePlanAssignmentData(  VAR PlanAss   : AnAssignmentRecord;
                                           Resource  : AResourcePointer;
                                           Task      : ATaskPtr );
VAR
    Loop                : CARDINAL;
    AssignmentResource  : AResourcePointer;
    HighlightData       : BOOLEAN;
    LocalFont           : CHAR;
BEGIN
    LocalFont     := 0C;

    IF (RTempFlag4 IN PlanAss.Attributes) THEN
        LocalFont := 1C;    (* Make a BOLD statement *)
    END;

        (* 17-Oct-90 RSC For the first few columns we MUST have a resource
                         pointer in the assignment record to get any
                         results out.  On the other hand, if there is NO
                         PLAN, we don't want to display any other columns.
                         Matt used the resource pointer field in the
                         assignment record to flag presence or absence of
                         data.  NIL means "no plan".

           Special understanding:  I know the sequence of column ID's.
        *)
    AssignmentResource := PlanAss.Resource;
    PlanAss.Resource   := Resource;
    FOR Loop := AssPlanStartColumn TO AssPlanLastColumn DO
        DoCol( PlanAss, Task, Loop, LocalFont );
        IF (Loop = AssResourceName) THEN
            PlanAss.Resource   := AssignmentResource;
        END;
    END;

END GeneratePlanAssignmentData;


PROCEDURE GenerateBsLnAssignmentData( VAR BsLnAss   : AnAssignmentRecord;
                                          Task      : ATaskPtr );
VAR
    Loop           : CARDINAL;
    LocalFont      : CHAR;
BEGIN
    LocalFont := 0C;

    IF (RTempFlag4 IN BsLnAss.Attributes) THEN
        LocalFont := 1C;    (* Make a BOLD statement *)
    END;

    FOR Loop := AssBsLnStartColumn TO AssBsLnLastColumn DO
        DoCol( BsLnAss, Task, Loop, LocalFont );
    END;

END GenerateBsLnAssignmentData;



PROCEDURE GenerateOneTasksData( VAR Node    : ATreeNode;
                                    Context : ADDRESS );
VAR
    i               : CARDINAL;
    Task            : ATaskPtr;
    AssignmentArray : AnAssignmentArray;
    Assignment      : POINTER TO AnAssignmentRecord;
    Counter         : POINTER TO CARDINAL;
    ReportPlan      : AnExtHandle;
    ReportBaseline  : AnExtHandle;

    NewDataPtr      : AssDataPtr;
BEGIN
    CollateAssignments ( Node );

    Counter := Context;

    Task := Node^.Methods^.LockFlexStorDataObject( Node );

    i := 1;
    NewDataPtr := RetrieveAssNode ( i );
    WHILE (NewDataPtr # NIL ) DO
        IF (RTempFlag3 IN NewDataPtr^.PlanAssign.Attributes) OR (* 17-Oct-90 RSC *)
           (RTempFlag3 IN NewDataPtr^.BsLnAssign.Attributes) THEN
            INC(Counter^);
            UpdateThermometer( Thermometer, Counter^ );
            WITH NewDataPtr^ DO
                GeneratePlanAssignmentData( PlanAssign, Resource, Task );
                GenerateBsLnAssignmentData( BsLnAssign,           Task );
            END;
        END;

        INC(i);
        NewDataPtr := RetrieveAssNode ( i );
    END;

    Node^.Methods^.UnlockUnchangedDataObject( Node );

    DisposeOfList ();

END GenerateOneTasksData;



PROCEDURE GenerateOneBsLnData( VAR Node    : ATreeNode;
                                   Context : ADDRESS );
VAR
    i               : CARDINAL;
    Task            : ATaskPtr;
    AssignmentArray : AnAssignmentArray;
    Assignment      : POINTER TO AnAssignmentRecord;
    Counter         : POINTER TO CARDINAL;
    ReportThisAss   : AnExtHandle;

BEGIN
    Counter := Context;
    Task := Node^.Methods^.LockFlexStorDataObject( Node );

    ReportThisAss := Task^.BaseLine.Assignments;

    IF (ReportThisAss <> AnExtHandle(NIL)) THEN
        i := LockObjectArray( ReportThisAss, AssignmentArray, TSIZE(AnAssignmentRecord));
        WHILE (i > 0) DO
            DEC(i);
            Assignment := ADR(AssignmentArray^[i]); (* Optimizer troubles! *)
            IF (RTempFlag3 IN Assignment^.Attributes) THEN
                INC(Counter^);
                UpdateThermometer( Thermometer, Counter^ );
                GenerateOneBsLnAssignmentData( Assignment^, Task );
            END;
        END;
        ReleaseUnchangedObject( ReportThisAss );
    END;

    Node^.Methods^.UnlockUnchangedDataObject( Node );
END GenerateOneBsLnData;

 (* GenerateOneAssignment - create the data records for one resource.

        Preconditions  - A valid resource node
        Postconditions - one or more data records have been written to the file.
 *)
PROCEDURE GenerateOneBsLnAssignmentData(  VAR Ass      : AnAssignmentRecord;
                                              Task     : ATaskPtr );
VAR
    i,
    Loop           : CARDINAL;
    LocalFont      : CHAR;
BEGIN
    LocalFont     := 0C;

    IF (RTempFlag4 IN Ass.Attributes) THEN
        LocalFont := 1C;    (* Make a BOLD statement *)
    END;

    i := 1;

    FOR Loop := AssBsLnStartColumn TO ( AssBsLnLastColumn + 3 ) DO
        DoCol( Ass, Task, i, LocalFont );

        INC(i);
    END;

END GenerateOneBsLnAssignmentData;





PROCEDURE RetrieveAssNode ( NodeNumber : CARDINAL ) : AssDataPtr;
VAR
    PL, NewDataPtr, TempDataPtr : AssDataPtr;
    i                           : CARDINAL;
BEGIN
    NewDataPtr := FirstDataRecordPtr;

    i := 1;

    IF ( NewDataPtr <> NIL ) THEN
        WHILE ( NewDataPtr # NIL ) DO

           IF ( i = NodeNumber ) THEN
              RETURN ( NewDataPtr );
           END;

           NewDataPtr  := NewDataPtr^.NextRecord;
           INC(i);
        END;
    END;

    RETURN ( NewDataPtr );

END RetrieveAssNode;



PROCEDURE CollateAssignments ( VAR Node : ATreeNode );
VAR
    Task            : ATaskPtr;
    ReportPlan      : AnExtHandle;
    ReportBaseline  : AnExtHandle;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject( Node );

    ReportBaseline := Task^.BaseLine.Assignments;
    ReportPlan     := Task^.Plan.Assignments;

    Node^.Methods^.UnlockUnchangedDataObject( Node );

    CollatePlanAssignments ( ReportPlan, Node );
    CollateBsLnAssignments ( ReportBaseline, Node );

END CollateAssignments;


PROCEDURE CollatePlanAssignments ( VAR ReportPlan : AnExtHandle;
                                   VAR Node       : ATreeNode );
VAR
    AssignmentArray : AnAssignmentArray;
    Assignment      : POINTER TO AnAssignmentRecord;
    NumberAssign    : CARDINAL;
BEGIN

     IF (ReportPlan <> AnExtHandle(NIL)) THEN
        NumberAssign := LockObjectArray( ReportPlan, AssignmentArray,
                                         TSIZE(AnAssignmentRecord ) );

        WHILE ( NumberAssign > 0 ) DO
            DEC(NumberAssign);
            Assignment := ADR(AssignmentArray^[NumberAssign]); (* Optimizer troubles! *)

            IF (RTempFlag3 IN Assignment^.Attributes) THEN
                CreateExportRecord ( Assignment^, AddPlan );
            END;
        END;
        ReleaseUnchangedObject( ReportPlan );
    END;

END CollatePlanAssignments;


PROCEDURE CollateBsLnAssignments ( VAR ReportBsLn : AnExtHandle;
                                   VAR Node       : ATreeNode );
VAR
    AssignmentArray : AnAssignmentArray;
    Assignment      : POINTER TO AnAssignmentRecord;
    NumberAssign    : CARDINAL;
BEGIN

    IF (ReportBsLn <> AnExtHandle(NIL)) THEN
        NumberAssign := LockObjectArray( ReportBsLn, AssignmentArray,
                                         TSIZE(AnAssignmentRecord ) );

        WHILE ( NumberAssign > 0 ) DO
            DEC(NumberAssign);
            Assignment := ADR(AssignmentArray^[NumberAssign]); (* Optimizer troubles! *)

            IF (RTempFlag3 IN Assignment^.Attributes) THEN
                AddBsLnRecord ( Assignment^ );
            END;
        END;
        ReleaseUnchangedObject( ReportBsLn );
    END;

END CollateBsLnAssignments;


PROCEDURE  AddBsLnRecord ( VAR Ass  : AnAssignmentRecord );
VAR
    PL, NewDataPtr, TempDataPtr : AssDataPtr;
    BsLnNotFound  : BOOLEAN;
BEGIN
    NewDataPtr := FirstDataRecordPtr;


    (* If no records to search, add the baseline assignment *)
    IF ( NewDataPtr = NIL ) THEN
         CreateExportRecord ( Ass, AddBsLn );
    ELSE
        BsLnNotFound := TRUE;
        WHILE ( NewDataPtr # NIL ) AND ( BsLnNotFound ) DO
            (* If resource ptr's match, see if this record already has
               a baseline record.
            *)
            IF ( Ass.Resource = NewDataPtr^.Resource ) THEN
               IF ( NewDataPtr^.BsLnAssign.Resource = AResourcePointer(NIL) ) THEN
                  NewDataPtr^.BsLnAssign := Ass;
                  BsLnNotFound := FALSE;
               END;
            END;

            IF ( BsLnNotFound ) THEN
               NewDataPtr  := NewDataPtr^.NextRecord;
            END;
        END;
        (* No records exist. Create a new one and add it to our list. *)
        IF ( BsLnNotFound ) THEN
          CreateExportRecord ( Ass, AddBsLn );
        END;
    END;

END AddBsLnRecord;


PROCEDURE  CreateExportRecord ( VAR Ass  : AnAssignmentRecord;
                                    Type : CARDINAL );
VAR
    PL, NewDataPtr, TempDataPtr : AssDataPtr;
BEGIN
    NEW(PL);

    WITH PL^ DO
       Resource := Ass.Resource;
       IF ( Type = AddPlan ) THEN
          PL^.PlanAssign := Ass;
          PL^.BsLnAssign.Resource   := AResourcePointer(NIL);
          PL^.BsLnAssign.Attributes := AnAssignmentAttributeSet{};
       ELSE
          PL^.BsLnAssign := Ass;
          PL^.PlanAssign.Resource   := AResourcePointer(NIL);
          PL^.PlanAssign.Attributes := AnAssignmentAttributeSet{};
       END;
    END;

    NewDataPtr := FirstDataRecordPtr;

    IF ( NewDataPtr = NIL ) THEN
        PL^.NextRecord  :=  NewDataPtr;
        FirstDataRecordPtr := PL;
    ELSE
        WHILE ( NewDataPtr # NIL ) DO
            TempDataPtr := NewDataPtr;
            NewDataPtr  := NewDataPtr^.NextRecord;
        END;

        PL^.NextRecord := NIL;

        TempDataPtr^.NextRecord  := PL;
    END;

END CreateExportRecord;


PROCEDURE DisposeOfList ();
VAR
    NewDataPtr, TempDataPtr : AssDataPtr;
BEGIN

    NewDataPtr := FirstDataRecordPtr;

    (* No entries in list *)
    IF ( NewDataPtr = NIL ) THEN
       RETURN;
    END;

    WHILE ( NewDataPtr # NIL ) DO
         TempDataPtr := NewDataPtr^.NextRecord;
         DISPOSE ( NewDataPtr );
         NewDataPtr  := TempDataPtr;
    END;

    FirstDataRecordPtr := NIL;

END DisposeOfList;




  (* Generate the headers for the assignment records attached to this task. *)

PROCEDURE DoAssHeader( VAR TaskNode   : ATreeNode;
                       VAR ID         : CARDINAL   );
VAR
    i              : CARDINAL;
    ReportThisAss  : AnExtHandle;
    NewDataPtr     : AssDataPtr;
    Task           : ATaskPtr;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    TaskName       : ARRAY [0..39]  OF CHAR;
    s              : ARRAY [0..255] OF CHAR;
    DataExists     : BOOLEAN;

    PROCEDURE DoOne();
    VAR
        AssignmentArray: AnAssignmentArray;
        Assignment     : POINTER TO AnAssignmentRecord;
        FilterSet      : ATaskFilterSet;
    BEGIN
        IF (ReportThisAss <> AnExtHandle(NIL)) THEN
            i := LockObjectArray( ReportThisAss, AssignmentArray, TSIZE(AnAssignmentRecord));
            WHILE (i > 0) DO
                DEC(i);
                Assignment := ADR(AssignmentArray^[i]); (* Optimizer troubles! *)
                FilterSet  := AssignmentFiltersPassed( TaskNode, Assignment^ );
                IF (Selected IN FilterSet) THEN
                    INCL(Assignment^.Attributes,RTempFlag3); (* 17-Oct-90 RSC Set/Clear flag *)
                    IF ((FilterSet * ATaskFilterSet{Highlight1..Highlight5})
                       <> ATaskFilterSet{}) THEN
                        INCL(Assignment^.Attributes,RTempFlag4);
                    ELSE
                        EXCL(Assignment^.Attributes,RTempFlag4);
                    END;
                ELSE
                    EXCL(Assignment^.Attributes,RTempFlag3);
                END;
            END;
            ReleaseObject( ReportThisAss ); (* 17-Oct-90 RSC R/W! *)
        END;
    END DoOne;

BEGIN
  (* Here we act paranoid about the task tree node.  By the time we are
     outputting data, we won't have to worry.
  *)
    CheckTaskValid( TaskNode );

    Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ReportThisAss := Task^.Plan.Assignments;

    DoOne();

    ReportThisAss := Task^.BaseLine.Assignments;
    DoOne();

    Copy( Task^.taskname, TaskName );
    TrimRear( TaskName );
    ConcatS(  TaskName, "/" );

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
    Task := NIL;

        (* 17-Oct-90 RSC I hate this!

                         We cannot process this until we have made the
                         initial pass to see what to include.  After
                         we have, we can then see how things collate
                         out and add headers for each collated record.
        *)

    CollateAssignments ( TaskNode );

    i := 1;
    NewDataPtr := RetrieveAssNode ( i );
    WHILE (NewDataPtr # NIL ) DO
        IF (RTempFlag3 IN NewDataPtr^.PlanAssign.Attributes) OR (* 17-Oct-90 RSC *)
           (RTempFlag3 IN NewDataPtr^.BsLnAssign.Attributes) THEN

            WITH HeadingRecord DO
                INC( ID );
                UniqueID        :=  ID;
                HeadingDepth    :=  1;  (* just the assignment name *)
                DataIndentation :=  0;
                Summary         :=  FALSE;
            END;
            WriteRecord( InterFile, HeadingRecordType,
                         ADR(HeadingRecord), SIZE(HeadingRecord) );
            WITH DataRecord DO
                Font := 1C;
                Copy( TaskName, s );
                ConcatLS( s, NewDataPtr^.Resource^.Name );
                TrimRear(s);
                Copy( s, LString );
                DataExists := TRUE;
            END;
            WriteIntData( TextType, DataRecord );
        END;

        INC(i);
        NewDataPtr := RetrieveAssNode ( i );
    END;

    DisposeOfList ();

END DoAssHeader;


PROCEDURE DoBsLnAssHeader( VAR TaskNode   : ATreeNode;
                           VAR ID         : CARDINAL   );
VAR
    i              : CARDINAL;
    Task           : ATaskPtr;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    AssignmentArray: AnAssignmentArray;
    Assignment     : POINTER TO AnAssignmentRecord;
    ReportThisAss  : AnExtHandle;
    FilterSet      : ATaskFilterSet;
    TaskName       : ARRAY [0..39]  OF CHAR;
    s              : ARRAY [0..255] OF CHAR;
    DataExists     : BOOLEAN;

BEGIN
  (* Here we act paranoid about the task tree node.  By the time we are
     outputting data, we won't have to worry.
  *)
    CheckTaskValid( TaskNode );

    Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ReportThisAss := Task^.BaseLine.Assignments;

        (* 17-Oct-90 RSC Release earlier.
        *)
    Copy( Task^.taskname, TaskName );
    TrimRear( TaskName );
    ConcatS(  TaskName, "/" );

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
    Task := NIL;

    IF (ReportThisAss <> AnExtHandle(NIL)) THEN
        i := LockObjectArray( ReportThisAss, AssignmentArray, TSIZE(AnAssignmentRecord));
        WHILE (i > 0) DO
            DEC(i);
            Assignment := ADR(AssignmentArray^[i]); (* Optimizer troubles! *)
            FilterSet  := AssignmentFiltersPassed( TaskNode, Assignment^ );
            IF (Selected IN FilterSet) THEN
                WITH HeadingRecord DO
                    INC( ID );
                    UniqueID        :=  ID;
                    HeadingDepth    :=  1;  (* just the assignment name *)
                    DataIndentation :=  0;
                    Summary         :=  FALSE;
                END;
                WriteRecord( InterFile, HeadingRecordType,
                             ADR(HeadingRecord), SIZE(HeadingRecord) );
                WITH DataRecord DO
                    Font := 1C;
                    Copy( TaskName, s );
                    ConcatLS( s, Assignment^.Resource^.Name );
                    TrimRear(s);
                    Copy( s, LString );
                    DataExists := TRUE;
                END;
                WriteIntData( TextType, DataRecord );

                INCL(Assignment^.Attributes,RTempFlag3); (* 17-Oct-90 RSC Set/Clear flag *)
                IF ((FilterSet * ATaskFilterSet{Highlight1..Highlight5})
                   <> ATaskFilterSet{}) THEN
                    INCL(Assignment^.Attributes,RTempFlag4);
                ELSE
                    EXCL(Assignment^.Attributes,RTempFlag4);
                END;
            ELSE
                EXCL(Assignment^.Attributes,RTempFlag3);
            END;
        END;
        ReleaseObject( ReportThisAss ); (* 17-Oct-90 RSC RW *)
    END;

END DoBsLnAssHeader;


    (* Generate the headers for the ASSIGNMENT dimension. *)

PROCEDURE AssHeaders( HeaderNumber : CARDINAL ) : CARDINAL;
VAR
    ID          : CARDINAL;
    Node        : ATreeNode;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );

    IF (CheckIO( InterFile ) <> done) THEN
        RETURN 0;
    END;

    ID := 0;

    Node := TaskTree^.Methods^.GetFirstVisible( TaskTree );

    WHILE (Node <> NIL) DO
        IF ( ReportFormat = ExportAll ) THEN
            DoAssHeader( Node, ID );
        ELSE
            DoBsLnAssHeader( Node, ID );
        END;
        Node := Node^.Methods^.NextForDisplay( Node );
    END;

    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

    RETURN ID;

END AssHeaders;


 (* Main *)

PROCEDURE DoTLXRsAss();
VAR
    Loop,
    ID                  : CARDINAL;
    P                   : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
    s                   : ARRAY [0..19] OF CHAR;
    Copyright           : ARRAY[0..50] OF CHAR;


    PROCEDURE Setup() : BOOLEAN;
    VAR
        s1         : ARRAY [0..19] OF CHAR;
        s2         : ARRAY [0..19] OF CHAR;
        j          : CARDINAL;
    BEGIN

        IF ( NOT HeapAvailable () ) THEN
            RETURN FALSE;       (* 17-Oct-90 RSC was Fatal Error *)
        END;
        (* Validate the task tree.  Insure that there ARE some tasks. *)

        ValidateTree( TaskTree );

        IF (TaskTree^.Methods^.GetFirst( TaskTree ) = NIL) THEN
            DoDialog( ModuleNumber + 3, TRUE ); (* No Tasks! *)
            RETURN FALSE;
        END;

        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            ErrorPhrase(ModuleNumber+99);  RETURN FALSE;
        END;

        j := 1;

        ParseString( P^, j, s1 );

        GetMessage( ModuleNumber + 5, s );
        (*  "EXPORT" *)
        IF ( Compare ( s1, s2 ) = 0 ) THEN
           CallerIsExporter := TRUE;
        END;

        ParseString( P^, j, s1 );

        j := 1;

        ReportFormat := StoC ( s1, j );

        IF ( ReportFormat < ExportAll ) OR ( ReportFormat > ExportBaseline ) THEN
            ReportFormat := ExportAll;                            (* 1-Sep-89 MWP *)
        END;


        IF ( NOT AnyAssignments () ) THEN
           DoDialog( ModuleNumber + 4, TRUE ); (* No Tasks! *)
           RETURN FALSE;
        END;

        RETURN TRUE;

    END Setup;



    PROCEDURE AnyAssignments () : BOOLEAN;
    VAR
        Node                : ATreeNode ;
        AssFound            : BOOLEAN;
    BEGIN

        AssFound := FALSE;

        Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);

        WHILE ( NOT AssFound ) AND (Node <> NIL) DO
            AssFound := CheckForAssignment ( Node );
            Node := Node^.Methods^.NextForDisplay (Node);
        END;

        RETURN ( AssFound );

    END AnyAssignments;

    PROCEDURE CheckForAssignment (VAR TaskNode : ATreeNode) : BOOLEAN;
    VAR
        TaskPtr         : ATaskPtr;
        ReportAss       : AnExtHandle;
        AssFound        : BOOLEAN;
    BEGIN
        AssFound := FALSE;

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        ReportAss := TaskPtr^.BaseLine.Assignments;

        IF (ReportAss <> AnExtHandle(NIL)) THEN
           AssFound := TRUE;
        END;


        IF ( ReportFormat = ExportAll ) THEN                        (* 20-Aug-89 MWP *)
            ReportAss := TaskPtr^.Plan.Assignments;

            IF (ReportAss <> AnExtHandle(NIL)) THEN
               AssFound := TRUE;
            END;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        RETURN ( AssFound );

    END CheckForAssignment;


    PROCEDURE GenerateData();
    VAR
        Node         : ATreeNode;
        Rows,
        Count        : CARDINAL;
        ok           : BOOLEAN;
        s            : ARRAY [0..69] OF CHAR;
    BEGIN
        Rows := AssHeaders( 1 );

        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;

        GetMessage( ModuleNumber + 6, s ); (* "Assignments' data generated" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );

        IF (CheckIO( InterFile ) = done) THEN
            Count := 0; (* # of rows output *)
            Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);     (* 21-Aug-89 MWP *)
            WHILE (Node <> NIL) DO
                IF ( ReportFormat = ExportAll ) THEN                   (* 20-Aug-89 MWP *)
                   GenerateOneTasksData ( Node, ADR ( Count ) );
                ELSE
                   GenerateOneBsLnData ( Node, ADR ( Count ) );
                END;
                Node := Node^.Methods^.NextForDisplay (Node);
            END;
        END;

        DiscardThermometer ( Thermometer );
        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;
        EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );
    END GenerateData;



    PROCEDURE SetUpAllColumns();
    VAR
        i          : CARDINAL;
        DataRecord : AColumnDataRecord;
        ok         : BOOLEAN;
    BEGIN
        FOR i := 1 TO MaxReportColumns DO
            WITH Columns[i] DO
                IF ( CallerIsExporter ) THEN                      (* 2-Sep-89 MWP*)
                   ok := GetAssInfo( i, ColumnExportWidth, 0, DataRecord );
                ELSE
                   ok := GetAssInfo( i, ColumnWidth, 0, DataRecord );
                END;

                IF (NOT ok) THEN ErrorPhrase(ModuleNumber+98); RETURN; END;  (* too few? *)
                Width        := DataRecord.CardinalValue;
                ColumnNumber := i;
                ok := GetAssInfo( i, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
        END;
    END SetUpAllColumns;


    PROCEDURE SetUpBsLnColumns();
    VAR
        i, j       : CARDINAL;
        DataRecord : AColumnDataRecord;
        ok         : BOOLEAN;
    BEGIN

       FOR i := 1 TO HIGH(Columns) DO
           Columns[ i ].Width := 0;  (* for RptCommon *)
       END;

       i := 1;

       FOR j := AssTaskName TO AssResourceName DO
            WITH Columns[i] DO
                IF ( CallerIsExporter ) THEN
                   ok := GetAssInfo( i, ColumnExportWidth, 0, DataRecord );
                ELSE
                   ok := GetAssInfo( j, ColumnWidth, 0, DataRecord );
                END;

                IF (NOT ok) THEN
                   ErrorPhrase(ModuleNumber+98);
                   RETURN;
                END;  (* too few? *)

                Width        := DataRecord.CardinalValue;
                ColumnNumber := j;
                ok := GetAssInfo( j, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
            INC(i);
       END;

       FOR j := AssBsLnStartColumn TO AssBsLnLastColumn DO
            WITH Columns[i] DO
                IF ( CallerIsExporter ) THEN
                   ok := GetAssInfo( i, ColumnExportWidth, 0, DataRecord );
                ELSE
                   ok := GetAssInfo( j, ColumnWidth, 0, DataRecord );
                END;

                IF (NOT ok) THEN
                   ErrorPhrase(ModuleNumber+98);
                   RETURN;
                END;  (* too few? *)

                Width        := DataRecord.CardinalValue;
                ColumnNumber := j;
                ok := GetAssInfo( j, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
            INC(i);
       END;

    END SetUpBsLnColumns;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)


    (* Create the first part of the file (the non-data part) *)

    SetLengthOf (s,0);

    IF (NOT Setup()) THEN
        RETURN;
    END;

    IF ( ReportFormat = ExportAll ) THEN                           (* 20-Aug-89 MWP *)
       SetUpAllColumns();
    ELSE
       SetUpBsLnColumns();
    END;

    SetLengthOf (s,0);

    IF (NOT CreateTheFile( s )) THEN
        RETURN;
    END;

    SetLengthOf (s,0);

    IF (GenerateFileHeaders( AGetInfoProc(GetAssInfo),
                             ModuleNumber +  9,  (* OverallPhrase         *)
                             2,                  (* PredicateHeadingDepth *)
                             ModuleNumber + 46,  (* DomainBase            *)
                             Columns,
                             s
                                )) THEN

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

END DoTLXRsAss;




BEGIN

    FirstDataRecordPtr := NIL;
    CallerIsExporter   := FALSE;
    DoTLXRsAss();

END TLXRsAss.

