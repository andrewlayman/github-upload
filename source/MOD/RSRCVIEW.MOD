IMPLEMENTATION MODULE RsrcViews;          (* Subclass of ActiveViews *)

    (*  RsrcViews provides an object which is a view of a tree node.
        The data object of the tree node is a resource.  The resource name is
        displayed using indentation to reflect depth in the tree, and "+"
        and "-" symbols to show whether or not it has children.  If the
        resource has no children, its resource type and long name will also
        be displayed.  The resource name is displayed in reverse video if the
        cursor is on it.

        20-Feb-88 RSC  Made debug toggles ready for ship.
        10-Jan-89 RSC  Changed Storage to Space    .
    *)

(*V9=DEBUGGING Code*)
(*V1=HIER archical resources *)


FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveViewMethods, AnActiveView,
    (* PROC *)                  CloneActiveViewMethods, ValidateActiveView,
                                InitAsActiveView, UnInitAsActiveView;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Copy, Procustes, ConcatLS, SetLengthOf,
                                Remove, SubStr;

FROM MatchNames             IMPORT
    (* PROC *)                  PutMatchedString;

FROM MsgFile                IMPORT
    (* PROC *)                  ConcatMessage;

FROM ObjectViews            IMPORT
    (* TYPE *)                  AnObjectView;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

FROM RsrcMod                IMPORT
    (* CONST *)                 ResourceNameLength,
    (* TYPE *)                  AResourcePointer, AResourceType,
    (* PROC *)                  CheckResourceValid;

FROM RsrcOutlines           IMPORT
    (* TYPE *)                  AResourceOutline;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;


CONST
    ModuleNumber            = 16000;



TYPE
    XResourceView             = POINTER TO XResourceViewRecord;
        
    XResourceViewRecord       = RECORD
                                Methods        : AResourceViewMethods;
                                ViewObject     : ATreeNode;
                                ParentView     : AResourceOutline;
                                Ulx            : ascreenx;
                                Uly            : ascreeny;
                                Lrx            : ascreenx;
                                Lry            : ascreeny;
                                Box            : ABoxType;
                                VideoMode      : avidmode;
                                Title          : ARRAY [0..40] OF CHAR;
                                HelpNumber     : CARDINAL;
                                Rug            : ARug;
                                Status         : AResourceViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                              END;



    AResourceViewDiscardProc = PROCEDURE (VAR AResourceView   );

    AResourceViewTitleProc   = PROCEDURE (    AResourceView,
                                          VAR ARRAY OF CHAR   );

    AResourceViewDisplayProc = PROCEDURE (    AResourceView   );



VAR
    ResourceViewMethodsRecord : AResourceViewMethodsRecord;




    (*  Following are the procedures which replace the methods inherited from
        ActiveViews.
    *)


PROCEDURE ResourceViewDiscard(VAR ResourceView  : XResourceView);

BEGIN                       (* ResourceViewDiscard *)

    (*<DEBUGGING
    IF (AnxietyLevel > Calm) THEN
        ValidateResourceView(AResourceView(ResourceView));
    END;
      DEBUGGING>*)

    UnInitAsResourceView(AResourceView(ResourceView));
    DISPOSE(ResourceView);

END ResourceViewDiscard;




PROCEDURE ResourceViewDisplay(    ResourceView  : XResourceView);

VAR
    s                       : ARRAY [0..80] OF CHAR;
    Resource                : AResourcePointer;
    Count                   : CARDINAL;
    i                       : CARDINAL;

BEGIN                       (* ResourceViewDisplay *)

    (*<DEBUGGING  
    IF (AnxietyLevel > Calm) THEN
        ValidateResourceView(AResourceView(ResourceView));
    END;
      DEBUGGING>*)

    WITH ResourceView^ DO
        IF (NOT (NeedsRedisplay IN Status)) THEN RETURN END;

        IF (ViewObject = NIL) THEN
            Fill(s, " ", Lrx-Ulx+1);
            Count := 0;
        ELSE
            Resource := ViewObject^.Methods^.GetDataObject (ViewObject);
            (*<DEBUGGING  
            IF (AnxietyLevel > Calm) THEN
                CheckResourceValid (Resource);
            END;
              DEBUGGING>*)
            Copy (Resource^.Name, s);
            Procustes (s, ResourceNameLength+2);
            IF (Resource^.Type = Employable) THEN
                i := ModuleNumber + 20;     (* " R  " *)
            ELSE
                i := ModuleNumber + 30 + ORD (Resource^.CostStyle);     (* "FC  ", "UC  ", or "VC  " *)
            END;
            ConcatMessage (s, i);
            ConcatLS (s, Resource^.LongName);
            Procustes (s, Lrx-Ulx+1);
            Count := ParentView^.Methods^.GetMatchCount (ParentView);
        END;
            
        PutMatchedString (s, Ulx, Uly, Count, VideoMode, CursorMode,
                             (CursorOn IN Status));

        EXCL(Status, NeedsRedisplay);
    END;

END ResourceViewDisplay;







    (*  These are the procedures which are exported from this module  *)


(*----------------------------------------------------------------------------
    InitAsResourceView --

    Initialize the indicated object as a resource view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid resource view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsResourceView(      ResourceView     : AResourceView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL);

VAR
    s                     : ARRAY [0..1] OF CHAR;
    PrivateResourceView       : XResourceView;

BEGIN                       (* InitAsResourceView *)

    Fill(s, " ", 0);
    InitAsActiveView(AnActiveView(ResourceView), AnObjectView(SuperView), Ulx, 
                     Uly, Lrx, Lry, Box, VideoMode, s, HelpKey, FALSE);
    PrivateResourceView := XResourceView(ResourceView);
    WITH PrivateResourceView^ DO
        Methods := AResourceViewMethods(ADR(ResourceViewMethodsRecord));
    END;

END InitAsResourceView;







(*----------------------------------------------------------------------------
    CreateResourceView --

    Allocate storage for, and initialize the indicated object as a resource 
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid resource view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateResourceView(  VAR ResourceView     : AResourceView;
                               SuperView    : AnActiveView;
                               Ulx          : ascreenx;
                               Uly          : ascreeny;
                               Lrx          : ascreenx;
                               Lry          : ascreeny;
                               Box          : ABoxType;
                               VideoMode    : avidmode;
                               HelpKey      : CARDINAL)
                                                       : BOOLEAN;

BEGIN                       (* CreateResourceView *)

    IF (Available(TSIZE(XResourceViewRecord))) THEN
        ALLOCATE(ResourceView, TSIZE(XResourceViewRecord));
        InitAsResourceView(ResourceView, SuperView, Ulx, Uly, Lrx, Lry, Box,
                         VideoMode, HelpKey);
        RETURN TRUE;
    END;

    RETURN FALSE;

END CreateResourceView;







(*----------------------------------------------------------------------------
    UnInitAsResourceView --

    UnInitialize the indicated object as a resource view.

    Preconditions:
        The object will be a valid resource view object.

    Postconditions:
        Whatever was done by InitAsResourceView will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsResourceView(    ResourceView : AResourceView);

BEGIN                       (* UnInitAsResourceView *)

    UnInitAsActiveView(AnActiveView(ResourceView));

END UnInitAsResourceView;












(*----------------------------------------------------------------------------
    CloneResourceViewMethods --

    Make a copy of the resource view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The resource view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneResourceViewMethods(    MethodObject : AResourceViewMethods);

BEGIN                       (* CloneResourceViewMethods *)

    FatalError();

END CloneResourceViewMethods;








(*----------------------------------------------------------------------------
    ValidateResourceView --

    Determine that the indicated object is in fact a valid resource view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid resource view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateResourceView(    ResourceView : AResourceView);

BEGIN                       (* ValidateResourceView *)

    (*<DEBUGGING  
    IF (AnxietyLevel > Calm) THEN
        ValidateActiveView(AnActiveView(ResourceView));
    END;
      DEBUGGING>*)

    IF (ResourceView^.Methods^.ResourceViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateResourceView;


BEGIN                       (* ResourceViews *)

    CloneActiveViewMethods(AnActiveViewMethods(ADR(ResourceViewMethodsRecord)));
    WITH ResourceViewMethodsRecord DO
        MethodSize := TSIZE(AResourceViewMethodsRecord);
        Discard := AResourceViewDiscardProc(ResourceViewDiscard);
        Display := AResourceViewDisplayProc(ResourceViewDisplay);
        ResourceViewTag := ModuleNumber;
    END;

END RsrcViews.
