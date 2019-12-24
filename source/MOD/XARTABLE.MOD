IMPLEMENTATION MODULE XArTable;

(*  =========================================================================
    MODIFICATION HISTORY:
    27-Jan-92 TGS   Added FixV4ArtemisTable proc. Bug 5391.
*)

FROM Holder                 IMPORT 
    (* TYPE *)                  AHoldTypeSet,
    (* PROC *)                  DeleteHeldItem, LocateHeldItem;

FROM LStrings               IMPORT 
    (* PROC *)                  SetString;

FROM SYSTEM                 IMPORT 
                                TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST  *)                CodingField1;

(*
    UpdateOldColumnID --

    Account for any column IDs that have changed since prior releases.

    This version of the procedure currently handles the version 4 to
    version 5 changes.

*)

PROCEDURE UpdateOldColumnID(VAR ID : CARDINAL);

CONST
    (*  The Aux ("CodingField") columns were moved from version
        4 to version 5.  *)
    OldAuxCol1          = 103;
    OldAuxCol20         = 122;

BEGIN
    IF (ID >= OldAuxCol1) AND (ID <= OldAuxCol20) THEN
        ID := CodingField1 + (ID - OldAuxCol1);
    END;
END UpdateOldColumnID;


    (* Used by TLITL4 to renumber the UserDef ColumnID numbers.
       There wasn't enough identifier space to put it in TLITL4. *)

PROCEDURE FixV4HeldArtemisTable();
VAR
    ARTExportP              : POINTER TO AnArtemisExportTable;
    Size, Class             : CARDINAL;
    Category                : AHoldTypeSet;
    Name                    : ARRAY [0..8] OF CHAR;
BEGIN
    Class := 3;
    SetString( Name, "TLXAFORM" );
    IF (LocateHeldItem( Name, Class, Category, ARTExportP, Size )) THEN
        IF (Size = TSIZE(AnArtemisExportTable)) THEN
            UpdateOldColumnID(ARTExportP^.UserDef1);
            UpdateOldColumnID(ARTExportP^.UserDef2);
            UpdateOldColumnID(ARTExportP^.UserDef3);
            UpdateOldColumnID(ARTExportP^.UserDef4);
        ELSE
            DeleteHeldItem( Name, Class );
        END;
    END;

END FixV4HeldArtemisTable;

END XArTable.
