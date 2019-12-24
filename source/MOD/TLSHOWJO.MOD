MODULE TLShowJoins;

    (*  MODIFICATION HISTORY
        07-Jun-89 LAA   First version.  Gets ShowJoins module out of the root.
        10-Aug-89 KKC   Add copyright message.
    *)

FROM Chart                  IMPORT
    (* VAR *)                   CursorTask;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM ShowJoins              IMPORT
    (* PROC *)                  HighlightJoinedTasks;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

VAR
    OverlayID               : AnOverlayID;

PROCEDURE DoShowJoin();
VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                       (* DoShowJoin *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    HighlightJoinedTasks(CursorTask);

END DoShowJoin;


BEGIN                       (* TLShowJoins *)

    OverlayID := ImAnInstallableOverlay( DoShowJoin, AnOverlayProc(NIL) );
    DoShowJoin();

END TLShowJoins.
