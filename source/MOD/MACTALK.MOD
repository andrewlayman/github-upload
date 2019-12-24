IMPLEMENTATION MODULE MacTalk;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)




FROM Dialog     IMPORT Error, WarningBox, ADialogOption, FatalError;

FROM LStrings   IMPORT TStringToLString, SetString, ConcatS;

FROM MacVars    IMPORT Interlock;

FROM MsgFile    IMPORT GetMessage;

FROM RTSMain    IMPORT Terminate, Status;




PROCEDURE MacError (S : ARRAY OF CHAR);


BEGIN
  INC (Interlock);
  Error (S);
  DEC (Interlock);
END MacError;


PROCEDURE MacDeath;

VAR S          : ARRAY [0..255] OF CHAR;

BEGIN
  GetMessage (26488, S);
  Error (S);
  FatalError;
END MacDeath;





(*---------------------------------------------------------------------

Uses Dialog's WarningBox, but allows no help, and input strings are
explicit (in quotes). Also INCs and DECs Interlock so OldGetCode is used.

----------------------------------------------------------------------*)

PROCEDURE MacWarningBox (VAR Interlock : CARDINAL;
                             S         : ARRAY OF CHAR;
                             Title     : ARRAY OF CHAR);
VAR
    S2    : ARRAY [0..255] OF CHAR;
    title : ARRAY [0..30] OF CHAR;

BEGIN
  TStringToLString (S, S2);
  TStringToLString (Title, title);
  INC (Interlock);
  WarningBox (S2, title, NoHelp);
  DEC (Interlock);
END MacWarningBox;

END MacTalk.
