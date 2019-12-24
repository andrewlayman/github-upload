IMPLEMENTATION MODULE FormHand;

    (* Modification History:

       10-Jan-89 RSC    Changed Storage to Space    .

    *)



FROM Dialog     IMPORT FatalError;

FROM FormRead   IMPORT GetFormRecordByNumber;

FROM FormRec    IMPORT AFormRecord, AFormRecordPointer;

FROM Space      IMPORT ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM     IMPORT WORD, ADR, ADDRESS;


CONST
    ModuleNumber = 10000;

TYPE
    AFormHandle = POINTER TO AFormRecord;



PROCEDURE AllocateHandle( VAR FormHandle : AFormHandle ) : BOOLEAN;
BEGIN
    IF (HeapAvailable()) THEN
        NEW(FormHandle);
        IF (FormHandle <> NIL) THEN
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END AllocateHandle;



PROCEDURE AttachHandleToFormNumber( VAR FormHandle : AFormHandle;
                                        Number     : CARDINAL
                                    ) : BOOLEAN;
BEGIN
    IF (AllocateHandle(FormHandle)) THEN
        IF (GetFormRecordByNumber(Number,FormHandle^)) THEN
            RETURN TRUE;
        ELSE
            DISPOSE(FormHandle);
        END;
    END;
    RETURN FALSE;
END AttachHandleToFormNumber;




PROCEDURE AttachHandleToRecord    ( VAR FormHandle  : AFormHandle;
                                    VAR Record      : ARRAY OF WORD
                                    ) : BOOLEAN;
VAR
    AlternateRecord : AFormRecordPointer;
BEGIN
    IF (AllocateHandle(FormHandle)) THEN
        AlternateRecord := ADR(Record);
        FormHandle^ := AlternateRecord^;
        RETURN TRUE;
    END;
    RETURN FALSE;
END AttachHandleToRecord;




PROCEDURE DiscardFormHandle       ( VAR FormHandle  : AFormHandle );
BEGIN
    DISPOSE(FormHandle);
END DiscardFormHandle;




PROCEDURE GetAddressFromFormHandle( VAR FormHandle  : AFormHandle;
                                    VAR Address     : ADDRESS );
BEGIN
    Address := FormHandle;
END GetAddressFromFormHandle;




END FormHand.
