IMPLEMENTATION MODULE ColForm;

(*  =========================================================================
    Last Edit : October 3, 1990 10:18AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Calls the column name form overlay.

    MODIFICATION HISTORY:

    10-Sep-90 PFG   Created to allow column name stuff to be in an overlay.
    26-Sep-90 PFG   Called overlay through TLFBASE.
    2-Oct-90  PFG   Change name of context record.  TLColName is now being
                    called with a different context.
    =========================================================================
*)

FROM LStrings               IMPORT
    (* PROC  *)                 SetString;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM SYSTEM                 IMPORT
                                ADR;



PROCEDURE DoColumnFormOverlay(VAR ColumnContext : AColumnContext);

VAR
    Result : BOOLEAN;
    s      : ARRAY[0..18] OF CHAR;

BEGIN

    SetString(s, "TLFBASE(TLCOLNAM)");
    Result := CallOverlayWithContext(s, ADR(ColumnContext));

END DoColumnFormOverlay;


BEGIN 
END ColForm.

