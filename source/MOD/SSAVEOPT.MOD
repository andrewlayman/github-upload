IMPLEMENTATION MODULE SSaveOptions;

(*
    MODIFICATION HISTORY:
        14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
*)


FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  LocateHeldItem, HoldThis;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlayWithContext;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;


CONST
    HoldName                = "SelSaveOptions";
    HoldClass               = 8968;             (* My new phone number *)



PROCEDURE GetSaveSettings (  VAR Settings   : ASaveSetting );

VAR
    s                       : ARRAY [0..20] OF CHAR;
    Category                : AHoldTypeSet;
    Size                    : CARDINAL;
    Where                   : POINTER TO ASaveSetting;

BEGIN
    SetString (s, HoldName);
    IF (LocateHeldItem (s, HoldClass, Category, Where, Size)) THEN
        Settings := Where^;
    ELSE
        WITH Settings DO
            FilterResources := FALSE;
            CursorTaskOnly := FALSE;
            DiscardKids := FALSE;
        END;
    END;
END GetSaveSettings;



PROCEDURE PutSaveSettings (  VAR Settings   : ASaveSetting );

VAR
    s                       : ARRAY [0..20] OF CHAR;
    Category                : AHoldTypeSet;
    Size                    : CARDINAL;
    Where                   : POINTER TO ASaveSetting;

BEGIN
    SetString (s, HoldName);
    IF (NOT LocateHeldItem (s, HoldClass, Category, Where, Size)) THEN
        Size := TSIZE(ASaveSetting);
        IF (Available (Size)) THEN
            NEW (Where);
        ELSE
            RETURN;
        END;
    END;

    Where^ := Settings;
    HoldThis (s, HoldClass, AHoldTypeSet{HoldInConfig, HoldInDataFile},     (* 9/14/89 EGK *)
              Where, Size);

END PutSaveSettings;



PROCEDURE DoSaveDialog () : BOOLEAN;
VAR
    Done            : BOOLEAN;
    s               : ARRAY [0..20] OF CHAR;
    OK              : BOOLEAN;

BEGIN
    SetString (s, "\TLFBASE(TLXSSOPT)");
    Done := FALSE;
    OK := CallOverlayWithContext (s, ADR(Done));
    RETURN (OK AND Done);

END DoSaveDialog;




END SSaveOptions.
