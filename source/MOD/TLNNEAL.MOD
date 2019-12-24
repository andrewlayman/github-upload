MODULE TLNNeal;

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
     20-Sep-89  EGK - Created this as a base for the TSort2 module, which
                      handles the annealing phase of PERT drawing.    
     21-Sep-89  EGK - Set PackageOK to FALSE on error.
    *)

                                                                        
FROM NetStatic              IMPORT 
    (* VAR *)                   FatalNetError;

FROM Overlays               IMPORT
    (* VAR *)                   PackageOK;

FROM TSort2                     IMPORT
    (* PROC *)                      TSort2;

VAR
    Copyright    : ARRAY[0..50] OF CHAR;

BEGIN                           (* TLNNeal *)
    
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    TSort2();

    IF (FatalNetError) THEN
        PackageOK := FALSE;
    END;

END TLNNeal.
