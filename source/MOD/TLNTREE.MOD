(*$S+*)
MODULE TLNTREE;

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
    
    *)

FROM NetStatic                  IMPORT
    (* CONST *)                     TreeView,
    (* VAR *)                       ViewType,
                                    HaveInfLoop, FatalNetError;     

FROM TreeBuild                   IMPORT 
    (* PROC *)                      TreeMain;

VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                           (* TLNTREE *)
   
   Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

   ViewType:= TreeView;    
   TreeMain(0);
   HaveInfLoop:= FALSE;
   FatalNetError:= FALSE; 

END TLNTREE.
