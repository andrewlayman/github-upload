IMPLEMENTATION MODULE OurPSP;

(*  =========================================================================
    Last Edit : June 19, 1991 2:58PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Provide the address variable OurPSPAddress to replace the PSPAddress
        in RTSMain.  The method used there is incorrect in DOS 3.0 and above.

    MODIFICATION HISTORY:
        11-Sep-89 WKH   Initial Version
        15-Sep-89 WKH   Use the GetProgramSegmentPrefix call only on DOS 4.0
                        and above.  Turns out that the method of looking at
                        the ES or DS register upon inital program load still
                        works, and in fact is being maniuplated by the
                        Logitech Debuggers.  So the net affect is that to
                        maintain compatibility with the debuggers, we have
                        to use the old method of retrieveing the PSP.  Side
                        note, unless there are new debuggers, we won't be 
                        able to debug under DOS 4.0 and above.
        19-Jun-91 RSC   Remove import of DOS3 code, and replace the tiny
                        fragment we need with inline code.

    =========================================================================
*)

FROM RTSMain                IMPORT 
    (* VAR  *)                  PSPAddress;

FROM SYSTEM                 IMPORT
    (* CONST *)                 AX, BX,
    (* TYPE *)                  ADDRESS, 
    (* PROC *)                  DOSCALL, SETREG, GETREG, SWI;

CONST 
    ModuleNumber            = 90;
    VERSION                 = 30H;
    MinVersion              = 400;

PROCEDURE CheckVersion() : CARDINAL;

VAR
    major, 
    minor                   : CHAR;
    VersionNum              : CARDINAL;

BEGIN
    DOSCALL(VERSION, major, minor);

    VersionNum := ORD(major) * 100;
    VersionNum := VersionNum + ORD(minor);

    RETURN (VersionNum);
END CheckVersion;

PROCEDURE PatchPSP();

VAR
    addr1                   : ADDRESS;
    bx                      : CARDINAL;
BEGIN
    IF (CheckVersion() >= MinVersion) THEN
            (* 19-Jun-91 RSC Remove DOS3 code.
            *)
        SETREG(AX, 6200H);
        SWI(21H);
        GETREG(BX, bx);
        addr1.SEGMENT := bx;
        addr1.OFFSET  := 0;
        OurPSPAddress := addr1;
    ELSE
        OurPSPAddress := PSPAddress;
    END;
END PatchPSP;

BEGIN  (* module OurPSP *)
    PatchPSP();    
END OurPSP.


