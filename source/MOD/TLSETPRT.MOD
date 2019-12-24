MODULE TLSetPrt;


     (****************************************************************)
     (*                                                              *)
     (*    TLSetPrt                                                  *)
     (*                                                              *)
     (*    Allow a user to set up printer and/or word processor      *)
     (*    control strings by picking from a menu.                   *)
     (*                                                              *)
     (*    External design by Andrew Layman and Roger Collins.       *)
     (*    Internal design and Coding by Roger Collins.              *)
     (*       Modified August 1984 by AL to allow a two-step         *)
     (*    selection of manufacturer and then model.                 *)
     (*                                                              *)
     (*                                                              *)
     (****************************************************************)

     (* MODIFICATION HISTORY:

        May  16, 1986  LAA - Updated for version 3.0 of TimeLine.

        Oct. 20, 1985  AL  - Expand size of character arrays for
                             menu.

        Nov. 10, 1985, AJL -- Correct a problem with positioning that
                              was causing the Init line to be read as
                              a blank line, too early.

        Dec. 8, 1985   AJL -- Read in the default translation string
                              from the phrases file.

        Jul 15 1987   RSC --  Added support for DOS printers.
        Aug 15 1987   RSC --  Added support for termination strings.
        Jan. 7, 1987  AJL --  Increased max tag length to 60.
        Feb 18, 1988  AJL --  Converted to use phrases file.
        Feb 25, 1988  RSC --  rename TLPRINT to TLPRINT3.
        Feb 26, 1988  AJL --  Allow the printer name line to have an
                              optional third $, and we take anything
                              following it (up to a delimiting 4th $)
                              as a description of the printer model.
        Mar. 4, 1988  AJL --  If a description line for a printer model
                              has a phrase in parenthesis at its beginning,
                              we will use that as a help key.
                          --  Reversed the order of parameters on ExtractParen.
                          --  The manufacturer name may optionally be followed
                              by prompt text in parenthesis, which may contain
                              a help key.
                          --  Manufacturer names not follwed by a description
                              containing a help key will have a help key of
                              "PRINTER" generated (or whatever the menu prefix
                              is.
        Mar. 4, 1988  AJL --  Changed Syntax to
                              $Manufacturer((Key)Prompt)$Model((Key)Prompt)
            2-Jan-89  RSC     Added references to StringsEqual() rather than Compare().
            2-Feb-89  RSC     Changed calls to ParseBal to reflect new params.
           28-Mar-89  RSC     Changed 3 to 4 in tlprint file.  Added options
                              for David's proposed menu scheme (directly offer
                              choice of Printer/Diskfile/Interface at a higher
                              level than in this program).
            4-May-89  MWP     Implemented support for direct serial port access
                              of second port.
            6-Jul-89  MWP     Save the printer name and model for use by
                              printer interface form.
           12-Apr-91  RSC     Changed params to MenuWithPrompt
     *)



    FROM ASCII        IMPORT  EOL;

    FROM Boxes        IMPORT  ABoxAttribute, ABoxType;

    FROM Codes        IMPORT  MaxCode, ACode, EmptyCodeSet, SetCodeBits,
                              ASetOfCodes;

    FROM Dialog       IMPORT  Message, Error, FatalError, Burp;

    FROM FileAux      IMPORT  PrepareForIO, CheckIO, FileResultMeans,
                              OverlayPath;

    FROM FileOpen     IMPORT  RequestFileOpenReadOnly;

    FROM FileSystem   IMPORT  File, Response, GetPos, ReadByte,
                              WriteChar, WriteWord, Close, SetPos,
                              Reset, SetOpen;

    FROM Foreign      IMPORT  ExpandStringToXLAT, DecodeString;

    FROM Helper       IMPORT  AScreenAction, GiveHelp;

    FROM Kbio         IMPORT  EraseScreen, maxrow, maxcol,
                              ascreeny, PutString, avidmode, PourText;

    FROM Keys         IMPORT  DoIt, HelpKey;

    FROM Layout       IMPORT  GanttWEnd, MenuStart, MenuEnd;

    FROM LStrings     IMPORT  ConcatS, ConcatLS, SetString, TrimRear,
                              Fill, Procustes, StoC, LStringToTString,
                              TStringToLString, SubStr, Search, StringsEqual,
                              Remove, LengthOf, SetLengthOf, Copy,
                              Upshift, LJust, Insert;

    FROM Menus        IMPORT  Menu, WordNumber, MenuWithPrompts, APromptType;

    FROM MsgFile      IMPORT  GetMessage;

    FROM Overlays     IMPORT
        (* PROC *)            OverlayContext;

    FROM PrintStatic  IMPORT  PrintCB, AControlGroup, AControlStyle,
                              APortType, AProtocol, PrintXLAT,
                              APrinterStyle, TranslateOverlay,
                              OutputDeviceName;

    FROM Rugs         IMPORT  ARug, GetRug, PutRug;

    FROM Schedule     IMPORT  ScheduleSaved, ConfigSaved;

FROM Text           IMPORT
    (* TYPE *)          AText,
    (* PROC *)          CreateText, DiscardText, AppendLine;

    FROM Words        IMPORT  ParseBal;






CONST
    ModuleNumber = 14000;   (* For GetMessage *)
CONST
    InputPrintName  = "TLPRINT4.CFG";  (* 3 --> 4.  RSC  3/28/89 *)
    TagLength       = 61; (* Arbitrary max of chars in a printer name *)
    TagOccurs       = 50; (* Current Max of MENU options *)
    TagChar         = "$";
CONST
    TextSpace = 3;
TYPE
    ATag            =  ARRAY [0..TagLength] OF CHAR;
VAR
    Option      : CARDINAL;
    TagOccurrance: CARDINAL;
    WhichSetup  : CARDINAL;
    InputFile   : File;
    l           : ascreeny;
    Rug         : ARug;
    Category    : ATag;
    High, Low   : ARRAY [1..TagOccurs] OF CARDINAL;
    s           : ARRAY [0..255] OF CHAR;
    s2          : ARRAY [0..80] OF CHAR;
    TagDescription : ARRAY [1..TagOccurs] OF ARRAY [0..81] OF CHAR;
    TagTable    : ARRAY [1..TagOccurs] OF ATag;


CONST  PrinterSetup    = 1;
       CustomSetup     = 2;
       AttachmentSetup = 3;




PROCEDURE DisplayInstructions(     MessageNumber : CARDINAL;
                                   StartY        : ascreeny;
                               VAR EndY          : ascreeny );
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    LOOP
        IF (StartY > GanttWEnd) THEN
    EXIT;
        END;
        GetMessage(MessageNumber,S);
        IF (LengthOf(S)=0) THEN
    EXIT;
        END;
        PourText(S,videonormal,2,StartY,maxcol-2,GanttWEnd,EndY);
        StartY := EndY + 1;
        INC(MessageNumber);
    END;
END DisplayInstructions;



    (* ExtractParen -- Remove the parenthesized string from the front of
                       S1 and put it in S2. *)

PROCEDURE ExtractParen( VAR S1, S2 : ARRAY OF CHAR );
VAR
    Len : CARDINAL;
BEGIN
    IF (LengthOf(S1)>0) AND (S1[1]="(") THEN
        Len := 1;
        ParseBal(S1,Len,S2);      (* Strip off the box title. *)
        Remove(S1,1,Len - 1);
    ELSE
        SetLengthOf(S2,0);
    END;
END ExtractParen;



    (* Module InfileInterface added Nov. 10, 1985.  AJL *)

    (*------------------ Start of Module InfileInterface ---------- *)
MODULE InfileInterface;

    (* This module allows us to get codes from the file, intermediated
       by a stack of codes that we may generate internally. *)

IMPORT EOL, File, ReadByte, CheckIO, FileResultMeans,
       Error, Response, SetPos;

EXPORT ReadNextChar, Push, PositionFile;


CONST
    StackSize  = 15;                 (* Maximum codes that can be pushed. *)
    CarriageReturn = 15C;
    LineFeed       = 12C;
VAR
    Stack      : ARRAY [0..StackSize-1] OF CHAR;
    Index      : CARDINAL;           (* Index of next unused stack cell. *)




PROCEDURE PositionFile( VAR F : File; H, L : CARDINAL);
BEGIN
    SetPos(F,H,L);
    Index := 0;
END PositionFile;






PROCEDURE GetNextChar(VAR InputFile:File; VAR C:CHAR):BOOLEAN;
VAR
    s : ARRAY [0..60] OF CHAR;
BEGIN
    ReadByte(InputFile,C);

    IF InputFile.eof THEN
        RETURN FALSE;
    ELSIF (CheckIO(InputFile) = done) THEN
            (* Any CarriageReturn will be returned as EOL.
               Any LineFeed following a CarriageReturn is skipped. *)
        IF (C = CarriageReturn) THEN
            ReadByte(InputFile,C);
            IF (NOT InputFile.eof) THEN
                IF (CheckIO(InputFile) = done) AND (C <> LineFeed) THEN
                    Push(C);  (* Oops, not a Line Feed. *)
                END;
            END;
            C := EOL;
        END;
        RETURN TRUE;
    ELSE
        FileResultMeans(InputFile,s);
        Error(s);
        RETURN FALSE;
    END;
END GetNextChar;




PROCEDURE ReadNextChar(VAR InputFile:File; VAR C:CHAR):BOOLEAN;
BEGIN
    IF (Pop(C)) THEN
        RETURN TRUE;
    ELSE
        RETURN GetNextChar(InputFile,C);
    END;
END ReadNextChar;




PROCEDURE Push( C : CHAR );
BEGIN
    IF (Index >= StackSize) THEN HALT; END;
    Stack[Index] := C;
    INC(Index);
END Push;





PROCEDURE Pop( VAR C : CHAR ) : BOOLEAN;
BEGIN
    IF (Index = 0) THEN
        RETURN FALSE;
    ELSE
        DEC(Index);
        C := Stack[Index];
        RETURN TRUE;
    END;
END Pop;


BEGIN
    Index := 0;    (* Stack is empty. *)
END InfileInterface;

    (*------------------ End of Module InfileInterface ---------- *)
















PROCEDURE GetOutputOption(VAR WhichSetup : CARDINAL):BOOLEAN;
VAR
    Context     : POINTER TO ARRAY [0..255] OF CHAR;
    Code        : ACode;
    l           : ascreeny;
    Prefix      : ARRAY [0..40] OF CHAR;
    MenuString  : ARRAY [0..100] OF CHAR;
BEGIN

    Context := OverlayContext();
    IF (Context <> NIL) AND (Context^[0] <> 0C) THEN
        CASE Context^[1] OF
            "P"  : WhichSetup := PrinterSetup;
          | "C"  : WhichSetup := CustomSetup;
          | "A"  : WhichSetup := AttachmentSetup;
        ELSE
            FatalError();
        END;
        RETURN TRUE;
    END;

    EraseScreen;
    DisplayInstructions(ModuleNumber+11,MenuStart+4,l);

    GetMessage(ModuleNumber+15,MenuString);
    ExtractParen(MenuString,Prefix);

    WhichSetup := 1;
    Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,EmptyCodeSet,
                 WhichSetup);

    RETURN (Code = DoIt);
END GetOutputOption;





PROCEDURE OpenInputFile(VAR f:File):BOOLEAN;
VAR
    InputName  : ARRAY [0..24] OF CHAR;
    Description : ARRAY [0..40] OF CHAR;
BEGIN
    SetString(InputName, InputPrintName);
    SetLengthOf(Description,0);

    RETURN  RequestFileOpenReadOnly(OverlayPath,InputName,Description,f);

END OpenInputFile;




   (*--------------------------------------------------------------*)



PROCEDURE Number(VAR NS:ARRAY OF CHAR):CARDINAL;
VAR
    i,n : CARDINAL;
BEGIN
    i := 1;
    n := StoC(NS,i);
    IF (NS[0] < 1C) OR (i <= ORD(NS[0])) THEN
        GetMessage(ModuleNumber+16,s);
        ConcatLS(s,NS);
        Error(s);
    END;
    RETURN n;
END Number;


PROCEDURE TrueOrFalse(VAR TS:ARRAY OF CHAR):BOOLEAN;
VAR
    S : ARRAY [0..99] OF CHAR;
    S1 : ARRAY [0..9] OF CHAR;
    S2 : ARRAY [0..5] OF CHAR;
    i  : CARDINAL;

BEGIN
    Copy(TS,S1);
    Upshift(S1);
    LJust(S1);
    Procustes(S1,1);
    GetMessage(ModuleNumber+17,S2);
    i := Search(S2,S1,1);
    CASE i OF
        1 : RETURN TRUE;
      | 2 : RETURN FALSE;
      ELSE
            GetMessage(ModuleNumber+18,S);
            ConcatLS(S,TS);
            Error(S);
    END;
    RETURN FALSE;
END TrueOrFalse;



PROCEDURE ReadOneGroup(VAR Group:AControlGroup);
TYPE
    AState = (SInit, SNewPage, SNewLine, SNormal, SBold,
              STop, SBottom, SLeft, SRight, SPause, STerminate, SDone);
VAR C:CHAR;
     i:CARDINAL;
     State:AState;
     ControlString : ARRAY [0..100] OF CHAR;
     Index:CARDINAL;
BEGIN
    MakeDefaults(Group);
        (* Now read the printer control chars into the appropriate arrays *)
    State := SInit;
    i     := 0;
    ControlString[0] := 0C;
    WHILE (State < SDone) DO
        IF (NOT ReadNextChar(InputFile,C)) THEN
            GetMessage(ModuleNumber+19,s);
            Error(s);
            RETURN;
        END;
        IF C = EOL THEN
            TrimRear(ControlString);
            CASE State OF
                SInit:     DecodeString(ControlString,Group.Init);
                  |
                SNewPage:  DecodeString(ControlString,Group.NewPage);
                  |
                SNewLine:  DecodeString(ControlString,Group.NewLine);
                  |
                SNormal:   DecodeString(ControlString,Group.Normal);
                  |
                SBold:     DecodeString(ControlString,Group.Bold);
                  |
                STop:      Group.TopMargin := Number(ControlString);
                  |
                SBottom:   Group.BottomMargin := Number(ControlString);
                  |
                SLeft:     Group.LeftMargin := Number(ControlString);
                  |
                SRight:    Group.RightMargin := Number(ControlString);
                  |
                SPause:    Group.Pause := TrueOrFalse(ControlString);
                  |
                STerminate:DecodeString(ControlString,Group.Terminate);
                ELSE FatalError;
            END; (* CASE *)
            INC(State);
            ControlString[0] := 0C;
            i := 0;
        ELSIF (i = 0) AND (C=TagChar) THEN      (* IF line begins "$" then *)
            State := SDone;                     (* it is past group.       *)
            Push(C);
            GetMessage(ModuleNumber+20,s);
            Error(s);
        ELSE  (* Not EOL ... Add onto ControlString. *)
            IF i < HIGH(ControlString) THEN
                INC(i);
                ControlString[0] := CHR(i);
                ControlString[i] := C;
            ELSIF (i = HIGH(ControlString)) THEN
                GetMessage(ModuleNumber+21,s);
                ConcatLS(s,ControlString);
                Error(s);
                INC(i);
            END; (* If room in the ControlString *)
        END; (* If not end-of-line *)
    END; (* While *)
END ReadOneGroup;



PROCEDURE ReadString( VAR S     : ARRAY OF CHAR);
VAR C:CHAR;
     i:CARDINAL;
     Index:CARDINAL;
BEGIN
        (* Now read the printer control chars into the appropriate arrays *)
    i     := 0;
    S[0]  := 0C;
    LOOP
        IF (NOT ReadNextChar(InputFile,C)) THEN
            RETURN;
        END;
        IF C = EOL THEN
            RETURN;
        END;
        IF (i < HIGH(S)) THEN
            INC(i);
            S[0] := CHR(i);
            S[i] := C;
        END;
    END; (* While *)
END ReadString;


    (* ReadOptionalLines -- Read and process lines of the general
                            form:
                            @x=string
                            Stop when a line does not start with "@".
                            *)


PROCEDURE ReadOptionalLines;
VAR  C:CHAR;
     Which : CHAR;
     i:CARDINAL;
     ControlString : ARRAY [0..255] OF CHAR;
     Index:CARDINAL;
BEGIN
    LOOP
        ControlString[0] := 0C;

        IF (NOT ReadNextChar(InputFile,C)) THEN
            RETURN;
        END;

        IF (C <> "@") THEN
            Push(C);
            RETURN;
        END;

        IF (NOT ReadNextChar(InputFile,Which)) THEN
            RETURN;
        END;

        LOOP
            IF (NOT ReadNextChar(InputFile,C)) OR (C=EOL) THEN
                RETURN;
            ELSIF (C = "=") THEN
                EXIT;
            END;
        END;

        ReadString(ControlString);

        CASE Which OF
            "X"    : IF (WhichSetup = CustomSetup) THEN
                         ExpandStringToXLAT(ControlString,PrintXLAT[OutToDisk]);
                     ELSE
                         ExpandStringToXLAT(ControlString,PrintXLAT[OutToPrinter]);
                     END;
          | "Y"    : SubStr(ControlString,TranslateOverlay,1,HIGH(TranslateOverlay));
            ELSE
                IF (ORD(ControlString[0]) > HIGH(ControlString)-30) THEN
                    ControlString[0] := CHR(HIGH(ControlString)-30);
                END;
                GetMessage(ModuleNumber+22,s);
                ConcatLS(s,ControlString);
                Error(s);
        END; (* CASE Which *)

    END;  (* End Main loop. *)


END ReadOptionalLines;



PROCEDURE GetPrinterStuff(Option:CARDINAL; VAR InputFile:File);

VAR
     Group:AControlGroup;
     C : CHAR;

BEGIN

        (* Set us back to the after the EOL following the tag they want. *)
        (* In my (Andrew's) humble opinion, it should not be necessary to
           do all of this Reset stuff before the PositionFile, but
           it is.  I think this reflects an oversight in the Logitech
           FileSystem module. *)
    Reset(InputFile);
    PositionFile(InputFile,High[Option],Low[Option]);


    IF (WhichSetup = CustomSetup) THEN
        ReadOneGroup(PrintCB.ControlStrings[WPNormal]);
        ReadOptionalLines;
    ELSE
        ReadOneGroup(PrintCB.ControlStrings[PrinterNormal]);
        PrintCB.ControlStrings[PrinterCompressed] :=
            PrintCB.ControlStrings[PrinterNormal];   (* In case of error. *)
        ReadOneGroup(PrintCB.ControlStrings[PrinterCompressed]);
        ReadOptionalLines;
    END;


END GetPrinterStuff;



PROCEDURE GetPromptText( VAR Text : AText );
VAR
    N       : CARDINAL;
    S2      : ARRAY [0..79]  OF CHAR;
    TempS   : ARRAY [0..255] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    Text := CreateText();
    IF (Text <> AText(NIL)) THEN
        FOR N := 1 TO TagOccurrance DO
            Copy(TagDescription[N],TempS);
            ExtractParen(TempS,S2);          (* Remove any help key. *)
            ok := AppendLine( TempS, Text );
        END;
    END;
END GetPromptText;



PROCEDURE PromptHelpKey( N : CARDINAL; VAR S : ARRAY OF CHAR);
VAR
    TempS : ARRAY [0..255] OF CHAR;
BEGIN
    Copy(TagDescription[N],TempS);
    ExtractParen(TempS,S);          (* Extract any help key. *)
END PromptHelpKey;








PROCEDURE GetCategory( VAR Category:ARRAY OF CHAR): BOOLEAN;
VAR
    PromptText  : AText;
    CodeSet     : ASetOfCodes;
    Selection   : CARDINAL;
    i, j        : CARDINAL;
    Code        : ACode;
    l           : ascreeny;
    Tag         : ATag;
    S           : ARRAY [0..31] OF CHAR;
    Prefix      : ARRAY [0..41]   OF CHAR;
    MenuString  : ARRAY [0..201] OF CHAR;
BEGIN
    EraseScreen;
    DisplayInstructions(ModuleNumber+31,MenuStart+4,l);

    GetMessage(ModuleNumber+35,Prefix);  (* Printer is a *)

    Fill(MenuString," ",0);
    Message(MenuString);

    Fill(S,",",1);                   (* Comma separates each choice. *)
    FOR i := 1 TO TagOccurrance DO
       Tag := TagTable[i];
       TrimRear(Tag);
       ConcatLS(MenuString,Tag);
       IF i < TagOccurrance THEN ConcatLS(MenuString,S); END;
    END; (* Loop *)

    Selection := 1;
    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);

    GetPromptText( PromptText );


    REPEAT
        Code := MenuWithPrompts(Prefix,MenuString,
                                0,MenuStart,maxcol,MenuEnd,ABoxType{NoBox},CodeSet,
                                PromptFromText,1,PromptText,
                                Selection);
        IF (Code = HelpKey) THEN
            PromptHelpKey(Selection,S);
            IF (LengthOf(S)=0) THEN
                Copy(Prefix,S);
            END;
            GiveHelp(S,MenuEnd+1,GanttWEnd,RestoreTheScreen);
        END;
    UNTIL Code <> HelpKey;

    DiscardText( PromptText );

    IF Code = DoIt THEN
        SubStr(TagTable[Selection], Category, 1, HIGH(Category));
        TrimRear(Category);
    END;

    RETURN (Code = DoIt);

END GetCategory;





PROCEDURE GetExactModel( VAR Category:ARRAY OF CHAR ): CARDINAL;
VAR Prefix      : ARRAY [0..15]   OF CHAR;
    MenuString  : ARRAY [0..200] OF CHAR;
    S           : ARRAY [0..30] OF CHAR;
    Code        : ACode;
    Selection   : CARDINAL;
    Tag         : ATag;
    Selection2  : CARDINAL;
    i, j        : CARDINAL;
    l           : ascreeny;
    CodeSet     : ASetOfCodes;
BEGIN

    Fill(MenuString," ",0);             (* Set length to zero *)
    Message(MenuString);

    Fill(S,",",1);                   (* Comma separates each choice. *)
    FOR i := 1 TO TagOccurrance DO
       Tag := TagTable[i];
       TrimRear(Tag);
       ConcatLS(MenuString,Tag);
       IF i < TagOccurrance THEN ConcatLS(MenuString,S); END;
    END; (* Loop *)

    Selection := 1;

    SetCodeBits(CodeSet,0,MaxCode,FALSE);
    SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);


    REPEAT
        Code := MenuWithPrompts(Category,MenuString,
                                0,MenuStart,maxcol,MenuEnd,ABoxType{NoBox},CodeSet,
                                PromptDescription,1,
                                Selection);
        IF (Code = HelpKey) THEN
            PromptHelpKey(Selection,S);
            IF (LengthOf(S) > 0) THEN
                GiveHelp(S,MenuEnd+1,GanttWEnd,RestoreTheScreen);
            ELSE
                Burp();
            END;
        END;
    UNTIL Code <> HelpKey;

    IF ( Code <> DoIt ) THEN
       Selection := 0;
    ELSE
        SubStr(TagTable[Selection], Category, 1, HIGH(Category));
        TrimRear(Category);
    END;

    RETURN Selection;

END GetExactModel;








PROCEDURE ReadCategories(VAR InputFile:File);
TYPE
    AState = (StartOfLine, InHeading, InText);
VAR
    C : CHAR;
    ok : BOOLEAN;
    State : AState;
    TagIndex : CARDINAL;
    Tag : ATag;


    PROCEDURE SaveTag(VAR s:ARRAY OF CHAR);
    VAR
        i : CARDINAL;
        s1,Category : ARRAY [0..255] OF CHAR;
        s2 : ARRAY [0..51] OF CHAR;
        Len : CARDINAL;
    BEGIN
            (*  Extract everything up to the first "$". *)
        SetString(s1,",$");       (* Change break char to $ *)
        ConcatLS(s1,s);
        WordNumber(s1,1,Category);

            (*  See if the category is already in the table. *)
        FOR i := 1 TO TagOccurrance DO
            IF (StringsEqual(Category,TagTable[i])) THEN
                RETURN;
            END;
        END;
            (*  But never add "Custom". *)
        GetMessage(ModuleNumber+25,s2);
        IF (StringsEqual(Category,s2)) THEN
            RETURN;
        END;
            (*  Not in table already. Add it. *)
        IF (TagOccurrance >= TagOccurs) THEN
            GetMessage(ModuleNumber+26,s2);    (* Too many categories in file. *)
            Message(s2);
            RETURN;
        END;
        INC(TagOccurrance);

            (* The first item is a manufacturer name, the second is
               an optional description, which may contain a help key. *)

        Len := 1;
        ParseBal(Category, Len ,TagTable[TagOccurrance]);
        ParseBal(Category, Len ,TagDescription[TagOccurrance]);

    END SaveTag;


BEGIN
    GetMessage(ModuleNumber+27,Tag);   (* One moment . . . *)
    Message(Tag);

    TagOccurrance := 0;
    Reset(InputFile);
    PositionFile(InputFile,0,0);

    State := StartOfLine;
    WHILE (ReadNextChar(InputFile,C)) DO
      CASE State OF
        StartOfLine:  IF (C = TagChar) THEN
                          Tag[0] := 0C;
                          TagIndex := 0;
                          State := InHeading;
                      ELSE
                          Push(C);
                          State := InText;
                      END;
          |
        InHeading:    IF (C <> EOL) THEN
                          IF (TagIndex < TagLength) THEN
                              INC(TagIndex);
                              Tag[TagIndex] := C;
                              Tag[0] := CHR(TagIndex);
                          END;
                      ELSE  (* EOL *)
                          SaveTag(Tag);
                          State := StartOfLine;
                      END;
          |
        InText:       IF (C = EOL) THEN
                          State := StartOfLine;
                      END;
        ELSE FatalError;
    END; (* Case *)
  END;   (* While *)
END ReadCategories;





PROCEDURE ReadSubCategories(VAR InputFile:File; VAR Category:ARRAY OF CHAR);
TYPE
    AState = (StartOfLine, InHeading, InText);
VAR
    C : CHAR;
    ok : BOOLEAN;
    State : AState;
    TagIndex : CARDINAL;
    Tag : ARRAY [0..255] OF CHAR;


    PROCEDURE SaveTag(VAR s:ARRAY OF CHAR);
    VAR
        i,Len : CARDINAL;
        s1,Model : ARRAY [0..255] OF CHAR;
        Cat : ATag;
    BEGIN
                    (*  Manufacturer$Model$Description *)

        SetString(s1,",$");       (* Change break char to $ *)
        ConcatLS(s1,s);
        WordNumber(s1,1,Model);   (* Temporary use.  Cat <-- Manufacturer *)
        Len := 1;
        ParseBal(Model,Len,Cat);

            (*  See if the category matches. *)
        IF (NOT StringsEqual(Cat,Category)) THEN (* RSC 1/2/88 *)
            RETURN;
        END;
            (*  Add to table. *)
        IF (TagOccurrance >= TagOccurs) THEN
            GetMessage(ModuleNumber+28,Model);   (* Too many categories in file. *)
            Message(Model);
            RETURN;
        END;
        INC(TagOccurrance);

        WordNumber(s1,2,Model);
        Len := 1;
        ParseBal(Model,Len,TagTable[TagOccurrance]);
        ParseBal(Model,Len,TagDescription[TagOccurrance]);


        GetPos(InputFile,High[TagOccurrance],Low[TagOccurrance]);
    END SaveTag;


BEGIN
    GetMessage(ModuleNumber+27,Tag);
    Message(Tag);

    TagOccurrance := 0;
    Reset(InputFile);
    PositionFile(InputFile,0,0);

    State := StartOfLine;
    WHILE (ReadNextChar(InputFile,C)) DO
      CASE State OF
        StartOfLine:  IF (C = TagChar) THEN
                          Tag[0] := 0C;
                          TagIndex := 0;
                          State := InHeading;
                      ELSE
                          Push(C);
                          State := InText;
                      END;
          |
        InHeading:    IF (C <> EOL) THEN
                          IF (TagIndex < HIGH(Tag)) THEN
                              INC(TagIndex);
                              Tag[TagIndex] := C;
                              Tag[0] := CHR(TagIndex);
                          END;
                      ELSE  (* EOL *)
                          SaveTag(Tag);
                          State := StartOfLine;
                      END;
          |
        InText:       IF (C = EOL) THEN
                          State := StartOfLine;
                      END;
        ELSE FatalError;
    END; (* Case *)
  END;   (* While *)
END ReadSubCategories;



(* <MWP> 04-May-89 *)

PROCEDURE GetPrinterNumber;
CONST
    PARALLEL1   = 1;
    PARALLEL2   = 2;
    PARALLEL3   = 3;
    SERIAL1     = 4;
    SERIAL2     = 5;
    DOSDEVICE   = 6;

VAR Prefix      : ARRAY [0..41] OF CHAR;
    MenuString  : ARRAY [0..99] OF CHAR;
    Code        : ACode;
    Selection   : CARDINAL;
    l           : ascreeny;
    i           : CARDINAL;
BEGIN
    EraseScreen;
    DisplayInstructions(ModuleNumber+41,MenuStart+4,l);

    GetMessage(ModuleNumber+45,MenuString);
    ExtractParen(MenuString,Prefix);

    IF (PrintCB.PortType = PortSerial) THEN
        Selection := PrintCB.PrinterNumber + SERIAL1;
    ELSIF  (PrintCB.PortType = PortDOS)  THEN
        Selection := DOSDEVICE;
    ELSE
        Selection := PrintCB.PrinterNumber+1;
    END;

    Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,EmptyCodeSet,
                 Selection);

    IF (Code = DoIt) THEN
        IF (Selection = SERIAL1) OR ( Selection = SERIAL2 ) THEN
            PrintCB.PortType      := PortSerial;
            PrintCB.PrinterNumber := Selection - SERIAL1;

            EraseScreen ();

            DisplayInstructions(ModuleNumber+51,MenuStart+4,l);

            GetMessage(ModuleNumber+55,MenuString);
            ExtractParen(MenuString,Prefix);

            Selection := 1;
            i := 300;
            WHILE (i < PrintCB.BaudRate) AND (Selection < 6) DO
                INC(Selection);
                INC(i,i);         (* Double the rate. *)
            END;
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            i := 1;
            IF (Code = DoIt) THEN
                PrintCB.BaudRate := 300;
                FOR i := 1 TO Selection - 1 DO
                    INC(PrintCB.BaudRate, PrintCB.BaudRate);
                END;
            END;

            GetMessage(ModuleNumber+56,MenuString);
            ExtractParen(MenuString,Prefix);
            Selection := PrintCB.NumberOfBits - 6;
            IF (Selection > 2) OR (Selection < 1) THEN
                Selection := 2;
            END;
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            IF (Code = DoIt) THEN
                PrintCB.NumberOfBits := Selection + 6;
            END;

            GetMessage(ModuleNumber+57,MenuString);
            ExtractParen(MenuString,Prefix);

            Selection := PrintCB.StopBits;
            IF (Selection < 1) OR (Selection > 2) THEN
                Selection := 1;
            END;
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            IF (Code = DoIt) THEN
                PrintCB.StopBits := Selection;
            END;

            GetMessage(ModuleNumber+58,MenuString);
            ExtractParen(MenuString,Prefix);
            IF (PrintCB.ParityBit) THEN
                IF (PrintCB.EvenParity) THEN
                    Selection := 2;
                ELSE
                    Selection := 3;
                END;
            ELSE
                Selection := 1;
            END;
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            IF (Code = DoIt) THEN
                PrintCB.ParityBit := (Selection > 1);
                PrintCB.EvenParity := (Selection = 2);
            END;

            GetMessage(ModuleNumber+59,MenuString);
            ExtractParen(MenuString,Prefix);
            Selection := ORD(PrintCB.Protocol)+1;
            IF (Selection > 4) THEN
                Selection := 2;
            END;
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            IF (Code = DoIt) THEN
                PrintCB.Protocol := VAL(AProtocol,Selection-1);
            END;

        ELSIF ( Selection = DOSDEVICE ) THEN
            IF (PrintCB.PortType = PortDOS) THEN (* Was DOS? *)
                Selection := PrintCB.PrinterNumber + 1;
            ELSE
                Selection := 1;
            END;
            PrintCB.PortType := PortDOS;
            GetMessage(ModuleNumber+65,MenuString);
            ExtractParen(MenuString,Prefix);
            EraseScreen;
            DisplayInstructions(ModuleNumber+61,MenuStart+4,l);
            Code := Menu(Prefix,MenuString,0,MenuStart,maxcol,MenuEnd,
                         EmptyCodeSet,Selection);
            IF (Code = DoIt) THEN
                PrintCB.PrinterNumber := Selection - 1;
            END;
        ELSE
            PrintCB.PrinterNumber := Selection-1;
            PrintCB.PortType      := PortParallel;
        END;
    END;
END GetPrinterNumber;




PROCEDURE MakeDefaults(VAR Group:AControlGroup);
BEGIN
    MakeDefaultControls(Group);
    WITH Group DO
        Fill(Bold," ",0);
        TopMargin := 3;
        BottomMargin := 63;
        LeftMargin := 6;
        RightMargin := 78;
        Pause := FALSE;
    END;
END MakeDefaults;





PROCEDURE MakeDefaultControls(VAR Group:AControlGroup);
BEGIN
    WITH Group DO
        Fill(Init," ",0);
        Fill(NewPage,14C,0); (* Form feed *)
        SetString(NewLine,"12");
        NewLine[1] := 15C;  (* Carriage return *)
        NewLine[2] := 12C;  (* Line feed       *)
        Fill(Normal," ",0);
        Fill(Bold," ",0);
        Fill(Terminate," ",0);
    END;
END MakeDefaultControls;




PROCEDURE DoTheWork;
VAR
    TempOutputName : ARRAY [0..255] OF CHAR;
BEGIN
    MakeDefaultControls(PrintCB.ControlStrings[NoControls]);

    EraseScreen;

    IF ( NOT OpenInputFile(InputFile) ) OR
       ( NOT GetOutputOption( WhichSetup ) ) THEN
        Close(InputFile);
        RETURN;
    END;


    EraseScreen;

    IF (WhichSetup = CustomSetup) THEN
        GetMessage(ModuleNumber+25,Category);   (* Custom *)

    ELSIF (WhichSetup = PrinterSetup) THEN
        ReadCategories(InputFile);
        IF TagOccurrance = 0 THEN
            GetMessage(ModuleNumber+71,s);    (* File contains no configurations! *)
            Error(s);
            Close(InputFile);
            RETURN;
        END;
        IF (GetCategory(Category)) THEN
            SetLengthOf ( TempOutputName, 0 );                      (* 6-Jul-89 MWP *)
            ConcatLS ( TempOutputName,Category );
            EraseScreen;
        ELSE
            GetMessage(ModuleNumber+72,s);  (* Options remain as they were. *)
            Message(s);
            Close(InputFile);
            RETURN;
        END;
    ELSE  (* AttachmentSetup *)
        GetPrinterNumber();
        RETURN;
    END;

    ReadSubCategories(InputFile,Category);

    IF TagOccurrance = 0 THEN
        GetMessage(ModuleNumber+71,s);  (* File contains no configurations! *)
        Error(s);
        Close(InputFile);
        RETURN;
    END;


    IF (WhichSetup = CustomSetup) THEN
        DisplayInstructions(ModuleNumber+81,GanttWEnd-TextSpace,l);
    ELSE
        DisplayInstructions(ModuleNumber+85,GanttWEnd-TextSpace,l);
    END;

    Option := GetExactModel(Category);

    IF Option = 0 THEN
        GetMessage(ModuleNumber+72,s);  (* Options remain as they were. *)
        Message(s);
        Close(InputFile);
        RETURN;
    ELSE
       ConcatS ( TempOutputName, " - " );                            (* 6-Jul-89 MWP *)
       ConcatLS ( TempOutputName,Category );
    END;

    GetMessage(ModuleNumber+1,s);   (* Translation string. *)
    IF (WhichSetup = CustomSetup) THEN
        ExpandStringToXLAT(s,PrintXLAT[OutToDisk]);
        TranslateOverlay[0] := 0C;
    ELSE
        ExpandStringToXLAT(s,PrintXLAT[OutToPrinter]);
    END;

    GetPrinterStuff(Option,InputFile);

    SetLengthOf(s,0);
    Message(s);
    ConfigSaved := FALSE;   (* To say that we modified the options *)
    ScheduleSaved := FALSE; (* and the schedule itself *)

    Close(InputFile);

    IF (WhichSetup = PrinterSetup) THEN                              (* 6-Jul-89 MWP *)
       SetLengthOf ( OutputDeviceName, 0 );
       ConcatLS ( OutputDeviceName, TempOutputName );
    END;


END DoTheWork;





BEGIN
    IF (GetRug(0,0,maxcol,maxrow,Rug)) THEN
        DoTheWork();
        PutRug(0,0,maxcol,maxrow,Rug);
    END;
END TLSetPrt.
