IMPLEMENTATION MODULE MacroViews;     (* A Subclass of ActiveViews *)

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

     13-Nov-89  RSC - Import from Space rather than Storage.

---------------------------------------------------------------------------*)




(*V9=DEBUGGING Code*)
(*V1=HIER archical macros *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Indentation            IMPORT
                                FormatIndentation;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM MacNodes               IMPORT
    (* TYPE *)                  AMacroRecordPointer;
    
FROM MacroOutlines          IMPORT
                                AMacroOutline;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Procustes, Copy, SetLengthOf, Remove,
                                SubStr, ConcatS, LJust, LengthOf;
                                
FROM MatchNames             IMPORT
                                PutMatchedString;                                

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;


CONST
    ModuleNumber            = 16110;



TYPE
    XMacroView             = POINTER TO XMacroViewRecord;
        
    XMacroViewRecord       = RECORD
                                Methods        : AMacroViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : AMacroOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AMacroViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;


    AMacroViewDiscardProc = PROCEDURE (VAR AMacroView   );
    
    AMacroViewTitleProc   = PROCEDURE (    AMacroView,
                                       VAR ARRAY OF CHAR );

    AMacroViewDisplayProc = PROCEDURE (    AMacroView   );


VAR
    MacroViewMethodsRecord : AMacroViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE MacroViewDiscard(VAR MacroView  : XMacroView);

BEGIN                       (* MacroViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateMacroView(AMacroView(MacroView));
    END;
    DEBUGGING>*)

    UnInitAsMacroView(AMacroView(MacroView));
    DISPOSE(MacroView);

END MacroViewDiscard;





PROCEDURE MacroViewDisplay(    MacroView  : XMacroView);

CONST
    SpacesPerLevel = 2;

VAR
    s                       : ARRAY [0..80] OF CHAR;
    MacroRecordPointer      : AMacroRecordPointer;
    Leader                  : CARDINAL;
    (*Count                   : CARDINAL;*)

BEGIN                       (* MacroViewDisplay *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateMacroView(AMacroView(MacroView));
    END;
    DEBUGGING>*)

    WITH MacroView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            IF (CursorOn IN Status) THEN
                PutString (s, Ulx, Uly, cvideonormal);
            ELSE
                PutString (s, Ulx, Uly, VideoMode);
            END;
        ELSE
            (*
            Leader := ViewObject^.Methods^.IndentationLevel (ViewObject)
                    * SpacesPerLevel;
            Fill (s, " ", Leader);
            IF (ViewObject^.Methods^.FirstChild (ViewObject) = NIL) THEN
                s[Leader+1] := "-";
            ELSE
                s[Leader+1] := "+";
            END;
            s[Leader+2] := " ";
            SetLengthOf (s, Leader+2);
            *)
            FormatIndentation(ViewObject, Lrx-Ulx+1, s);          (* 12-Oct-87 LAA *)
            ConcatS(s, " ");
            Leader := LengthOf(s);
            IF (Leader > Lrx-Ulx+1) THEN                          (* 24-Dec-87 LAA *)
                Leader := Lrx-Ulx+1;
            END;
            SetLengthOf(s, Leader);
            PutString (s, Ulx, Uly, VideoMode);

            (*MacroRecordPointer := ViewObject^.Methods^.GetDataObject (ViewObject);*)
            MacroRecordPointer := ViewObject^.Methods^.LockFlexStorDataObject (ViewObject);
            Copy (MacroRecordPointer^.name, s);
            ViewObject^.Methods^.UnlockUnchangedDataObject (ViewObject);
            LJust(s);                                             (* 24-Dec-87 LAA *)
            Procustes (s, Lrx-Ulx+1-Leader);                      (* 12-Oct-87 LAA *)
            IF (CursorOn IN Status) THEN
                PutString (s, Ulx+Leader, Uly, cvideonormal);
            ELSE
                PutString (s, Ulx+Leader, Uly, VideoMode);
            END;
        END;

        EXCL(Status, NeedsRedisplay);
    END;




(* Old MacroView code, prior to indentation. *)
(*    WITH MacroView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill (s, " ", Lrx-Ulx+1);
            Count := 0;
        ELSE
            MacroRecordPointer := ViewObject^.Methods^.GetDataObject (ViewObject);
            Copy (MacroRecordPointer^.name, s);
            Procustes (s, Lrx-Ulx+1);
            Count := ParentView^.Methods^.GetMatchCount (ParentView);
        END;

        PutMatchedString (s, Ulx, Uly, Count, VideoMode, CursorMode,
                           (CursorOn IN Status));

        EXCL(Status, NeedsRedisplay);
    END;
*)
END MacroViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsMacroView --

    Initialize the indicated object as a macro view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid macro view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsMacroView(      MacroView     : AMacroView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL);

VAR
    s                      : ARRAY [0..1] OF CHAR;
    PrivateMacroView       : XMacroView;

BEGIN                       (* InitAsMacroView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(MacroView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateMacroView := XMacroView(MacroView);
    WITH PrivateMacroView^ DO
        Methods := AMacroViewMethods(ADR(MacroViewMethodsRecord));
    END;

END InitAsMacroView;







(*----------------------------------------------------------------------------
    CreateMacroView --

    Allocate storage for, and initialize the indicated object as a macro 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid macro view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateMacroView(  VAR MacroView     : AMacroView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateMacroView *)

    IF (Available(TSIZE(XMacroViewRecord))) THEN
        ALLOCATE(MacroView, TSIZE(XMacroViewRecord));
        InitAsMacroView(MacroView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateMacroView;







(*----------------------------------------------------------------------------
    UnInitAsMacroView --

    UnInitialize the indicated object as a macro view.

    Preconditions:
        The object will be a valid macro view object.

    Postconditions:
        Whatever was done by InitAsMacroView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsMacroView(    MacroView : AMacroView);

BEGIN                       (* UnInitAsMacroView *)

    UnInitAsActiveView(AnActiveView(MacroView));

END UnInitAsMacroView;












(*----------------------------------------------------------------------------
    CloneMacroViewMethods --

    Make a copy of the macro view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The macro view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneMacroViewMethods(    MethodObject : AMacroViewMethods);

BEGIN                       (* CloneMacroViewMethods *)

    FatalError();

END CloneMacroViewMethods;








(*----------------------------------------------------------------------------
    ValidateMacroView --

    Determine that the indicated object is in fact a valid macro view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid macro view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateMacroView(    MacroView : AMacroView);

BEGIN                       (* ValidateMacroView *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(MacroView));
    END;
    DEBUGGING>*)

    IF (MacroView^.Methods^.MacroViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateMacroView;


BEGIN                       (* MacroViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(MacroViewMethodsRecord)));
    WITH MacroViewMethodsRecord DO
        MethodSize := TSIZE(AMacroViewMethodsRecord);
        Discard    := AMacroViewDiscardProc(MacroViewDiscard);
        Display    := AMacroViewDisplayProc(MacroViewDisplay);
        MacroViewTag := ModuleNumber;
    END;

END MacroViews.
