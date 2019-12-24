    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<DOS*)
MODULE TLFBase;
(*DOS>*)

(*<OS2
IMPLEMENTATION MODULE TLFBase;
OS2>*)

 (* TLFBase - Form Base Layer.

        This overlay, like TLRpBase, is used to keep code out of the root
        and yet avoid making all forms users 16K bigger.

        RSC 21-Jan-88 - Initial version.
        22-Jan-88 LAA   New overlay context scheme.
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        14-May-89 AJL   When this overlay was called from the RunMenu
                        module, based on the script in TLWHAT4.CFG, it
                        would not pass a context to the next overlay.
                        Now, it will take any parenthesized string following
                        the overlay name and pass it.  I made this change to
                        support the TLDOS overlay.
        09-Aug-89  KKC  Add copyright message.
        10-Aug-89  WKH  Initial OS/2 edits.
         6-Feb-91  RSC  Remove FormHand.
 *)

IMPORT  Forms;    (* Load forms into this layer *)
IMPORT  FormCon;
IMPORT  FormRec;
(*IMPORT  FormHand;*)           (* 6-Feb-91 RSC  *)

FROM LStrings        IMPORT
    (* PROC *)         Copy;

FROM Overlays        IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROCS *)     CallOverlayWithContext, OverlayContext,
                        OverlayCallChain, ImAnInstallableOverlay;

FROM OvTree          IMPORT
    (* TYPE *)          AnOverlayProc;

FROM SYSTEM          IMPORT
        (* Thing *)     ADR, ADDRESS;

FROM Words      IMPORT
    (* PROC *)     ParseBal;




VAR
    OverlayID               : AnOverlayID;
    Copyright               : ARRAY[0..50] OF CHAR;



PROCEDURE TLFBaseBody();

VAR
    Context   : ADDRESS;
    CallChain : POINTER TO ARRAY [0..255] OF CHAR;
    i         : CARDINAL;
    OverlayName : ARRAY [0..15] OF CHAR;
    Parms : ARRAY [0..61] OF CHAR;
BEGIN                       (* TLFBaseBody *)
    Context   := OverlayContext();
    CallChain := OverlayCallChain();

    IF (CallChain^[0] = 0C) THEN (* Handle RunMenu calls too ... *)
        CallChain := Context;
        i := 1;
        ParseBal( CallChain^,i,OverlayName);              (* File Name *)
        ParseBal( CallChain^,i,Parms);                    (* Parameters *)
        Context := ADR(Parms);
    ELSE
        Copy(CallChain^,OverlayName);
    END;

    IF (CallChain <> NIL) AND
       (CallOverlayWithContext( OverlayName, Context )) THEN
    END;
END TLFBaseBody;


(*<OS2
PROCEDURE TLFBaseBind ();
OS2>*)

BEGIN
(*<DOS*)
    OverlayID := ImAnInstallableOverlay(TLFBaseBody, AnOverlayProc(NIL));       (* 19-Jan-88 LAA *)
(*DOS>*)
    TLFBaseBody();

(*<OS2
END TLFBaseBind;
OS2>*)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
END TLFBase.
