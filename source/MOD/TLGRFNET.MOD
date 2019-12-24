(*$S+*)
MODULE TLGRFNET; (* TIME LINE Network Graphics*)

(*  =========================================================================
    Last Edit : August 23, 1989 11:40AM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
        WKH  19-May-89  Made changes to support new pert record format
        LAA  29-May-89  Adjusted for Title Blocks being kept in FlexStor.
        KKC  10-Aug-89  Add copyright message.
        WKH  23-Aug-89  Removed import of routines from TSEDWrite, they were
                        not being referenced.  This solved another of our
                        infmaous "Version Conflict" bugs.

        RSC  12-Dec-89  Added Version Conflict module.  ARRRGGGGHHH!!
    =========================================================================
*)

FROM DataNetwork             IMPORT
    (* PROC *)    		InitializeNetworkData;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType,
                                ATLGSTitleBlockPtr,
                                ATLGSPertRecordPtr,
                     	        ATLGSPageRecordPtr,
    (* PROC *)                  TLGSTitleBlockExists,
                 		TLGSPertRecord,
                		TLGSPageRecord;
    
FROM NetStatic               IMPORT
    (* TYPE *)                  DiagramView,   
    (* VAR *)                   DeallocForRecalc,
                                NetworkDone,
                                ViewType;
   			
FROM Overlays               IMPORT
    (* VAR *)			PackageOK;
    
FROM TSEDData               IMPORT
    (* CONST *)			NETWORK,
    (* VAR *)			ChartType,
    				DrawingScale;
     
FROM TSEDPert               IMPORT 
    (* PROC *)                  TLGSNodeCharts;

FROM TSEDTimescale	    IMPORT
    (* VAR *)			AxisHeight;

FROM VersionConflict    IMPORT
    (* PROC *)              ConflictProc;

VAR    
    TLGSPertInfo : ATLGSPertRecordPtr;
    TLGSPageInfo : ATLGSPageRecordPtr;
    
(*--------------------------------------------------------------------------*)
        (*  
            NetworkGraphicsMain
            
            Main procedure for the TLGS network diagrams.
         *)
         
PROCEDURE NetworkGraphicsMain();
VAR  
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN 
    
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

 (* set the chart type and the view type *)
    AxisHeight:= 0;
    ChartType:= NETWORK;      
    ViewType:=  NetworkView;	
   
 (* build the chart decription and write the interface files *)  
    DrawingScale:= 1.0;
    InitializeNetworkData();
    TLGSNodeCharts();
    
END NetworkGraphicsMain;

(*--------------------------------------------------------------------------*)

BEGIN                           (* TLGRFNET *)

    TLGSPertInfo:= TLGSPertRecord();
    TLGSPageInfo:= TLGSPageRecord();

    IF ((NOT TLGSTitleBlockExists(TLGSPertChart)) OR              (* 29-May-89 LAA *)
        (TLGSPertInfo = NIL) OR 
        (TLGSPageInfo = NIL)) THEN
         PackageOK:= FALSE;
         DeallocForRecalc:= TRUE;  (* release memory *)
         NetworkDone:= TRUE;       (* all done *)
    ELSE
         PackageOK:= TRUE;
         NetworkGraphicsMain();
    END;

END TLGRFNET.
