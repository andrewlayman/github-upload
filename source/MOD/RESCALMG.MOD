
IMPLEMENTATION MODULE ResCalMG;

(*V2=TRACE debugging printouts. *)

    (* Resource Calendar Merge routines

       10-Jul-90  RSC  - Cloned from ResCalUI, which got into circular
                         imports.  Changed format of
                         "MakeAvailabilityIntoResidue".
       11-Jul-90  AJL  - More miscellaneous work.
       24-Jul-90  RSC  - Restructured the routine, finished it off.
       15-Aug-90  AJL  - Modified the main loop so that we create intervals
                         covering the entire period from [MinDate,MaxDate).
                       - Convert all BigTimes to compressed Dates so that 
                         ones which convert to the same date after compression,
                         but differ beforehand, will be compared to each other
                         as equal.  This difference could previously cause 
                         degenerate, zero-length intervals to be created.
       25-Sep-90  AJL  - Modify the main loop, and add the parameter IsVacation
                         so that vacation periods can be scheduled to have 
                         availability rates just as non-vacation periods do.
        4-Oct-90  AJL  - Replace the previous CreateCell procedure with a 
                         new procedure AddInterval which avoids zero-length
                         cells and can combine two adjacent cells if their
                         properties are the same.
       18-Oct-90 AJL/CL - Rewrite AddInterval to use the new doubly linked 
                          availability list with a head cell.
                        - Add comments, rename some local variables, and
                          fix indentation to improve readability.
       26-Oct-90 CL  - In AddInterval, change argument Amount from a record
                       containing two CARDINALs to a LONGINT in order to
                       represent the total amount of available resource.
                     - In CreateAvailabilityCells, add logic to compute
                       the total amount of available resource and then
                       call AddInterval with that value.                       
       31-Jan-91 TGS    If varying rate/avail lists are NIL, use defaults
                        from Rsrcmod.
       22-Feb-91  AJL  - Add HonorDaysOff as a parameter to 
                         MakeAvailabilityIntoResidue.
       10-Oct-91  LAA  -In CreateAvailabilityCells, I put in a patch which
                        forces the AvailabilityEnd date to be MaxDate for the
                        last entry in the availability list.  Recalc assumes
                        that the end of time is MaxDate, but it's possible
                        for the end of the last year to be < MaxDate.  This
                        indicates a more general problem, but since we're
                        supposed to cut masters TODAY, I guess I'll just fix
                        it here.
    *)


FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM DateLists              IMPORT
    (* TYPE *)                  ADateList,
    (* PROC *)                  NumberOfDatesInList, GetDateListEntry,
                                CreateDateList, DisposeDateList,
                                CopyDateList;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError, NotYetImplemented;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CreateExtObjectWithSize, LockObject,
                                ReleaseObject, ReleaseUnchangedObject,
                                DiscardExtObject;

FROM ResCal                 IMPORT
    (* TYPE *)                  AnAvailabilityCellPointer, AnAvailabilityCell,
    (* PROC *)                  DisposeResAvailabilities, CreateNewCell;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AnAvailabilityRate, ACalendarEntry;

FROM RsrcMod                IMPORT
    (* CONST *)                 DefaultCostRate, DefaultAvailabilityAmount,
                                DefaultAvailabilityPercent,
    (* TYPE *)                  AResourcePointer;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  BYTE,
    (* PROC *)                  TSIZE, SIZE;

FROM Timei                  IMPORT
    (* TYPE  *)                 ADate,
    (* VAR *)                   MinDate, MaxDate;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime;


(*<TRACE
FROM LongConvert            IMPORT
    (* PROC *)                  LongToString;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, Copy, Fill, ConcatS,
                                Procustes, ConcatLS, SetLengthOf,
                                Search, TrimRear, TrimFront, SetString;

FROM ResTrace               IMPORT 
                                NoteString, PrintAString, 
                                PrintResidueAvailability;

FROM Timei                  IMPORT
    (* CONST *)                 NoDuration,
    (* TYPE  *)                 ADurationUnit, ATimeInfo,
    (* PROC  *)                 TimeUtoT;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
TRACE>*)

    



TYPE
    ACreateAvailabilityCellsContext = RECORD
        AvailabilityRate  : AnAvailabilityRate;
        AvailabilityStart,
        AvailabilityEnd   : ADate;
        AvailabilityCount : CARDINAL;
    END;


    (*<TRACE
    VAR
    S : ARRAY [0..255] OF CHAR;
    TRACE>*)





    (* AddInterval - 

	If the residual availability list doesn't exist, then create one 
    with an empty head cell followed by the new interval; otherwise, 
    insert the new interval following the head cells.

    However, (1) If the length of the new interval is not positive, 
                 quit without doing anything.
    
             (2) If the interval has the same properties as the cell
                 following the head cell, the new interval is merged 
                 into that cell.
                   
             (3) The availability list used to be built in reverve 
                 chronological order when it was a singly linked list.  
                 It remains built in such order.

                 In the future, if we want to change the order of
                 building the list, we have to carefully examine
                 all the procedures which builds the list.

    Input:

        Star/Thru     the start/thru dates of the cell to be added.
        Amount        the total amount of available resource.
        Vacation      TRUE iff this is vacation time.
        ResList       NIL if the residual list does not exist.
                      Otherwise, point to the head cell of residual 
                      availability list.
        StillGoing    TRUE iff we should process this entry.

    Output:
	
        ResList       point to the head cell of updated residual list
        StillGoing    TRUE iff the operation succeeded.
*)


PROCEDURE AddInterval(    Start, Thru       : ADate;
                          Amount            : LONGINT;
                          Vacation          : BOOLEAN;
                      VAR ResList           : AnExtHandle;
                      VAR StillGoing        : BOOLEAN );
VAR
    Cell, New, Next       : AnAvailabilityCellPointer;
    NextHandle, NewHandle : AnExtHandle;
    Merged                : BOOLEAN;
BEGIN
    (*<TRACE
        SetString(NoteString,"    Add interval: ");
        TimeUtoS(Start,S);
        ConcatLS(NoteString,S);
        ConcatS(NoteString," - ");
        TimeUtoS(Thru,S);
        ConcatLS(NoteString,S);
        IF (Vacation) THEN 
            ConcatS(NoteString,"  VACATION");
        END;
        IF (NOT StillGoing) THEN 
            ConcatS(NoteString,", But, NOT STILL GOING!!!");
        END;
        PrintAString(NoteString);
    TRACE>*)

    
    IF ( StillGoing ) AND ( Start < Thru ) THEN

        (*<TRACE
            SetString(NoteString,"        ( StillGoing ) AND ( Start < Thru )");
            PrintAString(NoteString);
        TRACE>*)
    
        Merged := FALSE;      (* initialization *)

        (* if the residual list does not exist, then create the head cell *)
        IF ( ResList = AnExtHandle(NIL) ) THEN
            (*<TRACE
                SetString(NoteString,"        Create head cell.");
                PrintAString(NoteString);
            TRACE>*)

            (* create the head cell *)
            ResList := CreateNewCell();
            IF ( ResList = AnExtHandle(NIL) ) THEN
                FatalError;
            ELSE
                IF (LockObject(ResList, Cell) <> TSIZE(AnAvailabilityCell) ) THEN
                    FatalError;
                ELSE
                    Cell^.NextCell    := ResList;
                    Cell^.PrevCell    := ResList;
                    Cell^.IsHeadCell  := TRUE;
                    ReleaseObject( ResList );   
                    Cell := NIL;
                    NextHandle := ResList;  (* the head cell point to itself *)
                END;
            END;
        ELSE
            (*<TRACE
                SetString(NoteString,"        ResList not nil");
                PrintAString(NoteString);
            TRACE>*)

            IF (LockObject(ResList, Cell) <> TSIZE(AnAvailabilityCell) ) THEN
                FatalError;
            ELSE
                NextHandle := Cell^.NextCell;
                ReleaseUnchangedObject(ResList);  
                Cell := NIL; 
          
                (* merge the new interval into the cell next to the head cell *)
                IF (LockObject(NextHandle,Next) <> TSIZE(AnAvailabilityCell)) THEN
                    FatalError;
                ELSE
                    IF ( (Next^.AmountAvailable = Amount) AND
                         (Next^.ThisIsAVacation = Vacation) ) THEN
                        Next^.StartDate := Start;
                        ReleaseObject(NextHandle);   
                        Next := NIL; 
                        Merged :=TRUE;
                        (*<TRACE
                        SetString(NoteString,"        Merged.");
                        PrintAString(NoteString);
                        TRACE>*)
                    ELSE
                        ReleaseUnchangedObject(NextHandle);  
                        Next := NIL; 
                    END;
                END;
            END;
        END;
    

        (* if not merged, then add the new interval following the head cell *)
        IF ( NOT Merged ) THEN
            (*<TRACE
                SetString(NoteString,"        Not merged, so create a new cell.");
                PrintAString(NoteString);
            TRACE>*)

            (* create a new cell *)
            NewHandle := CreateNewCell();
            IF ( NewHandle = AnExtHandle(NIL) ) THEN
                FatalError;
            ELSE
                IF (LockObject( NewHandle, New ) <> TSIZE(AnAvailabilityCell)) THEN
                    FatalError;
                ELSE
                    WITH New^ DO
                        StartDate           := Start;
                        EndDate             := Thru;
                        NextCell            := NextHandle;
                        PrevCell            := ResList;
                        AmountAvailable     := Amount;
                        ThisIsAVacation     := Vacation;
                        IsHeadCell          := FALSE;
                    END;
                    ReleaseObject( NewHandle );   
                    New := NIL;

                    (* insert the new cell between the head and the cell 
                        following the head cell 
                    *)
                    IF (LockObject( ResList, Cell ) <> TSIZE(AnAvailabilityCell)) THEN
                        FatalError;
                    ELSE
                        Cell^.NextCell := NewHandle;
                        ReleaseObject( ResList );   
                        Cell := NIL;
                    END;
        
                    IF (LockObject( NextHandle, Next ) <> TSIZE(AnAvailabilityCell)) THEN
                        FatalError;
                    ELSE
                        Next^.PrevCell := NewHandle;
                        ReleaseObject( NextHandle );   
                        Next := NIL;
                    END;
                END;
            END;
        END;
    END;
    
END AddInterval;
    
            
    
    
    









PROCEDURE GetCompressedDateListEntry(     RateList     : ADateList;
                                          N            : CARDINAL;
                                      VAR StartDate,
                                          ThruDate     : ADate;
                                      VAR Data         : ARRAY OF BYTE
                                     ) : BOOLEAN;
VAR
    BStartDate, BThruDate : ABigTime;
BEGIN
    IF GetDateListEntry( RateList, N, BStartDate, BThruDate, Data ) THEN
        StartDate := BigTimeToCalendarTime( BStartDate );
        ThruDate  := BigTimeToCalendarTime( BThruDate );
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END GetCompressedDateListEntry;








(* CreateAvailabilityCells - Create one or more cells from the avail list
                             that fall within the range BStartDate to
                             BThruDate.
    Preconditions:

        All periods are in reverse chronological order.  In other words,
        this ThruDate is less than any prior StartDate.

        Both the Availability List and Residual List are in forward
        chronological order.

        Resource Pointer is non nil.

        DateLists contain contiguous time in ascending date order,
            ie, Record N's EndDate = Record N+1's StartDate.
            Also, there are NO entries where StartDate = EndDate.

        Asking for the 0th record of a DateList returns FALSE.
            EVEN IF THE DATE LIST IS NIL.

    Input:

        StartDate        Begining of period we are interested in.
        ThruDate         End      of period we are interested in.
        ResidualList     The list of availability cells
        ResourcePointer  The resource we are working with,
        AvailabilityList The source avail list.  Can be NIL.
        Context          This proc's context.
        FirstTime        Is this the first time this proc has been called
                         for this list?
        StillGoing       Should we pay attention to this request?

    Output:

        ResidualList     The updated list of availability cells
        Context          This proc's (possibly updated) context.
        StillGoing       Did we succeed?
*)
PROCEDURE CreateAvailabilityCells(     StartDate,
                                       ThruDate         : ADate;
                                       IsVacation       : BOOLEAN;
                                   VAR ResidualList     : AnExtHandle;
                                       ResourcePointer  : AResourcePointer;
                                   VAR CreateAvailabilityCellsContext
                                                        : ACreateAvailabilityCellsContext;
                                       FirstTime        : BOOLEAN;
                                   VAR StillGoing       : BOOLEAN );
VAR
    CellStartDate,
    CellEndDate     : ADate;
    Total           : LONGINT;


BEGIN
    (*<TRACE
        SetString(NoteString,"CreateAvail: ");
        TimeUtoS(StartDate,S);
        ConcatLS(NoteString,S);
        ConcatS(NoteString," - ");
        TimeUtoS(ThruDate,S);
        ConcatLS(NoteString,S);
        IF (IsVacation) THEN 
            ConcatS(NoteString,"  VACATION");
        END;
        PrintAString(NoteString);
    TRACE>*)

    IF (StillGoing) THEN
        IF (FirstTime) THEN
            WITH CreateAvailabilityCellsContext DO
                IF (ResourcePointer^.Availability = ADateList(NIL)) THEN
                    AvailabilityCount        := 1;
                    AvailabilityStart        := MinDate;
                    AvailabilityEnd          := MaxDate;
                    AvailabilityRate.Percent := DefaultAvailabilityPercent; (* 31-Jan-91 TGS *)
                    AvailabilityRate.Amount  := DefaultAvailabilityAmount;
                ELSE
                    AvailabilityCount := NumberOfDatesInList( 
                                               ResourcePointer^.Availability, 
                                               TSIZE(AnAvailabilityRate) );
                    StillGoing        := GetCompressedDateListEntry( ResourcePointer^.Availability,
                                                           AvailabilityCount,
                                                           AvailabilityStart,
                                                           AvailabilityEnd,
                                                           AvailabilityRate );
                        (*  For resource leveling purposes, the availability
                            list is ASS U ME'd to go all the way to MaxDate,
                            even if the calendar doesn't go that far.
                        *)
                    IF (AvailabilityEnd < MaxDate) THEN        (* 10-Oct-91 *)
                        AvailabilityEnd := MaxDate;
                    END;
                END;
            END;
        END;

        WITH CreateAvailabilityCellsContext DO

                (* Find the availability record for which the
                   AvailabilityStart is less than the PeriodEnd, and
                   AvailabilityEnd   is G.E. PeriodEnd.

                   Since DateLists span all possible time without gaps,
                   and since the list is ordered by start date, we can
                   ASS-U-ME that either the record now in our context
                   area matches the criterion, or there exists a record
                   prior to this one for which both the above criteria
                   are true, and yet we only have to check the first of
                   the two.

                   If there was no availability list, we had set up
                   the context area with MinDate and MaxDate,
                   so we should never have to call "GetDateListEntry".

                   Examine the "Preconditions" of this module.
                *)

            WHILE ( AvailabilityCount > 1 ) AND
                  ( AvailabilityStart >= ThruDate ) AND
                  ( GetCompressedDateListEntry( ResourcePointer^.Availability,
                                                AvailabilityCount - 1,
                                                AvailabilityStart,
                                                AvailabilityEnd,
                                                AvailabilityRate )) DO
                DEC(AvailabilityCount);
            END;



                (* If we found an availability within this period,
                      create a cell with as much of the period as
                      we are aware of.  Loop back through all
                      relevent availabilities, stopping when
                      we have seen all moments in the period.
                *)

            IF (AvailabilityStart < ThruDate) THEN

                LOOP
                           (*<TRACE
                               SetString(NoteString,"    CreateAvail, at start of loop, AvailStart =: ");
                               TimeUtoS(AvailabilityStart,S);
                               ConcatLS(NoteString,S);
                               ConcatS(NoteString,", StartDate = ");
                               TimeUtoS(StartDate,S);
                               ConcatLS(NoteString,S);
                               PrintAString(NoteString);
                           TRACE>*)

                    (* make sure the new interval is within the period
                       between StartDate and ThruDate
                    *)   
                    IF ( AvailabilityStart > StartDate ) THEN
                        CellStartDate := AvailabilityStart;
                    ELSE
                        CellStartDate := StartDate;
                    END;
                    IF ( AvailabilityEnd < ThruDate ) THEN
                        CellEndDate := AvailabilityEnd;
                    ELSE
                        CellEndDate := ThruDate;
                    END;

                    (* compute the total amount of resource available *)
                    Total := VAL(LONGINT,AvailabilityRate.Amount) * 
                             VAL(LONGINT,AvailabilityRate.Percent);

                    AddInterval( CellStartDate,
                                 CellEndDate,
                                 Total,
                                 IsVacation,
                                 ResidualList,
                                 StillGoing );

                    IF (AvailabilityStart > StartDate) AND
                       (AvailabilityCount > 1) AND
                       (StillGoing) THEN
                        
                           (*<TRACE
                               SetString(NoteString,"    CreateAvail, looping, Avail =: ");
                               TimeUtoS(AvailabilityStart,S);
                               ConcatLS(NoteString,S);
                               ConcatS(NoteString,", StartDate = ");
                               TimeUtoS(StartDate,S);
                               ConcatLS(NoteString,S);
                               PrintAString(NoteString);
                           TRACE>*)

                        DEC(AvailabilityCount);
                        IF (NOT GetCompressedDateListEntry( ResourcePointer^.Availability,
                                                            AvailabilityCount,
                                                            AvailabilityStart,
                                                            AvailabilityEnd,
                                                            AvailabilityRate )) THEN
                            FatalError();   (* Can't get an entry? *)
                        END;
                    ELSE
(* EXIT *)              EXIT;
                    END;
                END;
            END;
        END;
    END;

END CreateAvailabilityCells;








(* Make Availability Into Residue

    Turn the resource's initial availability and cost rate lists into
    the initial residual availability list for RECALC.

    Preconditions -
    
            ResourcePointer must be valid (Non-NIL).
            FlexStor must be running.

    Postconditions -

            ResourcePointer^.AvailabilityList and ResourcePointer^.Calendar
            are unchanged.

            Any previously allocated ResidueProfile is
            disposed.

            The two lists, availabilities and the calendar, are merged
            into the residual availability list, ResidueProfile 
            (unless an error is returned.)



    Input

        ResourcePointer     the resource structure

        HonorDaysOff        If FALSE, the vacation calendars are ignored.
        

    Output

        ResidueProfile      Merged profile.

        RETURN              TRUE iff the residue list could be created.
                            FALSE otherwise.  If FALSE, the residue avail
                                 is NIL.

    Exceptions :            In case of error, the procedure will return
                            FALSE, the old availability list will have been
                            disposed, no new one created, and
                            ResidueAvailProfile is NIL.

*)


PROCEDURE MakeAvailabilityIntoResidue(     ResourcePointer   : AResourcePointer;
                                           HonorDaysOff      : BOOLEAN;
                                       VAR ResidueProfile    : AnExtHandle
                                     ) : BOOLEAN;

VAR
    N                               : CARDINAL;
    Calendar                        : ADateList;
    ResidualList                    : AnExtHandle;
    StartDate,
    ThruDate                        : ADate;
    CalendarEntry                   : ACalendarEntry;
    CreateAvailabilityCellsContext  : ACreateAvailabilityCellsContext;
    FirstTime,
    StillGoing                      : BOOLEAN;


BEGIN
    (*<TRACE
        SetString(NoteString,"----CreateAvail starting:");
        PrintAString(NoteString);
    TRACE>*)


        (* Remove any residue availabilities that are currently attached
           to the resource.
        *)
    DisposeResAvailabilities( ResidueProfile );

    
    ResidualList := AnExtHandle(NIL);
    StillGoing   := TRUE;


        (* Traverse the calendar (vacation) list in reverse order,
           creating nodes in the ResidualList.

           The ResidualList is forward linked, and that is why we
           traverse backwards.

           If the calendar node is a VACATION, make a cell with no
           amount available.  Otherwise, ask "CreateAvailabilityCells"
           to create one or more nodes with the availability for that
           period.

           Oh, and if there is no calendar for this resource, then
           create a list of just the availability profile.
        *)

    FirstTime := TRUE;

    IF (HonorDaysOff) AND (ResourcePointer^.Calendar <> NIL) THEN

        Calendar := ResourcePointer^.Calendar^.CalendarIntervals;

        N := NumberOfDatesInList( Calendar, TSIZE(ACalendarEntry) );


        WHILE (N > 0) AND
              (GetCompressedDateListEntry( Calendar, N, StartDate, ThruDate, 
                                           CalendarEntry )) DO

                (* Make sure that the intervals cover all known time.  *)

            IF (FirstTime) THEN
                ThruDate := MaxDate;
            END;


            IF (N=1) THEN 
                    (* Start at the beginning of the calendar. *)
                StartDate := MinDate;
            END;

            CreateAvailabilityCells( StartDate, ThruDate,
                                     CalendarEntry.Vacation,
                                     ResidualList,
                                     ResourcePointer,
                                     CreateAvailabilityCellsContext,
                                     FirstTime,
                                     StillGoing );
            FirstTime := FALSE;

            DEC(N);
        END;


    ELSE     (* There are no vacations. *)
        CreateAvailabilityCells( MinDate, MaxDate,
                                 FALSE,   (* Not a vacation *)
                                 ResidualList,
                                 ResourcePointer,
                                 CreateAvailabilityCellsContext,
                                 FirstTime,
                                 StillGoing );
    END;


        (* Attach the combined availability/vacation list to the resource.
        *)

    IF (StillGoing) THEN

            (* Assign just-built list to the resource. *)

        ResidueProfile := ResidualList;
    ELSE
            (* Ooops.  Failed somewhere.  Throw list away. *)

        DisposeResAvailabilities( ResidualList );
    END;

        (* Return an indication of our success or failure. *)

    (*<TRACE
        SetString(NoteString,"----CreateAvail finished:");
		IF (ResourcePointer^.ResidueAvailProfile = AnExtHandle(NIL)) THEN
            ConcatS(NoteString,"   but, the profile is NIL, which is bad.");
        END;
        PrintAString(NoteString);
		PrintResidueAvailability( ResourcePointer^.ResidueAvailProfile ); 
    TRACE>*)

    RETURN StillGoing;

END MakeAvailabilityIntoResidue;


END ResCalMG.


