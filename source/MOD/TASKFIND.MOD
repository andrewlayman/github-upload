IMPLEMENTATION MODULE TaskFind;

    (*  MODIFICATION HISTORY
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        19-Jun-89 RSC   Speed improvements for LAZLO.  This module is used
                        while reading in Edges in TLITL3/TLITL4.

                        This module provides a way to lookup any task with
                        a POSITIVE Task ID field by ID # and returns the
                        task's tree node.  It uses "ErrorFlag" from
                        LoadCommon to communicate status.

                        Improvements include:

                            - Use ReleaseUnchangedObject where possible
                              (was using ReleaseObject).
                            - Sort each block, and use a binary search on
                              it.
                            - Make all arrays 1-based, not 0-based (this is
                              not strictly an improvment, but reflects my
                              recent bias away from 0 based arrays).
        22-Jun-89 RSC   Allow nested begin/end calls, where the additional
                        begins/ends are NO-OPS.  Extra Ends are ok.
        21-Jan-91 RSC   Keep one buffer locked as a cheap cache.
        26-Jul-91 PFG   The AddInOrder proc didn't work in the case where
                        tasks weren't already in the right order.  We don't
                        run into this unless there's something wrong with
                        the schedule file, as was the case with files created
                        by the On Target importer, but since the code was
                        intended to work no matter what order they came in, 
                        I thought I'd fix it.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* VAR *)                   TaskTree,
    (* PROC *)                  CheckTaskValid;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CreateExtObjectWithSize, ReleaseObject,
                                LockObjectArray, DiscardExtObject,
                                ReleaseUnchangedObject, LockObject;

FROM LoadCommon             IMPORT
    (* TYPE *)                  ErrorFlag;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;


CONST
    MaxItem         = 512;      (* This many tasks in one buffer *)
    MaxBuf          = 65;       (* Maximum number of buffers *)
    MAXINT          = 32767;    (* HIGH VALUE for an INTEGER. *)

TYPE
    ALookupRecord   = RECORD
                        TaskNode    : ATreeNode;
                        ID          : INTEGER;
                      END;

    ATaskArray      = ARRAY [1..MaxItem] OF ALookupRecord;

    ATaskArrayPtr   = POINTER TO ATaskArray;

VAR
    NestingLevel    : CARDINAL;
    BufferNo        : CARDINAL;
    ElementNo       : CARDINAL;
    MaxBufInUse     : CARDINAL;
    TaskArray       : ATaskArrayPtr;
    BufferHandle    : ARRAY [1..MaxBuf] OF AnExtHandle;
    BufferLow       : ARRAY [1..MaxBuf] OF INTEGER;
    BufferHigh      : ARRAY [1..MaxBuf] OF INTEGER;

    TaskArrayIndex  : CARDINAL;  (* Into BufferHandle *)
    TaskArrayLocked : BOOLEAN;
    BufferDirty     : BOOLEAN;




PROCEDURE GainAccessToBuffer( Which : CARDINAL );
BEGIN
    IF (TaskArrayLocked) AND (TaskArrayIndex <> Which) THEN
        IF (BufferDirty) THEN
            ReleaseObject(BufferHandle[ TaskArrayIndex ]);
        ELSE
            ReleaseUnchangedObject(BufferHandle[ TaskArrayIndex ]);
        END;
        TaskArrayLocked := FALSE;
        BufferDirty     := FALSE;
    END;

    IF (NOT TaskArrayLocked) THEN
        IF (LockObject(BufferHandle[ Which ], TaskArray) < TSIZE(ATaskArray)) THEN
            FatalError();
        ELSE
            TaskArrayIndex  := Which;
            TaskArrayLocked := TRUE;
        END;
    END;

END GainAccessToBuffer;




(* NextBuffer

    Create and lock a new buffer full of task stuff.
    If there was an old buffer locked, unlock it.
*)
PROCEDURE NextBuffer( VAR BufferNo    : CARDINAL );
VAR
    i   : CARDINAL;
BEGIN
    IF (BufferNo > 0) THEN
        ReleaseObject (BufferHandle[BufferNo]);  (* You're filled up! *)
        TaskArrayLocked := FALSE;
    END;

    INC (BufferNo);

    IF (BufferNo > MaxBuf) THEN
        FatalError();   (* Too many buffers. *)
    END;

    (* Lock down a new buffer *)

    IF (CreateExtObjectWithSize(BufferHandle[BufferNo], ExtMedium, TSIZE(ATaskArray))) AND
       (LockObject(BufferHandle[BufferNo], TaskArray) >= TSIZE(ATaskArray)) THEN
        TaskArrayIndex  := BufferNo;
        TaskArrayLocked := TRUE;
        BufferDirty     := TRUE;
        FOR i := 1 TO MaxItem DO
            TaskArray^[i].ID := MAXINT;
        END;
    ELSE
        ErrorFlag := TRUE;
    END;

    MaxBufInUse := BufferNo;

END NextBuffer;








    (* Call this to add one task with it's ID and TreeNode.
       This is done here to avoid TaskFindBegin having to traverse the
       task tree.

       Do this AFTER TaskFindBegin!

       24-Jan-91 RSC
    *)
PROCEDURE AddTaskByNumber  ( ID    : INTEGER; Node : ATreeNode );
VAR
    LookupRecord        : ALookupRecord;
    LastID              : INTEGER;


    PROCEDURE AddInOrder( NewID, HighestID : INTEGER );
    VAR
        NewPosition,
        Loop                    : CARDINAL;
    BEGIN

        (* Since most likely the tasks are in numerical order,
           This new node most likely goes at the end.
        *)
        IF (NewID >= HighestID) THEN
            TaskArray^[ElementNo] := LookupRecord;
        END;

        (* Otherwise, find where it goes, bump everyone else out of the way,
           and insert our item.  I don't expect this to happen vary often.
        *)
        NewPosition := 1;
        WHILE (NewPosition < ElementNo)             AND
              (TaskArray^[NewPosition].ID < NewID)  DO
            INC(NewPosition);
        END;

        (*  The old code went through the array in forward order clobbering
            each element in the array as it put the new value in!  *)

        FOR Loop := ElementNo TO NewPosition+1 BY -1 DO
            TaskArray^[Loop] := TaskArray^[Loop-1];
        END;

        TaskArray^[NewPosition] := LookupRecord;

    END AddInOrder;



    PROCEDURE TrackHighestAndLowest(    ID       : INTEGER;
                                        BufferNo : CARDINAL );
    BEGIN
        IF (ID > BufferHigh[BufferNo]) THEN
            BufferHigh[BufferNo] := ID;
        END;
        IF (ID < BufferLow[BufferNo]) THEN
            BufferLow[BufferNo] := ID;
        END;
    END TrackHighestAndLowest;



BEGIN
    IF (ElementNo >= MaxItem) THEN
        NextBuffer(BufferNo);
        ElementNo := 0;
    END;

    IF (ErrorFlag) THEN
        RETURN;
    END;

    LookupRecord.TaskNode := Node;
    LookupRecord.ID       := ID;

    IF (ID >= MAXINT) OR (ID < 0) THEN
        FatalError();   (* MAXINT is reserved for HIGH VALUES. *)
    END;

    (* For File/Combine, Negative ID's are not to be found, and so this
       may speed up combine speed a little.
    *)
    INC(ElementNo);
    LastID := ID;
    IF (ElementNo > 1) THEN
        LastID := TaskArray^[ElementNo - 1].ID;
    END;
    TrackHighestAndLowest( ID, BufferNo );
    AddInOrder( ID, LastID );
    BufferDirty := TRUE;

END AddTaskByNumber;







PROCEDURE TaskFindBegin();
VAR
    i       : CARDINAL;
BEGIN
    IF (NestingLevel = 0) THEN
        FOR i := 1 TO MaxBuf DO  (* Seed these so they get set later *)
            BufferHigh[i]   := 0;
            BufferLow[i]    := MAXINT;
            BufferHandle[i] := AnExtHandle(NIL);
        END;

        BufferNo    := 0;
        ElementNo   := MaxItem;  (* Seed the purchasing of FlexStor buffers *)
        MaxBufInUse := 0;
    END;

    INC(NestingLevel);

END TaskFindBegin;









PROCEDURE TaskFindEnd();
VAR
    i           : CARDINAL;
BEGIN
    IF (TaskArrayLocked) THEN
        ReleaseObject (BufferHandle[TaskArrayIndex]);
        TaskArrayLocked := FALSE;
    END;

    IF (NestingLevel = 1) THEN
        FOR i := 1 TO MaxBufInUse DO
            DiscardExtObject (BufferHandle[i]);
        END;
        MaxBufInUse  := 0;
    END;

    IF (NestingLevel > 0) THEN  (* Too many ENDS are OK! RSC 22-Jun-89 *)
        DEC(NestingLevel);
    END;

END TaskFindEnd;





TYPE
    AComparison          = (LessThan, Equal, GreaterThan);

    (* A Search Compare Proc is used by Search to determine how an entry
       in a table relates to the given index.  Passed is a CARDINAL within
       the bounds of the table (table bounds are 1..UserSpecifiedHighValue)
       and another cardinal as the record or key to compare to.  Returned is
       how the record compares.
    *)
    ASearchCompareProc   = PROCEDURE( CARDINAL,
                                      INTEGER   ) : AComparison;




    (* SearchList -- Search a sorted table for a record with a key.
            Do a binary search.

         Preconditions:  Entries are in sorted order.
                         Compare : Passed procedure to do test.
                         Context : Passed intact to "Compare".
                         Last    : High value of list.

         Postconditions: Last    : Entry item was found at, or
                                   Entry JUST LESS THAN value.
                         RETURN is TRUE if found, FALSE if Last > value.


        This code comes to us courtesy of MsgFile.Mod.
    *)
PROCEDURE SearchList( Compare : ASearchCompareProc;
                      Context : INTEGER;
                  VAR Last    : CARDINAL ): BOOLEAN;
VAR
    LowBound,
    Target   : CARDINAL;
BEGIN
    LowBound := 1;

    REPEAT
        Target := (LowBound + Last) DIV 2;

        CASE Compare( Target, Context ) OF
          LessThan    : Last     := Target - 1;
        | Equal       : Last     := Target;
                        RETURN TRUE;           (* Found! *)
        | GreaterThan : LowBound := Target + 1;
        ELSE
            FatalError(); (* New comparison type? *)
        END;
    UNTIL (LowBound > Last);

    RETURN FALSE;

END SearchList;






PROCEDURE CompareProc(     CompareThisEntry : CARDINAL;
                           WithThisID       : INTEGER ) : AComparison;
VAR
    CompareID : INTEGER;
BEGIN
    CompareID := TaskArray^[CompareThisEntry].ID;

    IF (WithThisID > CompareID) THEN
        RETURN GreaterThan;
    ELSIF (WithThisID < CompareID) THEN
        RETURN LessThan;
    ELSE
        RETURN Equal;
    END;

END CompareProc;








(*  Search through as many buffers as necessary to find the ID
*)
PROCEDURE FindTaskByNumber(    ID    : INTEGER ) : ATreeNode;
VAR
    Last,
    i       : CARDINAL;
    Result  : ATreeNode;
BEGIN
    Result := ATreeNode(NIL);
    i      := 1;
    WHILE (i <= MaxBufInUse) AND (Result = ATreeNode(NIL)) DO
        IF (ID >= BufferLow[i]) AND (ID <= BufferHigh[i]) THEN

            GainAccessToBuffer( i );

            Last := MaxItem;
            IF (SearchList( CompareProc, ID, Last )) THEN
                Result := TaskArray^[Last].TaskNode;
            END;
        END;
        INC(i);
    END;

    RETURN Result;

END FindTaskByNumber;













BEGIN
    MaxBufInUse     := 0;
    NestingLevel    := 0;
    TaskArrayLocked := FALSE;
END TaskFind.
