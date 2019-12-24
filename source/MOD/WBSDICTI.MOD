IMPLEMENTATION MODULE WBSDictionary;

  (*   Routines for detemining if duplicate WBS codes exist across
       a Task range.

        MODIFICATION HISTORY:

         21-Apr-89  MWP  In the beginning...
         14-Jul-89  MWP  Incorporated routines to check for duplicate WBS Codes,
                         and if one is found, erase it.
         19-Jul-89  MWP  Consolidated various routines into general purpose
                         procedures for the creation, maintenance, and deletion
                         of WBS code dictionaries.
         20-Jul-89  MWP  Removed procedures CheckTaskTreeForDuplicateWBSCodes
                         CheckWBSCode. Turned ClearWBSCodes into a more
                         generic function, and renamed it to the more aptly
                         titled FlagDuplicateWBSCodes.
          2-Oct-89  MWP  Added display of progress messages.
          9-Oct-89  MWP  Removed text literals.
  *)


FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
    (* PROC *)              SetCodingField,
    (* TYPE *)              ATaskPtr,
    (* VAR *)               TaskTree;

FROM Dialog         IMPORT
    (* PROC *)              Error, FatalError;

FROM Dictionary     IMPORT
    (* TYPE *)              ADictionary,
    (* PROC *)              CreateDictionary, ExpungeDictionary,
                            AddToDictionary, InDictionary;

FROM LStrings       IMPORT
    (* PROC *)              SetString, LengthOf, SetLengthOf;

FROM WBSCommon      IMPORT
    (* CONST *)             MaxWbsLen,
    (* TYPE *)              AContextRecord,
                            WBSDictionary,
    (* VAR *)               DictionaryInUse,
    (* PROC *)              GetWBSCode;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATree, ATreeNode, ATreeOrder,
                            ATreeNodeAttribute;

FROM WBSDialog      IMPORT
                            ProgressMessage;

CONST
    (* No leading phrase for messages. *)
    ProgressMessagePhrase   =   0;                                    (* 2-Oct-89 MWP *)

VAR
    ErrorFlag               : BOOLEAN;


PROCEDURE  CreateWBSCodeDictionary () : BOOLEAN;                    (* 19-Jul-89 MWP *)
BEGIN
    IF ( DictionaryInUse ) THEN
        FatalError ();
    END;

    ErrorFlag := FALSE;

    WBSDictionary   := CreateDictionary (GetWBSCode);

    DictionaryInUse := WBSDictionary <> ADictionary(NIL);

    RETURN ( DictionaryInUse );

END CreateWBSCodeDictionary;


PROCEDURE  DeleteWBSCodeDictionary ();                              (* 19-Jul-89 MWP *)
BEGIN

    IF ( DictionaryInUse ) THEN
       ExpungeDictionary (WBSDictionary);
       DictionaryInUse := FALSE;
    END;

END DeleteWBSCodeDictionary;


PROCEDURE IsInDict ( VAR WBSCode : ARRAY OF CHAR ) : BOOLEAN;       (* 19-Jul-89 MWP *)
VAR
    FoundNode               : ATreeNode;
BEGIN
    IF ( NOT DictionaryInUse ) THEN
        FatalError ();
    END;

    FoundNode := InDictionary ( WBSCode, WBSDictionary);

    RETURN ( FoundNode <> NIL );

END IsInDict;

PROCEDURE PutInDict ( VAR Node : ATreeNode ) : BOOLEAN;             (* 19-Jul-89 MWP *)
BEGIN
    IF ( NOT DictionaryInUse ) THEN
        FatalError ();
    END;

    IF (NOT AddToDictionary ( Node, WBSDictionary ) ) THEN
       RETURN FALSE;
    END;

    RETURN TRUE;

END PutInDict;


PROCEDURE  LoadWBSCodes ();                                         (* 19-Jul-89 MWP *)
VAR
    TaskNode                : ATreeNode ;
BEGIN

    IF ( NOT DictionaryInUse ) THEN
        FatalError ();
    END;

    TaskNode := ATreeNode(NIL);

    ErrorFlag := FALSE;

    IF ( WBSDictionary <> ADictionary(NIL) ) THEN
       TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                        StoreWBSCode, ADR(TaskNode) );
    END;

END LoadWBSCodes;


PROCEDURE StoreWBSCode    ( VAR TaskNode  : ATreeNode;
                                Context   : ADDRESS   );
VAR
    FoundNode               : ATreeNode;
    s                       : ARRAY [0..100] OF CHAR;
    TaskPtr                 : ATaskPtr;
BEGIN

    IF ( ErrorFlag ) THEN
       RETURN;
    END;

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    GetWBSCode ( TaskNode, s );

    IF ( LengthOf ( s ) > 0 ) THEN
       FoundNode := InDictionary ( s, WBSDictionary );
       IF (FoundNode = NIL) THEN
           IF (NOT AddToDictionary ( TaskNode, WBSDictionary ) ) THEN
(***
               SetString ( s, "Out Of Sort Memory");
               Error (s);
***)
               ErrorFlag := TRUE;
           END;
       END;
    END;

END StoreWBSCode;


PROCEDURE FlagDuplicateWBSCodes ( Context : ADDRESS );             (* 20-Jul-89 MWP *)
BEGIN

    IF ( NOT DictionaryInUse ) THEN
        FatalError ();
    END;

    ErrorFlag := FALSE;


    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                     IsADuplicateWBSCode, Context);

END FlagDuplicateWBSCodes;


PROCEDURE IsADuplicateWBSCode    ( VAR TaskNode  : ATreeNode;
                                       Context   : ADDRESS   );
VAR
    TaskPtr                 : ATaskPtr;
    FoundNode               : ATreeNode;
    s                       : ARRAY [0..100] OF CHAR;

BEGIN

    IF ( ErrorFlag ) THEN
       RETURN;
    END;

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ProgressMessage ( ProgressMessagePhrase, TaskPtr^.taskname );    (* 2-Oct-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    GetWBSCode ( TaskNode, s );

    IF ( LengthOf ( s ) > 0 ) THEN
       FoundNode := InDictionary ( s, WBSDictionary);

       IF (FoundNode = NIL) THEN
           IF (NOT AddToDictionary (TaskNode, WBSDictionary)) THEN
(*******
               SetString ( s, "Out Of Sort Memory");
               Error (s);
******)
               ErrorFlag := TRUE;
           END;
       ELSE
           IF ( TaskNode^.Methods^.TestAttributeBit ( TaskNode, TempFlag1 ) ) THEN
               SetDoEraseFlagInNode ( TaskNode, TRUE );
           END;

           IF ( FoundNode^.Methods^.TestAttributeBit ( FoundNode, TempFlag1 ) ) THEN
               SetDoEraseFlagInNode ( FoundNode, TRUE );
           END;
       END;
    END;

END IsADuplicateWBSCode;


PROCEDURE ClearWBSCode ( VAR TaskNode : ATreeNode );
VAR
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [ 0..MaxWbsLen ] OF CHAR;
BEGIN
    SetLengthOf ( s, 0 );

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    SetCodingField ( TaskPtr^, WBSLine, s );

    TaskNode^.Methods^.UnlockFlexStorDataObject (TaskNode);

END ClearWBSCode;


PROCEDURE SetDuplicateFlagInNode ( VAR TaskNode : ATreeNode;
                                       Value    : BOOLEAN );
BEGIN
    TaskNode^.Methods^.SetAttributeBit ( TaskNode, TempFlag1, Value);

END SetDuplicateFlagInNode;


PROCEDURE SetDoEraseFlagInNode ( VAR TaskNode : ATreeNode;
                                     Value    : BOOLEAN );
BEGIN
    TaskNode^.Methods^.SetAttributeBit ( TaskNode, TempFlag2, Value);

END SetDoEraseFlagInNode;



PROCEDURE ClearFlag ( VAR TaskNode : ATreeNode;
                          Context  : ADDRESS );
BEGIN
    SetDuplicateFlagInNode ( TaskNode, FALSE );
    SetDoEraseFlagInNode ( TaskNode, FALSE );

END ClearFlag;



PROCEDURE ClearDuplicateFlagsInTree ( VAR Tree : ATree );
VAR
    TaskNode                : ATreeNode ;
BEGIN
    TaskNode := ATreeNode(NIL);

    Tree^.Methods^.TraverseTree( Tree,
                                 ParentAfterChild,
                                 9999,
                                 ClearFlag,
                                 ADR(TaskNode) );
END ClearDuplicateFlagsInTree;



PROCEDURE SetFlag ( VAR TaskNode : ATreeNode;
                          Context  : ADDRESS );
BEGIN
    SetDuplicateFlagInNode ( TaskNode, TRUE );
END SetFlag;


PROCEDURE SetDuplicateFlagsInTree ( VAR Tree : ATree );
VAR
    TaskNode                : ATreeNode ;
BEGIN
    TaskNode := ATreeNode(NIL);

    Tree^.Methods^.TraverseTree( Tree,
                                 ParentAfterChild,
                                 9999,
                                 SetFlag,
                                 ADR(TaskNode) );
END SetDuplicateFlagsInTree;



BEGIN
END WBSDictionary.
