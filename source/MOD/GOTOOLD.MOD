IMPLEMENTATION MODULE GoTo;

(*  =========================================================================
    Last Edit : January 18, 1990 6:09PM by WKH
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
        18-Jan-90 EGK   DoGoToWithPrompts now calls TLGOTO overlay.
    =========================================================================
*)

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  FatalError, Error, Burp, Message, ContinuationBox;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode, 
    (* CONST *)                 maxrow, maxcol,
    (* PROC *)                  PutString, EraseLn;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Overlay, SubStr, Procustes,
                                SetString, SetLengthOf, LengthOf, Upshift,
                                Copy;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
                                ATreeNodeAttribute, ATreeNodeProcessingProc;


CONST
    ModuleNumber = 19900;


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
                              CheckProc, NameProc, AGoToNameProc(NIL), StartNode );
END DoGoTo;









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
                                VAR StartNode   : ATreeNode    )
                                                    : BOOLEAN;
TYPE
    AContextRecord = RECORD
                        Tree        : ATree;
                        Ulx         : ascreenx;
                        Uly         : ascreeny;
                        Lrx         : ascreenx;
                        Lry         : ascreeny;
                        Title       : ARRAY [0..80] OF CHAR;
                        OpenTree    : BOOLEAN;
                        CheckProc   : AGoToCheckProc;
                        NameProc    : AGoToNameProc;
                        PromptProc  : AGoToNameProc;
                        StartNode   : ATreeNode;
                        DoIt        : BOOLEAN;
                     END;
VAR
    Context         : AContextRecord;
    OverlayName     : ARRAY [0..19] OF CHAR;

BEGIN
    Context.Tree        := Tree;
    Context.Ulx         := Ulx;
    Context.Uly         := Uly;
    Context.Lrx         := Lrx;
    Context.Lry         := Lry;
    Copy (Title, Context.Title);
    Context.OpenTree    := OpenTree;
    Context.CheckProc   := CheckProc;
    Context.NameProc    := NameProc;
    Context.PromptProc  := PromptProc;
    Context.StartNode   := StartNode;
    Context.DoIt        := FALSE;

    SetString( OverlayName, "TLGOTO" );

    IF (CallOverlayWithContext (OverlayName, ADR(Context))) THEN
        StartNode := Context.StartNode;
    END;

    RETURN Context.DoIt;

END DoGoToWithPrompts;











END GoTo.
