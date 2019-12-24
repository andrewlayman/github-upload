IMPLEMENTATION MODULE XTabFormat;

(*  =========================================================================
    Last Edit : September 26, 1990 5:47PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

    XTab Format - Format XTab Information

        This module is intended to do for XTabs what Captions does for
        tasks.  That is, given a column ID, return information about a
        Cross Tab column.


        MODIFICATION History - 

        21-Mar-89 RSC First version, for Ken's "Better Reports" project.
        26-Sep-90 PFG Added ColumnType parameter to ColumnInfo for 
                      user-defined column headings.
         3-Nov-90 AJL Import column numbers from XTabColNumbers rather
                      than MagicNumbers.
    =========================================================================
  *)


FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  FormatColumnValue;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM FormatCommon           IMPORT
    (* PROC *)                  ColumnInfo, GetFormattingInfo,
                                GetMessageWord, ConcatMessageWord;

FROM XTabColNumbers         IMPORT
    (* CONST *)                 XTabModuleNumber, XTabLastColumn;










(*
    Get XTab Info

        Preconditions
                        > ColumnID  is the column to return information about.

                        > InfoChoice is the kind of information you are
                          interested in.  See Captions.Def for the choices.

                        > Length is the length of the string to return,
                          important mostly for Right Justified strings.

        Postconditions
                        > If TRUE, InfoValue contains the desired information.
                          If a string value is being returned, it may be right
                          justified, and is always exactly "Length" bytes long.

                        > If FALSE, The column does not exist.  This allows
                          looking for information on ALL columns.
*)
PROCEDURE XGetXTabInfo(     ColumnID      : CARDINAL;
                            InfoChoice    : AColumnInfoChoice;
                            Length        : CARDINAL;
                        VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > XTabLastColumn) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( XTabModuleNumber,
                    ColumnID,
                    XTabLastColumn,
                    InfoChoice, 
                    Length, 
                    XTabColumnInfo,             (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END XGetXTabInfo;






BEGIN
    GetXTabInfo     := XGetXTabInfo;
END XTabFormat.
