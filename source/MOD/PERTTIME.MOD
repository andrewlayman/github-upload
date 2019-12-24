IMPLEMENTATION MODULE PertTimescale;

   (*
    Modification History:
         6-Sep-89 CMH   Moved AddTimescaling, AddTimeScalingVert,
                        FindMaxMinDates, FixMasterTaskCorners,
                        BeginCompressedAxis and EndCompressedAxis from
                        TSEDTimescale to PertTimescale.
        27-Sep-89 CMH   Consider phantoms in max axis calculation.
         3-Oct-89 CMH   Fixed alignment of axis and margins in
                        timescaled network diagrams.
        20-Oct-89 EGK   In CheckForDepConflict, replaced the hard-coded
                        phrase with a call to GetMessage.
         1-Nov-89 CMH   Corrected page margin so all are equal.
        14-Nov-89 CMH   Added code to bail out of TimeScaling when the
                        chart gets too wide for the SnetWidth spacing
                        array that is integer.
         7-Dec-89 CMH   Moved writing the compressed flag to TSEDPert.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        11-Apr-90 KKC   Replace all direct calculations on ADate and Duration
                        by calls to FindDuration, SubtractWorkingTime and
                        AddWorkingTime.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        10-Aug-90 RSC   Removed the PhantomFlag, as it was unused, but
                        referenced TempTaskFlags.
        31-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
    *)

FROM AccessMatrix 	    IMPORT
    (* PROC *)			GetCellInfo;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM CalShift   IMPORT
    (* VAR *)			TimeSheet;

FROM DataNetwork            IMPORT
    (* VAR *)			HorizOffset,
    			        MasterPipeWidth,
    			        NormalPipeWidth,
    				CompressAxis,
    				ArrangeBy,
    				LastColPosition;

FROM Dialog                 IMPORT
    (* PROC *)                  Error;

FROM Duration   IMPORT
    (* PROC *)                  FindDuration;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSScale, ATLGSTaskArrangement;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM NetCharacters          IMPORT
    (* CONST *)                 pastrUL;

FROM NetUtility             IMPORT
    (* VAR *)                   BoxWidth,
    				TLGSBoxWidth;

FROM NetStatic              IMPORT
    (* CONST *)			taskdim,			
    (* VAR *)                   SnetWidth, SnetHeight,
                                SnetRowOne, SnetColOne,
                                SnetRows, SnetCols,
                                Utility, loopnode;

FROM TimeJump               IMPORT
                                 FindNextKeyDate;

FROM Timei              IMPORT
     (* CONST*)             NoDuration, MaxDate, MinDate, Jan, Dec,
     (* TYPE *)             ADate, ADurationUnit, ADuration, ATimeInfo,
     (* PROC *) 		    KDay, KDate, TimeUtoT, TtoTimeU, DayOfWeek,
                            DurationToReal, RealToDuration;

FROM Timeu      	    IMPORT
     (* CONST *)            SMUPH,
     (* VAR *)              TimeTable, WeeksBeginOn, YearsOnFile;

FROM TSEDData		    IMPORT
    (* CONST *)			MAXCARDINAL,
    			 	BaseCharacterWidth,
    			 	RealVerticalGap,
    			        RealCharacterHeight,
    (* PROC *)			ShowThisTask;

FROM TSEDObjectWrite	    IMPORT
    (* PROC *)		     	WritePoint;

FROM TSEDWrite		    IMPORT
    (* PROC *)		     	WriteToTLGSFile;

FROM TreeObjects 	    IMPORT
    (* TYPE *)          	ATree, ATreeNode, ATreeOrder,
    (* PROC *)          	ValidateTree, ValidateTreeNode;

FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
                                DefaultDateAndTimeFormat;

FROM TimeUnitsTLGS          IMPORT
    (* VAR *) 			CharactersForScaling, UnitsForScaling;

FROM TSEDTimescale          IMPORT
    (* VAR *)                   MinAxisDate, MaxAxisDate,
                                AxisLength, AxisHeight,
                                AxisXorg, AxisYorg,
    (* PROC *)                  GetAxisChannels;

CONST
  LINENOTMASTER   = -1;
  LINEMASTERLEFT  = -2;
  LINEMOVEOK      = -3;
  ModuleNumber    = 20200;

VAR
  TimeToCompress : ADuration;
  TimeUnit       : ARRAY [0..taskdim] OF INTEGER;
  PixelOrigin,
  MaxPixelsPerUnit       : REAL;

(*--------------------------------------------------------------------------*)
        (*
            AddTimescaling
         *)


PROCEDURE AddTimescaling(Pass : CARDINAL) : CARDINAL;

VAR
    task                   : ATaskPtr;
    PixelsPerUnit          : REAL;
    StartingDate,
    LastTimeUnits,
    RogYY, RogMM,
    Date1, Date2           : ADate;
    NextKeyStep            : ADurationUnit;
    i, row, col,
    DateToUse,
    LastTimeUnit,
    UnitInTimeFrame,
    TimeFrameToUse,
    FirstTimeFrame,
    UnitCount,
    LineCount,
    PriorLines,
    MaxUnitWidth,
    PixelsInFrame,
    NextWeek,
    NextQuarter,
    MaxCols                : CARDINAL;
    TimeInfo               : ATimeInfo;
    column,
    cell                   : INTEGER;
    okay                   : BOOLEAN;

BEGIN

    LastTimeUnit:= 0;
    UnitCount:= 1;
    LineCount:= 0;
    MinAxisDate:=MaxDate;
    MaxAxisDate:=MinDate;
    MaxPixelsPerUnit:= 0.0;
    TimeToCompress:=NoDuration;

    WITH TimeInfo DO
        FOR col:= SnetColOne TO SnetCols DO
            column:=SnetWidth^[col];
            IF (column=BoxWidth) THEN
                (* find a task in the column *)
                row:= SnetRowOne;
                WHILE ((GetCellInfo(row,col) <= 0) AND (row < ORD(SnetRows))) DO
                    INC (row);
                END;

                (* get the task's date *)
                cell:= GetCellInfo(row,col);
                FindMaxMinDates(cell);
                task:=loopnode^[cell]^.Methods^.LockFlexStorDataObject(loopnode^[cell]);
                IF ((ArrangeBy = Baseline) AND (BaseLineExists IN task^.TaskFlags)) THEN
                        IF (Utility[cell] = -1) THEN  (* phantom end task *)
                            DateToUse:=task^.BaseLine.Dates.EarlyEnd; (* 22-Aug-89 CMH *)
                        ELSE
                            DateToUse:=task^.BaseLine.Dates.EarlyStart;
                        END;
                ELSE (* ArrangeBy = Actual or baseline doesn't exist *)
                        IF (Utility[cell] = -1) THEN  (* phantom end task *)
                            DateToUse:=task^.Plan.Dates.EarlyEnd; (* 22-Aug-89 CMH *)
                        ELSE
                            DateToUse:=task^.Plan.Dates.EarlyStart;
                        END;
                END;
                loopnode^[cell]^.Methods^.UnlockUnchangedDataObject(loopnode^[cell]);
                (* assign a date grouping *)
                TimeUtoT( DateToUse, TimeInfo );
    	        CASE UnitsForScaling OF
    	            SHours, SDays:
                        NextKeyStep:= Days;
                        TimeUnit[col]:=KDay(tiYear,tiMonth,tiDay);
                        UnitInTimeFrame:=
                            TimeTable.WeekTable[DayOfWeek(tiYear,tiMonth,tiDay)].TicsInDay;
                |   SWeeks:
                        NextKeyStep:= Weeks;
                        TimeUnit[col]:=KDay(tiYear,tiMonth,tiDay)-
                        (7+DayOfWeek(tiYear,tiMonth,tiDay)-WeeksBeginOn) MOD 7;
                        NextWeek:=KDay(tiYear,tiMonth,tiDay);
                        INC(NextWeek,(WeeksBeginOn+6-DayOfWeek(tiYear,tiMonth,tiDay))
                                    MOD 7 +1);
                        KDate(TimeUnit[col],tiYear,tiMonth,tiDay);
                        tiHour := 0;
                        tiMinute := 0;
                        okay:=TtoTimeU(TimeInfo,Date1);
                        KDate
                        (
                            NextWeek,
                            tiYear,
                            tiMonth,
                            tiDay
                        );
                        okay:=TtoTimeU(TimeInfo,Date2);
                        UnitInTimeFrame:= FindDuration(Date1, Date2, TimeSheet );
                |   SMonths:
                        NextKeyStep:= Months;
                        TimeUnit[col]:=KDay(tiYear,tiMonth,1);

                            (* 31-Oct-90 RSC big changes here...
                            *)
                        UnitInTimeFrame:=
                             TimeTable.YearTable[tiYear-TimeTable.FirstYear+1,tiMonth].TicsAtStartOfMonth;
                        IF (tiMonth > Jan) THEN
                            RogMM := tiMonth - 1;
                            RogYY := tiYear;
                        ELSE
                            RogMM := Dec;
                            RogYY := tiYear - 1;
                        END;
                            
                        IF (RogYY >= TimeTable.FirstYear) THEN
                            DEC(UnitInTimeFrame,
                                TimeTable.YearTable[RogYY-TimeTable.FirstYear+1,RogMM].TicsAtStartOfMonth);
                        END;

                |   SQuarters:
                        TimeUnit[col]:=KDay( tiYear, ( tiMonth DIV 3 ) * 3,1 );
                        INC(tiMonth,3);
                        IF( tiMonth>11) THEN
                        INC(tiYear);
                        tiMonth:=0;
                        END;
                        NextQuarter:= KDay( tiYear, ( tiMonth DIV 3 ) * 3, 1 );
                        KDate(TimeUnit[col],tiYear,tiMonth,tiDay);
                        okay:=TtoTimeU(TimeInfo,Date1);
                        KDate( NextQuarter, tiYear, tiMonth, tiDay );
                        okay:=TtoTimeU(TimeInfo,Date2);
                        UnitInTimeFrame:= FindDuration(Date1, Date2, TimeSheet );
                |   SYears:
                        NextKeyStep:= Years;
                        TimeUnit[col]:=KDay(tiYear,0,1);

                        IF (tiYear < (TimeTable.FirstYear + YearsOnFile)) THEN
                            UnitInTimeFrame :=
                                TimeTable.YearTable[tiYear-TimeTable.FirstYear+2,Jan].TicsAtStartOfMonth;
                        ELSE
                            UnitInTimeFrame := MAXCARDINAL;
                        END;

                        DEC(UnitInTimeFrame,
                            TimeTable.YearTable[tiYear-TimeTable.FirstYear+1,Jan].TicsAtStartOfMonth);

                ELSE
                END;  (* case *)
                IF (ORD(TimeUnit[col]) = LastTimeUnit) THEN  (* still in same time interval *)
                    INC(UnitCount);
                ELSE (* transitional *)
                    IF (LastTimeUnit <> 0) THEN (* do for steps after the first *)
                        MaxUnitWidth:= UnitCount*ORD(TLGSBoxWidth)+(LineCount+1)*NormalPipeWidth;
                        PixelsPerUnit:= FLOAT(MaxUnitWidth)
                                        /
                                        DurationToReal(TimeFrameToUse);

                        IF (PixelsPerUnit > MaxPixelsPerUnit) THEN
                            MaxPixelsPerUnit:= PixelsPerUnit;
                        END;
                    ELSE (* first step *)
                        FirstTimeFrame:= TimeUnit[col];
                        IF (LineCount = 0) THEN
                            PriorLines:= 1;
                        ELSE
                            PriorLines:= LineCount+1;
                        END;
                    END;
                    LineCount:=0;
                    TimeFrameToUse:=UnitInTimeFrame;
                    UnitCount:=1;
                END;
                LastTimeUnit:= TimeUnit[col];

            ELSE
                TimeUnit[col]:= LINENOTMASTER;
                INC(LineCount);
                row:= SnetRowOne;
                WHILE ((GetCellInfo(row,col)<> pastrUL) AND (row < ORD(SnetRows))) DO
                    INC (row);
                END;
                IF( GetCellInfo(row,col)=pastrUL) THEN
                        TimeUnit[col]:=LINEMASTERLEFT;
                END;
            END;

        END; (* for *)

    (* One More Time For Last Guy *)
        MaxUnitWidth:= UnitCount*ORD(TLGSBoxWidth)+(LineCount+1)*NormalPipeWidth;
        PixelsPerUnit:= FLOAT(MaxUnitWidth) / DurationToReal(TimeFrameToUse);
        IF (PixelsPerUnit > MaxPixelsPerUnit) THEN
            MaxPixelsPerUnit:= PixelsPerUnit;
        END;

        KDate(FirstTimeFrame,tiYear,tiMonth,tiDay);
        tiHour := 0;
        tiMinute := 0;
        okay:= TtoTimeU(TimeInfo, StartingDate);
        LastTimeUnits:=StartingDate;

        AddTimescalingVert(PriorLines*MasterPipeWidth+(HorizOffset DIV 2));

        PixelOrigin:= DurationToReal( MinAxisDate )
                    *
                    MaxPixelsPerUnit
                    -
                    FLOAT( HorizOffset DIV 2 );

        MaxCols := TimescalePositioning(StartingDate, NextKeyStep, Pass);

        FixMasterTaskCorners();
        AxisLength := TRUNC
                    (
                        DurationToReal
                        (
                            FindDuration( MinAxisDate, MaxAxisDate, TimeSheet )
                            -
                            TimeToCompress
                        )
                        *
                        MaxPixelsPerUnit
                    );
    END;
    RETURN (MaxCols);

END AddTimescaling;


(*--------------------------------------------------------------------------*)
        (*

	 CheckForDepConflict

         *)


PROCEDURE CheckForDepConflict(col : CARDINAL);
VAR
    s               : ARRAY [0..255] OF CHAR;
BEGIN

    IF (SnetWidth^[col-1] > SnetWidth^[col]) THEN
        SnetWidth^[col] := SnetWidth^[col-1] + 10;
        GetMessage (ModuleNumber+28, s);    (* "Start date conflict" *)
        Error (s);
    END;

END CheckForDepConflict;


(*--------------------------------------------------------------------------*)
        (*
	 FixMasterTaskCorners;
         *)


PROCEDURE FixMasterTaskCorners();

VAR

   col,
   PixelsInFrame : CARDINAL;
   SaveLast      : INTEGER;

BEGIN

(* Scan Backwards and fix Master Task corners *)
   PixelsInFrame:=MasterPipeWidth;
   FOR col:=SnetColOne+1  TO SnetCols   DO
       IF(TimeUnit[col]=LINENOTMASTER) THEN
          IF((TimeUnit[col-1]=LINEMASTERLEFT)
           OR (TimeUnit[col-1]=LINEMOVEOK)) THEN
              TimeUnit[col]:=LINEMOVEOK;
          END;
       END;
       SaveLast:=SnetWidth^[col];
   END;
   PixelsInFrame:=0;
   FOR col:=SnetCols TO SnetColOne BY -1 DO
       IF(TimeUnit[col]=LINEMASTERLEFT) THEN
          SnetWidth^[col]:=ORD(SaveLast)-MasterPipeWidth-PixelsInFrame;
          PixelsInFrame:=0;
       ELSIF(TimeUnit[col]=LINEMOVEOK) THEN
          SnetWidth^[col]:=ORD(SaveLast)-MasterPipeWidth-PixelsInFrame;
          PixelsInFrame:=0;
       ELSE
          PixelsInFrame:=MasterPipeWidth;
       END;
       SaveLast:=SnetWidth^[col];
   END;

END FixMasterTaskCorners;


(*--------------------------------------------------------------------------*)
        (*
           FindMaxMinDates
           Find the min and max dates for date scaling for Node Charts
         *)

PROCEDURE FindMaxMinDates(cell : INTEGER);

VAR
   task         : ATaskPtr;
   TaskTreeNode : ATreeNode;
   DateToUse    : ADate;

BEGIN

    TaskTreeNode := loopnode^[cell];

    IF (ShowThisTask(TaskTreeNode)) THEN
     (* check if open child and filtered in *)

        task:= TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);

        IF ((ArrangeBy = Baseline) AND
                (BaseLineExists IN task^.TaskFlags)) THEN

                IF (Utility[cell] = -1) THEN  (* phantom end task *)
                    DateToUse:=task^.BaseLine.Dates.EarlyEnd; (* 22-Aug-89 CMH *)
                ELSE
                    DateToUse:=task^.BaseLine.Dates.EarlyStart;
                END;
                IF (DateToUse>MaxAxisDate) THEN
                    MaxAxisDate:=DateToUse;
                END;
                DateToUse:=task^.BaseLine.Dates.EarlyStart;
                IF (DateToUse<MinAxisDate) THEN
                    MinAxisDate:=DateToUse;
                END;

            ELSE (* (ArrangeBy = Actual) OR (Baseline doesn't exist) *)

             (* actual task data for timescaling networks *)
                IF (Utility[cell] = -1) THEN  (* phantom end task *)
                    DateToUse:=task^.Plan.Dates.EarlyEnd; (* 22-Aug-89 CMH *)
                ELSE
                    DateToUse:=task^.Plan.Dates.EarlyStart;
                END;
                IF (DateToUse>MaxAxisDate) THEN
                    MaxAxisDate:=DateToUse;
                END;
                DateToUse:=task^.Plan.Dates.EarlyStart;
                IF (DateToUse<MinAxisDate) THEN
                    MinAxisDate:=DateToUse;
                END;

        END;


        TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    END;

END FindMaxMinDates;


(*--------------------------------------------------------------------------*)
        (*
            TimescalePositioning
         *)


PROCEDURE TimescalePositioning(StartingDate : ADate;
                               NextKeyStep  : ADurationUnit;
                               Pass         : CARDINAL) : CARDINAL;

CONST
    MAXINTEGER = 32768.0;

VAR
    CheckDrawingWidth : REAL;
    LastDate,
    NextDate,
    UnitsSoFar        : ADate;
    MaxCols,
    col,
    NextQuarter,
    LastTimeUnit      : CARDINAL;
    TimeInfo          : ATimeInfo;
    column,
    SaveThis,
    SaveLast          : INTEGER;
    okay,
    BailOut,
    FirstTask 	      : BOOLEAN;

BEGIN

    LastTimeUnit:= 0;
    MaxCols:= 0;
    FirstTask:= TRUE;
    BailOut := FALSE;
    LastDate:=StartingDate;

 (* calculating the horizontal positioning *)
    column := SnetWidth^[SnetColOne];
    IF (column = BoxWidth) THEN
        LastTimeUnit:=TimeUnit[SnetColOne];
    END;
    SaveLast := NormalPipeWidth; (* dependency line *)
    IF (column= BoxWidth) THEN
        SaveLast := TLGSBoxWidth;
    END;

    IF (column=BoxWidth) THEN
        CheckDrawingWidth := DurationToReal( StartingDate )
                             *
                             MaxPixelsPerUnit
                             -
                             PixelOrigin;
        IF (CheckDrawingWidth < MAXINTEGER) THEN
            SnetWidth^[SnetColOne] := TRUNC(CheckDrawingWidth);
        ELSE
            BailOut := TRUE;
            MaxCols := SnetColOne;
        END;
    ELSE
        SnetWidth^[SnetColOne]:= HorizOffset;
    END;

    WITH TimeInfo DO
        IF (NOT BailOut) THEN
            col := SnetColOne;
            LOOP (* loop from SnetColOne+1 to SnetCols or until chart too big *)
                INC(col);
                IF (col > ORD(SnetCols)) THEN
                    MaxCols := SnetCols;
                    EXIT;
                END;
                column:= SnetWidth^[col];
                SaveThis := NormalPipeWidth; (* dependency pipe *)
                IF (column = BoxWidth) THEN
    	            SaveThis := TLGSBoxWidth;
                END;
                IF (column=BoxWidth) THEN (* box *)
                    IF (ORD(TimeUnit[col])=LastTimeUnit) THEN (* same interval *)
                        CheckDrawingWidth := FLOAT(SnetWidth^[col-1] + SaveLast);
                        IF (CheckDrawingWidth < MAXINTEGER) THEN
                            SnetWidth^[col] := TRUNC(CheckDrawingWidth);
                        ELSE
                            BailOut := TRUE;
                            MaxCols := col;
                            EXIT;
                        END;
                    ELSE (* different interval, jump forward *)
                        KDate(TimeUnit[col],tiYear,tiMonth,tiDay);
                        tiHour := 0;
                        tiMinute := 0;
                        okay:=TtoTimeU(TimeInfo,UnitsSoFar);
                        IF (CompressAxis) THEN
                            IF (UnitsForScaling = SQuarters) THEN
                                TimeUtoT (LastDate,TimeInfo);
                                INC(tiMonth,3);
                                IF (tiMonth>11) THEN
                                    INC(tiYear);
                                    tiMonth:=0;
                                END;
                                NextQuarter:= KDay(tiYear,(tiMonth DIV 3)*3,1);
                                KDate(NextQuarter,tiYear,tiMonth,tiDay);
                                okay:=TtoTimeU(TimeInfo,NextDate);
                            ELSE
                                NextDate:=FindNextKeyDate(LastDate,NextKeyStep);
                            END;
                            IF (UnitsSoFar > NextDate) THEN
                                TimeToCompress:=TimeToCompress + (UnitsSoFar-NextDate);
                                IF (Pass = 2) THEN
                                    WritePoint(NextDate,UnitsSoFar);
                                END;
                            END;
                            LastDate := UnitsSoFar;
                            FirstTask := FALSE;
                        END; (* if compressaxis *)
                        StartingDate := UnitsSoFar-TimeToCompress;
                        CheckDrawingWidth := DurationToReal(StartingDate)
                                            *
                                            MaxPixelsPerUnit
                                            -
                                            PixelOrigin;
                        IF (CheckDrawingWidth < MAXINTEGER) THEN
                            SnetWidth^[col] := TRUNC(CheckDrawingWidth);
                        ELSE
                            BailOut := TRUE;
                            MaxCols := col;
                            EXIT;
                        END;
                    END;
                    LastTimeUnit := TimeUnit[col];
                ELSE (* line *)
                    CheckDrawingWidth := FLOAT(SnetWidth^[col-1] + SaveLast);
                    IF (CheckDrawingWidth < MAXINTEGER) THEN
                        SnetWidth^[col] := TRUNC(CheckDrawingWidth);
                    ELSE
                        BailOut := TRUE;
                        MaxCols := col;
                        EXIT;
                    END;
                END;
                SaveLast := SaveThis;
                CheckForDepConflict(col);
            END; (* loop *)
        END;
    END;

    IF (BailOut) THEN
        LastColPosition := SnetWidth^[MaxCols-1] + SaveLast;
    ELSE
        LastColPosition:= SnetWidth^[MaxCols] + SaveLast;
    END;

    RETURN(MaxCols);

END TimescalePositioning;


(*--------------------------------------------------------------------------*)
        (*
            AddTimescalingVert
         *)


PROCEDURE AddTimescalingVert(SpaceForPriorLines : CARDINAL);

VAR
   TempReal               : REAL;
   okay 	          : BOOLEAN;
   RoundTime,
   NumberOfAxisChannels   : CARDINAL;
   TimeInfo         : ATimeInfo;

BEGIN

(* ****  Prepare  Axis parameters ***** *)

    WITH TimeInfo DO
           TimeUtoT (MinAxisDate,TimeInfo);

    	   CASE UnitsForScaling OF

               SHours, SDays:
                 RoundTime:=KDay(tiYear,tiMonth,tiDay);

           |   SWeeks:

                 RoundTime:=KDay(tiYear,tiMonth,tiDay)-
                 (7+DayOfWeek(tiYear,tiMonth,tiDay)-WeeksBeginOn) MOD 7;

           |   SMonths:
                 RoundTime:=KDay(tiYear,tiMonth,1);

           |   SQuarters:
                 RoundTime:=KDay(tiYear,(tiMonth DIV 3)*3,1);

           |   SYears:
                 RoundTime:=KDay(tiYear,0,1);
           ELSE

           END;  (* case *)

           KDate(RoundTime,tiYear,tiMonth,tiDay);
           tiHour := 0;
           tiMinute := 0;
           okay:= TtoTimeU(TimeInfo,MinAxisDate);

           TimeUtoT (MaxAxisDate,TimeInfo);

    	   CASE UnitsForScaling OF

              SHours, SDays:
               RoundTime:=KDay(tiYear,tiMonth,tiDay+1);

           |   SWeeks:
               RoundTime:=KDay(tiYear,tiMonth,tiDay);
               INC(RoundTime,(WeeksBeginOn+6-DayOfWeek(tiYear,tiMonth,tiDay))
                              MOD 7 +1);
           |   SMonths:
                 RoundTime:=KDay(tiYear,tiMonth+1,1);

           |   SQuarters:
                 INC(tiMonth,3);
                 IF( tiMonth>11) THEN
                   INC(tiYear);
                   tiMonth:=0;
                 END;

                 RoundTime:=KDay(tiYear,(tiMonth DIV 3)*3,1);

           |   SYears:
                 RoundTime:=KDay(tiYear+1,0,1);
           ELSE

           END;  (* case *)

           KDate(RoundTime,tiYear,tiMonth,tiDay);

           tiHour := 0;
           tiMinute := 0;
           okay:= TtoTimeU(TimeInfo,MaxAxisDate);

           TempReal:=DurationToReal( MinAxisDate ) * MaxPixelsPerUnit;
           TempReal:=TempReal-FLOAT(SpaceForPriorLines);

           MinAxisDate:=RealToDuration( TempReal / MaxPixelsPerUnit );

           AxisXorg := 0;
           AxisYorg := 0;
           NumberOfAxisChannels:= GetAxisChannels();
           AxisHeight:= NumberOfAxisChannels*2*RealCharacterHeight;
    END;
END AddTimescalingVert;


(*--------------------------------------------------------------------------*)

BEGIN                       (* PertTimescale *)


END PertTimescale.
