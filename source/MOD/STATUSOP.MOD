IMPLEMENTATION MODULE StatusOptions;

    (*  MODIFICATION HISTORY

        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        23-Jan-89 RSC   Changed Storage to Space    .
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.

    *)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Codes                  IMPORT
    (* CONST *)                 MaxCode,
    (* TYPE *)                  ACode,
    (* VAR  *)                  EmptyCodeSet,
    (* PROC *)                  SetCodeBits;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, ACheckReason, AForm,
    (* PROC *)                  DoForm, NullCheckProc, ShowValue,
                                SetFieldProtection;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  LocateHeldItem, HoldThis;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 DoIt, CancelKey, ExitKey, EditKey;

FROM Layout                 IMPORT
    (* VAR *)                   MenuStart, MenuEnd, GanttWEnd, GanttWStart;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, SetLengthOf, LJust, TrimRear, Copy;

FROM ParseTime              IMPORT
    (* PROC *)                  StoTimeU;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;

FROM Timei                  IMPORT
    (* TYPE *)                  ADuration, ADate, ADurationUnit;

FROM Timeu                  IMPORT
    (* PROC *)                  UpScale, DownScale;


CONST
    DAY1    = 0;
    DAY2    = 1;
    WKS1    = 2;
    WKS2    = 3;
    MON1    = 4;
    MON2    = 5;

    VPAG    = 6;
    VCOL    = 7;
    VHED    = 8;
    VFTR    = 9;

    ALLT    = 10;
    HPAG    = 11;
    HHED    = 12;

    ReportSettingsName      = "TLSR";

    MAXDATE         = 65535;

 
VAR
    Size                : CARDINAL;
    Class               : CARDINAL;
    Category            : AHoldTypeSet;
    Name                : ARRAY [0..10] OF CHAR;



PROCEDURE CheckPeriod  (    Date            : ADate;
                            Unit            : ADurationUnit;
                        VAR Period          : CARDINAL  );
VAR
    Dur             : ADuration;

BEGIN

    Dur := UpScale (Period, Unit);
    IF (Dur > MAXDATE - Date) THEN
        Dur := MAXDATE - Date;
    END;
    Period := DownScale (Dur, Unit);

END CheckPeriod;



PROCEDURE CheckOptions (    Form            : AForm;
                            FieldNo         : AFieldNo;
                        VAR FormValue       : ARRAY OF AFieldValue;
                            CheckReason     : ACheckReason;
                        VAR Code            : CARDINAL ):BOOLEAN;
VAR
    Protect     : BOOLEAN;
    CodeIn      : CARDINAL;
    Changed,
    ok          : BOOLEAN;
    s           : ARRAY [0..255] OF CHAR;
    Unit        : ADurationUnit;
    Period      : CARDINAL;

BEGIN

    (*<NORMAL*)
    CodeIn := Code;
    Code := 0;  (* For safety on return. *)

    IF (CheckReason = CheckFieldEntry) THEN
        RETURN TRUE;
    END;

    CASE FieldNo OF

        VPAG :
                Protect := (FormValue[FieldNo].CardValue = 0);
                SetFieldProtection (Form,VHED,FormValue,Protect);
                SetFieldProtection (Form,VFTR,FormValue,Protect);
                SetFieldProtection (Form,VCOL,FormValue,Protect);
                ShowValue(Form,VHED,FormValue);
                ShowValue(Form,VFTR,FormValue);
                ShowValue(Form,VCOL,FormValue);

    |   HPAG :
                Protect := (FormValue[FieldNo].CardValue = 0);
                SetFieldProtection (Form,HHED,FormValue,Protect);
                ShowValue(Form,HHED,FormValue);

    |   DAY1, WKS1, MON1 :
                WITH FormValue[FieldNo] DO
                    LJust(CharValue^);
                    TrimRear(CharValue^);
                    ShowValue(Form,FieldNo,FormValue);
                    Protect := (CharValue^[0] = 0C) OR (CharValue^[1] = " ");
                    IF (Protect) THEN
                        FormValue[FieldNo+1].CardValue := 0;
                    END;
                    SetFieldProtection (Form,FieldNo+1,FormValue,Protect);
                    IF (Protect) THEN
                        RETURN TRUE;
                    ELSIF (NOT StoTimeU(CharValue^,CardValue)) THEN
                        RETURN FALSE;
                    ELSE
                        Unit := VAL (ADurationUnit, 2+ORD(FieldNo DIV 2));
                        CheckPeriod (CardValue, Unit, FormValue[FieldNo+1].CardValue);
                        ShowValue (Form,FieldNo+1,FormValue);
                    END;
                END;

    |   DAY2, WKS2, MON2 :
                WITH FormValue[FieldNo] DO
                    Unit := VAL (ADurationUnit, 2+ORD((FieldNo-1) DIV 2));
                    CheckPeriod (FormValue[FieldNo-1].CardValue, Unit, CardValue);
                    ShowValue (Form,FieldNo,FormValue);
                END;
    ELSE
    END;

    (*NORMAL>*)

    RETURN TRUE;
END CheckOptions;





PROCEDURE DoPrintDialog() : BOOLEAN;

CONST
    FormId          = 48;

VAR
    Code            : ACode;
    FormValue       : ARRAY [DAY1..HHED] OF AFieldValue;

BEGIN

    Code := CancelKey;

    NEW(FormValue[DAY1].CharValue);
    NEW(FormValue[WKS1].CharValue);
    NEW(FormValue[MON1].CharValue);

    Copy (ReportSettings^.DaysStart, FormValue[DAY1].CharValue^);
    Copy (ReportSettings^.WeeksStart, FormValue[WKS1].CharValue^);
    Copy (ReportSettings^.MonthsStart, FormValue[MON1].CharValue^);

    FormValue[DAY2].CardValue := ReportSettings^.DaysPeriod;
    FormValue[WKS2].CardValue := ReportSettings^.WeeksPeriod;
    FormValue[MON2].CardValue := ReportSettings^.MonthsPeriod;
    FormValue[ALLT].CardValue := ORD(NOT ReportSettings^.AllTasks);

    FormValue[VPAG].CardValue := ORD(ReportSettings^.Paged);
    FormValue[VHED].CardValue := ORD(ReportSettings^.RepeatHeaders);
    FormValue[VFTR].CardValue := ORD(ReportSettings^.RepeatFooters);
    FormValue[VCOL].CardValue := ORD(ReportSettings^.RepeatTitles);
    FormValue[HPAG].CardValue := ORD(ReportSettings^.DoStrips);
    FormValue[HHED].CardValue := ORD(ReportSettings^.HonorMargins);

    Code := DoForm(0,GanttWEnd,maxcol,maxrow-1,FormId,TRUE,FormValue,CheckOptions);
    
    IF (Code = ExitKey) THEN
        Copy (FormValue[DAY1].CharValue^, ReportSettings^.DaysStart);
        Copy (FormValue[WKS1].CharValue^, ReportSettings^.WeeksStart);
        Copy (FormValue[MON1].CharValue^, ReportSettings^.MonthsStart);

        ReportSettings^.DaysPeriod := FormValue[DAY2].CardValue;
        ReportSettings^.WeeksPeriod := FormValue[WKS2].CardValue;
        ReportSettings^.MonthsPeriod := FormValue[MON2].CardValue;
        ReportSettings^.AllTasks := NOT VAL(BOOLEAN,FormValue[ALLT].CardValue);

        ReportSettings^.Paged := VAL(BOOLEAN,FormValue[VPAG].CardValue);
        ReportSettings^.RepeatHeaders := VAL(BOOLEAN,FormValue[VHED].CardValue);
        ReportSettings^.RepeatFooters := VAL(BOOLEAN,FormValue[VFTR].CardValue);
        ReportSettings^.RepeatTitles := VAL(BOOLEAN,FormValue[VCOL].CardValue);
        ReportSettings^.DoStrips := VAL(BOOLEAN,FormValue[HPAG].CardValue);
        ReportSettings^.HonorMargins := VAL(BOOLEAN,FormValue[HHED].CardValue);
        HoldThis(Name, Class, Category, ReportSettings, Size);
    END;

    DISPOSE(FormValue[DAY1].CharValue);
    DISPOSE(FormValue[WKS1].CharValue);
    DISPOSE(FormValue[MON1].CharValue);

    RETURN (Code = ExitKey);

END DoPrintDialog;



BEGIN

    SetString(Name, ReportSettingsName);
    Class := 0;

    IF NOT LocateHeldItem(Name, Class, Category, ReportSettings, Size) OR
            (Size <> TSIZE(AReportSetting)) THEN
        Size := TSIZE(AReportSetting);
        Category := AHoldTypeSet{HoldInConfig};
        ALLOCATE(ReportSettings, Size);
        WITH ReportSettings^ DO
            SetLengthOf (DaysStart, 0);
            SetLengthOf (WeeksStart, 0);
            SetLengthOf (MonthsStart, 0);
            DaysPeriod := 0;
            WeeksPeriod := 0;
            MonthsPeriod := 0;
            AllTasks := TRUE;
            Paged := TRUE;
            RepeatHeaders := FALSE;
            RepeatFooters := FALSE;
            RepeatTitles := FALSE;
            DoStrips := TRUE;
            HonorMargins := FALSE;
        END;
    END;

END StatusOptions.
