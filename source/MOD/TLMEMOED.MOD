MODULE TLMemoEdit;

(*  =========================================================================
    Last Edit : December 11, 1989 5:08PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

    5/21/87 EGK     Rewritten to support storage of memos in MemoTree, and
                    editing and displaying using MemoOutlines and MemoViews
                    modules.
    6/1/87  EGK     No longer use memo names; just use first line of text as
                    the memo identifier.
    04-Jun-87 LAA   Changed parameters for TraverseTree.
    15-Oct-87 RSC   Added shadows to boxes.  Added param to EditText.
    04-Nov-87 LAA   Removed shadows from this edit window.
    24-Dec-87 LAA   Turn hardware cursor off when the list of memos is brought
                    up, and keep track of the last memo which the cursor was
                    on in LastMemoSelected, rather than just the last one 
                    edited.
    15-Jan-88 LAa   Put up some instructions for the memo list.
    20-Jan-88 RSC   Removed reference to Forms, which was not needed.
    04-Feb-88 EGK   Added InterlockFlag to prevent recursive invocations of
                    the journal list.
    05-Mar-88 LAA   Pass ModuleNumber as help number.
    01-Dec-88 EGK   Check for stack space in PickAndEditMemo, since this can
                    be called from a hot-key.
    10-Jan-89 RSC   Changed Storage to Space    .
    21-Sep-89 WKH   Don't "grow" boxes anymore, too slow
    08-Dec-89 EGK   Created this from the old Memos.MOD.
    14-Dec-89 MWP   Added checking for existence of rodents.
    =========================================================================
*)


FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error, Burp, Message;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, ascreeny, ascreenx, avidmode,
                                ACursorType,
    (* PROC *)                  SetCursorType, PutString;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, BackSpace, InsertKey,
                                DeleteKey, EditKey, CopyKey, ExitKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, TrimRear, Compare, Remove, Fill, 
                                Upshift, ConcatLS, TrimFront, Search, Copy,
                                Procustes, SetLengthOf;

FROM MemoOutlines           IMPORT
    (* TYPE *)                  AMemoOutline,
    (* PROC *)                  CreateMemoOutline;

FROM Memos                  IMPORT
    (* TYPE *)                  AMemoRecordPointer,
    (* VAR *)                   MemoTree,
    (* PROC *)                  EditMemo;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM   Mouse        IMPORT
    (* PROC *)          MousePresent;                               (* 14-Dec-89 MWP *)

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE,
                                HeapAvailable, StackSpaceLeft;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText, AssignText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    ModuleNumber            = 16300;

VAR
    OverlayID   : AnOverlayID;






(*----------------------------------------------------------------------------
    SelectMemo --

    Display a picklist of memos, with the cursor initially on the one
    passed into Selected, and allow the user to select a memo.  Selected will
    be changed only if something is selected, and TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE SelectMemo    (    ULX            : ascreenx;            (* in     *)
                             ULY            : ascreeny;            (* in     *)
                             LRX            : ascreenx;            (* in     *)
                             LRY            : ascreeny;            (* in     *)
                         VAR Selected       : ATreeNode    )           (* in/out *)
                                                        : BOOLEAN;

(*<NORMAL*)
VAR
    MemoOutline             : AMemoOutline;
    MemoData                : AMemoRecordPointer;
    LocalBoxType            : ABoxType;
    Title                   : ARRAY [0..21] OF CHAR;
    Event                   : AnEvent;
    FirstMemo               : ATreeNode;

(*NORMAL>*)

BEGIN                       (* SelectMemoName *)

    (*<NORMAL*)

    Event.EventCode := 0;
    GetMessage(ModuleNumber + 2, Title);                           (* Memos *)

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk, HasVScroll };
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;

    IF (CreateMemoOutline (MemoOutline, NIL, ULX, ULY, LRX, LRY,
            LocalBoxType, videonormal, Title, 
            ModuleNumber, TRUE)) THEN                             (* 05-Mar-88 LAA *)

            (*  Turn off cursor.  Will be restored by Discard method.  *)
        SetCursorType(NoCursor);                                  (* 24-Dec-87 LAA *)

        MemoOutline^.Methods^.SetObject (MemoOutline, MemoTree);
        FirstMemo := MemoTree^.Methods^.GetFirst (MemoTree);
        MemoOutline^.Methods^.SetFirst (MemoOutline, FirstMemo);
        IF (Selected = NIL) THEN
            MemoOutline^.Methods^.SetCursorNode (MemoOutline, FirstMemo);
        ELSE
            MemoOutline^.Methods^.SetCursorNode (MemoOutline, Selected);
        END;
        MemoOutline^.Methods^.SetCursor (MemoOutline, TRUE);
        MemoOutline^.Methods^.ResetMatching (MemoOutline);

        LOOP
            MemoOutline^.Methods^.Display (MemoOutline);
            GetNextEvent (Event);
            IF (Event.EventCode = DoIt) THEN
                Event.EventCode := EditKey;
            END;
            MemoOutline^.Methods^.ActOnEvent (MemoOutline, Event, Event);
            CASE Event.EventCode OF
                0 :;
            |   CancelKey, ExitKey :
                    Selected := MemoOutline^.Methods^.GetCursorNode(MemoOutline);
                    EXIT;
            ELSE
                Burp();
            END;
        END;
        MemoOutline^.Methods^.Discard (MemoOutline);
    ELSE
        DisplayMessage (ModuleNumber);  (* "Not enough memory to display list" *)
        Burp ();
    END;

    RETURN (Event.EventCode = DoIt);

    (*NORMAL>*)

    (*<GELDED
    RETURN FALSE;
    GELDED>*)

END SelectMemo;





PROCEDURE DoTLMemoEdit();

CONST
    StackNeeded             = 2048;
VAR
    LastMemoPtr             : POINTER TO ATreeNode;
    Rug                     : ARug;
    s                       : ARRAY [0..80] OF CHAR;
    RugTaken                : BOOLEAN;

BEGIN
    s := "Program Copyright (c) 1989 Symantec Corporation.";

    LastMemoPtr := OverlayContext();

    IF (NOT StackSpaceLeft (StackNeeded)) THEN
        Burp();
        RETURN;
    END;

    RugTaken :=  GetRug(0, 0, maxcol, GanttWStart - 1, Rug);
    SetLengthOf(s, 0);
    Message(s);
    GetMessage(ModuleNumber + 5, s);               (* editing instructions.  *)
    Procustes (s, maxcol+1);
    PutString(s, 0, GanttWStart - 2, videonormal);
    GetMessage(ModuleNumber + 6, s);
    Procustes (s, maxcol+1);
    PutString(s, 0, GanttWStart - 1, videonormal);

    IF SelectMemo (22, 5, 58, maxrow - 2, LastMemoPtr^) THEN
        EditMemo (LastMemoPtr^);
    END;

    IF (RugTaken) THEN
        PutRug(0, 0, maxcol, GanttWStart - 1, Rug);
    END;

END DoTLMemoEdit;



BEGIN

    OverlayID := ImAnInstallableOverlay(DoTLMemoEdit, AnOverlayProc(NIL));
    DoTLMemoEdit();

END TLMemoEdit.
