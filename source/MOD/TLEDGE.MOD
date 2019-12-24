MODULE TLEdge;

    (*  MODIFICATION HISTORY
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        6-Jan-89  RSC   Moved "AnOverlayProc" reference.
        21-Mar-89 AJL   Added Edge Type.
        09-Aug-89 KKC   Add copyright message.
        13-Nov-89 EGK   Don't have EditEdge return CancelKey if the form
                        data wasn't changed -- use the "Changed" parameter
                        for that.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
                        
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskStatus, ATaskStatusSet, ATaskPtr;

FROM ChartControl           IMPORT AChartState, SetState, UnSetState, 
                                DisplayTheChart;

FROM Codes                  IMPORT ACode;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr, AnEdgeType, AnEdge;

FROM Forms                  IMPORT AForm, DoForm, AFieldValue, ACheckReason, AStringValue;

FROM FormCon                IMPORT AFieldNo;

FROM Kbio                   IMPORT maxcol;

FROM Keys                   IMPORT ExitKey, CancelKey, OnMenu, DoIt, GotoKey,
                                   AddTaskKey, ChngTskKey, DelTaskKey, JoinKey,
                                   UnJoinKey, SplitKey, OnChart, UndoKey, CopyKey,
                                   EditKey, JoinPartialKey, ResourceFormKey,
                                   DeleteKey, EraseKey;

FROM Layout                 IMPORT GanttWEnd;

FROM LStrings               IMPORT Fill, SetString, ConcatS, ConcatLS, SubStr,
                                   LengthOf, Overlay, LJust, TrimRear, Insert, Procustes,
                                   CtoS, RJust, Compare, TrimFront, Copy, SetLengthOf;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Schedule               IMPORT ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* THING *)                 ADDRESS, TSIZE, ADR;

FROM TimeFormat             IMPORT
    (* PROC *)                  TimeUtoS;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration,
    (* TYPE *)                  ADate, ADurationUnit, ADuration;
    
FROM Timeu                  IMPORT
    (* PROC *)                  UpScale, DownScale;
                                   
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;



CONST
    ModuleNumber = 3500;  (* SAME AS TLChange AND Changer FOR NOW!! *)
    MAXCARDINAL  = 65535;

VAR
    OverlayID               : AnOverlayID;
    FormChanged             : BOOLEAN;


PROCEDURE CheckEdgeData (     Form          : AForm;
                              FieldNo       : AFieldNo;
                          VAR FormValue     : ARRAY OF AFieldValue;
                              CheckReason   : ACheckReason;
                          VAR Code          : CARDINAL ):BOOLEAN;
VAR
    Dur   : ADuration;
    Scale : ADurationUnit;
BEGIN
    Code := 0;  (* For a safe return. *)

    IF (CheckReason = CheckFieldChange) THEN        (* 4/28/89 EGK *)
        FormChanged := TRUE;
    END;

        (*  Attempt to weed-out settings that could cause problems during
            scheduling. *)
    Dur := NoDuration;
    CASE FieldNo OF
        3,4:
             Scale := VAL(ADurationUnit,FormValue[4].CardValue);
             Dur   := UpScale(FormValue[3].CardValue,Scale);
      | 8,9:
             Scale := VAL(ADurationUnit,FormValue[9].CardValue);
             Dur   := UpScale(FormValue[8].CardValue,Scale);
        ELSE ;
    END;
    IF (Dur <= (MAXCARDINAL DIV 4)) THEN
        RETURN TRUE;
    ELSE
        DisplayMessage(ModuleNumber+11);         (* "Too much!"  *)
        RETURN FALSE;
    END;
END CheckEdgeData;





    (*  EditEdge -- Change the edge connecting BugTaskA and BugTaskB *)

PROCEDURE EditEdge (    EdgePtr     : AnEdgePtr;
                    VAR Changed     : BOOLEAN   )   : ACode;
VAR
    PriorNode               : ATreeNode;
    AfterNode               : ATreeNode;
    PriorTask               : ATaskPtr;
    AfterTask               : ATaskPtr;
    Code                    : ACode;
    FormValue               : ARRAY [0..9] OF AFieldValue;
    StringValues            : ARRAY [0..1] OF AStringValue;
    OldEdgeRecord           : AnEdge;

BEGIN
    OldEdgeRecord := EdgePtr^;

    FormValue[1].CharValue := ADR(StringValues[0]);
    PriorNode := EdgePtr^.headtask;
    PriorTask := PriorNode^.Methods^.LockFlexStorDataObject (PriorNode);
    Copy(PriorTask^.taskname,FormValue[1].CharValue^);
    PriorNode^.Methods^.UnlockUnchangedDataObject (PriorNode);

    WITH EdgePtr^.FromOffset DO
        FormValue[0].CardValue := ORD(NOT Start);
        FormValue[2].CardValue := ORD(NOT Plus);
        FormValue[3].CardValue := DownScale(Dur,Scale);
        FormValue[4].CardValue := ORD(Scale);
    END;
    FormValue[6].CharValue := ADR(StringValues[1]);
    AfterNode := EdgePtr^.tailtask;
    AfterTask := AfterNode^.Methods^.LockFlexStorDataObject (AfterNode);
    Copy(AfterTask^.taskname,FormValue[6].CharValue^);
    AfterNode^.Methods^.UnlockUnchangedDataObject (AfterNode);

    WITH EdgePtr^.ToOffset DO
        FormValue[5].CardValue := ORD(NOT Start);
    END;
    FormValue[7].CardValue := ORD(EdgePtr^.Type); 

    FormChanged := FALSE;

    Code := DoForm(0,0,maxcol,GanttWEnd,10,TRUE,FormValue,CheckEdgeData);

    IF (Code = ExitKey) AND (FormChanged) THEN
        WITH EdgePtr^.FromOffset DO
            Start := NOT VAL(BOOLEAN,FormValue[0].CardValue);
            Plus  := NOT VAL(BOOLEAN,FormValue[2].CardValue);
            Scale := VAL(ADurationUnit,FormValue[4].CardValue);
            Dur := UpScale(FormValue[3].CardValue,Scale);
            WHILE (DownScale(Dur,Scale) > 999) DO                 (* 14-Jan-88 LAA *)
                DEC(Dur);
            END;
        END;
        WITH EdgePtr^.ToOffset DO
            Start := NOT VAL(BOOLEAN,FormValue[5].CardValue);
        END;

        EdgePtr^.Type := VAL(AnEdgeType,FormValue[7].CardValue);

        UnSetState(Scheduled);                             (* LAA 11/04/86 *)
        ScheduleSaved := FALSE;
        AfterTask := AfterNode^.Methods^.LockFlexStorDataObject (AfterNode);
        AfterTask^.TaskStatusSet := ATaskStatusSet{NeedsRecalculate};
        AfterNode^.Methods^.UnlockFlexStorDataObject (AfterNode);
    END;

    Changed := FormChanged;             (* 11/13/89 EGK *)
    RETURN Code;

END EditEdge;



PROCEDURE TLEdgeBody();

VAR
    ContextRecordPtr        : POINTER TO RECORD
                                EdgePtr     : AnEdgePtr;
                                ReturnCode  : ACode;
                                EdgeChanged : BOOLEAN;
                              END;

    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                       (* TLEdgeBody *)
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    ContextRecordPtr := OverlayContext();
    WITH ContextRecordPtr^ DO
        ReturnCode := EditEdge( EdgePtr, EdgeChanged );
    END;
END TLEdgeBody;



BEGIN                       (* TLEdge *)

    OverlayID := ImAnInstallableOverlay(TLEdgeBody, AnOverlayProc(NIL));
    TLEdgeBody();

END TLEdge.
