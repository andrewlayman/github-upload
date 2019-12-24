IMPLEMENTATION MODULE MacStore;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

(*
MODIFICATION HISTORY

	20-Dec-89 LVK - Added PROC StoreReplacementMacro for replacement
	                of a macro in an existing node on the macro tree.

*)


FROM Codes            IMPORT SetCodeBits;

FROM FlexStor         IMPORT SetExtData;

FROM LStrings         IMPORT Copy;

FROM MacHeader        IMPORT MacHeaderStack;

FROM MacNodes         IMPORT MacroTree, AMacroRecordPointer;

FROM MacVars          IMPORT ReplacedKeySet, MacStoragePreference;

FROM SYSTEM           IMPORT ADR;

FROM TreeObjects      IMPORT ATree, ATreeNode;


PROCEDURE FillMacroRecord (VAR MacroRecordPointer : AMacroRecordPointer;
                               length             : CARDINAL);

                               

    BEGIN
      MacroRecordPointer^.hotkey := MacHeaderStack^.record.hotkey;
      IF MacroRecordPointer^.hotkey <> 0 THEN
         SetCodeBits (ReplacedKeySet, MacroRecordPointer^.hotkey,
                                  MacroRecordPointer^.hotkey, TRUE);
      END;
      Copy (MacHeaderStack^.record.hotkeystr, MacroRecordPointer^.hotkeystr);
      Copy (MacHeaderStack^.record.name, MacroRecordPointer^.name);
      Copy (MacHeaderStack^.record.description, MacroRecordPointer^.description);
      MacroRecordPointer^.cardlen := length;
    END FillMacroRecord;




PROCEDURE InsertNode (VAR MacroNode : ATreeNode;
                      VAR WhereNode : ATreeNode;
                      VAR AMacroTree : ATree);

BEGIN
   IF AMacroTree^.Methods^.GetFirst (AMacroTree) = NIL THEN
     AMacroTree^.Methods^.AddFirst (AMacroTree, MacroNode);
   ELSIF WhereNode <> NIL THEN
     WhereNode^.Methods^.AddAfter (WhereNode, MacroNode);
   ELSE
     AMacroTree^.Methods^.AddLast (AMacroTree, MacroNode);
   END;
END InsertNode;




PROCEDURE SetDataObjects (VAR MacroNode : ATreeNode;
                          VAR Length    : CARDINAL;
                          VAR ABuffer   : ARRAY OF CARDINAL):BOOLEAN;
VAR
     MacroRecordPointer : AMacroRecordPointer;                       
     ok                 : BOOLEAN;

BEGIN;
      ok := TRUE;
      MacroRecordPointer :=
         MacroNode^.Methods^.LockFlexStorDataObject (MacroNode);
      IF NOT SetExtData (MacroRecordPointer^.handle,
                         ADR(ABuffer), Length*2) THEN
        ok := FALSE;
      END;
      FillMacroRecord (MacroRecordPointer, Length);
      MacroNode^.Methods^.UnlockFlexStorDataObject (MacroNode);
      RETURN ok;
END SetDataObjects;



(* -----------------------------------------------------------------------

Prerequisites:

      Valid MacroNode created by CreateMacro.
      MacHeaderStack has been Pushed.
      Length is the number of CARDINALS in the macro.

      WhereNode can be NIL.

----------------------------------------------------------------------- *)



PROCEDURE StoreMacro (VAR ABuffer            : ARRAY OF CARDINAL;
                      VAR Length             : CARDINAL;
                      VAR MacroNode          : ATreeNode;
                          WhereNode          : ATreeNode;
                      VAR AMacroTree         : ATree)
                      :BOOLEAN;

BEGIN
   InsertNode (MacroNode, WhereNode, AMacroTree);
   RETURN SetDataObjects (MacroNode, Length, ABuffer);
END StoreMacro;


(*------------------------------------------------------------------------
New PROC 20-Dec-89

Prerequisite - A valid macro node already placed in the tree

Result       - The node with filled data objects.
------------------------------------------------------------------------*)

PROCEDURE StoreReplacementMacro (VAR ABuffer            : ARRAY OF CARDINAL;
                                 VAR Length             : CARDINAL;
                                 VAR MacroNode          : ATreeNode)
                                :BOOLEAN;
BEGIN
   RETURN SetDataObjects (MacroNode, Length, ABuffer);
END StoreReplacementMacro; 


END MacStore.
