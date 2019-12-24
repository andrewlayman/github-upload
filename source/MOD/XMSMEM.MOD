IMPLEMENTATION MODULE XMSMem;

(*  =========================================================================
    Last Edit : March 21, 1991 5:04PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This module handle hooked procedure vectors for XMS.

    MODIFICATION HISTORY:

        14-Jun-90 RSC  First version.
        31-Jan-91 RSC  Added EMB Calls.
        21-Mar-91 RSC  Added HMAPresent and VideoAvailable Call.

    =========================================================================
*)


FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS;




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
BEGIN
    FoundSegment := 0;
    RETURN FALSE;
END XAllocateUMBMemory;






    (* DeAllocate UMB Memory -

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
BEGIN
    RETURN FALSE;
END XDeAllocateUMBMemory;







    (* UMB Available

        Largest single block of UMB available.  In Paragraphs.
    *)
PROCEDURE XUMBAvailable() : CARDINAL;
BEGIN
    RETURN 0;
END XUMBAvailable;



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
BEGIN
    RETURN FALSE;
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
BEGIN
END XDeAllocateEMBMemory;


    (* EMB Available

        Largest single block of EMB available.  In KB.
    *)
PROCEDURE XEMBAvailable( VAR TotalKB : CARDINAL ) : CARDINAL;
BEGIN
    TotalKB := 0;
    RETURN 0;
END XEMBAvailable;








    (* Copy EMB Memory To DOS

            Preconditions  - memory was obtained from AllocateUMBMemory.
                             DOS address is valid and you "own" it.
    *)
PROCEDURE XEMBCopyToDOS( StartingByte : LONGINT;
                         Length       : CARDINAL;
                         ToHere       : ADDRESS );
BEGIN
    HALT;
END XEMBCopyToDOS;



    (* Copy EMB Memory From DOS

            Preconditions  - memory was obtained from AllocateUMBMemory.
                             DOS address is valid and you "own" it.
    *)
PROCEDURE XEMBCopyFromDOS( StartingByte : LONGINT;
                           Length       : CARDINAL;
                           FromHere     : ADDRESS );
BEGIN
    HALT;
END XEMBCopyFromDOS;


PROCEDURE XVideoAvailable( VAR FreeKB   : CARDINAL;
                           VAR TotalKB  : CARDINAL );
BEGIN
    FreeKB  := 0;
    TotalKB := 0;
END XVideoAvailable;


BEGIN  (* module XMSMem *)

    DeAllocateUMBMemory := XDeAllocateUMBMemory;
    AllocateUMBMemory   := XAllocateUMBMemory;
    UMBAvailable        := XUMBAvailable;

    AllocateEMBMemory   := XAllocateEMBMemory;
    DeAllocateEMBMemory := XDeAllocateEMBMemory;
    EMBAvailable        := XEMBAvailable;
    EMBCopyFromDOS      := XEMBCopyFromDOS;
    EMBCopyToDOS        := XEMBCopyToDOS;

    VideoAvailable      := XVideoAvailable;
    HMAPresent          := FALSE;

END XMSMem.
