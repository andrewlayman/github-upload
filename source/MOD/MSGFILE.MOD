    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)
    (*V3=DEBUG*)

IMPLEMENTATION MODULE MsgFile;

(*  =========================================================================
    Last Edit : August 2, 1990 1:36PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
       1/28/86   AJL - Set MessagesInTable to 0 in initialization
                       so that the table starts out as empty until
                       it is initialized.
                     - Interlock around the attempt to open the file.
                     - On a call that happens before we are ready,
                       return "?" instead of halting.
       24 Jul 86 AJL - Add more calls to PrepareForIO.
       07/25/86 LAA     Added LoadAllLockedMessages to load them into storage
                        when a file is opened.  Also changed the default
                        phrases file name to TLPHRASE.DAT.
       11/12/86 LAA     Added calls to PrepareForIO in several places.
        7/14/87 RSC     Optimize loading locked messages and deleting excess
                        messages.
        9/31/87 EGK     Don't remove locked messages in ReleaseMessageEntries
                        even if (All) is TRUE.
       01-Dec-87 LAA    Minor changes to fix low memory behavior.
       02-Feb-88 LAA    Removed import of Space (it wasn't used).
       18-Feb-88 RSC    Improved stats gathering.
       19-Feb-88 LAA    MsgComp now stores the message address as the file
                        offset DIV 2, so we had to change this for that.  
                        Turned range checking off so we don't get an overflow
                        when multipling it by 2.
       22-Feb-88 LAA  - Force stack checking on for this module.
       27-Sep-88 RSC  - Speed and size changes.  Mostly size.
                        1) Don't keep the index in memory, but keep an index
                           of the index in memory.
                        2) Shrink the cache, but try to put the same number
                           of messages in it.  Use the FlexStor page management
                           routines to do this.
        4-Oct-88 RSC  - Incorporated FlexPage rather than DynMem.
        3-Feb-89 EGK  - Keep track of number of valid entries in the master
                        index and valid size of last index block.  This ensures
                        that SearchList is given the correct range for all index
                        blocks, including the last one, and removes the
                        requirement that unused entries be filled with
                        MAXCARDINALs.
        6-Mar-89 RSC  - Reflect new statistics gathering.
       10-Mar-89 RSC  - The cache list was being destroyed, causing Time Line
                        to loop or die when in the RTD.  May have fixed that.
                        I guess we'll see.  Also, while examining this in the
                        RTD I discovered that locked messages could be
                        significantly slowing down the message cache, as they
                        must be skipped over in our ruthless search for more
                        space in the cache.  I added another list to the cache
                        just to hold locked messages.
       21-Apr-89 EGK  - Addr is now the file position DIV 4.  Defined
                        "AddrScale" constant in case we need to change this
                        again sometime.  (A phrase file bigger than 256K?
                        Surely you jest, Shirley!)
       17-May-89 RSC  - Raised the limit of # of phrases to 4096.

       14-Jul-89 RSC  - New phrase file organization.  Kept the cache, but
                        reorganized the rest of the file handling.
                        The cache had to updated to accomidate CLASSES.

       16-Aug-89 WKH  - Disable Message Cache system for OS/2

       29-Aug-89 WKH  - Split-up complex boolean test into simpler
                        intermediate variables so we can get a better handle
                        on why we fail when we do.

                        New system:

                            Phrases all belong to a CLASS, such as STANDARD,
                            or FORMS.  All the old calls are supported, but
                            the assumed class is STANDARD, or "1".

        3-Jul-90 AJL  - Rephrase the initialization code to avoid overflow
                        traps when range checking is on.

        2-Aug-90 RSC  - Added CACHE and NOCACHE toggles.  Set CACHE to
                        off by default.  This will perhaps slow things down,
                        but will save 7+ KB from the root.

    =========================================================================
*)

FROM CRC16          IMPORT
    (* PROC *)          CheckSum;

FROM Dialog         IMPORT
    (* PROC *)          FatalError, Message, Error;

FROM DOSIO          IMPORT
    (* TYPE *)          ADOSFileHandle, AnAccessType,
    (* PROC *)          DOSOpen, DOSRead, DOSClose;

FROM DOSMemory      IMPORT
    (* PROC *)          DOSAlloc;

FROM FileAux        IMPORT
    (* VAR *)           TextPath;

FROM FileOpen       IMPORT
    (* PROC *)          RequestFileFind;

(*<DOS*)
FROM FlexData       IMPORT
    (* TYPE *)          APage, APageNo, ARecordNo;

FROM FlexPage       IMPORT
    (* PROC *)          InitializePage, DataAddress, SizeOfRecord,
                        PageHasRoomFor, AddRecordToPage,
                        RemoveRecordFromPage, SqueezePage;
(*DOS>*)

FROM GaGa           IMPORT
    (* PROC *)          GetGaGaMessage;

FROM LStrings       IMPORT
    (* PROC *)          LStringToTString, ConcatLS, SetString, Fill,
                        StoC, SetLengthOf, Insert, Remove, Search,
                        TrimFront, Upshift, Overlay, Copy, TrimRear,
                        StringsEqual, SubStr;

FROM Paranoia       IMPORT
    (* VAR *)           InitializationOK;

FROM ParmLine       IMPORT
    (* PROCS *)         GetOption;

FROM PhraseDefs     IMPORT
    (* CONST *)         PhraseFileName,         BlockSize,
    (* TYPE *)          ABlockNumber,           ADiskBlock,
                        AClassIndexHeader,      AMessageEntry,
                        ALockedMessageBlock,    AMessageIndexEntry,
                        AClassName,             APhraseFileHeader,
                        ADiskBlockHeader,       ADataBlockHeader,
                        AClassBlock,            AnOverflowIndexBlock;

FROM Space          IMPORT
    (* PROC *)          ALLOCATE;

FROM SYSTEM         IMPORT
    (* PROC *)          SIZE, TSIZE, ADR, ADDRESS, CODE, SETREG, CX;








CONST
    ModuleNumber         = 22200;  (* For GetGaGaMessage *)
    MAXCARDINAL          = 65535;
    MaxClasses           = 100;


TYPE
    AComparison          = (LessThan, Equal, GreaterThan);

    (* A Search Compare Proc is used by Search to determine how an entry
       in a table relates to the given index.  Passed is a CARDINAL within
       the bounds of the table (table bounds are 1..UserSpecifiedHighValue)
       and another cardinal as the record or key to compare to.  Returned is
       how the record compares.
    *)
    ASearchCompareProc   = PROCEDURE( CARDINAL,
                                      CARDINAL,
                                      CARDINAL ) : AComparison;



VAR
    CurrentDataBlock        : ADiskBlock;
    CurrentDataBlockRecNum  : CARDINAL;

    (* Each of these cardinals contains the highest message number for the
       block its index refers to.  In other words, element 23 of this array
       contains the highest phrase number in data block 23.
       This array is allocated dynamicly to be 1..NumberOfMessageBlocks.
    *)
    HighMessages            : POINTER TO ARRAY [1..(MAXCARDINAL DIV 2)] OF CARDINAL;
    NumberOfMessageBlocks   : CARDINAL;

    NumberOfClassEntries    : CARDINAL;
    ClassList               : POINTER TO ARRAY [1..MaxClasses] OF AClassIndexHeader;

    MessageFile             : ADOSFileHandle;
    MessageFileName         : ARRAY [0..13] OF CHAR;
    Interlock               : BOOLEAN;
    FileCurrentlyOpen       : BOOLEAN;


  (* This GLOBAL array is here to save stack space.  IT IS ONLY TO BE USED
     BY "ReadMessageText".
  *)
    FullText                : ARRAY [0..255] OF CHAR; (* Full 256 bytes *)

  (* This GLOBAL array is here to save stack space.  IT IS ONLY TO BE USED
     BY "ConcatMessage" OR "DisplayMessage".
  *)
    ConcatOrDisplayText     : ARRAY [0..255] OF CHAR;













           (* ======== Module MessageCache ========== *)

   (* Cache messages frequently used or locked.

      Cache:
            This is a doubly linked list of entries, each with the message
            key and message text.  When a message is accessed, it is linked
            in at the top of the list.  Messages are deleted from the tail
            of the list.

            There is a "Free" list and an "InUse" list.

            The list is not linked via addresses, but via indexes into
            the array of possible entries.  This makes each pointer only
            one word, and not two.  It also avoids dynamic memory allocation.

            The actual text of the cached messages is stored in a pre-allocated
            buffer.  This avoides using "Allocate", which could cause heap
            fragmentation.

            In this version, the buffer management is done with our very own
            FlexPage module, which manages a single buffer of data.

            To speed up the search of the cache (when looking for a particular
            Message key), we keep a sorted list of indexes.  That is, an array
            of numbers that index into the linked list.  When we delete an
            element from the linked list, we delete the corresponding entry
            from the sorted list.  When we add an item to the list, we insert
            the appropriate entry in sorted order.  All this searching is done
            with our generic "Search" routine, which does a BINARY search.

            In this implementation, to speed up the insert/delete times into
            the "CacheSearch" array of sorted indexes, we use an LString.
            This arrangement lets me reuse other code and should cut down
            on insert/delete time.  This limits the cache size to 255 entries.
   *)

MODULE MessageCache;

(*<CACHE
(*<DOS*)
IMPORT
        (* CONST *)     MAXCARDINAL,
        (* TYPE  *)     AComparison, ASearchCompareProc,
                        APage, APageNo, ARecordNo,
        (* VARS  *)     InitializationOK, DOSAlloc,
        (* PROCS *)     SearchList, FatalError, Copy, TSIZE, StoC, GetOption,
                        InitializePage, DataAddress, SizeOfRecord, SetString,
                        PageHasRoomFor, AddRecordToPage,
                        RemoveRecordFromPage, SqueezePage, ConcatLS,
                        ADR, CX, CODE, SETREG, ADDRESS, SetLengthOf;
(*DOS>*)
CACHE>*)


EXPORT 
        (* PROCS *)     GetMessageFromCache, AddToCache;

(*<CACHE
(*<DOS*)
CONST
        CacheSize             = 377C;  (* Seperate entries to be tracked.
                                          CAN NEVER BE GREATER THAN 255!!
                                          Includes LOCKED messages. *)
        MaxSizeToFitInCache   = 250;   (* Width more than this, don't bother.  *)

        LockedList            = 0C;    (* Start of Locked messages in "Cache" *)
        InUseList             = 1C;    (* Start of InUseList in "Cache" *)
        FreeList              = 2C;    (* Start of FreeList  in "Cache" *)
                               (* MUST BE JUST BEFORE FREE SPACE.  SEE INIT. *)


        LStringRecOverhead    = 1;  (* KEEP IN SYNCH WITH AnLStringRec, below... *)
TYPE
        ACacheIndex     = CHAR;
        AnLString       = ARRAY [0..255] OF CHAR;
        AnLStringRec    = POINTER TO RECORD             (* KEEP IN SYNCH WITH *)
                              LString      : AnLString; (* LStringRecOverhead, above. *)
                          END;                          (* Length byte + str len *)

        ACacheEntry     = RECORD
                              Next,
                              Prior         : ACacheIndex;  (* For linked list *)
                              MessageNumber : CARDINAL;     (* key to message  *)
                              MessageClass  : CARDINAL;     (* key to message  *)
                              Message       : ARecordNo;    (* Where text is.  *)
                          END;

        ACache          = ARRAY ACacheIndex OF ACacheEntry;

VAR
        CacheBufferAddress : POINTER TO APage;
        Cache              : ACache;
        CacheSearch        : ARRAY ACacheIndex OF CHAR; (* Search list *)

        CacheNotInitialzed : BOOLEAN;
(*DOS>*)
CACHE>*)



(*<CACHE
(*<DOS*)
    (* See if the indicated message key is in the cache. *)

PROCEDURE CompareCacheEntries( Where, LookingFor, Class : CARDINAL ) : AComparison;
VAR
    ThisEntryKey,
    ThisEntryClass  : CARDINAL;
BEGIN
    WITH Cache[ CacheSearch[ CHR(Where) ] ] DO
        ThisEntryKey    := MessageNumber;
        ThisEntryClass  := MessageClass;
    END;

    IF (Class < ThisEntryClass) THEN
        RETURN LessThan;
    ELSIF (Class > ThisEntryClass) THEN
        RETURN GreaterThan;
    END;

    IF (LookingFor < ThisEntryKey) THEN
        RETURN LessThan;
    ELSIF (LookingFor > ThisEntryKey) THEN
        RETURN GreaterThan;
    END;

    RETURN Equal;

END CompareCacheEntries;





    (* Takes an existing node and links it in at the top of the cache,
       delinking it from where it is now.  This can move from list to list.

       Does not affect the "CacheSearch" array.  The caller must change that
       array if the item is being moved to a different list!
    *)
PROCEDURE MoveToTopOfCache( ListHead, Where : ACacheIndex );
VAR
    OldFront : ACacheIndex;
BEGIN
    (* Remove it from where it is. *)

    OldFront              := Cache[Where].Next;
    Cache[OldFront].Prior := Cache[Where].Prior;
    Cache[Cache[Where].Prior].Next := OldFront;

    (* Add it to the front of the list.... *)

    OldFront              := Cache[ListHead].Next;
    Cache[Where].Next     := OldFront;
    Cache[Where].Prior    := ListHead;
    Cache[OldFront].Prior := Where;
    Cache[ListHead].Next  := Where;

END MoveToTopOfCache;



CONST
    REPNZ    = 0F2H;
    MOVSB    = 0A4H;
    LDS      = 0C5H;
    LES      = 0C4H;
    SIviaBP  = 76H;
    DIviaBP  = 7EH;


    (* From Logitek's FileSystem module. *)

(*$T-*)   (* RSC 10-Mar-89 *)
(*$R-*)
PROCEDURE MoveBlock (src, dest: ADDRESS; count: CARDINAL);
BEGIN
    CODE (LDS, SIviaBP,10);
    CODE (LES, DIviaBP,6);
    SETREG (CX, count);
    CODE (REPNZ, MOVSB);
END MoveBlock;
(*$R=*)
(*$T=*)




  (* Remove the key from the cache search (sorted) list.

        Preconditions  : MessageKey  Message to remove (key of).
                                     Message MUST BE ON THE InUse LIST!

        Postconditions : Removed from the search list.
  *)
PROCEDURE RemoveCacheSearchEntry( MessageKey, MessageClass : CARDINAL );
VAR
    CCacheEntry : CARDINAL;
    LastEntry,
    CacheEntry  : ACacheIndex;
BEGIN
    LastEntry   := CacheSearch[0C]; (* Size of cache search array *)
    CacheEntry  := LastEntry;
    CCacheEntry := ORD(CacheEntry);
    IF (NOT SearchList( CompareCacheEntries, MessageKey, MessageClass, CCacheEntry )) THEN
        FatalError();  (* Must be there! *)
    END;
    CacheEntry := CHR(CCacheEntry);

    IF (LastEntry > CacheEntry) THEN

        (* Let assembler help us. *)

        DEC( LastEntry, CCacheEntry );

        MoveBlock( ADR(CacheSearch[ CHR(CCacheEntry+1) ]),
                   ADR(CacheSearch[      CacheEntry ]),
                   ORD(LastEntry) );

    END;

    DEC(CacheSearch[0C]); (* Fewer bytes in the array. *)

END RemoveCacheSearchEntry;





  (* Insert the key into the cache search (sorted) list.

        Preconditions  : MessageKey - Message to add.
                         Where      - Where to point in the list.  MUST BE
                                      LESS THAN 256!
                                Must not already be in the CacheSearch list.

        Postconditions : added to the search list.
  *)
PROCEDURE InsertCacheSearchEntry( MessageKey, Class : CARDINAL; Where : ACacheIndex );
VAR
    CCacheEntry : CARDINAL;
    i, j,
    LastEntry,
    CacheEntry  : ACacheIndex;
BEGIN
    LastEntry  := CacheSearch[0C]; (* Size of cache search array *)
    CacheEntry := LastEntry;
    IF (CacheEntry > 0C) THEN
        CCacheEntry := ORD(CacheEntry);
        IF (SearchList( CompareCacheEntries, MessageKey, Class, CCacheEntry )) THEN
            FatalError();  (* Must NOT be there! *)
        END;
        CacheEntry := CHR(CCacheEntry);
    END;

    (* Since it failed, the entry returned is the one JUST BELOW where to add
       the new entry.  If at the end of the string, that is easy.
    *)

    INC(CacheEntry); (* Where we WANT this entry to go. *)

    IF (CacheEntry <= LastEntry) THEN
        (* Copy the bytes.  Don't use the "MoveBlock" routine, as we are
           copying UP, rather than DOWN.  A Modified "MoveBlock" could work.
        *)
        FOR i := LastEntry TO CacheEntry BY -1 DO
            j := i;
            INC(j);
            CacheSearch[j] := CacheSearch[i];
        END;
    END;

    CacheSearch[ CacheEntry ] := Where;
    INC(CacheSearch[0C]); (* One more byte in the array. *)

END InsertCacheSearchEntry;






    (* Delete the LString from the cache buffer, and
       remove the entry from the list.  Put it on the free list.

       Remove the entry from the CacheSearch list too!
    *)

PROCEDURE DeleteMessageFromCache( Where : ACacheIndex );
BEGIN

    WITH Cache[Where] DO
        RemoveCacheSearchEntry( MessageNumber, MessageClass );
        RemoveRecordFromPage( CacheBufferAddress^, Message );
    END;

    MoveToTopOfCache( FreeList, Where );

END DeleteMessageFromCache;



    (* Get an entry onto the TOP of the InUseList.
       Take the entry from the free list if any free.
       Get entry from the tail of the InUseList if none free.
       GUARENTEE ENOUGH ROOM FOR "SizeNeeded" bytes in the
       cache buffer!!  (If 0, that is easy.)

       Return the entry number.
    *)
PROCEDURE GetFreeEntry( SizeNeeded : CARDINAL ) : ACacheIndex;
VAR
    Where,
    Tail  : ACacheIndex;
BEGIN
    (* There are two parts to this.  The first is to secure a
       node for us to return.  The second is to secure SizeNeeded
       bytes in the cache buffer.
    *)

    IF (Cache[FreeList].Next = FreeList) THEN (* No free space. *)
        Where := Cache[InUseList].Prior; (* LAST IN THE CHAIN. *)
        IF (Where = InUseList) THEN
            FatalError();   (* Cache full of LOCKED messages. *)
        END;                (* No room for normal messages!   *)
        DeleteMessageFromCache( Where ); (* Puts it on the FREE LIST *)
    END;

    Where := Cache[FreeList].Next;
    MoveToTopOfCache( InUseList, Where ); (* Goes to the top of InUse list. *)

    IF (SizeNeeded = 0) THEN
        RETURN Where;
    END;

    (* Find space.  Delete anyone in our way. *)

    IF (NOT PageHasRoomFor( CacheBufferAddress^, SizeNeeded )) THEN
        SqueezePage( CacheBufferAddress^ );
        WHILE (NOT PageHasRoomFor( CacheBufferAddress^, SizeNeeded )) DO
            Tail := Cache[InUseList].Prior;
            IF (Tail = Where) THEN FatalError(); END; (* NO ROOM AT THE INN *)
            DeleteMessageFromCache( Tail );
            SqueezePage( CacheBufferAddress^ );
        END;
    END;

    RETURN Where;

END GetFreeEntry;
(*DOS>*)
CACHE>*)








 (* Add To Cache - Add a message (newly read) into the cache.

        Preconditions  - The message must not already be in the cache.
                         "Resident" is true iff this message can never be removed
                         from the cache.
        Postconditions - The message has been added to the cache, possibly
                         forcing another message out.
 *)
PROCEDURE AddToCache( MessageKey,
                      Class       : CARDINAL;
                      Resident    : BOOLEAN;
                  VAR MessageText : ARRAY OF CHAR );
(*<CACHE
(*<DOS*)
VAR
    LStringRec : AnLStringRec;
    Length     : CARDINAL;
    Where      : ACacheIndex;
(*DOS>*)
CACHE>*)

BEGIN
(*<CACHE
(*<DOS*)    
    IF (CacheNotInitialzed) THEN
        InitCache();
    END;

    Length := ORD(MessageText[0]); (* Len of JUST THE TEXT *)
    IF (Length <= MaxSizeToFitInCache) OR (Resident) THEN
        INC( Length, LStringRecOverhead );
        Where  := GetFreeEntry( Length ); (* Get an entry *)

        IF (NOT AddRecordToPage( CacheBufferAddress^, Cache[Where].Message, Length )) THEN
            FatalError();  (* There is supposed to be enough room. *)
        END;

        WITH Cache[Where] DO
            MessageNumber := MessageKey;
            MessageClass  := Class;
            LStringRec    := DataAddress( CacheBufferAddress^, Message );
        END;
        Copy( MessageText, LStringRec^.LString );
        InsertCacheSearchEntry( MessageKey, Class, Where );
        IF (Resident) THEN
            MoveToTopOfCache( LockedList, Where ); (* Goes to the top of Locked list. *)
        END;                                       (* RSC 10-Mar-89 *)
    END;
(*DOS>*)
CACHE>*)
END AddToCache;







 (* Get Message From Cache - Get a message from the cache.

        Preconditions  - MessageKey is the key into the message index.
        Postconditions - The message is copied from where it was to the
                         caller's string area.  The cache is updated
                         to reflect the access.  That is, the message
                         moves to the top of the list.
                         or else FALSE is returned.
 *)
PROCEDURE GetMessageFromCache(     MessageKey,
                                   Class        : CARDINAL;
                               VAR MessageText  : ARRAY OF CHAR ) : BOOLEAN;
(*<NOCACHE
(*<DOS*)
VAR
    CCacheEntry : CARDINAL;
    LStringRec  : AnLStringRec;
    CacheEntry  : ACacheIndex;
    ok          : BOOLEAN;
(*DOS>*)
NOCACHE>*)

BEGIN
(*<CACHE
(*<DOS*)
    IF (CacheNotInitialzed) THEN
        InitCache();
    END;

    MessageText[0] := 0C;

    CacheEntry  := CacheSearch[0C];    (* Size of cache search array *)
    CCacheEntry := ORD(CacheEntry);

    ok := SearchList( CompareCacheEntries, MessageKey, Class, CCacheEntry );
    IF (ok) THEN
        CacheEntry := CHR(CCacheEntry);
        LStringRec := DataAddress( CacheBufferAddress^, Cache[ CacheSearch[ CacheEntry ] ].Message  );
        Copy( LStringRec^.LString, MessageText );
    END;

    RETURN ok;
(*DOS>*)
CACHE>*)

(*<NOCACHE*)
    RETURN FALSE;
(*NOCACHE>*)

(*<OS2
    RETURN FALSE;
OS2>*)
END GetMessageFromCache;




(*<CACHE
(*<DOS*)
PROCEDURE InitCache();
VAR
    Index,
    CacheBufferSize     : CARDINAL;
    i, j, k             : ACacheIndex;
    Option, Param       : ARRAY [0..79] OF CHAR;
    Found               : BOOLEAN;

BEGIN
  (* Initially, they are ALL free.  Note that this algorithem DEPENDS ON
     "FreeList" being the last list header, and being before any of the
     items that should be on the free list.  RSC 10-Mar-89.
  *)

    FOR i := FreeList TO CacheSize DO
          (*$R-*)   (* Turn off range checking.  We will overflow. *)
        j := i;
        INC(j);
        k := i;
        DEC(k);
          (*$R=*)
        WITH Cache[i] DO
            Next          := j;
            Prior         := k;
            MessageNumber := 0;
            MessageClass  := 0;
            Message       := 0;
        END;
    END;

    Cache[CacheSize].Next  := FreeList;
    Cache[FreeList].Prior  := CacheSize;

    WITH Cache[InUseList] DO        (* was not being initted. RSC 10-Mar-89 *)
        Next          := InUseList;
        Prior         := InUseList;
        MessageNumber := 0;
        MessageClass  := 0;
        Message       := 0;
    END;

    WITH Cache[LockedList] DO       (* Added this.  RSC 10-Mar-89 *)
        Next          := LockedList;
        Prior         := LockedList;
        MessageNumber := 0;
        MessageClass  := 0;
        Message       := 0;
    END;

    CacheBufferSize       := 4096;  (* Default cache buffer size. *)
    SetString( Option, "MCACHE" );
    GetOption( Option, Found, Param );
    IF Found THEN
        Index             := 1;
        CacheBufferSize   := StoC( Param, Index );
        IF (CacheBufferSize <  1024) THEN
            CacheBufferSize := 1024;  (* Min size 1 KB *)
        END;
        IF (CacheBufferSize > 20000) THEN
            CacheBufferSize := 20000;  (* Max size 20 KB *)
        END;
    END;

    CacheBufferSize := CacheBufferSize DIV 16;  (* MAKE INTO PARAGRAPHS *)
    DOSAlloc( CacheBufferAddress, CacheBufferSize );

    InitializePage( CacheBufferAddress^, (CacheBufferSize * 16), 1 );

    CacheNotInitialzed := FALSE;

END InitCache;
(*DOS>*)
CACHE>*)


BEGIN  (* MODULE MessageCache *)
(*<CACHE
(*<DOS*)
    CacheNotInitialzed := TRUE;
    SetLengthOf( CacheSearch, 0 ); (* Nothing on the list yet. *)
(*DOS>*)
CACHE>*)
END MessageCache;

           (* ======== End Module MessageCache ========== *)




    (* SearchList -- Search a sorted table for a record with a key.
            Do a binary search.

         Preconditions:  Entries are in sorted order.
                         Compare : Passed procedure to do test.
                         Context : Passed intact to "Compare".
                         Last    : High value of list.
         Postconditions: Last    : Entry item was found at, or
                                   Entry JUST LESS THAN value.
                         RETURN is TRUE if found, FALSE if Last > value.
    *)
PROCEDURE SearchList( Compare   : ASearchCompareProc;
                      Context1,
                      Context2  : CARDINAL;
                  VAR Last      : CARDINAL ): BOOLEAN;
VAR
    LowBound,
    Target   : CARDINAL;
BEGIN
    LowBound := 1;

    REPEAT
        Target := (LowBound + Last) DIV 2;

        CASE Compare( Target, Context1, Context2 ) OF
          LessThan    : Last     := Target - 1;
        | Equal       : Last     := Target;
                        RETURN TRUE;           (* Found! *)
        | GreaterThan : LowBound := Target + 1;
        ELSE
            FatalError();
        END;
    UNTIL (LowBound > Last);

    RETURN FALSE;

END SearchList;







PROCEDURE ReadBlock(     RecordNumber   : CARDINAL;
                         WhereToPutIt   : ADDRESS   );
TYPE
    AMythicalDiskBlock = RECORD
        Header  : ADiskBlockHeader;
        Rest    : ARRAY [1..(BlockSize - TSIZE(ADiskBlockHeader))] OF CHAR;
    END;
VAR
    DiskBlockPtr   : POINTER TO AMythicalDiskBlock;
    ChecksumValue  : CARDINAL;
    EOF            : BOOLEAN;
    ReadSuccessful : BOOLEAN;
    BlocksMatch    : BOOLEAN;
    CheckSumsMatch : BOOLEAN;
    EverythingCool : BOOLEAN;

BEGIN
    DiskBlockPtr   := WhereToPutIt;
    EverythingCool := TRUE;

    (* 29-Aug-89 WKH *)
    ReadSuccessful := DOSRead( MessageFile, RecordNumber, WhereToPutIt, EOF );

    IF (ReadSuccessful) THEN

        IF (NOT EOF) THEN
            BlocksMatch := DiskBlockPtr^.Header.BlockNumber = RecordNumber;

            IF (BlocksMatch) THEN
                ChecksumValue  := CheckSum( ADR(DiskBlockPtr^.Rest),SIZE(DiskBlockPtr^.Rest) );
                CheckSumsMatch := DiskBlockPtr^.Header.CRC16Checksum = ChecksumValue;

                IF (NOT CheckSumsMatch) THEN
                    EverythingCool := FALSE;
                END;

            ELSE
                EverythingCool := FALSE;
            END;

        ELSE
            EverythingCool := FALSE;
        END;

    ELSE
        EverythingCool := FALSE;
    END;

    IF (NOT EverythingCool) THEN
        GetGaGaMessage( ModuleNumber + 2, ConcatOrDisplayText ); (* "Can't read message file!" *)
        Error( ConcatOrDisplayText );
        FatalError();
    END;

END ReadBlock;








(*  OpenTheFile -- Open the file if possible.
*)
PROCEDURE OpenTheFile() : BOOLEAN;
VAR
    i, j,
    Len,
    FirstLockedBlock,
    LastLockedBlock     : CARDINAL;
    ClassBlock          : AClassBlock;
    PathFoundIn,
    Description         : ARRAY [0..99] OF CHAR;
    FileFoundIn         : ARRAY [0..19] OF CHAR;
    EOF                 : BOOLEAN;


    PROCEDURE ReadOtherIndexBlocks(     OverflowIndexBlock,
                                        PositionToStart,
                                        TotalIndexEntries   : CARDINAL );
    VAR
        i               : CARDINAL;
        OverflowBlock   : AnOverflowIndexBlock;
    BEGIN
        WHILE (OverflowIndexBlock <> 0) DO
            (*<DEBUG*)
            IF (PositionToStart > TotalIndexEntries) THEN
                FatalError();
            END;
            (*DEBUG>*)
            ReadBlock( OverflowIndexBlock, ADR(OverflowBlock) );

            WITH OverflowBlock DO
                i := 1;
                WHILE (i <= HIGH(HighMessageNumber))            AND
                      (PositionToStart <  TotalIndexEntries)    DO
                    INC(PositionToStart);
                    HighMessages^[PositionToStart] := HighMessageNumber[i];
                    INC(i);
                END;
                OverflowIndexBlock := NextIndexBlock;
            END;
        END;
    END ReadOtherIndexBlocks;


    PROCEDURE LoadAllLockedMessages(     FirstLockedBlock,
                                         LastLockedBlock    : CARDINAL );
    VAR
        i               : CARDINAL;
        LockedBlock     : ALockedMessageBlock;
        s               : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (FirstLockedBlock > 0) THEN
            FOR i := FirstLockedBlock TO LastLockedBlock DO
                ReadBlock( i, ADR(LockedBlock) );
                WITH LockedBlock DO
                    FOR j := 1 TO NumberOfMessages DO
                        WITH LockedMessages[j] DO
                            ReadMessageText( MessageNumber, MessageClass,       s );
                            AddToCache(      MessageNumber, MessageClass, TRUE, s );
                        END;
                    END;
                END;
            END;
        END;
    END LoadAllLockedMessages;


BEGIN

    Interlock := TRUE;

    GetGaGaMessage( ModuleNumber + 1, Description ); (* "TimeLine RUN DISK" *)
    FileCurrentlyOpen := RequestFileFind( TextPath,
                                          MessageFileName,
                                          Description,
                                          PathFoundIn,
                                          FileFoundIn );
    IF (FileCurrentlyOpen) THEN
        ConcatLS( PathFoundIn, FileFoundIn );
        FileCurrentlyOpen := DOSOpen( PathFoundIn,
                                      MessageFile,
                                      OpenReadOnly,
                                      BlockSize );
    END;

    IF (FileCurrentlyOpen) THEN
        ReadBlock( 1, ADR(ClassBlock) );
        WITH ClassBlock DO
            WITH PhraseFileHeader DO
                IF (TimeLineVersion <> 400) THEN  (* We only know 400. *)
                    GetGaGaMessage( ModuleNumber + 3, ConcatOrDisplayText ); (* "Wrong version of file.  Not compiled properly." *)
                    Error( ConcatOrDisplayText );
                    FatalError();  (* Wrong version, or not compiled properly. *)
                END;
                FirstLockedBlock := FirstLockedMsgBlk;
                LastLockedBlock  := LastLockedMsgBlk;


                (* Allocate space for the class list and the index of blocks.
                *)
                NumberOfClassEntries  := NumberOfClasses;
                IF (NumberOfClassEntries > MaxClasses) THEN
                    FatalError();
                END;
                Len                   := TSIZE(AClassIndexHeader);
                IF (ODD(Len)) THEN
                    INC(Len);
                END;
                ALLOCATE( ClassList, (NumberOfClassEntries * Len) );
                FOR i := 1 TO NumberOfClassEntries DO
                    ClassList^[i] := ClassIndexes[i];
                END;

                NumberOfMessageBlocks := TotalIndexEntries;
                ALLOCATE( HighMessages, (NumberOfMessageBlocks * TSIZE(CARDINAL)) );


                (* Load up all the index entries; they may span several index blocks.
                   (in practice, this is not likely, but, well, you know how we hate to
                   have limits!)
                *)
                j := 0;
                i := FirstMessageSlot;
                WHILE (i <= HIGH(HighMessageNumber)) AND
                      (j <  TotalIndexEntries)       DO
                    INC(j);
                    HighMessages^[j] := HighMessageNumber[i];
                    INC(i);
                END;
                ReadOtherIndexBlocks( NextIndexBlock, j, TotalIndexEntries );
            END;
        END;

        (* Now load all the "locked" messages.
        *)
        Interlock := FALSE;  (* Turn off the interlock before here .... *)
        LoadAllLockedMessages( FirstLockedBlock, LastLockedBlock );
    END;

    Interlock := FALSE;

    RETURN FileCurrentlyOpen;
    
END OpenTheFile;





    (* OpenMsgFile -- Start the MsgFile module, or, if
                      already started, deallocate all phrase
                      storage and start anew. *)



PROCEDURE OpenMsgFile( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    IF (FileCurrentlyOpen) THEN
        FatalError();
    END;

    IF (FileName[0] > 0C) THEN
        Copy( FileName, MessageFileName );
    END;

    RETURN (OpenTheFile());

END OpenMsgFile;










(* Search the master block index for the item.
*)
PROCEDURE MasterIndexSearch( Where, Base, LookingFor : CARDINAL ) : AComparison;
VAR
    ThisEntryNumber : CARDINAL;
BEGIN
    ThisEntryNumber := HighMessages^[(Where + Base) - 1];

    IF (LookingFor < ThisEntryNumber) THEN
        RETURN LessThan;
    ELSIF (LookingFor > ThisEntryNumber) THEN
        RETURN GreaterThan;
    END;

    RETURN Equal;

END MasterIndexSearch;




(* Search the current data block for the item.
*)
PROCEDURE BlockIndexSearch( Where, Base, LookingFor : CARDINAL ) : AComparison;
VAR
    ThisEntryNumber : CARDINAL;
BEGIN
    ThisEntryNumber := CurrentDataBlock.BlockIndex[Where].MessageNumber;

    IF (LookingFor < ThisEntryNumber) THEN
        RETURN LessThan;
    ELSIF (LookingFor > ThisEntryNumber) THEN
        RETURN GreaterThan;
    END;

    RETURN Equal;

END BlockIndexSearch;





(* ReadMessageText -- Read the message text from the file.
                      Does a REAL read, not a cached read.
                      Uses the INDEX to determine where the record is.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is returned.  It could be
                      empty.

    Input Parameters    - MessageNumber is the desired message key.
                          MessageClass  is a valid message class.

    Output Parameters   - MessageText   is the message text.
*)
PROCEDURE ReadMessageText(     MessageNumber,
                               MessageClass : CARDINAL;
                           VAR MessageText  : ARRAY OF CHAR );
VAR
    WhereFound,
    BlockToLookAt   : CARDINAL;
    LStringPtr      : POINTER TO ARRAY [0..255] OF CHAR;
BEGIN
    IF (MessageClass = 0) OR
       (MessageClass > NumberOfClassEntries) THEN
        FatalError();
    END;

    SetLengthOf( MessageText, 0 );

    WITH ClassList^[ MessageClass ] DO
        BlockToLookAt := (LastIndexEntry - FirstIndexEntry) + 1;
        IF (NOT SearchList( MasterIndexSearch, FirstIndexEntry,
                            MessageNumber, BlockToLookAt )) THEN
            INC(BlockToLookAt); (* Bump up to the block containing the item. *)
        END;
        INC( BlockToLookAt, FirstIndexEntry ); (* Skip the index block, so. *)
    END;                                       (* the FIRST block is # 2.   *)

    IF (BlockToLookAt <> CurrentDataBlockRecNum) THEN
        ReadBlock( BlockToLookAt, ADR(CurrentDataBlock) );
        CurrentDataBlockRecNum := BlockToLookAt;
    END;

    WhereFound := CurrentDataBlock.DataBlockHeader.IndexEntriesInUse;
    IF (SearchList( BlockIndexSearch, 0 (* junk here *),
                    MessageNumber,    WhereFound )) THEN
        WITH CurrentDataBlock DO
            LStringPtr := ADR( BlockBytes[ BlockIndex[WhereFound].MessageOffset ] );
            ConcatLS( MessageText, LStringPtr^ );
        END;
    END;

END ReadMessageText;









(*  Get Message For Class    Read a message from the message file.

        Given a message number, retrieve a message of the desired class.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is returned.  It could be
                      empty.

    Input Parameters    - MessageNumber is the desired message key.
                          MessageClass  is a valid message class.

    Output Parameters   - Message       is the message text.
*)
PROCEDURE GetMessageForClass(     MessageNumber,
                                  MessageClass  : CARDINAL;
                              VAR Message       : ARRAY OF CHAR);
VAR
    ok  : BOOLEAN;
BEGIN
    (* Don't allow recursive calls to us. *)
    (* Don't allow people to call us until we are initialized. *)

    IF (Interlock) OR (NOT FileCurrentlyOpen) THEN
        IF (Interlock) THEN
            SetLengthOf( Message, 0 );
            RETURN;
        ELSE
            Interlock := TRUE;  (* Prevent recursion here. *)
            FatalError();
        END;
    END;

    Interlock := TRUE;

    (* If we can find a reference to the message number, return
       the text. *)

    IF (NOT GetMessageFromCache( MessageNumber, MessageClass, Message )) THEN
        ReadMessageText(   MessageNumber, MessageClass, Message );
        AddToCache( MessageNumber, MessageClass, FALSE, Message );
    END;

    Interlock := FALSE;

END GetMessageForClass;





(*  Get Message     Read a message from the message file.

        Given a message number, retrieve a message of the class STANDARD.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is returned.  It could be
                      empty.

    Input Parameters    - MessageNumber is the desired message key.

    Output Parameters   - Message       is the message text.
*)
PROCEDURE GetMessage(     MessageNumber : CARDINAL;
                      VAR Message       : ARRAY OF CHAR);
BEGIN
    GetMessageForClass( MessageNumber, Standard, Message );
END GetMessage;









(* Concat Message For Class -- Concatenate the called for message text to
                               the end of the LString Text.  The message is read
                               from the class specified.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is returned.  It could be
                      empty.

    Input Parameters    - Text          is an LString, possibly empty.
                          MessageNumber is the desired message key.
                          MessageClass  is a valid message class.

    Output Parameters   - Text          has the message text appended onto it.
*)
PROCEDURE ConcatMessageForClass( VAR Text           : ARRAY OF CHAR;
                                     MessageNumber,
                                     MessageClass   : CARDINAL );
BEGIN
    GetMessageForClass( MessageNumber, MessageClass, ConcatOrDisplayText );
    ConcatLS( Text, ConcatOrDisplayText );
END ConcatMessageForClass;






(* Concat Message -- Concatenate the called for message text to
                     the end of the LString Text.  The message is read
                     from class STANDARD.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is returned.  It could be
                      empty.

    Input Parameters    - Text          is an LString, possibly empty.
                          MessageNumber is the desired message key.

    Output Parameters   - Text          has the message text appended onto it.
*)
PROCEDURE ConcatMessage( VAR Text          : ARRAY OF CHAR;
                             MessageNumber : CARDINAL );
BEGIN
    ConcatMessageForClass( Text, MessageNumber, Standard );
END ConcatMessage;






(* Display Message For Class -- Call the Message procedure to display the
                                called for text.  The message is read
                                from the class specified.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is displayed.  It could be
                      empty.

    Input Parameters    - MessageNumber is the desired message key.
                          MessageClass  is a valid message class.

    Output Parameters   - none.
*)
PROCEDURE DisplayMessageForClass(     MessageNumber,
                                      MessageClass   : CARDINAL );
BEGIN
    GetMessageForClass( MessageNumber, MessageClass, ConcatOrDisplayText );
    Message(                                         ConcatOrDisplayText );
END DisplayMessageForClass;







(* Display Message -- Call the Message procedure to display the
                      called for text.  The message is read
                      from class STANDARD.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - The appropriate message is displayed.  It could be
                      empty.

    Input Parameters    - MessageNumber is the desired message key.

    Output Parameters   - none.
*)
PROCEDURE DisplayMessage( MessageNumber : CARDINAL );
BEGIN
    DisplayMessageForClass( MessageNumber, Standard );
END DisplayMessage;




(* Find Class   -- Look for a class by name.

    Preconditions   - This module has been initialized.
                      The message file has been opened.

    Postconditions  - same.

    Input Parameters    - ClassName     is the name of the class to
                                           search for.  This is case
                                           insensitive.

    Output Parameters   - ClassNumber   is the found class number.
                                           Undefined if FALSE is returned.

                          RETURN        is TRUE iff the class name was
                                           found.
*)
PROCEDURE FindClass(     ClassName      : AClassName;
                     VAR ClassNumber    : CARDINAL      ) : BOOLEAN;
VAR
    LocalClassName  : AClassName;
BEGIN
    IF (NOT FileCurrentlyOpen) THEN
        FatalError();   (* Too early.  Come back later. *)
    END;

    Copy( ClassName, LocalClassName );
    TrimRear(  LocalClassName );
    TrimFront( LocalClassName );
    Upshift(   LocalClassName );

    ClassNumber := 1;
    WHILE (ClassNumber <= NumberOfClassEntries) AND
          (NOT StringsEqual( ClassList^[ClassNumber].ClassName, LocalClassName )) DO
        INC(ClassNumber);
    END;

    RETURN (ClassNumber <= NumberOfClassEntries);

END FindClass;







PROCEDURE InitMsgFile();
BEGIN

    SetString(MessageFileName, PhraseFileName );
    FileCurrentlyOpen       := FALSE;
    Interlock               := FALSE;
    CurrentDataBlockRecNum  := 0;

END InitMsgFile;





BEGIN
    InitMsgFile();
END MsgFile.

