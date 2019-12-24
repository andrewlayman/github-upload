MODULE TLMenus;

(*V1=DEBUG *)


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
       19-Dec-89 AJL  - Split menus into Menus.mod and TLMenus.mod.
                      - Changed processing of mouse events.
       04-Jan-90 EGK  - Don't burp on a MouseUp outside of a modal menu.
       08-Jan-90 RSC  - Removed unused code.
       16-Jan-90 RSC  - Fixed bug where F10 was being seen as a "D".
       24-Dec-90 AJL  - In the BuildTable procedure there was a test against
                        >= the length of the string.  Changed it to
                        "IF (i > ORD(Menustr[0])) THEN FatalError; END;"
                        The earlier version incorrectly failed on a menu string
                        whose length was exactly 1.
        1-Apr-91 AJL  - We do not honor MouseUp until we have received a
                        a MouseDown.  This is to prevent us from being called
                        with the mouse button already down, then acting on the
                        release.
       11-Apr-91 RSC  - Act like a normal overlay and do not steal vectors.
                        Instead, dispatch based on context information.
                        Remove prompt proc from MenuWithPrompts.
       23-Jul-91 AJL  - Redisplay current choice after return from help.

    *)

FROM  Boxes    IMPORT ABoxType, ABoxAttribute, DrawBox,
                    GetInnerBoxSize, GetOuterBoxSize;

FROM  Codes    IMPORT ACode, ASetOfCodes, SetCodeBits,
                      MaxCode;

FROM  Dialog   IMPORT FatalError, Burp;

FROM  Events   IMPORT
    (* TYPE *)      AnEvent, AnEventType,
    (* PROC *)      GetNextEvent;

FROM  Fits     IMPORT Without;

FROM Foreign  IMPORT UpshiftTable, ConvertedCharacter;

FROM  Helper   IMPORT GiveHelp, AScreenAction;

FROM  Kbio     IMPORT maxcol, avidmode, PutString, 
                      ascreenx, ascreeny, PourText,
                      ACursorType, SetCursorType, GotoXY;

FROM  Keys     IMPORT Fwrd, Reverse, HelpKey, DoIt, CancelKey,
                      BackSpace, Up, Down, HomeKey, EndKey,
                      RollRight, RollLeft,
                      MouseUp, MouseDown, MouseStillDown, MouseDouble;

FROM  Layout   IMPORT GanttWEnd;

FROM  LStrings IMPORT SubStr, Fill, ConcatLS, Upshift, TrimRear,
                      SetLengthOf, Procustes, StringsEqual, Remove,
                      SetString, CtoS, ConcatS;

FROM MenuHelper IMPORT
    (* TYPE *)      AMenuFunction, AMenuContextPtr;

FROM Menus      IMPORT
    (* TYPE *)      APromptType;

FROM Mouse          IMPORT
    (* PROC *)          CancelDoubleClick;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          SendNotices;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImAnInstallableOverlay, OverlayContext;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

FROM  Rugs          IMPORT ARug, GetRug, PutRug;

FROM RunMenu2       IMPORT
    (* PROC *)          ExtraFancyMenu;

FROM SegWords       IMPORT
    (* PROC *)          EndOfWord, StartOfNextWord, SkipBlanks,
                        GetDelimAndStart;

FROM SYSTEM     IMPORT ADR;

FROM Text       IMPORT
    (* TYPE *)          AText,
    (* PROC *)          CopyLine;







VAR
    OverlayID           : AnOverlayID;





CONST
    ModuleNumber = 2000;   (* For GetMessage. *)
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







PROCEDURE BuildTable       (VAR Prefix : ARRAY OF CHAR;
                            VAR Menustr:ARRAY OF CHAR;
                                UsePrompts : BOOLEAN;
                                ULX    : ascreenx;
                                ULY    : ascreeny;
                                LRX    : ascreenx;
                            VAR LRY    : ascreeny;
                            VAR PromptY: ascreeny;    (* Output *)
                            VAR MenuWidth : CARDINAL;
                            VAR Table  : ATable;
                            VAR NumberOfEntries : CARDINAL );
VAR
    Nextx : CARDINAL;
    i,j,Space,WordLength : CARDINAL;
    n : [ 0 .. MaxSelections ];
    Delim                 : CHAR;
BEGIN

    MenuWidth := LRX - ULX + 1;

        (* Menustrings starting with the default delimiter use that
           as a code to change the delimiter. *)

    GetDelimAndStart(Menustr,Delim,i);     (* Sets i to first char. *)


    IF (ORD(Menustr[0])=0) OR
       (ORD(Prefix[0]) > maxcol) THEN FatalError END;


        (*  Decide how many columns will be needed for the prefix. *)

    Space := ORD(Prefix[0]);
    IF (Space > 0) THEN
        INC( Space, SpaceBetweenWords );
    END;

       (* Build a table that lists, for each menu selection,
         where it is in the source menu string, how long it
         is, and where it goes (x,y) on the screen.   Compute the
         last screen line used. *)

    SkipBlanks(Menustr,i);
    IF (i > ORD(Menustr[0])) THEN FatalError; END; (* Blank menu string *)

    n := 0;                     (* Word number *)
    Nextx := Space;
    PromptY := ULY;
    REPEAT
        j := EndOfWord(Menustr,i,Delim);
        WordLength := j - i + 1;

             (* Check for words that are too long. *)
        IF (WordLength > MenuWidth - Space) THEN FatalError END;

        IF (Nextx > (MenuWidth-1-ascreenx(WordLength))) THEN
            Nextx := Space;
            INC(PromptY);
        END;


        IF (n < MaxSelections ) THEN
            INC(n)
        ELSE
            (* Menu: too many entries. *)
            FatalError
        END;

        WITH Table[n] DO
             y := PromptY;
             x := VAL(ascreenx,(ULX + Nextx));
             Offset := i;
             Length := WordLength;
             ValidLength := 0;
        END;

        INC(Nextx,  WordLength + SpaceBetweenWords );

    UNTIL (NOT StartOfNextWord(Menustr,i,Delim));

    NumberOfEntries := n;

    IF (UsePrompts) THEN
        INC(PromptY);       (* Use Nexty for prompt. *)
    END;

    IF (PromptY > LRY) THEN
        LRY := PromptY;
    END;

END BuildTable;





PROCEDURE MenuWithPrompts  (VAR Prefix : ARRAY OF CHAR;
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
                                NoEasyExit : BOOLEAN; (* 11-Dec-89 RSC  *)
                            VAR Selection  : CARDINAL )
                                                    : ACode;
VAR
    Depth               : CARDINAL;               (* Unique letters of word. *)
    Count               : CARDINAL;
    MenuWidth           : CARDINAL;
    Event               : AnEvent;
    OriginalScreenImage : ARug;
    FormerSelection,
    n                   : [ 0 .. MaxSelections ];
    MULX, MLRX          : ascreenx;
    MULY, MLRY, PromptY : ascreeny;
    LastPromptY         : ascreeny;
    CSet                : ASetOfCodes;     (* Set of codes that we respond to. *)
    NewCode,
    Code                : ACode;
    WaitForMouseDown    : CARDINAL;
    Table               : ATable;
    NumberOfEntries     : ATableIndex;
    s1                  : ARRAY [0..1] OF CHAR;
    FullWidthString     : ARRAY [0..255] OF CHAR;
    s4                  : ARRAY [0..4] OF CHAR;
    MatchString         : ARRAY [0..30] OF CHAR;
    FormerPromptIsHighlighted,
    PromptIsHighlighted,
    CodeOK,
    SavedScreen         : BOOLEAN;



    PROCEDURE NameMatches(String:ARRAY OF CHAR; i:CARDINAL):BOOLEAN;
    VAR
        s : ARRAY [0..maxcol+1] OF CHAR;
    BEGIN
        Upshift(String);
        SubStr(Menustr, s, Table[i].Offset, ORD(String[0]) );
        Upshift(s);
        RETURN (StringsEqual(String,s));  (* RSC 1/2/88 *)
    END NameMatches;


        (* HowUnique -- Test the String against all possible
                        menu entries.  Return the count of
                        how many match and the index of the
                        first one that matches.  If more than
                        one entry matches, extend the String to
                        be longer, up through all characters
                        that are common to the several possible
                        choices.  Set the ValidLen entry in
                        each table item to the count of characters
                        matched. *)


    PROCEDURE HowUnique(VAR String:ARRAY OF CHAR;
                        VAR Table : ATable;
                        NumberOfEntries: ATableIndex;
                        VAR First,Count:CARDINAL);
    VAR
        i, Len : CARDINAL;
        OldCount, OldFirst, OldLen : CARDINAL;
        FirstTime : BOOLEAN;
    BEGIN

        FOR i := 1 TO NumberOfEntries DO
            Table[i].ValidLength := 0;
        END;

        FirstTime := TRUE;
        OldCount := 2;            (* Trick for first time. *)

        LOOP
            Len := ORD(String[0]);
            First := 0;
            Count := 0;

            FOR i := 1 TO NumberOfEntries DO
                IF (NameMatches(String,i)) THEN
                    INC(Count);
                    Table[i].ValidLength := Len;
                    IF (First = 0) THEN
                        First := i;
                    END;
                END;
            END;

            IF (Count < OldCount) THEN
                EXIT;
            END;

            OldCount := Count;
            OldFirst := First;
            OldLen   := Len;
            SubStr(Menustr,String,Table[First].Offset,Len+1);
            FirstTime := FALSE;

            IF (Table[First].Length <= Len) THEN
                EXIT;
            END;

        END;

        IF (NOT FirstTime) THEN
            Count := OldCount;
            First := OldFirst;
            Procustes(String,OldLen);
            Len := OldLen;
        END;

    END HowUnique;


        (*  Show the nth selection. *)

    PROCEDURE ShowChoice(n:ATableIndex; Depth:CARDINAL; mode:avidmode;
                         Visible, IsCursor : BOOLEAN );

    VAR
        ThisChoice : ARRAY [0..maxcol] OF CHAR;


    PROCEDURE DrawAPart( Start, Len : CARDINAL; Mode : avidmode );
    VAR
        s1 : ARRAY [0..maxcol] OF CHAR;
        XX : ascreenx;
    BEGIN
        IF (IsCursor) THEN
            INC(Mode);
        END;

        WITH Table[n] DO
            SubStr(ThisChoice,s1,Start,Len);
            XX := x+Start-1;
            PutString(s1,XX,y,Mode);
            GotoXY(XX,y);
        END;
    END DrawAPart;


    BEGIN
        WITH Table[n] DO
            IF (NOT Visible) THEN
                Fill(ThisChoice," ",Length);
                PutString(ThisChoice,x,y,videomenubox);
                RETURN;
            END;

                (* Is visible by here. *)

            SubStr(Menustr,ThisChoice,Offset,Length);

            IF (Depth < Length) THEN                              (* 3-Apr-89 LAA *)
                DrawAPart(Depth+2, Length-Depth-1, mode );
            END;

                (* If we had more than one choice that began with the
                   same string, highlight the common parts. *) 

            DrawAPart( 1, Depth, videomenuback );

                (*  Highlight the "Depth" letter of the choice. *)

            DrawAPart( Depth+1, 1, videomenubright );

               (* Follow the choice with a comma. *)

            IF (n < NumberOfEntries) THEN
                Fill(ThisChoice,",",1);
                PutString(ThisChoice,x+Length,y,videomenubox);
            END;

        END;
    END ShowChoice;


    PROCEDURE ShowCurrentChoices(Depth:CARDINAL;VAR CSet:ASetOfCodes);
    VAR
        i : CARDINAL;
        C : ACode;
    BEGIN
            (* Choose which characters we will accept from the keyboard.
              We will allow any in the set passed to us, plus any
              that represent the first letters of any menu choices,
              plus those that we need to allow cursor movement.
            *)
        CSet := CodeSet;
        SetCodeBits(CSet,Fwrd,Fwrd,TRUE);
        SetCodeBits(CSet,Reverse,Reverse,TRUE);
        SetCodeBits(CSet,Down,Down,TRUE);
        SetCodeBits(CSet,Up,Up,TRUE);
        SetCodeBits(CSet,BackSpace,BackSpace,TRUE);
        SetCodeBits(CSet,HomeKey,HomeKey,TRUE);
        SetCodeBits(CSet,EndKey,EndKey,TRUE);
        SetCodeBits(CSet,RollLeft,RollLeft,TRUE);
        SetCodeBits(CSet,RollRight,RollRight,TRUE);
        SetCodeBits(CSet,ORD(" "),ORD(" "),TRUE);
        SetCodeBits(CSet,HelpKey,HelpKey,TRUE);
        SetCodeBits(CSet,CancelKey,CancelKey,TRUE);

        FOR i := 1 TO NumberOfEntries DO
            WITH Table[i] DO
                IF (ValidLength >= Depth) THEN
                    C := ORD(ConvertedCharacter( Menustr[Offset+Depth], UpshiftTable ));
                    SetCodeBits(CSet,C,C,TRUE);
                    ShowChoice(i,Depth,videomenu,TRUE,FALSE);
                ELSE
                    ShowChoice(i,Depth,videomenubox,FALSE,FALSE);
                END;
            END;
        END;
    END ShowCurrentChoices;




    PROCEDURE ShowHelp;
    CONST
        MinimumSize = 11;
    VAR
       Top, Bottom : CARDINAL;
       i : CARDINAL;
       S : ARRAY [0..10] OF CHAR;
       S2 : ARRAY [0..4] OF CHAR;
    BEGIN
        Without(MinimumSize,MAXCARDINAL,ULY,LRY,0,GanttWEnd,Top,Bottom);
        Fill(S,HelpKeyChar,1);
        SubStr(Prefix,S2,1,4);
        ConcatLS(S,S2);
        WITH Table[n] DO
            i := 3;
            IF (Length < 3) THEN i := Length; END;
            SubStr(Menustr,S2,Offset,i);
        END;
        ConcatLS(S,S2);
        GiveHelp(S,Top,Bottom,RestoreTheScreen);
    END ShowHelp;




    PROCEDURE CleanUp;
    BEGIN
             (*  Determine which selection we were on. *)
         Selection := n;
             (*  Clean up after ourselves. *)
         IF (SavedScreen) THEN
             PutRug(ULX,ULY,LRX,LRY,OriginalScreenImage);
         END;
    END CleanUp;

    PROCEDURE Advance(    Amount : INTEGER);
    BEGIN
        REPEAT
           n := (CARDINAL(INTEGER(n+NumberOfEntries-1) + Amount ) MOD NumberOfEntries) + 1;
        UNTIL (Table[n].ValidLength >= Depth);
    END Advance;

    PROCEDURE MoveSelectionXY( EventX : ascreenx; EventY : ascreeny;
                               VAR n : CARDINAL ) : BOOLEAN;
    VAR
        i : CARDINAL;
    BEGIN
        FOR i := 1 TO NumberOfEntries DO
            WITH Table[i] DO
                IF (EventX >= x)           AND
                   (EventX < (x + Length)) AND
                   (EventY =  y)           THEN
                    n := i;
                    RETURN TRUE; 
                END;
            END;
        END;
        RETURN FALSE;   (* Did not hit a choice. *)

    END MoveSelectionXY;


    (*<DEBUG
    PROCEDURE ShowMouse( VAR Event : AnEvent );
    VAR
        S : ARRAY [0..50] OF CHAR;
        S2 : ARRAY [0..25] OF CHAR;
    BEGIN
        CASE Event.EventCode OF
            MouseUp :    SetString(S,"MouseUp         ");
         |  MouseDouble: SetString(S,"MouseDouble     ");
         |  MouseDown:   SetString(S,"MouseDown       ");
         |  MouseStillDown:  SetString(S,"MouseStillDown ");
         ELSE  SetString(S,"Mouse ????");
        END;
        IF (WaitForMouseDown > 0) THEN
            ConcatS(S," WAIT ");  CtoS(WaitForMouseDown,S2);
            Procustes(S2,2);  ConcatLS(S,S2);
        ELSE
            ConcatS(S,"        ");
        END;
        CtoS(Event.EventX,S2);  Procustes(S2,5);  ConcatLS(S,S2);
        CtoS(Event.EventY,S2);  Procustes(S2,5);  ConcatLS(S,S2);
        PutString(S,0,21,videoreverse);
    END ShowMouse;
    DEBUG>*)

    PROCEDURE ProcessMouseEvent(VAR Event : AnEvent;
                                VAR n     : CARDINAL ) : ACode;
    VAR
        Code : ACode;
        X    : ascreenx;
        Y    : ascreeny;
    BEGIN

        X := Event.EventX;
        Y := Event.EventY;
        Code := 0;             (* Means ignore. *)

        (*<DEBUG ShowMouse(Event); DEBUG>*)

            (* We do not honor mouse actions until we have received a
               a MouseDown.  This is to prevent us from being called
               with the mouse button already down, then acting on the
               release. *)
        IF (Event.EventCode = MouseDown) THEN 
            WaitForMouseDown := 0;
        ELSIF (Event.EventCode = MouseStillDown) AND
              (WaitForMouseDown > 0) THEN 
            DEC(WaitForMouseDown);
        END;

        IF (WaitForMouseDown > 0) THEN
                (* Ignore mouse until we get a MouseDown. *)
            RETURN 0;
        END;

        CASE Event.EventCode OF
            MouseUp: IF (MoveSelectionXY(X,Y,n)) THEN
                         Code := DoIt;
                         CancelDoubleClick();   (* Don't allow that second click. *)
                     ELSIF (X >= ULX) AND (X <= LRX) AND (Y >= ULY) AND (Y <= LRY) THEN
                             (* still on the menu, just not on a choice. *)
                         IF (PromptType <> NoPrompts) AND (PromptY <= Y) AND (Y <= LastPromptY) THEN
                             (* Permit double click. *)
                         ELSE
                             CancelDoubleClick();   (* Don't allow that second click. *)
                             Burp;
                         END;
                     ELSE
                         IF (NoEasyExit) THEN
                            (*      1/4/90 EGK
                              Burp();                 (* Sorry, can't leave so easily. *)
                            *)
                         ELSE
                              Code := CancelKey;      (* Out of the menu area. *)
                         END;
                         CancelDoubleClick();   (* Don't allow that second click. *)
                     END; 

      | MouseDouble:

                     Code := HelpKey;

      | MouseDown,
        MouseStillDown:

                     IF (MoveSelectionXY(X,Y,n)) THEN
                     ELSIF (X >= ULX) AND (X <= LRX) AND (Y >= PromptY) AND (Y <= LastPromptY) THEN
                         PromptIsHighlighted := TRUE;
                     ELSIF (Event.EventCode = MouseDown) THEN
                         Burp();
                     END;

        ELSE
                     (* Error condition safety net. *)
        END;
 
        RETURN Code;

    END ProcessMouseEvent;


    PROCEDURE ShowPrompt( n : CARDINAL;  Highlight : BOOLEAN );
    VAR
        Mode : avidmode;
    BEGIN
        IF (PromptType <> NoPrompts) THEN

                (* If prompts are being used, display the appropriate
                   one for this choice. *)

            IF (PromptType = PromptFromPhrases) THEN
                GetMessage(n-1+PromptStartingNumber, FullWidthString);
            ELSIF (PromptType = PromptFromText) THEN
                CopyLine(PromptText, n-1, FullWidthString);
            END;

            IF (Highlight) THEN
                Mode := videobright;
            ELSE
                Mode := videoprompt;
            END;
            PourText(FullWidthString,Mode,MULX,PromptY,MLRX,MLRY,
                     LastPromptY);
        END;
    END ShowPrompt;



    PROCEDURE ShowCursor( n : CARDINAL );
    BEGIN
        ShowChoice(n,Depth,videomenu,TRUE,TRUE);    (* Show the cursor. *)
        ShowPrompt(n,FALSE);
    END ShowCursor;




    PROCEDURE UnShowCursor( n : CARDINAL );
    BEGIN
        IF (n > 0) THEN
            ShowChoice(n,Depth,videomenu,TRUE,FALSE);       (* Turn off cursor. *)
        
                (* Erase any prompt showing. *)

            IF (PromptType <> NoPrompts) THEN
                FullWidthString[0] := 0C;
                DrawBox(MULX,PromptY,MLRX,LastPromptY,ABoxType{NoBox},
                        FullWidthString,videomenubox);
            END;
        END;

    END UnShowCursor;



BEGIN

    SendNotices( MenuActive, BeforeActing, ADR(Prefix) );

        (* We do not honor MouseUp until we have received a
           a MouseDown (or a series of MouseStillDown, indicating a
           lengthy elapsed period).  This is to prevent us from being called
           with the mouse button already down, then acting on the
           immediate release. *)
    WaitForMouseDown := 25;

    MatchString[0] := 0C;

        (* Always allow DoIt and CancelKey.
        *)

    SetCodeBits(CodeSet,DoIt,DoIt,TRUE);
    SetCodeBits(CodeSet,CancelKey,CancelKey,TRUE);



        (* Determine the menu boundaries. *)

    GetInnerBoxSize(ULX,ULY,LRX,LRY,BoxType);

    MULX := ULX;
    MULY := ULY;
    MLRX := LRX;
    MLRY := LRY;

        (* Determine how the menu will be layed out, including
           the lowest line on the screen, LRY. *)

    BuildTable( Prefix, Menustr,
                (PromptType <> NoPrompts),
                MULX, MULY, MLRX,
                MLRY,
                PromptY,
                MenuWidth,
                Table,
                NumberOfEntries );


    LRY := MLRY;

    GetOuterBoxSize(ULX,ULY,LRX,LRY,BoxType);

        (* Store the original screen contents. *)

    SavedScreen := GetRug(ULX,ULY,LRX,LRY,OriginalScreenImage);



        (*  Set the index "n" to correctly reference the selection
           that was passed in to us.  This allows our caller to
           specify a default selection, which will appear first. *)

    IF (Selection > NumberOfEntries) THEN
        Selection := 1;
    END;

    PromptIsHighlighted := FALSE;     (* Don't initially highlight prompt. *)


    LOOP
            (* Erase that area of the screen needed. *)
        SetCursorType(NoCursor);

        FullWidthString[0] := 0C;  (* No title. *)
        DrawBox(ULX,ULY,LRX,LRY,BoxType,FullWidthString,videomenubox);

            (* Display the Prefix *)

        IF (Prefix[0] > 0C) THEN
            PutString(Prefix,MULX,MULY,videomenuback);
            Fill(s1,":",1);
            PutString(s1,MULX+ORD(Prefix[0]),MULY,videomenuback);
        END;


            (*  Display all selections. Get valid code set. *)

        HowUnique(MatchString,Table,
                  NumberOfEntries,
                  n,Count);

        Depth := ORD(MatchString[0]);
        IF (Depth = 0) THEN
            n := Selection;
        END;
        ShowCurrentChoices(Depth,CSet);             (* Display all active items. *)
        ShowCursor(n);                              (* Highlight current choice. *)
        FormerSelection := n;                       (* Record cursor position. *)
        FormerPromptIsHighlighted := FALSE;   

            (*  Loop, displaying the current menu selection, and receiving
               input from the keyboard.  Keep looking until
                   a)  a key is entered that was in the code set passed, or
                   b)  an item is selected by its first letter.
            *)

        LOOP
                (* If the current choice has changed, show that. *)
            IF (n <> FormerSelection) THEN
                UnShowCursor(FormerSelection);
                ShowCursor(n);  
            END;
            IF (PromptIsHighlighted <> FormerPromptIsHighlighted) THEN
                ShowPrompt(n,PromptIsHighlighted);
            END;
            FormerSelection := n;
            FormerPromptIsHighlighted := PromptIsHighlighted;

                (* Get input from user. *)

            GetNextEvent( Event );

            PromptIsHighlighted := FALSE;      (* Plan on turning off any prompt highlight. *) 

            IF (Event.EventType = MouseEvent) THEN
                Code := ProcessMouseEvent( Event, n );
                IF (Code = 0) AND (Depth > 0) THEN
                    Depth          := 0;       (* Discard any typethrough *)
                    MatchString[0] := 0C;
                    EXIT;                      (* Leave the loop so we can reset the display. *)
                END;
            ELSE
                Code := Event.EventCode;
            END;


                (* 12-Dec-89 RSC Used to be GetCode, which does some
                                 fiendish upshift checking, so try to simulate
                                 that here.....
                *)
            IF (Code <> 0) THEN
                CodeOK  := (Code <= MaxCode) AND ((Code MOD 16) IN CSet[Code DIV 16]);
                IF (NOT CodeOK) AND (Code <= HIGH(UpshiftTable)) THEN   (* 16-Jan-90 RSC Was MaxCode again. *)
                    NewCode := ORD(ConvertedCharacter( CHR(Code), UpshiftTable ));
                    CodeOK  := ((NewCode MOD 16) IN CSet[NewCode DIV 16]);
                    IF (CodeOK) THEN
                        Code := NewCode;
                    END;
                END;
            END;

            IF (Code = 0) THEN
               (* ignore it. *) 
            ELSIF (CodeOK) THEN

                    (* If Code in Codeset then exit, returning it.  *)

                IF ((Code MOD 16) IN CodeSet[Code DIV 16]) THEN
                    CleanUp;
                    WITH Table[n] DO
                        SubStr(Menustr,FullWidthString,Offset,Length);
                    END;
                    SendNotices( MenuActive, AfterActing, ADR(FullWidthString) );
                    RETURN Code;
                END;

                CASE Code OF
                    BackSpace:
                                IF (Depth = 0) THEN
                                    Advance(-1);   (* Backspace *)
                                ELSE
                                        (* Backup in typethrough.
                                           Find the longest prior substring. *)
                                    Depth := ORD(MatchString[0]);
                                    REPEAT
                                        DEC(Depth);
                                        MatchString[0] := CHR(Depth);
                                        HowUnique(MatchString,Table,
                                                  NumberOfEntries,
                                                  n,Count);
                                    UNTIL (ORD(MatchString[0])=Depth) OR (Depth=0);  
                                    EXIT;      
                                END;
                  | CancelKey:  
                                CleanUp;
                                SendNotices( MenuActive, FailureToAct, ADR(Prefix) );
                                RETURN CancelKey;

                  | 32, (* Space *)
                    Fwrd,
                    Down:
                                Advance(1);

                  | Reverse,
                    Up:
                                Advance(-1);

                  | HomeKey, RollLeft:
                                    (* Go to the first entry past the end. *)
                                n := NumberOfEntries;
                                Advance(1);

                  | EndKey, RollRight:
                                    (* Go to the first entry prior to the beginning. *)
                                n := 1;
                                Advance(-1);
                  | HelpKey:
                                ShowChoice(n,Depth,videorestingcursor,TRUE,FALSE);       (* Show resting cursor. *)
                                ShowHelp;
                                FormerSelection := 0;   (* Signal redisplay of the current choice. *)
                ELSE
                        Fill(s4,CHR(Code),1);
                        ConcatLS(MatchString,s4);
                        HowUnique(MatchString,Table,NumberOfEntries,n,Count);
                        IF (Count = 1) THEN
                            CleanUp;
                            WITH Table[n] DO
                                SubStr(Menustr,FullWidthString,Offset,Length);
                            END;
                            SendNotices( MenuActive, AfterActing, ADR(FullWidthString) );
                            RETURN DoIt;
                        ELSIF (Count > 1) THEN
                            EXIT;
                        ELSE
                            FatalError;
                        END;
                END;  (* Case *)
            ELSE
                Burp;
            END;
        END;
    END;

END MenuWithPrompts;










PROCEDURE MenuSize (VAR Prefix        : ARRAY OF CHAR;
                    VAR Menustr       : ARRAY OF CHAR;
                        UsePrompts    : BOOLEAN;
                        ULX           : ascreenx;
                        LRX           : ascreenx;
                        BoxType       : ABoxType
                                                       ) : CARDINAL;
VAR
    LRY, ULY, Top   : CARDINAL;
    MenuWidth       : CARDINAL;
    Table           : ATable;
    NumberOfEntries : ATableIndex;
    PromptY         : ascreeny;
BEGIN
    Top := 1;
    ULY := Top;
    LRY := ULY;
    GetInnerBoxSize(ULX,ULY,LRX,LRY,BoxType);

        (* Determine how the menu will be layed out, including
           the lowest line on the screen, LRY. *)


    BuildTable( Prefix, Menustr,
                UsePrompts,
                ULX, ULY, LRX, LRY,
                PromptY,
                MenuWidth,
                Table,
                NumberOfEntries );

    GetOuterBoxSize(ULX,ULY,LRX,LRY,BoxType);

    RETURN (LRY - Top + 1);

END MenuSize;






PROCEDURE DoAMenuFunction();
VAR
    ContextPtr  : AMenuContextPtr;
BEGIN
    ContextPtr := OverlayContext();
    IF (ContextPtr = NIL) THEN HALT; END;

    WITH ContextPtr^ DO
        CASE MenuFunction OF
            DoExtraFancyMenu :
                ReturnCode := ExtraFancyMenu( CClass,
                                              CPrefix,
                                              CULX, CULY, CLRX, CLRY,
                                              CBoxType,
                                              CExitCodes,
                                              CInitialChoice,
                                              CReturnString,
                                              CDispatch,
                                              CCallDepth,
                                              CChoiceSequence);

          | DoMenuWithPrompts   :

                ReturnCode := MenuWithPrompts( CPrefix,
                                               CMenustr,
                                               CULX, CULY, CLRX, CLRY,
                                               CBoxType,
                                               CCodeSet,
                                               CPromptType,
                                               CPromptStartingNumber,
                                               CPromptText,
                                               CModal,
                                               CSelection );
          | DoMenuSize  :

                CSize := MenuSize( CPrefix,
                                   CMenustr,
                                   CUsePrompts,
                                   CULX, CLRX,
                                   CBoxType );
        ELSE
            FatalError;
        END;
    END;

END DoAMenuFunction;





BEGIN
    OverlayID := ImAnInstallableOverlay( DoAMenuFunction, AnOverlayProc(NIL) );
    DoAMenuFunction();
END TLMenus.

