IMPLEMENTATION MODULE Codes;

FROM Dialog  IMPORT FatalError;

    (* SetCodeBits *)

PROCEDURE SetCodeBits (VAR CodeSet:ASetOfCodes;
                       First, Last: ACode; Value:BOOLEAN);
VAR
    i : CARDINAL;
    WordNumber, BitNumber : CARDINAL;
BEGIN
    IF (First > MaxCode) OR (Last > MaxCode) THEN FatalError; END;

    i := First;
    WHILE (i <= Last) DO
        WordNumber := i DIV 16;
        BitNumber  := i MOD 16;
        IF (Value) THEN
            INCL(CodeSet[WordNumber], BitNumber)
        ELSE
            EXCL(CodeSet[WordNumber], BitNumber)
        END;
        INC(i);
    END
END SetCodeBits;


BEGIN
    SetCodeBits(EmptyCodeSet,0,MaxCode,FALSE);
END Codes.
