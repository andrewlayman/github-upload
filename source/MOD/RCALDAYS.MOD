IMPLEMENTATION MODULE RCalDays;

    (* Displays and edits the individual resource calendars on the 
       screen.
    *)

(*----------------------------------------------------------------------------
       MODIFICATION HISTORY:

       RSC  6-Jul-90  Cloned from Cal and CalControl
       AJL 19-Jul-90  Substantial changes, including moving a lot of code
                      to CalEdit, a module now shared by this one and the
                      Master Calendar editor, "Cal".
       RSC  3-Aug-90  Reorder the way we create new datelists so that we
                      aren't in danger of losing the old one if we can't
                      create a new one.
       RSC  4-Sep-90  Minor changes to make the width of cells bigger.
       30-Sep-90 AJL   -Made InsertKey and DeleteKey mark and unmark work
                        days.
        2-Nov-90 RSC  Ajusted for new calendar format.
       18-Jan-91 TGS  ChangeResourceCalendar now takes a Title parameter.
       15-Feb-91 TGS  DrawDateBox checks for fiscal calendar.
       20-Mar-91 TGS  If we run out of space for vacation entries, put up
                      an error box.
       14-Aug-91 AJL    CalendarCodeHandler procedure handles fiscal
                        years.
       13-Sep-91 AJL  Modified the routines that create and transform the
                      daily bitmaps so that they use bitmaps which are in
                      calendar, not fiscal, years.  This makes them match 
                      the master calendars, and fixes bug 4641.
----------------------------------------------------------------------------*)

FROM BigTimeU    IMPORT
    (* CONST *)     MINBIGTIME,
    (* TYPE *)      ABigTime,
    (* PROC *)      BigTimeToTime, TimeToBigTime;

FROM CalEdit     IMPORT
    (* PROC *)      EditCalendar;

FROM Codes       IMPORT
    (* TYPE *)      ACode;

FROM DateLists   IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      GetDateListEntry, DisposeDateList, 
                    CreateDateList, CreateDateListEntry;

FROM Dialog      IMPORT
    (* PROC *)      Burp, Error, FatalError;

FROM Helper      IMPORT
    (* TYPE *)      AScreenAction,
    (* PROC *)      GiveHelp;

FROM Kbio        IMPORT
    (* TYPE *)      ascreenx, ascreeny, avidmode,
    (* PROC *)      PutString;

FROM Keys        IMPORT
    (* CONST *)     CancelKey, HelpKey, SelectKey,
                    InsertKey, DeleteKey, MouseDown, MouseStillDown;

FROM Layout      IMPORT
    (* VAR *)       GanttWEnd;

FROM LStrings    IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, Fill, SubStr, Procustes,
                    CtoS, Search, StoC, LengthOf, SetLengthOf, RJust;

FROM Menus         IMPORT
    (* PROC *)            NoYes;

FROM MsgFile     IMPORT
    (* PROC *)      GetMessage, DisplayMessage;

FROM ResCalUI    IMPORT
    (* TYPE *)      AResourceCalendar, ACalendarEntry;

FROM Space       IMPORT
    (* PROC *)      Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM      IMPORT
    (* PROC *)      ADDRESS, ADR, SIZE;

FROM Timei       IMPORT
    (* CONST *)     Jan, Dec, 
    (* TYPE *)      ADate, ATimeInfo,
    (* PROC *)      TimeUtoT, TtoTimeU, DaysInMonth, DayOfWeek,
                    CalendarYearToFiscalYear,
                    FiscalYearToCalendarYear, AbsDaysInMonth;

FROM Timeu       IMPORT
    (* TYPE *)      ATimeTable, AMonthSet,
    (* CONST *)     YearsOnFile,
    (* VAR  *)      TimeTable;






CONST
    ModuleNumber        = 10100;   (* For GetMessage.  SAME AS CAL.MOD *)
    ControlModuleNumber = 10200;   (* SAME AS CALCONTROL.MOD *)



TYPE
    ATimeTablePointer = POINTER TO ATimeTable;
    AResCalContext = RECORD
                         SystemTimeTable,
                         ResourceTimeTable : ATimeTablePointer;
                         LastAction        : ACode;
                         ChangesMade : BOOLEAN;
                     END;





(* Fill in the bitmap of days that the resource is on vacation.
   We fill in the bitmap in terms of calendar years, not fiscal years,
   since that matches the master calendar.
*)

PROCEDURE FillInResourceTimeTable( VAR ResourceCalendar   : AResourceCalendar;
                                   VAR ResourceTimeTable  : ATimeTable );
VAR
    i,
    j               : CARDINAL;
    StartDate,
    ThruDate        : ABigTime;
    CalendarEntry   : ACalendarEntry;


    PROCEDURE Set( StartDate, ThruDate : ABigTime );
    VAR
        StartYear,
        ThruYear,  ThruMonth,  ThruDay,
        h,m,s,
        Days,
        Year,Month,Day : CARDINAL;
        i              : CARDINAL;

    BEGIN
            (* Get the start and end dates, in calendar years. *)

        BigTimeToTime( StartDate, StartYear, Month, Day, h,m,s );
        FiscalYearToCalendarYear(Month,StartYear);
        BigTimeToTime( ThruDate,  ThruYear,  ThruMonth,  ThruDay,  h,m,s );
        FiscalYearToCalendarYear(ThruMonth,ThruYear);

        WITH ResourceTimeTable DO
            Year := (FirstYear + YearsOnFile) - 1;
            IF (ThruYear >  Year) THEN
                ThruYear := Year;
            END;
            IF (StartYear <  FirstYear) THEN
                StartYear := FirstYear;
            END;
            IF (StartYear >  ThruYear) THEN
                StartYear := ThruYear;
            END;
            Year := StartYear;
            Days := AbsDaysInMonth(Year,Month);
            i    := Year - FirstYear + 1;
        END;

        LOOP
            IF (Year > ThruYear) THEN
        EXIT;
            ELSIF (Year = ThruYear) THEN
                IF (Month > ThruMonth) THEN
        EXIT;
                ELSIF  (Month = ThruMonth) AND (Day >= ThruDay) THEN
        EXIT;
                END;   
            END;    

            INCL(ResourceTimeTable.YearTable[i,Month].YearMap,  Day );

            INC(Day);
        
            IF (Day > Days) THEN
                INC(Month);
                Day := 1;
                IF (Month > Dec) THEN
                    INC(Year);
                    Month := Jan;
                END;
                Days := AbsDaysInMonth(Year,Month);
                i    := Year - ResourceTimeTable.FirstYear + 1;
            END;
        END;   

    END Set;


BEGIN
    FOR i := 1 TO YearsOnFile DO
        FOR j := Jan TO Dec DO
            ResourceTimeTable.YearTable[i,j].YearMap := AMonthSet{};
        END;
    END;

    i := 1;
    WHILE (GetDateListEntry( ResourceCalendar.CalendarIntervals,
                             i,
                             StartDate,
                             ThruDate,
                             CalendarEntry )) DO
        IF (CalendarEntry.Vacation) THEN
            Set( StartDate, ThruDate );
        END;
        INC(i);
    END;

END FillInResourceTimeTable;








(* Save the bitmap of days that the resource is on vacation.
*)
PROCEDURE SaveResourceTimeTable( VAR ResourceCalendar   : AResourceCalendar;
                                 VAR ResourceTimeTable  : ATimeTable );
VAR
    i,Year,FiscalYear,
    Month,
    Day             : CARDINAL;
    StartDate       : ABigTime;
    SavedDateList   : ADateList;
    N               : ADateListIndex;
    CalendarEntry   : ACalendarEntry;
    TooManyEntries,
    Bit,
    OldBit          : BOOLEAN;
    s               : ARRAY [0..99] OF CHAR;

BEGIN

    OldBit := FALSE; (* Off *)

    TooManyEntries         := FALSE; (* 20-Mar-91 TGS *)

    CalendarEntry.Vacation := FALSE;
    CalendarEntry.Filler   := FALSE;

        (* Create a new date list.  If succesful, remove the old one. *)

    SavedDateList := ResourceCalendar.CalendarIntervals;
    ResourceCalendar.CalendarIntervals := CreateDateList(CalendarEntry,MINBIGTIME);

    IF (ResourceCalendar.CalendarIntervals = ADateList(NIL)) THEN
        ResourceCalendar.CalendarIntervals := SavedDateList;
        RETURN;
    ELSE
        DisposeDateList( SavedDateList );
    END;

        (* Copy the calendar structure from the bit map arrangement to a
           date list.  Years are calendar, not fiscal years. *)

    FOR i := 1 TO YearsOnFile DO
        Year := ResourceTimeTable.FirstYear + i - 1;
        FOR Month := Jan TO Dec DO
            WITH ResourceTimeTable.YearTable[i,Month] DO
                FOR Day := 1 TO AbsDaysInMonth(Year,Month) DO
                    Bit := (Day IN YearMap);
                    IF (Bit <> OldBit) THEN
                        CalendarEntry.Vacation := Bit;
                        FiscalYear := Year;
                        CalendarYearToFiscalYear(Month,FiscalYear);
                        TimeToBigTime( FiscalYear,Month,Day,0,0,0,StartDate );
                        N := CreateDateListEntry( ResourceCalendar.CalendarIntervals,
                                                  StartDate,
                                                  CalendarEntry );
                        TooManyEntries := TooManyEntries OR (N=0);
                        OldBit := Bit;
                    END;
                END;
            END;
        END;
    END;

    IF TooManyEntries THEN
        GetMessage(ModuleNumber + 40, s);
        Error(s);
    END;

END SaveResourceTimeTable;



PROCEDURE DrawDateBox( Year, Month, Date : CARDINAL;
                       ULX               : ascreenx;   
                       ULY               : ascreeny;   
                       LRX               : ascreenx;
                       LRY               : ascreeny;
                       Highlight         : BOOLEAN;
                       Context           : ADDRESS );
VAR
    CalendarYear    : CARDINAL;
    ResCalContext   : POINTER TO AResCalContext;
    i               : CARDINAL;
    videomode       : avidmode;
    ResourceMark,
    SystemMark      : BOOLEAN;
    s               : ARRAY [0..31] OF CHAR;
BEGIN
        (* We are passed the fiscal year.  If this differs from the 
           calendar year, compute the calendar year. *)
    CalendarYear := Year;
    FiscalYearToCalendarYear(Month,CalendarYear);

    ResCalContext := Context;

    WITH ResCalContext^.SystemTimeTable^ DO
        i := CalendarYear - FirstYear + 1;
        SystemMark := (Date IN YearTable[i,Month].YearMap);
    END;
    WITH ResCalContext^.ResourceTimeTable^ DO
        i := CalendarYear - FirstYear + 1;
        ResourceMark := (Date IN YearTable[i,Month].YearMap);
    END;

    IF (ResourceMark) THEN
        GetMessage(ModuleNumber+20,s);  (* "Vacation  " *)
        videomode := videofilter3;
    ELSIF (SystemMark) THEN
        GetMessage(ModuleNumber+5,s);   (* "No Work   " *)
        videomode := videofilter4;
    ELSE
        Fill(s," ",HIGH(s));
        videomode := videonormal;
    END;
    Procustes( s, LRX-ULX+1 );
    IF (Highlight) THEN                (* Cursor on it. *)
        INC(videomode);
    END;

    PutString(s,ULX,ULY,videomode);

END DrawDateBox;   





PROCEDURE AllowLeaving( ChangesMade : BOOLEAN )    : BOOLEAN;

VAR
    s               : ARRAY [0..255] OF CHAR;

BEGIN
    IF (ChangesMade) THEN
        GetMessage (ModuleNumber+16,s);
        RETURN NoYes(s);
    ELSE
        RETURN TRUE;
    END;
END AllowLeaving;






PROCEDURE ResourceCalendarCodeHandler( VAR Code : ACode;
                                           Year, Month, Day : CARDINAL;
                                           Context : ADDRESS
                                     ) : BOOLEAN;
VAR
    CalendarYear    : CARDINAL;
    ResCalContext   : POINTER TO AResCalContext;
    i               : CARDINAL;
    s8              : ARRAY [0..9] OF CHAR;
BEGIN
        (* We are passed the fiscal year.  If this differs from the 
           calendar year, compute the calendar year. *)
    CalendarYear := Year;
    FiscalYearToCalendarYear(Month,CalendarYear);

    ResCalContext := Context;
    WITH ResCalContext^.ResourceTimeTable^ DO
        i := CalendarYear - FirstYear + 1;
    END;
    WITH ResCalContext^.ResourceTimeTable^.YearTable[i,Month] DO
        IF (Code = MouseStillDown) THEN
            Code := ResCalContext^.LastAction;
        END;
        ResCalContext^.LastAction := 0;

        CASE Code OF
            SelectKey,
            MouseDown :                    (* Flip the day's vacation bit. *)
                IF (Day IN YearMap) THEN
                    EXCL(YearMap, Day );
                    ResCalContext^.LastAction := DeleteKey;
                ELSE
                    INCL(YearMap, Day );
                    ResCalContext^.LastAction := InsertKey;
                END;
                ResCalContext^.ChangesMade := TRUE;
                RETURN TRUE;                           (* Code has been fully processed. *)
          | InsertKey :
                INCL(YearMap, Day );
                ResCalContext^.ChangesMade := TRUE;
                ResCalContext^.LastAction := InsertKey;
                RETURN TRUE;                           (* Code has been fully processed. *)
          | DeleteKey :
                EXCL(YearMap, Day );
                ResCalContext^.ChangesMade := TRUE;
                ResCalContext^.LastAction := DeleteKey;
                RETURN TRUE;                           (* Code has been fully processed. *)
          | HelpKey   :
                SetString(s8,"RS.MONTH");
                GiveHelp(s8,0,GanttWEnd,LeaveTheText);  (* Save space--don't save screen. *)
                RETURN TRUE;                           (* Code has been fully processed. *)
          | CancelKey :
                IF (AllowLeaving(ResCalContext^.ChangesMade)) THEN
                    ResCalContext^.ChangesMade := FALSE;   (* Cancel any changes. *)
                ELSE
                    RETURN TRUE;                        (* Ignore this key. *)
                END;
            ELSE
        END;
    END;

    RETURN FALSE;   (* We did not process the key, (or at least, not completely). *)

END ResourceCalendarCodeHandler;





(* Change Resource Calendar - Run a calendar change for a resource calendar.

    Preconditions -

            The resource calendar must be valid, although its DateList
            need not be non-NIL.

    Postconditions -

            The DateList in the resource calendar may have been changed.

    InputParameters

            ResourceCalendar    One calendar, initialized.  The DateList
                                can be NIL or a valid list.

            StartDate           The "cursor date" to start with on the
                                calendar.

    OutputParameters

            ResourceCalendar    May have been changed.

            RETURN              TRUE if changes made, FALSE otherwise
                                (either ESC pressed, F10 with no changes,
                                or memory problems)

                 ((AULX,AULY)(ALRX,ALRY)) define a region of the 
                 screen to position the chart near, but AVOIDing.
 

*)

PROCEDURE ChangeResourceCalendar( VAR ResourceCalendar : AResourceCalendar;
                                      StartDate        : ADate;                                      
                                      AULX             : ascreenx;   
                                      AULY             : ascreeny;   
                                      ALRX             : ascreenx;
                                      ALRY             : ascreeny;
                                      Title            : ARRAY OF CHAR (* 18-Jan-91 *)
                                 ) : BOOLEAN;

VAR
    ResCalContext      : AResCalContext;
    ResTimeTable       : ATimeTablePointer;
    CursorDate         : ATimeInfo;  
BEGIN
    TimeUtoT(StartDate,CursorDate);    (* Convert format of date. *)

    IF (Available(SIZE(ResTimeTable^))) THEN
        NEW( ResTimeTable );
        ResTimeTable^.FirstYear := TimeTable.FirstYear;
        FillInResourceTimeTable( ResourceCalendar, ResTimeTable^ );

            (* Set up the Context to contain parameters which specialize the 
               general calendar editting to edit a Resource calendar. *)

        WITH ResCalContext DO
            SystemTimeTable   := ADR(TimeTable);
            ResourceTimeTable := ResTimeTable;
            LastAction        := 0;
            ChangesMade       := FALSE;
        END;

             (* Edit the resource calendar. *)

        EditCalendar(ResourceCalendarCodeHandler,
                     DrawDateBox,ADR(ResCalContext),    
                     CursorDate,
                     AULX,AULY,ALRX,ALRY,
                     Title);

        IF (ResCalContext.ChangesMade) THEN
            SaveResourceTimeTable( ResourceCalendar, ResTimeTable^ );
        ELSE
            DisplayMessage(ControlModuleNumber+5);   (*  "Ok, calendar not changed."  *)
        END;
        DISPOSE( ResTimeTable );
    END;

    RETURN ResCalContext.ChangesMade;

END ChangeResourceCalendar;








END RCalDays.


