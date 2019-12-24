MODULE MacSave;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Saves macro to disk.

   Modifications:
   
   5/2/89 LVK   : Moved form to separate file "MACSECF.MOD" for additon
                  to TLFORMS file.
   7/21/89 LVK  : Used Direct411.GetOutputFile instead of forms. Saves
                  over 20K.
   10-Aug-89  KKC - Add copyright message.
   01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec.
   23-Oct-89  WKH - After GetOutputFile, parse the NameOut so that we don't
                    save the extension along with the macro name.  Caused
                    all sorts of problems(especially since the rest of macros
                    assumed that was the case!!!)
*)


FROM Dialog         IMPORT Message, Error;

FROM Direct411      IMPORT GetOutputFile;

FROM Directory      IMPORT ParseFileName;

FROM FlexStor       IMPORT GetExtData;

FROM FileSystem     IMPORT File, Lookup, Delete, Close, Response;

FROM FileAux        IMPORT PrepareForIO, DisplayFileError;

FROM LStrings       IMPORT Copy, ConcatLS, TStringToLString,
                           LStringToTString, ConcatS, TrimRear;

FROM MacBuffs       IMPORT MaxKeystrokes;

FROM MacCnfg        IMPORT WriteConfig;

FROM MacHeader      IMPORT AMacroHeaderType;

FROM MacNodes       IMPORT MacroTree, AMacroRecordPointer;

FROM MacVars        IMPORT LastMacroSaved, MacroFileMedia, FileSpec,
                           MacroFileName, FormAccepted;

FROM Menus          IMPORT NoYes;

FROM MsgFile        IMPORT GetMessage, ConcatMessage;

FROM RecordIO       IMPORT WriteRecord;

FROM Subfiles       IMPORT StartFileOutput, EndFileOutput,
                           StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM         IMPORT ADR, SIZE, ADDRESS;

FROM TreeObjects    IMPORT
                           ATreeNode, ATreeOrder;


  CONST
        headertype       = 1;
        MacRecType       = 2;
        nodeinfotype     = 3;

  VAR
      file               : File;
      S                  : ARRAY [0..255] OF CHAR;
      ourfilename,
      filename           : ARRAY [0..80] OF CHAR;
      OurMacroFileName   : ARRAY [0..8] OF CHAR;
      OurMacroFileMedia  : ARRAY [0..56] OF CHAR;
      NameIn,
      NameOut            : ARRAY [0..12] OF CHAR;
      PathIn,
      PathOut            : ARRAY [0..64] OF CHAR;
      macroheader        : AMacroHeaderType;
      MacroRecordPointer : AMacroRecordPointer;
      MacroNode          : ATreeNode;
      ok                 : BOOLEAN;






PROCEDURE DoFileName(): BOOLEAN;

CONST
  
VAR
    DummyDevice             : ARRAY [0..3] OF CHAR;
    DummyPath               : ARRAY [0..3] OF CHAR;
    DummyExtension          : ARRAY [0..5] OF CHAR;

BEGIN                       (* GetFileName *)


    Copy (MacroFileName, NameIn);
    ConcatS (NameIn, FileSpec);
    Copy (MacroFileMedia, PathIn);

    IF GetOutputFile(PathIn, 
                     NameIn, 
                     PathOut, 
                     NameOut,
                     TRUE) THEN
      ParseFileName(NameOut, DummyDevice, DummyPath, OurMacroFileName,
                    DummyExtension);    (* 23-Oct-89 WKH  *)
(*      Copy (NameOut, OurMacroFileName);      (*  LStrings *)*)

      Copy (PathOut, OurMacroFileMedia);     (*  LStrings *)
      RETURN TRUE;
      
    END;

    RETURN FALSE;
    
END DoFileName;




  PROCEDURE SetHeaderRecord (MacroNode  : ATreeNode;
                             VAR Record : AMacroHeaderType);
                             
  BEGIN
    Record.type := headertype;
    MacroRecordPointer :=
       MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
    Record.hotkey := MacroRecordPointer^.hotkey;
    Copy (MacroRecordPointer^.name, Record.name);
    Copy (MacroRecordPointer^.description, Record.description);
    Record.cardlen := MacroRecordPointer^.cardlen;
    Copy (MacroRecordPointer^.hotkeystr, Record.hotkeystr);
    MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
  END SetHeaderRecord;


(*
Saves the macro as:
      (HEADER    : name, hotkey, hotkeystr, description); !!saved elsewhere!!;
      MACRO     : a sequence of cardinals;
      NODE-INFO : a record of relationships
*)

  PROCEDURE SaveMacro (VAR MacroNode : ATreeNode);

  TYPE
      AMacroNodeInfoRecord = RECORD
                               indentation : CARDINAL;
                               attributes  : CARDINAL;
                               reserved    : CARDINAL;
                             END;

  VAR
      macro         : ARRAY [0..MaxKeystrokes] OF CARDINAL;
      numrecs       : CARDINAL;
      MacroNodeInfo : AMacroNodeInfoRecord;

  BEGIN
    (* get the actual macro *)
    MacroRecordPointer :=
    MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
    IF MacroRecordPointer^.cardlen > 0 THEN
      numrecs := GetExtData (MacroRecordPointer^.handle, ADR(macro));
    END;

    (* write out the actual macro *)
    WriteRecord (file, MacRecType, ADR(macro),
                             MacroRecordPointer^.cardlen * 2);
    MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);

    (* get the node information *)
    MacroNodeInfo.indentation :=
                         MacroNode^.Methods^.IndentationLevel (MacroNode);
    MacroNodeInfo.attributes := MacroNode^.Methods^.GetAttributes (MacroNode);

    (* write the node information *)
    MacroNodeInfo.reserved := 0;
    WriteRecord
       (file, nodeinfotype, ADR (MacroNodeInfo), SIZE (MacroNodeInfo));

  END SaveMacro;




  PROCEDURE InitMacroFile ():BOOLEAN;
  BEGIN
    StartFileOutput (file, 5);
    StartSubfileOutput (file, 1, 1);
    RETURN TRUE;
  END InitMacroFile;


  PROCEDURE OpenMacroFile ():BOOLEAN;
  BEGIN
    LStringToTString (filename, filename);
    Delete (filename, file);
    Lookup (file, filename, TRUE);
    IF file.res = done THEN
      RETURN TRUE;
    ELSE
      TStringToLString (filename, filename);
      DisplayFileError (file, filename);
      RETURN FALSE;
    END;
  END OpenMacroFile;



PROCEDURE CloseMacroFile;

BEGIN
    EndSubfileOutput (file, 1);
    EndFileOutput (file);
    Close (file);
END CloseMacroFile;


PROCEDURE SaveAMacro (VAR MacroNode    : ATreeNode;
                          DummyAddress : ADDRESS);

VAR MacroRecordPointer : AMacroRecordPointer;

BEGIN
      MacroRecordPointer :=
           MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
      Message (MacroRecordPointer^.name);
      MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
      SetHeaderRecord (MacroNode, macroheader);
      WriteRecord (file, headertype, ADR(macroheader), SIZE(macroheader));
      SaveMacro (MacroNode);
END SaveAMacro;





  PROCEDURE SaveMacros():BOOLEAN;
  
  VAR
      DummyAddress : ADDRESS;
      Copyright       : ARRAY[0..50] OF CHAR;
      
  BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF NOT OpenMacroFile() THEN RETURN FALSE; END;
    IF NOT InitMacroFile() THEN CloseMacroFile; RETURN FALSE; END;

    MacroNode := MacroTree^.Methods^.GetFirst (MacroTree);

    MacroTree^.Methods^.TraverseTree (MacroTree,ParentBeforeChild,
                                      9999,SaveAMacro,DummyAddress);

    CloseMacroFile;
    RETURN TRUE;
  END SaveMacros;




BEGIN
  FormAccepted := FALSE;
  ok := TRUE;
  LOOP
    IF DoFileName() THEN
      FormAccepted := TRUE;
      TrimRear (OurMacroFileMedia);
      IF OurMacroFileMedia[ORD(OurMacroFileMedia[0])] <> "\" THEN
        ConcatS (OurMacroFileMedia, "\");
      END;
      Copy (OurMacroFileMedia, filename);
      ConcatLS (filename, OurMacroFileName);
      TrimRear (filename);
      ConcatS (filename, FileSpec);
      LStringToTString (filename, ourfilename);
      EXIT;
      
      (*PrepareForIO (file);
      Lookup (file, ourfilename, FALSE);
      IF file.res = done THEN
        Close (file);
        GetMessage (26311, S);
        ConcatLS (S, filename);
        ConcatMessage (S, 26312);
        IF NoYes (S) THEN
          ok := TRUE;
          EXIT;
        END;
      ELSE
        Close (file);
        ok := TRUE;
        EXIT;
      END;*)  

    ELSE
      ok := FALSE;
      EXIT;
    END;
  END; (* loop *)
  IF ok THEN
    IF SaveMacros() THEN
      Copy (OurMacroFileName, LastMacroSaved);
      Copy (OurMacroFileName, MacroFileName);
      Copy (OurMacroFileMedia, MacroFileMedia);
      WriteConfig;
    ELSE
      GetMessage (26313, S);
      Error (S);
    END;
  END;
END MacSave.
