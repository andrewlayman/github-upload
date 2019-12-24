IMPLEMENTATION MODULE Palettes;

    (*  MODIFICATION HISTORY --
        10-Jun-89 LAA   First version.
        14-Jun-89 LAA   Continued development for first version.
        16-Jun-89 LAA   Fix to FindPaletteBy... so it'll work if the palette
                        tree is empty.
        27-Nov-89 LAA   Bug 1810.  Copying a palette (Shift-Insert) was
                        causing the two or more palettes to share the same
                        notes text.  So now, when making a palette from a
                        prototype, the notes are copied rather than just the
                        handle.
        LAA  01-Dec-89  'twas the night before code-freeze, and all through
                        the house, not a damn thing was working, not even 
                        DOS!  And I just returned from enjoying my perks, to
                        find that having a DefaultPalette shared between Gantt 
                        and PERT palettes just doesn't work!  
                        Even the identical color items are not mapped to the 
                        same element of the array.  So I changed the 
                        DefaultPalette to be an array.
    *)

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, ContinuationBox, FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CopyExtObject, DiscardExtObject;

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
    (* PROC *)                  CallOverlayWithContext;

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
    ModuleNumber            = 7200;



(*  FindPaletteByName --

    Find the tree node for a given palette name in the indicated tree of
    palettes.

    Preconditions:
        IlsaStatic must have been initialized by TLStart.

    Postconditions:
        If the palette name can be located in the indicated tree of palettes,
        its tree node will be returned.  If not, NIL will be returned.  The
        palette name will not be modified.
*)

PROCEDURE FindPaletteByName(    PaletteType : ATLGSChartType;
                                PaletteName : ARRAY OF CHAR ): ATreeNode;

VAR
    Node                    : ATreeNode;
    s                       : ARRAY [0..41] OF CHAR;

BEGIN                       (* FindPaletteByName *)

    TrimRear(PaletteName);
    Node := PaletteTree[PaletteType]^.Methods^.GetFirst(PaletteTree[PaletteType]);
    LOOP
        IF (Node = ATreeNode(NIL)) THEN
            RETURN Node;
        END;
        GetPaletteName(Node, s);
        TrimRear(s);
        IF (StringsEqual(PaletteName, s)) THEN
            RETURN Node;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

END FindPaletteByName;



(*  FindPaletteByNumber --

    Find the tree node of the Palette with ID equal to the MatchID.  Return
    NIL if there is no match.

    Preconditions:
        IlsaStatic must have been initialized, and TLStart run.

    Postconditions:
        The tree node of the matched Palette will be returned, or NIL if
        there was no match.
*)

PROCEDURE FindPaletteByNumber(     PaletteType: ATLGSChartType;
                                   MatchID    : CARDINAL      ) : ATreeNode;

VAR
    Node                    : ATreeNode;
    Palette                 : ATLGSColorAssignmentPtr;
    i                       : CARDINAL;

BEGIN                       (* FindPaletteByNumber *)

    Node := PaletteTree[PaletteType]^.Methods^.GetFirst(PaletteTree[PaletteType]);
    LOOP
        IF (Node = ATreeNode(NIL)) THEN
            RETURN Node;
        END;
        Palette := Node^.Methods^.LockFlexStorDataObject(Node);
        i := Palette^.ID;
        Node^.Methods^.UnlockUnchangedDataObject(Node);
        IF (i = MatchID) THEN
            RETURN Node;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

END FindPaletteByNumber;



(*  GetPaletteName --

    Retrieve the name of the palette, given its tree node.

    Preconditions:
        The tree node must be from one of the palette trees.

    Postconditons:
        The palette name will be returned.
*)

PROCEDURE GetPaletteName(    PaletteNode    : ATreeNode;
                         VAR PaletteName    : ARRAY OF CHAR);

VAR
    Palette                 : ATLGSColorAssignmentPtr;

BEGIN                       (* GetPaletteName *)

    SetLengthOf(PaletteName, 0);
    IF (PaletteNode <> ATreeNode(NIL)) THEN
        Palette := PaletteNode^.Methods^.LockFlexStorDataObject(PaletteNode);
        Copy(Palette^.Name, PaletteName);
        PaletteNode^.Methods^.UnlockUnchangedDataObject(PaletteNode);
    END;

END GetPaletteName;







PROCEDURE CreatePalette(    Prototype       : ATreeNode): ATreeNode;

VAR
    Node                : ATreeNode;
    Handle              : AnExtHandle;
    OldHandle           : AnExtHandle;
    Palette             : ATLGSColorAssignmentPtr;
    TempNotes           : AText;

BEGIN                   (* CreatePalette *)

    IF (Prototype = ATreeNode(NIL)) THEN
        FatalError();
    END;

    Node := ATreeNode(NIL);
    IF (CreateTreeNode(Node)) THEN
        OldHandle := AnExtHandle(Prototype^.Methods^.GetDataObject(Prototype));
        IF (CopyExtObject(OldHandle, ExtSlow, Handle)) THEN
            Node^.Methods^.SetDataObject(Node, ADDRESS(Handle));
            Palette := Node^.Methods^.LockFlexStorDataObject(Node);
            SetLengthOf(Palette^.Name, 0);
            INCL(Palette^.PaletteFlags, 1);    (* not a standard palette *)
            IF (AssignText(Palette^.Notes, TempNotes)) THEN       (* 27-Nov-89 LAA *)
                Palette^.Notes := TempNotes;
            ELSE
                Palette^.Notes := AText(NIL);
            END;
            Node^.Methods^.UnlockFlexStorDataObject(Node);
        ELSE
            Node^.Methods^.Discard(Node);
        END;
    END;

    RETURN Node;

END CreatePalette;


PROCEDURE DiscardPalette(VAR PaletteNode : ATreeNode);

VAR
    Handle              : AnExtHandle;

BEGIN                   (* DiscardPalette *)

    Handle := AnExtHandle(PaletteNode^.Methods^.GetDataObject(PaletteNode));
    DiscardExtObject(Handle);
    PaletteNode^.Methods^.DeList(PaletteNode);
    PaletteNode^.Methods^.Discard(PaletteNode);

END DiscardPalette;









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

PROCEDURE SelectPalette(    ThePaletteType     : ATLGSChartType;
                            TheUlx             : ascreenx;
                            TheUly             : ascreeny;
                            TheLrx             : ascreenx;
                            TheLry             : ascreeny;
                        VAR ThePaletteName     : ARRAY OF CHAR ) : BOOLEAN;

VAR
    Context : AnOverlayContext;
    Name    : ARRAY [0..9] OF CHAR;
    Ok      : BOOLEAN;
BEGIN

    WITH Context DO
        PaletteType := ThePaletteType;
        Ulx         := TheUlx;
        Uly         := TheUly;
        Lrx         := TheLrx;
        Lry         := TheLry;
        PaletteName := ADR(ThePaletteName);
    END;

    SetString(Name, "TLPalett");
    Ok := CallOverlayWithContext( Name, ADR(Context) );

    RETURN (Ok AND Context.ReturnValue);

END SelectPalette;



(*  DoPaletteForm --

    Display the indicated palette form, and allow the palette to be edited.

    Preconditions:
        The palette node must refer to a tree node for an existing palette.

    Postconditons:
        If the user exits the form with F10, the palette record for the 
        tree node will be changed as indicated, and the code returned.  Else,
        a code of CancelKey will be returned and the palette record will not
        be changed.
*)

PROCEDURE DoPaletteForm(    PaletteType     : ATLGSChartType;
                            PaletteNode     : ATreeNode     ) : ACode;

TYPE
    APaletteFormContext     = RECORD
                                PaletteType : ATLGSChartType;
                                PaletteNode : ATreeNode;
                                ReturnCode  : ACode;
                              END;

VAR
    Context                 : APaletteFormContext;
    s                       : ARRAY [0..41] OF CHAR;

BEGIN                       (* DoPaletteForm *)

    Context.PaletteType := PaletteType;
    Context.PaletteNode := PaletteNode;
    Context.ReturnCode := CancelKey;

    SetString(s, "|TLFBASE(TLGSColr)");
    IF (CallOverlayWithContext(s, ADR(Context))) THEN END;

    Context.PaletteNode := ATreeNode(NIL);             (* Just to be safe. *)

    RETURN Context.ReturnCode;

END DoPaletteForm;



END Palettes.

