(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module  :  Exec, provides access to the DOS shell.                   *)
(*                                                                            *)
(*       Release :    3.0 - July 87                                           *)
(*       Revised :    Gregor Kley, September 87                               *)
(*       Revised :    BZ, October 87                                  	      *)
(*                                                                            *)
(*       Copyright (C)  1987 Logitech, All rights reserved                    *)
(*       Permission is hereby granted to registered users to use or abstract  *)
(*       the following program in the implementation of customized versions.  *)
(*       This permission does not include the right to redistribute the       *)
(*       source code of this program.                                         *)
(*                                                                            *)
(******************************************************************************)

(* MODIFICATION HISTORY:

    RSC  22-Dec-89  Import from Space, not Storage.  Also, check available.
                    Return error 8222 if there is not enough memory to
                    allocate one block.
    RSC  21-Mar-91  Remove NEW/DISPOSE/Available, as the use of it while
                    exiting to dos conflicts with TLVidMem, who is a
                    memory provider.

                    Also, pass the name of command com down from the
                    caller, to avoid a pass at the PSP from this module
                    (which is code available elsewhere).
*)

(*$S-*)
(*$T-*)
(*$R-*)
(*$O-*)
IMPLEMENTATION MODULE Exec;

  FROM SYSTEM IMPORT
    DOSCALL,
    ADR, ADDRESS, TSIZE,
    ENABLE, DISABLE,
    CODE, SETREG, GETREG, SS, SP, BP, AX;

  CONST 
    EXEC   = 4BH;
    movSeg = 8EH;
    movReg = 8BH;
    AXtoSS = 0D0H;
    AXtoSP = 0E0H;
    AXtoBP = 0E8H;
  
  TYPE
    ParamBlock = RECORD
                   environmentSegment : CARDINAL;
                   commandLinePtr     : ADDRESS;
                   fcb1Ptr, fcb2Ptr   : ADDRESS;
                 END;
    ParamBlockPtr = POINTER TO ParamBlock;
 
  VAR
    paramBlockPtr: ParamBlockPtr;
    paramBlock   : ParamBlock;
    programNameAdr: ADDRESS;
    saveSS, saveSP, saveBP: CARDINAL;
    error : CARDINAL; (* this variable must be global ! *)
    
  PROCEDURE Execute(programName: ADDRESS;
                    environment: CARDINAL;
                    commandLineAdr: ADDRESS;
                    FCB1Adr, FCB2Adr: ADDRESS;
                    VAR errorReturn: CARDINAL);

  BEGIN

    paramBlockPtr := ADR(paramBlock);
    WITH paramBlockPtr^ DO
        environmentSegment := environment;
        commandLinePtr     := commandLineAdr;
        fcb1Ptr            := FCB1Adr;
        fcb2Ptr            := FCB2Adr;
    END;
    programNameAdr := programName;

    GETREG(SS, saveSS);
    GETREG(SP, saveSP);
    GETREG(BP, saveBP);
    DOSCALL (EXEC, programNameAdr, paramBlockPtr, 0, error);
    DISABLE;
    SETREG(AX, saveSS);
    CODE(movSeg, AXtoSS);
    SETREG(AX, saveSP);
    CODE(movReg, AXtoSP);
    SETREG(AX, saveBP);
    CODE(movReg, AXtoBP);
    ENABLE;

    errorReturn := error;
  END Execute;

  VAR
    commandLine : ARRAY [0..127] OF CHAR;
    fcb1, fcb2  : ARRAY [0..31] OF CHAR;




  PROCEDURE DosShell( VAR shell : ARRAY OF CHAR;
                      VAR done  : BOOLEAN );
  VAR
      err : CARDINAL;
  BEGIN
    commandLine[0] := CHR(0);
    Execute(ADR(shell), 0, ADR(commandLine), ADR(fcb1), ADR(fcb2), err);
    done := (err = 0);
  END DosShell;

BEGIN
  (* initialize dummy default FCB's *)
  fcb1 := "                                ";
  fcb1[0] := 0C;
  fcb2 := fcb1;
END Exec.


