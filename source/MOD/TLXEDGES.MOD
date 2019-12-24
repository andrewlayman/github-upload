MODULE TLXEdges;  (* Export Edges *)


  (* TL X Edges - Export Edges

        MODIFICATION HISTORY:

                RSC   6/1/88   First version.
        RSC  6/15/88   Added Thermometer.
        AJL  7/13/88   GenerateData procedure was mistakenly traversing all
                       tasks, not just visible ones.
        RSC  6-Feb-89  Change "ExportersOK" to "PackageOK"
        EGK 17-Mar-89     Put more checking into DoTLXEdges to make sure
                          we don't leave the temp file open if the back
                          end (which would close it) isn't going to run.
        RSC 21-Mar-89  Added support for new formatting routines, removing the
                       same formatting code from within here.
        MWP 11-Jul-89  If there are no dependencies to report on, display
                       error message and return false.
        MWP 13-Jul-89  Remember to unlock flexstor objects.
        KKC 09-Aug-89  Add copyright message.
        MWP 20-Aug-89  Large amount of changes to accomodate new Export
                       form.
        MWP 23-Aug-89  Do not export ToPlus, ToDuration, ToTime and ToScale
                       columns. They are no longer contained in Timeline
                       and are ignored on import.
        MWP 23-Aug-89  When checking for the existence of edges to
                       export, only check visible tasks.
        MWP  2-Sep-89  If exporting, retrieve the ColumnExportWidth.
        MWP  2-Oct-89  Move text literals to phrases file.
        KKC 21-Feb-90  Remove import of Timeu.
   *)


FROM AsciiIO       IMPORT
        (* PROCS *)     FileComplaint;

FROM Allocs        IMPORT
        (* TYPE *)      ATaskPtr,
        (* VARS *)      TaskTree,
        (* PROC *)      CheckTaskValid;

FROM Captions       IMPORT
    (* TYPE *)          AColumnDataRecord, AColumnInfoChoice;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM Edges          IMPORT
    (* TYPE *)          AnEdge, AnEdgePtr;

FROM EdgeFormat     IMPORT
    (* PROC *)          GetEdgeValue, GetEdgeInfo;

FROM ExportLinkage  IMPORT
    (* VAR *)           InterFile, InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      File,    Response;

FROM FileAux       IMPORT
        (* PROCS *)     CheckIO;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle,
        (* PROC *)      ReleaseUnchangedObject, LockObjectArray,
                        DiscardExtObject;

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

FROM MagicNum       IMPORT
    (* CONST *)         EdgeLastColumn, EdgeToStart;              (* 21-Aug-89 MWP *)

FROM Menus         IMPORT
        (* PROCS *)     WordNumber;

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

FROM Subfiles      IMPORT
        (* PROCS *)     StartFileOutput,    EndFileOutput,
                        StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM TempFile               IMPORT
    (* PROC *)                  DeleteTempFile;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATreeNode, ATreeOrder, ATreeNodeAttribute,
        (* PROCS *)     ValidateTree;

FROM Words          IMPORT
        (* PROC *)      ParseString;




CONST   ModuleNumber     = 24100;  (* For GetMessage *)

        ExportInclude    = TempFlag6;  (* Is this task included? *)

        MAXCARDINAL      = 65535;
        MAXDATE          = MAXCARDINAL;

        (* Subfile IO version number:   *)

        VersionNumber  = 1; (* For subfiles *)
        MaxReportColumns =  EdgeToStart;                          (* 21-Aug-89 MWP *)



VAR
    Columns      : ARRAY [1..MaxReportColumns] OF AColumn;
    CallerIsExporter        : BOOLEAN;

    Thermometer  : AThermometer;





 (* Column Data - Given a node, return a single data item.

        Preconditions  - Edge   is the edge record.
                         HTask  is the head task (predecessor)
                         TTask  is the tail task (successor)
                         Column is the column number, one of the constants
                                   defined above.
                         Width  is the maximum width of the resulting
                                   (string) field.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData ( VAR Edge     : AnEdge;
                           HTask,
                           TTask    : ATaskPtr;
                           Column   : CARDINAL;
                           Width    : CARDINAL; (* for strings only. *)
                       VAR DataType : CARDINAL;
                       VAR TheData  : AnIntDataRecord );
VAR
    Value   : AColumnDataRecord;
BEGIN

    IF (GetEdgeValue( ADR(Edge), HTask, TTask, Column, Value)) THEN
        ConvertCaptionsToIntermediate( Value, Width, DataType, TheData );
    END;

END ColumnData;







  (* Is this task filtered in? *)
PROCEDURE TaskFilteredIn( Task : ATreeNode ) : BOOLEAN;
BEGIN
    RETURN (Task^.Methods^.TestAttributeBit( Task, ExportInclude ));
END TaskFilteredIn;




 (* GenerateOneEdgeData - create the data records for one edge.

        Preconditions  - A valid edge node
        Postconditions - one or more data records have been written to the file.
 *)
PROCEDURE GenerateOneEdgeData( Edge  : AnEdgePtr;
                               Task  : ATaskPtr );
VAR
    DataType,
    Loop           : CARDINAL;
    TTask          : ATaskPtr;
    DataRecord     : AnIntDataRecord;
BEGIN
    IF (TaskFilteredIn(Edge^.tailtask)) THEN
        TTask := Edge^.tailtask^.Methods^.LockFlexStorDataObject( Edge^.tailtask );
        FOR Loop := 1 TO MaxReportColumns DO
            ColumnData( Edge^,
                        Task, TTask,
                        Columns[ Loop ].ColumnNumber,
                        Columns[ Loop ].Width,
                        DataType,
                        DataRecord );
            WriteIntData( DataType, DataRecord );
        END;
        Edge^.tailtask^.Methods^.UnlockUnchangedDataObject( Edge^.tailtask );
    END;
END GenerateOneEdgeData;



    (* GenerateOneEdgesData --

       Preconditions -- The subfile is correctly positioned and written
                        so that it is at the start of a data row.

                        Node is an antecedant task.

                        Tasks' bits are set to indicate which tasks are
                        proper for export.   See the TaskFilteredIn proc.

                        Context is the address of a CARDINAL number.

       Postconditions --

                        For each filtered-in dependant task of Node, a
                        row of data records is written to the output file.

                        The CARDINAL addressed by Context^ is incremented
                        for each row.

                        The global thermometer is updated.

    *)


PROCEDURE GenerateOneEdgesData( VAR Node    : ATreeNode;
                                    Context : ADDRESS );
VAR
    i               : CARDINAL;
    Task            : ATaskPtr;
    EdgeList        : AnEdgePtr;
    Counter         : POINTER TO CARDINAL;
BEGIN
    Task     := Node^.Methods^.LockFlexStorDataObject( Node );
    EdgeList := Task^.desctasks;
    Counter  := Context;
    WHILE (EdgeList <> NIL) DO
        INC(Counter^);
        UpdateThermometer( Thermometer, Counter^ );
        GenerateOneEdgeData( EdgeList, Task );
        EdgeList := EdgeList^.headlink;
    END;
    Node^.Methods^.UnlockUnchangedDataObject( Node );
END GenerateOneEdgesData;






  (* Generate the headers for the dependency records attached to this task. *)

PROCEDURE DoEdgeHeader( VAR TaskNode   : ATreeNode;
                        VAR ID         : CARDINAL   );
VAR
    i              : CARDINAL;
    EdgeList       : AnEdgePtr;
    TTask,
    Task           : ATaskPtr;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    s              : ARRAY [0..255] OF CHAR;
    DataExists     : BOOLEAN;

BEGIN
  (* Here we act paranoid about the task tree node.  By the time we are
     outputting data, we won't have to worry.
  *)
    CheckTaskValid( TaskNode );

    Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    EdgeList := Task^.desctasks;
    WHILE (EdgeList <> NIL) DO
        IF (TaskFilteredIn(EdgeList^.tailtask)) THEN
            TTask := EdgeList^.tailtask^.Methods^.LockFlexStorDataObject( EdgeList^.tailtask );
            INC( ID );
            WITH HeadingRecord DO
                UniqueID        := ID;
                HeadingDepth    := 1;  (* just the name *)
                DataIndentation := 0;  (* levels indented.  0 for all edges *)
                Summary         := FALSE; (* resources are never summaries. *)
            END;
            WriteRecord( InterFile, HeadingRecordType,
                         ADR(HeadingRecord), SIZE(HeadingRecord) );

            WITH DataRecord DO
                Font := 0C;
                Copy( Task^.taskname, s );
                TrimRear(s);
                ConcatS( s, "/" );
                ConcatLS(s, TTask^.taskname );
                TrimRear(s);
                Copy( s, LString );
            END;
            WriteIntData( TextType, DataRecord );
            EdgeList^.tailtask^.Methods^.UnlockUnchangedDataObject( EdgeList^.tailtask );
        END;
        EdgeList := EdgeList^.headlink;
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
END DoEdgeHeader;



    (* Generate the headers for the EDGE dimension. *)

PROCEDURE EdgeHeaders( HeaderNumber : CARDINAL ) : CARDINAL;
VAR
    ID          : CARDINAL;
    Node        : ATreeNode;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN 0; END;
    ID := 0;
    Node := TaskTree^.Methods^.GetFirstVisible( TaskTree );
    WHILE (Node <> NIL) DO
        DoEdgeHeader( Node, ID );
        Node := Node^.Methods^.NextForDisplay( Node );
    END;
    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );
    RETURN ID;
END EdgeHeaders;



  (* Reset the filtering bit (a temp bit I use) in all tasks.  This proc
     is called by TraverseTree()
  *)

PROCEDURE SetFilterBitOff( VAR Node : ATreeNode; Context : ADDRESS );
BEGIN
    Node^.Methods^.SetAttributeBit (Node, ExportInclude, FALSE);
END SetFilterBitOff;




   (* Set up the task tree to have a temp bit (ExportInclude) mean
      "This task is visible".  That way, we only output edges for
      tasks that are visible.
   *)
PROCEDURE SetupTaskTreeFilterBits();
VAR
    Node : ATreeNode;
BEGIN

  (* Set the temp bit OFF in all task nodes. *)

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                     SetFilterBitOff, NIL);

  (* Set the bit ON in the filtered in tasks. *)

    Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);
    WHILE (Node <> NIL) DO
        Node^.Methods^.SetAttributeBit (Node, ExportInclude, TRUE);
        Node := Node^.Methods^.NextForDisplay (Node);
    END;

END SetupTaskTreeFilterBits;






 (* Main *)

PROCEDURE DoTLXEdges();
VAR
    Rows,
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
        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            FatalError();
        END;

        (* Validate the task tree.  Insure that there ARE some tasks. *)

        ValidateTree( TaskTree );

        IF (TaskTree^.Methods^.GetFirst( TaskTree ) = NIL) THEN
            DoDialog( ModuleNumber + 6, TRUE );
            (* There are no tasks on which to report. *)
            RETURN FALSE;
        END;

        (* Mark tasks who are visible for edge export. *)
        SetupTaskTreeFilterBits();

        (* Make sure that there are edges available in the visible
           nodes, for export.
        *)
        IF ( NOT AnyEdges () ) THEN                                   (* 11-Jul-89 MWP *)
           DoDialog( ModuleNumber + 8, TRUE ); (* No Tasks! *)
           (* "There are no dependencies on which to report." *)
           RETURN FALSE;
        END;


        j := 1;

        ParseString( P^, j, s1 );

        GetMessage( ModuleNumber, s2 );                           (* 2-Oct-89 MWP *)
        (* "EXPORT" *)

        IF ( Compare ( s1, s2 ) = 0 ) THEN
           CallerIsExporter := TRUE;
        END;

        SetLengthOf ( s, 0 );

        RETURN ( CreateTheFile( s ) );

    END Setup;


    PROCEDURE AnyEdges () : BOOLEAN;                              (* 21-Aug-89 MWP *)
    VAR
        Node                : ATreeNode ;
        EdgesFound          : BOOLEAN;
    BEGIN
        EdgesFound := FALSE;

        Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);

        WHILE ( NOT EdgesFound ) AND (Node <> NIL) DO
            EdgesFound := CheckForEdges ( Node );
            Node := Node^.Methods^.NextForDisplay (Node);
        END;

        RETURN ( EdgesFound );

    END AnyEdges;


    PROCEDURE CheckForEdges (VAR TaskNode : ATreeNode ) : BOOLEAN;
    VAR
        Task            : ATaskPtr;
        EdgeList        : AnEdgePtr;
        EdgesFound      : BOOLEAN;
    BEGIN

        EdgesFound := FALSE;

        Task     := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        EdgeList := Task^.desctasks;

        IF (EdgeList <> NIL) THEN
           EdgesFound := TRUE;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );     (* 13-Jul-89 MWP *)

        RETURN ( EdgesFound );

    END CheckForEdges;


    PROCEDURE GenerateData();
    VAR
        Node : ATreeNode;
        Count        : CARDINAL;
        s            : ARRAY [0..69] OF CHAR;
        ok           : BOOLEAN;
    BEGIN
        Rows := EdgeHeaders( 1 );
        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;

        GetMessage( ModuleNumber + 7, s ); (* "Joins' data generated" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );

        IF (CheckIO( InterFile ) = done) THEN
            Count := 0; (* # of rows output *)
            Node := TaskTree^.Methods^.GetFirstVisible (TaskTree);

            WHILE (Node <> NIL) DO
                GenerateOneEdgesData(Node,ADR(Count));
                Node := Node^.Methods^.NextForDisplay (Node);
            END;
        END;

        DiscardThermometer ( Thermometer );

        IF (CheckIO( InterFile ) <> done) THEN
            RETURN;
        END;

        EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );
    END GenerateData;



    PROCEDURE SetUpColumns();
    VAR
        i          : CARDINAL;
        DataRecord : AColumnDataRecord;
        ok         : BOOLEAN;
    BEGIN
        FOR i := 1 TO MaxReportColumns DO
            WITH Columns[i] DO
                IF ( CallerIsExporter ) THEN
                    ok := GetEdgeInfo( i, ColumnExportWidth, 0, DataRecord );
                ELSE
                    ok := GetEdgeInfo( i, ColumnWidth, 0, DataRecord );
                END;

                IF (NOT ok) THEN FatalError(); END;  (* too few? *)
                Width        := DataRecord.CardinalValue;
                ColumnNumber := i;
                ok := GetEdgeInfo( i, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
        END;
    END SetUpColumns;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)

    SetLengthOf (s,0);

    IF ( NOT Setup () ) THEN
        RETURN;
    END;

    SetUpColumns();

    (* Create the first part of the file (the non-data part) *)


    IF (GenerateFileHeaders( AGetInfoProc(GetEdgeInfo),
                             ModuleNumber +  9,  (* OverallPhrase         *)
                             2,                  (* PredicateHeadingDepth *)
                             ModuleNumber + 30,  (* DomainBase            *)
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

END DoTLXEdges;




BEGIN

    CallerIsExporter   := FALSE;
    DoTLXEdges();

END TLXEdges.
