IMPLEMENTATION MODULE NetCharacters;

    (*  MODIFICATION HISTORY
        05-Feb-90 EGK  Made drawing chars variables instead of constants,
                       so they can be changed in phrases.
     *)

FROM Foreign                IMPORT
    (* TYPE *)                  ACharacterConversionTable,
    (* PROC *)                  ExpandStringToXLAT;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;


CONST
    ModuleNumber    = 20200;        (* Same as NetDraw *)


PROCEDURE InitNetFont ();

VAR
    s               : ARRAY [0..255] OF CHAR;
    NetCharTable    : ACharacterConversionTable;

BEGIN
    GetMessage (ModuleNumber+30, s);
    ExpandStringToXLAT (s, NetCharTable);

    blank          := NetCharTable[ 32];
    asterick       := NetCharTable[ 42];
    UpArrow        := NetCharTable[ 24];
    DownArrow      := NetCharTable[ 25];
    SmallPlus      := NetCharTable[ 43];
    PoundSign      := NetCharTable[ 35];
    HBar2          := NetCharTable[205];
    VBar2          := NetCharTable[186];
    TTee2          := NetCharTable[209];
    BTee2          := NetCharTable[207];
    ULC2           := NetCharTable[201];
    URC2           := NetCharTable[187];
    LLC2           := NetCharTable[200];
    LRC2           := NetCharTable[188];
    HBar1          := NetCharTable[196];
    VBar1          := NetCharTable[179];
    ULC1           := NetCharTable[218];
    URC1           := NetCharTable[191];
    LLC1           := NetCharTable[192];
    LRC1           := NetCharTable[217];
    TopTee         := NetCharTable[194];
    BotTee         := NetCharTable[193];
    LeftTee        := NetCharTable[195];
    RightTee       := NetCharTable[180];
    plus           := NetCharTable[197];
    ThickBar       := NetCharTable[223];
    DoubleLeftTee  := NetCharTable[199];
    DoubleRightTee := NetCharTable[182];
    DoubleVertPlus := NetCharTable[215];
    DoubleHorPlus  := NetCharTable[216];

END InitNetFont;



BEGIN                       (* NetCharacters *)
    InitNetFont();
END NetCharacters.
