MODULE TLSetClk;

(*  =========================================================================
    Last Edit : November 8, 1990 12:12PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Set the system date.

    MODIFICATION HISTORY:

       Sep. 3, 1985, AJL - Added support for default date format.
        11/14/86 LAA    Replaced call to KeyCommand with Dispatch, and changed
                        SetState(UnScheduled) to UnSetState(Scheduled).
        2/25/88   EGK   Call SetAsOfDate after setting the clock.
        3/14/88   RSC   move form up one line.
        11/10/88  WKH   Forced DefaultDateOption to be DisplayDateAndTime.  Use
                        to be that if it was DisplayDate only, DOS time would be
                        set to 0:00am.
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        23-Jan-89 RSC   Changed Storage to Space    .
        09-Aug-89 KKC   Add copyright message.
        13-Oct-89 MWP   Don't force a recalc if the user presses ESC from form.
        21-Feb-90 KKC   Remove unreferenced id from Timeu.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
         8-Nov-90 PFG   Changes to form as per 4.5 prototype review.  Make
                        prompt into a field.
        30-Sep-91 LAA   Take a rug which includes the entire screen, since
                        we're erasing the whole thing.  Also disable lights
                        during this form so they don't re-appear.
    =========================================================================
*)


FROM AsOf         IMPORT SetAsOfDate;

FROM Clock        IMPORT 
    (* TYPE *)                  ASystemTime,
    (* PROC *)                  GetDateAndTime, SetDateAndTime;

FROM Codes        IMPORT ACode;

FROM Kbio         IMPORT avidmode, EraseScreen, PutString,
                         maxcol, maxrow;

FROM Dialog       IMPORT Message;

FROM Layout       IMPORT GanttWStart, GanttWEnd;

FROM Lights       IMPORT ActiveLightRegion, ShowLights, EnableLights;

FROM LStrings     IMPORT Fill;

FROM Keys         IMPORT ExitKey, GotoTodayKey;

FROM ChartControl IMPORT AChartState, UnSetState;

FROM Dispatcher   IMPORT Dispatch;

FROM ParseTime    IMPORT
    (* PROC *)           StoD;

FROM TimeFormat   IMPORT
    (* TYPE *)           ADateDisplayOption,
    (* VAR  *)           DefaultDateOption,
    (* PROC *)           DtoS;

FROM Timei        IMPORT
    (* TYPE *)           ATimeInfo,
    (* VAR *)            Today,
    (* PROC *)           FindToday, SystemTimeToTime, TimeToSystemTime;

FROM Forms        IMPORT AFieldValue, NullCheckProc, DoForm;

FROM Rugs         IMPORT GetRug, PutRug, ARug;

FROM Space        IMPORT ALLOCATE, DEALLOCATE;

FROM MsgFile      IMPORT GetMessage;


CONST
    ModuleNumber = 13900;  (* For GetMessage *)


(*$S+*)

PROCEDURE SetClock;
VAR
    TimeInfo                    : ATimeInfo;
    FormValue                   : ARRAY [0..1] OF AFieldValue;
    s                           : ARRAY [0..80] OF CHAR;
    OriginalScreen              : ARug;
    Code                        : ACode;
    OldDateDisplayOption        : ADateDisplayOption;
    Copyright                   : ARRAY[0..50] OF CHAR;
    ok                          : BOOLEAN;
    SystemTime                  : ASystemTime;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Fill(s, " ", 0);     (* Erase the "Now loading overlay . . ." message. *)
    Message(s);

    IF (NOT GetRug(0,0,maxcol,GanttWEnd+1,OriginalScreen)) THEN     (* 30-Sep-91 *)
        RETURN;
    END;
    EnableLights( FALSE );
    EraseScreen;
    NEW(FormValue[0].CharValue);
    NEW(FormValue[1].CharValue);
    OldDateDisplayOption := DefaultDateOption;  (* 11/10/88 WKH *)
    DefaultDateOption    := ShowDateAndTime;    (* 11/10/88 WKH *)
    ok                   := FALSE;
    GetMessage(ModuleNumber + 2, FormValue[0].CharValue^);   (* "Date:" *)
    LOOP
        GetMessage(ModuleNumber+1,s);   (*  'Please enter the current date and time.'  *)
        PutString(s,20,10,videoenhance);
        GetDateAndTime( SystemTime );
        SystemTimeToTime( SystemTime, TimeInfo );
        DtoS(TimeInfo,FormValue[1].CharValue^);
        IF (DoForm(0,GanttWStart,maxcol,GanttWEnd,7,TRUE,FormValue,NullCheckProc) = ExitKey) THEN
            IF (StoD(FormValue[1].CharValue^,TimeInfo)) AND
               (TimeInfo.tiYear >= 1984) THEN
                TimeToSystemTime( TimeInfo, SystemTime );
                SetDateAndTime( SystemTime );
                ok := TRUE;                     (* 13-Oct-89 MWP *)
                EXIT;
            END;
            (* Else keep looping. *)
        ELSE
            EXIT;
        END;
    END;
    DefaultDateOption := OldDateDisplayOption;  (* 11/10/88 WKH *)
    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);
    PutRug(0,0,maxcol,GanttWEnd+1,OriginalScreen);             (* 30-Sep-91 *)
    EnableLights( TRUE );
    ShowLights( ActiveLightRegion );
    IF ( ok ) THEN                              (* 13-Oct-89 MWP *)
       Today := FindToday();
       SetAsOfDate();
       UnSetState(Scheduled);
       Dispatch(GotoTodayKey);
    END;
END SetClock;




(*$S+*)



BEGIN
    SetClock;
END TLSetClk.
