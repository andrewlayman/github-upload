IMPLEMENTATION MODULE AccessMatrix;

    (*  MODIFICATION HISTORY
        20-Oct-88 CMH   New module for modified GetCell, and new SetCell
                        and GetCellInfo procedures, for the new character
                        (smaller) drawing matrix (SnetMatrix) scheme.
        03-May-89 CMH   Changed GetCell, GetCellInfo, Setcell to use a
                        flexstore drawing matrix.
        08-Jun-89 EGK   Fixed bug in FreeDrawingMatrix where it was
                        discarding objects if they WERE nil, instead of
                        if they weren't.
        02-Aug-89 EGK   Changed everything.  Elements of MatrixHeight^ are
                        now handles to blocks, where a block is a
                        rectangular portion of the matrix.
        18-Aug-89 CMH   Turned off the compiler optimization.
        21-Aug-89 RSC   Check ExtStatus before allocating a flex block.
        19-Sep-89 EGK   Changed SetCell to just set FatalNetError if it can't
                        create another block (rather than calling FatalError).
        26-Nov-89 EGK   Have GetCellInfo call FatalError if it can't match
                        the contents of the matrix with the Xpos and Ypos
                        values (instead of looping forever).

        30-Jan-91 RSC   Added the cache for the MatrixBlock.
        19-Mar-91 RSC   Sometimes flushing the cache failed in
                        "FreeDrawingMatrix".
         8-Jul-91 EGK   Added RefreshDrawingMatrix procedure to allow
                        the private cache to be flushed.
     *)

FROM BlockOps               IMPORT
    (* PROC *)                  BlockSet;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC *)                  CreateExtObjectWithSize,
                                DiscardExtObject,   GetExtStatus,
                                LockObject, ReleaseObject,
                                ReleaseUnchangedObject;

FROM NetStatic              IMPORT
    (* CONST *)                 DimHeight, taskdim, DimWidth,
    (* VAR *)                   loopnode, MatrixOverflow, FatalNetError,
                                Xpos, Ypos;

FROM SYSTEM                 IMPORT
    (* CONST *)                 CX,
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE, CODE, SETREG;


TYPE
    ABlock              = ARRAY [0..BlockSize-1] OF CHAR;
    ABlockPtr           = POINTER TO ABlock;






MODULE Cache;                   (* 30-Jan-91 RSC  *)


    (* The Cache module is an attempt to speed up Pert topology by
       lowering the number of flexstor calls made and subsequent
       flexstor thrashing by reducing the locks of the MatrixBlock
       items.

       In one 540 task schedule, the tasks were locked 49,603 times
       and the MatrixBlock were locked 47,121 times.
    *)

IMPORT
    (* CONST *)     CX,
    (* TYPE *)      ABlock, ABlockPtr, AnExtHandle, ADDRESS,
    (* PROC *)      ADR, SETREG, CODE, TSIZE,
                    LockObject, ReleaseObject, ReleaseUnchangedObject,
                    FatalError;

EXPORT
    (* PROC *)      LockBlock;


VAR
    BlockCache          : ABlock;
    BlockCacheHandle    : AnExtHandle;
    BlockCacheDirty     : BOOLEAN;



PROCEDURE MoveBlock ( src, dest : ADDRESS; count: CARDINAL);
CONST
    REPNZ   = 0F2H;
    MOVSB   = 0A4H;
    LDS     = 0C5H;
    LES     = 0C4H;
    SIviaBP = 76H;
    DIviaBP = 7EH;

BEGIN
    CODE (LDS, SIviaBP,10);
    CODE (LES, DIviaBP,6);
    SETREG (CX, count);
    CODE (REPNZ, MOVSB);
END MoveBlock;





(* Lock the block indicated by "Handle".  Return the BlockPtr.

   If the passed handle is NIL, this has the effect of flushing any
   cached writes.  In this case, BlockPtr is undefined.
*)
PROCEDURE LockBlock(     Handle    : AnExtHandle;
                     VAR BlockPtr  : ABlockPtr;
                         ForUpdate : BOOLEAN );
VAR
    RemoteBlockPtr  : ADDRESS;
BEGIN
    BlockPtr := ADR(BlockCache);

    IF (Handle <> BlockCacheHandle) THEN
        IF (BlockCacheHandle <> AnExtHandle(NIL)) AND
           (BlockCacheDirty) THEN
            IF (LockObject(BlockCacheHandle, RemoteBlockPtr) = 0) THEN
                FatalError();
            ELSE
                MoveBlock( BlockPtr, RemoteBlockPtr, TSIZE(ABlock) );
                ReleaseObject(BlockCacheHandle);
            END;
            BlockCacheDirty := FALSE;
        END;
        IF (Handle <> AnExtHandle(NIL)) THEN
            IF (LockObject(Handle, RemoteBlockPtr) = 0) THEN
                FatalError();
            ELSE
                MoveBlock( RemoteBlockPtr, BlockPtr, TSIZE(ABlock) );
                ReleaseUnchangedObject(Handle);
            END;
        END;
        BlockCacheHandle := Handle;
    END;

    BlockCacheDirty  := (BlockCacheDirty OR ForUpdate);

END LockBlock;


BEGIN   (* MODULE CACHE *)

    BlockCacheHandle    := AnExtHandle(NIL);
    BlockCacheDirty     := FALSE;

END Cache;









    (*  GetBlockLocation -- given a row and column in the matrix, find
                            the block number (the index into MatrixBlock^)
                            and offset into that block (the index into the
                            appropriate BlockPtr^).
    *)

PROCEDURE GetBlockLocation  (   row,
                                col         : CARDINAL;
                            VAR BlockNum    : CARDINAL;
                            VAR BlockIndex  : CARDINAL  );
VAR
    BlockNumX,
    BlockNumY,
    BlockX,
    BlockY              : CARDINAL;

BEGIN

    BlockNumX := col DIV BlockWidth;
    BlockNumY := row DIV BlockHeight;
    BlockNum := BlockNumY * BlockCountX + BlockNumX;

    BlockX := col MOD BlockWidth;
    BlockY := row MOD BlockHeight;
    BlockIndex := BlockY * BlockWidth + BlockX;

END GetBlockLocation;



    (*  GetMatrixElement -- given a row and column in the matrix, return
                            the raw data value at that location.
    *)

PROCEDURE GetMatrixElement (    row, col : CARDINAL;
                            VAR Elem     : CARDINAL ) : BOOLEAN;
VAR
    BlockNum        : CARDINAL;
    BlockIndex      : CARDINAL;
    BlockPtr        : ABlockPtr;

BEGIN

 (* verify matrix row and column is in range *)

    IF ((col > DimWidth) OR (row > DimHeight)) THEN
        MatrixOverflow := TRUE;
        RETURN FALSE;
    END;

    GetBlockLocation (row, col, BlockNum, BlockIndex);

 (* be sure this block has a valid flexstore handle *)
    IF (MatrixBlock^[BlockNum] = AnExtHandle(NIL)) THEN
        RETURN FALSE;
    END;

 (* get the drawing character *)

    LockBlock( MatrixBlock^[BlockNum], BlockPtr, FALSE ); (* 30-Jan-91 RSC *)
    Elem := ORD(BlockPtr^[BlockIndex]);

    RETURN TRUE;

END GetMatrixElement;



(*--------------------------------------------------------------------------*)
        (*
            GetCell

            Accesses the internal matrix for an input row and
            column and returns the value found at that location.
         *)

PROCEDURE GetCell(row, col : CARDINAL) : INTEGER;        (* 13-Oct-88 CMH *)
                                                         (* 03-May-89 CMH *)
VAR
    CellValue : INTEGER;
    TempCard  : CARDINAL;

BEGIN

    IF (GetMatrixElement (row, col, TempCard)) THEN

        (* convert the drawing character to a task index or a special character *)
        CellValue := TempCard;
        CellValue := CellValue - MAXCHAR;
        IF (CellValue > 0) THEN
            CellValue := CellValue + TASKBANK - 1;
        END;
    ELSE
        CellValue := 0;
    END;

    RETURN CellValue;

END GetCell;


(*--------------------------------------------------------------------------*)
        (*
            GetCellInfo

            Accesses the internal matrix for an input row and
            column and returns the value found at that location.
            Task index is ready to use.
         *)


PROCEDURE GetCellInfo(row,col : CARDINAL) : INTEGER;     (* 13-Oct-88 CMH *)
                                                         (* 03-May-89 CMH *)
VAR
    CellValue    : INTEGER;
    TempCard     : CARDINAL;

BEGIN

    IF (GetMatrixElement (row, col, TempCard)) THEN

        (* convert the drawing character to a task index or a special character *)
        CellValue:= TempCard;
        CellValue:= CellValue - MAXCHAR;
        IF (CellValue > 0) THEN
            CellValue := CellValue-1;

         (* fix up loopnode task index *)
            IF (CellValue = 0) THEN
                CellValue := CellValue + TASKBANK;
            END;
            IF (CellValue > TASKBANK) THEN
                CellValue := CellValue - TASKBANK;
            END;
            WHILE ( (row<>ORD(Ypos[CellValue])) OR (col<>ORD(Xpos[CellValue]))) DO
               CellValue:=CellValue+TASKBANK;
               IF (CellValue > taskdim) THEN
                    FatalError();           (* 11/26/89 EGK *)
               END;
            END;

        END; (* if *)

    ELSE
        CellValue := 0;
    END;

    RETURN CellValue;

END GetCellInfo;


(*--------------------------------------------------------------------------*)
        (*
            SetCell
            Sets a value into the drawing matrix
         *)


PROCEDURE SetCell(row,col:CARDINAL;cell:INTEGER);        (* 13-Oct-88 CMH *)
                                                         (* 03-May-89 CMH *)
VAR
    NewBlockHandle  : AnExtHandle;
    BlockNum        : CARDINAL;
    BlockIndex      : CARDINAL;
    TempCard        : CARDINAL;
    BlockPtr        : ABlockPtr;
    okay            : BOOLEAN;
    TempChar        : CHAR;
BEGIN

 (* verify matrix row and column is in range *)
    IF ((col > DimWidth) OR (row > DimHeight)) THEN
         MatrixOverflow := TRUE;
         RETURN; (* out of range *)
    END;

 (* convert the task index into a representation for the character matrix *)
    IF (cell > 0) THEN
        cell := (cell MOD TASKBANK)+1;
    END;

    GetBlockLocation (row, col, BlockNum, BlockIndex);

 (* check to see if this block has been created yet *)

    IF (MatrixBlock^[BlockNum] = AnExtHandle(NIL)) THEN
     (* if not, allocate a new block *)
        okay := (GetExtStatus() = ExtGood) AND  (* 21-Aug-89 RSC *)
                (CreateExtObjectWithSize (NewBlockHandle,ExtSlow,BlockSize));
        IF (okay) THEN
            MatrixBlock^[BlockNum] := AnExtHandle(NewBlockHandle);
            LockBlock( MatrixBlock^[BlockNum], BlockPtr, TRUE ); (* 30-Jan-91 RSC *)
             (* clear the flexstore buffer *)
            TempChar:= CHR(MAXCHAR);
            BlockSet (BlockPtr, BlockSize, ADR(TempChar), TSIZE(CHAR));
        ELSE
            FatalNetError := TRUE;          (* 9/19/89 EGK *)
            RETURN;
        END;
    END;

 (* set the value into the drawing matrix *)

    LockBlock( MatrixBlock^[BlockNum], BlockPtr, TRUE ); (* 30-Jan-91 RSC *)
    BlockPtr^[BlockIndex] := VAL(CHAR,(cell+MAXCHAR));

END SetCell;


(*--------------------------------------------------------------------------*)
        (*
            MoveMatrixCols
            Opens up a column in the drawing matrix to insert
            a new column
         *)


PROCEDURE MoveMatrixCols(col1, col2, row : INTEGER);

VAR
    irow, icol  : CARDINAL;
    cell        : INTEGER;
    BlockNumY   : CARDINAL;
    RowsInUse   : CARDINAL;

BEGIN

    BlockNumY := BlockCountY - 1;
    WHILE (MatrixBlock^[BlockNumY * BlockCountX] = AnExtHandle(NIL)) DO
        DEC (BlockNumY);
    END;
    RowsInUse := (BlockNumY + 1) * BlockHeight;

    FOR irow := 0 TO row  DO
        IF (irow < RowsInUse) THEN
            FOR icol := col2 TO col1 + 1 BY -1  DO
                IF (icol < DimWidth) THEN
                    cell := GetCell (irow, icol-1);
                    SetCell (irow, icol, cell);
                END;
            END;
            SetCell (irow, col1, 0);
        END;
    END; (* for *)

END MoveMatrixCols;


(*--------------------------------------------------------------------------*)
        (*
            MoveMatrixRows
            Opens up a row in the drawing matrix to insert
            a new row
         *)

PROCEDURE MoveMatrixRows(row1, row2 : INTEGER);

VAR
    BlockNumX           : CARDINAL;
    ColsInUse           : CARDINAL;
    irow, col           : CARDINAL;
    cell                : INTEGER;
BEGIN

    BlockNumX := BlockCountX - 1;
    WHILE (MatrixBlock^[BlockNumX] = AnExtHandle(NIL)) DO
        DEC (BlockNumX);
    END;
    ColsInUse := (BlockNumX + 1) * BlockWidth;

    FOR irow := row2 TO row1+1 BY -1  DO
        IF (irow < DimHeight) THEN
            FOR col := 0 TO ColsInUse-1 DO
                cell := GetCell (irow-1, col);
                SetCell (irow, col, cell);
            END;
        END;
    END;

    FOR col := 0 TO ColsInUse-1 DO
        SetCell (row1, col, 0);
    END;

END MoveMatrixRows;


(*--------------------------------------------------------------------------*)
        (*
            ClearDrawingMatrix

            Clears the flexstore buffers used for the drawing
            matrix.
         *)


PROCEDURE ClearDrawingMatrix();                          (* 11-May-89 CMH *)
VAR
    i           : CARDINAL;
    BlockPtr    : ABlockPtr;
    TempChar    : CHAR;
BEGIN

    TempChar:= CHR(MAXCHAR);
    FOR i := 0 TO BlockCount-1 DO
        IF (MatrixBlock^[i] <> AnExtHandle(NIL)) THEN
            LockBlock( MatrixBlock^[i], BlockPtr, TRUE ); (* 30-Jan-91 RSC *)
             (* clear the flexstore buffer *)
            BlockSet(BlockPtr, BlockSize, ADR(TempChar), TSIZE(CHAR));
        END;
    END;

END ClearDrawingMatrix;


(*--------------------------------------------------------------------------*)
        (*
            FreeDrawingMatrix

            Release the flexstore buffers used for the drawing
            matrix.
         *)


PROCEDURE FreeDrawingMatrix();                          (* 03-May-89 CMH *)

VAR
    BlockPtr    : ABlockPtr;
    i           : CARDINAL;

BEGIN

        (* Flush the cache
        *)
    LockBlock( AnExtHandle(NIL), BlockPtr, FALSE ); (* 19-Mar-91 RSC  *)

    FOR i := 0 TO BlockCount-1 DO
        IF (MatrixBlock^[i] <> AnExtHandle(NIL)) THEN      (* 6/8/89 EGK *)
            DiscardExtObject(MatrixBlock^[i]);
        END;
    END;

END FreeDrawingMatrix;



(*----------------------------------------------------------------------------
          RefreshDrawingMatrix() --

          Update the drawing matrix by flushing the private cache.
          This should be called prior to any direct access to the
          MatrixBlock elements without going through GetCell or
          GetCellInfo.
----------------------------------------------------------------------------*)

PROCEDURE RefreshDrawingMatrix();
VAR
    BlockPtr    : ABlockPtr;

BEGIN

    LockBlock( AnExtHandle(NIL), BlockPtr, FALSE );

END RefreshDrawingMatrix;




(*--------------------------------------------------------------------------*)
BEGIN                       (* AccessMatrix *)

END AccessMatrix.
