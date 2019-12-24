IMPLEMENTATION MODULE ResAvailableResources;
(*V2=PRINT WITH debugging printouts. *)
(*V222=STATS, statistics on number of cells *)
                 
    (* This module provides procedures to query and update
       the resource availability structures. 

       MODIFICATION HISTORY:

       Feb. 16, 89  JES -Created to implement an idea of AJL's to
                         use resource usage "histograms" to speed
                         up resource levelling. Resource levelling 
                         now uses these
                         procedures, that explicitly give the amounts
                         of resources available at any point in time,
                         instead of repeatedly searching through        
                         task lists to get this information.

                         Use of these procedures (in a prudent way)
                         has allowed us to increase the speed of
                         resource levelling by a factor of 60 in one
                         case. In general, the more tasks in the
                         schedule, the greater the increase in speed.
                         (Very small schedules will tend to be a few        
                         seconds slower with this method, since
                         searching through a task list with only a few
                         tasks didn't take very long in the first place.)
                
                         "Resource availability cells"
                         are used. The cells
                         are arranged in a linked list (all objects,
                         in both methods, are FlexStor objects). Each
                         cell gives a date range and the amount of
                         the resource available in that range. An
                         initial cell is created representing the entire
                         calendar, and additional cells are created
                         whenever the amount of the resource changes in
                         some interval. A cell is collapsed into its
                         its neighboring cell whenever its amount becomes
                         equal to the amount in the neighboring cell.
                         Thus, unnecessary cells are never kept lying
                         around, so the amount of storage used is kept
                         at a minimum. The disadvantage of this method
                         is that query procedures must search through
                         the cells starting at 0 for information about
                         any date range, even one towards the end of                         
                         calendar. This is a problem only if there is                         
                         a large number of cells. In practise, in every
                         we have seen so far, 80 cells is the maximum
                         that have been created. (Older schedules that
                         have been modified etc over time may contain
                         more "wrinkles", but we have not yet seen this
                         effect. Also, allowing varying resource
                         availability will of course increase the number                        
                         cells needed right off the bat.) 

        
       July 12, 89 - JES Modified to exit gracefully when flexstore create
                         fails.
       July 24, 89 - JES Fixed bug # 708 - if a task goes past end of calendar
                     (due to non-robustness of the interface that requests,
                      but does not require, that the user change either the
                      calendar precision or task durations to avoid this),
                     we now set calc error and return instead of trying to
                     continue scheduling resources. This fixes bug where
                     the ScheduleResources procedure "ran out of cells"
                     (i.e., got to the end of the linked list but still
                     had not covered the task's duration).

    Aug. 28, 89 - AJL Fixed some of the PRINT imports.
    Aug-30-89   AJL     -Changed name of "InsufficientVirtualMemory" to
                         "SchedulingAbandoned". 
    Oct-16-89   JES   Started to modify to support multiple resource
                      calendars. Removed some inapplicable procedures.
    Jul 18 90   JES   Added procedure "CheckResourceOnDate". 
    
    Jul 21 90   JES   Removed initialization and flush procedures, since
                       they are now done elsewhere.
    Jul 24 90   JES   Moved CreateNewCell and CellContainingDate to
                       ResCal module. Also made some fixes necessary
                       because of the new meaning of EndDate in the
                       availability cell. 
    Jul 31 90   JES   Added parameter "AllowVacations" to various
                        procedures in support of multiple calendars.
   Sep 06, 90   JES -added parameter "AllowOverbookings" to
                        FirstDateHaveResourceAmount
   Sep 27, 90   AJL   Modified the ScheduleLongAmount procedure so that it
                      doesn't split cells when s start date or end date is 
                      exactly at the cell boundary.
   Oct  4, 90   AJL - Added more tracing.
                    - Modified the ScheduleLongAmount so that the
                      decision to split the start cell is based on 
                      StartDate > StartCellStartDate (not checking the
                      end dates) and the decision to split the end cell is
                      based on EndDate > EndCellStartDate (not also
                      EndDate < EndCellEndDate).  In addition, since
                      the EndCell sometimes begins on the very moment that
                      the subtracting period ends, I modified the subtracting
                      loop to avoid a cell unless its StartDate is < the 
                      period EndDate.
   Oct-18-90 AJL/CL - Rewrite ScheduleLongAmount and CollapseIntoPrevious
                      to use the new doubly linked availability list.
                    - Modify FirstDateHaveResourceAmount, DisplayNumberOfCells,
                      and MaxEndDateForResourceAmount also to use the head
                      cell as a boundary for searching thru the list.
                    - Remove the unused Dummy from DisplayNumberOfCells.
   Oct-30-90  CL    - IMPORT MaxDate from Timei instead of ResConstants.
   Nov 8, 90  JES   - undid some changes and comments made by CL while
                        making the above changes
   Nov 8, 90  JES   - added procedure FirstDateLevelIsAboveZero, to
                      support contouring for effort-driven split tasks.
   Nov 12, 90 JES   - added "StartSearchDate" and "EndSearchDate" parameters
                       to procedures FindFirstDateLevelIsAboveZero and 
                       FindFirstDateHaveResourceAmount.
   Nov 19, 90 JES  - added support for Honor-Days-Off flag.
   Nov 21, 90 AJL  - There were places where objects were being locked but
                     might not be released.  Fixed at least some of them,
                     in CollapsIntoPrevious and ScheduleLongAmount.
                   - Changed some indentation.
                   - Fixed bugs in FindFirstDateHaveResourceAmount and
                     FindFirstDateLevelIsAboveZero.  The bug was that the
                     date found was sometimes stored into a variable called
                     "FirstDate" which was never used again.  Now, result
                     gozinta the DateFound.
   Nov 26  90 AJL  - Removed some setting of flags prior to calling FatalError.
                   - Test for date >= MaxDate in ScheduleLongAmount.
   Nov 29, 90 JES  - Removed unused import MaxResourcesPerTask.
   Dec 20, 90   JES -added procedure FindLastDateHaveResourceAmount.
   Dec 21, 90   JES -moved procedure AllResourcesAreAvailable into
                     here from ResStart, so could be called also from
                     ResLates.
   Dec 28, 90   JES -Added procedure AllTaskResourcesAreAvailable -
                     just like AllResourcesAreAvailable but operates
                     on a task instead of an assignment array.
   Jan  3, 91  JES -Added procedures ScheduleLateResource and
                    FreeLateResource, analogs of ScheduleResource and
                    FreeResource that reference the LateResidueAvailProfile
                    instead of the ResidueAvailProfile of the resource.

                    Changed procedure ScheduleLongAmount to take,
                    instead of a resource, an ExtHandle as a parameter.
                    This handle will be the resource's residue avail
                    profile, if invoked by ScheduleResource or 
                    FreeResource; and the resource's late residue avail
                    profile, if invoked by ScheduleLateResource or
                    FreeLateResource.
   Jan 8,  91   JES-Fixed bug in FindFirstDateHaveResourceAmount, where
                     EndSearchAt boundary condition was not handled
                     correctly.
   Jan 14, 91   JES-Added parameter DoWeUseLateAvailabilities to some
                        procedures.
   Feb 19, 91   JES-Added procedures AllResourcesOnVacationOrAvailable and
                     FindFirstDateResOnVacationOrAvailable.                           
   Feb 22, 91   JES-Removed all references to Honor-Days-Off, since this
                    is now taken into account by the initial residue
                    availability lists.
   Mar 28, 91   AJL -Corrected an error in ScheduleLongAmount in which
                     we might try to collapse the cell past the end of
                     the search.  Replaced Collapse..(NextHandle) with
                     Collapse..(CellHandle);
   Apr 11, 91   JES -Cleaned up according to m2check, including two errors:
                     (1) AllResourcesAreAvailable was not initializing
                       AssignmentsHandle, and CollapseIntoPrevious was
                       releasing unchanged in one case where it had
                       actually changed the cell values.
   Apr 17, 91   AJL -Fix FindFirstDateHaveResourceAmount.  The loop was
                     checking whether the cell had valid date data (IsHeadCell)
                     AFTER using the data!
                    -Similar fix to FindFirstDateResOnVacationOrAvailable.
                    -Similar fix to FindLatestDateHaveResourceAmount.
   Apr 26, 91   JES-Removed unused procedure FindFirstDateLevelIsAboveZero.
   June 12, 91  JES-Fixed bug in procedure AllResourcesOnVacationOrAvailable,
                        where "Result" was not being initialized.
   June 18, 91  JES-Added FindFirstDateResourceNotOnVacation.
   June 21, 91  AJL-Corrected an unitialized value in
                    FindFirstDateResourceNotOnVacation.
                   -Modified the FindFirstDate... and FindLatestDate...
                    procedures to take MaxDate as a special case, and 
                    avoid searching for a cell containing it.
   June 24, 91  JES-Fixed bug in FindFirstDateResourceNotOnVacation, where
                     instead of finding the first date the resource is not
                     on vacation, it found the first date the resource IS
                     on vacation.
   July 14, 91  AJL-AmountAvailableOnDate was missing a ReleaseObject.
                    Fixed that.  Since no one uses this proc, commented
                    it out, though.
   Oct. 9, 91   LAA-In FindFirstDateHaveResourceAmount, if the CellHandle
                    returned from CellContainingDate was NIL, we were going
                    into the loop anyway (and causing a fatal error).  If
                    there's no cell containing the indicated date, the just
                    return with FoundDate = FALSE.  Also fixed a similar
                    situation in FindFirstDateResourceNotOnVacation.
   Oct. 9, 91   LAA-Well, I should have checked the whole module over,
                    because now we're getting the same problem on duration
                    split tasks, and it's the same situation in 
                    FindFirstDateResOnVacationOrAvailable.  Also fixed
                    similar situations in FindLatestDateHaveResourceAmount,
                    and ScheduleLongAmount, but I didn't put this fix into
                    CheckResourceOnDate as it's not clear to me that this
                    is quite the same situation.
                    It dones generally look like this problem of
                    CellContainingDate either should never occur, or there
                    are many parts of recalc which need to be looked at and
                    reworked.
   Feb  6, 92   JES-Added FindLatestViolationOrNonVacation (to change
                      duration-driven tasks so they can't start on a date
                      when all resources are on vacation - used in
                      FindLatestStartDate).                      
*)

FROM Allocs         IMPORT  ATaskPtr;

FROM Assignments    IMPORT  AnAssignmentArray, AnAssignmentRecord;

FROM Dialog         IMPORT  FatalError;

FROM FlexStor       IMPORT  
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
    (* PROC *)              CreateExtObjectWithSize,
                            LockObjectArray, LockObject, ReleaseObject, 
                            ReleaseUnchangedObject, DiscardExtObject;

FROM LStrings       IMPORT  SetString, ConcatLS, CtoS, TrimRear, Remove;
    (* PROC *)
 
FROM ResCal         IMPORT
    (* TYPE *)              AnAvailabilityCell, AnAvailabilityCellPointer,
                             CellContainingDate, BackCellContainingDate;
    
FROM ResConstants   IMPORT
    (* VAR *)               SchedulingAbandoned;

FROM ResWarnings    IMPORT
    (* PROC *)              SendErrorMsg;


FROM RsrcMod        IMPORT
    (* TYPE *)              AResourcePointer, AResourceType;

FROM Planner        IMPORT
    (* VAR *)               ScheduleComputedOk;


FROM SYSTEM         IMPORT
    (* TYPE *)              TSIZE;
      
FROM Timei          IMPORT
    (* TYPE *)              ADate, MaxDate;


(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM LongConvert    IMPORT  RealToLong, LongToString;
FROM LStrings     IMPORT ConcatS;
FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat; 
FROM ResTrace     IMPORT NoteString, PrintAString, PrintResidueAvailability;
FROM SYSTEM       IMPORT ADDRESS;
FROM TimeFormat   IMPORT TimeUtoS;     
VAR
    s : ARRAY [0..255] OF CHAR;
PRINT>*)
(* for testing purposes: 
VAR                 NumCells: CARDINAL;
                    MaxCells: CARDINAL;
                    UseMaxCells: BOOLEAN;  
***************************************)




(*<PRINT
    PROCEDURE CtoH     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
    CONST
        RADIX = 16;
        Size  = 4;
    VAR
        i,j,k : CARDINAL;
    BEGIN
        j := Size;
        REPEAT
            k := Card MOD RADIX;
            IF (k < 10) THEN
                String[j] := CHR(ORD("0")+k);
            ELSE
                String[j] := CHR(ORD("A")+(k-10));
            END;
            Card := Card DIV RADIX;
            DEC(j);
        UNTIL (j = 0);
        String[0] := CHR(Size);
    END CtoH;

    PROCEDURE HtoS( H : AnExtHandle; VAR S : ARRAY OF CHAR);
    VAR
        S2  : ARRAY [0..40] OF CHAR;
        A   : ADDRESS;
    BEGIN
        A := ADDRESS(H);
        CtoH(A.SEGMENT,S);
        CtoH(A.OFFSET MOD 16,S2);
        Remove(S2,1,3);
        ConcatLS(S,S2);
        ConcatS(S,".");
        CtoH(A.OFFSET DIV 256,S2);
        Remove(S2,1,2);
        ConcatLS(S,S2);
    END HtoS;
PRINT>*)


(*------AmountAvailableOnDate---------------(exported)-----------------*)

PROCEDURE AmountAvailableOnDate (Resource : AResourcePointer;
                                 Date     : ADate;
                                 DoWeUseLateAvailabilities : BOOLEAN) : LONGINT;

(*---
VAR
    CellHandle : AnExtHandle;
    Cell       : AnAvailabilityCellPointer;
    Amount     : LONGINT;
---*)
BEGIN
    (*--------- No one uses this proc. 
    IF (DoWeUseLateAvailabilities) THEN
        CellHandle := CellContainingDate(Resource^.LateResidueAvailProfile, Date);
    ELSE
        CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, Date);
    END;
    IF LockObject(CellHandle, Cell) = 0 THEN 
        SchedulingAbandoned := TRUE;
        ScheduleComputedOk := FALSE;
        FatalError(); 
    END;
    Amount := Cell^.AmountAvailable;
    ReleaseUnchangedObject(CellHandle);
    Cell := NIL;
    RETURN Amount;
    -------------------------- *)
    HALT;
END AmountAvailableOnDate;


(*-----CheckResourceOnDate-----------------(exported)--------------------*)

PROCEDURE CheckResourceOnDate (Resource                  : AResourcePointer;
                               Date                      : ADate;
                               DoWeUseLateAvailabilities : BOOLEAN;
                           VAR AmountAvail    : LONGINT;
                           VAR DateIsVacation : BOOLEAN);


VAR
    CellHandle : AnExtHandle;
    Cell       : AnAvailabilityCellPointer;
BEGIN
    IF (DoWeUseLateAvailabilities) THEN
        CellHandle := CellContainingDate(Resource^.LateResidueAvailProfile, Date);
    ELSE
        CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, Date);
    END;
    IF LockObject(CellHandle, Cell) = 0 THEN 
        FatalError(); 
    END;
    AmountAvail := Cell^.AmountAvailable;
    DateIsVacation := (Cell^.ThisIsAVacation);
    ReleaseUnchangedObject(CellHandle);
    Cell := NIL;

END CheckResourceOnDate;




(*------HaveResourceAmountOnDate-----------(exported procedure)-------*)

PROCEDURE HaveResourceAmountOnDate (Resource       : AResourcePointer;
                                    Amount         : LONGINT;
                                    Date           : ADate;
                                    DoWeAllowVacations        : BOOLEAN;
                                    DoWeUseLateAvailabilities : BOOLEAN) : BOOLEAN;
VAR
    AmountAvail    : LONGINT;
    DateIsVacation : BOOLEAN;
BEGIN
    CheckResourceOnDate (Resource, Date, DoWeUseLateAvailabilities,
                            AmountAvail, DateIsVacation);
    IF AmountAvail < Amount THEN
      RETURN FALSE;
    END;
    IF NOT (DateIsVacation) THEN
      RETURN TRUE;
    END;
    IF (DoWeAllowVacations) THEN
      RETURN TRUE;
    END;
    RETURN FALSE;
END HaveResourceAmountOnDate;


(* -------------- FindFirstDateResourceNotOnVacation --------------------*)

PROCEDURE FindFirstDateResourceNotOnVacation (Resource        : AResourcePointer;
                                              StartSearchDate : ADate;
                                              EndSearchDate   : ADate;
                                          VAR DateFound       : ADate;
                                          VAR FoundADate      : BOOLEAN);

VAR
   Cell            : AnAvailabilityCellPointer;
   CellHandle      : AnExtHandle;
   NextCellHandle  : AnExtHandle;
   ReachedHeadCell : BOOLEAN;
   ExceededInterval: BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString,"  FindFirstDateResourceNotOnVacation for resource ");
    ConcatLS(NoteString, Resource^.Name);  PrintAString(NoteString);
    SetString(NoteString,"    between ");
    TimeUtoS(StartSearchDate, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    SetString(NoteString,"    and ");  TimeUtoS(EndSearchDate, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);
    PRINT>*)


        (* No cell contains MaxDate. *)

    FoundADate := FALSE;
    IF (StartSearchDate = MaxDate) THEN
        RETURN;
    END;

    CellHandle  := CellContainingDate(Resource^.ResidueAvailProfile, StartSearchDate);

    IF (CellHandle = AnExtHandle(NIL)) THEN                    (* 09-Oct-91 *)
        RETURN;
    END;

    ReachedHeadCell  := FALSE;
    ExceededInterval := FALSE;
    FoundADate       := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN 
            FatalError(); 
        END;
 
        IF (Cell^.IsHeadCell) THEN
            ReachedHeadCell := TRUE;
        ELSIF (Cell^.StartDate > EndSearchDate) THEN
            ExceededInterval := TRUE;
        ELSIF NOT (Cell^.ThisIsAVacation) THEN
                (* found good date *)
            FoundADate := TRUE;
            DateFound := Cell^.StartDate;
            IF DateFound < StartSearchDate THEN
                (* we want the first date on or after StartSearchDate - it's valid,
                   since we're still in the same cell 
                *)
                DateFound := StartSearchDate; 
            END; 
        END;
 
        NextCellHandle := Cell^.NextCell;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := NextCellHandle;

    UNTIL (FoundADate) OR (ReachedHeadCell) OR (ExceededInterval);
 
    (*<PRINT
    IF (FoundADate) THEN
        SetString(NoteString,"    FindFirstDateResourceNotOnVacation--> ");
        TimeUtoS(DateFound, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    END;
    IF (ReachedHeadCell) THEN
        SetString(NoteString, "    Reached head cell");
        PrintAString(NoteString);
    END;
    IF (ExceededInterval) THEN
        SetString(NoteString, "    Exceeded Interval");
        PrintAString(NoteString);
    END;
    PRINT>*)

END FindFirstDateResourceNotOnVacation;




(*-------FindFirstDateHaveResourceAmount-----(exported)---------------------*)

PROCEDURE FindFirstDateHaveResourceAmount (Resource         : AResourcePointer;
                                           Amount           : LONGINT;
                                           StartSearchDate  : ADate;
                                           EndSearchDate    : ADate;
                                           DoWeAllowVacations        : BOOLEAN;
                                           DoWeAllowOverbookings     : BOOLEAN;
                                           DoWeUseLateAvailabilities : BOOLEAN;
                                       VAR FoundADate       : BOOLEAN;
                                       VAR DateFound        : ADate);

VAR
   Cell            : AnAvailabilityCellPointer;
   CellHandle      : AnExtHandle;
   NextCellHandle  : AnExtHandle;
   ReachedHeadCell : BOOLEAN;
   ExceededInterval: BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString,"  FindFirstDateHaveResourceAmount for resource ");
    ConcatLS(NoteString, Resource^.Name);  PrintAString(NoteString);
    SetString(NoteString, "   amount desired = ");  LongToString(Amount, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);  SetString(NoteString,"    between ");
    TimeUtoS(StartSearchDate, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    SetString(NoteString,"    and ");  TimeUtoS(EndSearchDate, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);
    PRINT>*)

        (* No cell contains MaxDate. *)

    IF (StartSearchDate = MaxDate) THEN
        FoundADate := FALSE;
        RETURN;
    END;

    FoundADate := FALSE;
    IF (DoWeUseLateAvailabilities) THEN
        CellHandle  := CellContainingDate(Resource^.LateResidueAvailProfile, StartSearchDate);
    ELSE
        CellHandle  := CellContainingDate(Resource^.ResidueAvailProfile, StartSearchDate);
    END;

    IF (CellHandle = AnExtHandle(NIL)) THEN                    (* 09-Oct-91 *)
        RETURN;
    END;

    ReachedHeadCell  := FALSE;
    ExceededInterval := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN 
            FatalError(); 
        END;
 
        IF (Cell^.IsHeadCell) THEN
            ReachedHeadCell := TRUE;
        ELSIF (Cell^.StartDate > EndSearchDate) THEN
            ExceededInterval := TRUE;
        ELSIF (((Cell^.AmountAvailable >= Amount) OR DoWeAllowOverbookings) 
                                     AND
             ((NOT Cell^.ThisIsAVacation) OR (DoWeAllowVacations))) THEN 
                (* found good date *)
            FoundADate := TRUE;
            DateFound := Cell^.StartDate;
            IF DateFound < StartSearchDate THEN
                (* we want the first date on or after StartSearchDate - it's valid,
                   since we're still in the same cell 
                *)
                DateFound := StartSearchDate; 
            END; 
        END;
 
        NextCellHandle := Cell^.NextCell;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := NextCellHandle;

    UNTIL (FoundADate) OR (ReachedHeadCell) OR (ExceededInterval);
 
    (*<PRINT
    IF (FoundADate) THEN
        SetString(NoteString,"    FindFirstDateHaveResourceAmount--> ");
        TimeUtoS(DateFound, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    END;
    IF (ReachedHeadCell) THEN
        SetString(NoteString, "    Reached head cell");
        PrintAString(NoteString);
    END;
    IF (ExceededInterval) THEN
        SetString(NoteString, "    Exceeded Interval");
        PrintAString(NoteString);
    END;
    PRINT>*)

END FindFirstDateHaveResourceAmount;



(*-------FindFirstDateResOnVacationOrAvailable -----(exported)---------------------*)

PROCEDURE FindFirstDateResOnVacationOrAvailable (Resource         : AResourcePointer;
                                                 Amount           : LONGINT;
                                                 StartSearchDate  : ADate;
                                                 EndSearchDate    : ADate;
                                                 DoWeUseLateAvailabilities : BOOLEAN;
                                             VAR FoundADate       : BOOLEAN;
                                             VAR DateFound        : ADate);

VAR
   Cell            : AnAvailabilityCellPointer;
   CellHandle      : AnExtHandle;
   NextCellHandle  : AnExtHandle;
   ReachedHeadCell : BOOLEAN;
   ExceededInterval: BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString,"  FindFirstDateResOnVacationOrAvailable for resource ");
    ConcatLS(NoteString, Resource^.Name);  PrintAString(NoteString);
    SetString(NoteString, "   amount desired = ");  LongToString(Amount, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);  SetString(NoteString,"    between ");
    TimeUtoS(StartSearchDate, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    SetString(NoteString,"    and ");  TimeUtoS(EndSearchDate, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);
    PRINT>*)

        (* dispense with non-levellable resource: *)
    IF NOT(Resource^.LevelThisResource) THEN
        (*<PRINT
        SetString(NoteString, " resource not levellable so any date ok");
        PrintAString(NoteString);
        PRINT>*)
        FoundADate := TRUE;
        DateFound := StartSearchDate;
        RETURN;
    END;

        (* No cell contains MaxDate. *)

    FoundADate := FALSE;
    IF (StartSearchDate = MaxDate) THEN
        RETURN;
    END;


    IF (DoWeUseLateAvailabilities) THEN
        CellHandle  := CellContainingDate(Resource^.LateResidueAvailProfile, StartSearchDate);
    ELSE
        CellHandle  := CellContainingDate(Resource^.ResidueAvailProfile, StartSearchDate);
    END;

    IF (CellHandle = AnExtHandle(NIL)) THEN                    (* 10-Oct-91 *)
        RETURN;
    END;

    ReachedHeadCell  := FALSE;
    ExceededInterval := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN 
            FatalError(); 
        END;
 
        IF ( Cell^.IsHeadCell ) THEN   (* quit search any further because *)
            ReachedHeadCell := TRUE;   (* the head cell is reached now *)
        ELSIF (Cell^.StartDate > EndSearchDate) THEN
           ExceededInterval := TRUE;
        ELSIF (
                (Cell^.AmountAvailable >= Amount) OR 
                ((Cell^.ThisIsAVacation)) 
              ) THEN
                (* found good date *)
            FoundADate := TRUE;
            DateFound := Cell^.StartDate;
            IF DateFound < StartSearchDate THEN
                (* we want the first date on or after StartSearchDate - it's valid,
                   since we're still in the same cell 
                *)
                DateFound := StartSearchDate; 
            END; 
        END;
  
        NextCellHandle := Cell^.NextCell;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := NextCellHandle;

    UNTIL (FoundADate) OR (ReachedHeadCell) OR (ExceededInterval);
 
    (*<PRINT
    IF (FoundADate) THEN
        SetString(NoteString,"    FindFirstDateHaveResourceAmount--> ");
        TimeUtoS(DateFound, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    END;
    PRINT>*)

END FindFirstDateResOnVacationOrAvailable;





PROCEDURE FindLatestDateHaveResourceAmount (Resource         : AResourcePointer;
                                            Amount           : LONGINT;
                                            OnOrBefore       : ADate;
                                            DoWeAllowVacations       : BOOLEAN;
                                            DoWeAllowOverbookings     : BOOLEAN;
                                            DoWeUseLateAvailabilities : BOOLEAN;
                                        VAR FoundADate       : BOOLEAN;
                                        VAR DateFound        : ADate);

VAR
   Cell            : AnAvailabilityCellPointer;
   CellHandle      : AnExtHandle;
   PrevCellHandle  : AnExtHandle;
   ReachedHeadCell : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString,"  FindLatestDateHaveResourceAmount for resource ");
    ConcatLS(NoteString, Resource^.Name);  PrintAString(NoteString);
    SetString(NoteString, "   amount desired = ");  LongToString(Amount, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);  SetString(NoteString,"    on or before");
    TimeUtoS(OnOrBefore, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    PRINT>*)


        (* No cell contains MaxDate. *)

    FoundADate := FALSE;
    IF (OnOrBefore >= MaxDate-1) THEN
        RETURN;
    END;

    IF (DoWeUseLateAvailabilities) THEN
        CellHandle  := BackCellContainingDate(Resource^.LateResidueAvailProfile, 
                                          OnOrBefore + 1);
         (* note: the above procedure operates on end dates *)
    ELSE
        CellHandle  := BackCellContainingDate(Resource^.ResidueAvailProfile, 
                                          OnOrBefore + 1);
         (* note: the above procedure operates on end dates *)
    END;

    IF (CellHandle = AnExtHandle(NIL)) THEN                    (* 10-Oct-91 *)
        RETURN;
    END;

    ReachedHeadCell  := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN 
            FatalError(); 
        END;
 
        IF ( Cell^.IsHeadCell ) THEN   (* quit search any further because
                                          the head cell is reached now *)
            ReachedHeadCell := TRUE;
        ELSIF (((Cell^.AmountAvailable >= Amount) OR DoWeAllowOverbookings) 
                                     AND
             ((NOT Cell^.ThisIsAVacation) OR (DoWeAllowVacations))) THEN 
                (* found good date *)
            FoundADate := TRUE;
            DateFound := Cell^.EndDate - 1;
            IF DateFound > OnOrBefore THEN
                DateFound := OnOrBefore; 
            END; 
        END;
 
        PrevCellHandle := Cell^.PrevCell;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := PrevCellHandle;

    UNTIL (FoundADate) OR (ReachedHeadCell);
 
    (*<PRINT
    IF (FoundADate) THEN
        SetString(NoteString,"    FindLatestDateHaveResourceAmount--> ");
        TimeUtoS(DateFound, s);  ConcatLS(NoteString, s);  PrintAString(NoteString);
    END;
    PRINT>*)

END FindLatestDateHaveResourceAmount;



PROCEDURE FindLatestViolationOrNonVacation (Resource         : AResourcePointer;
                                            Amount           : LONGINT;
                                            OnOrBefore       : ADate;
                                            DoWeAllowOverbookings     : BOOLEAN;
                                            DoWeUseLateAvailabilities : BOOLEAN;
                                        VAR DateFound        : ADate;
                                        VAR WeFoundDate      : BOOLEAN;
                                        VAR DateIsViolation  : BOOLEAN);        

VAR
   Cell            : AnAvailabilityCellPointer;
   CellHandle      : AnExtHandle;
   PrevCellHandle  : AnExtHandle;
   ReachedHeadCell : BOOLEAN;
BEGIN
    (*<PRINT
    SetString(NoteString,"  FindLatestViolationOrNonVacation for resource ");
    ConcatLS(NoteString, Resource^.Name);  PrintAString(NoteString);
    SetString(NoteString, "   amount desired = ");  LongToString(Amount, s);
    ConcatLS(NoteString, s);  PrintAString(NoteString);  SetString(NoteString,"    on or before");
    CtoS(OnOrBefore, s);  ConcatLS(NoteString, s);  
    TimeUtoS(OnOrBefore, s);  ConcatLS(NoteString, s);  
    PrintAString(NoteString);
    PRINT>*)


        (* No cell contains MaxDate. *)

    WeFoundDate := FALSE;
    IF (OnOrBefore >= MaxDate-1) THEN
        RETURN;
    END;

    IF (DoWeUseLateAvailabilities) THEN
        CellHandle  := BackCellContainingDate(Resource^.LateResidueAvailProfile, 
                                          OnOrBefore + 1);
         (* note: the above procedure operates on end dates *)
    ELSE
        CellHandle  := BackCellContainingDate(Resource^.ResidueAvailProfile, 
                                          OnOrBefore + 1);
         (* note: the above procedure operates on end dates *)
    END;

    IF (CellHandle = AnExtHandle(NIL)) THEN                    (* 10-Oct-91 *)
        RETURN;
    END;

    ReachedHeadCell  := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN 
            FatalError(); 
        END;
 
        IF ( Cell^.IsHeadCell ) THEN   (* quit search any further because
                                          the head cell is reached now *)
            ReachedHeadCell := TRUE;
        ELSIF ((NOT DoWeAllowOverbookings) AND 
               (Cell^.AmountAvailable < Amount)) THEN
            (* hit a violation first: *)
            WeFoundDate := TRUE;        
            DateIsViolation := TRUE;
            DateFound := Cell^.EndDate -1;     
            IF DateFound > OnOrBefore THEN
                DateFound := OnOrBefore; 
            END; 
            (*<PRINT
            SetString(NoteString, "found a violation - last date in cell = ");
            CtoS(Cell^.EndDate - 1, s);
            ConcatLS(NoteString, s);    
            PrintAString(NoteString);
            SetString(NoteString, "returning ");    
            CtoS(DateFound, s);
            ConcatLS(NoteString, s);
            PrintAString(NoteString);        
            PRINT>*)
        ELSIF (NOT Cell^.ThisIsAVacation) THEN
                (* found a good non-vacation date: *)
            WeFoundDate := TRUE;
            DateIsViolation := FALSE;
            DateFound := Cell^.EndDate - 1;
            IF DateFound > OnOrBefore THEN
                DateFound := OnOrBefore; 
            END; 
        END;
 
        PrevCellHandle := Cell^.PrevCell;
        ReleaseUnchangedObject(CellHandle);
        Cell := NIL;
        CellHandle := PrevCellHandle;

    UNTIL (WeFoundDate) OR (ReachedHeadCell);
 
    (*<PRINT
    IF (WeFoundDate) THEN
        SetString(NoteString,"    FindLatestViolationOrNonVacation--> ");
        CtoS(DateFound, s);  ConcatLS(NoteString, s);  
        TimeUtoS(DateFound, s);  ConcatLS(NoteString, s);  
        PrintAString(NoteString);
        IF (DateIsViolation) THEN SetString (NoteString, "date is violation");
        ELSE SetString(NoteString, "date is non-vacation"); PrintAString(NoteString);
        END;
    END;
    PRINT>*)

END FindLatestViolationOrNonVacation;




(*------AllResourcesAreAvailable-------------(exported)---------------*)

PROCEDURE AllResourcesAreAvailable(Assignments       : AnAssignmentArray;
                                   NumAssignments    : CARDINAL;
                                   Date              : ADate;
                                   DoWeAllowVacations        : BOOLEAN;
                                   DoWeAllowOverbookings     : BOOLEAN;
                                   DoWeUseLateAvailabilities : BOOLEAN) : BOOLEAN;

VAR
    i                : CARDINAL;
    AmountWeUse      : LONGINT;
    AmountAvailable  : LONGINT;
    ResourceWeUse    : AResourcePointer;
    DateIsVacation   : BOOLEAN;
    AllResourcesOnVacation : BOOLEAN;
    SomeResourcesOnVacation : BOOLEAN;
    Result           : BOOLEAN;

(*<PRINT
s   : ARRAY [0..80] OF CHAR;
PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"   All resources available on ");
    TimeUtoS(Date,s);
    ConcatLS(NoteString,s);
    ConcatS(NoteString,"?");
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG*)
    IF NumAssignments = 0 THEN
        (* this procedure should not have been reached *)
        SendErrorMsg("AllResourceAreAvailable: task has no resources.");
        FatalError();
    END;
    (*DEBUG>*)

    AllResourcesOnVacation := TRUE;
     (* if this remains true, then we will return FALSE; since for
       "all resources to be available", we require that at least one of them
       not be on vacation, even if AllowVacations is TRUE *)
     (* however, if we are not honoring vacations, then we don't care
        if a resource is on vacation or not *)

    SomeResourcesOnVacation := FALSE;

    FOR i := 0 TO (NumAssignments - 1) DO
        ResourceWeUse := Assignments^[i].Resource;
        (*<PRINT
        SetString(NoteString,  " testing resource ");
        ConcatLS(NoteString, ResourceWeUse^.Name);
        PrintAString(NoteString);
        PRINT>*)
              (* we don't consider or touch non-employable resources in levelling *)
        IF (ResourceWeUse^.Type = Employable) THEN
            AmountWeUse  := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            (*<PRINT
            SetString(NoteString, " amount required: ");
            LongToString(AmountWeUse,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)
            CheckResourceOnDate (ResourceWeUse,
                                 Date,
                                 DoWeUseLateAvailabilities,
                                 AmountAvailable,
                                 DateIsVacation);
            IF (
                (ResourceWeUse^.LevelThisResource) AND
                (AmountAvailable < AmountWeUse) AND 
                (NOT DoWeAllowOverbookings)
               ) 
            OR (
                (DateIsVacation) AND
                (NOT DoWeAllowVacations) 
               )
            THEN
                (*<PRINT
                SetString(NoteString,        "resource is not available");
                PrintAString(NoteString);
                PRINT>*)
                RETURN FALSE;
            END;
            IF DateIsVacation THEN
               (*<PRINT
               SetString(NoteString,  " - on vacation ");
               PrintAString(NoteString);
               PRINT>*)
               SomeResourcesOnVacation := TRUE;
            ELSE
               AllResourcesOnVacation := FALSE;
               (* we found some resource who is not on vacation on Date *)
            END;
        (*<PRINT
        ELSE
        SetString(NoteString,  " not employable resource.");
        PrintAString(NoteString);
        PRINT>*)
        END; (* employable resource *)
    END; (* end loop *)

    IF (AllResourcesOnVacation AND SomeResourcesOnVacation) THEN 
        Result := FALSE;
    ELSE    
        Result := TRUE;
    END;


    (*<PRINT
    IF Result THEN
        SetString(NoteString,"          All available.");
    ELSE
        SetString(NoteString,"          Not all are available.");
    END;
    PrintAString(NoteString);
    PRINT>*)

    RETURN Result;

END AllResourcesAreAvailable;



(*------AllResourcesOnVacationOrAvailable---------(exported)--------*)

PROCEDURE AllResourcesOnVacationOrAvailable(Assignments       : AnAssignmentArray;
                                            NumAssignments    : CARDINAL;
                                            Date              : ADate;
                                            DoWeUseLateAvailabilities : BOOLEAN) : BOOLEAN;

VAR
    i                : CARDINAL;
    AmountWeUse      : LONGINT;
    AmountAvailable  : LONGINT;
    ResourceWeUse    : AResourcePointer;
    DateIsVacation   : BOOLEAN;
    Result           : BOOLEAN;

(*<PRINT
s   : ARRAY [0..80] OF CHAR;
PRINT>*)

BEGIN

    (*<PRINT
    SetString(NoteString,"   All resources on vacation or available on ");
    TimeUtoS(Date,s);
    ConcatLS(NoteString,s);
    ConcatS(NoteString,"?");
    PrintAString(NoteString);
    PRINT>*)

    (*<DEBUG*)
    IF NumAssignments = 0 THEN
        (* this procedure should not have been reached *)
        SendErrorMsg("AllResourceAreAvailable: task has no resources.");
        FatalError();
    END;
    (*DEBUG>*)

    Result := TRUE;  (* innocent until proven guilty *)

    FOR i := 0 TO (NumAssignments - 1) DO
        ResourceWeUse := Assignments^[i].Resource;
        (*<PRINT
        SetString(NoteString,  " testing resource ");
        ConcatLS(NoteString, ResourceWeUse^.Name);
        PrintAString(NoteString);
        PRINT>*)
              (* we don't consider or touch non-employable resources in levelling *)
        IF (ResourceWeUse^.Type = Employable) THEN
            AmountWeUse  := VAL(LONGINT, Assignments^[i].MaxRatePercent);
            (*<PRINT
            SetString(NoteString, " amount required: ");
            LongToString(AmountWeUse,s);
            ConcatLS(NoteString,s);
            PrintAString(NoteString);
            PRINT>*)
            CheckResourceOnDate (ResourceWeUse,
                                 Date,
                                 DoWeUseLateAvailabilities,
                                 AmountAvailable,
                                 DateIsVacation);
            IF (
                (ResourceWeUse^.LevelThisResource) AND
                (AmountAvailable < AmountWeUse) AND 
                (NOT (DateIsVacation))
               ) 
            THEN
                (*<PRINT
                SetString(NoteString,        "resource has violation");
                PrintAString(NoteString);
                PRINT>*)
                Result := FALSE;
            END;
        END; (* employable resource *)
    END; (* end loop *)

    (*<PRINT
    IF Result THEN
        SetString(NoteString,"          All resource ok.");
    END;
    PrintAString(NoteString);
    PRINT>*)

    RETURN Result;

END AllResourcesOnVacationOrAvailable;





(* --- AllTaskResourcesAreAvailable -----------------

   Just like AllResourcesAreAvailable, but operates on a task instead
   of an assignment array, and locks and unlocks the task's assignment
   array instead of taking it as a parameter. 

*)

PROCEDURE AllTaskResourcesAreAvailable(Task              : ATaskPtr;
                                       Date              : ADate;
                                       DoWeAllowVacations        : BOOLEAN;
                                       DoWeAllowOverbookings     : BOOLEAN;
                                       DoWeUseLateAvailabilities : BOOLEAN) : BOOLEAN;

VAR
    AssignmentsHandle : AnExtHandle;
    Assignments       : AnAssignmentArray;
    ResourceCount     : CARDINAL;
    Result            : BOOLEAN;
BEGIN

    AssignmentsHandle := Task^.Plan.Assignments;
    ResourceCount    := LockObjectArray(AssignmentsHandle,
                                        Assignments,  
                                        TSIZE(AnAssignmentRecord));

    Result := AllResourcesAreAvailable (Assignments,
                                        ResourceCount,
                                        Date,
                                        DoWeAllowVacations,
                                        DoWeAllowOverbookings,
                                        DoWeUseLateAvailabilities);
    ReleaseUnchangedObject(AssignmentsHandle);
    RETURN Result;

END AllTaskResourcesAreAvailable;







    (* schedule Amount for Resource from StartDate to EndDate -
        StartHandle will be either the resource's ResidueAvailProfile
        or its LateResidueAvailProfile *)

PROCEDURE ScheduleLongAmount( AvailHandle : AnExtHandle;
                              Amount      : LONGINT;
                              StartDate   : ADate;
                              EndDate     : ADate);
VAR
    CellHandle, NewHandle, 
    PrevHandle, NextHandle,
    StartHandle                        : AnExtHandle; 
    Cell, New, Prev, Next              : AnAvailabilityCellPointer;
    Done, SplitEndCell, SplitStartCell : BOOLEAN;
BEGIN    
    (*<PRINT SetString(NoteString,"Before ScheduleLongAmount: ");
               HtoS(AvailHandle,s);  ConcatLS(NoteString,s);
               TimeUtoS(StartDate,s); ConcatLS(NoteString,s); ConcatS(NoteString," - ");
               TimeUtoS(EndDate,s); ConcatLS(NoteString,s); ConcatS(NoteString,", Amt = ");
               LongToString(Amount,s);  ConcatLS(NoteString,s); ConcatS(NoteString,", Vac = ");
               PrintAString(NoteString);
               PrintResidueAvailability(AvailHandle);
               PRINT>*)

        (* quit if there is nothing to be scheduled *)
    IF (StartDate = EndDate) 
       OR (Amount = VAL(LONGINT, 0))
       OR (StartDate >= MaxDate) THEN     
        RETURN;  
    END;

    (* locate the cell which contains StartDate *)
    CellHandle := CellContainingDate
                  (AvailHandle, StartDate);    
    IF ((CellHandle = AnExtHandle(NIL))                        (* 10-Oct-91 *)
       OR (LockObject(CellHandle, Cell) = 0)) THEN
        SchedulingAbandoned := TRUE;
        ScheduleComputedOk  := FALSE;
        RETURN;
    END;

    (* split the first cell if StartDate is in the middle of that cell 
       but do not schedule amount for the first cell yet 
    *)
    SplitStartCell := FALSE;
    IF (Cell^.StartDate < StartDate) THEN  
        (* create a new cell *)
        IF (NOT CreateExtObjectWithSize(NewHandle, ExtMedium,
                                        TSIZE(AnAvailabilityCell))) THEN                       
            ReleaseUnchangedObject(CellHandle);
            SchedulingAbandoned := TRUE;
            ScheduleComputedOk  := FALSE;
            RETURN;
        END;
    
        (* insert the new cell between the previous and current cell *)
        PrevHandle := Cell^.PrevCell;

        IF LockObject(NewHandle, New) <> TSIZE(AnAvailabilityCell) THEN 
            FatalError;
        END;

        New^                 := Cell^;
        New^.EndDate         := StartDate;
        New^.NextCell        := CellHandle;
        ReleaseObject(NewHandle);
        New := NIL;

        Cell^.PrevCell        := NewHandle;
        Cell^.StartDate       := StartDate;
        ReleaseObject(CellHandle);
        Cell := NIL;

        IF LockObject(PrevHandle, Prev) <> TSIZE(AnAvailabilityCell) THEN 
            FatalError;
        END;

        Prev^.NextCell    := NewHandle;        
        ReleaseObject(PrevHandle);
        Prev := NIL;

        SplitStartCell := TRUE;

    ELSE    (* the first cell is not split *)  
        ReleaseObject(CellHandle);
        Cell := NIL;
        StartHandle := CellHandle;  (* for future use *)
    END;

    (* schedule amount for every cell but not the end cell 
       if the end cell is to be split *)
    SplitEndCell := FALSE;
    Done         := FALSE;
    REPEAT
        IF LockObject(CellHandle, Cell) = 0 THEN  FatalError;  END;
        NextHandle := Cell^.NextCell;

        IF (Cell^.IsHeadCell) OR (Cell^.StartDate >= EndDate) THEN
            Done            := TRUE;   
        ELSE
            (* split the end cell if EndDate is in the middle of that cell *)
            IF ( EndDate < Cell^.EndDate ) THEN
                SplitEndCell := TRUE;
            ELSE
                Cell^.AmountAvailable := Cell^.AmountAvailable - Amount;
                ReleaseObject(CellHandle);
                Cell := NIL;
                CellHandle := NextHandle;
            END; 
        END;
    UNTIL ( Done OR SplitEndCell );

    IF (SplitEndCell) THEN
        (* create a new cell *)
        IF (NOT CreateExtObjectWithSize(NewHandle, ExtMedium,
                                        TSIZE(AnAvailabilityCell))) THEN                       
            SchedulingAbandoned := TRUE;
            ScheduleComputedOk  := FALSE;
            RETURN; 
        END;
    
        (* insert the new cell between the end cell and next cell *)
        IF LockObject(NewHandle, New) <> TSIZE(AnAvailabilityCell) THEN 
            FatalError;
        END;

        New^                 := Cell^;
        New^.StartDate       := EndDate;            
        New^.PrevCell        := CellHandle;
        ReleaseObject(NewHandle);
        New := NIL;
        
        Cell^.EndDate         := EndDate;
        Cell^.NextCell        := NewHandle;
        Cell^.AmountAvailable := Cell^.AmountAvailable - Amount;
        ReleaseObject(CellHandle);
        Cell := NIL;

        IF LockObject(NextHandle, Next) <> TSIZE(AnAvailabilityCell) THEN 
            FatalError;
        END;

        Next^.PrevCell := NewHandle;        
        ReleaseObject(NextHandle);
        Next := NIL;
    
    ELSE
        ReleaseObject(CellHandle);
        Cell := NIL;

        (* collapse the cell following the end cell into the end cell *)
        CollapseIntoPrevious(CellHandle);
    END;


    (* now that all cells including the start cell have been scheduled,
       see if the start cell can be merged into its previous cell 
    *)
    IF (NOT SplitStartCell) THEN
        CollapseIntoPrevious(StartHandle);
    END;


    (*<PRINT SetString(NoteString,"After ScheduleLongAmount:");
               PrintAString(NoteString);
               PrintResidueAvailability(AvailHandle);
               PRINT>*)

END ScheduleLongAmount;





(*------ScheduleResource----------------------(exported)-------------------*)

PROCEDURE ScheduleResource  (Resource  : AResourcePointer;
                             Amount    : CARDINAL;
                             StartDate : ADate;
                             EndDate   : ADate);
BEGIN
    ScheduleLongAmount(Resource^.ResidueAvailProfile,VAL(LONGINT,Amount),
                       StartDate,EndDate);
END ScheduleResource;


(* ------- ScheduleLateResource ------------------------------------

   Just like ScheduleResource, but references the resource's LateResidue
   AvailProfile instead of its ResidueAvailProfile.
*)

PROCEDURE ScheduleLateResource (Resource  : AResourcePointer;
                                Amount    : CARDINAL;
                                StartDate : ADate;
                                EndDate   : ADate);

BEGIN
    ScheduleLongAmount(Resource^.LateResidueAvailProfile,VAL(LONGINT,Amount),
                       StartDate,EndDate);
END ScheduleLateResource;


(*------FreeResource------------------(exported)---------------------*)

PROCEDURE FreeResource (Resource  : AResourcePointer;
                        Amount    : CARDINAL;
                        StartDate : ADate;
                        EndDate   : ADate);
VAR
        MinusAmount : LONGINT;

BEGIN    
    MinusAmount := -1L * VAL(LONGINT,Amount);
    ScheduleLongAmount(Resource^.ResidueAvailProfile, MinusAmount,
                       StartDate,EndDate);
END FreeResource;

(*------FreeLateResource------------------(exported)---------------------
  
  Just like FreeResource, but references the resource's LateResidueAvail
  Profile instead of its ResidueAvailProfile.
*)

PROCEDURE FreeLateResource (Resource  : AResourcePointer;
                            Amount    : CARDINAL;
                            StartDate : ADate;
                            EndDate   : ADate);
VAR
        MinusAmount : LONGINT;

BEGIN    
    MinusAmount := -1L * VAL(LONGINT,Amount);
    ScheduleLongAmount(Resource^.LateResidueAvailProfile, MinusAmount,
                       StartDate,EndDate);
END FreeLateResource;



(*-------CollapseIntoPrevious --------collapse a cell into the previous
                                      cell if they have the same amount and
                                      vacation values-------------------*)

PROCEDURE CollapseIntoPrevious( CellHandle: AnExtHandle );
                                

VAR
    PrevHandle, NextHandle : AnExtHandle;
    Cell, Prev, Next       : AnAvailabilityCellPointer;
BEGIN

    IF LockObject(CellHandle, Cell) <> TSIZE(AnAvailabilityCell) THEN 
        FatalError(); 
    END;

    (* quit if the cell to be collapsed is a head cell *)
    IF (Cell^.IsHeadCell) THEN
        (*<PRINT SetString(NoteString,"CollapseIntoPrev: headcell");
                   PrintAString(NoteString);
                   PRINT>*)
        ReleaseUnchangedObject(CellHandle);   (*<KILL*) Cell := NIL; (*KILL>*)
    ELSE
        PrevHandle := Cell^.PrevCell; 
        NextHandle := Cell^.NextCell;
    
        IF LockObject(PrevHandle, Prev) <> TSIZE(AnAvailabilityCell) THEN 
            FatalError; 
        END;
    
        (* quit if the previous cell is a head cell *)
        IF (Prev^.IsHeadCell) THEN
            (*<PRINT SetString(NoteString,"CollapseIntoPrev: Prev is headcell");
                       PrintAString(NoteString);
                       PRINT>*)
            ReleaseUnchangedObject(CellHandle);      (*<KILL*) Cell := NIL; (*KILL>*)
            ReleaseUnchangedObject(PrevHandle);      (*<KILL*) Prev := NIL; (*KILL>*)
        ELSE    
            (*<PRINT SetString(NoteString,"CollapseIntoPrev: ");
                       TimeUtoS(Cell^.StartDate,s); ConcatLS(NoteString,s); ConcatS(NoteString," - ");
                       TimeUtoS(Cell^.EndDate,s); ConcatLS(NoteString,s); ConcatS(NoteString,", Amt = ");
                       LongToString(Cell^.AmountAvailable,s);  ConcatLS(NoteString,s); ConcatS(NoteString,", Vac = ");
                       IF (Cell^.ThisIsAVacation) THEN ConcatS(NoteString,"Yes"); ELSE ConcatS(NoteString,"No"); END;
                       PrintAString(NoteString);
                       PRINT>*)
            IF ( (Cell^.AmountAvailable = Prev^.AmountAvailable) AND
                 (Cell^.ThisIsAVacation = Prev^.ThisIsAVacation)     ) THEN
                (*<PRINT SetString(NoteString,"    Collapse it: ");
                           PrintAString(NoteString);
                           PRINT>*)
                (* collapse the current cell into its previous cell *)
                Prev^.EndDate := Cell^.EndDate;        
                Prev^.NextCell:= Cell^.NextCell;
                ReleaseObject(PrevHandle);           (*<KILL*) Prev := NIL; (*KILL>*)
        
                (* discard the current cell *)   
                ReleaseObject(CellHandle);  (*<KILL*) Cell := NIL; (*KILL>*)
                DiscardExtObject(CellHandle);
        
                (* link the following cell with the previous cell *)
                IF LockObject(NextHandle, Next) = 0 THEN 
                    FatalError; 
                END;
                Next^.PrevCell := PrevHandle;
                ReleaseObject(NextHandle);           (*<KILL*) Next := NIL; (*KILL>*)
            ELSE
                ReleaseUnchangedObject(CellHandle);  (*<KILL*) Cell := NIL; (*KILL>*)
                ReleaseUnchangedObject(PrevHandle);  (*<KILL*) Prev := NIL; (*KILL>*)
            END;
        END;
    END;    
END CollapseIntoPrevious;





(* statistics gathering: *)
(*<STATS
PROCEDURE DisplayNumberOfCells(VAR ResourceNode : ATreeNode);
VAR
   Resource       : AResourcePointer;
   Cell           : AnAvailabilityCellPointer;
   CellHandle,
   NextHandle     : AnExtHandle;
   NumberOfCells  : CARDINAL;
   BackToHeadCell : BOOLEAN;
   s              : ARRAY[0..18] OF CHAR;
   n              : ARRAY[0..5] OF CHAR;
BEGIN
   
   Resource := ResourceNode^.Methods^.GetDataObject(ResourceNode);     
   IF (NOT Resource^.LevelThisResource) THEN
        RETURN;
   END;

   CellHandle := Resource^.ResidueAvailProfile;    
   IF CellHandle = AnExtHandle(NIL) THEN
        SendErrorMsg("DisplayNumCells: CellHandle is NIL");
        FatalError();
   END;

   NumberOfCells := 0;
   BackToHeadCell := FALSE;
   REPEAT
       IF LockObject(CellHandle, Cell) = 0 THEN FatalError(); END;
       IF (Cell^.IsHeadCell) AND (NumberOfCells > 0) THEN
           BackToHeadCell := TRUE;
       END;
       NextHandle := Cell^.NextCell;
       ReleaseUnchangedObject(CellHandle);
       Cell := NIL;
       CellHandle := NextHandle;
       INC(NumberOfCells);
   UNTIL BackToHeadCell;

   SetString(s, "Number of Cells = ");
   CtoS(NumberOfCells, n);   
   ConcatLS(s, n);
   TrimRear(s);
   SendErrorMsg(s);
END DisplayNumberOfCells;
STATS>*)

END ResAvailableResources.



