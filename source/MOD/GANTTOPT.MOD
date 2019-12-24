IMPLEMENTATION MODULE GanttOptions;

    (*  MODIFICATION HISTORY
         8-Mar-89 LAA   Created this module to insulate TLG/S from how we
                        implement the choices of where to show percent
                        complete (Plan line or Baseline), and what value to
                        use for percent complete.
        27-Apr-89 WKH   Made changes so this moudle would work with Lazlo
        06-Jul-89 LAA   Fixed up to pull the relevant info from the current
                        layout, rather than always getting it from the plan
                        line and percent complete column.
	26-Jul-89 CMH   Changed QueryPctCompletePlace and
	                QueryPctCompleteColumn to use the following order
	                in determining the layout to use: the layout
	                specified on the TLGS Gantt Form, the current Gantt 
	                layout, or the default Gantt layout.
	 9-Aug-89 CMH   Importing FindLayoutByName procedure from LoadCommon.
    23-Jan-91 RSC   Moved FindLayoutsByName here from LoadCommon to save
                    all that baggage.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice,
    (* PROC *)                  GetColumnPercentage;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormat, AChartFormatPtr,
    (* VAR *)                   CurrentChartFormat,
                                DefaultChartFormat, LayoutTree,
    (* PROC *)                  CurrentLayout;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM IlsaStatic	            IMPORT 
    (* TYPE *)	                ATLGSGanttRecord,
                                ATLGSGanttRecordPtr,
    (* PROC *)	                TLGSGanttRecord;
    
FROM LStrings               IMPORT
    (* PROC *)                  TrimRear, StringsEqual;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;





(* 23-Jan-91 RSC From LoadComm *)
PROCEDURE FindLayoutByName(VAR LayoutName   : ARRAY OF CHAR)       (* in     *)
                                                                : ATreeNode;

VAR
    Layout                  : AChartFormatPtr;
    Node                    : ATreeNode;

BEGIN                       (* FindLayoutByName *)

    TrimRear(LayoutName);   (* RSC 5-Sep-89 *)
    Node := LayoutTree^.Methods^.GetFirst (LayoutTree);
    WHILE (Node <> NIL) DO
        Layout := Node^.Methods^.GetDataObject (Node);
        TrimRear(Layout^.Name);   (* WKH 5/11/89 *)
        IF (StringsEqual(Layout^.Name, LayoutName)) THEN    (* RSC 1/2/88 *)
            RETURN Node;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;

    RETURN NIL;

END FindLayoutByName;





(*  QueryPctCompletePlace  --

    Return the kind of Gantt line (Plan or Baseline) where the percent
    complete value is to be shown by shading or other visual means.

    Preconditions:
        None.

    Postconditions:
        Placement of percent complete is returned.
*)

PROCEDURE QueryPctCompletePlace(): AGanttLineType;

VAR
    Layout                  : AChartFormatPtr;

BEGIN                       (* QueryPctCompletePlace *)

    Layout := GetTLGSGanttLayout();

    RETURN Layout^.ProgressLineType;

END QueryPctCompletePlace;




(*  QueryPctCompleteColumn --

    Returns the "magic" number of the column which has been designated to
    be used for showing percent complete, via shading or other visual
    indications, on the Gantt bars.

    Preconditions:
        None.

    Postconditons:
        The "magic" number of the column to be used for percent complete is
        returned.
*)

PROCEDURE QueryPctCompleteColumn(): CARDINAL;

VAR
    Layout                  : AChartFormatPtr;

BEGIN                       (* QueryPctCompleteColumn *)

    Layout := GetTLGSGanttLayout();

    RETURN Layout^.ProgressColumnID;

END QueryPctCompleteColumn;




(*  QueryPctComplete --

    Returns a number in the range 0..100 for the given task, to be used as
    percent complete in showing shading, or other visual indications, on the
    Gantt bars.

    Preconditions:
        Task must be a valid (non-NIL) task tree node.

    Postconditions:
        The value to be used as percent complete for this task is returned.
*)
  
PROCEDURE QueryPctComplete(    Task         : ATreeNode): CARDINAL;

VAR
    T                       : ATaskPtr;
    Pct                     : CARDINAL;
    GoodColumn              : BOOLEAN;
    s: ARRAY [0..255] OF CHAR;

BEGIN                       (* QueryPctComplete *)

    T := Task^.Methods^.LockFlexStorDataObject(Task);
    GoodColumn := GetColumnPercentage(Task, T, QueryPctCompleteColumn(), 
                                      QueryPctCompletePlace(), Pct);
    
    Task^.Methods^.UnlockUnchangedDataObject(Task);

    IF (NOT GoodColumn) THEN
        Pct := 0;
    END;

    RETURN Pct;

END QueryPctComplete;


(*  GetTLGSGanttLayout  --
  
    Returns the Gantt Chart Layout pointer for TLGS, based on the 
    following order to determine which layout to use: the layout
    specified on the TLGS Gantt Form, the current Gantt 
    layout, or the default Gantt layout.
*)

PROCEDURE GetTLGSGanttLayout() : AChartFormatPtr;  (* 26-Jul-89 CMH *)

CONST
    HoursMinChars = 3.0;
    
VAR
    GanttChartLayout : AChartFormatPtr;
    TLGSGanttInfo    : ATLGSGanttRecordPtr;
    Node             : ATreeNode;

BEGIN

    TLGSGanttInfo:= TLGSGanttRecord(HoursMinChars);
    Node := FindLayoutByName(TLGSGanttInfo^.Layout);
    IF (Node <> NIL) THEN
        GanttChartLayout := Node^.Methods^.GetDataObject (Node);
    ELSE
        IF (CurrentChartFormat = NIL) THEN
            GanttChartLayout := DefaultChartFormat^.Methods^.GetDataObject(DefaultChartFormat);
        ELSE        
            GanttChartLayout := CurrentChartFormat^.Methods^.GetDataObject(CurrentChartFormat);
        END;
    END;
    
    RETURN(GanttChartLayout);

END GetTLGSGanttLayout;


BEGIN                       (* GanttOptions *)
END GanttOptions.

