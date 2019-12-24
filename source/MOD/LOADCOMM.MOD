IMPLEMENTATION MODULE LoadCommon;



(*  =========================================================================
    Last Edit : August 19, 1991 11:46AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Load elements common to config and schedule files.

    MODIFICATION HISTORY:

       Sep. 3, 1985  AL  - Added support for DefaultDateFormat.
       10/31/86 LAA     Removed all references to AGlanceStyle, etc. for
                        the Time LIne version.  It now exists only for Plot
                        Line.
        3/27/87 EGK     Added code to read in As-of date, As-of setting,
                        First fiscal month, and First day of week.
        19-May-87 LAA   Commented out the code which reads in the
                        CurrentChartFormat and DefinedChartFormat from the
                        schedule file.
        21-May-87 LAA   CurrentChartFormat is now exported from ChartForms.
        05-Aug-87 LAA   Commented out reading in of CurrentChartFormat;
        9/4/87    RSC   Added AdvancedTaskForm to the environment.
        23-Sep-87 LAA   Imported AHeaderRecord from Transfer; it used to be
                        defined in this module's DEF.
        05-Oct-87 RSC   When importing the fiscal calendar, remember if it
                        WAS loaded so that TlInit can initialize it if it
                        wasn't found.
                        Also, on Filter and Layout readings, when duplicates
                        are found, ONLY overwrite if original item DID NOT
                        come from the config file AND the user says to
                        Override the original items.
        09-Oct-87 RSC   Import EndDateStyle with calendar.
        30-Oct-87 RSC   Load UndoLimit with environment.
        17-Nov-87 LAA   Loaded the NetLayouts and AnimationRecord which is
                        now saved into the config and schedule files.
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        15-Jan-88 LAA   Fixed a bug with the saved current layout not becoming
                        the current layout when a schedule is read in.  This
                        would only happen if there was already a copy of that
                        layout in memory.  Also fixed things like this with
                        filters and network layouts.
        26-Jan-88 RSC   Moved in "GetHeldItems" to here.
        18-Feb-88 LAA   Compress all texts after they are read in.
        22-Feb-88 RSC   Implement GetSignature()
        26-Feb-88 EGK   Accommodate new parameter to GetFiltersInfo and
                        GetLayoutsInfo (do we read in current selections?).
         1-Mar-88 EGK   Wrote new procedures to handle reading in current
                        selections of layouts and filters as names instead
                        of numbers.  Left the old code in to allow for upward
                        compatibility of our files.
         4-Aug-88 EGK   At end of GetFiltersInfo, make sure FiltersOn is FALSE
                        if RevealFilter is NIL (shouldn't happen normally).
        17-Oct-88 RSC   Load FlexStor-Held items.
                        Load "Foreign" records into flexstor.
        31-Oct-88 EGK   Added better duplicate-handling code into GetHeldItems.
                        Discard existing held item only if sizes are different.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
        10-Jan-89 RSC   Changed Storage to Space    .
        21-Mar-89 RSC   Added support for FSMUPH via SetSMU.
        22-Mar-89 EGK   Changed GetLayoutsInfo to look for smaller layout
                        records and convert them into version 4.0 size.
        18-Apr-89 LAA   Load the current cursor column and the scroll mode
                        that were saved with the schedule file and in the
                        config file.  This restores (as closely as possible)
                        the Gantt chart screen as it was when the last save
                        happened.
                        *)(*
        27-Apr-89 EGK   No, it doesn't.  In some cases, the Gantt chart
                        wasn't set up properly, and the SetCursorColumn
                        call produced an overflow error because its
                        "Cursor" was 0.  I commented this out until Larry
                        gets a chance to look at it.
        11-May-89 WKH   TrimRear'd the layout names before comparing
        14-May-89 AJL   Replaced the Alarms.AlarmOn variable with
                        Planner.MoveFutureTasks.
                        Load the TimeConstrained variable.
       24-May-89 AJL    Added "UsesCostTracking" variable.
       26-May-89 EGK    Added loading of AnnealingChoice and NetworkType to
                        GetTheEnvironment.
       30-May-89 AJL    Moved filter records to FlexStor.
       14-Jun-89 LAA  Added new procedure to load the Palettes.
       16-Jun-89 LAA    Removed the importing of F7Filter.  Adjust the Chart
                        State based on what's stored in the file.
       19-Jun-89 AJL    Removed FiltersOn boolean.
       22-Jun-89 RSC    Speed up reading filters by using the TaskFind
                        module.  Coordinate this with TLITL4.
       06-Jul-89 LAA    Sorted the Palettes after retrieving them from the
                        schedule or config file.
       13-Jul-89 EGK    Fixed bug in GetFiltersInfo where it was ignoring
                        the notes lines of all filters because their record
                        numbers were greater than 10.
       18-Aug-89 KKC    Call RecomputeTable in GetCalendar if the number of
                        years in the project file does not match the one
                        we have defined.
       23-Aug-89 KKC    Add one more parameter to RecomputeTable.
       24-Aug-89 EGK    Import procs from FilterUtility instead of FilterRc.
       31-Aug-89 LAA    Changed the file version number from 3.00 to 4.00.
                        This may cause old schedule files to be unreadable,
                        although I've tried to prevent that from happening.
        5-Sep-89 RSC    TrimRear the name of a layout when checking for dups.
       21-Sep-89 LAA    Removed all reference to Animation.
       25-Sep-89 EGK    Import procs from NetLList instead of NetLayouts.
       26-Oct-89 RSC    1) Added parameter to "GetSignature" for bug # 1638.
                        2) Added new procedure "SignatureError" to actually
                           put up a message.
        7-Nov-89 EGK    In GetTheEnvironment, change AnnealingChoice back to
                        Average if it was set to Presentation.  The two user
                        choices of "Draft" and "Final" correspond to the
                        values of Draft and Average, respectively.  This is
                        for compatibility with older test schedules.
        01-Dec-89 LAA   Because having just one DefaultPalette didn't work,
                        I made it an array.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        29-May-90 RSC   Clean up loading of filters to not depend on the
                        "RevealFilter" telling if Highlight[1] and [2] are
                        to follow. (Bug # 172)
        31-May-90 AJL   Changed the exported variables from Planner.
                        Eliminated the PlanLevel stuff, and added new options.
        20-Aug-90 RSC   Handle differences between BigTimeU versions, by
                        detecting and storing the file version number.
                        Files before 4.5 use the Old BigTime format.
        18-Sep-90 RSC   Added KeepEffortContiguous.
         4-Oct-90 RSC   Changed Smoothing to RecalcOptions.
        26-Oct-90 PFG   Move GetColumnNames here from TLStart so column
                        names can be in schedule files as well as config.
        31-Oct-90 PFG   Made ClearColumnNames proc so importers of old files
                        could use it.  Also, we now clear out column names 
                        even if new file we're loading doesn't have column
                        names.
        1-Nov-90 RSC    Load the NEW calendar.  Translate an old calendar
                        into the new format.
       13-Nov-90 RSC    Load the fixed task defaults.
       10-Jan-91 AJL    Renamed ReadTextLine to ReadOldFormatTextLine and 
                        added a new ReadTextLine.
       21-Jan-91 RSC    Removed the fiscal calendar.
       23-Jan-91 RSC    Force several Holder items into FlexStor.
       24-Jan-91 RSC    Added MASS UPDATE of text items.
        6-Feb-91 RSC    Change ref to Cal to ref to CalUtility.
       13-Feb-91 RSC    Added HeapNoOwner to held flexstor items.
                        If the text record size read is 0 length,
                        handle that properly.
       13-Mar-91 RSC    ClearColumnNames blasted texts without
                        discarding old texts.  Cleaned up some error
                        handling, added some error testing, cleaned up
                        the filter reading (it wasn't reading texts
                        always).  I was in here converting for Marilyn,
                        and cought these things.
       19-Mar-91 RSC    I was perhaps a little overzealous in my fix of
                        13-Mar as it related to Filters.  I have adjusted
                        my prior fix to be more conservative.
        2-Apr-91 TGS    Initial ReadingFileVersion is 500 instead of 450.
       29-May-91 LAA    Fix for bug #4355.  The PlanLevel and BackupPlanLevel
                        from version 4 schedules was not being read in.  They
                        are now; in GetTheEnvironment.  I've translated them
                        into the new meanings in Planner.def according to
                        Andrew's directions.
        4-Jun-91 RSC    Only mess with the calendar if we read it.
                        This is for Steve Alexandars OnTarget importer.
       18-Jun-91 AJL    Read 32-bit AsOfDate.
       16-Aug-91 PFG    Added argument to GetFiltersInfo, GetLayoutsInfo and 
                        GetNetLayoutsInfo to tell us whether to adjust for
                        column numbers that changed since the last version.
       26-Sep-91 AJL    Add comments.
    =========================================================================
*)




FROM Allocs       IMPORT  ATaskPtr, TaskTree;

FROM AsOf         IMPORT  AsOfSettingOption, AsOfDate;

FROM BigTimeU     IMPORT
    (* TYPE *)          ABigTime,
    (* PROC *)          BigTimeToTime;

FROM CalUtility   IMPORT        (* 6-Feb-91 RSC  *)
    (* PROC *)          RecomputeTable;

FROM Changer                    IMPORT
    (* VARS *)                      AdvancedTaskForm, UsesCostTracking;

FROM Chart                      IMPORT
    (* VAR *)                       GanttChart;

FROM ChartControl IMPORT  AChartState, UnSetState, AChartStateSet;

FROM ChartForms   IMPORT  CurrentChartFormat, AChartFormatPtr, LayoutTree,
                          SortLayouts, CreateLayout, DiscardLayout,
                          CurrentLayout, NumOfColumns, AChartColumnSpec,
                          AChartFormat;

FROM ColData       IMPORT
(* TYPE  *)             AColumnType,
(* VAR   *)             ColumnTable;

FROM Dialog       IMPORT  WarningBox, ADialogOption, FatalError, Message,
                        Error, NotYetImplemented;

FROM FileAux            IMPORT
    (* PROC *)              CheckIO;

FROM FileSystem   IMPORT  File, Response,
                        GetPos, SetPos;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer, AFltrType,
                                AFilterRecord, AFltrSet,
    (* VAR *)                   RevealFilter, HighlightFilter, FilterTree,
    (* PROC *)                  DeleteFilter;

FROM Filters                IMPORT
    (* PROC *)                  ShowFilterLight;

FROM FilterUtility          IMPORT
    (* PROC *)                  CreateFilter, SortFilters,
                                FindFilterByName;

FROM FlexStor               IMPORT
    (* TYPES *)                 AnExtHandle, AnExtStoragePreference,
    (* PROCS *)                 CreateExtObjectWithSize, SetExtData,
                                LockObject, ReleaseObject,
                                GetExtData;

FROM Gantt                  IMPORT  ChartFont, AGanttLineType,
                                    ASlackStyle;

FROM Holder                 IMPORT LocateHeldItem, AHoldType, AHoldTypeSet,
                                   DeleteHeldItem, HoldThis;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType, ATLGSColorAssignmentPtr,
    (* VAR *)                   PaletteTree, DefaultPalette;

FROM LStrings               IMPORT  StringsEqual, Copy, TrimRear, Compare,
                                SetString, Insert, Remove, Search, CtoS,
                                SetLengthOf;

FROM Memos                  IMPORT  CreateMemo, MemoTree,
                                    AMemoRecordPointer;

FROM MsgFile                IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout, ANetworkLayoutRecord,
    (* VAR *)                   CurrentNetLayout, EnlargedNetLayout,
                                NetLayoutTree;

FROM NetLUtility            IMPORT
    (* PROC *)                  CreateNetLayout, DiscardNetLayout,
                                SortNetLayouts, FindNetLayoutByName;

FROM NetworkData            IMPORT
    (* TYPE *)                  AnAnnealingChoice,
    (* VAR *)                   NetworkType, AnnealingChoice;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

IMPORT OBigTimeU;

FROM Palettes               IMPORT
    (* PROC *)                  CreatePalette, DiscardPalette,
                                FindPaletteByName, GetPaletteName;

FROM Planner      IMPORT
        (* TYPE *)         AWhenToCalc, ACalcComponent,
        (* VAR *)          CalculationState, Levelling, RecalcOptions, 
                           MoveFutureTasks, TimeConstrained, HonorDaysOff,
                           KeepEffortContiguous;

FROM RecordIO     IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                          ReadRecordBody, ReadStringBody;

FROM Schedule     IMPORT  ZeroIsLowestPriority,
                          FixedDateRules;

FROM Sorter                     IMPORT
    (* PROC *)                      SortTree;

FROM Space                      IMPORT
    (* PROC *)                      Available, ALLOCATE;

FROM Subfiles     IMPORT  StartSubfileInput;

FROM SYSTEM       IMPORT  SIZE, ADR, ADDRESS, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST  *)                CodingField1;

FROM TaskFind               IMPORT
    (* PROC *)                  FindTaskByNumber;

FROM Text                       IMPORT
    (* TYPE *)                      AText,
    (* PROC *)                      AppendLine, CreateText, TextExists,
                                    Compress, AssignLine, DiscardText,
                                    AppendManyLines;

FROM TimeFormat   IMPORT
    (* TYPE *)          ADateString,
    (* VAR *)           DefaultDateOption, EndDateStyle;

FROM Timei        IMPORT
    (* TYPE *)          ADate, ADuration, ADurationUnit, ATimeInfo,
    (* VAR  *)          Today,
    (* CONST *)         Jan, Dec, Sun, Sat,
    (* PROC *)          FindToday, TtoTimeU;

FROM Timeu        IMPORT
    (* TYPE *)          ATimeTable, AYearTable,
    (* VAR  *)          TimeTable, WeeksBeginOn, YearsOnFile,
    (* PROC *)          SetSMU, SetStartingMonth;

FROM Transfer                   IMPORT
    (* TYPE *)                      AHeaderRecord,
    (* VAR *)                       BackupsToKeep;

FROM TreeObjects                IMPORT
    (* TYPE *)                      ATree, ATreeNode,
    (* PROC *)                      ValidateTree, ValidateTreeNode;

FROM Undo                       IMPORT
    (* PROCS *)                     SetUndoLimit;


CONST
    ModuleNumber           = 12400; (* SAME AS TLITL3!! *)
    FileFormatVersion      = 400;   (* Version 3.00 of the file format. *)

CONST
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
     PlotsType             = 18;
     FiltersType           = 19;
     HeldItemsType         = 20;
     MemosType             = 21;
     LayoutsType           = 23;
     NetLayoutsType        = 24;
     TLGSDeviceType        = 25;                                  (* 21-May-89 LAA *)
     PalettesType          = 26;  (* Actually, 26, 27 and 28 because of 3 trees *)
     ColumnNamesType       = 29;

     ResourceFileVersionNumber   = 1;
     TaskFileVersionNumber       = 9;
     EdgeFileVersionNumber       = 6;
     EnvironmentVersionNumber    = 17;
     CalendarFileVersionNumber   = 1;
     BugsFileVersionNumber       = 1;

     LayoutFromCnfgFile = 0;  (* Secret bit in LayoutFlags *)
     FilterFromCnfgFile = 0;  (* Secret bit in FilterFlags *)




VAR
    ReadingFileVersion : CARDINAL;




PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;



TYPE
    AReadManyContext = RECORD
        f                   : POINTER TO File;
        FileType,
        LastLineNumberSeen  : CARDINAL;
        TextRecord          : RECORD
                                  LineNumber : CARDINAL;
                                  s          : ARRAY [0..255] OF CHAR;
                              END;
        RecordReady         : BOOLEAN;
    END;

    AReadManyContextPtr = POINTER TO AReadManyContext;



(* Called by the Text procedure "AppendManyLines".
*)
PROCEDURE ReadNewLines( VAR ReturnThis : ARRAY OF CHAR;
                            A          : ADDRESS        ) : BOOLEAN;
VAR
    Context : AReadManyContextPtr;
    Size,
    Type,
    Length,
    High,
    Low     : CARDINAL;
BEGIN
    Context := A;
    WITH Context^ DO
        IF (NOT RecordReady) THEN
            GetPos(f^, High, Low);
            ReadRecordPreface(f^, Type, Length);
            IF (Type <> FileType) THEN
                SetPos(f^,High, Low);
                SetLengthOf(ReturnThis,0);
                RETURN FALSE;
            END;
            Size := Length;
            IF (Size > SIZE(TextRecord)) THEN
                Size := SIZE(TextRecord);
            END;
            SetLengthOf(TextRecord.s,0);    (* 13-Feb-91 RSC *)
            ReadRecordBody(f^,Length,ADR(TextRecord),Size);
            RecordReady := TRUE;
        END;

        IF (TextRecord.LineNumber > LastLineNumberSeen) THEN
            SetLengthOf(ReturnThis,0);
        ELSE
            Copy(TextRecord.s,ReturnThis);
            RecordReady := FALSE;
        END;
        INC(LastLineNumberSeen);
    END;

    RETURN TRUE;

END ReadNewLines;





(* Called by the Text procedure "AppendManyLines".
*)
PROCEDURE ReadOldLines( VAR ReturnThis : ARRAY OF CHAR;
                            A          : ADDRESS        ) : BOOLEAN;
VAR
    Context : AReadManyContextPtr;
    Size,
    Type,
    Length,
    High,
    Low     : CARDINAL;
BEGIN
    Context := A;
    WITH Context^ DO
        IF (NOT RecordReady) THEN
            GetPos(f^, High, Low);
            ReadRecordPreface(f^, Type, Length);
            IF (Type <> FileType) THEN
                SetPos(f^,High, Low);
                SetLengthOf(ReturnThis,0);
                RETURN FALSE;
            END;
            Size := Length;
            IF (Size > SIZE(TextRecord.s)) THEN
                Size := SIZE(TextRecord.s);
            END;
            SetLengthOf(TextRecord.s,0);    (* 13-Feb-91 RSC *)
            ReadRecordBody(f^,Length,ADR(TextRecord.s),Size);
            RecordReady := TRUE;
        END;

        Copy(TextRecord.s,ReturnThis);
        RecordReady := FALSE;
    END;

    RETURN TRUE;

END ReadOldLines;





(* Read a series of text lines.

        Client has read the first line and supplies the type.

        On exit, Text is filled in and the file position is set to
        read the next record (which could theoreticy be of ANY type).

*)
PROCEDURE ReadManyTextLines(VAR F                : File;      (* in/out *)
                                Length           : CARDINAL;  (* in     *)
                                Type             : CARDINAL;  (* in     *)
                            VAR Text             : AText);    (* in/out *)
VAR
    ReadManyContext : AReadManyContext;
    Size            : CARDINAL;
    ok              : BOOLEAN;
BEGIN
    WITH ReadManyContext DO
        Size := Length;
        IF (Size > SIZE(TextRecord)) THEN
            Size := SIZE(TextRecord);
        END;
        SetLengthOf(TextRecord.s,0);    (* 13-Feb-91 RSC *)
        ReadRecordBody(F,Length,ADR(TextRecord),Size);
        f                  := ADR(F);
        LastLineNumberSeen := 0;
        FileType           := Type;
        RecordReady        := TRUE;
    END;

    ok := AppendManyLines( ReadNewLines, ADR(ReadManyContext), Text );

END ReadManyTextLines;




(* Read a series of OLD text lines.

        Client has read the first line and supplies the type.

        On exit, Text is filled in and the file position is set to
        read the next record (which could theoreticy be of ANY type).

*)
PROCEDURE ReadManyOldTextLines(VAR F                : File;      (* in/out *)
                                   Length           : CARDINAL;  (* in     *)
                                   Type             : CARDINAL;  (* in     *)
                               VAR Text             : AText);    (* in/out *)
VAR
    ReadManyContext : AReadManyContext;
    Size            : CARDINAL;
    ok              : BOOLEAN;
BEGIN
    WITH ReadManyContext DO
        Size := Length;
        IF (Size > SIZE(TextRecord.s)) THEN
            Size := SIZE(TextRecord.s);
        END;
        SetLengthOf(TextRecord.s,0);    (* 13-Feb-91 RSC *)
        ReadRecordBody(F,Length,ADR(TextRecord.s),Size);
        f                  := ADR(F);
        LastLineNumberSeen := 0;
        FileType           := Type;
        RecordReady        := TRUE;
    END;

    ok := AppendManyLines( ReadOldLines, ADR(ReadManyContext), Text );

END ReadManyOldTextLines;





(*----------------------------------------------------------------------------
    ReadOldFormatTextLine --

    From the file read a record of the specified length, and append it to the
    text.  If the text doesn't already exist, it will be created.
    Expects that the record is a length byte followed by the characters.

----------------------------------------------------------------------------*)

PROCEDURE ReadOldFormatTextLine(VAR F                : File;                (* in/out *)
                                    Length           : CARDINAL;            (* in     *)
                                VAR Text             : AText);              (* in/out *)

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ReadTextLine *)

    ReadStringBody(F, Length, s);
    IF NOT TextExists(Text) THEN
        Text := CreateText();
    END;
    IF NOT AppendLine(s, Text) THEN
        ErrorFlag := TRUE;
    END;

END ReadOldFormatTextLine;


(*----------------------------------------------------------------------------
    ReadTextLine --

    From the file read a record of the specified length, and sets the 
    indicated line of text.
    If the text doesn't already exist, it will be created.
    Expects that the record is a line number, length byte and characters.
----------------------------------------------------------------------------*)

PROCEDURE ReadTextLine(VAR F                : File;                (* in/out *)
                           Length           : CARDINAL;            (* in     *)
                       VAR Text             : AText);              (* in/out *)

VAR
    TextRecord              : RECORD
                                  LineNumber : CARDINAL;
                                  s          : ARRAY [0..255] OF CHAR;
                              END;

BEGIN                       (* ReadTextLine *)


    ReadRecordBody(F,Length,ADR(TextRecord),SIZE(TextRecord));
        (* If not an empty line, store it. *)
    IF (Length > 3) THEN
        IF NOT TextExists(Text) THEN
            Text := CreateText();
        END;
        IF NOT AssignLine(TextRecord.s, TextRecord.LineNumber, Text ) THEN
            ErrorFlag := TRUE;
        END;
    END;

END ReadTextLine;






PROCEDURE ReadDate(    VAR F      : File;
                           Length : CARDINAL;
                       VAR D      : ADate );
VAR
    TimeInfo     : ATimeInfo;
    BigTime      : ABigTime;
    ok           : BOOLEAN;
BEGIN

    ReadRecordBody(F,Length,ADR(BigTime), SIZE(BigTime));
    WITH TimeInfo DO
        IF (ReadingFileVersion < 450) THEN  (* 20-Aug-90 RSC  *)
            OBigTimeU.BigTimeToTime( BigTime, tiYear, tiMonth, tiDay, tiHour, tiMinute, tiSecond );
        ELSE
            BigTimeToTime( BigTime, tiYear, tiMonth, tiDay, tiHour, tiMinute, tiSecond );
        END;
    END;
    ok := TtoTimeU( TimeInfo, D );

END ReadDate;





    (* AttachNodeOnTree --

       Attach the node to the tree at a given level, if
       possible.  If there are no nodes in the tree with level greater
       than N, then the new node will have level of N+1.

    *)


PROCEDURE AttachNodeOnTree(     Tree     : ATree;
                                Node     : ATreeNode;
                                Level    : CARDINAL );
VAR
   OtherNode : ATreeNode;
   ChildNode : ATreeNode;
BEGIN
   ValidateTree(Tree);
   ValidateTreeNode(Node);


   IF (Level = 0) THEN
       Tree^.Methods^.AddLast(Tree,Node);
   ELSE
       OtherNode := Tree^.Methods^.GetLast(Tree);
       IF (OtherNode = NIL) THEN
            Tree^.Methods^.AddLast (Tree, Node);
            RETURN;
       END;
       LOOP
           IF (OtherNode^.Methods^.IndentationLevel (OtherNode) >= Level - 1) THEN
               OtherNode^.Methods^.AddAsLastChild (OtherNode, Node);
               EXIT;
           END;
           ChildNode := OtherNode^.Methods^.LastChild (OtherNode);
           IF (ChildNode = NIL) THEN
               OtherNode^.Methods^.AddAsLastChild (OtherNode, Node);
               EXIT;
           ELSE
               OtherNode := ChildNode;
           END;
       END;
   END;

END AttachNodeOnTree;








PROCEDURE ReadTaskNumber(VAR f:File; Length : CARDINAL; VAR Task:ATreeNode);
VAR
    Number : INTEGER;
BEGIN
    ReadRecordBody(f,Length,ADR(Number),SIZE(Number));
    IF (f.res = done) THEN      (* 13-Mar-91 RSC  *)
        Task := FindTaskByNumber(Number);
    ELSE
        Task := NIL;
    END;
END ReadTaskNumber;




(*----------------------------------------------------------------------------
    ClearColumnNames --

    Empty out the existing arrays of custom column names.

    Preconditions:
        The ColumnTable arrays must have been allocated already.

    Postconditions:
        The arrays are set to NIL.
----------------------------------------------------------------------------*)

PROCEDURE ClearColumnNames();
VAR
    ColumnType              : AColumnType;

BEGIN
    FOR ColumnType := MIN( AColumnType ) TO MAX( AColumnType ) DO
        IF (ColumnTable[ColumnType] <> AText(NIL)) THEN (* 13-Mar-91 RSC  *)
            DiscardText( ColumnTable[ColumnType] );
        END;
        ColumnTable[ColumnType] := AText(NIL);
    END;
END ClearColumnNames;



(*----------------------------------------------------------------------------
    GetColumnNames --

    Get any custom column names available.    

    Preconditions:
        The ColumnTable arrays must have been allocated already.

    Postconditions:
        If no column names are available, any column names that were
        previously in memory are cleared out.
----------------------------------------------------------------------------*)

PROCEDURE GetColumnNames(VAR F : File);     (* 10-Sep-90 PFG  *)

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;

BEGIN                       (* GetColumnNames *)

        (* Empty out existing custom columns first.  We always want to
           do this, even if there are no column names in the new file. *)

    ClearColumnNames();         (* 31-Oct-90 PFG *)

    IF (NOT StartSubfileInput(F, ColumnNamesType, Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(F, Type, Length);
        IF (F.res <> done) THEN      (* 13-Mar-91 RSC  *)
            EXIT;
        END;

        CASE Type OF
            0       :   (* Task Columns *)

                        ReadManyOldTextLines(F, Length, 0, ColumnTable[TaskColumnInfo] );

        |   1       :   (* Cross Tab Columns *)

                        ReadManyOldTextLines(F, Length, 1, ColumnTable[XTabColumnInfo]);

        |   2       :   (* Resource Columns *)

                        ReadManyOldTextLines(F, Length, 2, ColumnTable[RsrcColumnInfo]);

        |   3       :   (* Assignment Columns *)

                        ReadManyOldTextLines(F, Length, 3, ColumnTable[AssgColumnInfo]);

        |  10       :   (* Task Columns *)

                        ReadManyTextLines(F, Length, 10, ColumnTable[TaskColumnInfo]);

        |  11       :   (* Cross Tab Columns *)

                        ReadManyTextLines(F, Length, 11, ColumnTable[XTabColumnInfo]);

        |  12       :   (* Resource Columns *)

                        ReadManyTextLines(F, Length, 12, ColumnTable[RsrcColumnInfo]);

        |  13       :   (* Assignment Columns *)

                        ReadManyTextLines(F, Length, 13, ColumnTable[AssgColumnInfo]);

        |   0FFH    :   
                        EXIT;

        ELSE    
                        SkipRecordBody(F, Length);
        END;

    END;
END GetColumnNames;







PROCEDURE GetCalendar(VAR f:File);
TYPE
        (* Old year tables are used by the On Target importer
           as well as version 4 and prior of Time Line. *)
    AnOldYearTable = RECORD
                     HoursInYear : CARDINAL;
                     HoursInMonth: ARRAY [Jan..Dec] OF [0..(24*31)];
                     StartDay : ARRAY [Jan..Dec] OF [Sun..Sat];
                     YearMap: ARRAY [Jan..Dec] OF
                        ARRAY [0..1] OF BITSET;  (* Need 31 bits. *)
                 END;
    AnOldWeekTable = RECORD
                     HoursInDay : ARRAY [Sun..Sat] OF [0..24];
                     WeekMap: ARRAY [Sun..Sat] OF
                         ARRAY [0..1] OF BITSET;
                 END;
VAR
    i,
    NYearsInProjectFile : CARDINAL;
    Type                : CARDINAL;
    Length              : CARDINAL;
    Version             : CARDINAL;
    StartingMonth       : CARDINAL;
    LocalSMUPH          : CARDINAL;
    StdDay              : CARDINAL;
    OldWeekTable        : AnOldWeekTable;
    OldYearTable        : AnOldYearTable;

        (* Convert bit maps from the old format to the new format.
           Don't worry about the other fields, they are dealt with
           in Recompute Table.
        *)
    PROCEDURE ConvertWeekTable( VAR OldWeekTable : AnOldWeekTable );
    VAR
        i, j, k : CARDINAL;
    BEGIN
        FOR i := Sun TO Sat DO
            FOR j := 0 TO 23 DO
                IF ((j MOD 16) IN OldWeekTable.WeekMap[i,j DIV 16]) THEN
                    FOR k := 0 TO 3 DO
                        INCL( TimeTable.WeekTable[i].WeekMap, j*4+k );
                    END;
                ELSE
                    FOR k := 0 TO 3 DO
                        EXCL( TimeTable.WeekTable[i].WeekMap, j*4+k );
                    END;
                END;
            END;
        END;

    END ConvertWeekTable;


    PROCEDURE ConvertYearTable( VAR OldYearTable : AnOldYearTable;
                                    Year         : CARDINAL );
    VAR
        i, j    : CARDINAL;
    BEGIN
        FOR i := Jan TO Dec DO
            FOR j := 0 TO 31 DO
                IF ((j MOD 16) IN OldYearTable.YearMap[i,j DIV 16]) THEN
                    INCL( TimeTable.YearTable[Year,i].YearMap, j );
                ELSE
                    EXCL( TimeTable.YearTable[Year,i].YearMap, j );
                END;
            END;
        END;

    END ConvertYearTable;

BEGIN
    IF (NOT StartSubfileInput(f,CalendarType,Version)) THEN
        RETURN;
    END;

    NYearsInProjectFile := 0;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF

                (* 1-Nov-90 RSC Types 1 through 6, but not 2, are from
                                the old (Version 2, 3, and 4) calendars and
                                must be converted.
                *)


            1  :  ReadRecordBody(f,Length,ADR(TimeTable.FirstYear),SIZE(TimeTable.FirstYear));

          | 2  :  ReadRecordBody(f,Length,ADR(LocalSMUPH),SIZE(LocalSMUPH));

          | 3  :  ReadRecordBody(f,Length,ADR(StdDay),SIZE(StdDay));
                  TimeTable.StdDayTics := StdDay * LocalSMUPH;

          | 4  :  ReadRecordBody(f,Length,ADR(TimeTable.StdWeek),SIZE(TimeTable.StdWeek));

          | 5  :  ReadRecordBody(f,Length,ADR(OldWeekTable),SIZE(OldWeekTable));
                  ConvertWeekTable( OldWeekTable );

          | 6  :  IF (NYearsInProjectFile <= HIGH(TimeTable.YearTable)) THEN
                      INC(NYearsInProjectFile);
                      ReadRecordBody(f,Length,ADR(OldYearTable),SIZE(OldYearTable));
                      ConvertYearTable( OldYearTable, NYearsInProjectFile );
                  END;

          | 7  :  ReadRecordBody(f,Length,ADR(DefaultDateOption),SIZE(DefaultDateOption));
          | 8  :  ReadRecordBody(f,Length,ADR(WeeksBeginOn),SIZE(WeeksBeginOn));        (* 3/27/87 EGK *)
          | 9  :  ReadRecordBody(f,Length,ADR(StartingMonth),SIZE(StartingMonth));
                  SetStartingMonth(StartingMonth);
          | 10 :  ReadRecordBody(f,Length,ADR(EndDateStyle),SIZE(EndDateStyle));

                    (* 1-Nov-90 RSC New calendar is stored in its entirity
                    *)
          | 20 :  ReadRecordBody(f,Length,ADR(TimeTable),SIZE(TimeTable));
                  NYearsInProjectFile := YearsOnFile;

          | 0FFH : EXIT;

        ELSE
            SkipRecordBody(f,Length);
        END;
    END;

    SetSMU( 60 DIV LocalSMUPH );

        (* If we read an old calendar, clear out all subsequent
           years if we read a Version 3 style short (25 year) calendar.
        *)
    IF (NYearsInProjectFile > 0)           AND  (* 4-Jun-91 RSC  *)
       (NYearsInProjectFile < YearsOnFile) THEN

        FOR i := Jan TO Dec DO
            OldYearTable.YearMap[i,0] := {0..15};  (* All days are holidays. *)
            OldYearTable.YearMap[i,1] := {0..15};
        END;

        FOR i := NYearsInProjectFile + 1 TO YearsOnFile DO
            ConvertYearTable( OldYearTable, i );
        END;
    END;

    RecomputeTable( TimeTable, FALSE );    (* Ajust all the structures. *)


END GetCalendar;






PROCEDURE GetFiscalCalendar(VAR f : File);
BEGIN
END GetFiscalCalendar;





PROCEDURE GetTheEnvironment(VAR f:File);

    (*  This type is for reading in version 4 schedules.  It's no longer
        used.
    *)                                                         (* 29-May-91 *)
TYPE
    APlanLevel = (NoPlanning, CpmOnly, ResourcesToo);

VAR
    UndoLimit,
    Type,
    Length,
    Version : CARDINAL;
    i                       : CARDINAL;
    LocalChartState         : AChartStateSet;
    Scroll                  : BOOLEAN;
    BackupPlanLevel         : APlanLevel;
    PlanLevel               : APlanLevel;
    GotAsOfDate             : BOOLEAN;

BEGIN
    GotAsOfDate := FALSE;   (* Compatibility with files before 6/18/91. *)

    IF (NOT StartSubfileInput(f,EnvironmentType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
            1:    ReadRecordBody(f,Length,ADR(BackupsToKeep),SIZE(BackupsToKeep));
                     (* Field 7 is the former AlarmOn value, which, with sense
                        reversed, becomes the setting for MoveFutureTasks. *)
          | 2:    ReadRecordBody(f,Length,ADR(BackupPlanLevel),SIZE(BackupPlanLevel));
                  Levelling := (BackupPlanLevel = ResourcesToo);
          | 3:    ReadRecordBody(f,Length,ADR(PlanLevel),SIZE(PlanLevel));
                  IF (PlanLevel = NoPlanning) THEN
                      CalculationState[Scheduling].When := ManualCalc;
                  ELSE
                      CalculationState[Scheduling].When := AutoCalc;
                  END;    
          | 7:    ReadRecordBody(f,Length,ADR(MoveFutureTasks),SIZE(MoveFutureTasks));
                  MoveFutureTasks := NOT MoveFutureTasks;
          | 9:    ReadRecordBody(f,Length,ADR(AsOfSettingOption),SIZE(AsOfSettingOption));  (* 3/27/87 EGK *)
                      (* As of 6/18/91, we no longer store the AsOf date in the
                         16-bit field, number 10.  We store it in a 32-bit field, 
                         number 14. *)
          | 10:   IF (GotAsOfDate) THEN          (* Safety interlock in case we already read the *)
                      SkipRecordBody(f,Length);  (* 32-bit version. *)
                  ELSE
                      ReadRecordBody(f,Length,ADR(AsOfDate),SIZE(AsOfDate));
                  END;
          | 11:   ReadRecordBody(f,Length,ADR(ZeroIsLowestPriority),SIZE(ZeroIsLowestPriority));
          | 12:   ReadRecordBody(f,Length,ADR(AdvancedTaskForm),SIZE(AdvancedTaskForm));
          | 13:   ReadRecordBody(f,Length,ADR(UndoLimit),SIZE(UndoLimit));
                  SetUndoLimit(UndoLimit);
          | 14:   ReadDate(f,Length,AsOfDate);
                  GotAsOfDate := TRUE;

          | 21:   ReadRecordBody(f, Length, ADR(Scroll), SIZE(Scroll));
                  GanttChart^.Methods^.SetScrollMode(GanttChart, Scroll);
          | 22:   ReadRecordBody(f,Length,ADR(TimeConstrained),SIZE(TimeConstrained));
          | 23:   ReadRecordBody(f,Length,ADR(MoveFutureTasks),SIZE(MoveFutureTasks));
          | 24:   ReadRecordBody(f,Length,ADR(UsesCostTracking),SIZE(UsesCostTracking));
          | 25:   ReadRecordBody(f,Length,ADR(AnnealingChoice),SIZE(AnnealingChoice));
                  IF (AnnealingChoice = Presentation) THEN
                      AnnealingChoice := Average;           (* 11/7/89 EGK *)
                  END;
          | 26:   ReadRecordBody(f,Length,ADR(NetworkType),SIZE(NetworkType));
          | 27:   ReadRecordBody(f,Length,ADR(LocalChartState),   (* 16-Jun-89 LAA *)
                                 SIZE(LocalChartState));
                  IF (NOT (Scheduled IN LocalChartState)) THEN
                      UnSetState(Scheduled);
                  END;

          | 28:   ReadRecordBody(f,Length,ADR(CalculationState),SIZE(CalculationState));
          | 29:   ReadRecordBody(f,Length,ADR(Levelling),SIZE(Levelling));
          | 30:   ReadRecordBody(f,Length,ADR(RecalcOptions),SIZE(RecalcOptions));
          | 31:   ReadRecordBody(f,Length,ADR(HonorDaysOff),SIZE(HonorDaysOff));
          | 32:   ReadRecordBody(f,Length,ADR(KeepEffortContiguous),SIZE(KeepEffortContiguous));    (* 18-Sep-90 RSC *)

          | 33:   ReadRecordBody(f,Length,ADR(FixedDateRules),SIZE(FixedDateRules));    (* 13-Nov-90 RSC *)

          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetTheEnvironment;



  (* Get Signature - Check that this is a version 3.00 file format.

                     If the version number is in the file, but is not the
                     current one, then barf.

                     Later, when we are writing out other versions, the
                     customer will presumably get a new importer that can
                     handle this, and so we will ajust processing rather than
                     just upchucking.

                     For now (2/22/88), we let files with NO NUMBER slip by
                     us so we have an easier time with our current schedules.
                               26-Oct-89 RSC Added FileVersion parameter, removed
                                   error message into seperate proc.
   *)
PROCEDURE GetSignature(VAR f           : File;
                       VAR FileVersion : CARDINAL ) : BOOLEAN;
VAR
    Type,
    Length,
    Version     : CARDINAL;
    ok          : BOOLEAN;
BEGIN

    ok := (StartSubfileInput(f,SignatureType,Version));

    IF (ok) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            ok := (CheckIO(f) = done);
            IF (NOT ok) THEN
                EXIT;
            END;
            CASE Type OF
                10   : ReadRecordBody(f,Length,ADR(FileVersion),SIZE(FileVersion));
              | 0FFH : EXIT;
            ELSE
                SkipRecordBody(f,Length);
            END;
        END;
    END;

    ReadingFileVersion := FileVersion;  (* 20-Aug-90 RSC  *)

    RETURN ok;

END GetSignature;





(* 26-Oct-89 RSC This puts up an error message in the form

    "This file is from an in incompatible version of Time Line.
     I wanted version @, but it is version @."

     The first @ sign is replaced by the DESIRED signature number.
     The second is replaced by the ACTUAL number.

     The numbers are expected to be in the form NNN, like 300 or 401.
     They are printed as N.NN, like 3.00 or 4.01
*)
PROCEDURE SignatureError( DesiredSignature,
                          ActualSignature   : CARDINAL );
VAR
    Where       : CARDINAL;
    s           : ARRAY [0..255] OF CHAR;
    Title       : ARRAY [0..39]  OF CHAR;
    s2          : ARRAY [0..7]   OF CHAR;
    s1          : ARRAY [0..1]   OF CHAR;

    PROCEDURE CtoSDot( C : CARDINAL; VAR s : ARRAY OF CHAR );
    VAR
        temp    : ARRAY [0..1] OF CHAR;
    BEGIN
        CtoS( C, s );
        SetString( temp, "." );
        Insert( s, temp, 2 );
    END CtoSDot;

BEGIN

    GetMessage( ModuleNumber + 63, s );     (* "This file was from an incompatible version of Time Line" *)
    GetMessage( ModuleNumber + 64, Title ); (* "Wrong File Version" *)

    SetString(s1, "@");
    Where := Search(s, s1, 1);
    IF (Where > 0) THEN
        Remove(s,Where,1);
        CtoSDot( DesiredSignature, s2 );
        Insert(s,s2,Where);
        Where := Search(s, s1, Where);
        IF (Where > 0) THEN
            Remove(s,Where,1);
            CtoSDot( ActualSignature, s2 );
            Insert(s,s2,Where);
        END;
    END;

    WarningBox( s, Title, NoHelp );

END SignatureError;









PROCEDURE FindFilterByNumber( MatchID  : CARDINAL ) : ATreeNode;
VAR
    Filter     : AFilterRecordPointer;
    FilterNode : ATreeNode;
    ID         : CARDINAL;
BEGIN
    FilterNode := FilterTree^.Methods^.GetFirst(FilterTree);
    LOOP
        IF (FilterNode = NIL) THEN
            EXIT;
        END;
        Filter := FilterNode^.Methods^.LockFlexStorDataObject(FilterNode);
        ID := Filter^.ID;
        FilterNode^.Methods^.UnlockUnchangedDataObject(FilterNode);
        IF (ID = MatchID) THEN
            EXIT;
        END;
        FilterNode := FilterNode^.Methods^.NextPreOrder(FilterNode);
    END;
    RETURN FilterNode;
END FindFilterByNumber;






PROCEDURE ReadFilterNumber(VAR f:File; Length : CARDINAL; VAR Filter:ATreeNode);
VAR
    Number : CARDINAL;
    PrivateFilter : ATreeNode;

BEGIN
    ReadRecordBody(f,Length,ADR(Number),SIZE(Number));
    PrivateFilter := FindFilterByNumber(Number);                  (* 15-Jan-88 LAA *)
    IF (PrivateFilter <> NIL) THEN
        Filter := PrivateFilter;
    END;
END ReadFilterNumber;



                                    (* 3/1/88 EGK *)

PROCEDURE ReadFilterName  (VAR f:File; Length : CARDINAL; VAR Filter:ATreeNode);
VAR
    Name            : ARRAY [0..20] OF CHAR;
    PrivateFilter   : ATreeNode;

BEGIN
    ReadStringBody (f,Length,Name);
    PrivateFilter := FindFilterByName (Name);
    IF (PrivateFilter <> NIL) THEN
        Filter := PrivateFilter;
    END;
END ReadFilterName;




(*                                 (* 16-Aug-91 PFG *)
    AccountForColumnChanges--

    Some column numbers have changed, affecting the imported layouts.
    Renumber if necessary.

*)



(*$O-*)
(*$S+*)   (* Stack check -- This proc contains a large filter record. *)



PROCEDURE GetFiltersInfo(VAR f:File; DuplicatesOKProc : ADuplicatesOKProc;
                                     UpdateCurrent    : BOOLEAN;
                                     AdjustColumns    : BOOLEAN );
(*  If UpdateCurrent is FALSE, then we won't read the current selection
    of the select or the highlights, and we'll ignore the dependency filters.
    This requires saving the ID numbers of the current selections before
    getting stuff from the file (in case of duplicates).
*)

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    FilterNumber            : CARDINAL;
    HighlightNo             : CARDINAL;
    Node                    : ATreeNode;
    OldFilter               : ATreeNode;
    OldFilterRecord,
    TempFilterRecord        : AFilterRecordPointer;
    Header                  : AHeaderRecord;
    SavingInTree            : BOOLEAN;
    AllowThisOne            : BOOLEAN;
    FilterRecord            : AFilterRecord;

    PROCEDURE FilterChanged ( OldOne      : ATreeNode;
                              NewOne      : ATreeNode   );
    VAR
        i           : CARDINAL;

    BEGIN
        IF (RevealFilter = OldOne) THEN
            RevealFilter := NewOne;
        END;
        FOR i := 3 TO 5 DO
            IF (HighlightFilter[i] = OldOne) THEN
                HighlightFilter[i] := NewOne;
            END;
        END;
    END FilterChanged;


        (* Store the filter record from the stack variable into the
           Tree Node's FlexStor object. *)

    PROCEDURE FinishFilter();
    VAR
        FilterHandle       : AnExtHandle;
        i                  : AFltrType;
    BEGIN
        IF (Node <> NIL) THEN                   (* 18-Feb-88 LAA *)

            IF (AdjustColumns) THEN             (* 16-Aug-91 PFG *)
                WITH FilterRecord DO
                    FOR i := FDataField1 TO FDataField2 DO
                        UpdateOldColumnID(DataField[i].FieldId);
                    END;
                END;
            END;

            Compress(FilterRecord.Notes);
            FilterHandle := AnExtHandle(Node^.Methods^.GetDataObject (Node));
            IF (NOT SetExtData(FilterHandle,ADR(FilterRecord),SIZE(FilterRecord))) THEN
                FatalError();
            END;
            Node := NIL;
        END;
    END FinishFilter;

BEGIN
    IF (NOT StartSubfileInput(f,FiltersType,Version)) THEN
        RETURN;
    END;

    SavingInTree := TRUE;
    HighlightNo  := 1;
    Node         := NIL;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;

        IF ((Type >= 10) AND (Type < 100)) THEN (* 19-Mar-91 RSC  *)

                (* We are in a loop reading filter records from the
                   file.  Each filter is represented by a long series
                   of data records.  Each type 0 record is the beginning
                   of a new filter.  There is no explicit end of filter
                   record.
                   If there is any preceding filter being read, finish it.
                 *)
            FinishFilter();
        END;

        CASE Type OF
            0  :

                  FinishFilter();   (* 13-Mar-91 RSC  *)

                      (* Standard header for all tree items. *)
                  ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

          | 1  :
                      (* Create a new filter.  However, in order to avoid
                         holding a lock on it for a long time, we will
                         do our work temporarily on a filter record variable
                         allocated on the stack.  This gets stored into
                         the TreeNode by FinishFilter().  AJL  6/5/89. *)

                  IF (NOT CreateFilter (Node)) THEN EXIT; END;   (* 13-Mar-91 RSC  *)

                  ReadRecordBody(f,Length,ADR(FilterRecord),SIZE(FilterRecord));
                  FilterRecord.Notes := AText(NIL);

                  AllowThisOne := TRUE;
                  OldFilter    := FindFilterByName (FilterRecord.Name);
                  IF (OldFilter <> NIL) AND (SavingInTree) THEN

                      OldFilterRecord := OldFilter^.Methods^.LockFlexStorDataObject (OldFilter);
                      IF (DuplicatesOKProc( OldFilterRecord^.Name )) THEN
                          FilterChanged (OldFilter, Node);
                          OldFilter^.Methods^.UnlockUnchangedDataObject (OldFilter);
                          OldFilterRecord := NIL;
                          DeleteFilter (OldFilter);
                      ELSE
                              (* Scratch all further updates to this filter! *)
                          AllowThisOne := FALSE;
                          OldFilterRecord^.ID := FilterRecord.ID;
                          OldFilter^.Methods^.UnlockFlexStorDataObject (OldFilter);
                          OldFilterRecord := NIL;
                          DeleteFilter (Node);
                              (* Scratch all further updates to this filter! *)
                      END;
                  END;

                  IF (AllowThisOne) THEN
                      FilterRecord.antetask := NIL;    (* Don't want random pointers. *)
                      FilterRecord.desctask := NIL;
                      FilterRecord.Notes := AText (NIL);

                      IF (SavingInTree) THEN
                          AttachNodeOnTree (FilterTree, Node, Header.Level);
                          Node^.Methods^.SetAttributes (Node, Header.Attributes);
                      ELSE
                          IF (HighlightFilter[HighlightNo] <> NIL) THEN
                              DeleteFilter (HighlightFilter[HighlightNo]);
                          END;
                          HighlightFilter[HighlightNo] := Node;
                          INC (HighlightNo);
                      END;
                  END;

          | 2  :  IF (AllowThisOne) THEN
                      ReadTaskNumber(f,Length,FilterRecord.antetask);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 3  :  IF (AllowThisOne) THEN
                      ReadTaskNumber(f,Length,FilterRecord.desctask);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 4  :  IF (AllowThisOne) THEN
                      ReadDate(f,Length,FilterRecord.startdate);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 5  :  IF (AllowThisOne) THEN
                      ReadDate(f,Length,FilterRecord.enddate);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 10 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  SavingInTree := FALSE;
                  RevealFilter := NIL;                            (* 15-Jan-88 LAA *)
                  ReadFilterNumber (f, Length, RevealFilter);
                  ShowFilterLight();

          | 11  : ReadFilterNumber (f, Length, HighlightFilter[3]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)
          | 12  : ReadFilterNumber (f, Length, HighlightFilter[4]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)
          | 13  : ReadFilterNumber (f, Length, HighlightFilter[5]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)

          | 30 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  SavingInTree := FALSE;
                  RevealFilter := NIL;                            (* 15-Jan-88 LAA *)
                  ReadFilterName (f, Length, RevealFilter);
                  ShowFilterLight();

          | 31  : ReadFilterName (f, Length, HighlightFilter[3]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)
          | 32  : ReadFilterName (f, Length, HighlightFilter[4]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)
          | 33  : ReadFilterName (f, Length, HighlightFilter[5]);
                  SavingInTree := FALSE;    (* 29-May-90 RSC *)

          | 100 : IF (AllowThisOne) THEN
                      ReadManyOldTextLines(f, Length, 100, FilterRecord.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 102 : IF (AllowThisOne) THEN
                      ReadManyTextLines(f, Length, 102, FilterRecord.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

    FinishFilter();   (* 13-Mar-91 RSC  *)
    SortFilters();
    UnSetState(Filtered);

END GetFiltersInfo;

(*$S=*)
(*$O=*)





PROCEDURE GetMemosInfo(VAR f                : File);               (* 01/07/87 LAA *)

VAR
    Version                 : CARDINAL;
    Type,
    Length                  : CARDINAL;
    Memo                    : AMemoRecordPointer;
    Node                    : ATreeNode;
    Header                  : AHeaderRecord;


BEGIN                       (* GetMemosInfo *)

    IF (NOT StartSubfileInput(f,MemosType,Version)) THEN
        RETURN;
    END;

    Memo := NIL;                                                  (* 18-Feb-88 LAA *)
    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            0   :
                    ReadRecordBody (f, Length, ADR(Header), SIZE(Header));
        |   1   :
                    IF (Memo <> NIL) THEN                         (* 18-Feb-88 LAA *)
                        Compress(Memo^.text);
                    END;
                    Node := CreateMemo (AText(NIL));
                    IF (Node = NIL) THEN RETURN; END;
                    AttachNodeOnTree (MemoTree, Node, Header.Level);
                    Node^.Methods^.SetAttributes (Node, Header.Attributes);
                    Memo := Node^.Methods^.GetDataObject (Node);
                    ReadRecordBody(f,Length, Memo, SIZE(Memo^));
                    Memo^.text := AText(NIL);
                    Memo^.open := FALSE;
        |   2   :
                    ReadManyOldTextLines(f, Length, 2, Memo^.text);
        |  102  :
                    ReadManyTextLines(f, Length, 102, Memo^.text);
        |   0FFH:
                    EXIT;
        ELSE    SkipRecordBody(f,Length);
        END;
    END;
    IF (Memo <> NIL) THEN                                         (* 18-Feb-88 LAA *)
        Compress(Memo^.text);
    END;

END GetMemosInfo;





PROCEDURE FindLayoutByName(VAR LayoutName   : ARRAY OF CHAR)       (* in     *)
                                                                : ATreeNode;

VAR
    Layout                  : AChartFormatPtr;
    Node                    : ATreeNode;

BEGIN                       (* FindLayoutByName *)

    TrimRear(LayoutName);   (* RSC 5-Sep-89 *)
    Node := LayoutTree^.Methods^.GetFirst (LayoutTree);
    WHILE (Node <> NIL) DO
        Layout := Node^.Methods^.GetDataObject (Node);
        TrimRear(Layout^.Name);   (* WKH 5/11/89 *)
        IF (StringsEqual(Layout^.Name, LayoutName)) THEN    (* RSC 1/2/88 *)
            RETURN Node;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;

    RETURN NIL;

END FindLayoutByName;





PROCEDURE FindLayoutByNumber( MatchID  : CARDINAL ) : ATreeNode;
VAR
    Layout     : AChartFormatPtr;
    LayoutNode : ATreeNode;
BEGIN
    LayoutNode := LayoutTree^.Methods^.GetFirst(LayoutTree);
    LOOP
        IF (LayoutNode = NIL) THEN
            EXIT;
        END;
        Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);
        IF (Layout^.ID = MatchID) THEN
            EXIT;
        END;
        LayoutNode := LayoutNode^.Methods^.NextPreOrder(LayoutNode);
    END;
    RETURN LayoutNode;
END FindLayoutByNumber;






PROCEDURE ReadLayoutNumber(VAR f:File; Length : CARDINAL; VAR Layout:ATreeNode);
VAR
    Number : CARDINAL;
    PrivateLayout : ATreeNode;

BEGIN
    ReadRecordBody(f,Length,ADR(Number),SIZE(Number));
    PrivateLayout := FindLayoutByNumber(Number);                  (* 15-Jan-88 LAA *)
    IF (PrivateLayout <> NIL) THEN
        Layout := PrivateLayout;
    END;
END ReadLayoutNumber;




                                    (* 3/1/88 EGK *)

PROCEDURE ReadLayoutName  (VAR f:File; Length : CARDINAL; VAR Layout:ATreeNode);
VAR
    Name            : ARRAY [0..20] OF CHAR;
    PrivateLayout : ATreeNode;

BEGIN
    ReadStringBody (f,Length,Name);
    PrivateLayout := FindLayoutByName(Name);
    IF (PrivateLayout <> NIL) THEN
        Layout := PrivateLayout;
    END;
END ReadLayoutName;




PROCEDURE ReadLayoutRecordBody ( VAR f          : File;
                                     Length     : CARDINAL;
                                     Layout     : AChartFormatPtr   );
TYPE
    AV3ChartFormat   =  RECORD
                          Tag               : CARDINAL;
                          ID                : CARDINAL;
                          scale             : ADuration;
                          scaleunit         : ADurationUnit;
                          slackstyle        : ASlackStyle;
                          Name              : ARRAY [0..20] OF CHAR;
                          AVPShowing        : BOOLEAN;
                          GanttShowing      : BOOLEAN;
                          TaskNameOnScreen  : BOOLEAN;
                          Notes             : AText;
                          GanttWidth        : CARDINAL;
                          GanttPosition     : CARDINAL;
                          ColumnCount       : CARDINAL;
                          LayoutFlags       : BITSET;
                        END;
CONST
    Version4Size        = TSIZE(AChartFormat) -
                          NumOfColumns * TSIZE(AChartColumnSpec);
    Version3Size        = TSIZE(AV3ChartFormat);

VAR
    V3ChartFormat       : AV3ChartFormat;

BEGIN
    IF (Length = Version3Size) THEN
        ReadRecordBody (f, Length, ADR(V3ChartFormat), Version3Size);
        WITH Layout^ DO
            Tag               := V3ChartFormat.Tag;
            ID                := V3ChartFormat.ID;
            scale             := V3ChartFormat.scale;
            scaleunit         := V3ChartFormat.scaleunit;
            slackstyle        := V3ChartFormat.slackstyle;
            Copy (V3ChartFormat.Name, Name);
            AVPShowing        := V3ChartFormat.AVPShowing;
            GanttShowing      := V3ChartFormat.GanttShowing;
            TaskNameOnScreen  := V3ChartFormat.TaskNameOnScreen;
            Notes             := AText(NIL);
            GanttWidth        := V3ChartFormat.GanttWidth;
            GanttPosition     := V3ChartFormat.GanttPosition;
            ColumnCount       := V3ChartFormat.ColumnCount;
            LayoutFlags       := V3ChartFormat.LayoutFlags;
        END;
    ELSE
        ReadRecordBody (f, Length, Layout, Version4Size);
    END;
END ReadLayoutRecordBody;



(*
    UpdateOldColumnID --

    Account for any column IDs that have changed since prior releases.

    This version of the procedure currently handles the version 4 to
    version 5 changes.

*)

PROCEDURE UpdateOldColumnID(VAR ID : CARDINAL);

CONST
    (*  The Aux ("CodingField") columns were moved from version
        4 to version 5.  *)
    OldAuxCol1          = 103;
    OldAuxCol20         = 122;

BEGIN
    IF (ID >= OldAuxCol1) AND (ID <= OldAuxCol20) THEN
        ID := CodingField1 + (ID - OldAuxCol1);
    END;
END UpdateOldColumnID;


    

PROCEDURE GetLayoutsInfo(VAR f:File; DuplicatesOKProc : ADuplicatesOKProc;
                                     UpdateCurrent    : BOOLEAN;
                                     AdjustColumns    : BOOLEAN );
(*  If UpdateCurrent is FALSE, then we won't read the current selection
    of the current layout.
    This requires saving the ID numbers of the current selection before
    getting stuff from the file (in case of duplicates).
*)

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    LayoutNumber            : CARDINAL;
    LayoutRecord            : AChartFormatPtr;
    Node                    : ATreeNode;
    OldLayout               : ATreeNode;
    OldLayoutRecord         : AChartFormatPtr;
    Header                  : AHeaderRecord;
    i                       : CARDINAL;
    AllowThisOne            : BOOLEAN;

BEGIN
    IF (NOT StartSubfileInput(f,LayoutsType,Version)) THEN
        RETURN;
    END;

    LayoutRecord := NIL;                                          (* 18-Feb-88 LAA *)

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            0  :  ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

          | 1  :
                  IF (LayoutRecord <> NIL) THEN                   (* 18-Feb-88 LAA *)
                      Compress(LayoutRecord^.Notes);
                  END;
                  IF (NOT CreateLayout (Node)) THEN RETURN; END;
                  LayoutRecord := Node^.Methods^.GetDataObject (Node);
                  ReadLayoutRecordBody (f, Length, LayoutRecord);

                  LayoutRecord^.Notes := AText(NIL);
                  AllowThisOne        := TRUE;
                  OldLayout           := FindLayoutByName (LayoutRecord^.Name);
                  IF (OldLayout <> NIL) THEN
                      OldLayoutRecord  := OldLayout^.Methods^.GetDataObject (OldLayout);

                          (* We cannot override layouts from the config file,
                             or if the user says not to. *)

                      IF (DuplicatesOKProc( OldLayoutRecord^.Name )) THEN
                          IF (CurrentChartFormat = OldLayout) THEN
                              CurrentChartFormat := Node;
                          END;
                          DiscardLayout (OldLayout);
                      ELSE
                          AllowThisOne := FALSE;
                          OldLayoutRecord^.ID := LayoutRecord^.ID;
                          DiscardLayout (Node);
                      END;
                  END;

                  IF (AllowThisOne) THEN
                      AttachNodeOnTree (LayoutTree, Node, Header.Level);
                      Node^.Methods^.SetAttributes (Node, Header.Attributes);
                  END;

          | 2  :  IF (AllowThisOne) THEN
                      ReadRecordBody (f, Length, ADR(LayoutRecord^.ColumnSpec),
                            SIZE(LayoutRecord^.ColumnSpec));
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 10 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadLayoutNumber (f, Length, CurrentChartFormat);  (* 15-Jan-88 LAA *)

          | 30 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadLayoutName (f, Length, CurrentChartFormat);  (* 15-Jan-88 LAA *)

          | 100 : IF (AllowThisOne) THEN
                      ReadManyOldTextLines(f, Length, 100, LayoutRecord^.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 102 : IF (AllowThisOne) THEN
                      ReadManyTextLines(f, Length, 102, LayoutRecord^.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
    IF (LayoutRecord <> NIL) THEN                                 (* 18-Feb-88 LAA *)
        Compress(LayoutRecord^.Notes);

        IF (AdjustColumns) THEN             (* 16-Aug-91 PFG *)
            WITH LayoutRecord^ DO
                FOR i := 1 TO ColumnCount DO
                    UpdateOldColumnID(ColumnSpec[i].ColumnID);
                END;
            END;
        END;

    END;
    SortLayouts();

END GetLayoutsInfo;






PROCEDURE FindNetLayoutByNumber( MatchID  : CARDINAL ) : ATreeNode;
VAR
    LayoutNode : ATreeNode;
    Layout     : ANetworkLayout;
BEGIN
    LayoutNode := NetLayoutTree^.Methods^.GetFirst(NetLayoutTree);
    LOOP
        IF (LayoutNode = NIL) THEN
            EXIT;
        END;
        Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);
        IF (Layout^.ID = MatchID) THEN
            EXIT;
        END;
        LayoutNode := LayoutNode^.Methods^.NextPreOrder(LayoutNode);
    END;
    RETURN LayoutNode;
END FindNetLayoutByNumber;






PROCEDURE ReadNetLayoutNumber(VAR f      : File;
                                  Length : CARDINAL;
                              VAR Layout : ATreeNode);
VAR
    Number : CARDINAL;
    PrivateLayout : ATreeNode;

BEGIN
    ReadRecordBody(f,Length,ADR(Number),SIZE(Number));
    PrivateLayout := FindNetLayoutByNumber(Number);               (* 15-Jan-88 LAA *)
    IF (PrivateLayout <> NIL) THEN
        Layout := PrivateLayout;
    END;
END ReadNetLayoutNumber;




                                (* 3/1/88 EGK *)

PROCEDURE ReadNetLayoutName  (VAR f      : File;
                                  Length : CARDINAL;
                              VAR Layout : ATreeNode);
VAR
    Name          : ARRAY [0..20] OF CHAR;
    PrivateLayout : ATreeNode;

BEGIN
    ReadStringBody (f,Length,Name);
    PrivateLayout := FindNetLayoutByName (Name);
    IF (PrivateLayout <> NIL) THEN
        Layout := PrivateLayout;
    END;
END ReadNetLayoutName;





PROCEDURE GetNetLayoutsInfo(VAR f                : File;
                                DuplicatesOKProc : ADuplicatesOKProc;
                                UpdateCurrent    : BOOLEAN;
                                AdjustColumns    : BOOLEAN );
VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    LayoutNumber            : CARDINAL;
    Node                    : ATreeNode;
    OldLayout               : ATreeNode;
    Header                  : AHeaderRecord;
    LayoutRecord            : ANetworkLayout;
    OldLayoutRecord         : ANetworkLayout;
    i                       : CARDINAL;
    AllowThisOne            : BOOLEAN;


    PROCEDURE LayoutChanged     ( OldOne    : ATreeNode;
                                  NewOne    : ATreeNode );
    BEGIN
        IF (CurrentNetLayout = OldOne) THEN
            CurrentNetLayout := NewOne;
        END;
        IF (EnlargedNetLayout = OldOne) THEN
            EnlargedNetLayout := NewOne;
        END;
    END LayoutChanged;


BEGIN
    IF (NOT StartSubfileInput(f,NetLayoutsType,Version)) THEN
        RETURN;
    END;

    LayoutRecord := NIL;                                          (* 18-Feb-88 LAA *)
    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            0  :  ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

          | 1  :
                  IF (LayoutRecord <> NIL) THEN                   (* 18-Feb-88 LAA *)
                      Compress(LayoutRecord^.Notes);
                  END;
                  IF (NOT CreateNetLayout(Node)) THEN RETURN; END;
                  LayoutRecord := Node^.Methods^.GetDataObject (Node);
                  ReadRecordBody(f,Length,LayoutRecord,SIZE(LayoutRecord^));

                  LayoutRecord^.Notes := AText(NIL);
                  AllowThisOne        := TRUE;
                  OldLayout           := FindNetLayoutByName(LayoutRecord^.Name);
                  IF (OldLayout <> NIL) THEN
                      OldLayoutRecord  := OldLayout^.Methods^.GetDataObject (OldLayout);

                          (* We cannot override layouts from the config file,
                             or if the user says not to. *)

                      IF (DuplicatesOKProc( OldLayoutRecord^.Name )) THEN
                          LayoutChanged (OldLayout, Node);
                          DiscardNetLayout (OldLayout);
                      ELSE
                          AllowThisOne := FALSE;
                          OldLayoutRecord^.ID := LayoutRecord^.ID;
                          DiscardNetLayout(Node);
                      END;
                  END;

                  IF (AllowThisOne) THEN
                      AttachNodeOnTree(NetLayoutTree, Node, Header.Level);
                      Node^.Methods^.SetAttributes(Node, Header.Attributes);
                  END;

          | 10 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadNetLayoutNumber (f, Length, CurrentNetLayout);  (* 15-Jan-88 LAA *)

          | 20 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadNetLayoutNumber (f, Length, EnlargedNetLayout);

          | 40 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadNetLayoutName (f, Length, CurrentNetLayout);  (* 15-Jan-88 LAA *)

          | 50 :  IF (NOT UpdateCurrent) THEN
                      EXIT;
                  END;
                  ReadNetLayoutName (f, Length, EnlargedNetLayout);

          | 100 : IF (AllowThisOne) THEN
                      ReadManyOldTextLines(f, Length, 100, LayoutRecord^.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 102 : IF (AllowThisOne) THEN
                      ReadManyTextLines(f, Length, 102, LayoutRecord^.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
    IF (LayoutRecord <> NIL) THEN                                 (* 18-Feb-88 LAA *)
        Compress(LayoutRecord^.Notes);

        IF (AdjustColumns) THEN             (* 16-Aug-91 PFG *)
            WITH LayoutRecord^ DO
                FOR i := 1 TO 6 DO
                    UpdateOldColumnID(Fields[i].ColumnID);
                END;
            END;
        END;

    END;
    SortNetLayouts();

END GetNetLayoutsInfo;


PROCEDURE ComparePalettes(    Palette1  : AnObject;
                              Palette2  : AnObject): BOOLEAN;

VAR
    s1, s2              : ARRAY [0..41] OF CHAR;

BEGIN                   (* ComparePalettes *)

    GetPaletteName(ATreeNode(Palette1), s1);
    GetPaletteName(ATreeNode(Palette2), s2);

    RETURN (Compare(s1, s2) > 0);

END ComparePalettes;



(*  GetPalettesInfo --

    Retrieve the Palettes information from the indicated file, allowing
    duplicates and overwriting existing Palettes as indicated.

    Preconditions:
        IlsaStatic must have been initialized, and TLStart run.

    Postconditions:
        The PaletteTrees in IlsaStatic will be updated from the file as
        appropriate.
*)

PROCEDURE GetPalettesInfo      (VAR f                : File;
                                    Kind             : ATLGSChartType;
                                    DuplicatesOKProc : ADuplicatesOKProc;
                                    UpdateCurrent    : BOOLEAN           );

VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    PaletteNumber           : CARDINAL;
    Node                    : ATreeNode;
    OldPaletteNode          : ATreeNode;
    Header                  : AHeaderRecord;
    Palette                 : ATLGSColorAssignmentPtr;
    OldPalette              : ATLGSColorAssignmentPtr;
    LocalID                 : CARDINAL;
    LocalName               : ARRAY [0..21] OF CHAR;
    AllowThisOne            : BOOLEAN;

BEGIN                       (* GetPalettesInfo *)

    IF (NOT StartSubfileInput(f,PalettesType + ORD(Kind),Version)) THEN
        RETURN;
    END;

    Node := NIL;
    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;
        CASE Type OF
            0  :  ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

          | 1  :
                  IF (Node <> NIL) THEN                   (* 18-Feb-88 LAA *)
                      Palette := Node^.Methods^.LockFlexStorDataObject (Node);
                      Compress(Palette^.Notes);
                      Node^.Methods^.UnlockFlexStorDataObject(Node);
                  END;
                  Node := CreatePalette(DefaultPalette[Kind]);    (* 01-Dec-89 LAA *)
                  IF (Node = ATreeNode(NIL)) THEN RETURN; END;
                  Palette := Node^.Methods^.LockFlexStorDataObject (Node);
                  ReadRecordBody(f,Length,Palette,SIZE(Palette^));

                  Palette^.Notes := AText(NIL);
                  Copy(Palette^.Name, LocalName);
                  LocalID := Palette^.ID;
                  Node^.Methods^.UnlockFlexStorDataObject(Node);

                  AllowThisOne        := TRUE;
                  OldPaletteNode      := FindPaletteByName(Kind, LocalName);
                  IF (OldPaletteNode <> NIL) THEN
                      OldPalette  := OldPaletteNode^.Methods^.LockFlexStorDataObject (OldPaletteNode);

                          (* We cannot override palettes from the config file,
                             or if the user says not to. *)

                      IF (DuplicatesOKProc( OldPalette^.Name )) THEN
                          OldPaletteNode^.Methods^.UnlockFlexStorDataObject(OldPaletteNode);
                          OldPaletteNode^.Methods^.DeList(OldPaletteNode);
                          DiscardPalette (OldPaletteNode);
                      ELSE
                          AllowThisOne := FALSE;
                          OldPalette^.ID := LocalID;
                          OldPaletteNode^.Methods^.UnlockFlexStorDataObject(OldPaletteNode);
                          DiscardPalette(Node);
                      END;
                  END;

                  IF (AllowThisOne) THEN
                      AttachNodeOnTree(PaletteTree[Kind], Node, Header.Level);
                      Node^.Methods^.SetAttributes(Node, Header.Attributes);
                  END;

          | 100,
            102 : IF (AllowThisOne) THEN
                      Palette := Node^.Methods^.LockFlexStorDataObject (Node);
                      IF (Type = 100) THEN
                          ReadManyOldTextLines(f, Length, 100, Palette^.Notes);
                      ELSE
                          ReadManyTextLines(f, Length, 102, Palette^.Notes);
                      END;
                      Node^.Methods^.UnlockFlexStorDataObject(Node);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;
    IF (Node <> NIL) THEN
        Palette := Node^.Methods^.LockFlexStorDataObject (Node);
        Compress(Palette^.Notes);
        Node^.Methods^.UnlockFlexStorDataObject(Node);
    END;
    IF (SortTree(PaletteTree[Kind], ComparePalettes)) THEN END;

END GetPalettesInfo;




PROCEDURE GetHeldItems(VAR f:File);

VAR
    Version,
    Type,
    Length,
    Class,
    Size            : CARDINAL;
    Handle          : AnExtHandle;
    Where           : ADDRESS;
    Category        : AHoldTypeSet;
    Name            : ARRAY [0..30] OF CHAR;
    ExistsFlag      : BOOLEAN;
    CreateFlag      : BOOLEAN;


    PROCEDURE NameMatches( This : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        s           : ARRAY [0..30] OF CHAR;
    BEGIN
        SetString( s, This );
        RETURN StringsEqual(s,Name);
    END NameMatches;


    (* 23-Jan-91 RSC *)
    PROCEDURE MaybeAdjustCategory();
    BEGIN
        IF (NameMatches( "TlarData" ) OR
            NameMatches( "TLIFORM"  ) OR
            NameMatches( "TLXFORM"  ) OR
            NameMatches( "TLSR"     ) OR
            NameMatches( "TLDR"     ) OR
            NameMatches( "TLWBS"    )) THEN
            INCL(Category,HoldInFlexStor);
            INCL(Category,HeapNoOwner); (* 13-Feb-91 RSC  *)
        END;
    END MaybeAdjustCategory;



BEGIN
    IF (StartSubfileInput(f,HeldItemsType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1 :     (* Name *)
                    ReadStringBody(f,Length,Name);
                    Category := AHoldTypeSet{};
                    Class    := 0;

            |   2 :     (* Class *)
                    ReadRecordBody(f,Length,ADR(Class),SIZE(Class));

            |   3 :     (* Category *)
                    ReadRecordBody(f,Length,ADR(Category),SIZE(Category));

            |   4 :     (* Data item *)
                    MaybeAdjustCategory();

                    ExistsFlag := (LocateHeldItem(Name,Class,Category,Where,Size));

                      (* If it exists, but with a different size, blast the
                         version now in memory.   RSC 10/17/88.
                         If it exists with the same size, we just store the
                         new data at the location of the old data.  EGK 11/1/88.
                      *)

                    CreateFlag := TRUE;
                    IF (ExistsFlag) THEN
                        IF NOT (AllowDuplicates IN Category) THEN
                            IF (ErrorIfDuplicate IN Category) THEN
                                FatalError();
                            ELSIF (Length <> Size) THEN
                                DeleteHeldItem (Name, Class);
                            ELSE
                                CreateFlag := FALSE;
                            END;
                        END;
                    END;

                    IF (CreateFlag) THEN
                        Size := Length;   (* RSC 1/26/88 *)
                        IF (HoldInFlexStor IN Category) THEN
                            IF (CreateExtObjectWithSize( Handle, ExtSlow, Size )) THEN
                                Size := LockObject( Handle, Where );
                            ELSE
                                RETURN;  (* No room for this item? *)
                            END;
                        ELSE
                            IF (Available( Size )) THEN
                                ALLOCATE(Where,Size);
                            ELSE
                                RETURN;  (* No room for this item? *)
                            END;
                        END;
                        INCL (Category, HeapNoOwner);
                    ELSIF (HoldInFlexStor IN Category) THEN
                        Handle := AnExtHandle (Where);
                        Size := LockObject (Handle, Where);
                    END;

                          (* Load the data item into memory. *)

                    ReadRecordBody(f,Length,Where,Size);

                    IF (HoldInFlexStor IN Category) THEN
                        ReleaseObject (Handle);
                    END;
                    IF (CreateFlag) THEN
                        IF (HoldInFlexStor IN Category) THEN
                            Where := ADDRESS(Handle);
                        END;
                        HoldThis(Name,Class,Category,Where,Size);
                    END;

            |   0FFH :
                    EXIT;        (* End of subfile. *)

            ELSE
                SkipRecordBody(f,Length);
            END;
        END;
    END;
END GetHeldItems;





BEGIN
    ErrorFlag           := FALSE;
    FiscalCalendarFound := FALSE;
    ReadingFileVersion  := 500;   (* 20-Aug-90 RSC assume a new BigTime format. *)
END LoadCommon.

