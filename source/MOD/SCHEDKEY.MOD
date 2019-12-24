IMPLEMENTATION MODULE SchedKey;


    (* MODIFICATION HISTORY

       Aug-22-89  AJL -Original version of the DEF.  Most of the coding is
                       taken from earlier work by Ken Chiu.
       Aug-24-89  KKC -Use ExpandPath to expand ProjectMedia.
       Aug-25-89  AJL -Correct the phrase numbers.
                      -Add ability for keywords to have parameters.
                      -Add a new keyword, "CODE," which evaluates its
                       parameter through Foreign.ConvertString.  This allows
                       control codes in the header.
       Sep-11-89  AJL -Removed unused import of Schedule.ProjectText.
       Sep-18-89  AJL -Added RUNPARM(x) keyword which gets the text of any
                       run line parameter.
       Sep-20-89  AJL -Added keywords EXEDIRECTORY, DOSVERSION, SERIAL, EMSTOTAL &
                       EMSFREE
       Sep-21-89  AJL -Corrected the serial number reporting.
       30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
       19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                       date structure, ATimeInfo. 
       01-Jun-90 AJL   Removed use of the PlanLevel variables from Planner.
       23-Jan-91 RSC   Removed spurious import of Holder.
    *)


FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* VAR  *)                  ChartState;

FROM Clock                  IMPORT
    (* TYPE *)                  ASystemTime,
    (* PROC *)                  GetDateAndTime;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, FatalError;

FROM Directory              IMPORT
    (* PROC *)                  ExpandPath, DOSVersion;

FROM EmsStorage             IMPORT
    (* VAR PROC *)              EMSStatistics;

FROM FileAux                IMPORT
    (* VARS  *)                 EXEPath;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer,
    (* VAR  *)                  RevealFilter, HighlightFilter;

FROM Filters                IMPORT
    (* PROC  *)                 QueryRevealFilterOn;

FROM Foreign                IMPORT
    (* PROC *)                  DecodeString;

FROM Kbio                   IMPORT
    (* VAR *)                   VersionString;

FROM LStrings               IMPORT SetString, SubStr, ConcatLS, Fill,
                                   RJust, LJust, Overlay, LengthOf, StoC,
                                   Search, Upshift, StringsEqual, Compare,
                                   TrimRear, CtoS, ConcatS, Copy, Remove,
                                   TrimFront, Insert, Procustes, SetLengthOf;

FROM Menus                  IMPORT
    (* PROC *)                     WordNumber;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;

FROM Planner                IMPORT 
    (* TYPE *)                     ACalcComponent, AWhenToCalc,
    (* VAR *)                      ScheduleComputedOk, ScheduleEndDate,
                                   CalculationState, Levelling, 
                                   TimeConstrained,
    (* PROC *)                     Pert, WeShouldRecalc; 

FROM Registry               IMPORT
    (* VAR  *)                  UserName, UserSerialNumber;


FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia, ProjectName, Author,
                                FullScheduleName;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADR, ADDRESS;

FROM TimeFormat             IMPORT
    (* VAR *)                   DefaultDateAndTimeFormat, DefaultDateFormat,
    (* PROCS *)                 DtoS, TimeToString;

FROM Timei                  IMPORT
    (* TYPE *)                  ATimeInfo,
    (* PROC *)                  TimeUtoT, SystemTimeToTime;

FROM Words      IMPORT
    (* PROC *)         ParseBal;

CONST
    ModuleNumber        =   8400;    (* For GetMessage *)


PROCEDURE GetKeyWordValue(
                           VAR KeyWord : ARRAY OF CHAR;
                           VAR KeywordValue : ARRAY OF CHAR;
                               Context : ADDRESS
                         );
CONST
    ScheduleNameKey =   0;
    ResponsibleKey  =   1;
    AsofKey         =   2;
    ProjectDirKey   =   3;
    ScheduleFileKey =   4;
    RecalcKey       =   5;
    CalculationKey  =   6;
    DateAndTimeKey  =   7;
    DateKey         =   8;
    UserNameKey     =   9;
    CodeKey         =  10;
    RunparmKey      =  11;
    ExedirectoryKey =  12;
    DOSVersionKey   =  13;
    SerialKey       =  14;
    EmsTotalKey     =  15;
    EmsFreeKey      =  16;

    LastKeyWord     =  16;
    NotFoundKeyID   =   9999;
VAR
    i,j,k,RemainderIndex        :   CARDINAL;
    KeyID                       :   CARDINAL;
    TimeInfo                    :   ATimeInfo;
    SystemTime                  :   ASystemTime;
    Word                        :   ARRAY[0..81] OF CHAR;
    s                           :   ARRAY[0..255] OF CHAR;
    s2                          :   ARRAY[0..69] OF CHAR;
    DefaultProjectPath          :   ARRAY[0..0] OF CHAR;
    KeyFound, OK                :   BOOLEAN;
BEGIN
    KeyFound := FALSE;
    KeyID := NotFoundKeyID;
    IF (LengthOf(KeyWord) = 0) THEN
        RETURN;
    END;

        (* Strip away any parameters to the key word. *)

    RemainderIndex := 1;
    ParseBal(KeyWord,RemainderIndex,Word);

    Upshift(Word);


    i := 0;

    WHILE ( NOT KeyFound  ) DO

            (* Read the next line from the phrases file. *)

        GetMessage(ModuleNumber + 1 + i, s2);
        WordNumber(s2,1,s);
        j := 1;
        KeyID := StoC(s,j);

            (* Exhausted all possible key words? *)

        IF (KeyID = NotFoundKeyID) THEN
            RETURN;
        END;

            (* Check each key word.  Each line that we read from
               the phrases file has one or more alternate spellings
               for the keyword, separated by commas.

               When we leave this loop, either KeyFound will be true
               and KeyID will be the first number on the phrase line,
               or KeyFound will be FALSE and KeyID will be NotFoundKeyID.
             *)


        j := 2;
        LOOP
            WordNumber(s2,j,s);
            IF (LengthOf(s) = 0) THEN
   (* EXIT *)   EXIT;
            ELSIF (StringsEqual( Word, s )) THEN
                KeyFound := TRUE;
   (* EXIT *)   EXIT;
            END;
            INC(j);
        END;
        INC( i );        (* Next phrase *)

    END;                 (* End of all phrases. *)

    (*$OS-*)   (* Unreliable. *)

    CASE KeyID OF
        | ScheduleNameKey:
            Copy(FullScheduleName, KeywordValue);
        | ResponsibleKey:
            Copy(Author, KeywordValue);
        | AsofKey:
            TimeUtoT(AsOfDate,TimeInfo);
            DtoS( TimeInfo, KeywordValue);
        | ProjectDirKey:
            SetLengthOf( DefaultProjectPath, 0 );
            ExpandPath( ProjectMedia, DefaultProjectPath, KeywordValue);
        | ScheduleFileKey:
            Copy(ProjectName, KeywordValue);
        | RecalcKey:
            IF (NOT CalculationState[Scheduling].DataIsValid) 
               OR (WeShouldRecalc(CalculationState,ManualCalc)) THEN
                GetMessage( ModuleNumber + 75, KeywordValue); (* NO *)
            ELSE
                GetMessage( ModuleNumber + 74, KeywordValue); (* YES *)
            END;
        | CalculationKey:
            IF (NOT ScheduleComputedOk) THEN
                GetMessage( ModuleNumber + 77, KeywordValue); (* Calc Error *)
            ELSIF (CalculationState[Scheduling].DataIsValid) THEN
                i := 1;     (* CPM *)
                IF ( Levelling ) THEN
                    i := 2; (* Resource Leveled *)
                END;
                IF ( TimeConstrained ) THEN
                    i := 3; (* Leveled within Slack *)
                END;
                GetMessage( ModuleNumber + 78, s );
                WordNumber( s, i, KeywordValue );
            ELSE
                GetMessage( ModuleNumber + 76, KeywordValue); (* Needs Recalc *)
            END;
        | DateAndTimeKey:
            GetDateAndTime( SystemTime );
            SystemTimeToTime( SystemTime, TimeInfo );
            TimeToString( TimeInfo, DefaultDateAndTimeFormat, KeywordValue);
        | DateKey:
            GetDateAndTime( SystemTime );
            SystemTimeToTime( SystemTime, TimeInfo );
            TimeToString( TimeInfo, DefaultDateFormat, KeywordValue);
        | UserNameKey:
            Copy(UserName, KeywordValue);

        | CodeKey:         (* Expand the parameter as control codes. *)
            ParseBal(KeyWord,RemainderIndex,s);
            DecodeString(s,KeywordValue);

        | RunparmKey:      (* Get a parameter from the run line. *)
            ParseBal(KeyWord,RemainderIndex,s);
            GetOption(s,OK,KeywordValue);

        | ExedirectoryKey:
            Copy( EXEPath, KeywordValue );

        | DOSVersionKey  :
            CtoS( DOSVersion() DIV 100H, KeywordValue );
            ConcatS(KeywordValue,".");
            CtoS( DOSVersion() MOD 100H, s2 );
            ConcatLS(KeywordValue,s2);

        | SerialKey      :
            Copy( UserSerialNumber, KeywordValue );

        | EmsTotalKey    :
            EMSStatistics(i,j,k);
            CtoS( i, KeywordValue );

        | EmsFreeKey    :
            EMSStatistics(i,j,k);
            CtoS( j, KeywordValue );

        ELSE
            CtoS(ORD(KeyID),KeywordValue);   (* Phrase file mismatch! *)
            ConcatS(KeywordValue,"?! Phrase mismatch. ");
    END;
    (*$OS=*)

END GetKeyWordValue;


END SchedKey.

