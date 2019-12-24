IMPLEMENTATION MODULE CorTable;

    (*  Modification History --
        10-Mar-92   LAA Initial version.  This module provides a correlation
                        table between CARDINAL Id's and tree nodes.  It's 
                        initial use is for the Rocky importer.
    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

TYPE
    ACorTable               = RECORD
                                Size        : CARDINAL;
                                Entries     : ARRAY [0..8000] OF ATreeNode;
                              END;

    ACorTablePointer        = POINTER TO ACorTable;

    ACorrelationTable       = ACorTablePointer;



    (*  CreateCorrelationTable --
        Create a new Correlation Table and return the hidden type pointer
        for it.  This will be returned as NIL if there's insufficient room
        to create a table of the indicated size.  Size is in terms of 
        number of entries.

        Preconditions:  None.

        Postconditions: Table created, or NIL returned.
    *)

PROCEDURE CreateCorrelationTable( TableSize : CARDINAL ) : ACorrelationTable;

VAR
    Allocation              : CARDINAL;
    i                       : CARDINAL;
    TablePtr                : ACorrelationTable;

BEGIN                       (* CreateCorrelationTable *)

    Allocation := (TableSize * TSIZE(ATreeNode)) + TSIZE(CARDINAL);
    TablePtr := NIL;
    IF (Available( Allocation )) THEN
        ALLOCATE( TablePtr, Allocation );
        WITH TablePtr^ DO
            Size := TableSize;
            FOR i := 0 TO Size - 1 DO
                Entries[i] := ATreeNode(NIL);
            END;
        END;
    END;

    RETURN TablePtr;

END CreateCorrelationTable;

    (*  DisposeCorrelationTable --
        Dispose of a previously created Correlation Table, freeing it's
        memory.

        Preconditions:  The table must have been created via a call to
                        CreateCorrelationTable, and not previously disposed.

        Postconditions: The Table handle will be returned NIL, and the 
                        memory for this table freed up.
    *)

PROCEDURE DisposeCorrelationTable( VAR Table    : ACorrelationTable );

VAR
    Allocation              : CARDINAL;

BEGIN                       (* DisposeCorrelationTable *)

    IF (Table <> NIL) THEN
        Allocation := (Table^.Size * TSIZE(ATreeNode)) + TSIZE(CARDINAL);
        DEALLOCATE( Table, Allocation );
        Table := NIL;
    END;

END DisposeCorrelationTable;



    (*  AddTableEntry --
        Add a new entry to an existing Correlation Table.  TRUE will be
        returned if the addition is successful, FALSE otherwise.

        Preconditions:  The table must have been created via a call to
                        CreateCorrelationTable, and not disposed of.

        Postconditions: The entry will be added to the table, or FALSE
                        will be returned.
    *)

PROCEDURE AddTableEntry(     Table          : ACorrelationTable;
                             Id             : CARDINAL;
                             Node           : ATreeNode         ) : BOOLEAN;

BEGIN                       (* AddTableEntry *)

    IF (Table = NIL) THEN FatalError(); END;
    IF ((Id < Table^.Size) AND (Table^.Entries[Id] = NIL)) THEN
        Table^.Entries[Id] := Node;
        RETURN TRUE;
    END;

    RETURN FALSE;

END AddTableEntry;



    (*  FindEntryByID --
        Find an entry in the table identified by Id.  If one exists, Node
        is updated with the associated tree node and TRUE are returned.  
        If none exists, FALSE is returned.

        Preconditions:  The table must have been created via a call to
                        CreateCorrelationTable, and not disposed of.

        Postconditions: None.
    *)

PROCEDURE FindEntryByID(     Table          : ACorrelationTable;
                             Id             : CARDINAL;
                         VAR Node           : ATreeNode          ) : BOOLEAN;

BEGIN                       (* FindEntryByID *)

    IF (Table = NIL) THEN FatalError(); END;
    IF (Id < Table^.Size) THEN
        Node := Table^.Entries[Id];
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END; 

END FindEntryByID;



    (*  FindEntryByNode --
        Find an entry in the table identified by Node.  If one exists, 
        update Id with the associated Id and return TRUE.  If no entry
        exists for this Node, return FALSE.

        Preconditions:  The table must have been created via a call to
                        CreateCorrelationTable, and not disposed of.

        Postconditions: None.
    *)

PROCEDURE FindEntryByNode(     Table        : ACorrelationTable;
                               Node         : ATreeNode;
                           VAR Id           : CARDINAL           ) : BOOLEAN;

VAR
    i                       : CARDINAL;

BEGIN                       (* FindEntryByNode *)

    IF (Table = NIL) THEN FatalError(); END;

    FOR i := 0 TO Table^.Size - 1 DO
        IF (Table^.Entries[i] = Node) THEN
            Id := i;
            RETURN TRUE;
        END;
    END;

    RETURN FALSE;

END FindEntryByNode;



    (*  ForAllEntries --
        Iterate through the table, calling the processing proc for each
        entry.  The Context is just passed from caller to the processing
        proc.

        Preconditions:  The table must have been created via a call to
                        CreateCorrelationTable, and not disposed of.

        Postconditions: None.
    *)

PROCEDURE ForAllEntries(     Table          : ACorrelationTable;
                             ProcessProc    : ACorrelationProc;
                             Context        : ADDRESS           );

VAR
    i                       : CARDINAL;

BEGIN                       (* ForAllEntries *)

    IF (Table = NIL) THEN FatalError(); END;

    FOR i := 0 TO Table^.Size - 1 DO
        IF (NOT ProcessProc( i, Table^.Entries[i], Context )) THEN
            RETURN;
        END;
    END;

END ForAllEntries;

BEGIN                       (* CorTable *)
END CorTable.

