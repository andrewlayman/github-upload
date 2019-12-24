IMPLEMENTATION MODULE AssList;

(*  =========================================================================
    Last Edit : June 11, 1991 6:33PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        AssList - Provide a TREE of assignment record indexes.  This aids
                  editing the list of assignments, and allows the use of
                  GoTo.

                  The clients as of 11-Jun-91 are TLASLIST and ASSFORMS.


    MODIFICATION HISTORY:

    21-Apr-89  RSC  First Version.  See "EDITRSRC.QA" for the documentation
                    on the feature this implements.
     5-May-89  RSC  Set recalc flag.  Match editing for the task form.
    18-May-89  RSC  Removed "ZeroAssignmentWork", which is not usefull now.
                    Also "IsThereAssignmentWork" and "FindAssignmentErrors".
    22-May-89  RSC  SF8 resource list crashed, because "GlobalTree" was non-nil
                    after the assignment tree had been deleted.
     1-Jun-89  RSC  Support AssUtilities.
     4-Jun-89 EGK   Changed "ResourceDeleted" to "DeleteAResource" (big deal)
     5-Jun-89  RSC  1) Removed reference to AdvancedTaskForm.
                    2) Make Assignment list higher, add "Assignments of " before
                       the task name for the title.
    13-Jun-89  AJL  Made the list title string longer; on long task names it
                    would fail.
    13-Jun-89  RSC  Uh, um, well, I, er, ah, created assignments with ExtFast
                    rather than ExtMedium, and so assignments went onto the
                    heap.  Sorry....
    26-Jun-89  RSC  Don't sort the tree.
    12-Oct-89  RSC  Don't allow partial lists because it throws off recalcs.
                    I tried other fixes which would preserve functionality,
                    but they were much to prone to dangling pointers and
                    machine rebooting.  So, since the code is slushy,
                    I will go for the "Most chance of working" fix.
    25-Oct-89  RSC  removed "spurious" Burp for bug 1605.  I expect that the
                    next revision for this module will read something like
                    "Add a burp when hitting ESC of resource list".
    30-May-90  AJL  Initialize more of the assignment record.  Do this by calling
                    the InitAssignment procedure from Assignments.
     9-Jul-90  RSC  update for new assignment procedures to COPY and DISPOSE.

     7-Aug-90  RSC  Change DoGoTo to DoGoToWithPrompts.
    10-Aug-90  RSC  Update SummAssignments parameters.

    22-Aug-90  RSC  Ajusted calls to reflect no tree type and the fact that
                    nodes do not point to actual records.  This removed a
                    LOT of code and global data.

    25-Sep-90  CL   Removed unused CopyOneAssignmentRecord and
                    RemoveAssignmentsAndExpenses from IMPORT.
    26-Sep-90 PFG   Fixed a bug in DisposeOfAssignmentNodeAndData where if 
                    you deleted the last resource Time Line would crash.
    22-Jan-91  RSC  Import LongDurationToString from LongDuration rather than
                    from TimeFormat.
    29-Jan-91 TGS   Disallow duplicate resource assignments.
     5-Feb-91 RSC   Fixed logic where we were derefrencing a 000:000 pointer.
                    bug # 4103.
    14-Feb-91 RSC   Put the resource ID numbers into the assignment tree.
                    This aids Assignme.Mod, who has to see if a resource
                    being deleted is in use.
    11-Jun-91 RSC   Remove the EditAssignmentList proc and its related
                    imported modules in order to cut down the size of the
                    TLCHANGE overlay.
    =========================================================================
*)




FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr, AnAssignmentSummary, AStartStatus,
                        ARollupStatus, ATaskStatus;

FROM Assignments    IMPORT
    (* TYPES *)         AnAssignmentRecord,     AnAssignmentArray,
                        AnAssignmentAttribute,  AnAssignmentAttributeSet,
                        AnAssignmentPointer,
    (* PROCS *)         ForEachAssignment,     
                        InitAssignment,         
                        DisposeOneAssignmentRecordContents;

FROM Dialog         IMPORT
    (* PROCS *)         Error, FatalError, Burp;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle,             AnExtStoragePreference,
    (* PROC *)          NumberOfElements,        ArraySize,
                        LockObjectArray,         ReleaseObject,
                        ReleaseUnchangedObject,
                        SetExtSize,              GetExtSize,
                        CreateExtObject,         DiscardExtObject;

FROM LStrings       IMPORT
    (* PROCS *)         SetString, ConcatS, ConcatLS, Copy, Compare, Upshift,
                        Procustes, SetLengthOf, LengthOf, StringsEqual,
                        Fill, CtoS, RJust, TrimRear, Insert;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage, ConcatMessage;

FROM RsrcCalc       IMPORT
    (* TYPE *)          AnAssignmentCostType, AnAssignmentCostTypeSet,
    (* PROC *)          ComputeTaskNodeCosts, SummTaskNodeAmounts;

FROM RsrcMod        IMPORT
    (* CONST *)         ResourceNameLength,
    (* TYPE *)          AResourcePointer, AResourceType, ACostStyle,
    (* VAR *)           ResourceTree,
    (* PROC *)          FindResourceByName;

FROM StatusChange   IMPORT
    (* PROC *)          CheckStatusChange, DefaultStatusDialogProc;

FROM SYSTEM         IMPORT
    (* TYPE *)          TSIZE, ADR, ADDRESS;

FROM Timei          IMPORT
    (* TYPE *)          ADurationUnit, ADate;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree,      ATreeNode,      ATreeOrder,
    (* PROC *)          CreateTree, CreateTreeNode, ValidateTreeNode;






CONST
    ModuleNumber        = 4900;     (* For GetMessage *)



VAR
    GlobalScale             : ADurationUnit;






(*  Dispose Of Assignment Node

    Dispose of a single tree node.

    Preconditions
                    Node    The tree node from within an assignment tree
                            built by "PutAssignmentsInATree".
                    Context context returned by "PutAssignmentsInATree",
                            phrases as an address so that "ForAllNodes"
                            works.
    Postconditions
                    TreeNode        Deallocated and Delisted.
                                    Data object unchanged.
*)
PROCEDURE DisposeOfAssignmentNode( VAR TreeNode     : ATreeNode;
     (* AnAssignmentTreeContext *)     Context      : ADDRESS );
BEGIN

    IF (TreeNode <> NIL) THEN
        TreeNode^.Methods^.Discard( TreeNode );
        TreeNode := ATreeNode(NIL);
    END;

END DisposeOfAssignmentNode;








(* Dispose Of Assignment Nodes

        Given a tree of assignment records, dispose of the nodes,
        but not the tree, and NOT THE DATA.

    Preconditions
                    AssignmentTree  is the assignment tree.
                    Context context returned by "PutAssignmentsInATree",

    Postconditions
                    AssignmentTree's nodes have been disposed of.
*)
PROCEDURE DisposeOfAssignmentNodes( AssignmentTree : ATree;
                                    Context        : AnAssignmentTreeContext );
BEGIN
    IF (AssignmentTree <> ATree(NIL)) THEN
        AssignmentTree^.Methods^.TraverseTree( AssignmentTree,
                                               ParentAfterChild, 
                                               65535, 
                                               DisposeOfAssignmentNode,
                                               NIL );
    END;
END DisposeOfAssignmentNodes;







(* Get Assignment Info From Tree

        Given a tree node from within an assignment tree, return the
        flexstor handle and index of the actual record.

    Preconditions

            The node must be from within a tree built by
            "PutAssignmentsInATree".  The context is the context
            returned by that routine.

    Postconditions

            No data is changed in the tree, only information is
            returned.

    Input:
        Node    The tree node from within an assignment tree built by
                "PutAssignmentsInATree".
        Context context returned by "PutAssignmentsInATree".

    Output:
        Handle  FlexStor handle of the assingment array
        Index   index into that handle, starting with index 0.
*)
PROCEDURE GetAssignmentInfoFromTree(     Node          : ATreeNode;
                                         Context       : AnAssignmentTreeContext;
                                     VAR Handle        : AnExtHandle;
                                     VAR Index         : CARDINAL;
                                     VAR TaskNode      : ATreeNode
                                   );
VAR
    IndexAddr   : ADDRESS;
BEGIN
    IF (Node = NIL) THEN
        Index := 0;
    ELSE
        IndexAddr := Node^.Methods^.GetDataObject( Node );
        Index     := IndexAddr.OFFSET;
    END;

    Handle     := Context.AssignmentHandle;
    TaskNode   := Context.TaskNode;

END GetAssignmentInfoFromTree;








(* Get Assignment Record From Tree

        Given a tree node from within an assignment tree, return the
        actual assignment record referenced.

    Preconditions

            The node must be from within a tree built by
            "PutAssignmentsInATree".  The context is the context
            returned by that routine.

    Postconditions

            No data is changed in the tree, only information is
            returned.

    Input:
        Node    The tree node from within an assignment tree built by
                "PutAssignmentsInATree".
        Context context returned by "PutAssignmentsInATree".

    Output:
        Assignment    is the pointer to the assignment record.
        ReleaseHandle is the FlexStor handle to release when done using
                         the record.

            DANGER!! The flexstor handle "ReleaseHandle" must be released
                     soon, as this data is LOCKED DOWN.
*)
PROCEDURE GetAssignmentPointerFromTree(     Node          : ATreeNode;
                                            Context       : AnAssignmentTreeContext;
                                        VAR Assignment    : AnAssignmentPointer;
                                        VAR ReleaseHandle : AnExtHandle );
VAR
    Count,
    Index       : CARDINAL;
    TaskNode    : ATreeNode;
    Assignments : AnAssignmentArray;
BEGIN

    GetAssignmentInfoFromTree( Node, Context, ReleaseHandle, Index, TaskNode );
    Count := LockObjectArray( ReleaseHandle, Assignments, TSIZE( AnAssignmentRecord ) );
    IF (Count <= Index) THEN
        FatalError();
    END;

(*$O-*)
    Assignment := ADR(Assignments^[Index]);
(*$O=*)

END GetAssignmentPointerFromTree;







(* Set up the internal context, and change the task record.

    Call this when the assignment handle changes (is deleted or created)
*)
PROCEDURE SetContext(     NewAssHandle      : AnExtHandle;
                      VAR Context           : AnAssignmentTreeContext );
VAR
    TaskPtr : ATaskPtr;
BEGIN
    WITH Context DO
        AssignmentHandle := NewAssHandle;
        TaskPtr          := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        TaskPtr^.Plan.Assignments := NewAssHandle;
        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
    END;
END SetContext;










(*  Dispose Of Assignment Node And Data

    Dispose of a single tree node and its data node.

    Preconditions
                    Node    The tree node from within an assignment tree
                            built by "PutAssignmentsInATree".
                    Context context returned by "PutAssignmentsInATree",
    Postconditions
                    Data object DELETED.

                    TreeNode        The NEXT (or PRIOR if no NEXT) node.
                                    could be NIL.
*)
PROCEDURE DisposeOfAssignmentNodeAndData( VAR TreeNode     : ATreeNode;
                                          VAR Context      : AnAssignmentTreeContext );
VAR
    Assignments : AnAssignmentArray;
    TaskNode    : ATreeNode;
    Handle      : AnExtHandle;
    DiscardNode,
    NextNode    : ATreeNode;
    IndexAddr   : ADDRESS;
    Count,
    i,
    Index       : CARDINAL;
    ok          : BOOLEAN;
BEGIN
    GetAssignmentInfoFromTree( TreeNode, Context, Handle, Index, TaskNode );

    Count := LockObjectArray( Handle, Assignments, TSIZE( AnAssignmentRecord ) );

(*$O-*)
    DisposeOneAssignmentRecordContents(Assignments^[Index]);
    i := Index;
    WHILE ((Count > 1) AND (i < Count - 1)) DO      (* 26-Sep-90 PFG *)
        Assignments^[i] := Assignments^[i+1];
        INC(i);
    END;
(*$O=*)
    ReleaseObject( Handle );

    IF (Count = 1) THEN
        DiscardExtObject( Handle );
        SetContext( AnExtHandle(NIL), Context );
    ELSE
        (* Since we are shrinking the handle, don't wory about errors...
        *)
        ok := SetExtSize( Handle, ArraySize( Count-1, TSIZE( AnAssignmentRecord )));
        IF (NOT ok) THEN
            FatalError();
        END;
    END;


    DiscardNode := TreeNode;
    NextNode    := TreeNode^.Methods^.GetNext( TreeNode );

    IF (NextNode = ATreeNode(NIL)) THEN
        TreeNode := TreeNode^.Methods^.GetPrev( TreeNode );
    ELSE
        TreeNode := NextNode;
    END;

    DisposeOfAssignmentNode( DiscardNode, NIL );

    WHILE (NextNode <> ATreeNode(NIL)) DO
        IndexAddr := NextNode^.Methods^.GetDataObject( NextNode );
        DEC(IndexAddr.OFFSET);
        NextNode^.Methods^.SetDataObject( NextNode, IndexAddr );
        NextNode := NextNode^.Methods^.GetNext( NextNode );
    END;

END DisposeOfAssignmentNodeAndData;






(* Put Assignments In A Tree

        Put the assignments for a task into a tree for use with QuickPick
        or whatever.

    Preconditions
                    TaskNode        A Non-Nill Tree Node of the task to use.
                    AssTree         A Tree, from CreateTree, with no kids
                                    (if there are kids, the assignments
                                    are added on to the existing kids).


    Postconditions
                    Context         is the internal context needed by
                                    other procedures in this module.

                    RETURN          is TRUE  if it all worked,
                                       FALSE if it did not.  Most likely
                                             trouble is memory pressure.
*)
PROCEDURE PutAssignmentsInATree(     TaskNode   : ATreeNode;
                                     AssTree    : ATree;
                                 VAR Context    : AnAssignmentTreeContext
                               ) : BOOLEAN;
VAR
    TaskPtr          : ATaskPtr;
    Assignments      : AnAssignmentArray;
    Loop,
    Count            : CARDINAL;


    PROCEDURE AddOne( Index : CARDINAL ) : BOOLEAN;
    VAR
        TreeNode    : ATreeNode;
        AssIndex    : ADDRESS;
        ok          : BOOLEAN;
        s           : ARRAY [0..255] OF CHAR;
    BEGIN

        ok := CreateTreeNode( TreeNode );
        IF (ok) THEN
            AssIndex.OFFSET  := Index;
(*$O-*)
            AssIndex.SEGMENT := Assignments^[Index].Resource^.ID; (* 14-Feb-91 RSC *)
(*$O=*)
            TreeNode^.Methods^.SetDataObject( TreeNode, AssIndex );
            AssTree^.Methods^.AddLast( AssTree, TreeNode );  (* Last node *)
        ELSE
            GetMessage( ModuleNumber + 1, s );  (* "No more room for assignments" *)
            Error(s);
        END;

        RETURN ok;

    END AddOne;


BEGIN
    IF (AssTree = ATree(NIL)) OR (TaskNode = ATreeNode(NIL)) THEN
        FatalError();
    END;

    (* Get the proper handle to extract. *)

    Context.TaskNode := TaskNode;

    TaskPtr     := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    GlobalScale := TaskPtr^.EffortScale;
    Context.AssignmentHandle := TaskPtr^.Plan.Assignments;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    Count := LockObjectArray( Context.AssignmentHandle,
                              Assignments,
                              TSIZE( AnAssignmentRecord ) );
    Loop      := 0;
    WHILE (Count > 0) AND
          (AddOne( Loop )) DO
        DEC(Count);
        INC(Loop);
    END;

    ReleaseUnchangedObject( Context.AssignmentHandle );

    RETURN (Count = 0);

END PutAssignmentsInATree;










(* Add A Default Assignment To Tree

    Preconditions
                    AssTree     May be nil, but is the assignment tree.
                    RsrcNode    is the resource node to create the assignment
                                for.
                    Context     context returned by "PutAssignmentsInATree",
                    AssNode     If non NIL, is the tree node just ABOVE where
                                this tree node should be inserted.
    Postconditions
                    AssNode     is the assignment tree node created.
                    TRUE        if assignment added.
                    FALSE       if not.
*)
PROCEDURE AddADefaultAssignmentToTree(     AssTree      : ATree;
                                           RsrcNode     : ATreeNode;
                                       VAR Context      : AnAssignmentTreeContext;
                                       VAR AssNode      : ATreeNode
                                     ) : BOOLEAN;

VAR
    AssignmentRecord : AnAssignmentRecord;



    (* Check duplicates.
    *)
    PROCEDURE DuplicatesOK() : BOOLEAN;
    VAR
        Count       : CARDINAL;
        Assignments : AnAssignmentArray;
        s           : ARRAY [0..255] OF CHAR;
        Same        : BOOLEAN;
    BEGIN
            (* 5-Feb-91 RSC Logic was wrong here, fixed bug # 4103.
            *)
        Same  := FALSE;
        Count := LockObjectArray( Context.AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ) );

        WHILE (Count > 0) AND (NOT Same) DO
            DEC(Count);
(*$O-*)
            Same := StringsEqual( AssignmentRecord.Resource^.Name, Assignments^[Count].Resource^.Name );
(*$O=*)
        END;
        ReleaseUnchangedObject( Context.AssignmentHandle );

        IF (Same) THEN
                (* 29-Jan-91 TGS disallow duplicate assignments *)
            GetMessage(ModuleNumber+11,s); (* "Duplicate assignment not allowed" *)
            Error(s);
        END;

        RETURN (NOT Same);

    END DuplicatesOK;



    PROCEDURE InitializeAssignment(     RsrcNode         : ATreeNode;
                                    VAR AssignmentRecord : AnAssignmentRecord );
    VAR
        ResourcePtr : AResourcePointer;
    BEGIN
        ResourcePtr := RsrcNode^.Methods^.GetDataObject( RsrcNode );
        InitAssignment(ResourcePtr,AssignmentRecord);
        AssignmentRecord.ActualTimeUnits := GlobalScale;
    END InitializeAssignment;




    PROCEDURE ChangeFlexStorRecordCount( Up : BOOLEAN ) : BOOLEAN;
    VAR
        Count : CARDINAL;
    BEGIN

        Count := NumberOfElements(GetExtSize(Context.AssignmentHandle),TSIZE(AnAssignmentRecord));

        IF (Up) THEN
            INC( Count );
            IF (Count = 1) THEN
                IF (NOT CreateExtObject( Context.AssignmentHandle, ExtMedium )) THEN
                    RETURN FALSE;
                END;
                SetContext( Context.AssignmentHandle, Context );
            END;
        ELSIF (Count > 0) THEN
            DEC( Count );
        END;

        IF (Count = 0) THEN
            DiscardExtObject( Context.AssignmentHandle );
            SetContext( AnExtHandle(NIL), Context );
            RETURN TRUE;
        ELSE
            RETURN SetExtSize(Context.AssignmentHandle, ArraySize( Count, TSIZE(AnAssignmentRecord)));
        END;

    END ChangeFlexStorRecordCount;





    PROCEDURE AddOne( VAR After            : ATreeNode;
                      VAR AssignmentRecord : AnAssignmentRecord
                    ) : BOOLEAN;
    VAR
        TreeNode    : ATreeNode;
        A,
        AssIndex    : ADDRESS;
        Count       : CARDINAL;
        i           : CARDINAL;
        Assignments : AnAssignmentArray;
        ok          : BOOLEAN;
        s           : ARRAY [0..255] OF CHAR;
    BEGIN
        AssIndex.SEGMENT := AssignmentRecord.Resource^.ID; (* 14-Feb-91 RSC *)
        AssIndex.OFFSET  := 0;

        IF (After <> NIL) THEN
            A               := After^.Methods^.GetDataObject( After );
            AssIndex.OFFSET := A.OFFSET + 1;
        END;

        ok := CreateTreeNode( TreeNode );
        IF (ok) THEN
            TreeNode^.Methods^.SetDataObject( TreeNode, AssIndex );
            IF (After = NIL) THEN
                AssTree^.Methods^.AddLast( AssTree, TreeNode );  (* Last node *)
            ELSE
                After^.Methods^.AddAfter( After, TreeNode );  (* After "After" *)
            END;

                (* Move the subsequent records up, and plug in this
                   record.
                *)
            Count := LockObjectArray( Context.AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ) );

(*$O-*)
            FOR i := (Count - 1) TO AssIndex.OFFSET + 1 BY -1 DO
                Assignments^[i] := Assignments^[i-1];
            END;
            Assignments^[AssIndex.OFFSET] := AssignmentRecord;
(*$O=*)
            ReleaseObject( Context.AssignmentHandle );

            After    := TreeNode;
            TreeNode := TreeNode^.Methods^.GetNext( TreeNode );

                (* Increment the index of all sebsequent nodes
                *)
            WHILE (TreeNode <> ATreeNode(NIL)) DO
                AssIndex := TreeNode^.Methods^.GetDataObject( TreeNode );
                INC(AssIndex.OFFSET);
                TreeNode^.Methods^.SetDataObject( TreeNode, AssIndex );
                TreeNode := TreeNode^.Methods^.GetNext( TreeNode );
            END;

        ELSE
            GetMessage( ModuleNumber + 2, s );  (* "No more room for assignments" *)
            Error(s);

                (* Back off the flexstor size change.
                *)
            IF (NOT ChangeFlexStorRecordCount( FALSE )) THEN
                FatalError(); (* Should be able to downsize *)
            END;
        END;

        RETURN ok;

    END AddOne;


BEGIN
    IF (AssTree <> NIL) THEN
        InitializeAssignment( RsrcNode, AssignmentRecord );
        RETURN (DuplicatesOK())   AND
               (ChangeFlexStorRecordCount( TRUE )) AND
               (AddOne( AssNode, AssignmentRecord ));
    END;

    RETURN FALSE;

END AddADefaultAssignmentToTree;








  (* Check Resources - We are exiting the task form and want one last check
                       of the resources.  Catch (Actual > Total) errors by
                       looping through resources looking for negative
                       to-go amounts.

      Preconditions  - Assignments are in the tree.
                       TaskNode refers to the task we are dealing with.

      Postconditions - RETURN is TRUE iff all ok.
  *)

PROCEDURE CheckResources(     TaskNode      : ATreeNode;
                              AssTree       : ATree;
                              Context       : AnAssignmentTreeContext
                              ) : BOOLEAN;
BEGIN
    IF (AssTree = NIL) THEN
        RETURN TRUE;
    ELSE
        RETURN CheckStatusChange( TaskNode,
                                  DefaultStatusDialogProc );
    END;
END CheckResources;













END AssList.
