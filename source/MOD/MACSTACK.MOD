IMPLEMENTATION MODULE MacStack;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

     13-Nov-89  RSC - Import from Space rather than Storage.
     20-Mar-90  RSC - Remove unused global data.
     15-Sep-91  LAA - Check that there's space before trying to allocate a
                      new record for the MacStack.  I also cleaned up some
                      naming and indentation, and changed usage of 
                      ReleaseObject to ReleaseUnchangedObject where possible.
                      Changed GetName a bit to be safer.
---------------------------------------------------------------------------*)

FROM Dialog          IMPORT Error;

FROM FlexStor        IMPORT LockObjectArray, ReleaseUnchangedObject, 
                            AnExtHandle;

FROM LStrings        IMPORT SetLengthOf, Procustes, Compare,
                            SetString, ConcatLS;

FROM MacBuffs        IMPORT MaxKeystrokes;

FROM MacrosRc        IMPORT GetMacroName, GetMacroHandle, GetMacroLength;

FROM MsgFile         IMPORT GetMessage;

FROM Space           IMPORT Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM          IMPORT TSIZE;

FROM TreeObjects     IMPORT ATreeNode;


CONST
     MacStackTag  = 7895;
     NameCode     = 1000;
     ModuleNumber = 26400;      (* Shared with at least MacPlay *)

PROCEDURE PushMacro (VAR TheMacro     : ATreeNode);
VAR
    P                       : AMacStackPtr;
    name1, name2            : ARRAY [0..40] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
     
BEGIN

    (* iff a looping macro, then pop the macro off the stack; (save memory) *)
    IF MacStack <> NIL THEN
        GetMacroName (MacStack^.macro, name1);
        GetMacroName (TheMacro, name2);
        IF (Compare (name1, name2) = 0) THEN
            PopMacro;
        END;
    END;
  
    IF (Available( TSIZE(AMacStackRec) )) THEN
        NEW (P);
        P^.tag := MacStackTag;
        P^.macro := TheMacro;
        P^.pos := 0;
        IF MacStack <> NIL THEN
            MacStack^.prev := P;
            P^.next := MacStack;
        ELSE
            P^.next := NIL;
        END;
        P^.prev := NIL;
        MacStack := P;
    ELSE
            (*  Insufficient memory to play back this macro   *)
        GetMessage( ModuleNumber + 89, s );
        Error( s );
    END;

END PushMacro;


PROCEDURE PopMacro;

VAR
    P : AMacStackPtr;

BEGIN

    IF MacStack <> NIL THEN
        P := MacStack;
        MacStack := MacStack^.next;
        IF MacStack <> NIL THEN
            MacStack^.prev := NIL;
        END;
        DISPOSE (P);
    END;

END PopMacro;


(*------------------------------------------------------------------------

Reads a cardinal from the macro; from ExtStorage.

-------------------------------------------------------------------------*)

PROCEDURE GetACardinal (VAR Card   : CARDINAL);

TYPE ADataRec = RECORD
                    data : ARRAY [0..MaxKeystrokes] OF CARDINAL;
                END;

     ADataPtr = POINTER TO ADataRec;

VAR data        : ADataPtr;
    handle      : AnExtHandle;
    reccount,
    recordsize  : CARDINAL;

BEGIN
    handle := GetMacroHandle (MacStack^.macro);
    recordsize := (GetMacroLength (MacStack^.macro) * 2);
    reccount := LockObjectArray (handle, data, recordsize);
    Card := data^.data[MacStack^.pos];
    ReleaseUnchangedObject (handle);                           (* 15-Sep-91 *)
    INC(MacStack^.pos);
END GetACardinal;



(*------------------------------------------------------------------------

Reads a macro name inside a macro.

-------------------------------------------------------------------------*)

PROCEDURE GetName (C        : CARDINAL;
                   VAR name : ARRAY OF CHAR);
VAR
    i : CARDINAL;

BEGIN
    GetACardinal (C);
    i := 1;
    WHILE (C <> NameCode) DO
        IF (i <= HIGH( name )) THEN
            name[i] := CHR(C);
            INC (i);
        END;
        GetACardinal (C);
    END;
    SetLengthOf( name, i - 1 );
    Procustes (name, 40);
END GetName;



BEGIN
  MacStack := NIL;
END MacStack.
