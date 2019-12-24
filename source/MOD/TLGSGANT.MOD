MODULE TLGSGANT;

(*  =========================================================================
    Last Edit : June 10, 1991 3:21PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Graphics Gantt Report form.        

    MODIFICATION HISTORY:

        16-Dec-88 LAA   No longer use ATLGSLegentPlacement due to changes in
                        the title form.
        30-Jan-89 LAA   Set ExportersOK to FALSE if ESC is pressed from the 
                        form.
        21-Feb-89 LAA   Added lots of new fields to the form for SAMSO, and
                        labels on task bars, and date ranges.
        08-Mar-89 WKH   Added minimum character spacings for time units.
        13-Mar-89 WKH   Consolidated "inline" code in CheckForm into local
                        procedures because we were running into compiler
                        implementation restrictrions(procedure too large).
        15-Mar-89 WKH   Blank out Layout name if not found.
        16-Mar-89 WKH   Massive re-org of this form to reflect new design
        23-Mar-89 WKH   Calculate locally the start/end dates of the schedule
        27-Mar-89 WKH   Calculate and display size of Gantt bar region
        18-Apr-89 RSC   Move DEF to ILSASTAT.DEF; Remove Holder references.
        27-Apr-89 WKH   Start conversion for Lazlo.  Not yet completed due to
                        lack of necessary routines in Lazlo.  This is reflected
                        in the Kludge module.  When we do a compile with the
                        new LoadCommon.DEF, then we can nuke this code.
        10-May-89 WKH   Finally, the last changes to forms, hopefully, we have
                        optimized in terms of size as well!!!
        11-May-89 WKH   Added a pop-up color palette form
        13-May-89 WKH   Added support to edit scale in inches/cm
        15-May-89 WKH   Forgot to DIV the point size by 16.
                        Only calculate baseline info if baseline showing AND
                        baseline for a given task is set.
        16-May-89 WKH   Now that we show scale in inches/cm., changed the way
                        we calculate Gantt bar section size.
        22-May-89 WKH   Get rid of extraneous imports.
                        Also added validation of Column names
        24-May-89 WKH   Fixed problem with Layout names not being found.  Also, don't
                        allow form to come up if there is no visible schedule.  Also
                        consolidated layout checking (procedure ValidateLayoutAndAdjust).
        25-May-89 WKH   Highlight column fields when doing a picklist.
        29-May-89 LAA   Adjusted for the TitleBlock being stored in FlexStor.
        30-May-89 WKH   Init TimeScale field correctly.
                        Also changed edit rules of TimU & TimS fields.
                        And make sure that ColumnID always matches ColumnName.
        31-May-89 WKH   Don't allow column widths greater than 255.
                        Get inches/cm. info from device setup stuff.
        01-Jun-89 WKH   Get units info from TLGSConfigRecord instead of 
                        TLGSSetupRecord
        11-Jun-89 LAA   Disposed of the Palette string when the form is done.
        12-Jun-89 LAA   Added support for scrolling list of Palettes.
        14-Jun-89 LAA   Made the list of palettes wider to accomodate the
                        asterisk which marks standard palettes.
        26-Jun-89 LAA   Reorganized a bit to improve the code locality, and
                        added a check for the existance of Graphics 
                        configuration before allowing the form to proceed.
        27-Jun-89 LAA   Renamed RoundToNearestInt to RoundToNextHighestInt to
                        more accurately reflect the intended function, and
                        made RoundToNearestTenth actually round rather than
                        truncating.
        30-Jun-89 LAA   Changed MeasureToCharacter to not round up to the 
                        next highest integer, in order to solve a problem with
                        the Gantt form timescale field creeping up from 1.0
                        to 1.1 on the next iteration of the form.
        06-Jul-89 WKH   Adjust width used for formatting when doing a 
                        GetColumnInfo.
        10-Jul-89 WKH   Gantt section for Quarters was being calculated
                        incorrectly.  Also, only check if selected time scale
                        is too small on CheckFormExit.  And change attribute
                        CursorOn to CursorResting for Highlight field calls.
        25-Jul-89 WKH   Zero out column width field if column name is blank.
                        Also change default time unit to Weeks.
        27-Jul-89 KKC - Pop up calculator if F2 key is pressed in a numeric
                        field.
        31-Jul-89 WKH   Used WorkHoursToRealTime instead of DownScale in
                        calculation of Gantt bar size.  We must be precise.
        09-Aug-89 KKC   Add copyright message.
        22-Aug-89 WKH   Hide Indention Level if ExtraSpacing isn't selected.
        23-Aug-89 WKH   Finally, don't let the form proceed if there isn't
                            A. A configured output device
                            B. A values file in the current directory
                            C. Or if the name of said values file doesn't 
                               match the name of the one listed in the
                               configuration record.
        25-Aug-89 WKH   As always, rules are made to be broken.  We now want
                        to allow lables even if border repeat is selected.
                        So be it, I have removed the code, forever.
                        Additionally, we don't allow editing of the label
                        column and widths unless there is a name there.
        06-Sep-89 WKH   Oops. Forgot to set the new ColID up.
                        Also, call SelectLayoutAt with a FALSE for the
                        warning parm.
        12-Sep-89 WKH   Make palette and layout list bigger for compressed
                        video and make SelectedScale msg not sticky.
        19-Sep-89 RSC   Give StoEndDate a start date as a default.
        20-Sep-89 WKH   Procedureize some code to shrink some stuff
        21-Sep-89 WKH   Changed default time measure to be 1 inch instead
                        of min measure for that time unit (as per DAB).
        09-Oct-89 WKH   Don't allow Always Show Actuals field(Actu) if
                        Overlap Bars are selected(Bars).
        21-Nov-89 RSC   Bug # 1747.  Improve estimated graph size.
        29-Nov-89 RSC   Bug # 1818.  Force reinterpretation of dates, so
                        "ASOF" or "TODAY + 4" is calculated right.

         1-Dec-89 RSC   Revisit of Bug # 1818.  Do interp as part of
                        FormExit.  Fixes NEW bug #1857.
        19-Dec-89 WKH   As per LAA's request, use FormatAsAmount instead of
                        RealToLString to convert a real to an LString.  Now
                        we are internationally "aware."
        29-Dec-89 WKH   Tag the TLGSPage record to indicate that we are
                        about to do a Gantt plot.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.

        23-Jan-91 RSC   Moved FindLayoutByName here from LoadCommon, to save
                        all the baggage that LoadCommon pulls in.
        10-Jun-91 PFG   Call GetTaskColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a task 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
        14-Feb-92 TGS   User can change radix character, so we can't hard-
                        code fractional real number strings (like "3.00") in
                        Phrases anymore. This is the only place we were doing
                        so; the solution taken here was to read in a number
                        which is taken to represent 1/100ths, and to divide
                        by 100.0 after reading it in to get the same number
                        we were deriving before.  That way, it's still
                        possible to specify character widths to precision of 
                        1/100ths.  It would have "worked" to just change
                        "3.00" to "3" in Phrases, thereby eliminating the 
                        (variable) radix char, but then we'd lose out on
                        precision.
    =========================================================================
*)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ADateBlock, ATaskFlag,
    (* VARS *)                  TaskTree;

FROM CalShift               IMPORT
    (* VAR *)                   TimeSheet;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR *)                   LayoutTree,
    (* PROC *)                  SelectLayoutAt, CurrentLayout;

FROM Codes                  IMPORT 
                                ACode, EmptyCodeSet;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp,
                                Message;

FROM Duration               IMPORT
    (* PROC *)                  FindDuration;

FROM FloatingUtilities      IMPORT
    (* PROC *)                  Frac, Int;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
                                ACursorAttribute,
    (* PROC *)                  DoForm, SetFieldProtection, NullCheckProc,
                                ShowValue, HighlightField, SetFormChange,
                                SetFieldHidden;

FROM Gantt                  IMPORT
                                ASlackStyle;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSGridStyle, ATLGSCorner, ATLGSSymbology,
                                ATLGSGanttRecord, AGraphStyle, ATLGSPageRecord,
                                ATLGSGanttRecordPtr, ATLGSPageRecordPtr,
                                ATextLine, ATLGSScale, 
                                ATLGSTitlePlacement, ATLGSChartType,
                                ATLGSPosition, ATLGSLabelRecord,
                                AUserUnit, ATLGSConfigRecordPtr,
    (* VAR *)                   PaletteTree,
    (* PROC *)                  TLGSPageRecord, TLGSGanttRecord,
                                TLGSConfigRecord, TLGSConfigRecordExists;

FROM IlsaSupport            IMPORT
    (* PROC *)                  TLGSConfigIsCool;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, avidmode;

FROM Keys                   IMPORT 
                                CancelKey, ExitKey, EditKey, DoIt;

FROM Layout                 IMPORT 
                                GanttWEnd, GanttWStart;

FROM LStrings               IMPORT 
    (* PROC *)                  Fill, SetString, TrimRear, ConcatS, 
                                LengthOf, SetLengthOf, Copy, Compare,
                                ConcatLS, CtoS, LJust, TrimFront,
                                StringsEqual;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* VAR  *)                  PackageOK;

FROM ParseReal              IMPORT
    (* PROC *)                  AmountToReal;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU, StoEndTimeU;

FROM Palettes               IMPORT
    (* PROC *)                  FindPaletteByName, SelectPalette;

FROM RealFormat             IMPORT
    (* VAR  *)                  DefaultAmountFormat,
    (* PROC *)                  FormatAsAmount;

FROM Schedule               IMPORT
                                ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE,
    (* PROC *)                  HeapAvailable;

FROM SYSTEM                 IMPORT 
                                ADR, TSIZE, ADDRESS;

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration, MinDate, MaxDate,
    (* TYPE *)                  ADurationUnit, ADate, ADuration;

FROM Timeu                  IMPORT
    (* VAR  *)                  FSMUPH;     (* 21-Nov-89 RSC *)

FROM TLGSTitle              IMPORT
    (* PROC *)                  EditPageDescrip;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATree,
    (* PROC *)                  CreateTree;

FROM TypoGraph              IMPORT
    (* TYPE *)                  ATypoAttribute, ASetOfTypoAttributes, 
                                ATypoPlacement, ATypoLineSpec, 
                                ATypoBorderSpec, ATypoSpec;

FROM WorkHours              IMPORT
                                WorkHoursToRealTime;

CONST
    ModuleNumber            = 25100;

    (* Define meaningful names for indices into FormValue array *)
    Layt                    = 0;   (* Layout field *)
    Palt                    = 1;   (* Palette field *)
    PgDs                    = 2;   (* Page description field *)
    Brdr                    = 3;   (* Repeat on each page *)
    Crnr                    = 4;   (* Corners *)
    GStl                    = 5;   (* Grid Style *)
    HzGd                    = 6;   (* Horizontal Grid field *)
    VtGd                    = 7;   (* Vertical Grid field *)
    ExSp                    = 8;   (* Extra Spacing Between Tasks field *)
    InLv                    = 9;   (* Indentation Level field *)      
    Bars                    = 10;  (* Bar Symbology *)
    Actu                    = 11;  (* Always show actuals field *)
    TimS                    = 12;  (* Time Scale field *)
    InCm                    = 13;  (* inches per / cm. per *)
    TimU                    = 14;  (* Time Units field *)
    Gant                    = 15;  (* Estimated Task Bar Area field in./cm *)
    Strt                    = 16;  (* Starting *)
    Endg                    = 17;  (* Ending *)
    L1CO                    = 18;  (* Label 1 Column Name *)
    L1WD                    = 19;  (* Label 1 Column Width *)
    L1PS                    = 20;  (* Label 1 Column Position *)
    L2CO                    = 21;  (* Label 2 Column Name *)
    L2WD                    = 22;  (* Label 2 Column Width *)
    L2PS                    = 23;  (* Label 2 Column Position *)
    L3CO                    = 24;  (* Label 3 Column Name *)
    L3WD                    = 25;  (* Label 3 Column Width *)
    L3PS                    = 26;  (* Label 3 Column Position *)
    L4CO                    = 27;  (* Label 4 Column Name *)
    L4WD                    = 28;  (* Label 4 Column Width *)
    L4PS                    = 29;  (* Label 4 Column Position *)

    (* Offsets into phrases file for phrases used by this module *)
    TimeUnitsMsg            = 0;
    NoHeapMsg               = 1;
    BadLayoutMsg            = 2;
    BadScaleMsg             = 3;
    BadColumnMsg            = 4;
    NoTasksMsg              = 5;
    BadWidthMsg             = 6;
    MinCharWidthsMsg        = 9;
    TimeScaleTooSmallMsg    = 10;
    ScaleEqualsMsg          = 11;
    InchesPerMsg            = 12;
    GanttSectionIsMsg       = 13;
    InchesMsg               = 14;
    CmPerMsg                = 15;
    CmMsg                   = 16;
    NoDeviceSetup           = 17;

    (* Coordinates for layout selection box *)
    LayoutBoxULX            = 45;
    LayoutBoxULY            = 4;
    LayoutBoxLRX            = 70;

    (* Coordinates for Palette selection box *)
    PaletteUlx              = 45;
    PaletteUly              = 5;
    PaletteLrx              = 72;

    (* Index into MinCharWidths string *)
    HoursIndex              = 1;
    DaysIndex               = 2;
    WeeksIndex              = 3;
    MonthsIndex             = 4;
    QuartersIndex           = 5;
    YearsIndex              = 6;

    VerticalSizeRatio       = 0.8;

    PointsPerInch           = 72.0;
    
    PointSizeMultiplier     = 16;

    MonthsPerQuarter        = 3.0;   (* 10-Jul-89 WKH *)

    DefaultMeasure          = 1.0;

VAR
    ReportSettings          : ATLGSGanttRecordPtr;
    TempFontMember          : CARDINAL;

    HoursMinChars           : REAL;
    DaysMinChars            : REAL;
    WeeksMinChars           : REAL;
    MonthsMinChars          : REAL;
    QuartersMinChars        : REAL;
    YearsMinChars           : REAL;
    ConversionFactor        : REAL;   (* 5/31/89 WKH *)
    BaseLineShowing         : BOOLEAN;
    LocalUserUnit           : AUserUnit;
    LayoutBoxLRY            : CARDINAL;
    PaletteLry              : CARDINAL;


PROCEDURE ErrorMessage(    Phrase           : CARDINAL);

VAR
    ErrorString             : ARRAY [0..255] OF CHAR;

BEGIN                       (* ErrorMessage *)

    GetMessage(Phrase, ErrorString);
    Error(ErrorString);

END ErrorMessage;



(* 23-Jan-91 RSC from LoadCommon
*)
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






PROCEDURE ValidateLayoutAndAdjust(VAR ProposedLayout : ARRAY OF CHAR;
                                  VAR LayoutString   : ARRAY OF CHAR) : BOOLEAN;

VAR
    ChartFormatPtr          : AChartFormatPtr;
    TreeNode                : ATreeNode;
    DidWeFindIt             : BOOLEAN;

BEGIN
    DidWeFindIt    := TRUE; (* optimism *)
    
    ChartFormatPtr := CurrentLayout(); (* pessimism *)

    TrimRear(ProposedLayout);
    IF (LengthOf(ProposedLayout) > 0) THEN
        TreeNode := FindLayoutByName(ProposedLayout);
        IF (TreeNode <> NIL) THEN
            ChartFormatPtr := TreeNode^.Methods^.GetDataObject(TreeNode);
            Copy(ProposedLayout, LayoutString);
        ELSE
            DidWeFindIt := FALSE;
        END;
    END;
    BaseLineShowing := ChartFormatPtr^.AVPShowing;

    RETURN(DidWeFindIt);
END ValidateLayoutAndAdjust;




PROCEDURE RoundToNextHighestInt(RealNum : REAL) : REAL;
BEGIN
    IF (Frac(RealNum) > 0.0) THEN
        RealNum := Int(RealNum) + 1.0;
    END;

    RETURN(RealNum);
END RoundToNextHighestInt;




PROCEDURE RoundToNearestTenth(RealNum : REAL) : REAL; (* fix *)

CONST
    Ten                     = 10.0;
    
BEGIN
    
    RETURN (Int(RealNum) + (Int((Frac(RealNum) * Ten) + 0.5) / Ten));
    
END RoundToNearestTenth;




    (* NOTE!!!  The following two routines, MeasureToCharacters and
                CharactersToMeasure are not mathematical inverses of each
                other.  Rounding occurs in each.  So....
                MeasureToCharacters(CharactersToMeasure(10.0)) <> 10.0
    *)
PROCEDURE MeasureToCharacters(Measure : REAL;
                              Points  : CARDINAL) : REAL;
BEGIN
    (* Normalize to inches *)
    Measure := Measure / ConversionFactor;

    (* Now lets figure out how many points *)
    Measure := Measure * PointsPerInch;

    (* OK, finally, how many characters *)
    Measure := Measure / (FLOAT(Points) * VerticalSizeRatio);

    (* RETURN(RoundToNextHighestInt(Measure)); *)                 (* 30-Jun-89 LAA *)

    RETURN Measure;

END MeasureToCharacters;



PROCEDURE CharactersToMeasure(Characters : REAL;
                              Points     : CARDINAL) : REAL;

BEGIN
    (* Calculate what this means in points *)
    Characters := Characters * FLOAT(Points) * VerticalSizeRatio;

    (* Now let's figure out the measure in inches *)
    Characters := Characters / PointsPerInch;

    (* Now let's convert to centimeters, if necessary *)
    Characters := Characters * ConversionFactor;

    RETURN(RoundToNearestTenth(Characters));
END CharactersToMeasure;






PROCEDURE GetMinMeasurePerTimeUnit(    TimeUnit      : CARDINAL) : REAL;

VAR
    ReturnVal               : REAL;

BEGIN
    CASE VAL(ATLGSScale, TimeUnit) OF
        
        SHours    : ReturnVal := HoursMinChars;

    |   SDays     : ReturnVal := DaysMinChars;

    |   SWeeks    : ReturnVal := WeeksMinChars;

    |   SMonths   : ReturnVal := MonthsMinChars;

    |   SQuarters : ReturnVal := QuartersMinChars;

    |   SYears    : ReturnVal := YearsMinChars;

    ELSE
        FatalError();
    END;
    
    RETURN (CharactersToMeasure(ReturnVal, 
                                ReportSettings^.DefaultSpec.PointSize DIV
                                PointSizeMultiplier));
END GetMinMeasurePerTimeUnit;



PROCEDURE QueryBorderFlag() : BOOLEAN;

VAR
    TLGSPageInfo            : ATLGSPageRecordPtr;

BEGIN                       (* QueryBorderFlag *)

    TLGSPageInfo := TLGSPageRecord();

    RETURN TLGSPageInfo^.Borders;

END QueryBorderFlag;



PROCEDURE SetBorderFlag(    BorderFlag      : BOOLEAN);

VAR
    TLGSPageInfo            : ATLGSPageRecordPtr;

BEGIN                       (* SetBorderFlag *)

    TLGSPageInfo := TLGSPageRecord();

    TLGSPageInfo^.Borders := BorderFlag;

END SetBorderFlag;



PROCEDURE FindColumnNameByNumber(    ColumnId   : CARDINAL;
                                 VAR Name       : ARRAY OF CHAR);


BEGIN                       (* FindColumnNameByNumber *)

    IF (ColumnId = 0) THEN
        SetLengthOf(Name, 0);
    ELSE
        GetTaskColumnName(ColumnId, Name);
    END;

END FindColumnNameByNumber;




PROCEDURE CheckForm (    Form        : AForm;
                         FieldNo     : AFieldNo;
                     VAR FormValue   : ARRAY OF AFieldValue;
                         CheckReason : ACheckReason;
                     VAR Code        : CARDINAL ):BOOLEAN;

VAR
    i                       : CARDINAL;
    CodeIn                  : CARDINAL;
    ColID                   : CARDINAL;
    TempField               : AFieldValue;
    Layout                  : ATreeNode;
    Node                    : ATreeNode;
    T                       : ATaskPtr;
    KeyStruck               : ACode;
    LayoutGoodies           : AChartFormatPtr;
    DataRecord              : AColumnDataRecord;
    ErrorString             : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..10] OF CHAR;
    Found                   : BOOLEAN;
    LooksGood               : BOOLEAN;
    OldBaseLine             : BOOLEAN;
    
    PROCEDURE ValidateTimeScaleField();
    
    VAR
        AOk                 : BOOLEAN;

    BEGIN
        AOk := TRUE;

        IF (FormValue[TimS].RealValue < FormValue[TimU].RealValue) THEN
            AOk := FALSE;
        END;

        IF (NOT AOk) THEN
            GetMessage(ModuleNumber + BadScaleMsg, ErrorString);

            IF (CheckReason = CheckFormExit) THEN
                Error(ErrorString);
                Code := CARDINAL({15}) + TimS; (* Goto offending field *)
                LooksGood := FALSE;
            ELSIF (CheckReason = CheckFieldExit) OR 
                (CheckReason = CheckFieldChange) THEN
(*                IF (FieldNo = TimS) THEN
                    LooksGood := FALSE;
                END;*)
                Message(ErrorString);
                Burp();
            END;
        ELSE
            SetLengthOf(ErrorString, 0);  (* 12-Sep-89 WKH *)
            Message(ErrorString);
        END;

    END ValidateTimeScaleField;


    PROCEDURE ValidateColumnWidth();

    VAR
        AOk                 : BOOLEAN;

    BEGIN
        AOk := TRUE;
        
        IF (FormValue[FieldNo].CardValue > 255) THEN
            AOk := FALSE;
        END;

        IF (NOT AOk) THEN
            GetMessage(ModuleNumber + BadWidthMsg, ErrorString);
            LooksGood := FALSE;

            IF (CheckReason = CheckFormExit) THEN
                Error(ErrorString);
                Code := CARDINAL({15}) + FieldNo;
            ELSIF (CheckReason = CheckFieldExit) OR
                  (CheckReason = CheckFieldChange) THEN
                Message(ErrorString);
                Burp();
            END;
        END;

    END ValidateColumnWidth;

    PROCEDURE ShowGanttSize();

    VAR
        ScheduleLength          : ADuration;
        LocalStart              : ADate;
        LocalEnd                : ADate;
        TimeUnits               : ATLGSScale;
        TimeUnitSelector        : ADurationUnit;
        GanttSize               : REAL;
        s1                      : ARRAY [0..255] OF CHAR;
        MessageToUse            : CARDINAL;

    BEGIN
        TimeUnits  := VAL(ATLGSScale, FormValue[TimU].CardValue);
        LocalStart := FormValue[Strt].CardValue;
        IF (LocalStart = MinDate) THEN
            LocalStart := LocalScheduleStartDate;
        END;

        LocalEnd := FormValue[Endg].CardValue;
        IF (LocalEnd = MinDate) THEN
            LocalEnd := LocalScheduleEndDate;
        END;

        ScheduleLength := NoDuration;
        IF (LocalEnd > LocalStart) THEN
            ScheduleLength := FindDuration( LocalStart, LocalEnd, TimeSheet );
        END;

        CASE TimeUnits OF
            SHours    : TimeUnitSelector := Hours;
        |   SDays     : TimeUnitSelector := Days;
        |   SWeeks    : TimeUnitSelector := Weeks;
        |   SMonths   : TimeUnitSelector := Months;
        |   SQuarters : TimeUnitSelector := Months;
        |   SYears    : TimeUnitSelector := Years;
        END;

        (* 21-Nov-89 RSC: *)
        GanttSize := (FLOAT(ScheduleLength) / FSMUPH);
        GanttSize := GanttSize * WorkHoursToRealTime(1.0, TimeUnitSelector);  (* 31-Jul-89 WKH *)
        IF (TimeUnits = SQuarters) THEN
            GanttSize := GanttSize / MonthsPerQuarter;
        END;

        GanttSize := GanttSize * FormValue[TimS].RealValue;

        GetMessage(ModuleNumber + GanttSectionIsMsg, FormValue[Gant].CharValue^);

        ConcatS(FormValue[Gant].CharValue^, " ");

        FormatAsAmount(GanttSize, DefaultAmountFormat, s1, 20, 0, 3, FALSE);    (* 19-Dec-89 WKH  *)

        TrimRear(s1);
        ConcatLS(FormValue[Gant].CharValue^, s1);

        ConcatS(FormValue[Gant].CharValue^, " ");

        CASE LocalUserUnit OF
            Inches      : MessageToUse := ModuleNumber + InchesMsg;
        |   Centimeters : MessageToUse := ModuleNumber + CmMsg;
        ELSE
            FatalError();
        END;

        ConcatMessage(FormValue[Gant].CharValue^, MessageToUse);

        ShowValue(Form, Gant, FormValue);
    END ShowGanttSize;


    PROCEDURE ShowWidthAndPos(LabelNum : CARDINAL);
    
    VAR
        NoShowLabelDescriptors  : BOOLEAN;
        WidthNum                : CARDINAL;
        PosNum                  : CARDINAL;

        PROCEDURE SetFields(Width   : CARDINAL;
                            Pos     : CARDINAL;
                            WeShall : BOOLEAN);
        BEGIN
            SetFieldProtection(Form, Width, FormValue, WeShall);
            SetFieldHidden(Form, Width, FormValue, WeShall);
            SetFieldProtection(Form, Pos, FormValue, WeShall);
            SetFieldHidden(Form, Pos, FormValue, WeShall);
        END SetFields;

    BEGIN
        TrimRear(FormValue[FieldNo].CharValue^);
        NoShowLabelDescriptors := LengthOf(FormValue[FieldNo].CharValue^) = 0;

        CASE LabelNum OF
            L1CO :
                WidthNum := L1WD;
                PosNum   := L1PS;

        |   L2CO :
                WidthNum := L2WD;
                PosNum   := L2PS;

        |   L3CO :
                WidthNum := L3WD;
                PosNum   := L3PS;

        |   L4CO :
                WidthNum := L4WD;
                PosNum   := L4PS;
        ELSE
        END;

        SetFields(WidthNum, PosNum, NoShowLabelDescriptors);
    END ShowWidthAndPos;


    (* 1-Dec-89 RSC Made a subprocedure. *)
    PROCEDURE CheckDates();
    BEGIN
        WITH FormValue[FieldNo] DO
            LJust(CharValue^);
            TrimRear(CharValue^);
            ShowValue(Form,FieldNo,FormValue);
            IF (LengthOf(CharValue^) = 0) THEN
                LooksGood := TRUE;
                CardValue := 0;
            ELSIF (FieldNo = Strt) THEN
                LooksGood := StoTimeU(CharValue^,CardValue);
            ELSE
                CardValue := FormValue[Strt].CardValue; (* RSC 19-Sep-89 *)
                LooksGood := StoEndTimeU(CharValue^,CardValue);
            END;
        END;
        IF (NOT LooksGood) THEN
            Burp();
        ELSE  (* 3/27/89 WKH *)
            ShowGanttSize();
        END;
    END CheckDates;


BEGIN
    CodeIn    := Code;
    Code      := 0;
    LooksGood := TRUE;

    CASE CheckReason OF
        CheckFormEntry   :
            CASE FieldNo OF
                ExSp :
                    SetFieldProtection(Form, InLv, FormValue, 
                                       FormValue[FieldNo].CardValue = 0);
                    SetFieldHidden(Form, InLv, FormValue,
                                   FormValue[FieldNo].CardValue = 0);  (* 22-Aug-89 WKH *)

            |   InCm :
                    SetFieldProtection(Form, FieldNo, FormValue, TRUE);

            |   Gant :
                    SetFieldProtection(Form, FieldNo, FormValue, TRUE);
                    ShowGanttSize();

            |   L1CO, L2CO, L3CO, L4CO :
                    ShowWidthAndPos(FieldNo);

            |   Bars :          (* 9-Oct-89 WKH  *)
                    SetFieldProtection(Form, Actu, FormValue,
                                       FormValue[Bars].CardValue = 0);
                    SetFieldHidden(Form, Actu, FormValue,
                                   FormValue[Bars].CardValue = 0);

            ELSE
            END;

    |   CheckFormExit    :
            CASE FieldNo OF
                Layt :
                    IF (NOT ValidateLayoutAndAdjust(FormValue[Layt].CharValue^,
                                                    FormValue[Layt].CharValue^)) THEN
                        ErrorMessage(ModuleNumber + BadLayoutMsg);
                        LooksGood := FALSE;
                        Code := CARDINAL({15}) + FieldNo; (* Goto offending field *)
                    END;

            |   TimS :
                    ValidateTimeScaleField();

            |   L1WD, L2WD, L3WD, L4WD :
                    ValidateColumnWidth();
                        
            |   Strt, Endg :        (* 1-Dec-89 RSC *)

                    CheckDates();

                    IF (FieldNo = Endg) THEN
                        WITH FormValue[Endg] DO
                            IF ((CardValue > 0) 
                               AND (CardValue <= FormValue[Strt].CardValue)) THEN
                                LooksGood := FALSE;
                                Code := CARDINAL({15}) + FieldNo; (* Goto offending field *)
                            END;
                        END;
                    END;
            ELSE
            END;

    |   CheckFieldEntry  :
            (* Do nothing *)

    |   CheckFieldChange :
            CASE FieldNo OF
                TimU :
                    FormValue[TimU].RealValue := GetMinMeasurePerTimeUnit(FormValue[TimU].CardValue);
                    ShowGanttSize();

            |   ExSp :
                    SetFieldProtection(Form, InLv, FormValue, 
                                       FormValue[FieldNo].CardValue = 0);
                    SetFieldHidden(Form, InLv, FormValue,
                                   FormValue[FieldNo].CardValue = 0);  (* 22-Aug-89 WKH *)

            |   Layt :
                    OldBaseLine := BaseLineShowing;
                    IF (NOT ValidateLayoutAndAdjust(FormValue[Layt].CharValue^,
                                                    FormValue[Layt].CharValue^)) THEN
                        GetMessage(ModuleNumber + BadLayoutMsg, ErrorString);
                        Message(ErrorString);
                        Burp();
                        LooksGood := FALSE;
                    ELSE
                        IF (BaseLineShowing <> OldBaseLine) THEN
                            IF (FormValue[Strt].CardValue = 0) AND
                               (FormValue[Endg].CardValue = 0) THEN
                                CalcStartAndEndDates();
                            END;
                            ShowGanttSize();
                        END;
                    END;

            |   TimS :
                    ShowGanttSize();

            |   L1WD, L2WD, L3WD, L4WD :
                    ValidateColumnWidth();
                        
            |   L1CO, L2CO, L3CO, L4CO :
                    TrimRear(FormValue[FieldNo].CharValue^);
                    IF (LengthOf(FormValue[FieldNo].CharValue^) > 0) THEN
                        Found := SearchForTaskColumn(FormValue[FieldNo].CharValue^, 
                                                                   ColID);

                        CASE FieldNo OF
                            L1CO : i := L1WD;
                        |   L2CO : i := L2WD;
                        |   L3CO : i := L3WD;
                        |   L4CO : i := L4WD;
                        ELSE
                            FatalError();
                        END;

                        IF (NOT Found) THEN
                            GetMessage(ModuleNumber + BadColumnMsg, ErrorString);
                            Message(ErrorString);
                            Burp();
                            LooksGood := FALSE;
                        ELSIF (ColID <> FormValue[i].CardValue) THEN  (* 5/30/89 WKH *)
                            FormValue[FieldNo].CardValue := ColID;    (* 6-Sep-89 WKH *)
                            (* Get Default Column Width *)
                            T := NIL;
                            GetColumnInfo(NIL, 
                                            T, 
                                            ColID, 
                                            ColumnWidth, 
                                            3, 
                                            DataRecord);
                            FormValue[i].CardValue := DataRecord.CardinalValue;
                            ShowValue(Form, i, FormValue);
                        END;
                    ELSE
                        FormValue[FieldNo].CardValue := 0;
                    END;
                    ShowWidthAndPos(FieldNo);

            |   Bars :          (* 9-Oct-89 WKH  *)
                    SetFieldProtection(Form, Actu, FormValue,
                                       FormValue[Bars].CardValue = 0);
                    SetFieldHidden(Form, Actu, FormValue,
                                   FormValue[Bars].CardValue = 0);

            ELSE
            END;        

    |   CheckFieldExit   :
            CASE FieldNo OF
                Palt :                                            (* 12-Jun-89 LAA *)
                    TrimRear(FormValue[FieldNo].CharValue^);
                    IF (LengthOf(FormValue[FieldNo].CharValue^) > 0) THEN
                        LooksGood := (FindPaletteByName(TLGSGanttChart,
                                                FormValue[FieldNo].CharValue^)
                                                <> ATreeNode(NIL));
                        IF (NOT LooksGood) THEN
                            Burp();
                        END;
                    END;

            |   TimU, TimS :
                    ValidateTimeScaleField();
                    IF (LooksGood) THEN
                        ShowGanttSize();
                    END;

            |   L1WD, L2WD, L3WD, L4WD :
                    ValidateColumnWidth();
                        
            |   L1CO, L2CO, L3CO, L4CO :
                    TrimRear(FormValue[FieldNo].CharValue^);
                    IF (LengthOf(FormValue[FieldNo].CharValue^) = 0) THEN
                        FormValue[FieldNo].CardValue := 0;

                        CASE FieldNo OF        (* 25-Jul-89 WKH *)
                            L1CO : i := L1WD;
                        |   L2CO : i := L2WD;
                        |   L3CO : i := L3WD;
                        |   L4CO : i := L4WD;
                        ELSE
                            FatalError();
                        END;

                        FormValue[i].CardValue := 0;
                        ShowValue(Form, i, FormValue);
                    END;
                    ShowWidthAndPos(FieldNo);

            |   Strt, Endg :

                    CheckDates();
            ELSE
            END;

    |   CheckFieldKey    :
            IF (CodeIn = EditKey) THEN
                CASE FieldNo OF
                    Palt :                                        (* 12-Jun-89 LAA *)
                        HighlightField(Form, FormValue, FieldNo, CursorResting);
                        IF (SelectPalette(TLGSGanttChart, PaletteUlx, 
                                          PaletteUly, PaletteLrx, PaletteLry,
                                          FormValue[FieldNo].CharValue^)) THEN
                            ShowValue(Form, FieldNo, FormValue);
                        END;
                        HighlightField(Form, FormValue, FieldNo, CursorOff);

                |   Layt :
                        OldBaseLine := BaseLineShowing;
                        TrimRear(FormValue[FieldNo].CharValue^);
                        Layout := FindLayoutByName(FormValue[FieldNo].CharValue^);
                        HighlightField(Form, FormValue, FieldNo, CursorResting);
                        KeyStruck := SelectLayoutAt(Layout, 
                                                    LayoutBoxULX, 
                                                    LayoutBoxULY,
                                                    LayoutBoxLRX, 
                                                    LayoutBoxLRY,
                                                    FALSE);                
                        IF (KeyStruck <> CancelKey) THEN
                            IF (Layout <> NIL) THEN
                                LayoutGoodies := Layout^.Methods^.GetDataObject(Layout);
                                Found := ValidateLayoutAndAdjust(LayoutGoodies^.Name,
                                             FormValue[Layt].CharValue^);
                            ELSE
                                SetLengthOf(FormValue[FieldNo].CharValue^, 0);
                            END;
                        ELSE
                            IF (NOT ValidateLayoutAndAdjust(FormValue[Layt].CharValue^,
                                                            FormValue[Layt].CharValue^)) THEN
                                SetLengthOf(FormValue[FieldNo].CharValue^, 0);
                            END;
                        END;
                        IF (BaseLineShowing <> OldBaseLine) THEN
                            IF (FormValue[Strt].CardValue = 0) AND
                               (FormValue[Endg].CardValue = 0) THEN
                                CalcStartAndEndDates();
                            END;
                            ShowGanttSize();
                        END;
                        ShowValue(Form, FieldNo, FormValue);
                        HighlightField(Form, FormValue, FieldNo, CursorOff);

                |   PgDs :
                        EditPageDescrip(Form, TLGSGanttChart);

                |   L1CO, L2CO, L3CO, L4CO :
                        HighlightField(Form, FormValue, FieldNo, CursorResting);  (* 10-Jul-89 WKH *)
                        Found := SearchForTaskColumn(FormValue[FieldNo].CharValue^, 
                                                     ColID);
                        IF (PickTaskColumn(maxcol-31, 
                                           5, 
                                           maxcol, 
                                           maxrow-6, 
                                           ColID, 
                                           FormValue[FieldNo].CharValue^)) THEN
                            IF (FormValue[FieldNo].CardValue <> ColID) THEN
                                SetFormChange(Form);
                                FormValue[FieldNo].CardValue := ColID;

                                (* Get Default Column Width *)
                                T := NIL;
                                GetColumnInfo(NIL, 
                                              T, 
                                              ColID, 
                                              ColumnWidth, 
                                              3, 
                                              DataRecord);
                                CASE FieldNo OF
                                    L1CO : i := L1WD;
                                |   L2CO : i := L2WD;
                                |   L3CO : i := L3WD;
                                |   L4CO : i := L4WD;
                                ELSE
                                    FatalError();
                                END;
                                FormValue[i].CardValue := DataRecord.CardinalValue;
                                ShowValue(Form, i, FormValue);
                            END;


                        END;

                        (* In case column names were edited, update all column
                            names on form.  Need to do this even if PickTaskColumn
                            returns FALSE, since the user may have changed some 
                            column other than the highlighted one.  *)

                        FOR i := L1CO TO L4CO BY 3 DO
                            IF FormValue[i].CardValue <> 0 THEN
                                GetTaskColumnName(  FormValue[i].CardValue,
                                                    FormValue[i].CharValue^);
                            ELSE
                                Fill(FormValue[i].CharValue^, " ", 24);
                            END;
                            ShowValue(Form, i, FormValue);
                        END;

                        HighlightField(Form, FormValue, FieldNo, CursorOff);
                        ShowWidthAndPos(FieldNo);
                ELSE
                    Code := 04000H + CodeIn;
                END;
            ELSE
                Burp();
            END;
    ELSE
        FatalError();
    END;

    RETURN LooksGood;

END CheckForm;


(*  Optimization is turned off for the ExecForm module bedcause the real
    value in the FormValue array for the Time Scale field was not being
    assigned correctly (FormValue[1]).  Further inspection showed that
    optimization was the culprit.  Following is a list of attempted
    switch settings and their results:
        /r+/t+/o+ - works
        /r-/t-/o+ - doesn't work
        /r-/t-/o- - works

    The specific line of code is:

        FormValue[TimS].RealValue := TimeScale;

    NOTE: This problem occured with Logitech V3.03
*)

(*$O-*)
PROCEDURE ExecForm() : ACode;

CONST
    Asterik                 = "*";

VAR
    Code                    : ACode;
    i                       : CARDINAL;
    FormValue               : ARRAY [0..L4PS] OF AFieldValue;
    TitleSize               : CARDINAL;
    ConfigInfo              : ATLGSConfigRecordPtr;
    MessageToUse            : CARDINAL;
    Found                   : BOOLEAN;
    TLGSPageInfo            : ATLGSPageRecordPtr;

    PROCEDURE CalcMinCharWidths();

    VAR
        (* Minimum character spacings for time units *) (* 3/8/89 WKH *)
        MinCharParseStr     : ARRAY [0..255] OF CHAR;
        s                   : ARRAY [0..11] OF CHAR;

    BEGIN                   (* CalcMinCharWidths *)
        GetMessage(ModuleNumber + MinCharWidthsMsg, MinCharParseStr);

        WordNumber(MinCharParseStr, HoursIndex, s);
        AmountToReal(s, HoursMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        HoursMinChars   := HoursMinChars/100.0;     (* 14-Feb-92 TGS *)

        WordNumber(MinCharParseStr, DaysIndex, s);
        AmountToReal(s, DaysMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        DaysMinChars    := DaysMinChars/100.0;      (* 14-Feb-92 TGS *)

        WordNumber(MinCharParseStr, WeeksIndex, s);
        AmountToReal(s, WeeksMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        WeeksMinChars   := WeeksMinChars/100.0;     (* 14-Feb-92 TGS *)

        WordNumber(MinCharParseStr, MonthsIndex, s);
        AmountToReal(s, MonthsMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        MonthsMinChars  := MonthsMinChars/100.0;    (* 14-Feb-92 TGS *)

        WordNumber(MinCharParseStr, QuartersIndex, s);
        AmountToReal(s, QuartersMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        QuartersMinChars:= QuartersMinChars/100.0;  (* 14-Feb-92 TGS *)

        WordNumber(MinCharParseStr, YearsIndex, s);
        AmountToReal(s, YearsMinChars, Found);
        IF (NOT Found) THEN FatalError(); END;
        YearsMinChars   := YearsMinChars/100.0;     (* 14-Feb-92 TGS *)

    END CalcMinCharWidths;


    PROCEDURE InitLabelField(VAR Label       : ATLGSLabelRecord; 
                                 NameIdx     : CARDINAL;
                                 WidthIdx    : CARDINAL;
                                 PositionIdx : CARDINAL);

    BEGIN
        WITH Label DO
            NEW(FormValue[NameIdx].CharValue);
            SetLengthOf(FormValue[NameIdx].CharValue^, 0);
            FormValue[NameIdx].CardValue := ColumnID;
            FindColumnNameByNumber(ColumnID, FormValue[NameIdx].CharValue^);

            FormValue[WidthIdx   ].CardValue := Width;
            FormValue[PositionIdx].CardValue := ORD(Position);
        END;
    END InitLabelField;


    PROCEDURE PutBackLabelInfo(    NameIdx     : CARDINAL;
                                   WidthIdx    : CARDINAL;
                                   PositionIdx : CARDINAL;
                               VAR Label       : ATLGSLabelRecord);

    BEGIN
        WITH Label DO
            ColumnID := FormValue[NameIdx].CardValue;
            Width    := FormValue[WidthIdx].CardValue;
            Position := VAL(ATLGSPosition, FormValue[PositionIdx].CardValue);
        END;
    END PutBackLabelInfo;

BEGIN

    IF (NOT CreateTaskColumnsTree()) THEN
        RETURN CancelKey;
    END;

    CalcMinCharWidths();

    ReportSettings := TLGSGanttRecord( WeeksMinChars );    (* RSC 18-Apr-89 *)  (* WKH 25-Jul-89 *)
    ConfigInfo     := TLGSConfigRecord();                   (* WKH 31-May-89 *)
    LocalUserUnit  := ConfigInfo^.Units;

    CASE LocalUserUnit OF
        Inches      : MessageToUse := ModuleNumber + InchesPerMsg;
                      ConversionFactor := 1.0;
    |   Centimeters : MessageToUse := ModuleNumber + CmPerMsg;
                      ConversionFactor := 2.54;
    ELSE
        FatalError();
    END;
    
    NEW(FormValue[InCm].CharValue);

    GetMessage(MessageToUse, FormValue[InCm].CharValue^);

    WITH ReportSettings^ DO (* Copy settings to temp work space *)
        NEW(FormValue[PgDs].CharValue);
        SetString(FormValue[PgDs].CharValue^, Asterik);

        NEW(FormValue[Palt].CharValue);
        Copy(Palette, FormValue[Palt].CharValue^);                (* 12-Jun-89 LAA *)

        FormValue[TimU].CardValue := ORD(Group);
        FormValue[TimU].RealValue := GetMinMeasurePerTimeUnit(ORD(Group)); (* 3/8/89 WKH *)

        IF (TimeScale = 0.0) THEN   (* 5/30/89 WKH *)
            FormValue[TimS].RealValue := DefaultMeasure;
        ELSE
            FormValue[TimS].RealValue := CharactersToMeasure(TimeScale,
                                                             DefaultSpec.PointSize
                                                             DIV PointSizeMultiplier);
        END;

        FormValue[HzGd].CardValue := ORD(HorizGrid);
        FormValue[VtGd].CardValue := ORD(VertGrid);
        FormValue[GStl].CardValue := ORD(GridStyle);
        FormValue[Crnr].CardValue := ORD(Corners);

        InitLabelField(Label1, L1CO, L1WD, L1PS);
        InitLabelField(Label2, L2CO, L2WD, L2PS);
        InitLabelField(Label3, L3CO, L3WD, L3PS);
        InitLabelField(Label4, L4CO, L4WD, L4PS);


        FormValue[Bars].CardValue := ORD(Symbology);
        FormValue[Actu].CardValue := ORD(ShowActuals);

        FormValue[Strt].CardValue := StartDate;
        NEW(FormValue[Strt].CharValue);
        Copy(Starting, FormValue[Strt].CharValue^);
        FormValue[Endg].CardValue := EndDate;
        NEW(FormValue[Endg].CharValue);
        Copy(Ending, FormValue[Endg].CharValue^);
        FormValue[ExSp].CardValue := ORD(ExtraSpacing);
        FormValue[InLv].CardValue := IndentLevel;
        TempFontMember            := DefaultSpec.FontMember;

        NEW(FormValue[Gant].CharValue);
        SetLengthOf(FormValue[Gant].CharValue^, 0);

        (* String fields *)

        NEW(FormValue[Layt].CharValue);

        SetLengthOf(FormValue[Layt].CharValue^, 0);

        (* we don't really care if it found the layout, everything will be set
           for us anyways. 5/24/89 WKH *)
        IF (ValidateLayoutAndAdjust(Layout, FormValue[Layt].CharValue^)) THEN END;

        CalcStartAndEndDates();

    END;

    FormValue[Brdr].CardValue := ORD(QueryBorderFlag());

    Code := DoForm(0, 0, maxcol, GanttWEnd, 52, TRUE, FormValue, CheckForm);

    IF (Code <> CancelKey) THEN
        ScheduleSaved := FALSE;
        WITH ReportSettings^ DO (* Get FormValue's back into record *)
            Copy(FormValue[Palt].CharValue^, Palette);            (* 12-Jun-89 LAA *)
            SetBorderFlag(FormValue[Brdr].CardValue > 0);
            Group        := VAL(ATLGSScale, FormValue[TimU].CardValue);
            HorizGrid    := VAL(BOOLEAN, FormValue[HzGd].CardValue);
            VertGrid     := VAL(BOOLEAN, FormValue[VtGd].CardValue);
            ExtraSpacing := VAL(BOOLEAN, FormValue[ExSp].CardValue);
            IndentLevel  := FormValue[InLv].CardValue;
                                 
            TimeScale    := MeasureToCharacters(FormValue[TimS].RealValue,
                                                DefaultSpec.PointSize DIV
                                                PointSizeMultiplier);
            
            TrimRear(FormValue[Layt].CharValue^);
            Copy(FormValue[Layt].CharValue^, Layout);

            GridStyle    := VAL(ATLGSGridStyle, FormValue[GStl].CardValue);
            Corners      := VAL(ATLGSCorner, FormValue[Crnr].CardValue);

            PutBackLabelInfo(L1CO, L1WD, L1PS, Label1);
            PutBackLabelInfo(L2CO, L2WD, L2PS, Label2);
            PutBackLabelInfo(L3CO, L3WD, L3PS, Label3);
            PutBackLabelInfo(L4CO, L4WD, L4PS, Label4);

            Symbology    := VAL(ATLGSSymbology, FormValue[Bars].CardValue);
            ShowActuals  := VAL(BOOLEAN, FormValue[Actu].CardValue);
            Copy(FormValue[Strt].CharValue^, Starting);
            StartDate    := FormValue[Strt].CardValue;
            Copy(FormValue[Endg].CharValue^, Ending);
            EndDate      := FormValue[Endg].CardValue;
        END;

        TLGSPageInfo := TLGSPageRecord();               (* 29-Dec-89 WKH  *)
        TLGSPageInfo^.WhatsMyChart := TLGSGanttChart;   (* 29-Dec-89 WKH  *)
    END;

    DISPOSE(FormValue[Layt].CharValue);
    DISPOSE(FormValue[Palt].CharValue);                           (* 11-Jun-89 LAA *)
    DISPOSE(FormValue[PgDs].CharValue);
    DISPOSE(FormValue[L1CO].CharValue);
    DISPOSE(FormValue[L2CO].CharValue);
    DISPOSE(FormValue[L3CO].CharValue);
    DISPOSE(FormValue[L4CO].CharValue);
    DISPOSE(FormValue[Strt].CharValue);
    DISPOSE(FormValue[Endg].CharValue);
    DISPOSE(FormValue[Gant].CharValue);
    DISPOSE(FormValue[InCm].CharValue);

    DisposeTaskColumnsTree();

    RETURN(Code);

END ExecForm;
(*$O=*)


MODULE Overhead;

IMPORT
    ADR, ADate, ADateBlock, ATreeNode, ATreeOrder, ATaskPtr, ADDRESS, TaskTree,
    BaseLineShowing, ATaskFlag, MinDate, MaxDate;

EXPORT 
    LocalScheduleEndDate, LocalScheduleStartDate,
    CalcStartAndEndDates;

VAR
    LocalScheduleStartDate  : ADate; (* 3/23/89 WKH  TEMPORARY!!!*)
    LocalScheduleEndDate    : ADate; (* These vars should come from Planner in Lazlo *)


PROCEDURE CalcStartAndEndDates();

VAR
    TaskNode       : ATreeNode;
    Task           : ATaskPtr;

BEGIN
    LocalScheduleEndDate   := MinDate; 
    LocalScheduleStartDate := MaxDate;

    TaskNode := TaskTree^.Methods^.GetFirstVisible(TaskTree);  (* 21-Nov-89 RSC was GetFirst! *)
    WHILE (TaskNode <> NIL) DO
        Task := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);

        WITH Task^.Plan.Dates DO
            (* Find the latest end date of any task. *)
            IF (EarlyEnd > LocalScheduleEndDate) THEN
                LocalScheduleEndDate := EarlyEnd;
            END;

                (* Find the earliest start date of any task. *)
            IF (EarlyStart < LocalScheduleStartDate) THEN
                LocalScheduleStartDate := EarlyStart;
            END;

        END;

        IF (BaseLineShowing AND (BaseLineExists IN Task^.TaskFlags)) THEN
            WITH Task^.BaseLine.Dates DO
                (* Find the latest end date of any task. *)
                IF (EarlyEnd > LocalScheduleEndDate) THEN
                    LocalScheduleEndDate := EarlyEnd;
                END;

                    (* Find the earliest start date of any task. *)
                IF (EarlyStart < LocalScheduleStartDate) THEN
                    LocalScheduleStartDate := EarlyStart;
                END;

            END;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);
        TaskNode := TaskNode^.Methods^.NextForDisplay (TaskNode);
    END;

END CalcStartAndEndDates;

END Overhead;


PROCEDURE TLGSGanttMain();


VAR
    Copyright                      : ARRAY[0..50] OF CHAR;

BEGIN

    LayoutBoxLRY := maxrow - 5;
    PaletteLry   := maxrow - 4;

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        ErrorMessage(ModuleNumber + NoTasksMsg);     (* "There are no tasks to graph." *)
        PackageOK := FALSE;
    ELSIF (NOT TLGSConfigIsCool()) THEN
        ErrorMessage(ModuleNumber + NoDeviceSetup);  (* "You must configure for a graphics device before using this function." *)
        PackageOK := FALSE;
    ELSIF (NOT HeapAvailable()) THEN
        ErrorMessage(ModuleNumber + NoHeapMsg);
        PackageOK := FALSE;                                     (* 30-Jan-89 LAA *)
    ELSE
        CalcStartAndEndDates();                                   (* 23-Mar-89 WKH *) 

        IF (ExecForm() <> ExitKey) THEN
            PackageOK := FALSE;                                 (* 30-Jan-89 LAA *)
        END;
    END;

END TLGSGanttMain;



BEGIN

    TLGSGanttMain();

END TLGSGANT.


