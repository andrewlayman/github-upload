(*$S+*)
MODULE TLWRTNET; (* TIME LINE Network Graphics*)
   
    (* MODIFICATION HISTORY:
     10-Aug-89  KKC - Add copyright message.
     15-Nov-89  CMH - Added check for ilsastatic records.
     01-Dec-89  EGK - Put up a "please wait" box.
     *)

FROM DataNetwork             IMPORT
    (* PROC *)                  InitializeNetworkData;

FROM Dialog                 IMPORT
    (* TYPE *)                  ABoxHandle,
    (* PROC *)                  ProgressBox, ReleaseBox;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType,
                                ATLGSTitleBlockPtr,
                                ATLGSPertRecordPtr,
                                ATLGSPageRecordPtr,
    (* PROC *)                  TLGSTitleBlockExists,
                                TLGSPertRecord,
                                TLGSPageRecord;

FROM LStrings               IMPORT
     (* PROC *)                 SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM NetStatic              IMPORT
    (* TYPE *)                  DiagramView,   
    (* VAR *)                   DeallocForRecalc,
                                NetworkDone,
                                ViewType;
                           
FROM Overlays               IMPORT
    (* VAR *)                   PackageOK;
                     
FROM TSEDData               IMPORT
    (* CONST *)                 NETWORK,
    (* VAR *)                   ChartType,
                                DrawingScale;
     
FROM TSEDPert               IMPORT 
    (* PROC *)                  WriteNodeGraphicsFile;

FROM TSEDTimescale          IMPORT
    (* VAR *)                   AxisHeight;

FROM TSEDWrite              IMPORT
    (* PROC *)                  OpenTLGSFile,
                                CloseTLGSFile;
CONST
    ModuleNumber        = 8800;

VAR
    Okay            : BOOLEAN;
    TLGSPertInfo    : ATLGSPertRecordPtr;
    TLGSPageInfo    : ATLGSPageRecordPtr;
    s               : ARRAY[0..99] OF CHAR;
    BoxHandle       : ABoxHandle;

BEGIN                           (* TLWRTNET *)

    s := "Program Copyright (c) 1989 Symantec Corporation.";

    GetMessage (ModuleNumber, s);       (* "Please wait" *)
    BoxHandle := ProgressBox (s);       (* 12/1/89 EGK *)

    TLGSPertInfo:= TLGSPertRecord();
    TLGSPageInfo:= TLGSPageRecord();

    IF ((NOT TLGSTitleBlockExists(TLGSPertChart)) OR
        (TLGSPertInfo = NIL) OR 
        (TLGSPageInfo = NIL)) THEN
         PackageOK:= FALSE;
         DeallocForRecalc:= TRUE;  (* release memory *)
         NetworkDone:= TRUE;       (* all done *)
    ELSE
         PackageOK:= TRUE;
      (* set the chart type and the view type *)

         AxisHeight:= 0;
         ChartType:= NETWORK;      
         ViewType:=  NetworkView;      
   
      (* find the drawing scale factor *)
         TLGSPageInfo:= TLGSPageRecord();
         DrawingScale:= TLGSPageInfo^.Scale;
    
      (* build the chart decription and write the interface files *)  
         InitializeNetworkData();

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
    END;

    ReleaseBox (BoxHandle);         (* 12/1/89 EGK *)

END TLWRTNET.
