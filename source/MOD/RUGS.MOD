(*$S+*)

(*  =========================================================================
    Last Edit : September 25, 1989 5:25PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Takes screen "rugs".  This allows a client to trash some are of
        the screen, and then remove the rug, and PRESTO - the old screen
        contents come back.


    MODIFICATION HISTORY

    07/22/86 LAA    Put in a counter to keep track of how many calls to GetRug
                    and PutRug are made.
    11/25/86 LAA    Created DisplayRug, and recoded CreateRug and DisposeRug
                    to only use one allocation/deallocation each.
    27-Jun-87 LAA   Added new procedures to CreateBlankRug, CopyOfRug,
                    PutStringToRug, PutRugAt and PutVideoModeToRug.
    10-Sep-87 RSC   Put rugs into FlexStor.
     3-Dec-87 RSC   Remove error boxes on memory failures.
     8-Dec-87 AJL   Upgraded to new FlexStor.
    23-Dec-87 AJL   Check GetExtStatus before attempting to create a Rug.
                    This is to handle the problem that FlexStor may be
                    attempting to report an error, and that may make further
                    calls to FlexStor not workable until FlexStor returns.
                    FlexStor is not multi-threaded.
    29-Dec-87 LAA   After a call to GetCursorLocation, set the cursor back to
                    it's current type.  Otherwise the cursor comes on.
    11-Jan-88 LAA   Changed ReleaseObject to ReleaseUnchangedObject  where
                    appropriate.
    14-Feb-88 AJL   Rugs will now be allocated from the heap if there are
                    problems with FlexStor.
    22-Feb-88 LAA       - Force stack checking on for this module.
    23-Feb-88 AJL  -Weakened the RugsInterlock in create rug.  It was
                    preventing rugs during reporting of errors on
                    open of swapfile.
     3-Nov-88 RSC   For some reason, rugs never got allocated from flexstor.
                    ajusted that.
    23-Jan-89 RSC   Changed Storage to Space    .
    10-Jun-89 WKH   Added support for variable screen rows
     5-Jul-89 EGK   Rewrote everything.  Rugs no longer use any heap space;
                    rather, each is stored as a linked list of flexstor
                    blocks, where each block holds an integral number of
                    screen lines, and the maximum size of a block is
                    constrained by whatever flexstor reports as the
                    maximum record size.
    21-Aug-89 RSC   Remove use of GetExtStatus, as we are redefining the
                    meaning of that procedure.  Now it means "Do we have
                    plenty of FlexStor?", and for rugs, we don't care.
                    We'll take ANY FlexStor we can get.
    25-Sep-89 RSC   Check for ExtStatus of "ExtDamaged" to see if FlexStor
                    is calling us (ExtDamaged = "In FlexStor code now").
    26-Sep-89 LAA/RSC An extraneous NOT in CreateRug caused some problems.

----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE Rugs;

FROM Video      IMPORT GetImageLine, PutImageLine, GetCursorType,
                       SetCursorType, GetCursorLocation,
                       SetCursorLocation;

FROM Kbio       IMPORT ascreenx, ascreeny, AbsoluteMaxRow, maxrow, maxcol, avidmode, vidctrl;

FROM Dialog     IMPORT FatalError;

FROM SYSTEM     IMPORT CODE, WORD, ADDRESS, TSIZE, ADR, BYTE;

FROM LStrings   IMPORT LengthOf;

FROM MsgFile    IMPORT GetMessage;

FROM Paranoia   IMPORT  AProgramState, ProgramState, InitializationOK;

FROM FlexStor   IMPORT
        (* TYPE *)      AnExtHandle,     AnExtStoragePreference,
                        AnExtStatus,
        (* PROCS *)     CreateExtObjectWithSize, DiscardExtObject,
                        CopyExtObject,   GetExtSize, SetExtSize,
                        SetExtData,      LockObject, ReleaseObject,
                        MaximumRecordSize, GetExtStatus,
                        ReleaseUnchangedObject;

FROM Space      IMPORT  Available, ALLOCATE, DEALLOCATE;



CONST
    RugTag            = 7171;
    MAXCARDINAL       = 65535;

TYPE
    AnImage           = ARRAY [0..(AbsoluteMaxRow+1)*(maxcol+1)-1] OF WORD;


    ARugRecord        = RECORD
                           Tag         : CARDINAL;
                           CursorType  : CARDINAL;
                           CursorX,
                           CursorY     : CARDINAL;
                           Size        : CARDINAL;
                           XCount      : CARDINAL;
                           Ulx         : ascreenx;
                           Uly         : ascreeny;
                           Lrx         : ascreenx;
                           Lry         : ascreeny;
                           NextRRH     : AnExtHandle;
                           Image       : AnImage;
                        END;

    ARugRecordPointer = POINTER TO ARugRecord;

    ARug              = AnExtHandle;

VAR
    RugsInterlock       : BOOLEAN;





    (* CreateRugBuffer  --  Attempt to create a block to hold the portion
                            of the screen bounded by the given coordinates.
    *)

PROCEDURE CreateRugBuffer(    ULX               : ascreenx;
                              ULY               : ascreeny;
                              LRX               : ascreenx;
                              LRY               : ascreeny;
                          VAR RugBuffer         : AnExtHandle )
                                                               : BOOLEAN;
VAR
    WordSize                : CARDINAL;
    Overhead                : CARDINAL;
    DesiredSize             : CARDINAL;
    RugRecord               : ARugRecordPointer;

BEGIN
    WordSize := (LRX-ULX+1) * (LRY-ULY+1);        (* Compute storage *)
    Overhead := TSIZE(ARugRecord) - TSIZE(AnImage);
    DesiredSize := (WordSize*2) + Overhead;

 (* Interlock against recursive calls to CreateRug *)

    IF (RugsInterlock) THEN
        RETURN FALSE;
    END;
    RugsInterlock := TRUE;

    (* RSC 11/3/88 removed check of interlock here. *)

    IF (CreateExtObjectWithSize( RugBuffer, ExtMedium, DesiredSize )) THEN
        IF NOT (LockObject( RugBuffer, RugRecord ) = DesiredSize) THEN
            FatalError();
        END;
    ELSE
        RugsInterlock := FALSE;
        RETURN FALSE;
    END;

    RugsInterlock := FALSE;

    WITH RugRecord^ DO
        Tag  := RugTag;
        Size := WordSize;
        Ulx  := ULX;
        Uly  := ULY;
        Lrx  := LRX;
        Lry  := LRY;
        NextRRH := AnExtHandle(NIL);
    END;

    INC( RugBytes, DesiredSize );

    ReleaseObject (RugBuffer);
    RugRecord := NIL;

    RETURN TRUE;

END CreateRugBuffer;




PROCEDURE CreateRug(    ULX                 : ascreenx; 
                        ULY                 : ascreeny;
                        LRX                 : ascreenx; 
                        LRY                 : ascreeny;
                    VAR Rug                 : ARug     )
                                                        : BOOLEAN;
VAR
    LineSize                : CARDINAL;
    LinesPerBuffer          : CARDINAL;
    LinesToGo               : CARDINAL;
    Overhead                : CARDINAL;
    RugRecord               : ARugRecordPointer;
    LocalULY                : ascreeny;
    LocalLRY                : ascreeny;
    ThisBuffer              : AnExtHandle;
    NextBuffer              : AnExtHandle;
    ok                      : BOOLEAN;


        (*  SetBufferSize --  Figure out what the maximum y-coordinate
                              will be for the next block to be allocated,
                              and decrement the count of the number of
                              screen lines yet unaccounted for.
        *)

    PROCEDURE SetBufferSize ();
    BEGIN
        IF (LinesToGo <= LinesPerBuffer) THEN
            LocalLRY := LRY;
            LinesToGo := 0;
        ELSE
            LocalLRY := ULY + LinesPerBuffer - 1;
            DEC (LinesToGo, LinesPerBuffer);
        END;
    END SetBufferSize;


BEGIN
    (* RSC 25-Sep-89:

        As of today, GetExtStatus returns:

            ExtGood     if There is virtual memory available
            ExtQueazy   if we are out of virtual memory, but there may
                           be heap space.
            ExtDamaged  if FlexStor is now "interlocked", or executing.

        The deal is that If FlexStor runs out of space, it complains via
        a call to Error(), which calls this procedure for a rug.
        This proc calls FlexStor again, and FlexStor is not capable of
        this kind of reentrancy.
    *)
    ok := (GetExtStatus() <> ExtDamaged);

    IF (ok) THEN
        Overhead := TSIZE(ARugRecord) - TSIZE(AnImage);
        LineSize := (LRX-ULX+1) * 2;            (* bytes per line *)

        (*  LinesPerBuffer is the maximum number of screen lines we can
            fit in a single block.  *)

        LinesPerBuffer := (MaximumRecordSize() - Overhead) DIV LineSize;

        LinesToGo := (LRY - ULY + 1);
        SetBufferSize();

        ok := (CreateRugBuffer (ULX, ULY, LRX, LocalLRY, Rug));   (* 26-Sep-89 LAA/RSC *)

        IF (ok) THEN
            INC (RugsInUse);

            ThisBuffer := AnExtHandle(Rug);
            WHILE (ok AND (LinesToGo > 0)) DO

                INC (ULY, LinesPerBuffer);
                SetBufferSize();

                ok := (CreateRugBuffer (ULX, ULY, LRX, LocalLRY, NextBuffer));
                IF (ok) THEN
                    IF (LockObject (ThisBuffer, RugRecord) = 0) THEN
                        FatalError();
                    END;
                    RugRecord^.NextRRH := NextBuffer;
                    ReleaseObject (ThisBuffer);
                    ThisBuffer := NextBuffer;
                ELSE
                    DisposeRug (Rug);
                END;
            END;
        END;
    END;

    RETURN ok;

END CreateRug;




PROCEDURE DisposeRug(VAR Rug : ARug);

VAR
    Size            : CARDINAL;
    NextBuffer      : AnExtHandle;
    RugRecord       : ARugRecordPointer;

BEGIN
    DEC( RugsInUse );

        (*  Deallocate each of the buffers, one at a time  *)

    WHILE (Rug <> AnExtHandle(NIL)) DO
        Size := LockObject (Rug, RugRecord);
        IF (Size = 0) THEN
            FatalError();
        END;

        DEC (RugBytes, Size);
        NextBuffer := RugRecord^.NextRRH;
        ReleaseUnchangedObject (Rug);
        DiscardExtObject (Rug);

        Rug := NextBuffer;
    END;
END DisposeRug;





    (* GetRug -- Reads an area of the screen bounded at the upper left
                 by (ULX,ULY) and at the lower right by (LRX,LRY).  This
                 allocates temporary storage from the heap for the
                 screen data, and returns a pointer to it. *)

PROCEDURE GetRug(    ULX                    : ascreenx;
                     ULY                    : ascreeny;
                     LRX                    : ascreenx;
                     LRY                    : ascreeny;
                 VAR Rug                    : ARug)
                                                   : BOOLEAN;

VAR
    LineAddress : ADDRESS;
    Count       : CARDINAL;
    Y           : CARDINAL;
    RugRecord   : ARugRecordPointer;
    s           : ARRAY [0..99] OF CHAR;
    ThisBuffer  : AnExtHandle;
    NextBuffer  : AnExtHandle;

BEGIN
    IF (ProgramState < RootRunning) AND (NOT InitializationOK) THEN
        RETURN FALSE;
    END;

    IF (LRX > maxcol) THEN LRX := maxcol; END;
    IF (LRY > maxrow) THEN LRY := maxrow; END;
    IF (LRX < ULX) OR (LRY < ULY) THEN
        RETURN FALSE;
    END;

    IF (CreateRug(ULX,ULY,LRX,LRY,Rug))  THEN

            (*  Step through all the blocks, saving the appropriate portions
                of the screen to each  *)

        ThisBuffer := Rug;
        WHILE (ThisBuffer <> AnExtHandle(NIL)) DO
            IF (LockObject (ThisBuffer, RugRecord) = 0) THEN
                FatalError();
            END;

            GetCursorType(RugRecord^.CursorType);
            GetCursorLocation(RugRecord^.CursorX, RugRecord^.CursorY );
                (*  Set the type because GetCursorLocation has the side-effect
                    of turning the hardware cursor back on.  DOS does this.
                *)
            SetCursorType(RugRecord^.CursorType);              (* 29-Dec-87 LAA *)

            (*  Copy from the screen to the image area. *)
            LineAddress := ADR(RugRecord^.Image);
            Count := LRX - ULX + 1;
            RugRecord^.XCount := Count;

                (*  Loop only through the Y coordinates corresponding to
                    the Uly and Lry of THIS block.  *)

            Y := RugRecord^.Uly;
            WHILE (Y <= RugRecord^.Lry) DO
                GetImageLine(ULX,Y,Count,LineAddress);
                INC(Y);
                INC(LineAddress,Count*2);
            END;

            NextBuffer := RugRecord^.NextRRH;
            ReleaseObject (ThisBuffer);
            ThisBuffer := NextBuffer;
        END;
        RETURN TRUE;
    END;
    InitializationOK := FALSE; (* In case we are starting up now *)
    RETURN FALSE;
END GetRug;


(*----------------------------------------------------------------------------
    DisplayRug --

    Put the contents of the rug back on the screen at the specified
    coordinates, but do not dispose of the rug.  If you want to both display
    and dispose of the rug, use PutRug.
----------------------------------------------------------------------------*)

PROCEDURE DisplayRug(    ULX                : ascreenx;
                         ULY                : ascreeny;
                         LRX                : ascreenx;
                         LRY                : ascreeny;
                         Rug                : ARug);

VAR
    LineAddress : ADDRESS;
    Count       : CARDINAL;
    DeltaX      : CARDINAL;
    Y           : CARDINAL;
    WordsUsed   : CARDINAL;
    RugRecord   : ARugRecordPointer;
    NextBuffer  : AnExtHandle;
    LineCount   : CARDINAL;

BEGIN                   (* DisplayRug *)
    IF (LRX > maxcol) THEN LRX := maxcol; END;
    IF (LRY > maxrow) THEN LRY := maxrow; END;
    IF (LRX < ULX) OR (LRY < ULY) THEN
        FatalError;
    END;

    WHILE (Rug <> AnExtHandle(NIL)) DO
        IF (LockObject (Rug, RugRecord) = 0) THEN
            FatalError();
        END;

        IF (RugRecord^.Tag <> RugTag) THEN
            FatalError();
        END;

        SetCursorType(RugRecord^.CursorType);
        SetCursorLocation(RugRecord^.CursorX, RugRecord^.CursorY );

        LineAddress := ADR(RugRecord^.Image);
        Count := LRX-ULX + 1;                    (* Words per line. *)
        DeltaX := RugRecord^.XCount * 2;
        LineCount := RugRecord^.Lry - RugRecord^.Uly + 1;

            (*  Loop through the maximum y-coordinate of this block, or
                the maximum y-coordinate of the whole screen region,
                whichever is smaller.  *)

        Y := ULY;
        WHILE (Y <= LRY) AND (Y <= ULY+LineCount-1) DO
            PutImageLine(ULX,Y,Count,LineAddress);
            INC(Y);
            INC(LineAddress,DeltaX);
        END;
        INC (ULY, LineCount);

        NextBuffer := RugRecord^.NextRRH;
        ReleaseUnchangedObject (Rug);
        Rug := NextBuffer;
    END;
END DisplayRug;



    (*  PutRug -- Restores a stored area of the screen and deallocates
                  the heap space used by it. *)

PROCEDURE PutRug(    ULXIgnore              : ascreenx;
                     ULYIgnore              : ascreeny;
                     LRXIgnore              : ascreenx;
                     LRYIgnore              : ascreeny;
                 VAR Rug                    : ARug);
VAR
    RugRecord   : ARugRecordPointer;
    ULX, LRX    : ascreenx;
    ULY, LRY    : ascreeny;
    ThisBuffer  : AnExtHandle;
    NextBuffer  : AnExtHandle;

BEGIN
    ULY := MAXCARDINAL;
    LRY := 0;

        (*  Find the overall LRY and ULY by looking at all of the rug
            buffers.  ULX and ULY should be the same for each, so no
            comparisons are necessary.
        *)

    ThisBuffer := Rug;
    WHILE (ThisBuffer <> AnExtHandle(NIL)) DO
        IF (LockObject (ThisBuffer, RugRecord) = 0) THEN
            FatalError();
        END;

        WITH RugRecord^ DO
            ULX := Ulx;
            LRX := Lrx;
            IF (Uly < ULY) THEN
                ULY := Uly;
            END;
            IF (Lry > LRY) THEN
                LRY := Lry;
            END;
        END;

        NextBuffer := RugRecord^.NextRRH;
        ReleaseUnchangedObject (ThisBuffer);
        ThisBuffer := NextBuffer;
    END;

    DisplayRug(ULX, ULY, LRX, LRY, Rug);
    DisposeRug(Rug);
END PutRug;





(*----------------------------------------------------------------------------
    ThrowRug --

    Throw the rug away without displaying it's contents on the screen.
----------------------------------------------------------------------------*)

PROCEDURE ThrowRug(VAR Rug                  : ARug);

BEGIN                       (* ThrowRug *)

    (* Just for you, Andrew! *)
    DisposeRug(Rug);

END ThrowRug;



(*----------------------------------------------------------------------------
    CreateBlankRug --

    Create a rug of the indicated height and width, where all characters are
    blank with videonormal mode.

    Preconditions:
        The height must be in the range 1..maxrow + 1, and the width must be
        in the range 1..maxcol + 1.

    Postcondtions:
        If sufficient memory is available, the rug will be created and
        initialized as indicated above, and the rug will be returned.  If
        there isn't sufficient memory, NIL will be returned.
----------------------------------------------------------------------------*)

PROCEDURE CreateBlankRug(    Width          : CARDINAL;
                             Height         : CARDINAL)
                                                       : ARug;

VAR
    LineAddress             : POINTER TO BYTE;
    i                       : CARDINAL;
    RugRecord               : ARugRecordPointer;
    Rug                     : ARug;
    ImageWord               : WORD;
    s                       : ARRAY [0..99] OF CHAR;
    ThisBuffer              : AnExtHandle;
    NextBuffer              : AnExtHandle;
    LocalHeight             : CARDINAL;

BEGIN                       (* CreateBlankRug *)

    IF (Width > maxcol + 1) THEN
        Width := maxcol + 1;
    END;
    IF (Height > maxrow + 1) THEN
        Height := maxrow + 1;
    END;

    ImageWord  := WORD(2000H+(CARDINAL(vidctrl[videonormal]) MOD 256));

    IF (CreateRug(0, 0, Width - 1, Height - 1, Rug)) THEN
        ThisBuffer := Rug;
        WHILE (ThisBuffer <> AnExtHandle(NIL)) DO
            IF (LockObject (ThisBuffer, RugRecord) = 0) THEN
                FatalError();
            END;

            WITH RugRecord^ DO
                CursorType := 0;
                CursorX    := 0;
                CursorY    := 0;
                (*  Copy from the screen to the image area. *)
                XCount     := Width;

                    (*  Compute a height for this block, and write only
                        as many words as needed to fill that.   *)

                LocalHeight := Lry - Uly + 1;
                FOR i := 0 TO LocalHeight * Width - 1 DO
                    Image[i] := ImageWord;
                END;
            END;

            NextBuffer := RugRecord^.NextRRH;
            ReleaseObject (ThisBuffer);
            ThisBuffer := NextBuffer;
        END;
        RETURN Rug;
    END;
    RETURN ARug(NIL);

END CreateBlankRug;




(*----------------------------------------------------------------------------
    CopyOfRug --

    Create a new rug which is an exact copy of the one given.

    Preconditions:
        The rug to be copied must be a valid rug.

    Postcondtions:
        If there is sufficient memory to create a new rug of the appropriate
        size, it will be created, initialized to be a copy of the source
        rug, and returned.  Otherwise, NIL will be returned.
----------------------------------------------------------------------------*)

PROCEDURE CopyOfRug(    SourceRug           : ARug)
                                                   : ARug;

VAR
    NewRug                  : ARug;
    i                       : CARDINAL;

BEGIN                       (* CopyOfRug *)
    RETURN ARug(NIL);
END CopyOfRug;





(*----------------------------------------------------------------------------
    PutStringToRug --

    Write the given LString onto the rug with the video mode indicated.  The
    x and y coordinates are relative to the upper left corner of the rug.

    Preconditions:
        The LString and rug must be valid.  The coordinates given must be
        within the height and width of the rug.

    Postconditions:
        As much of the LString as will fit will be written to the rug at the
        indicated coordinates.  If the LString is null, nothing will be
        changed.
----------------------------------------------------------------------------*)

PROCEDURE PutStringToRug(VAR String         : ARRAY OF CHAR;
                             X              : ascreenx;
                             Y              : ascreeny;
                             VideoMode      : avidmode;
                             Rug            : ARug         );

VAR
    RugRecord               : ARugRecordPointer;
    i                       : CARDINAL;
    j                       : CARDINAL;
    NextBuffer              : AnExtHandle;
    Changed                 : BOOLEAN;
    LineCount               : CARDINAL;

BEGIN                       (* PutStringToRug *)

    Changed := FALSE;

    WHILE (Rug <> AnExtHandle(NIL)) AND (NOT Changed) DO
        IF (LockObject (Rug, RugRecord) = 0) THEN
            FatalError();
        END;

        WITH RugRecord^ DO
            LineCount := Lry - Uly + 1;

            IF (Y < LineCount) THEN

                (*  This is the correct buffer *)

                i := Y * XCount + X;
                FOR j := 1 TO LengthOf(String) DO
                    IF (X + j) > XCount THEN
                        ReleaseObject (Rug);
                        RETURN;
                    END;
                    Image[i] := WORD(CARDINAL(vidctrl[VideoMode]) * 0100H
                               + ORD(String[j]));
                    INC(i);
                END;
                Changed := TRUE;
            ELSE
                DEC (Y, LineCount);
            END;
        END;

        NextBuffer := RugRecord^.NextRRH;
        IF (Changed) THEN
            ReleaseObject (Rug);
        ELSE
            ReleaseUnchangedObject (Rug);
        END;
        Rug := NextBuffer;
    END;

END PutStringToRug;





(*----------------------------------------------------------------------------
    PutVideoModeToRug --

    Change the video mode of the characters in the rug to be as indicated.
    This starts at the x and y coordinates given, and continues for the
    length specified, or until the end of that line is encountered.

    Preconditions:
        The x and y coordinates must be within the rug, and are relative to
        the upper left corner of the rug.  The rug must already exist.

    Postconditions:
        The video mode of characters at the indicated position, for the
        given length, will be set as appropriate to the video mode.  The
        data characters will not be altered.
----------------------------------------------------------------------------*)

PROCEDURE PutVideoModeToRug(    VideoMode   : avidmode;
                                Length      : CARDINAL;
                                X           : ascreenx;
                                Y           : ascreeny;
                                Rug         : ARug    );

VAR
    RugRecord               : ARugRecordPointer;
    LineAddress             : ADDRESS;
    Attribute               : POINTER TO BYTE;
    j                       : CARDINAL;
    NextBuffer              : AnExtHandle;
    Changed                 : BOOLEAN;
    LineCount               : CARDINAL;

BEGIN                       (* PutVideoModeToRug *)

    Changed := FALSE;

    WHILE (Rug <> AnExtHandle(NIL)) AND (NOT Changed) DO
        IF (LockObject (Rug, RugRecord) = 0) THEN
            FatalError();
        END;

        WITH RugRecord^ DO
            LineCount := Lry - Uly + 1;

            IF (Y < LineCount) THEN

                (*  This is the correct buffer *)

                LineAddress := ADR(Image);
                INC(LineAddress, Y * (2 * XCount) + 2 * X + 1);
                FOR j := 1 TO Length DO
                    IF (X + j) > XCount THEN
                        ReleaseObject (Rug);
                        RETURN;
                    END;
                    Attribute := LineAddress;
                    Attribute^ := BYTE(CHR(CARDINAL(vidctrl[VideoMode]) MOD 256));
                    INC(LineAddress, 2);
                END;
                Changed := TRUE;
            ELSE
                DEC (Y, LineCount);
            END;
        END;

        NextBuffer := RugRecord^.NextRRH;
        IF (Changed) THEN
            ReleaseObject (Rug);
        ELSE
            ReleaseUnchangedObject (Rug);
        END;
        Rug := NextBuffer;
    END;

END PutVideoModeToRug;




(*----------------------------------------------------------------------------
    PutRugAt --

    Restore the contents of the rug to the screen at the indicated
    coordinates, and discard the rug.

    Preconditions:
        The coordinates must be within the screen area.  The rug must be
        valid.

    Postconditions:
        The contents of the rug will be written into screen display memory,
        and the rug disposed of.
----------------------------------------------------------------------------*)

PROCEDURE PutRugAt(    ULX                  : ascreenx;
                       ULY                  : ascreeny;
                       LRX                  : ascreenx;
                       LRY                  : ascreeny;
                   VAR Rug                  : ARug   );

BEGIN                       (* PutRugAt *)

    DisplayRug(ULX, ULY, LRX, LRY, Rug);
    DisposeRug(Rug);

END PutRugAt;


BEGIN
    RugsInterlock := FALSE;
    RugBytes      := 0;
    RugsInUse     := 0;
END Rugs.
