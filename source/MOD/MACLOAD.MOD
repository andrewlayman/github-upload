MODULE MacLoad;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
    *)



(* Loads macros from disk into memory.
*)

FROM Codes        IMPORT SetCodeBits;

FROM Dialog       IMPORT Message, ADialogOption,
                         MultipleChoiceBox;

FROM Directory    IMPORT ExtractFileNameParts;

FROM FileSystem   IMPORT File, Lookup, Close, Response;

FROM LStrings     IMPORT SetString, ConcatS, ConcatLS, Copy,
                         LStringToTString, TrimRear;

FROM MacHeader    IMPORT
                         AMacroHeaderType, MacHeaderStack;

FROM MacLoadTools IMPORT PickMacroFile, LoadMacros;

FROM MacNodes     IMPORT MacroTree;

FROM MacTalk      IMPORT MacDeath;

FROM MacVars      IMPORT MacroFileName, MacroFileMedia, ReplacedKeySet;

FROM MsgFile      IMPORT GetMessage;

FROM Rugs         IMPORT GetRug, PutRug, ARug;

FROM Schedule     IMPORT ProjectName, ProjectMedia;

FROM Space        IMPORT HeapAvailable;

FROM Subfiles     IMPORT StartFileInput, StartSubfileInput;

FROM SYSTEM       IMPORT ADR, WORD, SIZE, ADDRESS;

FROM TreeObjects  IMPORT ATreeNode;

FROM MacrosRc     IMPORT
                         DisposeMacros;

(* 
   pick a file,
   open the file,
   read in the macros to ext. storage,
   create a list of macros with handles.
*)

  CONST header         = 1;
        body           = 2;
        MacroSubfile   = 1;


VAR 
    S                  : ARRAY [0..255] OF CHAR;
    title              : ARRAY [0..31] OF CHAR;
    prefix             : ARRAY [0..10] OF CHAR;
    menustr            : ARRAY [0..255] OF CHAR;
    Template           : ARRAY [0..64] OF CHAR;
    device             : ARRAY [0..3] OF CHAR;
    path, media        : ARRAY [0..80] OF CHAR;
    file               : ARRAY [0..8] OF CHAR;
    ext                : ARRAY [0..5] OF CHAR;
    selection          : CARDINAL;
    rug                : ARug;
    AutoReplace        : BOOLEAN;
    Copyright          : ARRAY[0..50] OF CHAR;


BEGIN
  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  AutoReplace := TRUE;
  IF MacroTree^.Methods^.GetFirst (MacroTree) <> NIL THEN
    GetMessage (26404, title);
    GetMessage (26405, S);
    GetMessage (26406, prefix);
    GetMessage (26407, menustr);
    selection := 1;
    IF NOT MultipleChoiceBox (S, title, NoHelp, prefix, menustr, selection) THEN
      RETURN;
    ELSIF selection = 1 THEN
      DisposeMacros (MacroTree);
    ELSIF selection = 3 THEN RETURN;
    END;
  END;
  selection := 1;
  IF MacroTree^.Methods^.GetFirst (MacroTree) <> NIL THEN
    GetMessage (26408, title);
    GetMessage (26409, S);
    GetMessage (26410, prefix);
    GetMessage (26411, menustr);
    IF NOT MultipleChoiceBox (S, title, NoHelp, prefix, menustr, selection) THEN
      RETURN;
    END;
    CASE selection OF
      1 : AutoReplace := TRUE;
    | 2 : AutoReplace := FALSE;
    | 3 : RETURN;
    ELSE ;
    END;
  END;

  IF NOT GetRug (0,0,79,24, rug) THEN
    MacDeath;
  END;
  IF PickMacroFile (Template) THEN
    IF NOT LoadMacros (Template, MacroTree, AutoReplace) THEN RETURN; END;
    ExtractFileNameParts (Template, device, path, file, ext);
    Copy (device, media);
    ConcatLS (media, path);
    Copy (media, MacroFileMedia);
    Copy (file, MacroFileName);
  END;
  PutRug (0,0,79,24, rug);
END MacLoad.
