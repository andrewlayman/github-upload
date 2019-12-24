(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE XTabColumns;

(*  =========================================================================
    Last Edit : July 1, 1991 10:10AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Handles scrolling list of cross tab columns.

    MODIFICATION HISTORY:

        21-Mar-89 RSC   Created for "Better Reports" project.
        5-Sep-90  PFG   Add GoToCheckProc parameter to PickColumn.
        24-Sep-90 PFG   Implemented user-defined column headings for
                        cross tab columns.
        2-Oct-90  PFG   Moved the GoToCheckProc stuff again...out of ColFind
                        and into the TLColNam overlay. 
         6-Nov-90 AJL  Import column numbers from XTabColNumbers.
        10-Jun-91 PFG   Added GetXTabColumnName to get the latest cross tab
                        column name and format it for use in a data column
                        field of a form.
         1-Jul-91 PFG   GetMessage was referring to wrong phrases number for
                        Title of column pick list form and the error message
                        for out of memory errors.  No phrases existed
                        for these.  I added the phrases and put in the correct
                        numbers here.
        24-Jul-91 LAA   Removed use of GetInfo and OutlineView fields of the
                        ColumnContext record, which was changed to fix bug
                        #4768.
        17-Sep-91 LAA   In CrossTabGoToCheckProc, incorporated a change which
                        I'd made to TaskColumns on 23-Jul-91, which will force
                        a repaint of the column list after a change made via
                        F2.
    =========================================================================
*)


FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM ColFind                IMPORT
    (* PROC  *)                 GetColumnItem;

FROM ColForm                IMPORT
    (* TYPE  *)                 AGetColumnInfoProc, AColumnContext,
    (* PROC  *)                 DoColumnFormOverlay;

FROM ColumnSupport          IMPORT
    (* CONST *)                 DescriptionIndex,
    (* TYPE *)                  AColumnTreeRecordPtr, AColumnTreeRecord,
    (* PROC *)                  DisposeColumnTree, PickColumn;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM Kbio                   IMPORT
    (* CONST  *)                maxcol,
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM Keys                   IMPORT
    (* CONST *)                 EditKey;

FROM LStrings               IMPORT
    (* PROC *)                  Upshift, TrimFront, TrimRear, Copy, Fill,
                                LJust, SetLengthOf, StringsEqual, LengthOf;

FROM XTabColNumbers         IMPORT
                                XTabModuleNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

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

FROM XTabFormat             IMPORT
    (* PROC *)                   GetXTabInfo;


CONST
    ModuleNumber            = 28900;

VAR
    ColumnTree              : ATree;
    UseCount                : CARDINAL;




    (*  XTabColumnsTreeExists --

        Query whether or not the cross tab columns tree already exists.

        Preconditons:
            None.

        Postconditions:
            TRUE will be returned iff the cross tab columns tree exists.
    *)

PROCEDURE XTabColumnsTreeExists(): BOOLEAN;

BEGIN                       (* XTabColumnsTreeExists *)

    RETURN (UseCount > 0);

END XTabColumnsTreeExists;





 (* This procedure supplies GoTo with the text names it needs. *)

PROCEDURE GetColumnName (       Node    : ATreeNode;
                          VAR   s       : ARRAY OF CHAR);

VAR
    DisplayRecord           : AColumnTreeRecordPtr;

BEGIN                       (* ColumnViewTitle *)

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    WITH DisplayRecord^ DO                                        (* 04-Jan-89 LAA *)
        IF (LengthOf(Name) = 0) THEN
            GetXTabColumnName( ID, Name );  (* 10-Jun-91 PFG *)
        END;
        Copy(Name, s);
    END;

END GetColumnName;




    (*  GetXTabColumnName --

        Get the latest column name for the column ID passed.  Format it as
        needed for the data column fields on forms and return that string.

        Preconditons:
            A valid column ID must be passed in ColumnID.

        Postconditions:
            The string is returned in String.
    *)

PROCEDURE GetXTabColumnName(    ColumnID    : CARDINAL;
                                VAR String      : ARRAY OF CHAR);

VAR
    DataRecord              : AColumnDataRecord;
    ok                      : BOOLEAN;

BEGIN

    ok := GetXTabInfo( ColumnID, ColumnName, maxcol, DataRecord);
    LJust (DataRecord.StringValue);
    TrimRear( DataRecord.StringValue );
    Copy(DataRecord.StringValue, String);

END GetXTabColumnName;


 (* This procedure supplies GoTo with the text prompt it needs. *)

PROCEDURE GetColumnPrompt (       Node    : ATreeNode;
                            VAR   s       : ARRAY OF CHAR);
VAR
    i                       : CARDINAL;
    DisplayRecord           : AColumnTreeRecordPtr;

BEGIN

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    GetColumnItem(ModuleNumber, 
                  XTabColumnInfo, 
                  DisplayRecord^.ID, 
                  DescriptionIndex, 
                  FALSE, i, s);                       (* 26-Sep-90 PFG *)

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
    ok := GetXTabInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    FirstOrder   := DataRecord.CardinalValue;

    ColumnRecord := SecondNode^.Methods^.GetDataObject( SecondNode );
    ok := GetXTabInfo( ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
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







    (*  CreateXTabColumnsTree --  

            Create the tree of tasl column names for use by 
            PickXTabColumns and SearchForXTabColumns.

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


PROCEDURE CreateXTabColumnsTree( DontUse : AColumnNameSet ) : BOOLEAN;

VAR
    i                       : CARDINAL;
    DataRecord              : AColumnDataRecord;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* CreateXTabColumnTree *)

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
        IF (NOT (i IN DontUse)) AND (NOT AddToTree(i)) THEN
            GetMessage(ModuleNumber + 99, s); (* "Not enough memory to make the columna name list." *)
            Error(s);
            DisposeColumnTree(ColumnTree);
            RETURN FALSE;
        END;
            (*  Sets CardValue to the next valid column ID, or returns 0  *)
        ok := GetXTabInfo( i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i  := DataRecord.CardinalValue;                            (* 04-Jan-89 LAA *)
    UNTIL (i = 0);

    ok := SortTree( ColumnTree, CompareTwoColumns );   (* RSC 9-Mar-89 *)

    IF (ok) THEN
        INC(UseCount);
    ELSE
        DisposeColumnTree(ColumnTree);
    END;

    RETURN ok;

END CreateXTabColumnsTree;



    (*  DisposeXTabColumnsTree --

            Get rid of the column name tree made by CreateXTabColumnsTree.

        Preconditions:
            The column name tree must have been created by a call to
            CreateXTabColumnsTree.

        Postconditions:
            If the use count is 1, the column name tree and all it's node 
            will be discarded.  Otherwise, the use count will be decremented.
    *)

PROCEDURE DisposeXTabColumnsTree();

BEGIN                       (* DisposeXTabColumnsTree *)

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

END DisposeXTabColumnsTree;






    (*  PickXTabColumn --

            Display the scrolling list of column names at the indicated
            coordinates, and allow the user to select one from it.

        Preconditions:
            The column name tree must have been created by a call to
            CreateXTabColumnsTree, and not discarded by DisposeXTabColumnsTree.

        Postconditions:
            If the user selects a new column name, the ColumnId and 
            ColumnName will be changed to that for the new column, and TRUE 
            will be returned.  If no column name is selected, FALSE will be 
            returned.
    *)


PROCEDURE PickXTabColumn(    Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                         VAR ColumnId       : CARDINAL;
                         VAR ColumnName     : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    Title                   : ARRAY [0..31] OF CHAR;

BEGIN                       (* PickXTabColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    GetMessage(ModuleNumber + 98, Title);

    RETURN PickColumn(ColumnTree, Ulx, Uly, Lrx, Lry, Title, GetColumnName,
                      GetColumnPrompt, CrossTabGoToCheckProc, ColumnId, ColumnName);

END PickXTabColumn;





(*----------------------------------------------------------------------------
    CrossTabGoToCheckProc --

    Go To Proc to be used if user wants to edit column name.

    Preconditions:
        A tree of column info must already exist.

    Postconditions:
        The column info tree is updated if any changes are made, as well
        as the Text that stores column info.  Code is set to zero on 
        exit if it was EditKey on the way in.

----------------------------------------------------------------------------*)

PROCEDURE CrossTabGoToCheckProc( 
                                   View : AnOutlineView;        
                                   Tree : ATree;        
                               VAR Code : ACode       
                               );                          (* 26-Sep-90 PFG *)

VAR
    ColumnContext : AColumnContext;

BEGIN

    IF ( Code = EditKey ) THEN

        WITH ColumnContext DO
            PhraseModNumber := XTabModuleNumber;
            PromptModNumber := ModuleNumber;
            CursorNode := View^.Methods^.GetCursorNode( View );(* 24-Jul-91 *)
            ColumnType := XTabColumnInfo;
            Changed := FALSE;
        END;
        
        DoColumnFormOverlay(ColumnContext);

        IF (ColumnContext.Changed) THEN                        (* 17-Sep-91 *)
                (* Update the goto list with the changed name *)
            View^.Methods^.NotifyOfChange(View);
        END;

        Code := 0;

    END;

END CrossTabGoToCheckProc;





    (*  SearchForXTabColumn --

            Find the ColumnId in the cross tab column tree for the provided 
            column name (an LString).

        Preconditions:
            The cross tab column tree must have been created by a call to
            CreateXTabColumnsTree, and not discarded by DisposeXTabColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForXTabColumn(VAR ColumnName : ARRAY OF CHAR;
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


BEGIN                       (* SearchForXTabColumn *)

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

END SearchForXTabColumn;


BEGIN                       (* XTabColumns *)

    ColumnTree := NIL;
    UseCount := 0;

END XTabColumns.
