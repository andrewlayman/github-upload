IMPLEMENTATION MODULE ColData;

(*  =========================================================================
    Last Edit : September 7, 1990 4:49PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Defines global Text for storing user-modified column headings.

    MODIFICATION HISTORY:

    5-Sep-90 PFG    First version.

    =========================================================================
*)

FROM Text   IMPORT
(* TYPE  *)     AText;


VAR
    ColumnType : AColumnType;

BEGIN  (* module ColData *)

    FOR ColumnType := MIN( AColumnType ) TO MAX( AColumnType ) DO
        ColumnTable[ColumnType] := AText(NIL);
    END;

END ColData.


