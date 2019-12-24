IMPLEMENTATION MODULE Matches;

    (* MODIFICATION HISTORY:

       May 28, 1986   AJL - Read decimal fractions in durations.
       May 29, 1986   AJL - ALAP is no longer as synonym for TARGET.
       Jun 8, 1986    AJL - Allow common abbreviations for Dys, Mths,
                            etc.
       Jun 21, 1986   AJL - Changed MatchDateAtStart parsing to not
                            allow two punctuations in a row.
                          - Allow hours in military format.
                          - Exit from first loop on detection of
                            an hour, but without removing it from string,
                            so that it can be reparsed as an hour by
                            second loop.
        Dec 16, 1986  AJL - Changed MatchDateAtStart so that it will not
                            accidently match two month names in a row.
                          - MatchAMonthName was returning the chronologically
                            earlier month if the string contained more than
                            one month.
         Dec. 22, 1986 AJL- Adjust the ProbableYear routine to allow fewer
                            months in the past and more in the future.
         Dec. 30, 1986 AJL- Fix MatchDateAtStart so that it doesn't
                            override the year with a ProbableYear when a
                            year has already been found.
                          - When a month is found, set the Day to 1 (unless
                            it has already been found).
                          - Use FindFittingScale to adjust durations to
                            account for fractions.
         Jan. 12, 1987 AJL -Use a local version of FindNonZeroScale since
                            the one in the Captions module in the base
                            layer may be bad.
         Mar.  7, 1988 RSC -Internationalized.

       21-Dec-88 LAA        Changed imports for Lazlo reorganization.

       21-Feb-89 RSC        Added "MatchBoolean" for the importers.
       20-May-89 RSC        Accomidated new WorkHours module.
       30-Mar-90 RSC        Made Timeu to Timei/TimeForm conversions.
       19-Apr-90 KKC        Grouped year, month, day, hour, minute into one
                            date structure, ATimeInfo. 
       15-May-91 AJL        Parse the letters "FY" to mean fiscal year.
    *)

FROM Allocs          IMPORT AStartStatus, AFixType;

FROM Dialog          IMPORT Error, FatalError;

FROM ParseReal       IMPORT AmountToReal;

FROM LStrings        IMPORT SetString, Insert, ConcatS, ConcatLS, Remove,
                            SubStr, LStringToTString, TrimRear, Upshift,
                            TrimFront, StoC, Compare, Procustes, Fill,
                            Copy, Overlay, Search, CtoS, LengthOf;

FROM Menus           IMPORT
        (* PROCS *)         WordNumber;

FROM MsgFile         IMPORT
        (* PROCS *)         GetMessage, ConcatMessage, DisplayMessage;

FROM TimeFormat      IMPORT
        (* PROC *)          TimeUtoS, CtoMonth, PartialDateToDate;

FROM Timei           IMPORT
    (* CONST *)         Jan, Dec, OneUnitOfDuration,
    (* TYPE *)          ADuration, ADurationUnit, ADate, ASetOfADurationUnit,
                        ATimeInfo,
    (* PROC *)          TimeUtoT, DaysInMonth, TtoTimeU, DurationToReal,
                        CalendarYearToFiscalYear;

FROM Timeu           IMPORT
    (* VARS *)          TimeTable, YearsOnFile, SMUPH, SMU,
    (* PROC *)          UpScale,  DownScale;

FROM WorkHours        IMPORT
        (* PROCS *)         WorkHoursToRealTime, RealTimeToDuration;



CONST
    PlaceHolder        = "~";

    ModuleNumber       = 23500;



PROCEDURE Alphabetic( C : CHAR ) : BOOLEAN;
BEGIN
    C := CAP(C);
    RETURN (C >= "A") AND (C <= "Z");
END Alphabetic;


PROCEDURE Numeric( C : CHAR ) : BOOLEAN;
BEGIN
    RETURN (C >= "0") AND (C <= "9");
END Numeric;



PROCEDURE AlphaNumeric( C : CHAR ) : BOOLEAN;
BEGIN
    RETURN Alphabetic(C) OR (Numeric(C));
END AlphaNumeric;




PROCEDURE NumberPart( C : CHAR ) : BOOLEAN;
BEGIN
    RETURN (Numeric(C)) OR ( C = ".");
END NumberPart;





    (* EndOfWord -- Move End to termination of word. *)

PROCEDURE EndOfWord( VAR S    : ARRAY OF CHAR;
                         Start: CARDINAL;
                     VAR End  : CARDINAL );
VAR
    Length : CARDINAL;
    C      : CHAR;
BEGIN
    End := Start;
    Length := ORD(S[0]);
    C := S[Start];
    IF (Alphabetic(C)) THEN
        WHILE (End <= Length) AND (AlphaNumeric(S[End])) DO INC(End); END;
    ELSIF (NumberPart(C)) THEN
        WHILE (End <= Length) AND (NumberPart(S[End])) DO INC(End); END;
    ELSE
        WHILE (End <= Length) AND (S[End] = C) DO INC(End); END;
    END;
END EndOfWord;







PROCEDURE RemoveRestOfWord(  VAR S : ARRAY OF CHAR;
                                 i : CARDINAL       );
VAR
    j : CARDINAL;
BEGIN
    IF (i < 1) THEN RETURN; END;
    EndOfWord(S,i,j);
    Remove(S,i,j-i);
    WHILE (i <= ORD(S[0])) AND (S[i] = " ") DO
        Remove(S,i,1);
    END;
END RemoveRestOfWord;



PROCEDURE InsertBlap( VAR S : ARRAY OF CHAR;
                          i : CARDINAL );
VAR
    Blap : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(Blap,PlaceHolder,1);
    Insert(S,Blap,i);
END InsertBlap;


PROCEDURE ReplaceWordWithBlap( VAR S : ARRAY OF CHAR;
                                   i : CARDINAL       );
VAR
    Blap : ARRAY [0..1] OF CHAR;
BEGIN
    RemoveRestOfWord(S,i);
    Fill(Blap,PlaceHolder,1);
    Insert(S,Blap,i);
END ReplaceWordWithBlap;



    (* MatchWord -- Search S for Word beginning at position >= Start.
                    Word must match for at least MinLen chars.
                    If found, then (a) set At to the words position.
                    and (b) return TRUE. *)

PROCEDURE MatchWord( VAR S      : ARRAY OF CHAR;
                         Start  : CARDINAL;
                         MinLen : CARDINAL;
                         Word   : ARRAY OF CHAR;
                     VAR At     : CARDINAL   ) : BOOLEAN;
VAR
    S2 : ARRAY [0..99] OF CHAR;
    i,j,EoWord  : CARDINAL;
BEGIN
    IF (MinLen > ORD(Word[0])) THEN
        MinLen := ORD(Word[0]);
    END;
    SubStr(Word,S2,1,MinLen);

    WHILE (Start <= ORD(S[0]) ) DO

        At := Search(S,S2,Start);

        IF (At = 0) THEN
            RETURN FALSE;
        END;

        EndOfWord(S,At,EoWord);

            (* See if the whole word matches. *)

        IF (At = 1)
            OR ((At > 1) AND (NOT Alphabetic(S[At-1]))) THEN
            i := 1;
            j := At;
            LOOP
                IF (j >= EoWord) THEN RETURN TRUE;
                ELSIF (i > ORD(Word[0]))
                   OR (S[j] <> Word[i]) THEN EXIT;
                ELSE
                    INC(i);
                    INC(j);
                END;
            END;
        END;

        Start := EoWord;

    END;

    RETURN FALSE;

END MatchWord;




(* Match Phrase Word.

        Look through a phrase at ModuleNumber + Offset for the text
        that matches text in "LookIn".  Returns "WhereFound" and
        "WordNumber".  Returns TRUE iff found and FALSE if not.
*)

PROCEDURE MatchPhraseWord( Offset,
                           Start      : CARDINAL;
                       VAR LookIn     : ARRAY OF CHAR;
                       VAR WhereFound,
                           WordNum    : CARDINAL ) : BOOLEAN;
VAR
    LookingIn,
    Phrase      : ARRAY [0..255] OF CHAR;
    s1          : ARRAY [0..39] OF CHAR;
BEGIN
    Copy( LookIn, LookingIn );
    Upshift( LookingIn );
    GetMessage( ModuleNumber + Offset, Phrase );
    WordNum := 1;
    WordNumber( Phrase, WordNum, s1 );
    WHILE (s1[0] <> 0C) AND
          (NOT MatchWord(LookingIn, Start, ORD(s1[0]), s1, WhereFound)) DO
        INC( WordNum );
        WordNumber( Phrase, WordNum, s1 );
    END;
    RETURN (s1[0] <> 0C);
END MatchPhraseWord;






PROCEDURE MatchParallel( VAR S  : ARRAY OF CHAR;
                         VAR At : CARDINAL ) : BOOLEAN;
CONST
    ParallelPhrase = 3;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( ParallelPhrase, 1, S, At, WordNum )) THEN
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchParallel;






PROCEDURE MatchSequential( VAR S  : ARRAY OF CHAR;
                           VAR At : CARDINAL ) : BOOLEAN;
CONST
    SequentialPhrase = 2;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( SequentialPhrase, 1, S, At, WordNum )) THEN
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchSequential;





PROCEDURE MatchADurationUnit( VAR   S    : ARRAY OF CHAR;
                                i    : CARDINAL;
                          VAR   TU   : ADurationUnit;
                          VAR   At   : CARDINAL     ) :BOOLEAN;
CONST
    DurationUnitPhrase = 1;
    NumberOfUnits  = 6; (* Min Hr Dy Wk Mo Yr *)
VAR
    WordNum   : CARDINAL;
BEGIN
    IF (MatchPhraseWord( DurationUnitPhrase, i, S, At, WordNum )) THEN
        TU := VAL( ADurationUnit, ((WordNum - 1) MOD NumberOfUnits) );
        RETURN TRUE;
    END;

    RETURN FALSE;  (* Not found *)
END MatchADurationUnit;




(*
    Match Boolean

        Match on familiar Yes/No, True/False items.

        21-Feb-89 RSC
*)
PROCEDURE MatchBoolean(   VAR   S    : ARRAY OF CHAR;
                                i    : CARDINAL;
                          VAR   B    : BOOLEAN;
                          VAR   At   : CARDINAL     ) :BOOLEAN;
CONST
    BooleanPhrase = 5;
    NumberOfUnits = 2; (* Yes/No *)
VAR
    WordNum   : CARDINAL;
BEGIN
    IF (MatchPhraseWord( BooleanPhrase, i, S, At, WordNum )) THEN
        B := VAL( BOOLEAN, ((WordNum - 1) MOD NumberOfUnits) );
        RETURN TRUE;
    END;

    RETURN FALSE;  (* Not found *)

END MatchBoolean;





PROCEDURE MatchARealNumber( VAR S : ARRAY OF CHAR;
                                i : CARDINAL;
                            VAR At : CARDINAL;
                            VAR R : REAL  ) : BOOLEAN;
VAR
    j : CARDINAL;
    S2 : ARRAY [0..30] OF CHAR;
    OK : BOOLEAN;
BEGIN

        (* Find the first digit at position >= i. *)

    LOOP
        IF (i > ORD(S[0]) ) THEN
            RETURN FALSE;
        ELSIF (Numeric( S[i] ) ) THEN
            EXIT;
        ELSIF (S[i] = ".") AND (i < ORD(S[0])) AND (Numeric(S[i+1])) THEN
            EXIT;
        ELSE
            INC(i);
        END;
    END;

    At := i;

        (* Find the end of the number. *)

    EndOfWord(S,i,j);

    SubStr(S,S2,i,j-i);
    AmountToReal( S2, R, OK );

    RETURN OK;

END MatchARealNumber;






PROCEDURE MatchPrecedingRealNumber( VAR S : ARRAY OF CHAR;
                                        i : CARDINAL;
                                    VAR At : CARDINAL;
                                    VAR R : REAL  ) : BOOLEAN;
VAR
    j  : CARDINAL;
    OK : BOOLEAN;
    S2 : ARRAY [0..30] OF CHAR;
BEGIN
    IF (i = 0) THEN FatalError; END;

    j := i;
        (* Find the start of the preceding number. *)

    DEC(i);
    WHILE (S[i] = " ") AND (i > 1) DO DEC(i); END;
    WHILE (i > 1) AND (NumberPart(S[i])) AND (NumberPart(S[i-1])) DO DEC(i); END;

        (* If there is a preceding number, then we have found a good
           duration. *)

    IF (i >= 1) AND (NumberPart(S[i])) THEN
        At := i;
        SubStr(S,S2,i,j-i);
        AmountToReal( S2, R, OK );
        RETURN OK;
    ELSE
        RETURN FALSE;
    END;

END MatchPrecedingRealNumber;














PROCEDURE MatchAndRemoveAPercentage( VAR   S    : ARRAY OF CHAR;
                                           i    : CARDINAL;
                                     VAR   Percentage : REAL
                                     ) : BOOLEAN;
VAR
    UnitsAt : CARDINAL;
    QuantityAt : CARDINAL;
    S1         : ARRAY [0..1] OF CHAR;
BEGIN

    Fill(S1,"%",1);
    IF (NOT MatchWord(S,i,ORD(S1[0]),S1,UnitsAt)) THEN
        RETURN FALSE;
    END;

    IF (MatchPrecedingRealNumber(S,UnitsAt,QuantityAt,Percentage)) THEN
        Percentage := Percentage * 0.01;
        ReplaceWordWithBlap(S,UnitsAt);
        ReplaceWordWithBlap(S,QuantityAt);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END MatchAndRemoveAPercentage;







PROCEDURE MatchAndRemoveOneDuration( VAR   S    : ARRAY OF CHAR;
                                           i    : CARDINAL;
                                     VAR   H    : REAL; (* HOURS *)
                                     VAR   DurationUnit : ADurationUnit ) : BOOLEAN;
VAR
    UnitsAt    : CARDINAL;
    QuantityAt : CARDINAL;
    S1         : ARRAY [0..1] OF CHAR;
BEGIN
    DurationUnit := Days;

    IF (NOT MatchADurationUnit(S,i,DurationUnit,UnitsAt)) THEN
        RETURN FALSE;
    END;

    IF (MatchPrecedingRealNumber(S,UnitsAt,QuantityAt,H)) THEN
        IF (DurationUnit = Minutes) THEN
            H := H / 60.0;
        ELSIF (DurationUnit > Hours) THEN
            H := H
                 *
                 DurationToReal
                 (
                    UpScale( OneUnitOfDuration, DurationUnit ) DIV SMUPH
                 );
        END;
        ReplaceWordWithBlap(S,UnitsAt);           (* Remove the units word. *)
        ReplaceWordWithBlap(S,QuantityAt);        (* Remove the number. *)
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END MatchAndRemoveOneDuration;







    (* MatchAndRemoveADuration -- Match and remove a duration, either
                                  like "3 days" or "1 week, 2 days".
                                  *)


PROCEDURE MatchAndRemoveADuration( VAR   S    : ARRAY OF CHAR;
                                         i    : CARDINAL;
                                   VAR   Dur      : ADuration;
                                   VAR   DurationUnit : ADurationUnit ) : BOOLEAN;
VAR
    H, H2      : REAL;   (* Hours *)
    U,U2       : ADurationUnit;
    Matched    : BOOLEAN;
BEGIN
    H          := 0.0;
    U          := Months;
    Matched    := FALSE;

    WHILE (MatchAndRemoveOneDuration(S,i,H2,U2)) DO
        H := H + H2;
        IF (U2 < U) THEN                            (* Smallest unit. *)
            U := U2;
        END;
        Matched := TRUE;
    END;

    IF (Matched) THEN
        Dur      := RealTimeToDuration( WorkHoursToRealTime( H, U ), U );
        DurationUnit := U;
    END;

    RETURN Matched;

END MatchAndRemoveADuration;










PROCEDURE MatchAMonthName(  VAR S      : ARRAY OF CHAR;
                            VAR Month  : CARDINAL;
                            VAR At     : CARDINAL
                          ) : BOOLEAN;
VAR
    M         : CARDINAL;
    j         : CARDINAL;
    BestMonth : CARDINAL;
    BestAt    : CARDINAL;
    S2        : ARRAY [0..30] OF CHAR;
BEGIN
    BestAt := 9999;
    M := Jan;

    LOOP
        CtoMonth(M,S2);
        Upshift(S2);
            (* If the first three letters match, make sure that
               the whole word does. *)
        IF (MatchWord(S,1,3,S2,At) ) THEN
            IF (At < BestAt) THEN
                BestAt := At;
                BestMonth := M;
            END;
            IF (BestAt = 1) THEN
                EXIT;
            END;
        END;
        IF (M = Dec) THEN
            EXIT;
        END;
        INC(M)
    END;

    IF (BestAt < 9999) THEN
        Month := BestMonth;
        At    := BestAt;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END MatchAMonthName;



PROCEDURE ExtractWord( VAR S    : ARRAY OF CHAR;
                           At   : CARDINAL;
                       VAR Word : ARRAY OF CHAR );
VAR
    EoWord, Len : CARDINAL;
BEGIN
    EndOfWord(S,At,EoWord);
    Len := EoWord - At;
    IF (Len > HIGH(Word)) THEN
        Len := HIGH(Word);
    END;
    SubStr(S,Word,At,Len);
END ExtractWord;





    (* MatchDateAtStart -- Parse the string into a date.   If a date found,
                           Return TRUE.   Dates found only at start of string.
                           EndTime means "Parse as an EndTimeU"
    *)


PROCEDURE MatchDateAtStart (     TheString : ARRAY OF CHAR;
                             VAR TimeU     : ADate;
                             VAR Length    : CARDINAL;
                                 EndTime   : BOOLEAN    )
                           : BOOLEAN;
CONST
    TheYear    =  0;
    TheMonth   =  1;
    TheDay     =  2;
    TheHour    =  3;
    TheMinute  =  4;
    TheAm      =  5;
    AmPmPhrase = 10;
TYPE
    AnElementType = ( StartOfString, Space, Number, Word, Punctuation, Unknown );
VAR
    WordNum, LengthAtEndOfDate,
    At, N, OldHour,OriginalDay,
    OriginalMonth, OriginalYear,
    OriginalLength              : CARDINAL;
    TimeInfo                    : ATimeInfo;
    GotSet                      : BITSET;
    LastElementType             : AnElementType;
    s2                          : ARRAY [0..31] OF CHAR;
    ok                          : BOOLEAN;
    Valid                       : BOOLEAN;
    Fiscal                      : BOOLEAN;
    MonthFlag                   : BOOLEAN;   (* TheMonth IN GotSet, OR, it will be. *)


    PROCEDURE ProbableYear(ThisMonth,ThisYear,Month:CARDINAL):CARDINAL;
    CONST
        Window = 2;
    BEGIN
           (* If the month entered differs by more than ? from the
              current month, it is probably from a different year. *)
       IF (Month < ThisMonth) AND (ThisMonth - Month > Window) THEN
           RETURN ThisYear + 1;
       ELSIF (Month > ThisMonth) AND (Month - ThisMonth > 12-Window) THEN
           RETURN ThisYear - 1;
       ELSE
           RETURN ThisYear;
       END;
    END ProbableYear;




    PROCEDURE GetHourOrMinute():BOOLEAN;
    VAR
        i,k: CARDINAL;
    BEGIN
        i := 1;
        k := StoC(TheString,i);

        IF (TheHour IN GotSet) THEN
            IF (k <= 59) THEN
                TimeInfo.tiMinute := k;
                INCL(GotSet,TheMinute);
            ELSE
                RETURN FALSE;
            END;
        ELSIF (k <= 23) THEN
            TimeInfo.tiHour := k;
            INCL(GotSet,TheHour);
            TimeInfo.tiMinute := 0;
        ELSIF (i = 5) AND
              ((k MOD 100) <= 59) AND ((k DIV 100) <= 23) THEN
            TimeInfo.tiHour := k DIV 100;     (* Military Time *)
            TimeInfo.tiMinute := k MOD 100;
            INCL(GotSet,TheHour);
            INCL(GotSet,TheMinute);
            INCL(GotSet,TheAm);
        ELSE
            RETURN FALSE;
        END;

        Remove(TheString,1,i-1);   (* Remove what we matched. *)
        RETURN TRUE;
    END GetHourOrMinute;




    PROCEDURE GetYearMonthOrDay():BOOLEAN;
    VAR
        i,k : CARDINAL;
        LeadingZero : BOOLEAN;
        OK : BOOLEAN;
    BEGIN
        OK := FALSE;

        LeadingZero := (TheString[1] = "0");

        i := 1;
        k := StoC(TheString,i);

        IF (k = 0) THEN
            RETURN FALSE;
        ELSIF (i > 1) AND (TheString[i]=":") THEN
            RETURN FALSE;
        ELSIF (NOT MonthFlag) AND (k <= 12) THEN
            TimeInfo.tiMonth := k-1;
            IF (NOT (TheYear IN GotSet)) THEN
                TimeInfo.tiYear := ProbableYear
                                   (
                                        OriginalMonth,
                                        OriginalYear,
                                        TimeInfo.tiMonth
                                   );
            END;
            INCL(GotSet,TheMonth);
            MonthFlag := TRUE;
            IF (NOT (TheDay IN GotSet)) THEN
                TimeInfo.tiDay := 1;
            END;
        ELSIF (NOT (TheDay IN GotSet)) AND (k <= 31) THEN
            TimeInfo.tiDay := k;
            INCL(GotSet,TheDay);
        ELSIF (NOT (TheYear IN GotSet)) AND
              ((k >= 24) OR (LeadingZero))  THEN
            IF (k <  80) THEN
                INC(k,2000);
            ELSIF (k < 100) THEN
                INC(k,1900);
            END;
            IF (k < 1980) OR (k >= TimeTable.FirstYear+YearsOnFile) THEN
                RETURN FALSE;
            END;
            TimeInfo.tiYear := k;
            INCL(GotSet,TheYear);
        ELSE
            RETURN FALSE;
        END;

        Remove(TheString,1,i-1);   (* Remove what we matched. *)
        RETURN TRUE;
    END GetYearMonthOrDay;


    PROCEDURE RemoveIt;
    BEGIN
        Remove(TheString,1,1);     (* Remove the first character from the string. *)
    END RemoveIt;



    PROCEDURE MakeEndTime() : BOOLEAN;
    VAR
        DurationUnitsFound : ASetOfADurationUnit;
    BEGIN
        DurationUnitsFound := ASetOfADurationUnit{};
        IF (TheYear   IN GotSet) THEN INCL( DurationUnitsFound, Years   ); END;
        IF (TheMonth  IN GotSet) THEN INCL( DurationUnitsFound, Months  ); END;
        IF (TheDay    IN GotSet) THEN INCL( DurationUnitsFound, Days    ); END;
        IF (TheHour   IN GotSet) THEN INCL( DurationUnitsFound, Hours   ); END;
        IF (TheMinute IN GotSet) THEN INCL( DurationUnitsFound, Minutes ); END;

        RETURN PartialDateToDate(TimeInfo, DurationUnitsFound, FALSE, TimeU);
    END MakeEndTime;


BEGIN
    OriginalLength := ORD(TheString[0]);
    Valid := FALSE;
    MonthFlag := FALSE;
    GotSet := {};

    IF (TheString[0] = 0C) THEN
        RETURN FALSE;
    END;

    TimeUtoT(TimeU,TimeInfo);
    OriginalMonth := TimeInfo.tiMonth;
    OriginalYear  := TimeInfo.tiYear;
    OriginalDay   := TimeInfo.tiDay;

        (*  Find the first non-blank character. *)

    TrimFront(TheString);

        (* Is there going to be a month name found? *)

    IF (MatchAMonthName(TheString,TimeInfo.tiMonth,At)) AND
       (At <= 5) THEN
        MonthFlag := TRUE;
        TimeInfo.tiDay := 1;
    END;

    GetMessage(0410,s2);              (* "FY" *)
    IF (MatchWord(TheString, 1, LengthOf(s2), s2, At )) THEN
        Fiscal := TRUE;
        RemoveRestOfWord(TheString,At);
    END;

        (*  Get Year, Month, and Day. *)

    LastElementType := StartOfString;

    LOOP
        IF (TheString[0]=0C) OR
           (TheHour IN GotSet) OR
           ({TheYear,TheDay,TheMonth} <= GotSet) THEN
            EXIT;
        END;
        CASE TheString[1] OF
            "0".."9"  :
                        IF (NOT GetYearMonthOrDay()) THEN
                            EXIT;
                        END;
                        LastElementType := Number;
          | "A".."Z"  :
                            (* Contiguous month names are ok. *)
                        ExtractWord(TheString,1,s2);             (* Check only 1st word in string. *)
                                                                 (* AJL Dec 16, 1986 *)
                        IF (MatchAMonthName(s2,N,At))
                           AND (NOT (TheMonth IN GotSet))        (* AJL Dec 16, 1986 *)
                           AND (At = 1) THEN
                            TimeInfo.tiMonth := N;               (* AJL Dec. 16, 1986 *)
                            RemoveRestOfWord(TheString,1);
                            INCL(GotSet,TheMonth);
                            IF (NOT (TheYear IN GotSet)) THEN
                                TimeInfo.tiYear := ProbableYear
                                                   (
                                                        OriginalMonth,
                                                        OriginalYear,
                                                        TimeInfo.tiMonth
                                                   );
                            END;
                            IF (NOT (TheDay IN GotSet)) THEN
                                TimeInfo.tiDay := 1;
                            END;
                            MonthFlag := TRUE;
                            Valid := TRUE;
                            LastElementType := Word;
                        ELSE
                            LastElementType := Unknown;
                            EXIT;
                        END;

          | " " :
                        RemoveIt;

          | ",", ".", "/", "-" :
                        IF (LastElementType = Punctuation) THEN
                            RETURN FALSE;
                        END;
                        LastElementType := Punctuation;
                        RemoveIt;
          ELSE
                        EXIT;
        END;
    END;



    IF (({TheYear,TheMonth,TheDay} * GotSet) <> {}) THEN
        TimeInfo.tiHour := 0;
        TimeInfo.tiMinute := 0;
    END;

        (* All the rest of the program expects fiscal years.  If it
           is not already a fiscal year, make it so. *)

    IF (TheYear IN GotSet) AND (NOT Fiscal) THEN
        CalendarYearToFiscalYear(TimeInfo.tiMonth, TimeInfo.tiYear );
    END;

        (*  Get Hour and Minute *)


    LengthAtEndOfDate := ORD(TheString[0]);
    OldHour           := TimeInfo.tiHour;
    LOOP
        IF (TheString[0] = 0C)
          OR ({TheHour,TheMinute} <= GotSet) THEN
            EXIT;
        END;
        CASE TheString[1] OF
            "0".."9" :
                        IF (NOT GetHourOrMinute()) THEN
                            RETURN FALSE;
                        END;

          | ":"      :  IF NOT (TheHour IN GotSet) THEN
                            RETURN FALSE;
                        ELSE
                            Valid := TRUE;
                        END;
                        RemoveIt;
          | " "      :
                        RemoveIt;

          | ",", ".", "/", "-" :

                (* Well, here we have gotten ourselves into a bit of a jam.
                   We parsed the start of ANOTHER DATE FIELD as the TIME of
                   this date field.  We need to stop the scan and back up
                   over the prior field.
                *)
                        WHILE (ORD(TheString[0]) < LengthAtEndOfDate) DO
                            ConcatS( TheString, " " );
                        END;
                        EXCL( GotSet, TheHour );
                        TimeInfo.tiHour := OldHour;
                        EXIT;
          ELSE
                        EXIT;
        END;
    END;

    IF (MatchPhraseWord( AmPmPhrase, 1, TheString, At, WordNum )) THEN
        IF (((WordNum - 1) MOD 2) = 0) THEN (* AM *)
            IF (TimeInfo.tiHour = 12) THEN TimeInfo.tiHour := 0 END;
        ELSE                                   (* PM *)
            IF (TimeInfo.tiHour <= 11) THEN INC(TimeInfo.tiHour,12) END;
        END;
        INCL(GotSet,TheAm);
        RemoveRestOfWord(TheString,At);
    END;

    IF (TheAm IN GotSet) THEN
            (* 3pm etc. *)
        IF (GotSet  = {TheMonth,TheAm}) THEN
            TimeInfo.tiHour   := TimeInfo.tiMonth;
            TimeInfo.tiMonth  := OriginalMonth;
            TimeInfo.tiYear   := OriginalYear;  (* It may have been reset! *)
            TimeInfo.tiDay    := OriginalDay;   (* It was set to 1! *)
            GotSet := {TheHour,TheAm};
        END;
    ELSIF (TheHour IN GotSet) AND (TimeInfo.tiHour < 7) THEN
            (* If no Am/Pm specified, hours before 7 will be taken as
               pm.  *)
        INC(TimeInfo.tiHour,12);
    END;

        (* Check that we got some valid parts. *)

    IF ({TheMonth,TheYear} <= GotSet) THEN
        Valid := TRUE;
    ELSIF ({TheDay,TheMonth} <= GotSet) THEN
        Valid := TRUE;
    ELSIF ({TheHour,TheMinute} <= GotSet) THEN
        Valid := TRUE;
    ELSIF ({TheHour,TheAm} <= GotSet) THEN
        Valid := TRUE;
    END;

    IF (NOT Valid) THEN
        RETURN FALSE;
    END;

    IF (EndTime) THEN
        ok := MakeEndTime();
    ELSE
        ok := TtoTimeU(TimeInfo,TimeU);
    END;

    Length := OriginalLength - ORD(TheString[0]);

    RETURN ok;

END MatchDateAtStart;





PROCEDURE MatchADeadline( VAR S  : ARRAY OF CHAR;
                          VAR At : CARDINAL ) : BOOLEAN;
CONST
    DeadPhrase = 4;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( DeadPhrase, 1, S, At, WordNum )) THEN
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchADeadline;








PROCEDURE MatchAFixation( VAR S  : ARRAY OF CHAR;
                          VAR At : CARDINAL;
                          VAR Fixation : AFixType
                         ) : BOOLEAN;
CONST
    FixationPhrase = 11;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( FixationPhrase, 1, S, At, WordNum )) THEN
        Fixation := VAL( AFixType, (WordNum - 1) );
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchAFixation;







PROCEDURE MatchAStartStatus( VAR S           : ARRAY OF CHAR;
                             VAR At          : CARDINAL;
                             VAR StartStatus : AStartStatus
                         ) : BOOLEAN;
CONST
    SSPhrase = 12;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( SSPhrase, 1, S, At, WordNum )) THEN
        StartStatus := VAL( AStartStatus, ((WordNum - 1) MOD 3) );
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchAStartStatus;







PROCEDURE MatchAMilestone( VAR S  : ARRAY OF CHAR;
                           VAR At : CARDINAL
                          ) : BOOLEAN;
CONST
    MPhrase = 13;
VAR
    WordNum : CARDINAL;
BEGIN
    IF (MatchPhraseWord( MPhrase, 1, S, At, WordNum )) THEN
        RETURN TRUE;
    END;
    RETURN FALSE;  (* Not found *)
END MatchAMilestone;








PROCEDURE MatchADate(     S       : ARRAY OF CHAR;
                      VAR Date    : ADate;
                      VAR At      : CARDINAL;
                      VAR Length  : CARDINAL;
                          EndDate : BOOLEAN ) : BOOLEAN;
VAR
    j               : CARDINAL;
    OurDate         : ADate;
    Found           : BOOLEAN;
BEGIN
        (* Strategy: Repeatedly call MatchDateAtStart to see if the string S
                     starts with a date.  If it does, the date will
                     have been removed.  Otherwise, remove the first
                     word from the string and try again. *)

    At              := 1;
    Length          := 0;
    Found := FALSE;
    WHILE (S[0] > 0C) AND (NOT Found) DO
        j := ORD(S[0]);                      (* Current string length *)
        OurDate := Date;
        IF (MatchDateAtStart(S,OurDate,Length,EndDate)) THEN
            Date := OurDate;
            Found := TRUE;
        ELSE
            RemoveRestOfWord(S,1);           (* Remove first word  *)
            INC(At,j-ORD(S[0]));             (* At := new first word position. *)
        END;
    END;
    RETURN Found;
END MatchADate;




PROCEDURE CondensePlaceHolders( VAR S : ARRAY OF CHAR );
VAR
    i : CARDINAL;
BEGIN
    TrimFront(S);
    TrimRear(S);
    i := 1;
    WHILE (i <= ORD(S[0])) DO
        IF (S[i] = PlaceHolder) AND
            (  (i = 1) OR (S[i-1] = PlaceHolder) OR (i=ORD(S[0])) )
            THEN
            Remove(S,i,1);
        ELSE
            INC(i);
        END;
    END;
    TrimFront(S);
    TrimRear(S);
END CondensePlaceHolders;




BEGIN
END Matches.
