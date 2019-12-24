(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module  : Mouse                            			      *)
(* 	 The functions implemented in this module provide a		      *)	
(*	 Modula-2 interface for the LOGITECH Mouse Driver.		      *)
(*	 This driver interface is compatible with the Microsoft		      *)
(*	 Mouse Driver interface, so this module can be used with	      *)
(*	 all the compatible mouse drivers.				      *)
(*	 For detailed description of these functions, please		      *)
(*	 refer to your mouse documentation:				      *)
(*									      *)
(*	 e.g. LOGITECH Mouse Driver Programmer's Reference Manual	      *)
(*       Microsoft Mouse, Installation and Operation Manual		      *)
(*									      *)
(*									      *)
(*	 Microsoft is a registered trademark of				      *)
(*	 Microsoft Corporation						      *)
(*									      *)
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
(*       MODIFICATION HISTORY                                                 *)
(*                                                                            *)
(*       8-Dec-89  RSC  Renamed to LMouse "Logitek Mouse" and applied my      *)
(*                      support for de-installing a mouse handler.            *)
(*      05-Sep-91  LAA  Added the SoftwareReset function, and fixed the       *)
(*                      SetEventHandler so that when it picks up the mask     *)
(*                      it make the high-order bits zero, rather than junk.   *)
(*                                                                            *)
(******************************************************************************)
IMPLEMENTATION MODULE LMouse;

  FROM SYSTEM IMPORT
    BYTE, ADDRESS, ADR,
    SETREG, GETREG, SWI, CODE,
    AX, BX, CX, DX, SI, DI, ES;




FROM Video      IMPORT
    (* TYPE *)      AnAdapterType,
    (* PROC *)      QueryAdapterType;





  PROCEDURE FlagReset(VAR mouseStatus: INTEGER;
                      VAR numberOfButtons: CARDINAL);
    VAR temp: CARDINAL;
  BEGIN
    SETREG(AX,0);
    SETREG(BX,3);
    SWI(33H);
    GETREG(BX,temp);
    GETREG(AX,mouseStatus);
    numberOfButtons := temp;
  END FlagReset;

  PROCEDURE ShowCursor;                                 
  BEGIN
    SETREG(AX,1);
    SWI(33H);
  END ShowCursor;

  PROCEDURE HideCursor;                                 
  BEGIN
    SETREG(AX,2);
    SWI(33H);
  END HideCursor;

  PROCEDURE GetPosBut(VAR buttonStatus: ButtonSet;
                      VAR horizontal, vertical:CARDINAL);
    VAR temp: ButtonSet;
  BEGIN
    SETREG(AX, 3);
    SWI(33H);
    GETREG(BX, temp);
    GETREG(CX, horizontal);
    GETREG(DX, vertical);
    buttonStatus:= temp;
  END GetPosBut;

  PROCEDURE SetCursorPos(horizontal, vertical: INTEGER);
  BEGIN
    SETREG(AX,4);
    SETREG(CX, horizontal);
    SETREG(DX, vertical);
    SWI(33H);
  END SetCursorPos;

  PROCEDURE GetButPres(button: Button;
                       VAR buttonStatus: ButtonSet;
                       VAR buttonPressCount: CARDINAL;
                       VAR horizontal, vertical: INTEGER);
    VAR temp: CARDINAL;
  BEGIN
    SETREG(BX, ORD(button));
    SETREG(AX, 5);
    SWI(33H);
    GETREG(BX, temp);
    GETREG(AX, buttonStatus);
    GETREG(CX, horizontal);
    GETREG(DX, vertical);
    buttonPressCount:= temp;
  END GetButPres;

  PROCEDURE GetButRel(button: Button;
                      VAR buttonStatus: ButtonSet;
                      VAR buttonReleaseCount: CARDINAL;
                      VAR horizontal ,vertical: INTEGER);
    VAR temp: CARDINAL;
  BEGIN
    SETREG(BX, ORD(button));
    SETREG(AX, 6);
    SWI(33H);
    GETREG(BX, temp);
    GETREG(AX, buttonStatus);
    GETREG(CX, horizontal);
    GETREG(DX, vertical);
    buttonReleaseCount:= temp;
  END GetButRel;

  PROCEDURE SetHorizontalLimits(minPos, maxPos: INTEGER);
  BEGIN
    SETREG(AX, 7);
    SETREG(CX, minPos);
    SETREG(DX, maxPos);
    SWI(33H);
  END SetHorizontalLimits;

  PROCEDURE SetVerticalLimits(minPos, maxPos: INTEGER);                   
  BEGIN
    SETREG(AX, 8);
    SETREG(BX, 0);
    SETREG(CX, minPos);
    SETREG(DX, maxPos);
    SWI(33H);
  END SetVerticalLimits;


  PROCEDURE SetGraphicCursor(VAR cursor: GraphicCursor);
    VAR a: ADDRESS;
        x,y: INTEGER;
  BEGIN
    WITH cursor DO
      x := hotX; y := hotY;
      a := ADR(screenMask);
    END;
    SETREG(DX,a.OFFSET);
    SETREG(ES,a.SEGMENT);
    SETREG(CX,y);
    SETREG(BX,x);
    SETREG(AX,9);
    SWI(33H);
  END SetGraphicCursor;

  PROCEDURE SetTextCursor(selectedCursor,
                          screenMaskORscanStart,
                          cursorMaskORscanStop: CARDINAL);
  BEGIN
    SETREG(AX, 10);
    SETREG(BX, selectedCursor);
    SETREG(CX, screenMaskORscanStart);
    SETREG(DX, cursorMaskORscanStop);
    SWI(33H);
  END SetTextCursor;

  PROCEDURE ReadMotionCounters(VAR horizontal,
                                   vertical:INTEGER);
  BEGIN
    SETREG(AX, 11);
    SWI(33H);
    GETREG(CX, horizontal);
    GETREG(DX, vertical);
  END ReadMotionCounters;


(*$A-*)
(* alignment off, in order to avoid *)
(* dummy byte after field FarCall   *)

  VAR
    PrivateHandler: RECORD
                      PushAX, PushBX, PushCX, PushDX: BYTE;
                      FarCall: BYTE;
                      handlerProc: EventHandler;
                      FarRet: BYTE;
                    END;

(*$A=*)
(* reset alignment to previous state *)


(*$S-*)(*$T-*)(*$R-*)
  PROCEDURE SetEventHandler(mask: EventSet;
                            handler: EventHandler);
    VAR subr: ADDRESS;
        i   : CARDINAL;
  BEGIN

    (* 19-Dec-89 RSC Ajust for slower poll rate on InPort mice.
    *)
(*    SETREG( AX, 28 );           (* Set interrupt rate               *)
    SETREG( BX, 2  );           (* to 30 per second (kinda slow)    *)
    SWI(33H);
*)
    (* 19-Dec-89 RSC Moved this non-reentrant code here. *)
    IF (Terminator <> TerminateProc) THEN
        OldTermProc := TerminateProc;
        TerminateProc := Terminator;
        WITH PrivateHandler DO
            PushAX := BYTE(50H);
            PushBX := BYTE(53H);
            PushCX := BYTE(51H);
            PushDX := BYTE(52H);
            FarCall := BYTE(9AH);
            FarRet := BYTE(0CBH);
        END; (* WITH *)
    END;

    PrivateHandler.handlerProc := handler;
    subr := ADR(PrivateHandler);
    i := ORD(BYTE(mask));
    SETREG(CX, i);
    SETREG(DX, subr.OFFSET);
    SETREG(ES, subr.SEGMENT);
    SETREG(BX, subr.SEGMENT);
    SETREG(AX, 12);
    SWI(33H);
  END SetEventHandler;

(*$S=*)(*$T=*)(*$R=*)

  PROCEDURE LightPenOn;                              
  BEGIN
    SETREG(AX,13);
    SWI(33H);
  END LightPenOn;

  PROCEDURE LightPenOff;                             
  BEGIN
    SETREG(AX,14);
    SWI(33H);
  END LightPenOff;

  PROCEDURE SetMickeysPerPixel(horPix, verPix: CARDINAL);
  BEGIN
    SETREG(AX, 15);
    SETREG(CX, horPix);
    SETREG(DX, verPix);
    SWI(33H);
  END SetMickeysPerPixel;

  PROCEDURE ConditionalOff(left, top,
                           right, bottom: INTEGER);
  BEGIN
    SETREG(AX, 16);
    SETREG(CX, left);
    SETREG(DX, top);
    SETREG(SI, right);
    SETREG(DI, bottom);
    SWI(33H);
  END ConditionalOff;

  PROCEDURE SetSpeedThreshold(threshold: CARDINAL);
  BEGIN
    SETREG(AX, 19);
    SETREG(DX, threshold);
    SWI(33H);
  END SetSpeedThreshold;



  PROCEDURE Terminator;
  BEGIN
    SETREG(AX, 2);
    SWI(33H);      (* hide cursor *)
    SETREG(AX, 0);
    SWI(33H);      (* reset mouse, disable user defined event handler, etc. *)
    TerminateProc := OldTermProc;
         (* SWI(22H);    30-Nov-89 RSC *)
  END Terminator;




(* ************************************************************ *)

(* 19-Dec-89 RSC

    Added these to help the interrupt handler find out what to use for
    pixel widths/heights, and to help TLSTATS to figure out what kind
    of mouse we have.
*)


(* Get the screen type and pixel sizes.
*)
PROCEDURE GetScreenSize( VAR PixelsPerCharX,
                             PixelsPerCharY     : CARDINAL );
BEGIN

    IF (QueryAdapterType() = MDA) THEN  (* MONO/HERCULES *)
        PixelsPerCharX := 9;
        PixelsPerCharY := 14;
    ELSE
        PixelsPerCharX := 8;
        PixelsPerCharY := 8;
    END;

END GetScreenSize;



    (* Returns the mouse type as per the MicroSoft function 36 (24H)

        MouseTypes              IRQs
        ----------              ---------------
        1   Bus mouse           0 - PS/2
        2   Serial mouse        2,3,4,5, or 7 - IRQ #
        3   InPort mouse
        4   PS/2 mouse
        5   HP Mouse
    *)
PROCEDURE GetMouseType( VAR VersionNumberMajor,
                            VersionNumberMinor,
                            MouseType,
                            IRQInUse               : CARDINAL );
VAR
    Versions,
    MouseStuff  : CARDINAL;
BEGIN
    SETREG(AX, 36);
    SWI(33H);
    GETREG( BX, Versions );
    GETREG( CX, MouseStuff );

    VersionNumberMajor := Versions DIV 0FFH;
    VersionNumberMinor := Versions MOD 0FFH;
    MouseType          := MouseStuff DIV 0FFH;
    IRQInUse           := MouseStuff MOD 0FFH;

END GetMouseType;





PROCEDURE SoftwareReset() : BOOLEAN;

CONST
    SoftwareReset           = 33;

VAR
    Stat1                   : INTEGER;
    Stat2                   : INTEGER;

BEGIN                       (* SoftwareReset *)

    SETREG( AX, SoftwareReset );
    SETREG( BX, 1 );
    SWI( 33H );
    GETREG( AX, Stat1 );
    GETREG( BX, Stat2 );    (* Number of buttons; not currently used *)

    RETURN (Stat1 = -1);

END SoftwareReset;




(* ************************************************************ *)






  CONST
    IRET = 0CFH;
  VAR
    MouseVector[0:204]: ADDRESS;
    TerminateProc[0:88H]: PROC;
    OldTermProc: PROC;

BEGIN
  DriverInstalled := (MouseVector.OFFSET <> 0) AND
                     (MouseVector.SEGMENT <> 0) AND
                     (CARDINAL(MouseVector^) MOD 256 <> IRET);

(* 19-Dec-89 RSC non-reentrant code moved to install of event handler. *)
END LMouse.
