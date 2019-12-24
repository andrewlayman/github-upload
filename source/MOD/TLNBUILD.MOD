MODULE TLNBUILD;

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
     21-Sep-89  EGK - Set PackageOK to FALSE on error.
    *)


FROM NetStatic                  IMPORT 
    (* CONST *)                     NetworkView, 
    (* VAR *)                       maxtask,
                                    SnetRows, SnetCols,
                                    ViewType, FatalNetError;

FROM Overlays                   IMPORT
    (* VAR *)                       PackageOK;
                                                                        
FROM TSort                      IMPORT
    (* PROC *)                      TSort;

VAR
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN                           (* TLNBUILD *)
    
   Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
   maxtask := 0;
   SnetRows := 0;
   SnetCols := 0;
   ViewType := NetworkView;
   TSort();   (* Build the drawing matrix *)

    IF (FatalNetError) THEN         (* 9/21/89 EGK *)
        PackageOK := FALSE;
    END;

END TLNBUILD.
