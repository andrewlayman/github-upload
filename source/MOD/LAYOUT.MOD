IMPLEMENTATION MODULE Layout;

    (* MODIFICATION HISTORY:
       10-Jun-89      WKH - Made MaxRow a variable so that Time Line can
                            support a display that displays more than the
                            "usual" 25 lines.
    *)

FROM Kbio     IMPORT maxrow;

BEGIN
    MenuStart   := 0;
    MenuEnd     := 2;
    GanttWStart := 3;
    MaxRow      := 24;
    GanttWEnd   := MaxRow-1;
END Layout.
