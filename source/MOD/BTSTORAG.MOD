    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(****************************************************************************

         MODULA-2    Library

                LOGITECH SA,   CH-1111 Romanel    (Switzerland)
                LOGITECH Inc,  Fremont, CA 94555  (USA)

   	 Module       : Storage - implementation for release 3.0

         Standard dynamic storage management

  	 Storage management for dynamic variables. Calls to the
  	 Modula-2 standard procedures NEW and DISPOSE are
  	 translated into calls to ALLOCATE and DEALLOCATE. The
  	 standard way to provide these two procedures is to
  	 import them from this module 'Storage'.


         Release :    3.0 - July 87

         Copyright (C)  1987 Logitech, All rights reserved

         Permission is hereby granted to registered users to use or abstract
         the following program in the implementation of customized versions.
         This permission does not include the right to redistribute the
         source code of this program.

         MODIFICATION HISTORY

         16-Dec-87 LAA   Make all allocations and deallocations even.
         17-Dec-87 LAA   When allocating a big block directly from DOSMemory,
                         allocate just the exact size necessary.  Otherwise,
                         a call to Available could return TRUE, but there
                         might not be that extra paragraph to allocate.
                         Used to be paraSize + 1.
                         Also check to see that allocation under memory
                         constrained conditions works ok.
         20-Jan-88 RSC   Added hooks for TLMagic.
         03-Feb-88 LAA   Create from Logitech Storage to implement the ability
                         to count heap free blocks.
         18-Feb-88 LAA   Available was still refusing to handle the
                         possibility of allocating a block of less than 16k,
                         even if there was DOS memory available.
         21-Sep-88 WKH   Changed MinBlockSize from 1000 paras to 1027 paras
                         ((4096 + 16) * 4) - 16) bytes.  Now, Available and
                         ALLOCATE will not allow use of a DOS block smaller
                         than MinBlockSize.
         28-Oct-88 LAA   Have to allocate DOS blocks < 16K if available, due
                         to interactions with Space.HeapAvailable.  They are
                         allocated in increments of 4096 bytes.
         07-Nov-88 LAA   Fixed a bug which would cause problems if you tried
                         to check availability for an allocation > 4K bytes,
                         when there was 4K left in DOS.  It wasn't checking
                         to see that the DOSAvailable was > the size being
                         asked for.  Also put in a (hopefully redundant)
                         check to be sure DOSAlloc returns NIL if there isn't
                         enough memory.

         09-Nov-88 RSC   Made the space allocations one para bigger, because
                         we found out that not only does DOSAlloc take a para,
                         but DOS itself takes a para.

          2-Aug-89 RSC   Made ALLOCATE and DEALLOCATE stealable vectors,
                         and removed the debugger support.  This makes the
                         procedures cleaner and will even make TLMagic cleaner.

          9-Jan-90 RSC   Sometimes, with records greater than 4KB, ALLOCATE
                         could return a RANDOM pointer.  IF There was enough
                         memory for the pointer, but less than Pointer Size
                         rounded up to the higher 4KB boundary.  Under those
                         conditions, Available returned TRUE, and ALLOCATE
                         returned a random number (not NIL).

         11-Jan-90 RSC   Minor fixes to get the above change to work.
         16-Aug-90 RSC   Incredibly, DEALLOCATE did not set the pointer to
                         NIL.
         29-Jan-91 RSC   Changed BTDynMem and DynMem to RCDynMem, to get
                         the new, slower, but more compact heap manager
                         (does not waste two words via a boundary tag
                         system).  It saves 4 bytes per allocated item,
                         but, alas, takes longer to deallocate items.
                         And is not as-yet assemblerized.

  *****************************************************************************)

IMPLEMENTATION MODULE BTStorage;

(*
Storage description :
===================

87.02.18

blockList_RTSMain --->|-----------------|
                      | nextBlockSeg :  |  segment pointer to next block
                      |-----------------|
                      | prevBlockSeg :  |  segment pointer to previous block
                      |-----------------|
                      | nextProcessBlk: |  I'm not sure what these are - LAA
                      |-----------------|
                      | prevProcessBlk: |
                      |-----------------|
                      | BlockSize :     |  block size in paragraphs
                      |-----------------|
                      | dynamic :       |  boolean telling if used by Storage
                      |-----------------|
                      :                 :
                      :                 :
   blockList + 16 --> |-----------------|
                      |                 |
                      | usable area     |
                      :                 :
                      :                 :
                      :                 :
                      |-----------------|
*)
FROM SYSTEM    IMPORT ADDRESS, ADR, DOSCALL;
FROM RcDynMem  IMPORT
    (* TYPE *)      ABlock,
    (* PROC *)      InstallDynMem, Alloc, DeAlloc, Avail, CountOfFree;

FROM DOSMemory IMPORT DOSAlloc, DOSDeAlloc, DOSAvail;

(*<DOS*)
FROM RTSMain   IMPORT blockList, Terminate, Status;
(*DOS>*)

(*<OS2
FROM MemAvail  IMPORT OSMemAvail;
FROM RTSMain   IMPORT blockList;
FROM RTSTypes  IMPORT Status;
FROM RTSTerm   IMPORT Terminate;

IMPORT Storage;
OS2>*)

CONST
    DiffSize     =  100;
    MaxHeap      =    8;   (* number of heap available *)

    (* RSC 11/9/88  DOS takes a para, and DOSAlloc takes a para. *)

    OneFourth    = 256;        (* ((4096 + 32) * n) - 32, in paragraphs *)
    TwoFourths   = 512  + 2;
    ThreeFourths = 768  + 4;
    MinBlockSize = 1024 + 6;   (* in paragraphs *)

    (* 9-Jan-90 RSC We let DynMem manage records bigger than
                    UseDynMemBytes.
    *)
    UseDynMemParas = (MinBlockSize - DiffSize);
    UseDynMemBytes = (UseDynMemParas * 16);

TYPE
    BlockPtr    = RECORD
                    CASE BOOLEAN OF
                      TRUE  : ptr : POINTER TO DOSBlockHeader |
                      FALSE : adr : ADDRESS;
                    END;
                  END;

    DOSBlockHeader = RECORD
                       nextBlockSeg,
                       prevBlockSeg  : CARDINAL;
                       nextProceSeg,
                       prevProceSeg  : CARDINAL;
                       blockParaSize : CARDINAL;
                       dynamic       : BOOLEAN;
                       reserved      : ARRAY [0..4] OF CHAR;
                     END;


VAR
    LastCount   : CARDINAL;                                       (* 03-Feb-88 LAA *)
    LastSize    : CARDINAL;
    LastCountOk : BOOLEAN;





(* 9-Jan-90 RSC Added this proc to decide how much space we need
                and determine if that much is available.

    Preconditions

    Postconditions

    Input
            DesiredRecordSize   is the size in bytes of the record.

    Output
        IF TRUE is returned, there is enough memory for the allocation,
            UseThisBlockSize    is the size of the block to allocate.
            DynMemManagesBlock  Should DynMem be used to manage the
                                block?
        ELSE
            The return parameters are undefined.

*)
(*<DOS*)
PROCEDURE SpaceForNewBlockAvailable(     DesiredRecordSize  : CARDINAL;
                                     VAR UseThisBlockSize   : CARDINAL;
                                     VAR DynMemManagesBlock : BOOLEAN
                                   ) : BOOLEAN;
CONST
    DynMemOverhead      = 2;
VAR
    DesiredParas,
    DOSParasAvailable   : CARDINAL;
    ok                  : BOOLEAN;

BEGIN
    (* Compute desired whole paragraphs.
    *)
    DesiredParas      := DesiredRecordSize DIV 16;
    IF ((DesiredRecordSize MOD 16) > 0) THEN
        INC(DesiredParas);
    END;

    (* For purposes of finding free memory, we want to take into account
       some overhead of the allocation.  For DynMem in 3.03, the overhead
       is a one paragraph header for the block, plus 4 bytes for every
       item.  Since we are only trying to determine if there is enough
       memory for a NEW block, lets always assume we have the extra
       paras for overhead.
    *)
    INC(DesiredParas,DynMemOverhead);    (* 11-Jan-90 RSC was inc by 1 *)

    DOSParasAvailable := DOSAvail();

    (* If (There is enough memory to fit the desired record), AND
          (There is enough DOS memory for a tiny block) THEN
          Continue
       ELSE
          Give up.
    *)
    ok := (DOSParasAvailable >= DesiredParas) AND
          (DOSParasAvailable >= OneFourth);

    (* If continuing, we must still see if it will fit into a block.

       Blocks are multiples of (256+2) paras (See constants of
       OneFourth, TwoFourths, etc at the top of this module).
       These block sizes are coordinated with FlexStor and Overlay,
       so that we have memory sliced up into these 4K chunks in order
       to prevent memory fragmentation.

       If the desired size is almost 16K, don't bother with a block
       managed by DynMem, and don't bother making it fit our 4K chunk
       size.  This will hopefully happen VERY INFREQUENTLY, so we don't
       worry about fragmentation.  Back off on the DynMem overhead, too.
    *)
    IF (ok) THEN
        
        IF (DesiredParas > UseDynMemParas) THEN
            DynMemManagesBlock := FALSE;
            UseThisBlockSize   := (DesiredParas - DynMemOverhead);   (* 11-Jan-90 RSC back off the fudge for DynMem *)
        ELSE
            DynMemManagesBlock := TRUE;
            IF (DOSParasAvailable    >= MinBlockSize) THEN  (* 11-Jan-90 RSC *)
                UseThisBlockSize     := MinBlockSize;       (* 11-Jan-90 RSC *)
            ELSIF (DOSParasAvailable >= ThreeFourths) THEN
                UseThisBlockSize     := ThreeFourths;
            ELSIF (DOSParasAvailable >= TwoFourths) THEN
                UseThisBlockSize     := TwoFourths;
            ELSE
                UseThisBlockSize     := OneFourth;
            END;
            (* One last check to make sure that there is enough
               room in the block picked for the record.  This was the
               problem prior to 9-Jan-90, when we would get to this
               point knowing we could allocate, say, 4K, but the record
               was 5K and dos memory free was 6K.  Yuch.
            *)
            ok := (DesiredParas <= UseThisBlockSize);   (* 11-Jan-90 RSC *)
        END;
    END;

    RETURN ok;

END SpaceForNewBlockAvailable;







(* 9-Jan-90 RSC Also added this procedure....

    Determine if there is space in an existing allocated block of memory.

    Input
            DesiredRecordSize   is the size to look for, an even number.

    Output
            BlockToUse          is the address of the memory block,
                                   to be given to DynMem.

            RETURN              is TRUE if there is space in a block, and
                                   BlockToUse is valid, else FALSE.
                                   (FALSE implies that you should call
                                    "SpaceForNewBlockAvailable").

*)
PROCEDURE ExistingSpaceAvailable(     DesiredRecordSize  : CARDINAL;
                                  VAR BlockToUse         : ADDRESS
                                ) : BOOLEAN;
VAR
    A       : BlockPtr;
    ok      : BOOLEAN;
BEGIN

    (* We don't use DynMem for huge allocations.
    *)
    ok := (DesiredRecordSize <= UseDynMemBytes);
(*$O-*)
    IF (ok) THEN
        A.adr := blockList;
        ok    := FALSE;     (* Seed the loop *)

        WHILE (NOT ok) AND (A.adr.SEGMENT <> 0) DO
            IF (A.ptr^.dynamic) THEN
                BlockToUse := A.adr;
                INC( BlockToUse.SEGMENT );
                ok := Avail( ABlock(BlockToUse), DesiredRecordSize );
            END;
            A.adr.SEGMENT := A.ptr^.nextBlockSeg;
        END; (* while a # NIL *)
    END;
(*$O=*)

    RETURN ok;

END ExistingSpaceAvailable;
(*DOS>*)






(*
    - Allocate some dynamic storage (contiguous memory area).

    in:     size    number of bytes to allocate,

    out:    a       ADDRESS of allocated storage.

    The actual number of bytes allocated may be slightly
    greater than 'size', due to administrative overhead.

    Errors: If not enough space is available, or when
    attempting to allocate more than 65520 (0FFF0H)
    bytes at once, then the calling program is terminated
    with the status 'heapovf'.
*)

PROCEDURE XALLOCATE (VAR A: ADDRESS; Size: CARDINAL);
VAR
    Block           : BlockPtr;
    Where           : ADDRESS;
    ParasToAlloc    : CARDINAL;
    UseDynMem       : BOOLEAN;
    ok              : BOOLEAN;
BEGIN

(*<OS2
    Storage.ALLOCATE(a, size );
OS2>*)




(*<DOS*)
    Size := CARDINAL(BITSET(Size + 1) * BITSET(0FFFEH));            (* 16-Dec-87 LAA *)

    ok := (ExistingSpaceAvailable( Size, Where ));
    IF (ok) THEN
        UseDynMem := TRUE;
    ELSE
        ok := (SpaceForNewBlockAvailable( Size, ParasToAlloc, UseDynMem ));
(*$O-*)
        IF (ok) THEN
            DOSAlloc( Where, ParasToAlloc );
            ok := (Where <> NIL);             (* 11-Jan-90 RSC *)
            IF (ok AND UseDynMem) THEN        (* 11-Jan-90 RSC *)
                Block.adr          := Where;  (* 11-Jan-90 RSC *)
                DEC(Block.adr.SEGMENT);       (* 11-Jan-90 RSC *)
                Block.ptr^.dynamic := TRUE;   (* 11-Jan-90 RSC *)
                InstallDynMem( ABlock(Where), (ParasToAlloc * 16) );
            END;
        END;
(*$O=*)
    END;

    IF (ok) THEN
        IF (UseDynMem AND (Where <> NIL)) THEN
            Alloc( ABlock(Where), A, Size );
        ELSE
            A := Where;
        END;
        ok := (A <> NIL);
    END;

    IF (NOT ok) THEN
        Terminate( HeapOvf );
    END;
(*DOS>*)

    LastCountOk := FALSE;                     (* 03-Feb-88 LAA *)

END XALLOCATE;






PROCEDURE XDEALLOCATE (VAR a: ADDRESS; size: CARDINAL);
(*
- Release some dynamic storage (contiguous memory area).

in:     a       ADDRESS of the area to release,
        size    number of bytes to be released,

out:    a       set to NIL.

The storage area released is made available for subsequent
calls to ALLOCATE.
*)
  VAR
      adr      : BlockPtr;
      done     : BOOLEAN;
BEGIN
(*<OS2
  Storage.DEALLOCATE( a, size );
OS2>*)

(*<DOS*)
  size := CARDINAL(BITSET(size + 1) * BITSET(0FFFEH));            (* 16-Dec-87 LAA *)

  (* find the right block *)
  adr.adr := blockList;
  done := FALSE;
  REPEAT
    IF adr.adr.SEGMENT # 0 THEN
      IF (adr.adr.SEGMENT <= a.SEGMENT) AND
         (a.SEGMENT < (adr.adr.SEGMENT + adr.ptr^.blockParaSize)) THEN
        (* we find in the right block *)
        IF adr.ptr^.dynamic THEN
          INC( adr.adr.SEGMENT );
          IF DeAlloc( ABlock(adr.adr), a, size ) THEN
            DOSDeAlloc( adr.adr, 0 );
          END;
        ELSE
          DOSDeAlloc( a, 0 )
        END;
        done := TRUE;
      ELSE
        adr.adr.SEGMENT := adr.ptr^.nextBlockSeg;
      END;
    ELSE
      (* error, the block is not found *)
      Terminate( BadOperand );
    END;
  UNTIL done;
  LastCountOk := FALSE;
  a           := NIL;  (* 16-Aug-90 RSC *)
(*DOS>*)
END XDEALLOCATE;







(*
    - Test whether some number of bytes could be allocated.

    in:     size    number of bytes

    out:    TRUE if ALLOCATE (p, size) would succeed.
*)
PROCEDURE Available( Size: CARDINAL) : BOOLEAN;
VAR
    Where           : ADDRESS;
    SizeToAlloc     : CARDINAL;
    UseDynMem       : BOOLEAN;
BEGIN

(*<OS2
    RETURN (OSMemAvail( Size ));
OS2>*)



(*<DOS*)
    RETURN (ExistingSpaceAvailable( Size, Where ) OR    (* 11-Jan-90 RSC switched order. *)
            SpaceForNewBlockAvailable( Size, SizeToAlloc, UseDynMem ));
(*DOS>*)


END Available;













(*<DOS*)
PROCEDURE WhatsFreeOnHeap(    size          : CARDINAL)           (* 03-Feb-88 LAA *)
                                                       : CARDINAL;

VAR
    paraSize,
    availSize : CARDINAL;
    a         : BlockPtr;

BEGIN
    size := CARDINAL(BITSET(size + 1) * BITSET(0FFFEH));            (* 16-Dec-87 LAA *)

    paraSize := size DIV 16;
    IF (size MOD 16) > 0 THEN INC(paraSize) END;    (* get size in paragraphs *)

    (* get max number of paragraphs available *)

    availSize := 0;
    IF paraSize > (MinBlockSize - DiffSize) THEN
        (* we allocate a full block to user *)
        RETURN 0;
    ELSE
        (* at least search a small space in a dyn block *)
        a.adr := blockList;
        WHILE a.adr.SEGMENT # 0 DO
            IF a.ptr^.dynamic THEN
                INC( a.adr.SEGMENT );
                INC(availSize, CountOfFree(ABlock(a.adr), size));
                DEC( a.adr.SEGMENT );
            END;
            a.adr.SEGMENT := a.ptr^.nextBlockSeg
        END; (* while a # NIL *)
    END;

    RETURN availSize;

END WhatsFreeOnHeap;
(*DOS>*)


PROCEDURE CountOfFreeHeap(    BlockSize     : CARDINAL)
                                                       : CARDINAL;

VAR
    WhatToReturn            : CARDINAL;
    
BEGIN                       (* CountOfFreeHeap *)
(*<DOS*)
    IF (LastCountOk AND (BlockSize = LastSize)) THEN
        WhatToReturn := LastCount;
    ELSE
        IF (BlockSize < 10) THEN
            BlockSize := 10;
        END;
        WhatToReturn := WhatsFreeOnHeap(BlockSize);
        LastCount := WhatToReturn;
        LastSize := BlockSize;
        LastCountOk := TRUE;
    END;

    RETURN WhatToReturn;
(*DOS>*)
(*<OS2
    RETURN 0;
OS2>*)
END CountOfFreeHeap;






PROCEDURE InstallHeap;
BEGIN
    HALT;   (* 9-Jan-90 RSC trust me. *)
END InstallHeap;

PROCEDURE RemoveHeap;
BEGIN
    HALT;   (* 9-Jan-90 RSC trust me. *)
END RemoveHeap;

BEGIN
    ALLOCATE    := XALLOCATE;   (* 2-Aug-89 RSC *)
    DEALLOCATE  := XDEALLOCATE;
    LastCountOk := FALSE;                     (* 03-Feb-88 LAA *)
END BTStorage.
