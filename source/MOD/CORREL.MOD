IMPLEMENTATION MODULE Correl;

    (* MODIFICATION HISTORY

       Dec. 10, 1989  AJL  -Original version.

       23-Sep-91      LAA   CreateCorrelationList was calling Available with
                            TSIZE of a pointer, instead of the record which
                            that pointer refers to.  This would sometimes 
                            cause ALLOCATE to fail.
    *)



FROM FatalErr   IMPORT 
    (* PROC *)         FatalError; 

FROM Kbio       IMPORT 
    (* TYPE *)         ascreenx, ascreeny, avidmode;

FROM Space      IMPORT 
    (* PROC *)         ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM     IMPORT
    (* PROC *)         TSIZE;



TYPE
    ARegion            = RECORD
                             ulx : ascreenx;
                             uly : ascreeny;
                             lrx : ascreenx;
                             lry : ascreeny;
                             Num : ARegionNumber;  
                         END;
 
    ACorrelationRecord = RECORD
                             Count  : CARDINAL; 
                             Region : ARRAY [1..MaximumRegionNumber] OF ARegion; 
                         END;

    ACorrelationList = POINTER TO ACorrelationRecord;


PROCEDURE CreateCorrelationList( ):ACorrelationList;
VAR
    List : ACorrelationList;
    i    : ARegionNumber;
BEGIN
    IF (Available(TSIZE(ACorrelationRecord))) THEN             (* 23-Sep-91 *)
        NEW( List );
        List^.Count := 0;
        RETURN List;
    ELSE
        RETURN NIL;
    END;
END CreateCorrelationList;




PROCEDURE DisposeCorrelationList( VAR CorrelationList : ACorrelationList );
BEGIN
        (* We cannot store anything into a NIL list.  Don't dump though.
           Merely returning allows a more graceful performance degredation,
           since the mouse will merely lose its command ability. *)
    IF (CorrelationList = NIL) THEN
        RETURN;
    END;

    DISPOSE(CorrelationList);
    CorrelationList := NIL;
END DisposeCorrelationList;



PROCEDURE SetRegion( CorrelationList : ACorrelationList;
                     RegionNumber : ARegionNumber;
                     ULX : ascreenx;
                     ULY : ascreeny;
                     LRX : ascreenx;
                     LRY : ascreeny  );
VAR
    i : CARDINAL;
BEGIN
        (* We cannot store anything into a NIL list.  Don't dump though.
           Merely returning allows a more graceful performance degredation,
           since the mouse will merely lose its command ability. *)
    IF (CorrelationList = NIL) THEN
        RETURN;
    END;


    WITH CorrelationList^ DO
        i := Count;
        INC(i);

        IF (i > HIGH(CorrelationList^.Region)) THEN    (* Programming error.  Too many regions. *)
            FatalError();
        END;
    
        WITH Region[ i ] DO
            ulx := ULX;
            uly := ULY;
            lrx := LRX;
            lry := LRY;
            Num := RegionNumber;
        END; 

        Count := i;
    END;
END SetRegion;

    (* ------------------------------------------------------------------

       QueryRegion --

       Purpose:  See if a region of the given number is in the list.
                 If so, return its dimensions.

       Input:    CorrelationList -- A list of regions created by use
                                    of CreateCorrelationList and SetRegion.
                 RegionNumber    -- Identifying number.

       Preconditions:  The correlation list cannot have been disposed of and 
                       should not be NIL.

       Output:   ULX             -- Upper left X coordinate.
                 ULY             -- Upper left Y coordinate.
                 LRX             -- Lower right X coordinate.
                 LRY             -- Lower right Y coordinate.
                 RETURNS         -- TRUE iff the list contains a region
                                    of the given number.  

       Error Action:    If the correlation list is NIL, FALSE is returned.

    -------------------------------------------------------------------- *)

PROCEDURE QueryRegion(     CorrelationList : ACorrelationList;
                           RegionNumber : ARegionNumber;
                       VAR ULX : ascreenx;
                       VAR ULY : ascreeny;
                       VAR LRX : ascreenx;
                       VAR LRY : ascreeny  ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
        (* Merely returning allows a more graceful performance degredation,
           since the mouse will merely lose its command ability. *)
    IF (CorrelationList = NIL) THEN
        RETURN FALSE;
    END;

    FOR i := 1 TO CorrelationList^.Count DO
        WITH CorrelationList^.Region[ i ] DO
            IF (Num = RegionNumber) THEN
                ULX := ulx;
                ULY := uly;
                LRX := lrx;
                LRY := lry;
                RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE;
END QueryRegion;




PROCEDURE CorrelatePoint (     CorrelationList : ACorrelationList;
                               X : ascreenx;
                               Y : ascreeny ) : ARegionNumber;
VAR
    RegionSet : ARegionSet;
BEGIN
    RETURN CorrelatePointMulti( CorrelationList, X, Y, RegionSet );
END CorrelatePoint;



PROCEDURE CorrelatePointMulti (     CorrelationList : ACorrelationList;
                                    X : ascreenx;
                                    Y : ascreeny;
                                VAR RegionSet : ARegionSet ) : ARegionNumber;
VAR
    i : CARDINAL;
    RegionNumber : ARegionNumber;
BEGIN
        (* We cannot store anything into a NIL list.  Don't dump though.
           Merely returning allows a more graceful performance degredation,
           since the mouse will merely lose its command ability. *)
    IF (CorrelationList = NIL) THEN
        RETURN 0;
    END;

    RegionSet := ARegionSet{};
    RegionNumber := 0;           (* Sentinal means not found. *)

    FOR i := 1 TO CorrelationList^.Count DO
        WITH CorrelationList^.Region[ i ] DO
            IF (ulx <= X) AND (X <= lrx) AND (uly <= Y) AND (Y <= lry) THEN
                IF (Num <= 15) THEN 
                    INCL(RegionSet,Num);
                END;
                RegionNumber := Num;
            END; 
        END;
    END;

    RETURN RegionNumber;
END CorrelatePointMulti;



END Correl.

