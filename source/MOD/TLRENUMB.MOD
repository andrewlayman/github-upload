MODULE TLRenumber;

  (*    Renumber a range of WBS codes.

        MODIFICATION HISTORY:

         18-Apr-89  MWP  In the beginning...
          6-Jun-89  AJL  Removed import of AFilterRecordPointer.
                         Remove use of FiltersOn.
         29-Jul-89  MWP  Implemented new error notification scheme.
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Use AWBSPtr instead of ADDRESS.
         18-Aug-89  MWP  Clear WBS error field in all tasks in range.
         27-Aug-89  MWP  Remove call to ResetFilters.
          2-Oct-89  MWP  Added display of progress messages.
  *)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
    (* PROC *)              SetCodingField,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree;

FROM Chart          IMPORT
    (* VAR *)               GanttChart;

FROM Dialog         IMPORT
    (* PROC *)              FatalError, Error;

FROM Dictionary     IMPORT
    (* TYPE *)              ADictionary,
    (* PROC *)              InDictionary;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, ConcatLS,
                            LengthOf, Copy;

FROM MsgFile        IMPORT
                            GetMessage;

FROM Overlays     IMPORT
    (* PROC *)              OverlayContext;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATree;


FROM WBSCommon      IMPORT
                            WBSModuleNumberBase,
                            MaxWbsLen,
    (* TYPE *)              AContextRecord,
                            AWBSError,
                            AWBSErrorSet,
                            AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
                            AContextPtr,
                            MaxWbsRows,
    (* PROC *)              GetWBSCode,
                            ClearWBSFilterBitsInTask,               (* 18-Aug-89 MWP *)
                            ClearWBSFilterBitsInTree,
                            SetWBSCode,
                            CheckForWildCardCharacter,
                            DisplayErrorMessage,
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
                            CheckParentWBS,
                            CalculateWBSCardinalValue;

CONST
    ModuleNumber  =   WBSModuleNumberBase + 50;
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)

VAR
    ProcessLevel            : CARDINAL;
    TempBuffer              : ARRAY [0..255] OF CHAR;
    ErrorMessage            : ARRAY [0..255] OF CHAR;
    ErrorFlag               : BOOLEAN;
    Dictionary              : ADictionary;
    ContextRecordP          : AContextPtr;


PROCEDURE SelectRenumberRange ( WBSFormP : AWBSPtr );               (* 15-Aug-89 MWP *)
CONST
    AllTasks               = 1;
    Family                 = 2;
    Children               = 3;
    SingleTask             = 4;
VAR
    ok                      : BOOLEAN;
BEGIN

    IF ( CreateWBSCodeDictionary () ) THEN
        LoadWBSCodes ();
    ELSE
        RETURN;
    END;

    WITH ContextRecordP^ DO
        CASE RangeChoice OF
            AllTasks   :
                 RenumberAllWBSCodes ( WBSFormP );
        |   Family     :
                 RenumberFamily ( WBSFormP );
        |   Children   :
                 RenumberChildren ( WBSFormP );
        |   SingleTask   :
                 ok := RenumberTask ( WBSFormP );
        ELSE
           FatalError ();
        END;
    END;

    DeleteWBSCodeDictionary ();

    SetLengthOf ( TempBuffer, 0 );
    ProgressMessage ( ProgressMessagePhrase, TempBuffer );       (* 2-Oct-89 MWP *)


    IF ( ContextRecordP^.ErrorsFound <> AWBSErrorSet{} ) THEN
       DisplayErrorMessage ();
    END;

END SelectRenumberRange;


PROCEDURE RenumberAllWBSCodes ( WBSFormP : AWBSPtr );               (* 15-Aug-89 MWP *)
VAR
    TaskNode                : ATreeNode;
BEGIN

    ClearWBSFilterBitsInTree ( TaskTree );                         (* 18-Aug-89 MWP *)

    TaskNode := TaskTree^.Methods^.GetFirst ( TaskTree );
    CalculateWBS ( TaskNode, WBSFormP );

END RenumberAllWBSCodes;


PROCEDURE RenumberFamily ( WBSFormP : AWBSPtr );                    (* 15-Aug-89 MWP *)
BEGIN
   IF ( RenumberTask ( WBSFormP ) ) THEN
      RenumberChildren ( WBSFormP );
   END;

END RenumberFamily;


PROCEDURE RenumberChildren ( WBSFormP : AWBSPtr );                  (* 15-Aug-89 MWP *)
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
    TaskNode                : ATreeNode;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
       ClearWBSFilterBitsInTree ( Subtree );                      (* 18-Aug-89 MWP *)
       TaskNode:= Subtree^.Methods^.GetFirst ( Subtree );
       CalculateWBS ( TaskNode, WBSFormP );
    END;

END RenumberChildren;


PROCEDURE RenumberTask ( WBSFormP : AWBSPtr ) : BOOLEAN;            (* 15-Aug-89 MWP *)
CONST
    Previous = 1;
    Next     = 2;
VAR
    CursorNode              : ATreeNode;
    FoundNode               : ATreeNode;
    ok                      : BOOLEAN;
    Loop                    : BOOLEAN;
    ParentWBS               : ARRAY [0..MaxWbsLen] OF CHAR;
    s                       : ARRAY [0..MaxWbsLen] OF CHAR;
    PrevValue, NextValue,
    HighValue, Total        : CARDINAL;
    Err                     : AWBSError;
    TaskPtr                 : ATaskPtr;
BEGIN


    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    TaskPtr := CursorNode^.Methods^.LockFlexStorDataObject( CursorNode );
    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)
    CursorNode^.Methods^.UnlockFlexStorDataObject( CursorNode );

    ClearWBSFilterBitsInTask ( CursorNode, NIL );                   (* 18-Aug-89 MWP *)

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

    IF ( NOT CheckParentWBS ( CursorNode,
                              WBSFormP,
                              ContextRecordP,
                              ParentWBS ) ) THEN
        RETURN FALSE;
    END;

    INC( HighValue );

    Loop := TRUE;
    ProcessLevel := CursorNode^.Methods^.IndentationLevel ( CursorNode );

    WHILE Loop DO
       IF ( CreateAWbsCode ( HighValue,
                             ProcessLevel,
                             TempBuffer,
                             ParentWBS,
                             WBSFormP,
                             Err          ) ) THEN

           Total :=  LengthOf ( ParentWBS ) + LengthOf ( TempBuffer );

           IF ( Total <= MaxWbsLen ) THEN
               Copy ( ParentWBS, s );
               ConcatLS ( s, TempBuffer );

               IF ( IsInDict ( s ) ) THEN
                  INC(HighValue);
               ELSE
                   (* Code is unique, log it to the dictionary and set it in
                      the task node. *)
                   SetWBSCode ( CursorNode, s );
                   Loop := FALSE;
               END;
           ELSE
              WBSError ( CursorNode,                   (* 29-Jul-89 MWP *)
                         WBSTooLarge,
                         ContextRecordP^.ShowThese,
                         ContextRecordP^.ErrorsFound );
              RETURN FALSE;
           END;
       ELSE
           WBSError ( CursorNode,                   (* 29-Jul-89 MWP *)
                      Err,
                      ContextRecordP^.ShowThese,
                      ContextRecordP^.ErrorsFound );
           RETURN FALSE;
       END;
    END;

    RETURN TRUE;

END RenumberTask;


PROCEDURE CalculateWBS ( VAR CurrentTree : ATreeNode;
                             WBSFormP    : AWBSPtr );               (* 15-Aug-89 MWP *)
VAR
    LevelCounter,
    Total,
    ParentLevel             : CARDINAL;
    TaskNode                : ATreeNode;
    ParentNode              : ATreeNode;
    TaskPtr                 : ATaskPtr;
    Tree                    : ATree;
    ParentOk                : BOOLEAN;
    ParentWBS               : ARRAY [0..MaxWbsLen] OF CHAR;
    s                       : ARRAY [0..MaxWbsLen] OF CHAR;
    Err                     : AWBSError;
BEGIN

    TaskNode     := CurrentTree;
    LevelCounter := 1;
    ParentOk     := TRUE;

    SetLengthOf ( ParentWBS, 0 );

    ProcessLevel := TaskNode^.Methods^.IndentationLevel ( TaskNode );

    ParentNode   := TaskNode^.Methods^.Parent ( TaskNode );

    IF ( ParentNode <> ATreeNode(NIL) ) THEN
       ParentLevel := ParentNode^.Methods^.IndentationLevel ( ParentNode );

       GetWBSCode ( ParentNode, ParentWBS );

       IF ( LengthOf ( ParentWBS ) > 0 )  THEN
          IF ( NOT StripOffShowCharacters ( ParentLevel,
                                            WBSFormP,
                                            ParentWBS,
                                            ParentWBS ) ) THEN
             IF ( NOT ErrorFlag ) THEN
                GetMessage ( ModuleNumber + 2, ErrorMessage );
                (* "Error within Parent WBS code" *)
                Error ( ErrorMessage );
                ErrorFlag := TRUE;
             END;
             ParentOk := FALSE;

             WBSError ( ParentNode,                   (* 29-Jul-89 MWP *)
                        BadWBSError,
                        ContextRecordP^.ShowThese,
                        ContextRecordP^.ErrorsFound );
          END;
       ELSE
          WBSError ( ParentNode,                                   (* 29-Jul-89 MWP *)
                     BlankError,
                     ContextRecordP^.ShowThese,
                     ContextRecordP^.ErrorsFound );
          ParentOk := FALSE;
       END;
    END;

    WHILE ( TaskNode <> ATreeNode(NIL) ) DO
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)
        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

        IF ( ParentOk ) THEN

           IF ( CreateAWbsCode ( LevelCounter,
                                 ProcessLevel,
                                 TempBuffer,
                                 ParentWBS,
                                 WBSFormP,
                                 Err          ) ) THEN
               Total := LengthOf ( ParentWBS ) + LengthOf ( TempBuffer );
               IF ( Total <= MaxWbsLen ) THEN

                   Copy ( ParentWBS, s );
                   ConcatLS ( s, TempBuffer );

                   TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                   SetCodingField ( TaskPtr^, WBSLine, s );
                   TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
               ELSE
                   WBSError ( TaskNode,                            (* 29-Jul-89 MWP *)
                              WBSTooLarge,
                              ContextRecordP^.ShowThese,
                              ContextRecordP^.ErrorsFound );
               END;
           ELSE
               WBSError ( TaskNode,                                (* 29-Jul-89 MWP *)
                          Err,
                          ContextRecordP^.ShowThese,
                          ContextRecordP^.ErrorsFound );
           END;
        ELSE
           WBSError ( TaskNode,                                     (* 29-Jul-89 MWP *)
                      ParentError,
                      ContextRecordP^.ShowThese,
                      ContextRecordP^.ErrorsFound );
        END;

        TaskNode := TaskNode^.Methods^.GetNext ( TaskNode );
        INC(LevelCounter);
    END;

    WHILE ( CurrentTree <> ATreeNode(NIL) ) DO

       Tree := CurrentTree^.Methods^.GetSubtree ( CurrentTree );

       IF ( Tree <> ATree(NIL) ) THEN
            TaskNode:= Tree^.Methods^.GetFirst ( Tree );
            CalculateWBS ( TaskNode, WBSFormP );
       END;

       CurrentTree := CurrentTree^.Methods^.GetNext ( CurrentTree );
    END;

END CalculateWBS;


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
    WBSRecordP              :    AWBSPtr;                           (* 15-Aug-89 MWP *)

BEGIN
    ContextRecordP := OverlayContext();

    ProcessLevel := 0;

    ErrorFlag := FALSE;

    SetString ( FormName, "TLWBS" );

    IF ( NOT SetWBSValues ( FormName, WBSRecordP ) ) THEN
        RETURN;
    END;

    IF ( WildcardsNotPresent ( WBSRecordP ) ) THEN
       SelectRenumberRange ( WBSRecordP );
    ELSE
       GetMessage ( ModuleNumber + 4, ErrorMessage );
       (* "Wildcard characters entered into WBS form." *)
       Error ( ErrorMessage );
    END;

END TLRenumber.
