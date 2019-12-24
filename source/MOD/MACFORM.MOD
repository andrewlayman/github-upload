MODULE MacForm;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)



(* Modification History :

    3/20/88 : Macro names upshifted to caps.
    4/13/89 : Cloned MACFORM from MACFORM1. Shift to using TLFORMS file.
*)

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldType;

FROM FormSupport            IMPORT
    (* TYPE *)                  AFormRecord, ASetOfAttributes, APromptType,
                                AnAttribute, ABoxAttribute, ABoxType, ACode,
                                MaxCode, ASetOfCodes;

FROM GeldedLStrings         IMPORT SetString;

FROM PutForms               IMPORT PutForm, OpenFormsNew, CloseForms;



                                   





VAR
    S                     : ARRAY [0..255] OF CHAR;
    FormRecord            : AFormRecord;








PROCEDURE SetCodeBits (VAR CodeSet: ASetOfCodes;
                       First, Last: ACode; Value:BOOLEAN);
VAR
    i : CARDINAL;
    WordNumber, BitNumber : CARDINAL;
BEGIN
    IF (First > MaxCode) OR (Last > MaxCode) THEN HALT; END;

    i := First;
    WHILE (i <= Last) DO
        WordNumber := i DIV 16;
        BitNumber  := i MOD 16;
        IF (Value) THEN
            INCL(CodeSet[WordNumber], BitNumber)
        ELSE
            EXCL(CodeSet[WordNumber], BitNumber)
        END;
        INC(i);
    END
END SetCodeBits;






PROCEDURE InitForm;

CONST
    cThisForm               = 110;
    StartRecordKey          = 387;
    StopRecordKey           = 386;
    MenuKey                 = 360;
    ListKey                 = 365;
    MacInsertKey            = 362;
    maxcol                  = 79;
    PromptLY                = 2;


    

BEGIN                       (* GetFileName *)


    WITH FormRecord DO
        ID := cThisForm;
        PhrasesStart := 30000 + (ID * 100);
        PromptULX := 0;
        PromptULY := 0;
        PromptLRX := maxcol;
        PromptLRY := PromptLY;
        SetString(Title, " Primary Macro Form ");
        SetString(HelpKey, "MACPM");
        MaxLine := 4;
        Box := ABoxType{DoubleBox, ShadowBox};
        PromptType := SeparatePrompts;
                           (*          1         2         3         4         5         6         7*)
                           (* 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789*)
        SetString(FLine[0], "÷ You must name the macro, a hotkey assignment is optional.         ÷");
        SetString(FLine[1], "÷ שששששששששששששששששששששששששששששששששששששששששששששששששששששששששששששששששש÷");
        SetString(FLine[2], "÷ Macro Name  : [                                         ]         ÷");
        SetString(FLine[3], "÷ Macro HotKey: [          ]                                        ÷");
        SetString(FLine[4], "÷ Description : [                                                 ] ÷");

        MaxField := 2;
        Table.StartField := 9999;

              (*----------   CheckCodeSet   ----------*)
        SetCodeBits(CheckCodeSet, 0, MaxCode, FALSE);

            (* Alt letters *)
        SetCodeBits(CheckCodeSet, 272, 280, TRUE);  (* altq - alto - no Altp *)
        SetCodeBits(CheckCodeSet, 286, 294, TRUE);  (* alta - altl *)
        SetCodeBits(CheckCodeSet, 300, 304, TRUE);  (* altz - altb *)
        SetCodeBits(CheckCodeSet, 306, 306, TRUE);  (* altm *)
        SetCodeBits(CheckCodeSet, 275, 275, FALSE); (* remove Altr *)
        SetCodeBits(CheckCodeSet, 305, 305, FALSE); (* remove Altn *)

            (* Ctrl letters and characters *)
        SetCodeBits(CheckCodeSet, 1, 31, TRUE);
        SetCodeBits(CheckCodeSet, 8, 8, FALSE);     (* backspace *)
        SetCodeBits(CheckCodeSet, 9, 9, FALSE);     (* shift backspace *)
        SetCodeBits(CheckCodeSet, 13, 13, FALSE);   (* enter *)
        SetCodeBits(CheckCodeSet, 19, 19, FALSE);   (* ctrl s (scrolling) *)
        SetCodeBits(CheckCodeSet, 27, 27, FALSE);   (* esc *)
         
             (* Alt numbers *)
        SetCodeBits(CheckCodeSet, 376, 385, TRUE);  (* alt1 - alt0 *)
             (* Alt minus/equal keys *)
        SetCodeBits(CheckCodeSet, 386, 387, TRUE);
             (* Alt function keys *)
        SetCodeBits(CheckCodeSet, 360, 369, TRUE); (* altF1 - altf10 *)
        SetCodeBits(CheckCodeSet, 366, 366, FALSE); (* remove AltF7 *)
             (* Remove Macro Hotkeys *)
        SetCodeBits(CheckCodeSet, StartRecordKey, StartRecordKey, FALSE);
        SetCodeBits(CheckCodeSet, StopRecordKey, StopRecordKey, FALSE);
        SetCodeBits(CheckCodeSet, MenuKey, MenuKey, FALSE);
        SetCodeBits(CheckCodeSet, ListKey, ListKey, FALSE);
        SetCodeBits(CheckCodeSet, MacInsertKey, MacInsertKey, FALSE);

             (* --------   End of setting CheckCodeSet   ----------*)
        (*----------------------------------------------------------------*)
             (* --------     Start of setting Fields     ----------*)

        WITH Fields[0] DO
            Group := 0;
            xoff := 17; yoff := 2;
            Attributes := ASetOfAttributes{};
            INCL (Attributes, ResetCursorOnError);
            FFType := FormString;
            StLen := 40;
            SetCodeBits(CodeSet, 0, MaxCode, FALSE);
            SetCodeBits(CodeSet,33,96,TRUE);
        END;

        WITH Fields[1] DO
            Group := 0;
            xoff := 17; yoff := 3;
            Attributes := ASetOfAttributes{};
            INCL (Attributes, ResetCursorOnError);
            FFType := FormString;
            StLen := 10;
            SetCodeBits(CodeSet, 0, MaxCode, FALSE);

                 (*----------   CodeSet   ----------*)

            (* Alt letters *)
            SetCodeBits(CodeSet, 272, 280, TRUE);  (* altq - alto - no Altp *)
            SetCodeBits(CodeSet, 286, 294, TRUE);  (* alta - altl *)
            SetCodeBits(CodeSet, 300, 304, TRUE);  (* altz - altb *)
            SetCodeBits(CodeSet, 306, 306, TRUE);  (* altm *)
            SetCodeBits(CodeSet, 275, 275, FALSE); (* remove Altr *)
            SetCodeBits(CodeSet, 305, 305, FALSE); (* remove Altn *)

            (* Ctrl letters and characters *)
            SetCodeBits(CodeSet, 1, 31, TRUE);
            SetCodeBits(CodeSet, 8, 8, FALSE);     (* backspace *)
            SetCodeBits(CodeSet, 9, 9, FALSE);     (* shift backspace *)
            SetCodeBits(CodeSet, 13, 13, FALSE);   (* enter *)
            SetCodeBits(CodeSet, 19, 19, FALSE);   (* ctrl s (scrolling) *)
            SetCodeBits(CodeSet, 27, 27, FALSE);   (* esc *)
            
            (* Alt numbers *)
            SetCodeBits(CodeSet, 376, 385, TRUE);  (* alt1 - alt0 *)

            (* Alt function keys *)
            SetCodeBits(CodeSet, 360, 369, TRUE); (* altF1 - altf10 *)
            SetCodeBits(CodeSet, 366, 366, FALSE); (* remove AltF7 *)

            (* Alt minus/equal keys *)
            SetCodeBits(CodeSet, 386, 387, TRUE);

            (* Remove Macro Hotkeys *)
            SetCodeBits(CodeSet, StartRecordKey, StartRecordKey, FALSE);
            SetCodeBits(CodeSet, StopRecordKey, StopRecordKey, FALSE);
            SetCodeBits(CodeSet, MenuKey, MenuKey, FALSE);
            SetCodeBits(CodeSet, ListKey, ListKey, FALSE);
            SetCodeBits(CodeSet, MacInsertKey, MacInsertKey, FALSE);

        END;

        WITH Fields[2] DO
            Group := 0;
            xoff := 17; yoff := 4;
            Attributes := ASetOfAttributes{};
            FFType := FormString;
            StLen := 49;
            SetCodeBits(CodeSet, 0, MaxCode, FALSE);
            SetCodeBits(CodeSet,32,175,TRUE);
        END;

    END;
END InitForm;

BEGIN
  InitForm;
  SetString (S, "MACFORM.DAT");
  OpenFormsNew (S, 110);
  PutForm (FormRecord);
  CloseForms;
END MacForm.
