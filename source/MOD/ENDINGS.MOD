IMPLEMENTATION MODULE Endings;

(* 19-Jun-91 RSC Remove import of ErrorCodes module.
*)
FROM RTSMain IMPORT errorCode, Terminate, Status;

    (* This doesn't actually pass the error level to DOS, though if
       called with a non-zero ErrorLevel DOS will get a non-zero
       (1) error code. *)

PROCEDURE EndWithErrorLevel( ErrorLevel : CARDINAL );
BEGIN
    errorCode := ErrorLevel;
    Terminate(Normal);
END EndWithErrorLevel;

BEGIN
    CompletionCode := 0;
    QuitDammitCode := 0;
END Endings.
