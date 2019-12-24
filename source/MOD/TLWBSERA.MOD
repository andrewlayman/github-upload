MODULE TLWBSErase;

  (*    Erase a range of WBS codes.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         10-Aug-89  KKC  Add copyright message.
          2-Oct-89  MWP  Added display of progress messages.
         15-Aug-91  PFG  Errors were not being reset when WBS numbers were
                         erased.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
    (* PROC *)              GetCodingField, SetCodingField,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree;

FROM Chart          IMPORT
    (* VAR *)               GanttChart;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              FatalError, Error;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, ConcatS;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree;

FROM WBSCommon      IMPORT
                            WBSModuleNumberBase,
                            MaxWbsLen,
    (* PROC *)              SelectWBSRangeDialog,
                            PerformConfirmationDialog,
                            ClearWBSFilterBitsInTask;

FROM WBSDialog      IMPORT
    (* PROC *)              ProgressMessage;

CONST
    ModuleNumber  =   WBSModuleNumberBase + 30;

    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)


PROCEDURE DisplayConfirmationDialog () : BOOLEAN;
VAR
    Choice                  : CARDINAL;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    (* "If you are using WBS numbers as part of anü"
       "import or export process, you may beü"
       "erasing numbers other systems depend upon." *)

    GetMessage ( ModuleNumber, Prefix );

    Choice := 1; (* Default is Cancel *)

    ok := PerformConfirmationDialog ( Prefix, Choice );

    IF ( ok ) THEN
       ok := Choice = 1;
    END;

    RETURN ok;

END DisplayConfirmationDialog;

PROCEDURE DisplayEraseRangeDialog ();
VAR
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..255] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    GetMessage ( ModuleNumber + 1, Title );
    (* "WBS Erase Numbers" *)
    GetMessage ( ModuleNumber + 2, Prefix );
    (* "Which tasks do you want to erase theü"
       "WBS numbers from?" *)

    Choice := 1; (* Default is Cancel *)

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 Choice );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    CASE Choice OF
        1   :
             EraseAllWBSCodes ();
    |   2   :
             EraseFamily ();
    |   3   :
             EraseChildren ();
    |   4   :
             EraseThisTasksWBS ();
    ELSE
       FatalError ();
    END;

    SetLengthOf ( Title, 0 );
    ProgressMessage ( ProgressMessagePhrase, Title );               (* 2-Oct-89 MWP *)

    ScheduleSaved := FALSE;         (* 9/14/91 EGK *)
    UnSetState (Formatted);

END DisplayEraseRangeDialog;


PROCEDURE EraseFamily ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
    TaskPtr                 : ATaskPtr;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    EraseWBS ( CursorNode, NIL );

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        Subtree^.Methods^.TraverseTree (Subtree,
                                        ParentAfterChild,
                                        9999,
                                        EraseWBS,
                                        ADR(CursorNode));
    END;

END EraseFamily;

PROCEDURE EraseChildren ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
    TaskPtr                 : ATaskPtr;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        Subtree^.Methods^.TraverseTree (Subtree,
                                        ParentAfterChild,
                                        9999,
                                        EraseWBS,
                                        ADR(CursorNode));
    END;

END EraseChildren;


PROCEDURE  EraseThisTasksWBS ();
VAR
    CursorNode              : ATreeNode;
    TaskPtr                 : ATaskPtr;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    EraseWBS ( CursorNode, NIL );

END EraseThisTasksWBS;

PROCEDURE EraseWBS ( VAR TaskNode : ATreeNode;
                         Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [ 0..MaxWbsLen ] OF CHAR;
BEGIN
    SetLengthOf ( s, 0 );

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    SetCodingField ( TaskPtr^, WBSLine, s );

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

    ClearWBSFilterBitsInTask ( TaskNode, NIL );     (* 15-Aug-91 PFG *)

END EraseWBS;


PROCEDURE EraseAllWBSCodes ();
VAR
    TaskNode                : ATreeNode ;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentAfterChild,
                                     999,
                                     EraseWBS,
                                     ADR(TaskNode) );
END EraseAllWBSCodes;


VAR
    ok                      : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
BEGIN

   (* Check for task tree empty before we start *)

   IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN
       IF ( DisplayConfirmationDialog () ) THEN
          DisplayEraseRangeDialog ();
       END;
    ELSE
       GetMessage ( ModuleNumber + 3, s );
       (* "There are no tasks to erase." *)
       Error ( s );
    END;

END TLWBSErase.
