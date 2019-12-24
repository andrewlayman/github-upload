IMPLEMENTATION MODULE ResCal;

    (* MODIFICATION HISTORY 

       29 May 90  AJL  - Initial version, based on work by Janet Somers.
       10-Jul-90  AJL  - Added AResAvailability, DisposeResAvailability,
                         CopyResAvailability.
       11-Jul-90  AJL/WKH - Fix a flaw in CopyResAvailability.                   
       24-Jul-90  JES  - Added CreateNewCell, CellContainingDate 
                         procedures.       
                         (Changed definition of AnAvailabilityCell -       
                           see .def part.)
       18-Oct-90 AJL/CL - Modify the logic of DisposeResAvailabilities,
                          CellContainingDate, and CopyResAvailabilities
                          to use the new AnAvailabilityCell which is
                          a doubly linked list with a head cell now.
                        - Remove unused items from IMPORT section.
                        - Rename local variables to improve readability.
        8-Nov-90 CL     - Rewrite CopyResAvailabilities.
                        - Add code to set Target to NIL if Source is NIL
                          in the beginning of CopyResAvailabilities.
       12-Nov-90 RSC    - Set passed res availability to NIL in
                          DisposeResAvailabilities()
       21-Nov-90 CL     - Call FatalError when LockObject returns a
                          wrong size.
       06-Dec-90 JES    - Added procedure BackCellContainingDate. This
                          procedure is a backwards version of CellContaining
                          Date (i.e., it searches backwards through the
                          list instead of forwards). However, instead of
                          finding the cell such that 
                            cell start date <= given date  < cell end date,
                          it finds the cell such that
                            cell start date <  given date  <=cell end date.
                          The procedure is useful when we have a given
                          end date for some time period (and thus is not
                          actually itself contained in the time period), and
                          we want to find the cell representing it.
   *)

FROM FatalErr   IMPORT
    (* PROC *)      FatalError;

FROM FlexStor   IMPORT
    (* TYPE *)      AnExtHandle, AnExtStoragePreference,
    (* PROC *)      CreateExtObject, DiscardExtObject, ReleaseObject,
                    CreateExtObjectWithSize, LockObject, CopyExtObject,
                    ReleaseUnchangedObject;

FROM SYSTEM     IMPORT
    (* PROC *)      TSIZE;

FROM Timei      IMPORT
    (* TYPE *)      ADate;





(* Dispose of a doubly linked list with head cell *)

PROCEDURE DisposeResAvailabilities(  VAR ResList : AResAvailability );
VAR
    Cell       : AnAvailabilityCellPointer;
    Next, Head : AnExtHandle;
BEGIN
    IF ( ResList <> AResAvailability(NIL) ) THEN
        Head := ResList;       (* save the head cell *)
        REPEAT
            IF (LockObject(ResList, Cell) = TSIZE(AnAvailabilityCell)) THEN
                Next := Cell^.NextCell;
                ReleaseUnchangedObject(ResList);
                Cell := NIL;
                DiscardExtObject(ResList);
            ELSE
                FatalError;
            END;
            ResList := Next;
        UNTIL ResList = Head;
    END;

    ResList := AResAvailability(NIL);

END DisposeResAvailabilities;





(* Copy a doubly linked list with head cell *)

PROCEDURE CopyResAvailabilities( VAR Target : AResAvailability;
                                     Source : AResAvailability;
                                     Speed  : AnExtStoragePreference ) : BOOLEAN;
VAR
    Cell, NewCell, LastNewCell : AnAvailabilityCellPointer;
    CellHandle, NextHandle, NewHandle, LastNewHandle : AnExtHandle;
    Okay, First, OnlyOne : BOOLEAN;
    
BEGIN
    IF Source = AnExtHandle(NIL) THEN
        Target := AnExtHandle(NIL);
        RETURN TRUE;
    END;

    CellHandle     := Source;      (* In case Source is an alias for Target *)
    Okay           := TRUE;
    First          := TRUE;
    OnlyOne        := FALSE;
    LastNewHandle  := AnExtHandle(NIL);

    REPEAT
        IF (LockObject(CellHandle,Cell) = TSIZE(AnAvailabilityCell)) THEN
            NextHandle := Cell^.NextCell;
            IF CopyExtObject(CellHandle,Speed,NewHandle) THEN
                IF (First) THEN
                    Target := NewHandle;
                    First  := FALSE;
                    IF (CellHandle = NextHandle) THEN
                        OnlyOne := TRUE;
                    END;
                ELSE   (* not the first cell *)
                    IF (LockObject(LastNewHandle,LastNewCell) = TSIZE(AnAvailabilityCell)) THEN
                        (* link the last new cell to the new cell *)
                        LastNewCell^.NextCell := NewHandle;
                        IF (LockObject(NewHandle,NewCell) = TSIZE(AnAvailabilityCell)) THEN
                            (* link the new cell to the last new cell *)
                            NewCell^.PrevCell := LastNewHandle;
                            NewCell^.NextCell := Target; 
                        ELSE
                            FatalError;
                        END;
                        ReleaseObject(NewHandle);   
                        NewCell := NIL;
                    ELSE 
                        FatalError;
                    END;
                    ReleaseObject(LastNewHandle);   
                    LastNewCell := NIL; 
                END;
            ELSE
                Okay := FALSE;
            END;
        ELSE
            FatalError;
        END;
        ReleaseUnchangedObject(CellHandle);   
        Cell := NIL;
        LastNewHandle := NewHandle;           (* Lagging handle. *)
        CellHandle    := NextHandle;
    UNTIL ( CellHandle = Source ) OR ( NOT Okay ) ;
                
    IF Okay THEN
        IF (LockObject(Target,Cell) = TSIZE(AnAvailabilityCell)) THEN
            (* link the very last cell with the head cell *)
            IF (OnlyOne) THEN
                Cell^.NextCell := Target;
                Cell^.PrevCell := Target;
            ELSE
                Cell^.PrevCell := LastNewHandle;
            END;
        ELSE
            FatalError;
        END;
        ReleaseObject(Target);   
        Cell := NIL;
    END;
    
    IF (NOT Okay) THEN
        DisposeResAvailabilities(Target);
        Target := AnExtHandle(NIL);
    END;
    RETURN Okay;			

END CopyResAvailabilities;




(* Allocate a new cell *)

PROCEDURE CreateNewCell() : AnExtHandle;
                            
VAR
    CellHandle : AnExtHandle;

BEGIN   
    IF NOT CreateExtObjectWithSize(CellHandle, ExtMedium, 
                TSIZE(AnAvailabilityCell)) THEN 
        RETURN AnExtHandle(NIL);
    END; 
    RETURN CellHandle;

END CreateNewCell;







    (* Search forward through availability cells starting at StartCellHandle
       until we find the cell containing Date (i.e.,
       cell StartDate <= Date < cell EndDate). 
       If no such cell is located, the return value is AnExtHandle(NIL).    
    *)

PROCEDURE CellContainingDate (StartCellHandle: AnExtHandle;
                              Date           : ADate       ) : AnExtHandle;
VAR
    Cell           : AnAvailabilityCellPointer;
    CellHandle     : AnExtHandle;
    NextCellHandle : AnExtHandle;
    First          : BOOLEAN;
BEGIN
    CellHandle := StartCellHandle;
    First := TRUE;
    LOOP
        IF CellHandle = AnExtHandle(NIL) THEN
            RETURN CellHandle;
        END;

        IF (LockObject(CellHandle,Cell) = TSIZE(AnAvailabilityCell)) THEN
            IF (Cell^.IsHeadCell) THEN
                IF (NOT First) THEN
                    ReleaseUnchangedObject(CellHandle);
                    Cell := NIL;
                    RETURN AnExtHandle(NIL);
                END;
            ELSIF (Date >= Cell^.StartDate) AND (Date < Cell^.EndDate) THEN    
                ReleaseUnchangedObject(CellHandle);
                Cell := NIL;
                RETURN(CellHandle);
            END;
            NextCellHandle := Cell^.NextCell;
            ReleaseUnchangedObject(CellHandle);        
            Cell := NIL;
            CellHandle := NextCellHandle;
        ELSE
            FatalError;
        END;
        First := FALSE;
    END;
END CellContainingDate;



    (* Search backward through availability cells starting at StartCellHandle
       until we find the cell such that
       cell StartDate < Date <= cell EndDate. (Notice
       that, unlike with the procedure CellContainingDate,
       this is not necessarily the cell that actually contains
       the date. Specifically, we could find the cell whose
       end date is the given Date.)
       If no such cell is located, the return value is AnExtHandle(NIL).    
    *)

PROCEDURE BackCellContainingDate (StartCellHandle: AnExtHandle;
                                  Date           : ADate       ) 
                                                       : AnExtHandle;
VAR
    Cell           : AnAvailabilityCellPointer;
    CellHandle     : AnExtHandle;
    PrevCellHandle : AnExtHandle;
    First          : BOOLEAN;
BEGIN
    CellHandle := StartCellHandle;
    First := TRUE;
    LOOP
        IF CellHandle = AnExtHandle(NIL) THEN
            RETURN CellHandle;
        END;

        IF (LockObject(CellHandle,Cell) = TSIZE(AnAvailabilityCell)) THEN
            IF (Cell^.IsHeadCell) THEN
                IF (NOT First) THEN
                    ReleaseUnchangedObject(CellHandle);
                    Cell := NIL;
                    RETURN AnExtHandle(NIL);
                END;
            ELSIF (Date > Cell^.StartDate) AND (Date <= Cell^.EndDate) THEN    
                ReleaseUnchangedObject(CellHandle);
                Cell := NIL;
                RETURN(CellHandle);
            END;
            PrevCellHandle := Cell^.PrevCell;
            ReleaseUnchangedObject(CellHandle);        
            Cell := NIL;
            CellHandle := PrevCellHandle;
        ELSE
            FatalError;
        END;
        First := FALSE;
    END;
END BackCellContainingDate;



END ResCal.
