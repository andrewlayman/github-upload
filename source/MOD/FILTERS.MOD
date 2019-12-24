(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

IMPLEMENTATION MODULE Filters;

    (* Need to do work on setting and resetting of FiltersOn. *)

    (* MODIFICATION HISTORY

       Sep. 3, 1985, AJL - Added support for default date format.

       Dec. 4, 1985, AJL - Expanded size of many text buffers.

       May  2, 1986  AJL - Enhanced for separate Reveal/Highlight
                           filters.

       Jul 16, 1986  AJL - CleanFilterSet will now make sure that
                           Resource names in the record actually
                           refer to real resources.  This is necessary
                           in case a File Combine loaded a filter
                           record with names of resources that do
                           not exist.
                         - Call CleanFilterSet from within DoFilterForm
                           as well as within Filter.
       07/23/86 LAA     Changed Code in CheckFilters to be a CARDINAL.              
        11/04/86 LAA    ChartState is now a set.
        11/26/86 LAA    Changed for the new Lights module.
        11/28/86 LAA    In Filter, set the state to Filtered unconditionally.
        12/04/86 LAA    Made changes for new FilterSet in the task record.
        12/08/86 LAA    Added initialization for HighlightFilterName, 
                        RevealFilterName, and F7Filtering.  ResetFilters now
                        uses FilterDefaults from FilterRc instead of doing it
                        itself.  ResetFilters now also resets all manual 
                        filters, and manual filter clear only resets that
                        task.
        12/16/86 LAA    Removed the filter form, and WFilter.  They are now
                        in FilterSelect.  No longer filter on the notes, but
                        do filter on the sort codes.
        5/7/87  EGK     Several changes to allow use of the task tree object
                        for filtering tasks.
        5/ 8/87 RSC    Altered the resource connections.
        5/19/87 RSC    Removed manuall filtering references.
        5/22/87 EGK     Made changes to support tasks as nodes.
        27-May-87 LAA   Added the GELDED and NORMAL version comments.
        01-Jun-87 LAA   Used new methods exported from TreeObjects for
                        TaskFwd, TaskBack, and AdjacentTask.
        04-Jun-87 LAA   Changed parameters for TraverseTree.
        06/09/87 EGK    Modified Filter to handle filter start and end dates
                        as strings.
        7/6/87  EGK     Added code for FLate filter type (late tasks).
        7/9/87  EGK     Added FilterMyAncestors to filter up to the top of
                        the task tree for filtering on dependencies and
                        resource usage.
        7/13/87 EGK     Added MarkEdges procedure in bfs to allow recursive
                        marking of dependencies of subtasks.
        7/28/87 AJL     Changed references from RunOver to RunMenu.
        7/29/87 EGK     Removed all references to manual filtering.
        7/30/87 EGK     Conversions for five highlight filters, including
                        internal dependency filters ([1], [2]) and user-
                        selected highlights ([3], [4], [5]).  These are now
                        copies of tree object pointers from the filter list.
        9/16/87 RSC     Moved init of lights region into init procedure.  
       10/14/87 EGK     Changed the meaning of "late" tasks.  A task is now
                        late if it has a baseline defined and the planned
                        EarlyEnd exceeds the baseline EarlyEnd.
       11/30/87 AJL     Parse end date using StoEndTimeU.
       16-Dec-87 LAA    Removed TaskIsIn, TaskIsHighlighted, and
                        CompletelyUnfilterNode, which are no longer used.
       12-Jan-88 RSC    "Unchanged" changes.
       15-Jan-88 EGK    Rewrote things so that we only make one pass through
                        the task tree.  Removed "bfs" procedure.
       11-Mar-88 RSC    dont Parse end date using StoEndTimeU.
       12-Oct-88 EGK    Added ParentsOpen procedure to keep TaskBack and TaskFwd
                        from returning a node which is invisible because an
                        ancestor task is closed.
       21-Nov-88 LAA    Changed imports for Lazlo reorganiation.
       23-Jan-88 EGK    Moved things from here to TLFILTER overlay.
       30-May-89 AJL    Put filter records into FlexStor.
                        Clearing a task's filters just sets the FilterSet.
       15-Jun-89 AJL    Removed F7Filtering.
        19-Jun-89 AJL   Removed FiltersOn boolean, replaced by 
                        SetRevealFilterDisabled, and QueryRevealFilterOn.
       16-Aug-89 EGK    Moved CleanFilterSet to FilterUtility.
       24-Aug-89 EGK    Call UnSetState(Filtered) in SetRevealFilterDisabled.
       19-Sep-89 RSC    Cleaned up AdjacentTask and removed TaskFwd and
                        TaskBack.
    *)


FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskFilter, ATaskFilterSet,
    (* VAR *)                   TaskTree;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* VAR *)                   ChartState,
    (* PROC *)                  SetState, UnSetState;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFltrType, AFltrSet, AFilterRecordPointer,
                                AFilterMatch, ASlackCheck,
    (* VAR *)                   RevealFilter, HighlightFilter,
    (* PROC *)                  DeleteFilter;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* VAR *)                   ActiveLightRegion,
    (* PROC *)                  InstallLight, DisplayLight;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;



CONST
    ModuleNumber            = 4100;       (* For GetMessage *)
    FilterLightPriority     = 80;


VAR
    FilterLight             : ALight;
    Initialized             : BOOLEAN;





    (* Filter -- Set the filter flags for all tasks *)


PROCEDURE Filter;

VAR
    OverlayName                 : ARRAY [0..20] OF CHAR;
    Result                      : BOOLEAN;

BEGIN

    SetString (OverlayName, "TLFILTER");
    Result := CallOverlayWithContext (OverlayName, NIL);

    SetState(Filtered);                                  (* 11/28/86 LAA *)

END Filter;









(* Cleaned up some.   19-Sep-89 RSC.
*)
PROCEDURE AdjacentTask( Node : ATreeNode ) : ATreeNode;
VAR
    NewTask : ATreeNode;
BEGIN

    NewTask := Node;

    IF (NewTask <> NIL) THEN
        NewTask := NewTask^.Methods^.NextForDisplay(NewTask);
        IF (NewTask = NIL) THEN
            NewTask := Node^.Methods^.PrevForDisplay(Node);
        END;
    END;

    RETURN NewTask;

END AdjacentTask;









    (* -----------------------------------------------------------------
       SetRevealFilterDisabled

       Preconditions: None.

       Postconditions: There will not be a currently active Reveal Filter 
                       for tasks.
    --------------------------------------------------------------------*)


PROCEDURE SetRevealFilterDisabled();
BEGIN
    IF (NOT Initialized) THEN
        DoInitialization;
    END;

    IF (RevealFilter <> NIL) THEN
        RevealFilter := NIL;
 
        UnSetState(Formatted);
        ShowFilterLight();
    END;
    UnSetState (Filtered);          (* 8/24/89 EGK *)
END SetRevealFilterDisabled;




PROCEDURE UnfilterNode (VAR Node        : ATreeNode;
                            Context     : ADDRESS   );    (* 04-Jun-87 LAA *)

VAR
    Task: ATaskPtr;
BEGIN
    Task := Node^.Methods^.LockFlexStorDataObject (Node);
    Task^.FilterSet := ATaskFilterSet{Selected};
    Node^.Methods^.UnlockFlexStorDataObject (Node);
    Node^.Methods^.SetVisible (Node, TRUE);
END UnfilterNode;




PROCEDURE ResetFilters;
VAR
    FilterType  : AFltrType;
    i           : CARDINAL;
BEGIN
    SetRevealFilterDisabled();

        (* Filters number 1 and 2 are not part of the filter list.  So,
           they should be deleted whenever they are turned off. *)
    FOR i := 1 TO 2 DO
        IF ( HighlightFilter[i] <> NIL ) THEN
            DeleteFilter (HighlightFilter[i]);
        END;
    END;
    FOR i := 1 TO 5 DO
        HighlightFilter[i] := NIL;
    END;
    TaskTree^.Methods^.
          TraverseTree (TaskTree, ParentBeforeChild, 9999, UnfilterNode, NIL);
    UnSetState(Formatted);
END ResetFilters;





    (* -----------------------------------------------------------------
       QueryRevealFilterOn

       Preconditions: None.

       Postconditions: If there is a currently active Reveal Filter for
                       tasks, returns TRUE, else FALSE.
    --------------------------------------------------------------------*)


PROCEDURE QueryRevealFilterOn():BOOLEAN;
BEGIN
    RETURN RevealFilter <> NIL;
END QueryRevealFilterOn;











PROCEDURE ShowFilterLight;

VAR
    S                       : ARRAY [0..20] OF CHAR;

BEGIN
    IF (QueryRevealFilterOn()) THEN
        GetMessage(ModuleNumber+7,S);
    ELSE
        Fill(S, " ", 0);
    END;
    DisplayLight(FilterLight, S, videolights);

END ShowFilterLight;



PROCEDURE DoInitialization;
BEGIN
    InstallLight(ActiveLightRegion, FilterLightPriority, 8, 20, FilterLight);
    Initialized := TRUE;
END DoInitialization;



BEGIN
    Initialized := FALSE;   (* Delay some things until all modules loaded. *)
END Filters.
