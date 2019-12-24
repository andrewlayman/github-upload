IMPLEMENTATION MODULE SaveCommon;

(*  =========================================================================
    Last Edit : February 5, 1991 3:44PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:
        Save Common - common code for saving the schedule and the config file.


    MODIFICATION HISTORY:

       EVE - 5.0

       30-Mar-90 RSC    Made Timeu to Timei/TimeForm conversions.
       19-Apr-90 KKC    Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
       15-Aug-90 RSC    Adjust version number and other tweaks to make reading
                        and writing work.
       18-Sep-90 RSC    Added KeepEffortContiguous.
        4-Oct-90 RSC    Changed Smoothing to RecalcOptions.
       26-Oct-90 PFG    Move SaveColumnNames here from TLXCnfg so column
                        names can be in schedule files as well as config.
        1-Nov-90 RSC    Save the NEW calendar.
       13-Nov-90 RSC    Save the fixed task defaults.
        9-Jan-90 AJL   -Change WriteText to use a new format for saving texts,
                        where blank lines are skipped and each line is stored
                        with a line number.
                       -Store all texts which we control with a type of 102 
                        to distinguish them from texts stored in the old 
                        format.
       21-Jan-91 RSC    Removed fiscal calendar.
       24-Jan-91 RSC    Added "Zapsave" text saving.
       22-Jan-91 AJL   -Update the text type numbers used in SaveColumnNames
                        to reflect the new text format.  New numbers = Old + 10;
        2-Apr-91 TGS   -FileFormatVersion is now 500.
       18-Jun-91 AJL   -Store the as-of date in calendar-independent format.
    =========================================================================
*)


    FROM Allocs       IMPORT
        (* TYPE  *)          ATaskPtr,
        (* PROC  *)          CheckTaskValid;

    FROM AsOf         IMPORT  AsOfDate, AsOfSettingOption;

    FROM Assignments  IMPORT
        (* TYPE *)            AnAssignmentAttribute, AnAssignmentAttributeSet,
                              AnAssignmentRecord, AnAssignmentArray;

    FROM BigTimeU     IMPORT
        (* Type *)            ABigTime,
        (* Proc *)            TimeToBigTime;

    FROM Changer      IMPORT
        (* VAR *)            AdvancedTaskForm, UsesCostTracking;

    FROM Chart        IMPORT
        (* VAR  *)            GanttChart;

    FROM ChartControl IMPORT
        (* TYPE *)            AChartState, AChartStateSet,
        (* VARS *)            ChartState;

    FROM ChartForms   IMPORT
        (* TYPE *)            AChartFormatPtr,
        (* VAR *)             CurrentChartFormat, LayoutTree,
        (* PROCS *)           CurrentLayout;

    FROM ColData       IMPORT
    (* TYPE  *)             AColumnType,
    (* VAR   *)             ColumnTable;

    FROM ExportLinkage IMPORT
        (* VARS *)      NewFile,
                        SaveConfiguration, SaveSchedule, SelectiveSave;

    FROM FileAux      IMPORT FileResultMeans,
                             FlushBuffer, PrepareForIO, CheckIO,
                             OverlayPath;

    FROM FileSystem   IMPORT  File, Lookup, Response, Close,
                              WriteChar, Create, Rename, Delete;

    FROM FilterRc     IMPORT
        (* TYPE *)             AFilterRecordPointer, AFltrSet, AFltrType,
        (* VAR *)              RevealFilter, HighlightFilter,
                               FilterTree;

    FROM Filters      IMPORT
         (* PROC *)            QueryRevealFilterOn;

    FROM FlexStor     IMPORT
        (* TYPE *)            AnExtHandle,
        (* PROC *)            LockObject, ReleaseObject, ReleaseUnchangedObject;

    FROM Holder       IMPORT  ForAllHeldItems, AHoldType, AHoldTypeSet;

    FROM IlsaStatic   IMPORT
        (* TYPE *)           ATLGSChartType, ATLGSColorAssignment,
                             ATLGSColorAssignmentPtr,
        (* VAR *)            PaletteTree;

    FROM Kbio         IMPORT soundon,
                             Tone, vidctrl,
                             VersionString, TamperedFlag, maxcol;

    FROM LStrings     IMPORT SetString, ConcatLS, ConcatS, CtoS, StoC,
                             SubStr, LStringToTString, TStringToLString,
                             Fill, Compare, Upshift, TrimRear, Copy,
                             Procustes, LengthOf, Search, Remove, SetLengthOf;

    FROM Memos        IMPORT
                              MemoTree, AMemoRecordPointer;

    FROM NetLayouts   IMPORT
        (* TYPE *)         ANetworkLayout, ANetworkLayoutRecord,
        (* VAR *)          NetLayoutTree, CurrentNetLayout, EnlargedNetLayout;

    FROM NetworkData  IMPORT
        (* VAR *)          AnnealingChoice, NetworkType;

    FROM Planner      IMPORT
        (* TYPE *)         ACalculationState, AWhenToCalc, ACalcComponent,
        (* VAR *)          CalculationState, Levelling, RecalcOptions, 
                           MoveFutureTasks, TimeConstrained, HonorDaysOff,
                           ScheduleComputedOk, KeepEffortContiguous;

    FROM RecordIO     IMPORT  WriteRecord, WriteString;

    FROM SaveAscii    IMPORT  SaveBoolean, SaveCardinal, SaveReal,
                              SaveTimeUnit;

    FROM Schedule   IMPORT
                           ZeroIsLowestPriority,
                           ConfigSaved, ScheduleSaved, ProjectMedia,
                           RetrievalName, ProjectName, Loaded,
                           FixedDateRules;

    FROM Subfiles     IMPORT  StartSubfileOutput, EndSubfileOutput;

    FROM SYSTEM     IMPORT TSIZE, SIZE, ADR, ADDRESS;

    FROM Text       IMPORT
        (* TYPE *)      AText,
        (* PROC *)      ForEachLine;

FROM TimeFormat   IMPORT
    (* TYPE *)          ADateString,
    (* VAR *)           DefaultDateOption, EndDateStyle;

FROM Timei        IMPORT
    (* TYPE *)          ADate, ADuration, ADurationUnit, ATimeInfo,
    (* VAR  *)          Today,
    (* PROC *)          FindToday, TtoTimeU, TimeUtoT;

FROM Timeu        IMPORT
    (* CONST *)         SMUPH,
    (* TYPE *)          ATimeTable, AYearTable,
    (* VAR  *)          TimeTable, WeeksBeginOn,
    (* PROC *)          SetSMU, SetStartingMonth, GetStartingMonth;

    FROM Transfer   IMPORT AHeaderRecord, BackupsToKeep;

    FROM TreeObjects  IMPORT
        (* TYPE *)            ATree, ATreeNode, ATreeOrder,
                              ATreeNodeProcessingProc,
        (* PROC *)            ValidateTree, ValidateTreeNode;

    FROM Undo                   IMPORT
        (* PROC *)                  GetUndoLimit, FlushUndos;


CONST
    FileFormatVersion      = 500;   (* Version 5.0 of the file format. *)


     ProjectType           = 1;
     EnvironmentType       = 2;
     PrintFileType         = 3;
     SummaryType           = 4;
     ResourceType          = 5;
     TaskType              = 6;
     EdgeType              = 8;
     CalendarType          = 9;
     BugsType              = 10;
     SignatureType         = 11;
     PrinterTableType      = 12;
     FileNamesType         = 13;
     VideoType             = 14;
     PreferencesType       = 15;
     CodeSetsType          = 16;
     FontsType             = 17;
     PlotsType             = 18; (* RSC 8/14/87 from PlotGo *)
     FiltersType           = 19;
     HeldItemsType         = 20;
     MemosType             = 21;
     LayoutsType           = 23;
     NetLayoutsType        = 24;                                  (* 16-Nov-87 LAA *)
     TLGSDeviceType        = 25;                                  (* 21-May-89 LAA *)
     PalettesType          = 26;  (* Actually, 26, 27 and 28 because of 3 trees *)
     ColumnNamesType       = 29;

     ResourceFileVersionNumber   = 1;
     TaskFileVersionNumber       = 9;
     EdgeFileVersionNumber       = 6;
     EnvironmentVersionNumber    = 17;
     CalendarFileVersionNumber   = 1;
     BugsFileVersionNumber       = 1;

     MAXCARDINAL = 65535;
     MAXDATE     = MAXCARDINAL;

TYPE
    AContext = POINTER TO CARDINAL;         (* For SaveFilters *)


VAR
    GlobalHoldType : AHoldType;
    SequenceNumber : INTEGER;


PROCEDURE SaveOneHeldItem( Name      : ARRAY OF CHAR;
                           Class     : CARDINAL;
                           Category  : AHoldTypeSet;
                           Where     : ADDRESS;
                           Size      : CARDINAL );
VAR
    FlexItem  : ADDRESS;
BEGIN
        (* Note that f is GLOBAL here. *)
    IF (GlobalHoldType IN Category) THEN
        WriteString(f,1,Name);
        WriteRecord(f,2,ADR(Class),SIZE(Class));
        WriteRecord(f,3,ADR(Category),SIZE(Category));
        IF (HoldInFlexStor IN Category) THEN            (* RSC 8/16/88 *)
            Size := LockObject( AnExtHandle(Where), FlexItem );
            WriteRecord(f,4,FlexItem,Size);
            ReleaseUnchangedObject(AnExtHandle(Where));
        ELSE
            WriteRecord(f,4,Where,Size);
        END;
    END;
END SaveOneHeldItem;




PROCEDURE SaveHeldItems( HoldType : AHoldType );
BEGIN
    GlobalHoldType := HoldType;
    StartSubfileOutput(f,HeldItemsType,1);
    ForAllHeldItems(SaveOneHeldItem);
    EndSubfileOutput(f,HeldItemsType);
END SaveHeldItems;





PROCEDURE WriteDate(VAR f:File; Date:ADate; Type:CARDINAL);
VAR BigTime    : ABigTime;
    TimeInfo   : ATimeInfo;
BEGIN
    TimeUtoT(Date,TimeInfo);
    TimeToBigTime
    (
        TimeInfo.tiYear,
        TimeInfo.tiMonth,
        TimeInfo.tiDay,
        TimeInfo.tiHour,
        TimeInfo.tiMinute,
        0,
        BigTime
    );
    WriteRecord(f,Type,ADR(BigTime),SIZE(BigTime));
END WriteDate;






PROCEDURE SaveFileNames();
VAR
    i : CARDINAL;
    s : ARRAY [0..9] OF CHAR;
BEGIN
    SetString( s, "." );
    i := Search( ProjectName, s, 1 );   (* 28-Sep-89 WKH All refrences to *)
    IF (i=0) THEN                       (* Export changed to Project      *)
        i := ORD(ProjectName[0]) + 1;
    END;
    SubStr( ProjectName, s, 1, i-1 );
    StartSubfileOutput(f,FileNamesType,1);
    WriteString(f,0,s); (* Project name, or name we are saving as. *)
    WriteString(f,1,ProjectMedia);
    WriteString(f,2,OverlayPath);
    EndSubfileOutput(f,FileNamesType);
    Copy(s, RetrievalName);
END SaveFileNames;







PROCEDURE SaveSignature();
VAR
    FileVersion : CARDINAL;
BEGIN
    FileVersion := FileFormatVersion;

    StartSubfileOutput(f,SignatureType,1);
    WriteString(f,0,VersionString);
    WriteDate(f,Today,2);
    WriteRecord(f,10,ADR(FileVersion),SIZE(FileVersion));
    EndSubfileOutput(f,SignatureType);
END SaveSignature;










PROCEDURE SaveColumnNames();        (* 10-Sep-90 PFG  *)

VAR
    ColumnType  :   AColumnType;
    i           :   CARDINAL;

BEGIN
    StartSubfileOutput(f, ColumnNamesType, 1);

    i := 0;
    FOR ColumnType := MIN(AColumnType) TO MAX(AColumnType) DO
        WriteText (f, ColumnTable[ColumnType], 10+i);
        INC(i);
    END;

    EndSubfileOutput(f,ColumnNamesType);
END SaveColumnNames;








(* 1-Nov-90 RSC Save entire TimeTable.  If its format changes, there will
                have to be a conversion anyway.
*)
PROCEDURE SaveCalendar();
VAR
    StartingMonth : CARDINAL;
BEGIN
    StartSubfileOutput(f,CalendarType,CalendarFileVersionNumber);

    WriteRecord(f,2,ADR(SMUPH),SIZE(SMUPH));

    WriteRecord(f,7,ADR(DefaultDateOption),SIZE(DefaultDateOption));
    WriteRecord(f,8,ADR(WeeksBeginOn),SIZE(WeeksBeginOn));      (* 3/27/87 EGK *)
    GetStartingMonth(StartingMonth);
    WriteRecord(f,9,ADR(StartingMonth),SIZE(StartingMonth));
    WriteRecord(f,10,ADR(EndDateStyle),SIZE(EndDateStyle));

    WriteRecord(f,20,ADR(TimeTable),SIZE(TimeTable));

    EndSubfileOutput(f,CalendarType);

END SaveCalendar;










PROCEDURE SaveTheEnvironment();
VAR
    UndoLimit,
    i, j                : CARDINAL;
    TempCalcState       : ACalculationState;           (* 3/22/89 EGK *)
    TempChartState      : AChartStateSet;       (* 28-Sep-89 RSC *)
    Scroll              : BOOLEAN;

BEGIN
    StartSubfileOutput(f,EnvironmentType,EnvironmentVersionNumber);

    UndoLimit := GetUndoLimit(); (* RSC 10/29/87 *)

    WriteRecord(f,1,ADR(BackupsToKeep),SIZE(BackupsToKeep));

    WriteRecord(f,9,ADR(AsOfSettingOption),SIZE(AsOfSettingOption));        (* 3/27/87 EGK *)
    (* WriteRecord(f,10,ADR(AsOfDate),SIZE(AsOfDate)); *)                   (* AJL 18-Jun-91 *)
    WriteRecord(f,11,ADR(ZeroIsLowestPriority),SIZE(ZeroIsLowestPriority));
    WriteRecord(f,12,ADR(AdvancedTaskForm),SIZE(AdvancedTaskForm));
    WriteRecord(f,13,ADR(UndoLimit),SIZE(UndoLimit));
        (* Store the as-of date in calendar-independent format. *)
    WriteDate  (f,AsOfDate,14);

    Scroll := GanttChart^.Methods^.QueryScrollMode(GanttChart);
    WriteRecord(f, 21, ADR(Scroll), SIZE(Scroll));

    WriteRecord(f, 22, ADR(TimeConstrained), SIZE(TimeConstrained));
    WriteRecord(f, 23, ADR(MoveFutureTasks),SIZE(MoveFutureTasks));
    WriteRecord(f, 24, ADR(UsesCostTracking),SIZE(UsesCostTracking));

    WriteRecord(f, 25, ADR(AnnealingChoice),SIZE(AnnealingChoice)); (* 5/26/89 EGK *)
    WriteRecord(f, 26, ADR(NetworkType),SIZE(NetworkType));

    (* 28-Sep-89 RSC: If CALC ERR, pretend we need a recalc. *)

    TempChartState := ChartState;

    IF (NOT ScheduleComputedOk) THEN
        EXCL( TempChartState, Scheduled );
    END;

    WriteRecord(f, 27, ADR(TempChartState), SIZE(TempChartState)); (* 16-Jun-89 LAA *) (* 28-Sep-89 RSC *)

        (* Planner module *)
        (* If we save a partial schedule, we turn recalc off so that we
           do not instruct the next program that reads it to recalc.  That
           would probably lead to a very different calculation than if the 
           full data model were present. *)
    TempCalcState := CalculationState;
    IF (SelectiveSave) AND (TempCalcState[Scheduling].When = AutoCalc) THEN
        TempCalcState[Scheduling].When := ManualCalc;  
    END;
    WriteRecord(f, 28, ADR(TempCalcState),SIZE(TempCalcState));
    WriteRecord(f, 29, ADR(Levelling),SIZE(Levelling));
    WriteRecord(f, 30, ADR(RecalcOptions),SIZE(RecalcOptions));
    WriteRecord(f, 31, ADR(HonorDaysOff),SIZE(HonorDaysOff));
    WriteRecord(f, 32, ADR(KeepEffortContiguous),SIZE(KeepEffortContiguous));

        (* 13-Nov-90 RSC *)
    WriteRecord(f, 33, ADR(FixedDateRules),SIZE(FixedDateRules));

    EndSubfileOutput(f,EnvironmentType);

END SaveTheEnvironment;







TYPE
    AWriteTextContext = RECORD
        f       : POINTER TO File;
        TheType : CARDINAL;
        Line    : CARDINAL;
    END;


PROCEDURE PutLineProc( VAR s : ARRAY OF CHAR;
                           A : ADDRESS ) : BOOLEAN;
VAR
    Context     : POINTER TO AWriteTextContext;

    Length      : CARDINAL; 
    TextRecord  : RECORD
                      LineNumber : CARDINAL;
                      s          : ARRAY [0..255] OF CHAR;
                  END;
BEGIN
    Context := A;
    WITH Context^ DO
        (* Write only the lines which exist, as a record that is the 
           line number, a length byte, and the string. *)

        Length := LengthOf(s);
        IF (Length > 0) THEN
            Copy(s, TextRecord.s);
            TextRecord.LineNumber := Line;
            WriteRecord(f^, TheType, ADR(TextRecord),SIZE(CARDINAL)+1+Length);
        END;

        INC(Line);

        RETURN (CheckIO(f^) = done);
    END;

END PutLineProc;



(*----------------------------------------------------------------------------
    WriteText --

    Write the text to the file, giving each record the type specified.
----------------------------------------------------------------------------*)

PROCEDURE WriteText(VAR F                   : File;                (* in/out *)
                        Text                : AText;               (* in/out *)
                        Type                : CARDINAL);           (* in     *)

VAR
    Context     : AWriteTextContext;
    ok          : BOOLEAN;
BEGIN                       (* WriteText *)
        (* 24-Jan-91 RSC Use new Text call to speed up output.
        *)
    WITH Context DO
        f       := ADR(F);
        TheType := Type;
        Line    := 0;
    END;

    ok := ForEachLine( PutLineProc, ADR(Context), Text );

END WriteText;





PROCEDURE WriteTaskID(VAR f : File; TaskNode : ATreeNode; Type:CARDINAL);
VAR
    Task : ATaskPtr;
    V    : CARDINAL;
BEGIN
    V := 0;
    IF (TaskNode <> NIL) THEN
        CheckTaskValid(TaskNode);
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        V    := Task^.TaskID;
        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
    END;
    WriteRecord(f,Type,ADR(V),SIZE(V));
END WriteTaskID;






PROCEDURE WriteFilterName (VAR f          : File;
                               Type       : CARDINAL;
                               FilterNode : ATreeNode );
VAR
    Filter  : AFilterRecordPointer;
    Name    : ARRAY [0..20] OF CHAR;
BEGIN
    SetLengthOf (Name, 0);
    IF (FilterNode <> NIL) THEN
        Filter := FilterNode^.Methods^.LockFlexStorDataObject(FilterNode);
        Copy (Filter^.Name, Name);
        FilterNode^.Methods^.UnlockUnchangedDataObject(FilterNode);    Filter := NIL;
    END;
    WriteString(f,Type,Name);
END WriteFilterName;




PROCEDURE WriteLayoutName (VAR f          : File;
                               Type       : CARDINAL;
                               LayoutNode : ATreeNode );
VAR
    Layout  : AChartFormatPtr;
    Name    : ARRAY [0..20] OF CHAR;
BEGIN
    SetLengthOf (Name, 0);
    IF (LayoutNode <> NIL) THEN
        Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);
        Copy (Layout^.Name, Name);
    END;
    TrimRear(Name);         (* 22-Aug-89 WKH *)
    WriteString(f,Type,Name);
END WriteLayoutName;




PROCEDURE WriteNetLayoutName (VAR f          : File;
                                  Type       : CARDINAL;
                                  LayoutNode : ATreeNode );
VAR
    Layout  : ANetworkLayout;
    Name    : ARRAY [0..20] OF CHAR;

BEGIN
    SetLengthOf (Name, 0);
    IF (LayoutNode <> NIL) THEN
        Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);
        Copy (Layout^.Name, Name);
    END;
    TrimRear(Name);         (* 22-Aug-89 WKH *)
    WriteString (f,Type,Name);
END WriteNetLayoutName;




PROCEDURE WriteNodeInfo  ( VAR  f           : File;
                                Node        : ATreeNode;
                                ParentID    : CARDINAL;
                                Offset      : CARDINAL  );
VAR
    Header              : AHeaderRecord;

BEGIN
    Header.ParentID := ParentID;
    Header.Level := Node^.Methods^.IndentationLevel (Node);
    IF (Offset > Header.Level) THEN
        Header.Level := 0;
    ELSE
        DEC (Header.Level, Offset);             (* 3/17/89 EGK *)
    END;
    Header.Attributes := Node^.Methods^.GetAttributes (Node);
    WriteRecord (f, 0, ADR(Header), SIZE(Header));
END WriteNodeInfo;





PROCEDURE SaveOneFilter(VAR FilterNode  : ATreeNode;
                            Where       : AContext  );
VAR
    Filter          : AFilterRecordPointer;

BEGIN                       (* WriteFilterRecord *)
    ValidateTreeNode(FilterNode);

    Filter := FilterNode^.Methods^.LockFlexStorDataObject(FilterNode);

    INC (SequenceNumber);
    Filter^.ID := SequenceNumber;

    IF (Where^ = 1) AND (0 IN Filter^.FilterFlags) THEN
        FilterNode^.Methods^.UnlockFlexStorDataObject(FilterNode);      Filter := NIL;
        RETURN;
    END;

    IF (Where^ IN Filter^.FilterFlags) THEN
        WriteNodeInfo (f, FilterNode, 0, 0);
        WriteRecord(f, 1, Filter, SIZE(Filter^));
        WriteTaskID(f, Filter^.antetask, 2);
        WriteTaskID(f, Filter^.desctask, 3);
        WriteDate(f, Filter^.startdate, 4);
        WriteDate(f, Filter^.enddate, 5);
        WriteText(f, Filter^.Notes, 102);
    END;

    FilterNode^.Methods^.UnlockFlexStorDataObject(FilterNode);      Filter := NIL;

END SaveOneFilter;



(*$O-*)         (* I never did trust the optimizer with this stuff. *)

PROCEDURE SaveFilters ( Where : CARDINAL );   (* 12/12/86 LAA *)
VAR
    WhichType           : CARDINAL;
    RevealFilterOn      : BOOLEAN;

BEGIN                       (* SaveFilters *)
    SequenceNumber := 0;

    StartSubfileOutput (f, FiltersType, 1);

    RevealFilterOn := QueryRevealFilterOn();
    WriteRecord (f, 20, ADR(RevealFilterOn), SIZE(RevealFilterOn));

    ValidateTree(FilterTree);

    WhichType := 1;
    FilterTree^.Methods^.TraverseTree (FilterTree, ParentBeforeChild, 9999,
            ATreeNodeProcessingProc (SaveOneFilter), ADR(Where));

    IF (NOT SelectiveSave) THEN
        WriteFilterName (f, 30, RevealFilter);                  (* 3/1/88 EGK *)
    END;
    WriteFilterName (f, 31, HighlightFilter[3]);
    WriteFilterName (f, 32, HighlightFilter[4]);
    WriteFilterName (f, 33, HighlightFilter[5]);

    IF (HighlightFilter[1] <> NIL) THEN                           (* 16-Jun-89 LAA *)
        SaveOneFilter (HighlightFilter[1], ADR(Where));
        SaveOneFilter (HighlightFilter[2], ADR(Where));
    END;

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f, FiltersType);
    END;

END SaveFilters;

(*$O=*)







PROCEDURE SaveOneLayout(VAR LayoutNode  : ATreeNode;
                            Where       : AContext  );
VAR
    Layout          : AChartFormatPtr;

BEGIN                       (* WriteLayoutRecord *)
    ValidateTreeNode(LayoutNode);

    Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);

    INC (SequenceNumber);
    Layout^.ID := SequenceNumber;

    IF (Where^ = 1) AND (0 IN Layout^.LayoutFlags) THEN
        RETURN;
    END;

    IF (Where^ IN Layout^.LayoutFlags) THEN
        WriteNodeInfo (f, LayoutNode, 0, 0);
        WriteRecord(f, 1, Layout,
                    SIZE(Layout^)-SIZE(Layout^.ColumnSpec));
        WriteRecord (f, 2, ADR(Layout^.ColumnSpec), SIZE(Layout^.ColumnSpec));
        WriteText(f, Layout^.Notes, 102);
    END;

END SaveOneLayout;



PROCEDURE SaveLayouts ( Where : CARDINAL );

BEGIN                       (* SaveLayouts *)
    SequenceNumber := 0;

    StartSubfileOutput (f, LayoutsType, 1);

    ValidateTree (LayoutTree);

    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild, 9999,
            ATreeNodeProcessingProc(SaveOneLayout), ADR(Where));

    WriteLayoutName (f, 30, CurrentChartFormat);        (* 3/1/88 EGK *)

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f, LayoutsType);
    END;

END SaveLayouts;







PROCEDURE SaveOneNetLayout(VAR LayoutNode  : ATreeNode;
                               Where       : AContext  );

VAR
    Layout          : ANetworkLayout;

BEGIN                       (* SaveOneNetLayout *)

    ValidateTreeNode(LayoutNode);

    Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);

    INC (SequenceNumber);
    Layout^.ID := SequenceNumber;

    IF (Where^ = 1) AND (0 IN Layout^.NetLFlags) THEN
        RETURN;
    END;

    IF (Where^ IN Layout^.NetLFlags) THEN
        WriteNodeInfo (f, LayoutNode, 0, 0);
        WriteRecord(f, 1, Layout, SIZE(Layout^));
        WriteText(f, Layout^.Notes, 102);
    END;

END SaveOneNetLayout;



PROCEDURE SaveNetLayouts ( Where : CARDINAL );

BEGIN                       (* SaveNetLayouts *)
    SequenceNumber := 0;

    StartSubfileOutput (f, NetLayoutsType, 1);

    ValidateTree (NetLayoutTree);

    WITH NetLayoutTree^.Methods^ DO
        TraverseTree (NetLayoutTree, ParentBeforeChild, 9999,
                      ATreeNodeProcessingProc(SaveOneNetLayout), ADR(Where));
    END;

    WriteNetLayoutName (f, 40, CurrentNetLayout);           (* 3/1/88 EGK *)
    WriteNetLayoutName (f, 50, EnlargedNetLayout);

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f, NetLayoutsType);
    END;

END SaveNetLayouts;




PROCEDURE SaveOnePalette(VAR PaletteNode    : ATreeNode;
                             Where          : AContext);
VAR
    Palette                 : ATLGSColorAssignmentPtr;

BEGIN                       (* SaveOnePalette *)

    ValidateTreeNode(PaletteNode);

    Palette := PaletteNode^.Methods^.LockFlexStorDataObject(PaletteNode);

    IF (Where^ = 1) AND (0 IN Palette^.PaletteFlags) THEN
        PaletteNode^.Methods^.UnlockUnchangedDataObject(PaletteNode);
        RETURN;
    END;

    INC (SequenceNumber);
    Palette^.ID := SequenceNumber;

    IF (Where^ IN Palette^.PaletteFlags) THEN
        WriteNodeInfo (f, PaletteNode, 0, 0);
        WriteRecord(f, 1, Palette, TSIZE(ATLGSColorAssignment));
        WriteText(f, Palette^.Notes, 102);
    END;

    PaletteNode^.Methods^.UnlockFlexStorDataObject(PaletteNode);

END SaveOnePalette;



(*$O-*)   (*  Oops!  An array of pointers - bad for optimizer! *)


PROCEDURE SavePalettes (    Kind            : ATLGSChartType;
                            Where           : CARDINAL      );

BEGIN                       (* SavePalettes *)

    SequenceNumber := 0;

    IF (PaletteTree[Kind]^.Methods^.GetFirst(PaletteTree[Kind])
       = ATreeNode(NIL)) THEN
        RETURN;
    END;

    StartSubfileOutput (f, PalettesType + ORD(Kind), 1);

    ValidateTree (PaletteTree[Kind]);

    PaletteTree[Kind]^.Methods^.TraverseTree (PaletteTree[Kind],
                                              ParentBeforeChild,
                                              9999,
                                      ATreeNodeProcessingProc(SaveOnePalette),
                                              ADR(Where));

    IF (CheckIO(f) = done) THEN
        EndSubfileOutput(f, PalettesType + ORD(Kind));
    END;

END SavePalettes;

(*$O=*)





PROCEDURE SaveOneMemo(VAR MemoNode      : ATreeNode;
                          Where         : AContext  );

VAR
    Memo                    : AMemoRecordPointer;
    Text                    : AText;

BEGIN                       (* SaveOneMemo *)

        (*  Note that f is a global parameter  *)

    ValidateTreeNode(MemoNode);

    Memo := MemoNode^.Methods^.GetDataObject(MemoNode);

    INC(SequenceNumber);
    Memo^.ID := SequenceNumber;

    IF (Where^ IN Memo^.MemoFlags) THEN
        WriteNodeInfo (f, MemoNode, 0, 0);
        WriteRecord (f, 1, Memo, SIZE(Memo^));
        WriteText (f, Memo^.text, 102);
    END;

END SaveOneMemo;




PROCEDURE SaveMemos (Where : CARDINAL);

BEGIN                       (* SaveMemos *)
    SequenceNumber := 0;

    StartSubfileOutput(f, MemosType, 1);
    ValidateTree(MemoTree);

    MemoTree^.Methods^.TraverseTree(MemoTree,ParentBeforeChild,9999,
            ATreeNodeProcessingProc(SaveOneMemo), ADR(Where));

    IF (CheckIO(f)=done) THEN
        EndSubfileOutput(f, MemosType);
    END;

END SaveMemos;







PROCEDURE SaveCommonData( HoldType : AHoldType; Where : CARDINAL );
VAR
    i  : CARDINAL;
    ok : BOOLEAN;
BEGIN

    i := 0;
    LOOP
        ok := (CheckIO(f) = done);
        IF (NOT ok) THEN EXIT; END;
        CASE i OF
            0:  SaveSignature();
          | 1:  SaveFileNames();
          | 2:  SaveHeldItems( HoldType );
          | 3:  SaveTheEnvironment();
          | 4:  SaveCalendar();
          | 5:  SaveFilters( Where );
          | 6:  SaveMemos(   Where );
          | 7:  SaveLayouts( Where );
          | 8:  SaveNetLayouts(Where);
          | 9:  SavePalettes(TLGSGanttChart, Where);
                SavePalettes(TLGSPertChart, Where);
                SavePalettes(TLGSTreeChart, Where);
          | 10: SaveColumnNames();          (* 26-Oct-90 PFG *)
        ELSE
            EXIT;
        END;
        INC(i);
    END;

END SaveCommonData;





END SaveCommon.

