MODULE XMSCheck;


IMPORT DebugPMD;



FROM CardinalIO             IMPORT
                                WriteCardinal;

FROM InOut                  IMPORT
                                WriteHex;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, 
    (* CONST *)                 AX, BX, CX, DX, ES, DI,
    (* PROC *)                  GETREG, SETREG, SWI, DOSCALL, ADR, CODE;

FROM Terminal               IMPORT
                                WriteLn, WriteString;

FROM XMSMemory              IMPORT
    (* CONST *)                 XMSFunctionNotImplemented,
                                XMSVDISKDriverDetected,
                                XMSA20Error,
                                XMSGeneralDriverError,
                                XMSUnrecoverableDriverError,
                                XMSHMADoesNotExist,
                                XMSHMAAlreadyInUse,
                                XMSDXLessThanHMAMINParm,
                                XMSHMANotAllocated,
                                XMSA20StillEnabled,
                                XMSAllEMBAllocated,
                                XMSAllEMBHandlesInUse,
                                XMSEMBHandleInvalid,
                                XMSEMBSourceHandleInvalid,
                                XMSEMBSourceOffsetInvalid,
                                XMSEMBDestHandleInvalid,
                                XMSEMBDestOffsetInvalid,
                                XMSEMBLengthInvalid,
                                XMSEMBInvalidOverlap,
                                XMSEMBParityError,
                                XMSSmallerUMBIsAvail,
                                XMSNoUMBAvail,
                                XMSInvalidUMBSegmentNumber,

    (* VAR *)                   XMSStatsRecord,

    (* PROC *)                  XMSStartup, XMSShutDown,
                                GetUMBMemory, FreeUMBMemory,
                                CopyEMBToDOS, CopyDOSToEMB,
                                EMBAvailable,
                                GetEMBMemory, FreeEMBMemory;





TYPE
    ABigArray   = POINTER TO ARRAY [1..32767] OF CARDINAL;

VAR
    TestPatterns        : ARRAY [1..8] OF CARDINAL;
    AllMemoryOK         : BOOLEAN;
    SomeErrorOccured    : BOOLEAN;





PROCEDURE WriteTo5( s : ARRAY OF CHAR );
VAR
    i,
    Loop    : CARDINAL;
BEGIN

    Loop := 0;
    WHILE (Loop < 5) AND (s[Loop] <> 0C) DO
        INC(Loop);
    END;
    FOR i := 1 TO 5-Loop DO
        WriteString( " " );
    END;
    WriteString( s );

END WriteTo5;




PROCEDURE RealToString(     Amount : REAL;
                        VAR str    : ARRAY OF CHAR );
CONST
    One             =  1.0;
    Ten             = 10.0;
VAR
    Loop, A,
    LeadingDigits   : CARDINAL;

BEGIN
    IF (Amount < One) THEN
        str[0] := "0";
        str[1] := 0C;
        RETURN;
    END;

    LeadingDigits := 0;
    WHILE (Amount >= One) DO
        Amount := Amount / Ten;
        INC(LeadingDigits);
    END;

    FOR Loop := 0 TO LeadingDigits-1 DO
        Amount    := Amount * Ten;
        A         := TRUNC( Amount );
        Amount    := Amount - FLOAT( A );
        str[Loop] := CHR(A + ORD("0"));
    END;

    str[LeadingDigits] := 0C;

END RealToString;






(* Length is len in BYTES.  Code is any cardinal test pattern.
*)
PROCEDURE WriteToMem(      A      : ADDRESS;
                           Length : CARDINAL;
                           Code   : CARDINAL  );
VAR
    i           : CARDINAL;
    BigArray    : ABigArray;
BEGIN
    BigArray := A;
    FOR i := 1 TO (Length DIV 2) DO
        BigArray^[i] := Code;
    END;
END WriteToMem;




PROCEDURE VerifyMem(       A      : ADDRESS;
                           Length : CARDINAL;
                           Code   : CARDINAL  ) : BOOLEAN;
VAR
    i           : CARDINAL;
    BigArray    : ABigArray;
    ok          : BOOLEAN;
BEGIN
    BigArray := A;
    Length   := Length DIV 2;  (* Make into words. *)
    ok       := TRUE;

    i := 1;
    WHILE (ok) AND (i <= Length) DO
        ok := (BigArray^[i] = Code);
        INC(i);
    END;

    AllMemoryOK := AllMemoryOK AND ok;

    RETURN ok;

END VerifyMem;




PROCEDURE TestMemory(      A      : ADDRESS;
                           Length : CARDINAL;
                           Pats   : BITSET  ) : BOOLEAN;
VAR
    i   : CARDINAL;
    ok  : BOOLEAN;

BEGIN
    ok := TRUE;
    i  := 1;

    WHILE (ok) AND (i <= HIGH(TestPatterns)) DO

        IF (i IN Pats) THEN
            WriteToMem(A, Length, TestPatterns[i]);
            ok := VerifyMem(A, Length, TestPatterns[i]);
        END;

        INC(i);
    END;

    RETURN ok;

END TestMemory;






PROCEDURE ReportError( ErrorCode : CARDINAL );
VAR
    LocalError  : BOOLEAN;
BEGIN
    WriteLn();

    LocalError := TRUE;

    CASE ErrorCode OF
        XMSFunctionNotImplemented   :
            WriteString('    Function not available from this XMS driver.');
            WriteLn();
            WriteString('    Your XMS driver does not work very well. Try a better (or newer) one. FNI.');

      | XMSVDISKDriverDetected      :
            WriteString('    A VDISK (RAM DISK) driver has been detected.');

      | XMSA20Error                 :
            WriteString('    There is no HMA on this computer.  Either the XMS driver does not support');
            WriteLn();
            WriteString('    it, or this is an 8086/8088 computer (an XT or PS2/20) (A20 error).');

      | XMSGeneralDriverError       :
            WriteString('    Your XMS driver does not work very well. Try a better (or newer) one. GDE.');

      | XMSUnrecoverableDriverError :
            WriteString('    Your XMS driver does not work very well. Try a better (or newer) one. UDE.');

      | XMSHMADoesNotExist          :
            WriteString('    There is no HMA on this computer.  Either the XMS driver does not support');
            WriteLn();
            WriteString('    it, or this is an 8086/8088 computer (an XT or PS2/20) (no HMA).');
            LocalError := FALSE; (* Not too serious *)

      | XMSHMAAlreadyInUse          :
            WriteString('    HMA memory is already in use by another program.');
            LocalError := FALSE; (* Not too serious *)

      | XMSDXLessThanHMAMINParm     :
            WriteString('    Remove the /HMAMIN= parameter from your XMS driver.');
            LocalError := FALSE; (* Not too serious *)

      | XMSAllEMBAllocated          :
            WriteString('    Some other programs have used up all the Extended memory.');
            LocalError := FALSE; (* Not too serious *)

      | XMSAllEMBHandlesInUse       :
            WriteString('    Some other programs have used all Extended memory "handles".  Try');
            WriteLn();
            WriteString('    specifying or increasing the /NUMHANDLES= parameter on the XMS driver.');
            LocalError := FALSE; (* Not too serious *)

      | XMSEMBParityError           :
            WriteString('    There was an Extended Memory PARITY ERROR.');

    ELSE
        WriteString('    Unusual error:');
        WriteHex(ErrorCode, 4);
        WriteString('H.');
    END;

    SomeErrorOccured := SomeErrorOccured OR LocalError;

END ReportError;







PROCEDURE CheckUMB() : REAL;
VAR
    Ptr         : ARRAY [1..99] OF ADDRESS;
    Avail       : REAL;
    i,
    Paras,
    Size,
    ErrorCode   : CARDINAL;
    s           : ARRAY [0..11] OF CHAR;

BEGIN
    WriteLn();
(*    WriteString("UPPER MEMORY BLOCKS (UMB's):");*)

    WriteString("UMB (program code and data) : " );

    Avail := 0.0;

    IF XMSStatsRecord.UMBMemoryDetected THEN

        Size := 0400H;

        FOR i := 1 TO HIGH(Ptr) DO
            Ptr[i].SEGMENT := 0;
            Ptr[i].OFFSET  := 0;
        END;

        Paras := 0;
        i     := 1;

        ErrorCode := GetUMBMemory(Size, Ptr[i].SEGMENT);
        WHILE (i < HIGH(Ptr)) AND
              (ErrorCode = 0) DO
            IF (NOT TestMemory( Ptr[i], Size, {1,2,3,4,5,6,7,8} )) THEN
                WriteLn();
                WriteString('    DANGER!!  UMB contains FAULTY MEMORY!!');
            ELSE
                INC(Paras, Size);
            END;
            INC(i);
            ErrorCode := GetUMBMemory(Size, Ptr[i].SEGMENT);
        END;

        IF (ErrorCode <> 0)             AND
           (ErrorCode <> XMSNoUMBAvail) THEN
            WriteLn();
            WriteString("    Trouble getting the UMB memory:");
            ReportError(ErrorCode);
        END;

        Avail := FLOAT(Paras) * 16.0;
        RealToString( Avail / 1024.0, s );

        WriteTo5(s);
        WriteString(' KB free in ' );
        DEC(i);
        IF (i > 9) THEN
            WriteCardinal( i-1, 2 );
            WriteString(' chunks.');
        ELSIF (i = 1) THEN
            WriteCardinal( i-1, 1 );
            WriteString(' chunk.');
        ELSE
            WriteCardinal( i-1, 1 );
            WriteString(' chunks.');
        END;

        FOR i := 1 TO HIGH(Ptr) DO
            IF (Ptr[i].SEGMENT <> 0) THEN
                ErrorCode := FreeUMBMemory(Ptr[i].SEGMENT);
                IF (ErrorCode <> 0) THEN
                    WriteLn();
                    WriteString('    DANGER!!  Trouble freeing up UMB memory:');
                    ReportError(ErrorCode);
                END;
            END;
        END;
    ELSE
(*        WriteLn();*)
(*        WriteString('    No UMB Memory Available.  It may not be supported by your XMS driver.');*)
        WriteString('not available.  It may not be supported by your XMS driver.');
        WriteLn();
        WriteString("    Most versions of HIMEM.SYS don't support UMB.");
    END;

    RETURN Avail;

END CheckUMB;







PROCEDURE CheckHMA() : REAL;
VAR
    Avail   : REAL;
BEGIN
(*    WriteString("HIGH MEMORY AREA (HMA):");*)
    WriteLn();
    WriteString('HMA (dependancies, outlines): ');


    Avail := 0.0;

    WITH XMSStatsRecord DO
        IF HMAMemoryDetected THEN
            WriteCardinal(HMASize * 16, 5);
            WriteString(" bytes.");

            IF (NOT TestMemory( HMAAddress, HMASize, {1,2,3,4,5,6,7,8} )) THEN
                WriteLn();
                WriteString('    DANGER!!  HMA contains FAULTY MEMORY!!');
            ELSE
                Avail := FLOAT(HMASize * 16);
            END;
        ELSE
            WriteString('unavailable.  Could be in use by a program.');
            IF (HMAAllocationError <> 0) THEN
                WriteLn();
                WriteString('    HMA Allocation failed:');
                ReportError(HMAAllocationError);
            END;
            IF (A20EnableError <> 0) THEN
                WriteLn();
                WriteString('    A20 line enable failed:');
                ReportError(A20EnableError);
            END;
        END;
    END;

    RETURN Avail;

END CheckHMA;








PROCEDURE CheckEMB() : REAL;
VAR
    Where           : ADDRESS;
    i, j,
    TotalAllocated,
    ErrorCode,
    LargestFreeK,
    TotalFreeK      : CARDINAL;
    Handle          : ARRAY [1..30] OF CARDINAL;
    Avail           : REAL;
    MemoryOK        : BOOLEAN;


    PROCEDURE CheckExtended( KB, Handle : CARDINAL) : BOOLEAN;
    CONST
        OneKB   = VAL(LONGINT, 1024);
    VAR
        StartingByte : LONGINT;
        Pattern,
        Loop         : CARDINAL;
    BEGIN

        FOR Pattern := 1 TO HIGH(TestPatterns) DO
            WriteString( "." );

            WriteToMem( Where, 1024, TestPatterns[ Pattern ]);

            Loop := 0;
            WHILE (Loop < KB) AND (MemoryOK) DO
                StartingByte := VAL(LONGINT,Loop) * OneKB;
                ErrorCode := CopyDOSToEMB( Handle, StartingByte, OneKB, Where );
                IF (ErrorCode <> 0) THEN
                    WriteLn();
                    WriteString( "    Cannot COPY to Extended from DOS:" );
                    ReportError(ErrorCode);
                    MemoryOK := FALSE;
                END;
                INC(Loop);
            END;

            Loop := 0;
            WHILE (Loop < KB) AND (MemoryOK) DO
                StartingByte := VAL(LONGINT,Loop) * OneKB;
                ErrorCode := CopyEMBToDOS( Handle, StartingByte, OneKB, Where );
                IF (ErrorCode <> 0) THEN
                    WriteLn();
                    WriteString( "    Cannot COPY from Extended to DOS:" );
                    ReportError(ErrorCode);
                    MemoryOK := FALSE;
                END;

                MemoryOK := MemoryOK AND
                            VerifyMem( Where, 1024, TestPatterns[ Pattern ] );

                INC(Loop);
            END;
        END;

        RETURN MemoryOK;

    END CheckExtended;


BEGIN
(*    WriteLn();*)
(*    WriteLn();*)
(*    WriteString("EXTENDED MEMORY BLOCKS (EMB's):");*)

    WriteLn();
    WriteString("EMB (could be used like EMS): " );

    ErrorCode := EMBAvailable( LargestFreeK, TotalFreeK );

    IF (ErrorCode = 0) THEN
(*        WriteString("    Largest free block: ");*)
(*        WriteCardinal(LargestFreeK,5);*)
(*        WriteString("KB.  Total free : ");*)
        IF (TotalFreeK = 0) THEN
            WriteString("none available.");
        ELSE
            WriteCardinal(TotalFreeK,5);
            WriteString(" KB.");
        END;

        Where.OFFSET   := 0;
        i              := 1024;
        DOSCALL( 48H, i, Where.SEGMENT, ErrorCode );
        IF (ErrorCode <> 0) OR (i <> 1024) THEN
            WriteLn();
            WriteString( "    NOT ENOUGH DOS MEMORY TO CONTINUE." );
            RETURN Avail;
        END;

        IF (LargestFreeK > 30) THEN
            WriteString("  One moment, testing");
        END;

        TotalAllocated := 0;
        MemoryOK       := TRUE;
        i              := 1;

        WHILE (ErrorCode = 0)      AND
              (i <= HIGH(Handle))  AND
              (MemoryOK)           AND
              (LargestFreeK > 0)   DO
            ErrorCode := GetEMBMemory( LargestFreeK, Handle[i] );
            IF ((ErrorCode = 0) AND
               CheckExtended( LargestFreeK, Handle[i] )) THEN
                INC( TotalAllocated, LargestFreeK );
                INC(i);
                ErrorCode := EMBAvailable( LargestFreeK, TotalFreeK );
            END;
        END;

        Avail := FLOAT(TotalAllocated) * 1024.0;

        IF (NOT MemoryOK) THEN
            WriteLn();
            WriteString( "    DANGER!!  Extended Memory has BAD MEMORY CHIPS!!" );

        ELSIF (ErrorCode = XMSAllEMBHandlesInUse) THEN
            WriteLn();
            WriteString( "    Note that there are only " );
            WriteCardinal( i-1, 2 );
            WriteString( " Extended Memory Handles available," );
            WriteLn();
            WriteString( "    so Time Line can only access " );
            WriteCardinal( TotalAllocated, 5 );
            WriteString( "KB." );
            WriteLn();
            WriteString( "    Increase the /NUMHANDLES= parameter on your XMS driver." );

        ELSIF (ErrorCode <> 0) AND (ErrorCode <> XMSAllEMBAllocated) THEN
            WriteLn();
            WriteString( "    Trouble allocating Extended Memory:" );
            ReportError( ErrorCode );
(*        ELSE*)
(*            WriteLn();*)
(*            WriteString( "All Extended memory checked out." );*)
        END;


        FOR j := 1 TO i-1 DO
            ErrorCode := FreeEMBMemory( Handle[j] );
            IF (ErrorCode <> 0) THEN
                WriteLn();
                WriteString( "    Trouble freeing up Extended Memory:" );
                ReportError( ErrorCode );
            END;
        END;

    ELSE
        WriteString("Trouble getting at Extended Memory:" );
        ReportError( ErrorCode );

        Avail := 0.0;
    END;

    RETURN Avail;

END CheckEMB;










PROCEDURE SetupTestPatterns();
BEGIN
    AllMemoryOK     := TRUE;
    TestPatterns[1] := 05555H;  (* 0101010101010101 *)
    TestPatterns[2] := 0AAAAH;  (* 1010101010101010 *)
    TestPatterns[3] := 0FFFFH;  (* 1111111111111111 *)
    TestPatterns[4] := 00000H;  (* 0000000000000000 *)
    TestPatterns[5] := 0FF00H;  (* 1111111100000000 *)
    TestPatterns[6] := 000FFH;  (* 0000000011111111 *)
    TestPatterns[7] := 0F0F0H;  (* 1111000011110000 *)
    TestPatterns[8] := 00F0FH;  (* 0000111100001111 *)
END SetupTestPatterns;





(* Use this module rather than the EmsCalls.Mod module, as it refers to
   Dialog, LStrings, etc.  Code here taken from that module as needed.
*)
MODULE EMSCalls;


IMPORT
    (* TYPE *)                  ADDRESS, 
    (* CONST *)                 AX, BX, CX, DX, ES, DI,
    (* PROC *)                  GETREG, SETREG, SWI, DOSCALL, ADR;


EXPORT
    (* PROC *)      CheckForEMS, EMSGetStatus, EMSGetVersion,
                    EMSGetUnallocatedPages, EMSGetFrameAddresses,
                    EMSAllocatePages, EMSPageMap, EMSDeallocatePages;



CONST
    EMSInterrupt            = 67H;



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






PROCEDURE EMSGetStatus(): CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* EMSGetStatus *)

    SETREG(AX, 4000H);
    SWI(EMSInterrupt);
    GETREG(AX, i);

    RETURN (i DIV 100H);

END EMSGetStatus;



PROCEDURE EMSGetVersion(): CARDINAL;

VAR
    Status                  : CARDINAL;

BEGIN                       (* EMSGetVersion *)

    SETREG(AX, 4600H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    RETURN (Status MOD 100H);

END EMSGetVersion;




PROCEDURE EMSGetUnallocatedPages(VAR Free, Total : CARDINAL ): CARDINAL;

VAR
    Status                  : CARDINAL;
    FreePages,
    TotalPages              : CARDINAL;

BEGIN                       (* EMSGetUnallocatedPages *)

    SETREG(AX, 4200H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(BX, FreePages);
    GETREG(DX, TotalPages);

    Free  := FreePages;
    Total := TotalPages;

    RETURN (Status DIV 100H);

END EMSGetUnallocatedPages;





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

    SETREG(AX, 4100H);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(BX, Frame.SEGMENT);

    IF (NOT ((Status DIV 100H) = 0)) THEN
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
        FOR i := 0 TO 3 DO
            F := EMSGetPageFrame();
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

    IF (NOT ((Status DIV 100H) = 0)) OR (Count = 0) THEN
        RETURN 0;
    ELSIF (Count > HIGH(Map)+1) THEN   (* we overstepped the array bounds. *)
        HALT;
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

    SETREG(AX, 4300H);
    SETREG(BX, PagesWanted);
    SWI(EMSInterrupt);
    GETREG(AX, Status);
    GETREG(DX, Handle);

    EMSHandle := Handle;

    RETURN ((Status DIV 100H) = 0);

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

    PhysicalPage := (PhysicalPage MOD 100H) + 4400H;
    SETREG(AX, PhysicalPage);
    SETREG(BX, LogicalPage);
    SETREG(DX, EMSHandle);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    RETURN ((Status DIV 100H) = 0);

END EMSPageMap;



PROCEDURE DoFunctionOnHandle( Function   : CARDINAL;
                              EMSHandle  : CARDINAL) : BOOLEAN;

VAR
    Status                  : CARDINAL;

BEGIN

    SETREG(AX, Function);
    SETREG(DX, EMSHandle);
    SWI(EMSInterrupt);
    GETREG(AX, Status);

    RETURN ((Status DIV 100H) = 0);

END DoFunctionOnHandle;


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






END EMSCalls;





PROCEDURE WriteVersion( Version, Mod : CARDINAL );
BEGIN
    WriteCardinal( Version DIV Mod, 5 );
    WriteString( "." );
    WriteCardinal( Version MOD Mod, 1 );
END WriteVersion;







PROCEDURE CheckEMS() : BOOLEAN;
VAR
    Free,Total  : CARDINAL;
    EmsStatus   : CARDINAL;
    ok          : BOOLEAN;
    s           : ARRAY [0..15] OF CHAR;


    PROCEDURE TestEMS();
    VAR
        i, j,
        Pages       : CARDINAL;
        Handle      : CARDINAL;
        PageFrames  : ARRAY [1..4] OF ADDRESS;
    BEGIN
        Pages := EMSGetFrameAddresses( PageFrames );
        IF (Pages = 0) THEN
            WriteLn();
            WriteString( "No page frames available!" );
        ELSE
            IF (Pages > 4) THEN Pages := 4; END;
            WriteString( " pages: " );
            IF (EMSAllocatePages( Free, Handle )) THEN
                ok := TRUE;
                i  := 1;
                WHILE (ok AND (i <= Pages)) DO
                    IF (i > 1) THEN
                        WriteString( ", " );
                    END;

                    WriteHex( PageFrames[i].SEGMENT, 4 );

                    j  := 1;
                    WHILE (ok AND (j <= Free)) DO
                        IF (NOT EMSPageMap( Handle, j-1, i-1 )) THEN
                            ok := FALSE;
                            WriteLn();
                            WriteString( "EMS page cannout be mapped." );
                        ELSIF (NOT TestMemory( PageFrames[i], 16384, {2,7} )) THEN
                            ok := FALSE;
                            WriteLn();
                            WriteString( "EMS page contains bad memory." );
                        END;

                        IF (NOT ok) THEN
                            WriteString( "  Page " );
                            WriteCardinal( i, 3 );
                            WriteString( ", Frame " );
                            WriteCardinal( i, 2 );
                            WriteString( " (" );
                            WriteHex( PageFrames[i].SEGMENT, 4);
                            WriteString( ")" );
                        END;
                        INC(j);
                    END;
                    INC(i);
                END;
                EMSDeallocatePages( Handle );
            ELSE
                WriteLn();
                WriteString( "I can't allocate the free pages." );
            END;
        END;
    END TestEMS;


BEGIN
    ok := FALSE;  (* Assume failure. *)

    IF (CheckForEMS()) THEN
        EmsStatus := EMSGetStatus();
        IF (EmsStatus = 0) THEN
            EmsStatus := EMSGetVersion();
            WriteString( "EMS Driver version          : " );

            WriteVersion( EmsStatus, 10H );

            EmsStatus := EMSGetUnallocatedPages( Free, Total );
            IF (EmsStatus = 0) THEN
                WriteLn();
                WriteString("EMS (swapping data space)   : " );
                RealToString( FLOAT(Free) * 16.0, s );
                WriteTo5(s);
                WriteString( " KB free" );
                IF (Total <> Free) THEN
                    WriteString( " out of " );
                    RealToString( FLOAT(Total) * 16.0, s );
                    WriteString( s );
                    WriteString( " KB total" );
                END;
                WriteString( "." );
                IF (Free > 0) THEN
                    WriteLn();
                    WriteString( "    Testing" );
                    TestEMS();
                ELSE
                    ok := TRUE;
                END;
(*                TotalVirtual := TotalVirtual + (FLOAT(Free) * 16384.0);*)
            ELSE
                WriteString('EMS Driver allocation error  : ');
                WriteCardinal( EmsStatus, 5 );
            END;
        ELSE
            WriteString('EMS Driver error (bad status): ');
            WriteCardinal( EmsStatus, 5 );
        END;
    ELSE
        WriteString('No EMS Driver detected.');
        ok := TRUE;
    END;

    RETURN ok;

END CheckEMS;




TYPE
    AnAdapterType     = (None, MDA, CGA, EGAMono, EGAColor, VGAMono,
                         VGAColor, MCGAMono, MCGAColor);



    (*
        QueryAdapterType - Determine what type of adapter and display we're
                           using.

                           Adapted from a routine in the 2/89 issue of 
                           Dr. Dobb's Journal
    *)
PROCEDURE QueryAdapterType() : AnAdapterType;
    
VAR
    BL                      : CHAR;
    AL                      : CHAR;
    AdapterFound            : AnAdapterType;
    BXValue                 : CARDINAL;
    TempCard                : CARDINAL;

BEGIN
    AdapterFound := None;

    SETREG(AX, 01A00H);

    CODE(55H);
    SWI(10H);                (* Let's first check for VGA BIOS *)
    CODE(5DH);

    GETREG(AX, AL);
    GETREG(BX, BL);

    IF (ORD(AL) = 1AH) THEN  (* Well, guess we've got a VGA Adapter *)
        CASE ORD(BL) OF      (* Let's see what it's masquerading as *)
            00H : AdapterFound := None;
        |   01H : AdapterFound := MDA;
        |   02H : AdapterFound := CGA;
        |   04H : AdapterFound := EGAColor;
        |   05H : AdapterFound := EGAMono;
        |   07H : AdapterFound := VGAMono;
        |   08H : AdapterFound := VGAColor;
        |   0AH,
            0CH : AdapterFound := MCGAColor;
        |   0BH : AdapterFound := MCGAMono;

        ELSE
            AdapterFound := CGA;
        END;
    ELSE                     (* No VGA, let's see if we have EGA    *)
        SETREG(AX, 01200H);
        SETREG(BX, 00010H);

        CODE(55H);
        SWI(10H);
        CODE(5DH);
        
        GETREG(BX, BXValue);

        IF (ORD(BXValue) <> 010H) THEN  (* BX unchanged means no EGA *)
            (* Alright!!  If we get here, we've got EGA *)
            (* Let's see if it's color or mono *)
            
            SETREG(AX, 01200H);
            SETREG(BX, 010H);

            CODE(55H);
            SWI(10H);
            CODE(5DH);

            GETREG(BX, BXValue);

            BXValue := (BXValue DIV 256);

            IF (ORD(BXValue) = 0) THEN
                AdapterFound := EGAColor;
            ELSE
                AdapterFound := EGAMono;
            END;
        ELSE
            (* Well, guess we've got a lowly CGA or MDA, let's see which *)

            CODE(55H);
            SWI(11H);
            CODE(5DH);

            GETREG(AX, TempCard);

            TempCard := CARDINAL(BITSET(TempCard) * BITSET{4..5}) DIV 16;

            CASE TempCard OF
                1,
                2 : AdapterFound := CGA;
            |   3 : AdapterFound := MDA;
            ELSE
                AdapterFound := None;
            END;
                    
        END;

    END;

    RETURN(AdapterFound);

END QueryAdapterType;






PROCEDURE SetupVideoMemory() : CARDINAL;

TYPE
    ABunchOWords    = ARRAY [1..16384] OF CARDINAL;

VAR
    A000              [0A000H:0]    : ABunchOWords;
    B000              [0B000H:0]    : ABunchOWords;

    KB                              : CARDINAL;



    PROCEDURE NotEnoughMemory() : BOOLEAN;
    VAR
        Bx  : CARDINAL;
    BEGIN
        SETREG( AX, 1200H );
        SETREG( BX,   10H );
        CODE(55H);  (* PUSH BP   *)
        SWI(10H);   (* VIDEO SWI *)
        CODE(5DH);  (* POP BP    *)
        GETREG( BX,   Bx );
        RETURN ((Bx MOD 0FFH) < 3);
    END NotEnoughMemory;


    PROCEDURE MemMappedAlready( VAR Where : ABunchOWords ) : BOOLEAN;
    VAR
        T   : CARDINAL;
        ok  : BOOLEAN;
    BEGIN
(*$O-*)
        T           := Where[3990];   (* Save any old value *)
        Where[3990] := 0AEF0H;
        ok          := (Where[3990] = 0AEF0H);
        Where[3990] := T;             (* Put back old value *)

        RETURN ok;
(*$O=*)

    END MemMappedAlready;


BEGIN

    IF (NotEnoughMemory()) OR
       (MemMappedAlready(A000)) THEN
        KB := 0;
    ELSE
        KB := 64 + 20;  (* Really 24, but be conservative *)
        IF (NOT MemMappedAlready(B000)) THEN
            INC(KB, 32);
        END;
    END;

    RETURN KB;
        
END SetupVideoMemory;





PROCEDURE CallTech();
BEGIN
    WriteLn();
    WriteLn();
    WriteString( "      Call our Technical Support at (415) 898-1919 to see how to add this" );
    WriteLn();
    WriteString( "      to your TL.BAT file or the TIMELINE= environment variable." );
END CallTech;






PROCEDURE TestXMS();
VAR
    TotalSched,
    TotalVirtual    : REAL;
    VideoFree       : CARDINAL;
    AdapterType     : AnAdapterType;
    DoVideoCheck,
    EMSBad,
    XMSBad          : BOOLEAN;
    s               : ARRAY [0..15] OF CHAR;
BEGIN
    SetupTestPatterns();
    SomeErrorOccured := FALSE;

    EMSBad       := FALSE;
    XMSBad       := FALSE;
    DoVideoCheck := FALSE;

    IF (XMSStartup()) THEN
        WriteString('XMS Driver specification rev: ');
        WriteVersion(XMSStatsRecord.XMSSpecificationVersion, 100H);
        WriteString(', driver version : ');
        WriteVersion(XMSStatsRecord.XMSDriverVersion, 100H);
(*        WriteLn();*)

        TotalSched   := CheckHMA() + CheckUMB();
        TotalVirtual := CheckEMB();
        XMSBad := (SomeErrorOccured OR (NOT AllMemoryOK));
    ELSE
        WriteString('No XMS Driver detected.');
        DoVideoCheck := TRUE;
    END;

    WriteLn();

    EMSBad := (NOT CheckEMS());

    IF (EMSBad OR XMSBad) THEN
        WriteLn();
        WriteString( "Because of the above errors, PLEASE USE TIME LINE THIS WAY:" );
        WriteLn();
        WriteLn();
        IF (XMSBad AND EMSBad) THEN
            WriteString( "     TL ADDIN IS (-TLXMS,-TLEMS)" );
        ELSIF (XMSBad) THEN
            WriteString( "     TL ADDIN IS -TLXMS" );
        ELSE
            WriteString( "     TL ADDIN IS -TLEMS" );
        END;
        CallTech();
    END;

    XMSShutDown();  (* Do this AFTER EMS calcs. *)

    AdapterType := QueryAdapterType();

    IF ((AdapterType = EGAColor)  OR
        (AdapterType = VGAColor)) THEN
        VideoFree := SetupVideoMemory();
        IF (VideoFree > 0) THEN

            WriteLn();
            WriteLn();
            WriteString( "VIDEO Memory:" );
            WriteCardinal( VideoFree, 3 );
            WriteString( " KB is available for schedule data from your video card," );
            WriteLn();
            WriteString( "              although this memory is usually pretty slow in comparison" );
            WriteLn();
            WriteString( "              to regular memory." );
            WriteLn();

            IF (DoVideoCheck) THEN
                WriteString( "              Since you don't have XMS, it may be worth considering." );
            ELSE
                WriteString( "              Try Time Line with just XMS memory, and see if that is enough." );
            END;

            WriteLn();
            WriteLn();
            IF (EMSBad OR XMSBad) THEN
                WriteString( "         To use the video memory, call Time Line technical support." );
            ELSE
                WriteString( "         To use the video memory, try this command:" );
                WriteLn();
                WriteLn();
                WriteString( "             TL ADDIN IS TLVIDMEM" );
                CallTech();
            END;

            TotalSched := TotalSched + (FLOAT(VideoFree) * 1024.0);
        END;
    END;

    RealToString( TotalSched / 1024.0, s );
    WriteLn();
    WriteLn();
    WriteString( "Total available extra schedule data   : " );
    WriteTo5(s);
    WriteString( " KB." );

(*    RealToString( TotalVirtual, s );*)
(*    WriteLn();*)
(*    WriteString( "Total fast swapping room    : " );*)
(*    WriteString( s );*)
(*    WriteString( " bytes." );*)

    WriteLn();

END TestXMS;





BEGIN

    TestXMS();

END XMSCheck.
