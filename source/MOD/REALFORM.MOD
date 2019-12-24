IMPLEMENTATION MODULE RealFormat;

  (*  RealFormat - Format numbers as external representations.

    MODIFICATION HISTORY:

        12-Jun-87  RSC  First version.
        11-Jul-87  RSC  Optimization, Bug fixes, and add AmountToReal.
                        Optimization:
                             Tried to cut down execution time by tightening
                             code.  Created some static structures to avoid
                             computations and IFs.
                         Bugs:
                             Caught some suttle bugs that had not yet been
                             reported, such as 2 digit years after 1999.
        21-Jul-87  RSC  Fixed some FormatAsAmount problems with zero suppression
                        and with right justification.
        18-Jan-88  LAA  In an attempt to speed up the Gantt chart, changed the
                        way in which reals are converted to strings for small
                        numbers.
        31-Jan-88  RSC  Added a TrimRear() to AmountToReal.
        30-Sep-88  WKH  Don't allow MaxDigits to be > 25 in FormatAs.
         1-Nov-88  RSC  Make AMPM string big enough even for the Germans!
        30-Nov-88  AJL  Make the Size in the date format be a minimum for numbers, 
                        not both min and max, size.  This allows formats
                        such as 1/3/88 rather than 1/03/88.  When the format is
                        textual, we still use Procustes to set the size exactly.
                        We really should add a min and max size parameter to allow
                        full words. 
        16-Dec-88  RSC  Renamed from "FormatAs".  Time routines moved to TimeFormat.
         2-Jan-89  RSC  Removed references to Compare() (not used).
        26-Jun-89  KKC  Move RealToLStrings to Num2Str.asm
        27-Jun-89  LAA  Put RealToLStrings back into the DEF of this module.
                        Calls to it are just vectored to the Num2Str procedure.
 *)


FROM LStrings           IMPORT
        (* PROCS *)        SetString, SetLengthOf, Copy, RJust, 
                           Procustes, CtoS, TrimFront, TrimRear,
                           Insert, Remove, SubStr, Search, ConcatS,
                           LengthOf, Fill, TStringToLString, ConcatLS;
         
FROM Dialog             IMPORT
        (* PROCS *)        FatalError;

IMPORT                  Num2Str;







CONST
    Zero =  0.0;
    One  =  1.0;
    Ten  = 10.0;



VAR
    ZeroTable     : ARRAY [0..8] OF REAL; (* Is this number zero? *)









  (* AmountFormatLength - How big will the amount be?

      This procedure answers the musical question,
      "How big will the biggest number be?"

      Preconditions  - Format is the amount format record
                       LeadingDigits is the maximum leading digits you
                           expect.  This could become "FieldSize" on 
                           "FormatAs..." calls.
                       TrailingDigits is the largest number of trailing
                           digits you expect.  This is like "MaxDigits".

      Postconditions - Alignment is where the decimal point will show up.
                           If there will be no decimal point, because
                           TrailingDigits = 0, Alignment will equal
                           LeadingDigits.
                       RETURN is the maximum space taken up by the amount.
 *)

PROCEDURE AmountFormatLength(
        VAR Format         : AnAmountFormat;  (* format to use. *)
            LeadingDigits  : CARDINAL;        (* To right of decimal point *)
            TrailingDigits : CARDINAL;        (* To right of decimal point *)
        VAR Alignment      : CARDINAL         (* Where decimal point will be *)
            ) : CARDINAL;                     (* Returned length *)

VAR p1, p2, n1, n2 : CARDINAL;
    Commas         : CARDINAL;    
    Length         : CARDINAL;
BEGIN
    p1 := LengthOf( Format.Decorations.LeadingPositiveSymbol );
    n1 := LengthOf( Format.Decorations.LeadingNegativeSymbol );

    n2 := LengthOf( Format.Decorations.TrailingNegativeSymbol );
    p2 := LengthOf( Format.Decorations.TrailingPositiveSymbol );

    IF ((n1 + n2) < (p1+p2) ) THEN  (* Largest of the two decorations? *)
        n1 := p1;
        n2 := p2;   (* n1, n2 are now the bigest decoration size *)
    END;
      
    Commas := (LeadingDigits DIV Format.DigitsForSignificance);
    IF (Commas > 0) AND ((LeadingDigits MOD Format.DigitsForSignificance) = 0) THEN
        DEC(Commas);
    END;

    Length := n1 + LeadingDigits + Commas;

    Alignment := Length + 1;      (* Where the decimal point will go *)
    IF (TrailingDigits > 0) THEN
        INC(Length);              (* There will be a decimal point *)
    END;

    RETURN (Length + TrailingDigits + n2);
END AmountFormatLength;





  (* CurrencyFormatLength - How big will the currency be?

      This procedure answers the musical question,
      "How big will the biggest number be?"

      Preconditions  - Format is the currency format record
                       LeadingDigits is the maximum leading digits you
                           expect.  This could become "FieldSize" on 
                           "FormatAs..." calls.
                       ShowDigits is TRUE if you will want customary digits.
                       IncludeSymbol is TRUE if you will want the "$".

      Postconditions - Alignment is where the decimal point will show up.
                           If there will be no decimal point, because
                           TrailingDigits = 0, Alignment will equal
                           LeadingDigits.
                       RETURN is the maximum space taken up by the amount.
 *)

PROCEDURE CurrencyFormatLength(
        VAR Format         : ACurrencyFormat; (* Currency format record *)
            LeadingDigits  : CARDINAL;        (* To right of decimal point *)
            ShowDigits     : BOOLEAN;         (* Will you show customary digits? *)
            IncludeSymbol  : BOOLEAN;         (* Will you include currency symbol? *)
        VAR Alignment      : CARDINAL         (* Where decimal point will be *)
            ) : CARDINAL;                (* Returned length *)
VAR Max : CARDINAL;
BEGIN
    IF (ShowDigits) THEN
        Max := Format.MaxTrailingDigits;
    ELSE
        Max := 0;
    END;
    IF (IncludeSymbol) THEN
        Format.AmountFormat.Decorations := Format.DecorationsWithCurrency;
    ELSE
        Format.AmountFormat.Decorations := Format.Decorations;
    END;
    RETURN AmountFormatLength( Format.AmountFormat, LeadingDigits, Max, Alignment );
END CurrencyFormatLength;











  (* FormatAsAmount - Format a real number as an amoun string, including
           any appropriate decorations, like "." and ",".

    Preconditions  - A good real number in Amount.
                     A filled in AmountFormat record in Format.
                     An LString at least 1 byte big in Result.
                     The desired resultant field size in FieldSize.
                        THIS MUST BE > HIGH(Result) AND > MaxDigits!
                     The Minimum number of fractional digits desired.
                     The Maximum digits you will allow.  These only show up 
                         if they would be non-zero.
                     'AlignRadix' is the position within Result to align the
                         radix point to.  If zero, no alignment is done.

    Postconditions - Result is FieldSize size, filled in with the number or
                     the OverflowSymbol, possibly right justified.

    DANGER!! -
        Result had better be big enough for FieldSize chars!
        AlignRadix + MaxDigits better be >= FieldSize!
 *)

PROCEDURE FormatAsAmount(
            Amount    : REAL;            (* Amount to be converted *)
        VAR Format    : AnAmountFormat;  (* Amount format record *)
        VAR Result    : ARRAY OF CHAR;   (* Returned LString *)
            FieldSize : CARDINAL;        (* desired field size *)
            MinDigits : CARDINAL;        (* To right of decimal point *)
            MaxDigits : CARDINAL;        (* To right of decimal point *)
            RightJust : BOOLEAN   );     (* Right justify? *)

VAR s                 : ARRAY [0..25]  OF CHAR;
    Leading, Trailing : ARRAY [0..25] OF CHAR;
    IsNegative        : BOOLEAN;
    DotNeeded         : BOOLEAN;
    i, j, k           : CARDINAL;
    TrailingSize      : CARDINAL;


    (* Be conservative on our biggest number, but not TOO conservative.
       Allow for the normal case of one comma per 3 digits (Japan has
       one every 4 digits), the resulting LEADING digits must fit.
    *)
CONST BiggestNumber = 1.0E+16;

BEGIN
    IF (MaxDigits > 25) THEN        (* 9/30/88 WKH *)
        FatalError();
    END;
    IsNegative := (Amount < 0.0); (* Don't let "RealToLStrings" handle negatives. *)
    IF (IsNegative) THEN
        Amount := -Amount;
    END;
    IF ( Amount > BiggestNumber )  THEN
        Fill(Result,Format.OverflowSymbol,FieldSize);
        RETURN;
    END;

    i := MaxDigits;
    IF (i > HIGH(ZeroTable)) THEN
        i := HIGH(ZeroTable);
    END;
    IF (Amount < ZeroTable[i]) THEN (* Handle very small zeroes. *)
        Amount     := Zero;
        IsNegative := FALSE;
        IF (Format.IncludeAtLeastOneDigit) THEN (* set up something like 0.00 *)
            Fill(Leading,"0",1);
            Fill(Trailing,"0",MinDigits);
        ELSE                                 (* Otherwise return all spaces *)
            Fill(Result," ", FieldSize);
            RETURN;
        END;
    ELSE
        RealToLStrings( Amount, MinDigits, MaxDigits, Leading, Trailing );

        (* Now we may need to have at least one leading zero.  Do we? *)

        IF (Format.IncludeAtLeastOneDigit)     AND
           (Leading[0] = 0C)                   THEN
            Fill(Leading,"0",1);
        ELSE
            (* Add commas to the Leading string. *)

            SetString(s, Format.SymbolForSignificance );
            k := Format.DigitsForSignificance;
            i := ORD(Leading[0])+1;
            WHILE i >= (k + 2) DO
                DEC(i,k);
                Insert(Leading,s,i);
            END;
        END;
    END;

    (* Do we need a radix point? *)

    DotNeeded := (Trailing[0] > 0C);

    IF (DotNeeded)  OR  (Leading[0] > 0C)  THEN
        WITH Format.Decorations DO
            IF (IsNegative) THEN
                Insert  (Leading,  LeadingNegativeSymbol, 1);
                ConcatLS(Trailing, TrailingNegativeSymbol);
            ELSE
                Insert  (Leading,  LeadingPositiveSymbol, 1);
                ConcatLS(Trailing, TrailingPositiveSymbol);
            END;
        END;
    END;

    (* Will the number fit? *)

    IF (RightJust) THEN
        WITH Format.Decorations DO
            TrailingSize := ORD(TrailingNegativeSymbol[0]);
            IF (ORD(TrailingPositiveSymbol[0]) > TrailingSize) THEN
                TrailingSize := ORD(TrailingPositiveSymbol[0]);
            END;
        END;
        INC(TrailingSize,MaxDigits); (* Full trailing size. *)
    ELSE
        TrailingSize := ORD(Trailing[0]);
    END;
    IF (MaxDigits > 0) THEN
        INC(TrailingSize);  (* Trailing including decimal point *)
    END;

    i := ( ORD(Leading[0]) + TrailingSize );  (* Total size needed. *)
    IF ( i > FieldSize )  THEN
        Fill(Result,Format.OverflowSymbol,FieldSize);
        RETURN;
    END;

    Result[0] := 0C;
    j := (FieldSize - i); (* EXTRA space in field. *)
    IF (RightJust  AND  (j > 0)) THEN (* If leading spaces needed, add em. *)
        Fill(Result," ",j);
    END;
    ConcatLS(Result, Leading);

    IF (DotNeeded) THEN                     (* is there a decimal point? *)
        ConcatS( Result, Format.RadixSymbol);    (* Then add it. *)
    END;

    ConcatLS( Result, Trailing );          (* Add trailing chars *)
    
    Procustes( Result, FieldSize ); (* Make it fill the space alloted for it. *)
  
END FormatAsAmount;









  (* FormatAsCurrency - Format a real number as a currency string, including
           any appropriate decorations, like "$" and "DB".

    Preconditions  - A good real number in Amount.
                     A filled in CurrencyFormat record in Format.
                     An LString at least 1 byte big in Result.
                     The desired resultant field size in FieldSize.
                     'AlignRadix' is the position within Result to align the
                         radix point to.  If zero, no alignment is done.
                     Wether you want the fraction, like $1.23, or just $1
                     Wether to include the currency symbol, like "$".


    Postconditions - Result is FieldSize size, filled in with the number or
                     the OverflowSymbol, possibly right justified.

    DANGER!  Format.AmountFormat.Decorations is used as a temporary work
             area, taking on the identity of either Format.Decorations, or
             Format.DecorationsWithCurrency, as needed.
 *)

PROCEDURE FormatAsCurrency(
            Amount        : REAL;            (* Amount to be converted *)
        VAR Format        : ACurrencyFormat; (* currency format record *)
        VAR Result        : ARRAY OF CHAR;   (* Returned LString *)
            FieldSize     : CARDINAL;        (* Of LString *)
            RightJust     : BOOLEAN;         (* Right justify? *)
            ShowDigits    : BOOLEAN;         (* Show customary fraction? *)
            IncludeSymbol : BOOLEAN    );    (* Include the currency symbol? *)
VAR Min,         
    Max         : CARDINAL;
BEGIN
    WITH Format DO
        IF (ShowDigits) THEN
            Min := MinTrailingDigits;
            Max := MaxTrailingDigits;
        ELSE
            Min := 0;
            Max := 0;
        END;
        IF (IncludeSymbol) THEN
            AmountFormat.Decorations := DecorationsWithCurrency;
        ELSE
            AmountFormat.Decorations := Decorations;
        END;

        FormatAsAmount( Amount, AmountFormat, Result,
                        FieldSize, Min, Max, RightJust );
    END;
END FormatAsCurrency;







  (* RealToLStrings - Convert a real number to Lstrings.  This includes no
                      string decorations.  It is loosely based on the 
                      Logitek RealConversions module.  This procedure does
                      NOT:
                  1) Handle exponential notation.
                  2) Validate the reality of the number.
                  3) Put leading spaces or decimal points in the number.
                  4) Output leading zeroes or trailing zeroes beyond
                     'MinDigits'

     Preconditions  - Amount is a POSITIVE REAL number.
                      MinDigits is the Minimum number of decimal places.
                         If need be, the number will be padded with zeroes
                         up to this point.
                      Max digits is the maximum number of decimal places.
                         The Amount will be ROUNDED UP to this level of accuracy.

     Postconditions - Leading contains the digits before the decimal point.
                      Trailing contains the digits after the decimal point.
                      There are NO Leading or extra Trailing zeroes.
     DANGER!
         It is assumed that MaxDigits <= HIGH(Trailing), and that the
         leading digits can fit into Leading.  A TooLong() error will
         result if this is not true.
         I also assume that MinDigits <= MaxDigits.
 *)


PROCEDURE RealToLStrings( Amount          : REAL;
                          MinDigits       : CARDINAL;
                          MaxDigits       : CARDINAL;
                      VAR Leading,
                          Trailing        : ARRAY OF CHAR );
BEGIN

    Num2Str.RealToLStrings(Amount, MinDigits, MaxDigits, Leading, Trailing);

END RealToLStrings;






PROCEDURE InitRealFormat();
VAR
    i           : CARDINAL;
    R           : REAL;
    Name        : ARRAY [0..9] OF CHAR;
BEGIN

    R := One;
    FOR i := 0 TO HIGH(ZeroTable) DO
        ZeroTable[i] := R; (* 1, .1, .01, ... *)
        R := R / Ten;
    END;

        (* These will do until we read real ones from the config file.
           To my knowlege, only debugging overlays use this format
           before we get going.  RSC  22-Jan-91.
        *)
    WITH DefaultAmountFormat DO
        RadixSymbol            := ".";
        SymbolForSignificance  := ",";
        DigitsForSignificance  := 3;
        IncludeAtLeastOneDigit := TRUE;
        OverflowSymbol         := "*";
        SetString(Decorations.LeadingNegativeSymbol,"-");
        SetLengthOf(Decorations.TrailingNegativeSymbol,0);

        SetLengthOf(Decorations.LeadingPositiveSymbol, 0);
        SetLengthOf(Decorations.TrailingPositiveSymbol, 0);
    END;

    WITH DefaultCurrencyFormat DO
        AmountFormat            := DefaultAmountFormat;
        MinTrailingDigits       := 2;
        MaxTrailingDigits       := 2;
        Decorations             := DefaultAmountFormat.Decorations;
        DecorationsWithCurrency := DefaultAmountFormat.Decorations;
        SetLengthOf(DecorationsWithCurrency.LeadingPositiveSymbol,0);
        SetString(DecorationsWithCurrency.LeadingNegativeSymbol,"-");
    END;

END InitRealFormat;





BEGIN
    InitRealFormat();
END RealFormat.
