IMPLEMENTATION MODULE HistOptions;

    (* Modification History:

       10-Jan-89 RSC    Changed Storage to Space    .
       30-Jun-89 KKC    Rearrange histogram form.
       12-Jun-89 KKC    Do not protect "Space between Histograms" field when
                        Page break is set to NO.
       14-Sep-89 EGK    Added HoldInDataFile to the HoldTypeSet.
       19-Sep-89 KKC    Default precision to 0.5 instead of 1.
    *)

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE;

FROM Codes                  IMPORT
    (* TYPE *)                  ACode;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

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
    (* CONST *)                 ExitKey;

FROM Layout                 IMPORT
    (* VAR *)                   MenuStart, MenuEnd, GanttWEnd, GanttWStart;

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;


CONST
    VPAG    = 0;
    NEWP    = 1;
    HHED    = 2;
    VHED    = 3;
    VFTR    = 4;
    HREP    = 5;
    VCOL    = 6;
    PREC    = 7;
    VSPC    = 8;
    GPRC    = 9;
    HPAG    = 10;

    LastField = 10;

    ReportSettingsName      = "TLHR";

    Zero        = 0.0;

VAR
    Size                : CARDINAL;
    Class               : CARDINAL;
    Category            : AHoldTypeSet;
    Name                : ARRAY [0..10] OF CHAR;


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
    MaxWidth    : CARDINAL;


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
                IF (Protect) THEN
                    FormValue[VHED].CardValue := 0;
                    FormValue[VFTR].CardValue := 0;
                    FormValue[VCOL].CardValue := 0;
                    FormValue[NEWP].CardValue := 0;
                    FormValue[HREP].CardValue := 0;
                END;
                SetFieldProtection (Form,VHED,FormValue,Protect);
                SetFieldProtection (Form,VFTR,FormValue,Protect);
                SetFieldProtection (Form,VCOL,FormValue,Protect);
                SetFieldProtection (Form,NEWP,FormValue,Protect);
                SetFieldProtection (Form,HREP,FormValue,Protect);
                ShowValue(Form,VHED,FormValue);
                ShowValue(Form,VFTR,FormValue);
                ShowValue(Form,VCOL,FormValue);
                ShowValue(Form,NEWP,FormValue);
                ShowValue(Form,HREP,FormValue);

    |   PREC :
                IF (FormValue[FieldNo].RealValue = Zero) THEN
                    RETURN FALSE;
                END;

    |   NEWP :
                Protect := (FormValue[FieldNo].CardValue = 1);
                IF ( Protect ) THEN
                    FormValue[VSPC].CardValue := 0;
                END;
                SetFieldProtection (Form,VSPC,FormValue,Protect);
                ShowValue(Form,VSPC,FormValue);
    ELSE
    END;

    (*NORMAL>*)

    RETURN TRUE;
END CheckOptions;





PROCEDURE DoPrintDialog () : BOOLEAN;

VAR
    Code            : ACode;
    FormValue       : ARRAY [0..LastField] OF AFieldValue;

BEGIN

    FormValue[VPAG].CardValue := ORD(ReportSettings^.RowSpec.Paged);
    FormValue[HREP].CardValue := ORD(ReportSettings^.ColumnSpec.RepeatTitles);
    FormValue[VCOL].CardValue := ORD(ReportSettings^.RowSpec.RepeatTitles);
    FormValue[VHED].CardValue := ORD(ReportSettings^.RowSpec.RepeatHeaders);
    FormValue[VFTR].CardValue := ORD(ReportSettings^.RowSpec.RepeatFooters);

    FormValue[PREC].RealValue := ReportSettings^.RowSpec.Precision;
    FormValue[GPRC].CardValue := ReportSettings^.RowSpec.GridStep;

    FormValue[VSPC].CardValue := ReportSettings^.RowSpec.Spacing;
    FormValue[NEWP].CardValue := ORD(ReportSettings^.RowSpec.BreakEach);

    FormValue[HPAG].CardValue := ORD(ReportSettings^.ColumnSpec.Paged);
    FormValue[HHED].CardValue := ORD(ReportSettings^.ColumnSpec.RepeatHeaders);

    Code := DoForm (5, GanttWEnd, maxcol-5, maxrow-1,
                    50, TRUE, FormValue, CheckOptions);

    IF (Code = ExitKey) THEN
        ReportSettings^.RowSpec.Paged := VAL(BOOLEAN,FormValue[VPAG].CardValue);
        ReportSettings^.ColumnSpec.RepeatTitles := VAL(BOOLEAN,FormValue[HREP].CardValue);
        ReportSettings^.RowSpec.RepeatTitles := VAL(BOOLEAN,FormValue[VCOL].CardValue);
        ReportSettings^.RowSpec.RepeatHeaders := VAL(BOOLEAN,FormValue[VHED].CardValue);
        ReportSettings^.RowSpec.RepeatFooters := VAL(BOOLEAN,FormValue[VFTR].CardValue);

        ReportSettings^.RowSpec.Precision := FormValue[PREC].RealValue;
        ReportSettings^.RowSpec.GridStep := FormValue[GPRC].CardValue;

        ReportSettings^.RowSpec.Spacing := FormValue[VSPC].CardValue;
        ReportSettings^.RowSpec.BreakEach := VAL(BOOLEAN,FormValue[NEWP].CardValue);

        ReportSettings^.ColumnSpec.Paged := VAL(BOOLEAN,FormValue[HPAG].CardValue);
        ReportSettings^.ColumnSpec.RepeatHeaders := VAL(BOOLEAN,FormValue[HHED].CardValue);
        HoldThis(Name, Class, Category, ReportSettings, Size);
    END;

    RETURN (Code = ExitKey);

END DoPrintDialog;



BEGIN

    SetString(Name, ReportSettingsName);
    Class := 0;

    IF NOT LocateHeldItem(Name, Class, Category, ReportSettings, Size) OR
            (Size <> TSIZE(AReportSetting)) THEN
        Size := TSIZE(AReportSetting);
        Category := AHoldTypeSet{HoldInConfig, HoldInDataFile};   (* 9/14/89 EGK *)
        ALLOCATE(ReportSettings, Size);
        WITH ReportSettings^ DO
            RowSpec.Paged := TRUE;
            ColumnSpec.RepeatTitles := FALSE;
            RowSpec.RepeatTitles := FALSE;
            RowSpec.RepeatHeaders := FALSE;
            RowSpec.RepeatFooters := FALSE;

            RowSpec.Precision := 0.5;
            RowSpec.GridStep := 0;

            RowSpec.Spacing := 1;
            RowSpec.BreakEach := FALSE;

            ColumnSpec.Paged := TRUE;
            ColumnSpec.RepeatHeaders := FALSE;
        END;
    END;

END HistOptions.
