(*V1=PRINTOUTS Allows F6 key = Print *)
(*V9=DEBUGGING Code*)

IMPLEMENTATION MODULE EditViews;        (*  a subclass of ListViews  *)

    (*  MODIFICATION HISTORY
        28-Dec-87 LAA   Fixed bug which removed every other character when
                        doing a word-wrap from a completely filled line, i.e.
                        a line with no spaces in it.
        12-Jan-88 LAA   The previous fix caused the cursor to end up too far
                        to the right when word wrap occured.
        29-Jan-88 LAA   Errors were being posted but never handled.  This 
                        could cause a PMD.  Also put up messages when reading
                        and writing files, to indicate progress.
       RSC 2/3/88     - DocName should default to project media area, not dk:
       AJL 2/1/88     - Added calls to DisplayFileError so that we can report
                        them exactly, and also so that the files will be closed
                        when disks become full.
       AJL 2/2/88     - Removed an extra call to DisplayFileError that was
                        displaying a message whenever the end of file was 
                        hit during reading.
                      - Removed generic error messages when DisplayFileError
                        has just given a specific diagnostic. 
       03-Mar-88 LAA    Forgot to set Last to zero after discarding subviews.
       04-Mar-88 LAA    Intercept the help key, use ModuleNumber as key.
       08-Mar-88 EGK    Forgot to pop the error stack if CreateEditView
                        returns TRUE.
       09-Mar-88 EGK    Close the file after reading!
       27-Jun-88 LAA    Handle the Tab key.
       14-Jul-88 LAA    Don't record the * key in the event history, because
                        it'll be treated as if it was the RepeatKey (which it
                        is, but we don't want it treated as such here).  This
                        fixes bug #8302.
       12-Dec-88 WKH    Don't allow reading in of schedule files into Notes.
       23-Jan-89 RSC    Changed Storage to Space    .
       07-Jun-89 LAA    Due to changes in key assignments in ListViews, the
                        PgUp and PgDn keys were being translated into Ctrl
                        versions, which no longer scroll the screen by a full
                        screen's worth.  Fixed it so PgUp and PgDn are just
                        passed through.
       09-Jun-89 LAA    Turned off the cursor before bringing up the Help 
                        system, and restored it afterwards.
       10-Jun-89 WKH    Added support for variable screen rows.
       30-Jun-89 LAA    Stopped wordwrap from adding a extra blank, because of
                        the bad effects this was having on macros.
        5-Jan-90 LAA    Added the instance variable MouseDownRegion from
                        superclass ListViews.
        9-Jan-90 MWP    Allow columnar positioning on mouse movement,
                        ( i.e. MouseDown and MouseStillDown ).
        6-Oct-90 AJL -Allow the AlternateEraseKey (Ctrl-End) to erase to eol. 
       12-Mar-91 RSC  Clean up file handling; open input files Read-Only.
       31-MAr-91 AJL -Remove unreferenced identifiers.
                     -Add toggle PRINTOUTS which allows the F6 key to print
                      the text.
       26-Sep-91 LAA -In DoReadFromFile, it the lines we're reading are longer
                      than the width passed in, a character too many was
                      being read and lost.  Changed to end the when i = Width.
       28-Feb-92 AJL -Added Copy, Paste, and Calculations key.  Copy and
                      Paste work with the clipboard.  Calculations (Ctrl-F9)
                      evaluates the text following the cursor position as
                      an arithmetic expression and and replaces the expression
                      with its value.
        1-Apr-92 TGS  Implementation of Paste() was a little TOO cheap; now
                      enabled line wrap so we didn't wind up with something
                      too long to handle.
    *)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM ASCII                  IMPORT
    (* CONST *)                 EOL, lf, ht;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute,
                                AMouseClickPoint,                 (* 9-Jan-89 MWP *)
    (* PROC *)                  CorrelateMousePoint;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes, ACode,
    (* VAR *)                   EmptyCodeSet,
    (* PROC *)                  SetCodeBits;

FROM CutPaste               IMPORT
    (* PROC *)                  CopyToPasteBuffer, PasteBuffer;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  FatalError, Burp, Error, Message,
                                ContinuationBox;

FROM Direct411              IMPORT
    (* PROCS *)                 GetInputFile, GetOutputFile;

FROM Directory              IMPORT
    (* PROCS *)                 ExtractFileNameParts, ExpandPath;

FROM EditObjects            IMPORT
    (* TYPE *)                  AnEditNode, AnEditWorkspace,
    (* PROC *)                  CreateEditNode;

FROM ErrorCategories        IMPORT
    (* CONST *)                 AllocationError;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted,
                                PopToMarker, PostError;

FROM EvalReal               IMPORT
    (* PROC *)                  EvaluateRealExpression;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType;

FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO, DisplayFileError;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* CONST *)                 ReadOnlyMode,
    (* PROC *)                  Delete, Lookup, Close, WriteChar, ReadChar,
                                OpenFile, Again;

FROM Helper                 IMPORT
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode, AbsoluteMaxRow, maxrow,
                                ACursorType,
    (* PROC *)                  SetCursorType, GetCursorType;

FROM Keys                   IMPORT
    (* CONST *)                 Up, Down, HomeKey, EndKey, HelpKey, DoIt,
                                JoinPartialKey, Fwrd, Reverse, EraseKey,
                                RollLeft, RollRight, InsertKey, EraseToEOLKey,
                                DeleteKey, BackSpace, PgUpKey, PgDnKey, Tab,
                                CancelKey, GotoFirstKey, GotoLastKey,
                                RepeatKey, AlternateEraseKey,
                                CopyToPasteKey, PasteKey,
                                MouseUp, MouseStillDown, MouseDown;  (* 9-Jan-89 MWP *)

FROM ListViews              IMPORT
    (* TYPE *)                  AListView, 
    (* PROC *)                  CloneListViewMethods, InitAsListView,
                                UnInitAsListView;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, LengthOf, ConcatS, TrimRear,
                                SetLengthOf, SetString, LStringToTString, LJust,
                                Insert, Copy, ConcatLS, Remove, CtoS, Search;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

    (*<PRINTOUTS*)
FROM PrintSupport          IMPORT
    (* VAR *)                  Stopped,
    (* PROC *)                 StartReport, EndReport, PrintLine;
    (*PRINTOUTS>*)

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE,
                                HeapAvailable;

FROM StringViews            IMPORT
    (* TYPE *)                  AStringView,
    (* PROC *)                  CreateStringView;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM RealFormat IMPORT
    (* VARS  *)        DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROCS *)        FormatAsAmount, FormatAsCurrency;




CONST
    ModuleNumber            = 15300;
    LineDeleteKey           = 317;          (* F3 *)
    PrintKey                = 320;          (* F6 *)
    ReadFromFileKey         = 321;          (* F7 *)
    WriteToFileKey          = 322;          (* F8 *)
    ReformatKey             = 323;          (* F9 *)
    CalculateKey            = 358;          (* Ctrl-F9 *)


        (*  XEditView is a redefinition of AnEditView, for the use
            of this module only.
        *)

TYPE
    AnEditViewIModeProc     = PROCEDURE(    AnEditView): BOOLEAN;

    AnEditViewMarginProc    = PROCEDURE(    AnEditView): CARDINAL;

    XEditView               = POINTER TO XEditViewRecord;


        (*  The beginning of AnEditViewRecord MUST be identical with that of
            AListViewRecord.  They MUST be kept in sync.
        *)

    XEditViewRecord         = RECORD
                                Methods        : AnEditViewMethods;
                                ViewObject     : AnEditWorkspace;
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
                                Status         : AnEditViewStatusSet;
                                EventHistory   : ARRAY [0..10] OF AnEvent;
                                CursorMode     : avidmode;
                                  (* Here are the new fields for ListViews *)
                                Last           : CARDINAL;
                                SubView        : ARRAY [1..AbsoluteMaxRow + 1] OF 
                                                                  AStringView;
                                Cursor         : CARDINAL;
                                MouseDownRegion: CARDINAL;
                                  (* This is the stuff for EditViews *)
                                CursorColumn   : CARDINAL;
                                LeftMargin     : CARDINAL;
                                RightMargin    : CARDINAL;
                                InsertMode     : BOOLEAN;
                              END;


VAR
    EditViewMethodsRecord   : AnEditViewMethodsRecord;
    ValidInput              : ASetOfCodes;

    DefaultDocName          : ARRAY [0..1]  OF CHAR;
    DocName                 : ARRAY [0..81] OF CHAR; (* Document File Name *)








PROCEDURE DiscardSubViews(    EditView      : XEditView);

VAR
    i                       : CARDINAL;

BEGIN                       (* DiscardSubViews *)

    WITH EditView^ DO
        FOR i := 1 TO Last DO
            SubView[i]^.Methods^.Discard(SubView[i]);
        END;
        Last := 0;                                                (* 03-Mar-88 LAA *)
    END;

END DiscardSubViews;







    (*  The following override methods defined in Objects  *)


PROCEDURE EditViewDiscard(VAR EditView      : XEditView);

BEGIN                       (* EditViewDiscard *)

    IF (AnxietyLevel > Calm) THEN
        ValidateEditView(AnEditView(EditView));
    END;

    UnInitAsEditView(AnEditView(EditView));
    DISPOSE(EditView);

END EditViewDiscard;












    (*  The following override methods defined in ActiveViews  *)


PROCEDURE EditViewActOn(    EditView        : XEditView;
                            Event           : AnEvent;
                        VAR ReturnEvent     : AnEvent  );

VAR
    CNode                   : AnEditNode;
    ErrorMarker             : AnErrorMarker;
    OldCursor               : ACursorType;
    NeedsSync               : BOOLEAN;
    WantToRecord            : BOOLEAN;
    MenuName                : ARRAY [0..9] OF CHAR;


    PROCEDURE TellParentView(    Code       : ACode);

    VAR
        Event               : AnEvent;

    BEGIN                   (* TellParentView *)

        WITH EditView^ DO
            WITH Event DO
                EventCode := Code;
                EventType := KeyboardEvent;
            END;
            WITH EditViewMethodsRecord.SuperclassMethods^ DO
                ActOnEvent(AListView(EditView), Event, Event);
            END;
        END;

    END TellParentView;


    PROCEDURE AddLineAfter(    Node         : AnEditNode): BOOLEAN;

    VAR
        Workspace           : AnEditWorkspace;
        NextNode            : AnEditNode;

    BEGIN                   (* AddLineAfter *)

        Workspace := Node^.Methods^.GetList(Node);
        IF (NOT CreateEditNode(NextNode, Workspace)) THEN
            RETURN FALSE;
        END;
        Node^.Methods^.AddAfter(Node, NextNode);
        Workspace^.Methods^.SetChanged(Workspace, TRUE);
        EditView^.Methods^.Synchronize(AnEditView(EditView));

        RETURN TRUE;

    END AddLineAfter;


    PROCEDURE JoinWithNext(    Node         : AnEditNode;
                               Column       : CARDINAL  );

    VAR
        SizeAvailable       : CARDINAL;
        NextNode            : AnEditNode;
        s2                  : ARRAY [0..81] OF CHAR;
        s3                  : ARRAY [0..81] OF CHAR;

    BEGIN                   (* JoinWithNext *)

        WITH EditView^ DO
            NextNode := Node^.Methods^.GetNextVisible(Node);
            IF (NextNode = NIL) THEN
                Burp();
                RETURN;
            END;

            IF (Column >= RightMargin) THEN
                IF (NextNode^.Methods^.EndOfLine(NextNode) = 1) THEN
                    NextNode^.Methods^.Discard(NextNode);
                    Methods^.Synchronize(AnEditView(EditView));
                    ViewObject^.Methods^.SetChanged(ViewObject, TRUE);
                ELSE
                    Burp();
                END;
                RETURN;
            END;
            SizeAvailable := RightMargin - Column;

            NextNode^.Methods^.GetLine(NextNode, 1, HIGH(s2), s2);
            TrimRear(s2);
            IF (SizeAvailable >= LengthOf(s2)) THEN
                SizeAvailable := LengthOf(s2);
            ELSE
                IF (s2[SizeAvailable] = " ") THEN
                    FindNextWord(s2, SizeAvailable);
                ELSIF (s2[SizeAvailable + 1] = " ") THEN
                    FindNextWord(s2, SizeAvailable);
                ELSIF (NOT StartOfWord(s2, SizeAvailable)) THEN
                    FindPriorWord(s2, SizeAvailable);
                END;
                DEC(SizeAvailable);
                IF (SizeAvailable = 0) THEN 
                    Burp();
                    RETURN;
                END;
            END;

            SubStr(s2, s3, 1, SizeAvailable);
            TrimRear(s3);
            Node^.Methods^.PutLine(Node, Column + 1, FALSE, s3);
            NextNode^.Methods^.DeleteBlock(NextNode, 1, SizeAvailable);

            IF (NextNode^.Methods^.EndOfLine(NextNode) = 1) THEN
                NextNode^.Methods^.Discard(NextNode);
            END;
            ViewObject^.Methods^.SetChanged(ViewObject, TRUE);
            Methods^.Synchronize(AnEditView(EditView));
        END;

    END JoinWithNext;



    PROCEDURE DoWordWrap(VAR NeedsSync      : BOOLEAN);

    VAR
        NextNode                : AnEditNode;
        s                       : ARRAY [0..255] OF CHAR;
        s2                      : ARRAY [0..255] OF CHAR;
        i, j                    : CARDINAL;
        SizeToMove              : CARDINAL;
        InsertNewLine           : BOOLEAN;
        FullLine                : BOOLEAN;

    BEGIN                       (* DoWordWrap *)

        NeedsSync := FALSE;
        WITH EditView^ DO
            CNode^.Methods^.GetLine(CNode, 1, 999, s);
            TrimRear(s);
            IF (LengthOf(s) > RightMargin) THEN
                i := RightMargin + 1;
                WHILE ((i > 1) AND (s[i - 1] <> " ")) DO
                    DEC(i);
                END;
                FullLine := (i = 1);                              (* 30-Jun-89 LAA *)
                IF (FullLine) THEN
                    i := RightMargin + 1;
                END;
                SizeToMove := LengthOf(s) - i + 1;

                InsertNewLine := TRUE;
                NextNode := CNode^.Methods^.GetNextVisible(CNode);
                IF (NextNode <> NIL) THEN
                    NextNode^.Methods^.GetLine(NextNode, 1, 999, s2);
                    IF (LengthOf(s2) = 0) THEN ;
                    ELSIF ((LengthOf(s2) = 1) AND (s2[1] = " ")) THEN ;
                    ELSIF ((LengthOf(s2) = 2) AND (s2[1] = " ") 
                                              AND (s2[2] = " ")) THEN ;
                    ELSE
                        IF (LengthOf(s2)+SizeToMove < RightMargin) THEN
                            InsertNewLine := FALSE;
                        END;
                    END;
                END;

                IF (CursorColumn >= i) THEN
                    InsertNewLine := TRUE;
                END;

                IF (InsertNewLine) THEN
                    IF (NOT AddLineAfter(CNode)) THEN
                        Burp();
                        RETURN;
                    END;
                    NextNode := CNode^.Methods^.GetNextVisible(CNode);
                END;

                SubStr(s, s2, i, HIGH(s2));
                j := i;                                           (* 12-Jan-88 LAA *)
                WHILE ((j > 1) AND (s[j-1] = " ")) DO             (* 28-Dec-87 LAA *)
                    DEC(j);
                END;
                CNode^.Methods^.DeleteBlock(CNode, j, 999);

                IF (NOT FullLine) THEN                            (* 30-Jun-89 LAA *)
                    ConcatS(s2, " ");
                END;

                NextNode^.Methods^.PutLine(NextNode, 1, NOT InsertNewLine, s2);
                IF (CursorColumn >= i) THEN
                    Methods^.SetCursorNode(AnEditView(EditView), NextNode);
                    CursorColumn := CursorColumn - i + 1;
                END;
                NeedsSync := TRUE;
            ELSIF (CursorColumn >= RightMargin + 1) THEN
                IF (NOT AddLineAfter(CNode)) THEN
                    Burp();
                    RETURN;
                END;
            ELSE
                CNode^.Methods^.PutLine(CNode, 1, FALSE, s);
                Methods^.SetCursorNode(AnEditView(EditView), CNode);
            END;
        END;

    END DoWordWrap;





    PROCEDURE StartOfWord(VAR String        : ARRAY OF CHAR;
                              Position      : CARDINAL)
                                                       : BOOLEAN;

    BEGIN                   (* StartOfWord *)

        RETURN (Position <= 1) OR (Position > ORD(String[0])) OR
               ((String[Position] <> " ") AND (String[Position - 1] = " "));

    END StartOfWord;




    PROCEDURE FindPriorWord(VAR String      : ARRAY OF CHAR;
                            VAR Position    : CARDINAL);

    BEGIN                   (* FindPriorWord *)

        IF (Position > 1) THEN
            REPEAT
                DEC(Position);
            UNTIL (StartOfWord(String, Position));
        END;

    END FindPriorWord;




    PROCEDURE FindNextWord(VAR String       : ARRAY OF CHAR;
                           VAR Position     : CARDINAL);

    BEGIN                   (* FindNextWord *)

        IF (Position < ORD(String[0])) THEN
            REPEAT
                INC(Position);
            UNTIL (StartOfWord(String, Position));
        END;

    END FindNextWord;




    PROCEDURE DoFwrdKey();

    BEGIN                   (* DoFwrdKey *)

        WITH EditView^ DO
            SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
            IF (CursorColumn <= RightMargin) THEN
                INC(CursorColumn);
            ELSE
                CursorColumn := 1;
                DoDown();
            END;
        END;

    END DoFwrdKey;


    PROCEDURE DoTabKey();

    BEGIN                   (* DoTabKey *)

        WITH EditView^ DO
            DoFwrdKey();
            WHILE ((CursorColumn <> 1) AND ((CursorColumn MOD 5) <> 0)) DO
                DoFwrdKey();
            END;
        END;

    END DoTabKey;


    PROCEDURE DoReverseKey();

    BEGIN                   (* DoReverseKey *)

        WITH EditView^ DO
            SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
            IF (CursorColumn > 1) THEN
                DEC(CursorColumn);
            ELSE
                TellParentView(Up);
                IF (CNode <> Methods^.GetCursorNode(AnEditView(EditView))) THEN
                    CursorColumn := RightMargin;
                END;
            END;
        END;

    END DoReverseKey;



    PROCEDURE DoHomeKey();

    VAR
        Workspace           : AnEditWorkspace;
        FirstNode           : AnEditNode;

    BEGIN                   (* DoHomeKey *)

        WITH EditView^ DO
            IF (EventHistory[0].EventCode = HomeKey) THEN
                Workspace := CNode^.Methods^.GetList(CNode);
                FirstNode := Workspace^.Methods^.GetFirst(Workspace);
                IF (FirstNode = CNode) THEN
                    Burp();
                    RETURN;
                END;
                Methods^.SetCursorNode(AnEditView(EditView), FirstNode);
            END;
            CursorColumn := 1;
        END;

    END DoHomeKey;



    PROCEDURE DoEndKey();

    VAR
        Workspace           : AnEditWorkspace;
        LastNode            : AnEditNode;

    BEGIN                   (* DoEndKey *)

        WITH EditView^ DO
            SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
            IF (EventHistory[0].EventCode = EndKey) THEN
                Workspace := CNode^.Methods^.GetList(CNode);
                LastNode := Workspace^.Methods^.GetLast(Workspace);
                IF (LastNode = CNode) THEN
                    Burp();
                    RETURN;
                END;
                CNode := LastNode;
                Methods^.SetCursorNode(AnEditView(EditView), CNode);
            END;
            CursorColumn := CNode^.Methods^.EndOfLine(CNode);
        END;

    END DoEndKey;



    PROCEDURE DoBackSpace();

    BEGIN                   (* DoBackSpace *)

        WITH EditView^ DO
            DoReverseKey();
            CNode := Methods^.GetCursorNode(AnEditView(EditView));
            CNode^.Methods^.PutCharacter(CNode, CursorColumn, FALSE, " ");
            IF ((InsertMode) AND (CursorColumn < RightMargin)) THEN
                IF (CursorColumn < CNode^.Methods^.EndOfLine(CNode)) THEN
                    CNode^.Methods^.DeleteCharacter(CNode, CursorColumn);
                END; 
            END;
        END;

    END DoBackSpace;



    PROCEDURE DoDeleteKey();

    BEGIN                   (* DoDeleteKey *)

        WITH EditView^ DO
            IF (CursorColumn >= CNode^.Methods^.EndOfLine(CNode)) THEN
                JoinWithNext(CNode, CursorColumn);
            ELSE
                CNode^.Methods^.DeleteCharacter(CNode, CursorColumn);
            END;
        END;

    END DoDeleteKey;



    PROCEDURE DoWordLeft();

    VAR
        s                   : ARRAY [0..255] OF CHAR;
        Workspace           : AnEditWorkspace;

    BEGIN                   (* DoWordLeft *)

        WITH EditView^ DO
            IF (CursorColumn = 1) THEN
                Workspace := CNode^.Methods^.GetList(CNode);
                IF (CNode = Workspace^.Methods^.GetFirst(Workspace)) THEN
                    Burp();
                ELSE
                    TellParentView(Up);
                    CNode := Methods^.GetCursorNode(AnEditView(EditView));
                    DoEndKey();
                END;
            ELSE
                CNode^.Methods^.GetLine(CNode, 1, HIGH(s), s);
                FindPriorWord(s, CursorColumn);
            END;
        END;

    END DoWordLeft;



    PROCEDURE DoWordRight();

    VAR
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoWordRight *)

        WITH EditView^ DO
            WITH SubView[Cursor]^ DO
                CNode^.Methods^.GetLine(CNode, 1, 999, s);
                IF ((CursorColumn >= CNode^.Methods^.EndOfLine(CNode)) 
                   OR (CursorColumn >= RightMargin)) THEN
                    DoDown();
                    DoHomeKey();
                ELSE
                    FindNextWord(s, CursorColumn);
                    SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);
                END;
            END;
        END;

    END DoWordRight;



    PROCEDURE DoDown();

    BEGIN                   (* DoDown *)

        WITH EditView^ DO
            IF (CNode^.Methods^.GetNextVisible(CNode) = NIL) THEN
                IF (NOT AddLineAfter(CNode)) THEN
                    PostError(AllocationError, ModuleNumber);     (* 29-Jan-88 LAA *)
                    RETURN;
                END;
                Methods^.Synchronize(AnEditView(EditView));
            END;
            TellParentView(Down);
        END;

    END DoDown;




    PROCEDURE DoDoIt();

    VAR
        NextNode            : AnEditNode;
        s                   : ARRAY [0..255] OF CHAR;
        s2                  : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoDoIt *)

        WITH EditView^ DO
            IF (InsertMode) THEN
                CNode := Methods^.GetCursorNode(AnEditView(EditView));
                IF (NOT AddLineAfter(CNode)) THEN
                    PostError(AllocationError, ModuleNumber);     (* 29-Jan-88 LAA *)
                    RETURN;
                END;
                NextNode := CNode^.Methods^.GetNextVisible(CNode);
                CNode^.Methods^.GetLine(CNode, 1, 999, s);
                SetLengthOf(s2, 0);
                SubStr(s, s2, CursorColumn, HIGH(s2));
                CNode^.Methods^.DeleteBlock(CNode, CursorColumn, 999);
                Methods^.Synchronize(AnEditView(EditView));
                CNode^.Methods^.PutLine(NextNode, 1, FALSE, s2);
            END;

            IF (CNode^.Methods^.GetNextVisible(CNode) = NIL) THEN
                IF (NOT AddLineAfter(CNode)) THEN
                    PostError(AllocationError, ModuleNumber);     (* 29-Jan-88 LAA *)
                    RETURN;
                END;
                Methods^.Synchronize(AnEditView(EditView));
            END;
            CNode := CNode^.Methods^.GetNextVisible(CNode);
            Methods^.SetCursorNode(AnEditView(EditView), CNode);
            CursorColumn := 1;
        END;

    END DoDoIt;



    PROCEDURE DoDeleteLine();

    VAR
        NextNode                : AnEditNode;

    BEGIN                   (* DoDeleteLine *)

        WITH EditView^ DO
            NextNode := CNode^.Methods^.GetNextVisible(CNode);
            IF (NextNode = NIL) THEN
                NextNode := CNode^.Methods^.GetPrevVisible(CNode);
            END;
            IF (NextNode = NIL) THEN
                CNode^.Methods^.DeleteBlock(CNode, 1, 999);
                CursorColumn := 1;
            ELSE
                CNode^.Methods^.DeList(CNode);
                IF (CNode = Methods^.GetFirst(AnEditView(EditView))) THEN
                    Methods^.SetFirst(AnEditView(EditView), NextNode);
                END;
                CNode^.Methods^.Discard(CNode);
                Methods^.Synchronize(AnEditView(EditView));
                Methods^.SetCursorNode(AnEditView(EditView), NextNode);
                CNode := NextNode;
            END;
            ViewObject^.Methods^.SetChanged(ViewObject, TRUE);
        END;

    END DoDeleteLine;


    PROCEDURE GetFileName(     ForInput  : BOOLEAN;
                           VAR FileName  : ARRAY OF CHAR): BOOLEAN;
    VAR
        Loop        : CARDINAL;
        PathOut     : ARRAY [0..99] OF CHAR;
        FileNameOut : ARRAY [0..13] OF CHAR;
        Device,
        Extension   : ARRAY [0..3] OF CHAR;
        ok          : BOOLEAN;
        s           : ARRAY [0..3] OF CHAR;

    BEGIN                   (* GetFileName *)

        ExtractFileNameParts( FileName, Device, PathOut, FileNameOut, Extension );
        Insert( PathOut, Device, 1 );
        ConcatS( FileNameOut, "." );
        IF (LengthOf( Extension )=0) THEN
            Loop := LengthOf( FileName );
            WHILE (Loop > 0) AND (FileName[Loop] = " ") DO
                DEC(Loop);
            END;
            IF (FileName[Loop] <> ".") THEN
                SetString(Extension,"DOC");
            END;
        END;

        SetString(s, "T#"); (* WKH 12/12/88 *)
        IF (Search(Extension, s, 1) = 1) THEN
            SetLengthOf(Extension, 0);
        END;

        ConcatLS( FileNameOut, Extension );

        IF (ForInput) THEN
            ok := (GetInputFile( PathOut,
                                 FileNameOut, 
                                 PathOut, 
                                 FileNameOut,
                                 FALSE,        (* Allow Wildcards *)
                                 TRUE  ));     (* Give Assistance *)
        ELSE
            ok := (GetOutputFile( PathOut, 
                                  FileNameOut, 
                                  PathOut, 
                                  FileNameOut,
                                  TRUE ));   (* GiveAssistance *)
        END;

        IF (ok) THEN
            Copy( PathOut, FileName );
            ConcatLS( FileName, FileNameOut );
        END;
        RETURN ok;

    END GetFileName;


    PROCEDURE GetNextLine(VAR F             : File;
                              Width         : CARDINAL;
                          VAR Line          : ARRAY OF CHAR): BOOLEAN;

    VAR
        i                   : CARDINAL;
        ch                  : CHAR;

    BEGIN                   (* GetNextLine *)

        IF (Width > HIGH(Line)) THEN
            Width := HIGH(Line);
        END;

        i := 0;
        SetLengthOf(Line, 0);
        PrepareForIO(F);
        REPEAT
            ReadChar(F, ch);
            IF (F.eof OR (CheckIO(F) <> done)) THEN (* 12-Mar-91 RSC  *)
                IF (NOT F.eof) THEN                (* AJL 2/2/88 *)
                    DisplayFileError(F,DocName);
                END; 
                RETURN (i > 0);
            END;
            INC(i);
            IF ((ch <> EOL) AND (i <= Width)) THEN
                Line[i] := ch;
                SetLengthOf(Line, i);
            END;
        UNTIL ((i >= Width) OR (ch = EOL));                    (* 26-Sep-91 *)

        IF (ch <> EOL) THEN
            Again(F);
        END;

        RETURN TRUE;

    END GetNextLine;



    PROCEDURE DoReadFromFile();

    VAR
        s                   : ARRAY [0..255] OF CHAR;
        s2                  : ARRAY [0..255] OF CHAR;
        s3                  : ARRAY [0..255] OF CHAR;
        F                   : File;
        NextNode            : AnEditNode;
        TNode               : AnEditNode;

    BEGIN                   (* DoReadFromFile *)

        WITH EditView^ DO
            IF (NOT GetFileName(TRUE,DocName)) THEN RETURN; END;

            LStringToTString(DocName, s);
            PrepareForIO(F);
            OpenFile( F, s, ReadOnlyMode ); (* 12-Mar-91 RSC  *)
(*            Lookup(F, s, FALSE);*)
            IF (CheckIO(F) <> done) THEN
                DisplayFileError(F,DocName);
                (*  AJL 2/2/88
                GetMessage(ModuleNumber + 5, s); (* file cannot be accessed: *)
                ConcatLS(s, DocName);
                Error(s);
                *)
                RETURN;
            END;

            IF (NOT GetNextLine(F, Lrx - Ulx - 1, s)) THEN
                GetMessage(ModuleNumber + 6, s);               (*  Nothing in the file to get  *)
                Error(s);
                Close(F);   (* 12-Mar-91 RSC  *)
                RETURN;
            END;

            IF (NOT CreateEditNode(NextNode, ViewObject)) THEN
                GetMessage(ModuleNumber + 7, s);               (*  Insufficient memory to read in the file.  *)
                Error(s);
                Close(F);   (* 12-Mar-91 RSC  *)
                RETURN;
            END;

            IF (CursorColumn = 1) THEN
                CNode^.Methods^.AddBefore(CNode, NextNode);
            ELSIF (CursorColumn >= CNode^.Methods^.EndOfLine(CNode)) THEN
                CNode^.Methods^.AddAfter(CNode, NextNode);
                CNode := NextNode^.Methods^.GetNextVisible(NextNode);
                CursorColumn := 1;
            ELSE
                CNode^.Methods^.GetLine(CNode, 1, HIGH(s3), s3);
                CNode^.Methods^.AddAfter(CNode, NextNode);
                SubStr(s3, s2, CursorColumn, HIGH(s2));
                CNode^.Methods^.DeleteBlock(CNode, CursorColumn, 999);
                NextNode^.Methods^.PutLine(NextNode, 1, FALSE, s2);

                CNode := NextNode;
                CursorColumn := 1;

                IF (NOT CreateEditNode(NextNode, ViewObject)) THEN
                    GetMessage(ModuleNumber + 7, s);               (*  Insufficient memory to read in the file.  *)
                    Error(s);
                    Close(F);   (* 12-Mar-91 RSC  *)
                    RETURN;
                END;
                CNode^.Methods^.AddBefore(CNode, NextNode);
            END;
            NextNode^.Methods^.PutLine(NextNode, 1, FALSE, s);

            WHILE (GetNextLine(F, Lrx - Ulx - 1, s)) DO
                TNode := NextNode;
                IF (NOT CreateEditNode(NextNode, ViewObject)) THEN
                    GetMessage(ModuleNumber + 7, s);               (*  Insufficient memory to read in the file.  *)
                    Error(s);
                    Close(F);   (* 12-Mar-91 RSC  *)
                    RETURN;
                END;
                TNode^.Methods^.AddAfter(TNode, NextNode);
                NextNode^.Methods^.PutLine(NextNode, 1, FALSE, s);
                Message(s);                                       (* 29-Jan-88 LAA *)
            END;

            Close(F);                                           (* 9-Mar-88 EGK *)

            IF (CNode = NIL) THEN
                CNode := ViewObject^.Methods^.GetLast(ViewObject);
                CursorColumn := CNode^.Methods^.EndOfLine(CNode);
            END;
            ViewObject^.Methods^.SetChanged(ViewObject, TRUE);
            Methods^.Synchronize(AnEditView(EditView));
            Methods^.SetCursorNode(AnEditView(EditView), CNode);
        END;

    END DoReadFromFile;



    PROCEDURE DoWriteToFile();

    VAR
        Workspace           : AnEditWorkspace;
        Node                : AnEditNode;
        i                   : CARDINAL;
        F                   : File;
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoWriteToFile *)

        WITH EditView^ DO
            IF (NOT GetFileName(FALSE, DocName)) THEN RETURN; END;

            Workspace := CNode^.Methods^.GetList(CNode);
            Node := Workspace^.Methods^.GetFirst(Workspace);

            LStringToTString(DocName, s);
            Delete(s, F);
            PrepareForIO(F);
            Lookup(F, s, TRUE);
            IF (CheckIO(F) <> done) THEN
                DisplayFileError(F,DocName);
                (*   AJL 2/2/88
                GetMessage(ModuleNumber + 1, s);    (*  Unable to create a file to write to.  *)
                Error(s);
                *)
                RETURN;
            END;

            GetMessage(ModuleNumber + 3, s);        (* Writing your document to ~ *)
            ConcatLS(s, DocName);
            Message(s);

            WHILE (Node <> NIL) DO
                Node^.Methods^.GetLine(Node, 1, HIGH(s), s);
                Message(s);                                       (* 29-Jan-88 LAA *)
                PrepareForIO(F);
                FOR i := 1 TO LengthOf(s) DO
                    WriteChar(F, s[i]);
                END;
                WriteChar(F, EOL);
                IF (CheckIO(F) <> done) THEN
                    DisplayFileError(F,DocName);
                    (* AJL 2/2/88
                    GetMessage(ModuleNumber + 2, s);   (*  Error while writing the document.  *)
                    Error(s);
                    *)
                    Close(F);
                    RETURN;
                END;
                Node := Node^.Methods^.GetNextVisible(Node);
            END;
            Close(F);

            SetLengthOf(s, 0);
            Message(s);
        END;

    END DoWriteToFile;


        (*<PRINTOUTS*)
    PROCEDURE DoPrint();

    VAR
        Workspace           : AnEditWorkspace;
        Node                : AnEditNode;
        i                   : CARDINAL;
        Title               : ARRAY [0..0] OF CHAR;
        s                   : ARRAY [0..255] OF CHAR;

    BEGIN                   (* DoPrint *)

        GetMessage(ModuleNumber+8,s);    Title[0] := 0C;

        IF (NOT ContinuationBox(s,Title,NoHelp)) OR 
           (NOT StartReport()) THEN
            RETURN;
        END;

        WITH EditView^ DO
            Workspace := CNode^.Methods^.GetList(CNode);
            Node := Workspace^.Methods^.GetFirst(Workspace);

            WHILE (Node <> NIL) AND (NOT Stopped) DO
                Node^.Methods^.GetLine(Node, 1, HIGH(s), s);
                PrintLine(s,0);
                Node := Node^.Methods^.GetNextVisible(Node);
            END;
            EndReport();
        END;

    END DoPrint;
        (*PRINTOUTS>*)


        (* Paste the clipboard to the current line at the cursor position.
           This is a cheap implementation: it does not handle word wrap.
           *)

    PROCEDURE Paste();
    VAR
        SourceNode          : AnEditNode;
        S                   : ARRAY [0..255] OF CHAR;
    BEGIN
        PasteBuffer( S );     (* Pull the source string from the paste buffer. *)

        (*
        LJust(S);             (* Trim the blanks from it. *)
        *)
        TrimRear(S);

        (* 1-Apr-92 TGS paste string one char at a time, enable word wrap *)
        WHILE ( LengthOf(S) > 0 ) DO
            CNode^.Methods^.PutCharacter(CNode, EditView^.CursorColumn,
                                        TRUE, (* insert mode on *)
                                        S[1]);
            DoWordWrap(NeedsSync);
            DoFwrdKey();
            CNode := EditView^.Methods^.GetCursorNode(AnEditView(EditView));
            Remove(S, 1, 1);
        END;
        WITH EditView^ DO
            Methods^.Synchronize(AnEditView(EditView));
            Methods^.SetCursorNode(AnEditView(EditView), CNode);
            Methods^.Display(AnEditView(EditView));
        END;
        (*
        WITH EditView^ DO
            IF (CursorColumn <= RightMargin) THEN
                CNode^.Methods^.PutLine(CNode, CursorColumn, TRUE (* Insert Mode *), S);
            END;
        END;
        *)
    END Paste;

    PROCEDURE CopyLineToPasteBuffer();
    VAR
        SourceNode          : AnEditNode;
        S                   : ARRAY [0..255] OF CHAR;
    BEGIN
        WITH EditView^ DO
            CNode^.Methods^.GetLine(CNode, CursorColumn, 999, S);
        END;
        CopyToPasteBuffer( S );
    END CopyLineToPasteBuffer;

    (* CalculateLine -- Evaluate the current line, beginning at the 
                        cursor position, as a numeric expression,
                        replacing the expression with its value.
                        *)


    PROCEDURE CalculateLine();
    VAR
        SourceNode          : AnEditNode;
        Value               : REAL;
        i,j                 : CARDINAL;
        Problem             : BOOLEAN;
        S                   : ARRAY [0..255] OF CHAR;
    BEGIN
        WITH EditView^ DO
            CNode^.Methods^.GetLine(CNode, 1, 999, S);
            i := CursorColumn;
                (* If preceded by a space, keep the space. *)
            IF (i < LengthOf(S)) AND (S[i] = " ") THEN
                INC(i);
            END;
            j := i;
            EvaluateRealExpression(S,j,Value,DefaultAmountFormat,Problem);
            IF (NOT Problem) THEN
                IF (j > i) AND (S[j-1] = " ") AND    (* If a space after number, leave it. *)
                   (j < LengthOf(S)) THEN
                    DEC(j);
                END;
                FormatAsAmount( Value, DefaultAmountFormat, S, 25,
                                0, 7, FALSE );
                LJust(S);             (* Trim the blanks from it. *)
                TrimRear(S);
                CNode^.Methods^.DeleteBlock(CNode, i, j-i);
                CNode^.Methods^.PutLine(CNode, i, TRUE (* Insert Mode *), S);
            ELSE
                Burp();
            END;
        END;
    END CalculateLine;



    PROCEDURE Reformat();

    VAR
        SeperatorNode       : AnEditNode;
        SourceNode          : AnEditNode;
        TempNode            : AnEditNode;
        OriginalCursorNode  : AnEditNode;
        OriginalCursorCol   : CARDINAL;
        i                   : CARDINAL;
        s                   : ARRAY [0..255] OF CHAR;
        NeedsSync           : BOOLEAN;

        PROCEDURE GoForward();
        
        BEGIN               (* GoForward *)
    
            WITH EditView^ DO
                IF (CursorColumn <= RightMargin) THEN
                    INC(CursorColumn);
                ELSE
                    CursorColumn := 1;
                    TellParentView(Down);
                END;
            END;
    
        END GoForward;
    
    
    BEGIN                   (* Reformat *)

        WITH EditView^ DO
            OriginalCursorNode := CNode;
            OriginalCursorCol := CursorColumn;

            CNode^.Methods^.GetLine(CNode, 1, 999, s);
            CNode^.Methods^.DeleteBlock(CNode, 1, LengthOf(s));
            i := CursorColumn;
            WHILE (i < LengthOf(s)) DO
                IF ((s[i] = " ") AND (s[i + 1] = " ")) THEN
                    Remove(s, i, 1);
                ELSE
                    INC(i);
                END;
            END;
            CNode^.Methods^.PutLine(CNode, 1, FALSE, s);

            CursorColumn := CNode^.Methods^.EndOfLine(CNode);

            IF (NOT AddLineAfter(CNode)) THEN
                Burp();
                RETURN;
            END;
            SeperatorNode := CNode^.Methods^.GetNextVisible(CNode);

            SetCursorType(NoCursor);

            SourceNode := SeperatorNode^.Methods^.GetNextVisible(SeperatorNode);
            IF (SourceNode <> NIL) THEN
                SourceNode^.Methods^.GetLine(SourceNode, 1, 999, s);
                TrimRear(s);

                WHILE (((LengthOf(s) >= 1) AND (s[1] <> " "))
                    OR ((LengthOf(s) >= 2) AND (s[2] <> " "))) DO
                    TempNode := SourceNode^.Methods^.GetNextVisible(SourceNode);
                    SourceNode^.Methods^.DeList(SourceNode);
                    SourceNode^.Methods^.Discard(SourceNode);
                    SourceNode := TempNode;

                
                    CNode^.Methods^.PutCharacter(CNode, CursorColumn, TRUE, " ");
                    DoWordWrap(NeedsSync);
                    GoForward();
                    CNode := Methods^.GetCursorNode(AnEditView(EditView));
                    WHILE (LengthOf(s) > 0) DO
                        CNode^.Methods^.PutCharacter(CNode, CursorColumn, TRUE,
                                                     s[1]);
                        DoWordWrap(NeedsSync);
                        GoForward();
                        CNode := Methods^.GetCursorNode(AnEditView(EditView));
                        IF (s[1] <> " ") THEN
                            Remove(s, 1, 1);
                        ELSE
                            WHILE ((LengthOf(s) > 0) AND (s[1] = " ")) DO
                                Remove(s, 1, 1);
                            END;
                        END;
                    END;

                    IF (SourceNode <> NIL) THEN
                        SourceNode^.Methods^.GetLine(SourceNode, 1, 999, s);
                        TrimRear(s);
                    ELSE
                        SetLengthOf(s, 0);
                    END;
                END;
            END;

            SeperatorNode^.Methods^.DeList(SeperatorNode);
            SeperatorNode^.Methods^.Discard(SeperatorNode);

            IF (InsertMode) THEN
                SetCursorType(BlockCursor);
            ELSE
                SetCursorType(UnderlineCursor);
            END;

            CNode := OriginalCursorNode;
            CursorColumn := OriginalCursorCol;
            Methods^.Synchronize(AnEditView(EditView));
            Methods^.SetCursorNode(AnEditView(EditView), CNode);
        END;

    END Reformat;

    PROCEDURE ProcessMouseEvent ();
    VAR
        MouseArea           : AMouseClickPoint;
        LocalUlx            : ascreenx;
        LocalUly            : ascreeny;
        LocalLrx            : ascreenx;
        LocalLry            : ascreeny;
    BEGIN

        WITH EditView^ DO
            Methods^.GetExternalXY  ( AnEditView(EditView),
                                      LocalUlx, LocalUly, LocalLrx, LocalLry);

            MouseArea := CorrelateMousePoint ( LocalUlx, LocalUly, LocalLrx, LocalLry, Box,
                                               Event.EventX, Event.EventY );

            IF (Event.EventCode = MouseDown) THEN              (* 27-Dec-89 *)
                MouseDownRegion := ORD(MouseArea);
            ELSIF (MouseDownRegion <> ORD(MouseArea)) THEN
                RETURN;
            END;

            IF ( MouseArea = OnInside ) THEN
                CursorColumn := ( Event.EventX - LocalUlx ) - 1;
                IF ( CursorColumn = 0 ) THEN
                   CursorColumn := 1;
                END;
            END;
        END;

    END ProcessMouseEvent;



BEGIN                       (* EditViewActOn *)

    WITH EditView^ DO
        ErrorMarker := NewMarker();                               (* 29-Jan-88 LAA *)

        ReturnEvent.EventCode := 0;
        WantToRecord := TRUE;

        CNode := Methods^.GetCursorNode(AnEditView(EditView));

        CASE Event.EventCode OF
            Down :
                DoDown();
        |   LineDeleteKey :
                DoDeleteLine();
        |   DoIt :
                DoDoIt();
        |   HomeKey :
                DoHomeKey();
        |   EndKey :
                DoEndKey();
        |   RollRight :
                DoWordRight();
        |   RollLeft :
                DoWordLeft();
        |   Tab :
                DoTabKey();
        |   InsertKey :
                InsertMode := NOT InsertMode;
        |   DeleteKey :
                DoDeleteKey();
        |   BackSpace :
                DoBackSpace();
        |   Fwrd :
                DoFwrdKey();
        |   Reverse :
                DoReverseKey();
        |   EraseKey, EraseToEOLKey, AlternateEraseKey :
                CNode^.Methods^.DeleteBlock(CNode, CursorColumn, 999);
                    (*<PRINTOUTS*)
        |   PrintKey:
                DoPrint();
                    (*PRINTOUTS>*)
        |   WriteToFileKey :
                DoWriteToFile();
                SetLengthOf(MenuName, 0);                         (* 29-Jan-88 LAA *)
                Message(MenuName);
        |   ReadFromFileKey :
                DoReadFromFile();
                SetLengthOf(MenuName, 0);                         (* 29-Jan-88 LAA *)
                Message(MenuName);

(* ----
        |   PgUpKey :                                           (* 07-Jun-89 LAA *)
                TellParentView(GotoFirstKey);
        |   PgDnKey :
                TellParentView(GotoLastKey);
---- *)

        |   ReformatKey :
                Reformat();

        |   PasteKey :
                Paste();
        |   CopyToPasteKey:
                CopyLineToPasteBuffer();
        |   CalculateKey:
                CalculateLine();


        |   HelpKey :                                             (* 04-Mar-88 LAA *)
                OldCursor := GetCursorType();                     (* 09-Jun-89 LAA *)
                SetCursorType(NoCursor);
                CtoS(ModuleNumber, MenuName);
                GiveHelp(MenuName, 0, maxrow, RestoreTheScreen);
                SetCursorType(OldCursor);
        |   MouseDown, MouseStillDown :                           (* 9-Jan-90 MWP *)
                ProcessMouseEvent ();

                WITH EditViewMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AListView(EditView), Event, ReturnEvent);
                END;
                WantToRecord := (ReturnEvent.EventCode <> 0);
        ELSE
            IF ((Event.EventCode MOD 16) IN (ValidInput[Event.EventCode DIV 16])) THEN
                CNode^.Methods^.PutCharacter(CNode, CursorColumn, InsertMode,
                                             CHR(Event.EventCode));
                IF (NOT ErrorPosted(ErrorMarker)) THEN            (* 29-Jan-88 LAA *)
                    DoWordWrap(NeedsSync);
                    IF (NeedsSync) THEN
                        Methods^.Synchronize(AnEditView(EditView));
                    END;
                    DoFwrdKey();
                END;
            ELSE
                WITH EditViewMethodsRecord.SuperclassMethods^ DO
                    ActOnEvent(AListView(EditView), Event, ReturnEvent);
                END;
                WantToRecord := (ReturnEvent.EventCode <> 0);
            END;
        END;

        SubView[Cursor]^.Methods^.NotifyOfChange(SubView[Cursor]);

        IF (ErrorPosted(ErrorMarker)) THEN                        (* 29-Jan-88 LAA *)
            Burp();
        END;
        PopToMarker(ErrorMarker);

        IF ((WantToRecord) AND (Event.EventCode <> RepeatKey)) THEN  (* 14-Jul-88 LAA *)
            Methods^.RecordEvent(AnEditView(EditView), Event);
        END;
        Methods^.Display(AnEditView(EditView));
    END;

END EditViewActOn;





PROCEDURE EditViewGetCursorX(    EditView   : XEditView)
                                                        : CARDINAL;

BEGIN                       (* EditViewGetCursorX *)

    RETURN EditView^.CursorColumn;

END EditViewGetCursorX;




PROCEDURE EditViewGetInsertMode(    EditView : XEditView)
                                                         : BOOLEAN;

BEGIN                       (* EditViewGetInsertMode *)

    RETURN EditView^.InsertMode;

END EditViewGetInsertMode;





PROCEDURE EditViewGetLeftMargin(    EditView : XEditView)
                                                          : CARDINAL;

BEGIN                       (* EditViewGetLeftMargin *)

    RETURN EditView^.LeftMargin;

END EditViewGetLeftMargin;




PROCEDURE EditViewGetRightMargin(    EditView : XEditView)
                                                          : CARDINAL;

BEGIN                       (* EditViewGetRightMargin *)

    RETURN EditView^.RightMargin;

END EditViewGetRightMargin;




    (*  These procedure are exported from the module  *)


(*----------------------------------------------------------------------------
    InitAsEditView --

    Initialize the indicated object as an edit view.

    Preconditions:
        None.

    Postconditions:
        The object will be a valid edit view object.  No storage allocation
        is done by this procedure.
----------------------------------------------------------------------------*)

PROCEDURE InitAsEditView(    EditView       : AnEditView;
                             SuperView      : AnActiveView;
                             UlxP           : ascreenx;
                             UlyP           : ascreeny;
                             LrxP           : ascreenx;
                             LryP           : ascreeny;
                             BoxP           : ABoxType;
                             VideoModeP     : avidmode;
                         VAR Title          : ARRAY OF CHAR;
                             HelpKey        : CARDINAL;
                             TakeRug        : BOOLEAN      );

VAR
    PrivateEditView         : XEditView;
    y                       : ascreeny;

BEGIN                       (* InitAsEditView *)

    InitAsListView(AListView(EditView), SuperView, UlxP, UlyP, LrxP, LryP,
                   BoxP, VideoModeP, Title, HelpKey, TakeRug);
    PrivateEditView := XEditView(EditView);

    WITH PrivateEditView^ DO
        Methods := ADR(EditViewMethodsRecord);
        InsertMode := FALSE;
        CursorColumn := 1;
        LeftMargin := 1;
        Methods^.GetInternalXY(EditView, Ulx, Uly, Lrx, Lry);
        RightMargin := Lrx - Ulx - 1;
        y := Uly;

        WHILE (y <= Lry) DO
            Last := y - Uly;
            IF (NOT CreateStringView(SubView[Last + 1], AnActiveView(EditView),
                                     Ulx, y, Lrx, y, ABoxType{NoBox}, 
                                     VideoMode, HelpKey)) THEN
                DiscardSubViews(PrivateEditView);
                PostError(AllocationError, ModuleNumber);         (* 29-Jan-88 LAA *)
                RETURN;
            END;
            INC(y);
        END;
        INC(Last);
    END;

END InitAsEditView;






(*----------------------------------------------------------------------------
    CreateEditView --

    Allocate storage for, and initialize the indicated object as an edit
    view.

    Preconditions:
        None.

    Postconditions:
        Iff there is sufficient heap space available, the object will be 
        allocated and initialized as a valid edit view object, and TRUE
        will be returned.  
----------------------------------------------------------------------------*)

PROCEDURE CreateEditView(VAR EditView       : AnEditView;
                             SuperView      : AnActiveView;
                             Ulx            : ascreenx;
                             Uly            : ascreeny;
                             Lrx            : ascreenx;
                             Lry            : ascreeny;
                             Box            : ABoxType;
                             VideoMode      : avidmode;
                         VAR Title          : ARRAY OF CHAR;
                             HelpKey        : CARDINAL;
                             TakeRug        : BOOLEAN      ) 
                                                            : BOOLEAN;

VAR
    ErrorMarker             : AnErrorMarker;

BEGIN                       (* CreateEditView *)

    ErrorMarker := NewMarker();                                   (* 29-Jan-88 LAA *)

    IF (HeapAvailable()) THEN
        ALLOCATE(EditView, TSIZE(XEditViewRecord));
        InitAsEditView(EditView, SuperView, Ulx, Uly, Lrx, Lry, Box, VideoMode,
                       Title, HelpKey, TakeRug);

        IF (ErrorPosted(ErrorMarker)) THEN                        (* 29-Jan-88 LAA *)
            UnInitAsEditView(EditView);
            DEALLOCATE(EditView, TSIZE(XEditViewRecord));
        ELSE
            PopToMarker (ErrorMarker);                            (*  8-Mar-88 EGK *)
            RETURN TRUE;
        END;
    END;

    PopToMarker(ErrorMarker);                                     (* 29-Jan-88 LAA *)

    RETURN FALSE;

END CreateEditView;









(*----------------------------------------------------------------------------
    UnInitAsEditView --

    UnInitialize the indicated object as an edit view.

    Preconditions:
        The object must be a valid edit view object.

    Postconditions:
        Whatever was done by InitAsEditView has been un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsEditView(    EditView     : AnEditView);

BEGIN                       (* UnInitAsEditView *)

    DiscardSubViews(XEditView(EditView));
    UnInitAsListView(AListView(EditView));

END UnInitAsEditView;








(*----------------------------------------------------------------------------
    CloneEditViewMethods --

    Make a copy of the edit view methods into the indicated method object.

    Preconditions:
        None.

    Postcondition:
        The edit view methods will be copied into the indicated method 
        object.
----------------------------------------------------------------------------*)

PROCEDURE CloneEditViewMethods(    MethodObject : AnEditViewMethods);

BEGIN                       (* CloneEditViewMethods *)

    MethodObject^ := EditViewMethodsRecord;
    MethodObject^.SuperclassMethods := ADR(EditViewMethodsRecord);

END CloneEditViewMethods;








(*----------------------------------------------------------------------------
    ValidateEditView --

    Determine that the indicated object is in fact a valid edit view object.

    Preconditions:
        None.

    Postconditions:
        If the object is not a valid edit view object, FatalError will be
        called.
----------------------------------------------------------------------------*)

PROCEDURE ValidateEditView(    EditView : AnEditView);

VAR
    PrivateEditView         : XEditView;

BEGIN                       (* ValidateEditView *)

    PrivateEditView := XEditView(EditView);
    IF (PrivateEditView^.Methods^.EditViewTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateEditView;







BEGIN                       (* EditViews *)

    CloneListViewMethods(ADR(EditViewMethodsRecord));
    WITH EditViewMethodsRecord DO
        MethodSize := TSIZE(AnEditViewMethodsRecord);
        EditViewTag := ModuleNumber;
        Discard := AnEditViewDiscardProc(EditViewDiscard);
        ActOnEvent := AnEditViewActOnProc(EditViewActOn);
        GetCursorX := AnEditViewMarginProc(EditViewGetCursorX);
        GetInsertMode := AnEditViewIModeProc(EditViewGetInsertMode);
        GetLeftMargin := AnEditViewMarginProc(EditViewGetLeftMargin);
        GetRightMargin := AnEditViewMarginProc(EditViewGetRightMargin);
    END;
    ValidInput := EmptyCodeSet;
    SetCodeBits(ValidInput, 0, 254, TRUE);
    SetCodeBits(ValidInput, ORD(EOL), ORD(EOL), FALSE);
    SetCodeBits(ValidInput, CancelKey, CancelKey, FALSE);
    SetCodeBits(ValidInput, DoIt, DoIt, FALSE);
    SetCodeBits(ValidInput, ORD(lf), ORD(lf), FALSE);
    SetCodeBits(ValidInput, ORD(ht), ORD(ht), FALSE);

    (* RSC 2/3/88 - DocName should default to project media area, not dk: *)
    DefaultDocName[0] := 0C;
    ExpandPath( ProjectMedia, DefaultDocName, DocName );
    ConcatS( DocName, "*");

END EditViews.


