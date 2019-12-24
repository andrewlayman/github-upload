(*----------------------------------------------------------------------------
    MODIFICATION HISTORY 

    12/08/86 LAA    Expanded the held item name to 20 characters, for filters.
    12/10/86 LAA    In DeleteHeldItem, changed the location of DeList because
                    deallocating the stuff at Where changes the checksum.
    12/11/86 LAA    In HoldThis, only deallocate the previous storage of a
                    duplicate held item if it's different from the current
                    address.
    11/01/88 EGK    Fixed HoldThis and DeleteHeldItem to differentiate between
                    heap objects and flexstor objects.
    2-Jan-89 RSC    Added references to StringsEqual() rather than Compare().
   10-Jan-89 RSC    Changed Storage to Space    .
   22-Jan-91 RSC    Added a HolderListHead to FormStatic so that Holder can
                    leave the root.
----------------------------------------------------------------------------*)
IMPLEMENTATION MODULE Holder;

    (* Holder -- A module for recording the addresses and sizes of
                 other things, associating symbolic names and
                 categories with those items. *)

FROM SYSTEM      IMPORT ADDRESS, ADR, SIZE, TSIZE;

FROM Space       IMPORT ALLOCATE, DEALLOCATE, HeapAvailable;

FROM LStrings    IMPORT StringsEqual, SubStr, SetString;

FROM Dialog      IMPORT FatalError;

FROM CRC16       IMPORT CheckSum;

FROM FormStatic  IMPORT HolderListHead; (* 22-Jan-91 RSC *)

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROC *)                  DiscardExtObject, ObjectsAreSame;


CONST
    HeldItemTag   = 33333;
TYPE
    AHeldItemPointer = POINTER TO AHeldItemRecord;
    AHeldItemRecord  = RECORD
                           Tag      : CARDINAL;
                           Class    : CARDINAL;
                           Where    : ADDRESS;
                           Size     : CARDINAL;
                           CheckThem: CARDINAL;
                           Name     : ARRAY [0..15] OF CHAR;
                           NextLink,
                           PriorLink: AHeldItemPointer;
                           Category : AHoldTypeSet;
                           CheckUs  : CARDINAL;  (* Must be last field. *)
                       END;


VAR
    HeldItemList            : AHeldItemPointer;




PROCEDURE SetChecks( HeldItem : AHeldItemPointer );
BEGIN
    WITH HeldItem^ DO
            (* Tag it as valid. *)
        Tag := HeldItemTag;
            (* And maybe even checksum its target. *)
        IF (CheckSumStorage IN Category) THEN
            CheckThem := CheckSum(Where,Size);
        END;
            (* Now checksum our private record for a stronger test than tagging. *)
        CheckUs := CheckSum(ADR(HeldItem^),SIZE(HeldItem^)-TSIZE(CARDINAL));
    END;
END SetChecks;





    (* ListInit -- Initialize a list.  The pointer passed to us will
                   be converted into the head node of an empty list
                   by allocating space for it and setting its forward
                   and reverse links to itself. *)

PROCEDURE ListInit (VAR List:AHeldItemPointer);
BEGIN
    NEW(List);
    IF (List <> NIL) THEN
        WITH List^ DO
            Category := AHoldTypeSet{ErrorIfDuplicate};    (* No CheckSumStorage! *)
            NextLink := List;
            PriorLink := List;
            SetString(Name,"HOLDERLIST");  (* Dummy name for now. *)
        END;
        SetChecks(List);
    ELSE
        FatalError;
    END;
END ListInit;




    (* AddBefore -- Add a new resource to the list before the BeforeNode. *)

PROCEDURE AddBefore (BeforeNode, NewNode : AHeldItemPointer);
BEGIN
        (* Debugging *)
    CheckHeldItemValid(BeforeNode);
    CheckHeldItemValid(NewNode);

    NewNode^.PriorLink := BeforeNode^.PriorLink;
    NewNode^.NextLink := BeforeNode;
    NewNode^.PriorLink^.NextLink := NewNode;
    BeforeNode^.PriorLink := NewNode;

    SetChecks(NewNode);
    SetChecks(NewNode^.PriorLink);
    SetChecks(BeforeNode);
END AddBefore;



    (* DeList -- Remove the HeldItem from whichever circular list it is on. *)

PROCEDURE DeList ( HeldItem: AHeldItemPointer);
VAR
    P, N : AHeldItemPointer;
BEGIN
        (* Debugging *)
    CheckHeldItemValid(HeldItem);
    IF (HeldItem = HeldItemList) THEN FatalError; END;

    HeldItem^.PriorLink^.NextLink := HeldItem^.NextLink;
    HeldItem^.NextLink^.PriorLink := HeldItem^.PriorLink;

    SetChecks(HeldItem^.PriorLink);
    SetChecks(HeldItem^.NextLink);

        (* Debugging *)
    HeldItem^.NextLink := HeldItem;
    HeldItem^.PriorLink := HeldItem;
END DeList;






PROCEDURE FirstHeldItem():AHeldItemPointer;
BEGIN
    RETURN NextHeldItem(HeldItemList);
END FirstHeldItem;




PROCEDURE NextHeldItem(X:AHeldItemPointer):AHeldItemPointer;
BEGIN
    (* CheckHeldItemValid(X);  *)
    X := X^.NextLink;
    IF (X = HeldItemList) THEN
        RETURN NIL;
    ELSE
        RETURN X;
    END;
END NextHeldItem;





(*
PROCEDURE PriorHeldItem(X:AHeldItemPointer):AHeldItemPointer;
BEGIN
    CheckHeldItemValid(X);
    X := X^.PriorLink;
    IF (X = HeldItemList) THEN
        RETURN NIL;
    ELSE
        RETURN X;
    END;
END PriorHeldItem;
*)
















PROCEDURE CheckHeldItemValid(X:AHeldItemPointer);
BEGIN
    IF (X = NIL) OR
       (X^.Tag <> HeldItemTag) THEN
        FatalError;
    END;

    IF (X^.CheckUs <> CheckSum(ADR(X^),SIZE(X^)-TSIZE(CARDINAL) ) ) THEN
        FatalError;
    END;

    IF (CheckSumStorage IN X^.Category) THEN
        IF (CheckSum(X^.Where,X^.Size) <> X^.CheckThem) THEN
            FatalError;
        END;
    END;
END CheckHeldItemValid;





PROCEDURE LocateByName( VAR Name : ARRAY OF CHAR;
                            Class : CARDINAL;
                        VAR HeldItem : AHeldItemPointer ) : BOOLEAN;
BEGIN
    HeldItem := FirstHeldItem();
    WHILE (HeldItem <> NIL) DO
            (* We do a simple test here because it would be costly to
               do a complicated one in the middle of the loop. *)
        IF (HeldItem^.Tag <> HeldItemTag) THEN FatalError; END;
        IF (Class = HeldItem^.Class ) AND
           (StringsEqual(Name,HeldItem^.Name)) THEN     (* RSC 1/2/88 *)
            CheckHeldItemValid(HeldItem);   (* Costly check. *)
            RETURN TRUE;
        END;
        HeldItem := NextHeldItem(HeldItem);
    END;
    RETURN FALSE;
END LocateByName;








    (* HoldThis -- Record the Where address and size, tagging them
                   with both a Name and a Category.  This does not
                   actually store the data from "Where," but merely
                   records the address and size of it. *)

PROCEDURE HoldThis(     Name       : ARRAY OF CHAR;
                        Class      : CARDINAL;
                        Category   : AHoldTypeSet;
                        Where      : ADDRESS;
                        Size       : CARDINAL  );
VAR
    HeldItem                : AHeldItemPointer;
    Handle                  : AnExtHandle;

BEGIN
    IF (LocateByName(Name,Class,HeldItem)) AND
       (NOT (AllowDuplicates IN HeldItem^.Category)) THEN
        IF (ErrorIfDuplicate IN HeldItem^.Category) THEN
            FatalError;
        END;
        IF (HeapNoOwner IN HeldItem^.Category) THEN
            IF (HoldInFlexStor IN HeldItem^.Category) THEN      (* 11/1/88 EGK *)
                Handle := AnExtHandle (Where);
                IF (NOT ObjectsAreSame (Handle, AnExtHandle(HeldItem^.Where))) THEN
                    DiscardExtObject (Handle);
                END;
            ELSE
                IF (Where <> HeldItem^.Where) THEN
                    DEALLOCATE(HeldItem^.Where,HeldItem^.Size);
                END;
            END;
        END;
    ELSE
        IF (NOT HeapAvailable()) THEN RETURN END;
        NEW(HeldItem);
        IF (HeldItem <> NIL) THEN
                (*  Add to top of list. *)
            HeldItem^.Category := AHoldTypeSet{}; (* Avoid CheckSum, and *)
            SetChecks(HeldItem);                  (* Make it a valid node. *)
            AddBefore(HeldItemList^.NextLink,HeldItem);
        END;
    END;

        (* Fill in the data *)
    SubStr(Name,HeldItem^.Name,1,HIGH(HeldItem^.Name));
    HeldItem^.Class := Class;
    HeldItem^.Category := Category;
    HeldItem^.Where := Where;
    HeldItem^.Size  := Size;

        (* Set up checks. *)

    SetChecks(HeldItem);

END HoldThis;






    (* LocateHeldItem -- Given a Name, return the Category, address
                         and size of the held item.  Returns value
                         of TRUE iff item found. *)

PROCEDURE LocateHeldItem (     Name     : ARRAY OF CHAR;
                               Class      : CARDINAL;
                           VAR Category : AHoldTypeSet;
                           VAR Where    : ADDRESS;
                           VAR Size     : CARDINAL  ) : BOOLEAN;
VAR
    HeldItem : AHeldItemPointer;
BEGIN
    IF (LocateByName(Name,Class,HeldItem)) THEN
        Category := HeldItem^.Category;
        Where    := HeldItem^.Where;
        Size     := HeldItem^.Size;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END LocateHeldItem;





    (* ForAllHeldItems -- Call the DoThis procedure once for every
                          item held. *)


PROCEDURE ForAllHeldItems ( DoThis : AHolderDoThisProc );
VAR
    HeldItem, NextOne : AHeldItemPointer;
BEGIN
    HeldItem := FirstHeldItem();
    WHILE (HeldItem <> NIL) DO
        CheckHeldItemValid(HeldItem);
        NextOne := NextHeldItem(HeldItem);
        WITH HeldItem^ DO
            DoThis(Name,Class,Category,Where,Size);
        END;
        HeldItem := NextOne;
    END;
END ForAllHeldItems;




PROCEDURE DeleteHeldItem(Name : ARRAY OF CHAR; Class:CARDINAL);
VAR
    HeldItem    : AHeldItemPointer;
    Handle      : AnExtHandle;

BEGIN
    IF (LocateByName(Name,Class,HeldItem)) THEN
        CheckHeldItemValid(HeldItem);
        IF (HeldItem=HeldItemList) THEN FatalError; END;
        DeList(HeldItem);                                          (* 12/10/86 LAA *)
        IF (HeapNoOwner IN HeldItem^.Category) THEN
            IF (HoldInFlexStor IN HeldItem^.Category) THEN          (* 11/1/88 EGK *)
                Handle := AnExtHandle (HeldItem^.Where);
                DiscardExtObject (Handle);
            ELSE
                DEALLOCATE(HeldItem^.Where,HeldItem^.Size);
            END;
        END;
        DISPOSE(HeldItem);
    END;
END DeleteHeldItem;










BEGIN

    IF (HolderListHead = NIL) THEN  (* 22-Jan-91 RSC *)
        ListInit(HeldItemList);
        HolderListHead := HeldItemList;
    ELSE
        HeldItemList := HolderListHead;
    END;

END Holder.
