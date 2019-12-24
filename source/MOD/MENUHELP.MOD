IMPLEMENTATION MODULE MenuHelper;

(*  =========================================================================
    Last Edit : April 11, 1991 4:15PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This module defines structs to aid communication between
        Menus and RunMenus and TLMenu.



    MODIFICATION HISTORY:

    RSC 11-Apr-91   First version.

    =========================================================================
*)

FROM Keys       IMPORT
    (* CONST *)     CancelKey;

FROM LStrings   IMPORT
    (* PROC *)      SetString;

FROM Overlays   IMPORT
    (* PROC *)      CallOverlayWithContext;

FROM SYSTEM     IMPORT
    (* PROC *)      ADR;





(*$S+*)
PROCEDURE DoMenuFunction(     MenuFunction : AMenuFunction;
                          VAR MenuContext  : AMenuContext   );
VAR
    s   : ARRAY [0..9] OF CHAR;
BEGIN
    SetString( s, "TLMENUS" );
    MenuContext.MenuFunction := MenuFunction;
    IF (NOT CallOverlayWithContext( s, ADR(MenuContext) )) THEN
        MenuContext.ReturnCode := CancelKey;
        MenuContext.CSize      := 1;
    END;
END DoMenuFunction;
(*$S=*)




END MenuHelper.


