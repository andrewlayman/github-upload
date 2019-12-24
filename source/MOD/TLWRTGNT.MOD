(*$S+*)
MODULE TLWRTGNT;
(*
Modifications:  
    10-Aug-89 KKC   Add copyright message.
    15-Nov-89 CMH   Added check for ilsastatic records.
    01-Dec-89 EGK   Put up a "please wait" box.
    11-May-90 MWP   Imported ConflictProc to remove version
                    conflict.
*)

FROM DataGantt              IMPORT
     (* PROC *)                 InitializeGanttData;

FROM Dialog                 IMPORT
    (* TYPE *)                  ABoxHandle,
    (* PROC *)                  ProgressBox, ReleaseBox;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType, ATLGSGanttRecordPtr,
                                ATLGSPageRecordPtr,
    (* PROC *)                  TLGSTitleBlockExists,
                                TLGSGanttRecord,
                                TLGSPageRecord;
    
FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Overlays               IMPORT
    (* VAR *)                   PackageOK;

FROM TSEDData               IMPORT
     (* CONST *)                GANTT,
     (* VAR *)                  ChartType,
                                DrawingScale;
     
FROM TSEDGantt              IMPORT 
     (* PROC *)                 WriteGanttGraphicsFile;

FROM TSEDTimescale          IMPORT
     (* VAR *)                  AxisHeight;

FROM TSEDWrite              IMPORT
     (* PROC *)                 OpenTLGSFile,
                                CloseTLGSFile;
FROM VersionConflict        IMPORT                                       (* 11-May-90 *)
                                ConflictProc;
        
        
CONST
    HoursMinChars = 3.0;

CONST
    ModuleNumber        = 8900;

VAR
    Okay              : BOOLEAN;
    TLGSGanttInfo     : ATLGSGanttRecordPtr;
    TLGSPageInfo      : ATLGSPageRecordPtr;
    s                 : ARRAY[0..99] OF CHAR;
    BoxHandle         : ABoxHandle;

    
(*--------------------------------------------------------------------------*)

BEGIN                           (* TLWRTGNT *)

    s := "Program Copyright (c) 1989 Symantec Corporation.";

    GetMessage (ModuleNumber, s);       (* "Please wait" *)
    BoxHandle := ProgressBox (s);       (* 12/1/89 EGK *)

    TLGSGanttInfo:= TLGSGanttRecord(HoursMinChars);
    TLGSPageInfo:= TLGSPageRecord();
    IF ((NOT TLGSTitleBlockExists(TLGSGanttChart)) OR 
        (TLGSGanttInfo = NIL) OR 
        (TLGSPageInfo = NIL)) THEN
         PackageOK:= FALSE;
    ELSE
         PackageOK:= TRUE;
      (* set the chart type and the view type *)

         AxisHeight:= 0;
         ChartType:= GANTT;
   
      (* find the drawing scale factor *)
         DrawingScale:= TLGSPageInfo^.Scale;
    
      (* build the chart decription and write the interface files *)  
         InitializeGanttData();
    
      (* open the interface files *)   
         Okay:= OpenTLGSFile(); 
         IF Okay THEN
            WriteGanttGraphicsFile();
            CloseTLGSFile();
         END;
    END;
       
    ReleaseBox (BoxHandle);         (* 12/1/89 EGK *)

END TLWRTGNT.

