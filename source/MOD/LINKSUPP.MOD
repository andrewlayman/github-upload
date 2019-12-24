IMPLEMENTATION MODULE LinkSupport;

(*V7=TRACE*)


    (* LINK SUPPORT --

       Utility routines that are used in linking tasks and summarizing
       their resource assignments.

       MODIFICATION HISTORY

      17-Jan-92 AJL  - Pulled code from TLLNKTL2 and TLLNKSUM.
      29-Jan-92 AJL  - Changed rate parameters to REAL.
    27-Mar-92 TGS   NewPercent() wasn't checking to see if the percent
                    number returned was less than the limit passed in.
                    Also put in an optimization. Bug 5471.
     1-Apr-92 TGS   For "range check 3", pass more intelligible nums to
                    Notify(), i.e., instead of "70,000.0 is too big" say
                    "700.0 is too big.
                    Also, it looked to me that the immediately subsequent 
                    range checks were not being done right, so I changed.
                    Finally, we were showing _8_ decimal places for some
                    reason in the range error messages. Changed these to 2.
    *)


FROM Dialog                 IMPORT 
                                WarningBox, ADialogOption;

FROM FlexStor               IMPORT
        (* TYPE *)              AnExtStoragePreference;

FROM RealFormat             IMPORT FormatAsAmount, DefaultAmountFormat;

FROM LStrings               IMPORT SetString, LStringToTString, ConcatLS,
                                   Copy, ConcatS, SubStr, TrimRear, CtoS,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   LJust, Procustes, TrimFront;


FROM MsgFile                IMPORT  GetMessage, ConcatMessage;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnListIndex, AVaryingAssgnList,
    (* PROC *)                  CreateVaryingAssgnList,
                                GetVaryingAssgnListEntry,
                                CreateVaryingAssgnListEntry;


(*<TRACE
FROM FlexDisp IMPORT  HandleToString;
FROM RealFormat IMPORT
    (* VAR *)         DefaultAmountFormat, 
    (* PROC *)        FormatAsAmount;
FROM TimeFormat  IMPORT
    (* TYPE *)        AnEndDateStyle,
    (* VAR   *)       DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)       TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer   IMPORT  PrintString, EndTrace;
TRACE>*)


(*<TRACE
PROCEDURE FtoS( R : REAL; VAR S : ARRAY OF CHAR);
BEGIN
    FormatAsAmount(R, DefaultAmountFormat, S, 8, 0, 3, FALSE);
END FtoS;
TRACE>*)

CONST
     Zero                  = 0.0;
     Half                  = 0.5;
     OneHundred            = 100.0;
     FLOATMAXCARDINAL      = 65535.0;



     (* Convert4ByteReal : Convert a number from IEEE 4-byte to 
        8-byte format. *)


PROCEDURE Convert4ByteReal( VAR R4 : A4ByteReal ) : REAL;
TYPE 
      RealType8 = RECORD
        CASE INTEGER OF
           1 : word : ARRAY [0..3] OF CARDINAL;
        |  2 : bs   : ARRAY [0..3] OF BITSET;
        |  3 : num  : REAL;
        |  4 : long : ARRAY [0..1] OF LONGINT;
        END;(* case *)
      END;(* record *)
      RealType4 = RECORD
        CASE INTEGER OF
           1 : word : ARRAY [0..1] OF CARDINAL;
        |  2 : bs   : ARRAY [0..1] OF BITSET;
        |  3 : num  : A4ByteReal;
        END;(* case *)
      END;(* record *)
VAR
    temp4  : RealType4;
    temp8  : RealType8;
    sign   : BITSET;
    exp   : INTEGER;
    word,wordextra : CARDINAL;
    i     : CARDINAL;

BEGIN
      (* Convert from 4-byte.   The high-order word has 1 sign bit,
         8 exponent bits and 7 fraction bits. *)

  temp4.num := R4;                (* Load into recast structure. *)
  sign := temp4.bs[ 1 ] * {15};   (* Extract the sign bit. *)
      (* Exponent is bits 14..7, scaled by 127. *)
  exp := INTEGER( ( temp4.word[ 1 ] MOD 8000H ) DIV 80H );
      (* Clear destination to zeros. *)
  temp8.long[1] := 0L;
  temp8.long[0] := 0L;

      (* Move the fraction from the 4-byte structure to the 8-byte one.
         Because the exponent is 3 bits larger, all fraction bits must
         be shifted by 3. *)

      (* Shift bits by 3, since the exponent is three bits larger. *)
  word := temp4.word[ 0 ];
  wordextra := (word MOD 8) * 2000H;  (* Low 3 bits, shifted to high 3. *)
  word := word DIV 8;                 (* High 13 bits. *)
      (* Move these to destination. *)
  temp8.word[ 1 ] := wordextra;
  temp8.word[ 2 ] := word;

      (* Shift bits by 3, since the exponent is three bits larger. *)
  word := temp4.word[ 1 ] MOD 80H;    (* Fraction part of high word. *)
  wordextra := (word MOD 8) * 2000H;  (* Low 3 bits, shifted to high 3. *)
  word := word DIV 8;                 (* High 13 bits. *)
      (* Move these to destination. *)
  temp8.word[ 2 ] := temp8.word[ 2 ] + wordextra;
  temp8.word[ 3 ] := word;

      (* Move the exponent.   The high-order word has 1 sign bit,
         11 exponent bits and 4 fraction bits. *)

  IF (exp = 255) THEN  (* NAN or infinity *)
      exp := 2047;
  ELSE
      exp := exp + 1023 - 127;   (* Convert scaling from 127 to 1023. *)
  END;
      (* Shift left by 4 bits to clear the fraction bits. *)
  temp8.word[ 3 ] := temp8.word[ 3 ] + CARDINAL(exp * 16);

      (* Insert the sign. *)

  temp8.bs[ 3 ] := temp8.bs[ 3 ] + sign;

  RETURN temp8.num;

END Convert4ByteReal;



    (* Given two lists of varying assignments, merge them into one composite
       list.  The two lists are not empty (not NIL).

       Special knowlage: The End Date of one entry in the list is identical
                         to the Start Date of the next entry.
    *)
PROCEDURE MergeVaryingAssignmentLists( OV1, OV2 : AVaryingAssgnList
                                     ) : AVaryingAssgnList;
TYPE
    AV = RECORD
        RateInEffect    : REAL;
        NextRate        : REAL;
        List            : AVaryingAssgnList;
        Start           : ADate;
        N               : AVaryingAssgnListIndex;
        RatesAvailable  : BOOLEAN;
    END;

VAR
    NewList  : AVaryingAssgnList;
    NewStart : ADate;
    OldRate  : REAL;

    V1, V2   : AV;


    PROCEDURE Init( VAR V : AV; OV : AVaryingAssgnList );
    BEGIN
        WITH V DO
            N              := 0;
            NextRate       := Zero;
            RatesAvailable := TRUE;
            List := OV;
        END;
        Scratch( V );         (* Load the first entry. *)
    END Init;


        (* Get the next entry and put the prior entry's rate in the
           "RateInEffect" slot.

           The approach is that we have dates waiting to be used.
           As soon as a start date is used, scratch it, meaning
           put the start date's rate into effect and set up for the
           next date.

           When we get to the end, keep returning the same old date
           and put the last date's rate into effect.
        *)
    PROCEDURE Scratch( VAR V : AV );
    VAR
        StartDate,
        EndDate     : ADate;
        Rate        : REAL;
    BEGIN
        WITH V DO
            RateInEffect   := NextRate;
            RatesAvailable := GetVaryingAssgnListEntry( List, N+1, StartDate, EndDate, Rate );
            IF (RatesAvailable) THEN
                INC(N);
                Start        := StartDate;
                NextRate     := Rate;
            ELSE
                Start        := MAX(ADate); 
            END;

            (*<TRACE
            SetString(TraceS,"Scratch(");
            IF (ADR(V)=ADR(V1)) THEN SetString(TraceS2,"V1");
            ELSE   SetString(TraceS2,"V2");
            END; ConcatLS(TraceS,TraceS2);
            ConcatS(TraceS,"), N := ");
            FtoS(N,TraceS2); ConcatLS(TraceS,TraceS2);
            ConcatS(TraceS,";  RA := ");  
            IF (RatesAvailable) THEN SetString(TraceS2,"T") ELSE SetString(TraceS2,"F") END;
            ConcatLS(TraceS,TraceS2);  ConcatS(TraceS,";  Start := ");
            TimeUtoS(Start,TraceS2);  ConcatLS(TraceS,TraceS2);
            PrintString(TraceS);
            TRACE>*)

        END;
    END Scratch;


        (* Maybe create an entry in the new list, starting with
           NewStart date and containing the SUM of the two rates in
           effect from the lists being merged.

           Don't bother creating a list entry if the rates are the same.
        *)
    PROCEDURE MaybeCreateEntry( V1, V2 : AV;  NewStart : ADate );
    VAR
        Total,
        NewRate : REAL;
        ok      : BOOLEAN;
    BEGIN
        Total   := V1.RateInEffect + V2.RateInEffect;

        IF (Total > FLOATMAXCARDINAL) THEN
            NewRate := FLOATMAXCARDINAL;
        ELSE
            NewRate := Total;
        END;

            (* If the rate REALLY CHANGED, then add an entry.
            *)
        IF (NewRate <> OldRate) THEN

            OldRate := NewRate;

            IF (NewList  = AVaryingAssgnList(NIL)) THEN

                NewList := CreateVaryingAssgnList( NewRate,
                                                   NewStart,
                                                   ExtSlow );
            ELSE
                ok := CreateVaryingAssgnListEntry( NewList,
                                                   NewStart,
                                                   NewRate);
            END;
        END;

    END MaybeCreateEntry;


BEGIN
    (*<TRACE
    SetString(TraceS,"MergeVaryingAssignmentLists, ");
    HandleToString(OV1,TraceS2); ConcatLS(TraceS,TraceS2);
    ConcatS(TraceS," & "); HandleToString(OV2,TraceS2); ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)

    NewList := AVaryingAssgnList(NIL);
    OldRate := Zero;

        (* Initialize the structures. *)
    Init(V1, OV1);
    Init(V2, OV2);

        (*
        
        Background:

            Each list says something like:

                "Starting Monday,   I use Roger 30%.
                 Starting Thursday, I use Roger 100%."

            Suppose Roger worked on two tasks this week.

                Monday    he started working 30% on TASK A.
                Wednesday he started working 70% on TASK B.
                Thursday  he finishes both A and B and works on C at 100%.

            The merged profile should look like this:

                Monday through Tuesday, 30%.
                Wednesday,              100% (30% + 70%)
                Thursday,               100% (stop A&B, go onto C.

            Except that we don't want duplicate entries with the same
                amount, so skip the second entry for 100%.
        
        
        Plan of attack:

            While there are entries in either list,

                - Take the earliest date as the start date of the
                  entry to be created.

                - Scratch the earliest date.  Note that this has the
                  by-product of fetching the NEXT date, so get the
                  date we want BEFORE scratching the date.

                - Maybe create a new entry with the chosen start date and
                  the sum of the rates in effect.  I say maybe, because
                  if the rate of use is the same as it was, don't bother.
        *)

    WHILE (V1.RatesAvailable OR V2.RatesAvailable) DO


        IF (V1.Start < V2.Start) THEN
            NewStart := V1.Start;
            Scratch(V1);

        ELSIF (V1.Start > V2.Start) THEN
            NewStart := V2.Start;
            Scratch(V2);

        ELSE (* They are EQUAL - Scratch them BOTH. *)

            NewStart := V1.Start;
            Scratch(V1);
            Scratch(V2);
        END;

        MaybeCreateEntry( V1, V2, NewStart );
    END;

    RETURN NewList;

END MergeVaryingAssignmentLists;










  (* In version TLWin, resource rates are floating point and were in
     wild ranges.
     For TL5 DOS, we need rates to be more rigidly defined as
     n people at m percent, where n and m are both cardinals.

     This routine taken from TLITL2.MOD, the TL2 importer.

     Cases:
         Resource record:
                Fraction < 0.01  (version 2 allowed zeroes and negatives!)
                Fraction > (9999 @ 999%)

         Assignment record:
                Fraction < 0.00  (version 2 allowed negatives!)
                Fraction > 655.35 (vers 2 allowed up to 9,999,999,999.00)
                Fraction > <Resource's maximum>

                Note that the resources maximum CAN BE > 655.35!

     This procedure tries to do a good job picking the number and percent.

     Preconditions  - Name       is the prefix for the message. (rsrc name)
                      Fraction   is the version 2 rate.
                      UpperLimit is the max possible for this rsrc/assignment.
                      LowerLimit is the min possible for this rsrc/assignment.
                      NLimit     is the desired upper bound for the number field.
                      PLimit     is the desired upper bound for the percent field.
                      Number     is the resulting n people.
                      Percent    is the resulting percentage.
  *)
PROCEDURE NewPercent( VAR TaskName,
                          ResourceName : ARRAY OF CHAR;
                          Fraction,
                          UpperLimit,
                          LowerLimit   : REAL;
                          NLimit,
                          PLimit       : CARDINAL;
                      VAR Number,
                          Percent      : CARDINAL );
CONST
    GuestModuleNumber = 12400;   (* Source for error messages. *)
VAR
    R,
    BestDiff,
    Diff,
    BigFraction,
    FPLimit,
    FNLimit  : REAL;
    LoopLimit,
    Result,
    LoopBase,
    Bestn,
    Bestp,
    i, j     : CARDINAL;

    PROCEDURE Notify( TooBigNumber,
                      ReasonableNumber  : REAL;
                      AdditionalMessage : CARDINAL
                    );
    CONST
        LineBreak = "ü";  (* Our secret line break char. *)
    VAR
        s : ARRAY [0..255] OF CHAR;
        s1: ARRAY [0..39]  OF CHAR;
    BEGIN
        s[0] := 0C;
        IF (TaskName[0] <> 0C) THEN
            ConcatMessage(s, GuestModuleNumber+52); (* "Task:" *)
            ConcatLS(     s, TaskName );
            ConcatS(      s, LineBreak );
        END;
        IF (ResourceName[0] <> 0C) THEN
            ConcatMessage(s, GuestModuleNumber+53); (* "Resource:" *)
            ConcatLS(     s, ResourceName );
            ConcatS(      s, LineBreak );
        END;

        ConcatMessage(s, GuestModuleNumber+54); (* "The quantity of ~" *)
        FormatAsAmount( TooBigNumber,
                        DefaultAmountFormat,
                        s1, 39, 1, 2, FALSE );
        TrimFront( s1 );
        TrimRear(  s1 );
        ConcatLS( s, s1 );

        ConcatMessage(s, GuestModuleNumber+AdditionalMessage); (*    "~ is too large, and will be changed to ~" *)
        FormatAsAmount( ReasonableNumber,                 (* or "~ will be accepted, but is larger than its maximum quantity of ~" *)
                        DefaultAmountFormat,              (* or "~ is too small, and will be changed to ~" *)
                        s1, 39, 1, 2, FALSE );
        TrimFront( s1 );
        TrimRear(  s1 );
        ConcatLS( s, s1 );
        GetMessage( GuestModuleNumber+58, s1 ); (* "Out of Range" *)
        WarningBox( s, s1, NoHelp );
    END Notify;

BEGIN
    (* Error check 1: Is the number too big? *)

    IF (Fraction > UpperLimit) THEN
        Notify( Fraction, UpperLimit, 55 ); (* too big? *)
        Fraction := UpperLimit;
    END;

    (* Error check 2: Is the number too small? *)

    IF (Fraction < LowerLimit) THEN
        Notify( Fraction, LowerLimit, 56 ); (* too small? *)
        Fraction := LowerLimit;
    END;

    (* Is the number zero?  If it is, and we passed the above test,
       return 0 @ 0%.  Less than 1 @ 1% is the same as zero.
    *)
    IF (Fraction < 0.01) THEN
        Percent := 1;
        Number  := 0;
        RETURN;
    END;

    (* Error check 3: Is the number outside the DESIRED limits?
                      Note that, through a cruel twist of fate,
                      (PLimit * NLimit) can be bigger than UpperLimit

                      Numbers outside desired ranges are retained, but
                      we warn them anyway.  We also reset the limits
                      such that they will work for later calcs.  We
                      first try the assignment limits, then the resource
                      limits.  As we already got past the limit check,
                      the number is within the proper range.
    *)

    FPLimit     := FLOAT(PLimit);
    FNLimit     := FLOAT(NLimit);
    R           := (FPLimit * FNLimit)/OneHundred; (* 1-Apr-92 TGS *)
    BigFraction := (Fraction * OneHundred);

    IF (Fraction > R) THEN
        (* If it's too big, return the largest possible *)
        IF (PLimit > MAX(CARDINAL) DIV NLimit) THEN
            Number  := NLimit;
            Percent := MAX(CARDINAL) DIV NLimit;
            R       := FLOAT(Number * Percent)/OneHundred;
        ELSE
            Number  := NLimit;
            Percent := PLimit;
        END;
        Notify( Fraction, R, 55 ); (* out of desired range. *)
        RETURN;
        (* 
        IF  (NLimit < 250) AND
           ((BigFraction / 250.0) <= 650.0 ) THEN (* Assignment limits? *)
            NLimit := 250;
            PLimit := 650;
        ELSE
            NLimit := 999;   (* Resource limits. *)
            PLimit := 9999;
        END;
        *)
    END;

    (* Ok, now for the computation of the new number .... *)

    (* If the number is large, don't worry about neat fittings.
       Round the number a little...
       Choose the cutoff such that after this, TRUNC(BigFraction) will be
       within CARDINAL range!
    *)
    IF (BigFraction > 65000.0) THEN  (* Cutoff at 650 people *)
        IF  (PLimit   >= 100) AND
            (Fraction <= FNLimit) THEN
            Percent := 100;
            Number  := TRUNC( Fraction + Half );
        ELSE
            Percent := PLimit;
            Number  := TRUNC( (BigFraction + (FPLimit / 2.0)) / FPLimit );
        END;
        RETURN;
    END;

    (* If the number divides evenly, return that.  Go for 100% first. *)

    j := TRUNC( Fraction );
    IF (PLimit >= 100) AND (j <= NLimit) AND
       (FLOAT(j) = Fraction) THEN
        Percent := 100;
        Number  := j;
        RETURN;
    END;

    R := BigFraction / FPLimit;
    j := TRUNC(R);
    IF (FLOAT(j) = R) AND (j <= NLimit) THEN
        Percent := PLimit;
        Number  := j;
        RETURN;
    END;

    (* Otherwise, Find the best fit. *)

    (* 27-Mar-92 TGS: 
       If we can express it as "1 @ x%", do so and be done with it *)

    IF (BigFraction <= FPLimit) THEN
        Number  := 1;
        Percent := TRUNC(BigFraction + 0.5);
        RETURN;
    END;


    Bestn    := 1;
    Bestp    := 1;
    BestDiff := 9999.0;

    (* Loop through the possible percentages and numbers.

       We try all possible percentages and numbers and pick the one with
       the best fit, so, for example, 330 could be 3 @ 110%, 2 @ 165%, etc.
       As we want to limit the number of tries, we know that we should try
       numbers no smaller than would be acceptable (within PLimit AND NLimit)
       and no bigger than would cause redundancy (SQRT(BigFraction), or the
       MAX(NLimit,PLimit)).
    *)

    (* Find the loop base.  Take MAX(number, percent) and divide it into
       the big fraction.  This is the SMALLEST either number could be.
    *)
    R         := FPLimit;
    LoopLimit := PLimit;
    IF (NLimit > PLimit) THEN  (* Remember FNLimit == NLimit, FPLimit == PLimit *)
        R         := FNLimit;
        LoopLimit := NLimit;
    END;

    LoopBase  := TRUNC(BigFraction / R); (* Smallest sensible number *)
    IF (LoopBase = 0) THEN
        LoopBase := 1;      (* Can't allow 0 @ 0% here.  Zero handled above. *)
    END;
    IF (LoopLimit < LoopBase) THEN
        LoopLimit := LoopBase; (* Must loop at least once. *)
    END;

    (* Loop from loop base to the limit calculated above, or the
       square root of the big fraction, whichever is first.  I use
       a cheap method of determining when I have exceeded the square
       root by comparing the loop value with (BigFraction/i).

       We know that all numbers generated here are valid either as the
       percentage or as the number (although maybe not both), so look for
       the least difference AND THEN figure out which is which, favoring
       larger percentages.
    *)
    i      := LoopBase;
    Result := MAX(CARDINAL); (* A Cheap way of finding SQRT *)
    WHILE (i <= LoopLimit) AND (Result >= i) DO
        Result  := TRUNC( BigFraction / FLOAT(i) );
        Diff    := ABS( FLOAT(Result * i) - BigFraction );
        IF (Diff < BestDiff)  AND
           (Result <= PLimit) THEN  (* 27-Mar-92 TGS *)
            BestDiff := Diff;
            Bestn    := i;
            Bestp    := Result;
            IF (Diff = Zero) THEN
                Result := 0; (* TERMINATE THE LOOP CHEAPLY *)
            END;
        END;
        INC(i);
    END;

    (* We have the best possible fit.  Favor the percentages, so if the
       percent is smaller but can take the larger of the two numbers,
       give it to em.
    *)
    IF (Bestn > Bestp) AND (Bestp < NLimit) THEN
        j     := Bestn;
        Bestn := Bestp;
        Bestp := j;
    END;
    Number  := Bestn;
    Percent := Bestp;

END NewPercent;







END LinkSupport.

