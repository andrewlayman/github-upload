IMPLEMENTATION MODULE XMSMemory;

(*  =========================================================================
    Last Edit : July 8, 1991 5:02PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Interface module to XMS memory as per the Lotus/Intel/Microsoft/AST
        Extended Memory Specification, Version 2.0.

    MODIFICATION HISTORY:
        24-Mar-90 WKH   Initial version.
        28-Mar-90 WKH   Really detect for existance of UMB memory, don't 
                        assume existance just because XMS support is avail.
        24-Apr-90 RSC   Added EMB support and robustified things.
        21-Mar-91 RSC   If we Enable A20 but can't allocate HMA, disable
                        A20.
         8-Jul-91 RSC   Initialize the EMBDetected flag.  Fixes bug 4657.

    =========================================================================
*)

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, BYTE, WORD,
    (* VARS *)                  AX, BX, DX, ES, SI,
    (* PROC *)                  GETREG, SETREG, SWI, ADR;

CONST
    XMSGateway              =   2FH;

    XMSVersionFtn           = 0000H;
    XMSAllocateHMAFtn       = 0100H;
    XMSFreeHMAFtn           = 0200H;
    XMSGlobalA20EnableFtn   = 0300H;
    XMSGlobalA20DisableFtn  = 0400H;
    XMSLocalA20EnableFtn    = 0500H;
    XMSLocalA20DisableFtn   = 0600H;
    XMSQueryA20StateFtn     = 0700H;
    XMSAvailEMBFtn          = 0800H;
    XMSAllocateEMBFtn       = 0900H;
    XMSFreeEMBFtn           = 0A00H;
    XMSCopyEMBFtn           = 0B00H;
    XMSAllocateUMBFtn       = 1000H;
    XMSFreeUMBFtn           = 1100H;
    XMSDetectFtn            = 4300H;
    XMSGetVectorFtn         = 4310H;

TYPE
    AnXMSProcedureVector    = PROCEDURE();





VAR
    XMSServiceProc          : AnXMSProcedureVector;

    (* THIS RECORD IS HERE, SO THAT DS POINTS TO IT'S SEGMENT!!

        Don't move it.  Check new compilers for this behavior!
    *)
    XMSMemMoveStruct        : RECORD
        Length              : LONGINT;
        SourceHandle        : CARDINAL;
        SourceOffset        : LONGINT;
        DestHandle          : CARDINAL;
        DestOffset          : LONGINT;
    END;


    Initialized             : BOOLEAN;





(* Get UMB Memory - Get a chunk of UMB memory.

    Preconditions -

        XMSStartup has been called and returned TRUE.

    Postconditions -

        If available, some space in UMB was returned to you.

    Input:

        Size        - Desired maximum size in PARAGRAPHS.

    Output:

        Size        - Actual size in PARAGRAPHS.
        Segment     - Starting segment address.

        RETURN      - Error code, or 0 if no error.
                      Error code is one of those above in the CONST area.
*)
PROCEDURE GetUMBMemory(VAR Size    : CARDINAL;
                       VAR Segment : CARDINAL) : CARDINAL;

VAR
    Ax, Bx, Dx,
    ErrorCode               : CARDINAL;
    LetsJam                 : BOOLEAN;

BEGIN
    IF (NOT Initialized) THEN HALT; END;

    REPEAT
        SETREG(AX, XMSAllocateUMBFtn);
        SETREG(DX, Size);
        XMSServiceProc();
        GETREG(AX, Ax);
        GETREG(BX, Bx);
        GETREG(DX, Dx);

        Segment := Bx;      (* addressing problems with GETREG! *)
        Size    := Dx;

        IF (Ax = 1) THEN
            ErrorCode     := 0;                  (* Everything OK *)
        ELSE
            ErrorCode     := (Segment MOD 256);  (* Some error.   *)
            Segment       := 0;
        END;

        LetsJam := (ErrorCode <> XMSSmallerUMBIsAvail);

    UNTIL LetsJam;

    RETURN ErrorCode;

END GetUMBMemory;









(* Get EMB Memory - Get a chunk of EMB (Extended) memory.

    Preconditions -

        XMSStartup has been called and returned TRUE.

    Postconditions -

        If available, some Extended memory is allocated, and a handle
                is returned to you.

    Input:

        Size        - Desired size in KB.

    Output:

        Handle      - Handle to the memory, used in CopyEMBTo1MB;

        RETURN      - Error code, or 0 if no error.
                      Error code is one of those above in the CONST area.
*)
PROCEDURE GetEMBMemory(    Size    : CARDINAL;
                       VAR Handle  : CARDINAL) : CARDINAL;
VAR
    Han,
    Ax,
    ErrorCode   : CARDINAL;
BEGIN
    IF (NOT Initialized) THEN HALT; END;

    SETREG( AX, XMSAllocateEMBFtn );
    SETREG( DX, Size );
    XMSServiceProc();
    GETREG( AX, Ax );
    GETREG( DX, Han );
    GETREG( BX, ErrorCode );

    Handle := Han;  (* Stack addressing problems in GETREG *)

    IF (Ax = 1) THEN
        ErrorCode := 0;
    END;

    RETURN (ErrorCode MOD 256);

END GetEMBMemory;









                       
                       
(* Free UMB Memory - release memory previously allocated via GetUMBMemory.

    Preconditions -
    
        The Segment was returned from a prior SUCCESFULL call to
            GetUMBMemory.

    Postconditions -

        Memory previously allocated has been returned to the XMS driver.

    Input:

        Segment - same as returned from prior GetUMBMemory call.

    Output:

        RETURN  - Error code.  One of those above in the CONST area.
                  0 if no error.
*)
PROCEDURE FreeUMBMemory(Segment : CARDINAL) : CARDINAL;

VAR
    Ax,
    ErrorCode               : CARDINAL;

BEGIN
    IF (NOT Initialized) THEN HALT; END;

    SETREG(AX, XMSFreeUMBFtn);
    SETREG(DX, Segment);
    XMSServiceProc();
    GETREG( AX, Ax );
    GETREG( BX, ErrorCode );

    IF (Ax = 1) THEN
        ErrorCode := 0;
    END;

    RETURN (ErrorCode MOD 256);

END FreeUMBMemory;









(* Free EMB Memory - release memory previously allocated via GetEMBMemory.

    Preconditions -
    
        The Handle was returned from a prior SUCCESFULL call to
            GetEMBMemory.

    Postconditions -

        Memory previously allocated has been returned to the XMS driver.

    Input:

        Handle - same as returned from prior GetEMBMemory call.

    Output:

        RETURN  - Error code.  One of those above in the CONST area.
                  0 if no error.
*)
PROCEDURE FreeEMBMemory( Handle : CARDINAL) : CARDINAL;
VAR
    Ax,
    ErrorCode   : CARDINAL;
BEGIN
    IF (NOT Initialized) THEN HALT; END;

    SETREG( AX, XMSFreeEMBFtn );
    SETREG( DX, Handle );
    XMSServiceProc();
    GETREG( AX, Ax );
    GETREG( BX, ErrorCode );

    IF (Ax = 1) THEN
        ErrorCode := 0;
    END;

    RETURN (ErrorCode MOD 256);

END FreeEMBMemory;






PROCEDURE Move() : CARDINAL;
VAR
    Ax,
    ErrorCode   : CARDINAL;
    A           : ADDRESS;
BEGIN
    IF (NOT Initialized) THEN HALT; END;

    A := ADR(XMSMemMoveStruct);

    SETREG( AX, XMSCopyEMBFtn );
    SETREG( SI, A.OFFSET );

    (* SETREG( DS, A.SEGMENT ) SHOULD BE DONE BY THE COMPILER!! *)

    XMSServiceProc();
    GETREG( AX, Ax );
    GETREG( BX, ErrorCode );

    IF (Ax = 1) THEN
        ErrorCode := 0;
    END;

    RETURN (ErrorCode MOD 256);

END Move;




(* Copy EMB to DOS

    Copy part or all of an Extended block to DOS addressable memory.

    Preconditions -

        > Extended memory was allocated with "GetEMBMemory()" and not yet
          freed.  Handle is (therefore) good.

        > DOS or UMB memory was allocated for a size appropriate to receive
          the copy.

    Postconditions -

        If succesfull, data was copied from Extended memory to DOS
        memory or UMB memory (somewhere in the 1MB addressable area).

    Input:

        EMBHandle     Handle returned from good call to "GetEMBMemory()".
        StatingByte   First byte to copy; must be in range 0..AllocatedSize
        LengthToCopy  # of bytes to copy; Start+Len must be <= AllocatedSize
        ToHereInDOS   is any valid DOS or UMB memory block, previously
                         allocated.
    Output:

        RETURN      0 iff no error, error number otherwise.

    Notes:

        Length MUST BE EVEN.
        If starting byte is on a word boundary, xfer goes faster.
        If starting byte is on a DWORD boundary AND this is a 386,
            the XFER could go even faster (if support for it in XMS driver).
*)
PROCEDURE CopyEMBToDOS(     EMBHandle    : CARDINAL;
                            StartingByte,
                            LengthToCopy : LONGINT;
                            ToHereInDOS  : ADDRESS ) : CARDINAL;
BEGIN
    WITH XMSMemMoveStruct DO
        Length              := LengthToCopy;
        SourceHandle        := EMBHandle;
        SourceOffset        := StartingByte;
        DestHandle          := 0;
        DestOffset          := LONGINT(ToHereInDOS);
    END;

    RETURN Move();

END CopyEMBToDOS;







(* Copy DOS to EMB

    Same notes as for CopyEMBToDOS, but here we are putting memory back
    INTO extended from DOS or UMB space.

    StartingByte still refers to the starting byte in the EXTENDED memory.
*)
PROCEDURE CopyDOSToEMB(     EMBHandle     : CARDINAL;
                            StartingByte,
                            LengthToCopy  : LONGINT;
                            FromHereInDOS : ADDRESS ) : CARDINAL;
BEGIN
    WITH XMSMemMoveStruct DO
        Length              := LengthToCopy;
        SourceHandle        := 0;
        SourceOffset        := LONGINT(FromHereInDOS);
        DestHandle          := EMBHandle;
        DestOffset          := StartingByte;
    END;

    RETURN Move();

END CopyDOSToEMB;








(* EMB Available - How much extended memory is available?

    Preconditions - 

        XMSStartup has been called and returned TRUE.

    Postconditions -

        Extended memory stats are returned.

    INPUT:

        None

    Output:

        LargestFreeK        The largest contiguous free K area.
        TotalFreeK          The total quantity of free K.

        RETURN              Error code.  0 = no error.

    NOTE:

        This function attempts to make up for known driver deficiancies,
        ie HIMEM.SYS version 2.04 and earlier reported HMA as part of the
        extended memory available, I do not.
*)
PROCEDURE EMBAvail( VAR LargestFreeK,
                        TotalFreeK     : CARDINAL ) : CARDINAL;
VAR
    Largest,
    Total,
    ErrorCode   : CARDINAL;
BEGIN
    IF (NOT Initialized) THEN HALT; END;

    SETREG( AX, XMSAvailEMBFtn );
    XMSServiceProc();
    GETREG( AX, Largest   );
    GETREG( DX, Total     );
    GETREG( BX, ErrorCode );

    LargestFreeK := Largest; (* watch out for stack addressing problems! *)
    TotalFreeK   := Total;

    IF (LargestFreeK <> 0) THEN
        ErrorCode := 0;
    END;

    IF (XMSStatsRecord.XMSDriverVersion <= 0204H) THEN
        IF (LargestFreeK > 64) THEN DEC(LargestFreeK, 64); END;
        IF (TotalFreeK   > 64) THEN DEC(TotalFreeK,   64); END;
    END;

    RETURN (ErrorCode MOD 256);

END EMBAvail;









(* XMS Startup - does XMS exist?  Call this once to init XMS, and it returns
                 TRUE if there is some to get.

    Preconditions -

        This proc has not been called before.

    Postconditions -

        XMS has been checked for, and HMA allocated if found.

    Return parameter:

        TRUE  - XMS driver exists, and there is either

                    > All HMA avail
                    > Some UMB
                    > Some EMB

        else FALSE.
*)
PROCEDURE XMSStartup() : BOOLEAN;

VAR
    TempXMSVector           : ADDRESS;
    Ax, Bx, Cx, Dx          : CARDINAL;
    DummySeg                : CARDINAL;
    DummySize               : CARDINAL;
    ok                      : BOOLEAN;

BEGIN

    IF (NOT Initialized) THEN
        Initialized := TRUE;
        SETREG(AX, XMSDetectFtn);
        SWI(XMSGateway);
        GETREG(AX, Ax);

        XMSStatsRecord.XMSDriverDetected := ((Ax MOD 256) = 80H);

        IF (XMSStatsRecord.XMSDriverDetected) THEN


            (* Now let's setup the XMSServiceProc vector *)

            SETREG(AX, XMSGetVectorFtn);
            SWI(XMSGateway);
            GETREG(ES, TempXMSVector.SEGMENT);
            GETREG(BX, TempXMSVector.OFFSET);
            XMSServiceProc := AnXMSProcedureVector(TempXMSVector);


            (* Now let's see if we have any UMB, 28-Mar-90 WKH *)

            DummySize := 1;
            XMSStatsRecord.UMBMemoryDetected :=
                  (GetUMBMemory(DummySize, DummySeg) = 0);

            ok := (XMSStatsRecord.UMBMemoryDetected AND
                  (FreeUMBMemory(DummySeg) = 0));


            (* Now let's get XMS driver and spec version and check for HMA *)

            SETREG(AX, XMSVersionFtn);
            XMSServiceProc();
            GETREG(AX, Ax );
            GETREG(BX, Bx );
            GETREG(DX, Dx );

            XMSStatsRecord.XMSSpecificationVersion  := Ax;
            XMSStatsRecord.XMSDriverVersion         := Bx;

            IF (Dx = 1) THEN  (* HMA capability exists *)

                (* Alright, we know HMA memory exists, Let's enable A20 and see*)
                (* if any is available for our use.                            *)

                SETREG(AX, XMSLocalA20EnableFtn);
                XMSServiceProc();
                GETREG(AX, Ax );
                GETREG(BX, Bx );
                XMSStatsRecord.A20EnableError := Bx MOD 256;

                IF ((Ax MOD 256) = 1) THEN

                    SETREG(AX, XMSAllocateHMAFtn);
                    SETREG(DX, 0FFFFH);
                    XMSServiceProc();
                    GETREG(AX, Ax);
                    GETREG(BX, Bx);
                    XMSStatsRecord.HMAAllocationError     := Bx MOD 256;

                    IF ((Ax MOD 256) = 1) THEN
                        XMSStatsRecord.HMAMemoryDetected  := TRUE;
                        XMSStatsRecord.HMAAddress.SEGMENT := 0FFFFH;
                        XMSStatsRecord.HMAAddress.OFFSET  := 10H;
                        XMSStatsRecord.HMASize            := 0FFFH;
                            (* 64K - 16 bytes, in paras *)
                    ELSE
                        SETREG(AX, XMSLocalA20DisableFtn);  (* 21-Mar-91 RSC disable A20 *)
                        XMSServiceProc();
                    END;
                END;
            END;
            XMSStatsRecord.EMBMemoryDetected := (EMBAvail( Ax, Bx ) = 0);
        END;
    END;

    RETURN (XMSStatsRecord.UMBMemoryDetected OR
            XMSStatsRecord.HMAMemoryDetected OR
            XMSStatsRecord.EMBMemoryDetected);

END XMSStartup;
















(* XMS ShutDown - terminate storage.

    Preconditions -

        None.  Even XMSStartup need not be called,  Even this procedure may
        have been called before.

        HOWEVER, IF ANY HMA, UMB OR EMB was allocated, IT MUST HAVE BEEN
        DEALLOCATED BY THIS TIME.

    Postconditions -

        HMA is released.  Access to UMB and EMB is shut off.

        NO FURTHER ACCESS TO HMA, UMB, or EMA IS ALLOWED.
*)
PROCEDURE XMSShutDown();
BEGIN
    IF (XMSStatsRecord.HMAMemoryDetected) THEN
        SETREG(AX, XMSFreeHMAFtn);
        XMSServiceProc();

        SETREG(AX, XMSLocalA20DisableFtn);
        XMSServiceProc();
    END;
END XMSShutDown;













BEGIN (* Module XMSMemory *)

    Initialized := FALSE;

    WITH XMSStatsRecord DO
        XMSDriverDetected       := FALSE;
        UMBMemoryDetected       := FALSE;
        HMAMemoryDetected       := FALSE;
        EMBMemoryDetected       := FALSE;   (* 8-Jul-91 RSC added *)
        HMAAddress              := NIL;
        HMASize                 := 0;
        XMSDriverVersion        := 0;
        XMSSpecificationVersion := 0;
        HMAAllocationError      := 0;
        A20EnableError          := 0;
    END;

END XMSMemory.


