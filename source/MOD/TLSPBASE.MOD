MODULE TLSpBase;

(*  =========================================================================
    Last Edit : February 15, 1991 2:25PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        TLSpread's base overlay, to cut down the size of TLSpread.

    MODIFICATION HISTORY:

        14-Feb-91 RSC  First version.
        15-Feb-91 RSC  Changed the imports to balance the size.

    =========================================================================
*)

FROM LStrings   IMPORT
    (* PROC *)      SetString;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImAnInstallableOverlay, CallOverlayWithContext,
                    OverlayContext;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

(*IMPORT  TaskChange;*)
IMPORT ParseTime;
IMPORT ColFind;
IMPORT Matches;

VAR
    OverlayID                   : AnOverlayID;
    OverlayName                 : ARRAY [0..9] OF CHAR;


PROCEDURE DoSpreadsheet();
VAR
    ok  : BOOLEAN;
BEGIN
    SetString( OverlayName, "TLSPREAD" );
    ok := CallOverlayWithContext( OverlayName, OverlayContext() );
END DoSpreadsheet;

BEGIN
    OverlayID := ImAnInstallableOverlay( DoSpreadsheet, AnOverlayProc(NIL) );
    DoSpreadsheet();
END TLSpBase.

