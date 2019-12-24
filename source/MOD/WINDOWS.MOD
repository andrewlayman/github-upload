IMPLEMENTATION MODULE Windows;

(*  =========================================================================
    Last Edit : March 19, 1991 6:43PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Detects presence of Windows.



    MODIFICATION HISTORY:

    19-Mar-91 RSC First version, from MSJ Vol 6 # 2, March 1991.

    =========================================================================
*)


FROM SYSTEM IMPORT
    (* CONST *) AX, CX, DX,
    (* PROC *)  SETREG, GETREG, SWI;




PROCEDURE WindowsIsRunning() : AWindowsType;
VAR
    Al, Cl, Cx, Dx,
    Ax          : CARDINAL;
    WindowsType : AWindowsType;


    PROCEDURE XOR( VAR A : CARDINAL; B : CARDINAL );
    BEGIN
        A := CARDINAL(BITSET(A) / BITSET(B)) MOD 256;
    END XOR;


    PROCEDURE INT2F();
    BEGIN
        SETREG( AX, Ax );
        SETREG( DX, Dx );
        SETREG( CX, Cl );
        SWI( 2FH );
        GETREG( AX, Ax );
        GETREG( CX, Cx );
        Al := Ax MOD 256;
        Cl := Cx MOD 256;
    END INT2F;

    PROCEDURE And( VAR Dest : CARDINAL; With : CARDINAL );
    BEGIN
        Dest := CARDINAL( BITSET(Dest) * BITSET(With) ) MOD 256;
    END And;

    PROCEDURE Or( VAR Dest : CARDINAL; With : CARDINAL );
    BEGIN
        Dest := CARDINAL( BITSET(Dest) + BITSET(With) ) MOD 256;
    END Or;

BEGIN
        (* See page 113 of MSJ Vol 6 # 2 (March 1991) for this algorithem
        *)

    Ax := 4680H;

    INT2F;

    XOR(Al, 80H);
    Cl := Al;
    Ax := 1600H;

    INT2F;

    And(Al, 7FH);
    Or( Al, Cl );

    IF (Al = 80H) THEN  (* We are in either real or standard mode *)

        Ax := 1605H;
        Dx := 1;

        INT2F;

        IF (Cx = 0) THEN
            Ax := 1606H;
            INT2F;
        END;

        Al := 80H;

        Or(Al, Cl);

    END;

    CASE Al OF

         0  : WindowsType := WindowsNotRunning;
     |   1,
        7FH : WindowsType := Windows2;
     |  80H : WindowsType := Windows3Real;
     | 0FFH : WindowsType := Windows3Standard;
     |    3 : WindowsType := Windows3Enhanced;
    ELSE
        WindowsType := Windows4Enhanced;
    END;

    RETURN WindowsType;

END WindowsIsRunning;



END Windows.


