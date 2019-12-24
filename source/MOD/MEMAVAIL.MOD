IMPLEMENTATION MODULE MemAvail;

(*  =========================================================================
    Last Edit : August 5, 1989 9:49PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Supplant memory management for OS/2

    MODIFICATION HISTORY:
        05-Aug-89 WKH   Initial Version

    =========================================================================
*)

FROM MemManager             IMPORT 
                                DosAllocSeg, ShareFlagType, DosFreeSeg;


PROCEDURE OSMemAvail (size: CARDINAL) : BOOLEAN;

VAR
    err                     : CARDINAL;
    selector                : CARDINAL;

BEGIN
    err := DosAllocSeg ( size, selector, ShareFlagType{} );
    IF ( err <> 0 ) THEN
	    RETURN FALSE;
    END;

    err := DosFreeSeg ( selector );
    IF ( err <> 0 ) THEN
	    RETURN FALSE;
    END;

    RETURN TRUE;

END OSMemAvail;

END MemAvail.
