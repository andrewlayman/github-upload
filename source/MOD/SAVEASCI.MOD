IMPLEMENTATION MODULE SaveAscii;

  (* MODIFICATION HISTORY

        RSC  9/21/87 - remove RealToString in favor of FormatAsAmount.
        AJL  1/9/89  - Always store real numbers using the formatting that
                       would have obtained had we used the RealToString
                       procedure: basic USA formatting.
        AJL  3/2/89  - Import from RealFormat instead of FormatAs.
        30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
        23-Jan-91 RSC  Removed RealFormat, replaced with Num2Str, which
                       has less overhead.
  *)

FROM FileSystem    IMPORT File;

FROM Timei         IMPORT
    (* TYPE *)          ADurationUnit;

FROM LStrings      IMPORT CtoS, TStringToLString, LJust, TrimRear,
                          SetString, Search, Procustes, LengthOf,
                          ConcatS, ConcatLS, SetLengthOf;

FROM Num2Str       IMPORT
    (* PROC *)          RealToLStrings;

FROM RecordIO      IMPORT WriteRecord, WriteString;

FROM SYSTEM        IMPORT ADR, SIZE;


PROCEDURE SaveBoolean( VAR F    : File;
                           Type : CARDINAL;
                           B    : BOOLEAN );
VAR
    C : CHAR;
BEGIN
    IF (B) THEN C := "Y";
    ELSE        C := "N";
    END;

    WriteRecord(F,Type,ADR(C),SIZE(C));
END SaveBoolean;







PROCEDURE SaveCardinal( VAR F : File;
                            Type : CARDINAL;
                            N : CARDINAL );
VAR
    S  : ARRAY [0..6] OF CHAR;
BEGIN
    CtoS(N,S);
    WriteString(F,Type,S);
END SaveCardinal;







PROCEDURE SaveReal    ( VAR F        : File;
                            Type     : CARDINAL;
                            R        : REAL;
                            Decimals : CARDINAL;
                            Width    : INTEGER );
VAR
    Leading, Trailing : ARRAY [0..31] OF CHAR;
BEGIN
    RealToLStrings( R, 0, Decimals, Leading, Trailing );
    IF (Width < INTEGER(LengthOf(Leading))) THEN
        ConcatS( Leading, "." );
        ConcatLS( Leading, Trailing );
        IF (INTEGER(LengthOf(Leading)) > Width) THEN
            Procustes(Leading,CARDINAL(Width));
        END;
    END;

    WriteString(F,Type,Leading);
END SaveReal;




PROCEDURE SaveTimeUnit( VAR F : File;
                            Type : CARDINAL;
                            T : ADurationUnit  );
VAR
    C : CHAR;
BEGIN
    CASE T OF
        Minutes :  C := "m";
      | Hours   :  C := "H";
      | Days    :  C := "D";
      | Weeks   :  C := "W";
      | Months  :  C := "M";
      | Years   :  C := "Y";
    END;

    WriteRecord(F,Type,ADR(C),SIZE(C));
END SaveTimeUnit;




END SaveAscii.
