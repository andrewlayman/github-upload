MODULE TLMakStd;
(*
Modifications:
     10-Aug-89  KKC - Add copyright message.
     10-Oct-89  MWP - Moved text literal to phrases file.
     22-May-90  LAA - Removed the above change (not necessary since this is
                      a utility, and not shipped), and added code to make
                      everything standard, not just palettes.
*)

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR *)                   LayoutTree;

FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer,
    (* VAR *)                   FilterTree;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType, ATLGSColorAssignmentPtr,
    (* VAR *)                   PaletteTree;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;

VAR
    i                       : ATLGSChartType;
    s                       : ARRAY [0..255] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;


PROCEDURE MarkAsStandardPalette(VAR Node           : ATreeNode;
                                    Context        : ADDRESS  );

VAR
    Palette                 : ATLGSColorAssignmentPtr;

BEGIN                       (* MarkAsStandardPalette *)

    Palette := Node^.Methods^.LockFlexStorDataObject(Node);
    INCL(Palette^.PaletteFlags, 0);
    Node^.Methods^.UnlockFlexStorDataObject(Node);

END MarkAsStandardPalette;


PROCEDURE MarkAsStandardLayout( VAR Node           : ATreeNode;
                                    Context        : ADDRESS  );

VAR
    Layout                  : AChartFormatPtr;

BEGIN                       (* MarkAsStandardLayout *)

    Layout := Node^.Methods^.GetDataObject( Node );
    INCL(Layout^.LayoutFlags, 0);

END MarkAsStandardLayout;


PROCEDURE MarkAsStandardNetLayout( VAR Node       : ATreeNode;
                                       Context    : ADDRESS  );

VAR
    NetLayout               : ANetworkLayout;

BEGIN                       (* MarkAsStandardNetLayout *)

    NetLayout := Node^.Methods^.GetDataObject( Node );
    INCL( NetLayout^.NetLFlags, 0 );

END MarkAsStandardNetLayout;



PROCEDURE MarkAsStandardFilter( VAR Node       : ATreeNode;
                                    Context    : ADDRESS  );

VAR
    Filter                  : AFilterRecordPointer;

BEGIN                       (* MarkAsStandardFilter *)

    Filter := Node^.Methods^.LockFlexStorDataObject( Node );
    INCL( Filter^.FilterFlags, 0 );
    Node^.Methods^.UnlockFlexStorDataObject( Node );

END MarkAsStandardFilter;





BEGIN                       (* TLMakStd *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    FOR i := TLGSGanttChart TO TLGSTreeChart DO
        PaletteTree[i]^.Methods^.TraverseTree(PaletteTree[i],
                                              ParentBeforeChild,
                                              9999,
                                              MarkAsStandardPalette,
                                              NIL);
    END;

    LayoutTree^.Methods^.TraverseTree(LayoutTree,
                                      ParentBeforeChild, 9999,
                                      MarkAsStandardLayout, NIL );

    NetLayoutTree^.Methods^.TraverseTree( NetLayoutTree,
                                          ParentBeforeChild, 9999,
                                          MarkAsStandardNetLayout, NIL );

    FilterTree^.Methods^.TraverseTree( FilterTree, 
                                       ParentBeforeChild, 9999,
                                       MarkAsStandardFilter, NIL );

    SetString(s, "All Palettes, Layouts have been made standard.");
    Error(s);

END TLMakStd.
