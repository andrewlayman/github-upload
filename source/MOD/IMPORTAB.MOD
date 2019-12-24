IMPLEMENTATION MODULE ImPorTable;


  (* Importable - A variety of routines used by the importers.

        MODIFICATION HISTORY:

               6-Jul-89 MWP  Fixed a bug in FileNotFound which caused
                             by trying to append an LString to an
                             existing string using 'ConcatS'.
              27-Aug-89 MWP  When logging an import error message, allow
                             reporting the field number if appropriate.
               7-Sep-89 MWP  Add procedure to validate date values.
              27-Sep-89 MWP  Add date and time to import note header.
              27-Sep-89 MWP  When checking date values, use predefined
                             date boundaries from Timeu.mod.
               6-Oct-89 MWP  Created routine LogAMessage, which will not
                             set the ErrorsHaveOccured flag and
                             give the user incorrect Error messages at
                             the end of import.
                             Changed GetSignOnMessage to LogSignOnMessage.
               9-Oct-89 MWP  Removed text literal.
              19-Jan-90 WKH  Import GetMessageWord from MsgFileAux instead
                             of RptCommon.
              30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
              19-Apr-90 KKC  Grouped year, month, day, hour, minute into one
                             date structure, ATimeInfo. 
   *)

FROM Clock          IMPORT
    (* TYPE *)              ASystemTime,
    (* PROC *)              GetDateAndTime;

FROM Dialog         IMPORT
    (* PROC *)              Error;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile;

FROM FileAux        IMPORT
    (* PROC *)              FileResultMeans,
                            CheckIO;

FROM FileSystem     IMPORT
    (* PROC *)              File,  Response, SetPos, GetPos,
                            ReadByte;

FROM IntFileIO      IMPORT
                            PredicateRecordType,
    (* TYPE *)              AnOverallRecord,      APredicateHeadingRecord,
                            ADomainRecord,        APredicateRecord,
                            AnIntDataRecord,
    (* PROC *)              ReadIntData;

FROM LStrings       IMPORT
    (* PROC *)              TStringToLString,
                            SetLengthOf,
                            ConcatLS,
                            ConcatS,
                            LengthOf,
                            Fill,
                            CtoS;

FROM Memos          IMPORT
    (* VAR  *)              MemoTree,
    (* PROC *)              CreateMemo;

FROM Menus          IMPORT
    (* PROC *)              NoYes;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage, ConcatMessage;

FROM RecordIO       IMPORT
    (* PROC *)              ReadRecordPreface, ReadRecordBody;

FROM MsgFileAux     IMPORT
    (* PROC *)              GetMessageWord;

FROM Subfiles       IMPORT
    (* PROC *)              StartFileInput, StartSubfileInput;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS,
    (* PROC *)              ADR, TSIZE, SIZE;

FROM Text           IMPORT
    (* PROC *)              AppendLine, DiscardText,
    (* PROC *)              Compress,   CreateText;

FROM TimeFormat     IMPORT
    (* PROC *)              DtoS;

FROM Timei          IMPORT
    (* CONST *)             Jan, Dec,
    (* TYPE *)              ATimeInfo,
    (* PROC *)              SystemTimeToTime;

FROM Timeu          IMPORT
    (* CONST *)             YearsOnFile,
    (* VAR *)               TimeTable;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;



CONST
    ModuleNumber            = 29300; (* Same as TLIMPORT *)
    EOSF                    = 0FFH;
    MaxCardinal             = 65535;                              (* 27-Aug-89 MWP *)


PROCEDURE AskAlterBaseline(): BOOLEAN;
VAR
    Text                    : ARRAY [0..255] OF CHAR;
BEGIN

    GetMessage ( ModuleNumber + 7, Text );
    (* "Caution:
        Baseline information is about to be altered.
        Allow alterations?" *)
    RETURN  NoYes ( Text );

END AskAlterBaseline;


PROCEDURE DefAlterBaselineProc(): BOOLEAN;
BEGIN
    RETURN FALSE;
END DefAlterBaselineProc;


PROCEDURE  FileNotFound ( VAR FileName : ARRAY OF CHAR );
VAR
    s  : ARRAY [0..255] OF CHAR;
    s1 : ARRAY [0..255] OF CHAR;
BEGIN
    TStringToLString ( FileName, FileName );

    GetMessage ( ModuleNumber + 66, s );
    (* "The file " *)
    ConcatLS ( s, FileName );
    GetMessage ( ModuleNumber + 67, s1 );
    (* " does not exist." *)
    ConcatLS ( s, s1 );

    Error ( s );

    LogAnError ( s );

END FileNotFound;


PROCEDURE CreateJournal ();
VAR
    ok          : BOOLEAN;
    s           : ARRAY [0..255] OF CHAR;
    s1          : ARRAY [0..255] OF CHAR;
    TimeInfo    : ATimeInfo;
    SystemTime  : ASystemTime;
BEGIN
    ImportNote := CreateText();

    IF (ADDRESS(ImportNote) = NIL) THEN
        GetMessage ( ModuleNumber + 43, s );
        (* "Import note could not be created." *)
        Error ( s );
        RETURN;
    END;  (* no room for note? *)

    GetMessage ( ModuleNumber + 69, s );
    (* "Import Results - " *)
    GetDateAndTime( SystemTime );
    SystemTimeToTime( SystemTime, TimeInfo );
    DtoS ( TimeInfo, s1 );
    ConcatLS ( s, s1 );

    ok := AppendLine( s, ImportNote );

    SetLengthOf ( s, 0 );
    ok := AppendLine( s, ImportNote );

END CreateJournal;


PROCEDURE EndJournal ( HaveErrorsOccured : BOOLEAN );
VAR
    Memo   : ATreeNode;
    s      : ARRAY [0..255] OF CHAR;

BEGIN


    Compress( ImportNote );
    Memo := CreateMemo( ImportNote );

    IF (ADDRESS(Memo) <> NIL) THEN
       MemoTree^.Methods^.AddFirst( MemoTree, Memo );
    END;

    IF ( HaveErrorsOccured ) THEN
        GetMessage ( ModuleNumber + 9, s );
        (* "Errors may have occured.
            Please check Journal notes for more information" *)
        Error ( s );
(***
    ELSE
        DiscardText( ImportNote );             (* in/out *)
***)
    END;

END EndJournal;

(*
    Verbose Error Handler   - Report errors to the journal note.
                              Try to fix all errors.

*)
PROCEDURE VerboseErrorHandler( Severity        : AnErrorSeverity;
                               ErrorKind       : AKindOfError;
                               ColumnID        : CARDINAL;
                           VAR ErrorText       : ARRAY OF CHAR;
                               MyContext       : ADDRESS
                           ) : BOOLEAN;         (* Continue?         *)
VAR
    s                       :   ARRAY [0..255] OF CHAR;
    s1                      :   ARRAY [0..255]  OF CHAR;
    ok                      :   BOOLEAN;
    Number                  : CARDINAL;
BEGIN


    CtoS ( ImportLineNumber, s1 );

    GetMessage ( ModuleNumber + 41, s );
    (*  "Record # " *)
    ConcatLS( s, s1 );

    IF ( ImportFieldNumber < MaxCardinal ) THEN                   (* 27-Aug-89 MWP *)
       CtoS ( ImportFieldNumber, s1 );
       ConcatMessage ( s, ModuleNumber + 70 );                    (* 9-Oct-89 MWP *)
       (*  - Field " *)
       ConcatLS( s, s1 );
    END;

    ConcatS ( s, " " );

    GetMessage ( ModuleNumber + 42, s1 );
    (*  ", Error : " *)
    ConcatLS( s, s1 );


    Number := ORD(ErrorKind);
    GetMessage ( ModuleNumber + 10 + Number + 1, s1 );
    ConcatLS( s, s1 );

    IF (LengthOf( ErrorText ) > 0) THEN
        ConcatS(  s, " : " );
        ConcatLS( s, ErrorText );
    END;

    ok := AppendLine( s, ImportNote );

    ErrorsHaveOccured  := TRUE;

    RETURN TRUE;  (* Fix it if you can. *)

END VerboseErrorHandler;


PROCEDURE LogAnError ( VAR ErrorText       : ARRAY OF CHAR );
VAR
    ok   :   BOOLEAN;
BEGIN

    ok := AppendLine( ErrorText, ImportNote );
    ErrorsHaveOccured  := TRUE;

END LogAnError;

PROCEDURE LogAMessage ( VAR Text       : ARRAY OF CHAR );
VAR
    ok   :   BOOLEAN;
BEGIN

    ok := AppendLine( Text, ImportNote );

END LogAMessage;


PROCEDURE CheckFileStatus ( VAR f: File ) : BOOLEAN;
VAR
    s : ARRAY [0..150] OF CHAR;
BEGIN
    IF (f.eof) THEN
        RETURN FALSE;
    ELSIF (CheckIO(f) = done) THEN
        RETURN TRUE;
    END;
    FileResultMeans(f,s);
    LogAnError ( s );
    RETURN FALSE;

END CheckFileStatus;


PROCEDURE GetOverallInfo() : BOOLEAN;
VAR
    Version,
    Type,
    Length                  : CARDINAL;
    DomainInfo              : ADomainRecord;
    OverallRecord           : AnOverallRecord;
    PredicateHeadingRecord  : APredicateHeadingRecord;
    ok                      : BOOLEAN;

BEGIN
    ok  :=  TRUE;

    IF ( NOT StartFileInput (InterFile) ) OR
       ( NOT StartSubfileInput (InterFile, ImportOverall, Version) ) THEN
        ok  := FALSE;
    END;

    IF ( ok ) THEN
        LOOP
            ReadRecordPreface (InterFile, Type, Length);

            IF ( NOT CheckFileStatus ( InterFile ) ) THEN
               ok := FALSE;
               EXIT;
            END;

            CASE Type OF
                1 :
                    ReadRecordBody (InterFile, Length,
                                    ADR(OverallRecord), SIZE(OverallRecord));

                    RowsToImport := OverallRecord.Revision;
            |   2 :
                    ReadRecordBody (InterFile, Length,
                                    ADR(PredicateHeadingRecord),
                                    SIZE(PredicateHeadingRecord));
            |   3 :
                    ReadRecordBody (InterFile, Length,
                                    ADR(DomainInfo),
                                    TSIZE(ADomainRecord));
            |   0FFH :
                    EXIT;
            ELSE
                SkipRecordBody(InterFile,Length);
            END;
        END;
    END;

    RETURN ok;
END GetOverallInfo;


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
        IF ( NOT CheckFileStatus ( InterFile ) ) THEN
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


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;


PROCEDURE Advance () : BOOLEAN;

VAR
    Position   : AFilePosition;
    C          : CHAR;
    s          : ARRAY [0..255] OF CHAR;
BEGIN
    (* Save the current file position - wherever it is, and set to current
       data record position.
    *)
    GetFilePosition (Position);

    ReadByte(InterFile, C);                   (* Tag Field *)

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
        RETURN FALSE;
    END;

    IF (ORD(C) <> 55H) THEN
       GetMessage ( ModuleNumber + 10, s );
       (* "Bad data file internal structure." *)
       LogAnError ( s );
       RETURN FALSE;
    END;

    ReadByte(InterFile, C);                   (* Tag Field *)

    IF ( NOT CheckFileStatus ( InterFile ) ) THEN
        RETURN FALSE;
    END;

    IF (ORD(C) = EOSF) THEN
       RETURN FALSE;
    END;

    SetFilePosition (Position);

    RETURN TRUE;
END Advance;



PROCEDURE FlushARecord ( FieldCount : CARDINAL );
VAR
    Type                : CARDINAL;
    Data                : AnIntDataRecord;
    i                   : CARDINAL;
BEGIN

    FOR i := 1 TO FieldCount DO
        ReadIntData (Type, Data);
    END;

END FlushARecord;


PROCEDURE DoPredicateSetup  ( FormalName : AnStoreFormalNameProc) : BOOLEAN;
VAR
    Version             : CARDINAL;
    PredicateRecord     : APredicateRecord;
    WhoCares            : AFilePosition;
    ok                  : BOOLEAN;
BEGIN
    ok := TRUE;

    IF (NOT StartSubfileInput (InterFile, ImportPredicate, Version)) THEN
        RETURN FALSE;
    END;

    WHILE ( FindRecord (PredicateRecordType, WhoCares) AND ok ) DO
       IF ( CheckFileStatus ( InterFile ) ) THEN
           ReadRecordBody ( InterFile,
                            SIZE(PredicateRecord),
                            ADR(PredicateRecord),
                            SIZE(PredicateRecord) );

           WITH PredicateRecord DO
              FormalName ( Name, DataType );
           END;
       ELSE
          ok := FALSE;
       END;
    END;

    RETURN ok;
END DoPredicateSetup;


PROCEDURE LogSignOnMsg ();
VAR
    s, s1     :  ARRAY [0..255] OF CHAR;
    ok        : BOOLEAN;
    Len       : CARDINAL;
BEGIN

    GetMessageWord ( ModuleNumber + 53, FormatType - 1, s );
    (* 123, dBase, etc. *)
    ConcatS ( s, " " );
    GetMessageWord ( ModuleNumber + 52, FileType - 1, s1 );
    (* Tasks, Resources, etc. *)
    ConcatLS ( s, s1 );
    GetMessage ( ModuleNumber + 8, s1 );
    ConcatS ( s, " " );
    ConcatLS ( s, s1 );

    ok := AppendLine( s, ImportNote );

    Len := LengthOf ( s );

    Fill ( s, 'Ä', Len );

    ok := AppendLine( s, ImportNote );

END LogSignOnMsg;


PROCEDURE CheckDateValues (  TimeInfo : ATimeInfo ) : BOOLEAN;
VAR
    ok : BOOLEAN;
BEGIN

    ok := TRUE;

    WITH TimeInfo DO
        IF ( tiYear < TimeTable.FirstYear ) OR
        ( tiYear > TimeTable.FirstYear + YearsOnFile ) THEN
            ok := FALSE;
        END;

        IF ( tiMonth < Jan ) OR
        ( tiMonth > Dec ) THEN
            ok := FALSE;
        END;

        IF ( tiDay < MinDay ) OR
        ( tiDay > MaxDay ) THEN
            ok := FALSE;
        END;

        IF ( tiHour < MinHour ) OR
        ( tiHour > MaxHour ) THEN
            ok := FALSE;
        END;

        IF ( tiMinute < MinMinute ) OR
        ( tiMinute > MaxMinute ) THEN
            ok := FALSE;
        END;
    END;

    RETURN ( ok );

END CheckDateValues;




BEGIN
    ImportFieldNumber  := MaxCardinal;                            (* 27-Aug-89 MWP *)
    ErrorsHaveOccured  := FALSE;

END ImPorTable.
