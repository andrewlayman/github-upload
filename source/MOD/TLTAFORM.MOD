MODULE TLTaForm;



(*  =========================================================================
    Last Edit : August 14, 1991 6:14PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Task Assignment Forms.  Run the (up to 6) assignment form(s).

    MODIFICATION HISTORY:

        26-Apr-89 RSC  First version, code extracted from AssForms.
        17-May-89 RSC  For started and done tasks, allow any rate of
                       assignment.  Be more liberal in recalcing the
                       assigned percentages.
        20-May-89 RSC  Accomidated the new WorkHours module.
        25-May-89 RSC  Don't give error messages for rates being too
                       big until the form is exited.
        31-May-89 RSC  Handle overbooked resource rates differently.
                       Move the assignment pointer from rsrccalc to
                       assignme.def
         1-Jun-89 RSC  Entering 1 @ when percentage is 0 didn't work.
                       When overbooked, we used to change the assigned
                       rate to the max.  That looked strange.
         5-Jun-89 RSC  Added "UsesCostTracking" support rather than
                       "AdvancedTaskForm".
        12-Jun-89 AJL  Don't preempt the EditKey. 
        13-Jun-89 RSC  As per AJL, make the "TotalBucks", "YetToGoBucks",
                       and "ActualBucks" fields true Reals, not strings
                       masquerading as reals.
        14-Jun-89 RSC  Put back the original assignment if they hit ESC
                       from the form.  Otherwise, ESC was the same as
                       F10.
        13-Mar-90 RSC  Preserve the last entered "Number of people" field
                       upon entry to the form, and whenever anyone actually
                       changes it, so that we can cut down on wild changes
                       due to other fields changing, specificly the effort
                       fields (Qty & Units).
        30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
         6-Aug-90 RSC  New edit rules and handling for AssignmentDriven tasks
                       and for editing with var avail lists.  Added new
                       fields to assignment forms:  Overtime, Extra costs.
         7-Aug-90 RSC  Tune the editing of assignments.
        10-Aug-90 RSC  New parameters for AssignmentCost.
        21-Aug-90 PFG  Check for PercentageEach of 0 before dividing into 
                       MaxRatePercent.  (Bug #3126)
        27-Aug-90 RSC  Took assignments out of the tree and put them
                       back into the task record.
         4-Sep-90 RSC  Ajust how Counts are computed from Amounts.  It
                       used to be simple, but now when you enter Total or
                       Spent Dollars, I can't simply compute the count of
                       hours, but have to account for overtime and extra
                       dollars as well.

        25-Sep-90 RSC  Don't include extra dollars in the ActualBucks.
        05-Nov-90 PFG  Modifications to resource assignment forms as per 
                       4.5 prototype review: Added time units for Overtime 
                       and added Overtime to small form.  Also changed
                       "ResourceDriven" to "EffortDriven" for Chie.
        12-Nov-90 PFG  When user enters Spent Cost ("Actual Bucks") or Total
                       Cost, calculate hours using AsOfDate rather than 
                       beginning and ending task dates.  Also, (unrelated)
                       calculate overtime based on the type of time unit 
                       chosen.
*)
(*    
        14-Dec-90 TGS  Change SetProtection; Spent $ no longer editable.
        28-Dec-90 AJL  Well . . . it seems that the current assignment form
                       only allows entry of overtime hours in hours; However, 
                       nobody actually sets the OvertimeTimeUnits to hours,
                       and the user cannot because it is no longer an enterable
                       field!  Furthermore, the field is initialized to Days
                       in Assignments.mod, so whatever the user thinks is
                       entered in hours really gets entered in Days. Fixed.
                      -Removed unused EarlyStart and EarlyEnd from the context
                       record.
                      -Added a check that effort cannot be entered on an
                       assignment if the rate is zero.
                      -Make a FatalError if somehow effort is entered on
                       an effort-driven task.
                      -If a user enters more overtime spent than planned,
                       add enough to the planned overtime hours so that the
                       yet-to-go overtime is never negative.
                      -Reversing Roger's 25-Sep change, I am including the 
                       extra dollars in the spent dollars display.  I think
                       it had been removed because of ambiguities in working
                       backward from spent dollars to spent effort, which
                       are now removed because we don't allow entry of spent
                       dollars for resources.
                      -If a cost has varying rates, then the
                       spent bucks field is not enterable because we could not
                       work backwards from the rate to the quantity without
                       knowing the date.
                      -Allow entry of spent and total dollars for resources
                       and unit costs only when the number of rates is 1.
         4-Feb-91 TGS  Use DefaultAvailabiliy CONSTs from RsrcMod. 
         5-Feb-91 TGS  Don't allow 0% to be assigned.
                       Fixed PercentageOK proc a wee bit.
        15-May-91 TGS  No overtime fields now.
        24-May-91 PFG  Fixed a divide-by-zero problem in PercentageOK.
         7-Aug-91 PFG  The old assignment info was being saved, but it was
                       not being restored when the user pressed ESC.

                       Another, unrelated change.  This is a fix to the
                       change I made on 12-Nov.  I don't know WHAT I had in
                       mind when I made that change, but the AsOfDate should
                       only replace the Start/End dates when the user enters
                       new values, not when we calculate the spent and togo
                       totals initially.  I've gone back to using EarlyStart
                       and EarlyEnd where needed.
        14-Aug-91 PFG  Fixed a problem where on the small form hidden fields
                       were getting DisplayOnly turned OFF for them and the
                       user could then move into them.  There was only one
                       field that was actually a problem.
        20-Aug-91 TGS   If you ESC from an assignment form, don't recompute
                        nothin'. Also don't change nothin' when just moving
                        around on the form.
        23-Aug-91 LAA  On a Resource Assignment Form, protect the total
                       bucks field if for an Effort driven task.  With Eve,
                       it's no longer possible to enter dollars and work back
                       to assigned number and percent, just as you can't 
                       enter total resource effort and work back.
        24-Aug-91 LAA  Reversed out Andrew's 28-Dec-90 reversal of Roger's
                       25-Sep-90 change because, as Andrew noted, you CAN
                       enter spent dollars for a resource with only one cost
                       rate.  The effects of this were that you would enter
                       x dollars as spent, and the field would change to
                       show x + (extra $).  If you then entered (x + extra$)
                       in the field, it would change to (x + 2 * extra$), etc.
                       I think this is wrong.
        28-Aug-91 LAA  SaveField was updating the % field on a duration 
                       driven task when the time units field was exited with
                       no change, if there was a vacation during the period
                       of the task (i.e. it recomputed the percentage as if
                       the effort was spread evenly over the task).  SaveField
                       is now only called for a check field change.
        15-Sep-91 LAA  When the effort field of an assignment to a milestone
                       is blanked out, the MaxRateAmount was being changed to
                       0, causing field values to change from 1 @ 100% to
                       0 @ 100% (for instance).  For this situation, 
                       UpdateTotalEffort was changed to keep the 1 @ whatever.
        17-Sep-91 LAA  Added RateAvailable to check the rate value
                       against the varying avail. rate list.
         7-Oct-91 TGS  We were feeding AssignmentCost a negative interval,
                       in an attempt to get a more "accurate" number for
                       spent/togo $, on the assumption that Start<AsOf<End.
                       Well, when this assumption turned out to be untrue,
                       we'd get $0 from AssignmentCost for either Spent or
                       ToGo $.
                       Since we can't get accurate numbers anyway, we'll go
                       for reasonable numbers: use the same interval from
                       task Start to End for Total$, Spent$, and ToGo$,
                       instead of getting fancy with the AsOfDate as before.
        17-Jan-92 TGS  We were turning Protection off (after setting it
                       properly) on the TotalBucks field if the task was
                       Duration driven (small form). This gave rise to a
                       "phantom phield"
        29-Jan-92 TGS  Allow a Real NumberAt to be derived/entered.
        18-Feb-92 TGS  NumberAt/EffAmt was changing bizarrely. I shoulda
                       been looking at RealValue (now), not CardValue.
        05-Mar-92 LAA  In SaveField, after updating the total effort, also
                       check that this hasn't caused MaxRatePercent to be
                       too large.  This check was being done when the 
                       NumberAt or Percentage was directly changed, but not
                       when they were indirectly changed.  This change was
                       also made for changes in the effort units.
         3-Apr-92 TGS  Use new proc, AssignmentDollars() instead of 
                       AssignmentCost().
        06-Apr-92 TGS  Kill VaryingAssignments when a change is made to
                       effort numbers, so AssignmentDollars() will go and
                       make something up.
        08-Apr-92 TGS  When user enters "total cost", check effort as if
                       they'd entered the equivalent effort. Bug 5522.
        13-Apr-92 TGS  RtoC rounds to nearest CARDINAL instead of rounding
                       up to next one.
        15-Apr-92 TGS  UpdateTotalEffort() now sometimes calls PercentOK().
                       But we weren't hardly checking to see if it worked
                       so sometimes went ahead as if nothing were amiss.
                       Now everybody that calls it, directly or indirectly,
                       checks the return value and does something about it.
                       Bug 5543.
========================================================================= *)




FROM Allocs                     IMPORT
      (* TYPES *)                  AFixType, ATaskPtr, ATask, ADurationMethod,
                                   AStartStatus, AnAssignmentSummary;

FROM AsOf                       IMPORT
      (* VAR   *)                  AsOfDate;

FROM AssgnCalc              IMPORT
    (* PROC *)                  AssignmentDollars;

FROM Assignments                IMPORT
      (* TYPES *)                  AnAssignmentArray, AnAssignmentAttribute,
                                   AnAssignmentAttributeSet,
                                   AnAssignmentPointer,
                                   AnAssignmentRecord;

FROM BigTimeU                   IMPORT
    (* TYPE *)                     ABigTime;
     
FROM Changer                    IMPORT
      (* CONST *)                  MaxAssignmentFields,
      (* TYPE *)                   AnAssignmentField, AnAssignmentFieldSet,
                                   AFormMappingRecord,
                                   AnAssignmentForm,
      (* VAR  *)                   UsesCostTracking,
                                   FormMappingRecords;


FROM Codes                      IMPORT
      (* TYPE *)                   ACode;

FROM DateLists                  IMPORT
    (* TYPE *)                     ADateList,
    (* PROC *)                     NumberOfDatesInList, GetDateListEntry;

FROM Dialog                     IMPORT
      (* TYPES *)                  ADialogOption,
      (* PROCS *)                  ContinuationBox, WarningBox, Burp,
                                   MultipleChoiceBox, ErrorPhrase, FatalError,
                                   Message, NotYetImplemented;

FROM FlexStor                   IMPORT
      (* TYPE *)                   AnExtHandle, AnExtStoragePreference,
      (* PROC *)                   LockObjectArray, ReleaseObject,
                                   ReleaseUnchangedObject;

FROM Forms                      IMPORT
      (* TYPES *)                  AFieldValue, AStringValue, AForm,
                                   ACheckReason, ACursorAttribute,
      (* PROCS *)                  DoForm, HighlightField,
                                   SetFormChange,
                                   SetFieldProtection, ShowValue, 
                                   FieldIsHidden;

FROM FormCon                    IMPORT
      (* TYPES *)                  AFieldNo;

FROM Keys                       IMPORT
      (* CONST *)                  DoIt, EditKey, ResourceFormKey, ExitKey,
                                   CancelKey;

FROM LongConvert                IMPORT
    (* PROC *)                     LongToReal, RealToLong;

FROM LStrings                   IMPORT
      (* PROCS *)                  RJust, Fill, SetString, ConcatS, ConcatLS,
                                   LJust, SubStr, TrimRear, Upshift, CtoS,
                                   LengthOf, SetLengthOf, Procustes,
                                   StringsEqual, TrimFront, Copy;

FROM MsgFile                    IMPORT
      (* PROCS *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays                   IMPORT
    (* TYPE *)                      AnOverlayID,
    (* PROC *)                      OverlayContext, ImAnInstallableOverlay;

FROM OvTree                     IMPORT
    (* TYPE *)                      AnOverlayProc;

FROM Paranoia                   IMPORT
      (* TYPE *)                   AnAnxietyLevel,
      (* VAR  *)                   AnxietyLevel;

FROM ParseReal                  IMPORT
      (* PROCS *)                  AmountToReal;

FROM RateLists                  IMPORT
    (* TYPE *)                     ARateList,
    (* PROC *)                     NumberOfRatesInList;

FROM RealFormat                 IMPORT
    (* PROC *)                     RealToLStrings;

FROM ResCalUI                   IMPORT
    (* TYPE *)                     AnAvailabilityRate;

FROM RsrcCalc                   IMPORT
    (* TYPE *)                     AnAssignmentCostType,
                                   AnAssignmentCostTypeSet,
      (* PROCS *)                  AssignmentCost,
                                   ComputeTaskNodeCosts;

FROM RsrcMod                    IMPORT
    (* CONST *)                     DefaultAvailabilityAmount,
                                    DefaultAvailabilityPercent,
    (* TYPE *)                      ACostStyle,  AResourcePointer,
                                    AResourceType, 
    (* VARS *)                      ResourceTree,
    (* PROC *)                      FindResourceByName, AverageResourceRate;

FROM StatusChange               IMPORT
    (* PROC *)                      MakeAssignmentRateMatchTotal;

FROM Timei                      IMPORT 
      (* CONST *)                  NoDuration,
      (* TYPES *)                  ADate, ADurationUnit, ADuration,
      (* PROCS *)                  TimeUtoT, TtoTimeU, DurationToReal;

FROM Timeu                      IMPORT 
      (* VARS *)                   FSMUPH,
      (* PROCS *)                  UpScale, DownScale,
                                   FindCorrectScale;

FROM TaskAssForms               IMPORT
    (* TYPE *)                     AnOverlayContext;

FROM TreeObjects                IMPORT
      (* TYPE *)                   ATreeNode;

FROM SYSTEM                     IMPORT
      (* THING *)                  ADDRESS, ADR, SIZE, TSIZE;

FROM VaryAssgnment      IMPORT
    (* TYPE *)              AVaryingAssgnList,
    (* PROC *)              CopyVaryingAssgnList, DisposeVaryingAssgnList;

FROM WorkHours                   IMPORT
      (* PROCS *)                  RealTimeToWorkHours,
                                   WorkHoursToRealTime;





CONST
    ModuleNumber = 17800; (* MODULE NUMBER SHARED WITH ASSFORMS.MOD *)

    Zero         =     0.0;
    OneHundred   =   100.0;
    FMAXCARDINAL = 65535.0;
    MaxPercent   = 250;       (* Maximum value in the percent field
                                 on a task form. *)
    
        (* phrase file message numbers *)
    PercentTooBig           = ModuleNumber + 9;
    ImpliedPercentTooBig    = ModuleNumber + 30;               (* 05-Mar-92 *)
    EffortTooBig            = ModuleNumber + 37;
    EffortWithoutDuration   = ModuleNumber + 39;
    EffortWithoutRate       = ModuleNumber + 41;
    SpentMoreThanPlan       = ModuleNumber + 43;
    SpentOTMoreThanPlan     = ModuleNumber + 45;




TYPE
    ALocalFormContext = RECORD


        (* What task is this for? *)

        TaskNode            : ATreeNode;

        (* What is the assignment we are editing?
           We need both the original and the current one.
        *)
        CurrentAssignment   : AnAssignmentPointer;


            (* Keep track of which template we should use. *)

        CurrentForm         : AnAssignmentForm;

        EnteredNumber       : REAL;

        TaskDuration        : ADuration;
        TaskMethod          : ADurationMethod;
        StartStatus         : AStartStatus;

        TaskInfoNeeded      : BOOLEAN;

    END;



VAR
    OverlayID           : AnOverlayID;

    FormNumbers         : ARRAY ACostStyle OF
                          ARRAY BOOLEAN    OF CARDINAL;
    RsrcForm            : ARRAY BOOLEAN    OF CARDINAL;

    MyContext           : ALocalFormContext;

    FormKind            : ARRAY ACostStyle OF AnAssignmentForm;
    ModeChar            : ARRAY BOOLEAN    OF CHAR;








    (* Find the field with the specified field type *)

PROCEDURE FindField( WhichField : AnAssignmentField ) : CARDINAL;
VAR
    Loop : CARDINAL;
BEGIN
    WITH FormMappingRecords[ MyContext.CurrentForm ] DO
        FOR Loop := 1 TO FieldCount DO
            IF (FieldTable[ Loop ] = WhichField) THEN
                RETURN Loop;
            END;
        END;
    END;
    FatalError();  (* No related field ? *)
END FindField;




  (* Map Assignment Form - do generic mapping for the assignment form *)

PROCEDURE MapAssignmentForm( VAR Assignment : AnAssignmentRecord;
                             VAR Fields     : ARRAY OF AFieldValue );
VAR
    Loop    : CARDINAL;
    i       : INTEGER;
    TaskPtr : ATaskPtr;
    Start   : ADate;
    End     : ADate;
    s       : ARRAY [0..31] OF CHAR;
    On      : BOOLEAN;

BEGIN
        (* 7-Aug-91 PFG   Get task's start and end dates. *)
    WITH MyContext DO
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        WITH TaskPtr^ DO
            Start := Plan.Dates.EarlyStart;
            End   := Plan.Dates.EarlyEnd;
        END;
        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
    END;

    WITH Assignment DO
        FOR Loop := 0 TO FormMappingRecords[ MyContext.CurrentForm ].FieldCount DO
            WITH Fields[ Loop ] DO
                CASE FormMappingRecords[ MyContext.CurrentForm ].FieldTable[ Loop ] OF
                | ResourceNameField     : 
                    Copy(Resource^.Name, CharValue^);
                | BillableField         : 
                    CardValue := ORD(Billable IN Attributes);
                | NumberField           : 
                    IF (PercentageEach = 0C) THEN
                        RealValue := Zero;
                        PercentageEach := 1C; (* 5-Feb-91 TGS *)
                    ELSE
                        RealValue := FLOAT(MaxRatePercent)/
                                     FLOAT(ORD(PercentageEach));
                    END;
                | PercentageField       : 
                    CardValue := ORD(PercentageEach);
                | TotalQuantity         : 
                    RealValue := ActualQuantity + YetToGoQuantity;
                | TotalBucks            :
                    RealValue := AssignmentDollars(Assignment,
                                                Start,      (* 7-Aug-91 PFG *)
                                                End,        (* 7-Aug-91 PFG *)
                                                AnAssignmentCostTypeSet{
                                                    IncludeToGo,
                                                    IncludeSpent,
                                                    IncludeExtras,
                                                    IncludeOvertime});
                | TotalAsTime           :
                    RealValue := WorkHoursToRealTime( ActualQuantity + YetToGoQuantity, ActualTimeUnits );
                | TotalUnits            :
                    CardValue := ORD(ActualTimeUnits);       (* 3/7/89 EGK *)
                | ActualUnitsField      :
                    GetMessage (ModuleNumber + 15 + ORD(ActualTimeUnits), CharValue^);
                | ActualQuantityField   :
                    IF (MyContext.CurrentForm = ResourceForm) THEN
                        RealValue := WorkHoursToRealTime( ActualQuantity, ActualTimeUnits );
                    ELSE
                        RealValue := ActualQuantity;
                    END;
                | ActualBucksField      :
                    RealValue := AssignmentDollars(Assignment,
                                                Start, (*  7-Oct-91 TGS *)
                                                End,   (* 12-Nov-90 PFG *)
                                                AnAssignmentCostTypeSet{
                                                    IncludeOvertime,
                                                    IncludeSpent,
                                                    IncludeExtras });   (* 25-Sep-90 RSC removed Extras *)
                                                                                      (* 28-Dec-90 AJL restored them. *)

                | YetToGoQuantityField  :
                    IF (MyContext.CurrentForm = ResourceForm) THEN
                        RealValue := WorkHoursToRealTime( YetToGoQuantity, ActualTimeUnits );
                    ELSE
                        RealValue := YetToGoQuantity;
                    END;
                | YetToGoBucksField     :
                    RealValue := AssignmentDollars(Assignment,
                                                Start,   (* 12-Nov-90 PFG *)
                                                End,     (*  7-Oct-91 TGS *)
                                                AnAssignmentCostTypeSet{
                                                    IncludeOvertime,
                                                    IncludeToGo} );     (* 25-Sep-90 RSC removed Extras *)

                | YetToGoUnitsField     :
                    GetMessage(ModuleNumber + 15 + ORD(ActualTimeUnits), CharValue^); (* "Days", ... *)
                | UnitOfMeasureField    :
                    Copy(Resource^.UnitOfMeasure, CharValue^);
                | ModeIndicator1,
                  ModeIndicator2        :
                    On := (NOT (ComputeByHours IN Attributes))
                          OR (MyContext.TaskMethod = AssignmentDriven);

                    Fill (CharValue^, ModeChar[On], 1);

                | ModeIndicator3        :
                    On := (ComputeByHours IN Attributes)
                          OR (MyContext.TaskMethod = AssignmentDriven);
                    Fill (CharValue^, ModeChar[On], 1);

                | ExtraCostsField       :
                    RealValue := ExtraCosts;

                (*
                | OvertimeField         :
                    RealValue := LongToReal(OvertimeHours);
                    RealValue := WorkHoursToRealTime(RealValue, OvertimeTimeUnits);  (* 12-Nov-90 PFG *)
                | ActualOvertimeField   :
                    RealValue := LongToReal(OvertimeHours - YetToGoOvertimeHours);
                    RealValue := WorkHoursToRealTime(RealValue, OvertimeTimeUnits);  (* 12-Nov-90 PFG *)
                | YetToGoOvertimeField  :
                    RealValue := LongToReal(YetToGoOvertimeHours);
                    RealValue := WorkHoursToRealTime(RealValue, OvertimeTimeUnits);  (* 12-Nov-90 PFG *)
                | OvertimeUnits         :
                    CardValue := ORD(OvertimeTimeUnits);       (* 3/7/89 EGK *)
                | ActualOvertimeUnits,
                  YetToGoOvertimeUnits  :
                    GetMessage (ModuleNumber + 15 + ORD(OvertimeTimeUnits), CharValue^);
                *)

                ELSE
                    FatalError();
                    (* Nothing to do?  That is odd.  We should not get here. *)
                END;
            END;
        END;
    END;
END MapAssignmentForm;



PROCEDURE RefreshContext();
VAR
    TaskPtr         : ATaskPtr;
BEGIN

    WITH MyContext DO
        IF (TaskInfoNeeded) THEN
            TaskPtr      := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
            WITH TaskPtr^ DO
                TaskDuration := duration;
                TaskMethod   := DurationMethod;
            END;
            StartStatus  := TaskPtr^.StartStatus;  (* Oops.  Same name! *)
            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
            TaskInfoNeeded := FALSE;
        END;
    END;

END RefreshContext;



(* There is an error; show it to the customer.
*)
PROCEDURE ShowError ( PhraseNumber : CARDINAL );
VAR
    MessageText     : ARRAY [0..255] OF CHAR;
    MessageTitle    : ARRAY [0..59]  OF CHAR;
BEGIN
    GetMessage (PhraseNumber, MessageText);
    GetMessage (PhraseNumber + 1, MessageTitle);
    WarningBox (MessageText, MessageTitle, NoHelp);
END ShowError;


(* Round, and convert a real into a cardinal.  Don't let it go over 65K.
*)
PROCEDURE RtoC( R : REAL ) : CARDINAL;
BEGIN
    R := R + 0.5;  (* Round up *)
    IF (R >= FMAXCARDINAL) THEN
        RETURN MAX(CARDINAL);
    ELSE 
        RETURN TRUNC(R);
    END;
END RtoC;



    (* It doesn't make sense to have the to go amount of something
       less than zero, when the planned amount is positive.
       That would mean that we somehow intend
       to supply some of the stuff in the future, while having 
       consumed an excess of it in the past--all on the same task.
       We cannot work less than no work in the future.

       As a compensation to allow tricks, allowing an assignment
       to actually supply something, we only forbid the negative
       to go amount on an assignment that is overall positive.  
       This permits a user to create an assignment of a negative
       amount of something intentionally, but avoids an accidental
       negative to go amount just by overspending the plan. 

       I suppose we could be really sophisticated and verify that the
       (signless) magnitude of the spending has not exceeded the 
       magnitude of the assigned amount, but that is overkill.

       If more was spent than planned, we change the plan to be
       as much as was spent, and change the to go amount to zero.

       There are three procedures here to allow us to warn the user
       in some cases where the proper process to fix the problem
       is not obvious.
    *)

    (* Determine if the spent amount exceeds the plan in a situation
       where that is not permitted. *)

PROCEDURE ExcessSpentAmount( VAR Assignment : AnAssignmentRecord;
                             VAR Regular, Overtime:BOOLEAN);
BEGIN
    Regular := FALSE;
    Overtime := FALSE;
    WITH Assignment DO
        IF (Resource^.Type = AccountingOnly) THEN
            IF (ActualQuantity + YetToGoQuantity >= Zero) AND
               (YetToGoQuantity < Zero) THEN
                Regular := TRUE;
            END;
        ELSE
            IF (MyContext.TaskMethod = EffortDriven) THEN
                (* Well . . . we make an exception for assignments to 
                   effort-driven tasks.  The effort on each assignment
                   doesn't need to balance out.  Instead the total
                   spent effort on the whole task cannot exceed the
                   total effort planned for the whole task.
                *)
            ELSE (* Not an assignment of a person to an effort-driven task. *)
                IF (ActualQuantity + YetToGoQuantity >= Zero) AND
                   (YetToGoQuantity < Zero) THEN
                    Regular := TRUE;
                END;
            END;
            (* Always check overtime. *)
            IF (OvertimeHours >= 0L) AND 
               (YetToGoOvertimeHours < 0L) THEN
                Overtime := TRUE;
            END;
        END;
    END;

END ExcessSpentAmount;


PROCEDURE CheckToGoAmount(VAR Assignment : AnAssignmentRecord;
                          VAR Ok : BOOLEAN);
VAR
    ExcessiveRegular : BOOLEAN;
    ExcessiveOvertime : BOOLEAN;
BEGIN
    ExcessSpentAmount(Assignment, ExcessiveRegular, ExcessiveOvertime);
    IF (ExcessiveRegular) THEN
        ShowError(SpentMoreThanPlan);
        Ok := FALSE;
    ELSIF (ExcessiveOvertime) THEN
        ShowError(SpentOTMoreThanPlan);
        Ok := FALSE;
    END;
END CheckToGoAmount;

    (* This procedure updates the assignment to remove negative
       overtime without asking.  It is used either when the 
       proper action is obvious, or as a last resort. *)

PROCEDURE AvoidNegativeToGo(VAR Assignment : AnAssignmentRecord;
                            VAR Values     : ARRAY OF AFieldValue;
                            VAR Ok : BOOLEAN );
VAR
    ExcessiveRegular : BOOLEAN;
    ExcessiveOvertime : BOOLEAN;
BEGIN
    ExcessSpentAmount(Assignment,ExcessiveRegular, ExcessiveOvertime);
    WITH Assignment DO
        IF (Resource^.Type = AccountingOnly) THEN
            IF (ExcessiveRegular) THEN
                YetToGoQuantity := Zero;
            END;
        ELSE
            (* Update regular effort. *)
            IF (ExcessiveRegular) THEN
                UpdateTotalEffort( Assignment,
                                   WorkHoursToRealTime(ActualQuantity,
                                                       ActualTimeUnits),
                                   Values,
                                   Ok 
                                 );
            END;
            (* Update overtime. *)
            IF (ExcessiveOvertime) THEN
                OvertimeHours := OvertimeHours - YetToGoOvertimeHours;
                YetToGoOvertimeHours := 0L;
            END;
        END;
    END;
END AvoidNegativeToGo;



PROCEDURE UpdateTotalEffort( VAR Assignment     : AnAssignmentRecord;
                                 NewTotalEffort : REAL;
                             VAR Values         : ARRAY OF AFieldValue;
                             VAR Ok : BOOLEAN );
VAR
    RelatedField : CARDINAL;
    i            : CARDINAL;
    R, R2        : REAL;
BEGIN
    WITH Assignment DO
        IF (MyContext.TaskMethod = AssignmentDriven) THEN
            NewTotalEffort := RealTimeToWorkHours (NewTotalEffort, ActualTimeUnits);
            YetToGoQuantity := NewTotalEffort - ActualQuantity;
        ELSIF (NewTotalEffort = Zero) THEN
            EXCL (Attributes, ComputeByHours);
            IF (MyContext.TaskDuration <> NoDuration) THEN     (* 15-Sep-91 *)
                MaxRatePercent := 0;
            END;
        ELSIF (MyContext.TaskDuration = NoDuration) THEN
            ShowError (EffortWithoutDuration);
            Ok := FALSE;
        ELSIF (MyContext.TaskMethod = DurationDriven) THEN
            RelatedField := FindField (NumberField);
            R2:= Values[RelatedField].RealValue;
            i := NewPercentage (NewTotalEffort, ActualTimeUnits, R2);
            IF (PercentageOK (i, R2, Resource, MyContext.StartStatus)) THEN
                PercentageEach := CHR(i);
                MaxRatePercent := RtoC (FLOAT(i) * R2);
                NewTotalEffort := RealTimeToWorkHours (NewTotalEffort, ActualTimeUnits);
                IF (NewTotalEffort <> (ActualQuantity + YetToGoQuantity)) THEN
                    INCL (Attributes, ComputeByHours);
                END;
                YetToGoQuantity := NewTotalEffort - ActualQuantity;
            ELSE
                Ok := FALSE;
            END;
        ELSE
            (* Effort should not be enterable on 
               effort-driven tasks. *)
            FatalError();
        END;
    END;
END UpdateTotalEffort;



(* Given a new total assignment effort, try to compute a new
   percentage and optionally, a new number.
*)
PROCEDURE NewPercentage (     TotalEffort       : REAL;
                              Units             : ADurationUnit;
                          VAR NumberOf          : REAL ) : CARDINAL;
VAR
    TaskEffort          : REAL;
    TotalPercent        : REAL;
    TempReal            : REAL;
    Percentage          : CARDINAL;
    TaskPtr             : ATaskPtr;
    ok                  : BOOLEAN;
BEGIN
    NumberOf    := MyContext.EnteredNumber;
    TaskEffort  := DurationToReal(MyContext.TaskDuration) / FSMUPH;
    TotalEffort := RealTimeToWorkHours (TotalEffort, Units);
    IF (TaskEffort = Zero) OR (NumberOf = Zero) THEN
        TempReal := Zero;
    ELSE

        (* 13-Mar-90 RSC If the number does not work out,
                         return to the last entered number, if
                         that was different.
        *)
        TotalPercent := OneHundred * (TotalEffort / TaskEffort);
        TempReal     := TotalPercent / NumberOf;
    END;
    Percentage := RtoC (TempReal);

    IF (Percentage > MaxPercent) THEN
        WITH MyContext.CurrentAssignment^ DO
            YetToGoQuantity := TotalEffort - ActualQuantity;
        END;
        IF (MakeAssignmentRateMatchTotal( MyContext.CurrentAssignment^,
                                          MyContext.TaskDuration )) THEN
            WITH MyContext.CurrentAssignment^ DO
                Percentage := ORD(PercentageEach);
                IF (Percentage = 0) THEN
                    NumberOf   := Zero;
                    Percentage := 1; (* 5-Feb-91 TGS *)
                ELSE
                    NumberOf   := FLOAT(MaxRatePercent)/FLOAT(Percentage);
                END;
            END;
        END;
    END;

    RETURN Percentage;

END NewPercentage;



PROCEDURE RateAvailable(     Rate          : REAL;
                             Availability  : ADateList ) : BOOLEAN;

VAR
    i                   : CARDINAL;
    NumDates            : CARDINAL;
    Start, End          : ABigTime;
    Avail               : AnAvailabilityRate;
    ok                  : BOOLEAN;

BEGIN                   (* RateAvailable *)

    IF (Availability = ADateList(NIL)) THEN
        ok := (Rate <= FLOAT(DefaultAvailabilityAmount) *
                FLOAT(DefaultAvailabilityPercent));
    ELSE
        ok := FALSE;
        i := 1;
        NumDates := NumberOfDatesInList( Availability, 
                                         TSIZE( AnAvailabilityRate ));
        LOOP
            IF ((ok) OR (i > NumDates)) THEN
                EXIT;
            END;
            IF (NOT GetDateListEntry( Availability, i, Start, End, Avail )) THEN
                FatalError();
            END;
            WITH Avail DO
                IF (Rate <= (FLOAT(Percent) * FLOAT(Amount))) THEN
                    ok := TRUE;
                END;
            END;
            INC( i );
        END;
    END;

    RETURN ok;

END RateAvailable;






(* Is the proposed new percentage and number ok?
*)
PROCEDURE PercentageOK ( P : CARDINAL;  (* Proposed percentage *)
                         N : REAL;      (* Proposed number ( N @ P%) *)
                         R : AResourcePointer;
                         S : AStartStatus      ) : BOOLEAN;
VAR
    NewRate               : REAL;
    NumbersInRange,
    ok,
    UpperBoundsImportant  : BOOLEAN;

BEGIN

        (* Compute the effect of Percent times Number. *)
        (* 5-Feb-91 TGS moved following statement here from further down
           -- we were comparing NewRate before it had been initialized... *)

    NewRate := N * FLOAT(P);

        (* Check that the numbers as entered are within the range of
           what we can record. *)

    NumbersInRange := (P = 0)                       OR  (* 24-May-91 PFG *)
                      ((P <= MaxPercent)            AND
                       (N <= FMAXCARDINAL / FLOAT(P)) AND
                       (NewRate < FMAXCARDINAL));
    IF (NumbersInRange) THEN
        UpperBoundsImportant := ((S = FutureS) AND (R^.Type = Employable));

        IF (UpperBoundsImportant) THEN
                (* Check upper bounds. *)
            ok := RateAvailable( NewRate, R^.Availability );
        ELSE
            ok := TRUE;
        END;
    ELSE
        ok := FALSE;
    END;

    RETURN ok;

END PercentageOK;




  (* Check Assignment Form  -  Generic Check Proc for an assignment form. *)

PROCEDURE CheckAssignmentForm( Form               : AForm;
                               FieldNo            : AFieldNo;
                           VAR Values             : ARRAY OF AFieldValue;
                               CheckReason        : ACheckReason;
                           VAR Code               : CARDINAL ) : BOOLEAN;
VAR
    OldCode         : CARDINAL; 
    i,
    Loop            : CARDINAL;
    Completed,
    ToGo            : AnAssignmentSummary;  (* Dummys *)
    Field           : AnAssignmentField;
    MapNeeded,
    Ok              : BOOLEAN;





    PROCEDURE ConsistentPercent() : BOOLEAN;
    BEGIN
        WITH MyContext.CurrentAssignment^ DO
                (* We don't care about the "effort" of costs. *)
            IF (Resource^.Type = AccountingOnly) THEN
                RETURN TRUE;
            END;
                (* If there is effort, there must be a rate. *)
            IF (YetToGoQuantity <> Zero) OR (ActualQuantity <> Zero) THEN
                IF (MaxRatePercent = 0) THEN
                    RETURN FALSE;
                END;
            END;
        END;
        RETURN TRUE;
    END ConsistentPercent;


    (* Save the field passed in into the assignment record.
    *)
    PROCEDURE SaveField( VAR Field      : AFieldValue;
                         VAR Assignment : AnAssignmentRecord;
                             WhichField : AnAssignmentField;
                         VAR Ok         : BOOLEAN            );
    VAR 
        RelatedField : CARDINAL;
        RelatedField2: CARDINAL;
        R,R2,R3      : REAL;
        i,n          : CARDINAL;


        (* Figure out the costs of overtime and extras for
           spent, togo, or both.
        *)
        PROCEDURE MiscCosts( Type : AnAssignmentCostTypeSet ) : REAL;
        BEGIN
            WITH MyContext DO
                RETURN (AssignmentCost( Assignment,
                                        AsOfDate,
                                        AsOfDate,

                                        Type +

                                        AnAssignmentCostTypeSet{
                                            IncludeExtras,
                                            IncludeOvertime} )

                      - AssignmentCost( Assignment,
                                        AsOfDate,
                                        AsOfDate,
                                        Type ));
            END;
        END MiscCosts;



    BEGIN (* SaveField *)

          (* The customer made a change to a field.  See if we act on it. *)
    WITH Assignment DO
        WITH Field DO
            CASE WhichField OF

            | BillableField         : 

                IF (CardValue = 0) THEN
                    EXCL(Attributes, Billable);
                ELSE
                    INCL(Attributes, Billable);
                END;
                SetProtection();

            | NumberField           : 

                IF (RealValue > Zero) AND (PercentageEach = 0C) THEN
                    PercentageEach := 1C; (* so we register. RSC 1-Jun-89 *)
                END;
                IF (RealValue > 650.0) THEN (* 5-Feb-91 TGS *)
                    RealValue := 650.0;
                    Burp();
                END;
                RelatedField := FindField( PercentageField );
                IF (PercentageOK (Values[RelatedField].CardValue, RealValue,
                                  Resource, MyContext.StartStatus)) THEN
                    R := FLOAT(ORD(PercentageEach)) * RealValue;
                    MaxRatePercent          := RtoC( R );
                    WITH MyContext DO
                        IF (EnteredNumber <> RealValue) THEN
                            EXCL (Attributes, ComputeByHours);
                            MyContext.EnteredNumber := RealValue;
                        END;
                    END;
                ELSE
                    ShowError (PercentTooBig);
                    Ok := FALSE;
                END;

            | PercentageField       : 
                
                RelatedField   := FindField( NumberField );
                IF (PercentageOK (CardValue, Values[RelatedField].RealValue,
                                  Resource, MyContext.StartStatus)) THEN
                    IF (MyContext.TaskMethod <> AssignmentDriven) THEN
                        IF (PercentageEach <> CHR(CardValue)) THEN
                            EXCL (Attributes, ComputeByHours);
                        END;
                    END;
                    PercentageEach := CHR(CardValue);
                    R              := Values[ RelatedField ].RealValue (* 18-Feb-92 TGS *) 
                                        * FLOAT(CardValue);
                    MaxRatePercent := RtoC( R );
                ELSE
                    ShowError (PercentTooBig);
                    Ok := FALSE;
                END;

            | TotalQuantity         : 
                
                YetToGoQuantity := RealValue - ActualQuantity;

            | TotalBucks            : 
                
                R  := AverageResourceRate( Resource, AsOfDate, AsOfDate, FALSE );    (* 12-Nov-90 PFG Use AsOfDate *)

                IF (R <> Zero) THEN
                    R := (RealValue 
                         - MiscCosts(AnAssignmentCostTypeSet{IncludeSpent,IncludeToGo})
                         ) / R;
                    IF (R <> (ActualQuantity + YetToGoQuantity)) THEN
                        INCL( Attributes, ComputeByHours );
                        R2  := YetToGoQuantity;
                        YetToGoQuantity := R - ActualQuantity;
                        UpdateTotalEffort( Assignment, 
                                           WorkHoursToRealTime
                                            (ActualQuantity+YetToGoQuantity,
                                             ActualTimeUnits), 
                                           Values, Ok );
                        IF (NOT Ok) THEN
                            ShowError (ImpliedPercentTooBig);
                            YetToGoQuantity := R2;
                        END;
                    END;
                END;

            | TotalAsTime           : 

                UpdateTotalEffort( Assignment, RealValue, Values, Ok );
                IF (NOT Ok) THEN                               (* 05-Mar-92 *)
                    ShowError (ImpliedPercentTooBig);
                END;

            | TotalUnits            : 
                
                IF (ComputeByHours IN Attributes) AND
                   (MyContext.TaskMethod <> AssignmentDriven) THEN
                    RelatedField := FindField (NumberField);
                    R2:= Values[RelatedField].RealValue;
                    RelatedField := FindField (TotalAsTime);
                    R := Values[RelatedField].RealValue;
                    i := NewPercentage (R, VAL(ADurationUnit,CardValue), R2);
                    IF (PercentageOK (i, R2, Resource,
                                      MyContext.StartStatus)) THEN
                        PercentageEach := CHR(i);
                        MaxRatePercent := RtoC (FLOAT(i) * R2 );
                    ELSE
                        ShowError (ImpliedPercentTooBig);
                        Ok := FALSE;
                    END;
                END;
                RelatedField    := FindField( TotalAsTime );
                ActualTimeUnits := VAL(ADurationUnit, CardValue);
                R := RealTimeToWorkHours( Values[RelatedField].RealValue, ActualTimeUnits );
                YetToGoQuantity := R - ActualQuantity;

            | ActualQuantityField   : 
                
                R := ActualQuantity + YetToGoQuantity;  (* Total *)
                R2:= YetToGoQuantity;
                R3:= ActualQuantity;

                IF (MyContext.CurrentForm = ResourceForm) THEN
                    RealValue   := RealTimeToWorkHours( RealValue, ActualTimeUnits );
                END;
                ActualQuantity  := RealValue;
                YetToGoQuantity := R - ActualQuantity;
                    (* If spent exceeds plan, update plan. *)
                AvoidNegativeToGo(Assignment,Values,Ok);

                IF (NOT Ok) THEN                        (* 15-Apr-92 TGS *)
                (* user entered a value that implied too large a rate;
                   don't let 'em get away with it *)
                    ShowError (ImpliedPercentTooBig);
                    YetToGoQuantity := R2;
                    ActualQuantity  := R3;
                ELSIF ((R2 + R3) <> (ActualQuantity + YetToGoQuantity)) THEN
                    (* sometimes this doesn't happen in UpdateTotalEffort() *)
                    INCL(Attributes, ComputeByHours)
                END;

            | ActualBucksField      : 
                
                R := AverageResourceRate( Resource, AsOfDate, AsOfDate, FALSE );     (* 12-Nov-90 PFG use AsOfDate *)
                R2:= YetToGoQuantity;
                R3:= ActualQuantity;

                IF (R <> Zero) THEN
                    R := (RealValue
                      - MiscCosts(AnAssignmentCostTypeSet{IncludeSpent})) / R;
                    IF (R < Zero) THEN
                            (* Spent dollars must include Extra dollars. *)
                        DisplayMessage( ModuleNumber + 11 );
                        Burp();
                        Ok := FALSE;
                        RETURN;
                    END;
                END;
                YetToGoQuantity := (ActualQuantity + YetToGoQuantity) - R;
                ActualQuantity  := R;
                    (* If spent exceeds plan, update plan. *)
                AvoidNegativeToGo(Assignment,Values,Ok);

                IF (NOT Ok) THEN                        (* 15-Apr-92 TGS *)
                    ShowError (ImpliedPercentTooBig);
                    YetToGoQuantity := R2;
                    ActualQuantity  := R3;
                ELSIF ((R2 + R3) <> (ActualQuantity + YetToGoQuantity)) THEN
                    INCL(Attributes, ComputeByHours)
                END;

                    (* Leave the ACTUAL the same.
                        1) Compute the ACTUAL as Total - YTG.
                        2) Set the total.
                        3) Compute the YTG as Total-ACTUAL.
                    *)

            (* 16-May-91 TGS
            | OvertimeField         : 
                
                R := LongToReal(OvertimeHours - YetToGoOvertimeHours);
                R2 := RealTimeToWorkHours(RealValue, OvertimeTimeUnits);
                OvertimeHours := RealToLong(R2);
                YetToGoOvertimeHours := OvertimeHours - RealToLong(R);

            | OvertimeUnits         : 
                
                R := LongToReal(OvertimeHours - YetToGoOvertimeHours);
                RelatedField := FindField( OvertimeField );
                OvertimeTimeUnits := VAL(ADurationUnit, CardValue);
                R2 := RealTimeToWorkHours( Values[RelatedField].RealValue, OvertimeTimeUnits );
                OvertimeHours := RealToLong(R2);
                YetToGoOvertimeHours := OvertimeHours - RealToLong(R);

            | ActualOvertimeField   : 
                
                R := LongToReal(OvertimeHours) - RealTimeToWorkHours(RealValue, OvertimeTimeUnits);
                YetToGoOvertimeHours := RealToLong(R);
                    (* If spent exceeds plan, update plan. *)
                AvoidNegativeToGo(Assignment,Values,Ok);

            | YetToGoOvertimeField  : 
                
                R := RealTimeToWorkHours(RealValue, OvertimeTimeUnits);
                YetToGoOvertimeHours := RealToLong(R);
            *)

            | ExtraCostsField       : 
                
                ExtraCosts := RealValue;

            ELSE
                (* Nothing to do?  Then don't do nuthin' *)
            END;

                (* Always check that the spent doesn't exceed the 
                   planned amount unless that is permitted. *)
            CheckToGoAmount(Assignment,Ok);
        END;
    END;
    END SaveField;



    PROCEDURE SetProtection();
    VAR
        i           : CARDINAL;
        ProtectIt   : BOOLEAN;
        RateList    : ARateList;

    BEGIN
        IF (MyContext.CurrentForm <> FixedCostForm) THEN
                (* If the costs of this assignment are not going to be billed,
                   don't confuse the user by displaying them. *)
            ProtectIt := NOT (Billable IN MyContext.CurrentAssignment^.Attributes)
                        (* 17-Jan-92 TGS Add this case from below *)
                         OR ((MyContext.CurrentForm = ResourceForm) AND
                             ((NOT UsesCostTracking) OR
                             (MyContext.TaskMethod = EffortDriven)));

                (* However, if the unit cost has varying rates, then the
                   field is not enterable because we could not work
                   backwards from the rate to the quantity without knowing
                   the date. *)
            IF (NOT ProtectIt) THEN
                RateList := MyContext.CurrentAssignment^.Resource^.ActualRates;
                IF (RateList <> ARateList(NIL)) THEN
                    ProtectIt  := (NumberOfRatesInList(RateList) > 1);
                END;
            END;

            i  := FindField( TotalBucks );
            (*  Make sure it's not hidden before we turn protection off.  *)
            ProtectIt := ProtectIt OR (FieldIsHidden(Form, i, Values)); (* 14-Aug-91 PFG *)
            SetFieldProtection(Form,i,Values,ProtectIt);
            IF (UsesCostTracking) THEN
                i  := FindField( ActualBucksField );
                SetFieldProtection(Form,i,Values,ProtectIt);
            END;
        END;

        IF (MyContext.CurrentForm = ResourceForm) THEN
            ProtectIt := (MyContext.TaskMethod = EffortDriven);
            i  := FindField (TotalAsTime);
            SetFieldProtection (Form, i, Values, ProtectIt);

            (* 17-Jan-92 TGS Do this above, not here...
            i := FindField( TotalBucks );
            SetFieldProtection( Form, i, Values, ProtectIt );
            *)
        END;
    END SetProtection;




BEGIN   (* CheckAssignmentForm *)
    OldCode := Code;
    Code        := 0;
    Ok          := TRUE;
    MapNeeded   := FALSE;

    RefreshContext();

    CASE CheckReason OF
    | CheckFormEntry    :
        IF (FieldNo = 0) THEN
            SetProtection();
        END;

    | CheckFormExit     :
            (* 25-Sep-90 RSC removed limit check.  No easy way to
               tell WHEN the task might be scheduled.
            *)
        IF (MyContext.CurrentForm = ResourceForm) AND
           (NOT ConsistentPercent()) THEN
            ShowError(EffortWithoutRate);
                (* Put cursor on number field. *)
            Code := CARDINAL({15}) + FindField(NumberField);
            RETURN FALSE;
        END;
            (* Avoid assignments that wrongly have a spent amount
               exceeding the plan. *)
        CheckToGoAmount(MyContext.CurrentAssignment^,Ok);

    | CheckFieldEntry   :

    | CheckFieldKey     :
        Code := CARDINAL({14}) + OldCode;   (* restore the key. *)  (* AJL 6/12/89 *)
        Ok := FALSE;    (* RSC 27-Apr-89 *)
    ELSE
        WITH FormMappingRecords[ MyContext.CurrentForm ] DO
            Field := FieldTable[ FieldNo ];

            IF (CheckReason = CheckFieldChange) THEN

                SaveField(Values[FieldNo], MyContext.CurrentAssignment^, 
                          Field, Ok);
                WITH MyContext.CurrentAssignment^ DO
                    IF ( VaryingAssignment <> AnExtHandle(NIL) ) THEN (* 6-Apr-92 TGS *)
                        DisposeVaryingAssgnList(VaryingAssignment);
                        VaryingAssignment := AnExtHandle(NIL);
                    END;
                END;

            END;

            IF (Ok AND (CheckReason = CheckFieldChange)) THEN  (* 20-Aug-91 TGS *)
                WITH MyContext DO
                    ComputeTaskNodeCosts( TaskNode );
                    TaskInfoNeeded := TRUE;
                END;
            END;

            MapNeeded := TRUE;
        END;
    END;

    IF (Ok AND MapNeeded) THEN

        MapAssignmentForm( MyContext.CurrentAssignment^, Values );

        (* Redisplay any fields that need redisplay *)

        WITH FormMappingRecords[ MyContext.CurrentForm ] DO
            FOR Loop := 1 TO FieldCount DO
                IF (FieldTable[Loop] IN RedisplayMask) THEN
                    ShowValue( Form, Loop, Values );
                END;
            END;
        END;
    END;

    RETURN Ok;

END CheckAssignmentForm;








(* Do Assignment Form - Do an assignment form and any subforms.

    Preconditions
                    TaskTreeNode    is the node of the task this assignment
                                    belongs to.
                    Assignment      The Assignment record's pointer.

    Postconditions
                    The assignment record may have been changed.  The task
                    may have been recalc'd.

                    IF FALSE, ESC was pressed on the form.
*)
PROCEDURE DoAssignmentForm(     TaskTreeNode    : ATreeNode;
                            VAR Assignment      : AnAssignmentPointer
                          ) : BOOLEAN;
CONST
    MaxStringFieldsOnAForm = 12;

VAR
    Task                : ATaskPtr;
    AssignmentArray     : AnAssignmentArray;
    OldVaryingAss       : AVaryingAssgnList;
    FormNumber          : CARDINAL;
    Loop, i             : CARDINAL;
    Code                : ACode;
    OldAssignment       : AnAssignmentRecord;
    Values              : ARRAY [0..MaxAssignmentFields] OF AFieldValue;
    NameFields          : ARRAY [1..MaxStringFieldsOnAForm] OF AStringValue;
    Style               : ACostStyle;
    Ok                  : BOOLEAN;

BEGIN

    Style         := Assignment^.Resource^.CostStyle;
    OldAssignment := Assignment^;

    (* 7-Apr-92 TGS : need to make a copy of the VaryingAssignment, 
                      because CheckAssignmentForm can discard this object.

                      If we ESC from the form, and the assignment's
                      VaryingAssignment is NIL, restore the old
                      VaryingAssignment. Else, discard the copy; we didn't
                      blast the original.

                      If we F10 from the assignment form, discard the copy.
    *)
    CopyVaryingAssgnList( OldVaryingAss, 
                          Assignment^.VaryingAssignment, 
                          ExtMedium );

    IF (OldVaryingAss = AVaryingAssgnList(NIL)) AND
       (Assignment^.VaryingAssignment <> AVaryingAssgnList(NIL)) THEN 
        ErrorPhrase( 17813 );
        RETURN FALSE;
    END;

        (* Just make extra sure this is true.... *)
    IF (Style = CAmount) THEN
        Assignment^.ExtraCosts := Zero;
    END;

        (* Well . . . it seems that the current assignment form only
           allows entry of overtime hours in hours; However, nobody actually
           sets the OvertimeTimeUnits to hours, and the user cannot because
           it is no longer an enterable field!  Furthermore, the field
           is initialized to Days in Assignments.mod, so whatever the user
           thinks is entered in hours really gets entered in Days.  Pretty.
           Let's fix that here.  I set the value here, rather than in some
           other location in the program, because the rest of the program
           is generally prepared to handle any units; it is only a limit
           of the form that the only unit enterable is hours.  So, if you
           change the form, change this.
           AJL 12/28/90
        *)

    Assignment^.OvertimeTimeUnits := Hours;     (* To match the 12/90 form. *)

    IF (Assignment^.Resource^.Type = Employable) THEN
        FormNumber        := RsrcForm[ UsesCostTracking ];
    ELSE
        FormNumber        := FormNumbers[ Style, UsesCostTracking ];
    END;

    WITH MyContext DO
        TaskNode            := TaskTreeNode;
        CurrentAssignment   := Assignment;
        CurrentForm         := FormKind[ Style ];

        (* 13-Mar-90 RSC Setup new field. *)

        WITH Assignment^ DO
            IF (PercentageEach = 0C) THEN           (* 21-Aug-90 PFG *)
                EnteredNumber := Zero;
            ELSE
                EnteredNumber := FLOAT(MaxRatePercent)/
                                 FLOAT(ORD(PercentageEach));
            END;
        END;

        TaskInfoNeeded      := TRUE;
    END;

    RefreshContext();  (* Map the task info in. *)

    (* Make the strings point to the stack, not the heap. *)

    i := 1;
    WITH FormMappingRecords[ MyContext.CurrentForm ] DO
        FOR Loop := 0 TO FieldCount DO
            IF (Loop > HIGH(Values)) THEN FatalError(); END;

            IF (FieldTable[Loop] IN AllocateChars) THEN
                IF (i > HIGH(NameFields)) THEN FatalError(); END;
                Values[Loop].CharValue := ADR(NameFields[i]);
                INC(i);
            ELSE
                Values[Loop].CharValue := NIL; (* Maybe catch errors *)
            END;
        END;
    END;

    MapAssignmentForm( MyContext.CurrentAssignment^, Values );

    Code := DoForm( 1, 10,79,20, FormNumber, TRUE, Values, CheckAssignmentForm );

    IF (Code = CancelKey) THEN
        IF (Assignment^.VaryingAssignment = AVaryingAssgnList(NIL)) THEN
            (* either there never was one or we blasted it; either way,
               restore to previous VaryingAssignment object, which may be NIL *)
            Assignment^ := OldAssignment;
            Assignment^.VaryingAssignment := OldVaryingAss;
        ELSE
            (* we didn't blast the VaryingAssignment; don't need to restore it *)
            Assignment^ := OldAssignment;
            DisposeVaryingAssgnList( OldVaryingAss );
        END;
    ELSE  (* F10 *)
        DisposeVaryingAssgnList( OldVaryingAss ); (* won't be needing this *)

        Task  := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
        WITH Task^ DO

            (* 7-Apr-92 TGS If the task is effort driven, and we made a
                            change to effort numbers, such that the
                            VaryingAssignment of the current assignment
                            no longer exists, we can no longer
                            trust the VaryingAssignments of the other
                            assignments on this task.  Blast 'em. *)

            IF (DurationMethod = EffortDriven) AND
               (Assignment^.VaryingAssignment = AVaryingAssgnList(NIL)) THEN
                Loop := LockObjectArray( Plan.Assignments,
                                        AssignmentArray, TSIZE( AnAssignmentRecord ) );
                i := 0;
(*$O-*)
                WHILE (i < Loop) DO
                    WITH AssignmentArray^[i] DO
                        IF ( VaryingAssignment <> AVaryingAssgnList(NIL) ) THEN (* 6-Apr-92 TGS *)
                            DisposeVaryingAssgnList(VaryingAssignment);
                            VaryingAssignment := AnExtHandle(NIL);
                        END;
                    END;
                    INC(i);
                END;
(*$O=*)
                ReleaseObject( Plan.Assignments );
            END;
        END;

        TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
    END;

    RETURN (Code = ExitKey);

END DoAssignmentForm;





PROCEDURE DoTLTaForm();
VAR
    Context : POINTER TO AnOverlayContext;
BEGIN
    Context := OverlayContext();

    Context^.ReturnValue := DoAssignmentForm( Context^.TaskTreeNode,
                                              Context^.Assignment );
END DoTLTaForm;







CONST  TRAS = 21;
       TUCA = 23;
       TFCA = 25;
       TVCS = 45;  (* RSC 2/18/88 *)
      STRAS = 19;  (* Simple forms:     (RSC 9/3/87)  *)
      STUCA = 30;
      STFCA = 31;
      STVCS = 46;  (* RSC 2/18/88 *)




BEGIN
    FormNumbers[ CAmount         , TRUE ] :=  TFCA;
    FormNumbers[ CAmount         , FALSE] := STFCA;
    FormNumbers[ CAmountRate     , TRUE ] :=  TUCA;
    FormNumbers[ CAmountRate     , FALSE] := STUCA;
    FormNumbers[ CAmountRateTime , TRUE ] :=  TVCS;
    FormNumbers[ CAmountRateTime , FALSE] := STVCS;

    RsrcForm[                      TRUE ] :=  TRAS;
    RsrcForm[                      FALSE] := STRAS;

    FormKind   [ CAmount                ] := FixedCostForm;
    FormKind   [ CAmountRate            ] := UnitCostForm;
    FormKind   [ CAmountRateTime        ] := ResourceForm;  

    ModeChar[FALSE] := " ";
    ModeChar[TRUE]  := CHR(26);   (* right-arrow *)


    OverlayID := ImAnInstallableOverlay(DoTLTaForm, AnOverlayProc(NIL));       (* 19-Jan-88 LAA *)
    DoTLTaForm();

END TLTaForm.
