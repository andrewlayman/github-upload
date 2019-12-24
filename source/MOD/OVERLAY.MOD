(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module  :    Overlay, SubPrograms and ResidentOverlay manager        *)
(*                                                                            *)
(*       Release :    3.0 - July 87                                           *)
(*                                                                            *)
(*       Copyright (C)  1987 Logitech, All rights reserved                    *)
(*                                                                            *)
(*       Permission is hereby granted to registered users to use or abstract  *)
(*       the following program in the implementation of customized versions.  *)
(*       This permission does not include the right to redistribute the       *)
(*       source code of this program.                                         *)
(*                                                                            *)
(*       MODIFICATION HISTORY                                                 *)
(*                                                                            *)
(*       16-Dec-87 LAA  Fixed a bug in GetBlock, where after a failed call to *)
(*                      NewLayer, if dereferences the layer pointer anyway.   *)
(*       29-Dec-87 LAA  Overlays are opened in shared, read-only mode now so  *)
(*                      more than one process can have the same overlay open  *)
(*                      at a time (for networks).                             *)
(*       18-Feb-88 RSC  removed code to save space.  Allow 'DK:' as a drive.  *)
(*       10-Mar-88 RSC  check for errors on ReadBytes.  If OPEN fails,        *)
(*                      return FALSE.  not doing so caused machine lock up.   *)
(*                      this turns out to be a compiler bug; it should have   *)
(*                      dumped with a compiler-generated trap.                *)
(*       15-Sep-88 RSC  Use common module OvSize to read the overlay file's   *)
(*                      header, and use DetermineSpaceNeeded to round up      *)
(*                      sizes that are not in a pre-defined layer.            *)
(*                                                                            *)
(*                      Use some available procedures from DynMem to          *)
(*                      cut down on code needs here.                          *)
(*                                                                            *)
(*                      A note about rounding up overlay sizes:  For Time Line*)
(*                      we have determined that we should allocate all our    *)
(*                      free, dynamic memory in 4KB chunks, plus the 16 bytes *)
(*                      of overhead taken by DOSAlloc.  In other words, one   *)
(*                      DISK BASED FlexStor record is 4096 bytes + 16 bytes   *)
(*                      of DOSAlloc() overhead.  A Heap buffer is             *)
(*                      (4*(4096+16))-16 bytes, + 16 bytes of DOSAlloc()      *)
(*                      overhead.  See?  We want everything to end up as a    *)
(*                      multiple of 4096+16 bytes.  OvSize will compute the   *)
(*                      proper rounded up size for us.  We just need to decide*)
(*                      whether to round up or not.                           *)
(*                                                                            *)
(*                      As the reserved layer is static and not dynamic, there*)
(*                      is no benefit to rounding up the size of overlays that*)
(*                      go into a reserved (preallocated) layer.  In fact, it *)
(*                      would waste space.  Instead, any time a LOCAL LAYER   *)
(*                      (Layer^.local = TRUE) is to be created, that is       *)
(*                      upsized.  This is all done in the "GetBlock" proc.    *)
(*                                                                            *)
(*  (RSC 9/27/88 Note:  DynMem was designed for INTEGER ONLY sizes (<32KB),   *)
(*                      and so proved unusable for our needs.)                *)
(*                                                                            *)
(*       28-Sep-88 RSC  Try to save some stack space in Call/Install Overlay. *)
(*                                                                            *)
(*       11-Nov-88 RSC  Insure that HeapAvail() is true after loading an      *)
(*                      overlay onto the heap.  See GetBlock.                 *)
(*                                                                            *)
(*       18-Nov-88 EGK  Get Relocate to send a message to the outside that    *)
(*                      it has found the base layer overlay for the overlay   *)
(*                      being called.  We use ThingsWeForgot for this.        *)
(*                      See Overlays.MOD for receiver of this message.        *)
(*                                                                            *)
(*        5-Jan-89 RSC  1) remove relocate kluge via Kluges module.  Added    *)
(*                         references to OvTree module.                       *)
(*                      2) Even-aligned a few stacks                          *)
(*                      3) Made CallOverlay[InLayer] and InstallOverlay[InLayer] *)
(*                         have VAR filename parameters.                      *)
(*                                                                            *)
(*       09-Oct-89 RSC  Fixed bug where when a layer completely fills up such *)
(*                      that there is no free space, we would derefrence the  *)
(*                      free pointer anyway, which was NIL.  Ed and Wayne     *)
(*                      found this one.                                       *)
(*                                                                            *)
(*       13-Oct-89 RSC  When seeing if an overlay should have its size rounded*)
(*                      up, we checked TLMainStarting.  Recently, TLREG was   *)
(*                      setting up TLMainStarting as a flag that we were ABOUT*)
(*                      to start TLMain.  As a result, we rounded up TLMain   *)
(*                      to a 4K boundary, wasting 2K.   Argh.                 *)
(*                                                                            *)
(*       23-Sep-90 RSC  Added interlock to loading overlays, so that loading  *)
(*                      an overlay that runs into an error will NOT allow     *)
(*                      lower level procedures from invoking an overlay.      *)
(*                      Specificly, MACPLAY will not load when an error box   *)
(*                      is presented.                                         *)
(*                                                                            *)
(*        7-Feb-91 RSC  The overlay pointer is passed from the client into    *)
(*                      this module already pointing to space.  This allows   *)
(*                      overlays that have been swapped out to still have a   *)
(*                      valid descriptor.                                     *)
(*                                                                            *)
(*       27-May-91 RSC  Applied fixes and simplifications from the newer      *)
(*                      Logitech compiler release (89).                       *)
(*                                                                            *)
    (* RSC 30-May-91 Found a linker or RTS error.  The "fileLengthHigh"
                     number in the overlay header is the number of BLOCKS
                     of 512 bytes there are in the file.  As per the
                     Microsoft standard, this is the number of full AND
                     PARTIAL blocks, and so is one more than the number
                     of WHOLE blocks when the fileLengthLow is non-zero.
                     Well, Logitech (and I when I copied their code)
                     accounted for the WHOLE blocks when fileLengthLow
                     was non-zero, but if it is zero, we allocate TOO
                     LITTLE SPACE FOR THE OVERLAY.  Then we read in
                     the RIGHT number of bytes into the WRONG space
                     allocated.  For layers, this also had the effect
                     of causing SWAPPING and CACHEING to move too few
                     bytes.
    *)

    (*  1-Jul-91 RSC Put into the overlay descriptor maintained by the
                     RTSMain module the address of the corresponding
                     OvTree record and treenode as dummy[1] and dummy[2],
                     respectively.  This work is done in OvTree, but here
                     I changed the parameters to SetBaseLayer.
    *)

    (* 11-Jul-91 LAA Preserve the back pointers which go from the Logitech
                     overlay record to our overlay context (in OwnDesc).  
                     This is intended to fix a problem with overlays which 
                     produce version conflicts.  Credit Roger with this fix.
       20-Sep-91 EGK In NewLayer and DisposeLayer, use DOSMemory calls
                     instead of direct DOSCALLs to get DOS memory.  That way,
                     we can use UMB memory, and our memory use is consistent
                     with the checks that Overlays.MOD makes before calling
                     us.
       23-Sep-91 EGK When calling NewLayer, don't increment size by 1 since
                     DetermineSpaceNeeded has already done at least that.
       24-Sep-91 EGK Well, that wasn't exactly right.  For start-up overlays,
                     1 paragraph wasn't enough, and DetermineSpaceNeeded
                     wasn't being called for them anyway.  I fixed
                     DetermineSpaceNeeded in OvSize so that it accounts for
                     the ProgramState and adds a larger cushion for the
                     non-startup overlays.  At any rate, we don't need to
                     check the ProgramState here any more.
    *)
(******************************************************************************)
IMPLEMENTATION MODULE Overlay; (* BZ *) (* AR *)

FROM   RTSMain    IMPORT
  Execute, Status, OverlayPtr, OverlayDescriptor, overlayList, activProcess,
  ProcPtr, ProcDescriptor, debuggerRecord, DebuggerRecord,
  InstallTermProc, ProcessDescriptor,
  Terminate, RTDProc, overlayTermProc, overlayInitProc,
  PSPAddress, Process, dyingOverlay;
  
FROM   RTSCoroutine IMPORT
  addProcess;
  
FROM   SYSTEM     IMPORT
  ADDRESS, ADR, DOSCALL, SETREG, ES, DI, TSIZE, PROCESS;

FROM OvSize  IMPORT
    (* TYPE *)      AnOverlayHeader,
    (* PROCS *)     OpenOverlay, CloseOverlay, ReadOverlayHeader,
                    DetermineSpaceNeeded;

FROM OvTree  IMPORT
    (* PROCS *)     SetBaseLayer;

FROM Paranoia               IMPORT
        (* TYPES *)             AProgramState,
        (* VARS  *)             ProgramState;

FROM Space                  IMPORT
        (* PROCS *)             HeapAvailable;

FROM DOSMemory              IMPORT
    (* PROC *)                  DOSAvail, DOSAlloc, DOSDeAlloc;


(******************************************************************)

MODULE BlockManager;

  IMPORT ADDRESS, DOSCALL,  ADR, HeapAvailable,
         AProgramState, ProgramState,
         DetermineSpaceNeeded, DOSAlloc, DOSDeAlloc;

  EXPORT GetBlock, FreeBlock, NewLayer, DisposeLayer, LayerId;

  CONST
      Nil     = 0FFFFH;
      ALLOC   = 48H;
      DEALLOC = 49H;
      MAXSIZE = 4096;  (* 64KB in paragraphs *)

 (*
    DANGER!!
        This data structure knowledge is used in Overlays.Mod!!
 *)
  TYPE
      LayerId    = POINTER TO LayerDesc;

      LayerDesc  = RECORD
                     size   : CARDINAL;
                     InUse,
                     local  : BOOLEAN;
                   END;

(* 1-Feb-91 RSC Insure that there is only EVER 1 item in a block!!
                This is because we swap blocks out and in, so the
                ENTIRE BLOCK from <BlockStart> through <OverlayEnd>
                must go in here.
*)
  PROCEDURE GetBlock (VAR adr : ADDRESS; size : CARDINAL; VAR layer : LayerId):BOOLEAN;
  VAR
      done       : BOOLEAN;
  BEGIN
    IF layer = NIL THEN
          (* For NON-RESERVED-LAYER stuff RSC 9/16/88: *)

        (*  Removed the IF test 9/24/91 EGK
      IF (ProgramState >= TLMainRunning) THEN   (* 13-Oct-89 RSC Was TLMainStarting *)
          size := DetermineSpaceNeeded( size ); (* Round up *)
      END;
        *)

      size := DetermineSpaceNeeded (size);
      NewLayer (layer, size, done);     (* was size+1 -- 9/23/91 EGK *)

      (* RSC 11/11/88:

            If there was not enough memory, or, now that it is created,
            HeapAvailable() says there is not much there, then fail.
      *)
      IF (NOT done) OR (NOT HeapAvailable()) THEN
          IF (done) THEN
              DisposeLayer( layer );    (* was allocated? *)
          END;
          RETURN FALSE;
      END;

      layer^.local := TRUE;
    END;

    adr := layer;              (* Locals do not need memory management. *)
    INC(adr.SEGMENT);

    IF (NOT layer^.local) THEN
        IF (size >= layer^.size) THEN
            adr := NIL;
HALT; (* ********************************************* *)
            RETURN FALSE;
        END;
    END;

    layer^.InUse := TRUE;

    RETURN TRUE;

  END GetBlock;


  PROCEDURE FreeBlock (layer : LayerId; addr : ADDRESS; size : CARDINAL);
  BEGIN
    IF layer^.local THEN
        DisposeLayer (layer);
    END;
    layer^.InUse := FALSE;
  END FreeBlock;


  PROCEDURE NewLayer (VAR layer : LayerId; size : CARDINAL; VAR done : BOOLEAN);
  VAR base      : ADDRESS;
      err,
      s         : CARDINAL;
  BEGIN
    done  := FALSE;
    layer := NIL;
    IF (size > 1) THEN
            (*          old code
        s := size;
        DOSCALL (ALLOC, s, base.SEGMENT, err);
        IF (s <> size) OR (err > 0) THEN
          RETURN;
        END;
            *)

            (*  new code -- 9/20/91 EGK *)

        DOSAlloc (base, size);
        IF (base = NIL) THEN
            RETURN;
        END;

        base.OFFSET         := 0;
        layer               := base;
        layer^.size         := size;
        layer^.local        := FALSE;
        done                := TRUE;
        layer^.InUse        := FALSE;
    END;
  END NewLayer;


  PROCEDURE DisposeLayer (layer : LayerId);
  CONST
      DEALLOC = 49H;
  VAR
    err : CARDINAL;
    size : CARDINAL;
  BEGIN
        (* old code
    DOSCALL (DEALLOC, layer, err);
    IF (err > 0) THEN                                             (* 16-Dec-87 LAA *)
        HALT;
    END;
        *)

        (* new code -- 9/20/91 EGK *)

    size := layer^.size;
    DOSDeAlloc (layer, size);
    IF (layer <> NIL) THEN
        HALT;
    END;

  END DisposeLayer;




END BlockManager;

(********************************************************************)

MODULE Loader;

  IMPORT OverlayPtr, ErrorCode, LayerId, ADDRESS, ProcPtr, activProcess,
         DOSCALL, FreeBlock, GetBlock, ADR, TSIZE, ProcDescriptor,
         PSPAddress, AnOverlayHeader, OpenOverlay, ReadOverlayHeader,
         CloseOverlay, SetBaseLayer;

  EXPORT Load;

  CONST
       KeySize       = 4;      (* for instance, check not milli-seconds *)
       MaxCard       = 0FFFFH;
       HeaderSize    = 28;
       OVLCode       = 4DH + 256 * 5BH; (* signature of .OVL *)
       EXECode       = 4DH + 256 * 5AH; (* signature of .EXE *)
       BufLen        = 512;
       SharedReadOnly= 00100000B;                                 (* 29-Dec-87 LAA *)

       OPEN    = 3DH;
       CLOSE   = 3EH;
       READ    = 3FH;
       SEEK    = 42H;
       DRIVE   = 19H;

       NbProc  = 16;     (* number of init/term procedures allowed *)

  TYPE 
       ModuleKey= ARRAY [0..5]   OF CHAR;

  VAR
       Interlock    : CARDINAL; (* 23-Sep-90 RSC *)


  PROCEDURE AddCard (VAR n : CARDINAL; m : CARDINAL);
  BEGIN
    IF n > MaxCard - m THEN
      n := MaxCard
    ELSE
      n := n + m;
    END;
  END AddCard;

  PROCEDURE FindOvlDesc (VAR name : ARRAY OF CHAR):OverlayPtr;
    VAR desc : OverlayPtr;
        driv : OverlayPtr;
  
    PROCEDURE NoMatch (VAR nom : ARRAY OF CHAR):BOOLEAN;
      VAR i : CARDINAL;
    BEGIN
      i := 0;
      WHILE (CAP (nom[i]) = CAP (name[i]) ) & (nom [i] <> 0C) DO
        INC (i);
      END;
      RETURN (nom [i] <> 0C) OR (name [i] <> 0C);
    END NoMatch;
  
  BEGIN
    desc := activProcess^.currOverlay;
    LOOP
      IF desc = NIL THEN RETURN NIL END;
      driv := desc^.parent;
      WHILE (driv <> NIL) & NoMatch (driv^.overlayName) DO
        driv := driv^.parent;
      END;
      IF driv = NIL THEN
        IF NoMatch (desc^.overlayName) THEN
          desc := desc^.father;
        ELSE
          RETURN desc;
        END;
      ELSE
        RETURN driv;
      END;
    END;
  END FindOvlDesc;

  PROCEDURE Load ( VAR     fileName    : ARRAY OF CHAR ;
                   VAR     overlayDesc : OverlayPtr     ;
                   VAR     error       : ErrorCode     ;
                   VAR     entryPoint  : ADDRESS       ;
                           loadLayer   : LayerId      );
  
    VAR 
         WholeBlocks,
         pos             : CARDINAL;
         loadFile        : CARDINAL;
         err             : CARDINAL;
         codeSize        : CARDINAL;
         startCode       : ADDRESS;
         startMem        : ADDRESS;
         topMem          : ADDRESS;
         sizeMem         : CARDINAL;
         epAddr          : ADDRESS;
         OverlayHeader   : AnOverlayHeader;
         memAllocated    : BOOLEAN;
         done            : BOOLEAN;
         buffer          : ARRAY [1..BufLen] OF CHAR; (* RSC 1/5/89 moved here *)
  
    PROCEDURE Error (n : ErrorCode);
    BEGIN
      error := n;
      IF memAllocated THEN
        FreeBlock (loadLayer, startMem, OverlayHeader.minMemory);
      END;
    END Error;
  


    PROCEDURE OpenFile;
    VAR
        i    : CARDINAL;
        name : ARRAY [0..127] OF CHAR;
    BEGIN
        i := 0;
        WHILE fileName[i] <> 0C DO
            INC(i);
            name[i] := fileName[i-1];
        END;
        name[0] := CHR(i);
        IF (NOT OpenOverlay( name, loadFile )) THEN
            error := FileNotFound;
        END; 
    END OpenFile;
  



    PROCEDURE AllocateMemory;
      VAR actual : ADDRESS;
          base   : CARDINAL;
    BEGIN
      sizeMem := OverlayHeader.minMemory;
      IF GetBlock (startMem, OverlayHeader.minMemory, loadLayer) THEN
        memAllocated := TRUE;
      ELSE
        Error (InsufMemory);
        RETURN;
      END;
      topMem         := startMem;
      topMem.SEGMENT := topMem.SEGMENT + sizeMem;
      actual         := startMem;
      startCode      := actual;
      INC(startCode.SEGMENT, (NbProc*TSIZE(ProcDescriptor)+15) DIV 16);
    END AllocateMemory;




    PROCEDURE LoadFile;
      CONST BlockSize = 4096;
      VAR   read : CARDINAL;
            h,l  : CARDINAL;
            addr : ADDRESS;
  
      PROCEDURE IncAdr (VAR adr : ADDRESS; size : CARDINAL);
      BEGIN
        INC (adr.SEGMENT, size DIV 16);
        INC (adr.OFFSET,  size MOD 16);
        IF adr.OFFSET > 15 THEN
          INC (adr.SEGMENT, adr.OFFSET DIV 16);
          adr.OFFSET := adr.OFFSET MOD 16;
        END;
      END IncAdr;
  
    BEGIN
      WITH OverlayHeader DO
          DOSCALL (SEEK, loadFile, 0, headerSize DIV BlockSize, 
                         16 * (headerSize MOD BlockSize), h, l, err);
      END;
      read := 1;
      addr := startCode;
      WHILE (read > 0) & (err = 0) DO
        (* 27-May-91 RSC applied following fix: *)
        (* 19-Nov-87/?, use of 0FFF0H instead of MaxCard *)
        DOSCALL (READ, loadFile, 0FFF0H, addr, read, err);
        IncAdr (addr, read);
      END;
    END LoadFile;
  
    PROCEDURE InitBuf;
      VAR read : CARDINAL;
          h, l : CARDINAL;
    BEGIN
      DOSCALL (SEEK, loadFile, 0, 0, OverlayHeader.relocationOffset, h, l, err);
      DOSCALL (READ, loadFile, BufLen, ADR (buffer), read, err);
      pos := 0;
    END InitBuf;
  
    PROCEDURE ReadByte ():CARDINAL;
      VAR
          read : CARDINAL;
    BEGIN
      INC (pos);
      IF pos > BufLen THEN
        DOSCALL (READ, loadFile, BufLen, ADR (buffer), read, err);
        IF (err <> 0) THEN
            Error( NotDone );
                (* 27-May-91 RSC Code simplification: *)
            buffer[1] := 0C;  (* Return a 0, that tends to be a signal *)
        END;
        pos := 1;
      END;
      RETURN ORD(buffer[pos]);
    END ReadByte;
  
    PROCEDURE ReadWord ():CARDINAL;
      (* Intel order : low / high *)
    BEGIN
      RETURN ReadByte() + 256 * ReadByte();
    END ReadWord;
  
    PROCEDURE RelocatePass (baseAddress : CARDINAL);

      CONST Size = 4;

    VAR
        P : RECORD
            CASE BOOLEAN OF
              TRUE : reloc   : ADDRESS;
            | FALSE: ptrWord : POINTER TO CARDINAL;
            END;
        END;
        segment : CARDINAL;
        code    : CARDINAL;
    BEGIN
      segment := startCode.SEGMENT;
      code    := ReadByte ();
      WITH P DO
          WHILE (code = 255) DO  (* 27-May-91 RSC Simplified *)
            reloc.OFFSET  := ReadWord ();
            reloc.SEGMENT := ReadWord () + segment;
            ptrWord^      := ptrWord^ + baseAddress;
            code          := ReadByte ();
            WHILE (code > 0) AND (code < 255) DO
                (* 27-May-91 RSC Applied this simplification from the
                                 new compiler release:
                *)
              IF reloc.OFFSET >= (MaxCard - 255) THEN
                  INC(reloc.SEGMENT, reloc.OFFSET DIV 16 );
                  reloc.OFFSET  := reloc.OFFSET MOD 16;
              END;
              INC (reloc.OFFSET, code);
              ptrWord^ := ptrWord^ + baseAddress;
              code     := ReadByte ();
            END;
          END;
      END;
    END RelocatePass;
  
    PROCEDURE Relocate;
      VAR i,j         : CARDINAL;
          level       : CARDINAL;
          importedMod : CARDINAL;
          ParentOverlayDesc,
          ovlDesc     : OverlayPtr;
          addr        : ADDRESS;
          procPtr     : ProcPtr;
          moduleKey   : ModuleKey;
          name        : ARRAY [0..40] OF CHAR;
  
      PROCEDURE Name;
        VAR i,j : CARDINAL;
      BEGIN
        j := ReadByte (); i := 0;
        WHILE j > 0 DO
          name [i] := CHR (ReadByte ()); INC (i); DEC (j);
        END;
        name [i] := 0C;
      END Name;
  
      PROCEDURE Reloc;
      BEGIN
        RelocatePass (ovlDesc^.codeSegment);
      END Reloc;
  
      PROCEDURE Key;
        VAR i,j : CARDINAL;
            adr : ADDRESS;
            ptr : POINTER TO ModuleKey;
      BEGIN
        importedMod := ReadWord ();
        i := importedMod;
        WHILE i > 0 DO
          FOR j := 0 TO 5 DO
            moduleKey [j] := CHR (ReadByte ());
          END;
          adr.OFFSET  := ReadWord ();
          adr.SEGMENT := ReadWord () + ovlDesc^.codeSegment;
          ptr := adr;
          j := 0;
          WHILE (j < KeySize) & (moduleKey[j] = ptr^ [j]) DO
            INC (j);
          END;
          IF j < KeySize THEN
            Error (VersionConflict);
            RETURN;
          END;
          DEC (i);
        END;
      END Key;
  
      PROCEDURE OwnDesc;
        VAR addr           : ADDRESS;
            ownDescription : OverlayPtr;
            dummy1, dummy2 : ADDRESS;
      BEGIN
        addr.OFFSET    := ReadWord ();
        addr.SEGMENT   := ReadWord () + startCode.SEGMENT;
        ownDescription := addr;            (* 7-Feb-91 RSC  *)
        dummy1                := overlayDesc^.dummy[1];        (* 11-Jul-91 *)
        dummy2                := overlayDesc^.dummy[2];
        overlayDesc^          := ownDescription^; (* 7-Feb-91 RSC  *)
        overlayDesc^.dummy[1] := dummy1;
        overlayDesc^.dummy[2] := dummy2;
      END OwnDesc;
  
    BEGIN
      ParentOverlayDesc := NIL;
      InitBuf;
      RelocatePass (startCode.SEGMENT);
      level := ReadByte ();
      WHILE (error = Done) & (level <> 0FFH) DO
        Name;
        ovlDesc := FindOvlDesc (name);
        IF ovlDesc = NIL THEN
          Error (VersionConflict);
        ELSE
          Key;
          IF error = Done THEN
            IF (level = 0) THEN
                ParentOverlayDesc := ovlDesc;
            END;
            Reloc;
            level := ReadByte ();
          END;
        END;
      END;
      IF error = Done THEN
        OwnDesc;
        Name;

            (* 27-May-91 RSC Applied this fix:
            *)
          (* 11-Apr-88/yp, no key present in OVL file for own descr *)
          (* Key; *)
    
        WITH overlayDesc^ DO
          memoryAddr := startMem;
          memorySize := sizeMem;
          codeSegment:= startCode.SEGMENT;
          freeList   := startMem;
          termProc   := NIL;
          initProc   := NIL;
          layer      := loadLayer;
          checkWord  := 0FA50H;
        END;

        IF (ParentOverlayDesc = NIL) THEN
            HALT;  (* Fatal Error, all overlays have a parent. *)
        ELSE
                (* 1-Jul-91 RSC changed parameters to be the whole pointer,
                                not just the strings.
                *)
            SetBaseLayer( overlayDesc, ParentOverlayDesc );
        END;

        addr    := startMem;
  
        FOR i := 1 TO NbProc-1 DO
          procPtr := addr;
          INC(addr, TSIZE(ProcDescriptor));
          procPtr^.next := addr;
        END;
  
        procPtr       := addr;
        procPtr^.next := NIL;
      END;
    END Relocate;
  
  BEGIN

        (* 23-Sep-90 RSC Use an interlock to prevent recursion.
        *)
    IF (Interlock > 0) THEN
        error := NotDone;
        RETURN;
    END;

    INC(Interlock);

    error := Done;
    memAllocated := FALSE;
    OpenFile;
    IF error <> Done THEN DEC(Interlock); RETURN; END;

    IF (NOT ReadOverlayHeader(OverlayHeader)) THEN
        Error (BadFormat);
    END;

    IF (error = Done) THEN
        WITH OverlayHeader DO

                (* 30-May-91 RSC My fix:
                *)
            WholeBlocks := fileLengthHigh;
            IF (fileLengthLow > 0) THEN
                DEC(WholeBlocks); (* there is a partial last block *)
            END;

            codeSize  := 32 * (WholeBlocks) + fileLengthLow DIV 16 - headerSize;
            IF fileLengthLow MOD 16 > 0 THEN
                INC (codeSize);
            END;
            AddCard (minMemory, codeSize);
            AddCard (minMemory, (NbProc*TSIZE(ProcDescriptor)+15) DIV 16);
            AddCard (maxMemory, codeSize);
            AddCard (maxMemory, (NbProc*TSIZE(ProcDescriptor)+15) DIV 16);
        END;
        AllocateMemory();
    END;

    IF (error = Done) THEN
        LoadFile();
    END;

    IF (error = Done) THEN
        Relocate();
        WITH OverlayHeader DO
            entryPoint.SEGMENT := entryBase + startCode.SEGMENT;
            entryPoint.OFFSET  := entryOffset;
        END;
    END;

    CloseOverlay();
    DEC(Interlock);

  END Load;



BEGIN
    Interlock := 0;             (* 23-Sep-90 RSC *)
END Loader;

(*******************************************************************)

PROCEDURE NilProc;
BEGIN
END NilProc;

CONST
      MaxCard = 0FFFFH;
VAR
      curProgLevel : CARDINAL;





PROCEDURE Call (ep : ADDRESS);
  VAR addr : ADDRESS;
BEGIN
  addr := ADR (ep);
  SETREG (ES, addr.SEGMENT);
  SETREG (DI, addr.OFFSET);
  Execute;
END Call;




PROCEDURE InsertOverlayInList (overlay : OverlayPtr);
BEGIN
  overlay^.next := overlayList^.next;
  overlay^.prev := overlayList;
  overlay^.prev^.next := overlay;
  overlay^.next^.prev := overlay;
END InsertOverlayInList;




PROCEDURE DeleteOverlayInList (overlay : OverlayPtr);
BEGIN
  IF overlayList = overlay THEN
    overlayList := overlay^.next;
  END;
  overlay^.next^.prev := overlay^.prev;
  overlay^.prev^.next := overlay^.next;
  overlay^.next := NIL;
  overlay^.prev := NIL;
END DeleteOverlayInList;





PROCEDURE ExistOverlay ( overlay : OverlayId ) : BOOLEAN;
  VAR dd : OverlayPtr;
BEGIN
  dd := overlayList^.next;
  WHILE (dd <> overlayList) & (dd <> OverlayPtr (overlay)) DO
    dd := dd^.next;
  END;
  RETURN dd = OverlayPtr (overlay);
END ExistOverlay;





PROCEDURE FreeMemory (overlay : OverlayPtr);
BEGIN
  FreeBlock (LayerId (overlay^.layer), overlay^.memoryAddr, overlay^.memorySize);
  overlay^.checkWord := 0;
END FreeMemory;





PROCEDURE TermProc (overlay : OverlayPtr);
  VAR 
      pp     : ProcPtr;
      p      : PROC;
BEGIN
  activProcess^.termOverlay := overlay;
  pp  := overlay^.termProc;
  WHILE pp <> NIL DO
    p := pp^.termProc;
    pp^.termProc := NilProc;
    pp := pp^.next;
    p;
  END;
END TermProc;



(* ====================  exported procedures ======================= *)

PROCEDURE GetErrorCode (error : ErrorCode; VAR str : ARRAY OF CHAR);
BEGIN
str[0] := 0C;
END GetErrorCode;


PROCEDURE DeInstallOverlay (    overlayId : OverlayId  );
  VAR
      parent : OverlayPtr;
BEGIN
  IF ExistOverlay (overlayId) THEN
    overlayId^.overlay := 1;    (* AR, patch for debugger, 87.07.27 *)
    debuggerRecord.beforeTermProc ( PROCESS (activProcess), overlayId);
    overlayId^.overlay := 2;    (* AR, patch for debugger, 87.07.27 *)
    TermProc (overlayId);
    overlayId^.overlay := 1;    (* AR, patch for debugger, 87.07.27 *)
    debuggerRecord.beforeExit ( PROCESS (activProcess), overlayId);
    overlayId^.overlay := 2;    (* AR, patch for debugger, 87.07.27 *)
    parent := overlayId^.father;
    WHILE parent^.parent <> overlayId DO
      parent := parent^.parent;
    END;
    parent^.parent := overlayId^.parent;
    DeleteOverlayInList (overlayId);
    FreeMemory (overlayId);
  END;
END DeInstallOverlay;





  (* RSC 1/5/89  Made file name a VAR parameter. *)

PROCEDURE InstallOverlayInLayer(VAR fileName     : ARRAY OF CHAR;
                                    newOverlay   : OverlayId;   (* 7-Feb-91 RSC *)
                                    layer        : LayerId;
                                VAR done         : ErrorCode    ;
                                VAR status       : Status       );
VAR currentOverlay : OverlayPtr;
    currentLevel   : CARDINAL;
    entryPoint     : ADDRESS;
    processList    : Process;
    parent         : OverlayPtr;

BEGIN
  Load ( fileName, newOverlay, done, entryPoint, layer );
  IF done = Done THEN

    currentOverlay := activProcess^.currOverlay;
    currentLevel   := activProcess^.programLevel;

    newOverlay^.overlay := 2;
    newOverlay^.father  := currentOverlay;
    newOverlay^.loaderProcess := activProcess;
    newOverlay^.parent := NIL;
    newOverlay^.processList := NIL;
    InsertOverlayInList ( newOverlay );
    activProcess^.currOverlay := newOverlay;

    Call (entryPoint);

    status := newOverlay^.overlayStatus;
    activProcess^.currOverlay := currentOverlay;
    activProcess^.progStatus  := Normal;

    IF status = Normal THEN
      parent := currentOverlay;
      WHILE parent^.parent <> NIL DO
        parent := parent^.parent;
      END;
      parent^.parent := newOverlay;
      parent := newOverlay;
      WHILE parent <> NIL DO
        parent^.father := currentOverlay;
        parent := parent^.parent;
      END;
    ELSE
      WHILE newOverlay <> NIL DO
        currentOverlay := newOverlay;
        newOverlay := newOverlay^.parent;
        DeleteOverlayInList (currentOverlay);
        FreeMemory (currentOverlay);
      END;
    END;
  END;
END InstallOverlayInLayer;








PROCEDURE CallOverlayInLayer( VAR  fileName : ARRAY OF CHAR;
                                   layer    : LayerId      ;
                              VAR  done     : ErrorCode    ;
                              VAR  status   : Status       );
VAR
    entryPoint     : ADDRESS;
    currentLevel   : CARDINAL;
    currentOverlay : OverlayPtr;
    newOverlay     : OverlayPtr;
BEGIN
    HALT;  (* UNUSED *)

(* *********************************
  Load ( fileName, newOverlay, done, entryPoint, layer );
  IF done = Done THEN

    currentLevel   := activProcess^.programLevel;
    currentOverlay := activProcess^.currOverlay;

    (*$R-*)
    INC( curProgLevel );  (* Shouldn't wrap, but if it does, ... *)
    (*$R=*)

    newOverlay^.overlay := 1;
    newOverlay^.programLevel := curProgLevel;
    newOverlay^.father := currentOverlay;
    newOverlay^.loaderProcess := activProcess;
    newOverlay^.parent := NIL;
    newOverlay^.processList := NIL;
    InsertOverlayInList (newOverlay);
    activProcess^.currOverlay := newOverlay;
    activProcess^.programLevel := curProgLevel;

    Call (entryPoint);

    status := newOverlay^.overlayStatus;
    activProcess^.currOverlay := currentOverlay;
    activProcess^.progStatus  := Normal;
    activProcess^.programLevel:= currentLevel;

    WHILE newOverlay <> NIL DO
      currentOverlay := newOverlay;
      newOverlay := newOverlay^.parent;
      DeleteOverlayInList (currentOverlay);
      FreeMemory (currentOverlay);
    END;

  END;
****************************** *)
END CallOverlayInLayer;






PROCEDURE CallOverlay     ( VAR fileName : ARRAY OF CHAR;
                            VAR done     : ErrorCode    ;
                            VAR status   : Status       );
BEGIN
    CallOverlayInLayer ( fileName, NIL, done, status);
END CallOverlay;





PROCEDURE InstallOverlay  ( VAR fileName : ARRAY OF CHAR; 
                                Descript : OverlayId;   (* 7-Feb-91 RSC *)
                            VAR done     : ErrorCode    ;
                            VAR status   : Status       );
BEGIN
    InstallOverlayInLayer( fileName, Descript, NIL, done, status );
END InstallOverlay;





PROCEDURE TermProcess (currentProcess : Process);
  VAR currentOverlay : OverlayPtr;
      parent         : OverlayPtr;
      dd             : OverlayPtr;
      loader         : Process;
      processList    : Process;
BEGIN
  currentOverlay := currentProcess^.currOverlay;
  IF currentOverlay = NIL THEN RETURN END;    (* AR 87.07.28 a process may have
                                                 no overlay loaded  *)
  loader := currentOverlay^.loaderProcess;
  WHILE loader = currentProcess DO
    processList := currentOverlay^.processList;
    WHILE processList <> NIL DO
      TermProcess (processList);
      processList := processList^.processList;
    END;
    parent := currentOverlay;
    WHILE parent <> NIL DO
      TermProc (parent);
      debuggerRecord.beforeExit (PROCESS (loader), parent);
      parent := parent^.parent;
    END;
    parent := currentOverlay;
    currentOverlay := currentOverlay^.father;
    loader := currentOverlay^.loaderProcess;
    WHILE parent <> NIL DO
      dd := parent; 
      parent := parent^.parent;
      DeleteOverlayInList (dd);
      FreeMemory (dd);
    END;
  END;
  currentProcess^.currOverlay := NIL;
END TermProcess;


PROCEDURE CallTermProc;
  VAR currentOverlay : OverlayPtr;
      ovlList        : OverlayPtr;
      dyingOvl       : OverlayPtr;
      processList    : Process;
BEGIN

  dyingOvl := dyingOverlay;
 
  currentOverlay := activProcess^.currOverlay;

  IF (dyingOvl^.overlay = 1) OR (dyingOvl^.overlayStatus <> Normal) THEN
    WHILE dyingOvl <> currentOverlay DO
      processList := currentOverlay^.processList;
      WHILE processList <> NIL DO
        TermProcess (processList);
        processList := processList^.processList;
      END;
      ovlList := currentOverlay;
      WHILE ovlList <> NIL DO
        TermProc (ovlList);
        debuggerRecord.beforeExit (PROCESS (activProcess), ovlList);
        ovlList := ovlList^.parent;
      END;
      currentOverlay := currentOverlay^.father;
      activProcess^.currOverlay := currentOverlay;
    END;
    ovlList := currentOverlay^.parent;
    WHILE ovlList <> NIL DO
      TermProc (ovlList);
      debuggerRecord.beforeExit (PROCESS (activProcess), ovlList);
      ovlList := ovlList^.parent;
    END;
    TermProc (dyingOvl); (* the RTD has already been called for it *)
  END;
END CallTermProc;


PROCEDURE CallInitProc;
  VAR currentOverlay : OverlayPtr;
      pp : ProcPtr;
      stop : OverlayPtr;
BEGIN
  currentOverlay := activProcess^.currOverlay;
  stop := currentOverlay;
  REPEAT
    pp := currentOverlay^.initProc;
    activProcess^.termOverlay := currentOverlay;
    WHILE pp <> NIL DO
      pp^.termProc;
      pp := pp^.next;
    END;
    currentOverlay := currentOverlay^.next;
  UNTIL currentOverlay = stop;
END CallInitProc;


PROCEDURE NewProcess (P : PROCESS);
  VAR currentOverlay : OverlayPtr;
      process : Process;
BEGIN
  currentOverlay := activProcess^.currOverlay;
        (* 27-May-91 RSC This otherwise usefull check is always getting in
                         the way of my most powerfull kluges.  The check
                         was to make sure that overlays do not start
                         processes.  If the overlay terminates before the
                         process does, then there would be trouble.  However,
                         all my use of processes is in debugging overlays.
                         so, uh, er, well, trust me.
        *)
(*  IF currentOverlay^.overlay = 2 THEN*)
(*    Terminate (BadOperand);*)
(*  ELSE*)
    process := Process (P);
    process^.processList := currentOverlay^.processList;
    currentOverlay^.processList := process;
(*  END;*)
END NewProcess;

BEGIN

  curProgLevel := activProcess^.programLevel;

  overlayList^.next    := overlayList;
  overlayList^.prev    := overlayList;
  overlayList^.parent  := NIL;
  overlayList^.processList := NIL;
  overlayList^.father  := NIL;
  overlayList^.loaderProcess := activProcess;
  overlayList^.overlay := 1;
  overlayList^.programLevel := curProgLevel;
  overlayList^.layer   := NIL;
  activProcess^.currOverlay := overlayList;

  overlayTermProc := CallTermProc;
  overlayInitProc := CallInitProc;

  addProcess := NewProcess;

END Overlay.
