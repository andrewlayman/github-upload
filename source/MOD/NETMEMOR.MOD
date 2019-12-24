IMPLEMENTATION MODULE NetMemory;

    (*  MODIFICATION HISTORY
        14-Mar-88 LAA   Changed amount of memory reserved for phantoms since
                        the netview overlay is now in reserved layer.
        16-Aug-89 EGK   Import ALLOCATE from Space instead of Storage.
                        Removed other unused imports.
        19-Sep-89 EGK   Import matrix constants and types from AccessMatrix
                        instead of NetStatic and our own DEF.
    *)
 
FROM AccessMatrix           IMPORT
    (* CONST *)                 BlockCount,
    (* TYPE *)                  AMatrixBlockArray,
    (* VAR *)                   MatrixBlock,
    (* PROC *)                  FreeDrawingMatrix;

(* DEBUGGING
FROM ErrorUtil    IMPORT   PrintMsg,PrintCard,PrintTask,
                           PrintSMsg,PrintSCard,PrintSTask;
 DEBUGGING *)
 
FROM FlexStor               IMPORT 
    (* PROC *)                  AnExtHandle;   (* 02-MAY-89 CMH !!! *)

FROM NetStatic              IMPORT 
    (* CONST *)                 DimHeight,
    (* TYPE *)                  AHeightArray, AWidthArray, ATreeNodeArray,
    (* VAR *)                   loopnode, SnetHeight, SnetWidth, 
                                EnoughMemory;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;
   
FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE, ADR;


TYPE
    AContext                = RECORD
                                CNodes      : CARDINAL;
                                CEdges      : CARDINAL;
                              END;

PROCEDURE AllocNetMemory();

VAR
    i : CARDINAL;
  
BEGIN
 
    SnetWidth := NIL;
    SnetHeight := NIL;
    MatrixBlock := NIL; (* 02-MAY-89 CMH !!! *)
    loopnode  := NIL;

    EnoughMemory := FALSE;
    IF Available(TSIZE(ATreeNodeArray)) THEN
        ALLOCATE(loopnode,TSIZE(ATreeNodeArray));
        IF Available(TSIZE(AWidthArray)) THEN
            ALLOCATE(SnetWidth,TSIZE(AWidthArray));
            IF Available(TSIZE(AHeightArray)) THEN
                ALLOCATE(SnetHeight,TSIZE(AHeightArray));
                IF Available(TSIZE(AMatrixBlockArray)) THEN
                   ALLOCATE(MatrixBlock,TSIZE(AMatrixBlockArray));
                   FOR i := 0 TO BlockCount-1 DO
                       MatrixBlock^[i] := AnExtHandle(NIL);
                   END;
                   EnoughMemory := TRUE;
                END;
            END;
        END;
    END;

    IF (NOT EnoughMemory) THEN
        DeAllocNetMemory();
    END;
  
END AllocNetMemory; 
   
   
   
PROCEDURE DeAllocNetMemory();

VAR
    i           : CARDINAL;

BEGIN

    IF (SnetWidth <> NIL) THEN
        DEALLOCATE(SnetWidth,TSIZE(AWidthArray));
    END;

    IF (SnetHeight <> NIL) THEN
        DEALLOCATE(SnetHeight,TSIZE(AHeightArray));
    END;
    
    IF (MatrixBlock <> NIL) THEN
        FreeDrawingMatrix();  (* discard the flexstor buffers *)
        DEALLOCATE(MatrixBlock,TSIZE(AMatrixBlockArray));
    END;

    IF (loopnode <> NIL) THEN
        DEALLOCATE(loopnode,TSIZE(ATreeNodeArray));
    END;

END DeAllocNetMemory; 
   
   
BEGIN                       (* NetMemory *)

    loopnode := NIL;
    SnetHeight := NIL;
    SnetWidth := NIL;
    MatrixBlock := NIL;

END NetMemory.
