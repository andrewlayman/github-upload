IMPLEMENTATION MODULE ObjectID;

VAR
    Count           : INTEGER;



PROCEDURE NewID () : INTEGER;
BEGIN
    INC (Count);
    RETURN Count;
END NewID;



PROCEDURE InitializeIDs ( Num : INTEGER );
BEGIN
    Count := Num;
END InitializeIDs;



BEGIN
    Count := 0;
END ObjectID.
