IMPLEMENTATION MODULE MacroOutlines;    (* A Subclass of OutlineViews *)

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software
                  
---------------------------------------------------------------------------*)

(*  MODIFICATION HISTORY: 
    10-Jun-89 WKH   Added support for variable screen rows.
    6/14/89   LVK - Disabled CopyKey, InsertKey, DeleteKey & EditKey
                    actions in the macro list if Editing = TRUE.
    10/23/89  WKH - Disable type-through for macro list.
    13-Nov-89 RSC - Import from Space rather than Storage.
    11-Dec-89 LVK - Enabled CopyKey, InsertKey, DeleteKey & EditKey
                    actions in the macro list iff State = Neutral.
    19-Dec-89 LVK - DeleteKey now calls DisposeMacros with MacSubTree if
                    children exist.
    20-Dec-89 LVK - Modified DoInsertKey & DoCopyKey in order to keep
                    the nodes of replaced macros on the tree.
    27-Dec-89 LAA   Added MouseDownRegion to the object record definition,
                    so we can limit mouse actions to the screen region on 
                    which the mouse button was originally pressed.
     5-Jan-90 LAA   Moved the location of MouseDownRegion, because this
                    instance variable is now defined in ListViews instead
                    of OutlineViews.
                    Also removed the initialization of TypeThroughEnabled,
                    as this is now set to FALSE in InitAsOutlineView.

                    (Integrated by RSC)
    04-Jan-90 LVK - Use MacVars.StealHotkeyNode to reassign hotkey after
                    MACFORM1 is called to create a new macro in the editor,
                    (if a previous macro had the hotkey).
    13-Jan-90 LVK/LAA - Fixed a bug which caused the machine to hang if you
                        escaped off the editor when replacing a macro.
    13-Jan-90 LAA - Incorporated a change made by LVK to fix-up a stolen hot
                    key, if it occured during copying of a macro.
    30-May-91 RSC  Removed globals, put them on the stack.
*)


(*V9=DEBUGGING Code*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes, SetCodeBits;

FROM Dialog                 IMPORT
    (* PROC *)                  Burp, Error, FatalError, Message;

FROM ErrorCategories        IMPORT
    (* CONST *)                 NotPossibleInContextError, UnknownEventError,
                                AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails, PostError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;
    
FROM FlexStor               IMPORT
                                DiscardExtObject, AnExtHandle,
                                CopyExtObject;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc,
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 AbsoluteMaxRow, maxrow; 

FROM Keys                   IMPORT
    (* CONST *)                 JoinKey, UnJoinKey, CancelKey, GotoKey,
                                InsertKey, DeleteKey, EditKey, CopyKey,
                                PromoteKey, DemoteKey, MoveUpKey, MoveDownKey,
                                CloseKey;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, ConcatLS, Copy, SetString,
                                ConcatS, TrimRear;
                                
FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  (*CreateTreeNode,*)
                                ValidateTree, ValidateTreeNode;

FROM MacNodes              IMPORT
                                 MacroTree, AMacroRecordPointer;

FROM MacrosRc               IMPORT
    (* PROC *)                  MacroDefaults, CreateMacro,
                                ClearMacNode,
                                SetMacroHotKey, SetMacroHotKeyStr,
                                DeleteMacro, SortMacros, DisposeMacros,
                                GetMacroName, GetMacroLength;

FROM MacHeader             IMPORT PopMacHeaderStack, PushMacHeaderStack;

FROM MacState              IMPORT State, AState;

FROM MacStore              IMPORT StoreMacro, FillMacroRecord,
                                  StoreReplacementMacro;

FROM MacTalk               IMPORT MacDeath;

FROM MacroViews              IMPORT
    (* TYPE *)                  AMacroView,
    (* PROC *)                  CreateMacroView;
    
FROM MacVars                IMPORT SaveEdits, FormAccepted,
                                   MacStoragePreference,
                                   ReplacedKeySet, Editing,
                                   ReplacedMacro,
                                   OurEditRecord,
                                   StealHotkeyNode,
                                   MacrosModified;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineViewMethods, AnOutlineView,
    (* PROC *)                  InitAsOutlineView, UnInitAsOutlineView,
                                ValidateOutlineView, CloneOutlineViewMethods;
                                
FROM Overlays               IMPORT CallOverlay, CallOverlayWithContext;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Schedule               IMPORT
    (* VAR  *)                  ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber            = 32110;


TYPE
        (*  AMacroOutline is a subclass of AnOutlineView  *)

    XMacroOutline            = POINTER TO XMacroOutlineRecord;

    XMacroOutlineRecord      = RECORD
                                Methods        : AMacroOutlineMethods;
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
                                Status         : AMacroOutlineStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] 
                                                       OF AMacroView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* New fields for outline views *)
                                MatchCount         : CARDINAL;
                                MatchString        : ARRAY [0..80] OF CHAR;
                                TypeThroughEnabled : BOOLEAN;
                                MatchCodeSet       : ASetOfCodes;
                                NameProc           : AGoToNameProc;
                              END;


    AContext = POINTER TO BOOLEAN;


VAR
    MacroOutlineMethodsRecord : AMacroOutlineMethodsRecord;




PROCEDURE DiscardSubViews(    MacroOutline   : XMacroOutline);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH MacroOutline^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;
        Cursor := 0;
    END;

END DiscardSubViews;




PROCEDURE OurGetMacroName   (    Node       : ATreeNode;
                             VAR s          : ARRAY OF CHAR );
VAR
    MacroRecordPointer         : AMacroRecordPointer;

BEGIN               (* MacroViewGetTitle *)

    (*MacroRecordPointer := Node^.Methods^.GetDataObject (Node);
    Copy (MacroRecordPointer^.name, s);*)
    GetMacroName (Node, s);

END OurGetMacroName;





PROCEDURE MacroOutlineDiscard(VAR MacroOutline : XMacroOutline);

BEGIN                       (* MacroOutlineDiscard *)

    UnInitAsMacroOutline(AMacroOutline(MacroOutline));
    DISPOSE(MacroOutline);

END MacroOutlineDiscard;



PROCEDURE MacroOutlineActOn (  MacroOutline   : XMacroOutline;
                                Event           : AnEvent;
                            VAR ReturnEvent     : AnEvent        );
VAR
    WantToRecord            : BOOLEAN;
    ErrorMarker             : AnErrorMarker;
    MacroRecordPointer                   : AMacroRecordPointer;
    Msg                     : ARRAY [0..255] OF CHAR;
    FirstNode               : ATreeNode;
    OurMacro                : ATreeNode;
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


(*  User creates a new macro by editing *)

    PROCEDURE DoInsertKey ();
    
    VAR
      Buffer      : ARRAY [0..1] OF CARDINAL;
      S           : ARRAY [0..255] OF CHAR;
      Length      : CARDINAL;
      CursorMacro : ATreeNode;



	PROCEDURE EditMacro;
	BEGIN
          GetMacroName (OurEditRecord^.Macro, OurEditRecord^.macName);
          SetString (S, "|MACEDIT");
          IF CallOverlay (S) THEN
            IF ((NOT SaveEdits) AND (ReplacedMacro = NIL)) THEN
                DeleteMacro (OurEditRecord^.Macro);
            ELSE
                MacroOutline^.Methods^.Synchronize
                            (AMacroOutline (MacroOutline));
                MacroOutline^.Methods^.ResetMatching
                            (AMacroOutline(MacroOutline));
                MacroOutline^.Methods^.SetCursorNode
                         (AMacroOutline(MacroOutline), OurEditRecord^.Macro);
                
            END;
          END;
          ReplacedMacro := NIL;
	END EditMacro;



    BEGIN
      Length := 0;
      Buffer[0] := 0;
      Buffer[1] := 0;
      SetString (S, "MACFORM1");
      CursorMacro := MacroOutline^.Methods^.GetCursorNode
                            (AMacroOutline(MacroOutline));

      PushMacHeaderStack;
      IF (CallOverlay (S) AND FormAccepted) THEN
         IF StealHotkeyNode <> NIL THEN
           SetMacroHotKey(StealHotkeyNode, 0);
           Fill(S, ' ', 10);
           SetMacroHotKeyStr(StealHotkeyNode,S);
           StealHotkeyNode := NIL;
         END;
         IF ReplacedMacro <> NIL THEN
           OurEditRecord^.Macro := ReplacedMacro;
           IF ClearMacNode(OurEditRecord^.Macro) THEN
             IF NOT StoreReplacementMacro (Buffer, Length,
                                           OurEditRecord^.Macro) THEN
               MacDeath;
               PopMacHeaderStack;
               RETURN;
             END;
             EditMacro;
           ELSE
             MacDeath;
             PopMacHeaderStack;
             RETURN;
           END;
         ELSIF (CreateMacro (OurEditRecord^.Macro)) THEN
             IF NOT StoreMacro (Buffer, Length,
                           OurEditRecord^.Macro, CursorMacro, MacroTree) THEN
               MacDeath;
               PopMacHeaderStack;
               RETURN;
             END;
             EditMacro;
         ELSE
           PostError (AllocationError, 0);
         END;
         PopMacHeaderStack;
      END;
    END DoInsertKey;


    PROCEDURE DoDeleteKey ();
    VAR
        OurMacro               : ATreeNode;
        NextNode               : ATreeNode;
        MacSubTree             : ATree;
        name                   : ARRAY [0..40] OF CHAR;
        
        
    BEGIN
    
      WITH MacroOutline^.Methods^ DO
            OurMacro := GetCursorNode (AMacroOutline(MacroOutline));
            IF (OurMacro = NIL) THEN
                PostError (NotPossibleInContextError, 0);
                RETURN;
            END;

            MacroRecordPointer :=
                     OurMacro^.Methods^.LockFlexStorDataObject (OurMacro);
            GetMessage (26450, Msg);
            Copy (MacroRecordPointer^.name, name);
            OurMacro^.Methods^.UnlockUnchangedDataObject (OurMacro);
            TrimRear (name);
            ConcatLS (Msg, name);

            MacSubTree := OurMacro^.Methods^.GetSubtree(OurMacro);
            IF (MacSubTree <> NIL) THEN
                    (* Deleting it will also delete it's children.  *)
                ConcatMessage(Msg, 26451);             
            END;
            ConcatMessage (Msg, 26452);

            IF (NoYes(Msg)) THEN
                OurMacro^.Methods^.SetChildrenVisible (OurMacro, FALSE);
                NextNode := OurMacro^.Methods^.NextForDisplay(OurMacro);
                IF (NextNode = NIL) THEN
                    NextNode := OurMacro^.Methods^.PrevForDisplay(OurMacro);
                END;
                IF MacSubTree <> NIL THEN
                  DisposeMacros (MacSubTree);
                END;
                DeleteMacro (OurMacro);
                MacrosModified := TRUE;
                IF (MacroOutline^.Cursor = 1) THEN
                    SetFirst(AMacroOutline(MacroOutline), NextNode);
                ELSE
                    Synchronize(AMacroOutline(MacroOutline));
                END;
                ResetMatching (AMacroOutline(MacroOutline));
                SetCursorNode(AMacroOutline(MacroOutline), NextNode);
            END;
      END;
    END DoDeleteKey;
    
    
    

    PROCEDURE DoEditKey ();
    VAR
        FirstNode     : ATreeNode;
        S             : ARRAY [0..255] OF CHAR;
        MacroName     : ARRAY [0..40] OF CHAR;

    BEGIN
        OurEditRecord^.Macro :=
           MacroOutline^.Methods^.GetCursorNode (AMacroOutline(MacroOutline));
        IF OurEditRecord^.Macro = NIL THEN Burp(); RETURN; END;
        GetMacroName (OurEditRecord^.Macro, OurEditRecord^.macName);
        IF (OurEditRecord^.Macro <> NIL) THEN
           SetString (S, "|MACEDIT");
           IF NOT CallOverlay (S) THEN RETURN; END;
           MacroOutline^.Methods^.Synchronize
                              (AMacroOutline (MacroOutline));
           MacroOutline^.Methods^.ResetMatching
                              (AMacroOutline(MacroOutline));
           MacroOutline^.Methods^.SetCursorNode
                        (AMacroOutline(MacroOutline), OurEditRecord^.Macro);
        ELSE
            PostError (NotPossibleInContextError, 0);
        END;
    END DoEditKey;





    PROCEDURE DoCopyKey ();
    VAR
        MacroRecordPointer   : AMacroRecordPointer;
        S                    : ARRAY [0..255] OF CHAR;
        Length               : CARDINAL;
        handle               : AnExtHandle;
        CursorMacro          : ATreeNode;
        dummy                : CARDINAL;
        OurMacro             : ATreeNode;
        AtTop                : BOOLEAN;

    BEGIN
      AtTop := FALSE;
      (*WITH MacroOutline^.Methods^ DO*)
        CursorMacro :=
           MacroOutline^.Methods^.GetCursorNode (AMacroOutline(MacroOutline));
        IF MacroOutline^.Cursor = 1 THEN
           AtTop := TRUE;
        END;
        IF CursorMacro = NIL THEN
           PostError (NotPossibleInContextError, 0);
           RETURN;
        END;

        MacroRecordPointer :=
            CursorMacro^.Methods^.LockFlexStorDataObject (CursorMacro);
        IF CopyExtObject (MacroRecordPointer^.handle,
                          MacStoragePreference, handle) THEN
           Length := MacroRecordPointer^.cardlen;
           CursorMacro^.Methods^.UnlockUnchangedDataObject (CursorMacro)
        ELSE
          MacDeath;
          CursorMacro^.Methods^.UnlockUnchangedDataObject (CursorMacro);
          RETURN;
        END;

               (* Imported FormAccepted from MacVars              *)

        PushMacHeaderStack;

        OurMacro := CursorMacro;
        SetString (S, "MACFORM1");
        IF (CallOverlayWithContext (S, OurMacro)
              AND FormAccepted) THEN
          IF StealHotkeyNode <> NIL THEN                       (* 13-Jan-90 *)
            SetMacroHotKey(StealHotkeyNode, 0);
            Fill(S, ' ', 10);
            SetMacroHotKeyStr(StealHotkeyNode,S);
            StealHotkeyNode := NIL;
          END;
          IF ReplacedMacro <> NIL THEN
            OurMacro := ReplacedMacro;
            ReplacedMacro := NIL;
            IF NOT ClearMacNode (OurMacro) THEN
              PostError (AllocationError, 0);
              DiscardExtObject (handle);
              DeleteMacro (OurMacro);
              RETURN;
            END;
          ELSIF CreateMacro (OurMacro) THEN
            CursorMacro^.Methods^.AddAfter (CursorMacro, OurMacro);
          ELSE
            PostError (AllocationError, 0);
            DiscardExtObject (handle);
            DeleteMacro (OurMacro);
            RETURN;
          END;
          MacrosModified := TRUE;
          MacroRecordPointer :=
                 OurMacro^.Methods^.LockFlexStorDataObject (OurMacro);
          MacroRecordPointer^.handle := handle;
          FillMacroRecord (MacroRecordPointer, Length);
          OurMacro^.Methods^.UnlockFlexStorDataObject (OurMacro);
          IF AtTop THEN
            MacroOutline^.Methods^.SetFirst (AMacroOutline(MacroOutline), OurMacro);
          ELSE;
            MacroOutline^.Methods^.Synchronize (AMacroOutline (MacroOutline));
          END;
          MacroOutline^.Methods^.ResetMatching (AMacroOutline(MacroOutline));
          MacroOutline^.Methods^.SetCursorNode (AMacroOutline (MacroOutline), OurMacro);
          PopMacHeaderStack;
        END;
     (*  END;*)
     END DoCopyKey;



    PROCEDURE DoGotoKey ();
    VAR
        CursorNode                  : ATreeNode;
        Title                   : ARRAY [0..30] OF CHAR;

    BEGIN
        CursorNode := MacroOutline^.Methods^.GetCursorNode (AMacroOutline (MacroOutline));
        GetMessage (26397, Title);
        IF DoGoTo (MacroOutline^.ViewObject, 40, 6, 75, maxrow - 7, Title, TRUE,
                   NullGoToCheckProc, OurGetMacroName, CursorNode) THEN
            MacroOutline^.Methods^.SetCursorNode (AMacroOutline (MacroOutline), CursorNode);
        END;
    END DoGotoKey;




BEGIN               (* MacroOutlineActOn *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateMacroOutline (MacroOutline);
    END;
    DEBUGGING>*)

    ErrorMarker := NewMarker ();
    WITH MacroOutline^ DO
        MacroOutlineMethodsRecord.SuperclassMethods^.
                   ActOnEvent(AnOutlineView(MacroOutline), Event, ReturnEvent);
        Event := ReturnEvent;

        ReturnEvent.EventCode := 0;
        WantToRecord := TRUE;

        CASE Event.EventCode OF
            EditKey :
                IF (NOT Editing AND (State = Neutral)) THEN
                  DoEditKey ();
                ELSE
                  Burp();
                END;
        |   DeleteKey :
                IF (NOT Editing AND (State = Neutral)) THEN
                  DoDeleteKey ();
                ELSE
                  Burp();
                END;
        |   InsertKey :
                IF (NOT Editing AND (State = Neutral)) THEN
                  DoInsertKey ();
                ELSE
                  Burp();
                END;
        |   CopyKey :
                IF (NOT Editing AND (State = Neutral)) THEN
                  DoCopyKey ();
                ELSE
                  Burp();
                END;
        |   GotoKey :
                DoGotoKey ();
        ELSE
            ReturnEvent := Event;
            WantToRecord := FALSE;
        END;
        IF (WantToRecord) THEN
            Methods^.RecordEvent(AMacroOutline(MacroOutline), Event);
        END;
        IF (ErrorPosted(ErrorMarker)) THEN
            HandleErrors(ErrorMarker);
        END;
        PopToMarker(ErrorMarker);
    END;

    
END MacroOutlineActOn;





(*----------------------------------------------------------------------------
    InitAsMacroOutline --

    Initialize the indicated object as a macro outline view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid macro outline view object.  No storage 
        allocation is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsMacroOutline(    MacroOutline : AMacroOutline;
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
    PrivateMacroOutline      : XMacroOutline;
    y                       : ascreeny;

BEGIN                       (* InitAsMacroOutline *)

    PrivateMacroOutline := XMacroOutline(MacroOutline);

    InitAsOutlineView(AnOutlineView(MacroOutline), SuperView, Ulx, Uly, Lrx,
                      Lry, Box, VideoMode, Title, HelpKey, TakeRug);

    WITH PrivateMacroOutline^ DO
        Methods := ADR(MacroOutlineMethodsRecord);
        Last := 0;
        FOR y := Uly TO Lry DO
            IF (NOT CreateMacroView(SubView[Last + 1], AnActiveView(MacroOutline), 
                                   Ulx, y, Lrx, y, ABoxType{NoBox}, VideoMode, 
                                   HelpKey)) THEN
                DiscardSubViews(PrivateMacroOutline);

                RETURN;
            END;
            INC(Last);
        END;
        NameProc := OurGetMacroName;
    END;

END InitAsMacroOutline;





(*----------------------------------------------------------------------------
    CreateMacroOutline --

    Allocate storage for, and initialize the indicated object as a macro 
    outline view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid macro outline view object, and 
        TRUE will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateMacroOutline(VAR MacroOutline : AMacroOutline;
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
     ok           : BOOLEAN;
     ErrorMarker  : AnErrorMarker;                                                            

BEGIN                       (* CreateMacroOutline *)

    ok := FALSE;
    ErrorMarker := NewMarker();
    IF (Available(TSIZE(XMacroOutlineRecord))) THEN
        ALLOCATE(MacroOutline, TSIZE(XMacroOutlineRecord));
        InitAsMacroOutline(MacroOutline, SuperView, Ulx, Uly, Lrx, Lry, Box,
                          VideoMode, Title, HelpKey, TakeRug);
        ok := NOT ErrorPosted(ErrorMarker);
        IF (NOT ok) THEN
          DEALLOCATE(MacroOutline, TSIZE(XMacroOutlineRecord));
        END;
    END;
    PopToMarker(ErrorMarker);

    RETURN ok;

END CreateMacroOutline;







(*----------------------------------------------------------------------------
    UnInitAsMacroOutline --

    UnInitialize the indicated object as a macro outline view.

    Preconditions:
        The object will be a valid macro outline view object. 

    Postconditions:
        The outline view will be invalidated.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsMacroOutline(    MacroOutline : AMacroOutline);


BEGIN                       (* UnInitAsMacroOutline *)

    DiscardSubViews(XMacroOutline(MacroOutline));
    UnInitAsOutlineView(AnOutlineView(MacroOutline));

END UnInitAsMacroOutline;







(*----------------------------------------------------------------------------
    CloneMacroOutlineMethods --

    Make a copy of the macro outline methods into the indicated method 
    object.

    Preconditions:
        None.

    Postcondition:
        The macro outline methods will be copied into the indicated 
        method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneMacroOutlineMethods(    MethodObject : AMacroOutlineMethods);

BEGIN                       (* CloneMacroOutlineMethods *)

    MethodObject^ := MacroOutlineMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(MacroOutlineMethodsRecord);
END CloneMacroOutlineMethods;








(*----------------------------------------------------------------------------
    ValidateMacroOutline --

    Determine that the indicated object is in fact a valid macro outline view 
    object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid macro outline view object, FatalError 
        will be called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateMacroOutline(    MacroOutline : AMacroOutline);

VAR
    PrivateMacroOutline      : XMacroOutline;

BEGIN                       (* ValidateMacroOutline *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateOutlineView(AnOutlineView(MacroOutline));
    END;
    DEBUGGING>*)

    PrivateMacroOutline := XMacroOutline(MacroOutline);
    IF (PrivateMacroOutline^.Methods^.MacroOutlineTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateMacroOutline;





BEGIN                       (* MacroOutlines *)

    CloneOutlineViewMethods(ADR(MacroOutlineMethodsRecord));
    WITH MacroOutlineMethodsRecord DO
        MethodSize := TSIZE(AMacroOutlineMethodsRecord);
        Discard := AMacroOutlineDiscardProc(MacroOutlineDiscard);
        ActOnEvent := AMacroOutlineActOnProc (MacroOutlineActOn);
        MacroOutlineTag := ModuleNumber;
    END;

END MacroOutlines.
