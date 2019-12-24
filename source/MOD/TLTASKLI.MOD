MODULE TLTaskList;

(*  =========================================================================
    Last Edit : June 18, 1991 10:52AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        TIme Line's Task List.  This gets GoTo out of the root.

    MODIFICATION HISTORY:

         6-Jan-90  RSC  First version, code from GanttHelper.
        27-Feb-90  RSC  Fixed bug in GanttOutlines here (because this is
                        a small overlay), where a 25 line screen with
                        3+ histograms causes task list to crash with
                        Lry < Uly.
        18-Jun-91  RSC  Speed up lookups for common items, WBS and task name.
                        because of overlay swapping, this was VERY SLOW.
        20-Aug-91 TGS   PFG changed the order of the WBSErrors and 
                        CodingFields. This had to be accounted for here.
        25-Sep-91 LAA   Patty had changed the column number of the WBSErrors
                        column back to 123, as it had been in V.4, in order
                        to minimize the fixups of layouts (see the note in
                        TaskColNumbers dated 16-Aug-91).  Unfortunately, this
                        module assumed a relationship between the column
                        number of the WBSErrors column and the coding columns.
                        I fixed it so there is no longer a relationship.
                        Related to bug #5196.
    =========================================================================
*)


FROM Allocs                 IMPORT
    (* CONST *)                 WBSLine, OBSLine, AUXLine,
                                FirstOtherCodingLine,
    (* TYPE *)                  ATaskPtr,
    (* PROC *)                  GetCodingField;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, 
    (* PROC *)                  GetColumnString;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  ContinuationBox;

FROM Filters                IMPORT
    (* PROC *)                  SetRevealFilterDisabled, QueryRevealFilterOn;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc,
    (* PROC *)                  DoGoTo, AmIVisible;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, ExitKey;

FROM LStrings               IMPORT
     (* PROC *)                  LJust, SetLengthOf, Fill, LengthOf, Copy;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 WBSColumn, TaskNameColumn, OBSColumn,
                                NumberOfCodingFields,
                                AUXColumn, CodingField1, WBSErrors;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeNodeAttribute;




CONST
    ModuleNumber            = 17500;        (* Shared with GanttOutlines *)



VAR
    OverlayID           : AnOverlayID;
    GoToColumnID        : CARDINAL;     (* Global context *)




PROCEDURE GetTaskString  (     Node       : ATreeNode;
                           VAR s          : ARRAY OF CHAR );
VAR
    Task                : ATaskPtr;

BEGIN

    Task := Node^.Methods^.LockFlexStorDataObject (Node);

        (* 18-Jun-91 RSC For some cases, speed up the list vastly.
        *)
    CASE GoToColumnID OF

        TaskNameColumn : Copy( Task^.taskname, s );

      | WBSColumn      : GetCodingField( Task^, WBSLine, s );

      | OBSColumn      : GetCodingField( Task^, OBSLine, s );

      | AUXColumn      : GetCodingField( Task^, AUXLine, s );

      | CodingField1..CodingField1+NumberOfCodingFields-1 :
                         GetCodingField( Task^, FirstOtherCodingLine + (GoToColumnID - CodingField1), s );

      | WBSErrors : GetCodingField( Task^,                     (* 25-Sep-91 *)
                                    FirstOtherCodingLine + NumberOfCodingFields, 
                                    s );

    ELSE
        IF (GetColumnString (Node, Task, GoToColumnID, Plan, 80, s)) THEN
            LJust (s);
        ELSE
            SetLengthOf (s, 0);
        END;
    END;

    Node^.Methods^.UnlockUnchangedDataObject (Node);

END GetTaskString;




PROCEDURE GoToCheckProc    (    Outline     : AnOutlineView;
                                Tree        : ATree;
                            VAR Code        : ACode         );

VAR
    Node            : ATreeNode;

    PROCEDURE NoYesNumber   ( Msg   : CARDINAL  ) : BOOLEAN;

    VAR
        s               : ARRAY [0..200] OF CHAR;
        NullString      : ARRAY [0..0] OF CHAR;

    BEGIN
        GetMessage (Msg, s);
        SetLengthOf(NullString, 0);
        RETURN ContinuationBox (s, NullString, NoHelp);
    END NoYesNumber;

BEGIN

    IF (Code = DoIt) OR (Code = ExitKey) THEN
        Node := Outline^.Methods^.GetCursorNode (Outline);
        IF (Node <> NIL) THEN
            IF (QueryRevealFilterOn()) AND (NOT AmIVisible(Node)) THEN
                IF (NoYesNumber (ModuleNumber + 82)) THEN
                    SetRevealFilterDisabled();
                ELSE
                    Code := 0;
                END;
            END;
            IF (Code <> 0) THEN                 (* 12/6/89 EGK *)
                LOOP
                    Node := Node^.Methods^.Parent (Node);
                    IF (Node = NIL) THEN
                        EXIT;
                    END;
                    IF (NOT Node^.Methods^.TestAttributeBit(Node, Select1)) THEN    (* 28-Dec-89 WKH  *)
                        SendNotices (OpenATask, BeforeActing, Node);
                        Node^.Methods^.SetChildrenVisible (Node, TRUE);
                    END;
                END;
            END;
        END;
    END;

END GoToCheckProc;




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

VAR
    Column              : CARDINAL;
    Title               : ARRAY [0..41] OF CHAR;

BEGIN                   (* DoGanttGotoKey *)

    GoToColumnID := GoToColumn;                    (*  Global context *)
    GetMessage (ModuleNumber+30, Title);

    (* 27-Feb-90 RSC ARGH!!  When there are 3+ histograms on the
                             screen and we are in 25 line mode, then
                             Lry is passed as < Uly.  Here we insure
                             that Lry is a little greater than Lry.

                             REAL FIX WOULD BE IN GANTTOUTLINES!!

                             (In the root, so we can't change it now)
    *)
    IF (Lry < (Uly + 6)) THEN
        Lry := Uly + 10;
    END;

    RETURN (DoGoTo(ViewObject, Ulx, Uly, Lrx, Lry, Title, TRUE, 
                   GoToCheckProc, GetTaskString, CursorNode));

END DoGanttGotoKey;




PROCEDURE DoTaskList();
TYPE
    (* KEEP IN SYNCH WITH GANTTHELPER! *)
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
    Context     : POINTER TO ATaskListContext;
BEGIN
    Context := OverlayContext();
    WITH Context^ DO
        ReturnValue := DoGanttGotoKey(Ulx, Uly, Lrx, Lry,
                                      ViewObject,
                                      GoToColumn, CursorColumn,
                                      CursorNode );
    END;
END DoTaskList;





BEGIN 

    OverlayID := ImAnInstallableOverlay( AnOverlayProc(DoTaskList), AnOverlayProc(NIL) );
    DoTaskList();

END TLTaskList.

