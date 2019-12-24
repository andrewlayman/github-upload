MODULE TlAsList;

(*  =========================================================================
    Last Edit : August 30, 1991 4:23PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        Assignment GoTo List

        Edit the current column for the Task Node passed as Context.

        > There must be a valid task node as the context address.
        > The current column on the GanttChart must be the column to edit.
        > The column must be one of the costing columns.

    MODIFICATION HISTORY:

    26-Apr-89 RSC  First Version; For the Spreadsheet View.
    22-May-89 RSC  When rate was 0 @ 0%, was displaying as 1 @ 0%.
    31-May-89 RSC  1) The module number overlapped the spreadsheet view.
                      This module now has its own number.
                   2) "Fix" and "Unit" were being mixed up.
                   3) Durations were being scaled by SMUPH.
     5-Jun-89 RSC  Move the cursor task to the top of the Gantt Chart.
    13-Jun-89 RSC  Shorten the NameProc strings that show up on the
                   assignment list.  Unit Costs were going off the screen.
    14-Jun-89 RSC  The conflict char was the first char on the list.
                   Well, Typethrough hates that!.  I moved the conflict
                   char after the name, before the Unit/Rsrc/Var /Fix.
    27-Jun-89 RSC  Fixed costs did not have actuals displayed.
     3-Aug-89 RSC  Fixed bug # 860, extra space in resource output line.
                   Also converted to new module header format.
    09-Aug-89 KKC  Add copyright message.
    21-Feb-90 KKC  Remove all unreferenced id from Timeu.
    30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
     7-Aug-90 RSC  Updated display to include ExtraCosts and Overtime.
    10-Aug-90 RSC  Updated for new cost calcs.
    15-Aug-90 RSC  Oops.  Now that GotoWithPrompts is being used, the
                   GoToNameProc can get NIL nodes passed.  Handle it.
    23-Aug-90 RSC  Moved the NameProc into AssList, as part of altering
                   the way that assignment trees are handled.
    23-Jan-91 RSC  Removed RealFormat, as it was unused.
     8-Apr-91 TGS  Import from TaskColNumbers instead of MagicNum.
    11-Jun-91 RSC  Rename AssList to AssListEdit.
    30-Aug-91 EGK  In HandleResourceColumns (duh), commented out the second
                   call to DisplayTheChart.  This was bad because if auto-
                   recalc was on, a recalc would happen right here.  Undo,
                   which is recording a transaction right now, would be
                   tricked into thinking that what it's recording doesn't
                   force a recalc, because it records the chart state at the
                   time that EndTransaction is called (which hasn't happened
                   yet).  Fortunately, the second DisplayTheChart isn't
                   really needed here anyway, since we will just return back
                   to the Gantt chart, which will DisplayTheChart itself.
                   Whew.  See Eve bug #4604.
    =========================================================================
*)



FROM AssListEdit IMPORT
    (* PROC *)      EditAssignmentList;

FROM Changer    IMPORT
    (* TYPE *)      ATaskFormContext;

FROM Chart      IMPORT
    (* VAR  *)      GanttChart;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState, DisplayTheChart;

FROM Dialog     IMPORT
    (* PROC *)      FatalError;

FROM Gantt      IMPORT
    (* TYPE *)      AGanttLineType;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange;

FROM Keys       IMPORT
    (* CONST *)     DoIt;

FROM Layout     IMPORT
    (* CONST *)     GanttWStart;

FROM LongConvert IMPORT
    (* PROC *)      LongToReal;

FROM LStrings   IMPORT
    (* PROC *)      SetString, ConcatLS, ConcatS, LengthOf, SetLengthOf,
                    TrimFront, TrimRear, Search, Remove, Insert, Copy,
                    CtoS, RJust, Procustes, Fill;

FROM TaskColNumbers IMPORT
    (* CONST *)     ResourceColumn, CostColumn, CostAmount, ResourceAmount;

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImAnInstallableOverlay, InstallNewProcedure,    
                    EnteringOverlay,        ExitingOverlay,
                    OverlayContext;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, ADR;

FROM Timei      IMPORT
    (* TYPE *)      ADurationUnit, ADate;

FROM TreeObjects IMPORT
    (* TYPE *)      ATreeNode;




CONST
    ModuleNumber         = 6300;



VAR
    OverlayID                   : AnOverlayID;






(* Handle Resource Columns

    This procedure handles the editing of resource columns for the Spreadsheet
    View.

    Preconditions
                    The passed overlay context contains a "ATaskFormContext"
                    pointer in it, with the task node filled in.

    Postconditions
                    If Possible, the assignments for the given task are edited.
                    The Code field in the context record is changed to DoIt
                    if there was no trouble editing.  Otherwise the code field
                    is left alone.
*)
PROCEDURE HandleResourceColumns();
VAR
    OldPosition     : CARDINAL;
    Context         : POINTER TO ATaskFormContext;
BEGIN

    Context  := OverlayContext();

    WITH Context^ DO
        OldPosition := GanttChart^.Methods^.InquirePosition (GanttChart, TaskNode);
        GanttChart^.Methods^.ForceToPosition (GanttChart, TaskNode, 1); (* RSC 5-Jun-89 *)
        GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
        UnSetState (Showing);
        DisplayTheChart();

        IF (EditAssignmentList( TaskNode )) THEN
            Code := DoIt;
        END;
            
        GanttChart^.Methods^.ForceToPosition (GanttChart, TaskNode, OldPosition); (* RSC 5-Jun-89 *)
        GanttChart^.Methods^.NoteSpecificChange (GanttChart, TaskChange);
        UnSetState (Showing);
        (* DisplayTheChart(); *)    (* 8/30/91 EGK *)
    END;

END HandleResourceColumns;










BEGIN

    OverlayID := ImAnInstallableOverlay( AnOverlayProc(HandleResourceColumns), AnOverlayProc(NIL) );
    HandleResourceColumns();

END TlAsList.
