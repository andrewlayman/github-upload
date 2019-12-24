IMPLEMENTATION MODULE Menus;


    (* MODIFICATION HISTORY:

       Sep. 5, 1985   AL -  Modified CleanUp to only copy into Name
                            as much as will fit.  This may not return
                            the entire name, but it won't cause a
                            fatal error, either.
       Sep. 5, 1985   AL -  Use Rugs to get and restore screen.

       May 7, 1986    AL -  In Menu2 made Nextx a CARDINAL so that
                            it can temporarily go off screen.

       Jun 3, 1986   AJL -  Used Fits.Without to move the help text
                            so that it will fit on screen.
       Jun 24, 1987  RSC -  1) Box type was hardcoded as "NoBox" in the
                               MenusWithPrompts routine.
                            2) BuildTable calculated available room such that
                               menus with ULX > 0 did not behave resonably.
                            3) Added "MenuSize" procedure.
       Jul 13, 1987  AJL -  Added new menu video modes.
       Aug. 13, 1987 AJL -  Allow multiline prompts.
       Aug. 19, 1987 AJL -  Fixed a problem in which menus that took more
                            lines than extimated would not have their
                            bottom row extended enough, and too small a
                            rug was taken.
       Aug. 28, 1987 AJL -  NoYes now only uses MenuStart thru MenuEnd.
                         -  Rearranged sequence of imports.
       Sep. 23, 1987 AJL -  Turn off hardware cursor and move it to the
                            choice being displayed.
                         -  Import EndOfWord from Words.
                         -  Allow Up and Down Keys.
       Sep. 29, 1987 AJL -  Fixed a bug with 1-char menu items.
       Oct. 30, 1987 AJL -  Still fixing that 1-char bug.
                            No longer import from Words.
       Feb. 3,  1988 AJL -  The help keys generated are prefixed with a Greek
                            letter Beta.
       Feb. 8, 1988  AJL -  Changed the prefix character to Pi, 343C, Alt-227,
                            because Beta was being upshifted to a capital S
                            in order to support the Germanic use of that symbol
                            as a double "S" or something akin.   
       Feb. 19, 1988 AJL -  Request only upper case letters from GetCode, so
                            that we will always match strings even when the 
                            menu is showing a highlighted lower case letter.   
                         -  When several choices begin with the same string,
                            highlight the common portion in videoenhance.
       22-Feb-88 LAA  - Force stack checking on for this module.
       11-Oct-88 AJL  - Changed the highlighting rules within ShowChoice
                        in order to highlight the cursor better and give
                        less visual confusion when several choices begin with
                        the same string.
       20-Oct-88 AJL  - Backspace will cancel partial typethrough.
                      - Home and End position to start and end of the menu.
       28-Nov-88 EGK  - (entered by AJL) revised the StartOfWord and EndOfWord
                        to handle null words (two delimiters in a row).
        2-Jan-89 RSC  - Added references to StringsEqual() rather than Compare().
        2-Feb-89 RSC  - Send notices from menus.
        3-Apr-89 LAA    Bug fix: if two choices in a menu differ only by one
                        having a suffix (like Portrait & Portrait-II) then a
                        cardinal overflow resulted.  I removed the assumption
                        that Depth < Length in ShowChoice.
       21-Jul-89 KKC  - Add RollRight and RollLeft keys to menu.
       15-Nov-89 RSC  - Added mouse support.
       11-Dec-89 RSC  - Added "Modal" flag to support mice.
                        Use Events rather than GetCode.
       13-Dec-89 RSC  - Fix some minor bugs in mouse processing.
       14-Dec-89 RSC  - When mouse is dragging, turn off the cursor before
                        selecting a new cursor.
       22-Jan-91 RSC  - Removed reference to SegWords, instead duplicating
                        WordNumber here to flush SegWord's WordNumber out
                        of the root.
       11-Apr-91 RSC  - Call overlay from within MenuSize and MenuWithPrompts.
                        Remove PromptProc (replaced with PromptType)
       25-Apr-91 RSC  - In WordNumber, there was a problem when the string
                        ENDED in a delimeter.
    *)


FROM  Boxes    IMPORT ABoxType, ABoxAttribute;

FROM  Codes    IMPORT ACode, ASetOfCodes, EmptyCodeSet,
                      MaxCode;

FROM  Dialog   IMPORT MultipleChoiceBox, ADialogOption, FatalError, Burp;

FROM  Events   IMPORT
    (* TYPE *)      AnEvent, AnEventType,
    (* PROC *)      GetNextEvent;

FROM  Kbio     IMPORT avidmode, soundon, maxrow,
                      ascreenx, ascreeny,
                      Tone;

FROM  Keys     IMPORT CancelKey;

FROM  LStrings IMPORT SubStr, Fill, ConcatLS, Upshift, TrimRear, LengthOf,
                      SetLengthOf, Procustes, StringsEqual, Remove, Copy;

FROM  MsgFile  IMPORT GetMessage;

FROM MenuHelper     IMPORT
    (* TYPE *)          AMenuContext, AMenuFunction,
    (* PROC *)          DoMenuFunction;

FROM SYSTEM     IMPORT
    (* PROC *)      ADR;

FROM Text       IMPORT
    (* TYPE *)      AText;


CONST
    ModuleNumber = 2000;   (* For GetMessage. *)


CONST
    MaxSelections = 32;
    SpaceBetweenWords = 2;
    MAXCARDINAL = 0FFFFH;
    HelpKeyChar = 343C;    (* Greek Beta. *)
TYPE
    ATableIndex = [ 1..MaxSelections ];
    ATable = ARRAY ATableIndex OF RECORD
                x : ascreenx;
                y : ascreeny;
                Length : CARDINAL;
                Offset : CARDINAL;
                ValidLength  : CARDINAL;
             END;










    (* Menu *)


PROCEDURE Menu(VAR Prefix:ARRAY OF CHAR;
               VAR Menustr:ARRAY OF CHAR;
                   ULX    : ascreenx;
                   ULY    : ascreeny;
                   LRX    : ascreenx;
                   LRY    : ascreeny;
                   CodeSet:ASetOfCodes;
                   Modal  : BOOLEAN;    (* 11-Dec-89 RSC  *)
               VAR Selection:CARDINAL )
                                       : ACode;
BEGIN
    RETURN MenuWithPrompts(Prefix,Menustr,ULX,ULY,LRX,LRY,
                           ABoxType{NoBox},CodeSet,NoPrompts,0,AText(NIL),
                           Modal,Selection);
END Menu;








    (*  NoYes  -- Prompt for a Yes or No answer to a question.
                  Return TRUE iff Yes. *)


PROCEDURE NoYes (VAR Prefix:ARRAY OF CHAR):BOOLEAN;
BEGIN
    RETURN NoYesWithPrompts(Prefix,NoPrompts,0,AText(NIL));
END NoYes;



PROCEDURE NoYesWithPrompts( VAR Prefix     : ARRAY OF CHAR;
                                PromptTyep : APromptType;
                                PromptStartingNumber : CARDINAL;
                                PromptText : AText ) : BOOLEAN;
VAR
    Choice  : CARDINAL;
    Choices : ARRAY [0..20] OF CHAR;
    s       : ARRAY [0..1]  OF CHAR;
BEGIN
    IF (soundon) THEN
        Burp;
        Tone(200,40);
    END;
    GetMessage(ModuleNumber+1,Choices);  (* "No,Yes"  *)
    Choice := 1;
    SetLengthOf(s,0);
    
    IF (MultipleChoiceBox( Prefix, s, NoHelp, s, Choices, Choice )) THEN
        RETURN (Choice = 2);
    END;
    RETURN FALSE;
END NoYesWithPrompts;




PROCEDURE DefaultMenuWithPrompts  (VAR Prefix : ARRAY OF CHAR;
                                   VAR Menustr:ARRAY OF CHAR;
                                       ULX    : ascreenx;
                                       ULY    : ascreeny;
                                       LRX    : ascreenx;
                                       LRY    : ascreeny;
                                       BoxType : ABoxType;
                                       CodeSet:ASetOfCodes;
                                       PromptType : APromptType;
                                       PromptStartingNumber : CARDINAL;
                                       PromptText : AText;
                                       Modal      : BOOLEAN; (* 11-Dec-89 RSC  *)
                                   VAR Selection  : CARDINAL )
                                                           : ACode;
VAR
    MenuContext : AMenuContext;
BEGIN
    WITH MenuContext DO
        Copy( Prefix,  CPrefix );
        Copy( Menustr, CMenustr );
        CULX                    := ULX;
        CULY                    := ULY;
        CLRX                    := LRX;
        CLRY                    := LRY;
        CBoxType                := BoxType;
        CCodeSet                := CodeSet;
        CSelection              := Selection;
        CPromptType             := PromptType;
        CPromptStartingNumber   := PromptStartingNumber;
        CPromptText             := PromptText;
        CModal                  := Modal;

        DoMenuFunction( DoMenuWithPrompts, MenuContext );

        Selection               := CSelection;
        RETURN ReturnCode;
    END;

END DefaultMenuWithPrompts;




PROCEDURE DefaultMenuSize (VAR Prefix        : ARRAY OF CHAR;
                           VAR Menustr       : ARRAY OF CHAR;
                               UsePrompts    : BOOLEAN;
                               ULX           : ascreenx;
                               LRX           : ascreenx;
                               BoxType       : ABoxType
                                                       ) : CARDINAL;
VAR
    MenuContext : AMenuContext;
BEGIN
    WITH MenuContext DO
        Copy( Prefix,  CPrefix );
        Copy( Menustr, CMenustr );
        CULX                    := ULX;
        CLRX                    := LRX;
        CBoxType                := BoxType;
        CUsePrompts             := UsePrompts;

        DoMenuFunction( DoMenuSize, MenuContext );

        RETURN CSize;
    END;

END DefaultMenuSize;





    (* We cannot use the versions of EndOfWord or FindNextEndOfWord
       exported from words because they skip over repeated occurrences
       of the delimiter character. *)


    (* WordNumber -- Return the text of the Nth menu item. *)

PROCEDURE XWordNumber( VAR Menustr : ARRAY OF CHAR;
                           N       : CARDINAL;
                       VAR Word    : ARRAY OF CHAR );
VAR
    Length,
    WordStart,
    WordEnd     : CARDINAL;
    Delim       : CHAR;


    PROCEDURE GetDelimAndStart( VAR MenuStr : ARRAY OF CHAR;
                                VAR Delim   : CHAR;
                                VAR i       : CARDINAL );
    BEGIN
        Delim := ",";    (* Default *)

            (* Menustrings starting with the default delimiter use that
               as a code to change the delimiter. *)

        i := 1;
        IF (ORD(MenuStr[0]) > 2) AND (MenuStr[1] = Delim)  THEN
            Delim := MenuStr[2];
            i := 3;
        END;
    END GetDelimAndStart;


    PROCEDURE FindNthWordStart(     Which : CARDINAL;
                                VAR Where : CARDINAL  );
    BEGIN
        LOOP
            IF (Where > Length) THEN
                EXIT;
            END;

            IF (Menustr[Where] = Delim) THEN
                DEC(Which);
                IF (Which = 0) THEN
                    INC(Where);
                    EXIT;
                END;
            END;

            INC(Where);
        END;

    END FindNthWordStart;


BEGIN
        (* 17-Jan-91 RSC Recoded the algorithem because the profiler
                         said that this was called a lot and is slow.
                         This is used heavily in CAPTIONS stuff to parse
                         comma delimited phrases.
        *)
    Word[0]   := 0C;
    Length    := LengthOf(Menustr);

    IF (N > 0) AND (Length > 0) THEN
        GetDelimAndStart(Menustr,Delim,WordStart);


            (* Step 0: Trim off trailing delimiters.
               27-Feb-91 RSC
            *)
        WHILE (Length > 0) AND (Menustr[Length] = Delim) DO
            DEC(Length);
        END;

            (* Step 1: Find the start of this word by skipping past
                       word # N-1 (which might mean "skip nothing").
            *)
        IF (N > 1) THEN
            FindNthWordStart( N-1, WordStart );
        END;

            (* Step 2: Find the start of the NEXT word by skipping past
                       1 more word.  WordEnd then points 1 PAST the
                       delimiter, or 1 past the end of the string.
                       In the former case, we want to back off 2 bytes
                       to point to the end of the word, and in the
                       latter case we want to back off 1 byte to point
                       to the last byte in the string.

                       One last weird case.  If word N is past the
                       end of the string, WordStart and WordEnd
                       will be the SAME and will be 1 past the end
                       of the string.
            *)
        WordEnd := WordStart;
        FindNthWordStart( 1  , WordEnd   );

        IF (WordEnd <= Length) THEN  (* So its 2 past the end of word *)
            DEC(WordEnd);
        END;

        SubStr(Menustr,Word,WordStart,WordEnd - WordStart);
    END;

END XWordNumber;




BEGIN
    MenuWithPrompts := DefaultMenuWithPrompts;
    MenuSize := DefaultMenuSize;
(*    WordNumber := SegWords.WordNumber;*)  (* 22-Jan-91 RSC  *)
    WordNumber := XWordNumber;              (* 22-Jan-91 RSC  *)
END Menus.
