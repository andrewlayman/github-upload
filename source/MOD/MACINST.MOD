MODULE MacInst;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

    (*  MODIFICATION HISTORY
       10-Aug-89  KKC - Add copyright message.
       01-Oct-89  WKH - ReSynched code btwn Cybersoft & Symantec
       13-Nov-89  RSC - Import from Space rather than Storage.
    *)



FROM Codes                  IMPORT ACode;

FROM Dialog                 IMPORT Error, WarningBox, ADialogOption;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;
    
FROM Forms                  IMPORT
    (* TYPE *)                  AForm, AFieldValue, ACheckReason,
    (* PROC *)                  ShowValue,
                                DoForm;
FROM Kbio                   IMPORT maxrow;

FROM LStrings               IMPORT SetString,
                                   TrimRear,
                                   Copy;

FROM MacCodes               IMPORT CToStr, ExtendedCharStr;

FROM MacCnfg                IMPORT WriteConfig;

FROM MacVars                IMPORT ReplacedKeySet;

FROM MacSetUp               IMPORT StartRecordKey, StopRecordKey, MenuKey,
                                   ListKey, MacInsertKey, 
                                   StepMode, PlayBackSpeed, APlayBackSpeed;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM Keys                   IMPORT CancelKey;

FROM Space                  IMPORT Available;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT SIZE;



VAR
     str           : ARRAY [0..80] OF CHAR;
     S             : ARRAY [0..255] OF CHAR;











  PROCEDURE OurCheckProc (form            : AForm;
                          fieldno         : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                          checkreason     : ACheckReason;
                          VAR code        : CARDINAL):BOOLEAN;


  VAR
        title : ARRAY [0..31] OF CHAR;
        i,j   : CARDINAL;



      PROCEDURE SameHotKeys;
      BEGIN
        GetMessage (26315, S);
        GetMessage (26316, title);
        WarningBox (S, title, NoHelp);
        code := 0;
      END SameHotKeys;


  BEGIN

    IF NOT ((checkreason = CheckFieldKey) OR
            (checkreason = CheckFieldEntry) OR
            (checkreason = CheckFieldExit) OR
            (checkreason = CheckFormExit)) THEN
      code := 0;
      RETURN TRUE;
    END;
    IF checkreason = CheckFormExit THEN
      FOR i := 0 TO 4 DO
        IF FormValue[i].CardValue = 0 THEN
          GetMessage (26317, S);
          GetMessage (26318, title);
          WarningBox (S, title, NoHelp);
          code := 0;
          RETURN FALSE;
        END;
      END;

      FOR i := 1 TO 4 DO
        FOR j := 0 TO (i-1) DO
          IF (FormValue[i].CardValue = FormValue[j].CardValue) THEN
            SameHotKeys;
            RETURN FALSE;
          END;
        END;
      END;

    END;
    CASE fieldno OF
    0..4   :
             IF checkreason = CheckFieldEntry THEN
               code := 0;
               RETURN TRUE;
             ELSIF ((checkreason = CheckFieldExit) OR 
                    (checkreason = CheckFormExit)) THEN
               Copy (FormValue[fieldno].CharValue^, str);
               TrimRear (str);
               IF ORD (str[0]) = 0 THEN
                 FormValue[fieldno].CardValue := 0;
               ELSE
                 IF NOT ExtendedCharStr (str, code) THEN
                   GetMessage (26319, S);
                   Error (S);
                   code := 0;
                   RETURN FALSE;
                 END;
               END;  
               code := 0;
               RETURN TRUE;
             END;
             
             CToStr (code, str);
             FormValue[fieldno].CardValue := code;
             Copy (str, FormValue[fieldno].CharValue^);
             ShowValue (form, fieldno, FormValue);

             IF ((code MOD 16) IN ReplacedKeySet[code DIV 16]) THEN
               GetMessage (26320, S);
               GetMessage (26321, title);
               WarningBox (S, title, NoHelp);
               SetString (FormValue[fieldno].CharValue^, "          ");
               ShowValue (form, fieldno, FormValue);
               code := 0;
               FormValue[fieldno].CardValue := code;
               RETURN FALSE;
             END;
             code := 0;
             RETURN TRUE;
    | 5    :
             IF checkreason = CheckFieldEntry THEN
               code := 0;
               RETURN TRUE;
             END;

    | 6    :
             IF checkreason = CheckFieldEntry THEN
               code := 0;
               RETURN TRUE;
             END;
    ELSE ;
    END;
    code := 0;
    RETURN TRUE;
  END OurCheckProc;











PROCEDURE GetDefaults():BOOLEAN;

CONST
    cULX                    = 7;
    cLRX                    = 73;
    MaxLine                 = 8;
    
VAR
    S                       : ARRAY [0..128] OF CHAR;
    FormValue               : ARRAY [0..6] OF AFieldValue;
    code                    : ACode;
    LRY                     : CARDINAL;
    i, j                    : INTEGER;
    Copyright               : ARRAY[0..50] OF CHAR;


BEGIN                       (* GetFileName *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
        (* allocate memory for hotkey strings *)
    i := 0; j := 0;
    LOOP
      IF Available (SIZE(FormValue[i].CharValue^)) THEN 
        NEW(FormValue[i].CharValue);
      ELSE
        GetMessage (36322, S);
        Error (S);
        FOR i := 0 TO j-1 DO
           DISPOSE (FormValue[i].CharValue);
        END;
        RETURN FALSE;
      END;
      INC (i); INC (j);
      IF i > 4 THEN EXIT; END;
    END;
   
    CToStr (StartRecordKey, FormValue[0].CharValue^);
    FormValue[0].CardValue := StartRecordKey;
    CToStr (StopRecordKey, FormValue[1].CharValue^);
    FormValue[1].CardValue := StopRecordKey;
    CToStr (MenuKey, FormValue[2].CharValue^);
    FormValue[2].CardValue := MenuKey;
    CToStr (ListKey, FormValue[3].CharValue^);
    FormValue[3].CardValue := ListKey;
    CToStr (MacInsertKey, FormValue[4].CharValue^);
    FormValue[4].CardValue := MacInsertKey;
    FormValue[5].CardValue := ORD(NOT StepMode);
    FormValue[6].CardValue := ORD(PlayBackSpeed);

    LRY := maxrow - 13 + MaxLine + 2;
    code := CancelKey;

    code := DoForm(cULX, maxrow - 13, cLRX, LRY,
                               112,
                               TRUE, FormValue, OurCheckProc);
    
    IF code <> CancelKey THEN
        DisplayMessage (26323);
        StartRecordKey := FormValue[0].CardValue;
        StopRecordKey := FormValue[1].CardValue;
        MenuKey := FormValue[2].CardValue;
        ListKey := FormValue[3].CardValue;
        MacInsertKey := FormValue[4].CardValue;
        StepMode := NOT(VAL (BOOLEAN, FormValue[5].CardValue));
        PlayBackSpeed := VAL (APlayBackSpeed, FormValue[6].CardValue);
        WriteConfig;

    END;

    DISPOSE(FormValue[0].CharValue);
    DISPOSE(FormValue[1].CharValue);
    DISPOSE(FormValue[2].CharValue);
    DISPOSE(FormValue[3].CharValue);
    DISPOSE(FormValue[4].CharValue);

    RETURN code <> CancelKey;

END GetDefaults;

BEGIN
  IF GetDefaults() THEN 
  END;
END MacInst.
