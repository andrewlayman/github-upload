IMPLEMENTATION MODULE FilterRc;


    (* MODIFICATION HISTORY:

       Aug. 22, 1985  AJL -- Removed ResetFilters from initialization
                             to TimeLine main module.  It was calling
                             Allocs.ForAllTasks before Allocs was
                             initialized.
       Oct.  5, 1987  RSC -- When creating a filter, set notes field to NIL.
            2-Jan-89  RSC    Added references to StringsEqual() rather than Compare().
       11-May-89      AJL -- Added the "Needs Update" field.
       30-May-89 AJL         Moved filter records to FlexStor.
       15-Jun-89 AJL    Removed F7Filtering.
        19-Jun-89 AJL   Removed FiltersOn boolean.
        5-Jul-89 EGK    Fixed bug in CheckForDeletedTask.  It was setting
                        the filter to NIL unconditionally, whether or not
                        it was actually deleted (scratched).
        07-Jul-89 LAA   Added fields to the record for comparing any task
                        column against text entered by the user.
        16-Jul-89 LAA   Put in the Inverted field, so that we can compare
                        columnar data to be the inversed of a specified
                        relationship.
        21-Aug-89 AJL   When notified of a deleted task, check all filters
                        in the list, not just the active ones. 
        28-Aug-89 EGK   Moved most procedures from here to FilterUtility.
    *)

FROM Allocs                 IMPORT
    (* PROC *)                  CheckTaskValid;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor        IMPORT
   (* TYPES *)           AnExtHandle, AnExtStoragePreference,
   (* PROCS *)           HandleIsValid, DiscardExtObject,
                         CopyExtObject, CreateExtObjectWithSize,
                         LockObject, ReleaseObject, ReleaseUnchangedObject;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
                                ADDRESS,
                                TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree, ATreeOrder,
                                ATreeNodeProcessingProc, 
    (* PROC *)                  CreateTreeNode, CreateTree, ValidateTreeNode;



CONST
    MAXCARDINAL             = 0FFFFH;
    ModuleNumber            = 1100;

VAR
    i                       : CARDINAL;


PROCEDURE CheckForDeletedTask( VAR  Filter  : ATreeNode;
                                    Task    : ATreeNode  );
VAR
    FilterPtr           : AFilterRecordPointer;
    ScratchIt           : BOOLEAN;
    i           : CARDINAL;
BEGIN
    IF (Filter = NIL) THEN
        RETURN;
    END;

    ValidateTreeNode(Filter);
    CheckTaskValid(Task);

    FilterPtr := Filter^.Methods^.LockFlexStorDataObject (Filter);
    WITH FilterPtr^ DO
        ScratchIt := (antetask = Task) OR (desctask = Task);
    END;
    Filter^.Methods^.UnlockUnchangedDataObject (Filter);    FilterPtr := NIL;

    IF (ScratchIt) THEN
        (*$O-*)
        DeleteFilter (Filter);     (* Note that this might change our
                                      parameter! *)
        (*$O=*)
    END;

END CheckForDeletedTask;



PROCEDURE FilterSetIsEmpty (Filter : ATreeNode ) : BOOLEAN;
VAR
    FilterPtr           : AFilterRecordPointer;
    Answer              : BOOLEAN;
BEGIN
    IF (Filter = NIL) THEN
        RETURN TRUE;
    END;
    FilterPtr := Filter^.Methods^.LockFlexStorDataObject (Filter);
    Answer := (FilterPtr^.fltrset[0] = EmptyFilterSet[0]) AND
              (FilterPtr^.fltrset[1] = EmptyFilterSet[1]);
    Filter^.Methods^.UnlockUnchangedDataObject (Filter);
    Filter := NIL;

    RETURN Answer;
END FilterSetIsEmpty;






    (*  FiltersNotifyDeleted -- Please call this if you delete a
                                task. *)

PROCEDURE FiltersNotifyDeleted( Node : ATreeNode );
VAR
    i           : CARDINAL;
BEGIN
    FOR i := 1 TO HIGH(HighlightFilter) DO
        CheckForDeletedTask (HighlightFilter[i],Node);
    END;
    CheckForDeletedTask (RevealFilter,Node);
    FilterTree^.Methods^.TraverseTree (FilterTree, ParentBeforeChild, 9999,
            ATreeNodeProcessingProc(CheckForDeletedTask), Node);

END FiltersNotifyDeleted;






PROCEDURE DeleteFilter (VAR Node    : ATreeNode);
VAR
    Filter          : AFilterRecordPointer;
    FilterHandle    : AnExtHandle;
    i               : CARDINAL;
    NodeCopy        : ATreeNode;
BEGIN
    NodeCopy := Node;

    FilterHandle := AnExtHandle(Node^.Methods^.GetDataObject (Node));
    IF (LockObject(FilterHandle,Filter) <> TSIZE(AFilterRecord)) THEN
        FatalError();
    END;
    DiscardText (Filter^.Notes);
    ReleaseObject(FilterHandle);       Filter := NIL;
    DiscardExtObject (FilterHandle);

    IF (RevealFilter = Node) THEN    (* don't leave any dangling pointers *)
        RevealFilter := NIL;
        UnSetState (Filtered);
    END;

    FOR i := 1 TO HIGH(HighlightFilter) DO
        IF (HighlightFilter[i] = Node) THEN
            HighlightFilter[i] := NIL;
            UnSetState (Filtered);
        END;
    END;

    NodeCopy^.Methods^.Discard (NodeCopy);   (* Use NodeCopy since Node might
                                                be one of the filters which just
                                                got set to nil, and since Node is
                                                a VAR, it might have just, indirectly,
                                                become nil.    AJL 6/7/89   *)
    Node := NIL;
END DeleteFilter;





BEGIN
    EmptyFilterSet[0] := BITSET(0);
    EmptyFilterSet[1] := BITSET(0);
    IF (NOT CreateTree (FilterTree)) THEN
        FatalError ();
    END;
    RevealFilter := NIL;
    FOR i := 1 TO HIGH(HighlightFilter) DO
        HighlightFilter[i] := NIL;
    END;
END FilterRc.
