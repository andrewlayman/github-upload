IMPLEMENTATION MODULE VaryAssgnment;

(*V2=DEBUG*)
(*V1=PRINT WITH debugging printouts. *)

(* Modification History

    ?-???-90 AJL  First version
    8-Jun-90 RSC  Changed the "NotYetImplemented"s to real code.
    4-Jul-90 AJL  Changed NumberOfRatesInList to return Records-1.
    6-Jul-90 AJL  Added CheckVaryAssgnListValid.
   18-Aug-90 AJL  Add new proc.
                  Avoid duplicated entries.
    6-Sep-90 RSC  Modify saving and loading to save and load as a
                  DateList (so we can use BigTimes)
    3-Oct-90 RSC  Ajust the LocateDate routine to look at the last record
                  too.
    4-Oct-90 RSC  Ajust the LocateDate routine to look starting with the
                  first real record (not FirstReal+1) and to back off by
                  (FirstReal), not by (FirstReal+1).
    9-Oct-90 AJL  Added LocateRateAtDate.
   27-Nov-90 AJL  Added checks after SetExtSize.
    2-Apr-91 AJL -Converted TRACE to PRINT using ResTrace.
   27-Apr-91 AJL -Correct loop conditions in SetNewPoint and 
                  CreateVaryingAssgnListRange.
   26-Jun-91 AJL -Rearranged the locking orders.  Don't always 
                  shrink the arrays when removing an element.
   27-Jun-91 AJL -If there is a zero rate at the beginning of the
                  list, then in CreateVaryingAssgnListRange we can
                  remove it.
   22-Jul-91 AJL -If we cannot create a varying assignment list, display
                  an error phrase.
   29-Jan-92 LAA -The Rate parameters have been changed to REAL's, so we
                  can fix rounding problems which result from only allowing
                  whole numbers for (NumberAt * Percent).  A Rate MUST be
                  in the range 0.0 to 65535.0.
    2-Mar-92 AJL -A defect in CreateVaryingAssgnListRange caused the rate
                  to be set incorrectly for the following interval when
                  the end date parameter matched the end of an existing 
                  interval.
    4-Mar-92 LAA -In RealFromRate, I had incorrectly added two LongInts.
                  This produced an arithmetic overflow if the incoming
                  if the incoming Rate was large.  Solution is to convert
                  the Rate to a REAL first, then add the RealRateOffset.
*)

FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime;

FROM DateLists  IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      CreateDateListEntry, DisposeDateList,
                    GetDateListEntry, StoreDateList, LoadDateList,
                    NumberOfDatesInList;

FROM Dialog     IMPORT 
    (* PROC *)      FatalError, ErrorPhrase;

IMPORT Filing;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
                    AnExtStatus,
    (* PROC *)      CreateExtObject, GetExtSize, NumberOfElements,
                    SetExtData, DiscardExtObject, ReleaseObject,
                    CreateExtObjectWithSize, LockObject, CopyExtObject,
                    LockObjectArray, SetExtSize, ArraySize,
                    GetExtStatus, ReleaseUnchangedObject, HandleIsValid;

FROM LongConvert IMPORT
    (* PROC *)      LongToReal, RealToLong;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS,
    (* PROC *)      TSIZE, SIZE;

FROM Timei      IMPORT
    (* CONST *)     MinDate, MaxDate,
    (* TYPE *)      ADate, ADuration;

FROM TimeXlate  IMPORT
    (* PROC *)      CalendarTimeToBigTime, BigTimeToCalendarTime;


(*<PRINT
FROM FlexDisp IMPORT HandleToString;
FROM LStrings IMPORT SetString, ConcatS, ConcatLS, CtoS;
FROM LongConvert  IMPORT LongToString;
FROM RealFormat   IMPORT FormatAsAmount, DefaultAmountFormat, RealToLStrings;
FROM ResTrace    IMPORT
                        NoteString, PrintAString;
FROM TimeFormat   IMPORT TimeUtoS;     
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle;
PRINT>*)



(* ----------------------------------------------------------------------

   Notes on implementation:

   This module divides the  range [0..MaxDate) into a series of intervals of
   positive length, and records a rate that is in effect for each interval.

   The implementation stores this as the starting points for each interval, 
   but does not record the dates 0 or MaxDate, instead just storing the 
   dates in between.

   When an VaryingAssgnList is created, it starts out as having a rate of
   zero in the entire range [0..MaxDate).

   The array in which we store the dates and the rates can have some error-
   checking information at the start.  For this reason, the first entry in
   the array that actually contains a date is identified by "FirstReal"
   (though this offset is hidden from our clients).

   In addition, to save speed of changing the record size, we sometimes
   allocate more room in the array than we have currently used.  Some
   entries at the end of the physical array are not used.  The end of the
   used portion of the array is given by ORD(Entry[1].Rate).

   Assuming that FirstReal is 2, an array would look like

         +----------------+----------------+
    2 :  |  Date 1        |   Rate 1       |
         +----------------+----------------+
    3 :  |  Date 2        |   Rate 2       |
         +----------------+----------------+
    4 :  |  Date 3        |   Rate 3       |
         +----------------+----------------+
         :                :                :
         :                :                :
         +----------------+----------------+
    N :  |  Date N-1       |   Rate N-1    |
         +----------------+----------------+

         There is no entry for day 0 unless the user creates one in
         order to get a rate > 0 at day 0.

         There is no entry for day MaxDate.

  ---------------------------------------------------------------- *)





TYPE 
    AVaryingAssgnListEntry = RECORD
                              StartDate : ADate;
                              Rate      : LONGINT
                          END;

    AVaryingAssgnListArray = ARRAY [1..MaxIntervals] OF AVaryingAssgnListEntry;

    AVaryingAssgnListArrayPointer = POINTER TO AVaryingAssgnListArray;



CONST
    Zero    = 0.0;
    LongRateOffset  = 2147483647L;
    RealRateOffset  = 2147483647.0;
    SixtyFourKReal  = 65536.0;
    Tag     = 0ABABH;
    FirstReal = 2;
    Quantum   = 4;   (* Extra array allocation units. *)
    ModuleNumber = 30500;



    (*<PRINT
VAR
    S, S2 : ARRAY [0..150] OF CHAR;
    S3    : ARRAY [0..5] OF CHAR;
    PRINT>*)


    (*<PRINT

PROCEDURE RateToS(     Rate                 : LONGINT;
                   VAR S                    : ARRAY OF CHAR );

VAR
    S2                      : ARRAY [0..5] OF CHAR;

BEGIN                       (* RateToS *)

    RealToLStrings( RealFromRate( Rate ), 0, 5, S, S2 );
    ConcatS( S, "." );
    ConcatLS( S, S2 );

END RateToS;

    PRINT>*)



PROCEDURE CheckRealRate(     Rate           : REAL );

BEGIN                       (* CheckRealRate *)

    IF ((Rate < MinVaryAssgnListRate) OR (Rate > MaxVaryAssgnListRate)) THEN
        FatalError();
    END;

END CheckRealRate;


    (*  RealFromRate --
        Convert the rate back into a real number in the range 0.0 to
        65535.0.  This is the reverse of RateFromReal.
    *)

PROCEDURE RealFromRate(     Rate            : LONGINT ) : REAL;

BEGIN                       (* RealFromRate *)

    RETURN ((LongToReal(Rate) + RealRateOffset) / SixtyFourKReal );  (* 04-Mar-92 *)

END RealFromRate;


    (*  RateFromReal --
        Convert a real number in the range 0.0 to 65535.0 into a LONGINT
        such that maximum precision is preserved.  For example, an input
        value of 0.0 will be stored as MINUS LongRateOffset and 65535.0
        will end up as POSITIVE LongRateOffset - 65536.
    *)

PROCEDURE RateFromReal(     Real            : REAL ) : LONGINT;

BEGIN                       (* RateFromReal *)

    RETURN RealToLong(Real * SixtyFourKReal - RealRateOffset);

END RateFromReal;




PROCEDURE XCheckAssgnListValid ( VaryingAssgnList : AVaryingAssgnList);
VAR
    Entries       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
BEGIN
    IF (VaryingAssgnList <> AnExtHandle(NIL)) THEN
        Entries := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
        IF (Entries < FirstReal) OR (VaryingAssgnListArray^[1].StartDate <> Tag) THEN
            ErrorPhrase(ModuleNumber+1);
        END;
        ReleaseUnchangedObject( VaryingAssgnList );
    END;
END XCheckAssgnListValid;


    (*---------------------------------------------------------------

    CreateVaryingAssgnList 

    Purpose : Creates a VaryingAssgnList.

    Inputs:   InitialRate : Starting point for rates.
                            From 0.0 to 65535.0

    Outputs:  RETURNS : AVaryingAssgnList;

    Preconditions : None.

    Postconditions : The created rate list has a single interval, number 1,
                     which is the half open interval [StartDate..ThruDate),
                     and is initialized to the passed InitialRate.

                     ThruDate is assumed to be MaxDate, or the end of
                     the calendar.

    ------------------------------------------------------------------ *)

PROCEDURE CreateVaryingAssgnList( InitialRate : REAL;
                                  PStartDate  : ADate;
                                  Speed  : AnExtStoragePreference
                                  ) : AVaryingAssgnList;
VAR
    VaryingAssgnList                : AVaryingAssgnList;
    VaryingAssgnListArrayPointer    : AVaryingAssgnListArrayPointer;
    Size                            : CARDINAL;
BEGIN

    CheckRealRate( InitialRate );

        (* Allocate an array with enough room for more entries that 
           we will currently use.  This provides room for growth before
           we have to change the allocated size. *)

    Size := ArraySize(TSIZE(AVaryingAssgnListEntry), FirstReal+Quantum );
    

    IF (CreateExtObjectWithSize( VaryingAssgnList, Speed, Size )) AND
        (LockObject( VaryingAssgnList, VaryingAssgnListArrayPointer ) = Size)  THEN
       (*$O-*)
        WITH VaryingAssgnListArrayPointer^[1] DO
            StartDate := Tag;
            Rate      := VAL(LONGINT,FirstReal);    (* Index of last item in the list. *)
        END;

        WITH VaryingAssgnListArrayPointer^[FirstReal] DO
            StartDate := PStartDate;
            Rate      := RateFromReal(InitialRate);
        END;
       (*$O=*)
        ReleaseObject( VaryingAssgnList );     (*<KILL*)  VaryingAssgnListArrayPointer := NIL; (*KILL>*)
    ELSE
        ErrorPhrase(ModuleNumber+00);
        VaryingAssgnList := AVaryingAssgnList(NIL);
    END;

       (*<PRINT
    SetString(S,"V: Create varying assignment list "); HandleToString(VaryingAssgnList,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

    RETURN VaryingAssgnList;

END CreateVaryingAssgnList;



    (*---------------------------------------------------------------

    DisposeVaryingAssgnList 

    Purpose : Discards a VaryingAssgnList, deallocating any storage used.

    Inputs:   VaryingAssgnList : AVaryingAssgnList.

    Outputs:  VaryingAssgnList : An invalid VaryingAssgnList;

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.

    Postconditions : The VaryingAssgnList is no longer valid.

    ------------------------------------------------------------------ *)

PROCEDURE DisposeVaryingAssgnList(VAR VaryingAssgnList : AVaryingAssgnList);
BEGIN

       (*<PRINT
    SetString(S,"V: Dispose varying assignment list "); HandleToString(VaryingAssgnList,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    DiscardExtObject( VaryingAssgnList );

END DisposeVaryingAssgnList;






    (*---------------------------------------------------------------

    CopyVaryingAssgnList 

    Purpose : Copies the contents of one rate list to another. 

    Inputs:   Source : AVaryingAssgnList.

    Outputs:  Target : AVaryingAssgnList;

    Preconditions : Source was created by CreateVaryingAssgnList
                    and not disposed.

    Postconditions : Source is unchanged and Target = Source.

    ------------------------------------------------------------------ *)

(*$O-*)   (* Turn off optimizer because Source could be an alias of Target. *)

PROCEDURE CopyVaryingAssgnList( VAR Target : AVaryingAssgnList;
                                    Source : AVaryingAssgnList;
                                    Speed  : AnExtStoragePreference );
BEGIN
       (*<PRINT
    SetString(S,"V: Copy varying assignment list "); HandleToString(Source,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)
    (*<DEBUG CheckAssgnListValid(Source); DEBUG>*)


    IF (Source = AVaryingAssgnList(NIL)) OR
       (NOT CopyExtObject( Source, Speed, Target )) THEN
        Target := AVaryingAssgnList(NIL);
        (*<PRINT
    ELSE
        IF NOT (HandleIsValid(Source) AND HandleIsValid(Target) AND
               (VaryingAssgnListsAreEqual(Source,Target)) AND 
               (Source <> Target)  ) THEN
            SetString(S,"SERIOUS ERROR in V: Copy varying assignment list ");
            PrintAString(S);
            FatalError();
        END;
        PRINT>*)
    END;

       (*<PRINT
    ConcatS(S," to "); HandleToString(Target,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)


END CopyVaryingAssgnList;
(*$O=*)




    (*---------------------------------------------------------------

    VaryingAssgnListsAreEqual 

    Purpose : Determines whether two ratelists are equivalent.

    Inputs:   A, B : AVaryingAssgnList.

    Outputs:  TRUE iff each component of A is equal to the corresponding
              component of B.

    Preconditions : A and B were created by CreateVaryingAssgnList
                    and not disposed.

    Postconditions : A and B are unaffected.

    ------------------------------------------------------------------ *)


PROCEDURE VaryingAssgnListsAreEqual( A, B  : AVaryingAssgnList ) : BOOLEAN;
VAR
    i,
    RecordsA,
    RecordsB       : CARDINAL;
    VaryingAssgnListArrayA,
    VaryingAssgnListArrayB : AVaryingAssgnListArrayPointer;
    Equal          : BOOLEAN;


    PROCEDURE Eq( VAR A, B : AVaryingAssgnListEntry ) : BOOLEAN;
    BEGIN
        RETURN (A.Rate      = B.Rate          ) AND
               (A.StartDate = B.StartDate);
    END Eq;


BEGIN
    (* FatalError(); *)
    (*---- I don't think anyone uses this procedure *)
    (*<DEBUG CheckAssgnListValid(A); DEBUG>*)
    (*<DEBUG CheckAssgnListValid(B); DEBUG>*)

    RecordsA := LockObjectArray( A, VaryingAssgnListArrayA, TSIZE(AVaryingAssgnListEntry) );
    IF (RecordsA > 0) THEN
        RecordsA := VAL(CARDINAL,VaryingAssgnListArrayA^[1].Rate);   (* First entry has number used. *)
    END;
    RecordsB := LockObjectArray( B, VaryingAssgnListArrayB, TSIZE(AVaryingAssgnListEntry) );
    IF (RecordsB > 0) THEN
        RecordsB := VAL(CARDINAL,VaryingAssgnListArrayB^[1].Rate);   (* First entry has number used. *)
    END;


    Equal := (RecordsA = RecordsB);
    
    (*$O-*)
    i := FirstReal;
    WHILE (Equal) AND (i <= RecordsA) DO
        Equal := Eq(VaryingAssgnListArrayA^[i], VaryingAssgnListArrayB^[i]);
        INC(i);
    END;
    (*$O-*)

    ReleaseUnchangedObject( A );
    ReleaseUnchangedObject( B );

    RETURN Equal;
    (*----------*)

END VaryingAssgnListsAreEqual;




    (*---------------------------------------------------------------

    GetVaryingAssgnListEntry 

    Purpose : Returns one of the many intervals of time during a rate list,
              or indicates that no such interval exists.  Which interval
              is given by N.

    Inputs:   
              VaryingAssgnList    : AVaryingAssgnList;
              N           : The interval number.

    Outputs:  
              StartDate   : The date of the beginning of this period.
              ThruDate    : The smallest date > StartDate that is not
                            in this period.  I.E. the beginning (first 
                            moment) of the next period.     
              Rate        : The rate in effect during this period.
                            From 0.0 to 65535.0
	      RETURNS     : TRUE if this is a defined interval.  Else
                            returns FALSE.  Note: if period n is not 
                            defined, then periods n+i are undefined, for 
                            all i >= 0.

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.
    ------------------------------------------------------------------ *)

PROCEDURE GetVaryingAssgnListEntry(     VaryingAssgnList : AVaryingAssgnList;
                                        N        : AVaryingAssgnListIndex;
                                    VAR Start,
                                        Thru     : ADate;
                                    VAR RateIs   : REAL
                                   ) : BOOLEAN;
VAR
    Records       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
    ok            : BOOLEAN;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

       (*<PRINT
    SetString(S,"V: GetVaryingAssgnListEntry("); CtoS(N,S2);
    ConcatLS(S,S2); ConcatS(S,") which is entry number ");
    CtoS(N+FirstReal-1,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

    ok := (N > 0) AND (N <= MaxIntervals);

    INC(N,FirstReal-1);  (* Skip the first entry, which contains only the Tag. *)


    IF (ok) THEN
        Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
        IF (Records > 0) THEN
            Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
        END;

        (*<PRINT
            DisplayArray(VaryingAssgnListArray,Records);
        PRINT>*)

        IF (N > Records) THEN
            ok := FALSE;
        ELSE
            WITH VaryingAssgnListArray^[N] DO
                RateIs      := RealFromRate(Rate);
                Start       := StartDate;
            END;
            IF (N < Records) THEN
                Thru  := VaryingAssgnListArray^[N+1].StartDate;
            ELSE
                Thru  := MaxDate;
            END;
        END;

        ReleaseUnchangedObject( VaryingAssgnList );            (*<KILL*)  VaryingAssgnListArray := NIL; (*KILL>*)
    END;

    RETURN ok;

END GetVaryingAssgnListEntry;




PROCEDURE RemoveDuplicates( VAR VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
                            VAR Records : CARDINAL );
VAR
    i,
    Index      : CARDINAL;
BEGIN
       (*<PRINT
    SetString(S,"V: RemoveDuplicates, Records = ");  CtoS(Records,S2); ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

       (* If two adjacent entries have the same rate, and the second is not 
           the sentinel final record, the second is redundant. *) 
    Index := FirstReal+1;
    WHILE (Index <= Records) DO             (* Records to examine.  *)
        IF (VaryingAssgnListArray^[Index-1].Rate = VaryingAssgnListArray^[Index].Rate) THEN
               (*<PRINT
            SetString(S,"V: Remove, Index = ");  CtoS(Index,S2); ConcatLS(S,S2);
            PrintAString(S);
               PRINT>*)

            FOR i := Index TO Records-1 DO
                VaryingAssgnListArray^[i] := VaryingAssgnListArray^[i+1];
            END;
            DEC(Records);
        ELSE
            INC(Index);
        END;
    END;

    VaryingAssgnListArray^[1].Rate := VAL(LONGINT,Records);   (* First entry has index of max entry. *)

    (*<PRINT
        DisplayArray(VaryingAssgnListArray,Records);
    PRINT>*)

END RemoveDuplicates;









    (*---------------------------------------------------------------

    SetVaryingAssgnListEntryN 

    Purpose : Sets the Nth entry in a rate list.

    Inputs:   
              VaryingAssgnList    : AVaryingAssgnList;
              N           : The interval number.
              Rate        : The rate in effect during this period.
                            From 0.0 to 65535.0
    Outputs:   
              RETURNS     : FALSE if too many intervals to record have
                            been defined.

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.

    Postconditions: 
                    StartDate[N] and Rate[N] are set as passed in.
                    ThruDate[N] = StartDate[N+1].
    ------------------------------------------------------------------ *)

PROCEDURE SetVaryingAssgnListEntryN( VAR VaryingAssgnList : AVaryingAssgnList;
                                      N        : AVaryingAssgnListIndex;
                                      Rate     : REAL
                                ) : BOOLEAN;
VAR
    Records       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
    ok            : BOOLEAN;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    CheckRealRate( Rate );

    ok := (N > 0) AND (N <= MaxIntervals);

    INC(N,FirstReal-1);  (* Skip the first entry, which contains only the Tag. *)

    IF (ok) THEN
        Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
        IF (Records > 0) THEN
            Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
        END;

        ok := (N <= Records);
        IF (ok) THEN
            VaryingAssgnListArray^[N].Rate := RateFromReal(Rate);
        END;

            (* Consolidate any adjacent entries with the same rates. *)
    
        RemoveDuplicates( VaryingAssgnListArray, Records );

        ReleaseObject( VaryingAssgnList );                   (*<KILL*)  VaryingAssgnListArray := NIL; (*KILL>*)
    END;

    (*<PRINT
    IF (NOT ok) THEN 
        SetString(S,"SERIOUS ERROR in V: SetVaryingAssgnListEntryN");
        PrintAString(S);
        FatalError();
    END;
    PRINT>*)

    RETURN ok;

END SetVaryingAssgnListEntryN;



    (* Call with list locked.  Returns it changed and locked, or else
       returns FALSE and locked.   
       Records also := Records+Count *)

PROCEDURE AddEntryAt( VAR VaryingAssgnList   : AVaryingAssgnList;
                      VAR VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
                      VAR Records            : CARDINAL;
                          Index              : CARDINAL
                    ) : BOOLEAN;
VAR
    i : CARDINAL;
    Entries : CARDINAL;   (* Number of elements in physical array. *)
BEGIN
        (* Find out how large the array is that is currently
           allocated. *)

    Entries := NumberOfElements( GetExtSize(VaryingAssgnList),
                                 TSIZE(AVaryingAssgnListEntry) );

        (* "Records" is how many of those elements are used. *)


       (*<PRINT
    SetString(S,"V: AddEntryAt, Records = ");  CtoS(Records,S2); ConcatLS(S,S2);
    ConcatS(S,", Entries = ");  CtoS(Entries,S2);   ConcatLS(S,S2);
    ConcatS(S,", Index = ");  CtoS(Index,S2);   ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

       (* If we can add more entries to the array without increasing its
          size (because we are not using the entire array, do so.  Otherwise,
          add several more rows to the array. *)

    IF (Records >= Entries) THEN
        ReleaseObject( VaryingAssgnList );  (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)
        IF (Records = MaxIntervals) OR
           (NOT SetExtSize( VaryingAssgnList, ArraySize( Records+Quantum, TSIZE(AVaryingAssgnListEntry)))) THEN
            RETURN FALSE;   (* No room *)
        END;
        Entries := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    END;


    INC(Records);
    VaryingAssgnListArray^[1].Rate := VAL(LONGINT,Records);

        (* Move other entries out of the way. *)

    FOR i := Records TO Index + 1 BY -1 DO
        VaryingAssgnListArray^[i] := VaryingAssgnListArray^[i-1];
    END;

    RETURN TRUE;

END AddEntryAt;





PROCEDURE SetNewPoint( VAR VaryingAssgnList   : AVaryingAssgnList;
                       VAR VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
                       VAR Records            : CARDINAL;
                       VAR Index              : CARDINAL;
                           Start              : ADate;
                           RateIs             : REAL
                     ) : BOOLEAN;
VAR
    AddNew : BOOLEAN;
    LastRate : LONGINT;
BEGIN
        (* Add a new list entry. *)

       (*<PRINT
    SetString(S,"V: SetNewPoint, Records = ");  CtoS(Records,S2); ConcatLS(S,S2);
    ConcatS(S,", Start = ");  TimeUtoS(Start,S2);   ConcatLS(S,S2);
    ConcatS(S," (");  CtoS(Start,S2);   ConcatLS(S,S2);
    ConcatS(S,"), RateIs = ");  RealToLStrings(RateIs, 0, 5, S2, S3);   
    ConcatLS(S,S2);  ConcatS( S, "." ); ConcatLS( S, S3 );
    PrintAString(S);
       PRINT>*)

    (*<DEBUG    (* Technically legal, but for testing we don't expect
                     any assignment to run through MaxDate. *) 
    (*
    IF (Start = MaxDate) AND (RateIs <> Zero) THEN
        ErrorPhrase(0);
    END;
    *)
    DEBUG>*)


    Index := FirstReal;  (* Start with the first real entry.  Entry 1 is just the Tag. *)
    LastRate := RateFromReal(Zero);

         (* Search for the first entry whose date is >= Start.  While
            doing so, keep updating LastRate to the rate of the [Index-1]
            entry. *)

    LOOP
        IF (Index > Records) THEN
            EXIT;
        END;
        WITH VaryingAssgnListArray^[Index] DO
            IF (Start <= StartDate) THEN
                EXIT;
            END;
            LastRate := Rate;
        END;
        INC(Index);
    END;


        (* Start <= StartDate or Index > Records *)

        (* Check whether we need to add a new entry to express this new date
           and rate, or is it just a change to the start date or the rate
           of the current point. *) 
    WITH VaryingAssgnListArray^[Index] DO
        AddNew := (Index > Records) OR 
                  ((StartDate <> Start) AND (Rate <> RateFromReal(RateIs)));
    END;

        (* If it is a new entry, create it. *)
    IF (AddNew) THEN
            (* If the effect of this entry is duplicated by the immediately
               prior period, we do not need to add it. *)
        IF (Index > FirstReal) AND (LastRate = RateFromReal(RateIs)) THEN
            RETURN TRUE;
        END;
       
            (* Add a record if possible. *)
        IF NOT AddEntryAt( VaryingAssgnList, VaryingAssgnListArray, Records, Index ) THEN
            RETURN FALSE;   (* No room *)
        END;
    END;

    WITH VaryingAssgnListArray^[Index] DO
        Rate := RateFromReal(RateIs);
        StartDate := Start;
    END;


       (*<PRINT
    SetString(S,"V: End of SetNewPoint, Records = ");  CtoS(Records,S2); ConcatLS(S,S2);
    ConcatS(S,", Index = ");  CtoS(Index,S2);   ConcatLS(S,S2);
    ConcatS(S,", LastRate = ");  RateToS( LastRate, S2 ); 
    ConcatLS(S,S2);
    PrintAString(S);
       PRINT>*)

    RETURN TRUE;

END SetNewPoint;





    (*---------------------------------------------------------------

    CreateVaryingAssgnListEntry 

    Purpose : Creates a new entry in a rate list and returns its index
              in the list.

    Inputs:   
              VaryingAssgnList    : AVaryingAssgnList;
              StartDate   : The date of the beginning of this period.
              Rate        : The rate in effect during this period.
                            From 0.0 to 65535.0
    Outputs:   
              RETURNS     : TRUE usually, except FALSE
                            if too many entries to record have
                            been defined.

    Preconditions : VaryingAssgnList was created by 
                    CreateVaryingAssgnList and not disposed.

    Postconditions: 
		    There is an entry with StartDate = the passed 
                    value, EndDate = the end date of the original
                    entry whose interval contained StartDate, and Rate = 
                    the passed value.

		    The total number of entries may less than it was
                    before.
    ------------------------------------------------------------------ *)

PROCEDURE CreateVaryingAssgnListEntry( VAR VaryingAssgnList   : AVaryingAssgnList;
                                           StartDate  : ADate;
                                           Rate       : REAL
                                      ) : BOOLEAN;

VAR
    i,
    Index,
    Records       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    CheckRealRate( Rate );

    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;

        (* Put the new start date and rate into the array. *)

    IF NOT SetNewPoint(VaryingAssgnList, VaryingAssgnListArray, Records, Index,
                       StartDate, Rate ) THEN
        RETURN FALSE;
    END;

        (* Consolidate any adjacent entries with the same rates. *)

    RemoveDuplicates( VaryingAssgnListArray, Records );

    ReleaseObject( VaryingAssgnList );                       (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

    RETURN TRUE;

END CreateVaryingAssgnListEntry;






    (*---------------------------------------------------------------

    DisposeVaryingAssgnListEntry 

    Purpose : Removes the new Nth entry in a rate list.

    Inputs:   
              VaryingAssgnList    : AVaryingAssgnList;
              N           : The interval number.
          
    Outputs:   

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.

    Postconditions: 
                    All previous intervals N+j+1, for j > 0, will now
                    be numbered N+j.
		    The total number of intervals will be reduced by 1,
                    unless it was already 1.
                    ThruDate[i] always = StartDate[i+1] for all i > 0 where
                    i+1 is an entry.
    ------------------------------------------------------------------ *)

PROCEDURE DisposeVaryingAssgnListEntry( VAR VaryingAssgnList : AVaryingAssgnList;
                                         N        : AVaryingAssgnListIndex   );
VAR
    i,Records             : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
    ok                    : BOOLEAN;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    ok := (N > 0) AND (N <= MaxIntervals);

    INC(N,FirstReal-1);  (* Skip the first entry, which contains only the Tag. *)

    IF (NOT ok) THEN
        RETURN;
    END;

    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;

    IF (Records <= FirstReal) THEN
        ReleaseUnchangedObject( VaryingAssgnList );             (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)
        RETURN; (* All records deleted. *)
    END;

    IF (N <= Records) THEN
        FOR i := N TO Records-1 DO
            VaryingAssgnListArray^[i] := VaryingAssgnListArray^[i+1];
        END;
        DEC(Records);
    END;

    VaryingAssgnListArray^[1].Rate := VAL(LONGINT,Records);   (* First entry has number used. *)

        (* Consolidate any adjacent entries with the same rates. *)

    RemoveDuplicates( VaryingAssgnListArray, Records );

    ReleaseObject( VaryingAssgnList );                           (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

END DisposeVaryingAssgnListEntry;



    (*---------------------------------------------------------------

    CreateVaryingAssgnListRange 

    Purpose : Adjusts a varying assignment list so that the passed
              Rate is in effect from StartDate through EndDate.

    Inputs:   
              VaryingAssgnList    : AVaryingAssgnList;
              StartDate           : StartingDate
              EndDate             : End of the range.
              Rate                : The rate in effect during this period.
                                    From 0.0 to 65535.0

    Outputs:  TRUE if successful. 

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList 
                    and not disposed.

    Postconditions: 
                    All previous intervals in the date range [Start,End) are
                    removed.   All other intervals remain.
                    There will be two entries in the list, i and i+1,
                    such that the date of entry i is <= Start and the date
                    of entry i+1 is >= End.
    ------------------------------------------------------------------ *)

PROCEDURE CreateVaryingAssgnListRange( VAR VaryingAssgnList   : AVaryingAssgnList;
                                           Start,
                                           End                : ADate;
                                           RateIs             : REAL
                                      ) : BOOLEAN;
VAR
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
    i,j,
    Index,
    Records, NR  : CARDINAL;
    LastRate : LONGINT;
    ok : BOOLEAN;
BEGIN
       (*<PRINT
    SetString(S,"V: CreateVaryingAssgnListRange "); HandleToString(VaryingAssgnList,S2); ConcatLS(S,S2);
    ConcatS(S,", Start = ");  TimeUtoS(Start,S2);  ConcatLS(S,S2);
    ConcatS(S,", End = ");  TimeUtoS(End,S2);  ConcatLS(S,S2);
    ConcatS(S,", Rate = ");  RealToLStrings(RateIs, 0, 5, S2, S3);  
    ConcatLS(S,S2);  ConcatS( S, "." );  ConcatLS( S, S3 );
    PrintAString(S);
       PRINT>*)

    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    CheckRealRate( RateIs );

    IF (Start >= End) THEN  (* Trivial *)
        RETURN TRUE;
    END;


        (* If given a NIL entry, we can efficiently create just the 
           interval needed. *)

    IF (VaryingAssgnList = AVaryingAssgnList(NIL)) THEN
        VaryingAssgnList := CreateVaryingAssgnList( RateIs,
                                                    Start,ExtMedium);
        RETURN
           (VaryingAssgnList <> AVaryingAssgnList(NIL))
           AND
           (CreateVaryingAssgnListEntry(VaryingAssgnList,End,Zero));
    END;


        (* Otherwise, update the existing list. *)

    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;

        (* Special situation if we have a zero rate at the beginning of the
           list we don't need it. *)

    WITH VaryingAssgnListArray^[FirstReal] DO
        IF (StartDate < Start) AND (RealFromRate(Rate) = Zero) THEN
            StartDate := Start;
        END;
    END;


        (* Locate the first entry > our beginning date. *)

    LastRate := RateFromReal(Zero);
    j := FirstReal;
    LOOP
        WITH VaryingAssgnListArray^[j] DO
            IF (j > Records) OR (StartDate > Start) THEN
                EXIT;
            END;
            LastRate := Rate;
        END;
        INC(j);
    END;

        (* Remove intervening records in the interval [Start,End).
           Set LastRate to the rate that should be in effect at dates
           beginning with End.  *)

    Index := j;
    LOOP
        WITH VaryingAssgnListArray^[Index] DO
            IF (Index > Records) OR (StartDate > End) THEN
                EXIT;
            END;
            LastRate := Rate;
            IF (StartDate = End) THEN                         (* AJL 2-Mar-92 *)
                EXIT;
            END;
        END;
        INC(Index);
    END;

        (* LastRate is the rate of the last interval to be removed,
           or else there aren't any (j=Index). LastRate is the rate
           that should become in force at the end of the interval
           [Start,End).  *)

        (* Index now identifies the first entry we cannot remove.  *)

           (*<PRINT
        SetString(S,"V: Ready to remove overlaps, Index = ");
        CtoS(Index,S2); ConcatLS(S,S2);
        ConcatS(S,", j = ");  CtoS(j,S2);  ConcatLS(S,S2);
        ConcatS(S,", LastRate = ");  LongToS(LastRate, S2);  
        ConcatLS(S,S2);  
        ConcatS(S,", Records = ");  CtoS(Records,S2);  ConcatLS(S,S2);
        PrintAString(S);
           PRINT>*)

    IF (Index > j) THEN

        NR := Index - j;      (* Number to remove, beginning at j. *)
            (* Remove the unneeded records, then change the allocated size
               of the varying list. *)
        FOR i := j+NR TO Records DO
            VaryingAssgnListArray^[i-NR] :=  VaryingAssgnListArray^[i];
        END;
        Records := Records - NR;
        VaryingAssgnListArray^[1].Rate := VAL(LONGINT,Records);   (* First entry has number used. *)
     END;

        (* LastRate is the rate of the interval containing
           the End date.
         *)

        (* Put the new start date and rate into the array. *)

    IF NOT SetNewPoint(VaryingAssgnList, VaryingAssgnListArray, Records, Index,
                       Start, RateIs ) THEN
        RETURN FALSE;
    END;

    IF (End <> MaxDate) THEN
        IF NOT SetNewPoint(VaryingAssgnList, VaryingAssgnListArray, Records,
                           Index,
                           End, RealFromRate(LastRate) ) THEN
            RETURN FALSE;
        END;
    END;

        (* Consolidate any adjacent entries with the same rates. *)

    RemoveDuplicates( VaryingAssgnListArray, Records );

    ReleaseObject( VaryingAssgnList );                       (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

    RETURN TRUE;

END CreateVaryingAssgnListRange;


(*<PRINT 
    PROCEDURE DisplayArray(    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
                               Records               : CARDINAL );
    VAR
        i : CARDINAL;
        
    BEGIN
        SetString(S, "     [Records = ");  CtoS(Records,S2); ConcatLS(S,S2);
        ConcatS(S,"]");
        PrintAString(S);
        
        FOR i := FirstReal TO Records DO
            SetString(S, "     ");
            CtoS(i,S2);  ConcatLS(S,S2);  ConcatS(S,":  ");
            TimeUtoS(VaryingAssgnListArray^[i].StartDate,S2);  ConcatLS(S,S2);
            ConcatS(S,"  @  ");
            RealToLStrings(RealFromRate(VaryingAssgnListArray^[i].Rate), 0, 5, S2, S3);  
            ConcatLS(S,S2);  ConcatS( S, "." );  ConcatLS( S, S3 );
            PrintAString(S);
        END;
    END DisplayArray;
PRINT>*)






    (* LocateDate -- Find the array index of the entry containing Date.
                     This is the actual index, not adjusted for presentation
                     to the client.  In other words, it is not adjusted
                     for the tag record. 
                     *)


PROCEDURE LocateDate(    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
                         Records               : CARDINAL;
                         Date                  : ADate;
                     VAR N                     : AVaryingAssgnListIndex);
BEGIN
    (*<PRINT
        SetString(S,"LocateDate, Records = ");  CtoS(Records,S2);   ConcatLS(S,S2);
        ConcatS(S,", Date = ");  TimeUtoS(Date,S2);  ConcatLS(S,S2);
        PrintAString(S);
        DisplayArray(VaryingAssgnListArray,Records);
    PRINT>*)

        (* Locate the first entry whose start date is too large. *)
    N := FirstReal;                                         (* 4-Oct-90 RSC was FirstReal+1 *)
    WHILE (N <= Records) AND                                (* 3-Oct-90 RSC/AJL was < *)
          (VaryingAssgnListArray^[N].StartDate <= Date) DO
        INC(N);
    END;
        (* Back off by one. *)
    DEC(N);


    (*<PRINT
        SetString(S,"LocateDate, Returns N := ");  CtoS(N,S2);  ConcatLS(S,S2);
        PrintAString(S);
    PRINT>*)

END LocateDate;




    (*---------------------------------------------------------------

    LocateDateInVaryingAssgnList 

    Purpose : Given a Date, finds the index number, N, of the half-open
              interval [StartDate..ThruDate) containing Date.

    Inputs:   VaryingAssgnList       : A VaryingAssgnList;
              Date           : A date.

    Outputs:  
   	      N           :  Index to the interval containing Date.
                         If 0, then there is no interval containing the
                         date.  That is, the date is less than the date
                         of the first entry.

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.
                    Date is within the range of the calendar. 

    Postconditions: N is returned as noted above. 
    ------------------------------------------------------------------ *)



PROCEDURE LocateDateInVaryingAssgnList(    VaryingAssgnList   : AVaryingAssgnList;
                                        Date       : ADate;
                                    VAR N          : AVaryingAssgnListIndex);
VAR
    Records       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;

    LocateDate(VaryingAssgnListArray, Records, Date, N );

        (* Adjust for the presence of the tag record. *)
    DEC(N,FirstReal-1);                                  (* 4-Oct-90 RSC was FirstReal *)

    ReleaseUnchangedObject( VaryingAssgnList );          (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

END LocateDateInVaryingAssgnList;








    (*---------------------------------------------------------------

    LocateRateAtDate 

    Purpose : Given a Date, finds the rate in effect at that date.

              Equivalent to



    Inputs:   VaryingAssgnList       : A VaryingAssgnList;
              Date           : A date.

    Outputs:  
              Rate        : The rate in effect during this period.
                            From 0.0 to 65535.0

    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.
                    Date is within the range of the calendar. 

    Postconditions: If the date is in the list, Rate is returned as noted
                    above. 
                    If the date is not in the list, 0 is returned.
    ------------------------------------------------------------------ *)


PROCEDURE LocateRateAtDate(    VaryingAssgnList   : AVaryingAssgnList;
                               Date       : ADate
                          ) : REAL;

VAR
    Records, N            : CARDINAL;
    Rate                  : REAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;

    LocateDate(VaryingAssgnListArray, Records, Date, N );

    IF (N >= FirstReal) THEN
        Rate := RealFromRate(VaryingAssgnListArray^[N].Rate);
    ELSE
        Rate := Zero;
    END;

    ReleaseUnchangedObject( VaryingAssgnList );          (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

    RETURN Rate;

END LocateRateAtDate;




    (*---------------------------------------------------------------

    Number Of Rates In List

    Purpose : Given a Rate List, returns the number of entries in the list.

    Inputs:   VaryingAssgnList       : A VaryingAssgnList;

    Outputs:  
   	          RETURN         : Number of entries.


    Preconditions : VaryingAssgnList was created by CreateVaryingAssgnList and not disposed.

    Postconditions: RETURN as noted above.

    ------------------------------------------------------------------ *)
PROCEDURE NumberOfRatesInList(  VaryingAssgnList   : AVaryingAssgnList ) : CARDINAL;
VAR
    Records       : CARDINAL;
    VaryingAssgnListArray : AVaryingAssgnListArrayPointer;
BEGIN
    (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)


    Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
    IF (Records > 0) THEN
        Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
    END;
    ReleaseUnchangedObject( VaryingAssgnList );                            (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

    IF (Records >= FirstReal) THEN    (* The last entry in the list is a sentinel. *)
        DEC(Records,FirstReal);
    ELSE
        Records := 0;
    END;

    RETURN Records;

END NumberOfRatesInList;








PROCEDURE StoreVaryingAssgnList(  VaryingAssgnList  : AVaryingAssgnList;
                                  StorageProc       : Filing.AStoreProc;
                                  Context           : ADDRESS );

BEGIN                       (* StoreVaryingAssgnList *)

    StoreTheList( VaryingAssgnList, StorageProc, Context, FALSE );

END StoreVaryingAssgnList;




PROCEDURE StoreVaryingAssgnListOldFormat(  VaryingAssgnList  : AVaryingAssgnList;
                                           StorageProc       : Filing.AStoreProc;
                                           Context           : ADDRESS );

BEGIN                       (* StoreVaryingAssgnListOldFormat *)

    StoreTheList( VaryingAssgnList, StorageProc, Context, TRUE );

END StoreVaryingAssgnListOldFormat;



PROCEDURE StoreTheList(     VaryingAssgnList : AVaryingAssgnList;
                            StorageProc      : Filing.AStoreProc;
                            Context          : ADDRESS;
                            StoreAsCardinal  : BOOLEAN            );

VAR
    Records, i              : CARDINAL;
    DateList                : ADateList;
    N                       : ADateListIndex;
    BigDate                 : ABigTime;
    VaryingAssgnListArray   : AVaryingAssgnListArrayPointer;
    OldRate                 : CARDINAL;

BEGIN                       (* StoreTheList *)
    IF (VaryingAssgnList = AVaryingAssgnList(NIL)) THEN
        StorageProc(NIL,0,Context);
    ELSE
        (*<DEBUG CheckAssgnListValid(VaryingAssgnList); DEBUG>*)

        Records := LockObjectArray( VaryingAssgnList, VaryingAssgnListArray, TSIZE(AVaryingAssgnListEntry) );
        IF (Records > 0) THEN
            Records := VAL(CARDINAL,VaryingAssgnListArray^[1].Rate);   (* First entry has number used. *)
        END;
        
        DateList := ADateList(NIL);
        FOR i := FirstReal TO Records DO
(*$O-*)
            WITH VaryingAssgnListArray^[i] DO
                CalendarTimeToBigTime( StartDate, TRUE, BigDate );
                IF (StoreAsCardinal) THEN
                    OldRate := TRUNC(RealFromRate( Rate ));
                    N := CreateDateListEntry( DateList, BigDate, OldRate );
                ELSE
                    N := CreateDateListEntry( DateList, BigDate, Rate );
                END;
            END;
(*$O=*)
        END;
        ReleaseUnchangedObject( VaryingAssgnList );                  (*<KILL*) VaryingAssgnListArray := NIL; (*KILL>*)

        StoreDateList( DateList, StorageProc, Context );
        DisposeDateList( DateList );
    END;
END StoreTheList;




PROCEDURE LoadVaryingAssgnList ( VAR VaryingAssgnList    : AVaryingAssgnList;
                                  StoragePref : AnExtStoragePreference;
                                  PredictSize : Filing.APredictSizeProc;
                                  LoadProc    : Filing.ALoadProc;
                                  ReadNext    : Filing.AReadNextProc;
                                  Context     : ADDRESS ):BOOLEAN;
BEGIN

    RETURN LoadTheList( VaryingAssgnList, StoragePref, PredictSize, LoadProc,
                        ReadNext, Context, FALSE );

END LoadVaryingAssgnList;




PROCEDURE LoadVaryingAssgnListOldFormat ( VAR VaryingAssgnList    : AVaryingAssgnList;
                                              StoragePref : AnExtStoragePreference;
                                              PredictSize : Filing.APredictSizeProc;
                                              LoadProc    : Filing.ALoadProc;
                                              ReadNext    : Filing.AReadNextProc;
                                              Context     : ADDRESS ):BOOLEAN;
BEGIN

    RETURN LoadTheList( VaryingAssgnList, StoragePref, PredictSize, LoadProc,
                        ReadNext, Context, TRUE );

END LoadVaryingAssgnListOldFormat;




PROCEDURE LoadTheList ( VAR VaryingAssgnList    : AVaryingAssgnList;
                            StoragePref         : AnExtStoragePreference;
                            PredictSize         : Filing.APredictSizeProc;
                            LoadProc            : Filing.ALoadProc;
                            ReadNext            : Filing.AReadNextProc;
                            Context             : ADDRESS; 
                            LoadAsCardinal      : BOOLEAN
                      ) : BOOLEAN;

VAR
    P           : AVaryingAssgnListArrayPointer;
    DateList    : ADateList;
    N           : ADateListIndex;
    BStartDate,
    BThruDate   : ABigTime;
    Dates       : CARDINAL;
    Entries     : CARDINAL;
    i,
    Records     : CARDINAL;
    OldRate     : CARDINAL;
    ok          : BOOLEAN;

BEGIN                       (* LoadTheList *)

    ok := (LoadDateList( DateList, ExtMedium, PredictSize, LoadProc, ReadNext, Context ));

    IF (LoadAsCardinal) THEN
        i := TSIZE( CARDINAL );
    ELSE
        i := TSIZE( LONGINT );
    END;

    Dates := NumberOfDatesInList(DateList,i);
    Entries := Dates + (FirstReal-1);

    ok := ok AND
          (GetExtStatus() = ExtGood) AND
          (CreateExtObjectWithSize( VaryingAssgnList, StoragePref,
                ArraySize( Entries, TSIZE(AVaryingAssgnListEntry)) ));

    IF (ok) THEN
        Records := LockObjectArray( VaryingAssgnList, P, TSIZE(AVaryingAssgnListEntry) );

        N               := 1;

        WITH P^[1] DO
            StartDate := Tag;       (* Validity check. *)
            Rate      := VAL(LONGINT,Entries);   (* Index of last item in list. *)
        END;

        FOR i := FirstReal TO Entries DO
(*$O-*)
            WITH P^[i] DO
                IF (LoadAsCardinal) THEN
                    IF (NOT GetDateListEntry( DateList, N, BStartDate, BThruDate, OldRate )) THEN
                        ErrorPhrase(ModuleNumber+2);
                    END;
                    Rate := RateFromReal( FLOAT( OldRate ));
                ELSE
                    IF (NOT GetDateListEntry( DateList, N, BStartDate, BThruDate, Rate )) THEN
                        ErrorPhrase(ModuleNumber+2);
                    END;
                END;
                StartDate := BigTimeToCalendarTime( BStartDate );
            END;
(*$O=*)
            INC(N);
        END;
        DisposeDateList( DateList );

        RemoveDuplicates( P, Records );

        ReleaseObject( VaryingAssgnList );                       (*<KILL*) P := NIL; (*KILL>*)

    END;

    RETURN ok;

END LoadTheList;


BEGIN
    CheckAssgnListValid := XCheckAssgnListValid;
END VaryAssgnment.

