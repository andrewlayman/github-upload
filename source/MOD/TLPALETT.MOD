MODULE TLPalettes;

(*  =========================================================================
    Last Edit : February 19, 1991 6:47PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        

    MODIFICATION HISTORY:

    =========================================================================
*)


FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, ContinuationBox, FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CopyExtObject, DiscardExtObject;

FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType, ATLGSColorAssignmentPtr,
    (* VAR *)                   DefaultPalette, PaletteTree;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny,
    (* CONST *)                 maxcol;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey, InsertKey, DeleteKey,
                                DoIt, EditKey, CopyKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, LengthOf, Copy, StringsEqual,
                                TrimRear, SetString, Compare, Procustes,
                                ConcatS, ConcatLS;

FROM MsgFile                IMPORT
    (* PROC *)                  DisplayMessage, GetMessage, ConcatMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext, OverlayContext;

FROM Palettes               IMPORT
    (* TYPE *)                  AnOverlayContext,
    (* PROC *)                  DiscardPalette, GetPaletteName, CreatePalette,
                                FindPaletteByName, DoPaletteForm;

FROM Sorter                 IMPORT
    (* PROC *)                  SortTree;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTreeNode;




CONST
    ModuleNumber            = 7200; (* FROM PALETTES *)


VAR
    GlobalTree              : ATree;
    GlobalPaletteType       : ATLGSChartType;
    BlankEntry              : ATreeNode;






PROCEDURE ComparePalettes(    Palette1  : AnObject;
                              Palette2  : AnObject): BOOLEAN;

VAR
    s1, s2              : ARRAY [0..41] OF CHAR;

BEGIN                   (* ComparePalettes *)

    GetPaletteName(ATreeNode(Palette1), s1);
    GetPaletteName(ATreeNode(Palette2), s2);

    RETURN (Compare(s1, s2) > 0);

END ComparePalettes;





PROCEDURE GoToDisplayProc(    PaletteNode   : ATreeNode;
                          VAR PaletteName   : ARRAY OF CHAR);

VAR
    Palette                 : ATLGSColorAssignmentPtr;
    Standard                : BOOLEAN;

BEGIN                       (* GoToDisplayProc *)

    SetLengthOf(PaletteName, 0);
    IF (PaletteNode <> ATreeNode(NIL)) THEN
        Palette := PaletteNode^.Methods^.LockFlexStorDataObject(PaletteNode);
        Copy(Palette^.Name, PaletteName);
        Standard := (0 IN Palette^.PaletteFlags);
        PaletteNode^.Methods^.UnlockUnchangedDataObject(PaletteNode);
        Procustes(PaletteName, 20);
        IF (Standard) THEN
            ConcatS(PaletteName, " *");
        END;
    END;


END GoToDisplayProc;






PROCEDURE GoToCheckProc(    Outline     : AnOutlineView;
                            Tree        : ATree;
                        VAR Code        : ACode         );

CONST
    ResynchCode     = 511;

VAR
    CursorNode          : ATreeNode;
    NextNode            : ATreeNode;
    NewNode             : ATreeNode;
    WarningMsg          : ARRAY [0..255] OF CHAR;
    Title               : ARRAY [0..41] OF CHAR;


    (* Convince GoTo not to crash the machine.
    *)
    PROCEDURE Resynch(     CursorNode    : ATreeNode );

    VAR
        FirstNode   : ATreeNode;
        Node        : ATreeNode;
        NextNode    : ATreeNode;
        TempNode    : ATreeNode;

    BEGIN

        IF (SortTree(Tree, ComparePalettes)) THEN END;

        FirstNode := Tree^.Methods^.GetFirst( Tree );
        Outline^.Methods^.SetFirst( Outline, FirstNode );
        Outline^.Methods^.SetCursorNode( Outline, CursorNode );

        Code := ResynchCode; (* RESYNCH ME, PLEASE, Mr. GoTo! *)

    END Resynch;

BEGIN

    CursorNode := Outline^.Methods^.GetCursorNode( Outline );

    (* Based on the key typed, do something. *)

    CASE Code OF
        EditKey, InsertKey, CopyKey :
            IF ((Code = EditKey) AND (CursorNode <> BlankEntry)) THEN
                IF (DoPaletteForm(GlobalPaletteType, CursorNode) <> CancelKey) THEN
                    Resynch(CursorNode);
                END;
            ELSE
                IF ((Code = InsertKey) OR (CursorNode = ATreeNode(NIL))) THEN
                    NewNode := CreatePalette(DefaultPalette[GlobalPaletteType]);
                ELSE
                    NewNode := CreatePalette(CursorNode);
                END;
                IF (NewNode = ATreeNode(NIL)) THEN
                    DisplayMessage(ModuleNumber + 0);  (* "Unable to create a new Palette." *)
                    Burp();
                END;
                IF (CursorNode <> NIL) THEN
                    CursorNode^.Methods^.AddAfter(CursorNode, NewNode);
                ELSE
                    GlobalTree^.Methods^.AddFirst(GlobalTree, NewNode);
                END;

                IF (DoPaletteForm(GlobalPaletteType, NewNode) <> CancelKey) THEN
                    Resynch(NewNode);
                ELSE
                    DiscardPalette(NewNode);
                END;
            END;
            Code := 0;

    |   DeleteKey   :
            IF (CursorNode <> BlankEntry) THEN
                GetMessage(ModuleNumber + 1, WarningMsg);  (* "If you proceed, the Palette " *)
                GetPaletteName(CursorNode, Title);
                ConcatLS(WarningMsg, Title);
                ConcatMessage(WarningMsg, ModuleNumber + 2); (* " will be permanently deleted." *)
                GetMessage(ModuleNumber + 3, Title);         (* "Delete a Palette" *)
                IF (ContinuationBox(WarningMsg, Title, NoHelp)) THEN
                    NextNode := CursorNode^.Methods^.GetNext (CursorNode);
                    IF (NextNode = NIL) THEN
                        NextNode := CursorNode^.Methods^.GetPrev (CursorNode);
                    END;
                    DiscardPalette(CursorNode);
                    Resynch(NextNode);
                ELSE
                    Burp();
                END;
            ELSE
                Burp;
            END;
            Code := 0;
    ELSE
    END;

END GoToCheckProc;




(*  SelectPalette --

    Display a list of the palettes available in the indicated palette tree,
    and allow one to be selected.

    Preconditions:
        IlsaStatic must have been initialized by TLStart.

    Postconditions:
        If a palette is selected, TRUE will be returned and the palette name
        will be updated with the name of the newly selected palette.  Else
        FALSE will be returned and the palette name will not have been 
        changed.
*)

PROCEDURE SelectPalette(    PaletteType     : ATLGSChartType;
                            Ulx             : ascreenx;
                            Uly             : ascreeny;
                            Lrx             : ascreenx;
                            Lry             : ascreeny;
                        VAR PaletteName     : ARRAY OF CHAR ) : BOOLEAN;

VAR
    CursorNode              : ATreeNode;
    Title                   : ARRAY [0..41] OF CHAR;
    ok                      : BOOLEAN;
    
BEGIN                       (* SelectPalette *)

    GlobalTree := PaletteTree[PaletteType];
    GlobalPaletteType := PaletteType;
    BlankEntry := CreatePalette(DefaultPalette[PaletteType]);
    GlobalTree^.Methods^.AddFirst(GlobalTree, BlankEntry);
    CursorNode := FindPaletteByName(PaletteType, PaletteName);
    IF (CursorNode = NIL) THEN
        CursorNode := GlobalTree^.Methods^.GetFirst( GlobalTree );
    END;
    GetMessage(ModuleNumber + 10 + ORD(PaletteType), Title);

    ok := (DoGoTo( GlobalTree, Ulx, Uly, Lrx, Lry, Title, TRUE,
                   GoToCheckProc, GoToDisplayProc, CursorNode ));

    IF (ok) THEN
        GetPaletteName(CursorNode, PaletteName);
    END;

    DiscardPalette(BlankEntry);

    RETURN ok;

END SelectPalette;




PROCEDURE DoSelectPalette();
VAR
    Context : POINTER TO AnOverlayContext;
BEGIN
    Context           := OverlayContext();
    GlobalTree        := ATree(NIL);
    GlobalPaletteType := TLGSGanttChart;
    BlankEntry        := ATreeNode(NIL);

    WITH Context^ DO
        ReturnValue   := SelectPalette( PaletteType,
                                        Ulx, Uly, Lrx, Lry,
                                        PaletteName^ );
    END;

END DoSelectPalette;



BEGIN
    DoSelectPalette();
END TLPalettes.

