IMPLEMENTATION MODULE Progress;

    (* Modification History :

        25-Jan-89 RSC Made Storage Space.
        01-May-89 EGK Changed the way UpdateThermometer calculates X
                      positions to avoid overflow errors.
        26-Feb-91 AJL Don't fail if the thermometer is created with a
                      MaxValue of 0.
        30-May-91 AJL Use a solid square for progress character.

    *)

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatS, CtoS, ConcatLS, RJust, Procustes,
                                Fill, Copy, LengthOf;

FROM Rugs                   IMPORT
    (* TYPE *)                  ARug,
    (* PROC *)                  GetRug, PutRug;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;


CONST
    DoneChar        = 333C;     (* "Û" *)
    ToGoChar        = 260C;     (* "°" *)

    ThermometerSize = 20;                   (* screen chars *)

TYPE
    AThermometer = POINTER TO AThermometerRecord;


    AThermometerRecord  =   RECORD
                                Rug         : ARug;
                                X           : ascreenx;
                                Y           : ascreeny;
                                MaxValue    : CARDINAL;
                                CurrValue   : CARDINAL;
                            END;





PROCEDURE CreateThermometer  ( VAR  Thermometer     : AThermometer;
                                    X               : ascreenx;
                                    Y               : ascreeny;
                               VAR  Text            : ARRAY OF CHAR;
                                    MaxValue        : CARDINAL )
                                                                : BOOLEAN;
VAR
    Rug             : ARug;
    s               : ARRAY [0..10] OF CHAR;
    Line            : ARRAY [0..maxcol] OF CHAR;

BEGIN
    Thermometer := NIL;
    IF (MaxValue = 0) THEN
        RETURN TRUE;
    ELSIF (Available(TSIZE(AThermometerRecord))) AND
         (GetRug (X,Y,maxcol,Y,Rug)) THEN

        NEW (Thermometer);

        Fill (Line, ToGoChar, ThermometerSize);
        ConcatS (Line, "     0/");
        CtoS (MaxValue, s);
        ConcatLS (Line, s);
        ConcatS (Line, " ");
        ConcatLS (Line, Text);
        PutString (Line, X, Y, videonormal);

        Thermometer^.Rug := Rug;
        Thermometer^.X := X;
        Thermometer^.Y := Y;
        Thermometer^.MaxValue := MaxValue;
        Thermometer^.CurrValue := 0;

        RETURN TRUE;
    END;

    RETURN FALSE;
END CreateThermometer;




PROCEDURE UpdateThermometer  (      Thermometer     : AThermometer;
                                    NewValue        : CARDINAL      );
VAR
    OldX                : CARDINAL;
    NewX                : CARDINAL;
    s                   : ARRAY [0..ThermometerSize] OF CHAR;
    R                   : REAL;

BEGIN
    IF (Thermometer = NIL) THEN
        RETURN;
    END;

    WITH Thermometer^ DO
        R := FLOAT(ThermometerSize) / FLOAT(MaxValue);
        OldX := TRUNC(FLOAT(CurrValue) * R);
        CurrValue := NewValue;
        NewX := TRUNC(FLOAT(CurrValue) * R);
        IF (NewX > OldX) AND (NewValue <= MaxValue) THEN
            CtoS (CurrValue, s);
            Procustes (s, 5);
            RJust (s);
            PutString (s, X + ThermometerSize + 1, Y, videonormal);

            Fill (s, DoneChar, NewX - OldX);
            PutString (s, X + OldX, Y, videonormal);
        END;
    END;
END UpdateThermometer;




PROCEDURE DiscardThermometer ( VAR  Thermometer     : AThermometer  );
BEGIN
    IF (Thermometer = NIL) THEN
        RETURN;
    END;

    WITH Thermometer^ DO
        PutRug (X,Y,maxcol,Y,Rug);
    END;
    DISPOSE (Thermometer);
END DiscardThermometer;




END Progress.
