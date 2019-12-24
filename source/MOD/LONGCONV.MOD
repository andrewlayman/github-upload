IMPLEMENTATION MODULE LongConvert;

(* Procedures to convert between REAL and LONGINT.

        Modification History:

        Mar 16, 89 - JES - created from a procedure by RSC.
        Aug 17, 90 - AJL - Fixed the LongToString proc.


*)


FROM LStrings IMPORT 
    (* PROC *)        Fill, TrimFront, Copy;


CONST
    FMAXCARDINALpLUSoNE = 65536.0;
    Zero         =     0.0;

TYPE
    AKlugeRecord = RECORD
        CASE BOOLEAN OF
            TRUE  : Low, High : CARDINAL;
          | FALSE : LongValue : LONGINT;
        END;
        Negative  : BOOLEAN;
    END;



PROCEDURE LongToReal( LongInt : LONGINT ) : REAL;
VAR
    RealValue   : REAL;
    KlugeRecord : AKlugeRecord;

BEGIN

    WITH KlugeRecord DO
        Negative  := (LongInt < VAL(LONGINT,0));
        IF (Negative) THEN
            LongValue := -(LongInt);
        ELSE
            LongValue := LongInt;
        END;

        RealValue := FLOAT(Low);

        IF (High > 0) THEN
            RealValue := RealValue + (FLOAT(High) * FMAXCARDINALpLUSoNE);
        END;

        IF (Negative) THEN
            RETURN -(RealValue);
        ELSE
            RETURN RealValue;
        END;
    END;

END LongToReal;







PROCEDURE RealToLong( RealValue : REAL ) : LONGINT;
VAR
    KlugeRecord : AKlugeRecord;
BEGIN

    WITH KlugeRecord DO
        Negative := (RealValue < Zero);
        IF (Negative) THEN
            RealValue := -RealValue;
        END;
        High := TRUNC( RealValue / FMAXCARDINALpLUSoNE );
        Low  := TRUNC( RealValue - (FLOAT( High ) * FMAXCARDINALpLUSoNE) );
        IF (Negative) THEN
            RETURN -(LongValue);
        ELSE
            RETURN LongValue;
        END;
    END;

END RealToLong;


PROCEDURE LongToString(LongInt: LONGINT; VAR s1: ARRAY OF CHAR);

VAR
   i : CARDINAL;
   S : ARRAY [0..13] OF CHAR;
   Sign : BOOLEAN;
BEGIN
   i := HIGH(S);
   Fill(S," ",HIGH(S));

   IF (LongInt < 0L) THEN
       Sign := TRUE;
       LongInt := -LongInt;
   ELSE
       Sign := FALSE;
   END;

   REPEAT
       S[i] := CHR(VAL(CARDINAL, LongInt MOD 10L) + 60B);
       LongInt := LongInt DIV 10L;
       DEC(i);
   UNTIL LongInt = 0L;

   IF (Sign) THEN
      S[i] := "-";
   END; 

   TrimFront(S);
   Copy(S,s1);

END LongToString;


END LongConvert.
