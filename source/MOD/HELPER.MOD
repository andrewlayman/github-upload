(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

IMPLEMENTATION MODULE Helper;

    (* MODIFICATION HISTORY

       25 Jun 86   AJL - Add conditional Goto based on KeyPress.
                       - Add goto line command ("@").
                       - Add pause command, "#".
       14 Jul 86   AJL - Add indentation command, ")".
                       - Stack the indentations and y positions on
                         each subtext call.
                       - All @ positioning is relative to the starting
                         y as of the subtext call.
                       - Allow @-n to position relative to the end
                         of the window.
       24 Jul 86   AJL - Add "^" command to call a named overlay.
                         "^>" will call a named overlay file.
                         "^@" will execute the action given in plwhat.cfg.
                         "^=" will call the dispatcher with the following keycode.
                       - These commands can be also given in the menus,
                         that is, a menu choice (or alias) can begin with
                         a "^" character.
                       - Nested help does not overwrite the lights (last)
                         line on the screen.
                       - Modified the routines to allow reentrant calls
                         to GiveHelp.
       11/12/86 LAA    - In OpenHelpFiles, added a call to PrepareForIO.
       07/23/87 AJL    - Remove references to Dispatcher and RunMenu.
       08/24/87 EGK      Incorporated new object-oriented indexing scheme.
                         Moved expander into its own external module.
        9/29/87 AJL    - Changed the video control character to 375C
                         (Alt-253).
       10/14/87 EGK      Moved help index procedures outside of ManageHelp
                         and added TakeABranch procedure to allow
                         EscapeToOverlay (or any other routine) to directly
                         get a help item.
          ????  EGK?   - Moved most of the code into an overlay.
        2/29/88 AJL    - Removed the shadows from the box to give more text
                         room.
       06-Mar-88 LAA     Called ShowLights after enabling them.
       10-Jan-89 RSC     Changed Storage to Space    .
       12-May-91 AJL   - Add HelpExists.
                       - Commented-out MoveHelpBox and MoveToAvoid because
                         there are no current clients.

    *)

FROM Space      IMPORT ALLOCATE, DEALLOCATE;

FROM Kbio       IMPORT  ascreeny, maxrow, maxcol,
                        avidmode,
                        ascreenx;

FROM Dialog     IMPORT  Message, Error, WarningBox, FatalError, Burp,
                        ADialogOption, NotYetImplemented;

FROM LStrings   IMPORT  SetString, Copy,
                        CtoS, LengthOf, LJust, TrimRear;

FROM Rugs       IMPORT ARug, GetRug, PutRug;

FROM Boxes      IMPORT ABoxType, ABoxAttribute, DrawBox, GetInnerBoxSize;

FROM Lights     IMPORT EnableLights, ActiveLightRegion, ShowLights;

FROM MsgFile    IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays   IMPORT CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;


CONST
    ModeCharacter = 375C;
    TextNameNumber = 12;
    IndexNameNumber = 13;
    TagLength  = 8;
    MaxChoicesLen = 250;
    MaxSaveChoicesLen = 79;
    ModuleNumber = 1900;    (* For GetMessage *)
    OurTag = 0B0B0H;

TYPE
    AHelpBoxRecord = RECORD
                         Tag    : CARDINAL;
                         ulx    : ascreenx;
                         uly    : ascreeny;
                         lrx    : ascreenx;
                         lry    : ascreeny;
                         BType  : ABoxType;
                         Act    : AScreenAction;
                         Rug    : ARug;
                     END;
    AHelpBox = POINTER TO AHelpBoxRecord;




PROCEDURE CheckHelpBoxValid( HelpBox : AHelpBox );
BEGIN
    IF (HelpBox^.Tag <> OurTag) THEN FatalError; END;
END CheckHelpBoxValid;


    (* DoWork -- Calls the helper overlay with the help context. *)


PROCEDURE DoWork( VAR Context : AContextRecord );
VAR
    OverlayName         : ARRAY [0..10] OF CHAR;
BEGIN
    Context.Reaction := 0;
    SetString (OverlayName, "TLHELPER");
    IF (CallOverlayWithContext (OverlayName, ADR(Context))) THEN
    END;
END DoWork; 





    (* OpenHelpBox -- Open a help box on the screen.  *)

PROCEDURE OpenHelpBox(     Subject : ARRAY OF CHAR;
                           BoxType : ABoxType;
                           ULX     : ascreenx;
                           ULY     : ascreeny;
                           LRX     : ascreenx;
                           LRY     : ascreeny;
                           ScreenAction : AScreenAction;
                       VAR HelpBox : AHelpBox    )  : BOOLEAN;

VAR
    S                   : ARRAY [0..81] OF CHAR;
    Context             : AContextRecord;

BEGIN

    (*<NORMAL*)

    NEW(HelpBox);
    IF (HelpBox = NIL) THEN
        GetMessage( ModuleNumber + 17, S ); (* "Not enough memory for help." *)
        Error(S);
        RETURN FALSE;
    END;
    WITH HelpBox^ DO
        Tag := OurTag;
        ulx := ULX;
        uly := ULY;
        lrx := LRX;
        lry := LRY;
        Act := ScreenAction;
        BType := BoxType;
    END;

        (*  Try to save an image of the original screen. *)

    IF (NOT GetRug(ULX,ULY,LRX,LRY,HelpBox^.Rug) ) THEN
        DISPOSE(HelpBox);
        RETURN FALSE;
    END;

    GetMessage (ModuleNumber+15, S);
    DrawBox(ULX,ULY,LRX,LRY,BoxType,S,videonormal);

    GetInnerBoxSize(ULX,ULY,LRX,LRY,BoxType);

    EnableLights(FALSE);   (* Turn off status lights--we may need the room. *)


    Context.Action := 1;                (* Action code 1 means display help. *)
    Context.Depth := 1;
    Copy (Subject, Context.Subject);
    Context.ULX := ULX;
    Context.ULY := ULY;
    Context.LRX := LRX;
    Context.LRY := LRY;
    Context.ScreenAction := ScreenAction;

    DoWork(Context);   (* Call an overlay to do the real work. *)

    EnableLights(TRUE);   (* Turn on status lights. *)

    IF (ScreenAction = RestoreTheScreen) THEN
        CloseHelpBox(HelpBox);
    END;

    ShowLights(ActiveLightRegion);                                (* 06-Mar-88 LAA *)
    (*NORMAL>*)

    RETURN TRUE;
END OpenHelpBox;







PROCEDURE CloseHelpBox( VAR HelpBox : AHelpBox );
BEGIN
    CheckHelpBoxValid(HelpBox);
    WITH HelpBox^ DO
        PutRug(ulx,uly,lrx,lry,HelpBox^.Rug);
    END;
    DISPOSE(HelpBox);
END CloseHelpBox;





PROCEDURE MoveHelpBox( VAR HelpBox : AHelpBox;
                           ULX     : ascreenx;
                           ULY     : ascreeny;
                           LRX     : ascreenx;
                           LRY     : ascreeny );
VAR
    OurRug : ARug;
BEGIN
    (*-------------------------------------------------------
        (* Get an image of the help box.
           Restore the previous screen before box was there.
           Get an image of the screen under the new location.
           Display the help box image.
        *)
    WITH HelpBox^ DO
        IF (GetRug(ulx,uly,lrx,lry,OurRug)) THEN
            PutRug(ulx,uly,lrx,lry,Rug);
            ulx := ULX;
            uly := ULY;
            lrx := ULX+lrx-ulx;
            lry := ULY+lry-uly;
            IF (GetRug(ulx,uly,lrx,lry,Rug)) THEN
                PutRug(ulx,uly,lrx,lry,OurRug);
            END;
        END;
    END;
    ------------------------------------------------------- *)
END MoveHelpBox;





PROCEDURE MoveToAvoid( VAR HelpBox : AHelpBox;
                           ULX     : ascreenx;
                           ULY     : ascreeny;
                           LRX     : ascreenx;
                           LRY     : ascreeny );
BEGIN
END MoveToAvoid;






    (*  GiveHelp -- Using screen lines First..Last, present
                    help about Subject.  Subject is a name of at
                    most 8 characters, please. *)


PROCEDURE GiveHelp (Subject:ARRAY OF CHAR; First, Last: ascreeny;
                    ScreenAction : AScreenAction);
VAR
    HelpBox : AHelpBox;
BEGIN

    (*<NORMAL*) 

    IF OpenHelpBox(Subject,ABoxType{DoubleBox},0,First,maxcol,Last,ScreenAction,HelpBox) THEN
        IF (ScreenAction <> RestoreTheScreen) THEN
            CloseHelpBox(HelpBox);
        END;
        ShowLights(ActiveLightRegion);                            (* 06-Mar-88 LAA *)
    END;

    (*NORMAL>*)

END GiveHelp;


    (* HelpExists -- Returns TRUE iff there is help about the subject. *)

PROCEDURE HelpExists (Subject:ARRAY OF CHAR):BOOLEAN;
VAR
    Context             : AContextRecord;
BEGIN
    Context.Action := 0;                (* Action code 0 means check help subject. *)
    Copy (Subject, Context.Subject);
    DoWork(Context);                    (* Call an overlay to do the real work. *)
    RETURN (Context.Reaction > 0);
END HelpExists;




BEGIN
END Helper.
