IMPLEMENTATION MODULE ArtExport;

(*  MODIFICATION HISTORY --
     9-Dec-91 TGS   Adjustments for TL 5.0.  Move hard coded strings to 
                    Phrases.
*)

FROM Allocs                 IMPORT 
    (* CONST *)                 WBSLine, AUXLine,
    (* PROC *)                  GetCodingField,
    (* TYPE *)                  ATaskPtr;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  BigTimeToTime;

FROM Dialog                 IMPORT
    (* PROCS *)                 Error, FatalError; (* RSC 9/12/88 *)

FROM FileSystem             IMPORT
    (* CONST *)                 ArchiveAttribute,
    (* TYPE *)                  File, Response,
    (* PROC *)                  Lookup, WriteByte, Close, Delete,
                                SetAttribute;
                    
FROM FileAux                IMPORT
    (* PROC *)                  DisplayFileError, PrepareForIO, CheckIO;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, LJust, TrimRear, SetString, Search,
                                LStringToTString, CtoS, SetLengthOf,
                                ConcatS, ConcatLS, RJust, LengthOf, Copy;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  ConcatMessage, GetMessage;

FROM RealFormat             IMPORT
    (* TYPE *)                  AnAmountFormat,
    (* PROC *)                  FormatAsAmount;

FROM TimeFormat             IMPORT 
    (* VAR *)                   EndDateStyle,
    (* PROC *)                  TimeAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE *)                  ADuration, ADate, ATimeInfo,
    (* PROC *)                  TimeUtoT, DayOfWeek;

FROM Timeu                  IMPORT
    (* VAR *)                   TimeTable, SMUPH;

FROM XArTable               IMPORT
    (* TYPES *)                 AnArtemisExportTable,
                                AnArtemisType, AnActivityIDSource,
                                AnArtemisCalendarType,
                                AnArtemisPeriodType;

CONST
    cCarriageReturn = 15C;
    cLineFeed       = 12C;
    HeaderLength    = 3;        (* Leading spaces on second lines *)
    ModuleNumber    = 27200;

TYPE
    AWarningType    = (WBSTruncation, NoWBS, WriteError);
    AWarningTypeSet = SET OF AWarningType;


VAR
    f               : File;
    LineLength      : CARDINAL;
    MaxLineLength   : CARDINAL;
    WarningTypeSet  : AWarningTypeSet;
    TName           : ARRAY [0..99] OF CHAR;    (* TString *)
    StartNewLine    : BOOLEAN;   (* if TRUE, we are on a continuation line
                                    of an Artemis 6000 or 9000 record *)                                  

        (* Global rule for how to format real numbers. *)

    AmountFormat    : AnAmountFormat;


PROCEDURE FatalWriteError(): BOOLEAN;

BEGIN
    RETURN ( WriteError IN WarningTypeSet );
END FatalWriteError;


  (* RSC 9/12/88:  Added a seres of warning messages that only appear ONCE.
                   THESE SHOULD BE PUT IN THE PHRASES FILE!
  *)

PROCEDURE Warning( WarningType : AWarningType );
VAR
    s : ARRAY [0..255] OF CHAR;
BEGIN
    IF (WarningType IN WarningTypeSet) THEN
        RETURN;
    END;

    INCL( WarningTypeSet, WarningType );

    CASE WarningType OF
      WBSTruncation:
          GetMessage(ModuleNumber+1,s);  (* "WARNING:üTruncating some WBS numbers or Keywords." *)
    | NoWBS:
          GetMessage(ModuleNumber+2,s);  (* "WARNING:üSome WBS numbers or Keywords are missing.üUsing Sequence number for those tasks." *)
    | WriteError:
          SetLengthOf (s,0);
          DisplayFileError (f,s);
    ELSE
        FatalError();
    END;
    Error(s);
END Warning;


PROCEDURE CheckFileStatus ()    : BOOLEAN;

VAR

BEGIN
    IF (CheckIO(f) = done) THEN
        RETURN TRUE;
    ELSE
        Warning( WriteError );
        Delete(TName, f);
        RETURN FALSE;
    END;
END CheckFileStatus;



PROCEDURE OpenFile      ( VAR   Name        : ARRAY OF CHAR;
                                LineLength  : CARDINAL      ) : BOOLEAN;
BEGIN
    MaxLineLength := LineLength;
    LStringToTString (Name, TName);
    PrepareForIO (f);
    Delete (TName, f);
    PrepareForIO (f);
    Lookup (f, TName, TRUE);
    StartNewLine := FALSE;
    WarningTypeSet  := AWarningTypeSet{}; 
    RETURN CheckFileStatus();
END OpenFile;



PROCEDURE CloseFile();
BEGIN
    IF (CheckFileStatus()) THEN END;
    Close (f);
    SetAttribute (TName, ArchiveAttribute, f);
END CloseFile;



PROCEDURE StartRecord();
BEGIN
    LineLength := 0;
END StartRecord;



PROCEDURE EndRecord();
BEGIN
    WriteNewline;
    StartNewLine := FALSE;
END EndRecord;




PROCEDURE OutputLString (VAR s : ARRAY OF CHAR);

VAR
    i : CARDINAL;
    C : CHAR;

BEGIN
    IF (CheckFileStatus()) THEN END;
    FOR i := 1 TO ORD(s[0]) DO
        C := s[i];
        IF (C='"') THEN
            C := "'";
        END;
        WriteByte(f,C);
    END;
(*    LineLength := LineLength + ORD(s[0]); *)
END OutputLString;


PROCEDURE WriteNewline();

BEGIN
    IF (CheckFileStatus()) THEN END;
    WriteByte(f, cCarriageReturn);
    WriteByte(f, cLineFeed);
END WriteNewline;


PROCEDURE WriteTLine (s : ARRAY OF CHAR);

VAR
    i : CARDINAL;
            
BEGIN
    IF (CheckFileStatus()) THEN END;
    StartRecord();
    i := 0;
    WHILE ( (i <= HIGH(s)) AND (s[i] <> 0C) ) DO
        WriteByte(f,s[i]);
        i := i + 1;
    END;
    EndRecord();
END WriteTLine;


PROCEDURE CheckLineLength(ExportTable: AnArtemisExportTable;
                          i : CARDINAL);

VAR
    s               : ARRAY [0..20] OF CHAR;
    B               : ARRAY [0..4] OF CHAR;

BEGIN

    IF (CheckFileStatus()) THEN END;
    IF (LineLength > 0) THEN
        IF (MaxLineLength > 0) AND (LineLength + i >= MaxLineLength) THEN
            WriteNewline;
            Fill (s, " ", HeaderLength);
            OutputLString (s);
            LineLength := HeaderLength;
        ELSE
            IF ((ExportTable.ArtemisType = A6000) OR
                (ExportTable.ArtemisType = A9000)) THEN
                WriteByte(f," ");
            ELSE
                WriteByte(f,",");
            END;
            INC(LineLength);
        END;
    END;

    INC(LineLength,i);

    IF (StartNewLine) THEN
        EndRecord();
        StartRecord();
        (*
        SetString(B, " B ");
        *)
        (* "ModuleNumber + 10" *)
        GetMessage(27210, B);
        OutputLString(B);
        LineLength := 2;
        StartNewLine := FALSE;
    END;

END CheckLineLength;




PROCEDURE WriteCardinal(ExportTable:AnArtemisExportTable;
                        c: CARDINAL);
VAR
    s           : ARRAY [0..30] OF CHAR;
BEGIN
    CtoS(c,s);
    CheckLineLength(ExportTable,ORD(s[0]));
    OutputLString(s);
END WriteCardinal;



(* WriteTaskId - Write a task ID as either a sequence number or the WBS number
                 depending on what the user requested.  Add an optional
                 single suffix character if we were passed non-null Suffix
                 string .  The TaskID can never be longer than 8 characters
                 so truncate as necessary.
                 The suffix is used for tagging start and end milestones of
                 hammocks.
*)

PROCEDURE GetTaskID (   pTask       : ATaskPtr;
                        ExportTable : AnArtemisExportTable;
                        IDType      : AnArtemisTaskIDType;
                    VAR s           : ARRAY OF CHAR         );
VAR
    s1,s2,s3        : ARRAY [0..30] OF CHAR;
    AdjustedNumber  : CARDINAL;
    AdjustedWBS,
    TempWBS         : ARRAY [0..30] OF CHAR;
   
BEGIN

    Copy(ExportTable.ActivityPrefix, AdjustedWBS);
    TrimRear(AdjustedWBS);

    CASE IDType OF
        Normal:
            AdjustedNumber := pTask^.count;
    |   StartHammock:
            AdjustedNumber := pTask^.count + 1;  (* the following task *)
    |   FinishHammock:
            AdjustedNumber := pTask^.count + 2;  (* the task plus two *)
    |   StartProject:
            AdjustedNumber := 2;                 (* always number 1 *)
    |   ProjectHammock:
            AdjustedNumber := 1;                 (* always number 2 *)
    |   FinishProject:
            AdjustedNumber := 3;                 (* always number 3 *)
    ELSE
    END;
    IF (ExportTable.ActivityIDSource = SequenceNumber) THEN
        CtoS(AdjustedNumber,s2);
        Fill(s3,"0",4 - LengthOf(s2));
        ConcatLS(AdjustedWBS,s3);
        ConcatLS(AdjustedWBS,s2);
    ELSE (* If is either based on the WBS or the Keyword *)
        (* Construct a reasonable WBS for the phantom tasks *)
        CASE IDType OF
            Normal, StartHammock, FinishHammock:

                IF (ExportTable.ActivityIDSource = WBSCode) THEN
                    GetCodingField(pTask^,WBSLine,s1);       
                    ConcatLS(AdjustedWBS,s1);
                    Copy(s1,TempWBS);
                ELSE
                    GetCodingField(pTask^,AUXLine,s1);
                    ConcatLS(AdjustedWBS,s1);
                    Copy(s1,TempWBS);
                END;

                TrimRear(AdjustedWBS);
                TrimRear(TempWBS); (* just used to detect if code is blank *)

                IF ( LengthOf(TempWBS) = 0) THEN 
                    (* Task WBS had zero length, so create one from seq # *)
                    CtoS(AdjustedNumber,s2);  
                    Fill(s1,"0",4 - LengthOf(s2));
                    ConcatLS(AdjustedWBS,s1);
                    ConcatLS(AdjustedWBS,s2);
                    Warning( NoWBS );  (* RSC 9/12/88 *)
                END;
                
                CASE IDType OF
                  Normal:
                    IF (LengthOf(AdjustedWBS) >8) THEN
                        SetLengthOf(AdjustedWBS,8);
                        Warning( WBSTruncation );  (* RSC 9/12/88 *)
                    END;
                | StartHammock:
                    IF (LengthOf(AdjustedWBS) >7) THEN
                        SetLengthOf(AdjustedWBS,7);
                        Warning( WBSTruncation );  (* RSC 9/12/88 *)
                    END;
                    (*
                    ConcatS(AdjustedWBS, "S");
                    *)
                    ConcatMessage(AdjustedWBS, 27215);
                | FinishHammock:
                    IF (LengthOf(AdjustedWBS) >7) THEN
                        SetLengthOf(AdjustedWBS,7);
                        Warning( WBSTruncation );  (* RSC 9/12/88 *)
                    END;
                    (*
                    ConcatS(AdjustedWBS, "F");
                    *)
                    ConcatMessage(AdjustedWBS, 27216);
                END;
        |   StartProject:
                ConcatLS(AdjustedWBS,ExportTable.FileName);
                TrimRear(AdjustedWBS);
                (*
                ConcatS(AdjustedWBS, "S");
                *)
                ConcatMessage(AdjustedWBS, 27215);
        |   ProjectHammock:
                ConcatLS(AdjustedWBS,ExportTable.FileName);
                TrimRear(AdjustedWBS);
        |   FinishProject:
                ConcatLS(AdjustedWBS,ExportTable.FileName);
                TrimRear(AdjustedWBS);
                (*
                ConcatS(AdjustedWBS, "F");
                *)
                ConcatMessage(AdjustedWBS, 27216);
        ELSE
        END;
    END;
    Copy (AdjustedWBS, s);
END GetTaskID;



PROCEDURE WriteTaskID ( pTask       : ATaskPtr;  
                        ExportTable : AnArtemisExportTable;
                        IDType      : AnArtemisTaskIDType;
                        BreakLine   : BOOLEAN               );
VAR
    s           : ARRAY [0..40] OF CHAR;
BEGIN
    GetTaskID (pTask, ExportTable, IDType, s);
    WriteText (ExportTable, s, BreakLine);
END WriteTaskID;



PROCEDURE WriteReal     ( ExportTable:AnArtemisExportTable;
                          R         : REAL;
                          Digits    : CARDINAL  );
VAR
    S       : ARRAY [0..30] OF CHAR;
    S2      : ARRAY [0..1] OF CHAR;
    i       : CARDINAL;

BEGIN


    FormatAsAmount (R, AmountFormat, S, HIGH(S), 0, Digits, FALSE); (* RSC 9/12/88 *)
    LJust(S);
    TrimRear(S);

    CheckLineLength(ExportTable,ORD(S[0]));
    OutputLString(S);
END WriteReal;


PROCEDURE WriteText (    ExportTable    : AnArtemisExportTable;
                     VAR s              : ARRAY OF CHAR;
                         BreakLine      : BOOLEAN               );
            
BEGIN
    IF (CheckFileStatus()) THEN END;
    CheckLineLength(ExportTable,ORD(s[0])+2);

    IF ((ExportTable.ArtemisType = A6000) OR
        (ExportTable.ArtemisType = A9000) ) THEN
        IF ( LengthOf(s) > 0 ) THEN
            OutputLString(s);
            LineLength := LineLength + LengthOf(s);
        ELSE
            WriteByte(f,"0");
            LineLength := LineLength + 1;
        END;

        StartNewLine := BreakLine;
    ELSE
        IF ( LengthOf(s) > 0 ) THEN      (* We want this NOT to write the quotes
                                            if the string has zero length *)
            WriteByte(f, '"');
            OutputLString(s);
            WriteByte(f, '"');
            LineLength := LineLength + 2+ LengthOf(s);
        END;
    END;
END WriteText;


PROCEDURE FractionOfDayWorked(ThisTime : ATimeInfo): REAL;

VAR
    QHour       : CARDINAL;
    WorkCount,
    DayCount    : REAL;

BEGIN
    DayCount  := 0.0;
    WorkCount := 0.0;

    WITH ThisTime DO
    FOR QHour := 0 TO 95 DO
        IF (QHour IN TimeTable.WeekTable[DayOfWeek(tiYear, tiMonth, tiDay)].WeekMap ) THEN
            DayCount := DayCount + 0.25;
            IF (tiHour <= QHour) THEN
                WorkCount := WorkCount + 0.25;
            END;
        END;
    END;
    END; (* WITH *)

    IF (WorkCount > 0.0) THEN
        WorkCount := WorkCount - 1.0;
    END;

    RETURN WorkCount/DayCount;

END FractionOfDayWorked;


PROCEDURE WriteDate(     ExportTable : AnArtemisExportTable;
                         ThisTime    : ATimeInfo);
VAR
    NumberOfPeriods, 
    NumberOfDays                  : REAL;
    s,s1                          : ARRAY [0..30] OF CHAR;
    s2                            : ARRAY [0..255] OF CHAR;
BEGIN
    WITH ThisTime DO
        CtoS(tiDay,s);

        (*
        SetString(s2, "-JAN-,-FEB-,-MAR-,-APR-,-MAY-,-JUN-,-JUL-,-AUG-,-SEP-,-OCT-,-NOV-,-DEC-");
        *)
        (* "ModuleNumber + 11" *)
        GetMessage(27211, s2);
        WordNumber(s2, tiMonth+1, s1);
        ConcatLS(s, s1);

        CtoS(tiYear, s1);
        ConcatLS(s, s1);


        IF (ExportTable.CalendarType = Period) THEN
        (* Compute the fraction of a day to be expressed in periods *)
            IF (ExportTable.PeriodType = PerDay) THEN
                (*
                ConcatS(s, ":");
                *)
                ConcatMessage(s, 27217);
                NumberOfPeriods := FractionOfDayWorked(ThisTime) 
                                   * FLOAT(ExportTable.PeriodSize);
                CtoS(TRUNC(NumberOfPeriods+0.5), s1);
                ConcatLS(s, s1);
            END;
        ELSE
            (*
            ConcatS(s, ":");
            *)
            ConcatMessage(s, 27217);
            CtoS(tiHour, s1);
            ConcatLS(s, s1);
       
            (*
            ConcatS(s, ":");
            *)
            ConcatMessage(s, 27217);
     
            CtoS(tiMinute, s1);
            ConcatLS(s, s1);
        END;

        CheckLineLength(ExportTable, LengthOf(s));
        OutputLString(s);
    END;    (* WITH *)

END WriteDate;


PROCEDURE WritePureDate(    ExportTable     : AnArtemisExportTable;
                            year, month, day: CARDINAL );
VAR
    s,s1                          : ARRAY [0..30] OF CHAR;
    s2                            : ARRAY [0..255] OF CHAR;
BEGIN

    CtoS(day,s);

    (*
    SetString(s2, "-JAN-,-FEB-,-MAR-,-APR-,-MAY-,-JUN-,-JUL-,-AUG-,-SEP-,-OCT-,-NOV-,-DEC-");
    *)
    (* "ModuleNumber + 11" *)
    GetMessage(27211, s2);
    WordNumber(s2, month+1,s1);
    ConcatLS(s,s1);

    CtoS(year,s1);
    ConcatLS(s,s1);

    CheckLineLength(ExportTable,LengthOf(s));
    OutputLString(s);

END WritePureDate;





PROCEDURE WriteStartDate    (   ExportTable : AnArtemisExportTable;
                                Date        : ADate                 );

VAR
    year, month, day, hour, minute: CARDINAL;
    ThisTime    : ATimeInfo;
BEGIN
    TimeUtoT(Date, ThisTime);
    WriteDate( ExportTable, ThisTime);
END WriteStartDate;




PROCEDURE WriteEndDate    (   ExportTable: AnArtemisExportTable;
                              Date       : ADate                 );

VAR
    ThisTime    : ATimeInfo;
BEGIN
    TimeAsEndDateStyle (Date, EndDateStyle, ThisTime);
    WriteDate( ExportTable, ThisTime);
END WriteEndDate;


PROCEDURE WriteDuration( ExportTable: AnArtemisExportTable;
                         Plus       : BOOLEAN;       (* + or - duration *)
                         Time       : ADuration);
VAR
    SMUPerDay, 
    Days,
    SMUPerPeriod,
    NumberOfPeriods : REAL;
    S, S2           : ARRAY [0..100] OF CHAR;
BEGIN

    IF ( ExportTable.CalendarType = Period ) THEN
        Days := FLOAT(Time) / ( FLOAT(TimeTable.StdDayTics) * FLOAT(SMUPH) );
        IF ( ExportTable.PeriodType = PerDay ) THEN        
            NumberOfPeriods := Days * FLOAT(ExportTable.PeriodSize);
        ELSE
            NumberOfPeriods := Days / FLOAT(ExportTable.PeriodSize);
        END;
        IF (NOT Plus) THEN
           NumberOfPeriods := - NumberOfPeriods;
        END;
        WriteReal(ExportTable,NumberOfPeriods,0);  
    ELSE  (* Durations are in Hours or Days *)
        IF (ExportTable.CalendarType = DateHours) THEN
            NumberOfPeriods := FLOAT(Time) / FLOAT(SMUPH);
            (*
            SetString(S2, " HOURS");
            *)
            GetMessage(27212, S2);
        ELSE
            SMUPerPeriod := FLOAT(SMUPH) * FLOAT(TimeTable.StdDayTics);
            NumberOfPeriods := FLOAT(Time) / SMUPerPeriod;
            (*
            SetString(S2, " DAYS");
            *)
            GetMessage(27213, S2);
        END;

        FormatAsAmount (NumberOfPeriods, 
                        AmountFormat, 
                        S, 
                        HIGH(S), 
                        0,             (* min decimal places *)
                        0,             (* max decimal places *)
                        FALSE);
        LJust(S);
        TrimRear(S);
        ConcatLS(S, S2);

        IF (NOT Plus) THEN
            Copy(S, S2);
            (*
            SetString(S, "-");
            *)
            GetMessage(27214, S);
            ConcatLS(S, S2);
        END;

        CheckLineLength(ExportTable, ORD(S[0]));
        OutputLString(S);
    END;
END WriteDuration;



BEGIN
        (* Note that we have not yet issued any warnings. *)

    WarningTypeSet  := AWarningTypeSet{}; 

    (*  Set our rules for formatting real numbers.
        Use an amount format which does not
        place commas into the string, as the file also uses commas to
        separate values.   We always format the numbers the same,
        regardless of the country, since Artemis needs that.     *)

    WITH AmountFormat DO
        RadixSymbol            := ".";
        SymbolForSignificance  := "#";            (* Digit grouping symbol. *)
        DigitsForSignificance  := 9999;           (* Disable digit grouping. *)
        IncludeAtLeastOneDigit := TRUE;
        OverflowSymbol         := "*";
    END;
    WITH AmountFormat.Decorations DO
        Fill(LeadingNegativeSymbol,"-",1);
        Fill(TrailingNegativeSymbol," ",0);
        Fill(LeadingPositiveSymbol," ",0);
        Fill(TrailingPositiveSymbol," ",0);
    END;

END ArtExport.

