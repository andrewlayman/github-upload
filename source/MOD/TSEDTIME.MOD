IMPLEMENTATION MODULE TSEDTimescale;

(*  =========================================================================
    Last Edit : November 1, 1990 11:36AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        27-Jun-89 CMH   Modified axis height calculation for network diagrams 
        28-Jun-89 CMH   Modified axis width calculation for network diagrams 
         1-Aug-89 CMH   No longer buffer time frame on Gantt chart axis if
                        a date range was specified.
         3-Aug-89 CMH   Minimized space allocated for bar labels, was 
                        too much.
        11-Aug-89 CMH   More modifications pertaining to labels and axis 
                        length calculations.
        17-Aug-89 CMH   Increased minimum number of channels in the axis 
                        to allow two data column cap names.
        22-Aug-89 CMH   Use end date if phantom task. 
        25-Aug-89 CMH   Fixed weekly axis start date bug. 
        28-Aug-89 CMH   Removed debugging statements. 
         5-Sep-89 CMH   Moved UnitsForScaling, CharactersForScaling,
                        UnitsForGrouping and MilitaryTime to 
                        TimeUnitsTLGS.DEF from TSEDTimescale.DEF so 
                        TLNBUILD would not import from TSEDTimescale 
                        since it has 1.6k bytes of data.
         6-Sep-89 CMH   Moved GanttTimescaling,
                        GetDurationBarDates and FindGanttMaxMinDates
                        from TSEDTimescale to GanttTimescale.
                        Moved AddTimescaling, AddTimeScalingVert, 
                        FindMaxMinDates, FixMasterTaskCorners,
                        BeginCompressedAxis and EndCompressedAxis from
                        TSEDTimescale to PertTimescale.
         8-Sep-89 CMH   Using new WriteBoolean, WriteCardinal procedures.  
        21-Feb-90 KKC   Remove identifers in timeu which are not referenced.
        29-Jun-90 PHR   Write "UsingWeekNumbers" flag to calendar file,
                        so TLGS can correctly format dates on the axes.
						Also, write the week numbers data as needed to
						the file.
        26-Oct-90 PFG   Made Timeu to Timei/TimeForm conversions. Grouped 
                        year, month, day, hour, minute into one date 
                        structure, ATimeInfo.  
        31-Oct-90 RSC   StdDay is now in HalfHours, not Hours.
    =========================================================================
*)


FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  Close, Lookup, Delete, 
                                SetOpen, SetWrite,
                                WriteNBytes;
                                
FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSScale;   
                                 
FROM SYSTEM                 IMPORT 
    (* TYPE *)                  ADDRESS,
    (* PROC *)                   ADR, SIZE, TSIZE;
    
FROM Timei      	    IMPORT 
    (* TYPE *)                  ATimeInfo,
    (* PROC *)                  TimeUtoT; 

FROM Timeu      	    IMPORT 
     (* CONST *)                SMUPH,
     (* VAR *)                  TimeTable, AYearTable, WeeksBeginOn,
     (* PROC *)                 GetStartingMonth;
                                                                                                 
FROM TimeUnitsTLGS          IMPORT
    (* VAR *)                   UnitsForScaling;
    
FROM TSEDObjectWrite        IMPORT
    (* PROC *)                  WriteBoolean,
                                WriteCardinal;

FROM WeekNumberInfo         IMPORT						(* PHR 6/28/90 *)
    (* TYPES *)                 AWeekStartRecord,
    (* VARS *)                  UsingWeekNumbers, WeekStartTable;

(*--------------------------------------------------------------------------*)
        (*  
            GetAxisChannels
         *)
         
PROCEDURE GetAxisChannels() : CARDINAL;

VAR 
    NumberOfChannels : CARDINAL;
    
BEGIN
   
    CASE UnitsForScaling OF
         
         SHours, SDays, SWeeks: 
         NumberOfChannels:= 3;
       
    ELSE
    
      (* SMonths, SQuarters, SYears *)
         NumberOfChannels:= 2;
    
    END;   
    
    RETURN (NumberOfChannels);
    
END GetAxisChannels;


(*--------------------------------------------------------------------------*)
        (*  
            SaveCalendar
            
            Write the calendar to the TLGS interface file.
         *)

PROCEDURE SaveCalendar;

VAR
    f         : File;
    i, amount : CARDINAL;
    A         : ADDRESS;

BEGIN
    Delete('mcalfile.dat',f);
    Lookup(f,'mcalfile.dat',TRUE);
    SetWrite(f);
    WITH TimeTable DO
        WriteNBytes(f,ADR(FirstYear),SIZE(FirstYear),amount);
        WriteNBytes(f,ADR(SMUPH),SIZE(SMUPH),amount);
        WriteNBytes(f,ADR(StdDayTics),SIZE(StdDayTics),amount);
        WriteNBytes(f,ADR(StdWeek),SIZE(StdWeek),amount);
        WriteNBytes(f,ADR(WeekTable),SIZE(WeekTable),amount);
        i := 1;
        WHILE (i <= HIGH(YearTable)) DO
            A := ADR(YearTable[i]);
            WriteNBytes(f,A,TSIZE(AYearTable),amount);
            INC(i);
        END;
        WriteNBytes(f,ADR(UsingWeekNumbers),SIZE(UsingWeekNumbers),amount);
        WriteNBytes(f,ADR(WeeksBeginOn),SIZE(WeeksBeginOn),amount);
	GetStartingMonth(i);
	WriteNBytes(f,ADR(i),SIZE(i),amount);
    END;
    Close(f);

END SaveCalendar;


(*--------------------------------------------------------------------------*)
        (*  
            WriteScaleDates

            Write Min and Max Scaling Dates to TLGS interface file.
            Format:
             AXIS    -- class tag
             Min Year,Month,Day,Hour,Min -- Axis Start
             Max Year,Month,Day,Hour,Min -- Axis End
             x,y,x2,y2
             Chan1Type,Chan2Type,Chan3Type
            
         *)
         
PROCEDURE WriteScaleDates;
    
VAR 
    Chan1Type,
    Chan2Type,
    Chan3Type   : CARDINAL;
    TimeInfo    : ATimeInfo;

BEGIN

 (* write start date *)

    TimeUtoT (MinAxisDate,TimeInfo);
    WriteCardinal( TimeInfo.tiYear);
    WriteCardinal( TimeInfo.tiMonth);
    WriteCardinal( TimeInfo.tiDay);
    WriteCardinal( TimeInfo.tiHour);
    WriteCardinal( TimeInfo.tiMinute);

 (* write end date *)

    TimeUtoT (MaxAxisDate,TimeInfo);
    WriteCardinal(TimeInfo.tiYear);
    WriteCardinal(TimeInfo.tiMonth);
    WriteCardinal(TimeInfo.tiDay);
    WriteCardinal(TimeInfo.tiHour);
    WriteCardinal(TimeInfo.tiMinute);

 (* write position : x, y, x2, y2 *)
 
    WriteCardinal(AxisXorg);
    WriteCardinal(AxisYorg);
    WriteCardinal(AxisXorg+AxisLength);
    WriteCardinal(AxisYorg+AxisHeight);

(* write channel types *)
 
    Chan1Type:=1;
    Chan2Type:=3;
    Chan3Type:=5;
    WriteCardinal(Chan1Type);
    WriteCardinal(Chan2Type);
    WriteCardinal(Chan3Type);
          
END WriteScaleDates;
         

(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDTimescale *)

    
END TSEDTimescale.
