(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE EdgeColumns;

(*  =========================================================================
    Last Edit : June 10, 1991 4:48PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Handles scrolling list of resource columns.

    MODIFICATION HISTORY:

        22-Dec-88 LAA   Adjusted for new parameters to GetColumnInfo.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
        04-Jan-89 LAA   Next column ID is now returned in CardinalValue rather
                        than RealValue.  Also used a WITH statement in 
                        GetColumnName, and called GetColumnName from 
                        SearchForColumnName to avoid duplicate code.
        10-Jan-89 RSC   Changed Storage to Space.
         8-Mar-89 RSC   Sort the list of column names, based on Sort Order.
                        Also, Put out prompts for column choices.
        16-Mar-89 LAA   Created from the old ColumnNames module, to support
                        the new Assignments Report.
        17-Mar-89 RSC   Upgraded for resource format support.
        5-Sep-90  PFG   Add GoToCheckProc parameter to PickColumn.
        24-Sep-90 PFG   Implemented user-defined column headings for
                        resource columns.
        2-Oct-90  PFG   Moved the GoToCheckProc stuff again...out of ColFind
                        and into the TLColNam overlay.
       19-Oct-90  AJL   Renumbered a phrase.
        10-Jun-91 PFG   Added GetRsrcColumnName to get the latest resource
                        column name and format it for use in a data column
                        field of a form.
        24-Jul-91 LAA   Removed use of GetInfo and OutlineView fields of the
                        ColumnContext record, which was changed to fix bug
                        #4768.
        17-Sep-91 LAA   In CrossTabGoToCheckProc, incorporated a change which
                        I'd made to TaskColumns on 23-Jul-91, which will force
                        a repaint of the column list after a change made via
                        F2.
         9-Jan-92 AJL   Created this from RsrcColu.
    =========================================================================
*)


FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord;

FROM EdgeFormat             IMPORT
    (* VAR *)                   GetEdgeInfo;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM ColumnSupport          IMPORT
    (* CONST *)                 DescriptionIndex,
    (* TYPE *)                  AColumnTreeRecordPtr, AColumnTreeRecord,
    (* PROC *)                  DisposeColumnTree, PickColumn;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM LStrings               IMPORT
    (* PROC *)                  Upshift, TrimFront, TrimRear, Copy, Fill,
                                LJust, SetLengthOf, StringsEqual, LengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM Sorter                 IMPORT
    (* PROC *)                  SortTree;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, 
    (* PROC *)                  CreateTree, CreateTreeNode;



VAR
    ColumnTree              : ATree;
    UseCount                : CARDINAL;




    (*  EdgeColumnsTreeExists --

        Query whether or not the resource columns tree already exists.

        Preconditons:
            None.

        Postconditions:
            TRUE will be returned iff the resource columns tree exists.
    *)

PROCEDURE EdgeColumnsTreeExists(): BOOLEAN;

BEGIN                       (* EdgeColumnsTreeExists *)

    RETURN (UseCount > 0);

END EdgeColumnsTreeExists;





 (* This procedure supplies GoTo with the text names it needs. *)

PROCEDURE GetColumnName (       Node    : ATreeNode;
                          VAR   s       : ARRAY OF CHAR);

VAR
    DisplayRecord           : AColumnTreeRecordPtr;

BEGIN                       (* ColumnViewTitle *)

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    WITH DisplayRecord^ DO                                        (* 04-Jan-89 LAA *)
        IF (LengthOf(Name) = 0) THEN
            GetEdgeColumnName( ID, Name );  (* 10-Jun-91 PFG *)
        END;
        Copy(Name, s);
    END;

END GetColumnName;




    (*  GetEdgeColumnName --

        Get the latest column name for the column ID passed.  Format it as
        needed for the data column fields on forms and return that string.

        Preconditons:
            A valid column ID must be passed in ColumnID.

        Postconditions:
            The string is returned in String.
    *)

PROCEDURE GetEdgeColumnName(    ColumnID        : CARDINAL;
                                VAR String      : ARRAY OF CHAR);

VAR
    DataRecord              : AColumnDataRecord;
    ok                      : BOOLEAN;

BEGIN

    ok := GetEdgeInfo( ColumnID, ColumnName, HIGH(DataRecord.StringValue),
                       DataRecord);
    LJust (DataRecord.StringValue);
    TrimRear( DataRecord.StringValue );
    Copy(DataRecord.StringValue, String);

END GetEdgeColumnName;









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
    ok := GetEdgeInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    FirstOrder   := DataRecord.CardinalValue;

    ColumnRecord := SecondNode^.Methods^.GetDataObject( SecondNode );
    ok := GetEdgeInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
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







    (*  CreateEdgeColumnsTree --  

            Create the tree of edge column names for use by 
            PickEdgeColumns and SearchForEdgeColumns.

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


PROCEDURE CreateEdgeColumnsTree() : BOOLEAN;

VAR
    i                       : CARDINAL;
    DataRecord              : AColumnDataRecord;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* CreateEdgeColumnTree *)

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
            GetMessage(2609, s); (* "Not enough memory to make the columna name list." *)
            Error(s);
            DisposeColumnTree(ColumnTree);
            RETURN FALSE;
        END;
            (*  Sets CardValue to the next valid column ID, or returns 0  *)
        ok := GetEdgeInfo( i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i  := DataRecord.CardinalValue;                            (* 04-Jan-89 LAA *)
    UNTIL (i = 0);

    ok := SortTree( ColumnTree, CompareTwoColumns );   (* RSC 9-Mar-89 *)

    IF (ok) THEN
        INC(UseCount);
    ELSE
        DisposeColumnTree(ColumnTree);
    END;

    RETURN ok;

END CreateEdgeColumnsTree;



    (*  DisposeEdgeColumnsTree --

            Get rid of the column name tree made by CreateEdgeColumnsTree.

        Preconditions:
            The column name tree must have been created by a call to
            CreateEdgeColumnsTree.

        Postconditions:
            If the use count is 1, the column name tree and all it's node 
            will be discarded.  Otherwise, the use count will be decremented.
    *)

PROCEDURE DisposeEdgeColumnsTree();

BEGIN                       (* DisposeEdgeColumnsTree *)

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

END DisposeEdgeColumnsTree;









    (*  SearchForEdgeColumn --

            Find the ColumnId in the resource column tree for the provided 
            column name (an LString).

        Preconditions:
            The resource column tree must have been created by a call to
            CreateEdgeColumnsTree, and not discarded by DisposeEdgeColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForEdgeColumn(VAR ColumnName : ARRAY OF CHAR;
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


BEGIN                       (* SearchForEdgeColumn *)

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

END SearchForEdgeColumn;


BEGIN                       (* EdgeColumns *)

    ColumnTree := NIL;
    UseCount := 0;

END EdgeColumns.
