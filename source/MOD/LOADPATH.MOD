(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module  :    LoadPath, path and name of the running .EXE             *)
(*                                                                            *)
(*       Release :    3.0 - July 87                                           *)
(*                                                                            *)
(*                                                                            *)
(*       Modification History :                                               *)
(*           01-Mar-89 WKH - CheckVersion wasn't allowing for versions of     *)
(*                           DOS greater than 3.9(i.e. 4.0 and above)         *)
(*                                                                            *)
(*           01-Jun-89 WKH - OK, really fix problem with Check Version!!!     *)
(*                                                                            *)
(*           11-Sep-89 WKH - Get the "correct" PSP address.                   *)
(*                                                                            *)
(*       Copyright (C)  1987 Logitech, All rights reserved                    *)
(*                                                                            *)
(*       Permission is hereby granted to registered users to use or abstract  *)
(*       the following program in the implementation of customized versions.  *)
(*       This permission does not include the right to redistribute the       *)
(*       source code of this program.                                         *)
(*                                                                            *)
(******************************************************************************)
IMPLEMENTATION MODULE LoadPath;

FROM SYSTEM IMPORT ADDRESS, DOSCALL;
FROM OurPSP IMPORT OurPSPAddress;

CONST VERSION = 30H;

PROCEDURE CheckVersion() : BOOLEAN;

VAR
    major, minor : CHAR;
    VersionNum   : CARDINAL;

BEGIN
    DOSCALL(VERSION, major, minor);

    VersionNum := ORD(major) * 100;
    VersionNum := VersionNum + ORD(minor);

    RETURN (VersionNum >= 310);
END CheckVersion;

PROCEDURE GetLoad(VAR str: ARRAY OF CHAR);
  (* Get the complete filename of the file loaded by MSDOS
          In the environnement:
          - Look for the sequence 0,0
          - Skip two bytes ( meaning unknown, often 1,0 )
          - Take next characters until a 0 
          Return empty string if:
          - Doesn't find 0,0
          - filename > HIGH(str)
  *)

  CONST maxEnv=MAX(CARDINAL)-1; (* maximum length of environnement *)
                                (* stop research after that *)
  VAR ptr : POINTER TO ARRAY [0..maxEnv] OF CHAR;
    addr1 : ADDRESS;
    i, j : CARDINAL;
BEGIN
  IF NOT CheckVersion() THEN
    str[0] := 0C;
    RETURN;
  END;
  addr1:=OurPSPAddress;
  INC(addr1,44);
  addr1.SEGMENT:=CARDINAL(addr1^);
  addr1.OFFSET:=0;
  ptr:=addr1;
  i:=0;
  WHILE ((ptr^[i]<>0c) OR (ptr^[i+1]<>0c)) AND (i<maxEnv) DO INC(i) END;
  IF (i<maxEnv) THEN 
    INC(i,4);
    j:=0;
    WHILE (j<=HIGH(str)) AND (ptr^[i]<>0c) DO
      str[j]:=ptr^[i];
      INC(j);
      INC(i);
    END;
    IF ptr^[i]=0c THEN
      IF j<=HIGH(str) THEN str[j]:=0c END;
    ELSE
      str[0]:=0c;
    END;
  ELSE
    str[0]:=0c;
  END;
END GetLoad;

PROCEDURE GetLoadDir(VAR str: ARRAY OF CHAR);
  (* Return the directory of the loaded file or empty string
       if problems
  *)
VAR i,lastslash: CARDINAL;
BEGIN
  GetLoad(str);
  i:=0;
  lastslash:=HIGH(str)+1;
  WHILE (i<=HIGH(str)) AND (str[i]<>0c) DO
    IF str[i]="\" THEN lastslash:=i END;
    INC(i);
  END;
  IF lastslash > HIGH(str) THEN
    str[0]:=0c;
  ELSE
    str[lastslash+1]:=0c;
  END;
END GetLoadDir;

END LoadPath.
