IMPLEMENTATION MODULE ColorName;
    (*  MODIFICATION HISTORY --
        13-Jun-89 LAA   Removed the use of the Storage Module.
    *)

(*V1=DEBUGGING*)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode, ascreenx, ascreeny;

FROM LStrings               IMPORT
    (* PROC *)                  TrimRear, Copy, Compare, LengthOf, StoC;

FROM Menus                  IMPORT
    (* VAR *)                   WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, 
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    ModuleNumber            = 25400;

(* COLOROFFSET is an offset from the ModuleNumber into the Phrases file
   that points to the beginning of the list of the names of colors. *)

    COLOROFFSET             = 20;

(* These constants are used to retrieve messages via GetMessage *)

    CANTADDTOCOLORTREE        = 0;
    COLORMENUTITLE            = 1;


VAR
    ColorTree              : ATree;


PROCEDURE GetColorName (     Node              : ATreeNode;
                         VAR ColorNameReturned : ARRAY OF CHAR);

VAR
    ColorInfo : AColorRecordPtr;

BEGIN
    ColorInfo := Node^.Methods^.GetDataObject(Node);
    Copy (ColorInfo^.Name, ColorNameReturned);
END GetColorName;


PROCEDURE AddToColorTree() : BOOLEAN;

VAR
    ColorInfo               : AColorRecordPtr;
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..255] OF CHAR;
    Node                    : ATreeNode;
    i                       : CARDINAL;
    j                       : CARDINAL;

BEGIN
    i := COLOROFFSET;
    GetMessage(ModuleNumber + i, s);

    WHILE ((LengthOf(s) > 0) AND (i <= 99)) DO
        IF (NOT CreateTreeNode(Node)) THEN
            RETURN(FALSE);
        END;

        NEW(ColorInfo);
        WordNumber(s, 1, s1);
        WordNumber(s, 2, ColorInfo^.Name);

        j := 1;
        ColorInfo^.ID := StoC(s1, j);
        ColorTree^.Methods^.AddLast(ColorTree, Node);
        Node^.Methods^.SetDataObject(Node, ColorInfo);
        INC(i);
        GetMessage(ModuleNumber + i, s);
    END;

    RETURN(TRUE);
END AddToColorTree;


PROCEDURE DisposeColorTreeData();

VAR
    TreeNode            : ATreeNode;
    NextNode            : ATreeNode;
    ColorRecord         : AColorRecordPtr;

BEGIN
    TreeNode := ColorTree^.Methods^.GetFirst(ColorTree);
    WHILE (TreeNode <> NIL) DO
        NextNode := TreeNode^.Methods^.GetNext(TreeNode);
        ColorRecord := TreeNode^.Methods^.GetDataObject (TreeNode);
        DISPOSE (ColorRecord);
        TreeNode^.Methods^.Discard(TreeNode);
        TreeNode := NextNode;
    END;
    ColorTree^.Methods^.Discard(ColorTree);
END DisposeColorTreeData;


(*  DisposeColorNameTree --
        Dispose of the color name tree made by CreateColorNameTree.

    Preconditions:
        The color name tree must have been created by a call to
        CreateColorNameTree.

    Postconditions:
        The color name tree and all the nodes are discarded.
*)

PROCEDURE DisposeColorNameTree();

BEGIN
    IF (ColorTree <> NIL) THEN
        DisposeColorTreeData();
    END;
END DisposeColorNameTree;

(*  CreateColorNameTree --  
        Create the tree of Color names for use by 
        SelectColor, FindColorByName, and FindColorByNumber.

    Preconditions:
        None.

    Postconditions:
        If heap space is available, the color name tree is created,
        and TRUE returned.  Otherwise, FALSE is returned, and the
        tree is not created.
*)

PROCEDURE CreateColorNameTree() : BOOLEAN;

BEGIN
    IF (ColorTree <> NIL) THEN
        FatalError();
    END;

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(ColorTree))) THEN
        RETURN(FALSE);
    END;

    IF (NOT AddToColorTree()) THEN
        DisposeColorTreeData();
        RETURN(FALSE);
    END;

    RETURN(TRUE);
END CreateColorNameTree;


PROCEDURE FindColorNodeByName (ColorNameString : ARRAY OF CHAR) : ATreeNode;

VAR
    Node                    : ATreeNode;
    ColorToTest             : AColorRecordPtr;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN
    TrimRear(ColorNameString);
    Node := ColorTree^.Methods^.GetFirst(ColorTree);

    LOOP
        IF (Node = NIL) THEN
            EXIT;
        END;
        ColorToTest := Node^.Methods^.GetDataObject(Node);
        Copy(ColorToTest^.Name, s);
        TrimRear(s);
        IF (Compare(ColorNameString, s) = 0) THEN
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

    RETURN Node;
END FindColorNodeByName;

(*  SelectColor --
        Display the scrolling list of color names at the indicated
        coordinates, and allow the user to select one from it.

    Preconditions:
        The color name tree must have been created by a call to
        CreateColorNameTree, and not discarded by DisposeColorNameTree.

    Postconditions:
        The name of the color selected is passed back via ColorNameText,
        and the ID of the via ColorIDNumber.
*)

PROCEDURE SelectColor (    Ulx           : ascreenx;
                           Uly           : ascreeny;
                           Lrx           : ascreenx;
                           Lry           : ascreeny;
                       VAR ColorNameText : ARRAY OF CHAR;
                       VAR ColorNameID   : CARDINAL) : ACode;

VAR
    Node                    : ATreeNode;
    Title                   : ARRAY [0..255] OF CHAR;
    SelectedColor           : AColorRecordPtr;
    KeyStruck               : ACode;
    Success                 : BOOLEAN;

BEGIN
    Node := FindColorNodeByName(ColorNameText);

    (* If the ColorName passed is not found in the tree, then
       we use the first color in the list by default. *)

    IF (Node = NIL) THEN
        Node := ColorTree^.Methods^.GetFirst(ColorTree);
    END;
    
    KeyStruck := CancelKey;
    GetMessage(ModuleNumber + COLORMENUTITLE, Title);

    Success := DoGoTo(ColorTree, Ulx, Uly, Lrx, Lry, Title, TRUE, 
                      NullGoToCheckProc, GetColorName, Node);

    IF (Success) THEN
        SelectedColor := Node^.Methods^.GetDataObject(Node);
        Copy(SelectedColor^.Name, ColorNameText);
        ColorNameID := SelectedColor^.ID;
        KeyStruck := ExitKey;
    END;

    RETURN KeyStruck;
END SelectColor;

(*  FindColorByName --
        Find the node in the color name tree for the provided color
        name (an LString).

    Preconditions:
        The color name tree must have been created by a call to
        CreateColorNameTree, and not discarded by DisposeColorNameTree.

    Postconditions:
        If the color name can be found in the tree, the ColorRecord
        is returned.  If the color name is not found, NIL is returned.
*)

PROCEDURE FindColorByName (ColorNameString : ARRAY OF CHAR) : AColorRecordPtr;

VAR
    Node                    : ATreeNode;
    ColorToReturn           : AColorRecordPtr;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN
    TrimRear(ColorNameString);
    Node := ColorTree^.Methods^.GetFirst(ColorTree);

    LOOP
        IF (Node = NIL) THEN
            ColorToReturn := NIL;
            EXIT;
        END;
        ColorToReturn := Node^.Methods^.GetDataObject(Node);
        Copy(ColorToReturn^.Name, s);
        TrimRear(s);
        IF (Compare(ColorNameString, s) = 0) THEN
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

    RETURN ColorToReturn;
END FindColorByName;


(*  FindColorByNumber --
        Find the node in the color name tree for the provided color
        number (a cardinal).

    Preconditions:
        The color name tree must have been created by a call to
        CreateColorNameTree, and not discarded by DisposeColorNameTree.

    Postconditions:
        If the color number is found in the tree, a pointer to a
        ColorRecord is returned.  If the color name isn't found,
        NIL is returned.
*)

PROCEDURE FindColorByNumber (VAR ColorNumber : CARDINAL) : AColorRecordPtr;

VAR
    Node                    : ATreeNode;
    ColorToReturn           : AColorRecordPtr;

BEGIN
    Node := ColorTree^.Methods^.GetFirst(ColorTree);

    LOOP
        IF (Node = NIL) THEN
            ColorToReturn := NIL;
            EXIT;
        END;
        ColorToReturn := Node^.Methods^.GetDataObject(Node);
        IF (ColorToReturn^.ID = ColorNumber) THEN
            EXIT;
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;

    RETURN ColorToReturn;
END FindColorByNumber;


BEGIN
    ColorTree := NIL;
END ColorName.
