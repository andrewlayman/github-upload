IMPLEMENTATION MODULE InitMenu;

    (*   MODIFICATION HISTORY:

            This module is from RunMenu.  It provides all the setup code to
            build the list of menu items.

         2-Feb-89 RSC   Cloned from RunMenu.

        10-Nov-89 RSC   Fix bug in "FindException" that tended to blast
                        any prior exceptions.
    *)

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle, AnExtStoragePreference,
    (* PROC *)          CreateExtObjectWithSize, LockObject,
                        ReleaseObject, ReleaseUnchangedObject,
                        DiscardExtObject;
 
FROM LStrings       IMPORT
    (* PROCS *)         StringsEqual, SetLengthOf, LengthOf, ConcatLS,
                        ConcatS, Copy;

FROM RunMenu        IMPORT
    (* Type *)          AnItem, AClassIndex, AnExceptionEntry,
                        AnExceptionReason, AMenuItemList,
    (* VAR  *)          ClassList,
    (* PROC *)          LocateItem;

FROM Space          IMPORT
    (* PROC *)          HeapAvailable, ALLOCATE;

FROM SYSTEM         IMPORT
    (* THING *)         TSIZE;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, CreateTreeNode;








TYPE
    AClassIndexPtr      = POINTER TO AClassIndex;







PROCEDURE FindClass( VAR Class      : ARRAY OF CHAR;
                     VAR ClassIndex : AClassIndexPtr ) : BOOLEAN;
VAR
    Node            : ATreeNode;
    Found           : BOOLEAN;
BEGIN
    IF (ClassList = ATree(NIL)) THEN
        FatalError(); (* Too Soon. *)
    END;

    Node := ClassList^.Methods^.GetFirst( ClassList );

    Found       := FALSE;

    WHILE (Node <> NIL) AND (NOT Found) DO
        ClassIndex := Node^.Methods^.GetDataObject( Node );
        Found      := (StringsEqual( Class, ClassIndex^.Class ));
        Node       := Node^.Methods^.GetNext(Node);
    END;

    RETURN Found;

END FindClass;






(* Find any current exception records for this index of this class.
   Return the exception record found.  If TRUE.
*)
PROCEDURE FindException( VAR ClassIndex      : AClassIndexPtr;
                             TargetIndex     : CARDINAL;
                         VAR Exception       : AnExceptionEntry;
                         VAR ExceptionHandle : AnExtHandle ) : BOOLEAN;
VAR
    ExceptionPtr    : POINTER TO AnExceptionEntry;
    LExceptions     : AnExtHandle;
    Done            : BOOLEAN;
BEGIN
    Done := FALSE;

    WITH ClassIndex^ DO
        LExceptions := Exceptions;  (* 10-Nov-89 RSC *)
        WHILE (LExceptions <> AnExtHandle(NIL)) AND (NOT Done) DO
            IF (LockObject(LExceptions, ExceptionPtr) <> TSIZE(AnExceptionEntry)) THEN
                FatalError();
            END;
            WITH ExceptionPtr^ DO
                IF (Index = TargetIndex) THEN
                    Exception   := ExceptionPtr^;
                    Done        := TRUE;
                END;
                ExceptionHandle := LExceptions;
                LExceptions     := NextException;
            END;
            ReleaseUnchangedObject( ExceptionHandle );
        END;
    END;

    RETURN Done;

END FindException;







(* Add an entry to the head of the list of exceptions.
   There is a potential of having this supercede other items, but that
   would be a client bug (for example, "Add item 2.  Change item 2."
   The change would take, but would not apply to that item when looked
   up later.)
*)
PROCEDURE AddException( VAR ClassIndex      : AClassIndexPtr;
                        VAR Exception       : AnExceptionEntry );
VAR
    ExceptionEntry : POINTER TO AnExceptionEntry;
    OldExceptions  : AnExtHandle;
BEGIN
    WITH ClassIndex^ DO
        OldExceptions           := Exceptions;
        Exception.NextException := OldExceptions;
        IF (CreateExtObjectWithSize( Exceptions, ExtMedium, TSIZE(AnExceptionEntry) )) THEN
            IF (LockObject(Exceptions,ExceptionEntry) <> TSIZE(AnExceptionEntry)) THEN
                FatalError();
            END;
            ExceptionEntry^ := Exception;
            ReleaseObject( Exceptions );
        END;
    END;
END AddException;







PROCEDURE FixMenuItems( ClassIndexPtr   : AClassIndexPtr );
VAR
    At,
    i           : CARDINAL;
    MenuList    : POINTER TO AMenuItemList;
    Item        : AnItem;
BEGIN
    WITH ClassIndexPtr^ DO
        IF (MenuItems = AnExtHandle(NIL)) THEN
            IF (NOT CreateExtObjectWithSize( MenuItems, ExtMedium, TSIZE(AMenuItemList) )) THEN
                MenuItems := AnExtHandle(NIL);
            END;
        END;
        IF (MenuItems <> AnExtHandle(NIL)) THEN
            IF (LockObject(MenuItems, MenuList) <> TSIZE(AMenuItemList)) THEN
                FatalError();
            END;
            WITH MenuList^ DO
                SetLengthOf( MenuString, 0 );
                MenuItems := 0;
                i         := 1;
                WHILE (LocateItem( Class, i, Item, At )) DO
                    MenuItems := i;
                    Codes[i]  := Item.Key;
                    IF (LengthOf(MenuString) <> 0) THEN
                        ConcatS( MenuString, "," );
                    END;
                    ConcatLS( MenuString, Item.ItemName );
                    INC(i);
                END;
            END;
            ReleaseObject( MenuItems );
        END;
    END;
END FixMenuItems;








    (*-----------------------------------------------------------------

        SetMenuItem

        Preconditions:
            Index > 0.
            Item record is filled in.

        Postconditions:
            If there is an item in the Class with the indicated
            index number, its information will be changed to the
            new (passed) information.


    -----------------------------------------------------------------*)


PROCEDURE SetMenuItem ( VAR Item    : AnItem;
                            Index   : CARDINAL );
VAR
    ClassIndexPtr   : AClassIndexPtr;
    Exception       : AnExceptionEntry;
    Handle          : AnExtHandle;
    ExceptionPtr    : POINTER TO AnExceptionEntry;
BEGIN

    IF (FindClass( Item.Class, ClassIndexPtr )) THEN
        IF (FindException( ClassIndexPtr, Index, Exception, Handle )) THEN
            IF (LockObject(Handle, ExceptionPtr) <> TSIZE(AnExceptionEntry)) THEN
                FatalError();
            END;
            ExceptionPtr^.Item := Item;
            ReleaseObject( Handle );
        ELSE
            Exception.Index  := Index;
            Exception.Item   := Item;
            Exception.Reason := Changed;
            AddException( ClassIndexPtr, Exception );
        END;
        FixMenuItems( ClassIndexPtr );
    END;

END SetMenuItem;






    (*-----------------------------------------------------------------

        AddMenuItem

        Preconditions:
            Item record is filled in.

        Postconditions:
            If there is an item in the Class with the indicated
            index number a new item will be added to the class in
            ordinal position prior to the pre-existing one.  Otherwise
            a new item will be added as the last in the class.

            Note that passing an index of zero adds the item at the
            end of the class.


    -----------------------------------------------------------------*)


PROCEDURE AddMenuItem ( VAR Item    : AnItem;
                            Index   : CARDINAL );
VAR
    ClassIndex      : AClassIndex;
    ClassIndexPtr   : AClassIndexPtr;
    Exception       : AnExceptionEntry;
    Handle          : AnExtHandle;
    ExceptionPtr    : POINTER TO AnExceptionEntry;
    At              : CARDINAL;
    Node            : ATreeNode;
    JunkItem        : AnItem;
BEGIN

    IF (NOT HeapAvailable()) THEN
        RETURN;
    END;

    IF (NOT FindClass( Item.Class, ClassIndexPtr )) THEN
        WITH ClassIndex DO
            Copy( Item.Class, Class );
            Exceptions      := AnExtHandle(NIL);
            MenuItems       := AnExtHandle(NIL);
            StartingPhrase  := 0;
            IF (CreateTreeNode( Node )) THEN
                NEW(ClassIndexPtr);
                ClassIndexPtr^ := ClassIndex;
                ClassList^.Methods^.AddLast( ClassList, Node );
                Node^.Methods^.SetDataObject( Node, ClassIndexPtr );
            END;
        END;
    END;

    IF (Index > 0) AND
       (FindException( ClassIndexPtr, Index, Exception, Handle )) THEN
        IF (LockObject(Handle, ExceptionPtr) <> TSIZE(AnExceptionEntry)) THEN
            FatalError();
        END;
        ExceptionPtr^.Item := Item;
        ReleaseObject( Handle );
    ELSE
        IF (Index = 0) THEN
            Index := 1;
            WHILE (LocateItem( Item.Class, Index, JunkItem, At )) DO
                INC(Index);
            END;
        END;
        Exception.Index  := Index;
        Exception.Item   := Item;
        Exception.Reason := Inserted;
        AddException( ClassIndexPtr, Exception );
    END;

    FixMenuItems( ClassIndexPtr );

END AddMenuItem;









    (*-----------------------------------------------------------------

        DeleteMenuItem

        Preconditions:
            Index > 0
            Class is an LString with length > 0.

        Postconditions:
            If there is an item in the Class with the indicated
            index number, it will be deleted.

    -----------------------------------------------------------------*)


PROCEDURE DeleteMenuItem (  Class : ARRAY OF CHAR;
                            Index : CARDINAL       );
VAR
    ClassIndexPtr   : AClassIndexPtr;
    Exception       : AnExceptionEntry;
    Handle          : AnExtHandle;
BEGIN

    IF (FindClass( Class, ClassIndexPtr )) THEN
        IF (FindException( ClassIndexPtr, Index, Exception, Handle )) THEN
            DiscardExtObject( Handle );
        ELSE
            Exception.Index  := Index;
            Exception.Reason := Deleted;
            AddException( ClassIndexPtr, Exception );
        END;
        FixMenuItems( ClassIndexPtr );
    END;

END DeleteMenuItem;





END InitMenu.
