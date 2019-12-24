IMPLEMENTATION MODULE HistStat;

(* MODIFICATION HISTORY
     9-Sep-91 TGS   Initialize HistogramsAreUp.
*)

PROCEDURE InitHistStat();
VAR i : CARDINAL;
BEGIN
    FOR i := 1 TO MaxResources DO
        HistResource[i,0] := 0C;
    END;
    HistInterlock := FALSE;
    HistogramsAreUp := FALSE; (* 9-Sep-91 TGS *)
END InitHistStat;



BEGIN
    InitHistStat();
END HistStat.

