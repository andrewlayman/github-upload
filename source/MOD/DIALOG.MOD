    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Dialog;

(*$S+*)

(*  =========================================================================
    Last Edit : April 15, 1991 12:18PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        Mar 13, 1987    EGK - Modified DialogBox to use shadow box feature.
                              Dialog boxes are now centered on screen.
        Apr 9, 1987     EGK - Added NotYetImplemented Procedure.
        Jun 23,1987     RSC - Added MultipleChoiceBox.  Made Continuation
                              Box use it.
        Jun 29 1987     AJL - Added notices.
        Aug. 13, 1987   AJL - PourText now pours up to AND INCLUDING line
                              LRY.
        09-Sep-87 LAA       - Added Roger's code for Barf.
        24-Sep-87 LAA       - Imported RTSMain instead of System for
                              Logitech V3 compiler.
         8-Oct-87 AJL       - Make the menu boxes use fewer lines.  MenuSize
                              was being called with something other than
                              'NoBox'.
         1-Dec-87 AJL       - Split DialogBox proc into two parts, adding
                              procedure DisplayBox.
                            - Added type ABoxHandle and procs ProgressBox,
                              ReleaseBox, and DiscardBoxHandle.
         2-Dec-87 LAA       - Put an interlock on the Error procedure.
        21-Dec-87 LAA       - Changed the way Error returns to DOS.
        30-Dec-87 LAA       - Can exit from Error or WarningBox with F10.
        06-Jan-88 LAA       - Fixed bug in DialogBox with TextUlx and TextLrx
                              not being initialized.
        20-Jan-88 AJL       - Passing OfferHelp to DialogBox will display
                              "[F1] for help." even if menus are not chosen.
        26-Jan-88 AJL       - DialogBox automatically supplies the instructions
                              to press F1, Esc and F10.
         3-Feb-88           - DialogBox will always offer help for any box whose
                              title begins with Alt-157, the OfferHelpChar.
                            - Help keys for dialog boxes will be composed of
                              the Greek character alpha followed by the title.
                            - If the text of an error box begins with a 
                              parenthesis, that will be used as the box title.
                              This will cause allocation of temporary heap storage.
                              Note that the title can, per the above, request
                              help.
                            - If the Title begins with a parenthesis, remove the 
                              parenthesized contents and use them for a help key.
                            - Changed the tone of the Error beep.
         4-Feb-88           - Don't overwrite the phrase passed into DialogBox
                              with a leading alpha.  
         6-Feb-88 RSC       - Spruce up Message() behavior with the tampered
                              flag set.
        14-Feb-88 AJL       - Correct the indentation of the [F1] prompt
                              in DialogBox.
              ------ SOMEHOW SOME CHANGES GOT LOST, SO . . .
                            - Correct the source of the help index in DialogBox.
                            - Put the help key character (alpha) at the start
                              of a boxes help index.
        19-Feb-88 LAA       - Added procedure to get and set the message
                              priority.
        22-Feb-88 LAA       - Force stack checking on for this module.  
                              Commented out the ErrorInterlock, because it was
                              apparently causing the program to die if a low
                              memory notice is sent out while a dialog box is
                              on the screen.  This would be a problem if offering
                              help from the error box.
        24-Feb-88 AJL       - Moved the [F1] for Help message to the end of the line.
                            - Moved the local string Text from Error to DialogBox.
                            - Any Box text that starts with a "(" will set the 
                              title for that box.  You have been warned!
                            - Reduced the space in boxes with menus by
                              one line since prompts are not used.
        27-Feb-88 LAA       - Force the Option parameter of DialogBox to be
                              NoHelp, so that the only way help will be 
                              offered is if the phrase being displayed has
                              the offer help character in it.
        28-Feb-88 AJL       - Make a new variable, LocalTitle, inside 
                              DialogBox so that we can compose and parse
                              independently of the length of the string
                              passed to us.
        01-Mar-88 LAA       - Took Barf out of FatalError.
        02-Mar-88 AJL       - Increased the time delay in Burp, now that
                              Clock.Delay has been fixed to work correctly. 
        03-Oct-88 RSC       - Import FatalError from FatalErr.Mod.
        11-Nov-88 EGK       - Changed DialogBox so that if DisplayBox fails,
                              but we need to put up a menu, we just put a plain
                              menu at the top of the screen.  The caller might
                              not like it if we just return 0.
        14-Nov-88 EGK       - Made ReleaseBox check for Handle=NIL.
         2-Feb-89 RSC       - Changed params for ParseBal.
        25-May-89 RSC       - When Burping with the sound off, check to see
                              if keystrokes are waiting, so you can terminate
                              the burp early.  This is for Macros.
        25-Jul-89 RSC       - Get the error box suffix lines ("Press [ESC]")
                              from GaGa, so that we get them if there is
                              trouble opening the message file or checking
                              the serial number.
        05-Aug-89 WKH       - Initial OS/2 edits.
        21-Aug-89 RSC       - Removed the low memory processing.
                              New low memory scheme:  If we cannot get
                              a rug, we notify everyone we can think of
                              to tell them that we have trashed the screen.
         6-Sep-89 AJL       - Append the text of the error messages to the 
                              subject passed to GiveHelp.  This is accessable
                              within helptext as parameter *1*. 
        13-Sep-89 WKH       - Shut off cursor in DialogBox
        15-Nov-89 RSC       - Added mouse support.
        11-Dec-89 AJL       - Added mouse buttons onto the Dialog boxes.
        04-Jan-90 EGK       - Don't compute the internal box size once the
                              default dimensions are assumed
                              (GetInnerDisplayBoxSize).
         6-Oct-90 AJL       - Use CorrelateMouseToCode.
                            - Add a Help button.
         6-Feb-91 RSC       - Moved registering for notices to Message
                              rather than Error.  This will make the
                              registration happen early.
        10-Apr-91 AJL       - Changed the HelpKeyChar to Alt-157 (Yen).
        12-Apr-91 RSC       - Changed the parameters to MenuWithPrompts.
        16-Sep-91 AJL       - Increase the size of the help text to start
                              at the top of the screen.
                                  
    =========================================================================
*)


FROM Boxes          IMPORT
    (* TYPE *)          ABoxType, ABoxAttribute, AMouseClickPoint,
    (* PROC *)          DrawBox, GetInnerBoxSize, GetOuterBoxSize,
                        CorrelateMousePoint, CorrelateMouseToCode;

FROM Chart          IMPORT
    (* VAR *)           GanttChart;

FROM Codes          IMPORT
    (* CONST *)         MaxCode,
    (* TYPE *)          ACode, ASetOfCodes,
    (* PROC *)          SetCodeBits;

FROM Events         IMPORT
    (* TYPE *)          AnEvent, AnEventType,
    (* PROC *)          GetNextEvent;

IMPORT FatalErr;

FROM GaGa           IMPORT
    (* PROCS *)         GetGaGaMessage, ConcatGaGaMessage;

FROM GanttOutlines  IMPORT
    (* TYPE *)          AGanttOutlineSpecificChange;

FROM Kbio           IMPORT
    (* CONST *)         maxrow, maxcol,
    (* TYPE *)          avidmode, ascreenx, ascreeny, ACursorType,
    (* VAR *)           TamperedFlag, soundon,
    (* PROC *)          GetCode, GetAnyCode, Tone,
                        EraseLn,  SetCursorType,
                        PutString, PutAttribute, PourText, KbioTerminate,
                        ClearBreak, KeyPress;

FROM Keys           IMPORT
    (* CONST *)         HelpKey, CancelKey, DoIt, ExitKey,
                        MouseUp, MouseDouble; 

FROM Layout         IMPORT
    (* VARS *)          GanttWStart, GanttWEnd;

FROM LStrings       IMPORT
    (* PROC *)          SubStr, SetString, TrimFront, ConcatS,
                        SetLengthOf, LengthOf, Fill, ConcatLS, Remove,
                        Copy, Insert, Procustes;

FROM Rugs           IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug, ThrowRug, PutVideoModeToRug,
                        DisplayRug;

FROM Helper         IMPORT
    (* TYPE *)          AScreenAction,
    (* PROC *)          GiveHelp;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage, ConcatMessage;

FROM Paranoia       IMPORT  
    (* TYPE *)          AProgramState,
    (* VAR *)           ProgramState, InitializationOK;

FROM RTSMain        IMPORT
    (* VARS *)          Status,
    (* PROC *)          Terminate;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, ADR;

FROM Text           IMPORT
    (* TYPE *)          AText;

FROM Clock          IMPORT
    (* PROC *)          Delay, NoEarlyExit;

FROM Menus          IMPORT  
    (* TYPE *)          APromptType,
    (* PROCS *)         MenuSize, Menu, MenuWithPrompts;

FROM Mouse          IMPORT
    (* PROC *)          MousePresent, CancelDoubleClick;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          Permission, SendNotices, RegisterForNotices;

FROM Words          IMPORT
    (* PROC *)          ParseBal;    







CONST
    ModuleNumber = 1600;

CONST
    MessageRow           =  0;
    XMargin              =  3;
    YSafety              =  2;
    OfferHelpChar        =  235C;   (* Alt-157, Yen symbol *)
    HelpKeyChar          =  235C;   (* Alt-157, Yen symbol *)

    MinMemory           = 256;

TYPE
    ABoxHandle           =  ARug;
VAR
    CurrentMessagePriority : CARDINAL;
    LastRowWithMessage     : ascreeny;
    ErrorInterlock         : BOOLEAN;
    Registered             : BOOLEAN;



(*----------------------------------------------------------------------------
    ProgressBox

    Displays a message box on the screen.  The box
    contains the ForWhat text.  A BoxHandle is returned to allow the
    box to be removed, later.

----------------------------------------------------------------------------*)

PROCEDURE ProgressBox( VAR ForWhat : ARRAY OF CHAR ):ABoxHandle;
VAR
    TextULX,
    TextLRX    : ascreenx;
    TextULY, 
    TextLRY    : ascreeny;
    BoxULX,
    BoxLRX     : ascreenx;
    BoxULY, 
    BoxLRY     : ascreeny;
    Rug        : ARug;
    Title : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(Title," ",0);
    IF DisplayBox( ForWhat,Title,ABoxType{DoubleBox,ShadowBox},0,videoreverse,
                   TextULX,TextULY,TextLRX,TextLRY,
                   BoxULX,BoxULY,BoxLRX,BoxLRY,Rug) THEN
        RETURN Rug;
    ELSE
        RETURN ABoxHandle(NIL);
    END;
END ProgressBox;




(*----------------------------------------------------------------------------
    ReleaseBox

    Restores the screen under the box to its appearance before the box
    was displayed.

----------------------------------------------------------------------------*)

PROCEDURE ReleaseBox( VAR Handle : ABoxHandle );
BEGIN
    IF (Handle <> ABoxHandle(NIL)) THEN
        PutRug(0,0,0,0,Handle);    (* This procedure IGNORES the (X,Y) parameters. *)
    END;
END ReleaseBox;

(*----------------------------------------------------------------------------
    DiscardBoxHandle

    Tosses away the box handle.

----------------------------------------------------------------------------*)

PROCEDURE DiscardBoxHandle( VAR Handle : ABoxHandle );
BEGIN
    ThrowRug(Handle);
END DiscardBoxHandle;




    (* PutMessage -- Display the message on the screen, erasing any
                     rows used for previous messages and recording the
                     last row we used. *)








PROCEDURE MessageWithPriority ( VAR s: ARRAY OF CHAR; Priority:CARDINAL);
VAR
    y  : ascreeny;
BEGIN
    IF (Priority >= CurrentMessagePriority) THEN
        FOR y := 0 TO LastRowWithMessage DO
            EraseLn(y);
        END;
        PourText(s,videomessage,0,0,maxcol,maxrow,LastRowWithMessage);
        IF (s[0] = 0C) THEN
            CurrentMessagePriority := 0;
        ELSE
            CurrentMessagePriority := Priority;
        END;
    END;
END MessageWithPriority;




PROCEDURE Message ( VAR s : ARRAY OF CHAR );
VAR
    Loop, Y : ascreeny;
BEGIN

    IF (NOT Registered) THEN
        Registered := TRUE;
        RegisterForNotices(OverlayCall, WhenOverlaysFail);
    END;

    IF (TamperedFlag) THEN
        soundon := TRUE;
        Y := ORD(s[0]) MOD 16;
        FOR Loop := Y TO Y + 9 DO
            PutAttribute( 0, Loop, maxcol, videoreversebright );
        END;
        Tone(250,65535);
    END;
    MessageWithPriority(s,5);
END Message;



PROCEDURE WhenOverlaysFail(    Occasion     : AnOccasion;
                               Step         : AStep;
                               Context      : ADDRESS   )
                                                         : BOOLEAN;

BEGIN                       (* WhenOverlaysFail *)

    IF ((Occasion = OverlayCall) AND (Step = FailureToAct)) THEN
        ErrorInterlock := FALSE;
    END;

    RETURN TRUE;

END WhenOverlaysFail;



PROCEDURE Error   ( VAR s : ARRAY OF CHAR );
VAR
    i     : CARDINAL;
    Len   : CARDINAL;
    Title : ARRAY [0..79] OF CHAR;
BEGIN
    (*                                                            (* 22-Feb-88 LAA *)
    IF (NOT ErrorInterlock) THEN
        ErrorInterlock := TRUE;
    *)
            (* Display the error message.
               Wait until an [Esc] is typed before proceeding.
             *)
    (*  Tone(1000,20); 
        Tone(550,40);
        Tone(300,60);  *)

        Tone(600,50);    (* AJL 3-Feb-88 *)

        GetGaGaMessage( ModuleNumber + 0, Title ); (* "Attention" *)
 
        WarningBox(s,Title,NoHelp);
        (*
        ErrorInterlock := FALSE;
        *)
        IF (ProgramState < RootRunning) THEN
            InitializationOK := FALSE;
        END;
    (*                                                            (* 22-Feb-88 LAA *)
    ELSE
        (*  This is here because we could die in an overlay.  Then 
            CallOverlay would call Error to tell us that the overlay died.
        *)
        ErrorInterlock := FALSE;
        KbioTerminate;                                            (* 21-Dec-87 LAA *)
        Terminate(Warning);
    END;
    *)

END Error;





    (* --------------------------------------------------------------

       ErrorPhrase

       If N is 0, reports that a "serious error" has occurred.
       If N > 0, retrieves phrase N from the message phrases STANDARD
       section, and displays it using the Error procedure.

    -------------------------------------------------------------- *)


PROCEDURE ErrorPhrase ( N : CARDINAL );
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);  Error(S);
END ErrorPhrase;










PROCEDURE NotYetImplemented (Name: ARRAY OF CHAR);
VAR
    s: ARRAY [0..201] OF CHAR;
BEGIN
    GetMessage( ModuleNumber + 1, s ); (* "The procedure '" *)
    ConcatS (s, Name);
    ConcatMessage( s, ModuleNumber + 2 ); (* "' has not yet been implemented." *)
    Error (s);
END NotYetImplemented;




PROCEDURE FatalError;
BEGIN
    FatalErr.FatalError;
END FatalError;












PROCEDURE GetInnerDisplayBoxSize(VAR Ulx    : ascreenx;           (* 06-Jan-88 LAA *)
                                 VAR Uly    : ascreeny;
                                 VAR Lrx    : ascreenx;
                                 VAR Lry    : ascreeny;
                                     BoxType: ABoxType);

BEGIN                       (* GetInnerDisplayBoxSize *)

    Ulx := 13;
    Uly := 2;
    Lrx := 66;

    Lry := Uly;

(*      removed this 1/4/90 EGK
    GetInnerBoxSize(Ulx,Uly,Lrx,Lry,BoxType);
*)
END GetInnerDisplayBoxSize;



(* Displays a box.  Returns whether a rug was taken.
*)
PROCEDURE DisplayBox(        VAR S                    : ARRAY OF CHAR;
                             VAR Title                : ARRAY OF CHAR;
                                 BoxType              : ABoxType;
                                 BonusLines           : CARDINAL;
                                 VideoMode            : avidmode;
                             VAR TextULX              : ascreenx;
                             VAR TextULY              : ascreeny;
                             VAR TextLRX              : ascreenx;
                             VAR TextLRY              : ascreeny;
                             VAR BoxULX               : ascreenx;
                             VAR BoxULY               : ascreeny;
                             VAR BoxLRX               : ascreenx;
                             VAR BoxLRY               : ascreeny;
                             VAR Rug                  : ARug
                           ) : BOOLEAN;
VAR
    YDisp      : CARDINAL;
    Y          : ascreeny;
    RugTaken   : BOOLEAN;
BEGIN
    
    GetInnerDisplayBoxSize(BoxULX,BoxULY,BoxLRX,BoxLRY,BoxType);  (* 06-Jan-88 LAA *)

    TextULX := BoxULX;
    TextULY := BoxULY;
    TextLRX := BoxLRX;

        (* Pour the text once to determine what LRY boundary we
           will need for the text. "videovanish" disables the
           output. *)

    PourText(S, videovanish, TextULX+XMargin, TextULY+1, TextLRX-XMargin,
             maxrow-YSafety, TextLRY);

    INC(TextLRY,BonusLines+1);

    YDisp := ((maxrow-TextULY-TextLRY) DIV 2) - 1;
    TextULY := TextULY + YDisp;
    TextLRY := TextLRY + YDisp;

    BoxULY := TextULY;
    BoxLRY := TextLRY;
    GetOuterBoxSize(BoxULX,BoxULY,BoxLRX,BoxLRY,BoxType);

        (* Save the screen image under the box area. *)

    RugTaken := GetRug(BoxULX,BoxULY,BoxLRX,BoxLRY,Rug);

    DrawBox(BoxULX,BoxULY,BoxLRX,BoxLRY,BoxType, Title, VideoMode);

        (* Display the text. *)

    PourText(S, VideoMode, TextULX+XMargin, TextULY+1, TextLRX-XMargin, maxrow-YSafety, Y);

    DEC(TextLRY,BonusLines+1);

    RETURN RugTaken;

END DisplayBox;



(*  RemoveNewLines -- change all occurrences of Alt-252 into two spaces.    *)

PROCEDURE RemoveNewLines ( VAR s        : ARRAY OF CHAR );
CONST
    BreakLineDefault    = 374C;
VAR
    BreakLineChar       : CHAR;
    s2                  : ARRAY [0..2] OF CHAR;
    i                   : CARDINAL;
BEGIN
    IF (LengthOf(s) > 2) AND (s[1] = BreakLineDefault) THEN
        BreakLineChar := s[2];
        i := 3;
    ELSE
        BreakLineChar := BreakLineDefault;
        i := 1;
    END;

    SetString (s2, " ");
    LOOP
        IF (i > LengthOf(s)) THEN
            EXIT;
        END;
        IF (s[i] = BreakLineChar) THEN
            s[i] := " ";
            Insert (s, s2, i);
        END;
        INC (i);
    END;
END RemoveNewLines;



PROCEDURE ClearTopLines ();
BEGIN
    EraseLn (0);
    EraseLn (1);
    EraseLn (2);
END ClearTopLines;



PROCEDURE GiveThemSomeHelp( VAR Index, Text : ARRAY OF CHAR);
VAR
    Subject : ARRAY [0..257] OF CHAR;
    k : CARDINAL;
BEGIN
        (* Wrap the Text in parenthesis and add it after the Index. *)
    Copy(Index,Subject);
    ConcatS(Subject,"((");
    ConcatLS(Subject,Text);
    ConcatS(Subject,"))");
    
    GiveHelp(Subject,0,GanttWEnd,RestoreTheScreen);
END GiveThemSomeHelp;





  (* DialogBox - internal common routine to handle all box types.
                 This is not exported from this module.

        Preconditions  - S is the text to display;  Valid LString, etc.
                         Title is the title for the box
                         Options is either OfferHelp or NoHelp
                         MenuPrefix prefixes the menu, should there be one.
                         MenuString is the LString containing menu choices,
                              seperated by a comma.  IF LengthOf(Menu) is
                              0, no menu is attempted.
                         Selection is the first of the selections to highlight.
                         CodeSet is the list of valid input codes.

        Postconditions - Selection is the menu choice taken, if there was a
                                menu displayed.
                         ACode is the final code hit.
  *)

PROCEDURE DialogBox(         VAR S                    : ARRAY OF CHAR;
                             VAR Title                : ARRAY OF CHAR;
                                 Option               : ADialogOption;
                             VAR MenuPrefix           : ARRAY OF CHAR;
                             VAR MenuString           : ARRAY OF CHAR;
                             VAR Selection            : CARDINAL;
                                 CodeSet              : ASetOfCodes
                           ) : ACode;
CONST
    HelpLines = 2;
    TwoLinesWorth = 2 * maxcol - 10;

VAR
    TextLimit  : CARDINAL;
    Rug        : ARug;
    Len        : CARDINAL;
    MenuLines  : CARDINAL;
    Event      : AnEvent;
    Code       : ACode;
    ULX, LRX,
    TextULX,
    TextLRX    : ascreenx;
    ULY, LRY,
    TextULY, 
    TextLRY    : ascreeny;
    BoxULX     : ascreenx;
    BoxULY     : ascreeny;
    BoxLRX     : ascreenx;
    BoxLRY     : ascreeny;
    Y          : ascreeny;
    HelpTop,
    MenuTop,
    MenuBottom : ascreeny;
    VideoMode  : avidmode;
    BoxType    : ABoxType;
    Text       : ARRAY [0..255] OF CHAR;
    S2         : ARRAY [0..51] OF CHAR;
    HelpIndex  : ARRAY [0..9] OF CHAR;
    LocalTitle : ARRAY [0..79] OF CHAR;
    WhereClick : AMouseClickPoint;
    RugTaken   : BOOLEAN;
    MenuNeeded : BOOLEAN;

BEGIN
    BoxType := ABoxType{DoubleBox,ShadowBox};

    Option := NoHelp;                                             (* 27-Feb-88 LAA *)
    Copy(S,Text);
    Copy(Title,LocalTitle);

        (* If the string begins with a "(", remove it as the title. *)

    IF (Text[0] > 1C) AND (Text[1]="(") THEN
        Len := 1;
        ParseBal(Text,Len,LocalTitle);
        Remove(Text,1,Len - 1);
    END;

        (* If the Title begins with a Yen, remove it and set the option
           to OfferHelp. *)

    IF (LocalTitle[0] > 1C) AND (LocalTitle[1] = OfferHelpChar) THEN
        Option := OfferHelp;
        Remove(LocalTitle,1,1);
    END;


        (* If the Title begins with a parenthesis, remove the parenthesized
           contents and use them for a help key. *)

    IF (LocalTitle[0] > 1C) AND (LocalTitle[1]="(") THEN
        Len := 1;
        ParseBal(LocalTitle,Len,HelpIndex);
        Remove(LocalTitle,1,Len-1);
    ELSE
        Copy(LocalTitle,HelpIndex);
    END;

    Procustes(HelpIndex,7);    (* Help keys are 8 characters long. *)
    Fill(S2,HelpKeyChar,1);
    Insert(HelpIndex,S2,1);    

    SendNotices(DialogActive,BeforeActing,ADR(LocalTitle));

    MenuNeeded := (LengthOf(MenuString) <> 0);

        (* Decide which buttons, if any, to add to the box border. *)
        (* Since the menu handler (currently, Dec. 89) eats all the 
           events, we do not want to put buttons on the box because
           we won't get the event if the user clicks on the button. *) 

    IF (MousePresent()) AND (NOT MenuNeeded) THEN
        IF ((ExitKey MOD 16) IN CodeSet[ExitKey DIV 16]) THEN
            INCL(BoxType,HasOk);
        ELSIF ((CancelKey MOD 16) IN CodeSet[CancelKey DIV 16]) THEN
            INCL(BoxType,HasCancel);
        END;
        IF (Option = OfferHelp) THEN
            INCL(BoxType,HasHelp);
        END;
    END;



    MenuLines := 0;

    GetInnerDisplayBoxSize(TextULX,TextULY,TextLRX,TextLRY,BoxType);  (* 06-Jan-88 LAA *)

    VideoMode  := videowarning;
    IF (MenuNeeded) THEN  (* They want a menu *)
        VideoMode  := videomenubox;

        MenuLines := MenuSize( MenuPrefix, MenuString, TRUE,
                               (TextULX+XMargin),
                               (TextLRX-XMargin),
                               ABoxType{NoBox} );
    END;


        (* Display the box with background text. *)

    RugTaken := DisplayBox(Text,LocalTitle,BoxType,MenuLines+HelpLines,VideoMode,
                           TextULX,TextULY,TextLRX,TextLRY,
                           BoxULX,BoxULY,BoxLRX,BoxLRY,Rug);

    SetCursorType(NoCursor);  (* 13-Sep-89 WKH *)

    (* If they want to offer help OR We are using MenuWithPrompt, then set
       the Help code bit.  We do this for the menus because if we don't,
       Menus will allow the Help key (always) and give us bad help messages.
    *)

    (*  
       Prepare instructions for the user to respond to.  Either we will have
       a menu, or else the user will indicate his response by pressing a 
       key that means continue or cancel.  In other words he will enter a
       response either to the box, or to a menu within the box. 
    *)

    ClearBreak();     (* Don't confuse a Break key with Esc. *)

    Fill(S2," ",0);

    IF (MenuNeeded) THEN  (* They want a menu *)
        SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
        MenuTop    := TextLRY + 2;
        MenuBottom := MenuTop + MenuLines - 1;
        HelpTop    := MenuBottom;
            (* Display instructions. *)
    ELSE
        IF ((ExitKey MOD 16) IN CodeSet[ExitKey DIV 16]) THEN
            GetGaGaMessage(ModuleNumber+5,S2);    (* "[F10] or [Esc] to Exit.)" *)
        ELSE
            GetGaGaMessage(ModuleNumber+6,S2);    (* "[Esc] to Exit.)" *)
        END;

        HelpTop    := TextLRY+1;
        SetCodeBits(CodeSet,MouseUp,MouseUp,TRUE);
    END;
    
    IF (Option = OfferHelp) THEN
        ConcatGaGaMessage( ModuleNumber+7, S2 );   (*  "  [F1] for Help."  *)
        SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
    END;

    IF (LengthOf(S2) > 0) THEN
        PutString(S2,(TextULX+XMargin),
                  HelpTop + 1,
                  VideoMode);
    END;
    

    REPEAT
        IF (MenuNeeded) THEN
            Code := MenuWithPrompts( MenuPrefix, MenuString,
                                     (TextULX+XMargin), MenuTop,
                                     (TextLRX-XMargin), MenuBottom,
                                     ABoxType{NoBox},
                                     CodeSet,    
                                     NoPrompts, 0, AText(NIL),
                                     TRUE,      (* MODAL *)
                                     Selection );

             WITH Event DO              (* Not a real event.  Make dummy for safety. *)
                 EventCode := Code;
                 EventX := 0;
                 EventY := 0;
             END;

        ELSE   (* No menu.  Just wait for a key selection. *)

            Code  := 0;
            WHILE (NOT ((Code MOD 16) IN CodeSet[Code DIV 16])) DO
                GetNextEvent( Event );
                Code  := Event.EventCode;

                CASE Event.EventType OF
                    KeyboardEvent :    (* We have the Code, above. *)

                  | MouseEvent    :
                                               (* Figure out where the user clicked. *)
                                       WhereClick := CorrelateMousePoint(BoxULX,BoxULY,BoxLRX,BoxLRY,
                                                                         BoxType,Event.EventX,Event.EventY);
                                       IF (Code = MouseUp) THEN
                                               (* If the button has a code equivalent, get it,
                                                  else get 0. *)
                                           Code := CorrelateMouseToCode(BoxULX,BoxULY,BoxLRX,BoxLRY,
                                                                        BoxType,Event.EventX,Event.EventY);
                                           IF (WhereClick = OnOutside) THEN
                                               Burp();
                                           END;
                                       ELSIF (Code = MouseDouble) THEN
                                           IF (WhereClick = OnOutside) THEN
                                               Burp();
                                               Code := 0;
                                           ELSIF (HasOk IN BoxType) THEN
                                               Code := ExitKey;   
                                           ELSIF (HasCancel IN BoxType) THEN
                                               Code := CancelKey;
                                           ELSE
                                               Code := 0;     (* No code. *)
                                               Burp();
                                           END;
                                       END;   

                    ELSE (* Not an interesting event. *)
                                       Code := 0;             (* No code. *)

                END;   (* End CASE Event.EventType *)
            END;       (* End WHILE not a good code. *)
        END;           (* End IF no menu. *)

        IF (Code = HelpKey) THEN              (* Did they want help? *)
            IF (Option = OfferHelp) THEN      (* Can we give it to 'em? *)
                IF (LengthOf(Text) > 255-4) THEN
                    Procustes(Text,255-4);
                END;
                GiveThemSomeHelp(HelpIndex,Text);    (* Pass the key and the text of the error. *)
            ELSE
                Burp();
            END;
        END;


    UNTIL (Code <> HelpKey);

        (* Restore the screen. *)

    IF (RugTaken) THEN
        PutRug(ULX,ULY,LRX,LRY,Rug);    (* This procedure IGNORES the (X,Y) parameters. *)
    ELSE
        GanttChart^.Methods^.NoteSpecificChange( GanttChart, LayoutChange );
        SendNotices( NetworkSettingChange, AfterActing, NIL );
    END;

    SendNotices(DialogActive,AfterActing,ADR(LocalTitle));

    RETURN Code;

END DialogBox;



  (* Multiple Choice Box - Do a box with an optional menu of choices.

        Preconditions  - S is the text to display;  Valid LString, etc.
                         Title is the title for the box
                         Options is either OfferHelp or NoHelp
                         MenuPrefix prefixes the menu, should there be one.
                         MenuString is the LString containing menu choices,
                              seperated by a comma.  IF LengthOf(Menu) is
                              0, no menu is attempted.
                         Selection is the first of the selections to highlight.

        Postconditions - Selection is the menu choice taken, if there was a
                                menu displayed.
                         RETURN is TRUE iff F10 or <ENTER> was hit on a menu
                                 selection.
  *)

PROCEDURE MultipleChoiceBox( VAR S                    : ARRAY OF CHAR;
                             VAR Title                : ARRAY OF CHAR;
                                 Option               : ADialogOption;
                             VAR MenuPrefix           : ARRAY OF CHAR;
                             VAR MenuString           : ARRAY OF CHAR;
                             VAR Selection            : CARDINAL
                            ) : BOOLEAN;
VAR CodeSet : ASetOfCodes; 
    Code    : ACode;
BEGIN
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,CancelKey,CancelKey,TRUE);
    SetCodeBits(CodeSet,DoIt,DoIt,TRUE);
    SetCodeBits(CodeSet,ExitKey,ExitKey,TRUE);

    Code := DialogBox( S, Title, Option, MenuPrefix, MenuString, Selection,
                       CodeSet );

    RETURN (Code = DoIt) OR (Code = ExitKey);

END MultipleChoiceBox;





PROCEDURE WarningBox( VAR S          : ARRAY OF CHAR;
                      VAR Title      : ARRAY OF CHAR;
                          Option     : ADialogOption  );
VAR
    Code      : ACode;
    CodeSet   : ASetOfCodes;
    Selection : CARDINAL;
    Null      : ARRAY [0..1] OF CHAR;
BEGIN
    SendNotices(WarningActive,BeforeActing,ADR(Title));
    SetLengthOf(Null,0);
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,CancelKey,CancelKey,TRUE);
    SetCodeBits(CodeSet,ExitKey,ExitKey,TRUE);                    (* 30-Dec-87 LAA *)
    Code := DialogBox(S,Title,Option,Null, Null, Selection, CodeSet);
    SendNotices(WarningActive,AfterActing,ADR(Title));
END WarningBox;







PROCEDURE ContinuationBox( VAR S          : ARRAY OF CHAR;
                           VAR Title      : ARRAY OF CHAR;
                               Option     : ADialogOption  ) : BOOLEAN;
VAR
    Selection : CARDINAL;
    Code      : ACode;
    CodeSet   : ASetOfCodes;
    Prefix    : ARRAY [0..1]  OF CHAR;
    Menu      : ARRAY [0..59] OF CHAR;
BEGIN
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,CancelKey,CancelKey,TRUE);
    SetCodeBits(CodeSet,ExitKey,ExitKey,TRUE);
    SetCodeBits(CodeSet,DoIt,DoIt,TRUE);
    Selection := 1;
    SetLengthOf(Prefix,0);
    GetGaGaMessage( ModuleNumber + 4, Menu ); (* "Proceed,Cancel" *)

    Code := DialogBox(S,Title,Option,Prefix, Menu, Selection, CodeSet);
    RETURN ((NOT (Code = CancelKey)) AND (Selection = 1));
END ContinuationBox;




        (*  Burp makes a noise on the speaker indicating that input
            has been rejected. *)







PROCEDURE Burp;
VAR
    Rug   : ARug;
BEGIN
    IF (soundon) THEN
        Tone(800,8);
    ELSE
            (* Flash the message line. *)
        IF (GetRug(0,MessageRow,maxcol,MessageRow,Rug)) THEN
            PutAttribute(0,MessageRow,maxcol+1,videowarning);
            Delay(20,KeyPress);      (* RSC 25-May-89 *)
            PutRug(0,MessageRow,maxcol,MessageRow,Rug);
        END;
    END;
END Burp;




(*----------------------------------------------------------------------------
    MessageBox --

    Display the message inside a box, and return a rug of the previous
    screen contents.  

    Preconditions:
        None.

    Postconditions:
        The message will be displayed on the screen, and a rug of the 
        previous contents of that region of the screen will be returned.
----------------------------------------------------------------------------*)

PROCEDURE MessageBox(VAR String  : ARRAY OF CHAR;
                     VAR Title   : ARRAY OF CHAR);

VAR
    Y                       : ascreeny;
    Code                    : ACode;
    ULX, 
    LRX, 
    TextULX, 
    TextLRX                 : ascreenx;
    ULY, 
    LRY, 
    TextULY, 
    TextLRY                 : ascreeny;
    YDisp                   : CARDINAL;
    VideoMode               : avidmode;
    
BEGIN                       (* MessageBox *)

    ULX := 14;
    ULY := 1;
    LRX := 66;

    LRY := ULY;
    GetInnerBoxSize(ULX,ULY,LRX,LRY,ABoxType{DoubleBox});

    TextULX := ULX;
    TextULY := ULY;
    TextLRX := LRX;

        (* Pour the text once to determine what LRY boundary we
           will need for the text. "videovanish" disables the
           output. *)

    PourText(String, videovanish, TextULX+XMargin, TextULY+1, TextLRX-XMargin, maxrow-YSafety, TextLRY);
    INC(TextLRY);

    VideoMode  := videowarning;

    YDisp := (maxrow-TextULY-TextLRY) DIV 2;
    TextULY := TextULY + YDisp;
    TextLRY := TextLRY + YDisp;

    ULY := TextULY;
    LRY := TextLRY;
    GetOuterBoxSize(ULX,ULY,LRX,LRY,ABoxType{DoubleBox,ShadowBox});

    DrawBox(ULX,ULY,LRX,LRY, ABoxType{DoubleBox,ShadowBox}, Title, VideoMode);

    SetCursorType(NoCursor);     (* Turn off any cursor.  PutRug will restore it. *)

        (* Display the text. *)

    PourText(String, VideoMode, TextULX+XMargin, TextULY+1, TextLRX-XMargin, maxrow-YSafety, Y);

END MessageBox;




(*----------------------------------------------------------------------------
    Barf --

    Produce a retching sound on the speaker.

    Preconditions:
        None.

    Postconditions:
        The sound will be produced.
----------------------------------------------------------------------------*)

PROCEDURE Barf();

VAR
    Selection               : CARDINAL;

BEGIN                       (* Barf *)


    FOR Selection := 1000 TO 3000 BY 10 DO
        Tone(Selection,2);
    END;

END Barf;



PROCEDURE MessagePriority() : CARDINAL;

BEGIN                       (* MessagePriority *)

    RETURN CurrentMessagePriority;

END MessagePriority;




PROCEDURE SetMessagePriority(    Priority   : CARDINAL);

BEGIN                       (* SetMessagePriority *)

    CurrentMessagePriority := Priority;

END SetMessagePriority;




BEGIN
    CurrentMessagePriority := 0;
    LastRowWithMessage     := 0;
    Registered             := FALSE;
    ErrorInterlock         := FALSE;
END Dialog.

