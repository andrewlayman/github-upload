IMPLEMENTATION MODULE MacBuffs;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
     13-Nov-89  RSC - Import from Space rather than Storage.

---------------------------------------------------------------------------*)





FROM FlexStor IMPORT SetExtData;

FROM LStrings IMPORT SetString, LengthOf;

FROM MacHeader IMPORT PushMacHeaderStack, PopMacHeaderStack;

FROM MacNodes IMPORT EditRecordPointer, EditMacro;

FROM MacStack IMPORT MacStack, PushMacro;

FROM MacState IMPORT AState, PushState;

FROM MacStrings IMPORT MacMenuPtr, MacMessagePtr;

FROM MacTalk  IMPORT MacDeath, MacError;

FROM MacVars  IMPORT Editing;

FROM MsgFile  IMPORT GetMessage;

FROM Space    IMPORT Available;

FROM Space    IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM   IMPORT SIZE, ADR;

CONST
    MacBufferTag   = 761;
    NameCode       = 1000;


    PROCEDURE PushBuffer():BOOLEAN;

    VAR
        P : AMacBufferPtr;

    BEGIN
      IF Available (SIZE(P^)) THEN
        NEW (P);
      ELSE
        RETURN FALSE;
      END;
      P^.tag := MacBufferTag;
      P^.count := 0;
      IF MacBuffer <> NIL THEN
        MacBuffer^.prev := P;
        P^.next := MacBuffer;
      ELSE
        P^.next := NIL;
      END;
      P^.prev := NIL;
      MacBuffer := P;
      RETURN TRUE;
    END PushBuffer;


    PROCEDURE PopBuffer;

    VAR
        P : AMacBufferPtr;
        
    BEGIN
      IF MacBuffer = NIL THEN 
        RETURN;
      END;
      P := MacBuffer;
      MacBuffer := MacBuffer^.next;
      IF MacBuffer <> NIL THEN
        MacBuffer^.prev := NIL;
      END;
      DISPOSE (P);
   END PopBuffer;


(*------------------------------------------------------------------------

Check for available room in buffer.  How to check for cases when a cardinal
code is inserted ok before a string that can't be inserted?  Must be done in
the calling procedure that inserted the code. 
 
-------------------------------------------------------------------------*)

PROCEDURE MacBuffAvailable (amount : CARDINAL):BOOLEAN;

VAR
    S : ARRAY [0..80] OF CHAR;
    
BEGIN
 
  IF ((MacBuffer^.count + amount) >= (MaxKeystrokes)) THEN
    GetMessage (26377, S);
    MacError (S);
    RETURN FALSE;
  END;
  RETURN TRUE;
  
END MacBuffAvailable;





(*------------------------------------------------------------------------

Puts a string into a macro that is currently being recorded.  Used to
insert messages and menus that were created with the Add Menu.

-------------------------------------------------------------------------*)

PROCEDURE PutStrInBuffer (str  : ARRAY OF CHAR):BOOLEAN;

VAR 
    i   : CARDINAL;

BEGIN

  IF MacBuffer = NIL THEN RETURN FALSE; END;

  IF MacBuffAvailable(LengthOf(str)) THEN
    FOR i := 1 TO ORD(str[0]) DO
      IF  (
          ((ORD(str[i]) = 123) OR
          (ORD(str[i]) = 125)) AND
          (NOT Editing)) THEN
        MacBuffer^.buffer[MacBuffer^.count] := NameCode;
      ELSE;
        MacBuffer^.buffer[MacBuffer^.count] := ORD(str[i]);
      END;
      INC (MacBuffer^.count);
    END;
    RETURN TRUE;
  END;
  RETURN FALSE;
END PutStrInBuffer;




(*------------------------------------------------------------------------

Inserts a cardinal into a macro that is currently being recorded.  Used to
insert sentinal values before and after messages and menus.

-------------------------------------------------------------------------*)

PROCEDURE PutCodeInBuffer (code : CARDINAL):BOOLEAN;
BEGIN

  IF MacBuffer = NIL THEN RETURN FALSE; END;

  IF ((code = 65432) OR (MacBuffAvailable (1)))THEN
    IF code <> 0 THEN
      MacBuffer^.buffer[MacBuffer^.count] := code;
      INC (MacBuffer^.count);
    END;
    RETURN TRUE;
  END;
  RETURN FALSE;

END PutCodeInBuffer;



  (*------------------------------------------------------------------------

  Puts a menu that was created with the menu form into the edited macro.

  -------------------------------------------------------------------------*)

PROCEDURE PutMenuInBuffer():BOOLEAN;
VAR
    oldcount : CARDINAL;
    ok       : BOOLEAN;
    
BEGIN
  oldcount := MacBuffer^.count;
  ok := TRUE;
  IF NOT PutStrInBuffer (MacMenuPtr^.Title) THEN ok := FALSE; END;
  IF NOT PutStrInBuffer (MacMenuPtr^.Message) THEN ok := FALSE; END;
  IF NOT PutStrInBuffer (MacMenuPtr^.Prefix) THEN ok := FALSE; END;
  IF NOT PutStrInBuffer (MacMenuPtr^.Choices) THEN ok := FALSE; END;
  IF NOT PutStrInBuffer (MacMenuPtr^.Macros) THEN ok := FALSE; END;
  IF NOT ok THEN MacBuffer^.count := oldcount; END;
  RETURN ok;
END PutMenuInBuffer;





  (*------------------------------------------------------------------------

  Puts the message that was created with the message form into the edited macro.

  -------------------------------------------------------------------------*)

PROCEDURE PutMessageInBuffer():BOOLEAN;
CONST Separator = 124;
VAR
    oldcount : CARDINAL;
    ok       : BOOLEAN;
BEGIN
  oldcount := MacBuffer^.count;
  ok := TRUE;
  IF NOT PutStrInBuffer (MacMessagePtr^.Title) THEN ok := FALSE; END;
  IF NOT PutCodeInBuffer (Separator) THEN ok := FALSE; END;
  IF NOT PutStrInBuffer (MacMessagePtr^.Message) THEN ok := FALSE; END;
  IF NOT ok THEN MacBuffer^.count := oldcount; END;
  RETURN ok;
END PutMessageInBuffer;


    
(*------------------------------------------------------------------------

 Put the buffer's contents into a macro, ready for playback in editor.
 Used to put extended character strings, control character strings,
 messages and menus into the editted macros.

 Prerequisite : a valid buffer has been created with PushBuffer,

-------------------------------------------------------------------------*)

PROCEDURE PlayBuffer;

VAR i : CARDINAL;

BEGIN

    PushMacHeaderStack;   (* Create new record for macro on the stack *)

    FOR i := 0 TO 1 DO    (* add two sentinals *)
      MacBuffer^.buffer[MacBuffer^.count] := 65432;
      INC (MacBuffer^.count);
    END;
    (* Set the data and length *)
    EditRecordPointer :=
           EditMacro^.Methods^.LockFlexStorDataObject (EditMacro);
    IF NOT SetExtData (EditRecordPointer^.handle, ADR(MacBuffer^.buffer),
                       MacBuffer^.count*2) THEN
      MacDeath;
    END;
    EditRecordPointer^.cardlen := MacBuffer^.count;
    EditMacro^.Methods^.UnlockFlexStorDataObject (EditMacro);
    PushMacro (EditMacro);          (* put macro on top of stack *)
    PushState (Playback);           (* set the state for playback   *)

    PopBuffer;                      (* DISPOSE, now that we're done *)
    PopMacHeaderStack;              (* DISPOSE, now that we're done *)
    INC (MacBuffPlay);

END PlayBuffer;


BEGIN
  MacBuffer := NIL;
  MacBuffPlay := 0;

END MacBuffs.
