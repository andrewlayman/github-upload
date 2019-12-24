IMPLEMENTATION MODULE FilterOutlines;        (*  a subclass of OutlineViews  *)

(*  =========================================================================
    Last Edit : September 17, 1989 3:45PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        23-Dec-87 LAA   The numeric zero key (Shift insert) will create a new
                        filter only if we're not in type-through.  
        16-Nov-88 EGK   CreateFilterOutline Discards if error is posted.
        10-Jan-89 RSC   Changed Storage to Space    .
        30-May-89 AJL   Moved filter records to FlexStor.
        10-Jun-89 WKH   Added variable screen row support.
        31-Jul-89 KKC   Call ContinuationBox instead of NoYes.
        21-Aug-89 EGK   Import procs from FilterUtility instead of FilterRc.
        17-Sep-89 WKH   Make EditKey on first node(---Clear---) act just like
                        InsertKey.
        27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                        so we can limit mouse actions to the screen region on 
                        which the mouse button was originally pressed.
         5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                        instance variable is now defined in ListViews instead
                        of OutlineViews.
                        Also moved the initialization of TypeThroughEnabled,
                        as it's now init'ed to FALSE by InitAsOutlineView.
    =========================================================================
*)

(*V9=DEBUGGING Code*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  ContinuationBox;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes;

FROM Dialog                 IMPORT
    (* PROC *)                  Burp, Error, FatalError, NotYetImplemented;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError,
                                AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecord, AFilterRecordPointer,
    (* VAR  *)                  FilterTree,
    (* PROC *)                  DeleteFilter;

FROM FilterSelect           IMPORT
    (* PROC *)                  DoFilterForm;

FROM FilterUtility          IMPORT
    (* PROC *)                  FilterDefaults, CreateFilter, SortFilters;

FROM FilterViews              IMPORT
    (* TYPE *)                  AFilterView,
    (* PROC *)                  CreateFilterView;

FROM FlexStor        IMPORT
   (* TYPES *)           AnExtHandle, AnExtStoragePreference,
   (* PROCS *)           HandleIsValid, DiscardExtObject,
                         GetExtData, ReleaseObject, ReleaseUnchangedObject;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 JoinKey, UnJoinKey, CancelKey, OpenKey,
                                InsertKey, DeleteKey, EditKey, CopyKey,
                                PromoteKey, DemoteKey, MoveUpKey, MoveDownKey,
                                CloseKey;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, Copy, SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineViewMethods, AnOutlineView,
    (* PROC *)                  InitAsOutlineView, UnInitAsOutlineView,
                                ValidateOutlineView, CloneOutlineViewMethods;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Schedule               IMPORT
    (* VAR  *)                  ScheduleSaved;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE, SIZE;


FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  AssignText;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTreeNode;


CONST
    ModuleNumber            = 16400;


TYPE
        (*  AFilterOutline is a subclass of AnOutlineView  *)

    XFilterOutline            = POINTER TO XFilterOutlineRecord;

    XFilterOutlineRecord      = RECORD
                                Methods        : AFilterOutlineMethods;
                                ViewObject     : ATree;
                                ParentView     : AnActiveView;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AFilterOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                    AFilterView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                (* New fields for outline views *)
                                MatchCount          : CARDINAL;
                                MatchString         : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled  : BOOLEAN;
                                MatchCodeSet        : ASetOfCodes;
                                NameProc            : AGoToNameProc;
                              END;




VAR
    FilterOutlineMethodsRecord : AFilterOutlineMethodsRecord;






PROCEDURE DiscardSubViews(    FilterOutline   : XFilterOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH FilterOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;





PROCEDURE GetFilterName   (    Node         : ATreeNode;
                             VAR s          : ARRAY OF CHAR );
VAR
    FilterPtr         : AFilterRecordPointer;

BEGIN               (* FilterViewGetTitle *)

    FilterPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    Copy (FilterPtr^.Name, s);
    Node^.Methods^.UnlockUnchangedDataObject (Node);
    FilterPtr := NIL;

END GetFilterName;






PROCEDURE FilterOutlineDiscard(VAR FilterOutline : XFilterOutline);

BEGIN                       (* FilterOutlineDiscard *)

    UnInitAsFilterOutline(AFilterOutline(FilterOutline));
    DISPOSE(FilterOutline);

END FilterOutlineDiscard;



PROCEDURE FilterOutlineActOn (  FilterOutline   : AFilterOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent        );
VAR
    PrivateFilterOutline    : XFilterOutline;
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    Filter                  : AFilterRecordPointer;
    Msg                     : ARRAY [0..255] OF CHAR;
    Node, FirstNode         : ATreeNode;
    NeedToSynch             : BOOLEAN;



    PROCEDURE HandleErrors(    ErrorMarker : AnErrorMarker);

    VAR
        Category                : CARDINAL;
        Code                    : CARDINAL;
        i                       : CARDINAL;
        s                       : ARRAY [0..255] OF CHAR;

    BEGIN

        i := 0;
        REPEAT
            GetErrorDetails(ErrorMarker, i, Category, Code);
            IF ((Category = NotPossibleInContextError) OR 
               (Category = UnknownEventError)) THEN
                Burp();
            ELSIF (Category <> 0) THEN
                (* Call WhatTheHell here *)
                GetMessage(Code, s);
                Error(s);
            END;
            INC(i);
        UNTIL (Category = 0);

    END HandleErrors;



    PROCEDURE DoInsertKey ();
    BEGIN
        IF (CreateFilter (Node)) THEN
            IF (DoFilterForm (Node) = CancelKey) THEN
                DeleteFilter (Node);
            ELSE
                FirstNode^.Methods^.DeList (FirstNode);
                FilterTree^.Methods^.AddFirst (FilterTree, Node);
                SortFilters();
                FilterTree^.Methods^.AddFirst (FilterTree, FirstNode);
                NeedToSynch := TRUE;
            END;
        ELSE
            PostError (AllocationError, ModuleNumber+5);
        END;
    END DoInsertKey;


    PROCEDURE DoDeleteKey ();

    VAR
        NextNode                : ATreeNode;
        WasDeleted              : BOOLEAN;
        PrivateFilterOutline    : XFilterOutline;


        PROCEDURE OKToDelete(Node : ATreeNode) : BOOLEAN;
        VAR
            OK          : BOOLEAN;
            NullString  : ARRAY [0..0] OF CHAR;
        BEGIN
            Filter := Node^.Methods^.LockFlexStorDataObject (Node);
            GetMessage (ModuleNumber + 6, Msg);
            ConcatLS (Msg, Filter^.Name);
            ConcatMessage (Msg, ModuleNumber + 3);
            SetLengthOf(NullString, 0);
            OK := ContinuationBox (Msg, NullString, NoHelp);
            IF (OK) AND (0 IN Filter^.FilterFlags) THEN
                GetMessage (ModuleNumber + 7, Msg);
                OK := ContinuationBox (Msg, NullString, NoHelp);
            END;
            Node^.Methods^.UnlockUnchangedDataObject (Node);
            Filter := NIL;
            RETURN OK;
        END OKToDelete;

    BEGIN
        Node := FilterOutline^.Methods^.GetCursorNode (FilterOutline);
        IF (Node <> FirstNode) THEN

            PrivateFilterOutline := XFilterOutline (FilterOutline);
            FilterOutline^.Methods^.SetCursorMode (FilterOutline, videorestingcursor);
            FilterOutline^.Methods^.Display (FilterOutline);
            WasDeleted := OKToDelete (Node);
            FilterOutline^.Methods^.SetCursorMode
                    (FilterOutline, PrivateFilterOutline^.VideoMode);
            IF (WasDeleted) THEN
                NextNode := Node^.Methods^.GetNext (Node);
                IF (NextNode = NIL) THEN
                    NextNode := Node^.Methods^.GetPrev (Node);
                END;
                DeleteFilter (Node);
                Node := NextNode;
                NeedToSynch := TRUE;
            END;
        ELSE
            PostError (NotPossibleInContextError, ModuleNumber);
        END;
    END DoDeleteKey;


    PROCEDURE DoEditKey ();

    BEGIN
        Node := FilterOutline^.Methods^.GetCursorNode (FilterOutline);
        IF (Node <> FirstNode) THEN
            IF (DoFilterForm (Node) <> CancelKey) THEN
                FirstNode^.Methods^.DeList (FirstNode);
                SortFilters ();
                FilterTree^.Methods^.AddFirst (FilterTree, FirstNode);
                NeedToSynch := TRUE;
            END;
        ELSE
            DoInsertKey();
        END;
    END DoEditKey;

    (*$S+*)

    PROCEDURE DoCopyKey ();
    VAR
        OldFilterHandle : AnExtHandle;
        OldFilter   : AFilterRecord;
    BEGIN
        Node := FilterOutline^.Methods^.GetCursorNode (FilterOutline);
        IF (Node <> NIL) AND (Node <> FirstNode) THEN
                (* Copy the old filter to local storage. *)
            OldFilterHandle := AnExtHandle(Node^.Methods^.GetDataObject (Node));
            IF (GetExtData(OldFilterHandle,ADR(OldFilter)) <> SIZE(OldFilter)) THEN
                FatalError();
            END;
 
            IF (CreateFilter (Node)) THEN
                Filter := Node^.Methods^.LockFlexStorDataObject (Node);
                Filter^ := OldFilter;
                Filter^.Notes := AText(NIL);
                IF (AssignText(OldFilter.Notes, Filter^.Notes)) THEN END;
                Node^.Methods^.UnlockFlexStorDataObject (Node);
                Filter := NIL;

                IF (DoFilterForm (Node) = CancelKey) THEN
                    DeleteFilter (Node);
                ELSE
                    FirstNode^.Methods^.AddAfter (FirstNode, Node);
                    FirstNode^.Methods^.DeList (FirstNode);
                    SortFilters ();
                    FilterTree^.Methods^.AddFirst (FilterTree, FirstNode);
                    NeedToSynch := TRUE;
                END;
            ELSE
                PostError (AllocationError, ModuleNumber+5);
            END;
        ELSE
            PostError (NotPossibleInContextError, ModuleNumber);
        END;
    END DoCopyKey;

    (*$S=*)

BEGIN               (* FilterOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateFilterOutline (FilterOutline);
    END;
      DEBUGGING>*)

    ErrorMarker := NewMarker ();

    CASE Event.EventCode OF
        OpenKey,
        CloseKey,
        PromoteKey,
        DemoteKey,
        MoveUpKey,
        MoveDownKey :;
            IF (NOT FilterOutline^.Methods^.FindChar
                    (FilterOutline,CHR(Event.EventCode))) THEN
                PostError (NotPossibleInContextError, ModuleNumber+1);
            ELSE
                Event.EventCode := 0;
            END;
    ELSE
            FilterOutlineMethodsRecord.SuperclassMethods^.ActOnEvent
                (AnOutlineView (FilterOutline), Event, ReturnEvent);
            Event := ReturnEvent;
    END;


    ReturnEvent.EventCode := 0;
    WantToRecord := TRUE;

    NeedToSynch := FALSE;
    FirstNode := FilterTree^.Methods^.GetFirst (FilterTree);

    CASE Event.EventCode OF
        InsertKey :
            DoInsertKey ();
    |   DeleteKey :
            DoDeleteKey ();
    |   EditKey :
            DoEditKey ();
    |   CopyKey :
            PrivateFilterOutline := XFilterOutline(FilterOutline);
            IF (PrivateFilterOutline^.MatchCount > 0) THEN        (* 23-Dec-87 LAA *)
                WITH FilterOutlineMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AnOutlineView(FilterOutline),Event,
                               ReturnEvent);
                END;
                WantToRecord := (ReturnEvent.EventCode <> 0);
            ELSE
                DoCopyKey ();
            END;
    ELSE
        ReturnEvent := Event;
        WantToRecord := FALSE;
    END;

    IF (NeedToSynch) THEN
        FilterOutline^.Methods^.ResetMatching (FilterOutline);
        FilterOutline^.Methods^.SetFirst (FilterOutline, Node);
        FilterOutline^.Methods^.SetCursorNode (FilterOutline, Node);
        ScheduleSaved := FALSE;
    END;

    IF (WantToRecord) THEN
        FilterOutline^.Methods^.RecordEvent (FilterOutline, Event);
    END;

    IF (ErrorPosted (ErrorMarker)) THEN
        HandleErrors (ErrorMarker);
    END;
    PopToMarker (ErrorMarker);

END FilterOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsFilterOutline --

    Initialize the indicated object as a filter outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid filter outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsFilterOutline(    FilterOutline : AFilterOutline;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      );

VAR
    PrivateFilterOutline      : XFilterOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsFilterOutline *)

    InitAsOutlineView(AnOutlineView(FilterOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    PrivateFilterOutline := XFilterOutline(FilterOutline);
    WITH PrivateFilterOutline^ DO
        TypeThroughEnabled := TRUE;
        NameProc := GetFilterName;
        Methods := ADR(FilterOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateFilterView(SubView[Last + 1], AnActiveView(FilterOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateFilterOutline);

                PostError(ModuleNumber, AllocationError);
    
                RETURN;
            END;
            INC(Last);
        END;
    END;

END InitAsFilterOutline;





(*----------------------------------------------------------------------------
    CreateFilterOutline --

    Allocate storage for, and initialize the indicated object as a filter 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid filter outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateFilterOutline(VAR FilterOutline : AFilterOutline;
                                SuperView   : AnActiveView;
                                Ulx         : ascreenx;
                                Uly         : ascreeny;
                                Lrx         : ascreenx;
                                Lry         : ascreeny;
                                Box         : ABoxType;
                                VideoMode   : avidmode;
                            VAR Title       : ARRAY OF CHAR;
                                HelpKey     : CARDINAL;
                                TakeRug     : BOOLEAN      ) 
                                                            : BOOLEAN;

VAR
    ErrorMarker             : AnErrorMarker;
    ok                      : BOOLEAN;

BEGIN                       (* CreateFilterOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XFilterOutlineRecord))) THEN
        ALLOCATE(FilterOutline, TSIZE(XFilterOutlineRecord));
        InitAsFilterOutline(FilterOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                            VideoMode, Title, HelpKey, TakeRug);

        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
            FilterOutline^.Methods^.Discard (FilterOutline);        (* 11/16/88 EGK *)
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateFilterOutline;







(*----------------------------------------------------------------------------
    UnInitAsFilterOutline --

    UnInitialize the indicated object as a filter outline view.

    Preconditions:
        The object will be a valid filter outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsFilterOutline(    FilterOutline : AFilterOutline);


BEGIN                       (* UnInitAsFilterOutline *)

    DiscardSubViews(XFilterOutline(FilterOutline));
    UnInitAsOutlineView(AnOutlineView(FilterOutline));

END UnInitAsFilterOutline;







(*----------------------------------------------------------------------------
    CloneFilterOutlineMethods --

    Make a copy of the filter outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The filter outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneFilterOutlineMethods(    MethodObject : AFilterOutlineMethods);

BEGIN                       (* CloneFilterOutlineMethods *)

    MethodObject^ := FilterOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(FilterOutlineMethodsRecord);
END CloneFilterOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateFilterOutline --

    Determine that the indicated object is in fact a valid filter outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid filter outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateFilterOutline(    FilterOutline : AFilterOutline);

VAR
    PrivateFilterOutline      : XFilterOutline;

BEGIN                       (* ValidateFilterOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(FilterOutline));
    END;
      DEBUGGING>*)

    PrivateFilterOutline := XFilterOutline(FilterOutline);
    IF (PrivateFilterOutline^.Methods^.FilterOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateFilterOutline;





BEGIN                       (* FilterOutlines *)

    CloneOutlineViewMethods(ADR(FilterOutlineMethodsRecord));
    WITH FilterOutlineMethodsRecord DO
        MethodSize := TSIZE(AFilterOutlineMethodsRecord);
        Discard := AFilterOutlineDiscardProc(FilterOutlineDiscard);
        ActOnEvent := AFilterOutlineActOnProc (FilterOutlineActOn);
        FilterOutlineTag := ModuleNumber;
    END;

END FilterOutlines.
