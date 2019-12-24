IMPLEMENTATION MODULE Assertions;

    (*  MODIFICATION HISTORY --
    08-May-90 LAA   First version.
    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;



(*  Assert --

    Validate the assertions about pre- and post-conditions of procedures
    by checking and calling FatalError if the condition passed is not
    TRUE.  If the condition is TRUE, nothing happens.

    Preconditions:
        The Dialogs module has been initialized (which happens during the
        initialization of Time Line's root).

    Postconditions:
        None.

    Parameters:
        Condition   -   a BOOLEAN derived from some condition which the
                        caller is asserting to be TRUE.
*)

PROCEDURE Assert(     Condition             : BOOLEAN );

BEGIN                       (* Assert *)

    IF (NOT Condition) THEN
        FatalError();
    END;
     
END Assert;

BEGIN                       (* Assertions *)
END Assertions.
