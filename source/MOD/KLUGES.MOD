IMPLEMENTATION MODULE Kluges;

    (* Kluges -

        Implement things we forgot in the root.

        RSC 8/15/88 - New module.

        This module defines a stealable procedure vector to allow for a number of
        hooks into the root of Time Line for "Things We Forgot".

        Passed is a message, to be determined jointly by the users of the
        procedure, and a context pointer that can be modifed by the caller or
        callee.

        Returns a boolean value that can be examined by the caller.  Be default,
        FALSE means "It didn't work" and TRUE means "ok".
    *)

FROM SYSTEM IMPORT ADDRESS;




PROCEDURE OurThingsWeForgotProc( Message : CARDINAL;
                             VAR Context : ADDRESS   ) : BOOLEAN;
BEGIN
    RETURN FALSE;  (* I am not yet a kluge, master *)
END OurThingsWeForgotProc;


BEGIN

    ThingsWeForgot := OurThingsWeForgotProc;

END Kluges.
