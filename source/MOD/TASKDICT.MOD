IMPLEMENTATION MODULE TaskDictionary;

  (*   Routines for detemining if WBS codes exist within the current task tree.
       These routines allow us to maintain a 'Dictionary' of hashed WBS codes.
       This allows us to determine very quickly whether a task node exists which
       contains a specific WBS code, as opposed to the old method of determination
       which involved the task importer to conduct a linear search of every task
       node in the tree to see if a match occurs. The old method was OK for
       small task trees, but as the amount of nodes increased ( > 150 - 200 nodes )
       the search time for a non-match was VERY slow. This method keeps the
       time linear.

        MODIFICATION HISTORY:

        16-Oct-89  MWP  Creation
        19-Oct-89  MWP  Removed FatalError calls.
  *)


FROM Allocs         IMPORT
    (* CONST *)             WBSLine,
    (* PROC *)              SetCodingField,
    (* TYPE *)              ATaskPtr,
    (* VAR *)               TaskTree,
    (* PROC *)              GetCodingField;

FROM Dialog         IMPORT
    (* PROC *)              Error, FatalError;

FROM Dictionary     IMPORT
    (* TYPE *)              ADictionary,
    (* PROC *)              CreateDictionary, ExpungeDictionary,
                            AddToDictionary, InDictionary;

FROM LStrings       IMPORT
    (* PROC *)              SetString, LengthOf, SetLengthOf, LJust, TrimRear;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATree, ATreeNode, ATreeOrder,
                            ATreeNodeAttribute;

VAR
    WBSDictionary           : ADictionary;


PROCEDURE  CreateWBSCodeDictionary () : BOOLEAN;
BEGIN
    IF ( DictionaryInUse ) THEN
        RETURN FALSE;
    END;

    WBSDictionary   := CreateDictionary (GetWBSCode);

    DictionaryInUse := WBSDictionary <> ADictionary(NIL);

    RETURN ( DictionaryInUse );

END CreateWBSCodeDictionary;


PROCEDURE  DeleteWBSCodeDictionary ();
BEGIN

    IF ( DictionaryInUse ) THEN
       ExpungeDictionary (WBSDictionary);
       DictionaryInUse := FALSE;
    END;

END DeleteWBSCodeDictionary;


PROCEDURE IsInDict ( VAR WBSCode : ARRAY OF CHAR;
                     VAR Node    : ATreeNode ) : BOOLEAN;
BEGIN
    Node := ATreeNode(NIL);

    IF ( NOT DictionaryInUse ) THEN
        RETURN FALSE;
    END;

    Node := InDictionary ( WBSCode, WBSDictionary);

    RETURN ( Node <> ATreeNode(NIL) );

END IsInDict;


PROCEDURE PutInDict ( VAR Node : ATreeNode ) : BOOLEAN;
VAR
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [0..255] OF CHAR;
    TempNode                : ATreeNode;
BEGIN
    IF ( NOT DictionaryInUse ) THEN
        RETURN FALSE;
    END;

    IF ( Node <> ATreeNode(NIL) ) THEN

       TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
       GetCodingField ( TaskPtr^, WBSLine, s );
       Node^.Methods^.UnlockUnchangedDataObject (Node);
       LJust    ( s );
       TrimRear ( s );

       IF ( LengthOf ( s ) > 0 ) THEN
          IF ( NOT IsInDict ( s, TempNode ) ) THEN
             IF (NOT AddToDictionary ( Node, WBSDictionary ) ) THEN
                  RETURN FALSE;
             END;
          END;
       END;
    END;

    RETURN TRUE;

END PutInDict;


PROCEDURE  LoadWBSCodes ();
VAR
    TaskNode                : ATreeNode ;
BEGIN

    IF ( NOT DictionaryInUse ) THEN
        RETURN;
    END;

    IF (TaskTree^.Methods^.GetFirst( TaskTree ) = NIL) THEN
        RETURN;
    END;


    TaskNode := ATreeNode(NIL);

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
    ok                      : BOOLEAN;
BEGIN

    GetWBSCode ( TaskNode, s );

    IF ( LengthOf ( s ) > 0 ) THEN
       FoundNode := InDictionary ( s, WBSDictionary );
       IF (FoundNode = NIL) THEN
           ok := AddToDictionary ( TaskNode, WBSDictionary );
       END;
    END;

END StoreWBSCode;


PROCEDURE GetWBSCode   (     Node    : ATreeNode;
                         VAR s       : ARRAY OF CHAR );
VAR
    TaskPtr                 : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);

    GetCodingField ( TaskPtr^, WBSLine, s );

    Node^.Methods^.UnlockUnchangedDataObject (Node);

    LJust    ( s );
    TrimRear ( s );

END GetWBSCode;


BEGIN

    DictionaryInUse := FALSE;

END TaskDictionary.
