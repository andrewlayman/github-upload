MODULE TLDevSetup;

(*  =========================================================================
    Last Edit : October 4, 1990 10:51AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        TLDevSetup   Graphics Device Setup Form        

    MODIFICATION HISTORY:

        10-May-89 LAA   First version of the GRAPHICS / Setup Form
        24-May-89 LAA   Added the scrolling list of paper size names.
        01-Jun-89 LAA   Put in changes caused by the new ConfigRecord in
                        IlsaStatic, and took the OutputToFile field off the
                        form.
        03-Jun-89 LAA   Fixed problem with all the fields being set to
                        protected, and added the ability to handle more data
                        types.
        08-Jun-89 WKH   Changed TLGSetupRecord field references so that X now
                        means Wide and Y means High.
        14-Jun-89 LAA   In CheckSetupForm, changed CodeIn from ACode to
                        CARDINAL because Forms sometimes passes bad codes into
                        the check proc.
        22-Jun-89  LAA  Put two new fields in the SetupRecord to keep around
                        the plottable area of a page, because we have to swap
                        the existing fields for Sedona if Rotate is TRUE.
        23-Jun-89 LAA   Expanded the PaperName field of the SetupFormContext
                        so it can hold "extra" information which will be
                        defined on a per-page-size basis, and used solely by
                        Sedona.
        09-Aug-89 KKC   Add copyright message.
        01-Sep-89 MWP   Add support for Output to choice.
        12-Sep-89 WKH   Make paper size box bigger in compressed video mode
        22-Sep-89 KKC   Change device name to have 255 characters.
        09-Nov-89 LAA   Moved code here from TLGSPage which determines
                        whether or not the plot area X and Y need to be
                        interchanged, or set to the papersize for continuous
                        printing.  This is necessary because the Sedona code
                        needs to know the plottable area before we ever get
                        to the TLGSPage overlay.
         4-Oct-90 RSC   Resolve version conflicts.
    =========================================================================
*)
        

FROM BalExpr                IMPORT
    (* PROC *)                  ParseExpression, ParseCardinal,
                                LStringToExpression;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM FormHand               IMPORT
    (* TYPE *)                  AFormHandle,
    (* PROC *)                  AttachHandleToFormNumber, DiscardFormHandle;

FROM Forms                  IMPORT
    (* TYPE *)                  ACheckReason, AStringValue, AForm, AFieldValue,
                                ACursorAttribute,
    (* PROC *)                  DoFormByHandle, ShowValue, SetFieldHidden,
                                SetFieldProtection, SetFormChange,
                                HighlightField;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc,
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSSetupRecordPtr, AUserUnit,
                                AGraphicsOrientation, ATLGSConfigRecordPtr;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* VAR   *)                 maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, CancelKey, EditKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWEnd, GanttWStart;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, LengthOf, CtoS,
                                TrimRear, LJust, LStringToTString, Procustes,
                                Search, Insert, Remove, Copy, SetLengthOf,
                                StringsEqual;

FROM MakeForm               IMPORT
    (* PROC *)                  AddField, StartNewGroup, AddSeparator;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM ParseReal              IMPORT
    (* PROC *)                  AmountToReal;

FROM RealFormat             IMPORT
    (* VAR *)                   DefaultAmountFormat,
    (* PROC *)                  FormatAsAmount;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignLine, CopyLine, LineExists, AssignText,
                                TextExists, DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree, CreateTreeNode;






CONST
    ModuleNumber            = 6500;

    DEV                     = 0;
    PAPR                    = 1;
    PORT                    = 2;
    CONT                    = 3;
    UNIT                    = 4;
    OUTP                    = 5;                                  (* 1-Sep-89 MWP *)
(*
    VARI                    = 5;
*)
    VARI                    = 6;
TYPE
    ASetupFormContext       = RECORD
                                DeviceName  : ARRAY [0..255] OF CHAR;
                                PaperName   : ARRAY [0..255] OF CHAR;       (* 23-Jun-89 LAA *)
                                FormChoices : AText;
                                PaperChoices: AText;
                                FormValues  : AText;
                                SetupRecord : ATLGSSetupRecordPtr;
                                ConfigRecord: ATLGSConfigRecordPtr;
                                OutputChoice: CARDINAL;
                                ReturnCode  : CARDINAL;
                              END;

    ASetupFormContextPtr    = POINTER TO ASetupFormContext;




VAR
    OverlayID               : AnOverlayID;
    Context                 : ASetupFormContextPtr;


PROCEDURE ErrorMessage(    MessageNo        : CARDINAL);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ErrorMessage *)

    GetMessage(MessageNo, s);
    Error(s);

END ErrorMessage;



PROCEDURE GetLogicalLine(    Section        : AText;
                             LogicalLine    : CARDINAL;
                         VAR PhysicalLine   : CARDINAL;
                         VAR LineOfText     : ARRAY OF CHAR)
                                                            : BOOLEAN;
CONST
    Comment                 = "-";

VAR
    i                       : CARDINAL;
    k                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* GetLogicalLine *)

    i := 0;
    k := 0;
    LOOP
        IF (NOT LineExists(Section, i)) THEN
            RETURN FALSE;
        END;
        CopyLine(Section, i, s);
        TrimRear(s);
        IF ((LengthOf(s) >= 2) AND ((s[1] <> Comment) OR (s[2] <> Comment))) THEN
            INC(k);
        END;
        IF (k = LogicalLine) THEN
            EXIT;
        END;
        INC(i);
    END;

    Copy(s, LineOfText);
    PhysicalLine := i;

    RETURN TRUE;

END GetLogicalLine;




PROCEDURE AddNewFieldsToForm(    Choices    : AText;
                                 Handle     : AFormHandle): BOOLEAN;

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    FirstOne                : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* AddNewFieldsToForm *)

    FirstOne := TRUE;
    i := 1;
    WHILE (GetLogicalLine(Choices, i, j, s)) DO
        IF (FirstOne) THEN
            IF (AddSeparator(Handle, "Ä")) THEN END;
        END;

        IF (NOT AddField(Handle, s)) THEN
                (* "Bad parameters file" *)
            ErrorMessage(ModuleNumber + 0);
            RETURN FALSE;
        END;
        IF (FirstOne) THEN
            StartNewGroup(Handle);
            FirstOne := FALSE;
        END;
        INC(i);
    END;

    RETURN TRUE;

END AddNewFieldsToForm;


PROCEDURE ParseAReal(VAR String              : ARRAY OF CHAR;
                         Expression          : CARDINAL;
                     VAR Value               : REAL         ) : BOOLEAN;

VAR
    ok                      : BOOLEAN;
    s2                      : ARRAY [0..255] OF CHAR;

BEGIN                       (* ParseAReal *)

    ok := FALSE;
    IF (ParseExpression(String, Expression, s2)) THEN
        AmountToReal(s2, Value, ok);
    END;

    RETURN ok;

END ParseAReal;




PROCEDURE GetNewFieldValues(    Choices     : AText;
                                Values      : AText;
                                StartAt     : CARDINAL;
                            VAR FormValue   : ARRAY OF AFieldValue)
                                                                   : BOOLEAN;

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;


    PROCEDURE ExtractValue(VAR Spec         : ARRAY OF CHAR;
                           VAR FieldValue   : AFieldValue  )
                                                            : BOOLEAN;

    VAR
        Type                : CARDINAL;
        ok                  : BOOLEAN;

    BEGIN                   (* ExtractValue *)

        ok := FALSE;

        IF (ParseCardinal(Spec, 2, Type)) THEN
            CASE Type OF
                1   :   NEW(FieldValue.CharValue);
                        IF (ParseExpression(Spec, 3, FieldValue.CharValue^)) THEN
                            ok := TRUE;
                        END;
            |   2   :   IF (ParseAReal(Spec, 3, FieldValue.RealValue)) THEN
                            ok := TRUE;
                        END;
            |   5,6 :   IF (ParseCardinal(Spec, 3, FieldValue.CardValue)) THEN
                            ok := TRUE;
                        END;
            ELSE
            END;
        END;

        RETURN ok;

    END ExtractValue;


BEGIN                       (* GetNewFieldValues *)

    i := 1;
    WHILE (GetLogicalLine(Choices, i, j, s)) DO
        IF (Values <> AText(NIL)) THEN
            IF (GetLogicalLine(Values, i, j, s)) THEN END;
        END;
        IF (NOT ExtractValue(s, FormValue[StartAt + i - 1])) THEN
                (*  Structural problem with section 4 of the parameters or values file.  *)
            ErrorMessage(ModuleNumber + 1);
            RETURN FALSE;
        END;
        INC(i);
    END;

    RETURN TRUE;

END GetNewFieldValues;



PROCEDURE SaveNewFieldValues(    Choices    : AText;
                                 StartAt    : CARDINAL;
                             VAR FormValue  : ARRAY OF AFieldValue;
                             VAR Values     : AText)
                                                    : BOOLEAN;

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    Type                    : CARDINAL;
    Id                      : CARDINAL;
    s, s2, Line             : ARRAY [0..255] OF CHAR;

BEGIN                       (* SaveNewFieldValues *)

    IF (NOT AssignText(Choices, Values)) THEN
        RETURN FALSE;
    END;

    i := 1;
    WHILE (GetLogicalLine(Values, i, j, s)) DO
        IF ((ParseCardinal(s, 1, Id)) AND (ParseCardinal(s, 2, Type))) THEN
            CtoS(Id, s2);
            LStringToExpression(s2, Line);
            CtoS(Type, s2);
            LStringToExpression(s2, s);
            ConcatLS(Line, s);
            CASE Type OF
                1   :   Copy(FormValue[StartAt + i - 1].CharValue^, s2);
                        DISPOSE(FormValue[StartAt + i - 1].CharValue);
            |   2   :   FormatAsAmount(FormValue[StartAt + i - 1].RealValue,
                                       DefaultAmountFormat, s2, 20, 0, 5,
                                       FALSE);
            |   5,6 :   CtoS(FormValue[StartAt + i - 1].CardValue, s2);
            ELSE
                RETURN FALSE;
            END;
            LStringToExpression(s2, s);
            ConcatLS(Line, s);
            IF (NOT AssignLine(Line, j, Values)) THEN
                RETURN FALSE;
            END;
        ELSE
            RETURN FALSE;
        END;
        INC(i);
    END;

    RETURN TRUE;

END SaveNewFieldValues;


MODULE PaperSize;

IMPORT
    (* CONST *)             ModuleNumber,
    (* PROC *)              GetLogicalLine, ErrorMessage, ParseAReal;

IMPORT
    (* TYPE *)              AGoToNameProc,
    (* PROC *)              DoGoTo, NullGoToCheckProc;

IMPORT
    (* CONST *)             maxcol,
    (* VAR   *)             maxrow;

IMPORT
    (* VAR *)               GanttWStart;

IMPORT
    (* PROC *)              TrimRear, Copy, StringsEqual, SetLengthOf;

IMPORT
    (* PROC *)              ParseCardinal, ParseExpression;

IMPORT
    (* TYPE *)              ATree, ATreeNode,
    (* PROC *)              CreateTree, CreateTreeNode;

IMPORT
    (* PROC *)              GetMessage;

IMPORT
    (* PROC *)              ALLOCATE, DEALLOCATE, HeapAvailable;

IMPORT
    (* TYPE *)              AText;

EXPORT
    (* TYPE *)              APaperSizeRecord, APaperSizeRecordPtr,
    (* PROC *)              CreatePaperSizeTree, DiscardPaperSizeTree,
                            PickPaperSize, SearchForPaperSize;
CONST
    PaperListULX            = 45;
    PaperListULY            = 10;
    PaperListLRX            = 70;

TYPE
    APaperSizeRecord        = RECORD
                                Name        : ARRAY [0..21] OF CHAR;
                                SedonaStuff : ARRAY [0..255] OF CHAR;
                                SeqNo       : CARDINAL;
                                PageX       : REAL;
                                PageY       : REAL;
                                PrintableX  : REAL;
                                PrintableY  : REAL;
                              END;

    APaperSizeRecordPtr     = POINTER TO APaperSizeRecord;

VAR
    PaperSizeTree           : ATree;
    PaperListLRY            : CARDINAL;  (* 12-Sep-89 WKH *)



PROCEDURE AddNode(VAR Spec                  : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    PaperRecord             : APaperSizeRecordPtr;
    Node                    : ATreeNode;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* AddNode *)

    IF (NOT CreateTreeNode(Node)) THEN
        RETURN FALSE;
    END;

    PaperSizeTree^.Methods^.AddLast(PaperSizeTree, Node);
    NEW(PaperRecord);
    Node^.Methods^.SetDataObject(Node, PaperRecord);

    WITH PaperRecord^ DO
        IF (NOT ParseCardinal(Spec, 1, SeqNo)) THEN RETURN FALSE; END;

        IF (NOT ParseExpression(Spec, 2, s)) THEN RETURN FALSE; END;

        IF (NOT ParseExpression(s, 1, Name)) THEN RETURN FALSE; END;
        TrimRear(Name);

        IF (NOT ParseAReal(s, 2, PageX)) THEN RETURN FALSE; END;

        IF (NOT ParseAReal(s, 3, PageY)) THEN RETURN FALSE; END;

        IF (NOT ParseAReal(s, 4, PrintableX)) THEN RETURN FALSE; END;

        IF (NOT ParseAReal(s, 5, PrintableY)) THEN RETURN FALSE; END;

        IF (NOT ParseExpression(Spec, 3, SedonaStuff)) THEN
            SetLengthOf(SedonaStuff, 0);
        END;
    END;

    RETURN TRUE;

END AddNode;



PROCEDURE CreatePaperSizeTree(    Section12 : AText)
                                                    : BOOLEAN;

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* CreatePaperSizeTree *)

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(PaperSizeTree))) THEN
        RETURN FALSE;
    END;

    i := 1;
    WHILE (GetLogicalLine(Section12, i, j, s)) DO
        IF (NOT AddNode(s)) THEN
                (*  Bad parameters file  *)
            ErrorMessage(ModuleNumber + 0);
            DiscardPaperSizeTree();
            RETURN FALSE;
        END;
        INC(i);
    END;

    RETURN TRUE;

END CreatePaperSizeTree;



PROCEDURE DiscardPaperSizeTree();

VAR
    TreeNode                : ATreeNode;
    NextNode                : ATreeNode;
    PaperRecord             : APaperSizeRecordPtr;

BEGIN                       (* DiscardPaperSizeTree *)

    IF (PaperSizeTree <> NIL) THEN
        TreeNode := PaperSizeTree^.Methods^.GetFirst(PaperSizeTree);
        WHILE (TreeNode <> NIL) DO
            NextNode := TreeNode^.Methods^.GetNext(TreeNode);
            PaperRecord := TreeNode^.Methods^.GetDataObject (TreeNode);
            DISPOSE (PaperRecord);
            TreeNode^.Methods^.Discard(TreeNode);
            TreeNode := NextNode;
        END;
        PaperSizeTree^.Methods^.Discard(PaperSizeTree);
    END;

END DiscardPaperSizeTree;



PROCEDURE SearchForPaperSize(    PaperName  : ARRAY OF CHAR)
                                                            : ATreeNode;

VAR
    Node                    : ATreeNode;
    PaperRecord             : APaperSizeRecordPtr;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* SearchForPaperSize *)

    Node := PaperSizeTree^.Methods^.GetFirst(PaperSizeTree);
    TrimRear(PaperName);
    LOOP
        PaperRecord := Node^.Methods^.GetDataObject(Node);
        Copy(PaperRecord^.Name, s);
        TrimRear(s);
        IF (StringsEqual(s, PaperName)) THEN
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
        IF (Node = ATreeNode(NIL)) THEN
            EXIT;
        END;
    END;

    RETURN Node;

END SearchForPaperSize;



PROCEDURE GetNameProc(    Node              : ATreeNode;
                      VAR Name              : ARRAY OF CHAR);

VAR
    PaperRecord             : APaperSizeRecordPtr;

BEGIN                       (* GetNameProc *)

    PaperRecord := Node^.Methods^.GetDataObject(Node);
    Copy(PaperRecord^.Name, Name);

END GetNameProc;




PROCEDURE PickPaperSize(VAR PaperName       : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    TheNode                 : ATreeNode;
    PaperRecord             : APaperSizeRecordPtr;
    ok                      : BOOLEAN;
    Title                   : ARRAY [0..255] OF CHAR;

BEGIN                       (* PickPaperSize *)

    (*<DEBUGGING
    ValidateTree(PaperSizeTree);
    DEBUGGING>*)

    GetMessage(ModuleNumber + 2, Title);

    TheNode := SearchForPaperSize(PaperName);
    IF (TheNode = ATreeNode(NIL)) THEN
        TheNode := PaperSizeTree^.Methods^.GetFirst(PaperSizeTree);
    END;

    ok := DoGoTo(PaperSizeTree, PaperListULX, PaperListULY, PaperListLRX,
                 PaperListLRY, Title, TRUE, NullGoToCheckProc, GetNameProc,
                 TheNode);
    IF (ok) THEN
        PaperRecord := TheNode^.Methods^.GetDataObject(TheNode);
        Copy(PaperRecord^.Name, PaperName);
    END;


    RETURN ok;

END PickPaperSize;


BEGIN                       (* PaperSize *)

    PaperListLRY  := maxrow - 4;  (* 12-Sep-89 WKH *)

    PaperSizeTree := NIL;

END PaperSize;





PROCEDURE CheckSetupForm (     Form        : AForm;
                               FieldNo     : AFieldNo;
                           VAR FormValue   : ARRAY OF AFieldValue;
                               CheckReason : ACheckReason;
                           VAR Code        : CARDINAL ):BOOLEAN;

VAR
    CodeIn                  : CARDINAL;
    ok                      : BOOLEAN;

BEGIN                       (* CheckSetupForm *)

    CodeIn := Code;
    Code := 0;
    ok := TRUE;

    CASE CheckReason OF
        CheckFormEntry :
                IF ((FieldNo = CONT)
                   AND (NOT Context^.SetupRecord^.AskContinuous)) THEN
                    SetFieldProtection(Form, FieldNo, FormValue, TRUE);
                    SetFieldHidden(Form, FieldNo, FormValue, TRUE);
                END;

    |   CheckFieldKey :
                IF ((FieldNo = PAPR) AND (CodeIn = EditKey)) THEN
                    HighlightField(Form, FormValue, FieldNo, CursorResting);
                    IF (PickPaperSize(FormValue[PAPR].CharValue^)) THEN
                        SetFormChange(Form);
                    END;
                    HighlightField(Form, FormValue, FieldNo, CursorOn);
                    ShowValue(Form, FieldNo, FormValue);
                ELSE
                    Burp();
                    ok := FALSE;
                END;
    |   CheckFieldExit :
                IF (FieldNo = PAPR) THEN
                    IF (SearchForPaperSize(FormValue[PAPR].CharValue^) = NIL) THEN
                            (* You must select a paper size. *)
                        DisplayMessage(ModuleNumber + 3);
                        Burp();
                        ok := FALSE;
                    END;
                END;
    ELSE
    END;

    RETURN ok;

END CheckSetupForm;









PROCEDURE DoSetupForm();

CONST
     FormID = 65;

VAR
    i                       : CARDINAL;
    PaperRecord             : APaperSizeRecordPtr;
    Node                    : ATreeNode;
    FormHandle              : AFormHandle;
    PaperFeedOrientation    : AGraphicsOrientation;
    FormValue               : ARRAY [0..24] OF AFieldValue;
    s                       : ARRAY [0..255] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    IF (Context = NIL) THEN                 (* Called the wrong way! *)
        FatalError();
    END;

    WITH Context^ DO
        ReturnCode := CancelKey;

        IF (NOT AttachHandleToFormNumber(FormHandle, FormID)) THEN
                (* Not enough memory to bring up the GRAPHICS / Setup Form. *)
            ErrorMessage(ModuleNumber + 4);
            RETURN;
        END;

        IF (NOT CreatePaperSizeTree(PaperChoices)) THEN
                (* Not enough memory to bring up the GRAPHICS / Setup Form. *)
            ErrorMessage(ModuleNumber + 4);
            DiscardFormHandle(FormHandle);
            RETURN;
        END;

        IF ((AddNewFieldsToForm(Context^.FormChoices, FormHandle))
           AND (GetNewFieldValues(FormChoices, FormValues, VARI, FormValue))) THEN
            WITH SetupRecord^ DO
                NEW(FormValue[DEV].CharValue);
                Copy(DeviceName, FormValue[DEV].CharValue^);
                NEW(FormValue[PAPR].CharValue);
                IF (NOT ParseExpression(PaperName,1,FormValue[PAPR].CharValue^)) THEN
                    SetLengthOf(FormValue[PAPR].CharValue^, 0);
                END;
                FormValue[PORT].CardValue := ORD(Orientation);
                FormValue[CONT].CardValue := ORD(ContinuousPrint);
            END;
            FormValue[UNIT].CardValue := ORD(ConfigRecord^.Units);
            FormValue[OUTP].CardValue := OutputChoice;         (* 1-Sep-89 MWP *)

            ReturnCode := DoFormByHandle(2, 0, maxcol, GanttWEnd, FormHandle,
                                         TRUE, FormValue, CheckSetupForm);

            IF (ReturnCode = ExitKey) THEN
                WITH SetupRecord^ DO
                        (*  Deal with the "stuff" that can come after the
                            paper name.                                     *)

                    Node := SearchForPaperSize(FormValue[PAPR].CharValue^);
                    PaperRecord := Node^.Methods^.GetDataObject(Node);
                    LStringToExpression(PaperRecord^.Name, PaperName);
                    LStringToExpression(PaperRecord^.SedonaStuff, s);
                    ConcatLS(PaperName, s);
                    PhysPageWide := PaperRecord^.PageX;
                    PhysPageHigh := PaperRecord^.PageY;
                    OrigPlotAreaWide := PaperRecord^.PrintableX;   (* 22-Jun-89 LAA *)
                    OrigPlotAreaHigh := PaperRecord^.PrintableY;

                    Orientation := VAL(AGraphicsOrientation,
                                       FormValue[PORT].CardValue);
                    ContinuousPrint := (FormValue[CONT].CardValue <> 0);

                    IF (PhysPageWide <= PhysPageHigh) THEN        (* 09-Nov-89 LAA *)
                        PaperFeedOrientation := Portrait;
                    ELSE                                                      
                        PaperFeedOrientation := Landscape;
                    END;

                    IF ((PhysPageWide <> PhysPageHigh) 
                         AND (Orientation <> PaperFeedOrientation)) THEN
                        PlotAreaHigh := OrigPlotAreaWide;                     (* 22-Jun-89 LAA *)
                        IF (ContinuousPrint) THEN
                            PlotAreaWide := PhysPageHigh;
                        ELSE
                            PlotAreaWide := OrigPlotAreaHigh;
                        END;
                    ELSE
                        PlotAreaWide := OrigPlotAreaWide;
                        IF (ContinuousPrint) THEN
                            PlotAreaHigh := PhysPageHigh;
                        ELSE
                            PlotAreaHigh := OrigPlotAreaHigh;
                        END;
                    END;
                END;
                ConfigRecord^.Units := VAL(AUserUnit,FormValue[UNIT].CardValue);

                OutputChoice := FormValue[OUTP].CardValue;

                IF (NOT SaveNewFieldValues(FormChoices,VARI,FormValue,FormValues)) THEN
                        (*  Unable to save your setup choices to disk.  *)
                    ErrorMessage(ModuleNumber + 5);
                    ReturnCode := CancelKey;
                END;
            END;

            DISPOSE(FormValue[DEV].CharValue);
            DISPOSE(FormValue[PAPR].CharValue);
        END;

        DiscardPaperSizeTree();
        DiscardFormHandle(FormHandle);
    END;

END DoSetupForm;




BEGIN

    OverlayID := ImAnInstallableOverlay( DoSetupForm, AnOverlayProc(NIL) );
    DoSetupForm();

END TLDevSetup.
