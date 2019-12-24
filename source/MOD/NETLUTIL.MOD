IMPLEMENTATION MODULE NetLUtility;


FROM Dialog                 IMPORT Burp, Message, Error, FatalError;

FROM Kbio                   IMPORT maxrow, maxcol, ascreenx, ascreeny, soundon, 
                                   avidmode;

FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Insert, Procustes, TrimFront, TrimRear, Fill, 
                                   LengthOf, Copy, LJust, SetLengthOf,
                                   Upshift, Compare, StringsEqual;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout, 
    (* VAR *)                   NetLayoutTree, CurrentNetLayout, 
                                NormalLayoutActive,
                                EnlargedNetLayout;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;


CONST
    ModuleNumber            = 20800;    (* For GetMessage. *)



PROCEDURE CompareLayouts (Node1, Node2: ATreeNode): INTEGER;

VAR
    Layout1, Layout2            : ANetworkLayout;

BEGIN
    Layout1 := Node1^.Methods^.GetDataObject (Node1);
    Layout2 := Node2^.Methods^.GetDataObject (Node2);
    RETURN Compare (Layout1^.Name, Layout2^.Name);
END CompareLayouts;





(*----------------------------------------------------------------------------
    SortNetLayouts --

    Sort the layouts in the tree into alpha order.

    Preconditions:
        InitializeNetLList must have been called.

    Postconditions:
        The NetLayoutTree will be sorted into alphabetical order.
----------------------------------------------------------------------------*)

PROCEDURE SortNetLayouts();

VAR
    Node, NextNode, TempNode    : ATreeNode;

BEGIN                       (* SortNetLayouts *)

    (*  Use an insertion sort on the layouts, because it's easy to swap
        items on a linked list.  Also, since only one item is added at a
        time to the end of the (already sorted) list, this will place the 
        new layout into the correct order with only one swap.
    *)

    Node := NetLayoutTree^.Methods^.GetFirst (NetLayoutTree);
    IF (Node <> NIL) THEN
        NextNode := Node^.Methods^.GetNext (Node);
        WHILE (NextNode <> NIL) DO
            IF (CompareLayouts (NextNode, Node) < 0) THEN
                TempNode := Node^.Methods^.GetPrev (Node);
                WHILE ((TempNode <> NIL) AND
                        (CompareLayouts (NextNode, TempNode) < 0)) DO
                    TempNode := TempNode^.Methods^.GetPrev (TempNode);
                END;
                NextNode^.Methods^.DeList (NextNode);
                IF (TempNode = NIL) THEN
                    NetLayoutTree^.Methods^.AddFirst (NetLayoutTree, NextNode);
                ELSE
                    TempNode^.Methods^.AddAfter (TempNode, NextNode);
                END;
            ELSE
                Node := NextNode;
            END;
            NextNode := Node^.Methods^.GetNext (Node);
        END;
    END;

END SortNetLayouts;




PROCEDURE DefaultLayout(    Layout          : ANetworkLayout);

VAR
    i                       : CARDINAL;

BEGIN                       (* DefaultLayout *)

    WITH Layout^ DO
        SetLengthOf(Name, 0);
        Notes := AText(NIL);
        Fields[1].ColumnID := 1;
        Fields[1].ColumnWidth := 10;
        FOR i := 2 TO 6 DO
            Fields[i].ColumnID := 0;
            Fields[i].ColumnWidth := 0;
        END;
        Height := 0;
        Width := 0;
        BoxOutline := TRUE;
        NetLFlags := {1};
    END;

END DefaultLayout;






(*----------------------------------------------------------------------------
    CreateNetLayout --

    Create a new layout, setting all fields of the layout to their default 
    values.

    Preconditions:
        None.

    Postconditions:
        The layout will be created if possible, and its fields defaulted.
        TRUE will be returned iff the layout was created.
----------------------------------------------------------------------------*)

PROCEDURE CreateNetLayout(VAR Layout           : ATreeNode)
                                                           : BOOLEAN;

VAR
    LayoutRecord            : ANetworkLayout;

BEGIN                       (* CreateNetLayout *)

    IF ((NOT HeapAvailable()) OR (NOT CreateTreeNode(Layout))) THEN  (* 10-Feb-88 LAA *)
        RETURN FALSE;
    END;

    NEW(LayoutRecord);
    IF (LayoutRecord = NIL) THEN
        Layout^.Methods^.Discard(Layout);
        RETURN FALSE;
    END;

    LayoutRecord^.Tag := ModuleNumber;
    Layout^.Methods^.SetDataObject(Layout, LayoutRecord);
    DefaultLayout(LayoutRecord);

    RETURN TRUE;

END CreateNetLayout;




(*----------------------------------------------------------------------------
    DiscardNetLayout --

    Get rid of the given layout tree node.

    Preconditions:
        The layout must be a valid layout node.

    Postconditions:
        The node and all its associated storage will be discarded.
----------------------------------------------------------------------------*)

PROCEDURE DiscardNetLayout(VAR Layout          : ATreeNode);

VAR
    LayoutRecord             : ANetworkLayout;

BEGIN                       (* DiscardNetLayout *)

    (*<DEBUGGING*)
    ValidateTreeNode(Layout);
    (*DEBUGGING>*)

    LayoutRecord := Layout^.Methods^.GetDataObject(Layout);
    LayoutRecord^.Tag := 0;
    DiscardText(LayoutRecord^.Notes);                             (* 10-Feb-88 LAA *)
    DISPOSE(LayoutRecord);

    IF (Layout = CurrentNetLayout) THEN
        CurrentNetLayout := NIL;
    END;
    IF (Layout = EnlargedNetLayout) THEN
        EnlargedNetLayout := NIL;
    END;
    Layout^.Methods^.DeList(Layout);
    Layout^.Methods^.Discard(Layout);

END DiscardNetLayout;



PROCEDURE FindNetLayoutByName(VAR LayoutName   : ARRAY OF CHAR)       (* in     *)
                                                                : ATreeNode;

VAR
    Node                    : ATreeNode;
    Layout                  : ANetworkLayout;

BEGIN                       (* FindNetLayoutByName *)

    Node := NetLayoutTree^.Methods^.GetFirst (NetLayoutTree);
    WHILE (Node <> NIL) DO
        Layout := Node^.Methods^.GetDataObject (Node);
        TrimRear(Layout^.Name);    (* 5/11/89 WKH *)
        IF (StringsEqual(Layout^.Name, LayoutName)) THEN    (* RSC 1/2/88 *)
            RETURN Node;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;

    RETURN NIL;

END FindNetLayoutByName;



BEGIN
END NetLUtility.
