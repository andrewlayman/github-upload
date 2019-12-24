MODULE UnAlias;

     (* UnAlias -- Removes all of the user definitions for column names,
                   descriptions, etc.

        MODIFICATION HISTORY:

        19-Feb-91 AJL Initial version.

      *)


FROM ColData IMPORT
    (* TYPE *)  AColumnType,
    (* VAR *)   ColumnTable;

FROM Dialog IMPORT
    (* TYPE *)  ADialogOption,
    (* PROC *)  ContinuationBox;

FROM LStrings IMPORT
    (* PROC *)  SetString;

FROM Text IMPORT 
    (* PROC *)  CreateText, DiscardText;


VAR
    i : AColumnType;
    Title : ARRAY [0..31] OF CHAR;
    S     : ARRAY [0..255] OF CHAR;

BEGIN
    SetString(S,"This will remove all of the user-entered changes to columns.");
    SetString(Title,"Un-alias");
    IF (ContinuationBox(S,Title,NoHelp)) THEN
        FOR i := MIN(AColumnType) TO MAX(AColumnType) DO
            DiscardText(ColumnTable[i]);
            ColumnTable[i] := CreateText();
        END;
    END;
END UnAlias.
