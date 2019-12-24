(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(* 	 Module: DiskDirectory						      *)
(*	  Provides an interface to the directory and disk		      *)
(*        functions of the underlying operating system,			      *)
(*        which are not dealing with specific files.			      *)
(*                                                                            *)
(*       Release :    3.0 - July 87                                           *)
(*                                                                            *)
(*       Copyright (C)  1987 Logitech, All rights reserved                    *)
(*                                                                            *)
(*       Permission is hereby granted to registered users to use or abstract  *)
(*       the following program in the implementation of customized versions.  *)
(*       This permission does not include the right to redistribute the       *)
(*       source code of this program.                                         *)
(*                                                                            *)
(******************************************************************************)

(*
    MODIFICATION HISTORY

    RSC  22-Dec-89  Allow drives greater than "P".
*)
(*$T-*)
(*$R-*)
IMPLEMENTATION MODULE DiskDirectory;		(* WS, opje *)

  FROM SYSTEM IMPORT  DOSCALL, ADR, ADDRESS;

  TYPE
    FileName = ARRAY [0..80] OF CHAR;
      (* longest possible filename in MS-DOS *)

  CONST
    (* the MSDOS function-calls: *)
    ResetSystem = 13;
    SelDisk = 14;
    GetCurrDisk = 25;
(*    ResetDr = 37; *)




PROCEDURE CurrentDrive (VAR drive: CHAR);
BEGIN
  DOSCALL (GetCurrDisk, drive);
  INC (drive,ORD('A'));
END CurrentDrive;


PROCEDURE SelectDrive (drive: CHAR; VAR done: BOOLEAN);
  VAR cch: CHAR; result: BOOLEAN;
BEGIN
  cch := CAP(drive);
  (* 22-Dec-89 RSC allow drive letters > "P" *)
(*  done := FALSE;*)
(*  IF ('A'<=cch) AND (cch<='P') THEN*)
    DOSCALL (SelDisk, ORD(cch)-ORD('A'), result);
    done := TRUE;
(*  END;*)
END SelectDrive;


PROCEDURE CurrentDirectory (drive: CHAR; VAR dir: ARRAY OF CHAR);
VAR dirAdr:ADDRESS; result : CARDINAL;
BEGIN
  dirAdr:=ADR(dir);
  drive := CAP(drive);
  IF drive = ' ' THEN
    drive := 0C;
  ELSE
  (* 22-Dec-89 RSC allow drive letters > "P" *)
(*  ELSIF (drive >= 'A') AND (drive <= 'P') THEN*)
    drive := CHR (ORD(drive)-ORD('A')+1);
(*    dir[0] := 0C;*)
(*    RETURN;*)
  END;
  DOSCALL(47H,drive,dirAdr,result);
  IF result=15 THEN
    dir[0] := 0C;
  END;
END CurrentDirectory;


PROCEDURE ChangeDirectory (dir: ARRAY OF CHAR; VAR done: BOOLEAN);
  VAR
    dirAdr:ADDRESS; result:CARDINAL;
    dircopy: FileName;
    i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(dir)) AND (i <= HIGH(dircopy)) AND (dir[i] <> 0C) DO
    dircopy[i] := dir[i];
    INC(i);
  END;
  IF i <= HIGH(dircopy) THEN dircopy[i] := 0C END;
  dirAdr:=ADR(dircopy);
  DOSCALL(3BH,dirAdr,result);
  IF result=0 THEN
    done:=TRUE
  ELSE
    done := FALSE;
  END;
END ChangeDirectory;


PROCEDURE MakeDir (dir: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR dirAdr:ADDRESS; result:CARDINAL;
    dircopy: FileName;
    i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(dir)) AND (i <= HIGH(dircopy)) AND (dir[i] <> 0C) DO
    dircopy[i] := dir[i];
    INC(i);
  END;
  IF i <= HIGH(dircopy) THEN dircopy[i] := 0C END;
  dirAdr:=ADR(dircopy);
  DOSCALL(39H,dirAdr,result);
  IF result=0 THEN
    done:=TRUE
  ELSE
    done := FALSE;
  END;
END MakeDir;


PROCEDURE RemoveDir (dir: ARRAY OF CHAR; VAR done: BOOLEAN);
VAR dirAdr:ADDRESS; result:CARDINAL;
    dircopy: FileName;
    i: CARDINAL;
BEGIN
  i := 0;
  WHILE (i <= HIGH(dir)) AND (i <= HIGH(dircopy)) AND (dir[i] <> 0C) DO
    dircopy[i] := dir[i];
    INC(i);
  END;
  IF i <= HIGH(dircopy) THEN dircopy[i] := 0C END;
  dirAdr:=ADR(dircopy);
  DOSCALL(3AH,dirAdr,result);
  IF result=0 THEN
    done:=TRUE
  ELSE
    done := FALSE;
  END;
END RemoveDir;



PROCEDURE ResetDiskSys;
BEGIN
  DOSCALL (ResetSystem);
END ResetDiskSys;


PROCEDURE ResetDrive (d: CHAR): CARDINAL;
  VAR drives: BITSET; i: CARDINAL;
BEGIN
(*
  IF (d > 'P') OR (d < 'A') THEN RETURN (255); END;
  i := ORD (d) - ORD ('A');
  drives := {};
  INCL (drives, i);
  CPMCALL (ResetDr, drives, i);
  RETURN (i);
*)
  RETURN (255);
END ResetDrive;


END DiskDirectory.
