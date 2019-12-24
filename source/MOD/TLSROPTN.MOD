MODULE TLSROPTN;
(*  =========================================================================
    Last Edit : August 9, 1991 10:39AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Status Report options form.

    MODIFICATION HISTORY:

        06-APR-89 KKC First version
        21-Jul-89 KKC - Allow user to leave the column width fields if is
                        empty.
        27-Jul-89 KKC - Pop up calculator if F2 key is pressed in a numeric
                        field.
        10-Aug-89 KKC - Add copyright message.
        11-Aug-89 KKC - Pass Pointer instead of address.
                      - Add three blank lines between procedures.
        14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
        20-Oct-89 KKC - Disallow user from mixing baseline assignments and
                        current assignments.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.
        1-Oct-90 PFG    Did the same for resource and assignment columns that
                        I just did for task columns.
        23-Jan-91 RSC   Moved holder item into FlexStor.
        13-Feb-91 RSC   Added "HeapNoOwner" to Holder category.
        20-Mar-91 AJL - Moved the record definitions shared with TLSR
                        to TLSRRec.
                      - Added more error checking.
        20-May-91 PFG   A crucial missing set of parentheses around an AND
                        statement in DoStatusForms meant that the new values
                        in InputForms were never getting put into FlexStor
                        and the report never got run.
         3-Jun-91 PFG   Because the form values are saved from one use of the
                        report form to the next, changes in column names
                        weren't taking effect.  Now we call captions procs for
                        each column on the form to update its name.
        10-Jun-91 PFG   Call GetTaskColumnName() and GetAssgColumnName() to 
                        fix a problem where pressing ESC from a pick list 
                        after changing a column name, the data columns 
                        whose contents had been changed didn't get refreshed 
                        properly.
         1-Jul-91 PFG   The ReturnOK value in the holder record wasn't getting
                        saved to FlexStor if the user ESC'd out of either form,
                        so TLSR proceeded as if the user had pressed F10.  
                        ReturnOK is now updated.  If F10 WAS pressed, we now
                        pass along information that shows that this form was
                        changed so that the Page Options form will know.
         9-Aug-91 PFG   Okay...marketing and QA didn't like part of my last 
                        change.  So now we save the first form regardless of
                        whether you pressed ESC or F10 on the second one.
        24-Sep-91 LAA   For bug #5182, put checks into the form checkproc to
                        set CardValue to zero if the column name doesn't
                        check out.
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM AssColumns             IMPORT
    (* PROCS *)                 CreateAssColumnsTree, PickAssColumn,
                                DisposeAssColumnsTree, SearchForAssColumn,
                                GetAssgColumnName;

FROM AssFormat              IMPORT
    (* VAR   *) (* PROC *)      GetAssInfo;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
    (* VAR   *) (* PROC *)      GetColumnInfo;

FROM Codes                  IMPORT
    (* TYPE  *)                 ACode;

FROM Dialog                 IMPORT
    (* PROC  *)                 FatalError, Error, Burp, NotYetImplemented;

FROM FlexStor               IMPORT
    (* TYPE  *)                 AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  GetExtData, SetExtData, LockObject,
                                ReleaseObject, CreateExtObjectWithSize;

FROM FormCon                IMPORT
    (* TYPE  *)                 AFieldNo;

FROM Forms                  IMPORT
    (* TYPE  *)                 AFieldValue, AForm, ACheckReason,
                                ACursorAttribute, AStringValue,
    (* PROC  *)                 SetFieldHidden, SetFieldProtection,
                                ShowValue, SetFormChange, DoForm,
                                HighlightField;

FROM Holder                 IMPORT
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem, HoldThis, DeleteHeldItem;

FROM Kbio                   IMPORT
    (* CONST *)                 maxrow, maxcol;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, EditKey, MoveUpKey, MoveDownKey;

FROM Layout                 IMPORT
    (* VAR   *)                 GanttWEnd;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, StoC, Copy,
                                ConcatLS, SetLengthOf, SubStr,
                                TrimRear, TrimFront, SetString, Fill;

FROM MagicNum               IMPORT
    (* CONST *)                 BsLnBillable;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage;

FROM PageRepeat             IMPORT
    (* TYPE  *)                 APageRepeatSettings,
    (* PROC  *)                 InitPageRepeatSettings;

FROM PageOptn               IMPORT
    (* PROC  *)                 DoPageRepeatForm;

FROM ParseTime              IMPORT
    (* PROC  *)                 StoTimeU;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE  *)                 ADDRESS, ADR, TSIZE;

FROM TaskColumns            IMPORT
    (* PROCS *)                 CreateTaskColumnsTree, PickTaskColumn,
                                DisposeTaskColumnsTree, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Timei                  IMPORT
    (* CONST *)                 MinDate,
    (* TYPE  *)                 ADate, ADurationUnit;

FROM TLSRRec                IMPORT
    (* CONST *)                 LASTTASKINFO, LASTASSIGNINFO,
    (* TYPE *)                  AReportChoices, AGroupMethod, AShowMethod   ,
                                ADateInfo, AColumnInfo,
                                AColumnPrintStatus,
                                AStatusFormInputValues, AStatusFormInputValuesPtr,
                                AStatusReportPrintControls, AStatusReportPrintControlsPtr;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode;

CONST
    ModuleNumber        =   7900;
    MaxWidth            =   255;
    MaxColumnWidth      =   255;
    TLSRFORMID          =   48;
    TLRPFORMID          =   58;
    Normal              =   0;
    Bold                =   1;

    STATUSFOR           =   0;
    WHATSHOW            =   1;
    DAILY               =   2;
    DAILYDAYS           =   3;
    WEEKLY              =   4;
    WEEKLYWEEKS         =   5;
    MONTHLY             =   6;
    MONTHLYMONTHS       =   7;
    TASKSUM             =   8;
    INCLUDEPASTDUE      =   9;
    GROUPBY             =   10;
    FIRSTTASKFLD        =   11;
    LASTTASKFLD         =   22;
    FIRSTASSIGNFLD      =   23;
    LASTASSIGNFLD       =   34;

    LastStatusFormFld   =   34;

    NBottomRowsReserved =   2;

    NSpcsBetweenFld     =   2;
    MaxPrintWidth       =   255;


TYPE

(* dummy  in AStatus is used to force AStatusSet fall into two bytes *)

    AStatus         =     (SelfStart, SelfEnd,
                           SelfContinue, SelfDelayed,
                           InStartList, InEndList,
                           InContinueList, InDelayedList,
                           dummy);

    AStatusSet      =     SET OF AStatus;



VAR


(****************************************************************************
    SetColumnInfo -
        Set up the ColumnInfo in AStatusReportSettings based on
        the value in FormValueArray.
        FormValueArray contains the information inputed from user.
****************************************************************************)
PROCEDURE SetColumnInfo(
                            VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                              ColumnInfoIndex : CARDINAL;
                            VAR     FormValue : ARRAY OF AFieldValue;
                               FormValueIndex : CARDINAL
                           );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    i, i2, i3               :   CARDINAL;
BEGIN


    Copy(FormValue[FormValueIndex].CharValue^,
                                  ColumnInfoArr[ColumnInfoIndex].ColumnName);
    ColumnInfoArr[ColumnInfoIndex].ColumnID :=
                                          FormValue[FormValueIndex].CardValue;

    TrimFront(ColumnInfoArr[ColumnInfoIndex].ColumnName);

    ColumnInfoArr[ColumnInfoIndex].IsBlankColumn := FALSE;
    IF (LengthOf(ColumnInfoArr[ColumnInfoIndex].ColumnName) = 0) THEN
        ColumnInfoArr[ColumnInfoIndex].ColumnWidth := 0;
        RETURN;
    END;

    i := 1;
    ColumnInfoArr[ColumnInfoIndex].ColumnWidth :=
                          StoC(FormValue[FormValueIndex + 1].CharValue^, i);
    i3 :=  LengthOf(FormValue[FormValueIndex+1].CharValue^);

    IF (i > i3)  THEN RETURN; END;

    FOR i2 := i TO i3 DO
        GetMessage(ModuleNumber + 28, Line);  (* Blank *)
        IF (FormValue[FormValueIndex + 1].CharValue^[i2] = Line[1] ) THEN
            ColumnInfoArr[ColumnInfoIndex].IsBlankColumn := TRUE;
        END;
    END;

END SetColumnInfo;




(****************************************************************************
    SetStatusInputSettings -
        Set up the AStatusReportSettings based on the value in FormValueArray.
        FormValueArray contains the information inputed from user.
****************************************************************************)
PROCEDURE SetStatusInputSettings(
                                 VAR FormValue  : ARRAY OF AFieldValue;
                                 VAR Inputs     : AStatusFormInputValues
                                );
VAR
    i, i2                   :   CARDINAL;
BEGIN

    WITH Inputs DO
        HowToReport := VAL(AReportChoices, FormValue[STATUSFOR].CardValue);
        OpenSummary := VAL(BOOLEAN, FormValue[TASKSUM].CardValue);
        IncludePastDue := VAL(BOOLEAN, FormValue[INCLUDEPASTDUE].CardValue);
        HowToGroup := VAL(AGroupMethod, FormValue[GROUPBY].CardValue);
        WhatToShow := VAL(AShowMethod, FormValue[WHATSHOW].CardValue);

        FOR i := 0 TO LASTTASKINFO DO
            InitColumnInfo(TaskColumn, i);
        END;

        i2 := 0;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
            SetColumnInfo(TaskColumn, i2, FormValue, i);
            IF ( LengthOf( TaskColumn[i2].ColumnName ) > 0 ) THEN
                INC(i2);
            END;
        END;

        FOR i := 0 TO LASTASSIGNINFO DO
            InitColumnInfo(AssignColumn, i);
        END;

        i2 := 0;
        FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
            SetColumnInfo(AssignColumn, i2, FormValue, i);
            IF ( LengthOf( AssignColumn[i2].ColumnName  ) > 0 ) THEN
                INC(i2);
            END;
        END;

        Copy(FormValue[DAILY].CharValue^, DailyRange.DateString);
        TrimFront(DailyRange.DateString);
        IF ( ( LengthOf( DailyRange.DateString ) > 0 )
            AND
             ( StoTimeU(DailyRange.DateString, DailyRange.DateValue) ) ) THEN
            DailyRange.DateDuration := FormValue[DAILYDAYS].CardValue;
        END;

        Copy(FormValue[WEEKLY].CharValue^, WeeklyRange.DateString);
        TrimFront(WeeklyRange.DateString);
        IF ( ( LengthOf( WeeklyRange.DateString ) > 0 )
            AND
             ( StoTimeU(WeeklyRange.DateString, WeeklyRange.DateValue) ) ) THEN
            WeeklyRange.DateDuration := FormValue[WEEKLYWEEKS].CardValue;
        END;

        Copy(FormValue[MONTHLY].CharValue^, MonthlyRange.DateString);
        TrimFront(MonthlyRange.DateString);
        IF ( ( LengthOf( MonthlyRange.DateString ) > 0 )
            AND
             ( StoTimeU(MonthlyRange.DateString, MonthlyRange.DateValue) ) ) THEN
            MonthlyRange.DateDuration := FormValue[MONTHLYMONTHS].CardValue;
        END;

        IF ( HowToReport = EachResourceStatus ) THEN
            OpenSummary := FALSE;
        END;
    END;

END SetStatusInputSettings;




(* ***************  Form related stuffs start ***************** *)

(****************************************************************************
    EnoughInputsAndAllInputsOk  -
        Make sure we have all the parameters we need.
****************************************************************************)
PROCEDURE EnoughInputsAndAllInputsOk(
                                     VAR FormValue : ARRAY OF AFieldValue
                                    ) : BOOLEAN;
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    GotDateRange            :   BOOLEAN;
    TmpString               :   AStringValue;
    GotColumn               :   BOOLEAN;
    CurrentAssignExist      :   BOOLEAN;
    BslnAssignExist         :   BOOLEAN;
    i                       :   CARDINAL;
BEGIN
    GotDateRange := FALSE;
    Copy( FormValue[DAILY].CharValue^, TmpString );
    TrimRear(TmpString);
    IF ( ( LengthOf (TmpString) <> 0 )
         AND
         ( FormValue[DAILYDAYS].CardValue <> 0 ) ) THEN
        GotDateRange := TRUE;
    END;

    Copy( FormValue[WEEKLY].CharValue^, TmpString );
    TrimRear(TmpString);
    IF ( ( LengthOf (TmpString) <> 0 )
         AND
         ( FormValue[WEEKLYWEEKS].CardValue <> 0 ) ) THEN
        GotDateRange := TRUE;
    END;

    Copy( FormValue[MONTHLY].CharValue^, TmpString );
    TrimRear(TmpString);
    IF ( ( LengthOf (TmpString) <> 0 )
         AND
         ( FormValue[MONTHLYMONTHS].CardValue <> 0 ) ) THEN
        GotDateRange := TRUE;
    END;

    IF ( NOT GotDateRange ) THEN
        GetMessage ( ModuleNumber + 30, Line );
        Error(Line);
        RETURN FALSE;
    END;

    GotColumn := FALSE;
    FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
        Copy( FormValue[i].CharValue^, TmpString );
        TrimRear(TmpString);
        IF ( LengthOf(TmpString) <> 0 ) THEN
            GotColumn := TRUE;
        END;
    END;

    BslnAssignExist := FALSE;
    CurrentAssignExist := FALSE;
    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
        Copy( FormValue[i].CharValue^, TmpString );
        TrimRear(TmpString);
        IF ( LengthOf(TmpString) <> 0 ) THEN
            GotColumn := TRUE;
            IF ( FormValue[i].CardValue < BsLnBillable ) THEN
                CurrentAssignExist := TRUE;
            ELSE
                BslnAssignExist := TRUE;
            END;
        END;
    END;

    IF ( NOT GotColumn ) THEN
        GetMessage ( ModuleNumber + 14, Line );
        Error(Line);
        RETURN FALSE;
    ELSIF ( CurrentAssignExist AND BslnAssignExist ) THEN
        GetMessage(ModuleNumber + 35, Line);          (* Cannot mix baseline and current assignments *)
        Error(Line);
        RETURN FALSE;
    END;
    RETURN TRUE;
END EnoughInputsAndAllInputsOk;




PROCEDURE DoPickTaskColumn(
                                      Form : AForm;
                                   FieldNo : AFieldNo;
                             VAR FormValue : ARRAY OF AFieldValue
                            ) : BOOLEAN;
CONST
    TaskBoxLeft             =   50;
    TaskBoxRight            =   79;
    TaskBoxTop              =   3;
VAR
    Column                  :   CARDINAL;
    Width                   :   CARDINAL;
    TaskBoxBottom           :   CARDINAL;
    i                       :   CARDINAL;
    DataRecord              :   AColumnDataRecord;
    T                       :   ATaskPtr;
    Node                    :   ATreeNode;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN
    TaskBoxBottom           :=   maxrow-8;
    Column := FormValue[FieldNo].CardValue;
    IF (NOT PickTaskColumn(TaskBoxLeft, TaskBoxTop,
                           TaskBoxRight, TaskBoxBottom, Column, Line)) THEN
        RETURN FALSE
    END;
    IF ( (FormValue[FieldNo].CardValue <> Column) OR
          (FormValue[FieldNo + 1].CardValue = 0) ) THEN
         T := NIL;                             (* 08-Feb-88 LAA *)
         GetColumnInfo(NIL, T, Column, ColumnWidth, maxcol, DataRecord);
         FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue;
         SetFieldProtection(Form,FieldNo+1,FormValue,FALSE);
    END;
    FormValue[FieldNo].CardValue := Column;

    RETURN TRUE;
END DoPickTaskColumn;




PROCEDURE DoPickAssignColumn(
                                           Form : AForm;
                                        FieldNo : AFieldNo;
                                  VAR FormValue : ARRAY OF AFieldValue
                                 ) : BOOLEAN;
CONST
    AssignBoxLeft           =   0;
    AssignBoxRight          =   29;
    AssignBoxTop            =   3;
VAR
    Column                  :   CARDINAL;
    Width                   :   CARDINAL;
    AssignBoxBottom         :   CARDINAL;
    i                       :   CARDINAL;
    DataRecord              :   AColumnDataRecord;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN
    AssignBoxBottom         :=   maxrow-8;
    Column := FormValue[FieldNo].CardValue;
    IF (NOT PickAssColumn(AssignBoxLeft, AssignBoxTop,
                              AssignBoxRight, AssignBoxBottom, Column, Line)) THEN
        RETURN FALSE
    END;

    IF ( (FormValue[FieldNo].CardValue <> Column) OR
          (FormValue[FieldNo + 1].CardValue = 0) ) THEN
        IF ( NOT GetAssInfo(Column, AColumnInfoChoice(ColumnWidth),
                            Width, DataRecord) ) THEN
            RETURN FALSE;
        END;
        FormValue[ FieldNo+1 ].CardValue := DataRecord.CardinalValue;
        SetFieldProtection(Form, FieldNo+1, FormValue, FALSE);
    END;
    FormValue[FieldNo].CardValue := Column;

    RETURN TRUE;
END DoPickAssignColumn;




PROCEDURE CheckStatusForm(          Form : AForm;
                                     FieldNo : AFieldNo;
                               VAR FormValue : ARRAY OF AFieldValue;
                                 CheckReason : ACheckReason;
                                    VAR Code : CARDINAL
                             ) : BOOLEAN;
VAR
    TmpString               :   AStringValue;
    TmpColumn               :   CARDINAL;
    TmpDate                 :   ADate;
    ok                      :   BOOLEAN;
    i                       :   CARDINAL;
    TasksStatus             :   BOOLEAN;
    NoName                  :   BOOLEAN;
    NoDate                  :   BOOLEAN;
    NotShowAssignWidth      :   BOOLEAN;
    TempField               :   AFieldValue;
    CodeIn                  :   CARDINAL;
    Line                    :   ARRAY[0..MaxWidth] OF CHAR;
BEGIN

    CodeIn := Code;
    Code := 0;

    CASE CheckReason OF
        | CheckFormEntry    :   ;
            CASE FieldNo OF
                | STATUSFOR:
                   TasksStatus := (FormValue[STATUSFOR].CardValue = 0);
                   FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
                      SetFieldHidden(Form, i, FormValue, TasksStatus);
                      SetFieldProtection(Form, i, FormValue, TasksStatus);
                   END;
                   SetFieldHidden(Form, TASKSUM, FormValue, NOT TasksStatus);
                   SetFieldProtection(Form, TASKSUM, FormValue,
                                      NOT TasksStatus);
                   SetFieldHidden(Form, WHATSHOW, FormValue, TasksStatus);
                   SetFieldProtection(Form, WHATSHOW, FormValue, TasksStatus);
                   RETURN TRUE;
                | FIRSTTASKFLD..LASTTASKFLD:
                   (* If column width then return *)
                   IF ( ( ( FieldNo + FIRSTTASKFLD ) MOD 2 ) = 1 ) THEN
                      RETURN TRUE;
                   END;
                   NoName := (LengthOf( FormValue[FieldNo].CharValue^ ) = 0);
                   SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
                   SetFieldProtection(Form, FieldNo + 1, FormValue, NoName);
                   RETURN TRUE;
                | FIRSTASSIGNFLD..LASTASSIGNFLD:
                   (* If column width then return *)
                   IF ( ( ( FieldNo + FIRSTASSIGNFLD ) MOD 2 ) = 1 ) THEN
                      RETURN TRUE;
                   END;
                   TasksStatus := (FormValue[STATUSFOR].CardValue = 0);
                   NoName := (LengthOf( FormValue[FieldNo].CharValue^ ) = 0);
                   NotShowAssignWidth := ( TasksStatus OR NoName ) ;
                   SetFieldHidden(Form, FieldNo + 1, FormValue,
                                                          NotShowAssignWidth);
                   SetFieldProtection(Form, FieldNo + 1, FormValue,
                                                          NotShowAssignWidth);
                   RETURN TRUE;
                | DAILY, WEEKLY, MONTHLY:
                   NoDate := (LengthOf( FormValue[FieldNo].CharValue^ ) = 0);
                   SetFieldHidden(Form, FieldNo + 1, FormValue, NoDate);
                   SetFieldProtection(Form, FieldNo + 1,  FormValue, NoDate);
                   RETURN TRUE;
            ELSE
                RETURN TRUE;
            END;

        | CheckFormExit :
                RETURN (EnoughInputsAndAllInputsOk( FormValue ) );
        | CheckFieldEntry   :    ;
        | CheckFieldChange:   ;
            CASE FieldNo OF
                | STATUSFOR:
                   TasksStatus := (FormValue[FieldNo].CardValue = 0);
                   FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
                      SetFieldHidden(Form, i, FormValue, TasksStatus);
                      SetFieldProtection(Form, i, FormValue, TasksStatus);
                   END;
                   SetFieldHidden(Form, TASKSUM, FormValue, NOT TasksStatus);
                   SetFieldProtection(Form, TASKSUM, FormValue,
                                      NOT TasksStatus);
                   SetFieldHidden(Form, WHATSHOW, FormValue, TasksStatus);
                   SetFieldProtection(Form, WHATSHOW, FormValue, TasksStatus);
                   SetFormChange(Form);
                | DAILY, WEEKLY, MONTHLY:
                   Copy(FormValue[FieldNo].CharValue^, TmpString);
                   TrimFront(TmpString);
                   NoDate := ( LengthOf( TmpString ) = 0);

                   IF ( NOT NoDate ) THEN
                      ok := StoTimeU (TmpString, TmpDate);
                   ELSE
                      ok := TRUE;
                   END;

                   IF ( NOT ok ) THEN
                      Burp();
                      RETURN FALSE;
                   END;

                   FormValue[FieldNo].CardValue := TmpDate;
                   SetFieldHidden(Form, FieldNo + 1, FormValue, NoDate);
                   SetFieldProtection(Form, FieldNo + 1, FormValue, NoDate);
                   SetFormChange(Form);
                   RETURN TRUE;
            ELSE
            END;
            RETURN TRUE;
        | CheckFieldExit    :
            CASE FieldNo OF
                | FIRSTTASKFLD..LASTTASKFLD,
                  FIRSTASSIGNFLD..LASTASSIGNFLD:
                      (* if column name *)
                      IF ( ( ( FieldNo + FIRSTTASKFLD ) MOD 2 ) = 0 ) THEN
                         Copy(FormValue[FieldNo].CharValue^, TmpString);
                         TrimFront(TmpString);
                         IF ( LengthOf(TmpString) <> 0 ) THEN
                            IF ( ( FieldNo >= FIRSTTASKFLD )
                                AND
                                 ( FieldNo <= LASTTASKFLD ) ) THEN
                                ok := SearchForTaskColumn(TmpString, TmpColumn);
                            ELSE
                                ok := SearchForAssColumn(TmpString, TmpColumn);
                            END;
                            IF ( NOT ok ) THEN
                                Burp();
                                RETURN FALSE;
                            END;
                            FormValue[FieldNo].CardValue := TmpColumn;
                         ELSE
                            FormValue[FieldNo].CardValue := 0; (* 24-Sep-91 *)
                         END;
                         NoName := ( LengthOf( TmpString ) = 0);
                         SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
                         SetFieldProtection(Form, FieldNo + 1, FormValue,
                                            NoName);
                         RETURN TRUE;
                      END;
                      i := 1;
                      FormValue[FieldNo].CardValue :=
                           StoC(FormValue[FieldNo].CharValue^, i);
                      IF (FormValue[FieldNo].CardValue > MaxColumnWidth ) THEN
                            GetMessage( ModuleNumber + 34, Line); (* Column width too wide *)
                            Error(Line);
                            RETURN FALSE;
                      END;
                      IF (FormValue[FieldNo].CardValue = 0) THEN
                         SetLengthOf( FormValue[FieldNo].CharValue^, 0 );
                      END;
                      ShowValue( Form, FieldNo, FormValue );
                      RETURN TRUE;
            ELSE
            END;
        | CheckFieldKey  :
            IF (
                 ( FieldNo < FIRSTTASKFLD )
                OR
                 ( FieldNo > LASTASSIGNFLD )
                OR
                 (((FieldNo + FIRSTTASKFLD) MOD 2) = 1) (* Column Width *)
               ) THEN
                Code := 04000H + CodeIn;
                RETURN TRUE;
            END;

            IF ( CodeIn = MoveUpKey ) THEN
                IF ( ( FieldNo = FIRSTTASKFLD )
                     OR
                     ( FieldNo = FIRSTASSIGNFLD ) ) THEN
                    Burp();
                    RETURN FALSE;
                END;
                TempField := FormValue[FieldNo - 2];
                FormValue[FieldNo - 2] := FormValue[FieldNo];
                FormValue[FieldNo] := TempField;
                TempField := FormValue[FieldNo - 1];
                FormValue[FieldNo - 1] := FormValue[FieldNo + 1];
                FormValue[FieldNo + 1] := TempField;
                ShowValue(Form, FieldNo - 2, FormValue);
                ShowValue(Form, FieldNo - 1, FormValue);
                ShowValue(Form, FieldNo, FormValue);
                ShowValue(Form, FieldNo + 1, FormValue);
                Code := 08000H + FieldNo - 2;
                SetFormChange(Form);
                RETURN TRUE;
            END;

            IF ( CodeIn = MoveDownKey ) THEN
                IF ( ( FieldNo = ( LASTTASKFLD - 1 ) )
                     OR
                     ( FieldNo = ( LASTASSIGNFLD - 1 ) ) ) THEN
                    Burp();
                    RETURN FALSE;
                END;
                TempField := FormValue[FieldNo + 2];
                FormValue[FieldNo + 2] := FormValue[FieldNo];
                FormValue[FieldNo] := TempField;
                TempField := FormValue[FieldNo + 3];
                FormValue[FieldNo + 3] := FormValue[FieldNo + 1];
                FormValue[FieldNo + 1] := TempField;
                ShowValue(Form, FieldNo, FormValue);
                ShowValue(Form, FieldNo + 1, FormValue);
                ShowValue(Form, FieldNo + 2, FormValue);
                ShowValue(Form, FieldNo + 3, FormValue);
                Code := 08000H + FieldNo + 2;
                SetFormChange(Form);
                RETURN TRUE;
            END;

            (* CodeIn = EditKey *)

            HighlightField( Form, FormValue, FieldNo, CursorResting);
            CASE FieldNo OF
                | FIRSTTASKFLD..LASTTASKFLD:
                    IF (NOT SearchForTaskColumn (FormValue[FieldNo].CharValue^,   (* 24-Sep-91 *)
                                                 FormValue[FieldNo].CardValue)) THEN
                        FormValue[FieldNo].CardValue := 0;
                    END;
                    ok := DoPickTaskColumn(Form, FieldNo, FormValue);

                    (* In case column names were edited, update all column
                        names on form.  Need to do this even if PickTaskColumn
                        returns FALSE, since the user may have changed some 
                        column other than the highlighted one.  *)

                    FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
                        IF FormValue[i].CardValue <> 0 THEN
                            GetTaskColumnName(  FormValue[i].CardValue,
                                                FormValue[i].CharValue^);
                        ELSE
                            Fill(FormValue[i].CharValue^, " ", 24);
                            FormValue[i + 1].CardValue := 0;
                        END;
                    END;

                    (*  Redisplay the column names and widths  *)

                    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
                        ShowValue(Form, i, FormValue);
                    END;

                | FIRSTASSIGNFLD..LASTASSIGNFLD:
                    IF (NOT SearchForAssColumn( FormValue[FieldNo].CharValue^,  (* 24-Sep-91 *)
                                                FormValue[FieldNo].CardValue )) THEN
                        FormValue[FieldNo].CardValue := 0;
                    END;
                    ok := DoPickAssignColumn(Form, FieldNo, FormValue);

                    (* In case column names were edited, update all column
                        names on form.  Need to do this even if PickAssColumn
                        returns FALSE, since the user may have changed some 
                        column other than the highlighted one.  *)

                    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
                        IF FormValue[i].CardValue <> 0 THEN
                            GetAssgColumnName(  FormValue[i].CardValue,
                                                FormValue[i].CharValue^);
                        ELSE
                            Fill(FormValue[i].CharValue^, " ", 24);
                            FormValue[i + 1].CardValue := 0;
                        END;
                    END;

                    (*  Redisplay the column names and widths  *)

                    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
                        ShowValue(Form, i, FormValue);
                    END;

            END;
            HighlightField( Form, FormValue, FieldNo, CursorOff);

            IF (NOT ok) THEN
                RETURN FALSE;
            END;

            CtoS(FormValue[FieldNo+1].CardValue,
                 FormValue[FieldNo+1].CharValue^);

            SetFieldHidden(Form, FieldNo + 1, FormValue, FALSE);
            SetFieldProtection(Form, FieldNo + 1, FormValue, FALSE);

            ShowValue( Form, FieldNo, FormValue );
            ShowValue( Form, FieldNo+1, FormValue );
            SetFormChange(Form);
     END;

     RETURN TRUE;

END CheckStatusForm;




(****************************************************************************
    TerminateUsingFormValue -
        It deallocates storage for all buffers that are allocated in
    StartUsingFormValue and set all pointers in FormValue to NIL.
****************************************************************************)
PROCEDURE TerminateUsingFormValue(VAR FormValue : ARRAY OF AFieldValue);
VAR
    i                       :   CARDINAL;
BEGIN

    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
        DISPOSE(FormValue[i].CharValue);
        FormValue[i].CharValue := NIL;   (* Safely !!! *)
    END;

    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
        DISPOSE(FormValue[i].CharValue);
        FormValue[i].CharValue := NIL;   (* Safely !!! *)
    END;

    DISPOSE(FormValue[DAILY].CharValue);
    FormValue[DAILY].CharValue := NIL; (* Safely !!! *)

    DISPOSE(FormValue[WEEKLY].CharValue);
    FormValue[WEEKLY].CharValue := NIL; (* Safely !!! *)

    DISPOSE(FormValue[MONTHLY].CharValue);
    FormValue[MONTHLY].CharValue := NIL; (* Safely !!! *)

END TerminateUsingFormValue;




(****************************************************************************
    InitColumnField -
        Initialize the pointers for Column name info in FormValueArray.
        Since we are using some of the buffer from FormInputs, we only
    allocate the buffer that has not defined.  All variable will be set
    based on the value in FormInputs.
****************************************************************************)
PROCEDURE InitColumnField(
                          VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                            ColumnInfoIndex : CARDINAL;
                          VAR     FormValue : ARRAY OF AFieldValue;
                             FormValueIndex : CARDINAL
                         );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    OneCharBuffer           :   ARRAY[0..1] OF CHAR;
BEGIN

    Copy(ColumnInfoArr[ColumnInfoIndex].ColumnName,
                                        FormValue[FormValueIndex].CharValue^);
    FormValue[FormValueIndex].CardValue :=
                                     ColumnInfoArr[ColumnInfoIndex].ColumnID;

    FormValue[FormValueIndex + 1].CardValue :=
                                  ColumnInfoArr[ColumnInfoIndex].ColumnWidth;
    SetLengthOf( FormValue[FormValueIndex + 1].CharValue^, 0 );
    IF (FormValue[FormValueIndex + 1].CardValue <> 0) THEN
        CtoS(FormValue[FormValueIndex + 1].CardValue,
                                    FormValue[FormValueIndex + 1].CharValue^);
        IF (ColumnInfoArr[ColumnInfoIndex].IsBlankColumn) THEN
            GetMessage(ModuleNumber + 28, Line);  (* Blank *)
            SubStr(Line, OneCharBuffer, 1, 1);
            ConcatLS(FormValue[FormValueIndex + 1].CharValue^, OneCharBuffer);
        END;
    END;
END InitColumnField;




(****************************************************************************
    AllocateFormValue -
        Allocate buffers for form value array.
****************************************************************************)
PROCEDURE AllocateFormValue( VAR FormValue : ARRAY OF AFieldValue );
VAR
    i                       :   CARDINAL;
BEGIN

    NEW(FormValue[DAILY].CharValue);
    NEW(FormValue[WEEKLY].CharValue);
    NEW(FormValue[MONTHLY].CharValue);

    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
        NEW(FormValue[i].CharValue);
    END;

    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
        NEW(FormValue[i].CharValue);
    END;
END AllocateFormValue;




(****************************************************************************
    StartUsingFormValue -
    Allocate the buffers for form value array.  All variable will be set
    based on the value in FormInputs.
****************************************************************************)
PROCEDURE StartUsingFormValue(
                              VAR FormValue : ARRAY OF AFieldValue;
                              VAR Inputs    : AStatusFormInputValues
                             );
VAR
    i, i2                   :   CARDINAL;
BEGIN

    AllocateFormValue( FormValue );

    WITH Inputs DO
        FormValue[STATUSFOR].CardValue := ORD(HowToReport);
        FormValue[TASKSUM].CardValue := ORD(OpenSummary);
        FormValue[INCLUDEPASTDUE].CardValue := ORD(IncludePastDue);
        FormValue[GROUPBY].CardValue := ORD(HowToGroup);
        FormValue[WHATSHOW].CardValue := ORD(WhatToShow);

        Copy(DailyRange.DateString, FormValue[DAILY].CharValue^);
        FormValue[DAILY].CardValue := DailyRange.DateValue;
        FormValue[DAILYDAYS].CardValue := DailyRange.DateDuration;

        Copy(WeeklyRange.DateString, FormValue[WEEKLY].CharValue^);
        FormValue[WEEKLY].CardValue := WeeklyRange.DateValue;
        FormValue[WEEKLYWEEKS].CardValue := WeeklyRange.DateDuration;

        Copy(MonthlyRange.DateString, FormValue[MONTHLY].CharValue^);
        FormValue[MONTHLY].CardValue := MonthlyRange.DateValue;
        FormValue[MONTHLYMONTHS].CardValue := MonthlyRange.DateDuration;

        i2 := 0;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
            InitColumnField(TaskColumn, i2, FormValue, i);
            INC(i2);
        END;

        i2 := 0;
        FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
            InitColumnField(AssignColumn, i2, FormValue, i);
            INC(i2);
        END;
    END;
END StartUsingFormValue;




PROCEDURE DisposeAllColumnTrees();
BEGIN
    DisposeTaskColumnsTree();
    DisposeAssColumnsTree();
END DisposeAllColumnTrees;




PROCEDURE BuildAllColumnTrees() : BOOLEAN;
VAR
BEGIN
    IF ( NOT CreateTaskColumnsTree() ) THEN RETURN FALSE; END;
    IF ( CreateAssColumnsTree() ) THEN RETURN TRUE; END;
    DisposeAssColumnsTree();
    RETURN FALSE;
END BuildAllColumnTrees;




PROCEDURE DoStatusForm( VAR FormInputs  : AStatusFormInputValues ) : BOOLEAN;
VAR
    FormValue               :   ARRAY [0..LastStatusFormFld] OF AFieldValue;
    Code                    :   ACode;
BEGIN
    IF ( NOT BuildAllColumnTrees() ) THEN RETURN FALSE; END;
    StartUsingFormValue(FormValue, FormInputs);
    Code := DoForm(0, 0, maxcol, GanttWEnd, TLSRFORMID, TRUE,
                      FormValue, CheckStatusForm);
    IF (Code = ExitKey) THEN
(* This must be called before terminateusingformvalue *)
        SetStatusInputSettings(FormValue, FormInputs);
    END;
    TerminateUsingFormValue(FormValue);
    DisposeAllColumnTrees();

    RETURN ( Code = ExitKey );
END DoStatusForm;

(* ***************  Form related stuffs end ***************** *)




(****************************************************************************
    InitColumnInfo -
        No old settings for AStatusFormInputValues.
        Initialize all Column Info in AStatusFormInputValues.
****************************************************************************)
PROCEDURE InitColumnInfo(
                             VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                               ColumnInfoIndex : CARDINAL
                            );
BEGIN
    SetLengthOf( ColumnInfoArr[ColumnInfoIndex].ColumnName, 0 );
    ColumnInfoArr[ColumnInfoIndex].ColumnWidth := 0;
    ColumnInfoArr[ColumnInfoIndex].ColumnID := 0;
    ColumnInfoArr[ColumnInfoIndex].IsBlankColumn := FALSE;
END InitColumnInfo;




(****************************************************************************
    InitDateRange -
        No old settings for ADateInfo.
        Initialize all DateInfo in AStatusFormInputValues.
****************************************************************************)
PROCEDURE InitDateRange( VAR DateRange : ADateInfo; DurationUnit : ADurationUnit);
BEGIN
    SetLengthOf( DateRange.DateString, 0 );
    DateRange.DateValue := MinDate;
    DateRange.DateDuration := 0;
    DateRange.DateUnit := DurationUnit;
END InitDateRange;


VAR Handle : AnExtHandle;


(****************************************************************************
    StartUsingStatusSettings  -
        Retreive the old settings for AStatusFormInputValues.
        If we can not retrieve the old settings then allocate storage
        for the settings and initialize all variable in the settings.
****************************************************************************)
PROCEDURE StartUsingStatusSettings(VAR Inputs : AStatusFormInputValues);
VAR
    A                       :   ADDRESS;
    i                       :   CARDINAL;
    ItemName                :   ARRAY [0..21] OF CHAR;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;
    TaskNode                :   ATreeNode;
    TaskPtr                 :   ATaskPtr;
    DataRecord              :   AColumnDataRecord;

BEGIN

    SetString(ItemName, "TLSR");
    Class := 1;
    IF ( LocateHeldItem(ItemName, Class, Category, A, Size) AND
       (Size = TSIZE(AStatusFormInputValues))) AND
       (HoldInFlexStor IN Category) THEN    (* 23-Jan-91 RSC *)
        Handle := AnExtHandle(A);
        Size   := GetExtData( Handle, ADR(Inputs) );

        (*  3-Jun-91 PFG  In case any of the column names have been 
            changed since the last time the report form was saved, 
            update them.  *)

        WITH Inputs DO
            FOR i := 0 TO LASTTASKINFO DO
                IF (TaskColumn[i].ColumnID <> 0) THEN
                    GetTaskColumnName(  TaskColumn[i].ColumnID,
                                        TaskColumn[i].ColumnName );
                END;
            END;

            FOR i := 0 TO LASTASSIGNINFO DO
                IF (AssignColumn[i].ColumnID <> 0) THEN
                    GetAssgColumnName(  AssignColumn[i].ColumnID,
                                        AssignColumn[i].ColumnName );
                END;
            END;

        END;

        RETURN;
    END;

    WITH Inputs DO
        HowToReport := TasksStatus;
        OpenSummary := FALSE;
        IncludePastDue := FALSE;
        HowToGroup := NotGroupByStartEndCont;
        WhatToShow := ShowResources;
        ReturnOK := FALSE;      (* 1-Jul-91 PFG *)

        InitDateRange(DailyRange, Days);
        InitDateRange(WeeklyRange, Weeks);
        InitDateRange(MonthlyRange, Months);

        FOR i := 0 TO LASTTASKINFO DO
            InitColumnInfo(TaskColumn, i);
        END;

        FOR i := 0 TO LASTASSIGNINFO DO
            InitColumnInfo(AssignColumn, i);
        END;

        InitPageRepeatSettings( StatusPageCtrl );
    END;

    Size := TSIZE(AStatusFormInputValues);

    DeleteHeldItem( ItemName, Class );

    IF (CreateExtObjectWithSize( Handle, ExtSlow, Size )) THEN
        IF NOT SetExtData( Handle, ADR(Inputs),
                           TSIZE(AStatusFormInputValues) ) THEN
            FatalError();
        END;
        Category := AHoldTypeSet{HoldInConfig,
                                 HeapNoOwner,   (* 13-Feb-91 RSC *)
                                 HoldInFlexStor,    (* 23-Jan-91 RSC *)
                                 HoldInDataFile};
        HoldThis(ItemName, Class, Category, ADDRESS(Handle), Size);
    ELSE
        FatalError();
    END;

END StartUsingStatusSettings;




PROCEDURE DoStatusForms();
VAR
    FormInputs              :   AStatusFormInputValues;
    InputsPtr               :   POINTER TO AStatusFormInputValues;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN
    Line := "Program Copyright (c) 1989 Symantec Corporation.";

    StartUsingStatusSettings(FormInputs);

    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        GetMessage(ModuleNumber + 15, Line);          (* "There are not tasks on which to report." *)
        Error(Line);
    ELSIF (DoStatusForm(FormInputs)) THEN
        FormInputs.ReturnOK := DoPageRepeatForm(FormInputs.StatusPageCtrl);

        (*  Save changes to forms.  We want to save changes to first form
            even if there were no changes to second.  *)
        IF NOT ((Handle <> AnExtHandle(NIL)) AND
                 SetExtData( Handle, ADR(FormInputs),
                             TSIZE(AStatusFormInputValues) ) ) THEN
            GetMessage(ModuleNumber+1, Line);
            Error(Line);
        END;
    ELSE        (* 1-Jul-91 PFG  Update ReturnOK field *)
        IF (LockObject(Handle, InputsPtr) < TSIZE(AStatusFormInputValues)) THEN
            FatalError();
        ELSE
            InputsPtr^.ReturnOK := FALSE;
            ReleaseObject(Handle);
        END;
    END;

END DoStatusForms;

BEGIN
    DoStatusForms();
END TLSROPTN.
