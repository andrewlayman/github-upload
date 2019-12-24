IMPLEMENTATION MODULE TimeFormat;

(*  =========================================================================
    Last Edit : May 7, 1991 12:08PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Format times into external representations.
        Format WorkHours/LongTics into external representations.

    MODIFICATION HISTORY:

        RSC 12/19/88 Created this module from Captions and FormatAs.
        LAA 21-Dec-88 Changed imports for Laslo reorganization.
        RSC 23-Jan-89 Minor formatting changes.
        EGK 27-Feb-89 Changed LongDurationToString to test for a zero, and
                      leave off the time unit if necessary.
        AJL  9-Feb-89 Make sure that the time format record contains legal
                      values for all fields so that Timeu won't crash
                      during init.
        RSC 21-Mar-89 Use FSMUPH rather than SMUPH.
        20-May-89  RSC  Accomidated new WorkHours module.
        25-Sep-89  RSC  LongDurationToString uses new rules for determining
                        when to scale:  If you say there are no decimal
                        places allowed, then we scale when the value is < 1.0
                        Otherwise we scale when it is < 0.1.  Used to always
                        scale when < 0.5.
                        BUG # 1423.
        30-Oct-89 EGK   In LongDurationToString, put in an extra check to
                        make sure that the string isn't too long for its
                        string variable.
        02-Apr-90 MWP   Weeknumber support added.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        19-Oct-90 PFG   Substituted call to CompressTime() with call to
                        TtoTimeU so that fiscal years will be handled con-
                        sistently.
        12-Nov-90 PFG   Added AbsTimeAsEndDateStyle, which is exported, and
                        TtoEndDateStyle, which is not so that exporters can
                        ignore fiscal years.
        22-Jan-91 RSC   Removed AppendDurationUnit and LongDurationToString.
         7-May-91 RSC   With less than hour precision, EndDateStyle was not
                        entirely working (it assumed whole hours).
        14-May-91 AJL   Added Fiscal formatting to dates, and 
                        CheckDateFormatLength.
        26-Jun-91 AJL   No longer issue a message from within
                        CheckDateFormatLength.
    =========================================================================
*)


FROM Dialog             IMPORT 
    (* PROC *)             ErrorPhrase;

FROM GaGa               IMPORT
        (* PROCS *)        GetGaGaMessage;

FROM LStrings           IMPORT
        (* PROCS *)        SetString, SetLengthOf, Copy, RJust, Overlay,
                           Compare, Procustes, CtoS, TrimFront, TrimRear,
                           Insert, Remove, SubStr, Search, ConcatS,
                           LengthOf, Fill, TStringToLString, ConcatLS;

FROM MsgFile            IMPORT
        (* PROCS *)        GetMessage, ConcatMessage;

FROM Paranoia           IMPORT
        (* TYPE *)         AProgramState,
        (* VARS *)         ProgramState;

FROM Timeu              IMPORT
        (* VAR   *)        FSMUPH, SMU,
        (* PROCS *)        FindCorrectScale, GetStartingMonth,
                           DownScale;

FROM Timei              IMPORT
        (* TYPES *)        ADurationUnit, ADuration, ADate,
                           ASetOfADurationUnit, ATimeInfo,
        (* CONST *)        Jan, Dec,
        (* PROCS *)        DayOfWeek, TimeUtoT, TtoTimeU, AbsTimeUtoT,
                           DurationToReal;

FROM TimeJump           IMPORT
        (* PROC *)         FindNextKeyDate;

FROM WeekNumberInfo      IMPORT                                (* 2-Apr-90 MWP *)
    (* VAR *)              UsingWeekNumbers,
    (* PROC *)             CtoIntDay,
    (* PROC *)             TimeUToWeekNumber,
    (* PROC *)             TimeToWeekNumber;




CONST
    ModuleNumber            = 21900;  (* FROM FORMATAS *)
    CaptionsModuleNumber    = 19100;  (* FROM CAPTIONS *)
    TimeuModuleNumber       =   400;  (* FROM TIMEU!! *)



TYPE
    AnAMPMFragment = ARRAY [0..13] OF CHAR; (* RSC 11/1/88 *)


VAR
    AMPMString    : ARRAY BOOLEAN OF AnAMPMFragment;
    Init          : BOOLEAN;






  (* TimeStringLength - How long will a time format be?

        Preconditions  - A Valid TimeFormat that you intend to pass down
                         to TimeToString.

        Postconditions - RETURN is the length of the largest time that can
                         be returned.
   *)

PROCEDURE TimeStringLength( VAR Format : ATimeFormat ) : CARDINAL;
VAR s          : ARRAY [0..79] OF CHAR;
    Size, Loop : CARDINAL;
    Month      : CARDINAL;
    TimeInfo   : ATimeInfo;
BEGIN
     (* Because the months or day of week can be text, in any language,
        we must figure out the longest of each of these.  We loop through
        each month finding the longest one.  Then loop through 7 days to
        find the longest day of the week.
     *)
    Size := 0;
    TimeInfo.tiYear := 1987;
    TimeInfo.tiDay := 20;
    TimeInfo.tiHour := 11;
    TimeInfo.tiMinute := 20;

    FOR Loop := Jan TO Dec DO  (* For each possible month *)
        TimeInfo.tiMonth := Loop;
        TimeToString( TimeInfo, Format, s );
        IF LengthOf(s) > Size THEN
            Size  := LengthOf(s);
            Month := Loop;
        END;
    END;
    TimeInfo.tiMonth := Month;

    FOR Loop := 1 TO 28 DO  (* Cover all the days in the week. *)
        TimeInfo.tiDay := Loop;
        TimeToString( TimeInfo, Format, s );
        IF LengthOf(s) > Size THEN
            Size := LengthOf(s);
        END;
    END;

    RETURN Size;
END TimeStringLength;








  (* TimeToString - Convert cardinal time to printable international date
                    string.  This handles many formats and languages.

      Preconditions  - Year, Month, Day, Hour, Minute are valid
                       TimeFormat is filled in properly.

      Postconditions - S must be big enough for the returned date.  To see
                       how big that will be, use TimeStringLength.  Anyway,
                       S will contain the returned date
  *)

PROCEDURE TimeToString(   TimeInfo : ATimeInfo;
                        VAR Format : ATimeFormat;
                        VAR S      : ARRAY OF CHAR );
VAR
    i, j,
    WeekNumber, WeekDay,                                            (* 2-Apr-90 MWP *)
    LYear                : CARDINAL;
    FirstMonth           : CARDINAL;
    S2                   : ARRAY [0..30] OF CHAR;
    AMPMFlag, IsAM, ok   : BOOLEAN;
BEGIN
        (* If we are following the whole string by anything,
           it signals AM/PM format. *)


    AMPMFlag := (ORD(Format[4].FollowBy[0]) > 0);

        (* Put all the components into a string. *)

    SetLengthOf(S,0);
    FOR i := 0 TO HIGH(Format) DO WITH TimeInfo DO
        WITH Format[i] DO
            IF (Size > 0) THEN
                IF (Text) THEN
                    CASE Unit OF
                    Weeks :
                        CtoDay(DayOfWeek(tiYear,tiMonth,tiDay),S2);
                    | Days  :                                       (* 2-Apr-90 MWP *)
                        IF ( UsingWeekNumbers ) THEN
                            CtoIntDay(DayOfWeek(tiYear,tiMonth,tiDay),S2);
                        END;
                    | Months:
                        CtoMonth(tiMonth,S2);
                    ELSE
                        Fill(S2,"?",1);
                    END;
                        (*  Moved 11/30/88 AJL from later down *)
                    IF (ORD(S2[0]) > Size) THEN
                        Procustes(S2,Size);
                    END;
                ELSE
                    CASE Unit OF
                        Minutes  : j := tiMinute;
                    | Hours    : j := tiHour;
                                IF (AMPMFlag  AND  (tiHour > 12)) THEN
                                    DEC(j,12);
                                END;
                    | Weeks    :

                                LYear  := tiYear;

                                ok := TimeToWeekNumber ( tiMonth,
                                                         tiDay,
                                                         tiHour,
                                                         tiMinute,
                                                         LYear,
                                                         WeekNumber,
                                                         WeekDay );
                                j := WeekNumber;

                    | Days     : j := tiDay;
                    | Months   : j := tiMonth + 1;
                    | Years    :
                                 GetStartingMonth(FirstMonth);
                                 IF (FirstMonth <> Jan) THEN
                                     ConcatMessage(S,0410);  (* "FY" *)
                                 END;

                                (* If the display is in week numbers, we
                                    have to handle end of year boundary
                                    cases. The year could actually be
                                    the previous or next year.
                                *)
                                IF ( UsingWeekNumbers ) THEN

                                    LYear  := tiYear;

                                    ok := TimeToWeekNumber (tiMonth,
                                                            tiDay,
                                                            tiHour,
                                                            tiMinute,
                                                            LYear,
                                                            WeekNumber,
                                                            WeekDay );

                                    j := LYear;
                                ELSE
                                    j := tiYear;
                                END;

                                IF Size = 2 THEN (* Handle 2 digit year. *)
                                    DEC(j,(j DIV 100) * 100); (* RSC 7/11/87 *)
                                END;
                    ELSE j := 0; (* Non text week *)
                    END;
                    CtoS(j,S2);
                    WHILE (Size > ORD(S2[0])) DO
                        Insert(S2,FillChar,1);
                    END;
                END;
                ConcatLS(S2,FollowBy);
            ELSE
                SetLengthOf(S2,0); (* No size.  RSC 6/4/87 *)
            END;
        END;
        ConcatLS(S,S2);
    END; END;

    IF (AMPMFlag) THEN
        TrimRear(S);
        ConcatLS(S,AMPMString[ (TimeInfo.tiHour <= 11) ]);
    END;
END TimeToString;


















PROCEDURE TimeUtoS(TimeU:ADate; VAR s:ARRAY OF CHAR);
VAR
    TimeInfo : ATimeInfo;
BEGIN
    TimeUtoT(TimeU, TimeInfo);
    DtoS(TimeInfo,s);
END TimeUtoS;



    (* CtoMonth -- Return the name of the given month. *)



PROCEDURE CtoMonth(month:CARDINAL; VAR s:ARRAY OF CHAR);
BEGIN
    SubStr(MonthNameArray[month],s,1,HIGH(s));
END CtoMonth;





PROCEDURE CtoDay(C:CARDINAL; VAR s:ARRAY OF CHAR);
BEGIN
    (*
    CASE C OF
        Sun:     SetString(s,"Sunday");      |
        1:       SetString(s,"Monday");      |
        2:       SetString(s,"Tuesday");     |
        3:       SetString(s,"Wednesday");   |
        4:       SetString(s,"Thursday");    |
        5:       SetString(s,"Friday");      |
        Sat:     SetString(s,"Saturday");
        ELSE
            FatalError;
    END;
    *)
    GetMessage(TimeuModuleNumber+30+C,s);
END CtoDay;









PROCEDURE CtoM (month:CARDINAL; VAR m:ARRAY OF CHAR);
BEGIN
    SubStr(MonthNameArray[month],m,1,3);
END CtoM;





PROCEDURE DtoS ( TimeInfo : ATimeInfo; VAR s:ARRAY OF CHAR);
BEGIN
    s[0] := 0C;
        (* Don't do anything that could call MsgFile procedures
           until we are initialized. *)
    IF (ProgramState >= RootInit) THEN
        CASE DefaultDateOption OF

              (* Date only formats .... *)
          ShowDate :
                TimeToString( TimeInfo, DefaultDateFormat, s );

              (* Time only formats .... *)
        | ShowTime :
                TimeToString( TimeInfo, DefaultTimeFormat, s );

              (* Date And Time Formats .... *)
        | ShowDateAndTime :
                TimeToString( TimeInfo, DefaultDateAndTimeFormat, s );
        END;
    END;

END DtoS;







  (* Format As End Date Style - Return string as the end date style wants it.

      Preconditions - TheTime            Starting time unit.
                      (EndDateStyle)     (From our DEF), defined as either
                                         EndOfDay or StartOfNextDay.

      Postconditions - s                 the time.

  Based on the date style, return the date as either the start of the
  new day or the end of the old day.  This only applies to dates that
  fall exactly on day boundaries.  RSC 10/9/87
  *)

PROCEDURE FormatAsEndDateStyle( TheTime : ADate;
                            VAR s       : ARRAY OF CHAR );
VAR
    TimeInfo    :   ATimeInfo;
BEGIN

    TimeAsEndDateStyle( TheTime, EndDateStyle, TimeInfo );
    DtoS( TimeInfo, s );

END FormatAsEndDateStyle;






  (* Time As End Date Style - Return the customizable end date style.

     AbsTimeAsEndDateStyle is also available.  TimeAsEndDateStyle converts
     to fiscal years.  AbsTimeAsEndDateStyle does not.  Both call 
     TtoEndDateStyle.


      Preconditions - TheTime            Starting time unit.
                      (EndDateStyle)     (From our DEF), defined as either
                                         EndOfDay or StartOfNextDay.

      Postconditions - Year, Month, Day,
                       Hour, Minute      Returned date.  Either exactly
                                         implied by TheTime, or last
                                         minute of previous day.

  Based on the date style, return the date as either the start of the
  new day or the end of the old day.  This only applies to dates that
  fall exactly on day boundaries.  RSC 10/9/87
  *)

PROCEDURE TimeAsEndDateStyle( TheTime      : ADate;
                              EndDateStyle : AnEndDateStyle;
                              VAR TimeInfo : ATimeInfo
                            );
BEGIN

    TtoEndDateStyle(TheTime, EndDateStyle, TimeInfo, FALSE);

END TimeAsEndDateStyle;








PROCEDURE AbsTimeAsEndDateStyle( TheTime      : ADate;      (* 12-Nov-90 PFG *)
                                 EndDateStyle : AnEndDateStyle;
                                 VAR TimeInfo : ATimeInfo
                               );
BEGIN

    TtoEndDateStyle(TheTime, EndDateStyle, TimeInfo, TRUE);

END AbsTimeAsEndDateStyle;





PROCEDURE TtoEndDateStyle( TheTime      : ADate;      (* 12-Nov-90 PFG *)
                           EndDateStyle : AnEndDateStyle;
                           VAR TimeInfo : ATimeInfo;
                           FiscalYear   : BOOLEAN
                          );
VAR
    LTimeInfo : ATimeInfo;

BEGIN
     (* This routine assumes that days always end on hourly boundaries,
        and that it is not possible to have only part of an hour be
        work time, and that one "tick" is not greater than one hour. *)

        (* 7-May-91 RSC Well, the first two assumptions are no longer
                        valid.  Account for partial hours and days ending
                        on them.
        *)
    IF (FiscalYear) THEN
        AbsTimeUtoT( TheTime, TimeInfo );
    ELSE
        TimeUtoT( TheTime, TimeInfo );
    END;

    IF (EndDateStyle = EndOfDay) AND (TheTime > 0) (* AND (TimeInfo.tiMinute = 0) *) THEN
        IF (FiscalYear) THEN
            AbsTimeUtoT( (TheTime - 1) , LTimeInfo );
        ELSE
            TimeUtoT( (TheTime - 1) , LTimeInfo );
        END;

            (* See if the prior period is a different day. *)

        IF (LTimeInfo.tiDay <> TimeInfo.tiDay) THEN
            TimeInfo := LTimeInfo;
            WITH TimeInfo DO
                INC(tiMinute, SMU);      (* Add in SMU more minutes *)
                IF (tiMinute >= 60) THEN
                    INC(tiHour);
                    DEC(tiMinute,60);
                END;
            END;
        END;
    END;
END TtoEndDateStyle;













    (*  PartialDateToDate  -- Takes the date and a set of which components are
                              valid, and returns the earliest or latest date
                              that could match. *)


PROCEDURE PartialDateToDate  (     TimeInfo : ATimeInfo;
                                   DurationUnitsFound : ASetOfADurationUnit;
                                   Earliest       : BOOLEAN;
                               VAR Date           : ADate     ) : BOOLEAN;
VAR
    i              : CARDINAL;
    TimeFormat     : ATimeFormat;
    DurationUnit,
    LeastWeFormat,
    LeastSpecified : ADurationUnit;
BEGIN

        (*  If any units are left out, set the appropriate numbers
            to their smallest values.       -- EGK 11/20/89
        *)

    DurationUnit := Minutes;
    WHILE (DurationUnit <= Months) AND NOT (DurationUnit IN DurationUnitsFound) DO
        CASE DurationUnit OF
            Minutes :
                TimeInfo.tiMinute := 0;
        |   Hours :
                TimeInfo.tiHour := 0;
        |   Days :
                TimeInfo.tiDay := 1;
        ELSE
        END;
        INC (DurationUnit);
    END;

    IF NOT (TtoTimeU(TimeInfo, Date) ) THEN
        RETURN FALSE;
    END;

        (* When ambiguous dates are entered, and the end of a period
           is not rolled over to the start of the next, then we
           must do our own rollover. *)

    IF (NOT Earliest) AND (EndDateStyle = EndOfDay) THEN
            (* Find the smallest unit of time that is output by
               date formatting. *)
        CASE DefaultDateOption OF
          ShowDate :         TimeFormat := DefaultDateFormat;
        | ShowTime :         TimeFormat := DefaultTimeFormat;
        | ShowDateAndTime :  TimeFormat := DefaultDateAndTimeFormat;
        END;
        LeastWeFormat := Years;
        FOR i := 0 TO HIGH(TimeFormat) DO
            WITH TimeFormat[i] DO
                IF (Size > 0) AND (Unit < LeastWeFormat) THEN
                    LeastWeFormat := Unit;
                END;
            END;
        END;
            (* Find the smallest unit of time specified. *)
        LeastSpecified := Years;
        FOR DurationUnit := Years TO Minutes BY -1 DO
            IF ( DurationUnit IN DurationUnitsFound) THEN
                LeastSpecified := DurationUnit;
            END;
        END;
            (* Fill in all lesser time units. *)
        IF (LeastSpecified > Hours) AND (LeastSpecified >= LeastWeFormat) THEN
            Date := FindNextKeyDate(Date,LeastSpecified);
        END;
    END;

    RETURN TRUE;

END PartialDateToDate;





    (* CheckDateFormatLength -- Verify that the dates as formatted would 
                            not exceed the maximum size of ADateString.
                            If they would exceed that limit, RETURN FALSE.
    *)

PROCEDURE CheckDateFormatLength( VAR Format : ATimeFormat ): BOOLEAN;
VAR
    DateString          : POINTER TO ADateString;    (* So that HIGH will work. *)
    DateLength          : CARDINAL; 
BEGIN
        (* Make sure that the user has not picked a date and a format that
           are too large for the program.   Warn if so.   *)
    DateLength        := TimeStringLength( Format );
    IF (DateLength > HIGH(DateString^)) THEN
        RETURN FALSE;
    END;
    RETURN TRUE;
END CheckDateFormatLength;





PROCEDURE InitializeTimeFormat;
VAR
    i    :CARDINAL;
    S    : ARRAY [0..40] OF CHAR;
    DurationUnit : ADurationUnit;
    NumberPosition : ARRAY ADurationUnit OF CARDINAL;
BEGIN
        (* We have this initialization procedure so that we
           can avoid making any calls to the MsgFile module
           until it is initialized. *)
    Init := TRUE;
        (* Initialize the arrays that have month names in them. *)

    FOR i := Jan TO Dec DO
        GetMessage(TimeuModuleNumber+50+i,MonthNameArray[i]);
    END;
    SetLengthOf(MonthNameArray[12], 0 );
    GetMessage(TimeuModuleNumber+15,S);
        (* Get a default parsing style. *)
    USADate := (S[1] = "U");


        (* If both months and days are numeric, which displays
           first? *)
    FOR DurationUnit := MIN(ADurationUnit) TO MAX(ADurationUnit) DO
        NumberPosition[DurationUnit] := MAX(CARDINAL);
    END;
    FOR i := 0 TO HIGH(DefaultDateAndTimeFormat) DO
        WITH DefaultDateAndTimeFormat[i] DO
            IF (NOT Text) THEN
                NumberPosition[Unit] := i;
            END;
        END;
    END;
    IF (NumberPosition[Months] <> MAX(CARDINAL)) THEN
        USADate := (NumberPosition[Months] < NumberPosition[Days]);
    END;

END InitializeTimeFormat;





PROCEDURE InitDatesAndTimes();
VAR
    i : CARDINAL;
BEGIN
    Init := FALSE;  (* Message file init not yet done. *)

 (* Pre-init time for the people who try to use it before TLINIT is called.
    Make a VERY empty format. *)

    DefaultDateOption := ShowDateAndTime;
    EndDateStyle      := EndOfDay;

    FOR i := 0 TO HIGH(DefaultTimeFormat) DO
        WITH DefaultTimeFormat[i] DO
            Unit := Minutes;
            Size := 0;
            Text := FALSE;
            FollowBy[0] := 0C;  (* Turn off AM/PM flag *)
        END;
    END;
    DefaultDateFormat                := DefaultTimeFormat;
    DefaultDateAndTimeFormat         := DefaultTimeFormat;

 (*****  NON EXPORTED  VARIABLE INITIALIZATION ****** *)

   (* Rest of initialization is done in TlInit. *)

    GetGaGaMessage( ModuleNumber + 0, AMPMString[ TRUE  ] ); (* "am" *)
    GetGaGaMessage( ModuleNumber + 1, AMPMString[ FALSE ] ); (* "pm" *)

END InitDatesAndTimes;



BEGIN

    InitDatesAndTimes();

END TimeFormat.
