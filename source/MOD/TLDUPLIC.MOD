MODULE TLDuplicates;

  (*    Verify a range of tasks for duplicate WBS codes. Each task in the
        selected range is checked against the entire task tree for duplicate
        codes. If a duplicate code is found, and the task is in the user
        selected range, the wbs code is erased. This overlay is meant to
        be called by verify and renumber.

        MODIFICATION HISTORY:

         14-Jul-89  MWP  In the beginning...
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Remove use of AWBSPtr.
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
    (* PROC *)              OverlayContext;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree;

FROM WBSCreate      IMPORT
    (* PROC *)              DecomposeWBSCode,
                            ExtractDecomposedSegment;


FROM WBSCommon      IMPORT
    (* CONST *)             AllTasks,                               (* 14-Jul-89 MWP *)
                            Family,
                            Children,
                            SingleTask,
                            MaxWbsLen,
                            MaxWbsSize,
    (* TYPE *)              AContextRecord,
                            AContextPtr,
    (* PROC *)              InitializeWBSColumns,
                            SelectWBSRangeDialog,
                            GetWBSCode,
                            SetWBSValues,
                            ClearWBSFilterBitsInTask,
                            ClearWBSFilterBitsInTree,
                            ErrorsInTask;
FROM WBSDictionary  IMPORT
    (* PROC *)              SetDuplicateFlagsInTree,
                            SetDuplicateFlagInNode,
                            ClearDuplicateFlagsInTree,
                            FlagDuplicateWBSCodes;

VAR
    ContextRecordP          : AContextPtr;


PROCEDURE SelectVerifyRange ();
BEGIN

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

END SelectVerifyRange;



PROCEDURE VerifyAllWBSCodes ();
BEGIN

    (* First, verify all WBS codes within task range are unique. *)

    (* Set duplicate flag bit in all nodes in selected range.
       For this case, we do not have to worry about clearing
       any bits first as we are checking the whole task tree.
    *)

    ClearDuplicateFlagsInTree ( TaskTree );

    SetDuplicateFlagsInTree ( TaskTree );
    ClearWBSFilterBitsInTree ( TaskTree );

    FlagDuplicateWBSCodes ( ContextRecordP );

END VerifyAllWBSCodes;


PROCEDURE VerifyFamily ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
    TaskPtr                 : ATaskPtr;
BEGIN

    ClearDuplicateFlagsInTree ( TaskTree );

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    SetDuplicateFlagInNode ( CursorNode, TRUE );

    ClearWBSFilterBitsInTask ( CursorNode, NIL );

    IF (Subtree <> NIL) THEN
       SetDuplicateFlagsInTree ( Subtree );
       ClearWBSFilterBitsInTree ( Subtree );
    END;

    FlagDuplicateWBSCodes ( ContextRecordP );

END VerifyFamily;


PROCEDURE VerifyChildren ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN
    ClearDuplicateFlagsInTree ( TaskTree );

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        SetDuplicateFlagsInTree ( Subtree );

        ClearWBSFilterBitsInTree ( Subtree );

        FlagDuplicateWBSCodes ( ContextRecordP );

    END;

END VerifyChildren;


PROCEDURE VerifyTask ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
    TaskPtr                 : ATaskPtr;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    ClearDuplicateFlagsInTree ( TaskTree );

    SetDuplicateFlagInNode ( CursorNode, TRUE );

    ClearWBSFilterBitsInTask ( CursorNode, NIL );

    FlagDuplicateWBSCodes ( ContextRecordP );

END VerifyTask;

BEGIN
    ContextRecordP := OverlayContext();

    SelectVerifyRange ();

END TLDuplicates.
