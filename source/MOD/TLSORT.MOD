MODULE TLSort;

(*  =========================================================================
    Last Edit : April 15, 1991 6:13PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        19-Jan-88 LAA   Made this an installable overlay.
        08-Feb-88 LAA   Adjusted for new parameters to GetColumnInfo.
        11-Feb-88 LAA   Secondary sort is on EarlyStart.
        23-Feb-88 LAA   Upshift strings before comparing.
        01-Mar-88 LAA   Fixed bug which was causing erratic sorts, because
                        last manual sort order was incorrectly used as a tie
                        breaker when sorting by early start date.
        31-Oct-88 EGK   Added "Quit" option to the menu.
        27-Dec-88 LAA   Changed parameters to GetColumnInfo and GetColumnValue.
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        23-Jan-89 RSC   Removed Storage.  Changed call sequence of Sort routines.
        24-Jan-88 AJL   Added multiple keys.
        13-Feb-89 RSC   Upgraded to LAZLO captions.
        27-Feb-89 EGK   Changed CompareDataRecords to allow comparing of type
                        IsEndDate with type IsMilestoneEnd.
        20-Mar-89 LAA   Replaced ColumnName module with TaskColumns.
        27-Apr-89 EGK   Fixed CompareDataRecords to treat values of
                        "IsTruncatedString" as equivalent to values of
                        "IsStringValue".
        26-May-89 EGK   Removed the getting and putting of rugs.  In some
                        cases it was restoring old light information that
                        was no longer valid.
         4-Jun-89 EGK   Put in explicit calls to SendNotices, since
                        Permission doesn't do it automatically any more.
        10-Aug-89 KKC   Add copyright message.
        21-Aug-89 EGK   Changed menu string for "other keys" to not include
                        1 or 2, and adjusted logic to offset the remaining
                        choices appropriately.  Moved the setting of
                        ExitFlag so that "Last Manual" always exits the
                        main sort menu.
        17-Sep-89 WKH   Remember the sort keys from previous sort.
        21-Sep-89 WKH   Make the holder record that remembers the sort keys
                        "live" throught schedule erase, but not forever.
        12-Dec-89 RSC   New parameters for Menu.
        03-Jan-90 EGK   Changed menus to be non-modal.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
         8-Apr-91 TGS   Import Task numbers from TaskColNumbers.
        15-Apr-91 RSC   Changed MenuWithPrompts params.
        28-Oct-91 TGS   Fixed one of RSC's MenuWithPrompts params:
                        (NoPrompts-->PromptsFromPhrases)
    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView, AnActiveViewMethods,
    (* PROC *)                  CreateActiveView, CloneActiveViewMethods;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* VAR *)                   TaskTree;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  BigTimeToTime;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo, GetColumnValue;

FROM Chart                  IMPORT
    (* VAR *)                   GanttChart;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode,
    (* CONST *)                 EmptyCodeSet;

FROM Dialog                 IMPORT
    (* PROC *)                  Burp, Message, Error, FatalError, MessageBox;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM Gantt                  IMPORT AGanttLineType;

FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  HoldThis, LocateHeldItem;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, DoIt, InsertKey, DeleteKey,
                                CancelKey, SelectKey, MoveUpKey, MoveDownKey;

FROM Layout                 IMPORT
    (* CONST *)                 MenuStart, MenuEnd, MaxColumn, MaxRow;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                Insert, Procustes, TrimFront, TrimRear, Fill,
                                LengthOf, Copy, Compare, SetLengthOf,
                                Upshift, TStringToLString;

FROM MagicNum               IMPORT
    (* CONST *)                 IsStringValue,
                                IsRealValue,
                                IsIntValue,
                                IsCardValue,
                                IsBoolValue,
                                IsEnumValue,
                                IsBigStart,
                                IsBigEnd,
                                IsStartDate,
                                IsEndDate,
                                IsDuration,
                                IsSlack,
                                IsCurrency,
                                IsEffort,
                                IsMilestoneEnd,
                                IsDurationUnits,
                                IsEffortUnits,
                                IsTruncatedString;

FROM Menus                  IMPORT
    (* TYPE *)                  APromptType,
    (* PROC *)                  Menu, MenuWithPrompts;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  Permission, SendNotices;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved, SortSelection,
                                SortOrderManuallyAltered,
                                WarnBeforeManualChange;

FROM SegWords               IMPORT
    (* PROC *)                  WordNumber;

FROM Sorter                 IMPORT
    (* TYPE *)                  AnObjectCompareProc,
    (* PROC *)                  SortTree;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;

FROM TaskColNumbers         IMPORT 
    (* CONST *)                 ResourceColumn,
                                CostColumn,
                                CostAmount,
                                ResourceAmount; 

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

FROM Timei                  IMPORT
    (* TYPE *)                  ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;



CONST
    ModuleNumber            = 19500;
    EarlyStartID            = 4;                                  (* 11-Feb-88 LAA *)
    MAXKEYS                 = 9;                                  (* Max user-specified keys. *)
    KeySettingsName         = "SortKeys";                         (* 17-Sep-89 WKH *)

TYPE
    AKeySpecification = RECORD
                            ColumnChosen  : CARDINAL;
                            Ascending     : BOOLEAN;
                            Valid         : BOOLEAN;
                        END;

    AnArrayOfKeys     = ARRAY [0..MAXKEYS] OF AKeySpecification;

    AnArrayOfKeysPtr  = POINTER TO AnArrayOfKeys;

VAR
    Rug                     : ARug;
    Key                     : AnArrayOfKeysPtr;
    OverlayID               : AnOverlayID;



PROCEDURE DoColumnNamesList(VAR ColumnID    : CARDINAL): ACode;

CONST
    ULX                     = 48;
    ULY                     = 5;
    LRX                     = 79;
    LRY                     = 22;

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* DoColumnNamesList *)

    IF (PickTaskColumn(ULX, ULY, LRX, LRY, ColumnID, s)) THEN     (* 20-Mar-89 LAA *)
        RETURN ExitKey;
    END;

    RETURN CancelKey;

END DoColumnNamesList;








PROCEDURE CompareDataRecords( VAR D1, 
                                  D2            : AColumnDataRecord;
                                  SortSelection : CARDINAL
                                              ) : INTEGER;
VAR
    j          : INTEGER;
    R1, R2     : REAL;
    Compatible : BOOLEAN;
    String1    : ARRAY [0..255] OF CHAR;
    String2    : ARRAY [0..255] OF CHAR;



    PROCEDURE GetReal( VAR D : AColumnDataRecord ) : REAL;
    CONST
        MAXINT       = 32767.0;
        FMAXCARDINAL = 65536.0;
    VAR
        TimeInfo    : ATimeInfo;
        TimeValue   : CARDINAL;
        R           : REAL;
    BEGIN
        CASE D.DataType OF
           IsRealValue,
           IsCurrency,
           IsSlack,
           IsDuration,
           IsDurationUnits,
           IsEffortUnits,
           IsEffort         :
                    RETURN D.RealValue;
         | IsIntValue       :
                    R := FLOAT(CARDINAL(D.IntegerValue));
                    IF (R > MAXINT) THEN        (* If it was negative, *)
                        R := R - FMAXCARDINAL;  (* Be positive!        *)
                    END;
                    RETURN R;
         | IsCardValue      :
                    RETURN FLOAT(D.CardinalValue);
         | IsBoolValue      :
                    RETURN FLOAT(ORD(D.BooleanValue));
         | IsBigStart,
           IsBigEnd         :
                    BigTimeToTime
                    (
                        D.BigTimeValue,
                        TimeInfo.tiYear,
                        TimeInfo.tiMonth,
                        TimeInfo.tiDay,
                        TimeInfo.tiHour,
                        TimeInfo.tiMinute,
                        TimeInfo.tiSecond
                    );
                    IF (NOT TtoTimeU( TimeInfo, TimeValue )) THEN
                        TimeValue := 0;
                    END;
                    RETURN FLOAT(TimeValue);
         | IsStartDate,
           IsMilestoneEnd,
           IsEndDate        :
                    RETURN FLOAT(D.DateValue);
        ELSE
            FatalError();
        END;
    END GetReal;


    (* If the selected column is a resource column,
     * we only want to sort on the FIRST resource.
     * since the resource and cost names are delimited by
     * commas, we can use WordNumber's default parameters
     * and get what we want.
     *)

    PROCEDURE GetFirstIfResource();
    BEGIN

        IF((SortSelection = ResourceColumn) OR
           (SortSelection = CostColumn)     OR
           (SortSelection = CostAmount)     OR
           (SortSelection = ResourceAmount)) 
        THEN
            WordNumber(D1.StringValue, 1, String1);
            WordNumber(D2.StringValue, 1, String2);
        ELSE
            Copy(D1.StringValue, String1);
            Copy(D2.StringValue, String2);
        END;

    END GetFirstIfResource;
 

BEGIN

    IF (D1.DataType = IsEndDate) OR (D1.DataType = IsMilestoneEnd) THEN
        Compatible := ((D2.DataType = IsEndDate) OR (D2.DataType = IsMilestoneEnd));
    ELSIF (D1.DataType = IsStringValue) OR (D1.DataType = IsTruncatedString) THEN
        Compatible := ((D2.DataType = IsStringValue) OR (D2.DataType = IsTruncatedString));
    ELSE
        Compatible := (D1.DataType = D2.DataType);          (* 2/27/89 EGK *)
    END;

    IF (NOT Compatible) THEN
        FatalError();
    END;

    IF (D1.DataType = IsStringValue) OR
       (D1.DataType = IsTruncatedString) OR     (* 4/27/89 EGK *)
       (D1.DataType = IsEnumValue)   THEN
        GetFirstIfResource();
        Upshift(String1);
        Upshift(String2);
        j := Compare(String1, String2);
    ELSE
        R1 := GetReal( D1 );
        R2 := GetReal( D2 );
        IF (R1 > R2)    THEN
            j :=  1;
        ELSIF (R1 < R2) THEN
            j := -1;
        ELSE
            j := 0;
        END;
    END;

    RETURN j;

END CompareDataRecords;







PROCEDURE CompareTasks(TaskA, TaskB :ATreeNode):BOOLEAN;
VAR
    SortSelection           : CARDINAL;
    TASortOrder,
    TBSortOrder             : CARDINAL;
    i, j                    : INTEGER;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
    DataRecord2             : AColumnDataRecord;
    Ascending               : BOOLEAN;
    okA, okB                : BOOLEAN;
BEGIN


    i := 0;
    WHILE (i <= HIGH(Key^)) DO

        IF (Key^[i].Valid) THEN

            SortSelection := Key^[i].ColumnChosen;
            Ascending     := Key^[i].Ascending;

            T := TaskA^.Methods^.LockFlexStorDataObject(TaskA);           (* 08-Feb-88 LAA *)
            okA := GetColumnValue( TaskA, T, SortSelection, Plan, DataRecord);
            TASortOrder := T^.TaskSortOrder;
            TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);     T := NIL;

            T := TaskB^.Methods^.LockFlexStorDataObject(TaskB);
            okB := GetColumnValue( TaskB, T, SortSelection, Plan, DataRecord2);
            TBSortOrder := T^.TaskSortOrder;
            TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);     T := NIL;


            IF (okA AND okB) THEN
                j := CompareDataRecords( DataRecord, DataRecord2,
                                         SortSelection );
            ELSIF (okA) THEN
                j := 1;
            ELSIF (okB) THEN
                j := -1;
            ELSE
                j := 0;
            END;


            IF (Ascending) THEN
                IF (j > 0) THEN
                    RETURN TRUE;
                ELSIF (j < 0) THEN
                    RETURN FALSE;
                END;
            ELSE
                IF (j < 0) THEN
                    RETURN TRUE;
                ELSIF (j > 0) THEN
                    RETURN FALSE;
                END;
            END;
        END;

        INC(i);                            (* On to the next key field. *)

    END;

    RETURN (TASortOrder > TBSortOrder);    (* Final tie-breaker if all else failed. *)

END CompareTasks;






PROCEDURE SortTasks();

VAR
    Node                    : ATreeNode;

BEGIN

    IF (Permission(ScheduleSort,NIL)) THEN
        SendNotices (ScheduleSort, BeforeActing, NIL);      (* 6/4/89 EGK *)
        IF (SortTree(TaskTree,AnObjectCompareProc(CompareTasks))) THEN
            SendNotices(ScheduleSort,AfterActing,NIL);
        ELSE
            SendNotices(ScheduleSort,FailureToAct,NIL);
        END;
        Node := TaskTree^.Methods^.GetFirst(TaskTree);
        UnSetState (Formatted);
    END;

END SortTasks;




PROCEDURE RenumberTasks();

VAR
    i                       : CARDINAL;
    Task                    : ATaskPtr;
    Node                    : ATreeNode;

BEGIN                       (* RenumberTasks *)

    i := 1;
    Node := TaskTree^.Methods^.GetFirst(TaskTree);
    WHILE (Node <> NIL) DO
        Task := Node^.Methods^.LockFlexStorDataObject(Node);
        Task^.TaskSortOrder := i;
        Node^.Methods^.UnlockUnchangedDataObject(Node);           (* 11-Jan-88 LAA *)
        INC(i);
        Node := Node^.Methods^.NextPreOrder(Node);
    END;

END RenumberTasks;





PROCEDURE CompareLastManual(TaskA, TaskB :ATreeNode) : BOOLEAN;

VAR
    T                       : ATaskPtr;
    TASortOrder,
    TBSortOrder             : CARDINAL;

BEGIN

    T := TaskA^.Methods^.LockFlexStorDataObject(TaskA);
    TASortOrder := T^.TaskSortOrder;
    TaskA^.Methods^.UnlockUnchangedDataObject(TaskA);             (* 11-Jan-88 LAA *)
    T := TaskB^.Methods^.LockFlexStorDataObject(TaskB);
    TBSortOrder := T^.TaskSortOrder;
    TaskB^.Methods^.UnlockUnchangedDataObject(TaskB);             (* 11-Jan-88 LAA *)

    RETURN (TASortOrder > TBSortOrder);

END CompareLastManual;




PROCEDURE ReturnToManualOrder();

VAR
    CNode                   : ATreeNode;
    Node                    : ATreeNode;

BEGIN                       (* ReturnToManualOrder *)

    CNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    IF (Permission(ScheduleSort,NIL)) THEN
        SendNotices (ScheduleSort, BeforeActing, NIL);      (* 6/4/89 EGK *)
        IF (SortTree(TaskTree,AnObjectCompareProc(CompareLastManual))) THEN
            SendNotices(ScheduleSort,AfterActing,NIL);
        ELSE
            SendNotices(ScheduleSort,FailureToAct,NIL);
        END;
        Node := TaskTree^.Methods^.GetFirst(TaskTree);
        UnSetState (Formatted);
    END;

END ReturnToManualOrder;



PROCEDURE GeneratePrompts(    ChoiceKey     : CARDINAL;
                          VAR PromptString  : ARRAY OF CHAR);

BEGIN                       (* GeneratePrompts *)

    GetMessage(ChoiceKey, PromptString);

END GeneratePrompts;


    (* Ask if this key is to be sorted ascendingly or descendingly. *)

PROCEDURE PickADirection( VAR Ascending:BOOLEAN ):BOOLEAN;
VAR
    Choice                  : CARDINAL;
    Prefix                  : ARRAY [0..31] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber + 20, Prefix);       (* Sort Order *)
    GetMessage(ModuleNumber + 21, Choices);      (* Ascending,Descending *)
    Choice := ORD(NOT Ascending)+1;
    IF (MenuWithPrompts(Prefix, Choices, 0, MenuStart, MaxColumn, MenuEnd,
                        ABoxType{NoBox}, EmptyCodeSet, PromptFromPhrases,
                        ModuleNumber + 22, AText(NIL),
                        FALSE,      (* 12-Dec-89 RSC MODAL *)   (* 3-Jan-90 EGK Non-modal *)
                        Choice) <> CancelKey) THEN

        Ascending := ( Choice = 1 );
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END PickADirection;




PROCEDURE SetKey( KeyNumber : CARDINAL ) : BOOLEAN;
VAR
    ColumnChosen            : CARDINAL;
    Kind                    : REAL;
BEGIN

    IF PickADirection(Key^[KeyNumber].Ascending) THEN
        DisplayMessage(ModuleNumber + 8);                      (* Choose a column of task information to sort by *)
        ColumnChosen := Key^[KeyNumber].ColumnChosen;           (* Last time. *)
        IF (DoColumnNamesList(ColumnChosen) <> CancelKey) THEN
            Key^[KeyNumber].ColumnChosen := ColumnChosen;
            Key^[KeyNumber].Valid        := TRUE;
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END SetKey;






PROCEDURE TLSortBody();
VAR
    i                       : CARDINAL;
    SortChoice,KeyChoice    : CARDINAL;
    Prefix                  : ARRAY [0..21] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..9] OF CHAR;
    RugTaken                : BOOLEAN;
    ExitFlag                : BOOLEAN;
    Copyright               : ARRAY[0..50] OF CHAR;
    Class                   : CARDINAL;
    Size                    : CARDINAL;
    Name                    : ARRAY[0..9] OF CHAR;
    Category                : AHoldTypeSet;

BEGIN                       (* TLSortBody *)
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    Class := 1;
    SetString(Name, KeySettingsName);  (* SortKeys *)
    IF (NOT LocateHeldItem(Name, Class, Category, Key, Size)) OR
       (Size <> TSIZE(AnArrayOfKeys)) THEN
        IF (Available(TSIZE(AnArrayOfKeys))) THEN
            NEW(Key);

            FOR i := 0 TO HIGH(Key^) DO
                WITH Key^[i] DO
                    Valid        := FALSE;
                    ColumnChosen := 0;
                    Ascending    := TRUE;
                END;
            END;

                (* Tie breaker number *)
            WITH Key^[HIGH(Key^)] DO
                ColumnChosen := EarlyStartID;
                Ascending    := TRUE;
                Valid        := TRUE;
            END;

            Category := AHoldTypeSet{HeapNoOwner};
            HoldThis( Name, Class, Category, Key, TSIZE(AnArrayOfKeys));
        ELSE
            GetMessage(ModuleNumber + 7, Choices);
            Error(Choices);
            RETURN;
        END;
    END;

    IF (NOT CreateTaskColumnsTree()) THEN                         (* 20-Mar-89 LAA *)
        GetMessage(ModuleNumber + 7, Choices);
        Error(Choices);
        RETURN;
    END;

        (*  Erase the "Loading TLSort" message *)

    SetLengthOf(Prefix, 0);
    Message(Prefix);


    SortChoice := 1;

    KeyChoice  := 1;            (* If choosing secondary keys. *)

         (* Do the menu. *)

    REPEAT

        ExitFlag := FALSE;

        GetMessage(ModuleNumber + 1, Prefix);                          (* SORT *)
        GetMessage(ModuleNumber + 2, Choices);                         (* Primary,Secondary,Other Keys,Last Manual Order,Go,Quit *)

        IF (MenuWithPrompts(Prefix, Choices, 0, MenuStart, maxcol, MenuEnd,
                            ABoxType{NoBox}, EmptyCodeSet, PromptFromPhrases, (* 28-Oct-91 TGS *)
                            ModuleNumber + 10, AText(NIL),
                            FALSE,       (* 12-Dec-89 RSC MODAL *)  (* 3-Jan-90 EGK Non-modal *)
                            SortChoice) <> CancelKey)
                AND (SortChoice <> 6 (*QUIT*)  ) THEN
    (*
            RugTaken := GetRug(0, 0, MaxColumn, MaxRow, Rug);
    *)
            IF (SortChoice = 4 (*LAST MANUAL*) ) THEN
                IF (WarnBeforeManualChange) THEN
                    SetLengthOf(Prefix, 0);
                    GetMessage(ModuleNumber + 4, Choices);             (* Please wait.  Returning tasks to manual order. *)
                    MessageBox(Choices, Prefix);
                    ReturnToManualOrder();
                    WarnBeforeManualChange := FALSE;
                    SortOrderManuallyAltered := FALSE;
                END;
                ExitFlag := TRUE;
            ELSIF (SortChoice = 5) THEN                                 (* Go *)
                SetLengthOf(Prefix, 0);
                Message(Prefix);
                GetMessage(ModuleNumber + 3, Choices);                  (* Please wait.  Sorting *)
                MessageBox(Choices, Prefix);
                IF (SortOrderManuallyAltered) THEN
                    RenumberTasks();
                    SortOrderManuallyAltered := FALSE;
                END;
                SortTasks();
                WarnBeforeManualChange := TRUE;
                ExitFlag := TRUE;
            ELSIF (SortChoice = 3) THEN
                SetLengthOf(Prefix,0);
                SetString(Choices,"3,4,5,6,7,8,9");
                IF (KeyChoice > MAXKEYS-2) THEN
                    KeyChoice := MAXKEYS-2;
                END;
                IF (Menu(Prefix, Choices, 0, MenuStart, MaxColumn, MenuEnd,
                         EmptyCodeSet,
                         FALSE,      (* 12-Dec-89 RSC MODAL *)  (* 3-Jan-90 EGK Non-modal *)
                         KeyChoice) <> CancelKey) THEN
                    IF (SetKey(KeyChoice+1)) THEN
                        SortChoice := 5;                                    (* Suggest "GO" *)
                        INC(KeyChoice);
                    END;
                END;
            ELSE
                IF (SetKey(SortChoice-1)) THEN
                    SortChoice := 5;                                    (* Suggest "GO" *)
                END;
            END;
    (*
            IF (RugTaken) THEN
                PutRug(0, 0, maxcol, maxrow, Rug);
            END;
    *)
        ELSE                                                           (* Menu cancelled *)
            ExitFlag := TRUE;
        END;
    UNTIL ExitFlag;

    DisposeTaskColumnsTree();                                     (* 20-Mar-89 LAA *)

END TLSortBody;


BEGIN                       (* TLSort *)

    OverlayID := ImAnInstallableOverlay(TLSortBody, AnOverlayProc(NIL));         (* 19-Jan-88 LAA *)
    TLSortBody();

END TLSort.


