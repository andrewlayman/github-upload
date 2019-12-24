MODULE TLPrt1D;

(*  Generic printing module for tabular reports of one and two dimensions.
   RSC 9/16/88 - remove kluge where DeleteTempFile had to be called.
   RSC 11/9/88 - left InterFileOpen reference behind that shouldn't be there.
   LAA 21-Dec-88 Changed imports for Lazlo reorganization.
   RSC 23-Jan-89 Changed Storage to Space    .
   AJL 21-Jun-89 Added format type FPercent.
   KKC 05-Jul-89 Print spaces for strings contain only zeros If user selects
                 "Print zeros as spaces" in page break form.
   KKC 10-Aug-89 Add copyright message.
   KKC 18-Sep-89 Pass NDecimalDigits as max and min digits to FormatAsAmount.
   KKC 06-Oct-89 IF Header is set to First Page Only, print out header on
                 strip 1 only.
   WKH 29-Nov-89 Import ConflictProc from VersionConflict to fix version
                 conflict problem caused by linker.
   KKC 19-Apr-90 Grouped year, month, day, hour, minute into one
                 date structure, ATimeInfo. 
   AJL 23-Feb-91 For fields which are marked "IsHeading," we print blanks
                 on subsequent rows which repeat the same value.
                -Only insert indentation for the first field on a line that
                 is marked as "IsHeading".  This works for all current (Feb 91)
                 reports, but is really not the correct solution (for example,
                 what if on an assignment report the Resource name preceded
                 the task name, but the row indentation were set based on the
                 task.  Better would be to have each field contain not only
                 its font, but its indentation, or else to have another record
                 giving the indentation precede each indented field.
   AJL 29-Feb-91 Don't fail if there are no columns.
   AJL  3-Jul-91 Added UsesSelectFilter and UsesHighlightFilter to 
                 OverallRecord.  Pass to FilterNotes.
   TGS  3-Sep-91 After printing a data item, check to see if it is the last
                 item on that line. If so, then don't print spaces between it
                 and the (nonexistent) item to its right. Not doing so causes
                 unintentional "wraparound" to the next line. Bug 5025.
   AJL 24-Apr-92 In the above change, the test was coded incorrectly.  Change
                 to use a new procedure, ColumnFollows. 
*)


FROM BigTimeU               IMPORT
    (* PROC *)                  BigTimeToTime;

FROM Codes                  IMPORT
    (* TYPE *)                  ASetOfCodes,
    (* CONST *)                 BitsPerBitSet, MaxCode,
    (* VAR *)                   EmptyCodeSet,
    (* PROC *)                  SetCodeBits;

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
                                HeadingRecordType, SkipRecordType,
    (* TYPE *)                  AnOverallRecord, APredicateHeadingRecord,
                                ADomainRecord, APredicateRecord,
                                AHeadingRecord, AnIntDataRecord, AFormat,
                                AFormatType, ASetOfIntDataFields,
    (* PROC *)                  ReadIntData;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatLS, CtoS, RJust,
                                SubStr, ConcatS, Insert, Procustes,
                                Search, LJust, TrimRear, Remove, Copy,
                                LengthOf, SetLengthOf, Overlay, StoC,
                                StringsEqual;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM PrintCaptions          IMPORT
    (* PROC *)                  FilterNotes, PageHead;

FROM PrintOptions           IMPORT
    (* VAR *)                   ReportSettings,
    (* PROC *)                  DoPrintDialog;

FROM PrintSupport           IMPORT
    (* VAR *)                   Stopped,
    (* PROC *)                  RowsLeft, PageWidth, PageTop, StartReport,
                                StartPage, EndReport, PrintLine, PrintText,
                                AllowUnlimitedPageLength, ProgressMessage,
                                AllowLeftMargin, GetCurrentPrintRow;

FROM RealFormat             IMPORT
    (* TYPE *)                  ACurrencyFormat,
    (* VAR *)                   DefaultAmountFormat, DefaultCurrencyFormat,
                                FormatAsAmount, FormatAsCurrency;

FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecord, ReadRecordPreface, ReadRecordBody;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable, ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE, SIZE;

FROM TempFile               IMPORT
    (* PROC *)                  DeleteTempFile;

FROM TimeFormat             IMPORT
    (* PROC *)                  DtoS, TimeUtoS, FormatAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ATimeInfo;

FROM VersionConflict        IMPORT
    (* PROC *)                  ConflictProc;  (* 29-Nov-89 WKH *)


CONST
    Normal                  = 0;
    Bold                    = 1;
    Zero                    = 0.0;
    ModuleNumber            = 21500;
    MaxLastRowColumns       = 3;        (* Number whose duplicates are suppressed. *)

TYPE
    APredicateList          = POINTER TO ARRAY [0..500] OF APredicateRecord;
    AFilePosition           = ADDRESS;

VAR
    TotalColumns            : CARDINAL;
    TotalRows               : CARDINAL;
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    XDomainRecord           : ADomainRecord;
    YDomainRecord           : ADomainRecord;
    BlankLine               : ARRAY [0..1] OF CHAR;
    HeadingPos              : AFilePosition;
    PredicateList           : APredicateList;
        (* LastRowData stores the values of the first several columns of the
           preceding row.   We actually only store the values of fields
           which are eligible for suppression, which is fields marked
           as being headers. *)
    LastRowData             : ARRAY [1..MaxLastRowColumns] OF
                                         AnIntDataRecord;
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



PROCEDURE BitInSet  (   BitNumber   : CARDINAL;
                        Set         : ASetOfCodes   ) : BOOLEAN;
BEGIN
    RETURN ((BitNumber MOD BitsPerBitSet) IN Set[BitNumber DIV BitsPerBitSet]);
END BitInSet;




PROCEDURE ConvertToString   (     Type      : CARDINAL;
                              VAR Data      : AnIntDataRecord;
                                  Format    : AFormat;
                                  Width     : CARDINAL;
                              VAR String    : ARRAY OF CHAR     );
VAR
    r           : REAL;
    NDecimalDigits   : CARDINAL;
    CurrencyFormat      : ACurrencyFormat;
    TimeInfo    : ATimeInfo;
    i, tmp      : CARDINAL;

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

    |   BigStartTimeType, BigEndTimeType :
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
            DtoS (TimeInfo, String);

    |   StartDateType :
            TimeUtoS (Data.Date, String);

    |   EndDateType :
            FormatAsEndDateStyle (Data.Date, String);

    |   SkipRecordType :
            Fill (String, " ", Width);

    ELSE
            FatalError();
    END;

    IF (NOT ReportSettings^.PrintZeros) THEN
        TrimRear(String);
        i := 1;
        tmp := StoC(String, i);
        IF (  tmp = 0 ) THEN
            IF ( String[i] = '.') THEN
                INC(i);
                tmp := StoC(String, i);
            END;
            IF ( (tmp = 0 ) AND ( i > LengthOf(String) ) ) THEN
                Fill (String, " ", LengthOf(String) );
            END;
        END;
    END;

    IF (LengthOf(String) > Width) THEN
        SetLengthOf (String, Width);
    END;
    WHILE (LengthOf(String) < Width) DO
        ConcatS (String, " ");
    END;
END ConvertToString;




PROCEDURE GetOverallInfo();
VAR
    Version : CARDINAL;
    Type,
    Length  : CARDINAL;
BEGIN
    IF (NOT StartFileInput (InterFile)) THEN
        RETURN;
    END;

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



    (* AColumnFollows -- Returns TRUE iff there is some column in the 
                         ColumnSet > ThisColumn. 
    *)

PROCEDURE AColumnFollows(     ThisColumn : CARDINAL;
                          VAR ColumnSet  : ASetOfCodes ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
    FOR i := ThisColumn+1 TO MaxCode DO
        IF (i MOD BitsPerBitSet IN ColumnSet[i DIV BitsPerBitSet]) THEN
            RETURN TRUE;
	END;
    END;
    RETURN FALSE;
END AColumnFollows;




PROCEDURE DoColumnHeaders ( ColumnSet       : ASetOfCodes   );

VAR
    RowNum          : CARDINAL;
    Version         : CARDINAL;
    j               : CARDINAL;
    Column          : CARDINAL;
    Type            : CARDINAL;
    Length          : CARDINAL;
    s               : ARRAY [0..255] OF CHAR;
    Space           : ARRAY [0..255] OF CHAR;
    Data            : AnIntDataRecord;
    FilePos         : AFilePosition;

BEGIN

    GetFilePosition (FilePos);      (* Save where we are now *)

    FOR RowNum := 1 TO PredicateHeadingRecord.HeadingDepth DO

        IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
            RETURN;
        END;

        Fill (Space, " ", ReportSettings^.ColumnSpec.Spacing);

        Column := 1;

        LOOP
            ReadRecordPreface (InterFile, Type, Length);
            IF (CheckIO(InterFile) <> done) THEN EXIT; END;

            CASE Type OF

                PredicateRecordType :

                    SkipRecordBody (InterFile, Length);

                    IF BitInSet (Column, ColumnSet) THEN
                        FOR j := 1 TO PredicateHeadingRecord.HeadingDepth DO
                            ReadIntData (Type, Data);
                            IF (j = RowNum) THEN
                                ConvertToString (Type, Data, PredicateList^[Column].Format,
                                                 PredicateList^[Column].Width, s);
                                Procustes (s, PredicateList^[Column].Width);
                                IF (PredicateList^[Column].DataType IN
                                        {RealNumberType, IntegerType, CardinalType}) THEN
                                    RJust (s);
                                END;
                                PrintText (s, Normal);
                                IF (Column < TotalColumns) AND
				   (AColumnFollows(Column,ColumnSet)) THEN (* 3-Sep-91 TGS *)
                                    PrintText (Space, Normal);
                                END;
                            END;
                        END;
                    END;
                    INC (Column);

            |   0FFH :
                    EXIT;
            ELSE
                SkipRecordBody (InterFile, Length);
            END;
        END;
        PrintLine (BlankLine, Normal);
    END;

    FOR Column := 1 TO TotalColumns DO
        IF BitInSet (Column, ColumnSet) THEN
            Fill (s, "-", PredicateList^[Column].Width);
            PrintText (s, Normal);
            IF (Column < TotalColumns) AND
	       (AColumnFollows(Column,ColumnSet)) THEN (* 3-Sep-91 TGS *)
                PrintText (Space, Normal);
            END;
        END;
    END;

    PrintLine (BlankLine, Normal);

    SetFilePosition (FilePos);      (* Restore our old position *)
END DoColumnHeaders;




PROCEDURE ResetHeadings();
VAR
    FilePos         : AFilePosition;
    Version         : CARDINAL;
BEGIN
    GetFilePosition (FilePos);

    IF (StartSubfileInput (InterFile, 3, Version)) THEN END;
    GetFilePosition (HeadingPos);

    SetFilePosition (FilePos);
END ResetHeadings;




PROCEDURE GetIndentation () : CARDINAL;

VAR
    HeadingRecord       : AHeadingRecord;
    Data                : AnIntDataRecord;
    Type                : CARDINAL;
    FilePos             : AFilePosition;
    Length              : CARDINAL;
    i                   : CARDINAL;
BEGIN
    GetFilePosition (FilePos);
    SetFilePosition (HeadingPos);

    ReadRecordPreface (InterFile, Type, Length);
    ReadRecordBody (InterFile, Length, ADR(HeadingRecord), SIZE(HeadingRecord));
    FOR i := 1 TO HeadingRecord.HeadingDepth DO
        ReadIntData (Type, Data);
    END;

    GetFilePosition (HeadingPos);
    SetFilePosition (FilePos);

    RETURN HeadingRecord.DataIndentation;
END GetIndentation;




PROCEDURE PutIndentation (  VAR s           : ARRAY OF CHAR;
                                Indent      : CARDINAL;
                                MaxWidth    : CARDINAL      );
CONST
    SpacesPerLevel  = 2;
VAR
    Spaces          : ARRAY [0..40] OF CHAR;

BEGIN
    Fill (Spaces, " ", Indent * SpacesPerLevel);
    IF (LengthOf(s) + LengthOf(Spaces) > MaxWidth) THEN
        SetLengthOf (s, MaxWidth-LengthOf(Spaces));
    END;
    Insert (s, Spaces, 1);
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

    GetFilePosition (TempFilePos);
    SetFilePosition (HeadingPos);

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

    SetFilePosition (TempFilePos);
    RETURN Result;
END PageBreakNeeded;




PROCEDURE DoPage(   StripNumber     : CARDINAL;
                    PageNumber      : CARDINAL;
                    ColumnSet       : ASetOfCodes;
                VAR Done            : BOOLEAN         );

VAR
    i               : CARDINAL;
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    s               : ARRAY [0..255] OF CHAR;
    Space           : ARRAY [0..255] OF CHAR;
    EndLines        : CARDINAL;
    Column          : CARDINAL;
    Indent          : CARDINAL;
        (* If a line contains several fields which are marked as being
           "headers" (aka "key fields") then this counts the ordinal
           sequence of the current one. *)
    HeaderFieldSequence : CARDINAL;
    Duplicate       : BOOLEAN;

BEGIN

    IF (
        ( (StripNumber = 1) AND (PageNumber = 1) )
        OR
        (ReportSettings^.RowSpec.RepeatHeaders)
       ) THEN
        PageHead();
        FilterNotes(OverallRecord.UsesSelectFilter, OverallRecord.UsesHighlightFilter);
        EndReportHeaderPos := GetCurrentPrintRow();
        ClearLastRowData(1);   (* Allow repeat of duplicated items. *)
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
        DoColumnHeaders (ColumnSet);
        ClearLastRowData(1);   (* Allow repeat of duplicated items. *)
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

    Fill (Space, " ", ReportSettings^.ColumnSpec.Spacing);
    Column := 1;
    Indent := 0;

    LOOP

        IF (RowsLeft() <= EndLines) OR (Stopped) THEN
            EXIT;
        END;

        ReadIntData (Type, Data);
        IF (Type = 0FFH) THEN
            Done := TRUE;
            EXIT;
        END;

            (* Column = 1 means we are starting a new row. *)

        IF (Column = 1) THEN
            Indent := GetIndentation();
            HeaderFieldSequence := 0;   (* None seen so far. *)
        END;


            (* Is this a copy of the row above column?   We only
               keep copies of the fields which are "Heading" columns. *)
        IF (PredicateList^[Column].IsHeading) THEN
            INC(HeaderFieldSequence);
            Duplicate := (CompareLastRowData(HeaderFieldSequence,
                                             Type,Data));
                (* Record this value so we can compare it to the next row. *)
            StoreLastRowData(HeaderFieldSequence,Data);
            IF (NOT Duplicate) THEN
                ClearLastRowData(HeaderFieldSequence+1);   (* Allow repeat of following columns. *)
            END;
        ELSE
            Duplicate := FALSE;
        END;


        IF BitInSet (Column, ColumnSet) THEN
                (* If the column is a duplicate of the one above it,
                   print as blank.  Otherwise, print it, perhaps
                   indented. *)
            IF (Duplicate) THEN
                Fill(s," ",PredicateList^[Column].Width);
                PrintText (s, Normal);
            ELSE
                ConvertToString (Type, Data, 
                                 PredicateList^[Column].Format,
                                 PredicateList^[Column].Width, s);
                IF (PredicateList^[Column].IsHeading) AND
                   (HeaderFieldSequence = 1) THEN
                    PutIndentation (s, Indent, PredicateList^[Column].Width);
                END;
                PrintText (s, ORD(Data.Font));
            END;


            IF (Column < TotalColumns) AND
	       (AColumnFollows(Column,ColumnSet)) THEN (* 3-Sep-91 TGS *)
                PrintText (Space, Normal);
            END;
        END;


        INC (Column);
        IF (Column > TotalColumns) THEN
            Column := 1;
            PrintLine (BlankLine, Normal);

            IF (ReportSettings^.RowSpec.Paged) AND
                    (PageBreakNeeded (Indent)) THEN
                EXIT;
            END;

            i := ReportSettings^.RowSpec.Spacing;
            WHILE (i > 1) AND (RowsLeft() > EndLines) DO
                PrintLine (BlankLine, Normal);
                DEC(i);
            END;
        END;

    END;

    IF (ReportSettings^.RowSpec.Paged) THEN
        IF (Done) OR (ReportSettings^.RowSpec.RepeatFooters) THEN
            EndLines := 2;      (* The last page must have a footer *)
        END;
        WHILE (RowsLeft() > EndLines) DO
            PrintLine (BlankLine, Normal);
        END;
    END;

    IF (Done) OR ((ReportSettings^.RowSpec.Paged) AND
            (ReportSettings^.RowSpec.RepeatFooters)) THEN
        PrintLine (BlankLine, Normal);
        GetMessage (ModuleNumber+1, s);     (* "TIME LINE " *)
        ConcatLS (s, OverallRecord.ReportName);

        IF (StripNumber > 1) OR (NOT BitInSet (TotalColumns, ColumnSet)) THEN
            ConcatMessage (s, ModuleNumber+2);      (* ", Strip " *)
            CtoS (StripNumber, Space);
            ConcatLS (s, Space);
        END;

        IF (ReportSettings^.RowSpec.RepeatFooters) AND
                ((PageNumber > 1) OR (NOT Done)) THEN
            ConcatMessage (s, ModuleNumber+3);      (* ", Page " *)
            CtoS (PageNumber, Space);
            ConcatLS (s, Space);
        END;

        PrintLine (s, Normal);
        ProgressMessage (s);
    END;
END DoPage;



PROCEDURE DoStrip (     StripNumber     : CARDINAL;
                        FirstColumn     : CARDINAL;
                    VAR LastColumn      : CARDINAL  );

VAR
    Done            : BOOLEAN;
    PageNumber      : CARDINAL;
    Column          : CARDINAL;
    ColumnSet       : ASetOfCodes;
    RowRepeat       : BOOLEAN;
    SpaceLeft       : CARDINAL;
    Version         : CARDINAL;


    PROCEDURE ColumnFits ( Column : CARDINAL ) : BOOLEAN;
    BEGIN
        RETURN (PredicateList^[Column].Width <= SpaceLeft);
    END ColumnFits;


    PROCEDURE AddColumn ( Column : CARDINAL );
    BEGIN
        IF (PredicateList^[Column].Width > SpaceLeft) THEN
            PredicateList^[Column].Width := SpaceLeft;
        END;
        SetCodeBits (ColumnSet, Column, Column, TRUE);
        DEC (SpaceLeft, PredicateList^[Column].Width);
        IF (SpaceLeft > ReportSettings^.ColumnSpec.Spacing) THEN
            DEC (SpaceLeft, ReportSettings^.ColumnSpec.Spacing);
        ELSE
            SpaceLeft := 0;
        END;
    END AddColumn;


BEGIN

    IF (StripNumber > 1) AND (NOT ReportSettings^.ColumnSpec.RepeatHeaders) THEN
        AllowLeftMargin (FALSE);
    END;

    (*  Should we automatically repeat the first column on all strips after
        the first?      *)

    RowRepeat   := (StripNumber > 1)                            AND
                   (ReportSettings^.ColumnSpec.Paged)           AND
                   (ReportSettings^.ColumnSpec.RepeatTitles);

    SpaceLeft := PageWidth();
    ColumnSet := EmptyCodeSet;

    IF (RowRepeat) THEN
        AddColumn (1);
    END;

    Column := FirstColumn;

    LOOP
        IF (Column > TotalColumns) THEN
            DEC (Column);
            EXIT;
        END;

        IF (ColumnFits (Column)) THEN
            AddColumn (Column);
        ELSIF (Column = FirstColumn) THEN
            AddColumn (Column);
            EXIT;
        ELSE
            DEC (Column);
            EXIT;
        END;
        INC (Column);
    END;

    LastColumn := Column;

    IF (NOT StartSubfileInput (InterFile, 3+OverallRecord.Dimensions, Version)) THEN
        RETURN;
    END;

    ResetHeadings();        (*  start reading from beginning of heading
                                subfile, for calls to GetIndentation       *)

    Done := FALSE;
    PageNumber := 1;

    WHILE (NOT Done) AND (NOT Stopped) DO
        DoPage (StripNumber, PageNumber, ColumnSet, Done);
        INC (PageNumber);
    END;

END DoStrip;




PROCEDURE BuildPredicateArray();
VAR
    Version             : CARDINAL;
    Type,
    Length              : CARDINAL;
    PredicateRecord     : APredicateRecord;
    Column              : CARDINAL;
BEGIN
    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        RETURN;
    END;

    Column := 1;

    LOOP
        ReadRecordPreface(InterFile,Type,Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            PredicateRecordType :
                ReadRecordBody (InterFile, Length,
                        ADR(PredicateRecord), SIZE(PredicateRecord));
                PredicateList^[Column] := PredicateRecord;
                INC (Column);
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;
END BuildPredicateArray;





    (* Erase the record of what were the beginning values of the 
       preceding line. *)

PROCEDURE ClearLastRowData(Start:CARDINAL);
VAR
    i : CARDINAL;
BEGIN
    FOR i := Start TO HIGH(LastRowData) DO
        LastRowData[i].IntDataField := ASetOfIntDataFields{};
    END;
END ClearLastRowData;



PROCEDURE StoreLastRowData( i : CARDINAL; VAR Data : AnIntDataRecord );
BEGIN
    IF (i <= HIGH(LastRowData)) THEN
        LastRowData[i] := Data;
    END;
END StoreLastRowData;


PROCEDURE CompareLastRowData(     i      : CARDINAL;
                                  Type   : CARDINAL;
                              VAR Data : AnIntDataRecord)
                            : BOOLEAN;
VAR
    Same : BOOLEAN;
BEGIN
    IF (i > HIGH(LastRowData)) OR 
       (LastRowData[i].IntDataField = ASetOfIntDataFields{}) THEN
        RETURN FALSE;
    ELSE
        WITH LastRowData[i] DO

            CASE Type OF
                TextType, BooleanType, EnumeratedType :
                    Same := StringsEqual(Data.LString, LString);
        
            |   RealNumberType:
                    Same := (Data.Real = Real);
            |   IntegerType:
                    Same := (Data.Integer = Integer);
            |   CardinalType:
                    Same := (Data.Cardinal = Cardinal);
        
            |   BigStartTimeType, BigEndTimeType :
                    Same := (Data.BigTime.High = BigTime.High) AND
                            (Data.BigTime.Low  = BigTime.Low);
        
            |   StartDateType, EndDateType :
                    Same := (Data.Date = Date);
        
            ELSE
                    Same := FALSE;
            END;
        END;
        RETURN Same;
    END;
END CompareLastRowData;


PROCEDURE DoReport();
VAR
    FirstColumn     : CARDINAL;
    StripNumber     : CARDINAL;
    LastColumn      : CARDINAL;
    Size            : CARDINAL;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (NOT StartReport()) THEN
        RETURN;
    END;

    IF (NOT ReportSettings^.RowSpec.Paged) THEN
        AllowUnlimitedPageLength (TRUE);
    END;

    SetLengthOf (BlankLine, 0);
    GetOverallInfo();

(*  TotalRows := DimensionCount(1);     *)

    TotalColumns := NumberOfPredicates();

    IF (TotalColumns > 0) THEN

           (* Store information about each column. *)
    
        Size := ArraySize (TotalColumns+1, TSIZE(APredicateRecord));
        ALLOCATE (PredicateList, Size);
        BuildPredicateArray();
    
        ClearLastRowData(1);
    
    
        StripNumber := 1;
        LastColumn := 0;
    
        WHILE (LastColumn < TotalColumns) AND (NOT Stopped) DO
            FirstColumn := LastColumn + 1;
            DoStrip (StripNumber, FirstColumn, LastColumn);
            INC (StripNumber);
        END;
    
    
        DEALLOCATE (PredicateList, Size);

    END;
    
    EndReport;
END DoReport;



BEGIN
    IF HeapAvailable() AND DoPrintDialog(2) THEN
        DoReport();
    END;
    DeleteTempFile (InterFile);
    InterFileOpen := FALSE;
END TLPrt1D.

