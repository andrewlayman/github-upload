MODULE TLWBSvr;

  (*    Examine a range of tasks for errors, and if errors are found,
        attempt to renumber them.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         06-Jun-89  AJL  Remove import of AFilterRecordPointer.
                         Remove use of FiltersOn.
         17-Jul-89  MWP  Re-design and writing of verify and renumber.
                         Massive changes have been made. For all
                         intents and purposes, this is a new module.
         29-Jul-89  MWP  Implemented new error notification scheme.
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Use AWBSPtr instead of ADDRESS.
         27-Aug-89  MWP  Remove call to ResetFilters.
          2-Oct-89  MWP  Added display of progress messages.
         10-May-91  RSC  Put context on the stack while calling overlays.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM Allocs         IMPORT
    (* CONST *)             TskNmLen,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree,
    (* TYPE *)              ATaskFilter,
                            ATaskFilterSet;

FROM Chart          IMPORT
    (* VAR *)               GanttChart;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox, FatalError, Error;


FROM Dictionary     IMPORT
    (* TYPE *)              ADictionary,
    (* PROC *)              CreateDictionary, ExpungeDictionary,
                            AddToDictionary, InDictionary;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, ConcatS, ConcatLS,
                            CtoS, LengthOf, Copy, Search, Compare;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM Overlays       IMPORT
    (* PROC *)              CallOverlayWithContext;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree,
                            ATreeNodeAttribute;

FROM WBSCreate      IMPORT
    (* PROC *)              DecomposeWBSCode,
                            CreateAWbsCode,
                            StripOffShowCharacters,
                            ExtractDecomposedSegment;

FROM WBSCommon      IMPORT
    (* TYPE *)              AContextRecord,
                            AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
                            AWBSError,
                            AWBSErrorSet,
    (* VAR *)               WBSDictionary,
    (* CONST *)             WBSModuleNumberBase,
                            MaxWbsSize,
                            MaxWbsLen,
                            MaxWbsRows,
                            AllTasks,                               (* 14-Jul-89 MWP *)
                            Family,
                            Children,
                            SingleTask,
    (* PROC *)              InitializeWBSColumns,
                            GetWBSCode,
                            SetWBSCode,
                            SelectWBSRangeDialog,
                            CheckForWildCardCharacter,
                            SetWBSValues,
                            ErrorsInTask;

FROM WBSDialog      IMPORT
    (* PROC *)              ErrorDialog,
                            ProgressMessage,
                            WBSError;


FROM WBSTranslate   IMPORT
    (* PROC *)              ConvertWBSCodeToCard,
                            CheckParentWBS,
                            CompareSegments,
                            CalculateWBSCardinalValue;

FROM WBSDictionary  IMPORT
    (* PROC *)              IsInDict,
                            PutInDict,
                            CreateWBSCodeDictionary,
                            DeleteWBSCodeDictionary,
                            ClearWBSCode;

CONST
    ModuleNumber            =   WBSModuleNumberBase + 70;
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)

VAR
    TempBuffer              : ARRAY [0..255] OF CHAR;
    WBSRecordP              : AWBSPtr;                              (* 15-Aug-89 MWP *)
    ErrorMessage            : ARRAY [0..255] OF CHAR;
    ContextRecord           : AContextRecord;
    RenumberAll             : BOOLEAN;


(*=============================================================================
 * DisplayVerifyRangeDialog
 * ------------------------
 * Ask the user which range of tasks they wish to V & R on.
 * Call TLDuplicates overlay to flag duplicate WBS code values in the range
 * selected, then V & R all tasks in the range.
 *
 * INPUT    WBSFormP - Pointer to current WBS Form.
 * RETURNS  Nothing.
 *============================================================================*)
PROCEDURE DisplayVerifyRangeDialog ();
VAR
    LocalContextRecord      : AContextRecord;
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..29] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    Overlay                 : ARRAY [0..39] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    GetMessage ( ModuleNumber, Title );
    (* WBS Verify *)
    GetMessage ( ModuleNumber + 1, Prefix );
    (* Which tasks do you want to verify:" *)

    Choice := AllTasks;

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 Choice );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    IF ( NOT CreateWBSCodeDictionary () ) THEN
       RETURN;
    END;

    (* Call TLDuplicates to check for and flag duplicate WBS codes across
       the entire task tree.
    *)
    ContextRecord.RangeChoice := Choice;

    SetString( Overlay, "TLDUPLIC" );

    ContextRecord.ShowThese   := AWBSErrorSet {BlankError..WBSTooLarge};
    ContextRecord.ErrorsFound := AWBSErrorSet {};

    LocalContextRecord := ContextRecord;    (* 10-May-91 RSC stack it. *)
    ok := CallOverlayWithContext( Overlay, ADR(LocalContextRecord) );
    ContextRecord := LocalContextRecord;    (* 10-May-91 RSC restore it. *)

    IF ( NOT ok ) THEN
       RETURN;
    END;

    (* Clear duplicated WBS codes if user allows. *)

    DisposeOfDuplicates ();

    CASE Choice OF
        AllTasks   :
             VerifyAllWBSCodes ();
    |   Family     :
             VerifyFamily      ();
    |   Children   :
             VerifyChildren    ();
    |   SingleTask :
             VerifyTask        ();
    ELSE
       FatalError ();
    END;

    DeleteWBSCodeDictionary();

    CheckForErrors ();

    ScheduleSaved := FALSE;             (* 9/14/91 EGK *)
    UnSetState (Formatted);

END DisplayVerifyRangeDialog;


(*=============================================================================
 * DisposeOfDuplicates
 * -------------------
 * Traverse the entire task tree, looking for nodes which have been flagged
 * as having duplicate WBS codes.
 *
 * INPUT    Nothing.
 * RETURNS  Nothing.
 *============================================================================*)
PROCEDURE DisposeOfDuplicates ();
VAR
    TaskNode                : ATreeNode;
BEGIN

    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                     EraseDuplicateWBSCode,
                                     ADR(TaskNode) );

END DisposeOfDuplicates;


(*=============================================================================
 * EraseDuplicateWBSCode
 * ---------------------
 * If a task's WBS code is duplicated elsewhere in the task tree, and, it
 * falls within the user selected range of tasks to verify, then the
 * TempFlag2 will be set in the current node. If the flag is set, we
 * ask the user if they wish to renumber the current duplicate WBS code.
 * If they respond Yes, we blank out the current WBS code and set the
 * highlight3 filter.
 *
 * INPUT    TaskNode - The current node to check WBS code on.
 *          Context  - Not used.
 * RETURNS  Nothing.
 *
 * NOTE: We do not renumber the WBS code at this point. All we do is blank the
 *       WBS code, leaving the actual renumbering for the second pass of
 *       verification and renumbering.
 *============================================================================*)
PROCEDURE EraseDuplicateWBSCode    ( VAR TaskNode  : ATreeNode;
                                         Context   : ADDRESS   );
BEGIN

    IF ( TaskNode^.Methods^.TestAttributeBit ( TaskNode, TempFlag2 ) ) THEN
        IF ( ErrorDialog ( TaskNode,
                           DuplicateError,
                           ContextRecord.ShowThese,
                           ContextRecord.ErrorsFound,
                           RenumberAll ) ) THEN
           ClearWBSCode ( TaskNode );
        END;
    END;

END EraseDuplicateWBSCode;


(*=============================================================================
 * CheckForErrors
 * --------------
 * If errors have occured renumbering WBS codes, inform the user of this.
 * This proc is meant to be called after the verify and renumbering cycle
 * is complete.
 *
 * INPUT    Nothing.
 * RETURNS  Nothing.
 *============================================================================*)
PROCEDURE CheckForErrors ();
BEGIN

    IF ( ContextRecord.ErrorsFound <> AWBSErrorSet{} ) THEN
       GetMessage ( ModuleNumber + 2, ErrorMessage );
       (* "Error(s) have occured renumbering WBS codes" *)
       Error ( ErrorMessage );
    END;

    SetLengthOf ( ErrorMessage, 0 );

    ProgressMessage ( ProgressMessagePhrase, ErrorMessage );    (* 2-Oct-89 MWP *)

END CheckForErrors;


(*=============================================================================
 * CheckWBSForErrors
 * -----------------
 * The range of tasks has been checked for duplicates. All duplicate
 * WBS codes have been blanked out. Now, we have to verify against
 * blanks and incorrect codes. If VerifyWBS finds a problem with
 * the TaskNode and the user wants it re-numbered, we mark the
 * node with a Highlight1 filter, and attempt to renumber it.
 *
 * INPUT    TaskNode - The node to verify.
 *          Context  - Ignored. Is demanded by TraverseTree.
 *
 * RETURNS  Nothing.
 *============================================================================*)
PROCEDURE CheckWBSForErrors ( VAR TaskNode : ATreeNode;
                                  Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    ok                      : BOOLEAN;
    FilterSet               : ATaskFilterSet;
    Name                    : ARRAY [0..TskNmLen] OF CHAR;                 (* 1-Jul-89 MWP *)
    s                       : ARRAY [0..100] OF CHAR;

BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    ok := VerifyWBS ( TaskNode, WBSRecordP );

    IF ( ok ) THEN
        ok := RenumberTask ( WBSRecordP, TaskNode );
    END;

END CheckWBSForErrors;


(*=============================================================================
 * VerifyWBS
 * ---------
 *          Verifies the current TaskNode WBS code for correctness. The
 *  checking is performed against the following conditions:
 *  Is the parent WBS code correct?
 *  Is the task's WBS code blank?
 *  If not blank, is the task's WBS code correct?
 *
 *  INPUT     TaskNode - The node to verify WBS code with.
 *            WBSFormP - Pointer to the current WBS form values.
 *
 *  RETURNS   TRUE  - if the task being verified is to be renumbered.
 *            FALSE - Do not renumber task.
 *============================================================================*)
PROCEDURE VerifyWBS ( VAR TaskNode   : ATreeNode;
                      VAR WBSFormP   : AWBSPtr ) : BOOLEAN;         (* 15-Aug-89 MWP *)
VAR
    ParentNode              : ATreeNode;

    TaskWBS                 : ARRAY [0..MaxWbsLen] OF CHAR;
    ParentWBS               : ARRAY [0..MaxWbsLen] OF CHAR;

    TaskBuffer              : ARRAY [0..45] OF CHAR;
    ParentBuffer            : ARRAY [0..45] OF CHAR;

    ParentPtr               : ATaskPtr;
    TaskPtr                 : ATaskPtr;

    ParentLevel,
    TaskLevel               : CARDINAL;

    ok                      : BOOLEAN;
    ParentAvailable         : BOOLEAN;
BEGIN
    ok              := TRUE;
    ParentAvailable := TRUE;


    (* First, validate the parent WBS code, if one exists.
       If the parent code is invalid, display a menu dialog to
       the user asking whether we should continue renumbering or not.
       Return the user selection ( True or False ).
    *)

    ParentNode  := TaskNode^.Methods^.Parent ( TaskNode );

    IF ( ParentNode <> ATreeNode(NIL) ) THEN

       ParentLevel := ParentNode^.Methods^.IndentationLevel( ParentNode );
       GetWBSCode ( ParentNode, ParentWBS );

       IF ( NOT DecomposeWBSCode ( ParentWBS,
                                   WBSFormP,
                                   ParentLevel,
                                   ParentBuffer ) ) THEN

           RETURN ( ErrorDialog ( TaskNode,
                                  ParentError,
                                  ContextRecord.ShowThese,
                                  ContextRecord.ErrorsFound,
                                  RenumberAll ) );
       END;
    ELSE
       ParentAvailable := FALSE;
    END;

    (* The parent, if it exists, is ok.
       Now we will check the task itself.
       If it is blank, and has been flagged as duplicate,just renumber it
       else display renumber dialog and return user's choice.

       If the WBS is incorrect, inform user via menu choice, and see
       what they want to do. Return their choice.
    *)

    GetWBSCode ( TaskNode, TaskWBS );

    (* WBS is blank, If this node has not been flagged as a duplicate,
       ask the user whether they wish to renumber.
       Duplicate entries have already been flagged, and the user prompted
       for renumbering in the first pass of verify. If the user selected
       renumber, the duplicate WBS is simply blanked, and we pick it up
       here on the second pass.
    *)
    IF ( LengthOf ( TaskWBS ) = 0 ) THEN
       IF ( TaskNode^.Methods^.TestAttributeBit ( TaskNode, TempFlag2 ) ) THEN
           RETURN TRUE;
       ELSE
           RETURN ( ErrorDialog ( TaskNode,
                                  BlankError,
                                  ContextRecord.ShowThese,
                                  ContextRecord.ErrorsFound,
                                  RenumberAll ) );
       END;
    END;

    TaskLevel   := TaskNode^.Methods^.IndentationLevel ( TaskNode );

    (* Tasks WBS code cannot be broken down according to form values.
     * Display error menu, and return value.
    *)
    IF ( NOT DecomposeWBSCode ( TaskWBS,
                                WBSFormP,
                                TaskLevel,
                                TaskBuffer ) ) THEN
        RETURN ( ErrorDialog ( TaskNode,
                               BadWBSError,
                               ContextRecord.ShowThese,
                               ContextRecord.ErrorsFound,
                               RenumberAll ) );
    END;

    (* Task WBS appears ok. Check it against the parent to make sure
     * that the parent's segments conform to the task's segments.
     * If they do not match, display MisMatch dialog, and return the user's
     * selection.
     * If there is no parent, we are through.
    *)

    IF ( ParentAvailable ) THEN
       IF ( LengthOf ( WBSFormP^.Prefix ) > 0 ) THEN
          INC(ParentLevel);
       END;

       IF ( NOT CompareSegments ( TaskBuffer, ParentBuffer, ParentLevel ) ) THEN
          RETURN ( ErrorDialog ( TaskNode,
                                 MisMatchError,
                                 ContextRecord.ShowThese,
                                 ContextRecord.ErrorsFound,
                                 RenumberAll ) );
       END;
    END;

    RETURN FALSE;

END VerifyWBS;


PROCEDURE VerifyAllWBSCodes ();
VAR
    TaskNode                : ATreeNode;
BEGIN

    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentBeforeChild,
                                     999,
                                     CheckWBSForErrors,
                                     ADR(TaskNode) );

END VerifyAllWBSCodes;


PROCEDURE VerifyFamily ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    CheckWBSForErrors ( CursorNode , NIL );

    IF (Subtree <> NIL) THEN
        TaskTree^.Methods^.TraverseTree( Subtree,
                                         ParentBeforeChild,
                                         999,
                                         CheckWBSForErrors,
                                         ADR(CursorNode) );
    END;
END VerifyFamily;


PROCEDURE VerifyChildren ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN
    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        TaskTree^.Methods^.TraverseTree( Subtree,
                                         ParentBeforeChild,
                                         999,
                                         CheckWBSForErrors,
                                         ADR(CursorNode) );
    END;

END VerifyChildren;


PROCEDURE VerifyTask ();
VAR
    CursorNode              : ATreeNode;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    CheckWBSForErrors ( CursorNode , NIL );

END VerifyTask;


(*=============================================================================
 * RenumberTask
 * ------------
 * Assign a new WBS code to CursorNode, according to WBS form values.
 *
 * INPUT   WBSFormP   - Pointer to current WBS form.
 *         CursorNode - Task Node to assign WBS value to.
 *
 * RETURNS TRUE  - The task was successfully renumbered.
 *         FALSE - An error condition occured while trying to renumber.
 *
 *===========================================================================*)
PROCEDURE RenumberTask ( WBSFormP       : AWBSPtr;                  (* 15-Aug-89 MWP *)
                         VAR CursorNode : ATreeNode ) : BOOLEAN;
CONST
    Previous = 1;
    Next     = 2;
VAR
    PrevValue, NextValue    : CARDINAL;
    HighValue               : CARDINAL;
    CalculateSiblingValues  : BOOLEAN;
    ParentNode              : ATreeNode;
BEGIN

    (*
      When renumbering a WBS value, we try and assign the a WBS value
      that is sequentially one value higher than the largest sibling's
      WBS value. We will not do this if we detect that the parent
      has been found to be changed. This helps remove inconsistencies
      in the renumbering that can arise.
    *)
    CalculateSiblingValues := TRUE;

    ParentNode  := CursorNode^.Methods^.Parent ( CursorNode );
    IF ( ParentNode <> ATreeNode(NIL) ) THEN
       IF ( ErrorsInTask ( ParentNode ) ) THEN
           CalculateSiblingValues := FALSE;
           HighValue := 1;
       END;
    END;


    IF ( CalculateSiblingValues ) THEN
        PrevValue := CalculateWBSCardinalValue ( CursorNode,
                                                 Previous,
                                                 WBSFormP );

        NextValue := CalculateWBSCardinalValue ( CursorNode,
                                                 Next,
                                                 WBSFormP );

        IF ( NextValue > PrevValue ) THEN
            HighValue := NextValue;
        ELSE
            HighValue := PrevValue;
        END;

        INC( HighValue );
    END;

    RETURN ( RenumberATask ( WBSFormP, CursorNode, HighValue ) );

END RenumberTask;


(*=============================================================================
 * RenumberATask
 * -------------
 * Create and assign a new WBS value for CursorNode.
 *
 * INPUT  WBSFormP    Pointer to current WBS form.
 *        CursorNode  The task node to renumber the WBS value for.
 *        Count       The numeric value to calculate the WBS value for.
 *
 * RETURNS TRUE  - The task's WBS was successfully created.
 *         FALSE - The WBS code could not be calculated. This will most
 *                 likely be as a result of Count being to large for the
 *                 appropriate form value, or there are no entries for
 *                 the CursorNode outline level on the WBS form.
 *
 * WARNING: This function checks the WBS code created to see if it already
 *          exists in the task tree by calling IsInDict(). IsInDict assumes
 *          the existence of a dictionary, created previously by a call to
 *          ClearDuplicateWBSCodes. If the WBS code already exists, then
 *          we will try and create another code one value higher. We continue
 *          the cycle until we find a unique code, or find we cannot create
 *          a WBS code that conforms to the WBS form entries. If a
 *          unique code is discovered, it is placed in the dictionary by a
 *          call to PutInDict.
 *===========================================================================*)
PROCEDURE RenumberATask (     WBSFormP   : AWBSPtr;                 (* 15-Aug-89 MWP *)
                          VAR CursorNode : ATreeNode;
                              Count      : CARDINAL ) : BOOLEAN;
VAR
    NodeLevel, Total        : CARDINAL;
    ParentNode              : ATreeNode;
    ok                      : BOOLEAN;
    WBSCreated              : BOOLEAN;
    ParentWBS               : ARRAY [0..MaxWbsLen] OF CHAR;
    s                       : ARRAY [0..MaxWbsLen] OF CHAR;
    Err                     : AWBSError;
BEGIN

    ok := CheckParentWBS ( CursorNode,
                           WBSFormP,
                           ADR(ContextRecord),
                           ParentWBS );

    (* If there is a problem with the parent WBS code, then we cannot
       depend on the count value passed to us. Things can get a little bizarre
       in certain circumstances, as described below.
       1. Parent_1       AA
             Child_1     01.01
             Child_2     01.02
          In this case, Parent_1's WBS is invalid, but the children's codes
          are OK. If we process the children, we will find a parent
          WBS error. Assume that the children will be renumbered.
          The first child, Child_1, will end up with a WBS code of
          AA.03 - The AA coming from the Parent, and the 03 because
          that is the next highest available WBS code for the children.
          Upon processing Child_2, however, we will assign the WBS_Code
          AA.01, where the 01 is assigned because we could not calculate
          a higher WBS than one. ( By this time Child_1 does have an
          invalid code, and is not counted. )
       2. Even more fatal to us, is the case of -
          Parent_1       AA
             Child_1
             Child_2
          where the parent is once again in error. After processing the two
          children, we will end up with
          Parent_1       AA
             Child_1     AA.01
             Child_2     AA.01
          We have erroneously generated duplicate WBS codes! Yuchh.

       Solution:
          If the parent is in error, set 'Count' equal to one, and generate
          a complete WBS code based on this.
          Then, check the WBS code generated against the dictionary of
          current Task tree WBS codes. If it does not exist, use it.
          If it already exists somewhere in the tree, increment 'Count'
          and try again. Continue until we get a valid code or generate
          an Creation error. If we get a valid code, add it to the dictionary.
    *)
    IF ( NOT ok ) THEN
       Count := 1;
    END;

    ok := TRUE;

    WBSCreated := FALSE;

    NodeLevel := CursorNode^.Methods^.IndentationLevel ( CursorNode );

    WHILE ok AND NOT WBSCreated DO
       IF ( CreateAWbsCode ( Count,
                             NodeLevel,
                             TempBuffer,
                             ParentWBS,
                             WBSFormP,
                             Err        ) ) THEN

           Total :=  LengthOf ( ParentWBS ) + LengthOf ( TempBuffer );

           IF ( Total <= MaxWbsLen ) THEN
               Copy ( ParentWBS, s );
               ConcatLS ( s, TempBuffer );

               IF ( IsInDict ( s ) ) THEN
                  INC(Count);
               ELSE
                  (* Code is unique, log it to the dictionary and set it in
                     the task node. *)
                  SetWBSCode ( CursorNode, s );
                  WBSCreated := TRUE;
                  ok := PutInDict ( CursorNode );
              END;
           ELSE
               WBSError ( CursorNode,                              (* 29-Jul-89 MWP *)
                          WBSTooLarge,
                          ContextRecord.ShowThese,
                          ContextRecord.ErrorsFound );
               RETURN FALSE;
           END;
       ELSE
           WBSError ( CursorNode,                              (* 29-Jul-89 MWP *)
                      Err,
                      ContextRecord.ShowThese,
                      ContextRecord.ErrorsFound );
           RETURN FALSE;
       END;
    END;

    (* Something drastic has happened to force abort of WBS code creation,
     * such as the node level is too deep for the form, or we have
     * run out of available WBS numbers.
     * We should be notifying the user of this unusual event, and
     * highlighting in some fashion.
    *)

    RETURN FALSE;

END RenumberATask;


(*=============================================================================
 * WildcardsNotPresent
 * -------------------
 * Check all valid form entries for the presence of wildcard characters.
 *
 * INPUT   WBSFormP - Pointer to current WBS form.
 * RETURNS TRUE     - There are no wildcard characters entered in the WBS form.
 *         FALSE    - Wildcard characters have been found.
 *
 *===========================================================================*)
PROCEDURE WildcardsNotPresent ( WBSFormP : AWBSPtr ) : BOOLEAN;     (* 15-Aug-89 MWP *)
VAR
    Loop                    : CARDINAL;
BEGIN
    WITH WBSFormP^ DO
       IF ( NOT CheckForWildCardCharacter ( Prefix ) ) THEN
          RETURN FALSE;
       END;

       FOR Loop := 0 TO MaxWbsRows DO
          IF ( LengthOf ( WBSColumns[ Loop ].CharacterSequence ) > 0 ) AND
             ( LengthOf ( WBSColumns[ Loop ].FollowBy ) > 0 ) THEN
                IF ( NOT CheckForWildCardCharacter ( WBSColumns[ Loop ].FollowBy) ) THEN
                   RETURN FALSE;
                END;
          END;
       END;
    END;

    RETURN TRUE;
END WildcardsNotPresent;



VAR
    FormName                :    ARRAY[0..10] OF CHAR;
    Copyright               :    ARRAY[0..50] OF CHAR;
BEGIN

   Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
   RenumberAll   := FALSE;

   (* Check for task tree empty before we start *)
   IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN

       SetString ( FormName, "TLWBS" );
       IF ( NOT SetWBSValues ( FormName, WBSRecordP ) ) THEN
          RETURN;
       END;

       IF ( WildcardsNotPresent ( WBSRecordP ) ) THEN
           DisplayVerifyRangeDialog ();
       ELSE
           GetMessage ( ModuleNumber + 4, ErrorMessage );
           (* "Wildcard characters entered into WBS form." *)
           Error ( ErrorMessage );
       END;
    ELSE
        GetMessage ( ModuleNumber + 5, ErrorMessage );
        (* "There are no tasks to verify and renumber." *)
        Error ( ErrorMessage );
    END;

END TLWBSvr.


     WBS Verify and Renumber Specs.


     Verify and renumber purports to verify all wbs codes within a user
     defined range, and if they are in error, allow the user to renumber
     them. A wbs code is considered to be erroneous under the following
     conditions:
     - It is blank.
     - It's segments do not conform to the current wbs manager form.
     - There are 2 or more occurences of the same wbs code in the task
       tree.
     - The parent segments of the current wbs code do not match the
       parents wbs code.


     In order to correctly verify and renumber, we perform the following
     sequence of events.

     1. Check for duplicate codes across the entire task tree.

        TempFlag1 is used to indicate whether a node is within the user
        defined region or not.

        TempFlag2 is used to indicate that the node's WBS code is
        duplicated within the task tree.

        Set TempFlag1 to FALSE for all nodes in the TaskTree.

        For all nodes within the user selected range, set TempFlag1
        to TRUE and TempFlag2 to FALSE.

        Create a dictionary which will hold all the WBS codes for
        the entire task tree.

        Traverse the entire task tree in parent before child order.

           For each node in the tree, examine the WBS code.
              If it is not blank, see if it exists in the dictionary.
              If it doesn't, add it to the dictionary.
              If it does, check the current node and the dictionary
              node to see if either of them are within the verify range. (
              TempFlag1 = TRUE. )
                 If they are, mark the node(s) with TempFlag2 = TRUE.


        Traverse the entire task tree in parent before child order.

           For each node in the tree
           If TempFlag2 is TRUE
              Inform the user of the duplication viloation and ask
              whether to renumber.
              If they say yes, blank the WBS code.


     2. Verify for remaining error conditions.

        For each task in the user elected range, ( in parent before child order )

          If the task has a parent
              Validate the parent's WBS code.
              If it is invalid
                Ask the user whether to renumber current task or not.

          If the task is blank
              Renumber it.

          If the task's WBS code is in error
               Ask the user whether to renumber current task or not.

          If the task's WBS code amd Parent's WBS code do not
          match.
              Ask the user whether to renumber current task or not.

     3. Renumbering tasks.

          Note: When renumbering a task, we try and assign the next highest
                value to the WBS code within that task's siblings. To
                do this examine all siblings WBS codes and calculate
                what their cardinal values are. If a sibling's WBS code
                cannot be calculated, a cardinal value of zero is
                used. We keep track of the highest value obtained from
                the siblings, and when we are finished use the next highest
                value to create the current tak's WBS code.

          Check the current task's parent WBS to see if it is incorrect.

          If it is, it is because of one of three possible occurences,
          1 - We have previously detected this, and the user has decided
              to leave it the way it was.
          2 - We could not generate the WBS code for the parent previously
              because of internal problems. ( i.e form restrictions etc. )
          3 - The user selected range's parent is incorrect.

          Irregardless, this condition was noted during the verify
          process, and the user has responded that he wants the current
          task renumbered. This means that although the current task, and
          possibly the task's siblings, possess valid codes, we have to
          treat them as being invalid. This means that we have to start
          assigning values starting at '1'.

          Set TempWBSCode value to '1'.


Create:   Create a WBS code based on TempWBSCode and the parent's WBS.

          If the WBS code cannot be created,
            post error message, and return.

          Check to see if this code exists in the dictionary.
            If it does AND TempFlag2 is FALSE
              Increment  TempWBSCode and loop to Create:
            else
              Add it to the dictionary
              Assign the task the new code


     4. Delete the dictionary, and say good-bye.


