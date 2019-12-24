MODULE TLMagic;

(*  =========================================================================
    Last Edit : March 27, 1991 11:03AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
    (***************************************************************)
    (*                                                             *)
    (*   TimeLine's Magic Mode driver                              *)
    (*                                                             *)
    (***************************************************************)


    MODIFICATION HISTORY:

        RSC 11/18/88 - Updated for OverlayTree.
        Feb 14, 1989   RSC   Made into a LOCKED overlay.
        23 Feb 89  AJL -FlexData.PageTable is now a pointer.
        6-Mar-89   RSC -Reflect new statistics gathering.
        8-Mar-89   RSC -Fix bug where storage manager was crashing
                        when overlays failed at Time Line startup.
        9-Jun-89   RSC -Added "Holder" debugging.
       13-Jun-89   RSC -Ed had updated the list of notices, but had
                        neglected to change the loop end, so some
                        notices caused fatal errors when you were
                        watching them.

                        Also, I put in a FAST Flexstor trap.

       27-Jul-89   RSC  Removed message file statistics.
        2-Aug-89   RSC  Support for ALLOCATE/DEALLOCATE as vectors.
       09-Aug-89   KKC  Add copyright message.
                        Call ContinuationBox instead of NoYes.
       23-Aug-89   RSC  Added stack dump - ALT-251.
       12-Sep-89   WKH  Make goto boxes bigger for compressed video mode
       14-Sep-89   RSC  Improved the handling of notices.  Reduced the size
                        of the lights, and put them at the end.  Reduced the
                        size of this module.  Removed the stack dump.
       15-Sep-89   RSC  Moved some ALLOCATE/DEALLOCATE checking code here
                        from Storage.MOD.
       02-Oct-89   WKH  Sorry Rog, great idea, but....
                        The XALLOCATE and XDEALLOCATE procedures are great
                        for checking to make sure we deallocate what we 
                        allocate except when we allocate stuff in the root
                        (before TLMagic is resident and we allocate SIZE
                        bytes) and the later try to deallocate it(when 
                        TLMagic is resident and we try to deallocate
                        SIZE+2 bytes!!!!).
                        I have commented out all code that does the byte
                        tagging but have left in the increment of counters
                        and such.  I'm not sure how to retain this feature.
                        That's your job....
       13-Oct-89   RSC  The "HeapDump" would miss entries on each page.
       27-Nov-89   RSC  Add support for sizing overlays.
       21-Jan-91   RSC  Improvements.
       27-Mar-91   RSC  In OvSizes, search for overlays first in the
                        current dir, and THEN in the master ov dir.

    =========================================================================
*)



  FROM Allocs      IMPORT TaskTree;
  FROM Boxes       IMPORT
    (* TYPE *)            ABoxType, ABoxAttribute;
  FROM RcDynMem    IMPORT ABlock, CountOfFree;
  FROM BTStorage   IMPORT AStorageProc, ALLOCATE, DEALLOCATE;
  FROM Space       IMPORT Available;
  FROM Chainer     IMPORT Chain;
  FROM Codes       IMPORT ACode;
  FROM Dialog      IMPORT Error, Barf, MultipleChoiceBox, ADialogOption, 
                          FatalError, Message, Burp, ContinuationBox, 
                          NotYetImplemented, WarningBox;
  FROM Directory   IMPORT
    (* TYPE *)          AFileAttributeSet, AFileNameRecord,
    (* PROC *)          StartFileNodeLookup, ContinueFileNodeLookup;

  FROM Dispatcher  IMPORT Dispatch;
  FROM DOSMemory   IMPORT DOSAvail, DOSAlloc, DOSDeAlloc;
  FROM DynMem      IMPORT Alloc, DeAlloc;

FROM FileAux   IMPORT
    (* VAR *)       EXEPath;

  FROM FlexData    IMPORT MaxPages, PageTable, APagePointer;
  FROM FlexDbug    IMPORT DiagnosticHook;
  FROM FlexTrace   IMPORT TraceOn, TraceOff;
  FROM GoTo        IMPORT
    (* PROC *)            DoGoTo, NullGoToCheckProc;
  FROM Holder      IMPORT ForAllHeldItems, DeleteHeldItem, AHoldType, AHoldTypeSet;
  FROM InitMenu    IMPORT SetMenuItem, AddMenuItem, DeleteMenuItem;
  FROM Kbio        IMPORT KeyPress, GetAnyCode, Tone, avidmode, maxrow;
  FROM Lights      IMPORT InstallLight, ActiveLightRegion, DisplayLight, ALight,
                          RemoveLight, EnableLights;
  FROM LStrings    IMPORT TrimRear, SetString, ConcatLS, ConcatS, CtoS,
                          TrimFront, LengthOf, Compare,
                          Insert, SetLengthOf, Fill, TStringToLString,
                          Copy, Procustes, RJust, SubStr, Remove;

FROM Menus          IMPORT
    (* PROC *)          WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          RegisterForNotices, Permission, SendNotices;

FROM Overlays      IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvSize         IMPORT
    (* PROC *)          OpenOverlay, DetermineOverlaySize, CloseOverlay;

FROM OvTree        IMPORT
    (* TYPE *)          AContextListEntry, AnOverlayProc, ALoadOption,
                        AResidenceWhere, AResidence,
    (* VAR  *)          OverlayTree;

FROM PageSupply             IMPORT
    (* TYPE *)                  APageCreateProc, APageDiscardProc, 
                                APageRetrieveProc,
                                APageSynchProc,
                                AStartupProc, AShutdownProc, 
                                APageClassStatusProc, APageClass,
                                APageHandle, APageClassStatus,
    (* PROC *)                  CreatePage, DiscardPage, RetrievePage, 
                                SynchPage, PageClassStatus,
                                StartupPageClass, ShutdownPageClass;

  FROM Paranoia    IMPORT AnAnxietyLevel, AnxietyLevel;
  FROM RealFormat  IMPORT FormatAsAmount, DefaultAmountFormat;
  FROM Rugs        IMPORT RugsInUse, RugBytes;
  FROM RsrcMod      IMPORT AResource;
  FROM RunMenu     IMPORT AnItem;
  FROM RTSMain     IMPORT blockList, Status, OverlayPtr, activProcess;
(* ****  FROM Stack       IMPORT Dump;  *RSC 14-Sep-89*  ***** *)
  FROM SYSTEM      IMPORT ADR, ADDRESS, TSIZE, SIZE, GETREG, SP, AX, SWI, DOSCALL;
  FROM TimeDate    IMPORT Time, GetTime, TimeToString;
  FROM TreeObjects IMPORT ATree, ATreeOrder, ATreeNode, CreateTree, CreateTreeNode;
  FROM Undo        IMPORT
    (* VAR  *)            UndoTree, RedoTree;
  FROM UndoViews   IMPORT
    (* PROC *)            GetUndoInfo;


IMPORT Keyboard;





 (* From Storage:    *)

TYPE
    BlockPtr    = RECORD
                    CASE BOOLEAN OF
                      TRUE  : ptr : POINTER TO DOSBlockHeader |
                      FALSE : adr : ADDRESS;
                    END;
                  END;

    DOSBlockHeader = RECORD
                       nextBlockSeg,
                       prevBlockSeg  : CARDINAL;
                       nextProceSeg,
                       prevProceSeg  : CARDINAL;
                       blockParaSize : CARDINAL;
                       dynamic       : BOOLEAN;
                       reserved      : ARRAY [0..4] OF CHAR;
                     END;


    AReportItem = RECORD
                        Addr    : CARDINAL;  (* Well, segment. *)
                        Size    : CARDINAL;  (* in para *)
                        Name    : ARRAY [0..9] OF CHAR;
                  END;


TYPE
    AMemoryChunkPtr = POINTER TO AMemoryChunk;
    AMemoryChunk = RECORD
        Prev  : AMemoryChunkPtr;
        Heap  : BOOLEAN;                (* On the heap? *)
    END;



CONST
    MagicModeKey      = 253;
    DumpCode          = 251;
    Zero              = 0.0;
    CreateAFile       = 3CH;
    OpenAFile         = 3DH;
    NormalAttribute   = 00H;
    CloseFile         = 3EH;
    WriteRecord       = 40H;
    SetPos            = 42H;

  ReadWriteMode       =  2H;
  ExclusiveAccessMode = 10H; (* network functions available only in DOS 3.0 *)

VAR
    OverlayID               : AnOverlayID;

    HolderTree              : ATree;
    OldALLOCATE,
    OldDEALLOCATE           : AStorageProc;
    i                       : CARDINAL;
    OldCreatePage           : APageCreateProc;
    OldGetCode              : Keyboard.AGetCodeProcedure;
    HeapItems               : CARDINAL;
    GSize                   : REAL;
    ReportItems             : CARDINAL;
    Report                  : POINTER TO ARRAY [1..250] OF AReportItem;
    MemoryChunkList         : AMemoryChunkPtr;  (* End of list *)
    CloseLogInterlock,
    MagicModeLevel,
    SizeToWatchFor          : CARDINAL;
    LogHandle               : CARDINAL;
    NoticeCount             : ARRAY AnOccasion OF CARDINAL;
    LastLightBarSize        : CARDINAL;  (* # bars displayed. *)
    NoticeLight,
    StackLight              : ALight;

    FirstTime,
    DisplayNotices          : BOOLEAN;
    WatchingForSize         : BOOLEAN;
    Logging                 : BOOLEAN;
    CheckStackActive,
    WatchForNotices         : BOOLEAN;






PROCEDURE OurGetCode():CARDINAL;
VAR
    Code          : CARDINAL;
    s             : ARRAY [0..9] OF CHAR;
BEGIN
    LOOP
        CheckStack();
        Code := OldGetCode();
        CheckStack();
        IF (Code = MagicModeKey) THEN
            INC(MagicModeLevel);
            WHILE DoMenu() DO END;
            DEC(MagicModeLevel);

    (* ****** RSC 14-Sep-89

        ELSIF (Code = DumpCode) THEN
            INC(MagicModeLevel);
            SubStr( EXEPath, s, 1, 2 );
            ConcatS( s, "\MAP\" );
            Dump(s);
            DEC(MagicModeLevel);
    *** *)

        ELSE
            RETURN Code;
        END;
    END;
END OurGetCode;






PROCEDURE WriteLog( VAR s, Title : ARRAY OF CHAR; AlsoToScreen : BOOLEAN );
CONST
    BreakLineDefault = 374C;
VAR
    i,
    ErrorCode,
    XferedBytes : CARDINAL;
    s1          : ARRAY [0..5] OF CHAR;


    PROCEDURE WriteByte( B : CHAR );
    BEGIN
        IF (Logging) THEN
            DOSCALL( WriteRecord, LogHandle, 1, ADR(B),
                     XferedBytes, ErrorCode );
            IF (ErrorCode <> 0) OR (XferedBytes < 1) THEN
                CtoS( ErrorCode, s1 );
                SetString(s, "Error writing to LOG:");
                ConcatLS( s, s1 );
                Error(s);
                CloseLog(FALSE);
            END;
        END;
    END WriteByte;


BEGIN
    IF (AlsoToScreen) THEN
        WarningBox( s, Title, NoHelp );
    END;
    IF (Logging) THEN
        WriteByte( 15C );
        WriteByte( 12C );
        IF (ORD(Title[0]) > 0) THEN
            FOR i := 1 TO ORD(Title[0]) DO
                WriteByte( Title[i] );
            END;
            WriteByte( ":" );
            WriteByte( 15C );
            WriteByte( 12C );
        END;
        WriteByte( " " );
        WriteByte( " " );
        FOR i := 1 TO ORD(s[0]) DO
            IF (s[i] = BreakLineDefault) THEN
                WriteByte( 15C );
                WriteByte( 12C );
                WriteByte( " " );
                WriteByte( " " );
            ELSE
                WriteByte( s[i] );
            END;
        END;
    END;
END WriteLog;





PROCEDURE CloseLog( WriteTrailer : BOOLEAN );
VAR
    T         : Time;
    ErrorCode : CARDINAL;
    s, s1     : ARRAY [0..23] OF CHAR;
BEGIN
    IF (Logging) AND (CloseLogInterlock = 0) THEN
        INC(CloseLogInterlock);
        IF (WriteTrailer) THEN
            GetTime( T );
            TimeToString( T, s1 );
            TStringToLString( s1, s );
            SetString(s1, "LOG CLOSED" );
            WriteLog( s, s1, FALSE );
        END;
        IF (Logging) THEN
            DOSCALL( CloseFile, LogHandle, ErrorCode );
        END;
        Logging := FALSE;
        DEC(CloseLogInterlock);
    END;
END CloseLog;






PROCEDURE OpenLog();
VAR
    OHigh, OLow,
    High, Low,
    ErrorCode  : CARDINAL;
    T          : Time;
    s, s1      : ARRAY [0..23] OF CHAR;
BEGIN
    IF (NOT Logging) THEN
          (*  0123456789  *)
        s := "MAGIC.LOG ";
        s[9] := 0C;

        DOSCALL( OpenAFile, ADR( s ), ReadWriteMode + ExclusiveAccessMode, LogHandle, ErrorCode );
        IF (ErrorCode = 2) THEN
            DOSCALL( CreateAFile, ADR( s ), NormalAttribute, LogHandle, ErrorCode );
        ELSIF (ErrorCode = 0) THEN
            DOSCALL( SetPos, LogHandle, 2, 0, 0, High, Low, ErrorCode );
            DOSCALL( SetPos, LogHandle, 0, High, Low, OHigh, OLow, ErrorCode );
        END;
        IF (ErrorCode <> 0) THEN
            CtoS( ErrorCode, s1 );
            SetString(s, "Error opening LOG:");
            ConcatLS( s, s1 );
            Error(s);
            Logging := FALSE;
        ELSE
            Logging := TRUE;
            GetTime( T );
            TimeToString( T, s1 );
            TStringToLString( s1, s );
            SetString(s1, "LOG STARTED" );
            WriteLog( s, s1, FALSE );
        END;
    END;
END OpenLog;




PROCEDURE CheckHeap();
VAR
      a         : BlockPtr;
      Free      : CARDINAL;
      s1        : ARRAY [0..5] OF CHAR;
BEGIN
      a.adr := blockList;
      WHILE a.adr.SEGMENT # 0 DO
          IF (ReportItems < HIGH(Report^)) THEN
              INC(ReportItems);
              WITH Report^[ ReportItems ] DO
                  Addr := a.adr.SEGMENT;
                  Size := a.ptr^.blockParaSize;
                  IF a.ptr^.dynamic THEN
                      INC( a.adr.SEGMENT );
                      Free := CountOfFree(ABlock(a.adr), 16); (* Number of paras *)
                      DEC( a.adr.SEGMENT );
                      SetString(Name, "H(" );
                      CtoS( (Free * 16), s1 );      (* Make into byte count *)
                      ConcatLS( Name, s1 );
                      ConcatS(  Name, ")" );
                  ELSE
                      SetString( Name, "Heap Big" );
                  END;
                  Procustes( Name, 8 );
                  IF (a.adr.OFFSET <> 0) THEN
                      ConcatS(Name, "*");
                      INC( Addr, (a.adr.OFFSET DIV 16));
                  END;
              END;
              a.adr.SEGMENT := a.ptr^.nextBlockSeg
          END;
      END; (* while a # NIL *)

END CheckHeap;




  (* Overlay sizes. *)

PROCEDURE FigureOutSize();
VAR
    FirstOverlay,
    LogitekOverlay : OverlayPtr;
    Done           : BOOLEAN;
    s              : ARRAY [0..79] OF CHAR;

BEGIN
    LogitekOverlay := activProcess^.currOverlay;
    FirstOverlay   := LogitekOverlay;
    Done           := FALSE;

    WHILE (LogitekOverlay <> NIL) AND (NOT Done) DO

        IF (ReportItems < HIGH(Report^)) THEN
            INC(ReportItems);
            WITH Report^[ ReportItems ] DO
                Addr := LogitekOverlay^.memoryAddr.SEGMENT - 1; (* Ajust for 1 para overhead. *)
                Size := LogitekOverlay^.memorySize + 1; (* Paras + overhead. *)
                TStringToLString( LogitekOverlay^.overlayName, s );
                Procustes( s, 8 );
                Copy( s, Name );
                IF (LogitekOverlay^.memoryAddr.OFFSET <> 0) THEN
                    ConcatS(Name, "*");
                    INC( Addr, (LogitekOverlay^.memoryAddr.OFFSET DIV 16));
                END;
            END;
        END;

        LogitekOverlay  := LogitekOverlay^.next;
        IF (FirstOverlay = LogitekOverlay) THEN
            Done := TRUE; (* Stop at end of circular list *)
        END;
    END;
END FigureOutSize;


PROCEDURE PtoS( P : CARDINAL; VAR s:ARRAY OF CHAR );
VAR
    s1 : ARRAY [0..15]   OF CHAR;
    i  : CARDINAL;
BEGIN
    FormatAsAmount( FLOAT(P) * 16.0,
                    DefaultAmountFormat,
                    s1, 9,
                    0,0, TRUE );
    TrimRear( s1 );
    ConcatLS( s, s1 );
END PtoS;




PROCEDURE DisplayAnswer( ToPrinter : BOOLEAN );
VAR
    i,
    Page,
    NSeg,
    ESeg : CARDINAL;
    s1   : ARRAY [0..39]  OF CHAR;
    s2   : ARRAY [0..99]  OF CHAR;
    s    : ARRAY [0..255] OF CHAR;
    WerePrinting : BOOLEAN;

BEGIN
    ESeg  := Report^[1].Addr;

    WerePrinting := Logging;
    IF (ToPrinter) AND (NOT Logging) THEN
        OpenLog();
    END;

    s[0]  := 0C;
    Page  := 0;

    FOR i := 1 TO ReportItems DO

        WITH Report^[ i ] DO

            s2[0] := 0C;
            NSeg  := Addr + Size + 1;  (* End of this item + DOS overhead. *)
            IF    (ESeg < Addr) THEN
                SetString(s2,"**** Free block ");
                PtoS( (Addr - ESeg), s2 );
                ConcatS( s2, " bytes ****ü" );
            ELSIF (ESeg > Addr) THEN
                IF (ESeg >= (Addr+Size)) THEN
                    SetString(s2, "vvvvv CONTAINS vvvvvü" );
                    NSeg := ESeg; (* Don't reset it. *)
                ELSE
                    SetString(s2, "vvvvv OVERLAPS vvvvvü" );
                END;
            END;

            ESeg := NSeg;

            CtoS( Addr, s1 );
            Procustes(s1,6);
            ConcatLS( s2, s1 );
            Procustes( Name, 9 );
            ConcatLS( s2, Name );
            ConcatS(   s2, ":" );
            PtoS( Size,  s2 );
        END;

        IF (ORD(s[0]) + ORD(s2[0]) > 250) THEN
            INC(Page);
            SetString(s1,"Mem Map Page ");
            PtoS( Page, s1 );
            WriteLog(s,s1,(NOT ToPrinter));
            s[0] := 0C;
        END;
        ConcatLS(s,s2);
        ConcatS(s,"ü");
    END;
    IF (s[0] > 0C) THEN
        INC(Page);
        SetString(s2,"Mem Map Page ");
        CtoS( Page, s1 );
        ConcatLS( s2, s1 );
        WriteLog(s,s1,(NOT ToPrinter));
    END;

    IF (ToPrinter) AND (NOT WerePrinting) THEN
        CloseLog(TRUE);
    END;

END DisplayAnswer;




  (* Sort by ascending segments.  Not a fast sort, but effective. *)

PROCEDURE Sort();
VAR
    Item    : AReportItem;
    i,
    Limit   : CARDINAL;
BEGIN

    Limit := ReportItems;

    WHILE (Limit > 1) DO
        FOR i := 1 TO (Limit - 1) DO
            IF (Report^[i].Addr > Report^[Limit].Addr) THEN (* Bigger address? *)
                Item           := Report^[Limit];           (* Swap em *)
                Report^[Limit] := Report^[i];
                Report^[i]     := Item;
            END;
        END;
        DEC(Limit);
    END;

END Sort;



TYPE
    AHolderTreeNode = POINTER TO RECORD
        TheName        : ARRAY [0..29] OF CHAR;
        TheClass       : CARDINAL;
        TheCategory    : AHoldTypeSet;
        TheWhere       : ADDRESS;
        TheSize        : CARDINAL;
    END;




PROCEDURE HolderDoIt(   Name        : ARRAY OF CHAR;
                        Class       : CARDINAL;
                        Category    : AHoldTypeSet;
                        Where       : ADDRESS;
                        Size        : CARDINAL );
VAR
    TreeNode        : ATreeNode;
    HolderTreeNode  : AHolderTreeNode;
BEGIN
    IF (CreateTreeNode( TreeNode )) AND
       (Available( 1024 ))          THEN
        NEW( HolderTreeNode );
        WITH HolderTreeNode^ DO
            Copy( Name,     TheName );
            TheClass    := Class;
            TheCategory := Category;
            TheWhere    := Where;
            TheSize     := Size;
        END;
        TreeNode^.Methods^.SetDataObject( TreeNode, HolderTreeNode );
        HolderTree^.Methods^.AddLast( HolderTree, TreeNode );  (* Last node *)
    END;
END HolderDoIt;




PROCEDURE GetHolderInfo( Node : ATreeNode; VAR s : ARRAY OF CHAR );
VAR
    HolderTreeNode  : AHolderTreeNode;
    s1              : ARRAY [0..7] OF CHAR;
    OneCategory     : AHoldType;
BEGIN
    HolderTreeNode := Node^.Methods^.GetDataObject( Node );
    WITH HolderTreeNode^ DO
        SetString( s, "'" );
        ConcatLS( s, TheName );
        ConcatS(  s, "'" );
        Procustes( s, 15 );
        ConcatS( s, ", class " );
        CtoS( TheClass, s1 );
        ConcatLS( s, s1 );
        ConcatS( s, ", Size " );
        CtoS( TheSize, s1 );
        ConcatLS( s, s1 );
        FOR OneCategory := HoldInConfig TO HoldsLString DO
            IF (OneCategory IN TheCategory) THEN
                CASE OneCategory OF
                    HoldInConfig    :

                        ConcatS( s, ", Config" );

                  | HoldInDataFile  :

                        ConcatS( s, ", Sched" );

                  | HoldTransiently :

                        ConcatS( s, ", Tansient" );

                  | HeapNoOwner :

                        ConcatS( s, ", No Owner" );

                  | HoldsProc   :

                        ConcatS( s, ", PROC" );

                  | HoldsEventProc  :

                        ConcatS( s, ", EVENT" );

                  | HoldsDriver :

                        ConcatS( s, ", DRIVER" );

                  | HoldsNumber :

                        ConcatS( s, ", NUM" );

                  | HoldsAddress    :

                        ConcatS( s, ", ADDR" );

                  | ErrorIfDuplicate    :

                        ConcatS( s, ", Er if Dup" );

                  | AllowDuplicates :

                        ConcatS( s, ", Allow Dups" );

                  | CheckSumStorage :

                        ConcatS( s, ", CHKSUM" );

                  | HoldInFlexStor  :

                        ConcatS( s, ", In FlexStor" );

                  | HoldsLString    :

                        ConcatS( s, ", LString" );

                ELSE
                END;
            END;
        END;
    END;

END GetHolderInfo;





PROCEDURE HolderStuf();
VAR
    TreeNode,
    CursorNode      : ATreeNode;
    HolderTreeNode  : AHolderTreeNode;
    s               : ARRAY [0..99] OF CHAR;
    Title           : ARRAY [0..29] OF CHAR;
    NullString      : ARRAY [0..0] OF CHAR;
BEGIN
    IF (NOT Available(4096))          OR
       (NOT CreateTree( HolderTree )) THEN
        RETURN;
    END;

    ForAllHeldItems( HolderDoIt );

    SetString( Title, " Hold me! " );
    CursorNode := HolderTree^.Methods^.GetFirst( HolderTree );

    IF DoGoTo( HolderTree, 5, 5, 78, maxrow-2, Title,
               TRUE, NullGoToCheckProc, GetHolderInfo, CursorNode) THEN

        IF (CursorNode <> NIL) THEN
            HolderTreeNode := CursorNode^.Methods^.GetDataObject( CursorNode );
            WITH HolderTreeNode^ DO
                SetString( s, "Delete " );
                ConcatLS( s, TheName );
                SetLengthOf(NullString, 0);
                IF ( ContinuationBox (s, NullString, NoHelp) ) THEN
                    DeleteHeldItem( TheName, TheClass );
                END;
            END;
        END;
    END;

    CursorNode := HolderTree^.Methods^.GetFirst( HolderTree );
    WHILE (CursorNode <> NIL) DO
        HolderTreeNode := CursorNode^.Methods^.GetDataObject( CursorNode );
        DISPOSE( HolderTreeNode );
        TreeNode    := CursorNode;
        CursorNode  := CursorNode^.Methods^.NextPreOrder( CursorNode );
        TreeNode^.Methods^.Discard( TreeNode );
    END;
    HolderTree^.Methods^.Discard( HolderTree );

END HolderStuf;






PROCEDURE FlexStor();
VAR
    PageNumber   : CARDINAL;
    Page         : APagePointer;
    A            : ADDRESS;
    S, S1        : ARRAY [0..19] OF CHAR;
BEGIN
    PageNumber := 1;
    WHILE (PageNumber <= MaxPages) DO
        WITH PageTable^[PageNumber] DO
            IF (Valid) AND (ADDRESS(Location) <> NIL) THEN
                CASE StorageClass OF
                    PageFast   : SetString(S,"F(");
                  | PageMedium : SetString(S,"M(");
                  | PageSlow   : SetString(S,"S(");
                END;
                CtoS(FreeBytes,S1);
                ConcatLS(S,S1);
                ConcatS( S,")");

                IF (ReportItems < HIGH(Report^)) THEN INC(ReportItems); END;

                WITH Report^[ ReportItems ] DO
                    A    := ADDRESS(Location);
                    Addr := A.SEGMENT;
                    IF (A.OFFSET >= 16) THEN
                        INC(Addr, (A.OFFSET DIV 16));
                        ConcatS( S, "*" );
                    END;
                    Page := Location;
                    Size := Page^.Header.PageSize DIV 16; (* Make it paras. *)
                    Procustes( S, 8 );
                    Copy( S, Name );
                END;

            END;
        END;
        INC(PageNumber);
    END;
END FlexStor;





PROCEDURE GetCardinal( VAR  s, Title, Prefix : ARRAY OF CHAR ) : CARDINAL;
VAR
    Selection : CARDINAL;
    Answer    : CARDINAL;
    MenuStr   : ARRAY [0..79] OF CHAR;
    s1        : ARRAY [0..7]  OF CHAR;
BEGIN
    SetString(MenuStr,"RESET, Add 1, Add 10, Add 100, Subtract 1, Subtract 10");
    Selection := 2;
    Answer    := 0;

    SetString(s1,"0");
    Message(s1);

    WHILE (MultipleChoiceBox( s, Title, NoHelp, Prefix, MenuStr, Selection )) DO
        CASE Selection OF
          1 : Answer := 0;
        | 2 : INC( Answer );
        | 3 : INC( Answer, 10);
        | 4 : INC( Answer, 100);
        | 5 : IF (Answer > 0)  THEN DEC( Answer );    END;
        | 6 : IF (Answer > 10) THEN DEC( Answer, 10); END;
        END;
        CtoS( Answer, s1 );
        Message(s1);
    END;

    RETURN Answer;

END GetCardinal;





PROCEDURE DoMemory();



    PROCEDURE SumHeap() : CARDINAL;
    VAR
          a         : BlockPtr;
          TotalSize : CARDINAL;
          Free      : CARDINAL;
    BEGIN
        TotalSize := 0;
        a.adr := blockList;
        WHILE a.adr.SEGMENT # 0 DO
            IF a.ptr^.dynamic THEN
                INC( a.adr.SEGMENT );
                Free := CountOfFree(ABlock(a.adr), 16); (* Number of paras *)
                INC( TotalSize, Free );
                DEC( a.adr.SEGMENT );
            END;
            a.adr.SEGMENT := a.ptr^.nextBlockSeg
        END; (* while a # NIL *)

        RETURN TotalSize;

    END SumHeap;




    PROCEDURE CutBackDOS( Leave : CARDINAL );
    CONST
        KPara = 1024 DIV 16;
    VAR
        LastPtr : AMemoryChunkPtr;
        YetToGo : CARDINAL;
    BEGIN
        (* Make Leave into paras. *)
        Leave   := Leave * KPara;
        LastPtr := MemoryChunkList;
        YetToGo := DOSAvail();
        WHILE (YetToGo > Leave) DO
            DOSAlloc( MemoryChunkList, YetToGo - Leave );
            MemoryChunkList^.Prev   := LastPtr;
            MemoryChunkList^.Heap   := FALSE;
            LastPtr                 := MemoryChunkList;
            YetToGo                 := DOSAvail();
        END;
    END CutBackDOS;



    PROCEDURE AllocateAPara( VAR Ptr : ADDRESS ) : BOOLEAN;
    VAR
          a         : BlockPtr;
          Free      : CARDINAL;
    BEGIN
        a.adr := blockList;
        WHILE a.adr.SEGMENT # 0 DO
            IF a.ptr^.dynamic THEN
                INC( a.adr.SEGMENT );
                Free := CountOfFree(ABlock(a.adr), 16); (* Number of paras *)
                IF (Free > 1) THEN
                    Alloc( a.adr, Ptr, 16 );
                    RETURN TRUE;
                END;
                DEC( a.adr.SEGMENT );
            END;
            a.adr.SEGMENT := a.ptr^.nextBlockSeg
        END; (* while a # NIL *)
        RETURN FALSE;

    END AllocateAPara;



    PROCEDURE CutBackHEAP( Leave : CARDINAL );
    CONST
        KPara = 1024 DIV 16;
    VAR
        LastPtr : AMemoryChunkPtr;
        YetToGo : CARDINAL;
    BEGIN
        (* Make Leave into paras. *)
        Leave   := Leave * KPara;
        LastPtr := MemoryChunkList;
        YetToGo := SumHeap();
        WHILE (YetToGo > Leave) AND
              (AllocateAPara( MemoryChunkList )) DO
            MemoryChunkList^.Prev   := LastPtr;
            MemoryChunkList^.Heap   := TRUE;
            LastPtr                 := MemoryChunkList;
            YetToGo                 := SumHeap();
        END;
    END CutBackHEAP;




    PROCEDURE FreeUpSpace();
    VAR
        PrevPtr : AMemoryChunkPtr;
    BEGIN
        WHILE (MemoryChunkList <> NIL) DO
            PrevPtr := MemoryChunkList^.Prev;
            IF (MemoryChunkList^.Heap) THEN
                DEALLOCATE( MemoryChunkList, 16 ); (* One para at a time *)
            ELSE
                DOSDeAlloc( MemoryChunkList, 0 );
            END;
            MemoryChunkList := PrevPtr;
        END;
    END FreeUpSpace;




    PROCEDURE NextOption() : BOOLEAN;
    CONST
        KPara = 1024 DIV 16;
    VAR
        i,
        Selection     : CARDINAL;
        CutBackTo     : CARDINAL;
        s             : ARRAY [0..159] OF CHAR;
        s1            : ARRAY [0..19] OF CHAR;
        MenuStr       : ARRAY [0..99] OF CHAR;
        Title, Prefix : ARRAY [0..15] OF CHAR;
    BEGIN
        SetString(s, "Memory Options (Send low mem first?):üTOTAL Heap Avail Paras:" );
        i := SumHeap();
        CtoS( i, s1 );
        ConcatLS( s, s1 );

        ConcatS( s, " or, in KB:" );
        CtoS( i DIV KPara, s1 );
        ConcatLS( s, s1 );

        ConcatS(  s, "üMAX DOS Avail Paras:" );
        i := DOSAvail();
        CtoS( i, s1 );
        ConcatLS( s, s1 );

        ConcatS( s, " or, in KB:" );
        CtoS( i DIV KPara, s1 );
        ConcatLS( s, s1 );

        SetString(Title, " Remember ... ");
        SetString(Prefix,"Please do");
        SetString(MenuStr,"Memory Map,Print Memory Map,Free Up Space,DOS Reduce to ...,HEAP Reduce to ...");
        Selection := 1;

        IF (MultipleChoiceBox( s, Title, NoHelp, Prefix, MenuStr, Selection )) THEN
            IF (Selection > 3) THEN
                SetString(s,"Cut back to:");
                SetString(Title, "Pick a number");
                SetString(Prefix,"Cut down to");

                CutBackTo := GetCardinal( s, Title, Prefix );

            END;

            CASE Selection OF
               1, 2 : 
                   IF (Available(SIZE(Report))) THEN
                       ReportItems := 0;

                       NEW(Report);
                       CheckHeap();       (* Heap     *)
                       FigureOutSize();   (* Overlays *)
                       FlexStor();        (* Flex stor *)

                       Sort();

                       DisplayAnswer( (Selection = 2 ) );
                       DISPOSE(Report);
                   END;

             | 3 : FreeUpSpace();
             | 4 : CutBackDOS(  CutBackTo );
             | 5 : CutBackHEAP( CutBackTo );
            END;
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END;
    END NextOption;

BEGIN

    WHILE (NextOption()) DO END;

END DoMemory;









PROCEDURE RugsReport();
VAR
   s, s1 : ARRAY [0..99] OF CHAR;
BEGIN

    SetString(s, "Rugs in use now (not including this one):" );
    CtoS( RugsInUse, s1 );
    ConcatLS(s,s1);
    ConcatS( s, ".  Bytes in use by those rugs:" );
    CtoS( RugBytes, s1 );
    ConcatLS( s,s1 );

    SetString(s1, " Bugs in Rugs? " );
    WriteLog( s, s1, TRUE );

END RugsReport;






PROCEDURE CountATask( VAR Node : ATreeNode; PtrORama : ADDRESS );
VAR
    TaskCount : POINTER TO CARDINAL;
BEGIN
    TaskCount := PtrORama;
    INC(TaskCount^);
END CountATask;






PROCEDURE CountTasks();
VAR
    TaskCount : CARDINAL;
    s, s1     : ARRAY [0..29] OF CHAR;
BEGIN
    TaskTree^.Methods^.TraverseTree( TaskTree, ParentBeforeChild, 9999,
                                     CountATask, ADR(TaskCount) );
    SetString(s,"Tasks in schedule:");
    CtoS( TaskCount, s1 );
    ConcatLS( s,s1 );
    SetString(s1,"Task Count" );
    WriteLog(s,s1,TRUE);
END CountTasks;





    (*  For use by SwapF via notices call.... *)

PROCEDURE EnoughFree() : BOOLEAN;

BEGIN                       (* EnoughFree *)

    RETURN FALSE;  (* We can NEVER get enough memory! *)

END EnoughFree;




  (* Get Overlay Info.

        Called from within GoTo and locally in "Print Overlays", this
        procedure takes an OverlayNode and returns a printable string
        with the relevant information.

        VERSION 3.0 KLUGE:

            Overlays.Mod does not export the record type that we need to
            reference OverlayContext's.  Here we "borrow" an exported
            variable and put it back when we are done.  This is, of course
            extremely dangerous and un-orthodox.  FIX FOR 4.0!!
  *)
PROCEDURE GetOverlayInfo( OverlayNode : ATreeNode; VAR s : ARRAY OF CHAR );
CONST
    SpacesPerLevel         = 3;
    MaxLevels              = 3;  (* 0..3 *)
    MaxSpaces              = SpacesPerLevel * MaxLevels;
VAR
    OverlayContext         : AContextListEntry;
    Spaces                 : CARDINAL;
    s1                     : ARRAY [0..MaxSpaces] OF CHAR;
    Dammit                 : BOOLEAN;
BEGIN
    OverlayContext := OverlayNode^.Methods^.GetDataObject( OverlayNode );
    WITH OverlayContext^ DO
        Copy( OverlayName, s );
        IF (s[1] = "\") OR (s[1] = "|") THEN
            Remove(s,1,1);
        END;
        Dammit := FALSE;
        IF (s[0] = "!") THEN
            Dammit := TRUE;
            Remove(s,1,1);
        END;
        Procustes(s,9); (* Len(Filename) + 1 blank *)
        Spaces := OverlayNode^.Methods^.IndentationLevel( OverlayNode ) * SpacesPerLevel;
        IF (Spaces >  MaxSpaces) THEN
            Spaces := MaxSpaces;
        END;
        Fill(s1, " ", MaxSpaces - Spaces );
        ConcatLS(s,s1);
        ConcatS( s, "Users:" );
        CtoS( UseCount, s1 );
        ConcatLS( s, s1 );
        IF (LoadOption = LoadInMomArea) THEN
            ConcatS( s, " MOM,  Paras:");
        ELSIF (LoadOption = LoadInKidArea) THEN
            ConcatS( s, " KID,  Paras:");
        ELSE
            ConcatS( s, " HEAP, Paras:");
        END;
        CtoS( OverlaySize, s1 );
        Procustes(   s1, 5 );
        RJust(       s1 );
        ConcatLS( s, s1 );
        IF (Residence = InMainMemory) THEN
            IF (WantsResidence) THEN
                ConcatS( s, ", Resident " );
            ELSIF (IsLocked) THEN
                ConcatS( s, ", LOCKED!! " );
            ELSE
                ConcatS( s, ", Dynamic  " );
            END;
        ELSIF (Residence = InXms) THEN
            ConcatS( s, ", SWAP:XMS " );
        ELSIF (Residence = InEms) THEN
            ConcatS( s, ", SWAP:EMS " );
        ELSIF (Residence = InFlexStor) THEN
            ConcatS( s, ", SWAP:FLX " );
        ELSE
            ConcatS( s, ", SWAP:??? " );
        END;
        IF (Dammit) THEN
            ConcatS(s,"!");
        END;
        CASE ResidentWhere.Residence OF
            InMainMemory:
          | InXms:        ConcatS(s, "Res:XMS" );
          | InEms:        ConcatS(s, "Res:EMS" );
          | InFlexStor:   ConcatS(s, "Res:FLX" );
        ELSE
                          ConcatS(s, "Res:???" );
        END;
    END;
END GetOverlayInfo;






PROCEDURE PrintOverlays( OverlayTree : ATree );
VAR
    Node           : ATreeNode;
    OverlayContext : AContextListEntry;
    s              : ARRAY [0..80] OF CHAR;
    s1             : ARRAY [0..39] OF CHAR;
    Title          : ARRAY [0..0]  OF CHAR;
BEGIN
    Title[0] := 0C;  (* No title. *)
    Node := OverlayTree^.Methods^.GetFirst( OverlayTree );
    WHILE (Node <> NIL) DO
        GetOverlayInfo( Node, s );
        Fill(s1," ", Node^.Methods^.IndentationLevel( Node ) * 2 );
        Insert( s, s1, 1 );
        WriteLog( s, Title, FALSE );
        OverlayContext := Node^.Methods^.GetDataObject( Node );
        WITH OverlayContext^ DO
            Copy(OverlayName,s);
            ConcatS(  s, "/" );
            ConcatLS( s, CallChain );
            Insert( s, s1, 1 );
            WriteLog( s, Title, FALSE );
        END;
        Node := Node^.Methods^.NextPreOrder( Node );
    END;
END PrintOverlays;







PROCEDURE OvSizes();
CONST
    OvModuleNumber  = 2700;
VAR
    i,j,
    Largest  : CARDINAL;
    s,
    Mask     : ARRAY [0..199] OF CHAR;
    s1       : ARRAY [0..19]  OF CHAR;

    PROCEDURE GatherReport( VAR Name : ARRAY OF CHAR );
    VAR
        FileName    : ARRAY [0..199] OF CHAR;
        Size,
        Handle      : CARDINAL;
    BEGIN

        Copy(Name, FileName );
        ConcatS(   FileName, ".OVL" );
        IF (NOT OpenOverlay( FileName, Handle )) THEN
            Insert(FileName, Mask, 1);
            IF (NOT OpenOverlay( FileName, Handle )) THEN
                Error( FileName );
                RETURN;
            END;
        END;

        Size := DetermineOverlaySize();
        CloseOverlay();
        INC(ReportItems);
        Copy( Name, Report^[ReportItems].Name );
        Report^[ReportItems].Size := Size;
        IF (Largest <  Size) THEN
            Largest := Size;
        END;

    END GatherReport;


    PROCEDURE PrintReport( Why : ARRAY OF CHAR );
    VAR
        i        : CARDINAL;
        Text     : ARRAY [0..199] OF CHAR;
        Title    : ARRAY [0..99] OF CHAR;
        LocalLog : BOOLEAN;
    BEGIN
        LocalLog := Logging;
        IF (NOT LocalLog) THEN
            OpenLog();
        END;

        SetLengthOf( Title, 0 );
        SetString( Text, Why );
        WriteLog( Text, Title, FALSE );

        FOR i := 1 TO ReportItems DO
            Copy( Report^[i].Name, Text );
            Procustes( Text, 11 );
            PtoS( Report^[i].Size, Text );
            IF (Report^[i].Size = Largest) THEN
                ConcatS(Text," <== LARGEST" );
            ELSIF (Report^[i].Size > (Largest - (Largest DIV 10))) THEN
                ConcatS(Text," <-- within 10% of largest" );
            END;
            WriteLog( Text, Title, FALSE );
        END;

        SetString( Text, "Largest overlay for this layer is " );
        CtoS(Largest,Title);
        ConcatLS( Text, Title );
        SetLengthOf( Title, 0 );
        WriteLog( Text, Title, FALSE );

        IF (NOT LocalLog) THEN
            CloseLog( TRUE );
        END;

    END PrintReport;

    PROCEDURE FileSort();
    VAR
        Item    : AReportItem;
        i,
        Limit   : CARDINAL;
    BEGIN

        Limit := ReportItems;

        WHILE (Limit > 1) DO
            FOR i := 1 TO (Limit - 1) DO
                IF (Compare(Report^[i].Name, Report^[Limit].Name) > 0) THEN
                    Item           := Report^[Limit];           (* Swap em *)
                    Report^[Limit] := Report^[i];
                    Report^[i]     := Item;
                END;
            END;
            DEC(Limit);
        END;

    END FileSort;


    PROCEDURE DoOneMsg();
    BEGIN
        j := 1;
        WordNumber(s,j,s1);
        WHILE (LengthOf(s1) > 0) DO
            GatherReport(s1);
            INC(j);
            WordNumber(s,j,s1);
        END;
    END DoOneMsg;


BEGIN
    IF (NOT Available(SIZE(Report))) THEN
        RETURN;
    END;

    Copy( EXEPath, Mask );
    ConcatS( Mask, "PROGRAMS\" );
    NEW(Report);

    ReportItems := 0;
    Largest     := 0;

    i := OvModuleNumber + 80;
    GetMessage( i, s );
    DoOneMsg();
    FileSort();
    PrintReport("Mom Layer:");

    ReportItems := 0;
    Largest     := 0;

    i := OvModuleNumber + 81;
    GetMessage( i, s );
    WHILE (i < (OvModuleNumber + 99)) AND (LengthOf(s) > 0) DO
        DoOneMsg();
        INC(i);
        GetMessage( i, s );
    END;

    FileSort();
    PrintReport("Kid Layer:");

    DISPOSE(Report);

END OvSizes;







PROCEDURE DoMenu() : BOOLEAN;
VAR  s             : ARRAY [0..255] OF CHAR;
     MenuStr       : ARRAY [0..99]  OF CHAR;
     Title, Prefix : ARRAY [0..21]  OF CHAR;
     s1            : ARRAY [0..21]  OF CHAR;
     Selection     : CARDINAL;


     PROCEDURE Gas();  
     VAR
         Stack           : CARDINAL;
         j               : APageClass;
         s1              : ARRAY [0..99]    OF CHAR;
     BEGIN
         Selection := 1;
         SetString(s, "Total heap items:");
         CtoS( HeapItems, s1 );
         ConcatLS( s, s1 );
         ConcatS(s,", Total size:" );
         FormatAsAmount( GSize, DefaultAmountFormat, s1, 9,0,0,FALSE );
         TrimRear( s1 );
         ConcatLS( s, s1 );
         ConcatS(s,".  DOS left:");
         i := (DOSAvail() + 32) DIV 64; (* round.  DOSAvail() returns paras *)
         CtoS( i, s1 );
         ConcatLS( s, s1 );
         ConcatS(s,"KB.  Low-Mem notices:");
         CtoS( NoticeCount[ LowMemory ], s1 );
         ConcatLS( s, s1 );
         ConcatS(s,".");
         SetString(Title, "Memory in a Heap?");
         WriteLog( s, Title, TRUE );

     END Gas;  



    PROCEDURE DebugUndo();
    VAR
        Node                : ATreeNode;
        ThisTree            : ATree;
        s2                  : ARRAY [0..10] OF CHAR;

        PROCEDURE TopLevelCount (Tree : ATree) : CARDINAL;
        VAR
            Node        : ATreeNode;
            Count       : CARDINAL;
        BEGIN
            Count := 0;
            Node := Tree^.Methods^.GetFirst (Tree);
            WHILE (Node <> NIL) DO
                INC (Count);
                Node := Node^.Methods^.GetNext (Node);
            END;
            RETURN Count;
        END TopLevelCount;


    BEGIN

        SetString (s, "Undos: ");
        CtoS (TopLevelCount (UndoTree), s2);
        ConcatLS (s, s2);
        ConcatS (s, "    Redos: ");
        CtoS (TopLevelCount (RedoTree), s2);
        ConcatLS (s, s2);
        SetString (Title, "Undo debugger");
        SetString (Prefix, "Which tree?");
        SetString (MenuStr, "Undo tree,Redo tree,Quit");
        Selection := 1;
        IF (NOT MultipleChoiceBox(s, Title, NoHelp, Prefix, MenuStr, Selection)) THEN
            RETURN;
        END;
        IF (Selection = 3) THEN
            RETURN;
        END;
        IF (Selection = 1) THEN
            ThisTree := UndoTree;
        ELSE
            ThisTree := RedoTree;
        END;

        Node := ThisTree^.Methods^.GetFirst (ThisTree);
        SetString (Title, "Transaction list");
        IF DoGoTo (ThisTree, 40, 6, 75, maxrow-7, Title,
            TRUE, NullGoToCheckProc, GetUndoInfo, Node) THEN END;
    END DebugUndo;


    (* Show the overlay tree.  NOTE THAT THIS CALLS THE KLUGES MODULE TO
       GET THE OVERLAY TREE. THIS SHOULD BE CLEANED UP IN 4.0 SO THAT THE
       OVERLAY TREE IS EXPORTED FROM OVERLAYS.
    *)
    PROCEDURE ShowOverlays();
    VAR
        OverlayContext      : AContextListEntry;
        Node                : ATreeNode;
        ok                  : BOOLEAN;
    BEGIN
        Node := OverlayTree^.Methods^.GetFirst( OverlayTree );
        SetString (Title, "Overlay List");
        IF DoGoTo( OverlayTree, 5, 5, 78, maxrow-2, Title,
                   TRUE, NullGoToCheckProc, GetOverlayInfo, Node) THEN
            OverlayContext := Node^.Methods^.GetDataObject( Node );
            WITH OverlayContext^ DO
                Error(CallChain);
            END;
        END;
        IF (Logging) THEN
            PrintOverlays( OverlayTree );
        END;
    END ShowOverlays;




    PROCEDURE SendLowMemNotice();
    VAR
        i          : CARDINAL;
        Avail      : CARDINAL;
        StartTime,
        EndTime    : Time;
        ElapsedTime: REAL;
        s1         : ARRAY [0..12] OF CHAR;
    BEGIN
        Avail := 0;
        SendNotices(LowMemory, BeforeActing, ADR(Avail));
        SetString(s,"Claimed free-uppable KB before notice:");
        CtoS( Avail, s1 );
        ConcatLS( s, s1 );
        ConcatS(s,".üDOS memory avail before notice:");
        i := (DOSAvail() + 32) DIV 64; (* round.  DOSAvail() returns paras *)
        CtoS( i, s1 );
        ConcatLS( s, s1 );
        ConcatS(s, "KB.üTime for notice:");
        GetTime( StartTime );
        SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));
        GetTime( EndTime );
        ElapsedTime := ((FLOAT(   EndTime.minute ) * 60000.0) + FLOAT(   EndTime.millisec ))
                     - ((FLOAT( StartTime.minute ) * 60000.0) + FLOAT( StartTime.millisec ));
        FormatAsAmount( ElapsedTime, DefaultAmountFormat, s1, 9,0,0,FALSE );
        ConcatLS( s, s1 );
        i := (DOSAvail() + 32) DIV 64; (* round.  DOSAvail() returns paras *)
        CtoS( i, s1 );
        ConcatS(s,"ms.üDOS memory avail after notice:");
        ConcatLS( s, s1 );
        SetString(s1,"Send Low Mem" );
        WriteLog(s,s1,TRUE);
    END SendLowMemNotice;



    PROCEDURE SpyOnHeap();
    BEGIN

        SetString(s,"Heap SPY:");
        IF (WatchingForSize) THEN
            IF (SizeToWatchFor = 0) THEN
                ConcatS(s, " Now trapping ALL HEAP requests." );
            ELSE
                ConcatS(s, " Now trapping HEAP requests of " );
                CtoS( SizeToWatchFor, s1 );
                ConcatLS( s, s1 );
                ConcatS(s, " bytes." );
            END;
        ELSE
            ConcatS( s, " Heap spying is not armed.");
        END;
        SetString(Title, "Heap Big Trouble, Boy");
        SetString(Prefix,"Please");
        SetString(MenuStr,"Trap ALL Heap requests,Watch for a size,Reset");
        Selection := 1;

        IF (MultipleChoiceBox( s, Title, NoHelp, Prefix, MenuStr, Selection )) THEN
            CASE Selection OF
               1 :
                    WatchingForSize := TRUE;
                    SizeToWatchFor  := 0;
             | 2 : 
                    SetString(s,"Watch for (0=ALL):");
                    SetString(Title, "Pick a number");
                    SetString(Prefix,"Watch for");
                    SizeToWatchFor  := GetCardinal( s, Title, Prefix );
                    WatchingForSize := TRUE;
             | 3 :
                    WatchingForSize := FALSE;
            END;
        END;

    END SpyOnHeap;


    PROCEDURE Switches();

        PROCEDURE AddString( Switch : BOOLEAN; Name : ARRAY OF CHAR );
        BEGIN
            ConcatS( MenuStr, Name );
            ConcatS( MenuStr, "," );

            ConcatS( s, Name );
            IF (Switch) THEN
                ConcatS( s, ":ON" );
            ELSE
                ConcatS( s, ":OFF" );
            END;
            ConcatS( s, "; " );
        END AddString;

    BEGIN
        Selection  := 1;
        MenuStr[0] := 0C;
        SetString(s, "Switches:" );

        AddString( CheckStackActive, "Stack"   );
        AddString( WatchForNotices,  "Notices" );
        AddString( Logging,          "Logging" );

        SetString(Title, "Watchers/Doers");
        SetString(Prefix,"Toggle");

        IF (MultipleChoiceBox( s, Title, NoHelp, Prefix, MenuStr, Selection )) THEN
            INC(MagicModeLevel, 1000);
            CASE Selection OF
               1 : IF (CheckStackActive) THEN
                       RemoveLight( StackLight );
                   ELSE
                       InstallLight( ActiveLightRegion, 240, 10, 10, StackLight );
                   END;
                   CheckStackActive := (NOT CheckStackActive);

             | 2 : IF (WatchForNotices) THEN
                       RemoveLight( NoticeLight );
                   ELSE
                       InstallLight( ActiveLightRegion, 240,  5, 20, NoticeLight );
                   END;
                   WatchForNotices  := (NOT WatchForNotices);

             | 3 : IF (Logging) THEN
                       CloseLog(TRUE);
                   ELSE
                       OpenLog();
                   END;
            ELSE
                FatalError();
            END;
            DEC(MagicModeLevel, 1000);
        END;
    END Switches;


BEGIN
    Selection := 1;
    SetString(s, "Magic Mode!  Welcome backstage at the Time Line theatre!" );
    SetString(Title, " Yes master, I obey ");
    SetString(Prefix,"Logging is O");
    IF (Logging) THEN
        ConcatS( Prefix, "N" );
    ELSE
        ConcatS( Prefix, "FF" );
    END;
    SetString(MenuStr,"FlexStor,Rugs,Gas,Absorb,Undo,Count,Overlays,Low Mem Ntc,Heap Spy,Switches,Holder,KB for overlays");

    CheckStack();
(*    IF (FirstTime) THEN*)
(*        FirstTime := FALSE;*)
(*        TestMenus();*)
(*        InstallNewProcedure( ADR(CreatePage), PROC(XCreatePage), ADR(OldCreatePage) );*)
(*    END;*)

    IF (MultipleChoiceBox( s, Title, NoHelp, Prefix, MenuStr, Selection )) THEN
        CASE Selection OF
           1 : Selection := DiagnosticHook( 3 );   (* FlexStorage *)
         | 2 : RugsReport();
         | 3 : Gas();
         | 4 : DoMemory();
         | 5 : DebugUndo();
         | 6 : CountTasks();
         | 7 : ShowOverlays();
         | 8 : SendLowMemNotice();
         | 9 : SpyOnHeap();
         | 10: Switches();
         | 11: HolderStuf();
         | 12: OvSizes();
        ELSE
            FatalError();
        END;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END DoMenu;




 (* Check the stack frequently. *)
PROCEDURE CheckStack();
CONST
    MaxStack              = 13000;  (* Start recording at this point *)
    MaxStackBars          = 10;
    StackBarIncrement     = MaxStack DIV MaxStackBars;
    HalfStackBarIncrement = StackBarIncrement DIV 2;
    StackGoLiveAnyway     = 7 * 1024;  (* Less than this we display anyway. *)
    UnusedStack           = 15000 - MaxStack; (* "Real Stack" - "Tracked Stack" *)
VAR
    X      : CARDINAL;
    s      : ARRAY [0..MaxStackBars] OF CHAR;
BEGIN

    GETREG(SP, X);
    IF (MagicModeLevel < 1000) AND
       (CheckStackActive) (* *** OR (X < StackGoLiveAnyway) ***** *) THEN
        IF (X > UnusedStack) THEN
            DEC(X,UnusedStack);
        END;
        IF (X >  MaxStack) THEN
            X := MaxStack;
        END;
        X := (X + HalfStackBarIncrement) DIV StackBarIncrement;
        IF (X >  MaxStackBars) THEN
            X := MaxStackBars;
        END;
        X := MaxStackBars - X;

        IF (X <> LastLightBarSize) THEN
            LastLightBarSize := X;
            Fill( s, "°", MaxStackBars ); (* CHR(176) *)
            WHILE (X > 0) DO
                s[X] := "²";
                DEC(X);
            END;

            EnableLights( TRUE );
            DisplayLight( StackLight, s, videobright );
        END;

    END;

END CheckStack;






  (* Monitor All Notices. *)

PROCEDURE NoticeCatcher( Occasion : AnOccasion;
                         Step     : AStep;
                         Context  : ADDRESS ) : BOOLEAN;
VAR
    s1     : ARRAY [0..5]  OF CHAR;
    s      : ARRAY [0..45] OF CHAR; (* Add a little fudge. *)
BEGIN
    INC(MagicModeLevel);
    INC(NoticeCount[ Occasion ]);

    IF (WatchForNotices) AND (MagicModeLevel < 1000) THEN

        CASE Step OF
            RequestPermission : SetString( s, "RQ:" );
          | BeforeActing      : SetString( s, "BE:" );
          | AfterActing       : SetString( s, "AF:" );
          | FailureToAct      : SetString( s, "FA:" );
        ELSE
            CtoS( ORD(Step), s );
        END;

        CASE Occasion OF
           ProgramStart             : ConcatS( s, "ProgStart" );
         | ProgramQuit              : ConcatS( s, "ProgQuit" );
         | ProgramEnd               : ConcatS( s, "ProgEnd" );
         | ModelLoad                : ConcatS( s, "ModelLoad" );
         | ModelErase               : ConcatS( s, "ModelErase" );
         | ModelSave                : ConcatS( s, "ModelSave" );
         | ConfigLoad               : ConcatS( s, "ConfigLoad" );
         | ConfigErase              : ConcatS( s, "ConfigErase" );
         | ConfigSave               : ConcatS( s, "ConfigSave" );
         | DiskFileErase            : ConcatS( s, "FileErase" );
         | EMSLowMemory             : ConcatS( s, "EMS Low" );
         | LowMemory                : ConcatS( s, "Low Memory" );
         | QueryMemoryStatus        : ConcatS( s, "Query Mem" );
         | ScheduleCompute          : ConcatS( s, "SchedCompute" );
         | ScheduleSort             : ConcatS( s, "SchedSort" );
         | ScheduleFilter           : ConcatS( s, "SchedFilter" );
         | DisplayFormatChanged     : ConcatS( s, "DispFormat" );
         | WarningActive            : ConcatS( s, "WarnActive" );
         | FormActive               : ConcatS( s, "FormActive" );
         | MenuActive               : ConcatS( s, "MenuActive" );
         | PickListActive           : ConcatS( s, "ListActive" );
         | DialogActive             : ConcatS( s, "DialogActive" );
         | OverlayCall              : ConcatS( s, "OverlayCall" );
         | OverlayActive            : ConcatS( s, "OverlayActive" );
         | TakeCursorControl        : ConcatS( s, "TakeControl" );
         | ReturnCursorControl      : ConcatS( s, "ReturnControl" );
         | KeyForAltView            : ConcatS( s, "KeyForAltView" );
         | ExitToDOS                : ConcatS( s, "ExitToDOS" );
         | AddATask                 : ConcatS( s, "AddATask" );
         | DeleteATask              : ConcatS( s, "DeleteATask" );
         | ChangeATask              : ConcatS( s, "ChangeATask" );
         | MoveATask                : ConcatS( s, "MoveATask" );
         | OpenATask                : ConcatS( s, "OpenATask" );
         | CloseATask               : ConcatS( s, "CloseATask" );
         | AddAResource             : ConcatS( s, "AddAResource" );
         | DeleteAResource          : ConcatS( s, "DeleteAResource" );
         | ChangeAResource          : ConcatS( s, "ChangeAResource" );
         | AddAnEdge                : ConcatS( s, "AddAnEdge" );
         | DeleteAnEdge             : ConcatS( s, "DeleteAnEdge" );
         | ChangeAnEdge             : ConcatS( s, "ChangeAnEdge" );
         | NetworkSettingChange     : ConcatS( s, "Net Set Chng" );
         | VideoSetupChange         : ConcatS( s, "Video Change" );
         | GanttLayoutChange        : ConcatS( s, "Layout Change" );
         | FilterChange             : ConcatS( s, "Filter Change" );
         | CalendarChange           : ConcatS( s, "Cal Change" );
         | MiscSetupChange          : ConcatS( s, "Misc Set Chng" );

        ELSE
            CtoS( ORD(Occasion), s1 );
            ConcatS(  s, "?? " );
            ConcatLS( s, s1 );
        END;

        CtoS( NoticeCount[ Occasion ], s1 );
        ConcatS( s, ":" );
        ConcatLS( s, s1 );
        s1[0] := 0C; (* No Title *)
        WriteLog( s, s1, FALSE );

        DisplayLight( NoticeLight, s, videobright );

    END;

    CheckStack();           (* Lights are enabled and displayed here too. *)
    DEC(MagicModeLevel);

    RETURN TRUE;

END NoticeCatcher;



PROCEDURE AllocCheck( Which : ARRAY OF CHAR; size : CARDINAL );
VAR
    Code    : ACode;
    s, s1   : ARRAY [0..19] OF CHAR;
BEGIN
   CheckStack();
   IF (MagicModeLevel = 0) AND
      (WatchingForSize) AND
      ((size = SizeToWatchFor) OR
       (SizeToWatchFor = 0))   THEN
       INC(MagicModeLevel);
       Tone( 2000, 6 );
       SetString(s, Which);
       CtoS( size, s1 );
       ConcatLS(s,s1);
       Error(s);
       DEC(MagicModeLevel);
   END;
END AllocCheck;







PROCEDURE XALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
(*$R-*)
   INC( HeapItems );
(*$R=*)
   GSize := GSize + FLOAT( size );
   AllocCheck( "Alloc:", size );

   OldALLOCATE( A, size );  (* 02-Oct-89 WKH *)

END XALLOCATE;


PROCEDURE XDEALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
(*$R-*)
    DEC( HeapItems );
(*$R=*)
    GSize := GSize - FLOAT( size );
    AllocCheck( "DeAlloc:", size );
    OldDEALLOCATE( A, size );  (* 02-Oct-89 WKH *)
END XDEALLOCATE;





PROCEDURE XCreatePage (     PageClass     : APageClass;
                            PageNo        : CARDINAL;
                        VAR Size          : CARDINAL     ) : BOOLEAN;
CONST
    OurPageClass            = PageFast;
VAR
    s       : ARRAY [0..99] OF CHAR;
BEGIN

    IF (PageClass = OurPageClass) AND (MagicModeLevel = 0) THEN
        INC(MagicModeLevel);
        SetString(s, "My GOD!  Someone is creating a FAST FlexPage!!");
        Error(s);
        DEC(MagicModeLevel);
    END;

    RETURN (OldCreatePage(PageClass, PageNo, Size ));

END XCreatePage;





PROCEDURE InitTLMagic();
VAR
    i : AnOccasion;
    j : APageClass;
BEGIN
    DisplayNotices    := FALSE;
    MemoryChunkList   := NIL;
    SizeToWatchFor    := 0;
    WatchingForSize   := FALSE;
    MagicModeLevel    := 0;
    Logging           := FALSE;
    CloseLogInterlock := 0;
    CheckStackActive  := FALSE;
    WatchForNotices   := FALSE;
    LastLightBarSize  := 0;
    FirstTime         := TRUE;

    FOR i := MIN(AnOccasion) TO MAX(AnOccasion) DO
        NoticeCount[i]  := 0;
    END;

    (* Install our keystroke handler into the keystroke handling chain.
    *)
    InstallNewProcedure(ADR(Keyboard.GetAnyCode),PROC(OurGetCode), ADR(OldGetCode));

    RegisterForNotices( AllOccasions, NoticeCatcher );
    HeapItems      := 0;
    GSize          := Zero;

    InstallNewProcedure( ADR(ALLOCATE),  PROC(XALLOCATE),  ADR(OldALLOCATE));
    InstallNewProcedure( ADR(DEALLOCATE),PROC(XDEALLOCATE),ADR(OldDEALLOCATE));

(*
    InstallNewProcedure( ADR(CreateExtObjectWithSize),PROC(XCreateExtObjectWithSize),ADR(OldCreateExtObjectWithSize));
    InstallNewProcedure( ADR(DiscardExtObject),PROC(XDiscardExtObject),ADR(OldDiscardExtObject));
    InstallNewProcedure( ADR(LockObject),PROC(XLockObject),ADR(OldLockObject));
    InstallNewProcedure( ADR(ReleaseObject),PROC(XReleaseObject),ADR(OldReleaseObject));
    InstallNewProcedure( ADR(ReleaseUnchangedObject),PROC(XReleaseUnchangedObject),ADR(OldReleaseUnchangedObject));
*)
END InitTLMagic;


PROCEDURE ShutDown();
BEGIN
    CheckStackActive  := FALSE;  (* Disarm stack checking. *)
    WatchForNotices   := FALSE;  (* And notice watching.   *)
    CloseLog(TRUE);  (* Insure that the log file closes. *)
END ShutDown;


MODULE MenuMod;
IMPORT AnItem, SetString, AddMenuItem, Dispatch;
EXPORT TestMenus;

PROCEDURE TestMenus();
VAR
    Item        : AnItem;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    WITH Item DO
        SetString( Class, "UTILITIES" );
        SetString( ItemName, "Mail" );
        SetString( ActionString, ">TLDOS(XMSCHECK)" );
        SetString( Description, "Never, never pick this menu item!" );
        Key          := 254;
        DispatchProc := Dispatch;
    END;
    AddMenuItem( Item, 1 );
END TestMenus;

END MenuMod;


BEGIN

    InitTLMagic();  (* Initialize. *)

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );

END TLMagic.
