(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

IMPLEMENTATION MODULE Memos;

(*  =========================================================================
    Last Edit : December 8, 1989 6:17PM by EGK
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
    08-Dec-89 EGK   Move PickAndEditMemo into TLMEMOED overlay.
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

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, ascreeny, ascreenx, avidmode;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, Fill, ConcatLS, Copy,
                                SetLengthOf, SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE,
                                HeapAvailable, StackSpaceLeft;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  DiscardText, AssignText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    ModuleNumber            = 16300;

VAR
    LastMemoSelected        : ATreeNode;
    InterlockFlag           : BOOLEAN;





(*----------------------------------------------------------------------------
    PickAndEditMemo --

    Allow the user to select a memo off of the pick list of all memos for 
    editing.  Also allows creation and deletion of memos.
----------------------------------------------------------------------------*)

PROCEDURE PickAndEditMemo();
VAR
    OverlayName         : ARRAY [0..20] OF CHAR;
    ok                  : BOOLEAN;

BEGIN                       (* PickAndEditMemo *)

    IF (InterlockFlag) THEN
        Burp();
        RETURN;
    END;

    InterlockFlag := TRUE;

    SetString( OverlayName, "TLMEMOED" );
    ok := CallOverlayWithContext( OverlayName, ADR(LastMemoSelected));

    InterlockFlag := FALSE;

END PickAndEditMemo;







(*----------------------------------------------------------------------------
    EditMemo --

    Given a memo, bring up an editing session on its text.
----------------------------------------------------------------------------*)

PROCEDURE EditMemo (Memo        : ATreeNode);

VAR
    MemoData                : AMemoRecordPointer;
    Changed                 : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* EditMemo *)

    (*<NORMAL*)

    IF (Memo <> NIL) THEN
        MemoData := Memo^.Methods^.GetDataObject (Memo);
        IF NOT MemoData^.open THEN
            MemoData^.open := TRUE;
            Fill (s, " ", 0);
            EditText(0, GanttWStart, maxcol, maxrow-1, ABoxType{DoubleBox}, s,   (* 04-Nov-87 LAA *)
                     ModuleNumber, MemoData^.text, Changed);
            MemoData^.open := FALSE;
        ELSE
            GetMessage(ModuleNumber + 3, s);                       (* That memo is already being edited. *)
            Error(s);
        END;
    ELSE
         Burp ();
    END;

    (*NORMAL>*)

END EditMemo;




(*----------------------------------------------------------------------------
    CreateMemo --

    Create a new memo, using the given text.  Return its handle.
----------------------------------------------------------------------------*)

PROCEDURE CreateMemo (Text               : AText)               (* in     *)
                                                 : ATreeNode;

VAR
    MemoData                : AMemoRecordPointer;
    Node                    : ATreeNode;

BEGIN                       (* CreateMemo *)

    (*<NORMAL*)

    IF (NOT HeapAvailable()) THEN
        RETURN NIL;
    END;

    NEW(MemoData);
    IF ((MemoData = NIL) OR (NOT CreateTreeNode (Node))) THEN
        RETURN NIL;
    END;

    MemoData^.text := Text;
    MemoData^.open := FALSE;
    MemoData^.MemoFlags := {1};
    Node^.Methods^.SetDataObject (Node, MemoData);

    RETURN Node;

    (*NORMAL>*)

    (*<GELDED
    RETURN NIL;
    GELDED>*)

END CreateMemo;





(*----------------------------------------------------------------------------
    DiscardMemo --

    Release all storage for the specified memo, including it's text.
----------------------------------------------------------------------------*)

PROCEDURE DiscardMemoData (VAR Memo         : ATreeNode;
                               Context      : ADDRESS);           (* 04-Jun-87 LAA *)

VAR
    MemoData            : AMemoRecordPointer;
BEGIN

    IF (Memo = LastMemoSelected) THEN                             (* 24-Dec-87 LAA *)
        LastMemoSelected := NIL;
    END;
    MemoData := Memo^.Methods^.GetDataObject (Memo);
    DiscardText(MemoData^.text);
    DISPOSE (MemoData);
END DiscardMemoData;


PROCEDURE DiscardMemo(VAR Memo              : ATreeNode);              (* in/out *)

VAR
    Subtree             : ATree;

BEGIN                       (* DiscardMemo *)

    (*<NORMAL*)

    IF Memo = NIL THEN FatalError() END;

    Subtree := Memo^.Methods^.GetSubtree (Memo);
    IF (Subtree <> NIL) THEN
        Subtree^.Methods^.TraverseTree (Subtree, ParentAfterChild, 999,
                DiscardMemoData, NIL);                            (* 04-Jun-87 LAA *)
    END;
    DiscardMemoData (Memo, NIL);
    Memo^.Methods^.Discard (Memo);

    (*NORMAL>*)

END DiscardMemo;






BEGIN                       (* Memos *)

    IF (NOT CreateTree (MemoTree)) THEN
        FatalError ();
    END;
    LastMemoSelected := NIL;
    InterlockFlag := FALSE;

END Memos.
