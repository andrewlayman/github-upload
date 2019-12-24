MODULE TLNetForm;

(*$S+*)

(*  =========================================================================
    Last Edit : June 10, 1991 2:56PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        PERT and Tree report form        

    MODIFICATION HISTORY:
        09-Feb-88 LAA   Adjusted for new parameter of GetColumnInfo.
        10-Feb-88 LAA   Used procedure from ColumnName to create the list of
                        columns, and fixed bug which left a text lying around
                        on the heap whenever the form was brought up.
        13-Feb-88 LAA   Added ability to move column name fields up and down.
        01-Mar-88 LAA   Changed the checking of adjacent field widths to occur
                        on FormExit only, and to bitch about anything > 79.
        02-Mar-88 LAA   Return MoveUp and MoveDown keys to forms if they come
                        in from other than the column name fields.
        03-Mar-88 LAA   Only F2 should bring up the editor from the notes 
                        field.
        22-Dec-88 LAA   Adjusted parameters for new GetColumnInfo.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        23-Jan-89 RSC   Changed Storage to Space.
         2-Feb-89 RSC   Fixed problems with GetColumnInfo.
         3-Mar-89 LAA   Changed compound IF ... AND ... etc. statement so it
                        would compile with range and address checking on.
        20-Mar-89 LAA   Replaced ColumnName with TaskColumns module.
        14-Jul-89 EGK   Fixed the check of layout name uniqueness so that
                        it uses the TrimRear'd version of the string.
        09-Aug-89 KKC   Add copyright message.
        11-Sep-89 WKH   TrimRear the Layout name after we copy it from the
                        form field to the layout tree.  We were storing
                        the "padded" version thus making it impossible for
                        us to safeguard agains duplicate layout names.
        12-Sep-89 WKH   Hi, it's me again.  Making the Notes editor box
                        bigger for compressed video mode.
        14-Sep-89 EGK   Validate the column name on CheckFieldChange, not
                        on CheckFieldExit.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.
        10-Jun-91 PFG   Call GetTaskColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a task 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
    =========================================================================
*)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM Boxes                  IMPORT 
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT 
    (* PROC *)                  Burp, Message, Error, FatalError;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason, 
                                ACursorAttribute,
    (* PROC *)                  ShowValue, HighlightField, SetFieldProtection,
                                DoForm, SetFormChange;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey, EditKey, MoveUpKey, 
                                MoveDownKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, TrimRear, Copy, Upshift, TrimFront, 
                                StringsEqual, LengthOf, LJust, SetLengthOf, 
                                Procustes;

FROM MsgFile                IMPORT 
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved, ConfigSaved;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  TextExists, CreateText, AssignLine, Compress,
                                CopyLine, AssignText, DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTreeNode, CreateTree, ValidateTreeNode;

CONST
    ModuleNumber            = 22600;

CONST
    NAME                    = 0;
    NOTE                    = 1;
    BOX                     = 2;
    CN1                     = 3;
    CN2                     = 5;
    CN3                     = 7;
    CN4                     = 9;
    CN5                     = 11;
    CN6                     = 13;
    CW1                     = 4;
    CW2                     = 6;
    CW3                     = 8;
    CW4                     = 10;
    CW5                     = 12;
    CW6                     = 14;

VAR
    LayoutOnForm            : ATreeNode;
    LayoutNotes             : AText;
    OverlayID               : AnOverlayID;


PROCEDURE MapColumnSpecsToFormValue(    Layout      : ANetworkLayout;
                                    VAR FormValue   : ARRAY OF AFieldValue);

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;

BEGIN                       (* MapColumnSpecsToFormValue *)

    WITH Layout^ DO
        i := CN1;
        FOR j := 1 TO 6 DO
            FormValue[i].CardValue := Fields[j].ColumnID;
            IF (Fields[j].ColumnID <> 0) THEN
                GetTaskColumnName(  Fields[j].ColumnID, 
                                    FormValue[i].CharValue^); (* 10-Jun-91 PFG *)
                FormValue[i + 1].CardValue := Fields[j].ColumnWidth;
            ELSE
                Fill(FormValue[i].CharValue^, " ", 24);
                FormValue[i + 1].CardValue := 0;
            END;
            INC(i, 2);
        END;
    END;

END MapColumnSpecsToFormValue;



PROCEDURE MapFormValueToColumnSpecs(VAR FormValue   : ARRAY OF AFieldValue;
                                        Layout      : ANetworkLayout);


VAR
    i                       : CARDINAL;
    j                       : CARDINAL;

BEGIN                       (* MapFormValueToColumnSpecs *)

    WITH Layout^ DO
        j := 1;
        FOR i := CN1 TO CN6 BY 2 DO
            Fields[j].ColumnID := FormValue[i].CardValue;
            IF (FormValue[i].CardValue <> 0) THEN
                Fields[j].ColumnWidth := FormValue[i + 1].CardValue;
            ELSE
                Fields[j].ColumnWidth := 0;
            END;
            INC(j);
        END;
    END;

END MapFormValueToColumnSpecs;




PROCEDURE CheckForm (    Form        : AForm;
                         FieldNo     : AFieldNo;
                     VAR FormValue   : ARRAY OF AFieldValue;
                         CheckReason : ACheckReason;
                     VAR Code        : CARDINAL ):BOOLEAN;
VAR
    ULX, LRX, LRY           : CARDINAL;
    i, j, k                 : CARDINAL;
    CodeIn                  : CARDINAL;
    Id                      : CARDINAL;
    Node                    : ATreeNode;
    Layout                  : ANetworkLayout;
    T                       : ATaskPtr;
    r                       : REAL;
    TempField               : AFieldValue;
    DataRecord              : AColumnDataRecord;
    S2                      : ARRAY [0..255] OF CHAR;
    S3                      : ARRAY [0..81] OF CHAR;
    S                       : ARRAY [0..81] OF CHAR;
    Changed                 : BOOLEAN;

    PROCEDURE SaveNotesToText();
    BEGIN                      (* SaveNotesToText *)

        TrimRear(FormValue[NOTE].CharValue^);
        IF NOT TextExists(LayoutNotes) THEN
            IF (FormValue[NOTE].CharValue^[0] = 0C) THEN
                RETURN;
            ELSE
                LayoutNotes := CreateText();
            END;
        END;
        IF NOT AssignLine(FormValue[NOTE].CharValue^, 0, LayoutNotes) THEN
            GetMessage(ModuleNumber + 5, S);    (* Unable to save your notes  *)
            Error(S);
        END;

    END SaveNotesToText;


    PROCEDURE Max(    i                     : CARDINAL;
                      j                     : CARDINAL)
                                                       : CARDINAL;

    BEGIN                   (* Max *)

        IF (j > i) THEN
            i := j;
        END;

        RETURN i;

    END Max;

BEGIN

    CodeIn := Code;
    Code := 0;

    CASE FieldNo OF                                               (* 11-Jun-87 LAA *)
        NAME :
            IF ((CheckReason = CheckFieldExit) OR (CheckReason = CheckFormExit)) THEN
                Copy(FormValue[FieldNo].CharValue^, S);
                TrimRear(S);
                IF (LengthOf(S) = 0) THEN
                    DisplayMessage(ModuleNumber + 4);    (* Each layout must be given a unique name. *)
                    Burp();
                    RETURN FALSE;
                END;
                Node := NetLayoutTree^.Methods^.GetFirst(NetLayoutTree);
                WHILE (Node <> NIL) DO
                    Layout := Node^.Methods^.GetDataObject(Node);
                    IF (StringsEqual(Layout^.Name, S)) THEN     (* 7/14/89 EGK *)
                        IF (Node <> LayoutOnForm) THEN
                            DisplayMessage(ModuleNumber + 4);   (* Each layout must be given a unique name. *)
                            Burp();
                            RETURN FALSE;
                        END;
                    END;
                    Node := Node^.Methods^.NextPreOrder(Node);
                END;

                RETURN TRUE;
            ELSIF (CheckReason = CheckFieldKey) THEN              (* 02-Mar-88 LAA *)
                Code := 04000H + CodeIn;
            END;

    |   NOTE :
            IF ((CheckReason = CheckFieldKey) AND (CodeIn = EditKey)) THEN  (* 03-Mar-88 LAA *)
                SaveNotesToText();
                Copy(FormValue[NAME].CharValue^, S);
                LJust(S);
                TrimRear(S);
                EditText(14,8,79,maxrow-2, ABoxType{ShadowBox,DoubleBox}, S, 0, LayoutNotes, Changed);
                SetLengthOf(FormValue[NOTE].CharValue^, 0);
                IF TextExists(LayoutNotes) THEN
                    CopyLine(LayoutNotes, 0, FormValue[NOTE].CharValue^);
                END;
                Procustes(FormValue[NOTE].CharValue^, HIGH(FormValue[NOTE].CharValue^));
                ShowValue(Form, NOTE, FormValue);
            ELSIF (CheckReason = CheckFormExit) THEN
                SaveNotesToText();
                Compress(LayoutNotes);
            ELSIF (CheckReason = CheckFieldKey) THEN              (* 02-Mar-88 LAA *)
                Code := 04000H + CodeIn;
            END;

    |   CN1,CN2,CN3,CN4,CN5,CN6 :
            
            IF (CheckReason = CheckFieldKey) THEN
                IF (CodeIn = EditKey) THEN
                    HighlightField(Form, FormValue, FieldNo, CursorResting);
                    Id := FormValue[FieldNo].CardValue;
                    IF (SearchForTaskColumn(FormValue[FieldNo].CharValue^, Id)) THEN END;  (* 20-Mar-89 LAA *)
                    IF (PickTaskColumn(maxcol-29, 3, maxcol, maxrow-10, Id, 
                                       FormValue[FieldNo].CharValue^)) THEN
                        IF (FormValue[FieldNo].CardValue <> Id) THEN
                            T := NIL;                             
                            GetColumnInfo(NIL,T,Id,ColumnWidth,maxcol,          (* 22-Dec-88 LAA *)
                                          DataRecord);
                            FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue; (* RSC 2-Feb-89 *)
                            SetFieldProtection(Form,FieldNo+1,FormValue,FALSE);  
                        END;
                        FormValue[FieldNo].CardValue := Id;
                        ShowValue(Form, FieldNo, FormValue);
                        SetFormChange(Form);

                    END;

                    (* In case column names were edited, update all column
                        names on form.  Need to do this even if PickTaskColumn
                        returns FALSE, since the user may have changed some 
                        column other than the highlighted one.  *)

                    FOR i := CN1 TO CN6 BY 2 DO
                        IF FormValue[i].CardValue <> 0 THEN
                            GetTaskColumnName(  FormValue[i].CardValue,
                                                FormValue[i].CharValue^);
                        ELSE
                            Fill(FormValue[i].CharValue^, " ", 24);
                            FormValue[i + 1].CardValue := 0;
                        END;
                    END;

                    (*  Redisplay the column names and widths  *)

                    FOR i := CN1 TO CN6+1 DO
                        ShowValue(Form, i, FormValue);
                    END;

                    HighlightField(Form, FormValue, FieldNo, CursorOff);
                ELSIF ((CodeIn = MoveUpKey) AND (FieldNo <> CN1)) THEN
                    TempField := FormValue[FieldNo];
                    FormValue[FieldNo] := FormValue[FieldNo - 2];
                    FormValue[FieldNo - 2] := TempField;
                    TempField := FormValue[FieldNo + 1];
                    FormValue[FieldNo + 1] := FormValue[FieldNo - 1];
                    FormValue[FieldNo - 1] := TempField;
                    ShowValue(Form, FieldNo, FormValue);
                    ShowValue(Form, FieldNo + 1, FormValue);
                    ShowValue(Form, FieldNo - 1, FormValue);
                    ShowValue(Form, FieldNo - 2, FormValue);
                    Code := 08000H + FieldNo - 2;
                    SetFormChange(Form);
                ELSIF ((CodeIn = MoveDownKey) AND (FieldNo <> CN6)) THEN
                    TempField := FormValue[FieldNo];
                    FormValue[FieldNo] := FormValue[FieldNo + 2];
                    FormValue[FieldNo + 2] := TempField;
                    TempField := FormValue[FieldNo + 1];
                    FormValue[FieldNo + 1] := FormValue[FieldNo + 3];
                    FormValue[FieldNo + 3] := TempField;
                    ShowValue(Form, FieldNo, FormValue);
                    ShowValue(Form, FieldNo + 1, FormValue);
                    ShowValue(Form, FieldNo + 2, FormValue);
                    ShowValue(Form, FieldNo + 3, FormValue);
                    Code := 08000H + FieldNo + 2;
                    SetFormChange(Form);
                ELSE
                    Burp();
                END;

            ELSIF ((CheckReason = CheckFieldChange)         (* 9/14/89 EGK *)
               OR (CheckReason = CheckFormExit)) THEN
                Copy(FormValue[FieldNo].CharValue^, S);
                Upshift(S);
                TrimRear(S);
                IF (LengthOf(S) = 0) THEN
                    FormValue[FieldNo].CardValue := 0;
                    FormValue[FieldNo + 1].CardValue := 0;
                    SetFieldProtection(Form, FieldNo + 1, FormValue, TRUE);
                ELSIF (NOT SearchForTaskColumn(FormValue[FieldNo].CharValue^, Id)) THEN  (* 20-Mar-89 LAA *)
                    Burp();
                    RETURN FALSE;
                END;

                IF (CheckReason = CheckFormExit) THEN             (* 23-Feb-88 LAA *)
                    i := 0;
                    INC(i, FormValue[CN1].CardValue);             (*  3-Mar-89 LAA *)
                    INC(i, FormValue[CN2].CardValue);
                    INC(i, FormValue[CN3].CardValue);
                    INC(i, FormValue[CN4].CardValue);
                    INC(i, FormValue[CN5].CardValue);
                    INC(i, FormValue[CN6].CardValue);
                    IF ((i = 0) AND (FormValue[BOX].CardValue = 0)) THEN
                        GetMessage(ModuleNumber + 7, S2);    (* Either pick a column, or turn box outlines on.  *)
                        Error(S2);
                        RETURN FALSE;
                    END;
                END;
            END;

    |   CW1,CW2,CW3,CW4,CW5,CW6 :

            IF ((CheckReason = CheckFieldExit) OR (CheckReason = CheckFormExit)) THEN
                IF (FormValue[FieldNo].CardValue > maxcol + 1) THEN
                    GetMessage(ModuleNumber + 1,S2);    (*  Column widths must be less than 80.  *)
                    Error(S2);
                    RETURN FALSE;
                END;
            END;
            IF (CheckReason = CheckFormExit) THEN                 (* 01-Mar-88 LAA *)
                j := 0;
                k := 0;
                k := Max(k, FormValue[CW1].CardValue);
                k := Max(k, FormValue[CW2].CardValue);
                k := Max(k, FormValue[CW3].CardValue);
                j := Max(j, FormValue[CW4].CardValue);
                j := Max(j, FormValue[CW5].CardValue);
                j := Max(j, FormValue[CW6].CardValue);
                IF (j + k > maxcol) THEN
                    GetMessage(ModuleNumber + 6, S2);   (*  Each pair of fields must be less than 80.  *)
                    Error(S2);
                    RETURN FALSE;
                END;
            ELSIF (CheckReason = CheckFieldKey) THEN              (* 02-Mar-88 LAA *)
                Code := 04000H + CodeIn;
            END;
    ELSE
        IF (CheckReason = CheckFieldKey) THEN                     (* 02-Mar-88 LAA *)
            Code := 04000H + CodeIn;
        END;
    END;

    RETURN TRUE;

END CheckForm;




(*----------------------------------------------------------------------------
    DoNetLayoutForm --

    Bring up the layout form to allow editing of a layout record.

    Preconditions:
        The layout parameter must be a valid layout node.

    Postconditions:
        The layout record will be changed as directed by the user, unless the
        form is left with ESC.  The code will be returned.
----------------------------------------------------------------------------*)

PROCEDURE DoNetLayoutForm(    LayoutNode    : ATreeNode)
                                                        : ACode;

VAR
    FormValue               : ARRAY [0..14] OF AFieldValue;
    Code                    : ACode;
    i                       : CARDINAL;
    Layout                  : ANetworkLayout;
    T                       : ATaskPtr;
    r                       : REAL;

BEGIN                       (* DoNetLayoutForm *)

    (*<DEBUGGING*)
    ValidateTreeNode(LayoutNode);
    (*DEBUGGING*)

    Layout := LayoutNode^.Methods^.GetDataObject(LayoutNode);
    IF ((NOT CreateTaskColumnsTree())                             (* 20-Mar-89 LAA *)
       OR (NOT AssignText(Layout^.Notes, LayoutNotes))) THEN      (* 10-Feb-88 LAA *)
        RETURN CancelKey;
    END;

    LayoutOnForm := LayoutNode;

    WITH Layout^ DO
        NEW(FormValue[NAME].CharValue);
        Copy(Name, FormValue[NAME].CharValue^);
        NEW(FormValue[NOTE].CharValue);
        SetLengthOf(FormValue[NOTE].CharValue^, 0);
        IF (TextExists(LayoutNotes)) THEN
            CopyLine(LayoutNotes, 0, FormValue[NOTE].CharValue^);
        END;
        FormValue[BOX].CardValue := ORD(BoxOutline);
        FOR i := CN1 TO CN6 BY 2 DO
            NEW(FormValue[i].CharValue);
        END;
        MapColumnSpecsToFormValue(Layout, FormValue);
    END;
    
    Code := DoForm(0,0,maxcol,GanttWEnd,150,TRUE,FormValue,CheckForm);

    IF (Code = ExitKey) THEN
        WITH Layout^ DO
            Copy(FormValue[NAME].CharValue^, Name);
            TrimRear(Name);                                       (* 11-Sep-89 WKH *)
            DiscardText(Notes);                                   (* 10-Feb-88 LAA *)
            IF (AssignText(LayoutNotes, Notes)) THEN END;
            BoxOutline := FormValue[BOX].CardValue > 0;
            MapFormValueToColumnSpecs(FormValue, Layout);
        END;

        ScheduleSaved := FALSE;                                    (* 12/15/86 LAA *)
        ConfigSaved := FALSE;
    END;
    DISPOSE(FormValue[NAME].CharValue);
    DISPOSE(FormValue[NOTE].CharValue);
    FOR i := CN1 TO CN6 BY 2 DO
        DISPOSE(FormValue[i].CharValue);
    END;
    DiscardText(LayoutNotes);                                     (* 10-Feb-88 LAA *)
    DisposeTaskColumnsTree();                                     (* 20-Mar-89 LAA *)

    RETURN Code;

END DoNetLayoutForm;


PROCEDURE TLNetFormBody();

VAR
    Context                 : POINTER TO RECORD
                                NetLayout   : ATreeNode;
                                Code        : ACode;
                              END;

    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                       (* TLNetFormBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    WITH Context^ DO
        Code := DoNetLayoutForm(NetLayout);
    END;

END TLNetFormBody;


BEGIN                       (* TLNetForm *)

    OverlayID := ImAnInstallableOverlay(TLNetFormBody, AnOverlayProc(NIL));
    TLNetFormBody();

END TLNetForm.
