MODULE TLSwapF;

(*V1=PRODUCTION Without debugging printouts. *)
(*V2=PRINT WITH debugging printouts. *)
(*V3=TRACE with lots of debugging printouts. *)
(*V4=CHECKSUM Enables checksumming *)
(*V5=MONITOR Report buffer use statistics. *)
(*V6=AGRESSION Allow a slightly more agressive consumption of buffers. *)
(*V7=NONAGRESSION Allow a slightly more lazy consumption of buffers. *)

(* =======================================================================

   Run line parameters:

   SWAPVOL=(1,2,3,4)

        Meaning                                         Default
        ---------------------------------------------   -----------
   1:   The volume and directory to use for swapping.   Current Dir

   2:   Take Checksums on all disk operations? (Y/N)    N

   3:   Write dirty pages to disk if no keyboard        Y
        activity for a little while?           (Y/N)

   4:   Unload from memory if plenty (1MB) of EMS       Y
        is available?                          (Y/N) 

========================================================================*)



(*<TRACE        (*$R+*) (*$T+*) (*$S+*)        TRACE>*)
(*              (*$R=*) (*$T=*) (*$S=*)              *)


    (*-------------------------------------------------------------

        TLSwapF

        This module is responsible for creating and managing the
        storage and location of pages of data.  It is a support module
        for the ExtStorage module.

        This one manages pages of data in a temporary disk file.

    --------------------------------------------------------------- *)

    (* --------------------------------------------------------------

    MODIFICATION HISTORY:
 
    22-Dec-87   AJL - Added checking of the page numbers in the page headers
                      on read and write of buffers.
                    - Fixed the FindLRUUnused procedure to return a good value
                      in Oldest on return when a free buffer is found.
                    - Fixed a problem in which SetWrite no work.
    30-Dec-87   AJL - Changed the strategy for deallocating buffers when space
                      is low so that we deallocate in order of buffer address.  
                      This should create a contiguous gap quicker.
                    - Put phrases in the phrases file.
     3-Jan-88   AJL - SynchWrite all buffers on a LowMemoryNotice.
                    - Allow LowMemory notices during FindFreeBuffer.
     5-Jan-88   LAA - Use the procedure passed as context by a low memory
                      notice to determine how much memory to free up.  Also
                      fixed a problem with initialization of SwapVolume.
    11-Jan-88   AJL - Preallocate our minimum number of buffers so that later
                      program tests for sufficient memory will take these into
                      account.
    14-Jan-88   LAA - Converted the temporary file to a regular file, and
                      closed and reopened it each time it's extended.  This
                      is to prevent lost clusters if the program terminates
                      abnormally.
    21-Jan-88   AJL - With Roger's recent changes to overlays, we no longer
                      need to respond to overlay loading notices.
                    - If we need more memory, we will send out a low memory
                      notice.
    25-Jan-88   AJL - Give an error message if we cannot allocate our minimum
                      number of buffers on startup.
                    - Expanded the size of the SWAPVOL parameter allowed.
                    - Modified the shutdown page class proc so that it
                      doesn't attempt to close the file unless it was opened.
                    - Don't set the Initialized flag if we have no buffers.
                    - Improve the error checking on file reopen, and rearrange
                      the procedures to use a common procedure, OpenSwapingFile.
                    - Don't panic and synch write all buffers unless we are
                      down to only a few, as indicated by the global constant
                      ComfortBuffers. 
    29-Jan-88   LAA - Made string large enough to hold message in DoStartup.
     1-Feb-88   AJL - Changed ComfortBuffers to Minbuffers+2;
                    - Changed the NoticeLowMemory proc to distinguish between
                      BeforeActing step as a query on how much (non-contiguous)
                      space is available, vs AfterActing which is a request to
                      deallocate buffers.
    02-Feb-88   LAA - Changed for new Space exports.
    10-Feb-88   RSC - Changed the procedure which sends out notices to correctly
                      use AfterActing.  Using BeforeActing would increment our
                      procedure pointer, ruining the program.
                AJL - Correctly check that a buffer is allocated before replying 
                      that its size is available for deallocation.
    13-Feb-88   LAA - In NoticeLowMemory, add in allocated but unlocked pages.
    14-Feb-88   AJL - Use DisplayFileError in Complain, and add file name.
    22-Feb-88   RSC - set debugging toggles for production.
     2-Mar-88   AJL - Force a terminating "\" on the swapvolume parameter.
    06-Mar-88   LAA - Substituted HeapSpaceLeft for HeapAvailable so that
                      lots of low memory messages wouldn't come out just
                      because we tried to allocate a buffer, when not being
                      able to do so it really ok as far as the user is
                      concerned.
    08-Mar-88   AJL - Added support for a status record in PageClassStatus.
                    - On startup, check for sufficient EMS memory.  If there
                      is lots of EMS memory, don't even install this disk 
                      swapping.
    09-Mar-88   AJL - Don't use the GlobalFileIsNearlyFull flag.  Instead,
                      use Interlock.
                    - If no EMS present, respond as PageMedium in order to 
                      allow FlexStor to segregate pages.
    15-Mar-88   AJL - Added a new procedure, FindUnusedBuffer, that is used 
                      within FindLeastUnlocked and also FindFreeBuffer.  This
                      is to ensure that allocated buffers that do no contain
                      pages are used before new buffers get allocated.
                          A further space-saving technique would be to, on a
                      low memory notice, copy unlocked pages from higher addressed
                      buffers to lower addressed ones.  This has not been done.
    19-Jul-88   AJL - CheckSum every page on read or write.
    16-Aug-88   RSC - 1) Lower page size to 4096 bytes.
                      2) Use DOS for disk I/O, not Logitek.
     6-Sep-88   RSC - Extend file N blocks at a time.  This is valuable only
                      because we allocate 4K, not 8K chunks now.  Because of
                      this, the file is extended twice as often, with all
                      of the FAT update overhead.
    27-Oct-88   AJL - Expanded the documentation.
                    - Add an initial extent in pages that is created when
                      the file is first used.
     7-Nov-88   RSC - On disks with more than 35MB free, we were overflowing.
     7-Nov-88   AJL - When checking for the amount of space we could free up,
                      never go below the MinBuffers limit.
                    - Don't check disk free space on every status call.
                      Instead check the amount free whenever we create
                      a new page.  If other files are being written to the
                      same disk, this can delay our catching that the disk
                      is filling up.  However, it saves significant stack 
                      space in the XPageClassStatus procedure, which is 
                      sometimes called when stack space is low.
    18-Nov-88   AJL - Rather than a FatalError, display an Error message
                      if we get a disk read checksum error.  This is to
                      help tech support diagnostics.  Some people have
                      unreliable disks.  A side effect is that we will 
                      retry the read.  If the data was written correctly,
                      this will help.
                    - Reinstated checksumming.
                    - Checksumming is now controlled by a run time parameter.
                      SWAPVOL=(,N) turns it off.
    29-Nov-88   RSC - Put increments/decrements of Interlock around
                      OpenOurFile.  Also cleaned up other Interlocks around
                      Error() calls.  Added more reporting capabilities to
                      CheckLowOnSpace() to distinguish between File FULL,
                      File LOW, and BAD DISK.  Call CheckLowOnSpace() during
                      initialization to insure swapvol is ok.
    10-Jan-89   RSC - Change Storage to Space.
    22-Feb-89   AJL - Allow more than 256 pages.
                    - Changed initial disk allocation to 128K, additions in 
                      blocks of 16 pages.
     2-Mar-89   RSC - Changed parameters to "InstallNewProcedure".
     7-Mar-89   LAA   Changed ADDRESS to ADR in calls to InstallNewProcedure.
    25-Apr-89   RSC - OOPS!  In "WriteBuffer", "ok2" was not being set to TRUE,
                      meaning that occasionally the swap file is marked as
                      hideously unavailable.  On a SynchWrite, this is a
                      FatalError()!.  Reported by Telecom Canada.
     6/7/89     AJL - Be greeder for space, but decreasingly so.  Long periods
                      of buffer activity uninterrupted by other users requesting
                      memory will cause us to gradually increase our number of
                      buffers.
    6-Jul-89    KKC   Check existance of TLSwap.$$$ on the current directory.
                      If TLSwap.$$$ exists, modify the swap file name to a
                      non existing file name.
    10-Jul-89   KKC   Assemblerize GetSwapFileName so that it can be used
                      by TLDOS.
    01-Aug-89   KKC   Get SWAPVOL for swap file.
    09-Aug-89   KKC   Add copyright message.
    10-Aug-89   AJL  -Change the LRU method to use an AgedList to track
                      the age of buffers instead of a When clock.
                     -Improve LRU tracking by marking about half the
                      buffers as though they were not in memory as a
                      better way of tracking which are recently used.
                     -Add a version toggle that can turn on or off the
                      Agression tracking on buffers.
    11-Aug-89   AJL  -Fix the MarkProvisionalBuffers routine to
                      use a high water mark to reduce the number it marks
                      each time.
    14-Aug-89   AJL  -Correct the XCreatePage and XRetrieve page routines
                      so that they do not mark the page as swapped away
                      while it is still in use.
                     -Remove the compile options R- S- T-.
                     -Install an IdleProc into Kbio that will write dirty
                      buffers back to disk when waiting for KB input.  
    15-Aug-89   AJL  -Fix an error in MoveLower that could cause infinite
                      looping on a low-memory notice.
                     -During idle processing, or on a low memory notice,
                      try to move buffers to lower addresses in order to
                      reduce heap fragmentation.
    15-Aug-89   AJL  -The 1-Aug-89 change added a second call to get the 
                      SWAPVOL parameter, but it parsed and expanded it
                      differently than the code in the Startup proc.  I
                      have consolidated these. 
    12-Sep-89   AJL  -Added a THIRD Y/N parameter.  "N" disables idle
                      writes.
                     -WriteBuffer had been returning an error if the FileIsFull
                      flag was set.  Now, only return an error if there was actually
                      an error writing.
                     -Added more printer diagnostics, and delay opening the
                      printer until TLStart has configured the printer.
    25-Sep-89   LAA  -Return a status of BAD when interlocked.  This will
                      allow Rugs to still get space for a rug even when we're
                      low on space, but not when we're interlocked.
    13-Oct-89   RSC  -Low memory notice processing would call MoveLower(),
                      which could call low memory notices.  Made MoveLower()
                      less aggressive, only making new buffers if there is
                      existing free memory, not if memory COULD be made free.

                      Problem still outstanding: This overlay does not track
                            free space WITHIN buffers, so returns queazy
                            when the disk is full, even if buffers have
                            been discarded or are empty.

    23-Oct-89   RSC  -Added tracking of deleted pages, so we can determine

                      FlexSpaceAvailable = DiskSpaceAvailable + FreePages

                      This is to address the problem mentioned in my comment
                      of 13-Oct-89, and in bug report #1545.

                      This is done by monitoring the "DiscardPage" calls
                      from FlexStor.  We used to return FALSE, meaning
                      "I can't discard this.  Don't you either".

    23-Oct-89   AJL  -Make sure that XRetrievePage doesn't allow 
                      MarkProvisionalBuffers to mark the page being retrieved
                      as absent.
     4-Dec-89   RSC  -Add explicit 4th parameter to SWAPVOL=() to determine
                      if we should exit when there is enough EMS.  Set the
                      amount of EMS we need to be a little smaller.
     5-Dec-89   AJL  -Fix a coding error in the above change.
                     -Document the run-line parameters.
    14-Jun-90   RSC  -Fixed bug where we wrote to the disk 3 times for every
                      expected write.  Also upped the vpages from 512 to
                      1024.  Look for the "14-Jun-90"
     3-Oct-90   DSL  -Changed all "$"'s to "%"'s in filenames for Unix 
                      compatability
    23-Oct-90   RSC   Changed %'s to 4's in filenames for Dos batch.
     9-Nov-90   TGS   Integrate changes made to 4.03.
    29-Jul-91   AJL  -Default setting on checksums is now "No".
     4-Sep-91   EGK  -In two places, added parentheses where they seemed to
                      be lacking.  The construct is (a+b) MOD c, where the
                      parentheses keep the compiler from assuming
                      a + (B MOD C).  I don't have a specific bug that
                      resulted from this, but I did get range errors when
                      I compiled this module with range checking.
    24-Sep-91   LAA   Found a bug in AgedRemove, for the boundary condition
                      where AgedIn = AgedOut, which can occur when the 
                      AgedList is full.  It was removing the wrong item!
    27-Apr-92   LAA   In XSynchPage, SynchWrite was being called even on
                      buffers which have a locked object in them.  This 
                      seems (emperically) to cause a bogus "double lock"
                      error message from FlexStor later in the program.
                      Particularly, a low memory notice sent from Overlays 
                      while it's trying to make space to load TLCAPTIO on
                      the heap was doing this.  I conditioned the calls to
                      SynchWrite upon the buffer having a lock count of zero,
                      and that seems to fix it.
    ------------------------------------------------------------------ *)


FROM BlockOps               IMPORT
                                BlockMoveForward;

FROM Chainer                IMPORT
    (* PROC *)                  Chain;

FROM Codes                  IMPORT
    (* CONST *)                 BitsPerBitSet;

(*<CHECKSUM*)
FROM CRC16                  IMPORT
    (* PROC *)                  CheckSum; 
(*CHECKSUM>*)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp;

FROM Directory              IMPORT
    (* CONST *)                 MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
    (* TYPES *)                 AFileNameNode, AFileNameRecord,
                                AFileAttributeSet, ASetOfFileNameParts,
                                AFileNamePart,
    (* PROC *)                  DiskFreeSpace, PathLookupStart, GetPathEntry,
                                NormalizeFileName, ExpandPath;

FROM DOSIO                  IMPORT
    (* TYPE *)                  ADOSFileHandle, AnAccessType,
    (* PROCS *)                 DOSOpen, DOSClose, DOSDelete, DOSRefresh,
                                DOSRead, DOSWrite;

FROM DOSMemory              IMPORT
    (* PROC *)                  DOSAlloc, DOSDeAlloc, DOSAvail;

FROM FlexData               IMPORT
    (* TYPE *)                  APage, APagePointer, APageNo,
    (* VAR *)                   PageTable;
IMPORT FlexData; 

FROM FlexStor               IMPORT
    (* PROC *)                  InitExtStorage;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Fill, LStringToTString, SetLengthOf,
                                ConcatLS, Copy, ConcatS, Remove, LengthOf,
                                TStringToLString, CtoS, Procustes, LJust;

FROM Kbio                   IMPORT
                                AnIdleProcessProc,
                                IdleProcess;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  RegisterForNotices, SendNotices;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImALockedOverlay,
                                InstallNewProcedure;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM PageSupply             IMPORT
    (* TYPE *)                  APageCreateProc, APageDiscardProc, 
                                APageRetrieveProc,
                                APageSynchProc,
                                AStartupProc, AShutdownProc, APageClass,
                                APageClassStatus, APageClassStatusProc,
                                APageHandle,
    (* PROC *)                  CreatePage, DiscardPage, RetrievePage, 
                                SynchPage, PageClassStatus,
                                StartupPageClass, ShutdownPageClass;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;

FROM Space                  IMPORT
    (* TYPE *)                  AMemoryRequest, APurgeRequest,
    (* PROC *)                  HeapSpaceLeft, ALLOCATE, DEALLOCATE, Available;

FROM SwapFile               IMPORT
    (* PROC *)                  GetSwapFileName;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR, DOSCALL;


    (*<PRINT  
FROM Paranoia               IMPORT
        (* TYPE *)              AProgramState, ProgramState;

IMPORT PrintSupport;
      PRINT>*)

    (*<MONITOR
FROM Kbio                   IMPORT
                                avidmode;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* VAR *)                   ActiveLightRegion,
    (* PROC *)                  InstallLight, DisplayLight;
    MONITOR>*)




    (*$A+*)   (* Alignment on. *)

CONST
    ModuleNumber            = 21800;
    (* 4-Dec-89 RSC down from 1024.  EMS uses a page for overhead. *)
    EMSHandoffSize          = 1000;    (* This many K of EMS disables disk. *)  
    OurPageClass            = PageSlow;
    PageSizeInK             = 4;
    OurPageSize             = PageSizeInK * 1024;
    ParagraphSize           = 16;
    OurPageSizeInParagraphs = OurPageSize DIV ParagraphSize;
    MinBuffers              = 3;
    ComfortBuffers          = MinBuffers + 3; (* RSC 9/6/88 from 2 *)

    MaxBufferK              = 256;         (* Max K of memory to use. *)
    MaxBuffers              = MaxBufferK DIV PageSizeInK;
                                           (* If > 255, must change
                                              the BufferIn array. *)
    (*
    MaxHeadroom             = 2;           (* Megabytes virtual *)
    MaxVirtualPages         = MaxHeadroom * 1024 DIV (OurPageSize DIV 1024);
    *)
    MaxVirtualPages         = 1024;   (* Our limit.  Must be a multiple of 16 for BuffersInUse. *)  (* 14-Jun-90 RSC 512-->1024 *)
    MAXCARDINAL             = 0FFFFH;
    DefaultSwapVolume       = "DK:";
        (*  The should correspond to the LeastMemoryLevel in Space.  *)
    HeapAvailableLevel      = 8192 + 32;                          (* 06-Mar-88 LAA *)
      
    FileExtendSize          = 16;                   (* Blocks at a time. *)
    InitialExtent           = 128 DIV PageSizeInK;  (* Initial file size, in K. *)

TYPE             


        (* FlexStor asks us to store and retrieve pages according to a
           page number that he creates.  However, to keep track of our
           pages, we have our own numbering scheme that we control.  Our
           numbers correspond directly to the ordinal position of the page
           in the disk file.  That is what a VPageNumber is.
        *) 


    AVPageNumber            = [0..MaxVirtualPages];

    VPageHandle             = RECORD
                                  CASE BOOLEAN OF
                                      TRUE : A : ADDRESS;
                                     |FALSE: P : AVPageNumber;
                                  END;
                              END;


        (* Each BufferRecord keeps track of one potential buffer.  It
           indicates whether the buffer is allocated, where, what is in
           it, and when it was last read from disk. 
        *)

    ABufferRecord           = RECORD
                                  Where     : APagePointer;     (* NIL if unallocated. *)
                                  VPageNumber: AVPageNumber;    (* Our page number.  Where it goes on disk. *)
                                  FPageNo    : APageNo;         (* FlexStor's page number.  *)
                              END;

    ABufferNumber           = [0..MaxBuffers];

    APageClassSet           = SET OF APageClass;


TYPE
    AnUntilProc = PROCEDURE () : BOOLEAN;



VAR
    OverlayID               : AnOverlayID;

        (* PagesNowFree tracks pages that had been in use, but are now
           available (DiscardPage was called).  The list is the actual
           list of buffers free.  Bit n ON means that buffer is free.
           PagesNowFree = SUM(Bits ON in PagesNowFreeList).
        *)

    PagesNowFree            : CARDINAL;
    PagesNowFreeList        : ARRAY [0..((MaxVirtualPages+1) DIV BitsPerBitSet)-1] OF BITSET;

        (* BufferTable keeps track of all currently allocated buffers. *)

    BufferTable             : ARRAY [1..MaxBuffers] OF ABufferRecord;

        (* BufferIn is a reversed-index for BufferTable.  It allows us
           to rapidly determine which buffer a chosen page is in.  It
           must be kept in synch with the BufferTable.
        *)

    BufferIn                : ARRAY [1..MaxVirtualPages] OF CHAR;

    MaxFilePages,              (* Allocated file size in number of pages. *)
    MaxPage       : CARDINAL;  (* Pages actually created, <= MaxFilePages. *)

    BufferCount,               (* Number of buffers currently allocated. *)
    Interlock               : CARDINAL;     (* If > 0, we are busy. *)
    FreePagesOnDisk         : CARDINAL;


        (* Count of how many buffers are marked as though they are not in
           memory but really are.  See the Aging module. 
           This is not always an accurate count, and doesn't need to be. 
           The actual number of buffers that are marked is >= this, so
           this is a high water mark.  It speeds up provisional marking
           since we can start marking at this index, and then reset it.
        *)

    YoungestProvisionalBufferIndex : CARDINAL;    

        (* These two variables control how agressive we get in taking
           memory buffers.  The idea is that we keep growing our buffer
           pool above the ComfortBuffers level, but at a declining rate.
           Whenever someone else asks for memory though, we drop back to
           being unagressive.  The intention is that during a period of
           disk-intensive activity, such as recalc, we will gradually
           favor buffers over other users of memory.
        *)

        (*<AGRESSION
    AgressiveBuffers,
    AgressiveCountDown      : CARDINAL;
        AGRESSION>*)


    f                       : ADOSFileHandle;


    OldCreatePage           : APageCreateProc;
    OldDiscardPage          : APageDiscardProc;
    OldRetrievePage         : APageRetrieveProc;
    OldSynchPage            : APageSynchProc;
    OldPageClassStatus      : APageClassStatusProc;
    OldStartupPageClass     : AStartupProc;
    OldShutdownPageClass    : AShutdownProc;
    OldIdleProc             : AnIdleProcessProc;
   
    SwapVolume              : ARRAY [0..65] OF CHAR;

    OurPageClassSet         : APageClassSet;
 
    Initialized             : BOOLEAN;
    FileIsOpen              : BOOLEAN;
    FileIsFull              : BOOLEAN;
    TakeCheckSums           : BOOLEAN;
 


    (*<MONITOR
VAR
    Light : ALight;

PROCEDURE ReportBufferCount();
VAR
    S,S2 : ARRAY [0..25] OF CHAR;
BEGIN
    SetString(S,"Bufs=");
    CtoS(BufferCount,S2);
    ConcatLS(S,S2);
    DisplayLight(Light, S, videowarning);
END ReportBufferCount;



    MONITOR>*)








(*<PRINT
VAR
    ReadCount, WriteCount, CleanWriteCount : CARDINAL;

MODULE Printing;
IMPORT PrintSupport;
IMPORT TStringToLString, CtoS, ConcatS, ConcatLS;
IMPORT AProgramState, ProgramState;
EXPORT Trace, TraceI, TraceIJ, PrintLine, StartPrinting, EndPrinting;

TYPE
    APrintState = (Off, Waiting, Starting, Running, Ending );

VAR
    PrintState : APrintState;

PROCEDURE StartPrinting();
BEGIN
    PrintState := Waiting;
END StartPrinting;


PROCEDURE PrintLine( VAR S: ARRAY OF CHAR );
BEGIN
    IF (PrintState = Off) THEN 
        RETURN;
                 (* Wait until the program is initialized. *)
    ELSIF (PrintState = Waiting) AND (ProgramState >= TLMainStarting) THEN
        PrintState := Starting;
    END;

    IF (PrintState >= Starting) THEN
        IF (PrintState = Ending) THEN
            EndPrinting();
        ELSE
            IF (PrintState = Starting) THEN
                IF PrintSupport.StartReport() THEN
                    PrintState := Running;
                END;
            END;
            PrintSupport.PrintLine(S,0);
        END;
    END;
END PrintLine;

PROCEDURE Trace( S : ARRAY OF CHAR );
VAR
    S2 : ARRAY [0..80] OF CHAR;
BEGIN
    TStringToLString(S,S2);
    PrintLine(S2);
END Trace;


PROCEDURE TraceI( S : ARRAY OF CHAR; I : CARDINAL );
VAR
    S2 : ARRAY [0..80] OF CHAR;
    S3 : ARRAY [0..5] OF CHAR;
BEGIN
    TStringToLString(S,S2);
    CtoS(I,S3);
    ConcatS(S2," ");
    ConcatLS(S2,S3);
    PrintLine(S2);
END TraceI;

PROCEDURE TraceIJ( S : ARRAY OF CHAR; I,J : CARDINAL );
VAR
    S2 : ARRAY [0..80] OF CHAR;
    S3 : ARRAY [0..5] OF CHAR;
BEGIN
    TStringToLString(S,S2);
    CtoS(I,S3);
    ConcatS(S2,"   ");
    ConcatLS(S2,S3);
    CtoS(J,S3);
    ConcatS(S2,"     ");
    ConcatLS(S2,S3);
    PrintLine(S2);
END TraceIJ;



PROCEDURE EndPrinting();
BEGIN
    PrintSupport.EndReport();
    PrintState := Off;
END EndPrinting;

BEGIN
    PrintState := Off;
END Printing;



PROCEDURE CtoH     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
    CONST
        RADIX = 16;
        Size  = 4;
    VAR
        i,j,k : CARDINAL;
BEGIN
        j := Size;
        REPEAT
            k := Card MOD RADIX;
            IF (k < 10) THEN
                String[j] := CHR(ORD("0")+k);
            ELSE
                String[j] := CHR(ORD("A")+(k-10));
            END;
            Card := Card DIV RADIX;
            DEC(j);
        UNTIL (j = 0);
        String[0] := CHR(Size);
END CtoH;


PROCEDURE HtoS( A : ADDRESS; VAR S : ARRAY OF CHAR);
    VAR
        S2  : ARRAY [0..40] OF CHAR;
BEGIN
        CtoH(A.SEGMENT,S);
        ConcatS(S,":");
        CtoH(A.OFFSET,S2);
        ConcatLS(S,S2);
END HtoS;





PROCEDURE PrintBufferTable();
VAR
    S  : ARRAY [0..80] OF CHAR;
    S2 : ARRAY [0..30] OF CHAR;
    A  : ADDRESS;
    i, PrintedCount  : CARDINAL;
    X : ABufferNumber;
BEGIN
    IF (Interlock > 0) THEN
        Trace(" ");
        TraceI("Interlock = ",Interlock);
    END;

    SetString(S," ");
    PrintLine(S);
    SetString(S,"No     Where      VPage  FPage  Locks  Dirty");
    PrintLine(S);
    SetString(S,"-----  ---------  -----  -----  -----  -----");
    PrintLine(S);
    SetString(S," ");
    PrintLine(S);

    PrintedCount := 0;

    FOR i := 1 TO MaxBuffers DO
        IF (PrintedCount < BufferCount) THEN
            WITH BufferTable[i] DO
                CtoS(i,S);
                Procustes(S,5);
                IF (VPageNumber <> 0) THEN
                    ConcatS(S,"  ");
                    A := Where;
                    HtoS(A,S2);                         Procustes(S2,9);  ConcatLS(S,S2);  ConcatS(S,"  ");
                    CtoS(VPageNumber,S2);               Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
                    CtoS(FPageNo,S2);                   Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
                    CtoS(Where^.Header.LockCount,S2);   Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
                    IF (Where^.Header.Dirty) THEN
                        SetString(S2,"Dirty");
                    ELSE
                        SetString(S2,"     ");
                    END;
                    ConcatLS(S,S2);  ConcatS(S,"  ");
                END;
                PrintLine(S);
                INC(PrintedCount);
            END;
        END;
    END;

    SetString(S," ");
    PrintLine(S);

    SetString(S," ");
    PrintLine(S);
    SetString(S,"Age    BufferNo ");
    PrintLine(S);
    SetString(S,"-----  ---------");
    PrintLine(S);
    SetString(S," ");
    PrintLine(S);

    i := 0;
    WHILE (AgedInspect(i,X)) DO
        CtoS(i,S);
        ConcatS(S,"  ");
        CtoS(ORD(X),S2);
        ConcatLS(S,S2);
        PrintLine(S);
        INC(i);
    END;

    SetString(S," ");
    PrintLine(S);

 
END PrintBufferTable;






PROCEDURE NoticeProgramEnd(    Occasion : AnOccasion;
                               Step     : AStep;
                               Context  : ADDRESS ):BOOLEAN;
BEGIN
    Trace(" "); Trace("-----EndOfProgram-----"); 
    PrintBufferTable();
    TraceI("ReadCount       = ",ReadCount);
    TraceI("WriteCount      = ",WriteCount);
    TraceI("CleanWriteCount = ",CleanWriteCount);
    EndPrinting();
    RETURN TRUE;
END NoticeProgramEnd;





PRINT>*)


(*<TRACE  


TRACE>*)


(*<CHECKSUM*)
PROCEDURE CheckSumAPage( VAR Page : APage );
BEGIN
    IF (TakeCheckSums) THEN
        Page.Header.Check := CheckSum(ADR(Page.Header.PageNumber),
                               OurPageSize-2 );
    END;
END CheckSumAPage;
(*CHECKSUM>*)




PROCEDURE LocalFatalError();
BEGIN
    INC(Interlock);
        (*<TRACE    Trace("FatalError in TLSWAPF");
                    EndPrinting();
          TRACE>*)
    FatalError();
    DEC(Interlock);
END LocalFatalError;





PROCEDURE CheckBufferValid(    i : ABufferNumber );
BEGIN
    WITH BufferTable[i] DO
        IF (Where^.Header.PageNumber <> FPageNo) THEN
            LocalFatalError();
        END;
    END;
END CheckBufferValid;



PROCEDURE OpenOurFile;
VAR
    S          : ARRAY [0..127] OF CHAR;
BEGIN
    (*<TRACE    StartPrinting(); Trace("OpenOurFile");   TRACE>*)

    IF (FileIsFull) THEN RETURN END;    (* Bail out if impossible. *)


    GetSwapFileName( SwapVolume, S);                 (* KKC July 5, 1989 *)
    INC(Interlock);  (* RSC 11/29/88 *)
    FileIsOpen := DOSOpen( S, f, CreateFile, OurPageSize );
    FileIsFull := (NOT FileIsOpen);
    DEC(Interlock);  (* RSC 11/29/88 *)

END OpenOurFile;





PROCEDURE WriteBuffer( i : ABufferNumber ) : BOOLEAN;
CONST
    MaxTries    = 3;
    DiskReset   = 0DH;
VAR
    VPageNumber : AVPageNumber;
    ExtendBy,    
    Tries       : CARDINAL;
    Page        : APagePointer;
    ShortRecord,
    WroteOK, RefreshedOK     : BOOLEAN;
BEGIN
    IF (NOT FileIsOpen) THEN
        OpenOurFile();
        IF (NOT FileIsOpen) THEN
            (*<TRACE   TraceIJ("Write buffer while Closed, VPage ",i,VPageNumber);  TRACE>*)
            RETURN FALSE;
        END;
    END;

    Tries := 0;
    VPageNumber := BufferTable[i].VPageNumber;

    (*<TRACE   TraceIJ("Write buffer, VPage ",i,VPageNumber);  TRACE>*)
    (*<PRINT   INC(WriteCount);   PRINT>*)

        (* Check that we are synchronized. *)
   
    REPEAT
        WITH BufferTable[i] DO
            Page := Where;
            Page^.Header.Dirty := FALSE;  (* Well, it will be in a minute. *)
                (*<CHECKSUM*)
            IF (TakeCheckSums) THEN
                CheckSumAPage(Where^);
            END; 
                (*CHECKSUM>*)
            INC(Interlock);
            WroteOK := DOSWrite( f, VPageNumber, Where, ShortRecord );
            DEC(Interlock);
            RefreshedOK := TRUE; (* RSC 25-Apr-89 ARRGGHH! *)
        END;

        IF (WroteOK AND (NOT ShortRecord)) THEN
            IF (VPageNumber > MaxFilePages) THEN
                INC(Interlock);
                    (* The first time we write to the file, we will create
                       a large initial extent.  This may get us more
                       contiguous allocation. *)  
                IF (MaxFilePages = 0) THEN 
                    ExtendBy := InitialExtent;
                ELSE
                    ExtendBy := FileExtendSize;
                END;
                DEC(ExtendBy);             (* We already did one, remember? *)
                INC(MaxFilePages);         (* We already did THIS one. *)
                ShortRecord := FALSE;
                WHILE (WroteOK AND (ExtendBy > 0) AND (NOT ShortRecord)) DO
                    INC(MaxFilePages);
                    WroteOK := DOSWrite( f, MaxFilePages, BufferTable[i].Where, ShortRecord );
                    DEC(ExtendBy);     
                END;
                RefreshedOK := DOSRefresh( f ); (* Update the FAT.  Also resets disks. *)
                DEC(Interlock);
            END;
        ELSE
            Burp(); 
            (*<TRACE   TraceIJ("Error in Write buffer, VPage, Try ",i,Tries);   TRACE>*)
            INC(Tries);
        END;

    UNTIL (WroteOK) OR (Tries >= MaxTries);




    IF (WroteOK AND ShortRecord) THEN (* No error, but EOM? *)
        CheckLowOnSpace(); (* RSC 11/30/88 EOF?  Tell 'em we's in trouble. *)
        FileIsFull := TRUE;
        (*<TRACE   TraceIJ("FileIsFull in Write buffer, VPage ",i,VPageNumber);   TRACE>*)
    ELSIF (NOT WroteOK) OR (NOT RefreshedOK) THEN
        FileIsFull := TRUE;    (* If we ever get a write error, stop
                                  creating more pages. *)
        (*<TRACE   TraceIJ("Write Error in Write buffer, VPage ",i,VPageNumber);   TRACE>*)
    END;

    RETURN (WroteOK AND RefreshedOK);

END WriteBuffer;



    (* If the buffer needs to be written to disk in order to synchronize
       our in memory copy with the disk copy, do so. *)

PROCEDURE SynchWrite( i : ABufferNumber );
    (*<MONITOR  VAR S,S2 : ARRAY [0..25] OF CHAR;  MONITOR>*)
BEGIN
    WITH BufferTable[i] DO
        (*<TRACE   TraceIJ("SynchWrite buffer, VPage ",i,VPageNumber);   TRACE>*)
        IF (VPageNumber <> 0) AND             (* Page in buffer *)
           (Where^.Header.Dirty) THEN         (* Page is dirty. *)
                (*<MONITOR  SetString(S,"SynchWrite "); CtoS(BufferTable[i].FPageNo,S2);
                            ConcatLS(S,S2); DisplayLight(Light, S, videowarning);
                 MONITOR>*)
             CheckBufferValid(i);
             IF (NOT WriteBuffer(i)) THEN
                LocalFatalError();
             END;
        END;
    END;
END SynchWrite;





TYPE
    ABufferCompareProc = PROCEDURE( ABufferNumber, ABufferNumber ) : BOOLEAN;
       (* Returns TRUE iff first buffer <= second buffer  *)


PROCEDURE Highest( i, j : ABufferNumber ) : BOOLEAN;
VAR
    A, B : ADDRESS;
BEGIN
    A := BufferTable[i].Where; 
    B := BufferTable[j].Where; 
    RETURN A.SEGMENT >= B.SEGMENT;
END Highest;    








PROCEDURE FindUnusedBuffer( VAR Least         : ABufferNumber ) : BOOLEAN;
VAR
    i      : AVPageNumber;
    Found  : BOOLEAN;
BEGIN

        (* Find the "least", free, allocated buffer. *)
    Found := FALSE;
    Least := 1;
    WHILE (Least <= MaxBuffers) DO
        WITH BufferTable[Least] DO
            IF (Where=NIL) THEN          (* Not allocated. *)
            ELSIF (VPageNumber = 0) THEN (* Not in use. *)
               (*<TRACE   TraceIJ("FindUnusedBuffer returns ",Least,VPageNumber);   TRACE>*)
               RETURN TRUE;
            END;
        END;
            (*$R-*)
        INC(Least);
            (*$R=*)
    END;


    (*<TRACE  
    IF Found THEN
        TraceIJ("FindUnusedBuffer returns ",Least,BufferTable[Least].VPageNumber);
    ELSE
        Trace("FindUnusedBuffer returns FALSE.");
    END;
      TRACE>*)

    RETURN FALSE;

END FindUnusedBuffer;






PROCEDURE FindLeastUnlocked(     BufferCompare : ABufferCompareProc;
                             VAR Least         : ABufferNumber ) : BOOLEAN;
VAR
    i      : AVPageNumber;
    Found  : BOOLEAN;
BEGIN
    IF (FindUnusedBuffer(Least)) THEN RETURN TRUE; END;            (* 15-Mar-88 AJL *)

        (* Find the "least", free, allocated buffer. *)
    Found := FALSE;
    i := 1;
    WHILE (i <= MaxBuffers) DO
        WITH BufferTable[i] DO
            IF (Where=NIL) THEN          (* Not allocated. *)
            ELSIF (Where^.Header.LockCount = 0) THEN
                IF (NOT Found) OR 
                   ((NOT Where^.Header.Dirty) AND BufferTable[Least].Where^.Header.Dirty ) OR
                   ( BufferCompare( i, Least ) ) THEN
                    Least := i;
                END;
                Found := TRUE;
            END;
        END;
            (*$R-*)
        INC(i);
            (*$R=*)
    END;


    (*<TRACE  
    IF Found THEN
        TraceIJ("FindLeastUnlocked returns ",Least,BufferTable[Least].VPageNumber);
    ELSE
        Trace("FindLeastUnlocked returns FALSE.");
    END;
      TRACE>*)

    RETURN Found;

END FindLeastUnlocked;






    (* ReleaseBuffer -- Record that the buffer has been released.  Update
                        our cross-referenced tables.  Does not actually
                        deallocate space.
    *) 

PROCEDURE ReleaseBuffer( i : ABufferNumber );
BEGIN
    AgedRemove(i);
    IF (YoungestProvisionalBufferIndex > 0) THEN
        DEC(YoungestProvisionalBufferIndex);
    END;

    WITH BufferTable[i] DO
            (*<TRACE   TraceIJ("ReleaseBuffer ",i,VPageNumber);   TRACE>*)

            (* If there was a FlexStor page in this buffer, note that
               it is not there now. *)

        IF (VPageNumber <> 0) THEN

                (* Update FlexStor's tables of where his pages are. *)

            FlexData.PageTable^[FPageNo].Location := NIL;  (* Not in memory. *)

                (* Update our tables. *)

            BufferIn[VPageNumber] := 0C; (* Page not in any buffer. *)
            VPageNumber := 0;            (* No page in the buffer. *)

        END;

    END;
END ReleaseBuffer;






 (*
    Changed by:
    RSC 9/6/88 - Just look for enough DOS space.
 *)

PROCEDURE RoomForABuffer():BOOLEAN;
BEGIN
     RETURN (DOSAvail() >= OurPageSizeInParagraphs);
END RoomForABuffer;



 (*
    Changed by:
    RSC 9/6/88 - A simpler look for space than was here.  Mainly, send out
                 a LOT fewer low memory notices.  Also, try not to be so
                 greedy for space.
    AJL 6/7/89 - Be greeder for space, but decreasingly so. 
 *)


PROCEDURE RoomToAddABuffer():BOOLEAN;
VAR
    GotOne : BOOLEAN;
BEGIN

    (*
        IF DOS says there is enough memory, trust him.  In fact, there may
        be enough DOS memory, but then we may not have enough for misc.
        work.  If so, this will be caught in FindFreeBuffer or any other
        client of this procedure.
    *)

    IF (RoomForABuffer()) THEN
        RETURN TRUE;
    END;

    (*
        If we have several buffers already and there is no DOS memory avail in
        our size, well then just bail out.  The theory here is that if we were
        to send out a low mem notice, it would just throw away a resident
        overlay and cause some thrashing.  Hard to prove, I know.

        However, before we leave, we increase the number of buffers we will
        seek next time, or decrease our waiting period before increasing that
        buffer limit.

        The interval between increases in the number of buffers is inversely
        proportional to (BufferCount - ComfortBuffers).

    *)

    (*<AGRESSION
    IF (BufferCount >= ComfortBuffers + AgressiveBuffers) THEN
            (* Enough buffers already.  However, increase the liklihood
                that we will take a buffer on the next request. *)
        IF (AgressiveCountDown = 0) THEN
                (* Take one next time. *)
            INC(AgressiveBuffers);
        ELSE
            DEC(AgressiveCountDown); 
        END;
        RETURN FALSE;
    END;
    AGRESSION>*)

    (*<NONAGRESSION*)
    IF (BufferCount >= ComfortBuffers) THEN
        RETURN FALSE;
    END;
    (*NONAGRESSION>*)

    (*
        Well, there is not enough room and we don't have many buffers.  Send
        out a low memory notice.
    *)

    INC(Interlock);
    SendNotices(LowMemory, AfterActing, ADDRESS(RoomForABuffer));
    DEC(Interlock); 

    (*<AGRESSION
        (* Set the count of how many requests we will allow to fail before
           we increase the number of buffers.  By setting the count down
           to an increasing number, we become less agressive as we have 
           more buffers. *)

    AgressiveCountDown := AgressiveBuffers;
    AGRESSION>*)

       (* Can we actually allocate a new buffer? *)

    RETURN (RoomForABuffer());

END RoomToAddABuffer;






PROCEDURE FindFreeBuffer( VAR i : ABufferNumber ) : BOOLEAN;
VAR
    Oops : BOOLEAN;
BEGIN
    (*<TRACE   TraceI("FindFreeBuffer, Interlock = ",Interlock);   TRACE>*)

        (* If there are any buffers that are allocated but don't have 
           any page in them, find that buffer and return it.  The
           exception to this is during startup when we want to force
           creation of several buffers. *)

    IF (Initialized) AND (FindUnusedBuffer(i)) THEN RETURN TRUE; END;            (* 15-Mar-88 AJL *)


        (* Well . . . there are no unused buffers.  In that case, are
           we allowed to create one? *)

    IF (BufferCount < MaxBuffers) AND
       (RoomToAddABuffer()) THEN

            (* Room to grow.  Allocate another buffer. *)
        INC(Interlock);      (* Prevent processing of low-memory notices. *)
        i    := 1;
        Oops := FALSE;
        WHILE (i <= MaxBuffers) AND (NOT Oops) DO
            WITH BufferTable[i] DO
                IF (Where = NIL) THEN
                    DOSAlloc(Where,OurPageSizeInParagraphs);
                    IF (Where = NIL) THEN FatalError(); END;
                    IF (HeapSpaceLeft(HeapAvailableLevel, NonContiguous, PurgeForSpace)) THEN  (* 06-Mar-88 LAA *)
                        INC(BufferCount);
                        (*<MONITOR    ReportBufferCount(); MONITOR>*)  
                        DEC(Interlock);
                        (*<TRACE   TraceIJ("    FindFreeBuffer returns new buffer",i,VPageNumber);   TRACE>*)
                        RETURN TRUE;
                    ELSE
                            (* This page allocation pushed us into
                               a low memory condition.  Back out. *)
                        DOSDeAlloc(Where,OurPageSizeInParagraphs);
                        Oops := TRUE;
                    END;
                END;
            END;
            INC(i);
        END;
        DEC(Interlock);
    END;

        (* If we are not allowed to allocate a new buffer, can we find
           one that has a page in it, but that is unlocked so that we
           can reuse the buffer? *)

    IF (FindLeastUnlocked(Oldest,i)) THEN
        INC(Interlock);
        SynchWrite(i);
        ReleaseBuffer(i);
        DEC(Interlock);
        (*<TRACE   TraceIJ("    FindFreeBuffer returns old buffer",i,BufferTable[i].VPageNumber);   TRACE>*)
        RETURN TRUE;
    END;

    (*<TRACE   Trace("    FindFreeBuffer returns FALSE");   TRACE>*)

        (* Mama mia!  Mary mother of God!  No buffers!  *)


    RETURN FALSE;

END FindFreeBuffer;



PROCEDURE CheckLowOnSpace();
CONST
    WarningLevel = 4;
VAR
    MaxSectorsWeNeed,
    SectorsPerOurPage,
    FreeClusters,
    TotalClusters,
    BytesPerSector,
    SectorsPerCluster : CARDINAL;
    Valid             : BOOLEAN;

    (* Here we play Russian Roulette with the stack.  If they run out of disk space,
       then we try to tell them that.  If there is not enough stack, we will die.
    *)
    PROCEDURE WarnThem( DiskOK : BOOLEAN );
    VAR
        MessageNumber : CARDINAL;
        S             : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (DiskOK) THEN
            IF (FileIsFull) THEN
                MessageNumber := ModuleNumber + 5; (* "WARNING: Virtual memory swap file disk is full." *)
            ELSE
                MessageNumber := ModuleNumber + 2; (* "WARNING: Virtual memory swap file disk space is low." *)
            END;
        ELSE
            MessageNumber := ModuleNumber + 6; (* "WARNING: Virtual memory swap file disk does not exist." *)
        END;
        INC(Interlock);
        GetMessage(MessageNumber,S);
        Error(S);
        DEC(Interlock);
    END WarnThem;

BEGIN
    IF (NOT FileIsFull) AND (Interlock=0) THEN
        DiskFreeSpace(SwapVolume,FreeClusters,TotalClusters,BytesPerSector,SectorsPerCluster,Valid);

                (* Whenever we use up some disk space, check on how much is left.
                   Put the answer into a global variable for others to use.   These
                   complicated tests are only to ensure we don't overflow. *)

        IF (NOT Valid) THEN  (* Bad drive now?  Floppy or Bernoulli gone? *)
            FreeClusters      :=   0; (* Then there is no room. *)
            BytesPerSector    := 512; (* Some defaults. *)
            SectorsPerCluster :=   4;
        END;

        (* Compute the number of disk sectors in each of our buffers.
        *)
        IF (OurPageSize <= BytesPerSector) THEN
            SectorsPerOurPage := 1;
        ELSE
            SectorsPerOurPage := OurPageSize DIV BytesPerSector;
        END;

        IF (MaxVirtualPages <= (MAXCARDINAL DIV SectorsPerOurPage)) THEN
            MaxSectorsWeNeed := (MaxVirtualPages * SectorsPerOurPage);
        ELSE
            MaxSectorsWeNeed := MAXCARDINAL;
        END;

        (* Here, either there is a LOT free, or we will see exactly how much is
           free.
        *)
        IF (FreeClusters    >= (MaxSectorsWeNeed DIV SectorsPerCluster)) THEN
            FreePagesOnDisk := MaxVirtualPages;
        ELSE
            FreePagesOnDisk := ((FreeClusters * SectorsPerCluster) DIV SectorsPerOurPage);
            IF (FreePagesOnDisk <= WarningLevel) THEN
                FileIsFull := (FreePagesOnDisk = 0);
                (*<TRACE   TraceI("    Low Space, FreePages =",FreePagesOnDisk);   TRACE>*)
                (*<TRACE   IF (FileIsFull) THEN Trace("    File is Full !!!!"); END;   TRACE>*)
                WarnThem( Valid );
            END;
        END;

    END;
END CheckLowOnSpace;





PROCEDURE NewPage(VAR VPageNumber : AVPageNumber;
                      FPageNumber : CARDINAL;
                  VAR i           : ABufferNumber ):BOOLEAN;
VAR
    j               : CARDINAL;
    ExistingPage    : BOOLEAN;
BEGIN
    (*<TRACE   Trace("NewPage");   TRACE>*)

    IF (MaxPage >= MaxVirtualPages) OR
       (NOT FindFreeBuffer(i)) THEN
        RETURN FALSE;
    END;

    (* 23-Oct-89 RSC If we previously discarded a page, reclaim it now.
    *)
    ExistingPage := (PagesNowFree > 0);

    IF ExistingPage THEN
        j := 0;
        WHILE (j <= HIGH(PagesNowFreeList)) AND
              (PagesNowFreeList[j] = {}) DO
            INC(j);
        END;
        IF (j > HIGH(PagesNowFreeList)) THEN FatalError(); END;

        VPageNumber := 0;
        WHILE (VPageNumber < BitsPerBitSet) AND
              (NOT (VPageNumber IN PagesNowFreeList[j])) DO
            INC(VPageNumber);
        END;

        EXCL(PagesNowFreeList[j], VPageNumber );
        INC(VPageNumber, j * BitsPerBitSet);
        DEC(PagesNowFree);

    ELSE
        VPageNumber := MaxPage+1;
    END;

    BufferTable[i].VPageNumber := VPageNumber;
    BufferIn[VPageNumber]      := CHR(i);

    MakeYoungest(i);                 (* This is the youngest buffer. *)
    IF (YoungestProvisionalBufferIndex > 0) THEN
        DEC(YoungestProvisionalBufferIndex);
    END;

        (* Make it look like an invalid page. *)

    j := 0;
    (*$R-*)
    BufferTable[i].Where^.Header.PageNumber := j;
    (*$R=*)
    
    (*
    BufferTable[i].Where^.Header.Check      := VPageNumber;  (* Where did it come from? *)
    *)

         (* Update our buffer table to record the PageNo that
            FlexStor assigns to this page. *)

    BufferTable[i].FPageNo := FPageNumber;

        (* Write the buffer to disk in order to make sure that we
           really have room for it. *)


        (* Since we pre-write records in WriteBuffer, Only call it if we are
           extending beyond the current physical buffer.  Note that we
           test that we can actually write the page to the disk before we
           take the step of increasing MaxPage.  If we fail, we instead
           return FALSE.  This ensures that if we have created a new page,
           we can guarantee that there is a place on disk to store it.
        *)

    IF (NOT ExistingPage) THEN  (* 23-Oct-89 RSC *)
        IF (MaxPage >= MaxFilePages) AND (NOT WriteBuffer(i)) THEN
            BufferTable[i].VPageNumber := 0;
            BufferIn[VPageNumber] := 0C;
            RETURN FALSE;       (* Failure to create page. *)
        END;
        (* Increase our count of the number of pages we have created and
           given to FlexStor.
        *)

        INC(MaxPage);

        CheckLowOnSpace();

    END;

    RETURN TRUE;

END NewPage;




PROCEDURE UntilAtMinBuffers():BOOLEAN;
BEGIN
    RETURN FALSE;
END UntilAtMinBuffers;



PROCEDURE ReduceBufferUsage( Until : AnUntilProc );
VAR
    i : ABufferNumber;
    Criterea : ABufferCompareProc;
    RoyalFlush    : BOOLEAN;
BEGIN
    (*<TRACE   Trace("ReduceBufferUsage");   TRACE>*)

    INC(Interlock);

        (* Release the buffers until we are down to our
           minimum number or there are no more free ones.   If we have
           quite a few buffers, then we release the oldest ones first.
           If we are tight, though, we try to release contiguous ones. *)

    RoyalFlush := FALSE;

    LOOP
        IF (BufferCount >= ComfortBuffers) THEN
            Criterea := Oldest;
        ELSE
            Criterea := Highest;
            IF (NOT RoyalFlush) THEN
                    (* Write out all dirty buffers to give us more 
                       flexibility. *)
                IF XSynchPage(OurPageClass) THEN END;
                RoyalFlush := TRUE;
            END; 
        END;

        IF (Until()) OR
           (BufferCount <= MinBuffers) OR
           (NOT FindLeastUnlocked(Criterea,i)) THEN
    EXIT;
        END;

            (* Write dirty buffers back to disk. *)
        WITH BufferTable[i] DO
            SynchWrite(i);
               (* Release the buffer. *)
            DOSDeAlloc(Where,OurPageSizeInParagraphs);
            ReleaseBuffer(i);
            DEC(BufferCount);
            (*<MONITOR    ReportBufferCount(); MONITOR>*)  
        END;
    END;

    (*<AGRESSION
        (* Since someone else wants memory, start over again on the process
           of accumulating buffers above the ComfortBuffers level. *)

    IF (BufferCount > ComfortBuffers) THEN
        AgressiveBuffers := BufferCount - ComfortBuffers;
    ELSE
        AgressiveBuffers := 0;
    END;
    AgressiveCountDown := AgressiveBuffers;      (* Interval *)
    AGRESSION>*)

    DEC(Interlock);
END ReduceBufferUsage;







PROCEDURE NoticeLowMemory(     Occasion : AnOccasion;
                               Step     : AStep;
                               Context  : ADDRESS ):BOOLEAN;

VAR
    MemoryFree              : AnUntilProc;
    KFree                   : POINTER TO CARDINAL;
    i,CountLeft        : CARDINAL;
BEGIN
    (*<TRACE  
         Trace(" "); TraceIJ("NoticeLowMemory ",ORD(Occasion),Interlock); 
      TRACE>*)
    
    IF (Interlock = 0) THEN
        IF (Step = BeforeActing) THEN   (* Just inquiring how much could be freed. *)
            KFree := Context;
            CountLeft := BufferCount;
            FOR i := 1 TO MaxBuffers DO
                WITH BufferTable[i] DO
                    IF (CountLeft > MinBuffers)      (* Never presume we can free past the min limit. *)
                       AND
                       (Where <> NIL) THEN
                        IF ((VPageNumber = 0) OR (Where^.Header.LockCount = 0)) THEN  
                            INC(KFree^,PageSizeInK);
                            DEC(CountLeft);
                        END;
                    END;
                END;
            END;
         ELSE                           (* Asking to deallocate some buffers. *)
            IF (Context <> NIL) THEN                     
                MemoryFree := AnUntilProc(Context);
            ELSE
                MemoryFree := UntilAtMinBuffers;
            END;
            ReduceBufferUsage(MemoryFree); 
            WHILE (MoveLower()) DO END;    (* Compact the buffers. *)
        END;
    END;
 
    (*<TRACE  
         Trace(" "); TraceIJ("End NoticeLowMemory ",ORD(Occasion),Interlock); 
         PrintBufferTable();
       TRACE>*)
 
    RETURN TRUE;
END NoticeLowMemory;





    (* MarkProvisionalBuffers --
       
        Mark some of the buffers as though they are not in memory, so
        that we can detect which ones are really being used.  See the
        Aging module for details.
    *)

PROCEDURE MarkProvisionalBuffers();
CONST
    Proportion = 2;
    Limit      = 10;              (* Limit prevents us from adding too much
                                     overhead when there is lots of memory *)
VAR
    i, Max : CARDINAL;
    BufferNumber : ABufferNumber;
BEGIN
        (* The oldest half (or so) of all the buffers are marked to 
           FlexStor as though they are not in memory.  This will help
           us track their age of use better.    See the description 
           at the beginning of the Aging module, below.  *)
    Max := BufferCount DIV Proportion;
    IF (Max > Limit) THEN
        Max := Limit;
    END;

    i := YoungestProvisionalBufferIndex;     (* High water mark. *)

    WHILE (i < Max) AND (AgedInspect(i,BufferNumber) ) DO
        WITH BufferTable[BufferNumber] DO
                (* Never mess with a buffer that is in use. *)
            IF (Where^.Header.LockCount = 0) THEN
                FlexData.PageTable^[FPageNo].Location := NIL;
            END;
        END;
        INC(i);
    END;

    YoungestProvisionalBufferIndex := i;     (* High water mark. *)

END MarkProvisionalBuffers;



    (* Attempt to move the buffer to a lower address in memory. *)

PROCEDURE MoveLower( ):BOOLEAN;
VAR
    A, B            : ADDRESS;
    i               : CARDINAL;
    Page            : APagePointer;
    BufferNumber    : ABufferNumber;
    VPageNumber     : AVPageNumber;
    Move            : BOOLEAN;
    (*<MONITOR  VAR S,S2 : ARRAY [0..25] OF CHAR;  MONITOR>*)
BEGIN
    Move := FALSE;

    (* 13-Oct-89 RSC Was "RoomToAddABuffer()".  Use this less aggressive
                     approach (Don't send a low memory notice).
    *)
    IF (RoomForABuffer()) THEN
        DOSAlloc(B,OurPageSizeInParagraphs);
        IF (B = NIL) THEN FatalError; END;
            (* Try to find a buffer with a higher address. *)
        i := 0;
        WHILE (NOT Move) AND (AgedInspect(i,BufferNumber) ) DO
            WITH BufferTable[BufferNumber] DO
                IF (Where^.Header.LockCount = 0) THEN
                    A := Where;
                    IF (A.SEGMENT > B.SEGMENT) THEN 
                        Move := TRUE;
                    END;
                END;
            END;
            INC(i);
        END;

            (* If we found one, move the contents of the buffer, and update
               the client's tables. *)

        IF (Move) THEN
            BlockMoveForward (B,A,OurPageSize);       (* Non-overlap! *)
            WITH BufferTable[BufferNumber] DO
                Where := B;
                WITH FlexData.PageTable^[FPageNo] DO 
                    IF (Location = A) THEN
                        Location := B;
                    END;
                END;
                DOSDeAlloc(A,OurPageSizeInParagraphs);
                 (*<MONITOR 
                            INC(Where^.Header.LockCount);    (* Avoid recursion. *)
                            SetString(S,"MLow B="); CtoS(i,S2);
                            ConcatLS(S,S2); DisplayLight(Light, S, videowarning);
                            DEC(Where^.Header.LockCount);    (* Available again *)
                 MONITOR>*)
            END;
        ELSE
            DOSDeAlloc(B,OurPageSizeInParagraphs);
        END;
    END;

    RETURN Move;
END MoveLower;




    (* This gets called by the Kbio module when it is waiting on
       keyboard input for a long time. *)



PROCEDURE XIdleProc();
TYPE
    AStep = (Writing, Moving);
VAR
    i : CARDINAL;
    BufferNumber : ABufferNumber;
    WroteOne     : BOOLEAN;
BEGIN
        (* Write out the oldest dirty buffer. *)
    IF (Interlock = 0) THEN
        (*<MONITOR  Burp();   MONITOR>*)
    
        i := 0;
        WroteOne := FALSE;
        WHILE (NOT WroteOne) AND (AgedInspect(i,BufferNumber) ) DO
            WITH BufferTable[BufferNumber].Where^.Header DO
                IF (Dirty) AND (LockCount = 0) THEN
                    SynchWrite(BufferNumber);
                    WroteOne := TRUE;
                END;
            END;
            INC(i);
        END;

        IF (NOT WroteOne) THEN
            WroteOne := MoveLower();
        END;

        
    END;

        (* Call any other idle proc. *)

    OldIdleProc();

END XIdleProc;








PROCEDURE DoStartup():BOOLEAN;

VAR
    i                       : CARDINAL;
    ClassStatus             : APageClassStatus;
    S                       : ARRAY [0..255] OF CHAR;             (* 29-Jan-88 LAA *)
    S2                      : ARRAY [0..11] OF CHAR;
    DeferIfEnoughEMS,
    Found                   : BOOLEAN;
BEGIN                       (* DoStartup *)

    (* 23-Oct-89 RSC *)
    PagesNowFree     := 0;
    FOR i := 0 TO HIGH(PagesNowFreeList) DO
        PagesNowFreeList[i] := {};
    END;

    OurPageClassSet := APageClassSet{PageSlow};


        (* The swapvol parameter looks like

              SWAPVOL=()
              SWAPVOL=<Vol>
              SWAPVOL=(<Vol>,<Check>).
              SWAPVOL=(<Vol>,<Check>,<Idle>).
              SWAPVOL=(<Vol>,<Check>,<Idle>,<EMS>).

           IF (), then there will be NO disk swapping.

           If <Check> is supplied as "Y" then we turn on checksumming
               for greater error detection.
           If <Idle> is supplied as "N" then we turn off flushing of
               dirty records during idle time.
           If <EMS> is supplied as "N" then we turn off letting EMS
               override us ( > one meg, no disk swapping)
         *) 

    GetMessage(ModuleNumber+3,S2);    (* "SWAPVOL" *)
    GetOption(S2,Found,S);

    TakeCheckSums  := FALSE;              (* Default *)
    DeferIfEnoughEMS    := TRUE;
    SetLengthOf(SwapVolume,0);

    IF (Found) THEN
        IF (S[0]=0C) THEN    (* SWAPVOL=nothing bails us out. *)
            RETURN FALSE;
        ELSE
            WordNumber(S,1,SwapVolume);
                (* Second parameter controls whether we checksum all
                   reads and writes. *) 
            WordNumber(S,2,S2);
            IF (LengthOf(S2) > 0) AND (CAP(S2[1]) = "Y") THEN
                TakeCheckSums := TRUE;
            END;
                (* Third parameter controls whether or not the program 
                   attempts to write buffers and reorganize memory when
                   there is no keyboard activity. *)
            WordNumber(S,3,S2);
            IF (LengthOf(S2) = 0) OR (CAP(S2[1]) <> "N") THEN
                InstallNewProcedure(ADR(   IdleProcess       ),PROC(XIdleProc),          ADR(OldIdleProc));  
            END;
                (* Fourth parameter controls whether or not the program 
                   remains in memory even when there is plenty of EMS around.
                   RSC 4-Dec-89, Wayne made me do it.
                *)
            WordNumber(S,4,S2);
            IF (LengthOf(S2) > 0) AND (CAP(S2[1]) = "N") THEN
                DeferIfEnoughEMS    := FALSE;
            END;
        END;
    END;

        (* Check whether we are needed.  If there is sufficient EMS 
           memory available, then we do not need to be here supporting
           swapping to disk. *)

    IF (DeferIfEnoughEMS) THEN
        PageClassStatus( PageMedium, ClassStatus );
        WITH ClassStatus DO
            IF (Present) AND (Condition=0) THEN
                IF (FreePages >= (EMSHandoffSize DIV PageSize)) THEN
                    RETURN FALSE;
                END;
            ELSE
                (* Responding as medium speed also will allow FlexStor
                    to segregate items into medium and slow pages.  This
                    should greatly improve buffer efficiency. *)
                INCL(OurPageClassSet,PageMedium);   
            END;
        END;
    END;

        (* If there is more than one volume in the path, take the first.
           If none, use a default. *)

    Copy(SwapVolume,S);
    IF ( GetPathEntry( S, 0, SwapVolume ) ) THEN
    ELSE
        SetString(SwapVolume,DefaultSwapVolume);                  (* 05-Jan-88 LAA *)
    END;

        (* Expand the SwapVolume name to full specification. *)

    Copy(SwapVolume,S);
    SetLengthOf(S2,0);
    ExpandPath( S, S2, SwapVolume );

    (* ---- I believe that ExpandPath makes this unnecessary.  AJL
        (* Don't allow a path without a terminating "\" *)
    IF (NOT (SwapVolume[ORD(SwapVolume[0])] IN ASetOfChar{":","\"})) THEN 
        ConcatS(SwapVolume,"\");
    END;
    ------- *)



    MaxPage := 0;
    FOR i := 1 TO MaxVirtualPages DO
        BufferIn[i] := 0C;
    END;

    BufferCount := 0;
    (*<MONITOR    ReportBufferCount(); MONITOR>*)  

    FOR i := 1 TO MaxBuffers DO
        WITH BufferTable[i] DO
            Where := NIL;
            VPageNumber := 0;
        END;
    END;

    InstallNewProcedure(ADR(   CreatePage        ),PROC(XCreatePage),        ADR(OldCreatePage));
    InstallNewProcedure(ADR(   DiscardPage       ),PROC(XDiscardPage),       ADR(OldDiscardPage));
    InstallNewProcedure(ADR(   RetrievePage      ),PROC(XRetrievePage),      ADR(OldRetrievePage));
    InstallNewProcedure(ADR(   SynchPage         ),PROC(XSynchPage),         ADR(OldSynchPage));
    InstallNewProcedure(ADR(   StartupPageClass  ),PROC(XStartupPageClass),  ADR(OldStartupPageClass));
    InstallNewProcedure(ADR(   ShutdownPageClass ),PROC(XShutdownPageClass), ADR(OldShutdownPageClass));
    InstallNewProcedure(ADR(   PageClassStatus   ),PROC(XPageClassStatus),   ADR(OldPageClassStatus));


        (* Reduce our buffer usage whenever memory is low or prior
           to an overlay call. *)

    RegisterForNotices( LowMemory,   NoticeLowMemory );

    (*<TRACE   RegisterForNotices( ProgramEnd, NoticeProgramEnd ); 
               RegisterForNotices( ProgramQuit, NoticeProgramEnd );
      TRACE>*)

        (* Preallocate our minimum number of buffers. *)

    WHILE (BufferCount < MinBuffers) AND (FindFreeBuffer(i)) DO; END;

    IF (BufferCount < MinBuffers) THEN
        GetMessage(ModuleNumber+4,S);   (* warn of insufficient memory. *)
        Error(S);
    END;

    DEC(Interlock);

    CheckLowOnSpace();

    IF (BufferCount > 0) AND (NOT FileIsFull) THEN
        Initialized := TRUE;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END DoStartup;



        (*-----------------------------------------------------------

            XCreatePage

            Attempts to create a new page of the indicated class.

            Preconditions:
                StartupPageStorage returned TRUE.

            PostConditions:
                Either returns VPageHandle to the newly created
                page, or else FALSE.   When a handle is returned,
                the page is mapped into normal memory and its address
                and size is also returned.



        -------------------------------------------------------------*)


PROCEDURE XCreatePage (     PageClass     : APageClass;
                            PageNo        : CARDINAL;    (* FlexStor Page No. *)
                        VAR Size          : CARDINAL     ) : BOOLEAN;

VAR
    VPageNumber : AVPageNumber;
    i           : ABufferNumber;
    PageHandle  : VPageHandle;
    Page        : APagePointer;
    ok          : BOOLEAN;

BEGIN                       (* XCreatePage *)


    IF (NOT (PageClass IN OurPageClassSet)) THEN
        ok := OldCreatePage(PageClass, PageNo, Size);
    ELSE
        (*<TRACE   Trace(" "); TraceI("XCreatePage, Interlock = ",Interlock);
         PrintBufferTable();
          TRACE>*)

            (* We may get called by FlexStor before we are initialized as
               a consequence of an Error call during initialization.  In
               this case, responding with FALSE will signal that we are
               not capable of creating pages.

               If the FileIsFull, then we used to be able to create pages
               but cannot any longer.

               RSC 23-Oct-89 If there are some deleted pages, we can use
                             them before we extend the file.
            *) 

        ok   := (Initialized AND ((NOT FileIsFull) OR (PagesNowFree > 0)));

        Size := OurPageSize;

        ok   := (ok AND NewPage( PageHandle.P, PageNo, i ));

        IF (ok) THEN
                (* Update the FlexStor page table to contain the
                   current address and our V page number of the page. *)
            Page  := BufferTable[ i ].Where;
            WITH FlexData.PageTable^[PageNo] DO
                Location := Page;
                HomeAddress := APageHandle(PageHandle);
            END;
            WITH Page^.Header DO 
                    (* Update the page itself to show that it is not
                       the same as the copy on disk. *)
                Dirty := TRUE;
                    (* Prevent the provisional buffer marking from marking
                       this page. *)
                LockCount := 1;  
            END;
            MarkProvisionalBuffers();  (* Make some buffers into provisional swap out. *)
            Page^.Header.LockCount := 0;
        END;
    END;

    RETURN ok;

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
                         VAR PageHandle : VPageHandle ) : BOOLEAN;

VAR
    XPageHandle : APageHandle;
    OK          : BOOLEAN;

BEGIN                       (* XDiscardPage *)

    (* 23-Oct-89 RSC Reworked *)

    OK := (PageClass IN OurPageClassSet);

    IF (OK) THEN
        INC(PagesNowFree);
        WITH PageHandle DO
            IF (BufferIn[P] <> 0C) THEN
                ReleaseBuffer( ORD(BufferIn[P]) );
            END;
            INCL(PagesNowFreeList[ P DIV BitsPerBitSet ], P MOD BitsPerBitSet);
            A := NIL;
        END;
    ELSE

        (* We assume this will happen infrequently.
        *)

        XPageHandle := APageHandle(PageHandle);
        OK          := OldDiscardPage(PageClass, XPageHandle);
        PageHandle  := VPageHandle(XPageHandle);
    END;

    RETURN OK;

END XDiscardPage;








PROCEDURE ReadBuffer( VPageNumber : AVPageNumber; i : ABufferNumber ) : BOOLEAN;
CONST
    MaxTries = 3;
VAR
    S            : ARRAY [0..31] OF CHAR;   (* Keep Short. *)
    Count        : CARDINAL;
    Tries        : CARDINAL;
    Page         : APagePointer;
    ok,
    Eof          : BOOLEAN;
BEGIN
    (*<TRACE   TraceIJ("ReadBuffer (i,VPage) ",i,VPageNumber);   TRACE>*)
    (*<PRINT   INC(ReadCount);   PRINT>*)

    Tries := 0;

    WHILE (Tries < MaxTries) DO
        INC(Interlock);   (* RSC 11/30/88 *)
        ok := DOSRead( f, VPageNumber, BufferTable[i].Where, Eof );
        DEC(Interlock);   (* RSC 11/30/88 *)
        IF (ok) AND (NOT Eof) THEN
                (* OK.  A good read. *)
            BufferTable[i].VPageNumber := VPageNumber;
            Page := BufferTable[i].Where;
                    (*<CHECKSUM*)
            IF (TakeCheckSums) AND
               (Page^.Header.Check <> CheckSum(ADR(Page^.Header.PageNumber),OurPageSize-2)) THEN
                SetString(S,"Disk-Read CheckSum Error");
                INC(Interlock);   (* RSC 11/30/88 *)
                Error(S);
                DEC(Interlock);   (* RSC 11/30/88 *)
            ELSE            
                     (*CHECKSUM>*)

                IF (TakeCheckSums) THEN
                    IF (Page^.Header.Dirty) THEN
                        Page^.Header.Dirty      := FALSE;
                            (*<CHECKSUM*)
                        CheckSumAPage(Page^);
                            (*CHECKSUM>*)
                    END;
                END;
 
                BufferIn[VPageNumber]      := CHR(i);
 (* Exit *)     RETURN TRUE;
                    (*<CHECKSUM*)
            END;
                     (*CHECKSUM>*)
        END;
            (* Failure on reading. *)
        BufferIn[VPageNumber] := 0C;     (* Invalidate it. *)
        BufferTable[i].VPageNumber := 0;
        IF (Eof) THEN RETURN FALSE; END;
        INC(Tries);
     END;
     RETURN FALSE;

END ReadBuffer;




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

VAR
    BufferNumber : ABufferNumber;
    PageHandle  :  VPageHandle;
    Page         : APagePointer;
BEGIN                       (* XRetrievePage *)

    IF (PageClass IN OurPageClassSet) THEN
        (*<TRACE   Trace(" "); TraceI("XRetrievePage ",PageNo); 
         PrintBufferTable();
          TRACE>*)

        (*<DEBUGGING
        IF (NOT Initialized) THEN LocalFatalError(); END;
          DEBUGGING>*)
         
        IF (Interlock > 0) THEN RETURN FALSE; END;

            (* Look into FlexStor's tables to get our PageHandle, which
               contains our VPageNumber.   From that, locate the buffer. *)

        PageHandle  := VPageHandle(FlexData.PageTable^[PageNo].HomeAddress);
        BufferNumber := ORD(BufferIn[PageHandle.P]);


            (* If not in memory, find a buffer and read the page. *)

        IF (BufferNumber = 0) THEN
            IF (FindFreeBuffer(BufferNumber)) AND
               (ReadBuffer(PageHandle.P,BufferNumber)) THEN
            ELSE
                RETURN FALSE;
            END;
        END;


        MakeYoungest(BufferNumber);        (* This is now the newest buffer. *)
        IF (YoungestProvisionalBufferIndex > 0) THEN
            DEC(YoungestProvisionalBufferIndex);
        END;


        WITH BufferTable[BufferNumber] DO
            FPageNo := PageNo;            (* Where does FlexStor keep it? *)
                (* Get the address.   Put it into FlexStor's tables. *)
            Page := Where;
        END;

        FlexData.PageTable^[PageNo].Location := Page;


            (* Check synchronization. *)
        CheckBufferValid(BufferNumber);
            
            (* Make some buffers into provisional swap out.  Tell FlexStor that
               they are already gone. *)
        INC(Page^.Header.LockCount);       (* Prevent this buffer from marking. *)
        MarkProvisionalBuffers();
        DEC(Page^.Header.LockCount);

    ELSE
        RETURN OldRetrievePage(PageClass, PageNo);
    END;

    RETURN TRUE;

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

VAR
    i : ABufferNumber;
BEGIN                       (* XSynchPage *)

    IF (NOT (Class IN OurPageClassSet)) THEN
        RETURN OldSynchPage(Class);
    END;

    (*<TRACE   Trace(" "); Trace("XSynchPage"); 
         PrintBufferTable();
      TRACE>*)

    FOR i := 1 TO MaxBuffers DO
            (* Write dirty buffers back to disk. *)
        WITH BufferTable[i].Where^.Header DO
            IF (LockCount = 0) THEN
                SynchWrite(i);
            END;
        END;
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

    IF (NOT (Class IN OurPageClassSet)) THEN
        RETURN OldStartupPageClass(Class);
    ELSIF (Initialized) THEN
        RETURN OurPageSize;
    END;

    RETURN 0;

END XStartupPageClass;




        (*-----------------------------------------------------------

            XShutdownPageClass

            Ends a class of page storage.

            Preconditions:

            PostConditions:
                The class of storage is no longer available.

        -------------------------------------------------------------*)


PROCEDURE XShutdownPageClass(    Class : APageClass    );

VAR
    i  : ABufferNumber;
    ok : BOOLEAN;
BEGIN                       (* XShutdownPageClass *)

    IF (NOT (Class IN OurPageClassSet)) THEN
        OldShutdownPageClass(Class);
    ELSE
        IF (Initialized) THEN
            FOR i := 1 TO MaxBuffers DO
                WITH BufferTable[i] DO
                    IF (Where <> NIL) THEN
                        DOSDeAlloc(Where,OurPageSizeInParagraphs);
                    END;
                END;
            END;

                (* Discard any temporary file. *)
            IF (FileIsOpen) THEN
                INC(Interlock);   (* RSC 11/30/88 *)
                ok := DOSDelete( f );
                DEC(Interlock);   (* RSC 11/30/88 *)
            END;

        END;
        Initialized := FALSE;
    END;

END XShutdownPageClass;





PROCEDURE XPageClassStatus(     Class : APageClass;
                            VAR ClassStatus : APageClassStatus );
VAR
    Valid : BOOLEAN;
BEGIN
    IF (NOT (Class IN OurPageClassSet)) THEN
        OldPageClassStatus(Class,ClassStatus);
    ELSE
            (* We pick up the free pages from the global record rather
               than checking the disk, which would be more accurate but
               uses stack space when we may already be perilously low. *)
        IF (FileIsFull) THEN
            ClassStatus.FreePages :=  PagesNowFree;
        ELSE
            IF (FreePagesOnDisk < 1000) THEN
                ClassStatus.FreePages :=  FreePagesOnDisk + PagesNowFree;
            ELSE
                ClassStatus.FreePages :=  FreePagesOnDisk;
            END;
        END;

        WITH ClassStatus DO
            Present := TRUE;
            Busy := TRUE;
            PageSize := PageSizeInK;
            NumberOfPages := FreePages + MaxPage;
            IF (Initialized) THEN
                IF (Interlock = 0) THEN
                    Condition := 0;         (* All clear. *)
                    Busy := FALSE;
                ELSE
                    Condition := 2;         (* Bad *)             (* 25-Sep-89 LAA *)
                END;
            ELSE
                Condition := 2;             (* Bad *)
            END;
        END;
    END;
END XPageClassStatus;




PROCEDURE ShutDown();
VAR
    Copyright           : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    XShutdownPageClass(OurPageClass);
END ShutDown;



  (* -------------------- Module Aging ---------------------- *)


  (* This module manages a queue of buffer numbers.  It can add
     numbers to the end of the queue, remove numbers from the 
     queue, and find numbers based on their age in the queue. 

     We use it to keep the records so that we know which buffers are
     the least recently used.

     We are using this within a scheme invented by someone at Borland and
     described in the Turbo Pascal manual in the section on overlays.
     Briefly, we want to improve the accuracy of the tracking of the 
     least-recently-used buffer, so periodically tell FlexStor that the 
     oldest group of buffers have been swapped out, even though they 
     haven't been.  Those that FlexStor asks to be mapped in before they
     actually get swapped out are put at the end of the queue, as young
     buffers.

     The cost is the overhead of marking buffers as out, plus the work
     of doing an XRetrievePage more often.  The benefit is fewer disk
     reads.

  *) 



MODULE Aging;

IMPORT MaxBuffers,
       ABufferNumber,
       FatalError   (*<TRACE ,TraceI  TRACE>*)   ;


EXPORT 
    AgedDeposit, AgedRemove, AgedInspect, Oldest, MakeYoungest;

VAR
        (* AgedList is a queue that lists the buffers in order of the
           age of their most recent use. *)

    AgedList                : ARRAY [0..MaxBuffers-1] OF ABufferNumber;
    AgedIn, AgedOut, AgedN  : ABufferNumber;




PROCEDURE AgedDeposit( BufferNumber : ABufferNumber );
BEGIN
    (*<TRACE TraceI("AgedDeposit ",BufferNumber);  TRACE>*)
    IF (AgedN >= MaxBuffers) THEN HALT; END;
    INC(AgedN);
    AgedList[ AgedIn ] := BufferNumber;
    AgedIn := (AgedIn+1) MOD MaxBuffers;        (* 9/4/91 EGK *)
END AgedDeposit;



(*
PROCEDURE AgedFetch( VAR BufferNumber : ABufferNumber );
BEGIN
    IF (AgedN = 0) THEN FatalError(); END;
    DEC(AgedN);
    BufferNumber := AgedList[ AgedOut ];
    AgedOut := AgedOut+1 MOD MaxBuffers;
END AgedFetch;
*)


    (* AgedRemove -- If BufferNumber is in the list, take it out. *)

PROCEDURE AgedRemove( BufferNumber : ABufferNumber );
VAR
    i,j : CARDINAL;
    ToGo : CARDINAL;
BEGIN
    (*<TRACE TraceI("AgedRemove ",BufferNumber);  TRACE>*)


        (* See if it is in the list.  If so, where. *)
        (* Invarient is that if AgedList[n] = BufferNumber, then
           i >= n >= AgedIn-ToGo-1 \
           and                     |  MOD BufferNumber 
           i < AgedIn-ToGo,        |
           AgedOut <= AgedIn       /
           and, consequently, on exit
           either i=n or ToGo=0
   
        *) 
    i := AgedOut;
    ToGo := AgedN;
    WHILE (AgedList[i] <> BufferNumber) AND (ToGo > 0) DO
        i := (i + 1) MOD MaxBuffers;
        DEC(ToGo);
    END;
        (* Either ToGo = 0 or AgedList[i] = BufferNumber *)

    IF (ToGo > 0) THEN
        IF (i = AgedOut) THEN                                  (* 24-Sep-91 *)
                (*  Special case: no need to move anything! *)
            AgedOut := (AgedOut + 1) MOD MaxBuffers;
        ELSE
                (* Move the remaining items. *)
            WHILE (i <> AgedIn) DO
                j := (i+1) MOD MaxBuffers;      (* 9/4/91 EGK *)
                AgedList[i] := AgedList[j];
                i := j;
            END;

                (*AgedIn := AgedIn-1 MOD MaxBuffers;*)
            IF (AgedIn = 0) THEN
               AgedIn := MaxBuffers-1;
            ELSE
               DEC(AgedIn);
            END;  
        END;
            
        DEC(AgedN);
    END;

END AgedRemove;



PROCEDURE AgedInspect(    Sequence     : CARDINAL;
                      VAR BufferNumber : ABufferNumber
                      ) : BOOLEAN;
BEGIN
    IF (Sequence < AgedN) THEN
        BufferNumber := AgedList[ (AgedOut+Sequence) MOD MaxBuffers ];
        RETURN TRUE; 
    ELSE
        RETURN FALSE;
    END;
END AgedInspect;

(*
PROCEDURE Age( BufferNumber : ABufferNumber ) : CARDINAL;
VAR
    i : CARDINAL;
    B : ABufferNumber;
BEGIN
    i := 0;
    WHILE (AgedInspect(i,B)) AND (B <> BufferNumber) DO
        INC(i);
    END;
    IF (B <> BufferNumber) THEN
        FatalError();
    END;
    RETURN AgedN - i;
END Age;
*)

PROCEDURE Oldest( A, B : ABufferNumber ) : BOOLEAN;
VAR
    i : CARDINAL;
    X : ABufferNumber;
BEGIN
    i := 0;
    WHILE (AgedInspect(i,X)) DO
        IF (X=A) THEN RETURN TRUE
        ELSIF (X=B) THEN RETURN FALSE
        END;   
        INC(i);
    END;
    FatalError();
END Oldest;


PROCEDURE MakeYoungest( BufferNumber : ABufferNumber );
BEGIN
    AgedRemove(BufferNumber);
    AgedDeposit(BufferNumber);
END MakeYoungest;

BEGIN
        (* Empty AgedList *)
    AgedIn := 0;
    AgedOut := 0;
    AgedN  := 0;

END Aging;    
  (* -------------------- End Module Aging ---------------------- *)




BEGIN
    Initialized  := FALSE;
    FileIsOpen   := FALSE;
    FileIsFull   := FALSE;
    Interlock    := 1;       (* This is decremented in "DoStartup" *)
    MaxFilePages := 0;
    FreePagesOnDisk := MAXCARDINAL;      (* Presume lots of room. *)
    YoungestProvisionalBufferIndex := 0;

    (*<AGRESSION
    AgressiveBuffers := 0;
    AgressiveCountDown := 0;
    AGRESSION>*)
    
    (* RandomInit(1); *)


    (*<PRINT   ReadCount := 0; WriteCount := 0; CleanWriteCount := 0;  PRINT>*)


    (*<MONITOR InstallLight(ActiveLightRegion, 0, 2, 15, Light); MONITOR>*)


        (* If we are able to initialize, then we will chain to the
           next overlay, locking ourselves into memory.  If we fail to
           initialize, we will exit, freeing the memory.  The Chainer
           will then load the next overlay, without us. *)

    IF (DoStartup()) THEN
        IF (InitExtStorage(1000)) THEN END;
        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );
    END;


        (* The overlays module will back out our vectors when we leave. *)

END TLSwapF.

