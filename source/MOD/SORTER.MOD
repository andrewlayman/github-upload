(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    05/25/87 AJL    Constructed this module based on the former Sorter
                    module from TimeLine version 2.3.
   10-Jan-89 RSC    Changed Storage to BTStorage.
   24-Jan-89 RSC    Changed BTStorage to Space.  Made sorting Break() able,
                    Cleaned up several issues with:
                        > More than 4096 items in one list (for OS/2)
                        > Stack space check prior to heap allocation
                        > no heap space check
                        > gracefull abandonment of sort.
----------------------------------------------------------------------------*)
IMPLEMENTATION MODULE Sorter;


    (* ESSAY: AJL Dec. 18, 1986 

           Sorting can sometimes take an extraordinarily long time. 
       For example, sometimes the user will put WBS number at the start 
       of a task name or notes field, and will sort based on this.
       Partly because these numbers have a lot of leading characters in 
       common, because this method is used for large schedules, because 
       string comparisons are slower than date comparisons, and because 
       the schedule calculations totally jumble the alphabetic order of 
       tasks, this can run very slowly. 

           Several improvements are possible.  First, obviously, we could 
       increase speed by using a better sorting algorithm.   Heap sort
       comes to mind since it is guaranteed N ln N, and can easily use
       the next and prev links. 

           But we can also get improved perceived performance by observing
       that the displayed sort order doesn't change very much from one time to
       the next (unless the user selects a new sort key).  This suggests that 
       if we record the sort order obtained last time, restore the tasks to 
       this order, then make any minor corrections (using an algorithm such as
       insertion sort that works very efficiently of nearly sorted lists) we
       should get seemingly very rapid sorts. 

           This would probably require that we expand each task's record to 
       contain a cardinal sequence number from the last sort, and us to 
       keep a record of the last sort key used, so that we can decide if
       those sequence numbers are still useful. 

           Also, on any change to a task that does not involve recalculating
       the schedule, we could merely move that task to its correct place in 
       the list, without forcing a resort of all tasks. 

       Note: At one point, I thought of allowing CtrlBreak to cancel a
             sorting.  This is not safe, since we do not know what procedure
             is calling us, and the caller may depend on the sort running 
             to completion. 

           RSC 24-Jan-89:

                This module is now Break Sensitive!  If "BreakRequested()"
                returns TRUE, then the sort has failed at a point such that,
                for each subtree or list, it is either sorted, or the way
                it was before sorting.  See special note for
                "SortArrayOfObjects".  The theory here is that we could have
                had OTHER errors, such as memory failures, so we can't just
                say that sorting always succeeds.

    *)




FROM Dialog       IMPORT
    (* PROC *)           FatalError, Error;

FROM Kbio         IMPORT
    (* PROC *)          BreakRequested;

FROM LinkedListObjects IMPORT
    (* TYPE *)           ALinkedList, ALinkedListNode;

FROM MsgFile      IMPORT
    (* PROCS *)         GetMessage;

FROM Objects      IMPORT
    (* TYPE *)           AnObject;

FROM Space        IMPORT
    (* PROC *)           Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM       IMPORT
    (* PROC *)           TSIZE;

FROM TreeObjects  IMPORT
    (* TYPE *)          ATree, ATreeNode;





CONST
    ModuleNumber    = 27800;











    (* --------------------------------------------------------------

       SortArrayOfObjects --

       Preconditions:
           This must be the only procedure modifying the array.  This
           procedure is not reentrant, and does not allow for any
           changes to the array during its tenure, except those controlled
           internally.

           Array points to an array of objects.

           N is the number of elements in the array.

       Postconditions:
           If TRUE,
               The nodes in the array will be reordered so that, for no
               nodes, Compare( Node, Node^.Methods^.GetNext(Node)) = FALSE.
           ELSE
               Sorting was interruped by the customer via a Break!  The Array
               of objects should be assumed to be INVALID.  RSC 24-Jan-89.

           This procedure is not "stable".  That is, there is no guarantee
           that nodes which compare as equal to each other will be kept
           in the same order after sorting as they appeared prior to
           sorting.

     ----------------------------------------------------------------*)

PROCEDURE SortArrayOfObjects( Array   : AnArrayOfObjects;
                              N       : CARDINAL;
                              Compare : AnObjectCompareProc ) : BOOLEAN;
CONST 
    MinimumPartition = 10;
VAR 
    i, j, L, R, p    : CARDINAL;
    V                : AnObject;
    Stack            : ARRAY [0..100] OF CARDINAL;
    a, b, c          : CARDINAL; 


    PROCEDURE Exchange( d, e : CARDINAL );
    VAR 
        T : AnObject;
    BEGIN 
        T := Array^[d];  Array^[d] := Array^[e];  Array^[e] := T; 
    END Exchange; 



    PROCEDURE ThreeSort( a, b, c : CARDINAL );
    BEGIN 
        IF (Compare(Array^[a],Array^[b])) THEN
            Exchange(a,b);
        END;
        IF (Compare(Array^[a],Array^[c])) THEN
            Exchange(a,c);
        END;
        IF (Compare(Array^[b],Array^[c])) THEN
            Exchange(b,c);
        END;
    END ThreeSort;


    PROCEDURE Partition( VAR Array : ARRAY OF AnObject; l, r : CARDINAL ) : CARDINAL; 
    VAR 
        V    : AnObject;
        i, j : CARDINAL;
    BEGIN 

        V := Array[r];   i := l-1;   j := r;
        LOOP
            REPEAT
                INC(i); 
            UNTIL (  (i>=r) OR Compare(Array[i],V)  );     (* Don't compare to self! *) 
            REPEAT
                DEC(j); 
            UNTIL ( (j <= i) OR Compare(V,Array[j])  );    (* j <= l implies j <= i *)
            IF ( j <= i) THEN 
                EXIT; 
            END;
            Exchange(i,j);
        END;
        Exchange(i,r);


        RETURN i; 
    END Partition;

BEGIN
    L := 1;  R := N;  p := 2; 

    REPEAT
        IF (R > (L + MinimumPartition)) THEN

                (* Although the partition algorithm has been modified to
                   check the indices against the bounds, and this also
                   avoids the need for sentinals, we will still do a
                   median-of-three partitioning selection in order to 
                   avoid degenerate cases.
                       Note also that as long as MinimumPartition > 2 then
                   ThreeSort will not attempt to compare an array 
                   element with itself (which is not necessarily a
                   defined operation).
                *)

            a := L;  b := (L+R) DIV 2;  c := R; 
            ThreeSort(a,b,c); 
            Exchange(b,R);

            i := Partition(Array^,L,R); 
            IF (i-L) > (R-i) THEN 
                Stack[p] := L;  Stack[p+1] := i-1;  L := i+1; 
            ELSE
                Stack[p] := i+1;  Stack[p+1] := R;  R := i-1; 
            END;
            INC(p,2); 
            IF (p > HIGH(Stack)) THEN FatalError(); END;  (* RSC 24-Jan-89 *)
        ELSE
            DEC(p,2);  L := Stack[p];  R := Stack[p+1]; 
        END;
    UNTIL ((p = 0) OR BreakRequested());


        (* Since we may have numerous small partitions still unsorted,
           courtesy of the effect of MinimumPartition, we need to do
           a final sort of the task list.  Insertion Sort is appropriate
           for this nearly sorted list. *)

    FOR i := 2 TO N DO
        IF (NOT BreakRequested()) THEN
            V := Array^[i];
            j := i;
            WHILE ((j > 1) AND ( Compare(Array^[j-1],V) )) DO
                Array^[j] := Array^[j-1];
                DEC(j);
            END;
            Array^[j] := V;
        END;
    END;

    RETURN (NOT BreakRequested());  (* Only way we can terminate early. *)

END SortArrayOfObjects;










    (* SortLinkedList  -- The most important aspect of this procedure
                          is to minimize the number of comparisons done
                          since they may be string comparisons or other
                          expensive operations.

            A TRUE return means the sort went fine.
            
            A FALSE means one of:

                1) We ran out of room.
                2) User hit BREAK.
                3) Too many items in list (more than 4096)

            The good news is, either the whole sort made it or none of
            the sort applied.
    *)
PROCEDURE SortLinkedList(     List    : ALinkedList;
                              Compare : AnObjectCompareProc ) : BOOLEAN;
VAR 
    i, N                : CARDINAL;
    t, CurrentNode      : ALinkedListNode;
    SizeNeeded          : CARDINAL;
    A                   : POINTER TO ARRAY [0..4096] OF ALinkedListNode;
    s                   : ARRAY [0..255] OF CHAR;
BEGIN 

        (* Count the number of nodes. *)

    N := 0;
    CurrentNode := List^.Methods^.GetFirst(List);
    WHILE (CurrentNode <> NIL) DO
        INC(N);
        CurrentNode := CurrentNode^.Methods^.GetNext(CurrentNode);
    END;

    IF (N > HIGH(A^)) THEN
        GetMessage( ModuleNumber + 1, s ); (* "Too many entries to sort."   RSC 24-Jan-89  *)
        Error(s);
        RETURN FALSE;
    END;

        (* Check that we have enough heap space to build an array
           of pointers to the nodes. *)

    SizeNeeded := ((N+1) * TSIZE(ALinkedListNode));
    IF (NOT Available(SizeNeeded)) THEN
        GetMessage( ModuleNumber + 2, s ); (* "Too many entries for the memory you have."   RSC 24-Jan-89  *)
        Error(s);
        RETURN FALSE;
    END;

    IF (BreakRequested()) THEN
        RETURN FALSE;
    END;

        (* Fill the A array with pointers to each task. *)

    ALLOCATE(A,SizeNeeded); 

    i := 0;
    CurrentNode := List^.Methods^.GetFirst(List);
    WHILE (CurrentNode <> NIL) DO
        INC(i);
        A^[i] := CurrentNode;
        CurrentNode := CurrentNode^.Methods^.GetNext(CurrentNode);
    END;
    IF (i <> N) THEN FatalError(); END; (* To be sure.  RSC 24-Jan-89 *)

        (* Sort the list *)
        (* Starting with the smallest task, remove each from the
           unsorted list, and put it at the end of the list. *)

    IF (SortArrayOfObjects(AnArrayOfObjects(A),N,Compare)) THEN
        FOR i := 1 TO N DO
            CurrentNode := A^[i];
            CurrentNode^.Methods^.DeList(CurrentNode);
            List^.Methods^.AddLast(List,CurrentNode);
        END;
    END;

        (* Toss away temp storage. *) 

    DEALLOCATE(A,SizeNeeded); 

    RETURN (NOT BreakRequested());

END SortLinkedList;








PROCEDURE SortTree      (     Tree    : ATree;
                              Compare : AnObjectCompareProc ) : BOOLEAN;
VAR
    CurrentNode : ATreeNode;
BEGIN
    IF (Tree = NIL) THEN
        RETURN TRUE;
    END;

    IF (SortLinkedList( ALinkedList(Tree), Compare )) THEN

        CurrentNode := Tree^.Methods^.GetFirst(Tree);
        WHILE (CurrentNode <> NIL)   AND
              (SortTree( CurrentNode^.Methods^.GetSubtree(CurrentNode),
                         Compare ))   DO
            CurrentNode := CurrentNode^.Methods^.GetNext(CurrentNode);
        END;

        RETURN (CurrentNode = NIL); (* TRUE if we did the whole list *)

    ELSE
        RETURN FALSE;
    END;


END SortTree;














BEGIN
END Sorter.
