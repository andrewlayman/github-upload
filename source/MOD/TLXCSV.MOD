MODULE TLXCSV;

  (* TL X CSV - Output report data to a CSV file format.

        MODIFICATION HISTORY:

        MWP    1-May-89  -  Trim off spaces from Formal Names.

        MWP    2-May-89  -  Change maximum number of columns output from
                            100 to 110 to account for outputting all task
                            columns. Actually, this should not be a
                            hard coded constant, but rather, should be based
                            on the maximum number of columns available from
                            MagicNum.

        MWP    3-May-89  -  Output a new record type, -105, to
                            CSV format. This type indicates the seperator
                            character to use.

        MWP    5-Jul-89     Import "IsImportable" from ExportLinkage. This
                            boolean tells us whether the user wished the CSV
                            data to be formatted for re-import to Timeline, or
                            should it go out in a 'universal' CSV format.

        MWP    7-Jul-89     Fixed bug which was causing exporting of a maximum
                            line length of 120 characters no matter what the
                            user had selected. This bug was induced by a change
                            to TLSETCSV which was not reflected in other
                            modules which consort with said module. Hmmm.
        MWP    7-Jul-89     Removed unnecessary imports and formatted a
                            bit ( sic ).
        MWP   10-Jul-89     Output column type 7 for all date formats.
        MWP   11-Jul-89     Support FPercent format type. As all percentage
                            values are stored as fractionals, i.e 10% = .1,
                            we force decimal output to a least 1 decimal
                            place.

        KKC    9-Aug-89     Add copyright message.
        MWP    6-Sep-89     Added support for null fields when exporting.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
        17-Sep-91 AJL   Use WriteBoolean.
   *)


FROM BigTimeU       IMPORT
    (* TYPE *)              ABigTime;

FROM CSVExport      IMPORT
    (* VAR *)               FieldDelimiter, LastFieldNull,
    (* PROC *)              OpenFile, CloseFile, StartRecord, EndRecord,
                            WriteText, WriteCardinal, WriteReal, WriteEmpty,
                            WriteStartDate, WriteEndDate, WriteBigTime,
                            WriteBoolean;

FROM Dialog         IMPORT
    (* PROC *)              FatalError;

FROM ExportLinkage  IMPORT
                            IsImportable;                          (* 5-Jul-89 MWP *)

FROM Holder         IMPORT
    (* TYPE *)              AHoldTypeSet,
    (* PROC *)              LocateHeldItem;

FROM IntFileIO      IMPORT
    (* CONST *)             TextType, RealNumberType, IntegerType,
                            CardinalType, BooleanType,
                            BigStartTimeType, BigEndTimeType,
                            StartDateType, EndDateType, EnumeratedType,
    (* TYPE *)              ADataType,
                            AFormatType,
                            AnIntDataRecord, AFormat;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, SetString, StoC, Copy,
                            TrimRear;

FROM Menus          IMPORT
    (* PROC *)              WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM NormalExport   IMPORT
    (* PROC *)              ExportNormalData;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM TaskColNumbers IMPORT
    (* CONST *)             HighestRootColumn;

FROM Timei          IMPORT
    (* CONST*)              MinDate,
    (* TYPE *)              ADate;


CONST
    Zero            = 0.0;

    SeperatorHeader = -105.0;
    CountHeader     = -110.0;
    NameHeader      = -120.0;
    TypeHeader      = -130.0;
    DataHeader      = -900.0;
    ModuleNumber    = 24400;
    MaxColumns      = HighestRootColumn;
TYPE
    AProgramState   = (AtStart,Defining,Writing);

    AColumnRecord   = RECORD
                        Name        : ARRAY [0..20] OF CHAR;
                        Type        : CARDINAL;
                      END;

VAR
    NullData            : AnIntDataRecord;
    ProgramState        : AProgramState;
    Columns             : ARRAY [1..MaxColumns] OF AColumnRecord;
    ColumnCount         : CARDINAL;




PROCEDURE OpenCSVFile( VAR Name    : ARRAY OF CHAR ) : BOOLEAN;

VAR
    MenuString      : ARRAY [0..50] OF CHAR;
    Selection       : CARDINAL;
    i               : CARDINAL;
    s               : ARRAY [0..40] OF CHAR;
    LineLength      : CARDINAL;


    PROCEDURE GetLengthSelection ( VAR WhichChoice : CARDINAL ) : BOOLEAN;

    CONST
        LengthName      = "CSVLength";
        LengthClass     = 64;            (* A very good year *)
    VAR
        HoldName        : ARRAY [0..20] OF CHAR;
        Category        : AHoldTypeSet;
        Where           : ADDRESS;
        Where1          : POINTER TO CARDINAL;
        ok : BOOLEAN;

    BEGIN
        SetString (HoldName, LengthName);

        ok := LocateHeldItem (HoldName, LengthClass, Category,
                               Where1, WhichChoice);
        IF ( ok ) THEN
           WhichChoice := Where1^;
        END;

        RETURN ( ok );

    END GetLengthSelection;


BEGIN
    IF (NOT GetLengthSelection (Selection)) THEN
        LineLength := 0;
    ELSE
        GetMessage (ModuleNumber+3, MenuString);            (* "80,120,250" *)
        WordNumber (MenuString, Selection, s);
        i := 1;
        LineLength := StoC (s, i);
        IF (LineLength > 0) THEN
            DEC (LineLength);                       (* For safety *)
        END;
    END;

    RETURN OpenFile (Name, LineLength);

END OpenCSVFile;




PROCEDURE DefineColumn( VAR Name    : ARRAY OF CHAR;
                            Type    : ADataType;
                            Format  : AFormat;
                            Width   : CARDINAL      );

BEGIN

    (*  Just buffer the data.  We will write this out after all the columns
        have been defined.
    *)

    INC (ColumnCount);
    Copy (Name, Columns[ColumnCount].Name);
    Columns[ColumnCount].Type := Type;

END DefineColumn;




PROCEDURE StartCSVRecord();

VAR
    i               : CARDINAL;

BEGIN
    IF (ProgramState < Writing) AND
       ( IsImportable ) THEN                                         (* 5-Jul-89 MWP *)
        ProgramState := Writing;

            (*  This is the first record, so we need to write out all the
                previously stored header information.
                First, the number of columns:
            *)

        StartRecord();
        WriteReal (SeperatorHeader, 0);
        WriteCardinal(ORD(FieldDelimiter));
        EndRecord();

        StartRecord();
        WriteReal (CountHeader, 0);
        WriteCardinal (ColumnCount);
        EndRecord();

            (* Now the column names *)

        StartRecord();
        WriteReal (NameHeader, 0);
        FOR i := 1 TO ColumnCount DO
            TrimRear (Columns[i].Name);                             (* 5-Jul-89 MWP*)
            WriteText (Columns[i].Name);
        END;
        EndRecord();

            (* And the column types *)

        StartRecord();
        WriteReal (TypeHeader, 0);
        FOR i := 1 TO ColumnCount DO
            WriteCardinal (Columns[i].Type);
(******
            IF (Columns[i].Type > 7 ) THEN                          (* 10-Jul-89 MWP *)
               WriteCardinal ( 7 );
            ELSE
               WriteCardinal (Columns[i].Type);
            END;
*******)
        END;
        EndRecord();
    END;


    StartRecord();

    IF ( IsImportable ) THEN                                        (* 5-Jul-89 MWP *)
       WriteReal (DataHeader,0);
    END;

END StartCSVRecord;





PROCEDURE WriteData(     Type       : ADataType;
                     VAR Data       : AnIntDataRecord;
                         Format     : AFormat         );
BEGIN


    CASE Type OF
        BooleanType :
            WriteBoolean( Data.Boolean );

    |   TextType, EnumeratedType :
            WriteText (Data.LString);

    |   RealNumberType :
            CASE Format.FormatType OF
                FNumeric,
                FCurrency :
                      WriteReal (Data.Real, ORD(Format.DecimalDigits));

            |   FPercent :                                           (* 11-Jul-89 MWP *)
                      WriteReal (Data.Real, 2);
            ELSE
                      WriteReal (Data.Real, ORD(Format.DecimalDigits));
            END;

    |   IntegerType    :
            WriteCardinal (CARDINAL(Data.Integer));

    |   CardinalType   :
            WriteCardinal (Data.Cardinal);

    |   BigStartTimeType, BigEndTimeType :
            WriteBigTime (Data.BigTime);

    |   StartDateType  :
            WriteStartDate (Data.Date);

    |   EndDateType    :
            WriteEndDate (Data.Date);

    ELSE
            FatalError();
    END;

    LastFieldNull := FALSE;

END WriteData;



PROCEDURE WriteNull(     Type       : ADataType;
                         Format     : AFormat         );
VAR
    Copyright                      : ARRAY[0..50] OF CHAR;
    i                              : CARDINAL;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    i := 1;

    CASE Type OF
        BigStartTimeType, BigEndTimeType,
        StartDateType,    EndDateType     :
               i := 5;
    ELSE
    END;

    WriteEmpty ( i );

    LastFieldNull := TRUE;

END WriteNull;



BEGIN

    WITH NullData DO
        Integer := 0;
        Cardinal := 0;
        Real := Zero;
        Date := MinDate;
        BigTime := ABigTime(0:0);
        Boolean := FALSE;
        SetLengthOf (LString,0);
    END;

    ProgramState := AtStart;
    ColumnCount := 0;

    ExportNormalData (OpenCSVFile, CloseFile, StartCSVRecord, EndRecord,
                      DefineColumn, WriteData, WriteNull);

END TLXCSV.

