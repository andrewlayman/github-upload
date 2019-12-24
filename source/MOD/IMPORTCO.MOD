IMPLEMENTATION MODULE ImportCommon;


  (* Importable - A variety of routines used by the importers.

        MODIFICATION HISTORY:

        6-Sep-89 MWP Created.
        8-Sep-89 MWP Changed phrases number.
       10-Sep-89 MWP Moved procedure Cleanup here, so importers main
                     overlays can access it.
       19-Sep-89 MWP Added proc to process Break key.
       20-Sep-89 MWP Added reporting of rows read and rows imported to
                     journal.
       22-Sep-89 MWP Changed the somewhat confusing, round-a-bout, and
                     obscure logic of StopImport.
       25-Sep-89 MWP If user cancels import, log a message to that effect
                     in journal.
       28-Sep-89 MWP Changed phrase number for cancelling import.
        3-Oct-89 MWP Changed the import journal, so that it now correctly
                     only prints the record number information once per
                     task, resource etc., instead of for every record.
       30-Mar-90 RSC Made Timeu to Timei/TimeForm conversions.
   *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskStatus, ATaskPtr,
    (* VAR  *)              TaskTree;

FROM AsOf           IMPORT
    (* PROC *)              AsOfDate, SetAsOfDate;

FROM ChartControl   IMPORT
    (* PROC *)              UnSetState,
    (* TYPE *)              AChartState;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;


FROM ImPorTable      IMPORT
    (* VAR  *)              ImportNote,          ImportLineNumber,
                            ImportFieldNumber,
                            ErrorsHaveOccured,
    (* PROC *)              LogAnError;
FROM Kbio           IMPORT
    (* PROCS *)             BreakRequested, ClearBreak;


FROM LStrings       IMPORT
                            SetString,        Fill,
                            SetLengthOf,      ConcatLS,
                            Copy,             ConcatS,
                            LengthOf,         Insert,
                            CtoS,
                            SubStr;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM Notices        IMPORT
    (* TYPE *)              AnOccasion, AStep,
    (* PROC *)              Permission, SendNotices;

FROM Schedule       IMPORT
    (* VAR  *)              ProjectName,   ProjectMedia,
                            Author,        FullScheduleName,
                            ProjectText,   ConfigSaved,
                            ScheduleSaved, Loaded,
                            RetrievalName,
    (* PROC *)              DisplayScheduleLight;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM Text           IMPORT
                            AppendLine;

FROM Timei          IMPORT
    (* TYPE *)              ADate,
    (* VAR  *)              Today,
    (* PROC *)              FindToday;

CONST
    ModuleNumber            = 29300; (* Same as TLIMPORT *)
    MaxCardinal             = 65535;                              (* 27-Aug-89 MWP *)

PROCEDURE ImportErrorHandler(    Severity        : AnErrorSeverity;
                                 ErrorKind       : AKindOfError;
                                 ColumnID        : CARDINAL;
                             VAR ErrorText       : ARRAY OF CHAR;
                             VAR Field           : ARRAY OF CHAR
                             ) : BOOLEAN;
CONST
    MaxTextLength           = 75;
VAR
    s                       :   ARRAY [0..255] OF CHAR;
    s1                      :   ARRAY [0..255]  OF CHAR;
    s2                      :   ARRAY [0..255]  OF CHAR;
    ok, FirstTime           :   BOOLEAN;
    Number, Indent, TotalLineLength,
    Len, Beginning, End, i  :   CARDINAL;
BEGIN

    SetLengthOf ( s, 0 );

    IF ( PrintErrorHeader ) THEN
       CtoS ( ImportLineNumber, s1 );

       GetMessage ( ModuleNumber + 41, s );
       (*  "Record # " *)
       ConcatLS( s, s1 );


       IF ( LengthOf ( ErrorText ) > 0 ) THEN
          ConcatS( s, "  " );
          ConcatLS ( s, ErrorText );
       END;

       ok := AppendLine( s, ImportNote );
       PrintErrorHeader := FALSE;
    END;

    SetString ( s, "    " );

    IF ( ImportFieldNumber < MaxCardinal ) THEN                   (* 27-Aug-89 MWP *)
       GetMessage ( ModuleNumber + 54, s2 );
       (* - Field " *)
       ConcatLS ( s, s2 );
       ConcatLS( s, Field );
       ConcatS ( s, " : " );
    END;

    Indent := LengthOf ( s );

    Number := ORD(ErrorKind);
    GetMessage ( ModuleNumber + 10 + Number + 1, s1 );

    ConcatLS( s, s1 );

    Len := LengthOf ( s );

    IF ( Len > MaxTextLength ) THEN
       Beginning       := 1;
       TotalLineLength := MaxTextLength - Indent;
       FirstTime       := TRUE;

       REPEAT
          IF ( FirstTime ) THEN
              End := MaxTextLength;
          END;

          SubStr ( s, s1, Beginning, End - Beginning );

          IF ( End < Len ) THEN
             i := End - Beginning;
             WHILE ( s1[ i ] <> ' ' ) DO
                DEC(i);
             END;
             SetLengthOf ( s1, i );
             End := ( Beginning + i ) - 1;
          END;

          IF ( FirstTime ) THEN
             SetLengthOf ( s2, 0 );
             FirstTime := FALSE;
          ELSE
             SetLengthOf ( s2, 0 );
             Fill ( s2, ' ', Indent );
          END;

          ConcatLS ( s2, s1 );

          ok := AppendLine( s2, ImportNote );

          Beginning := End + 1;
          End       := End + TotalLineLength;

          IF ( End > Len ) THEN
             End := Len;
          END;

       UNTIL ( Beginning >= Len );
    ELSE
       ok := AppendLine( s, ImportNote );
    END;

    SetString ( s, " " );
    ok := AppendLine( s, ImportNote );

    ErrorsHaveOccured  := TRUE;

    RETURN TRUE;  (* Fix it if you can. *)

END ImportErrorHandler;


PROCEDURE CompleteBEndImport ( RowsImported : CARDINAL;
                               RowsRead     : CARDINAL;
                               ReportType   : CARDINAL );
VAR
    s         : ARRAY [0..255] OF CHAR;
    s1        : ARRAY [0..5] OF CHAR;
    ok        : BOOLEAN;
BEGIN

    CtoS ( RowsImported, s1 );
    GetMessage ( ModuleNumber + 55 + ReportType, s );

    Insert ( s, s1, 1 );
    ok := AppendLine( s, ImportNote );

    CtoS ( RowsRead, s1 );                                        (* 20-Sep-89 MWP *)
    GetMessage ( ModuleNumber + 62 + ReportType, s );

    Insert ( s, s1, 1 );
    ok := AppendLine( s, ImportNote );


    IF ( NOT ErrorsHaveOccured ) THEN
       GetMessage ( ModuleNumber + 44, s );                       (* 8-Sep-89 MWP *)
       (* "No errors encountered during import." *)
       ok := AppendLine( s, ImportNote );
    END;

    SetLengthOf ( s , 0 );
    ok := AppendLine( s, ImportNote );

END CompleteBEndImport;


PROCEDURE CleanUp ();
VAR
    OldAsOfDate          : ADate;
    TasksInMemory        : BOOLEAN;
BEGIN

    (* Call the client-supplied procedure to actually load the
       file. *)

    TasksInMemory := (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL);
    Today         := FindToday();

    OldAsOfDate := AsOfDate;
    SetAsOfDate();                          (* 3/20/87   EGK  *)
    IF (AsOfDate <> OldAsOfDate) AND (TasksInMemory) THEN
        UnSetState (Scheduled);
    END;

    SendNotices(ModelLoad,AfterActing,NIL);

    Loaded := TRUE;
    IF (NOT TasksInMemory) THEN
        ScheduleSaved := TRUE;
    END;

END CleanUp;


PROCEDURE StopImport () : BOOLEAN;
VAR
    Choice     : CARDINAL;
    Prefix     : ARRAY [0..41] OF CHAR;
    Choices    : ARRAY [0..255] OF CHAR;
    S          : ARRAY [0..255] OF CHAR;
    NillString : ARRAY [0..1] OF CHAR;
BEGIN

    IF ( BreakRequested () ) THEN
        ClearBreak ();

        SetLengthOf(NillString,0);

        GetMessage ( ModuleNumber + 59, Prefix );
        GetMessage ( ModuleNumber + 60, Choices );
        GetMessage ( ModuleNumber + 61, S );

        Choice := 1;

           (* Find out what they want.  Do not allow the CancelKey
              since its meaning is unclear in this context. *)
        REPEAT
        UNTIL (MultipleChoiceBox( S, NillString, NoHelp, Prefix, Choices, Choice ));

        IF ( Choice = 2 ) THEN
            GetMessage ( ModuleNumber + 68, S );
            LogAnError ( S );
            HaltImport := TRUE;
        END;
    END;

    RETURN ( HaltImport );

END StopImport;


BEGIN

    HaltImport       := FALSE;
    PrintErrorHeader := TRUE;
END ImportCommon.
