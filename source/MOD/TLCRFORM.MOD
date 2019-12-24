MODULE TlCrForm;  (* Cost Report Form *)

    (*  MODIFICATION HISTORY
        02-Feb-88 LAA   Removed reference to LowFuel.
        10-Feb-88 RSC   Cleaned up edits of form.  A lot.
        24-Feb-88 RSC   Added Tab support.
        25-Feb-88 RSC   Cleaned up code sets.
        27-Feb-88 RSC   Disavow 'Billable' from TvsT.
         5-Mar-88 EGK   Disabled all Baseline Spent and Baseline To Go
                        columns, and expanded DontUseThese set.
        23-Jun-88 EGK   Removed form-record-building code.  This form is
                        now in the forms file.
        23-Jun-88 EGK   Changed column numbers in DontUseThese set to
                        accommodate the new "Man-hours / Max available"
                        column.
         7-Jul-88 EGK   Call LegalColumn to prevent picking baseline columns
                        with no baseline in schedule.  Normally, though,
                        those columns are now excluded from the list
                        entirely.
        30-Aug-88 AJL  -Restrict the date ranges to any limited by filter
                        selection.
        31-Aug-88 AJL  -If the final task is the schedule is a milestone,
                        the duration of the schedule is extended by one
                        time unit to ensure that there is a period in which
                        to report the task costs.  See also ROLLUPRE for a
                        synchronized change.
         2-Nov-88 AJL  -Check for plausibility of dates entered vis-a-vis
                        the reporting period.
                       -Back out any changes to the interface record if the
                        form is cancelled.
         7-Nov-88 RSC  -Allow "Normalize" on all three forms.
         9-Nov-88 RSC  -Fix bug where default dates were not being set.
        21-Dec-88 LAA  -Changed imports for Lazlo reorganization.
        10-Jan-89 RSC   Changed Storage to Space.
        22-Mar-89 RSC  Improve for "Better Reports" project.  Use XTabColumn
                       rather than RptCommon routines.
        01-May-89 EGK  In CheckDateRanges, check for dates that would
                       cause an overflow before subtracting.
        22-May-89 KKC  Allow zero column width if there is no column name.
        24-May-89 LAA  Rename "Man" to "Work" in constants imported from
                       MagicNum, because they changed there.  Also removed
                       some unused imports from MagicNum.
         6-Jun-89 AJL  Put filters into FlexStor.
        19-Jun-89 AJL  Removed FiltersOn boolean, replaced by
                       QueryRevealFilterOn.
        22-Jun-89 KKC  Set DatesEntered only if user entered a valid date.
        19-Jul-89 KKC  Check ClientUse in AnOverlayInteface to determine
                       who calls TLCRForm.
        25-Jul-89 EGK  Changed usage of "TotalByX" and "TotalByY" to reflect
                       the new enumerated type "ASummChoice".
        27-Jul-89 KKC - Pop up calculator if F2 key is pressed in a numeric
                        field.
        31-Jul-89 RSC  Made an exception for XTabPercentAss, so that we do
                       not allow totals.  In general, we should allow
                       percentage columns to be averaged.  Until that time,
                       we don't allow totals of percentage columns.  Right
                       now, we only have one such percentage column,
                       Percent Assigned.
        09-Aug-89 KKC  Add copyright message.
        11-Aug-89 KKC  Allow user to leave the field with empty field name.
        28-Aug-89 KKC  Add two new fields for Resource vs Time form.
                       Add an extra paramter to SetOtherFields.
         5-Sep-89 RSC  Only allow NORMALIZE when dealing with a numeric,
                       non-percentage field.  Fixes AJL's bug of 16-Aug-89.
        14-Sep-89 KKC  Set FillValuesOnScreen in CheckTheForm.
        19-Sep-89 RSC  Make the EndDate parsing take the StartDate as a
                       default.
        20-Sep-89 KKC
        18-Sep-89 KKC  Call FillValuesOnScreen in CheckFormEntry.
        22-Sep-89 KKC  Call ProtectFieldValues in CheckFormEntry.
        25-Sep-89 KKC  Default Show as Hourly Rate to "NO"
                       Protect "total by row", "Column width" and "number of
                       digits" for Histogram report.
        27-Sep-89 KKC  Protect and force the (Plan, Actual) field to plan if
                       cost tracking is off.
        14-Nov-89 MWP  Import WBSError to resolve a version conflict.
        30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
        05-Jun-90 AJL  Removed ARateCalendar imports.
        22-Aug-90 TGS  Changed references to some phrases to make room for 
                       more XTab column phrase nums (bumped 60's and 70's up
                       to 70's and 80's).
         6-Nov-90 AJL  Import column numbers from XTabColNumbers.
        20-Dec-90 TGS  Bug 3252: "total by column" field should always be
                       protected and hidden for histogram reports.
        19-Feb-91 AJL  For Cross-tab reports, "Duplicate on-screen histograms"
                       will select the AssignedQuantity column; while for
                       histograms it will continue to select WorkHours/Max.
        30-Apr-91 TGS  Swapped Column spec fields with R/R&C field.
        24-May-91 TGS  Interface StartDate is now the earlier of the filtered-
                       in task EarlyStart's, and the date on which spending
                       starts for an associated  resource (spending can start
                       before EarlyStart).
        29-May-91 EGK  In SetOtherFields, don't automatically blast the
                       Normalize flag to FALSE when defaults are to be
                       refreshed.  Just use whatever the form contains.
                       Fixes bug #4422.
         4-Jun-91 TGS  Get rid of silly "Estimates, Spent" field.
        10-Jun-91 PFG   Call GetXTabColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
        12-Jun-91 RSC  Remove WBSError (not used).
        13-Sep-91 TGS   FindStartOfSpending leaves things alone if Assignment
                        Rate turns out to be zero (indicating resource was
                        assigned but was never available?).
        16-Sep-91 TGS   FindStartOfSpending now picks up on spending on 
                        "cost"-type resources.
        18-Sep-91 TGS   FindStartOfSpending. Fixed a logic flaw (it was using
                        EndOfSpending inappropriately). Also we now loop
                        through the varying assignment list until we find the
                        first non-zero rate, rather than just checking the 
                        first entry and assuming that if it's zero that there
                        aren't any more rates to look at. You never know.
    *)

FROM Allocs         IMPORT
    (* TYPE  *)         ATaskName, AFixType, ARollupStatus, ATaskPtr,
                        ATask, ATaskFlag,
                        ATaskFlagSet, AStartStatus,
                        ADateBlock, ADateBlockPointer, ABigDateBlock,
                        ATaskStatus, ATaskStatusSet,
                        ATaskFilter, ATaskFilterSet,
                        ADurationMethod, AnAssignmentSummary,
    (* VAR   *)         StartStatusName, FixationName, TaskTree,
    (* PROC  *)         CheckTaskValid;

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentRecord,
    (* PROC *)          ForEachAssignment;

FROM Boxes          IMPORT
    (* TYPE *)          ABoxAttribute, ABoxType;

FROM Changer        IMPORT
    (* VAR  *)          UsesCostTracking;

FROM ChartForms     IMPORT
    (* TYPE *)          AChartFormat, AChartFormatPtr,
    (* PROG *)          CurrentLayout;

FROM Codes          IMPORT
        (* TYPE  *)     ACode,
        (* CONST *)     MaxCode,
        (* VARS  *)     EmptyCodeSet,
        (* PROCS *)     SetCodeBits;

FROM Dialog        IMPORT
        (* TYPE *)      ADialogOption,
        (* PROCS *)     NotYetImplemented, Burp, Error, FatalError,
                        WarningBox, ContinuationBox;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr;

FROM Filter1       IMPORT
        (* PROC *)      ResourceFiltersPassed;

FROM FilterRc      IMPORT
    (* TYPE *)          AFltrType, AFltrSet, AFilterRecordPointer,
    (* VAR *)           RevealFilter;

FROM FilterUtility IMPORT
    (* PROC *)          TestFilterBit;

FROM Filters       IMPORT
    (* PROC *)          QueryRevealFilterOn;

FROM FlexStor       IMPORT 
    (* TYPE *)          AnExtHandle;

FROM Forms         IMPORT
        (* TYPE *)      AFieldValue, AForm, ACheckReason, AStringValue,
        (* PROCS *)     DoForm, ShowValue, SetFieldProtection,
                        SetFieldHidden, ChangeFormTitle, SetFormChange;

FROM FormCon       IMPORT
    (* TYPE *)          AFieldType, AFieldNo;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType,
                        CardinalType, BooleanType, BigStartTimeType,
                        PredicateRecordType, EnumeratedType, BigEndTimeType,
                        HeadingRecordType, SkipRecordType,
                        RepeatRecordType, AggregatorRecordType,
        (* TYPE *)      AFormat;

FROM Keys          IMPORT
        (* CONST *)     EditKey, ExitKey;

FROM Kbio          IMPORT
        (* CONST *)     maxrow, maxcol;

FROM Layout        IMPORT
        (* CONST *)     GanttWStart, GanttWEnd;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        Upshift, Compare, Fill,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays      IMPORT
        (* PROCS *)     OverlayContext;

FROM ParseTime     IMPORT
    (* PROC *)          StoEndTimeU, StoTimeU;

FROM RecordIO      IMPORT
        (* PROCS *)     WriteRecord, WriteString;

FROM RptCommon     IMPORT
        (* TYPES *)     AColumn, AnOverlayInterfacePtr, AReportType,
                        AnOverlayInterface, AGetInfoProc, AClientUse,
                        ASummChoice,
        (* VARS  *)     TotalByX, TotalByY,
        (* PROCS *)     GenerateFileTrailers, ColumnHeadings, ReleaseDialog,
                        CreateTheFile, GetMessageWord, TaskHeaders,
                        TimeHeaders, CommonCleanup, RsrcHeaders;

FROM RsrcMod       IMPORT
        (* TYPE  *)     AResourcePointer,
                        AResourceType, ACostStyle,
        (* VAR   *)     ResourceTree,
        (* PROC *)      AverageResourceRate,
                        FindResourceByNumber,
                        CheckResourceValid;

FROM Space         IMPORT
        (* PROCS *)     ALLOCATE, DEALLOCATE, SetHeapLevels, HeapAvailable;

FROM Subfiles      IMPORT
        (* PROCS *)     StartFileOutput,    EndFileOutput,
                        StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM Text          IMPORT
        (* PROCS *)     LineExists, CopyLine;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATree, ATreeNode, ATreeOrder,
        (* PROCS *)     ValidateTree, ValidateTreeNode;

FROM TimeFormat    IMPORT
    (* PROC *)          FormatAsEndDateStyle, TimeUtoS;

FROM Timei         IMPORT
        (* CONST*)      MinDate, MaxDate,
        (* TYPE *)      ADurationUnit, ADate;

FROM Timeu         IMPORT
        (* PROCS *)     UpScale;

FROM TimeJump      IMPORT
        (* PROC *)      FindStartDateOf, FindNextKeyDate;

FROM VaryAssgnment  IMPORT 
    (* PROC *)          GetVaryingAssgnListEntry, NumberOfRatesInList;

FROM XTabColNumbers IMPORT
    (* CONST *)
                        XTabQuantity,
                        XTabBillable,
                        XTabSpentQuantity,
                        XTabYTGQuantity,
                        XTabTotalDollars,
                        XTabSpentDollars,
                        XTabYTGDollars,
                        XTabPercentAss,
                        XTabAWorkHours,
                        XTabAWorkDays,
                        XTabAWorkWeeks,
                        XTabYWorkHours,
                        XTabYWorkDays,
                        XTabYWorkWeeks,
                        XTabDataExists,
                        XTabBaseLineOffset,
                        XTabFirstBaseCol,
                        XTabLastColumn,
                        XTabTWorkHrsPerMax;

FROM XTabColumns    IMPORT
    (* TYPE *)          AColumnNameSet,
    (* PROC *)          CreateXTabColumnsTree, DisposeXTabColumnsTree,
                        PickXTabColumn, SearchForXTabColumn,
                        GetXTabColumnName;

FROM XTabFormat     IMPORT
    (* PROC *)          GetXTabInfo;






CONST   ModuleNumber = 21400;       (* Share with TLCR. *)
        MAXCARDINAL = 65535;
        TaskVsTimeForm      =   44;
        TaskVsResourceForm  =   69;
        ResourceVsTimeForm  =   70;

TYPE
        ADateRecord         =   RECORD
            DateString      :       AStringValue;
            DateValue       :       CARDINAL;
        END;

        AReportDataRecord   =   RECORD
            ReportData      :   AStringValue;
            ReportDataID    :   CARDINAL;
            ReportDataWidth :   CARDINAL;
            ReportDataDigit :   CARDINAL;
        END;

        AnCrossTabRecord    =   RECORD
            ReportStartDate         :       ADateRecord;
            ReportEndDate           :       ADateRecord;
            CrossTabReportOn        :       CARDINAL;
            ReportPeriod            :       CARDINAL;
            ReportData              :       AReportDataRecord;
            UseActualEffortOrCost   :       CARDINAL;
            ShowasHourlyRate        :       CARDINAL;
            TotalbyColumn           :       CARDINAL;
            TotalbyRow              :       CARDINAL;
        END;



VAR
    StartNorm,
    StartBase,
    EndNorm,
    EndBase     : ADate;

    Interface   : AnOverlayInterfacePtr;
    CrossTabRecord  :   AnCrossTabRecord;

    NoBaselines,
    WarnedOfDateConstraint  : BOOLEAN;
    FillFieldValuesOnScrn   : BOOLEAN;
    LastChangeIndex         : CARDINAL;








    (* ConstrainDateToFilter --

       Preconditions -- none special.

       Postconditions -- If there is a filter selection active, and it
                         specifies a date range, and the passed date
                         is outside the date range, the passed date will be
                         modified to fall within the date range, else
                         no change.
    *)


PROCEDURE ConstrainDateToFilter( VAR Date : ADate );
VAR
    FilterRecord : AFilterRecordPointer;
    S : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..0] OF CHAR;
    Changed : BOOLEAN;
BEGIN
    Changed := FALSE;

    IF (QueryRevealFilterOn()) THEN
        ValidateTreeNode(RevealFilter);
        FilterRecord := RevealFilter^.Methods^.LockFlexStorDataObject(RevealFilter);
        IF (TestFilterBit ( FilterRecord^.fltrset, FDate )) THEN
            IF (Date < FilterRecord^.startdate) THEN
                Date := FilterRecord^.startdate;
                Changed := TRUE;
            END;
            IF (Date > FilterRecord^.enddate) THEN
                Date := FilterRecord^.enddate;
                Changed := TRUE;
            END;
        END;
        RevealFilter^.Methods^.UnlockUnchangedDataObject(RevealFilter);   FilterRecord := NIL;

        IF (Changed) AND (NOT WarnedOfDateConstraint) THEN
            WarnedOfDateConstraint := TRUE;
            GetMessage(ModuleNumber+6,S);
            SetLengthOf(Title,0);
            WarningBox( S, Title, NoHelp );
        END;
    END;
END ConstrainDateToFilter;

    (*  24-May-91 TGS

        FindStartOfSpending --

        Fed to Assignments.ForEachAssignment.

        Walks through the assignments for a particular task and returns
        the first date on which spending occurred. This is so the crosstab
        report start reporting on the first period in which there was 
        spending, regardless of what the first EarlyStart date was.

        In TL4 and before, spending always happened after EarlyStart; this
        is no longer necessarily the case.

    *)

PROCEDURE FindStartOfSpending(VAR Assignment : AnAssignmentRecord;
                                  Ptr        : ADDRESS ) : BOOLEAN;
VAR
    PStartDate  : POINTER TO ADate;
    StartDate,
    EndDate     : ADate;
    Rate        : REAL;
    i, Count    : CARDINAL;
    Found       : BOOLEAN;
BEGIN
    PStartDate := Ptr;
    WITH Assignment DO
    IF ( Selected IN ResourceFiltersPassed
                        (FindResourceByNumber(Resource^.ID)) ) THEN
        IF ( Resource^.Type = Employable ) THEN
            IF ( VaryingAssignment <> AnExtHandle(NIL) ) THEN
                (* 18-Sep-91 TGS added this loop  *)
                Count := NumberOfRatesInList( VaryingAssignment );
                i     := 1;
                Found := FALSE;
                WHILE (i <= Count) AND (NOT Found) DO   
                    IF GetVaryingAssgnListEntry(VaryingAssignment, i,
                                                StartDate, EndDate, Rate)
                            AND
                       ( Rate > 0.0 ) THEN
                        IF ( StartDate < PStartDate^ ) THEN
                            PStartDate^ := StartDate;
                        END;
                        Found := TRUE;
                    ELSE
                        INC(i);
                    END;
                END;
            END;

            (* 16-Sep-91 TGS pick up "cost" assignments *)
        ELSIF ( ActualQuantity <> 0.0 ) THEN (* don't do Baseline/FutureOnly assignments *)    
            IF ( EndOfSpentDate = 0 ) THEN
                    (* special case *)
                PStartDate^ := EndOfSpentDate;

            ELSIF ((EndOfSpentDate - 1 ) < PStartDate^) THEN
                PStartDate^ := EndOfSpentDate - 1;

            END;
        END;
       
    END; (* IF   *)
    END; (* WITH *)

    RETURN TRUE;
END FindStartOfSpending;



 (* *************************** FORM Related stuff ****************** *)


CONST
    FillValuesOnScrn =   0;
    STD = 1;  (* Start Date  *)
    EDD = 2;  (* End   Date  *)
    PER = 3;  (* Period      *)
    CNM = 4;  (* Col Name    *)
    CWD = 5;  (* Col Width   *)
    CDG = 6;  (* Col Digits  *)
    ICL = 7;  (* Include     *)
    (* 4-Jun-91 TGS
    UseActualEffortOrCost = 8 ;
    *)
    NOR = 8;  (* Col Digits  *)
    TBX = 9;  (* Tot by X    *)
    TBY = 10; (* Tot by Y    *)

    LASTFIELD  = TBY;
    MAXSTRINGS = 3;         (* Col name, dates *)


 (* Build Form Record - construct the form for this report. *)

PROCEDURE BuildFormRecord( VAR FormValue  : ARRAY OF AFieldValue;
                           VAR Strings    : ARRAY OF AStringValue   );
VAR
    Node       : ATreeNode;
    Task       : ATaskPtr;
    j, Loop,
    C          : CARDINAL;
    F          : AFormat;
    s          : ARRAY [0..255] OF CHAR;
    Start, End : ADate;
    B          : BOOLEAN;
BEGIN
 (* Fill in the starting data for the field. *)

    FOR Loop := 0 TO HIGH(FormValue) DO
        FormValue[Loop].CardValue := 0;
        FormValue[Loop].CharValue := NIL;
    END;

    WITH Interface^ DO

        FormValue[ ICL ].CardValue := ORD(NOT ResourcesOnly);

        (* Note that 'Strings' is DECLARED 1..n, but, because it is passed to this
           procedure, we must reference it is 0..n-1.   Stupid compiler.
        *)
        j := 0;
        FOR Loop := CNM TO ((CNM-1) + (PMaxReportColumns * 3)) BY 3 DO
            INC(j);
            WITH FormValue[Loop] DO
                CharValue    := ADR(Strings[j-1]);
                IF (Columns^[ j ].Width > 0) THEN
                    ColumnHeadings( AGetInfoProc(GetXTabInfo),
                                    Columns^[ j ].ColumnNumber,
                                    s, CharValue^, s, s, B, B, C, F, C );
                ELSE
                    CharValue^[0] := 0C;
                END;
                CardValue := Columns^[ j ].ColumnNumber;
            END;
            FormValue[Loop+1].CardValue := Columns^[ j ].Width;
            FormValue[Loop+2].CardValue := Columns^[ j ].Decimals;
        END;

        NoBaselines := TRUE; (* Assume no baseline for this schedule *)

        IF (WhichForm = TaskVsResourceForm) THEN (* KKC Aug 27, 89 *)
            StartNorm := MinDate;
            StartBase := MinDate;
            EndNorm   := MaxDate;  (* Assume all the time in the world. *)
            EndBase   := MaxDate;
            Node   := TaskTree^.Methods^.GetFirstVisible( TaskTree );
            WHILE (Node <> NIL) AND (NoBaselines) DO
                Task := Node^.Methods^.LockFlexStorDataObject( Node );
                IF (BaseLineExists IN Task^.TaskFlags) THEN
                    NoBaselines := FALSE;
                END;
                Node^.Methods^.UnlockUnchangedDataObject( Node );
                Node := Node^.Methods^.NextForDisplay(    Node );
            END;
        ELSE
            IF ( WhichForm = ResourceVsTimeForm ) THEN
                FormValue[FillValuesOnScrn].CardValue := ORD(FillValuesOnScreen);
            END;
            FormValue[ PER ].CardValue := ORD(Period)-1;
            StartNorm := MaxDate;
            StartBase := MaxDate;
            EndNorm   := MinDate;
            EndBase   := MinDate;
            Node   := TaskTree^.Methods^.GetFirstVisible( TaskTree );
            WHILE (Node <> NIL) DO
                Task := Node^.Methods^.LockFlexStorDataObject( Node );
                WITH Task^ DO
                        (* 24-May-91 TGS
                           Spending can start before EarlyStart now *)
                    Start := Plan.Dates.EarlyStart;
                    ForEachAssignment
                        (Plan.Assignments, FindStartOfSpending, ADR(Start));
                    End   := Plan.Dates.EarlyEnd;
                        (* If this is a milestone, then we may need to add
                           an extra reporting period at the end of the
                           schedule since milestone costs occurring at the
                           boundary of a reporting period are included in
                           the later period.  See 8-31-88 changes to ROLLUPRE.
                           AJL 8-31-88  *)
                    IF (End = Start) AND (End <> MaxDate) THEN
                        INC(End);   (* Max test added RSC 11/9/88 *)
                    END;
                    IF (Start < StartNorm) THEN
                        StartNorm := Start;
                    END;
                    IF (End > EndNorm) THEN
                        EndNorm := End;
                    END;
                    IF (BaseLineExists IN TaskFlags) THEN
                            (* 24-May-91 TGS 
                               Spending can start before EarlyStart now *)
                        Start := BaseLine.Dates.EarlyStart;
                        ForEachAssignment
                            (BaseLine.Assignments,
                            FindStartOfSpending, ADR(Start));
                        End   := BaseLine.Dates.EarlyEnd;
                        IF (End = Start) AND (End <> MaxDate) THEN (* See above comments. *)
                            INC(End);
                        END;
                        IF (Start < StartBase) THEN
                            StartBase := Start;
                        END;
                        IF (End > EndBase) THEN
                            EndBase := End;
                        END;
                        NoBaselines := FALSE;
                    END;
                END;
                Node^.Methods^.UnlockUnchangedDataObject( Node );
                Node := Node^.Methods^.NextForDisplay(   Node );
            END;
        END;

        IF (DatesEntered) THEN
            FormValue[ STD ].CardValue := TheStartDate;
            FormValue[ EDD ].CardValue := TheEndDate;
        ELSE
            FormValue[ STD ].CardValue := StartNorm;
            FormValue[ EDD ].CardValue := EndNorm;
        END;


        FOR Loop := STD TO EDD DO
            WITH FormValue[ Loop ] DO
                CharValue     := ADR(Strings[ j ]);
                INC(j);
                CharValue^[0] := 0C;  (* Don't show dates if not entered *)
                IF (DatesEntered) THEN
                    IF (Loop = EDD) THEN
                        FormatAsEndDateStyle( ADate( CardValue ), CharValue^ );
                    ELSE
                        TimeUtoS( ADate( CardValue ), CharValue^ );
                    END;
                END;
            END;
        END;
        FormValue[ NOR ].CardValue := ORD(Normalize);
        (* 4-Jun-91 TGS
        FormValue[ UseActualEffortOrCost ].CardValue :=
                                                   ORD(CostTracking);
        *)
        FormValue[ TBX ].CardValue := ORD(TotalByX);
        FormValue[ TBY ].CardValue := ORD(TotalByY);
    END;

END BuildFormRecord;



    (* Check that the date ranges are plausible for the time periods
       chosen. *)


PROCEDURE CheckDateRanges(     Start, End : ADate;
                               Period : ADurationUnit ) : BOOLEAN;
VAR
    S : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..0] OF CHAR;
    SD, ED          : ADate;

BEGIN
    ED := FindNextKeyDate (End, Period);            (* 5/1/89 EGK *)
    SD := FindStartDateOf (Start, Period);
    IF (ED >= SD) AND ((ED - SD) >= UpScale (2, Period)) THEN
        RETURN TRUE;
    END;

    GetMessage(ModuleNumber+7,S);
    SetLengthOf(Title,0);

    RETURN ContinuationBox(S,Title,NoHelp);

END CheckDateRanges;


 (* Check The Form - Standard Form Check procedure.  *)

PROCEDURE CheckTheForm(    Form         : AForm;
                           FieldNo      : AFieldNo;
                       VAR FormValue    : ARRAY OF AFieldValue;
                           CheckReason  : ACheckReason;
                       VAR Code         : CARDINAL
                                                      ) : BOOLEAN;
VAR
    Column        : CARDINAL;
    Title         : ARRAY [0..50] OF CHAR;
    s             : ARRAY[0..255] OF CHAR;
    ok            : BOOLEAN;
    CodeIn        : CARDINAL;


    PROCEDURE FillFieldValues(
                                    Form : AForm;
                            VAR FormValue : ARRAY OF AFieldValue
                            );
    VAR
        F           : AFormat;
        B           : BOOLEAN;
        C           : CARDINAL;
        ChartFormat : AChartFormatPtr;
    BEGIN
        WITH CrossTabRecord DO
            ReportStartDate.DateString := FormValue[STD].CharValue^;
            ReportStartDate.DateValue := FormValue[STD].CardValue;
            ReportEndDate.DateString := FormValue[EDD].CharValue^;
            ReportEndDate.DateValue := FormValue[EDD].CardValue;
            CrossTabReportOn := FormValue[ICL].CardValue;
            ReportPeriod := FormValue[PER].CardValue;
            ShowasHourlyRate := FormValue[NOR].CardValue;
            TotalbyColumn := FormValue[TBX].CardValue;
            TotalbyRow := FormValue[TBY].CardValue;
            ReportData.ReportData := FormValue[CNM].CharValue^;
            ReportData.ReportDataID := FormValue[CNM].CardValue;
            ReportData.ReportDataWidth := FormValue[CWD].CardValue;
            ReportData.ReportDataDigit := FormValue[CDG].CardValue;
        END;
        (* 4-Jun-91 TGS
        CrossTabRecord.UseActualEffortOrCost := FormValue[UseActualEffortOrCost].CardValue;
        *)
        SetLengthOf ( FormValue[STD].CharValue^, 0 );
        FormValue[STD].CardValue := 0;
        SetLengthOf ( FormValue[EDD].CharValue^, 0 );
        FormValue[EDD].CardValue := MaxDate;
        FormValue[ICL].CardValue := 0;

        ChartFormat := CurrentLayout();
        WITH Interface^ DO
            Period := ChartFormat^.scaleunit;
            IF ( Period = Minutes ) THEN
                Period := Hours;
            END;
            FormValue[ PER ].CardValue := ORD(Period)-1;
        END;

            (* If we are doing a histogram, which is a graph, use
               the column which makes the shape of the histogram
               match the shape shown on screen.  If printing the 
               numbers though, use the column whose numbers will
               match. *)

        IF (Interface^.ClientUse = Histogram) THEN
            FormValue[CNM].CardValue := XTabTWorkHrsPerMax;
        ELSE
            FormValue[CNM].CardValue := XTabQuantity;
        END;

        Column := FormValue[CNM].CardValue;
        ColumnHeadings( AGetInfoProc(GetXTabInfo),
                        FormValue[CNM].CardValue,
                        s, FormValue[CNM].CharValue^,s, s, B, B, C, F,
                        FormValue[CWD].CardValue );
        SetOtherFields(TRUE, TRUE);

        (* 4-Jun-91 TGS
        FormValue[UseActualEffortOrCost].CardValue := 0;
        *)
        FormValue[NOR].CardValue := 1;
        FormValue[TBX].CardValue := 0;
        FormValue[TBY].CardValue := 0;

        Interface^.CostTracking := FALSE;
    END FillFieldValues;



    PROCEDURE RestoreFieldValues(
                                        Form : AForm;
                                VAR FormValue : ARRAY OF AFieldValue
                                );
    VAR
        F          : AFormat;
        B          : BOOLEAN;
        C          : CARDINAL;
    BEGIN
        FormValue[STD].CharValue^ := CrossTabRecord.ReportStartDate.DateString;
        FormValue[STD].CardValue  := CrossTabRecord.ReportStartDate.DateValue;
        FormValue[EDD].CharValue^ := CrossTabRecord.ReportEndDate.DateString;
        FormValue[EDD].CardValue  := CrossTabRecord.ReportEndDate.DateValue;
        FormValue[ICL].CardValue  := CrossTabRecord.CrossTabReportOn;
        FormValue[PER].CardValue  := CrossTabRecord.ReportPeriod;
        (* 4-Jun-91 TGS
        FormValue[UseActualEffortOrCost].CardValue := CrossTabRecord.UseActualEffortOrCost;
        *)
        FormValue[NOR].CardValue := CrossTabRecord.ShowasHourlyRate;
        FormValue[TBX].CardValue := CrossTabRecord.TotalbyColumn;
        FormValue[TBY].CardValue := CrossTabRecord.TotalbyRow;
        FormValue[CNM].CharValue^ := CrossTabRecord.ReportData.ReportData;
        FormValue[CNM].CardValue  := CrossTabRecord.ReportData.ReportDataID;
        Column := FormValue[CNM].CardValue;
        IF ( Column <> MAXCARDINAL ) THEN
            ColumnHeadings( AGetInfoProc(GetXTabInfo),
                            FormValue[CNM].CardValue,
                            s, FormValue[CNM].CharValue^,s, s, B, B, C, F,
                            FormValue[CWD].CardValue );
            SetOtherFields(TRUE, TRUE);
            FormValue[CWD].CardValue  := CrossTabRecord.ReportData.ReportDataWidth;
            FormValue[CDG].CardValue  := CrossTabRecord.ReportData.ReportDataDigit;
        ELSE
            SetLengthOf(FormValue[CNM].CharValue^, 0);
            FormValue[CWD].CardValue  := 0;
            FormValue[CDG].CardValue  := 0;
        END;
        WITH Interface^ DO
            (* 4-Jun-91 TGS
            CostTracking := (FormValue[ UseActualEffortOrCost ].CardValue <> 0 );
            *)
            Period := VAL(ADurationUnit, (FormValue[ PER ].CardValue + 1) );
        END;
    END RestoreFieldValues;

    PROCEDURE ProtectFieldValues(
                                          Form : AForm;
                                 VAR FormValue : ARRAY OF AFieldValue;
                                   ProtectFlag : BOOLEAN
                                );
    BEGIN
        SetFieldProtection(Form,ICL,FormValue,ProtectFlag);
        SetFieldProtection(Form,PER,FormValue,ProtectFlag);
        SetFieldProtection(Form,NOR,FormValue,ProtectFlag);
        SetFieldProtection(Form,TBX,FormValue,ProtectFlag);
        SetFieldProtection(Form,CNM,FormValue,ProtectFlag);
        IF ( Interface^.ClientUse <> Histogram  ) THEN  (* 25-Sep-89 KKC  *)
            SetFieldProtection(Form,TBY,FormValue,ProtectFlag);
            SetFieldProtection(Form,CWD,FormValue,ProtectFlag);
            SetFieldProtection(Form,CDG,FormValue,ProtectFlag);
        ELSE
            SetFieldProtection(Form,TBX,FormValue,TRUE); (* 20-Dec-90 TGS *)
            SetFieldHidden(Form,TBX,FormValue,TRUE);
            SetFieldProtection(Form,TBY,FormValue,TRUE);
            SetFieldHidden(Form,TBY,FormValue,TRUE);
            SetFieldProtection(Form,CWD,FormValue,TRUE);
            SetFieldHidden(Form,CWD,FormValue,TRUE);
            SetFieldProtection(Form,CDG,FormValue,TRUE);
            SetFieldHidden(Form,CDG,FormValue,TRUE);
        END;

        (* 4-Jun-91 TGS
        IF ( NOT UsesCostTracking ) THEN
            FormValue[UseActualEffortOrCost].CardValue := 0;
            SetFieldProtection(Form,UseActualEffortOrCost,FormValue,TRUE);
        ELSE
            SetFieldProtection(Form,UseActualEffortOrCost,FormValue,ProtectFlag);
        END;
        *)

        ShowValue( Form, STD, FormValue );
        ShowValue( Form, EDD, FormValue );
        ShowValue( Form, ICL, FormValue );
        ShowValue( Form, PER, FormValue );
        (* 4-Jun-91 TGS
        ShowValue( Form, UseActualEffortOrCost, FormValue );
        *)
        ShowValue( Form, NOR, FormValue );
        ShowValue( Form, TBY, FormValue );
        ShowValue( Form, TBX, FormValue );
        ShowValue( Form, CNM, FormValue );
        ShowValue( Form, CWD, FormValue );
        ShowValue( Form, CDG, FormValue );
    END ProtectFieldValues;



    PROCEDURE ColumnSize( Column     : CARDINAL;
                      VAR ItsNumeric : BOOLEAN;
                      VAR Decimals   : CARDINAL;
                      VAR NoDecimals,
                          TotalByRsrc: BOOLEAN ) : CARDINAL;
    VAR
        DataType,
        DfltWidth : CARDINAL;
        Format    : AFormat;
        s1, s2    : ARRAY [0..69] OF CHAR;
        b         : BOOLEAN;
    BEGIN
        WITH Interface^ DO
            ColumnHeadings( AGetInfoProc(GetXTabInfo),
                            Column,
                            s1, s2,
                            s1, s2,
                            b,  TotalByRsrc,   DataType,
                            Format,  DfltWidth );
            Decimals   := ORD(Format.DecimalDigits);
            NoDecimals := (DataType <>  RealNumberType);
            ItsNumeric := (DataType IN {RealNumberType,IntegerType,CardinalType});
        END;
        RETURN DfltWidth;
    END ColumnSize;



    PROCEDURE SetOtherFields ( ColumnDataChanged, RefreshDefaults  : BOOLEAN   );
    VAR
        Loop,
        Decimals      : CARDINAL;
        ProtectNormalize,
        Normalize,
        AllowXTotals,
        AllowYTotals,
        TotalByRsrc,
        NoDecimals,
        ItsNumeric    : BOOLEAN;
        TempColSize     : CARDINAL;
    BEGIN
        IF ( ColumnDataChanged ) THEN
            IF (Column < MAXCARDINAL) THEN
                TempColSize := ColumnSize( Column,
                                           ItsNumeric,
                                           Decimals,
                                           NoDecimals,
                                           TotalByRsrc );
                IF (RefreshDefaults) THEN
                    FormValue[ CWD ].CardValue := TempColSize;
                    FormValue[ CDG ].CardValue := Decimals;
                END;
                SetFieldProtection( Form, CDG, FormValue, NoDecimals );
                SetFieldHidden    ( Form, CDG, FormValue, NoDecimals );

                (* If the field is NOT numeric, then we cannot total data.
                   And we cannot normalize.
                   If it IS,
                       Allow normalize for non-% columns.
                       If TotalByRsrc, allow both X and Y totals.
                       Else
                               Report       Allow X  Allow Y
                           ---------------  -------  -------
                           If Task vs Rsrc     Y        N
                           If Task vs Time     N        N
                           If Rsrc vs Time     N        Y
                *)
                AllowXTotals := FALSE; (* Default to FALSE *)
                AllowYTotals := FALSE;
                ProtectNormalize := FALSE;  (* 25-Sep-89 KKC  *)
                Normalize    := FALSE;  (* RSC 5-Sep-89 *)
                IF (ItsNumeric) THEN
                    IF (TotalByRsrc) THEN
                        AllowXTotals := TRUE;
                        AllowYTotals := TRUE;
                        ProtectNormalize := TRUE;   (* 25-Sep-89 KKC  *)
                        Normalize := VAL(BOOLEAN, FormValue[NOR].CardValue);    (* 29-May-91 EGK *)
                    ELSE
                        (* For the percent assigned column totaling does
                           not work.  In general, for any percentage column,
                           a total should perhaps be an AVERAGE.  Since we
                           as yet have no such mechanism, we do not allow
                           totaling for the percentage columns.  Now, we
                           just have the one column, "XTabPercentAss".
                        *)
                        IF (Column <> XTabPercentAss) THEN
                            ProtectNormalize := TRUE;      (* 25-Sep-89 KKC  *)
                            Normalize := VAL(BOOLEAN, FormValue[NOR].CardValue);    (* 29-May-91 EGK *)
                            CASE Interface^.PReportType OF
                               TvsR : AllowXTotals := TRUE;
                             | RvsT : AllowYTotals := TRUE;
                            ELSE
                            END;
                        END;
                    END;
                END;

                IF ( Interface^.ClientUse = Histogram  ) THEN  (* 25-Sep-89 KKC  *)
                    SetFieldProtection( Form, CWD, FormValue, TRUE );
                    SetFieldHidden    ( Form, CWD, FormValue, TRUE );
                    SetFieldProtection( Form, CDG, FormValue, TRUE );
                    SetFieldHidden    ( Form, CDG, FormValue, TRUE );
                    AllowYTotals := FALSE;
                END;

                IF (RefreshDefaults) THEN
                    FormValue[ TBX ].CardValue := ORD(AllowXTotals);
                    FormValue[ TBY ].CardValue := ORD(AllowYTotals);
                    FormValue[ NOR ].CardValue := ORD(Normalize);
                END;
                SetFieldProtection( Form, TBX, FormValue, NOT AllowXTotals );
                SetFieldHidden    ( Form, TBX, FormValue, NOT AllowXTotals );

                SetFieldProtection( Form, TBY, FormValue, NOT AllowYTotals );
                SetFieldHidden    ( Form, TBY, FormValue, NOT AllowYTotals );

                SetFieldProtection( Form, NOR, FormValue, NOT ProtectNormalize );   (* 25-Sep-89 KKC  *)
                SetFieldHidden    ( Form, NOR, FormValue, NOT ProtectNormalize );   (* 25-Sep-89 KKC  *)

                FOR Loop := CNM TO CDG DO
                    ShowValue( Form, Loop, FormValue );
                END;
            ELSE
                FOR Loop := NOR TO TBY DO
                    SetFieldProtection( Form, Loop, FormValue, TRUE );
                    SetFieldHidden    ( Form, Loop, FormValue, TRUE );
                END;
            END;
        END;

        WITH Interface^ DO
            IF (WhichForm <> TaskVsResourceForm) THEN (* KKC Aug 27, 89 *)
                FOR Loop := STD TO EDD DO
                    WITH FormValue[ Loop ] DO
                        IF (CharValue^[0] <> 0C) THEN
                            IF (Loop = EDD) THEN
                                FormatAsEndDateStyle( ADate( CardValue ), CharValue^ );
                            ELSE
                                TimeUtoS( ADate( CardValue ), CharValue^ );
                            END;
                            ShowValue( Form, Loop, FormValue );
                        ELSE
                            IF (Column >= XTabFirstBaseCol) THEN
                                IF (Loop = EDD) THEN
                                    FormValue[ EDD ].CardValue := EndBase;
                                ELSE
                                    FormValue[ STD ].CardValue := StartBase;
                                END;
                            ELSE
                                IF (Loop = EDD) THEN
                                    FormValue[ EDD ].CardValue := EndNorm;
                                ELSE
                                    FormValue[ STD ].CardValue := StartNorm;
                                END;
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END SetOtherFields;



    PROCEDURE LegalColumn( Column : CARDINAL ) : BOOLEAN;
    VAR
        s : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (Column >= XTabFirstBaseCol) AND (NoBaselines) THEN
            GetMessage( Interface^.PModuleNumber + 82, s ); (* "There is no baseline for this schedule." *)
            Error(s);
            RETURN FALSE;
        END;
        RETURN TRUE;
    END LegalColumn;


    PROCEDURE NoColumnError();
    VAR
        s : ARRAY [0..255] OF CHAR;
    BEGIN
         GetMessage( Interface^.PModuleNumber + 81, s ); (* "Because you haven't filled in a column, I will not create a report." *)
         Error( s );
    END NoColumnError;


BEGIN (* CheckTheForm *)

    CodeIn := Code;
    Code := 0;

    WITH Interface^ DO
        IF (FieldNo = CWD) THEN
            IF (CheckReason = CheckFieldKey) THEN
                Code := 04000H + CodeIn;
                RETURN TRUE;
            END;
            IF  ( (FormValue[FieldNo].CardValue = 0)
                  AND
                  (LengthOf(FormValue[CNM].CharValue^) <> 0 ) ) THEN
                    FormValue[FieldNo].CardValue := 1;
                    ShowValue (Form, FieldNo, FormValue);
            END;
        ELSIF (CheckReason = CheckFormEntry) THEN
            IF (FieldNo = 0 ) THEN
                IF ( ClientUse = Histogram ) THEN
                    GetMessage ( ModuleNumber + 78, Title );
                    ChangeFormTitle( Form, Title );
                END;
                Column := FormValue[ CNM ].CardValue;
                SetOtherFields(TRUE, FALSE);
                IF (( WhichForm = ResourceVsTimeForm ) 
                    AND
                    ( FillValuesOnScreen )) THEN
                    IF ( LengthOf ( FormValue[CNM].CharValue^ ) = 0 ) THEN
                        FillFieldValues( Form, FormValue );
                    END;
                    ProtectFieldValues(Form, FormValue, FillValuesOnScreen );
                END;
                (* 4-Jun-91 TGS
                IF ( NOT UsesCostTracking ) THEN
                    FormValue[UseActualEffortOrCost].CardValue := 0;
                    SetFieldProtection(Form,UseActualEffortOrCost,FormValue,TRUE);
                    ShowValue( Form, UseActualEffortOrCost, FormValue );
                END;
                *)
            END;
        ELSIF (CheckReason = CheckFieldExit) THEN
            IF (FieldNo = CNM) THEN
                Column := FormValue[ FieldNo ].CardValue;
                TrimRear( FormValue[CNM].CharValue^ );
                IF ( LengthOf( FormValue[CNM].CharValue^)  <> 0 ) THEN
                    IF (Column = MAXCARDINAL) THEN
                        NoColumnError();
                        RETURN FALSE;
                    ELSIF (NOT LegalColumn (Column)) THEN
                        RETURN FALSE;
                    END;
                END;
                RETURN TRUE;
            END;
        ELSIF (CheckReason = CheckFormExit) THEN
            IF (FieldNo = CNM) THEN
                Column := FormValue[ FieldNo ].CardValue;
                TrimRear( FormValue[CNM].CharValue^ );
                IF ( LengthOf( FormValue[CNM].CharValue^)  = 0 ) THEN
                    GetMessage ( ModuleNumber + 81, s );
                    Error(s);
                    RETURN FALSE;
                ELSE
                    IF (Column = MAXCARDINAL) THEN
                        NoColumnError();
                        RETURN FALSE;
                    ELSIF (NOT LegalColumn (Column)) THEN
                        RETURN FALSE;
                    END;
                END;
                RETURN TRUE;
            END;
        ELSIF (CheckReason = CheckFieldKey) THEN

          (* Only allow F2 on a 'real' column field.
          *)
            IF (FieldNo = CNM) THEN
                ok := TRUE;
                Column := FormValue[ FieldNo ].CardValue;
                IF (PickXTabColumn( maxcol-29, 3, maxcol, maxrow-10,
                                    Column, FormValue[ FieldNo ].CharValue^ )) THEN
                    FormValue[ FieldNo ].CardValue := Column;
                    SetOtherFields(TRUE,TRUE);
                    ok := LegalColumn(Column);
                    IF ( ok ) THEN
                        SetFormChange(Form);
                    END;
                END;

                (* In case column names were edited, update all column
                    names on form.  Need to do this even if PickXTabColumn
                    returns FALSE, since the user may have changed the column,
                    but pressed ESC from the pick list.  *) 

                IF FormValue[CNM].CardValue <> MAXCARDINAL THEN
                    GetXTabColumnName(  FormValue[CNM].CardValue,
                                        FormValue[CNM].CharValue^);
                ELSE
                    Fill(FormValue[CNM].CharValue^, " ", 24);
                END;
                ShowValue(Form, FieldNo, FormValue);

                RETURN (ok);

            END;
            Code := 04000H + CodeIn;
            RETURN TRUE;
        ELSIF (CheckReason = CheckFieldChange) THEN
            IF (FieldNo = CNM) THEN
                WITH FormValue[ FieldNo ] DO
                    TrimRear( CharValue^ );
                    IF (CharValue^[0] <> 0C) THEN
                        IF (NOT SearchForXTabColumn( CharValue^, Column )) THEN
                            RETURN FALSE;
                        END;
                    ELSE
                        Column := MAXCARDINAL;
                    END;
                    CardValue  := Column;
                    SetOtherFields(TRUE, TRUE);
                END;
            ELSIF ( FieldNo = FillValuesOnScrn ) THEN
                IF ( FormValue[ FieldNo ].CardValue = 0 ) THEN
                    IF ( FillFieldValuesOnScrn ) THEN
                        IF ( LastChangeIndex <> FormValue[ FieldNo ].CardValue ) THEN
                            LastChangeIndex := FormValue[ FieldNo ].CardValue;
                            RestoreFieldValues( Form, FormValue );
                        END;
                    END;
                ELSE
                    IF ( LastChangeIndex <> FormValue[ FieldNo ].CardValue ) THEN
                        LastChangeIndex := FormValue[ FieldNo ].CardValue;
                        FillFieldValues( Form, FormValue );
                        FillFieldValuesOnScrn := TRUE;
                    END;
                END;
                FillValuesOnScreen := (FormValue[ FieldNo ].CardValue <> 0 );
                ProtectFieldValues(Form, FormValue, FillValuesOnScreen );
                IF ( FormValue[ FieldNo ].CardValue = 0 ) THEN (* 20-Dec-90 TGS *)
                    WITH FormValue[CNM] DO 
                        IF ((CharValue^[0] <> 0C) AND
                            (SearchForXTabColumn( CharValue^, Column ))) THEN
                            CardValue  := Column;
                            SetOtherFields(TRUE, TRUE);
                        END;
                    END;
                END;
                RETURN TRUE;
            ELSIF (FieldNo = STD) OR (FieldNo = EDD) THEN
                WITH FormValue[ FieldNo ] DO
                    TrimRear( CharValue^ );

                    ok := TRUE;

                    IF (LengthOf(CharValue^) > 0) THEN
                        IF (FieldNo = EDD) THEN
                            TheEndDate := TheStartDate; (* RSC 19-Sep-89 *)
                            ok := StoEndTimeU (CharValue^, TheEndDate);
                            ConstrainDateToFilter(TheEndDate);
                            CardValue := TheEndDate;
                        ELSE
                            ok := StoTimeU (CharValue^, TheStartDate);
                            ConstrainDateToFilter(TheStartDate);
                            CardValue := TheStartDate;
                        END;
                    END;

                    IF (FormValue[ STD ].CharValue^[0] <> 0C) AND
                       (FormValue[ EDD ].CharValue^[0] <> 0C) THEN
                        ok := (ok AND
                              (TheStartDate <= TheEndDate ));
                    END;

                    IF (ok) THEN
                        DatesEntered := (FormValue[ STD ].CharValue^[0] <> 0C)
                                            OR
                                        (FormValue[ EDD ].CharValue^[0] <> 0C);
                        Column := FormValue[ CNM ].CardValue;
                        SetOtherFields(FALSE, TRUE);
                    ELSE
                        Burp();
                        DisplayMessage( PModuleNumber + 0 ); (* "End < Start, must be like '22-Aug-88'" *)
                    END;
                    RETURN ok;
                END;
            (* 4-Jun-91 TGS
            ELSIF (FieldNo = UseActualEffortOrCost ) THEN
                CostTracking := (FormValue[ FieldNo ].CardValue <> 0 );
            *)
            ELSIF (FieldNo = PER) THEN
                Period       := VAL(ADurationUnit, (FormValue[ PER ].CardValue + 1) );
            END;
        END;

        IF (CheckReason = CheckFormExit) AND (FieldNo = PER) THEN
                (* Before allowing exit, check that the dates entered
                   by the user look plausible in light of the reporting
                   period chosen.   The above test could actually check
                   any field number.  We test so that we only ask once. *)
            IF (DatesEntered) AND
               (NOT CheckDateRanges(TheStartDate,TheEndDate,Period)) THEN
                Code := CARDINAL({15}) + PER;   (* Goto PER field. *)
                RETURN FALSE;
            END;
        END;
    END;
    RETURN TRUE;
END CheckTheForm;




 (* Do The Form - Ask the user for the desired columns for the report.
 *)
PROCEDURE DoTheForm();
VAR
    Loop, j      : CARDINAL;
    DontUseThese : AColumnNameSet;
    FormValue    : ARRAY [0..LASTFIELD]  OF AFieldValue;
    Strings      : ARRAY [1..MAXSTRINGS] OF AStringValue;
    OldInterface : AnOverlayInterfacePtr;
    Actual       : BOOLEAN;
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    NEW(OldInterface);

    OldInterface^ := Interface^;   (* Save copy in case form is cancelled. *)

    WITH Interface^ DO

     (* Build the form record *)

        BuildFormRecord( FormValue, Strings );

     (* Build a tree of column names for the GoTo lists.  As a kluge,
        set up a BITSET with the list of fields NOT to use in a report.
        In the case of Task Vs Time, exclude the ....Quantity fields.
      *)
        DontUseThese := AColumnNameSet{};
        IF (PReportType = TvsT) THEN
            DontUseThese := AColumnNameSet{ XTabQuantity,
                                            XTabBillable,
                                            XTabSpentQuantity,
                                            XTabYTGQuantity,
                                            XTabQuantity      + XTabBaseLineOffset,
                                            XTabBillable      + XTabBaseLineOffset,
                                            XTabSpentQuantity + XTabBaseLineOffset,
                                            XTabYTGQuantity   + XTabBaseLineOffset};
        END;

        DontUseThese := DontUseThese +
                        AColumnNameSet{ XTabSpentQuantity + XTabBaseLineOffset,  (* 24-May-89 LAA *)
                                        XTabYTGQuantity   + XTabBaseLineOffset,
                                        XTabSpentDollars  + XTabBaseLineOffset,
                                        XTabYTGDollars    + XTabBaseLineOffset,
                                        XTabAWorkHours    + XTabBaseLineOffset,
                                        XTabAWorkDays     + XTabBaseLineOffset,
                                        XTabAWorkWeeks    + XTabBaseLineOffset,
                                        XTabYWorkHours    + XTabBaseLineOffset,
                                        XTabYWorkDays     + XTabBaseLineOffset,
                                        XTabYWorkWeeks    + XTabBaseLineOffset };

        IF (NoBaselines) THEN
            FOR j := XTabFirstBaseCol TO XTabLastColumn DO
                INCL (DontUseThese, j);
            END;
        END;

        IF (NOT CreateXTabColumnsTree( DontUseThese )) THEN
            OverlayOK := FALSE;
            DISPOSE(OldInterface);
            RETURN;
        END;

     (* Do the form.  If ESC is hit, don't do the report. *)

        FillFieldValuesOnScrn := FALSE;
        LastChangeIndex := MAXCARDINAL; (* LastChangeIndex is not needed if *)
                                        (* the CheckProg is not called for  *)
                                        (* an extra CheckFieldChange        *)

        OverlayOK := (DoForm( 0, GanttWStart,
                              maxcol,     maxrow-1,
                              WhichForm, TRUE,
                              FormValue,  CheckTheForm ) = ExitKey);

        DisposeXTabColumnsTree();

        IF (OverlayOK) THEN
            ResourcesOnly := (FormValue[ ICL ].CardValue = 0);
            j := 0;
            FOR Loop := CNM TO (CNM-1+(PMaxReportColumns * 3)) BY 3 DO
                INC(j);
                Columns^[ j ].ColumnNumber := FormValue[Loop  ].CardValue;
                IF (Columns^[ j ].ColumnNumber < MAXCARDINAL) THEN
                    Columns^[ j ].Width    := FormValue[Loop+1].CardValue;
                    Columns^[ j ].Decimals := FormValue[Loop+2].CardValue;
                    Actual := (Columns^[ j ].ColumnNumber < XTabFirstBaseCol);
                    PNeedActualAssignment := (PNeedActualAssignment OR Actual);
                    PNeedBaseAssignment   := (PNeedBaseAssignment   OR (NOT Actual));
                END;
            END;
            TotalByX     := VAL(ASummChoice, FormValue[ TBX ].CardValue);
            TotalByY     := VAL(ASummChoice, FormValue[ TBY ].CardValue);

            TheStartDate := FormValue[ STD ].CardValue;
            TheEndDate   := FormValue[ EDD ].CardValue;

                (* If there is a filtered date range, constrain the
                   start and end dates. *)
            ConstrainDateToFilter( TheStartDate );
            ConstrainDateToFilter( TheEndDate );

            IF (TheEndDate <  TheStartDate) THEN
                TheEndDate := TheStartDate;
            END;

            Normalize    := VAL(BOOLEAN, FormValue[ NOR ].CardValue);
        ELSE
            Interface^ := OldInterface^;
            RETURN;
        END;

    END; (* WITH Interface *)

    DISPOSE(OldInterface);

END DoTheForm;


BEGIN
    WarnedOfDateConstraint := FALSE;

    Interface := OverlayContext();
    DoTheForm();

END TlCrForm.





