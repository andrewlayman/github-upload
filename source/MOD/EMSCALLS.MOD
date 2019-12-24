IMPLEMENTATION MODULE EMSCalls;

    (*  This module implements the primitive EMS functions.  *)

    (* MODIFICATION HISTORY
       16-Sep-88 AJL - Added the EMSGetFrameAddresses function.
        7-Jul-89 AJL - Corrected the documentation of EMSPageMap().
                     - Added EMSSavePageMap and EMSRestorePageMap.
                     - Gave it a real ModuleNumber.
       29-Aug-91 LAA - If we can't get an EMS page frame, return 0 from
                       EMSGetPageFrameAddresses.  Bug #4841
    *) 
       

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error;

FROM LStrings               IMPORT
    (* PROC *)                  CtoS, ConcatLS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, 
    (* CONST *)                 AX, BX, CX, DX, ES, DI,
    (* PROC *)                  GETREG, SETREG, SWI, DOSCALL, ADR;


CONST
    ModuleNumber            = 8000;
    EMSInterrupt            = 67H;

VAR
    EMSInstalled            : BOOLEAN;



PROCEDURE DoFunctionOnHandle( Function   : CARDINAL;
                              EMSHandle  : CARDINAL) : BOOLEAN;

VAR
    Status                  : CARDINAL;

BEGIN

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    SETREG(AX, Function);
    SETREG(DX, EMSHandle);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    RETURN Check(Status);

END DoFunctionOnHandle;






PROCEDURE Check(    Status      : CARDINAL): BOOLEAN;

VAR
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..9] OF CHAR;

BEGIN                       (* Check *)

    Status := Status DIV 100H;

    IF (Status = 0) THEN
        RETURN TRUE;
    END;

    GetMessage(ModuleNumber + 2, s);    (* The following EMS error has occured *)
    CtoS((Status), s2);
    ConcatLS(s, s2);
    Error(s);

    CASE (Status) OF
        80H..84H, 8FH..91H, 94H, 98H, 9AH :
            GetMessage(ModuleNumber + 1, s);
            Error(s);
            FatalError();
    ELSE
    END;

    RETURN FALSE;

END Check;

(*----------------------------------------------------------------------------
    EMSGetStatus --

    Determine the status of the EMS subsystem.

    Preconditions:
        None.

    Postconditions:
        The status code from EMS is returned.  Zero indicates EMS is 
        functioning correctly, anything else means not to use EMS.
----------------------------------------------------------------------------*)

PROCEDURE EMSGetStatus(): CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* EMSGetStatus *)

    IF (NOT EMSInstalled) THEN
        RETURN 80H;
    END;

    SETREG(AX, 4000H);
    SWI(EMSInterrupt);
    GETREG(AX, i);

    RETURN (i DIV 100H);

END EMSGetStatus;




(*----------------------------------------------------------------------------
    EMSGetPageFrame --

    Find and return the page frame address, i.e. the address of physical page
    zero.

    Preconditions:
        The EMS status must have checked out ok.

    Postconditions:
        The address of the page frame is returned.
----------------------------------------------------------------------------*)

PROCEDURE EMSGetPageFrame(): ADDRESS;

VAR
    Status                  : CARDINAL;
    Frame                   : ADDRESS;

BEGIN                       (* EMSGetPageFrame *)

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    SETREG(AX, 4100H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(BX, Frame.SEGMENT);

    IF (NOT Check(Status)) THEN
        Frame.SEGMENT := 0FFFFH;
    END;
    Frame.OFFSET := 0;

    RETURN Frame;

END EMSGetPageFrame;


(*----------------------------------------------------------------------------
    EMSGetFrameAddresses --

    Find and return the page addresses for all pages.  These might not
    be contiguous.

    Preconditions:
        The EMS status must have checked out ok.

    Postconditions:
        The address of each page in the page frame is filled into the 
        array, up to the HIGH(Pages) or the maximum number of pages,
        whichever comes first.   The number of pages is returned.
----------------------------------------------------------------------------*)

PROCEDURE EMSGetFrameAddresses(VAR Pages : ARRAY OF ADDRESS) : CARDINAL;
CONST
    GetMappableArrayFunction = 5800H;
TYPE
    AMapStructure = RECORD
                        Segment : CARDINAL;
                        PageNo  : CARDINAL;
                    END;
VAR
    F                       : ADDRESS;
    Map                     : ARRAY [0..63] OF AMapStructure;
    Status                  : CARDINAL;
    i, Count, N             : CARDINAL;
BEGIN
        (* Take no chances.  Fill the array with NILs. *)

    FOR i := 0 TO HIGH(Pages) DO
        Pages[i] := NIL;
    END;
    

        (* EMS versions less than 4.0 have four contiguous pages. In
           EEMS, the first four pages are contiguous. *)

    IF (EMSGetVersion() < 40H) THEN
        F := EMSGetPageFrame();
        IF (F.SEGMENT = 0FFFFH) THEN
            RETURN 0;
        END;
        FOR i := 0 TO 3 DO
            F.OFFSET := i * 4000H;
            Pages[i] := F;
        END;
        RETURN 4;
    END;


        (* EMS 4.0 introduces the problem of non-contiguous pages. *)


    F := ADR(Map);                  (* ES:DI --> Map array. *)
    SETREG(ES, F.SEGMENT);
    SETREG(DI, F.OFFSET);
    SETREG(AX, GetMappableArrayFunction);    (* the function code. *)
    SWI(EMSInterrupt);              (* Make the EMS call. *)
    GETREG(AX, Status);             (* AH := Status *)
    GETREG(CX, Count );

    IF (NOT Check(Status)) OR (Count = 0) THEN
        RETURN 0;
    ELSIF (Count > HIGH(Map)+1) THEN   (* we overstepped the array bounds. *)
        FatalError();
    END; 

        (* We now have an array of page numbers and their segment addresses
           sorted in address order.  Unfortunately, we want pages 0..Count-1
           in page number order. *)

    FOR i := 0 TO Count-1 DO
        N := Map[i].PageNo;
        IF (N <= HIGH(Pages)) THEN
            F.SEGMENT := Map[i].Segment;
            F.OFFSET  := 0;
            Pages[N] := F;
        END;
    END; 

    RETURN Count;

END EMSGetFrameAddresses;




(*----------------------------------------------------------------------------
    EMSGetUnallocatedPages --

    Return the number of unallocated pages in EMS.

    Preconditions:
        The EMS status must have checked out ok.

    Postconditions:
        The number of pages in EMS which are currently unallocated will be
        returned.
----------------------------------------------------------------------------*)

PROCEDURE EMSGetUnallocatedPages(): CARDINAL;

VAR
    Status                  : CARDINAL;
    Pages                   : CARDINAL;

BEGIN                       (* EMSGetUnallocatedPages *)

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    SETREG(AX, 4200H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(BX, Pages);

    IF (NOT Check(Status)) THEN
        Pages := 0;
    END;

    RETURN Pages;

END EMSGetUnallocatedPages;




(*----------------------------------------------------------------------------
    EMSAllocatePages --

    Allocate the requested number of pages, and return the handle by which
    those pages are to be known.

    Preconditions:
        The EMS status must have checked out ok.

    Postconditions:
        If TRUE is returned, the pages will have been allocated to the 
        returned handle and be available for mapping.  Otherwise, FALSE will
        be returned.
----------------------------------------------------------------------------*)

PROCEDURE EMSAllocatePages(    PagesWanted  : CARDINAL;
                           VAR EMSHandle    : CARDINAL)
                                                       : BOOLEAN;

VAR
    Status                  : CARDINAL;
    Handle                  : CARDINAL;

BEGIN                       (* EMSAllocatePages *)

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    SETREG(AX, 4300H);
    SETREG(BX, PagesWanted);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(DX, Handle);

    EMSHandle := Handle;

    RETURN Check(Status);

END EMSAllocatePages;




(*----------------------------------------------------------------------------
    EMSPageMap --

    Map and unmap logical pages of an EMS handle into physical pages of the
    page frame.

    Preconditions:
        The EMS status must have checked out ok.
        The handle given must have been created by EMSAllocatePages, the 
        physical page number must be in the range (0..3), and the logical
        page number must be within the range (0..PagesWanted - 1).  To unmap
        a physical page, specify a logical page number of 0FFFFH.

    Postconditions:
        If the logical page is successfully mapped into the physical page,
        (or unmapped, if that was requested) then TRUE will be returned.
        FALSE will be returned if there was an error.
----------------------------------------------------------------------------*)

PROCEDURE EMSPageMap(    EMSHandle          : CARDINAL;
                         LogicalPage        : CARDINAL;
                         PhysicalPage       : CARDINAL)
                                                       : BOOLEAN;

VAR
    Status                  : CARDINAL;

BEGIN                       (* EMSPageMap *)

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    PhysicalPage := (PhysicalPage MOD 100H) + 4400H;
    SETREG(AX, PhysicalPage);
    SETREG(BX, LogicalPage);
    SETREG(DX, EMSHandle);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    RETURN Check(Status);

END EMSPageMap;




(*----------------------------------------------------------------------------
    EMSDeallocatePages --

    Dispose of the given handle and the logical pages associated with it.

    Preconditions:
        The EMS status must have checked out ok.
        The handle given must have been created by EMSAllocatePages.

    Postconditions:
        The EMS handle and pages will be returned to the pool of available
        EMS resources.
----------------------------------------------------------------------------*)

PROCEDURE EMSDeallocatePages(VAR EMSHandle  : CARDINAL);

VAR
    OK  : BOOLEAN;

BEGIN                       (* EMSDeallocatePages *)
    IF (DoFunctionOnHandle( 4500H, EMSHandle )) THEN
        EMSHandle := 0;
    END;

END EMSDeallocatePages;




(*----------------------------------------------------------------------------
    EMSGetVersion --

    Return the version of EMS software installed.

    Preconditions:
        The EMS status must have checked out ok.

    Postconditions:
        The version number will be returned as a CARDINAL number, with major
        and minor version numbers.  A returned value of 40 indicated version
        4.0.
----------------------------------------------------------------------------*)

PROCEDURE EMSGetVersion(): CARDINAL;

VAR
    Status                  : CARDINAL;

BEGIN                       (* EMSGetVersion *)

    IF (NOT EMSInstalled) THEN
        FatalError();
    END;

    SETREG(AX, 4600H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    IF (NOT Check(Status)) THEN
        Status := 0;
    END;

    RETURN (Status MOD 100H);

END EMSGetVersion;


PROCEDURE CheckForEMS(): BOOLEAN;

VAR
    EMSName                 : ARRAY [0..7] OF CHAR;
    i                       : CARDINAL;
    Addr                    : ADDRESS;
    EMSDriver               : POINTER TO ARRAY [0..17] OF CHAR;

BEGIN                       (* CheckForEMS *)

    EMSName := "EMMXXXX0";
    DOSCALL(35H, EMSInterrupt, Addr);          (* Check for EMS driver *)
    Addr.OFFSET := 10;
    EMSDriver := Addr;
    FOR i := 0 TO 7 DO
        IF (EMSDriver^[i] <> EMSName[i]) THEN
            RETURN FALSE;
        END;
    END;

    SETREG(AX, 4000H);          (* Call EMS driver for GetStatus *)
    SWI(EMSInterrupt);
    GETREG(AX, i);

    RETURN ((i DIV 100H) = 0);

END CheckForEMS;





(*----------------------------------------------------------------------------
    EMSSavePageMap --

    Saves the page mapping registers into an internal save area.

    Preconditions:
        The EMS status must have checked out ok.
        The EMS Handle must be the one returned from EMSAllocatePages.

    Postconditions:
        The EMS state is stored into a internal area and TRUE is returned,
        else FALSE is returned.
         
----------------------------------------------------------------------------*)

PROCEDURE EMSSavePageMap(EMSHandle  : CARDINAL) : BOOLEAN;
BEGIN
    RETURN DoFunctionOnHandle( 4700H, EMSHandle );
END EMSSavePageMap;


(*----------------------------------------------------------------------------
    EMSRestorePageMap --

    Restores the page mapping registers from an internal save area.

    Preconditions:
        The EMS status must have checked out ok.
        The EMS Handle must be the one returned from EMSAllocatePages.
        EMSSavePageMap must have been called, and returned successfully.

    Postconditions:
        The EMS state is restored to the state it was when the 
        EMSSavePageMap procedure was called.
         
----------------------------------------------------------------------------*)

PROCEDURE EMSRestorePageMap(EMSHandle  : CARDINAL) : BOOLEAN;
BEGIN
    RETURN DoFunctionOnHandle( 4800H, EMSHandle );
END EMSRestorePageMap;




BEGIN                       (* EMSCalls *)

    EMSInstalled := CheckForEMS();

END EMSCalls.

