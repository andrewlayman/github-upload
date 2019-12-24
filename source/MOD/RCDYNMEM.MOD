IMPLEMENTATION MODULE RcDynMem;

(*  =========================================================================
    Last Edit : January 29, 1991 5:38PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This is a newer version of DynMem and BTDynMem.  It has the advantage
        that it does NOT use one word of memory on each side of data items
        like its forefathers.  It also does not require that the "Block"
        have an OFFSET of 0, or that the block size be < MaxInt (it can
        be any CARDINAL number of bytes).


        All entries are relative to the block's base address.  The base
        address is not stored in the block, so the block may be relocated
        anywhere, or even paged out to "external storage".

        One note, though.  If you MOVE a block, I assume that the base OFFSET
        is unchanged.  That is, it is always either 0 or some other
        non-changing number.  So, typicly, movable blocks have offset 0,
        while some non-movable blocks (like HMA) can have non-0 offsets.


    MODIFICATION HISTORY:

    RSC 28-Jan-91 First version, with interface from DynMem and BTDynMem.

    =========================================================================
*)

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, TSIZE, SIZE,
    (* PROC *)                  ADR;



TYPE
    AFreeEntryIndex = CARDINAL;

        (* The free list is ordered by ascending index,
           with the exception that the last entry has a NextFreeEntry of 0.
        *)
    ABlockHeaderRec     = RECORD
        FreeBlockSize   : CARDINAL;  (* Largest possible free size. *)
        HintSize        : CARDINAL;  (* To speed up free list searches *)
        HintIndex       : CARDINAL;
        HintPriorIndex  : CARDINAL;
        FreeListHead    : AFreeEntryIndex;
    END;

CONST
    MaxDataEntries      = 32767 - (TSIZE(ABlockHeaderRec) DIV 2);

TYPE
        (* Data and free entries are stored here.  The Data array is
           a CARDINAL array for ease of dealing with the free list.
        *)
    ABlock              = POINTER TO RECORD
        Header          : ABlockHeaderRec;
        Data            : ARRAY [0..MaxDataEntries-1] OF CARDINAL;
    END;

        (* Here are the free entry offsets in the array.  Given any
           base index for a free entry, add these constants to the
           base index and that yields the item wanted.

           The compiler will tend to optimize these constants, especially
           the "0".
        *)
CONST
    SizeOfFreeEntry = 0;
    NextFreeEntry   = 1;

    NumberOfWordsInAFreeEntry = 2; (* Words it takes to make a free entry. *)

    NillNextFreeEntry = MaxDataEntries;  (* Means "end of free list" *)



(* Block is any valid address, including HMA addresses of FFFF:10.
   Size  is any number of bytes, greater than about 2 bytes.
*)
PROCEDURE InstallDynMem( Block : ABlock; Size : CARDINAL );
VAR
    A   : ADDRESS;
BEGIN
    IF (Size < (TSIZE(ABlockHeaderRec) + (NumberOfWordsInAFreeEntry * 2))) THEN
        HALT;
    END;

    Size := Size DIV 2;  (* Make it a size in words *)

    WITH Block^ DO
        WITH Header DO
            HintSize        := 0;
            HintIndex       := 0;
            HintPriorIndex  := 0;
            A               := ADR(Data);
            FreeBlockSize   := Size - (TSIZE(ABlockHeaderRec) DIV 2);
            FreeListHead    := 0;  (* The first index is free! *)
        END;

        Data[0+SizeOfFreeEntry] := Header.FreeBlockSize;
        Data[0+NextFreeEntry  ] := NillNextFreeEntry;

    END;
END InstallDynMem;






PROCEDURE FindSize(     Block       : ABlock;
                        Size        : CARDINAL;
                    VAR Found,
                        Prior       : AFreeEntryIndex );
BEGIN
    WITH Block^ DO
        WITH Header DO
            Found := FreeListHead;
            Prior := NillNextFreeEntry;

            IF (Size = HintSize) THEN
                Found := HintIndex;
                Prior := HintPriorIndex;
            ELSE
                WHILE (Found <> NillNextFreeEntry)           AND
                      (Data[Found + SizeOfFreeEntry] < Size)  DO
                    Prior := Found;
                    Found := Data[Found + NextFreeEntry];
                END;
            END;
        END;
    END;
END FindSize;






(* Allocate "Adr" of "Size" bytes from block Block.  Block must have been
   given to InstallDynMem before.  Adr may be returned as NIL if there
   is not enough space.
*)
PROCEDURE Alloc( Block : ABlock; VAR Adr : ADDRESS; Size : CARDINAL );
VAR
    Prior,
    Next,
    Where       : AFreeEntryIndex;
BEGIN
    Size := (Size + 1) DIV 2;  (* Make size an even number of words. *)
    IF (Size <  NumberOfWordsInAFreeEntry) THEN
        IF (Size = 0) THEN
            Adr := Block;   (* Well, I can't return NIL! *)
            RETURN;
        END;
        Size := NumberOfWordsInAFreeEntry;
    END;


    FindSize( Block, Size, Where, Prior );

    IF (Where = NillNextFreeEntry) THEN
        Adr := NIL;
    ELSE
            (* We found a chunk of memory at least large enough to hold
               the record.  Now, if the free entry is large enough to hold
               both the data record and another free record, then put the
               data address at the high end of the free entry, and keep the
               free entry pointer where it is.  Otherwise, take the free
               entry out of the list of free entries by setting the prior
               (or list head) to point to this entry's next entry (which
               may be nil).

               The "NumberOfWordsInAFreeEntry" is how many words it takes
               to describe a free entry.  If there would be, say, 1 word
               left after allocation, we give the extra two bytes to
               the data item and hope that the data compaction algorithem
               takes care of reclaiming the space.
            *)
        WITH Block^ DO
            DEC(Data[Where+SizeOfFreeEntry],Size);
            Next := Where + Data[Where+SizeOfFreeEntry];
            Adr  := ADR(Data[Next]);
            IF (Data[Where+SizeOfFreeEntry] < NumberOfWordsInAFreeEntry) THEN
                Next := Data[Where+NextFreeEntry];
                IF (Prior = NillNextFreeEntry) THEN
                    Header.FreeListHead := Next;
                ELSE
                    Data[Prior+NextFreeEntry] := Next;
                END;
            END;
            Header.HintSize := 0; (* Forget any hint we had found. *)
        END;
    END;

END Alloc;






(* DeAlloc a chunk of memory that had been returned from Alloc.
   Size MUST be the same as the size passed to Alloc.
   Adr will be returned as NIL.
   RETURN is TRUE if the block is now completely empty.
*)
PROCEDURE DeAlloc(     Block : ABlock;
                   VAR Adr   : ADDRESS;
                       Size  : CARDINAL ): BOOLEAN;
VAR
    A       : ADDRESS;
    Prior,
    Next,
    Target  : AFreeEntryIndex;


        (* Collapse Adjacent Blocks

            Before --> After --> Next(or NIL).

            IF Before and After are adjacent,
                Make Before --> Next
                Make Before's size = Before's Size + After's Size.

            "Adjacent" means within a tolerance of NumberOfWordsInAFreeEntry,
            because that is how much we could have allocated extra to a block.
            No block could ever get less than that amount.

            Because of this, we always recompute the size of the free entry
            of the collapsed block, rather than just Incrementing the size
            by the size of After.
        *)
    PROCEDURE Collapse( Before, After : AFreeEntryIndex );
    VAR
        NewIndex : AFreeEntryIndex;
    BEGIN
        WITH Block^ DO
            NewIndex := Before + Data[Before + SizeOfFreeEntry];
            IF ((NewIndex + NumberOfWordsInAFreeEntry) >= After) THEN
                Data[Before + SizeOfFreeEntry] :=
                    ((After - Before) + Data[After + SizeOfFreeEntry]);
                Data[Before + NextFreeEntry] := Data[After + NextFreeEntry];
            ELSE
                Data[Before + NextFreeEntry] := After;
            END;
        END;
    END Collapse;

BEGIN
    Size := (Size + 1) DIV 2;  (* Make size an even number of words. *)
    IF (Size <  NumberOfWordsInAFreeEntry) THEN
        IF (Size = 0) THEN
            Adr := NIL;
            RETURN FALSE;
        END;
        Size := NumberOfWordsInAFreeEntry;
    END;

    A      := ADR(Block^.Data);
(*    IF (A.SEGMENT <> Adr.SEGMENT) OR (A.OFFSET > Adr.OFFSET) THEN*)
(*        HALT;*)
(*    END;*)

    Target := (Adr.OFFSET - A.OFFSET) DIV 2;    (* Index into the data area *)

    WITH Block^ DO
        Next   := Header.FreeListHead;
        Prior  := NillNextFreeEntry;
        WHILE (Next <> NillNextFreeEntry)  AND
              (Next <  Target)             DO
            Prior := Next;
            Next  := Data[Next + NextFreeEntry];
        END;
        Header.HintSize := 0;  (* In case we collapse free space. *)
    END;

    (* Now, Prior is before Target which is before Next.

        Actually, Prior and/or Next could be NIL.

        First, take the client's data address and set up the data area
        as a free entry.

        Then, attempt to collapse non-nil entries togeather.
    *)
    WITH Block^ DO
        Data[Target+NextFreeEntry]   := Next; (* Could be NillNextFreeEntry *)
        Data[Target+SizeOfFreeEntry] := Size;
    END;

    IF (Next <> NillNextFreeEntry) THEN
        Collapse( Target, Next );
    END;

    IF (Prior <> NillNextFreeEntry) THEN
        Collapse( Prior, Target );
    ELSE
        WITH Block^ DO
            IF (Target > 0) AND (Target < NumberOfWordsInAFreeEntry) THEN
                Data[0] := Data[Target];
                Data[1] := Data[Target+1];
                Target  := 0;
            END;
            Header.FreeListHead := Target;
        END;
    END;

    Adr    := NIL;

    WITH Block^ DO
        RETURN (Header.FreeListHead = 0) AND
               (Data[0+SizeOfFreeEntry] = Header.FreeBlockSize);
    END;

END DeAlloc;






(* Avail returns TRUE iff Block can hold Size bytes.
   Block must have been passed to InstallDynMem.
*)
PROCEDURE Avail( Block : ABlock; Size : CARDINAL ): BOOLEAN;
VAR
    Prior,
    Where           : AFreeEntryIndex;
BEGIN
    Size := (Size + 1) DIV 2;  (* Make size an even number of words. *)
    IF (Size < NumberOfWordsInAFreeEntry) THEN
        IF (Size = 0) THEN
            RETURN TRUE;
        END;
        Size := NumberOfWordsInAFreeEntry;
    END;

    FindSize( Block, Size, Where, Prior );

    WITH Block^.Header DO
        HintIndex      := Where;
        HintPriorIndex := Prior;
        HintSize       := Size;
    END;

    RETURN (Where <> NillNextFreeEntry);

END Avail;




(* How many blocks of SizeToCount are free in Block.
*)
PROCEDURE CountOfFree(    Block         : ABlock;
                          SizeToCount   : CARDINAL)
                                                       : CARDINAL;
VAR
    Found       : AFreeEntryIndex;
    Size,
    TotalSize   : CARDINAL;
BEGIN
    IF (SizeToCount = 0) THEN HALT; END;

    TotalSize := 0;

    WITH Block^ DO
        Found := Header.FreeListHead;

        WHILE (Found <> NillNextFreeEntry) DO
            Size := Data[Found + SizeOfFreeEntry] * 2;
            IF (Size >= SizeToCount) THEN
                INC(TotalSize, Size DIV SizeToCount );
            END;
            Found := Data[Found + NextFreeEntry];
        END;
    END;

    RETURN TotalSize;

END CountOfFree;




END RcDynMem.


