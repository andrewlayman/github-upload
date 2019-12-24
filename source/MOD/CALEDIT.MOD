IMPLEMENTATION MODULE CalEdit;

(*  =========================================================================
    Last Edit : November 8, 1990 12:41PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
       Provides the generic procedures for editting a calendar, which
       is a series of months that can be scrolled from month to month,
       and editted. 

    MODIFICATION HISTORY:

       16-Jul-90 AJL  Initial version.
        4-Sep-90 RSC  Minor changes to make the width of cells bigger.
       10-Sep-90 RSC  Handle mouse events better, so both UPS and DOWNS
                      don't move months, only DOWNS and STILL DOWNS.
       30-Sep-90 AJL  Made the Up and Down keys move from month to month,
                      but keeping the day of the week.
                      Allow the GotoKey to bring up a date editting form.
        6-Oct-90 AJL  Add insert and delete mouse buttons.
                      Rearranged the processing of MouseUp and MouseDown.
       15-Oct-90 RSC  Make the width of cells 1 bigger.  Enabled Help.
        6-Nov-90 AJL  Avoid placing the calendar too high.  Keep lower
                      than the top prompt lines.
        8-Nov-90 PFG  Changes to form as per 4.5 prototype review.  Make
                      prompt into a field.
       18-Jan-91 TGS  EditCalendar now requires a Title.
        8-Feb-91 TGS  Fix Forward() and Backward() so they notice Fiscal
                      years.
       15-Feb-91 TGS  When moving Up or Down, make sure year index stays
                      in synch. Fix SetDateByIndex.
       20-Mar-91 TGS  Resynch index after GoToDate.
       15-May-91 AJL   Add fiscal year to calendar.
       14-Aug-91 AJL  Somehow, a number of bug fixes got LOST:
                      1.  Remove reference to debug procs DazeInMonth and
                          DayOfWeak.
                      2.  Pass calendar year, not fiscal year, to client
                          code handler.

    =========================================================================
*)


FROM Boxes       IMPORT
    (* TYPE *)      ABoxType, ABoxAttribute, AMouseClickPoint,
    (* PROC *)      DrawBox, CorrelateMousePoint, GetInnerBoxSize,
                    CorrelateMouseToCode;

FROM Codes       IMPORT
    (* TYPE *)      ACode;

FROM Dialog      IMPORT
    (* PROC *)      Burp, FatalError, NotYetImplemented;

FROM Events      IMPORT
    (* TYPE *)      AnEvent, AnEventType,
    (* PROC *)      GetNextEvent;

FROM Fits        IMPORT 
    (* PROC *)      Within, Without;

FROM Forms        IMPORT
    (* TYPE *)       AFieldValue,
    (* PROC *)       NullCheckProc, DoForm;

FROM Kbio        IMPORT
    (* TYPE *)      ascreenx, ascreeny, avidmode,
    (* const  *)    maxcol,
    (* PROC *)      PutString, PutAttribute, PourText;

FROM Keys        IMPORT
    (* CONST *)     Fwrd, Reverse, Up, Down, Tab, RTab, ExitKey,
                    SelectKey, CancelKey, DoIt, TimeoutKey,
                    RollUp, RollDown, GotoKey, HelpKey,
                    MouseUp, MouseDown, MouseStillDown, MouseDouble;

FROM Layout      IMPORT
    (* CONST *)     MaxColumn, 
    (* VAR  *)      MaxRow, GanttWStart, GanttWEnd;

FROM LStrings    IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, Fill, SubStr, Procustes,
                    CtoS, Search, StoC, LengthOf, SetLengthOf, RJust;

FROM Mouse       IMPORT
    (* PROC *)      MousePresent;

FROM MsgFile     IMPORT
    (* PROC *)      GetMessage, ConcatMessage;

FROM ParseTime    IMPORT
    (* PROC *)           StoD;

FROM Rugs        IMPORT
    (* TYPE *)      ARug,
    (* PROC *)      GetRug, PutRug;

FROM Space       IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE;

FROM SYSTEM      IMPORT
    (* PROC *)      ADDRESS, ADR, TSIZE, SIZE;

FROM TimeFormat   IMPORT
    (* TYPE *)      ADateDisplayOption,
    (* VAR  *)      DefaultDateOption,
    (* PROC *)      DtoS, CtoMonth, CtoDay;

FROM Timei       IMPORT
    (* CONST *)     Jan, Dec, Sun, Sat,
    (* TYPE *)      ADate, ATimeInfo, ADurationCounter,
    (* PROC *)      TimeUtoT, TtoTimeU, 
                    DaysInMonth, DayOfWeek,
                    KDay, KDate, FiscalYearToCalendarYear;

FROM Timeu       IMPORT
    (* TYPE *)      AWeekTable, ATimeTable, AYearTable,
    (* CONST *)     YearsOnFile,
    (* VAR  *)      TimeTable,
    (* PROC *)      GetStartingMonth;




CONST
    ModuleNumber        = 10100;   (* For GetMessage.  SAME AS CAL.MOD *)


    BoxWidth     = 8;   (* + left and right dividers    *) (* 15-Oct-90 RSC *)
    BoxHeight    = 1;   (* + upper and lower dividers   *)
    BoxesX       = 7;   (* # of boxes accross           *)
    BoxesY       = 6;   (* # of boxes down              *)
    Spacer       = 1;   (* Width of the separating line *)
    TitleY       = 2;   (* Year row, Day names row      *)
    BorderWidth  = 4;   (* Box border and shadow.       *)
    BorderHeight = 3;   (* BoxBorder and shadow.        *)   
    CalWidth     = ((BoxWidth  + Spacer) * BoxesX) - Spacer + BorderWidth;
    CalHeight    = ((BoxHeight + Spacer) * BoxesY) + TitleY + BorderHeight;



PROCEDURE DoDateForm( VAR TimeInfo : ATimeInfo );
VAR
    NewDate                     : ATimeInfo;
    FormValue                   : ARRAY [0..1] OF AFieldValue;
    s                           : ARRAY [0..80] OF CHAR;
    Code                        : ACode;
    OldDateDisplayOption        : ADateDisplayOption;
    ok                          : BOOLEAN;
BEGIN
    NEW(FormValue[0].CharValue);
    NEW(FormValue[1].CharValue);
    OldDateDisplayOption := DefaultDateOption;  (* 11/10/88 WKH *)
    DefaultDateOption    := ShowDate;           (* 11/10/88 WKH *)
    ok                   := FALSE;

    GetMessage(ModuleNumber + 35, FormValue[0].CharValue^);   (* "Move To Date:" *)
    NewDate := TimeInfo; 
    DtoS(NewDate,FormValue[1].CharValue^);

    IF (DoForm(0,GanttWStart,maxcol,(GanttWEnd-GanttWStart) DIV 2,
               7 (* Form number 7 is the date form. *),
               TRUE,FormValue,NullCheckProc) = ExitKey) THEN
        IF (StoD(FormValue[1].CharValue^,NewDate)) AND
           (NewDate.tiYear >= TimeTable.FirstYear) AND 
           (NewDate.tiYear <= TimeTable.FirstYear + YearsOnFile-1 ) THEN
            TimeInfo := NewDate;
        END;
    END;

    DefaultDateOption := OldDateDisplayOption;  (* 11/10/88 WKH *)
    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);
END DoDateForm;



    (* DOMONTH -- Display the calendar for a given month on the
                 screen and allow the user to change selected
                 days to working or non-working.  On exit, it
                 returns the code entered that caused the exit.

                 Note: because of the way this procedure loses control
                 when it returns in order to allow changes from month
                 to month, the interface also loses control.  Consequently,
                 there is no record of the location of the previous mouse
                 down region, which leads to some awkwardnesses, such as
                 the fact that a MouseStillDown will be processed even
                 it the original MouseDown was not in the same area. 

                 *)

PROCEDURE DoMonth (    ClientCodeHandler : ACalCodeHandler;
                       DrawDateContents  : ADateContentsProc;
                       Context           : ADDRESS;   
                       year,
                       month             : CARDINAL;
                   VAR Day               : CARDINAL;
                       ULX, OULX         : ascreenx;
                       ULY, OULY         : ascreeny;   
                       LRX, OLRX         : ascreenx;
                       LRY, OLRY         : ascreeny;
                       BoxType           : ABoxType  ) : ACode;
VAR
    Event               : AnEvent;  (* 13-Dec-89 RSC *)
    CalendarYear,
    i,
    j,
    x                   : ascreenx;
    y                   : ascreeny;
    days,
    startday            : CARDINAL;
    YearStart,
    YearEnd,
    MonthStart,
    MonthEnd            : CARDINAL;
    FirstBoxTop         : CARDINAL;
    LastDownPoint,
    MouseClickPoint     : AMouseClickPoint;
    ClickDay, LastDownDay: CARDINAL;
    Code                : ACode;
    s, s2               : ARRAY [0..81] OF CHAR;
    NewMouseDown,
    OnADate,
    on,
    ExitFlag            : BOOLEAN;



    PROCEDURE MakeGrid;
    VAR
        x       : ascreenx;
        y       : ascreeny;
        i,j,FirstMonth     : CARDINAL;
        s, s2   : ARRAY [0..81] OF CHAR;
    BEGIN
        CtoMonth(month,s);
        ConcatS(s,"  ");
            (* If the user has activated a fiscal year, put in the
               designation. *)
        GetStartingMonth( FirstMonth );
        IF (FirstMonth <> Jan) THEN
            CtoS(CalendarYear,s2);
            ConcatLS(s,s2);
            ConcatMessage(s,ModuleNumber+25);  (* "   (Fiscal " *)
            CtoS(year,s2);
            ConcatLS(s,s2);
            ConcatMessage(s,ModuleNumber+26);  (* ")" *)
        ELSE
            CtoS(year,s2);
            ConcatLS(s,s2);
        END;
    
        Procustes( s, LRX - ULX + 1);
        PutString(s, ULX, ULY, videonormal );

        x := ULX; 
        FOR j := Sun TO Sat DO
            CtoDay(j,s);
            s[0] := 3C;
            PutString(s, x, ULY+1, videomessage );
            INC(x, BoxWidth + Spacer);
        END;

        Fill (s, "Ä",(LRX-ULX)+1);
        Fill (s2," ",(LRX-ULX)+1);

        j := 1;
        FOR i := ULX TO LRX DO
            IF ((j MOD (BoxWidth+1)) = 0) THEN
                s[j]  := 'Å';
                s2[j] := '³';
            END;
            INC(j);
        END;

        j := 0;
        FOR i := ULY+2 TO LRY DO
            IF ((j MOD (BoxHeight+1)) = 0) THEN
                PutString(s,ULX,i,videomessage)
            ELSE
                PutString(s2,ULX,i,videomessage);
            END;
            INC(j);
        END;

    END MakeGrid;


    (* Given a Day of the month, find the ULX and ULY of the
       TOP SEPARATOR of the box.  In other words, the "X" point:

            =X=====
            |     |
            =======

    *)
    PROCEDURE GetXY(     Day : CARDINAL;
                     VAR x   : ascreenx;
                     VAR y   : ascreeny );
    VAR
        BoxNumber : CARDINAL;
    BEGIN
        BoxNumber := Day + startday - 1;

        x := ULX + ((BoxNumber MOD 7) * (BoxWidth+Spacer));
        y := FirstBoxTop + ((BoxNumber DIV 7) * (BoxHeight+Spacer));

    END GetXY;


    PROCEDURE FindXY(     x    : ascreenx;
                          y    : ascreeny;
                      VAR Date : CARDINAL ) : BOOLEAN;
    VAR
        BoxX    : ascreenx;
        BoxY    : ascreeny;
        NewDate : CARDINAL;
    BEGIN
        FOR NewDate := 1 TO days DO
            GetXY( NewDate, BoxX, BoxY );
            IF (x >= BoxX) AND
               (x < (BoxX + BoxWidth)) AND
               (y = BoxY+1) THEN
                Date := NewDate;
                RETURN TRUE;
            END;
        END;

        RETURN FALSE;

    END FindXY;


    PROCEDURE NumberDate( date  : CARDINAL);
    VAR
        x           : ascreenx;
        y           : ascreeny;
        s           : ARRAY [0..11] OF CHAR;
    BEGIN
        GetXY(date,x,y);
        CtoS(date,s);
        IF (LengthOf(s)=1) THEN
           INC(x);
        END;
        PutString(s,x,y,videonormal);     
    END NumberDate;



    PROCEDURE MarkDate( date            : CARDINAL;
                        Highlight       : BOOLEAN);
    VAR
        x           : ascreenx;
        y           : ascreeny;
    BEGIN
        GetXY(date,x,y);
        DrawDateContents( year, (* fiscal *)
                          month, date, x, y+1, x+BoxWidth-1, y+BoxHeight-2,
                          Highlight,
                          Context );
    END MarkDate;

    (*
    PROCEDURE DazeInMonth(Year,Month:CARDINAL):CARDINAL;
    VAR
        Days,
        StartingMonth : CARDINAL;
    BEGIN
    
        IF (Month = 1) THEN
                (* 13-Jan-91 TGS Special case: FY starts Feb *)
            GetStartingMonth(StartingMonth);
            IF (StartingMonth = 1) THEN
                DEC(Year);
            END;
    
            IF (Year MOD 4 = 0) THEN
                Days := 29;
            ELSE
                Days := 28;
            END
        ELSE
            IF (Month < 7) THEN INC(Month) END;
            Days := 30 + (Month MOD 2);
        END;
    
        RETURN Days;
    
    END DazeInMonth;
    
    PROCEDURE DayOfWeak (year,month,day:CARDINAL):CARDINAL ;
    BEGIN
        RETURN (KDay(year,month,day) + 5) MOD 7
    END DayOfWeak;
    *)

BEGIN (* DoMonth *)
        (* We are passed the fiscal year.  If this differs from the 
           calendar year, compute the calendar year. *)
    CalendarYear := year;
    FiscalYearToCalendarYear(month,CalendarYear);

    days      := DaysInMonth(year,month);
    startday  := DayOfWeek(year,month,1);
    (* debug code here
    days      := DazeInMonth(year,month);
    startday  := DayOfWeak(year,month,1);
       debug code off  *)
    LastDownPoint := OnOutside;
    LastDownDay   := 0;
    NewMouseDown := TRUE;


    MakeGrid();

    FirstBoxTop := ULY + 2;

        (* Put in the dates. *)

    FOR i := 1 TO days DO
        NumberDate( i );
        MarkDate( i, FALSE);
    END;

    ExitFlag := FALSE;

        (* Loop while input for this month. *)

    REPEAT
        MarkDate( Day, TRUE );

        GetNextEvent( Event );

        MarkDate( Day, FALSE);


        Code := Event.EventCode;

        IF (Event.EventType = MouseEvent) THEN

            MouseClickPoint := CorrelateMousePoint( OULX, OULY, OLRX, OLRY,
                                                    BoxType,
                                                    Event.EventX,
                                                    Event.EventY );

                (* Scroll bars and dates act on the mouse down. *)

            IF (Code = MouseDown)      OR
               (Code = MouseStillDown) THEN 
                CASE MouseClickPoint OF
                | OnInside       : 
                    OnADate := FindXY( Event.EventX, Event.EventY, ClickDay);
                    IF OnADate THEN
                        IF (ClickDay <> LastDownDay) THEN
                            NewMouseDown := TRUE;
                        END;
                        IF (NewMouseDown) THEN  (* Avoid still down flurry. *)
                            LastDownDay := ClickDay;
                            NewMouseDown := FALSE;
                        END;
                        Day := ClickDay;
                    ELSE
                        Code := 0;
                    END;

                | OnVScrollUp    : Code := RTab;
                | OnVScrollDown  : Code := Tab;
                ELSE
                    Code := 0;
                END;
                LastDownPoint := MouseClickPoint;
            END;

               (* Buttons act on mouse up. *)

            IF (Code = MouseUp) THEN
                Code := 0;
                IF (MouseClickPoint = LastDownPoint) THEN
    
                    CASE MouseClickPoint OF
                    | OnInside,   
                      OnVScrollUp, 
                      OnVScrollDown  :   (* React on the down. *)

                    | OnHelp         : Code := HelpKey;  (* 15-Oct-90 RSC *)

                    ELSE
                        Code := CorrelateMouseToCode(OULX, OULY, OLRX, OLRY,
                                                     BoxType,
                                                     Event.EventX,
                                                     Event.EventY );
                    END;
                END;
                NewMouseDown := TRUE;
            END;


        END;

        IF (Code = 0) THEN
            (* Ignore it.  Don't confuse the code handler by passing it. *)
        ELSIF (NOT ClientCodeHandler( Code, 
                                      year, (* fiscal *)
                                      month, Day, Context )) THEN

            CASE Code OF
            | Fwrd,
              DoIt   :   
                IF (Day < days) THEN INC(Day);
                ELSE
                    Day := 1;  (* Next month *)
                    Code := Tab;
                    ExitFlag := TRUE;
                END;

            | Reverse :
                DEC(Day);
                IF (Day = 0) THEN
                    Day := 99;    (* Next month. Make Day > any possible day. *)
                    Code := RTab;
                    ExitFlag := TRUE;
                END;

            | Up      :
                IF (Day > 7) THEN DEC(Day,7);
                ELSE ExitFlag := TRUE;
                END;

            | Down    :
                IF (Day <= days-7) THEN INC(Day,7);
                ELSE ExitFlag := TRUE;
                END;

                (* Code 253 following is special repaint screen key. *)
            | Tab, RTab,
              RollUp, RollDown,
              ExitKey, CancelKey,
              GotoKey, 253      :
            
                ExitFlag := TRUE;
    
            ELSE
                IF (Event.EventType <> MouseEvent) THEN
                    Burp;
                END;

            END;
        END;


    UNTIL ExitFlag;
    
    RETURN Code;

END DoMonth;







PROCEDURE DoYears (     ClientCodeHandler   : ACalCodeHandler;
                        DrawDateContents    : ADateContentsProc;
                        Context             : ADDRESS;   
                    VAR CursorDate          : ATimeInfo;
                        ULX, OULX           : ascreenx;
                        ULY, OULY           : ascreeny;   
                        LRX, OLRX           : ascreenx;
                        LRY, OLRY           : ascreeny;   
                        BoxType             : ABoxType   );
VAR
    StartingMonth,
    i,
    j           : CARDINAL;
    Code        : ACode;
    Date        : ADurationCounter;

    PROCEDURE SetDateByIndex();
    BEGIN
        WITH CursorDate DO
            tiYear := i + TimeTable.FirstYear - 1;
            IF (tiMonth >= StartingMonth) AND
               (StartingMonth > Jan)      THEN (* 15-Feb-91 TGS *)
                INC(tiYear);
            END;
            j := DaysInMonth(tiYear,tiMonth);
            IF (tiDay > j) THEN
                tiDay := j;
            ELSIF (tiDay = 0) THEN 
                tiDay := 1;
            END;
        END;
    END SetDateByIndex;

    PROCEDURE Forward();
    BEGIN
        WITH CursorDate DO
            IF (tiMonth = Dec) THEN
                tiMonth := Jan;
                IF (i < YearsOnFile) THEN
                    INC(i);
                ELSE
                    i := 1;
                END;
            ELSE
                INC(tiMonth);
            END;
            SetDateByIndex();
        END;
    END Forward;


    PROCEDURE Backward();
    BEGIN
        WITH CursorDate DO
            IF (tiMonth = Jan) THEN
                tiMonth := Dec;
                IF (i > 1) THEN
                    DEC(i)
                ELSE
                    i := YearsOnFile
                END;
            ELSE
                DEC(tiMonth);
            END;
            SetDateByIndex();
        END;
    END Backward;

    PROCEDURE SetIndexByDate();  (* 15-Jan-91 TGS *)
    BEGIN
        i := CursorDate.tiYear - TimeTable.FirstYear + 1;
        IF (CursorDate.tiMonth >= StartingMonth) AND
           (StartingMonth > Jan ) THEN
            DEC(i)
        END;
        IF (i < 1) THEN
            i := YearsOnFile;
            SetDateByIndex();
        ELSIF (i > YearsOnFile) THEN
            i := 1;
            SetDateByIndex();
        END;
    END SetIndexByDate;
   
BEGIN (* DoYears *)
    
    GetStartingMonth(StartingMonth); (* 8-Feb-91 TGS *)
    SetIndexByDate();

    LOOP
        PutPrompts();

        WITH CursorDate DO
            Code := DoMonth(ClientCodeHandler,
                            DrawDateContents,Context,
                            tiYear, tiMonth, tiDay,
                            ULX,OULX,ULY,OULY,LRX,OLRX,LRY,OLRY,BoxType );
        END;

        CASE Code OF
        | ExitKey,
          CancelKey,
          TimeoutKey :
            EXIT;

        | Tab,
          RollDown   :  
            Forward();

        | RTab,
          RollUp     :
            Backward();

        | Down       :      (* Go to the same day, next week *)
            WITH CursorDate DO
                Date := KDay(tiYear,tiMonth,tiDay);
                KDate(Date+7, tiYear,tiMonth,tiDay);
                SetIndexByDate(); (* 15-Feb-91 TGS *)
            END;

        | Up         :      (* Go to the same day, last week *)
            WITH CursorDate DO
                Date := KDay(tiYear,tiMonth,tiDay);
                KDate(Date-7, tiYear,tiMonth,tiDay);
                SetIndexByDate(); (* 15-Feb-91 TGS *)
            END;

        | GotoKey    :
            DoDateForm( CursorDate );
            SetIndexByDate(); (* 20-Mar-91 TGS *)

        ELSE
            Burp;

        END; (* Case *)

    END;

END DoYears;


    (* Instructions for which keys do what. *)

PROCEDURE PutPrompts();
VAR
    i                  : CARDINAL;
    LastY              : ascreeny;      
    S                  : ARRAY [0..101] OF CHAR;
BEGIN
    FOR i := 0 TO 1 DO
        GetMessage(ModuleNumber+1+i,S);
        PourText(S,videomessage,0,i,MaxColumn,GanttWStart,LastY);
    END;
    SetString(S," ");
    PourText(S,videomessage,0,2,MaxColumn,GanttWStart,LastY);
END PutPrompts;


PROCEDURE EditCalendar(     ClientCodeHandler : ACalCodeHandler;
                            DrawDateContents  : ADateContentsProc;
                            Context           : ADDRESS;   
                        VAR CursorDate        : ATimeInfo;                                      
                            AULX              : ascreenx;   
                            AULY              : ascreeny;   
                            ALRX              : ascreenx;
                            ALRY              : ascreeny;
                            Title             : ARRAY OF CHAR (* 18-Jan-91 TGS *)
                       );        


VAR
    Rug,PromptRug      : ARug;
    ULX                : ascreenx;
    ULY                : ascreeny;   
    LRX                : ascreenx;
    LRY                : ascreeny;   
    iULX               : ascreenx;
    iULY               : ascreeny;   
    iLRX               : ascreenx;
    iLRY               : ascreeny;   
    BoxType            : ABoxType;   
    RugTaken,
    PromptRugTaken     : BOOLEAN;
    s0                 : ARRAY [0..0] OF CHAR;
BEGIN
    IF ( MousePresent() ) THEN 
        BoxType     := ABoxType{DoubleBox,ShadowBox,HasOk,HasCancel,HasVScroll,
                                HasHelp};
    ELSE
        BoxType     := ABoxType{DoubleBox,ShadowBox};
    END;


        (* Determine the area in which to draw the calendar.   Put the 
           calendar to one side or another of the area to avoid, preferably. *)

    Without( CalWidth, CalWidth, AULX, ALRX, 0, MaxColumn, ULX, LRX );
    IF (ULX > ALRX) OR (LRX < AULX) THEN  (* Non-overlapping. *)
        LRY := ALRY;                      (* Align with field. *)
        IF (LRY >= CalHeight-1 ) THEN
            ULY := LRY - (CalHeight-1);
        ELSE
            ULY := 0;
            LRY := CalHeight-1;
        END;
    ELSE
        Without( CalHeight, CalHeight, AULY, ALRY, 0, GanttWEnd, ULY, LRY );
    END;
    Within(ULY,LRY,GanttWStart,GanttWEnd);  (* Avoiding the prompt areas. *)

        (* Copy the area behind it, and draw the calendar. *)

    s0[0] := 0C;
    PromptRugTaken := GetRug( 0,0,MaxColumn,GanttWStart-1, PromptRug );
    DrawBox(0,0,MaxColumn,GanttWStart-1,ABoxType{NoBox},s0,videonormal);
    RugTaken := GetRug( ULX, ULY, LRX, LRY, Rug );
    DrawBox( ULX, ULY, LRX, LRY,        (* Draw border around the calendar. *)
             BoxType,
             Title,
             videomessage );
    iULX := ULX;   iULY := ULY;   iLRX := LRX;   iLRY := LRY;
    GetInnerBoxSize(iULX,iULY,iLRX,iLRY,BoxType);

    DoYears( ClientCodeHandler,
             DrawDateContents,Context,
             CursorDate,
             iULX, ULX, iULY, ULY, iLRX, LRX, iLRY, LRY, BoxType );

    IF (RugTaken) THEN
        PutRug( ULX, ULY, LRX, LRY, Rug );
    END;
    IF (PromptRugTaken) THEN
        PutRug( ULX, ULY, LRX, LRY, PromptRug );
    END;

END EditCalendar;


END CalEdit.
