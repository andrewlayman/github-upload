MODULE TLVerify;

  (*   Verify a range of tasks for valid WBS codes.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         06-Jun-89  AJL  Removed import of AFilterRecordPointer.
                         Remove use of FiltersOn.
         18-Jul-89  MWP  Added support for logging verify errors to the
                         Aux 20 field of the task record.
         19-Jul-89  MWP  Call TLDuplicates overlay to verify task range
                         for duplicate WBS codes.
         19-Jul-89  MWP  Reset filters before verifying.
         29-Jul-89  MWP  Implemented new error notification scheme.
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Use AWBSPtr instead of ADDRESS.
         27-Aug-89  MWP  Remove call to ResetFilters.
          2-Oct-89  MWP  Added display of progress messages.
  *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree,
    (* TYPE *)              ATaskFilter;

FROM Chart          IMPORT
    (* VAR *)               GanttChart;

FROM Dialog         IMPORT
    (* PROC *)              FatalError, Error;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString,
                            LengthOf;

FROM MsgFile        IMPORT
                            GetMessage;

FROM Overlays     IMPORT
    (* TYPE *)              OverlayContext,
    (* PROC *)              CallOverlayWithContext;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree,
                            ATreeNodeAttribute;

FROM WBSCreate      IMPORT
    (* PROC *)              DecomposeWBSCode;


FROM WBSCommon      IMPORT
    (* CONST *)             AllTasks,                               (* 14-Jul-89 MWP *)
                            Family,
                            Children,
                            SingleTask,
                            MaxWbsLen,
                            MaxWbsSize,
    (* TYPE *)              AContextRecord,
                            AnWBSFormsValue,
                            AWBSPtr,
                            AContextPtr,
                            AWBSError,
    (* PROC *)              InitializeWBSColumns,
                            SelectWBSRangeDialog,
                            GetWBSCode,
                            SetWBSValues,
                            ErrorsInTask;

FROM WBSDialog      IMPORT
    (* PROC *)              WBSError, ProgressMessage;

FROM WBSDictionary  IMPORT
                            CreateWBSCodeDictionary,
                            DeleteWBSCodeDictionary;

FROM WBSTranslate   IMPORT
                            CompareSegments;

CONST
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)

VAR
    WBSRecordP              : AWBSPtr;                              (* 15-Aug-89 MWP *)
    ContextRecordP          : AContextPtr;


PROCEDURE SelectVerifyRange ();                                     (* 15-Aug-89 MWP *)
VAR
    Overlay                 : ARRAY [0..39] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    IF ( NOT CreateWBSCodeDictionary () ) THEN
       RETURN;
    END;

    SetString( Overlay, "TLDUPLIC" );                              (* 19-Jul-89 MWP *)

    ok := CallOverlayWithContext( Overlay, ContextRecordP );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    CheckForDuplicates ();

    WITH ContextRecordP^ DO
       CASE RangeChoice OF

           AllTasks   :
                        VerifyAllWBSCodes ();
       |   Family     :
                        VerifyFamily ();
       |   Children   :
                        VerifyChildren ();
       |   SingleTask :
                        VerifyTask ();
       ELSE
          FatalError ();
       END;
    END;

    SetLengthOf ( Overlay, 0 );

    ProgressMessage ( ProgressMessagePhrase, Overlay );    (* 2-Oct-89 MWP *)

    DeleteWBSCodeDictionary ();

END SelectVerifyRange;

PROCEDURE  CheckForDuplicates ();
BEGIN

    TaskTree^.Methods^.TraverseTree ( TaskTree, ParentBeforeChild, 9999,
                                      FlagWBSCode, ContextRecordP );

END CheckForDuplicates;


PROCEDURE FlagWBSCode    ( VAR TaskNode  : ATreeNode;
                               Context   : ADDRESS   );
VAR
    TaskPtr                 : ATaskPtr;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    IF ( TaskNode^.Methods^.TestAttributeBit ( TaskNode, TempFlag2 ) ) THEN
         WBSError ( TaskNode,
                    DuplicateError,
                    ContextRecordP^.ShowThese,
                    ContextRecordP^.ErrorsFound );
    END;

END FlagWBSCode;



PROCEDURE CheckForParentageAndBlanks ( Tree  : ATree );
BEGIN


    Tree^.Methods^.TraverseTree (Tree, ParentBeforeChild, 9999,
                                     CheckWBSForErrors, NIL);

END CheckForParentageAndBlanks;


PROCEDURE CheckWBSForErrors    ( VAR TaskNode  : ATreeNode;
                                     Context   : ADDRESS   );
BEGIN

    VerifyWBS ( TaskNode, WBSRecordP );

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
 *  PRECONDITIONS:
 *            TaskNode - The node to verify WBS code with.
 *            WBSFormP - Pointer to the current WBS form values.
 *
 *  POSTCONDITIONS:
 *            If the WBS code is in error, the Aux 20 field will have an
 *            error message logged to it.
 *
 *  RETURNS   Nothing.
 *============================================================================*)
PROCEDURE VerifyWBS ( VAR TaskNode   : ATreeNode;                   (* 18-Jul-89 MWP *)
                      VAR WBSFormP   : AWBSPtr );                   (* 15-Aug-89 MWP *)
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

    ParentNode  := TaskNode^.Methods^.Parent ( TaskNode );

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    IF ( ParentNode <> ATreeNode(NIL) ) THEN

       ParentLevel := ParentNode^.Methods^.IndentationLevel( ParentNode );
       GetWBSCode ( ParentNode, ParentWBS );

       IF ( NOT DecomposeWBSCode ( ParentWBS,
                                   WBSFormP,
                                   ParentLevel,
                                   ParentBuffer ) ) THEN
           WBSError ( TaskNode,
                      ParentError,
                      ContextRecordP^.ShowThese,
                      ContextRecordP^.ErrorsFound );
           RETURN;
       END;

    ELSE
       ParentAvailable := FALSE;
    END;

    GetWBSCode ( TaskNode, TaskWBS );

    IF ( LengthOf ( TaskWBS ) = 0 ) THEN
       WBSError ( TaskNode,
                  BlankError,
                  ContextRecordP^.ShowThese,
                  ContextRecordP^.ErrorsFound );
       RETURN;
    END;

    TaskLevel   := TaskNode^.Methods^.IndentationLevel ( TaskNode );

    IF ( NOT DecomposeWBSCode ( TaskWBS,
                                WBSFormP,
                                TaskLevel,
                                TaskBuffer ) ) THEN
        WBSError ( TaskNode,
                   BadWBSError,
                   ContextRecordP^.ShowThese,
                   ContextRecordP^.ErrorsFound );
        RETURN;
    END;

    IF ( ParentAvailable ) THEN
       IF ( LengthOf ( WBSFormP^.Prefix ) > 0 ) THEN
          INC(ParentLevel);
       END;

       IF ( NOT CompareSegments ( TaskBuffer, ParentBuffer, ParentLevel ) ) THEN
          WBSError ( TaskNode,
                     MisMatchError,
                     ContextRecordP^.ShowThese,
                     ContextRecordP^.ErrorsFound );
       END;
    END;

END VerifyWBS;


PROCEDURE VerifyAllWBSCodes ();                                     (* 15-Aug-89 MWP *)
BEGIN
    CheckForParentageAndBlanks ( TaskTree );

END VerifyAllWBSCodes;




PROCEDURE VerifyFamily ();                                          (* 15-Aug-89 MWP *)
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN
    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    CheckWBSForErrors ( CursorNode, NIL );

    IF (Subtree <> NIL) THEN
        CheckForParentageAndBlanks ( Subtree );
    END;

END VerifyFamily;


PROCEDURE VerifyChildren ();                                        (* 15-Aug-89 MWP *)
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        CheckForParentageAndBlanks ( Subtree );
    END;

END VerifyChildren;


PROCEDURE VerifyTask ();                                            (* 15-Aug-89 MWP *)
VAR
    CursorNode              : ATreeNode;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    CheckWBSForErrors ( CursorNode, NIL );

END VerifyTask;


VAR
    FormName                :    ARRAY[0..10] OF CHAR;

BEGIN
    ContextRecordP := OverlayContext();

    SetString ( FormName, "TLWBS" );

    IF ( NOT SetWBSValues ( FormName, WBSRecordP ) ) THEN
       RETURN;
    END;

    SelectVerifyRange ();

END TLVerify.
