MODULE TLSwapF;

    (* Supplies disk swapping for FlexStor using only one disk buffer. *)


(*V1=PRODUCTION Without debugging printouts. *)
(*V2=PRINT WITH debugging printouts. *)
(*V3=TRACE with lots of debugging printouts. *)
(*V4=CHECKSUM Enables checksumming *)
(*V5=MONITOR Report buffer use statistics. *)

(* =======================================================================

   Run line parameters:

   SWAPVOL=(1,2,3,4)

        Meaning                                         Default
        ---------------------------------------------   -----------
   1:   The volume and directory to use for swapping.   Current Dir

   2:   Take Checksums on all disk operations? (Y/N)    Y

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


FROM Codes                  IMPORT
    (* CONST *)                 BitsPerBitSet;

(*<CHECKSUM*)
FROM CRC16                  IMPORT
    (* PROC *)                  CheckSum; 
(*CHECKSUM>*)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp;

FROM Directory              IMPORT
    (* PROC *)                  DiskFreeSpace, GetPathEntry,
                                ExpandPath;

FROM DOSIO                  IMPORT
    (* TYPE *)                  ADOSFileHandle, AnAccessType,
    (* PROCS *)                 DOSOpen, DOSDelete, DOSRefresh,
                                DOSRead, DOSWrite;

FROM FlexData               IMPORT
    (* TYPE *)                  APage, APagePointer, APageNo;
IMPORT FlexData; 

FROM FlexStor               IMPORT
    (* PROC *)                  InitExtStorage;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Fill, LStringToTString, SetLengthOf,
                                ConcatLS, Copy, ConcatS, Remove, LengthOf,
                                TStringToLString, CtoS, Procustes, LJust;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

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

FROM SwapFile               IMPORT
    (* PROC *)                  GetSwapFileName;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR;


    (*<PRINT  
FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  RegisterForNotices, SendNotices;

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
    PageSizeInK             = 8;
    OurPageSize             = PageSizeInK * 1024;
    (*
    MaxHeadroom             = 2;           (* Megabytes virtual *)
    MaxVirtualPages         = MaxHeadroom * 1024 DIV (OurPageSize DIV 1024);
    *)
    MaxVirtualPages         = 1024;   (* Our limit.  Must be a multiple of 16 for BuffersInUse. *)  (* 14-Jun-90 RSC 512-->1024 *)
    MAXCARDINAL             = 0FFFFH;
    DefaultSwapVolume       = "DK:";
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

    APageClassSet           = SET OF APageClass;



VAR
        (* Allocate a page buffer of the size WE need, then point GPage at it. *)
    GBuffer     : ARRAY [0..OurPageSize-1] OF CHAR;
    GPage       : APagePointer;    (* Buffer for one page. *)
    VPageNumber : AVPageNumber;    (* Our page number on disk. *)
    FPageNo     : APageNo;         (* FlexStor's page number. *)


    OverlayID               : AnOverlayID;

        (* PagesNowFree tracks pages that had been in use, but are now
           available (DiscardPage was called).  The list is the actual
           list of buffers free.  Bit n ON means that buffer is free.
           PagesNowFree = SUM(Bits ON in PagesNowFreeList).
        *)

    PagesNowFree            : CARDINAL;
    PagesNowFreeList        : ARRAY [0..((MaxVirtualPages+1) DIV BitsPerBitSet)-1] OF BITSET;

    MaxFilePages,              (* Allocated file size in number of pages. *)
    MaxPage       : CARDINAL;  (* Pages actually created, <= MaxFilePages. *)

    Interlock               : CARDINAL;     (* If > 0, we are busy. *)
    FreePagesOnDisk         : CARDINAL;



    f                       : ADOSFileHandle;


    OldCreatePage           : APageCreateProc;
    OldDiscardPage          : APageDiscardProc;
    OldRetrievePage         : APageRetrieveProc;
    OldSynchPage            : APageSynchProc;
    OldPageClassStatus      : APageClassStatusProc;
    OldStartupPageClass     : AStartupProc;
    OldShutdownPageClass    : AShutdownProc;
   
    SwapVolume              : ARRAY [0..65] OF CHAR;

    OurPageClassSet         : APageClassSet;
 
    Initialized             : BOOLEAN;
    FileIsOpen              : BOOLEAN;
    FileIsFull              : BOOLEAN;
    TakeCheckSums           : BOOLEAN;
 





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
    SetString(S," VPage  FPage  Locks  Dirty");
    PrintLine(S);
    SetString(S," -----  -----  -----  -----");
    PrintLine(S);
    SetString(S," ");
    PrintLine(S);

    PrintedCount := 0;

    SetString(S,"Buffer: ");
    IF (VPageNumber <> 0) THEN
        CtoS(VPageNumber,S2);               Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
        CtoS(FPageNo,S2);                   Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
        CtoS(GPage^^.Header.LockCount,S2);   Procustes(S2,5);  ConcatLS(S,S2);  ConcatS(S,"  ");
        IF (GPage^^.Header.Dirty) THEN
            SetString(S2,"Dirty");
        ELSE
            SetString(S2,"     ");
        END;
        ConcatLS(S,S2);  ConcatS(S,"  ");
    END;
    PrintLine(S);

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





PROCEDURE CheckBufferValid();
BEGIN
    IF (GPage^.Header.PageNumber <> FPageNo) THEN
        LocalFatalError();
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





PROCEDURE WriteBuffer() : BOOLEAN;
CONST
    MaxTries    = 3;
VAR
    ExtendBy,    
    Tries       : CARDINAL;
    ShortRecord,
    WroteOK, RefreshedOK     : BOOLEAN;
BEGIN
    IF (NOT FileIsOpen) THEN
        OpenOurFile();
        IF (NOT FileIsOpen) THEN
            (*<TRACE   TraceI("Write buffer while Closed, VPage ",VPageNumber);  TRACE>*)
            RETURN FALSE;
        END;
    END;

    Tries := 0;

    (*<TRACE   TraceI("Write buffer, VPage ",VPageNumber);  TRACE>*)
    (*<PRINT   INC(WriteCount);   PRINT>*)

        (* Check that we are synchronized. *)
   
    REPEAT
        GPage^.Header.Dirty := FALSE;  (* Well, it will be in a minute. *)
            (*<CHECKSUM*)
        IF (TakeCheckSums) THEN
            CheckSumAPage(GPage^);
        END; 
            (*CHECKSUM>*)
        INC(Interlock);
        WroteOK := DOSWrite( f, VPageNumber, GPage, ShortRecord );
        DEC(Interlock);
        RefreshedOK := TRUE; (* RSC 25-Apr-89 ARRGGHH! *)
        

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
                    WroteOK := DOSWrite( f, MaxFilePages, GPage, ShortRecord );
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
        (*<TRACE   TraceI("FileIsFull in Write buffer, VPage ",VPageNumber);   TRACE>*)
    ELSIF (NOT WroteOK) OR (NOT RefreshedOK) THEN
        FileIsFull := TRUE;    (* If we ever get a write error, stop
                                  creating more pages. *)
        (*<TRACE   TraceI("Write Error in Write buffer, VPage ",VPageNumber);   TRACE>*)
    END;

    RETURN (WroteOK AND RefreshedOK);

END WriteBuffer;



    (* If the buffer needs to be written to disk in order to synchronize
       our in memory copy with the disk copy, do so. *)

PROCEDURE SynchWrite();
    (*<MONITOR  VAR S,S2 : ARRAY [0..25] OF CHAR;  MONITOR>*)
BEGIN
    (*<TRACE   TraceI("SynchWrite buffer, VPage ",VPageNumber);   TRACE>*)
    IF (VPageNumber <> 0) AND             (* Page in buffer *)
       (GPage^.Header.Dirty) THEN         (* Page is dirty. *)
            (*<MONITOR  SetString(S,"SynchWrite "); CtoS(FPageNo,S2);
                        ConcatLS(S,S2); DisplayLight(Light, S, videowarning);
             MONITOR>*)
         CheckBufferValid();
         IF (NOT WriteBuffer()) THEN
            LocalFatalError();
         END;
    END;
END SynchWrite;





PROCEDURE FindUnusedBuffer() : BOOLEAN;
BEGIN
    RETURN VPageNumber = 0;
END FindUnusedBuffer;






PROCEDURE FindLeastUnlocked() : BOOLEAN;
BEGIN
    RETURN (VPageNumber <> 0) AND (GPage^.Header.LockCount = 0);
END FindLeastUnlocked;






    (* ReleaseBuffer -- Record that the buffer has been released.  Update
                        our cross-referenced tables.  Does not actually
                        deallocate space.
    *) 

PROCEDURE ReleaseBuffer();
BEGIN
    (*<TRACE   TraceI("ReleaseBuffer ",VPageNumber);   TRACE>*)

        (* If there was a FlexStor page in this buffer, note that
           it is not there now. *)

    IF (VPageNumber <> 0) THEN

            (* Update FlexStor's tables of where his pages are. *)

        FlexData.PageTable^[FPageNo].Location := NIL;  (* Not in memory. *)

            (* Update our tables. *)

        VPageNumber := 0;            (* No page in the buffer. *)

    END;

END ReleaseBuffer;






PROCEDURE FindFreeBuffer() : BOOLEAN;
BEGIN
    (*<TRACE   TraceI("FindFreeBuffer, Interlock = ",Interlock);   TRACE>*)

        (* If there are any buffers that are allocated but don't have 
           any page in them, find that buffer and return it.  The
           exception to this is during startup when we want to force
           creation of several buffers. *)

    IF (Initialized) AND (FindUnusedBuffer()) THEN RETURN TRUE; END;            (* 15-Mar-88 AJL *)


        (* If we are not allowed to allocate a new buffer, can we find
           one that has a page in it, but that is unlocked so that we
           can reuse the buffer? *)

    IF (FindLeastUnlocked()) THEN
        INC(Interlock);
        SynchWrite();
        ReleaseBuffer();
        DEC(Interlock);
        (*<TRACE   TraceI("    FindFreeBuffer returns old buffer ",BufferTable[i].VPageNumber);   TRACE>*)
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





PROCEDURE NewPage(VAR VPageNo : AVPageNumber;
                      FPageNumber : CARDINAL      ):BOOLEAN;
VAR
    j               : CARDINAL;
    ExistingPage    : BOOLEAN;
BEGIN
    (*<TRACE   Trace("NewPage");   TRACE>*)

    IF (MaxPage >= MaxVirtualPages) OR
       (NOT FindFreeBuffer()) THEN
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

        VPageNo := 0;
        WHILE (VPageNo < BitsPerBitSet) AND
              (NOT (VPageNo IN PagesNowFreeList[j])) DO
            INC(VPageNo);
        END;

        EXCL(PagesNowFreeList[j], VPageNo );
        INC(VPageNo, j * BitsPerBitSet);
        DEC(PagesNowFree);

    ELSE
        VPageNo := MaxPage+1;
    END;


    VPageNumber := VPageNo;    (* Global record of which page is in the buffer. *)

        (* Make it look like an invalid page. *)

    j := 0;
    (*$R-*)
    GPage^.Header.PageNumber := j;
    (*$R=*)
    
    (*
    GPage^.Header.Check      := VPageNo;  (* Where did it come from? *)
    *)

         (* Update our buffer table to record the PageNo that
            FlexStor assigns to this page. *)

    FPageNo := FPageNumber;

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
        IF (MaxPage >= MaxFilePages) AND (NOT WriteBuffer()) THEN
            VPageNo := 0;
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

           If <Check> is supplied as "N" then we turn off checksumming
               for greater speed.
           If <Idle> is supplied as "N" then we turn off flushing of
               dirty records during idle time.
           If <EMS> is supplied as "N" then we turn off letting EMS
               override us ( > one meg, no disk swapping)
         *) 

    GetMessage(ModuleNumber+3,S2);    (* "SWAPVOL" *)
    GetOption(S2,Found,S);

    TakeCheckSums  := TRUE;
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
            IF (LengthOf(S2) > 0) AND (CAP(S2[1]) = "N") THEN
                TakeCheckSums := FALSE;
            END;
                (* Third parameter controls whether or not the program 
                   attempts to write buffers and reorganize memory when
                   there is no keyboard activity. *)
                   (* UNUSED NOW *)

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




    MaxPage := 0;
    VPageNumber := 0;
    FPageNo     := 0;

    InstallNewProcedure(ADR(   CreatePage        ),PROC(XCreatePage),        ADR(OldCreatePage));
    InstallNewProcedure(ADR(   DiscardPage       ),PROC(XDiscardPage),       ADR(OldDiscardPage));
    InstallNewProcedure(ADR(   RetrievePage      ),PROC(XRetrievePage),      ADR(OldRetrievePage));
    InstallNewProcedure(ADR(   SynchPage         ),PROC(XSynchPage),         ADR(OldSynchPage));
    InstallNewProcedure(ADR(   StartupPageClass  ),PROC(XStartupPageClass),  ADR(OldStartupPageClass));
    InstallNewProcedure(ADR(   ShutdownPageClass ),PROC(XShutdownPageClass), ADR(OldShutdownPageClass));
    InstallNewProcedure(ADR(   PageClassStatus   ),PROC(XPageClassStatus),   ADR(OldPageClassStatus));


    (*<TRACE   RegisterForNotices( ProgramEnd, NoticeProgramEnd ); 
               RegisterForNotices( ProgramQuit, NoticeProgramEnd );
      TRACE>*)

    DEC(Interlock);

    CheckLowOnSpace();

    IF (NOT FileIsFull) THEN
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
    PageHandle  : VPageHandle;
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

        ok   := (ok AND NewPage( PageHandle.P, PageNo ));

        IF (ok) THEN
                (* Update the FlexStor page table to contain the
                   current address and our V page number of the page. *)
            WITH FlexData.PageTable^[PageNo] DO
                Location := GPage;
                HomeAddress := APageHandle(PageHandle);
            END;
            WITH GPage^.Header DO 
                    (* Update the page itself to show that it is not
                       the same as the copy on disk. *)
                Dirty := TRUE;
                    (* Prevent the provisional buffer marking from marking
                       this page. *)
                LockCount := 1;  
            END;
            GPage^.Header.LockCount := 0;
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
            IF (VPageNumber = P) THEN
                ReleaseBuffer();
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








PROCEDURE ReadBuffer( VPageNo : AVPageNumber) : BOOLEAN;
CONST
    MaxTries = 3;
VAR
    S            : ARRAY [0..31] OF CHAR;   (* Keep Short. *)
    Tries        : CARDINAL;
    ok,
    Eof          : BOOLEAN;
BEGIN
    (*<TRACE   TraceI("ReadBuffer (VPage) ",VPageNumber);   TRACE>*)
    (*<PRINT   INC(ReadCount);   PRINT>*)

    Tries := 0;

    WHILE (Tries < MaxTries) DO
        INC(Interlock);   (* RSC 11/30/88 *)
        ok := DOSRead( f, VPageNo, GPage, Eof );
        DEC(Interlock);   (* RSC 11/30/88 *)
        IF (ok) AND (NOT Eof) THEN
                (* OK.  A good read. *)
            VPageNumber := VPageNo;
                    (*<CHECKSUM*)
            IF (TakeCheckSums) AND
               (GPage^.Header.Check <> CheckSum(ADR(GPage^.Header.PageNumber),OurPageSize-2)) THEN
                SetString(S,"Disk-Read CheckSum Error");
                INC(Interlock);   (* RSC 11/30/88 *)
                Error(S);
                DEC(Interlock);   (* RSC 11/30/88 *)
            ELSE            
                     (*CHECKSUM>*)

                IF (TakeCheckSums) THEN
                    IF (GPage^.Header.Dirty) THEN
                        GPage^.Header.Dirty      := FALSE;
                            (*<CHECKSUM*)
                        CheckSumAPage(GPage^);
                            (*CHECKSUM>*)
                    END;
                END;
 
 (* Exit *)     RETURN TRUE;
                    (*<CHECKSUM*)
            END;
                     (*CHECKSUM>*)
        END;
            (* Failure on reading. *)
        VPageNumber := 0;
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
    PageHandle  :  VPageHandle;
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

            (* If not in memory, find a buffer and read the page. *)

        IF (PageHandle.P <> VPageNumber) THEN
            IF (FindFreeBuffer()) AND
               (ReadBuffer(PageHandle.P)) THEN
            ELSE
                RETURN FALSE;
            END;
        END;


        FPageNo := PageNo;            (* Where does FlexStor keep it? *)
            (* Get the address.   Put it into FlexStor's tables. *)

        FlexData.PageTable^[PageNo].Location := GPage;


            (* Check synchronization. *)
        CheckBufferValid();
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

BEGIN                       (* XSynchPage *)

    IF (NOT (Class IN OurPageClassSet)) THEN
        RETURN OldSynchPage(Class);
    END;

    (*<TRACE   Trace(" "); Trace("XSynchPage"); 
         PrintBufferTable();
      TRACE>*)


            (* Write dirty buffers back to disk. *)
    SynchWrite();
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
    ok : BOOLEAN;
BEGIN                       (* XShutdownPageClass *)

    IF (NOT (Class IN OurPageClassSet)) THEN
        OldShutdownPageClass(Class);
    ELSE
        IF (Initialized) THEN
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




BEGIN
    Initialized  := FALSE;
    FileIsOpen   := FALSE;
    FileIsFull   := FALSE;
    Interlock    := 1;       (* This is decremented in "DoStartup" *)
    MaxFilePages := 0;
    GPage        := ADR(GBuffer);   (* A PageOfOurSize *)

    FreePagesOnDisk := MAXCARDINAL;      (* Presume lots of room. *)

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