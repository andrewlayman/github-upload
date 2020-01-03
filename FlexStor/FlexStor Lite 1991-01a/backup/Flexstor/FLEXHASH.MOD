IMPLEMENTATION MODULE FlexHash;


FROM FlexStor IMPORT AnExtHandle;
FROM FatalErr IMPORT FatalError;



VAR
    InitIndex : CARDINAL;







    (* LocateTableIndex -- Look in the HashTable for the Handle.
           If found, return its index and set Found to TRUE.
           Otherwise, Found is FALSE, and returns the index of
           an empty location, if one exists. *)


PROCEDURE LocateTableIndex(     Handle : AnExtHandle;
                           VAR Found : BOOLEAN) : CARDINAL;
VAR
    i,j, EmptySlot : CARDINAL;
    EmptyFound     : BOOLEAN;
BEGIN
    Found := FALSE;
    EmptyFound := FALSE;
    EmptySlot := 0;

        (* Not really hashing.  Exhaustive search for now! *)

    FOR i := 0 TO HIGH(HashTable) DO
        IF (HashTable[i].Handle = Handle) THEN
            Found := TRUE;
            RETURN i;
        END;
        IF (NOT EmptyFound) AND (HashTable[i].Handle = AnExtHandle(NIL)) THEN
            EmptySlot := i;
            EmptyFound := TRUE;
        END;
    END;

    RETURN EmptySlot;
END LocateTableIndex;



PROCEDURE AddToTable( TheHandle : AnExtHandle; VAR i : CARDINAL ):BOOLEAN;
VAR
    Found : BOOLEAN;
BEGIN
    i := LocateTableIndex(TheHandle,Found);
    IF (NOT Found) THEN
        WITH HashTable[i] DO
            IF (Handle = AnExtHandle(NIL)) THEN
                Handle := TheHandle;
            ELSE
                (* No empty space. *)
                FatalError();
            END;
        END;
    ELSE
        FatalError();
    END;

    RETURN TRUE;
END AddToTable;







BEGIN
       (* Init statistics keepers. *)

    OutstandingLocks       := 0;
    MostOutstandingLocks   := 0;
    TotalLocksEver         := 0L;
    Hits                   := 0L;
    Misses                 := 0L;
    MaxBytesInMemory       := 0L;
    MaxLockedBytesInMemory := 0L;
    MemoryFlushNotices     := 0L;

        (* Init the records of retained records. *)

    Clock              := 0;
    ItemsInMemory      := 0;
    BytesInMemory      := 0L;
    LockedBytesInMemory:= 0L;


    FOR InitIndex := 0 TO HIGH(HashTable) DO
        WITH HashTable[ InitIndex ] DO
            Handle := AnExtHandle(NIL);
            Loc    := NIL;
            Size   := 0;
            Locks  := 0;
            Time   := 0;
            Dirty  := FALSE;
        END;
    END;

    (* Set rules *)

    MaxBytesToKeep := 16384L;   (* Over and above locked items. *)

END FlexHash.
