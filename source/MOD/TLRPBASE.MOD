MODULE TLRPBASE;

    (*  This module contains the basic routines needed to support
        reports.  It loads them into memory and then calls the
        actual report.
    *)

    (* MODIFICATION HISTORY:

        9/19/87 AJL - Use the new OverlayContext procedure.
        1/21/88 RSC - Forced Forms into this layer for all reports.
        2/10/88 RSC - RealFmt was being imported into this module.  I
                      removed it.
        8/10/89 KKC - Add copyright message.
        6-Feb-91 RSC  Removed PrintSupport and PrintCaptions.
    *)

(*IMPORT PrintSupport;*)

(*IMPORT PrintCaptions;*)

IMPORT Forms; (* Force forms into this layer to stop all reports from swelling *)

FROM Overlays IMPORT OverlayPackage, OverlayContext;

FROM   PrintStatic IMPORT  PrintCB, PrintDiskFileName,
                           ReportFinishedOK,
                           TranslateOverlay,
                           GlobalTimeOut,                         (* 27-Sep-89 MWP *)
                           AControlGroup, AControlStyle,
                           APrinterStyle, APortType,
                           AProtocol, PrintXLAT;


VAR
    OverlayList                 : POINTER TO ARRAY [0..99] OF CHAR;
    Copyright                   : ARRAY[0..50] OF CHAR;





PROCEDURE CheckForTranslation();
VAR
    ok  : BOOLEAN;
BEGIN
    IF (PrintCB.Style = OutToDisk) AND
       (PrintCB.ControlStyle = WPNormal) AND
       (TranslateOverlay[0] > 0C) THEN
        ok := OverlayPackage(TranslateOverlay);
    END;
END CheckForTranslation;





BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    ReportFinishedOK := FALSE;
    OverlayList := OverlayContext();
    IF (OverlayList <> NIL) AND (OverlayPackage(OverlayList^)) THEN
                (* Special post processing for translation of disk files.  *)
        IF (ReportFinishedOK) THEN
            CheckForTranslation();
        END;
    END;
END TLRPBASE.
