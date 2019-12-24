IMPLEMENTATION MODULE CalUtility;

(*  =========================================================================
    Last Edit : February 6, 1991 1:55PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This is a module that holds calendar utility routines, ones that
        can be called by non-calendar functions, like Loading schedules.

    MODIFICATION HISTORY:

     6-Feb-91 RSC  First version.

    =========================================================================
*)


FROM Dialog         IMPORT
    (* TYPE *)          ADialogOption,
    (* PROC *)          FatalError, MultipleChoiceBox, Message;

FROM LStrings       IMPORT
    (* PROC *)          SetLengthOf, ConcatLS;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage, DisplayMessage, ConcatMessage;

FROM TimeFormat     IMPORT
    (* VAR  *)          DefaultDateFormat,
    (* PROC *)          TimeToString;

FROM Timei          IMPORT
    (* CONST *)         Jan,Dec,Sun,Sat,
    (* TYPE  *)         ATimeInfo,
    (* VAR *)           Today,
    (* PROCS *)         DaysInMonth, FindToday, KDay, DayOfWeek;

FROM Timeu         IMPORT
    (* CONST *)         YearsOnFile,
    (* TYPE *)          ATimeTable, AYearTable, AWeekTable,
    (* VAR  *)          WeeksBeginOn, SMU, SMUPH;

FROM WeekNumberInfo IMPORT
    (* PROC *)          InitWeekNumberInfo;



CONST
    ModuleNumber        = 10100;   (* For GetMessage. SAME AS CAL.MOD *)

    MAXCARDINAL         = 0FFFFH;



PROCEDURE QtrHourToSector(     QtrHour,
                               ProposedSMU      : CARDINAL;
                           VAR SectorStart,
                               SectorEnd        : CARDINAL );
BEGIN
    CASE ProposedSMU OF
        1, 5, 15  :  (* These are always ok. *)

                    SectorStart := QtrHour;
                    SectorEnd   := SectorStart;

      | 6, 10, 30 :  (* Allow dual sectors only (no .25 or .75 hours) *)

                    SectorStart := (QtrHour DIV 2) * 2;
                    SectorEnd   := SectorStart + 1;

      | 60        :  (* Allow quad sectors only *)

                    SectorStart := (QtrHour DIV 4) * 4;
                    SectorEnd   := SectorStart + 3;

    ELSE
        FatalError();  (* Not accounted for. *)
    END;

END QtrHourToSector;





(*
    FALSE means "Abort changes to Time Table"
    TRUE  means "TimeTable's WeekMaps fixed up."
*)
PROCEDURE CheckAndFixupWeekTable( VAR TimeTable   : ATimeTable;
                                      ProposedSMU : CARDINAL;
                                      Warn        : BOOLEAN ) : BOOLEAN;
VAR
    QtrHours,
    i, j,
    Day,
    Selection,
    SectorStart,
    SectorEnd       : CARDINAL;
    Result,
    Fix,
    NeverWarned,
    on              : BOOLEAN;
    s               : ARRAY [0..255] OF CHAR;
    Title           : ARRAY [0..31]  OF CHAR;
    MenuPrefix      : ARRAY [0..1]   OF CHAR;
    MenuString      : ARRAY [0..155] OF CHAR;
BEGIN
    NeverWarned := TRUE;

    FOR Day := Sun TO Sat DO
        WITH TimeTable.WeekTable[Day] DO
            QtrHours  := 0;
            i         := 0;  (* Start with Qtr Hour 0 *)
            WHILE (i <= 95) DO
                QtrHourToSector( i, ProposedSMU, SectorStart, SectorEnd );
                on := (i IN WeekMap);
                FOR j := SectorStart TO SectorEnd DO
                    IF ((j IN WeekMap) <> on) THEN
                        IF (Warn AND NeverWarned) THEN
                            GetMessage (ModuleNumber+32,s);     (* "What should I do?" *)
                            SetLengthOf (MenuPrefix, 0);
                            GetMessage (ModuleNumber+33,MenuString);    (* "Change,Forget it" *)
                            GetMessage (ModuleNumber+34,Title);         (* "Weekmap error" *)
                            Selection := 1;
                            Result := MultipleChoiceBox(s, Title, NoHelp, MenuPrefix, MenuString, Selection);
                            IF (NOT Result) OR (Selection = 2) THEN
                                RETURN FALSE;
                            END;
                            Fix := (Selection = 1);
                            NeverWarned := FALSE;
                        ELSE
                            Fix := TRUE;
                        END;
                        IF (Fix) THEN
                            IF (on) THEN
                                INCL(WeekMap,j);
                            ELSE
                                EXCL(WeekMap,j);
                            END;
                        END;
                    END;
                    IF (NOT on) THEN
                        INC(QtrHours);
                    END;
                END;

                i := SectorEnd + 1;

            END;
                (* Tics in day = (Hours in day) * (Tics Per Hour),

                   but because of cardinal math, avoid fractions by
                   wording this as:

                        (QtrHours * Tics Per Hour) / 4

                   Also note that SMUPH is not possible here because we
                   were given a "proposed SMU", not always the real one.
                *)
            TicsInDay := (QtrHours * (60 DIV ProposedSMU)) DIV 4;
        END;
    END;

    RETURN TRUE;

END CheckAndFixupWeekTable;





(* 2-Nov-90 RSC Massive reworking for qtr hour day changes.
*)
PROCEDURE RecomputeTable(VAR TimeTable    : ATimeTable;
                             DisplayMsg   : BOOLEAN );
VAR
    i               : CARDINAL;
    j               : CARDINAL;
    k               : CARDINAL;
    Day             : CARDINAL;
    Month           : CARDINAL;
    Year            : CARDINAL;
    Tics,
    date            : CARDINAL;

    monthsize       : CARDINAL;
    n               : CARDINAL;
    on              : BOOLEAN;
    Result          : BOOLEAN;
    s               : ARRAY [0..1] OF CHAR;

        (* Get this stuff off the stack when calling other procs.
        *)
    PROCEDURE Warn() : BOOLEAN;
    VAR
        Selection       : CARDINAL;
        TimeInfo        : ATimeInfo;
        s               : ARRAY [0..255] OF CHAR;
        s2              : ARRAY [0..99]  OF CHAR;
        Title           : ARRAY [0..31]  OF CHAR;
        MenuPrefix      : ARRAY [0..1]   OF CHAR;
        MenuString      : ARRAY [0..155] OF CHAR;
    BEGIN

        GetMessage (ModuleNumber+12, s);        (* "I found a bad date ..." *)
        TimeInfo.tiYear := Year + i - 1;
        TimeInfo.tiMonth := Month;
        TimeInfo.tiDay := date;
        TimeInfo.tiHour := 0;
        TimeInfo.tiMinute := 0;
        TimeToString (TimeInfo,DefaultDateFormat,s2);
        ConcatLS (s, s2);
        ConcatMessage (s, ModuleNumber+13);     (* "What should I do?" *)
        SetLengthOf (MenuPrefix, 0);
        GetMessage (ModuleNumber+14,MenuString);    (* "Ignore,Change,Forget it" *)
        GetMessage (ModuleNumber+15,Title);         (* "Calendar error" *)
        Selection := 1;
        Result := MultipleChoiceBox (s, Title, NoHelp, MenuPrefix, MenuString, Selection);
        IF (NOT Result) OR (Selection = 3) THEN
            RETURN FALSE;
        ELSIF (Selection = 2) THEN
            INCL( TimeTable.YearTable[i,Month].YearMap, date );
        END;

        RETURN TRUE;

    END Warn;

BEGIN
    DisplayMessage(ModuleNumber+6);   (*  "Reorganizing the calendar . . ."  *)

     (* Never warn here, thats been handled in the CheckProc
        of the Calendar Form.  Only result possible is TRUE.
     *)
    on   := CheckAndFixupWeekTable( TimeTable, SMU, FALSE );

    Year := TimeTable.FirstYear;
    Day  := DayOfWeek(Year,Jan,1);  (* Day of week *)

    Tics := 0;

    FOR i := 1 TO YearsOnFile DO
        FOR Month := Jan TO Dec DO
            WITH TimeTable.YearTable[i, Month] DO

                TicsAtStartOfMonth := Tics;
                StartDay           := Day;

                FOR j := 1 TO DaysInMonth(Year+i-1,Month) DO
                    IF (NOT (j IN YearMap)) THEN
                        k := TimeTable.WeekTable[Day].TicsInDay;
                        IF ((MAXCARDINAL - Tics) < k) THEN
                            Tics := MAXCARDINAL;
                        ELSE
                            INC( Tics, k );
                        END;
                    END;

                    Day := (Day+1) MOD 7;

                END;
            END;
        END;
    END;


    Today := FindToday();
    s[0] := 0C;
    Message(s);

    InitWeekNumberInfo ();                                          (* 2-Apr-90 MWP *)


    IF ( NOT DisplayMsg ) THEN      (* KKC Aug 31, 1989 *)
        RETURN;
    END;

(* The only thing that is done inside the loop is to display error messages *)
(* if there is any.                                                         *)

    FOR i := 1 TO YearsOnFile DO
        FOR Day := Sun TO Sat DO
            IF (TimeTable.WeekTable[Day].TicsInDay = 0) THEN
                FOR Month := Jan TO Dec DO
                    monthsize := DaysInMonth (Year+i-1,Month);
                    n := monthsize DIV 7 + 1;
                    FOR j := 1 TO n DO
                        date := (7+Day - TimeTable.YearTable[i,Month].StartDay) MOD 7 + 1+7*(j-1);
                        IF (date <= monthsize) THEN
                            on := (date IN TimeTable.YearTable[i,Month].YearMap);
                            IF (NOT on) THEN
                                IF (NOT Warn()) THEN
                                    RETURN;
                                END;
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;

END RecomputeTable;






END CalUtility.

