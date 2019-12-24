IMPLEMENTATION MODULE Filter1;

        (* This module determines which of the current filters would be
           passed by the resource.  The ATaskFilterSet returned reflects
           the result of applying each of the active filters to the 
           resource.  We only check the portions of those filters that
           specify resource information, specifically the resource names
           and keywords.

           Although we return a set that is lables ATaskFilterSet, it is
           really a set of succeeding filters.  Until now, these have been
           only used for tasks, but we remove that restriction.

           MODIFICATION HISTORY:

           June 27, 1988  AJL - Original version.
            Jan 26, 1989  EGK - changed to use StringMatch from new Searcher
                                module, to allow wildcard searches.
          30-May-89 AJL         Moved filter records to FlexStor.
          21-Aug-89 EGK   Import procs from FilterUtility instead of FilterRc.
          23-Sep-90 LAA   Because of a fix to StringMatch in Searcher, it's
                          no longer necessary to make a copy of the parameters
                          passed to that procedure in order to assure that 
                          they don't get upshifted.  Now done in StringMatch.
        *)

FROM Allocs                 IMPORT
    (* TYPE *)                ATaskFilter, ATaskFilterSet,
                              ATaskPtr;

FROM Assignments            IMPORT
    (* TYPE *)                AnAssignmentRecord;

FROM Dialog                 IMPORT
    (* PROC *)                 FatalError;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM FilterRc               IMPORT  
    (* TYPE *)                 AFltrType, AFltrSet, AFilterRecordPointer,
                               AFilterMatch,
    (* VAR *)                  RevealFilter, HighlightFilter;

FROM FilterUtility          IMPORT
    (* PROC *)                 TestFilterBit;

FROM FlexStor               IMPORT
    (* TYPE *)                 AnExtHandle, 
    (* PROC *)                 LockObject, ReleaseUnchangedObject;


FROM LStrings               IMPORT
    (* PROC *)                 Copy, Upshift;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer,
    (* PROC *)                  FindResourceByNumber;

FROM Searcher               IMPORT
    (* PROC *)                  StringMatch;

FROM TreeObjects            IMPORT
    (* TYPE *)                 ATreeNode;






PROCEDURE CheckThisFilter(     FilterNode : ATreeNode;
                               ResourceNode : ATreeNode;
                               FilterIdentifier : ATaskFilter; 
                           VAR FilterSet    : ATaskFilterSet );
VAR
    Node         : ATreeNode;
    FilterRecord : AFilterRecordPointer;
    Resource     : AResourcePointer;    
    FilterType   : AFltrType;
    FilteredIn,                    (* Passes this filter. *)
    Significant : BOOLEAN;         (* This filter lists resource criterea *)

BEGIN
    IF (FilterNode = ATreeNode(NIL)) THEN RETURN; END;

        (* This routine makes that assumption that a Resource will pass
           only one of the criterea, so we do not attempt to track each
           separately in order to check for all vs. any. *)


    FilterRecord := FilterNode^.Methods^.LockFlexStorDataObject (FilterNode);

        (* The default condition is for the resource to be Selected, 
           but not highlighted *)

    Significant := FALSE;
    FilteredIn := FALSE;

        (* Look through the array of resources specifically identified.
           Each filter can list several resources explicitly.  If this
           filter lists a resource, and that is the resource we are
           testing, then it may pass this filter. *)

    FOR FilterType := FResource0 TO FResource3 DO
        IF TestFilterBit (FilterRecord^.fltrset, FilterType) THEN
            Node := FilterRecord^.ResourceNode[ FilterType ];
            IF ( Node <> NIL) THEN
                IF (Node = ResourceNode) THEN
                    FilteredIn := TRUE;
                END;
            END;
            Significant := TRUE;
        END;
    END;

        (* If we are looking at the more broad FRNameHas criterea, then
           we need to locate the actual Resource record. Note that we
           are duplicating logic from the Filters module here, so if it
           changes, we need to change, too. *)

    IF TestFilterBit (FilterRecord^.fltrset, FRNameHas) THEN
               (* Do this only after testing that FRNameHas is in filter
                  set--otherwise the pattern may not be a valid LString. *)

        Significant := TRUE;
        Resource := ResourceNode^.Methods^.GetDataObject (ResourceNode);

              (* Is there a match on the keyword? *)
        IF (StringMatch (FilterRecord^.Match[FRNameHas].Pattern, 
                         Resource^.Keyword, ItContains)) THEN  (* 23-Sep-90 *)    
            FilteredIn := TRUE;
        END;
    END;

    IF (Significant) THEN
        IF (FilteredIn = FilterRecord^.Negative) THEN
            EXCL( FilterSet, FilterIdentifier );
        ELSE
            INCL( FilterSet, FilterIdentifier );
        END;
    END;

    FilterNode^.Methods^.UnlockUnchangedDataObject (FilterNode);

END CheckThisFilter;



PROCEDURE ResourceFiltersPassed( ResourceNode : ATreeNode ) : ATaskFilterSet;
VAR
    i : CARDINAL;
    FilterSet : ATaskFilterSet;
    FilterIdentifier : ATaskFilter;
BEGIN

    FilterSet := ATaskFilterSet{Selected};
    CheckThisFilter(RevealFilter,ResourceNode,Selected,FilterSet);
    FOR i := 1 TO HIGH(HighlightFilter) DO
        FilterIdentifier := VAL( ATaskFilter, ORD(Highlight1) - 1 + i ); 
        CheckThisFilter(HighlightFilter[i],ResourceNode,FilterIdentifier,FilterSet);
    END;
    RETURN FilterSet;
END ResourceFiltersPassed;




PROCEDURE TaskFiltersPassed( TaskNode : ATreeNode ) : ATaskFilterSet;
VAR
    TaskHandle : AnExtHandle;
    Task : ATaskPtr;
    FilterSet : ATaskFilterSet;
BEGIN
    TaskHandle := AnExtHandle(TaskNode^.Methods^.GetDataObject (TaskNode));
    IF (LockObject(TaskHandle,Task) <> 0) THEN
        FilterSet := Task^.FilterSet;
        ReleaseUnchangedObject(TaskHandle);
        IF (RevealFilter = NIL) THEN          (* AC-CEN-TU-ATE the positive! *)
            INCL(FilterSet,Selected);
        END;
    ELSE
        FatalError();
    END;
    RETURN FilterSet;
END TaskFiltersPassed;




PROCEDURE AssignmentFiltersPassed(     TaskNode : ATreeNode;
                                   VAR Assignment : AnAssignmentRecord ) : ATaskFilterSet;
VAR
    ResourceSet, TaskSet : ATaskFilterSet;
    ResourceNode : ATreeNode;
BEGIN
    TaskSet := TaskFiltersPassed( TaskNode );
        (* Slow, but this is a report, and it does work. *)
    ResourceNode := FindResourceByNumber(Assignment.Resource^.ID);
    ResourceSet := ResourceFiltersPassed( ResourceNode );
    RETURN TaskSet * ResourceSet;
END AssignmentFiltersPassed;




PROCEDURE DependencyFiltersPassed( Edge : AnEdgePtr ) : ATaskFilterSet;
VAR
    A, B : ATaskFilterSet;
BEGIN
    A := TaskFiltersPassed( Edge^.headtask );
    B := TaskFiltersPassed( Edge^.tailtask );
    RETURN A * B;
END DependencyFiltersPassed;




END Filter1.
