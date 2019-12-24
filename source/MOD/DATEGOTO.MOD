IMPLEMENTATION MODULE DateGoto;

(*  =========================================================================
    Last Edit : May 24, 1991 1:37PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Manage a QuickPick DateList.  In other words, given any DateList,
        put it into a QuickPick list.

    MODIFICATION HISTORY:

        31-Jul-90  RSC  Added DeleteProc to the ManageDateList proc.
                        Added a param to the EditProc.

         7-Aug-90  RSC  Added parm to CopyDateList.
        23-Aug-90  RSC  Removed english text.
         4-Sep-90  RSC  Correct cursor positioning.
        18-Sep-90  CL   Removed unused DateListsAreEqual.
        11-Feb-91  TGS  Import CopyKey and treat it just like InsertKey.
        24-May-91  PFG  Changed DeleteProc to actually do the delete, not
                        just check to see if a delete is okay.  Added an
                        argument that says whether delete was done or not.
                        Also made Element a VAR param so it could be
                        changed to reflect the deleted element.  If delete
                        is done by delete proc, tree now gets rebuilt.  These
                        changes were done to fix bug #4308 where adjacent
                        entries that were identical weren't getting deleted.
    =========================================================================
*)



FROM BigTimeU   IMPORT
    (* CONST *)     MAXBIGTIME,
    (* TYPE *)      ABigTime;

FROM Codes      IMPORT
    (* TYPE *)      ACode;

FROM DateLists  IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      CreateDateList, DisposeDateList, CopyDateList,
                    GetDateListEntry, SetDateListEntryN,
                    CreateDateListEntry, DisposeDateListEntry,
                    LocateDateInDateList, NumberOfDatesInList,
                    StoreDateList, LoadDateList;

FROM Dialog     IMPORT
    (* PROC *)      Burp, NotYetImplemented;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference;

FROM GoTo       IMPORT
    (* PROC *)      DoGoTo;

FROM Kbio       IMPORT
    (* VAR  *)      maxrow, maxcol;

FROM Keys       IMPORT
    (* CONST *)     CopyKey, InsertKey, DoIt, DeleteKey, EditKey, ExitKey,
                    CancelKey;

FROM Layout     IMPORT
    (* CONST *)     GanttWStart;

FROM LStrings   IMPORT
    (* PROCS *)     SetString, ConcatS, ConcatLS, Copy, Compare, Upshift,
                    Procustes, SetLengthOf, LengthOf, StringsEqual;

FROM Menus      IMPORT
    (* PROC *)      NoYes;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM OutlineViews IMPORT
    (* TYPE *)      AnOutlineView;

FROM Space      IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE, Available, HeapAvailable;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS,
    (* PROC *)      TSIZE; 

FROM TreeObjects IMPORT
    (* TYPE *)      ATree,      ATreeNode,      ATreeOrder,
    (* PROC *)      CreateTree, CreateTreeNode, ValidateTreeNode;





CONST
    ModuleNumber    = 100;  (* For GetMessage *)




TYPE
    AContext    = RECORD
        Tree            : ATree;
        TheDateList     : ADateList;
        TheDataSize     : CARDINAL;
        TheDisplayProc  : ADateDisplayProc;
        TheEditProc     : ADateEditProc;
        TheDeleteProc   : ADateDeleteProc;
        InUse           : BOOLEAN;
        Changes         : BOOLEAN;
    END;

    AContextPtr = POINTER TO AContext;



    
    (* We store the index into the date list into the DataObject field
       of the tree nodes.  We use this weird structure to do this:
    *)
    AnElement   = RECORD
        CASE BOOLEAN OF
        | TRUE:   Adr : ADDRESS;
        | FALSE:  Ele : ADateListIndex;
        ELSE
        END;
    END;





    (* When GoTo allows context areas, this will be on the stack.
    *)
VAR
    Context     : AContext;




(* Dispose of Node

        Dispose of the TreeNode.
*)
PROCEDURE DisposeOfNode( VAR TreeNode      : ATreeNode;
                             ContextA      : ADDRESS   );
BEGIN

    IF (TreeNode <> NIL) THEN
        TreeNode^.Methods^.Discard( TreeNode );
        TreeNode := ATreeNode(NIL);
    END;

END DisposeOfNode;






(* Dispose Of Nodes

        Given a tree, dispose of the nodes, but not the tree.
        Do not alter the data objects.

    Preconditions
                    Tree  is the tree.

    Postconditions
                    Tree's nodes have been disposed of.
*)
PROCEDURE DisposeOfNodes( VAR Tree  : ATree );
BEGIN
    Tree^.Methods^.TraverseTree( Tree,
                                 ParentAfterChild, 
                                 65535, 
                                 DisposeOfNode,
                                 NIL );
END DisposeOfNodes;








(* Put Date List In A Tree

    Given the date list, create the tree.  The DataObjects are simply
    indexes into the date list, not pointers to records.
*)
PROCEDURE PutDateListInATree( VAR Context : AContext ) : BOOLEAN;
VAR
    TreeNode        : ATreeNode;
    Element         : AnElement;
    i               : ADateListIndex;
    Count           : CARDINAL;
BEGIN
    WITH Context DO
        DisposeOfNodes( Tree );  (* Clean out the tree *)

        Count := NumberOfDatesInList( TheDateList, TheDataSize );

        FOR i := 1 TO Count DO
            IF (Available( 2048 ))          AND
               (CreateTreeNode( TreeNode )) THEN
                Element.Ele := i;
                TreeNode^.Methods^.SetDataObject( TreeNode, Element.Adr );
                Tree^.Methods^.AddLast( Tree, TreeNode );  (* Last node *)
            ELSE
                DisposeOfNodes( Tree );  (* Clean out the tree *)
                RETURN FALSE;
            END;
        END;
    END;

    RETURN TRUE;

END PutDateListInATree;








(* Delete Node And Data

    Delete the passed tree node and its corresponding data item.

    Since data items are stored as INDEXes, we need to ajust all
    the following data objects to point to the index just BELOW
    the current one.

    The node is returned as the next node, or the prior.
*)
PROCEDURE DeleteNodeAndData( VAR TreeNode      : ATreeNode;
                             VAR Context       : AContext   );
VAR
    DiscardNode,
    NextNode        : ATreeNode;
    Element         : AnElement;
    i               : ADateListIndex;
BEGIN
    Element.Adr := TreeNode^.Methods^.GetDataObject( TreeNode );

    WITH Context DO
        DisposeDateListEntry( TheDateList, TheDataSize, Element.Ele );
    END;


    DiscardNode := TreeNode;
    NextNode    := TreeNode^.Methods^.GetNext( TreeNode );


    IF (NextNode = ATreeNode(NIL)) THEN
        TreeNode := TreeNode^.Methods^.GetPrev( TreeNode );
    ELSE
        TreeNode := NextNode;
    END;


    DiscardNode^.Methods^.Discard( DiscardNode );


    WHILE (NextNode <> ATreeNode(NIL)) DO
        Element.Adr := NextNode^.Methods^.GetDataObject( NextNode );
        DEC(Element.Ele);
        NextNode^.Methods^.SetDataObject( NextNode, Element.Adr );
        NextNode    := NextNode^.Methods^.GetNext( NextNode );
    END;

END DeleteNodeAndData;













PROCEDURE GoToCheckProc(    Outline     : AnOutlineView;
                            Tree        : ATree;
                        VAR Code        : ACode         );
CONST
    ResynchCode     = 511;
VAR
    OldCursorPos        : CARDINAL;
    CursorNode          : ATreeNode;
    NextNode            : ATreeNode;
    Element             : AnElement;
    WasDeleted          : BOOLEAN;




    PROCEDURE OkToEscapeForm() : BOOLEAN;
    VAR
        s : ARRAY [0..255] OF CHAR;
    BEGIN

        IF (Context.Changes) THEN
            GetMessage( ModuleNumber + 1, s ); (* "Abandon changes to the list?" *)
            RETURN (NoYes(s));
        END;

        RETURN TRUE;

    END OkToEscapeForm;



    (* Convince GoTo not to crash the machine.
    *)
    PROCEDURE Resynch( VAR CursorNode    : ATreeNode );
    VAR
        FirstNode   : ATreeNode;
    BEGIN
        FirstNode := Tree^.Methods^.GetFirst( Tree );
        IF (CursorNode = NIL) THEN
            CursorNode := FirstNode;
        END;

        Outline^.Methods^.SetFirst( Outline, FirstNode );
        Outline^.Methods^.SetCursorNode( Outline, CursorNode );

        Code := ResynchCode; (* RESYNCH ME, PLEASE, Mr. GoTo! *)

    END Resynch;





    PROCEDURE CountToNode( TreePos : ADateListIndex ) : ATreeNode;
    VAR
        Node    : ATreeNode;
    BEGIN
        Node := Context.Tree^.Methods^.GetFirst( Context.Tree );
        WHILE (Node <> ATreeNode(NIL)) AND (TreePos > 1) DO
            Node := Node^.Methods^.GetNext( Node );
            DEC(TreePos);
        END;

        RETURN Node;

    END CountToNode;



    PROCEDURE DoEdit( Ele  : ADateListIndex;
                      Edit : BOOLEAN          );
    BEGIN

        IF (Context.TheEditProc( Context.TheDateList, Ele, Edit )) THEN
            Context.Changes := TRUE;
            IF (PutDateListInATree( Context )) THEN
                CursorNode := CountToNode( Ele );
            ELSE
                CursorNode := ATreeNode(NIL);
            END;
            Resynch( CursorNode );
        ELSE
            Code := 0; (* Otherwise, we would exit back to the GoTo client. *)
        END;

    END DoEdit;


BEGIN

    CursorNode := Outline^.Methods^.GetCursorNode( Outline );
    IF (CursorNode <> NIL) THEN
        Element.Adr := CursorNode^.Methods^.GetDataObject( CursorNode );
    ELSE
        Element.Ele := 0;
    END;


    (* Based on the key typed, do something.
    *)
    CASE Code OF
    | DoIt,
      EditKey     :

        DoEdit( Element.Ele, TRUE );

    | CopyKey,
      InsertKey   :

        DoEdit( Element.Ele, FALSE );

    | DeleteKey   :

        IF ((CursorNode <> NIL) AND
            (Context.TheDeleteProc( Context.TheDateList, 
                                    Element.Ele, 
                                    WasDeleted ))) THEN
            IF (WasDeleted) THEN
                (* Rebuild tree and reset cursor.  *)
                IF (PutDateListInATree( Context )) THEN
                    CursorNode := CountToNode( Element.Ele );
                ELSE
                    CursorNode := ATreeNode(NIL);
                END;
            ELSE    (*  Do the delete here and reset cursor.  *)
                DeleteNodeAndData( CursorNode, Context );
            END;
            Context.Changes := TRUE;
            Resynch( CursorNode );
        ELSE
            Burp;
            Code := 0; (* Otherwise, we would exit back to the GoTo client. *)
        END;

    | CancelKey   :

        IF (NOT OkToEscapeForm()) THEN
            Code := 0;
        END;
    ELSE
    END;

END GoToCheckProc;












PROCEDURE GoToNameProc(     TreeNode : ATreeNode;
                        VAR Text     : ARRAY OF CHAR );
VAR
    Element     : AnElement;
BEGIN

    Element.Adr := TreeNode^.Methods^.GetDataObject( TreeNode );

    Context.TheDisplayProc( Context.TheDateList, Element.Ele, Text );

END GoToNameProc;














(* Manage Date List

    Given some callback procedures, display a GoTo list of entries from
    the DateList and allow Inserts, Deletes, and Edits.

    Preconditions

        The date list must be valid (NIL is OK)

    Postconditions

        The date list has been updated as per the customer's desires.
        The list may be completely different that it was.

    Input

        DateList    The date list to manage (edit)
        DataSize    The size of the data record, not including StartDate.
        DisplayProc The proc to call to get a printable string
        EditProc    The proc to call to edit one record.
        Title       The title for the box.

    Output

        DateList    The new list
        RETURN      TRUE iff DateList has changed.


*)
PROCEDURE ManageDateList( VAR DateList     : ADateList;
                              DataSize     : CARDINAL;
                              DisplayProc  : ADateDisplayProc;
                              EditProc     : ADateEditProc;
                              DeleteProc   : ADateDeleteProc;
                              Title        : ARRAY OF CHAR

                        ) : BOOLEAN;


    PROCEDURE ListWidth() : CARDINAL;
    CONST
        DefaultWidth = 40;
        MinimumWidth = 15;
        MaximumWidth = 75;
    VAR
        Width   : CARDINAL;
        s       : ARRAY [0..255] OF CHAR;
    BEGIN
        IF (DateList = ADateList(NIL)) THEN
            Width := DefaultWidth;
        ELSE
            DisplayProc( DateList, 1, s );
            Width := LengthOf(s) + 2;  (* Allow for the " +" area *)
            IF (Width <  MinimumWidth) THEN
                Width := MinimumWidth;
            END;
            IF (Width >  MaximumWidth) THEN
                Width := MaximumWidth;
            END;
        END;

        RETURN Width;

    END ListWidth;


VAR
    CursorNode      : ATreeNode;
    ULX,
    LRX             : CARDINAL;
    KeepChanges     : BOOLEAN;
BEGIN
    KeepChanges := FALSE;


    WITH Context DO


    (* DANGER:  This version does not support recursion, because GoTo
                does not allow a context.  We could manage our own stack
                of contexts, and a stack pointer into the context stack,
                but, until that is needed, just cry about it.
    *)
        IF (InUse) THEN HALT; END; (* No recursion now. *)

        InUse := TRUE;


        (* Create the assignment tree. *)

        IF (NOT HeapAvailable())       OR
           (NOT CreateTree( Tree )) THEN
            RETURN FALSE;
        END;



        (* Fill it in. *)

        CopyDateList( TheDateList, DateList, ExtMedium );
        TheDataSize    := DataSize;
        TheDisplayProc := DisplayProc;
        TheEditProc    := EditProc;
        TheDeleteProc  := DeleteProc;
        Changes        := FALSE;

        IF (PutDateListInATree( Context )) THEN

            CursorNode  := Tree^.Methods^.GetFirst( Tree );

                (* Compute the width of the list and center it on the screen.
                *)
            LRX         := ListWidth() + 3; (* Account for borders & shadow *)
            ULX         := (maxcol - LRX) DIV 2;
            INC(LRX,ULX);

            KeepChanges := DoGoTo ( Tree,
                                    ULX, GanttWStart + 2, LRX, maxrow - 4,
                                    Title,
                                    TRUE,
                                    GoToCheckProc,
                                    GoToNameProc,
                                    CursorNode );
        END;

        DisposeOfNodes( Tree );
        Tree^.Methods^.Discard( Tree );

        IF (KeepChanges) THEN
            DisposeDateList( DateList );
            DateList := TheDateList;
        ELSE
            DisposeDateList( TheDateList );
        END;

        InUse := FALSE;
    END;

    RETURN KeepChanges;

END ManageDateList;







BEGIN  (* module DateGoto *)

    Context.InUse := FALSE;

END DateGoto.


