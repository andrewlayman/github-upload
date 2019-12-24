(*$S+*)
MODULE TLNetList;

    (* Modification History:

        6-Jan-89 RSC    Moved "AnOverlayProc" reference.
       24-May-89 WKH    No one is ever going to believe this but, as Ed, Roger, and
                        Larry as my witnesses, we were having overlay conflict
                        problems that were solved by just importing Dialog and not
                        referencing it.......
       10-Aug-89 KKC    Add copyright message.
    *)

IMPORT Dialog; (* 5/24/89 WKH *)

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM NetLList               IMPORT
    (* PROC *)                  ChooseNetLayout;


VAR
    OverlayID               : AnOverlayID;


PROCEDURE TLNetListBody();
VAR
    Copyright       : ARRAY[0..50] OF CHAR;
BEGIN                       (* TLNetListBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    ChooseNetLayout();

END TLNetListBody;


BEGIN                       (* TLNetList *)

    OverlayID := ImAnInstallableOverlay(TLNetListBody, AnOverlayProc(NIL));
    TLNetListBody();

END TLNetList.
