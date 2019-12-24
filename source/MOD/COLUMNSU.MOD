(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE ColumnSupport;

(*  =========================================================================
    Last Edit : August 29, 1990 11:32AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Supports the User-defined column names form.

    MODIFICATION HISTORY:
    22-Dec-88 LAA   Adjusted for new parameters to GetColumnInfo.
     2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
    04-Jan-89 LAA   Next column ID is now returned in CardinalValue rather
                    than RealValue.  Also used a WITH statement in 
                    GetColumnName, and called GetColumnName from 
                    SearchForColumnName to avoid duplicate code.
    10-Jan-89 RSC   Changed Storage to Space.
    16-Mar-89 LAA   Created from the old ColumnNames module, to support
                    the new Assignments Report.
    22-Aug-90 PFG   Added new parameter to PickColumn for user-defined 
                    columns.
    01-Aug-91 LAA   Added new parameter to DoGoToWithPrompts.  This made
                    necessary by a fix for bug #4772.
    =========================================================================
*)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc, AGoToCheckProc,
    (* PROC *)                  DoGoToWithPrompts;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM LStrings               IMPORT
    (* PROC *)                  Upshift, TrimFront, TrimRear, Copy, Fill,
                                LJust, SetLengthOf, StringsEqual, LengthOf;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Space                  IMPORT
    (* PROC *)                  DEALLOCATE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, 
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    
    ModuleNumber            = 28500;






    (*  DisposeColumnTree --

            Get rid of the given column name tree.

        Preconditions:
            The column name tree must have been created by a call to
            one of the CreatexxxxColumnTree procedures.

        Postconditions:
            The column tree and all it's nodes will be discarded.
    *)

PROCEDURE DisposeColumnTree(VAR ColumnTree  : ATree);

VAR
    TreeNode            : ATreeNode;
    NextNode            : ATreeNode;
    ColumnRecord        : AColumnTreeRecordPtr;

BEGIN                       (* DisposeColumnTree *)

    IF (ColumnTree <> NIL) THEN
        (*<DEBUGGING
        IF (AnxietyLevel > Calm) THEN
        END;
        DEBUGGING>*)

        TreeNode := ColumnTree^.Methods^.GetFirst(ColumnTree);
        WHILE (TreeNode <> NIL) DO
            NextNode := TreeNode^.Methods^.GetNext(TreeNode);
            ColumnRecord := TreeNode^.Methods^.GetDataObject (TreeNode);
            DISPOSE (ColumnRecord);
            TreeNode^.Methods^.Discard(TreeNode);
            TreeNode := NextNode;
        END;
        ColumnTree^.Methods^.Discard(ColumnTree);
    END;

END DisposeColumnTree;






    (*  PickColumn --

            Display the scrolling list of column names at the indicated
            coordinates, and allow the user to select one from it.

        Preconditions:
            The column name tree must have been created by a call to
            CreatexxxxColumnTree, and not discarded by DisposeColumnTree.

        Postconditions:
            The GetNameProc provides a column name given the column Id.
            The column Id will be used to position the cursor on the current
            selection.  If the user selects a new column name, the ColumnName 
            and ColumnId will be changed to that for the new column, and TRUE 
            will be returned.  If no column name is selected, FALSE will be 
            returned and nothing will be changed.
    *)

PROCEDURE PickColumn(    ColumnTree         : ATree;
                         Ulx                : ascreenx;
                         Uly                : ascreeny;
                         Lrx                : ascreenx;
                         Lry                : ascreeny;
                     VAR Title              : ARRAY OF CHAR;
                         GetNameProc        : AGoToNameProc;
                         PromptProc         : AGoToNameProc;
                         GoToCheckProc      : AGoToCheckProc;
                     VAR ColumnId           : CARDINAL;
                     VAR ColumnName         : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    Node                    : ATreeNode;
    StartNode               : ATreeNode;
    ColumnRecord            : AColumnTreeRecordPtr;
    ok                      : BOOLEAN;

BEGIN                       (* PickColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
    END;
    DEBUGGING>*)

    StartNode := ColumnTree^.Methods^.GetFirst(ColumnTree);
    IF (ColumnId > 0) THEN
        Node := StartNode;
        LOOP
            ColumnRecord := Node^.Methods^.GetDataObject(Node);
            IF (ColumnRecord^.ID = ColumnId) THEN
                StartNode := Node;
                EXIT;
            END;
            Node := Node^.Methods^.GetNext(Node);
            IF (Node = ATreeNode(NIL)) THEN
                EXIT;
            END;
        END;
    END;

    ok := DoGoToWithPrompts(ColumnTree, Ulx, Uly, Lrx, Lry, Title, TRUE,      (* 01-Aug-91 *)
                            GoToCheckProc, GetNameProc, PromptProc, 
                            ABoxType{}, StartNode);
    IF (ok) THEN
        ColumnRecord := StartNode^.Methods^.GetDataObject(StartNode);
        ColumnId := ColumnRecord^.ID;
        Copy(ColumnRecord^.Name, ColumnName);
    END;

    RETURN ok;

END PickColumn;





BEGIN                       (* ColumnSupport *)


END ColumnSupport.
