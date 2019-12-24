MODULE TLVidMem;

(*  =========================================================================
    Last Edit : March 21, 1991 5:29PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        DANGEROUS 4.00 and 4.01 VIDEO MEMORY USER.  DO NOT USE UNLESS
        YOU HAVE BEEN WARNED OF THE DANGERS!!


    MODIFICATION HISTORY:

        16-May-90 RSC     Found the 120K of video memory.
         1-Jun-90 RSC     Support 50 line mode.
        12-Nov-90 RSC     Import ReservedLayer
        20-Jul-90 RSC     Get the cursors to work, using the NEWPROCESS 
                          procedure.  We fire up a process that runs in 
                          the background to reset the cursor every 18th of
                          a second. 
        23-Sep-90 RSC     When TLVIDMEM decides not to stick around, the
                          overlay exits.  Unfortunately, by that time,
                          the timer interrupt process had been created. 
                          Apparently, when tearing down the overlay,
                          some memory gets trashed (it is not normal for
                          processes to be in overlays). 
        24-Sep-90 RSC     The address of the reserved layer slides around 
                          a little.  I tried to lock it down some.
        29-Jan-91 RSC     Removed import of reserved layer, and
                          use RcDynMem to manage the memory space.
        30-Jan-91 RSC     Use "ExitingToDOSNotification" from Exit2Dos
                          to make sure that we can use video memory for
                          any heap request (including notices).
        12-Feb-91 RSC     Resynched with 4.0.3.
        20-Mar-91 RSC     Added check for windows.  If windows is present,
                          exit, unless "WINDOWS IS OK" is on the command
                          line.
        21-Mar-91 RSC     Handle the XmsMem module's VideoAvailable proc.
        12-Sep-91 LAA     This has gotta be the kludge of all time, but here
                          goes ...  Certain versions of the Microsoft mouse
                          drivers (at least v. 7) write into VGA graphics
                          memory when they are hardware reset.  Since we think
                          we own that memory, this causes severe problems.
                          In particular, it was trashing a NoticeRecord on
                          Mark Hemsley's machine when terminating mouse usage
                          for exit to DOS.  The trashed area always starts at
                          A000:FF80 and runs for 48 bytes, so my solution is
                          to exclude the last 256 bytes of video memory from
                          our usage.  Thank you, Microsoft!
    =========================================================================
*)


FROM BTStorage      IMPORT
    (* TYPE *)          AStorageProc,
    (* PROC *)          ALLOCATE, DEALLOCATE;

FROM Directory      IMPORT
    (* TYPE *)          ASetOfFileNameParts, AFileNamePart,
    (* PROC *)          NormalizeFileName;

FROM DOSIO          IMPORT
    (* TYPE *)          AnAccessType, ADOSFileHandle,
    (* PROC *)          DOSOpen, DOSClose, DOSDelete, DOSRead, DOSWrite;

FROM Edges          IMPORT
    (* TYPE *)          AnEdge;

FROM Exit2Dos       IMPORT
    (* TYPE *)          AnExitingToDOSNotification,
    (* PROC *)          ExitingToDOSNotification;

FROM Kbio           IMPORT
    (* PROC *)          GetAnyCode;

FROM LStrings       IMPORT
    (* PROC *)          SetLengthOf, ConcatS, SetString;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Overlay        IMPORT
    (* TYPE *)          LayerId,
    (* PROC *)          DisposeLayer;

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
    (* PROC *)          InstallDynMem, Alloc, DeAlloc, Avail,
                        CountOfFree;

FROM RTSMain        IMPORT
    (* TYPE *)          RTDProc, OverlayPtr, Process, OverlayDescriptor,
    (* VAR *)           debuggerRecord, blockList, activProcess;

FROM SYSTEM         IMPORT
    (* CONST *)         AX, BX, CX, DX, ES, DI,
    (* TYPE *)          ADDRESS, BYTE, PROCESS,
    (* PROC *)          ADR, SIZE, TSIZE, GETREG, SETREG, OUTBYTE, NEWPROCESS,
                        ENABLE, DISABLE, INBYTE, CODE, SWI, IOTRANSFER,
                        TRANSFER;

FROM Video          IMPORT
    (* TYPE *)          AnAdapterType,
    (* PROC *)          QueryAdapterType,
                        GetCursorType, SetCursorType, SetCursorLocation,
                        TerminateVideoHardware;

FROM Windows        IMPORT
    (* TYPE *)          AWindowsType,
    (* PROC *)          WindowsIsRunning;

FROM XMSMem         IMPORT
    (* PROC *)          VideoAvailable;




VAR
    OverlayID               : AnOverlayID;

    OldALLOCATE,
    OldDEALLOCATE           : AStorageProc;
    OldGetCode              : PROCEDURE () : CARDINAL;

    OldExitingToDOSNotification : AnExitingToDOSNotification;

    Areas                   : ARRAY [1..3] OF RECORD
        Adr                 : ADDRESS;
        Size                : CARDINAL;
    END;

    NumberOfAreas           : CARDINAL;

    OldExitProc             : RTDProc;

    VideoPresent            : BOOLEAN;






PROCEDURE OurGetCode() : CARDINAL;
VAR 
    Code  : CARDINAL; 
BEGIN 

    StartVideoProcess();    (* Grab timer *)
    Code := OldGetCode(); 
    StopVideoProcess();     (* Release it *)

    RETURN Code;

END OurGetCode; 



PROCEDURE WasteTime();
BEGIN
    (* OUT instructions like to have the cache flushed and some
       CPU cycles wasted.  I dunno why.
    *)
END WasteTime;






(* Here we implement a simple disk swapper.

    - Swapfile is ".\VIDSWAP.TMP".
    - Written to in 1K chunks
    - Read from in 1K chunks
    - Clients have no control over record placement, except that
        the order written is the order read.
*)
MODULE Swapper;



IMPORT
    (* TYPE *)  AnAccessType, ADOSFileHandle, ADDRESS,
                ASetOfFileNameParts, AFileNamePart,
    (* PROC *)  DOSOpen, DOSClose, DOSDelete, DOSRead, DOSWrite,
                ConcatS, GetOption, SetLengthOf, GetMessage, ADR,
                NormalizeFileName, SetString;


EXPORT
    (* PROC *)  CreateSwapFile, SwapOut, SwapIn, ResetToReadSwapFile,
                DisposeOfSwapFile, SafestoreSwapFile;



CONST
    TLDOSModuleNumber = 22900;   (* For GetMessage *)

VAR
    SwapFile    : ADOSFileHandle;
    NextRecord  : CARDINAL;
    SwapOpen    : BOOLEAN;
    FileName    : ARRAY [0..127] OF CHAR;





PROCEDURE OpenSwapFile( AccessType : AnAccessType ) : BOOLEAN;
VAR
    s           : ARRAY [0..59]  OF CHAR;
    Found       : BOOLEAN;
BEGIN
    IF (AccessType = CreateFile) THEN
        GetMessage( TLDOSModuleNumber + 25, s ); (* MEMSWAP *)
        GetOption( s, Found, FileName );

        IF (NOT Found) THEN
            SetString(FileName, ".\");
        END;
        NormalizeFileName( FileName, ASetOfFileNameParts{DevicePart,DirectoryPart} );

        ConcatS( FileName,   "TLVIDSWP.TMP" );
    END;

    IF (SwapOpen) THEN
        DisposeOfSwapFile();
    END;

    NextRecord := 1;

    SwapOpen := DOSOpen( FileName, SwapFile, AccessType, 1024 );

    RETURN SwapOpen;

END OpenSwapFile;






PROCEDURE CreateSwapFile() : BOOLEAN;
BEGIN

    RETURN OpenSwapFile( CreateFile );

END CreateSwapFile;



PROCEDURE ResetToReadSwapFile() : BOOLEAN;
BEGIN

    RETURN OpenSwapFile( OpenFile );

END ResetToReadSwapFile;



TYPE
    ABuffer     = ARRAY [1..1024] OF CHAR;
    ABufferPtr  = POINTER TO ABuffer;



PROCEDURE SwapOut(  A           : ADDRESS;
                    SizeInKB    : CARDINAL ) : BOOLEAN;
VAR
    BufferPtr   : ABufferPtr;
    Buffer      : ABuffer;
    Size        : CARDINAL;
    ok,
    Full        : BOOLEAN;
BEGIN

    ok        := TRUE;
    Size      := 0;
    BufferPtr := A;

    WHILE (ok) AND
          (Size < SizeInKB) DO
        Buffer := BufferPtr^;
        ok := (SwapOpen AND
               DOSWrite( SwapFile, NextRecord, ADR(Buffer), Full ) AND
              (NOT Full));
        INC(NextRecord);
        INC(Size);
        INC(A.SEGMENT, (1024 DIV 16));
        BufferPtr := A;
    END;

    IF (NOT ok) THEN
        DisposeOfSwapFile();
    END;

    RETURN ok;

END SwapOut;



PROCEDURE SwapIn(  A           : ADDRESS;
                   SizeInKB    : CARDINAL ) : BOOLEAN;
VAR
    BufferPtr   : ABufferPtr;
    Buffer      : ABuffer;
    Size        : CARDINAL;
    ok,
    EOF         : BOOLEAN;
BEGIN
    ok        := TRUE;
    Size      := 0;
    BufferPtr := A;

    WHILE (ok) AND
          (Size < SizeInKB) DO
        ok := (SwapOpen AND
               DOSRead( SwapFile, NextRecord, ADR(Buffer), EOF ) AND
              (NOT EOF));
        BufferPtr^ := Buffer;
        INC(NextRecord);
        INC(Size);
        INC(A.SEGMENT, (1024 DIV 16));
        BufferPtr := A;
    END;

    IF (NOT ok) THEN
        DisposeOfSwapFile();
    END;

    RETURN ok;

END SwapIn;









PROCEDURE DisposeOfSwapFile();
VAR
    ok  : BOOLEAN;
BEGIN
    ok := (SwapOpen AND DOSDelete( SwapFile ));
    SwapOpen := FALSE;
END DisposeOfSwapFile;





PROCEDURE SafestoreSwapFile();
VAR
    ok  : BOOLEAN;
BEGIN
    ok := (SwapOpen AND DOSClose( SwapFile ));
    SwapOpen := FALSE;
END SafestoreSwapFile;



BEGIN
    SwapOpen := FALSE;
END Swapper;








MODULE VideoMemory;

(* There are two areas of video memory.  One is the area A000 to B7FF,
   which is 96K, the other is the area BA00 to BFFF, which is 24K.

   The 24K region we use as

        HMA if there is no real HMA, although we restrict it a bit more.
        Forms buffers (4K) if there is HMA.

   The 96K is used for overlays and maybe forms buffers.

   We do s VERY SIMPLISTIC test to see if the memory is already mapped
   with HIMEM by writing to the memory, reading it back, and comparing the 
   results to see if they are the same.  Not very trustworthy.

   These areas are not linked into Logitech blocks because the PMD dumper
   saves video memory anyway.
*)

IMPORT
    (* CONST *) AX, BX,

    (* TYPE *)  ADDRESS, AnAdapterType, ABlock, AWindowsType,

    (* VAR  *)  Areas, NumberOfAreas,
                OldExitingToDOSNotification,

    (* PROC *)  ADR, SETREG, GETREG, OUTBYTE, ENABLE, DISABLE,
                QueryAdapterType, CODE, SWI,

                GetOption, SetString, WindowsIsRunning,

                CreateSwapFile, SwapOut, SwapIn, ResetToReadSwapFile,
                DisposeOfSwapFile, SafestoreSwapFile,

                GetCursorType, SetCursorType, SetCursorLocation,

                StartVideoProcess, StopVideoProcess, WasteTime,
                
                InstallDynMem;

EXPORT
    (* VAR  *) VideoSegment,
    (* PROC *) IsVideoAvailable, ShutdownVideoMemory,
               XExitingToDOSNotification;





CONST
    VideoSizeInK     = 24;
    VideoSize        = (VideoSizeInK * 1024);
    VideoHMASegment  =  0BA00H;     (* B800 + 8KB *)



VAR
    DangerousVideoSize  : CARDINAL;
    VideoSegment        : CARDINAL;
    UseTheB000Segment   : BOOLEAN;
    SwappedOut          : BOOLEAN;










PROCEDURE XExitingToDOSNotification( Exiting : BOOLEAN ) : BOOLEAN;
VAR
    ok  : BOOLEAN;


    PROCEDURE SaveVideoRam() : BOOLEAN;
    VAR
        V    : ADDRESS;
        ok   : BOOLEAN;
    BEGIN

        ok := TRUE;
        V.OFFSET  := 0;
        V.SEGMENT := VideoHMASegment;
        ok := SwapOut( V, VideoSizeInK );

        IF (DangerousVideoSize > 0) THEN
            V.OFFSET  := 0;
            V.SEGMENT := 0A000H;
            ok        := (ok AND SwapOut( V, DangerousVideoSize ));
        END;

        SafestoreSwapFile();

        RETURN ok;

    END SaveVideoRam;


    PROCEDURE RestoreVideoRam() : BOOLEAN;
    VAR
        i    : CARDINAL;
        V    : ADDRESS;
    BEGIN

        ok := (ResetToReadSwapFile() AND
               SetupVideoMemory());

        V.OFFSET  := 0;
        V.SEGMENT := VideoHMASegment;
        ok := (ok AND SwapIn( V, VideoSizeInK ));

        IF (DangerousVideoSize > 0) THEN
            V.OFFSET  := 0;
            V.SEGMENT := 0A000H;
            ok        := (ok AND SwapIn( V, DangerousVideoSize ));
        END;

        DisposeOfSwapFile();

        RETURN ok;

    END RestoreVideoRam;


BEGIN

    IF (Exiting) THEN
        ok := (CreateSwapFile() AND
               SaveVideoRam());

        IF (ok) THEN
            ShutdownVideoMemory();
        END;

        SwappedOut := ok;

    ELSE
        IF (SwappedOut) THEN
            ok         := RestoreVideoRam();
            SwappedOut := FALSE;
        END;
        ok := TRUE; (* Ignore errors (gulp!) *)
    END;

    RETURN (ok AND OldExitingToDOSNotification(Exiting));

END XExitingToDOSNotification;





(*$O-*)
PROCEDURE TemporaryKlugeUseOfDangerousVideo( VAR KBInUse : CARDINAL );
VAR
    A                       : ADDRESS;
BEGIN
    (* Use 64K if we get A000 to B000, use additional space
       if we get A000 through B800, use it too.
       We always get 0BA00H for 24K, too.

       So, 64K for reserved layer           (A000 - AFFF)
           20K for simulated HMA            (B000 - B4FF)
           12K for FORMS buffers            (B500 - B7FF)
           <VIDEO BUFFER>                   (B800 - B9FF)
           24K for ADDITIONAL simulated HMA (BA00 - BFFF)

           We must swap all but B500 through B7FF.

        12-Sep-91 LAA  Reduce the size of the region beginning at A000, due
                       to a Microsoft mouse driver bug.  It writes to this
                       region when it's initialized!
    *)

    KBInUse := 64;
    WITH Areas[1] DO
        Adr.SEGMENT := 0A000H;
        Adr.OFFSET  := 0;
        Size        := 65534 - 256;                            (* 12-Sep-91 *)
        InstallDynMem( ABlock(Adr), Size );
    END;
    NumberOfAreas := 1;


    (* Setup the simulated HMA area in the high 24K
    *)
        (* No need for a memory header here, PMD
           snapshots all video memory!
        *)
    WITH Areas[2] DO
        Adr.SEGMENT := VideoHMASegment;
        Adr.OFFSET  := 0;
        Size        := VideoSize;
        InstallDynMem( ABlock(Adr), Size );
    END;
    NumberOfAreas := 2;


    IF (UseTheB000Segment) THEN

        INC(KBInUse, 32);

        WITH Areas[3] DO
            Adr.SEGMENT := 0B000H;
            Adr.OFFSET  := 0;
            Size        := 32766;
            InstallDynMem( ABlock(Adr), Size );
        END;
        NumberOfAreas := 3;
    END;


END TemporaryKlugeUseOfDangerousVideo;
(*$O=*)





PROCEDURE IsVideoAvailable() : BOOLEAN;
VAR
    AdapterType     : AnAdapterType;
    ok              : BOOLEAN;

    PROCEDURE ParmLineOverride() : BOOLEAN;
    VAR
        Override    : ARRAY [0..79] OF CHAR;
        Found       : BOOLEAN;
    BEGIN
        SetString( Override, "WINDOWS" );
        GetOption( Override, Found, Override );

        RETURN Found;

    END ParmLineOverride;

BEGIN
    SwappedOut := FALSE;

    AdapterType := QueryAdapterType();

    ok := (WindowsIsRunning() = WindowsNotRunning) OR   (* 20-Mar-91 RSC  *)
          (ParmLineOverride());

    ok := ok AND
          (((AdapterType = EGAColor)  OR
            (AdapterType = VGAColor)) AND
            SetupVideoMemory());

    IF (ok) THEN
        TemporaryKlugeUseOfDangerousVideo(DangerousVideoSize);
    END;

    RETURN ok;

END IsVideoAvailable;







TYPE
    ABunchOWords    = ARRAY [1..16384] OF CARDINAL;

VAR
    ScreenLocOffset   [0:044EH]     : CARDINAL;
    ScreenPageNumber  [0:0462H]     : CHAR;
    A000              [0A000H:0]    : ABunchOWords;
    B000              [0B000H:0]    : ABunchOWords;
    B800              [0B800H:0]    : ABunchOWords;





PROCEDURE SetupVideoMemory() : BOOLEAN;
VAR
    CursorShape       [0:0460H]     : CARDINAL;

    MemAddress                      : CARDINAL;
    Lo, Hi                          : CHAR;



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
        RETURN FALSE;
    END;

    UseTheB000Segment := (NOT MemMappedAlready(B000));
        

    ScreenLocOffset := ORD(ScreenPageNumber) * 01000H;

    MemAddress  := (ScreenLocOffset DIV 2) + 0C000H; (* Offset from A000 in WORDS *)

    Hi          := CHR(MemAddress DIV 256);
    Lo          := CHR(MemAddress MOD 256);



    (* Set memory available *)

    DISABLE;

    OUTBYTE(3CEH, 006H );   (* Select miscelanious register *)
    WasteTime();
    OUTBYTE(3CFH, 002H );   (* Select Even/Odd chaining, FULL ADDRESSING *)
    WasteTime();

    ENABLE;

    (* Copy data from A000 to B800 *)

    B800 := A000;

    (* Set starting address to use. *)

    DISABLE;

    OUTBYTE(3D4H, 0CH );   (* Start address high register selector *)
    WasteTime();
    OUTBYTE(3D5H, Hi  );   (* High of start address *)
    WasteTime();
    OUTBYTE(3D4H, 0DH );   (* Start address low  register selector *)
    WasteTime();
    OUTBYTE(3D5H, Lo  );   (* Low of start address *)
    WasteTime();

    OUTBYTE(3D4H, 0EH );   (* Start cursor address high register selector *)
    WasteTime();
    OUTBYTE(3D5H, Hi  );   (* High of start address *)
    WasteTime();
    ENABLE;

    CursorShape := 0607H;  (* Tell the BIOS about the shape. *)

    IF (NOT MemMappedAlready(A000)) THEN
        ShutdownVideoMemory();
        RETURN FALSE;
    END;

    RETURN TRUE;

END SetupVideoMemory;







PROCEDURE ShutdownVideoMemory();
VAR
    CurrentCursorType               : CARDINAL;
BEGIN

    StopVideoProcess();
    GetCursorType(CurrentCursorType);

    (* Copy data from B800 to A000 *)

    A000 := B800;

    ScreenPageNumber := 0C;
    ScreenLocOffset  := 0;

    (* Set memory available *)

    DISABLE;

    OUTBYTE(3CEH, 006H );   (* Select miscelanious register *)
    OUTBYTE(3CFH, 00EH );   (* Select Even/Odd chaining, PARTIAL ADDRESSING *)

    (* Set starting address to use. *)

    OUTBYTE(3D4H, 0CH );   (* Start address high register selector *)
    OUTBYTE(3D5H,  0  );   (* High of start address *)
    OUTBYTE(3D4H, 0DH );   (* Start address low  register selector *)
    OUTBYTE(3D5H,  0  );   (* Low of start address *)

    ENABLE;

    SetCursorType(CurrentCursorType);
    SetCursorLocation(0,0);

END ShutdownVideoMemory;




BEGIN

    DangerousVideoSize  := 0;
    UseTheB000Segment   := FALSE;

END VideoMemory;





MODULE ManageVideoProcess;

IMPORT
    (* TYPE *)  ADDRESS, BYTE, PROCESS,
    (* VAR  *)  activProcess,
    (* PROC *)  ADR, SIZE, TRANSFER, NEWPROCESS, IOTRANSFER, SWI,
                TerminateVideoHardware, OUTBYTE, INBYTE, WasteTime;



EXPORT
    (* PROC *)  StartVideoProcess, StopVideoProcess, InstallVideoProcess;


CONST
    TimerInterrupt  =  8;

VAR 
    Main, 
    VideoProcess      : PROCESS;

    Hi, NewHi         : CARDINAL; 

    ProcessStack      : ARRAY [1..1800] OF CHAR; (* our stack *)

    VideoProcessRunning,
    VideoProcessActive  : BOOLEAN;




PROCEDURE WaitOnInt8H();
BEGIN 
    VideoProcessRunning := TRUE;

    LOOP

        VideoProcessActive := TRUE; 

        WHILE VideoProcessActive DO 

            IOTRANSFER( VideoProcess, Main, TimerInterrupt ); 
            IF (VideoProcessActive) THEN
                SWI(TimerInterrupt);  (* Try not to race the clock. *)
            END;

            OUTBYTE(3D4H, 0EH );   (* Start cursor address high register selector *)
            WasteTime();
            INBYTE( 3D5H, Hi  );   (* High of start address *)

            NewHi := CARDINAL(BITSET(Hi) + BITSET(0C0H)); 
            IF (NewHi <> Hi) THEN 
                OUTBYTE(3D5H, NewHi );   (* High of start address *)
            END;

        END;

        VideoProcessRunning := FALSE; 
        TRANSFER( VideoProcess, Main );   (* Give foreground control *) 
        VideoProcessRunning := TRUE;
    END;

END WaitOnInt8H;






PROCEDURE StartVideoProcess();
BEGIN 

    IF (NOT VideoProcessActive) THEN

        WHILE (VideoProcessRunning) DO
            (* Wait for it to stop *) 
        END;

        TRANSFER( Main, VideoProcess );   (* Give background control *) 
    END;

END StartVideoProcess;




PROCEDURE StopVideoProcess();
BEGIN

    IF (VideoProcessActive) THEN
        VideoProcessActive := FALSE;
        SWI(TimerInterrupt);  (* signal our timer to stop *)
    END;

END StopVideoProcess;









VAR
    OldTerminateVideoHardware : PROC;


PROCEDURE MyTerminateVideoHardware();    (* 1-Jun-90 RSC Support 50 line mode. *)
BEGIN
    StopVideoProcess();
    OldTerminateVideoHardware();
END MyTerminateVideoHardware;







PROCEDURE InstallVideoProcess();
VAR 
    OldValue : CARDINAL;
BEGIN

    (* Don't use the proper STEAL procedures, because
       We will be long gone (oficially) when this code executes.
    *)
    OldTerminateVideoHardware := TerminateVideoHardware;
    TerminateVideoHardware    := MyTerminateVideoHardware;

    OldValue                  := activProcess^.currOverlay^.overlay; 

    activProcess^.currOverlay^.overlay := 1;

    NEWPROCESS( WaitOnInt8H, ADR(ProcessStack), 
                            SIZE(ProcessStack), VideoProcess ); 

    activProcess^.currOverlay^.overlay := OldValue; 

END InstallVideoProcess;


BEGIN
    VideoProcessActive   := FALSE;
    VideoProcessRunning  := FALSE; 
END ManageVideoProcess;






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
    TheOverlay  : OverlayPtr;
    ErrorCode   : CARDINAL;

    PROCEDURE TimeLineName( VAR s : ARRAY OF CHAR ) : BOOLEAN;
    BEGIN

        RETURN (s[0] = "T") AND (s[1] = "i") AND (s[2] = "m");

    END TimeLineName;


BEGIN

    TheOverlay := OverlayPtr(A);
    IF (TheOverlay = NIL) OR (TimeLineName(TheOverlay^.overlayName)) THEN

        KlugeRunning := TRUE; (* Watch out for all deallocates from now on! *)

        ShutdownVideoMemory();

    END;

    IF (ADDRESS(OldExitProc) <> NIL) THEN
        OldExitProc( PList, A );    (* WARNING!!  COULD BE DUMPING HERE!! *)
    END;

END TLXMSShutDown;








(* Steal the ALLOCATE vector.  Decide if we give HMA memory, VIDEO MEMORY,
   or DOS/UMB memory.
*)
PROCEDURE XALLOCATE( VAR A : ADDRESS; size : CARDINAL );
VAR
    i   : CARDINAL;
BEGIN

    IF (NOT KlugeRunning)                 AND
       (ProgramState = TLMainRunning)     AND
       (size <> TSIZE(OverlayDescriptor)) THEN
        FOR i := 1 TO NumberOfAreas DO
            WITH Areas[i] DO
                IF (Avail(ABlock(Adr),size)) THEN
                    Alloc( ABlock(Adr), A, size );
                    RETURN;
                END;
            END;
        END;
    END;

    OldALLOCATE( A, size );

END XALLOCATE;






VAR
    KlugeRunning    : BOOLEAN;



(* Steal the ALLOCATE vector.  Decide if the memory is HMA memory, or
   DOS/UMB memory.
*)
PROCEDURE XDEALLOCATE( VAR A : ADDRESS; size : CARDINAL );
VAR
    i,
    Segment      : CARDINAL;
    ok           : BOOLEAN;
BEGIN
    IF (KlugeRunning) THEN
        A := NIL;  (* Pretend to deallocate *)
        RETURN;
    END;

    Segment := A.SEGMENT;
    FOR i := 1 TO NumberOfAreas DO
        WITH Areas[i] DO
            IF (Segment = Adr.SEGMENT) THEN
                ok := DeAlloc( ABlock(Adr), A, size );
                RETURN;
            END;
        END;
    END;

    OldDEALLOCATE( A, size );

END XDEALLOCATE;






PROCEDURE XVideoAvailable( VAR FreeKB   : CARDINAL;
                           VAR TotalKB  : CARDINAL );
VAR
    i   : CARDINAL;
BEGIN
    FreeKB  := 0;
    TotalKB := 0;

    IF (NOT KlugeRunning) THEN
        FOR i := 1 TO NumberOfAreas DO
            WITH Areas[i] DO
                    (* Compute paras here, KB below
                    *)
                INC(FreeKB, CountOfFree(ABlock(Adr),16));
                INC(TotalKB,Size DIV 16);
            END;
        END;
    END;

        (* Convert the Paras to KB
        *)
    FreeKB  := FreeKB  DIV (1024 DIV 16);
    TotalKB := TotalKB DIV (1024 DIV 16);

END XVideoAvailable;






BEGIN
    OldExitProc   := RTDProc(NIL);
    NumberOfAreas := 0;

    VideoPresent  := IsVideoAvailable();

    IF (VideoPresent) THEN

        (* Uh, there is a slight problem deallocating memory from within
           the root when the overlay exits.  For now, we kluge big time.
           This is highly dangerous and suspect code.  Kids, don't do this
           at home!!
        *)
        OldALLOCATE   := ALLOCATE;
        OldDEALLOCATE := DEALLOCATE;
        ALLOCATE      := XALLOCATE;
        DEALLOCATE    := XDEALLOCATE;
        KlugeRunning  := FALSE;  (* Look for other "KlugeRunning"s!! *)
        InstallNewProcedure( ADR(ExitingToDOSNotification),  PROC(XExitingToDOSNotification),  ADR(OldExitingToDOSNotification));
        InstallNewProcedure( ADR(VideoAvailable),  PROC(XVideoAvailable), NIL );

        (* This is the RIGHT way to do this! *)

(*        IF (HMAFreeList <> NIL) THEN  (* These are only needed for HMA. *)*)
(*            InstallNewProcedure( ADR(ALLOCATE),  PROC(XALLOCATE),  ADR(OldALLOCATE));*)
(*            InstallNewProcedure( ADR(DEALLOCATE),PROC(XDEALLOCATE),ADR(OldDEALLOCATE));*)
(*        END;*)

        InstallVideoProcess();  (* 23-Sep-90 RSC *) 
        InstallNewProcedure(ADR(GetAnyCode),PROC(OurGetCode), ADR(OldGetCode)); 

        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), SetUpShutDown );
    END;

END TLVidMem.
