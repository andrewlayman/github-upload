(*----------------------------------------------------------------------------
       MODIFICATION HISTORY:

       Aug. 21, 1985  AJL - Moved the call to CalendarForm before the
                            call to RecomputeStdDay in CalendarHours
                            so that extra conversions are not done.
                            Converting task and resource scales
                            unnecessarily reduces accuracy.
                          - Within RecomputeStdDay, use floating
                            point calculations to do adjustments.
                          - Prevent exit from Hours screen if no
                            working hours.
                          - Add InsideCalendarForm to avoid rescaling
                            things more than necessary.
                          - Make task duration conversion more accurate
                            by storing the old (external) duration into
                            the count field.
        Aug. 22, 85, AJL  - A clever (read dangerous but powerful) trick
                            to avoid inaccurate duration conversions:
                            store the EXTERNAL form of the duration
                            into the field meant for the internal form
                            on each resource, edge, etc.  Then, after
                            processing the form (etc.) restore them
                            back to internal form.

        Dec. 7, 1985 AJL  - Make sure that the scale of chart or
                            period of resource cost never bocomes 0.
                          - Make sure that durations are exactly
                            expressed so that we have no conversion
                            errors.  Side effect: Scales may change.
        11/14/86 LAA    Brought this over from international.  Replaces old
                        AllSaved with ConfigSaved.  Changed SetState(UnSched)
                        to UnSetState(Scheduled), and adjusted parameters on
                        DoForm.
        11/27/86 LAA    Removed NeedsRecompute, whose function is now handled
                        by ChartState.
        03/19/87 EGK    Supports new field in calendar form for start-of-week
                        day.  Changing this causes an UnSetState(Formatted)
                        as well as NoteChange.
        03/23/87 EGK    Calls SetAsOfDate in Epilogue.
        03/24/87 EGK    Supports new field in calendar form for first fiscal
                        month.  Changing this causes an UnSetState(Formatted)
                        and NoteChange.
                        *)(*
        03/27/87 EGK    Now has a CheckCalendarForm procedure to check the
                        validity of the first-fiscal-month string.
        04-Jun-87 LAA   Changed parameters to TraverseTree and ForAll.
        21-Jul-87 LAA   Changed usage of datestring to store bigtime dates
                        in the workspace.  Must choose which dates to store
                        depending on the task type and start status.
        07-Aug-87 LAA   Changed SaveTime and RestoreTime for named layouts.
        18-Aug-87 EGK   Use a multiple-choice box, instead of the calendar
                        form, to get confirmation before changing standard
                        day and week definitions.  This is not needed in
                        CalendarDays, since Cal.DoYears doesn't change these
                        values.
        12-Dec-88 EGK   After making a changes to the calendar, all pertinent
                        dates are converted using a separate module,
                        TimeConversions.  It is no longer necessary to go
                        through contortions to save external values of
                        durations and big-time values of dates before a
                        calendar change.
                        SaveTime is no longer used.
                        New things updated:  As-of date, baseline info,
                        layout scales.
        03-Feb-88 EGK   Fixed computation of new SMUPH.  On rare occasions,
                        it was returning SMU*SMUPH <> 60.
        06-Mar-88 LAA   If the calendar is changed, set the NeedsRecalculate
                        bit in each task's status set.
        28-Oct-88 EGK   Added HoursInWeek procedure to check for work-hour
                        changes.  Fixed ConvertAllDates to always convert the
                        end dates of tasks.
        07-Nov-88 EGK   Reactivated a simple version of SaveTime for use by
                        KillTime.  KillTime might change dates, and the next
                        call to WeMustReduce might use unconverted task dates.
                        Fixed bugs where baseline dates were used without
                        checking for existence of a baseline.
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        10-Jan-89 RSC   Changed Storage to Space.
        21-Mar-89 RSC   Added support for SetSMU.
         3-Apr-89 LAA   Have to convert ChartStartDay to the new date, too.
        23-May-89 EGK   Allow definition of a choice prefix in the dialog
                        box handled by ConfirmConversions.
        19-Jun-89 AJL   Add CheckPlausibleCalendar to verify that the user
                        hasn't got totally wierd calendar settings.
        23-Aug-89 KKC   Add one more parameter to RecomputeTable.
        18-Sep-89 RSC   Remove AdjustScale.
        22-Sep-89 RSC   1) CheckPlausibleCalendar() was being a little
                           pesimistic in its checks of the calendars.
                           I softened it just a smidge.
                           BUG # 1406.
                        2) When computing proposed hours/day for the
                           suggestion box, round the numbers to be more
                           reasonable.
                           BUG # 1406.
                        3) Scale the resource cost rates by Resource^.Units
                           before changing the meaning of a Unit.  This is
                           because all cost rates are stored as $s/hour
                           to make costing calculations easier.  If you
                           change the number of hours in a day, though,
                           you want a DAILY cost to stay the same.
                           This only applies to resources and var costs.
                           BUG # 1408.
                        *)(*
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        18-Apr-90 MWP   If the start day of the week has changed, re-initialize
                        week number data structures.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        04-Jun-90 AJL   Removed references to resource rates--temporarily.
        19-Jul-90 AJL   Changed to use new format of Cal.DoYears.
        12-Sep-90 RSC   Fixed for new Allocs.Def
         1-Nov-90 RSC   Conversion for qtr-hour days.
         6-Nov-90 RSC   Fixup the dialog that asks how you want days and
                        hours set.  Changed it to use MakeSubstitutions.
        12-Nov-90 RSC   Added the new dates to the converted dates when
                        calendar conversion is done.
        21-Nov-90 RSC   Ajusted OldStdDay and NewStdDay to be the number
                        of work MINUTES in a day, rather than the number
                        of TICS.
        12-Mar-91 TGS   Call LayoutChanged() so Gantt scale stays in synch.
                        If precision increases too much, KillTime to maximize
                        chances that dates (AsOfDate in particular) stay in
                        range.
                        ConvertAllDates() doesn't use Duration to extrapolate
                        End dates, since that doesn't work any more. Fixes bug
                        where if calander changed, baseline dates would be 
                        made identical to PLAN.
        15-May-91 AJL   Check that setting the fiscal year does not create
                        a date format that is too long.
                        *)(*
        22-May-91 LAA   Changed InsideCalendarForm to return a BOOLEAN, to
                        indicate whether any changes were made on the form.
                        For now, it just returns whether the form was left
                        with ESC or F10, but we could make it more precise.
                        This was done in response to bug #4443, which is a
                        symptom of removing all availability and residuals
                        lists from resources when a calendar change is made.
                        Ideally, it'd be good to fix those things up like we
                        do for task dates, etc. but a policy decision seems
                        to have been made no to do that.  Ok, so at least
                        now it won't happen if you just ESC from the form!
                        I also removed a misleading comment from Prologue.
                        *)(*
        24-Jun-91 RSC   LateFreeEnd dates were not being adjusted right.
        25-Jun-91 RSC   Also, SMU is not being set before AfterCalendarChange
                        is set.  And, backed out some of the change from
                        12-Mar-91 because of bug # 4561.  I try now to
                        preserve AsOf with ABigTime.
        01-Jul-91 LAA   Reworked what happens after an F10 from the workhours
                        form, so that the adjusting of various calendars
                        parameters only happens if there were changes to the
                        form.  Bug #4675.  Did the same kind of fix for the
                        other options.
        2-Jul-91 EGK    Always redisplay the hours-per-day field, so the
                        user will see when we "condition" it to follow the
                        rules.  Fixes Eve bug #4142.
        2-Jul-91 AJL    Add a local error message to the check proc so that
                        when we detect a too-long date format we can give
                        a context-sensitive error message.
         9-Jul-91 LAA   Added a parameter to InsideCalendarForm, so it can
                        return status about whether the changes made on the
                        form will require calendar reorganization.
        24-Jul-91 AJL  -Ask before KillTime.
                       -Don't kill dates used by the baseline.
        26-Jul-91 EGK   The polarity of the PreserveDurations flag was
                        incorrect.  It was being set to TRUE if the user
                        picked "End dates" from the ConfirmConversions
                        dialog box.  Somehow, this has been wrong for a long
                        time, at least since version 4.
        29-Jul-91      -Do not force a calendar reorg if the user only
                        changes the starting month of the year or the 
                        starting day of the week.  Bug 4866.
                       -After exit from the form, display the schedule light
                        in case it should indicate an unsaved schedule
                        settings.
        01-Aug-91 LAA   In GetKeywords, added a TrimRear after formatting
                        the *D* keyword, so the resulting phrase would read
                        better.  Bug #4576.
        15-Aug-91 EGK   In CalendarDays and CalendarHours, commented out
                        initial calls to SetState(Formatted).  For the cases
                        where the days or hours were not changed, these calls
                        were canceling out the UnsetState(Formatted) calls of
                        previous passes through CalendarDays and
                        CalendarHours which DID change the calendar, and
                        the recalc state was not set properly as a result.
                        See Eve bugs #4864 and 4888.
                        *)(*
        16-Aug-91 EGK   Don't let user enter a number of hours per day that
                        will get rounded down to zero.
        10-Sep-91 EGK   Put in logic to keep the "Shall I remove days from
                        the beginning of the calendar?" question from being
                        asked twice in a row.
        19-Sep-91 AJL   Do not remove days from the calendar unless there
                        are tasks in the schedule.
        24-Sep-91 EGK   Fixed FindNewSMUPH so that it only allows the same
                        values that the settings form allows.  This procedure
                        was occasionally returning a SMUPH of 30, which is
                        not allowed (2-minute precision?).
        26-Sep-91 TGS   If they're using week numbers, don't allow fiscal yrs.
        26-Sep-91 AJL   Remove fix of 19-Sep.  QA changed mind.
        27-Sep-91 EGK  -Fixed WeMustReduce so that it once again compares
                        number of ticks per week.  It broke when NewStdDay
                        and OldStdDay were changed to represent minutes.
                       -In the two places where AdjustSMUPH is called, I
                        moved the resetting of StdDayTics AFTER that call,
                        instead of before.  Problem was that we would set
                        StdDayTics, then possibly change SMU, and then be
                        stuck with an incorrect StdDayTics.
                       -Somebody commented out the calls to RestoreTime and
                        SaveTime at the end of KillTime.  I put them back
                        in, because they convert the existing schedule data
                        to follow the new squashed calendar.  This assures
                        that the second call to WeMustReduce will use
                        accurate dates in its comparisons.  (Refer to my
                        comment of 07-Nov-88.)
                       -Put code into RestoreAssignment to really convert
                        the small-date-based VaryingAssignment lists in the
                        assignment records, primarily so that calendar
                        changes won't affect baseline reporting.
      29-Jan-92 AJL   - Changed rate parameters to REAL.
----------------------------------------------------------------------------*)


IMPLEMENTATION MODULE CalControl;


FROM Allocs                 IMPORT
    (* TYPE *)                  ADateBlock, AFixType, AStartStatus,
                                ATaskFlag, ATaskPtr, ATaskStatus,
    (* VAR  *)                  TaskTree, 
    (* PROC *)                  CheckTaskValid, QueryNumberOfTasks;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord,
    (* PROC *)                  ForEachAssignment;

FROM AsOf                   IMPORT
    (* TYPE *)                  AnAsOfSettingOption,
    (* VAR  *)                  AsOfDate, AsOfSettingOption,
    (* PROC *)                  SetAsOfDate;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  CompareBigTimes, BigTimeToTimeInfo;

FROM Cal                    IMPORT
    (* PROC *)                  DoYears, DoWeek, RecomputeTable,
                                CheckAndFixupWeekTable;

FROM Chart                  IMPORT
                                CursorDay, MChDay, ChartStartDay;

FROM ChartControl           IMPORT
                                SetState, AChartState, ChartState, UnSetState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  CurrentLayout, DefaultChartFormat, LayoutTree,
    (* PROC *)                  LayoutChanged;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, ErrorPhrase, WarningBox,
                                MultipleChoiceBox, ContinuationBox,
                                ADialogOption, Burp;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr,
    (* PROC *)                  CheckEdgeValid;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM Forms                  IMPORT 
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
    (* PROC *)                  DoForm, ShowValue, NullCheckProc;

FROM Kbio                   IMPORT
                                maxrow, maxcol;

FROM Keys                   IMPORT
                                ExitKey;

FROM KeywdSub               IMPORT
    (* PROC *)                  MakeSubstitutions;

FROM Layout                 IMPORT
                                GanttWEnd;

FROM LStrings               IMPORT
                                SetString, ConcatLS, CtoS, SetLengthOf,
                                TrimRear;

FROM MsgFile                IMPORT
                                GetMessage, ConcatMessage, DisplayMessage;

FROM ParseTime              IMPORT
    (* PROC *)                  StoD;

FROM RealFormat             IMPORT
    (* VARS  *)                 DefaultAmountFormat,
    (* PROCS *)                 FormatAsAmount;

FROM ResCal                 IMPORT
    (* PROC *)                  DisposeResAvailabilities;

FROM RsrcMod                IMPORT
    (* TYPE *)                  ACostStyle, AResourcePointer, AResource,
    (* VAR *)                   ResourceTree;

FROM Schedule               IMPORT
    (* VAR *)                   ConfigSaved,
    (* PROC *)                  DisplayScheduleLight;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, TSIZE, ADR;

FROM TimeConversions        IMPORT
    (* PROC *)                  BeforeCalendarChange, AfterCalendarChange,
                                ToNewDate, ToNewDuration, ToNewScale;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR  *)                  EndDateStyle, DefaultDateAndTimeFormat,
    (* PROC *)                  CtoMonth, CheckDateFormatLength;

FROM TimeJump               IMPORT
    (* PROC *)                  FindStartDateOf, FindNextKeyDate;

FROM Timei                  IMPORT
    (* CONST *)                 Jan, Dec, Sun, Sat, FindToday,
    (* TYPE *)                  ADurationUnit, ADate, ADuration, ATimeInfo,
    (* VAR  *)                  Today, 
    (* PROC *)                  TimeUtoT, TtoTimeU;

FROM Timeu                  IMPORT
    (* TYPE *)                  AWeekTable, ATimeTable, AMonthSet,
    (* VAR  *)                  SMU, SMUPH, FSMUPH, WeeksBeginOn, TimeTable,
    (* PROC *)                  UpScale, DownScale, FindCorrectScale,
                                SetSMU, GetStartingMonth, SetStartingMonth;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime, CalendarTimeToBigTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnList, AVaryingAssgnListIndex,
    (* PROC *)                  CreateVaryingAssgnList,
                                DisposeVaryingAssgnList,
                                NumberOfRatesInList,
                                GetVaryingAssgnListEntry,
                                CreateVaryingAssgnListRange,
                                CreateVaryingAssgnListEntry;

FROM WeekNumberInfo         IMPORT                                  (* 18-Apr-90 MWP *)
    (* PROC *)                  InitWeekNumberInfo,
    (* VAR *)                   UsingWeekNumbers;

FROM WorkHours              IMPORT
    (* PROC *)                  RealTimeToWorkHours, WorkHoursToRealTime;


CONST
    ModuleNumber = 10200;    (* For GetMessage *)

CONST
    MAXCARDINAL = 0FFFFH;
    Zero        = 0.0;
    Four        = 4.0;

VAR
    OldStdDay,
    OldStdWeek,
    OldSMUPH            : CARDINAL;
    OldQtrHoursInWeek   : CARDINAL;
    FirstDate           : ABigTime;
    LatestDay           : ADate;
    PreserveDurations   : BOOLEAN;

    RemoveDaysAsked     : BOOLEAN;  (* These are for the "Shall I remove  *)
    RemoveDays          : BOOLEAN;  (* unused days from the beginning of  *)
                                    (* the calendar?" question.           *)




PROCEDURE CheckPlausibleCalendar();
CONST
    Distance = 20;           (* 20 days, then 20 weeks.   We need a distance
                                large enough to smooth out any bunch of
                                holidays. *) (* 22-Sep-89 RSC was 12. *)

    Tolerance  = (Distance DIV 2) + 1;  (* 21-Sep-89 RSC *)
VAR
    ThisWeek,
    Later,
    Later2      : ADate;
    i,
    Difference  : CARDINAL;
    TimeUnit    : ADurationUnit;
    Title       : ARRAY [0..31] OF CHAR;
    S           : ARRAY [0..255] OF CHAR;
BEGIN
    FOR TimeUnit := Days TO Weeks DO
            (* Get two dates, several weeks apart. *)
            (* 25-Jun-91 RSC Don't use "Today", as it may not be in the
                             calendar.  In fact, this will report trouble
                             if you use AsOf and that is late in the
                             calendar.  I chose a fixed date of 10,080
                             moments into the calendar.
            *)
        ThisWeek := FindStartDateOf(ADate(10080),Weeks);    (* 25-Jun-91 RSC 10,080 = Mins in one week. *)
        Later := ThisWeek;
        FOR i := 1 TO Distance DO
            Later := FindNextKeyDate(Later,TimeUnit);
        END;
            (* Now compute a similar distance based on what the user claimed
               was a standard day and standard week.

               1-Nov-90 RSC Ajusted for TICS
            *)
        Later2 := TimeTable.StdDayTics * Distance;
        IF (TimeUnit = Weeks) THEN
            Later2 := Later2 * TimeTable.StdWeek;
        END;
        INC(Later2,ThisWeek);

            (* Are they plausibly close? *)
        IF ( Later2 > Later) THEN
            Difference := Later2 - Later;
        ELSE
            Difference := Later - Later2;
        END;

        (* 21-Sep-89 RSC Was >= *)
        IF (Difference > UpScale(Tolerance,VAL(ADurationUnit,ORD(TimeUnit)-1))) THEN
            GetMessage(ModuleNumber+24,Title);
            GetMessage(ModuleNumber+25+ORD(TimeUnit)-ORD(Days),S);
            WarningBox(S,Title,NoHelp);
            RETURN;
        END;
    END;
END CheckPlausibleCalendar;







PROCEDURE SaveTime;

BEGIN
    OldSMUPH := SMUPH;
    BeforeCalendarChange();
END SaveTime;



PROCEDURE RescaleLayout     ( VAR Node      : ATreeNode;
                                  Context   : ADDRESS   );
VAR
    Layout          : AChartFormatPtr;

BEGIN

    Layout := Node^.Methods^.GetDataObject (Node);
    WITH Layout^ DO
        ToNewScale (scale, scaleunit, FALSE);
    END;

END RescaleLayout;







(* Rescale Resource:

    Scale the resource back to HOURS from its <Units>.

    ScaleResource must have been called for this resource!!
*)
PROCEDURE RescaleResource( VAR Node         : ATreeNode;
                               Context      : ADDRESS  );
VAR
    Resource : AResourcePointer;
BEGIN
    Resource := Node^.Methods^.GetDataObject(Node);
    IF (Resource^.ResidueAvailProfile <> AnExtHandle(NIL)) THEN
        DisposeResAvailabilities(Resource^.ResidueAvailProfile);
    END;
    IF (Resource^.LateResidueAvailProfile <> AnExtHandle(NIL)) THEN
        DisposeResAvailabilities(Resource^.LateResidueAvailProfile);
    END;
END RescaleResource;





PROCEDURE RestoreAssignment( VAR AssRec  : AnAssignmentRecord;
                                 Context : ADDRESS )            : BOOLEAN;
VAR
    OldList     : AVaryingAssgnList;
    NewList     : AVaryingAssgnList;
    i           : AVaryingAssgnListIndex;
    N           : CARDINAL;
    OK          : BOOLEAN;
    StartDate,
    EndDate     : ADate;
    Rate        : REAL;

BEGIN

    ToNewDate (AssRec.EndOfSpentDate);

    OldList := AssRec.VaryingAssignment;
    IF (OldList = AVaryingAssgnList(NIL)) THEN
        RETURN TRUE;
    END;

    NewList := AVaryingAssgnList(NIL);

    N := NumberOfRatesInList (OldList);
    OK := TRUE;
    i := 1;

    LOOP

        IF (i > N) OR (NOT OK) THEN
            EXIT;
        END;

        IF (GetVaryingAssgnListEntry (OldList, i, StartDate, EndDate, Rate)) THEN

            ToNewDate (StartDate);
            ToNewDate (EndDate);

            IF (i = 1) THEN
                NewList := CreateVaryingAssgnList (Rate, StartDate, ExtSlow);
                IF (NewList <> AVaryingAssgnList(NIL)) THEN
                    IF NOT (CreateVaryingAssgnListEntry (NewList, EndDate, Zero)) THEN
                        OK := FALSE;
                    END;
                ELSE
                    OK := FALSE;
                END;
            ELSE
                IF NOT (CreateVaryingAssgnListRange (NewList, StartDate, EndDate, Rate)) THEN
                    OK := FALSE;
                END;
            END;
        ELSE
            OK := FALSE;
        END;

        INC(i);
    END;

    DisposeVaryingAssgnList (AssRec.VaryingAssignment);

    IF (NOT OK) THEN
        IF (NewList <> AVaryingAssgnList(NIL)) THEN
            DisposeVaryingAssgnList (NewList);
            NewList := AVaryingAssgnList(NIL);
        END;
    END;
        
    AssRec.VaryingAssignment := NewList;

(*
    This was the "old" code, that unconditionally wiped out the varying
    assignment lists.       -- EGK 9/27/91

    (* Ignore the date in the assignment record, as that will be
       set by Recalc the next time it computes the VaryingAssignment
       list.
    *)
    IF (AssRec.VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
        DisposeVaryingAssgnList( AssRec.VaryingAssignment );
    END;
*)

    RETURN TRUE;

END RestoreAssignment;






PROCEDURE RestoreTaskTime (VAR Node         : ATreeNode;
                               Context      : ADDRESS  );

VAR
    Task                    : ATaskPtr;
    Edge                    : AnEdgePtr;


    PROCEDURE ConvertAllDates ( VAR DateBlock     : ADateBlock );
    BEGIN
        WITH DateBlock DO
            ToNewDate (EarlyStart);
            ToNewDate (LateFreeStart);
            ToNewDate (LateTotalStart);
            ToNewDate (LateIndStart);                   (* 12-Nov-90 RSC *)
            ToNewDate (EarlyEnd);                       (* 12-Mar-91 TGS *)
            ToNewDate (LateFreeEnd); (* 24-Jun-91 RSC *) (* 12-Mar-91 TGS *)
            ToNewDate (LateTotalEnd);                   (* 12-Mar-91 TGS *)
            ToNewDate (LateIndEnd);                     (* 12-Mar-91 TGS *)
        END;
    END ConvertAllDates;


BEGIN
    CheckTaskValid (Node);
    Task := Node^.Methods^.LockFlexStorDataObject (Node);

    IF (NOT(Scheduled IN ChartState)) THEN
        WITH Task^ DO
            ToNewDuration (duration, scale, PreserveDurations);

            ConvertAllDates (Plan.Dates);
            IF (BaseLineExists IN TaskFlags) THEN
                ConvertAllDates (BaseLine.Dates);
            END;
            INCL(TaskStatusSet, NeedsRecalculate);                (* 06-Mar-88 LAA *)
        END;

    END;

    ForEachAssignment(     Task^.Plan.Assignments, RestoreAssignment, NIL );
    ForEachAssignment( Task^.BaseLine.Assignments, RestoreAssignment, NIL );


        (* Restore the durations of any partial joins on the
           edges. *)
    Edge := Task^.desctasks;
    Node^.Methods^.UnlockFlexStorDataObject (Node);
    WHILE (Edge <> NIL) DO
        CheckEdgeValid(Edge);
        WITH Edge^.FromOffset DO
            ToNewDuration (Dur, Scale, PreserveDurations);
        END;
        Edge := Edge^.headlink;
    END;
END RestoreTaskTime;



PROCEDURE RestoreTime;

VAR
    ChartRecord             : AChartFormatPtr;
    s                       : ARRAY [0..1] OF CHAR;

BEGIN
    DisplayMessage(ModuleNumber+1);   (*  "Cleaning up the calendar . . ."  *)

    AfterCalendarChange();

    Today := FindToday();

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 999,
            RestoreTaskTime, NIL);

        (* Convert Gantt chart scale to external form. *)

    RescaleLayout (DefaultChartFormat, NIL);

    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild, 9999,
                                       RescaleLayout, NIL);

    LayoutChanged(); (* 12-Mar-91 TGS *)

        (*  Restore cursor time. *)
    AsOfDate  := BigTimeToCalendarTime(OldAsOf);    (* 25-Jun-91 RSC  *)
    SetAsOfDate;        (* 3/23/87 EGK *)

    ToNewDate (CursorDay);
    ToNewDate(ChartStartDay);                                     (* 3-Apr-89 LAA *)
    MChDay(CursorDay);

    s[0] := 0C;
    Message(s);

END RestoreTime;






    (* NoteChange -- Note that something about the calendar was
                     changed. *)


PROCEDURE NoteChange;
BEGIN
    UnSetState(Scheduled);
    ConfigSaved := FALSE;
END NoteChange;






    (*  KillTime -- Remove unnecessary days from the front of the calendar.
                    Do not change StdDay or StdWeek or SMUPH. *)


PROCEDURE FindEarliestTaskDate (VAR Node            : ATreeNode;
                            Context         : ADDRESS   );

VAR
    Task        : ATaskPtr;
    BigStart    : ABigTime;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    WITH Task^ DO
        IF (CompareBigTimes(UserEnteredStartDate,FirstDate) < 0) THEN
            FirstDate := UserEnteredStartDate;
        END;
        CalendarTimeToBigTime(Plan.Dates.EarlyStart,TRUE,BigStart);
        IF (CompareBigTimes(BigStart,FirstDate) < 0) THEN
            FirstDate := BigStart;
        END;
        IF (BaseLineExists IN TaskFlags) THEN
            CalendarTimeToBigTime(BaseLine.Dates.EarlyStart,TRUE,BigStart);
            IF (CompareBigTimes(BigStart,FirstDate) < 0) THEN
                FirstDate := BigStart;
            END;
        END;
    END;
    Node^.Methods^.UnlockUnchangedDataObject (Node);
END FindEarliestTaskDate;



PROCEDURE KillTime;
VAR
    TimeInfo    : ATimeInfo;
    i,j         : CARDINAL;
    S           : ARRAY [0..255] OF CHAR;
    S0          : ARRAY [0..0] OF CHAR;
BEGIN

    (* Removed 9/25/91 per QA request.  The logic is that the user
       might initially, with a blank schedule, set the precision very
       high and not be warned of the consequences.
    IF (QueryNumberOfTasks() = 0) THEN
        RETURN;
    END;
    *)


        (* Ask if we should eliminate unused time. *)

    IF (NOT RemoveDaysAsked) THEN
        RemoveDaysAsked := TRUE;
        SetLengthOf(S0,0);
        GetMessage(ModuleNumber+0,S);
        RemoveDays := (ContinuationBox(S,S0,NoHelp));
    END;

    IF (NOT RemoveDays) THEN
        RETURN;
    END;

    DisplayMessage(ModuleNumber+2);   (*  "Killing time . . ."  *)

        (*  Find the date of the earliest task. *)

    FirstDate := OldAsOf;
    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 999,
            FindEarliestTaskDate, NIL);

        (*  For all months earlier than the first scheduled task's month,
            set all days to non-working.  *)
    BigTimeToTimeInfo(FirstDate,TimeInfo);
    DEC(TimeInfo.tiYear,TimeTable.FirstYear-1);
    i := 1;
    j := Jan;
    WHILE (i < TimeInfo.tiYear) OR (j < TimeInfo.tiMonth) DO
        WITH TimeTable.YearTable[i,j] DO
            YearMap := AMonthSet{0..31};       (*  All non-working.  *)
        END;
        INC(j);
        IF (j > Dec) THEN
            j := Jan;
            INC(i);
        END;
    END;

    RecomputeTable(TimeTable, TRUE);   (*  Reorganize calendar.  *)

    NoteChange;

    RestoreTime; SaveTime;   (* Restore all of the task start dates and durations. *)

END KillTime;





PROCEDURE FindTaskLateEnd (VAR Node         : ATreeNode;
                               Context      : ADDRESS  );

VAR
    Task            : ATaskPtr;
    Day1            : ADate;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);

    WITH Task^ DO
            (* If the schedule has not be recomputed, the
               estart+duration may be much > lateenddate. *)
(*        IF (fixation <> FixedDate) THEN*) (* 21-Nov-90 RSC removed *)
            Day1 := Plan.Dates.EarlyEnd;
            IF (Day1 > LatestDay) THEN LatestDay := Day1 END;
            IF (BaseLineExists IN TaskFlags) THEN
                Day1 := BaseLine.Dates.EarlyEnd;
                IF (Day1 > LatestDay) THEN LatestDay := Day1 END;
            END;
(*        END;*)
        Day1 := Plan.Dates.LateTotalEnd;
        IF (Day1 > LatestDay) THEN LatestDay := Day1 END;
        IF (BaseLineExists IN TaskFlags) THEN
            Day1 := BaseLine.Dates.LateTotalEnd;
            IF (Day1 > LatestDay) THEN LatestDay := Day1 END;
        END;
    END;

    Node^.Methods^.UnlockUnchangedDataObject (Node);
END FindTaskLateEnd;



PROCEDURE FindLatestDate():ADate;
BEGIN
        (*  Find the latest ending date for any task. *)
    LatestDay  := 0;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 999,
            FindTaskLateEnd, NIL);

    RETURN LatestDay;

END FindLatestDate;



PROCEDURE QtrHoursInWeek ( WeekTable   : AWeekTable ) : CARDINAL;

VAR
    Day,
    QtrHours,
    QtrHour    : CARDINAL;

BEGIN

    QtrHours := 0;
    FOR Day  := Sun TO Sat DO
        WITH WeekTable[Day] DO
            FOR QtrHour := 0 TO 95 DO
                IF NOT (QtrHour IN WeekMap) THEN
                    INC(QtrHours);
                END;
            END;
        END;
    END;

    RETURN QtrHours;

END QtrHoursInWeek;




PROCEDURE AdjustSMUPH(OldSMUPH:CARDINAL; VAR NewSMUPH :CARDINAL;
                      OldStdDay,NewStdDay,
                      OldStdWeek,NewStdWeek:CARDINAL);
VAR
    ExpansionRatio,
    MaxExpansionRatio : REAL;
    s : ARRAY [0..255] OF CHAR;
    Title : ARRAY [0..20] OF CHAR;


    PROCEDURE WeMustReduce():BOOLEAN;
    VAR
        OldProduct, NewProduct : CARDINAL;
        LatestTaskDate : CARDINAL;
    BEGIN

            (* Compare number of TICS per WEEK, for the new scheme vs. the
               old scheme.  *)

        NewProduct := (NewStdDay DIV 60) * NewStdWeek * NewSMUPH;
        OldProduct := (OldStdDay DIV 60) * OldStdWeek * OldSMUPH;

        IF (NewProduct > OldProduct) THEN
            ExpansionRatio := FLOAT(NewProduct) / FLOAT(OldProduct);
            LatestTaskDate := FindLatestDate();
            IF (LatestTaskDate < AsOfDate) THEN
                LatestTaskDate := AsOfDate;
            END;
            IF (LatestTaskDate > 1) THEN
                MaxExpansionRatio := FLOAT(MAXCARDINAL) / FLOAT(LatestTaskDate);
                RETURN (MaxExpansionRatio < ExpansionRatio);
            END;
        END;
        RETURN FALSE;
    END WeMustReduce;


    PROCEDURE FindNewSMUPH  ( SMUPH : CARDINAL  ) : CARDINAL;
    BEGIN
        LOOP
            CASE (SMUPH) OF
                1, 2, 4, 10, 12, 60:        (* 9/24/91 EGK *)
                    RETURN (SMUPH);
            ELSE
                DEC (SMUPH);
            END;
        END;
    END FindNewSMUPH;


BEGIN
    IF (WeMustReduce()) THEN
        KillTime;                    (*  Attempt to eliminate unneeded days. *)
    END;
    IF (WeMustReduce()) THEN
        NewSMUPH :=  TRUNC(FLOAT(NewSMUPH) * MaxExpansionRatio / ExpansionRatio);
        IF (* God forbid *) (NewSMUPH < 1) THEN
            NewSMUPH := 1;
        END;
            (* Make it divide 60 evenly. *)
        NewSMUPH := FindNewSMUPH (NewSMUPH);            (* 2/3/88 EGK *)
        GetMessage(ModuleNumber+3,s);   (*  "WARNING--Time units per hour reduced.$$(Press [Esc] to continue.)"  *)
        GetMessage(ModuleNumber+4,Title);  (* "Reduce Precision" *)
        WarningBox(s,Title,NoHelp);
        UnSetState(Scheduled);
    END;
END AdjustSMUPH;



PROCEDURE ConfirmConversions ();
VAR
    s                   : ARRAY [0..255] OF CHAR;
    Title               : ARRAY [0..40] OF CHAR;
    MenuPrefix          : ARRAY [0..20] OF CHAR;
    MenuString          : ARRAY [0..40] OF CHAR;
    Selection           : CARDINAL;
BEGIN

    SetLengthOf (MenuPrefix, 0);
    GetMessage (ModuleNumber+20, s);            (* "For existing tasks, you can either" *)
    GetMessage (ModuleNumber+21, MenuPrefix);   (* "Keep" *)
    GetMessage (ModuleNumber+22, MenuString);   (* "End dates,Durations" *)
    GetMessage (ModuleNumber+23, Title);        (* "Calendar change" *)
    Selection := 1;

    IF (MultipleChoiceBox (s, Title, NoHelp, MenuPrefix,
            MenuString, Selection)) AND (Selection = 1) THEN
        PreserveDurations := FALSE;     (* 7/26/91 EGK *)
    END;

END ConfirmConversions;




PROCEDURE CheckCalendarForm (   Form         : AForm;                    (* 3/27/87 EGK *)
                                FieldNo      : AFieldNo;
                            VAR FormValue    : ARRAY OF AFieldValue;
                                CheckReason  : ACheckReason;
                            VAR Code         : CARDINAL ): BOOLEAN;

VAR
    s                   : ARRAY [0..255] OF CHAR;
    Title               : ARRAY [0..1]   OF CHAR;
    NewRealValue,
    Scaler      : REAL;
    TimeInfo    : ATimeInfo;
    Offset,
    NewSMU      : CARDINAL;
BEGIN
    Code := 0;

    IF (CheckReason = CheckFieldChange) OR
       (FieldNo     = 4) THEN    (* 22-Oct-90 RSC speedup *)
        IF (FieldNo = 3) THEN       (* Starting month *)
            WITH FormValue[FieldNo] DO
                IF NOT (StoD(CharValue^,TimeInfo)) THEN
                    RETURN FALSE;
                ELSE
                    (* 26-Sep-91 TGS added this IF *)
                    IF (UsingWeekNumbers) AND
                       (TimeInfo.tiMonth <> Jan) THEN
                        (* complain and change it back to Jan *)
                        GetMessage(ModuleNumber + 35, s);
                        Title := 0C;
                        WarningBox(s, Title, NoHelp);
                        CtoMonth(Jan,CharValue^);
                        ShowValue(Form,FieldNo,FormValue);
                    ELSE
                        CtoMonth(TimeInfo.tiMonth,CharValue^);
                        SetStartingMonth(TimeInfo.tiMonth);
                        ShowValue(Form,FieldNo,FormValue);
                    END;
                END;
            END;
            IF (NOT CheckDateFormatLength(DefaultDateAndTimeFormat)) THEN
                ErrorPhrase(ModuleNumber+34);
                RETURN FALSE;
            END;
        ELSIF (FieldNo = 1) THEN    (* Days in a week *)
            WITH FormValue[FieldNo] DO
                IF (CardValue < 1) THEN
                    CardValue := 1;
                    ShowValue(Form,FieldNo,FormValue);
                ELSIF (CardValue > 7) THEN
                    CardValue := 7;
                    ShowValue(Form,FieldNo,FormValue);
                END;
            END;

            (* 22-Oct-90 RSC This field can be in qtr hours, n > 0, n <= 24
            *)
        ELSIF (FieldNo = 0) OR
              (FieldNo = 4) THEN (* Hours in a day or Precision *)
            WITH FormValue[0] DO
                IF (RealValue < 0.25) THEN
                    RealValue := 0.25;
                ELSIF (RealValue > 24.0) THEN
                    RealValue := 24.0;
                END;

                CASE FormValue[4].CardValue OF  (* Precision *)
                  5, 4, 2  :    (* Qtr, Half, & Hour days *)
                    Scaler := 4.0;
                    Offset := 2;
                | 3, 1     :    (* Half & Whole Hour days only *)
                    Scaler := 2.0;
                    Offset := 1;
                ELSE            (* Whole Hour days only *)
                    Scaler := 1.0;
                    Offset := 0;
                END;

                NewRealValue := FLOAT(TRUNC( RealValue * Scaler )) / Scaler;

                IF (NewRealValue < 0.25) THEN       (* 8/16/91 EGK *)
                    RETURN FALSE;
                END;

                IF (NewRealValue <> RealValue) THEN
                    RealValue := NewRealValue;
                    DisplayMessage( ModuleNumber + 31 + Offset ); (* "Scale off" *)
                    Burp;
                END;
                ShowValue(Form,0,FormValue);        (* 7/2/91 EGK *)
            END;
        END;
    ELSIF (CheckReason = CheckFormExit) THEN

        IF (FieldNo = 4) THEN    (* Precision *)
            CASE FormValue[FieldNo].CardValue OF
             0  :   NewSMU := 60;
            |1  :   NewSMU := 30;
            |2  :   NewSMU := 15;
            |3  :   NewSMU := 6;
            |4  :   NewSMU := 5;
            |5  :   NewSMU := 1;
            ELSE
                ErrorPhrase(0);
            END;

            IF (NOT CheckDateFormatLength(DefaultDateAndTimeFormat)) THEN
                RETURN FALSE;
            END;

            RETURN CheckAndFixupWeekTable(TimeTable, NewSMU, TRUE);
        END;
    END;

    RETURN TRUE;

END CheckCalendarForm;



    (* This is the internally-callable version of the Form
       procedure.
       It now returns a flag indicating if any changes were (or might
       have been) made on the form.  
    *)




PROCEDURE InsideCalendarForm( VAR CalendarChanged : BOOLEAN ): BOOLEAN;

VAR
    TempDate,
    OldStdDay,
    OldStdWeek,
    OldSMUPH            : CARDINAL;
    Task                : ATaskPtr;
    NewStdDay           : CARDINAL;
    NewStdWeek          : CARDINAL;
    NewSMU              : CARDINAL;
    NewSMUPH            : CARDINAL;
    NewWeeksBeginOn     : CARDINAL;
    NewEndDateStyle     : AnEndDateStyle;
    i,j                 : CARDINAL;
    OldWeeksBeginOn,
    OldStartingMonth    : CARDINAL;
    OldEndDateStyle     : AnEndDateStyle;
    SaveDate            : ABigTime;
    TimeInfo            : ATimeInfo;
    FormValue           : ARRAY [0..5] OF AFieldValue;
    Changed             : BOOLEAN;         (* did the form change anything? *)

BEGIN
    OldStdDay  := TimeTable.StdDayTics * SMU;   (* 21-Nov-90 RSC *)
    OldStdWeek := TimeTable.StdWeek;
    OldSMUPH   := SMUPH;

    FormValue[0].RealValue := FLOAT(OldStdDay) / 60.0;  (* 21-Nov-90 RSC *)
    FormValue[1].CardValue := OldStdWeek;
    FormValue[2].CardValue := WeeksBeginOn;             (* 3/24/87 EGK *)

    NEW(FormValue[3].CharValue);                        (* 3/24/87 EGK *)
    GetStartingMonth(OldStartingMonth);
    CtoMonth(OldStartingMonth,FormValue[3].CharValue^);
    OldWeeksBeginOn := WeeksBeginOn;

    i := 0;
    LOOP
        CASE i OF
         0  :   j := 60;
        |1  :   j := 30;
        |2  :   j := 15;
        |3  :   j := 6;
        |4  :   j := 5;
        |5  :   j := 1;
        ELSE 
            ErrorPhrase(0);
        END;
        IF (j <= SMU) THEN
           EXIT;
        END;
        INC(i);
    END;
    IF (j < SMU) THEN           (* 2/3/88 EGK *)
        DEC(i);
    END;

    FormValue[4].CardValue := i;
    FormValue[5].CardValue := ORD(EndDateStyle); (* RSC 10/8/87 *)
    OldEndDateStyle := EndDateStyle;

    Changed   := FALSE;                                      (* 22-May-91 *)

    IF (DoForm(0,GanttWEnd,maxcol,maxrow-1,8,TRUE,FormValue,CheckCalendarForm)=ExitKey) THEN

        CASE FormValue[4].CardValue OF
         0  :   NewSMU := 60;
        |1  :   NewSMU := 30;
        |2  :   NewSMU := 15;
        |3  :   NewSMU := 6;
        |4  :   NewSMU := 5;
        |5  :   NewSMU := 1;
        ELSE 
            ErrorPhrase(0);
        END;

        NewSMUPH     := 60 DIV NewSMU;

        NewStdDay    := TRUNC(FormValue[0].RealValue * 60.0);   (* 21-Nov-90 RSC *)
        IF (NewStdDay < 1) THEN NewStdDay := 1; END;

        NewStdWeek   := FormValue[1].CardValue;
        IF (NewStdWeek < 1) THEN NewStdWeek := 1; END;

        NewEndDateStyle := VAL(AnEndDateStyle,FormValue[5].CardValue); (* RSC 10/8/87 *)

        NewWeeksBeginOn := FormValue[2].CardValue;       (* 3/19/87    EGK *)

        IF (StoD(FormValue[3].CharValue^, TimeInfo)) THEN END;  (* 3/27/87 EGK *)

        CalendarChanged := FALSE;

            (*  These changes will cause the calendar to be reorganized. *)
        IF (OldStdDay        <> NewStdDay)        OR          (* 01-Jul-91 *)
           (OldStdWeek       <> NewStdWeek)       OR
           (OldSMUPH         <> NewSMUPH)         THEN
            Changed := TRUE;
            CalendarChanged := TRUE;
        END;

            (* At this point, Changed means that the calendar needs 
               to be reorganized. *)

        IF (Changed) THEN

        (*
            CalendarTimeToBigTime(AsOfDate,TRUE,FirstDate);

                (* 12-Mar-91 TGS *)
            IF (NewSMU < SMU) THEN
                TempDate := FindLatestDate();
                IF AsOfDate > TempDate THEN
                    TempDate := AsOfDate;
                END;
                IF (TempDate DIV NewSMU) > (MAXCARDINAL DIV SMU) THEN
                    KillTime();
                END;
            END;

            SMU := NewSMU;
        *)
            AdjustSMUPH(OldSMUPH,NewSMUPH,
                        OldStdDay,NewStdDay,OldStdWeek,NewStdWeek);

            SetSMU( 60 DIV NewSMUPH ); (* RSC 21-Mar-89 *)

            TimeTable.StdDayTics := NewStdDay DIV SMU;   (* 27-Sep-91 EGK *)
            TimeTable.StdWeek    := NewStdWeek;

            RecomputeTable( TimeTable, FALSE );

        END;

            (*  This change doesn't require calendar reogranization.  *)

        IF (OldEndDateStyle <> NewEndDateStyle) THEN
            Changed := TRUE;
            EndDateStyle := NewEndDateStyle;
            UnSetState(Formatted);
            ConfigSaved := FALSE;
        END;

        IF (OldWeeksBeginOn  <> NewWeeksBeginOn) THEN 
            Changed := TRUE;
            WeeksBeginOn := NewWeeksBeginOn;
            NoteChange;                              (* Clears ConfigSaved. *)
            InitWeekNumberInfo();                    (* 18-Apr-90 MWP *)
        END;


        IF (OldStartingMonth <> TimeInfo.tiMonth) THEN
            Changed := TRUE;
            SetStartingMonth(TimeInfo.tiMonth);
            UnSetState(Formatted);
            ConfigSaved := FALSE;
        END;

        DisplayScheduleLight();     (* Schedule options may have changed. *)
    ELSE
        SetStartingMonth(OldStartingMonth);
    END;

    DISPOSE(FormValue[3].CharValue);

    RETURN Changed;

END InsideCalendarForm;



    (* Prologue -- Save the current cursor position and the
                   current settings for the standard hour, day
                   and week. *)

VAR
    OldAsOf : ABigTime;         (* 25-Jun-91 RSC  *)

PROCEDURE Prologue;
BEGIN
    OldStdDay         := TimeTable.StdDayTics * SMU;    (* 21-Nov-90 RSC *)
    OldStdWeek        := TimeTable.StdWeek;
    OldSMUPH          := SMUPH;
    OldQtrHoursInWeek := QtrHoursInWeek(TimeTable.WeekTable);

    CalendarTimeToBigTime(AsOfDate,TRUE,OldAsOf);

    BeforeCalendarChange();

END Prologue;


    (* Epilogue -- Adjust the tasks and resources and joins.
                   Move the cursor. *)


PROCEDURE Epilogue;

VAR
    NewQtrHoursInWeek   : CARDINAL;

BEGIN
    PreserveDurations := TRUE;
    IF (TimeTable.StdWeek            <> OldStdWeek) OR
       ((TimeTable.StdDayTics * SMU) <> OldStdDay) THEN (* 21-Nov-90 RSC *)

        IF (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL) THEN
            ConfirmConversions;
        END;
    END;

    NewQtrHoursInWeek := QtrHoursInWeek(TimeTable.WeekTable);
    IF (TimeTable.StdWeek            <> OldStdWeek)         OR
       ((TimeTable.StdDayTics * SMU) <> OldStdDay)          OR
       (NewQtrHoursInWeek            <> OldQtrHoursInWeek)  OR
       (SMUPH                        <> OldSMUPH)           THEN
        NoteChange;
        CheckForCalendarRoom;
    END;


        (* Convert all the start dates and durations back. *)
    RestoreTime;

    (* 22-Sep-89 RSC Put the resource rates back. *)
    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentBeforeChild, 9999,
                                         RescaleResource, NIL);

        (* And recheck that things aren't TOTALLY wierd. *)
    CheckPlausibleCalendar;

END Epilogue;




PROCEDURE CalendarForm;

VAR
    CalendarChanged         : BOOLEAN;

BEGIN
    RemoveDaysAsked := FALSE;

    Prologue;
    IF (InsideCalendarForm( CalendarChanged )) THEN
        IF (CalendarChanged) THEN
            Epilogue();
        END;
    END;
END CalendarForm;






PROCEDURE CalendarDays;
VAR
    NewTimeTable : POINTER TO ATimeTable;
    NewTime      : ADate;
    TimeInfo     : ATimeInfo;
    s            : ARRAY [0..255] OF CHAR;
BEGIN
    RemoveDaysAsked := FALSE;

    IF (Available( TSIZE(ATimeTable))) THEN
        NEW(NewTimeTable);
    ELSE
        ErrorPhrase(ModuleNumber + 30); (* "Not enough memory" *)
        RETURN;
    END;

    Prologue;
    (* SetState(Formatted); *)          (* 8/15/91 EGK *)
    NewTimeTable^ := TimeTable;
    TimeUtoT(CursorDay,TimeInfo);
    IF  (DoYears(NewTimeTable^,TimeInfo) = ExitKey) THEN
        TimeTable := NewTimeTable^;

            (* Check the form. *)
        NoteChange;
        CheckForCalendarRoom;

        IF (TtoTimeU(TimeInfo,CursorDay)) THEN;   (* Move Gantt cursor. *)
        END;
        Epilogue;
    ELSE
        DisplayMessage(ModuleNumber+5);   (*  "Ok, calendar not changed."  *)
    END;

    DISPOSE(NewTimeTable);

END CalendarDays;




TYPE
    AKeywordContext = RECORD
        StdDay,
        StdWeek     : CARDINAL;
    END;


(* Provide keywords for the resource prompt area strings.

    Preconditions:

        Context points to AKeywordContext, which has been filled in.

        This is being called from within the "MakeSubstitutions" proc,
        and obeys its conditions and rules.

    Keywords:

        D   # of hours in a DAY.
        W   # of days  in a WEEK.
*)
PROCEDURE GetKeywords( VAR Keyword  : ARRAY OF CHAR;
                       VAR KeyValue : ARRAY OF CHAR;
                           Context  : ADDRESS );
VAR
    MyContext       : POINTER TO AKeywordContext;

BEGIN

    MyContext := Context;

    WITH MyContext^ DO
        CASE CAP(Keyword[1]) OF
            "D" :   FormatAsAmount( FLOAT( MyContext^.StdDay ) / 60.0,  (* 21-Nov-90 RSC *)
                                    DefaultAmountFormat,
                                    KeyValue,
                                    5,      (* Size to fill *)
                                    0, 2,   (* Digits *)
                                    FALSE );
                    TrimRear( KeyValue );                      (* 01-Aug-91 *)

          | "W" :   CtoS( MyContext^.StdWeek, KeyValue );

        ELSE
        END;
    END;

END GetKeywords;








PROCEDURE CalendarHours;
VAR
    Selection               : CARDINAL;
    NewStdDay               : CARDINAL;
    NewStdWeek              : CARDINAL;
    Tics,
    Day, Count, i           : CARDINAL;
    NewTimeTable            : POINTER TO ATimeTable;
    Context                 : AKeywordContext;
    s                       : ARRAY [0..255] OF CHAR;
    MenuPrefix              : ARRAY [0..40] OF CHAR;
    MenuString              : ARRAY [0..60] OF CHAR;
    Title                   : ARRAY [0..40] OF CHAR;
    ErrorFlag               : BOOLEAN;
    Change                  : BOOLEAN;

BEGIN
    RemoveDaysAsked := FALSE;

    IF (Available( TSIZE(ATimeTable))) THEN
        NEW(NewTimeTable);
    ELSE
        ErrorPhrase( ModuleNumber + 30); (* "Not enough memory" *)
        RETURN;
    END;

    Prologue;

    (* SetState(Formatted); *)      (* 8/15/91 EGK *)
    NewTimeTable^ := TimeTable;

    ErrorFlag := FALSE;
    Change    := FALSE;

    REPEAT
        IF (DoWeek(NewTimeTable^) = ExitKey) THEN
            Change := TRUE;

            TimeTable := NewTimeTable^;
                (*  Compute average day length in hours. *)
            Tics := 0;
            Count := 0;
            FOR Day := Sun TO Sat DO
                i := TimeTable.WeekTable[Day].TicsInDay;
                IF (i > 0) THEN
                    INC(Tics,i);
                    INC(Count);
                END;
            END;
            IF (Tics = 0) THEN
                    (*  "Hey!  You gotta have SOME working hours!$$(Press [Esc] to continue.)" *)
                GetMessage(ModuleNumber+6,s);
                GetMessage(ModuleNumber+7,Title);  (* "No Work Hours" *)
                WarningBox(s,Title,NoHelp);
                ErrorFlag := TRUE;
            ELSE
                NewStdDay  := (Tics * SMU) DIV Count;   (* 21-Nov-90 RSC *)
                NewStdWeek := Count;
                ErrorFlag  := FALSE;

                IF ((NewStdDay  <> (TimeTable.StdDayTics * SMU)) OR
                    (NewStdWeek <> TimeTable.StdWeek)) THEN

                    GetMessage (ModuleNumber+10, s);    (* "The defaults have changed..." *)

                    WITH Context DO
                        StdDay  := NewStdDay;
                        StdWeek := NewStdWeek;
                    END;

                    MakeSubstitutions(s, HIGH(s), GetKeywords, ADR(Context));

                    GetMessage (ModuleNumber+13, MenuPrefix);   (* "Do you wish to make the change?" *)
                    GetMessage (ModuleNumber+14, MenuString);   (* "No, Yes" *)
                    GetMessage (ModuleNumber+15, Title);        (* "Change defaults" *)
                    Selection := 1;

                    IF (MultipleChoiceBox (s, Title, NoHelp, MenuPrefix,
                        MenuString, Selection)) AND (Selection = 2) THEN

                        AdjustSMUPH(SMUPH,SMUPH,OldStdDay,NewStdDay,OldStdWeek,NewStdWeek);

                        SetSMU(60 DIV SMUPH);   (* RSC 21-Mar-89 *)

                        TimeTable.StdDayTics := NewStdDay DIV SMU;  (* 9/27/91 EGK *)
                        TimeTable.StdWeek    := NewStdWeek;
                    END;
                END;
            END;
        ELSE
            DisplayMessage(ModuleNumber+8);   (*  "Ok, work hours not changed."  *)
        END;
    UNTIL (NOT ErrorFlag);


    DISPOSE(NewTimeTable);


    IF (Change) THEN
        NoteChange;
        CheckForCalendarRoom;
        Epilogue;
    END;


END CalendarHours;





PROCEDURE CheckForCalendarRoom;
VAR
    D1, D2 : ADate;
BEGIN
        (*  If the greater of either Today or the ending date of the
            latest task is more than 80% of the way through the calendar,
            then try to compress the calendar. *)
    D1 := AsOfDate;
    D2 := FindLatestDate();
    IF (D2 > D1) THEN
        D1 := D2;
    END;
    IF (D1 > ((MAXCARDINAL DIV 10) * 8) ) THEN
        KillTime;
    END;
END CheckForCalendarRoom;



END CalControl.

