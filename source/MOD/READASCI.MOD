IMPLEMENTATION MODULE ReadAscii;

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    11/10/86 LAA    Changed ReadDate to handle the format HYYYYMMDDHHMM, as
                    used by version 3.
    1/9/89   AJL    Since the DefaultAmountFormat is an implied parameter to the
                    AmountToReal procedure, we store it, change it, then put it
                    back.  God help us if anyone every tries to be reentrant!
    3/2/89   AJL  - Import from RealFormat and ParseReal instead of FormatAs.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo. 
----------------------------------------------------------------------------*)

FROM Dialog        IMPORT Error;

FROM FileSystem    IMPORT File;

FROM Timei         IMPORT
    (* TYPE *)          ADurationUnit, ADate, ATimeInfo,
    (* PROC *)          TtoTimeU;

FROM BigTimeU      IMPORT ABigTime, BigTimeToTime;

FROM LStrings      IMPORT StoC, LJust, TrimRear,
                          SetString, SubStr, SetLengthOf;

FROM RealFormat    IMPORT
    (* TYPE *)         AnAmountFormat,
    (* VAR *)          DefaultAmountFormat;

FROM ParseReal     IMPORT
    (* PROC *)         AmountToReal;

FROM RecordIO      IMPORT ReadRecordBody, ReadStringBody;

FROM SYSTEM        IMPORT ADR, SIZE;


PROCEDURE ReadBoolean( VAR F    : File;
                           Length : CARDINAL;
                       VAR B    : BOOLEAN );
VAR
    C : CHAR;
BEGIN
    ReadRecordBody(F,Length,ADR(C),SIZE(C));

    B := ( CAP(C) = "Y" );

END ReadBoolean;







PROCEDURE ReadCardinal( VAR F : File;
                            Length : CARDINAL;
                        VAR N : CARDINAL );
VAR
    i  : CARDINAL;
    S  : ARRAY [0..10] OF CHAR;
BEGIN
    ReadStringBody(F,Length,S);
    i := 1;
    N := StoC(S,i);
END ReadCardinal;







PROCEDURE ReadReal    ( VAR F : File;
                            Length : CARDINAL;
                        VAR R : REAL );
VAR
    OldAmountFormat : AnAmountFormat;
    i  : CARDINAL;
    S  : ARRAY [0..31] OF CHAR;
    ok : BOOLEAN;
BEGIN
    ReadStringBody(F,Length,S);

        (* Since the DefaultAmountFormat is an implied parameter to the
           AmountToReal procedure, we store it, change it, then put it
           back.  God help us if anyone every tries to be reentrant!
           AJL 1-9-89.
        *)

    OldAmountFormat := DefaultAmountFormat;

    WITH DefaultAmountFormat DO
        RadixSymbol            := ".";
        SymbolForSignificance  := ",";
        DigitsForSignificance  := 9999;
        IncludeAtLeastOneDigit := TRUE;
        OverflowSymbol         := "*";
        SetString(Decorations.LeadingNegativeSymbol,"-");
        SetLengthOf(Decorations.TrailingNegativeSymbol,0);
        SetLengthOf(Decorations.LeadingPositiveSymbol, 0);
        SetLengthOf(Decorations.TrailingPositiveSymbol,0);
    END;

    AmountToReal(S,R,ok);

    DefaultAmountFormat := OldAmountFormat;

    IF (NOT ok) THEN
        Error(S);
    END;
END ReadReal;




PROCEDURE ReadDate(    VAR F : File;
                           Length : CARDINAL;
                       VAR D : ADate );
VAR
    TimeInfo     : ATimeInfo;
    BigTime      : ABigTime;
    ok           : BOOLEAN;
BEGIN

    ReadRecordBody(F,Length,ADR(BigTime), SIZE(BigTime));
    BigTimeToTime
    (
        BigTime,
        TimeInfo.tiYear,
        TimeInfo.tiMonth,
        TimeInfo.tiDay,
        TimeInfo.tiHour,
        TimeInfo.tiMinute,
        TimeInfo.tiSecond
    );
    ok := TtoTimeU( TimeInfo, D );

END ReadDate;





PROCEDURE ReadTimeUnit( VAR F : File;
                            Length : CARDINAL;
                        VAR T : ADurationUnit  );
VAR
    C : CHAR;
BEGIN
    ReadRecordBody(F,Length,ADR(C),SIZE(C));
    CASE C OF
        "m"     :  T := Minutes;
      | "H"     :  T := Hours;
      | "D"     :  T := Days;
      | "W"     :  T := Weeks;
      | "M"     :  T := Months;
      | "Y"     :  T := Years;
      ELSE
          T := Days;
    END;
END ReadTimeUnit;




END ReadAscii.
