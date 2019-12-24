IMPLEMENTATION MODULE ParseReal;

    (*  MODIFICATION HISTORY
        22-Dec-88 LAA   Added constants Zero and Ten.
        2-Jan-89  RSC   Added references to StringsEqual() rather than Compare().
        24-Jul-89 LAA   Fixed a bug which only showed up when 
                        ParseAmountToReal was given a string which hadn't
                        gone through Forms processing as a real number!  If
                        took the string "YESTERDAY" and said it was an ok
                        real number of value 0.0!!!!  That was because it got
                        stuck thing all those characters were Leading 
                        decorations.
        31-Aug-89 LAA   Added a new parameter to ParseAmountToReal so that the
                        amount format can be specified by the caller.
    *)


FROM Dialog         IMPORT
    (* PROCS *)         FatalError;

FROM LStrings       IMPORT
    (* PROCS *)         Copy, TrimRear, SetString, ConcatS, StringsEqual;

FROM RealFormat     IMPORT
    (* TYPE *)          AnAmountFormat,
    (* VARS *)          DefaultAmountFormat;



CONST
    Zero                    = 0.0;
    Ten                     = 10.0;


  (* Amount To Real - Convert an LString to REAL value.  Handles internationals.

      Preconditions  - Amount is the source LString to be converted.
                              Amount EITHER:
                              - Contains ONLY the real number, or
                              - Is followed by a blank before any other chars.

      Postconditions - Real is the real number (or zero).
                       ok   is TRUE iff the number parsed corectly.
  *)

PROCEDURE AmountToReal( VAR Amount : ARRAY OF CHAR;   (* Input  *)
                        VAR Real   : REAL;            (* Output *)
                        VAR ok     : BOOLEAN );       (* Output *)
VAR StoppedAfter : CARDINAL;
    LAmount      : ARRAY [0..99] OF CHAR;
BEGIN
    Copy( Amount, LAmount );
    TrimRear( LAmount );
    ParseAmountToReal( LAmount, DefaultAmountFormat, Real, ok, StoppedAfter );
    ok := (ok AND (StoppedAfter > ORD(LAmount[0])));
END AmountToReal;



  (* Parse Amount To Real - Convert an LString to REAL value.  Handles internationals.

      Preconditions  - Amount is the source LString to be converted.
                              Amount EITHER:
                              - Contains ONLY the real number, or
                              - Is followed by a blank before any other chars.
                       Format is the AmountFormat defining the rules by which
                              Amount will be parsed.

      Postconditions - Real is the real number (or zero).
                       ok   is TRUE iff the number parsed corectly.
                       Stopped is the last byte examined.  If <= Len(Amount),
                            then parsing stopped early.  if > len, then
                            the entire string was digested.
  *)

PROCEDURE ParseAmountToReal( VAR Amount : ARRAY OF CHAR;   (* Input  *)
                                 Format : AnAmountFormat;  (* Input  *)
                             VAR Real   : REAL;            (* Output *)
                             VAR ok     : BOOLEAN;         (* Output *)
                             VAR Stopped: CARDINAL);       (* Output *)

TYPE AState = (Start, Leading,  SaveLeading,  Before,
               After, Trailing, SaveTrailing, Stop);

CONST MaxRealSize = 25;
      AsciiZero   = 48; (* ORD("0") *)

VAR State      : AState;
    Limit,
    Loop       : CARDINAL;
    C          : CHAR;
    Plus,
    Minus      : ARRAY [0..1] OF CHAR;
    Decoration : ARRAY [0..MaxRealSize] OF CHAR;
    Digit,
    IsNegative,
    IsNegative2,
    RealSign   : BOOLEAN;
    Small      : CARDINAL;
BEGIN
    State      := Start;   (* We are just starting the string. *)
    Real       := Zero;    (* Nothing yet *)
    ok         := TRUE;    (* Assume we'll make it. *)
    Small      := 0;       (* Will scale down this many times *)
    SetString(Minus,"-");
    SetString(Plus,"+");

    Loop  := 1;
    Limit := ORD(Amount[0]);
    IF (Limit >  MaxRealSize) THEN
        Limit := MaxRealSize;
    END;
    WHILE (Loop <= (Limit+1))  AND  (State < Stop)  DO
        IF (Loop > Limit) THEN
            C := " ";             (* End of Real *)
        ELSE
            C := Amount[ Loop ];  (* Current charactor. *)
        END;
        Digit := (C >= "0")  AND  (C <= "9");
        CASE State OF
          Start    : IF (C = " ") THEN
                         INC( Loop );  (* Keep searching. *)
                     ELSE 
                         INC( State ); (* Go on to next state with this char. *)
                         Decoration[0] := 0C; (* leading digits holder *)
                     END;
        | Leading  : IF (Digit)  OR  (C = Format.RadixSymbol) THEN
                         INC( State ); (* Go into saving. *)
                     ELSE
                         IF (C <> " ") THEN
                             ConcatS( Decoration, C );
                         END;
                         INC( Loop );  (* Go on to next byte *)
                     END;
        | SaveLeading :
                     INC(State);  (* Always move on from here. *)
                     IF (ORD(Decoration[0]) = 0) THEN
                         IsNegative := FALSE; (* No sign?  Must be positive *)
                         RealSign   := FALSE;
                     ELSE    
                         (* Changed Compare() to StringsEqual() 1/2/88 RSC *)
                         IF (StringsEqual(Decoration,Minus))  OR
                            (StringsEqual(Decoration,Format.Decorations.LeadingNegativeSymbol)) THEN
                             IsNegative := TRUE;
                         ELSIF
                            (StringsEqual(Decoration,Plus))  OR
                            (StringsEqual(Decoration,Format.Decorations.LeadingPositiveSymbol)) THEN
                             IsNegative := FALSE;
                         ELSE
                            ok    := FALSE;
                            State := Stop;
                         END;
                         RealSign := ok;
                     END;
                     Decoration[0] := 0C; (* reset for trailing chars. *)
        | Before   : INC(Loop); (* Go on to next char, probably. *)
                     IF (Digit) THEN
                         Real := (Real * Ten) + FLOAT( ORD(C) - AsciiZero );
                     ELSIF
                        (C = Format.RadixSymbol) THEN
                         INC(State);
                     ELSIF
                        (C <> Format.SymbolForSignificance) THEN
                         State := Trailing; (* Strange char in our midst? *)
                         DEC(Loop); (* To get back to that strange char. *)
                     END;
        | After    : IF (Digit) THEN
                         INC(Loop);
                         INC(Small);
                         Real  := (Real  * Ten) + FLOAT( ORD(C) - AsciiZero );
                     ELSE
                         INC(State);
                     END;
        | Trailing : IF (C = " ") THEN
                         INC( State ); (* Go into saving. *)
                     ELSE
                         ConcatS( Decoration, C );
                         INC( Loop );  (* Go on to next byte *)
                     END;
        | SaveTrailing : 
                     INC(State);  (* Always move on from here. *)
                     IF (ORD(Decoration[0]) > 0) THEN
                         IF (StringsEqual(Decoration,Minus))  OR
                            (StringsEqual(Decoration,Format.Decorations.TrailingNegativeSymbol)) THEN
                             IsNegative2 := TRUE;
                         ELSIF
                            (StringsEqual(Decoration,Plus))  OR
                            (StringsEqual(Decoration,Format.Decorations.TrailingPositiveSymbol)) THEN
                             IsNegative2 := FALSE;
                         ELSE
                            ok := FALSE;
                         END;
                         IF (ok) THEN
                             IF ((IsNegative <> IsNegative2) AND RealSign) THEN
                                 ok := FALSE;  (* Conflicting signs *)
                             ELSE
                                 IsNegative := IsNegative2;
                             END;
                         END;
                     END;
        ELSE
            FatalError(); (* Stop state should never get here. *)
        END;
    END;
    Stopped := Loop;

    IF (ok) THEN
        IF (IsNegative) THEN
            Real := -Real;
        END;
        (* Scale the number down if there were digits after the decimal point.
           We do this rather than scaling down the entire amount in one big
           divide (say, 1234.0 / 1000.0 --> 1.234) because you quickly get into
           rounding trouble where 1.23450 becomes 1.23449999.  Likewise, you 
           can't multiply trailing digits by a smaller and smaller number,
           like (("1" - ORD("0")) * 0.000001).  I tried 'em all.  Stupid REALs.
        *)
        FOR Loop := 1 TO Small DO
            Real := (Real / Ten);
        END;

        ok := (State <> Leading);                                 (* 24-Jul-89 LAA *)
    END;

END ParseAmountToReal;





BEGIN
END ParseReal.
