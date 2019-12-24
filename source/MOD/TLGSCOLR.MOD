MODULE TLGSColr;

(*V1=TEST*)

(*  =========================================================================
    Last Edit : September 12, 1989 2:39PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        19-Dec-88 LAA   Added a new field so slack can be assigned a color.
        27-Jan-89 LAA   Wayne & I changed the definition of Name within
                        ATLGSColorAssignment from ARRAY OF CARDINAL to ARRAY
                        OF CHAR.  Also fixed a problem with use of the 
                        ColorInfo pointer.  Put in a call to SetFormChange
                        whenever a color selection may have changed.
        07-Feb-89 LAA   Changed bound of ARRAY OF AFieldValue to 25.  It's a
                        bug!!!!  We long ago added a new field, and never 
                        bumped up the array.  Oops.  Kudos to Carol for 
                        finding this one.
        16-Feb-89 LAA   Put in Carol's suggested default colors.
        22-Mar-89 LAA   Adjusted default colors for the addition of Foreground
                        and Background.
        23-Mar-89 LAA   Fixed bug with color descriptions caused by the
                        addition of Foreground and Background colors.
        12-Apr-89 RSC   Added support for IlsaStatic.
        11-May-89 WKH   Changed this to an implementation module so different
                        overlays could import this and thus we could have a
                        different color palette for every concevable type of
                        graphics chart.
        15-May-89 WKH   Added support to save color notes(not really saved in
                        data or config file yet though).
        26-May-89 LAA   The color assignments are now stored in FlexStor.  
                        Also removed the color descriptions, which are no
                        longer used here and which are stored in a different
                        way anyway.
        09-Jun-89 WKH   Added support for pert chart color form.
        11-Jun-89 LAA   Fixed a bug, where the FOR loop was going up to SLAK
                        instead of LastColor.
        13-Jun-89 LAA   Converted this module back into an overlay, which is
                        called by Palettes.
        10-Jul-89 WKH   Highlight Notes field when we "F2" it.
        09-Aug-89 KKC   Add copyright message.
        12-Sep-89 WKH   Make Color list and edit window bigger in compressed
                        video mode

    =========================================================================
*)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, EmptyCodeSet;

FROM ColorName              IMPORT
    (* CONST *)                 MaxColor,
    (* TYPE *)                  AColorRecordPtr, ATLGSColorDescTablePtr,
                                ATLGSColorDescTable,
    (* PROC *)                  DisposeColorNameTree, CreateColorNameTree,
                                SelectColor, FindColorByName,
                                FindColorByNumber;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, Error, FatalError, Burp;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
                                ACursorAttribute,
    (* PROC *)                  DoForm, ShowValue, HighlightField,
                                SetFormChange, FindFormBoundaries;

FROM IlsaStatic             IMPORT
    (* CONST *)                 TILG,  TXHD,  BRDR,  ASOF,  MJGD,  MNGD,  PAGE,  BKHD,
                                DATA,  TKBR,  F1FG,  F1BG,  F2FG,  F2BG,  F3FG,  F3BG,
                                OSTK,  AOTK,  OSBR,  AOTB,  MILE,  BASE,  ACMT,  SLAK,
                                PTILG, PTXHD, PBRDR, PPAGE, PBKHD, PBKCH, PBKTB,
                                PF1FG, PF1BG, PF2FG, PF2BG, PF3FG, PF3BG, POPST,
                                PAOTK, POPSB, PAOBX, PMSBX, PPTDP,
    (* TYPE *)                  ATLGSColorAssignment, ATLGSColorAssignmentPtr,
                                ATLGSChartType;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, avidmode;

FROM Keys                   IMPORT
     (* CONST *)                CancelKey, ExitKey, DoIt, EditKey;

FROM Layout                 IMPORT
     (* CONST *)                GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, Compare, SetLengthOf, Fill,
                                LengthOf, TrimRear, Procustes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Palettes               IMPORT
    (* PROC *)                  FindPaletteByName;

FROM Schedule               IMPORT
    (* VAR *)                   ConfigSaved;

FROM Space                  IMPORT
    (* VAR *)                   HeapAvailable,
    (* PROC *)                  ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignLine, Compress, CreateText, DiscardText,
                                CopyLine, LineExists, TextExists;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  ValidateTreeNode;

CONST
    ModuleNumber            = 25200;
    GanttFormID             = 53;
    PertFormID              = 68;

(* These are used to get messages from GetMessage *)

    NOHEAP                  = 0;
    MUSTSELECTCOLOR         = 1;
    NOTESTITLE              = 2;

    NAME                    = 0;
    NOTE                    = 1;

VAR
    TLGSColorInfo           : ATLGSColorAssignmentPtr;
    LeftColStart            : CARDINAL;
    LeftColEnd              : CARDINAL;
    RightColStart           : CARDINAL;
    RightColEnd             : CARDINAL;
    FirstField              : CARDINAL;
    LastField               : CARDINAL;
    OverlayId               : AnOverlayID;
    GlobalPaletteNode       : ATreeNode;
    GlobalPaletteType       : ATLGSChartType;

(*----------------------------------------------------------------------------
    GetColorNotes --

    Retrieve the first line of the color description text.
----------------------------------------------------------------------------*)

PROCEDURE GetColorNotes(VAR Line          : ARRAY OF CHAR;
                        VAR ColorText     : AText);

BEGIN                       (* GetColorNotes *)

    SetLengthOf(Line, 0);
    IF LineExists(ColorText, 0) THEN
        CopyLine(ColorText, 0, Line);
    END;

END GetColorNotes;




(*----------------------------------------------------------------------------
    PutColorNotes --

    Replace the first line of the color description text.
----------------------------------------------------------------------------*)

PROCEDURE PutColorNotes(VAR Line          : ARRAY OF CHAR;
                        VAR ColorText     : AText);

VAR
    s                       : ARRAY [0..80] OF CHAR;

BEGIN                       (* PutColorNotes *)

    TrimRear(Line);
    IF NOT TextExists(ColorText) THEN
        IF (ORD(Line[0]) = 0) THEN
            RETURN;
        ELSE
            ColorText := CreateText();
        END;
    END;

    IF NOT AssignLine(Line, 0, ColorText) THEN
        GetMessage( ModuleNumber + 6, s ); (* "Project description not saved: out of memory." *)
        Error(s);
    END;
    Compress(ColorText);

END PutColorNotes;


PROCEDURE CheckColorForm (   Form        : AForm;
                             FieldNo     : AFieldNo;
                         VAR FormValue   : ARRAY OF AFieldValue;
                             CheckReason : ACheckReason;
                         VAR Code        : CARDINAL) : BOOLEAN;
VAR
    CodeIn                  : CARDINAL;
    i                       : CARDINAL;
    KeyPressed              : ACode;
    ColorInfo               : AColorRecordPtr;
    ULX                     : CARDINAL;
    ULY                     : CARDINAL;
    LRX                     : CARDINAL;
    LRY                     : CARDINAL;
    ExitVal                 : BOOLEAN;
    Changed                 : BOOLEAN;
    Title                   : ARRAY [0..21] OF CHAR;


    PROCEDURE CheckColorEntry(CheckReason : ACheckReason): BOOLEAN;

    VAR
        ColorRec            : AColorRecordPtr;
        MsgString           : ARRAY [0..255] OF CHAR;

    BEGIN
        ColorRec := FindColorByName (FormValue[FieldNo].CharValue^);
        IF (ColorRec = NIL) THEN
            GetMessage(ModuleNumber + MUSTSELECTCOLOR, MsgString);
            IF (CheckReason = CheckFieldExit) THEN
                Message(MsgString);
                Burp();
            ELSE
                Error(MsgString);
            END;
            Code := CARDINAL({15}) + FieldNo; (* Jump to offending field *)
        END;

        RETURN (ColorRec <> NIL);

    END CheckColorEntry;


    PROCEDURE UniqueName(VAR PaletteName    : ARRAY OF CHAR): BOOLEAN;

    VAR
        Node                : ATreeNode;

    BEGIN                   (* UniqueName *)

        Node := FindPaletteByName(GlobalPaletteType, PaletteName);
        IF ((Node <> ATreeNode(NIL)) AND (Node <> GlobalPaletteNode)) THEN
            RETURN FALSE;
        END;

        RETURN TRUE;

    END UniqueName;


BEGIN

    CodeIn := Code;
    Code := 0;
    ExitVal := TRUE;

    CASE CheckReason OF

    |   CheckFormEntry :

    |   CheckFieldEntry :

    |   CheckFieldChange :

    |   CheckFieldKey :

            IF (CodeIn = EditKey) THEN
                IF (FieldNo >= FirstField) AND (FieldNo <= LastField) THEN
                    (* We need to position the scrolling lists of colors
                    in two different places depending upon which column
                    the field being changed is in. *)

                    IF (FieldNo >= LeftColStart) AND (FieldNo <= LeftColEnd) THEN
                        ULX := 45;
                        ULY := 7;
                        LRX := 70;
                        LRY := maxrow - 3;  (* 12-Sep-89 WKH *)
                    ELSIF (FieldNo >= RightColStart) AND (FieldNo <= RightColEnd) THEN
                        ULX := 5;
                        ULY := 7;
                        LRX := 30;
                        LRY := maxrow - 3;  (* 12-Sep-89 WKH *)
                    END;

                    (* Pass the name of the currently selected color to
                    the selection routine so that that color is
                    centered in the submenu *)

                    HighlightField (Form, FormValue, FieldNo, CursorResting);
                    KeyPressed := SelectColor (ULX, ULY, LRX, LRY,
                                            FormValue[FieldNo].CharValue^, i);  (* 27-Jan-89 LAA *)
                    HighlightField (Form, FormValue, FieldNo, CursorOff);
                    IF (KeyPressed <> CancelKey) THEN
                        ShowValue (Form, FieldNo, FormValue);
                        SetFormChange(Form);                          (* 27-Jan-89 LAA *)
                    END;
                ELSIF (FieldNo = NOTE) THEN
                    HighlightField (Form, FormValue, FieldNo, CursorResting);  (* 10-Jul-89 WKH *)
                    PutColorNotes(FormValue[NOTE].CharValue^,
                                  TLGSColorInfo^.Notes);
                    GetMessage(ModuleNumber + NOTESTITLE, Title);  (* "Palette Notes" *)
                    EditText(15,5,79,maxrow-7, ABoxType{ShadowBox, DoubleBox}, Title, ModuleNumber,
                            TLGSColorInfo^.Notes, Changed);
                    IF (Changed) THEN
                        SetFormChange( Form );
                    END;
                    GetColorNotes(FormValue[NOTE].CharValue^,
                                  TLGSColorInfo^.Notes);
                    HighlightField (Form, FormValue, FieldNo, CursorOff);
                    ShowValue(Form, NOTE, FormValue);
                ELSE
                    Burp();
                END;
            END;

    |   CheckFieldExit , CheckFormExit :
            IF (FieldNo = NAME) THEN
                ExitVal := UniqueName(FormValue[NAME].CharValue^);
                IF (NOT ExitVal) THEN
                    Burp();
                END;
            ELSIF ((FieldNo >= FirstField) AND (FieldNo <= LastField)) THEN
                ExitVal := CheckColorEntry(CheckReason);
            END;
    ELSE
        FatalError();
    END;

    RETURN (ExitVal);

END CheckColorForm;


PROCEDURE DisplayColorForm(    ColorClient : ATLGSChartType;
                               ColorNode   : ATreeNode     ) : ACode;

VAR
    Code            : ACode;
    i               : CARDINAL;
    BottomX         : CARDINAL;
    BottomY         : CARDINAL;
    FormValue       : ARRAY [0..25] OF AFieldValue;
    ColorInfo       : AColorRecordPtr;
    FormID          : CARDINAL;

BEGIN

    TLGSColorInfo := ColorNode^.Methods^.LockFlexStorDataObject(ColorNode);

    GlobalPaletteNode := ColorNode;
    GlobalPaletteType := ColorClient;

    IF (ColorClient = TLGSGanttChart) THEN  (* 09-Jun-89 WKH *)
        FormID        := GanttFormID;
        LeftColStart  := TILG;
        LeftColEnd    := TKBR;
        RightColStart := F1FG;
        RightColEnd   := SLAK;
        FirstField    := TILG;
        LastField     := SLAK;
        BottomX       := maxcol;
        BottomY       := GanttWEnd - 1;
    ELSIF (ColorClient = TLGSPertChart) THEN
        FormID        := PertFormID;
        LeftColStart  := PTILG;
        LeftColEnd    := PBKTB;
        RightColStart := PF1FG;
        RightColEnd   := PPTDP;
        FirstField    := PTILG;
        LastField     := PPTDP;
        BottomX       := maxcol;
        BottomY       := GanttWEnd - 1;
    ELSE
        FatalError();
    END;

    FOR i := 0 TO LastField DO
        NEW(FormValue[i].CharValue);
        SetLengthOf(FormValue[i].CharValue^,0);
    END;

    WITH TLGSColorInfo^ DO
        Copy(Name, FormValue[NAME].CharValue^);
        GetColorNotes(FormValue[NOTE].CharValue^, Notes);
        FOR i := FirstField TO LastField DO
            ColorInfo := FindColorByNumber(ColorFor[i]);
            IF (ColorInfo = NIL) THEN
                FatalError();
            END;
            Copy (ColorInfo^.Name, FormValue[i].CharValue^);
        END;
    END;

    Code := DoForm(0,0,BottomX,BottomY,FormID,TRUE,FormValue,CheckColorForm);

    IF (Code <> CancelKey) THEN
        WITH TLGSColorInfo^ DO
            Copy(FormValue[NAME].CharValue^, Name);
            PutColorNotes(FormValue[NOTE].CharValue^, Notes);
            FOR i := FirstField TO LastField DO                         (* 11-Jun-89 LAA *)
                ColorInfo := FindColorByName(FormValue[i].CharValue^);
                IF (ColorInfo = NIL) THEN
                    FatalError();
                END;
                ColorFor[i] := ColorInfo^.ID;
            END;
        END;
        ConfigSaved := FALSE;
    END;

    FOR i := 0 TO LastField DO
        DISPOSE(FormValue[i].CharValue);
    END;

    ColorNode^.Methods^.UnlockFlexStorDataObject(ColorNode);

    RETURN(Code);

END DisplayColorForm;


PROCEDURE CheckHeapAndDisplayMessage () : BOOLEAN;

VAR
    NoHeapMessage      : ARRAY [0..255] OF CHAR;
    Continue           : BOOLEAN;

BEGIN

    Continue := TRUE;

    IF (NOT HeapAvailable()) THEN
        GetMessage(ModuleNumber + NOHEAP, NoHeapMessage);
        Error (NoHeapMessage);
        Continue := FALSE;
    END;

    RETURN (Continue);

END CheckHeapAndDisplayMessage;


PROCEDURE ErrorMessage(    MsgNumber        : CARDINAL);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ErrorMessage *)

    GetMessage(MsgNumber, s);
    Error(s);

END ErrorMessage;



PROCEDURE EditColorDescrip();

TYPE
    APaletteFormContext     = RECORD
                                PaletteType : ATLGSChartType;
                                PaletteNode : ATreeNode;
                                ReturnCode  : ACode;
                              END;

VAR
    Context                 : POINTER TO APaletteFormContext;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN                       (* TLGSColr *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    IF (Context = NIL) THEN
        FatalError();
    END;

    IF (CheckHeapAndDisplayMessage ()) THEN
        IF (CreateColorNameTree()) THEN
            WITH Context^ DO
               ReturnCode := DisplayColorForm(PaletteType, PaletteNode);
            END;
            DisposeColorNameTree();
        ELSE
            ErrorMessage(ModuleNumber + NOHEAP);
            Context^.ReturnCode := CancelKey;
        END;
    ELSE
        Context^.ReturnCode := CancelKey;
    END;

END EditColorDescrip;



BEGIN                       (* TLGSColr *)

    OverlayId := ImAnInstallableOverlay(EditColorDescrip, AnOverlayProc(NIL));
    EditColorDescrip();

END TLGSColr.

