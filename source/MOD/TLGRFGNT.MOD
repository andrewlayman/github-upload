(*$S+*)
MODULE TLGRFGNT;

    (*  MODIFICATION HISTORY --
        29-May-89 LAA   Adjusted for the TitleBlock being stored in FlexStor.
        10-Aug-89 KKC   Add copyright message.
    *)

FROM DataGantt		     IMPORT
    (* PROC *)			InitializeGanttData;
    
FROM ErrorUtil              IMPORT
    (* PROC *) 			PrintSMsg;
    
FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSChartType, ATLGSGanttRecordPtr,
              			        ATLGSPageRecordPtr,
    (* PROC *)                  TLGSTitleBlockExists,
    				TLGSGanttRecord,
    				TLGSPageRecord;
    
FROM Overlays               IMPORT
    (* VAR *)			PackageOK;

FROM TSEDData               IMPORT
    (* CONST *)			GANTT,
    (* VAR *)			ChartType,
    				DrawingScale;
     
FROM TSEDGantt              IMPORT 
    (* PROC *)                  CalcTLGSGanttChart;

FROM TSEDTimescale	    IMPORT
    (* VAR *)			AxisHeight;
    
CONST
    HoursMinChars = 3.0;

VAR    
    TLGSGanttInfo   : ATLGSGanttRecordPtr;
    TLGSPageInfo    : ATLGSPageRecordPtr;
    
    
(*--------------------------------------------------------------------------*)
        (*  
            GanttGraphicsMain
            
            Main procedure for the TLGS Gantt charts.
         *)
         
PROCEDURE GanttGraphicsMain();
VAR  
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN 
    
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
 (* set the chart type and the view type *)

    AxisHeight:= 0;
    ChartType:= GANTT;
   
 (* build the chart decription and write the interface files *)  
    DrawingScale:= 1.0;
    InitializeGanttData();
    CalcTLGSGanttChart();
    
END GanttGraphicsMain;

(*--------------------------------------------------------------------------*)

BEGIN                           (* TLGRFGNT *)

    TLGSGanttInfo:= TLGSGanttRecord(HoursMinChars);
    TLGSPageInfo:= TLGSPageRecord();
    IF ((NOT TLGSTitleBlockExists(TLGSGanttChart)) OR 
        (TLGSGanttInfo = NIL) OR 
        (TLGSPageInfo = NIL)) THEN
         PackageOK:= FALSE;
    ELSE
         PackageOK:= TRUE;
         GanttGraphicsMain();
    END;
   
END TLGRFGNT.
