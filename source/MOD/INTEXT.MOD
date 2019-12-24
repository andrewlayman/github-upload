IMPLEMENTATION MODULE InText;


    (* MODIFICATION HISTORY:

       4/5/86    AJL - Lines beginning "--", and containing a
                       duration, will be taken as resource
                       assignments to the master task.  Resource
                       name will be the first word on the line.
                       Allocation will be the ratio of durations.
       5/28/86   AJL - Split off module Matches.
       5/29/86   AJL - Lines beginning with "@" are resource
                       assignments.
                     - Pass LastContextOurLevel to ReadSubtasks
                       when nesting.  This corrects accidental
                       passing of the just-parsed own lines context
                       as the context in which to interpret itself.
                     - The DueFlag on a line context controls the
                       parsing of its children, but not the line
                       itself.
       5/31/86   AJL - Fixed some problems with the wrong context
                       being passed to SubdivideMasterTask. This
                       fixes some errors with ALBUG1.RDY and tasks
                       erroneously being interpreted in the context
                       of the immediately prior task.
                     - Join all tasks except Fixed to Fixed.
                     - Support percentage allocations for resources.
                     - Percentages may be given as a number followed
                       by a "%", or as a decimal fraction.
                     - Lines beginning with "--" and containing a
                       percentage (nnn %) are resource lines.
                       The percent sign "%" must be included.
                     - Percentages > 100% will raise the limit
                       for the resource.  This will not affect
                       assignments expressed in durations.
        6/2/86 AJL   - "--" lines can no longer be resource
                       assignments.  Only "@" lines.
        6/8/86 AJL   - Resource names ending with or containing
                       numbers will be correctly read as names.
                       Previously, the numeric part was read as
                       an amount of the resource when no "%" was
                       on the line.
                     - Resources assigned to a master-level task
                       will appear on the Span portion, not on the
                       Start milestone as they formerly did.
        6/23/86      - We pass the sequence number of our progress
                       back up to the caller of ReadSubtasks so
                       that sequence numbers will not be thrown off
                       by wrongly-indented comments or resource
                       assignments.
                     - Comments at the current level do not cause
                       exit or ReadSubtasks.
        12/9/86      - Remove the initial read of the first line of
                       a file.  This was setting an unreasonable default
                       context.  Reference November 25, 1986 memo from
                       Mikel Cook re: Al Olsten HP bug report.
        12/23/86 AJL - Update handling of default dates for headings.
        12/30/86 AJL - If there is a "--" on a line, only parse the
                       portion to the right of the "--".
                     - Allow explicit fixations (Fixed, ASAP, etc.) to
                       override implied ones.
                     - Allow SEQUENTIAL and PARALLEL keywords.
                       PARALLEL, NOJOIN, and NOLINK prevent the tasks
                       in a level from being joined.
                       SEQUENCE, SEQUENTIAL, JOIN and LINK cause
                       tasks to be sequentially joined.
        1/12/87  AJL - Mark span tasks in the notes fields as summaries.
        3/22/88  RSC - SPIKE upgrade.
        4/12/88  RSC - Internationalization.
       Jun  6, 1988 RSC   - Beefed-up keyword processing for later SNOBOL
                            conversions of other people's CSV files.
       Jun 20, 1988 RSC   - added METACOMMANDS to override normal processing.
       Jul 20, 1988 RSC   - final touches before shipping.
        2-Jan-89    RSC   - Removed references to Compare() (not used).
        4-Apr-89    EGK   - Changed TempFlag to RTempFlag.
        3-May-89    EGK   - Changed to support new scheme for WBS, OBS, and AUX.
       20-May-89    RSC     Accomidated new WorkHours module.
       15-Aug-89    RSC     Fixed bug from field dump where "@" with no
                            resource name, but with sublines, caused a PMD.
       21-Aug-89    RSC   - Check ExtStatus before allocating resource
                            assignment records.
       21-Sep-89    RSC   - Added parm to SetResourceRate.
       19-Oct-89    MWP   - When removing numbers, start the removal
                            process after the resource name field, so we
                            can have numbers within the resource name.
       16-Nov-89    MWP   - If there is no EndOfNameString marker in the
                            resource field, assume all text after '@' marker
                            is the resource name. Otherwise, we start stripping
                            numbers starting at character pos 0, and we are back
                            to the same problem as above.
       30-Mar-90    RSC     Made Timeu to Timei/TimeForm conversions.
       11-Apr-90    KKC     Replace all direct calculations on ADate and Duration
                            by calls to FindDuration, SubtractWorkingTime and
                            AddWorkingTime.
        6-Aug-90    RSC     Fixed import problems due to def changes.
                            Removed check before "You should recalc" message
                            so that it puts up the message unconditionally.
       13-Sep-90    CL      Rename the former Plan.Dates.FixedStart field 
                            to UserEnteredStartDate and change its format 
                            from ADate to ABigTime.
       24-Jan-91    AJl     Added AsOf parameter to AppropriateStartStatus.
        5-Feb-91    TGS     Change Availability list instead of UpperLimit/
                            Percent fields in Resource record.
        13-Nov-91 TGS   Initialize VaryingAssignmentList to NIL.
        31-Jan-92 LAA       In AjustPercentages, I removed code which adjusts
                            the NumberAt and Percentage for the best match,
                            since this is undesirable behavior (particularly
                            now that we allow decimals in the NumberAt field.
        07-Apr-92 TGS       Make sure Percentage is not 0C.
    *)


FROM Alarms         IMPORT AppropriateStartStatus;

FROM Allocs         IMPORT ATask, ATaskPtr, ATaskName, TaskTree,
                           AFixType, StartStatusName, ARollupStatus,
                           FixationName, AStartStatus, InitializeTaskRecord,
                           AddTask, CopyTask, ATaskFlagSet, ATaskFlag,
                           CreateTask, TskNmLen, ADurationMethod,
                           WBSLine, GetCodingField, SetCodingField, WBSLen,
                           OBSLine, AUXLine, ATempTaskFlag;

FROM Assignments    IMPORT
      (* TYPES *)          AnAssignmentAttribute,
                           AnAssignmentAttributeSet,
                           AnAssignmentRecord,
                           AnAssignmentArray,
                           ASetOfRoles,
    (* PROC *)             ForEachAssignment;

FROM AsOf           IMPORT AsOfDate;

FROM BigTimeU       IMPORT
    (* TYPE *)          ABigTime,
    (* VAR  *)          MINBIGTIME;

FROM CalShift               IMPORT
    (* VAR *)                   TimeSheet;

FROM ChartControl   IMPORT AChartState, UnSetState;

FROM DateLists      IMPORT 
    (* TYPE *)          ADateList,
    (* PROC *)          GetDateListEntry, CreateDateList, 
                        DisposeDateListEntry, SetDateListEntryN;

FROM Dialog         IMPORT Message, Error, FatalError;

FROM Duration       IMPORT 
    (* PROC *)         FindDuration, AddWorkingTime, 
                       SubtractWorkingTime;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdge, AnEdgePtr,
    (* PROC *)                  ItDepends, CreateEdge, AddEdge;

FROM FileSystem     IMPORT File;

FROM FlexStor       IMPORT
    (* TYPE *)         AnExtHandle, AnExtStoragePreference,
                       AnExtStatus,
    (* PROC *)         CreateExtObject, SetExtData, GetExtData,
                       CreateExtObjectWithSize, SetExtSize, GetExtSize,
                       SaveHeapCopy, MakeHeapCopy,  GetExtStatus,
                       LockObject, LockObjectArray, ReleaseObject,
                       ArraySize, NumberOfElements, ReleaseUnchangedObject;

FROM Kbio           IMPORT
    (* PROCS *)        BreakRequested;

FROM LStrings       IMPORT
    (* PROCS *)        SetString, Insert, ConcatS, ConcatLS, Remove,
                       SubStr, LStringToTString, TrimRear, Upshift,
                       TrimFront, StoC, Procustes, Fill,
                       Copy, Overlay, Search, CtoS, LengthOf;

FROM Matches        IMPORT
    (* PROCS *)        Alphabetic, Numeric, NumberPart,
                       EndOfWord, RemoveRestOfWord, InsertBlap,
                       ReplaceWordWithBlap, MatchWord,
                       MatchAStartStatus, MatchADurationUnit,
                       MatchAndRemoveADuration, AlphaNumeric,
                       MatchParallel,   MatchAndRemoveAPercentage,
                       MatchSequential, MatchARealNumber,
                       MatchAMonthName, MatchADeadline,
                       MatchAFixation, MatchAMilestone,
                       MatchADate, CondensePlaceHolders;

FROM MsgFile        IMPORT
    (* PROCS *)        GetMessage;

FROM ParseReal      IMPORT
    (* PROCS *)        AmountToReal;

FROM RateLists      IMPORT
    (* PROC *)          CreateRateList;

FROM ResCalUI       IMPORT 
    (* TYPE *)          AnAvailabilityRate;

FROM RsrcMod        IMPORT 
    (* TYPE *)          AResourcePointer, ACostStyle,
                        AResourceType, 
    (* CONST *)         ResourceNameLength,
                        DefaultAvailabilityPercent, DefaultAvailabilityAmount,
    (* PROC *)          CreateResource, ChangedResource,
                        FindResourceByName;

FROM RsrcCalc       IMPORT ComputeTaskNodeCosts;

FROM Space          IMPORT HeapAvailable, ALLOCATE;

FROM SYSTEM         IMPORT SIZE, TSIZE, ADR, ADDRESS;

FROM TextStack      IMPORT PushText, FlushTextStack;

FROM Text           IMPORT DiscardText, AssignText, TextExists, SizeOfText, 
                           AText, Compress, CreateText,
                           AppendLine;

FROM Timei          IMPORT
    (* CONST*)         MaxDate, MinDate, NoDuration,
    (* TYPE *)         ADuration, ADurationUnit, ADate,
    (* PROC *)         DurationToReal;

FROM TimeXlate      IMPORT
    (* PROC *)         CalendarTimeToBigTime, BigTimeToCalendarTime;

FROM TreeObjects    IMPORT
    (* TYPE *)         ATreeNode, ATreeOrder,
    (* PROC *)         CreateTreeNode, ValidateTreeNode;

FROM   WorkHours     IMPORT
        (* PROCS *)    WorkHoursToRealTime;





CONST
    ModuleNumber       = 23400;

    MaxTextLineLength  = 106C;  (* 70 decimal *)
    CharactersPerLevel = 2;
    MAXCARDINAL        = 65535;
    Zero               = 0.0;



TYPE
    ALineType = (ATaskLine, AResourceLine, ACommentLine);


        (*

            AContext allows us to interpret subordinate lines
            in light of what we have gleaned from superordinate
            ones.

            "The sins of the fathers are visited upon the children."

            Osvald, in Ghosts, Henrik Ibsen.

        *)


    AContext = RECORD
                   Level    : CARDINAL;
                   Duration : ADuration;
                   ParallelDate,
                   Date     : ADate;
                   DueDate  : ADate;
                   Fixation : AFixType;
                   LineType : ALineType;
                   DurationExplicit : BOOLEAN;
                   Scale    : ADurationUnit;
                   DateFlag : BOOLEAN;
                   DueFlag  : BOOLEAN;
                   TaskName : ARRAY [0..30] OF CHAR;   (* Where we got this context (debugging) *)
                   JoinFlag : BOOLEAN;
               END;

    (* ALevelHistory is to allow us to exit to a higher level in
       the outline and then return to the lower level as though
       we had not been interrupted. *)


    ALevelHistory = RECORD
                        LastTaskOurLevel,
                        PrecedingTaskEnd    : ATreeNode;
                        LastContextOurLevel : AContext;
                        NotSplitYet         : BOOLEAN;
                        NewSequence         : BOOLEAN;
                        SequenceNumber      : ARRAY [0..15] OF CHAR;
                    END;


VAR
    TempAsOfDate     : ADate;
    MetacommandsSeen : BOOLEAN;
    MetaContext      : AContext;







PROCEDURE BumpCharacter( VAR C : CHAR; VAR Carry : BOOLEAN );
BEGIN
    Carry := FALSE;
    IF ( C = "9" )  THEN
        C := "A";
    ELSIF (C = "Z") THEN
        C     := "0";
        Carry := TRUE;
    ELSE
        INC(C);
    END;
END BumpCharacter;





PROCEDURE IncrementString( VAR S : ARRAY OF CHAR;
                           VAR Carry : BOOLEAN );
VAR
    i : CARDINAL;
BEGIN
    i := ORD(S[0]);
    LOOP
        IF (i = 0) THEN
            Carry := TRUE;
            EXIT;
        END;
        BumpCharacter(S[i],Carry);
        IF (NOT Carry) THEN
            EXIT;
        END;
        DEC(i);
    END;
END IncrementString;





  (* Parse a WBS number the customer supplied.

        Preconditions  - WBS is the full WBS number typed in.
                         FirstPart is the parent task's LEADING portion of
                                the WBS number.

        Postconditions - FirstPart is EITHER
                            > Left alone if it matches leading part of WBS.
                            > Set to all but last few chars in WBS.
                         LastPart is EITHER
                            > Chars in WBS after chars in FirstPart
                            > Last few chars in WBS.
  *)
PROCEDURE ParseWBS( VAR WBS,
                        FirstPart,
                        LastPart   : ARRAY OF CHAR );
VAR
    MatchPart,
    i          : CARDINAL;
BEGIN

  (* Does FirstPart match WBS for some number of bytes? *)

    MatchPart := 0;
    WHILE (MatchPart < ORD(WBS[0])) AND (MatchPart < ORD(FirstPart[0])) AND
          (WBS[ MatchPart+1 ] = FirstPart[ MatchPart+1 ]) DO
        INC( MatchPart );
    END;

  (* IF some matched, then the rest must be the LastPart. *)

    IF (MatchPart > 0) THEN
        SubStr( WBS, LastPart, MatchPart + 1, HIGH(LastPart) );
        FirstPart[0] := CHR(MatchPart);
        RETURN;
    END;

 (* None matched, try to find a logical breaking point between first and
    last.  Start by trying to find a seperator (dot, dash, space, stroke)
 *)

    i := ORD(WBS[0]);
    WHILE (i > 0) AND (AlphaNumeric(WBS[i])) DO
        DEC(i);
    END;

    IF (i = 0) THEN
        FirstPart[0] := 0C;  (* No first part! *)
        Copy( WBS, LastPart );
    ELSE
        SubStr( WBS, FirstPart, 1, i );
        IF (i = ORD(WBS[0])) THEN
            LastPart[0] := 0C;  (* No last part *)
        ELSE
            SubStr( WBS, LastPart, i+1, HIGH(LastPart));
        END;
    END;

END ParseWBS;





PROCEDURE SubtractDate( FromThis, SubtractThis : ADate ) : ADuration;
BEGIN
    IF (SubtractThis >= FromThis) THEN
        RETURN NoDuration;
    END;
    RETURN FindDuration( SubtractThis, FromThis, TimeSheet );
END SubtractDate;



PROCEDURE SubtractDur( StartDate : ADate; Dur : ADuration ) : ADate;
BEGIN
    IF ( StartDate < AddWorkingTime( MinDate, Dur, TimeSheet ) ) THEN
        RETURN MinDate;
    END;
    RETURN SubtractWorkingTime( StartDate, Dur, TimeSheet );
END SubtractDur;



PROCEDURE Add( This : ADate; ToThis : ADuration ) : ADate;
BEGIN
    IF ( FindDuration( This, MaxDate, TimeSheet ) < ToThis ) THEN
        RETURN MaxDate;
    END;
    RETURN AddWorkingTime( This, ToThis, TimeSheet );
END Add;






  (* In version 3, task and resource names cannot have these charactors:

           \, ^, *, or [.

  *)
PROCEDURE AjustName( VAR NewName : ARRAY OF CHAR );
VAR
    Loop : CARDINAL;
    C    : CHAR;
BEGIN
    FOR Loop := 1 TO ORD(NewName[0]) DO
        C := NewName[ Loop ];
        IF ((C = "\") OR
            (C = "^") OR
            (C = "*") OR
            (C = "]") OR
            (C = "["))  THEN
            NewName[ Loop ] := "-";    (* Give 'em a replacement char. *)
        ELSIF (C = ",") THEN
            NewName[ Loop ] := " ";
        END;
    END;
END AjustName;






PROCEDURE ParseMiscTaskKeywords( VAR TextString  : ARRAY OF CHAR;
                                 VAR Task        : ATask         );
VAR
    i, j       : CARDINAL;
    Parameter  : ARRAY [0..79]  OF CHAR;
BEGIN

    IF (GetParam( TextString, Parameter, ModuleNumber + 5)) THEN (* WBS *)
        SetCodingField (Task, WBSLine, Parameter);
    END;

    IF (GetParam( TextString, Parameter, ModuleNumber + 6)) THEN (* OBS *)
        SetCodingField (Task, OBSLine, Parameter);
    END;

    IF (GetParam( TextString, Parameter, ModuleNumber + 7)) THEN (* Keyword *)
        SetCodingField (Task, AUXLine, Parameter);
    END;

    IF (GetParam( TextString, Parameter, ModuleNumber + 8)) THEN (* Percent *)
        i := 1;
        Task.PercentComplete := StoC( Parameter, i );
    END;

    IF (GetParam( TextString, Parameter, ModuleNumber + 9)) THEN (* Priority *)
        i := 1;
        j := StoC( Parameter, i );
        IF (i > 1) THEN
            IF (j <= 999) THEN
                Task.priority := j * 10;
            ELSE
                Task.priority := 9999;
            END;
            IF (i < ORD(Parameter[0])) AND (Parameter[i] = ".") THEN
                INC(i);
                Parameter[0] := CHR(i);  (* Force one decimal place only. *)
                j := StoC( Parameter, i );
                IF (j <= 9) THEN
                    INC( Task.priority, j );
                END;
            END;
        END;
    END;

END ParseMiscTaskKeywords;





PROCEDURE ParseTaskData( VAR TaskDataString : ARRAY OF CHAR;
                         VAR Task           : ATask;
                         VAR Context        : AContext );
CONST
    EndOfNameString   = "*";
    StartOfComment    = "-";
    ResourceString    = "@";
    MetacommandString = "$";
VAR
    Date,FirstDate,SecondDate   : ADate;
    At                          : CARDINAL;
    Length                      : CARDINAL;
    Percentage                  : REAL;
    i,j                         : CARDINAL;
    Dur                         : ADuration;
    StartStatus                 : AStartStatus;
    S                           : ARRAY [0..255] OF CHAR;
    S2                          : ARRAY [0..11] OF CHAR;
    TaskName                    : ATaskName;
    TimeUnit                    : ADurationUnit;
    FirstDateValid,
    SecondDateValid             : BOOLEAN;
        (* We use the EndDateGiven flag separately from the DueFlag
           as of 5/29/86 in order to still pass the inheritance of
           a tendency towards ALAP and to fixed date ending milestones,
           but so that we interpret dates based on this text line. *)
    EndDateGiven : BOOLEAN;
    FixationGiven : BOOLEAN;
    GivenFixation : AFixType;
    Metacommand   : BOOLEAN;
BEGIN

    EndDateGiven  := FALSE;
    FixationGiven := FALSE;
    Metacommand   := FALSE;

    WITH Context DO
        DurationExplicit := FALSE;
        LineType         := ATaskLine;
    END;

    InitializeTaskRecord(Task);

    TrimFront(TaskDataString);
    TrimRear(TaskDataString);

  (* Determine what kind of line it is. *)

 (* Is it a resource line? *)

    SetString(S2,ResourceString);
    i := Search(TaskDataString,S2,1);
    IF (i = 1) THEN
        Context.LineType := AResourceLine;
        RETURN;  (* So don't process any more. *)
    END;

  (* Is it a METACOMMAND line?  (  <Spaces>$<task params> )   *)

    SetString(S2,MetacommandString);
    i := Search(TaskDataString,S2,1);
    IF (i = 1) THEN
        Metacommand      := TRUE;
    END;

 (* Is it a comment line? *)

    SetString(S2,StartOfComment);
    i := Search(TaskDataString,S2,1);

    IF (i = 1) THEN                        (* at start of line. *)
        Context.LineType := ACommentLine;
        RETURN;
    END;

        (* Copy the task name from the string into the task
           record, but if there is a "*", then only up to
           that. *)

    SetString(S2,EndOfNameString);
    i := Search(TaskDataString,S2,1);
    j := i;

    IF (i = 0) OR                          (* not found *)
       (i >  HIGH(Task.taskname) + 1) THEN (* too far right. *)
        i := HIGH(Task.taskname) + 1;
    END;

        (* Store the task name. *)

    SubStr(TaskDataString,Task.taskname,1,i-1);
    AjustName(Task.taskname);

        (* For debugging, copy the name of the task into the context. *)

    Copy(Task.taskname,Context.TaskName);

        (* Copy into the S string the part of the line that we will parse. *)

    IF (j = 0) THEN                   (* No "*" found. *)
        j := 1;
    ELSE
        INC(j);                     (* Skip the "*". *)
    END;
    SubStr(TaskDataString,S,j,HIGH(S));
    TrimFront(S);
    TrimRear(S);

  (* Look for dates, times, keywords, etc. *)

        (* S is an UpShifted copy of TaskDataString, though
           if there is a "--", then only the part to the right
           of the "--". *)

    Upshift(S);

    ParseMiscTaskKeywords( S, Task );

    IF (MatchParallel(S,At)) THEN
        ReplaceWordWithBlap(S,At);
        Context.JoinFlag := FALSE;
        Context.Date     := Context.ParallelDate; (* Get proper default date. *)
    ELSIF (MatchSequential(S,At)) THEN
        ReplaceWordWithBlap(S,At);
        Context.JoinFlag := TRUE;
    END;

    IF (MatchADeadline(S,i)) THEN
        ReplaceWordWithBlap(S,i);
        Context.DueFlag  := TRUE;           (* For inheritance. *)
        EndDateGiven     := TRUE;           (* For us. *)
    ELSIF (MatchAFixation(S,i,Context.Fixation)) THEN
        ReplaceWordWithBlap(S,i);
        FixationGiven := TRUE;
        GivenFixation := Context.Fixation;
    END;

    IF (MatchAMilestone(S,i)) THEN
        ReplaceWordWithBlap(S,i);
        Context.DurationExplicit := TRUE;
        Context.Duration := NoDuration;
        Context.Scale    := Days;
    END;

        (* See if a time is included. *)

    IF (MatchAndRemoveADuration(S,1,Dur,TimeUnit)) THEN
        Context.DurationExplicit := TRUE;
        Context.Duration := Dur;
        Context.Scale    := TimeUnit;
    END;

        (* See if we can find a date in the string. *)

    FirstDateValid := FALSE;
    SecondDateValid := FALSE;

    Date := Context.Date;
    IF (MatchADate(S,Date,At,Length,Context.DueFlag)) THEN
        Remove(S,At,Length);
        InsertBlap(S,At);
        FirstDate        := Date;
        FirstDateValid   := TRUE;
        Context.Date     := Date;
        Context.Fixation := FixedDate;
        Context.DateFlag := TRUE;
    END;

    IF (FirstDateValid) THEN   (* Look for a second (end) date. *)
        Date := Context.Date;
        IF (MatchADate(S,Date,At,Length,TRUE)) THEN
            Remove(S,At,Length);
            InsertBlap(S,At);
            SecondDate       := Date;
            SecondDateValid  := TRUE;
            Context.Date     := Date;
            Context.Fixation := FixedDate;
            Context.DateFlag := TRUE;
        END;
    END;

    IF (FirstDateValid) AND (SecondDateValid) THEN
        IF (FirstDate > SecondDate) THEN
            Date := FirstDate;
            FirstDate := SecondDate;
            SecondDate := Date;
        END;
        Context.DurationExplicit := TRUE;
        Context.Duration         := SubtractDate(SecondDate,FirstDate);
    END;

        (* Store the fixation. *)

    IF (FixationGiven) THEN
        Task.fixation := GivenFixation;
    ELSE
        Task.fixation := Context.Fixation;
    END;

    IF MatchAStartStatus( S, i, StartStatus ) THEN (* RSC 3/28/88 *)
        Task.StartStatus := StartStatus;
        INCL( Task.TempTaskFlags, TempTaskFlag1 );
    END;

        (* If this is a task with a specific due date, note that. *)

    IF (EndDateGiven) THEN
        IF (SecondDateValid) THEN          (* Both valid *)
            Context.DueDate            := SecondDate;
            Context.Date               := FirstDate;
            Task.Plan.Dates.EarlyStart := FirstDate;
        ELSIF (FirstDateValid) THEN
            Context.DueDate            := FirstDate;
            Context.Date               := SubtractDur(FirstDate,Context.Duration);
            Task.Plan.Dates.EarlyStart := Context.Date;
        ELSE
            Context.Date               := SubtractDur(Context.DueDate,Context.Duration);
            Task.Plan.Dates.EarlyStart := Context.Date;
        END;
        IF (NOT Metacommand) THEN
            Context.Fixation := ALAP;  (* For future children. *)
        END;
    ELSE
        IF (FirstDateValid) THEN
            Task.Plan.Dates.EarlyStart := FirstDate;
        ELSE
            IF (Context.DueFlag) THEN
                Context.Date           := SubtractDur(Context.DueDate,Context.Duration);
            END;
            Task.Plan.Dates.EarlyStart := Context.Date;
        END;
    END;

        (* Store findings. *)

    Task.scale         := Context.Scale;
    Task.EffortScale   := Context.Scale;
    Task.duration      := Context.Duration;

    WITH Task.Plan.Dates DO
        CalendarTimeToBigTime(EarlyStart,TRUE,Task.UserEnteredStartDate);
        LateFreeStart  := EarlyStart;
        LateTotalStart := EarlyStart;
        EarlyEnd       := Add(EarlyStart,Task.duration);
        LateFreeEnd    := EarlyEnd;
        LateTotalEnd   := EarlyEnd;
    END;

    IF (Metacommand) THEN
        MetaContext      := Context;
        MetacommandsSeen := TRUE;
    END;

END ParseTaskData;







PROCEDURE AppendToName( VAR Name   : ARRAY OF CHAR;
                            Phrase : ARRAY OF CHAR );
VAR
    S : ARRAY [0..60] OF CHAR;
BEGIN
    SubStr(Name,S,1,HIGH(S));
    ConcatLS(S,Phrase);
    SubStr(S,Name,1,HIGH(Name));
END AppendToName;




PROCEDURE CreateWBS  ( VAR MasterSequence : ARRAY OF CHAR;
                       VAR SequenceNumber : ARRAY OF CHAR;
                       VAR WBS            : ARRAY OF CHAR  );
VAR
    i : CARDINAL;
BEGIN
    Copy( MasterSequence, WBS );
    i := ORD(WBS[0]);
    IF (i > 0) AND (i < HIGH(WBS)) AND (AlphaNumeric(WBS[i])) THEN
        ConcatS( WBS,"." );
    END;
    IF ((ORD(WBS[0]) + ORD(SequenceNumber[0])) <= HIGH(WBS)) THEN
        ConcatLS( WBS,SequenceNumber );
    END;
END CreateWBS;






PROCEDURE AjustPercentages( VAR Assignment : AnAssignmentRecord;
                                Ratio      : REAL );
VAR
    i,j, At,
    BestD    : CARDINAL;
BEGIN
    WITH Assignment DO
        IF (Ratio <= 0.01) THEN
            MaxRatePercent := 0;
            PercentageEach := 1C;   (* 7-Apr-92 TGS *)    
        ELSIF (Ratio >= 650.0)  THEN (* Maxcardinal *)
            MaxRatePercent := MAXCARDINAL;
        ELSE
            At             := ORD( PercentageEach );
            MaxRatePercent := TRUNC((Ratio * 100.0) + 0.5);
            IF (At > MaxRatePercent) THEN
                PercentageEach := CHR(MaxRatePercent);
            ELSIF ((MaxRatePercent MOD At) <> 0) THEN

           (* Find the CLOSEST match, by checking all differences (BestD). *)

                (*  ---------------------------------------------------------
                    Removed this stuff which adjusts the NumberAt & percent

                BestD := (MaxRatePercent MOD At);
                i     := At;
                WHILE (BestD <> 0) AND (i > 1) AND ((MaxRatePercent DIV (i-1)) < 999) DO
                    DEC( i );
                    j := MaxRatePercent MOD i;
                    IF (j < BestD) THEN
                        BestD := j;
                        At    := i;
                    END;
                END;

                ------------------------------------------------------------*)

                PercentageEach := CHR( At );
            END;
        END;

        (* Normalize the MaxRatePercent so it devides evenly with % each. *)

        IF (PercentageEach = 0C) THEN
            MaxRatePercent := 0;
            PercentageEach := 1C;   (* 7-Apr-92 TGS *)
        ELSE
            At             := ORD( PercentageEach );
            MaxRatePercent := ((MaxRatePercent DIV At) * At);
        END;
    END;
END AjustPercentages;



PROCEDURE ScaleAssignments( VAR Assignment : AnAssignmentRecord;
                                Context    : ADDRESS) : BOOLEAN;
VAR
    FTaskDuration : POINTER TO REAL;
    Ratio         : REAL;
BEGIN

      (* If in duration, not percentage . . .
                
          use 'MaxRateUnits' to mean 'Assignment Duration' temporarily.
       *)

    WITH Assignment DO
        IF (RTempFlag1 IN Assignment.Attributes) THEN
            FTaskDuration := Context;
            Ratio         := (FLOAT(MaxRateUnits) / FTaskDuration^) + 0.0045;
            AjustPercentages( Assignment, Ratio );
        END;
    END;
    RETURN TRUE;
END ScaleAssignments;



(* Get Param - Find a parameter to a keyword.

        Passed:   Text String    is the main string to parse.
                  Keyword Number is the phrase # to look for in the string.
        Returned: Parameter      is the found parameter (could be nil)
*)
PROCEDURE GetParam( VAR TextString,
                        Parameter     : ARRAY OF CHAR;
                        KeywordNumber : CARDINAL       ) : BOOLEAN;
VAR
    i,j : CARDINAL;
    s   : ARRAY [0..79] OF CHAR;
BEGIN
    Parameter[0] := 0C;  (* Nil string to start with *)
    GetMessage( KeywordNumber, s );  (* Param to look for *)
    ConcatS(    s, " " );            (* Tack on a seperator *)

    i := Search( TextString, s, 1 ); (* Is it there? *)
    IF (i = 0) THEN
        RETURN FALSE;  (* Not there. *)
    END;

    j := i + ORD(s[0]); (* Where the end of the string is. *)

    WHILE (i < j) DO
        TextString[ i ] := "~";
        INC( i );  (* Skip the string. *)
    END;

    WHILE (i <= ORD(TextString[0])) AND (TextString[ i ] = " ") DO
        INC( i );  (* Skip the spaces between string and arg. *)
    END;

    j := 0;
    WHILE (i <= ORD(TextString[0])) AND (TextString[ i ] <> " ") DO
        IF (j < HIGH(Parameter)) THEN
            INC( j );
            Parameter[ j ] := TextString[ i ];
        END;
        TextString[ i ] := "~";
        INC( i );  (* Skip the string. *)
    END;

    Parameter[ 0 ] := CHR(j);  (* Set the length *)

    RETURN (j <> 0);

END GetParam;





PROCEDURE ParseMiscResourceParameters( VAR TextString  : ARRAY OF CHAR;
                                       VAR TimeUnit    : ADurationUnit;
                                       VAR Keyword     : ARRAY OF CHAR;
                                       VAR Rate        : REAL;
                                       VAR TimeUnitChanged,
                                           KeywordChanged,
                                           RateChanged : BOOLEAN
                                     );
VAR
    i          : CARDINAL;
    Parameter  : ARRAY [0..79] OF CHAR;
    ok         : BOOLEAN;
BEGIN
    TimeUnitChanged := FALSE;
    KeywordChanged  := FALSE;
    RateChanged     := FALSE;
    TimeUnit        := Hours;  (* Defualt for RATE, below *)

    IF (GetParam( TextString, Parameter, ModuleNumber + 2)) AND  (* Per *)
       (MatchADurationUnit( Parameter, 1, TimeUnit, i ))        THEN
        TimeUnitChanged := TRUE;
    END;

    IF (GetParam( TextString, Keyword, ModuleNumber + 3)) THEN (* Keyword *)
        KeywordChanged := TRUE;
    END;

    IF (GetParam( TextString, Parameter, ModuleNumber + 4)) THEN (* Rate *)
        AmountToReal( Parameter, Rate, ok );
        IF (ok) THEN
            RateChanged := TRUE;
        END;
    END;

END ParseMiscResourceParameters;





PROCEDURE AddResourceAssignment( VAR TextString           : ARRAY OF CHAR;
                                     TaskNode             : ATreeNode;
                                     TaskDurationExplicit : BOOLEAN;
                                 VAR Resource             : AResourcePointer );
CONST
    EndOfNameString = "*";
    Squigle         = "~";
    LModuleNumber   = 3000; (* For GetMessage, SAME AS RsrcEdit and TLRsrc!! *)

VAR
    Task                : ATaskPtr;
    ResourceNode        : ATreeNode;
    At,
    i,j,Length          : CARDINAL;
    Rate,
    Amount,
    Percentage,
    FDuration           : REAL;
    Duration            : ADuration;
    Array               : AnAssignmentArray;
    Assignment          : AnAssignmentRecord;
    TimeUnit            : ADurationUnit;
    PerTimeUnit         : ADurationUnit;
    Keyword             : ARRAY [0..10] OF CHAR;
    TimeUnitChanged,
    KeywordChanged,
    RateChanged         : BOOLEAN;
    GivenAsDurationFlag : BOOLEAN;
    Parameter           : ARRAY [0..79] OF CHAR;
    ResourceName        : ARRAY [0..ResourceNameLength] OF CHAR;
    ResourceLongName    : ARRAY [0..50] OF CHAR;
    ok                  : BOOLEAN;
BEGIN
    Resource := NIL;    (* RSC 15-Aug-89 *)

    IF (GetExtStatus() <> ExtGood) THEN
        RETURN;
    END;

        (* NOTE -- We use the Conflict flag in the resource assignment
                   record to tell us whether the assignment was in duration
                   or percentage.  TRUE :: Duration.
         *)

        (* Parse some special keywords.... *)

    Upshift( TextString );
    ParseMiscResourceParameters( TextString, PerTimeUnit, Keyword, Rate,
                             TimeUnitChanged, KeywordChanged, RateChanged );

        (* Find the duration assigned.  If no duration, make one up.
           Otherwise, remove it from the string. *)

    Percentage := 1.0;
    At         := 100;
    GivenAsDurationFlag := FALSE;
    IF (MatchAndRemoveADuration(TextString,1,Duration,TimeUnit)) THEN
        GivenAsDurationFlag := TRUE;
    ELSE

     (* Otherwise look for the amount assigned, as in "30%" or "3.0" or
        "3 at 100%".  Look for the "AT xx%" first, so we don't find and
        remove the xx% in "MatchAndRemoveAPercentage".

                AT xx% RULES:

                        "%"  optional and assumed.
                        "xx" must be numeric and between 0 and 250.
                             if > 250, it is set to 250.
                        If no preceeding number, "1 AT xx%" is assumed.

                N AT xx% RULE:

                        N is multiplied by xx% to come up with the effective
                             percentage (for MaxRatePercent).

                N        RULE:

                        No "AT xx%" is the same as "AT 100%".

                N%       RULE:

                        If N% <= 250 then we assume they meant "1 AT N%"
                        Otherwise we assume they meant (N% / 100) AT 100%.
                        If an AT is specified, it is used as if you said
                        "200% AT 10%", and should come out as "20 AT 10%".
     *)
        IF (GetParam( TextString, Parameter, ModuleNumber + 10)) THEN (* " AT" *)
            j  := 1;
            At := StoC( Parameter, j );
            IF (j > 1) THEN
                IF (At >  250) THEN
                    At := 250;
                END;
            ELSE
                At := 100;
            END;
        END;

        SetString(Parameter,EndOfNameString);

        i := Search( TextString, Parameter, 1 );

        IF ( i = 0 ) THEN                                           (* 16-Nov-89 MWP *)
           i := LengthOf ( TextString );
           INC(i);
        END;

        (* 19-Oct-89 MWP - When removing numbers, start the removal
           process after the resource name field, so we can have
           numbers within the resource name.
        *)
        IF (MatchAndRemoveAPercentage(TextString,i,Percentage)) THEN
            IF (Percentage <= 2.5) AND (At = 100) THEN
                At := TRUNC( (Percentage * 100.0) + 0.5 );
            END;
        ELSIF (MatchARealNumber(TextString,i,j,Percentage)) THEN
            ReplaceWordWithBlap(TextString,j);
            IF (At <> 100) THEN
                Percentage := ((Percentage * FLOAT(At)) / 100.0) + 0.005;
            END;
        ELSE
            IF (At <> 100) THEN
                Percentage := FLOAT(At) / 100.0;
            END;
        END;
    END;

        (* Reduce place holder marks. *)

    CondensePlaceHolders(TextString);

 (* Now, finally, parse the name.  We wait until now, because we want to
    parse and remove all other text that is parseable.  This way, If you
    have @BOB 1 DAY the name becomes BOB because the 1 DAY has been removed.
 *)
    TrimFront( TextString );       (* Remove any leading spaces *)
    Remove(    TextString, 1, 1 ); (* And the "@" sign. *)
    TrimFront( TextString );       (* Remove any [now] leading spaces *)

    SetString(Parameter,EndOfNameString);
    i := Search( TextString, Parameter, 1 );
    IF (i=1) THEN FatalError; END; (* Should be trapped in ParseTaskData *)

    SetString(Parameter,Squigle);
    j := Search( TextString, Parameter, 1 ); (* Search for squiggle. *)
    IF (j < i) AND (j > 0) THEN i := j; END;
    IF (i = 0) AND (j > 0) THEN i := j; END;

  (* First fill in the long name, as that is the most flexible. *)

    IF (i = 0) OR (i > HIGH(ResourceLongName)) THEN
        SubStr( TextString, ResourceLongName, 1, HIGH( ResourceLongName ) );

    ELSE
        SubStr( TextString, ResourceLongName, 1, i-1 );

    END;
    TrimRear( ResourceLongName );


  (* Now fill in the more fussy short name. *)

    IF (i = 0) OR                       (* not found *)
       (i >  HIGH(ResourceName)+1) THEN (* too far right. *)
        i := HIGH(ResourceName)+1;
    END;

        (* Store the resource name. *)

    SubStr( TextString, ResourceName, 1, i-1 );
    IF (j > 0) THEN (* there was an explicit name so remove it. *)
        Remove( TextString, 1, j+1 ); (* and the "--" too. *)
    END;
    TrimRear(  ResourceName );
    IF ResourceName[0] = 0C THEN
       RETURN;
    END;  (* No name?  No problem! Fuck em! *)
    AjustName( ResourceName );

        (* Locate a resource by that name. *)

    ResourceNode := FindResourceByName(ResourceName);
    IF (ResourceNode = NIL) THEN
        IF (NOT CreateResource(ResourceNode)) THEN RETURN; END;
        Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
        WITH Resource^ DO
            Copy(ResourceName,Name);
            Copy(ResourceLongName,LongName);
        END;
        ChangedResource( ResourceNode );
    END;

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF TimeUnitChanged THEN
        Resource^.Units := PerTimeUnit;
    END;
    IF KeywordChanged THEN
        Copy( Keyword, Resource^.Keyword );
    END;
    IF RateChanged THEN
        Resource^.ActualRates := CreateRateList(
                                    WorkHoursToRealTime(Rate,PerTimeUnit), (* 1 / RealTimeToWorkHours *)
                                    MINBIGTIME );
        GetMessage(LModuleNumber + 12 + ORD(PerTimeUnit), Resource^.UnitOfMeasure); (* "Hours" *)
    END;

        (* If no duration is given for the task, compute one in
           terms of the resource assignments.   If there are other
           resources already assigned, adjust their allocations.
        *)

    Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    IF (GivenAsDurationFlag) AND
       (Duration > NoDuration) AND
       (Duration > Task^.duration) AND
       ( NOT TaskDurationExplicit ) THEN

        Task^.duration := Duration;      (* MAX of resource durations. *)
        Task^.scale    := TimeUnit;

            (* Adjust previously assigned resources that were
               expressed in durations. *)

        FDuration := DurationToReal(Duration);
        IF (Task^.Plan.Assignments <> AnExtHandle(NIL)) THEN
            ForEachAssignment( Task^.Plan.Assignments,
                               ScaleAssignments,
                               ADR(FDuration) );
        END;
    END;


        (* Determine the percentage to assign. *)

    IF (GivenAsDurationFlag) THEN
            (* Ok, now the task may be 3 weeks long, but we only need
               the resouce for 1 week.  Set the percentage. *)
        IF (Duration = NoDuration) OR (Task^.duration = NoDuration) THEN
            Amount := Zero;
        ELSIF (Task^.duration = Duration) THEN
            Amount := 1.0;
        ELSE
            Amount := (
                        DurationToReal(Duration) 
                        / 
                        DurationToReal(Task^.duration)
                       ) + 0.0045;
        END;
    ELSE
        Amount := Percentage;
        IF (At = 0) THEN
            Amount := Zero;
        END;
    END;

    WITH Assignment DO
        Resource        := ResourceNode^.Methods^.GetDataObject( ResourceNode );
        Attributes      := AnAssignmentAttributeSet{AllowLevel,Billable};
        IF (GivenAsDurationFlag) THEN
            INCL( Attributes, RTempFlag1 );
        END;
        MaxRatePercent  := 100;
        PercentageEach  := CHR(At);
        ActualTimeUnits := Days;
        MaxRateUnits    := CARDINAL(Duration);   (* Temp storage area. *)
        Expenses        := AnExtHandle(NIL);
        ActualQuantity  := Zero;
        YetToGoQuantity := Zero;
            (* 13-Nov-91 TGS init all this stuff: *)
        OvertimeHours       := 0L;
        YetToGoOvertimeHours:= 0L;
        ExtraCosts          := Zero;
        VaryingAssignment   := AnExtHandle(NIL);
        EndOfSpentDate      := 0;
        Spare               := {};
        Roles               := ASetOfRoles{};
        OvertimeTimeUnits   := Days;
    END;
    AjustPercentages( Assignment, Amount );

    IF (ADDRESS(Task^.Plan.Assignments) = NIL) THEN
        ALLOCATE( Array, ArraySize(1,TSIZE(AnAssignmentRecord)) );
        i         := 0;
        IF (NOT CreateExtObjectWithSize( Task^.Plan.Assignments,
                                         ExtMedium,
                                         ArraySize(1,TSIZE(AnAssignmentRecord)) )) THEN
            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
            RETURN;
        END;
    ELSE
        i := NumberOfElements( GetExtSize( Task^.Plan.Assignments ),
                               TSIZE(AnAssignmentRecord) );
        ALLOCATE(Array, ArraySize((i + 1),TSIZE(AnAssignmentRecord)));
        j := GetExtData( Task^.Plan.Assignments, Array );
    END;
    Array^[i] := Assignment;
    IF (SaveHeapCopy( Task^.Plan.Assignments,
                      Array,
                      ArraySize((i + 1),TSIZE(AnAssignmentRecord)))) THEN
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

END AddResourceAssignment;






    (* ReadSubLines -- Read in all lines at Level > OurLevel, and
                       Add them to the text node.  Skip over the first
                       'SkipOver' bytes if they are spaces.
                       *)


PROCEDURE ReadSubLines ( VAR f                  : File;
                             ReadATaskData      : AReadATaskDataProc;
                         VAR Text               : AText;
                             SaveText           : BOOLEAN;
                             OurLevel           : CARDINAL;
                             SkipOver           : CARDINAL  );
VAR
    Skipped,
    FillSize,
    Level                   : CARDINAL;
    ok, Eof, FirstTime      : BOOLEAN;
    Filler,
    TextString              : ARRAY [0..255] OF CHAR;
BEGIN
        (* Read in all lines at a level > the level of the
           next line read.  Oh, yes.  The first line is at OurLevel,
           as the caller PUSHED it.
         *)
    FirstTime := TRUE;
    LOOP
        ReadATaskData(f,TextString,Level,Eof);
        IF (Eof) OR (ErrorFlag) THEN
            EXIT;
        END;
        IF (Level < OurLevel) OR ((NOT FirstTime) AND (Level = OurLevel)) THEN
            PushText(TextString,Level);
            EXIT;
        END;
        FirstTime := FALSE;

        IF SaveText THEN
            IF (ADDRESS(Text) = NIL) THEN
                Text := CreateText();
            END;
            Skipped := 0;
            WHILE (Skipped < SkipOver)            AND
                  (Skipped < ORD(TextString[0]))  AND
                  ((TextString[Skipped+1] = " ")   OR
                   (TextString[Skipped+1] = "-"))  DO
                INC(Skipped);
            END;

            FillSize := (Level - OurLevel);
            IF (Skipped > 0) THEN
                Remove( TextString, 1, Skipped );
            END;

            IF (FillSize > (SkipOver - Skipped)) THEN
                DEC( FillSize, (SkipOver - Skipped));
            ELSE
                FillSize := 0;
            END;

            IF (FillSize > 0) THEN
                Fill( Filler, " ", FillSize ); (* Add leading blanks? *)
                Insert( TextString, Filler, 1 );
            END;

            IF (TextString[0] >  MaxTextLineLength) THEN
                TextString[0] := MaxTextLineLength;
            END;
            ok := AppendLine( TextString, Text );
            Compress( Text );
        END;
    END;

END ReadSubLines;





PROCEDURE CleanUpParent( ParentTask : ATreeNode;
                         DueFlag    : BOOLEAN  );
VAR
    TaskRecord : ATask;


    (* Create a new milestone and add it as the last kid for the parent task.
       "TaskRec" is used to get data from the mother task.  It is input only.
    *)
    PROCEDURE AddLastKid( VAR TaskRec : ATask ) : ATreeNode;
    VAR
        KidNode : ATreeNode;
        KidTask : ATaskPtr;
        s       : ARRAY [0..29] OF CHAR;
    BEGIN
        KidNode := CreateTask();
        IF (KidNode = NIL) THEN
            RETURN KidNode;
        END;
        KidTask := KidNode^.Methods^.LockFlexStorDataObject( KidNode );
        WITH KidTask^ DO
            Copy( TaskRec.taskname, taskname );
            GetMessage( ModuleNumber + 1, s ); (* "-End" *)
            Procustes( taskname, (HIGH(taskname) - ORD(s[0])) );
            TrimRear(  taskname );
            ConcatLS(  taskname, s );
            fixation              := FixedDate;
            scale                 := TaskRec.scale;
            EffortScale           := TaskRec.EffortScale;
            WITH Plan.Dates DO
                CalendarTimeToBigTime(TaskRec.Plan.Dates.EarlyEnd,TRUE,
                                      KidTask^.UserEnteredStartDate);
                EarlyStart     := BigTimeToCalendarTime(
                                      KidTask^.UserEnteredStartDate);
                LateFreeStart  := EarlyStart;
                LateTotalStart := EarlyStart;
                EarlyEnd       := EarlyStart;
                LateFreeEnd    := EarlyEnd;
                LateTotalEnd   := EarlyEnd;
            END;
        END;
        KidNode^.Methods^.UnlockFlexStorDataObject( KidNode );
        AddTask (KidNode, ParentTask, ParentTask^.Methods^.LastChild( ParentTask ));
        RETURN KidNode;
    END AddLastKid;


    (* For each of the OTHER children of the parent task, make sure that
       they are joined to SOME successor.  If not, join them to the 
       LastKid node.
    *)
    PROCEDURE JoinToLastKid( LastKid : ATreeNode );
    VAR
        Kid    : ATreeNode;
        Task   : ATaskPtr;
        Edge   : AnEdgePtr;
    BEGIN
        IF (LastKid = NIL) THEN  (* Failed to add last kid? *)
            RETURN;
        END;

        Kid := ParentTask^.Methods^.FirstChild( ParentTask );
        WHILE (Kid <> NIL) AND (Kid <> LastKid) DO
            Task := Kid^.Methods^.LockFlexStorDataObject( Kid );
            IF (Task^.desctasks = NIL) THEN
                Edge := CreateEdge( Kid, LastKid );
                IF (Edge <> NIL) THEN
                    AddEdge( Edge, TRUE );  (* TRUE = <Set recalc bits> *)
                END;
            END;
            Kid^.Methods^.UnlockFlexStorDataObject( Kid );
            Kid := Kid^.Methods^.GetNext( Kid );
        END;
    END JoinToLastKid;


    (* Sanitize the task given in Node and return the task record.
    *)
    PROCEDURE SanitizeTask( Node    : ATreeNode;
                        VAR TaskRec : ATask      );
    VAR
        Task : ATaskPtr;
    BEGIN
        Task := Node^.Methods^.LockFlexStorDataObject( Node );
        WITH Task^ DO
            DurationMethod := DurationDriven;
            fixation       := ASAP;
        END;
        TaskRec := Task^;
        Node^.Methods^.UnlockFlexStorDataObject( Node );
    END SanitizeTask;


BEGIN
    SanitizeTask( ParentTask, TaskRecord );
    IF (DueFlag) THEN
        JoinToLastKid( AddLastKid(TaskRecord) );
    END;
END CleanUpParent;





  (* Is A Meta Command - See if this line is a metaline. *)

PROCEDURE IsAMetaCommand( VAR TextString : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
    i := 1;
    WHILE (i <= ORD(TextString[0])) AND (TextString[i] = " ") DO
        INC(i);
    END;
    RETURN (i <= ORD(TextString[0])) AND (TextString[i] = "$");
END IsAMetaCommand;


  (* Handle Meta Lines:

     Given that this IS a meta line, process it and set the length of
     the text string to 0.

     This procedure absorbs the metaline and updates the MasterSequence and
     LevelHistory.
  *)
PROCEDURE HandleMetaLines( VAR TextString,
                               MasterSequence     : ARRAY OF CHAR;
                               WBSIntoMaster      : BOOLEAN;
                           VAR Context            : AContext;
                           VAR LevelHistory       : ALevelHistory );
VAR
    i    : CARDINAL;
    Task : ATask;
    WBS  : ARRAY [0..WBSLen] OF CHAR;

BEGIN
    ParseTaskData(TextString,Task,Context);
    TextString[0] := 0C;

    (* If WBS was given, fart around with it so the NEXT task
       will get this WBS number.
    *)
    GetCodingField (Task, WBSLine, WBS);
    IF (WBS[0] <> 0C) THEN
        IF WBSIntoMaster THEN
            Copy( WBS, MasterSequence );
            i := 0;
        ELSE
            ParseWBS( WBS, MasterSequence, LevelHistory.SequenceNumber );
            i := ORD(LevelHistory.SequenceNumber[0]);
        END;
        IF (i > 0) THEN
            DEC(LevelHistory.SequenceNumber[i]);
        ELSE
            i := ORD(MasterSequence[0]);
            DEC(MasterSequence[i]);
        END;
    END;
END HandleMetaLines;








    (* ReadSubtasks -- Read in all tasks at Level >= OurLevel, and
                       all subordinate
                       tasks from the file, linking them as
                       subtasks. *)


PROCEDURE ReadSubtasks ( VAR f                  : File;
                             ReadATaskData      : AReadATaskDataProc;
                             MasterTask         : ATreeNode;
                             MasterSequence     : ARRAY OF CHAR;
                             UseMasterSequence  : BOOLEAN;
                             MasterContext      : AContext;
                             OurLevel           : CARDINAL;
                             Indentation        : CARDINAL;
                         VAR LevelHistory       : ALevelHistory );
VAR
    TrimTo,
    i                       : CARDINAL;
    T                       : ATaskPtr;
    Resource                : AResourcePointer;
    CurrentTask             : ATreeNode;
    Edge                    : AnEdgePtr;
    Level                   : CARDINAL;
    Task                    : ATask;
    Context                 : AContext;
    SubLevelHistory         : ALevelHistory;
    NillNotes               : AText;
    Join,
    Eof,
    Carry,
    LocalDueFlag,
    ok                      : BOOLEAN;
    S,
    TextString              : ARRAY [0..255] OF CHAR;
    WBS                     : ARRAY [0..WBSLen] OF CHAR;


    PROCEDURE ProcessResourceLine;
    BEGIN
         WITH LevelHistory DO
             IF (LastTaskOurLevel = NIL) THEN RETURN; END; (* No prior task? *)

             T  := LastTaskOurLevel^.Methods^.LockFlexStorDataObject( LastTaskOurLevel );
             IF (ORD(TextString[0]) < 254) THEN
                 SetString( S, "  " );
                 ConcatLS(  S, TextString );
             END;
             IF (S[0] >  MaxTextLineLength) THEN
                 S[0] := MaxTextLineLength;
             END;
             ok := AppendLine( S, T^.notes );
             Compress( T^.notes );
             LastTaskOurLevel^.Methods^.UnlockFlexStorDataObject( LastTaskOurLevel );
             AddResourceAssignment(TextString,
                                   LastTaskOurLevel,
                                   LastContextOurLevel.DurationExplicit,
                                   Resource );

            (* RSC 15-Aug-89 The resource pointer can come back NIL, meaning
                             that there was no resource name or no room.
            *)
             IF (Resource <> NIL) THEN
                 (* Read and ignore any sublines. *)
                 ReadSubLines( f, ReadATaskData,
                               Resource^.Notes, TRUE, Level+1, 0 );
             END;
         END;

    END ProcessResourceLine;



    PROCEDURE ProcessCommentLines();
    BEGIN
        CurrentTask := MasterTask;
        IF (ADDRESS(LevelHistory.LastTaskOurLevel) <> NIL) THEN
            CurrentTask := LevelHistory.LastTaskOurLevel;
        END;

        TrimTo := 0;
        WHILE (TrimTo < ORD(TextString[0])) AND
              ((TextString[TrimTo+1] = "-")   OR
               (TextString[TrimTo+1] = " "))  DO
            INC(TrimTo);
        END;
        PushText(TextString,Level);
        IF (ADDRESS(CurrentTask) <> NIL) THEN
            T := CurrentTask^.Methods^.LockFlexStorDataObject( CurrentTask );
            ReadSubLines( f, ReadATaskData, T^.notes, TRUE, Level, TrimTo );
            CurrentTask^.Methods^.UnlockFlexStorDataObject( CurrentTask );
        ELSE
            ReadSubLines( f, ReadATaskData, NillNotes, FALSE, Level, TrimTo );
        END;
    END ProcessCommentLines;



BEGIN
    NillNotes := AText(NIL);

    WITH LevelHistory DO
        IF (NewSequence) THEN
            SubLevelHistory.NewSequence := TRUE;
            LastContextOurLevel         := MasterContext;
            LastTaskOurLevel            := NIL;      (* Redundant *)
            PrecedingTaskEnd            := NIL;
            NotSplitYet                 := TRUE;
            IF UseMasterSequence THEN
                Copy( MasterSequence, SequenceNumber );
                MasterSequence[0] := 0C;
            ELSE
                Fill(SequenceNumber,"0",CharactersPerLevel);
            END;
            NewSequence                 := FALSE;
        END;
    END;

        (* Read in all tasks at a level >= the level of the
           next task read.  *)

    LOOP
        IF (NOT HeapAvailable()) OR (BreakRequested()) THEN
            ErrorFlag := TRUE;
            RETURN;
        END;

        TextString[0] := 0C;
        WHILE (TextString[0] = 0C) DO
            ReadATaskData(f,TextString,Level,Eof);
            IF (Eof) OR (ErrorFlag) THEN
                EXIT;
            END;

  (* If they set a default, use it.  Otherwise use our parent's defaults. *)

            IF (MetacommandsSeen) THEN
                Context := MetaContext;
            ELSE
                Context := MasterContext;
            END;

            IF (IsAMetaCommand( TextString )) THEN
                HandleMetaLines( TextString, MasterSequence, FALSE,
                                 Context,    LevelHistory );
            END;
        END;

        IF ( Level < OurLevel ) THEN
                (* This sequence is definitely ended if the text is
                   a task at a higher level.  Other line types at
                   a higher level will end the sequence also in order
                   to prevent us from reentering this level with
                   an unitialized LevelHistory. *)
            LevelHistory.NewSequence := TRUE;   (* End this sequence of tasks. *)
            PushText(TextString,Level);
            EXIT;
        ELSIF (MasterContext.LineType <> ATaskLine) THEN
            (* Subordinate lines to non-task lines are comments. *)
        ELSIF ( Level > OurLevel ) THEN
            ParseTaskData(TextString,Task,Context);
            CASE Context.LineType OF
            | ATaskLine :
                    (* Postpone processing the subtask's data string.  *)
                PushText(TextString,Level);
                    (* Was there a WBS number? *)
                GetCodingField (Task, WBSLine, WBS);
                IF (WBS[0] = 0C) THEN
                    CreateWBS( MasterSequence, LevelHistory.SequenceNumber, WBS );
                    SetCodingField (Task, WBSLine, WBS);
                    GetCodingField (Task, WBSLine, WBS);
                END;
                    (* Read all subtasks. *)
                LocalDueFlag := LevelHistory.LastContextOurLevel.DueFlag;
                ReadSubtasks( f,
                              ReadATaskData,
                              LevelHistory.LastTaskOurLevel,
                              WBS,
                              FALSE,
                              LevelHistory.LastContextOurLevel,
                              Level,
                              Indentation+1,
                              SubLevelHistory );
                CleanUpParent( LevelHistory.LastTaskOurLevel, LocalDueFlag );
            | AResourceLine:
                ProcessResourceLine();
            | ACommentLine:
                    (* Read and save as text all sublines. *)
                ProcessCommentLines();
            ELSE
                FatalError;
            END;
        ELSIF (Level = OurLevel ) THEN
                (* Assume that the date is similar to the last date
                   processed. *)
            IF (MasterContext.JoinFlag) AND (LevelHistory.PrecedingTaskEnd <> NIL) THEN
                T := LevelHistory.PrecedingTaskEnd^.Methods^.LockFlexStorDataObject(LevelHistory.PrecedingTaskEnd);
                Context.ParallelDate := T^.Plan.Dates.EarlyStart;
                Context.Date         := Add(T^.Plan.Dates.EarlyStart, T^.duration);
                LevelHistory.PrecedingTaskEnd^.Methods^.UnlockUnchangedDataObject(LevelHistory.PrecedingTaskEnd);
            END;
                (* Parse the line. *)
            ParseTaskData(TextString,Task,Context);
                (* What kind of line is it? *)
            IF (Context.LineType = ACommentLine) THEN
                   (* Read and save as text all sublines. *)
                ProcessCommentLines();
            ELSIF (Context.LineType = AResourceLine) THEN
                ProcessResourceLine();
            ELSIF ( Context.LineType = ATaskLine ) THEN
                LevelHistory.LastContextOurLevel := Context;    (* Save Context of most recent task. *)

                    (* Reading the TextString, convert it to a task, update
                       the Context.   (Context both an in and out parm.) *)
                    (* Fill in any WBS number. *)
                IncrementString(LevelHistory.SequenceNumber,Carry);
                GetCodingField (Task, WBSLine, WBS);
                IF (WBS[0] = 0C) THEN
                    CreateWBS( MasterSequence, LevelHistory.SequenceNumber, WBS );
                    SetCodingField (Task, WBSLine, WBS);
                ELSE
                    ParseWBS( WBS, MasterSequence, LevelHistory.SequenceNumber );
                END;
                    (* Create new task. *)
                CurrentTask := CreateTask();
                IF (CurrentTask = NIL) THEN
                    ErrorFlag := TRUE;
                    RETURN;
                END;
                T  := CurrentTask^.Methods^.LockFlexStorDataObject(CurrentTask);
                T^ := Task;
                CurrentTask^.Methods^.UnlockFlexStorDataObject(CurrentTask);

                    (* Link into hierarchy. *)
                AddTask( CurrentTask, MasterTask, LevelHistory.PrecedingTaskEnd );
                WITH LevelHistory DO
                        (* Join if need be *)
                    IF (Context.JoinFlag AND (PrecedingTaskEnd <> NIL)) THEN
                        IF (NOT (ItDepends(PrecedingTaskEnd,CurrentTask) OR
                                 ItDepends(CurrentTask,PrecedingTaskEnd))) THEN
                            Edge := CreateEdge( PrecedingTaskEnd, CurrentTask );
                            IF (Edge <> NIL) THEN
                                AddEdge( Edge, TRUE );  (* TRUE = <Set recalc bits> *)
                            END;
                        END;
                    END;
                END;

                    (* Store the current task as the task to link the
                       next one read to. *)
                LevelHistory.PrecedingTaskEnd := CurrentTask;
                    (* NotSplitYet is to cover a wierd case such as
                       1.  AAAAAA
                               3.   BBBBBB
                           2.  CCCCCCC
                    *)
                LevelHistory.NotSplitYet      := TRUE;

                LevelHistory.LastTaskOurLevel := CurrentTask;

            ELSE
                FatalError;
            END;
        END;
    END;
END ReadSubtasks;






PROCEDURE CleanAssignments( VAR Assignment : AnAssignmentRecord;
                                Context    : ADDRESS ) : BOOLEAN;
VAR
    MaxPeople       : CARDINAL;
    BStartDate, BThruDate : ABigTime;
    Avail, OldAvail : AnAvailabilityRate;
    ok              : BOOLEAN;

BEGIN
    WITH Assignment DO
        EXCL( Attributes, RTempFlag1 );

        (* Raise the limit? *)

        WITH Resource^ DO (* 5-Feb-91 TGS *)
            Avail.Percent := ORD(PercentageEach);
            Avail.Amount  := MaxRatePercent DIV ORD(Avail.Percent);
            IF (Avail.Percent <> DefaultAvailabilityPercent) OR
               (Avail.Amount  <> DefaultAvailabilityAmount)  THEN
                IF Availability = ADateList(NIL) THEN
                    Availability := CreateDateList(Avail, MINBIGTIME);
                ELSE
                    IF GetDateListEntry(Availability, 1, BStartDate, BThruDate, OldAvail) THEN
                        IF (Avail.Percent > OldAvail.Percent) THEN
                            OldAvail.Percent := Avail.Percent;
                        END;
                        IF (Avail.Amount > OldAvail.Amount) THEN
                            OldAvail.Amount := Avail.Amount;
                        END;

                        ok := SetDateListEntryN(Availability, 1, Avail);
                        IF GetDateListEntry(Availability, 2, BStartDate, BThruDate, Avail) THEN
                            IF (OldAvail.Percent = Avail.Percent) AND
                               (OldAvail.Amount  = Avail.Amount)  THEN
                                DisposeDateListEntry(Availability, TSIZE(AnAvailabilityRate), 2);
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;

    RETURN TRUE;
END CleanAssignments;





PROCEDURE SetDoneAssignments( VAR Assignment : AnAssignmentRecord;
                                  Context    : ADDRESS ) : BOOLEAN;
BEGIN
    WITH Assignment DO
        ActualQuantity  := YetToGoQuantity;
        YetToGoQuantity := Zero;
    END;
    RETURN TRUE;
END SetDoneAssignments;




PROCEDURE FixStartStatus( VAR Node      : ATreeNode;
                              Context   : ADDRESS   );
VAR
    TaskPtr             : ATaskPtr;
    Status              : AStartStatus;
BEGIN

    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);

 (* Step 1 - Clean up assignment records.
 *)

    ForEachAssignment( TaskPtr^.Plan.Assignments,
                       CleanAssignments,
                       NIL );

 (* Step 2 - Figure out the start status. *)

    IF (TempTaskFlag1 IN TaskPtr^.TempTaskFlags) THEN
        Status := TaskPtr^.StartStatus;
        EXCL( TaskPtr^.TempTaskFlags, TempTaskFlag1 );
    ELSE
        Status := AppropriateStartStatus(TaskPtr^,AsOfDate);
        TaskPtr^.StartStatus := Status;
    END;

    IF (TaskPtr^.StartStatus = DoneS) THEN (* RSC 7/1/88 Bug # 8244 *)
        TaskPtr^.PercentComplete := 100;
    END;

    Node^.Methods^.UnlockFlexStorDataObject (Node);

 (* Now compute the yet to go quantity for the resources.... *)

    ComputeTaskNodeCosts( Node );

 (* And we make ANOTHER pass if this is a DONE task, to move the
    costing data from TO GO to ACTUAL.
 *)
    IF (Status = DoneS) THEN
        TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
        ForEachAssignment( TaskPtr^.Plan.Assignments,
                           SetDoneAssignments,
                           NIL );
        Node^.Methods^.UnlockUnchangedDataObject (Node);
    END;

END FixStartStatus;







PROCEDURE ReadTextFile ( VAR f             : File;
                             ReadATaskData : AReadATaskDataProc;
                             Indent        : BOOLEAN  );
VAR
    Level          : CARDINAL;
    Task           : ATaskPtr;
    TaskRecord     : ATask;
    Context        : AContext;
    SubLevelHistory: ALevelHistory;
    Eof            : BOOLEAN;
    SequenceNumber : ARRAY [0..39]  OF CHAR;
    TextString     : ARRAY [0..255] OF CHAR;
BEGIN

  (* Put back the AS OF DATE because we may have erased the schedule and this
     has the side effect as of June 88 of setting the AS OF DATE to Today,
     ajusted by the (start of day/start of week/etc) settings.  If the setting
     is MANUAL, then we just reset the current time of day.  Appropriate for
     schedule importing perhaps, but not for us.
  *)
    AsOfDate             := TempAsOfDate;

    WITH Context DO
        ParallelDate     := AsOfDate;
        Date             := AsOfDate;
        Fixation         := ASAP;
        DurationExplicit := FALSE;
        Duration         := NoDuration;  (* was UpScale(1,Days);  *)
        Scale            := Days;
        DateFlag         := FALSE;
        DueFlag          := FALSE;
        JoinFlag         := TRUE;
        LineType         := ATaskLine;
    END;
    MetaContext := Context;

    SequenceNumber[0] := 0C;

  (* They may start the outline with one or more metacommands.  If so, we
     don't want to confuse "ReadSubtasks" into thinking that the first
     REAL task is a kid of a metacommand (which would attach the first real
     task to a random parent address).

     Read lines until we come across a REAL task line.  Or the end of the
     file.
   *)
    TextString[0] := 0C;
    WHILE (TextString[0] = 0C) DO
        ReadATaskData(f,TextString,Level,Eof);
        IF (Eof) OR (ErrorFlag) THEN
            RETURN;
        END;

        IF (MetacommandsSeen) THEN
            Context := MetaContext;
        END;

        IF (IsAMetaCommand( TextString )) THEN
            HandleMetaLines( TextString, SequenceNumber, TRUE,
                             Context,    SubLevelHistory );
        END;
    END;

    PushText(TextString,Level);
    SubLevelHistory.NewSequence := TRUE;

    ReadSubtasks(f,ReadATaskData,NIL,
                 SequenceNumber,FALSE,Context,Level,0,SubLevelHistory);

            (* Fix Start Statusses *)

    TaskTree^.Methods^.TraverseTree(TaskTree,
                                    ParentAfterChild,
                                    9999,
                                    FixStartStatus,
                                    NIL);

  (* If they have manual recalc, let them know that they need to recalc. *)

    UnSetState( Scheduled );

          (* 6-Aug-90 RSC Couldn't figure out how to do this now. *)

(*    IF (PlanLevel = NoPlanning) THEN*)
        GetMessage(ModuleNumber+15,TextString); (* "Remember to recalc your schedule" *)
        Error(TextString);
(*    END;*)

END ReadTextFile;






BEGIN

  (* Save off the AS OF DATE so we can put it back later.  There is a ROOT
     BUG as of June 88 which resets the AS OF date to TODAY during an ERASE.
     In order to prevent this, we save the AS OF date for now.
  *)
    TempAsOfDate         := AsOfDate;

    ErrorFlag            := FALSE;
    MetacommandsSeen     := FALSE;

END InText.


