
  (* MODIFICATION HISTORY:

       Oct 15 1987 RSC - Added "Changed" to the parameters of EditText.
       04-Nov-87   LAA   Take a rug of the first 3 lines of the screen, and
                         restore it when we leave the editor.  Give help when
                         the HelpKey is pressed.
       16-Dec-87   RSC   moved into this overlay from Edits.Mod.
       20-Jan-88   LAA   Made this an installable overlay.
        5-May-88   RSC   remove "one moment please" when note too big.
       01-Dec-88   LAA   At Kris' insistance, I added a progress box while
                         loading a note.
        6-Jan-89   RSC   Moved "AnOverlayProc" reference.
       10-Aug-89   KKC   Add copyright message.
        3-Jan-90   RSC   Mouse support - added "OK/CANCEL".
        9-Jan-90   MWP   Added vertical scroll bars.
        6-Oct-90   AJL   Add Help mouse buttons.
       31-Mar-91   AJL   Removed unused variables and imports.
       21-May-91   AJL   Use PourText to display prompt lines.
  *)


MODULE TlEdits;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType, ABoxAttribute;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption, ABoxHandle,
    (* PROC *)                  Message, Error, Burp, ContinuationBox,
                                ProgressBox, ReleaseBox;

FROM Edits                  IMPORT
    (* TYPE *)                  APrivateEditContext;

FROM EditObjects            IMPORT
    (* TYPE *)                  AnEditWorkspace, AnEditNode, 
    (* PROC *)                  CreateEditWorkspace, CreateEditNode;

FROM EditViews              IMPORT
    (* TYPE *)                  AnEditView,
    (* PROC *)                  CreateEditView;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, 
    (* PROC *)                  GetNextEvent;

FROM Helper                 IMPORT
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PourText, BreakRequested;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, ExitKey, HelpKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd, MaxColumn;

FROM LinkedListObjects      IMPORT
    (* TYPE *)                  ALinkedList, ALinkedListNode;

FROM LStrings               IMPORT
    (* PROC *)                  TrimRear, SetLengthOf;

FROM Mouse                  IMPORT
    (* PROC *)                  MousePresent;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROCS *)                 OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CreateText, TextExists, AppendLine, 
                                DiscardText, Compress, SizeOfText, LineExists,
                                CopyLine;



CONST
    ModuleNumber                = 20000;

VAR
    OverlayID                   : AnOverlayID;





PROCEDURE LoadTheWorkspace(    Text         : AText;
                           VAR Workspace    : AnEditWorkspace)
                                                              : BOOLEAN;

CONST
    PleaseWaitThreshold     = 4000;

VAR
    i                       : CARDINAL;
    Node                    : AnEditNode;
    PleaseWaitBox           : ABoxHandle;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* LoadTheWorkspace *)

    IF (CreateEditWorkspace(Workspace)) THEN
        IF SizeOfText(Text) > 0 THEN
            PleaseWaitBox := ABoxHandle(NIL);                     (* 01-Dec-88 LAA *)
            IF (SizeOfText(Text) > PleaseWaitThreshold) THEN
                GetMessage(ModuleNumber + 10, s);    (*  "One moment ..."  *)  
                PleaseWaitBox := ProgressBox(s);
            END;

            i := 0;
            WHILE LineExists(Text, i) DO
                IF ((NOT CreateEditNode(Node, Workspace)) 
                   OR (BreakRequested())) THEN
                    Workspace^.Methods^.Discard(Workspace);
                    IF (PleaseWaitBox <> ABoxHandle(NIL)) THEN    (* 01-Dec-88 LAA *)
                        ReleaseBox(PleaseWaitBox);
                    END;
                    RETURN FALSE;
                END;
                Workspace^.Methods^.AddLast(Workspace, Node);
                CopyLine(Text, i, s);
                Node^.Methods^.PutLine(Node, 1, FALSE, s);
                INC(i);
            END;
            IF (PleaseWaitBox <> ABoxHandle(NIL)) THEN            (* 01-Dec-88 LAA *)
                ReleaseBox(PleaseWaitBox);
            END;
        ELSE
            IF (NOT CreateEditNode(Node, Workspace)) THEN 
                Workspace^.Methods^.Discard(Workspace);
                RETURN FALSE;
            END;
            Workspace^.Methods^.AddLast(Workspace, Node);
        END;
    
        RETURN TRUE;
    END;

    RETURN FALSE;

END LoadTheWorkspace;




PROCEDURE SaveTheWorkspace(    Workspace    : AnEditWorkspace;
                           VAR Text         : AText)
                                                    : BOOLEAN;

VAR
    NewText                 : AText;
    Line                    : AnEditNode;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* SaveTheWorkspace *)
    
    NewText := CreateText();
    IF NOT TextExists(NewText) THEN
        GetMessage(ModuleNumber + 3, s);    (*  Insufficient memory to save editing changes  *)
        Error(s);
        RETURN FALSE;
    END;

    Line := Workspace^.Methods^.GetFirst(Workspace);
    LOOP
        IF (Line = NIL) THEN
            EXIT;
        END;
        Line^.Methods^.GetLine(Line, 1, 255, s);
        TrimRear(s);
        IF NOT AppendLine(s, NewText) THEN
            DiscardText(NewText);
            GetMessage(ModuleNumber + 4, s);    (*  Your document is too large to be saved. *)
            Error(s);
            RETURN FALSE;
        END;
        Line := Line^.Methods^.GetNext(Line);
    END;

    Compress(NewText);
    DiscardText(Text);
    Text := NewText;

    RETURN TRUE;

END SaveTheWorkspace;



(*----------------------------------------------------------------------------
    EditText --

    Allow editing of the indicated text, and replace it if changed.

    Preconditions:
        The text must have been created by the Text module.

    Postconditions:
        The text, as changed, will be returned.
----------------------------------------------------------------------------*)

PROCEDURE EditText(    Ulx                  : ascreenx;
                       Uly                  : ascreeny;
                       Lrx                  : ascreenx;
                       Lry                  : ascreeny;
                       Box                  : ABoxType;
                   VAR Title                : ARRAY OF CHAR;
                       HelpNumber           : CARDINAL;
                   VAR Text                 : AText;
                   VAR Changed              : BOOLEAN );

VAR
    EditView                : AnEditView;
    EditViewWorkspace       : AnEditWorkspace;
    TheEvent                : AnEvent;
    ReturnEvent             : AnEvent;
    TopNode                 : AnEditNode;
    Rug                     : ARug;
    LastY                   : ascreeny;
    RugTaken                : BOOLEAN;
    ReadyToGo               : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..81] OF CHAR;

BEGIN                       (* EditText *)

    Changed   := FALSE;  (* Not yet. *)
    ReadyToGo := FALSE;

    IF (MousePresent()) THEN
        Box := Box + ABoxType{HasOk,HasCancel,HasVScroll,HasHelp}; 
    END;

    IF (CreateEditView(EditView, NIL, Ulx, Uly, Lrx, Lry, Box, videonormal,
                       Title, HelpNumber, TRUE)) THEN

        IF (LoadTheWorkspace(Text, EditViewWorkspace)) THEN
            RugTaken :=  GetRug(0, 0, MaxColumn, GanttWStart - 1, Rug);
            SetLengthOf(s, 0);
            Message(s);
            GetMessage(ModuleNumber + 5, s);               (* editing instructions.  *)
            PourText( s, videonormal, 0, GanttWStart-2, MaxColumn, GanttWStart-2, LastY );
            GetMessage(ModuleNumber + 6, s);
            PourText( s, videonormal, 0, LastY+1, MaxColumn, LastY+1, LastY );

            EditViewWorkspace^.Methods^.SetChanged(EditViewWorkspace, FALSE);
            EditView^.Methods^.SetObject(EditView, 
                                         ALinkedList(EditViewWorkspace));
            TopNode := EditViewWorkspace^.Methods^.GetFirst(EditViewWorkspace);
            EditView^.Methods^.SetFirst(EditView, ALinkedListNode(TopNode));
            EditView^.Methods^.SetCursorNode(EditView, ALinkedListNode(TopNode));
            EditView^.Methods^.SetCursor(EditView, TRUE);
            EditView^.Methods^.Display(EditView);

            LOOP
                s[0] := 0C; (* RSC 5/4/88 *)
                Message(s); (* RSC 5/4/88 *)
                GetNextEvent(TheEvent);
                IF (TheEvent.EventCode = HelpKey) THEN
                    GetMessage(ModuleNumber + 9, s);               (* EDITHELP *)
                    GiveHelp(s, 0, GanttWEnd, RestoreTheScreen);
                    ReturnEvent := TheEvent;
                    ReturnEvent.EventCode := 0;
                ELSE
                    EditView^.Methods^.ActOnEvent(EditView, TheEvent, ReturnEvent);
                    Changed := (EditViewWorkspace^.Methods^.GetChanged(EditViewWorkspace));
                END;
                IF (ReturnEvent.EventCode = CancelKey) THEN
                    IF (Changed) THEN
                            (*  Escaping from the notepad will cause you to loose the changes you've made.  *)
                        GetMessage(ModuleNumber + 7, s);           
                        GetMessage(ModuleNumber + 8, s2);
                        IF (ContinuationBox(s, s2, OfferHelp)) THEN
                            Changed := FALSE; (* Well, it changed, but we discarded the changes. *)
                            EXIT;
                        END;
                    ELSE
                        EXIT;
                    END;
                ELSIF (ReturnEvent.EventCode = ExitKey) THEN
                    IF (Changed) THEN
                        GetMessage(ModuleNumber + 1, s);    (*  One moment please.  *)
                        Message(s);
                        IF (SaveTheWorkspace(EditViewWorkspace, Text)) THEN
                            EXIT;
                        END;
                    ELSE
                        EXIT;
                    END;
                ELSIF (ReturnEvent.EventCode <> 0) THEN
                    Burp();
                END;
            END;
            EditViewWorkspace^.Methods^.Discard(EditViewWorkspace);
            EditView^.Methods^.Discard(EditView);

            IF (RugTaken) THEN
                PutRug(0, 0, MaxColumn, GanttWStart - 1, Rug);
            END;

            RETURN;
        ELSE
            EditView^.Methods^.Discard(EditView);
        END;
    END;
    
    GetMessage(ModuleNumber + 2, s);    (*  Insufficient memory to edit  *)
    Error(s);

END EditText;




PROCEDURE DoEditText();
VAR
    PrivateEditContext : POINTER TO APrivateEditContext;
    Copyright          : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PrivateEditContext := OverlayContext();
    WITH PrivateEditContext^ DO
        EditText( PUlx, PUly, PLrx, PLry, PBox, PTitle, PHelpNumber,
                  PText, PChanged );
    END;

END DoEditText;





BEGIN                       (* Edits *)

    OverlayID := ImAnInstallableOverlay(DoEditText, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    DoEditText();

END TlEdits.


