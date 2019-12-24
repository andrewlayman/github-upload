IMPLEMENTATION MODULE MacrosRc;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Modification History -

     3/25/88 - DeleteMacro now removes hotkey from ReplacedKeySet and
               Discards the handle.
     3/28/88 - DeleteMacro cannot remove handle... problem w/ MacroSelect.
     13-Nov-89  RSC - Import from Space rather than Storage.
     15-Dec-89 EGK  - Fixed bug in DisposeMacros.  It was only discarding
                      top-level nodes and ignoring the data objects in all
                      the other nodes.
     19-Dec-89 LVK  - DisposeMacros now uses VAR parameter instead of global
                      MacroTree in order to delete subtrees.
     20-Dec-89 LVK  - Created new PROC ClearMacNode to be used when
                      replacing the contents of a macro.
     20-Mar-90 RSC  - Removed "AProcessingProcContext" from global memory.
                      made it local to the procedures that need it.
*)

FROM Codes                  IMPORT SetCodeBits;

FROM Dialog                 IMPORT
                                WarningBox, ADialogOption, Error;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Compare, CtoS, ConcatLS, SetString,
                                ConcatS, Copy;
                                
FROM FlexStor               IMPORT DiscardExtObject, CreateExtObject,
                                   AnExtHandle, SetExtData;                                

FROM MacNodes               IMPORT AMacroRecordPointer,
                                   MacroTree;

FROM MacTalk                IMPORT MacDeath;

FROM MacVars                IMPORT ReplacedKeySet, MacStoragePreference;    

FROM Schedule               IMPORT
    (* VAR  *)                  ScheduleSaved;

FROM Space                  IMPORT Available;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;
    
FROM SYSTEM                 IMPORT ADDRESS, ADR, SIZE;    
(*
FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;
*)

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree, ATreeOrder,
    (* PROC *)                  CreateTreeNode, ValidateTree;



CONST
    MAXCARDINAL             = 0FFFFH;
    MacroTag                = 7653;
(*    ModuleNumber            = 37919;  *)

(* new record: 10/26/88 *)
TYPE
    AMacroPointer       = POINTER TO AMacroHandle;

    AMacroHandle        = RECORD
                            handle : AnExtHandle; (* holds MacroRecord *)
                          END;

    AProcessingProcContext = RECORD
                                 hotkey : CARDINAL;
                                 name   : ARRAY [0..40] OF CHAR;
                                 node   : ATreeNode;
                             END;


VAR
    i                       : CARDINAL;

    (* for debugging - 1/17/88
    S,
    title,
    str                    : ARRAY [0..80] OF CHAR;
    segstr,
    offstr                 : ARRAY [0..12] OF CHAR;
    address                : ADDRESS;*)

(*----------------------------------------------------------------------------
    MacroDefaults --

    Give the macro record default values.
----------------------------------------------------------------------------*)

PROCEDURE MacroDefaults(VAR Macro         : ATreeNode);

VAR
    MacroRecordPointer         : AMacroRecordPointer;

BEGIN                       (* MacroDefaults *)

    MacroRecordPointer := Macro^.Methods^.LockFlexStorDataObject (Macro);
    
    MacroRecordPointer^.tag         := MacroTag;
    MacroRecordPointer^.hotkey      := 0;
    Fill (MacroRecordPointer^.hotkeystr, " ", 9);
    Fill (MacroRecordPointer^.name, " ", 40);
    Fill (MacroRecordPointer^.description, " ", 49);
    MacroRecordPointer^.cardlen     := 0;
    
    Macro^.Methods^.UnlockFlexStorDataObject (Macro);


END MacroDefaults;


(*-----------------------------------------------------------------------

A TreeNodeProcessingProc. Used by FindMacroByName.

-------------------------------------------------------------------------*)

PROCEDURE FindAMacroByName (VAR Node                  : ATreeNode;
                                ProcessingProcContext : ADDRESS );
VAR
    MacroRecordPointer       : AMacroRecordPointer;
    OurProcessingProcContext : POINTER TO AProcessingProcContext;
BEGIN

      OurProcessingProcContext := ProcessingProcContext;
      MacroRecordPointer := Node^.Methods^.LockFlexStorDataObject (Node);

      IF (Compare (MacroRecordPointer^.name,
                            OurProcessingProcContext^.name) = 0) THEN
          Node^.Methods^.UnlockUnchangedDataObject (Node);
          OurProcessingProcContext^.node := Node;
      END;

      Node^.Methods^.UnlockUnchangedDataObject (Node);
      
END FindAMacroByName;
 

(*----------------------------------------------------------------------------
    FindMacroByName --

    Look up the macro name given in the group of all macros, and return a
    pointer to that macro if it's found.  Else return NIL.

    Expects an LString.
----------------------------------------------------------------------------*)

PROCEDURE FindMacroByName(VAR MacroName   : ARRAY OF CHAR)       (* in     *)
                                                                : ATreeNode;

VAR
    Node                    : ATreeNode;
    ProcessingProcContext   : AProcessingProcContext;


   

BEGIN                       (* FindMacroByName *)

    ProcessingProcContext.node := NIL;
    Copy (MacroName, ProcessingProcContext.name);
    ValidateTree (MacroTree);

    Node := MacroTree^.Methods^.GetFirst (MacroTree);

    MacroTree^.Methods^.TraverseTree (MacroTree, ParentBeforeChild,
                       9999,FindAMacroByName, ADR(ProcessingProcContext));
                                      
    RETURN ProcessingProcContext.node;

END FindMacroByName;




(*-----------------------------------------------------------------------

A TreeNodeProcessingProc. Used by FindMacroByHotkey.

-------------------------------------------------------------------------*)

PROCEDURE FindAMacroByHotkey  (VAR Node               : ATreeNode;
                                ProcessingProcContext : ADDRESS);
VAR
    MacroRecordPointer       : AMacroRecordPointer;
    OurProcessingProcContext : POINTER TO AProcessingProcContext;                                
BEGIN

      OurProcessingProcContext := ProcessingProcContext;
      MacroRecordPointer := Node^.Methods^.LockFlexStorDataObject (Node);

      IF MacroRecordPointer^.hotkey = OurProcessingProcContext^.hotkey THEN
          Node^.Methods^.UnlockUnchangedDataObject (Node);
          OurProcessingProcContext^.node := Node;
      END;

      Node^.Methods^.UnlockUnchangedDataObject (Node);
      
END FindAMacroByHotkey;
 
(*----------------------------------------------------------------------------
    
    FindMacroByHotkey --

    Look up the macro name given in the group of all macros, and return a
    pointer to that macro if it's found.  Else return NIL.
----------------------------------------------------------------------------*)

PROCEDURE FindMacroByHotkey(VAR MacroHotkey   : CARDINAL)       (* in     *)
                                                                : ATreeNode;

VAR
    Node                    : ATreeNode;
    ProcessingProcContext   : AProcessingProcContext;

BEGIN                       (* FindMacroByName *)
(*
    Node := MacroTree^.Methods^.GetFirst (MacroTree);

    WHILE (Node <> NIL) DO
        MacroRecordPointer := Node^.Methods^.LockFlexStorDataObject (Node);
        IF (MacroRecordPointer^.hotkey = MacroHotkey) THEN
          Node^.Methods^.UnlockUnchangedDataObject (Node);
          RETURN Node;
        END;
        Node^.Methods^.UnlockUnchangedDataObject (Node);
        Node := Node^.Methods^.GetNext (Node);
    END;

    RETURN NIL;
*)

    ProcessingProcContext.node := NIL;
    ProcessingProcContext.hotkey := MacroHotkey;
    ValidateTree (MacroTree);

    Node := MacroTree^.Methods^.GetFirst (MacroTree);

    MacroTree^.Methods^.TraverseTree (MacroTree, ParentBeforeChild,
                       9999,FindAMacroByHotkey, ADR(ProcessingProcContext));
                                      
    RETURN ProcessingProcContext.node;


END FindMacroByHotkey;






PROCEDURE FindMacro (VAR Hotkey   : CARDINAL;
                     VAR Name     : ARRAY OF CHAR): ATreeNode;

VAR
    Node : ATreeNode;

BEGIN
  Node := FindMacroByName (Name);
  IF ((Node = NIL) AND (Hotkey <> 0)) THEN
    Node := FindMacroByHotkey (Hotkey);
  END;
  RETURN Node;
END FindMacro;







PROCEDURE CompareMacros (Node1, Node2: ATreeNode): INTEGER;
VAR
     MacroRecordPointer             : AMacroRecordPointer;
     name1, name2                   : ARRAY [0..40] OF CHAR;
BEGIN
    MacroRecordPointer := Node1^.Methods^.LockFlexStorDataObject (Node1);
    Copy (MacroRecordPointer^.name, name1);
    Node1^.Methods^.UnlockUnchangedDataObject (Node1);
    MacroRecordPointer := Node2^.Methods^.LockFlexStorDataObject (Node2);
    Copy (MacroRecordPointer^.name, name2);
    Node2^.Methods^.UnlockUnchangedDataObject (Node2);
    RETURN Compare (name1, name2);
END CompareMacros;




(*----------------------------------------------------------------------------
    SortMacros --

    Place the macro list into ascending alphabetical order.
    
    Currently not used, so is commented out. (Outline structure used.)
----------------------------------------------------------------------------*)

PROCEDURE SortMacros();

VAR
    Node, NextNode, TempNode    : ATreeNode;

BEGIN                       (* SortMacros *)

    (*  Use an insertion sort on the macros, because it's easy to swap
        items on a linked list.  Also, since only one item is added at a
        time to the end of the (already sorted) list, this will place the 
        new macro into the correct order with only one swap.
    *)
(*
    Node := MacroTree^.Methods^.GetFirst (MacroTree);
    IF (Node <> NIL) THEN
        NextNode := Node^.Methods^.GetNext (Node);
        WHILE (NextNode <> NIL) DO
            IF (CompareMacros (NextNode, Node) < 0) THEN
                TempNode := Node^.Methods^.GetPrev (Node);
                WHILE ((TempNode <> NIL) AND
                        (CompareMacros (NextNode, TempNode) < 0)) DO
                    TempNode := TempNode^.Methods^.GetPrev (TempNode);
                END;
                NextNode^.Methods^.DeList (NextNode);
                IF (TempNode = NIL) THEN
                    MacroTree^.Methods^.AddFirst (MacroTree, NextNode);
                ELSE
                    TempNode^.Methods^.AddAfter (TempNode, NextNode);
                END;
            ELSE
                Node := NextNode;
            END;
            NextNode := Node^.Methods^.GetNext (Node);
        END;
    END;
*)
END SortMacros;


(*-------------------------------------------------------------------------
New PROC 20-Dec-89 LVK
Creates the data objects for a newly created node.
Taken out of CreateMacro.
Used in CreateMacro & ClearMacNode.
-------------------------------------------------------------------------*)


PROCEDURE CreateDataObjects (VAR Node : ATreeNode):BOOLEAN;

VAR
    MacroRecordPointer        : AMacroRecordPointer;
    handle                    : AnExtHandle;

BEGIN
    IF Available (SIZE(MacroRecordPointer)) THEN
      NEW (MacroRecordPointer);
      IF (MacroRecordPointer <> NIL) THEN
          
        IF NOT ((CreateExtObject (handle, MacStoragePreference)) AND
                (CreateExtObject (MacroRecordPointer^.handle,
                                          MacStoragePreference)) AND
                (SetExtData (handle, MacroRecordPointer,
                                          SIZE (MacroRecordPointer^)))) THEN
          DISPOSE (MacroRecordPointer);
          Node^.Methods^.Discard (Node);
          Node := NIL;
          MacDeath;
          RETURN FALSE;
        END;  
        Node^.Methods^.SetDataObject (Node, ADDRESS(handle));
        MacroDefaults (Node);
        DISPOSE (MacroRecordPointer);
        RETURN TRUE;
      END;
    END;
    RETURN FALSE;
END CreateDataObjects;





(*-------------------------------------------------------------------------
New PROC - 20-Dec-89 LVK

Prerequisite - A valid macro node in the macro tree.

Result - Node remains, but data objects are deleted and replaced with
         blank data objects, ready for new contents.
-------------------------------------------------------------------------*)


PROCEDURE ClearMacNode (VAR Node : ATreeNode):BOOLEAN;
BEGIN
   DeleteDataObjects(Node);
   IF NOT CreateDataObjects(Node) THEN
     Node^.Methods^.Discard (Node);
     Node := NIL;
     RETURN FALSE;
   END;
   RETURN TRUE;
END ClearMacNode;


(*-------------------------------------------------------------------------
Creates a new node with blank data objects.

11/4/88 - Each macro requires 40 bytes.
--------------------------------------------------------------------------*)

PROCEDURE CreateMacro (VAR Node    : ATreeNode)
                                                    : BOOLEAN;
BEGIN
   IF NOT CreateTreeNode (Node) THEN RETURN FALSE; END;
   IF NOT CreateDataObjects(Node) THEN
     Node^.Methods^.Discard (Node);
     Node := NIL;
     RETURN FALSE;
   END;
   RETURN TRUE;
END CreateMacro;





(*------------------------------------------------------------------------
New PROC 20-Dec-89 LVK
Taken out of DeleteMacro.
Used in DeleteMacro & ClearMacNode.
--------------------------------------------------------------------------*)

PROCEDURE DeleteDataObjects (VAR Node : ATreeNode);

VAR
    MacroRecordPointer : AMacroRecordPointer;
    handle             : AnExtHandle;

BEGIN
    MacroRecordPointer := Node^.Methods^.LockFlexStorDataObject (Node);
    CheckTag (MacroRecordPointer);
    DiscardExtObject (MacroRecordPointer^.handle);
    Node^.Methods^.UnlockFlexStorDataObject (Node);
    SetCodeBits (ReplacedKeySet, GetMacroHotKey (Node),
                                 GetMacroHotKey (Node), FALSE);
    handle := AnExtHandle(Node^.Methods^.GetDataObject (Node));
    DiscardExtObject (handle);
END DeleteDataObjects;




PROCEDURE DeleteMacro (VAR Node    : ATreeNode);
BEGIN
    DeleteDataObjects (Node);
    Node^.Methods^.Discard (Node);
    Node := NIL;
END DeleteMacro;



PROCEDURE DeleteProc (  VAR Node    : ATreeNode;
                            Context : ADDRESS   );
BEGIN
    DeleteMacro (Node);
END DeleteProc;



PROCEDURE DisposeMacros (VAR Tree      : ATree);
BEGIN
        (*  Do a full tree traversal to catch all the nodes  -- 12/15/89 EGK *)
    Tree^.Methods^.TraverseTree (Tree, ParentAfterChild,
                                 9999, DeleteProc, NIL         );
END DisposeMacros;



PROCEDURE CheckTag (VAR OurMacroRecordPointer : AMacroRecordPointer);

VAR S : ARRAY [0..80] OF CHAR;

BEGIN
  IF (OurMacroRecordPointer^.tag <> MacroTag) THEN
    MacDeath;
  END;
END CheckTag;



PROCEDURE SetMacroHotKey (VAR MacroNode : ATreeNode;
                              HotKey    : CARDINAL);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  MacroRecordPointer^.hotkey := HotKey;
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroHotKey;



PROCEDURE GetMacroHotKey (VAR MacroNode : ATreeNode):CARDINAL;
VAR
    MacroRecordPointer : AMacroRecordPointer;
    hotkey             : CARDINAL;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  hotkey := MacroRecordPointer^.hotkey;
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
  RETURN hotkey;
END GetMacroHotKey;



PROCEDURE SetMacroHotKeyStr (VAR MacroNode : ATreeNode;
                                 HotKeyStr : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (HotKeyStr, MacroRecordPointer^.hotkeystr);
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroHotKeyStr;


PROCEDURE GetMacroHotKeyStr (VAR MacroNode : ATreeNode;
                             VAR HotKeyStr : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;

BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (MacroRecordPointer^.hotkeystr, HotKeyStr);
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
END GetMacroHotKeyStr;



PROCEDURE SetMacroName (VAR MacroNode : ATreeNode;
                            Name      : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (Name, MacroRecordPointer^.name);
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroName;


PROCEDURE GetMacroName (VAR MacroNode : ATreeNode;
                        VAR Name      : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;

BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (MacroRecordPointer^.name, Name);
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
END GetMacroName;



PROCEDURE SetMacroDescription (VAR MacroNode   : ATreeNode;
                                   Description : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (Description, MacroRecordPointer^.description);
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroDescription;



PROCEDURE GetMacroDescription (VAR MacroNode   : ATreeNode;
                               VAR Description : ARRAY OF CHAR);
VAR
    MacroRecordPointer : AMacroRecordPointer;

BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  Copy (MacroRecordPointer^.description, Description);
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
END GetMacroDescription;



PROCEDURE SetMacroHandle (VAR MacroNode   : ATreeNode;
                              Handle      : AnExtHandle);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  MacroRecordPointer^.handle := Handle;
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroHandle;



PROCEDURE GetMacroHandle (VAR MacroNode : ATreeNode):AnExtHandle;
VAR
    MacroRecordPointer : AMacroRecordPointer;
    handle             : AnExtHandle;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  handle := MacroRecordPointer^.handle;
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
  RETURN handle;
END GetMacroHandle;



PROCEDURE SetMacroLength (VAR MacroNode : ATreeNode;
                              Length    : CARDINAL);
VAR
    MacroRecordPointer : AMacroRecordPointer;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  MacroRecordPointer^.cardlen := Length;
  MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
END SetMacroLength;



PROCEDURE GetMacroLength (VAR MacroNode : ATreeNode):CARDINAL;
VAR
    MacroRecordPointer : AMacroRecordPointer;
    length             : CARDINAL;
BEGIN
  MacroRecordPointer := MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
  CheckTag (MacroRecordPointer);
  length := MacroRecordPointer^.cardlen;
  MacroNode^.Methods^.UnlockUnchangedDataObject (MacroNode);
  RETURN length;
END GetMacroLength;




END MacrosRc.
