MODULE TLBookM;

     (* TLBookM -- Book Marks for Time Line tasks.

        Pressing one of the keys Alt-1 through Alt-0 will record
        a bookmark for the cursor task.  Pressing Alt-J will 
        ask for a jump to one of those marks.

        Andrew Layman, Dec. 19, 1990

     *) 




FROM Chart IMPORT GanttChart, CursorDay, MChTask, MChDay;

FROM Codes  IMPORT ACode, ASetOfCodes, EmptyCodeSet;

FROM Dialog   IMPORT Message, FatalError, Burp, Error,
                     NotYetImplemented, ADialogOption,
                     MultipleChoiceBox;

FROM GanttOutlines IMPORT AGanttOutline;

IMPORT Keyboard;

FROM LStrings IMPORT SetString, StoC, CtoS, ConcatS, ConcatLS,
                     LengthOf, SetLengthOf;

FROM Menus    IMPORT NoYes;

FROM MsgFile  IMPORT GetMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices, RegisterForNotices;

FROM Overlays      IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure,
                        CallOverlayWithContext;

FROM OvTree        IMPORT
    (* TYPE *)          AContextListEntry, AnOverlayProc,
    (* VAR  *)          OverlayTree;

FROM SYSTEM        IMPORT ADDRESS, ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeNodeAttribute;





CONST
    ModuleNumber    = 16800;
    NumberOfMarks   = 9;
    FirstMarkKey    = 376;    (* Alt-1 *)
    JumpKey         = 292;    (* Alt-J *)   


VAR
    Marks : ARRAY [0..NumberOfMarks-1] OF ATreeNode;
    Interlock   : CARDINAL;
    OldGetCode              : Keyboard.AGetCodeProcedure;
    OverlayID               : AnOverlayID;



PROCEDURE SetMark( i : CARDINAL );
VAR
    CNode                   : ATreeNode;
    S                       : ARRAY [0..81] OF CHAR;
    S2                      : ARRAY [0..7] OF CHAR;
BEGIN
    IF (Marks[i] <> ATreeNode(NIL)) THEN
        CtoS(i+1,S2);
        SetString(S,"Overwrite mark ");
        ConcatLS(S,S2);  ConcatS(S,"?");
        IF NOT NoYes(S) THEN
            RETURN;
        END;
    END;

    CNode := GanttChart^.Methods^.GetCursorNode(AGanttOutline(GanttChart));
    Marks[i] := CNode;

    SetString(S,"Bookmark set.");
    Message(S);

END SetMark;



PROCEDURE JumpTo( i : CARDINAL );
VAR
    Node                   : ATreeNode;
BEGIN
    Node := Marks[i];
        (* Open up any parents as necessary for visibility. *)
    LOOP
        Node := Node^.Methods^.Parent (Node);
        IF (Node = NIL) THEN
            EXIT;
        END;
        IF (NOT Node^.Methods^.TestAttributeBit(Node, Select1)) THEN    (* 28-Dec-89 WKH  *)
            SendNotices (OpenATask, BeforeActing, Node);
            Node^.Methods^.SetChildrenVisible (Node, TRUE);
        END;
    END;
        (* Set cursor to this node. *)
    MChTask(Marks[i]);
END JumpTo;





PROCEDURE Jump();
VAR
    S                       : ARRAY [0..31] OF CHAR;
    Choices                 : ARRAY [0..31] OF CHAR;
    MarkNumber              : ARRAY [1..NumberOfMarks] OF CARDINAL;
    ActiveMarks             : CARDINAL;
    S2                      : ARRAY [0..7] OF CHAR;
    i                       : CARDINAL;
BEGIN
    ActiveMarks := 0;
    SetLengthOf(Choices,0);
    FOR i := 0 TO HIGH(Marks) DO
        IF Marks[i] <> ATreeNode(NIL) THEN
                (* Describe the mark. *)
            CtoS(i+1,S2);
                (* Note its sequence in the list of marks. *)
            INC(ActiveMarks);
                (* Add to the menu list. *)
            IF (ActiveMarks > 1) THEN
                ConcatS(Choices,",");
            END;
            ConcatLS(Choices,S2);
                (* Record which mark was just described. *)
            MarkNumber[ ActiveMarks ] := i;
        END;
    END;

    IF (ActiveMarks > 0) THEN
        SetString(S,"Jump To");
        SetString(S2,"");
        IF MultipleChoiceBox(S2,S,NoHelp,S,Choices,i) THEN
            JumpTo(MarkNumber[i]);
        END;
    END;

END Jump;


PROCEDURE XGetCode():CARDINAL;
VAR
    C  : CARDINAL;
BEGIN
    IF (Interlock > 0) THEN
        RETURN OldGetCode();
    END;

    INC(Interlock);

    C := OldGetCode();

    IF (C=JumpKey) THEN
        Jump();
        C := 0;   (* Substitute a null return. *)
    ELSIF (C >= FirstMarkKey) AND (C < FirstMarkKey+NumberOfMarks) THEN
        SetMark(C-FirstMarkKey);
        C := 0;   (* Substitute a null return. *)
    END;


    DEC(Interlock);
    RETURN C;

END XGetCode;



PROCEDURE ClearAll();
VAR
    i : CARDINAL;
BEGIN
    FOR i := 0 TO HIGH(Marks) DO
        Marks[i] := ATreeNode(NIL);
    END;
END ClearAll;



PROCEDURE NoticeRemoval( Occasion : AnOccasion;
                         Step     : AStep;
                         Context  : ADDRESS ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
    IF (Step <> RequestPermission) THEN
        IF (Occasion = ModelErase) THEN
            ClearAll();
        ELSE (* Task deletion *)
            FOR i := 0 TO HIGH(Marks) DO
                    (* If the deleted task is in the marks list,
                       remove it from the list. *)
                IF Marks[i] = ATreeNode(Context) THEN
                    Marks[i] := NIL;
                END;
            END;
        END;
    END;
    RETURN TRUE;   (* No objection. *)
END NoticeRemoval;





BEGIN
    Interlock := 0;

        (* Install our keystroke handler into the keystroke handling chain. *)

    InstallNewProcedure(ADR(Keyboard.GetAnyCode), PROC(XGetCode), ADR(OldGetCode));  (* RSC 2-Mar-89 *)

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), AnOverlayProc(NIL) );

        (* There are no marks, yet. *)

    ClearAll();

        (* Notice removal of any marked tasks. *)
    RegisterForNotices(ModelErase,NoticeRemoval);
    RegisterForNotices(DeleteATask,NoticeRemoval);


END TLBookM.
