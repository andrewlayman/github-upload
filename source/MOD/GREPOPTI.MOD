IMPLEMENTATION MODULE GrepOptions;

(*  =========================================================================
    Last Edit : October 19, 1990 5:37PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: Gantt Report Options form support
        
    MODIFICATION HISTORY
        18-Nov-88 LAA   Removed the form record from this module, and put it
                        in the forms file (TLGRFORM is the form builder).
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
        10-Jan-89 RSC   Changed Storage to Space.
        14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
        19-Sep-89 RSC   Pass down the start date to the end date parser.
        30-Jul-90 PFG   Check on FormExit to see if the end date is before 
                        the start date.  Also cleaned up CheckOptions somewhat
                        to make cases clearer and added module number.  See
                        bug #3047.
        19-Oct-90 PFG   More changes for bug #3047.  CardValues for the end
                        date and start date don't always get set (for 
                        instance, if there are already values from the last
                        time the report was run) so we need to compute them
                        before comparing.  Also, we need to allow a blank end 
                        date not to be computed as preceding the start date.
         5-Mar-91 TGS   Protect AdvanceToNewPage and Headings/Legends fields
                        if PageBreaks is No, on FormEntry and on FieldChange.
*)

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxAttribute, ABoxType;

FROM Codes                  IMPORT
    (* CONST *)                 MaxCode,
    (* TYPE *)                  ACode,
    (* VAR  *)                  EmptyCodeSet,
    (* PROC *)                  SetCodeBits;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* PROC *)                  CurrentLayout;

FROM Dialog                 IMPORT Error;

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
    (* PROC *)                  Copy, LJust, TrimRear, SetString, SetLengthOf;

FROM MsgFile                IMPORT GetMessage;

FROM ParseTime              IMPORT StoTimeU, StoEndTimeU;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  TSIZE;


CONST
    AFTR    = 0;
    BFOR    = 1;
    SPAC    = 2;
    GRID    = 3;
    PAGE    = 4;
    LEVL    = 5;
    CAPT    = 6;

    ReportSettingsName      = "TLGR";
    ModuleNumber            = 28300;

 
VAR
    Size                : CARDINAL;
    Class               : CARDINAL;
    Category            : AHoldTypeSet;
    Name                : ARRAY [0..10] OF CHAR;
    FormatPtr           : AChartFormatPtr;



PROCEDURE CheckOptions (    Form            : AForm;
                            FieldNo         : AFieldNo;
                        VAR FormValue       : ARRAY OF AFieldValue;
                            CheckReason     : ACheckReason;
                        VAR Code            : CARDINAL ):BOOLEAN;
VAR
    CodeIn      : CARDINAL;
    EndDate     : CARDINAL;
    s           : ARRAY [0..255] OF CHAR;
    Protect     : BOOLEAN;
    OK          : BOOLEAN;

BEGIN

    (*<NORMAL*)
    CodeIn := Code;
    Code := 0;  (* For safety on return. *)

    CASE CheckReason OF

    | CheckFormEntry :

        IF (NOT FormatPtr^.GanttShowing) THEN
            SetFieldProtection (Form,AFTR,FormValue,TRUE);
            SetFieldProtection (Form,BFOR,FormValue,TRUE);
            SetFieldProtection (Form,GRID,FormValue,TRUE);
        END;
        IF (FieldNo = PAGE) THEN  (* 5-Mar-91 TGS *)
            Protect := (FormValue[PAGE].CardValue = 0);
            IF (Protect) THEN
                FormValue[CAPT].CardValue := 0;
                SetFieldProtection (Form,CAPT,FormValue,TRUE);
                SetFieldProtection (Form,LEVL,FormValue,TRUE);
                ShowValue(Form,CAPT,FormValue);
                ShowValue(Form,LEVL,FormValue);
            END;
        END;

    | CheckFormExit :                                  (* PFG 7/30/90 *)

            (* Set the CardValues for the start and end date
                so that even if they didn't get edited this 
                session they will be accurate for the comparison
                on exit.  *)                 (* 19-Oct-90 PFG *)

        WITH FormValue[BFOR] DO
            IF (CharValue^[0] <> 0C) AND 
                (CharValue^[1] <> " ") THEN

                OK := StoTimeU(CharValue^, CardValue);

                WITH FormValue[AFTR] DO
                    IF (CharValue^[0] = 0C) OR
                    (CharValue^[1] = " ") THEN
                        CardValue := 0;
                    ELSE
                        OK := StoTimeU(CharValue^, CardValue);
                    END;
                END;

                IF (FormValue[BFOR].CardValue < FormValue[AFTR].CardValue) THEN
                    Code := 08000H + BFOR;     (*  Position cursor on end date  *)
                    GetMessage(ModuleNumber + 1, s);  (*  End Date before Start Date  *)
                    Error(s);
                    RETURN FALSE;
                END;

            END;
        END;

    | CheckFieldExit :

        CASE FieldNo OF
(* 5-May-91 TGS moved to CheckFormEntry and CheckFieldChange cases
        | PAGE :
            Protect := (FormValue[FieldNo].CardValue = 0);
            IF (Protect) THEN
                FormValue[CAPT].CardValue := 0;
            END;
            SetFieldProtection (Form,CAPT,FormValue,Protect);
            SetFieldProtection (Form,LEVL,FormValue,Protect);
            ShowValue(Form,CAPT,FormValue);
            ShowValue(Form,LEVL,FormValue);
*)

        |   AFTR, BFOR :
            WITH FormValue[FieldNo] DO
                LJust(CharValue^);
                TrimRear(CharValue^);
                ShowValue(Form,FieldNo,FormValue);
                IF (CharValue^[0] = 0C) OR
                    (CharValue^[1] = " ") THEN
                    RETURN TRUE;
                ELSIF (FieldNo = AFTR) THEN
                    RETURN StoTimeU(CharValue^,CardValue);
                ELSE
                    CardValue := FormValue[AFTR].CardValue; (* RSC 19-Sep-89 *)
                    RETURN StoEndTimeU(CharValue^,CardValue);
                END;
            END;

        ELSE
        END;

    | CheckFieldChange : (* 5-May-91 TGS *)
        IF (FieldNo = PAGE) THEN
            Protect := (FormValue[PAGE].CardValue = 0);
            IF (Protect) THEN
                FormValue[CAPT].CardValue := 0;
            END;
            SetFieldProtection (Form,CAPT,FormValue,Protect);
            SetFieldProtection (Form,LEVL,FormValue,Protect);
            ShowValue(Form,CAPT,FormValue);
            ShowValue(Form,LEVL,FormValue);
        END;

    ELSE
    END;
    (*NORMAL>*)

    RETURN TRUE;
END CheckOptions;






PROCEDURE DoPrintDialog() : BOOLEAN;

CONST
    FormID          = 40;

VAR
    Code            : ACode;
    FormValue       : ARRAY [0..9] OF AFieldValue;

BEGIN

    NEW(FormValue[AFTR].CharValue);
    NEW(FormValue[BFOR].CharValue);

    Copy (ReportSettings^.StartDate, FormValue[AFTR].CharValue^);
    Copy (ReportSettings^.EndDate, FormValue[BFOR].CharValue^);
    FormValue[PAGE].CardValue := ORD(ReportSettings^.BreakPages);
    FormValue[LEVL].CardValue := ORD(ReportSettings^.PageBreakLevel);
    FormValue[SPAC].CardValue := ReportSettings^.Spacing - 1;
    FormValue[CAPT].CardValue := ORD(ReportSettings^.PrintCaptions);
    FormValue[GRID].CardValue := ORD(ReportSettings^.MakeGrid);

    Code := DoForm(0,0,maxcol,GanttWEnd,FormID,TRUE,FormValue,CheckOptions);

    IF (Code = ExitKey) THEN
        ReportSettings^.MakeGrid   := VAL(BOOLEAN, FormValue[GRID].CardValue);
        ReportSettings^.BreakPages := VAL(BOOLEAN, FormValue[PAGE].CardValue);
        ReportSettings^.PrintCaptions := VAL(BOOLEAN, FormValue[CAPT].CardValue);
        ReportSettings^.PageBreakLevel := FormValue[LEVL].CardValue;
        ReportSettings^.Spacing := FormValue[SPAC].CardValue + 1;
        Copy(FormValue[AFTR].CharValue^, ReportSettings^.StartDate);
        Copy(FormValue[BFOR].CharValue^, ReportSettings^.EndDate);
        HoldThis(Name, Class, Category, ReportSettings, Size);
    END;
    DISPOSE(FormValue[AFTR].CharValue);
    DISPOSE(FormValue[BFOR].CharValue);

    RETURN (Code = ExitKey);

END DoPrintDialog;



BEGIN

    FormatPtr := CurrentLayout();

    SetString(Name, ReportSettingsName);
    Class := 0;

    IF NOT LocateHeldItem(Name, Class, Category, ReportSettings, Size) OR
            (Size <> TSIZE(AReportSetting)) THEN
        Size := TSIZE(AReportSetting);
        Category := AHoldTypeSet{HoldInConfig, HoldInDataFile};  (* 9/14/89 EGK *)
        ALLOCATE(ReportSettings, Size);
        WITH ReportSettings^ DO
            TagType := NoTags;
            MakeGrid := TRUE;
            BreakPages := FALSE;
            TagColumn := 0;
            SetLengthOf (StartDate, 0);
            SetLengthOf (EndDate, 0);
            Spacing := 1;
            PrintCaptions := TRUE;
            DetailsOnly := FALSE;
            PageBreakLevel := 0;
        END;
        HoldThis(Name, Class, Category, ReportSettings, Size);
    END;
    ReportSettings^.TagType := NoTags;      (* Tagging has been disabled *)

END GrepOptions.

