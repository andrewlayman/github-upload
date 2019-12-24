IMPLEMENTATION MODULE GanttHelper;

(*  =========================================================================
    Last Edit : January 9, 1990 11:38AM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description:

        TIme Line's Task List.  This gets GoTo out of the root.

    MODIFICATION HISTORY:

        14-Dec-89 LAA   Created this module from GanttOutlines by extracting
                        the processing for the GoTo Key.  This was necessary
                        because GanttOutlines had too many symbols to compile.
        18-Dec-89 LAA   Added procedures PutVScroll and PutHScroll so Ed can
                        use them in the PERT view.
        19-Dec-89 LAA   Oops.  A bug in DoGanttGotoKey.  I'd mistyped what
                        should have been Lrx as Ulx.  Thanks, Ed.
        28-Dec-89 WKH   Sorry Ed, but think about it, in your 12/6/89 change,
                        send "OpenATask" notices if a closed-off task is
                        picked, there are never tasks that are closed-off in
                        GoTo.  You open them all!!!  Larry thought up a
                        really nice general solution for GoTo, but we were
                        afraid of the rippling effects(note the date of this
                        change).  Instead, we're going to give GanttOutlines
                        knolwedge of GoTo's secret visibility bit saving
                        scheme and limit the amount of damage we can do to
                        the Gantt and Pert view.  By the way, the way we
                        discovered this was that using GoTo to jump to a
                        closed task in the Pert or Tree view didn't work.
        04-Jan-89 LAA   Made the vertical and horizontal scroll bars use
                        videonetdone.
         6-Jan-90 RSC   Removed GoTo references.  This lets GoTo leave
                        the root.  Put standard header on this module.
         9-Jan-90 EGK   Fixed bug where DoGanttGotoKey wasn't updating the
                        value of "CursorNode" after calling the overlay.
         9-Jan-90 LAA   Tweeked where the vertical scroll separator character
                        is displayed to exactly match the scroll regions.
       4-Oct-90   AJL - Change the names of the mouse video attributes.
       01-Aug-91  LAA   When Histograms are up, the Gantt chart may be only
                        two line high.  Change PutVScrollBar so that, in this
                        case, there's no separator line between the up and
                        down arrows.  Bug # 4819.
    =========================================================================
*)


FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Endings                IMPORT
    (* VAR *)                   CompletionCode;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* CONST *)                 maxcol,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  LJust, SetLengthOf, Fill, LengthOf, SetString;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  Permission;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved, ConfigSaved;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeNodeAttribute;






CONST
    ModuleNumber            = 17500;        (* Shared with GanttOutlines *)



(*  DoGanttGotoKey --
        Process the Goto key from GanttOutlines, by putting up an appropriate
        GoTo list and returning the selected cursor node.
    Preconditions:
        Should be called only from the ActOnEvent proc of GanttOutlines. The
        ViewObject must be the task tree, the CursorColumn and CursorNode
        must be valid (non-zero, non-NIL).
    Postconditons:
        TRUE, and an updated cursor node will be returned iff the user pressed
        Enter or F10 from the GoTo list.
*)

PROCEDURE DoGanttGotoKey (     Ulx          : CARDINAL;
                               Uly          : CARDINAL;
                               Lrx          : CARDINAL;
                               Lry          : CARDINAL;
                               ViewObject   : ATree;
                               GoToColumn   : CARDINAL;
                               CursorColumn : CARDINAL;
                           VAR CursorNode   : ATreeNode      ): BOOLEAN;

TYPE
    (* KEEP IN SYNCH WITH TLTASKLIST! *)
    ATaskListContext = RECORD
        Ulx          : CARDINAL;
        Uly          : CARDINAL;
        Lrx          : CARDINAL;
        Lry          : CARDINAL;
        ViewObject   : ATree;
        GoToColumn   : CARDINAL;
        CursorColumn : CARDINAL;
        CursorNode   : ATreeNode;
        ReturnValue  : BOOLEAN;
    END;

VAR
    Context         : ATaskListContext;
    OverlayName     : ARRAY [0..19] OF CHAR;
    ok              : BOOLEAN;

BEGIN                   (* DoGanttGotoKey *)

    Context.Ulx          := Ulx;
    Context.Uly          := Uly;
    Context.Lrx          := Lrx;
    Context.Lry          := Lry;
    Context.ViewObject   := ViewObject;
    Context.GoToColumn   := GoToColumn;
    Context.CursorColumn := CursorColumn;
    Context.CursorNode   := CursorNode;
    Context.ReturnValue  := FALSE;      (* Init to "failed" *)

    SetString( OverlayName, "TLTASKLIS" );

    ok := CallOverlayWithContext( OverlayName, ADR(Context) );
    IF (ok) THEN
        CursorNode := Context.CursorNode;
    END;

    RETURN (ok) AND (Context.ReturnValue);

END DoGanttGotoKey;





PROCEDURE WantToQuit()  : BOOLEAN;
VAR
    S                   : ARRAY [0..255] OF CHAR;
BEGIN
    CompletionCode := 1; (* Terminate without continuing. *)  
    GetMessage(ModuleNumber + 79, S); (* "Really Leave Time Line?" *)
    IF (NoYes(S)) AND
       (Permission(ProgramQuit,NIL)) THEN
        IF ((ScheduleSaved) AND (ConfigSaved)) THEN
            RETURN TRUE;
        ELSE
            GetMessage(ModuleNumber + 80, S); (* "Without saving your schedule?" *)
            IF (NoYes(S)) THEN
                RETURN TRUE;
            END;
        END;
    END;
    UnSetState (Showing);
    RETURN FALSE;
END WantToQuit;



(*  PutHScrollBar --
        Write a horizontal scrollbar to the screen at the indicated 
        coordinates.  This scrollbar will consist of a left arrow at
        the left end, a right arrow at the right end, and a separator bar
        in the middle.  Either a left or right separator (or both) can be
        requested to separate this scroll area from an adjacent one.
    Preconditons:
        Video must be initialized.
    Postconditons:
        The indicated screen coordinates will be overwritten.
*)

PROCEDURE PutHScrollBar(     Ulx       : CARDINAL;
                             Uly       : CARDINAL;
                             Lrx       : CARDINAL;
                             LeftSep   : BOOLEAN;
                             RightSep  : BOOLEAN );

CONST
    LeftArrow           = 033C;         (* 27 decimal *)
    RightArrow          = 032C;         (* 26 decimal *)
    Separator           = 263C;         (* 179 decimal *)
    EndBar              = 272C;         (* 186 decimal *)

VAR
    Width               : CARDINAL;
    s                   : ARRAY [0..maxcol + 1] OF CHAR;

BEGIN                   (* PutHScrollBar *)

    Width := Lrx - Ulx + 1;
    IF (Width > 4) THEN
        Fill(s, " ", Width + 2);
        IF (LeftSep) THEN
            s[1] := Separator;
        END;
        s[2] := LeftArrow;
        s[Width + 1] := RightArrow;
        IF (RightSep) THEN
            s[Width + 2] := Separator;
        END;
        s[(Width+3) DIV 2] := Separator;
        PutString( s, Ulx-1, Uly, videoscrollbar );
    END;

END PutHScrollBar;


(*  PutVScrollBar --
        Write a vertical scroll bar to the screen at the indicated 
        coordinates.  This scroll bar will consist of an up arrow at the top,
        a down arrow at the bottom, and a horizontal separator line in the
        middle.
    Preconditions:
        Video must be initialized.
    Postconditions:
        The indicated screen coordinates will be overwitten with the scroll
        bar.
*)

PROCEDURE PutVScrollBar(     Ulx        : CARDINAL;
                             Uly        : CARDINAL;
                             Lry        : CARDINAL );

CONST
    UpArrow             = 030C;         (* 24 decimal *)
    DownArrow           = 031C;         (* 25 decimal *)
    Separator           = 304C;         (* 196 decimal *)

VAR
    Height              : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;
    s2                  : ARRAY [0..1] OF CHAR;

BEGIN                   (* PutVScrollBar *)

    Height := Lry-Uly+1;
    Fill( s, " ", Height );
    s[1] := UpArrow;
    s[(Height DIV 2)+1] := Separator;                          (*  9-Jan-90 *)
    s[Height] := DownArrow;

    FOR Height := 1 TO LengthOf( s ) DO
        Fill( s2, s[Height], 1);
        PutString( s2, Ulx, Uly+Height-1, videoscrollbar );
    END;

END PutVScrollBar;


END GanttHelper.
