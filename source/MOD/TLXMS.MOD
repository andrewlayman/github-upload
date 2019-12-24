MODULE TLXMS;

(*  =========================================================================
    Last Edit : July 8, 1991 5:14PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        XMS UMB and HMA driver.  WKH and RSC, 23-Mar-90.

        The XMS spec was developed by a consortium of developers,
        among them Quarterdeck, makers of QEMM and QRAM.
        In 1988, after TL V3.0 was released, Microsoft published the
        first "official spec" for XMS.  Since then, Windows, QEMM,
        QRAM, DesQView, etc have used this spec.

        In brief, the area between 640KB and 1MB is all directly addressable
        from DOS via segments and offsets.  Without an XMS driver, the
        memory above 640K does not contain RAM, however.  Instead, it is
        a mishmosh of ROMs, EMS page frames, Video Ram, etc.  In between
        the addresses used by these hardwarish items are unused memory
        addresses.  As much as 200K or more of unused addresses, depending
        on wether you use EMS, CGA/EGA/VGA cards, network adapter cards,
        etc.

        Programs like QEMM map real (extended) memory into these addresses
        that are free, and allow you to "LoadHi" TSRs into that space.
        In addition, If you do not have a graphics video adapter, or disable
        graphics with something like "Vidram ON", QEMM gives you another
        100K of DOS MEMORY for applications like Time Line 3.0 to use.

        Now the exciting part.  Through the XMS spec, with an XMS driver
        like QEMM, QRAM, or even DOS 3.3/4.x's HIMEM.SYS driver, TL 4.0
        can access the free memory that LOADHI uses for TSR's.  Depending
        on the number of TSR's and other factors, there can be no free
        high memory (in which case, the user has optimized DOS memory by
        placing TSR's high, and that is fine too), or up to 178KB or so free.
        This is called "UMB" memory.

        When this overlay starts, I allocate all the UMB memory I can get
        ahold of in blocks from 16K down to 2K.  I then "fool" BTStorage
        into thinking that these blocks are part of the heap.  BTStorage
        then manages all allocations and deallocations through DynMem.
        Therefore, no overhead is needed here for UMB memory.  When the
        overlay shuts down, I return UMB memory to DOS.  If we crash, then
        the UMB memory is lost until reboot, much like EMS memory.

        In addition to UMB memory, there is a trick on 286 and 386 machines
        that you can play to extend the 1MB border.  It is possible, and is
        part of the XMS spec, to address the 64K (less one para) JUST ABOVE
        1MB.  Set the segment to FFFF and the offset to 0010 or greater (up
        to FFFF), and "presto" another chunk of directly addressable space.
        This space is kind of special in that you cannot normalize addresses.
        For this reason and others, it is not available for LOADHI, and is
        often available to us.  This is called "HMA" memory.

        In this overlay, we steal the ALLOCATE and DEALLOCATE vectors to
        manage HMA memory.  If there is no HMA memory, then we don't need
        to steal the vectors.  When a client wants to allocate memory, we
        get the request first and see if it should come from HMA memory.
        If not available here, go back to the default method of asking
        BTStorage for memory.

        Now, a problem.  The HMA memory starts at offset 0010, not at 0000,
        and DynMem (BTStorage's block manager) wants all its blocks to be
        paragraph aligned (no problem so far) and with a 0 offset (oh).
        Rather than build my own block manager, which would require more
        testing, I use the HMA for other special purposes.

        I happen to know that we allocate many many records of the same
        size.  For example, Tree Nodes.  I define an array of these
        tree nodes, put its address in the HMA, and whenever a
        request for something the size of a tree node comes in, I
        go ahead and allocate it from this list.  I maintain a very
        simple free list of records.  Since the records are all the
        same size, I need not worry about compressing free space, or
        other "risky" things.

        Now a risk note.  Using this high 64K requires enabling the 21st
        address line on 286/386's.  Anecdotally, we hear that some programs
        expect this line to not be enabled when they run, so we must turn
        off the line when we are shutting down.  For this reason, we will
        provide a small program that cleans up after us, and put this
        program into TL.BAT after Time Line runs.  This way, if we die
        with PMD's, and so this overlay does not clean up, at least the
        address line will be disabled.

        Further, this 64K area cannot be used with DMA or with many DOS
        calls, or for interrupt handlers.  By restricting its use to just
        24 byte "things" (hopefully mostly tree nodes), we may be able to
        avoid these problems.  We'll see.


    MODIFICATION HISTORY:

        23-Mar-90 RSC/WKH First secret version by Iceman and Maverick.
        27-Mar-90 RSC     Upped size of an HMA node to include edges.
                          Removed CutoffSegment.
        29-Mar-90 RSC     Changed the way we shut down.  See warnings!
        14-Jun-90 RSC     Upgraded for new XMSMemory.Mod
        18-Jun-90 RSC     Debugged.
        30-Jan-91 RSC     Use RcDynMem for standard heap management for
                          the HMA.
         1-Feb-91 RSC     Support new EMB calls in XMSMem.
        21-Mar-91 RSC     Support STATS calls better for TLStats.
        09-Apr-91 RSC     Fix one-too-many problem in allocating EMB pages.
        12-Jun-91 RSC     EMBAvailable will return (as it was supposed to)
                          the LARGEST SINGLE BLOCK free, not the TOTAL free.
         8-Jul-91 RSC     Leave 64K of EMB for EMS use in TLGS.  Also,
                          as per bug 4657, on machines with no XMS, we
                          would behave strangely on our "early" shutdown.
        29-Aug-91 TGS   Changed "XMS IS" to "EMB IS".
                        Round the amount down to the nearest EMBPageSizeInKB
                        (TL crashed if KBRequested was less than 4).
        25-Sep-91 LAA   Changed XEMBAvailable so that it actually does return
                        the largest block of EMB memory available, rather
                        than always returning either 0 or 4.  This was a
                        simple logic error, but accounts for the fact that
                        the Stats screen always reported just 4K free.
    =========================================================================
*)


FROM BTStorage      IMPORT
    (* TYPE *)          AStorageProc,
    (* PROC *)          ALLOCATE, DEALLOCATE;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM DOSMemory      IMPORT
    (* PROC *)          DOSDeAlloc;

FROM FlexData       IMPORT
    (* TYPE *)          ACellBlock;

FROM LStrings       IMPORT
    (* PROC *)          SetString, StoC;

FROM Overlays       IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvTree         IMPORT
    (* TYPE *)          AContextListEntry, AnOverlayProc;

FROM Paranoia       IMPORT
    (* TYPE *)          AProgramState,
    (* VAR  *)          ProgramState;

FROM ParmLine       IMPORT
    (* PROC *)          GetOption;

FROM RcDynMem       IMPORT
    (* TYPE *)          ABlock,
    (* PROC *)          InstallDynMem, Alloc, DeAlloc, Avail;

FROM RTSMain        IMPORT
    (* TYPE *)          RTDProc, OverlayPtr, OverlayDescriptor,
    (* VAR *)           debuggerRecord, blockList, activProcess;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, PROCESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM XMSMem         IMPORT
    (* VAR  *)          HMAPresent,
    (* PROC *)          AllocateUMBMemory, DeAllocateUMBMemory, UMBAvailable,
                        AllocateEMBMemory, DeAllocateEMBMemory, EMBAvailable,
                        EMBCopyToDOS,      EMBCopyFromDOS;

FROM XMSMemory      IMPORT
    (* VAR *)           XMSStatsRecord,
    (* PROCS *)         GetUMBMemory, FreeUMBMemory,
                        EMBAvail, CopyEMBToDOS, CopyDOSToEMB,
                        GetEMBMemory, FreeEMBMemory,
                        XMSShutDown,  XMSStartup;






TYPE
        (* WARNING!! THESE TWO TYPES ARE COPIES OF THOSE IN
                     BTSTORAGE.MOD (From Us and Logitech).
        *)
    DOSBlockHeader = RECORD
        NextBlockSeg,
        PrevBlockSeg  : CARDINAL;
        NextProceSeg,
        PrevProceSeg  : CARDINAL;
        BlockParaSize : CARDINAL;
        Heap          : BOOLEAN;
        XMSManaged    : BOOLEAN;
        Reserved      : ARRAY [0..3] OF CHAR;
    END;
    Ptr = RECORD
        CASE BOOLEAN OF
            TRUE  : adr : ADDRESS |
            FALSE : ptr : POINTER TO DOSBlockHeader;
        END;
    END;


    AnEMBPage    = [0..255];
    AnEMBPageSet = SET OF AnEMBPage;

CONST
           (* 4KB per page
           *)
    EMBPageSizeInKB     = 4;

           (* Pages in up to 8 Page SETS
           *)
    NumberOfEMBPageSets = 8;

           (* total KB we can manage (about 8 megs)
           *)
    MaxAllowedEMBPages  = 256 * NumberOfEMBPageSets;
    MaxAllowedEMBKB     = MaxAllowedEMBPages * EMBPageSizeInKB;


VAR

    OverlayID               : AnOverlayID;

    OldALLOCATE,
    OldDEALLOCATE           : AStorageProc;

    UMBParagraphsAvailable  : CARDINAL;     (* Stats info *)


    OldExitProc             : RTDProc;

    EMBTotalEverFree        : CARDINAL; (* In KB *)

    EMBPageSets             : ARRAY [1..NumberOfEMBPageSets] OF AnEMBPageSet;
    EMBPages                : CARDINAL;
    EMBHandle               : CARDINAL;
    EMBHandleInUse          : BOOLEAN;





(* Grab all XMS memory from the system.  None around?  Return FALSE.
*)
PROCEDURE XMSAvailable() : BOOLEAN;
VAR
    ok              : BOOLEAN;
BEGIN
    ok := XMSStartup();

    WITH XMSStatsRecord DO
        ok := (ok AND XMSDriverDetected AND (* 8-Jul-91 RSC "ok AND" *)
              (UMBMemoryDetected OR HMAMemoryDetected OR EMBMemoryDetected));

        IF (ok AND HMAMemoryDetected) THEN
            InstallDynMem( ABlock(HMAAddress), (HMASize * 16) );
        END;
    END;

    RETURN (ok);

END XMSAvailable;




(*
    WARNING!!!!

   Because this is an overlay, and there is not enough support in
   the root for us, we need to play games with our shutting down.

   Here we take advantage of the fact that, since Time Line is shutting
   down, Our code will be marked as "Free".  However, no new data or code
   is being loaded, so nothing will take our place, and the code here will
   still be intact and executable.

   This is, of course, a gamble.  It depends on the Logitech 3.x compiler
   my knowledge of our App.  This must be changed when we can change the
   root, so that things shut down at the very end of TimeLine.Mod.

   Here, we set up the TLXMSShutDown proc as the one for the root to
   call when exiting the main.

   RSC
*)
PROCEDURE SetUpShutDown();
BEGIN
    OldExitProc               := debuggerRecord.beforeExit;
    debuggerRecord.beforeExit := TLXMSShutDown;
END SetUpShutDown;








(* Return all UMB memory to the system.
*)
PROCEDURE TLXMSShutDown( PList : PROCESS;  A : ADDRESS );
VAR
    Next,
    NextProcess,
    Prev,
    P           : Ptr;
    TheOverlay  : OverlayPtr;
    ErrorCode   : CARDINAL;

    PROCEDURE TimeLineName( VAR s : ARRAY OF CHAR ) : BOOLEAN;
    BEGIN

        RETURN (s[0] = "T") AND (s[1] = "i") AND (s[2] = "m");

    END TimeLineName;


BEGIN

    TheOverlay := OverlayPtr(A);
    IF (TheOverlay = NIL) OR (TimeLineName(TheOverlay^.overlayName)) THEN

        Next.adr.OFFSET         := 0;
        Prev.adr.OFFSET         := 0;
        NextProcess.adr.OFFSET  := 0;

(*$O-*)
        P.adr := blockList;
        WHILE (P.adr.SEGMENT <> 0) DO
            Next.adr.SEGMENT  := P.ptr^.NextBlockSeg;
            IF (P.ptr^.XMSManaged) THEN
                INC(P.adr.SEGMENT);
                DOSDeAlloc( P.adr, 0 );
                P.adr     := blockList;  (* Start from the top again. *)
            ELSE
                P         := Next;  (* Otherwise go onto the next block. *)
            END;
        END;
(*$O=*)

        KlugeRunning := TRUE; (* Watch out for all deallocates from now on! *)

        IF (EMBHandleInUse) THEN
            ErrorCode := FreeEMBMemory( EMBHandle );
        END;

        HMAPresent     := FALSE;
        XMSShutDown();

    END;

    IF (ADDRESS(OldExitProc) <> NIL) THEN
        OldExitProc( PList, A );    (* WARNING!!  COULD BE DUMPING HERE!! *)
    END;

END TLXMSShutDown;





    (* Allocate UMB Memory -

            Preconditions  - none
            Postconditions - If enough memory is found, it is allocated.

            Input
                    Desired Paragraphs  - # of paras desired
            Output
                    FoundSegment        - Segment number of memory block
                    RETURN              - TRUE  iff found
                                          FALSE iff not found.
    *)
PROCEDURE XAllocateUMBMemory(     DesiredParas : CARDINAL;
                              VAR FoundSegment : CARDINAL
                             ) : BOOLEAN;
VAR
    FoundParas,
    ErrorCode   : CARDINAL;
BEGIN
    IF (KlugeRunning) THEN
        RETURN FALSE;
    ELSE
        FoundParas := DesiredParas;
        ErrorCode  := GetUMBMemory( FoundParas, FoundSegment );
        IF (ErrorCode = 0) AND (FoundParas <> DesiredParas) THEN
            ErrorCode := FreeUMBMemory( FoundSegment );
            ErrorCode := 1;  (* not enough room *)
        END;
    END;

    RETURN (ErrorCode = 0);

END XAllocateUMBMemory;






    (* Allocate UMB Memory -

            Preconditions  - Segment was obtained from AllocateUMBMemory.

            Postconditions - Memory returned to UMB pool.

            Input
                    Segment             - Segment number of memory block
            Output
                    RETURN              - TRUE  iff ok
                                          FALSE iff not ok.
    *)
PROCEDURE XDeAllocateUMBMemory( UMBSegment : CARDINAL
                              ) : BOOLEAN;
VAR
    ErrorCode   : CARDINAL;
BEGIN
    IF (KlugeRunning) THEN
        RETURN FALSE;
    ELSE
        ErrorCode := FreeUMBMemory( UMBSegment );
        RETURN (ErrorCode = 0);
    END;

END XDeAllocateUMBMemory;







    (* UMB Available

        Largest single block of UMB available.  In Paragraphs.
    *)
PROCEDURE XUMBAvailable() : CARDINAL;
VAR
    FoundParas,
    FoundSegment,
    DesiredParas,
    ErrorCode       : CARDINAL;
BEGIN
    FoundParas := 0;
    IF (NOT KlugeRunning) THEN
        DesiredParas := 0FFFFH;
        FoundParas   := DesiredParas;
        ErrorCode    := GetUMBMemory( FoundParas, FoundSegment );
        IF (ErrorCode = 0) THEN
            ErrorCode := FreeUMBMemory( FoundSegment );
        END;
    END;

    RETURN FoundParas;

END XUMBAvailable;



    (* 12-Jun-91 RSC Changed to return the largest available block.
    *)
PROCEDURE XEMBAvailable( VAR TotalKB : CARDINAL ) : CARDINAL;
VAR
    i, j,
    ErrorCode,
    LargestKB,
    FreeKB      : CARDINAL;
BEGIN
    IF (NOT KlugeRunning) THEN
        TotalKB := EMBTotalEverFree;  (* Total we could have ever gotten *)

        LargestKB := 0;
        FreeKB  := 0;
        FOR i   := 1 TO NumberOfEMBPageSets DO
            FOR j := 0 TO 255 DO
                IF (j IN EMBPageSets[i]) THEN
                    INC(FreeKB, EMBPageSizeInKB);
                    IF (LargestKB  < FreeKB) THEN   (* 12-Jun-91 RSC  *)
                        LargestKB := FreeKB;
                    END;
                ELSE                                           (* 25-Sep-91 *)
                    FreeKB  := 0;
                END;
            END;
        END;

    ELSE
        TotalKB   := 0;
        LargestKB := 0;
    END;

    RETURN LargestKB;

END XEMBAvailable;





    (* Allocate EMB Memory -

            Preconditions  - none
            Postconditions - If enough memory is found, it is allocated.

            Input
                    Desired bytes       - # of bytes desired
            Output
                    StartingByte        - Starting byte to use, if TRUE.
                    RETURN              - TRUE  iff found
                                          FALSE iff not found.
    *)
PROCEDURE XAllocateEMBMemory(     DesiredBytes : CARDINAL;
                              VAR StartingByte : LONGINT
                            ) : BOOLEAN;
CONST
    EMBPageSizeInBytes = EMBPageSizeInKB * 1024;
VAR
    Low, High,
    PagesWanted : CARDINAL;
    ok          : BOOLEAN;
BEGIN
    PagesWanted := DesiredBytes DIV EMBPageSizeInBytes;
    IF ((DesiredBytes MOD EMBPageSizeInBytes) > 0) THEN
        INC(PagesWanted);
    END;

    ok := GetEMB( PagesWanted, Low, High );
    IF (ok) THEN
        StartingByte := VAL(LONGINT,Low * EMBPageSizeInKB) * 1024L;
        SetEMB( Low, High, FALSE );
    END;

    RETURN ok;

END XAllocateEMBMemory;




    (* DeAllocate EMB Memory -

            Preconditions  - memory was obtained from AllocateUMBMemory.

            Postconditions - Memory returned to EMB pool.

            Input
                    StartingByte        - returned from AllocateEMBMemory.
                    Length              - "DesiredBytes" requested from
                                          AllocateEMBMemory.
            Output
                    none.
    *)
PROCEDURE XDeAllocateEMBMemory(     StartingByte : LONGINT;
                                    Length       : CARDINAL );
CONST
    EMBPageSizeInBytes = EMBPageSizeInKB * 1024;
VAR
    PagesUsed,
    Low, High   : CARDINAL;
BEGIN
    PagesUsed := Length DIV EMBPageSizeInBytes;
    IF ((Length MOD EMBPageSizeInBytes) > 0) THEN
        INC(PagesUsed);
    END;

    Low  := VAL(CARDINAL, (StartingByte DIV 1024L) ) DIV EMBPageSizeInKB;
    High := (Low + PagesUsed) - 1;

    SetEMB( Low, High, TRUE );

END XDeAllocateEMBMemory;





    (* Copy EMB Memory To DOS

            Preconditions  - memory was obtained from AllocateUMBMemory.
                             DOS address is valid and you "own" it.
    *)
PROCEDURE XEMBCopyToDOS( StartingByte : LONGINT;
                         Length       : CARDINAL;
                         ToHere       : ADDRESS );
BEGIN
    IF (CopyEMBToDOS( EMBHandle,
                      StartingByte,
                      VAL(LONGINT,Length),
                      ToHere ) <> 0) THEN
        HALT;
    END;
END XEMBCopyToDOS;



    (* Copy EMB Memory From DOS

            Preconditions  - memory was obtained from AllocateUMBMemory.
                             DOS address is valid and you "own" it.
    *)
PROCEDURE XEMBCopyFromDOS( StartingByte : LONGINT;
                           Length       : CARDINAL;
                           FromHere     : ADDRESS );
BEGIN
    IF (CopyDOSToEMB( EMBHandle,
                      StartingByte,
                      VAL(LONGINT,Length),
                      FromHere ) <> 0) THEN
        HALT;
    END;
END XEMBCopyFromDOS;










(* Steal the ALLOCATE vector.  Decide if we give HMA memory, or
   DOS/UMB memory.
*)
PROCEDURE XALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN

    IF (NOT KlugeRunning)                 AND
       (ProgramState = TLMainRunning)     AND
       (size <> TSIZE(ACellBlock))        AND
       (size <> TSIZE(OverlayDescriptor)) AND
       (Avail(ABlock(XMSStatsRecord.HMAAddress),size)) THEN
        Alloc(ABlock(XMSStatsRecord.HMAAddress), A, size );
    ELSE
        OldALLOCATE( A, size );
    END;

END XALLOCATE;






VAR
    KlugeRunning    : BOOLEAN;



(* Steal the ALLOCATE vector.  Decide if the memory is HMA memory, or
   DOS/UMB memory.
*)
PROCEDURE XDEALLOCATE( VAR A : ADDRESS; size : CARDINAL );
VAR
    Segment : CARDINAL;
    ok      : BOOLEAN;
BEGIN
    IF (KlugeRunning) THEN
        A := NIL;  (* Pretend to deallocate *)
    ELSE
        Segment := A.SEGMENT;
        IF (Segment = XMSStatsRecord.HMAAddress.SEGMENT) THEN
            ok := DeAlloc( ABlock(XMSStatsRecord.HMAAddress), A, size );
        ELSE
            OldDEALLOCATE( A, size );
        END;
    END;

END XDEALLOCATE;






(* Get all the EMB we can or that the Customer wants us to get
   via the command line "EMB IS <kb>".

   RETURN FALSE if we get nothing, either because there is nothing,
                or the customer wants nothin, or there is an error.

   IF TRUE, Handle is the EMB Handle and AllocatedKB is the allocatedKB.
*)
PROCEDURE GrabAllKnownEMB( VAR Handle       : CARDINAL;
                           VAR AllocatedKB  : CARDINAL ) : BOOLEAN;
VAR
    ErrorCode,
    MaxFree,
    i,
    DesiredMaxKB    : CARDINAL;
    Option          : ARRAY [0..9]  OF CHAR;
    Param           : ARRAY [0..29] OF CHAR;
    Found           : BOOLEAN;
BEGIN
    ErrorCode := EMBAvail( MaxFree, EMBTotalEverFree ); (* 21-Mar-91 RSC  *)

    IF (ErrorCode = 0) THEN

        AllocatedKB := MaxFree;

        IF (AllocatedKB > 64) THEN
            DEC(AllocatedKB,64);     (* 8-Jul-91 RSC reserve 64K for TLGS *)
        END;

        SetString(Option, "EMB");   (* 29-Aug-91 TGS *)
        GetOption( Option, Found, Param );
        IF (Found) THEN
            i            := 1;
            DesiredMaxKB := StoC( Param, i );
            IF (AllocatedKB >  DesiredMaxKB) THEN
                AllocatedKB := DesiredMaxKB;
            END;
        END;

            (* 29-Aug-91 TGS: *)
        AllocatedKB := EMBPageSizeInKB * (AllocatedKB DIV EMBPageSizeInKB);

        IF (AllocatedKB >  MaxAllowedEMBKB) THEN
            AllocatedKB := MaxAllowedEMBKB;
        ELSIF (AllocatedKB = 0) THEN
            RETURN FALSE;
        END;

        ErrorCode := GetEMBMemory( AllocatedKB, Handle );
    END;

    RETURN (ErrorCode = 0);

END GrabAllKnownEMB;




PROCEDURE SetEMB( Low, High : CARDINAL; MakeFree : BOOLEAN );
VAR
    TheSet,
    TheItem,
    i           : CARDINAL;
BEGIN
    FOR i := Low TO High DO
        TheSet  := (i DIV 256) + 1;
        TheItem :=  i MOD 256;
        IF (MakeFree) THEN
            INCL(EMBPageSets[TheSet],TheItem);
        ELSE
            EXCL(EMBPageSets[TheSet],TheItem);
        END;
    END;
END SetEMB;






PROCEDURE GetEMB(     PagesDesired : CARDINAL;
                  VAR Low, High    : CARDINAL ) : BOOLEAN;
VAR
    Found,
    i, j    : CARDINAL;
BEGIN
    Found := 0;
    FOR i := 1 TO NumberOfEMBPageSets DO
        FOR j := 0 TO 255 DO
            IF (j IN EMBPageSets[i]) THEN
                INC(Found);
                IF (Found = 1) THEN
                    Low := (i-1) * 256 + j;
                END;
                IF (Found = PagesDesired) THEN
                    High := (i-1) * 256 + j;
                    RETURN TRUE;
                END;
            ELSE
                Found := 0;
            END;
        END;
    END;

    RETURN FALSE;

END GetEMB;





PROCEDURE EMBInit();
VAR
    i   : CARDINAL;
BEGIN
    EMBHandleInUse := GrabAllKnownEMB( EMBHandle, i );

    IF (EMBHandleInUse) THEN
        EMBPages            := i DIV EMBPageSizeInKB;
        IF (EMBPages >  MaxAllowedEMBPages) THEN    (* 9-Apr-91 RSC added *)
            EMBPages := MaxAllowedEMBPages;
        END;

        EMBAvailable        := XEMBAvailable;
        AllocateEMBMemory   := XAllocateEMBMemory;
        DeAllocateEMBMemory := XDeAllocateEMBMemory;
        EMBCopyToDOS        := XEMBCopyToDOS;
        EMBCopyFromDOS      := XEMBCopyFromDOS;

        SetEMB( 0, EMBPages - 1, TRUE );    (* 9-Apr-91 RSC added -1 *)
        IF (EMBPages < (MaxAllowedEMBPages - 1)) THEN
            SetEMB( EMBPages, MaxAllowedEMBPages - 1, FALSE );  (* 9-Apr-91 RSC removed +1 *)
        END;
    END;

END EMBInit;






BEGIN
    OldExitProc     := RTDProc(NIL);
    EMBHandleInUse  := FALSE;   (* 8-Jul-91 RSC used in early shutdown *)

    IF (XMSAvailable()) THEN

        (* Uh, there is a slight problem deallocating memory from within
           the root when the overlay exits.  For now, we kluge big time.
           This is highly dangerous and suspect code.  Kids, don't do this
           at home!!
        *)
        IF (XMSStatsRecord.HMAMemoryDetected) THEN
            OldALLOCATE         := ALLOCATE;
            OldDEALLOCATE       := DEALLOCATE;
            ALLOCATE            := XALLOCATE;
            DEALLOCATE          := XDEALLOCATE;
            HMAPresent          := TRUE;
        END;

        KlugeRunning        := FALSE;  (* Look for other "KlugeRunning"s!! *)

        IF (XMSStatsRecord.UMBMemoryDetected) THEN
            AllocateUMBMemory   := XAllocateUMBMemory;
            DeAllocateUMBMemory := XDeAllocateUMBMemory;
            UMBAvailable        := XUMBAvailable;
        END;

        EMBHandleInUse          := FALSE;
        IF (XMSStatsRecord.EMBMemoryDetected) THEN
            EMBInit();
        END;

        (* This is the RIGHT way to do this! *)

(*        IF (HMAFreeList <> NIL) THEN  (* These are only needed for HMA. *)*)
(*            InstallNewProcedure( ADR(ALLOCATE),  PROC(XALLOCATE),  ADR(OldALLOCATE));*)
(*            InstallNewProcedure( ADR(DEALLOCATE),PROC(XDEALLOCATE),ADR(OldDEALLOCATE));*)
(*        END;*)

        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), SetUpShutDown );
    ELSE
        TLXMSShutDown(PROCESS(NIL), NIL );  (* In case anything was allocated. *)
    END;

END TLXMS.

