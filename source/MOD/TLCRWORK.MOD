MODULE TLCrWork;


  (* Work module for the cost reports
       Jan 28 88 RSC Adjust fonts for Bold and normal.
       Feb  3 88 RSC Rename variable so Andrew likes it.  It WAS a little
                     weird.  Also, fix 'Manxxx' bug.
       18-Feb-88 LAA Changed import of RsrcCalc to ManHours.
       24-Feb-88 RSC Added CTRL-Break support.
       27-Feb-88 RSC New rollup module.
        3-Mar-88 AJL -In GenerateTimeForRsrcData, look at all tasks, even
                      closed ones.
                     -Inside the ResourceVsTime and TaskVsTime loops, replace
                      the WHILE with REPEAT loops so that if the project
                      consists of but a milestone, we still print one column.
        4-Mar-88 AJL -Added a PeriodType parameter to RollupResource.
       14-Apr-88 EGK  Set the font value for skip records (aggregate or not?).
       15-Jun-88 RSC  Added Thermometer.
       23-Jun-88 EGK  Added code for normalizing.
       27-Jun-88 AJL -Added ResourceFiltersPassed.
       11-Jul-88 EGK -Fixed bug in DoData where only one skip record was
                      being written in the totals column line if there
                      was no data in any of the columns.
       30-Aug-88 AJL -Modified the GenerateOneResourcesData procedure so
                      that it will constrain the data chosen to the date
                      range specified in the Interface record.
                     -Improved some documentation.
       ??-Sep-88 RSC -For November masters, permanantly fixed Ed's 11-Jul-88
                      problem by fixing WriteIntData.
        7-Nov-88 RSC -Fixed AssignedQuantity bug for rsrcs and var costs, by
                      using the ManHours/Max instead.  Then, I had to fix the
                      bug where the totals are not being normalized.
       21-Dec-88 LAA  Changed imports for Lazlo reorganization.
       23-Feb-89 EGK  Found that in ColumnData.SummData, the ReleaseObject call
                      was executed even if nothing was locked (i.e., one of the
                      IF's failed).  Fixed that.  Also found that the modular
                      arithmetic in SummData and DoHeaders didn't work on
                      boundary conditions.  Also put a check after the
                      LockObjectArray in SummData.
       21-Mar-89 RSC  Support FSMUPH rather than FLOAT(SMUPH).
       22-Mar-89 RSC  Improve for "Better Reports" project.  Use XTabFormat
                      rather than RptCommon routines.
       20-May-89 RSC  Accomidated new WorkHours module.  Also changed
                      "Man..." to "Work...." in column names.
       25-May-89 EGK  Removed the mysterious Lock-Unlock pair with nothing
                      in between, in GenerateTimeForTaskData.
       12-Jun-89 EGK  Changed to use new "XTabFirstBaseCol" constant, which
                      replaces incorrect use of "XTabBaseLineOffset".
       12-Jun-89 AJL  WorkHoursDivMax no longer crashes the program on a
                      task vs. time report.
       22-Jun-89 KKC  Put an ELSE for the case statement in NormalizeByTime.
       25-Jul-89 EGK  Changed SummData to keep running row totals.  Changed
                      other clients of "TotalBy" quantities to reflect the
                      new "Running" totals type.
       09-Aug-89 KKC  Add copyright message.
       23-Aug-89 EGK  RollupResource now expects "CostTracking" as a
                      parameter, so import it from Changer.
       28-Aug-89 KKC  Remove import of CostTracking from Changer.
                      Pass the "CostTracking" from AnOverlayInterface to
                      RollupResource.
       31-Aug-89 EGK  Changed PercentAssigned column to be a real-valued
                      ratio column.
        5-Sep-89 MWP  Added thermometer message.
       22-Sep-89 MWP  Added parameter to RsrcHeader call.
       30-Mar-90 RSC  Made Timeu to Timei/TimeForm conversions.
       11-Apr-90 KKC  Replace all direct calculations on ADate and Duration
                      by calls to FindDuration, SubtractWorkingTime and
                      AddWorkingTime.
       05-Jun-90 AJL  Removed import of RateCalendars.
       17-Sep-90 TGS  New XTab columns.
       22-Oct-90 TGS  Adjust XTab equations to reflect adjustments to 
                      RollupResources.
       06-Nov-90 AJL  Import column numbers from XTabColNumbers.
                      Remove unused imports of BigTimeU, IntFileIO and others.
       19-Dec-90 TGS  Somehow some of Larry's changes to 4.03 didn't get 
                      rolled into Eve. Here is his description of them:
        9-Oct-90 LAA  In order to fix bugs # 3170 and 3099, I added a 
                      statement to ColumnData to set DataExists to TRUE if
                      the report is trying to produce a running total.
                      The bugs are that running totals are not produced for 
                      Rsrc vs. Time cross-tabs when the resource is no longer 
                      assigned to anything.  That should just mean that it 
                      contributes 0.  When doing running totals, the fact 
                      that you don't have any good NEW data does NOT mean you 
                      don't have any data to be written out for that column.  
       21-May-91 TGS  Remove new XTab columns.
       23-May-91 TGS  Okay, finally get rid of references to "UpperLimit", an
                      unused field these days.
        4-Jun-91 TGS  Put XTabExtraDollars back in.
       27-Aug-91 EGK  Changed the way that WrkHrsPerMax is computed, so that
                      if the resource is unavailable for the period, we just
                      output a zero instead of MaxReal.  Using MaxReal was
                      causing problems for the cross-tab reports (it was
                      printing asterisks instead of numbers) and the
                      histogram report (it was altogether dropping resources
                      (Everybody: "dropping resources" :-) with any unavail-
                      abilities) when this column was picked.
       24-Jan-92 TGS  Generate Histogram report headings and data according
                      to equal-spaced (ticwise) periods. This is so they are
                      in synch with the Histogram date headings which make
                      this assumption. Bug 5324.
  *)



FROM Assignments   IMPORT
    (* TYPE *)          AnAssignmentAttribute,
                        AnAssignmentAttributeSet;

FROM Allocs        IMPORT
    (* TYPE  *)         ATaskPtr,
                        ATaskFilter, ATaskFilterSet,
    (* VAR   *)         TaskTree;

FROM BigTimeU       IMPORT
    (* PROC *)          CompareBigTimes,
    (* TYPE *)          ABigTime;

FROM CalShift       IMPORT
    (* VAR   *)         TimeSheet;

FROM DateLists      IMPORT
    (* TYPE *)          ADateList, ADateListIndex,
    (* PROC *)          LocateDateInDateList, GetDateListEntry;

FROM Dialog        IMPORT
        (* PROCS *)     FatalError;

FROM Duration      IMPORT
    (* PROC *)          FindDuration;

FROM ExportLinkage IMPORT
    (* VAR *)           InterFile;

FROM FileSystem    IMPORT
        (* TYPE *)      Response;

FROM FileAux       IMPORT
        (* PROCS *)     CheckIO;

FROM Filter1       IMPORT
        (* PROC *)      ResourceFiltersPassed;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle, AnExtStoragePreference,
        (* PROC *)      CreateExtObjectWithSize, DiscardExtObject,
                        LockObjectArray, ReleaseObject,
                        ReleaseUnchangedObject;

FROM IntFileIO     IMPORT
    (* CONST *)         PredicateSubfileNumber,
                        RealNumberType, IntegerType,
                        CardinalType, BooleanType, 
                        SkipRecordType,
    (* TYPE *)          ADataType,
                        AnIntDataRecord,
    (* PROC *)          WriteIntData;

FROM Kbio          IMPORT
        (* PROCS *)     BreakRequested;

FROM LongConvert    IMPORT
    (* PROC *)          LongToReal;

FROM MsgFile       IMPORT
    (* PROC *)          GetMessage;

FROM Overlays      IMPORT
        (* PROCS *)     OverlayContext;

FROM Progress      IMPORT
        (* TYPE *)      AThermometer,
        (* PROCS *)     CreateThermometer, UpdateThermometer,
                        DiscardThermometer;

FROM ResCalUI       IMPORT
    (* TYPE *)          AnAvailabilityRate;

FROM RollupResourceModule IMPORT
        (* TYPES *)     AResourceKind, ASingleAccumulation, AnAccumulationRecord,
                        APeriodType,
        (* PROCS *)     RollupResource;

FROM RptCommon     IMPORT
        (* TYPES *)     AnOverlayInterfacePtr, AReportType,
                        ASummChoice, AClientUse,
        (* VARS  *)     TotalByX, TotalByY,
        (* PROCS *)     GetMessageWord, TaskHeaders,
                        SetResourcesOnly, TimeHeaders,
                        RsrcHeaders;

FROM RsrcMod       IMPORT
        (* TYPE  *)     AResourcePointer,
                        AResourceType,
        (* VAR   *)     ResourceTree;

FROM Subfiles      IMPORT
        (* PROCS *)     StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATreeNode, ATreeOrder;

FROM TimeJump      IMPORT
        (* PROCS *)     FindNextKeyDate;

FROM Timei         IMPORT
        (* TYPE *)      ADurationUnit, ADate, ADuration,
        (* PROCS*)      DurationToReal;

FROM TimeMath       IMPORT
        (* PROC *)      DurationInPeriod;

FROM Timeu         IMPORT
        (* VAR *)       FSMUPH,
        (* PROC *)      UpScale;

FROM TimeXlate      IMPORT
        (* PROC *)      BigTimeToCalendarTime,
                        CalendarTimeToBigTime,
                        TimesToBigTimes;

FROM WorkHours      IMPORT
        (* TYPE *)      WorkHoursToRealTime;

FROM XTabColNumbers IMPORT
    (* CONST *)
                        XTabQuantity,
                        XTabBillable,
                        XTabSpentQuantity,
                        XTabYTGQuantity,
                        XTabTotalDollars,
                        XTabSpentDollars,
                        XTabYTGDollars,
                        XTabPercentAss,
                        XTabTWorkHours,
                        XTabTWorkWeeks,
                        XTabTWorkHrsPerMax,
                        XTabAWorkHours,
                        XTabAWorkWeeks,
                        XTabYWorkHours,
                        XTabYWorkWeeks,
                        XTabDataExists,
                        XTabExtraDollars,
                        (* 21-May-91 TGS
                        XTabTOTWorkHours,
                        XTabAOTWorkHours,
                        XTabYOTWorkHours,
                        XTabTotalOTDollars,
                        XTabSpentOTDollars,
                        XTabYToGoOTDollars,
                        XTabTotalEffortDollars,
                        XTabSpentEffortDollars,
                        XTabToGoEffortDollars, 
                        *)
                        XTabBaseLineOffset,
                        XTabFirstBaseCol;




CONST
        Zero            = 0.0;
        AlmostZero      = 0.5;
        One             = 1.0;
        OneHundred      = 100.0;
        ModuleNumber    = 21400;  (* Shared with TLCr *)
        LongOneHundred  = 100L;
        MaxReal         = 1.79E+308;    (* Local infinity. *)


        (* Subfile IO version number:   *)

        VersionNumber    = 1; (* For subfiles *)

        MaxReportColumns = 1; (* How many we allow across the page. *)

        MaxColRecords    = 200; (* Maximum resources across for sums.
                                   True upper limit is 4KB, but lets be real
                                   conservative.
                                 *)
        MaxColGroupsInRow = 20; (* So we can have up to 20 * 200 or 4000 tracked
                                   columns.  More than that are not totaled.
                                *)


TYPE
        AColSumArray = POINTER TO ARRAY [1..MaxColRecords] OF REAL;
        AColSummary  = ARRAY [1..MaxColGroupsInRow] OF AnExtHandle;
            (* Each EXT Handle contains one ColSumArray. *)

        AGenerateDataContext = RECORD
                ID             : CARDINAL;
                RowNode        : ATreeNode;
                RowIsLevel0    : BOOLEAN;
                AggregateFont  : CHAR;
        END;

        AResourceLimitContext = RECORD
            Total       : REAL;
            PeriodStart,
            PeriodEnd   : ADate;
            IsBaseline  : BOOLEAN;
        END;

        AGenerateDataContextPtr = POINTER TO AGenerateDataContext;

        AGenerateDataProc    = PROCEDURE ( VAR AGenerateDataContext, VAR BOOLEAN );

VAR
    Interface              : AnOverlayInterfacePtr;

    Thermometer            : AThermometer;

    GlobalQuantityMonitor  : BITSET;

    GrandSumm              : ARRAY [1..MaxReportColumns] OF REAL;
    RowSum                 : ARRAY [1..MaxReportColumns] OF REAL;
    ColSum                 : ARRAY [1..MaxReportColumns] OF AColSummary;
    ColSumIncluded         : ARRAY [1..MaxReportColumns] OF BOOLEAN;

    ColumnAllowsNonResources : ARRAY [1..XTabBaseLineOffset] OF BOOLEAN;



    (* RealRatio (stolen from TLCaptions)

       Compute the ratio of A:B, taking into account that either or
       both might be zero.

       IF a=0 and b=0    ----> 0
          a = b          ----> 1
          b = 0          ----> infinity
          a = infinity   ----> infinity
          b = infinity   ----> 0
          else           ----> a/b

           When composing complex formulas involving
       division, you will get the most meaningful results if the terms
       with like units are paired, as in the formula for Proportional
       Percent Complete: (BCWP/BCWS) * (TimeCompleted/Duration).
           In this case, we compute a dollar ratio and a time ratio
       separately, then multiply them.  This permits us to compute the
       ratios as 1 in case both numerator and denominator are both
       zero (or infinity), in effect cancelling the zeros instead of
       propagating a zero or infinity.

     *)

PROCEDURE RealRatio ( A, B : REAL ) : REAL;
VAR
    C : REAL;
BEGIN
    IF (B = Zero) THEN             (* Ratio  A : 0  *)
        IF (A = Zero) THEN
            C := Zero;             (*        0  : 0  *)
        ELSE
            C := MaxReal;          (*        N  : 0  *)
        END;
    ELSIF (A >= MaxReal) THEN      (* Ratio Infinity : B *)
        IF (B >= MaxReal) THEN
            C := One;              (*        Infinity  : Infinity  *)
        ELSE
            C := MaxReal;          (*        Infinity  : B  *)
        END;
    ELSIF (B >= MaxReal) THEN      (* Ratio A : Infinity *)
        C := Zero;
    ELSE                           (* Ratio A : B *)
        C := A / B;
    END;
    RETURN C;
END RealRatio;



   (* Returns the maximum rate of resource availability in the period.
      If Resource = NIL, the sum of all resource availabilities is
      returned. *)

PROCEDURE AverageLimit( Resource            : AResourcePointer;
                        IsBaseline          : BOOLEAN;
                        StartDate, EndDate  : ADate) : REAL;
VAR
    Rate                        : AnAvailabilityRate;
    IntervalStart, IntervalEnd  : ADate;
    Index                       : ADateListIndex;
    TotalAmount                 : LONGINT;
    BStartDate, BEndDate,
    BRateStart, BRateEnd        : ABigTime;
    AvailsList                  : ADateList;

BEGIN

    TotalAmount := 0L;

    IF (StartDate = EndDate) THEN
        RETURN Zero;
    END;

    (* Which availability list do we use? *)
    IF IsBaseline THEN
        AvailsList := Resource^.BaselineAvailability;
    ELSE
        AvailsList := Resource^.Availability;
    END;

    (* Take a weighted average of each 'availability interval' in the period *)

    (* First, convert Start/End dates to BigTimes and find the index to the  *)
    (*  correct AvailabilityRate                                             *)

    IF (AvailsList = ADateList(NIL)) THEN
        TotalAmount := LongOneHundred
                       * VAL(LONGINT, FindDuration( StartDate, EndDate, TimeSheet));
    ELSE
        TimesToBigTimes(StartDate, EndDate, BStartDate, BEndDate);
        LocateDateInDateList( AvailsList, BStartDate,
                              TSIZE(AnAvailabilityRate), Index);

    (* Now, sum up the availabilities weighted by duration of each interval  *)

        WHILE GetDateListEntry( AvailsList, Index, BRateStart, BRateEnd, Rate)
        AND   (CompareBigTimes(BRateStart, BEndDate) < 0) DO
            IntervalStart := BigTimeToCalendarTime(BRateStart);
            IntervalEnd   := BigTimeToCalendarTime(BRateEnd  );
            TotalAmount := TotalAmount + 
                           (VAL(LONGINT, Rate.Amount) * VAL(LONGINT, Rate.Percent))
                           * VAL(LONGINT, DurationInPeriod( StartDate, EndDate,
                                                        IntervalStart, IntervalEnd));
            INC(Index);
        END;
    END;

    RETURN LongToReal(TotalAmount)/FLOAT(FindDuration(StartDate, EndDate, TimeSheet));

END AverageLimit;

PROCEDURE AddAverageLimits( VAR ResourceNode : ATreeNode;
                            Context          : ADDRESS    );
VAR
    ContextPtr  : POINTER TO AResourceLimitContext;
    Resource    : AResourcePointer;
BEGIN
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF (Resource^.Type = Employable) AND
       (Selected IN  ResourceFiltersPassed(ResourceNode)) THEN
        ContextPtr := Context;
        WITH ContextPtr^ DO
            Total := Total 
                     + 
                     AverageLimit
                        (Resource, IsBaseline, PeriodStart, PeriodEnd);
        END;
    END;
END AddAverageLimits;

PROCEDURE ResourceAverageLimitInPeriod( Resource        : AResourcePointer;
                                        ItIsBaseline    : BOOLEAN;
                                        StartDate, EndDate  : ADate
                                      ) : REAL;
VAR
    LReal       : REAL;
    ThisContext : AResourceLimitContext;

BEGIN

    IF (Resource <> NIL) THEN
        LReal := AverageLimit(Resource, ItIsBaseline, StartDate, EndDate);
        IF (LReal < AlmostZero) THEN
            RETURN Zero;
        ELSE
            RETURN LReal;
        END;
    ELSE
        WITH ThisContext DO
            Total       := Zero;
            IsBaseline  := ItIsBaseline;
            PeriodStart := StartDate;
            PeriodEnd   := EndDate;

            ResourceTree^.Methods^.TraverseTree(ResourceTree,
                                                ParentBeforeChild,
                                                9999,
                                                AddAverageLimits,
                                                ADR(ThisContext) );
            IF (Total < AlmostZero) THEN
                Total := Zero;
            END;
            RETURN Total;
        END;
    END;
END  ResourceAverageLimitInPeriod;







 (* Column Data - Given a node, return a single data item.

        Preconditions  - Accumulation     is the data record for ACTUAL
                         BaseAccumulation is the data record for BASELINE
                         Column is the column number, one of the constants
                                   defined above.
                         ColumnEle is the element in the columns array,
                                        for keeping sums.
                         ID     is the COLUMN ID (1-n, computed by me) for
                                   keeping sums.
                         Width  is the maximum width of the resulting
                                   (string) field.
                         ResourcesOnly is TRUE iff you only care about resources.
                         StartDate and EndDate are the period we are examining,
                            for use by NormalizeByTime.

                         SummaryTask is TRUE iff task is a summary.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData ( VAR Accumulation,
                           BaseAccumulation : AnAccumulationRecord;
                           Column,
                           ColumnEle,
                           ID,
                           Width            : CARDINAL; (* for strings only. *)
                           ResourcesOnly,
                           SummaryTask      : BOOLEAN;
                           StartDate,
                           EndDate          : ADate;
                       VAR DataType         : CARDINAL;
                       VAR TheData          : AnIntDataRecord;
                       VAR DataItemExists   : BOOLEAN );
VAR
    Totals      : ASingleAccumulation;
    IsBaseline  : BOOLEAN; (* 23-May-91 TGS *)


        (*  The "R" here is now declared as a VAR so we can just replace it
            with whatever the running total is at this point, after adding
            its original value in.       *)

    PROCEDURE SummData( VAR  R : REAL );
    VAR
        WhichEle,
        WhichGroup,
        i           : CARDINAL;
        ColSumArray : AColSumArray;
    BEGIN
        WITH Interface^ DO
            IF (TotalByY <> None) THEN
                RowSum[ ColumnEle ] := RowSum[ ColumnEle ] + R;
                IF (TotalByY = Running) THEN        (* 7/25/89 EGK *)
                    R := RowSum[ColumnEle];
                END;
            END;
            IF ((TotalByX <> None) AND SummaryTask) THEN
                ColSumIncluded[ ColumnEle ] := TRUE;
                WhichGroup := ((ID + MaxColRecords - 1) DIV MaxColRecords);
                WhichEle   := ((ID + MaxColRecords - 1) MOD MaxColRecords) + 1;     (* 2/23/89 EGK *)
                IF (WhichGroup <= MaxColGroupsInRow) THEN
                    IF (ColSum[ ColumnEle, WhichGroup ] <> AnExtHandle(NIL)) THEN
                        i := LockObjectArray( ColSum[ ColumnEle, WhichGroup ],
                                              ColSumArray, SIZE(R) );
                        IF (i = 0) THEN
                            FatalError();           (* 2/23/89 EGK *)
                        END;
                        ColSumArray^[ WhichEle ] := ColSumArray^[ WhichEle ] + R;
                        ReleaseObject( ColSum[ ColumnEle, WhichGroup ] );
                    END;
                END;
                IF (TotalByY <> None) THEN
                    GrandSumm[ ColumnEle ] := GrandSumm[ ColumnEle ] + R;
                END;
            END;
        END;
    END SummData;


    PROCEDURE WorkUnits( BaseColumn : CARDINAL; Qty : REAL ) : REAL;
    VAR
        Real  : REAL;
        Units : ADurationUnit;
    BEGIN
        Units := VAL(ADurationUnit,(Column - BaseColumn)+1);
        Real  := WorkHoursToRealTime( Qty, Units );
        RETURN Real;
    END WorkUnits;


    (* Make up totals based on wether they want resources only or resources
       and costs.  Some things are unique to resources, like TotalMaxRate.
    *)

    PROCEDURE MakeMasterAccumulator( VAR DataDoesExist : BOOLEAN );
    VAR
        Accumulator     : POINTER TO AnAccumulationRecord;
        Limit,
        r               : AResourceKind;
    BEGIN
        IF (Column < XTabFirstBaseCol) THEN
            Accumulator := ADR( Accumulation );
            IsBaseline  := FALSE;
        ELSE
            Accumulator := ADR( BaseAccumulation );
            IsBaseline  := TRUE;
        END;

        Limit := Rsrc;
        IF ((NOT ResourcesOnly) AND
             ColumnAllowsNonResources[ ((Column-1) MOD XTabBaseLineOffset)+1 ]) THEN
            Limit := VarCost;
        END;
        WITH Totals DO
            SpentDollars    := Zero;
            ToGoDollars     := Zero;
            SpentOTDollars  := Zero;
            ToGoOTDollars   := Zero;
            RealDoneOTHours := Zero;
            RealToGoOTHours := Zero;
            TotalMaxRate := Accumulator^[ Rsrc ].TotalMaxRate;
            DataExists   := FALSE;
            WITH Assignment DO  (* NOTE THAT WE DON'T ROLL UP ALL FIELDS! *)
                Resource        := Accumulator^[Rsrc].Assignment.Resource;
                Attributes      := AnAssignmentAttributeSet{};
                ActualQuantity  := Zero;
                YetToGoQuantity := Zero;
                OvertimeHours   := 0L;
                YetToGoOvertimeHours := 0L;
                ExtraCosts      := Zero;
            END;

            FOR r := Rsrc TO Limit DO
                IF (Accumulator^[ r ].DataExists) THEN
                    SpentDollars    := SpentDollars     + Accumulator^[ r ].SpentDollars;
                    ToGoDollars     := ToGoDollars      + Accumulator^[ r ].ToGoDollars;
                    SpentOTDollars  := SpentOTDollars   + Accumulator^[ r ].SpentOTDollars;
                    ToGoOTDollars   := ToGoOTDollars    + Accumulator^[ r ].ToGoOTDollars;
                    RealDoneOTHours := RealDoneOTHours  + Accumulator^[ r ].RealDoneOTHours;
                    RealToGoOTHours := RealToGoOTHours  + Accumulator^[ r ].RealToGoOTHours;
                    DataExists   := TRUE;
                    WITH Assignment DO
                        Attributes      := Attributes       + Accumulator^[ r ].Assignment.Attributes;
                        ActualQuantity  := ActualQuantity   + Accumulator^[ r ].Assignment.ActualQuantity;
                        YetToGoQuantity := YetToGoQuantity  + Accumulator^[ r ].Assignment.YetToGoQuantity;
                        OvertimeHours   := OvertimeHours    + Accumulator^[ r ].Assignment.OvertimeHours;
                        YetToGoOvertimeHours := YetToGoOvertimeHours + Accumulator^[ r ].Assignment.YetToGoOvertimeHours;
                        ExtraCosts      := ExtraCosts       + Accumulator^[ r ].Assignment.ExtraCosts;
                    END;
                END;
            END;
            DataDoesExist := Totals.DataExists; (* Tell our caller. *)
        END;
    END MakeMasterAccumulator;



BEGIN
    WITH Interface^ DO
        TheData.Font       := 0C; (* Default Font *)
        TheData.LString[0] := 0C;
        DataType           := RealNumberType;

        MakeMasterAccumulator( DataItemExists );
        Column := ((Column-1) MOD XTabBaseLineOffset) + 1;

        (*  Pretend that data exists so we can get running totals. *)

        IF (TotalByY = Running) THEN
            DataItemExists := TRUE;
        END;

        IF ((NOT DataItemExists) AND (Column <> XTabDataExists)) THEN
            RETURN;
        END;

        WITH TheData    DO
        WITH Totals     DO
        WITH Assignment DO
            CASE Column OF
              XTabQuantity      :
                Real := ActualQuantity + YetToGoQuantity;

            | XTabBillable      :
                Boolean := (Billable IN Attributes);
                GetMessageWord( PModuleNumber + 3, ORD(Boolean), LString );
                (* "No,Yes" *)
                DataType := BooleanType;

            | XTabSpentQuantity :
                Real := ActualQuantity;

            | XTabYTGQuantity   :
                Real := YetToGoQuantity;

            | XTabTotalDollars  :
                Real := SpentDollars + ToGoDollars
                        + ExtraCosts;

            | XTabSpentDollars  :
                Real := SpentDollars + ExtraCosts;

            | XTabYTGDollars    :
                Real := ToGoDollars;

            | XTabPercentAss    :
                Real := TotalMaxRate;

                (*  These next few columns rely on knowing the order of
                    a Time Unit as Minutes,Hours,Days,Weeks.
                *)

            | XTabTWorkHours..XTabTWorkWeeks :
                Real := WorkUnits( XTabTWorkHours, ActualQuantity
                                                + YetToGoQuantity );

                (*  Kludge in progress!  XTabTWorkHrsPerMax is used here so
                    that WorkUnits will think we are dealing with hours.
                *)

            | XTabTWorkHrsPerMax :

                    (*  If the resource limit is zero for the period, just
                        let the real value be zero, not infinity.
                        EGK 8/27/91
                    *)

                Real := ResourceAverageLimitInPeriod
                                (Resource, IsBaseline, StartDate, EndDate);
                IF (Real <> Zero) THEN
                    Real := RealRatio (
                              (WorkUnits( XTabTWorkHrsPerMax,
                                          ActualQuantity + YetToGoQuantity )
                                        * OneHundred),
                              Real );
                END;

            | XTabAWorkHours..XTabAWorkWeeks :
                Real := WorkUnits( XTabAWorkHours, ActualQuantity );

            | XTabYWorkHours..XTabYWorkWeeks :
                Real := WorkUnits( XTabYWorkHours, YetToGoQuantity );

            | XTabDataExists            :
                Boolean := DataExists;
                GetMessageWord( PModuleNumber + 3, ORD(Boolean), LString );
                    (* "No,Yes" *)
                DataType   := BooleanType;
                DataItemExists := TRUE; (* Se we print this *)
            | XTabExtraDollars :
                Real := ExtraCosts;
            (* 21-May-91 TGS
            | XTabTOTWorkHours :
                Real := RealDoneOTHours + RealToGoOTHours;
            | XTabAOTWorkHours :
                Real := RealDoneOTHours;
            | XTabYOTWorkHours :
                Real := RealToGoOTHours;
            | XTabTotalOTDollars :
                Real := SpentOTDollars + ToGoOTDollars;
            | XTabSpentOTDollars :
                Real := SpentOTDollars; 
            | XTabYToGoOTDollars :
                Real := ToGoOTDollars; 
            | XTabTotalEffortDollars :
                Real := SpentDollars + ToGoDollars;
            | XTabSpentEffortDollars :
                Real := SpentDollars;
            | XTabToGoEffortDollars :
                Real := ToGoDollars;
            *)
            ELSE
                FatalError();
            END;
        END;  (* WITH Assignment *)
        END;  (* WITH Totals     *)
        END;  (* WITH TheData    *)

        (* RSC 11/9/88 Normalize and then summ totals, so that the sum becomes
                       the sum of the normalized numbers.
        *)
        WITH TheData DO
            IF (DataItemExists) THEN
                IF (Normalize) THEN
                    NormalizeByTime( DataType, TheData, StartDate, EndDate );
                END;
                IF (DataType = RealNumberType) THEN
                    SummData( Real );
                END;
            END;
        END;
    END;

END ColumnData;




PROCEDURE NormalizeByTime   (     Type          : ADataType;
                              VAR Data          : AnIntDataRecord;
                                  StartDate     : ADate;
                                  EndDate       : ADate             );
VAR
    HoursInPeriod       : REAL;
    r                   : REAL;

    PROCEDURE SGN ( i   : INTEGER   ) : INTEGER;
    BEGIN
        IF (i < 0) THEN
            RETURN -1;
        ELSIF (i > 0) THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END;
    END SGN;


BEGIN
    IF (StartDate >= EndDate) THEN
        RETURN;
    END;

    HoursInPeriod := DurationToReal
                     (
                        FindDuration
                        (
                            StartDate, 
                            EndDate, 
                            TimeSheet 
                         )
                     ) / FSMUPH;
    IF (HoursInPeriod = Zero) THEN
        RETURN;                     (* I'm paranoid *)
    END;

    CASE Type OF
        RealNumberType :
            Data.Real := Data.Real / HoursInPeriod;

    |   IntegerType :
            r := FLOAT(Data.Integer) / HoursInPeriod;
            Data.Integer := SGN(Data.Integer) * INTEGER(TRUNC(r + 0.5));

    |   CardinalType :
            r := FLOAT(Data.Cardinal) / HoursInPeriod;
            Data.Integer := TRUNC(r + 0.5);
    ELSE                (* KKC - Jun 22, 1989 *)
    END;
END NormalizeByTime;





 (* Generate One Data Item - Generate One Row/Column intersection.

        Given the row and column data points, generate all the desired
        columns of data for this one point.

        Preconditions  - Column ID  is the same as the resource ID or Time ID
                                    from the header records.  It is the unique
                                    column number (1..n) for this column.
                         First Time is the 'do we initialize' flag.
                         Dont Care  is 'Do We Examine Resource Node or NOT?'
                         Row Is A Summary is 'Is the row record a summary item or not?'
                         Task Node  is the task node for this data.
                         Rsrc Node  is the (optional) resource node.  It is ignored and may be
                                    NIL iff 'DontCare' is TRUE.
                         Start Date is the starting date of the period, or 0 for 'start of time'
                         End Date   is the end of the period, or MAXDATE.

        Postconditions - One data item per column in effect has been written
                         to the interpass file.
 *)
PROCEDURE GenerateOneDataItem( VAR ColumnID       : CARDINAL;
                                   RowIsLevel0    : BOOLEAN;
                                   TaskNode,
                                   RsrcNode       : ATreeNode;
                                   StartDate,
                                   EndDate        : ADate;
                                   PeriodType     : APeriodType;
                               VAR AggregateFont  : CHAR );
VAR
    TaskPtr             : ATaskPtr;
    DataType,
    Loop                : CARDINAL;
    BaseAccumulation,
    Accumulation        : AnAccumulationRecord;
    DataRecord          : AnIntDataRecord;
    PeriodStartDate,
    PeriodEndDate       : ADate;
    DataItemExists,
    HighlightData       : BOOLEAN;
    LocalFont           : CHAR;
BEGIN
    TaskPtr       := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    HighlightData := (TaskPtr^.FilterSet *
                  ATaskFilterSet{Highlight1..Highlight5}) <> ATaskFilterSet{};
    LocalFont     := 0C;
    IF (HighlightData) THEN
        LocalFont     := 1C;
        AggregateFont := 201C;
    END;
    IF (ColumnID >= XTabFirstBaseCol) THEN
        PeriodStartDate := TaskPtr^.BaseLine.Dates.EarlyStart;
        PeriodEndDate   := TaskPtr^.BaseLine.Dates.EarlyEnd;
    ELSE
        PeriodStartDate := TaskPtr^.Plan.Dates.EarlyStart;
        PeriodEndDate   := TaskPtr^.Plan.Dates.EarlyEnd;
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    WITH Interface^ DO
        IF (PReportType <> TvsR) THEN
            PeriodStartDate := StartDate;
            PeriodEndDate   := EndDate;
        END;
        IF (PNeedActualAssignment) THEN
            RollupResource( TaskNode,  RsrcNode,
                            StartDate, EndDate,
                            TRUE,  (* Rollup Kids? *)
                            FALSE, (* Baseline? *)
                            TRUE,  (* First Time? *)
                            CostTracking,
                            PeriodType,
                            Accumulation );
        END;

        IF (PNeedBaseAssignment) THEN
            RollupResource( TaskNode,  RsrcNode,
                            StartDate, EndDate,
                            TRUE,  (* Rollup Kids? *)
                            TRUE,  (* Baseline? *)
                            TRUE,  (* First Time? *)
                            CostTracking,
                            PeriodType,
                            BaseAccumulation );
        END;

        INC(ColumnID);

        FOR Loop := 1 TO MaxReportColumns DO
            IF (Columns^[ Loop ].Width > 0) THEN
                ColumnData( Accumulation,
                            BaseAccumulation,
                            Columns^[ Loop ].ColumnNumber,
                            Loop,
                            ColumnID,
                            Columns^[ Loop ].Width,
                            ResourcesOnly,
                            RowIsLevel0,
                            PeriodStartDate,
                            PeriodEndDate,
                            DataType,
                            DataRecord,
                            DataItemExists );
                DataRecord.Font := LocalFont;
                IF (DataItemExists) THEN
                    WriteIntData( DataType, DataRecord );
                ELSE
                    WriteIntData( SkipRecordType, DataRecord );
                END;
            END;
        END;
    END;
END GenerateOneDataItem;






 (* GenerateOneResource - create the data records for one resource.

        Preconditions  - A valid task and resource node
        Postconditions - one or more data records have been written to the file.

   NOTE: IT IS ASSUMED THAT THIS IS A COLUMN DATA PROCEDURE, NOT A ROW DATA
         PROCEDURE, AND THE ROW MUST BE A TASK NODE!!
 *)
PROCEDURE GenerateOneResourcesData( VAR ResourceNode : ATreeNode;
                                        Context      : ADDRESS    );
VAR
    GenerateDataContext : AGenerateDataContextPtr;
    Resource            : AResourcePointer;
BEGIN
    WITH Interface^ DO
        Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
        IF (ResourcesOnly) THEN
            IF (Resource^.Type <> Employable) THEN
                RETURN;
            END;
        END;

        IF (NOT ( Selected IN  ResourceFiltersPassed(ResourceNode))) THEN
            RETURN;
        END;


        GenerateDataContext := Context;

        IF (BreakRequested()) THEN  (* RSC 2/24/88 *)
            RETURN;
        END;

        (* HERE WE ASS U ME THAT THE ROW NODE IS A TASK NODE! *)

        GenerateOneDataItem( GenerateDataContext^.ID,
                             GenerateDataContext^.RowIsLevel0,
                             GenerateDataContext^.RowNode,  (* The Task node *)
                             ResourceNode,
                             Interface^.TheStartDate, Interface^.TheEndDate,
                             FinalPeriod,
                             GenerateDataContext^.AggregateFont );    (* Dates *)
    END;
END GenerateOneResourcesData;




 (* Generate xxxx Data - Generate the data records for one ROW.

        Preconditions  - GenerateDataContext has the row node in it.

        Postconditions - One record has been generated for each column in
                         the report, not including row aggregates.
 *)
PROCEDURE GenerateResourceData( VAR GenerateDataContext : AGenerateDataContext;
                                VAR TotalThisRow        : BOOLEAN    );
BEGIN
    TotalThisRow := TRUE;
    ResourceTree^.Methods^.TraverseTree( ResourceTree,
                                         ParentBeforeChild,
                                         9999,
                                         GenerateOneResourcesData,
                                         ADR(GenerateDataContext));
END GenerateResourceData;




PROCEDURE GenerateTimeForTaskData( VAR GenerateDataContext : AGenerateDataContext;
                                   VAR TotalThisRow        : BOOLEAN    );
VAR
    Loop      : ADate;
    NextLoop  : ADate;
    PeriodType : APeriodType;
BEGIN
    TotalThisRow := TRUE;
    WITH Interface^ DO
        (*IF (TheStartDate > TheEndDate) THEN RETURN; END;*)      (* AJL 3/3/88 *)
        Loop      := TheStartDate;
        NextLoop  := Loop;
        REPEAT                                                (* AJL 3/3/88 *)
            NextLoop := FindNextKeyDate( Loop, Period );
            IF (NextLoop >= TheEndDate) THEN
                PeriodType := FinalPeriod;
                NextLoop := TheEndDate;
            ELSE
                PeriodType := NormalPeriod;
            END;

            IF (BreakRequested()) THEN  (* RSC 2/24/88 *)
                RETURN;
            END;

        (* HERE WE ASS U ME THAT THE ROW NODE IS A TASK NODE! *)

            GenerateOneDataItem( GenerateDataContext.ID,
                                 GenerateDataContext.RowIsLevel0,
                                 GenerateDataContext.RowNode,  (* The Task node *)
                                 NIL,                          (* No resource node! *)
                                 Loop,                         (* Start Date *)
                                 NextLoop,                     (* End Date   *)
                                 PeriodType,
                                 GenerateDataContext.AggregateFont );
            Loop := NextLoop;
        UNTIL (Loop >= TheEndDate);           (* AJL 3/3/88 *)
    END;
END GenerateTimeForTaskData;




PROCEDURE GenerateTimeForRsrcData( VAR GenerateDataContext : AGenerateDataContext;
                                   VAR TotalThisRow        : BOOLEAN    );
VAR
    Loop                : ADate;
    NextLoop            : ADate;
    DataType,
    Loop2               : CARDINAL;
    ResourceNode,
    TaskNode            : ATreeNode;
    Resource            : AResourcePointer;
    DataRecord          : AnIntDataRecord;
    BaseAccumulation,
    Accumulation        : AnAccumulationRecord;
    FirstTime           : BOOLEAN;
    DataItemExists      : BOOLEAN;
    PeriodType          : APeriodType;
    Scale               : ADuration;

BEGIN
    TotalThisRow := TRUE;
    WITH Interface^ DO
        (*IF (TheStartDate > TheEndDate) THEN RETURN; END;*)
        ResourceNode := GenerateDataContext.RowNode;  (* The Rsrc node *)
        Resource     := ResourceNode^.Methods^.GetDataObject( ResourceNode );
        IF (ResourcesOnly) THEN
            IF (Resource^.Type <> Employable) THEN
                TotalThisRow := FALSE;
                RETURN;
            END;
        END;
        IF (NOT ( Selected IN  ResourceFiltersPassed(ResourceNode))) THEN
            TotalThisRow := FALSE;
            RETURN;
        END;

        Loop      := TheStartDate;
        NextLoop  := Loop;
        REPEAT
            IF (ClientUse = Histogram) THEN (* 24-Jan-92 TGS *)
                Scale := UpScale(1, Period);
                INC(NextLoop, Scale);
            ELSE
                NextLoop := FindNextKeyDate( Loop, Period );
            END;
            IF (NextLoop >= TheEndDate) THEN
                NextLoop := TheEndDate;
                PeriodType := FinalPeriod;
            ELSE
                PeriodType := NormalPeriod;
            END;

        (* HERE WE ASS U ME THAT THE ROW NODE IS A RESOURCE NODE! *)

            FirstTime := TRUE;
            TaskNode  := TaskTree^.Methods^.GetFirst( TaskTree );

            WHILE (TaskNode <> NIL) DO                                  (* AJL 3/3/88 *)

                IF (BreakRequested()) THEN  (* RSC 2/24/88 *)
                    RETURN;
                END;

                IF (TaskNode^.Methods^.Visible(TaskNode)) THEN

                    IF (PNeedActualAssignment) THEN
                        RollupResource( TaskNode,  ResourceNode,
                                        Loop, NextLoop,  (* Dates *)
                                        FALSE, (* Rollup Kids? *)
                                        FALSE, (* Baseline? *)
                                        FirstTime,
                                        CostTracking,
                                        PeriodType,
                                        Accumulation );
                    END;

                    IF (PNeedBaseAssignment) THEN
                        RollupResource( TaskNode,  ResourceNode,
                                        Loop, NextLoop,  (* Dates *)
                                        FALSE, (* Rollup Kids? *)
                                        TRUE,  (* Baseline?  *)
                                        FirstTime,
                                        CostTracking,
                                        PeriodType,
                                        BaseAccumulation );
                    END;
                    FirstTime := FALSE;
                END;  (* If visible *)

                TaskNode  := TaskNode^.Methods^.NextPreOrder( TaskNode );
            END;

            DataRecord.Font := 0C;          (* 4/14/88 EGK *)
            IF (NOT FirstTime) THEN (* If we found ANY data points .... *)
                WITH GenerateDataContext DO
                    INC(ID);
                    FOR Loop2 := 1 TO MaxReportColumns DO
                        IF (Columns^[ Loop2 ].Width > 0) THEN
                            ColumnData( Accumulation,
                                        BaseAccumulation,
                                        Columns^[ Loop2 ].ColumnNumber,
                                        Loop2,
                                        ID,
                                        Columns^[ Loop2 ].Width,
                                        ResourcesOnly,
                                        RowIsLevel0,
                                        Loop,
                                        NextLoop,
                                        DataType,
                                        DataRecord,
                                        DataItemExists );
                            IF (DataItemExists) THEN
                                WriteIntData( DataType, DataRecord );
                            ELSE
                                WriteIntData( SkipRecordType, DataRecord );
                            END;
                        END;
                    END;
                END;
            ELSE
                WriteIntData( SkipRecordType, DataRecord );
            END;
            Loop := NextLoop;
        UNTIL (Loop >= TheEndDate);                                     (* AJL 3/3/88 *)
    END;
END GenerateTimeForRsrcData;






PROCEDURE DoTheWork();
VAR
    Loop,
    SumLoop,
    TotalColsInReport : CARDINAL;
    Copyright         : ARRAY[0..50] OF CHAR;


    PROCEDURE DoHeaders( VAR ColsInReport : CARDINAL );
    VAR
        MaxGroups,
        LastEle,
        Loop,
        Loop2,
        i,
        Size,
        Rows,
        Cols        : CARDINAL;
        ColSumArray : AColSumArray;
        ok          : BOOLEAN;
        s           : ARRAY [0..255] OF CHAR;
    BEGIN
        WITH Interface^ DO
            SetResourcesOnly( ResourcesOnly );
            CASE PReportType OF
              TvsR : 
                Rows := TaskHeaders( PModuleNumber, 1, (TotalByX = AtEnd) );
                Cols := RsrcHeaders( PModuleNumber, 2, (TotalByY = AtEnd),FALSE );         (* 22-Sep-89 MWP *)
            | TvsT :
                Rows := TaskHeaders( PModuleNumber, 1, (TotalByX = AtEnd) );
                Cols := TimeHeaders( PModuleNumber, 2, (TotalByY = AtEnd),
                                     FALSE, Period, TheStartDate, TheEndDate );
            | RvsT :
                Rows := RsrcHeaders( PModuleNumber, 1, (TotalByX = AtEnd), FALSE );        (* 22-Sep-89 MWP *)
                (* 24-Jan-92 TGS generate histogram headers differently *)
                Cols := TimeHeaders( PModuleNumber, 2, (TotalByY = AtEnd),
                                     (ClientUse = Histogram), 
                                     Period, TheStartDate, TheEndDate );
            ELSE
                FatalError();
            END;

            IF (CheckIO( InterFile ) <> done) THEN RETURN; END;
(*
            s[0] := 0C;
*)
            GetMessage ( ModuleNumber + 1, s );                   (* 5-Sep-89 MWP *)
            ok   := CreateThermometer( Thermometer, 0, 0, s, Rows );

            (* Generate an EMS area to hold aggregates, if any.
            *)

            ColsInReport := Cols;           (* Total calls... *)
            IF (TotalByY = AtEnd) THEN
                DEC(Cols);     (* Cols included totals column *)
            END;
            IF (Cols >  MaxColRecords) THEN (* Total we can handle. *)
                Cols := MaxColRecords;
            END;

            IF (TotalByX = AtEnd) THEN
                FOR Loop := 1 TO MaxReportColumns DO

                    MaxGroups := ((Cols + MaxColRecords - 1) DIV MaxColRecords);        (* 2/23/89 EGK *)
                    LastEle   := ((Cols + MaxColRecords - 1) MOD MaxColRecords) + 1;
                    IF (MaxGroups >  MaxColGroupsInRow) THEN
                        MaxGroups := MaxColGroupsInRow;
                        LastEle   := MaxColRecords;
                    END;

                    FOR SumLoop := 1 TO MaxGroups DO

                        Size := MaxColRecords;
                        IF SumLoop = MaxGroups THEN
                            Size := LastEle;
                        END;

                        IF (CreateExtObjectWithSize( ColSum[ Loop, SumLoop ],
                                                     ExtSlow,
                                                     Size * TSIZE(REAL) )) THEN
                            i := LockObjectArray( ColSum[ Loop, SumLoop ],
                                                  ColSumArray, TSIZE(REAL) );
                            IF (i <> Size) THEN FatalError(); END;
                            FOR Loop2 := 1 TO Size DO
                                ColSumArray^[Loop2] := Zero;
                            END;
                            ReleaseObject( ColSum[ Loop, SumLoop ] );
                        ELSE
                            ColSum[ Loop, SumLoop ] := AnExtHandle(NIL);
                        END;
                    END;

                END;
            END;
        END;
    END DoHeaders;


    PROCEDURE DoData( ColsInReport : CARDINAL );
     (*A+*)
    VAR
        TotalSumsOutput,
        Count,
        i,
        Loop,
        Loop2               : CARDINAL;
        Node                : ATreeNode;
        ColSumArray         : AColSumArray;
        DataRecord          : AnIntDataRecord;
        R                   : REAL;
        GenerateData        : AGenerateDataProc;
        GenerateDataContext : AGenerateDataContext;
        TotalThisRow        : BOOLEAN;
     (*A=*)

    BEGIN
        WITH Interface^ DO
            (* Generate the data section of the file. *)

            StartSubfileOutput( InterFile, PredicateSubfileNumber + 3, VersionNumber );
            IF (CheckIO( InterFile ) <> done) THEN RETURN; END;

            (* The following code is not super-generalized.  It assumes that the
               rows are some sort of Tree Nodes and the columns are an
               intersection of the Tree Node and some other related data.
            *)
            CASE PReportType OF
               TvsR : Node         := TaskTree^.Methods^.GetFirstVisible( TaskTree );
                      GenerateData := GenerateResourceData;
             | TvsT : Node         := TaskTree^.Methods^.GetFirstVisible( TaskTree );
                      GenerateData := GenerateTimeForTaskData;
             | RvsT : Node         := ResourceTree^.Methods^.GetFirstVisible( ResourceTree );
                      GenerateData := GenerateTimeForRsrcData;
            ELSE
                FatalError();
            END;

            Count := 0; (* # of rows output *)
            WHILE (Node <> NIL) DO

                IF (TotalByY <> None) THEN
                    FOR i := 1 TO MaxReportColumns DO
                        RowSum[ i ] := Zero;
                    END;
                END;
                WITH GenerateDataContext DO
                    ID             := 0;
                    RowNode        := Node;
                    RowIsLevel0    := (Node^.Methods^.IndentationLevel( Node ) = 0);
                    AggregateFont  := 200C;
                END;

                INC(Count);
                UpdateThermometer( Thermometer, Count );

                GenerateData( GenerateDataContext, TotalThisRow ); (* Generate the row's data *)

                IF (BreakRequested()) THEN  (* RSC 2/24/88 *)
                    RETURN;
                END;

                (* Output row totals? *)

                IF ((TotalByY = AtEnd) AND TotalThisRow) THEN
                    FOR i := 1 TO MaxReportColumns DO
                        WITH DataRecord DO (* Totals by row.  ALL predicates must be numeric! *)
                            Font     := GenerateDataContext.AggregateFont; (* AGGREGATE *)
                            Real     := RowSum[ i ];
                        END;
                        WriteIntData( RealNumberType, DataRecord );
                    END;
                END;

                Node := Node^.Methods^.NextForDisplay( Node );
            END;

            (* Output column totals? *)

            IF (TotalByX = AtEnd) THEN
                FOR Loop := 1 TO MaxReportColumns DO

                    INC(Count);
                    UpdateThermometer( Thermometer, Count );

                    DataRecord.Font := 200C;    (* AGGREGATE *)

                    TotalSumsOutput := 0;
                    FOR SumLoop := 1 TO MaxColGroupsInRow DO
                        IF (ColSum[ Loop, SumLoop ] <> AnExtHandle(NIL)) THEN
                            i := LockObjectArray( ColSum[ Loop, SumLoop ], ColSumArray, SIZE(R) );
                            INC(TotalSumsOutput, i);
                            FOR Loop2 := 1 TO i DO
                                IF (ColSumIncluded[ Loop ]) THEN
                                    WITH DataRecord DO (* Totals by row.  ALL predicates must be numeric! *)
                                        Real     := ColSumArray^[ Loop2 ];
                                    END;
                                    WriteIntData( RealNumberType, DataRecord );
                                ELSE
                                    WriteIntData ( SkipRecordType, DataRecord );        (* 7/11/88 EGK *)
                                END;
                            END;
                            ReleaseUnchangedObject( ColSum[ Loop, SumLoop ] );
                        END;
                    END;

                    (* If there were more cols than we could total up,
                       make the remainders 'skip' columns.
                       Remember that 'ColsInReport' may include the
                       summary column, so maybe skip that one.
                    *)
                    FOR Loop2 := (TotalSumsOutput+1) TO (ColsInReport - ORD(TotalByY = AtEnd)) DO
                        IF (ColSumIncluded[ Loop ]) THEN
                            WriteIntData( SkipRecordType, DataRecord );
                        ELSE
                            WriteIntData ( SkipRecordType, DataRecord );
                        END;
                    END;

                END;
            END;

            IF (BreakRequested()) THEN    (* RSC 2/24/88 *)
                RETURN;
            END;

            (* Grand Total? *)

            IF ((TotalByX = AtEnd) AND (TotalByY = AtEnd)) THEN
                FOR Loop := 1 TO MaxReportColumns DO
                    WITH DataRecord DO (* Totals of col info. *)
                        Font     := 200C; (* AGGREGATE *)
                        Real     := GrandSumm[ Loop ];
                    END;
                    WriteIntData( RealNumberType, DataRecord );
                END;
            END;

            IF (CheckIO( InterFile ) = done) THEN
                EndSubfileOutput( InterFile, PredicateSubfileNumber + 3 );
            END;
        END;
    END DoData;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    FOR Loop := 1 TO MaxReportColumns DO
        FOR SumLoop := 1 TO MaxColGroupsInRow DO
            ColSum[     Loop, SumLoop ] := AnExtHandle(NIL); (* EMS handles *)
        END;
        GrandSumm[      Loop ] := Zero; (* Master accumulators for SUMM aggregates *)
        RowSum[         Loop ] := Zero;
        ColSumIncluded[ Loop ] := FALSE;
    END;

    FOR Loop := 1 TO XTabBaseLineOffset DO
        ColumnAllowsNonResources[ Loop ] := TRUE;
        IF (Loop >= XTabTWorkHours) AND (Loop <= XTabYWorkWeeks) THEN
            ColumnAllowsNonResources[ Loop ] := FALSE;
        END;
    END;
    ColumnAllowsNonResources[ XTabPercentAss ] := FALSE;

    Thermometer := AThermometer(NIL);

    DoHeaders( TotalColsInReport );
    IF (CheckIO( InterFile ) = done) AND (NOT BreakRequested()) THEN  (* RSC 2/24/88 *)
        DoData( TotalColsInReport );
    END;
    FOR Loop := 1 TO MaxReportColumns DO
        FOR SumLoop := 1 TO MaxColGroupsInRow DO
            IF (ADDRESS(ColSum[ Loop, SumLoop ]) <> NIL) THEN (* Clean up EMS handles *)
                DiscardExtObject( ColSum[ Loop, SumLoop ] );
            END;
        END;
    END;

    DiscardThermometer ( Thermometer );

END DoTheWork;



BEGIN
    GlobalQuantityMonitor := {};

    Interface := OverlayContext();
    DoTheWork();

END TLCrWork.

