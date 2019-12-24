IMPLEMENTATION MODULE FormatCommon;

(*V1=TRACE*)

(*  =========================================================================
    Last Edit : August 16, 1991 9:28AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
    Format Common - Helper routine for TaskFormat, RsrcFormat, EdgeFormat, and
                    AssFormat.

    MODIFICATION HISTORY:

        RSC  20-Feb-89  First version, code inspired by TLCaption.
        RSC  16-Mar-89  Added support for "Next Column".
        RSC  17-Mar-89  Added "GetFormattingInfo"
        RSC  20-Mar-89  Added procedures to get words from phrases.
        RSC  22-Mar-89  Upgraded for "Better Reports" project.
        RSC  27-Mar-89  Added "GetValueInfo" for "Better Reports" project.
        RSC   3-Apr-89  Removed automatic right justification.
        EGK  01-Sep-89  Added general-purpose "FormatDataValue" procedure
                        and format type constants.  Added FormatType
                        parameter to GetFormattingInfo.
        MWP  19-Oct-89  When formatting RealValue numbers, check that we
                        do not have an impossibly large number by comparing
                        it against the 'SaganConstant'. If it is > SaganC,
                        assume the real value is 0.0.
        AJL  16-Sep-90  Add formatting of BigTimes.
        26-Sep-90 PFG   Implemented user-defined column headings for use
                        of Resource, Assignment and Cross Tab columns.
        23-Oct-90 AJL   Well, somebody laid a good booby trap for Patty when
                        they named a type "DataType" exported from ColumnSupport
                        and named a field in AColumnDataRecord "DataType".
                        There is a WITH Statement in ColumnInfo that uses "DataType".
                        But, although it looks to be using ColumnSupport.DataType
                        it really ends up using the field from the record.
                        I have changed this to be more explicit.  Now, the question
                        is: why does ColumnSupport export the types as CARDINAL
                        numbers instead of enumerated types, which would have
                        caught this error?  Cost me two days to find this one.

        22-Jan-91  RSC  Import LongDurationToString from LongDuration rather
                        than from TimeFormat.
        15-Aug-91  PFG  Gave this module its own section in phrases and
                        stopped using the TLCaptions phrase for boolean
                        column values.  This allowed us to change to "Y" and
                        "N" for output from "T" and "F".
         3-Apr-92 TGS Add parameter to LongDurationToString to help align.
    =========================================================================
*)




FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  BigTimeToTimeInfo;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
                                AColumnDataField, ASetOfColumnDataFields,
    (* PROC *)                  DataFieldsFromDataType, GetCurrencyScale;

FROM ColData                IMPORT
    (* TYPE *)                  AColumnType;            (* 26-Sep-90 PFG  *)

FROM ColFind                IMPORT
    (* PROC *)                  GetColInfoFromPhrasesOrText;    (* 26-Sep-90 PFG  *)

FROM ColumnSupport          IMPORT                      (* 26-Sep-90 PFG  *)
    (* CONST *)                 FullTitle,
                                Title1,
                                Title2,
                                DefaultLength,
                                NarrowWidth,
                                NarrowTitle1,
                                NarrowTitle2,
                                FormalName,
                                UniqueID,
                                Percentage,
                                MinExportWidth,
                                FormatType,
                                MaxDecimals,     
                                TotalByRsrc,
                                MinDecimals,    
                                BslnRequired,    
                                BslnDifferent,   
                                RightJustify,  
                                SortOrder;
IMPORT ColumnSupport;                                   (* 23-Oct-90 AJL *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, NotYetImplemented, Message;

FROM LongDuration           IMPORT
    (* PROC *)                  LongDurationToString;

FROM LStrings               IMPORT
    (* PROC *)                  StoC, Copy, RJust, Procustes, ConcatLS,
                                LengthOf, SetLengthOf, CtoS, SetString,
                                Search, Fill, Insert, TrimFront, ConcatS;

FROM MagicNum               IMPORT
    (* CONST *)                 IsStringValue,
                                IsRealValue,
                                IsIntValue,
                                IsCardValue,
                                IsBoolValue,
                                IsEnumValue,
                                IsBigStart,
                                IsBigEnd,
                                IsStartDate,
                                IsEndDate,
                                IsDuration,
                                IsSlack,
                                IsCurrency,
                                IsEffort,
                                IsMilestoneEnd,
                                IsDurationUnits,
                                IsEffortUnits,
                                IsTruncatedString,
                                SaganConstant;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM RealFormat IMPORT
    (* VARS *)      DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROCS *)     FormatAsAmount, FormatAsCurrency;

FROM TimeFormat IMPORT
    (* VAR *)       DefaultDateAndTimeFormat,
    (* PROCS *)     TimeUtoS, TimeToString,
                    FormatAsEndDateStyle;

FROM Timei      IMPORT
    (* CONST *)     NoDuration,
    (* TYPE  *)     ADate, ADurationUnit, ATimeInfo,
    (* PROC  *)     TimeUtoT;

FROM WorkHours  IMPORT
    (* PROC *)      WorkHoursToRealTime;



(*<TRACE
FROM Tracer IMPORT PrintString, EndTrace;
VAR
    TraceS, TraceS2 : ARRAY [0..255] OF CHAR;
TRACE>*)





CONST
    Zero                    =   0.0;
    One                     =   1.0;
    OneHundred              = 100.0;

    ModuleNumber            = 27500;            (* 16-Aug-91 PFG *)

VAR
    TrueChar,
    FalseChar            : CHAR;





(*
    Column Info

        Reads column information from the encoded phrase.

        Preconditions
                        > PhraseNumber is the BASE phrase to get the
                          information from.  It is in our "standard
                          captions phrase format".

                        > ColumnID is the desired column ID.

                        > LastColumnID is used for the "Next Column"
                          request.  THIS IMPLEMENTATION REQUIRES THAT ALL
                          COLUMNS BE SEQUENTIAL.

                        > InfoChoice is the kind of information you desire.

                        > Length is the length of the string to return,
                          important mostly for Right Justified strings.

                        > ColumnType is the type of column: Resource,
                          Assignment, Cross Tab, etc.

        Postconditions
                        > ReturnValue contains the desired information.
                          If a string value is being returned, it may be right
                          justified, and is always exactly "Length" bytes long.

*)
PROCEDURE ColumnInfo(     PhraseNumber,
                          ColumnID,
                          LastColumnID    : CARDINAL;
                          InfoChoice      : AColumnInfoChoice;
                          Length          : CARDINAL;
                          ColumnType      : AColumnType;
                      VAR ReturnValue     : AColumnDataRecord);
VAR
    s                       : ARRAY [0..255] OF CHAR;


    PROCEDURE GetNumber( Word : CARDINAL );
    VAR
        i   : CARDINAL;
    BEGIN
         (*<TRACE
         SetString(TraceS,"    GetNumber(");
         CtoS(Word,TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS,") of '");
         ConcatLS(TraceS,s); ConcatS(TraceS,"'");
         PrintString(TraceS);
         TRACE>*)

        WITH ReturnValue DO
            DataType      := IsCardValue;
            DataFields    := ASetOfColumnDataFields{CardinalInUse};

            WordNumber(s, Word, StringValue);
            i := 1;
            CardinalValue := StoC(StringValue, i);
        END;
    END GetNumber;


    PROCEDURE GetText( Word : CARDINAL );
    VAR
        s2  : ARRAY [0..5] OF CHAR;
    BEGIN
        WITH ReturnValue DO
            DataType   := IsStringValue;
            DataFields := ASetOfColumnDataFields{StringInUse};

            WordNumber(s, Word, StringValue);

            IF (Length >  HIGH(StringValue)) THEN
                Length := HIGH(StringValue);
            END;
            Procustes( StringValue, Length );

            (* **** RSC 3-Apr-89 *****************

            WordNumber(s, 17, s2);   (* Right Justify it? *)

            IF (s2[1] = "T") THEN
                RJust( StringValue );
            END;

            **** RSC 3-Apr-89 ***************** *)
        END;
    END GetText;


    PROCEDURE GetBoolean( Word : CARDINAL );
    BEGIN
        WITH ReturnValue DO
            DataType   := IsBoolValue;
            DataFields := ASetOfColumnDataFields{BooleanInUse};

            WordNumber(s, Word, StringValue);
            BooleanValue := (StringValue[1] = "T");  (* Yes, its in English *)
        END;
    END GetBoolean;


BEGIN
    GetColInfoFromPhrasesOrText(PhraseNumber, ColumnType, ColumnID, s);   (* 26-Sep-90 PFG *)

     (*<TRACE
     SetString(TraceS,"FormatCommon.ColumnInfo(");
     CtoS(PhraseNumber,TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS,",");
     CtoS(ColumnID,TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS,",");
     CtoS(ORD(InfoChoice),TraceS2);  ConcatLS(TraceS,TraceS2); ConcatS(TraceS,")");
     PrintString(TraceS);
     TRACE>*)


    WITH ReturnValue DO

        CASE InfoChoice OF
            ColumnNext :

                IF (ColumnID >= LastColumnID) THEN
                    CardinalValue := 0;
                ELSE
                    CardinalValue := ColumnID + 1;
                END;

        |   ColumnWidth :

                GetNumber( ColumnSupport.DefaultLength );

        |   ColumnName :

                GetText( ColumnSupport.FullTitle );

        |   ColumnHeading1 :

                GetNumber( ColumnSupport.NarrowWidth );     (* Width for narrow hdg *)
                IF (Length > CardinalValue) THEN
                    GetText( ColumnSupport.Title1 );        (* Full heading *)
                ELSE
                    GetText( ColumnSupport.NarrowTitle1 );  (* Narrow heading *)
                END;

        |   ColumnNarrowHeading1 :

                GetText( ColumnSupport.NarrowTitle1 );      (* Narrow heading *)

        |   ColumnHeading2 :

                GetNumber( ColumnSupport.NarrowWidth );     (* Width for narrow hdg *)
                IF (Length > CardinalValue) THEN
                    GetText( ColumnSupport.Title2 );        (* Full heading *)
                ELSE
                    GetText( ColumnSupport.NarrowTitle2 );  (* Narrow heading *)
                END;

        |   ColumnNarrowHeading2 :

                GetText( ColumnSupport.NarrowTitle2 );      (* Narrow heading *)

        |   ColumnNarrowWidth :

                GetNumber( ColumnSupport.NarrowWidth );     (* Width for narrow hdg *)

        |   ColumnExportWidth :

                GetNumber( ColumnSupport.MinExportWidth );

        |   ColumnMinDecimals :

                GetNumber( ColumnSupport.MinDecimals );

        |   ColumnMaxDecimals :

                GetNumber( ColumnSupport.MaxDecimals );

        |   ColumnDataType :

                GetNumber( ColumnSupport.DataType );

        |   ColumnFormatType :

                GetNumber( ColumnSupport.FormatType );

        |   ColumnFormalName :
    
                GetText( ColumnSupport.FormalName );

        |   ColumnUniqueId :

                GetBoolean( ColumnSupport.UniqueID );

        |   ColumnRightJustified :

                GetBoolean( ColumnSupport.RightJustify );

        |   ColumnBslnRequired :

                GetBoolean( ColumnSupport.BslnRequired );

        |   ColumnBslnDifferent :

                GetBoolean( ColumnSupport.BslnDifferent );

        |   ColumnPhraseRaw :

                Copy(s, StringValue);

        |   ColumnSortSequence :

                GetNumber( ColumnSupport.SortOrder );

        |   ColumnTotalByRsrc  :

                GetBoolean( ColumnSupport.TotalByRsrc );
        ELSE
            FatalError();
        END;

    END;
END ColumnInfo;










(*
    Get Formatting Info

        Reads column information from the encoded phrase.  Returns the
        information needed by column formatters.

        Preconditions
                        > PhraseNumber is the phrase to get the information
                          from.  It is in our "standard captions phrase
                          format".

        Postconditions
                        > MinDecimals, MaxDecimals, and RightJustify are
                          returned.
*)
PROCEDURE GetFormattingInfo(    PhraseNumber : CARDINAL;
                            VAR MinDecimals,
                                MaxDecimals  : CARDINAL;
                            VAR RightJustify : BOOLEAN;
                            VAR FormatType   : CARDINAL );
VAR
    i   : CARDINAL;
    s   : ARRAY [0..255] OF CHAR;
    s1  : ARRAY [0..9]   OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );  (* The column description *)

    WordNumber(s, 14, s1);
    i           := 1;
    MinDecimals := StoC(s1, i);

    WordNumber(s, 11, s1);
    i           := 1;
    MaxDecimals := StoC(s1, i);

    WordNumber(s, 10, s1);
    i           := 1;
    FormatType  := StoC(s1, i);         (* 9/1/89 EGK *)

    WordNumber(s, 17, s1);
    RightJustify := (s1[1] = "T");  (* Yes, its in English *)

END GetFormattingInfo;





(*
    Get Value Info

        Reads column information from the encoded phrase.  Returns the
        information needed by column value procedures.

        Preconditions
                        > PhraseNumber is the phrase to get the information
                          from.  It is in our "standard captions phrase
                          format".

        Postconditions
                        > DataType and DataFields are returned.
*)
PROCEDURE GetValueInfo(    PhraseNumber  : CARDINAL;
                       VAR DataType      : CARDINAL;
                       VAR DataFields    : ASetOfColumnDataFields );
VAR
    i   : CARDINAL;
    s   : ARRAY [0..255] OF CHAR;
    s1  : ARRAY [0..9]   OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );  (* The column description *)

    WordNumber(s, 12, s1);
    i           := 1;
    DataType    := StoC(s1, i);

    DataFields  := DataFieldsFromDataType( DataType );

END GetValueInfo;









(* Get Message Word

        Given a phrase number, get the appropriate "word", or comma seperated
        value, from the phrase and return it into "Return Value".

        TheWordNumber starts with word 0, not 1.
*)
PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber + 1, ReturnValue );
END GetMessageWord;






(* Concat Message Word

        Given a phrase number, get the appropriate "word", or comma seperated
        value, from the phrase and append it onto "Return Value".

        TheWordNumber starts with word 0, not 1.
*)
PROCEDURE ConcatMessageWord( PhraseNumber    : CARDINAL;
                             TheWordNumber   : CARDINAL;
                         VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..99] OF CHAR;
BEGIN
    GetMessageWord( PhraseNumber, TheWordNumber, s );
    ConcatLS( ReturnValue, s );
END ConcatMessageWord;




PROCEDURE BigTimeToString( B : ABigTime; VAR S : ARRAY OF CHAR );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    BigTimeToTimeInfo(B,TimeInfo);
    TimeToString(TimeInfo,DefaultDateAndTimeFormat,S);
END BigTimeToString;





PROCEDURE FormatDataValue(    Width             : CARDINAL;
                              MinDecimals       : CARDINAL;
                              MaxDecimals       : CARDINAL;
                              RightJustify      : BOOLEAN;
                              FormatType        : CARDINAL;
                          VAR ReturnValue       : AColumnDataRecord);

VAR
    CurrencyScale           : REAL;
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    Simple                  : BOOLEAN;

BEGIN                       (* FormatValue *)

    IF (Width >  255) THEN
        Width := 255;
    END;

    WITH ReturnValue DO
        CASE DataType OF
            0 :
                SetLengthOf( StringValue, 0 );

        |   IsStringValue, IsEnumValue :

        |   IsTruncatedString :
                IF (Width > 0) AND (LengthOf( StringValue ) > Width) THEN
                    StringValue[Width] := "+";
                END;


        |   IsRealValue,
            IsCardValue,
            IsIntValue :

                Simple := (FormatType = FormatNumeric) AND (MaxDecimals=0);

                IF (DataType=IsCardValue) THEN
                    IF (Simple) THEN
                        CtoS(CardinalValue, StringValue);
                    ELSE
                        RealValue := FLOAT(CardinalValue);
                    END;
                ELSIF (DataType=IsIntValue) THEN
                    IF (Simple) AND (IntegerValue >= 0) THEN
                        CtoS(ORD(IntegerValue), StringValue);
                    ELSE
                        RealValue := FLOAT(IntegerValue);
                    END;
                ELSE
                    Simple := FALSE;
                END;

                IF (FormatType = FormatPercentage) THEN
                    CurrencyScale := OneHundred;
                ELSE
                    CurrencyScale := One;
                END;

                IF (NOT Simple) THEN
                    IF ( RealValue > SaganConstant ) THEN           (* 19-Oct-89 MWP *)
                        RealValue := 0.0
                    END;

                    FormatAsAmount(RealValue * CurrencyScale,
                                   DefaultAmountFormat, StringValue,
                                   Width, MinDecimals, MaxDecimals, RightJustify);
                END;

                RightJustify := FALSE;  (* RSC 1/23/89  FormatAs takes care of it *)


        |   IsBoolValue :
                Fill(StringValue, " ", Width);
                IF (BooleanValue) THEN
                    StringValue[1] := TrueChar;
                ELSE
                    StringValue[1] := FalseChar;
                END;

        |   IsStartDate,
            IsMilestoneEnd :
                TimeUtoS(DateValue, StringValue);

        |   IsEndDate :
                FormatAsEndDateStyle(DateValue, StringValue);

        |   IsBigStart,
            IsBigEnd:
                BigTimeToString( BigTimeValue, StringValue );
                

        |   IsDuration, IsEffort, IsSlack :
                FormatAsAmount( WorkHoursToRealTime(RealValue, TimeUnitValue),
                                DefaultAmountFormat,StringValue,
                                Width,MinDecimals,MaxDecimals,RightJustify);
                RightJustify := FALSE;

        |   IsDurationUnits, IsEffortUnits :
                LongDurationToString( RealValue,   TimeUnitValue,
                                      MinDecimals, MaxDecimals,
                                      Width,       StringValue, i );
                INC(i);
                TrimFront( StringValue );

                IF (i < 8) THEN (* RSC 2/13/89 At least 5 leading digits + ".n" *)
                    Fill( s, " ", 8 - i );
                    Insert( StringValue, s, 1 );
                END;

        |   IsCurrency :
                CurrencyScale   := GetCurrencyScale();
                IF (CurrencyScale <> One) THEN
                    RealValue   := RealValue / CurrencyScale;
                END;
                FormatAsCurrency( RealValue,
                                  DefaultCurrencyFormat,
                                  StringValue,
                                  Width,
                                  RightJustify,
                                  (MaxDecimals > 0),
                                  FALSE (* No "$" sign *) );
                RightJustify := FALSE;

        ELSE
            FatalError();
        END;

        (* Was a Procustes(), but that does a TrimFront!  RSC 1/23/89 *)

        i := LengthOf(StringValue);
        IF (i >= Width) THEN
            SetLengthOf(StringValue, Width);
        ELSE
            Fill(s, " ", Width - i);
            ConcatLS(StringValue, s);
        END;

        IF (RightJustify) THEN
            RJust(StringValue);
        END;
    END;

END FormatDataValue;



PROCEDURE GetBooleanChars ();
VAR
    s       : ARRAY [0..5] OF CHAR;
BEGIN
    GetMessage (ModuleNumber + 1, s);    (* "YN" *)     (* 16-Aug-91 PFG  Was TF.  New phrase added. *)
    TrueChar    := s[1];
    FalseChar   := s[2];
END GetBooleanChars;



BEGIN
    GetBooleanChars();
END FormatCommon.


