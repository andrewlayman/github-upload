MODULE TLLayList;


(*  =========================================================================
    Last Edit : February 21, 1990 10:48AM by KKC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        16-Jun-89 RSC   First cut, from RsrcEdit.
        27-Jul-89 EGK   Changed DoTLLayList to reflect the fact that
                        "Layout" is now a POINTER to a node.
        09-Aug-89 KKC   Add copyright message.
        21-Sep-89 WKH   Don't "Grow" layout list, too slow.
        14-Dec-89 MWP   Added checking for existence of rodents.
        27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                        the same thing.
         5-Jan-90 MWP   Put the Ok button back in.
        21-Feb-90 KKC   Remove import of Timeu.
        04-Jun-90 AJL   Remove import of Planner.
         6-Oct-90 AJL   Add insert and delete mouse buttons.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
    =========================================================================
*)




FROM Boxes                  IMPORT 
                                ABoxType, ABoxAttribute;

FROM Codes                  IMPORT 
                                ACode;

FROM ChartForms             IMPORT
    (* TYPE *)                  ALayoutContext, AChartFormatPtr,
    (* VAR  *)                  LayoutTree,
    (* PROC *)                  CreateLayout, DiscardLayout;

FROM Dialog                 IMPORT 
                                Burp, Message, Error, FatalError, 
                                ADialogOption, WarningBox;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM Gantt                  IMPORT 
                                ASlackStyle, AGanttLineType;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineViewType;

FROM Kbio                   IMPORT 
                                maxrow, maxcol, ascreenx, ascreeny, avidmode;

FROM Keys                   IMPORT 
                                ExitKey, DoIt, InsertKey, DeleteKey, CancelKey,
                                EditKey, MoveUpKey, MoveDownKey;

FROM MsgFile                IMPORT 
                                GetMessage;

FROM LayoutOutlines         IMPORT
    (* TYPE *)                  ALayoutOutline,
    (* PROC *)                  CreateLayoutOutline;

FROM LStrings               IMPORT 
                                SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                Insert, Procustes, TrimFront, TrimRear, Fill, 
                                LengthOf, Copy, Compare, LJust, SetLengthOf,
                                Upshift;

FROM   Mouse        IMPORT
    (* PROC *)          MousePresent;                               (* 14-Dec-89 MWP *)


FROM   Overlays     IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          OverlayContext, ImAnInstallableOverlay;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM Schedule               IMPORT 
                                ScheduleSaved, ConfigSaved;

FROM Space                  IMPORT 
                                ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT 
                                ADR;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 TaskNameColumn, ResourceColumn,
                                StatusColumn, PercentAchieved;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;


CONST
    ModuleNumber = 2600;    (* For GetMessage. *)
                            (* 9/20/88 WKH - ModuleNumber is referenced as
                               KludgeNumber in module LayoutKludges. *)






VAR
    OverlayID   : AnOverlayID;








(*----------------------------------------------------------------------------
    SelectLayout --

    Display a list of the named layouts, defaulting the cursor position to
    the layout passed as parameter, and allow the user to select one.
    The ULX, ULY, LRX, & LRY paramaters specify the screen location of the
    selection box.  The Warning parm indicates whether a warning should be
    issued when the selected layout is longer than the screen width,
    longer than 255 characters, or if the task name isn't on screen.

    Preconditions:
        The layout passed in must be a valid layout, or it may be NIL.

    Postconditions:
        The layout parameter will be changed to reflect the user's choice,
        if a selection is made.  If the user exits with ESC, the initial
        value of the layout parameter will be preserved.  Within this call,
        it is possible to add, delete, copy and edit named layouts.
----------------------------------------------------------------------------*)

PROCEDURE SelectLayoutAt(VAR Layout             : ATreeNode;
                             ULX, ULY, LRX, LRY : CARDINAL;
                             Warning            : BOOLEAN) : ACode;

CONST
    KludgeNumber            = 2600;  (* KludgeNumber is actually the module
                                        number for ChartForms.  This is needed
                                        because SelectLayout needs to reference
                                        phrases and helptext from the 
                                        ChartForms module. *)

VAR
    LayoutOutline           : ALayoutOutline;
    Title                   : ARRAY [0..80] OF CHAR;
    FirstNode               : ATreeNode;
    Event                   : AnEvent;
    TempLayout              : ATreeNode;
    LayoutPtr               : AChartFormatPtr;
    LocalBoxType            : ABoxType;


    PROCEDURE WarnIfNecessary();

    VAR
        i                   : CARDINAL;
        TotalWidth          : CARDINAL;
        ChartRecord         : AChartFormatPtr;
        S                   : ARRAY [0..255] OF CHAR;
        Title               : ARRAY [0..1] OF CHAR;

    BEGIN                   (* WarnIfNecessary *)

        ChartRecord := Layout^.Methods^.GetDataObject(Layout);
        WITH ChartRecord^ DO
                (*  Warn if the task name isn't on screen.  *)    (* 01-May-89 LAA *)

            IF (NOT TaskNameOnScreen) THEN
                    (* "Because the task names won't be visible, some commands to the Gantt chart will be disabled." *)
                GetMessage(KludgeNumber + 7, S);
                SetLengthOf(Title, 0);                            (* 30-Dec-87 LAA *)
                WarningBox(S, Title, NoHelp);
            END;
        END;

    END WarnIfNecessary;


    PROCEDURE WarnOfLowMemory();
    VAR
        Title               : ARRAY [0..1] OF CHAR;
        S                   : ARRAY [0..255] OF CHAR;
    BEGIN
        GetMessage(KludgeNumber + 9, S); (* "Not enough memory left to honor your request.üüSee Appendix G." *)
        SetLengthOf(Title, 0);
        WarningBox(S, Title, NoHelp);
    END WarnOfLowMemory;


BEGIN                       (* SelectLayout *)

    GetMessage (KludgeNumber+8, Title);

    IF (NOT CreateLayout(TempLayout)) THEN
        WarnOfLowMemory();
        RETURN CancelKey;
    END;

    LayoutPtr := TempLayout^.Methods^.GetDataObject(TempLayout);  (* 14-Jan-88 LAA *)
    EXCL(LayoutPtr^.LayoutFlags, 0);

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll,
                               HasInsert,HasDelete }; (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;

    IF (CreateLayoutOutline(LayoutOutline, NIL, ULX, ULY, LRX, LRY,
                            LocalBoxType, 
                            videonormal, Title, KludgeNumber, TRUE)) THEN    (* 05-Mar-88 LAA *)

        WITH LayoutTree^.Methods^ DO
            AddFirst(LayoutTree, TempLayout);
        END;

        FirstNode := LayoutTree^.Methods^.GetFirst(LayoutTree);
        LayoutOutline^.Methods^.SetObject (LayoutOutline, LayoutTree);
        LayoutOutline^.Methods^.ResetMatching (LayoutOutline);
        LayoutOutline^.Methods^.SetFirst (LayoutOutline, FirstNode);
        IF (Layout = NIL) THEN
            LayoutOutline^.Methods^.SetCursorNode (LayoutOutline, FirstNode);
        ELSE
            (*<DEBUGGING
            ValidateTreeNode(Layout);
              DEBUGGING*)

            LayoutOutline^.Methods^.SetCursorNode (LayoutOutline, Layout);
        END;
        LayoutOutline^.Methods^.SetCursor (LayoutOutline, TRUE);

        LOOP
            LayoutOutline^.Methods^.Display (LayoutOutline);
            GetNextEvent (Event);
            LayoutOutline^.Methods^.ActOnEvent (LayoutOutline, Event, Event);
            CASE Event.EventCode OF
                CancelKey :
                    EXIT;
            |   DoIt, ExitKey :
                    Layout := LayoutOutline^.Methods^.GetCursorNode (LayoutOutline);
                    IF (Layout = TempLayout) THEN
                        Layout := NIL;
                    ELSIF (Warning) THEN
                        WarnIfNecessary();
                    END;
                    EXIT;
            |   0 : ;
            ELSE
                Burp();
            END;
        END;
        DiscardLayout(TempLayout);
        LayoutOutline^.Methods^.Discard (LayoutOutline);
    ELSE
        WarnOfLowMemory();
        RETURN CancelKey;
    END;

    RETURN Event.EventCode;

END SelectLayoutAt;






PROCEDURE DoTLLayList();
VAR
    LayoutContextPtr : POINTER TO ALayoutContext;
    Copyright        : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    LayoutContextPtr := OverlayContext();

    WITH LayoutContextPtr^ DO
        ReturnCode := SelectLayoutAt( LayoutPtr^, ULX, ULY, LRX, LRY, Warning );
    END;

END DoTLLayList;









BEGIN

    OverlayID := ImAnInstallableOverlay(DoTLLayList, AnOverlayProc(NIL));
    DoTLLayList();

END TLLayList.


