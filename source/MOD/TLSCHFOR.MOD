MODULE TLSchFor;

(*  =========================================================================
    Last Edit : November 2, 1990 4:45PM by CL
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Supports the SCHEDULE/OPTIONS form.        

    MODIFICATION HISTORY:

    07/23/86 LAA    Change the type of Code to CARDINAL in CheckScheduleForm.
    07/30/86 LAA    Removed usage of HotLinkedProjectName.
    11/04/86 LAA    ChartState is now a set, so the usage of SetState and
                    UnSetState has changed.
    11/25/86 LAA    Modified for new Lights module.  Exported new procedure
                    to display the schedule light.
    12/03/86 LAA    Only one line of project notes is now displayed on the
                    form.
    12/16/86 LAA    Incorporated new version of Edit.
    12/31/86 LAA    Changed screen coordinates of edit window.
    03/18/87 EGK    Added code for new As-of setting field.  The As-of date
                    is set from the form value only if "Manual" is selected.
                    Otherwise, the As-of date field is protected and set
                    externally by SetAsOfDate.
    03/30/87 EGK    As-of date value (on form) changes appropriately as
                    different as-of settings are selected.
    30-Mar-87 LAA   Incorporated second version of editor, which uses object
                    oriented concepts.
    07-Aug-87 EGK   Moved lots of fields from the schedule form to the
                    options form.
    18-Sep-87 RSC   Altered form string value initialization and editing of
                    the schedule form.
     8-Oct-87 RSC   Altered the Options Form check proc a little because of
                    a changed Options Form.  Fields moved around, (Yes,No)
                    became (No,Yes) for consistancy, and added the "undo
                    steps" field.  Also squish out spaces in the file name
                    fields in the project form.
    13-Oct-87 RSC   Added 'Set as Highest Priority' field to optns form.
    15-Oct-87 RSC   Changed param to EditText.  Added Shadows.
    28-Oct-87 RSC   Notify Forms when text has been edited to prevent
                    accidental ESCs.
    21-Dec-87 EGK   New overlay, taken from old Schedule.MOD.
    04-Jan-88 LAA   Option form was turning recalc on, even for no changes.
    20-Jan-88 LAA   Made this an installable overlay.
    21-Dec-88 LAA   Changed imports for Lazlo reorganization.
     6-Jan-89 RSC   Moved "AnOverlayProc" reference.
    20-Apr-89 AJL   Added the time-constrained leveling option.
     8-Apr-89 AJL   If the planning method choice is changed, UnSetState(Scheduled).
    08-May-89 WKH   Added support for annealing options and network view
                    options.
    14-May-89 AJL   Replaced the Alarms.AlarmOn variable with 
                    Planner.MoveFutureTasks. 
    15-May-89 AJL   Import Changer.UsesCostTracking and attach it to the
                    Cost Tracking field on the form.
    20-Jun-89 AJL   Return the passed-in code from the CheckProc unless
                    we explicitly override it.
    09-Aug-89 KKC   Add copyright message.
    18-Aug-89 EGK   Send out a "NetworkSettingChange" notice if either of
                    the PERT-related fields is changed.
    12-Sep-89 WKH   Make editor window bigger in compressed video mode
    06-Nov-89 EGK   Reduce the number of AnnealingChoice values to two.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    01-Jun-90 AJL   Replaced the PlanLevel variables from Planner with
                    use of the CalculationState array.
    03-Aug-90 PFG   Removed code related to Recalc state (auto/manual) and
                    Resource Leveling (yes/no/within slack).  Moved to new
                    Calculations form in TLCALCUL.
    23-Oct-90 PFG   Made changes to form as per 4.5 prototype review.  Added
                    Start "Date Restriction" and "Force Critical".  Moved 
                    "Force Future Tasks..." and "Highest Priority" to 
                    Calculations form.  Removed "Sound" field.  Other 
                    cosmetic changes.
     2-Nov-90 CL    Put StartDateMustStart and ForceCritical into a record, 
                    FixedDateRules.
    =========================================================================
*)



FROM Changer      IMPORT  AdvancedTaskForm, UsesCostTracking;

FROM AsOf         IMPORT  AsOfDate, AnAsOfSettingOption, AsOfSettingOption,
                          SetAsOfDate;

FROM Boxes        IMPORT  ABoxType, ABoxAttribute;

FROM ChartControl IMPORT  UnSetState, AChartState, ChartState;

FROM Codes        IMPORT  ACode;

FROM Dialog       IMPORT ADialogOption, WarningBox, Error, FatalError;

FROM Directory    IMPORT  NormalizeFileName, DirectoryIsReachable,
                          ExpandPath, AFileNamePart, ASetOfFileNameParts;

FROM FileAux      IMPORT  OverlayPath;

FROM FormCon      IMPORT  AFieldNo;

FROM Forms        IMPORT  DoForm, AFieldValue, ACheckReason, NullCheckProc,
                          AStringValue, ShowValue, AForm, SetFieldProtection,
                          SetFormChange;

FROM Kbio         IMPORT  maxcol, avidmode, soundon, maxrow;

FROM Keys         IMPORT  ExitKey, AddTaskKey, CopyKey, JoinKey, UnJoinKey,
                          UndoKey, ChngTskKey, DelTaskKey, SplitKey, 
                          JoinPartialKey;

FROM Layout       IMPORT  GanttWEnd;

FROM Lights       IMPORT ALight, ActiveLightRegion, InstallLight, DisplayLight;

FROM LStrings     IMPORT  Fill, SubStr, ConcatLS, LengthOf,
                          TrimRear, LJust, LStringToTString, Procustes,
                          Search, Insert, Remove, Copy, SetLengthOf;

FROM MsgFile      IMPORT GetMessage;

FROM NetworkData            IMPORT
    (* TYPE *)                  AnAnnealingChoice, ANetworkType,
    (* VAR  *)                  AnnealingChoice, NetworkType;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM ParseTime    IMPORT
    (* PROC *)           StoTimeU;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectText, FullScheduleName, Author,
                                FixedDateRules, ScheduleSaved, ConfigSaved;

FROM Text         IMPORT  AText, CopyLine, AssignLine, Compress, CreateText,
                          LineExists, TextExists;

FROM Edits        IMPORT  EditText;

FROM TimeFormat   IMPORT
    (* TYPE *)          ADateDisplayOption,
    (* VAR *)           DefaultDateOption,
    (* PROC *)          TimeUtoS;

FROM Timei        IMPORT
    (* TYPE *)          ADate,
    (* VAR *)           Today;

FROM SYSTEM       IMPORT  ADR;

FROM Undo         IMPORT  GetUndoLimit, SetUndoLimit;


CONST
    ModuleNumber            = 4600;

VAR
    CopyOfNotes             : AText;
    OverlayID               : AnOverlayID;


(*----------------------------------------------------------------------------
    GetProjectNotes --

    Retrieve the first line of the project description text.
----------------------------------------------------------------------------*)

PROCEDURE GetProjectNotes(VAR Line          : ARRAY OF CHAR);

BEGIN                       (* GetProjectNotes *)

    Fill(Line, " ", 0);
    IF LineExists(ProjectText, 0) THEN
        CopyLine(ProjectText, 0, Line);
    END;
    Procustes(Line, HIGH(Line));

END GetProjectNotes;




(*----------------------------------------------------------------------------
    PutProjectNotes --

    Replace the first line of the project description text.
----------------------------------------------------------------------------*)

PROCEDURE PutProjectNotes(VAR Line          : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..80] OF CHAR;

BEGIN                       (* PutProjectNotes *)

    TrimRear(Line);
    IF NOT TextExists(ProjectText) THEN
        IF (ORD(Line[0]) = 0) THEN
            RETURN;
        ELSE
            ProjectText := CreateText();
        END;
    END;

    IF NOT AssignLine(Line, 0, ProjectText) THEN
        GetMessage( ModuleNumber + 6, s ); (* "Project description not saved: out of memory." *)
        Error(s);
    END;
    Compress(ProjectText);

END PutProjectNotes;



CONST
    FSN  =  0;           (* Schedule name. *)
    CM1  =  1;           (* Notes *)  
    PMF  =  2;           (* Responsible *)
    AOS  =  3;           (* As-of method *)
    ASD  =  4;           (* As-of date *)
    MON  =  5;           (* Small/Large Form *)
    CST  =  6;           (* Cost Tracking *)
    DAT  =  7;           (* Date format *)
    UND  =  8;           (* Undo *)
    SDR  =  9;           (* Start Date Restriction *)
    FCR  =  10;          (* Force Critical *)
    NTP  =  11;          (* PERT Style *)
    ANN  =  12;          (* PERT Quality *)
   TopField = 12;        (* Highest numbered field. *)

    OptionsStringFields = {FSN,CM1,PMF,ASD};
    OptionsStringCount  = 4;  (* # of the bits in OptionsStringFields *)



PROCEDURE CheckOptionsForm  (   Form        : AForm;
                                FieldNo     : AFieldNo;
                            VAR FormValue   : ARRAY OF AFieldValue;
                                CheckReason : ACheckReason;
                            VAR Code        : CARDINAL ):BOOLEAN;
VAR
    InCode              : CARDINAL;
    TempAsOfDate        : ADate;
    TempAsOfSetting     : AnAsOfSettingOption;
    ok                  : BOOLEAN;
    Title               : ARRAY [0..41] OF CHAR;
    Protect             : BOOLEAN;
    Changed             : BOOLEAN;  (* RSC 10/15/87 *)
    PreemptedTheCode    : BOOLEAN;
    
BEGIN
    InCode := Code;
    Code := 0;
    PreemptedTheCode := FALSE; 

        (*  The Project Notes field  *)
    IF (FieldNo = CM1) THEN
        PutProjectNotes(FormValue[CM1].CharValue^);
        IF (InCode = ChngTskKey) AND (CheckReason = CheckFieldKey) THEN
            GetMessage(ModuleNumber + 3, Title);
            EditText(14,11,79,maxrow-1, ABoxType{ShadowBox, DoubleBox}, Title, ModuleNumber,
                     ProjectText, Changed);
            IF (Changed) THEN
                SetFormChange( Form );
            END;
            GetProjectNotes(FormValue[CM1].CharValue^);
            ShowValue(Form, CM1, FormValue);
            PreemptedTheCode := TRUE;
        END;
    ELSIF (FieldNo = AOS) OR
            ((FieldNo = DAT) AND (CheckReason = CheckFieldChange)) THEN
        IF (FormValue[DAT].CardValue = 0) THEN
            DefaultDateOption := ShowDate;
        ELSE
            DefaultDateOption := ShowDateAndTime;
        END;
        AsOfSettingOption := VAL(AnAsOfSettingOption,FormValue[AOS].CardValue);
        SetAsOfDate();
        Protect := (AsOfSettingOption <> AsOfWhenISay);
        SetFieldProtection(Form,ASD,FormValue,Protect);
        TimeUtoS(AsOfDate,FormValue[ASD].CharValue^);
        ShowValue(Form,ASD,FormValue);
    ELSIF (FieldNo = ASD) THEN                     (*  As-Of Date *)
        WITH FormValue[FieldNo] DO
              LJust(CharValue^);
              IF (CharValue^[0] = 0C) OR
                 (CharValue^[1] = " ") THEN
                  RETURN TRUE;
              ELSE
                  CardValue := Today;
                  ok := StoTimeU(CharValue^,CardValue);
                  IF (ok) THEN
                      AsOfDate := CardValue;
                      TimeUtoS(CardValue,CharValue^);
                  END;
                  ShowValue(Form,FieldNo,FormValue);
                  RETURN ok;
              END;
        END;
    ELSIF (FieldNo = UND) THEN
        WITH FormValue[FieldNo] DO
            IF (CardValue = 0) THEN
                CardValue := 1;
                ShowValue(Form,FieldNo,FormValue);
            END;
        END;
    END;

      (* 20-Jun-89 AJL   Return the passed-in code from the CheckProc unless
                         we explicitly override it.  *)

    IF (CheckReason = CheckFieldKey) AND (NOT PreemptedTheCode) THEN
        Code := InCode + CARDINAL({14});
    END;

    RETURN TRUE;
END CheckOptionsForm;







PROCEDURE DoOptionsForm;

CONST
    FormNumber = 9;

VAR
    Loop, i                 : CARDINAL;
    OldPlanningMethod       : CARDINAL;
    OldAsOfDate             : ADate;
    OldAsOfSetting          : AnAsOfSettingOption;
    OldDateOption           : ADateDisplayOption;
    OldNetworkType          : ANetworkType;
    OldAnnealingChoice      : AnAnnealingChoice;
    FormValue               : ARRAY [0..TopField] OF AFieldValue;
    StringFields            : ARRAY [1..OptionsStringCount] OF AStringValue;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    i := 0;
    FOR Loop := 0 TO TopField DO
        IF (Loop IN OptionsStringFields) THEN
            INC(i);
            FormValue[Loop].CharValue := ADR( StringFields[i] );
        ELSE
            FormValue[Loop].CharValue := NIL;
        END;
    END;

    OldAsOfDate             := AsOfDate;
    OldDateOption           := DefaultDateOption;
    OldAsOfSetting          := AsOfSettingOption;

    OldAnnealingChoice      := AnnealingChoice;     (* 8/18/89 EGK *)
    OldNetworkType          := NetworkType;

    Copy (FullScheduleName, FormValue[FSN].CharValue^);
    GetProjectNotes(FormValue[CM1].CharValue^);
    Copy (Author, FormValue[PMF].CharValue^);

    CASE DefaultDateOption OF
        ShowDate :
            FormValue[DAT].CardValue := 0;
    |   ShowDateAndTime :
            FormValue[DAT].CardValue := 1;
    |   ShowTime :
            FormValue[DAT].CardValue := 1;
    ELSE
            FatalError();
    END;

    FormValue[AOS].CardValue := ORD(AsOfSettingOption);
    TimeUtoS(AsOfDate,FormValue[ASD].CharValue^);

    FormValue[MON].CardValue := ORD(AdvancedTaskForm);
    FormValue[CST].CardValue := ORD(UsesCostTracking);
    FormValue[UND].CardValue := GetUndoLimit();
    WITH FixedDateRules DO
        FormValue[SDR].CardValue := ORD(StartDateMustStart); (* 24-Oct-90 PFG *)
        FormValue[FCR].CardValue := ORD(ForceCritical); (* 24-Oct-90 PFG *)
    END;

    i := ORD(AnnealingChoice);
    IF (i = 2) THEN
        i := 1;         (* Change "Presentation" to "Average" *)
    END;
    FormValue[ANN].CardValue := i;          (* 11/6/89 EGK *)

    FormValue[NTP].CardValue := ORD(NetworkType);     (* 5/8/89 WKH *)

    IF (DoForm (0, 0, maxcol, GanttWEnd, FormNumber, TRUE, FormValue,
            CheckOptionsForm) = ExitKey) THEN

        Copy (FormValue[FSN].CharValue^, FullScheduleName);
        TrimRear(FullScheduleName);
        PutProjectNotes(FormValue[CM1].CharValue^);
        Copy (FormValue[PMF].CharValue^, Author);
        TrimRear (Author);

        IF (FormValue[DAT].CardValue = 0) THEN
            DefaultDateOption := ShowDate;
        ELSE
            DefaultDateOption := ShowDateAndTime;
        END;

        AsOfSettingOption    := VAL(AnAsOfSettingOption,FormValue[AOS].CardValue);

        IF ((AsOfDate <> OldAsOfDate) OR (AsOfSettingOption <> OldAsOfSetting)) THEN  (* 04-Jan-88 LAA *)
            UnSetState(Scheduled);
        END;

        WITH FixedDateRules DO
            StartDateMustStart := VAL(BOOLEAN, FormValue[SDR].CardValue);
            ForceCritical      := VAL(BOOLEAN, FormValue[FCR].CardValue);
        END;

        AdvancedTaskForm   := VAL(BOOLEAN, FormValue[MON].CardValue);
        UsesCostTracking   := VAL(BOOLEAN, FormValue[CST].CardValue);
        SetUndoLimit(FormValue[UND].CardValue);

        (* Set the flags so the schedule and the config need to be saved *)

        ScheduleSaved    := FALSE;
        ConfigSaved      := FALSE;
        UnSetState (Formatted);

        AnnealingChoice := VAL(AnAnnealingChoice, FormValue[ANN].CardValue);  (* 5/8/89 WKH *)
        NetworkType     := VAL(ANetworkType, FormValue[NTP].CardValue);        (* 5/8/89 WKH *)

        IF (AnnealingChoice <> OldAnnealingChoice) OR
               (NetworkType <> OldNetworkType) THEN
            SendNotices (NetworkSettingChange, AfterActing, NIL);  (* 8/18/89 EGK *)
        END;

    ELSE
        DefaultDateOption := OldDateOption;
        AsOfDate          := OldAsOfDate;
        AsOfSettingOption := OldAsOfSetting;
    END;

END DoOptionsForm;





BEGIN

    OverlayID := ImAnInstallableOverlay(DoOptionsForm, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    DoOptionsForm;

END TLSchFor.
