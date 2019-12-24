IMPLEMENTATION MODULE WBSDialog;

  (*    WBS Dialog - Routines used by most WBS manager functions to display
                     information to the user.

        MODIFICATION HISTORY:

         17-Jul-89  MWP  In the beginning...
         29-Jul-89  MWP  Changed VerifyError to WBSError.
         29-Jul-89  MWP  ErrorDialog now calls WBSError to log the error.
         27-Aug-89  MWP  Log errors to WBS Errors column.
          2-Oct-89  MWP  Added procedure to display progress messages.
          8-Jan-91  TGS  WBSError was feeding the wrong CodingLine number
                         to SetCodingField.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
  *)


FROM Allocs         IMPORT
    (* CONST *)             TskNmLen,
                            FirstOtherCodingLine,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree,
    (* PROC *)              SetCodingField;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox, FatalError, Error, Message;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, ConcatS, ConcatLS,
                            CtoS, LengthOf, Copy, Search, Compare;

FROM MsgFile        IMPORT
                            GetMessage;

FROM RptCommon      IMPORT
                            GetMessageWord;

FROM TaskColNumbers IMPORT 
    (* CONST *)             NumberOfCodingFields;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATree, ATreeNode;

FROM WBSCommon      IMPORT
    (* CONST *)             WBSModuleNumberBase,
                            WBSErrorCodingField,                  (* 27-Aug-89 MWP *)
    (* VAR   *)             AWBSError,
                            AWBSErrorSet,
    (* PROC *)              SetWBSHighlight;


CONST
    ModuleNumber     =   WBSModuleNumberBase + 70;

VAR
    LastPrefixPhrase   : CARDINAL;
    PrefixPhraseText   : ARRAY [0..255] OF CHAR;


(*=============================================================================
 * ErrorDialog
 * -----------
 *    Display an verify and renumber error menu to the user. A description
 * of the error is displayed, and the user is prompted as to whether
 * allow renumbering of the WBS code, Leave it alone, or Renumber all
 * remaining WBS codes found to be in error.
 *
 * INPUT   : TaskNode    - Task with WBS code in error.
 *           ErrChoice   - What is wrong with the WBS code.
 * OUTPUT  : RenumberAll - Set to TRUE only if the user selects Renumber all
 *                         remaining WBS codes.
 *
 * RETURNS : TRUE  - If user selects Renumber or Renumber all remaining.
 *           FALSE - Leave WBS code alone.
 *============================================================================*)
PROCEDURE ErrorDialog ( VAR TaskNode    : ATreeNode;
                            ErrChoice   : AWBSError;
                            ShowErrors  : AWBSErrorSet;
                        VAR LogErrors   : AWBSErrorSet;
                        VAR RenumberAll : BOOLEAN ) : BOOLEAN;
VAR
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..29] OF CHAR;
    MenuPrefix              : ARRAY [0..29] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
    Name                    : ARRAY [0..TskNmLen] OF CHAR;
    TaskPtr                 : ATaskPtr;
BEGIN
    WBSError ( TaskNode, ErrChoice, ShowErrors, LogErrors );       (* 29-Jul-89 MWP *)

    IF ( RenumberAll ) THEN
       RETURN TRUE;
    END;

    Choice := ORD(ErrChoice);

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    Copy ( TaskPtr^.taskname, Name );

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

    SetLengthOf ( MenuPrefix, 0 );

    GetMessageWord( ModuleNumber + 6, Choice, Title );
    (* "Blank WBS Code,
        Duplicate WBS Error,
        Parent WBS Error,
        WBS Code Error,
        WBS Code Mismatch *)

    IF ( ErrChoice <> ParentError ) THEN
       GetMessage ( ModuleNumber + 8, Prefix );
       (* The task ~ *)
    ELSE
       GetMessage ( ModuleNumber + 9, Prefix );
       (*  The parent task of ~ *)
    END;

    ConcatLS ( Prefix, Name );

    GetMessage ( ModuleNumber + 20 + Choice, Choices );

    (*     ~ has a blank WBS code.
           ~ has a duplicate WBS code.
           ~ has an invalid WBS code.
           ~ has an invalid WBS code.
           ~ has WBS code segments which do not match it's parents. *)

    ConcatLS ( Prefix, Choices );

    GetMessage ( ModuleNumber + 28, Choices );
    (*  "üüShould ~" *)
    ConcatLS ( Prefix, Choices );

    ConcatLS ( Prefix, Name );

    GetMessage ( ModuleNumber + 29, Choices );
    (*  be renumbered?" *)

    ConcatLS ( Prefix, Choices );

    GetMessage ( ModuleNumber + 7, Choices );
    (* "No, Yes, Renumber all remaining" *)

    Choice := 1;   (* No *)

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, Choice);

    IF ( NOT ok ) THEN
       RETURN FALSE;
    END;

    CASE Choice OF
         1  :
            RETURN FALSE;
     |   2  :
            RETURN TRUE;
     |   3  :
            RenumberAll := TRUE;
            RETURN TRUE;
     ELSE
        FatalError();
     END;

     RETURN FALSE;

END ErrorDialog;


(*=============================================================================
 * VerifyError
 * -----------
 *
 * INPUT   :  TaskNode  - Member of the task tree where error message will
 *                        be placed.
 *            ErrChoice - The type of error that has occured.
 * OUTPUT  :  Nothing.
 * RETURNS :  Nothing.
 *
 * POSTCONDITION - The AUX 20 field of TaskNode will be replaced by the error
 *                 message.
 *============================================================================*)
PROCEDURE WBSError ( VAR TaskNode    : ATreeNode;
                         ErrChoice   : AWBSError;
                         ShowErrors  : AWBSErrorSet;
                     VAR LogErrors   : AWBSErrorSet );
CONST
    ErrorModuleNumber       = 5350;
VAR
    Choices                 : ARRAY [0..255] OF CHAR;
    TaskPtr                 : ATaskPtr;
BEGIN

    IF ( ErrChoice IN ShowErrors ) THEN
        GetMessage ( ErrorModuleNumber + ORD(ErrChoice), Choices );

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        SetCodingField (TaskPtr^, 
                        FirstOtherCodingLine + NumberOfCodingFields, (* 8-Jan-91 TGS *)
                        Choices );  (* 27-Aug-89 MWP *)

        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

        SetWBSHighlight ( TaskNode );
    END;

    INCL( LogErrors, ErrChoice );

END WBSError;

PROCEDURE ProgressMessage (     PrefixPhrase : CARDINAL;
                            VAR Suffix       : ARRAY OF CHAR );
VAR
    s : ARRAY [0..255] OF CHAR;
BEGIN

    IF ( PrefixPhrase > 0 ) THEN
       IF ( PrefixPhrase <> LastPrefixPhrase ) THEN
          LastPrefixPhrase := PrefixPhrase;
          GetMessage ( PrefixPhrase, PrefixPhraseText );
       END;
       Copy ( PrefixPhraseText, s );
    ELSE
       SetLengthOf ( s, 0 );
    END;

    ConcatLS ( s, Suffix );
    Message ( s );

END ProgressMessage;

BEGIN
    SetLengthOf ( PrefixPhraseText, 0 );
    LastPrefixPhrase := 0;

END WBSDialog.

