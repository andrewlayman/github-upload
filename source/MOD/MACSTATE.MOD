IMPLEMENTATION MODULE MacState;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

     13-Nov-89  RSC - Import from Space rather than Storage.
     20-Mar-90  RSC - Removed unused globals.
---------------------------------------------------------------------------*)

FROM Dialog IMPORT Error;

FROM LStrings   IMPORT SetString;


FROM MacTalk    IMPORT MacDeath;

FROM Space      IMPORT ALLOCATE, DEALLOCATE;


CONST
      StateStackTag = 763;


(* Testing *)
(*
PROCEDURE SayState;
VAR
      S             : ARRAY [0..80] OF CHAR;
BEGIN
  CASE State OF
  Neutral : SetString (S, "State is neutral")|
  Recording : SetString (S, "State is Recording")|
  Playback : SetString (S, "State is Playback");
  ELSE;
  END;
  Error (S);
END SayState;
*)




PROCEDURE PushState (TheState       : AState);

VAR
    P : AStateStackPtr;

BEGIN
  NEW (P);
  P^.tag := StateStackTag;
  P^.state := TheState;
  IF StateStack <> NIL THEN
    StateStack^.prev := P;
    P^.next := StateStack;
  ELSE
    P^.next := NIL;
  END;
  P^.prev := NIL;
  StateStack := P;
  State := StateStack^.state;

(*testing*)
  (*SetString (S, "Pushed state.");
  Error (S);
  SayState;*)
(*end testing*)

END PushState;


PROCEDURE PopState;

VAR
    P : AStateStackPtr;

BEGIN
  
  IF StateStack = NIL THEN 
    MacDeath;
  END;
   
  P := StateStack;
  StateStack := StateStack^.next;
  IF StateStack <> NIL THEN
    StateStack^.prev := NIL;
    State := StateStack^.state;  (* ??? *)

    (*testing*)
    (*SetString (S, "Popped state.");
    Error (S);
    SayState;*)
    (*testing*)
    
  END;
  DISPOSE (P);
END PopState;

BEGIN
  StateStack := NIL;
  PushState (Neutral);

END MacState.
