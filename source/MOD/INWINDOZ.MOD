MODULE InWindoz;

FROM RTSMain                IMPORT 
                                errorCode, Terminate, Status;

FROM Windows                IMPORT
    (* TYPE *)                  AWindowsType,
    (* PROC *)                  WindowsIsRunning;

BEGIN                       (* InWindoz *)

    errorCode := ORD(WindowsIsRunning() <> WindowsNotRunning);
    Terminate(Normal);

END InWindoz.
