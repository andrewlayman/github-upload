(*V9=DEBUGGING Version*)

IMPLEMENTATION MODULE NetLList;

(*  =========================================================================
    Last Edit : September 19, 1989 5:51PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        21-Jan-88 LAA   Added NormalLayout variable, and changed ChooseNetLayout
                        to use it.  Also removed the animation form.
        28-Jan-88 LAA   Removed the layout form, and commented out the
                        animation form so that forms modules would not be
                        linked in with TLNSHOW.
        11-Feb-88 LAA   Fixed bug: typethrough not being reset.
        17-Feb-88 LAA   Title of layout list is now Standard or Alternate.
                        Imported ALLOCATE and DEALLOCATE from Space.
        23-Feb-88 LAA   Make sure the temp net layout at the top of the list
                        is not a standard layout.
        02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
        05-Mar-88 LAA   Pass ModuleNumber as help number.
        14-Mar-88 LAA   Increased size of message array in SelectNetLayout.
        12-Dec-88 LAA   Re: 02-Mar-88 comment: but TLNETFOR is!
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
         2-Jan-89 RSC   Removed references to Compare() (not used).
        10-Jan-89 RSC   Added SelectLayoutAt from NetLKludges.
        20-Mar-89 LAA   Removed import of ColumnName module (wasn't used).
        12-Sep-89 WKH   Make Network Layout lists bigger in compressed video.
        19-Sep-89 RSC   Use the start date as a default for the StoEndDate
                        routine.
        21-Sep-89 LAA   Removed all reference to Animation.  Also cleaned up
                        the import list a bit, and remove the GrowBox
                        attribute.
        25-Sep-89 EGK   Import procs from NetLUtility instead of NetLayouts.
        14-Dec-89 MWP   Added checking for existence of rodents.
        27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                        the same thing.
        5-Jan-90 MWP    Put the Ok button back in.
        6-Oct-90 AJL    Add insert and delete mouse buttons.
    =========================================================================
*)



FROM Boxes                  IMPORT ABoxType, ABoxAttribute;

FROM Codes                  IMPORT ACode, EmptyCodeSet;

FROM Dialog                 IMPORT Burp, Message, Error, FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM Kbio                   IMPORT maxrow, maxcol, ascreenx, ascreeny, soundon, 
                                   avidmode;

FROM Keys                   IMPORT ExitKey, DoIt, InsertKey, DeleteKey, CancelKey,
                                   SelectKey;

FROM Layout                 IMPORT GanttWEnd;

FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Insert, Procustes, TrimFront, TrimRear, Fill, 
                                   LengthOf, Copy, LJust, SetLengthOf,
                                   Upshift;

FROM   Mouse        IMPORT
    (* PROC *)          MousePresent;                               (* 14-Dec-89 MWP *)

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout, 
    (* VAR *)                   NetLayoutTree, CurrentNetLayout, 
                                NormalLayoutActive,
                                EnlargedNetLayout;

FROM NetLUtility            IMPORT
    (* PROC *)                  CreateNetLayout, DiscardNetLayout, 
                                SortNetLayouts;

FROM NetLOutlines           IMPORT
    (* TYPE *)                  ANetLOutline,
    (* PROC *)                  CreateNetLOutline;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  CreateTree, CreateTreeNode, ValidateTreeNode;


CONST
    ModuleNumber            = 20800;    (* For GetMessage. *)
    MAXCARDINAL             = 0FFFFH;



(*----------------------------------------------------------------------------
    DoNetLayoutForm --

    Bring up the layout form to allow editing of a layout record.

    Preconditions:
        The layout parameter must be a valid layout node.

    Postconditions:
        The layout record will be changed as directed by the user, unless the
        form is left with ESC.  The code will be returned.
----------------------------------------------------------------------------*)

PROCEDURE DoNetLayoutForm(    LayoutNode    : ATreeNode)
                                                        : ACode;

TYPE
    AContext                = RECORD
                                NetLayout   : ATreeNode;
                                Code        : ACode;
                              END;
VAR
    Context                 : AContext;
    s                       : ARRAY [0..31] OF CHAR;

BEGIN                       (* DoNetLayoutForm *)

    (*<DEBUGGING*)
    ValidateTreeNode(LayoutNode);
    (*DEBUGGING*)

    WITH Context DO
        NetLayout := LayoutNode;
        Code := CancelKey;
    END;

    SetString(s, "\TLFBASE(|TLNETFOR)");                           (* 02-Mar-88 LAA *) (* 12-Dec-88 LAA *)
    IF (CallOverlayWithContext(s, ADR(Context))) THEN END;

    RETURN Context.Code;

END DoNetLayoutForm;






(*----------------------------------------------------------------------------
    SelectNetLayout --

    Display a list of the named layouts, defaulting the cursor position to
    the layout passed as parameter, and allow the user to select one.

    Preconditions:
        The layout passed in must be a valid layout, or it may be NIL.

    Postconditions:
        The layout parameter will be changed to reflect the user's choice,
        if a selection is made.  If the user exits with ESC, the initial
        value of the layout parameter will be preserved.  Within this call,
        it is possible to add, delete, copy and edit named layouts.
----------------------------------------------------------------------------*)

PROCEDURE SelectNetLayoutAt(VAR Layout             : ATreeNode;
                            VAR Title              : ARRAY OF CHAR;
                                ULX, ULY, LRX, LRY : CARDINAL) : ACode;

CONST
    KludgeNumber            = 20800; (* KludgeNumber is actually the module
                                        number for NetLList.  This is needed
                                        because SelectNetLayout needs to 
                                        reference phrases and helptext from the 
                                        NetLList module. *)

(*CONST
    ULX                     = 27;
    ULY                     = 5;
    LRX                     = 52;
    LRY                     = 20;*)

VAR
    LayoutOutline           : ANetLOutline;
    FirstNode               : ATreeNode;
    Event                   : AnEvent;
    TempLayout              : ATreeNode;
    LayoutPtr               : ANetworkLayout;
    LocalBoxType            : ABoxType;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* SelectNetLayout *)

    IF (NOT CreateNetLayout(TempLayout)) THEN
        GetMessage (KludgeNumber + 2, s);                         (* 14-Mar-88 LAA *)
        Error(s);
        RETURN CancelKey;
    END;

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll,
                               HasInsert,HasDelete }; (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;

    IF (CreateNetLOutline (LayoutOutline, NIL, ULX, ULY, LRX, LRY,
        LocalBoxType, 
        videonormal, Title, KludgeNumber, TRUE)) THEN             (* 05-Mar-88 LAA *)

        WITH NetLayoutTree^.Methods^ DO
            AddFirst(NetLayoutTree, TempLayout);
        END;

        LayoutPtr := TempLayout^.Methods^.GetDataObject(TempLayout);  (* 23-Feb-88 LAA *)
        EXCL(LayoutPtr^.NetLFlags, 0);


        FirstNode := NetLayoutTree^.Methods^.GetFirst(NetLayoutTree);
        LayoutOutline^.Methods^.SetObject (LayoutOutline, NetLayoutTree);
        LayoutOutline^.Methods^.ResetMatching (LayoutOutline);    (* 11-Feb-88 LAA *)
        LayoutOutline^.Methods^.SetFirst (LayoutOutline, FirstNode);
        IF (Layout = NIL) THEN
            LayoutOutline^.Methods^.SetCursorNode (LayoutOutline, FirstNode);
        ELSE
            (*<DEBUGGING*)
            ValidateTreeNode(Layout);
            (*DEBUGGING*)

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
                    EXIT;
            |   0 : ;
            ELSE
                Burp();
            END;
        END;
        IF (Layout = TempLayout) THEN
            Layout := NIL;
        END;
        DiscardNetLayout(TempLayout);
        LayoutOutline^.Methods^.Discard (LayoutOutline);
    ELSE
        GetMessage (KludgeNumber + 2, s);           (* 10/26/88 EGK *)
        Error(s);
    END;

    RETURN Event.EventCode;

END SelectNetLayoutAt;







(*----------------------------------------------------------------------------
    ChooseNetLayout --

        Allow the user to choose which layout, regular or enlarged he wants
        to set, and display a list of all layouts for him to choose from.

    Preconditions:
        NetLayouts must have been initialized in the root.

    Postconditions:
        A new layout may be selected, or any layout on the list may be edited,
        deleted, or new ones created.  Once the list is up, all features
        which apply to scrolling lists are in effect.
----------------------------------------------------------------------------*)

PROCEDURE ChooseNetLayout();

VAR
    Title                   : ARRAY [0..31] OF CHAR;

BEGIN                       (* ChooseNetLayout *)

    IF (NormalLayoutActive) THEN                                  (* 21-Jan-88 LAA *)
        GetMessage(ModuleNumber + 6, Title);                      (* 17-Feb-88 LAA *)
        IF (SelectNetLayoutAt(CurrentNetLayout,Title,27,5,52,maxrow-4) <> 
            CancelKey) THEN END;
    ELSE
        GetMessage(ModuleNumber + 7, Title);
        IF (SelectNetLayoutAt(EnlargedNetLayout,Title,27,5,52,maxrow-4) <> 
            CancelKey) THEN END;
    END;

END ChooseNetLayout;


BEGIN
END NetLList.

