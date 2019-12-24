IMPLEMENTATION MODULE RptCommon;

  (* First version - RSC 11/21/87

        1/15/88 - RSC - spruced up the report setings saving stuff.
                        Holder now holds everything needed for the form.
        1/28/88 - RSC - ajusted font bolding and normal.
        02-Feb-88 LAA   Removed use of LowFuel.
        16-Jun-88 RSC   Removed Create() call and now create int file on
                        ExportMedia directory.  This is for network support.
        EGK 6/23/88   - Added new field "Normalize" (by time).
        EGK 6/28/88   - Added Prefix parameter to GenerateFileHeaders.
        27-Jun-88 AJL - Added resource filtering.
        14-Jul-88 AJL - Removed the separate box titles from DoDialog.
                        Titles must be coded into the phrases now,
                        see Dialog for format.
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
        23-Jan-89 RSC   Changed Storage to Space    .
        21-Mar-89 RSC   Upgraded for Ken's reports.  This entailed a variety of
                        structural changes and general reqorking of the module.
        01-May-89 EGK   Put calls to TrimRear in ColumnHeadings, to avoid
                        returning strings with unnecessary spaces.
        31-May-89 KKC   Use Narrow heading for narrow columns in
                        GenerateFileHeaders.
        23-Jun-89 EGK   Put in calls to LJust in ColumnHeadings, to make
                        sure that we don't write right-justified strings
                        into the intermediate file.
        25-Jul-89 EGK   Changed references to "TotalBy" to accommodate the
                        new enumerated type which allows running totals.
                        Define AReportHolderRecord and ReportHolderRecord
                        as local variable.
        27-Aug-89 KKC   Move AReportHolderRecord and ReportHolderRecord
                        from the definition module to the implementation
                        module.
        11-Sep-89 KKC   Default FillScreenValues to TRUE.
        14-Sep-89 EGK   Added HoldInConfig to the HoldTypeSet.
        22-Sep-89 MWP   Added parameter to RsrcHeaders which allows us
                        to check for Acutals or Planned resources.
        10-Oct-89 MWP   Moved text literals to phrases file.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        04-Jun-90 AJL   Don't lock the baseline resource rate structure.
                        Just check that it is not NIL.
        14-Sep-90 AJl   Don't fail if the ColumnHeadings procedure inquires
                        about a column not currently defined.
        24-Oct-90 TGS   Some phrase numbers changed; fixed references to them.
        23-Jan-91 RSC   Put holder items in FlexStor.
        17-Jun-91 LAA   Reworked GetHolderHandle to clean up the logic, and
                        fix bug #4577.
         3-Jul-91 AJL   Added UsesSelectFilter and UsesHighlightFilter to 
                        OverallRecord.
        31-Jul-91 LAA   Well, my fix of 17-Jun-91 caused so problems, so I've
                        once again "fixed" GetHolderHandle.  Now, instead of
                        setting the Handle to NIL at the end of the procedure
                        based on the Found = FALSE, I set it to NIL at
                        several places where I know it's no good.  I hope.
        26-Aug-91 LAA   This is getting tiresome!  My last "fix" wasn't so
                        good either, as DigestReportHolderRecord expected
                        GetHolderHandle to return a NIL if it couldn't find
                        anything - but I'd made it allocate a new handle!
                        Now BuildReportHolderRecord will create a new handle
                        if it needs one, and GetHolderHandle will return NIL
                        if it can't find a handle in holder.  Sigh.
        03-Sep-91 LAA   Well, Tom found yet another case where GetHolderHandle
                        wasn't behaving itself.  This time, if you find a
                        holder record which is HoldInFlexStor, but is of the
                        wrong size, it deletes the handle and then during
                        RemoveObsoleteHeldItems tries to delete the handle 
                        again!  So I've conditioned it to only delete the
                        handle if it was created by earlier processing in
                        GetHolderHandle.
        24-Jan-92 TGS   Changed TimeHeaders so that it can generate equal-
                        spaced (tic-wise) time columns. It now takes a
                        parameter to enable this behavior, made necessary
                        because Histogram reports generate their date line
                        by using DateLines from Gantt.Mod, which assumes
                        columns all have the same number of tics in them,
                        while the data for the columns was being generated
                        with the assumption that they started and ended
                        on period boundaries. Bug 5324.
  *)




FROM Allocs        IMPORT
        (* TYPE  *)     ATaskPtr, ATaskFilterSet, ATaskFilter,
        (* VAR   *)     TaskTree,
        (* PROC  *)     CheckTaskValid;

FROM AsciiIO       IMPORT
        (* PROCS *)     FileComplaint;

FROM BigTimeU      IMPORT
        (* TYPE  *)     ABigTime,
        (* PROCS *)     BigTimeToTime, TimeToBigTime;

FROM Boxes         IMPORT
    (* TYPE *)          ABoxAttribute, ABoxType;

FROM Captions       IMPORT
    (* TYPE *)          AColumnDataRecord, AColumnInfoChoice;

FROM Dialog        IMPORT
        (* PROCS *)     MessageBox, Error, FatalError;

FROM Directory     IMPORT
        (* VARS *)      ExtractDeviceName;

FROM ExportLinkage IMPORT
        (* VAR *)       ExportMedia, InterFile, InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      File,    Response,
        (* PROCS *)     SetOpen;

FROM FileAux       IMPORT
        (* PROCS *)     FileResultMeans, FlushBuffer, PrepareForIO, CheckIO;

FROM Filter1       IMPORT
        (* PROC *)      ResourceFiltersPassed;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle, AnExtStoragePreference,
        (* PROC *)      ReleaseUnchangedObject, ReleaseObject,
                        CreateExtObjectWithSize, LockObject,
                        SetExtData, DiscardExtObject;

FROM GoTo          IMPORT
    (* PROCS *)         NullGoToCheckProc, DoGoTo;

FROM Holder        IMPORT
    (* TYPE *)          AHoldType, AHoldTypeSet,
    (* PROC *)          LocateHeldItem, HoldThis, DeleteHeldItem;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType, BigEndTimeType,
                        CardinalType, BooleanType, BigStartTimeType,
                        PredicateRecordType, EnumeratedType,
                        HeadingRecordType, SkipRecordType,
                        RepeatRecordType, AggregatorRecordType,
    (* TYPE *)          AFont, ADataType, AnOverallRecord,
                        APredicateHeadingRecord, ADomainRecord,
                        APredicateRecord, AFormatType, AFormat,
                        AnAggType, AnAggregatorRecord,
                        AHeadingRecord, AnIntDataRecord,
    (* PROC *)          WriteIntData, ReadIntData,
                        ExportDataType;

FROM Kbio          IMPORT
    (* TYPE *)          ascreenx, ascreeny, avidmode;


FROM Kbio          IMPORT
        (* CONST *)     maxrow, maxcol;

FROM Layout        IMPORT
        (* CONST *)     GanttWStart, GanttWEnd;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        Upshift, TrimFront, StringsEqual, StoC,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS;

FROM Menus         IMPORT
        (* PROCS *)     WordNumber;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage, ConcatMessage, DisplayMessage;

FROM RecordIO      IMPORT
        (* PROCS *)     WriteRecord, WriteString;

FROM RsrcMod       IMPORT
        (* TYPE *)      AResourcePointer, AResourceType,
        (* VAR   *)     ResourceTree,
        (* PROC *)      CheckResourceValid;

FROM Rugs          IMPORT
        (* TYPE *)      ARug,
        (* PROCS *)     GetRug, PutRug;

FROM Subfiles      IMPORT
        (* PROCS *)     StartFileOutput,    EndFileOutput,
                        StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM Space         IMPORT
        (* PROCS *)     HeapAvailable, ALLOCATE, DEALLOCATE;

FROM TempFile      IMPORT
        (* PROC *)      CreateTempFile;

FROM TimeJump      IMPORT
        (* PROCS *)     FindNextKeyDate;

FROM TimeFormat    IMPORT
        (* TYPE *)      EndDateStyle,
        (* PROCS *)     TimeAsEndDateStyle;

FROM Timei         IMPORT
        (* CONST*)      MinDate,
        (* TYPE *)      ADurationUnit, ADate, ATimeInfo, ADuration,
        (* PROCS *)     TimeUtoT, TtoTimeU;

FROM Timeu         IMPORT
        (* PROCS *)     UpScale;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATree, ATreeNode, ATreeOrder,
        (* PROCS *)     CreateTree,   CreateTreeNode,
                        ValidateTree, ValidateTreeNode;




        (* Subfile IO version number:   *)
CONST
        VersionNumber  = 1; (* For subfiles *)
        ModuleNumber   = 9300;

        MAXCARDINAL    = 65535;


TYPE
    ADisplayRecord = POINTER TO
        RECORD
            ColumnNumber  : CARDINAL;
            DisplayString : ARRAY [0..41] OF CHAR;
        END;



        AReportHolderRecord = RECORD
            Columns           : ARRAY [0..15] OF AColumn;
            RptStart,
            RptEnd            : ABigTime;
            RptPeriod         : ADurationUnit;
            Normalize         : BOOLEAN;
            TotalByRow,
            TotalByCol        : ASummChoice;
            DatesWereEntered,
            ResourcesOnly,
            EffortOrCost,
            FillValuesOnScrn  : BOOLEAN;
        END;

        AReportHolderRecordPointer = POINTER TO AReportHolderRecord;

VAR

    ColumnTree : ATree;         (* Text names for GoTo of each column *)

        (* For the Get Message Word procedure: *)

        GlobalPhrase        : CARDINAL;
        GlobalPhraseString  : ARRAY [0..255] OF CHAR;

        MessageRug          : ARug;
        MessageRugTaken     : BOOLEAN;
        ResourcesOnly       : BOOLEAN;
        RsrcBaseLine        : BOOLEAN;


        ReportHolderRecord : AReportHolderRecord;



PROCEDURE SetResourcesOnly( LResourcesOnly : BOOLEAN );
BEGIN
    ResourcesOnly := LResourcesOnly;
END SetResourcesOnly;




  (* Get Message Word - Get the nth word (0...m) from a phrase.

        Preconditions  - Phrase  is the phrase to get from the phrases file.
                         WordNumber is the Nth substring to return, N starting
                                        with 0 (for ORD(Enumeration)).  Substrings
                                        are delimited by commas.
        Postconditions - LString is the phrase.

   Note: This procedure uses a one-phrase cache, so if the requested phrase
         is the same as the last requested phrase, we do not re-ask the
         message processor for it.
  *)
PROCEDURE GetMessageWord( Phrase,
                          Word       : CARDINAL;
                      VAR LString    : ARRAY OF CHAR );
BEGIN
    IF (Phrase <> GlobalPhrase) THEN
        GlobalPhrase := Phrase;
        GetMessage( Phrase, GlobalPhraseString );
    END;
    WordNumber( GlobalPhraseString, Word + 1, LString );
END GetMessageWord;




 (* Word To C - Convert a phrase's word number to a Cardinal.

        Preconditions  - Phrase     is the phrase number to look up
                         WordNumber is the 'word' to seek in that phrase.
        Postconditions - RETURN     is the cardinal number.
 *)
PROCEDURE WordToC( Phrase,
                   WordNumber  : CARDINAL ) : CARDINAL;
VAR
    i  : CARDINAL;
    s1 : ARRAY [0..9] OF CHAR;
BEGIN
    GetMessageWord( Phrase, WordNumber, s1 );
    i := 1;
    RETURN StoC( s1, i );
END WordToC;



 (* Word To Ch - Convert a phrase's word number to a SmallCardinal.

        Preconditions  - Phrase     is the phrase number to look up
                         WordNumber is the 'word' to seek in that phrase.
        Postconditions - RETURN     is the CHR(Cardinal)
 *)
PROCEDURE WordToCh( Phrase,
                    WordNumber  : CARDINAL ) : CHAR;
VAR
    i  : CARDINAL;
    s1 : ARRAY [0..9] OF CHAR;
BEGIN
    GetMessageWord( Phrase, WordNumber, s1 );
    i := 1;
    RETURN CHR(StoC( s1, i ));
END WordToCh;





 (* Word To B - Convert a phrase's word number to a Boolean.

        Preconditions  - Phrase     is the phrase number to look up
                         WordNumber is the 'word' to seek in that phrase.
        Postconditions - RETURN     is the boolean.
 *)
PROCEDURE WordToB( Phrase,
                   WordNumber  : CARDINAL ) : BOOLEAN;
VAR
    i  : CARDINAL;
    s1 : ARRAY [0..9] OF CHAR;
BEGIN
    GetMessageWord( Phrase, WordNumber, s1 );
    RETURN (s1[1] = "T");
END WordToB;




  (* Column Headings - Describe the column.

        Preconditions  - GetInfo  is the info proc to get info from.
                         Column   is the desired column.

        Postconditions - Name      is the formal name for predicate headers
                         FullTitle is the name for the form.
                         Heading1  is the first heading line.
                         Heading2  is the second heading line.
                         UniqueID  is TRUE iff this column is the unique ID
                                      (for resources, its the Name column)
                         Format    is the output format on the report side.
                         DfltWidth is the suggested default width.
   *)
PROCEDURE ColumnHeadings( GetInfo     : AGetInfoProc;
                          Column      : CARDINAL;
                      VAR Name,
                          FullTitle,
                          Heading1,
                          Heading2    : ARRAY OF CHAR;
                      VAR UniqueID,
                          TotalByRsrc : BOOLEAN;
                      VAR DataType    : CARDINAL;
                      VAR Format      : AFormat;
                      VAR DfltWidth   : CARDINAL );
VAR
    DataRecord  : AColumnDataRecord;
    ok          : BOOLEAN;
BEGIN

    ok := GetInfo( Column, ColumnName, HIGH(FullTitle), DataRecord );
    IF (NOT ok) THEN
        FatalError();
    END;
    Copy( DataRecord.StringValue, FullTitle );
    LJust (FullTitle);
    TrimRear (FullTitle);

    ok := GetInfo( Column, ColumnFormalName, HIGH(Name), DataRecord );
    Copy( DataRecord.StringValue, Name );
    TrimRear (Name);

    ok := GetInfo( Column, ColumnHeading1, HIGH(Heading1), DataRecord );
    Copy( DataRecord.StringValue, Heading1 );
    LJust (Heading1);
    TrimRear (Heading1);

    ok := GetInfo( Column, ColumnHeading2, HIGH(Heading2), DataRecord );
    Copy( DataRecord.StringValue, Heading2 );
    LJust (Heading2);
    TrimRear (Heading2);

    ok := GetInfo( Column, ColumnWidth, 0, DataRecord );
    DfltWidth := DataRecord.CardinalValue;

    ok := GetInfo( Column, ColumnUniqueId, 0, DataRecord );
    UniqueID := DataRecord.BooleanValue;

    WITH Format DO
        ok := GetInfo( Column, ColumnFormatType, 0, DataRecord );
        FormatType    :=
                VAL(AFormatType,DataRecord.CardinalValue); (* Format Type *)
        ok := GetInfo( Column, ColumnMaxDecimals, 0, DataRecord );
        DecimalDigits := CHR(DataRecord.CardinalValue);
    END;

    ok := GetInfo( Column, ColumnDataType, 0, DataRecord );
    IF (DataRecord.CardinalValue > 0) THEN
        DataType    := ExportDataType(DataRecord.CardinalValue);
    ELSE
        DataType    := 0;
    END;

    ok := GetInfo( Column, ColumnTotalByRsrc, 0, DataRecord );
    TotalByRsrc := DataRecord.BooleanValue;

END ColumnHeadings;





  (* Generate various headers for the reports.... *)



 (* DoResourceHeaders - create the header records, one per resource.

        Preconditions  - A valid resource node
                         Context is a CARDINAL ID # (unique)
        Postconditions - a header record has been written to the file.
 *)
PROCEDURE DoResourceHeaders( VAR ResourceNode : ATreeNode;
                                 IDContext    : ADDRESS    );
VAR
    Resource       : AResourcePointer;
    ID             : POINTER TO CARDINAL;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    Handle            : AnExtHandle;
    Count             : CARDINAL;

BEGIN
  (* Here we act paranoid about the resource tree node.  By the time we are
     outputting data, we won't have to worry.
  *)
    ValidateTreeNode( ResourceNode );

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    CheckResourceValid( Resource );
    IF (ResourcesOnly AND (Resource^.Type <> Employable)) THEN
        RETURN;
    END;

    IF (NOT ( Selected IN  ResourceFiltersPassed(ResourceNode))) THEN
        RETURN;
    END;


        (* I think that the purpose of this is to check whether a 
           baseline has been set for the resource. *)

    IF ( RsrcBaseLine ) THEN
        Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
        IF (Resource^.BaseLineRates = AnExtHandle(NIL)) THEN
           RETURN;
        END;
    END;



    ID := IDContext;
    WITH HeadingRecord DO
        INC( ID^ );
        UniqueID        := ID^;
        HeadingDepth    := 1;  (* just the resource name *)
        DataIndentation := 0;  (* levels indented.  0 for all resources *)
        Summary         := FALSE; (* resources are never summaries. *)
    END;
    WriteRecord( InterFile, HeadingRecordType,
                 ADR(HeadingRecord), SIZE(HeadingRecord) );

    WITH DataRecord DO
        Font := 0C;
        Copy( Resource^.Name, LString );
    END;
    WriteIntData( TextType, DataRecord );
    (* errors are checked before writing in the WRITE procedures. *)
END DoResourceHeaders;



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

BEGIN
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




 (* Time U to B - Convert a timeu to a big time. *)

PROCEDURE TimeUtoB( T : ADate; VAR B : ABigTime; EndDate : BOOLEAN );
VAR
    TimeInfo    :   ATimeInfo;
BEGIN
    IF (EndDate) THEN
        TimeAsEndDateStyle( T, EndDateStyle, TimeInfo );
    ELSE
        TimeUtoT( T, TimeInfo);
    END;
    TimeToBigTime
    (
        TimeInfo.tiYear,
        TimeInfo.tiMonth,
        TimeInfo.tiDay,
        TimeInfo.tiHour,
        TimeInfo.tiMinute,
        0,
        B
    );
END TimeUtoB;






 (* DoTimeHeader - create the header records, one per tick.

        Preconditions  - Context is a CARDINAL ID # (unique)
        Postconditions - a header record has been written to the file.
 *)
PROCEDURE DoTimeHeader( VAR ID        : CARDINAL;
                        Period        : ADurationUnit;
                        EqualPeriods  : BOOLEAN;
                        TheStartDate,
                        TheEndDate    : ADate );
VAR
    Loop           : ADate;
    NextLoop       : ADate;
    Scale          : ADuration;
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
BEGIN

    Loop     := TheStartDate;
    NextLoop := Loop;
    WHILE (Loop < TheEndDate) DO
        IF (EqualPeriods) THEN
            Scale := UpScale(1, Period);
            INC(NextLoop, Scale);
        ELSE
            NextLoop := FindNextKeyDate( Loop, Period );
        END;
        IF (NextLoop > TheEndDate) THEN
            NextLoop := TheEndDate;
        END;
        WITH HeadingRecord DO
            INC( ID );
            UniqueID        := ID;
            HeadingDepth    := 2;  (* start and end dates *)
            DataIndentation := 0;
            Summary         := FALSE;
        END;
        WriteRecord( InterFile, HeadingRecordType,
                     ADR(HeadingRecord), SIZE(HeadingRecord) );

        WITH DataRecord DO (* First date *)
            Font     := 0C;
            Cardinal := ORD(Period);
            TimeUtoB( Loop, BigTime, FALSE );
        END;
        WriteIntData( BigStartTimeType, DataRecord );

        WITH DataRecord DO (* last date, use same Font and Cardinal. *)
            TimeUtoB( NextLoop, BigTime, TRUE );
        END;
        WriteIntData( BigEndTimeType, DataRecord );
        Loop := NextLoop;
    END;

END DoTimeHeader;



 (* Generate task headers for a task dimension *)

PROCEDURE TaskHeaders( CModuleNumber,
                       HeaderNumber : CARDINAL;
                       AddSummTitle : BOOLEAN ) : CARDINAL;
VAR
    ID          : CARDINAL;
    Node        : ATreeNode;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN 0; END;
    ID   := 0;
    Node := TaskTree^.Methods^.GetFirstVisible( TaskTree );
    WHILE (Node <> NIL) DO
        DoTaskHeader( Node, ID );
        Node := Node^.Methods^.NextForDisplay( Node );
    END;
    IF (AddSummTitle) THEN
        DoSummTitle( CModuleNumber, ID );
    END;
    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

    RETURN ID;
END TaskHeaders;


    (* Generate the headers for the RESOURCE dimension. *)

PROCEDURE RsrcHeaders( CModuleNumber,
                       HeaderNumber : CARDINAL;
                       AddSummTitle : BOOLEAN;
                       BaseLineOnly : BOOLEAN ) : CARDINAL;
VAR
    ID          : CARDINAL;
BEGIN
    RsrcBaseLine := BaseLineOnly;

    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN 0; END;
    ID := 0;
    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                        9999, DoResourceHeaders, ADR(ID));
    IF (AddSummTitle) THEN
        DoSummTitle( CModuleNumber, ID );
    END;
    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

    RETURN ID;
END RsrcHeaders;




PROCEDURE DoSummTitle( CModuleNumber : CARDINAL; VAR ID : CARDINAL );
VAR
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
BEGIN
    WITH HeadingRecord DO
        INC( ID );
        UniqueID        := ID;
        HeadingDepth    := 1;  (* just the word "TOTAL" *)
        DataIndentation := 0;  (* levels indented.  0 for all resources *)
        Summary         := FALSE; (* this is never a summary. *)
    END;
    WriteRecord( InterFile, HeadingRecordType,
                 ADR(HeadingRecord), SIZE(HeadingRecord) );

    WITH DataRecord DO
        Font := 200C; (* AGGREGATE HEADER *)
        GetMessage( CModuleNumber + 80, LString ); (* "Total" *)  (* 24-Oct-TGS *)
    END;
    WriteIntData( TextType, DataRecord );
END DoSummTitle;



    (* 24-Jan-92 TGS:
        EqualPeriods = TRUE : make the column headers an equal number of
                              tics apart, i.e., for histograms.
                       FALSE: columns represent period boundaries, i.e.,
                              whole months, weeks, etc., as for normal
                              cross-tabs.
    *)

PROCEDURE TimeHeaders( CModuleNumber,
                       HeaderNumber  : CARDINAL;
                       AddSummTitle,
                       EqualPeriods  : BOOLEAN;
                       Period        : ADurationUnit;
                       TheStartDate,
                       TheEndDate    : ADate ) : CARDINAL;
VAR
    ID : CARDINAL;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN 0; END;

    ID := 0;
    DoTimeHeader( ID, Period, EqualPeriods, TheStartDate, TheEndDate );
    IF (AddSummTitle) THEN
        DoSummTitle( CModuleNumber, ID );
    END;

    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );

    RETURN ID;
END TimeHeaders;



 (* Generate File Headers.  Generate the start-of-file records.

        Overall Record - Put in the Overall subfile.
        Predicate Heading - Put in the Predicate Subfile

        RETURN is TRUE iff the file writes went OK.
  *)
PROCEDURE GenerateFileHeaders( GetInfo               : AGetInfoProc;
                               OverallPhrase,
                               PredicateHeadingDepth,
                               DomainBase            : CARDINAL;
                           VAR Columns               : ARRAY OF AColumn;
                           VAR Prefix                : ARRAY OF CHAR
                              ) : BOOLEAN;

CONST MaxSubfileCount = 25;

VAR
    NextID,
    DfltWidth,
    Loop                   : CARDINAL;
    OverallRecord          : AnOverallRecord;
    PredicateHeadingRecord : APredicateHeadingRecord;
    PredicateRecord        : APredicateRecord;
    DomainRecord           : ADomainRecord;
    DataRecord             : AnIntDataRecord;
    ColDataRecord          : AColumnDataRecord;
    NarrowWidth            : CARDINAL;

    FullTitle,
    Heading1, Heading2     : ARRAY [0..63] OF CHAR; (* never longer than this. *)
    TotalByRsrc,
    Unique                 : BOOLEAN;



    PROCEDURE WriteAggregate( TheAggType : AnAggType;
                              X, Y       : ASummChoice  );
    VAR
        Aggregator : AnAggregatorRecord;
    BEGIN
        WITH Aggregator DO
            AggType    := TheAggType;
            DataType   := PredicateRecord.DataType;
            Format     := PredicateRecord.Format;
            Dimensions := {};
            DataInFile := TRUE;
            IF (X = AtEnd) THEN INCL(Dimensions,1); END;
            IF (Y = AtEnd) THEN INCL(Dimensions,2); END;
        END;
        WriteRecord( InterFile, AggregatorRecordType, ADR(Aggregator), SIZE(Aggregator) );
    END WriteAggregate;



    PROCEDURE ReadOverallRecord();
    BEGIN
        WITH OverallRecord DO
            Revision     := WordToC(  OverallPhrase, 0 );
            Dimensions   := WordToC(  OverallPhrase, 1 );
            Font         := WordToCh( OverallPhrase, 2 );
            GetMessageWord( OverallPhrase, 3, ReportName );
            UsesSelectFilter := WordToB( OverallPhrase, 4 );
            UsesHighlightFilter := WordToB( OverallPhrase, 5 );
        END;
    END ReadOverallRecord;



    PROCEDURE ReadDomainRecord( DomainPhraseNumber : CARDINAL );
    BEGIN
        WITH DomainRecord DO
            HeadingDepth := WordToC( DomainPhraseNumber, 0  );
            Discrete     := WordToB( DomainPhraseNumber, 1  );
            GetMessageWord( DomainPhraseNumber, 2, DimensionName );
            Width        := WordToC( DomainPhraseNumber, 3  );
        END;
    END ReadDomainRecord;


BEGIN
    StartFileOutput( InterFile, MaxSubfileCount );
    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;

    StartSubfileOutput( InterFile, OverallSubfileNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;

    ReadOverallRecord();
    WriteRecord( InterFile, 1, ADR(OverallRecord), SIZE(OverallRecord) );

    PredicateHeadingRecord.HeadingDepth := PredicateHeadingDepth;
    WriteRecord( InterFile, 2, ADR(PredicateHeadingRecord), SIZE(PredicateHeadingRecord) );

    FOR Loop := 0 TO (OverallRecord.Dimensions - 1) DO
        ReadDomainRecord( DomainBase + Loop );
        WriteRecord( InterFile, 3 + Loop,
                     ADR(DomainRecord), SIZE(DomainRecord) );
    END;
    EndSubfileOutput( InterFile, OverallSubfileNumber );

 (* Write record checks for status of done, but StartSubfileOutput doesn't *)

    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;

    StartSubfileOutput( InterFile, PredicateSubfileNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;

    NextID   := 0;
    (* Note that even though Columns are defined as 1..n, we must reference
       them as 0..n-1 because they are passed to us and the compiler is
       stupid.
    *)
    FOR Loop := 0 TO HIGH( Columns ) DO
        IF (Columns[ Loop ].Width > 0) THEN
            WITH PredicateRecord DO
                INC( NextID );
                ID           := NextID;
                HeadingDepth := 2; (* Always? *)
                Width        := Columns[ Loop ].Width;
                NarrowWidth := Width - 1;
                IF GetInfo( Columns[ Loop ].ColumnNumber, ColumnNarrowWidth,
                            maxcol, ColDataRecord ) THEN
                    NarrowWidth := ColDataRecord.CardinalValue;
                END;

                ColumnHeadings( GetInfo,
                                Columns[ Loop ].ColumnNumber,
                                Name,       FullTitle,
                                Heading1,   Heading2,
                                IsUniqueID, TotalByRsrc, DataType,
                                Format,     DfltWidth );

                IF (NarrowWidth < Width ) THEN

                    (* If the column width is somewhat larger than the
                        full title, use it for the heading rather than the
                        shorter headings.
                    *)
                    IF (Width > (LengthOf( FullTitle ) + 2)) THEN
                        SetString(Heading1,"  "); (* Make it blanks *)
                        Copy( FullTitle, Heading2 );
                    END;
                ELSE
                    IF ( GetInfo(Columns[ Loop ].ColumnNumber,
                            ColumnNarrowHeading1, Width, ColDataRecord) ) THEN
                        Copy(ColDataRecord.StringValue, Heading1);
                    END;
                    IF ( GetInfo(Columns[ Loop ].ColumnNumber,
                            ColumnNarrowHeading2, Width, ColDataRecord) ) THEN
                        Copy(ColDataRecord.StringValue, Heading2);
                    END;
                END;
                IsHeading := IsUniqueID; (* is this always true? *)
                Format.DecimalDigits := CHR( Columns[ Loop ].Decimals );
            END;
            WriteRecord( InterFile, PredicateRecordType, ADR(PredicateRecord), SIZE(PredicateRecord) );

            WITH DataRecord DO
                Font := 0C; (* Default Font *)

                Copy (Prefix, LString);
                ConcatLS( LString, Heading1 );
                WriteIntData( TextType, DataRecord );

                Copy( Heading2, LString );
                WriteIntData( TextType, DataRecord );
            END;

            IF (((TotalByX = AtEnd) OR (TotalByY = AtEnd)) AND (* Predicates desired and numeric? *)
                (PredicateRecord.DataType IN
                        {RealNumberType,IntegerType,CardinalType})) THEN
                WriteAggregate( AggSum, TotalByX, TotalByY );
            END;

        END;
    END;
    EndSubfileOutput( InterFile, PredicateSubfileNumber );

    RETURN (CheckIO( InterFile ) = done);

END GenerateFileHeaders;



(* Generate File Trailers.  Finish up the file I/O.  Don't close the file.
*)

PROCEDURE GenerateFileTrailers() : BOOLEAN;
BEGIN
    EndFileOutput( InterFile );
    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;
    FlushBuffer( InterFile );
    IF (CheckIO( InterFile ) <> done) THEN RETURN FALSE; END;
    SetOpen(       InterFile );
    RETURN (CheckIO( InterFile ) = done);
END GenerateFileTrailers;





  (* Do Dialog - Do a dialog with the customer.

        Preconditions  - MessageBase   is the message's base number.
                         ErrorBox      is TRUE if you want an error box.
                                          FALSE if you want a dialog box.
  *)

PROCEDURE DoDialog( MessageBase : CARDINAL;
                    ErrorBox    : BOOLEAN  );
VAR
    Msg   : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..0]  OF CHAR;
BEGIN
    ReleaseDialog(); (* Release any prior dialog *)
    GetMessage( MessageBase    , Msg   );
    SetLengthOf( Title, 0 );
    IF (ErrorBox) THEN
        MessageRugTaken := FALSE;
        Error( Msg );
    ELSE
        MessageRugTaken := GetRug( 10,8, 70,20, MessageRug );
        MessageBox( Msg, Title );
    END;
END DoDialog;



 (* Release any grabbed message box area. *)

PROCEDURE ReleaseDialog();
BEGIN
    IF (MessageRugTaken) THEN
        MessageRugTaken := FALSE;
        PutRug( 10,8, 70,20, MessageRug );
    END;
END ReleaseDialog;




 (* Common report cleanup code. *)

PROCEDURE CommonCleanup();
VAR
    s        : ARRAY [0..19] OF CHAR;
BEGIN
    ReleaseDialog(); (* Release any pending message. *)
    IF (CheckIO( InterFile ) <> done) THEN
        GetMessage ( ModuleNumber, s );
        (* "Interpass file" *)
        FileComplaint( s,  InterFile );
    END;
END CommonCleanup;





 (* Create The File - Create the interpass file to send to
                      our Dr. Moriarity.

         Preconditions  - FileNameLString is the LString with the file name
                          to create.  The name is not yet expanded.
         Postconditions - RETURNs TRUE iff the file is opened.  Any existing
                          file of the same name is deleted.
  *)
PROCEDURE CreateTheFile( VAR NoLongerUsed : ARRAY OF CHAR ) : BOOLEAN;
VAR
    s           : ARRAY [0..5] OF CHAR;

BEGIN

    SetString (s, "DK:");
    InterFileOpen := CreateTempFile( s, InterFile );
    RETURN InterFileOpen;

END CreateTheFile;



PROCEDURE GetHolderHandle( VAR ProgramName : ARRAY OF CHAR ) : AnExtHandle;

VAR
    Handle              : AnExtHandle;
    TempPointer         : AReportHolderRecordPointer;
    Size,
    Class               : CARDINAL;
    Category            : AHoldTypeSet;
    Found               : BOOLEAN;


    PROCEDURE RemoveObsoleteHeldItems( VAR ProgramName : ARRAY OF CHAR;
                                           Class       : CARDINAL      );

    VAR
        TempPointer         : AReportHolderRecordPointer;
        Size                : CARDINAL;
        Category            : AHoldTypeSet;

    BEGIN
        (* If we found an old-style record, clean it out and any friends too.
           'old' is SPIKE prior to Jan 16, 1988.  RSC.
        *)
        DeleteHeldItem( ProgramName, Class );
        WHILE (LocateHeldItem(ProgramName, Class, Category, TempPointer, Size)) DO
            DeleteHeldItem( ProgramName, Class );
        END;
    END RemoveObsoleteHeldItems;

BEGIN
    Class := 2;
    Found  := LocateHeldItem(ProgramName, Class, Category, TempPointer, Size);
    IF (NOT Found) THEN                                        (* 26-Aug-91 *)
        RETURN AnExtHandle(NIL);
    END;

    Handle := AnExtHandle(TempPointer);

    IF (NOT (HoldInFlexStor IN Category)) THEN
        Handle := AnExtHandle(NIL);                            (* 31-Jul-91 *)
        IF (NOT CreateExtObjectWithSize( Handle, ExtSlow, TSIZE(AReportHolderRecord) )) THEN
            RETURN AnExtHandle(NIL);
        END;
    END;

    IF (Size <> TSIZE(AReportHolderRecord)) THEN
        (* Pretend it isn't there. *)
        IF ((NOT (HoldInFlexStor IN Category)) AND
           (Handle <> AnExtHandle(NIL))) THEN                  (* 03-Sep-91 *)
            DiscardExtObject( Handle );
        END;
        Handle := AnExtHandle(NIL);                            (* 31-Jul-91 *)
        RemoveObsoleteHeldItems( ProgramName, Class );
    ELSIF (NOT (HoldInFlexStor IN Category)) THEN
        IF (SetExtData( Handle, TempPointer, TSIZE(AReportHolderRecord))) THEN
            INCL( Category, HoldInFlexStor );
            (*  Don't move this next line!  It has the effect of trashing
                the data pointed to by TempPointer!
            *)
            RemoveObsoleteHeldItems( ProgramName, Class );
            HoldThis( ProgramName, Class, Category, ADDRESS(Handle), 
                      TSIZE(AReportHolderRecord) );
        ELSE
            RemoveObsoleteHeldItems( ProgramName, Class );
            DiscardExtObject( Handle );
            Handle := AnExtHandle(NIL);
        END;
    END;

    RETURN Handle;

END GetHolderHandle;




PROCEDURE BuildReportHolderRecord( VAR ProgramName        : ARRAY OF CHAR;
                                   VAR LColumns           : ARRAY OF AColumn;
                                       StartDate,
                                       EndDate            : ADate;
                                       Period             : ADurationUnit;
                                       NormalizeIt        : BOOLEAN;
                                       TotalByX,
                                       TotalByY           : ASummChoice;
                                       DatesEntered,
                                       OnlyResources      : BOOLEAN;
                                    VAR TractingCost,
                                        FillScreenValues
                                                           : BOOLEAN
                                 );
VAR
    ReportHolderRecord : POINTER TO AReportHolderRecord;
    Handle             : AnExtHandle;
    TimeInfo           : ATimeInfo;
    Size,
    Class,
    Loop               : CARDINAL;
    Category           : AHoldTypeSet;
    Found              : BOOLEAN;

BEGIN

    Handle := GetHolderHandle(ProgramName);
    Found := (Handle <> AnExtHandle(NIL));                     (* 26-Aug-91 *)
    IF (NOT Found) THEN
        IF (NOT CreateExtObjectWithSize( Handle, ExtSlow, TSIZE(AReportHolderRecord) )) THEN
            RETURN;
        END;
    END;

    Size := LockObject( Handle, ReportHolderRecord );

    WITH ReportHolderRecord^ DO
        IF (HIGH(Columns) < HIGH(LColumns)) THEN FatalError(); END;

        FOR Loop := 0 TO HIGH(LColumns) DO
            Columns[Loop] := LColumns[Loop];
        END;
        FOR Loop := HIGH(LColumns) + 1 TO HIGH(Columns) DO
            WITH Columns[Loop] DO
                Width        := 0;  (* Include no columns for now. *)
                ColumnNumber := MAXCARDINAL;
                Decimals     := 0;
            END;
        END;

        TimeUtoT( StartDate, TimeInfo);
        TimeToBigTime
        (
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            0,
            RptStart
        );
        TimeUtoT( EndDate, TimeInfo );
        TimeToBigTime
        (
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            0,
            RptEnd
        );

        RptPeriod        := Period;
        Normalize        := NormalizeIt;
        TotalByRow       := TotalByY;
        TotalByCol       := TotalByX;
        DatesWereEntered := DatesEntered;
        ResourcesOnly    := OnlyResources;
        EffortOrCost     := TractingCost;
        FillValuesOnScrn  := FillScreenValues;
    END;

    ReleaseObject( Handle );

    IF (NOT Found) THEN
        Class := 2;
        Category := AHoldTypeSet{HoldInDataFile,
                                 HeapNoOwner,
                                 HoldInFlexStor,    (* 23-Jan-91 RSC *)
                                 HoldInConfig};
        HoldThis( ProgramName, Class, Category,
                  ADDRESS(Handle), TSIZE(AReportHolderRecord));
    END;

END BuildReportHolderRecord;





PROCEDURE DigestReportHolderRecord( VAR ProgramName        : ARRAY OF CHAR;
                                    VAR LColumns           : ARRAY OF AColumn;
                                    VAR StartDate,
                                        EndDate            : ADate;
                                    VAR Period             : ADurationUnit;
                                    VAR NormalizeIt        : BOOLEAN;
                                    VAR TotalByX,
                                        TotalByY           : ASummChoice;
                                    VAR DatesEntered,
                                        OnlyResources      : BOOLEAN ;
                                    VAR TractingCost,
                                        FillScreenValues
                                                           : BOOLEAN
                                  );
VAR
    ReportHolderRecord : POINTER TO AReportHolderRecord;
    Handle             : AnExtHandle;
    TimeInfo           : ATimeInfo;
    Size,
    Loop               : CARDINAL;
    Found,
    ok                 : BOOLEAN;

BEGIN

    Handle := GetHolderHandle(ProgramName);

    IF (Handle = AnExtHandle(NIL)) THEN     (* Default initialization *)
        FOR Loop := 0 TO HIGH(LColumns) DO
            WITH LColumns[Loop] DO
                Width        := 0;  (* Include no columns for now. *)
                ColumnNumber := MAXCARDINAL;
                Decimals     := 0;
            END;
        END;
        StartDate     := MinDate;
        EndDate       := MinDate;
        Period        := Days;
        NormalizeIt   := FALSE;
        TotalByY      := None;
        TotalByX      := None;
        DatesEntered  := FALSE;
        OnlyResources := TRUE;
        TractingCost     := FALSE;
        FillScreenValues := TRUE;       (* KKC Sep 11, 89 *)
        RETURN;
    END;

    Size := LockObject( Handle, ReportHolderRecord );

    WITH ReportHolderRecord^ DO
        IF (HIGH(Columns) < HIGH(LColumns)) THEN FatalError(); END;

        FOR Loop := 0 TO HIGH(LColumns) DO
            LColumns[Loop] := Columns[Loop];
        END;

        BigTimeToTime
        (
            RptStart,
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            TimeInfo.tiSecond
        );
        ok := TtoTimeU( TimeInfo, StartDate );
        BigTimeToTime
        (
            RptEnd,
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            TimeInfo.tiSecond
        );
        ok := TtoTimeU( TimeInfo, EndDate );

        Period        := RptPeriod;
        NormalizeIt   := Normalize;
        TotalByY      := TotalByRow;
        TotalByX      := TotalByCol;
        DatesEntered  := DatesWereEntered;
        OnlyResources := ResourcesOnly;
        TractingCost     := EffortOrCost;
        FillScreenValues := FillValuesOnScrn;
    END;

    ReleaseUnchangedObject( Handle );

END DigestReportHolderRecord;





BEGIN

    GlobalPhrase    := 0;
    MessageRugTaken := FALSE;
    TotalByX        := None;
    TotalByY        := None;
    ColumnTree      := ATreeNode(NIL);
    RsrcBaseLine    := TRUE;

END RptCommon.



