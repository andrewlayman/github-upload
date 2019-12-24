(*$S+ *)
(*$T- *)
(*$R- *)
(****************************************************************)
(*      RS232I14 --                                                                         *)
(*      Serial output using interrupt 14.                                       *)
(*      For the IBM PC and compatibles.                         *)
(*                                                              *)
(*          This implementation is designed to have the same    *)
(*      definition as the interrupt-driven version provided     *)
(*      by Logitech (with addition of modules ClearToSend       *)
(*      and DataSetReady).                                      *)
(*                                                              *)
(*      Andrew Layman, May 13, 1985.                            *)
(*                                                              *)
(****************************************************************)

IMPLEMENTATION MODULE RS232;


FROM Kbio IMPORT BreakRequested;
FROM SYSTEM IMPORT SETREG, GETREG, SWI, AX, BX, CX, DX;







CONST
    SerialInterrupt = 14H;

PROCEDURE StartReading ();
BEGIN
END StartReading;



PROCEDURE StopReading ();
BEGIN
END StopReading;

    (* Used to initialze the serial port to specific values. The legal
       values for the parameters are:
         baudRate: 300..9600
         stopBits: 1 or 2
         parityBit: TRUE / FALSE
         evenParity: TRUE / FALSE
         nbrOfBits: 5..8
    *)

(* <MWP> 04-May-89 *)

PROCEDURE Init (   PortNo : CARDINAL;
                 baudRate : CARDINAL;     stopBits   : CARDINAL;
                parityBit : BOOLEAN;      evenParity : BOOLEAN;
                nbrOfBits : CARDINAL; VAR result     : BOOLEAN);
VAR
    Parameters : BITSET;

BEGIN (* Init *)

        (* Set the high byte to 0 which is the command for
           parameter setting.  Set the low byte to the correct
           speed parameters. *)

    result := FALSE;
    CASE baudRate OF
         300: Parameters := {6};
      |  600: Parameters := {6,5};
      | 1200: Parameters := {7};
      | 2400: Parameters := {7,5};
      | 4800: Parameters := {7,6};
      | 9600: Parameters := {7,6,5};
      ELSE RETURN;
    END;

    IF stopBits = 2 THEN INCL (Parameters, 2);
    ELSIF stopBits <> 1 THEN RETURN;
    END;

    IF parityBit THEN INCL (Parameters, 3); END;

    IF evenParity THEN INCL (Parameters, 4); END;

    IF (nbrOfBits < 7) OR (nbrOfBits > 8) THEN RETURN END;

    IF NOT ODD (nbrOfBits) THEN INCL (Parameters, 0); END;

    IF nbrOfBits >= 7 THEN INCL (Parameters, 1); END;

    SETREG(AX,Parameters);

(* <MWP> 04-May-89 *)
(***
    SETREG(DX,0);                (* Serial port 1. *)
***)
    SETREG(DX,PortNo);                (* Serial port 1 or 2. *)
    SWI(SerialInterrupt);

    result := TRUE;
END Init;



PROCEDURE ClearToSend ( PortNo : CARDINAL ):BOOLEAN;
    CONST CTS = 4;
    VAR status: BITSET;
BEGIN

(* <MWP> 04-May-89 *)
(***
    SETREG(DX,0);          (* Serial port 1 or 2 *)
***)
    SETREG(DX,PortNo);          (* Serial port 1 or 2 *)
    SETREG(AX,0300H);      (* Get status *)
    SWI(SerialInterrupt);
    GETREG(AX,status);
    RETURN (CTS IN status);
END ClearToSend;


PROCEDURE DataSetReady ( PortNo : CARDINAL ):BOOLEAN;
    CONST DSR = 5;
    VAR status: BITSET;
BEGIN
(* <MWP> 04-May-89 *)
(***
    SETREG(DX,0);          (* Printer 1. *)
***)
    SETREG(DX,PortNo);          (* Serial port 1 or 2 *)
    SETREG(AX,0300H);
    SWI(SerialInterrupt);
    GETREG(AX,status);
    RETURN (DSR IN status);
END DataSetReady;


    (* If a character has been received, it is read and assigned to 'ch'
       and 'received' is set to TRUE. If no character has been received,
       'ch' is set to 0C and 'received' is set to FALSE.
    *)
PROCEDURE BusyRead (     PortNo   : CARDINAL;
                     VAR ch       : CHAR;
                     VAR received : BOOLEAN );
CONST
    DeltaCTS = 8;       (* Low bit, AH register. *)
VAR
    status: BITSET;
BEGIN
        (* See if the Clear-To-Send bit has changed.  If it has, then
           we probably have received a character.  If it has not changed,
           we have definitely not received one. *)
(* <MWP> 04-May-89 *)
(*****
    SETREG(DX,0);          (* Printer 1. *)
******)
    SETREG(DX,PortNo);          (* Serial Port 1 or 2. *)
    SETREG(AX,0300H);
    SWI(SerialInterrupt);
    GETREG(AX,status);
    IF (DeltaCTS IN status) THEN
(* <MWP> 04-May-89 *)
(******
        SETREG(DX,0);      (* Printer 1. *)
****)
        SETREG(DX,PortNo);      (* Serial port 1 or 2 *)
        SETREG(AX,0200H);  (* Read.      *)
        SWI(SerialInterrupt);
        GETREG(AX,status);
        ch := CHR(CARDINAL(status * {0..7}));         (* AL *)
           (* Check the line control status byte for errors. *)
        received :=  ( status * {8..15} ) = {};       (* AH *)
    ELSE
        received :=  FALSE;
    END;
END BusyRead;




    (* Reads a character from the buffer and returns it in 'ch'.
       This routine returns control to the calling program only after
       a character has been received.
    *)
PROCEDURE Read (     PortNo : CARDINAL;
                 VAR ch     : CHAR );
  VAR done: BOOLEAN;
BEGIN
    LOOP
(* <MWP> 04-May-89 *)
(***
      BusyRead (ch, done);
***)
      BusyRead (PortNo, ch, done);
      IF done OR BreakRequested() THEN EXIT END;
    END;
END Read;


    (* Writes 'ch' to the port. No interpretation of characters is made *)

PROCEDURE Write ( PortNo : CARDINAL;
                  ch     : CHAR);
CONST
   WriteRequest = 0100H;
VAR
   Register : CARDINAL;
BEGIN
    Register := WriteRequest + ORD(ch);
    SETREG(AX,Register);
(* <MWP> 04-May-89 *)
(******
    SETREG(DX,0);          (* Printer 1. *)
****)
    SETREG(DX,PortNo);          (* Printer 1. *)
    SWI(SerialInterrupt);
END Write;






BEGIN
END RS232.
