MODULE TLHR;

(*  Customized back-end 2-D printing module for histograms.
    Assumes an intermediate file containing resource-vs-time data, where
    the predicate is something like percent assigned or total dollars.

    MODIFICATION HISTORY

    21-Dec-88 LAA   Changed imports for Lazlo reorganization.
    23-Jan-89 RSC   Changed Storage to Space    .
    25-Apr-89 EGK   Put in LJust and TrimRear of predicate labels.  Moved
                    check of RowNumber > TotalRows in DoPage.
    10-Aug-89 KKC   Add copyright message.
    18-Sep-89 RSC   Removed AdjustScale.
    19-Sep-89 RSC   Fixed Kris' PMD bug where the new format FPercent
                    was causing a FatalError.
    20-Sep-89 KKC   Set buffer size to 255 if it is used by GetMessage.
    06-Oct-89 KKC   IF Header is set to First Page Only, print out header on
                    strip 1 only.
    20-Nov-89 KKC   IF footer is too long to fit on one line, truncate it.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo. 
    17-Jul-90 MWP   If using weeknumber date formatting, don't output
                    first date line. 
    22-Jan-91 RSC   Import AppendDurationUnit from LongDuration rather
                    than from TimeFormat.
    2-Jul-91  AJL - Added parameters to FilterNotes.
*)


FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTime;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, Error, FatalError, NotYetImplemented,
                                MultipleChoiceBox;

FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile, InterFileOpen;

FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  GetPos, SetPos;

FROM FlexStor               IMPORT
    (* PROC *)                  ArraySize;

FROM Gantt                  IMPORT
    (* TYPE *)                  ADStyle,
    (* VAR *)                   ChartFont,
    (* PROC *)                  DateLines, CheckScale;

FROM HistOptions           IMPORT
    (* VAR *)                   ReportSettings,
    (* PROC *)                  DoPrintDialog;

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

FROM LongDuration           IMPORT
    (* PROC *)                  AppendDurationUnit;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatLS, CtoS, RJust,
                                SubStr, ConcatS, Insert, Procustes,
                                Search, LJust, TrimRear, Remove, Copy,
                                LengthOf, SetLengthOf, Overlay, TrimFront;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM PrintCaptions          IMPORT
    (* PROC *)                  FilterNotes, PageHead;

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
    (* PROC *)                  SetHeapLevels, HeapAvailable,
                                ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, SIZE, TSIZE;

FROM TempFile               IMPORT
    (* PROC *)                  DeleteTempFile;

FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
    (* VAR *)                   DefaultDateAndTimeFormat,
    (* PROC *)                  TimeToString;

FROM TimeJump               IMPORT
    (* PROC *)                  FindStartDateOf, FindNextKeyDate;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit, ADate, ADuration, ATimeInfo,
    (* PROC *)                  TtoTimeU;

FROM Timeu                  IMPORT
    (* PROC *)                  UpScale;

FROM WeekNumberInfo      IMPORT                                (* 17-Jul-90 MWP *)
    (* VAR *)                   UsingWeekNumbers;

FROM Words                  IMPORT
    (* PROC *)                  StartOfWord;



CONST
    Normal                  = 0;
    Bold                    = 1;
    Zero                    = 0.0;
    ModuleNumber            = 24900;

    BlockChar               = 261C;     (* "±" *)
    AxisChar                = "-";
    GridChar                = ".";

TYPE
    AFilePosition   = ADDRESS;

    AHistogramSpec  = RECORD
                        MaxValue        : REAL;
                        MinValue        : REAL;
                        Precision       : REAL;
                        GridStep        : CARDINAL;
                        AxisNo          : CARDINAL;
                        RowCount        : CARDINAL;
                      END;

VAR
    TotalColumns            : CARDINAL;
    TotalDataColumns        : CARDINAL;
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

    KeyArray                : ARRAY [0..15] OF BITSET;
    ReportPeriod            : ADurationUnit;

    ErrorFlag               : BOOLEAN;
    EndReportHeaderPos      : CARDINAL;


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;



PROCEDURE GetFilePosition ( VAR Position    : AFilePosition );
BEGIN
    WITH Position DO
        GetPos (InterFile, SEGMENT, OFFSET);
    END;
END GetFilePosition;




PROCEDURE SetFilePosition ( Position    : AFilePosition );
BEGIN
    WITH Position DO
        SetPos (InterFile, SEGMENT, OFFSET);
    END;
END SetFilePosition;




PROCEDURE ResetSubfile  (   Subfile     : CARDINAL  );
VAR
    Version     : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput (InterFile, Subfile, Version)) THEN
    END;
END ResetSubfile;


PROCEDURE FindRecord    (    Type    : CARDINAL;
                         VAR Where   : AFilePosition  ) : BOOLEAN;

(*  Sets "Where" to the position in the intermediate file just AFTER the
    next record preface which is of the given type.  Iff the procedure
    returns TRUE, call ReadRecordBody to get the actual record contents.
*)

VAR
    Type2       : CARDINAL;
    Length      : CARDINAL;
BEGIN
    LOOP
        ReadRecordPreface (InterFile, Type2, Length);
        IF (CheckIO (InterFile) <> done) THEN
            RETURN FALSE;
        ELSIF (Type2 = Type) THEN
            GetFilePosition (Where);
            RETURN TRUE;
        ELSIF (Type2 = 0FFH) THEN
            RETURN FALSE;
        ELSE
            SkipRecordBody (InterFile, Length);
        END;
    END;
END FindRecord;




PROCEDURE GetOverallInfo();
VAR
    Type,
    Length      : CARDINAL;
    i           : CARDINAL;
    Data        : AnIntDataRecord;
    s           : ARRAY [0..80] OF CHAR;
    Where       : AFilePosition;

BEGIN
    IF (NOT StartFileInput (InterFile)) THEN
        RETURN;
    END;

    WITH AggregatorRecord DO
        Dimensions := {};
    END;

    ResetSubfile (OverallSubfileNumber);

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

    ResetSubfile (PredicateSubfileNumber);

    GetMessage (ModuleNumber+1, FooterTitle);     (* "TIME LINE Histogram Report showing" *)

    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            PredicateRecordType :

                ReadRecordBody (InterFile, Length,
                        ADR(PredicateRecord), SIZE(PredicateRecord));
                FOR i := 1 TO PredicateRecord.HeadingDepth DO
                    ReadIntData (Type, Data);
                    Copy (Data.LString, s);
                    LJust (s);                      (* 4/25/89 EGK *)
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

        (*  Look at the first date heading record to find out what
            time unit we are reporting on (days, weeks, etc.)
        *)

    ResetSubfile (4);
    IF (NOT FindRecord (HeadingRecordType, Where)) THEN
        ErrorFlag := TRUE;
        RETURN;
    END;
    SkipRecordBody (InterFile, TSIZE(AHeadingRecord));
    ReadIntData (Type, Data);
    ReportPeriod := VAL(ADurationUnit, Data.Cardinal);

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






    (*  Build the array that tells us where the "key" date columns are.
        These columns are determined by the beginning of all "words" in the
        string passed to us.
    *)

PROCEDURE MakeKeyArray  (   VAR Line        : ARRAY OF CHAR );
VAR
    i           : CARDINAL;
    WordNumber  : CARDINAL;
    BitNumber   : CARDINAL;
BEGIN
    FOR i := 0 TO 15 DO
        KeyArray[i] := BITSET{};
    END;

    (*  Assume that the "words" in the line passed are aligned exactly
        where we want the grid dots to be.  *)

    FOR i := 1 TO LengthOf(Line) DO
        IF (StartOfWord (Line, i, " ")) THEN
            WordNumber := i DIV 16;
            BitNumber  := i MOD 16;
            INCL (KeyArray[WordNumber], BitNumber);
        END;
    END;
END MakeKeyArray;



PROCEDURE PutDateLines      (   StartDate       : ADate;
                                Scale           : ADuration;
                                ScaleUnit       : ADurationUnit;
                                FirstColumn     : CARDINAL;
                                ColumnCount     : CARDINAL  );
VAR
    DateStyle       : ADStyle;
    DateArray       : ARRAY [0..1] OF ADate;
    Line1           : ARRAY [0..255] OF CHAR;
    Line2           : ARRAY [0..255] OF CHAR;
    Spaces          : ARRAY [0..40] OF CHAR;

BEGIN

    Fill (Spaces, " ", FirstColumn - 1);
    IF (ReportPeriod < Weeks) AND                                   (* 17-Jul-90 MWP *)
       (NOT UsingWeekNumbers) THEN
        DateStyle := YearMonth;
        DateLines (StartDate, ColumnCount, FirstColumn, Scale, ScaleUnit,
                   DateStyle, ChartFont, FALSE, Line1, Line2, DateArray);
    ELSE
        SetLengthOf (Line1, 0);
    END;
    Insert (Line1, Spaces, 1);
    PrintLine (Line1, Normal);

    CASE ReportPeriod OF
        Hours, Days :
            DateStyle := MonthDay;
    |   Weeks, Months, Years :
            DateStyle := YearMonth;
    ELSE
        FatalError();
    END;
    DateLines (StartDate, ColumnCount, FirstColumn, Scale, ScaleUnit,
               DateStyle, ChartFont, FALSE, Line1, Line2, DateArray);
    MakeKeyArray (Line2);
    Insert (Line1, Spaces, 1);
    Insert (Line2, Spaces, 1);
    PrintLine (Line1, Normal);
    PrintLine (Line2, Normal);

END PutDateLines;



    (* DoColumnHeaders --

        In this case, just put up the standard Time Line date scale.

    *)

PROCEDURE DoColumnHeaders ( StartDate       : ADate;
                            Scale           : ADuration;
                            ScaleUnit       : ADurationUnit;
                            SkipCount       : CARDINAL;
                            ColumnCount     : CARDINAL;
                            RowHeadings     : BOOLEAN   );
VAR
    FirstColumn         : CARDINAL;
    ExpandedColumns     : CARDINAL;
    NextDate            : ADate;

BEGIN

    FirstColumn := 1;
    IF (RowHeadings) THEN
        INC (FirstColumn, YDomainRecord.Width);
    END;

        (* Find the end of the last period. *)

    NextDate := StartDate + ColumnCount * Scale;
    NextDate := FindStartDateOf (NextDate, ScaleUnit);
    NextDate := FindNextKeyDate (NextDate, ScaleUnit);

        (*  Attempt to extend the date bar so that we don't end in the
            middle of a time period, even if the actual data does.    *)

    ExpandedColumns := FirstColumn - 1 + ((NextDate - StartDate) DIV Scale);
    IF (NOT ReportSettings^.ColumnSpec.Paged) OR
           (ExpandedColumns <= PageWidth()) THEN
        ColumnCount := ExpandedColumns - FirstColumn + 1;
    END;


    PutDateLines (StartDate, Scale, ScaleUnit, FirstColumn, ColumnCount);

END DoColumnHeaders;




PROCEDURE ReadTitleLine ( VAR s         : ARRAY OF CHAR );

VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    s2              : ARRAY [0..255] OF CHAR;
    TempFilePos     : AFilePosition;
    Length          : CARDINAL;
    HeadingRecord   : AHeadingRecord;

BEGIN
    GetFilePosition (TempFilePos);
    SetFilePosition (HeadingFilePos);

    IF (NOT FindRecord (HeadingRecordType, HeadingFilePos)) THEN
        GetMessage (ModuleNumber+7, s2);        (* "The intermediate file is corrupted" *)
        Error (s2);
        RETURN;
    END;
    ReadRecordBody (InterFile, SIZE(HeadingRecord), ADR(HeadingRecord),
                    SIZE(HeadingRecord));
    ReadIntData (Type, Data);
    Copy (Data.LString, s);

    GetFilePosition (HeadingFilePos);
    SetFilePosition (TempFilePos);

END ReadTitleLine;




PROCEDURE GetRealValue (    Type        : CARDINAL;
                        VAR Data        : AnIntDataRecord   ) : REAL;
BEGIN

    CASE Type OF
        RealNumberType :
            RETURN Data.Real;
    |   IntegerType :
            RETURN FLOAT(Data.Integer);
    |   CardinalType :
            RETURN FLOAT(Data.Cardinal);
    |   SkipRecordType :
            RETURN Zero;
    |   BooleanType :
            RETURN FLOAT(ORD(Data.Boolean));
    ELSE
            FatalError();
    END;

END GetRealValue;



PROCEDURE GetScaleValue (   RowNum          : CARDINAL;
                            HistSpec        : AHistogramSpec ) : REAL;
BEGIN
    WITH HistSpec DO
        RETURN (FLOAT(AxisNo) - FLOAT(RowNum)) * Precision;
    END;
END GetScaleValue;




    (* Print the numeric value corresponding to this histogram row. *)

PROCEDURE FormatScale   (    RowNum         : CARDINAL;
                             HistSpec       : AHistogramSpec;
                         VAR s              : ARRAY OF CHAR  );
VAR
    r                   : REAL;
    MinDigits           : CARDINAL;
    CurrencyFormat      : ACurrencyFormat;
    Format              : AFormat;
    String              : ARRAY [0..30] OF CHAR;
    s2                  : ARRAY [0..1] OF CHAR;
    Width               : CARDINAL;

BEGIN
    r         := GetScaleValue (RowNum, HistSpec);
    Format    := PredicateRecord.Format;
    Width     := LengthOf(s);
    MinDigits := ORD(Format.DecimalDigits);

    IF (Format.FormatType = FNumeric) OR
       (Format.FormatType = FPercent) OR           (* RSC 19-Sep-89 *)
       (Format.FormatType = FBoolean) THEN
        IF (Format.FormatType = FPercent) THEN     (* RSC 19-Sep-89 *)
            r := r * 100.0;
        END;
        FormatAsAmount (r, DefaultAmountFormat, String,
                        Width, 0, MinDigits, TRUE);
    ELSIF (Format.FormatType = FCurrency) THEN
        CurrencyFormat := DefaultCurrencyFormat;
        WITH CurrencyFormat DO
            MinTrailingDigits := MinDigits;
            MaxTrailingDigits := MinDigits;
        END;
        FormatAsCurrency (r, CurrencyFormat,
                          String, Width, TRUE, TRUE, FALSE);
    ELSE
        FatalError();
    END;
    TrimFront (String);
    SetString (s2, " ");
    Insert (String, s2, 1);
    Width := LengthOf(String);
    Overlay (s, String, LengthOf(s)-Width+1, Width);
END FormatScale;




PROCEDURE ColumnIsKey   (   Column  : CARDINAL  ) : BOOLEAN;
VAR
    WordNumber      : CARDINAL;
    BitNumber       : CARDINAL;
BEGIN
    WordNumber := Column DIV 16;
    BitNumber  := Column MOD 16;
    RETURN (BitNumber IN KeyArray[WordNumber]);
END ColumnIsKey;




PROCEDURE RowIsKey  (   HistSpec    : AHistogramSpec;
                        RowNum      : CARDINAL       ) : BOOLEAN;
BEGIN
    WITH HistSpec DO
        IF (GridStep = 0) OR (RowNum = AxisNo) THEN
            RETURN FALSE;
        ELSIF (RowNum < AxisNo) THEN
            RETURN (((AxisNo-RowNum) MOD GridStep) = 0);
        ELSE
            RETURN (((RowNum-AxisNo) MOD GridStep) = 0);
        END;
    END;
END RowIsKey;




PROCEDURE FormatSymbol  (    Type        : CARDINAL;
                         VAR Data        : AnIntDataRecord;
                             RowNum      : CARDINAL;
                             Column      : CARDINAL;
                             HistSpec    : AHistogramSpec;
                         VAR s           : ARRAY OF CHAR;
                         VAR Font        : CARDINAL          );
VAR
    r, Ref              : REAL;
    MakeSolid           : BOOLEAN;

BEGIN
    IF (RowNum = HistSpec.AxisNo) THEN         (* On the axis *)
        Fill (s, AxisChar, 1);
    ELSE
        r := GetRealValue (Type, Data);
        IF (RowNum < HistSpec.AxisNo) THEN
            Ref := GetScaleValue (RowNum+1, HistSpec);
            MakeSolid := (r > Ref);
        ELSE
            Ref := GetScaleValue (RowNum-1, HistSpec);
            MakeSolid := (r < Ref);
        END;
        IF (MakeSolid) THEN
            Fill (s, BlockChar, 1);
        ELSIF (ColumnIsKey (Column)) OR (RowIsKey (HistSpec,RowNum)) THEN
            Fill (s, GridChar, 1);
        ELSE
            SetString (s, " ");
        END;
    END;
    Font := Normal;
END FormatSymbol;





PROCEDURE PrintAHistogram ( VAR RowName         : ARRAY OF CHAR;
                                RowHeadings     : BOOLEAN;
                                BeforeSkip      : CARDINAL;
                                ColumnCount     : CARDINAL;
                                HistSpec        : AHistogramSpec );
VAR
    i,j             : CARDINAL;
    s               : ARRAY [0..40] OF CHAR;
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    Font            : CARDINAL;
    FilePosition    : AFilePosition;

BEGIN

    GetFilePosition (FilePosition);     (* Remember where we are now *)

    i := 1;
    WHILE (i <= HistSpec.RowCount) AND (NOT Stopped) DO

            (* Label each line with resource name and amount *)

        IF (RowHeadings) THEN
            j := YDomainRecord.Width;
            IF (i = 1) THEN
                Copy (RowName, s);
                Procustes (s, j);
            ELSE
                Fill (s, " ", j);
            END;
            FormatScale (i, HistSpec, s);
            PrintText (s, Normal);
        END;

        SetFilePosition (FilePosition);     (* Start at begining of line *)

        FOR j := 1 TO BeforeSkip DO
            ReadIntData (Type, Data);
        END;

        FOR j := 1 TO ColumnCount DO
            ReadIntData (Type, Data);
            FormatSymbol (Type, Data, i, j, HistSpec, s, Font);
            PrintText (s, Font);
        END;

        PrintLine (BlankLine, Normal);
        INC (i);
    END;
END PrintAHistogram;





    (*  Scan one line of the intermediate file, finding the statistics about
        this line's data (in HistSpec) and the position of the beginning
        of the next line (in FilePosition).
    *)

PROCEDURE ScanOneLine   ( VAR HistSpec      : AHistogramSpec;
                          VAR FilePosition  : AFilePosition     );
CONST
    Tolerance           = 0.01;     (* Use another line if we are 1% over *)
VAR
    TempFilePos         : AFilePosition;
    Max                 : REAL;
    Min                 : REAL;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;
    r                   : REAL;
    i                   : CARDINAL;
    PlusRows            : CARDINAL;
    MinusRows           : CARDINAL;

BEGIN
    GetFilePosition (TempFilePos);
    Max := Zero;
    Min := Zero;

    FOR i := 1 TO TotalDataColumns DO
        ReadIntData (Type, Data);
        r := GetRealValue (Type, Data);
        IF (r > Max) THEN
            Max := r;
        ELSIF (r < Min) THEN
            Min := r;
        END;
    END;

        (* Skip over any that are for row totals *)

    FOR i := 1 TO TotalColumns - TotalDataColumns DO
        ReadIntData (Type, Data);
    END;

    GetFilePosition (FilePosition);
    SetFilePosition (TempFilePos);

    WITH HistSpec DO
        MaxValue := Max;
        MinValue := Min;
        Precision := ReportSettings^.RowSpec.Precision;
        GridStep := ReportSettings^.RowSpec.GridStep;

        PlusRows := TRUNC(1.0 - Tolerance + (MaxValue / Precision));
        MinusRows := TRUNC(1.0 - Tolerance - (MinValue / Precision));
        RowCount := 1 + PlusRows + MinusRows;
        AxisNo := 1 + PlusRows;

    END;

END ScanOneLine;




PROCEDURE DoPage(   StripNumber     : CARDINAL;
                    PageNumber      : CARDINAL;
                    ColumnCount     : CARDINAL;
                VAR RowNumber       : CARDINAL;
                    StartDate       : ADate;
                    Scale           : ADuration;
                    ScaleUnit       : ADurationUnit;
                    RowHeaders      : BOOLEAN;
                    BeforeSkip      : CARDINAL;
                    AfterSkip       : CARDINAL;
                VAR Done            : BOOLEAN   );

VAR
    i                   : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;
    s2                  : ARRAY [0..40] OF CHAR;
    EndLines            : CARDINAL;
    NewDataFilePos      : AFilePosition;
    HistSpec            : AHistogramSpec;
    StartingRow         : CARDINAL;
    MultiPage           : BOOLEAN;

BEGIN

    IF (ReportSettings^.RowSpec.Paged) THEN
        AllowUnlimitedPageLength (FALSE);
    END;

    IF (
        ( (StripNumber = 1) AND (PageNumber = 1) )
        OR
        (ReportSettings^.RowSpec.RepeatHeaders)
       ) THEN
        PageHead();
        FilterNotes(TRUE,    (* Select Filters *)
                    FALSE);   (* no Highlight Filters *)
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

    IF (PageNumber = 1) OR (ReportSettings^.RowSpec.RepeatTitles) THEN
        DoColumnHeaders (StartDate, Scale, ScaleUnit,
                         BeforeSkip, ColumnCount, RowHeaders);
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

    StartingRow := RowNumber;
    MultiPage := FALSE;

    LOOP

        IF (RowNumber > TotalRows) OR (Stopped) THEN
            Done := TRUE;
            EXIT;
        END;

        (*  Look at all the data points for this resource, and save the
            position in the file of the first data record in the next row. *)

        ScanOneLine (HistSpec, NewDataFilePos);

        IF (RowsLeft() < EndLines + HistSpec.RowCount) THEN
            IF (RowNumber = StartingRow) THEN
                MultiPage := TRUE;
                AllowUnlimitedPageLength (TRUE);
            ELSE
                EXIT;                                   (* It won't fit! *)
            END;
        END;

        ReadTitleLine (s);      (* Get resource name *)

        PrintAHistogram (s, RowHeaders, BeforeSkip, ColumnCount,
                         HistSpec);
        ProgressMessage (s);

        SetFilePosition (NewDataFilePos);

            (* Print blank lines, as specified on the printing form *)

        i := ReportSettings^.RowSpec.Spacing;
        WHILE (i > 0) AND (RowsLeft() > EndLines) DO
            PrintLine (BlankLine, Normal);
            DEC(i);
        END;

        INC (RowNumber);

        (*  There are two conditions where we fall out early.
            1.  Paged printing, but one histogram was larger than a page.
            2.  Paged printing, but the user set the spacing between
                histograms to 0 (this means "one histogram per page").
        *)

        IF ((ReportSettings^.RowSpec.BreakEach) AND
                (ReportSettings^.RowSpec.Paged)) OR (MultiPage) THEN
            EXIT;
        END;

    END;

    IF (ReportSettings^.RowSpec.Paged) AND (NOT MultiPage) THEN
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
        CtoS (StripNumber, s2);
        ConcatLS (s, s2);
    END;

    IF (PageNumber > 1) OR (NOT Done) THEN
        ConcatMessage (s, ModuleNumber+3);      (* ", Page " *)
        CtoS (PageNumber, s2);
        ConcatLS (s, s2);
    END;
    ProgressMessage (s);

    IF (ReportSettings^.RowSpec.RepeatFooters) OR (Done) THEN
        PrintLine (BlankLine, Normal);
        IF ( LengthOf(s) > PageWidth() ) THEN   (* 20-Dec-89 KKC  *)
            Procustes(s, PageWidth() );
        END;
        PrintLine (s, Normal);
    END;
END DoPage;




PROCEDURE StartDateOfColumn (   Column  : CARDINAL  ) : ADate;
VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    OldFilePosition : AFilePosition;
    Where           : AFilePosition;
    StartDate       : ADate;
    TimeInfo        : ATimeInfo;
    i               : CARDINAL;

BEGIN

    GetFilePosition (OldFilePosition);
    ResetSubfile (4);

        (*  This loop just skips to the position of the first data record
            which will go on this page.     *)

    FOR i := 1 TO Column DO
        IF (NOT FindRecord (HeadingRecordType, Where)) THEN
            ErrorFlag := TRUE;
            RETURN 0;
        END;
        SkipRecordBody (InterFile, TSIZE(AHeadingRecord));
    END;

    ReadIntData (Type, Data);
    SetFilePosition (OldFilePosition);

    IF (Type = StartDateType) THEN
        StartDate := Data.Date;
    ELSIF (Type = BigStartTimeType) THEN
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
        IF (NOT TtoTimeU ( TimeInfo, StartDate)) THEN
            StartDate := 0;
        END;
    ELSE
        FatalError();
    END;

    RETURN StartDate;

END StartDateOfColumn;




PROCEDURE DoStrip (     StripNumber     : CARDINAL;
                        FirstDataColumn : CARDINAL;
                    VAR LastDataColumn  : CARDINAL  );

VAR
    Done            : BOOLEAN;
    PageNumber      : CARDINAL;
    NewWidth        : CARDINAL;
    FirstColumn     : CARDINAL;
    Columns         : CARDINAL;
    Count           : CARDINAL;
    BeforeSkip      : CARDINAL;
    AfterSkip       : CARDINAL;
    RowNumber       : CARDINAL;
    StartDate       : ADate;
    NextDate        : ADate;
    Scale           : ADuration;
    ScaleUnit       : ADurationUnit;
    RowHeadings     : BOOLEAN;
    More            : BOOLEAN;
    DateStyle       : ADStyle;
    DataColumns     : CARDINAL;
    ok              : BOOLEAN;

BEGIN

    IF (StripNumber > 1) AND (NOT ReportSettings^.ColumnSpec.Paged) THEN
        AllowLeftMargin (FALSE);
    END;

    RowHeadings := (StripNumber = 1) OR
                   (ReportSettings^.ColumnSpec.RepeatTitles);

    FirstColumn := 1;
    IF (RowHeadings) THEN
        INC (FirstColumn, YDomainRecord.Width);
    END;

    DataColumns := TotalDataColumns - FirstDataColumn + 1;
    StartDate := StartDateOfColumn (FirstDataColumn);
    BeforeSkip := FirstDataColumn - 1;

    More := (ReportSettings^.ColumnSpec.Paged) AND
            (FirstColumn - 1 + DataColumns > PageWidth());

    IF (More) THEN
        Count := PageWidth() - FirstColumn + 1;
    ELSE
        Count := DataColumns;
    END;

    Scale := UpScale (1, ReportPeriod);
    Columns := FirstColumn - 1 + Count;
    ok := CheckScale (Columns, FirstColumn, StartDate,
                      Scale, ScaleUnit, DateStyle);

    IF (More) THEN
        NextDate := StartDate + Count * Scale;
        NextDate := FindStartDateOf (NextDate, ScaleUnit);
        Count := (NextDate - StartDate) DIV Scale;
    END;

    AfterSkip := TotalColumns - BeforeSkip - Count;
    LastDataColumn := FirstDataColumn + Count - 1;

    ResetSubfile (3);       (* Row heading subfile *)
    GetFilePosition (HeadingFilePos);
    ResetSubfile (5);

    Done := FALSE;
    PageNumber := 1;
    RowNumber := 1;

    WHILE (NOT Done) AND (NOT Stopped) DO
        DoPage (StripNumber, PageNumber, Count, RowNumber, StartDate,
                Scale, ScaleUnit, RowHeadings, BeforeSkip, AfterSkip, Done);
        INC (PageNumber);
    END;

END DoStrip;




PROCEDURE OKToReduce (  ColumnsWanted       : CARDINAL;
                        ColumnsAvailable    : CARDINAL  ) : BOOLEAN;
VAR
    Selection           : CARDINAL;
    MenuString          : ARRAY [0..40] OF CHAR;
    Prefix              : ARRAY [0..30] OF CHAR;
    s                   : ARRAY [0..255] OF CHAR;
    Title               : ARRAY [0..255] OF CHAR;
    s2                  : ARRAY [0..10] OF CHAR;

BEGIN
    Selection := 1;
    GetMessage (ModuleNumber+10, s);            (* "You have requested " *)
    CtoS (ColumnsWanted, s2);
    ConcatLS (s, s2);                           (* <number> *)
    ConcatS (s, " ");
    AppendDurationUnit (s, ReportPeriod, TRUE);     (* <units> *)
    ConcatMessage (s, ModuleNumber+11);         (* ", but only " *)
    CtoS (ColumnsAvailable, s2);
    ConcatLS (s, s2);
    ConcatMessage (s, ModuleNumber+12);         (* " are available." *)
    GetMessage (ModuleNumber+13, MenuString);   (* "Proceed,Cancel" *)
    GetMessage (ModuleNumber+14, Title);        (* "Histogram too big" *)
    SetLengthOf (Prefix, 0);

    RETURN (MultipleChoiceBox (s, Title, NoHelp, Prefix, MenuString,
            Selection)) AND (Selection = 1);
END OKToReduce;






PROCEDURE DoReport();

CONST
    MaxColumns          = 250;      (* Includes fudge factor *)
    SpaceForNumbers     = 7;        (* Columns reserved for vertical grid numbers *)
VAR
    FirstColumn         : CARDINAL;
    StripNumber         : CARDINAL;
    LastColumn          : CARDINAL;
    ColumnsAvailable    : CARDINAL;
    Copyright           : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetLengthOf (BlankLine, 0);
    ErrorFlag := FALSE;
    GetOverallInfo();

    INC (YDomainRecord.Width, SpaceForNumbers);      (* Make room for the amounts *)

    TotalRows := DimensionCount(1);
    TotalColumns := DimensionCount(2);
    ColumnsAvailable := MaxColumns - YDomainRecord.Width;
    IF (TotalColumns > ColumnsAvailable) THEN
        IF NOT (OKToReduce (TotalColumns, ColumnsAvailable)) THEN
            RETURN;
        END;
        TotalDataColumns := ColumnsAvailable;
    ELSE
        TotalDataColumns := TotalColumns;
        IF (2 IN AggregatorRecord.Dimensions) THEN
            DEC (TotalDataColumns);
        END;
    END;

    IF (NOT StartReport()) THEN
        RETURN;
    END;

    IF (NOT ReportSettings^.RowSpec.Paged) THEN
        AllowUnlimitedPageLength (TRUE);
    END;

    StripNumber := 1;
    LastColumn := 0;

    WHILE (LastColumn < TotalDataColumns) AND (NOT Stopped) DO
        FirstColumn := LastColumn + 1;
        DoStrip (StripNumber, FirstColumn, LastColumn);
        INC (StripNumber);
    END;

    EndReport;
END DoReport;



BEGIN
    IF HeapAvailable() AND DoPrintDialog() THEN
        DoReport();
    END;
    DeleteTempFile (InterFile);
    InterFileOpen := FALSE;
END TLHR.

