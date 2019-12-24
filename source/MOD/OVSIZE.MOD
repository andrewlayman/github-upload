IMPLEMENTATION MODULE OvSize;


    (* OvSize - This module aids in determining the size of an overlay.
                the job is complicated by the fact that we want memory to
                be split up into chunks of 4kb.

                RSC 9/15/88

        RSC 11/9/88 - Upped the roundup size from one para to two.
        RSC 2-Jan-89  Changed references to Compare() to StringsEqual().
        RSC/KKC/LAA 27-Sep-89 Fixed a bug in DetermineSpaceNeeded, where
                    a boundary condition existed when we would return
                    1 paragraph LESS than was really needed!!   ARRGHH!
        RSC 1-Feb-91 Fixed bug in OpenOverlay that checked for the DOS
                     handle to be greater than 4.  The AUX handle is 3,
                     and Keyboard.EmergencyDump will close the AUX handle
                     to make sure that the HALT code has a handle to use.
                     Well, after the dump, the next file to be opened,
                     an overlay, will use handle 3, as AUX is now free.

                     Now, it is not optimal to keep running Time Line after
                     dumping the program, but it may be enough to be able
                     to save the schedule or run some other overlay.

        RSC 30-May-91 Found a linker or RTS error.  The "fileLengthHigh"
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
        EGK 9/24/91  Changed DetermineSpaceNeeded so that it checks the
                     ProgramState, instead of having one of its clients
                     (Overlay.GetBlock) do it.  The start-up overlays need
                     some extra space (10 paragraphs should be plenty) even
                     though they don't get rounded up to a 4K boundary.  We
                     think this may have caused the Eve start-up bug, due to
                     some overlays (sometimes) not having enough space
                     allocated for them.  Prior to this fix, Overlay.GetBlock
                     was only adding 1 paragraph for non-startup overlays,
                     and calling DetermineSpaceNeeded for startup overlays.
    *)



FROM Dialog     IMPORT
    (* PROCS *)     FatalError;

FROM Directory  IMPORT
    (* PROCS *)     ExtractFileNameParts;

FROM LStrings   IMPORT
    (* PROCS *)     SetString, StringsEqual, Copy, ConcatS, ConcatLS,
                    Upshift, LStringToTString, LengthOf;

FROM Paranoia               IMPORT
        (* TYPES *)             AProgramState,
        (* VARS  *)             ProgramState;

FROM RTSMain    IMPORT
    (* PROCS *)     ProcDescriptor;

FROM SYSTEM     IMPORT
    (* Things *)    ADR, SIZE, TSIZE, DOSCALL;




VAR
    SavedHandle   : CARDINAL;
    SavedString   : ARRAY [0..127] OF CHAR;
    SavedFileOpen : BOOLEAN;






 (* Open Overlay:

        Open the overlay file.  The passed string can be an LString that
        needs expanding, like "DK:..\Z".  The file need not exist here.

        Also, if the overlay was just opened, a caching action takes place.
        This way, OVERLAYS can find the overlay and set up space for it, and
        OVERLAYS can read the overlay into memory, but the overlay is only
        opened once.

     Preconditions  : LString is the file name.
     Postconditions : Handle  is the returned handle.
                      RETURN  is TRUE iff file opened.
 *)
PROCEDURE OpenOverlay( VAR FString : ARRAY OF CHAR;
                       VAR Handle  : CARDINAL   ) : BOOLEAN;
CONST
   SharedReadOnly = 00100000B;
   OPEN           = 3DH;
VAR
   Error     : CARDINAL;
   Device    : ARRAY [0..5]   OF CHAR;
   Path      : ARRAY [0..127] OF CHAR;
   File      : ARRAY [0..9]   OF CHAR;
   Extension : ARRAY [0..5]   OF CHAR;
   LString,
   TString   : ARRAY [0..127] OF CHAR;
BEGIN
    Copy( FString, LString );
    Upshift(LString);
    ExtractFileNameParts( LString, Device, Path, File, Extension );
    IF (LengthOf(Extension) = 0) THEN
        SetString( Extension, "OVL" );
    END;
    Copy(              Device, LString );
    ConcatLS( LString, Path );
    ConcatLS( LString, File );
    ConcatS(  LString, "." );
    ConcatLS( LString, Extension );

    IF ((StringsEqual( LString, SavedString )) AND (SavedFileOpen)) THEN
        Handle := SavedHandle;
        RETURN TRUE;
    END;

    CloseOverlay();

    LStringToTString( LString, TString );
    DOSCALL( OPEN, ADR(TString), SharedReadOnly, Handle, Error );
    IF (Handle > 0) AND (Error = 0) THEN    (* 1-Feb-91 RSC was > 4 *)
        SavedHandle   := Handle;
        SavedFileOpen := TRUE;
        Copy(LString, SavedString);
        RETURN TRUE;  (* File Opened. *)
    END;
    RETURN FALSE;
END OpenOverlay;





 (* Close any opened overlay. *)

PROCEDURE CloseOverlay();
CONST
    CLOSE = 3EH;
VAR
    Error : CARDINAL;
BEGIN
    IF (SavedFileOpen) THEN
        DOSCALL( CLOSE, SavedHandle, Error );
    END;
    SavedFileOpen  := FALSE;
    SavedString[0] := 0C;
END CloseOverlay;





  (* Read the overlay's header record.  This includes much of the
     Size information needed.

     Preconditions  : An overlay was opened successfully.
     Postconditions : Overlay Header is read in and returned, or else
                      FALSE is returned.
  *)
PROCEDURE ReadOverlayHeader( VAR OverlayHeader : AnOverlayHeader ) : BOOLEAN;
CONST
    READ     = 3FH;
    SetPos   = 42H;
    OVLCode  = 4DH + 256 * 5BH; (* signature of .OVL *) (* From Logitek *)
VAR
    CountRead,
    OHigh,
    OLow,
    Error   : CARDINAL;
BEGIN
    IF (NOT SavedFileOpen) THEN
        FatalError();
    END;
    DOSCALL( SetPos, SavedHandle, 0, 0, 0, OHigh, OLow, Error );
    DOSCALL( READ,   SavedHandle, SIZE(OverlayHeader), ADR(OverlayHeader),
             CountRead, Error);
    IF (CountRead <> SIZE(OverlayHeader)) OR (Error <> 0) OR
       (OverlayHeader.signature <> OVLCode) THEN
        RETURN FALSE;
    END;
    RETURN TRUE;
END ReadOverlayHeader;






 (* Determine Overlay Size.  Returns the size in paragraphs, or 0 if there
    is an error.
 *)
PROCEDURE DetermineOverlaySize() : CARDINAL;
CONST
    (* From OVERLAY.MOD:    *)
    NbProc  = 16;     (* number of init/term procedures allowed *)
VAR
    WholeBlocks,
    CodeSize      : CARDINAL;
    OverlayHeader : AnOverlayHeader;
BEGIN
    IF (NOT ReadOverlayHeader( OverlayHeader )) THEN
        RETURN 0;
    END;
    WITH OverlayHeader DO

     (* Code courtesy of Logitek's OVERLAY module. *)

            (* 30-May-91 RSC And fixes courtesy of me.
            *)
        WholeBlocks := fileLengthHigh;
        IF (fileLengthLow > 0) THEN
            DEC(WholeBlocks); (* there is a partial last block *)
        END;

        CodeSize := (32 * WholeBlocks) + (fileLengthLow DIV 16) - headerSize;
        IF ((fileLengthLow MOD 16) > 0) THEN
            INC (CodeSize);
        END;
        INC(minMemory, CodeSize);
        INC(minMemory, (NbProc*TSIZE(ProcDescriptor)+15) DIV 16);
    END;

    RETURN OverlayHeader.minMemory;

END DetermineOverlaySize;






 (* Determine Space Needed:

        Decide how much space we ACTUALLY want to allocate.  What we want here
        is to allocate in chunks equivelent to our standard "PageSize" of 4096
        bytes, with the added overhead that DOSAlloc will add (1 paragraph), and
        the overhead that DOS will add (1 paragraph).

        Preconditions: DesiredSizeInPara is a VERY ACCURATE count of paragraphs
                                         needed by the overlay.
        Postconditions: RETURNs the size, rounded up to the nearest magical
                                boundary.
 *)
PROCEDURE DetermineSpaceNeeded( DesiredSizeInPara : CARDINAL ) : CARDINAL;
CONST
    PageSize             = 4096 DIV 16;  (* Paragraphs in a page *)
    PageSizeWithOverhead = PageSize + 2; (* With DOSAlloc() and DOS overhead *)
    StartupFudge         = 10;           (* paragraphs for startup overlays *)
VAR
    OverlaySpaceNeeded : CARDINAL;
BEGIN
    IF (DesiredSizeInPara = 0) THEN  (* Error in input? *)
        RETURN 0;
    END;

    IF (ProgramState >= TLMainRunning) THEN     (* 9/24/91 EGK *)

        (* So, we want N buffers of "PageSizeWithOverhead" size, and
           1 buffer of "PageSize" size.
        *)
        OverlaySpaceNeeded := (DesiredSizeInPara DIV PageSizeWithOverhead)
                             * PageSizeWithOverhead;
        INC(OverlaySpaceNeeded, PageSize);

        (*  27-Sep-89  RSC

            There is a boundary condition here because our overhead size is 2,
            not 1.  It is possible at this point that we are one paragraph
            short because DesiredSizeInPara is (N * PageSizeWithOverhead)
            - 1 paragraph.  In this case we need to round up again by 4K+Fudge.
            We always want there to be ((N - 1) * PageSizeWithOverhead)
            + PageSize bytes allocated.
        *)
        IF (OverlaySpaceNeeded < DesiredSizeInPara) THEN
            INC(OverlaySpaceNeeded, PageSizeWithOverhead);
        END;

    ELSE
        OverlaySpaceNeeded := DesiredSizeInPara + StartupFudge;
    END;

    RETURN OverlaySpaceNeeded;

END DetermineSpaceNeeded;







BEGIN
    SavedFileOpen  := FALSE;
    SavedString[0] := 0C;
END OvSize.
