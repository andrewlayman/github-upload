MODULE TLNBMat;
    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
     21-Sep-89  EGK - Set PackageOK to FALSE on error.
    *)


FROM BuildMatrix            IMPORT
    (* PROC *)                  BuildMatrix;

FROM NetStatic              IMPORT 
    (* VAR *)                   FatalNetError;

FROM Overlays               IMPORT
    (* VAR *)                   PackageOK;


VAR
    Copyright    : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    BuildMatrix();

    IF (FatalNetError) THEN
        PackageOK := FALSE;
    END;

END TLNBMat.
