(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module       : DOSMemory - DOS memory management compatible with M-2 *)
(*                                                                            *)
(*       Release :    3.0 - July 87                                           *)
(*                                                                            *)
(*       Copyright (C)  1987 Logitech, All rights reserved                    *)
(*                                                                            *)
(*       Permission is hereby granted to registered users to use or abstract  *)
(*       the following program in the implementation of customized versions.  *)
(*       This permission does not include the right to redistribute the       *)
(*       source code of this program.                                         *)
(*                                                                            *)
(*                                                                            *)
(* MODIFICATION HISTORY:                                                      *)
(*                                                                            *)
(*       14-Mar-90 RSC  Sort the chain of memory blocks in segment number     *)
(*                      order.  This should help reduce fragmentation.        *)
(*                                                                            *)
(*       14-Jun-90 RSC  Add XMS support through hookable vectors.             *)
(*                                                                            *)
(*       25-Jul-91 LAA  Put in checks for DOS memory chain corruptions,       *)
(*                      and call HALT if they occur.  This should help        *)
(*                      isolate the occasional bug with Time Line dying       *)
(*                      at start-up due to "insufficient memory".              *)
(*       02-Oct-91 LAA  In DOSAlloc, if DOS ever gave us back a segment       *)
(*                      which was less than the first segment in the existing *)
(*                      blockList, we'd loose track of the existing stuff,    *)
(*                      which caused real problems when trying to deallocate  *)
(*                      stuff in those blocks!  This only seemed to happen    *)
(*                      under 3Com+, just because!  NextSegment was           *)
(*                      initialized to zero, which wasn't right.              *)
(*                                                                            *)
(******************************************************************************)

IMPLEMENTATION MODULE DOSMemory;

(* IMPLEMENTATION NOTES :                                                  *)
(*                                                                         *)
(*    - We assume here that NIL is represented by 0:FFFF ( segment is 0 )  *)
(*    - We assume too that DOS will never allocate memory at address 0:0   *)
(*    - We assume that DOS allocates only paragraph aligned memory blocks  *)
(*                                                                         *)
(* Under these assumptions, we build the list of the allocated blocks      *)
(* using the segment only and assuming that segment 0 is NIL segment.      *)

FROM SYSTEM  IMPORT ADDRESS, DOSCALL;
FROM RTSMain IMPORT ProcessDescriptor, blockList, activProcess;

FROM XMSMem  IMPORT
    (* PROC *)      AllocateUMBMemory, DeAllocateUMBMemory, UMBAvailable;



TYPE
    DOSBlockHeader = RECORD
                       nextBlockSeg,
                       prevBlockSeg  : CARDINAL;
                       nextProceSeg,
                       prevProceSeg  : CARDINAL;
                       blockParaSize : CARDINAL;
                       Heap          : BOOLEAN;
                       XMSManaged    : BOOLEAN;
                       reserved      : ARRAY [0..1] OF CARDINAL;
                     END;
    Ptr = RECORD
            CASE BOOLEAN OF
              TRUE  : adr : ADDRESS |
              FALSE : ptr : POINTER TO DOSBlockHeader;
            END;
          END;


PROCEDURE DOSAlloc( VAR a: ADDRESS; paraSize: CARDINAL );
(* Allocates a block of paraSize paragraphs :                      *)
(*   a is the address of the block returned or NIL if the size     *)
(*   is not available or an error occured                          *)
  VAR
      error,
      blockSize : CARDINAL;
      p, next   : Ptr;

      NewBlockSegment,
      PriorSegment,
      NextSegment       : CARDINAL; (* 14-Mar-90 RSC *)

      XMSMemory         : BOOLEAN;

      PROCEDURE Lt( Item : Ptr ) : BOOLEAN;
      BEGIN
        (* First comes XMS memory, and then regular memory.
           so, XMS memory TRUE is "less than" XMS memory FALSE.
        *)
          RETURN (ORD(Item.ptr^.XMSManaged) > ORD(XMSMemory)) OR (Item.adr.SEGMENT < NewBlockSegment);
      END Lt;

BEGIN
    blockSize    := paraSize+1;

    XMSMemory := (AllocateUMBMemory( blockSize, NewBlockSegment ));
    IF (XMSMemory) THEN
        error := 0;
    ELSE
        DOSCALL( 48H, blockSize, NewBlockSegment, error );
    END;

    IF (error <> 0) THEN
            (*  Die if DOS memory control blocks have been damaged. *)
        IF (error = 7) THEN                                    (* 25-Jul-91 *)
            HALT;
        END;
        a := NIL;
    ELSE
        WITH p DO
            adr.SEGMENT        := NewBlockSegment;
            adr.OFFSET         := 0;
            ptr^.blockParaSize := blockSize;
            ptr^.Heap          := FALSE;
            ptr^.XMSManaged    := XMSMemory;
        END;

        (* 14-Mar-90 RSC OLD CODE:

            **  next.adr := blockList;
            **  blockList := p.adr;
            **  p.ptr^.prevBlockSeg := 0;
            **  p.ptr^.nextBlockSeg := next.adr.SEGMENT;
            **  IF next.adr.SEGMENT # 0 THEN
            **    next.ptr^.prevBlockSeg  := p.adr.SEGMENT
            **  END;


            NEW CODE:

            Insert the new block in sorted segment order into the chain.

            If the block list is currently empty, make this the first item.
            Otherwise, search through the existing chain and find where the
            new item goes.  If at the front of the list, point the block list
            header to the new item, and the "prior" item is nil (0).
            If at the end of the list, the "next" item is nil (0).
        *)

        PriorSegment := 0;
        NextSegment  := blockList.SEGMENT;                     (* 02-Oct-91 *)

        WITH next DO
            adr := blockList;

            WHILE (adr.SEGMENT <> 0) AND
                  (Lt(next)) DO
                PriorSegment := adr.SEGMENT;
                NextSegment  := ptr^.nextBlockSeg;
                adr.SEGMENT  := NextSegment;
            END;
        END;

        (* Here, we are at the point where next --> the end of the chain
           or the item we must insert before.  In either case, insert
           the new item before the next item.
        *)

        p.ptr^.nextBlockSeg := NextSegment;
        IF (NextSegment <> 0) THEN
            next.ptr^.prevBlockSeg := NewBlockSegment;
        END;
        p.ptr^.prevBlockSeg := PriorSegment;

        (* If there is no prior, then we are at the head of the list, so
           the blockList should point to us, otherwise the PriorSegment's
           block points to us.
        *)
        IF (PriorSegment = 0) THEN
            blockList := p.adr;
        ELSE
            next.adr.SEGMENT       := PriorSegment;
            next.ptr^.nextBlockSeg := NewBlockSegment;
        END;


        (* 14-Mar-90 RSC End of change. *)


        next.adr := activProcess^.heapDesc;
        activProcess^.heapDesc := p.adr;
        p.ptr^.prevProceSeg := 0;
        p.ptr^.nextProceSeg := next.adr.SEGMENT;
        IF next.adr.SEGMENT # 0 THEN
            next.ptr^.prevProceSeg  := p.adr.SEGMENT
        END;

        a := p.adr;
        INC( a.SEGMENT );
    END;
END DOSAlloc;


PROCEDURE DOSDeAlloc( VAR a: ADDRESS; paraSize: CARDINAL );
(* DeAllocates a block previously allocated with DOSAlloc. The     *)
(* paraSize passed must be the size given for allocate or setsize  *)
(*   a is set to the NIL value if DeAlloc succeds, not modified    *)
(*   an error occured.                                             *)
(* NOTE: the address passed MUST BE the address returned by        *)
(*       DOSAlloc                                                  *)
  VAR
      error,
      blockSize : CARDINAL;
      p, next, prev   : Ptr;
      ok              : BOOLEAN;
BEGIN
  p.adr := a;
  DEC( p.adr.SEGMENT );
  prev.adr.OFFSET := 0;
  next.adr.OFFSET := 0;

  prev.adr.SEGMENT := p.ptr^.prevBlockSeg;
  next.adr.SEGMENT := p.ptr^.nextBlockSeg;
  IF prev.adr.SEGMENT=0 THEN
    blockList := next.adr
  ELSE
    prev.ptr^.nextBlockSeg := next.adr.SEGMENT;
  END;
  IF next.adr.SEGMENT # 0 THEN
    next.ptr^.prevBlockSeg := prev.adr.SEGMENT;
  END;

  prev.adr.SEGMENT := p.ptr^.prevProceSeg;
  next.adr.SEGMENT := p.ptr^.nextProceSeg;
  IF prev.adr.SEGMENT=0 THEN
    activProcess^.heapDesc := next.adr
  ELSE
    prev.ptr^.nextProceSeg := next.adr.SEGMENT;
  END;
  IF next.adr.SEGMENT # 0 THEN
    next.ptr^.prevProceSeg := prev.adr.SEGMENT;
  END;

(*  blockSize := p.ptr^.blockParaSize;*)    (* 14-Mar-90 RSC Not used? *)

    IF (p.ptr^.XMSManaged) THEN
        ok := DeAllocateUMBMemory( p.adr.SEGMENT );
    ELSE
        DOSCALL( 49H, p.adr, error );
            (*  Die if DOS memory control blocks have been damaged. *)
        IF (error = 7) THEN                                    (* 25-Jul-91 *)
            HALT;
        END;
    END;

    a := NIL;

END DOSDeAlloc;


PROCEDURE DOSAvail(): CARDINAL;
(* Function that returns the size ( in paragraphs ) of the largest *)
(* space available.                                                *)
  VAR
      error,
      UMBSize,
      a    : CARDINAL;
      size : CARDINAL;
BEGIN
  size := 0FFFFH;

  UMBSize := UMBAvailable();

  DOSCALL( 48H, size, a, error );
    (*  Die if DOS memory control blocks have been damaged. *)
  IF (error = 7) THEN                                          (* 25-Jul-91 *)
    HALT;
  ELSIF (error=8)AND(size>1) AND (size > UMBSize) THEN
    (* size is already set up correctly *)
  ELSIF (UMBSize > 0) THEN
    size := UMBSize;
  ELSE
    size := 1;  (* Will be decremented to zero. *)
  END;

  RETURN size - 1;

END DOSAvail;


PROCEDURE DOSSetSize( a: ADDRESS; paraSize: CARDINAL; VAR errorCode: CARDINAL );
(* Sets the size of the block given to the new size given in       *)
(* paraSize. The returned value is TRUE if the operation succeds   *)
(* FALSE if any error occurs.                                      *)
(* NOTE: the address passed MUST BE the address returned by        *)
(*       DOSAlloc                                                  *)
  VAR
      blockSize : CARDINAL;
      p         : Ptr;
BEGIN

    HALT;
(*
  blockSize := paraSize+1;
  p.adr := a;
  DEC(p.adr.SEGMENT);
  DOSCALL( 4AH, p.adr, blockSize, errorCode );
  IF errorCode=0 THEN
    p.ptr^.blockParaSize := blockSize;
  END;
*)
END DOSSetSize;


PROCEDURE DOSGetMaxSize( a: ADDRESS ): CARDINAL;
(* Gets the maximal paragraph size to which the block given as     *)
(* parameter can be extended                                       *)
(* NOTE: the address passed MUST BE the address returned by        *)
(*       DOSAlloc                                                  *)
  VAR
      error,
      blockSize : CARDINAL;
      p         : Ptr;
BEGIN

    HALT;

(*
  blockSize := 0FFFFH;
  p.adr := a;
  DEC(p.adr.SEGMENT);
  DOSCALL( 4AH, p.adr, blockSize, error );
  IF error=8 THEN
    RETURN blockSize-1
  ELSE
    RETURN 0
  END;
*)
END DOSGetMaxSize;

END DOSMemory.
