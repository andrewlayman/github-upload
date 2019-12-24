IMPLEMENTATION MODULE AllFormalName;

  (* All Formal Name - Routines to manage caches of column information.

        Modification History:

        30-Aug-89 MWP Creation.
  *)

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          DoDash, ConvertString;

FROM LStrings       IMPORT
                        SetLengthOf, Remove, Fill, LengthOf;

FROM MsgFile        IMPORT
    (* PROCS *)         GetMessage;

PROCEDURE PurgeCache ();
BEGIN

    CacheContents := MaxCardinal;

    InitCache ();

END PurgeCache;


PROCEDURE InitCache ();
VAR
    i  :  CARDINAL;
BEGIN

    FOR i := 1 TO HIGH(Cache) DO
        Cache[i].ColumnID := MaxCardinal;
    END;

END InitCache;


PROCEDURE SetupTranslation ();
CONST
    CModuleNumber    = 24300;
VAR
    i                   : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;
    s2                  : ARRAY [0..255] OF CHAR;
    ReplaceChar         : CHAR;

BEGIN
    GetMessage (CModuleNumber+1, s);     (* The string of legal characters *)
    ReplaceChar := s[1];
    Remove (s, 1, 1);                   (* Parse out the replace character *)
    i := 1;
    DoDash (s, s2, i);
    SetLengthOf (s2, i-1);
    Fill (CharTable, ReplaceChar, 255);
    FOR i := 1 TO LengthOf(s2) DO
        CharTable[ORD(s2[i])] := s2[i];
    END;
END SetupTranslation;


BEGIN
    SetupTranslation ();

END AllFormalName.
