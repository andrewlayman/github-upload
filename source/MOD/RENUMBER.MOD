IMPLEMENTATION MODULE Renumber;

(*  =========================================================================
    Last Edit : 02-Aug-1989 05:04PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Handles renumbering of sequence numbers in tasks, filters,
        resources, etc...


    MODIFICATION HISTORY :

        01-Aug-89 WKH   Initial version extracted from TLITL4.
    =========================================================================
*)

FROM Allocs                 IMPORT 
    (* TYPE *)                  ATask, ATaskPtr,
    (* VAR  *)                  TaskTree;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  LayoutTree;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer,
    (* VAR  *)                  FilterTree;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSColorAssignmentPtr, ATLGSChartType,
    (* VAR *)                   PaletteTree;

FROM Memos                  IMPORT
    (* TYPE *)                  AMemoRecordPointer,
    (* VAR  *)                  MemoTree;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR  *)                  NetLayoutTree;

FROM ObjectID               IMPORT
    (* PROC *)                  NewID, InitializeIDs;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer,
    (* VAR  *)                  ResourceTree;

FROM SYSTEM                 IMPORT 
    (* TYPE *)                  ADDRESS;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;

FROM Undo                   IMPORT
    (* PROC *)                  FlushUndos;


CONST
    ModuleNumber            = 81;


PROCEDURE NumberTheTask(VAR Node    : ATreeNode;
                            Context : ADDRESS);

VAR
    TaskPtr                 : ATaskPtr;

BEGIN
    TaskPtr         := Node^.Methods^.LockFlexStorDataObject (Node);
    TaskPtr^.TaskID := NewID();
    Node^.Methods^.UnlockFlexStorDataObject(Node);
END NumberTheTask;


PROCEDURE NumberTheResource(VAR Node    : ATreeNode;
                                Context : ADDRESS);

VAR
    ResourcePtr             : AResourcePointer;

BEGIN
    ResourcePtr     := Node^.Methods^.GetDataObject(Node);
    ResourcePtr^.ID := NewID();
END NumberTheResource;


PROCEDURE NumberTheLayout(VAR Node    : ATreeNode;
                              Context : ADDRESS);

VAR
    LayoutPtr               : AChartFormatPtr;

BEGIN
    LayoutPtr     := Node^.Methods^.GetDataObject(Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheLayout;


PROCEDURE NumberTheNetLayout(VAR Node    : ATreeNode;
                                 Context : ADDRESS);

VAR
    LayoutPtr               : ANetworkLayout;

BEGIN
    LayoutPtr     := Node^.Methods^.GetDataObject(Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheNetLayout;


PROCEDURE NumberTheFilter(VAR Node    : ATreeNode;
                              Context : ADDRESS   );

VAR
    FilterPtr               : AFilterRecordPointer;

BEGIN
    FilterPtr     := Node^.Methods^.LockFlexStorDataObject(Node);
    FilterPtr^.ID := CARDINAL(NewID());
    Node^.Methods^.UnlockFlexStorDataObject(Node);   
END NumberTheFilter;


PROCEDURE NumberThePalette(VAR Node    : ATreeNode;        (* 16-Jun-89 LAA *)
                               Context : ADDRESS  );

VAR
    Palette                 : ATLGSColorAssignmentPtr;

BEGIN                       (* NumberThePalette *)

    Palette     := Node^.Methods^.LockFlexStorDataObject(Node);
    Palette^.ID := CARDINAL(NewID());
    Node^.Methods^.UnlockFlexStorDataObject(Node);

END NumberThePalette;


PROCEDURE NumberTheMemo(VAR Node    : ATreeNode;
                            Context : ADDRESS);

VAR
    MemoPtr                 : AMemoRecordPointer;

BEGIN
    MemoPtr     := Node^.Methods^.GetDataObject(Node);
    MemoPtr^.ID := CARDINAL(NewID());
END NumberTheMemo;


PROCEDURE RenumberEverything();

BEGIN
    InitializeIDs (0);

    TaskTree^.Methods^.TraverseTree(TaskTree, ParentAfterChild, 9999,
                                    NumberTheTask, NIL);

    ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentAfterChild, 9999,
                                        NumberTheResource, NIL);

    FilterTree^.Methods^.TraverseTree(FilterTree, ParentAfterChild, 9999,
                                      NumberTheFilter, NIL);

    LayoutTree^.Methods^.TraverseTree(LayoutTree, ParentAfterChild, 9999,
                                      NumberTheLayout, NIL);

    NetLayoutTree^.Methods^.TraverseTree(NetLayoutTree,ParentAfterChild,9999,  (* 17-Nov-87 LAA *)
                                         NumberTheNetLayout, NIL);

    MemoTree^.Methods^.TraverseTree (MemoTree, ParentAfterChild, 9999,
                                     NumberTheMemo, NIL);

    PaletteTree[TLGSGanttChart]^.Methods^.TraverseTree(PaletteTree[TLGSGanttChart],
                                                       ParentAfterChild, 9999,
                                                       NumberThePalette, 
                                                       NIL);

    PaletteTree[TLGSPertChart]^.Methods^.TraverseTree(PaletteTree[TLGSPertChart],
                                                      ParentAfterChild, 9999,
                                                      NumberThePalette, 
                                                      NIL);

    PaletteTree[TLGSTreeChart]^.Methods^.TraverseTree(PaletteTree[TLGSTreeChart],
                                                      ParentAfterChild, 9999,
                                                      NumberThePalette, 
                                                      NIL);

    FlushUndos();                                       (* 3/18/88 EGK *)
END RenumberEverything;

END Renumber.
