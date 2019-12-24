IMPLEMENTATION MODULE Dictionary;


  (* Dictionary  - Implement a simple dictionary of items.

        > Multiple concurrent dictionaries can be active.
        > Provides "IS IT THERE?" and "FOR EACH ITEM" access.
        > Items are TreeNodes
        > Keys are any user-supplied LString.
        > Items can be added, but not removed.
        > The Number of items allowed is limited by FlexStor.
  *)

 (* RSC 4/14/88 initial version.
    RSC 9/14/88 Lowered required flexstor buffer size to <4KB.
    RSC 2-Jan-89  Changed references to Compare() to StringsEqual().
 *)

FROM CRC16       IMPORT
    (* PROCS *)         CheckSum;

FROM Dialog      IMPORT
    (* PROCS *)         FatalError;

FROM FlexStor    IMPORT
    (* TYPE  *)         AnExtHandle, AnExtStoragePreference,
    (* PROCS *)         CreateExtObjectWithSize, DiscardExtObject,
                        LockObject, ReleaseObject, ReleaseUnchangedObject;

FROM LStrings    IMPORT
    (* PROCS *)         StringsEqual;

FROM Space       IMPORT
    (* PROCS *)         ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM      IMPORT
    (* TYPES *)         ADR, TSIZE, SIZE, ADDRESS;

FROM TreeObjects IMPORT
    (* TYPES *)         ATreeNode;


 (* To implement the dictionary, we use a hash table.

    Each hash node contains a tree node of the item (or nil) and an
       index to the next hash node with the same hash function value (or 0).
 *)

CONST
    NoTable = 9999; (* flag for "table = no table" *)

TYPE
    AHashNode = RECORD
        DataNode  : ATreeNode; (* User supplied tree node *)
        NextPtr   : CARDINAL;  (* Index of NEXT item.     *)
    END;

CONST
    HashTableSize =  3400 DIV 6; (* TSIZE(FlexStorBuffer) DIV TSIZE(AHashNode) *)
    MaxHashTables = 15;    (* RSC 9/14/88 *)

TYPE
    AHashTable = POINTER TO ARRAY [1..HashTableSize] OF AHashNode;

    ADictionaryRecord = RECORD
        HashTables : ARRAY [0..MaxHashTables] OF AnExtHandle;
        LastTable  : CARDINAL;
        LastOffset : CARDINAL;
        GetIdProc  : AGetIdProc;
    END;

    ADictionary = POINTER TO ADictionaryRecord;  (* Invisible dictionary *)





 (* Create Hash Table

                Create one hash table record in FlexStor.  Initialize it.

        Preconditions  - HashTableHandle is an uninitialized ext handle.
        Postconditions - HashTableHandle is created and initted.
                         Else FALSE is returned.
 *)
PROCEDURE CreateHashTable( VAR HashTableHandle : AnExtHandle ) : BOOLEAN;
VAR
    i,
    Size        : CARDINAL;
    HashTable   : AHashTable;
    DefaultNode : AHashNode;
BEGIN
    IF (CreateExtObjectWithSize( HashTableHandle,
                                 ExtSlow,
                                 SIZE( HashTable^ ))) THEN
        IF (LockObject( HashTableHandle, HashTable ) <> SIZE( HashTable^ )) THEN
            FatalError; (* What?  Me worry? *)
        END;
        DefaultNode.DataNode := ATreeNode(NIL);
        DefaultNode.NextPtr  := 0;
        FOR i := 1 TO HashTableSize DO
            HashTable^[i] := DefaultNode;
        END;
        ReleaseObject( HashTableHandle );
        RETURN TRUE;
    END;
    RETURN FALSE;
END CreateHashTable;





 (* Create Dictionary

                Create a dictionary.

        Preconditions  - GetIdProc is a supplied procedure that, given a
                            tree node, returns an LString that is the KEY to
                            the dictionary.
        Postconditions - A Dictionary is created and returned to you.
 *)
PROCEDURE CreateDictionary( SGetIdProc : AGetIdProc ) : ADictionary;
CONST
    FudgeFactor = 2048;
VAR
    i          : CARDINAL;
    Dictionary : ADictionary;
BEGIN
    Dictionary := NIL;
    IF (Available( TSIZE( ADictionaryRecord ) + FudgeFactor)) THEN
        NEW( Dictionary );
        WITH Dictionary^ DO
            IF (CreateHashTable( HashTables[0] )) THEN
                LastTable  := 0;
                LastOffset := HashTableSize; (* Seed generating a new entry *)
                GetIdProc  := SGetIdProc;
                FOR i := 1 TO MaxHashTables DO
                    HashTables[i] := AnExtHandle( NIL );
                END;
            ELSE
                DISPOSE( Dictionary );
            END;
        END;
    END;
    RETURN Dictionary;
END CreateDictionary;



 (* Expunge Dictionary

                Eliminate the dictionary.

        Preconditions  - Dictionary must have been created.
        Postconditions - Dictionary is eliminated.
 *)
PROCEDURE ExpungeDictionary( VAR Dictionary : ADictionary );
VAR
    i : CARDINAL;
BEGIN
    IF (Dictionary <> NIL) THEN
        WITH Dictionary^ DO
            FOR i := 0 TO LastTable DO
                IF (ADDRESS( HashTables[i] ) <> NIL) THEN
                    DiscardExtObject( HashTables[i] );
                END;
            END;
        END;
        DISPOSE( Dictionary );
    END;
END ExpungeDictionary;






 (* Hash Offset

                Return the proper offset into the hash table
                (1..HashTableSize) for the given key.

        Preconditions  - Key is the LString.
        Postconditions - RETURN is a valid offset into the initial hash table.
 *)
PROCEDURE HashOffset( VAR Key : ARRAY OF CHAR ) : CARDINAL;
CONST
    HugePrime = 65521;
BEGIN
    RETURN ((CheckSum( ADR(Key), ORD(Key[0]) ) MOD HugePrime)
                                               MOD HashTableSize) + 1;
END HashOffset;



 (* Find Next Table

                Find the next table and offset into the table given
                then current table and offset.

        Preconditions  - Table and Offset are valid indexes into the
                             current hash table.
                         HashTable is the current hash table (locked)
        Postconditions - Table and Offset are updated for the NEW
                             hash table.  HashTable is unchanged.
 *)
PROCEDURE FindNextTable( VAR Table, Offset : CARDINAL;
                         VAR HashTable     : AHashTable );
VAR
    NextTable : CARDINAL;
BEGIN
    NextTable := HashTable^[Offset].NextPtr;
    IF (NextTable = 0) THEN
        Table  := NoTable;
        Offset := 0;
    ELSE
        Table  := ((NextTable - 1) DIV HashTableSize) + 1;
        Offset := ((NextTable - 1) MOD HashTableSize) + 1;
    END;
END FindNextTable;





 (* Add To Dictionary

                Add one item to the dictionary.  It may be a duplicate
                of an item allready in the dictionary.

        Preconditions  - Node is the tree node that, when supplied to the
                            dictionary's GetIdProc, yields an LString KEY.
                         Dictionary must have been created.
        Postconditions - Dictionary is updated and TRUE is returned.
                         FALSE is returned if the dictionary is too big
                         (FlexStor limitations, perhaps).
 *)
PROCEDURE AddToDictionary( Node       : ATreeNode;
                           Dictionary : ADictionary ) : BOOLEAN;
VAR
    Size,
    Offset    : CARDINAL;
    HashTable : AHashTable;
    DictKey   : ARRAY [0..255] OF CHAR;

    PROCEDURE Overflow();
    VAR
        HashTable2 : AHashTable;
    BEGIN
        WITH Dictionary^ DO
            Size := LockObject( HashTables[ LastTable ], HashTable2 );
            INC( LastOffset );
            HashTable2^[LastOffset] := HashTable^[Offset];
            HashTable^[Offset].NextPtr := ((LastTable - 1) * HashTableSize) + LastOffset;
            ReleaseObject( HashTables[ LastTable ] );
        END;
    END Overflow;

BEGIN
    IF (Dictionary <> NIL) THEN
        Dictionary^.GetIdProc( Node, DictKey );
        Offset   := HashOffset( DictKey );

        (* If the first entry is available, fill it.  If not, create a new
           entry, copy the first entry to it and link the new entry in as
           the first entry.
        *)
        Size := LockObject( Dictionary^.HashTables[ 0 ], HashTable );
        IF (HashTable^[Offset].DataNode <> ATreeNode( NIL )) THEN
            WITH Dictionary^ DO
                IF (LastOffset < HashTableSize) THEN
                    Overflow();
                ELSIF (LastTable < MaxHashTables)                 AND
                   (CreateHashTable( HashTables[ LastTable+1 ] )) THEN
                    INC(LastTable);
                    LastOffset := 0;
                    Overflow();
                ELSE
                    ReleaseUnchangedObject( HashTables[ 0 ] );
                    RETURN FALSE;
                END;
            END;
        END;
        HashTable^[Offset].DataNode := Node;
        ReleaseObject( Dictionary^.HashTables[ 0 ] );
        RETURN TRUE;
    END;
    RETURN FALSE;
END AddToDictionary;




 (* In Dictionary

                Search the dictionary for the given key.  Return the
                tree node associated with it or NIL.

        Preconditions  - Key is the key to search for.  It must EXACTLY match
                            the key in the tree node(s).
                         Dictionary must have been created.
        Postconditions - If found, the FIRST occurance's tree node is
                         returned.  If NOT FOUND, then NIL is returned.
 *)
PROCEDURE InDictionary(VAR Key        : ARRAY OF CHAR;
                           Dictionary : ADictionary ) : ATreeNode;
VAR
    Table,
    OldTable,
    Offset      : CARDINAL;
    FoundTree   : ATreeNode;
    HashTable   : AHashTable;
    Found       : BOOLEAN;

    PROCEDURE ExamineOneHashEntry( Table, Offset : CARDINAL;
                               VAR DataNode      : ATreeNode) : BOOLEAN;
    VAR
        Size      : CARDINAL;
        DictKey   : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (Table = NoTable) THEN
            DataNode := ATreeNode (NIL);
            RETURN FALSE;
        END;
        IF (Table <> OldTable) THEN
            IF (OldTable <> NoTable) THEN
                ReleaseUnchangedObject( Dictionary^.HashTables[OldTable] );
            END;
            Size     := LockObject( Dictionary^.HashTables[Table], HashTable );
            OldTable := Table;
        END;
        DataNode := HashTable^[Offset].DataNode;
        IF (DataNode = ATreeNode( NIL )) THEN
            RETURN FALSE;
        END;
        Dictionary^.GetIdProc( DataNode, DictKey );
        IF (NOT StringsEqual( Key, DictKey )) THEN
            DataNode := ATreeNode( NIL );
        END;
        RETURN (HashTable^[Offset].NextPtr <> 0) AND
               (DataNode = ATreeNode( NIL ));
     END ExamineOneHashEntry;

BEGIN
    FoundTree := ATreeNode( NIL );  (* Default return value *)
    IF (Dictionary <> NIL) THEN
        OldTable := NoTable;
        Table    := 0;
        Offset   := HashOffset( Key );

    (* Traverse the chain of hash entries, looking for the key we want. *)

        WHILE (ExamineOneHashEntry( Table, Offset, FoundTree )) DO
            FindNextTable( Table, Offset, HashTable );
        END;
        IF (OldTable <> NoTable) THEN
            ReleaseUnchangedObject( Dictionary^.HashTables[OldTable] );
        END;
    END;
    RETURN FoundTree;  (* Return what we did, or did not, find. *)
END InDictionary;




 (* For All Keys

                Call the user-supplied proc for each of the keys in the
                dictionary.  EACH TIME THE ForAllProc IS CALLED, ONE LOCK
                IS ALREADY IN EFFECT!!

        Preconditions  - Dictionary is the current dictionary
                         ForAllProc is the users proc called once with
                             each tree node in the dictionary.
                         Context is passed to the ForAllProc.
        Postconditions - ForAllProc has been called once for each node in
                             the dictionary.
 *)
PROCEDURE ForAllKeys  ( Dictionary : ADictionary;
                        ForAllProc : AForAllProc;
                        Context    : ADDRESS      );
VAR
    Size,
    Table,
    Limit,
    Offset    : CARDINAL;
    HashTable : AHashTable;
    Node        : ATreeNode;
BEGIN
    IF (Dictionary <> NIL) THEN
        WITH Dictionary^ DO
            FOR Table := 0 TO LastTable DO
                Size  := LockObject( HashTables[ Table ], HashTable );
                Limit := HashTableSize;
                IF (Table = LastTable) THEN
                    Limit := LastOffset;
                END;
                FOR Offset := 1 TO Limit DO
                    Node := HashTable^[Offset].DataNode;
                    IF (Node <> NIL) THEN
                        ForAllProc (Node, Context );
                    END;
                END;
                ReleaseUnchangedObject( HashTables[ Table ] );
            END;
        END;
    END;
END ForAllKeys;


END Dictionary.

