IMPLEMENTATION MODULE NetCopy;


(*  =========================================================================
    Last Edit : July 8, 1991 5:02PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
    MODIFICATION HISTORY

        29-Nov-89 EGK   Added "ViewType" to the list of things saved in
                        the MiscRecord.  It needs to be preserved because
                        the overlays that initialize it are skipped when
                        we do a quick recall of the old PERT data.
         8-Jul-91 EGK   Call new procedure, RefreshDrawingMatrix, prior
                        to copying the elements of the MatrixBlock array.
                        This fixes bug #4706, which resulted from
                        SaveNetData using the un-refreshed matrix contents.
                        "Old data -- pay it no mind." -- C-3PO
    =========================================================================
*)


FROM AccessMatrix           IMPORT
    (* VAR *)                   MatrixBlock,
    (* PROC *)                  FreeDrawingMatrix, RefreshDrawingMatrix;

FROM BlockOps               IMPORT
    (* PROC *)                  BlockMove;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC *)                  CreateExtObjectWithSize, CopyExtObject,
                                GetExtStatus, LockObject,
                                ReleaseObject, ReleaseUnchangedObject;

FROM NetSave                IMPORT
    (* CONST *)                 ArrayMax,
    (* TYPE *)                  AnArrayPtr, ANetArray,
    (* VAR *)                   DataValid, NetSaveData, NetSaveArray,
    (* PROC *)                  DiscardData;

FROM NetStatic              IMPORT
    (* TYPE *)                  ATreeNodeArray, DiagramView,
    (* VAR *)                   Xpos, Ypos, Xmaxpos, Ymaxpos, Utility,
                                SnetRows, SnetCols, SnetRowOne, SnetColOne,
                                MatrixOverflow, HaveInfLoop, loopnode,
                                maxtask, ViewType;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE, SIZE;



TYPE
        (*  This structure allows storage of a small number of
            simple integers and boolean values, for miscellaneous
            PERT parameters.
        *)

    AMiscNetDataRecord      = RECORD
                                Integer     : ARRAY [0..9] OF INTEGER;
                                Boolean     : ARRAY [0..9] OF BOOLEAN;
                              END;


    (*  SaveNetObject -- make a copy of the data pointed by Where, and of
                         Size bytes, to the element of NetSaveData specified
                         by HandleNum.  Return success or failure as a
                         result.
    *)

PROCEDURE SaveNetObject (   HandleNum   : CARDINAL;
                            Where       : ADDRESS;
                            Size        : CARDINAL  ) : BOOLEAN;
VAR
    P           : ADDRESS;
    OK          : BOOLEAN;

BEGIN
    OK := (GetExtStatus() = ExtGood) AND
          (CreateExtObjectWithSize (NetSaveData[HandleNum], ExtSlow, Size));
    IF (OK) THEN
        IF (LockObject (NetSaveData[HandleNum], P) <> Size) THEN
            FatalError();
        END;
        BlockMove (P, Where, Size);
        ReleaseObject (NetSaveData[HandleNum]);
    END;
    RETURN OK;
END SaveNetObject;


    (*  NOTE:  If any new data is to be saved here in the future, then
               SaveNetData and GetNetData both need to be changed to load
               and save the new information (either as a new element of
               NetSaveData or as another field in the MiscRecord).

        The current storage scheme is as follows:

        NetSaveData[0]  stores   Xpos
                   [1]           Ypos
                   [2]           Xmaxpos
                   [3]           Ymaxpos
                   [4]           Utility
                   [5]           loopnode

                   [6]  stores   SnetRowOne, SnetColOne, SnetRows,
                                 SnetCols, MatrixOverflow, HaveInfLoop,
                                 and maxtask (as a record).

        NetSaveArray    stores   all the data currently allocated in
                                 MatrixBlock.
    *)

PROCEDURE SaveNetData () : BOOLEAN;
VAR
    i           : CARDINAL;
    MiscRecord  : AMiscNetDataRecord;
    OK          : BOOLEAN;
    ArrayPtr    : AnArrayPtr;

BEGIN
    IF (DataValid) THEN
        RETURN TRUE;
    END;

    OK := SaveNetObject (0, ADR(Xpos), SIZE(Xpos));
    OK := OK AND SaveNetObject (1, ADR(Ypos), SIZE(Ypos));
    OK := OK AND SaveNetObject (2, ADR(Xmaxpos), SIZE(Xmaxpos));
    OK := OK AND SaveNetObject (3, ADR(Ymaxpos), SIZE(Ymaxpos));
    OK := OK AND SaveNetObject (4, ADR(Utility), SIZE(Utility));
    OK := OK AND SaveNetObject (5, loopnode, TSIZE(ATreeNodeArray));

    MiscRecord.Integer[1] := SnetRowOne;
    MiscRecord.Integer[2] := SnetColOne;
    MiscRecord.Integer[3] := SnetRows;
    MiscRecord.Integer[4] := SnetCols;
    MiscRecord.Integer[5] := maxtask;
    MiscRecord.Integer[6] := ORD(ViewType);
    MiscRecord.Boolean[1] := MatrixOverflow;
    MiscRecord.Boolean[2] := HaveInfLoop;

    OK := OK AND SaveNetObject (6, ADR(MiscRecord), SIZE(MiscRecord));

    RefreshDrawingMatrix();     (* 7/8/91 EGK *)

    IF (OK) THEN
        OK := (GetExtStatus() = ExtGood) AND
              (CreateExtObjectWithSize (NetSaveArray, ExtSlow, TSIZE(ANetArray)));
        IF (OK) THEN
            IF (LockObject (NetSaveArray, ArrayPtr) = 0) THEN
                FatalError();
            END;
            FOR i := 0 TO HIGH(MatrixBlock^) DO
                ArrayPtr^[i] := AnExtHandle(NIL);
                IF (MatrixBlock^[i] <> AnExtHandle(NIL)) THEN
                    OK := OK AND (GetExtStatus() = ExtGood) AND
                          (CopyExtObject (MatrixBlock^[i], ExtSlow, ArrayPtr^[i]));
                END;
            END;
            FOR i := HIGH(MatrixBlock^)+1 TO ArrayMax DO
                ArrayPtr^[i] := AnExtHandle(NIL);
            END;
            ReleaseObject (NetSaveArray);
        END;
    END;

    IF (NOT OK) THEN
        DiscardData();
    END;

    DataValid := OK;

    RETURN OK;

END SaveNetData;



PROCEDURE GetNetObject (    HandleNum   : CARDINAL;
                            Where       : ADDRESS;
                            Size        : CARDINAL  );
VAR
    P           : ADDRESS;
BEGIN
    IF (LockObject (NetSaveData[HandleNum], P) <> Size) THEN
        FatalError();
    END;
    BlockMove (Where, P, Size);
    ReleaseUnchangedObject (NetSaveData[HandleNum]);
END GetNetObject;



PROCEDURE GetNetData () : BOOLEAN;

VAR
    OK          : BOOLEAN;
    i           : CARDINAL;
    MiscRecord  : AMiscNetDataRecord;
    ArrayPtr    : AnArrayPtr;

BEGIN
    IF (NOT DataValid) THEN
        RETURN FALSE;
    END;

    GetNetObject (0, ADR(Xpos), SIZE(Xpos));
    GetNetObject (1, ADR(Ypos), SIZE(Ypos));
    GetNetObject (2, ADR(Xmaxpos), SIZE(Xmaxpos));
    GetNetObject (3, ADR(Ymaxpos), SIZE(Ymaxpos));
    GetNetObject (4, ADR(Utility), SIZE(Utility));
    GetNetObject (5, loopnode, TSIZE(ATreeNodeArray));
    GetNetObject (6, ADR(MiscRecord), SIZE(MiscRecord));

    SnetRowOne      := MiscRecord.Integer[1];
    SnetColOne      := MiscRecord.Integer[2];
    SnetRows        := MiscRecord.Integer[3];
    SnetCols        := MiscRecord.Integer[4];
    maxtask         := MiscRecord.Integer[5];
    ViewType        := VAL(DiagramView,MiscRecord.Integer[6]);
    MatrixOverflow  := MiscRecord.Boolean[1];
    HaveInfLoop     := MiscRecord.Boolean[2];

    FreeDrawingMatrix();

    OK := TRUE;

    IF (LockObject (NetSaveArray, ArrayPtr) = 0) THEN
        FatalError();
    END;
    FOR i := 0 TO HIGH(MatrixBlock^) DO
        IF (ArrayPtr^[i] <> AnExtHandle(NIL)) THEN
            OK := OK AND (GetExtStatus() = ExtGood) AND
                  (CopyExtObject (ArrayPtr^[i], ExtSlow, MatrixBlock^[i]));
        END;
    END;
    ReleaseUnchangedObject (NetSaveArray);

    IF (NOT OK) THEN
        FreeDrawingMatrix();
    END;

    RETURN OK;

END GetNetData;



BEGIN
END NetCopy.
