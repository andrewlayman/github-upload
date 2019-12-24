(*V9=DEBUGGING*)

MODULE TLSetVideo;

(*----------------------------------------------------------------------------

    V1= Without custom options
    V2= With custom options

       MODIFICATION HISTORY

       Nov. 6, 1986  AJL -- Added mention of the Hercules Mono-Graphics
                            board, and added two new Dim Color palettes.
                            Mentioned Zenith 200.
       Nov. 24, 1986 AJL -- Allow Escape from the GetTypes menu.
                         -- Show the hexadecimal value of each cursor
                            position.
                         -- Display the name of the video attribute when
                            asking "normal, cursor superimposed".
                         -- Print the names of the attributes as part of
                            showing a sample.
                         -- Add a second color palette to the normal group.
                         -- "Other" setting will now be treated as a
                            generic compatible.
                         -- Compaq Deskpro can now have color tubes.
        Dec. 2, 1986 AJL -- Monochrome tube, Color board choice was not
                            assigning any value to the "s" variable in
                            procedure BuildVideoTable.
        Dec. 5, 1986 AJL -- CGA Blue/Yellow (String3) form background changed
                            from 80 to 83 to show up better on IBM monitors.

        3/26/87 EGK:    Converted this version to run with Time Line 3.0, by:

                        New imports: InitializeVideoHardware, GetCursorType,
                            SetCursorType, MaxCode, GanttWEnd, ConfigSaved,
                            WordNumber, LocateHeldItem, AHoldTypeSet.
                        New ComputerType: GetOptions.
                        WhiteOnBlack and BlackOnWhite constants changed to
                            sets (not cardinals).
                        Changed Menu procedure calls to conform with new
                            MENUS.DEF.  Now takes 4 coordinates but no name.
                        Added SelectVideoOption procedure from previous version
                            (Sets Fast/Clean option and reprograms 6845).
                        Added "Video Options" menu item.
                        Reads in BlinkFlag and CleanFlag bits from Holder.
                        GetRug at beginning and PutRug at end of main code.
        Jun. 16, 1987 AJL-- Added mention of the IBM PS/2 models, and the
                            LCD screen options.
        Sep. 6, 87   AJL -- Added ATT Mono palette 2, and fixed the CGA
                            blue/Yellow and blue/pink pallettes.  Blue/Pink is
                            unfinished (as are most other palettes.)
        Sep. 28, 87  AJL -- Changed the CGA pallettes to ones supplied by David
                            Bryan.
                         -- Added listing for the Compaq portable III.
        Oct. 15, 87  RSC -- Cleaned up Menu useage to use NoYes() where
                            possible.  Also renamed menu items called
                            "Graph xxxx" to be more descriptive (I hope).
        Nov.  6, 87  RSC -- remove extra spaces from menu choices.  Redisplay
                            lights after setting video.

        27-Nov-87 LAA       Added video modes for the network view.

        30-Dec-87 AJL    -- Fixed the customize menus to work in two steps.

        7 -Jan-88 AJL    -- Changed names of CGA palettes.
                         -- Enabled CGA palette 6.
                         -- Made HighestMode a global constant.

       26-Jan-88  AJL    -- Pressing F9 within custom setup will now print
                            the video strings to a report.
                         -- Corrected an error with the setting of shadow.
        3-Feb 88  AJL    -- Added a seventh standard palette.
                         -- Corrected an error with setting resting cursor.
       11-Feb-88  LAA    -- The printer stuff is now in DEBUGGING version.
       12-Feb-88  AJL    -- Set Tube type when user picks "Other".
                         -- Rephrased the PS/2 adapter card choices.
       19-Feb-88  AJL    -- 3270 Plasma now uses the LCD palette.
                         -- installed a better Compaq Deskpro palette.
                         -- Allow setting specific cursor modes.
       24-Feb-88  AJL    -- Fixed when the TransparentShadow is set.
       15-Mar-88  AJL    -- Changed the EGA colors.
       19-Aug-88  AJL    -- Changed EGA and VGA to use the CGA color settings,
                            now that we have a version of Video (or TLVIDEGA)
                            that enables bright backgrounds on these monitors.
       20-Oct-88  AJL    -- Do not reset the secondary and resting cursor modes
                            when cursors are set.
                         -- Change the Grey setting for CGA/EGA to a richer one.
       16-Nov-88  AJL    -- Converted to use MsgFile and PourText.
        2-Jan-89  RSC    -- Removed references to Compare() (not used).
       25-May-89  AJL    -- Added new video board types, EGA, VGA and MCGA.
       26-May-89  AJL    -- Second cursor selects background only.
                         -- CGA, VGA, MCGA and EGA all use the richer palettes.  
                            Generic doesn't. 
                         -- Ask about auto-detecting the adapter board type.
                         -- Increase string lengths.
                         -- Remove the "Do you really want to change . . ." question.
       10-Aug-89  KKC    -- Add copyright message.
       18-Aug-89  AJL    -- Redisplay the Gantt chart after changing video, or,
                            at least, try to.
                         -- Send notices.
                         -- Don't change all cursors if user selects the same 
                            background as it was previously.  
       24-Aug-89  AJL    -- Tune the foreground colors of cursors to avoid 
                            some color clashes.
                         -- Don't call the Gantt chart redisplay explicitly.
       13-Sep-89  LAA    -- The CleanFlag and BlinkFlag are now exported from
                            Kbio, rather than kept in Holder.  This was done
                            to separate these flags from report data.
       15-Nov-89  AJL    -- Allow monochrome monitors on VCG,EGA and MCGA boards.
                         -- Compaq deskpro is now treated as an IBM clone.
       16-Nov-89  AJL    -- Only reinitialize the video hardware if the user
                            changes the BlinkFlag or the CleanFlag.  
       30-Nov-89  AJL    -- Avoid any changes to the video types unless all
                            questions are answered.  Escaping from the 
                            menus will not cause the video settings to change.  
        5-Dec-89  AJL    -- Avoid changes to video types when merely customizing
                            colors.
       12-Dec-89  RSC    -- New parameter to menus.
       15-Dec-89  RSC    -- Mouse support.
       20-Dec-89  AJL    -- Mouse buttons.
        2-Jan-90  AJL    -- Reused the unused video attributes videonetstarted
                            and videonetdone as mouse button attributes.    
        3-Jan-90  RSC    -- Made the menus non-modal (allow esc)
        4-Oct-90  AJL     - Renamed the videonetstarted and videonetstarted
                            to videobutton and videoscrollbar.
                          - Add videographvac, the vacations attribute on histograms.
       26-Dec-90  AJL     - Add VGAPlasma tupe type to support Toshiba portables.
----------------------------------------------------------------------------*)

    FROM Boxes      IMPORT
        (* TYPE *)         ABoxType, ABoxAttribute,
        (* VAR *)          TransparentShadow;

    FROM Buttons    IMPORT
        (* TYPE *)         AButtonCollection, AnOrientation,
                           CreateButtonCollection, DisposeButtonCollection,
                           CorrelateMouseToButton;


    FROM Codes      IMPORT ACode, ASetOfCodes, SetCodeBits, MaxCode;

    FROM Chart      IMPORT
        (* VAR *)          GanttChart,
        (* PROC *)         ShowSched;

    FROM ChartControl IMPORT 
        (* TYPE *)         AChartState, 
        (* PROC *)         UnSetState;


    FROM Dialog     IMPORT Burp, Message, Error, FatalError,
                           ContinuationBox, ADialogOption;

    FROM Events     IMPORT
        (* TYPE *)          AnEvent, AnEventType,
        (* PROC *)          GetNextEvent;

    FROM Holder     IMPORT LocateHeldItem, AHoldTypeSet;    (* 3/26/87 EGK *)

    FROM Kbio       IMPORT ascreenx, ascreeny, maxrow, maxcol, avidmode,
                           vidctrl, KbioInit, CleanFlag, BlinkFlag,
                           EraseLn, PutString,
                           GotoXY, EraseScreen,
                           PourText;

    FROM Keys       IMPORT DoIt, CancelKey, ExitKey, HelpKey,
                           Fwrd, Reverse, Up, Down, UndoKey,
                           ComputeKey,
                           MouseDown, MouseUp, MouseStillDown, MouseDouble;

    FROM Layout     IMPORT GanttWEnd, MenuStart, MenuEnd;

    FROM Lights     IMPORT ShowLights, ActiveLightRegion;

    FROM LStrings   IMPORT SetString, SubStr, Procustes, CtoS, StoC,
                           ConcatS, ConcatLS, Insert, Remove, Fill,
                           LJust, RJust, Overlay, LStringToTString,
                           Upshift, Copy, SetLengthOf;

    FROM Menus      IMPORT Menu, NoYes, WordNumber;

    FROM MsgFile    IMPORT GetMessage, ConcatMessage;

    FROM Notices    IMPORT
        (* TYPE *)         AnOccasion, AStep,
        (* PROC *)         Permission, SendNotices;

    FROM Rugs       IMPORT ARug, GetRug, PutRug;

    FROM Schedule   IMPORT ConfigSaved, InstalledFlag;

    FROM SYSTEM     IMPORT ADR, TSIZE;

    FROM Video      IMPORT PutStringWithAttribute, InitializeVideoHardware, (* 3/26/87 EGK *)
                           GetCursorType, SetCursorType;

    FROM VidType    IMPORT 
        (* TYPE *)         AComputerType, ABoardType, ATubeType, AQuestionType,
        (* VAR *)          VideoConfiguration, Answers;

    (*<DEBUGGING*)
    FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;
    (*DEBUGGING>*)


CONST
    DefaultInputName = "DK:TLCONFIG.DAT";
    ModuleNumber     = 26500;

TYPE
        (* "Avidmode" is the shorthand representation of video attributes
           for the display screen.  These values are to be used in the client
           modules to refer to all video attributes.  The first four are
           normal video modes, and the next four represent a combination of
           one of the first four overlayed by the "cursor."

           The actual translation of avidmode into video attribute bits,
           or other hardware dependent features, may be controlled by
           the vidctrllist.  This list will need to be initialized, in some
           hardware dependent manner, before videmodes have their desired
           effects. *)


    avidctrllist = ARRAY avidmode OF BITSET;
    AVideoTablePointer = POINTER TO avidctrllist;

    AComputerTypeSet = SET OF AComputerType;
    ABoardTypeSet    = SET OF ABoardType;
    ATubeTypeSet     = SET OF ATubeType;



VAR
    InputName    : ARRAY [0..81] OF CHAR;
    s,s2         : ARRAY [0..255] OF CHAR;
    VideoTable   : AVideoTablePointer;
    l            : ascreeny;
    Palette      : CARDINAL;
    Rug          : ARug;
    Category     : AHoldTypeSet;
    i            : CARDINAL;
    RugTaken     : BOOLEAN;

    (* These constants give the phrase numbers in the phrase file that 
       contain the various video setups. *)

CONST

    VideoStringBase = ModuleNumber + 120;

    DefaultVideoString      = 0;
    MonoBoardString         = 1;
    ColorString             = 2;            (* A range *)
    IBMCGAString            = 12;           (* A range *)
    Mono3270String          = 22;
    CompaqPortableString    = 23;
    P13270String            = 24;           (* A range *)
    LCDString               = 26;
    CompaqPIII              = 27;
    ATTMonoString2          = 28;
    VGAPlasmaString         = 29;

    ReprogrammableColorBoards = ABoardTypeSet{CGABoard,MCGABoard,EGABoard,VGABoard,MCGABoard,ATTBoard};
    ColorBoards = ABoardTypeSet{CGABoard,MCGABoard,EGABoard,VGABoard,MCGABoard,ATTBoard,GenericColorBoard};



    (*+2<*)
    (* --------- BEGIN MODULE CustomizedVideo  ---------------------*)

MODULE CustomizedVideo;

IMPORT ascreenx, ascreeny, vidctrl, avidmode, maxcol, maxrow, EraseScreen,
       TransparentShadow,
       Message, FatalError, MenuEnd,
       Fill, SetString, ConcatS, ConcatLS, Copy, SubStr, Upshift, Overlay,
       Insert, SetLengthOf,
       Fwrd, Reverse, Up, Down, DoIt, ExitKey, CancelKey, UndoKey, ComputeKey,
       ACode, Burp,
       SetCodeBits, MaxCode, ASetOfCodes,
       MenuStart, WordNumber, GanttWEnd,
       Menu,
       QuickMenu,
       PutStringWithAttribute,
       ARug, GetRug, PutRug,
       GetMessage, ConcatMessage, ModuleNumber,

       MouseDown, MouseUp, MouseStillDown, MouseDouble,
       AnEvent, GetNextEvent, AnEventType,  (* 15-Dec-89 RSC  *)
       ABoxType, ABoxAttribute,
       AButtonCollection, AnOrientation,
       CreateButtonCollection, DisposeButtonCollection,
       CorrelateMouseToButton

       (*<DEBUGGING*)
       , StartReport, EndReport, PrintLine
       (*DEBUGGING>*) ;






EXPORT  MakeCustomVideoSetup;

CONST
    ULX   = 5;
    ULY   = 6;
    LRX   = ULX+15;
    LRY   = ULY+15;
    WhiteOnBlack = {0..2};      (* White foreground, Black background *)   (* 3/26/87 EGK *)
    BlackOnWhite = {4..6};      (* Black foreground, White background *)



    (* Adjust the cursors so that they are readable. *)

PROCEDURE FixForeground( Mode : avidmode );
CONST
    Intense = 3;
    Black   = {};
    BrightWhite = {0..3}; 
VAR
    Attribute : BITSET;
    Foreground, Background : BITSET; 
    ForegroundColor, BackgroundColor : BITSET; 
BEGIN
    Attribute :=   vidctrl[ Mode ];
        (* Get the colors, and separate the hues from the intensities. *)
    Foreground :=  Attribute * {0..3};
    Background :=  BITSET(CARDINAL((Attribute * {4..7})) DIV 10H);  (* Shift right 4 bits. *)
    ForegroundColor := Foreground * {0..2};
    BackgroundColor := Background * {0..2};

    IF (ForegroundColor = BackgroundColor) THEN      (* difficult to read. *)
        IF (Intense IN Background) AND (BackgroundColor <> Black) THEN
            Foreground := Black;
        ELSE
            Foreground := BrightWhite;
        END;
    END;
    
    Attribute := BITSET(CARDINAL(Background) * 10H) + Foreground;
    vidctrl[ Mode ] := Attribute;
END FixForeground;



PROCEDURE MakeCursorsReadable();
VAR
    Mode : avidmode;
BEGIN
    FixForeground( videorestingcursor   );
    FixForeground( videosecondarycursor );

    FOR Mode := VAL(avidmode,0) TO MAX(avidmode) DO
            (* Reset cursor foregrounds to avoid the background color. *)
        IF (ODD(ORD(Mode))) THEN
            FixForeground(Mode);
        END;
    END;
END MakeCursorsReadable;





PROCEDURE AttrX(     Foreground : CARDINAL;
                     Background : CARDINAL  ) : ascreenx;
BEGIN
    RETURN ULX + (Foreground MOD 16);
END AttrX;




PROCEDURE AttrY(     Foreground : CARDINAL;
                     Background : CARDINAL  ) : ascreeny;
BEGIN
    RETURN ULY + (Background MOD 16);
END AttrY;


PROCEDURE FGtoAttr( Foreground, Background : CARDINAL ): BITSET;
BEGIN
    RETURN BITSET(Foreground + (16 * Background));
END FGtoAttr;






PROCEDURE DisplayPalette;
VAR
    Foreground, Background : CARDINAL;
    S                      : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(S,"a",1);
    FOR Foreground := 0 TO 15 DO
        FOR Background := 0 TO 15 DO
            PutStringWithAttribute(S,
                                   AttrX(Foreground,Background),
                                   AttrY(Foreground,Background),
                                   FGtoAttr(Foreground,Background) );
        END;
    END;
END DisplayPalette;


PROCEDURE HexChar( N : CARDINAL ) : CHAR;
BEGIN
    IF (N <= 9) THEN
        RETURN CHR( ORD("0") + N );
    ELSIF (N <= 15) THEN
        RETURN CHR( ORD("A") + N - 10 );
    ELSE
        FatalError;
    END;
END HexChar;



PROCEDURE FormatHex( N : CARDINAL; VAR S: ARRAY OF CHAR);
BEGIN
  S[0] := 2C;
  S[2] := HexChar(N MOD 16);
  S[1] := HexChar(N DIV 16);
END FormatHex;




PROCEDURE ShowAllModes(Mode : avidmode);
VAR
    S : ARRAY [0..2] OF CHAR;
    M : avidmode;
    i : CARDINAL;
    Attribute : BITSET;
    S80 : ARRAY [0..80] OF CHAR;
BEGIN
    (*<DEBUGGING*)

    IF (StartReport()) THEN ; END;
    Fill(S80," ",0);
    FOR i := 0 TO (ORD(MAX(avidmode)) DIV 2) DO
        M := VAL(avidmode,i*2);
        FormatHex(CARDINAL(vidctrl[M]),S);
        IF (M=Mode) THEN
            Attribute := BlackOnWhite;
        ELSE
            Attribute := WhiteOnBlack;
        END;
        PutStringWithAttribute(S,(i*2)+2,LRY+1,Attribute);
        ConcatLS(S80,S);
    END;
    PrintLine(S80,0);

    Fill(S80," ",0);
    FOR i := 0 TO (ORD(MAX(avidmode)) DIV 2) DO
        M := VAL(avidmode,(i*2)+1);
        FormatHex(CARDINAL(vidctrl[M]),S);
        IF (M=Mode) THEN
            Attribute := BlackOnWhite;
        ELSE
            Attribute := WhiteOnBlack;
        END;
        PutStringWithAttribute(S,(i*2)+2,LRY+2,Attribute);
        ConcatLS(S80,S);
    END;
    PrintLine(S80,0);

    EndReport();

    (*DEBUGGING>*)

END ShowAllModes;




PROCEDURE ShowSample(    Mode      : avidmode;
                         Attribute : BITSET;
                     VAR Name      : ARRAY OF CHAR );
CONST
    Width = 40;
    LULX   = 35;
    LULY   = ULY;
    LLRX   = LULX + Width - 1;
    LLRY   = LULY+4;
VAR
    S : ARRAY [0..Width] OF CHAR;
    X  : ascreenx;
    Y  : ascreeny;
    i  : CARDINAL;
    BackgroundAttribute,
    ForegroundAttribute : BITSET;
    BackgroundName, ForegroundName : ARRAY [0..Width] OF CHAR;
BEGIN


    BackgroundAttribute := Attribute;
    ForegroundAttribute := Attribute;
    Copy(Name,BackgroundName);
    Copy(Name,ForegroundName);

    IF (ODD(ORD(Mode))) THEN
            (* If it is a cursor mode, show it surrounded by
               its normal mode text. *)
        SetLengthOf(BackgroundName,0);
        BackgroundAttribute := vidctrl[VAL(avidmode,ORD(Mode)-1)];
        PutStringWithAttribute(ForegroundName,LULX,ULY-2,WhiteOnBlack);
    ELSE
        CASE Mode OF
            videoprotectedfield,
            videoformdata :  BackgroundAttribute := vidctrl[videoformback];
                             GetMessage(ModuleNumber+1,BackgroundName);  (* "Form Background" *)
          | videoformback :  ForegroundAttribute := vidctrl[videoformdata];
                             GetMessage(ModuleNumber+2,ForegroundName);  (* "Form Data" *)
            ELSE
                             BackgroundAttribute := vidctrl[videonormal];
                             GetMessage(ModuleNumber+3,BackgroundName);  (* "Text" *)
        END;
        PutStringWithAttribute(Name,LULX,ULY-2,WhiteOnBlack);
    END;

    Fill(S,"a",HIGH(S));
    FOR Y := LULY+1 TO LLRY DO
        PutStringWithAttribute(S, LULX, Y, BackgroundAttribute );
    END;

    ConcatS(BackgroundName,"  ");                  (* CONSTANT *)
    Overlay(S,BackgroundName,1,HIGH(S));
    PutStringWithAttribute(S, LULX, LULY, BackgroundAttribute);

    Copy(ForegroundName,S);
    PutStringWithAttribute(S,LULX+((Width-ORD(S[0])) DIV 2), LULY+2, ForegroundAttribute);

END ShowSample;


PROCEDURE DisplayCursor(    Foreground  : CARDINAL;
                            Background  : CARDINAL;
                            Mode        : avidmode;
                        VAR Name        : ARRAY OF CHAR;
                            Fore, Back  : BOOLEAN;
                            AndrewFlag  : BOOLEAN );
CONST
    LeftArrow    = 21C;
    RightArrow   = 20C;
    UpArrow      = 36C;
    DownArrow    = 37C;
VAR
    S : ARRAY [0..2] OF CHAR;
    S1 : ARRAY [0..2] OF CHAR;
    X  : ascreenx;
    Y  : ascreeny;
    i  : CARDINAL;
BEGIN
    ShowSample(Mode,FGtoAttr(Foreground,Background),Name);

    X  := AttrX(Foreground,Background);
    Y  := AttrY(Foreground,Background);

    IF (Fore AND Back) THEN
        Fill(S,LeftArrow,1);
        PutStringWithAttribute(S,X+1,Y,WhiteOnBlack);
        Fill(S,RightArrow,1);
        PutStringWithAttribute(S,X-1,Y,WhiteOnBlack);
        Fill(S,DownArrow,1);
        PutStringWithAttribute(S,X,Y-1,WhiteOnBlack);
        Fill(S,UpArrow,1);
        PutStringWithAttribute(S,X,Y+1,WhiteOnBlack);
    ELSIF (Back) THEN
        X  := AttrX(15,Background);
        Fill(S,LeftArrow,1);
        PutStringWithAttribute(S,X+1,Y,WhiteOnBlack);
        X  := AttrX(0,Background);
        Fill(S,RightArrow,1);
        PutStringWithAttribute(S,X-1,Y,WhiteOnBlack);
    ELSIF (Fore) THEN
        Y  := AttrY(Foreground,0);
        Fill(S,DownArrow,1);
        PutStringWithAttribute(S,X,Y-1,WhiteOnBlack);
        Y  := AttrY(Foreground,15);
        Fill(S,UpArrow,1);
        PutStringWithAttribute(S,X,Y+1,WhiteOnBlack);
    END;

    FormatHex(CARDINAL(FGtoAttr(Foreground,Background)),S);
    PutStringWithAttribute(S, ULX, ULY-2, WhiteOnBlack );

        (* We have this special flag to enable extra debugging information. *)

    IF (AndrewFlag) THEN
        ShowAllModes(Mode);
    END;

END DisplayCursor;





(* 15-Dec-89 RSC Mouse support additions.
*)
PROCEDURE SelectAnAttribute(VAR Attribute : BITSET;
                                Mode      : avidmode;
                            VAR Name      : ARRAY OF CHAR;
                                Fore      : BOOLEAN;
                                Back      : BOOLEAN
                            ) : BOOLEAN;
VAR
    Event           : AnEvent;
    Foreground,
    Background      : CARDINAL;
    Rug             : ARug;
    ButtonCollection : AButtonCollection;
    ButtonNumber     : CARDINAL;
    OldAttribute    : BITSET;
    AndrewFlag      : BOOLEAN;       (* Extra diagnostics *)
    S               : ARRAY [0..80] OF CHAR;


    PROCEDURE ProcessMouseEvent() : BOOLEAN;
    VAR
        F, B   : CARDINAL;
    BEGIN
        (* Find the foreground (the "X" dimension).
           Find the background (the "Y" dimension).
           Exact match?  Reset forground and background.
           otherwise, FALSE.

           Note that this algorithem understands that Foreground==X and
           Background==Y.  This may speed things up.
        *)
        B := 0;
        FOR F := 0 TO 15 DO
            IF (Event.EventX = AttrX(F,B)) THEN
                FOR B := 0 TO 15 DO
                    IF (Event.EventY = AttrY(F,B)) THEN
                        Foreground := F;
                        Background := B;
                        RETURN TRUE;
                    END;
                END;
                RETURN FALSE;
            END;
        END;
        RETURN FALSE;
        
    END ProcessMouseEvent;


BEGIN
    AndrewFlag := FALSE;

    GetMessage(ModuleNumber+4,S);  (* "Use arrow keys to select a video mode.  [ENTER] to confirm." *)
    Message(S);

    Foreground := CARDINAL(Attribute) MOD 16;
    Background := (CARDINAL(Attribute) DIV 16) MOD 16;

    DisplayPalette;
    GetMessage(ModuleNumber+10,S);
    IF CreateButtonCollection(ULX,LRY+2,maxcol,LRY+2,ABoxType{NoBox},Horizontal,S,
                              ButtonCollection) THEN
    END;

    LOOP
            (* Use Rug to quickly erase all cursor residue. *)
        IF (NOT (GetRug( ULX-1, ULY-1, LRX+1, LRY+1, Rug))) THEN EXIT; END;

        DisplayCursor(Foreground,Background,Mode,Name,Fore,Back,AndrewFlag);
        AndrewFlag := FALSE;

        GetNextEvent( Event );

        IF (Event.EventType = MouseEvent) THEN
            IF CorrelateMouseToButton(ButtonCollection,Event.EventX,
                                      Event.EventY,ButtonNumber) THEN
                IF (Event.EventCode <> MouseUp) THEN
                    Event.EventCode := 0;
                ELSIF (ButtonNumber = 1) THEN
                    Event.EventCode := ExitKey;
                ELSE
                    Event.EventCode := CancelKey;
                END;
            END;
        END;

        PutRug(ULX-1, ULY-1, LRX+1, LRY+1, Rug );

        CASE Event.EventCode OF
            0        :
          | Fwrd     :  IF (Fore) THEN
                            Foreground := (Foreground + 1) MOD 16;
                        ELSE
                            Burp;
                        END;
          | Reverse  :  IF (Fore) THEN
                            Foreground := (Foreground + 15) MOD 16;
                        ELSE
                            Burp;
                        END;
          | Up       :  IF (Back) THEN
                            Background := (Background + 15) MOD 16;
                        ELSE
                            Burp;
                        END;
          | Down     :  IF (Back) THEN
                            Background := (Background + 1) MOD 16;
                        ELSE
                            Burp;
                        END;
          | UndoKey  :  Foreground := CARDINAL(Attribute) MOD 16;
                        Background := (CARDINAL(Attribute) DIV 16) MOD 16;
          | MouseDown,
            MouseStillDown:
                        IF (NOT ProcessMouseEvent()) THEN
                            IF (Event.EventCode = MouseDown) THEN
                               Burp;
                            END;
                        END;

          | DoIt,
            ExitKey  :  Attribute := FGtoAttr(Foreground,Background);
                            (* Only return TRUE if a different one is chosen.
                               This cuts down on side-effects. *)
                        RETURN Attribute <> OldAttribute;
          | CancelKey:  RETURN FALSE;
          | ComputeKey: AndrewFlag := TRUE;
          | MouseUp,
            MouseDouble :
        ELSE
            Burp;
        END;
    END;

    DisposeButtonCollection(ButtonCollection);
END SelectAnAttribute;






PROCEDURE SelectSecondMode( VAR Prefix : ARRAY OF CHAR;
                            VAR Choices: ARRAY OF CHAR;
                                StartMode : avidmode;
                            VAR Mode   : avidmode;
                            VAR Choice2 : CARDINAL;
                            VAR Name    : ARRAY OF CHAR;
                            VAR LastChoice2 : CARDINAL
                           ) : BOOLEAN;
VAR
    CodeSet : ASetOfCodes;
    Code : ACode;
BEGIN
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,ExitKey,ExitKey,TRUE);

    Choice2 := LastChoice2;
    Code := Menu(Prefix,Choices,0,MenuStart+1,maxcol,MenuEnd,CodeSet,
                 FALSE,  (* 12-Dec-89 RSC NOT MODAL *)
                 Choice2);
    IF (Code <> DoIt) THEN RETURN FALSE; END;
    LastChoice2 := Choice2;
    Mode := VAL(avidmode,ORD(StartMode) + ((Choice2 - 1) * 2));
    WordNumber (Choices, Choice2, Name);
    RETURN TRUE;
END SelectSecondMode;





PROCEDURE SelectAMode(     AllowCursorSelect : BOOLEAN );
VAR
    Name,Name2,LastName : ARRAY [0..41] OF CHAR;
    Choices : ARRAY [0..255] OF CHAR;
    Prefix  : ARRAY [0..81] OF CHAR;
    Choice, Choice2  : CARDINAL;
    OK      : BOOLEAN;
    CodeSet : ASetOfCodes;
    Code : ACode;
    Attribute, OldAttribute : BITSET;
    Mode : avidmode;

    LastLevel : CARDINAL;
    LastChoice, LastChoice2 : CARDINAL;
    Fore, Back : BOOLEAN;

BEGIN

    LastChoice := 1;
    LastChoice2 := 1;
    LastLevel := 1;
    SetLengthOf(LastName,0);

    LOOP

        LOOP
          SetCodeBits(CodeSet,0,MaxCode,FALSE);
          SetCodeBits(CodeSet,ExitKey,ExitKey,TRUE);

          Fore := TRUE;    (* We are probably selecting both foreground and *)
          Back := TRUE;    (* background. *)


          EraseScreen;

          GetMessage(ModuleNumber+5,Choices);  (* "Select a video type, or press [F10] when done, or [F1] for help." *)
          Message(Choices);

          OK := FALSE;

          Choice := LastChoice;

          IF (LastLevel <= 1) THEN
              IF (AllowCursorSelect) THEN
                  GetMessage(ModuleNumber+6,Prefix);  (* "VIDEO FOR" *)
                  GetMessage(ModuleNumber+7,Choices);  (* "Cursors," *)
              ELSE
                  GetMessage(ModuleNumber+8,Prefix);  (* "CURSOR ON" *)
                  SetLengthOf(Choices,0);
              END;
              ConcatMessage(Choices,ModuleNumber+9);  (* "Text,Messages,Forms,Gantt,Menu,Filters,PERT,Mouse,Quit" *)

              Code := Menu(Prefix,Choices,0,MenuStart+1,maxcol,MenuEnd,CodeSet,
                           FALSE,  (* 12-Dec-89 RSC NOT MODAL *)
                           Choice);   (* 3/26/87 EGK *)
              WordNumber (Choices, Choice, Name);

              IF (Code <> DoIt) THEN RETURN; END;   (* Escape *)

              IF (Choice <> LastChoice) THEN
                  LastChoice2 := 1;
              END;

              LastChoice := Choice;
              Copy(Name,LastName);


          ELSE
              Copy(LastName,Name);
          END;

          LastLevel := 1;

              (* Ask the second level menu questions. *)

          Copy(Name,Prefix);
          Upshift(Prefix);

          GetMessage(ModuleNumber+10,Name2);  (* "" *)

          IF (NOT AllowCursorSelect) THEN    (* Dummy out Cursors choice. *)
              INC(Choice);
          END;

          CASE Choice OF

            1  :   (* Cursors *)
                  (* We treat this one strangely, since the first
                     and third of its choices
                     refers to ALL cursors. *)
              GetMessage(ModuleNumber+11,Choices);  (* "Normal background,Resting,Second" *)
              IF (AllowCursorSelect) THEN
                  ConcatMessage(Choices,ModuleNumber+12);  (* ",Overlay selected mode" *)
              END;
              Choice2 := LastChoice2;
              Code := Menu(Prefix,Choices,0,MenuStart+1,maxcol,MenuEnd,CodeSet,
                           FALSE,    (* 12-Dec-89 RSC NOT MODAL *)
                           Choice2);
              IF (Code = DoIt) THEN
                  WordNumber (Choices, Choice2, Name2);
                  LastChoice2 := Choice2;
                  IF (Choice2 = 1) THEN
                      Mode := cvideonormal;
                      Attribute := vidctrl[cvideonormal];
                      OldAttribute := Attribute;
                      IF (SelectAnAttribute(Attribute,Mode,Name,FALSE,TRUE))
                         AND (Attribute <> OldAttribute) THEN
                          FOR Mode := VAL(avidmode,0) TO MAX(avidmode) DO
                                  (* Reset backgrounds. *)
                              IF (ODD(ORD(Mode))) THEN
                                  vidctrl[Mode] := (vidctrl[  VAL( avidmode, ORD(Mode)-1)] * {0..3})
                                                   +
                                                   (Attribute * {4..7});
                              END;
                          END;
                              (* These special video modes are actually variants
                                 of cursors.   Their cursor modes are the same as
                                 their normal modes. *)
                          vidctrl[ cvrcursor ] := vidctrl[ videorestingcursor ];
                          vidctrl[ cvscursor ] := vidctrl[ videosecondarycursor ];

                          MakeCursorsReadable();
                      END;
                  ELSIF (Choice2 = 4) THEN
                      SelectAMode( FALSE );  (* Recursion *)
                  ELSE
                      Mode := VAL(avidmode,ORD(videorestingcursor) + ((Choice2 - 2) * 2));
                      IF (Choice2 = 3) THEN   (* Secondary cursor is background setting only. *)
                          Fore := FALSE;
                      END;
                      EXIT;
                  END;
              END;

          | 2  :  (* Text *)
              GetMessage(ModuleNumber+13,Choices);  (* "Normal,Bright,Enhanced,Reversed,Reversed Bright" *)
              IF SelectSecondMode(Prefix,Choices,videonormal,Mode,Choice2,Name2,LastChoice2) THEN
                  EXIT;
              END;

          | 3  :   (* Messages *)
              GetMessage(ModuleNumber+14,Choices);  (* "Normal,Warning,Caption,Indicator Light,Shadow" *)
              IF SelectSecondMode(Prefix,Choices,videomessage,Mode,Choice2,Name2,LastChoice2) THEN
                  IF (Choice2 = 4) THEN
                      Mode := videolights;
                  ELSIF (Choice2 = 5) THEN
                      Mode := videoshadow;
                  END;
                  EXIT;
              END;

          | 4  :  (* Forms *)
              GetMessage(ModuleNumber+15,Choices);  (* "Background,Data,Hidden Field,Protected" *)
              IF SelectSecondMode(Prefix,Choices,videoformback,Mode,Choice2,Name2,LastChoice2) THEN
                  IF (Choice2 = 4) THEN
                      Mode := videoprotectedfield;
                  END;
                  EXIT;
              END;

          | 5  :  (* Gantt *)
              GetMessage(ModuleNumber+16,Choices);  (* "Date Bar,Hist Normal,Max Line,Overbooked,Vacations" *)
              IF SelectSecondMode(Prefix,Choices,videodatebar,Mode,Choice2,Name2,LastChoice2) THEN
                  IF (Choice2 = 5) THEN
                      Mode := videographvac;
                  END;
                  EXIT;
              END;

          | 6  :  (* Menus *)
              GetMessage(ModuleNumber+17,Choices);  (* "Choices,First letters,Prefix,Background,Help Prompt" *)
              IF SelectSecondMode(Prefix,Choices,videomenu,Mode,Choice2,Name2,LastChoice2) THEN
                  EXIT;
              END;

          | 7  :  (* Filters *)
              ConcatMessage(Prefix,ModuleNumber+18);  (* " HIGHLIGHT" *)
              GetMessage(ModuleNumber+19,Choices);  (* "Predecessor,Successor,1,2,3" *)
              IF SelectSecondMode(Prefix,Choices,videofilter1,Mode,Choice2,Name2,LastChoice2) THEN
                  EXIT;
              END;

          | 8  :  (* Network *)
              GetMessage(ModuleNumber+20,Choices);  (* "Background,Bright,Started Task,Done Task" *)
              IF SelectSecondMode(Prefix,Choices,videonetwork,Mode,Choice2,Name2,LastChoice2) THEN
                  EXIT;
              END;

          | 9  :  (* Network *)
              GetMessage(ModuleNumber+21,Choices);  (* "Push Buttons,Borders" *)
              IF SelectSecondMode(Prefix,Choices,videobutton,Mode,Choice2,Name2,LastChoice2) THEN
                  EXIT;
              END;

          | 10  :  (* Quit *)
                  RETURN;

            ELSE FatalError();

          END;   (* End CASE *)

        END;  (* End Loop *)


        IF (NOT AllowCursorSelect) THEN
            GetMessage(ModuleNumber+23,Prefix);  (* "Cursor on " *)
            Insert(Name,Prefix,1);
            INC(Mode);                  (* Convert to the cursor mode. *)
        END;


        ConcatS(Name," ");              (* CONSTANT *)
        ConcatLS(Name,Name2);

        Fill(Choices," ",0);
        Message(Choices);

        LastLevel := 2;

        Attribute := vidctrl[Mode];
        IF (SelectAnAttribute(Attribute,Mode,Name,Fore,Back)) THEN
            vidctrl[Mode] := Attribute;
        END;

        IF (Mode = videoshadow) THEN
            GetMessage(ModuleNumber+24,Prefix);  (* "SHADOWS" *)
            GetMessage(ModuleNumber+25,Choices);  (* "Solid,Transparent" *)
            Choice := ORD(TransparentShadow)+1;
            IF QuickMenu(Prefix,Choices,Choice,FALSE) THEN
                TransparentShadow := VAL(BOOLEAN,Choice-1);
            END;
        END;

        EraseScreen;

    END;

END SelectAMode;







PROCEDURE MakeCustomVideoSetup( AllowCursors : BOOLEAN);
VAR
    Attribute : BITSET;
    Mode      : avidmode;
    Name : ARRAY [0..80] OF CHAR;
    Cursors : BOOLEAN;
BEGIN
    SelectAMode(AllowCursors);
END MakeCustomVideoSetup;





END CustomizedVideo;


    (* --------- END MODULE CustomizedVideo  ---------------------*)

    (*+2>*)








PROCEDURE TranslateNextTwoCharacters( VAR S     : ARRAY OF CHAR;
                                      VAR V     : CARDINAL;
                                          i     : CARDINAL );
VAR
    j   : CARDINAL;
    C   : CHAR;
BEGIN
    V := 0;
    j := 0;
    WHILE (j <= 1) AND (i <= ORD(S[0])) DO
        V := V * 16;
        C := S[i];
        IF (C >= "0") AND (C <= "9") THEN
            INC(V,ORD(C)-ORD("0"));
        ELSIF (C >= "A") AND (C <= "F") THEN
            INC(V,ORD(C)-ORD("A")+10);
        ELSE
            FatalError;
        END;
        INC(i);
        INC(j);
    END;
END TranslateNextTwoCharacters;



    (* TranslateVideoDefinition -- Read the defining string and translate each
                                   two characters as a hexadecimal code
                                   for a video attribute. *)


PROCEDURE TranslateVideoDefinition(     StringNumber : CARDINAL;
                                        T       : AVideoTablePointer );
VAR
    S      : ARRAY [0..255] OF CHAR;
    Fore, Back : ARRAY [0..129] OF CHAR;
    Mode   : avidmode;
    i,V    : CARDINAL;
    C      : CHAR;
BEGIN
        (* Read the string from the phrases file and split it into two
           parts. *)

    GetMessage(VideoStringBase + StringNumber, S);
    WordNumber(S,1,Fore);
    WordNumber(S,2,Back);

    Mode := VAL(avidmode,0);
    i    := 1;
    WHILE (i < ORD(Fore[0])) DO
        TranslateNextTwoCharacters(Fore,V,i);
        T^[Mode] := BITSET(V);
        IF (Mode >= HIGH(T^)) THEN
            RETURN;
        END;
        INC(Mode);

        TranslateNextTwoCharacters(Back,V,i);
        T^[Mode] := BITSET(V);
        IF (Mode >= HIGH(T^)) THEN
            RETURN;
        END;
        INC(Mode);

        INC(i,2);
    END;

END TranslateVideoDefinition;



PROCEDURE WriteMsg( Number : CARDINAL; VAR l : ascreeny );
VAR
    s           : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(Number,s);
    PourText(s,videonormal,0,l,maxcol,maxrow,l);
    INC(l);
END WriteMsg;







PROCEDURE QuickMenu(VAR Prefix,
                        Choices:ARRAY OF CHAR;
                    VAR Choice:CARDINAL;
                        AllowHelp : BOOLEAN
                        ):BOOLEAN;
VAR
    CodeSet : ASetOfCodes;
    Code : ACode;
    NewChoice : CARDINAL;
BEGIN
    NewChoice := Choice;
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    IF (NOT AllowHelp) THEN
        SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
    END;

    LOOP
        Code := Menu(Prefix,Choices,0,MenuStart+1,maxcol,MenuEnd,CodeSet,
                     FALSE,         (* 12-Dec-89 RSC NOT MODAL *)
                     NewChoice);   (* 3/26/87 EGK *)
        IF (Code = DoIt) THEN
            Choice := NewChoice;
            RETURN TRUE;
        ELSIF (Code = CancelKey) THEN
            RETURN FALSE;
        ELSE
            Burp;
        END;
    END;
END QuickMenu;



PROCEDURE DumbMenu(VAR Prefix,Choices:ARRAY OF CHAR; VAR Choice:CARDINAL);
BEGIN
    REPEAT
    UNTIL (QuickMenu(Prefix,Choices,Choice,FALSE));
END DumbMenu;




PROCEDURE GetPalette ( VAR Choices : ARRAY OF CHAR;
                       VAR Palette : CARDINAL;
                       VAR Valid   : BOOLEAN  );
VAR
    l      : ascreeny;
    Prefix : ARRAY [0..20] OF CHAR;
BEGIN
    EraseScreen;
    l := MenuStart + 4;
    WriteMsg(ModuleNumber+26,l);  (* "   Several color schemes are available.  Please select one." *)
                                  (* "You are also free to try each in turn, and then select the one" *)
    WriteMsg(ModuleNumber+27,l);  (* "you prefer.  Color choices may be further refined by choosing" *)
                                  (* "CUSTOMIZE from the initial video setup menu." *)
    GetMessage(ModuleNumber+28,Prefix);  (* "PALETTE" *)
    Palette := Answers[QPalette];
    Valid := QuickMenu(Prefix,Choices,Palette,FALSE);
    Answers[QPalette] := Palette;
END GetPalette;




PROCEDURE GetStandardPalette (     BoardType : ABoardType;
                                   TubeType  : ATubeType;
                               VAR Palette : CARDINAL;
                               VAR Valid   : BOOLEAN  );
VAR
    s : ARRAY [0..255] OF CHAR;
BEGIN
    IF (TubeType = ColorTube) THEN
        GetMessage(ModuleNumber+29,s);  (* "1 (Dark Blue),2 (Light Blue),3 (Yellow),4 (Grey),5 (Black/Blue),6 (Black/Green),7 (Medium Blue)" *)
        GetPalette(s,Palette,Valid);
    ELSE
        Palette := 1;
        Valid := TRUE;
    END;
END GetStandardPalette;




PROCEDURE GetTubeType(VAR TubeType:ATubeType; VAR Valid : BOOLEAN );
VAR
    Prefix : ARRAY [0..80] OF CHAR;
    s : ARRAY [0..255] OF CHAR;
    Choice : CARDINAL;
    l      : ascreeny;
BEGIN
    EraseScreen;
    l := MenuStart + 4;
    WriteMsg(ModuleNumber+30,l);  (* "   Now, what kind of video monitor do you have?  If it can show" *)
    WriteMsg(ModuleNumber+31,l);  (* 'colors, pick "COLOR".  Otherwise, pick "MONOCHROME."' *)

    GetMessage(ModuleNumber+32,Prefix);  (* "WHAT KIND OF MONITOR DO YOU HAVE" *)
    GetMessage(ModuleNumber+33,s);  (* "Monochrome,Color,Plasma or LCD,Other" *)
    Choice := Answers[QTube];
    Valid := QuickMenu(Prefix,s,Choice,FALSE);
    Answers[QTube] := Choice;
    IF (Choice <= 2) THEN
       TubeType := VAL(ATubeType,Choice-1);
    ELSIF (Valid) THEN
        GetMessage(ModuleNumber+34,Prefix);  (* "MONITOR IS" *)
        GetMessage(ModuleNumber+35,s);  (* "Mono,Color,3270 Mono,3270 Color,3270 Plasma,LCD,Compaq Plasma,VGA Plasma" *)
        Choice := ORD(TubeType)+1;
        Valid := QuickMenu(Prefix,s,Choice,FALSE);
        TubeType := VAL(ATubeType,Choice-1);
    END;
END GetTubeType;




PROCEDURE GetColorBoardType( VAR BoardType    : ABoardType;
                             VAR Palette      : CARDINAL;
                             VAR Valid        : BOOLEAN );
VAR
    Prefix : ARRAY [0..255] OF CHAR;
    s : ARRAY [0..255] OF CHAR;
    Choice : CARDINAL;
    l : ascreeny;
BEGIN
    EraseScreen;
    l := MenuStart + 4;

    WriteMsg(ModuleNumber+36,l);  (* "   IBM Color boards are capable of displaying a wider range of" *)
    WriteMsg(ModuleNumber+37,l);  (* "background colors than are available to many similar boards." *)
    WriteMsg(ModuleNumber+38,l);  (* "If you have an IBM or compatible board, and are not running" *)
    WriteMsg(ModuleNumber+39,l);  (* "memory-resident programs, we recommend this choice." *)
    WriteMsg(ModuleNumber+40,l);  (* "   Several other computers come standard with compatible adapters." *)
    WriteMsg(ModuleNumber+41,l);  (* '   If you do not have a compatible card, pick "Generic."  Likewise,' *)
    WriteMsg(ModuleNumber+42,l);  (* 'choose "Generic" if a memory-resident program causes incompatibility' *)
    WriteMsg(ModuleNumber+43,l);  (* "problems such as screen blinking or loss of reverse highlights." *)
    WriteMsg(ModuleNumber+44,l);  (* "   If you choose IBM and your display shows flashing colors, redo your" *)
    WriteMsg(ModuleNumber+45,l);  (* 'video setup using "Generic".' *)

    GetMessage(ModuleNumber+46,Prefix);  (* "VIDEO CONTROLLER BOARD IS" *)
    GetMessage(ModuleNumber+47,s);  (* "CGA,EGA,VGA,MCGA,Generic" *)
    Choice := Answers[QBoard]; 
    Valid := QuickMenu(Prefix,s,Choice,FALSE);
    Answers[QBoard] := Choice; 
    IF (Valid) THEN
        CASE Choice OF
            1 : BoardType := CGABoard;
          | 2 : BoardType := EGABoard;
          | 3 : BoardType := VGABoard;
          | 4 : BoardType := MCGABoard;
            ELSE
                BoardType := GenericColorBoard;
        END;
        GetStandardPalette(BoardType,ColorTube,Palette,Valid);
    END;
END GetColorBoardType;






PROCEDURE GetMonochromeBoardType( VAR BoardType    : ABoardType;
                                  VAR Palette      : CARDINAL;
                                  VAR Valid        : BOOLEAN );
VAR
    Prefix : ARRAY [0..255] OF CHAR;
    s : ARRAY [0..255] OF CHAR;
    Choice : CARDINAL;
    l : ascreeny;
BEGIN
    EraseScreen;
    l := MenuStart + 4;

    WriteMsg(ModuleNumber+48,l);  (* "   Monochrome monitors can be attached to either MONOCHROME or" *)
    WriteMsg(ModuleNumber+49,l);  (* "COLOR GRAPHICS video controller boards inside the computer.  If" *)
    WriteMsg(ModuleNumber+50,l);  (* "your monitor is capable of showing graphics on the screen, or if" *)
    WriteMsg(ModuleNumber+51,l);  (* "the dots that make up the letters are pretty obvious, you have a" *)
    WriteMsg(ModuleNumber+52,l);  (* "COLOR GRAPHICS board.  If you have an IBM, green-on-black monitor" *)
    WriteMsg(ModuleNumber+53,l);  (* "on which the little dots are barely visible, that is MONOCHROME." *)
    WriteMsg(ModuleNumber+54,l);  (* "If you are not sure, experiment and see which one works better." *)

    GetMessage(ModuleNumber+55,Prefix);  (* "WHAT KIND OF VIDEO CONTROLLER DO YOU HAVE" *)
    GetMessage(ModuleNumber+56,s);  (* "Monochrome,Hercules Mono-Graphics,CGA,EGA,VGA,MCGA" *)
    Choice := Answers[QBoard];
    Valid := QuickMenu(Prefix,s,Choice,FALSE);
    Answers[QBoard] := Choice;
    CASE Choice OF
          1,
          2  : BoardType := MonoBoard;
        | 3  : BoardType := CGABoard;
        | 4  : BoardType := EGABoard;
        | 5  : BoardType := VGABoard;
        | 6  : BoardType := MCGABoard;
        ELSE   BoardType := MonoBoard;
    END;
END GetMonochromeBoardType;


PROCEDURE SelectVideoOption;        (* 3/26/87 EGK *)
VAR
    Prefix, s : ARRAY [0..255] OF CHAR;
    Choice : CARDINAL;
    l      : ascreeny;
    SaveCursorType      : CARDINAL;
    Changed             : BOOLEAN;
    OldFlag             : BOOLEAN;
BEGIN
    Changed := FALSE;

    EraseScreen;
    l := MenuStart + 4;
    WriteMsg(ModuleNumber+57,l);  (* "   Time Line can use the video display on your computer in one of" *)
    WriteMsg(ModuleNumber+58,l);  (* "two ways: FAST or CLEAN." *)
    WriteMsg(ModuleNumber+59,l);  (* "   FAST is rapid, and provides the best performance.  We recommend it." *)
    WriteMsg(ModuleNumber+60,l);  (* "   Some DOS enhancements, memory-resident utility programs, multi-" *)
    WriteMsg(ModuleNumber+61,l);  (* "tasking and windowing programs don't work as well when Time Line is" *)
    WriteMsg(ModuleNumber+62,l);  (* 'running FAST video.  For this reason, Time Line can also run "CLEAN."' *)

    GetMessage(ModuleNumber+63,Prefix);  (* "Which would you prefer" *)
    GetMessage(ModuleNumber+64,s);  (* "Fast,Clean" *)
    OldFlag := CleanFlag;
    IF (CleanFlag) THEN
        Choice := 2;
    ELSE
        Choice := 1;
    END;
    DumbMenu(Prefix,s,Choice);
    CleanFlag := (Choice = 2);
    Changed := Changed OR (CleanFlag <> OldFlag);
        

    OldFlag := BlinkFlag;
    IF (NOT CleanFlag) THEN
        EraseScreen;
        l := MenuStart + 4;
        WriteMsg(ModuleNumber+65,l);  (* "   Time Line can reprogram the Motorola 6845 video controller chip" *)
        WriteMsg(ModuleNumber+66,l);  (* "on your PC in order to get brighter background colors." *)
        WriteMsg(ModuleNumber+67,l);  (* "   Reprogramming the chip also disables any blinking on the screen." *)
        WriteMsg(ModuleNumber+68,l);  (* "   Some DOS enhancements, memory-resident utility programs, multi-" *)
        WriteMsg(ModuleNumber+69,l);  (* "tasking and windowing programs don't work as well when the chip has" *)
        WriteMsg(ModuleNumber+70,l);  (* 'been reprogrammed.  Some video cards (such as the EGA) do not support' *)
        WriteMsg(ModuleNumber+71,l);  (* 'reprogramming, nor do some soi disant "compatibles."' *)

        GetMessage(ModuleNumber+72,Prefix);  (* "Reprogram the 6845 video controller chip?" *)
        GetMessage(ModuleNumber+73,s);  (* "Yes,No" *)
        IF (BlinkFlag) THEN                                       (* 13-Sep-89 LAA *)
            Choice := 2;
        ELSE
            Choice := 1;
        END;
        DumbMenu(Prefix,s,Choice);
        BlinkFlag := (Choice = 2);
    ELSE
        BlinkFlag := TRUE;
    END;
    Changed := Changed OR (BlinkFlag <> OldFlag);

    GetCursorType(SaveCursorType);
    IF (Changed) THEN
        InitializeVideoHardware(BlinkFlag,CleanFlag);
    END;
    SetCursorType(SaveCursorType);

        (* Ask about auto-detecting the adapter board type. *)

    EraseScreen;
    l := MenuStart + 4;
    WriteMsg(ModuleNumber+105,l);  
    WriteMsg(ModuleNumber+106,l);  
    GetMessage(ModuleNumber+104,Prefix);  (* "Auto Detect Graphics Monitor?" *)
    GetMessage(ModuleNumber+73,s);        (* "Yes,No" *)
    IF (VideoConfiguration.AutoDetect) THEN Choice := 1; ELSE Choice := 2; END;
    DumbMenu(Prefix,s,Choice);
    VideoConfiguration.AutoDetect := (Choice = 1);


END SelectVideoOption;

    (* SetupIBM -- Setup for a generic IBM clone.  *)


PROCEDURE SetupIBM(VAR BoardType    : ABoardType;
                   VAR TubeType     : ATubeType;
                   VAR Palette      : CARDINAL ):BOOLEAN;
VAR
    Valid : BOOLEAN;
BEGIN
    GetTubeType(TubeType,Valid);
    IF (Valid) THEN
        IF (TubeType = MonoTube) THEN
            GetMonochromeBoardType(BoardType,Palette,Valid);
        ELSIF (TubeType = ColorTube) THEN
            GetColorBoardType(BoardType,Palette,Valid);
        END;
    END;
    RETURN Valid;
END SetupIBM;




PROCEDURE MaybeGetTypes(VAR ComputerType : AComputerType;
                        VAR BoardType    : ABoardType;
                        VAR TubeType     : ATubeType;
                        VAR Palette      : CARDINAL ) : BOOLEAN;
VAR
    Prefix : ARRAY [0..255] OF CHAR;
    s : ARRAY [0..255] OF CHAR;
    Choice : CARDINAL;
    l : ascreeny;
    Model : CARDINAL;
    Valid : BOOLEAN;
BEGIN


    Valid := FALSE;

    (* ----------------                       -----   Disabled 12/5/89 AJL
       This was intended once to make sure that we had an initialized
       structure, a function that is now in VidTypes.  This code had the bad
       side-effect of resetting video options whenever one tried to merely
       customize a color.
    Palette := 1;
    ComputerType := UnknownComputer;
    BoardType    := GenericColorBoard;
    TubeType     := MonoTube;
    -------------------- *)

    EraseScreen;
    l := MenuStart + 6;
    WriteMsg(ModuleNumber+74,l);  (* "   Pick the manufacturer of your computer here.  If your computer is" *)
    WriteMsg(ModuleNumber+75,l);  (* "not listed, experiment with either picking a similar model, or using" *)
    WriteMsg(ModuleNumber+76,l);  (* "OTHER, which tends to work adequately for most compatible machines." *)
        (*+2<*)
    WriteMsg(ModuleNumber+77,l);  (* "   CUSTOMIZE will allow you to alter the current video settings to" *)
    WriteMsg(ModuleNumber+78,l);  (* "your preferences.  Use CUSTOMIZE after you have chosen a computer type," *)
    WriteMsg(ModuleNumber+79,l);  (* "in order to further modify the colors used by Time Line." *)
        (*+2>*)

    GetMessage(ModuleNumber+80,Prefix);  (* "WHAT KIND OF COMPUTER DO YOU HAVE" *)
    GetMessage(ModuleNumber+81,s);  (* ',|IBM PC, AT or "compatible"|IBM PS/2|Compaq|AT&T 6300|IBM 3270 PC or AT|Zenith 200 Series|Other' *)
        (*+2<*)
    ConcatMessage(s,ModuleNumber+82);  (* "|Customize|Video Options" *)      (* 3/26/87 EGK *)
        (*+2>*)
    Choice := Answers[QComputer];
    IF (NOT QuickMenu(Prefix,s,Choice,FALSE)) THEN
        RETURN FALSE;
    END;
    Answers[QComputer] := Choice;

    ComputerType := VAL(AComputerType,Choice-1);

    IF (ComputerType = GetOptions) THEN     (* 3/26/87 EGK *)
        SelectVideoOption;
        Valid := FALSE;                     (* Signal no change to palettes. *)
    ELSIF (ComputerType = CustomizeIt) THEN
        (* We will make a customized setup *)
        Valid := TRUE;
    ELSIF (ComputerType = IBMPS2) THEN
        EraseScreen;
        GetMessage(ModuleNumber+84,Prefix);  (* "MODEL" *)
        GetMessage(ModuleNumber+111,s);  (* ",|25 or 30 (MCGA)|50, 60, 70, 80 etc. (VGA)" *)
        Model := Answers[QModel];
        Valid := QuickMenu(Prefix,s,Model,FALSE);
        Answers[QModel] := Model;
        IF (Model = 1) THEN
            BoardType := MCGABoard;
        ELSE
            BoardType := VGABoard;
        END;
        GetTubeType(TubeType,Valid);
        IF (TubeType = ColorTube) THEN
            GetStandardPalette(BoardType,TubeType,Palette,Valid);
        END;
    ELSIF (ComputerType = ATT6300) THEN
        GetTubeType(TubeType,Valid);
        IF (NOT Valid) THEN
        ELSIF (TubeType = MonoTube) THEN
            BoardType := ATTBoard;
            GetMessage(ModuleNumber+83,s);  (* "1 Black Background,2 Grey Background" *)
            GetPalette(s,Palette,Valid);
        ELSIF (TubeType = ColorTube) THEN
            BoardType := ATTBoard;
            GetStandardPalette(BoardType,TubeType,Palette,Valid);
        END;
    ELSIF (ComputerType = Compaq) THEN
        EraseScreen;
        GetMessage(ModuleNumber+84,Prefix);  (* "MODEL" *)
        GetMessage(ModuleNumber+85,s);  (* "Portable,Deskpro,Portable III" *)
        Model := Answers[QModel];
        Valid := QuickMenu(Prefix,s,Model,FALSE);
        Answers[QModel] := Model;
        IF (NOT Valid) THEN
        ELSE
            BoardType := GenericColorBoard;
            TubeType  := UnknownTube;
            IF (Model = 1) THEN
                EraseScreen;
                GetMessage(ModuleNumber+86,Prefix);  (* "MONITOR" *)
                GetMessage(ModuleNumber+87,s);  (* "Internal,External" *)
                Choice := 1;
                Valid := QuickMenu(Prefix,s,Choice,FALSE);
                IF (Valid) AND (Choice = 1) THEN
                    TubeType  := MonoTube;
                    BoardType := CompaqPortableBoard;
                END;
            ELSIF (Model = 2) THEN
                Valid := SetupIBM(BoardType,TubeType,Palette);
            ELSIF (Model = 3) THEN
                EraseScreen;
                GetMessage(ModuleNumber+88,Prefix);  (* "MONITOR" *)
                GetMessage(ModuleNumber+89,s);  (* "Internal,External" *)
                Choice := 1;
                Valid := QuickMenu(Prefix,s,Choice,FALSE);
                IF (Valid) AND (Choice = 1) THEN
                    TubeType  := CompaqPlasma;
                END;
            END;
            IF (Valid) AND (TubeType = UnknownTube) THEN
                GetTubeType(TubeType,Valid);
                IF (TubeType = LCD) THEN
                ELSIF (TubeType = MonoTube) THEN
                    BoardType := CompaqPortableBoard;
                ELSE
                    IF (Model = 2) THEN  (* Deskpro *)
                        BoardType := CGABoard;
                        GetStandardPalette(BoardType,TubeType,Palette,Valid);
                    ELSE
                        GetColorBoardType(BoardType,Palette,Valid);
                    END;
                END;
            END;
        END;
    ELSIF (ComputerType = IBM3270PC) THEN
        BoardType := GenericColorBoard;
        EraseScreen;
        GetMessage(ModuleNumber+90,Prefix);  (* "WHAT KIND OF MONITOR" *)
        GetMessage(ModuleNumber+91,s);  (* "Monochrome,Color,Plasma Display" *)
        Choice := Answers[QTube];
        Valid := QuickMenu(Prefix,s,Choice,FALSE);
        Answers[QTube] := Choice;
        IF (Valid) THEN
            CASE Choice OF
                1 :  TubeType := Mono3270;
              | 2 :  TubeType := Color3270;
                     GetMessage(ModuleNumber+92,s);  (* "1 (Red Cursor),2 (White Cursor)" *)
                     GetPalette(s,Palette,Valid);
              | 3 :  TubeType := Plasma3270;
            END;
        END;
    ELSE   (* IBM ? Other? *)
        Valid := SetupIBM(BoardType,TubeType,Palette);
    END;



    EraseScreen;

    RETURN Valid;

END MaybeGetTypes;



PROCEDURE GetTypes(VAR ComputerType : AComputerType;
                   VAR BoardType    : ABoardType;
                   VAR TubeType     : ATubeType;
                   VAR Palette      : CARDINAL ) : BOOLEAN;
VAR
    LocalComputerType : AComputerType;
    LocalBoardType    : ABoardType;
    LocalTubeType     : ATubeType;
    LocalPalette      : CARDINAL;
BEGIN
    LocalComputerType := ComputerType;
    LocalBoardType    := BoardType;
    LocalTubeType     := TubeType;
    LocalPalette      := Palette;

    IF (MaybeGetTypes(LocalComputerType,LocalBoardType,
                      LocalTubeType,LocalPalette)) THEN
        ComputerType := LocalComputerType;
        BoardType    := LocalBoardType;
        TubeType     := LocalTubeType;
        Palette      := LocalPalette;  
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
    
END GetTypes;



PROCEDURE SetDefaultVideo(    T:AVideoTablePointer);
BEGIN
    TranslateVideoDefinition(DefaultVideoString,T);
END SetDefaultVideo;




PROCEDURE BuildVideoTable(ComputerType:AComputerType;
                          BoardType : ABoardType;
                          TubeType : ATubeType;
                          Palette   : CARDINAL;
                          T:AVideoTablePointer );
VAR
    VideoNumber : CARDINAL;
BEGIN

    IF (ComputerType = CustomizeIt) THEN
            (*+2<*)
        MakeCustomVideoSetup(TRUE);
            (*+2>*)
    ELSE
        IF (TubeType = ColorTube) THEN
            IF (BoardType IN ReprogrammableColorBoards) THEN
                VideoNumber := IBMCGAString + Palette - 1;
            ELSE
                VideoNumber := ColorString + Palette - 1;
            END;
        ELSIF (TubeType IN ATubeTypeSet{LCD,Plasma3270}) THEN
            VideoNumber := LCDString;
        ELSIF (TubeType = CompaqPlasma) THEN
            VideoNumber := CompaqPIII;              
        ELSIF (TubeType = VGAPlasma) THEN
            VideoNumber := VGAPlasmaString;              
        ELSIF (TubeType = Mono3270) THEN
            VideoNumber := Mono3270String;
        ELSIF (TubeType = Color3270) THEN
            VideoNumber := P13270String + Palette - 1;
        ELSIF (TubeType = MonoTube)
              AND (BoardType IN ABoardTypeSet{CGABoard,MCGABoard,EGABoard,VGABoard,MCGABoard,ATTBoard,GenericColorBoard}) THEN
            VideoNumber := DefaultVideoString;
        ELSIF (BoardType = CompaqPortableBoard) THEN
            VideoNumber := CompaqPortableString;
        ELSIF (BoardType = MonoBoard) THEN
            VideoNumber := MonoBoardString;
        ELSIF (BoardType = ATTBoard) THEN
            CASE Palette OF
                1 :  VideoNumber := MonoBoardString;
               ELSE  
                     VideoNumber := ATTMonoString2;
            END;
        ELSE
            GetMessage(ModuleNumber+93,s);  (* "Sorry.  I cannot support that video combination." *)
            Error(s);
            VideoNumber := DefaultVideoString;
        END;

        TranslateVideoDefinition(VideoNumber,T);

        TransparentShadow := TubeType IN ATubeTypeSet{ColorTube,Color3270};

    END;

END BuildVideoTable;




PROCEDURE ClosingInstructions():BOOLEAN;
VAR
    Name : ARRAY [0..30] OF CHAR;
    CodeSet : ASetOfCodes;
    Code : ACode;
    Prefix, Choices : ARRAY [0..30] OF CHAR;
    Choice  : CARDINAL;
    l       : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    EraseScreen;
    l := 1;
    WriteMsg(ModuleNumber+94,l);  (* '   This video setup is not yet saved.  In order to save it so that' *)
    WriteMsg(ModuleNumber+95,l);  (* 'it is available whenever you use Time Line, you must go to the FILES' *)
    WriteMsg(ModuleNumber+96,l);  (* 'menu and select SAVE.  (You can select "Save Options Only" on the' *)
    WriteMsg(ModuleNumber+97,l);  (* 'SAVE menu.)  Until you have given the SAVE command, this' *)
    WriteMsg(ModuleNumber+98,l);  (* 'video setup will be temporary.' *)
    INC(l);

    GetMessage(ModuleNumber+99,Prefix);  (* "FINISHED SETTING UP VIDEO? " *)

    RETURN (NoYes(Prefix));

END ClosingInstructions;





BEGIN
    IF Permission( VideoSetupChange,NIL)  THEN
        SendNotices( VideoSetupChange, BeforeActing, NIL );

        VideoTable := ADR(vidctrl);
    
        RugTaken := GetRug(0, 0, maxcol, maxrow, Rug); (* 3/26/87 EGK *)
    
        EraseScreen;
    
        REPEAT
            WITH VideoConfiguration DO
                IF (GetTypes(ComputerType,BoardType,TubeType,Palette)) THEN
                   BuildVideoTable(ComputerType,BoardType,TubeType,Palette,VideoTable);
    
                    ConfigSaved := FALSE;
    
                    EraseScreen;
                END;
            END;
    
        UNTIL ClosingInstructions();
    
    
        EraseScreen;
    
        IF RugTaken THEN
            PutRug(0, 0, maxcol, maxrow, Rug);      (* 3/26/87 EGK *)
        END;
    
        ShowLights(ActiveLightRegion); (* RSC 11/4/87 *)

        SetLengthOf(s,0);
        Message(s);

        SendNotices( VideoSetupChange, AfterActing, NIL );
    END;

END TLSetVideo.
