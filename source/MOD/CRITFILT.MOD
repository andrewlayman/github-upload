IMPLEMENTATION MODULE CritFilt;

    (* MODIFICATION HISTORY

       16-June-89 AJL Initial Version
       21-Aug-89 EGK  Import procs from FilterUtility instead of FilterRc.


    *)



FROM FilterRc    IMPORT  
    (* TYPE *)           AFltrType,  
                         AFilterRecordPointer,
                         ASlackCheck,
                         HighlightFilter;

FROM FilterUtility          IMPORT
     (* PROC *)                 TestFilterBit;
    
FROM TreeObjects IMPORT  
     (* TYPE *)           ATreeNode;
                  



    (*  -------------------------------------------------------------

        QueryCriticalPathFilter

        Preconditions: none.

        Postconditions:  A.  If there is a highlight filter currently 
                             active which is selecting critical path tasks,
                             the lowest numbered such filter number is
                             returned in Number and the function returns
                             TRUE.

                         B.  Else, FALSE is returned, and Number is 
                             undefined.

    -------------------------------------------------------------------- *)




PROCEDURE QueryCriticalPathFilter( VAR Number : CARDINAL ) : BOOLEAN;
VAR
    i                   : CARDINAL;
    FilterPtr           : AFilterRecordPointer;
    Filter              : ATreeNode;
    Bingo               : BOOLEAN;
BEGIN
    FOR i := 3 TO HIGH(HighlightFilter) DO
        Filter := HighlightFilter[i];
        IF (Filter <> NIL) THEN
            FilterPtr := Filter^.Methods^.LockFlexStorDataObject (Filter);
            WITH FilterPtr^ DO
                Bingo := TestFilterBit(fltrset,FSlack) AND
                         (SlackCheck >= CriticalCheck);
            END;
            Filter^.Methods^.UnlockUnchangedDataObject (Filter);    FilterPtr := NIL;
            IF (Bingo) THEN
                Number := i;
                RETURN TRUE;
            END;
        END;
    END;

    RETURN FALSE;
END QueryCriticalPathFilter;


END CritFilt.
