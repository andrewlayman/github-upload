MODULE TLWBSTransfer;

  (*    Transfer a range of WBS codes.

        MODIFICATION HISTORY:

         20-Apr-89  MWP  In the beginning...
          1-Jul-89  MWP  Swapped the order of HOW the transfer is performed
                         in the dialog box.
          8-Jul-89  MWP  Do not move a zero length string into the WBS field,
                         wiping out what was previously there.
        29-Jul-89   MWP  Do not assume extract if the user selects to transfer
                         from Tasks.
         10-Aug-89  KKC  Add copyright message.
         19-Aug-89  MWP  If performing an exchange of WBS and Task name, if
                         WBS is blank, do not wipe out Task name.
          2-Oct-89  MWP  Added display of progress messages.
         16-Nov-89  MWP  If the user selects to ESC off of How To Transfer
                         form, return.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine, OBSLine, AUXLine,
                            FirstOtherCodingLine,
                            WBSLen, OBSLen, AUXLen,
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
    (* PROC *)              SetLengthOf, SetString, ConcatS,
                            SubStr, LengthOf, Copy;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM Text           IMPORT
    (* PROC *)              CopyLine, AssignLine, TextExists;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree;

FROM WBSCommon      IMPORT
                            WBSModuleNumberBase,
                            MaxWbsLen,
                            MaxWbsSize,
    (* PROC *)              SelectWBSRangeDialog;

FROM WBSDialog      IMPORT
    (* PROC *)              ProgressMessage;

CONST
    ModuleNumber  =   WBSModuleNumberBase + 80;
    Exchange      =   2;                                             (* 1-Jul-89 MWP *)
    Extract       =   1;                                             (* 1-Jul-89 MWP *)
    FromTask      =   1;
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)

VAR
    FromFieldChoice         : CARDINAL;
    HowToTransfer           : CARDINAL;
    ErrorMessage            : ARRAY [0..255] OF CHAR;


PROCEDURE DisplayTransferRangeDialog ();
VAR
    RangeChoice             : CARDINAL;
    Title                   : ARRAY [0..255] OF CHAR;
    MenuPrefix              : ARRAY [0..255] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN
    GetMessage ( ModuleNumber, Title );
    (* "WBS Transfer Tasks" *)
    GetMessage ( ModuleNumber + 1, Prefix );
    (* "On which tasks do you want to transfer WBSü"
       "numbers?" *)

    RangeChoice := 1;

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 RangeChoice );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    SetLengthOf ( Prefix, 0 );
    SetLengthOf ( Title, 0 );

    GetMessage ( ModuleNumber + 2, Choices );
    (* "Task Name,Keyword,OBS,Notes" *)
    GetMessage ( ModuleNumber + 3, MenuPrefix );
    (* "FROM" *)

    FromFieldChoice := FromTask;

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, FromFieldChoice);

    IF ( NOT ok ) THEN
       RETURN;
    END;

    SetLengthOf ( Prefix, 0 );
    SetLengthOf ( Title, 0 );

    GetMessage ( ModuleNumber + 4, Choices );
    (* 'Extract up to Space or "/" ,Interchange'*)               (* 1-Jul-89 MWP *)
    GetMessage ( ModuleNumber + 5, MenuPrefix );
    (* "HOW:" *)

    HowToTransfer := Extract;                                    (* 1-Jul-89 MWP *)

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, HowToTransfer );

    IF ( NOT ok ) THEN                                           (* 16-Nov-89 MWP *)
       RETURN;
    END;

    CASE RangeChoice OF
        1   :
             TransferAllWBSCodes ( );
    |   2   :
             TransferFamily ();
    |   3   :
             TransferChildren ();
    |   4   :
             TransferThisTasksWBS ();
    ELSE
       FatalError ();
    END;

    SetLengthOf ( Title, 0 );
    ProgressMessage ( ProgressMessagePhrase, Title );               (* 2-Oct-89 MWP *)

    ScheduleSaved := FALSE;         (* 9/14/91 EGK *)
    UnSetState (Formatted);

END DisplayTransferRangeDialog;


PROCEDURE TransferData ( VAR  From    : ARRAY OF CHAR;
                         VAR  To      : ARRAY OF CHAR;
                              MaxLen  : CARDINAL );
VAR
    i                       : CARDINAL;
    FromLen                 : CARDINAL;
BEGIN

    FromLen := LengthOf ( From );
    IF ( FromLen > MaxLen ) THEN
       FromLen := MaxLen;
    END;

    i := 1;

    IF ( HowToTransfer = Exchange ) THEN
       SubStr ( From, To, i, FromLen );
    ELSE
       WHILE ( From[ i ] <> ' ' ) AND
             ( From[ i ] <> '/' ) AND
             ( i <= FromLen ) DO
           To[ i ] := From[ i ];
           INC(i);
       END;
       To[ 0 ] := CHR(i - 1);
    END;
END TransferData;


PROCEDURE TransferWBS ( VAR TaskNode : ATreeNode;
                            Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [0..255] OF CHAR;
    NoteText                : ARRAY [0..255] OF CHAR;
    WBSCode                 : ARRAY [0..MaxWbsLen] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    IF ( HowToTransfer = Exchange ) THEN
        GetCodingField ( TaskPtr^, WBSLine, WBSCode );
    END;

    ok := TRUE;

    SetLengthOf ( s, 0 );

    CASE FromFieldChoice OF
        1   : (* Taskname *)
             TransferData ( TaskPtr^.taskname, s, MaxWbsLen );
             IF ( HowToTransfer = Exchange ) THEN
                IF ( LengthOf ( WBSCode ) > 0 ) THEN                (* 19-Aug-89 MWP *)
                    Copy ( WBSCode, TaskPtr^.taskname );
                END;
             END;

    |   2   : (* Keyword *)
             GetCodingField ( TaskPtr^, AUXLine, s );
             IF ( HowToTransfer = Exchange ) THEN
                IF ( LengthOf ( WBSCode ) > AUXLen ) THEN
                   SetLengthOf ( WBSCode, AUXLen );
                END;

                SetCodingField ( TaskPtr^, AUXLine, WBSCode );
             ELSE
                TransferData ( s, s, WBSLen );
             END;
    |   3   :

             GetCodingField ( TaskPtr^, OBSLine, s );
             IF ( HowToTransfer = Exchange ) THEN
                IF ( LengthOf ( WBSCode ) > OBSLen ) THEN
                   SetLengthOf ( WBSCode, OBSLen );
                END;
                SetCodingField ( TaskPtr^, OBSLine, WBSCode );
             ELSE
                TransferData ( s, s, WBSLen );
             END;

    |   4   :
             IF ( TextExists ( TaskPtr^.notes ) ) THEN
                CopyLine( TaskPtr^.notes, 0, NoteText );
                TransferData ( NoteText, s, MaxWbsLen );
                IF ( HowToTransfer = Exchange ) THEN
                   ok := AssignLine ( WBSCode, 0, TaskPtr^.notes );
                END;
             END;

    |   5   : (* AUX 1 *)
             GetCodingField ( TaskPtr^, FirstOtherCodingLine, s );

                IF ( HowToTransfer = Exchange ) THEN
                   IF ( LengthOf ( WBSCode ) > AUXLen ) THEN
                      SetLengthOf ( WBSCode, AUXLen );
                   END;
                   SetCodingField ( TaskPtr^, FirstOtherCodingLine, WBSCode );
                ELSE
                   TransferData ( s, s, WBSLen );
                END;

    |   6   : (* AUX 2 *)
             GetCodingField ( TaskPtr^, FirstOtherCodingLine + 1, s );

                 IF ( HowToTransfer = Exchange ) THEN
                    IF ( LengthOf ( WBSCode ) > AUXLen ) THEN
                       SetLengthOf ( WBSCode, AUXLen );
                    END;
                    SetCodingField ( TaskPtr^, FirstOtherCodingLine + 1, WBSCode );
                 ELSE
                    TransferData ( s, s, WBSLen );
                 END;

    |   7   : (* AUX 3 *)
             GetCodingField ( TaskPtr^, FirstOtherCodingLine + 2, s );

                 IF ( HowToTransfer = Exchange ) THEN
                    IF ( LengthOf ( WBSCode ) > AUXLen ) THEN
                       SetLengthOf ( WBSCode, AUXLen );
                    END;
                    SetCodingField ( TaskPtr^, FirstOtherCodingLine + 2, WBSCode );
                 ELSE
                    TransferData ( s, s, WBSLen );
                 END;
    ELSE
       FatalError ();
    END;

    IF ( ok ) THEN
       IF ( LengthOf ( s ) > WBSLen ) THEN
          SetLengthOf ( s, WBSLen );
       END;
       IF ( LengthOf ( s ) > 0 ) THEN                             (* 9-Jul-89 MWP *)
          SetCodingField ( TaskPtr^, WBSLine, s );
       END;
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
END TransferWBS;

PROCEDURE TransferAllWBSCodes ();
VAR
    TaskNode                : ATreeNode ;
BEGIN
    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentAfterChild,
                                     999,
                                     TransferWBS,
                                     ADR(TaskNode) );
END TransferAllWBSCodes;

PROCEDURE TransferFamily ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    TransferThisTasksWBS ();
    TransferChildren ();

END TransferFamily;

PROCEDURE TransferChildren ();
VAR
    CursorNode              : ATreeNode;
    Subtree                 : ATree;
BEGIN

    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    Subtree := CursorNode^.Methods^.GetSubtree (CursorNode);

    IF (Subtree <> NIL) THEN
        Subtree^.Methods^.TraverseTree (Subtree,
                                        ParentAfterChild,
                                        9999,
                                        TransferWBS,
                                        ADR(CursorNode));
    END;

END TransferChildren;


PROCEDURE  TransferThisTasksWBS ();
VAR
    CursorNode              : ATreeNode;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    CursorNode := GanttChart^.Methods^.GetCursorNode(GanttChart);

    TransferWBS ( CursorNode, NIL );

END TransferThisTasksWBS;



VAR
    ok                      : BOOLEAN;
BEGIN
   (* Check for task tree empty before we start *)

   IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN
       DisplayTransferRangeDialog ();
    ELSE
       GetMessage ( ModuleNumber + 6, ErrorMessage );
       (* "There are no tasks to transfer" *)
       Error ( ErrorMessage );
    END;

END TLWBSTransfer.
