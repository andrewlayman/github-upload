IMPLEMENTATION MODULE FlexHash;


FROM FlexData IMPORT ACellInfo;
FROM FlexStor IMPORT AnExtHandle;
FROM Space    IMPORT Available, ALLOCATE, DEALLOCATE;
FROM SYSTEM   IMPORT ADDRESS, TSIZE;


CONST
    Null = 0;                   (* Null link. *)


VAR
    InitIndex : CARDINAL;
    UnusedRecords : CARDINAL;   (* Head of a list of unused records. *)




    (* Allocates space in a special heap used for flexstor.  
       If no space, fails and halts program. *)

PROCEDURE AllocateSpace( VAR Where : ADDRESS; Size : CARDINAL);
BEGIN
    ALLOCATE(Where,Size);
END AllocateSpace;


PROCEDURE DeAllocateSpace( VAR Where : ADDRESS; Size : CARDINAL);
BEGIN
    DEALLOCATE(Where,Size);
END DeAllocateSpace;


PROCEDURE SpaceAvailable( Size : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN Available(Size);
END SpaceAvailable;






(*$S-*) (*$R-*) (*T-*)

PROCEDURE Hash( TheHandle : AnExtHandle ) : CARDINAL;
VAR
    A : ADDRESS;
BEGIN
    A := ADDRESS(TheHandle);
    RETURN (A.OFFSET + A.SEGMENT) MOD HashTableSize;
END Hash;

(*$S=*) (*$R=*) (*T=*)


PROCEDURE Search(     TheHandle : AnExtHandle;
                  VAR HashTableIndex : CARDINAL;
                  VAR HashRecordIndex : CARDINAL  ) : BOOLEAN;
BEGIN
    HashTableIndex := Hash(TheHandle);
        (* Get the top of the chain. *)
    HashRecordIndex := HashTable[ HashTableIndex ];
        (* Search the chain for the record with the Handle in it. *)
    WHILE (HashRecordIndex <> Null) DO
        WITH HashRecords[ HashRecordIndex ] DO
            IF (Handle = TheHandle ) THEN
                RETURN TRUE;
            END;
            HashRecordIndex := Next;
        END;
    END;
    RETURN FALSE;
END Search;




    (* LocateTableIndex -- Look in the HashRecords for the Handle.
           If found, return its index and TRUE.
           Otherwise, RETURN FALSE.
     *)

PROCEDURE LocateRecordIndex(     Handle : AnExtHandle;
                             VAR HashRecordIndex : CARDINAL) : BOOLEAN;
VAR
    HashTableIndex : CARDINAL;
BEGIN
    RETURN Search(Handle,HashTableIndex,HashRecordIndex);
END LocateRecordIndex;



PROCEDURE AddToTable( TheHandle : AnExtHandle; VAR i : CARDINAL ):BOOLEAN;
VAR
    HashTableIndex : CARDINAL;
BEGIN
    IF NOT Search(TheHandle,HashTableIndex,i) THEN
            (* Get a new HashRecord. *)
        i := UnusedRecords;
        IF (i <> Null) THEN
            UnusedRecords := HashRecords[ UnusedRecords ].Next;
        ELSE
            (* No empty space. *)
            RETURN FALSE;
        END;
        WITH HashRecords[ i ] DO
                (* Fill in the handle. *)
            Handle := TheHandle;
                (* Link to table. *)
            Next   := HashTable[ HashTableIndex ];
        END;
        HashTable[ HashTableIndex ] := i;
        RETURN TRUE;
    END;

    RETURN FALSE;
END AddToTable;


    (* Removes Handle from the hash tables. *)

PROCEDURE RemoveFromTable( TheHandle : AnExtHandle );
VAR
    i, Last,HashRecordIndex : CARDINAL;
    HashTableIndex : CARDINAL;
BEGIN
    IF Search(TheHandle,HashTableIndex,HashRecordIndex) THEN
        i := HashTable[ HashTableIndex ];
        IF (i=HashRecordIndex) THEN
            (* The record is at the start of the chain. *)
            HashTable[ HashTableIndex ] := HashRecords[ i ].Next;
        ELSE
            (* Search the chain again for the record. *)
            REPEAT
                Last := i;
                i    := HashRecords[ i ].Next;
            UNTIL (i = HashRecordIndex);
            (* Remove the record from the chain. *)
            HashRecords[ Last ].Next := HashRecords[ i ].Next;
        END;
            (* Put the freed record on the unused list. *)
        WITH HashRecords[ i ] DO
            Next := UnusedRecords;
            Handle := AnExtHandle(NIL);
        END;
        UnusedRecords := i;
    END;
END RemoveFromTable;






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


        (* Empty the HashTable. *)

    FOR InitIndex := 0 TO HIGH(HashTable) DO
        HashTable[ InitIndex ] := Null;
    END;

        (* Link all the HashRecords into a list, terminated by Null,
           which must = 0, and put them into the UnusedRecords list. *)

    FOR InitIndex := 1 TO HIGH(HashRecords) DO
        WITH HashRecords[ InitIndex ] DO
            Next := InitIndex-1;
            Handle := AnExtHandle(NIL);
        END;
    END;
    UnusedRecords := HIGH(HashRecords);


    (* Set rules *)

    MaxBytesToKeep := 16384L;   (* Over and above locked items. *)

END FlexHash.
