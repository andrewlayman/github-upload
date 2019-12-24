MODULE TLGSSAVE;

(*  =========================================================================
    Last Edit : December 27, 1989 12:28PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Ask user if he wants to save the schedule before actually going off
        to do a plot.

    MODIFICATION HISTORY:
        19-Dec-89 WKH   Initial Version.
        21-Dec-89 WKH   Get autosave option from TLGSPageRecord.
                        Option to save is now part of TLGSPage form instead
                        of a separate standalone dialog box.

    =========================================================================
*)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSPageRecordPtr,
    (* PROC *)                  TLGSPageRecord;

FROM Overlays               IMPORT
    (* VAR  *)                  OverlayPackage, PackageOK,
    (* PROC *)                  OverlayContext;


CONST
    ModuleNumber            = 10000;

PROCEDURE TLGSSaveMain();

VAR
    Context                 : POINTER TO ARRAY [0..255] OF CHAR;
    PageRecord              : ATLGSPageRecordPtr;   (* 21-Dec-89 WKH  *)
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN
    Context    := OverlayContext();
    Copyright  := "Program Copyright (c) 1989 Symantec Corporation.";

    PageRecord := TLGSPageRecord(); (* 21-Dec-89 WKH  *)

    IF (PageRecord^.AutoSave) THEN  (* 21-Dec-89 WKH  *)
        PackageOK := OverlayPackage(Context^);
    END;
END TLGSSaveMain;

BEGIN

    TLGSSaveMain();

END TLGSSAVE.

