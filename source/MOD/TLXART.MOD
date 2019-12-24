MODULE TLXArt;

    (*  MODIFICATION HISTORY --
        26-Feb-90 TGS  Adjusted imports for Time Line 4.0.
        11-Dec-91 TGS   Adjust imports for TL5.
    *)

FROM Allocs                 IMPORT 
    (* TYPE *)                  ATaskPtr, ATask, ATaskName, ATempTaskFlag,
                                TaskTree, AStartStatus, AFixType, 
                                ATaskFilter;

FROM ArtExport              IMPORT
    (* TYPE *)                  AnArtemisTaskIDType,
    (* PROC *)                  OpenFile, CloseFile, StartRecord,
                                EndRecord, WriteText, WriteCardinal,
                                WriteReal, WriteStartDate, WriteEndDate,
                                WriteDuration, OutputLString, WriteTaskID,
                                WriteTLine, GetTaskID, FatalWriteError,
                                WritePureDate;

FROM AsOf                   IMPORT
    (* VAR *)                   AsOfDate;

FROM Assignments            IMPORT 
                                AnAssignmentRecord, ForEachAssignment;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM Captions               IMPORT       (* RSC 9/12/88 *)
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  GetColumnValue, 
                                FormatColumnValue;

FROM ChartControl           IMPORT 
    (* TYPE *)                  AChartState,(*Scheduled, Sorted, Filtered, 
                                Formatted, Showing*)
    (* VAR *)                   ChartState;

FROM DateLists              IMPORT 
    (* TYPE *)                  ADateList,
    (* PROC *)                  GetDateListEntry;

FROM Dialog                 IMPORT
    (* PROCS *)                 Error, FatalError;

FROM Edges                  IMPORT
                                AnEdgePtr;

FROM Foreign                IMPORT
    (* PROC *)                  DoDash;

FROM Gantt                  IMPORT 
                                AGanttLineType;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldTypeSet,
    (* PROC *)                  LocateHeldItem;

FROM LStrings               IMPORT
                                SetString, ConcatS, ConcatLS, Copy, Fill,
                                Procustes, TrimFront, TrimRear, Insert,
                                Search, Remove, LengthOf, SetLengthOf, CtoS,
                                RJust;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Planner                IMPORT
        (* VAR *)               Levelling,
                                ScheduleComputedOk;

FROM Progress               IMPORT
        (* TYPE *)              AThermometer,
        (* PROCS *)             CreateThermometer, UpdateThermometer,
                                DiscardThermometer;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AnAvailabilityRate;

FROM RsrcMod                IMPORT
    (* CONST *)                 DefaultCostRate, DefaultAvailabilityAmount,
                                DefaultAvailabilityPercent,
    (* TYPE *)                  AResourcePointer, AResourceType,
    (* VAR *)                   ResourceTree;

FROM SYSTEM                 IMPORT 
                                TSIZE, ADDRESS, ADR;

FROM Text                   IMPORT
                                TextExists, LineExists, CopyLine;

FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat, AnEndDateStyle,
    (* VAR *)                   DefaultDateFormat, DefaultDateAndTimeFormat,
                                EndDateStyle,
    (* PROC *)                  AbsTimeAsEndDateStyle, TimeToString;

FROM Timei                  IMPORT
    (* TYPE *)                  ADuration, ADate, ATimeInfo,
    (* CONST *)                 Jan, Dec, Sun, Sat,
    (* PROC *)                  TimeUtoT, DaysInMonth, DayOfWeek;

FROM Timeu                  IMPORT
    (* TYPE *)                  ATimeTable, AYearTable, AWeekTable,
    (* VAR *)                   TimeTable,
    (* PROC *)                  YearsOnFile;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATreeNodeAttribute;

FROM XArTable               IMPORT
    (* TYPE *)                  AnArtemisExportTable,
                                AnArtemisType,
                                AnActivityIDSource,
                                AnArtemisCalendarType,
                                AnArtemisPeriodType,
                                AnArtemisSummaryType;
 
TYPE
    (* This type is used by the procedures that export resources.  It holds
       the context that is passed as a procedure parameter to a procedure
       that scans all resources for a given task *)

    AnExportContext = RECORD
       pTask:  ATaskPtr;
       pTargetTask: ATaskPtr;
       pExportTable: POINTER TO AnArtemisExportTable;
       Count       : CARDINAL;
    END;


CONST
    ModuleNumber            = 27100;

VAR
    CountOfTasks           : CARDINAL;
    ExportTable            : AnArtemisExportTable;
    A,P                    : ARRAY [0..2] OF CHAR;
    ScheduleStartDate,
    ScheduleEndDate        : ADate;

    GoodCharSet            : SET OF CHAR;      (* Allowable Artemis string chars *)
    Err                    : ARRAY [0..150] OF CHAR;
    ContinueWriting        : BOOLEAN;  (* If FALSE, an error has occurred
                                          and we want to stop exporting. *)


(* RSC 9/13/88. *)
(*  This procedure flags all tasks as invisible by setting the count2 field
    to 0.
*)

PROCEDURE FlagTasksAsInvisible();
VAR
    Task     : ATaskPtr;
    TaskNode : ATreeNode;
BEGIN
    ScheduleStartDate := 65000;
    ScheduleEndDate := 0;


    TaskNode := TaskTree^.Methods^.GetFirst(TaskTree);
    WHILE (TaskNode <> NIL) DO
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        Task^.count2 := 0;

        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
        TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode);
    END;

END FlagTasksAsInvisible;




(* RSC 9/12/88. *)

PROCEDURE MarkVisibleTasks( VAR SequenceNumberCount : CARDINAL );
VAR
    TaskNode : ATreeNode;
    Task     : ATaskPtr;
BEGIN

    SequenceNumberCount := 0;

    TaskNode := TaskTree^.Methods^.GetFirstVisible (TaskTree);
    WHILE (TaskNode <> NIL) DO
        INC(SequenceNumberCount);

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        Task^.count2 := 1;        (* Mark it as visible *)

        (*Adjust our schedule start and end dates based on this task's dates*)
        IF ( Task^.Plan.Dates.EarlyStart < ScheduleStartDate ) THEN
           ScheduleStartDate := Task^.Plan.Dates.EarlyStart;
        END;

        IF ( Task^.Plan.Dates.LateTotalEnd > ScheduleEndDate ) THEN
           ScheduleEndDate := Task^.Plan.Dates.LateTotalEnd;
        END;

        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);    (* RSC 9/12/88 *)

        TaskNode := TaskNode^.Methods^.NextForDisplay(TaskNode);
    END;

END MarkVisibleTasks;


(* Write N  blank fields *)
PROCEDURE WriteBlank(ExportTable:AnArtemisExportTable; N:CARDINAL);

VAR
    blank   : ARRAY [0..2] OF CHAR;

BEGIN
    SetLengthOf(blank, 0);       (* used for writing empty fields *)
    WHILE ( N>0 ) DO
        WriteText(ExportTable, blank, TRUE );
        N := N - 1;
    END;
END WriteBlank;


PROCEDURE EncloseWith   (   VAR s               : ARRAY OF CHAR;
                                C               : CHAR          );

    (*  Surround the string s with the character C *)
VAR
    s2          : ARRAY [0..2] OF CHAR;

BEGIN
    Fill (s2, C, 1);
    Insert (s, s2, 1);
    ConcatLS (s, s2);
END EncloseWith;



PROCEDURE ExpressEndDate( ExportTable: AnArtemisExportTable;
                          EndDate : ADate;
                          Duration : ADuration );
BEGIN
    IF (Duration > 0) THEN
        WriteEndDate(ExportTable, EndDate);
    ELSE
        WriteStartDate(ExportTable, EndDate);
    END;    
END ExpressEndDate;


    PROCEDURE HasNoVisiblePredecessors( Task: ATaskPtr ): BOOLEAN;
    VAR
       nextedge      : AnEdgePtr;
       LinkedTask    : ATaskPtr;
       FoundVisibleTask: BOOLEAN;

    BEGIN
        (* Look for any real predecessors by looping through the linked
           list of predecessors for this task *)

        nextedge := Task^.antetasks;
        FoundVisibleTask := FALSE;
        WHILE ( (nextedge <> NIL) AND (NOT FoundVisibleTask) ) DO
           WITH nextedge^ DO
              LinkedTask := headtask^.Methods^.LockFlexStorDataObject(headtask);
(*            IF LinkedTask^.count2 <> 0 THEN (* task is VISIBLE *)
*)
              IF ( Selected IN LinkedTask^.FilterSet ) THEN
                 FoundVisibleTask := TRUE;
              END;
              headtask^.Methods^.UnlockUnchangedDataObject(headtask);
           END;
           nextedge := nextedge^.taillink;
        END;
        RETURN NOT FoundVisibleTask;
    END HasNoVisiblePredecessors;



    PROCEDURE HasNoVisibleSuccessors( Task: ATaskPtr ): BOOLEAN;
    VAR
       nextedge   : AnEdgePtr;
       LinkedTask : ATaskPtr;
       FoundVisibleTask    : BOOLEAN;

    BEGIN
        (* Look for any real successors by looping through the linked
           list of successors for this task *)

        nextedge := Task^.desctasks;
        FoundVisibleTask := FALSE;

        WHILE ( (nextedge <> NIL) AND (NOT FoundVisibleTask) ) DO
           WITH nextedge^ DO
              LinkedTask := tailtask^.Methods^.LockFlexStorDataObject(tailtask);
(*            IF LinkedTask^.count2 <> 0 THEN (* task is VISIBLE *)
*)
              IF ( Selected IN LinkedTask^.FilterSet ) THEN
                 FoundVisibleTask := TRUE;
              END;
              tailtask^.Methods^.UnlockUnchangedDataObject(tailtask);
           END;
           nextedge := nextedge^.headlink;
        END;
        RETURN NOT FoundVisibleTask;
    END HasNoVisibleSuccessors;

(* This procedure writes the summary hammock and project start and end 
   milestones.  It is called from the procedure to write the activity
   file. *)
PROCEDURE WriteSummaryHammock(ExportTable:AnArtemisExportTable);
VAR
    temp                  : ARRAY [0..255] OF CHAR;
    start,finish,
    hammock               : ARRAY [0..8] OF CHAR;

    Task                  : ATaskPtr;
    RDU                   : ADuration;

BEGIN
    SetString(start, "STA");
    SetString(finish, "FIN");
    SetString(hammock, "HAM");
    Task := NIL;

    IF (ExportTable.ArtemisType <> A6000) THEN
        (* Write project summary hammock record *)
        StartRecord();
        OutputLString(A);

        WriteTaskID(Task, ExportTable, ProjectHammock, TRUE);    (* AN: count or WBS *)
        WriteDuration(ExportTable, TRUE, ScheduleEndDate-ScheduleStartDate); 
                                                                 (* DU: Duration *)
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
        WriteText(ExportTable,ExportTable.FileName, TRUE); (* DES: task name *)
        WriteText(ExportTable,hammock, TRUE);                  (* TYPE *)
        WriteBlank(ExportTable, 4);                            (* F1 .. F4 *)

        RDU := ScheduleEndDate - ScheduleStartDate; 

        IF (ExportTable.ArtemisType <> A6000) THEN
            IF ((Scheduled IN ChartState) AND ScheduleComputedOk ) THEN
                WriteStartDate(ExportTable, ScheduleStartDate);     (* ES *)
                ExpressEndDate(ExportTable, ScheduleEndDate, RDU);  (* EF *)

                IF (Levelling) THEN
                    WriteBlank(ExportTable,2);
                ELSE
                    WriteStartDate(ExportTable, ScheduleStartDate);     (* LS *)
                    ExpressEndDate(ExportTable, ScheduleEndDate, RDU);  (* LF *)
                END;
                    
                WriteStartDate(ExportTable, ScheduleStartDate);     (* ESS *)
                ExpressEndDate(ExportTable, ScheduleEndDate, RDU);  (* EFS *)

                WriteDuration(ExportTable, TRUE, 0);                (* SD *)
            ELSE
                WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
            END;
        END;
    END;

    EndRecord();

    (* Write project start milestone record *)
    StartRecord();
    OutputLString(A);
    WriteTaskID(Task, ExportTable, StartProject, TRUE);  (* AN: count or WBS *)
    WriteDuration(ExportTable, TRUE, 0);           (* DU: Duration *)
    WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
    SetString(temp, "Start ");
    ConcatLS(temp,ExportTable.FileName);
    WriteText(ExportTable,temp, TRUE);                         (* DES: task name *)
    WriteText(ExportTable,start, TRUE);                        (* TYPE *)
    WriteBlank(ExportTable, 4);                              (* F1 .. F4 *)
    (* this is a milestone, so duration is zero.  For milestones,
       we express the start date and the end dates using the 
       start date procedure.  *)

    IF (ExportTable.ArtemisType <> A6000) THEN
        IF ((Scheduled IN ChartState) AND ScheduleComputedOk ) THEN
            WriteStartDate(ExportTable, ScheduleStartDate);   (* ES *)
            ExpressEndDate(ExportTable, ScheduleStartDate,0); (* EF *)

            IF (Levelling) THEN
                WriteBlank(ExportTable,2);
            ELSE
                WriteStartDate(ExportTable, ScheduleStartDate);   (* LS *)
                ExpressEndDate(ExportTable, ScheduleStartDate,0); (* LF *)
            END;

            WriteStartDate(ExportTable, ScheduleStartDate);   (* ESS *)
            ExpressEndDate(ExportTable, ScheduleStartDate,0); (* EFS *)

            WriteDuration(ExportTable, TRUE, 0);                (* SD *)
        ELSE
            WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
        END;
    END;

    EndRecord();

    (* Write project end milestone record *)
    StartRecord();
    OutputLString(A);
    WriteTaskID(Task, ExportTable, FinishProject, TRUE);  (* AN: count or WBS *)
    WriteDuration(ExportTable, TRUE, 0);           (* DU: Duration *)
    WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
    SetString(temp, "Finish ");
    ConcatLS(temp,ExportTable.FileName);
    WriteText(ExportTable,temp, TRUE);                (* DES *)
    WriteText(ExportTable,finish, TRUE);              (* TYPE *)
    WriteBlank(ExportTable, 4 );                      (* F1 .. F4 *)
    (* this is a milestone, so duration is zero.  For milestones,
       we express the start date and the end dates using the 
       start date procedure.  *)

    IF (ExportTable.ArtemisType <> A6000) THEN
        IF ((Scheduled IN ChartState) AND ScheduleComputedOk )  THEN
            ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* ES *)
            ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* EF *)

            IF (Levelling) THEN
                WriteBlank(ExportTable,2);
            ELSE
                ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* LS *)
                ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* LF *)
            END;
            
            ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* ESS *)
            ExpressEndDate(ExportTable, ScheduleEndDate,RDU); (* EFS *)

            WriteDuration(ExportTable, TRUE, 0);                (* SD *)
        ELSE
            WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
        END;
    END;
    EndRecord();
END WriteSummaryHammock;



    (*  Make the string suitable for exporting to Artemis by removing
        characters that it doesn't like.
    *)

PROCEDURE CleanseString ( VAR s             : ARRAY OF CHAR );

VAR
    i        : CARDINAL;
    AllStars : BOOLEAN;

    PROCEDURE Numeric ( C : CHAR ) : BOOLEAN;
    BEGIN
        RETURN (C >= "0") AND (C <= "9");
    END Numeric;

BEGIN

    (* For 6000 and 9000, remove the fractional part of any number. *)

    IF (ExportTable.ArtemisType = A6000) OR (ExportTable.ArtemisType = A9000) THEN
        i := 1;
        WHILE (i <= LengthOf(s)) DO
            IF (s[i] = ".") THEN
                Remove (s, i, 1);
                WHILE (i <= LengthOf(s)) AND Numeric(s[i]) DO
                    Remove (s, i, 1);
                END;
            ELSE
                INC (i);
            END;
        END;
    END;

    i := 1;
    WHILE (i <= LengthOf(s)) DO
        IF (NOT (s[i] IN GoodCharSet) OR (s[i] = "-") OR (s[i] = " ") ) THEN
            Remove (s, i, 1);
        ELSE;
            INC (i);
        END;
    END;


    (* check is the string is all asterisks and set it to null ifit is *)
    i := 1;
    AllStars := TRUE;
    WHILE (i <= LengthOf(s)) DO
        IF (s[i] <> "*") THEN
            AllStars := FALSE;
        END;
        INC (i);
    END;

    IF (AllStars) THEN
        SetLengthOf(s,0);
    END;

END CleanseString;




PROCEDURE FormatDate   (    Date        : ADate;
                            IsEnd       : BOOLEAN;
                            ExportTable : AnArtemisExportTable;
                        VAR s           : ARRAY OF CHAR );
VAR
    s2          : ARRAY [0..5] OF CHAR;
    Format      : ATimeFormat;
    Finicky     : BOOLEAN;          (* 6000 or 9000 format *)
    TimeInfo    : ATimeInfo;

BEGIN
    Finicky := (ExportTable.ArtemisType = A6000) OR
               (ExportTable.ArtemisType = A9000);

    IF (IsEnd) THEN
        AbsTimeAsEndDateStyle (Date, EndDateStyle, TimeInfo);
    ELSE
        TimeUtoT (Date, TimeInfo);
    END;
    IF (Finicky) THEN
        Format := DefaultDateFormat;
    ELSE
        Format := DefaultDateAndTimeFormat;
    END;
    TimeToString (TimeInfo, Format, s);

    IF (Finicky) THEN
        IF (TimeInfo.tiDay < 10) THEN
            SetString (s2, "0");
            TrimFront(s);
            Insert (s, s2, 1);
        END;
    END;
END FormatDate;



 
PROCEDURE OurFormatColumnValue(    ColumnId          : CARDINAL;
                                   Width             : CARDINAL;
                                   LineType          : AGanttLineType;
                                   MinDecimals       : CARDINAL;
                                   MaxDecimals       : CARDINAL;
                                   RightJustify      : BOOLEAN;
                                   ExportTable       : AnArtemisExportTable;
                               VAR ReturnValue       : AColumnDataRecord    );

CONST       (*  These constants define the data types used by Captions  *)
    IsStringValue           = 1;
    IsRealValue             = 2;
    IsIntValue              = 3;
    IsCardValue             = 4;
    IsBoolValue             = 5;
    IsEnumValue             = 6;
    IsBigStart              = 7;
    IsBigEnd                = 8;
    IsStartDate             = 9;
    IsEndDate               = 10;
    IsDuration              = 11;
    IsSlack                 = 12;
    IsCurrency              = 13;
    IsEffort                = 14;
    IsMilestoneEnd          = 15;
    IsDurationUnits         = 16;
    IsEffortUnits           = 17;

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    IsEnd                   : BOOLEAN;

BEGIN                       (* FormatValue *)

    IF (ExportTable.ArtemisType = A6000) OR (ExportTable.ArtemisType = A9000) THEN
        MinDecimals := 0;
        MaxDecimals := 0;
    END;

    WITH ReturnValue DO
        CASE DataType OF

        |   IsStartDate, IsMilestoneEnd, IsEndDate :
                IsEnd := (DataType = IsEndDate);
                FormatDate (DateValue, IsEnd, ExportTable, StringValue); (* TGS 27 Feb 90 - DateValue was "CardValue"?? *)
                IF (LengthOf(StringValue) >= Width) THEN
                    SetLengthOf(StringValue, Width);
                ELSE
                    Fill(s, " ", Width - LengthOf(StringValue));
                    ConcatLS(StringValue, s);
                END;

                IF (RightJustify) THEN
                    RJust(StringValue);
                END;

        ELSE
            FormatColumnValue (ColumnId, Width, LineType, MinDecimals, MaxDecimals,
                               RightJustify, ReturnValue);
        END;

    END;

END OurFormatColumnValue;



PROCEDURE WriteStartMilestone(ExportTable: AnArtemisExportTable;
                              Task       : ATaskPtr;
                              TaskNode   : ATreeNode
                             );

VAR
    temp            : ARRAY [0..255] OF CHAR;
    start,finish    : ARRAY [0..8] OF CHAR;
    CPMStart        : ADate;    

BEGIN
    SetString(start, "STA");
    SetString(finish, "FIN");

    StartRecord();
    OutputLString(A);

    WriteTaskID(Task, ExportTable, StartHammock, TRUE);  (* AN: count or WBS *)
    WriteDuration(ExportTable, TRUE, 0);         (* DU: Duration = 0 *)
    WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
    SetString(temp, "Start ");
    ConcatLS(temp,Task^.taskname);
    WriteText(ExportTable,temp, TRUE);                       (* DES: task name *)


    IF ( (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0)
         AND HasNoVisiblePredecessors( Task ) 
         AND (NOT ExportTable.CreateSummaryHammock) ) THEN
        WriteText(ExportTable,start, TRUE);
    ELSE
        WriteBlank(ExportTable, 1);
    END;

    WriteBlank(ExportTable, 4);                       (* F1 .. F4 *)
    WITH Task^.Plan.Dates DO
        IF (ExportTable.ArtemisType <> A6000) THEN
            IF ((Scheduled IN ChartState)AND ScheduleComputedOk ) THEN

                CPMStart := BigTimeToCalendarTime( Task^.SupposedToStart );

                WriteStartDate(ExportTable, CPMStart);      (* ES *)
                ExpressEndDate(ExportTable, CPMStart+Task^.duration,0);    (* EF *)
 
                (* These two should be blank if leveling is on *)
                IF (Levelling) THEN
                    WriteBlank(ExportTable,2);
                ELSE
                    WriteStartDate(ExportTable, LateFreeStart);   (* LS *)
                    ExpressEndDate(ExportTable, LateFreeStart,0); (* LF *)
                END;
 
                WriteStartDate(ExportTable, EarlyStart);      (* ESS *)
                ExpressEndDate(ExportTable, EarlyStart,0);    (* EFS *)
 
                IF ( EarlyStart >= CPMStart ) THEN
                    WriteDuration(ExportTable, TRUE, EarlyStart-CPMStart); (* SD *)
                ELSE
                    WriteDuration(ExportTable, FALSE, CPMStart-EarlyStart); (* SD *)
                END;
            ELSE
                WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
            END;
        END;
 
        (* Export information for the progess fields AS, PC and AF *)
        (* This milestone can only be started (and done) it the
           entire summary task is started or done *)
        IF ((Task^.StartStatus = DoneS) OR 
            (Task^.StartStatus = StartedS)) THEN
            (* AS - actual start *)
            WriteStartDate(ExportTable, EarlyStart);
 
            (* PC - percent complete *)
            WriteCardinal(ExportTable,100);
            (* AF - actual finish *)
            ExpressEndDate(ExportTable, EarlyStart,Task^.duration);
        ELSE (* not started, export blank progress fields *)
            WriteBlank(ExportTable, 3);     
            IF (ExportTable.ArtemisType = A6000) THEN
                WriteBlank(ExportTable, 1);
            END;
        END;
    END;
 
    EndRecord();

END WriteStartMilestone;



PROCEDURE WriteEndMilestone(ExportTable: AnArtemisExportTable;
                            Task       : ATaskPtr;
                            TaskNode   : ATreeNode
                           );

VAR
    temp                  : ARRAY [0..255] OF CHAR;
    start,finish          : ARRAY [0..8] OF CHAR;
    CPMStart        : ADate;    

BEGIN
    SetString(start, "STA");
    SetString(finish, "FIN");

    StartRecord();
    OutputLString(A);

    WriteTaskID(Task, ExportTable, FinishHammock, TRUE);  (* AN: count or WBS *)
    WriteDuration(ExportTable, TRUE, 0);         (* DU: Duration *)
    WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
    SetString(temp, "Finish ");
    ConcatLS(temp,Task^.taskname);
    WriteText(ExportTable,temp, TRUE);                       (* DES: task name *)

    IF ( (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0)
         AND HasNoVisibleSuccessors( Task ) 
         AND (NOT ExportTable.CreateSummaryHammock) ) THEN
        WriteText(ExportTable,finish, TRUE);
    ELSE
        WriteBlank(ExportTable, 1);
    END;

    WriteBlank(ExportTable, 4);                    (* F1 .. F4 *)
    WITH Task^.Plan.Dates DO

        IF (ExportTable.ArtemisType <> A6000) THEN
            IF ((Scheduled IN ChartState)AND ScheduleComputedOk ) THEN

                CPMStart := BigTimeToCalendarTime( Task^.SupposedToStart );
                ExpressEndDate(ExportTable, CPMStart + Task^.duration,
                                            Task^.duration);   (* ES *)
                ExpressEndDate(ExportTable, CPMStart + Task^.duration,
                                            Task^.duration);   (* ES *)

                (* These two should be blank if leveling is on *)
                IF (Levelling) THEN
                    WriteBlank(ExportTable,2);
                ELSE
                    ExpressEndDate(ExportTable, LateFreeEnd,Task^.duration);(* LS *)
                    ExpressEndDate(ExportTable, LateFreeEnd,Task^.duration);(* LF *)
                END;

                ExpressEndDate(ExportTable, EarlyEnd,Task^.duration);   (* ES *)
                ExpressEndDate(ExportTable, EarlyEnd,Task^.duration);   (* EF *)

                IF ( EarlyStart >= CPMStart ) THEN
                    WriteDuration(ExportTable, TRUE, EarlyStart-CPMStart); (* SD *)
                ELSE
                    WriteDuration(ExportTable, FALSE, CPMStart-EarlyStart); (* SD *)
                END;
            ELSE
                WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
            END;
        END;

        (* Export information for the progess fields AS, PC and AF *)
        (* This milestone can only be started (and done) if the
           entire summary task is done *)
        IF (Task^.StartStatus = DoneS) THEN 
            (* AS - actual start *)
            WriteStartDate(ExportTable, EarlyEnd);

            (* PC - percent complete *)
            WriteCardinal(ExportTable,100);
            (* AF - actual finish *)
            ExpressEndDate(ExportTable, EarlyEnd,Task^.duration);
        ELSE (* not started, export blank progress fields *)
            WriteBlank(ExportTable, 3);     
        END;
    END; 

    EndRecord();

END WriteEndMilestone;

PROCEDURE XportTasks( ExportTable: AnArtemisExportTable );
VAR
    TaskNode              : ATreeNode;
    Task,LinkTask         : ATaskPtr;
    edge                  : AnEdgePtr;
    Thermometer           : AThermometer;
    Counter               : CARDINAL;
    SequenceNumberCounter : CARDINAL;
    RDU                   : ADuration;
    CPMStart                : ADate;
    fn                    : ARRAY [0..99] OF CHAR;
    temp                  : ARRAY [0..255] OF CHAR;
    start,finish,
    hammock               : ARRAY [0..8] OF CHAR;
    ok                    : BOOLEAN;

    (* RSC  9/12/88:           Decode the user defined fields.  *)

    PROCEDURE WriteUserDef( FieldDef       : CARDINAL;
                            SequenceNumber : CARDINAL);
    VAR
        Value :        AColumnDataRecord;
        OutputString, 
        Filler, 
        SeqString:     ARRAY[0..8] OF CHAR;
    BEGIN
        IF (GetColumnValue(TaskNode, Task, FieldDef, Plan, Value)) THEN
            OurFormatColumnValue(FieldDef,
                                 HIGH(Value.StringValue),
                                 Plan,
                                 0,     (* Min Digits     *)
                                 6,     (* Max Digits     *)
                                 FALSE, (* Right justify? *)
                                 ExportTable,
                                 Value);

            WITH Value DO
                CleanseString (StringValue);

                (* And write the data to the CSV file *)

                TrimFront( StringValue );
                IF (FieldDef = 74) THEN  (* If field is "Indentation Level" *)
                    TrimRear(StringValue);
                    Fill(OutputString,"0",2 - LengthOf(ExportTable.ActivityPrefix));
                    ConcatLS(OutputString,ExportTable.ActivityPrefix);
                    TrimRear(StringValue);
                    CtoS(SequenceNumber,SeqString);
                    Fill(Filler,"0",4 - LengthOf(SeqString));
                    ConcatLS(OutputString,Filler);
                    ConcatLS(OutputString, SeqString);
                    Fill(Filler,"0",2 - LengthOf(StringValue));
                    ConcatLS(OutputString, Filler);
                    ConcatLS(OutputString, StringValue);
                    WriteText(ExportTable, OutputString, TRUE );
                ELSE
                    (* RSC 9/13/88:  Type 9000 & 6000 only allow 8 chars max. *)
                    IF (ExportTable.ArtemisType = A9000) OR
                       (ExportTable.ArtemisType = A6000) THEN
                       Procustes(StringValue,8);
                    END;
                    TrimRear ( StringValue );

                    IF ( LengthOf( StringValue ) > 0 ) THEN
                        WriteText(ExportTable, StringValue, TRUE );
                    ELSE
                        WriteBlank(ExportTable,1);
                    END;
                END;
            END; 
        ELSE
            WriteBlank(ExportTable, 1);
        END;                 
    END WriteUserDef;



BEGIN  (* XportTasks *)

    Copy( ExportTable.FileDir, fn );  (* RSC 9/12/88 *)
    ConcatLS(fn,ExportTable.FileName);
    ConcatS(fn, "A");                  (* RSC 9/12/88 *)
    ConcatS(fn, ".ART");
    IF (NOT OpenFile(fn,9999)) THEN
        RETURN;
    END;


    CASE ExportTable.ArtemisType OF
      PROJECT:
        WriteTLine("; Activity=P");
        WriteTLine("; Project Version: 1.5");
        WriteTLine("; fields an du wpn des type f1 f2 f3 f4 es ef ls lf ess efs sd as pc af tse tsl");
    | A2000, A7000:
        WriteTLine("; Activity=P");
        WriteTLine("; fields an du wpn des type f1 f2 f3 f4 es ef ls lf ess efs sd as pc af tse tsl");
    | A6000:
        WriteTLine("SWITCH PREC ON");
        WriteTLine("ENTER IN NETWORK");
        WriteTLine("FIELDS");
        WriteTLine("PE");
        WriteTLine("DU CAL AD"); 
        WriteTLine("TYP"); 
        WriteTLine("F1");
        WriteTLine("F2");
        WriteTLine("F3");
        WriteTLine("F4");
        WriteTLine("AS");
        WriteTLine("PC");
        WriteTLine("AF");   
        WriteTLine("TS");
        WriteTLine("TC");
        WriteTLine("END");
        WriteTLine("DATA");
    | A9000:
        WriteTLine("switch echo off");
        WriteTLine("enter in N@ZTL");
        WriteTLine("DATA");
        WriteTLine("END");
        WriteTLine("FIELD");
        WriteTLine(" AN DU CAL AD TYP F1 F2 F3 F4 ES EF LS LF ESS EFS SD AS PC AF TS TC");
        WriteTLine("END");
        WriteTLine("data");
    ELSE
      FatalError();
    END;

    SetString(start, "STA");
    SetString(finish, "FIN");
    SetString(hammock, "HAM");

    IF (ExportTable.CreateSummaryHammock) THEN
        SequenceNumberCounter := 3;               (* first real task is # 4 *)
        (* project summary hammock *)
        WriteSummaryHammock(ExportTable);
    ELSE
        SequenceNumberCounter := 0;            (* first task is # 1 *)
    END;

    (* RSC 9/12/88:   *)
    GetMessage (ModuleNumber+1, temp);  (* "Tasks output in Artemis format" *)
    ok := CreateThermometer( Thermometer, 0, 0, temp, CountOfTasks );
    Counter := 0;

    TaskNode := TaskTree^.Methods^.GetFirstVisible (TaskTree); (* RSC 9/12/88 *)

    (* Main loop to export tasks *)

    WHILE ( (TaskNode <> NIL) AND ContinueWriting ) DO

        INC(Counter);                              (* RSC 9/12/88 *)
        INC(SequenceNumberCounter);                (* RSC 9/12/88 *)
        UpdateThermometer( Thermometer, Counter ); (* RSC 9/12/88 *)

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

        Task^.count := SequenceNumberCounter; (* Current task seq number.*)

        IF ( 
             ( TaskNode^.Methods^.FirstVisibleChild(TaskNode) <> NIL) AND
             ( 
               (ExportTable.ArtemisType = A6000   ) OR 
               (ExportTable.ExportSummaryTasks = No) 
             )
           ) THEN

            (* If this is artemis 6000, then don't export hammocks.  They are 
               only exported as constraints.
               Also don't export hammocks if user has asked not to do it *)

            INCL(Task^.TempTaskFlags, TempTaskFlag1);

(*          Task^.TempTaskFlags := Task^.TaskFlags + ATaskFlagSet{TempTaskFlag1}; *)

        ELSE

            (* Write actual task record *)
            StartRecord();
            OutputLString(A);

            WriteTaskID(Task, ExportTable, Normal, TRUE);        (* AN: count or WBS *)
  
            WriteDuration(ExportTable, TRUE, Task^.duration);  (* DU: Duration *)

            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)

            WriteText(ExportTable,Task^.taskname, TRUE);             (* DES: task name *)

                                                         (* TYPE *)
            (* Note we are using TempTaskFlag1 to mark which tasks are hammocks
               for use in exporting dependencies *)

            EXCL(Task^.TempTaskFlags, TempTaskFlag1);
(*          Task^.TaskFlags := Task^.TaskFlags - ATaskFlagSet{TempTaskFlag1}; *)

            IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) <> NIL) ) THEN
                WriteText(ExportTable,hammock, TRUE);
                (* flag as hammock for use in writing dependencies *)

                INCL(Task^.TempTaskFlags, TempTaskFlag1);
(*              Task^.TaskFlags := Task^.TaskFlags + ATaskFlagSet{TempTaskFlag1}; *)

            ELSIF ( HasNoVisiblePredecessors( Task ) AND
                    (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0) AND
                    (NOT ExportTable.CreateSummaryHammock ) ) THEN
                WriteText(ExportTable,start, TRUE);
            ELSIF ( HasNoVisibleSuccessors( Task ) AND
                    (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0) AND
                    (NOT ExportTable.CreateSummaryHammock ) ) THEN
                WriteText(ExportTable,finish, TRUE);
            ELSE
                WriteBlank(ExportTable, 1);
            END;

            (* RSC 9/12/88:     *)
            WITH ExportTable DO                          (* F1 to F4 *)
                WriteUserDef( UserDef1, SequenceNumberCounter );
                WriteUserDef( UserDef2, SequenceNumberCounter );
                WriteUserDef( UserDef3, SequenceNumberCounter );
                WriteUserDef( UserDef4, SequenceNumberCounter );
            END;

            WITH Task^.Plan.Dates DO

                 (* Compute the to go duration for the task. *)
                IF (EarlyStart >= AsOfDate) THEN
                    RDU := Task^.duration;
                ELSIF (EarlyEnd <= AsOfDate) THEN
                    RDU := 0;
                ELSE
                    RDU := EarlyEnd - AsOfDate;
                END;

                IF (ExportTable.ArtemisType <> A6000) THEN

                    IF ((Scheduled IN ChartState) AND ScheduleComputedOk ) THEN

                        CPMStart := BigTimeToCalendarTime( Task^.SupposedToStart );
                        WriteStartDate(ExportTable, CPMStart);             (* ES *)
                        ExpressEndDate(ExportTable, CPMStart+Task^.duration,
                                                    Task^.duration);         (* EF *)

                        (* These two should be blank if leveling is on *)
                        IF (Levelling) THEN
                            WriteBlank(ExportTable,2);
                        ELSE
                            WriteStartDate(ExportTable, LateFreeStart);             (* LS *)
                            ExpressEndDate(ExportTable, LateFreeEnd,Task^.duration);(* LF *)
                        END;

                        WriteStartDate(ExportTable, EarlyStart);              (* ESS *)
                        ExpressEndDate(ExportTable, EarlyEnd,Task^.duration); (* EFS *)

                        IF ( EarlyStart >= CPMStart ) THEN
                            WriteDuration(ExportTable, TRUE, EarlyStart-CPMStart); (* SD *)
                        ELSE
                            WriteDuration(ExportTable, FALSE, CPMStart-EarlyStart); (* SD *)
                        END;
                    ELSE
                        WriteBlank(ExportTable,7);   (* all schedule fields are blank *)
                    END;
                END;

                (* Export information for the progess fields AS, PC and AF *)
                IF (Task^.StartStatus = DoneS) THEN
                    (* AS - actual start *)
                    WriteStartDate(ExportTable, EarlyStart);

                    (* PC - percent complete *)
                    WriteCardinal(ExportTable,100);

                    (* AF - actual finish *)
                    ExpressEndDate(ExportTable, EarlyEnd,Task^.duration);
                ELSIF (Task^.StartStatus = StartedS) THEN
                    (* AS - actual start *)
                    WriteStartDate(ExportTable, EarlyStart);

                    (* PC - percent complete *)
                    WriteCardinal(ExportTable,Task^.PercentComplete);

                    (* AF - actual finish *)
                    WriteBlank(ExportTable, 1);            

                ELSE (* not started, export blank progress fields *)
                    WriteBlank(ExportTable, 3);     
                END;

                (* If this is a fixed task, export its fixed dates *)
                IF (Task^.fixation = FixedDate) THEN
                    (* TSE - target start date *)
                    WriteStartDate(ExportTable, EarlyStart);  

                    (* TSL - target finish date *)
                    ExpressEndDate(ExportTable, EarlyEnd,Task^.duration);     
                ELSE
                    (* write blank fields to show it is not fixed *)
                    WriteBlank(ExportTable, 2);      
                END;
            END;
        END;

        EndRecord();

        (* If this is a summary task (has visible children), then export
           dummy start and end milestones with names based on the name of
           the summary task. 
        *)
        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) <> NIL) AND
            (ExportTable.ExportSummaryTasks = XMilestones) ) THEN

            SequenceNumberCounter := SequenceNumberCounter + 2; (* leave room for milestones *)

            WriteStartMilestone(ExportTable, Task, TaskNode);

            WriteEndMilestone(ExportTable, Task, TaskNode);
        END;

        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);    (* RSC 9/12/88 *)

        TaskNode := TaskNode^.Methods^.NextForDisplay(TaskNode); (* RSC 9/12/88 *)

        IF ( FatalWriteError() ) THEN
            ContinueWriting := FALSE;
        END;

    END; (* of WHILE loop to write activities *)

    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        (* nothing *)
    | A9000, A6000:
        WriteTLine("END");
        WriteTLine("END");
        WriteTLine("RETURN");
    ELSE
      FatalError();
    END;

    CloseFile();
    DiscardThermometer ( Thermometer ); (* RSC 9/12/88 *)



END XportTasks;



PROCEDURE ExportOneAssignment( VAR Assignment:AnAssignmentRecord;
                               Ptr           :ADDRESS ) : BOOLEAN;

VAR
    temp           : CARDINAL;
    ResourceName   : ARRAY [0..20] OF CHAR;
    pContext       : POINTER TO AnExportContext;
    IDString        : ARRAY [0..80] OF CHAR;

    PROCEDURE Write6000Prefix ( Label       : ARRAY OF CHAR;
                                SendEnd     : BOOLEAN       );
    VAR
        s           : ARRAY [0..40] OF CHAR;
        s2          : ARRAY [0..20] OF CHAR;
    BEGIN
        IF (ExportTable.ArtemisType = A6000) THEN
            IF (SendEnd) THEN
                EndRecord();
            END;
            StartRecord();
            Copy (IDString, s);
            ConcatS (s, Label);
            ConcatS (s, "(");
            CtoS (pContext^.Count, s2);
            ConcatLS (s, s2);
            ConcatS (s, ")=");
            OutputLString (s);
        END;
    END Write6000Prefix;


BEGIN
    pContext := Ptr;

    IF (Assignment.Resource^.Type <> AccountingOnly) THEN
        IF (ExportTable.ArtemisType <> A6000) THEN
            StartRecord();
            OutputLString(A);
        END;

        WITH pContext^ DO
            IF (ExportTable.ArtemisType <> A6000) THEN
                WriteTaskID(pTargetTask, ExportTable, Normal, FALSE); (* an:task number *)
            ELSE
                GetTaskID (pTargetTask, ExportTable, Normal, IDString);
                ConcatS (IDString, "-0 ");
            END;

            Write6000Prefix ("res", FALSE);

            Copy (Assignment.Resource^.Name, ResourceName);
            CleanseString (ResourceName);

            IF ( (ExportTable.ArtemisType = A6000) OR
                 (ExportTable.ArtemisType = A9000) ) THEN
                IF (LengthOf(ResourceName) > 8) THEN   (* CEG Jan 9/89 *)
                    SetLengthOf(ResourceName,8);
                END;
            END;

            WriteText(ExportTable, ResourceName, FALSE);  (* res:name of resource *)

            Write6000Prefix ("qty", TRUE);

            temp := ORD(Assignment.PercentageEach);

            WriteReal(ExportTable,FLOAT(Assignment.MaxRatePercent)/100.0,4);           (* qty:quantity assigned *)

            Write6000Prefix ("dur", TRUE);

            WriteDuration( ExportTable, TRUE, pTask^.duration );    (* dur *)

            Write6000Prefix ("der", TRUE);

            IF ( pTargetTask = pTask ) THEN
               (* We are writing this task's own resources so assignment
                  starts at the start of the task *)
                WriteDuration(ExportTable, TRUE, 0 );               (* leadr:*)
            ELSE
               (* We are writing this task's resources to a parent task at a
                  higher level in the outline so we must compute the lag
                  between the starts of the two tasks *)
                WriteDuration(ExportTable, TRUE,
                              pTask^.Plan.Dates.EarlyStart -
                              pTargetTask^.Plan.Dates.EarlyStart ); (* leadr *)
            END;

            IF (ExportTable.ArtemisType <> A6000) THEN
                IF (ExportTable.ArtemisType <> A9000) THEN
                    WriteText(ExportTable,Assignment.Resource^.LongName, TRUE);     (* desr:*)
                    WriteDuration(ExportTable, TRUE, pTask^.duration); (* rdur:*)
                END;

                WITH pTask^ DO
                    WriteStartDate(ExportTable, Plan.Dates.EarlyStart);             (* ESR *)
                    ExpressEndDate(ExportTable, Plan.Dates.EarlyEnd,duration);      (* EFR *)
                    WriteStartDate(ExportTable, Plan.Dates.LateFreeStart);          (* LSR *)
                    ExpressEndDate(ExportTable, Plan.Dates.LateFreeEnd,duration);   (* LFR *)
                END;
            END;
            INC (Count);
        END; (* WITH *)

        EndRecord();
    END;
    RETURN TRUE;
END ExportOneAssignment;


    (* XportAssignments -- Produce a list of all the resources used
                           by the task. *)

PROCEDURE XportAssignments( ExportTable: AnArtemisExportTable );
VAR 
    Counter               : CARDINAL;
    Thermometer           : AThermometer;
    TaskNode, VisibleParent  : ATreeNode;
    pTask                 : ATaskPtr;
    Context               : AnExportContext;
    fn                    : ARRAY [0..99] OF CHAR;
    temp                  : ARRAY [0..255] OF CHAR;
    ok                    : BOOLEAN;

BEGIN

    Copy( ExportTable.FileDir, fn );  (* RSC 9/12/88 *)
    ConcatLS(fn,ExportTable.FileName);
    ConcatS(fn,"R");                  (* RSC 9/12/88 *)
    ConcatS(fn,".ART");

    IF (NOT OpenFile(fn,9999)) THEN
        RETURN;
    END;
                               (* RSC 9/12/88:   *)
    GetMessage (ModuleNumber+2, temp);  (* "Assignments output in Artemis format" *)
    ok := CreateThermometer( Thermometer, 0, 0, temp, CountOfTasks );
    Counter := 0;

    CASE ExportTable.ArtemisType OF
      PROJECT:
        WriteTLine("; Resource=P");
        WriteTLine("; Project Version: 1.5");
        WriteTLine("; fields an res qty dur leadr desr rdur esr efr lsr lfr");
    | A2000, A7000:
        WriteTLine("; Resource=P");
        WriteTLine("; fields an res qty dur leadr desr rdur esr efr lsr lfr");
    | A6000:
        WriteTLine("CHANGE IN NETWORK");
    | A9000:
        WriteTLine("enter in R@ZTL");
        WriteTLine("FIELDS");
        WriteTLine(" AN RES QTY DUR DER ESR EFR LSR LFR");
        WriteTLine("end");
        WriteTLine(" DATA");
    ELSE
      FatalError();
    END;

    TaskNode := TaskTree^.Methods^.GetFirst(TaskTree); (* RSC 9/12/88 *)

    VisibleParent := TaskNode;

    (* We loop through ALL tasks here because we want to assign the resources 
       of invisible tasks to the first visible parent above them in the
       outline hierarchy. *)
    WHILE ( (TaskNode <> NIL) AND ContinueWriting ) DO
        INC(Counter);                              (* RSC 9/12/88 *)
        UpdateThermometer( Thermometer, Counter ); (* RSC 9/12/88 *)

        pTask := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode); 

        (* We want to assign resources to the most recent visible task.  We 
           remember what that task was with the variable VisibleParent.  We 
           change its value each time we encounter a new visible task *)
        IF ( pTask^.count2 = 1 ) THEN
            (* If the task is visible, then update its "visible parent" 
               to be itself *)
            VisibleParent := TaskNode;
        END;

        (* Store the treenode of this task's first visible parent for use in
           exporting dependencies. Note that for visible tasks, this is its
           own treenode. *)
        pTask^.WorkSpace := VisibleParent;

        (* Don't export resources attached to tasks that are filtered out, or
           to summary tasks if they have not been exported. 
        *)
        IF ( (Selected IN pTask^.FilterSet) AND
             ( TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL )
           ) THEN
            Context.pTask := pTask;
            Context.pExportTable := ADR(ExportTable);
            Context.Count := 1;

            IF ( VisibleParent = TaskNode ) THEN           
                (* Assign this task's resources to itself *)
                Context.pTargetTask := pTask;
                ForEachAssignment( pTask^.Plan.Assignments, 
                                   ExportOneAssignment, 
                                   ADR(Context) );
            ELSE                
                (* Assign this task's resources to its first visible parent.
                   First, lock its parent. *)
                Context.pTargetTask := 
                     VisibleParent^.Methods^.LockFlexStorDataObject(VisibleParent);
                ForEachAssignment( pTask^.Plan.Assignments, 
                                   ExportOneAssignment, 
                                   ADR(Context) );
                VisibleParent^.Methods^.UnlockUnchangedDataObject(VisibleParent);  
            END;
        END;

        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);  
        TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode); (* RSC 9/12/88 *)

        IF ( FatalWriteError() ) THEN
            ContinueWriting := FALSE;
        END;

    END;

    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        (* nothing *)
    | A9000, A6000:
        WriteTLine("END");
        WriteTLine("END");
        WriteTLine("RETURN");
    ELSE
      FatalError();
    END;

    CloseFile();
    DiscardThermometer ( Thermometer ); (* RSC 9/12/88 *)

END XportAssignments;
                            

(*

Suppose you have this task and dependency structure in Time Line:

  Task 1.0
  Task 2.0
    Task 2.1
    Task 2.2
  Task 3.0          

        Task 1.0 --->+--Task 2.0--+---->Task 3.0
                     |            |
                     |  Task 2.1  |
                     |            |
                     |  Task 2.2  |
                     +------------+
Rules:
  1) Connect "start" milestone to start of each direct child task.
  2) Connect "finish" milestone to end of each direct child task.
  3) Connect each preceding dependency of the parent task to the "start"
     milestone instead of to the parent task.
  4) Connect each succeding dependency of the parent task to the "finish"
     milestone instead of to the parent task.



It goes to:

Task 1.0 -->Start Task 2.0---->Task 2.0---->Finish Task 2.0--->Task 3.0
                            |            ^
                            |->Task 2.1--|
                            |            |
                            |->Task 2.2--|

Note that task 2.0 becomes a hammock, and "Start Task 2.0" and "Finish
Task 2.0" are milestones that have been created automatically to be the
focus of the dependencies of Time Line summary task 2.0.
                  
*)


PROCEDURE XportDependencies( ExportTable: AnArtemisExportTable );

VAR
    Counter                      : CARDINAL;
    edge                         : AnEdgePtr;
    TaskNode,ParentNode          : ATreeNode;
    pTask,pTailTask              : ATaskPtr;
    Thermometer                  : AThermometer;
    fn                           : ARRAY [0..99] OF CHAR;
    temp                         : ARRAY [0..255] OF CHAR;
    temp2                        : ARRAY [0..2] OF CHAR;
    HeadTaskAttachment,
    TailTaskAttachment           : BOOLEAN;
    DependencyString             : ARRAY [0..3] OF CHAR;
    ok                           : BOOLEAN;


    PROCEDURE HookToParentMilestones();

    VAR
        pParentTask   : ATaskPtr;

    BEGIN
        pParentTask := ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);

        (* hook to start milestone of its parent *)

        SetString(DependencyString, "FS");
        StartRecord();
        OutputLString(A);      
        WriteTaskID(pParentTask, ExportTable, StartHammock, FALSE);(*PAN*)

        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL) ) THEN
            WriteTaskID(pTask, ExportTable, Normal, FALSE);            (*SAN*)
        ELSE
            (* This is a hammock *)
            WriteTaskID(pTask, ExportTable, StartHammock, FALSE);      (*SAN*)
        END;

        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
        EndRecord();                                    

        (* hook to finish milestone of its parent *)

        SetString(DependencyString, "FS");
        StartRecord();
        OutputLString(A);      
        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL) ) THEN
            WriteTaskID(pTask, ExportTable, Normal, FALSE);             (*PAN*)
        ELSE
            WriteTaskID(pTask, ExportTable, FinishHammock, FALSE);
        END;

        WriteTaskID(pParentTask, ExportTable, FinishHammock, FALSE);(*SAN*) 
        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
        EndRecord();

        ParentNode^.Methods^.UnlockUnchangedDataObject(ParentNode);
    END HookToParentMilestones;


    PROCEDURE HookToParentHammock();

    VAR
        pParentTask   : ATaskPtr;

    BEGIN
        pParentTask := ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);

        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL) ) THEN

            (* hook to start of its parent hammock *)
            SetString(DependencyString, "SS");
            StartRecord();
            OutputLString(A);      
            WriteTaskID(pTask, ExportTable, Normal, FALSE);            (*PAN*)
            WriteTaskID(pParentTask, ExportTable, Normal, FALSE);      (*SAN*)
            WriteText(ExportTable,DependencyString, FALSE);
            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (*WPN: write what user entered *)
            EndRecord();                                    

            (* hook to finish of its parent hammock *)

            SetString(DependencyString, "FF");
            StartRecord();
            OutputLString(A);      
            WriteTaskID(pTask, ExportTable, Normal, FALSE);            (*PAN*)
            WriteTaskID(pParentTask, ExportTable, Normal, FALSE);      (*SAN*) 
            WriteText(ExportTable,DependencyString, FALSE);
            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (*WPN: write what user entered *)
            EndRecord();
        END;

        ParentNode^.Methods^.UnlockUnchangedDataObject(ParentNode);
    END HookToParentHammock;


    PROCEDURE HookMilestonesToHammock();

    BEGIN
        (* hook to start milestone of its parent *)

        SetString(DependencyString, "SS");
        StartRecord();
        OutputLString(A);      
        WriteTaskID(pTask, ExportTable, StartHammock, FALSE);           (*PAN*) 
        WriteTaskID(pTask, ExportTable, Normal, FALSE);                 (*SAN*)
        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
        EndRecord();                                    

        (* hook to finish milestone of its parent *)

        SetString(DependencyString, "FF");
        StartRecord();
        OutputLString(A);      
        WriteTaskID(pTask, ExportTable, FinishHammock, FALSE);      (*PAN*) 
        WriteTaskID(pTask, ExportTable, Normal, FALSE);             (*SAN*)
        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
        EndRecord();

    END HookMilestonesToHammock;
            

    PROCEDURE HookToProjectStartAndEnd();

    BEGIN
    

        SetString(DependencyString, "FS");
        StartRecord();
        OutputLString(A);      
        WriteTaskID(pTask, ExportTable, StartProject, FALSE);       (*PAN*)
             
        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL) ) THEN
           WriteTaskID(pTask, ExportTable, Normal, FALSE);             (*SAN*)
        ELSE
           WriteTaskID(pTask, ExportTable, StartHammock, FALSE);
        END;
        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
        EndRecord();

        (* Link to project end *)

        SetString(DependencyString, "FS");
        StartRecord();
        OutputLString(A);      

        IF ((TaskNode^.Methods^.FirstVisibleChild(TaskNode) = NIL) ) THEN
            WriteTaskID(pTask, ExportTable, Normal, FALSE);         (*PAN*)
        ELSE
            WriteTaskID(pTask, ExportTable, FinishHammock, FALSE);
        END;

        WriteTaskID(pTask, ExportTable, FinishProject, FALSE);      (*SAN*)

        WriteText(ExportTable,DependencyString, FALSE);
        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
        EndRecord();
    END HookToProjectStartAndEnd;


    PROCEDURE ExportADependency();

    VAR
        pTailParent,
        pParentTask    : ATaskPtr;
        ParentNode,
        TailParent     : ATreeNode;
        DurationLead,
        DurationLag    : REAL;
        Temp           : REAL;
                         
    BEGIN

        IF ( (Selected IN pTailTask^.FilterSet) AND
           (pTailTask^.WorkSpace <> pTask^.WorkSpace) ) THEN 
           (* The tail task is not filtered out and the two tasks do
              not have the same parent. *)
            StartRecord();
            OutputLString(A);      

            DurationLead := 0.0;
            DurationLag  := 0.0;

            ParentNode := pTask^.WorkSpace;

            (* Process first task's dependency *)

            IF ( TaskNode = ParentNode ) THEN
                (* This task receives its own dependencies *)

                (* If this task is hooked to a summary task, then be sure
                   to connect to the summary task's start or end milestone *)

                (* write PAN *)
                IF ( TempTaskFlag1 IN pTask^.TempTaskFlags ) THEN 
                    (* this is a hammock, so hook to its
                       finish milestone *)
                    WriteTaskID( pTask, ExportTable, FinishHammock, FALSE);
                ELSE
                    (* hook directly to the task *)
                    WriteTaskID( pTask, ExportTable, Normal, FALSE); 
                END;
            ELSE
                (* This task's dependencies are assigned to its first
                   visible parent *)

                pParentTask := ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);

                (* Although the parent is an outline task, it must be 
                closed here, because we are about to assign a dependency 
                of one  of its children to it *)
                WriteTaskID( pParentTask, ExportTable, Normal, FALSE);

                IF edge^.FromOffset.Start THEN     
                    (* it is an S? type dependency *)
                    DurationLead := FLOAT(pTask^.Plan.Dates.EarlyStart);
                    DurationLead := DurationLead - 
                                    FLOAT(pParentTask^.Plan.Dates.EarlyStart);
                ELSE
                    (* it is an F? type dependency *)
                    DurationLead := FLOAT(pTask^.Plan.Dates.EarlyEnd);
                    DurationLead := DurationLead - 
                                    FLOAT(pParentTask^.Plan.Dates.EarlyEnd);
                END;

                ParentNode^.Methods^.UnlockUnchangedDataObject(ParentNode);
            END;


            (* Process second task's dependency *)

            TailParent := pTailTask^.WorkSpace;

            IF ( edge^.tailtask = TailParent ) THEN
                (* The tail task receives its own dependencies *)

                (* write SAN *)
                IF ( TempTaskFlag1 IN pTailTask^.TempTaskFlags ) THEN 
                    (* The linked task is a hammock, so hook to its
                       start milestone *)
                    (* Don't write any dependency to a hammock if 
                       we did not create a milestone - Artemis ignores 
                       dependencies to or from hammocks. *)
                    WriteTaskID( pTailTask, ExportTable, StartHammock, FALSE); 
                ELSE
                    (* hook directly to the task *)
                    WriteTaskID( pTailTask, ExportTable, Normal, FALSE); 
                END;
            ELSE
                (* The tail task's dependencies are assigned to its first
                   visible parent *)

                pTailParent := TailParent^.Methods^.LockFlexStorDataObject(TailParent);

                (* Although the tail parent is an outline task, it must be 
                closed here because we are about to assign a dependency of 
                one of its children to it *)
                WriteTaskID( pTailParent, ExportTable, Normal, FALSE);

                IF edge^.ToOffset.Start THEN     
                    (* it is a ?S type dependency *)
                    DurationLag := FLOAT(pTailParent^.Plan.Dates.EarlyStart) - 
                                   FLOAT(pTailTask^.Plan.Dates.EarlyStart);
                ELSE
                    (* it is a ?F type dependency *)
                    DurationLag := FLOAT(pTailParent^.Plan.Dates.EarlyEnd) - 
                                   FLOAT(pTailTask^.Plan.Dates.EarlyEnd);
                END;

                TailParent^.Methods^.UnlockUnchangedDataObject(TailParent);
            END;

            IF edge^.FromOffset.Start THEN      (* TYPEC *)
                SetString(DependencyString, "S");
            ELSE
                SetString(DependencyString, "F");
            END;

            IF edge^.ToOffset.Start THEN
                ConcatS(DependencyString,"S");
            ELSE
                ConcatS(DependencyString,"F");
            END;

            WriteText(ExportTable,DependencyString, FALSE);

            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)

            (* Note - Artemis will not accept a negative value for the 
               duration of a constraint.  However, it will accept a negative LEAD on
               a constraint.  Therefore partial dependencies must ber represented
               with the LEAD field, and the DUC field is set to zero. *)

            (* Also, the lead created by rolling a task into its parent
               for export must be combined into LEADC *)

            IF (edge^.FromOffset.Plus) THEN
               DurationLead := DurationLead + FLOAT(edge^.FromOffset.Dur);
            ELSE
               DurationLead := DurationLead - FLOAT(edge^.FromOffset.Dur);
            END;

            (* Artemis 9000 does not have a duration lag field, so we combine
               it with duration lead to give the field CDE - constraint delay  *)
            IF ( (ExportTable.ArtemisType = A9000) OR
                 (ExportTable.ArtemisType = A6000) ) THEN
                DurationLead := DurationLead + DurationLag;

                IF (DurationLead >= 0.0) THEN                       (* LEADC *)
                    WriteDuration(ExportTable, TRUE, TRUNC(DurationLead) );  
                ELSE
                    WriteDuration(ExportTable, FALSE, TRUNC(ABS(DurationLead)) );  
                END;
            ELSE
                IF (DurationLead >= 0.0) THEN                       (* LEADC *)
                    WriteDuration(ExportTable, TRUE, TRUNC(DurationLead) );  
                ELSE
                    WriteDuration(ExportTable, FALSE, TRUNC(ABS(DurationLead)) );  
                END;

                (* LAGC will only be non-zero if this dependency was to the
                   child of a closed summary task. *)
        
                IF (DurationLag >= 0.0) THEN                         (* LAGC *)
                    WriteDuration(ExportTable, TRUE, TRUNC(DurationLag) );  
                ELSE
                    WriteDuration(ExportTable, FALSE, TRUNC(ABS(DurationLag)) );  
                END;
            END;

            EndRecord();
        END;

    END ExportADependency;


BEGIN (* XportDependencies *)        

    Copy( ExportTable.FileDir, fn );  (* RSC 9/12/88 *)
    ConcatLS(fn,ExportTable.FileName);
    ConcatS(fn,"L");                  (* RSC 9/12/88 *)
    ConcatS(fn,".ART");
    
    IF (NOT OpenFile(fn,9999)) THEN
        RETURN;
    END;

    (* RSC 9/12/88:   *)
    GetMessage (ModuleNumber+3, temp);  (* "Dependencies output in Artemis format" *)
    ok := CreateThermometer( Thermometer, 0, 0, temp, CountOfTasks );
    Counter := 0;

    CASE ExportTable.ArtemisType OF
      PROJECT:
        WriteTLine("; Logic");
        WriteTLine("; Project Version: 1.5");
        WriteTLine("; fields pan san typec wpnc leadc lagc");
    | A2000, A7000:
        WriteTLine("; Logic");
        WriteTLine("; fields pan san typec wpnc leadc lagc");
    | A6000:
        WriteTLine("ENTER IN NETWORK");
        WriteTLine("FIELDS"); 
        WriteTLine("PE SE TYP CAL DE DU");
        WriteTLine("END");
        WriteTLine("DATA");
    | A9000:
        WriteTLine("enter in C@ZTL");
        WriteTLine("fields");
        WriteTLine(" pan san contyp concal cde");
        WriteTLine("end");
        WriteTLine("DATA");
    ELSE
      FatalError();
    END;


    IF ( (ExportTable.CreateSummaryHammock) ) THEN
        IF ( ExportTable.ArtemisType = A6000 ) THEN
            SetString(DependencyString, "HAM");
            StartRecord();
            OutputLString(A);      
            WriteTaskID(pTask, ExportTable, StartProject, FALSE);       (*PAN*)
            WriteTaskID(pTask, ExportTable, FinishProject, FALSE);
            WriteText(ExportTable,DependencyString, FALSE);
            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
            EndRecord();
        ELSE
            SetString(DependencyString, "SS");
            StartRecord();
            OutputLString(A);      
            WriteTaskID(pTask, ExportTable, StartProject, FALSE);       (*PAN*)
            WriteTaskID(pTask, ExportTable, ProjectHammock, FALSE);
            WriteText(ExportTable,DependencyString, FALSE);
            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
            EndRecord();

            (* Link to project end *)

            SetString(DependencyString, "FF");
            StartRecord();
            OutputLString(A);      

            WriteTaskID(pTask, ExportTable, FinishProject, FALSE);      (*PAN*)
            WriteTaskID(pTask, ExportTable, ProjectHammock, FALSE);

            WriteText(ExportTable,DependencyString, FALSE);
            WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
            EndRecord();
        END;
    END;



    (* RSC 9/13/88: Make sure that the tailtask for each edge record is
                    visible by checking the count2 field that was set up
                    by FlagTasksAsInvisible() and the tasks export procedure.
                    Also, we do not need to look at the headtask, because,
                    when looking at Task's desctasks, headtask == Task.
    *)

    TaskNode := TaskTree^.Methods^.GetFirst(TaskTree); (* RSC 9/12/88 *)

    WHILE ( (TaskNode <> NIL) AND ContinueWriting ) DO
        INC(Counter);                            
        UpdateThermometer( Thermometer, Counter ); 

        pTask := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode); 

        (* Since we are looping through all tasks here, we must skip tasks 
           that are filtered out.  However, tasks that are hidden because
           they are in a closed part of the outline will have their
           dependencies reconnected to their first visible parent *)
        IF ( Selected IN pTask^.FilterSet ) THEN


            ParentNode := TaskNode^.Methods^.Parent(TaskNode);

            (* If this task has a parent, then hook it to its parent hammock's
               start and finish milestones *)
            IF ( (ParentNode <> NIL) AND (pTask^.count2 <> 0) ) THEN
               IF (ExportTable.ExportSummaryTasks = XMilestones) THEN
                  HookToParentMilestones();
               ELSIF (ExportTable.ExportSummaryTasks = Hammocks) THEN
                  HookToParentHammock();
               END;
            END;


            IF ( ( TempTaskFlag1 IN pTask^.TempTaskFlags ) AND 
                  (pTask^.count2 <> 0) ) THEN (* It is a hammock and visible *)
               IF (    (  ExportTable.ExportSummaryTasks = No ) 
                    OR (  ExportTable.ExportSummaryTasks = Hammocks )
                  ) THEN

                  (* We are not exporting summary tasks and/or their milestones *)
                  IF (   ( pTask^.desctasks <> NIL ) 
                      OR
                         ( pTask^.antetasks <> NIL )
                     ) THEN (* It has a dependency to or from it *)
                  
(*                     SetString(temp,"Warning: Ignoring dependencies on summary task: ");
*)
                     GetMessage (ModuleNumber+5, temp);  (* "Warning: Ignoring dependencies on summary task: " *)
                     SetString(temp2, " ");
                     ConcatLS(temp,temp2);
                     ConcatLS(temp,pTask^.taskname);
                     Error(temp);
                  END;
               END;
            END;

            (* If this is a hammock (open summary task), hook it to its own
               start and end milestones. *)

            IF ( ExportTable.ExportSummaryTasks = XMilestones ) THEN 
                IF ( ( TempTaskFlag1 IN pTask^.TempTaskFlags ) AND 
                       (pTask^.count2 <> 0) ) THEN (* It is a hammock and visible *)
                    IF ( ExportTable.ArtemisType = A6000 ) THEN
                        (* On the 6000 we just write a hammock record *)
                        StartRecord();
                        OutputLString(A);      
                        WriteTaskID( pTask, ExportTable, StartHammock, FALSE);
                        WriteTaskID( pTask, ExportTable, FinishHammock, FALSE);
                        SetString(DependencyString,"HAM");
                        WriteText(ExportTable,DependencyString, FALSE);
                        WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);  (* WPN: write what user entered *)
                        EndRecord();
                    ELSE
                        HookMilestonesToHammock();
                    END;
                END;
            END;

            (* If we want to summarize the entire project with a summary hammock
              then we must connect any tasks at the top level to the project start
              start and finish milestones.  Note that this only applies to
              top level tasks because all others must be at least connected
              to their parents. *)
            IF ( (ExportTable.CreateSummaryHammock) 
            AND  (TaskNode^.Methods^.IndentationLevel(TaskNode) = 0)
            AND  (pTask^.count2 <> 0) ) THEN
                 HookToProjectStartAndEnd();
            END;

            (* Now write any real dependencies by looping through the linked
                list of successors for this task *)
            edge := pTask^.desctasks;

            WHILE (edge <> NIL) DO
               pTailTask := edge^.tailtask^.Methods^.LockFlexStorDataObject(edge^.tailtask);
               IF ( ( (
                        ( NOT ( TempTaskFlag1 IN pTailTask^.TempTaskFlags ) )
                      AND
                        ( NOT ( TempTaskFlag1 IN pTask^.TempTaskFlags ) )
                      )
                    )
               OR ( ExportTable.ExportSummaryTasks = XMilestones )
               ) THEN
                  ExportADependency(); 
               END;
               edge^.tailtask^.Methods^.UnlockUnchangedDataObject(edge^.tailtask);
               edge := edge^.headlink;
            END;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
        TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode); (* RSC 9/12/88 *)
        IF ( FatalWriteError() ) THEN
            ContinueWriting := FALSE;
        END;
    END;

    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        (* nothing *)
    | A9000, A6000:
        WriteTLine("END");
        WriteTLine("END");
        WriteTLine("RETURN");
    ELSE
      FatalError();
    END;

    CloseFile();
    DiscardThermometer ( Thermometer ); (* RSC 9/12/88 *)

END XportDependencies;
  

    (* XportResources -- Produce a list of resources used by this project *)

PROCEDURE XportResources( ExportTable: AnArtemisExportTable );
VAR
    Counter               : CARDINAL;
    Thermometer           : AThermometer;
    fn                    : ARRAY [0..99] OF CHAR;
    temp                  : ARRAY [0..255] OF CHAR;
    Context               : CARDINAL;
    ResourceNode          : ATreeNode;
    pResource             : AResourcePointer;
    ok                    : BOOLEAN;
    AvailabilityRate      : AnAvailabilityRate;
    BigTimeDummy          : ABigTime;

BEGIN
    Copy( ExportTable.FileDir, fn );  (* RSC 9/12/88 *)
    ConcatLS(fn,ExportTable.FileName);
    ConcatS(fn,"P");                  (* RSC 9/12/88 *)
    ConcatS(fn,".ART");

    IF (NOT OpenFile(fn,9999)) THEN
        RETURN;
    END;

    GetMessage (ModuleNumber+4, temp);  (* "Resource Pool output in Artemis format" *)
    ok := CreateThermometer( Thermometer, 0, 0, temp, CountOfTasks );
    Counter := 0;

    CASE ExportTable.ArtemisType OF
      PROJECT:
        WriteTLine("; Pool=P");
        WriteTLine("; Project Version: 1.5");
        WriteTLine("; fields res qtya");
    | A2000, A7000:
        WriteTLine("; Pool=P");
        WriteTLine("; fields res qtya");
    | A6000, A9000:
        WriteTLine("RESOURCES");
    ELSE
      FatalError();
    END;

    ResourceNode := ResourceTree^.Methods^.GetFirst(ResourceTree);

        IF ( FatalWriteError() ) THEN
            ContinueWriting := FALSE;
        END;

    WHILE ( (ResourceNode <> NIL) AND ContinueWriting ) DO

        pResource := ResourceNode^.Methods^.GetDataObject(ResourceNode);

        INC(Counter);                            
        UpdateThermometer( Thermometer, Counter ); 

        (* ******Do processing on resource data****** *)
        (* Only export resources, not costs *)
        IF (pResource^.Type <> AccountingOnly ) THEN
            StartRecord();
            IF (ExportTable.ArtemisType <> A6000) AND
               (ExportTable.ArtemisType <> A9000) THEN
                OutputLString(A);
            END;

            Copy(pResource^.Name, temp);
            CleanseString (temp);
            IF ( (ExportTable.ArtemisType = A6000) OR
                 (ExportTable.ArtemisType = A9000) ) THEN
                IF (LengthOf(temp) > 8) THEN   (* CEG Jan 9/89 *)
                    SetLengthOf(temp,8);
                END;
            END;

            IF (ExportTable.ArtemisType = A9000) THEN
                EncloseWith (temp, "'");
            END;
            IF (ExportTable.ArtemisType = A6000) OR
               (ExportTable.ArtemisType = A9000) THEN
                WriteText(ExportTable,temp, FALSE);
            ELSE
                WriteText(ExportTable,temp, TRUE);
            END;

            (* We export the overtime amounts since this is the true
               upper limit for leveling *)

            IF (pResource^.Availability <> ADateList(NIL)) AND
               GetDateListEntry(pResource^.Availability, 1,
                                BigTimeDummy, BigTimeDummy,
                                AvailabilityRate) THEN
                WITH AvailabilityRate DO
                    WriteReal(ExportTable, FLOAT(Amount*Percent)/100.0, 2);
                END;
            ELSE
                WriteReal(ExportTable,
                          FLOAT(DefaultAvailabilityPercent
                              * DefaultAvailabilityAmount)/100.0, 2);
            END;
           
            (* UpperLimit field no longer valid in TL5
            WriteReal(ExportTable,pResource^.UpperLimit/100.0,2);
            *)
            EndRecord();
        END;

        ResourceNode := ResourceNode^.Methods^.NextPreOrder(ResourceNode);

        IF ( FatalWriteError() ) THEN
            ContinueWriting := FALSE;
        END;
    END;

    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        (* nothing *)
    | A9000,A6000:
        WriteTLine("END");
        WriteTLine("END");
        WriteTLine("RETURN");
    ELSE
      FatalError();
    END;

    CloseFile();

END XportResources;

    (* XportCalendar -- Create a calendar dataset for this project *)

PROCEDURE XportCalendar( ExportTable: AnArtemisExportTable );
VAR
    Counter               : CARDINAL;
    Thermometer           : AThermometer;
    fn                    : ARRAY [0..99] OF CHAR;
    temp                  : ARRAY [0..255] OF CHAR;
    temp2                 : ARRAY [0..100] OF CHAR;

    Rest,Holiday          : ARRAY [0..8] OF CHAR;

    DayName               : ARRAY [0..9] OF CHAR;

    Day,
    Month,
    Hour,
    Minute,
    i                     : CARDINAL;
    TimeInfo            : ATimeInfo;
    RestDay               : ARRAY[Sun..Sat] OF BOOLEAN;
    ok                    : BOOLEAN;

    StartYear,
    EndYear,
    DOW                   : CARDINAL;



    PROCEDURE WriteRestDays;

    BEGIN

        FOR Day := Sun TO Sat DO
            RestDay[Day] := TRUE;
        END;

        FOR i := 1 TO (EndYear - StartYear + 1) DO
            Counter := Counter + 1;
            UpdateThermometer( Thermometer, Counter ); 
            FOR Month := Jan TO Dec DO
                WITH TimeTable.YearTable[StartYear - TimeTable.FirstYear + i,
                                         Month] DO
                    FOR Day := 1 TO DaysInMonth(StartYear+i-1,Month) DO
                        IF (NOT (Day IN YearMap)) THEN
                            DOW := DayOfWeek(StartYear+i-1,Month,Day);
                            RestDay[DOW] := FALSE;
                        END;
                    END;
                END;    
            END;
        END;

        IF ((ExportTable.ArtemisType = A6000) OR 
            (ExportTable.ArtemisType = A9000) ) THEN
            SetString(temp,"REST ON CAL ");
            CtoS(ExportTable.WorkpatternNumber,temp2);
            ConcatLS(temp,temp2);
            OutputLString(temp);
            EndRecord();
            FOR Day := Sun TO Sat DO
                IF ( RestDay[Day] ) THEN
                    StartRecord();               
                    (* DAY_NAME    *)
                    CASE Day OF
                      Sun:  SetString(DayName,"SUN");
                    | 1  :  SetString(DayName,"MON");
                    | 2  :  SetString(DayName,"TUE");
                    | 3  :  SetString(DayName,"WED");
                    | 4  :  SetString(DayName,"THU");
                    | 5  :  SetString(DayName,"FRI");
                    | Sat:  SetString(DayName,"SAT");
                    ELSE
                    END;
                    WriteText(ExportTable, DayName, FALSE); 
                    EndRecord();
                END;
            END;

            WITH ExportTable DO
                IF ((CalendarType = Period) AND
                    (PeriodType = PerDay)   AND 
                    (PeriodSize = 24) )     THEN
               (* Don't write an END because we can write some rest hours *)
                ELSE
                    WriteTLine("END");
                END;
            END;

        ELSE  (* We are exporting to A2000, A7000, or Project *)
            FOR Day := Sun TO Sat DO
                IF ( RestDay[Day] ) THEN

                    StartRecord();               
                    OutputLString(A);      

                    (* WORK_PAT    *)
                    WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
  
                    (* TYPE        *)
                    WriteText(ExportTable,Rest, FALSE); 

                    (* FROM_DATE   *)
                    WritePureDate(ExportTable, StartYear, 0, 1);
  
                    (* UNTIL_DATE  *)
                    WritePureDate(ExportTable, EndYear, 11,31);

                    (* DAY_NAME    *)
                    CASE Day OF
                      Sun:  SetString(DayName,"SUN");
                    | 1  :  SetString(DayName,"MON");
                    | 2  :  SetString(DayName,"TUE");
                    | 3  :  SetString(DayName,"WED");
                    | 4  :  SetString(DayName,"THU");
                    | 5  :  SetString(DayName,"FRI");
                    | Sat:  SetString(DayName,"SAT");
                    ELSE
                    END;
                    WriteText(ExportTable,DayName, FALSE); 

                    (* FROM_TIME   *)
                    WriteBlank(ExportTable,1);
               
                    (* UNTIL_TIME  *)
                    WriteBlank(ExportTable,1);
       
                    EndRecord();
                END;
            END;
        END;

    END WriteRestDays;


    PROCEDURE WriteHolidays;

    BEGIN

        IF ((ExportTable.ArtemisType = A6000)   OR 
            (ExportTable.ArtemisType = A9000) ) THEN
            SetString(temp,"HOLIDAY ON CAL ");
            CtoS(ExportTable.WorkpatternNumber,temp2);
            ConcatLS(temp,temp2);
            OutputLString(temp);
            EndRecord();
        END;

        FOR i := 1 TO (EndYear - StartYear + 1) DO 
            Counter := Counter + 1;
            UpdateThermometer( Thermometer, Counter ); 
            FOR Month := Jan TO Dec DO
                WITH TimeTable.YearTable[StartYear - TimeTable.FirstYear + i,
                                         Month] DO
                    FOR Day := 1 TO DaysInMonth(StartYear+i-1,Month) DO
                        IF ((Day IN YearMap) AND
                            NOT (RestDay[DayOfWeek(StartYear+i-1,Month,Day)] )
                           ) THEN

                            IF ((ExportTable.ArtemisType = A6000)   OR 
                                (ExportTable.ArtemisType = A9000) ) THEN
                                StartRecord();               

                                (* FROM_DATE   *)
                                WritePureDate(ExportTable, StartYear+i-1-1900, Month, Day);

                                EndRecord();
                            ELSE
                                StartRecord();               
                                OutputLString(A);      

                                (* WORK_PAT    *)
                                WriteCardinal(ExportTable,ExportTable.WorkpatternNumber);

                                (* TYPE        *)
                                WriteText(ExportTable,Holiday, FALSE); 

                                (* FROM_DATE   *)
                                WritePureDate(ExportTable, StartYear+i-1, Month, Day);

                                (* UNTIL_DATE  *)
                                WritePureDate(ExportTable, StartYear+i-1, Month, Day);

                                (* DAY_NAME    *)
                                WriteBlank(ExportTable,1);

                                (* FROM_TIME   *)
                                WriteBlank(ExportTable,1);
            
                                (* UNTIL_TIME  *)
                                WriteBlank(ExportTable,1);
    
                                EndRecord();
                            END;
                        END;
                    END;
                END; 
            END;
        END;

        IF ((ExportTable.ArtemisType = A6000)   OR 
            (ExportTable.ArtemisType = A9000) ) THEN
            WriteTLine("END");
        END;

    END WriteHolidays;


    PROCEDURE WriteRestHours;

    VAR
        StartHour, EndHour : CARDINAL;

    BEGIN

        FOR Day := Sun TO Sat DO
            IF ( NOT RestDay[Day] ) THEN
                StartHour := 0;
                WHILE  (StartHour <= 23) DO 
                    WITH TimeTable.WeekTable[Day] DO
                        (* Scan for a rest hour *)
                        WHILE ((StartHour <= 23) AND 
                               NOT (StartHour IN WeekMap)) DO
                            INC(StartHour);
                        END;

                        EndHour := StartHour;

                        (* Scan for a work hour *)
                        WHILE ((EndHour <= 23) AND (EndHour IN WeekMap)) DO
                            INC(EndHour);
                        END;

                        IF (StartHour <= 23) THEN
                            StartRecord();        

                            IF (ExportTable.CalendarType = Period) THEN

                                (* DAY_NAME    *)
                                CASE Day OF
                                  Sun:  SetString(DayName,"SUN FROM ");
                                | 1  :  SetString(DayName,"MON FROM ");
                                | 2  :  SetString(DayName,"TUE FROM ");
                                | 3  :  SetString(DayName,"WED FROM ");
                                | 4  :  SetString(DayName,"THU FROM ");
                                | 5  :  SetString(DayName,"FRI FROM ");
                                | Sat:  SetString(DayName,"SAT FROM ");
                                END;
                                OutputLString(DayName); 

                                (* FROM_TIME   *)
                                CtoS(StartHour+1,temp);
                                OutputLString(temp);
                        
                                SetString(temp2," UNTIL ");
                                OutputLString(temp2);

                                (* UNTIL_TIME  *)
                                CtoS(EndHour,temp);
                                OutputLString(temp);
                
                            ELSE
                                OutputLString(A);      

                                (* WORK_PAT    *)
                                WriteCardinal(ExportTable,
                                              ExportTable.WorkpatternNumber);(* WPN: write what user entered *)
         
                                (* TYPE        *)
                                WriteText(ExportTable,Rest, FALSE); 

                                (* FROM_DATE   *)
                                WritePureDate(ExportTable, StartYear, 0, 1);
    
                                (* UNTIL_DATE  *)
                                WritePureDate(ExportTable, EndYear, 11,31);

                                (* DAY_NAME    *)
                                CASE Day OF
                                  Sun:  SetString(DayName,"SUN");
                                | 1  :  SetString(DayName,"MON");
                                | 2  :  SetString(DayName,"TUE");
                                | 3  :  SetString(DayName,"WED");
                                | 4  :  SetString(DayName,"THU");
                                | 5  :  SetString(DayName,"FRI");
                                | Sat:  SetString(DayName,"SAT");
                                END;
                                WriteText(ExportTable,DayName, FALSE); 

                                SetString(temp2,",");
                                OutputLString(temp2);

                                (* FROM_TIME   *)
                                SetString(temp2,":00,");
                                CtoS(StartHour+1,temp);
                                ConcatLS(temp,temp2);
                                OutputLString(temp);
                        
                                (* UNTIL_TIME  *)
                                SetString(temp2,":00");
                                CtoS(EndHour,temp);
                                ConcatLS(temp,temp2);
                                OutputLString(temp);
                
                            END; (* IF *)

                            EndRecord();

                        END; (* IF *)

                        StartHour := EndHour;
                    END;  (* WITH *)
                END;  (* WHILE *)
            END; (* IF *)
        END;   (* FOR *)

        IF ((ExportTable.ArtemisType = A6000)   OR 
            (ExportTable.ArtemisType = A9000) ) THEN

            WriteTLine("END");
        END;

    END WriteRestHours;



BEGIN
            
    WITH ExportTable DO

        IF (CalendarType = Period ) THEN
            (* Can't export period based calendars to Artemis 2000, 7000 or Project *)
            IF (( ArtemisType = PROJECT ) OR
                ( ArtemisType = A2000 )   OR
                ( ArtemisType = A7000 ) ) THEN

(*
             SetString(temp,"WARNING: A calendar file will not be written.  Period-based ");
             SetString(temp2,"calendars cannot be exported to Artemis 2000, 7000 or Project.");
             ConcatLS(temp,temp2);
*)

                GetMessage(ModuleNumber+8,Err);

                Error(Err);

                RETURN;
            END;

            (* Can't export period based calendars unless period size is 1 or 24 per day. *)
            IF ((PeriodType = PerDay) AND 
                NOT ((PeriodSize = 24) OR (PeriodSize = 1))) OR
               ((PeriodType = Days) AND NOT (PeriodSize = 1)) THEN

(*
             SetString(temp,"WARNING: A calendar file will not be written. Period-based ");
             SetString(temp2,"calendar is not of type 1 per day, 24 per day or 1 day.");
             ConcatLS(temp,temp2);
             Error(temp);
*)

                GetMessage(ModuleNumber+9,Err);

                Error(Err);
                RETURN;
            END;

        END; (* IF *)

    END;  (* WITH *)


    Copy( ExportTable.FileDir, fn );  
    ConcatLS(fn,ExportTable.FileName);
    ConcatS(fn,"C");                  
    ConcatS(fn,".ART");


    SetString(Rest, "REST");
    SetString(Holiday, "HOLIDAY");

    IF (NOT OpenFile(fn,9999)) THEN
        RETURN;
    END;

    (* Determine length of calendar information to export. Onlu years are
       significant. *)

    TimeUtoT (ScheduleStartDate, TimeInfo);
    StartYear := TimeInfo.tiYear;
    TimeUtoT (ScheduleEndDate, TimeInfo);
    EndYear := TimeInfo.tiYear;

    (* Adjust end year so that we output calendar information about twice
       the length of the project *)
    EndYear := EndYear + (EndYear - StartYear) * 2;

    (* But not past end of calendar *)
    IF ( EndYear > (TimeTable.FirstYear + YearsOnFile - 1) ) THEN
        EndYear := TimeTable.FirstYear + YearsOnFile - 1;
    END;

    GetMessage (ModuleNumber+7, temp);  (* "Calendar output in Artemis format" *)

(*    SetString(temp,"Calendar output in Artemis format"); *)
    Counter := 0;
    ok := CreateThermometer( Thermometer, 0, 0, temp, 2*(EndYear-StartYear) );


    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        SetString(temp,"; Calendar - base ");
        CtoS(StartYear,temp2);
        ConcatLS(temp,temp2);
        SetString(temp2,"*span ");
        ConcatLS(temp,temp2);
        CtoS(EndYear-StartYear+1,temp2);
        ConcatLS(temp,temp2);
        SetString(temp2,"*units ");
        ConcatLS(temp,temp2);
        IF (ExportTable.CalendarType = DateDays) THEN
            SetString(temp2,"1 DAYS");
        ELSIF (ExportTable.CalendarType = DateHours) THEN
            SetString(temp2,"1 HOURS");
        ELSE
            (* ERROR - should never happen *)
            FatalError();
        END;
        ConcatLS(temp,temp2);

        StartRecord();
        OutputLString(temp);
        EndRecord();
        WriteTLine("; Project version: 1.5");
        WriteTLine("; fields $WNUM $TYPE $RFRD $RTOD $DOW $RFRT $RTOT");
    | A6000, A9000:
        WriteTLine("CALENDAR");
        SetString(temp,"UNITS ");
        CtoS(ExportTable.PeriodSize,temp2);
        ConcatLS(temp,temp2);
        IF (ExportTable.PeriodType = Days) THEN
            SetString(temp2," DAYS");
        ELSE
            SetString(temp2," PER DAY");
        END;
        ConcatLS(temp,temp2);
        OutputLString(temp);
        EndRecord();
    ELSE
        FatalError();
    END;

    WriteRestDays;

    WITH ExportTable DO
        IF ( (CalendarType = DateHours) OR 
            ((CalendarType = Period) AND (PeriodSize = 24)) 
           ) THEN
            WriteRestHours;
        END;
    END;

    WriteHolidays;

    CASE ExportTable.ArtemisType OF
      PROJECT, A2000, A7000:
        (* nothing *)
    | A9000,A6000:
        WriteTLine("END");
        WriteTLine("RETURN");
    ELSE
        FatalError();
    END;

    CloseFile();

END XportCalendar;



PROCEDURE GetHeldContext( VAR ExportTable : AnArtemisExportTable );
VAR
    LExportTableP      : POINTER TO AnArtemisExportTable;
    Size,
    Class              : CARDINAL;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
BEGIN
    Class := 3;
    SetString( Name, "TLXAFORM" );
    IF (LocateHeldItem( Name, Class, Category, LExportTableP, Size )) AND
       (Size = TSIZE(AnArtemisExportTable)) THEN
        ExportTable := LExportTableP^;
    ELSE
        FatalError();
    END;
END GetHeldContext;



    (*  Initialize the GoodCharSet array so that CleanseString will be able
        to remove characters that Artemis doesn't like.
    *)

PROCEDURE SetUpCharSet ();
VAR
    i                   : CARDINAL;
    s                   : ARRAY [0..40] OF CHAR;
    s2                  : ARRAY [0..99] OF CHAR;

BEGIN
    IF (ExportTable.ArtemisType = A6000) OR (ExportTable.ArtemisType = A9000) THEN
        SetString (s, "0..9A..Za..z");
        i := 1;
        DoDash (s, s2, i);
        SetLengthOf (s2, i-1);
        FOR i := 1 TO LengthOf(s2) DO
            INCL (GoodCharSet, s2[i]);
        END;
    ELSE
        FOR i := 0 TO 255 DO
            INCL (GoodCharSet, CHR(i));
        END;
        EXCL (GoodCharSet, ",");
    END;
END SetUpCharSet;

BEGIN

    SetString(A,"A ");           (* prefix for AB format records *)
    SetString(P,"P ");           (* prefix for 6000 PB format records *)

    (* InitCaptions();  (* RSC 9/12/88 *) TGS 27-Feb-90 *)

    ContinueWriting := TRUE;

    GetHeldContext(ExportTable);
    IF (ExportTable.Ready) THEN
        SetUpCharSet();

        FlagTasksAsInvisible();
        MarkVisibleTasks( CountOfTasks );

        IF (CountOfTasks = 0) THEN
(*            SetString(Err,"No tasks selected for export.");
*)
            GetMessage (ModuleNumber+6, Err);  (* "No tasks selected for export." *)
            Error(Err);
        ELSE
            XportTasks(ExportTable);
            IF ( ContinueWriting ) THEN
                XportAssignments(ExportTable);
                IF ( ContinueWriting ) THEN
                    XportDependencies(ExportTable);
                    IF ( ContinueWriting ) THEN 
                       XportResources(ExportTable);
                       IF ( ContinueWriting ) THEN 
                          XportCalendar(ExportTable);
                       END;
                    END;
                END;
            END;
        END;
    END;

END TLXArt.
