(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE TaskColumns;

(*  =========================================================================
    Last Edit : June 10, 1991 1:11PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Handles the scrolling list of task column names.        

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
    04-Aug-89 EGK   Added new procedures for manipulating a "percent
                    columns" tree, which is just like a task columns
                    tree but filtered to include only those columns
                    that express a percentage quantity.
    22-Aug-90 PFG   Added support for user-defined column headings.
    12-Sep-90 PFG   Change the TaskGoToCheckProc to call GetColumnInfo
                    rather than GetColumnItem when it can.  Massage the
                    strings returned by GetColumnInfo.  (Larry made me
                    do it.)
    28-Sep-90 PFG   Moved core of the GoToCheckProc to ColFind module
                    and genericized it for use with other kinds of 
                    columns.  Added xxx so that all captions procs conform
                    to the same calling conventions.
    2-Oct-90  PFG   Moved the GoToCheckProc stuff again...out of ColFind
                    and into the TLColNam overlay.  Okay, so call me
                    wishy-washy.
    21-Nov-90 PFG   I was passing a maximum width of the string to
                    GetTaskInfo, but not using it.  Whoops!
    25-Apr-91 RSC   Optimized the search for column names.  See also
                    TLCaptions fix for this date.  Also, on 12-Sep-90,
                    Larry had Patty change some calls to be more "normal".
                    However, this had the side effect of invoking TLCaptions
                    many, many times.  I reverted back to the less-normal
                    use of GetColumnItem.
    10-Jun-91 PFG   Added GetTaskColumnName to get the latest task
                    column name and format it for use in a data column
                    field of a form.
    23-Jul-91 LAA   Adjusted the context passed to DoColumnFormOverlay, and
                    called NotifyOfChange for the outline view if the context
                    returns an Changed flag of TRUE.  These changes help
                    fix bug# 4768.
    =========================================================================
*)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

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
    (* CONST *)                 DescriptionIndex, FullTitle,
    (* TYPE *)                  AColumnTreeRecordPtr, AColumnTreeRecord,
    (* PROC *)                  DisposeColumnTree, PickColumn;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM GoTo                   IMPORT
    (* PROC *)                  NullGoToCheckProc;

FROM Keys                   IMPORT
    (* CONST *)                 EditKey;

FROM Kbio                   IMPORT
    (* CONST  *)                maxcol,
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM LStrings               IMPORT
    (* PROC *)                  Upshift, TrimFront, TrimRear, Copy,
                                LJust, SetLengthOf, StringsEqual, LengthOf;

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


CONST
    ModuleNumber    = 28100;  (* AND 28200 *)
    PromptPhrasesNumber    = 28100;  (*  Where column descriptions (prompts) start  *)
    ColumnPhrasesNumber    = 19200;  (*  Where task columns start in Phrases  *)
    MAXCARDINAL            = 65535;


VAR
    TaskColumnTree              : ATree;
    TaskUseCount                : CARDINAL;

    PctColumnTree               : ATree;
    PctUseCount                 : CARDINAL;




    (*  TaskColumnsTreeExists --

        Query whether or not the task columns tree already exists.

        Preconditons:
            None.

        Postconditions:
            TRUE will be returned iff the task columns tree exists.
    *)

PROCEDURE TaskColumnsTreeExists(): BOOLEAN;

BEGIN                       (* TaskColumnsTreeExists *)

    RETURN (TaskUseCount > 0);

END TaskColumnsTreeExists;




    (*  PctColumnsTreeExists --

        Query whether or not the percent columns tree already exists.

        Preconditons:
            None.

        Postconditions:
            TRUE will be returned iff the percent columns tree exists.
    *)

PROCEDURE PctColumnsTreeExists(): BOOLEAN;

BEGIN                       (* PctColumnsTreeExists *)

    RETURN (PctUseCount > 0);

END PctColumnsTreeExists;




 (* This procedure supplies GoTo with the text names it needs. *)

PROCEDURE GetColumnName (       Node    : ATreeNode;
                          VAR   s       : ARRAY OF CHAR);

VAR
    i                       : CARDINAL;
    DisplayRecord           : AColumnTreeRecordPtr;

BEGIN                       (* GetColumnName *)

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    WITH DisplayRecord^ DO
        IF (LengthOf(Name) = 0) THEN
            GetColumnItem( ColumnPhrasesNumber, (* 25-Apr-91 RSC  *)
                           TaskColumnInfo, 
                           ID, 
                           FullTitle,
                           FALSE, i, Name);
        END;
        Copy(Name, s);
    END;

END GetColumnName;


 (* This procedure supplies GoTo with the text prompt it needs. *)

PROCEDURE GetColumnPrompt (       Node    : ATreeNode;
                            VAR   s       : ARRAY OF CHAR);
VAR
    DisplayRecord           : AColumnTreeRecordPtr;
    i                       : CARDINAL;

BEGIN

    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    GetColumnItem(PromptPhrasesNumber, 
                  TaskColumnInfo, 
                  DisplayRecord^.ID, 
                  DescriptionIndex, 
                  FALSE, i, s);                       (* 29-Aug-90 PFG  *)

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
    T                   : ATaskPtr;
    FirstNode,
    SecondNode          : ATreeNode;
    FirstOrder,
    SecondOrder         : CARDINAL;
    ColumnRecord        : AColumnTreeRecordPtr;
    DataRecord          : AColumnDataRecord;
BEGIN
    FirstNode   := ATreeNode( First  );
    SecondNode  := ATreeNode( Second );
    T           := NIL;

    ColumnRecord := FirstNode^.Methods^.GetDataObject( FirstNode );
    GetColumnInfo(NIL, T, ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    FirstOrder   := DataRecord.CardinalValue;

    ColumnRecord := SecondNode^.Methods^.GetDataObject( SecondNode );
    GetColumnInfo(NIL, T, ColumnRecord^.ID, ColumnSortSequence, 0, DataRecord);
    SecondOrder   := DataRecord.CardinalValue;

    RETURN (FirstOrder > SecondOrder);

END CompareTwoColumns;







PROCEDURE AddToTree(    Tree            : ATree;
                        ColumnID        : CARDINAL)
                                                   : BOOLEAN;

VAR
    ColumnRecord        : AColumnTreeRecordPtr;
    Node                : ATreeNode;

BEGIN                   (* AddToTree *)

    IF (NOT CreateTreeNode(Node)) THEN
        RETURN FALSE;
    END;
    Tree^.Methods^.AddLast(Tree, Node);
    NEW(ColumnRecord);
    Node^.Methods^.SetDataObject(Node, ColumnRecord);
    ColumnRecord^.ID := ColumnID;

    SetLengthOf(ColumnRecord^.Name, 0);  (* Too expensive to get name now. *)

    RETURN TRUE;

END AddToTree;







    (*  CreateTaskColumnsTree --  

            Create the tree of tasl column names for use by 
            PickTaskColumns and SearchForTaskColumns.

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


PROCEDURE CreateTaskColumnsTree() : BOOLEAN;

VAR
    i                       : CARDINAL;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* CreateTaskColumnTree *)

    IF (TaskUseCount > 0) THEN 
        INC(TaskUseCount);
        RETURN TRUE; 
    END;

    IF (TaskColumnTree <> NIL) THEN
        FatalError();
    END;

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(TaskColumnTree))) THEN
        RETURN FALSE;
    END;

    i := 1;
    REPEAT
        IF (NOT AddToTree(TaskColumnTree, i)) THEN
            GetMessage(PromptPhrasesNumber + 199, s); (* "Not enough memory to make the column name list." *)
            Error(s);
            DisposeColumnTree(TaskColumnTree);
            RETURN FALSE;
        END;
            (*  Sets CardValue to the next valid column ID, or returns 0  *)
        T := NIL;                                                 (* 08-Feb-88 LAA *)
        GetColumnInfo(NIL, T, i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i := DataRecord.CardinalValue;                            (* 04-Jan-89 LAA *)
    UNTIL (i = 0);

    ok := SortTree( TaskColumnTree, CompareTwoColumns );   (* RSC 9-Mar-89 *)

    IF (ok) THEN
        INC(TaskUseCount);
    ELSE
        DisposeColumnTree(TaskColumnTree);
    END;

    RETURN ok;

END CreateTaskColumnsTree;



    (*  DisposeTaskColumnsTree --

            Get rid of the column name tree made by CreateTaskColumnsTree.

        Preconditions:
            The column name tree must have been created by a call to
            CreateTaskColumnsTree.

        Postconditions:
            If the use count is 1, the column name tree and all it's node 
            will be discarded.  Otherwise, the use count will be decremented.
    *)

PROCEDURE DisposeTaskColumnsTree();

BEGIN                       (* DisposeTaskColumnsTree *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    IF ((TaskUseCount = 1) AND (TaskColumnTree <> NIL)) THEN
        DisposeColumnTree(TaskColumnTree);
    END;
    IF (TaskUseCount > 0) THEN
        DEC(TaskUseCount);
    END;

END DisposeTaskColumnsTree;






    (*  PickTaskColumn --

            Display the scrolling list of column names at the indicated
            coordinates, and allow the user to select one from it.

        Preconditions:
            The column name tree must have been created by a call to
            CreateTaskColumnsTree, and not discarded by DisposeTaskColumnsTree.

        Postconditions:
            If the user selects a new column name, the ColumnId and 
            ColumnName will be changed to that for the new column, and TRUE 
            will be returned.  If no column name is selected, FALSE will be 
            returned.
    *)


PROCEDURE PickTaskColumn(    Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                         VAR ColumnId       : CARDINAL;
                         VAR ColumnName     : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    Title                   : ARRAY [0..31] OF CHAR;

BEGIN                       (* PickTaskColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    GetMessage(PromptPhrasesNumber + 198, Title);

    RETURN PickColumn(TaskColumnTree, Ulx, Uly, Lrx, Lry, Title, 
                      GetColumnName, GetColumnPrompt, TaskGoToCheckProc, 
                      ColumnId, ColumnName);

END PickTaskColumn;



(*----------------------------------------------------------------------------
    GetTaskInfo --                                 1-Oct-90 PFG 

    Get column info for a task column.  Conforms to the AGetColumnInfoProc
    definition.

    Preconditions:
        ColumnID is a valid task column ID.

        InfoChoice is the type of column information you want.

        Length is the maximum length of the information you're retrieving.

    Postconditions:
        The column information is passed back in InfoValue.
        
        This procedure always returns TRUE.  It must return a boolean to
        conform to other procedures of its kind.

----------------------------------------------------------------------------*)

PROCEDURE GetTaskInfo(     ColumnID      : CARDINAL;
                           InfoChoice    : AColumnInfoChoice;   
                           Length        : CARDINAL;
                       VAR InfoValue     : AColumnDataRecord) : BOOLEAN;

VAR
    NodePtr : ATaskPtr;

BEGIN
    NodePtr := NIL;
    GetColumnInfo(NIL, NodePtr, ColumnID, InfoChoice, Length, InfoValue);
    RETURN TRUE;
END GetTaskInfo;


(*----------------------------------------------------------------------------
    TaskGoToCheckProc --                             1-Oct-90 PFG 

    Go To Proc to be used if user wants to edit column name.

    Preconditions:
        A tree of column info must already exist.

    Postconditions:
        The column info tree is updated if any changes are made, as well
        as the Text that stores column info.  Code is set to zero on 
        exit if it was EditKey on the way in.
----------------------------------------------------------------------------*)

PROCEDURE TaskGoToCheckProc( 
                                View : AnOutlineView;        
                                Tree : ATree;        
                            VAR Code : ACode       
                            );

VAR
    ColumnContext : AColumnContext;

BEGIN

    IF ( Code = EditKey ) THEN

        WITH ColumnContext DO                                  (* 23-Jul-91 *)
            PhraseModNumber := ColumnPhrasesNumber;
            PromptModNumber := PromptPhrasesNumber;
            CursorNode      := View^.Methods^.GetCursorNode( View );
            ColumnType      := TaskColumnInfo;
            Changed         := FALSE;
        END;
        
        DoColumnFormOverlay(ColumnContext);

        IF (ColumnContext.Changed) THEN                        (* 23-Jul-91 *)
                (* Update the goto list with the changed name *)
            View^.Methods^.NotifyOfChange(View);
        END;

        Code := 0;

    END;

END TaskGoToCheckProc;




    (* 25-Apr-91 RSC New behaviour: TLCAPTIONS will now do a search
                     for us.  This avoids the hideous thrashing when
                     looking for a name.

        Passed: NameToFind - task column name to find.
        Returned: ColumnID - found column id
                  RETURN   - TRUE iff found, FALSE if not.
    *)
PROCEDURE AskCaptionsForASearch( VAR NameToFind : ARRAY OF CHAR;
                                 VAR ColumnID   : CARDINAL
                               ) : BOOLEAN;
VAR
    InfoValue     : AColumnDataRecord;
BEGIN
    WITH InfoValue DO
        Copy( NameToFind, StringValue );
        TrimRear( StringValue );
        IF (LengthOf(StringValue) = 0) OR
           (NOT GetTaskInfo( MAXCARDINAL, ColumnName, 0, InfoValue )) THEN
            ColumnID := MAXCARDINAL;
        ELSE
            ColumnID := CardinalValue;
        END;
    END;

    RETURN (ColumnID < MAXCARDINAL);

END AskCaptionsForASearch;








    (*  SearchForTaskColumn --

            Find the ColumnId in the task column tree for the provided column
            name (an LString).

        Preconditions:
            The task column tree must have been created by a call to
            CreateTaskColumnsTree, and not discarded by DisposeTaskColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForAColumn(VAR ColumnName : ARRAY OF CHAR;
                           VAR ColumnId   : CARDINAL;
                               Tree       : ATree
                          ) : BOOLEAN;

VAR
    Node                    : ATreeNode;
    ColumnRecord            : AColumnTreeRecordPtr;
BEGIN

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(ColumnTree);
    END;
    DEBUGGING>*)

    (* 25-Apr-91 RSC See if ANY column has this name.
    *)
    IF (NOT AskCaptionsForASearch( ColumnName, ColumnId )) THEN
        RETURN FALSE;
    END;

    (* 25-Apr-91 RSC Now, it DOES exist, is it in THIS list?
    *)
    Node := Tree^.Methods^.GetFirst(Tree);

    LOOP
        IF (Node = NIL) THEN
            EXIT;
        END;
        ColumnRecord := Node^.Methods^.GetDataObject(Node);
        IF (ColumnId  = ColumnRecord^.ID) THEN
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

    RETURN (Node <> NIL);

END SearchForAColumn;




    (*  SearchForTaskColumn --

            Find the ColumnId in the task column tree for the provided column
            name (an LString).

        Preconditions:
            The task column tree must have been created by a call to
            CreateTaskColumnsTree, and not discarded by DisposeTaskColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForTaskColumn(VAR ColumnName : ARRAY OF CHAR;
                              VAR ColumnId   : CARDINAL     )
                                                             : BOOLEAN;
BEGIN

    RETURN SearchForAColumn( ColumnName, ColumnId, TaskColumnTree );

END SearchForTaskColumn;






    (*  GetTaskColumnName --

        Get the latest column name for the column ID passed.  Format it as
        needed for the data column fields on forms and return that string.

        Preconditons:
            A valid column ID must be passed in ColumnID.

        Postconditions:
            The string is returned in String.
    *)

PROCEDURE GetTaskColumnName(    ColumnID    : CARDINAL;
                                VAR String      : ARRAY OF CHAR);

VAR
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;

BEGIN

    T := NIL;
    GetColumnInfo(NIL, T, ColumnID, ColumnName, maxcol, DataRecord);
    LJust (DataRecord.StringValue);
    TrimRear( DataRecord.StringValue );
    Copy(DataRecord.StringValue, String);

END GetTaskColumnName;


    (*  CreatePctColumnsTree --  

            Create the tree of task column names for use by 
            PickPctColumns and SearchForPctColumns.

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


PROCEDURE CreatePctColumnsTree() : BOOLEAN;

VAR
    i                       : CARDINAL;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
    s                       : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;

BEGIN                       (* CreatePctColumnTree *)

    IF (PctUseCount > 0) THEN 
        INC(PctUseCount);
        RETURN TRUE; 
    END;

    IF (PctColumnTree <> NIL) THEN
        FatalError();
    END;

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(PctColumnTree))) THEN
        RETURN FALSE;
    END;

    i := 1;
    REPEAT

        (*  Don't use this column unless it's a valid percent column.
            We check this by "borrowing" the ColumnTotalByRsrc attribute
            for task columns.
        *)

        T := NIL;
        GetColumnInfo (NIL, T, i, ColumnTotalByRsrc, 1, DataRecord);
        IF (DataRecord.BooleanValue) THEN
            IF (NOT AddToTree(PctColumnTree, i)) THEN
                GetMessage(PromptPhrasesNumber + 199, s); (* "Not enough memory to make the columna name list." *)
                Error(s);
                DisposeColumnTree(PctColumnTree);
                RETURN FALSE;
            END;
        END;

            (*  Sets CardValue to the next valid column ID, or returns 0  *)
        T := NIL;                                                 (* 08-Feb-88 LAA *)
        GetColumnInfo(NIL, T, i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i := DataRecord.CardinalValue;                            (* 04-Jan-89 LAA *)
    UNTIL (i = 0);

    ok := SortTree( PctColumnTree, CompareTwoColumns );   (* RSC 9-Mar-89 *)

    IF (ok) THEN
        INC(PctUseCount);
    ELSE
        DisposeColumnTree(PctColumnTree);
    END;

    RETURN ok;

END CreatePctColumnsTree;



    (*  DisposePctColumnsTree --

            Get rid of the column name tree made by CreatePctColumnsTree.

        Preconditions:
            The column name tree must have been created by a call to
            CreatePctColumnsTree.

        Postconditions:
            If the use count is 1, the column name tree and all it's node 
            will be discarded.  Otherwise, the use count will be decremented.
    *)

PROCEDURE DisposePctColumnsTree();

BEGIN                       (* DisposePctColumnsTree *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(PctColumnTree);
    END;
    DEBUGGING>*)

    IF ((PctUseCount = 1) AND (PctColumnTree <> NIL)) THEN
        DisposeColumnTree(PctColumnTree);
    END;
    IF (PctUseCount > 0) THEN
        DEC(PctUseCount);
    END;

END DisposePctColumnsTree;






    (*  PickPctColumn --

            Display the scrolling list of column names at the indicated
            coordinates, and allow the user to select one from it.

        Preconditions:
            The column name tree must have been created by a call to
            CreatePctColumnsTree, and not discarded by DisposePctColumnsTree.

        Postconditions:
            If the user selects a new column name, the ColumnId and 
            ColumnName will be changed to that for the new column, and TRUE 
            will be returned.  If no column name is selected, FALSE will be 
            returned.
    *)


PROCEDURE PickPctColumn(     Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                         VAR ColumnId       : CARDINAL;
                         VAR ColumnName     : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    Title                   : ARRAY [0..31] OF CHAR;

BEGIN                       (* PickPctColumn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateTree(PctColumnTree);
    END;
    DEBUGGING>*)

    GetMessage(PromptPhrasesNumber + 198, Title);

    RETURN PickColumn(PctColumnTree, Ulx, Uly, Lrx, Lry, Title, GetColumnName,
                      GetColumnPrompt, NullGoToCheckProc, ColumnId, ColumnName);

END PickPctColumn;





    (*  SearchForPctColumn --

            Find the ColumnId in the percent column tree for the provided column
            name (an LString).

        Preconditions:
            The percent column tree must have been created by a call to
            CreatePctColumnsTree, and not discarded by DisposePctColumnsTree.

        Postconditions:
            If the column name can be found in the tree, it's name and id
            will be returned.  If the column name can't be found, NIL will 
            be returned.  The search ignores case.
    *)

PROCEDURE SearchForPctColumn (VAR ColumnName : ARRAY OF CHAR;
                              VAR ColumnId   : CARDINAL     )
                                                             : BOOLEAN;

BEGIN
    RETURN SearchForAColumn( ColumnName, ColumnId, PctColumnTree );
END SearchForPctColumn;




BEGIN                       (* TaskColumns *)

    TaskColumnTree := NIL;
    TaskUseCount := 0;

    PctColumnTree := NIL;
    PctUseCount := 0;

END TaskColumns.
