    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
MODULE TLErase;
(*DOS>*)

(*<OS2
IMPLEMENTATION MODULE TLErase;
OS2>*)


(*  =========================================================================
    Last Edit : August 23, 1989 10:57AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        TLErase is a shell that runs the EraseAll procedure from Tran2.

    MODIFICATION HISTORY:

        21-Aug-89  EGK  First version to remove things from the root.
        23-Aug-89  RSC  Take a context to override the dialog.
                        "N" means "No dialog."  Also, I OS-2-ized this
                        module.
         8-Jan-91  AJL  If the schedule has not been saved, ask before
                        erasing it.

    =========================================================================
*)



FROM Dialog                 IMPORT
     (* TYPE *)                 ADialogOption,
     (* PROCS *)                ContinuationBox;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext;

FROM Schedule               IMPORT
    (* VAR *)                   ScheduleSaved;

FROM Tran2                  IMPORT
    (* PROC *)                  EraseAll;


CONST
    ModuleNumber = 3300; (* For GetMessage, shared with Tran2.   *)




PROCEDURE DoFileErase();
VAR
    ContextArea     : POINTER TO ARRAY [0..255] OF CHAR;
    S1              : ARRAY [0..255] OF CHAR;
    NullString      : ARRAY [0..0]   OF CHAR;
    DoDialog        : BOOLEAN;

BEGIN
    S1 := "Program Copyright (c) 1989 Symantec Corporation.";

    ContextArea := OverlayContext();
    DoDialog    := (ContextArea = NIL) OR (ContextArea^[1] <> "N");

    IF (ScheduleSaved) THEN
        GetMessage( ModuleNumber + 0, S1 );
    ELSE
        GetMessage( ModuleNumber + 5, S1 );
    END;
    SetLengthOf(NullString, 0);

    IF (NOT DoDialog) OR (ContinuationBox(S1, NullString, NoHelp)) THEN
        EraseAll();
    END;

END DoFileErase;




(*<OS2
PROCEDURE TLEraseBind();
OS2>*)

BEGIN
    DoFileErase();

(*<OS2
END TLEraseBind;
OS2>*)


END TLErase.
