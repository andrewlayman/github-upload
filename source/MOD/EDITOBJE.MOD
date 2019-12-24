(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE EditObjects;

    (*  MODIFICATION HISTORY
        29-Jan-88 LAA   Added posting and detecting of errors.
        17-Feb-88 LAA   Called Available instead of HeapAvailable in one
                        place, and import ALLOCATE and DEALLOCATE from Space
                        instead of Storage.
        16-Jun-88 LAA   Fixed bug in AllocationSize for outline importer.
    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM ErrorHandler           IMPORT
    (* PROC *)                  PostError, ErrorPosted;

FROM ErrorCategories        IMPORT
    (* CONST *)                 AllocationError;

FROM LinkedListObjects      IMPORT
    (* TYPE *)                  ALinkedListMethods, ALinkedListNodeMethods,
                                ALinkedList, ALinkedListNode, 
    (* PROC *)                  InitAsLinkedList, ValidateLinkedList,
                                CloneLinkedListMethods, InitAsLinkedListNode,
                                ValidateLinkedListNode, 
                                CloneLinkedListNodeMethods,
                                UnInitAsLinkedList, UnInitAsLinkedListNode;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, LengthOf, TrimRear, ConcatLS,
                                Insert, Overlay, Remove, ConcatS;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject, AnObjectMethods;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  BYTE,
    (* PROC *)                  ADR, TSIZE;



CONST
    ModuleNumber            = 15000;








TYPE
    XEditWorkspace          = POINTER TO XEditWorkspaceRecord;

    XEditNode               = POINTER TO XEditNodeRecord;

    XEditWorkspaceRecord    = RECORD
                                Methods     : AnEditWorkspaceMethods;
                                Header      : XEditNode;
                                Changed     : BOOLEAN;
                              END;

    XEditNodeRecord         = RECORD
                                Methods     : AnEditNodeMethods;
                                HeaderFlag  : BOOLEAN;
                                Filler      : BYTE;
                                Next        : XEditNode;
                                Prev        : XEditNode;
                                LineOfText  : AnEditStringPointer;
                                LineAlloc   : CARDINAL;
                                Workspace   : XEditWorkspace;
                                SequenceNo  : CARDINAL;
                              END;









VAR
    AllocationTable         : ARRAY [1..13] OF CARDINAL;          (* 16-Jun-88 LAA *)


    EditWorkspaceMethodsRecord : AnEditWorkspaceMethodsRecord;
    EditNodeMethodsRecord      : AnEditNodeMethodsRecord;



 (* ***************************************************************

PROCEDURE Renumber(    EditNode             : XEditNode);

VAR
    i                       : CARDINAL;

BEGIN                       (* Renumber *)

    i := EditNode^.SequenceNo;
    REPEAT
        EditNode^.SequenceNo := i;
        INC(i);
        EditNode := EditNode^.Methods^.GetNext(AnEditNode(EditNode));
    UNTIL (EditNode = NIL);

END Renumber;

 ********************************************************** *)

(*$T+*)

PROCEDURE AllocationSize(    Length         : CARDINAL): CARDINAL;

VAR
    i                   : CARDINAL;

BEGIN                   (* AllocationSize *)

    IF (Length = 0) THEN
        RETURN 0;
    END;

    INC(Length);
    i := 1;
    WHILE (Length > AllocationTable[i]) DO
        INC(i);
    END;
    
    RETURN AllocationTable[i];

END AllocationSize;

(*$T=*)



PROCEDURE Reallocate(VAR String             : AnEditStringPointer;
                     VAR Size               : CARDINAL;
                         NewSize            : CARDINAL           )
                                                                  : BOOLEAN;

VAR
    NewAllocation           : CARDINAL;
    NewString               : AnEditStringPointer;

BEGIN                       (* Reallocate *)

    NewAllocation := AllocationSize(NewSize);
    IF (NewAllocation > Size) THEN
        IF (NOT Available(NewAllocation)) THEN                    (* 17-Feb-88 LAA *)
            PostError(ModuleNumber, AllocationError);
            RETURN FALSE;
        END;
        ALLOCATE(NewString, NewAllocation);
        IF (String <> NIL) THEN
            SubStr(String^, NewString^, 1, HIGH(NewString^));
        ELSE
            Fill(NewString^, " ", 0);
        END;
        IF (String <> NIL) THEN
            DEALLOCATE(String, Size);
        END;
        String := NewString;
        Size := NewAllocation;
    END;

    RETURN TRUE;

END Reallocate;






PROCEDURE WorkspaceClone(    Workspace      : XEditWorkspace;
                         VAR NewWorkspace   : XEditWorkspace)
                                                             : BOOLEAN;

BEGIN                       (* WorkspaceClone *)

    FatalError();

END WorkspaceClone;





PROCEDURE WorkspaceStoreOn(    Workspace    : XEditWorkspace;
                               FileObject   : AnObject      );

BEGIN                       (* WorkspaceStoreOn *)

    FatalError();

END WorkspaceStoreOn;






PROCEDURE WorkspaceDiscard(VAR Workspace    : XEditWorkspace);

BEGIN                       (* WorkspaceDiscard *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateEditWorkspace(AnEditWorkspace(Workspace));
    END;
    (*DEBUGGING>*)

    UnInitAsEditWorkspace(AnEditWorkspace(Workspace));
    DISPOSE(Workspace);

END WorkspaceDiscard;








PROCEDURE WorkspaceGetChanged(    Workspace : XEditWorkspace)
                                                             : BOOLEAN;

BEGIN                       (* WorkspaceGetChanged *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateEditWorkspace(AnEditWorkspace(Workspace));
    END;
    (*DEBUGGING>*)

    RETURN Workspace^.Changed;

END WorkspaceGetChanged;






PROCEDURE WorkspaceSetChanged(    Workspace : XEditWorkspace;
                                  Changed   : BOOLEAN        );

BEGIN                       (* WorkspaceSetChanged *)

    (*<DEBUGGING*)
    IF (AnxietyLevel > Calm) THEN
        ValidateEditWorkspace(AnEditWorkspace(Workspace));
    END;
    (*DEBUGGING>*)

    Workspace^.Changed := Changed;

END WorkspaceSetChanged;





PROCEDURE EditNodeClone(    EditNode        : XEditNode;
                        VAR NewEditNode     : XEditNode)
                                                        : BOOLEAN;

BEGIN                       (* EditNodeClone *)

    FatalError();

END EditNodeClone;





PROCEDURE EditNodeStoreOn(    EditNode      : XEditNode;
                              FileObject    : AnObject );

BEGIN                       (* EditNodeStoreOn *)

    FatalError();

END EditNodeStoreOn;





PROCEDURE EditNodeDiscard(VAR EditNode      : XEditNode);

BEGIN                       (* EditNodeDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    UnInitAsEditNode(AnEditNode(EditNode));
    DISPOSE(EditNode);

END EditNodeDiscard;




PROCEDURE EditNodeGetWorkspace(    EditNode : XEditNode)
                                                         : XEditWorkspace;

BEGIN                       (* EditNodeGetWorkspace *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    RETURN EditNode^.Workspace;

END EditNodeGetWorkspace;






PROCEDURE EditNodeOrder(    EditNode1       : XEditNode;
                            Column1         : CARDINAL;
                            EditNode2       : XEditNode;
                            Column2         : CARDINAL  )
                                                         : ARelativeOrder;

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;

BEGIN                       (* EditNodeOrder *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode1));
        ValidateEditNode(AnEditNode(EditNode2));
    END;
    DEBUGGING>*)

    i := EditNode1^.SequenceNo;
    j := EditNode2^.SequenceNo;

    IF (i < j) THEN
        RETURN ComesBefore;
    ELSIF (i > j) THEN
        RETURN ComesAfter;
    ELSIF (Column1 < Column2) THEN
        RETURN ComesBefore;
    ELSIF (Column1 > Column2) THEN
        RETURN ComesAfter;
    ELSE
        RETURN SameAs;
    END;

END EditNodeOrder;







PROCEDURE EditNodeEndOfLine(    EditNode    : XEditNode)
                                                         : CARDINAL;

VAR
    End                     : CARDINAL;

BEGIN                       (* EditNodeEndOfLine *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        End := 1;
        IF (LineOfText <> NIL) THEN
            End := LengthOf(LineOfText^);
            WHILE ((End > 0) AND (LineOfText^[End] = " ")) DO
                DEC(End);
            END;
            INC(End);
        END;
    END;

    RETURN End;

END EditNodeEndOfLine;








PROCEDURE EditNodeGetLine(    EditNode      : XEditNode;
                              StartAt       : CARDINAL;
                              MaxLength     : CARDINAL;
                          VAR LString       : ARRAY OF CHAR);

BEGIN                       (* EditNodeGetLine *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    IF (MaxLength > HIGH(LString)) THEN
        MaxLength := HIGH(LString);
    END;

    IF (EditNode^.LineOfText <> NIL) THEN
        SubStr(EditNode^.LineOfText^, LString, StartAt, MaxLength);
    ELSE
        Fill(LString, " ", 0);
    END;

END EditNodeGetLine;







PROCEDURE EditNodePutLine(    EditNode      : XEditNode;
                              StartAt       : CARDINAL;
                              InsertMode    : BOOLEAN;
                          VAR LString       : ARRAY OF CHAR);

VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    Size                    : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* EditNodePutLine *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        i := 0;
        IF (LineOfText <> NIL) THEN
            i := LengthOf(LineOfText^);
        END;

        j := LengthOf(LString);
        IF ((InsertMode) AND (StartAt <= i)) THEN
            IF (i + j) <= 240 THEN
                IF (Reallocate(LineOfText, LineAlloc, i + j)) THEN  (* 29-Jan-88 LAA *)
                    Insert(LineOfText^, LString, StartAt);
                END;

                RETURN;
            ELSE
                FatalError();
            END;
        END;

        Size := StartAt + j - 1;
        IF (Size <= 240) THEN
            IF (i < Size) THEN
                IF (NOT Reallocate(LineOfText, LineAlloc, Size)) THEN (* 29-Jan-88 LAA *)
                    RETURN;
                END;
                Fill(s, " ", Size - i);
                ConcatLS(LineOfText^, s);
            END;
            IF (j > 0) THEN
                Overlay(LineOfText^, LString, StartAt, j);
            END;
        ELSE
            FatalError();
        END;
        Workspace^.Methods^.SetChanged(AnEditWorkspace(Workspace), TRUE);
    END;
    
END EditNodePutLine;







PROCEDURE EditNodeGetCharacter(    EditNode : XEditNode;
                                   Column   : CARDINAL  )
                                                         : CHAR;

BEGIN                       (* EditNodeGetCharacter *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        IF ((LineOfText <> NIL) AND (LengthOf(LineOfText^) >= Column)) THEN
            RETURN LineOfText^[Column];
        END;
    END;

    RETURN " ";

END EditNodeGetCharacter;







PROCEDURE EditNodePutCharacter(    EditNode   : XEditNode;
                                   Column     : CARDINAL;
                                   InsertMode : BOOLEAN;
                                   Character  : CHAR     );

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* EditNodePutCharacter *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        i := 0;
        IF (LineOfText <> NIL) THEN
            i := LengthOf(LineOfText^);
        END;

        IF (Column > i) THEN
            IF (NOT Reallocate(LineOfText, LineAlloc, Column)) THEN (* 29-Jan-88 LAA *)
                RETURN;
            END;
            Fill(s, " ", Column - i);
            ConcatLS(LineOfText^, s);
        ELSE
            IF (InsertMode) THEN
                IF (NOT Reallocate(LineOfText, LineAlloc, i + 1)) THEN  (* 29-Jan-88 LAA *)
                    RETURN;
                END;
                Fill(s, " ", 1);
                Insert(LineOfText^, s, Column);
            END;
        END;
        LineOfText^[Column] := Character;
        Workspace^.Methods^.SetChanged(AnEditWorkspace(Workspace), TRUE);
    END;

END EditNodePutCharacter;







PROCEDURE EditNodeDelCharacter(    EditNode : XEditNode;
                                   Column   : CARDINAL  );

VAR
    i                       : CARDINAL;

BEGIN                       (* EditNodeDelCharacter *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        IF (EditNode^.LineOfText <> NIL) THEN
            i := LengthOf(EditNode^.LineOfText^);
            IF (Column <= i) THEN
                Remove(LineOfText^, Column, 1);
            END;
        END;
        Workspace^.Methods^.SetChanged(AnEditWorkspace(Workspace), TRUE);
    END;

END EditNodeDelCharacter;







PROCEDURE EditNodeDeleteBlock(    EditNode  : XEditNode;
                                  StartAt   : CARDINAL;
                                  Length    : CARDINAL  );

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* EditNodeDeleteBlock *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateEditNode(AnEditNode(EditNode));
    END;
    DEBUGGING>*)

    WITH EditNode^ DO
        IF (LineOfText <> NIL) THEN
            i := LengthOf(LineOfText^);
            IF (StartAt <= i) THEN
                IF (StartAt + Length - 1 > i) THEN
                    Length := i - StartAt + 1;
                END;
                Remove(LineOfText^, StartAt, Length);
            END;
        END;
        Workspace^.Methods^.SetChanged(AnEditWorkspace(Workspace), TRUE);
    END;

END EditNodeDeleteBlock;








(*----------------------------------------------------------------------------
    InitAsEditWorkspace --

    Initialize the indicated storage as an object of type AnEditWorkspace.

    Preconditions:
        None.

    Postconditions:
        The indicated storage is initialized as a valid object of type
        AnEditWorkspace.
----------------------------------------------------------------------------*)

PROCEDURE InitAsEditWorkspace(    EditWorkspace : AnEditWorkspace);

VAR
    PrivateWorkspace        : XEditWorkspace;

BEGIN                       (* InitAsEditWorkspace *)

    InitAsLinkedList(ALinkedList(EditWorkspace));
    PrivateWorkspace := XEditWorkspace(EditWorkspace);
    WITH PrivateWorkspace^ DO
        Methods := AnEditWorkspaceMethods(ADR(EditWorkspaceMethodsRecord));
        Changed := FALSE;
    END;

END InitAsEditWorkspace;






(*----------------------------------------------------------------------------
    InitAsEditNode --

    Initialize the indicated storage as an object of type AnEditNode.

    Preconditions:
        None.

    Postconditions:
        The indicated storage is initialized as a valid object of type
        AnEditNode.
----------------------------------------------------------------------------*)

PROCEDURE InitAsEditNode(    EditNode       : AnEditNode;
                             EditWorkspace  : AnEditWorkspace);

VAR
    PrivateEditNode         : XEditNode;

BEGIN                       (* InitAsEditNode *)

    InitAsLinkedListNode(ALinkedListNode(EditNode));
    PrivateEditNode := XEditNode(EditNode);
    WITH PrivateEditNode^ DO
        Methods := AnEditNodeMethods(ADR(EditNodeMethodsRecord));
        Workspace := XEditWorkspace(EditWorkspace);
        LineOfText := NIL;
        LineAlloc := 0;
        SequenceNo := 0;
    END;

END InitAsEditNode;







(*----------------------------------------------------------------------------
    CreateEditWorkspace --

    Allocate storage for, and initialize the storage as an object of type 
    AnEditWorkspace.

    Preconditions:
        None.

    Postconditions:
        Iff sufficient heap space is available, a new object of type
        AnEditWorkspace will be allocated, and initialized and TRUE will be
        returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateEditWorkspace(VAR EditWorkspace : AnEditWorkspace)
                                                                  : BOOLEAN;

BEGIN                       (* CreateEditWorkspace *)

    IF (HeapAvailable()) THEN
        ALLOCATE(EditWorkspace, TSIZE(XEditWorkspaceRecord));
        InitAsEditWorkspace(EditWorkspace);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateEditWorkspace;







(*----------------------------------------------------------------------------
    CreateEditNode --

    Allocate and initialize space on the heap as an object of type AnEditNode.

    Preconditions:
        None.

    Postconditions:
        Iff sufficient heap space is available, a new object of type
        AnEditNode will be allocated, and initialized and TRUE will be
        returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateEditNode(VAR EditNode       : AnEditNode;
                             EditWorkspace  : AnEditWorkspace)
                                                              : BOOLEAN;

BEGIN                       (* CreateEditNode *)

    IF (HeapAvailable()) THEN
        ALLOCATE(EditNode, TSIZE(XEditNodeRecord));
        InitAsEditNode(EditNode, EditWorkspace);

        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateEditNode;









(*----------------------------------------------------------------------------
    UnInitAsEditWorkspace --

    UnInitialize the indicated storage as an object of type AnEditWorkspace.

    Preconditions:
        The object must be a valid edit workspace.

    Postconditions:
        Whatever was done by InitAsEditWorkspace will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsEditWorkspace(    EditWorkspace : AnEditWorkspace);

BEGIN                       (* UnInitAsEditWorkspace *)

    UnInitAsLinkedList(ALinkedList(EditWorkspace));

END UnInitAsEditWorkspace;







(*----------------------------------------------------------------------------
    UnInitAsEditNode --

    UnInitialize the indicated storage as an object of type AnEditNode.

    Preconditions:
        The object must be a valid edit node.

    Postconditions:
        Whatever was done by InitAsEditNode will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsEditNode(    EditNode     : AnEditNode);

VAR
    PrivateEditNode         : XEditNode;

BEGIN                       (* UnInitAsEditNode *)

    PrivateEditNode := XEditNode(EditNode);
    WITH PrivateEditNode^ DO
        Workspace^.Methods^.SetChanged(AnEditWorkspace(Workspace), TRUE);
        IF (LineOfText <>  NIL) THEN
            DEALLOCATE(LineOfText, LineAlloc);
        END;
    END;
    UnInitAsLinkedListNode(ALinkedListNode(EditNode));

END UnInitAsEditNode;







(*----------------------------------------------------------------------------
    ValidateEditWorkspace --

    Validate the indicated storage location as an object of type 
    AnEditWorkspace.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not an edit workspace, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateEditWorkspace(    Workspace : AnEditWorkspace);

BEGIN                       (* ValidateEditWorkspace *)

    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedList(ALinkedList(Workspace));
    END;

    IF (Workspace^.Methods^.WorkspaceMethodsTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateEditWorkspace;






(*----------------------------------------------------------------------------
    ValidateEditNode --

    Validate the indicated storage location as an object of type 
    AnEditNode.

    Preconditions:
        None.

    Postconditions:
        If the indicated object is not an edit node, or a subclass, 
        FatalError will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateEditNode(    EditNode     : AnEditNode);

BEGIN                       (* ValidateEditNode *)

    IF (AnxietyLevel > Calm) THEN
        ValidateLinkedListNode(ALinkedListNode(EditNode));
    END;

    IF (EditNode^.Methods^.EditNodeMethodsTag <> ModuleNumber + 1) THEN
        FatalError();
    END;

END ValidateEditNode;





 (* *********************************************************

(*----------------------------------------------------------------------------
    CloneEditWorkspaceMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The edit workspace methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneEditWorkspaceMethods(    MethodObject : AnEditWorkspaceMethods);

BEGIN                       (* CloneEditWorkspaceMethods *)

    MethodObject^ := EditWorkspaceMethodsRecord;
    MethodObject^.SuperclassMethods := 
                      AnEditWorkspaceMethods(ADR(EditWorkspaceMethodsRecord));

END CloneEditWorkspaceMethods;








(*----------------------------------------------------------------------------
    CloneEditNodeMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The edit node methods will be copied into the indicated method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneEditNodeMethods(    MethodObject : AnEditNodeMethods);

BEGIN                       (* CloneEditNodeMethods *)

    MethodObject^ := EditNodeMethodsRecord;
    MethodObject^.SuperclassMethods
                             := AnEditNodeMethods(ADR(EditNodeMethodsRecord));

END CloneEditNodeMethods;

 *************************************** *)


BEGIN                       (* EditObjects *)

    AllocationTable[1] := 20;
    AllocationTable[2] := 40;
    AllocationTable[3] := 60;
    AllocationTable[4] := 80;
    AllocationTable[5] := 100;
    AllocationTable[6] := 120;
    AllocationTable[7] := 140;
    AllocationTable[8] := 160;
    AllocationTable[9] := 180;
    AllocationTable[10] := 200;
    AllocationTable[11] := 220;
    AllocationTable[12] := 240;
    AllocationTable[13] := 256;                                   (* 16-Jun-88 LAA *)

    CloneLinkedListMethods(ALinkedListMethods(ADR(EditWorkspaceMethodsRecord)));
    WITH EditWorkspaceMethodsRecord DO
        MethodSize := TSIZE(AnEditWorkspaceMethodsRecord);
        Clone := AWorkspaceCloneProc(WorkspaceClone);
        StoreOn := AWorkspaceStoreOnProc(WorkspaceStoreOn);
        Discard := AWorkspaceDiscardProc(WorkspaceDiscard);
        GetChanged := AWorkspaceGetChangedProc(WorkspaceGetChanged);
        SetChanged := AWorkspaceSetChangedProc(WorkspaceSetChanged);
        WorkspaceMethodsTag := ModuleNumber;
    END;

    CloneLinkedListNodeMethods(ALinkedListNodeMethods(ADR(EditNodeMethodsRecord)));
    WITH EditNodeMethodsRecord DO
        MethodSize := TSIZE(AnEditNodeMethodsRecord);
        Clone := AnEditNodeCloneProc(EditNodeClone);
        StoreOn := AnEditNodeStoreOnProc(EditNodeStoreOn);
        Discard := AnEditNodeDiscardProc(EditNodeDiscard);
        GetList := AnEditNodeGetWorkspaceProc(EditNodeGetWorkspace);
        RelativeOrder := AnEditNodeRelativeOrderProc(EditNodeOrder);
        EndOfLine := AnEditNodeEndOfLineProc(EditNodeEndOfLine);
        GetLine := AnEditNodeGetLineProc(EditNodeGetLine);
        PutLine := AnEditNodePutLineProc(EditNodePutLine);
        GetCharacter := AnEditNodeGetCharProc(EditNodeGetCharacter);
        PutCharacter := AnEditNodePutCharProc(EditNodePutCharacter);
        DeleteCharacter := AnEditNodeDeleteCharProc(EditNodeDelCharacter);
        DeleteBlock := AnEditNodeDeleteBlockProc(EditNodeDeleteBlock);
        EditNodeMethodsTag := ModuleNumber + 1;
    END;

END EditObjects.
