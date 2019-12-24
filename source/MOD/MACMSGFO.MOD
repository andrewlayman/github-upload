MODULE MacMsgForm;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Saves macro to disk.

   MODIFICATIONS:
   
   5/2/89 LVK : Moved form to separate file "MACMSGF.MOD" for addition
                to TLFORMS file.
   10-Aug-89  KKC - Add copyright message.
   01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
   13-Nov-89  RSC - Import from Space rather than Storage.
   20-Mar-90  RSC - Removed FormRecord dispose.
*)

FROM Codes                  IMPORT ACode;

FROM Dialog                 IMPORT
                                   Error;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM FormRec                IMPORT
    (* TYPE *)                  AFormRecord;

FROM Forms                  IMPORT
    (* TYPE *)                  AForm, AFieldValue, ACheckReason,
    (* PROC *)                  DoForm;

FROM Kbio           IMPORT maxrow;

FROM Keys           IMPORT CancelKey;

FROM LStrings       IMPORT SetString, Fill, Copy, ConcatLS,
                           ConcatS, TrimRear;

FROM MacStrings     IMPORT MacMessagePtr;

FROM MacVars        IMPORT FormAccepted, Editing;

FROM MsgFile        IMPORT GetMessage;

FROM Space          IMPORT Available;

FROM Space          IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT SIZE;




  VAR
      S                  : ARRAY [0..128] OF CHAR;

PROCEDURE Replace (VAR str  : ARRAY OF CHAR;
                       with : CHAR;
                       by   : CHAR);
VAR
    i : CARDINAL;

BEGIN
  FOR i := 1 TO ORD(str[0]) DO
    IF str[i] = with THEN
      str[i] := by;
    END;
  END;
END Replace;


  PROCEDURE OurCheckProc (form            : AForm;
                          fieldno         : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                          checkreason     : ACheckReason;
                          VAR code        : CARDINAL):BOOLEAN;

  (*CONST jump = 8000H;*)


  BEGIN
    IF NOT (checkreason = CheckFieldEntry) THEN
      code := 0;
      RETURN TRUE;
    END;

    CASE fieldno OF
      0   : 
              code := 0;
              RETURN TRUE|

      1..5 : 
              code := 0;
              RETURN TRUE;
      ELSE ;
      END;
      code := 0;
      RETURN TRUE;
END OurCheckProc;


PROCEDURE DoMessage(): BOOLEAN;

CONST
    cULX                    = 5;
    (*cULY                    = 15;*)
    cLRX                    = 73;
    MaxLine                 = 5;
    
VAR
(*    FormRecord              : POINTER TO AFormRecord;*)  (* 20-Mar-90 RSC removed *)
    FormValue               : ARRAY [0..5] OF AFieldValue;
    code                    : ACode;
    LRY                     : CARDINAL;
    i, j                    : CARDINAL;
    tempstr                 : ARRAY [0..40] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;





BEGIN                       (* GetFileName *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    (* allocate memory  *)
    i := 0; j := 0;
    LOOP
      IF Available (SIZE(FormValue[i].CharValue^)) THEN 
        NEW(FormValue[i].CharValue);
      ELSE
        GetMessage (26350, S);
        Error (S);
        FOR i := 0 TO j-1 DO
           DISPOSE (FormValue[i].CharValue);
(*           DISPOSE (FormRecord);*)    (* 20-Mar-90 RSC Removed this *)
        END;
        RETURN FALSE;
      END;
      INC (i); INC (j);
      IF i > 5 THEN EXIT; END;
    END;

    Fill (FormValue[0].CharValue^, " ", 30);

    FOR i := 1 TO 5 DO
      Fill (FormValue[i].CharValue^, " ", 50);
    END;

    code := CancelKey;
    LRY := maxrow-10 + MaxLine + 2;

    code := DoForm(cULX, maxrow-10, cLRX, LRY,
                               115,
                               TRUE, FormValue, OurCheckProc);

    IF code <> CancelKey THEN

      NEW (MacMessagePtr);

      Copy (FormValue[0].CharValue^, MacMessagePtr^.Title);
      TrimRear (MacMessagePtr^.Title);

      (* adds a space front and back to the title *)
      SetString (tempstr, " ");
      ConcatLS (tempstr, MacMessagePtr^.Title);
      ConcatS (tempstr, " ");
      Copy (tempstr, MacMessagePtr^.Title);

      IF (FormValue[1].CharValue^[50] = " ") THEN
        TrimRear (FormValue[1].CharValue^);
        ConcatS (FormValue[1].CharValue^, " ");
      END;
      Copy (FormValue[1].CharValue^, MacMessagePtr^.Message);
      FOR i := 2 TO 5 DO
        IF ((i <> 5) AND (FormValue[i].CharValue^[50] = " ")) THEN
          TrimRear (FormValue[i].CharValue^);
          ConcatS (FormValue[i].CharValue^, " ");
        END;
        ConcatLS (MacMessagePtr^.Message, FormValue[i].CharValue^);
      END;
      TrimRear (MacMessagePtr^.Message);

      IF Editing THEN
        Replace (MacMessagePtr^.Title, " ", "ù");
        Replace (MacMessagePtr^.Message, " ", "ù");
      END;
      
    ELSE
      MacMessagePtr := NIL;
    END;

    DISPOSE(FormValue[0].CharValue);
    FOR i := 1 TO 5 DO
      DISPOSE(FormValue[i].CharValue);
    END;

    RETURN code <> CancelKey;

END DoMessage;

BEGIN

  FormAccepted := FALSE;
  IF DoMessage() THEN FormAccepted := TRUE; END;

END MacMsgForm.
