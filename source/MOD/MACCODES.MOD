IMPLEMENTATION MODULE MacCodes;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
      8-Jan-90  RSC - Expand the range of extended keys to allow for mice.
      30-May-91 RSC   Removed globals, put them on the stack.

---------------------------------------------------------------------------*)

(* Modifications :
                    10/27/88 - CToStr, ExtendedCharStr added.
                    10/28/88 - CToStr & ExtendedCharStr changed to use
                               flexstor.
                               
*)

FROM Codes       IMPORT
                        ASetOfCodes;

FROM FlexStor    IMPORT
                        LockObjectArray, ReleaseObject;

FROM MacVars     IMPORT
                        ExtendedCharSet, XKey, NormKey, KeyOffset,
                        ReplacedKeySet;

FROM LStrings    IMPORT
                        Copy, Compare;

FROM SYSTEM      IMPORT
                        ADDRESS;


CONST  LastExKey = 182;
       LastNormKey = 31;
       recordsize = 11;

TYPE
     name            = ARRAY [0..10] OF CHAR;
     XKeyArray       = ARRAY [0..182] OF name;
     NormKeyArray    = ARRAY [0..31] OF name;


(*------------------------------------------------------------------------

Returns TRUE iff the code is found to be in the specified codeset.

-------------------------------------------------------------------------*)

PROCEDURE InCodeSet (VAR codeset : ASetOfCodes;
                     code        : CARDINAL):BOOLEAN;
BEGIN
  RETURN ((code MOD 16) IN codeset[code DIV 16]);
END InCodeSet;




(*------------------------------------------------------------------------

Gets the string equivalent of extended characters and control characters.
Used in the editor.

-------------------------------------------------------------------------*)

PROCEDURE GetCodeString (C       : CARDINAL;
                         VAR str : ARRAY OF CHAR);
VAR
     numrecs         : CARDINAL;
     NormKeyArrayPtr : POINTER TO NormKeyArray;
     XKeyArrayPtr    : POINTER TO XKeyArray;

BEGIN
(*$O-*)
  IF InCodeSet (ExtendedCharSet, C) THEN
    numrecs := LockObjectArray (XKey, XKeyArrayPtr, recordsize);
    Copy (XKeyArrayPtr^[C-KeyOffset], str);
    ReleaseObject (XKey);
  ELSE
    numrecs := LockObjectArray (NormKey, NormKeyArrayPtr, recordsize);
    Copy (NormKeyArrayPtr^[C], str);
    ReleaseObject (NormKey);
  END;

(*$O+*)

END GetCodeString;




(****** Test procedure... remove before production *************************)
(*
PROCEDURE CodeIsValid (C : ACode):BOOLEAN;
BEGIN

    IF ((C > MaxCard) AND (C <> NameCode)) THEN
      SetString (S, "Invalid character in macro...ü");
      ConcatS (S, "CARDINAL of ");
      CtoS (C, str);
      ConcatLS (S, str);
      INC(Interlock);
      Error (S);
      DEC(Interlock);
      ClearPlayback;
      IF StepMode THEN RemoveLight (StepModeLight); END;
      RETURN FALSE;
    END;
    RETURN TRUE;
END CodeIsValid;
*)


(*------------------------------------------------------------------------

Returns TRUE iff the code is found in the hotkey set.

-------------------------------------------------------------------------*)

PROCEDURE CodeIsAHotKey (code : CARDINAL):BOOLEAN;

BEGIN
  IF code < 389 THEN
    RETURN ((code MOD 16) IN ReplacedKeySet[code DIV 16]);
  END;
  RETURN FALSE;
END CodeIsAHotKey;



PROCEDURE CToStr (C       : CARDINAL;
                  VAR Str : ARRAY OF CHAR);
VAR
     numrecs         : CARDINAL;
     XKeyArrayPtr    : POINTER TO XKeyArray;

(*$O-*) (* optimization OFF *)

  BEGIN
    IF C > LastNormKey THEN
      numrecs := LockObjectArray (XKey, XKeyArrayPtr, recordsize);
      Copy (XKeyArrayPtr^[C-KeyOffset], Str);
      ReleaseObject (XKey);
    ELSE
      numrecs := LockObjectArray (NormKey, XKeyArrayPtr, recordsize);
      Copy (XKeyArrayPtr^[C], Str);
      ReleaseObject (NormKey);
    END;

(*$O+*) (* optimization ON *)
END CToStr;




PROCEDURE ExtendedCharStr (str   : ARRAY OF CHAR;
                           VAR c : CARDINAL):BOOLEAN;

CONST  recordsize = 11;

VAR
     i       : CARDINAL;
     numrecs : CARDINAL;
     NormKeyArrayPtr : POINTER TO NormKeyArray;
     XKeyArrayPtr    : POINTER TO XKeyArray;

(*$O-*)

      BEGIN

        numrecs := LockObjectArray (XKey, XKeyArrayPtr, recordsize);
        FOR i := 0 TO LastExKey DO
          IF Compare (str, XKeyArrayPtr^[i]) = 0 THEN
            c := i + KeyOffset;
            ReleaseObject (XKey);
            RETURN TRUE;
          END;
        END;
        ReleaseObject (XKey);

        numrecs := LockObjectArray (NormKey, NormKeyArrayPtr, recordsize);
        FOR i := 0 TO LastNormKey DO
          IF Compare (str, NormKeyArrayPtr^[i]) = 0 THEN
            c := i;
            ReleaseObject (NormKey);
            RETURN TRUE;
          END;
        END;
        ReleaseObject (NormKey);

        RETURN FALSE;

(*$O+*)

END ExtendedCharStr;



END MacCodes.
