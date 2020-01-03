IMPLEMENTATION MODULE EmsFlexStor;

(*  =========================================================================
    Last Edit : August 23, 1989 11:58AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        This is the FlexStor Page Supply for EMS.  It was based on the old
        TLEMS.

    MODIFICATION HISTORY:

     8-Aug-89   RSC  -First version.

    21-Aug-89   RSC  -Change meaning of GetExtStatus to return Quezey if
                      we are low on space or interlocked.  Before it only
                      returned queazy if interlocked.  This provides us
                      with a kind of "FlexAvailable" call.

    22-Aug-89   RSC  -Bug in Retrieve Page which invalidates the frame handle.
                      Removed offending bug.  Caused FatalErrors sometimes.

    23-Aug-89   RSC  -Bug in Exit To DOS logic.  Caused permission to be
                      denied.

    25-Sep-89   LAA  -Return a status of BAD when interlocked.  This will
                      allow Rugs to still get space for a rug even when we're
                      low on space, but not when we're interlocked.
    =========================================================================
*)




FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM EmsStorage             IMPORT
    (* CONST *)                 NilEMSHandle, EMSPageSizeInBytes,
    (* TYPE *)                  AnEmsPageFrameRequest, AnEmsHandle,
                                AnEmsPriority, AnEMSFrameRequest,
    (* PROC *)                  EMSFrameRequest, EMSAllocate, EMSDeAllocate,
                                EMSLock, EMSUnLock, EMSStatistics;

FROM FlexData               IMPORT
    (* TYPE *)                  APage, APagePointer, APageNo,
    (* VAR *)                   PageTable;

FROM FlexStor               IMPORT
    (* PROC *)                  InitExtStorage, MaximumRecordSize;

FROM LStrings               IMPORT
    (* PROC *)                  CtoS, ConcatLS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  InstallNewProcedure;

FROM PageSupply             IMPORT
    (* TYPE *)                  APageCreateProc, APageDiscardProc, 
                                APageRetrieveProc,
                                APageSynchProc,
                                AStartupProc, AShutdownProc, 
                                APageClassStatusProc, APageClass,
                                APageHandle, APageClassStatus,
    (* PROC *)                  CreatePage, DiscardPage, RetrievePage, 
                                SynchPage, PageClassStatus,
                                StartupPageClass, ShutdownPageClass;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR;




VAR
    OldCreatePage           : APageCreateProc;
    OldDiscardPage          : APageDiscardProc;
    OldRetrievePage         : APageRetrieveProc;
    OldSynchPage            : APageSynchProc;
    OldStartupPageClass     : AStartupProc;
    OldShutdownPageClass    : AShutdownProc;
    OldPageClassStatus      : APageClassStatusProc;
    OldEMSFrameRequest      : AnEMSFrameRequest;


CONST
    ModuleNumber            = 23200;  (* Was formerly assigned to TLEMS. *)
    OurPageClass            = PageMedium;
    EMSPageSizeInK          = (EMSPageSizeInBytes DIV 1024);


VAR
    Interlock           : CARDINAL;






MODULE LockedPageManager;

IMPORT
    (* CONST *)         NilEMSHandle,
    (* TYPE *)          ADDRESS, AnEmsHandle, AnEmsPageFrameRequest,
                        APagePointer, APageNo,
    (* VAR *)           PageTable,
    (* PROC *)          EMSUnLock;

EXPORT
    (* TYPE *)          AFrameCacheEntry,
    (* VAR *)           FrameCache,
    (* PROC *)          FindLockedPage, FindLockedPageByHandle,
                        InvalidateLockedPage, SetLockedPage,
                        XEMSFrameRequest;


CONST
    MaxFramesToCache        = 4;


TYPE
    AFrameCacheEntry        = RECORD
                                  FlexStorPageNumber    : CARDINAL;
                                  PageFrameAddress      : ADDRESS;
                                  EmsHandle             : AnEmsHandle;
                                  FrameHandle           : CARDINAL;
                              END;

VAR
    (* We keep a local cache of page frames locked down.
    *)
    FrameCache   : ARRAY [1..MaxFramesToCache] OF AFrameCacheEntry;




PROCEDURE FindLockedPage(     PageNo    : CARDINAL;
                          VAR WhereAt   : ADDRESS;
                          VAR LockEntry : CARDINAL ) : BOOLEAN;
VAR
    i   : CARDINAL;
    ok  : BOOLEAN;
BEGIN

    i  := 0;
    ok := FALSE;
    WHILE (i < HIGH(FrameCache)) AND (NOT ok) DO
        INC(i);
        ok := (FrameCache[i].FlexStorPageNumber = PageNo);
    END;

    IF (ok) THEN
        WhereAt   := FrameCache[i].PageFrameAddress;
        LockEntry := i;
    ELSE
        LockEntry := 0;   (* not found.  Signal to SetLockedPage. *)
    END;
    
    RETURN ok;

END FindLockedPage;






PROCEDURE FindLockedPageByHandle(     TheEmsHandle : AnEmsHandle;
                                  VAR LockEntry    : CARDINAL ) : BOOLEAN;
VAR
    i   : CARDINAL;
    ok  : BOOLEAN;
BEGIN

    i  := 0;
    ok := FALSE;
    WHILE (i < HIGH(FrameCache)) AND (NOT ok) DO
        INC(i);
        ok := (FrameCache[i].EmsHandle = TheEmsHandle);
    END;

    IF (ok) THEN
        LockEntry := i;
    ELSE
        LockEntry := 0;   (* not found.  Signal to SetLockedPage. *)
    END;
    
    RETURN ok;

END FindLockedPageByHandle;





PROCEDURE InvalidateLockedPage(     LockEntry : CARDINAL );
BEGIN
    FrameCache[LockEntry].FlexStorPageNumber := NilEMSHandle;
END InvalidateLockedPage;






PROCEDURE SetLockedPage(     LockEntry,
                             PageNo         : CARDINAL;
                             TheEmsHandle   : AnEmsHandle;
                             TheFrameHandle : CARDINAL;
                             WhereAt        : ADDRESS   ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
BEGIN

    (* Did it exist in our table?
    *)
    ok := (LockEntry <> 0);
    WHILE (NOT ok) AND (LockEntry < HIGH(FrameCache)) DO
        INC(LockEntry);
        ok := (FrameCache[LockEntry].FlexStorPageNumber = NilEMSHandle);
    END;

    IF (ok) THEN
        WITH FrameCache[LockEntry] DO
            PageFrameAddress   := WhereAt;
            EmsHandle          := TheEmsHandle;
            FlexStorPageNumber := PageNo;
            FrameHandle        := TheFrameHandle;
        END;
    END;
    
    RETURN ok;

END SetLockedPage;






(* The EMS manager (EMSStorage) wants a page frame back.  He may want one,
   or he may want all the frames back.  Try to do this for him.  Only do this
   for UNLOCKED frames, however.
*)
PROCEDURE XEMSFrameRequest( RequestType : AnEmsPageFrameRequest ) : BOOLEAN;
VAR
    Page    : APagePointer;
    i       : CARDINAL;
    ok      : BOOLEAN;
BEGIN
    i  := 0;
    ok := FALSE;
    WHILE (i < HIGH(FrameCache)) AND (NOT ok) DO
        INC(i);
        WITH FrameCache[i] DO
            IF (FlexStorPageNumber <> NilEMSHandle) THEN
                Page := PageFrameAddress;
                IF (Page^.Header.LockCount = 0) THEN

                    EMSUnLock( EmsHandle, FrameHandle );

                    (* Tell FlexStor that the page is no longer in the
                       buffer. *)
                    PageTable^[ FlexStorPageNumber ].Location := NIL;

                    FlexStorPageNumber := NilEMSHandle;

                    ok := (RequestType = OneEmsPageFrame);

                ELSIF (RequestType = AllEmsPageFrames) THEN
                    RETURN FALSE;  (* LOCKED PAGE WHEN REQUESTED TO FLUSH!! *)
                END;
            END;
        END;
    END;

    RETURN (ok OR (i = HIGH(FrameCache)));

END XEMSFrameRequest;






PROCEDURE InitLockedPageManager();
VAR
    i   : CARDINAL;
BEGIN
    FOR i := 1 TO HIGH(FrameCache) DO
        InvalidateLockedPage( i );
    END;
END InitLockedPageManager;




BEGIN
    InitLockedPageManager();
END LockedPageManager;






        (*-----------------------------------------------------------

            XCreatePage

            Attempts to create a new page of the indicated class.

            Preconditions:
                StartupPageStorage returned TRUE.

            PostConditions:
                Either returns XPageHandle to the newly created
                page, or else FALSE.   When a handle is returned,
                the page is mapped into normal memory and its address
                and size is also returned.



        -------------------------------------------------------------*)


PROCEDURE XCreatePage (     PageClass     : APageClass;
                            PageNo        : CARDINAL;
                        VAR Size          : CARDINAL     ) : BOOLEAN;
VAR
    Where,
    PageHandle              : ADDRESS;
    TotalPages,
    FreePages,
    HiPriFree,
    FrameHandle             : CARDINAL;
    TheEmsHandle            : AnEmsHandle;

    PROCEDURE Warn();
    VAR
        S                       : ARRAY [0..255] OF CHAR;
        S2                      : ARRAY [0..5]   OF CHAR;
    BEGIN
        INC(Interlock);
        GetMessage(ModuleNumber+2,S);        (*   EMS memory is nearly full." *)
        CtoS(HiPriFree,S2);
        ConcatLS(S,S2);
        ConcatMessage(S,ModuleNumber+3);     (*   pages remain. *)
        Error(S);
        DEC(Interlock);
    END Warn;

BEGIN                       (* XCreatePage *)

    IF (PageClass <> OurPageClass) THEN
        RETURN (OldCreatePage(PageClass, PageNo, Size ));
    ELSIF (Interlock = 0) THEN
        (*<DEBUGGING
        SetString(s, "Creating an EMS page.");
        Error(s);
        DEBUGGING>*)

        IF (EMSAllocate( TheEmsHandle, HighEmsPriority )) THEN
            IF (EMSLock( TheEmsHandle, Where, FrameHandle )) THEN
            
                PageHandle        := NIL;
                PageHandle.OFFSET := TheEmsHandle;

                WITH PageTable^[PageNo] DO
                    Location    := Where;
                    HomeAddress := APageHandle(PageHandle);
                END;

                Size := EMSPageSizeInBytes;

                EMSStatistics( TotalPages, FreePages, HiPriFree );

                IF (HiPriFree < 5) AND (StartupPageClass(PageSlow) = EMSPageSizeInBytes) THEN
                    Warn();
                END;

                RETURN SetLockedPage( 0, PageNo,
                                      TheEmsHandle, FrameHandle,
                                      Where );
            ELSE
                EMSDeAllocate( TheEmsHandle );
            END;
        END;

    END;

    RETURN FALSE;

END XCreatePage;






        (*-----------------------------------------------------------

            XDiscardPage

            Attempts to discard the page.

            Preconditions:
                The page handle must have been created by APageCreateProc.

            PostConditions:
                The page handle is no longer valid.

        -------------------------------------------------------------*)


PROCEDURE XDiscardPage (     PageClass  : APageClass;
                         VAR PageHandle : APageHandle ) : BOOLEAN;

VAR
    XPageHandle             : ADDRESS;
    LockEntry               : CARDINAL;
    TheEmsHandle            : AnEmsHandle;

BEGIN                       (* XDiscardPage *)

    IF (PageClass <> OurPageClass) THEN
        RETURN OldDiscardPage(PageClass, PageHandle);
    ELSE
        (*<DEBUGGING
        SetString(s, "Discarding an EMS page.");
        Error(s);
        DEBUGGING>*)

        XPageHandle  := ADDRESS(PageHandle);
        TheEmsHandle := XPageHandle.OFFSET;

        IF (FindLockedPageByHandle( TheEmsHandle, LockEntry )) THEN
            EMSUnLock( TheEmsHandle, FrameCache[LockEntry].FrameHandle );
            InvalidateLockedPage( LockEntry );
        END;

        EMSDeAllocate( TheEmsHandle );

        XPageHandle.OFFSET := NilEMSHandle;

        RETURN TRUE;
    END;

END XDiscardPage;


        (*-----------------------------------------------------------

            XRetrievePage

            Attempts to get the page.

            Preconditions:
                The page handle must have been created by APageCreateProc.

            PostConditions:
                The page will be mapped into physical memory of the
                current process, and the address of it is returned, or
                else FALSE.  Addresses are returned by filling in the
                PageTable^[PageNo].Location.

                The page will remain at this physical location until
                a subsequent call to AReleasePageProc.

        -------------------------------------------------------------*)


PROCEDURE XRetrievePage (     PageClass  : APageClass;
                              PageNo     : CARDINAL      ) : BOOLEAN;

VAR
    FrameHandle,
    LockEntry               : CARDINAL;
    WhereAt,
    PageHandle              : ADDRESS;
    (*<DEBUG>*)   Page      : APagePointer;  (*DEBUG>*)
    ok                      : BOOLEAN;
BEGIN                       (* XRetrievePage *)

    IF (PageClass <> OurPageClass) THEN
        ok := OldRetrievePage(PageClass, PageNo);
    ELSE
        PageHandle := ADDRESS(PageTable^[PageNo].HomeAddress);

        (* Find the page by first looking to see if we already have it.
           If we don't, then go on to see if we can get it.  Locking a
           page may involve our "XEMSFrameRequest" being called.
        *)
        ok := (FindLockedPage( PageNo, WhereAt, LockEntry )) OR
              (EMSLock(AnEmsHandle(PageHandle.OFFSET), WhereAt, FrameHandle ));
        IF (ok) THEN

            IF (LockEntry <> 0) THEN
                FrameHandle := FrameCache[LockEntry].FrameHandle; (* RSC 22-Aug-89 We already own the page. *)
            END;

            ok := SetLockedPage( LockEntry,
                                 PageNo,
                                 AnEmsHandle(PageHandle.OFFSET),
                                 FrameHandle,
                                 WhereAt );
            (*<DEBUG>*)
            Page := WhereAt;
            IF (NOT ok) OR (Page^.Header.PageNumber <> PageNo) THEN
                HALT; 
            END;  
            (*DEBUG>*)

            (* Return the answer by filling in FlexStor's page table. *)
            PageTable^[PageNo].Location := WhereAt;

        END;
    END;

    RETURN ok;

END XRetrievePage;







        (*-----------------------------------------------------------

            SynchPage

            Synchronizes all copies of the page.

            Preconditions:
                The page handle must have been created by APageCreateProc.

            PostConditions:
                Any copies of the page on secondary media will match
                any copy (if any) existing in physical memory, or else
                FALSE is returned.

        -------------------------------------------------------------*)

PROCEDURE XSynchPage (  Class  : APageClass   ) : BOOLEAN;

BEGIN                       (* XSynchPage *)

    IF (Class <> OurPageClass) THEN
        RETURN OldSynchPage(Class);
    END;

    RETURN TRUE;
    
END XSynchPage;





        (*-----------------------------------------------------------

            XStartupPageClass

            Starts a class of page storage.

            Preconditions:

            PostConditions:
                If the page class of storage is available, it will be
                made ready.  Else FALSE is returned.

        -------------------------------------------------------------*)

PROCEDURE XStartupPageClass(    Class : APageClass    ) : CARDINAL;

BEGIN                       (* XStartupPageClass *)

    IF (Class <> OurPageClass) THEN
        RETURN OldStartupPageClass(Class);
    ELSE
        RETURN EMSPageSizeInBytes;
    END;

END XStartupPageClass;




        (*-----------------------------------------------------------

            XShutdownPageClass

            Ends a class of page storage.

            Preconditions:

            PostConditions:
                The class of storage is no longer available.

        -------------------------------------------------------------*)


PROCEDURE XShutdownPageClass(    Class : APageClass    );

BEGIN                       (* XShutdownPageClass *)

    IF (Class <> OurPageClass) THEN
        OldShutdownPageClass(Class);
    ELSE
        (*<DEBUGGING
        SetString(s, "Shutting down now.");
        Error(s);
        DEBUGGING>*)
    END;

END XShutdownPageClass;








PROCEDURE XPageClassStatus(     Class       : APageClass;
                            VAR ClassStatus : APageClassStatus );
VAR
    NowFreePages    : CARDINAL;
BEGIN
    IF (Class <> OurPageClass) THEN
        OldPageClassStatus(Class,ClassStatus);
    ELSE
        WITH ClassStatus DO
            Present := TRUE;
            IF (Interlock > 0) THEN
                Condition := 2;   (* Bad *)                       (* 25-Sep-89 LAA *)
                Busy := TRUE;
            ELSE 
                Condition := 0;   (* OK *)
                Busy := FALSE;
            END;
            PageSize      := EMSPageSizeInK;
            EMSStatistics( NumberOfPages, NowFreePages, FreePages );
        END;
    END;
END XPageClassStatus;










PROCEDURE EmsFlexStorStartUp() : BOOLEAN;
BEGIN

    InstallNewProcedure(ADR(   CreatePage        ),PROC(XCreatePage),       ADR(OldCreatePage));
    InstallNewProcedure(ADR(   DiscardPage       ),PROC(XDiscardPage),      ADR(OldDiscardPage));
    InstallNewProcedure(ADR(   RetrievePage      ),PROC(XRetrievePage),     ADR(OldRetrievePage));
    InstallNewProcedure(ADR(   SynchPage         ),PROC(XSynchPage),        ADR(OldSynchPage));
    InstallNewProcedure(ADR(   StartupPageClass  ),PROC(XStartupPageClass), ADR(OldStartupPageClass));
    InstallNewProcedure(ADR(   ShutdownPageClass ),PROC(XShutdownPageClass),ADR(OldShutdownPageClass));
    InstallNewProcedure(ADR(   PageClassStatus   ),PROC(XPageClassStatus),  ADR(OldPageClassStatus));
    InstallNewProcedure(ADR(   EMSFrameRequest   ),PROC(XEMSFrameRequest),  ADR(OldEMSFrameRequest));

    Interlock   := 0;

    RETURN TRUE;

END EmsFlexStorStartUp;



END EmsFlexStor.
