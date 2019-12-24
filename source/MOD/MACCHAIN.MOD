(*<BIND IMPLEMENTATION BIND>*) MODULE MacChain;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

(*
Modifications:  
     10-Aug-89  KKC - Add copyright message.
     01-Sep-89  WKh - ReSynch code btwn. Cybersoft & Symantec.
     17-Nov-89  LVK - Modified to use MacroFileMedia if no path specified.
     20-Oct-90  RSC - Added BIND toggles.
                      Made minor tweaks to put things on the stack
                      rather than in globals.
*)


(* largely a copy of Macauto *)

    FROM Dialog   IMPORT Error;

    FROM Directory IMPORT ExtractFileNameParts, ParseFileName;

    FROM LStrings IMPORT SetString,  Upshift, LengthOf, SetLengthOf,
                         Copy, ConcatLS, Procustes, TrimRear,
                         ConcatS, SubStr, Remove;

    FROM MacLoadTools       IMPORT LoadMacros;

    FROM MacLights      IMPORT PlaybackLight, DoOurLight;

    FROM MacNodes       IMPORT MacroTree;

    FROM MacrosRc       IMPORT
    (* PROC *)                  FindMacroByName;


    FROM MacStack IMPORT
                         PushMacro;


    FROM MacVars  IMPORT MacroFileMedia, MacroFileName, FileSpec,
                         LightsOnRecord;

    FROM MacState IMPORT PushState,
                         StateStack, AState, State;

    FROM MsgFile  IMPORT GetMessage;
                         
    FROM Overlays IMPORT OverlayContext;

    FROM TreeObjects IMPORT ATreeNode;


TYPE
    chainType           = ARRAY [0..79] OF CHAR;





PROCEDURE DoMacChain();
VAR
    chainPtr            : POINTER TO chainType;
    chainMacro          : ARRAY [0..79] OF CHAR;
    MacroNode           : ATreeNode;
    MacName             : ARRAY [0..79] OF CHAR;
    S                   : ARRAY [0..200] OF CHAR;


(*-------------------------------------------------------------------------

Parses the chained macro string to get a
Macro Filename (with path), and a Macro Name.

The path is returned as argument1.

Both VARs are returned as LStrings.

---------------------------------------------------------------------------*)

PROCEDURE ParseArgument (VAR chainMacro,
                             macroname  : ARRAY OF CHAR):BOOLEAN;
VAR
    i         : CARDINAL;
    specifier : BOOLEAN;

BEGIN

  specifier := TRUE;
  
  TrimRear (chainMacro);
  IF ORD (chainMacro[0]) = 0 THEN
    RETURN FALSE;
  END;    (* no chainMacro *)

  (* sets position of i at last backslash *)
  i := ORD(chainMacro[0]);  (* begin at end *)
  LOOP (* search for backslash *)
    IF i = 0 THEN
      GetMessage (26381, S);
      Error (S);
      RETURN FALSE;
    END;
    IF chainMacro[i] = "\" THEN EXIT; END;
    DEC (i);
  END;

  (* extract macro name *)
  SubStr (chainMacro, macroname, i+1, (ORD (chainMacro[0]) +i-1));
  
  (* remove macro name and backslash *)
  Remove (chainMacro, i, ORD (macroname[0])+1);

  (* set macro name to proper length *)
  Procustes (macroname, 40);


  (* searches for period *)
  i := ORD(chainMacro[0]);  (* begin at end *)
  LOOP (* search for backslash *)
    IF i = 0 THEN
      specifier := FALSE;
    END;
    IF chainMacro[i] = "." THEN EXIT; END;
    DEC (i);
  END;

  IF NOT specifier THEN  
    ConcatS (chainMacro, FileSpec);
  END;
  
  RETURN TRUE;
END ParseArgument;




PROCEDURE AutoLoad( VAR chainMacro  : ARRAY OF CHAR);

VAR
    device      : ARRAY [0..3] OF CHAR;
    path        : ARRAY [0..56] OF CHAR;
    file        : ARRAY [0..8] OF CHAR;
    ext         : ARRAY [0..5] OF CHAR;
    OurChain    : ARRAY [0..80] OF CHAR;

BEGIN
      S := "Program Copyright (c) 1989 Symantec Corporation.";

      (* This part sets the path to MacroFileMedia if no path is supplied,
         else sets MacroFileMedia to path *)
         
      ParseFileName (chainMacro, device, path, file, ext);
      IF ((LengthOf(path) = 0) AND (LengthOf(device) = 0)) THEN
        SetLengthOf (OurChain, 0);
        ConcatLS (OurChain, MacroFileMedia);
        ConcatLS (OurChain, chainMacro);
        Copy (OurChain, chainMacro);
      ELSE
        ExtractFileNameParts (chainMacro, device, path, file, ext);
        Copy (device, MacroFileMedia);
        ConcatLS (MacroFileMedia, path);
        Copy (file, MacroFileName);
      END;


      IF LoadMacros (chainMacro, MacroTree, TRUE) THEN
        MacroNode := FindMacroByName (MacName);
        IF MacroNode = NIL THEN
          GetMessage (26382, S);
          ConcatLS (S, MacName);
          Error (S);
        ELSE
          PushMacro (MacroNode);
          PushState (Playback);
          IF NOT LightsOnRecord.PlayLight THEN
            GetMessage (26372, S);
            DoOurLight (PlaybackLight, S);
            LightsOnRecord.PlayLight := TRUE;
          END;
        END;
      ELSE
        GetMessage (26383, S);
        ConcatLS (S, chainMacro);
        Error (S);
      END;
END AutoLoad;





BEGIN

    chainPtr := OverlayContext();
    Copy (chainPtr^, chainMacro);
    Upshift (chainMacro);
    IF ParseArgument (chainMacro, MacName) THEN
      AutoLoad( chainMacro );
    ELSE
      GetMessage (26384, S);
      Error (S);
    END;

END DoMacChain;



(*<BIND
PROCEDURE MacChainBind();
BIND>*) 

BEGIN

    DoMacChain();

(*<BIND
END MacChainBind;
BIND>*) 


END MacChain.
