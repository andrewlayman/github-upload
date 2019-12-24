    (*V1=PRODUCTION Fast enough to ship. *)
    (*V2=DEBUG Extra checking code. *)
    (*V3=TRACE Extra code to allow debugging and tracing. *)
    (*V4=PARANOID Requires TRACE. Adds checksumming. *)
    (*V5=STATISTICS Tracks some statistics on locks. *)
    (*V6=OS2 OS/2 code changes. *)
    (*V7=DOS Regular DOS TL code. *)

    (* WARNING -- Check comments labled "WARNING" for secret tricks,
                  assumptions, short cuts and other risky stuff. *)



IMPLEMENTATION MODULE FlexStor;

  (* MODIFICATION HISTORY   (Original Author AJL)

        5/6/87  RSC  Made Handle a VAR on the Discard call.
                     Activated "HandleIsValid".
        5/7/87  AJL  Added Get and Set procs for Tag and Storage
                     preference.  Added CopyExtObject proc.
                     Added AnExtTagSet.
        5/7/87  RSC  Delete change size routine.  Add MakeHeapCopy and
                     SaveHeapCopy.  Ajust some other minor things.
       5/12/87  RSC  debugging fixes.  caller beware that you may get back
                     a size of 0 from calls! 
        5/13/87  RSC  Added new parameters to get and put calls.  Added
                      "ArraySize" and "NumberOfElements" functions.
       5/21/87   AJL  Rewriting for new record structures, pages, etc.
       7/7/87    AJL  Code is here to create and discard pages via the
                      PageSupply, but not to retrieve them or write them.
       7/30/87   AJL  Removed Tags.
       8/28/87   AJL  Added a basic initialization call to module init.
       9/3/87    AJL  Fixed SetManyExtObjects.
       9/15/87   AJL -Added the Version switch "RELEASE".  If not chosen,
                      then the ReleasePage procedure will not be called,
                      meaning that the PageSupply module must itself
                      check the lock count in the page header before
                      moving a page.
                 AJL -SetExtSize will return FALSE if a size that is
                      too large is requested.
                 AJL -Fix the calculation of the page overhead.
                 AJL -Removed CheckSumThePageTable.
                     -Moved the debugging diagnostics to other
                      modules, FlexTrace and FlexDbug.
                     -Fuss about odd-sized objects.
                 AJL -Changed calls to WritePage to just setting the
                      Dirty flag in the header.
                 AJL -Made it the responsibility of the PageSupply
                      to set PageTable[ ].Location to NIL when the
                      page is not in memory.
                     -Removed WritePage and ReleasePage.
                     -Added GetExtStatus.
      07-Jan-88 LAA  -Added ReleaseUnchangedHandle to implement the 
                      UnlockUnchangedDataObject method of TreeObjects.
      12-Jan-88 AJL  -Moved the setting of the page's dirty bit from the
                      Lock to the Unlock call.
                     -Fixed a bug in which the ReleaseUnchangedHandle was
                      clearing the dirty bit.  No one except the PageSupply
                      should do this.
      19-Jan-88 AJL  -We are using a count in the PageTable records, FreeBytes,
                      that records the amount of free space in each record (though
                      it may be discontinuous).  This is to speed up the 
                      creation of new objects so that we can avoid reading
                      pages into memory that do not have enough room for the
                      object.
      25-Jan-88      -Changed NextClass so that we are more reluctant to 
                      allocate Fast memory. 
      28-Jan-88      -After Discarding a handle, check to see if we can
                      discard the cell block that contains it.
      29-Jan-88      -Improved the internals of the DiscardEmptyCelBlocks call.
      17-Feb-88      -Implemented GetExtStoragePreference.
                     -Turned many calls of NotYEtImplemented into ReportError;
      20-Feb-88      -Odd lengthed itemes now do not call ReportError, but
                      merely Trace, and only if DEGUG is on.
       8-Mar-88  AJL -Changed to use a status record returned from PageClassStatus. 
       9-Mar-88  AJL -Corrected an error in ReportErrorPhrase. 
       5-Oct-88  AJL -Moved the management of records within pages to FlexPage.
                     -Moved LockHandle code internal to LockObject for speed.
                      Ditto for ReleaseObject and ReleaseUnchangedObject.
                     -Word-aligned some variables for speed.
      12-Oct-88  RSC -Fixed uninitialized variable "OK".  Made it TRUE.
      27-Oct-88  AJL -Removed the restriction that made all records at least
                      30 bytes long.  This is necessary since CreateExtObjWithSize
                      no longer corrects the size of an object after creating 
                      it.
      10-Jan-89 RSC  -Changed Storage to Space.
      22-Feb-89 AJL  -APageNo is now 16 bits, not 8 bits.
                     -PageTable is now a pointer. 
      05-Aug-89 WKH  -First edits for OS/2.
      11-Aug-89 RSC  -Full OS/2 implementation.
      21-Aug-89 RSC  -Alter definition of GetExtStatus to return queazy if
                      we run low on FlexStor memory from Medium or Slow
                      storage (DOS only).
      12-Sep-89 AJL  -Correct comment:  ; Now AX:DX is the normalized address

      25-Sep-89 LAA  -Return a status of BAD when interlocked.  This will
                      allow Rugs to still get space for a rug even when we're
                      low on space, but not when we're interlocked.

      13-Nov-89 RSC  -Change the limit of the array of the cell block table.
                      The table is allocated as ARRAY CHAR OF ...., but the
                      limit was set as 255C, not 377C.

      14-Nov-89 RSC - Make Create, Lock, UnLock, and Dispose be stealable.
                      In the past, this could have helped us in debugging
                      nasty problems, and so I assume that it will help
                      us in the future.  Heh, heh, heh....

      17-Nov-89 RSC - Yes.  Well.  Ahem.  My fix of 13-Nov was not as well
                      tested as I thought.  It seems that if you delete all
                      cells in a cell block, you hang on a WHILE () loop.
                      See my date stamp around line 1200.
      12-Jun-90 AJL - Add the ability to EnlargePageTable if we want to 
                      dynamically add more pages during AddPage.
       3-Jun-90 AJL - Modify CopyExtHandle so it won't have an aliasing problem
                      when the same variable is passed in as both OriginalHandle
                      and NewHandle.

      29-Aug-90 CL  - Initialize Size to 0 in MakeHeapCopy.             
       6-Feb-91 RSC - Change copy bytes to NOT NORMALIZE ADDRESSES.
                      (the one in FlexPage may need to, this one cannot,
                      because the heap may be in the HMA.)
      24-Apr-91 AJL - Add specific error messages to StorageError.
      18-Sep-91 AJL - In order to reduce fragmentation, always free up as
                      much temporary memory as possible before allocating a
                      new cell block, since they cannot be moved, and we
                      would like them loaded as low as possible. 
      25-Sep-91 AJL - Display an error message if unable to create a new
                      block.

      *** NOTE *** 

         The Modula-2 compiler, even with the /-A option, will pad odd-length
         records in arrays to make them even lengthed.  So, SIZE and TSIZE
         of the record will be ODD, but SIZE(Array) will be EVEN.  Because of
         this, all the get and save calls use RecordSize and RecordCount to
         compute the "real" size.  These numbers are NOT saved with the
         data, so the caller should be consistant with calling these routines
         with proper sizes.  TSIZE(ARecord) and SIZE(Record) and SIZE(Array[0])
         all work equally well.

     Also, note:

         When you see this construct:

             CARDINAL(BITSET( RecordSize + 1 ) * BITSET( 0FFFEH ));

         I am getting the RecordSize rounded up to the next even size.
         This is functionally equivelent to:
             IF ODD(RecordSize) THEN INC(RecordSize); END;
         But, according to Andrew, the easier-to-read version is much slower.
         The CARDINAL(...) emits only two instructions.
   *)

(*<OS2
FROM BlockOps IMPORT
    (* PROC *)      BlockMove;
OS2>*)

FROM LStrings IMPORT
    (* PROC *)      ConcatLS, CtoS, SetString;

FROM MsgFile  IMPORT
    (* PROC *)      GetMessage;

FROM Dialog  IMPORT
    (* PROC *)      ErrorPhrase, FatalError, NotYetImplemented;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          SendNotices;

(*<DOS*)
FROM PageSupply IMPORT
    (* TYPE *)      APageClass, APageHandle, APageClassStatus,
    (* PROC *)      CreatePage, DiscardPage, RetrievePage,
                    SynchPage, PageClassStatus,
                    StartupPageClass, ShutdownPageClass;
(*DOS>*)

FROM Space     IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM  IMPORT
    (* CONST *)     CX,
    (* TYPE *)      BYTE, TSIZE, SIZE, ADDRESS, ADR,
    (* PROC *)      SETREG, CODE;


FROM FlexData IMPORT

    (* CONST *)    MaxDataSize, MaxUserRecordsPerPage, MaxRecordsPerPage,
                   MaxRecordSize, BPBS, BitsetsPerPageSet,
                   MaxRecords, MaxPages, MaxGeneration, MaxCellPerBlock,

    (* TYPE *)     ACellBlockNumber, ACellNo, APageNo,
                   AGeneration, ARecordNo,
                   ACellInfo, ACellBlock, ACellPointer, APageIndexArray,
                   APageHeader, APageSet, APage, APagePointer, APageInfo,
                   APageTable, AHandlesInternals,

    (* VAR *)      CellBlockTable, TopCellBlock, PageTable,
                   CellTableCheck, PageTableCheck, Quantity, MaxPageSize,
                   MinPageSize, PageOverhead, MaxDataBytesPerPage,
                   ClassPageSize,
                   
    (* PROC *)     EnlargePageTable;


(*<DOS*)
FROM FlexPage    IMPORT
    (* PROC *)     InitializePage, DataAddress, SizeOfRecord, PageHasRoomFor,
                   AddRecordToPage, SetRecordSize, RemoveRecordFromPage,
                   MarkPageDirty, SqueezePage, CheckSumAPage, TestPageCheckSum;
   
(*DOS>*)



    (* ------------- DEBUGGING ---------------------------*)

(*<DOS*)
              (*<TRACE

FROM CRC16    IMPORT
    (* PROC *)      CheckSum;

FROM FlexTrace      IMPORT
                           Trace, TraceLS,
                           TraceSize, TraceHandle, TraceHandleAndSize,
                           TraceOn, TraceOff;


              TRACE>*)
(*DOS>*)


CONST  ModuleNumber = 22500; (* For GetMessage *)
       MAXCARDINAL  = 65535;



TYPE
(*<OS2
    AnExtHandle     = POINTER TO RECORD
        Size        : CARDINAL;
        UserData    : POINTER TO ARRAY [0..(MAXCARDINAL-1)] OF CHAR;
    END;
OS2>*)

(*<DOS*)
    AnOddSizedRecord    = RECORD X: ARRAY [0..2] OF CHAR; END;
    TwoOddSizedRecords  = ARRAY [0..1] OF AnOddSizedRecord;
    AnExtHandle         = POINTER TO BYTE; (* Not Really *)
    AClassSet           = SET OF APageClass;

VAR
    Interlock          : CARDINAL; 
    LastPageAdded      : ARRAY APageClass OF APageNo;
    LotsOfRoom         : ARRAY APageClass OF BOOLEAN;


   (*<STATISTICS
   OutstandingLocks,
   MostOutstandingLocks : CARDINAL;
   STATISTICS>*)
(*DOS>*)



    (* Speedups needed:


       4.  CheckSumming the pages and tables is only for development
           testing.  It is not meant to make it into shipping code.

    *)








    (*$R-*) (*$S-*) (*$T-*)





(*<OS2
PROCEDURE CopyBytes( From, To : ADDRESS;  Length : CARDINAL );
BEGIN

    BlockMove(To, From, Length);

END CopyBytes;
OS2>*)


(*<DOS*)
PROCEDURE CopyBytes( From, To : ADDRESS;  Length : CARDINAL );
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
    SETREG (CX, Length);
    CODE (REPNZ, MOVSB);


(*
CODE	SEGMENT	PARA 'code'
	ASSUME	CS:CODE


    ;(* Move Length Bytes *)

    MOV CX, [BP+4]        ; CX := Length
    JCXZ OUT

  ;(* Normalize address at BP+6  *)

    MOV AX, [BP+6  ]      ;  AX := Offset DIV 16
    MOV CL, 4
    SHR AX, CL
    ADD [BP+8], AX      ;  Segment := Segment + (Offset DIV 16);
    AND WORD PTR [BP+6], 0FH       ;  Offset := Offset MOD 16

  ;(* Normalize address at BP+A  *)

    MOV AX, [BP+0AH]      ;  AX := Offset DIV 16
    MOV CL, 4
    SHR AX, CL
    ADD [BP+0CH], AX      ;  Segment := Segment + (Offset DIV 16);
    AND WORD PTR [BP+0AH], 0FH       ;  Offset := Offset MOD 16

    MOV CX, [BP+4]       ; Bytes to move

   ;(*  Compare normalized addresses at [BP+6] and [BP+A] *)

    MOV AX,[BP+08H]       ; Compare segments To
    CMP AX,[BP+0CH]       ;  and From
    JB  BIGGER
    JNE SMALLER
    MOV AX,[BP+06H]       ; Segments equal.  Compare offsets.
    CMP AX,[BP+0AH]
    JB  BIGGER
    JE  OUT               ; Get out if addresses are equal.

    ; Here if From < To
SMALLER:
    STD                  ; Auto Decrement
    MOV AX, [BP+8]       ; To segment
    MOV BX, [BP+0CH]     ; From segment
    MOV DI, [BP+6]       ; ES:DI ------> To
    MOV ES, AX           ;
    MOV SI, [BP+0AH]     ; DS:SI ------> From
    MOV DS, BX
    ADD DI, CX           ; ES:DI  ---->  To[Length]
    DEC DI
    ADD SI, CX           ; DS:SI  ---->  From[Length]
    DEC SI
    REP MOVSB            ; COPY CX bytes
    CLD                  ; Auto Increment
    JMP OUT


    ; Here if From > To
BIGGER:
    CLD
    MOV AX, [BP+8]       ; To segment
    MOV BX, [BP+0CH]     ; From segment
    MOV DI, [BP+6]       ; ES:DI ------> To
    MOV ES, AX           ;
    MOV SI, [BP+0AH]     ; DS:SI ------> From
    MOV DS, BX
    REP MOVSB            ; COPY CX bytes

OUT:
    NOP

CODE	ENDS
        END


    CODE(

       8BH, 4EH, 04H,
       0E3H, 65H       );

    CODE(
       8BH, 46H, 06H,
       0B1H, 04H,
       0D3H, 0E8H,
       01H, 46H, 08H,
       81H, 66H, 06H, 0FH, 00,

       08BH, 46H, 0AH,
       0B1H, 04H,
       0D3H, 0E8H,
       01H, 46H, 0CH,
       81H, 66H, 0AH, 0FH, 00 );

    CODE(
       8BH, 4EH, 04 );

    CODE(
       8BH, 46H, 08H,
       3BH, 46H, 0CH,
       72H, 29H,
       75H, 0AH,
       08BH, 46H, 06H,
       3BH, 46H, 0AH,
       72H, 1FH,
       74H, 30H );

    CODE(
       0FDH,

       8BH, 46H, 08H,
       8BH, 5EH, 0CH,
       8BH, 7EH, 06H,
       8EH, 0C0H,
       8BH, 76H, 0AH,
       8EH, 0DBH,
       03H, 0F9H,
       4FH,
       03H, 0F1H,
       4EH,
       0F3H, 0A4H,
       0FCH,
       0EBH, 14H, 90H );

    CODE(
       0FCH,
       8BH, 46H, 08H,
       8BH, 5EH, 0CH,

       8BH, 7EH, 06H,
       8EH, 0C0H,
       8BH, 76H, 0AH,
       8EH, 0DBH,
       0F3H, 0A4H
    );

*)

END CopyBytes;
(*DOS>*)

    (*$R=*) (*$S=*) (*$T=*)








PROCEDURE DiagnosticHook( WithMenu : CARDINAL ) : CARDINAL;
BEGIN
(*<DOS*)
    RETURN Quantity;
(*DOS>*)
(*<OS2
    RETURN 0;
OS2>*)
END DiagnosticHook;






    (*$R-*)  (*$S-*)  (*$T-*)         (* Turn off checks. *)

PROCEDURE ArraySize  ( Records, RecordSize : CARDINAL ) : CARDINAL;
BEGIN
    IF (Records = 1) OR (RecordSize = 1) THEN
        RETURN Records * RecordSize;
    ELSE
        RETURN (Records * CARDINAL(BITSET( RecordSize + 1 ) * BITSET( 0FFFEH )));
    END;
END ArraySize;







    (* NumberOfElements - # of elements in an array.  Takes into account  
                          odd sized records.

       Preconditions  -- # of bytes in the full array of records.     
                         Size of one record from SIZE/TSIZE.

       Postconditions -- Returns # of records in the full array.  
    *)


PROCEDURE NumberOfElements( ArraySize, RecordSize : CARDINAL ) : CARDINAL;
BEGIN
    IF (RecordSize = ArraySize) OR (RecordSize = 1) THEN
        RETURN ArraySize DIV RecordSize;
    ELSE
        RETURN (ArraySize DIV CARDINAL(BITSET(RecordSize + 1) * BITSET(0FFFEH)));
    END;
END NumberOfElements;






(*<DOS*)
PROCEDURE DecodeHandle(    Handle     : AnExtHandle;
                       VAR CellPointer: ACellPointer;
                       VAR Generation : AGeneration );
BEGIN
    (*
CODE	SEGMENT	PARA 'code'
	ASSUME	CS:CODE




    LES AX, [BP+0CH]       ; ES:AX := Handle
    LDS BX, [BP+4]         ; DS:BX ------> Generation
    MOV [BX], AH           ; Store the generation
    MOV AH, 00             ; Erase the generation
    LDS BX, [BP+8]         ; DS:BX ------> CellPointer
    MOV [BX], AX           ; Store the pointer
    MOV [BX+2], ES



CODE ENDS

END
    *)

    CODE(
        0C4H, 46H, 0CH,
        0C5H, 5EH, 04H,
        088H, 27H,
        0B4H, 00H,
        0C5H, 5EH, 08H,
        089H, 07H,
        08CH, 47H, 02H);

END DecodeHandle;
(*DOS>*)








(*<DOS*)
PROCEDURE EncodeHandle(    CellPointer: ACellPointer;
                           Generation : AGeneration;
                       VAR Handle     : AnExtHandle    );
BEGIN

   (*
CODE	SEGMENT	PARA 'code'
	ASSUME	CS:CODE


        ; Normalize the address in CellPointer.
    MOV AX, [BP+0AH]      ; AX := Offset
    MOV BX, [BP+0CH]      ; BX := Segment
    MOV DX,AX             ; DX := Offset MOD 16
    AND DX, 0000FH
    SHR AX, 1             ; AX := Offset DIV 16
    SHR AX, 1
    SHR AX, 1
    SHR AX, 1
    ADD AX, BX            ; AX := (Segment + Offset DIV 16)
        ; Now AX:DX is the normalized address
        ; Add in the Generation
    MOV DH, BYTE PTR [BP+8]
        ; Store the results
    LDS SI, [BP+4]
    MOV [SI], DX
    MOV [SI+2], AX

CODE ENDS

END
   *)

    CODE(
         8BH, 46H, 0AH,
         8BH, 5EH, 0CH,
         8BH, 0D0H,
         81H, 0E2H, 0FH, 00H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         03H, 0C3H,
         8AH, 76H, 08H,
         0C5H, 76H, 04H,
         89H, 14H,
         89H, 44H, 02H );

END EncodeHandle;
(*DOS>*)


    (*$R=*)  (*$S=*)  (*$T=*)




    (* This must be optimized! *)

    (*$R-*) (*$S-*) (*$T-*)


(*<DOS*)
PROCEDURE CheckAndDecodeHandle(     Handle    : AnExtHandle;
                                VAR Page      : APagePointer;
                                VAR RecNo     : ARecordNo
                              ) : BOOLEAN;
VAR
    CellPointer: ACellPointer;
    Gen        : AGeneration;
    PageNum    : CARDINAL;
BEGIN
    (*
    DecodeHandle(Handle,CellPointer,Gen);
    *)

    (*
    CODE	SEGMENT	PARA 'code'
	ASSUME	CS:CODE




    LES AX, [BP+0CH]       ; ES:AX := Handle
    MOV [BP-4], AH           ; Store the generation
    MOV AH, 00             ; Erase the generation
    MOV [BP-8], AX           ; Store the pointer
    MOV [BP-6], ES

    CODE ENDS

    END
    *)

    CODE(
        0C4H, 46H, 0CH,
        088H, 66H, 0FCH,
        0B4H, 00H,
        089H, 46H, 0F8H,
        08CH, 46H, 0FAH  );
    WITH CellPointer^ DO
        IF (Gen <> Generation) THEN
            StorageError(0);
            RETURN FALSE;
        END;
        PageNum := PageNo;
        RecNo   := ORD(RecordNo);
    END;

    (*<DEBUG*)
    IF (PageNum = 0)
        OR (PageNum > MaxPages) OR (RecNo > MaxUserRecordsPerPage)
        OR (NOT PageTable^[PageNum].Valid)
    THEN
        StorageError(2);
        RETURN FALSE;
    END;
    (*DEBUG>*)


    WITH PageTable^[PageNum] DO

        IF (Location = NIL) AND
           (NOT RetrievePage(StorageClass,PageNum)) THEN
            StorageError(3);
            RETURN FALSE;
        END;
        Page   := Location;
    END;


    RETURN TRUE;

END CheckAndDecodeHandle;
(*DOS>*)

    (*$R=*)  (*$S=*)  (*$T=*)





    (*<TRACE


(*<DOS*)
PROCEDURE CheckSumTheCellTable();
BEGIN
    (*<PARANOID
    CellTableCheck := CheckSum(CellBlockTable[0C],SIZE(CellBlockTable[0C]));
    PARANOID>*)
END CheckSumTheCellTable;
(*DOS>*)








(*<DOS*)
PROCEDURE TestCheckSums(VAR Page:APage);
BEGIN
    (*<PARANOID
   IF (CheckSum(CellBlockTable[0C],SIZE(CellBlockTable[0C])) <> CellTableCheck) THEN
       StorageError(4);
   END;
   TestPageCheckSum(Page);
    PARANOID>*)
END TestCheckSums;

(*DOS>*)
    TRACE>*)






PROCEDURE StorageError(n:CARDINAL);
BEGIN
(*<DOS*)
    IF (Interlock > 0) THEN
        RETURN;
    END;
    INC(Interlock);
(*DOS>*)
    ErrorPhrase(ModuleNumber+n);
(*<DOS*)
    DEC(Interlock); 
(*DOS>*)
END StorageError;









    (* InitExtStorage -- Initialize the ExtStorage module.

       Preconditions  -- The Storage module must be installed and
                         active.
                         MaxDataSizeWanted must be > 0.

       Postconditions -- The ExtStorage module will be ready to store
                         and retrieve objects, or else FALSE will be
                         returned.

                         When TRUE is returned, the system will be
                         ready to store objects up to MaxDataSizeAvailable
                         bytes long.
    *)

PROCEDURE InitExtStorage(      MaxDataSizeWanted    : CARDINAL
                        ) : BOOLEAN;
VAR
(*<DOS*)
    Class : APageClass;
    Size  : CARDINAL;
(*DOS>*)
BEGIN
(*<DOS*)
        (*<TRACE
    Trace("InitExtStorage");
        TRACE>*)

    MinPageSize := 0FFFFH;
    MaxPageSize := 0;

    FOR Class := PageFast TO PageSlow DO
        Size := StartupPageClass(Class);
        ClassPageSize[Class]  := Size;
        IF (Size > 0) THEN
            IF (Size < MinPageSize) THEN
                MinPageSize := Size;
            END;
            IF (Size > MaxPageSize) THEN
                MaxPageSize := Size;
            END;
        END;
    END;

    IF (MaxPageSize < MinPageSize) THEN   (* No storage classes active *)
        StorageError(5);
    END;

    MaxDataBytesPerPage := MinPageSize - PageOverhead;

    RETURN (MaxDataSizeWanted <= MaxDataBytesPerPage);
(*DOS>*)
(*<OS2
    RETURN TRUE;
OS2>*)
END InitExtStorage;








    (* MaximumRecordSize  --

       Preconditions  -- The Storage module must be installed and
                         active.

       Postconditions -- We return the size, in bytes, of the largest
                         record that we can handle.
    *)

PROCEDURE MaximumRecordSize(): CARDINAL;
BEGIN
(*<DOS*)
    RETURN MaxDataBytesPerPage;
(*DOS>*)
(*<OS2
    RETURN MAXCARDINAL;
OS2>*)
END MaximumRecordSize;











(*<DOS*)
PROCEDURE NextClass( VAR Class : APageClass; Tried : AClassSet );
BEGIN
    CASE Class OF
          PageFast     : Class := PageMedium;
        | PageMedium   : Class := PageSlow;
        | PageSlow     : Class := PageMedium;
    END;
    IF (Class IN Tried) THEN
        Class := PageFast;
        WHILE (Class IN Tried) AND (Class < PageSlow) DO INC(Class); END;
    END;
END NextClass;
(*DOS>*)




(*<DOS*)
PROCEDURE FindAvailablePageClass(     Storage : AnExtStoragePreference;
                                      Size    : CARDINAL )
                                  : APageClass;
VAR
    Class : APageClass;
    Tried : AClassSet;
BEGIN

        (* Find a page class that is active.  This routine will
           not always return the requested page class, but will
           search for alternate classes if the original is unavailable. *)

    Class := APageClass(Storage);
    Tried := AClassSet{};

    WHILE (Tried <> AClassSet{PageFast,PageMedium,PageSlow}) DO
        INCL(Tried,Class);
        IF (ClassPageSize[Class] >= (Size + PageOverhead)) THEN
            RETURN Class;
        END;
        NextClass(Class,Tried);
    END;


    StorageError(6);
END FindAvailablePageClass;
(*DOS>*)




(*<DOS*)
PROCEDURE MakeNewPage( VAR PageNo   : APageNo;
                           Storage  : AnExtStoragePreference
                     ) : BOOLEAN;
VAR
    Page : APagePointer;
    PageSize : CARDINAL;
    PageHandle : APageHandle;
    Class      : APageClass;
    Tried : AClassSet;
BEGIN
    Tried := AClassSet{};

    Class := FindAvailablePageClass(Storage,1);


        (* This routine assumes that MaxPages > 0 *)

    WHILE (Tried <> AClassSet{PageFast,PageMedium,PageSlow}) DO
        INCL(Tried,Class);

            (* Try to create a page in this class. *)
        PageNo := 1;
        LOOP
            IF (NOT PageTable^[PageNo].Valid) THEN
                IF (CreatePage( Class, PageNo, PageSize ) ) THEN
                    WITH PageTable^[PageNo] DO
                        StorageClass := Class;
                        Valid        := TRUE;
                        Page         := Location;
                    END;
                    InitializePage(Page^,PageSize,PageNo);
                    PageTable^[PageNo].FreeBytes := Page^.Header.DataBytesThisPage;
                    MarkPageDirty(Page^);
                    LastPageAdded[ Class ] := PageNo;
                    RETURN TRUE;
                ELSE
                    LotsOfRoom[ Class ] := FALSE;
                    EXIT;
                END;
            ELSIF (PageNo >= MaxPages) THEN       (* Page table is too small? *)
                IF (EnlargePageTable(64)) THEN    (* Changes PageTable and MaxPages! *)
                ELSE
                    EXIT;                         (* No ability to enlarge the page table. *)
                END;
            END;
            INC(PageNo);
        END;

        NextClass(Class,Tried);

    END; (* While not tried all page classes. *)

    StorageError(1);

    RETURN FALSE;
END MakeNewPage;
(*DOS>*)





















(*<DOS*)
PROCEDURE FindExistingRoomFor(     Size     : CARDINAL;
                                   Class    : APageClass;
                               VAR PageNo   : CARDINAL
                              ) : BOOLEAN;
VAR
    Page : APagePointer;
    Tried : AClassSet;
BEGIN
        (*<TRACE
    IF (Size > MaxRecordSize) THEN
        FatalError();
    END;
        TRACE>*)

        (* Can we find an existing page of this class with enough
           memory.  There are several reasons that might prevent us:
           1.  There are no pages of this class.
           2.  There are none with enough room.
           3.  It is not possible to add more pages of this class.
        *)

          (* Search this class for an available page. *)

    PageNo := LastPageAdded[ Class ];

    WHILE (PageNo <> 0) DO

        WITH PageTable^[PageNo] DO
            IF (Valid)
                  AND (StorageClass = Class )
                  AND (FreeBytes >= Size) THEN
    
                IF (Location = NIL) AND
                   (NOT RetrievePage(StorageClass,PageNo)) THEN
                    StorageError(7);
                    RETURN FALSE;
                END;
    
                Page := Location;
                IF (Page^.Header.NeedsSqueeze) AND (Page^.Header.LockCount = 0) THEN
                    SqueezePage(Page^);
                END;
                IF (PageHasRoomFor(Page^,Size)) AND
                   (Page^.Header.LastEntry < MaxUserRecordsPerPage) THEN
                    RETURN TRUE;
                END;
            END;

        END;                               (* END WITH *)

        DEC(PageNo);
    END;                                   (* END WHILE *)

    RETURN FALSE;

END FindExistingRoomFor;
(*DOS>*)



    (* FindRoomFor --

       Finds a page with enough room that Size bytes coud be added to
       it as a record without moving any existing records . . . though
       this procedure may cause the target page to be squeezed before
       returning.

       *)

(*<DOS*)
PROCEDURE FindRoomFor(     Size     : CARDINAL;
                           Storage  : AnExtStoragePreference;
                       VAR PageNo   : CARDINAL
                     ) : BOOLEAN;
VAR
    Page : APagePointer;
    Class : APageClass;
    Tried : AClassSet;
BEGIN
        (*<TRACE
    IF (Size > MaxRecordSize) THEN
        FatalError();
    END;
        TRACE>*)

    Class := FindAvailablePageClass(Storage,1);

        (* Can we find an existing page of this class with enough
           memory.  There are several reasons that might prevent us:
           1.  There are no pages of this class.
           2.  There are none with enough room.
           3.  It is not possible to add more pages of this class.
        *)

    Tried := AClassSet{};
    PageNo := 0;

    LOOP

          (* Search this class for an available page. *)

        IF FindExistingRoomFor(Size,Class,PageNo) THEN
            RETURN TRUE;
        END;

            (* If this class is still valid and has the potential
               to make more pages, then make a new page.
               Otherwise continue the search into the page class that
               is taking the overflow. *)

        IF (LotsOfRoom[ Class ]) THEN
            EXIT;
        END;

            (* If there is no room in pages of the original or
               any overflow class then make a new page. *)

        INCL(Tried,Class);

        IF (Tried = AClassSet{PageFast,PageMedium,PageSlow}) THEN
            EXIT;
        END;

        NextClass(Class,Tried);

    END;

       (* 0 > PageNo > MaxPages or else PageNo is good page number. *)

    RETURN (MakeNewPage(PageNo,Storage));

END FindRoomFor;
(*DOS>*)









(*<DOS*)
PROCEDURE AddRecordToSomePage( RecordSize : CARDINAL;
                               Storage  : AnExtStoragePreference;
                           VAR PageNo   : CARDINAL;
                           VAR RecNo    : CARDINAL
                          ) : BOOLEAN;
VAR
    Page : APagePointer;
    Data, NextIndex : ADDRESS;
    Last : CARDINAL;
    Size : CARDINAL;
BEGIN
    Size := RecordSize;

    IF (FindRoomFor(Size,Storage,PageNo)) THEN
        Page := PageTable^[PageNo].Location;

        IF NOT AddRecordToPage(Page^,RecNo,Size) THEN
            StorageError(8);
        END; 

            (* Now that we've added a new record to the page, decrease
               our in-memory copy of the amount of free space left in it. *)

        DEC( PageTable^[PageNo].FreeBytes, SizeOfRecord(Page^,RecNo) );

        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END AddRecordToSomePage;
(*DOS>*)




(*<DOS*)
PROCEDURE FindEmptyCell( VAR BlockNumber : ACellBlockNumber;
                         VAR CellNo      : ACellNo       ) : BOOLEAN;
VAR
    Block : ACellBlockNumber;
    PageNumber : CARDINAL;
    i     : ACellNo;
BEGIN
        (* Search the CellTables to find a free cell. *)

    FOR Block := TopCellBlock TO 0C BY -1 DO
        FOR i := 0C TO MaxCellPerBlock DO
            IF (CellBlockTable[Block]^[i].PageNo = 0) THEN
                BlockNumber := Block;
                CellNo      := i;
                RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE;

END FindEmptyCell;
(*DOS>*)




(*<DOS*)
PROCEDURE DiscardEmptyCellBlocks();
VAR
    Block : ACellBlockNumber;
    PageNumber : CARDINAL;
    i     : ACellNo;
BEGIN
        (* Search the CellTables to find a free cell. *)

    FOR Block := TopCellBlock TO 1C BY -1 DO    (* Never deallaocate table 0 *)
            (* Search the block to see if it has any occupied cells. *)
        i := 0C;
        WHILE (i < MaxCellPerBlock) AND (CellBlockTable[Block]^[i].PageNo = 0) DO   (* 17-Nov-89 RSC *)
            INC(i);
        END;
            (* If all cells are empty, discard the block and condense the 
               CellBlockTable. *)
        IF (CellBlockTable[Block]^[i].PageNo = 0) THEN  (* 17-Nov-89 RSC *)
            DISPOSE(CellBlockTable[Block]);
            CellBlockTable[Block] := CellBlockTable[TopCellBlock];
            DEC(TopCellBlock);
        END;
    END;

END DiscardEmptyCellBlocks;
(*DOS>*)
 
 
 


    (* CreateExtObjectWithSize --

       Preconditions  -- InitExtStorage must have been called.

       Postconditions -- A valid handle will be created.  It will refer
                         to a block of storage MinSize bytes long.
                         The indicated tag will be associated with the
                         Handle.
                         Or else, FALSE will be returned.

    *)


PROCEDURE XCreateExtObjectWithSize
                         ( VAR Handle : AnExtHandle;
                               Storage: AnExtStoragePreference;
                               Size   : CARDINAL
                          ):BOOLEAN;
(*<OS2
CONST
    Fudge   = 32;  (* Any overhead for the storage manager. *)
OS2>*)
VAR
(*<DOS*)
    BlockNumber  : ACellBlockNumber;
    i            : ACellNo;
    PageNumber   : APageNo;
    CellPointer  : ACellPointer;
    RecordNumber : ARecordNo;
(*DOS>*)
BEGIN
    Handle := NIL;

(*<DOS*)
        (*<TRACE
    TraceSize("CreateExtWithSize",Size);
    TraceOff();
        TRACE>*)

    IF (NOT FindEmptyCell(BlockNumber,i)) THEN
        IF (TopCellBlock < 377C) THEN   (* Was 255C.  RSC 13-Nov-89 *)
            INC(TopCellBlock);
            IF (NOT CreateCellBlock(TopCellBlock)) THEN
                DEC(TopCellBlock);
                StorageError(17);
                Handle := AnExtHandle(NIL);
                RETURN FALSE;
            END;
            BlockNumber := TopCellBlock;
            i           := 0C;
        END;
    END;

    IF (AddRecordToSomePage(Size,Storage,PageNumber,RecordNumber)) THEN
        CellPointer := ADR(CellBlockTable[BlockNumber]^[i]);
        WITH CellPointer^ DO
            PageNo    := PageNumber;
            RecordNo  := CHR(RecordNumber);

                (* Generations are incremented on discard *)
            EncodeHandle(CellPointer,Generation,Handle);
        END;

        INC(Quantity);

            (*<TRACE
        CheckSumTheCellTable;
        TraceOn();
            TRACE>*)

        RETURN TRUE;
    END;

        (*<TRACE
    TraceOn();
    Trace("CreateExtObject FAILED");
        TRACE>*)

(*DOS>*)

(*<OS2
    IF (Available( Size+TSIZE(AnExtHandle)+Fudge )) THEN
        NEW( Handle );
        IF (Size <> 0) THEN
            ALLOCATE( Handle^.UserData, Size );
        ELSE
            Handle^.UserData := NIL;
        END;
        Handle^.Size := Size;
        RETURN TRUE;
    END;
OS2>*)

    RETURN FALSE;

END XCreateExtObjectWithSize;








    (* CreateExtObject --

       Preconditions  -- InitExtStorage must have been called.

       Postconditions -- A valid handle will be created.  It will refer
                         to a block of storage of undefined size.
                         The indicated tag will be associated with the
                         Handle.
                         Or else, FALSE will be returned.

    *)


PROCEDURE CreateExtObject( VAR Handle : AnExtHandle;
                               Storage: AnExtStoragePreference
                          ):BOOLEAN;
CONST
    StartingSize = 0;
BEGIN
        (*<TRACE
    Trace("CreateExtObject");
    TraceOff();
        TRACE>*)

    IF CreateExtObjectWithSize(Handle,Storage,StartingSize) THEN
            (*<TRACE
        TraceOn();
        TraceHandle("CreateExtObject",Handle);
            TRACE>*)
        RETURN TRUE;
    ELSE
            (*<TRACE
        TraceOn();
        Trace("CreateExtObject FAILED");
            TRACE>*)
        RETURN FALSE;
    END;

END CreateExtObject;








    (* SetExtSize - Ajust the size of the extended object if
                    need be.

       Preconditions  -- Handle is valid.

       Postconditions -- Record is of the exact size.
                         Else FALSE.
                         Note that this procedure may move the
                         record from one page to another, or
                         change the record number.
     *)

PROCEDURE SetExtSize(     Handle   : AnExtHandle;
                          NewSize  : CARDINAL
                    ) : BOOLEAN;
VAR
(*<DOS*)
    CurrentSize       : CARDINAL;
    ShiftLength       : CARDINAL;
    Difference        : CARDINAL;
    i                 : CARDINAL;
    Page              : APagePointer;
    NewHandle         : AnExtHandle;
    CellPointer, NewCellPointer : ACellPointer;
    Gen, NewGen       : AGeneration;
    StorageClass      : AnExtStoragePreference;
    PageNo            : APageNo;
    RecNo             : ARecordNo;
    CannotChangeSize  : BOOLEAN;
(*DOS>*)
(*<OS2
    TempPtr           : ADDRESS;
    CopySize          : CARDINAL;
OS2>*)

BEGIN
(*<DOS*)
        (*<TRACE
    TraceHandleAndSize("SetExtSize",Handle,NewSize);
    TraceOff();
        TRACE>*)

        (*<TRACE
    IF ODD(NewSize) THEN
        TraceHandleAndSize("Odd-sized ",Handle,NewSize);
    END;
        TRACE>*)

        (* Get the page and record number. *)
    IF (NOT CheckAndDecodeHandle(Handle,Page,RecNo)) THEN
        RETURN FALSE;
    END;

        (* Determine if we can move other records around, or
           whether we must keep other records in this page in
           place.  The test to allow the last record to always
           change size is important to prevent this routine
           from going into infinite recursion. *)

    CannotChangeSize := (Page^.Header.LockCount > 0)
                        AND
                        (RecNo+1 < Page^.Header.LastEntry);

    CurrentSize := SizeOfRecord(Page^,RecNo);

    ShiftLength := Page^.StartAt[Page^.Header.LastEntry]
                   - Page^.StartAt[RecNo+1];

        (* Move the other records in the array. *)

    IF (NewSize = CurrentSize) THEN
       (* Nothing *)

    ELSIF (NewSize > CurrentSize)     (* Bigger *)
       OR (CannotChangeSize) THEN

        IF (NewSize > MaxDataBytesPerPage ) THEN
            RETURN FALSE;
        END;

        IF (NOT CannotChangeSize) THEN               (* Avoid cardinal overflow. *)
            Difference := NewSize - CurrentSize;
        END; 

        IF (CannotChangeSize) OR
           (SizeOfRecord(Page^,Page^.Header.LastEntry) < Difference) THEN

                (* Record won't fit on the current page, or the
                   current page is locked.  Force creation of a
                   new handle. *)

                (* Our logic, here, relies on the assumption that
                   CopyObject will put the new record onto a page that
                   has enough room so that the new record can become
                   a copy of the original record without having to itself
                   be moved.  In this way, we avoid recursion. *)

            INC(Page^.Header.LockCount);  (* Lock Page into memory. *)

            StorageClass := AnExtStoragePreference(
                                PageTable^[Page^.Header.PageNumber].StorageClass);

            IF (CopyObject(Handle,NewHandle,NewSize,StorageClass)) THEN
                    (* Change the table that maps handles to pages and
                       records so that the old handle points to the
                       new record.   The old handle takes over the
                       identity of the new handle, but keeps the correct
                       generation count. *)
                DecodeHandle(Handle,CellPointer,Gen);
                DecodeHandle(NewHandle,NewCellPointer,NewGen);
                CellPointer^ := NewCellPointer^;
                CellPointer^.Generation := Gen;
                    (* Discard the new handle's entry. *)
                NewCellPointer^.PageNo := 0;
                    (*<TRACE
                CheckSumTheCellTable();
                    TRACE>*)

                DEC(Page^.Header.LockCount);  (* Free Page. *)

                    (* Discard the old record. *)
                INC(PageTable^[ Page^.Header.PageNumber ].FreeBytes,
                    CurrentSize );
                RemoveRecordFromPage(Page^,RecNo);
            ELSE
                StorageError(9);
                    (*<TRACE
                TraceOn();
                    TRACE>*)
                RETURN FALSE;
            END;
        ELSE
                (* Record does fit on the page. *)
            IF SetRecordSize(Page^,RecNo,NewSize) THEN
                PageNo := Page^.Header.PageNumber;
                DEC( PageTable^[PageNo].FreeBytes, NewSize - CurrentSize );
            ELSE
                StorageError(10);
            END; 
        END;

    ELSIF ( NewSize < CurrentSize ) THEN

            (* Record fits easily on the page because it has become smaller. *)

            (* Record does fit on the page. *)
        IF SetRecordSize(Page^,RecNo,NewSize) THEN
            PageNo := Page^.Header.PageNumber;
            INC( PageTable^[PageNo].FreeBytes, CurrentSize-NewSize );
        ELSE
            StorageError(10);
        END; 
    END;


        (*<TRACE
    TraceOn();
        TRACE>*)
(*DOS>*)

(*<OS2
    WITH Handle^ DO
        IF (NewSize = Size) THEN
            RETURN TRUE;
        ELSE
            IF (Available(NewSize)) THEN
                IF (NewSize <> 0) THEN
                    ALLOCATE(TempPtr, NewSize);

                    IF (NewSize < Size) THEN
                        CopySize := NewSize;
                    ELSE
                        CopySize := Size;
                    END;

                    CopyBytes(UserData, TempPtr, CopySize);
                END;

                IF (Size <> 0) THEN
                    DEALLOCATE(UserData, Size);
                    Size := 0;
                END;

                IF (NewSize <> 0) THEN
                    UserData := TempPtr;
                    Size     := NewSize;
                END;

                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
        END;
    END;
OS2>*)

    RETURN TRUE;

END SetExtSize;








    (* SetExtData     --

       Preconditions  -- The handle must have been created by a 
                         sucessfull call to CreateExtObject, and not
                         discarded.
                      -- Size may be up to size specified when extended
                         storage was created.

       Postconditions --
                         Bytes of data will be copied from Data to
                         extended storage.
                         or else FALSE will be returned.
     *)

PROCEDURE SetExtData     (     Handle     : AnExtHandle;
                               Data       : ADDRESS;
                               Size       : CARDINAL ) : BOOLEAN;
VAR
(*<DOS*)
    Page       : APagePointer;
    RecNo      : ARecordNo;
(*DOS>*)

BEGIN
(*<DOS*)
        (*<TRACE
    TraceHandleAndSize("SetExtData",Handle,Size);
    TraceOff();
        TRACE>*)

        (*<TRACE
    IF ODD(Data.OFFSET) THEN
        TraceHandleAndSize("Odd-Address",Handle,Data.OFFSET);
    END;
        TRACE>*)

   IF (Handle <> NIL) AND
      (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN

       INC(Page^.Header.LockCount);

       IF HandleIsLocked(Handle) THEN
           StorageError(11); (* Handle is locked *)
       END;

       DEC(Page^.Header.LockCount);

       IF SetExtSize(Handle,Size) AND
               (* Since changing the record's size may have changed
                  its location as well, we must relocate it. *)
           (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN
               (* Now copy the data into the record. *)
           CopyBytes(Data,DataAddress(Page^,RecNo),Size);
           MarkPageDirty(Page^);
               (*<TRACE
           TraceOn();
               TRACE>*)
           RETURN TRUE;
       ELSE
           StorageError(10);
               (*<TRACE
           TraceOn();
               TRACE>*)
           RETURN FALSE;
       END;
   ELSE
       StorageError(12);
   END;
(*DOS>*)


(*<OS2
    IF SetExtSize(Handle,Size) THEN
        WITH Handle^ DO
            CopyBytes( Data, UserData, Size );
        END;
        RETURN TRUE;
    END;

    RETURN FALSE;
OS2>*)

END SetExtData;








    (* SaveHeapCopy -

       Preconditions  -- An address of a heap object (Data) pointing to
                         RecordCount records of RecordSize bytes.       

       Postconditions -- Space will be deallocated off the heap after
                         data is copied from there.  The address is set
                         to NIL.
    *)

PROCEDURE SaveHeapCopy(     Handle      : AnExtHandle;
                        VAR Data        : ADDRESS;
                            Size        : CARDINAL ) : BOOLEAN;
BEGIN
        (*<TRACE
    TraceHandleAndSize("SaveHeapCopy",Handle,Size);
        TRACE>*)


        (* Note that SetExtData routine checks for locked items and valid handles *)

    IF SetExtData( Handle, Data, Size ) THEN
        IF (Size > 0) AND (Data <> NIL) THEN
            DEALLOCATE( Data, Size );
        END;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END SaveHeapCopy;











    (* GetExtData     --

       Preconditions  -- The handle must have been created by a
                         sucessfull call to CreateExtObject, and
                         not discarded.
                         Data is a valid address where you want the data put.
                         RecordSize is the size of ONE record, from TSIZE/SIZE.

       Postconditions -- Data will be filled in for the size that was last
                         Put into storage.  
                         The RETURN value of the function is the number of
                         RECORDS of RecordSize were returned.
    *)


PROCEDURE GetExtData     (     Handle     : AnExtHandle;
                               Data       : ADDRESS  ) : CARDINAL;
VAR
(*<DOS*)
    Page           : APagePointer;
    StoredSize     : CARDINAL;
    RecNo          : ARecordNo;
(*DOS>*)

BEGIN
(*<DOS*)
        (*<TRACE
    TraceHandle("GetExtData",Handle);
        TRACE>*)

        (*<TRACE
    IF ODD(Data.OFFSET) THEN
        TraceHandleAndSize("Odd-Address",Handle,Data.OFFSET);
    END;
        TRACE>*)

   IF Handle = NIL THEN
       RETURN 0;
   END;


   IF CheckAndDecodeHandle(Handle,Page,RecNo)   THEN
       StoredSize := SizeOfRecord(Page^,RecNo);
       CopyBytes(DataAddress(Page^,RecNo),Data,StoredSize);
   ELSE
       StorageError(0);
   END;
 
   RETURN StoredSize;
(*DOS>*)

(*<OS2
    WITH Handle^ DO
        CopyBytes( UserData, Data, Size );
    END;
    RETURN Handle^.Size;
OS2>*)

END GetExtData;





    (* MakeHeapCopy -

       Preconditions  -- Valid Handle, Data should not point to any current
                         storage, for it will be changed.

       Postconditions -- Space will be allocated on the heap and the
                         data copied there.  The address and # of bytes
                         are returned (in Size); or else FALSE.
    *)

PROCEDURE MakeHeapCopy(     Handle      : AnExtHandle;
                        VAR Data        : ADDRESS;
                        VAR Size        : CARDINAL ) : BOOLEAN;
BEGIN
        (*<TRACE
    TraceHandleAndSize("MakeHeapCopy",Handle,Size);
        TRACE>*)

    Data        := NIL;
    Size        := 0;           (* 29-Aug-90 CL  *)
    IF Handle = NIL THEN
        RETURN TRUE;
    END;
    IF HandleIsValid( Handle ) THEN
        Size := GetExtSize(Handle);
        IF Size = 0 THEN
            RETURN TRUE;
        ELSIF Available( Size ) THEN
            ALLOCATE(Data,Size);
            Size := GetExtData( Handle, Data );
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END;
    ELSE
        StorageError(0);
    END;
END MakeHeapCopy;








    (* DiscardExtObject --

       Preconditions  --  The handle must have been
                          created by a sucessfull call to
                          CreateExtObject, and not discarded.

       Postconditions --  The handle is discarded, and no longer
                          valid.

    *)


PROCEDURE XDiscardExtObject( VAR Handle : AnExtHandle   );
VAR
(*<DOS*)
    CellPointer: ACellPointer;
    Gen        : AGeneration;
    PageNum    : APageNo;
    Page       : APagePointer;
    RecNo      : ARecordNo;
(*DOS>*)

BEGIN
(*<DOS*)
        (*<TRACE
    TraceHandle("DiscardExtObject",Handle);
        TRACE>*)


    IF (Handle = NIL) THEN
        RETURN;
    END;

    IF (NOT HandleIsValid(Handle)) THEN
        StorageError(0);
    END;

    DecodeHandle(Handle,CellPointer,Gen);

    WITH CellPointer^ DO
        IF (Gen <> Generation) THEN
            StorageError(0);
        END;
        PageNum := ORD(PageNo);
        RecNo   := ORD(RecordNo);
    END;

    WITH PageTable^[PageNum] DO
        IF (Location = NIL) AND
           (NOT RetrievePage(StorageClass,PageNum)) THEN
            StorageError(7);
            RETURN;
        END;
    END;
    Page   := PageTable^[PageNum].Location;

    IF HandleIsLocked(Handle) THEN
        StorageError(13); (* Handle is locked *)
    END;

        (* Note that the space is now available. *)

    INC(PageTable^[ Page^.Header.PageNumber ].FreeBytes,
                   SizeOfRecord( Page^, RecNo ) );

        (* Remove the record out of the page. *)

    RemoveRecordFromPage(Page^,RecNo);

        (* Do we still need this page? *)

    IF (Page^.Header.LastEntry = 0) THEN       (* No records in it. *)
        WITH PageTable^[PageNum] DO
            Valid := NOT DiscardPage(StorageClass,HomeAddress);
        END;
    END;

        (* Invalidate the handle. *)

    Handle := NIL;

    WITH CellPointer^ DO
        (* Mark the cell as free to be given out as a new handle. *)

        PageNo := 0;

        (* Strongly invalidate any old copies of the handle.   By
           changing the generation number, any old copies of the
           former handle will have the old generation number.  Even
           though they would refer to this cell, they would be detected
           as having an invalid generation.
           *)

        Generation :=
           CHR( (ORD(Generation) + 1) MOD (MaxGeneration+1) );
    END;

        (* If the containing cell block is empty, dispose it. *)

    DiscardEmptyCellBlocks();

        (*<TRACE
    CheckSumTheCellTable();
        TRACE>*)

        (* Decrease the count of the number of records currently
           under our management. *)

    DEC(Quantity);
(*DOS>*)


(*<OS2
    WITH Handle^ DO
        IF (Size <> 0) THEN
            DEALLOCATE( UserData, Size );
        END;
    END;
    DISPOSE( Handle );
OS2>*)

END XDiscardExtObject;










    (* GetExtSize     --

       Preconditions  -- The handle must have been created by a
                         sucessfull call to CreateExtObject, and
                         not discarded.

       Postconditions -- Size (from the previous CreateExtObject call)
                         will be returned.
    *)


PROCEDURE GetExtSize     (     Handle : AnExtHandle ) : CARDINAL;
VAR
(*<DOS*)
    Page     : APagePointer;
    Size     : CARDINAL;
    RecNo    : ARecordNo;
(*DOS>*)
BEGIN
(*<DOS*)
        (*<TRACE
    Trace("GetExtSize");
        TRACE>*)


    IF (Handle <> NIL) AND (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN
        Size := SizeOfRecord(Page^,RecNo);
        RETURN Size;
    ELSE
        RETURN 0;
    END;
(*DOS>*)


(*<OS2
    RETURN Handle^.Size;
OS2>*)

END GetExtSize;




    (* HandleIsValid  -- Check whether this handle is a valid
                         handle or not.

       Preconditions  -- InitExtStorage must have returned TRUE.

       Postconditions -- If the handle was created by a successful
                         call to CreateExtObject and has not been
                         discarded, then TRUE is returned; else
                         FALSE.
    *)


PROCEDURE HandleIsValid  (     Handle : AnExtHandle ) : BOOLEAN;
VAR
(*<DOS*)
    Page     : APagePointer;
    RecNo    : ARecordNo;
    ok       : BOOLEAN;
(*DOS>*)
BEGIN
    IF (Handle = NIL) THEN
        RETURN FALSE;
    ELSE
(*<DOS*)
        ok := CheckAndDecodeHandle(Handle,Page,RecNo);
        IF (ok) THEN
                (*<TRACE
            TestCheckSums(Page^);
                TRACE>*)
        END;
        RETURN ok;
(*DOS>*)
(*<OS2
        RETURN TRUE;
OS2>*)
    END;
END HandleIsValid;




    (* Refresh --

       Preconditions  -- InitExtStorage must have returned TRUE.

       Postconditions -- Any storage on secondary media will match
                         any buffered copies of the data.

    *)

PROCEDURE Refresh();
(*<DOS*)
VAR
    Class : APageClass;
(*DOS>*)
BEGIN
(*<DOS*)
        (*<TRACE
    Trace("Refresh");
        TRACE>*)


    FOR Class := PageFast TO PageSlow DO
        IF (ClassPageSize[Class] > 0) AND (NOT SynchPage(Class)) THEN
            StorageError(14);
        END;
    END;
(*DOS>*)
END Refresh;





    (*$R-*) (*$S-*) (*$T-*)


PROCEDURE HandleIsLocked( Handle : AnExtHandle ) : BOOLEAN;
VAR
(*<DOS*)
    Page     : APagePointer;
    RecNo    : ARecordNo;
    Lock     : BOOLEAN;
(*DOS>*)
BEGIN
(*<DOS*)
    IF (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN
       Lock := (RecNo MOD BPBS) IN ( Page^.LockSet[ RecNo DIV BPBS ] );
       RETURN Lock;
    END;
(*DOS>*)
    RETURN FALSE;
END HandleIsLocked;





    (*$R=*) (*$S=*) (*$T=*)






    (* CopyObject --

       Preconditions  -- InitExtStorage must have been called.
                         OriginalHandle is not NIL.

       Postconditions -- A valid handle will be created.  It will refer
                         to a new extended storage block that is a
                         bitwise copy of the original's data block.
                         Storage is duplicated.
                         Or else, FALSE will be returned.

    *)

PROCEDURE CopyObject     (     OriginalHandle : AnExtHandle;
                           VAR NewHandle      : AnExtHandle;
                               NewSize        : CARDINAL;
                               NewStorage     : AnExtStoragePreference
                          ):BOOLEAN;
VAR
(*<DOS*)
    CellNo     : ACellNo;
    Gen        : CARDINAL;
    PageNum    : APageNo;
    Page       : APagePointer;
    V          : BOOLEAN;
    RecNo      : ARecordNo;
(*DOS>*)

BEGIN
(*<DOS*)
    IF (NOT CheckAndDecodeHandle(OriginalHandle,Page,RecNo)) THEN
        StorageError(0);
    END;

    PageNum := Page^.Header.PageNumber;

    V := FALSE;

    INC(Page^.Header.LockCount);            (* Lock the page. *)

    IF ( CreateExtObjectWithSize
                        ( NewHandle,
                          NewStorage,
                          NewSize
                         )) THEN

            (* There is a risk, here, that the NewSize is bigger than
               the old size, sufficiently so that the copy could wrap
               over a page boundary.  We don't really care that some
               trash gets copied.  However, some processors (e.g. 80386)
               may trap us if we try to read past the end of a page. *)

        V := SetExtData(NewHandle,
                        DataAddress(Page^,RecNo),
                        NewSize);

    END;

    DEC(Page^.Header.LockCount);            (* Release our lock. *)

        (*<TRACE
    CheckSumAPage(Page^);
        TRACE>*)

    RETURN V;
(*DOS>*)

(*<OS2
    RETURN (CreateExtObjectWithSize( NewHandle, NewStorage, NewSize ) AND
            SetExtData( NewHandle, OriginalHandle^.UserData, NewSize ));
OS2>*)

END CopyObject;








    (* CopyExtObject --

       Preconditions  -- InitExtStorage must have been called.

       Postconditions -- A valid handle will be created.  It will refer
                         to a new extended storage block that is a
                         bitwise copy of the original's data block.
                         Or else, FALSE will be returned.

    *)

PROCEDURE CopyExtObject  (     OriginalHandle : AnExtHandle;
                               NewStorage     : AnExtStoragePreference;
                           VAR NewHandle      : AnExtHandle
                          ):BOOLEAN;
VAR
    OldHandle  : AnExtHandle;
(*<DOS*)
    CellNo     : ACellNo;
    Gen        : CARDINAL;
    PageNum    : APageNo;
    Page       : APagePointer;
    V          : BOOLEAN;
    RecNo      : ARecordNo;
(*DOS>*)

BEGIN
    OldHandle := OriginalHandle;   (* In case NewHandle == OriginalHandle. *)
(*<DOS*)
        (*<TRACE
    TraceHandle("CopyExtObject",OldHandle);
    TraceOff();
        TRACE>*)


    NewHandle := NIL;
    IF OldHandle = NIL THEN
            (*<TRACE
       TraceOn();
            TRACE>*)
       RETURN TRUE;
    END;

    IF (NOT CheckAndDecodeHandle(OldHandle,Page,RecNo)) THEN
        StorageError(0);
    END;

    IF (CopyObject(OldHandle,NewHandle,
                       SizeOfRecord(Page^,RecNo),NewStorage)) THEN
        INC(Quantity);
            (*<TRACE
        TraceOn();
        TraceHandle("  Copied to",NewHandle);
            TRACE>*)

        RETURN TRUE;
    END;

        (*<TRACE
   TraceOn();
        TRACE>*)

    RETURN FALSE;
(*DOS>*)

(*<OS2
    RETURN (CreateExtObjectWithSize( NewHandle, NewStorage, OldHandle^.Size ) AND
            SetExtData( NewHandle, OldHandle^.UserData, OldHandle^.Size ));
OS2>*)

END CopyExtObject;













    (* GetExtStoragePreference --

       Preconditions  -- The handle must have been created by a 
                         sucessfull call to CreateExtObject, and not
                         discarded.

       Postconditions --
                         The current storage preference is set.
     *)

PROCEDURE GetExtStoragePreference  (     Handle : AnExtHandle )
                                     : AnExtStoragePreference;
VAR
(*<DOS*)
    Cell       : ACellPointer; 
    Gen        : AGeneration;
(*DOS>*)
BEGIN
(*<DOS*)
        (*<TRACE
    TraceHandle("GetExtStoragePreference",Handle);
        TRACE>*)

    DecodeHandle(Handle,Cell,Gen);

    RETURN AnExtStoragePreference( PageTable^[ ORD(Cell^.PageNo) ].StorageClass ); 
(*DOS>*)

(*<OS2
    RETURN ExtFast;
OS2>*)

END GetExtStoragePreference;



PROCEDURE SetExtStoragePreference  (     Handle  : AnExtHandle;
                                         Storage : AnExtStoragePreference );
BEGIN
        (*<TRACE
    Trace("SetExtStoragePreference");
        TRACE>*)


    NotYetImplemented("FlexStor.SetExtStoragePreference");
END SetExtStoragePreference;








    (*$R-*) (*$S-*) (*$T-*)

    (* LockObject - Lock an object into memory and return a pointer to it.

       Preconditions  -- InitExtStorage must have returned TRUE.
                         Handle must be valid.
                         Data is returned, so should not point to anything.
                         RecordSize is the size of one record from SIZE/TSIZE.

       Postconditions -- The object is brought into DOS memory and is
                         LOCKED down.  Its address is returned.
                         If too many objects become locked, FatalError is
                         called.
                         RETURNed value is the Size.

         Locked objects MUST be released via ReleaseObject.  No other
         data-movement calls may be made to Locked objects, and their
         size cannot be changed.  You can, however, make changes in place
         to the locked object, and access other objects that are not locked.
    *)

PROCEDURE XLockObject(     Handle      : AnExtHandle;
                       VAR Data        : ADDRESS ) : CARDINAL;
VAR
(*<DOS*)
    Page      : APagePointer;
    Size      : CARDINAL;
    i         : CARDINAL;
    RM, RD    : CARDINAL;
    RecNo     : ARecordNo;
(*DOS>*)

BEGIN


   IF Handle = NIL THEN
            (*<TRACE
        TraceHandle("LockObject    NIL",Handle);
            TRACE>*)
       Data := NIL;
       RETURN 0; (* Locked her down, yesserry bob indeedy!  *)
   END;

(*<DOS*)
   (*<STATISTICS
   INC(OutstandingLocks);
   IF (OutstandingLocks > MostOutstandingLocks) THEN
       MostOutstandingLocks := OutstandingLocks;
   END;
     STATISTICS>*)



    IF (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN
        RD := RecNo DIV BPBS;
        RM := RecNo MOD BPBS;

        IF ( (RM) IN (Page^.LockSet[ RD ]) )  THEN
            IF ( (RM) IN (Page^.DoubleLockSet[ RD ]) )  THEN
                (*<DEBUG*) HALT; (*DEBUG>*)
                StorageError(16);   (* Handle locked twice already. *)
                RETURN 0;
            ELSE
                INCL( Page^.DoubleLockSet[ RD ], RM );
            END;
        ELSE
            INCL( Page^.LockSet[ RD ], RM );
        END;

        INC(Page^.Header.LockCount);


        (*
        Data := DataAddress(Page^,RecNo);
        Size := SizeOfRecord(Page^,RecNo);
        *)
        i    :=  Page^.StartAt[RecNo];
        Data :=  ADR(Page^.Data[ i ] );
        Size :=  Page^.StartAt[RecNo+1] - i;
        
            (*<TRACE
         TraceHandleAndSize("LockObject",Handle,Size);
             TRACE>*)

    ELSE
        StorageError(0); 
        Size := 0;
    END;

    RETURN Size;
(*DOS>*)

(*<OS2
    WITH Handle^ DO
        Data := UserData;
        RETURN Size;
    END;
OS2>*)

END XLockObject;

    (*$R=*) (*$S=*) (*$T=*)







    (*$R-*) (*$S-*) (*$T-*)

PROCEDURE LockObjectArray(     Handle      : AnExtHandle;
                           VAR Data        : ADDRESS;
                               ElementSize : CARDINAL ) : CARDINAL;
BEGIN
    RETURN NumberOfElements( LockObject(Handle,Data), ElementSize);
END LockObjectArray;

    (*$R=*) (*$S=*) (*$T=*)







    (*$R-*) (*$S-*) (*$T-*)


    (* ReleaseObject - Release previously locked object.

       Preconditions  -- The object must have been locked.
                         (If not, StorageError is called).

       Postconditions -- The object is unlocked.

    *)




PROCEDURE XReleaseObject(    Handle : AnExtHandle );
(*<DOS*)
VAR
    RM, RD   : CARDINAL;
    Page      : APagePointer;
    RecNo     : ARecordNo;
(*DOS>*)
BEGIN                       (* XReleaseObject *)
(*<DOS*)

        (*<TRACE
    TraceHandle("ReleaseObject",Handle);
        TRACE>*)


    IF (Handle = NIL) THEN
        RETURN;
    END;

    (*<STATISTICS
    DEC(OutstandingLocks);
    STATISTICS>*)

    IF (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN

        RD := RecNo DIV BPBS;
        RM := RecNo MOD BPBS;

        IF ( (RM) IN (Page^.DoubleLockSet[ RD ]) )  THEN
            EXCL( Page^.DoubleLockSet[ RD ], RM );
        ELSIF ( (RM) IN (Page^.LockSet[ RD ]) ) THEN
            EXCL( Page^.LockSet[ RD ], RM );
        ELSE
            RETURN;
        END;

            (* MarkPageDirty(Page^); *)
        Page^.Header.Dirty := TRUE;

        DEC(Page^.Header.LockCount);
           (*<TRACE
        CheckSumAPage(Page^);
           TRACE>*)
    END;
(*DOS>*)

END XReleaseObject;


    (*$R=*) (*$S=*) (*$T=*)




    (*$R-*) (*$S-*) (*$T-*)


    (* ReleaseUnchangedObject - Release previously locked object.

       Preconditions  -- The object must have been locked.
                         (If not, StorageError is called).

       Postconditions -- The object is unlocked, and not marked as dirty.

    *)




PROCEDURE XReleaseUnchangedObject(    Handle : AnExtHandle );

(*<DOS*)
VAR
    RM, RD   : CARDINAL;
    Page     : APagePointer;
    RecNo    : ARecordNo;
(*DOS>*)
BEGIN                       (* XReleaseUnchangedObject *)
(*<DOS*)

        (*<TRACE
    TraceHandle("ReleaseUnchangedObject",Handle);
        TRACE>*)

    IF (Handle = NIL) THEN
        RETURN;
    END;

    (*<STATISTICS
    DEC(OutstandingLocks);
    STATISTICS>*)

    IF (CheckAndDecodeHandle(Handle,Page,RecNo)) THEN

        RD := RecNo DIV BPBS;
        RM := RecNo MOD BPBS;

        IF ( (RM) IN (Page^.DoubleLockSet[ RD ]) )  THEN
            EXCL( Page^.DoubleLockSet[ RD ], RM );
        ELSIF ( (RM) IN (Page^.LockSet[ RD ]) ) THEN
            EXCL( Page^.LockSet[ RD ], RM );
        ELSE
            RETURN;
        END;

        DEC(Page^.Header.LockCount);

           (*<TRACE
        CheckSumAPage(Page^);
           TRACE>*)
    END;
(*DOS>*)


END XReleaseUnchangedObject;


    (*$R=*) (*$S=*) (*$T=*)









        (* ArraySize -- Returns the true size taken up by an array of records.
                    This accounts for odd length records.

       Preconditions  -- # of records in the array, size of one record
                         (From TSIZE/SIZE).

       Postconditions -- Returns # of bytes in the full array.  
    *)


PROCEDURE ObjectsAreSame( HandleA, HandleB : AnExtHandle ) : BOOLEAN;
BEGIN
        (*<TRACE
    TraceHandle("ObjectsAreSame",HandleA);
        TRACE>*)


    RETURN (HandleA = HandleB);
END ObjectsAreSame;





    (* TerminateExtStorage --

       Preconditions:
           InitExtStorage returned TRUE.
           TerminateExtStorage has not been called.

       Postconditions:
           Storage held by this module is released.

    *)

PROCEDURE TerminateExtStorage();
(*<DOS*)
VAR
    i : CARDINAL;
    Block : ACellBlockNumber;
    Class : APageClass;
(*DOS>*)
BEGIN
(*<DOS*)
        (*<TRACE
    Trace("TerminateExtStorage");
        TRACE>*)


    (*
        (* Copy extended data to secondary media. *)
        (* Why bother? *)

    Refresh();

    FOR i := 1 TO MaxPages DO
        WITH PageTable^[i] DO
            IF (Valid) THEN
                Valid := NOT DiscardPage(StorageClass,HomeAddress);
            END;
        END;
    END;
    *)

    FOR Class := PageFast TO PageSlow DO
        IF (ClassPageSize[Class] > 0) THEN
            ShutdownPageClass(Class);
        END;
    END;

    FOR Block := 0C TO TopCellBlock DO
        DISPOSE(CellBlockTable[Block]);
    END;
(*DOS>*)
END TerminateExtStorage;




(*<DOS*)

PROCEDURE EnoughFree() : BOOLEAN;
BEGIN                       (* EnoughFree *)
    RETURN FALSE;  (* We can NEVER get enough memory! *)
END EnoughFree;


PROCEDURE CreateCellBlock( i : ACellBlockNumber ) : BOOLEAN;
VAR
    CellNo : ACellNo;
BEGIN

        (* In order to reduce fragmentation, always free up as
           much temporary memory as possible before allocating a
           new cell block, since they cannot be moved, and we
           would like them loaded as low as possible. *)

    SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));


    IF (Available(TSIZE(ACellBlock))) THEN
        NEW(CellBlockTable[i]);
        FOR CellNo := 0C TO MaxCellPerBlock DO
            WITH CellBlockTable[i]^[CellNo] DO
                PageNo     := 0;       (* Not a page *)
                Generation := 10C;     (* start *)
            END;
        END;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END CreateCellBlock;

(*DOS>*)



(* RSC 21-Aug-89  Modified to return queazy if we are low on FlexStor.
*)
PROCEDURE GetExtStatus():AnExtStatus;
(*<DOS*)
CONST
    DesiredFreeKForReasonableness = 64;
VAR
    KFree,
    KNeededForReason,
    WorstCondition,
    Condition       : CARDINAL;
    Class           : APageClass;
    ClassStatus     : APageClassStatus;
(*DOS>*)
BEGIN
(*<DOS*)
    KNeededForReason := DesiredFreeKForReasonableness;

    IF (Interlock > 0) THEN
        WorstCondition := 2;     (* Reentrancy lockout. *)        (* 25-Sep-89 LAA *)
    ELSE
        WorstCondition := 0;
    END; 
    FOR Class := PageFast TO PageSlow DO
        IF (ClassPageSize[Class] > 0) THEN
            PageClassStatus(Class,ClassStatus);
            Condition := ClassStatus.Condition;
            IF (Condition > WorstCondition) THEN
                WorstCondition := Condition;
            END;
            IF (Class <> PageFast) THEN
                KFree := ClassStatus.FreePages * (ClassPageSize[Class] DIV 1024);
                IF (KNeededForReason > KFree) THEN
                    DEC( KNeededForReason, KFree );
                ELSE
                    KNeededForReason := 0;
                END;
            END;
        END;
    END;

    (* 21-Aug-89 RSC  If there is not enough free space to satisfy us,
                      then make us queazy.
    *)
    IF (WorstCondition = 0) AND
       (KNeededForReason > 0) THEN
        WorstCondition := 1;
    END;

    RETURN VAL(AnExtStatus,WorstCondition);
(*DOS>*)

(*<OS2
    RETURN ExtGood;
OS2>*)
END GetExtStatus;




PROCEDURE InitFlexStor();
VAR
    InitIndex          : CARDINAL;
(*<DOS*)
    Class              : APageClass;
(*DOS>*)
BEGIN
(*<DOS*)
   (*<STATISTICS
   OutstandingLocks := 0;
   MostOutstandingLocks := 0;
   STATISTICS>*)

       (* Our calculations of array sizes assume that the compiler
          pads array elements to start on an even offset boundary. *)
    IF (TSIZE(TwoOddSizedRecords) <> (TSIZE(AnOddSizedRecord)+1)*2 ) THEN
        StorageError(15);
    END;

    Quantity  := 0;
    Interlock := 0; 
(*DOS>*)
    FOR InitIndex := 1 TO MaxPages DO
        PageTable^[InitIndex].Valid := FALSE;
    END;

(*<DOS*)
    FOR InitIndex := 0 TO ORD(HIGH(CellBlockTable)) DO
        CellBlockTable[CHR(InitIndex)] := NIL;
    END;

    TopCellBlock := 0C;
    IF (NOT CreateCellBlock(0C)) THEN StorageError(15); END;

    FOR Class := PageFast TO PageSlow DO
        ClassPageSize[ Class ] := 0;
        LastPageAdded[ Class ] := 1;
        LotsOfRoom   [ Class ] := TRUE;
    END;
(*DOS>*)
        (*<TRACE
    CheckSumTheCellTable();
        TRACE>*)
END InitFlexStor;



BEGIN
(* 14-Nov-89 RSC *)
    CreateExtObjectWithSize := XCreateExtObjectWithSize;
    DiscardExtObject        := XDiscardExtObject;
    LockObject              := XLockObject;
    ReleaseObject           := XReleaseObject;
    ReleaseUnchangedObject  := XReleaseUnchangedObject;
    InitFlexStor();
END FlexStor.

