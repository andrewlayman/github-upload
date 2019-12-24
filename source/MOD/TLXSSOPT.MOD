MODULE TLXSSOpt;

    (* MODIFICATION HISTORY

       6-Jun-89  AJL  Put filters into FlexStor.
      09-Aug-89  KKC  Add copyright message.

    *) 


    (*  Bring up the form allowing the user to change the settings
        for the selective save operation.
    *)


FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFltrType, AFilterRecordPointer,
    (* VAR *)                   RevealFilter;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm,
    (* PROC *)                  DoForm, NullCheckProc;

FROM Kbio                   IMPORT
    (* CONST *)                 maxrow, maxcol;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey;

FROM Layout                 IMPORT
    (* VAR *)                   GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatLS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext;

FROM SSaveOptions           IMPORT
    (* TYPE *)                  ASaveSetting,
    (* PROC *)                  GetSaveSettings, PutSaveSettings;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;


CONST
    FormID                  = 62;
    ModuleNumber            = 4700;

VAR
    OK                      : POINTER TO BOOLEAN;
    FormValue               : ARRAY [0..2] OF AFieldValue;
    String                  : ARRAY [0..80] OF CHAR;
    Settings                : ASaveSetting;
    Code                    : ACode;

    FilterPtr               : AFilterRecordPointer;
    Copyright               : ARRAY[0..50] OF CHAR;




BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    OK := OverlayContext();

    GetSaveSettings (Settings);

    FormValue[0].CharValue := ADR(String);

    GetMessage (ModuleNumber+1, String);            (* "Active select filter: " *)

    IF (RevealFilter = NIL) THEN
        ConcatMessage (String, ModuleNumber+2);     (* "(none)" *)
    ELSE
        FilterPtr := RevealFilter^.Methods^.LockFlexStorDataObject (RevealFilter);
        ConcatLS (String, FilterPtr^.Name);
        RevealFilter^.Methods^.UnlockUnchangedDataObject (RevealFilter);
    END;

    FormValue[1].CardValue := ORD(Settings.CursorTaskOnly);
    FormValue[2].CardValue := ORD(Settings.FilterResources);

    OK^ := (DoForm (0, GanttWEnd, maxcol, maxrow-1, FormID,
                    TRUE, FormValue, NullCheckProc) <> CancelKey);

    IF (OK^) THEN
        Settings.CursorTaskOnly  := (FormValue[1].CardValue = 1);
        Settings.FilterResources := (FormValue[2].CardValue = 1);

        PutSaveSettings (Settings);
    END;

END TLXSSOpt.
