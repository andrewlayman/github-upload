IMPLEMENTATION MODULE GoTo;
(*MODULE TLGoTo;*)

(*  =========================================================================
    Last Edit : February 19, 1991 9:57AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        29-Dec-87 LAA   GoTo was allowing keys which reorganized the tree.
        24-Feb-88 EGK   Changed all notice contexts to be NIL.
        05-Mar-88 LAA   Pass ModuleNumber as help number.
         2-Jan-89 RSC   Removed references to Compare() (not used).
        14-Mar-89 RSC   Added ability to put out prompts from QuickPick.
                        That is, the cursor item can have a prompt displayed
                        for it.
         4-Jun-89 EGK   Changed SendNotices call to be more specific about
                        which task was opened.
        15-Jun-89 RSC   Take a rug of the first screen line, so Message()
                        wont blast anything up there.  Why?  Because the
                        Help Index is a GoTo box, and you can get to it from
                        the menus.
        19-Jun-89 AJL   Removed FiltersOn boolean, replaced by 
                        SetRevealFilterDisabled, and QueryRevealFilterOn.
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        14-Sep-89 WKH   If we try to bring up a goto box with the StartNode
                        = NIL, then we will try to just make FirstNode the
                        StartNode.  At least we're no worst off.
        19-Sep-89 WKH   Remove code that is specific to QuickPick and select
                        filtering and move it to GanttOutlines where it 
                        belongs.
        19-Sep-89 WKH   Added procedure AmIVisible to determine if a task
                        is "really" visible despite GoTo temporarily
                        opening up the entire tree.
         6-Dec-89 EGK   Removed code that sent "OpenATask" notices if a
                        closed item was selected.  Not good, since we might
                        be working with something other than tasks here.
        14-Dec-89 MWP   Added checking for existence of rodents.
        27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                        the same thing.
         5-Jan-90 MWP   Put the Ok button back in.
        18-Jan-90 EGK   Created this by moving code from old GoTo module.
        01-Aug-91 LAA   Added MouseKeys parameter to DoGoToWithPrompt so 
                        that callers can decide whether to have Insert,
                        Delete, Help, etc. buttons or not.  Bug #4772.
    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView,
    (* PROC *)                  CreateActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  FatalError, Error, Burp, Message, ContinuationBox;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, GetNextEvent, AnEventType;

(*FROM GoTo                   IMPORT*)
(*    (* TYPE *)                  AGoToNameProc, AGoToCheckProc,*)
(*                                SaveVisibility, RestoreVisibility;*)

FROM GoToOutlines           IMPORT
    (* TYPE *)                  AGoToOutline,
    (* PROC *)                  CreateGoToOutline, ValidateGoToOutline;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode, 
    (* CONST *)                 maxrow, maxcol,
    (* PROC *)                  PutString, EraseLn;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey, BackSpace, DoIt,
                                PromoteKey, DemoteKey,
                                MoveUpKey, MoveDownKey,
                                RepeatKey, OpenKey, CloseKey;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Overlay, SubStr, Procustes,
                                SetString, SetLengthOf, LengthOf, Upshift,
                                Copy;

FROM Mouse                  IMPORT
    (* PROC *)                  MousePresent;                               (* 14-Dec-89 MWP *)

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
                                ATreeNodeAttribute, ATreeNodeProcessingProc;


CONST
    ModuleNumber = 19900;

VAR
    OverlayID           : AnOverlayID;



(* FROM GOTO OLD ********************** *)
PROCEDURE AmIVisible        (VAR Node    : ATreeNode) : BOOLEAN;

BEGIN
    RETURN(Node^.Methods^.TestAttributeBit(Node, Select0));
END AmIVisible;


PROCEDURE SaveVisibility    (VAR Node    : ATreeNode;
                                 Context : ADDRESS  );

VAR
    Value : BOOLEAN;
    OpenTree                : POINTER TO BOOLEAN;

BEGIN                       (* SaveVisibility *)
    Value := Node^.Methods^.Visible (Node);
    Node^.Methods^.SetAttributeBit (Node, Select0, Value);
    Node^.Methods^.SetVisible (Node, TRUE);
    OpenTree := Context;
    IF (OpenTree^) THEN
        Value := Node^.Methods^.ChildrenVisible (Node);
        Node^.Methods^.SetAttributeBit (Node, Select1, Value);
        Node^.Methods^.SetChildrenVisible (Node, TRUE);
    END;
END SaveVisibility;



PROCEDURE RestoreVisibility    (VAR Node    : ATreeNode;
                                    Context : ADDRESS  );

VAR
    Value : BOOLEAN;
    OpenTree    : POINTER TO BOOLEAN;

BEGIN                       (* Restore Visibility *)
    Value := Node^.Methods^.TestAttributeBit (Node, Select0);
    Node^.Methods^.SetVisible (Node, Value);
    OpenTree := Context;
    IF (OpenTree^) THEN
        Value := Node^.Methods^.TestAttributeBit (Node, Select1);
        Node^.Methods^.SetChildrenVisible (Node, Value);
    END;
END RestoreVisibility;





PROCEDURE NullGoToCheckProc(    Outline     : AnOutlineView;
                                Tree        : ATree;
                            VAR Code        : ACode         );

BEGIN                       (* NullGoToCheckProc *)
END NullGoToCheckProc;





PROCEDURE DoGoTo (      Tree        : ATree;
                        Ulx         : ascreenx;
                        Uly         : ascreeny;
                        Lrx         : ascreenx;
                        Lry         : ascreeny;
                    VAR Title       : ARRAY OF CHAR;
                        OpenTree    : BOOLEAN;
                        CheckProc   : AGoToCheckProc;
                        NameProc    : AGoToNameProc;
                    VAR StartNode   : ATreeNode     )
                                                     : BOOLEAN;
BEGIN
    RETURN DoGoToWithPrompts( Tree, Ulx, Uly, Lrx, Lry, Title, OpenTree,
                              CheckProc, NameProc, AGoToNameProc(NIL), 
                              ABoxType{}, StartNode );
END DoGoTo;


(* END FROM GOTO OLD ********************** *)



PROCEDURE DoGoToWithPrompts (       Tree        : ATree;
                                    Ulx         : ascreenx;
                                    Uly         : ascreeny;
                                    Lrx         : ascreenx;
                                    Lry         : ascreeny;
                                VAR Title       : ARRAY OF CHAR;
                                    OpenTree    : BOOLEAN;
                                    CheckProc   : AGoToCheckProc;
                                    NameProc    : AGoToNameProc;
                                    PromptProc  : AGoToNameProc;
                                    MouseKeys   : ABoxType;
                                VAR StartNode   : ATreeNode    )
                                                    : BOOLEAN;

VAR
    Outline         : AGoToOutline;
    FirstNode       : ATreeNode;
    ParentNode      : ATreeNode;
    Event           : AnEvent;
    TheRug          : ARug;
    LocalBoxType    : ABoxType;
    RugTaken,
    Changed         : BOOLEAN;
    NillString      : ARRAY [0..1] OF CHAR;
    


    PROCEDURE Resynch();
    BEGIN
        Tree^.Methods^.TraverseTree (Tree, ParentBeforeChild, 9999,
                                     SaveVisibility, ADR(OpenTree));

        Outline^.Methods^.ResetMatching (Outline);

    END Resynch;


    PROCEDURE DoPrompt();
    VAR
        s               : ARRAY [0..200] OF CHAR;

    BEGIN
        IF (PromptProc <> AGoToNameProc(NIL)) THEN
            PromptProc( Outline^.Methods^.GetCursorNode( Outline ), s );
            Message(s);
        END;
    END DoPrompt;


BEGIN

    Event.EventCode := 0;
    Changed := FALSE;

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
        MouseKeys := MouseKeys * ABoxType{HasInsert,HasDelete,HasEdit,HasHelp};  (* 01-Aug-91 *)
        LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll };  (* 5-Jan-89 MWP *)
        LocalBoxType := LocalBoxType + MouseKeys;
    ELSE
        LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;


    IF (NOT CreateGoToOutline (Outline, NIL, Ulx, Uly, Lrx, Lry, NameProc,
            LocalBoxType, videonormal, Title, ModuleNumber,  (* 05-Mar-88 LAA *)
            TRUE)) THEN

        DisplayMessage (ModuleNumber);     (* "Not enough memory for the view" *)
        Burp ();
        RETURN FALSE;
    END;

    RugTaken := GetRug( 0, 0, maxcol, 2, TheRug );  (* RSC 15-Jun-89 *)

    ValidateGoToOutline (Outline);
    Outline^.Methods^.SetObject (Outline, Tree);
    Resynch();
    Outline^.Methods^.SetCursor (Outline, TRUE);
    FirstNode := Tree^.Methods^.GetFirstVisible (Tree);
    Outline^.Methods^.SetFirst (Outline, FirstNode);

    IF (StartNode = ATreeNode(NIL)) THEN        (* 14-Sep-89 WKH *)
        Outline^.Methods^.SetCursorNode (Outline, FirstNode);
    ELSE
        Outline^.Methods^.SetCursorNode (Outline, StartNode);
    END;

    ValidateGoToOutline (Outline);
    
    LOOP
        Outline^.Methods^.Display (Outline);
        DoPrompt();
        GetNextEvent (Event);

        CheckProc(AnOutlineView(Outline), Tree, Event.EventCode);
        IF (Event.EventCode = 511) THEN
            Resynch();
            Event.EventCode := 0;
        END;

        CASE Event.EventCode OF
            RepeatKey :                                           (* 29-Dec-87 LAA *)
                IF (NOT Outline^.Methods^.FindChar (Outline, CHR(Event.EventCode))) THEN
                    Outline^.Methods^.ActOnEvent (Outline, Event, Event);
                ELSE
                    Event.EventCode := 0;
                END;

        |   DemoteKey,
            PromoteKey,
            MoveUpKey,
            MoveDownKey,
            OpenKey,
            CloseKey:
                IF (Outline^.Methods^.FindChar (Outline, CHR(Event.EventCode))) THEN  (* 29-Dec-87 LAA *)
                    Event.EventCode := 0;
                END;
        ELSE
            Outline^.Methods^.ActOnEvent (Outline, Event, Event);
        END;

        CASE Event.EventCode OF
            0 :;
        |   CancelKey :
                EXIT;
        |   DoIt, ExitKey :
                StartNode := Outline^.Methods^.GetCursorNode (Outline);
                Changed := TRUE;
                EXIT;
        ELSE
            Burp ();
        END;
    END;

    SetLengthOf( NillString, 0 );
    Message(     NillString );

    Outline^.Methods^.ResetMatching (Outline);

    Tree^.Methods^.TraverseTree (Tree, ParentBeforeChild, 9999,
                                 RestoreVisibility, ADR(OpenTree));

    IF (RugTaken) THEN
        PutRug( 0, 0, maxcol, 1, TheRug );  (* RSC 15-Jun-89 *)
    END;

    Outline^.Methods^.Discard (Outline);

    IF (Changed) AND (StartNode <> NIL) THEN

        (* 19-Sep-89 WKH code used to be here to handle filters *)
        (*               Not a good                             *)

                (* Now open up all ancestors of this node *)

        ParentNode := StartNode^.Methods^.Parent (StartNode);
        WHILE (ParentNode <> NIL) DO
            ParentNode^.Methods^.SetChildrenVisible (ParentNode, TRUE);
            ParentNode := ParentNode^.Methods^.Parent (ParentNode);
        END;
    END;
    RETURN Changed;
END DoGoToWithPrompts;




(*PROCEDURE DoTheWork();*)

(*TYPE*)
(*    AContextRecord = RECORD*)
(*                        Tree        : ATree;*)
(*                        Ulx         : ascreenx;*)
(*                        Uly         : ascreeny;*)
(*                        Lrx         : ascreenx;*)
(*                        Lry         : ascreeny;*)
(*                        Title       : ARRAY [0..80] OF CHAR;*)
(*                        OpenTree    : BOOLEAN;*)
(*                        CheckProc   : AGoToCheckProc;*)
(*                        NameProc    : AGoToNameProc;*)
(*                        PromptProc  : AGoToNameProc;*)
(*                        StartNode   : ATreeNode;*)
(*                        DoIt        : BOOLEAN;*)
(*                     END;*)

(*VAR*)
(*    Context     : POINTER TO AContextRecord;*)

(*BEGIN*)
(*    Context := OverlayContext();*)
(*    WITH Context^ DO*)
(*        DoIt := DoGoToWithPrompts (Tree, Ulx, Uly, Lrx, Lry, Title,*)
(*                                   OpenTree, CheckProc, NameProc, PromptProc,*)
(*                                   StartNode);*)
(*    END;*)
(*END DoTheWork;*)







BEGIN

(*    OverlayID := ImAnInstallableOverlay( AnOverlayProc(DoTheWork), AnOverlayProc(NIL) );*)
(*    DoTheWork();*)

(*END TLGoTo.*)
END GoTo.
