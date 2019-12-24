IMPLEMENTATION MODULE TimeConversions;

    (*  MODIFICATION HISTORY


            EGK 6/8/89 EGK  Changed ToNewScale to not return a "Dur" of
                            zero (layouts must have a nonzero scale).
            RSC 28-Sep-89   Made the "OldTimeTable" a HEAP item, not a
                            global data item.  This saves about 3600 bytes
                            from overlays that refer to it, causing them
                            to fit into the reserved layer (maybe).
            30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
            19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                            date structure, ATimeInfo. 
            16-Aug-90 RSC   Set OldTimeTable to NIL upon exit, as
                            DEALLOCATE didn't.
             1-Nov-90 RSC   Removed need for TimeTable internals.
             3-Nov-90 RSC   Ajust for 1/4 hour days.
            21-Nov-90 RSC   Convert Tics to minutes for comparisons between
                            OLD and NEW.
            10-June-91 RSC  Change calendar swapping to be based on global
                            memory, which doesn't require a ShutDown proc.
            24-Jun-91 RSC   Save/Restore SMU/SMUPH during OldTtoTimeU.
    *)


FROM Dialog                 IMPORT
    (* PROC *)                  FatalError, NotYetImplemented;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM Timei                  IMPORT
    (* CONST *)                 Jan, Dec, NoDuration, OneUnitOfDuration,
    (* TYPE  *)                 ADate, ADurationUnit, ADuration, ATimeInfo,
    (* PROC  *)                 TtoTimeU, DurationToReal, RealToDuration,
                                TimeUtoT;

FROM Timeu                  IMPORT
    (* TYPE  *)                 ATimeTable,
    (* VAR   *)                 SMU, SMUPH, TimeTable, YearsOnFile,
    (* PROC  *)                 UpScale, DownScale, FindCorrectScale;

CONST
    MAXCARDINAL     = 65535;

VAR
    OldSMU              : CARDINAL;
    OldSMUPH            : ADuration;
    SMUPHRatio          : REAL;
    DaysRatio           : REAL;
    WeeksRatio          : REAL;
    TempTimeTable,
    OldTimeTable        : ATimeTable;
    SMUPHChanged        : BOOLEAN;


PROCEDURE OldTimeUtoT( TimeU:ADate; VAR TimeInfo : ATimeInfo );
VAR
    TempSMU,
    TempSMUPH : CARDINAL;
BEGIN

    TempSMU        := SMU;
    TempSMUPH      := SMUPH;
    SMU            := OldSMU;
    SMUPH          := OldSMUPH;
    TempTimeTable  := TimeTable;
    TimeTable      := OldTimeTable;

    TimeUtoT( TimeU, TimeInfo );

    TimeTable      := TempTimeTable;
    SMU            := TempSMU;
    SMUPH          := TempSMUPH;

END OldTimeUtoT;





PROCEDURE BeforeCalendarChange();
BEGIN

    OldTimeTable := TimeTable;

    OldSMU       := SMU;
    OldSMUPH     := SMUPH;

END BeforeCalendarChange;


PROCEDURE AfterCalendarChange();
BEGIN
    SMUPHChanged := (SMUPH <> OldSMUPH);
    SMUPHRatio   := DurationToReal(SMUPH)/DurationToReal(OldSMUPH);
        (* 21-Nov-90 RSC *)
    DaysRatio    := FLOAT(TimeTable.StdDayTics * SMU)/FLOAT(OldTimeTable.StdDayTics * OldSMU);
    WeeksRatio   := FLOAT(TimeTable.StdWeek)/FLOAT(OldTimeTable.StdWeek);
END AfterCalendarChange;



PROCEDURE ToNewDate    ( VAR OldDate   : ADate );

VAR
    TimeInfo        : ATimeInfo;
    Result          : BOOLEAN;

BEGIN
    OldTimeUtoT( OldDate, TimeInfo );
    Result := TtoTimeU ( TimeInfo, OldDate);
END ToNewDate;




PROCEDURE ToNewDuration ( VAR Dur           : ADuration;
                          VAR Scale         : ADurationUnit;
                              SaveUnits     : BOOLEAN   );
VAR
    Temp        : CARDINAL;
    OldScale    : ADurationUnit;
    RealDur     : REAL;

BEGIN

    RealDur := DurationToReal(Dur);
    IF (SMUPHChanged) THEN
        RealDur := RealDur * SMUPHRatio;
    END;
    IF (SaveUnits) THEN
        IF (Scale > Hours) THEN
            RealDur := RealDur * DaysRatio;
        END;
        IF (Scale > Days) THEN
            RealDur := RealDur * WeeksRatio;
        END;
    END;
    Dur := RealToDuration(RealDur);
END ToNewDuration;



PROCEDURE ToNewScale    ( VAR Dur           : ADuration;
                          VAR Scale         : ADurationUnit;
                              SaveUnits     : BOOLEAN   );
VAR
    Temp        : CARDINAL;

BEGIN

    IF (SMUPHChanged) THEN
        Dur := RealToDuration(DurationToReal(Dur)*SMUPHRatio);
        IF (Dur = NoDuration) THEN
            Dur := OneUnitOfDuration;               (* 6/8/89 EGK *)
        END;
    END;
    FindCorrectScale (Dur, Scale);

END ToNewScale;






END TimeConversions.
