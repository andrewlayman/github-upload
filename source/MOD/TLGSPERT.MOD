MODULE TLGSPERT;

(*  =========================================================================
    Last Edit : December 29, 1989 4:06PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
    30-Jan-89 LAA   Set ExportersOK to FALSE if ESC is pressed from the form.
    22-Mar-89 WKH   Restructure forms as per marketing's design.  
    22-Mar-89 WKH   Blank out Layout name if not found.
    22-Mar-89 WKH   Fix for bug #82, TimeScale=NO disallows modification of
                    Group tasks by, scale, and characters per.
    12-Apr-89 RSC   Added support for IlsaStatic.
    27-Apr-89 WKH   Start conversion for Lazlo.  Not yet completed due to
                    lack of necessary routines in Lazlo.  This is reflected
                    in the Kludge module.  When we do a compile with the
                    new LoadCommon.DEF, then we can nuke this code.
    16-May-89 WKH   Changed this form totally.  Removed fonts.
    19-May-89 WKH   Added support for color form, but it's the Gantt one.
                    Will implement Pert color palette when it's ready.
    22-May-89 WKH   Get rid of extraneous imports.
                    Also, disallow time period, task arrangement, and task
                    compression if periodic pert is not selected.
                    Furthermore, disallow shadows for round corners.
    24-May-89 WKH   Fixed problem with locating layouts, also don't allow graphic
                    of a schedule with no tasks.
    29-May-89 LAA   Adjusted for the TitleBlocks being stored in FlexStor,
                    by removing unused imports.
    09-Jun-89 WKH   Call real pert color palette.
    13-Jun-89 LAA   Added support for scrolling list of Palettes.
    10-Jul-89 WKH   Changed attribute for call to HighlightField from CursorOn
                    to CursorResting
    09-Aug-89 KKC   Add copyright message.
    23-Aug-89 WKH   Finally, don't let the form proceed if there isn't
                        A. A configured output device
                        B. A values file in the current directory
                        C. Or if the name of said values file doesn't 
                           match the name of the one listed in the
                           configuration record.
    12-Sep-89 WKH   Make pick boxes bigger for compressed video
    12-Sep-89 LAA   Removed import of Holder (no longer needed).
    25-Sep-89 EGK   Import FindNetLayoutByName from NetLUtility.
    09-Oct-89 WKH   We weren't checking to see if the old palette we saved
                    with the schedule was actually in the list of current
                    palettes.  This could happen by creating a palette that
                    is saved in the config only and then changing
                    config files.  If we don't find our palette, we set it
                    to blanks.
    13-Nov-89 RSC   Changed BTStorage to Space.
    29-Dec-89 WKH   Tag the TLGSPage record to indicate that we are
                    about to do a Pert plot.

    =========================================================================
*)
FROM Allocs                 IMPORT
                                TaskTree;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, EmptyCodeSet;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, Burp;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
                                ACursorAttribute,
    (* PROC *)                  DoForm, SetFieldProtection, ShowValue,
                                HighlightField, SetFieldHidden;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSGridStyle,  ATLGSCorner, AnOrientation,
                                ATLGSPertRecord, ATLGSPertRecordPtr,
                                ATextLine, ATLGSScale, 
                                ATLGSTitlePlacement, ATLGSChartType,
                                ATLGSTaskArrangement, ATLGSPageRecordPtr,
    (* PROC *)                  TLGSPertRecord,  TLGSPertRecordExists,
                                TLGSPageRecord;

FROM IlsaSupport            IMPORT
    (* PROC *)                  TLGSConfigIsCool;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, avidmode;

FROM Keys                   IMPORT
     (* CONST *)                CancelKey, ExitKey, DoIt, EditKey;

FROM Layout                 IMPORT MenuStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, Compare, SetLengthOf,
                                LengthOf, TrimRear, ConcatLS, Fill, CtoS,
                                ConcatS;

FROM Menus                  IMPORT
    (* VAR *)                   WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout;

FROM NetLList               IMPORT
    (* PROC *)                  SelectNetLayoutAt;

FROM NetLUtility            IMPORT
    (* PROC *)                  FindNetLayoutByName;

FROM Overlays               IMPORT
    (* VAR  *)                  PackageOK;

FROM Palettes               IMPORT
    (* PROC *)                  FindPaletteByName, SelectPalette;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TLGSTitle              IMPORT
    (* PROC *)                  EditPageDescrip;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM TypoGraph              IMPORT
    (* TYPE *)                  ATypoAttribute, ASetOfTypoAttributes,
                                ATypoPlacement, ATypoLineSpec,
                                ATypoBorderSpec, ATypoSpec;

CONST
    ModuleNumber            = 25000;

(* These are used to get messages from GetMessage *)
    NOHEAP                  = 0;
    NOCONF                  = 1;
    PERTLAYOUTTITLE         = 2;
    MUSTGIVELAYOUTNAME      = 3;
    NoTasksMsg              = 4;

(* The following are used to initialize the FormValue array *)
    LYOT                    =  0; (* Layout (press F2) *)
    PALT                    =  1; (* Palette *)
    PgDs                    =  2; (* Page description field *)
    TBST                    =  3; (* Task Boxes: Style *)
    TBCR                    =  4; (* Task Boxes: Corners *)
    TBSH                    =  5; (* Task Boxes: Shadows *)
    DLST                    =  6; (* Dependency Line: Style *)
    DLCR                    =  7; (* Dependency Line: Corners *)
    DLSH                    =  8; (* Dependency Line: Shadows *)
    PPRT                    =  9; (* Perodic PERT *)
    TMPD                    = 10; (* Time Period *)
    ATKB                    = 11; (* Arrange Tasks by *)
    ELIM                    = 12; (* Eliminate Empty Time Periods to Save Space *)

VAR
    TLGSPertInfo            : ATLGSPertRecordPtr;
    ErrorStr                : POINTER TO ARRAY[0..255] OF CHAR;

PROCEDURE CheckPERTForm(    Form        : AForm;
                            FieldNo     : AFieldNo;
                        VAR FormValue   : ARRAY OF AFieldValue;
                            CheckReason : ACheckReason;
                        VAR Code        : CARDINAL) : BOOLEAN;
CONST

    (* Coordinates for layout selection box *)
    LayoutBoxULX            = 45;
    LayoutBoxULY            = 10;
    LayoutBoxLRX            = 70;

    (* Coordinates for Palette selection box *)
    PaletteUlx              = 45;
    PaletteUly              = 10;
    PaletteLrx              = 72;

VAR
    CodeIn                  : CARDINAL;
    i                       : CARDINAL;
    ExitVal                 : BOOLEAN;
    ReturnCode              : ACode;  
    Layout                  : ANetworkLayout;
    TreeNode                : ATreeNode;
    Found                   : BOOLEAN;
    MsgString               : ARRAY [0..255] OF CHAR;
    LayoutBoxLRY            : CARDINAL; (* 12-Sep-89 WKH *)
    PaletteLry              : CARDINAL; (* 12-Sep-89 WKH *)


    PROCEDURE SetPeriodicPertFields(AllSystemsGo : BOOLEAN);

    BEGIN
        AllSystemsGo := NOT AllSystemsGo;

        SetFieldProtection(Form, TMPD, FormValue, AllSystemsGo);
        SetFieldHidden(Form, TMPD, FormValue, AllSystemsGo);

        SetFieldProtection(Form, ATKB, FormValue, AllSystemsGo);
        SetFieldHidden(Form, ATKB, FormValue, AllSystemsGo);

        SetFieldProtection(Form, ELIM, FormValue, AllSystemsGo);
        SetFieldHidden(Form, ELIM, FormValue, AllSystemsGo);

    END SetPeriodicPertFields;

    
    PROCEDURE SetShadows(    CornerType  : ATLGSCorner;
                             ShadowField : CARDINAL);

    BEGIN
        IF (CornerType = Round) THEN
            FormValue[ShadowField].CardValue := ORD(FALSE);
            SetFieldProtection(Form, ShadowField, FormValue, TRUE);
        ELSE
            SetFieldProtection(Form, ShadowField, FormValue, FALSE);
        END;
    END SetShadows;

BEGIN

    CodeIn  := Code;
    Code    := 0;
    ExitVal := TRUE;

    LayoutBoxLRY            := maxrow - 2; (* 12-Sep-89 WKH *)
    PaletteLry              := maxrow - 2; (* 12-Sep-89 WKH *)

    CASE CheckReason OF

    |   CheckFormEntry :
            CASE FieldNo OF
                PPRT : 
                    SetPeriodicPertFields(VAL(BOOLEAN, FormValue[PPRT].CardValue));

            |   TBCR : 
                    SetShadows(VAL(ATLGSCorner, FormValue[TBCR].CardValue), TBSH);

            |   DLCR : 
                    SetShadows(VAL(ATLGSCorner, FormValue[DLCR].CardValue), DLSH);

            |   PALT :          (* 9-Oct-89 WKH  *)
                    WITH FormValue[PALT] DO
                        IF (FindPaletteByName(TLGSPertChart, CharValue^) = NIL) THEN
                            SetLengthOf(CharValue^, 0);
                        END;
                    END;

            ELSE
            END;

    |   CheckFieldEntry :

    |   CheckFieldChange :
            CASE FieldNo OF
                ELIM :
            |   LYOT :
                    TrimRear(FormValue[LYOT].CharValue^);
                    IF (LengthOf(FormValue[LYOT].CharValue^) > 0) THEN
                        TreeNode := FindNetLayoutByName(FormValue[LYOT].CharValue^);
                        IF (TreeNode = NIL) THEN
                            GetMessage(ModuleNumber + MUSTGIVELAYOUTNAME, 
                                       MsgString);
                            Message(MsgString);
                            Burp();
                            ExitVal := FALSE;
                        END;
                    END;

            |   PPRT : 
                    SetPeriodicPertFields(VAL(BOOLEAN, FormValue[PPRT].CardValue));

            |   TBCR : 
                    SetShadows(VAL(ATLGSCorner, FormValue[TBCR].CardValue), TBSH);

            |   DLCR : 
                    SetShadows(VAL(ATLGSCorner, FormValue[DLCR].CardValue), DLSH);
            ELSE
            END;

    |   CheckFieldKey :
            IF ((FieldNo = LYOT) AND (CodeIn = EditKey)) THEN
                TrimRear(FormValue[LYOT].CharValue^);
                TreeNode := FindNetLayoutByName(FormValue[LYOT].CharValue^);
                GetMessage(ModuleNumber + PERTLAYOUTTITLE, MsgString);
                HighlightField(Form, FormValue, FieldNo, CursorResting);  (* 10-Jul-89 WKH *)
                ReturnCode := SelectNetLayoutAt(TreeNode, MsgString,
                                                LayoutBoxULX, LayoutBoxULY, 
                                                LayoutBoxLRX, LayoutBoxLRY);
                IF (ReturnCode <> CancelKey) THEN
                    IF (TreeNode = NIL) THEN
                        SetLengthOf(FormValue[LYOT].CharValue^,0);
                    ELSE
                        Layout := TreeNode^.Methods^.GetDataObject(TreeNode);
                        Copy(Layout^.Name, FormValue[LYOT].CharValue^);
                    END;
                ELSE
                    TrimRear(FormValue[LYOT].CharValue^);
                    TreeNode := FindNetLayoutByName(FormValue[LYOT].CharValue^);
                    IF (TreeNode = NIL) THEN
                        SetLengthOf(FormValue[LYOT].CharValue^,0);
                    END;
                END;
                ShowValue(Form, LYOT, FormValue);
                HighlightField(Form, FormValue, FieldNo, CursorOff);
            ELSIF ((FieldNo = PgDs) AND (CodeIn = EditKey)) THEN
                EditPageDescrip(Form, TLGSPertChart);
            ELSIF ((FieldNo = PALT) AND (CodeIn = EditKey)) THEN
                HighlightField(Form, FormValue, FieldNo, CursorResting);
                IF (SelectPalette(TLGSPertChart, PaletteUlx, 
                                  PaletteUly, PaletteLrx, PaletteLry,
                                  FormValue[FieldNo].CharValue^)) THEN
                    ShowValue(Form, FieldNo, FormValue);
                END;
                HighlightField(Form, FormValue, FieldNo, CursorOff);
            ELSE
                Burp();
            END;

    |   CheckFieldExit :
            IF (FieldNo = PALT) THEN
                TrimRear(FormValue[FieldNo].CharValue^);
                IF (LengthOf(FormValue[FieldNo].CharValue^) > 0) THEN
                    ExitVal := (FindPaletteByName(TLGSPertChart,
                                                FormValue[FieldNo].CharValue^)
                                                <> ATreeNode(NIL));
                    IF (NOT ExitVal) THEN
                        Burp();
                    END;
                END;
            END;

    |   CheckFormExit :
            CASE FieldNo OF
            |   LYOT :
                    TrimRear(FormValue[LYOT].CharValue^);
                    IF (LengthOf(FormValue[LYOT].CharValue^) > 0) THEN
                        TreeNode := FindNetLayoutByName(FormValue[LYOT].CharValue^);
                        IF (TreeNode = NIL) THEN
                            GetMessage(ModuleNumber + MUSTGIVELAYOUTNAME, 
                                       MsgString);
                            Error(MsgString);
                            ExitVal := FALSE;
                            Code    := CARDINAL({15}) + FieldNo; (* Goto bad field *)
                        END;
                    END;
            ELSE
            END;    
    ELSE
        FatalError();
    END;

    RETURN(ExitVal);

END CheckPERTForm;


PROCEDURE DisplayPERTForm() : ACode;

VAR
    StringToGet             : CARDINAL;
    Class                   : CARDINAL;
    Size                    : CARDINAL;
    TreePtr                 : ATreeNode;
    i                       : CARDINAL;
    Code                    : ACode;
    FormValue               : ARRAY [LYOT..ELIM] OF AFieldValue;
    ItemName                : ARRAY [0..21] OF CHAR;
    Found                   : BOOLEAN;
    TLGSPageInfo            : ATLGSPageRecordPtr;

BEGIN
    TLGSPertInfo := TLGSPertRecord();

    WITH TLGSPertInfo^ DO
        (* Cardinals *)
        FormValue[TBST].CardValue := ORD(TaskBoxStyle);
        FormValue[TBCR].CardValue := ORD(TaskBoxCorners);
        FormValue[TBSH].CardValue := ORD(TaskBoxShadows);
        FormValue[DLST].CardValue := ORD(DependLineStyle);
        FormValue[DLCR].CardValue := ORD(DependLineCorners);
        FormValue[DLSH].CardValue := ORD(DependLineShadows);
        FormValue[PPRT].CardValue := ORD(PeriodicPert);
        FormValue[TMPD].CardValue := ORD(Group) - 1; (* no hours in pert *)
        FormValue[ATKB].CardValue := ORD(TaskArrangement);
        FormValue[ELIM].CardValue := ORD(Compressed);


        (* String fields *)
        NEW(FormValue[PgDs].CharValue);
        SetString(FormValue[PgDs].CharValue^, "*");

        NEW(FormValue[PALT].CharValue);
        Copy(Palette, FormValue[PALT].CharValue^);                (* 14-Jun-89 LAA *)

        NEW(FormValue[LYOT].CharValue);
        SetLengthOf(FormValue[LYOT].CharValue^, 0);

        TrimRear(Layout);
        IF (LengthOf(Layout) > 0) THEN           (* 3/22/89 WKH *)
            TreePtr := FindNetLayoutByName(Layout);
            IF (TreePtr = NIL) THEN
                SetLengthOf(Layout, 0);
            END;
        END;
        Copy(Layout, FormValue[LYOT].CharValue^);

    END;

    Code := DoForm(0, 0, maxcol, GanttWEnd, 51, TRUE, FormValue, CheckPERTForm);

    IF (Code <> CancelKey) THEN
        ScheduleSaved := FALSE;

        WITH TLGSPertInfo^ DO
            TaskBoxStyle      := VAL(ATLGSGridStyle, FormValue[TBST].CardValue);
            TaskBoxCorners    := VAL(ATLGSCorner, FormValue[TBCR].CardValue);
            TaskBoxShadows    := VAL(BOOLEAN, FormValue[TBSH].CardValue);
            DependLineStyle   := VAL(ATLGSGridStyle, FormValue[DLST].CardValue);
            DependLineCorners := VAL(ATLGSCorner, FormValue[DLCR].CardValue);
            DependLineShadows := VAL(BOOLEAN, FormValue[DLSH].CardValue);
            Compressed        := VAL(BOOLEAN, FormValue[ELIM].CardValue);
            Group             := VAL(ATLGSScale, FormValue[TMPD].CardValue + 1);
            PeriodicPert      := VAL(BOOLEAN, FormValue[PPRT].CardValue);
            TaskArrangement   := VAL(ATLGSTaskArrangement, FormValue[ATKB].CardValue);

            TrimRear(FormValue[LYOT].CharValue^);
            Copy(FormValue[LYOT].CharValue^, Layout);
            Copy(FormValue[PALT].CharValue^, Palette);            (* 14-Jun-89 LAA *)
        END;

        TLGSPageInfo := TLGSPageRecord();               (* 29-Dec-89 WKH  *)
        TLGSPageInfo^.WhatsMyChart := TLGSPertChart;   (* 29-Dec-89 WKH  *)
    END;

    DISPOSE(FormValue[LYOT].CharValue);
    DISPOSE(FormValue[PgDs].CharValue);
    DISPOSE(FormValue[PALT].CharValue);

    RETURN(Code);

END DisplayPERTForm;


PROCEDURE TLGSPertMain();

VAR
    ErrorMessage       : ARRAY [0..255] OF CHAR;
    Copyright          : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IF (NOT TLGSConfigIsCool()) THEN
        GetMessage(ModuleNumber + NOCONF, ErrorMessage);
        Error(ErrorMessage);
        PackageOK := FALSE;
    ELSE
        IF (HeapAvailable()) THEN
            IF (DisplayPERTForm() <> ExitKey) THEN
                PackageOK := FALSE;
            END;
        ELSE
            GetMessage(ModuleNumber + NOHEAP, ErrorMessage);
            Error(ErrorMessage);
            PackageOK := FALSE;
        END;
    END;

END TLGSPertMain;


BEGIN

    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        NEW (ErrorStr);
        GetMessage(ModuleNumber + NoTasksMsg, ErrorStr^);(* "There are no tasks to graph." *)
        Error(ErrorStr^);
        DISPOSE(ErrorStr);
        PackageOK := FALSE;
        RETURN;
    ELSE
        TLGSPertMain();
    END;
END TLGSPERT.

