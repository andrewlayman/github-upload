IMPLEMENTATION MODULE XEmsStorage;

(*  =========================================================================
    Last Edit : May 8, 1991 10:01PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        Implementation of the EMS driver, EmsStorage.  This is bound into
        TLEms.


    MODIFICATION HISTORY:

         8-Aug-89  RSC  First version.
         5-Dec-89  RSC  Cleaned up EXIT TO DOS code by only noticing
                        BeforeActing, not NOT noticing AfterActing.
         8-Jan-90  AJL  Removed the tests of what looks like a valid EMS
                        handle.  Evidently, each driver can have any
                        number system it likes.  Test with Compaq's CEMM. 
        23-Feb-90  RSC  Fixed bug when no EMS pages available.  We were
                        reallocating page 0.
        23-Mar-90  RSC  1) When customer asks for more EMS than there is
                           (say, they have 20 EMSPAGES and say EMSPAGES=40)
                           we give them error 136.  Instead, just give them
                           as much as they have.
                        2) Always try to set aside a vacant page for
                           unmapping, and if it cannot be allocated do not
                           attempt to remap pages to the vacant page.
                        3) Save the page map AFTER remapping pages to the
                           vacant page.
        23-Sep-90  RSC  Hmmmm. I seem to fix this module on the 23rd of the
                        month, only.  Anyway, allow TLGS to get 4 pages of
                        EMS iff there are more than a few pages for us,
                        and iff the customer does not specify an EMSPAGES
                        parameter.  I tried to pick a number where a 1MB
                        machine could use the EMS pages for TLGS.
        12-Nov-90 TGS   Merge changes made to 4.03.
        23-Mar-91 RSC   (What tha?  Its the 23'rd again!!)
                        Fixed bug in my 23-Sep change, where I was lowering
                        the wrong variable to free up space for TLGS.
                        In addition, I lower by another 4 pages to make room
                        for the HMA, in case (as is the case now) the XMS
                        driver is loaded after this driver.
         8-May-91 RSC   Lowered the max pages to 312 from 512.  This way,
                        If you have more than 5MB of EMS the rest is unused,
                        which could mean it is usable for Extended memory
                        which is used for overlay swapping.
        26-Aug-91 LAA   If there are fewer than 4 physical pages of EMS,
                        don't die, just complain about it.  This can happen
                        when running under Windows.
        29-Aug-91 LAA   Well, under Windows it doesn't actually tell you
                        that there's no physical pages, it just gives you
                        pages which reside in low memory (< 640K).  So, if
                        the first page is < A000H, pretend that EMS isn't
                        working.  Bug #4841.
    =========================================================================
*)





FROM Dialog         IMPORT
    (* PROC *)          Error, FatalError;

FROM EMSCalls       IMPORT
    (* PROC *)          EMSGetStatus,  
                        EMSGetUnallocatedPages, EMSAllocatePages,
                        EMSPageMap, EMSDeallocatePages,
                        EMSGetFrameAddresses,
                        EMSSavePageMap, EMSRestorePageMap;

FROM EmsStorage     IMPORT
    (* CONST *)         EMSPageSizeInBytes, NilEMSHandle,
    (* TYPE *)          AnEmsHandle, AnEmsPriority, AnEmsPageFrameRequest,
    (* PROC *)          EMSAllocate, EMSDeAllocate, EMSLock, EMSUnLock,
                        EMSStatistics, EMSFrameRequest;

FROM LStrings       IMPORT
    (* PROC *)          StoC, ConcatLS, CtoS, SetString;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          SendNotices, RegisterForNotices;

FROM Overlays       IMPORT
    (* PROC *)          InstallNewProcedure;

FROM ParmLine       IMPORT
    (* PROC *)          GetOption;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, ADR;




CONST
    ModuleNumber            = 23200;  (* Was formerly assigned to TLEMS. *)

    MinPages                = 4;      (* We must have these many to run. *) 
        (* 8-May-91 RSC From 512 (8MB) to 312 (about 5MB) *)
    MaxPageNumber           = 312;    (* Maximum number of EMS pages to manage. *)
    PhysicalPages           = 4;
    OurPageSizeInK          = 16;

        (* 23-Sep-90 RSC *)     (* 23-Mar-91 RSC made 8 from 4 *)
    TLGSAndHMAPagesDesired  =  8;     (* Give this many to TLGS and the HMA *)

        (* 29-Aug-91 LAA  Windows will give back frame addresses which reside
            in the lower 640K when using QEMM and FRAME=NONE.  This causes
            Window to abort Time Line.  This constant allowes us to do a
            disaster check on the actual page frame addresses returned.  I set
            is at the 512K mark just in case some customer can actually run
            Time Line in that little memory, and has EMS.
        *)
    LowestReasonablePageFrame = 08000H;  

TYPE
    APhysicalPageNumber     = [0..PhysicalPages-1];



VAR
        (* LogicalPageNumber contains NilEMSHandle if the physical
           page does not contain a logical page, or the logical
           page's number if it does.
        *)
    LogicalPageNumber       : ARRAY APhysicalPageNumber OF CARDINAL;


        (* This is the base address and mapping of the EMS memory.
        *)
    AddressOfPage           : ARRAY APhysicalPageNumber OF ADDRESS;

    EMSSystemHandle         : CARDINAL;

    AvailablePages          : ARRAY [0..(MaxPageNumber DIV 16)-1] OF BITSET;
    HighPriPages            : ARRAY [0..(MaxPageNumber DIV 16)-1] OF BITSET;

    MaxPages                : CARDINAL;
    UnusedPages             : CARDINAL;
    UnusedPagesOfHighPri    : CARDINAL;
    VacantPage              : CARDINAL;    (* Page number of an unused page. *)

    Interlock               : CARDINAL;
    Initialized             : BOOLEAN;
    Sleeping                : BOOLEAN;  (* Pages unmapped during task switch. *)





PROCEDURE Complain( N : CARDINAL );
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    IF (Interlock = 0) THEN
        INC(Interlock);
        GetMessage(N,S);
        Error(S); 
        DEC(Interlock);
    END;
END Complain;







PROCEDURE TestPhysicalPage( PageNumber : CARDINAL ) : BOOLEAN;
TYPE
    ABlankPage         = ARRAY [0..(OurPageSizeInK DIV 2)-1] OF CARDINAL; 
    ABlankPagePointer  = POINTER TO ABlankPage; 

VAR 
    BlankPage               : ABlankPagePointer;
    i,j                     : CARDINAL; 
    S                       : ARRAY [0..81] OF CHAR;
    S2                      : ARRAY [0..5] OF CHAR; 
BEGIN 
    BlankPage := ABlankPagePointer(AddressOfPage[PageNumber]);
    FOR j := 0 TO HIGH(BlankPage^) DO 
        BlankPage^[j] := j; 
        IF (BlankPage^[j] <> j) THEN  
            Complain(ModuleNumber+4);  (* EMS memory hardware failure *)
            RETURN FALSE; 
        END;
    END;
    
    RETURN TRUE;

END TestPhysicalPage; 








PROCEDURE FreePhysicalPage(VAR PhysicalPage : CARDINAL): BOOLEAN;

BEGIN                       (* FreePhysicalPage *)

        (* Search the mapped buffers for an unused one. *)

    PhysicalPage := 0;
    WHILE (PhysicalPage < PhysicalPages) DO
        IF (LogicalPageNumber[PhysicalPage] = NilEMSHandle) THEN
            RETURN TRUE;
        END;
        INC(PhysicalPage);
    END;

    RETURN FALSE;

END FreePhysicalPage;







PROCEDURE AllocateLogicalPage(VAR LogicalPage : CARDINAL;
                                  EmsPriority : AnEmsPriority ): BOOLEAN;

BEGIN                       (* AllocateLogicalPage *)

    IF (UnusedPages <> 0) THEN
        LogicalPage := 0;   (* 23-Feb-90 RSC moved from two lines above. *)
        WHILE (LogicalPage < MaxPages) DO
            IF ((LogicalPage MOD 16) IN (AvailablePages[LogicalPage DIV 16])) THEN
                EXCL(AvailablePages[LogicalPage DIV 16], LogicalPage MOD 16);
                DEC(UnusedPages);
                IF (EmsPriority = HighEmsPriority) THEN
                    DEC(UnusedPagesOfHighPri);
                    INCL(HighPriPages[LogicalPage DIV 16], LogicalPage MOD 16);
                END;
                RETURN TRUE;
            END;
            INC(LogicalPage);
        END;
        FatalError();  (* Should have been one free *) (* 23-Feb-90 RSC *)
    END;

    RETURN FALSE;

END AllocateLogicalPage;







PROCEDURE DeallocateLogicalPage(    LogicalPage : CARDINAL);

BEGIN                       (* DeallocateLogicalPage *)

    INCL(AvailablePages[LogicalPage DIV 16], LogicalPage MOD 16);
    INC(UnusedPages);
    IF ((LogicalPage MOD 16) IN HighPriPages[LogicalPage DIV 16]) THEN
        EXCL(HighPriPages[LogicalPage DIV 16], LogicalPage MOD 16);
        INC(UnusedPagesOfHighPri);
    END;

END DeallocateLogicalPage;







    (* Prepare ourselves for an exit to DOS or other horrible
       possibility that some other program might use EMS. *)

PROCEDURE PrepareForTaskSwitch() : BOOLEAN;
VAR
    PhysicalPage : APhysicalPageNumber;
BEGIN
    WakeUp();
    IF (NOT EMSFrameRequest(AllEmsPageFrames)) THEN
        RETURN FALSE;
    END;

    FOR PhysicalPage := 0 TO MAX(APhysicalPageNumber) DO
        IF (LogicalPageNumber[PhysicalPage] = NilEMSHandle) AND
           ( (VacantPage = NilEMSHandle) OR
             (EMSPageMap(EMSSystemHandle,VacantPage,PhysicalPage))) THEN   (* Remove from maps. *)
        ELSE
            Complain(ModuleNumber+8);  (* Pages still mapped. *)
            RETURN FALSE;
        END;
    END;
    
    IF (NOT EMSSavePageMap(EMSSystemHandle)) THEN   (* 23-Mar-90 RSC was before loop. *)
        RETURN FALSE;
    END;

    Sleeping := TRUE;

    RETURN TRUE;

END PrepareForTaskSwitch;








PROCEDURE NoticeExitToDOS(     Occasion : AnOccasion;
                               Step     : AStep;
                               Context  : ADDRESS ):BOOLEAN;
BEGIN

    IF (Step = BeforeActing) AND (NOT Sleeping) THEN       (* Really free up memory. *)
        RETURN PrepareForTaskSwitch();
    END;
 
    RETURN TRUE;

END NoticeExitToDOS;






PROCEDURE XEmsStorageStartUp() : BOOLEAN;
VAR
    DesiredMaxPages,
    i                       : CARDINAL;
    S2,
    Option,
    Param                   : ARRAY [0..39] OF CHAR;
    S                       : ARRAY [0..255] OF CHAR;
    ok,
    RequestedSomePages      : BOOLEAN;         (* User specified number of pages. *)

BEGIN

    ok := (EMSGetStatus() = 0);               (* EMS ok? *)

    IF (ok) THEN
        MaxPages := EMSGetUnallocatedPages();

        IF (MaxPages > MaxPageNumber) THEN
            MaxPages := MaxPageNumber;
        END;

        GetMessage( ModuleNumber + 1, Option );  (* "EMSPAGES" *)
        GetOption( Option, RequestedSomePages, Param );
        IF (RequestedSomePages) THEN
            i               := 1;
            DesiredMaxPages := StoC( Param, i );
            IF (DesiredMaxPages < MinPages) THEN
                RETURN FALSE; 
            END;
            IF (MaxPages >  DesiredMaxPages) THEN
                MaxPages := DesiredMaxPages;
            ELSIF (MaxPages < DesiredMaxPages) THEN (* 23-Mar-90 RSC *)
                DesiredMaxPages := MaxPages;
            END;
        ELSE
                (* 23-Sep-90 RSC *)

            IF (MaxPages > TLGSAndHMAPagesDesired) THEN
                DEC(MaxPages, TLGSAndHMAPagesDesired);
            END;

            DesiredMaxPages := MaxPages;    (* 23-Mar-91 RSC Moved from above *)
        END;

        IF (MaxPages > 0) AND  (* RSC 23-Mar-89 *)
           (MaxPages < MinPages) THEN 
            Complain(ModuleNumber+5);   (* Too few pages. *)
        END;

        ok := (MaxPages >= MinPages);

    END;

    IF (ok) THEN
        UnusedPages          := MaxPages;
        UnusedPagesOfHighPri := MaxPages;

        FOR i := 0 TO HIGH(AvailablePages) DO
            AvailablePages[i] := {};
            HighPriPages[i]   := {};
        END;

        i := EMSGetFrameAddresses(AddressOfPage);
        IF ((i < PhysicalPages) OR                             (* 26-Aug-91 *)
           (AddressOfPage[0].SEGMENT < LowestReasonablePageFrame)) THEN  (* 29-Aug-91 *)
            RETURN FALSE;
        END;

        FOR i := 0 TO MaxPages - 1 DO
            INCL(AvailablePages[i DIV 16], i MOD 16);
        END;

            (* Grab all the pages, now, while we have a chance. *)

        IF (NOT EMSAllocatePages(MaxPages, EMSSystemHandle)) THEN
            Complain(ModuleNumber+6);
            RETURN FALSE;
        END;

            (* EMS 4.0 shouldn't return 0.  3.x might. *)
        (* Testing reveals that some boards return handles > 0FFH, but
           work properly.  The Ray Duncan "Advanced MS-DOS" book says that
           the Intel AboveBoard uses handles starting with 0FF01, or so. *)
        (*-------
        IF (EMSSystemHandle > 0FFH)  (*<DEBUGGING  OR (EMSSystemHandle = 0)  DEBUGGING>*)
        THEN
            IF (Interlock = 0) THEN
                INC(Interlock);
                GetMessage(ModuleNumber+7,S);
                CtoS(EMSSystemHandle,S2);
                ConcatLS(S,S2);
                Error(S);
                DEC(Interlock);
            END;
            RETURN FALSE;
        END;
        --------*) 


        (* This loop does two things: first, it clears the LogicalPageNumber
           array.  Second, it tests each page in the page frame.   We test  
           the page frame during startup to catch overtly bad hardware or 
           drivers, and so that we can exit gracefully, turning over the
           virtual memory to the disk swapping. *)

        FOR i := 0 TO PhysicalPages - 1 DO

                (* No logical page is assigned yet to a physical address.
                *)
            LogicalPageNumber[i] := NilEMSHandle;

                (* Test the EMS memory within the page frame.
                   Map a page into the page frame.
                *)
            IF EMSPageMap(EMSSystemHandle,i,i) THEN 
                    (* Test the EMS memory within the page frame. *)
                IF (NOT TestPhysicalPage(i)) THEN 
                    EMSDeallocatePages(EMSSystemHandle);
                    RETURN FALSE; 
                END;
            ELSE
                EMSDeallocatePages(EMSSystemHandle);
                RETURN FALSE; 
            END;
        END;


        (* This may seem wierd, but some EMS drivers do not actually allow
           us to unmap pages, even though the specs say they can.  So, if
           possible, rather than unmap pages, we map them to a page we
           aren't using.

           See the PrepareForTaskSwitch routine.  

           (* 23-Mar-90 RSC Always try to get a vacant page, even when
                            a specific number of pages is requested.
           *)
         *)

        IF (NOT AllocateLogicalPage(VacantPage,HighEmsPriority)) THEN
            VacantPage := NilEMSHandle;
        END;

        Initialized := TRUE;
        Sleeping    := FALSE;
    END;

    RETURN ok;

END XEmsStorageStartUp;





PROCEDURE XEmsStorageShutDown();
BEGIN
    EMSDeallocatePages(EMSSystemHandle);
    Initialized := FALSE;
END XEmsStorageShutDown;







    (* ------------------------------------------------------------------

       WakeUp

       Make sure that we are initialized and that our pages are mapped
       in.

     --------------------------------------------------------------------- *) 


PROCEDURE WakeUp();
BEGIN
    IF (NOT Initialized) THEN 
        FatalError();
    END;

    IF (Sleeping) THEN
        IF (EMSRestorePageMap(EMSSystemHandle)) THEN
            Sleeping := FALSE;
        END;
    END;
END WakeUp;







PROCEDURE XEMSAllocate( VAR EmsHandle   : AnEmsHandle;
                            EmsPriority : AnEmsPriority ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
BEGIN

    WakeUp();
    EmsHandle := NilEMSHandle;

    (* Game Plan:

       Try to allocate a really free page.
       If I cannot, AND there are pages out there that are not hi pri,
       AND this is not a LOW pri request, then
            send a low memory notice, and try to allocate a page again.
    *)
    IF (NOT AllocateLogicalPage( EmsHandle, EmsPriority )) AND
       (UnusedPagesOfHighPri <> 0)                         AND
       (EmsPriority <> LowEmsPriority) THEN
        SendNotices( EMSLowMemory, BeforeActing, ADR(EmsPriority) );
        ok := (AllocateLogicalPage( EmsHandle, EmsPriority ));
    END;
    RETURN (EmsHandle <> NilEMSHandle);

END XEMSAllocate;





PROCEDURE XEMSUnLock(    EmsHandle     : AnEmsHandle;
                         FrameHandle   : CARDINAL    );
BEGIN

    WakeUp();

(*$R+*)  (* Also check for valid frame handles in this cheap way. *)
    IF (LogicalPageNumber[FrameHandle] <> EmsHandle) THEN
        FatalError();  (* Page was not locked. *)
    END;
(*$R=*)

    LogicalPageNumber[FrameHandle] := NilEMSHandle;

END XEMSUnLock;







PROCEDURE XEMSDeAllocate( VAR EmsHandle     : AnEmsHandle );
BEGIN
    WakeUp();
    DeallocateLogicalPage( EmsHandle );
    EmsHandle := NilEMSHandle;
END XEMSDeAllocate;










(* Lock an EMS page down into a page frame.  Return the address of the
   page frame.
*)
PROCEDURE XEMSLock(     EmsHandle     : AnEmsHandle;
                    VAR PageFrame     : ADDRESS;
                    VAR PhysicalPage  : CARDINAL ) : BOOLEAN;
BEGIN
    WakeUp();

    PageFrame := NIL;

    (* Is there a free page frame?
       If no page is free that we can find right away, try
       requesting a free frame and then look for a free frame again.
       Note the non-trivial (x OR (y AND z)) test.
    *)
    IF (FreePhysicalPage(PhysicalPage)) OR
       (EMSFrameRequest(OneEmsPageFrame) AND
        FreePhysicalPage(PhysicalPage)) THEN

        IF (EMSPageMap(EMSSystemHandle, EmsHandle, PhysicalPage)) THEN
            PageFrame := AddressOfPage[ PhysicalPage ];
            LogicalPageNumber[PhysicalPage] := EmsHandle;
        END;
    END;
    RETURN (PageFrame <> NIL);

END XEMSLock;






PROCEDURE XEMSStatistics( VAR TotalPages,
                              FreePages,
                              HighPriFree    : CARDINAL );
BEGIN
    TotalPages  := MaxPages;
    FreePages   := UnusedPages;
    HighPriFree := UnusedPagesOfHighPri;
END XEMSStatistics;








BEGIN
    Initialized := FALSE;
    Sleeping    := FALSE;
    Interlock   := 0;

    InstallNewProcedure(ADR(EMSAllocate   ),PROC(XEMSAllocate  ), NIL);
    InstallNewProcedure(ADR(EMSDeAllocate ),PROC(XEMSDeAllocate), NIL);
    InstallNewProcedure(ADR(EMSLock       ),PROC(XEMSLock      ), NIL);
    InstallNewProcedure(ADR(EMSUnLock     ),PROC(XEMSUnLock    ), NIL);
    InstallNewProcedure(ADR(EMSStatistics ),PROC(XEMSStatistics), NIL);


        (* Release our mapped pages whenever we might do an
           exit to DOS. *)

    RegisterForNotices( ExitToDOS,   NoticeExitToDOS );

END XEmsStorage.



Notes to the changes of 9-Mar-89 AJL:

This diskette contains a copy of TLEMS.OVL, the EMS memory manager for
Time Line 3.0.  It has been modified from the standard driver in order
to check the EMS driver and hardware for proper operation.  In my opinion,
this should not have been necessary, since it is irresponsible programming 
by whoever wrote the EMS Driver (e.g. Boca) to publish a driver that doesn't
even verify that the hardware is operational.  However, since such crummy
drivers exist, we will check them.
   The check consists of writing sequentially increasing 16-bit numbers to
each of the 8,192 word locations in each page of the page frame, and 
reading those same words back, verifying that they match.  If they do not,
a warning is issued, and our EMS driver will exit from memory, permitting
the program to continue operating, albeit with disk swapping instead of EMS.
   The page frame is tested when the program is started by mapping pages 
zero through three and checking them.  Each subseqent page is check when
allocated.
   Since this test does not verify the high-order 2 bits of any word, and 
only tries one bit pattern per word (in an unsophisticated manner), 
and does not check for delayed alteration of memory contents, it is hardly 
foolproof, particularly if other device hardware is also mapped to the same 
memory address but is not active during the check out.  For example, a 
commumincations device could alter the memory contents, yet not be operating 
during the test.
    Nonetheless, this should catch all cases of clearly non-operational 
hardware or drivers, and most cases of semi-operation.
    One case that is not caught be this test, or by Time Line at all: if
the user thinks that he has an EMS board installed, but the board is not
installed, or the EMS driver is not working or was omitted from the 
CONFIG.SYS file, then Time Line will merely detect the absence of EMS 
and will procede to use disk swapping, without any alarms to the user.


