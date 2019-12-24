MODULE TLWBSNumberBlanks;

  (*    Find and number blank WBS codes in a rnage of tasks.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         06-Jun-89  AJL  Remove import of AFilterRecordPointer.
                         Remove use of FiltersOn.
         19-Jul-89  MWP  Added new WBS code dictionary support.
         29-Jul-89  MWP  Implemented new error notification scheme.
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Use AWBSPtr instead of ADDRESS.
         18-Aug-89  MWP  Clear WBS error field in all tasks in range.
         27-Aug-89  MWP  Remove call to ResetFilters.
          2-Oct-89  MWP  Added display of progress messages.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine, WBSLen,
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
    (* PROC *)              MultipleChoiceBox, FatalError, Error;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, ConcatS, ConcatLS,
                            CtoS, LengthOf, Copy, Search, TrimRear;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree;

FROM WBSCommon      IMPORT
    (* CONST *)             WBSModuleNumberBase,
                            MaxWbsLen,
                            MaxWbsSize,
    (* TYPE *)              AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
                            AWBSError,
                            AWBSErrorSet,
                            MaxWbsRows,
                            AContextRecord,
    (* PROC *)              InitializeWBSColumns,
                            ClearWBSFilterBitsInTask,               (* 18-Aug-89 MWP *)
                            ClearWBSFilterBitsInTree,
                            SelectWBSRangeDialog,
                            GetWBSCode,
                            SetWBSCode,
                            CheckForWildCardCharacter,
                            SetWBSValues;

FROM WBSCreate      IMPORT
    (* PROC *)              CreateAWbsCode,
                            StripOffShowCharacters;

FROM WBSDialog      IMPORT
    (* PROC *)              WBSError, ProgressMessage;

FROM WBSDictionary  IMPORT
    (* PROC *)              IsInDict,
                            LoadWBSCodes,
                            CreateWBSCodeDictionary,
                            DeleteWBSCodeDictionary;

FROM WBSTranslate   IMPORT
                            ConvertWBSCodeToCard,
                            CheckParentWBS,
                            CalculateWBSCardinalValue;

VAR
    WBSRecordP              : AWBSPtr;                              (* 15-Aug-89 MWP *)
    ContextRecord           : AContextRecord;

CONST
    ModuleNumber            =   WBSModuleNumberBase + 20;
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)


PROCEDURE DisplayNumberBlanksRangeDialog ();
CONST
    AllTasks               = 1;
    Family                 = 2;
    Children               = 3;
    SingleTask             = 4;
VAR
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..255] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN
    GetMessage ( ModuleNumber, Title );
    (* "WBS Number Blank Tasks" *)
    GetMessage ( ModuleNumber + 1, Prefix );
    (* "Which tasks do you want to number:" *)

    Choice := AllTasks;

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 Choice );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    IF ( Choice < AllTasks ) OR ( Choice > SingleTask ) THEN
       RETURN;
    END;

    IF ( CreateWBSCodeDictionary () ) THEN                          (* 19-Jul-89 MWP *)
        LoadWBSCodes ();
    ELSE
        RETURN;
    END;

    ContextRecord.ShowThese   := AWBSErrorSet {BlankError..WBSTooLarge};
    ContextRecord.ErrorsFound := AWBSErrorSet {};

    CASE Choice OF
        AllTasks   :
             NumberAllWBSCodes ();
    |   Family     :
             NumberFamily ();
    |   Children   :
             NumberChildren ();
    |   SingleTask :
             NumberTask ();
    ELSE
       FatalError ();
    END;

    DeleteWBSCodeDictionary ();                                     (* 19-Jul-89 MWP *)

    CheckForErrors ();

    ScheduleSaved := FALSE;             (* 9/14/91 EGK *)
    UnSetState (Formatted);

END DisplayNumberBlanksRangeDialog;


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
VAR
    ErrorMessage            : ARRAY [0..255] OF CHAR;
BEGIN

    SetLengthOf ( ErrorMessage,  0 );
    ProgressMessage ( ProgressMessagePhrase, ErrorMessage );       (* 2-Oct-89 MWP *)

    IF ( ContextRecord.ErrorsFound <> AWBSErrorSet{} ) THEN
       GetMessage ( ModuleNumber + 8, ErrorMessage );
       (* "Error(s) have occured renumbering WBS codes" *)
       Error ( ErrorMessage );
    END;

END CheckForErrors;


PROCEDURE NumberAllWBSCodes ();
VAR
    TaskNode                : ATreeNode;
BEGIN
    TaskNode := ATreeNode(NIL);

    ClearWBSFilterBitsInTree ( TaskTree );                         (* 18-Aug-89 MWP *)

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentBeforeChild,
                                     999,
                                     CheckWBSForBlank,
                                     ADR(TaskNode) );
END NumberAllWBSCodes;

PROCEDURE NumberFamily ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    ClearWBSFilterBitsInTask ( CursorNode, NIL );                  (* 18-Aug-89 MWP *)

    CheckWBSForBlank ( CursorNode, NIL );

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        ClearWBSFilterBitsInTree ( Subtree );                      (* 18-Aug-89 MWP *)
        Subtree^.Methods^.TraverseTree (Subtree,
                                        ParentBeforeChild,
                                        9999,
                                        CheckWBSForBlank,
                                        ADR(CursorNode));
    END;
END NumberFamily;

PROCEDURE NumberChildren ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        ClearWBSFilterBitsInTree ( Subtree );                      (* 18-Aug-89 MWP *)
        Subtree^.Methods^.TraverseTree (Subtree,
                                        ParentBeforeChild,
                                        9999,
                                        CheckWBSForBlank,
                                        ADR(CursorNode));
    END;

END NumberChildren;

PROCEDURE NumberTask ();
VAR
    CursorNode              : ATreeNode;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    ClearWBSFilterBitsInTask ( CursorNode, NIL );                   (* 18-Aug-89 MWP *)

    CheckWBSForBlank ( CursorNode, NIL );

END NumberTask;


PROCEDURE CheckWBSForBlank ( VAR TaskNode : ATreeNode;
                                 Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    ok                      : BOOLEAN;
    s                       : ARRAY [ 0..255 ] OF CHAR;
BEGIN
    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    GetCodingField ( TaskPtr^, WBSLine, s );

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
    TrimRear ( s );

    ok := LengthOf( s ) = 0;

    IF ( ok ) THEN
        ok := RenumberTask ( WBSRecordP, TaskNode );
    END;

END CheckWBSForBlank;



PROCEDURE RenumberTask ( WBSFormP       : AWBSPtr;                  (* 15-Aug-89 MWP *)
                         VAR CursorNode : ATreeNode ) : BOOLEAN;
CONST
    Previous = 1;
    Next     = 2;
VAR
    ParentLevel             : CARDINAL;
    FoundNode               : ATreeNode;
    Loop                    : BOOLEAN;
    ParentWBS               : ARRAY [0..MaxWbsLen] OF CHAR;
    s                       : ARRAY [0..MaxWbsLen] OF CHAR;
    TempBuffer              : ARRAY [0..MaxWbsLen] OF CHAR;
    PrevValue, NextValue,
    HighValue, Total        : CARDINAL;
    Err                     : AWBSError;
BEGIN

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

    IF ( NOT CheckParentWBS ( CursorNode,
                              WBSFormP,
                              ADR(ContextRecord),
                              ParentWBS ) ) THEN
        RETURN FALSE;
    END;

    Loop := TRUE;

    ParentLevel := CursorNode^.Methods^.IndentationLevel ( CursorNode );

    WHILE ( Loop ) DO
       IF ( CreateAWbsCode ( HighValue,
                             ParentLevel,
                             TempBuffer,
                             ParentWBS,
                             WBSFormP,
                             Err         ) ) THEN                  (* 29-Jul-89 MWP *)

           Total :=  LengthOf ( ParentWBS ) + LengthOf ( TempBuffer );

           IF ( Total <= MaxWbsLen ) THEN
               Copy ( ParentWBS, s );
               ConcatLS ( s, TempBuffer );

               IF ( IsInDict ( s ) ) THEN                           (* 19-Jul-89 MWP *)
                  INC(HighValue);
               ELSE
                   (* Code is unique, log it to the dictionary and set it in
                      the task node. *)
                   SetWBSCode ( CursorNode, s );
                   Loop := FALSE;
               END;
           ELSE
               WBSError ( CursorNode,                               (* 29-Jul-89 MWP *)
                          WBSTooLarge,
                          ContextRecord.ShowThese,
                          ContextRecord.ErrorsFound );
               RETURN FALSE;
           END;
       ELSE
            WBSError ( CursorNode,                               (* 29-Jul-89 MWP *)
                       Err,
                       ContextRecord.ShowThese,
                       ContextRecord.ErrorsFound );
           RETURN FALSE;
       END;
    END;

    RETURN TRUE;

END RenumberTask;


PROCEDURE WildcardsNotPresent ( WBSFormP : AWBSPtr ) : BOOLEAN;     (* 15-Aug-89 MWP *)
VAR
    Loop                    : CARDINAL;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

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
    ok                      :    BOOLEAN;
    ErrorMessage            :    ARRAY [0..255] OF CHAR;

BEGIN
   (* Check for task tree empty before we start *)

   IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN

      SetString ( FormName, "TLWBS" );

      IF ( NOT SetWBSValues ( FormName, WBSRecordP ) ) THEN
         RETURN;
      END;

      IF ( WildcardsNotPresent ( WBSRecordP ) ) THEN
          DisplayNumberBlanksRangeDialog ();
      ELSE
          GetMessage ( ModuleNumber + 6, ErrorMessage );
          (* "Wildcard characters entered into WBS form." *)
          Error ( ErrorMessage );
      END;
    ELSE
       GetMessage ( ModuleNumber + 7, ErrorMessage );
       (* "There are no tasks to renumber." *)
       Error ( ErrorMessage );
    END;

END TLWBSNumberBlanks.
