IMPLEMENTATION MODULE MacSetUp;

(* MODIFICATION HISTORY *)
(* 25 Jun 1990 TGS - get macros hotkeys from Phrases                      *)

FROM LStrings   IMPORT  StoC;

FROM MsgFile    IMPORT  GetMessage;

FROM SegWords   IMPORT 
    (* PROC *)          WordNumber;

CONST
    ModuleNumber = 26400;

VAR
    S       : ARRAY [0..79] OF CHAR;
    Text    : ARRAY [0..8]  OF CHAR;
    k       : CARDINAL;

BEGIN
    (* What Was...
    MenuKey         := 256 + 68H; (* Alt/F1 *)
    MacInsertKey    := 256 + 6AH; (* Alt/F3 *)
    MacHaltKey      := 256 + 75H; (* Ctrl/End *) (* took out of DEF, not used - TGS 27-Jun-90 *)
    StartRecordKey  := 256 + 83H; (* Alt/= *)
    StopRecordKey   := 256 + 82H; (* Alt/- *)
    ListKey         := 256 + 6DH; (* Alt/F6 *)
    *)

    GetMessage(ModuleNumber+95,S);
    WordNumber(S,1,Text); k := 1; MenuKey        := StoC(Text,k);
    WordNumber(S,2,Text); k := 1; MacInsertKey   := StoC(Text,k);
    WordNumber(S,3,Text); k := 1; StartRecordKey := StoC(Text,k);
    WordNumber(S,4,Text); k := 1; StopRecordKey  := StoC(Text,k);
    WordNumber(S,5,Text); k := 1; ListKey        := StoC(Text,k);

    StepMode        := FALSE;
    PlayBackSpeed   := Fast;

END MacSetUp.
