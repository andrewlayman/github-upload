IMPLEMENTATION MODULE MacHeader;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
     13-Nov-89  RSC - Import from Space rather than Storage.

---------------------------------------------------------------------------*)




FROM LStrings   IMPORT Fill, SetString;

FROM MacTalk    IMPORT MacDeath;

FROM Space      IMPORT ALLOCATE, DEALLOCATE;



CONST
      MacHeaderStackTag = 8365;


PROCEDURE PushMacHeaderStack;

VAR
    P    : AMacHeaderStackPtr;

BEGIN
  NEW (P);
  P^.tag := MacHeaderStackTag;
  P^.record.hotkey := 0;
  Fill (P^.record.hotkeystr, " ", 9);
  Fill (P^.record.name, " ", 40);
  Fill (P^.record.description, " ", 49);
  IF MacHeaderStack <> NIL THEN
    MacHeaderStack^.prev := P;
    P^.next := MacHeaderStack;
  ELSE
    P^.next := NIL;
  END;
  P^.prev := NIL;
  MacHeaderStack := P;
END PushMacHeaderStack;



PROCEDURE PopMacHeaderStack;

VAR
  P : AMacHeaderStackPtr;

BEGIN
  IF MacHeaderStack = NIL THEN 
    MacDeath;
  END;
  P := MacHeaderStack;
  MacHeaderStack := MacHeaderStack^.next;
  IF MacHeaderStack <> NIL THEN
    MacHeaderStack^.prev := NIL;
  END;
  DISPOSE (P);
END PopMacHeaderStack;

BEGIN
  MacHeaderStack := NIL;

END MacHeader.
