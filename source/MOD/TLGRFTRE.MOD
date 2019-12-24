(*$S+*)
MODULE TLGRFTRE;

    (*  MODIFICATION HISTORY --
        29-May-89 LAA   Adjusted for the TitleBlock being stored in FlexStor.
        10-Aug-89 KKC   Add copyright message.
    *)


FROM DataTree               IMPORT
    (* PROC *)			InitializeTreeData;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType,
                                ATLGSTitleBlockPtr,
                                ATLGSTreeRecordPtr,
              			ATLGSPageRecordPtr,
    (* PROC *)                  TLGSTitleBlockExists,
    				TLGSTreeRecord,
    				TLGSPageRecord;
    
FROM NetStatic               IMPORT
    (* TYPE *)                  DiagramView,   
    (* VAR *)                   DeallocForRecalc,
                                NetworkDone,
                                ViewType;
   			
FROM Overlays               IMPORT
    (* VAR *)			PackageOK;
    
FROM TSEDData               IMPORT
    (* CONST *)			TREE,
    (* VAR *) 			ChartType, DrawingScale;
     
FROM TSEDPert               IMPORT 
    (* PROC *)                  TLGSNodeCharts;

VAR    
    TLGSTreeInfo : ATLGSTreeRecordPtr;
    TLGSPageInfo : ATLGSPageRecordPtr;
    
(*--------------------------------------------------------------------------*)
        (*  
            TreeGraphicsMain
            
            Main procedure for the TLGS tree diagrams.
         *)
         
PROCEDURE TreeGraphicsMain();
VAR  
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN 
    
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

 (* set the chart type and the view type *)
    ChartType:= TREE; 
    ViewType:=  TreeView;		
   
 (* build the chart decription and write the interface files *)  
    InitializeTreeData();
    DrawingScale:= 1.0;
    TLGSNodeCharts();

END TreeGraphicsMain;

(*--------------------------------------------------------------------------*)

BEGIN                           (* TLGRGTRE *)

    TLGSTreeInfo:= TLGSTreeRecord();
    TLGSPageInfo:= TLGSPageRecord();
    IF ((NOT TLGSTitleBlockExists(TLGSTreeChart)) OR              (* 29-May-89 LAA *)
        (TLGSTreeInfo = NIL) OR 
        (TLGSPageInfo = NIL)) THEN
         PackageOK:= FALSE;
         DeallocForRecalc:= TRUE;  (* release memory *)
         NetworkDone:= TRUE;       (* all done *)
    ELSE
         PackageOK:= TRUE;
         TreeGraphicsMain();
    END;
    
END TLGRFTRE.
