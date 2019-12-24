(*----------------------------------------------------------------------------
    WARNING !  
        This module contains assembly code optimized procedures.  Beware of
        porting this to another machine incompatible with the 8086.  Do not
        remove the assembly under penality of great performance degradation.

    MODIFICATION HISTORY --
    
    12-Oct-87 LAA   Changed Compress to strip off trailing blanks as well as
                    trailing EOL's.
    04-Nov-87 LAA   In AssignLine, EOL was being put into the byte past the
                    last allocated byte of odd length expansion strings.  
                    Fixed bug which resulted in garbage lines when going 
                    from the task form into the editor.
    10-Dec-87 RSC   Fixes for flexstor.
    11-Jan-88 LAA   Changed ReleaseObject to ReleaseUnchangedObject where
                    appropriate.
    16-Feb-88 LAA   Writing one byte past where I should.  Just like fix of
                    4-Nov-87.
    18-Feb-88 LAA   Changed the cAllocIncrement to be smaller.  Put in more
                    safety checks.  Then I backed it out again.
    22-Feb-88 LAA  - Force stack checking on for this module.
    02-Mar-88 LAA  - In AssignLine and AppendLine, rewrote so that we can't
                     get too near the FlexStor limit on object size, and
                     accounted for extra EOL's that are sometimes written.
    09-Mar-88 LAA  - Set allocation to SourceText^.allocation, rather than
                     its length, since they can be different.
    30-Sep-88 LAA   Reorganized the structure of AText so that FlexStor 
                    buffers can be half as small, and yet allow texts at least
                    as big as before.
    06-Oct-88 LAA   Yet another step in the above reorganization.
    12-Oct-88 RSC   Made the buffer size a run time parm.
    18-Oct-88 LAA   AssignLine will now treat the Text as an array of lines,
                    appending empty lines as necessary in order to put a line
                    at the indicated line number within the text.  This only
                    occurs if the line number is greater than the last line.
    19-Oct-88 LAA   Kudos to Ed for finding a bug here.  In AssignLine, I had
                    "forgotten" to move the EOL character when expanding a 
                    line.  I also put in some other suggested changes to clean
                    up the code.
    21-Oct-88 LAA   Well, he found another one.  In AssignLine, I wasn't
                    including TextBlockHeaderSize in a comparison.  Oops!
                    Also changed default text size to 288 from 300.
    24-Oct-88 LAA   Ed's testing found another one.  This time (in AssignLine)
                    it was a confusion over the origins of different numbers.
                    Line counts start at 1, but positions in the String start
                    at 0.  This means that if you ask for the StartOfLine n
                    it returns you the start of the (n + 1)th line.
    23-Jan-89 RSC   Changed Storage to Space.
    30-Jun-89 LAA   Prevented cardinal overflow in SizeOfText if the text is
                    bigger than 65K.  It'll just max out at 65K and return
                    that number.
    21-Aug-89 RSC   When creating a text block, check ExtStatus to make sure
                    there is enough flexstor left.
    18-Sep-89 LAA   Use NO heap space for Texts.  This has become imperative
                    since we decided to keep WBS, OBS, and Keyword (as well as
                    AUX1-21 in a Text.  Without this change, each task which
                    has any one of those fields takes up 10 bytes more of real
                    memory than in version 3.0 - which would noticably
                    decrease the capacity of 4.0 below 3.0.
    10-Jan-90 LAA   MAJOR CHANGE!!!  And just in time for the deadline!  I
                    can't believe I'm really doing this 1 week before we ship!
                    It's the dark side of the force - I'm not responsible.
                    Anyway, Larry's Folly is that I've changed the internal
                    structure of AText, so that instead of separating lines
                    with the EOL character, lines are kept as LString (each
                    line is preceeded by it's length).  The reason for this
                    madness is that is clears the way for AText to hold 
                    BINARY data instead of just text characters, which may save
                    out asses for both Ajida and for improving the speed and
                    quality of the PERT view.  I know I'll regret this, but
                    it's something I've been wanting to fix for the longest
                    time.

    11-Sep-90 RSC   "Who is the more foolish?  The Fool, or the fool who
                    follows him?" - Obewan.

                    Make the text blocks dynamic lengthed to cut down on the
                    total number of blocks (and therefore, flex handles) in
                    use.  Could perhaps speed things up too.

     9-Jan-91 AJL -Corrected the definition of AssignLine.

    31-Jan-91 RSC  Added ForEachLine and AppendManyLines.  Also changed the
                   structure to have no header block.  The first block is
                   just another ordinary block.  I moved the Tag into each
                   block, but removed FirstBlock and LastBlock, as that is
                   the first block encountered.

                   This is to cut the locks of text records in half, on
                   average.

    12-Feb-91 RSC  Mass Text writing was not working right.
    20-Feb-91 RSC  AssignText was not copying blocks corectly.  I introduced
                   this when I removed any concept of a header.
     1-Mar-91 RSC  Readded an accidently removed line of code.
    04-Mar-91 PFG  Fixed a problem in FindLine.  The "ok" variable needed
                   to be initialized to TRUE.
    13-Mar-91 RSC  On DiscardText, set the text to NIL.
    15-Mar-91 AJL  Correct above change to set text to AText(NIL) so the 
                   program will compile.
    17-Jul-91 LAA  To improve error checking, changed all calls to LockObject
                   to calls to LocalLockObject, which also assures a non-zero
                   object size.
-----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE Text;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC *)                  CreateExtObjectWithSize, DiscardExtObject,
                                LockObject, ReleaseObject,
                                GetExtSize, SetExtSize,
                                CopyExtObject, ReleaseUnchangedObject,
                                MaximumRecordSize, HandleIsValid,
                                ObjectsAreSame, GetExtStatus;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, StoC, Search, Fill, SetLengthOf,
                                LengthOf, Copy;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  CODE, TSIZE, ADR;



CONST
    MaxFlexStorSize         = 3200; (* 11-Sep-90 RSC was 3500.  This is safer. *)
    TextBlockHeaderSize     = 10;
    TextBlockStringSize     = MaxFlexStorSize - TextBlockHeaderSize;  (* ATextBlock must total no more than MaxFlexStorSize *)
    AllocationSize          = 288;  (* must be > 270, < MaxFlexStorSize *)
    TextTag                 = 4552;
    MaxCardinal             = 0FFFFH;

TYPE
    AText                   = AnExtHandle; (* --> ATextBlock *)

    ATextBlockPtr           = POINTER TO ATextBlock;

        (*  This is allocated from FlexStor  *)

    ATextBlock              = RECORD
                                Tag         : CARDINAL;
                                Next        : AnExtHandle;
                                LineCount   : CARDINAL;
                                Length      : CARDINAL;
                                String      : ARRAY [0..TextBlockStringSize-1] 
                                              OF CHAR;
                              END;





(*----------------------------------------------------------------------------
    MoveBytes --

    Move bytes between two arrays, using offsets and size limits.
----------------------------------------------------------------------------*)

PROCEDURE MoveBytes(VAR Source              : ARRAY OF CHAR;       (* in     *)
                        SIndex              : CARDINAL;            (* in     *)
                        SSize               : CARDINAL;            (* in     *)
                    VAR Destination         : ARRAY OF CHAR;       (*    out *)
                        DIndex              : CARDINAL);           (* in     *)

VAR
    i                       : CARDINAL;

BEGIN                       (* MoveBytes *)

    IF SSize > 0 THEN
(*      FOR i := 0 TO SSize - 1 DO
            Destination[DIndex] := Source[SIndex];
            INC(DIndex);
            INC(SIndex);
        END;
*)
        CODE(
            01EH,           (* PUSH  DS           ; Save value of DS reg.    *)
            08BH,04EH,00CH, (* MOV   CX,[BP+0C]   ; SSize ---> CX            *)
            0C5H,076H,010H, (* LDS   SI,[BP+10]   ; ADR(Source) ---> DS,SI   *)
            003H,076H,00EH, (* ADD   SI,[BP+0E]   ; Add SIndex to SI         *)
            0C4H,07EH,006H, (* LES   DI,[BP+06]   ; ADR(Destination) -> ES,DI*)
            003H,07EH,004H, (* ADD   DI,[BP+04]   ; Add DIndex to DI         *)
            0FCH,           (* CLD                ; Set to increment SI,DI   *)
            0F3H,0A4H,      (* REP   MOVSB        ; Move SI to DI until CX=0 *)
            01FH);          (* POP   DS           ; Restore DS reg value.    *)
            
    END;

END MoveBytes;



PROCEDURE LocalLockObject(     Handle       : AnExtHandle;
                           VAR Pointer      : ADDRESS    ) : CARDINAL;

VAR
    i                       : CARDINAL;

BEGIN                       (* LocalLockObject *)

    i := LockObject( Handle, Pointer );
    IF (i = 0) THEN FatalError(); END;

    RETURN i;

END LocalLockObject;


(*----------------------------------------------------------------------------
    StartOfLineN --

    Determine the position within a string of the first character of line N.
    Line numbers start at 0.
----------------------------------------------------------------------------*)

PROCEDURE StartOfLineN(VAR String           : ARRAY OF CHAR;       (* in     *)
                           Length           : CARDINAL;            (* in     *)
                           N                : CARDINAL     )       (* in     *)
                                                            : CARDINAL;

VAR
    i                       : CARDINAL;
    linecount               : CARDINAL;

BEGIN                       (* StartOfLineN *)

    i := 0;
    linecount := 0;

    WHILE ((i < Length) AND (linecount < N)) DO
        INC( i, ORD( String[i] ) + 1 );                        (* 10-Jan-90 *)
        INC( linecount );
    END;

    RETURN i;
    
END StartOfLineN;



(*----------------------------------------------------------------------------
    BlockOfLineN --

    Determine the TextBlock of a text within which line N falls.  Returns 
    also a count of the number of lines in blocks before the one containing 
    line N.  If no block contains line N, the TextBlock will be returned NIL.
----------------------------------------------------------------------------*)

PROCEDURE BlockOfLineN(    Text             : AText;
                           N                : CARDINAL;
                       VAR TextBlockHandle  : AnExtHandle;
                       VAR LinesBefore      : CARDINAL   );

VAR
    nextblock               : AnExtHandle;
    block                   : ATextBlockPtr;
    AllocatedSize           : CARDINAL;
    done                    : BOOLEAN;

BEGIN                       (* BlockOfLineN *)

    done            := FALSE;
    LinesBefore     := 0;
    TextBlockHandle := Text;

    WHILE ((NOT done) AND (ADDRESS(TextBlockHandle) <> NIL)) DO
        AllocatedSize := LocalLockObject(TextBlockHandle, block);
        WITH block^ DO
            IF (Tag <> TextTag) THEN
                FatalError();
            END;
            IF (LineCount = 0) THEN (* Block empty.  Probably new. *)
                nextblock := AnExtHandle(NIL);
            ELSIF (N > LineCount - 1) THEN
                INC(LinesBefore, LineCount);
                DEC(N, LineCount);
                nextblock := Next;
            ELSE
                done := TRUE;
            END;
        END;
        ReleaseUnchangedObject(TextBlockHandle);

        IF (NOT done) THEN
            TextBlockHandle := nextblock;
        END;
    END;

END BlockOfLineN;




(*----------------------------------------------------------------------------
    InsertAfter --

    Link the SuccHandle into the list after the PredHandle.
----------------------------------------------------------------------------*)

PROCEDURE InsertAfter(    PredHandle        : AnExtHandle;
                          SuccHandle        : AnExtHandle);

VAR
    oldnext                 : AnExtHandle;
    block                   : ATextBlockPtr;
    AllocatedSize           : CARDINAL;

BEGIN                       (* InsertAfter *)

    oldnext := AnExtHandle(NIL);
    IF (ADDRESS(PredHandle) <> NIL) THEN
        AllocatedSize := LocalLockObject(PredHandle, block);
        oldnext       := block^.Next;
        block^.Next   := SuccHandle;
        ReleaseObject(PredHandle);
    END;

    AllocatedSize := LocalLockObject(SuccHandle, block);
    block^.Next   := oldnext;
    ReleaseObject(SuccHandle);

END InsertAfter;





(*----------------------------------------------------------------------------
    CreateNewBlock --

    Create an instance of ATextBlock, and initialize it.
----------------------------------------------------------------------------*)

PROCEDURE CreateNewBlock(    Size           : CARDINAL): AnExtHandle;

VAR
    handle              : AnExtHandle;
    block               : ATextBlockPtr;

BEGIN                   (* CreateNewBlock *)

    handle := AnExtHandle(NIL);
    IF (GetExtStatus() = ExtGood) AND   (* 21-Aug-89 *)
       (CreateExtObjectWithSize(handle, ExtSlow, Size)) THEN
        IF (LocalLockObject(handle, block) <> Size) THEN
            FatalError();
        END;
        WITH block^ DO
            Tag       := TextTag;
            Length    := 0;
            LineCount := 0;
            Next      := AnExtHandle(NIL);
        END;
        ReleaseObject(handle);
    END;

    RETURN handle;

END CreateNewBlock;







(*----------------------------------------------------------------------------
    CreateText --

    Create an instance of AText, with no storage allocated.
----------------------------------------------------------------------------*)

PROCEDURE CreateText() : AText;
BEGIN                       (* CreateText *)

    RETURN AText(CreateNewBlock(AllocationSize));

END CreateText;





(*----------------------------------------------------------------------------
    DiscardText --

    Discard a previously created instance of AText.  Storage will be 
    deallocated, and the string stored in this text will be lost.
----------------------------------------------------------------------------*)

PROCEDURE DiscardText(VAR Text              : AText);             (* in/out *)

VAR
    blockhandle             : AnExtHandle;
    nexthandle              : AnExtHandle;
    block                   : ATextBlockPtr;
    AllocatedSize           : CARDINAL;

BEGIN                       (* DiscardText *)

    blockhandle := Text;
    WHILE (ADDRESS(blockhandle) <> NIL) DO
        AllocatedSize := LocalLockObject(blockhandle, block);
        nexthandle    := block^.Next;
        ReleaseUnchangedObject(blockhandle);
        DiscardExtObject(blockhandle);
        blockhandle   := nexthandle;
    END;

    Text := AText(NIL);

END DiscardText;





(*----------------------------------------------------------------------------
    SizeOfText --

    Return the length of the specified text in bytes;
----------------------------------------------------------------------------*)

PROCEDURE SizeOfText(    Text               : AText)              (* in     *)
                                                    : CARDINAL;

VAR
    j                       : CARDINAL;
    AllocatedSize           : CARDINAL;
    blockhandle             : AnExtHandle;
    nexthandle              : AnExtHandle;
    block                   : ATextBlockPtr;

BEGIN                       (* SizeOfText *)

    j := 0;
    blockhandle := Text;
    WHILE (ADDRESS(blockhandle) <> NIL) DO
        AllocatedSize := LocalLockObject(blockhandle, block);
        nexthandle    := block^.Next;
        IF (block^.Length < (MaxCardinal - j)) THEN           (* 30-Jun-89 LAA *)
            INC(j, block^.Length);
        END;
        ReleaseUnchangedObject(blockhandle);
        blockhandle := nexthandle;
    END;

    RETURN j;

END SizeOfText;





(*----------------------------------------------------------------------------
    TextExists --

    Determine if the given text exists, i.e. is not NIL.
----------------------------------------------------------------------------*)

PROCEDURE TextExists(    Text               : AText)              (* in     *)
                                                    : BOOLEAN;

BEGIN                       (* TextExists *)

    RETURN (HandleIsValid(Text));

END TextExists;





(*----------------------------------------------------------------------------
    AssignText --

    Copy one text onto another.  If the destination text does not exist,
    it will be created.  If it does exist, it's current contents will be
    lost.
----------------------------------------------------------------------------*)

PROCEDURE AssignText(    SourceText         : AText;              (* in     *)
                     VAR DestinationText    : AText)              (* in/out *)
                                                    : BOOLEAN;

VAR
    AllocatedSize           : CARDINAL;
    LastBlock               : AnExtHandle;
    blockhandle             : AnExtHandle;
    nexthandle              : AnExtHandle;
    desthandle              : AnExtHandle;
    block                   : ATextBlockPtr;
BEGIN                       (* AssignText *)

    DestinationText := AText(NIL);

    IF (SourceText = AText(NIL)) THEN RETURN TRUE; END;

    LastBlock       := AText(NIL);
    blockhandle     := SourceText;
    DestinationText := AText(NIL);  (* 20-Feb-91 RSC  *)

    WHILE (ADDRESS(blockhandle) <> NIL) DO

        AllocatedSize := LocalLockObject(blockhandle, block);
        nexthandle    := block^.Next;
        ReleaseUnchangedObject(blockhandle);

        IF (NOT CopyExtObject(blockhandle, ExtSlow, desthandle)) THEN
            DiscardText(DestinationText);
            RETURN FALSE;
        END;

        IF (DestinationText  = AText(NIL)) THEN (* 20-Feb-91 RSC  *)
            DestinationText := desthandle;      (* 20-Feb-91 RSC  *)
        END;                                    (* 20-Feb-91 RSC  *)

        InsertAfter(LastBlock, desthandle);

        LastBlock   := desthandle;              (* 20-Feb-91 RSC  *)
        blockhandle := nexthandle;
    END;

    RETURN TRUE;

END AssignText;





(*----------------------------------------------------------------------------
    Compress --

    Compress the Text so it consumes the minimum possible space.
----------------------------------------------------------------------------*)

PROCEDURE Compress(VAR Text                 : AText);             (* in/out *)
BEGIN                       (* Compress *)
END Compress;





(*----------------------------------------------------------------------------
    LineExists --

    Determine if line N exists in the Text.
----------------------------------------------------------------------------*)

PROCEDURE LineExists(    Text               : AText;              (* in     *)
                         N                  : CARDINAL)           (* in     *)
                                                       : BOOLEAN;

VAR
    handle                  : AnExtHandle;
    i                       : CARDINAL;
BEGIN                       (* LineExists *)

    BlockOfLineN( Text, N, handle, i);

    RETURN (ADDRESS(handle) <> NIL);

END LineExists;





(*----------------------------------------------------------------------------
    CopyLine --

    Make a copy of line N of the Text, as an LString.  Return a blank line 
    if there is no corrosponding line.  Line numbers start at zero.
----------------------------------------------------------------------------*)

PROCEDURE CopyLine(    Text                 : AText;              (* in     *)
                       N                    : CARDINAL;           (* in     *)
                   VAR Line                 : ARRAY OF CHAR);     (*    out *)

VAR
    AllocatedSize           : CARDINAL;
    handle                  : AnExtHandle;
    block                   : ATextBlockPtr;
    i                       : CARDINAL;
    numbefore               : CARDINAL;
    SourceLString           : POINTER TO ARRAY [0..255] OF CHAR;

BEGIN                       (* CopyLine *)

    SetLengthOf(Line, 0);
    BlockOfLineN( Text, N, handle, numbefore);

    IF (ADDRESS(handle) <> NIL) THEN
        AllocatedSize := LocalLockObject(handle, block);
        WITH block^ DO
            i := StartOfLineN(String, Length, N - numbefore);
            IF (i < Length) THEN
                SourceLString := ADR( String[i] );         (* 10-Jan-90 *)
                Copy( SourceLString^, Line );
            END;
        END;
        ReleaseUnchangedObject(handle);                       (* 11-Jan-88 LAA *)
    END;

END CopyLine;








PROCEDURE MaybeRaiseSize( Block  : AnExtHandle );
VAR
    Size : CARDINAL;
    ok   : BOOLEAN;
BEGIN
    Size := GetExtSize( Block );
    IF (Size < (MaxFlexStorSize - AllocationSize)) THEN
        ok := SetExtSize( Block, Size + AllocationSize );
    END;
END MaybeRaiseSize;





(*----------------------------------------------------------------------------
    AssignLine --

    Assign the String to line N of the specified text.  If N is greater than
    the number of lines in the text, blank lines are inserted up to line N-1, 
    then the String is appended at line N.
----------------------------------------------------------------------------*)


PROCEDURE AssignLine(VAR Line               : ARRAY OF CHAR;      (* in     *)
                         N                  : CARDINAL;           (* in     *)
                         Text               : AText)              (* in/out *)
                                                    : BOOLEAN;

VAR
    handle                  : AnExtHandle;
    newhandle               : AnExtHandle;
    block                   : ATextBlockPtr;
    newblock                : ATextBlockPtr;
    AllocatedSize           : CARDINAL;
    numbefore               : CARDINAL;
    i, j, k                 : CARDINAL;
    oldlinesize             : CARDINAL;
    linelength              : CARDINAL;
    difference              : CARDINAL;
    s                       : ARRAY [0..1] OF CHAR;

BEGIN                       (* AssignLine *)

    IF (Text = AText(NIL)) THEN
        RETURN FALSE;     (* Could not add line *)
    END;

    BlockOfLineN( Text, N, handle, numbefore);
    IF (ADDRESS(handle) = NIL) THEN
        SetLengthOf(s, 0);
        FOR i := numbefore + 1 TO N DO      (*  Shouldn't this be N - 1? *)
            IF (NOT AppendLine(s, Text)) THEN
                RETURN FALSE;
            END;
        END;
        RETURN AppendLine(Line, Text);
    END;

    linelength    := LengthOf( Line ) + 1;                        (* 10-Jan-90 *)
    AllocatedSize := LocalLockObject(handle, block);
    WITH block^ DO
        j := StartOfLineN(String, Length, N - numbefore);
        IF (j >= Length) THEN
            FatalError();
        END;

        k := StartOfLineN(String, Length, N + 1 - numbefore);
    END;

    oldlinesize := k - j;                                  (* 10-Jan-90 *)

            (*  Compare the lengths of the old and replacement lines  *)
    IF (oldlinesize = linelength) THEN

        MoveBytes( Line, 0, linelength, block^.String, j );       (* 10-Jan-90 *)
        ReleaseObject(handle);

    ELSIF (oldlinesize < linelength) THEN                     (* 06-Oct-88 LAA *)

        difference := linelength - oldlinesize;

            (* 11-Sep-90 RSC Try raising the size of this block.
               31-Jan-91 RSC Oops.  Had "<=" rather than ">".
            *)
        IF ((block^.Length + difference + TextBlockHeaderSize) > AllocatedSize) THEN
            ReleaseUnchangedObject(handle);
            MaybeRaiseSize( handle );
            AllocatedSize := LocalLockObject(handle, block);
        END;


        IF ((block^.Length + difference + TextBlockHeaderSize) <= AllocatedSize) THEN (* 21-Oct-88 LAA *)

            WITH block^ DO
                FOR i := Length - 1 TO k BY -1 DO              (* 10-Jan-90 *)
                    String[i + difference] := String[i];
                END;
                MoveBytes(Line, 0, linelength, String, j);     (* 10-Jan-90 *)
                INC(Length, difference);
            END;
            ReleaseObject(handle);

        ELSE
                (*  Split the block into approx. equal parts  *)

            newhandle := CreateNewBlock(AllocatedSize);
            IF (ADDRESS(newhandle) = NIL) THEN
                ReleaseUnchangedObject(handle);
                RETURN FALSE;
            END;
            InsertAfter(handle, newhandle);

                (*  Move second group of lines of new block  *)

            WITH block^ DO
                k := LineCount DIV 2;
                j := StartOfLineN(String, Length, k);             (* 24-Oct-88 LAA *)
                AllocatedSize := LocalLockObject(newhandle, newblock);
                MoveBytes(String, j, Length - j, newblock^.String, 0);
                newblock^.Length := Length - j;
                newblock^.LineCount := LineCount - k;
                ReleaseObject(newhandle); newblock := NIL;
                Length := j;
                LineCount := k;
            END;

            ReleaseObject(handle);

                (*  Call again now that there's space for new line  *)

            RETURN AssignLine(Line, N, Text);
        END;
    ELSE
        WITH block^ DO
            MoveBytes(Line, 0, linelength, String, j);         (* 10-Jan-90 *)
            INC(j, linelength);

                (*  Copy lines after the replaced line  *)
            MoveBytes(String, k, Length - k, String, j); 
            DEC(Length, oldlinesize - linelength);  (* 1-Mar-91 RSC *)
            ReleaseObject(handle);
        END;
    END;
    

    RETURN TRUE;

END AssignLine;




(* INTERNAL PROCEDURE TO AppendLine and AppendManyLines.
    LastBlock is locked, block is the contents of LastBlock, and
    AllocatedSize is how big it was.  Client sets all this up!
    On return, LastBlock could have changed, as could block and
    AllocatedSize.
    
    IF TRUE,  The LastBlock is still locked, and has been modified.
    IF FALSE, no blocks are locked, and the line could not be added.
*)
PROCEDURE AddOneLine( VAR LastBlock     : AnExtHandle;
                      VAR block         : ATextBlockPtr;
                      VAR AllocatedSize : CARDINAL;
                      VAR Line          : ARRAY OF CHAR ) : BOOLEAN;
VAR
    newlength     : CARDINAL;
    linelength    : CARDINAL;
    newblock      : AnExtHandle;

BEGIN
    linelength    := LengthOf( Line ) + 1;                 (* 10-Jan-90 *)
    newlength     := block^.Length + linelength;           (* 10-Jan-90 *)

    (* 11-Sep-90 RSC Perhaps resize the block. *)
    IF ((newlength + TextBlockHeaderSize) > AllocatedSize) THEN
        ReleaseObject( LastBlock );
        MaybeRaiseSize( LastBlock );
        AllocatedSize := LocalLockObject(LastBlock, block);
        newlength     := block^.Length + linelength;           (* 10-Jan-90 *)
    END;

    IF ((newlength + TextBlockHeaderSize) > AllocatedSize) THEN

        ReleaseUnchangedObject(LastBlock);

        (*  add a new block onto the end, put the line there *)
        newblock := CreateNewBlock(AllocationSize);
        IF (ADDRESS(newblock) = NIL) THEN
            RETURN FALSE;
        END;
        InsertAfter(LastBlock, newblock);
        LastBlock := newblock;

        AllocatedSize := LocalLockObject(LastBlock, block);
    END;

    WITH block^ DO (* RSC 10/4/88: block may have changed, and I
                               don't trust the optimizer. *)
        MoveBytes( Line, 0, linelength, String, Length );  (* 10-Jan-90 *)
        INC( Length, linelength );
        INC(LineCount);
    END;

    RETURN TRUE;

END AddOneLine;




(*----------------------------------------------------------------------------
    AppendLine --

    Append the line to the end of the specified text.
----------------------------------------------------------------------------*)

PROCEDURE AppendLine(VAR Line               : ARRAY OF CHAR;       (* in     *)
                         Text               : AText)               (* in/out *)
                                                    : BOOLEAN;
VAR
    AllocatedSize           : CARDINAL;
    block                   : ATextBlockPtr;
    LastBlock,
    newblock                : AnExtHandle;
    ok                      : BOOLEAN;

BEGIN                       (* AppendLine *)

    IF (Text = AText(NIL)) THEN
        RETURN FALSE;     (* Could not add line *)
    END;


        (* 31-Jan-91 RSC     Find the last block.  Not many texts will
                             have more than one block, because blocks can
                             grow to be 3200 bytes or so.
        *)
    LastBlock     := Text;
    AllocatedSize := LocalLockObject(LastBlock, block);
    WHILE (block^.Next <> AnExtHandle(NIL)) DO
        newblock      := block^.Next;
        ReleaseUnchangedObject(LastBlock);
        LastBlock     := newblock;
        AllocatedSize := LocalLockObject(LastBlock, block);
    END;

    ok := AddOneLine( LastBlock, block, AllocatedSize, Line );

    IF (ok) THEN
        ReleaseObject(LastBlock);
    END;

    RETURN ok;

END AppendLine;





(*----------------------------------------------------------------------------
    AppendManyLines --

    Append many lines to the end of the specified text.
    If the text is NIL, it is created first.
----------------------------------------------------------------------------*)

PROCEDURE AppendManyLines(     GetLineProc        : AGetLineProc;
                               GetLineContext     : ADDRESS;
                           VAR Text               : AText
                         ) : BOOLEAN;
VAR
    newlength               : CARDINAL;
    linelength              : CARDINAL;
    AllocatedSize           : CARDINAL;
    block                   : ATextBlockPtr;
    LastBlock,
    newblock                : AnExtHandle;
    Line                    : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN                       (* AppendLine *)

    IF (Text = AText(NIL)) THEN
        Text := CreateText();
        IF (Text = AText(NIL)) THEN
            RETURN FALSE;     (* Could not create text *)
        END;
    END;

    LastBlock     := Text;
    AllocatedSize := LocalLockObject(LastBlock, block);
    WHILE (block^.Next <> AnExtHandle(NIL)) DO
        newblock      := block^.Next;
        ReleaseUnchangedObject(LastBlock);
        LastBlock     := newblock;
        AllocatedSize := LocalLockObject(LastBlock, block);
    END;

    ok := TRUE;

    WHILE (ok AND GetLineProc( Line, GetLineContext )) DO
        ok := AddOneLine( LastBlock, block, AllocatedSize, Line );
    END;

    IF (ok) THEN
        ReleaseObject(LastBlock);
    END;

    RETURN ok;

END AppendManyLines;







(*----------------------------------------------------------------------------
    For Each Line --

    Send each line of the text out to the PutLineProc.
----------------------------------------------------------------------------*)

PROCEDURE ForEachLine(       PutLineProc        : AGetLineProc;
                             PutLineContext     : ADDRESS;
                             Text               : AText
                     ) : BOOLEAN;
VAR
    NextHandle,
    Handle                  : AnExtHandle;
    block                   : ATextBlockPtr;
    AllocatedSize,
    i                       : CARDINAL;
    SourceLString           : POINTER TO ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN
    Handle := Text;
    ok     := TRUE;

    WHILE (ok AND (ADDRESS(Handle) <> NIL)) DO
        AllocatedSize := LocalLockObject(Handle, block);
        i := 0;
        WITH block^ DO
            WHILE ((i < Length) AND ok) DO
                SourceLString := ADR( String[i] );
                ok := PutLineProc( SourceLString^, PutLineContext );
                INC( i, ORD( String[i] ) + 1 );
            END;
            NextHandle := Next;
        END;
        ReleaseUnchangedObject(Handle);
        Handle := NextHandle;
    END;

    RETURN ok;

END ForEachLine;







(*----------------------------------------------------------------------------
    FindLine --

    Find the line containing the pattern specified.  The search begins on the
    specified line N, and N will return with the line found.  Return FALSE if 
    no matching line can be found.
----------------------------------------------------------------------------*)

PROCEDURE FindLine(    Text                 : AText;              (* in     *)
                   VAR Pattern              : ARRAY OF CHAR;      (* in     *)
                   VAR N                    : CARDINAL)           (* in/out *)
                                                       : BOOLEAN;

VAR
    NextHandle,
    Handle                  : AnExtHandle;
    block                   : ATextBlockPtr;
    AllocatedSize,
    i                       : CARDINAL;
    SourceLString           : POINTER TO ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* FindLine *)
    Handle := Text;
    N      := 0;

    WHILE (ADDRESS(Handle) <> NIL) DO
        AllocatedSize := LocalLockObject(Handle, block);
        i := 0;
        ok := TRUE;                 (*  PFG 4-Mar-91  *)
        WITH block^ DO
            WHILE ((i < Length) AND ok) DO
                SourceLString := ADR( String[i] );
                IF Search(SourceLString^, Pattern, 1) > 0 THEN
                    RETURN TRUE;
                END;
                INC(N);
                INC( i, ORD( String[i] ) + 1 );
            END;
            NextHandle := Next;
        END;
        ReleaseUnchangedObject(Handle);
        Handle := NextHandle;
    END;

    RETURN FALSE;

END FindLine;



END Text.


