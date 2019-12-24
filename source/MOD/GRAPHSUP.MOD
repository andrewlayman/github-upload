IMPLEMENTATION MODULE GraphSupport;
(*
    Modification History:

        WKH 22-May-89   Use AmountToReal instead of StringToReal.  Also
                        stripped out code that is no longer used.
        KKC 21-Feb-90   Remove import of Timeu.
*)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, Error;

FROM LStrings               IMPORT
    (* PROC *)                  StoC, LengthOf, ConcatLS;

FROM Menus                  IMPORT
                                WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR  *)                  AnxietyLevel;

FROM ParseReal              IMPORT
    (* PROC *)                  AmountToReal;

CONST
    ModuleNumber            = 25500;
    ModuleNameMsg           = 00;
    BorderNotFoundMsg       = 01;
    ConversionFacStoRMsg    = 06;
    ConversionFacNotFoundMsg= 07;
    BorderMsg               = 21;
    ConversionFactorMsg     = 24;

VAR
    Initialized             : BOOLEAN;
    DefaultBorder           : CARDINAL;
    ConversionFactor        : REAL;


PROCEDURE InitGraphSupport();

VAR
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..255] OF CHAR;
    i                       : CARDINAL;
    Success                 : BOOLEAN;
    ChillOut                : BOOLEAN;

BEGIN
    ChillOut := TRUE;

    IF (NOT Initialized) THEN
        GetMessage(ModuleNumber + BorderMsg, s);
        WordNumber(s, 1, s1);
        IF (LengthOf(s1) > 0) THEN
            i := 1;
            DefaultBorder := StoC(s1, i);
        ELSE
            IF (AnxietyLevel > Calm) THEN
                GetMessage(ModuleNumber + ModuleNameMsg, s);
                GetMessage(ModuleNumber + BorderNotFoundMsg, s1);
                ConcatLS(s, s1);
                Error(s);
                ChillOut := FALSE;
            END;
        END;

        GetMessage(ModuleNumber + ConversionFactorMsg, s);
        WordNumber(s, 1, s1);
        IF (LengthOf(s1) > 0) THEN
            AmountToReal(s1, ConversionFactor, Success);
            IF (NOT Success) THEN
                IF (AnxietyLevel > Calm) THEN
                    GetMessage(ModuleNumber + ModuleNameMsg, s);
                    GetMessage(ModuleNumber + ConversionFacStoRMsg, s1);
                    ConcatLS(s, s1);
                    Error(s);
                    Error(s);
                    ChillOut := FALSE;
                END;
            END;
        ELSE
            IF (AnxietyLevel > Calm) THEN
                GetMessage(ModuleNumber + ModuleNameMsg, s);
                GetMessage(ModuleNumber + ConversionFacNotFoundMsg, s1);
                ConcatLS(s, s1);
                Error(s);
                ChillOut := FALSE;
            END;
        END;

        Initialized := ChillOut;
    END;
END InitGraphSupport;

PROCEDURE GetDefaultBorder() : CARDINAL;

BEGIN
    InitGraphSupport();
    RETURN(DefaultBorder);
END GetDefaultBorder;

PROCEDURE GetConversionFactor() : REAL;
BEGIN
    InitGraphSupport();
    RETURN(ConversionFactor);
END GetConversionFactor;

BEGIN
    Initialized      := FALSE;
    DefaultBorder    := 50;
    ConversionFactor := 1.0;
END GraphSupport.

