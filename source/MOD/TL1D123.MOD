MODULE TL1D123;

(*  Exports the intermediate report/export file to a Lotus 1-2-3
    spreadsheet file.

    MODIFICATION HISTORY
        21-Dec-88 LAA   Changed imports for Lazlo reorganization.
        10-Jan-89 RSC   Changed Storage to Space    .
        18-May-89 MWP   Added translation of Boolean values.
        06-Jul-89 MWP   Added support for Percentage record types as per
                        Andrews changes.
        06-Jul-89 MWP   Output the named ranges, "TLDATA" and TL_TABLE,
                        which describes the range of exported data.
        06-Jul-89 MWP   Output the column names as first row in "TL_TABLE".
        30-Jul-89 MWP   Format 123 header data so that it aligns properly.
        10-Aug-89 KKC   Add copyright message.
         1-Sep-89 MWP   Added parameter to WriteTextRecord which tells whether
                        we are writing a header record or not.
         5-Sep-89 MWP   Retrieve thermometer message from phrases file, and
                        set it to 'cells written'.
        12-Sep-89 MWP  Fixed bug causing incorrect retrieval of boolean values.
        28-Sep-89 MWP  Changed the heading rows count from 7 to 9.
        19-Oct-89 MWP  Center formal column names.
        17-Sep-91 AJL  Add WriteBooleanRecord.
*)

FROM AsOf                   IMPORT
    (* PROC *)                  AsOfDate;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError, NotYetImplemented;

FROM Directory              IMPORT
    (* VAR *)                   ExpandPath;

FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile, ExportMedia, ExportName;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO;

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
                                HeadingRecordType, SkipRecordType,
    (* TYPE *)                  AnOverallRecord, APredicateHeadingRecord,
                                ADomainRecord, APredicateRecord,
                                AHeadingRecord, AnIntDataRecord, AFormat,
                                AFormatType,
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
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM Subfiles               IMPORT
    (* PROC *)                  StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE, SIZE;

FROM Text                   IMPORT
    (* PROC *)                  LineExists, CopyLine;

FROM TimeFormat             IMPORT
    (* PROC *)                  TimeUtoS;



CONST
    Zero                    = 0.0;
    ModuleNumber            = 21500;
    HeadingRows             = 9;        (* Was 9 *)                    (* 30-Jul-89 MWP *)
    PrintZeros              = TRUE;
    ColSpacing              = 1;        (* Was 2 *)               (* 4-Sep-89 MWP *)
    LotusModuleNumber       = 5500;                                    (* 6-Jul-88 MWP *)

TYPE
    APredicateList          = POINTER TO ARRAY [0..500] OF APredicateRecord;

VAR
    TotalColumns            : CARDINAL;
    TotalRows               : CARDINAL;
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    XDomainRecord           : ADomainRecord;
    YDomainRecord           : ADomainRecord;
    PredicateList           : APredicateList;
    FooterTitle             : ARRAY [0..80] OF CHAR;

    FirstDataRow            : CARDINAL;
    LastDataRow             : CARDINAL;

    Row                     : CARDINAL;         (* Current Lotus cell *)
    Column                  : CARDINAL;



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
                                  RightJust : BOOLEAN;
                                  Protect   : BOOLEAN;
                                  Heading   : BOOLEAN );
VAR
    r           : REAL;
    c           : CARDINAL;

BEGIN

    CASE Type OF
        BooleanType :
            WriteBooleanRecord (Column, Row, Data.Boolean, RightJust, Protect, Heading );

    |   TextType, EnumeratedType :
            WriteTextRecord (Column, Row, Data.LString, RightJust, Protect, Heading );

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

    |   BigStartTimeType, BigEndTimeType :
            WriteBigTimeRecord (Column, Row, Data.BigTime, Protect);

    |   StartDateType :
            WriteDateRecord (Column, Row, Data.Date, FALSE, Protect);

    |   EndDateType :
            WriteDateRecord (Column, Row, Data.Date, TRUE, Protect);

    |   SkipRecordType :
            WriteBlankRecord (Column, Row, Protect);

    ELSE
            FatalError();
    END;
END PutCellData;




PROCEDURE GetOverallInfo();
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput (InterFile, OverallSubfileNumber, Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(InterFile,Type,Length);
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

    GetMessage (ModuleNumber+1, FooterTitle);     (* "TIME LINE " *)
    ConcatLS (FooterTitle, OverallRecord.ReportName);

END GetOverallInfo;





PROCEDURE NumberOfPredicates() : CARDINAL;

(*  For one-dimensional reports only.   *)

VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
    PredicateRecord         : APredicateRecord;
    Count           : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        RETURN 0;
    END;

    Count := 0;
    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            PredicateRecordType :
                ReadRecordBody (InterFile, Length,
                        ADR(PredicateRecord), SIZE(PredicateRecord));
                INC (Count);
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;
    RETURN Count;
END NumberOfPredicates;






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




PROCEDURE DoColumnHeaders;

VAR
    RowNum          : CARDINAL;
    Version         : CARDINAL;
    i, j            : CARDINAL;
    Type            : CARDINAL;
    Length          : CARDINAL;
    PredicateRecord : APredicateRecord;
    Data            : AnIntDataRecord;
    RightJust       : BOOLEAN;

BEGIN

    FOR RowNum := 1 TO PredicateHeadingRecord.HeadingDepth DO

        IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
            RETURN;
        END;

        LOOP
            ReadRecordPreface (InterFile, Type, Length);
            IF (CheckIO(InterFile) <> done) THEN EXIT; END;

            CASE Type OF

                PredicateRecordType :

                    ReadRecordBody (InterFile, Length, ADR(PredicateRecord),
                            SIZE(PredicateRecord));
                    FOR j := 1 TO PredicateHeadingRecord.HeadingDepth DO
                        ReadIntData (Type, Data);
                        IF (j = RowNum) THEN
                            RightJust := (PredicateRecord.DataType IN
                                {RealNumberType, IntegerType, CardinalType,
                                 BigStartTimeType, BigEndTimeType,
                                 StartDateType, EndDateType});

                            PutCellData (Type, Data, PredicateRecord.Format,
                                         RightJust, TRUE, TRUE);
                            INC(Column);
                        END;
                    END;
                    IF (Column >= TotalColumns) THEN
                        EXIT;
                    END;
            |   0FFH :
                    EXIT;
            ELSE
                SkipRecordBody (InterFile, Length);
            END;
        END;
        Column := 0;
        INC(Row);
    END;
    INC (Row);                  (* 6/30/88 EGK *)
(*
    FOR i := 0 TO ColumnCount - 1 DO
        Fill (s, "-", PredicateList^[i].Width);
        PrintText (s, Normal);
        PrintText (Space, Normal);
    END;

    PrintLine (BlankLine, Normal);
*)
END DoColumnHeaders;




PROCEDURE PageHead;

CONST
    ModuleNumber = 10700;       (* From PrintCaptions *)

VAR
    Line    : ARRAY[0..230] OF CHAR;
    s       : ARRAY [0..80] OF CHAR;

BEGIN

    Copy (FooterTitle, Line);
    WriteTextRecord (0, 0, Line, FALSE, TRUE, FALSE );

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
        TrimRear ( Line );                                        (* 30-Jul-89 MWP *)
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





PROCEDURE DoPage;

VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    High, Low       : CARDINAL;
    Version         : CARDINAL;
    i               : CARDINAL;
    Thermometer     : AThermometer;
    ThermOK         : BOOLEAN;
    s               : ARRAY [0..255] OF CHAR;

BEGIN

    FirstDataRow := HeadingRows + PredicateHeadingRecord.HeadingDepth + 1;
    LastDataRow := FirstDataRow + TotalRows;                       (* 6-Jul-89 MWP *)

    IF (TotalColumns > 0) THEN
        WriteActiveRange (0, 0, TotalColumns-1, LastDataRow);

        FOR i := 0 TO TotalColumns - 1 DO
            WriteColumnWidth (i, PredicateList^[i].Width + ColSpacing);
        END;

        FOR i := 0 TO TotalColumns - 1 DO
            WriteNameRange ( PredicateList^[i].Name,
                             i,
                             FirstDataRow + 1,                      (* 6-Jul-89 MWP *)
                             i,
                             LastDataRow);
        END;

        GetMessage ( LotusModuleNumber + 14, s );                   (* 6-Jul-89 MWP *)
        (* TL_DATA *)
        i := 0;
        WriteNameRange (s, i, FirstDataRow + 1, TotalColumns - 1, LastDataRow );

        GetMessage ( LotusModuleNumber + 13, s );                   (* 6-Jul-89 MWP *)
        (* TL_TABLE *)
        i := 0;
        WriteNameRange (s, i, FirstDataRow, TotalColumns - 1, LastDataRow );
    END;

    Row := 0;               (* Start writing at (0,0) *)
    Column := 0;

    PageHead ();            (* Overall report information *)
    Row := HeadingRows;     (* In case PageHead printed less than HeadingRows *)
    DoColumnHeaders;        (* Specific headings for the columns *)

    IF (NOT StartSubfileInput (InterFile, 3+OverallRecord.Dimensions, Version)) THEN
        RETURN;
    END;

    (* Now write out all the Formal Column Names. *)

    FOR i := 0 TO TotalColumns - 1 DO                               (* 6-Jul-89 MWP *)
        WriteTextRecord (Column, Row, PredicateList^[i].Name, FALSE, FALSE, TRUE);  (* 19-Oct-89 MWP *)
        INC (Column);
    END;

    Column := 0;
    INC(Row);


    i := 0;
    GetMessage ( ModuleNumber + 10, s );                          (* 5-Sep-89 MWP *)
    (* cells written *)
    ThermOK := CreateThermometer (Thermometer, 0, 0, s, TotalRows * TotalColumns);

    LOOP

        ReadIntData (Type, Data);
        IF (Type = 0FFH) THEN
            EXIT;
        END;

        PutCellData (Type, Data, PredicateList^[Column].Format, FALSE, FALSE, FALSE);

        INC (Column);
        IF (Column >= TotalColumns) THEN
            Column := 0;
            INC(Row);
        END;

        INC (i);
        UpdateThermometer (Thermometer, i);

    END;

    DiscardThermometer (Thermometer);

END DoPage;



PROCEDURE GetColumnInfo();

VAR
    Version         : CARDINAL;
    PredicateRecord : APredicateRecord;
    Type            : CARDINAL;
    Length          : CARDINAL;
    i               : CARDINAL;

BEGIN

    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        RETURN;
    END;

    i := 0;
    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            PredicateRecordType :
                ReadRecordBody (InterFile, Length,
                                ADR(PredicateRecord), SIZE(PredicateRecord));
                PredicateList^[i] := PredicateRecord;
                INC (i);
                IF (i >= TotalColumns) THEN
                    EXIT;
                END;
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;

END GetColumnInfo;




PROCEDURE DoReport();

VAR
    Name            : ARRAY [0..99] OF CHAR;
    Size            : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Copy (ExportMedia, Name);
    ConcatLS (Name, ExportName);

    IF NOT OpenFile(Name) THEN
        RETURN;
    END;

    TotalColumns := NumberOfPredicates();
    TotalRows := DimensionCount(1);
(*
    IF (TotalColumns = 0) OR (TotalRows = 0) THEN
        CloseFile;
        RETURN;
    END;
*)
    Size := ArraySize (TotalColumns, TSIZE(APredicateRecord));
    ALLOCATE (PredicateList, Size);

    GetOverallInfo();
    GetColumnInfo();        (* Set up the predicate list *)

    DoPage;                 (* Put out stuff *)

    CloseFile;

    DEALLOCATE (PredicateList, Size);

END DoReport;



BEGIN
    IF HeapAvailable() THEN

        DoReport();

    END;
END TL1D123.
