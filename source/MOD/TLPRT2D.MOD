MODULE TLPrt2D;

(*  Generic printing module for tabular reports of one and two dimensions.
   RSC 9/16/88 - remove kluge where DeleteTempFile had to be called.
   RSC 11/9/88 - I had left a reference to setting InterFileOpen to FALSE.
   LAA 21-Dec-88 - Changed imports for Lazlo reorganization.
   RSC 10-Jan-89 - Changed Storage to Space.
   25-Apr-89 EGK   Put in LJust and TrimRear of predicate labels.
   AJL 21-Jun-89   Added format type FPercent.
   22-Jun-89 KKC   Check PageWidth in DoStrip if not Unlimited page width
                   set to YES or not output to Disk.
   4-Jul-89  KKC   In DoPage, Stop when RowsLeft <= EndLines instead of
                   RowsLeft < EndLines
   10-Aug-89 KKC   Add copyright message.
   23-Aug-89 EGK   Changed DoColumnHeaders so that it always prints a
                   single line of headings.
   18-Sep-89 KKC   Pass NDecimalDigits as max and min digits to FormatAsAmount.
   06-Oct-89 KKC   IF Header is set to First Page Only, print out header on
                   strip 1 only.
   30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
   19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                   date structure, ATimeInfo. 
   AJL  3-Jul-91 Added UsesSelectFilter and UsesHighlightFilter to 
                 OverallRecord.  Pass to FilterNotes.
   TGS  3-Sep-91 After printing a data item, check to see if it is the last
                 item on that line. If so, then don't print spaces between it
                 and the (nonexistent) item to its right. Not doing so causes
                 unintentional "wraparound" to the next line. Bug 5025.
*)


FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTime;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, NotYetImplemented;

FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile, InterFileOpen;

FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  GetPos, SetPos;

FROM FlexStor               IMPORT
    (* PROC *)                  ArraySize;

FROM IntFileIO              IMPORT
    (* CONST *)                 OverallSubfileNumber, PredicateSubfileNumber,
                                TextType, RealNumberType, IntegerType,
                                CardinalType, BooleanType,
                                BigStartTimeType, BigEndTimeType,
                                StartDateType, EndDateType,
                                EnumeratedType, PredicateRecordType,
                                HeadingRecordType, AggregatorRecordType,
                                SkipRecordType,
    (* TYPE *)                  AnOverallRecord, APredicateHeadingRecord,
                                ADomainRecord, APredicateRecord,
                                AHeadingRecord, AnAggregatorRecord,
                                AnIntDataRecord, AFormat, AFormatType,
    (* PROC *)                  ReadIntData;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatLS, CtoS, RJust,
                                SubStr, ConcatS, Insert, Procustes,
                                Search, LJust, TrimRear, Remove, Copy,
                                LengthOf, SetLengthOf, Overlay;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM PrintCaptions          IMPORT
    (* PROC *)                  FilterNotes, PageHead;

FROM PrintOptions           IMPORT
    (* VAR *)                   ReportSettings,
    (* PROC *)                  DoPrintDialog;

FROM PrintStatic            IMPORT
    (* TYPE  *)                 APrinterStyle,
    (* VAR   *)                 PrintCB;

FROM PrintSupport           IMPORT
    (* VAR *)                   Stopped,
    (* PROC *)                  RowsLeft, PageWidth, PageTop, StartReport,
                                StartPage, EndReport, PrintLine, PrintText,
                                AllowUnlimitedPageLength, ProgressMessage,
                                AllowLeftMargin, GetCurrentPrintRow;

FROM RealFormat             IMPORT
    (* TYPE *)                  ACurrencyFormat,
    (* VAR *)                   DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROC *)                  FormatAsAmount, FormatAsCurrency;

FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecord, ReadRecordPreface, ReadRecordBody;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE, SIZE;

FROM TempFile               IMPORT
    (* PROC *)                  DeleteTempFile;

FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
    (* VAR *)                   DefaultDateAndTimeFormat,
    (* PROC *)                  TimeToString, TimeUtoS, FormatAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit, ATimeInfo;



CONST
    Normal                  = 0;
    Bold                    = 1;
    Zero                    = 0.0;
    ModuleNumber            = 21500;

TYPE
    AFilePosition   = RECORD
                        High, Low       : CARDINAL;
                      END;

VAR
    TotalColumns            : CARDINAL;
    TotalRows               : CARDINAL;
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    PredicateRecord         : APredicateRecord;
    XDomainRecord           : ADomainRecord;
    YDomainRecord           : ADomainRecord;
    AggregatorRecord        : AnAggregatorRecord;
    BlankLine               : ARRAY [0..1] OF CHAR;
    HeadingFilePos          : AFilePosition;
    FooterTitle             : ARRAY [0..255] OF CHAR;
    EndReportHeaderPos      : CARDINAL;


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;



PROCEDURE AppropriateTimeFormat (       TimeUnit        : ADurationUnit;
                                    VAR TimeFormat      : ATimeFormat;
                                    VAR Exact           : BOOLEAN       );
VAR
    i               : CARDINAL;
    MaxUnit         : ADurationUnit;

BEGIN
    TimeFormat := DefaultDateAndTimeFormat;
    MaxUnit := Minutes;
    FOR i := 0 TO 4 DO
        IF (TimeFormat[i].Unit <= TimeUnit) AND (TimeFormat[i].Unit > MaxUnit) THEN
            MaxUnit := TimeFormat[i].Unit;
        END;
    END;
    FOR i := 0 TO 4 DO
        IF (TimeFormat[i].Unit < MaxUnit) THEN
            IF (TimeFormat[i].Unit <> Minutes) OR (MaxUnit <> Hours) THEN
                TimeFormat[i].Size := 0;
                SetLengthOf (TimeFormat[i].FollowBy, 0);
            END;
        END;
    END;
    Exact := (MaxUnit = TimeUnit);
END AppropriateTimeFormat;



PROCEDURE ConvertToString   (     Type          : CARDINAL;
                              VAR Data          : AnIntDataRecord;
                                  Format        : AFormat;
                                  Width         : CARDINAL;
                              VAR String        : ARRAY OF CHAR;
                                  FirstLine     : BOOLEAN           );
VAR
    r           : REAL;
    NDecimalDigits   : CARDINAL;
    TimeFormat          : ATimeFormat;
    CurrencyFormat      : ACurrencyFormat;
    Exact               : BOOLEAN;
    TimeInfo            : ATimeInfo;

BEGIN

    CASE Type OF
        TextType, BooleanType, EnumeratedType :
            Copy (Data.LString, String);

    |   RealNumberType, IntegerType, CardinalType :
            CASE Type OF
                RealNumberType :
                    r := Data.Real;
            |   IntegerType :
                    r := FLOAT(Data.Integer);
            |   CardinalType :
                    r := FLOAT(Data.Cardinal);
            ELSE
                    FatalError();
            END;

            IF (r = Zero) AND (NOT ReportSettings^.PrintZeros) THEN
                Fill (String, " ", Width);
                RETURN;
            END;

            NDecimalDigits := ORD(Format.DecimalDigits);

            CASE Format.FormatType OF
                FNumeric :
                    FormatAsAmount (r, DefaultAmountFormat, String,
                                    Width, NDecimalDigits, NDecimalDigits,
                                    TRUE);
            |   FPercent :
                    FormatAsAmount (r * 100.0, DefaultAmountFormat, String,
                                    Width, NDecimalDigits, NDecimalDigits,
                                    TRUE);
            |   FCurrency :
                    CurrencyFormat := DefaultCurrencyFormat;
                    WITH CurrencyFormat DO
                        MinTrailingDigits := NDecimalDigits;
                        MaxTrailingDigits := NDecimalDigits;
                    END;
                    FormatAsCurrency (r, CurrencyFormat,
                                      String, Width, TRUE, TRUE, FALSE);
            ELSE
                    Fill (String, "?", Width);
            END;

    |   BigStartTimeType, BigEndTimeType, StartDateType, EndDateType :
            AppropriateTimeFormat (VAL(ADurationUnit,Data.Cardinal), TimeFormat, Exact);
            IF  (* (Exact) AND *)  (NOT FirstLine) THEN     (* 8/23/89 EGK *)
                Fill (String, " ", Width);
            ELSE
                CASE Type OF
                    BigStartTimeType, BigEndTimeType :
                        BigTimeToTime
                        (
                            Data.BigTime,
                            TimeInfo.tiYear,
                            TimeInfo.tiMonth,
                            TimeInfo.tiDay,
                            TimeInfo.tiHour,
                            TimeInfo.tiMinute,
                            TimeInfo.tiSecond
                        );
                        TimeToString (TimeInfo, TimeFormat, String);
                |   StartDateType :
                        TimeUtoS (Data.Date, String);
                |   EndDateType :
                        FormatAsEndDateStyle (Data.Date, String);
                ELSE
                        FatalError();
                END;
            END;

    |   SkipRecordType :
            Fill (String, " ", Width);

    ELSE
            FatalError();
    END;
END ConvertToString;




PROCEDURE GetOverallInfo();
VAR
    Version     : CARDINAL;
    Type,
    Length      : CARDINAL;
    i           : CARDINAL;
    Data        : AnIntDataRecord;
    s           : ARRAY [0..80] OF CHAR;

BEGIN
    IF (NOT StartFileInput (InterFile)) THEN
        RETURN;
    END;

    WITH AggregatorRecord DO
        Dimensions := {};
    END;

    IF (NOT StartSubfileInput (InterFile, OverallSubfileNumber, Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface (InterFile, Type, Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            1 :
                ReadRecordBody (InterFile, Length,
                        ADR(OverallRecord), SIZE(OverallRecord));
        |   2 :
                ReadRecordBody (InterFile, Length,
                        ADR(PredicateHeadingRecord),
                        SIZE(PredicateHeadingRecord));
        |   3 :
                ReadRecordBody (InterFile, Length,
                        ADR(YDomainRecord), SIZE(YDomainRecord));

        |   4 :
                ReadRecordBody (InterFile, Length,
                        ADR(XDomainRecord), SIZE(XDomainRecord));
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;

    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        RETURN;
    END;

    GetMessage (ModuleNumber+1, FooterTitle);     (* "TIME LINE " *)
    ConcatLS (FooterTitle, OverallRecord.ReportName);

    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            PredicateRecordType :

                ReadRecordBody (InterFile, Length,
                        ADR(PredicateRecord), SIZE(PredicateRecord));
                ConcatMessage (FooterTitle, ModuleNumber+4);    (* " showing" *)
                FOR i := 1 TO PredicateRecord.HeadingDepth DO
                    ReadIntData (Type, Data);
                    ConvertToString (Type, Data, PredicateRecord.Format,
                                     YDomainRecord.Width, s, TRUE);
                    LJust (s);                  (* 4/25/89 EGK *)
                    TrimRear (s);
                    ConcatS (FooterTitle, " ");
                    ConcatLS (FooterTitle, s);
                END;

        |   AggregatorRecordType :
                ReadRecordBody (InterFile, Length,
                        ADR(AggregatorRecord), SIZE(AggregatorRecord));

        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;

END GetOverallInfo;





PROCEDURE DimensionCount ( DimensionNumber : CARDINAL ) : CARDINAL;

(*  Return the number of items in the selected dimension.  For now,
    1   = vertical
    2   = horizontal
*)

VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
    HeadingRecord       : AHeadingRecord;
    Count               : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput (InterFile, 2+DimensionNumber, Version)) THEN
        RETURN 0;
    END;

    Count := 0;
    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            HeadingRecordType :
                ReadRecordBody (InterFile, Length,
                        ADR(HeadingRecord), SIZE(HeadingRecord));
                INC (Count);
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;
    RETURN Count;
END DimensionCount;



PROCEDURE ReadTitleLine ( VAR s         : ARRAY OF CHAR;
                          VAR Font      : CARDINAL      );
VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    High, Low       : CARDINAL;
    Format          : AFormat;

BEGIN
    GetPos (InterFile, High, Low);
    SetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

    ReadIntData (Type, Data);
    Font := ORD(Data.Font);
    IF (Font > 127) THEN
        Format := AggregatorRecord.Format;
        DEC (Font, 128);
    ELSE
        Format := PredicateRecord.Format;
    END;
    ConvertToString (Type, Data, Format, YDomainRecord.Width, s, TRUE);

    GetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);
    SetPos (InterFile, High, Low);
END ReadTitleLine;



PROCEDURE ReadHeadingRecord ( VAR HeadingRecord : AHeadingRecord );
VAR
    Type            : CARDINAL;
    Length          : CARDINAL;
    TempFilePos     : AFilePosition;

BEGIN
    (* Save our current position, then reposition ourself
       in the headings subfile *)

    GetPos (InterFile, TempFilePos.High, TempFilePos.Low);
    SetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

    ReadRecordPreface (InterFile, Type, Length);
    ReadRecordBody (InterFile, Length, ADR(HeadingRecord), SIZE(HeadingRecord));

    GetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);
    SetPos (InterFile, TempFilePos.High, TempFilePos.Low);
END ReadHeadingRecord;



PROCEDURE PutIndentation  ( VAR s       : ARRAY OF CHAR;
                                Indent  : CARDINAL;
                                Width   : CARDINAL      );
CONST
    SpacesPerLevel      = 2;
VAR
    s2          : ARRAY [0..99] OF CHAR;

BEGIN
    Procustes (s, Width);
    Fill (s2, " ", Indent * SpacesPerLevel);
    ConcatLS (s2, s);
    SetLengthOf (s2, Width);
    Copy (s2, s);
END PutIndentation;



PROCEDURE PageBreakNeeded   (   CurrentLevel    : CARDINAL ) : BOOLEAN;

VAR
    NextLevel       : CARDINAL;
    Threshold       : CARDINAL;
    HeadingRecord   : AHeadingRecord;
    Type            : CARDINAL;
    Length          : CARDINAL;
    TempFilePos     : AFilePosition;
    Result          : BOOLEAN;

BEGIN
    IF (ReportSettings^.PageBreakLevel < 1) THEN
        RETURN FALSE;
    END;

    (* Take a peek at the next heading record to get its level, but don't
       update the file marker.  *)

    GetPos (InterFile, TempFilePos.High, TempFilePos.Low);
    SetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

    ReadRecordPreface (InterFile, Type, Length);
    IF (Type = 0FFH) THEN
        Result := FALSE;
    ELSE
        ReadRecordBody (InterFile, Length, ADR(HeadingRecord), SIZE(HeadingRecord));
        NextLevel := HeadingRecord.DataIndentation;
        Threshold := ReportSettings^.PageBreakLevel - 1;
        Result := ((NextLevel <= Threshold) AND (Threshold <= CurrentLevel))
                    OR (NextLevel = Threshold);
    END;

    SetPos (InterFile, TempFilePos.High, TempFilePos.Low);
    RETURN Result;
END PageBreakNeeded;



PROCEDURE DoColumnHeaders ( SkipCount       : CARDINAL;
                            ColumnCount     : CARDINAL;
                            RowHeadings     : BOOLEAN   );
VAR
    RowNum          : CARDINAL;
    ColumnNum       : CARDINAL;
    Version         : CARDINAL;
    i, j            : CARDINAL;
    Type            : CARDINAL;
    Length          : CARDINAL;
    HeadingRecord   : AHeadingRecord;
    s               : ARRAY [0..255] OF CHAR;
    Space           : ARRAY [0..255] OF CHAR;
    Data            : AnIntDataRecord;
    OldPosition     : AFilePosition;



BEGIN
    GetPos (InterFile, OldPosition.High, OldPosition.Low);
    Fill (Space, " ", ReportSettings^.ColumnSpec.Spacing);
(*
    FOR RowNum := 1 TO XDomainRecord.HeadingDepth DO
*)
    RowNum := 1;            (* 8/23/89 EGK *)

        IF (NOT StartSubfileInput (InterFile, 4, Version)) THEN
            RETURN;
        END;

        IF (RowHeadings) THEN
            Fill (s, " ", YDomainRecord.Width + ReportSettings^.ColumnSpec.Spacing);
            PrintText (s, Normal);
        END;

        i := 0;
        LOOP
            ReadRecordPreface (InterFile, Type, Length);
            IF (CheckIO(InterFile) <> done) THEN EXIT; END;

            CASE Type OF

                HeadingRecordType :

                    ReadRecordBody (InterFile, Length, ADR(HeadingRecord),
                            SIZE(HeadingRecord));
                    INC (i);

                    IF (i = TotalColumns) AND (2 IN AggregatorRecord.Dimensions) THEN
                        PrintText (Space, Normal);
                    END;

                    IF (i > SkipCount) THEN
                        FOR j := 1 TO HeadingRecord.HeadingDepth DO
                            ReadIntData (Type, Data);
                            IF (j = RowNum) THEN
                                ConvertToString (Type, Data, PredicateRecord.Format,
                                                 PredicateRecord.Width, s, (j=1));
                                Procustes (s, PredicateRecord.Width);
                                IF (PredicateRecord.DataType IN
                                        {RealNumberType, IntegerType, CardinalType}) THEN
                                    RJust (s);
                                END;
                                PrintText (s, Normal);
                                IF (i < SkipCount + ColumnCount) THEN (* 3-Sep-91 TGS *)
                                    PrintText (Space, Normal);
                                END;
                            END;
                        END;
                    END;

                    IF (i >= SkipCount + ColumnCount) THEN
                        EXIT;
                    END;

            |   0FFH :
                    EXIT;
            ELSE
                SkipRecordBody (InterFile, Length);
            END;
        END;
        PrintLine (BlankLine, Normal);
(*
    END;
*)

    IF (RowHeadings) THEN
        Fill (s, " ", YDomainRecord.Width + ReportSettings^.ColumnSpec.Spacing);
        PrintText (s, Normal);
    END;

    Fill (s, "-", PredicateRecord.Width);
    FOR i := 1 TO ColumnCount - 1 DO
        PrintText (s, Normal);
        PrintText (Space, Normal);
    END;
    IF (2 IN AggregatorRecord.Dimensions) AND
            (SkipCount + ColumnCount = TotalColumns) THEN
        PrintText (Space, Normal);
    END;
    PrintText (s, Normal);
    PrintLine (BlankLine, Normal);
    SetPos (InterFile, OldPosition.High, OldPosition.Low);
END DoColumnHeaders;




PROCEDURE DoPage(   StripNumber     : CARDINAL;
                    PageNumber      : CARDINAL;
                    ColumnCount     : CARDINAL;
                VAR RowNumber       : CARDINAL;
                    BeforeSkip      : CARDINAL;
                    AfterSkip       : CARDINAL;
                VAR Done            : BOOLEAN   );

VAR
    i               : CARDINAL;
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    s               : ARRAY [0..255] OF CHAR;
    Space           : ARRAY [0..255] OF CHAR;
    EndLines        : CARDINAL;
    Column          : CARDINAL;
    PrintRowHeadings    : BOOLEAN;
    Font                : CARDINAL;
    Format              : AFormat;
    HeadingRecord       : AHeadingRecord;


    PROCEDURE PrintAggregatorLines();
    BEGIN
        IF (PrintRowHeadings) THEN
            Fill (s, " ", YDomainRecord.Width + ReportSettings^.ColumnSpec.Spacing);
            PrintText (s, Normal);
        END;
        Fill (s, "=", PredicateRecord.Width);
        FOR i := 1 TO ColumnCount - 1 DO
            PrintText (s, Normal);
            PrintText (Space, Normal);
        END;
        IF (2 IN AggregatorRecord.Dimensions) AND (AfterSkip = 0) THEN
            PrintText (Space, Normal);
        END;
        PrintText (s, Normal);
        PrintLine (BlankLine, Normal);
        FOR i := 1 TO ReportSettings^.RowSpec.Spacing - 1 DO
            PrintLine (BlankLine, Normal);
        END;
    END PrintAggregatorLines;


BEGIN

    IF (
        ( (StripNumber = 1) AND (PageNumber = 1) )
        OR
        (ReportSettings^.RowSpec.RepeatHeaders)
       ) THEN
        PageHead();
        FilterNotes(OverallRecord.UsesSelectFilter, OverallRecord.UsesHighlightFilter);
        EndReportHeaderPos := GetCurrentPrintRow();
    ELSE
        StartPage;
        IF (PageNumber = 1) THEN
            SetLengthOf( s, 0 );
            i := GetCurrentPrintRow();
            WHILE ( i < EndReportHeaderPos ) DO
                PrintLine( s, Normal);
                INC(i);
            END;
        END;
    END;

    PrintRowHeadings := (StripNumber = 1) OR
                        (ReportSettings^.ColumnSpec.RepeatTitles);

    IF (PageNumber = 1) OR (ReportSettings^.RowSpec.RepeatTitles) THEN
        DoColumnHeaders (BeforeSkip, ColumnCount, PrintRowHeadings);
    END;

    IF (ReportSettings^.RowSpec.RepeatFooters) THEN
        EndLines := 2;
    ELSE
        EndLines := 0;
    END;

    IF (RowsLeft() <= EndLines) AND (NOT Stopped) THEN
        GetMessage (ModuleNumber+5, s);     (* "Not enough room on the page" *)
        Error (s);
        Stopped := TRUE;
        RETURN;
    END;

    Column := 1;
    Fill (Space, " ", ReportSettings^.ColumnSpec.Spacing);

    LOOP

        IF (RowsLeft() <= EndLines + YDomainRecord.HeadingDepth) OR (Stopped) THEN
            EXIT;
        END;

        IF (RowNumber > TotalRows) THEN
            Done := TRUE;
            EXIT;
        END;

        IF (RowNumber = TotalRows) AND (Column = 1) AND
                (1 IN AggregatorRecord.Dimensions) THEN
            IF (RowsLeft() <= EndLines + YDomainRecord.HeadingDepth +
                                        ReportSettings^.RowSpec.Spacing) THEN
                EXIT;
            ELSE
                PrintAggregatorLines();
            END;
        END;

        ReadIntData (Type, Data);
        IF (Type = 0FFH) THEN
            Done := TRUE;
            EXIT;
        END;

        IF (Column = TotalColumns) AND (2 IN AggregatorRecord.Dimensions)
                    AND (Column <= TotalColumns - AfterSkip) THEN
            Space[1] := "|";
            PrintText (Space, Normal);
            Space[1] := " ";
        END;

        IF (Column = BeforeSkip + 1) THEN
            ReadHeadingRecord (HeadingRecord);
            ReadTitleLine (s, Font);
            IF (PrintRowHeadings) THEN
                PutIndentation (s, HeadingRecord.DataIndentation,
                                    YDomainRecord.Width);
                PrintText (s, Font);
                PrintText (Space, Normal);
            END;
        END;


        (* Don't print the data unless it falls within our range *)

        IF (Column > BeforeSkip) AND (Column <= TotalColumns-AfterSkip) THEN
            i := Column - BeforeSkip - 1;
            Font := ORD(Data.Font);
            IF (Font > 127) THEN
                Format := AggregatorRecord.Format;
                DEC (Font, 128);
            ELSE
                Format := PredicateRecord.Format;
            END;
            ConvertToString (Type, Data, Format, PredicateRecord.Width, s, TRUE);
            Procustes (s, PredicateRecord.Width);
            PrintText (s, Font);
            IF (Column < TotalColumns-AfterSkip) THEN (* 3-Sep-91 TGS *)
                PrintText (Space, Normal);
            ELSIF (AggregatorRecord.Dimensions * BITSET{1,2} = BITSET{1,2}) AND
               (HeadingRecord.DataIndentation = 0) AND (Type <> SkipRecordType) THEN
                SetString (s, "*");
                PrintText (s, Font);
            END;

        END;

        INC (Column);
        IF (Column > TotalColumns) THEN     (* Get ready for a new line *)
            Column := 1;

            PrintLine (BlankLine, Normal);
            FOR i := 2 TO YDomainRecord.HeadingDepth DO
                ReadTitleLine (s, Font);
                PutIndentation (s, HeadingRecord.DataIndentation,
                                YDomainRecord.Width);
                PrintLine (s, Font);
            END;


            (* Will the next transition between levels cause a page break? *)

            IF (ReportSettings^.RowSpec.Paged) AND
                    (PageBreakNeeded (HeadingRecord.DataIndentation)) THEN
                EXIT;
            END;


            (* Print blank lines, as specified on the printing form *)

            i := ReportSettings^.RowSpec.Spacing;
            WHILE (i > 1) AND (RowsLeft() > EndLines) DO
                PrintLine (BlankLine, Normal);
                DEC(i);
            END;

            INC (RowNumber);
        END;

    END;

    IF (ReportSettings^.RowSpec.Paged) THEN
        IF (Done) THEN
            EndLines := 2;      (* The last page must have a footer *)
        END;
        WHILE (RowsLeft() > EndLines) DO
            PrintLine (BlankLine, Normal);
        END;
    END;


    Copy (FooterTitle, s);

    IF (StripNumber > 1) OR (AfterSkip > 0) THEN
        ConcatMessage (s, ModuleNumber+2);      (* ", Strip " *)
        CtoS (StripNumber, Space);
        ConcatLS (s, Space);
    END;

    IF (PageNumber > 1) OR (NOT Done) THEN
        ConcatMessage (s, ModuleNumber+3);      (* ", Page " *)
        CtoS (PageNumber, Space);
        ConcatLS (s, Space);
    END;
    ProgressMessage (s);

    IF (ReportSettings^.RowSpec.RepeatFooters) OR (Done) THEN
        PrintLine (BlankLine, Normal);
        PrintLine (s, Normal);
    END;
END DoPage;



PROCEDURE DoStrip (     StripNumber     : CARDINAL;
                        FirstColumn     : CARDINAL;
                    VAR LastColumn      : CARDINAL  );
CONST
    MaxPageWidth    =   7FFFH;
VAR
    Done            : BOOLEAN;
    PageNumber      : CARDINAL;
    NewWidth        : CARDINAL;
    Column          : CARDINAL;
    Count           : CARDINAL;
    i               : CARDINAL;
    Width           : CARDINAL;
    BeforeSkip      : CARDINAL;
    AfterSkip       : CARDINAL;
    Version         : CARDINAL;
    RowNumber       : CARDINAL;
    MaxWidth        : CARDINAL;

BEGIN

    IF (StripNumber > 1) AND (NOT ReportSettings^.ColumnSpec.Paged) THEN
        AllowLeftMargin (FALSE);
    END;

    Count := 0;
    Width := 0;
    Column := 0;
    IF (StripNumber = 1) OR (ReportSettings^.ColumnSpec.RepeatTitles) THEN
        Width := YDomainRecord.Width + ReportSettings^.ColumnSpec.Spacing;
    END;

    IF ( (NOT ReportSettings^.ColumnSpec.Paged)
            AND
         (PrintCB.Style = OutToDisk) ) THEN
        MaxWidth := MaxPageWidth;
    ELSE
        MaxWidth := PageWidth();
    END;

    LOOP
        INC (Column);
        IF (Column >= FirstColumn) THEN

            NewWidth := Width + PredicateRecord.Width +
                        ReportSettings^.ColumnSpec.Spacing;

            IF (Column = TotalColumns) AND (2 IN AggregatorRecord.Dimensions) THEN
                INC (NewWidth, ReportSettings^.ColumnSpec.Spacing);
            END;

            IF (NewWidth <= MaxWidth) THEN   (* KKC - Jun 22, 1989 *)
                INC (Count);
                Width := NewWidth;
            ELSIF (Column = FirstColumn) THEN
                INC (Count);
                Width := PageWidth();
                EXIT;
            ELSE
                DEC (Column);
                EXIT;
            END;
        END;
        IF (Column >= TotalColumns) THEN
            EXIT;
        END;
    END;

    LastColumn := Column;

    IF (NOT StartSubfileInput (InterFile, 3, Version)) THEN
        RETURN;
    END;
    GetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

    IF (NOT StartSubfileInput (InterFile, 5, Version)) THEN
        RETURN;
    END;

    Done := FALSE;
    PageNumber := 1;
    BeforeSkip := FirstColumn - 1;
    AfterSkip := TotalColumns - LastColumn;
    RowNumber := 1;

    WHILE (NOT Done) AND (NOT Stopped) DO
        DoPage (StripNumber, PageNumber, Count, RowNumber,
                BeforeSkip, AfterSkip, Done);
        INC (PageNumber);
    END;

END DoStrip;




PROCEDURE DoReport();
VAR
    FirstColumn     : CARDINAL;
    StripNumber     : CARDINAL;
    LastColumn      : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (NOT StartReport()) THEN
        RETURN;
    END;

    SetLengthOf (BlankLine, 0);
    GetOverallInfo();

    IF (NOT ReportSettings^.RowSpec.Paged) THEN
        AllowUnlimitedPageLength (TRUE);
    END;

    TotalRows := DimensionCount(1);
    TotalColumns := DimensionCount(2);

    StripNumber := 1;
    LastColumn := 0;

    WHILE (LastColumn < TotalColumns) AND (NOT Stopped) DO
        FirstColumn := LastColumn + 1;
        DoStrip (StripNumber, FirstColumn, LastColumn);
        INC (StripNumber);
    END;

    EndReport;
END DoReport;



BEGIN
    IF HeapAvailable() AND DoPrintDialog(2) THEN
        DoReport();
    END;
    DeleteTempFile (InterFile);
    InterFileOpen := FALSE;
END TLPrt2D.

