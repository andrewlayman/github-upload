IMPLEMENTATION MODULE FilterUtility;

    (*  MODIFICATION HISTORY

        16-Aug-89 EGK   First version.  Moved procedures from FilterRc and
                        Filters to here.
        24-Jan-91 RSC   Added CleanFilterRecord as part of Speed and Size
                        improvements.
    *)



FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer, AFltrType,
                                ASlackCheck, AFilterMatch, AFltrSet,
                                AFilterRecord,
    (* VAR *)                   EmptyFilterSet, FilterTree;

FROM FlexStor               IMPORT
   (* TYPES *)                  AnExtHandle, AnExtStoragePreference,
   (* PROCS *)                  HandleIsValid, DiscardExtObject,
                                CreateExtObjectWithSize,
                                LockObject, ReleaseObject;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, StringsEqual, Compare, SetLengthOf;

FROM RsrcMod                IMPORT
    (* PROC *)                  FindResourceByName;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
                                ADDRESS,
                                TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;

FROM Timei                  IMPORT
    (* CONST *)                 MinDate, MaxDate;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTreeNode, CreateTree, ValidateTreeNode;


CONST
    ModuleNumber            = 1100;





(* 24-Jan-91 RSC Added this to speed up TLFilter.
*)
PROCEDURE CleanFilterRecord( VAR FilterRecord : AFilterRecord  );
VAR
    i                   : CARDINAL;
    FilterType          : AFltrType;
    Node                : ATreeNode;
BEGIN
    WITH FilterRecord DO
        IF (antetask = NIL) THEN SetFilterBit (fltrset,FAnte,FALSE); END;
        IF (desctask = NIL) THEN SetFilterBit (fltrset,FDesc,FALSE); END;
        FOR i := 0 TO 3 DO
            FilterType := VAL(AFltrType,ORD(FResource0)+i);
            IF TestFilterBit (fltrset, FilterType) THEN
                Node := FindResourceByName(ResourceName[FilterType]);
                IF (Node = NIL) THEN
                    Fill(ResourceName[FilterType]," ",0);
                    SetFilterBit (fltrset,FilterType,FALSE);
                END;
            END;
        END;
    END;

END CleanFilterRecord;




PROCEDURE CleanFilterSet( Filter : ATreeNode    );
VAR
    FilterPtr           : AFilterRecordPointer;
BEGIN
    IF (Filter = NIL) THEN RETURN; END;

    FilterPtr := Filter^.Methods^.LockFlexStorDataObject (Filter);
    CleanFilterRecord( FilterPtr^ );
    Filter^.Methods^.UnlockFlexStorDataObject (Filter);
END CleanFilterSet;



(*----------------------------------------------------------------------------
    FilterDefaults --

    Give the filter record default values.
----------------------------------------------------------------------------*)

PROCEDURE FilterDefaults( Filter         : ATreeNode);

VAR
    FilterPtr               : AFilterRecordPointer;
    FilterType              : AFltrType;

BEGIN                       (* FilterDefaults *)

    ValidateTreeNode (Filter);
    FilterPtr := Filter^.Methods^.LockFlexStorDataObject (Filter);
    WITH FilterPtr^ DO
        Fill(Name, " ", 0);
        Notes := AText (NIL);
        Any      := TRUE;
        Tag := ModuleNumber;
        fltrset := EmptyFilterSet;
        Fill (StartDateString, " ", 0);
        Fill (EndDateString, " ", 0);
        startdate := MinDate;
        enddate := MaxDate;
        directly := TRUE;
        antetask := NIL;
        desctask := NIL;
        directly := TRUE;
        SlackCheck := NoSlackCheck;
        MilestoneCheck := FALSE;
        LessThan := FALSE;
        PercentComplete := 0;
        LoopCheck := FALSE;
        LateCheck := FALSE;
        PartialJoinCheck := FALSE;
        ConflictCheck := FALSE;
        FOR FilterType := FNameHas TO FRNameHas DO
            Match[FilterType].Type := ItContains;
            Fill(Match[FilterType].Pattern, " ", 0);
        END;
        NeedsUpdate := FALSE;
        Negative := FALSE;
        FilterFlags := {1};
        FOR FilterType := FDataField1 TO FDataField2 DO           (* 07-Jul-89 LAA *)
            DataField[FilterType].FieldId := 0;
            SetLengthOf(DataField[FilterType].CompareTo, 0);
            DataField[FilterType].CompareAs := ItMatches;
            DataField[FilterType].Inverted := FALSE;              (* 16-Jul-89 LAA *)
        END;
    END;
    Filter^.Methods^.UnlockFlexStorDataObject (Filter);

END FilterDefaults;




(*----------------------------------------------------------------------------
    FindFilterByName --

    Look up the filter name given in the group of all filters, and return a
    pointer to that filter if it's found.  Else return NIL.
----------------------------------------------------------------------------*)

PROCEDURE FindFilterByName(VAR FilterName   : ARRAY OF CHAR)       (* in     *)
                                                                : ATreeNode;

VAR
    Filter                  : AFilterRecordPointer;
    Node                    : ATreeNode;
    Equal                   : BOOLEAN;

BEGIN                       (* FindFilterByName *)

    Node := FilterTree^.Methods^.GetFirst (FilterTree);
    WHILE (Node <> NIL) DO
        Filter := Node^.Methods^.LockFlexStorDataObject (Node);
        Equal := (StringsEqual(Filter^.Name, FilterName));
        Node^.Methods^.UnlockUnchangedDataObject (Node);
        IF (Equal) THEN
            RETURN Node;
        END;
        Node := Node^.Methods^.GetNext (Node);
    END;

    RETURN NIL;

END FindFilterByName;








PROCEDURE CompareFilters (Node1, Node2: ATreeNode): INTEGER;
VAR
    Filter1, Filter2            : AFilterRecordPointer;
    Order                       : INTEGER;
BEGIN
    Filter1 := Node1^.Methods^.LockFlexStorDataObject (Node1);
    Filter2 := Node2^.Methods^.LockFlexStorDataObject (Node2);
    Order := Compare (Filter1^.Name, Filter2^.Name);
    Node1^.Methods^.UnlockUnchangedDataObject (Node1);
    Node2^.Methods^.UnlockUnchangedDataObject (Node2);
    RETURN Order;
END CompareFilters;




(*----------------------------------------------------------------------------
    SortFilters --

    Place the filter list into ascending alphabetical order.
----------------------------------------------------------------------------*)

PROCEDURE SortFilters();

VAR
    Node, NextNode, TempNode    : ATreeNode;

BEGIN                       (* SortFilters *)

    (*  Use an insertion sort on the filters, because it's easy to swap
        items on a linked list.  Also, since only one item is added at a
        time to the end of the (already sorted) list, this will place the
        new filter into the correct order with only one swap.
    *)

    Node := FilterTree^.Methods^.GetFirst (FilterTree);
    IF (Node <> NIL) THEN
        NextNode := Node^.Methods^.GetNext (Node);
        WHILE (NextNode <> NIL) DO
            IF (CompareFilters (NextNode, Node) < 0) THEN
                TempNode := Node^.Methods^.GetPrev (Node);
                WHILE ((TempNode <> NIL) AND
                        (CompareFilters (NextNode, TempNode) < 0)) DO
                    TempNode := TempNode^.Methods^.GetPrev (TempNode);
                END;
                NextNode^.Methods^.DeList (NextNode);
                IF (TempNode = NIL) THEN
                    FilterTree^.Methods^.AddFirst (FilterTree, NextNode);
                ELSE
                    TempNode^.Methods^.AddAfter (TempNode, NextNode);
                END;
            ELSE
                Node := NextNode;
            END;
            NextNode := Node^.Methods^.GetNext (Node);
        END;
    END;

END SortFilters;





PROCEDURE CreateFilter (VAR Node    : ATreeNode)
                                                    : BOOLEAN;
VAR
    Filter              : AFilterRecordPointer;
    FilterHandle        : AnExtHandle;

BEGIN

    IF (CreateExtObjectWithSize( FilterHandle,ExtSlow,TSIZE(AFilterRecord))) THEN
        IF (CreateTreeNode (Node)) THEN
            Node^.Methods^.SetDataObject (Node, ADDRESS(FilterHandle));
            IF (LockObject(FilterHandle,Filter) = TSIZE(AFilterRecord)) THEN
                Filter^.Notes := AText(NIL);
                ReleaseObject(FilterHandle);    Filter := NIL;
                FilterDefaults (Node);
                RETURN TRUE;
            END;
        ELSE
            DiscardExtObject(FilterHandle);
        END;
    END;

    RETURN FALSE;

END CreateFilter;



PROCEDURE SetFilterBit  (VAR FilterSet          : AFltrSet;
                             FilterType         : AFltrType;
                             Value              : BOOLEAN   );
VAR
    WordNumber          : CARDINAL;
    BitNumber           : CARDINAL;
BEGIN
    WordNumber := ORD (FilterType) DIV 16;
    BitNumber  := ORD (FilterType) MOD 16;
    IF (Value) THEN
        INCL(FilterSet[WordNumber], BitNumber);
    ELSE
        EXCL(FilterSet[WordNumber], BitNumber);
    END;
END SetFilterBit;



PROCEDURE TestFilterBit (   FilterSet           : AFltrSet;
                            FilterType          : AFltrType
                                                            ): BOOLEAN;
BEGIN
    RETURN ((ORD(FilterType) MOD 16) IN FilterSet[ORD(FilterType) DIV 16]);
END TestFilterBit;







BEGIN
END FilterUtility.
