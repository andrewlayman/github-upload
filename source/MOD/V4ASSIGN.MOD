IMPLEMENTATION MODULE V4Assignments;

(*  =========================================================================
    Last Edit : May 7, 1991 4:46PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

    This module maps version 3 and 4 assignment arrays from a schedule
    file into a version 4.5 assignment array.


    MODIFICATION HISTORY:

    27-Jul-90  RSC  First version.
    16-Aug-90  RSC  Loop count was one too big, causing fatal errors.
     7-May-91  RSC  Insure there are no duplicate assignments.

    =========================================================================
*)


FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentAttributeSet, AnAssignmentRecord,
                        AnAssignmentArray,
    (* PROC *)          InitAssignment, RemoveAssignmentsAndExpenses;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM FileSystem     IMPORT
    (* TYPE *)          File;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle, AnExtStoragePreference,
                        AnExtStatus,
    (* PROC *)          NumberOfElements, DiscardExtObject, ReleaseObject,
                        CreateExtObjectWithSize, LockObjectArray, ArraySize,
                        SetExtSize, GetExtStatus;

FROM RecordIO       IMPORT
    (* PROC *)          ReadRecordBody;

FROM RsrcMod        IMPORT
    (* TYPE *)          AResourcePointer,
    (* PROC *)          FindResourceByNumber;

FROM Space          IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* PROC *)          TSIZE;

FROM Timei          IMPORT
    (* TYPE *)          ADurationUnit;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;





TYPE
    AV4AssignmentRecord = RECORD
                       Resource        : AResourcePointer;
                       Attributes      : AnAssignmentAttributeSet;
                       MaxRatePercent  : CARDINAL;
                       PercentageEach  : CHAR; (* SMALLCARDINAL *)
                       ActualTimeUnits : ADurationUnit;
                       MaxRateUnits    : CARDINAL; (* TEMP USE IN PLANNER ONLY *)
                       Expenses        : AnExtHandle;
                       ActualQuantity  : REAL;
                       YetToGoQuantity : REAL;

    END;

    AV4AssignmentArray = POINTER TO ARRAY [0..1000] OF AV4AssignmentRecord;





PROCEDURE MapV4( VAR OldRec     : AV4AssignmentRecord;
                 VAR NewRec     : AnAssignmentRecord    ) : BOOLEAN;
VAR
    Node         : ATreeNode;
    Resource     : AResourcePointer;
    AddressTrick : RECORD
                       CASE BOOLEAN OF
                           TRUE :  P   : AResourcePointer;
                         | FALSE:  C   : RECORD
                                           A, B : CARDINAL;
                                         END;
                       END;
                   END;
BEGIN
    AddressTrick.P := OldRec.Resource;

    Node := FindResourceByNumber (AddressTrick.C.A);

    IF (Node <> NIL) THEN
        Resource := Node^.Methods^.GetDataObject (Node);

        InitAssignment( Resource, NewRec );

        WITH OldRec DO
            NewRec.Attributes      := Attributes;
            NewRec.MaxRatePercent  := MaxRatePercent;
            NewRec.PercentageEach  := PercentageEach;
            NewRec.ActualTimeUnits := ActualTimeUnits;
            NewRec.ActualQuantity  := ActualQuantity;
            NewRec.YetToGoQuantity := YetToGoQuantity;
        END;

    END;

    RETURN (Node <> NIL);

END MapV4;









PROCEDURE ReadV4AssignmentArray  (VAR f               : File;
                                      Length          : CARDINAL;
                                  VAR Handle          : AnExtHandle;
                                  VAR BadCount        : CARDINAL;
                                  VAR DuplicatesFound : BOOLEAN ) : BOOLEAN;
VAR
    AssignmentArray         : AnAssignmentArray;
    V4AssignmentArray       : AV4AssignmentArray;
    AssignmentCount         : CARDINAL;
    AssignmentSize          : CARDINAL;
    V4Index, V5Index        : CARDINAL;
    MapOK, Dup,
    ok                      : BOOLEAN;

        (* 7-May-91 RSC Added this code to detect dups.
        *)
    PROCEDURE DuplicateAssignment( V4AssignmentArray : AV4AssignmentArray;
                                   NewAddition       : CARDINAL;
                               VAR DuplicatesFound   : BOOLEAN
                                  ) : BOOLEAN;
    VAR
        Resource        : AResourcePointer;
        i               : CARDINAL;
        DuplicateFound  : BOOLEAN;
    BEGIN
(*$O-*)
        Resource := V4AssignmentArray^[NewAddition].Resource;
        i := 0;
        WHILE (i < NewAddition) AND
              (V4AssignmentArray^[i].Resource <> Resource) DO
            INC(i);
        END;
(*$O=*)

        DuplicateFound  := (i < NewAddition);
        DuplicatesFound := DuplicatesFound OR DuplicateFound;

        RETURN DuplicateFound;

    END DuplicateAssignment;

BEGIN

    (* Create a holder for the OLD record and read it.
    *)
    ok := (Available(Length));
    IF (NOT ok) THEN
        RETURN FALSE;
    END;

    ALLOCATE( V4AssignmentArray, Length );
    AssignmentSize  := Length;
    ReadRecordBody (f, Length, V4AssignmentArray, AssignmentSize);

    (* Compute NEW size *)
    AssignmentCount := NumberOfElements( Length,  TSIZE(AV4AssignmentRecord));
    AssignmentSize  := ArraySize( AssignmentCount, TSIZE(AnAssignmentRecord));

    (* Create the new record and lock IT down.
    *)
    IF (GetExtStatus() <> ExtGood) OR
       (NOT CreateExtObjectWithSize(Handle, ExtMedium, AssignmentSize)) THEN
        DEALLOCATE( V4AssignmentArray, Length );
        RETURN FALSE;
    END;

    AssignmentCount := LockObjectArray( Handle, AssignmentArray, TSIZE (AnAssignmentRecord));

    BadCount        := 0;
    DuplicatesFound := FALSE;
    V4Index         := 0;
    V5Index         := 0;
    WHILE (V4Index < AssignmentCount) DO
(*$O-*)
        MapOK := MapV4( V4AssignmentArray^[V4Index], AssignmentArray^[V5Index] );
        IF (MapOK) THEN
            Dup := DuplicateAssignment( V4AssignmentArray, V4Index, DuplicatesFound );
        ELSE
            INC(BadCount);
            Dup := FALSE;
        END;

        INC(V4Index);
        IF (MapOK AND (NOT Dup)) THEN
            INC(V5Index);
        END;
(*$O=*)
    END;

    DEALLOCATE( V4AssignmentArray, Length );
    ReleaseObject( Handle );

        (* Now, V4Index and V5Index are how many we have looked at
            V4Index is = AssignmentCount, V5Index is the number of VALID
            entries found.
        *)
    IF (V5Index = 0) THEN
        RemoveAssignmentsAndExpenses( Handle );
    ELSIF (V4Index <> V5Index) THEN
        ok := SetExtSize( Handle, ArraySize( V5Index, TSIZE(AnAssignmentRecord)));
    END;

    RETURN ok;

END ReadV4AssignmentArray;



END V4Assignments.
