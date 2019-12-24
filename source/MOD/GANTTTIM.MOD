IMPLEMENTATION MODULE GanttTimescale;
   (*
         6-Sep-89 CMH   Moved GanttTimescaling, GetDurationBarDates and 
                        FindGanttMaxMinDates from TSEDTimescale to GanttTimescale.
         7-Sep-89 CMH   Show Baseline in axis only when specified on the
                        form.
        18-Sep-89 CMH   Changed date range to allow min less than the 
                        schedule min and max greater than the schedule max.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        27-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
        12-Aug-91 PHR   Set baseline start/end to 0 when no baseline exists
                        for a task.  TLGS picks this up, and does not draw
                        baseline boxes for the task. Ref bug #770.
    *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM DataGantt              IMPORT
     (* VAR *)               	LeftBarLabelSize,
                   		RightBarLabelSize,
                   		TopBarLabelSize,
    				SlackType,
                   		BottomBarLabelSize,
                                ShowBaseLineBars;

FROM Duration               IMPORT
     (* PROC *)                 AddWorkingTime, SubtractWorkingTime;

FROM Gantt                 IMPORT
    (* TYPE *)			ASlackStyle;
    
FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSScale, ATLGSTaskArrangement;                                

FROM SYSTEM                 IMPORT 
    (* TYPE *)			 ADDRESS;
    
FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
                                DefaultDateAndTimeFormat;

FROM TimeJump               IMPORT
                                 FindNextKeyDate;    
                                
FROM Timei                  IMPORT
     (* CONST*)                 MinDate, MaxDate, NoDuration,
     (* TYPE *)                 ADate, ADuration,
     (* PROC *)                 KDay, KDate, TimeUtoT, TtoTimeU, DayOfWeek, 
                                DurationToReal, RealToDuration;

FROM Timeu                  IMPORT 
     (* CONST *)                SMUPH,
     (* VAR *)                  TimeTable, AYearTable, 
                                AWeekTable, WeeksBeginOn;
                                                                                                 
FROM TimeUnitsTLGS          IMPORT
    (* VAR *) 			CharactersForScaling, UnitsForScaling;
                                

FROM TreeObjects 	    IMPORT
    (* TYPE *)          	ATree, ATreeNode, ATreeOrder,
    (* PROC *)          	ValidateTree, ValidateTreeNode;
                                
FROM TSEDData		    IMPORT
    (* CONST *)	                MAXCARDINAL,
                                BaseCharacterWidth, 
                                RealVerticalGap,    
                                RealCharacterHeight,
    (* PROC *)	                ShowThisTask;

FROM TSEDTimescale          IMPORT
    (* VAR *)                   MinAxisDate, MaxAxisDate,
                                AxisLength, AxisHeight,
                                AxisXorg, AxisYorg,
    (* PROC *)                  GetAxisChannels;
    
VAR
    MaxStartDate           : ADate; 
    PixelOrigin,
    MaxPixelsPerUnit       : REAL;

(*--------------------------------------------------------------------------*)
        (*  
           Find the min and max dates for date scaling 
         *)
         

PROCEDURE GanttTimescaling();

CONST
    EDGEBUFFER = 2; (* characters *)
    
VAR
    TextInSU,
    AxisSizeInSU,
    AxisSizeInTime        : REAL;
    NumberOfAxisChannels  : CARDINAL;  
    TimeFrameToUse,
    TextInTime            : ADuration;
    BufferLeft,
    BufferRight,
    UsingStartDate,
    UsingEndDate          : BOOLEAN;
    
BEGIN  
 
    MaxAxisDate := MinDate;
    MaxStartDate := MinDate;
    MinAxisDate := MaxDate;
   
 (* get min and max axis dates for the current schedule *)   
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentAfterChild,65535,
                                 FindGanttMaxMinDates, NIL);
                                 
 (* use the users date range *)   
    UsingStartDate := FALSE;
    IF (StartingDateSelected) THEN  
        IF ((StartDateToUse >= MinDate) AND 
            (StartDateToUse < MaxAxisDate)) THEN
             MinAxisDate:= StartDateToUse;   (* user start date from form *)
             UsingStartDate := TRUE;
        END;
    END;
    UsingEndDate := FALSE;
    IF (EndingDateSelected) THEN  
        IF ((EndDateToUse <= MaxDate) AND 
            (EndDateToUse > MinAxisDate)) THEN
             MaxAxisDate:= EndDateToUse;   (* user end date from form *)
             UsingEndDate := TRUE;
        END;
    END;
    
        (* 27-Oct-90 RSC StdDay is now HalfHours, not Hours.
        *)
    CASE UnitsForScaling OF
        SHours:
          TimeFrameToUse:= SMUPH;
      | SDays:
          TimeFrameToUse:= TimeTable.StdDayTics;    (* 1-Nov-90 RSC *)
      | SWeeks:
          TimeFrameToUse:= TimeTable.StdWeek * TimeTable.StdDayTics;    (* 1-Nov-90 RSC *)
      | SMonths:
          TimeFrameToUse:= (4 * (TimeTable.StdWeek * TimeTable.StdDayTics)
                         + TimeTable.StdDayTics);
      | SQuarters:
          TimeFrameToUse:= (12 * TimeTable.StdWeek * TimeTable.StdDayTics)
                         + 6 * TimeTable.StdDayTics;
      | SYears:
          TimeFrameToUse:= 52 * TimeTable.StdWeek * TimeTable.StdDayTics;
           
      ELSE  (* use months *)
        TimeFrameToUse:= (4 * TimeTable.StdWeek * TimeTable.StdDayTics)
                        + TimeTable.StdDayTics;
   END;  (* case *)   

  
 (* calculate max sedona units per time frame *)
    MaxPixelsPerUnit:= CharactersForScaling/DurationToReal(TimeFrameToUse); 
    MaxPixelsPerUnit:= MaxPixelsPerUnit*FLOAT(BaseCharacterWidth);     
 
    BufferLeft := FALSE;
    BufferRight := FALSE;
    
 (* buffer edges of axis for bar labels *)
    (* left side of axis *) 
    IF (NOT UsingStartDate) THEN  
        IF (LeftBarLabelSize > 0)THEN
            TextInSU:= FLOAT(LeftBarLabelSize*BaseCharacterWidth);
            TextInTime:= RealToDuration(TextInSU/MaxPixelsPerUnit);
            IF (MinAxisDate > AddWorkingTime( MinDate, TextInTime, TimeSheet) ) THEN
                MinAxisDate:= SubtractWorkingTime( MinAxisDate, TextInTime, TimeSheet );
            END;
            BufferLeft := TRUE;
        END;
    END;
    
    (* right side of axis - max of top right and bottom label sizes *) 
    IF (NOT UsingEndDate) THEN  
    
        IF (RightBarLabelSize > 0)THEN
            TextInSU:= FLOAT(RightBarLabelSize*BaseCharacterWidth);
            TextInTime:= RealToDuration(TextInSU/MaxPixelsPerUnit);
            IF (
                    MaxAxisDate 
                    < 
                    SubtractWorkingTime( MaxDate, TextInTime, TimeSheet )
               ) THEN 
                MaxAxisDate:= AddWorkingTime
                              ( 
                                MaxAxisDate, 
                                TextInTime, 
                                TimeSheet
                              ); 
            END;
            BufferRight := TRUE;
        END;
    
        IF (TopBarLabelSize > 0) THEN
            TextInSU:= FLOAT(TopBarLabelSize*BaseCharacterWidth);
            TextInTime:= RealToDuration(TextInSU/MaxPixelsPerUnit);
            IF (
                    MaxAxisDate 
                    < 
                    SubtractWorkingTime( MaxDate, TextInTime, TimeSheet ) 
               ) THEN
                IF ( 
                        AddWorkingTime( MaxStartDate, TextInTime, TimeSheet ) 
                        > 
                        MaxAxisDate 
                   ) THEN 
                    MaxAxisDate:= AddWorkingTime
                                  ( 
                                    MaxStartDate, 
                                    TextInTime, 
                                    TimeSheet
                                  );
                    BufferRight := TRUE;
                END;
            END;
        END;
    
        IF (BottomBarLabelSize > 0) THEN
            TextInSU:= FLOAT(BottomBarLabelSize*BaseCharacterWidth);
            TextInTime:= RealToDuration(TextInSU/MaxPixelsPerUnit);
            IF (
                    MaxAxisDate 
                    < 
                    SubtractWorkingTime(MaxDate, TextInTime, TimeSheet)
               ) THEN 
                IF (
                        AddWorkingTime( MaxStartDate, TextInTime, TimeSheet) 
                        > 
                        MaxAxisDate 
                   ) THEN 
                    MaxAxisDate:= AddWorkingTime
                                  ( 
                                    MaxStartDate, 
                                    TextInTime, 
                                    TimeSheet
                                  );

                    BufferRight := TRUE;
                END;
            END;
        END;
    END;
   
 (* buffer edges so symbols are not cut off at edge of plot,
    execpt if the user specified a date range or
    chart was buffered for labels *)   
    TextInSU:= FLOAT(EDGEBUFFER*BaseCharacterWidth);
    TextInTime:= RealToDuration(TextInSU/MaxPixelsPerUnit);
    IF ((NOT UsingStartDate) AND (NOT BufferLeft)) THEN
        IF (
                MinAxisDate 
                > 
                AddWorkingTime( MinDate, TextInTime, TimeSheet ) 
           ) THEN 
            MinAxisDate:= SubtractWorkingTime
                          ( 
                            MinAxisDate, 
                            TextInTime, 
                            TimeSheet
                           );
        END;
    END;
    IF ((NOT UsingEndDate) AND (NOT BufferRight)) THEN
        IF (
                MaxAxisDate 
                < 
                SubtractWorkingTime(MaxDate, TextInTime, TimeSheet )
           ) THEN
            MaxAxisDate:= AddWorkingTime( MaxAxisDate, TextInTime, TimeSheet );
         END;
    END;

    
    PixelOrigin:=DurationToReal(MinAxisDate)*MaxPixelsPerUnit;
    AxisXorg:= TRUNC(DurationToReal(MinAxisDate)*MaxPixelsPerUnit-PixelOrigin); 
    AxisLength:= TRUNC(DurationToReal(MaxAxisDate)*MaxPixelsPerUnit-PixelOrigin-FLOAT(AxisXorg));

    AxisYorg := 0;
    NumberOfAxisChannels:= GetAxisChannels();
    AxisHeight:= NumberOfAxisChannels*(RealVerticalGap+RealCharacterHeight);
                    
END GanttTimescaling;


(*--------------------------------------------------------------------------*)
        (*  
           Gantt Chart--
           Find the min and max dates for date scaling 
         *)
         
PROCEDURE FindGanttMaxMinDates(VAR TaskTreeNode : ATreeNode;
                               Context : ADDRESS   );                          
VAR
    DateToUse : ADate;
    task      : ATaskPtr;

BEGIN    

    task := TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
 
    IF (ShowThisTask(TaskTreeNode)) THEN
     (* check if open child and filtered in *)
    
        DateToUse:=task^.Plan.Dates.EarlyStart;
        IF (DateToUse<MinAxisDate) THEN
            MinAxisDate:=DateToUse;
        END; 
        DateToUse:=task^.Plan.Dates.EarlyEnd;
        IF (DateToUse>MaxAxisDate) THEN
            MaxAxisDate:=DateToUse;
        END;    
     (* get maximum start date in schedule for bar label size calculations *)      
        IF (task^.Plan.Dates.EarlyStart > MaxStartDate) THEN
            MaxStartDate := task^.Plan.Dates.EarlyStart;
        END; 
     (* get minimum and maximum start date in schedule including slack
        for bar label size calculations *)      
        IF (SlackType = TotalSlack) THEN
            IF (task^.Plan.Dates.LateTotalEnd > task^.Plan.Dates.EarlyEnd) THEN
                IF (task^.Plan.Dates.LateTotalEnd > MaxStartDate) THEN
                    MaxStartDate := task^.Plan.Dates.LateTotalEnd;
                END;
            END;
        ELSIF (SlackType = FreeSlack) THEN
            IF (task^.Plan.Dates.LateFreeEnd > task^.Plan.Dates.EarlyEnd) THEN
                IF (task^.Plan.Dates.LateFreeEnd > MaxStartDate) THEN
                    MaxStartDate:= task^.Plan.Dates.LateFreeEnd;
                END;
            END;
        END;
        IF ((BaseLineExists IN task^.TaskFlags) AND (ShowBaseLineBars)) THEN
             DateToUse:=task^.BaseLine.Dates.EarlyEnd;
             IF (DateToUse>MaxAxisDate) THEN
                 MaxAxisDate:=DateToUse;
             END;    
             DateToUse:=task^.BaseLine.Dates.EarlyStart;
           
             IF (DateToUse<MinAxisDate) THEN
                 MinAxisDate:=DateToUse;
             END;  
          (* get maximum start date in schedule for bar label size calculations *)      
             IF (task^.BaseLine.Dates.EarlyStart > MaxStartDate ) THEN
                 MaxStartDate := task^.BaseLine.Dates.EarlyStart;
             END;  
        END;
        
    END;
    
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

END FindGanttMaxMinDates;


(*--------------------------------------------------------------------------*)
        (*  
            Get Duration Bar Dates 
            
         *)
         
PROCEDURE GetDurationBarDates(TaskTreeNode :ATreeNode;
			  VAR x1Plan,  x2Plan,
			      x1Actual,x2Actual,
			      slack        :ADate);

VAR
    task     : ATaskPtr;

BEGIN 

 (* get planned(baseline) and actual (plan) dates from task record *)
 (* if baseline data is not set use actual data *)
    
    task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    
    slack:= NoDuration;
    IF (SlackType = TotalSlack) THEN
        IF (task^.Plan.Dates.LateTotalEnd > task^.Plan.Dates.EarlyEnd) THEN
            slack:= task^.Plan.Dates.LateTotalEnd;
        END;
    ELSIF (SlackType = FreeSlack) THEN
        IF (task^.Plan.Dates.LateFreeEnd > task^.Plan.Dates.EarlyEnd) THEN
            slack:= task^.Plan.Dates.LateFreeEnd;
        END;
    END;
        
    x1Actual:= task^.Plan.Dates.EarlyStart;
    x2Actual:= task^.Plan.Dates.EarlyEnd;
    
    IF(BaseLineExists IN task^.TaskFlags) THEN
        x1Plan:= task^.BaseLine.Dates.EarlyStart;
        x2Plan:= task^.BaseLine.Dates.EarlyEnd;
    ELSE
        x1Plan:= 0; (* PHR -- 08/12/91 *)
        x2Plan:= 0; (* PHR -- 08/12/91 *)
    END;
   
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);
    
END GetDurationBarDates;             


(*--------------------------------------------------------------------------*)

BEGIN                       (* GanttTimescale *)

    
END GanttTimescale.

