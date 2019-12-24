IMPLEMENTATION MODULE Mouse;

(*  =========================================================================
    Last Edit : January 3, 1990 2:12PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Time Line Mouse Support ROOT module.

    MODIFICATION HISTORY:

         8-Dec-89 RSC  First version.

    =========================================================================
*)


    (* Mouse Present answers the musical question "Is there a mouse in
                        the house?"  This one is the default.
    *)
PROCEDURE NoMousePresentProc() : BOOLEAN;
BEGIN
    RETURN FALSE;
END NoMousePresentProc;




PROCEDURE NulProc();
BEGIN
END NulProc;





BEGIN  (* module Mouse *)

    MousePresent      := NoMousePresentProc;
    RepeatRate        := VAL(AMouseTime,1);  (* 0.08 seconds *)
    DoubleClickRate   := VAL(AMouseTime,6);  (* 0.33 seconds *)
    CancelDoubleClick := NulProc;

END Mouse.


