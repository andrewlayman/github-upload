MODULE TLFMTINT;

  (* Modification History:

         2-Jan-89  RSC  Removed references to Compare() (not used).
        10-Aug-89  KKC  Add copyright message.
         9-Oct-89  MWP  Removed text literals.
        02-Apr-90  MWP  Weeknumber support added.
         9-Apr-90  RSC  Timei/TimeFormat changes.
        15-May-91  AJL  Check that setting the format does not create
                        a date format that is too long.
        26-Jun-91  AJL  Display our own error message if the date format
                        is too long.
        31-Jul-91  AJL  Don't change the date format if Esc is used to 
                        cancel out of the multiple choice box.
        27-Sep-91 TGS   If fiscal years are being used, don't allow week
                        numbers formats.
        31-Jan-92 TGS   Don't read in Amount/Currency stuff here anymore.
                        Do it in TLNumFrm instead.
  *)

FROM Dialog     IMPORT
                    ADialogOption, WarningBox,
                    MultipleChoiceBox, Error, FatalError, ErrorPhrase;

FROM LStrings   IMPORT SetString, SubStr, Procustes, CtoS, StoC,
                       ConcatS, ConcatLS, Insert, Remove, Fill,
                       LJust, RJust, Overlay, LStringToTString,
                       Upshift, Copy, SetLengthOf, LengthOf, StringsEqual;

FROM Menus      IMPORT WordNumber;

FROM MsgFile    IMPORT GetMessage, ConcatMessage;

FROM RealFormat IMPORT
    (* Var *)        DefaultAmountFormat,
                     DefaultCurrencyFormat;

FROM Schedule   IMPORT ConfigSaved, InstalledFlag;

FROM TimeFormat IMPORT
    (* TYPE *)       ATimeFormat,
    (* Var *)        DefaultDateAndTimeFormat,
                     DefaultDateFormat,
                     DefaultTimeFormat,
    (* PROC *)       InitializeTimeFormat, CheckDateFormatLength;

FROM Timei          IMPORT
    (* CONST *)         Jan,
    (* TYPE *)          ADurationUnit;

FROM Timeu          IMPORT 
    (* PROC *)          GetStartingMonth, SetStartingMonth;

FROM WeekNumberInfo IMPORT
    (* VAR *)        UsingWeekNumbers;


CONST
    ModuleNumber = 26900;








PROCEDURE ExtractCardinal( VAR S : ARRAY OF CHAR;
                               N : CARDINAL ) : CARDINAL;
VAR
    i,j  : CARDINAL;
    S2 : ARRAY [0..31] OF CHAR;
    S3 : ARRAY [0..99] OF CHAR;
BEGIN
    WordNumber(S,N,S2);
    i := 1;
    j := StoC(S2,i);
    IF (i = 1) THEN
        SetString(S3,'"');
        ConcatLS(S3,S2);
        ConcatMessage ( S3, ModuleNumber + 6 );                   (* 9-Oct-89 MWP *)
        (* " should be a number. *)
        Error(S3);
    END;
    RETURN j;
END ExtractCardinal;


PROCEDURE ExtractCharacter( VAR S : ARRAY OF CHAR;
                               N : CARDINAL ) : CHAR;
VAR
    S2 : ARRAY [0..31] OF CHAR;
    S3 : ARRAY [0..99] OF CHAR;
BEGIN
    WordNumber(S,N,S2);
    IF (LengthOf(S2) <> 1) THEN
        SetString(S3,'"');
        ConcatLS(S3,S2);
        ConcatMessage ( S3, ModuleNumber + 7 );                   (* 9-Oct-89 MWP *)
        (* " should be one character long. *)
        Error(S3);
    END;
    RETURN S2[1];
END ExtractCharacter;


PROCEDURE ExtractBoolean( VAR S : ARRAY OF CHAR;
                              N : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN (CAP(ExtractCharacter(S,N)) = "T");
END ExtractBoolean;




PROCEDURE SameFormat(     Format1           : ATimeFormat;
                          Format2           : ATimeFormat ) : BOOLEAN;

VAR
    i                       : CARDINAL;
    Same                    : BOOLEAN;

BEGIN                       (* SameFormat *)

    Same := TRUE;
    FOR i := 0 TO HIGH(Format1) DO
        WITH Format1[i] DO
            Same := Same AND (Unit = Format2[i].Unit) 
                    AND (Size = Format2[i].Size) AND (Text = Format2[i].Text);
            Same := Same AND (StringsEqual( FillChar, Format2[i].FillChar ));
            Same := Same AND (StringsEqual( FollowBy, Format2[i].FollowBy ));
        END;
    END;

    RETURN Same;

END SameFormat;


PROCEDURE MakeAFormat(     Base             : CARDINAL;
                       VAR Format           : ATimeFormat );

VAR
    i                       : CARDINAL;
    S                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* MakeAFormat *)

    FOR i := 0 TO HIGH(Format) DO
        GetMessage(ModuleNumber+Base+i, S);
        IF (LengthOf(S) = 0) THEN
            GetMessage(ModuleNumber + 5, S);                      (* 9-Oct-89 MWP *)
            (* "Missing date format line." *)
            Error(S);
            RETURN;
        END;
        WITH Format[i] DO
            Unit := VAL(ADurationUnit, ExtractCardinal(S,1));
            Size := ExtractCardinal(S,2);
            Text := ExtractBoolean(S,3);
            WordNumber(S,4,FillChar);
            WordNumber(S,5,FollowBy);
        END;
    END;

END MakeAFormat;



PROCEDURE FindCurrentFormat( VAR MenuString : ARRAY OF CHAR ) : CARDINAL;

VAR
    Choice                  : CARDINAL;
    LocalDateAndTimeFormat  : ATimeFormat;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* FindCurrentFormat *)

    Choice := 1;
    LOOP
        WordNumber( MenuString, Choice, s );
        IF (LengthOf( s ) = 0) THEN
            Choice := 1;
            EXIT;
        END;
        MakeAFormat( Choice * 10, LocalDateAndTimeFormat );
        IF (SameFormat( LocalDateAndTimeFormat, DefaultDateAndTimeFormat )) THEN
            EXIT;
        END;
        INC( Choice );
    END;

    RETURN Choice;

END FindCurrentFormat;




PROCEDURE MakeFormat(Base:CARDINAL);
VAR
    i               : CARDINAL;
    S               : ARRAY [0..255] OF CHAR;
BEGIN

    MakeAFormat( Base, DefaultDateAndTimeFormat );

    UsingWeekNumbers := FALSE;                                      (* 2-Apr-90 MWP *)

    FOR i := 0 TO HIGH(DefaultDateAndTimeFormat) DO
        WITH DefaultDateAndTimeFormat[i] DO
            IF ( Unit = Weeks ) THEN                              (* 2-Apr-90 MWP *)
                UsingWeekNumbers := TRUE;
            END;
        END;
    END;


    DefaultDateFormat := DefaultDateAndTimeFormat;
    FOR i := 3 TO 4 DO
        DefaultDateFormat[i].Size := 0;
        SetLengthOf (DefaultDateFormat[i].FollowBy, 0);
    END;

    DefaultTimeFormat := DefaultDateAndTimeFormat;
    FOR i := 0 TO 2 DO
        DefaultTimeFormat[i].Size := 0;
        SetLengthOf (DefaultTimeFormat[i].FollowBy, 0);
    END;

    (* 31-Jan-92 TGS
    GetMessage(ModuleNumber+Base+6, S);

    WITH DefaultAmountFormat DO
        RadixSymbol            := ExtractCharacter(S,1);
        SymbolForSignificance  := ExtractCharacter(S,2);
        DigitsForSignificance  := ExtractCardinal(S,3);
        IncludeAtLeastOneDigit := ExtractBoolean(S,4);
        OverflowSymbol         := ExtractCharacter(S,5);
        WordNumber(S,6,Decorations.LeadingPositiveSymbol);
        WordNumber(S,7,Decorations.TrailingPositiveSymbol);
        WordNumber(S,8,Decorations.LeadingNegativeSymbol);
        WordNumber(S,9,Decorations.TrailingNegativeSymbol);
    END;

    GetMessage(ModuleNumber+Base+7, S);

    WITH DefaultCurrencyFormat DO
        AmountFormat            := DefaultAmountFormat;
        MinTrailingDigits       := ExtractCardinal(S,1);
        MaxTrailingDigits       := ExtractCardinal(S,2);
        Decorations             := DefaultAmountFormat.Decorations;
        WordNumber(S,3,DecorationsWithCurrency.LeadingPositiveSymbol);
        WordNumber(S,4,DecorationsWithCurrency.TrailingPositiveSymbol);
        WordNumber(S,5,DecorationsWithCurrency.LeadingNegativeSymbol);
        WordNumber(S,6,DecorationsWithCurrency.TrailingNegativeSymbol);
    END;
    *)
END MakeFormat;






PROCEDURE CheckDateFormat( VAR Format : ATimeFormat ): BOOLEAN;
VAR
    StartingMonth   : CARDINAL;
    ok              : BOOLEAN;
BEGIN
    ok := CheckDateFormatLength(DefaultDateAndTimeFormat);
    IF (NOT ok) THEN
        ErrorPhrase(ModuleNumber+8);
    ELSIF UsingWeekNumbers THEN (* 27-Sep-91 TGS *)
        GetStartingMonth(StartingMonth);
        ok := (StartingMonth = Jan);
        IF (NOT ok) THEN
            ErrorPhrase(ModuleNumber+9);
        END;
    END;
    RETURN ok;
END CheckDateFormat;





PROCEDURE InitFormatAs();
VAR
    Text        : ARRAY [0..255] OF CHAR;
    Title       : ARRAY [0..51] OF CHAR;
    Prefix      : ARRAY [0..31] OF CHAR;
    Choices     : ARRAY [0..255] OF CHAR;
    Choice      : CARDINAL;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetMessage(ModuleNumber+1,Text);     (* "Time Line contains preset date and currency formats for " *)
                                         (* "several countries.  Please choose one." *)
    GetMessage(ModuleNumber+2,Prefix);   
    GetMessage(ModuleNumber+3,Choices);  
    GetMessage(ModuleNumber+4,Title);    
    Choice := FindCurrentFormat( Choices );

    REPEAT
        IF (MultipleChoiceBox(Text,Title,NoHelp,Prefix,Choices,Choice)) THEN
            MakeFormat(Choice * 10);
            ConfigSaved := FALSE;
            InitializeTimeFormat();
        ELSE
            Choice := 1;
        END;
    UNTIL (CheckDateFormat(DefaultDateAndTimeFormat));

END InitFormatAs;


BEGIN                       (* Formats *)

    InitFormatAs();

END TLFMTINT.
