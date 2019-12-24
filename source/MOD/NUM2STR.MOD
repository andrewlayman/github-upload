IMPLEMENTATION MODULE Num2Str;

(* 22-Jan-91 RSC Removed ZeroTable as it was not used.
*)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM LStrings               IMPORT
    (* PROC *)                  CtoS;



CONST
    Zero =  0.0;
    One  =  1.0;
    Ten  = 10.0;



VAR
    DigitTable    : ARRAY [0..9] OF CHAR;
    RoundTable    : ARRAY [0..8] OF REAL; (* Rounding up numbers *)





PROCEDURE InitRealFormat();
VAR
    i : CARDINAL;
    R : REAL;
BEGIN

    R := 5.0;
    FOR i := 0 TO HIGH(RoundTable) DO
        R := R / Ten;
        RoundTable[i] := R; (* .5, .05, .005, ... *)
    END;

    DigitTable := "0123456789";

END InitRealFormat;




PROCEDURE RealToLStrings( Amount          : REAL;
                          MinDigits       : CARDINAL;
                          MaxDigits       : CARDINAL;
                      VAR Leading,
                          Trailing        : ARRAY OF CHAR );

VAR
    Loop          : CARDINAL;
    LeadingDigits : CARDINAL;
    A             : CARDINAL;
    TrailLen      : CARDINAL;

BEGIN
    (* Step one - round the number.  Do this by adding a small amount to it. *)     
   
    A := MaxDigits;
    IF (MaxDigits > HIGH(RoundTable)) THEN
        A := HIGH(RoundTable);     (* Always round some. *)
    END;
    Amount := Amount + RoundTable[ A ]; (* Pizza? in an 8086? *)

    IF (Amount <= 65535.0) THEN                                   (* 18-Jan-88 LAA *)
        A := TRUNC(Amount);
        Amount := Amount - FLOAT(A);
        CtoS(A, Leading);
    ELSE
        (* Step 2 - make the number all to the right of the decimal point. *)

        LeadingDigits := 0;
        WHILE (Amount >= One) DO
            Amount := Amount / Ten;
            INC(LeadingDigits);
        END;
        IF (LeadingDigits > HIGH(Leading)) THEN
            FatalError(); (* Code bug - number way too big. *)
        END;

        (* Step 3 - output leading digits.  For each one, convert to a digit. *)

        Leading[0] := CHR(LeadingDigits);
        FOR Loop := 1 TO LeadingDigits DO
            Amount := Amount * Ten;
            A      := TRUNC( Amount );
            Amount := Amount - FLOAT( A );
            Leading[Loop] := DigitTable[ A ];
        END;
    END;

    (* Step 4 - Output trailing digits.  No trailing 0s beyond "MinDigits". *)

    TrailLen := 0; (* Initial trailing length *)
    FOR Loop := 1 TO MaxDigits DO
        Amount := Amount * Ten;
        A      := TRUNC( Amount );
        Amount := Amount - FLOAT( A );
        Trailing[Loop] := DigitTable[ A ];
        IF (A > 0)  OR  (Loop <= MinDigits)  THEN
            TrailLen := Loop;      (* if non zero or within minimum *)
        END;
    END;
    Trailing[0] := CHR(TrailLen);

END RealToLStrings;



BEGIN                       (* Num2Str *)

    InitRealFormat();

END Num2Str.
