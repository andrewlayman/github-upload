    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE FatalErr;

(*$S+*)

    (* MODIFICATION HISTORY:

        03-Oct-88 RSC       - Split off from Dialog.Mod.  Shares Module #!
        11-Oct-88 RSC       - Made it use same stuff as old dialog.
        05-Aug-89 WKH       - Initial edits for OS/2.
        04-Dec-89 LAA       - Because of a dump of TLDOS, I noticed that
                              calls to FatalError can sometimes be recursive.
                              This can happen when something fails along the
                              Notices path, and possibly elsewhere, too.  It's
                              a problem, because the dump that results from
                              a stack overflow won't show you the source of
                              the problem!  So I put an interlock into
                              LocalFatalError to prevent it from doing this.
    *)


FROM Dialog       IMPORT
        (* PROCS *)       Error;

FROM GaGa         IMPORT
        (* PROCS *)       GetGaGaMessage;

FROM Kbio         IMPORT
        (* PROCS *)       KbioTerminate;

FROM Keyboard     IMPORT
        (* PROCS *)       GetAnyCode;

(*<DOS*)
FROM RTSMain      IMPORT
        (* PROCS *)       Terminate, Status;
(*DOS>*)

(*<OS2
FROM RTSTypes     IMPORT
        (* TYPES *)       Status;

FROM RTSTerm      IMPORT
        (* PROCS *)       Terminate;
OS2>*)




CONST
    ModuleNumber = 1600;  (* SAME AS DIALOG.MOD !! *)

VAR
    FatalErrorInterlock     : BOOLEAN;





PROCEDURE LocalNotify();
BEGIN
END LocalNotify;





PROCEDURE LocalFatalError();
VAR
    s : ARRAY [ 0..255 ] OF CHAR;
BEGIN

    IF (FatalErrorInterlock) THEN                                 (* 04-Dec-89 LAA *)
        FatalErrorInterlock := FALSE;
        HALT;
    END;

    FatalErrorInterlock := TRUE;
    FatalErrorNotify();
    GetGaGaMessage( ModuleNumber + 3, s ); (* <fatal error message> *)
    Error(s);
    
    KbioTerminate;
    FatalErrorInterlock := FALSE;
    Terminate(Warning);

    (* Not useable now, as we use Error().  See FatalEr2.Mod *)
    (* **** Code := FatalErrorGetCode(); **** *)

END LocalFatalError;











BEGIN
    FatalErrorInterlock := FALSE;                                 (* 04-Dec-89 LAA *)
    FatalErrorGetCode   := GetAnyCode;       (* Defaults *)
    FatalErrorNotify    := LocalNotify;
    FatalError          := LocalFatalError;
END FatalErr.
