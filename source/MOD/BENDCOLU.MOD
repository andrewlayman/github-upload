(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE BEndColumns;

(*  =========================================================================
    Last Edit : September 26, 1990 2:00PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Handles scrolling list of output formats for importing.

    MODIFICATION HISTORY:

        23-Mar-89 RSC   Created from the old ColumnNames module, to support
                        the new Assignments Report.
        5-Sep-90 PFG    Add GoToCheckProc parameter to PickColumn.
        01-Aug-91 LAA   Removed the import of DoGoToWithPrompts.
    =========================================================================
*)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM BEndFormat             IMPORT
    (* VAR *)                   GetBEndInfo;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord;

FROM ColumnSupport          IMPORT
    (* TYPE *)                  AColumnTreeRecordPtr, AColumnTreeRecord,
    (* PROC *)                  DisposeColumnTree, PickColumn;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM GoTo                   IMPORT
    (* PROC *)                  NullGoToCheckProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM LStrings               IMPORT
    (* PROC *)                  Upshift, TrimFront, TrimRear, Copy, Fill,
                                LJust, SetLengthOf, StringsEqual, LengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Sorter                 IMPORT
    (* PROC *)                  SortTree;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, 
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    ModuleNumber            = 29000;

VAR
    ColumnTree              : ATree;
    UseCount                : CARDINAL;




    (*  BEndColumnsTreeExists --

        Query whether or not the resource columns tree already exists.

        Preconditons:
            None.

        Postconditions:
            TRUE will be returned iff the resource columns tree exists.
    *)

PROCEDURE BEndColumnsTreeExists(): BOOLEAN;

BEGIN                       (* BEndColumnsTreeExists *)

    RETURN (UseCount > 0);

END BEndColumnsTreeExists;





 (* This procedure supplies GoTo with the text names it needs. *)

PROCEDURE GetColumnName (       Node    : ATreeNode;
                          VAR   s       : ARRAY OF CHAR);

VAR
    DisplayRecord           : AColumnTreeRecordPtr;
    DataRecord              : AColumnDataRecord;
    ok                      : BOOLEAN;

BEGIN                       (* ColumnViewTitle *)

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    WITH DisplayRecord^ DO                                        (* 04-Jan-89 LAA *)
        IF (LengthOf(Name) = 0) THEN
            ok := GetBEndInfo( ID, ColumnName, 255, DataRecord);    (* 17-May-89 RSC *)
            LJust( DataRecord.StringValue );
            TrimRear( DataRecord.StringValue ); (* RSC 7-Feb-89 *)
            Copy(DataRecord.StringValue, Name);
        END;
        Copy(Name, s);
    END;

END GetColumnName;




 (* This procedure supplies GoTo with the text prompt it needs. *)

PROCEDURE GetColumnPrompt (       Node    : ATreeNode;
                            VAR   s       : ARRAY OF CHAR);
VAR
    DisplayRecord           : AColumnTreeRecordPtr;
BEGIN

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    GetMessage( ModuleNumber + DisplayRecord^.ID, s );

END GetColumnPrompt;







        (* ---------------------------------------------------------

            This procedure is a type of:

               "ALinkedListNodeCompareProc"  (From Sorter.Mod)

           Preconditions:
                First and Second are TreeNodes.

           Postconditions:
               IFF the first node is > the second node, TRUE is returned.


           RSC 9-Mar-89  Added this for sort support.

         ------------------------------------------------------------*)

PROCEDURE CompareTwoColumns( First, Second : AnObject ) : BOOLEAN;
VAR
    FirstNode,
    SecondNode          : ATreeNode;
    FirstOrder,
    SecondOrder         : CARDINAL;
    ColumnRecord        : AColumnTreeRecordPtr;
    DataRecord          : AColumnDataRecord;
    ok                  : BOOLEAN;
BEGIN
    FirstNode   := ATreeNode( First  );
    SecondNode  := ATreeNode( Second );

    ColumnRecord := FirstNode^.Methods^.GetDataObject( FirstNode );
    ok := GetBEndInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    FirstOrder   := DataRecord.CardinalValue;

    ColumnRecord := SecondNode^.Methods^.GetDataObject( SecondNode );
    ok := GetBEndInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    SecondOrder   := DataRecord.CardinalValue;

    RETURN (FirstOrder > SecondOrder);

END CompareTwoColumns;







PROCEDURE AddToTree(    ColumnID        : CARDINAL)
                                                   : BOOLEAN;

VAR
    ColumnRecord        : AColumnTreeRecordPtr;
    Node                : ATreeNode;

BEGIN                   (* AddToTree *)

    IF (NOT CreateTreeNode(Node)) THEN
        RETURN FALSE;
    END;
    ColumnTree^.Methods^.AddLast(ColumnTree, Node);
    NEW(ColumnRecord);
    Node^.Methods^.SetDataObject(Node, ColumnRecord);
    ColumnRecord^.ID := ColumnID;

    SetLengthOf(ColumnRecord^.Name, 0);  (* Too expensive to get name now. *)

    RETURN TRUE;

END AddToTree;







    (*  CreateBEndColumnsTree --  

            Create the tree of tasl column names for use by 
            PickBEndColumns and SearchForBEndColumns.

        Preconditions:
            None.

        Postconditions:
            If the use count is zero, and if heap space is available, the 
            column name tree will be created, and TRUE returned.  If the use
            count is > 0, it will just be incremented.  Otherwise,  FALSE will 
            be returned, and the tree won't have been created.  

            RSC 9-Mar-89  Columns are in sorted order, sorted by their
                          "SortOrder"
    *)


PROCEDURE CreateBEndColumnsTree() : BOOLEAN;

VAR
    i                       : CARDINAL;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* CreateBEndColumnTree *)

    IF (UseCount > 0) THEN 
        INC(UseCount);
        RETURN TRUE; 
    END;

    IF (ColumnTree <> NIL) THEN
        FatalError();
    END;

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(ColumnTree))) THEN
        RETURN FALSE;
    END;

    i := 1;
    REPEAT
        IF (NOT AddToTree(i)) THEN
            GetMessage(ModuleNumber + 199, s); (* "Not enough memory to make the columna name list." *)
            Error(s);
            DisposeColumnTree(ColumnTree);
            RETURN FALSE;
        END;
            (*  Sets CardValue to the next valid column ID, or returns 0  *)
        ok := GetBEndInfo( i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i  := DataRecord.CardinalValue;                            (* 04-Jan-89 LAA *)
    UNTIL (i = 0);

    ok := SortTree( ColumnTree, CompareTwoColumns );   (* RSC 9-Mar-89 *)

    IF (ok) THEN
        INC(UseCount);
    ELSE
        DisposeColumnTree(ColumnTree);
    END;

    RETURN ok;

END CreateBEndColumnsTree;



    (*  DisposeBEndColumnsTree --

            Get rid of the column name tree made by CreateBEndColumnsTree.

        Preconditions:
            The column name tree must have been created by a call to
            CreateBEndColumnsTree.

        Postconditions:
            If the use count is 1, the column name tree and all it's node 
            will be discarded.  Otherwise, the use count will be decremented.
    *)

PROCEDURE DisposeBEndColumnsTree();

BEGIN                       (* DisposeBEndColumnsTree *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    IF ((UseCount = 1) AND (ColumnTree <> NIL)) THEN
        DisposeColumnTree(ColumnTree);
    END;
    IF (UseCount > 0) THEN
        DEC(UseCount);
    END;

END DisposeBEndColumnsTree;






    (*  PickBEndColumn --

            Display the scrolling list of column names at the indicated
            coordinates, and allow the user to select one from it.

        Preconditions:
            The column name tree must have been created by a call to
            CreateBEndColumnsTree, and not discarded by DisposeBEndColumnsTree.

        Postconditions:
            If the user selects a new column name, the ColumnId and 
            ColumnName will be changed to that for the new column, and TRUE 
            will be returned.  If no column name is selected, FALSE will be 
            returned.
    *)


PROCEDURE PickBEndColumn(    Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                         VAR ColumnId       : CARDINAL;
                         VAR ColumnName     : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    Title                   : ARRAY [0..31] OF CHAR;

BEGIN                       (* PickBEndColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    GetMessage(ModuleNumber + 198, Title);

    RETURN PickColumn(ColumnTree, Ulx, Uly, Lrx, Lry, Title, GetColumnName,
                      GetColumnPrompt, NullGoToCheckProc, ColumnId, ColumnName);

END PickBEndColumn;





    (*  SearchForBEndColumn --

            Find the ColumnId in the resource column tree for the provided 
            column name (an LString).

        Preconditions:
            The resource column tree must have been created by a call to
            CreateBEndColumnsTree, and not discarded by DisposeBEndColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForBEndColumn(VAR ColumnName : ARRAY OF CHAR;
                              VAR ColumnId   : CARDINAL     )
                                                             : BOOLEAN;

VAR
    Node                    : ATreeNode;
    ColumnRecord            : AColumnTreeRecordPtr;
    s                       : ARRAY [0..25] OF CHAR;
    s1                      : ARRAY [0..25] OF CHAR;
    s2                      : ARRAY [0..25] OF CHAR;


    PROCEDURE Normalize(VAR NameIn          : ARRAY OF CHAR;
                        VAR NameOut         : ARRAY OF CHAR);

    BEGIN                   (* Normalize *)

        Copy(NameIn, NameOut);
        Upshift(NameOut);
        TrimFront(NameOut);
        TrimRear(NameOut);

    END Normalize;


BEGIN                       (* SearchForBEndColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    Normalize(ColumnName, s);
    Node := ColumnTree^.Methods^.GetFirst(ColumnTree);

    LOOP
        IF (Node = NIL) THEN
            EXIT;
        END;
        GetColumnName(Node, s1);                                  (* 04-Jan-89 LAA *)
        Normalize(s1, s2);
        IF (StringsEqual(s, s2)) THEN   (* RSC 1/2/88 *)
            ColumnRecord := Node^.Methods^.GetDataObject(Node);
            ColumnId := ColumnRecord^.ID;
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

    RETURN (Node <> NIL);

END SearchForBEndColumn;


BEGIN                       (* BEndColumns *)

    ColumnTree := NIL;
    UseCount := 0;

END BEndColumns.
