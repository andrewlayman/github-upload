IMPLEMENTATION MODULE DateLists;

(* Data structures and procedures to manage lists of Date records.

   MODIFICATION HISTORY:

    ?-Jun-90 AJL  First version of RateLists, the father of this module.
   20-Jun-90 RSC  First version, genericised from RateLists.
    5-Jul-90 EGK  Removed unnecessary "ok" test from DisposeDateListEntry.
    9-Jul-90 EGK  Initialize "Records" to something in LocateDateinDateList.
    7-Aug-90 RSC  Add speed parameter to CopyDateList
   13-Aug-90 RSC  Correct LocateDateInDateList.
   14-Aug-90 RSC  Correct LocateDateInDateList.  Again.
    4-Sep-90 RSC  Correct LocateDateInDateList.  Again.
   18-Sep-90 CL   Removed unused argument DataSize from procedure
                  DateListsAreEqual. 
*)



FROM BigTimeU   IMPORT
    (* CONST *)     MINBIGTIME, MAXBIGTIME,
    (* TYPE *)      ABigTime,
    (* PROC *)      CompareBigTimes;

IMPORT Filing;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
                    AnExtStatus,
    (* PROC *)      CreateExtObject, GetExtSize, NumberOfElements,
                    SetExtData, DiscardExtObject, ReleaseObject,
                    CreateExtObjectWithSize, LockObject, CopyExtObject,
                    LockObjectArray, SetExtSize, ArraySize,
                    GetExtStatus, ReleaseUnchangedObject;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, BYTE,
    (* PROC *)      TSIZE, ADR;






CONST
    Overhead    = TSIZE( ABigTime );


TYPE
    ADateListArrayPointer = POINTER TO ARRAY [0..9999] OF BYTE;
    ABigTimePointer       = POINTER TO ABigTime;





PROCEDURE GetOffset(     Element,
                         SizeEach,
                         ArrayBytes,
                         DataHigh    : CARDINAL;
                         Array       : ADateListArrayPointer;
                     VAR BTP         : ABigTimePointer;
                     VAR Offset,
                         End         : CARDINAL ) : BOOLEAN;
VAR
    DataTotal   : CARDINAL;
BEGIN
    IF ODD(SizeEach) THEN INC(SizeEach); END;

    Offset := (Element - 1) * SizeEach;
    End    := Offset+SizeEach-1;

    BTP    := ADR( Array^[Offset] );
    INC(Offset, Overhead);

    IF (End < Offset) THEN HALT; END;  (* Code bug? *)

    DataTotal := End-Offset;
    IF (DataHigh < DataTotal) THEN
        End := Offset + DataHigh;
    END;

    RETURN (End < ArrayBytes);

END GetOffset;






PROCEDURE Get(     Element,
                   SizeEach    : CARDINAL;
                   Array       : ADateListArrayPointer;
                   ArrayBytes  : CARDINAL;
               VAR StartDate   : ABigTime;
               VAR Item        : ARRAY OF BYTE ) : BOOLEAN;
VAR
    i, j,
    Offset,
    End     : CARDINAL;
    DateP   : ABigTimePointer;
    ok      : BOOLEAN;
BEGIN
    ok := GetOffset( Element, SizeEach, ArrayBytes, HIGH(Item), Array, DateP, Offset, End );

    IF (ok) THEN

        StartDate := DateP^;

        j := 0;
        FOR i := Offset TO End DO
            Item[j] := Array^[i];
            INC(j);
        END;
    END;

    RETURN ok;

END Get;






PROCEDURE Set(     Element,
                   SizeEach    : CARDINAL;
                   Array       : ADateListArrayPointer;
                   ArrayBytes  : CARDINAL;
                   StartDate   : ABigTime;
               VAR Item        : ARRAY OF BYTE );
VAR
    i, j,
    Offset,
    End     : CARDINAL;
    DateP   : ABigTimePointer;
    ok      : BOOLEAN;
BEGIN
    ok := GetOffset( Element, SizeEach, ArrayBytes, HIGH(Item), Array, DateP, Offset, End );

    IF (ok) THEN
        DateP^ := StartDate;

        j := 0;
        FOR i := Offset TO End DO
            Array^[i] := Item[j];
            INC(j);
        END;
    ELSE
        HALT; (* Code bug here somewhere! *)
    END;

END Set;







(*   GENERAL CONDITIONS:

     1.   There is no entry 0.

     2.   For all entries i and j, where j=i+1 and the entry j
          and i are defined, StartDate[i] < StartDate[j] and
          ThruDate[i] = StartDate[j+1].
          (Entries are sorted by start date, and are contiguous.)

    Note:

        A Modula standard allows passing ANY structure as an ARRAY
        OF BYTES, which allows for having generic record contents.

*)

    (*---------------------------------------------------------------

    CreateDateList 

    Purpose : Creates a DateList.

    Inputs:   InitialData : First record, not including the date.
                            (this is just the extra data)

                            This is assumed to be the EXACT LENGTH of
                            one record.

    Outputs:  RETURNS : ADateList;

    Preconditions : None.

    Postconditions : The created Date list has a single interval, number 1,
                     which is the half open interval [StartDate..ThruDate),
                     and is initialized to the passed InitialData.

                     ThruDate is assumed to be MAXBIGTIME, or the end of
                     the calendar.

    ------------------------------------------------------------------ *)

PROCEDURE CreateDateList( InitialData : ARRAY OF BYTE;
                          StartDate   : ABigTime ) : ADateList;
VAR
    FullSize,
    DataSize                : CARDINAL;
    DateList                : ADateList;
    DateListArrayPointer    : ADateListArrayPointer;
BEGIN
    DataSize := Overhead + HIGH(InitialData) + 1;
    FullSize := ArraySize( DataSize, 2 );

    IF (CreateExtObjectWithSize( DateList, ExtMedium, FullSize) AND
        (LockObject( DateList, DateListArrayPointer ) <> 0))  THEN

        Set( 1, DataSize, DateListArrayPointer, FullSize, StartDate,  InitialData );
        Set( 2, DataSize, DateListArrayPointer, FullSize, MAXBIGTIME, InitialData );

        ReleaseObject( DateList );
    ELSE
        DateList := ADateList(NIL);
    END;

    RETURN DateList;

END CreateDateList;






    (*---------------------------------------------------------------

    DisposeDateList 

    Purpose : Discards a DateList, deallocating any storage used.

    Inputs:   DateList : ADateList.

    Outputs:  DateList : An invalid DateList;

    Preconditions : DateList was created by CreateDateList and not disposed.

    Postconditions : The DateList is no longer valid.

    ------------------------------------------------------------------ *)

PROCEDURE DisposeDateList(VAR DateList : ADateList);
BEGIN
    DiscardExtObject( DateList );
END DisposeDateList;








    (*---------------------------------------------------------------

    CopyDateList 

    Purpose : Copies the contents of one rate list to another. 

    Inputs:   Source : ADateList.

    Outputs:  Target : ADateList;

    Preconditions : Source was created by CreateDateList
                    and not disposed.

    Postconditions : Source is unchanged and Target = Source.

    ------------------------------------------------------------------ *)


PROCEDURE CopyDateList( VAR Target : ADateList; Source : ADateList;
                             Speed : AnExtStoragePreference );
BEGIN

    IF (NOT CopyExtObject( Source, Speed, Target )) THEN
        Target := ADateList(NIL);
    END;

END CopyDateList;










(*---------------------------------------------------------------

    DateListsAreEqual 

    Purpose : Determines whether two DateLists are equivalent.

    Inputs:   A, B      : ADateList.

    Outputs:  TRUE iff each component of A is equal to the corresponding
              component of B.

    Preconditions : A and B were created by CreateDateList
                    and not disposed.

                    The data portions of each record are assumed to be
                    able to be compared byte for byte.  That is, if there
                    are any filler bytes (for alignment), they are assumed
                    to be initialized to a common value.

    Postconditions : A and B are unaffected.

    ------------------------------------------------------------------ *)


PROCEDURE DateListsAreEqual( A, B : ADateList ) : BOOLEAN;

VAR
    i,
    RecordsA,
    RecordsB       : CARDINAL;
    DateListArrayA,
    DateListArrayB : ADateListArrayPointer;
    Equal          : BOOLEAN;
BEGIN
    RecordsA := LockObject( A, DateListArrayA );
    RecordsB := LockObject( B, DateListArrayB );

    Equal := (RecordsA = RecordsB);
    
    i := 0;
    WHILE (Equal) AND (i < RecordsA) DO
        Equal := (DateListArrayA^[i] = DateListArrayB^[i]);
        INC(i);
    END;

    ReleaseUnchangedObject( A );
    ReleaseUnchangedObject( B );

    RETURN Equal;

END DateListsAreEqual;










    (*---------------------------------------------------------------

    GetDateListEntry 

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
              Data        : The data in effect during this period.
                            This is assumed to be the EXACT LENGTH of
                            one record.

	      RETURNS     : TRUE if this is a defined interval.  Else
                            returns FALSE.  Note: if period n is not 
                            defined, then periods n+i are undefined, for 
                            all i >= 0.

    Preconditions : RateList was created by CreateDateList and not disposed.
    ------------------------------------------------------------------ *)

PROCEDURE GetDateListEntry(     DateList     : ADateList;
                                N            : ADateListIndex;
                            VAR StartDate,
                                ThruDate     : ABigTime;
                            VAR Data         : ARRAY OF BYTE
                           ) : BOOLEAN;
VAR
    ArrayBytes,
    DataSize,
    Records       : CARDINAL;
    DateListArray : ADateListArrayPointer;
    TempData      : ARRAY [0..1] OF BYTE;
    ok            : BOOLEAN;
BEGIN
    DataSize   := HIGH(Data) + 1 + Overhead;

    ArrayBytes := LockObject( DateList, DateListArray );
    Records    := NumberOfElements( ArrayBytes, DataSize );

    ok := (N < Records);  (* Remember that the last rec is a sentinal *)

    ok := ok AND 
          Get( N,   DataSize, DateListArray, ArrayBytes, StartDate, Data ) AND
          Get( N+1, DataSize, DateListArray, ArrayBytes, ThruDate,  TempData );

    ReleaseUnchangedObject( DateList );

    RETURN ok;

END GetDateListEntry;










    (*---------------------------------------------------------------

    SetDateListEntryN 

    Purpose : Sets the Nth entry in a rate list.

    Inputs:   
              DateList    : ADateList;
              N           : The interval number.
              Data        : The data in effect during this period.
          
    Outputs:   
              RETURNS     : FALSE if too many intervals to record have
                            been defined.

    Preconditions : DateList was created by CreateDateList and not disposed.

    Postconditions: 
                    StartDate[N] and Rate[N] are set as passed in.
                    ThruDate[N] = StartDate[N+1].
    ------------------------------------------------------------------ *)

PROCEDURE SetDateListEntryN( VAR DateList : ADateList;
                                 N        : ADateListIndex;
                                 Data     : ARRAY OF BYTE
                           ) : BOOLEAN;
VAR
    ArrayBytes,
    DataSize,
    Records       : CARDINAL;
    MyStartDate   : ABigTime;
    DateListArray : ADateListArrayPointer;
    TempData      : ARRAY [0..255] OF BYTE;
    ok            : BOOLEAN;
BEGIN
    DataSize   := HIGH(Data) + 1 + Overhead;

    ArrayBytes := LockObject( DateList, DateListArray );
    Records    := NumberOfElements( ArrayBytes, DataSize );

    ok := (N < Records);  (* Remember that the last rec is a sentinal *)

    IF (ok AND
        Get( N, DataSize, DateListArray, ArrayBytes, MyStartDate, TempData )) THEN
        Set( N, DataSize, DateListArray, ArrayBytes, MyStartDate, Data );
    END;

    ReleaseObject( DateList );

    RETURN ok;

END SetDateListEntryN;













    (*---------------------------------------------------------------

    CreateDateListEntry 

    Purpose : Creates a new Nth entry in a date list.

    Inputs:   
              DateList    : ADateList;
              StartDate   : The date of the beginning of this period.
              Data        : The data in effect during this period.
          
    Outputs:   
              RETURNS     : The resulting date list index, or zero
                            if too many entries to record have
                            been defined.

    Preconditions : DateList was created by CreateDateList and not disposed.

    Postconditions: 
		    The total number of entries is not less than it was
                    before.
		    There is an entry n, with StartDate = the passed 
                    value, and same for Rate.  The next entry will
                    start with the Thru date.  This may split previous
                    records, or completely overlap a previous record.
		    General conditions on DateLists still obtain.
    ------------------------------------------------------------------ *)

PROCEDURE CreateDateListEntry( VAR DateList   : ADateList;
                                   StartDate  : ABigTime;
                                   Data       : ARRAY OF BYTE
                              ) : ADateListIndex;
VAR
    i,
    Index,
    ArrayBytes,
    DataSize,
    Records       : CARDINAL;
    MyStartDate   : ABigTime;
    DateListArray : ADateListArrayPointer;
    TempData      : ARRAY [0..255] OF BYTE;
BEGIN
    IF (DateList = ADateList(NIL)) THEN
        DateList := CreateDateList( Data, StartDate );
        RETURN 1;
    END;

    DataSize   := HIGH(Data)+1+Overhead;

    ArrayBytes := LockObject( DateList, DateListArray );
    Records    := NumberOfElements( ArrayBytes, DataSize );

    Index := 1;
    WHILE (Index < Records) AND  (* Last record is not "real" *)
          (Get( Index, DataSize, DateListArray, ArrayBytes, MyStartDate, TempData )) AND
          (CompareBigTimes( MyStartDate, StartDate) < 0) DO
        INC(Index);
    END;

    IF (CompareBigTimes( MyStartDate, StartDate ) <> 0) THEN

        ReleaseUnchangedObject( DateList );  DateListArray := NIL;

        (* Add a record if possible. *)

        IF (NOT SetExtSize( DateList, ArraySize( Records+1, DataSize ))) THEN
            RETURN 0;   (* No room *)
        END;

        ArrayBytes := LockObject( DateList, DateListArray );
        Records   := NumberOfElements( ArrayBytes, DataSize );

        FOR i := Records TO Index + 1 BY -1 DO
            IF (NOT Get( i-1, DataSize, DateListArray, ArrayBytes, MyStartDate, TempData )) THEN HALT; END;
            Set( i,   DataSize, DateListArray, ArrayBytes, MyStartDate, TempData );
        END;

    END;

    Set( Index, DataSize, DateListArray, ArrayBytes, StartDate, Data );

    ReleaseObject( DateList );

    RETURN Index;

END CreateDateListEntry;













    (*---------------------------------------------------------------

    DisposeDateListEntry 

    Purpose : Removes the new Nth entry in a date list.

    Inputs:   
              DateList    : ADateList;
              DataSize    : Size of the data portion, not incl. Start Date.
              N           : The interval number.
          
    Outputs:   

    Preconditions : DateList was created by CreateDateList and not disposed.

    Postconditions: 
                    All previous intervals N+j+1, for j > 0, will now
                    be numbered N+j.
		    The total number of intervals will be reduced by 1,
                    unless it was already 1.
                    ThruDate[i] always = StartDate[i+1] for all i > 0 where
                    i+1 is an entry.
    ------------------------------------------------------------------ *)

PROCEDURE DisposeDateListEntry( VAR DateList : ADateList;
                                    DataSize : CARDINAL;
                                    N        : ADateListIndex   );
VAR
    Records,
    ArrayBytes     : CARDINAL;
    DateListArray : ADateListArrayPointer;
    StartDate     : ABigTime;
    Data          : ARRAY [0..255] OF BYTE;
    ok            : BOOLEAN;
BEGIN
    INC(DataSize,Overhead);

    ArrayBytes := LockObject( DateList, DateListArray );
    Records    := NumberOfElements( ArrayBytes, DataSize );

    ok := (N < Records);  (* Remember that the last rec is a sentinal *)
    IF (ok) THEN
        IF (Records = 2) THEN
            ReleaseUnchangedObject( DateList );
            DiscardExtObject(       DateList );
            RETURN; (* All records deleted. *)
        ELSE
            WHILE (Get( N+1, DataSize, DateListArray, ArrayBytes, StartDate, Data )) DO
                Set(    N,   DataSize, DateListArray, ArrayBytes, StartDate, Data );
                INC(N);
            END;
        END;
    END;

    ReleaseObject( DateList );

    ok := (ok AND
           SetExtSize( DateList, ArraySize( Records-1, DataSize )));

END DisposeDateListEntry;












    (*---------------------------------------------------------------

    LocateDateInDateList 

    Purpose : Given a Date, finds the index number, N, of the half-open
              interval [StartDate..ThruDate) containing Date.

    Inputs:   DateList       : A DateList;
              Date           : A date.
              DataSize       : Size of the data portion, not incl. Start Date.

    Outputs:  
   	      N           :  Index to the interval containing Date.
                         If 0, then there is no interval containing the
                         date.  That is, the date is less than the date
                         of the first entry.


    Preconditions : RateList was created by CreateRateList and not disposed.
                    Date is within the range of the calendar. 

    Postconditions: N is returned as noted above. 
    ------------------------------------------------------------------ *)


PROCEDURE LocateDateInDateList(    DateList   : ADateList;
                                   Date       : ABigTime;
                                   DataSize   : CARDINAL;
                               VAR N          : ADateListIndex);
VAR
    Records,
    ArrayBytes     : CARDINAL;
    DateListArray  : ADateListArrayPointer;
    StartDate      : ABigTime;
    Junk           : ARRAY [0..1] OF BYTE;
BEGIN

    INC(DataSize, Overhead);

    ArrayBytes := LockObject( DateList, DateListArray );
    Records    := NumberOfElements( ArrayBytes, DataSize ); (* 7/9/90 EGK *)

    N := 1;
    WHILE (N < Records) AND  (* Last record is not "real" *)
          (Get( N, DataSize, DateListArray, ArrayBytes, StartDate, Junk )) AND
          (CompareBigTimes(Date, StartDate) >= 0) DO    (* 4-Sep-90 RSC was > *)
        INC(N);
    END;

    DEC(N);

    ReleaseUnchangedObject( DateList );

END LocateDateInDateList;









    (*---------------------------------------------------------------

    Number Of Dates In List

    Purpose : Given a Date List, returns the number of entries in the list.

    Inputs:   DateList       : A DateList;
              DataSize       : Size of the data portion, not incl. Start Date.

    Outputs:  
   	          RETURN         : Number of entries.


    Preconditions : DateList was created by CreateDateList and not disposed.

    Postconditions: RETURN as noted above.

    ------------------------------------------------------------------ *)
PROCEDURE NumberOfDatesInList(  DateList   : ADateList;
                                DataSize   : CARDINAL  ) : CARDINAL;
VAR
    Records       : CARDINAL;
    DateListArray : ADateListArrayPointer;
BEGIN

    Records := LockObjectArray( DateList, DateListArray, DataSize + Overhead );
    ReleaseUnchangedObject( DateList );

    IF (Records > 0) THEN
        DEC(Records);       (* Remember, the last one does not exist. *)
    END;

    RETURN Records;

END NumberOfDatesInList;












PROCEDURE StoreDateList(     DateList    : ADateList;
                             StorageProc : Filing.AStoreProc;
                             Context     : ADDRESS );
VAR
    Size          : CARDINAL;
    DateListArray : ADateListArrayPointer;
BEGIN
    IF (DateList = ADateList(NIL)) THEN
        StorageProc(NIL,0,Context);
    ELSE
        Size := LockObject( DateList, DateListArray);
        StorageProc(DateListArray,Size,Context);
        ReleaseUnchangedObject( DateList );
    END;
END StoreDateList;








PROCEDURE LoadDateList ( VAR DateList    : ADateList;
                             StoragePref : AnExtStoragePreference;
                             PredictSize : Filing.APredictSizeProc;
                             LoadProc    : Filing.ALoadProc;
                             ReadNext    : Filing.AReadNextProc;
                             Context     : ADDRESS
                        ) : BOOLEAN;
VAR
    P          : ADDRESS;
    MaxSize,
    ActualSize : CARDINAL;
    ok         : BOOLEAN;
BEGIN
    ok := FALSE;

    ActualSize := PredictSize(Context);
    IF (GetExtStatus() = ExtGood) AND
       (CreateExtObjectWithSize( DateList, ExtMedium, ActualSize )) THEN
        MaxSize := LockObject(   DateList, P );
        LoadProc(P,MaxSize,ActualSize,Context);
        ReleaseObject(   DateList );
        ok := TRUE;
    END;

    RETURN ok;

END LoadDateList;





END DateLists.


