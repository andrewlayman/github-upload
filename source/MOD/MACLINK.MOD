MODULE MacLink;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       13-Nov-89  RSC - Import from Space rather than Storage.
       20-Nov-89  LVK - LinkedMacro now only incorporates the path iff
                        the supplied path (from MacroList) <> MacroFileMedia.
    *)


(* Gets template and macro from user for chaining *)

(* Hmm... needs to do SelectMacroName... tough

  Select Macro File ---> Select Macro Name ---> Concat
  
  Need a macrotree VAR for load macros so a temporary tree
  can be built.
  
 *)


FROM Dialog       IMPORT Message;

FROM Directory    IMPORT ParseFileName;

FROM Kbio         IMPORT EraseLn, maxrow;

FROM LStrings     IMPORT SetString, Copy, Fill, ConcatLS, ConcatS,
                         TrimRear, Compare;

FROM MacLoadTools IMPORT PickMacroFile, LoadMacros;

FROM MacNodes     IMPORT MacroTree;

FROM MacroSelect  IMPORT SelectMacroName;

FROM MacTalk      IMPORT MacDeath;

FROM MacVars      IMPORT MacroFileName, MacroFileMedia, FormAccepted,
                         LinkedMacro;

FROM MsgFile      IMPORT GetMessage;

FROM Rugs         IMPORT GetRug, PutRug, ARug;

FROM Space        IMPORT DEALLOCATE;

FROM Subfiles     IMPORT StartFileInput, StartSubfileInput;

FROM TreeObjects  IMPORT ATree, CreateTree, ValidateTree;

FROM MacrosRc     IMPORT
                         DisposeMacros;

(* 
   pick a file,
   open the file,
   read in the macros to ext. storage,
   create a list of macros with handles.
*)


VAR 
    S                  : ARRAY [0..255] OF CHAR;
    title              : ARRAY [0..31] OF CHAR;
    Template           : ARRAY [0..64] OF CHAR;
    MacName            : ARRAY [0..40] OF CHAR;
    DeviceName         : ARRAY [0..2] OF CHAR;
    PathName           : ARRAY [0..64] OF CHAR;
    FileName           : ARRAY [0..8] OF CHAR;
    Extension          : ARRAY [0..3] OF CHAR;
    LinkedMacroMedia   : ARRAY [0..64] OF CHAR;
    i                  : CARDINAL;
    rug                : ARug;
    FirstMacroTree,
    SecondMacroTree    : ATree;
    Copyright          : ARRAY[0..50] OF CHAR;



BEGIN

  Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  FormAccepted := FALSE;

  IF NOT GetRug (0,0,79,24, rug) THEN
    MacDeath;
  END;
  
  FOR i := 0 TO 2 DO
    EraseLn (i);
  END;
  
  IF PickMacroFile (Template) THEN

    IF NOT (CreateTree (SecondMacroTree)) THEN
      MacDeath;
      RETURN;
    END;
    ValidateTree (SecondMacroTree);

    FirstMacroTree := MacroTree;
    MacroTree := SecondMacroTree;

    IF NOT LoadMacros (Template, MacroTree, TRUE) THEN RETURN; END;

    GetMessage (26396, S);
    Message (S);
    Fill (MacName, " ", 0);
    GetMessage (26397, title);
    IF SelectMacroName (5, 5, 47, maxrow - 6, title, MacName) THEN
      FormAccepted := TRUE;
    END;

    TrimRear (MacName);
    Copy (Template, LinkedMacro);

       (* Use only the filename if the specified path is the same as
          the current macro media *)
    ParseFileName(LinkedMacro, DeviceName, PathName, FileName, Extension);
    Copy (DeviceName, LinkedMacroMedia);
    ConcatLS (LinkedMacroMedia, PathName);
    IF Compare (MacroFileMedia, LinkedMacroMedia) = 0 THEN
      Copy (FileName, LinkedMacro);
      ConcatS (LinkedMacro, ".");
      ConcatLS (LinkedMacro, Extension);
    END;

    ConcatS (LinkedMacro, "\");
    ConcatLS (LinkedMacro, MacName);
    
    DisposeMacros (MacroTree);
    MacroTree^.Methods^.Discard (MacroTree);
    MacroTree := FirstMacroTree;

  END;
  PutRug (0,0,79,24, rug);
END MacLink.
