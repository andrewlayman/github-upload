IMPLEMENTATION MODULE NormalExport;

(*  MODIFICATION HISTORY:


    Translate the intermediate file into a normalized form suitable for
    exporting to a fixed-record style database product (as opposed to a
    spreadsheet product).

    Each record written consists of fields to identify the coordinates of
    the data point (the heading labels, one set per dimension) followed by
    the data defined at that point (one field per predicate value).

    If the intermediate file contains aggregate values, they will be skipped
    over.

        RSC  6-Feb-89  Remove "ExportersOK".
        MWP  5-Sep-89  If we are outputting XTab information, then display
                       'fields written' thermometer message, rather than
                       'records written'.
*)





FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM ExportLinkage          IMPORT
    (* VAR *)                   ExportMedia, ExportName, InterFile;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  GetPos, SetPos;

FROM IntFileIO              IMPORT
    (* CONST *)                 OverallSubfileNumber, PredicateSubfileNumber,
                                TextType, RealNumberType, IntegerType,
                                CardinalType, BooleanType,
                                BigStartTimeType, BigEndTimeType,
                                StartDateType, EndDateType,
                                EnumeratedType, PredicateRecordType,
                                HeadingRecordType, SkipRecordType,
                                AggregatorRecordType,
    (* TYPE *)                  AnOverallRecord, APredicateHeadingRecord,
                                ADomainRecord, APredicateRecord, ADataType,
                                AHeadingRecord, AnIntDataRecord, AFormat,
                                AFormatType, AnAggregatorRecord,
    (* PROC *)                  ReadIntData;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetString, ConcatLS, CtoS, RJust,
                                SubStr, ConcatS, Insert, Procustes,
                                Search, LJust, TrimRear, Remove, Copy,
                                LengthOf, SetLengthOf, Overlay,
                                LStringToTString, StoC;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM Progress               IMPORT
    (* TYPE *)                  AThermometer,
    (* PROC *)                  CreateThermometer, UpdateThermometer,
                                DiscardThermometer;

FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecord, ReadRecordPreface, ReadRecordBody;

FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE, SIZE;



CONST
    MaxDim              = 10;
    MaxPred             = 500;

    ModuleNumber        = 24500;

TYPE

    AFilePosition       = ADDRESS;


    (* In the following record,
            ItemCount   = size of the dimension (excluding aggregates)
            CurrentPos  = index selected by HFilePos (from 1 to ItemCount)
            HFilePos    = heading file position (calling SetFilePosition with
                          this allows ReadRecordBody to get the current
                          heading record (followed by its labels)
            AggCount    = number of aggregate values (extra data points)
                          defined for this dimension
            DomainRecord: defines the name of the dimension (e.g. "TASK"),
                          column width, etc.
    *)


    ADomainInfoRecord = RECORD
                            ItemCount       : CARDINAL;
                            CurrentPos      : CARDINAL;
                            HFilePos        : AFilePosition;
                            AggCount        : CARDINAL;
                            DomainRecord    : ADomainRecord;
                        END;
VAR
    TotalDimensions             : CARDINAL;
    OverallRecord               : AnOverallRecord;
    PredicateHeadingRecord      : APredicateHeadingRecord;



    DomainInfo                  : ARRAY [0..MaxDim] OF ADomainInfoRecord;

        (*  index 1 is the first real dimension.  DomainInfo[0] actually
            applies to the predicate list.
        *)

    NullFormat                  : AFormat;
    DataPos                     : AFilePosition;
    Agging                      : BOOLEAN;


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




PROCEDURE ResetPos  (   Dimension   : CARDINAL  ) : BOOLEAN;

(*  Resets the position of this dimension's heading subfile marker,
    and sets its index to 1.  If FALSE is returned, something is wrong!
*)

VAR
    Version             : CARDINAL;
    Type                : CARDINAL;
    Result              : BOOLEAN;

BEGIN

    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber + Dimension,
                                Version)) THEN
        RETURN FALSE;
    END;

    IF (Dimension = 0) THEN
        Type := PredicateRecordType;
    ELSE
        Type := HeadingRecordType;
    END;

    Result := FindRecord (Type, DomainInfo[Dimension].HFilePos);
    IF (Result) THEN
        DomainInfo[Dimension].CurrentPos := 1;
    END;
    RETURN Result;

END ResetPos;






PROCEDURE NextPos   (   Dimension   : CARDINAL  ) : BOOLEAN;

(*  Moves the subfile marker for this dimension to point to the next
    heading record.  FALSE is returned iff there are no more headings
    (e.g., at the end of a row).
*)

VAR
    Type                : CARDINAL;
    Length              : CARDINAL;
    Result              : BOOLEAN;

BEGIN

    SetFilePosition (DomainInfo[Dimension].HFilePos);

    IF (Dimension = 0) THEN
        Type := PredicateRecordType;
        Length := TSIZE(APredicateRecord);
    ELSE
        Type := HeadingRecordType;
        Length := TSIZE(AHeadingRecord);
    END;

    SkipRecordBody (InterFile, Length);
    Result := FindRecord (Type, DomainInfo[Dimension].HFilePos);
    IF (Result) THEN
        INC (DomainInfo[Dimension].CurrentPos);
    END;
    RETURN Result;

END NextPos;



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
        |   3..MaxDim+2 :
                ReadRecordBody (InterFile, Length,
                                ADR(DomainInfo[Type-2].DomainRecord),
                                TSIZE(ADomainRecord));
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;

    TotalDimensions := OverallRecord.Dimensions;

END GetOverallInfo;




PROCEDURE NumberOfRecords    (   Dimension   : CARDINAL  ) : CARDINAL;

(*  For real dimensions (excluding 0, which applies to predicates), this
    includes aggregates.  They must be detected elsewhere.
*)

VAR
    Count       : CARDINAL;
BEGIN
    Count := 0;
    IF ResetPos (Dimension) THEN
        REPEAT
            INC (Count);
        UNTIL NOT NextPos (Dimension);
    END;
    RETURN Count;
END NumberOfRecords;





PROCEDURE DoHeadingSetup    (   Dimension       : CARDINAL;
                                DefineColumn    : ADefineColumnProc );

(*  Count the number of items in this dimension, and then re-read the first
    heading record to get the data types of its fields.  Define one column
    per heading field, using the supplied proc.
*)

VAR
    i               : CARDINAL;
    s               : ARRAY [0..50] OF CHAR;
    s2              : ARRAY [0..10] OF CHAR;
    HeadingRecord   : AHeadingRecord;
    Type            : CARDINAL;
    Data            : AnIntDataRecord;

BEGIN
    WITH DomainInfo[Dimension] DO
        ItemCount := NumberOfRecords (Dimension);
        AggCount := 0;
    END;

    IF (NOT ResetPos(Dimension)) THEN
        RETURN;
    END;

    IF (TotalDimensions < 2) THEN
        RETURN;              (* We only write headings for 2+ dimensions *)
    END;

    ReadRecordBody (InterFile, SIZE(HeadingRecord), ADR(HeadingRecord),
                    SIZE(HeadingRecord));
    FOR i := 1 TO HeadingRecord.HeadingDepth DO
        ReadIntData (Type, Data);
        Copy (DomainInfo[Dimension].DomainRecord.DimensionName, s);

        (* Attach a number to any label after the first (per dimension). *)

        IF (i > 1) THEN
            CtoS (i, s2);
            ConcatLS (s, s2);
        END;
        DefineColumn (s, Type, NullFormat, DomainInfo[Dimension].DomainRecord.Width);
    END;
END DoHeadingSetup;





PROCEDURE DoPredicateSetup  (   DefineColumn    : ADefineColumnProc  );

(*  Count the predicates, and define one column per predicate record. *)

VAR
    i                   : CARDINAL;
    PredicateRecord     : APredicateRecord;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;
    s                   : ARRAY [0..40] OF CHAR;
    WhoCares            : AFilePosition;
    Version             : CARDINAL;

BEGIN

    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        ErrorFlag := TRUE;
        RETURN;
    END;

    DomainInfo[0].ItemCount := 0;

    WHILE FindRecord (PredicateRecordType, WhoCares) DO

        INC (DomainInfo[0].ItemCount);
        ReadRecordBody (InterFile, SIZE(PredicateRecord), ADR(PredicateRecord),
                        SIZE(PredicateRecord));
        WITH PredicateRecord DO
            DefineColumn (Name, DataType, Format, Width);
        END;

    END;

END DoPredicateSetup;




PROCEDURE DoAggregateSetup();

VAR
    i                   : CARDINAL;
    AggregateRecord     : AnAggregatorRecord;
    WhoCares            : AFilePosition;
    Version             : CARDINAL;

BEGIN
    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        ErrorFlag := TRUE;
        RETURN;
    END;

    WHILE (FindRecord (AggregatorRecordType, WhoCares)) DO

        ReadRecordBody (InterFile, SIZE(AggregateRecord), ADR(AggregateRecord),
                        SIZE(AggregateRecord));
        WITH AggregateRecord DO
            FOR i := 1 TO TotalDimensions DO
                IF (i IN Dimensions) THEN
                    INC (DomainInfo[i].AggCount);
                    DEC (DomainInfo[i].ItemCount);
                END;
            END;
        END;

    END;

END DoAggregateSetup;




PROCEDURE WriteHeadings (   Dimension   : CARDINAL;
                            WriteData   : AWriteDataProc    );
VAR
    Type            : CARDINAL;
    Data            : AnIntDataRecord;
    i               : CARDINAL;
    HeadingRecord   : AHeadingRecord;

BEGIN
    SetFilePosition (DomainInfo[Dimension].HFilePos);

    ReadRecordBody (InterFile, SIZE(HeadingRecord), ADR(HeadingRecord),
                    SIZE(HeadingRecord));
    FOR i := 1 TO HeadingRecord.HeadingDepth DO
        ReadIntData (Type, Data);
        WriteData (Type, Data, NullFormat);
    END;
END WriteHeadings;




PROCEDURE WritePredicates ( WriteData       : AWriteDataProc;
                            WriteNull       : AWriteNullProc    );

(*  Write all the predicate data for this point, by fetching one predicate
    record at a time from the predicate subfile, and then a corresponding
    data value from the data subfile.
*)

VAR
    Position            : AFilePosition;
    Version             : CARDINAL;
    WhoCares            : AFilePosition;
    PredicateRecord     : APredicateRecord;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;

BEGIN

    IF (NOT StartSubfileInput (InterFile, PredicateSubfileNumber, Version)) THEN
        ErrorFlag := TRUE;
        RETURN;
    END;

    WHILE FindRecord (PredicateRecordType, WhoCares) DO

        ReadRecordBody (InterFile, SIZE(PredicateRecord), ADR(PredicateRecord),
                        SIZE(PredicateRecord));
        GetFilePosition (Position);
        SetFilePosition (DataPos);

        ReadIntData (Type, Data);

        GetFilePosition (DataPos);
        SetFilePosition (Position);

        IF (Type = SkipRecordType) THEN
            WriteNull (PredicateRecord.DataType, PredicateRecord.Format);
        ELSE
            WriteData (Type, Data, PredicateRecord.Format);
        END;
    END;

END WritePredicates;




(*  Move us to the next position in the matrix, by incrementing the
    index of the least significant dimension and carrying to higher
    dimensions if necessary.
*)

PROCEDURE Advance () : BOOLEAN;

VAR
    CurrDim         : CARDINAL;

BEGIN
    CurrDim := TotalDimensions;        (* Start with the least significant *)

    LOOP
        IF (CurrDim = 0) THEN
            RETURN FALSE;         (* The highest dimension has carried out *)
        END;

        WITH DomainInfo[CurrDim] DO

            IF (CurrentPos = ItemCount) AND (AggCount > 0) THEN
                Agging := TRUE;         (* Switch to aggregate (skip) mode *)
            END;

            IF (CurrentPos < ItemCount) THEN        (* No carry *)

                IF (NOT NextPos (CurrDim)) THEN
                    ErrorFlag := TRUE;
                    RETURN FALSE;
                END;
                RETURN TRUE;

            ELSE                (* Reset this index to 1 and try the
                                   next higher dimension *)

                IF (NOT ResetPos (CurrDim)) THEN
                    ErrorFlag := TRUE;
                    RETURN FALSE;
                END;
                DEC (CurrDim);

            END;
        END;
    END;
END Advance;




PROCEDURE DataExists () : BOOLEAN;

(*  Take a peek at the next data record without updating the file marker.
    Return whether or not it is a skip record.
*)

VAR
    Position            : AFilePosition;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;

BEGIN
    IF (TotalDimensions = 1) THEN
        RETURN TRUE;                (* Don't skip in the 1-D case *)
    END;

    GetFilePosition (Position);
    SetFilePosition (DataPos);
    ReadIntData (Type, Data);
    SetFilePosition (Position);

    RETURN (Type <> SkipRecordType);
END DataExists;





PROCEDURE SkipPredicates();

VAR
    i                   : CARDINAL;
    Type                : CARDINAL;
    Data                : AnIntDataRecord;

BEGIN

    SetFilePosition (DataPos);
    FOR i := 1 TO DomainInfo[0].ItemCount DO
        ReadIntData (Type, Data);
    END;
    GetFilePosition (DataPos);

END SkipPredicates;




PROCEDURE ExportNormalData  (    OpenFile        : AnOpenFileProc;
                                 CloseFile       : ACloseFileProc;
                                 BeginRecord     : ABeginRecordProc;
                                 EndRecord       : AnEndRecordProc;
                                 DefineColumn    : ADefineColumnProc;
                                 WriteData       : AWriteDataProc;
                                 WriteNull       : AWriteNullProc    );
VAR
    i               : CARDINAL;
    SkipCount       : CARDINAL;
    Version         : CARDINAL;
    FileName        : ARRAY [0..70] OF CHAR;
    Type            : ADataType;
    Data            : AnIntDataRecord;
    TotalRecords    : CARDINAL;
    StatusCount     : CARDINAL;
    s               : ARRAY [0..255] OF CHAR;
    Thermometer     : AThermometer;
    ThermOK         : BOOLEAN;

BEGIN
    ErrorFlag := FALSE;
    GetOverallInfo();

    Copy (ExportMedia, FileName);
    ConcatLS (FileName, ExportName);
    IF (NOT OpenFile (FileName)) THEN
        RETURN;
    END;

    FOR i := 1 TO TotalDimensions DO
        DoHeadingSetup (i, DefineColumn);
    END;

    DoPredicateSetup (DefineColumn);
    DoAggregateSetup ();

    IF (NOT StartSubfileInput (InterFile, 3+TotalDimensions, Version)) THEN
        ErrorFlag := TRUE;
        CloseFile();
        RETURN;
    END;

    GetFilePosition (DataPos);

    Agging := FALSE;
    StatusCount := 0;
    TotalRecords := 1;
    FOR i := 1 TO TotalDimensions DO
        TotalRecords := TotalRecords * DomainInfo[i].ItemCount;
    END;

    IF (TotalRecords = 0) THEN
        CloseFile();
        RETURN;
    END;

    IF ( TotalDimensions = 1 ) THEN                                 (* 5-Sep-89 MWP *)
        GetMessage (ModuleNumber+1, s);         (* "records written" *)
    ELSE
        GetMessage ( ModuleNumber + 3, s );     (* "fields written" *)
    END;

    ThermOK := CreateThermometer (Thermometer, 0, 0, s, TotalRecords);

    LOOP
        IF (ErrorFlag) THEN
            GetMessage (ModuleNumber+2, s);     (* "Error writing the file" *)
            Error (s);
            EXIT;
        END;

        (* If the aggregate flag is set, then we must skip over data
           until we reach a real (non-aggregate) data record.  We will
           then switch off the aggregate flag (without advancing the
           data subfile's marker, since that record must be re-read)
           and continue.     *)

        IF (Agging) THEN
            SetFilePosition (DataPos);
            ReadIntData (Type, Data);
            IF (ORD(Data.Font) > 127) THEN        (* Not an aggregator *)
                GetFilePosition (DataPos);
            ELSE
                Agging := FALSE;
            END;
        END;

        IF (NOT Agging) THEN

            (*  This test allows us to write only those records for which
                there is valid data (i.e. not a skip).      *)

            IF DataExists() THEN
                BeginRecord();
                IF (TotalDimensions > 1) THEN
                    FOR i := 1 TO TotalDimensions DO
                        WriteHeadings (i, WriteData);
                    END;
                END;
                WritePredicates (WriteData, WriteNull);
                EndRecord();
            ELSE
                SkipPredicates();
            END;

            INC (StatusCount);
            UpdateThermometer (Thermometer, StatusCount);

            IF (NOT Advance()) THEN
                EXIT;                   (* All done! *)
            END;
        END;
    END;

    DiscardThermometer (Thermometer);

    CloseFile();

END ExportNormalData;


BEGIN
    WITH NullFormat DO
        FormatType := FText;
        DecimalDigits := CHR(0);
    END;
END NormalExport.
