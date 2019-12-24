MODULE TLXDB;

    (*  Modification History:

        RSC  2-Feb-89   Change to use OverlayPackage.
        KKC  09-Aug-89  Add copyright message.

        This is the base layer for exporters to fixed-record style
        database products.
    *)


IMPORT NormalExport;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayPackage, OverlayContext;





VAR
    Context     : POINTER TO ARRAY [0..255] OF CHAR;
    ok          : BOOLEAN;
    Copyright   : ARRAY[0..50] OF CHAR;



BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    ok      := OverlayPackage( Context^ );   (* RSC 2-Feb-89 *)

END TLXDB.
