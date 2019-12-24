MODULE TLTimer;

    (***************************************************************)
    (*                                                             *)
    (*   TimeLine Event Timer for debugging.                       *)
    (*                                                             *)
    (***************************************************************)
(* Modification History:

     2-Mar-89   RSC - Changed parameters to "InstallNewProcedure".
     7-Mar-89   RSC - Changed parameters to "InstallNewProcedure".
     09-Aug-89  KKC - Add copyright message.
     28-May-91  RSC - Use ImALockedOverlay rather than Chainer.
     20-Jun-91  RSC - Handle crossing day boundaries.  Thanks, Kris G.
*)
  FROM LStrings    IMPORT SetString, TrimRear, ConcatS, ConcatLS;
  FROM Dialog      IMPORT Error;
  FROM RealFormat  IMPORT FormatAsAmount, DefaultAmountFormat;
  FROM SYSTEM      IMPORT ADR, ADDRESS, SETREG, GETREG, SWI, AX, CX, DX;

  IMPORT Keyboard;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImALockedOverlay, InstallNewProcedure;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;



CONST
    MagicModeKey         = 251;

TYPE
   Time = RECORD day, minute, millisec: CARDINAL; END;


VAR
    OverlayID               : AnOverlayID;
    OldGetCode              : Keyboard.AGetCodeProcedure;
    StartTime               : Time;





  PROCEDURE GetTime (VAR curTime: Time);
  VAR cx, dx: CARDINAL;
  BEGIN
    SETREG(AX,2A00H);
    SWI(21H);
    GETREG(CX,cx);   (* CX = year 1980..2099  *)
    GETREG(DX,dx);   (* DH = month  1..12     *)
                     (* DL = day    1..31     *)
    curTime.day := (cx-1900)*512 + (dx DIV 256)*32 + (dx MOD 256);
    SETREG(AX,2C00H);
    SWI(21H);        (* get time -> CX:DX     *)
    GETREG(CX,cx);   (* CH = hour 0..23       *)
                     (* CL = min  0..59       *)
    GETREG(DX,dx);   (* DH = sec  0..59       *)
                     (* DL = sec/100  0..99   *)
    curTime.minute := (cx DIV 256)*60 + (cx MOD 256);
    curTime.millisec := (dx DIV 256)*1000 + (dx MOD 256)*10;
  END GetTime;




PROCEDURE OurGetCode():CARDINAL;
VAR
    Code    : CARDINAL;
BEGIN
    LOOP
        Code := OldGetCode();
        IF (Code = MagicModeKey) THEN
            DoIt();
        ELSE
            GetTime( StartTime );
            RETURN Code;
        END;
    END;
END OurGetCode;






PROCEDURE DoIt();
VAR
    EndTime    : Time;
    ElapsedTime: REAL;
    s1         : ARRAY [0..39]  OF CHAR;
    s          : ARRAY [0..255] OF CHAR;
    Copyright  : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetTime( EndTime );
    INC(EndTime.minute, (EndTime.day - StartTime.day) * 1440);  (* 20-Jun-91 RSC cross day boundaries?? *)
    ElapsedTime := ((FLOAT(   EndTime.minute ) * 60000.0) + FLOAT(   EndTime.millisec ))
                 - ((FLOAT( StartTime.minute ) * 60000.0) + FLOAT( StartTime.millisec ));
    FormatAsAmount( (ElapsedTime / 1000.0), DefaultAmountFormat, s1, 19,0,3,FALSE );
    SetString(s,"Event took: ");
    ConcatLS( s, s1 );
    TrimRear( s );
    ConcatS(  s, " seconds.");
    Error(s);
END DoIt;



BEGIN
        (* Install our keystroke handler into the keystroke handling chain.

            2-Mar-89 RSC.
        *)

    InstallNewProcedure(ADR(Keyboard.GetAnyCode),PROC(OurGetCode), ADR(OldGetCode));
    GetTime( StartTime );
    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), AnOverlayProc(NIL) );

END TLTimer.
