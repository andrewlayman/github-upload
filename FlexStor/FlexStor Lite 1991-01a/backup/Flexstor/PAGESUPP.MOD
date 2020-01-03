

IMPLEMENTATION MODULE PageSupply;

    (*-------------------------------------------------------------

        PageSupply

        This module is responsible for creating and managing the
        storage and location of pages of data.  It is a support module
        for the ExtStorage module.

    --------------------------------------------------------------- *)

    (* MODIFICATION HISTORY:

    26 Jan 88   AJL -Import Available from Space.
                    -Use HeapSpaceLeft instead of HeapAvailable.
    02 Feb 88   LAA -Changed call to HeapSpaceLeft to HeapAvailable.
    3/8/88      AJL -Changed APageClassStatusProc to return a record 
                     containing several items of information.
    23-Jan-89   RSC -Changed Storage to Space.
    23-Feb-89   AJL -PageTable is now a pointer. 
     7-Nov-89   AJL -Page size reduced to 4K.
     2-Jan-90   AJL -Page size increased to 8K.
    *)  

FROM FlexData               IMPORT
    (* TYPE *)                  APage, APageNo,
    (* VAR *)                   PageTable;

FROM Space       IMPORT
    (* PROC *)       ALLOCATE, DEALLOCATE,
                     HeapAvailable, Available;

FROM SYSTEM      IMPORT
    (* TYPE *)       ADDRESS;




CONST
    OurPageSize = 8 * 1024;
    OurPageClass = PageFast;


TYPE
    APageHandle  = ADDRESS;

        (*-----------------------------------------------------------

            XCreatePage

            Attempts to create a new page of the indicated class.

            Preconditions:
                StartupPageStorage returned TRUE.

            PostConditions:
                Either sets PageTable^[PageNo] to the newly created
                page, or else FALSE.   When a handle is returned,
                the page is mapped into normal memory and its address
                and size is also returned.  The page table is updated
                by having its HomeAddress filled in and also its
                location set to the address of the page.



        -------------------------------------------------------------*)


PROCEDURE XCreatePage (     PageClass     : APageClass;
                            PageNo        : CARDINAL;
                        VAR Size          : CARDINAL     ) : BOOLEAN;
VAR
    PageHandle : APageHandle;
BEGIN
    IF (PageClass = OurPageClass) AND
       (HeapAvailable()) AND                                      (* 02-Feb-88 LAA *)
       (Available(OurPageSize)) THEN
        ALLOCATE(PageHandle,OurPageSize);
        WITH PageTable^[PageNo] DO
            Location  := PageHandle;
            HomeAddress := PageHandle;
        END;
        Size := OurPageSize;
        IF (HeapAvailable()) THEN                                 (* 02-Feb-88 LAA *)
            RETURN TRUE;
        ELSE
            DEALLOCATE(PageHandle,OurPageSize);
        END;
    END;
    PageTable^[PageNo].Location := NIL;
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


PROCEDURE XDiscardPage (     PageClass : APageClass;
                         VAR PageHandle : APageHandle ) : BOOLEAN;
BEGIN
    IF (PageClass = OurPageClass) THEN
        DEALLOCATE(PageHandle,OurPageSize);
        RETURN TRUE;
    END;
    RETURN FALSE;
END XDiscardPage;


        (*-----------------------------------------------------------

            XRetrievePage

            Attempts to get the page.

            Preconditions:
                The page class must be started.

            PostConditions:
                The page whose handle is in PageTable^[PageNo] will
                be mapped into physical memory and PageTable^[PageNo]
                .Location will contain the address of the page, or
                else FALSE.

        -------------------------------------------------------------*)


PROCEDURE XRetrievePage (     PageClass  : APageClass;
                              PageNo     : CARDINAL      ) : BOOLEAN;
BEGIN
    IF (PageClass = OurPageClass) THEN
        WITH PageTable^[PageNo] DO
            Location := HomeAddress;
        END;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
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
BEGIN
    RETURN (Class = OurPageClass);
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
BEGIN
    IF (Class = OurPageClass) THEN
        RETURN OurPageSize;
    ELSE
        RETURN 0;
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
BEGIN
END XShutdownPageClass;




PROCEDURE XPageClassStatus ( Class : APageClass;
                             VAR ClassStatus : APageClassStatus );
BEGIN
    ClassStatus.Condition := 0;      (* We may run out of memory, but we never fail. *)
    IF (Class = OurPageClass) THEN
        WITH ClassStatus DO
            Present := TRUE;
            Busy    := FALSE;
            PageSize := OurPageSize DIV 1024;
            NumberOfPages := 1;       (* At least, hopefully. *)
            FreePages     := 1;       (* ??? *) 
        END; 
    ELSE
        ClassStatus.Present := FALSE;
    END;
END XPageClassStatus;


BEGIN

    CreatePage          := XCreatePage;
    DiscardPage         := XDiscardPage;
    RetrievePage        := XRetrievePage;
    SynchPage           := XSynchPage;
    StartupPageClass    := XStartupPageClass;
    ShutdownPageClass   := XShutdownPageClass;
    PageClassStatus     := XPageClassStatus;

END PageSupply.

