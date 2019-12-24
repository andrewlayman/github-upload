MODULE TLRHForm;

  (* TL R[esource] H[istogram] Form -

        This module gets forms away from the histogram stuff, so that
        the Forms module is not linked into TLRHist, and so that
        TLFBase need not stay resident ALL the time that TLRHist is.

        RSC - 1/21/88   First version from TLRHist.
        6-Jan-89 RSC    Moved "AnOverlayProc" reference.
       19-Apr-89 RSC    Fixed bug where deleting a resource causes a crash.
       09-Aug-89 KKC    Add copyright message.
   *)


FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM Forms                  IMPORT DoForm, AFieldValue, NullCheckProc,
                                   ACheckReason, ShowValue, AForm,
                                   AStringValue, SetFieldProtection;

FROM Keys                   IMPORT CancelKey, ExitKey, DoIt;

FROM Kbio                   IMPORT maxrow, maxcol;

FROM Layout                 IMPORT GanttWEnd;

FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Copy, Insert, Procustes, TrimFront, TrimRear, 
                                   Compare, LJust, Overlay, TStringToLString,
                                   LengthOf, SetLengthOf, Fill;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM HistStat               IMPORT MaxResources, HistResource;

FROM RsrcEdit               IMPORT SelectResource,
                                   EditResources;

FROM RsrcMod                IMPORT
    (* CONST *)                    ResourceNameLength,
    (* TYPE *)                     AResourcePointer, AResourceType, ACostStyle,
    (* VAR *)                      ResourceTree,
    (* PROC *)                     FindResourceByName;

FROM SYSTEM                IMPORT
    (* Thing *)                 ADR;

FROM TreeObjects           IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  ValidateTree, ValidateTreeNode;



CONST
    ModuleNumber     = 13300;    (* SAME AS TLRHist *)

VAR
    OverlayID        : AnOverlayID;
    s                : ARRAY [0..255] OF CHAR;




PROCEDURE CheckForm (    Form               : AForm;
                         FieldNo            : AFieldNo;
                     VAR FormValue          : ARRAY OF AFieldValue;
                         CheckReason        : ACheckReason; 
                     VAR Code               : CARDINAL)
                                                       : BOOLEAN;
VAR
    CheckNode,
    RsrcNode : ATreeNode;
    Resource : AResourcePointer;
    i        : CARDINAL;
    ok       : BOOLEAN;
BEGIN
    Code := 0;
    IF (CheckReason = CheckFormEntry)  OR
       (CheckReason = CheckFieldEntry) THEN
        RETURN TRUE;
    END;

    IF (CheckReason = CheckFieldKey) THEN
        RsrcNode := FindResourceByName(FormValue[FieldNo].CharValue^);
        ok := (SelectResource(RsrcNode));

        FOR i := 0 TO (MaxResources - 1) DO
            CheckNode := FindResourceByName(FormValue[i].CharValue^);
            IF (CheckNode = NIL) THEN
                SetLengthOf( FormValue[i].CharValue^, 0 );
                ShowValue( Form, i, FormValue );
            END;
        END;

        IF (ok) THEN
            Resource := RsrcNode^.Methods^.GetDataObject(RsrcNode);
            Copy( Resource^.Name, FormValue[FieldNo].CharValue^ );
            ShowValue(Form,FieldNo,FormValue);
        END;

        RETURN ok;
    END;

    Copy( FormValue[FieldNo].CharValue^, s );
    TrimRear(s);
    IF (s[0] > 0C) THEN
        RsrcNode := FindResourceByName(s);
        IF (RsrcNode = NIL) THEN
            ConcatS( s, ":ü" );
            ConcatMessage( s, ModuleNumber+3);   (*  "That resource doesn't exist."  *)
            Error(s);
            RETURN FALSE;
        ELSE
            Resource := RsrcNode^.Methods^.GetDataObject(RsrcNode);
            IF (Resource^.Type <> Employable) THEN
                ConcatS( s, ":ü" );
                ConcatMessage(s, ModuleNumber+2 );   (*  "Only RESOURCES are allowed for histograms (not costs)."  *)
                Error(s);
                RETURN FALSE;
            END;
            Copy( Resource^.Name, FormValue[FieldNo].CharValue^ );
            ShowValue(Form,FieldNo,FormValue);
        END;
    END;
    RETURN TRUE;
END CheckForm;








PROCEDURE DisplayControlForm();
VAR
    Code      : ACode;
    i         : CARDINAL;
    FormValue : ARRAY [1..MaxResources] OF AFieldValue;
    Strings   : ARRAY [1..MaxResources] OF AStringValue;
    Copyright : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    FOR i := 1 TO MaxResources DO
        FormValue[i].CharValue := ADR(Strings[i]);
        Copy( HistResource[i], FormValue[i].CharValue^ );
    END;

    Code := DoForm(49,GanttWEnd,maxcol,maxrow-4,11,TRUE,FormValue,CheckForm);
    IF (Code = ExitKey) THEN
        FOR i := 1 TO MaxResources DO
            Copy( FormValue[i].CharValue^, HistResource[i] );
            LJust(    HistResource[i] );
            TrimRear( HistResource[i] );
        END;
    END;
END DisplayControlForm;


BEGIN
    OverlayID := ImAnInstallableOverlay(DisplayControlForm, AnOverlayProc(NIL));
    DisplayControlForm();
END TLRHForm.
