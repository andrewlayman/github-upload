(*$S+*)
MODULE TLBLDTRE;
    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
    
    *)

FROM IlsaStatic                 IMPORT
    (* TYPE *)                     AnOrientation, 
                                   ATLGSTreeRecordPtr,
    (* PROC *)                     TLGSTreeRecord;
    				
FROM LStrings                   IMPORT
     (* PROC *)			   SetString;
     
FROM NetStatic                  IMPORT
    (* CONST *)                    TreeView,
    (* VAR *)                      ViewType,
                                   DeallocForRecalc, NetworkDone,
                                   HaveInfLoop, FatalNetError;     

FROM Overlays                   IMPORT
    (* VAR *)		           PackageOK;
    
FROM TreeBuild                  IMPORT 
    (* PROC *)                     TreeMain;

FROM TypoGraph              	IMPORT
                                   ATypoSpec;    
VAR 
    TreeType     : CARDINAL;
    TLGSTreeInfo : ATLGSTreeRecordPtr;
    Copyright    : ARRAY[0..50] OF CHAR;

BEGIN                           (* TLBLDTRE *)
   Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
   ViewType := TreeView;    
   TreeType := 0; (*  wide *)
   TLGSTreeInfo:= TLGSTreeRecord();
   IF (TLGSTreeInfo = NIL) THEN 
       PackageOK:= FALSE;
       DeallocForRecalc:= TRUE;  (* release memory *)
       NetworkDone:= TRUE;       (* all done *)
   ELSE
       PackageOK:= TRUE;
       IF (TLGSTreeInfo^.Orientation = Wide) THEN
           TreeType := 0; (* wide *)
       ELSE 
           TreeType := 1; (* tall *)
       END;
       TreeMain(TreeType);
       HaveInfLoop:= FALSE;
       FatalNetError:= FALSE; 
    END;
    
END TLBLDTRE.
