IMPLEMENTATION MODULE OVSwap;
(*  =========================================================================
    Last Edit : July 1, 1991 11:27AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Overlay Swpper


        We swap to Extended memory or to FlexStor.


    MODIFICATION HISTORY:

        1-Feb-91 RSC First version.

       28-Mar-91 RSC Added "Trace mode".  This is to help debug problems
                     when not in "debug mode".  Often maps are useless,
                     because they say "Map file does not correspond to
                     program dump".  at least here, you will see the flow
                     of overlay calls with trace mode on:

                         ADDIN IS TLTRACE

       12-Apr-91 RSC When flushing the cache, we sometimes flushed TOO
                     MANY overlays, including ones not in the cache!

       26-Apr-91 RSC Make FlushOverlay a stealable procedure.

       12-Jun-91 RSC When Flushing, never flush a parent with kids.  Flush
                     the kids first, so that we don't have dangling kids.
                     Sometimes it can crash, and it never is a good thing.
                     Also, stop flushing when we get enough free space.

       11-Jul-91 LAA Small bugs which Patty, Roger and I found during a 
                     walk-through.  In FreeSwapSpace, changed a test for =
                     into one of >=, and at the end changed it to return
                     FALSE.  In AllocateSpace, moved a return out of a loop.
                     Also added some annotations to re-inforce my 
                     understanding.  I also added a couple of FatalError
                     checks "just in case".
    =========================================================================
*)


FROM Dialog     IMPORT
    (* PROC *)      FatalError;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
    (* PROC *)      CreateExtObjectWithSize, LockObject, ReleaseObject,
                    ReleaseUnchangedObject, DiscardExtObject;

FROM LStrings   IMPORT
    (* PROC *)      SetString, ConcatLS, ConcatS, CtoS;

FROM Overlay    IMPORT
    (* PROC *)      DeInstallOverlay;

FROM OvTree     IMPORT
    (* TYPE *)      AContextListEntry, AResidence, AResidenceBlock,
                    AResidenceWhere,
    (* VAR  *)      OverlayTree,
    (* PROC *)      RemoveFromContextList;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS,
    (* CONST *)     CX,
    (* ADR  *)      TSIZE, CODE, SETREG, ADR;

FROM TreeObjects IMPORT
    (* TYPE *)      ATreeNode;

FROM XMSMem     IMPORT
    (* PROC *)      AllocateEMBMemory, DeAllocateEMBMemory,
                    EMBCopyFromDOS, EMBCopyToDOS, EMBAvailable;



    (* To hold an overlay in FlexStor, we have to slice it up.  That's what
       BlockDataSize is used for (exclusively), and its value is dependant
       on the size of FlexStor buffers.
    *)
CONST
    BlockDataSize  = (1024 * 3);           (* data bytes per block *)
    BlockDataSizeP = BlockDataSize DIV 16; (* in paragraphs *)
    MaxBlocks      = (64 DIV 3) + 1;       (* Ever needed for an overlay *)

TYPE
    ABlock         = RECORD
        Header  : AResidenceBlock;
        Data    : ARRAY [1..BlockDataSize] OF CHAR;
    END;

    ABlockPointer  = POINTER TO ABlock;





PROCEDURE MoveBlock ( src, dest : ADDRESS; count: CARDINAL);
CONST
    REPNZ   = 0F2H;
    MOVSB   = 0A4H;
    LDS     = 0C5H;
    LES     = 0C4H;
    SIviaBP = 76H;
    DIviaBP = 7EH;

BEGIN
    CODE (LDS, SIviaBP,10);
    CODE (LES, DIviaBP,6);
    SETREG (CX, count);
    CODE (REPNZ, MOVSB);
END MoveBlock;






(* Stealable flush routine.
   This flushes an overlay from XMS memory only.  It's not called for
   overlays pushed to FlexStor.

   26-Apr-91 RSC Broke out from FreeSwapSpace and made stealable.
*)
PROCEDURE XFlushOverlay( OverlayEntry : ATreeNode );
VAR
    Context                 : AContextListEntry;
BEGIN
    Context := OverlayEntry^.Methods^.GetDataObject( OverlayEntry );
    WITH Context^ DO
        DeAllocateEMBMemory( ResidentWhere.XMSStartingByte,
                             ResidentWhere.XMSLength );
        DeInstallOverlay( TheOverlayPtr );
    END;

    RemoveFromContextList(Context);

END XFlushOverlay;






(* Free up overlays in swap space if they are not critical (not in use).

    Size is in PARAGRAPHS.
*)
PROCEDURE FreeSwapSpace( Size : CARDINAL ) : BOOLEAN;
VAR
    TotalKB,
    NeededKB,
    Pass                    : CARDINAL;
    NextNode,
    Node                    : ATreeNode;
    Context                 : AContextListEntry;
BEGIN
    NeededKB := Size DIV 64;         (* Paragraphs to KB *)
    IF ((Size MOD 64) <> 0) THEN
        INC(NeededKB);
    END;


        (* Pass 1, get an overlay of the same or better size
           Pass 2 and 3, get anything we can.
           (Pass 2 gets KIDS and Pass 3 gets MOMS) 12-Jun-91 RSC
        *)
    FOR Pass := 1 TO 3 DO
        Node := OverlayTree^.Methods^.GetFirst (OverlayTree);
        WHILE (Node <> NIL) DO
            NextNode := Node^.Methods^.NextPreOrder (Node);
            Context  := Node^.Methods^.GetDataObject (Node);
            IF (Context = NIL) THEN FatalError(); END;

                (* 12-Jun-91 RSC Added this, so kids die before
                                 their parents.  Kids in Pass 2,
                                 Parents in 3 (at the latest).
                                 Otherwise, we could kill parents
                                 and leave kids hanging.  A Traverse
                                 Tree( KidsBeforeAdults ) would also
                                 work, but the FIRST pass would be
                                 handled much in this way anyway,
                                 so that we tend not to blast
                                 EVERYTHING.
                *)
            IF (Node^.Methods^.GetSubtree(Node) = NIL) THEN
                    (*  We don't want to flush an overlay with a deinstall
                        proc, since having a deinstall proc implies there's
                        some deinitialization work to be done, but we can't
                        do it without bringing the overlay into real memory.
                    *)
                WITH Context^ DO
                    IF (UseCount                  = 0)     AND
                       (ResidentWhere.Residence   = InXms) AND
                       (ADDRESS(DeInstallProc)    = NIL)   THEN

                        IF (Pass > 1) OR
                           (ResidentWhere.XMSLength  >= Size * 16)  THEN
                            FlushOverlay( Node );
                            IF (Pass = 1) OR
                                    (* 12-Jun-91 RSC Added this check, too
                                    *)
                               (EMBAvailable(TotalKB) >= NeededKB) THEN  (* 11-Jul-91 *)
                                RETURN TRUE;
                            END;
                        END;
                    END;
                END;
            END;
            Node := NextNode;
        END;
    END;

    RETURN FALSE;                                              (* 11-Jul-91 *)

END FreeSwapSpace;










(* Swap out the overlay, if possible.

        TRUE  - swapped out.
        FALSE - not swapped out.

    TheSizeToSwap is in PARAGRAPHS.
*)
PROCEDURE XSwapOut(     Critical         : BOOLEAN;
                    VAR Where            : AResidenceWhere;
                        TheSizeToSwap    : CARDINAL;
                        FromHere         : ADDRESS ) : BOOLEAN;
CONST
    MaxSize = 32768 DIV 8;  (* MAXCARD / 16 bytes *)
VAR
    BlockNumber : CARDINAL;
    Blocks      : ARRAY [1..MaxBlocks+1] OF AnExtHandle;
    ok          : BOOLEAN;



    PROCEDURE AllocateSpace() : BOOLEAN;
    VAR
        BlocksNeeded,
        i               : CARDINAL;
    BEGIN
        Where.Residence := InMainMemory;

            (* If there is free Extended memory, OR
                  (this is a critical swap (UseCount > 0) AND
                   we can free up some Extended memory, AND
                   There is then free Extended memory) THEN

                   we have extended memory to use.

                Otherwise,

                    If Critical swap,
                        allocate space in FlexStor
            *)
        IF (TheSizeToSwap < MaxSize) AND
            (AllocateEMBMemory( TheSizeToSwap * 16,
                                Where.XMSStartingByte ) OR

            (Critical AND FreeSwapSpace(TheSizeToSwap) AND
             AllocateEMBMemory( TheSizeToSwap * 16,
                                Where.XMSStartingByte ))) THEN

                (* Its in EMB!!  Horay! *)

            Where.Residence := InXms;
            Where.XMSLength := TheSizeToSwap * 16;

        ELSIF (Critical) THEN

            BlocksNeeded := (TheSizeToSwap DIV BlockDataSizeP);
            IF ((TheSizeToSwap MOD BlockDataSizeP) > 0) THEN
                INC(BlocksNeeded);
            END;

            FOR i := 1 TO BlocksNeeded DO
                BlockNumber := i;
                IF (NOT CreateExtObjectWithSize( Blocks[i],
                                                 ExtSlow,
                                                 TSIZE(ABlock)
                                                )) THEN
                    DEC(BlockNumber);
                    WHILE (BlockNumber > 0) DO
                        DiscardExtObject(Blocks[BlockNumber]);
                        DEC(BlockNumber);
                    END;
                    RETURN FALSE;                              (* 11-Jul-91 *)
                END;
            END;

            Where.Residence := InFlexStor;

        END;

        RETURN (Where.Residence <> InMainMemory);

    END AllocateSpace;



    PROCEDURE Swap( From : ADDRESS; ByteCount : CARDINAL );
    VAR
        BlockPtr    : ABlockPointer;
        MoveSize,
        ObjectSize  : CARDINAL;
        i           : CARDINAL;
    BEGIN
        IF (Where.Residence = InXms) THEN

            EMBCopyFromDOS( Where.XMSStartingByte,
                            Where.XMSLength,
                            From );

        ELSIF (Where.Residence = InFlexStor) THEN

            Blocks[BlockNumber+1] := AnExtHandle(NIL);

            FOR i := 1 TO BlockNumber DO

                ObjectSize := LockObject(Blocks[i],BlockPtr);
                IF (ObjectSize <> TSIZE(ABlock)) THEN
                    FatalError();
                END;

                    (*  All these numbers are in paragraphs. *)

                MoveSize := BlockDataSizeP;
                IF (MoveSize > ByteCount) THEN
                    MoveSize := ByteCount;
                END;
                DEC(ByteCount, MoveSize);

                WITH BlockPtr^.Header DO
                    Next.FlexStorHandle := Blocks[i+1];
                    Size                := MoveSize * 16;
                END;
                MoveBlock( From, ADR(BlockPtr^.Data[1]), MoveSize * 16);
                INC(From,MoveSize * 16);

                ReleaseObject(Blocks[i]);
            END;
            Where.FlexStorHandle := Blocks[1];
        ELSE
            FatalError();
        END;
    END Swap;


BEGIN
    ok := AllocateSpace();
    IF (ok) THEN
        Swap( FromHere, TheSizeToSwap );
    END;

    RETURN ok;

END XSwapOut;




(* Swap In the overlay.  If the overlay is in use, then dispose of the
   swap space.

    TheSizeSwapped is in PARAGRAPHS.
*)
PROCEDURE XSwapIn(     Discard          : BOOLEAN;
                   VAR Where            : AResidenceWhere;
                   VAR TheSizeSwapped   : CARDINAL;
                       ToHere           : ADDRESS );
VAR
    ObjectSize  : CARDINAL;
    BlockPtr    : ABlockPointer;
    NextBlock,
    BlockHandle : AnExtHandle;
BEGIN
    TheSizeSwapped := 0;

    IF (Where.Residence = InXms) THEN

        TheSizeSwapped := Where.XMSLength DIV 16;

        EMBCopyToDOS( Where.XMSStartingByte,
                      Where.XMSLength,
                      ToHere );

        IF (Discard) THEN
            DeAllocateEMBMemory( Where.XMSStartingByte,
                                 Where.XMSLength );
            Where.Residence := InMainMemory;
        END;

    ELSIF (Where.Residence = InFlexStor) THEN

        BlockHandle := Where.FlexStorHandle;
        IF (BlockHandle = AnExtHandle(NIL)) THEN FatalError(); END;

        WHILE (BlockHandle <> AnExtHandle(NIL)) DO

            ObjectSize := LockObject(BlockHandle,BlockPtr);
            IF (ObjectSize <> TSIZE(ABlock)) THEN
                FatalError();
            END;

            WITH BlockPtr^.Header DO
                NextBlock := Next.FlexStorHandle;
                INC(TheSizeSwapped,Size DIV 16);
                MoveBlock( ADR(BlockPtr^.Data[1]), ToHere, Size);
                INC(ToHere,Size);
            END;

            ReleaseUnchangedObject( BlockHandle );
            IF (Discard) THEN
                DiscardExtObject(   BlockHandle );
                Where.Residence := InMainMemory;               (* 11-Jul-91 *)
            END;

            BlockHandle := NextBlock;
        END;
    ELSE
        FatalError();
    END;

END XSwapIn;




BEGIN
    FlushOverlay := XFlushOverlay;  (* 26-Apr-91 RSC  *)
    SwapOut      := XSwapOut;
    SwapIn       := XSwapIn;
END OVSwap.
