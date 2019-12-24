MODULE TLAROPTN;
(*  =========================================================================
    Last Edit : August 9, 1991 10:39AM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Time Line Assignments Report options form        

    MODIFICATION HISTORY:

        12-Jun-89 KKC First version
        15-Jun-89 KKC - Any constants which are related to maxrow are
                        changed to be variables.
        26-Jun-89 KKC - Modify TLAROPTN so that it is called directly from
                        timeline instead of TLAR. Pass data to TLAR by
                        using LocateHeldItem and HoldThis.
        27-Jun-89 KKC - Restrict user from entering zero in column width
                        for a non empty column name.
        21-Jul-89 KKC - Allow user to leave the column width fields if is
                        empty.
        27-Jul-89 KKC - Pop up calculator if F2 key is pressed in a numeric
                        field.
        09-Aug-89 KKC - Add copyright message.
                      - Pass Pointer instead of address.
        11-Aug-89 KKC - Add three blank lines between procedures.
        14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
        19-Sep-89 RSC - Use StartDate as a default for the StoEndD routine.
        20-Oct-89 KKC - Disallow user from mixing baseline assignments and
                        current assignments.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.
        1-Oct-90 PFG    Did the same for resource and assignment columns that
                        I just did for task columns.
        23-Jan-91 RSC   Put holder items in flexstor.
        13-Feb-91 RSC   Added HeapNoOwner to the holder item.
        21-Mar-91 AJL   Improve error checking.
                        Set the ReturnOK flag before storing it into Holder.
                        Convert to use VAR parms for PageRepeat and PageOptn.
         3-Jun-91 PFG   Because the form values are saved from one use of the
                        report form to the next, changes in column names
                        weren't taking effect.  Now we call captions procs for
                        each column on the form to update its name.
        10-Jun-91 PFG   Call GetTaskColumnName(), GetAssgColumnName() and
                        GetRsrcColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
         1-Jul-91 PFG   The ReturnOK value in the holder record wasn't getting
                        saved to FlexStor if the user ESC'd out of either form,
                        so TLAR proceeded as if the user had pressed F10.  
                        ReturnOK is now updated.  If F10 WAS pressed, we now
                        pass along information that shows that this form was
                        changed so that the Page Options form will know.
         9-Aug-91 PFG   Okay...marketing and QA didn't like part of my last 
                        change.  So now we save the first form regardless of
                        whether you pressed ESC or F10 on the second one.
        25-Sep-91 LAA   Bug #5182.  Erased column names were re-appearing
                        after bringing up the list of column names.
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM AssColumns             IMPORT
    (* PROCS *)                 CreateAssColumnsTree, DisposeAssColumnsTree,
                                PickAssColumn, SearchForAssColumn,
                                GetAssgColumnName;

FROM AssFormat              IMPORT
    (* VAR   *) (* PROC *)      GetAssInfo;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
    (* VAR   *) (* PROC *)      GetColumnInfo;

FROM Codes                  IMPORT
    (* TYPE  *)                 ACode;

FROM Dialog                 IMPORT
    (* PROC  *)                 FatalError, Error, Burp;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CreateExtObjectWithSize, LockObject,
                                ReleaseObject, SetExtData, GetExtData;

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
    (* CONST *)                 maxcol,
    (* VAR   *)                 maxrow;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, EditKey, MoveUpKey, MoveDownKey;

FROM Layout                 IMPORT
    (* VAR   *)                 GanttWEnd;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, StoC, TrimFront, Copy, Fill,
                                Procustes, ConcatLS, SetLengthOf, SubStr,
                                Search, TrimRear, SetString;

FROM MagicNum               IMPORT
    (* CONST *)                 BsLnBillable;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage;

FROM PageRepeat             IMPORT
    (* PROC  *)                 InitPageRepeatSettings;

FROM PageRepeat             IMPORT
    (* TYPE  *)                 APageRepeatSettings;

FROM PageOptn               IMPORT
    (* PROC  *)                 DoPageRepeatForm;

FROM ParseTime              IMPORT
    (* PROC  *)                 StoTimeU, StoEndTimeU;

FROM RsrcColumns            IMPORT
    (* PROCS *)                 CreateRsrcColumnsTree, PickRsrcColumn,
                                DisposeRsrcColumnsTree, SearchForRsrcColumn,
                                GetRsrcColumnName;

FROM RsrcFormat             IMPORT
    (* VAR   *) (* PROC *)      GetRsrcInfo;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE  *)                 ADDRESS, ADR, TSIZE;

FROM TaskColumns            IMPORT
    (* PROCS *)                 CreateTaskColumnsTree, PickTaskColumn,
                                DisposeTaskColumnsTree, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Timei                  IMPORT
    (* CONST *)                 MinDate, MaxDate,
    (* TYPE  *)                 ADate;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder;

CONST
    ModuleNumber        =   6900;
    MaxWidth            =   255;
    MaxColumnWidth      =   255;
    TLARFORMID          =   57;

    ASSIGNGROUPBY       =   0;
    ASSIGNSHOW          =   1;
    STARTDATE           =   2;
    ENDDATE             =   3;
    FIRSTTASKFLD        =   4;
    LASTTASKFLD         =   13;
    FIRSTRESOURCEFLD    =   14;
    LASTRESOURCEFLD     =   21;
    FIRSTASSIGNFLD      =   22;
    LASTASSIGNFLD       =   41;

    LastAssignFormField =   41;

    LASTTASKINFO        =   4;    (* (LASTTASKFLD - LASTTASKFLD + 1) /2 - 1 = 4 *)
    LASTRESOURCEINFO    =   3;    (* (LASTRESOURCEFLD - LASTRESOURCEFLD + 1) /2 - 1 = 3 *)
    LASTASSIGNINFO      =   9;    (* (LASTASSIGNFLD - LASTASSIGNFLD + 1) /2 - 1 = 9 *)

    MaxPrintWidth       =   255;


TYPE

    AGroupMethod        =   (ByTasks, ByResources);
    AShowMethod         =   (ShowResources, ShowResourcesAndCosts);

    AColumnInfo         =   RECORD
        ColumnName          :   AStringValue;
        ColumnWidth         :   CARDINAL;
        ColumnID            :   CARDINAL;
        IsBlankColumn       :   BOOLEAN;
    END;

    ADateInfo           =   RECORD
        DateString          :   AStringValue;
        DateValue           :   ADate;
    END;

    AnAssignFormInputValues     =   RECORD
        HowToGroup          :   AGroupMethod;
        WhatToShow          :   AShowMethod;
        StartingDate        :   ADateInfo;
        EndingDate          :   ADateInfo;
        TaskColumn          :   ARRAY[0..LASTTASKINFO] OF AColumnInfo;
        ResourceColumn      :   ARRAY[0..LASTRESOURCEINFO] OF AColumnInfo;
        AssignColumn        :   ARRAY[0..LASTASSIGNINFO] OF AColumnInfo;
        AssignPageCtrl      :   APageRepeatSettings;
        ReturnOK            :   BOOLEAN;
    END;
    AnAssignFormInputValuesPtr  =   POINTER TO AnAssignFormInputValues;


VAR




(****************************************************************************
    SetColumnInfo -
        Set up the ColumnInfo in AssignReporrtSettings based on
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
    IF (LengthOf( ColumnInfoArr[ColumnInfoIndex].ColumnName ) = 0) THEN
        ColumnInfoArr[ColumnInfoIndex].ColumnWidth := 0;
        RETURN;
    END;

    i := 1;
    ColumnInfoArr[ColumnInfoIndex].ColumnWidth :=
                         StoC(FormValue[FormValueIndex + 1].CharValue^, i);
    i3 :=  LengthOf(FormValue[FormValueIndex+1].CharValue^);

    IF (i > i3)  THEN RETURN; END;

    FOR i2 := i TO i3 DO
        GetMessage(ModuleNumber + 14, Line);  (* Blank *)
        IF (FormValue[FormValueIndex + 1].CharValue^[i2] = Line[1] ) THEN
            ColumnInfoArr[ColumnInfoIndex].IsBlankColumn := TRUE;
        END;
    END;

END SetColumnInfo;




(****************************************************************************
    InitColumnInfo -
        No old settings for AnAssignFormInputValues.
        Initialize all Column Info in AnAssignFormInputValues.
****************************************************************************)
PROCEDURE InitColumnInfo(
                         VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                           ColumnInfoIndex : CARDINAL
                        );
BEGIN
    SetLengthOf(ColumnInfoArr[ColumnInfoIndex].ColumnName, 0);
    ColumnInfoArr[ColumnInfoIndex].ColumnWidth := 0;
    ColumnInfoArr[ColumnInfoIndex].ColumnID := 0;
    ColumnInfoArr[ColumnInfoIndex].IsBlankColumn := FALSE;
END InitColumnInfo;




(****************************************************************************
    SetAssignInputSettings   -
        Set up the AssignReporrtSettings based on the value in FormValueArray.
        FormValueArray contains the information inputed from user.
****************************************************************************)
PROCEDURE SetAssignInputSettings(
                               VAR FormValue  : ARRAY OF AFieldValue;
                               VAR Inputs     : AnAssignFormInputValues
                              );
VAR
    i, i2                   :   CARDINAL;
BEGIN

    WITH Inputs DO
        HowToGroup := VAL(AGroupMethod, FormValue[ASSIGNGROUPBY].CardValue);
        WhatToShow := VAL(AShowMethod, FormValue[ASSIGNSHOW].CardValue);

        Copy(FormValue[STARTDATE].CharValue^, StartingDate.DateString);
        Copy(FormValue[ENDDATE].CharValue^, EndingDate.DateString);

        TrimRear( StartingDate.DateString );
        TrimRear( EndingDate.DateString );

            (* Errors are already checked in the procedure EnoughInputsAndAllInputsOk *)
        IF ( LengthOf( StartingDate.DateString ) = 0 ) THEN
            StartingDate.DateValue := MinDate;
        ELSE
            IF (StoTimeU(StartingDate.DateString, StartingDate.DateValue)) THEN
            END;
        END;

        IF ( LengthOf( EndingDate.DateString ) = 0 ) THEN
            EndingDate.DateValue := MaxDate;
        ELSE
            EndingDate.DateValue := StartingDate.DateValue; (* RSC 19-Sep-89 *)
            IF (StoEndTimeU(EndingDate.DateString, EndingDate.DateValue)) THEN
            END;
        END;

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

        FOR i := 0 TO LASTRESOURCEINFO DO
            InitColumnInfo(ResourceColumn, i);
        END;

        i2 := 0;
        FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD - 1 BY 2 DO
            SetColumnInfo(ResourceColumn, i2, FormValue, i);
            IF ( LengthOf( ResourceColumn[i2].ColumnName ) > 0 ) THEN
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
    END;

END SetAssignInputSettings;




(****************************************************************************
    EnoughInputsAndAllInputsOk  -
        Make sure we have all the parameters we need.
****************************************************************************)
PROCEDURE EnoughInputsAndAllInputsOk(
                                     VAR FormValue  : ARRAY OF AFieldValue
                                    ) : BOOLEAN;
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    GotTask                 :   BOOLEAN;
    GotRsrc                 :   BOOLEAN;
    GotAssign               :   BOOLEAN;
    CurrentAssignExist      :   BOOLEAN;
    BslnAssignExist         :   BOOLEAN;
    TmpStartDate            :   ADate;
    TmpEndDate              :   ADate;
    i                       :   CARDINAL;
BEGIN
    IF ( FormValue[ASSIGNGROUPBY].CardValue = 0) THEN (* Group By Task *)
        GotTask := FALSE;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
            Copy(FormValue[i].CharValue^, Line);
            TrimFront(Line);
            IF (LengthOf(Line) <> 0) THEN
               GotTask := TRUE;
            END;
        END;
        IF ( NOT GotTask ) THEN
            GetMessage(ModuleNumber + 8, Line);          (* No task columns *)
            Error(Line);
            RETURN FALSE;
        END;
    ELSE
        GotRsrc := FALSE;
        FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD - 1 BY 2 DO
            Copy(FormValue[i].CharValue^, Line);
            TrimFront(Line);
            IF (LengthOf(Line) <> 0) THEN
               GotRsrc := TRUE;
            END;
        END;
        IF ( NOT GotRsrc ) THEN
            GetMessage(ModuleNumber + 9, Line);          (* No resource columns *)
            Error(Line);
            RETURN FALSE;
        END;
    END;

    CurrentAssignExist := FALSE;
    BslnAssignExist := FALSE;
    GotAssign := FALSE;
    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
        Copy(FormValue[i].CharValue^, Line);
        TrimFront(Line);
        IF (LengthOf(Line) <> 0) THEN
            GotAssign := TRUE;
            IF ( FormValue[i].CardValue < BsLnBillable ) THEN
                CurrentAssignExist := TRUE;
            ELSE
                BslnAssignExist := TRUE;
            END;
        END;
    END;

    IF ( NOT GotAssign ) THEN
        GetMessage(ModuleNumber + 20, Line);          (* No assign columns *)
        Error(Line);
        RETURN FALSE;
    ELSIF ( CurrentAssignExist AND BslnAssignExist ) THEN
        GetMessage(ModuleNumber + 21, Line);          (* Cannot mix baseline and current assignments *)
        Error(Line);
        RETURN FALSE;
    END;

    Copy(FormValue[STARTDATE].CharValue^, Line);
    TrimFront(Line);
    TmpStartDate := MinDate;
    IF ( (LengthOf(Line) <> 0) AND (NOT StoTimeU(Line, TmpStartDate)) ) THEN
        RETURN FALSE;
    END;

    Copy(FormValue[ENDDATE].CharValue^, Line);
    TrimFront(Line);
    TmpEndDate := MaxDate;
    IF ( (LengthOf(Line) <> 0) AND (NOT StoTimeU(Line, TmpEndDate)) ) THEN
        RETURN FALSE;
    END;

    IF ( TmpStartDate >= TmpEndDate ) THEN
        GetMessage(ModuleNumber + 10, Line);    (* Start date greater than end date *)
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
    TaskBoxLeft         =   50;
    TaskBoxRight        =   79;
    TaskBoxTop          =   3;
VAR
    Column                  :   CARDINAL;
    Width                   :   CARDINAL;
    TaskBoxBottom           :   CARDINAL;
    i                       :   CARDINAL;
    DataRecord              :   AColumnDataRecord;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    T                       :   ATaskPtr;
    Node                    :   ATreeNode;

BEGIN
    TaskBoxBottom := maxrow-8;
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




PROCEDURE DoPickResourceColumn(
                                         Form : AForm;
                                      FieldNo : AFieldNo;
                                VAR FormValue : ARRAY OF AFieldValue
                               ) : BOOLEAN;
CONST
    RsrcBoxLeft         =   50;
    RsrcBoxRight        =   79;
    RsrcBoxTop          =   3;
VAR
    Column                  :   CARDINAL;
    RsrcBoxBottom           :   CARDINAL;
    i                       :   CARDINAL;
    Width                   :   CARDINAL;
    DataRecord              :   AColumnDataRecord;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN
    RsrcBoxBottom := maxrow-8;
    Column := FormValue[FieldNo].CardValue;
    IF (NOT PickRsrcColumn(RsrcBoxLeft, RsrcBoxTop,
                              RsrcBoxRight, RsrcBoxBottom, Column, Line)) THEN
        RETURN FALSE
    END;

    IF ( (FormValue[FieldNo].CardValue <> Column) OR
          (FormValue[FieldNo + 1].CardValue = 0) ) THEN
        IF ( NOT GetRsrcInfo(Column, AColumnInfoChoice(ColumnWidth),
                             Width, DataRecord) ) THEN
            RETURN FALSE;
        END;
        FormValue[ FieldNo+1 ].CardValue := DataRecord.CardinalValue;
        SetFieldProtection(Form, FieldNo+1, FormValue, FALSE);
    END;
    FormValue[FieldNo].CardValue := Column;

    RETURN TRUE;
END DoPickResourceColumn;




PROCEDURE DoPickAssignColumn(
                                      Form : AForm;
                                   FieldNo : AFieldNo;
                             VAR FormValue : ARRAY OF AFieldValue
                            ) : BOOLEAN;
CONST
    AssignBoxLeft       =   0;
    AssignBoxRight      =   29;
    AssignBoxTop        =   3;
VAR
    Column                  :   CARDINAL;
    Width                   :   CARDINAL;
    AssignBoxBottom         :   CARDINAL;
    i                       :   CARDINAL;
    DataRecord              :   AColumnDataRecord;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN
    AssignBoxBottom := maxrow-8;
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




PROCEDURE CheckTLARForm(
                                 Form : AForm;
                              FieldNo : AFieldNo;
                        VAR FormValue : ARRAY OF AFieldValue;
                          CheckReason : ACheckReason;
                             VAR Code : CARDINAL
                       ) : BOOLEAN;
VAR
    CodeIn                  :   CARDINAL;
    TmpString               :   AStringValue;
    TmpColumn               :   CARDINAL;
    ok                      :   BOOLEAN;
    i                       :   CARDINAL;
    TmpDate                 :   ADate;
    NoDate                  :   BOOLEAN;
    NoName                  :   BOOLEAN;
    TempField               :   AFieldValue;
    Line                    :   ARRAY[0..MaxWidth] OF CHAR;
BEGIN

    CodeIn := Code;
    Code := 0;

    CASE CheckReason OF
        | CheckFormEntry :
            CASE FieldNo OF
                | FIRSTTASKFLD..LASTTASKFLD,
                  FIRSTRESOURCEFLD..LASTRESOURCEFLD,
                  FIRSTASSIGNFLD..LASTASSIGNFLD:
            (* Return if it is column width *)
                   IF ( ( ( FieldNo + FIRSTTASKFLD ) MOD 2 ) = 1 ) THEN
                      RETURN TRUE;
                   END;
                   NoName := (LengthOf( FormValue[FieldNo].CharValue^ ) = 0);
                   SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
                   SetFieldProtection(Form, FieldNo + 1, FormValue, NoName);
                   RETURN TRUE;
            ELSE
                RETURN TRUE;
            END;
        | CheckFormExit :
            RETURN (EnoughInputsAndAllInputsOk(FormValue));
        | CheckFieldEntry:   ;
        | CheckFieldChange:
            CASE FieldNo OF
                | STARTDATE:
                    Copy(FormValue[FieldNo].CharValue^, TmpString);
                    TrimFront(TmpString);
                    NoDate := (LengthOf( TmpString ) = 0);

                    IF ( NOT NoDate ) THEN
                        ok := StoTimeU (TmpString, TmpDate);
                    ELSE
                        TmpDate := MinDate;
                        ok := TRUE;
                    END;

                    IF ( NOT ok ) THEN
                        Burp();
                        RETURN FALSE;
                    END;
                    FormValue[FieldNo].CardValue := TmpDate;
                    SetFormChange(Form);
                    RETURN TRUE;
                | ENDDATE:
                    Copy(FormValue[FieldNo].CharValue^, TmpString);
                    TrimFront(TmpString);
                    NoDate := (LengthOf( TmpString ) = 0);

                    IF ( NOT NoDate ) THEN
                        TmpDate := FormValue[STARTDATE].CardValue; (* RSC 19-Sep-89 *)
                        ok := StoEndTimeU (TmpString, TmpDate);
                    ELSE
                        TmpDate := MaxDate;
                        ok := TRUE;
                    END;

                    IF ( NOT ok ) THEN
                        Burp();
                        RETURN FALSE;
                    END;
                    FormValue[FieldNo].CardValue := TmpDate;
                    SetFormChange(Form);
                    RETURN TRUE;
            ELSE
                SetFormChange(Form);
                RETURN TRUE;
            END;
        | CheckFieldExit :
            CASE FieldNo OF
                | FIRSTTASKFLD..LASTTASKFLD,
                  FIRSTRESOURCEFLD..LASTRESOURCEFLD,
                  FIRSTASSIGNFLD..LASTASSIGNFLD:
                    (* If column name then *)
                      IF ( ( ( FieldNo + FIRSTTASKFLD ) MOD 2 ) = 0 ) THEN
                         Copy(FormValue[FieldNo].CharValue^, TmpString);
                         TrimFront(TmpString);
                         IF ( LengthOf(TmpString) <> 0 ) THEN
                            IF ( ( FieldNo >= FIRSTTASKFLD )
                                AND
                                 ( FieldNo <= LASTTASKFLD ) ) THEN
                                ok := SearchForTaskColumn(TmpString, TmpColumn);
                            ELSIF ( ( FieldNo >= FIRSTRESOURCEFLD )
                                AND
                                 ( FieldNo <= LASTRESOURCEFLD ) ) THEN
                                ok := SearchForRsrcColumn(TmpString, TmpColumn);
                            ELSE
                                ok := SearchForAssColumn(TmpString, TmpColumn);
                            END;
                            IF ( NOT ok ) THEN
                                Burp();
                                RETURN FALSE;
                            END;
                            FormValue[FieldNo].CardValue := TmpColumn;
                         ELSE                                  (* 25-Sep-91 *)
                            FormValue[FieldNo].CardValue := 0;
                         END;
                         NoName := (LengthOf( TmpString ) = 0);
                         SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
                         SetFieldProtection(Form, FieldNo + 1, FormValue,
                                            NoName);
                         SetFormChange(Form);
                         RETURN TRUE;
                      END;
                      i := 1;
                      FormValue[FieldNo].CardValue :=
                           StoC(FormValue[FieldNo].CharValue^, i);
                      IF (FormValue[FieldNo].CardValue > MaxColumnWidth ) THEN
                            GetMessage( ModuleNumber + 19, Line); (* Column width too wide *)
                            Error(Line);
                            RETURN FALSE;
                      END;
                      IF (FormValue[FieldNo].CardValue = 0) THEN
                         SetLengthOf(FormValue[FieldNo].CharValue^, 0);
                      END;
                      ShowValue( Form, FieldNo, FormValue );
                      RETURN TRUE;
            ELSE
                RETURN TRUE;
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
                     ( FieldNo = FIRSTRESOURCEFLD )
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
                     ( FieldNo = ( LASTRESOURCEFLD - 1 ) )
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
                    IF (NOT SearchForTaskColumn( FormValue[FieldNo].CharValue^,        (* 25-Sep-91 *)
                                                 FormValue[FieldNo].CardValue )) THEN
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

                | FIRSTRESOURCEFLD..LASTRESOURCEFLD:
                    IF (NOT SearchForRsrcColumn( FormValue[FieldNo].CharValue^,       (* 25-Sep-91 *)
                                                 FormValue[FieldNo].CardValue )) THEN
                        FormValue[FieldNo].CardValue := 0;
                    END;
                    ok := DoPickResourceColumn(Form, FieldNo, FormValue);

                    (* In case column names were edited, update all column
                        names on form.  Need to do this even if PickRsrcColumn
                        returns FALSE, since the user may have changed some 
                        column other than the highlighted one.  *)

                    FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD - 1 BY 2 DO
                        IF FormValue[i].CardValue <> 0 THEN
                            GetRsrcColumnName(  FormValue[i].CardValue,
                                                FormValue[i].CharValue^);
                        ELSE
                            Fill(FormValue[i].CharValue^, " ", 24);
                            FormValue[i + 1].CardValue := 0;
                        END;
                    END;

                    (*  Redisplay the column names and widths  *)

                    FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD DO
                        ShowValue(Form, i, FormValue);
                    END;

                | FIRSTASSIGNFLD..LASTASSIGNFLD:
                    IF (NOT SearchForAssColumn( FormValue[FieldNo].CharValue^,         (* 25-Sep-91 *)
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
            RETURN TRUE;
        ELSE
            RETURN FALSE;
    END;

    RETURN TRUE;

END CheckTLARForm;




(****************************************************************************
    InitColumnField -
        Initialize pointers for Column name info in FormValueArray.
    All variable will be set based on the value in FormInputs.
****************************************************************************)
PROCEDURE InitColumnField(
                          VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                            ColumnInfoIndex : CARDINAL;
                          VAR     FormValue : ARRAY OF AFieldValue;
                             FormValueIndex : CARDINAL
                         );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    OneCharBuffer           :   ARRAY [0..1] OF CHAR;
BEGIN

    Copy(ColumnInfoArr[ColumnInfoIndex].ColumnName,
                                        FormValue[FormValueIndex].CharValue^);
    FormValue[FormValueIndex].CardValue :=
                                      ColumnInfoArr[ColumnInfoIndex].ColumnID;

    FormValue[FormValueIndex + 1].CardValue :=
                                   ColumnInfoArr[ColumnInfoIndex].ColumnWidth;
    SetLengthOf( FormValue[FormValueIndex + 1].CharValue^, 0);
    IF (FormValue[FormValueIndex + 1].CardValue <> 0) THEN
        CtoS(FormValue[FormValueIndex + 1].CardValue,
                                    FormValue[FormValueIndex + 1].CharValue^);
        IF (ColumnInfoArr[ColumnInfoIndex].IsBlankColumn) THEN
            GetMessage(ModuleNumber + 14, Line);  (* Blank *)
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
    NEW(FormValue[STARTDATE].CharValue);
    NEW(FormValue[ENDDATE].CharValue);

    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
        NEW(FormValue[i].CharValue);
    END;

    FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD DO
        NEW(FormValue[i].CharValue);
    END;

    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
        NEW(FormValue[i].CharValue);
    END;
END AllocateFormValue;




(****************************************************************************
    StartUsingFormValueArray -
    Allocate the buffers for form value array.  All variable will be set
    based on the value in FormInputs.
****************************************************************************)
PROCEDURE StartUsingFormValue(
                               VAR FormValue : ARRAY OF AFieldValue;
                               VAR Inputs    : AnAssignFormInputValues
                             );
VAR
    i, i2                   :   CARDINAL;
BEGIN

    AllocateFormValue( FormValue );

    WITH Inputs DO
        FormValue[ASSIGNGROUPBY].CardValue := ORD(HowToGroup);
        FormValue[ASSIGNSHOW].CardValue := ORD(WhatToShow);

        Copy(StartingDate.DateString, FormValue[STARTDATE].CharValue^);
        FormValue[STARTDATE].CardValue := StartingDate.DateValue;

        Copy(EndingDate.DateString, FormValue[ENDDATE].CharValue^);
        FormValue[ENDDATE].CardValue := EndingDate.DateValue;

        i2 := 0;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD - 1 BY 2 DO
            InitColumnField(TaskColumn, i2, FormValue, i);
            INC(i2);
        END;

        i2 := 0;
        FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD - 1 BY 2 DO
            InitColumnField(ResourceColumn, i2, FormValue, i);
            INC(i2);
        END;

        i2 := 0;
        FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD - 1 BY 2 DO
            InitColumnField(AssignColumn, i2, FormValue, i);
            INC(i2);
        END;
    END;

END StartUsingFormValue;




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

    FOR i := FIRSTRESOURCEFLD TO LASTRESOURCEFLD DO
        DISPOSE(FormValue[i].CharValue);
        FormValue[i].CharValue := NIL;   (* Safely !!! *)
    END;

    FOR i := FIRSTASSIGNFLD TO LASTASSIGNFLD DO
        DISPOSE(FormValue[i].CharValue);
        FormValue[i].CharValue := NIL;   (* Safely !!! *)
    END;

    DISPOSE(FormValue[ENDDATE].CharValue);
    FormValue[ENDDATE].CharValue := NIL;   (* Safely !!! *)
    DISPOSE(FormValue[STARTDATE].CharValue);
    FormValue[STARTDATE].CharValue := NIL; (* Safely !!! *)

END TerminateUsingFormValue;




PROCEDURE BuildAllColumnTrees() : BOOLEAN;
VAR
    TaskTreeBuilt           :   BOOLEAN;
    RsrcTreeBuilt           :   BOOLEAN;
    AssignTreeBuilt           :   BOOLEAN;
BEGIN
    TaskTreeBuilt := CreateTaskColumnsTree();
    RsrcTreeBuilt := CreateRsrcColumnsTree();
    AssignTreeBuilt := CreateAssColumnsTree();
    IF ( TaskTreeBuilt AND RsrcTreeBuilt AND AssignTreeBuilt ) THEN
        RETURN TRUE;
    END;
    IF ( TaskTreeBuilt ) THEN
        DisposeTaskColumnsTree();
    END;
    IF ( RsrcTreeBuilt ) THEN
        DisposeRsrcColumnsTree();
    END;
    IF ( AssignTreeBuilt ) THEN
        DisposeAssColumnsTree();
    END;
    RETURN FALSE;
END BuildAllColumnTrees;




PROCEDURE DisposeAllColumnTrees();
BEGIN
    DisposeTaskColumnsTree();
    DisposeRsrcColumnsTree();
    DisposeAssColumnsTree();
END DisposeAllColumnTrees;




PROCEDURE DoAssignmentForm( VAR FormInputs  : AnAssignFormInputValues
                            ) : BOOLEAN;
VAR
    FormValue               :   ARRAY [0..LastAssignFormField] OF AFieldValue;
    Code                    :   ACode;
BEGIN
    IF ( NOT BuildAllColumnTrees() ) THEN RETURN FALSE; END;
    StartUsingFormValue(FormValue, FormInputs);
    Code := DoForm(0, 0, maxcol, GanttWEnd, TLARFORMID, TRUE,
                      FormValue, CheckTLARForm);

    IF (Code = ExitKey) THEN
        SetAssignInputSettings(FormValue, FormInputs);
    END;

    TerminateUsingFormValue(FormValue);
    DisposeAllColumnTrees();

    RETURN ( Code = ExitKey );

END DoAssignmentForm;

(* ***************  Form related stuffs end ***************** *)



VAR Handle : AnExtHandle;




(****************************************************************************
    StartUsingAssignSettings  -
        Retreive the old settings for AnAssignFormInputValues.
        If we can not retrieve the old settings then allocate storage
        for the settings and initialize all variable in the settings.
****************************************************************************)
PROCEDURE StartUsingAssignSettings( 
                                   VAR Inputs  : AnAssignFormInputValues
                                  );
VAR
    A                       :   ADDRESS;
    i                       :   CARDINAL;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;
    ItemName                :   ARRAY [0..21] OF CHAR;
    TaskNode                :   ATreeNode;
    TaskPtr                 :   ATaskPtr;
    DataRecord              :   AColumnDataRecord;

BEGIN

    SetString(ItemName, "TlarData");
    Class := 1;
    IF ( LocateHeldItem(ItemName, Class, Category, A, Size) AND
       (Size = TSIZE(AnAssignFormInputValues) ) ) AND
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

            FOR i := 0 TO LASTRESOURCEINFO DO
                IF (ResourceColumn[i].ColumnID <> 0) THEN
                    GetRsrcColumnName(  ResourceColumn[i].ColumnID,
                                        ResourceColumn[i].ColumnName );
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
        HowToGroup := ByTasks;
        WhatToShow := ShowResources;
        ReturnOK := FALSE;      (* 1-Jul-91 PFG *)

        SetLengthOf(StartingDate.DateString, 0);
        StartingDate.DateValue := MinDate;

        SetLengthOf(EndingDate.DateString, 0);
        EndingDate.DateValue := MinDate;

        FOR i := 0 TO LASTTASKINFO DO
            InitColumnInfo(TaskColumn, i);
        END;

        FOR i := 0 TO LASTRESOURCEINFO DO
            InitColumnInfo(ResourceColumn, i);
        END;

        FOR i := 0 TO LASTASSIGNINFO DO
            InitColumnInfo(AssignColumn, i);
        END;

        InitPageRepeatSettings( AssignPageCtrl );
    END;

    Size := TSIZE(AnAssignFormInputValues);

    DeleteHeldItem( ItemName, Class );

    IF (CreateExtObjectWithSize( Handle, ExtSlow, Size )) THEN
        Category := AHoldTypeSet{HoldInConfig,
                                 HeapNoOwner,   (* 13-Feb-91 RSC  *)
                                 HoldInFlexStor,    (* 23-Jan-91 RSC *)
                                 HoldInDataFile};
        HoldThis(ItemName, Class, Category, ADDRESS(Handle), Size);
    ELSE
        FatalError();
    END;

END StartUsingAssignSettings;




PROCEDURE DoAssignmentForms();
VAR
    FormInputs              :   AnAssignFormInputValues;
    InputsPtr               :   POINTER TO AnAssignFormInputValues;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN

    Line := "Program Copyright (c) 1989 Symantec Corporation.";
    StartUsingAssignSettings(FormInputs);

    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        GetMessage(ModuleNumber + 2, Line);          (* "There are not tasks on which to report." *)
        Error(Line);
    ELSIF (DoAssignmentForm(FormInputs)) THEN
        FormInputs.ReturnOK := DoPageRepeatForm(FormInputs.AssignPageCtrl);

        (*  Save changes to forms.  We want to save changes to first form
            even if there were no changes to second.  *)
        IF NOT ((Handle <> AnExtHandle(NIL)) AND
                 SetExtData( Handle, ADR(FormInputs),
                             TSIZE(AnAssignFormInputValues) ) ) THEN
            GetMessage(ModuleNumber+1, Line);
            Error(Line);
        END;
    ELSE        (* 1-Jul-91 PFG  Update ReturnOK field *)
        IF (LockObject(Handle, InputsPtr) < TSIZE(AnAssignFormInputValues)) THEN
            FatalError();
        ELSE
            InputsPtr^.ReturnOK := FALSE;
            ReleaseObject(Handle);
        END;
    END;

END DoAssignmentForms;

BEGIN
    DoAssignmentForms();
END TLAROPTN.
