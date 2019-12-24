IMPLEMENTATION MODULE IEndFormat;

(*  =========================================================================
    Last Edit : September 26, 1990 5:47PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

    BEnd Format - Format Resource Information

        This module is intended to do for resources what Captions does for
        tasks.  That is, given a column ID, return information about a
        resource.

        At this time, only the information about a resource COLUMN is
        returned, not information about a specific resource.


        MODIFICATION History -

        23-Mar-89 RSC Added support for "better reports".
        26-Sep-90 PFG Added ColumnType parameter to ColumnInfo for 
                      user-defined column headings.
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

FROM LStrings               IMPORT
    (* PROC *)                  StoC;

(* ***** TEMP *****
FROM MagicNum               IMPORT
    (* CONST *)                 BEndModuleNumber;
****** *)






CONST  (* TEMP *)
    BEndModuleNumber        = 29209;    (* Overlaps TLXForm! *)


VAR
    BEndLastColumn          : CARDINAL;







(*
    Get BEnd Info

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
PROCEDURE XGetBEndInfo(     ColumnID      : CARDINAL;
                            InfoChoice    : AColumnInfoChoice;
                            Length        : CARDINAL;
                        VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > BEndLastColumn) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( BEndModuleNumber,
                    ColumnID,
                    BEndLastColumn,
                    InfoChoice, 
                    Length, 
                    NotEditableColumn,              (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END XGetBEndInfo;





PROCEDURE Setup();
VAR
    i : CARDINAL;
    s : ARRAY [0..79] OF CHAR;
BEGIN
    GetMessageWord( BEndModuleNumber, 0, s );  (* Number of rows - 1. *)
    i               := 1;
    BEndLastColumn  := (StoC( s, i ) + 1);
END Setup;





BEGIN

    GetBEndInfo := XGetBEndInfo;

    Setup();

END IEndFormat.
