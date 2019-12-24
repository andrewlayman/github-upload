MODULE TLEMS;

    (*-------------------------------------------------------------

        TLEMS

        This module is responsible for creating and managing the
        storage and location of pages of data.  It is a support module
        for the ExtStorage module.

        On startup, we take all the EMS memory available.  We do not
        share use of EMS with any other programs; we don't release
        pages we don't need and we cannot ever use more than were
        available when we start.

    --------------------------------------------------------------- *)

    (* MODIFICATION HISTORY:

        9/30/87  AJL - This module will now exit without chaining to
                       the next overlay if EMS memory is not present or
                       could not be used.
               Note: - We need to install a termination proc to
                       release our EMS pages in the event of premature
                       death.
       10/4/87   AJL - Removed WritePage and ReleasePage.
                     - Changed to new versions of CreatePage and
                       RetrievePage.
        1/21/88  AJL - Since there is no particular value in discarding
                       a page when we are asked to, and it is a possible 
                       source of errors, plus some unnecessary code, we
                       will just decline to discard the page.

        2/21/88  RSC - Ajusted word alignment in global data.
        2/26/88  RSC - Added "EMSPages" parameter.
        3/8/88   AJL - Upgraded the PageClassStatus procedure to use a 
                       returned record.
       23-Feb-89 AJL - PageTable is now a pointer.
        2-Mar-89 RSC - Changed "InstallNewProcedure" for Overlays.Mod.
        7-Mar-89 LAA   Changed ADDRESS to ADR in calls to InstallNewProcedure.
        9-Mar-89 AJL - Added tests that the EMS memory is actually working so
                       that technical support will have an easier time diagnosing
                       problems where customers have accidently set multiple
                       boards to the same address or have set their switches
                       wrong.
                     - Warn the user if an EMS driver is present but no pages
                       are available, or fewer than were requested.
                     - Require at least 4 pages.
       23-Mar-89 RSC - Fix bug where not asking for EMS caused the warning
                       saying you didn't have enough.  You actually have none,
                       and ask for none, but are told that you can't have that
                       much, because you have none.  Sigh.
       22-Jun-89 RSC - When you are low on EMS, check to see if there is some
                       OTHER page size as slow storage.  If so, don't
                       complain, as there is a disk swapper around.
        7-Jul-89 AJL - Added EMSSavePageMap and EMSRestorePageMap.
       11-Jul-89 AJL - Limit ourselves to 512 pages.
       12-Jul-89 AJL - Add some fancy use of a "VacantPage" to allow us to
                       run even with EMS drivers that refuse to unmap pages.
       18-Aug-89 RSC - Split TLEMS into three parts:
                            TLEMS        as a shell to drive things.
                            XEmsStorage  Manage EMS pages and frames.
                            EMSFlexStor  A Page supply for FlexStor/EMS.
       22-Aug-89 KKC - Add copyright message.
    *)

FROM EmsFlexStor            IMPORT
    (* PROC *)                  EmsFlexStorStartUp;

FROM FlexStor               IMPORT
    (* PROC *)                  InitExtStorage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImALockedOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM PageSupply             IMPORT
    (* TYPE *)                  APageClass,
    (* PROC *)                  ShutdownPageClass;

FROM XEmsStorage            IMPORT
    (* PROC *)                  XEmsStorageStartUp, XEmsStorageShutDown;


CONST
    OurPageClass            = PageMedium;


VAR
    OverlayID               : AnOverlayID;









PROCEDURE DoStartup():BOOLEAN;
BEGIN                       (* DoStartup *)

    RETURN XEmsStorageStartUp() AND EmsFlexStorStartUp();

END DoStartup;






PROCEDURE ShutDown();
VAR
    Copyright               : ARRAY[0..47] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    ShutdownPageClass(OurPageClass);
    XEmsStorageShutDown();
END ShutDown;




BEGIN

    IF (DoStartup()) THEN
        IF (InitExtStorage(1000)) THEN END;
        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );
    END;

END TLEMS.

