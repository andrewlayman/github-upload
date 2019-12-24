(*V1=NORMAL Version*)
(*V8=GELDED Version for debugging*)

MODULE TLFSelct;

(*  =========================================================================
    Last Edit : September 21, 1989 2:13PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

    5/6/87 EGK      Many changes (mostly deletions) to re-implement the
                    filter list using object-oriented scheme.  Moved
                    CreateFilter and DeleteFilter to FilterOutlines module,
                    removed ForAllFilters and the internal SelectFilterNames
                    module, and re-coded SelectFilterName and SortFilters to
                    use the new filter list object.

    5/7/87 EGK      Minor changes to fix problems with phrase file numbers.

    01-Jun-87 LAA   Recoded MustFind to use the new methods of TreeObjects
                    instead of FindTask, which is no longer in Allocs.
    7/6/87  EGK     Replaced DoFilterNamesForm with ChooseFilter, which uses
                    a menu.
    7/9/87  EGK     The user-selected highlight filter is now Highlight1,
                    since we now have a total of four highlight filters.
    22-Sep-87 LAA   Incorporated form changes proposed by DSB, and in process
                    added field number constants and consolidated code.
    15-Oct-87 RSC   Added Shadows to boxes.  Added parameter to EditText.
    19-Oct-87 EGK   Call ResetMatching when filter list is put up.
    28-Oct-87 RSC   Notify forms when text has been edited.
    05-Nov-87 LAA   Fixed bug under which Shift-F8 acted like F2 on the notes
                    field.
    06-Nov-87 RSC   ljust wbs, obs, and notes.
    18-Dec-87 EGK   Moved DoFilterForm into TLFILTER overlay.
    23-Dec-87 LAA   Fixed DoFilterForm to return CancelKey if there's any
                    problem with the overlay.
    02-Mar-88 LAA   Forced TLFBASE to load on the heap, not in reserved layer.
    05-Mar-88 LAA   Pass this module's module number as the help number.
    31-Oct-88 EGK   Put up a message after clearing select filter.
    23-Jan-89 EGK   Created this overlay from the old FilterSelect module.
    30-May-89 AJL   Moved filter records to FlexStor.
    19-Jun-89 AJL   Removed FiltersOn boolean.
    09-Aug-89 KKC   Add copyright message.
    21-Aug-89 EGK   Import procs from FilterUtility instead of FilterRc.
    12-Sep-89 WKH   Make Filter boxes bigger in 50 line mode
    21-Sep-89 WKH   Don't allow filter boxes to "grow" anymore, too slow
    14-Dec-89 MWP   Added checking for existence of rodents.
    27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                    the same thing.
     5-Jan-90 MWP   Put the Ok button back in.
     6-Oct-90 AJL   Add insert and delete mouse buttons.
    =========================================================================
*)



FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskFilter;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState, DisplayTheChart;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, Burp;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

(*<NORMAL*)
FROM FilterOutlines         IMPORT
    (* TYPE *)                  AFilterOutline,
    (* PROC *)                  CreateFilterOutline;
(*NORMAL>*)

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecord, AFilterRecordPointer, AFltrType,
                                AFltrSet, ASlackCheck, AFilterMatch,
    (* VAR *)                   FilterTree,
                                RevealFilter, HighlightFilter,
                                EmptyFilterSet,
    (* PROC *)                  DeleteFilter;

FROM Filters                IMPORT
    (* PROC *)                  ShowFilterLight,
                                QueryRevealFilterOn;

FROM FilterUtility          IMPORT
    (* PROC *)                  CreateFilter, FindFilterByName;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreeny, ascreenx, avidmode,
    (* VAR  *)                  maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, ExitKey, InsertKey, DeleteKey,
                                EditKey, BackSpace, CopyKey;

FROM LStrings               IMPORT
    (* PROC *)                  SubStr, Fill, Compare, TrimRear, LJust, Copy,
                                ConcatLS, TrimFront, Upshift, Remove, Search,
                                Procustes, SetLengthOf, LengthOf, SetString;

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

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree;


CONST
    ModuleNumber            = 17100;


VAR
    OverlayID               : AnOverlayID;


(*<NORMAL*)






(*----------------------------------------------------------------------------
    SelectFilterName --

    Display a picklist of filter names, with the cursor initially on the one
    passed into Selected, and allow the user to select a name.  Selected will
    be changed only if something is selected, and TRUE will be returned.  The
    edit key will allowed only if AllowEdit is TRUE.
----------------------------------------------------------------------------*)

PROCEDURE SelectFilterName(    Variety      : ATaskFilter;
                               ULX          : ascreenx;            (* in     *)
                               ULY          : ascreeny;            (* in     *)
                               LRX          : ascreenx;            (* in     *)
                               LRY          : ascreeny;            (* in     *)
                           VAR SelectedName : ARRAY OF CHAR)       (* in/out *)
                                                            : BOOLEAN;

(*<NORMAL*)

VAR
    FilterOutline           : AFilterOutline;
    Filter                  : AFilterRecordPointer;
    s                       : ARRAY [0..80] OF CHAR;
    Title                   : ARRAY [0..20] OF CHAR;
    Node                    : ATreeNode;
    FirstNode               : ATreeNode;
    Event                   : AnEvent;
    LocalBoxType            : ABoxType;

(*NORMAL>*)


BEGIN                       (* SelectFilterName *)

    (*<NORMAL*)

    Event.EventCode := 0;
    GetMessage (ModuleNumber+ORD(Variety)+12, Title);

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll,
                               HasInsert,HasDelete }; (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;

    IF (CreateFilterOutline (FilterOutline, NIL, ULX, ULY, LRX, LRY,
            LocalBoxType, 
            videonormal, Title, ModuleNumber, TRUE)) THEN         (* 05-Mar-88 LAA *)

        IF (CreateFilter (FirstNode)) THEN
            FilterTree^.Methods^.AddFirst (FilterTree, FirstNode);
            Filter := FirstNode^.Methods^.LockFlexStorDataObject (FirstNode);
            GetMessage (ModuleNumber+20,Filter^.Name);      (* "Clear" *)
            FirstNode^.Methods^.UnlockFlexStorDataObject (FirstNode);
            Filter := NIL; 
            Copy (SelectedName, s);
            TrimRear(s);
            Node := FindFilterByName (s);
            FilterOutline^.Methods^.SetObject (FilterOutline, FilterTree);
            FilterOutline^.Methods^.ResetMatching (FilterOutline);
            FilterOutline^.Methods^.SetFirst (FilterOutline, FirstNode);
            IF (Node = NIL) THEN
                FilterOutline^.Methods^.SetCursorNode (FilterOutline, FirstNode);
            ELSE
                FilterOutline^.Methods^.SetCursorNode (FilterOutline, Node);
            END;
            FilterOutline^.Methods^.SetCursor (FilterOutline, TRUE);

            LOOP
                FilterOutline^.Methods^.Display (FilterOutline);
                GetNextEvent (Event);
                FilterOutline^.Methods^.ActOnEvent (FilterOutline, Event, Event);
                CASE Event.EventCode OF
                    0 :;
                |   CancelKey :
                        EXIT;
                |   DoIt, ExitKey :
                        Node := FilterOutline^.Methods^.GetCursorNode (FilterOutline);
                        IF (Node <> NIL) THEN
                            Filter := Node^.Methods^.LockFlexStorDataObject (Node);
                            Copy (Filter^.Name, SelectedName);
                            Node^.Methods^.UnlockUnchangedDataObject (Node);
                            Filter := NIL;
                        ELSE
                            Fill (SelectedName, " ", 0);
                        END;
                        EXIT;
                ELSE
                    Burp();
                END;
            END;
            DeleteFilter (FirstNode);
        ELSE
            DisplayMessage (ModuleNumber);
            Burp ();
        END;
        FilterOutline^.Methods^.Discard (FilterOutline);
    ELSE
        DisplayMessage (ModuleNumber);
        Burp ();
    END;

    RETURN (Event.EventCode = DoIt) OR (Event.EventCode = ExitKey);

    (*NORMAL>*)

    (*<GELDED
    RETURN FALSE;
    GELDED>*)

END SelectFilterName;




PROCEDURE ChooseFilter ( Variety    : ATaskFilter);
VAR
    Filter          : AFilterRecordPointer;
    Node            : ATreeNode;
    i               : CARDINAL;
    Name            : ARRAY [0..21] OF CHAR;
    Changed         : BOOLEAN;
BEGIN
    Changed := FALSE;
    IF (Variety = Selected) THEN
        IF (RevealFilter = NIL) THEN
            SetLengthOf (Name, 0);
        ELSE
            Filter := RevealFilter^.Methods^.LockFlexStorDataObject (RevealFilter);
            Copy (Filter^.Name, Name);
            RevealFilter^.Methods^.UnlockUnchangedDataObject (RevealFilter);
            Filter := NIL;
        END;
        IF (SelectFilterName (Selected,20,6,45,maxrow-4,Name)) THEN (* 12-Sep-89 WKH *)
            Changed := TRUE;
            RevealFilter := FindFilterByName(Name);
            IF (QueryRevealFilterOn()) THEN
                DisplayMessage(ModuleNumber+10);
            ELSE
                DisplayMessage(ModuleNumber+30);        (* 10/31/88 EGK *)
            END;
        END;
    ELSE
        i := ORD (Variety);
        IF (HighlightFilter[i] = NIL) THEN
            SetLengthOf (Name, 0);
        ELSE
            Filter := HighlightFilter[i]^.Methods^.LockFlexStorDataObject (HighlightFilter[i]);
            Copy (Filter^.Name, Name);
            HighlightFilter[i]^.Methods^.UnlockUnchangedDataObject (HighlightFilter[i]);
            Filter := NIL;
        END;
        IF (SelectFilterName (Variety,20,6,45,maxrow-4,Name)) THEN  (* 12-Sep-89 WKH *)
            Changed := TRUE;
            HighlightFilter[i] := FindFilterByName(Name);
        END;
    END;
    IF (Changed) THEN
        ScheduleSaved := FALSE;
        UnSetState (Filtered);
        ShowFilterLight ();
    END;
END ChooseFilter;



PROCEDURE TLFSelctBody();

VAR
    Context         : POINTER TO ATaskFilter;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN                       (* TLFSelctBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    ChooseFilter (Context^);

END TLFSelctBody;



BEGIN

    OverlayID := ImAnInstallableOverlay(TLFSelctBody, AnOverlayProc(NIL));
    TLFSelctBody();

END TLFSelct.

