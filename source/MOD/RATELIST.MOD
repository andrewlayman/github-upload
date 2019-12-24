IMPLEMENTATION MODULE RateLists;

(* Modification History

    ?-???-90 AJL  First version
    8-Jun-90 RSC  Changed the "NotYetImplemented"s to real code.
    7-Aug-90 RSC  Added Speed parameter to CopyRateList
   18-Sep-90 CL   Removed the unused argument DataSize from
                  procedure DateListsAreEqual. 
*)


FROM BigTimeU   IMPORT
    (* CONST *)     MAXBIGTIME,
    (* TYPE *)      ABigTime;

FROM DateLists  IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      CreateDateList, DisposeDateList, CopyDateList,
                    DateListsAreEqual, GetDateListEntry, SetDateListEntryN,
                    CreateDateListEntry, DisposeDateListEntry,
                    LocateDateInDateList, NumberOfDatesInList,
                    StoreDateList, LoadDateList;

IMPORT Filing;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS,
    (* PROC *)      TSIZE; 








CONST
    DataSize  = TSIZE(REAL);








    (*---------------------------------------------------------------

    CreateRateList 

    Purpose : Creates a RateList.

    Inputs:   InitialRate : Starting point for rates.

    Outputs:  RETURNS : ARateList;

    Preconditions : None.

    Postconditions : The created rate list has a single interval, number 1,
                     which is the half open interval [StartDate..ThruDate),
                     and is initialized to the passed InitialRate.

                     ThruDate is assumed to be MAXBIGTIME, or the end of
                     the calendar.

    ------------------------------------------------------------------ *)

PROCEDURE CreateRateList( InitialRate : REAL;
                          StartDate   : ABigTime ) : ARateList;
BEGIN
    RETURN ARateList(CreateDateList( InitialRate, StartDate ) );
END CreateRateList;



    (*---------------------------------------------------------------

    DisposeRateList 

    Purpose : Discards a RateList, deallocating any storage used.

    Inputs:   RateList : ARateList.

    Outputs:  RateList : An invalid RateList;

    Preconditions : RateList was created by CreateRateList and not disposed.

    Postconditions : The RateList is no longer valid.

    ------------------------------------------------------------------ *)

PROCEDURE DisposeRateList( VAR RateList : ARateList);
VAR
    DateList : ADateList;
BEGIN

    DateList := ADateList( RateList );
    DisposeDateList( DateList );
    RateList := ARateList( DateList );

END DisposeRateList;






    (*---------------------------------------------------------------

    CopyRateList 

    Purpose : Copies the contents of one rate list to another. 

    Inputs:   Source : ARateList.

    Outputs:  Target : ARateList;

    Preconditions : Source was created by CreateRateList
                    and not disposed.

    Postconditions : Source is unchanged and Target = Source.

    ------------------------------------------------------------------ *)


PROCEDURE CopyRateList( VAR Target : ARateList; Source : ARateList;
                            Speed  : AnExtStoragePreference );
VAR
    DTarget : ADateList;
BEGIN
    DTarget := ADateList( Target );
    CopyDateList( DTarget, ADateList(Source), Speed );
    Target := ARateList( DTarget );
END CopyRateList;




    (*---------------------------------------------------------------

    RateListsAreEqual 

    Purpose : Determines whether two ratelists are equivalent.

    Inputs:   A, B : ARateList.

    Outputs:  TRUE iff each component of A is equal to the corresponding
              component of B.

    Preconditions : A and B were created by CreateRateList
                    and not disposed.

    Postconditions : A and B are unaffected.

    ------------------------------------------------------------------ *)


PROCEDURE RateListsAreEqual( A, B  : ARateList ) : BOOLEAN;
BEGIN

    RETURN DateListsAreEqual( ADateList(A), ADateList(B) );

END RateListsAreEqual;




    (*---------------------------------------------------------------

    GetRateListEntry 

    Purpose : Returns one of the many intervals of time during a rate list,
              or indicates that no such interval exists.  Which interval
              is given by N.

    Inputs:   
              RateList    : ARateList;
              N           : The interval number.

    Outputs:  
              StartDate   : The date of the beginning of this period.
              ThruDate    : The smallest date > StartDate that is not
                            in this period.  I.E. the beginning (first 
                            moment) of the next period.     
              Rate        : The rate in effect during this period.
	      RETURNS     : TRUE if this is a defined interval.  Else
                            returns FALSE.  Note: if period n is not 
                            defined, then periods n+i are undefined, for 
                            all i >= 0.

    Preconditions : RateList was created by CreateRateList and not disposed.
    ------------------------------------------------------------------ *)

PROCEDURE GetRateListEntry(     RateList : ARateList;
                                N        : ARateListIndex;
                            VAR StartDate,
                                ThruDate : ABigTime;
                            VAR Rate     : REAL
                           ) : BOOLEAN;
VAR
    ok            : BOOLEAN;
BEGIN
    ok := GetDateListEntry( ADateList(RateList), ADateListIndex(N),
                            StartDate, ThruDate, Rate );
    RETURN ok;
END GetRateListEntry;






    (*---------------------------------------------------------------

    SetRateListEntryN 

    Purpose : Sets the Nth entry in a rate list.

    Inputs:   
              RateList    : ARateList;
              N           : The interval number.
              Rate        : The rate in effect during this period.
          
    Outputs:   
              RETURNS     : FALSE if too many intervals to record have
                            been defined.

    Preconditions : RateList was created by CreateRateList and not disposed.

    Postconditions: 
                    StartDate[N] and Rate[N] are set as passed in.
                    ThruDate[N] = StartDate[N+1].
    ------------------------------------------------------------------ *)

PROCEDURE SetRateListEntryN( VAR RateList : ARateList;
                                 N        : ARateListIndex;
                                 Rate     : REAL
                           ) : BOOLEAN;
VAR
    DateList  : ADateList;
    ok        : BOOLEAN;
BEGIN
    DateList := ADateList( RateList );
    ok := SetDateListEntryN( DateList,
                             ADateListIndex(N),
                             Rate );
    RateList := ARateList( DateList );

    RETURN ok;

END SetRateListEntryN;







    (*---------------------------------------------------------------

    CreateRateListEntry 

    Purpose : Creates a new Nth entry in a rate list.

    Inputs:   
              RateList    : ARateList;
              StartDate   : The date of the beginning of this period.
              Rate        : The rate in effect during this period.
          
    Outputs:   
              RETURNS     : The resulting rate list index, or zero
                            if too many entries to record have
                            been defined.

    Preconditions : RateList was created by CreateRateList and not disposed.

    Postconditions: 
		    The total number of entries is not less than it was
                    before.
		    There is an entry n, with StartDate = the passed 
                    value, and same for Rate.
		    General conditions on RateLists still obtain.
    ------------------------------------------------------------------ *)

PROCEDURE CreateRateListEntry( VAR RateList   : ARateList;
                                   StartDate  : ABigTime;
                                   Rate       : REAL
                              ) : ARateListIndex;
VAR
    N         : ARateListIndex;
    DateList  : ADateList;
BEGIN

    DateList := ADateList( RateList );
    N := ARateListIndex(CreateDateListEntry(DateList, StartDate, Rate ));
    RateList := ARateList( DateList );

    RETURN N;

END CreateRateListEntry;






    (*---------------------------------------------------------------

    DisposeRateListEntry 

    Purpose : Removes the new Nth entry in a rate list.

    Inputs:   
              RateList    : ARateList;
              N           : The interval number.
          
    Outputs:   

    Preconditions : RateList was created by CreateRateList and not disposed.

    Postconditions: 
                    All previous intervals N+j+1, for j > 0, will now
                    be numbered N+j.
		    The total number of intervals will be reduced by 1,
                    unless it was already 1.
                    ThruDate[i] always = StartDate[i+1] for all i > 0 where
                    i+1 is an entry.
    ------------------------------------------------------------------ *)

PROCEDURE DisposeRateListEntry( VAR RateList : ARateList;
                                    N        : ARateListIndex   );
VAR
    DateList : ADateList;
    ok       : BOOLEAN;
BEGIN
    ok := (N > 0) AND (N <= MaxIntervals);

    IF (ok) THEN
        DateList := ADateList(RateList);
        DisposeDateListEntry( DateList, DataSize, ADateListIndex(N) );
        RateList := ARateList(DateList);
    END;

END DisposeRateListEntry;






    (*---------------------------------------------------------------

    LocateDateInRateList 

    Purpose : Given a Date, finds the index number, N, of the half-open
              interval [StartDate..ThruDate) containing Date.

    Inputs:   RateList       : A RateList;
              Date           : A date.

    Outputs:  
   	      N           :  Index to the interval containing Date.
                         If 0, then there is no interval containing the
                         date.  That is, the date is less than the date
                         of the first entry.

    Preconditions : RateList was created by CreateRateList and not disposed.
                    Date is within the range of the calendar. 

    Postconditions: N is returned as noted above. 
    ------------------------------------------------------------------ *)


PROCEDURE LocateDateInRateList(    RateList   : ARateList;
                                   Date       : ABigTime;
                               VAR N          : ARateListIndex);
VAR
    N1  : ADateListIndex;
BEGIN
    N1 := ADateListIndex( N );
    LocateDateInDateList( ADateList(RateList), Date, DataSize, N1 );
    N  := ARateListIndex( N1 );
END LocateDateInRateList;



    (*---------------------------------------------------------------

    Number Of Rates In List

    Purpose : Given a Rate List, returns the number of entries in the list.

    Inputs:   RateList       : A RateList;

    Outputs:  
   	          RETURN         : Number of entries.


    Preconditions : RateList was created by CreateRateList and not disposed.

    Postconditions: RETURN as noted above.

    ------------------------------------------------------------------ *)
PROCEDURE NumberOfRatesInList(  RateList   : ARateList ) : CARDINAL;
BEGIN
    RETURN NumberOfDatesInList(  ADateList( RateList ), DataSize );
END NumberOfRatesInList;








PROCEDURE StoreRateList(     RateList    : ARateList;
                             StorageProc : Filing.AStoreProc;
                             Context     : ADDRESS );
BEGIN
    StoreDateList( ADateList(RateList), StorageProc, Context );
END StoreRateList;




PROCEDURE LoadRateList ( VAR RateList    : ARateList;
                             StoragePref : AnExtStoragePreference;
                             PredictSize : Filing.APredictSizeProc;
                             LoadProc    : Filing.ALoadProc;
                             ReadNext    : Filing.AReadNextProc;
                             Context     : ADDRESS ):BOOLEAN;
VAR
    DateList    : ADateList;
    ok          : BOOLEAN;
BEGIN
    DateList := ADateList(RateList);
    ok := LoadDateList( DateList, StoragePref, PredictSize, LoadProc,
                        ReadNext, Context );
    RateList := ARateList(DateList);

    RETURN ok;

END LoadRateList;


END RateLists.
