(*$S+*)
MODULE TLNCalc;

    (*  MODIFICATION HISTORY 
        18-Feb-88 LAA   Imported PTaskList here instead of in TLNet.
        03-Mar-88 LAA   Set NetworkDone if an overlay fails, and made this an
                        installable overlay.  Fixed bug by which summary 
                        phantoms could be left around if the second overlay
                        fails.
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        10-Aug-89 KKC   Add copyright message.
        11-Aug-89 CMH/KWC Only discard phantoms if tlnbuild had been called
                          to create phantoms first.
        19-Sep-89 EGK   Took out the above fix, since it was possible for
                        TSort to set FatalNetError after the phantoms had
                        been created.  In that case, they should be discarded
                        immediately after TLNBUILD finishes.  In any case,
                        discard phantoms after all sub-overlays finish.
        21-Sep-89 EGK   Changed this to use overlay packages instead of
                        implementing its own loop.
         1-Nov-89 EGK   Added call to GetNetData to try to avoid
                        recalculating the PERT view when the schedule has
                        not changed since the last time the view was up.
        21-Nov-89 EGK   Have THIS module put up the "Please wait" box for
                        all of the PERT calculations.
    *)

FROM Dialog                 IMPORT
    (* TYPE *)                  ABoxHandle,
    (* PROC *)                  ProgressBox, ReleaseBox;

FROM ExportLinkage          IMPORT
    (* PROC *)                  ParseAFlag;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

IMPORT NetBData;

FROM NetStatic              IMPORT
    (* VAR *)                   NetworkDone, FatalNetError;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, CallOverlayWithContext,
                                ImAnInstallableOverlay, OverlayPackage;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM NetCopy                IMPORT
    (* PROC *)                  GetNetData;

FROM NetPhantoms            IMPORT
    (* PROC *)                  DiscardSummaryPhantoms;

IMPORT PTaskList;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM Words                  IMPORT
    (* PROC *)                  ParseString;


CONST
    ModuleNumber        = 20200;

VAR
    OverlayID               : AnOverlayID;



PROCEDURE BoxStart () : ABoxHandle;
VAR
    s               : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage (ModuleNumber+24, s);        (* "Please wait ..." *)
    RETURN ProgressBox (s);
END BoxStart;



PROCEDURE TLNCalcBody();

VAR
    CallChain           : POINTER TO ARRAY [0..255] OF CHAR;
    PackageName         : ARRAY[0..50] OF CHAR; 
    Flag                : CHAR;
    i                   : CARDINAL;
    BoxHandle           : ABoxHandle;

BEGIN                       (* TLNCalcBody *)

        (* Borrow this string for the copyright notice *)

    PackageName := "Program Copyright (c) 1989 Symantec Corporation.";

    CallChain := OverlayContext();
    IF (CallChain <> NIL) THEN
        i := 1;
        ParseAFlag (CallChain^, Flag, i);

        (*  See if we can retrieve the old network data, if it's still
            valid.  If we're doing a TLGS PERT graph (Flag = "N"), then
            don't try to use that data, since TLGS may compute things
            slightly differently than the PERT view.  Our main goal is to
            make switching of VIEWS faster.
        *)

        IF (Flag <> "Y") OR (NOT GetNetData()) THEN
            ParseString (CallChain^, i, PackageName);

            BoxHandle := BoxStart();            (* 11/21/89 EGK *)

            NetworkDone := ((NOT OverlayPackage (PackageName)) OR FatalNetError);
            DiscardSummaryPhantoms;

            ReleaseBox (BoxHandle);
        END;
    END;

END TLNCalcBody;


BEGIN                       (* TLNCalc *)

    OverlayID := ImAnInstallableOverlay(TLNCalcBody, AnOverlayProc(NIL));
    TLNCalcBody();

END TLNCalc.
