
MODULE TLXTLCSV;

  (* TL X PLain CSV - Output report data to a CSV file format.

        MODIFICATION HISTORY:


        20-Aug-89 MWP   In the beginning...
   *)


FROM ExportLinkage  IMPORT
                            IsImportable;                          (* 5-Jul-89 MWP *)

FROM LStrings       IMPORT
                            SetString;

FROM Overlays       IMPORT
    (* PROC *)              CallOverlay;


VAR
    Copyright   : ARRAY[0..50] OF CHAR;
    Overlay     : ARRAY [0..39] OF CHAR;
    ok          : BOOLEAN;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IsImportable := TRUE;


    SetString( Overlay, "TLXCSV" );
    ok := CallOverlay ( Overlay );

END TLXTLCSV.
