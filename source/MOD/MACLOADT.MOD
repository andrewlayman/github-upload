IMPLEMENTATION MODULE MacLoadTools;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Loads macros from disk into memory.

   Modifications - 1/27/88 : changed macro to MacPointer in order to
                             move the variable into the heap.
     13-Nov-89  RSC - Import from Space rather than Storage.
     19_Dec-89  LVK - Changed name of ReplaceMacro to DoReplaceMacro
     20-Dec-89  LVK - Replacing macros uses existing node.
     23-Jan-91  RSC - Remove LoadComm reference.
*)

FROM Codes        IMPORT SetCodeBits;

FROM Dialog       IMPORT Error, Message, ADialogOption,
                         MultipleChoiceBox;

FROM Direct411    IMPORT GiveDirectoryAssistance, AlwaysApprove;

FROM FileAux      IMPORT DisplayFileError, CheckIO;
                         
FROM FileOpen     IMPORT RequestFileOpen;

FROM FileSystem   IMPORT File, Lookup, Close, Response;

FROM LStrings     IMPORT SetString, ConcatS, Copy, LStringToTString, TrimRear,
                         CtoS, ConcatLS, TStringToLString, LengthOf;

FROM MacBuffs     IMPORT MaxKeystrokes;

FROM MacHeader    IMPORT
                         AMacroHeaderType, MacHeaderStack,
                         PushMacHeaderStack, PopMacHeaderStack;
                         
FROM MacStore     IMPORT StoreMacro, StoreReplacementMacro;

FROM MacTalk      IMPORT MacDeath;                         

FROM MacVars      IMPORT LastMacroSaved, MacroFileMedia, FileSpec,
                         MacStoragePreference, ReplacedKeySet;

FROM MsgFile      IMPORT GetMessage, ConcatMessage;

FROM RecordIO     IMPORT ReadRecord, ReadString, ReadRecordPreface,
                         ReadRecordBody, ReadStringBody;

FROM Schedule     IMPORT ProjectName, ProjectMedia;

FROM Space        IMPORT HeapAvailable, Available;

FROM Space        IMPORT ALLOCATE, DEALLOCATE;

FROM Subfiles     IMPORT StartFileInput, StartSubfileInput;

FROM SYSTEM       IMPORT ADR, WORD, SIZE, ADDRESS;

FROM TreeObjects  IMPORT ATree, ATreeNode;

FROM MacrosRc     IMPORT
                         CreateMacro,
                         FindMacro, ClearMacNode;
(* 
   pick a file,
   open the file,
   read in the macros to ext. storage,
   create a list of macros with handles.
*)

   TYPE MacPointer = POINTER TO ARRAY [0..MaxKeystrokes] OF CARDINAL;

        AMacInfoRecord = RECORD
                           indentation : CARDINAL;
                           attributes  : CARDINAL;
                           reserved    : CARDINAL;
                         END;
                         
  CONST header         = 1;
        body           = 2;
        info           = 3;
        eof            = 0FFH;
        MacroSubfile   = 1;


VAR 
    S, S2              : ARRAY [0..255] OF CHAR;
    file               : File;
    record             : AMacroHeaderType;
    title              : ARRAY [0..31] OF CHAR;
    prefix             : ARRAY [0..10] OF CHAR;
    menustr            : ARRAY [0..255] OF CHAR;
    Template           : ARRAY [0..64] OF CHAR;
    lastfilesaved      : ARRAY [0..20] OF CHAR;
    projectname        : ARRAY [0..8] OF CHAR;
    projectmedia       : ARRAY [0..80] OF CHAR;
    selection          : CARDINAL;
    MacroNode          : ATreeNode;
    InfoRecord         : AMacInfoRecord;


PROCEDURE PickMacroFile (VAR template : ARRAY OF CHAR):BOOLEAN;

BEGIN
  GetMessage (26415, title);
  TrimRear (MacroFileMedia);
  IF ((MacroFileMedia[ORD(MacroFileMedia[0])] <> "\") AND
      (LengthOf(MacroFileMedia) <> 0)) THEN
    ConcatS (MacroFileMedia, "\");
  END;
  Copy (MacroFileMedia, template);
  ConcatS (template, "*");
  ConcatS (template, FileSpec);
  Copy (LastMacroSaved, lastfilesaved);

  IF GiveDirectoryAssistance (5, 20, title, template, lastfilesaved,
                              AlwaysApprove) THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END PickMacroFile;


(* Returns true iff the record is of the proper type *)

PROCEDURE ReadHeaderRecord (VAR file   : File;
                            VAR record : AMacroHeaderType)(*:BOOLEAN*);
VAR
    type : CARDINAL;

BEGIN
  ReadRecordBody (file, SIZE(record), ADR(record), SIZE(record));
  (*IF type <> header THEN RETURN FALSE; END;*)
  (*RETURN TRUE;*)
END ReadHeaderRecord;


PROCEDURE CopyRecordToMacHeaderStack (VAR OurRecord : AMacroHeaderType);

BEGIN
  MacHeaderStack^.record.hotkey := OurRecord.hotkey;
  Copy (OurRecord.hotkeystr, MacHeaderStack^.record.hotkeystr);
  Copy (OurRecord.name, MacHeaderStack^.record.name);
  Copy (OurRecord.description, MacHeaderStack^.record.description);
  MacHeaderStack^.record.cardlen := OurRecord.cardlen;
END CopyRecordToMacHeaderStack;



PROCEDURE OpenMacroFile (VAR file      : File;
                         VAR MacroFile : ARRAY OF CHAR):BOOLEAN;

BEGIN                         
    LStringToTString (MacroFile, MacroFile);
    Lookup (file, MacroFile, FALSE);
    IF file.res <> done THEN
      TStringToLString (MacroFile, MacroFile);
      DisplayFileError (file, MacroFile);
      Close (file);
      RETURN FALSE;
    END;
    RETURN TRUE;
END OpenMacroFile;


  PROCEDURE LoadMacros ( MacroFile      : ARRAY OF CHAR;
                         VAR AMacroTree : ATree;
                         AutoReplace    : BOOLEAN):BOOLEAN;

  VAR
      macro         : MacPointer;
      Junk,
      i             : INTEGER;
      type,
      RecordType,
      RecordLength,
      Replace,
      version       : CARDINAL;
      ok            : BOOLEAN;



     PROCEDURE InitializeMacroArray():BOOLEAN;
     BEGIN
       IF Available (SIZE(macro^))THEN
          NEW (macro);
          RETURN TRUE;
        ELSE
          GetMessage (26416, S);
          Error (S);
          Close (file);
          RETURN FALSE;
        END;
      END InitializeMacroArray;


     PROCEDURE GetMacro (VAR OurMacroNode : ATreeNode);
     
     BEGIN
          ReadRecordBody (file, record.cardlen*2, macro, record.cardlen*2);
          CopyRecordToMacHeaderStack (record);
          OurMacroNode := FindMacro (record.hotkey, record.name);
     END GetMacro;


     PROCEDURE CreateAndStoreMacro (VAR OurMacroNode : ATreeNode):BOOLEAN;
     BEGIN
        IF NOT CreateMacro (OurMacroNode) THEN
           MacDeath;
           RETURN FALSE;
         END;
        IF NOT StoreMacro (macro^, record.cardlen,
                           OurMacroNode, NIL, AMacroTree) THEN
          GetMessage (26417, S);
          Error (S);
          DISPOSE (macro);
          RETURN FALSE;
        END;
        RETURN TRUE;
      END CreateAndStoreMacro;


      PROCEDURE DoReplaceMacro ():BOOLEAN;
      
      BEGIN
        GetMessage (26418, title);
        Copy (record.name, S);
        TrimRear (S);
        ConcatMessage (S, 26419);
        GetMessage (26420, prefix);
        GetMessage (26421, menustr);
        selection := 1;
        IF MultipleChoiceBox(S,title,NoHelp,prefix,menustr,selection) THEN
          RETURN selection = 1;
        ELSE
          RETURN FALSE;
        END;
      END DoReplaceMacro;


  BEGIN (* LoadMacros *)
  
    Replace := 0;
    ok := TRUE;

    IF NOT InitializeMacroArray() THEN RETURN FALSE; END;

    PushMacHeaderStack;
    
    IF NOT OpenMacroFile (file, MacroFile) THEN RETURN FALSE; END;
    
    IF NOT (StartFileInput (file) AND
           StartSubfileInput (file, MacroSubfile, version)) THEN
      GetMessage (26422, S);
      Error (S);
      Close (file);
      RETURN FALSE;
    END;
    
    LOOP
      ReadRecordPreface (file, RecordType, RecordLength);
      IF (CheckIO (file) <> done) THEN DISPOSE (macro); EXIT; END;
      CASE RecordType OF
        header :
                 ReadHeaderRecord (file, record)|
        body   :
                 GetMacro (MacroNode);
                 IF MacroNode = NIL THEN
                     ok := CreateAndStoreMacro (MacroNode);
                 ELSIF AutoReplace THEN
                     ok := ((ClearMacNode (MacroNode)) AND
                            (StoreReplacementMacro (macro^, record.cardlen,
                                                  MacroNode)));
                     (*DeleteMacro (MacroNode);
                     ok := CreateAndStoreMacro (MacroNode);*)
                 ELSE  
                     LOOP
                       IF  DoReplaceMacro() THEN
                         ok := ((ClearMacNode (MacroNode)) AND
                         StoreReplacementMacro (macro^, record.cardlen,
                                                      MacroNode));
                         (*DeleteMacro (MacroNode);
                         ok := CreateAndStoreMacro (MacroNode);*)
                         EXIT;
                       END;
                       INC (Replace);
                       EXIT;
                     END;
                 END|
        info   : 
                 ReadRecordBody (file, SIZE (InfoRecord), ADR(InfoRecord), SIZE (InfoRecord));
                 IF Replace = 0 THEN
                   MacroNode^.Methods^.SetAttributes
                                     (MacroNode, InfoRecord.attributes);
                   FOR i := 1 TO InfoRecord.indentation DO
                     MacroNode^.Methods^.Demote (MacroNode);
                   END;
                   INC (Replace);
                 END;
                 DEC (Replace)|
        eof    :
                 DISPOSE (macro);
                 EXIT;
      ELSE
          ReadRecordBody(file,RecordLength,ADR(Junk),0);
      END; (* CASE *)
      IF NOT ok THEN DISPOSE (macro); EXIT; END;
    END; (* LOOP *)
     
    Close (file);
    PopMacHeaderStack;

    RETURN ok;
    
  END LoadMacros;


END MacLoadTools.
