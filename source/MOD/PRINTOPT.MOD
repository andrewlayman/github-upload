IMPLEMENTATION MODULE PrintOptions;

    (* Modification History:

       10-Jan-89 RSC    Changed Storage to Space    .
       15-Jun-89 KKC    Center the Page Break Form on the screen.
       20-Jun-89 KKC    Do not protect row heading if Unlimited Page
                        width field is set to YES.
       14-Sep-89 EGK    Added HoldInDataFile to the HoldTypeSet.
       13-Oct-89 KKC    Restore the changes user made when he switch 
                        PageBreaks back to Yes.
       15-Nov-89 KKC    Protect VHED VFTR HREP VCOL LEVL if page breaks is no.
       21-Nov-89 KKC    Do not set VHED VFTR HREP VCOL LEVL if page breaks 
                        is yes.
    *)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

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
    (* PROC *)                  SetString;

FROM PrintStatic            IMPORT
    (* VAR *)                   PrintCB;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;


CONST
    VPAG    = 0;
    LEVL    = 1;
    HHED    = 2;
    VHED    = 3;
    VFTR    = 4;
    HREP    = 5;
    VCOL    = 6;
    VSPC    = 7;
    HSPC    = 8;
    ZERO    = 9;
    HPAG    = 10;

    ReportSettingsName      = "TLPRTREP";


TYPE
    AnOldSettings   =   RECORD
        OldVHED     : CARDINAL;
        OldVFTR     : CARDINAL;
        OldHREP     : CARDINAL;
        OldVCOL     : CARDINAL;
        OldLEVL     : CARDINAL;
    END;
VAR
    Size                : CARDINAL;
    Class               : CARDINAL;
    Category            : AHoldTypeSet;
    Name                : ARRAY [0..10] OF CHAR;
    AllowRowRepeat      : BOOLEAN;
    OldSettings         : AnOldSettings;


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

    CASE CheckReason OF
    | CheckFormEntry:
        CASE FieldNo OF
            | VPAG :
                Protect := (FormValue[FieldNo].CardValue = 0);
                IF ( Protect ) THEN
                    FormValue[VHED].CardValue := 0;
                    FormValue[VFTR].CardValue := 0;
                    FormValue[HREP].CardValue := 0;
                    FormValue[VCOL].CardValue := 0;
                    FormValue[LEVL].CardValue := 0;
                END;
                SetFieldProtection (Form,VHED,FormValue,Protect);
                SetFieldProtection (Form,VFTR,FormValue,Protect);
                SetFieldProtection (Form,HREP,FormValue,Protect);
                SetFieldProtection (Form,VCOL,FormValue,Protect);
                SetFieldProtection (Form,LEVL,FormValue,Protect);
                ShowValue(Form,VHED,FormValue);
                ShowValue(Form,VFTR,FormValue);
                ShowValue(Form,HREP,FormValue);
                ShowValue(Form,VCOL,FormValue);
                ShowValue(Form,LEVL,FormValue);
                WITH OldSettings DO
                    OldVHED     :=  FormValue[VHED].CardValue;
                    OldVFTR     :=  FormValue[VFTR].CardValue;
                    OldHREP     :=  FormValue[HREP].CardValue;
                    OldVCOL     :=  FormValue[VCOL].CardValue;
                    OldLEVL     :=  FormValue[LEVL].CardValue;
                END;
            ELSE
            END;
            RETURN TRUE;
    | CheckFieldEntry:
        CASE FieldNo OF
            | VPAG :
                IF ( FormValue[FieldNo].CardValue <> 0 ) THEN
                    WITH OldSettings DO
                        OldVHED     :=  FormValue[VHED].CardValue;
                        OldVFTR     :=  FormValue[VFTR].CardValue;
                        OldHREP     :=  FormValue[HREP].CardValue;
                        OldVCOL     :=  FormValue[VCOL].CardValue;
                        OldLEVL     :=  FormValue[LEVL].CardValue;
                    END;
                END;
            ELSE
            END;
    | CheckFieldChange:
        CASE FieldNo OF
            | VPAG :
                Protect := (FormValue[FieldNo].CardValue = 0);
                IF ( Protect ) THEN
                    FormValue[VHED].CardValue := 0;
                    FormValue[VFTR].CardValue := 0;
                    FormValue[HREP].CardValue := 0;
                    FormValue[VCOL].CardValue := 0;
                    FormValue[LEVL].CardValue := 0;
                ELSE
                    WITH OldSettings DO
                        FormValue[VHED].CardValue := OldVHED;
                        FormValue[VFTR].CardValue := OldVFTR;
                        FormValue[HREP].CardValue := OldHREP;
                        FormValue[VCOL].CardValue := OldVCOL;
                        FormValue[LEVL].CardValue := OldLEVL;
                    END;
                END;
                SetFieldProtection (Form,VHED,FormValue,Protect);
                SetFieldProtection (Form,VFTR,FormValue,Protect);
                SetFieldProtection (Form,HREP,FormValue,Protect);
                SetFieldProtection (Form,VCOL,FormValue,Protect);
                SetFieldProtection (Form,LEVL,FormValue,Protect);
                ShowValue(Form,VHED,FormValue);
                ShowValue(Form,VFTR,FormValue);
                ShowValue(Form,HREP,FormValue);
                ShowValue(Form,VCOL,FormValue);
                ShowValue(Form,LEVL,FormValue);
            |   VSPC :
                        IF (FormValue[FieldNo].CardValue = 0) THEN
                            FormValue[FieldNo].CardValue := 1;
                            ShowValue(Form,VSPC,FormValue);
                        ELSIF (FormValue[FieldNo].CardValue > 9) THEN
                            FormValue[FieldNo].CardValue := 9;
                            ShowValue(Form,VSPC,FormValue);
                        END;

            |   HSPC :
                        MaxWidth := PrintCB.RightMargin - PrintCB.LeftMargin;
                        IF (FormValue[FieldNo].CardValue > MaxWidth) THEN
                            FormValue[FieldNo].CardValue := MaxWidth;
                            ShowValue(Form,FieldNo,FormValue);
                        ELSIF (FormValue[FieldNo].CardValue < 1) THEN
                            FormValue[FieldNo].CardValue := 1;
                            ShowValue(Form,FieldNo,FormValue);
                        END;
            ELSE
            END;
    ELSE
    END;

    (*NORMAL>*)

    RETURN TRUE;
END CheckOptions;





PROCEDURE DoPrintDialog (   Dimensions  : CARDINAL  ) : BOOLEAN;

CONST
    FormId                  = 41;

VAR
    Code            : ACode;
    FormValue       : ARRAY [0..10] OF AFieldValue;

BEGIN

    AllowRowRepeat := (Dimensions > 1);

    Code := CancelKey;

    FormValue[VPAG].CardValue := ORD(ReportSettings^.RowSpec.Paged);
    FormValue[VHED].CardValue := ORD(ReportSettings^.RowSpec.RepeatHeaders);
    FormValue[VFTR].CardValue := ORD(ReportSettings^.RowSpec.RepeatFooters);
    FormValue[VCOL].CardValue := ORD(ReportSettings^.RowSpec.RepeatTitles);
    FormValue[VSPC].CardValue := ReportSettings^.RowSpec.Spacing;
    FormValue[HPAG].CardValue := ORD(ReportSettings^.ColumnSpec.Paged);
    FormValue[HHED].CardValue := ORD(ReportSettings^.ColumnSpec.RepeatHeaders);
    FormValue[HREP].CardValue := ORD(ReportSettings^.ColumnSpec.RepeatTitles);
    FormValue[HSPC].CardValue := ReportSettings^.ColumnSpec.Spacing;
    FormValue[LEVL].CardValue := ReportSettings^.PageBreakLevel;
    FormValue[ZERO].CardValue := ORD(ReportSettings^.PrintZeros);

    Code := DoForm(7,GanttWEnd,maxcol-7,maxrow-1,FormId,TRUE,FormValue,CheckOptions);

    IF (Code = ExitKey) THEN
        ReportSettings^.RowSpec.Paged := VAL(BOOLEAN,FormValue[VPAG].CardValue);
        ReportSettings^.RowSpec.RepeatHeaders := VAL(BOOLEAN,FormValue[VHED].CardValue);
        ReportSettings^.RowSpec.RepeatFooters := VAL(BOOLEAN,FormValue[VFTR].CardValue);
        ReportSettings^.RowSpec.RepeatTitles := VAL(BOOLEAN,FormValue[VCOL].CardValue);
        ReportSettings^.RowSpec.Spacing := FormValue[VSPC].CardValue;
        ReportSettings^.ColumnSpec.Paged := VAL(BOOLEAN,FormValue[HPAG].CardValue);
        ReportSettings^.ColumnSpec.RepeatHeaders := VAL(BOOLEAN,FormValue[HHED].CardValue);
        ReportSettings^.ColumnSpec.RepeatTitles := VAL(BOOLEAN,FormValue[HREP].CardValue);
        ReportSettings^.ColumnSpec.Spacing := FormValue[HSPC].CardValue;
        ReportSettings^.PageBreakLevel := FormValue[LEVL].CardValue;
        ReportSettings^.PrintZeros := VAL(BOOLEAN,FormValue[ZERO].CardValue);
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
            RowSpec.RepeatHeaders := FALSE;
            RowSpec.RepeatFooters := FALSE;
            RowSpec.RepeatTitles := FALSE;
            RowSpec.Spacing := 1;
            ColumnSpec.Paged := TRUE;
            ColumnSpec.RepeatHeaders := FALSE;
            ColumnSpec.RepeatFooters := FALSE;
            ColumnSpec.RepeatTitles := FALSE;
            ColumnSpec.Spacing := 5;
            PageBreakLevel := 0;
            PrintZeros := TRUE;
        END;
    END;

END PrintOptions.
