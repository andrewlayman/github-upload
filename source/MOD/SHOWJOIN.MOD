IMPLEMENTATION MODULE ShowJoins;

(*
    MODIFICATION HISTORY

    01-Jun-87 LAA   Changed MustFind to use the new NextPreOrder methods of
                    TreeObjects instead of FindTask, which is no longer in
                    Allocs.
    7/9/87  EGK     Removed MustFind, because we now allow duplicate task
                    names.  We now use new filters 3 and 4 for antedecent and
                    descendant task highlighting.
    7/31/87 EGK     Changed for new highlight filter scheme.  Now use
                    highlight[1] for predecessors and highlight[2] for
                    successors.
   12-Jan-88 RSC    "Unchanged" changes.
    6-Jun-89 AJL    Put filters into FlexStor.
   15-Jun-89 AJL    Removed F7Filtering.

*)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog                 IMPORT
    (* PROC *)                  Message;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFltrType, AFilterRecordPointer,
    (* VAR *)                   HighlightFilter,
                                EmptyFilterSet,
    (* PROC *)                  DeleteFilter;

FROM FilterUtility          IMPORT
    (* PROC *)                  FilterDefaults, SetFilterBit, CreateFilter;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, ConcatLS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;


CONST
    ModuleNumber            = 17200;

(*----------------------------------------------------------------------------
    HighlightJoinedTasks --

    Highlight all tasks joined to the specified task, as either predecessors 
    or successors.  This temporarily replaces the highlight filtering, but 
    does not effect the reveal filtering.
----------------------------------------------------------------------------*)

(*  If this section is optimized, it won't work.  Seems to have problems
    passing pointer array elements by value.
*)


(*$O-*)

PROCEDURE HighlightJoinedTasks(    Task    : ATreeNode);

VAR
    FilterPtr1              : AFilterRecordPointer;
    FilterPtr2              : AFilterRecordPointer;
    TaskPtr                 : ATaskPtr;
    s                       : ARRAY [0..81] OF CHAR;
    ShowingThisTask         : BOOLEAN;


    PROCEDURE SetItUp();

    BEGIN                   (* SetItUp *)

        IF (HighlightFilter[1] <> NIL) THEN
            FilterDefaults (HighlightFilter[1]);
        ELSIF (NOT CreateFilter (HighlightFilter[1])) THEN
            RETURN;
        END;

        IF (HighlightFilter[2] <> NIL) THEN
            FilterDefaults (HighlightFilter[2]);
        ELSIF (NOT CreateFilter (HighlightFilter[2])) THEN
            DeleteFilter (HighlightFilter[1]);
            RETURN;
        END;

        FilterPtr1 := HighlightFilter[1]^.Methods^.LockFlexStorDataObject (HighlightFilter[1]);
        FilterPtr1^.antetask := Task;
        FilterPtr1^.directly := TRUE;
        FilterPtr1^.fltrset := EmptyFilterSet;
        SetFilterBit (FilterPtr1^.fltrset, FAnte, TRUE);
        HighlightFilter[1]^.Methods^.UnlockFlexStorDataObject (HighlightFilter[1]);
        FilterPtr1 := NIL;


        FilterPtr2 := HighlightFilter[2]^.Methods^.LockFlexStorDataObject (HighlightFilter[2]);
        FilterPtr2^.desctask := Task;
        FilterPtr2^.fltrset := EmptyFilterSet;
        FilterPtr2^.directly := TRUE;
        SetFilterBit (FilterPtr2^.fltrset, FDesc, TRUE);
        HighlightFilter[2]^.Methods^.UnlockFlexStorDataObject (HighlightFilter[2]);
        FilterPtr2 := NIL;

        TaskPtr := Task^.Methods^.LockFlexStorDataObject (Task);
        GetMessage (ModuleNumber + 3, s);       (* "All joins to '" *)
        ConcatLS (s, TaskPtr^.taskname);
        Task^.Methods^.UnlockUnchangedDataObject (Task);

        ConcatMessage (s, ModuleNumber + 5);    (* 'are now displayed." *)
        Message (s);

    END SetItUp;

BEGIN                       (* HighlightJoinedTasks *)

    IF (Task = NIL) THEN RETURN END;

    IF (HighlightFilter[1] <> NIL) THEN
        FilterPtr1 := HighlightFilter[1]^.Methods^.LockFlexStorDataObject (HighlightFilter[1]);
        ShowingThisTask :=(FilterPtr1^.antetask = Task);
        HighlightFilter[1]^.Methods^.UnlockFlexStorDataObject (HighlightFilter[1]);   FilterPtr1 := NIL;
        IF (ShowingThisTask) THEN
            SetLengthOf (s, 0);
            Message (s);
            DeleteFilter (HighlightFilter[1]);
            DeleteFilter (HighlightFilter[2]);
        ELSE
            SetItUp();
        END;
    ELSE
        SetItUp();
    END;
    UnSetState(Filtered);

END HighlightJoinedTasks;

(*$O=*)


BEGIN                       (* ShowJoins *)
END ShowJoins.
