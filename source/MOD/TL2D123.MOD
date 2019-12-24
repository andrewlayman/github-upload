MODULE TL2D123;

(*  Generic printing module for tabular reports of one and two dimensions.  *)

    (*  MODIFICATION HISTORY
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        23-Jan-89 RSC   Changed Storage to Space    .
        18-May-89 MWP   Added translation of Boolean values.
        06-Jul-89 MWP   Added support for Percentage record types as per
                        Andrews changes.
        30-Jul-89 MWP   Format 123 header data so that it aligns properly.
        10-Aug-89 KKC   Add copyright message.
        23-Aug-89 EGK   Changed DoColumnHeaders so that it always prints a
                        single line of headings.
         1-Sep-89 MWP   Added parameter to WriteTextRecord call which tells
                        whether we are writing a header record or not.
         5-Sep-89 MWP   Retrieve thermometer message from phrases file, and
                        set it to 'cells written'.
        12-Sep-89 MWP   Fixed bug causing incorrect retrieval of boolean values.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        23-Jan-91 RSC   Removed RealFormat, as it was unused.
        17-Sep-91 AJL  Add WriteBooleanRecord.
    *)


FROM AsOf                   IMPORT
    (* PROC *)                  AsOfDate;

FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTime;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, NotYetImplemented;

FROM Directory              IMPORT
    (* VAR *)                   ExpandPath;

FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile, ExportMedia, ExportName;

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

FROM LotusExport            IMPORT
    (* PROC *)                  OpenFile, CloseFile, CheckFileStatus,
                                WriteTextRecord, WriteDateRecord,
                                WriteBooleanRecord, WriteIntegerRecord,
                                WriteRealRecord, WriteBigTimeRecord,
                                WriteCurrencyRecord, WriteBlankRecord,
                                WritePercentageRecord,
                                WriteColumnWidth, WriteNameRange,
                                WriteActiveRange;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatLS, CtoS, RJust,
                                SubStr, ConcatS, Insert, Procustes,
                                Search, LJust, TrimRear, Remove, Copy,
                                LengthOf, SetLengthOf, Overlay, TrimFront;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayCallChain;

FROM Progress               IMPORT
    (* TYPE *)                  AThermometer,
    (* PROC *)                  CreateThermometer, UpdateThermometer,
                                DiscardThermometer;

FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecord, ReadRecordPreface, ReadRecordBody;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia, ProjectName, FullScheduleName,
                                Author, ProjectText;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT
    (* PROC *)                  StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE, SIZE;

FROM Text                   IMPORT
    (* PROC *)                  LineExists, CopyLine;

FROM TimeFormat             IMPORT
    (* VAR *)                   DefaultDateAndTimeFormat,
    (* PROC *)                  TimeToString, TimeUtoS, FormatAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit;



CONST
    Zero                    = 0.0;
    ModuleNumber            = 21500;
    HeadingRows             = 9;        (* Was 9 *)                (* 30-Jul-89 MWP *)
    PrintZeros              = TRUE;
    ColSpacing              = 1;        (* Was 2 *)

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
    HeadingFilePos          : AFilePosition;
    FooterTitle             : ARRAY [0..127] OF CHAR;

    Row                     : CARDINAL;
    Column                  : CARDINAL;

    FirstDataRow            : CARDINAL;
    LastDataRow             : CARDINAL;


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;


PROCEDURE GetMessageWord( PhraseNumber    : CARDINAL;
                          TheWordNumber   : CARDINAL;
                      VAR ReturnValue     : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( PhraseNumber, s );
    WordNumber( s, TheWordNumber, ReturnValue );
END GetMessageWord;



PROCEDURE PutCellData       (     Type      : CARDINAL;
                              VAR Data      : AnIntDataRecord;
                                  Format    : AFormat;
                                  FirstLine : BOOLEAN;
                                  RightJust : BOOLEAN;
                                  Protect   : BOOLEAN;
                                  Header    : BOOLEAN );
VAR
    r           : REAL;
    c           : CARDINAL;
    TimeUnit    : ADurationUnit;

BEGIN

    CASE Type OF
        BooleanType :
            WriteBooleanRecord (Column, Row, Data.Boolean, RightJust, Protect, Header );

     |  TextType, EnumeratedType :
            WriteTextRecord (Column, Row, Data.LString, RightJust, Protect, Header );

    |   RealNumberType:
            CASE Format.FormatType OF
                FNumeric :
                    WriteRealRecord (Column, Row, Data.Real,
                                     ORD(Format.DecimalDigits),
                                     PrintZeros, Protect);
            |   FPercent :                                           (* 6-Jul-89 MWP *)
                    WritePercentageRecord (Column, Row, Data.Real,
                                           PrintZeros, Protect);

            |   FCurrency :
                    WriteCurrencyRecord (Column, Row, Data.Real,
                                         PrintZeros, Protect);
            ELSE
                    WriteBlankRecord (Column, Row, Protect);
            END;

    |   IntegerType :
            WriteIntegerRecord (Column, Row, Data.Integer,
                                PrintZeros, Protect);

    |   CardinalType :
            r := FLOAT(Data.Cardinal);
            WriteRealRecord (Column, Row, r, 0, PrintZeros, Protect);

    |   BigStartTimeType, BigEndTimeType, StartDateType, EndDateType :
            TimeUnit := VAL(ADurationUnit,Data.Cardinal);
            IF (TimeUnit = Weeks) OR (FirstLine) THEN
                CASE Type OF
                    BigStartTimeType, BigEndTimeType :
                        WriteBigTimeRecord (Column, Row, Data.BigTime, Protect);
                |   StartDateType :
                        WriteDateRecord (Column, Row, Data.Date, FALSE, Protect);

                |   EndDateType :
                        WriteDateRecord (Column, Row, Data.Date, TRUE, Protect);
                ELSE
                END;
            ELSE
                WriteBlankRecord (Column, Row, Protect);
            END;

    |   SkipRecordType :
            WriteBlankRecord (Column, Row, Protect);

    ELSE
            FatalError();
    END;
END PutCellData;




PROCEDURE GetOverallInfo();
VAR
    Version     : CARDINAL;
    Type,
    Length      : CARDINAL;
    i           : CARDINAL;
    Data        : AnIntDataRecord;
    s           : ARRAY [0..80] OF CHAR;

BEGIN
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
                    LJust (Data.LString);                  (* 4/25/89 EGK *)
                    TrimRear (Data.LString);
                    ConcatS (FooterTitle, " ");
                    ConcatLS (FooterTitle, Data.LString);
(**********
                    IF ( i > 1 ) THEN
                       ConcatS (FooterTitle, " ");
                    END;
                    ConcatLS (FooterTitle, Data.LString);
**********)
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



PROCEDURE ReadTitleLine ( VAR s         : ARRAY OF CHAR);
VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    High, Low       : CARDINAL;
    Format          : AFormat;

BEGIN
    GetPos (InterFile, High, Low);
    SetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

    ReadIntData (Type, Data);
    Copy (Data.LString, s);

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





PROCEDURE DoColumnHeaders;

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
    RightJust       : BOOLEAN;


BEGIN
(*
    FOR RowNum := 1 TO XDomainRecord.HeadingDepth DO
*)
    RowNum := 1;            (* 8/23/89 EGK *)

        IF (NOT StartSubfileInput (InterFile, 4, Version)) THEN
            RETURN;
        END;

        INC (Column);           (* Skip one for the row heading column *)

        LOOP
            ReadRecordPreface (InterFile, Type, Length);
            IF (CheckIO(InterFile) <> done) THEN EXIT; END;

            CASE Type OF

                HeadingRecordType :

                    ReadRecordBody (InterFile, Length, ADR(HeadingRecord),
                            SIZE(HeadingRecord));

                    FOR j := 1 TO HeadingRecord.HeadingDepth DO
                        ReadIntData (Type, Data);
                        IF (j = RowNum) THEN
                            RightJust := (PredicateRecord.DataType IN
                                    {RealNumberType, IntegerType, CardinalType});
                            PutCellData (Type, Data, PredicateRecord.Format,
                                         (j=1), RightJust, TRUE, TRUE);
                            INC (Column);
                        END;
                    END;

                    IF (Column > TotalColumns) THEN
                        EXIT;
                    END;

            |   0FFH :
                    EXIT;
            ELSE
                SkipRecordBody (InterFile, Length);
            END;
        END;
        Column := 0;
        INC (Row);
(*
    END;
*)
    INC (Row);                  (* 6/30/88 EGK *)
END DoColumnHeaders;




PROCEDURE PageHead;

CONST
    ModuleNumber = 10700;       (* From PrintCaptions *)

VAR
    Line    : ARRAY[0..230] OF CHAR;
    s       : ARRAY [0..80] OF CHAR;

BEGIN

    Copy (FooterTitle, Line);
    WriteTextRecord (0, 0, Line, FALSE, TRUE, FALSE);

    GetMessage(ModuleNumber+40,Line);   (*  "Schedule Name:   "  *)
    ConcatLS(Line,FullScheduleName);
    WriteTextRecord (0, 1, Line, FALSE, TRUE, FALSE);

    GetMessage(ModuleNumber+41,Line);   (*  "Project Manager: "  *)
    ConcatLS(Line,Author);
    WriteTextRecord (0, 2, Line, FALSE, TRUE, FALSE);

    GetMessage(ModuleNumber+42,Line);   (*  "As of date:      "  *)
    TimeUtoS (AsOfDate, s);
    TrimFront ( s );                                              (* 30-Jul-89 MWP *)
    ConcatLS(Line,s);
    WriteTextRecord (0, 3, Line, FALSE, TRUE, FALSE);

    IF (ProjectName[0] > 0C) THEN
        GetMessage (ModuleNumber+43,Line);     (*  "   Schedule File: "  *)
        LJust (Line);
        TrimRear ( Line );
        SetString ( s, " " );
        ConcatLS ( Line, s );

        Copy ( ProjectMedia, s );                                 (* 30-Jul-89 MWP *)
        TrimFront ( s );
        ConcatLS (Line, s );

        Copy ( ProjectName, s );                                 (* 30-Jul-89 MWP *)
        TrimFront ( s );
        ConcatLS (Line, s );

        WriteTextRecord (0, 4, Line, FALSE, TRUE, FALSE);
    END;

        (*  Print the first two lines of the project text as the project
            description.  If there isn't any text, print blank lines  *)
    IF LineExists(ProjectText, 0) THEN
        CopyLine(ProjectText, 0, s);
        WriteTextRecord (0, 6, s, FALSE, TRUE, FALSE);
    END;

    IF LineExists(ProjectText, 1) THEN
        CopyLine(ProjectText, 1, s);
        WriteTextRecord (0, 7, s, FALSE, TRUE, FALSE);
    END;

END PageHead;





PROCEDURE PutIndentation  ( VAR s       : ARRAY OF CHAR;
                                Indent  : CARDINAL      );
CONST
    SpacesPerLevel      = 2;
VAR
    s2          : ARRAY [0..99] OF CHAR;

BEGIN
    Fill (s2, " ", Indent * SpacesPerLevel);
    Insert (s, s2, 1);
END PutIndentation;



PROCEDURE DoPage;

VAR
    i                   : CARDINAL;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;
    Version             : CARDINAL;
    HeadingRecord       : AHeadingRecord;
    s                   : ARRAY [0..255] OF CHAR;
    Thermometer         : AThermometer;
    ThermOK             : BOOLEAN;

BEGIN

    IF (NOT StartSubfileInput (InterFile, 3, Version)) THEN
        RETURN;
    END;
    GetPos (InterFile, HeadingFilePos.High, HeadingFilePos.Low);

(*
    FirstDataRow := HeadingRows + XDomainRecord.HeadingDepth + 1;
*)
    FirstDataRow := HeadingRows + 2;    (* 8/23/89 EGK *)

    LastDataRow := FirstDataRow + TotalRows - 1;
    WriteActiveRange (0, 0, TotalColumns, LastDataRow);

    WriteColumnWidth (0, YDomainRecord.Width + ColSpacing);

    FOR i := 1 TO TotalColumns DO
        WriteColumnWidth (i, PredicateRecord.Width + ColSpacing);
    END;
    WriteNameRange (PredicateRecord.Name, 1, FirstDataRow, TotalColumns, LastDataRow);

    Row := 0;
    Column := 0;

    PageHead;
    Row := HeadingRows;
    DoColumnHeaders;

    IF (NOT StartSubfileInput (InterFile, 5, Version)) THEN
        RETURN;
    END;

    i := 0;
(*
    SetString (s, "records written");
*)
    GetMessage ( ModuleNumber + 10, s );                          (* 5-Sep-89 MWP *)
    (* cells written *)

    ThermOK := CreateThermometer (Thermometer, 0, 0, s, TotalRows * TotalColumns);

    LOOP

        ReadIntData (Type, Data);
        IF (Type = 0FFH) THEN
            EXIT;
        END;

        IF (Column = 0) THEN
            ReadHeadingRecord (HeadingRecord);
            ReadTitleLine (s);
            PutIndentation (s, HeadingRecord.DataIndentation);
            WriteTextRecord (Column, Row, s, FALSE, TRUE, FALSE);
            INC (Column);
        END;

        PutCellData (Type, Data, PredicateRecord.Format, TRUE, FALSE, FALSE, FALSE);

        INC (Column);
        IF (Column > TotalColumns) THEN     (* Get ready for a new line *)
            Column := 0;
            INC (Row);
        END;

        IF (ThermOK) THEN
            INC (i);
            UpdateThermometer (Thermometer, i);
        END;

    END;

    IF (ThermOK) THEN
        DiscardThermometer (Thermometer);
    END;
END DoPage;





PROCEDURE DoReport();

VAR
    Name            : ARRAY [0..99] OF CHAR;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Copy (ExportMedia, Name);
    ConcatLS (Name, ExportName);

    IF NOT OpenFile(Name) THEN
        RETURN;
    END;

    TotalRows := DimensionCount(1);
    TotalColumns := DimensionCount(2);

    IF (TotalColumns = 0) OR (TotalRows = 0) THEN
        RETURN;
    END;

    GetOverallInfo();

    DoPage;

    CloseFile;
END DoReport;



BEGIN
    IF HeapAvailable() THEN
        DoReport();
    END;
END TL2D123.
