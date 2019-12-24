IMPLEMENTATION MODULE TaskChange;

(*V7=TRACE*)

    (*
        Task Change - Edit a task record

            This module provides the ability to make changes to a task record
            by changing "columns" of data.  It deals with the same columns as
            are output by the "Captions" module.  For this reason, this module
            and its cousins are sometimes refered to as "AntiCaptions".


        Terminology:

            For this module, we view the Task Tree as if it were a giant TABLE
            of records, where each TASK is a ROW in the table.  Each FIELD in
            a task record is a COLUMN in the table.

            A Column HEADING is the formal name a column goes by.  This is the
            name found in a Lotus, DBase, or CSV file.  This heading is
            translated into a ColumnID, a "magic number" used to identify the
            column.  Note that some exporters, notably DBase, may translate
            the official formal name into a new name that is more compatible
            with the external program.  It is the importer's job to translate
            those names BACK into the "official" formal name.


        Procedure Overview:

            GetTaskColumnID()   Given a column's formal name, return the
                                internal Column ID.

            BeginTaskEdit()     Start the editing of a task.

            DigestTaskString()  Change a text string into an internal format.

            ChangeTaskColumn()  Change the value of a column.

            EndTaskEdit()       End the editing of a task, and commit the
                                changes if there were no serious errors.

            SanitizeTask()      Rigorously check the task, and make sure that
                                it is complete and consistant.  Called at the
                                end of importing all files.  Takes whatever
                                measures needed to insure the sanity of the
                                internal model.

        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Undo:

            This module does not use Undo.  It is the job of clients to
            back out records deemed not valid.


        Related Modules:

            TaskAcquire  is used to find the task record to be edited.
            RsrcEdit     edits resource records.
            AssEdit      edits assignment records.
            EdgeEdit     edits edge records.


        Modification History:

         (early history move to the end of the file.

         1-Jun-90  RSC  Fixed case where start status --> DONE.
                        Bug # 2196.
        28-Jun-90  AJL  Import UsesCostTracking so above fix will compile.
        20-Jul-90  AJL  Import NumberOfCodingFields.
        10-Aug-90  RSC  Update SummAssignments parameters.
        12-Sep-90  CL   Rename the former Plan.Dates.FixedStart field
                        to UserEnteredStartDate and change its format
                        from ADate to ABigTime.
        13-Sep-90  RSC  Allow "Assignment Driven" as a task type.
        14-Sep-90 PFG   Added support for new Splitting Rule column.
        17-Sep-90 PFG   Changed FixedStartColumn to UserEnteredStartColumn.
                        Added UserEnteredEndColumn, SupposedToStartColumn,
                        LateIndStartColumn, LateIndEndColumn.
        27-Sep-90 DSL   Set PercentAchived to 100 if StartStatus = DoneS.
                        In EndTaskEdit. Bug report #3066
        28-Oct-90 AJL   Add AllowSlackColumn and RequiredStartColumn.
                        Rearrange the way that enumerated types are parsed
                        so that all the values of the enumeration are in a
                        single phrase.  Add the procedure DoEnumeration and
                        remove most of the former more specific procs.
         1-Nov-90 CL  - Rename SuppressSlack to ForceCritical,
                        ResourceDriven to EffortDriven.
*)
(*
        14-Nov-90 RSC - Applied these changes:
        13-Jul-90  WKH/ You're gonna love this one.  It was possible to import
                   LAA/ baseline information and have it corrupted.                   is two-fold.  1) the what's been seen bits weren't 
                   RSC  
                        The problem what that the WhatsBeenSeen bits were not
                        correctly being used in EndTaskEdit.  Adjustments
                        have been made, but there seems to be a larger hole
                        in importing period.

                        Also, defer the setting of the BaselineExists flag
                        in the task record until EndTaskEdit(used to be done
                        in ChangeTaskRecord) so we can tell if there used
                        to be a baseline with valid information or if that
                        data is just garbage.
        24-Jul-90  LAA  Tasks without existing baselines were being given
                        baselines during import, even though there was no
                        baseline info coming in for that task.  It was a
                        consequence of the baselines of OTHER tasks!  The
                        new rule is that, if none of (BslnStartDate, 
                        BslnEndDate, BslnDuration) come in to the task, the
                        baseline exists flag will not be set.  Massively
                        changed the processing in EndTaskEdit for baseline
                        stuff!!!!
        25-Jul-90  WKH  Seems like we're here alot these days!!  Well, it
                        seems that in gantt, we use the fixedstart field of a
                        task regardless of its fixation type.  This may be
                        correct, but I'm not sure.  The problem we were 
                        having was with baseline bars that were chronologically
                        before plan bars not showing up after import.  So
                        we just make the fixed start equal to the early start
                        and life should be wonderful....   Patty, please 
                        redo all of this and make our lives better....

        23-Sep-90  RSC  Upon change of TaskType to FixedDate, make sure that
                        DurationMethod changes to DurationDriven.  Bug
                        number 3115.

                        Bug 3116: Summary tasks loose their effort numbers
                        when edited.  This seems to be a curious side effect
                        of what was being done when a task had no resource
                        assignments, coupled with the task being recalced
                        in BeginTaskEdits (MWP's 29-Sep-89 change).

        14-Nov-90 RSC - END OF CHANGES FROM 4.0.3.

                        Also, apply fixed task defaults,
                        clean up date normalizations.
        19-Dec-90 TGS   Future ASAP/ALAP tasks do not set NoSoonerStart or
                        NoLaterStart.
         8-Jan-91 AJL  -When not using CostTracking (explicit entry of 
                        effort and costs spent) we infer spent costs
                        based on percent achieved.
                       -Setting a percent in the range > 0 and < 100 will
                        set the start status to StartedS unless the start
                        status was explicitly seen, or cost tracking is
                        on.
         8-Jan-91 TGS   As part of SanitizeTasks, make sure Spent Efforts
                        do not exceed Estimated Effort for EffortDriven tasks.
        22-Jan-91 RSC   Removed spurious import of LongDurationToString.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
        29-Apr-91 TGS   Change call to CheckTaskEfforts.
        30-Apr-91 TGS   SanitizeTask sets Split/Delay to Split if StartStatus
                        is StartedS or DoneS and the task is duration-driven.
        10-May-91 TGS   Went to rename a couple of column identifiers, which
                        turned out to be unused. "Where there's one, there's
                        another"; I got rid of all I could find.
        28-Jun-91 LAA   Commented out the line which forces a task with no
                        assignments to be duration driven.  This was causing
                        spreadsheet editing to have different effects than
                        the task form, when all resources were removed from
                        a task.  Bug #4605.
        22-Jul-91 AJL   Make sure that updating a start status affects
                        percent achieved, and visa versa.
        13-Aug-91 AJL   Change passed parameter to UpdateEffortToMatchRatio.
        20-Aug-91 EGK   Put in more support for UserEnteredEndColumn.  We
                        weren't properly updating the EarlyEnd column from it
                        or vice-versa, and we weren't checking it against the
                        start date.
        29-Aug-91 EGK   Undid Larry's fix of 28-Jun-91.  By my estimation,
                        recalc cannot handle an effort-driven task with no
                        resources (see bug #5046 if you don't believe me),
                        so neither the task form nor the spreadsheet should
                        allow it.  With this change, the spreadsheet will set
                        the task type to DurationDriven if it has no
                        resources.
        20-Sep-91 TGS   Task defaults were not being set correctly when task
                        type changed to FixedDate. I copied what the task
                        form was doing, since it seems to work okay.
                        Refresh UserEntered dates with EarlyStart/End dates
                        when TaskType is changed to Fixed or StartStatus is
                        no longer FutureS. This duplicates behavior of task
                        form, though the steps are taken in a different
                        order. Both fixes are for Bug 5163.
        25-Sep-91 LAA   Patty had changed the column number of the WBSErrors
                        column back to 123, as it had been in V.4, in order
                        to minimize the fixups of layouts (see the note in
                        TaskColNumbers dated 16-Aug-91).  Unfortunately, this
                        module assumed a relationship between the column
                        number of the WBSErrors column and the coding columns.
                        I fixed it so there is no longer a relationship.
                        Bug #5196.
        27-Sep-91 LAA   Bug #5245.  If the user edits the UserEnteredStartDate
                        on the spreadsheet, the UserEnteredEndDate was not
                        being updated, therefore when a recalc occured the
                        start date change was being lost.  
        26-Feb-92 AJL  -Entry of to go effort on an effort driven task, if
                        cost tracking is off, will recompute the percent achieved
                        to match.
                       -Made the effect of a change to start status on
                        user-entered dates work consistently whether the user
                        entered the start status explicitly or implicitly
                        by a change to achieved percent.

        09-Mar-92 LAA   Commented out the part of EndTaskEdit which changes
                        the link status.  This was causing bug #5387, where
                        the link status was being changed unnecessarily.  It
                        seems that this code isn't really necessary, since
                        the spreadsheet doesn't go through this code, and
                        the importers don't allow you to edit the "summarizes"
                        info anyway.
    *)





FROM Allocs         IMPORT
    (* CONST *)             WBSLine, OBSLine, AUXLine,    FirstOtherCodingLine,
                            WBSLen,  OBSLen,  AUXLen,
    (* TYPE *)              ATaskPtr,        AFixType,    AStartStatus,
                            ADurationMethod, ATaskFlag,   AnAssignmentSummary,
                            ATaskStatus,     ATaskFilter, ATaskStatusSet,
                            ATaskFlagSet,    ARollupStatus, ASplittingRule,
                            ADateBlock,
    (* PROC *)              GetCodingField, SetCodingField;

FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentArray, AnAssignmentRecord,
                            AnAssignmentAttribute;

FROM CalShift       IMPORT
    (* VAR *)               TimeSheet;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord, AColumnInfoChoice,
                            AColumnDataField,  ASetOfColumnDataFields,
    (* PROC *)              GetColumnInfo;

FROM Changer        IMPORT
    (* VAR *)               UsesCostTracking;

FROM ChartControl   IMPORT
    (* TYPE *)              AChartState,
    (* PROC *)              UnSetState;

FROM Dialog         IMPORT
    (* PROC *)              FatalError, ErrorPhrase;

FROM Duration       IMPORT
    (* PROC *)              SubtractWorkingTime, FindDuration,
                            AddWorkingTime;

FROM EditCommon     IMPORT
    (* PROC *)              GetAColumnID, DigestAString, AjustName,
    (* PROC *)              DigestAIntString;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM EffDone                    IMPORT
    (* PROC *)                     UpdateEffortToMatchRatio;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle,
    (* PROC *)              ReleaseUnchangedObject, ReleaseObject,
                            LockObjectArray;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable, AnAskAlterBaselineProc, LogAnError;

FROM IntFileIO      IMPORT
                            AnIntDataRecord;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear,  Copy,     SetLengthOf,
                            StringsEqual, SetString, LengthOf, Upshift,
                            Procustes, ConcatS, ConcatLS, Compare;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat;

FROM RsrcCalc       IMPORT
    (* PROC *)              ComputeTaskNodeCosts,
                            SummTaskNodeAmounts, SummAssignments;

FROM RsrcMod        IMPORT
    (* TYPE *)              ACostStyle, AResourceType;

FROM SegWords       IMPORT
    (* PROC *)              WordNumber;

FROM Schedule       IMPORT
    (* VAR *)               ScheduleSaved, FixedDateRules;

FROM StatusChange   IMPORT
    (* TYPE *)              AStatusDialogResponse,
    (* PROC *)              CheckStatusChange, CheckTaskEfforts;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, TSIZE, ADR;

FROM TaskColNumbers IMPORT
    (* CONST *)             TaskNameColumn,             NotesColumn,
                            EarlyStartColumn,           EarlyEndColumn,
                            DurationColumn,             DurationDays,
                            DurationWeeks,              DurationMonths,
                            TotalEffort,                EffortDays,
                            EffortWeeks,                EffortMonths,
                            AUXColumn,                  WBSColumn,
                            OBSColumn,                  TaskTypeColumn,
                            StartStatusColumn,          DurationMethodColumn,
                            PercentAchieved,            PriorityColumn,
                            UserEnteredStartColumn,     LateStartColumn,
                            LateEndColumn,              LateTotalStartColumn,
                            LateTotalEndColumn,         TotalSlackColumn,
                            Highlight1Column,           Highlight2Column,
                            Highlight3Column,           PredSuccColumn,
                            BaselineDuration,           BaselineDollars,
                            BaselineEffort,
                            BaselineStartDate,          BaselineEndDate,
                            BaselineBCWS,               CompletedEffort,
                            ToGoEffort,                 AchievedDollars,
                            SplittingRuleColumn,    (* 14-Sep-90 PFG *)
                            EffortHours,                DurationHours,
                            ToGoDuration,                       (* 26-Feb-92 AJL *)

                            SupposedToStartColumn,              (* 17-Sep-90 PFG *)
                            UserEnteredEndColumn,               (* 17-Sep-90 PFG *)
                            LateIndStartColumn,                 (* 17-Sep-90 PFG *)
                            LateIndEndColumn,                   (* 17-Sep-90 PFG *)
                            AllowSlackColumn,
                            RequiredStartColumn,

                            CodingField1,               NumberOfCodingFields,
                            WBSErrors,                            (* 27-Aug-89 MWP *)

                            HighestRootColumn;

FROM TaskProtection IMPORT
    (* VARS *)              RecalcColumns, SortColumns;

FROM Text           IMPORT
    (* TYPE *)              AText,
    (* PROCS *)             TextExists, CreateText, AssignLine, Compress,
                            CopyLine,   DiscardText;

FROM Timei          IMPORT
    (* CONST*)              MaxDate,
    (* TYPE *)              ADurationUnit, ADate, ADuration,
                            ASetOfADurationUnit;

FROM TimeXlate      IMPORT
    (* PROC *)              CalendarTimeToBigTime, BigTimeToCalendarTime;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;

FROM WorkHours      IMPORT
    (* PROCS *)             RealTimeToDuration, RealTimeToWorkHours;

(*<TRACE
FROM Tracer IMPORT PrintString, EndTrace;
TRACE>*)


    (*<TRACE
VAR
    TraceS : ARRAY [0..100] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)








CONST
    MAXCARDINAL             = 65535;
    FMAXCARDINAL            = 65535.0;
    Zero                    = 0.0;
    Half                    = 0.5;
    One                     = 1.0;
    OneHundred              = 100.0;


    TLCaptionsModuleNumber  = 27300;  (* THIS IS SHARED WITH TLCAPTIONS!! *)



TYPE
    AGlobalContext         = RECORD
                                TaskNode        : ATreeNode;
                                ContextReady    : BOOLEAN;
                                EditsOK         : BOOLEAN;
                                StartStatusSeen : BOOLEAN;
                                AchievedSeen    : BOOLEAN;
                                ToGoEffortSeen  : BOOLEAN;
                                AlterBaseline   : AnAskAlterBaselineProc;
                                PImportTable    : POINTER TO AImportTable;
                                StateInfo       : ATaskEditContext;
                             END;

VAR
    GlobalContext    : AGlobalContext;
    NilString        : ARRAY [0..1]  OF CHAR;
    TempBsLnDuration : ADuration;
    TempBsLnEffort   : REAL;
    TempDurScale     : ADurationUnit;
    TempEffScale     : ADurationUnit;
    BaseChange       : BOOLEAN;



(*
    Get Task Info

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
PROCEDURE GetTaskInfo(     ColumnID      : CARDINAL;
                           InfoChoice    : AColumnInfoChoice;
                           Length        : CARDINAL;
                       VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
VAR
    NilTask : ATaskPtr;
BEGIN
    IF (ColumnID > HighestRootColumn) THEN
        RETURN FALSE;
    ELSE
        NilTask := ATaskPtr(NIL);
        GetColumnInfo( ATreeNode(NIL), NilTask,
                       ColumnID,       InfoChoice,
                       Length,         InfoValue );
        RETURN TRUE;
    END;
END GetTaskInfo;



(*
    Get Task Column ID

        Preconditions
                        > "ColumnName" is an LString containing the FORMAL
                          NAME of the task column (The same name that is
                          exported by Captions).  The caller must resolve
                          any differences between the name read in from a
                          file and the "official" formal name.  For example,
                          DBase translates some charactors.

        Postconditions
                        > Returns TRUE if the ColumnName is a known task
                          column name, or FALSE if it is unknown.

                        > ColumnID is the internal number to use for
                          changing the data, if TRUE is returned.
*)
PROCEDURE GetTaskColumnID( VAR ColumnName       : ARRAY OF CHAR;
                           VAR ColumnID         : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN GetAColumnID( GetTaskInfo, ColumnName, ColumnID );
END GetTaskColumnID;



(*
    Begin Task Edit

        Preconditions
                        > No task is currently being edited (close off an edit
                          with EndTaskEdit)

                        > RowNode is the TreeNode for the existing task
                          to be edited.  It must not be NIL.

                        > ErrorHandler is the procedure to be called when an
                          edit error occurs.

        Postconditions
                        > Task is ready to be edited.
*)
PROCEDURE BeginTaskEdit(     RowNode          : ATreeNode;
                             LErrorHandler    : AnErrorHandlerProc;
                             LHandlersContext : ADDRESS;
                             LAlterBaselineProc :  AnAskAlterBaselineProc;
                             LImportTable       : ADDRESS );
VAR
    TaskPtr         : ATaskPtr;
    LocalBaseLine,
    LocalJunk,
    LocalCompleted,
    LocalToGo       : AnAssignmentSummary;



    PROCEDURE Max( R1, R2 : REAL ) : REAL;
    BEGIN
        IF (R1 > R2) THEN RETURN R1; ELSE RETURN R2; END;
    END Max;


BEGIN
    WITH GlobalContext DO
        TaskNode          := RowNode;
        ContextReady      := (TaskNode <> ATreeNode(NIL));
        EditsOK           := TRUE;

        StartStatusSeen   := FALSE;
        AchievedSeen      := FALSE;
        ToGoEffortSeen    := FALSE;

        AlterBaseline     := LAlterBaselineProc;
        PImportTable      := LImportTable;

        WITH StateInfo DO
            ErrorHandler          := LErrorHandler;
            HandlersContext       := LHandlersContext;
            NeedsRecalc           := FALSE;
            NeedsSort             := FALSE;
            WhatsBeenSeen         := AWhatsBeenSeenSet{};

            DurationUnitSeen      := ADurationUnitSet{};               (* 10-Jul-89 MWP *)
            EffortUnitSeen        := AEffortUnitSet{};                 (* 10-Jul-89 MWP *)

                (* 23-Sep-90 RSC This seems to not be good.  Why do it here??
                *)
(* ***********ComputeTaskNodeCosts( RowNode );                           (* 29-Sep-89 MWP *)*)

            SummTaskNodeAmounts( RowNode, FALSE,
                                 LocalCompleted, LocalToGo );

            SummTaskNodeAmounts( RowNode, TRUE,
                                 LocalJunk, LocalBaseLine );

            TaskPtr := RowNode^.Methods^.LockFlexStorDataObject( RowNode );

            WITH TaskPtr^ DO
                KidsToGoSummary.Time        := Max ( ToGoSummary.Time -
                                                     LocalToGo.Time, Zero );

                KidsCompletedSummary.Time   := Max ( CompletedSummary.Time -
                                                     LocalCompleted.Time, Zero );

                KidsToGoSummary.Amount      := Max ( ToGoSummary.Amount -
                                                     LocalToGo.Amount, Zero );

                KidsCompletedSummary.Amount := Max ( CompletedSummary.Amount -
                                                     LocalCompleted.Amount, Zero);


                KidsBaseLineSummary.Time    := Max ( BaseLineSummary.Time -
                                                     LocalBaseLine.Time, Zero);

                KidsBaseLineSummary.Amount  := Max ( BaseLineSummary.Amount -
                                                     LocalBaseLine.Amount, Zero);

                TempDurScale                := scale;
                TempEffScale                := EffortScale;
                IF (NOT (BaseLineExists IN TaskFlags)) THEN
                    BaseLine.Dates := Plan.Dates;
                END;
                TempBsLnDuration := (BaseLine.Dates.EarlyEnd 
                                   - BaseLine.Dates.EarlyStart);
            END;

            RowNode^.Methods^.UnlockUnchangedDataObject( RowNode );
        END;
    END;
    BaseChange := FALSE;                                       (* 24-Jul-90 *)
END BeginTaskEdit;








(*
    Digest Task String

        Convert a text string into the internal data record needed by
        "ChangeTaskColumn".

        Preconditions
                        > "ColumnID" is a valid column id.

                        > "TextString" is the string to be digested into
                          "ColumnData".  It is not modified (VAR only for
                          efficiency).

                        > "Amount Format" is the real number format to use
                          in analizing REAL numbers.  It is not altered.
                          VAR is just for efficiency.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty text string.
                          This is not allowed for all columns.

        Postconditions
                        > "ColumnData" is the data to be applied to the task.

                        > The text is checked within the context of the
                          column in question, and the "ColumnData" record
                          is filled in appropriately.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is fixable can be fixed,
                          at the descresion of the error handler.  A fix that
                          means "Ignore" will return ColumnData filled out as
                          if an empty string was passed.

                        > Returns TRUE if there were no formatting errors,
                          FALSE if there were, and were not fixed.
*)
PROCEDURE DigestTaskString (     ColumnID     : CARDINAL;
                            VAR TextString   : ARRAY OF CHAR;
                            VAR AmountFormat : AnAmountFormat;
                            VAR ColumnData   : AColumnDataRecord ;
                                LErrorHandler    : AnErrorHandlerProc;
                                LHandlersContext : ADDRESS          ) : BOOLEAN;
BEGIN

     GlobalContext.EditsOK := DigestAString( GetTaskInfo,  ColumnID,
                                             TextString,   AmountFormat,
                                             ColumnData,
                                             LErrorHandler,
                                             LHandlersContext );

     RETURN GlobalContext.EditsOK;

END DigestTaskString;


PROCEDURE DigestIntTaskString (     ColumnID         : CARDINAL;
                                    Type             : CARDINAL;
                                VAR Data             : AnIntDataRecord;
                                VAR AmountFormat     : AnAmountFormat;
                                VAR ColumnData       : AColumnDataRecord ;
                                    LErrorHandler    : AnErrorHandlerProc;
                                    LHandlersContext : ADDRESS          ) : BOOLEAN;
BEGIN

   GlobalContext.EditsOK := DigestAIntString( GetTaskInfo,
                                              ColumnID,
                                              Type,
                                              Data,
                                              AmountFormat,
                                              ColumnData,
                                              LErrorHandler,
                                              LHandlersContext );

   RETURN GlobalContext.EditsOK;

END DigestIntTaskString;












(*
    Change Task Column

        Preconditions
                        > A Task is being edited (BeginTaskEdit has been
                          called).

                        > "ColumnID" is a valid column id.

                        > "ColumnData" is the data to be applied to the task.

                        > Some columns may allow a "Null" value.  An example
                          of this is the StartDate column, which allows
                          the start date to TEMPORARILY be set to "null".
                          This is handled here by an empty "DataFields" inside
                          "ColumnData".  This is not allowed for all columns.

        Postconditions
                        > The data is checked within the context of the
                          column in question, and the changes are applied,
                          except as noted below.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is not fixable, or that the
                          error handler decides not to fix, will cause FALSE
                          to be returned.

                        > If TRUE is returned, it is implied that no errors
                          have yet been detected.  A call to EndTaskEdit MIGHT
                          succeed, unless other errors are encountered.

                        > If FALSE is returned, no further edits will
                          be accepted (further calls to "ChangeTaskColumn"
                          will return FALSE).  The changes should be ABORTED
                          by the caller.
*)
PROCEDURE ChangeTaskColumn(     ColumnID    : CARDINAL;
                            VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
VAR
    TaskPtr      : ATaskPtr;
BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) AND  (* Ignore? *)
           (EditsOK)                                     THEN

            TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

            EditsOK := ChangeTaskRecord( ColumnID,
                                         TaskPtr,
                                         ColumnData,
                                         StateInfo,
                                         AlterBaseline,
                                         PImportTable );

            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
        END;
    END;

    RETURN GlobalContext.EditsOK;

END ChangeTaskColumn;




PROCEDURE PrepareCustomerStringForCompares( VAR s : ARRAY OF CHAR );
BEGIN
    TrimRear( s );
    TrimFront(s );
    Upshift(  s );
END PrepareCustomerStringForCompares;

    (* Process a comparison string for abbreviated names.  In other words,
       If the customer types "AL" it should match "ALAP".
       RSC 26-May-89.
    *)

PROCEDURE AjustTo( VAR AjustThis, ToThis : ARRAY OF CHAR );
BEGIN
    Upshift( AjustThis );
    IF (LengthOf( AjustThis ) > LengthOf( ToThis )) THEN
        SetLengthOf( AjustThis, LengthOf( ToThis ));
    END;
END AjustTo;

PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber, ReturnValue );
END GetMessageWord;





    (* MatchWordFromPhrase -- See if the source string matches any
                              of the words in the phrase.  If it
                              does, return the index of the word.
                              Words are numbered starting with 1.
    *)


PROCEDURE MatchWordFromPhrase(     SourceString : ARRAY OF CHAR;
                                   PhraseNumber : CARDINAL;
                               VAR WordIndex    : CARDINAL ) : BOOLEAN;
VAR
    S,S2  : ARRAY [0..99] OF CHAR;
BEGIN
    PrepareCustomerStringForCompares( SourceString );
    WordIndex := 1;
    LOOP
        GetMessage( PhraseNumber, S2 );
        WordNumber( S2, WordIndex, S );
        IF (LengthOf(S) = 0) THEN
            RETURN FALSE;
        END;
        AjustTo( S, SourceString );
        IF (StringsEqual( S, SourceString )) THEN
            RETURN TRUE;
        END;
        INC(WordIndex);
    END;
END MatchWordFromPhrase;







(*
    Change Task Record

        THIS PROCEDURE IS FOR INTERNAL USE BY THE EDIT SUBSYSTEM, AND IS NOT
        FOR CLIENTS TO USE.

        Use "ChangeTaskColumn" instead.

        Preconditions
                        > "ColumnID" is a valid task column id.

                        > "ColumnData" is the data to be applied to the task.

                        > "TaskPtr" is the task to change.

                        > "Context" is the information saved from field to
                          field while editing one task.

                        > Some columns may allow a "Null" value.  An example
                          of this is the StartDate column, which allows
                          the start date to TEMPORARILY be set to "null".
                          This is handled here by an empty "DataFields" inside
                          "ColumnData".  This is not allowed for all columns.

        Postconditions
                        > The data is checked within the context of the
                          column in question, and the changes are applied,
                          If TRUE is returned.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is not fixable, or that the
                          error handler decides not to fix, will cause FALSE
                          to be returned.  Otherwise, TRUE is returned.

    IMPLEMENTATION NOTES:

        Why separate this procedure from "ChangeTaskColumn"?

            Because TaskAcquire needs to set default columns up for a task.
            TaskAcquire creates a temporary task node and fills that node in
            with whatever columns the client wants.  When a new task is created
            in TaskAcquire, the default task is copied to the new task.

            1) We don't want the side effects of Begin/End, which tend to drasticly
               change the task based on the few columns input.  (For example,
               maybe you just have a default end date and ALAP fixation.  Passing
               this through EndTaskEdit would wipe out the end date.)

            2) We allow changing only one task at a time, thus ONE global context,
               but you can change default columns simultaniously with changing
               "real" tasks.

*)
PROCEDURE ChangeTaskRecord(     ColumnID      : CARDINAL;
                                TaskPtr       : ATaskPtr;
                            VAR ColumnData    : AColumnDataRecord;
                            VAR Context       : ATaskEditContext;
                            VAR AlterBaseline : AnAskAlterBaselineProc;
                                PImportContext: ADDRESS
                           ) : BOOLEAN;
VAR
    PImport     : POINTER TO AImportTable;
    WhichField,
    i           : CARDINAL;
    Junk        : BOOLEAN;
    EditsOK     : BOOLEAN;
    TempDuration: ADuration;
    TempTime    : ADurationUnit;
    TempReal    : REAL;
    TempCard    : CARDINAL;
    TempString  : ARRAY [0..255] OF CHAR;
    s, s1       : ARRAY [0..99] OF CHAR;
    TempBoolean : BOOLEAN;


    PROCEDURE Assume( Field : AColumnDataField ) : BOOLEAN;
    VAR
        s : ARRAY [0..255] OF CHAR;
    BEGIN

        IF (NOT (Field IN ColumnData.DataFields)) THEN
            Junk      := Context.ErrorHandler( SeriousError,
                                               DataFieldsWrong,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            EditsOK := FALSE;
        END;

        RETURN EditsOK;

    END Assume;



    PROCEDURE DoString( VAR s : ARRAY OF CHAR; MaxSize : CARDINAL );
    BEGIN
        IF (Assume( StringInUse )) THEN
            WITH ColumnData DO
                TrimFront( StringValue );
                TrimRear(  StringValue );
                IF (LengthOf( StringValue ) > MaxSize) THEN
                    EditsOK := Context.ErrorHandler( FormatError,
                                                     TextTruncation,
                                                     ColumnID,
                                                     NilString,
                                                     Context.HandlersContext );
                    Procustes( StringValue, MaxSize );
                END;
                Copy( StringValue, s );
            END;
        END;
    END DoString;



    PROCEDURE DoNotes( VAR Text : AText );
    BEGIN
        IF (Assume( StringInUse )) THEN
            IF (NOT TextExists( Text )) THEN
                Text := CreateText();
            END;
            IF (NOT TextExists( Text )) THEN
                EditsOK := FALSE;
            ELSE
                EditsOK := AssignLine( ColumnData.StringValue, 0, Text );
                Compress( Text );
            END;

            IF (NOT EditsOK) THEN
                Junk := Context.ErrorHandler( SystemError,
                                              NoMemoryForEdit,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
            END;
        END;
    END DoNotes;


    PROCEDURE DoDate( VAR TheDate : ADate );
    BEGIN
        IF (Assume( DateInUse )) THEN
            TheDate             := ColumnData.DateValue;
        END;
    END DoDate;


    PROCEDURE DoBoolean( VAR TheBoolean : BOOLEAN );
    BEGIN
        IF (Assume( BooleanInUse )) THEN
            TheBoolean :=  ColumnData.BooleanValue;
        END;
    END DoBoolean;


    PROCEDURE RtoC( R : REAL; VAR C : CARDINAL ) : BOOLEAN;
    BEGIN
        IF (R > FMAXCARDINAL) OR (R < Zero) THEN
            EditsOK := Context.ErrorHandler( FormatError,
                                             NumberOutOfRange,
                                             ColumnID,
                                             NilString,
                                             Context.HandlersContext );
            IF (R < Zero) THEN
                C := 0;
            ELSE
                C := MAXCARDINAL;
            END;
        ELSE
            C := TRUNC( R + 0.5 );  (* Round *)
        END;

        RETURN EditsOK;

    END RtoC;


    PROCEDURE DoDuration( VAR Unit : ADurationUnit ) : BOOLEAN;            (* 10-Jul-89 MWP *)
    VAR
        Leading, Trailing : ARRAY [0..25] OF CHAR;
        ok, UseDuration      : BOOLEAN;

    BEGIN
       ok := TRUE;
       UseDuration := TRUE;

        IF (Assume( RealInUse )) THEN
            CASE Unit OF
                Minutes  :                                        (* 12-Sep-89 MWP *)

             |  Hours    :
                      INCL( Context.DurationUnitSeen, DurHours );
             |  Days     :
                   IF ( DurHours IN Context.DurationUnitSeen ) THEN
                      UseDuration := FALSE;
                   ELSE
                      INCL( Context.DurationUnitSeen, DurDays );
                   END;
             |  Weeks    :
                   IF ( ( Context.DurationUnitSeen *
                          ADurationUnitSet{DurHours..DurDays})
                          <> ADurationUnitSet{} ) THEN
                      UseDuration := FALSE;
                   ELSE
                      INCL( Context.DurationUnitSeen, DurWeeks );
                   END;
             |  Months   :
                   IF ( ( Context.DurationUnitSeen *
                          ADurationUnitSet{DurHours..DurWeeks})
                          <> ADurationUnitSet{} ) THEN
                      UseDuration := FALSE;
                   ELSE
                      INCL( Context.DurationUnitSeen, DurMonths );
                   END;
             |  Years    :
                   IF ( ( Context.DurationUnitSeen *
                          ADurationUnitSet{DurHours..DurMonths})
                          <> ADurationUnitSet{} ) THEN
                      UseDuration := FALSE;
                   ELSE
                      INCL( Context.DurationUnitSeen, DurMonths );
                      Unit := Months;
                      ColumnData.RealValue := ColumnData.RealValue * 12.0;
                   END;

            ELSE
                ok := FALSE;
                Junk := Context.ErrorHandler( FormatError,
                                              EnumerationWrong,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
            END;

            IF ( ok ) THEN
                IF ( UseDuration ) THEN
                   TaskPtr^.duration   := RealTimeToDuration( ColumnData.RealValue,
                                                              Unit );
                   TaskPtr^.scale := Unit;
                   INCL( Context.WhatsBeenSeen, DurationSeen );
                END;
            END;
        ELSE
            ok := FALSE;
        END;

        RETURN ( ok );

    END DoDuration;



    PROCEDURE DoEffort ( VAR Unit : ADurationUnit;
                             Calc : BOOLEAN ) : BOOLEAN;
    VAR
        ok, UseDuration        : BOOLEAN;
    BEGIN
       ok          := TRUE;
       UseDuration := TRUE;

        WITH TaskPtr^ DO
            IF (Assume( RealInUse )) THEN

                CASE Unit OF
                    Minutes  :                                     (* 12-Sep-89 MWP *)

                 |  Hours    :
                       IF ( EffHours IN Context.EffortUnitSeen ) THEN
                          UseDuration := FALSE;
                       ELSE
                          INCL( Context.EffortUnitSeen, EffHours );
                       END;
                 |  Days     :
                       IF ( EffHours IN Context.EffortUnitSeen ) THEN
                          UseDuration := FALSE;
                       ELSE
                          INCL( Context.EffortUnitSeen, EffDays );
                       END;
                 |  Weeks    :
                       IF ( ( Context.EffortUnitSeen *
                              AEffortUnitSet{EffHours..EffDays})
                              <> AEffortUnitSet{} ) THEN
                          UseDuration := FALSE;
                       ELSE
                          INCL( Context.EffortUnitSeen, EffWeeks );
                       END;
                 |  Months   :
                       IF ( ( Context.EffortUnitSeen *
                              AEffortUnitSet{EffHours..EffWeeks})
                              <> AEffortUnitSet{} ) THEN
                          UseDuration := FALSE;
                       ELSE
                          INCL( Context.EffortUnitSeen, EffMonths );
                       END;

                 |  Years    :
                       IF ( ( Context.EffortUnitSeen *
                              AEffortUnitSet{EffHours..EffMonths})
                              <> AEffortUnitSet{} ) THEN
                          UseDuration := FALSE;
                       ELSE
                          INCL( Context.EffortUnitSeen, EffMonths );
                          Unit := Months;
                          ColumnData.RealValue := ColumnData.RealValue * 12.0;

                       END;
                ELSE
                   ok := FALSE;
                   Junk := Context.ErrorHandler( FormatError,
                                                 EnumerationWrong,
                                                 ColumnID,
                                                 NilString,
                                                 Context.HandlersContext );
                END;

                IF ( ok ) THEN
                     IF ( UseDuration ) THEN
                         IF ( Calc ) THEN                             (* 24-Aug-89 MWP *)
                            ToGoSummary.Time := RealTimeToWorkHours( ColumnData.RealValue,
                                                                     Unit )
                                                - CompletedSummary.Time;
                         ELSE
                            ToGoSummary.Time := RealTimeToWorkHours( ColumnData.RealValue,
                                                                     Unit );
                         END;
                         EffortScale := Unit;                        (* 8-Sep-89 MWP *)
                     END;
                END;
            ELSE
                ok := FALSE;
            END;
        END;

        RETURN ( ok );

    END DoEffort;


    PROCEDURE DoSplitEffort ( VAR Unit : ADurationUnit;
                                  ToGo : BOOLEAN ) : BOOLEAN;
    VAR
        ok                : BOOLEAN;
    BEGIN
       ok := TRUE;

        WITH TaskPtr^ DO
            IF (Assume( RealInUse )) THEN
                IF ( Unit < Minutes ) OR
                   ( Unit > Years ) THEN
                   ok := FALSE;
                   Junk := Context.ErrorHandler( FormatError,
                                                 EnumerationWrong,
                                                 ColumnID,
                                                 NilString,
                                                 Context.HandlersContext );
                ELSE
                   IF ( ToGo ) THEN                             (* 24-Aug-89 MWP *)
                      ToGoSummary.Time := RealTimeToWorkHours( ColumnData.RealValue,
                                                               Unit );
                      GlobalContext.ToGoEffortSeen  := TRUE;
                   ELSE
                      CompletedSummary.Time := RealTimeToWorkHours( ColumnData.RealValue,
                                                               Unit );
                   END;


                END;
            ELSE
                ok := FALSE;
            END;
        END;

        RETURN ( ok );

    END DoSplitEffort;




    (* Look up a list of possible enumerated names and determine which
       one matches, if any.  Enumerations are numbered beginning with 0.
    *)


    PROCEDURE DoEnumeration(     PhraseNumber : CARDINAL;
                             VAR i : CARDINAL ) : BOOLEAN;
    VAR
        s1 : ARRAY [0..99] OF CHAR;
    BEGIN
        DoString( s1, HIGH(s1) );
        IF (EditsOK) THEN
            IF MatchWordFromPhrase( s1, PhraseNumber, i ) THEN
                DEC(i);
                RETURN TRUE;
            ELSE
                EditsOK := Context.ErrorHandler( FormatError,
                                                 EnumerationWrong,
                                                 ColumnID,
                                                 NilString,
                                                 Context.HandlersContext );
                RETURN FALSE;
            END;
        END;
    END DoEnumeration;



    PROCEDURE DoRequiredStart( VAR TaskFlags : ATaskFlagSet );
    VAR
        i : CARDINAL;
    BEGIN
            (* The requirements for the start date are stored in the task
               as two bits in the bitset that can be combined in any of
               four ways.  However, they are presented to the user as
               an enumeration. *)
        IF DoEnumeration( TLCaptionsModuleNumber+16, i) THEN
            TaskFlags := TaskFlags - ATaskFlagSet{NoSoonerStart,NoLaterStart};
            CASE i OF
                0 :
              | 1 : INCL(TaskFlags,NoSoonerStart);
              | 2 : INCL(TaskFlags,NoLaterStart);
              | 3 : TaskFlags := TaskFlags + ATaskFlagSet{NoSoonerStart,NoLaterStart};
            ELSE ErrorPhrase(0);   (* Recoverable program error. *)
            END;
        END;
    END DoRequiredStart;




    PROCEDURE DoTaskType();
    VAR
        i           : CARDINAL;
        OldFixType  : AFixType;
    BEGIN
            (* Phrase 15 contains the word "Summary" followed by a
               list of the valid fixation types.
            *)
        IF DoEnumeration( TLCaptionsModuleNumber+15, i) THEN
            IF (i = 0) THEN (* Summary *)
                TaskPtr^.fixation   := ASAP;   (* We hope this is really a summary task *)
            ELSE
                WITH TaskPtr^ DO
                    OldFixType := fixation;
                    fixation   := VAL(AFixType,i-1);

                        (* 14-Nov-90 RSC: If fixed, apply defaults.
                        *)
                        (* 20-Sep-91 TGS Since task form seemed to work, and
                           this didn't, I copied this section from TLChange.
                        *)
                    IF (fixation <> OldFixType) THEN
                        EXCL(TaskFlags,NoSoonerStart);
                        EXCL(TaskFlags,NoLaterStart);
                        IF (fixation = FixedDate) THEN
                            IF (FixedDateRules.ForceCritical) THEN
                                INCL( TaskFlags, ForceCritical );
                            ELSE
                                EXCL( TaskFlags, ForceCritical );
                            END;
                            INCL( TaskFlags, NoSoonerStart );
                            IF (FixedDateRules.StartDateMustStart) THEN
                                INCL( TaskFlags, NoLaterStart );
                            END;
                            (* 20-Sep-91 TGS Because UserEntered dates can
                                now be entered, set flags so that they are
                                set to be the same as EarlyStart/End dates
                                in EndTaskEdit.
                            *)
                            INCL( Context.WhatsBeenSeen, EarlyStartSeen );
                            INCL( Context.WhatsBeenSeen, EarlyEndSeen );
                        END;
                    END;
                END;
            END;
        END;
    END DoTaskType;


    PROCEDURE AllowAlterBaseline () : BOOLEAN;                    (* 20-Sep-89 MWP *)
    BEGIN
        IF ( NOT PImport^.BaseLineEncountered ) THEN
           PImport^.BaseLineEncountered := TRUE;
           PImport^.ImportBaseLineInfo  := AlterBaseline ();
        END;

        BaseChange := PImport^.ImportBaseLineInfo;             (* 24-Jul-90 *)

        RETURN PImport^.ImportBaseLineInfo;

    END AllowAlterBaseline;


    PROCEDURE DoBsLnEffort ( Unit      : ADurationUnit;
                             VAR Value : REAL       );
    VAR
        ok                : BOOLEAN;
    BEGIN
       ok := TRUE;

       IF (Assume( RealInUse )) THEN
          Value := RealTimeToWorkHours( ColumnData.RealValue,
                                        Unit );
       END;

    END DoBsLnEffort;


    PROCEDURE DoBsLnDuration (     Unit      : ADurationUnit;
                               VAR Value     : ADuration );
    BEGIN

       IF (Assume( RealInUse )) THEN
          Value  := RealTimeToDuration( ColumnData.RealValue,
                                        Unit );
       END;

    END DoBsLnDuration;


BEGIN
    PImport := PImportContext;

    WITH Context DO
        EditsOK := TRUE;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) THEN
            WITH TaskPtr^ DO
                WITH ColumnData  DO
                    CASE ColumnID OF
                        TaskNameColumn          :

                            DoString( taskname, HIGH(taskname) );
                            AjustName( taskname );
                            IF ( LengthOf ( taskname ) = 0 ) THEN
                                EditsOK := (LengthOf(CurrentTskNm) <> 0); (* 8-Nov-89 RSC Set "EditsOK" flag *)
                                IF (EditsOK) THEN
                                    Copy ( CurrentTskNm, taskname );
                                ELSE  (* 8-Nov-89 RSC *)
                                    Junk := ErrorHandler( CrossFieldError,
                                                          NoName,
                                                          ColumnID,
                                                          NilString,
                                                          HandlersContext );
                                END;
                            END;

                      | NotesColumn             :

                            DoNotes( notes );

                      | EarlyStartColumn        :

                            DoDate( Plan.Dates.EarlyStart );
                            INCL( WhatsBeenSeen, EarlyStartSeen );

                      | EarlyEndColumn          :
                            DoDate( Plan.Dates.EarlyEnd );
                            INCL( WhatsBeenSeen, EarlyEndSeen );

                      | DurationColumn          :

                            IF (Assume( TimeUnitInUse )) THEN
                                IF ( DoDuration( TimeUnitValue ) ) THEN
                                    TempDurScale := TimeUnitValue;
                                    scale := TimeUnitValue;
                                END;
                            END;

                      | DurationHours            :
                            TempTime := Hours;
                            Junk := DoDuration( TempTime ); (* 8-Nov-89 RSC Changed "Junk" To "EditsOK" *)

                      | DurationDays            :
                            TempTime := Days;
                            EditsOK  := DoDuration( TempTime ); (* 8-Nov-89 RSC Changed "Junk" To "EditsOK" *)

                      | DurationWeeks           :

                            TempTime := Weeks;
                            EditsOK := DoDuration( TempTime ); (* 8-Nov-89 RSC Changed "Junk" To "EditsOK" *)

                      | DurationMonths          :

                            TempTime := Months;
                            EditsOK := DoDuration( TempTime ); (* 8-Nov-89 RSC Changed "Junk" To "EditsOK" *)

                      | TotalEffort             :

                            IF (Assume( TimeUnitInUse )) THEN
                                IF ( DoEffort( TimeUnitValue, TRUE ) ) THEN
                                    EffortScale := TimeUnitValue;
                                    TempEffScale := TimeUnitValue;
                                END;
                            END;

                      | EffortHours             :

                            TempTime := Hours;
                            EditsOK  := DoEffort( TempTime, TRUE ); (* 8-Nov-89 RSC Changed "Junk" to "EditsOK" *)

                      | EffortDays              :

                            TempTime := Days;
                            EditsOK  := DoEffort( TempTime, TRUE ); (* 8-Nov-89 RSC Changed "Junk" to "EditsOK" *)

                      | EffortWeeks             :

                            TempTime := Weeks;
                            EditsOK  := DoEffort( TempTime, TRUE ); (* 8-Nov-89 RSC Changed "Junk" to "EditsOK" *)

                      | EffortMonths            :

                            TempTime := Months;
                            EditsOK  := DoEffort( TempTime, TRUE ); (* 8-Nov-89 RSC Changed "Junk" to "EditsOK" *)

                      | AUXColumn               :

                            GetCodingField (TaskPtr^, AUXLine, TempString);
                            DoString( TempString, AUXLen );
                            IF ( EditsOK ) THEN
                               SetCodingField (TaskPtr^, AUXLine, TempString);
                            END;

                      | WBSColumn               :

                            GetCodingField (TaskPtr^, WBSLine, TempString);
                            DoString( TempString, WBSLen );
                            IF ( EditsOK ) THEN
                               SetCodingField (TaskPtr^, WBSLine, TempString);
                            END;

                      | OBSColumn               :

                            GetCodingField (TaskPtr^, OBSLine, TempString);
                            DoString( TempString, OBSLen );
                            IF ( EditsOK ) THEN
                               SetCodingField (TaskPtr^, OBSLine, TempString);
                            END;

                      | TaskTypeColumn          :

                            DoTaskType();

                      | StartStatusColumn       :

                            IF DoEnumeration( TLCaptionsModuleNumber + 2,TempCard ) THEN
                                StartStatus := VAL(AStartStatus,TempCard);
                                GlobalContext.StartStatusSeen  := TRUE;
                            END;

                      | DurationMethodColumn    :

                            IF DoEnumeration( TLCaptionsModuleNumber + 1,TempCard ) THEN
                                DurationMethod := VAL(ADurationMethod,TempCard);
                            END;


                      | PercentAchieved         :

                            IF (Assume( RealInUse )) THEN
                                IF ( RealValue <= One ) AND
                                   ( RealValue >= 0.0 ) THEN
                                    TempReal := OneHundred * RealValue; (* 26-Sep-89 MWP *)
                                    EditsOK  := RtoC ( TempReal, TempCard ); (* 8-Nov-89 RSC was "Junk" *)
                                    PercentComplete:= TempCard;
                                    GlobalContext.AchievedSeen  := TRUE;
                                ELSE
                                    EditsOK := FALSE;  (* 8-Nov-89 RSC *)
                                    Junk := ErrorHandler( FormatError,
                                                          NumberOutOfRange,
                                                          ColumnID,
                                                          NilString,
                                                          HandlersContext );
                                END;
                            END;

                      | PriorityColumn          :

                            IF (Assume( RealInUse )) THEN
                                EditsOK := (RealValue <= 999.9);
                                IF (NOT EditsOK) THEN
                                    Junk := ErrorHandler( FormatError,
                                                          NumberOutOfRange,
                                                          ColumnID,
                                                          NilString,
                                                          HandlersContext );
                                ELSE
                                    EditsOK := RtoC( RealValue * 10.0, priority ); (* 8-Nov-89 RSC was "Junk" *)
                                END;
                            END;

                      | UserEnteredStartColumn        :

                            IF (Assume( BigTimeInUse )) THEN
                                UserEnteredStartDate := ColumnData.BigTimeValue;
                                INCL( WhatsBeenSeen, FixedStartSeen );
                            END;

                      | UserEnteredEndColumn        :   (* 17-Sep-90 PFG *)

                            IF (Assume( BigTimeInUse )) THEN
                                UserEnteredEndDate := ColumnData.BigTimeValue;
                                INCL (WhatsBeenSeen, FixedEndSeen);  (* 8/20/91 EGK *)
                            END;

                      | SupposedToStartColumn       :   (* 17-Sep-90 PFG *)

                            IF (Assume( BigTimeInUse )) THEN
                                SupposedToStart := ColumnData.BigTimeValue;
                            END;

                      | LateStartColumn         :

                            DoDate( Plan.Dates.LateFreeStart );

                      | LateEndColumn           :

                            DoDate( Plan.Dates.LateFreeEnd );

                      | LateIndStartColumn         :    (* 17-Sep-90 PFG *)

                            DoDate( Plan.Dates.LateIndStart );

                      | LateIndEndColumn           :    (* 17-Sep-90 PFG *)

                            DoDate( Plan.Dates.LateIndEnd );

                      | LateTotalStartColumn    :

                            DoDate( Plan.Dates.LateTotalStart );

                      | LateTotalEndColumn      :

                            DoDate( Plan.Dates.LateTotalEnd );

                      | Highlight1Column        :

                            DoString( TempString, HIGH(TempString) );
                            IF (EditsOK) THEN
                                EXCL( FilterSet, Highlight3 );
                                IF (TempString[1] <> " ") THEN
                                    INCL( FilterSet, Highlight3 );
                                END;
                            END;

                      | Highlight2Column        :

                            DoString( TempString, HIGH(TempString) );
                            IF (EditsOK) THEN
                                EXCL( FilterSet, Highlight4 );
                                IF (TempString[1] <> " ") THEN
                                    INCL( FilterSet, Highlight4 );
                                END;
                            END;

                      | Highlight3Column        :

                            DoString( TempString, HIGH(TempString) );
                            IF (EditsOK) THEN
                                EXCL( FilterSet, Highlight5 );
                                IF (TempString[1] <> " ") THEN
                                    INCL( FilterSet, Highlight5 );
                                END;
                            END;



                      | BaselineDuration        :
                            IF (Assume( TimeUnitInUse )) THEN
                                DoBsLnDuration ( TimeUnitValue, i );
                                IF (((NOT (BaseLineExists IN TaskFlags)) OR
                                    (TempBsLnDuration <> i)) AND
                                    AllowAlterBaseline()) THEN
                                    TempBsLnDuration := i;
                                END;
                                INCL( WhatsBeenSeen, BsLnDurationSeen);
                            END;


                      | BaselineDollars         :

                            IF (Assume( RealInUse )) THEN
                                IF ( BaseLineSummary.Amount <> RealValue ) THEN
                                   TempReal := BaseLineSummary.Amount - RealValue;

                                   IF ( TempReal < 0.0 ) THEN
                                      TempReal := -TempReal;
                                   END;

                                   IF ( TempReal > 0.001 ) THEN
                                      IF ( AllowAlterBaseline () ) THEN
                                          BaseLineSummary.Amount := RealValue;
                                      END;
                                   END;
                                END;
                            END;

                      | BaselineEffort          :
                            IF (Assume( TimeUnitInUse )) THEN
                                DoBsLnEffort ( TimeUnitValue, TempBsLnEffort );

                                BaseLineSummary.Time := TempBsLnEffort;
                             END;


                      | BaselineStartDate       :

                            IF (Assume( DateInUse )) THEN
                               IF (((NOT (BaseLineExists IN TaskFlags)) OR 
                                   ( BaseLine.Dates.EarlyStart <> DateValue )) AND
                                   AllowAlterBaseline () ) THEN
                                   BaseLine.Dates.EarlyStart := DateValue;
                                   INCL( WhatsBeenSeen, BsLnStartDate );
                               END;
                            END;

                      | BaselineEndDate         :

                            IF (Assume( DateInUse )) THEN
                               IF (((NOT (BaseLineExists IN TaskFlags)) OR
                                   ( BaseLine.Dates.EarlyEnd <> DateValue )) AND
                                   AllowAlterBaseline () ) THEN
                                   BaseLine.Dates.EarlyEnd := DateValue;
                                   INCL( WhatsBeenSeen, BsLnEndDate );
                               END;
                            END;


                      | BaselineBCWS            :

                            IF (Assume( RealInUse )) THEN
                               IF (  BCWSDollars <> RealValue  ) THEN
                                   TempReal := BCWSDollars - RealValue;
                                   IF ( TempReal < 0.0 ) THEN
                                      TempReal := -TempReal;
                                   END;

                                   IF ( TempReal > 0.001 ) THEN
                                      IF ( AllowAlterBaseline () ) THEN
                                         BCWSDollars := RealValue;
                                      END;
                                   END;
                               END;
                            END;

                      | ToGoEffort              :

                            IF (Assume( TimeUnitInUse )) THEN
                                EditsOK := DoSplitEffort( TimeUnitValue, TRUE );
                            END;

                      | CompletedEffort         :

                            IF (Assume( TimeUnitInUse )) THEN
                                EditsOK := DoSplitEffort( TimeUnitValue, FALSE );
                            END;

                      | AchievedDollars         :

                            IF (Assume( RealInUse )) THEN
                                BCWP        := RealValue;
                            END;

                      | SplittingRuleColumn    :

                            IF DoEnumeration( TLCaptionsModuleNumber + 13,TempCard ) THEN
                                SplittingRule := VAL(ASplittingRule,TempCard);
                            END;

                      | AllowSlackColumn       :

                            TempBoolean := ForceCritical IN TaskFlags;
                            DoBoolean(TempBoolean);
                            IF (TempBoolean) THEN
                                INCL(TaskFlags,ForceCritical);
                            ELSE
                                EXCL(TaskFlags,ForceCritical);
                            END;

                      | RequiredStartColumn    :

                            DoRequiredStart( TaskFlags );

                      | CodingField1..CodingField1+NumberOfCodingFields-1:

                            WhichField := (FirstOtherCodingLine
                                           + (ColumnID - CodingField1));
                            GetCodingField (TaskPtr^, WhichField, TempString);
                            DoString( TempString, HIGH(TempString) );   (* RSC 24-May-89 *)
                            IF ( EditsOK ) THEN
                               SetCodingField (TaskPtr^, WhichField, TempString);
                            END;
                      | WBSErrors:                             (* 25-Sep-91 *)
                            WhichField := FirstOtherCodingLine + NumberOfCodingFields;
                            GetCodingField (TaskPtr^, WhichField, TempString);
                            DoString( TempString, HIGH(TempString) );   (* RSC 24-May-89 *)
                            IF ( EditsOK ) THEN
                               SetCodingField (TaskPtr^, WhichField, TempString);
                            END;
                    ELSE
                    END;
                END;
                (* Recalc or Sort/Filter things if the column requires it.
                *)
                IF (EditsOK) THEN
                    NeedsRecalc := (NeedsRecalc OR (ColumnID IN RecalcColumns));
                    NeedsSort   := (NeedsSort   OR (ColumnID IN SortColumns));
                    IF (NeedsRecalc) THEN
                        INCL( TaskStatusSet, NeedsRecalculate );
                    END;
                END;
            END;
        END;
    END;


    RETURN EditsOK;

END ChangeTaskRecord;



(*
    End Task Edit

        Preconditions
                        > A Task is being edited (BeginTaskEdit has been
                          called).

        Postconditions
                        > Any changes made to the task after BeginTaskEdit
                          have been applied to the task node, or else the
                          ErrorHandler is called for each exception found.

                        > If any errors were found that were not fixable, or
                          where the error handler decided not to request
                          fixing, FALSE is returned.  Otherwise, TRUE is
                          returned.

    IMPLEMENTATION NOTE:

        This procedure is designed to fix all errors, regardless of what the
        client error handler wants to do.  This is because this procedure is
        used as a part of the "Sanitize" procedure, who needs to depend on
        this effect.
*)
PROCEDURE EndTaskEdit() : BOOLEAN;

CONST
    BaselineItems =  AWhatsBeenSeenSet{BsLnDurationSeen, BsLnStartDate, BsLnEndDate};

VAR
    TaskPtr         : ATaskPtr;
    s               : ARRAY [0..99] OF CHAR;
    TempBaseSet     : AWhatsBeenSeenSet;
    Total           : REAL;
    ForceBaseline   : BOOLEAN;
    AchievedSet     : BOOLEAN;
    StartStatusSet  : BOOLEAN;

    PROCEDURE SetEnd(    Start              : ADate;
                         Duration           : ADuration;
                     VAR End                : ADate );

    BEGIN                   (* SetEnd *)

        IF (MAXCARDINAL - Duration < Start) THEN
            End := MAXCARDINAL;
        ELSE
            End := Start + Duration;
        END;

    END SetEnd;


    PROCEDURE SetStart(VAR Start            : ADate;
                           Duration         : ADuration;
                           End              : ADate );

    BEGIN                   (* SetStart *)

        IF (Duration > End) THEN
            Start := 0;
        ELSE
            Start := End - Duration;
        END;

    END SetStart;


    PROCEDURE AjustDates( VAR DateBlock    : ADateBlock );
    BEGIN
            (* In EVE, negative slack can push slack dates before
               the early start date.
            *)
        WITH DateBlock DO
            IF (EarlyEnd <  EarlyStart) THEN
                EarlyEnd := EarlyStart;
            END;

            IF (LateFreeEnd <  LateFreeStart) THEN
                LateFreeEnd := LateFreeStart;
            END;

            IF (LateTotalEnd <  LateTotalStart) THEN
                LateTotalEnd := LateTotalStart;
            END;

            IF (LateTotalStart <  LateFreeStart) THEN
                LateTotalStart := LateFreeStart;
            END;

            IF (LateTotalEnd <  LateFreeEnd) THEN
                LateTotalEnd := LateFreeEnd;
            END;

            IF (LateIndEnd <  LateIndStart) THEN
                LateIndEnd := LateIndStart;
            END;
        END;
    END AjustDates;


BEGIN (* EndTaskEdit *)

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF (NOT EditsOK) THEN
            RETURN FALSE;
        END;

        WITH StateInfo DO
            IF (NeedsRecalc) THEN
                UnSetState( Scheduled );
                ScheduleSaved := FALSE;
            END;
            IF (NeedsSort) THEN
                UnSetState (Sorted);
                UnSetState (Filtered);
                ScheduleSaved := FALSE;
            END;


            (* Lock the task down so we can change it. *)

            TaskPtr  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);


            WITH TaskPtr^ DO

                    (* Fixed Date tasks are currently required to be
                       duration-driven.  This is a limit of the 
                       design of the task form interface, not a limit
                       of recalc. *)

                IF (fixation = FixedDate) THEN
                    DurationMethod := DurationDriven;  (* 23-Sep-90 RSC *)
                END;

                    (* Future tasks, unless they are fixed date, are
                       currently not allowed to have required start dates.
                       This is really an interface, not a recalc,
                       limitiation. *)

                IF (StartStatus = FutureS) AND
                   (fixation <> FixedDate) THEN (* 19-Dec-90 TGS *)
                    EXCL(TaskFlags,NoSoonerStart);
                    EXCL(TaskFlags,NoLaterStart);
                END;

                AchievedSet    := FALSE;
                StartStatusSet := FALSE;

                    (* If the user enters to go effort, and cost tracking is off,
                       and the user has not entered achievement or start status,
                       and this is an effort driven task, then infer the achievement
                       from the to go effort. *)

                IF (NOT (UsesCostTracking OR AchievedSeen OR StartStatusSeen) ) THEN
                    IF (ToGoEffortSeen)
                      AND (DurationMethod = EffortDriven) THEN
                        Total := CompletedSummary.Time + ToGoSummary.Time;
                        IF (Total > Zero) THEN
                            PercentComplete := TRUNC((CompletedSummary.Time * OneHundred
                                                     / Total)+Half);
                            AchievedSet := TRUE;
                        END;
                    END;
                END;

                    (* Make sure that the percent achieved and the 
                       start status are consistent. *)

                IF (StartStatusSeen) AND (NOT AchievedSeen) THEN
                    IF (StartStatus <> StartedS)  THEN
                        IF (StartStatus = FutureS) THEN
                            PercentComplete := 0;
                        ELSE
                            PercentComplete := 100;
                        END;
                        AchievedSet := TRUE;
                    END;
                END;

                (* If Percent Achieved is changed to 0 or 100, make the
                   start status be Future or Done, respectively.
                   RSC 22-Aug-89.
                *)
                IF ((AchievedSeen) OR (AchievedSet))
                   AND (NOT StartStatusSeen) THEN
                    IF (PercentComplete = 100) THEN
                        StartStatus := DoneS;
                    ELSIF (PercentComplete = 0) THEN
                        StartStatus := FutureS;
                    ELSE
                        StartStatus := StartedS;
                    END;
                    StartStatusSet := TRUE;
                END;

                    (* 20-Sep-91 TGS *)
                    (* Make sure UserEntered dates are the same as EarlyStart
                       EarlyEnd dates. But don't step on any that might have
                       been imported or whatever.
                    *)
                IF ((StartStatusSeen) OR (StartStatusSet)) AND
                   (StartStatus <> FutureS) THEN
                    IF NOT (FixedStartSeen IN WhatsBeenSeen) THEN
                        INCL(WhatsBeenSeen, EarlyStartSeen);
                    END;
                    IF NOT (FixedEndSeen   IN WhatsBeenSeen) THEN
                        INCL(WhatsBeenSeen, EarlyEndSeen);
                    END;
                END;

                    (* When not using CostTracking (explicit entry of 
                       effort and costs spent) we infer spent costs
                       based on percent achieved, or in some cases,
                       percent achieved based on spent effort. *)

                IF (NOT UsesCostTracking) THEN
                    IF (AchievedSeen) AND (NOT ToGoEffortSeen) THEN
                        UpdateEffortToMatchRatio( TaskPtr^,
                                                  FLOAT(PercentComplete)/OneHundred );
                    END;
                END;

                scale       := TempDurScale;
                EffortScale := TempEffScale;
            END;


            (* Now thread our way through the complicated date reconciling.

                Enforce the rules:

                  IF THEY CHANGE            WE UPDATE
                  --------------            -----------
                  Start Date                End Date
                  Duration                  End Date
                  End Date                  Duration   IFF duration driven,
                  End Date                  StartDate  IFF effort driven.

            *)


            WITH TaskPtr^.Plan.Dates DO

                IF (FixedStartSeen IN WhatsBeenSeen) THEN
                    IF (NOT (EarlyStartSeen IN WhatsBeenSeen)) THEN
                        EarlyStart := BigTimeToCalendarTime(TaskPtr^.UserEnteredStartDate);
                    END;
                ELSE
                    IF (EarlyStartSeen IN WhatsBeenSeen) THEN
                        CalendarTimeToBigTime(EarlyStart,TRUE,TaskPtr^.UserEnteredStartDate);
                    END;
                END;

                IF (FixedEndSeen IN WhatsBeenSeen) THEN     (* 8/20/91 EGK *)
                    IF (NOT (EarlyEndSeen IN WhatsBeenSeen)) THEN
                        EarlyEnd := BigTimeToCalendarTime(TaskPtr^.UserEnteredEndDate);
                    END;
                    IF (EarlyEnd < EarlyStart) THEN
                        CalendarTimeToBigTime (EarlyStart, TRUE, TaskPtr^.UserEnteredEndDate);
                    END;
                ELSE
                    IF (EarlyEndSeen IN WhatsBeenSeen) THEN
                        CalendarTimeToBigTime(EarlyEnd,FALSE,TaskPtr^.UserEnteredEndDate);
                    END;
                END;


                AjustDates( TaskPtr^.Plan.Dates );  (* Pass 1 for EarlyStart/End *)

                IF (FixedStartSeen IN WhatsBeenSeen) OR
                   (EarlyStartSeen IN WhatsBeenSeen) THEN

                    TaskPtr^.SupposedToStart := TaskPtr^.UserEnteredStartDate;

                    IF (EarlyEndSeen IN WhatsBeenSeen) OR
                       (FixedEndSeen IN WhatsBeenSeen) THEN
                        TaskPtr^.duration := EarlyEnd - EarlyStart;
                    ELSE
                        SetEnd( EarlyStart, TaskPtr^.duration, EarlyEnd );
                        IF (FixedStartSeen IN WhatsBeenSeen) THEN              (* 27-Sep-91 *)
                            CalendarTimeToBigTime(EarlyEnd,FALSE,
                                                 TaskPtr^.UserEnteredEndDate);
                        END;    
                    END;
                ELSIF (EarlyEndSeen IN WhatsBeenSeen) OR
                      (FixedEndSeen IN WhatsBeenSeen) THEN
                    IF (DurationSeen IN WhatsBeenSeen) THEN
                        SetStart( EarlyStart, TaskPtr^.duration, EarlyEnd );
                        IF (FixedEndSeen IN WhatsBeenSeen) THEN                (* 27-Sep-91 *)
                            CalendarTimeToBigTime (EarlyStart, TRUE, 
                                               TaskPtr^.UserEnteredStartDate);
                        END;
                    ELSE
                        TaskPtr^.duration := EarlyEnd - EarlyStart;
                    END;
                ELSIF (DurationSeen IN WhatsBeenSeen) THEN
                    SetEnd( EarlyStart, TaskPtr^.duration, EarlyEnd );
                END;

                AjustDates( TaskPtr^.Plan.Dates );
            END;

            IF (BaseChange) THEN                               (* 24-Jul-90 *)
                WITH TaskPtr^.BaseLine.Dates DO
                    TempBaseSet := WhatsBeenSeen * BaselineItems;
                    IF (TempBaseSet <> AWhatsBeenSeenSet{}) THEN
                        INCL (TaskPtr^.TaskFlags, BaseLineExists);

                        IF (TempBaseSet = AWhatsBeenSeenSet{BsLnStartDate}) THEN
                            SetEnd( EarlyStart, TempBsLnDuration, EarlyEnd );
                        ELSIF (TempBaseSet = AWhatsBeenSeenSet{BsLnEndDate}) THEN
                            SetStart( EarlyStart, TempBsLnDuration, EarlyEnd );
                        ELSIF (TempBaseSet = AWhatsBeenSeenSet{BsLnDurationSeen}) THEN
                            SetEnd( EarlyStart, TempBsLnDuration, EarlyEnd );
                        ELSIF (TempBaseSet = AWhatsBeenSeenSet{BsLnEndDate,BsLnDurationSeen}) THEN
                            SetStart( EarlyStart, TempBsLnDuration, EarlyEnd );
                        ELSIF (TempBaseSet = AWhatsBeenSeenSet{BsLnStartDate,BsLnDurationSeen}) THEN
                            SetEnd( EarlyStart, TempBsLnDuration, EarlyEnd );
                        END;

                    END;
                END;
                AjustDates( TaskPtr^.BaseLine.Dates );
            END;

            (*  Don't change the rollup status.                (* 09-Mar-92 *)
            WITH TaskPtr^ DO
                IF (ADDRESS(summarizes) <> NIL) THEN
                    rollupstatus := RollupNotLoaded;
                ELSE
                    rollupstatus := NotRollup;
                END;
            END;
            *)

            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode); (* R/W version! *)

            ContextReady := FALSE;
        END;
    END;

    RETURN (GlobalContext.EditsOK);

END EndTaskEdit;







(* Status No Dialog Proc

        Provide a dialog proc for "CheckStatusChange" that does not ask
        any questions.
*)
PROCEDURE StatusNoDialogProc(    TreeNode          : ATreeNode;
                                 StartStatus       : AStartStatus
                            ) : AStatusDialogResponse;
BEGIN
    RETURN FixTheTask;
END StatusNoDialogProc;









(*
    Sanitize Task

        Preconditions
                        > The task is thought to be complete and consistant
                          (All referenced resources are present, any dependant
                          tasks are present, etc)

                          The intention is that this is called for all tasks
                          at the end of importing ALL data for the schedule.

        Postconditions
                        > If any errors are found, they are fixed by whatever
                          measures are needed to insure that the schedule
                          contains only consistant data.
*)
PROCEDURE SanitizeTask(     RowNode         : ATreeNode;
                            ErrorHandler    : AnErrorHandlerProc;
                            HandlersContext : ADDRESS;
                            LAlterBaselineProc :  AnAskAlterBaselineProc;
                            LImportTable       : ADDRESS );
VAR
    Task                    : ATaskPtr;
    i,
    Count                   : CARDINAL;
    PImportTable            : POINTER TO AImportTable;
    Assignments             : AnAssignmentArray;
    PlanHandle              : AnExtHandle;
    NewCompletedSummary,
    NewToGoSummary,
    OldCompletedSummary,
    OldToGoSummary,
    LocalCompleted,
    LocalToGo,
    LocalBaseLine,
    JunkSummary             : AnAssignmentSummary;
    HasKids,
    Resources,
    ok                      : BOOLEAN;
BEGIN


    BeginTaskEdit( RowNode, ErrorHandler, HandlersContext,
                   LAlterBaselineProc,
                   LImportTable );

    ok := EndTaskEdit();

    PImportTable := LImportTable;

    HasKids := (RowNode^.Methods^.FirstChild(RowNode) <> NIL);
    Task    := RowNode^.Methods^.LockFlexStorDataObject(RowNode);

    WITH Task^ DO
        IF (HasKids) THEN
            DurationMethod := DurationDriven;
            fixation       := ASAP;

            IF (ADDRESS(summarizes) <> NIL) THEN
                DiscardText( summarizes );
                rollupstatus := NotRollup;
            END;
        END;

        (* 30-Apr-91 TGS *)
        IF (DurationMethod = DurationDriven) AND
           (StartStatus   <> FutureS       ) THEN
            SplittingRule := Split;
        END;


        IF (BaseLine.Assignments <> AnExtHandle(NIL)) THEN
            Count := LockObjectArray( BaseLine.Assignments,
                                      Assignments, TSIZE( AnAssignmentRecord ) );
            i := 0;
            WHILE (i < Count) DO
(*$O-*)
                WITH Assignments^[i] DO
                    IF (ActualQuantity > Zero) THEN
                        YetToGoQuantity := YetToGoQuantity + ActualQuantity;
                        ActualQuantity  := Zero;
                    END;
                END;
(*$O=*)
                INC(i);
            END;

            SummAssignments( Assignments, Count,
                             BaseLine.Dates.EarlyStart, (* 10-Aug-90 RSC *)
                             BaseLine.Dates.EarlyEnd,
                             TRUE,
                             JunkSummary,
                             LocalBaseLine );

            WITH GlobalContext DO
                WITH StateInfo DO
                    BaseLineSummary.Time            := LocalBaseLine.Time   + KidsBaseLineSummary.Time;
                    BaseLineSummary.Amount          := LocalBaseLine.Amount + KidsBaseLineSummary.Amount;
                END;
            END;

            ReleaseObject( BaseLine.Assignments );
            INCL( TaskFlags, BaseLineExists );
        ELSE
            BaseLineSummary := GlobalContext.StateInfo.KidsBaseLineSummary;
            (* RSC 8-Nov-89 INCL( TaskFlags, BaseLineExists );  *)  (* 8-Oct-89 MWP *)
        END;

        IF (Plan.Assignments <> AnExtHandle(NIL)) THEN
            Count := LockObjectArray( Plan.Assignments,
                                      Assignments, TSIZE( AnAssignmentRecord ) );

            i := 0;
(*$O-*)
            WHILE (i < Count) AND
                  (Assignments^[i].Resource^.Type <> Employable) DO
                INC(i);
            END;
(*$O=*)
            Resources := (i < Count);

            IF (NOT Resources) THEN
                DurationMethod := DurationDriven;
            END;

            IF (DurationMethod = EffortDriven) THEN  (* 11-Oct-89 RSC *)
                i := 0;
(*$O-*)
                WHILE (i < Count) DO
                    EXCL (Assignments^[i].Attributes, ComputeByHours);
                    INC(i);
                END;
(*$O=*)
            END;

            ReleaseObject( Plan.Assignments );
            INCL( TaskFlags, PlanExists );
        ELSE

        (* 23-Sep-90 RSC remove these, as they seem to get in the way
                         of the computations below.
        *)
(*            CompletedSummary  := GlobalContext.StateInfo.KidsCompletedSummary;*)
(*            ToGoSummary       := GlobalContext.StateInfo.KidsToGoSummary;*)

                (* Un-commented the next line -- EGK 8/29/91 *)

              DurationMethod    := DurationDriven;

            (* RSC 11-Aug-89 EXCL( TaskFlags, PlanExists ); *)

        END;

        OldCompletedSummary := CompletedSummary;
        OldToGoSummary      := ToGoSummary;

        PlanHandle          := Plan.Assignments;
    END;

    RowNode^.Methods^.UnlockFlexStorDataObject( RowNode ); (* R/W version! *)
    Task := NIL; (* DEBUGGING *)

    (* Make sure Assigned Spent efforts are less than or equal to Estimated efforts *)
    ok := CheckTaskEfforts(RowNode, FALSE,
                           NewCompletedSummary, NewToGoSummary); (* 29-Apr-91 TGS *)

    ok := CheckStatusChange( RowNode,
                             StatusNoDialogProc );

    ComputeTaskNodeCosts( RowNode );

    SummTaskNodeAmounts(  RowNode, FALSE,
                          LocalCompleted,
                          LocalToGo );

    (* Ajust the summaries to account for kids who have not (yet) changed. *)
    IF (HasKids) THEN   (* 1-Jun-90 RSC Don't double book changes for kids *)
        WITH GlobalContext DO
            WITH StateInfo DO
                NewToGoSummary.Time        := LocalToGo.Time +
                                              KidsToGoSummary.Time;

                NewToGoSummary.Amount      := LocalToGo.Amount +
                                              KidsToGoSummary.Amount;

                NewCompletedSummary.Time   := LocalCompleted.Time +
                                              KidsCompletedSummary.Time;

                NewCompletedSummary.Amount := LocalCompleted.Amount +
                                              KidsCompletedSummary.Amount;
            END;
        END;

        (* If there is a difference, save it.*)

            (* 23-Sep-90 RSC It seems that by now, the "Old...." values
                             may no longer reflect what was in the task
                             record, due to the "ComputeTaskNodeCosts",
                             above.  Take the speed hit and always put
                             the new data in the task.
            *)
        Task             := RowNode^.Methods^.LockFlexStorDataObject(RowNode);
        WITH Task^ DO
            CompletedSummary := NewCompletedSummary;
            ToGoSummary      := NewToGoSummary;
        END;
        RowNode^.Methods^.UnlockFlexStorDataObject( RowNode ); (* R/W version! *)

        (* OLD CODE: ********************** *)

(* ****** IF (NewToGoSummary.Time        <> OldToGoSummary.Time)        OR*)
(* ******    (NewToGoSummary.Amount      <> OldToGoSummary.Amount)      OR*)
(* ******    (NewCompletedSummary.Time   <> OldCompletedSummary.Time)   OR*)
(* ******    (NewCompletedSummary.Amount <> OldCompletedSummary.Amount) THEN*)
(* ******     Task             := RowNode^.Methods^.LockFlexStorDataObject(RowNode);*)
(* ******     WITH Task^ DO*)
(* ******         CompletedSummary := NewCompletedSummary;*)
(* ******         ToGoSummary      := NewToGoSummary;*)
(* ******     END;*)
(* ******     RowNode^.Methods^.UnlockFlexStorDataObject( RowNode ); (* R/W version! *)*)
(* ****** END;*)
    END;

END SanitizeTask;


BEGIN
    SetLengthOf( NilString,    0 );
    SetLengthOf( CurrentTskNm, 0 );     (* 8-Nov-89 RSC *)
    GlobalContext.ContextReady := FALSE;
    BaseChange := FALSE;

END TaskChange.


