(*$S+*)
MODULE TLWRTTRE; (* TIME LINE Tree Graphics*)

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
    
    *)
FROM DataTree               IMPORT
    (* PROC *)			InitializeTreeData;

FROM IlsaStatic             IMPORT
     (* TYPE *)                  AGraphStyle, 
                                 ATLGSPageRecord,
                                 ATLGSPageRecordPtr,
     (* PROC *)                  TLGSPageRecord;
           
FROM NetStatic               IMPORT
    (* TYPE *)                  DiagramView,   
    (* VAR *)                   DeallocForRecalc,
                                NetworkDone,
   				ViewType;
   			
FROM TSEDData               IMPORT
    (* CONST *)			TREE,
    (* VAR *)			ChartType,
    				DrawingScale;
     
FROM TSEDPert               IMPORT 
    (* PROC *)                  WriteNodeGraphicsFile;

FROM TSEDTimescale	    IMPORT
    (* VAR *)			AxisHeight;

FROM TSEDWrite		    IMPORT
    (* PROC *)		     	OpenTLGSFile,
    				CloseTLGSFile,
    				OpenMatrixSize,
    
    				CloseMatrixSize;
VAR
    APageDescription : ATLGSPageRecordPtr;
    Okay             : BOOLEAN;
    Copyright        : ARRAY[0..50] OF CHAR;
    
BEGIN                           (* TLWRTTRE *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

 (* set the chart type and the view type *)
    ChartType:= TREE; 
    ViewType:=  TreeView;		
   
 (* find the drawing scale factor *)
    APageDescription:= TLGSPageRecord();
    DrawingScale:= APageDescription^.Scale;
    
 (* build the chart decription and write the interface files *)  
    InitializeTreeData();

 (* open the interface files *)   
    Okay:= OpenTLGSFile(); 
    IF (Okay) THEN
     (* write the chart information *)
        WriteNodeGraphicsFile();
     (* all done, close the interface files *)    
        CloseTLGSFile();
    END; (* not okay - file open problems *)
  
    DeallocForRecalc:= TRUE;  (* release memory *)
    NetworkDone:= TRUE;       (* all done *)
        
END TLWRTTRE.
