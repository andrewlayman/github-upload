MODULE TLNUMFRM;

  (* Modification History:
    27-Jan-92 TGS   First Version, "read only".
    31-Jan-92 TGS   Finish hooking up all fields. Add "None" 1000's choice.
    13-Feb-92 TGS   Add "Quote" char as valid 1000's separator.
     3-Apr-92 TGS   Fix problem with NoSep 1000's separator.
  *)

FROM Codes          IMPORT
    (* TYPE *)          ACode;

FROM Dialog         IMPORT
                        ADialogOption, WarningBox,
                        MultipleChoiceBox, Error, FatalError, ErrorPhrase;

FROM FormCon        IMPORT
                        AFieldNo;

FROM Forms          IMPORT
                        DoForm, AFieldValue, ACheckReason, NullCheckProc,
                        AStringValue, ShowValue, AForm, SetFieldProtection,
                        SetFormChange;

FROM Kbio           IMPORT
                        maxcol;

FROM Keys           IMPORT
    (* CONST *)         ExitKey;

FROM Layout         IMPORT
                        GanttWEnd;

FROM LStrings       IMPORT
                        SetString, SubStr, Procustes, CtoS, StoC, Search,
                        ConcatS, ConcatLS, Insert, Remove, Fill, TrimRear,
                        LJust, RJust, Overlay, LStringToTString, TrimFront,
                        Upshift, Copy, SetLengthOf, LengthOf, StringsEqual;

FROM Menus          IMPORT
                        WordNumber;

FROM MsgFile        IMPORT
                        GetMessage;

FROM RealFormat     IMPORT
    (* TYPE *)          AnAmountFormat, ACurrencyFormat,
    (* VAR  *)          DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROC *)          FormatAsAmount, FormatAsCurrency;

FROM Schedule       IMPORT
                        ConfigSaved, InstalledFlag;

FROM Space          IMPORT
                        ALLOCATE, DEALLOCATE;

FROM Timei          IMPORT
    (* CONST *)         Jan,
    (* TYPE *)          ADurationUnit;

FROM Timeu          IMPORT 
    (* PROC *)          GetStartingMonth, SetStartingMonth;

CONST
    ModuleNumber = 30700;

    DSP   = 0; (* Decimal Separator *)
    TSP   = 1; (* Thousands Separator *)
    NPP   = 2; (* Number positive prefix *)
    NPE   = 3; (* Number positive example *)
    NPS   = 4; (* Number positive suffix *)
    NNP   = 5; (* Number negative prefix *)
    NNE   = 6; (* Number negative example *)
    NNS   = 7; (* Number negative suffix *)
    NSZ   = 8; (* Number show leading zero *)
    CPP   = 9; (* Currency positive prefix *)
    CPE   =10; (* Currency positive example *)
    CPS   =11; (* Currency positive suffix *)
    CNP   =12; (* Currency negative prefix *)
    CNE   =13; (* Currency negative example *)
    CNS   =14; (* Currency negative suffix *)
    CSZ   =15; (* Currency show leading zero *)
    CMX   =16; (* Currency show max digits *)
    CMN   =17; (* Currency show min digits *)

    NumberOfFields  = 17;

    MaxLength       = 18;

    ExampleStringFields = {NPE, NNE, CPE, CNE};
    PrefixSuffixFields  = {NPP, NPS, NNP, NNS, CPP, CPS, CNP, CNS};

    PositiveNumber   = 1234.56;
    NegativeNumber   =-1234.56;

VAR
    FormValue    : ARRAY [DSP..CMN] OF AFieldValue;
    Code         : ACode;
    LocalAmountFormat     : AnAmountFormat;
    LocalCurrencyFormat   : ACurrencyFormat;
    Period, Comma, Quote,
    Space, NoSep,
    PlaceholderChar       : CHAR;
    PhrasesDigitsForSignificance : CARDINAL;

PROCEDURE ReplaceCharInLS( VAR s : ARRAY OF CHAR; c1, c2 : CHAR );
VAR
    s1, s2 : ARRAY[0..1] OF CHAR;
    i      : CARDINAL;
BEGIN
    SetString(s1, c1);
    SetString(s2, c2);
    i := Search(s, s1, 1);
    WHILE (i > 0) DO
        Remove(s, i, 1);
        Insert(s, s2, i);
        i := Search(s, s1, 1);
    END;
END ReplaceCharInLS;

PROCEDURE MapDefaultFormatsToForm();
VAR
    i   : CARDINAL;
BEGIN

    WITH DefaultAmountFormat DO

        IF (RadixSymbol = Period) THEN
            FormValue[DSP].CardValue := 0;
        ELSE
            FormValue[DSP].CardValue := 1;
        END;

        IF    (SymbolForSignificance = Comma) THEN
            FormValue[TSP].CardValue := 1;
        ELSIF (SymbolForSignificance = Quote) THEN
            FormValue[TSP].CardValue := 2;
        ELSIF (SymbolForSignificance = Space) THEN
            FormValue[TSP].CardValue := 3;
        ELSIF (SymbolForSignificance = NoSep) THEN
            FormValue[TSP].CardValue := 4;
            LocalAmountFormat.DigitsForSignificance := 9999;
            LocalCurrencyFormat.AmountFormat.DigitsForSignificance := 9999;
        ELSE (* "Period" or whatever *)
            FormValue[TSP].CardValue := 0;
        END;

        WITH Decorations DO
            Copy(LeadingPositiveSymbol,  FormValue[NPP].CharValue^);
            Copy(TrailingPositiveSymbol, FormValue[NPS].CharValue^);
            Copy(LeadingNegativeSymbol,  FormValue[NNP].CharValue^);
            Copy(TrailingNegativeSymbol, FormValue[NNS].CharValue^);
        END;
    
        IF (IncludeAtLeastOneDigit) THEN
            FormValue[NSZ].CardValue := 0;
        ELSE
            FormValue[NSZ].CardValue := 1;
        END;

    END;

    SetLengthOf(FormValue[NPE].CharValue^, 0);
    SetLengthOf(FormValue[NNE].CharValue^, 0);

    WITH DefaultCurrencyFormat DO
        WITH DecorationsWithCurrency DO
            Copy(LeadingPositiveSymbol,  FormValue[CPP].CharValue^);
            Copy(TrailingPositiveSymbol, FormValue[CPS].CharValue^);
            Copy(LeadingNegativeSymbol,  FormValue[CNP].CharValue^);
            Copy(TrailingNegativeSymbol, FormValue[CNS].CharValue^);
        END;
        IF (AmountFormat.IncludeAtLeastOneDigit) THEN
            FormValue[CSZ].CardValue := 0;
        ELSE
            FormValue[CSZ].CardValue := 1;
        END;
        FormValue[CMX].CardValue := MaxTrailingDigits;
        FormValue[CMN].CardValue := MinTrailingDigits;
    END;

    SetLengthOf(FormValue[CPE].CharValue^, 0);
    SetLengthOf(FormValue[CNE].CharValue^, 0);

    (* Replace any spaces in the Decorations with PlaceholderChar *)
    FOR i := NPP TO CNS DO
        IF (i IN PrefixSuffixFields) THEN
            ReplaceCharInLS(FormValue[i].CharValue^, " ", PlaceholderChar);
        END;
    END;

END MapDefaultFormatsToForm;

    (*  CheckNumForm -

        - Separators must be unequal
        - Re-display all examples whenever separators change.
        - Re-display number examples whenever number pre/suffixes change.
        - Re-display currency examples whenever currency pre/suffixes or
            min/max decimals change.
    *)

PROCEDURE CheckNumForm( Form        : AForm;
                        FieldNo     : AFieldNo;
                    VAR FormValue   : ARRAY OF AFieldValue;
                        CheckReason : ACheckReason;
                    VAR Code        : CARDINAL ) : BOOLEAN;

VAR
    s   : ARRAY[0..5] OF CHAR;

    PROCEDURE CheckSeparators(Field : CARDINAL);
    BEGIN
        IF (FormValue[DSP].CardValue = FormValue[TSP].CardValue) THEN
            IF (Field = DSP) THEN
                FormValue[TSP].CardValue := (FormValue[DSP].CardValue + 1) MOD 2;
                ShowValue(Form, TSP, FormValue);
            ELSE
                FormValue[DSP].CardValue := (FormValue[TSP].CardValue + 1) MOD 2;
                ShowValue(Form, DSP, FormValue);
            END;
        END;
    END CheckSeparators;

    PROCEDURE ResetLocalFormat(Field : CARDINAL);
    VAR
        i   : CARDINAL;
        Ch  : CHAR;

        PROCEDURE FormValToDecoration(VAR s1, s2   : ARRAY OF CHAR;
                                          IsPrefix : BOOLEAN);
        VAR
            s3     : ARRAY[0..1] OF CHAR;
            i      : CARDINAL;
        BEGIN
            TrimFront(s1);
            TrimRear(s1);
            Copy(s1, s2);
            SetString(s3, PlaceholderChar);

            IF IsPrefix THEN
                WHILE (Search(s1, s3, 1) = 1) DO
                    Remove(s1, 1, 1);
                END;
            ELSE
                i := LengthOf(s1);
                WHILE (i > 0) AND (Search(s1, s3, i) = i) DO
                    Remove(s1, i, 1);
                    i := LengthOf(s1);
                END;
            END;

            ReplaceCharInLS(s2, PlaceholderChar, " ");

            IF IsPrefix THEN
                TrimFront(s2);
            ELSE
                TrimRear(s2);
            END;
        END FormValToDecoration;

    BEGIN (* ResetLocalFormat *)
        CASE Field OF
        DSP, TSP      :
            FOR i := DSP TO TSP DO
                CASE FormValue[i].CardValue OF
                | 0 : Ch := Period;
                | 1 : Ch := Comma;
                | 2 : Ch := Quote;
                | 3 : Ch := Space;
                | 4 : Ch := NoSep;
                ELSE
                    FatalError();
                END;
                IF (i = DSP) THEN
                    LocalAmountFormat.RadixSymbol := Ch;
                    LocalCurrencyFormat.AmountFormat.RadixSymbol := Ch;
                ELSE (* TSP: Thousands separator *)
                    LocalAmountFormat.SymbolForSignificance := Ch;
                    LocalCurrencyFormat.AmountFormat.SymbolForSignificance := Ch;
                    IF (Ch = NoSep) THEN
                        LocalAmountFormat.DigitsForSignificance := 9999;
                        LocalCurrencyFormat.AmountFormat.DigitsForSignificance
                            := 9999;
                    ELSE
                        LocalAmountFormat.DigitsForSignificance :=
                            PhrasesDigitsForSignificance;
                        LocalCurrencyFormat.AmountFormat.DigitsForSignificance :=
                            PhrasesDigitsForSignificance;
                    END;
                END;
            END;
        | NPP, NPS      : (* we don't allow editing of these at present *)
        | NNP           :
            FormValToDecoration(FormValue[Field].CharValue^, s, TRUE);
            Copy(s, LocalAmountFormat.Decorations.LeadingNegativeSymbol);
            Copy(s, LocalCurrencyFormat.Decorations.LeadingNegativeSymbol);
        | NNS           :
            FormValToDecoration(FormValue[Field].CharValue^, s, FALSE);
            Copy(s, LocalAmountFormat.Decorations.TrailingNegativeSymbol);
            Copy(s, LocalCurrencyFormat.Decorations.TrailingNegativeSymbol);
        | CPP           :
            FormValToDecoration
                (FormValue[Field].CharValue^,
                 LocalCurrencyFormat.DecorationsWithCurrency.LeadingPositiveSymbol,
                 TRUE);
        | CPS           :
            FormValToDecoration
                (FormValue[Field].CharValue^,
                 LocalCurrencyFormat.DecorationsWithCurrency.TrailingPositiveSymbol,
                 FALSE);
        | CNP           :
            FormValToDecoration
                (FormValue[Field].CharValue^,
                 LocalCurrencyFormat.DecorationsWithCurrency.LeadingNegativeSymbol,
                 TRUE);
        | CNS           :
            FormValToDecoration
                (FormValue[Field].CharValue^,
                 LocalCurrencyFormat.DecorationsWithCurrency.TrailingNegativeSymbol,
                 FALSE);
        | CMX           :
            LocalCurrencyFormat.MaxTrailingDigits := FormValue[CMX].CardValue;
            IF (FormValue[CMX].CardValue < FormValue[CMN].CardValue) THEN
                FormValue[CMN].CardValue := FormValue[CMX].CardValue;
                LocalCurrencyFormat.MinTrailingDigits := FormValue[CMN].CardValue;
                ShowValue(Form, CMN, FormValue);
            END;
        | CMN           :
            LocalCurrencyFormat.MinTrailingDigits := FormValue[CMN].CardValue;
            IF (FormValue[CMX].CardValue < FormValue[CMN].CardValue) THEN
                FormValue[CMX].CardValue := FormValue[CMN].CardValue;
                LocalCurrencyFormat.MaxTrailingDigits := FormValue[CMX].CardValue;
                ShowValue(Form, CMX, FormValue);
            END;
        ELSE

        END;

        IF (Field IN PrefixSuffixFields) THEN
            ShowValue(Form, Field, FormValue); (* in case it changed *)
        END;

    END ResetLocalFormat;

    PROCEDURE RedisplayExamples(Field : CARDINAL);
    VAR
        s   : ARRAY[0..MaxLength] OF CHAR;
    BEGIN
        FormatAsAmount  ( PositiveNumber, LocalAmountFormat, s,
                        MaxLength, 2, 2, TRUE );
        Copy(s, FormValue[NPE].CharValue^);
        ShowValue(Form, NPE, FormValue);

        FormatAsAmount  ( NegativeNumber, LocalAmountFormat, s,
                        MaxLength, 2, 2, TRUE );
        Copy(s, FormValue[NNE].CharValue^);
        ShowValue(Form, NNE, FormValue);

        FormatAsCurrency( PositiveNumber, LocalCurrencyFormat, s,
                        MaxLength, TRUE, TRUE, TRUE );
        Copy(s, FormValue[CPE].CharValue^);
        ShowValue(Form, CPE, FormValue);

        FormatAsCurrency( NegativeNumber, LocalCurrencyFormat, s,
                          MaxLength, TRUE, TRUE, TRUE );
        Copy(s, FormValue[CNE].CharValue^);
        ShowValue(Form, CNE, FormValue);

    END RedisplayExamples;
                                             
    PROCEDURE CheckNumSymbols() : BOOLEAN;
    BEGIN
        WITH LocalAmountFormat.Decorations DO
            IF (StringsEqual(LeadingPositiveSymbol, 
                             LeadingNegativeSymbol) AND
                StringsEqual(TrailingPositiveSymbol, 
                             TrailingNegativeSymbol))   THEN
                RETURN FALSE;
            END;
        END;
        RETURN TRUE;
    END CheckNumSymbols;

    PROCEDURE CheckCurSymbols() : BOOLEAN;
    BEGIN
        WITH LocalCurrencyFormat.DecorationsWithCurrency DO
            IF (StringsEqual(LeadingPositiveSymbol,
                             LeadingNegativeSymbol) AND
                StringsEqual(TrailingPositiveSymbol,
                             TrailingNegativeSymbol))   
                    OR
               ((LengthOf(TrailingNegativeSymbol) = 0 ) AND
                (LengthOf(LeadingNegativeSymbol)  = 0 ))
                    THEN
                RETURN FALSE;
            END;
        END;
        RETURN TRUE;
    END CheckCurSymbols;

BEGIN (* CheckNumForm *)

    CASE CheckReason OF
      CheckFormEntry    :
        IF (FieldNo = DSP) THEN
            CheckSeparators(DSP);
            RedisplayExamples(FieldNo);
        END;
    | CheckFormExit     :
        IF (FieldNo = DSP) THEN
            (* must have some kinda negative symbols *)
            IF NOT CheckNumSymbols() THEN
                ErrorPhrase(30702);
                Code := 0;
                RETURN FALSE;
            END;

            (* positive/negative currency symbols must be different *)
            IF NOT CheckCurSymbols() THEN
                ErrorPhrase(30703);
                Code := 0;
                RETURN FALSE;
            END;
        END;
    | CheckFieldKey     :
        IF (FieldNo IN PrefixSuffixFields) THEN
            IF (Code = 32) THEN
                Code := CARDINAL(BITSET(ORD(PlaceholderChar)) + {14});
                RETURN TRUE;
            END;
        END;
    | CheckFieldChange  :
        CASE FieldNo OF
        | DSP, TSP              :
            CheckSeparators(FieldNo);
            ResetLocalFormat(FieldNo);
            RedisplayExamples(FieldNo);
        | NPP, NPS, NNP, NNS,
          CPP, CPS, CNP, CNS,
          CMX, CMN              :
            ResetLocalFormat(FieldNo);
            RedisplayExamples(FieldNo);
        ELSE
        END;
    ELSE
    END;

    Code := 0;
    RETURN TRUE;

END CheckNumForm;

PROCEDURE DoNumForm();
VAR
    s   : ARRAY[0..20] OF CHAR;
    s1  : ARRAY[0..4] OF CHAR;
    i   : CARDINAL;
    ch  : CHAR;
    ok  : BOOLEAN;

    PROCEDURE GetCharN( VAR s : ARRAY OF CHAR; n : CARDINAL; VAR c : CHAR)
                        : BOOLEAN;
    VAR
        s1 : ARRAY[0..1] OF CHAR;
    BEGIN
        WordNumber(s, n, s1);
        IF (LengthOf(s1) = 0) THEN
            RETURN FALSE;
        END;
        c := s1[1];
        RETURN TRUE;
    END GetCharN;

BEGIN

    (* Get separator char definitions. *)
    GetMessage(30700, s);
    IF (LengthOf(s) = 0) THEN
        FatalError();
    END;

    ok :=        GetCharN(s, 1, Period);
    ok := ok AND GetCharN(s, 2, Comma);
    ok := ok AND GetCharN(s, 3, Quote);
    ok := ok AND GetCharN(s, 4, Space);
    ok := ok AND GetCharN(s, 5, NoSep);

    (* Get the rest of the stuff *)
    GetMessage(30701, s);
    IF (LengthOf(s) = 0) THEN
        FatalError();
    END;
    ok := ok AND GetCharN(s, 1, PlaceholderChar);
    ok := ok AND GetCharN(s, 2, ch);
    IF NOT ok THEN
        RETURN;
    END;

    (* Map default format values to form values *)
    MapDefaultFormatsToForm();

    (* Make copies of the default number/currency formats *)
    LocalAmountFormat     := DefaultAmountFormat;
    LocalCurrencyFormat   := DefaultCurrencyFormat;

    LocalAmountFormat.OverflowSymbol := ch;
    LocalCurrencyFormat.AmountFormat.OverflowSymbol := ch;

    WordNumber(s, 3, s1);
    i := 1;
    PhrasesDigitsForSignificance := StoC(s1, i);    (* 3-Apr-92 TGS *)

    WordNumber(s, 4, s1);
    Copy(s1, LocalAmountFormat.Decorations.LeadingPositiveSymbol);
    Copy(s1, LocalCurrencyFormat.Decorations.LeadingPositiveSymbol);
    WordNumber(s, 5, s1);
    Copy(s1, LocalAmountFormat.Decorations.TrailingPositiveSymbol);
    Copy(s1, LocalCurrencyFormat.Decorations.TrailingPositiveSymbol);

    IF ( DoForm(10,0,maxcol,GanttWEnd-4,120,TRUE,FormValue,CheckNumForm) 
             = ExitKey ) THEN
        (* If F10 hit, copy new number/currency formats to defaults *)
        DefaultAmountFormat     := LocalAmountFormat;
        DefaultCurrencyFormat   := LocalCurrencyFormat;
        ConfigSaved := FALSE;
    END;

END DoNumForm;

PROCEDURE AllocateFormStrings();
VAR
    i   : CARDINAL;
BEGIN
    FOR i := 0 TO NumberOfFields DO
        IF ((i IN PrefixSuffixFields) OR
            (i IN ExampleStringFields) )    THEN
            NEW(FormValue[i].CharValue);
        END;
    END;
END AllocateFormStrings;

PROCEDURE DeallocateFormStrings();
VAR
    i   : CARDINAL;
BEGIN
    FOR i := 0 TO NumberOfFields DO
        IF ((i IN PrefixSuffixFields) OR
            (i IN ExampleStringFields) )    THEN
            DISPOSE(FormValue[i].CharValue);
        END;
    END;
END DeallocateFormStrings;

BEGIN

    AllocateFormStrings();

    DoNumForm();

    DeallocateFormStrings();

END TLNUMFRM.
