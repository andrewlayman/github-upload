    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Space;

(*$S+*)


(*  =========================================================================
    Last Edit : December 15, 1989 3:13PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

       Dec. 4, 1985   AJL - Expanded the size of some text buffers.
                          - Increased the memory requirements by 1K.
                            (LeastMemoryLevel from 18 to 19.)
       May. 28, 1987  AJL - Replaced the StackSpaceLeft internal calls
                            with calls to a new module, StackLeft,
                            so that we don't get recursion.

        21-Aug-87 LAA       Increased the size of arrays in DisplaySpaceLight
                            so it doesn't cause a TooLong error.
        24-Sep-87 LAA       Imported RTSMain instead of System for Logitech 
                            Version 3 compiler. 
         6-Nov-87 RSC       remove low mem msg, as it is also in a light.
         4-Dec-87 RSC       Handle low mem conditions better; that is,
                            avoid recursion in HeapAvailable and wait for
                            error box until the message processor is going.
                            This helps with program startup.
        15-Dec-87 LAA       Changed StackSpaceLeft to look at the SP, and
                            assume that the difference between it and zero is
                            the amount of stack left.
        16-Dec-87 LAA       HeapSpaceLeft sends an out-of-memory notice.
        12-Jan-88 LAA       Changed for new overlay scheme, where there's just
                            one number for space headroom.
        13-Jan-88 LAA       Tried to get the space light to work.
        26-Jan-88 LAA       Put a call to HeapSpaceLeft into DisplaySpaceLight
                            to be sure LowFuel is set correctly.
        29-Jan-88 LAA       Tried to clean things up because of low memory
                            errors.
        01-Feb-88 LAA       Low memory notices are now AfterActing.
        02-Feb-88 LAA       Changed parameters of HeapSpaceLeft, and removed
                            SpaceForOverlays.  No checks of space will directly
                            call the DisplaySpaceLight proc.
        03-Feb-88 LAA       Started using CountOfFreeHeap.
        17-Feb-88 LAA       Exported ALLOCATE and DEALLOCATE.
        18-Feb-88 LAA       Use BTStorage instead of Storage.
        22-Feb-88 LAA  - Force stack checking on for this module.
        11-Mar-88 LAA       Exported ChunkSize and LeastMemoryLevel.
        07-Nov-88 LAA       In FreeKOnHeap, incorporated the change made to
                            BTStorage for allocations in increments of 4K.
        09-Nov-88 RSC       In FreeKOnHeap, bumped up the allocations, as
                            DOS takes a para in addition to DOSAlloc's para.
                            Changed REAL globals to something less expensive
                            (Heap and LastStackSize).
        20-Jul-89 RSC       Removed LONGINTs.
        05-Aug-89 WKH       Initial OS/2 edits.
        15-Sep-89 RSC       Make space light 1-25 bytes.
                            Remove "StackLeft", replace with "StackSpaceLeft",
                            as it no longer calls the space light.
        21-Sep-89 WKH       Don't allow "grow" boxes, too slow
         5-Oct-89 EGK       Removed references to stack space in
                            HeapAvailable and DisplaySpaceLight.  This keeps
                            us from displaying a low-memory light if we are
                            running low on stack, or having the program think
                            there's no more heap left when we're simply too
                            deeply nested in the help system.
        29-Nov-89 EGK       Well, I didn't quite get that last one right.
                            This time, I changed StackSpaceLeft and
                            DisplaySpaceLight so that they don't use StackLow
                            to determine whether to set LowFuel.
        15-Dec-89 RSC       For mouse support, Change GetAnyCode to
                            GetNextEvent.
        26-Jul-91 LAA       Added special call to DOSAvail to check for
                            corrupted DOS memory.  This should help localize
                            a startup bug that's occasionally happening.
                            This code MUST be removed once we've found the
                            bug!
        19-Sep-91 LAA       In HeapSpaceLeft, use the rounded-up size for
                            our low-memory notice, to make sure enough
                            memory is freed up.  This will hopefully improve
                            the situation where a function runs out of memory
                            the first time, but succeeds the next time.
    =========================================================================
*)

FROM Boxes    IMPORT  DrawBox, ABoxType, ABoxAttribute;

IMPORT BTStorage;

FROM Dialog   IMPORT  Barf, Burp, Message, Error, FatalError;

FROM DOSMemory IMPORT DOSAvail;

FROM Endings  IMPORT EndWithErrorLevel, CompletionCode;

FROM Events   IMPORT
    (* TYPE *)      AnEvent,
    (* PROC *)      GetNextEvent;

FROM FileAux  IMPORT TerminateFiles;

FROM GaGa     IMPORT
    (* PROCS *)       GetGaGaMessage; 

FROM Kbio     IMPORT  KbioTerminate, Tone, PutString, avidmode;

FROM Lights   IMPORT  ALight, ActiveLightRegion, InstallLight, DisplayLight;

FROM LStrings IMPORT  ConcatS, ConcatLS, CtoS, Fill, SetString, SetLengthOf;

FROM MsgFile  IMPORT  GetMessage, DisplayMessage, ConcatMessage;

FROM Notices  IMPORT  AnOccasion, AStep, SendNotices;

FROM Paranoia IMPORT  InitializationOK, ProgramState, AProgramState;

FROM SYSTEM   IMPORT  ADDRESS, ADR, SP, GETREG;

(* DEBUG *) FROM Codes IMPORT ACode;

CONST
    ModuleNumber            = 0500;   (* For GetMessage *)
    SpaceLightPriority      = 70;

VAR
    MemoryWarningLevel : CARDINAL;
    LastStackSize,
    Heap               : CARDINAL;  (* Space left in PARAS! RSC 11/9/88 *)
    SpaceLight         : ALight;
    RequestedSize      : CARDINAL;
    PreviousLowFuel    : BOOLEAN;
    Initialized        : BOOLEAN;
    HeapLow,
    StackLow           : BOOLEAN;
    LowFuel            : BOOLEAN;
    InterlockFlag      : BOOLEAN;  (* Stamp out recursion *)

    (* SetHeapLevels -- Set the levels (in 1000's) for low memory
                        detection.  Warnings are issued for
                        low memory when HeapAvailable is called. *)


PROCEDURE SetHeapLevels(    Warning,  Minimum : CARDINAL );
BEGIN
    (*                                                            (* 12-Jan-88 LAA *)
    MemoryWarningLevel := Warning;
    LeastMemoryLevel   := Minimum;
    *)
    IF (HeapAvailable()) THEN; END;   (* Test the new memory settings. *)
END SetHeapLevels;


    (* GetHeapLevels -- What are the current settings for low
                        memory detection. *)


PROCEDURE GetHeapLevels( VAR Warning,  Minimum : CARDINAL );
BEGIN
    Warning := MemoryWarningLevel;
    Minimum := LeastMemoryLevel;
END GetHeapLevels;






    (* StackSpaceLeft -- Return TRUE iff there are "Amount"
                         bytes of stack space left.
    *)
PROCEDURE StackSpaceLeft(   Amount : CARDINAL ) : BOOLEAN;

VAR
    X                       : CARDINAL;

BEGIN

(*    IF (DOSAvail() > 0) THEN END;           (* DEBUGGING ONLY!!! *) *)
(*<OS2
    RETURN TRUE;
OS2>*)

(*<DOS*)
    GETREG(SP, X);

        (* To help debugging, store the last stack size checked. *)

    LastStackSize := X;
    StackLow      := (LastStackSize <= Amount);

(*          11/28/89 EGK
    LowFuel       := (StackLow OR HeapLow);
*)

    RETURN (NOT StackLow);
(*DOS>*)

END StackSpaceLeft;



PROCEDURE FreeKOnHeap(    SizeInK           : CARDINAL) 
                                                       : CARDINAL;

    (*  WARNING -- WARNING  these constants are copies of those in BTStorage,
                            and must ALWAYS be in sync with that module!!!!!
                            AND the module called "OvSize"!!!!!!!!!!!!!!!!!!
    *)

CONST

    (* Ajusted further by RSC on 11/9/88 *)

    OneFourth    = 256;        (* ((4096 + 32) * n) - 32, in paragraphs *)
    TwoFourths   = 512  + 2;
    ThreeFourths = 768  + 4;
    MinBlockSize = 1024 + 6;   (* in paragraphs *)

    ChunkSizeInParas = (ChunkSize DIV 16);  (* RSC 20-Jul-89 *)
VAR
    i                       : CARDINAL;
    WhatToReturn            : CARDINAL;
(*<OS2
    TempSpace		        : ARRAY [1..65] OF ADDRESS;
OS2>*)

BEGIN                       (* FreeKOnHeap *)

(*<DOS*)
    i := DOSAvail();                                              (* 07-Nov-88 LAA *)
    IF (i < MinBlockSize) THEN 
        IF (i >= ThreeFourths) THEN
            i := ThreeFourths;
        ELSIF (i >= TwoFourths) THEN
            i := TwoFourths;
        ELSIF (i >= OneFourth) THEN
            i := OneFourth;
        ELSE
            i := 0;
        END;
    END;

    WhatToReturn     := (i DIV ChunkSizeInParas); (* RSC 20-Jul-89 *)

    IF (WhatToReturn < SizeInK) THEN
        INC(WhatToReturn, BTStorage.CountOfFreeHeap(ChunkSize));
    END;
(*DOS>*)

(*<OS2
    i := 1;
    WHILE ((i <= SizeInK) AND (BTStorage.Available(ChunkSize))) DO
	    BTStorage.ALLOCATE(TempSpace[i], ChunkSize);
	    INC(i);
    END;

    WhatToReturn := i - 1;

    WHILE (i > 1) DO
	    DEC(i);
	    BTStorage.DEALLOCATE(TempSpace[i], ChunkSize);
    END;
OS2>*)

    RETURN WhatToReturn;
END FreeKOnHeap;




MODULE CheckHeapSpace;                                            (* 02-Feb-88 LAA *)

IMPORT                      AMemoryRequest, APurgeRequest, ADDRESS, AStep,
                            AnOccasion,
                            ChunkSize, DOSAvail,
                            BTStorage, SendNotices, FreeKOnHeap, FatalError;

EXPORT                      HeapSpaceLeft;


VAR
    RequestedSize           : CARDINAL;
    RequestedType           : AMemoryRequest;


PROCEDURE EnoughFree() : BOOLEAN;

BEGIN                       (* EnoughFree *)

    RETURN HeapSpaceLeft(RequestedSize, RequestedType, NoPurge);

END EnoughFree;



PROCEDURE HeapSpaceLeft(    Size            : CARDINAL;
                            Contiguity      : AMemoryRequest;
                            Purge           : APurgeRequest ) 
                                                             : BOOLEAN;

VAR
    SizeInK                 : CARDINAL;
    i                       : CARDINAL;
    ReturnValue             : BOOLEAN;

BEGIN                       (* HeapSpaceLeft *)

(*    IF (DOSAvail() > 0) THEN END;           (* DEBUGGING ONLY!!! *) *)
    IF (Size = 0) THEN RETURN TRUE; END;

    ReturnValue := TRUE;
    IF (NOT BTStorage.Available(Size)) THEN
        IF (Contiguity = NonContiguous) THEN

                (*  Try to allocate the appropriate number of ChunkSizes  *)

            SizeInK := Size DIV ChunkSize;
            IF (Size > ChunkSize * SizeInK) THEN
                INC(SizeInK);       
            END;

            i := FreeKOnHeap(SizeInK); 
            IF (i >= SizeInK) THEN
                ReturnValue := TRUE;
            ELSIF (Purge = PurgeForSpace) THEN
                    (*  Send low memory notice.  EnoughFree uses NoPurge.  *)
                RequestedSize := SizeInK * ChunkSize;          (* 19-Sep-91 *)
                RequestedType := NonContiguous;
                SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree)); 
                ReturnValue := HeapSpaceLeft(RequestedSize,NonContiguous,NoPurge);
            ELSE
                ReturnValue := FALSE;
            END;
        ELSIF (Purge = PurgeForSpace) THEN
                (*  Send low memory notice.  EnoughFree uses NoPurge.  *)
            RequestedSize := Size;
            RequestedType := Contiguous;
            SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree)); 
            ReturnValue := BTStorage.Available(Size);
        ELSE
            ReturnValue := FALSE;
        END;
    END;

    RETURN ReturnValue;

END HeapSpaceLeft;


BEGIN                       (* CheckHeapSpace *)
END CheckHeapSpace;




    (* Available --  Determine if a given number of bytes is available for
                     allocation.  Like BTStorage.Available, but issues a low
                     memory notice and tries again before it returns FALSE. *)

PROCEDURE Available(    Size                : CARDINAL) : BOOLEAN;

BEGIN                       (* Available *)

    RETURN HeapSpaceLeft(Size, Contiguous, PurgeForSpace);        (* 02-Feb-88 LAA *)

END Available;





PROCEDURE HeapAvailable() : BOOLEAN;

VAR
    Event                   : AnEvent;  (* 15-Dec-89 RSC  *)
    s                       : ARRAY [0..81] OF CHAR;
    Title                   : ARRAY [0..31] OF CHAR;
    WhatToReturn            : BOOLEAN;

BEGIN

    IF (InterlockFlag) THEN
        RETURN FALSE;
    END;

    InterlockFlag      := TRUE; (* Prevent recursion *)

    WhatToReturn := TRUE;

    IF (NOT HeapSpaceLeft(LeastMemoryLevel * ChunkSize, NonContiguous, PurgeForSpace)) THEN
        IF (ProgramState >= TLMainRunning) THEN
            GetMessage(ModuleNumber+1,s);   (*  "PROBLEM!  Out of memory space."  *)
            Error(s);
        ELSE
            InitializationOK := FALSE; (* Tell root not to go on. *)

            (* Because we may not have enough memory to start the message
               system, or we may be invoked bofore the message system has
               started, we opt for this no-frills 'out of memory' error.
            *)
            GetGaGaMessage( ModuleNumber + 0, s );     (* "There is not enough memory to start Time Line" *)
            GetGaGaMessage( ModuleNumber + 1, Title ); (* "Out Of Memory" *)
            DrawBox( 10, 10, 70, 20, ABoxType{DoubleBox, ShadowBox},
                     Title, videoreverse );
            PutString( s, (80-ORD(s[0])) DIV 2, 14, videobright );
            GetGaGaMessage( ModuleNumber + 2, s ); (* "(Press any key to exit Time Line)" *)
            PutString( s, (80-ORD(s[0])) DIV 2, 15, videobright );
            Barf();
            Barf();
            GetNextEvent(Event);    (* 15-Dec-89 RSC  *)
            KbioTerminate();
            TerminateFiles();
            EndWithErrorLevel( 1 );
        END;
        WhatToReturn := FALSE;
    END;

    InterlockFlag := FALSE;   (* No recursion in progress *)

    RETURN WhatToReturn;

END HeapAvailable;





PROCEDURE DisplaySpaceLight();

VAR
    i                       : CARDINAL;
    S                       : ARRAY [0..51] OF CHAR;
    s2                      : ARRAY [0..7] OF CHAR;

BEGIN
(*<DOS*)
    IF (NOT Initialized) THEN
        InstallLight(ActiveLightRegion, SpaceLightPriority, 1, 25, SpaceLight);
        Initialized := TRUE;
    END;

    i := FreeKOnHeap(MemoryWarningLevel);
    IF (i < MemoryWarningLevel) THEN
        SendNotices(LowMemory, BeforeActing, ADR(i)); 
    END;
    HeapLow := (i < MemoryWarningLevel);
    StackLow := NOT StackSpaceLeft(ChunkSize);
    LowFuel := HeapLow  (* OR StackLow *) ;     (* 11/28/89 EGK *)

    IF LowFuel <> PreviousLowFuel THEN
        IF (LowFuel) THEN
            GetMessage(ModuleNumber+4,S);
            ConcatS(S, " ");
            IF (i > LeastMemoryLevel) THEN
                CtoS(i-LeastMemoryLevel,s2);
            ELSE
                SetString(s2, "0");
            END;
            ConcatLS(S,s2);
            ConcatMessage(S,ModuleNumber+3);     (*  'K bytes left.'  *)
            DisplayLight(SpaceLight, S, videoreverse);
        ELSE
            SetLengthOf( S, 0 );
            DisplayLight(SpaceLight, S, videolights);
        END;
        PreviousLowFuel := LowFuel;
    END;
    Heap := DOSAvail();  (* Save heap space in PARAs *)
(*DOS>*)
END DisplaySpaceLight;



PROCEDURE ALLOCATE (VAR a: ADDRESS; size: CARDINAL);
(*
- Allocate some dynamic storage (contiguous memory area).

in:     size    number of bytes to allocate,

out:    a       ADDRESS of allocated storage.

The actual number of bytes allocated may be slightly
greater than 'size', due to administrative overhead.

Errors: If not enough space is available, or when
attempting to allocate more than 65520 (0FFF0H)
bytes at once, then the calling program is terminated
with the status 'heapovf'.
*)
BEGIN
(*    IF (DOSAvail() > 0) THEN END;           (* DEBUGGING ONLY!!! *) *)
(*<DOS*)
    IF (Available(size)) THEN
(*DOS>*)
(*<OS2
    IF (BTStorage.Available(size)) THEN
OS2>*)
        BTStorage.ALLOCATE(a, size);
    ELSE
        FatalError();
    END;

END ALLOCATE;


PROCEDURE DEALLOCATE (VAR a: ADDRESS; size: CARDINAL);
(*
- Release some dynamic storage (contiguous memory area).

in:     a       ADDRESS of the area to release,
        size    number of bytes to be released,

out:    a       set to NIL.

The storage area released is made available for subsequent
calls to ALLOCATE.
*)
BEGIN
(*    IF (DOSAvail() > 0) THEN END;           (* DEBUGGING ONLY!!! *) *)
    BTStorage.DEALLOCATE(a, size);
END DEALLOCATE;


BEGIN
        (* These numbers must be changed if the sizes of the overlays
           change.  The warning level is set to ensure that the largest
           overlay will execute provided at least that much memory
           remains.  The minimum is the amount required to load or save
           a schedule. *)

    MemoryWarningLevel := 18;                                     (* 13-Jan-88 LAA *)
    LeastMemoryLevel   := 8;                                      (* 12-Jan-88 LAA *)
    PreviousLowFuel    := FALSE;
    Initialized        := FALSE;
    InterlockFlag      := FALSE; (* No recursion in progress *)
    HeapLow            := FALSE;
    StackLow           := FALSE;

END Space.
