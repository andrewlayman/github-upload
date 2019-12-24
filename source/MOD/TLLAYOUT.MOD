MODULE TLLayout;

(*  =========================================================================
    Last Edit : July 12, 1991 4:30PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Layout form.        

    MODIFICATION HISTORY:
        8/13/85   AJL - Fixed AdjustScale to round up correctly.
        8/16/85   AJL - Reinstated use of MOD to check scales less
                        than the GreaterScale in AdjustScale, though
                        keeping the 8/13 change for scales >=.
        12/4/85   AJL - Expanded the size of some text buffers.

        4/20/86   AJL   Removed OptionsForm, menu, other TL items.
        7/22/86   AJL - Added a local check proc.  Limit field
                        values for task and resource column width.
        11/10/86 LAA    Reinstated DoOptionsForm from vers. 2.3 code to
                        bring this back to Time Line.  I didn't bring back the
                        goto menu bacause it's implemented using TLWHAT now.
        11/11/86 LAA    Instead of directly setting the chart state to an
                        empty set, use UnSetState(Scheduled) instead.
        11/26/86 LAA    Removed reference to NeedsRecompute.  This function is
                        now handled strictly by the chart state.
        12/08/86 LAA    Added filter names to the display control form.
        12/09/86 LAA    Incorporated filter name picklist.
        12/12/86 LAA    Set ConfigSaved to FALSE if the display control
                        form has been changed.  Also UnSetState(Filtered) so
                        the filtering will be re-done.
        12/15/86 LAA    When the display control form is changed, set 
                        ScheduleSaved, in addition to ConfigSaved, to FALSE.
        20-May-87 LAA   Modified the chart form for the changed meanings of
                        fields in AChartFormat, and used CurrentChartFormat
                        directly.  DefinedChartFormat is no longer used.  
                        Field 4 of the chart form is now the resource column
                        width.  Moved chart format stuff from Chart into this
                        module.
        22-May-87 LAA   Removed CursorDate, StartDate, BugTasks and 
                        AutoTracking from the ChartFormat.  Made changes due
                        to the fact that CursorTask is now a tree node rather
                        than a task pointer.
        25-May-87 LAA   Removed use of TaskIsIn in DisplayControlForm.  Use
                        the Visible method instead.
        29-May-87 LAA   Fixed bug in DisplayControlForm, which was causing the
                        system to hang.
        09-Jun-87 LAA   Removed limit on length of task name field.  Added
                        SeperatorChar field to the chart format, and init'ed
                        it.  Changed the edits on the task name and resource
                        column width fields.
        10-Jun-87 LAA   Added new fields to the form, and changed the 
                        selections by which the user can sort.
        11-Jun-87 LAA   Added more fields to the form.
        19-Jun-87 LAA   Still working on the new fields for this form.
        22-Jun-87 LAA   Changed the initial chart scale.
        23-Jun-87 LAA   Don't turn off F7 filtering when leaving the display
                        form.  This will allow us to switch between AVP and
                        Gantt views and retain the showing of joins.
                        Removed sorting criteria from the Options form.
        24-Jun-87 LAA   Incorporated Ed's changes for the filter set.
        25-Jun-87 LAA   Column widths on the display form no longer include
                        the seperation between columns.
        29-Jun-87 LAA   Changed the starting column of columnar data to be 1.
        07-Jul-87 LAA   Fixed bug which screwed up the column sequence if the
                        seq. no. was > 0, but the width = 0.
        24-Jul-87 LAA   Completely changed the layout form.  Removed the
                        procedure RecomputeChartScale.
        04-Aug-87 LAA   Moved DoOptionsForm to the Schedule module.  Put in
                        named layouts.
        07-Aug-87 LAA   Started adding list of column names to chart form.
                        Put in blank layout to select the default.
        21-Aug-87 LAA   Removed restriction that column widths must be at
                        least 4.
        21-Sep-87 LAA   Changed layout form per request of DSB, added notes
                        per MD request.
        15-Oct-87 RSC   Added shadows to boxes.  Added param to EditText.
        20-Oct-87 EGK   Call ResetMatching when the layout list or column
                        name list is put up.
        22-Oct-87 EGK   Exiting the column name list with DoIt causes the
                        cursor item to become selected.
        29-Oct-87 LAA   Fixed multiple bugs with the layout form.
        30-Nov-87 LAA   Removed usage of ColumnViews and ColumnOutlines 
                        modules.
        02-Dec-87 LAA   Incorporated ColumnName module.
        23-Dec-87 LAA   Blanking out a column name field didn't remove that
                        column name from use because of the CardValue.
        30-Dec-87 LAA   When a column is chosen, the following width field is
                        immediately made unprotected.  Also made the list of
                        column names shorter so it doesn't obscure the fields.
        19-Jan-88 LAA   Made this an installable overlay.
        28-Jan-88 RSC   When selecting a column, set form written flag.
        08-Feb-88 LAA   Adjusted for new parameters to GetColumnInfo.
        10-Feb-88 LAA   Fixed bug with leaving stuff around on the heap.
        12-Nov-88 LAA   If the task name column was specified more than once
                        on the layout form, and the last one was off-screen,
                        TaskNameOnScreen was being set to FALSE, even if one
                        of the task name columns WAS on the screen.
        22-Dec-88 LAA   Adjusted for new parameters of GetColumnInfo.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        10-Jan-89 RSC   Changed Storage to Space    .
         7-Feb-89 RSC   Updated "GetColumnInfo" call.
        17-Feb-89 EGK   Put in a call to LJust in MapColumnSpecsToFormValue.
        16-Mar-89 EGK   Changed to use procedures from TaskColumns module.
        22-Mar-89 EGK   Added code to handle the new percent-complete fields.
        11-Apr-89 EGK   Re-interpret "ColumnTotalByRsrc" to mean
                        "ColumnIsPercentage"; i.e., "does it make sense to
                        pick this column to show progress?"
        24-May-89 KKC   Highlight field before picking list and UnHighlight
                        field after it.
        25-May-89 EGK   Fixed the check of layout name uniqueness so that
                        it uses the TrimRear'd version of the string.
         6-Jun-89 AJL   Removed import of AFilterRecordPointer.
         9-Jun-89 EGK   Change order of "percent column" and "which
                        line shows" fields, and protect both if not showing
                        gantt bars.
        14-Jul-89 EGK   Changed order of "show gantt bars" and "slack style"
                        fields.
        04-Aug-89 EGK   Make use of new "percent column" routines to display
                        a list of only the columns that show a percentage.
        10-Aug-89 KKC   Add copyright message.
        06-Sep-89 WKH   Insidious.  Turns out that you were able pick a 
                        column name such as "Parent WBS" and then delete
                        the preceding chars and leave only "WBS", then you
                        will always get the Parent WBS column and not the
                        WBS column.  I fixeded it.
        11-Sep-89 WKH   TrimRear the Layout name after we copy it from the
                        form field to the layout tree.  We were storing
                        the "padded" version thus making it impossible for
                        us to safeguard agains duplicate layout names.
        12-Sep-89 WKH   Make edit window bigger for compressed video mode.
        12-Sep-89 EGK   Changed the checkproc so that it validates the
                        column name on CheckFieldChange, not CheckFieldExit.
                        This eliminates the delay sometimes experienced when
                        moving around through fields that haven't changed.
        18-Sep-89 RSC   Moved AdjustScale here from ChartFor.  Added a
                        "Are you sure?" box.
        21-Feb-90 KKC   Remove all unreferenced id from Timeu.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.
        09-Jan-91 PFG   Removed my last change and redisplayed ALL column
                        names in case several changed at once or only one
                        changed but user ESCaped out of pick list.  (See bug
                        #4088.)
        11-Jan-91 PFG   Additional fix:  took incrementing and decrementing
                        of column widths out of Map calls and put them just
                        where they were needed so they wouldn't get called
                        every time.  Also fixed a problem with the ShowValue
                        call I had added.
        16-Jan-91 PFG   Moved call to MapFormValueToColumnSpec outside of
                        check for new column name being inserted.  It wasn't
                        getting called if user chose same column that was
                        already in the field.
         4-Mar-91 TGS   Column widths were changing without being changed.
         5-Mar-91 TGS   Missed one change yesterday.
        21-Mar-91 TGS   Remove a mysterious offset that was causing default
                        column width to come up 1 greater than what it said
                        on the column spec form.
                        Created RefreshColumnNames() so this could be called
                        instead of MapFormValueToColumnSpec, etc., when we're
                        still on the form. It is wrong to change the layout
                        record until we're done editing the form.
                        Finally, rebuild the PctColumnTree whenever we visit
                        the TaskColumnTree.
        10-Jun-91 PFG   Genericized RefreshTaskColumnName() and moved it to
                        TASKCOLU.MOD so it could be used for all forms that
                        display task column names as a data field.  This was
                        done to fix a problem where pressing ESC from a 
                        pick list after changing a task column name, the 
                        data columns whose contents had been changed didn't
                        get refreshed properly.
         1-Jul-91 PFG   Account for cases where GreaterDuration is odd and 
                        scale is odd or vice-versa.  This can happen now that
                        we allow standard workdays in increments of less than 
                        an hour.  It was causing a divide overflow because we
                        would never quit trying to make them divide up 
                        evenly.
        12-Jul-91 PFG   Added a call to DisplayScheduleLight when a new
                        layout is created so the "dirty light" is displayed
                        at the bottom of the screen.
    =========================================================================
*)


FROM Allocs                 IMPORT TskNmLen, ATaskFilter, ATaskPtr;

FROM Boxes                  IMPORT ABoxType, ABoxAttribute;

FROM Space                  IMPORT ALLOCATE, DEALLOCATE;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;

FROM Chart                  IMPORT CursorTask, MChToday, GanttChart;

FROM ChartControl           IMPORT AChartState, ChartState, AChartStateSet,
                                   UnSetState, DisplayTheChart;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr, AnOverlayContext,
    (* VAR *)                   LayoutTree,
    (* PROC *)                  DetermineFirstGantt;

FROM Codes                  IMPORT ACode;

FROM ColumnSupport          IMPORT
    (* TYPE *)                  AColumnTreeRecord;

FROM Dialog                 IMPORT Burp, Message, Error, FatalError;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM FormCon                IMPORT AFieldNo;

FROM Forms                  IMPORT DoForm, AFieldValue, AForm, ACheckReason, 
                                   NullCheckProc, ShowValue, FindFieldXY, 
                                   SetFieldProtection, SetFormChange,
                                   HighlightField, ACursorAttribute;

FROM Gantt                  IMPORT StatWidth, ASlackStyle, AGanttLineType;

FROM Kbio                   IMPORT maxrow, maxcol, ascreenx, ascreeny, soundon, 
                                   avidmode;

FROM Keys                   IMPORT ExitKey, DoIt, InsertKey, DeleteKey, CancelKey,
                                   EditKey, MoveUpKey, MoveDownKey;

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Layout                 IMPORT GanttWEnd;
                            
FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Insert, Procustes, TrimFront, TrimRear, Fill, 
                                   LengthOf, Copy, StringsEqual, LJust, SetLengthOf,
                                   Upshift;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved, ConfigSaved,
    (* PROC  *)                 DisplayScheduleLight;

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn,
                                CreatePctColumnsTree, DisposePctColumnsTree,
                                PickPctColumn, SearchForPctColumn,
                                GetTaskColumnName;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  TextExists, CreateText, AssignLine,
                                CopyLine, Compress, AssignText, DiscardText;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration, OneUnitOfDuration,
    (* TYPE *)                  ADuration, ADurationUnit, ADurationCounter;

FROM Timeu                  IMPORT
    (* PROC *)                  UpScale, DownScale, FindCorrectScale;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATree,
    (* PROC *)                  ValidateTreeNode;


CONST
    ModuleNumber = 2600;    (* For GetMessage. *)

    TaskNameColumn          = 1;

    NAME                    = 0;
    NOTE                    = 1;
    SCAL                    = 2;
    UNIT                    = 3;
    SLAC                    = 4;
    GANT                    = 5;
    AVP                     = 6;
    PCOL                    = 7;
    PLIN                    = 8;

    (* WARNING!!!  DANGER!!!   *)
    (* There is code in the check proc that relies on the relationship that *)
    (* the column width field directly follows the column name field.       *)
    (* This assumption was made to avoid a very large case statement.       *)
    (* Should this relationship ever need be changed for good reasons, you  *)
    (* can find the code that relies on this relationship by searching for  *)
    (* the string "Field + 1".  06-Sep-89 WKH                               *)

    CN1                     = 9;
    CN2                     = 11;
    CN3                     = 13;
    CN4                     = 15;
    CN5                     = 17;
    CN6                     = 19;
    CN7                     = 21;
    CN8                     = 23;
    CN9                     = 25;
    CN10                    = 27;
    CN11                    = 29;
    CN12                    = 31;
    CN13                    = 33;
    CN14                    = 35;
    CN15                    = 37;
    CN16                    = 39;
    CW1                     = 10;
    CW2                     = 12;
    CW3                     = 14;
    CW4                     = 16;
    CW5                     = 18;
    CW6                     = 20;
    CW7                     = 22;
    CW8                     = 24;
    CW9                     = 26;
    CW10                    = 28;
    CW11                    = 30;
    CW12                    = 32;
    CW13                    = 34;
    CW14                    = 36;
    CW15                    = 38;
    CW16                    = 40;

VAR
    PrivateOverlayContext   : POINTER TO AnOverlayContext;
    LayoutOnForm            : ATreeNode;
    LayoutNotes             : AText;
    OverlayID               : AnOverlayID;






    (* AdjustScale -- Make sure that the scale chosen for the chart
                      will divide to produce reasonably even spacing.
                      For example, avoid 3 hours per column on an
                      eight hour day.   That would take 8 columns to
                      get back in synchronization.  Go to 4 hours.
    *)


PROCEDURE AdjustScale(VAR scale:ADuration;VAR scaleunit:ADurationUnit);

VAR
    Temp            : ADuration;         
    TooLarge        : BOOLEAN;
    GreaterUnit     : ADurationUnit;
    GreaterDuration : ADuration;    (* If the user picks hours, this
                                       will hold a day.  If days, a
                                       week.  Etc.  *)

BEGIN
        (* If the scale is in weeks or more (a) it is difficult to
           adjust, and (b) it is so large that synchronization should
           not be a problem. *)
    IF (scaleunit < Days) THEN
        GreaterUnit := scaleunit; (* A larger segment of time. *)
        INC(GreaterUnit);
        GreaterDuration := UpScale(OneUnitOfDuration,GreaterUnit);

            (* Round it up. *)
        IF (scale <= GreaterDuration) THEN
                (* Increase scale until it divides the GreaterDuration
                   evenly.   This does not necessarily round it up all
                   the way as the equation below does.   (This also,
                   as a side effect, ensures that scale is not 0.) *)

                (* 1-Jul-91 PFG   Account for cases where GreaterDuration
                   is odd and scale is odd or vice-versa.  This can happen
                   now that we allow standard workdays in increments of
                   less than an hour.  *)

            Temp := scale;
            TooLarge := FALSE;
            WHILE (((GreaterDuration MOD Temp) <> NoDuration) AND
                    (NOT TooLarge)) DO
                scale := Temp;
                Temp := scale +  UpScale(OneUnitOfDuration,scaleunit);
                TooLarge := Temp > GreaterDuration;
            END;
            IF (NOT TooLarge) THEN
                scale := Temp;
            END;
        ELSE
            scale := ( 
                        ( scale + GreaterDuration - OneUnitOfDuration ) 
                        DIV 
                        GreaterDuration
                     ) * GreaterDuration;
        END;
    END;

        (*  Ensure that the scale is <= 6 months per character.  *)

    GreaterDuration := UpScale( VAL( ADurationCounter, 6 ) , Months); 
    IF (scale > GreaterDuration) THEN
        scale := GreaterDuration;
    END;

        (* Safety adjustments. *)
    FindCorrectScale(scale,scaleunit);

END AdjustScale;







PROCEDURE MapColumnSpecsToFormValue(    ChartFormat : AChartFormatPtr;
                                    VAR FormValue   : ARRAY OF AFieldValue);
VAR
    i                       : CARDINAL;
    j                       : CARDINAL;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;

BEGIN                       (* MapColumnSpecsToFormValue *)

    WITH ChartFormat^ DO
        i := CN1;
        FOR j := 1 TO ColumnCount DO
            IF (i <= CN16) THEN
                GetTaskColumnName(  ColumnSpec[j].ColumnID,
                                    FormValue[i].CharValue^);   (* 3-Jun-91 PFG *)
                FormValue[i].CardValue := ColumnSpec[j].ColumnID;
                IF ColumnSpec[j].Width = 0 THEN (* 4-Mar-91 TGS *)
                    FormValue[i + 1].CardValue := 0;
                ELSE
                    FormValue[i + 1].CardValue := ColumnSpec[j].Width - 1;
                END;
                INC(i, 2);
            END;
        END;
    END;

    WHILE (i <= CN16) DO
        Fill(FormValue[i].CharValue^, " ", 24);
        FormValue[i].CardValue := 0;
        FormValue[i + 1].CardValue := 0;
        INC(i, 2);
    END;

    WITH ChartFormat^ DO                (* 3/22/89 EGK *)
        GetTaskColumnName(  ProgressColumnID,
                            FormValue[PCOL].CharValue^);   (* 3-Jun-91 PFG *)
        FormValue[PCOL].CardValue := ProgressColumnID;
    END;

END MapColumnSpecsToFormValue;




PROCEDURE MapFormValueToColumnSpecs(VAR FormValue   : ARRAY OF AFieldValue;
                                        ChartFormat : AChartFormatPtr);


VAR
    i                       : CARDINAL;
    j                       : CARDINAL;

BEGIN                       (* MapFormValueToColumnSpecs *)

    WITH ChartFormat^ DO
        ColumnCount := 0;
        FOR i := CN1 TO CN16 BY 2 DO
            IF (FormValue[i].CardValue <> 0) THEN
                INC(ColumnCount);
                ColumnSpec[ColumnCount].ColumnID := FormValue[i].CardValue;
                IF FormValue[i + 1].CardValue = 0 THEN (* 4-Mar-91 TGS *)
                    ColumnSpec[ColumnCount].Width := 0;
                ELSE
                    ColumnSpec[ColumnCount].Width := FormValue[i + 1].CardValue + 1;
                END;
            END;
        END;
        ProgressColumnID := FormValue[PCOL].CardValue;      (* 3/22/89 EGK *)
    END;

END MapFormValueToColumnSpecs;





PROCEDURE CheckForm (    Form        : AForm;
                         FieldNo     : AFieldNo;
                     VAR FormValue   : ARRAY OF AFieldValue;
                         CheckReason : ACheckReason;
                     VAR Code        : CARDINAL ):BOOLEAN;
VAR
    ULX, LRX, LRY           : CARDINAL;
    i                       : CARDINAL;
    r                       : REAL;
    Node                    : ATreeNode;
    ChartRecord             : AChartFormatPtr;
    Variety                 : ATaskFilter;
    CodeIn                  : CARDINAL;
    T                       : ATaskPtr;
    TempField               : AFieldValue;
    Column                  : AColumnTreeRecord;
    S                       : ARRAY [0..99] OF CHAR;
    S2                      : ARRAY [0..255] OF CHAR;
    Changed                 : BOOLEAN;
    Protect                 : BOOLEAN;
    DataRecord              : AColumnDataRecord;
    PctColumnsTreeOK        : BOOLEAN;


    PROCEDURE SaveNotesToText();
    BEGIN                      (* SaveNotesToText *)

        TrimRear(FormValue[NOTE].CharValue^);
        IF NOT TextExists(LayoutNotes) THEN
            IF (FormValue[NOTE].CharValue^[0] = 0C) THEN
                RETURN;
            ELSE
                LayoutNotes := CreateText();
            END;
        END;
        IF NOT AssignLine(FormValue[NOTE].CharValue^, 0, LayoutNotes) THEN
            GetMessage(ModuleNumber + 28, S);
            Error(S);
        END;

    END SaveNotesToText;



BEGIN   (* CheckForm *)

    CodeIn := Code;
    Code := 0;

    CASE FieldNo OF                                               (* 11-Jun-87 LAA *)
    | NAME :
        IF ((CheckReason = CheckFieldExit) OR (CheckReason = CheckFormExit)) THEN
            Copy(FormValue[FieldNo].CharValue^, S);
            TrimRear(S);
            IF (LengthOf(S) = 0) THEN
                DisplayMessage(ModuleNumber + 11);    (* Each layout must be given a unique name. *)
                Burp();
                RETURN FALSE;
            END;
            Node := LayoutTree^.Methods^.GetFirst(LayoutTree);
            WHILE (Node <> NIL) DO
                ChartRecord := Node^.Methods^.GetDataObject(Node);
                IF (StringsEqual(ChartRecord^.Name, S)) THEN (* RSC 1/2/88 *)
                    IF (Node <> LayoutOnForm) THEN
                        DisplayMessage(ModuleNumber + 11);   (* Each layout must be given a unique name. *)
                        Burp();
                        RETURN FALSE;
                    END;
                END;
                Node := Node^.Methods^.NextPreOrder(Node);
            END;

                (*  Erase any previous message  *)

            SetLengthOf(S, 0);
            Message(S);
        ELSIF (CheckReason = CheckFieldKey) THEN
            Code := 04000H + CodeIn;
        END;

    | NOTE :
        IF ((CheckReason = CheckFieldKey) AND (CodeIn = EditKey)) THEN
            SaveNotesToText();
            Copy(FormValue[NAME].CharValue^, S);
            LJust(S);
            TrimRear(S);
            EditText(14,8,79,maxrow-2, ABoxType{ShadowBox,DoubleBox}, S, 0, LayoutNotes, Changed);
            IF (Changed) THEN
                SetFormChange(Form);
            END;
            SetLengthOf(FormValue[NOTE].CharValue^, 0);
            IF TextExists(LayoutNotes) THEN
                CopyLine(LayoutNotes, 0, FormValue[NOTE].CharValue^);
            END;
            Procustes(FormValue[NOTE].CharValue^, HIGH(FormValue[NOTE].CharValue^));
            ShowValue(Form, NOTE, FormValue);
        ELSIF (CheckReason = CheckFormExit) THEN
            SaveNotesToText();
            Compress(LayoutNotes);
        ELSIF (CheckReason = CheckFieldKey) THEN
            Code := 04000H + CodeIn;
        END;

    | GANT :
        Protect := (FormValue[FieldNo].CardValue = 0);
        SetFieldProtection (Form,PCOL,FormValue,Protect);
        SetFieldProtection (Form,PLIN,FormValue,Protect);
        ShowValue(Form,PCOL,FormValue);
        ShowValue(Form,PLIN,FormValue);

    | PCOL :
        IF (CheckReason = CheckFieldKey) THEN
            IF (CodeIn = EditKey) THEN
                Copy (FormValue[FieldNo].CharValue^, Column.Name);
                IF (NOT SearchForPctColumn (Column.Name, Column.ID)) THEN
                    Column.ID := 0;
                END;
                IF (PickPctColumn (maxcol-29, 3, maxcol, maxrow-10,
                                    Column.ID, Column.Name)) THEN

                    FormValue[FieldNo].CardValue := Column.ID;
                    Copy(Column.Name, FormValue[FieldNo].CharValue^);
                    ShowValue(Form, FieldNo, FormValue);
                    SetFormChange(Form);
                END;
            ELSE
                Burp();
            END;
        END;

        IF ((CheckReason = CheckFieldExit) OR (CheckReason = CheckFormExit)) THEN
            Copy(FormValue[FieldNo].CharValue^, Column.Name);
            TrimRear(Column.Name);
            Column.ID := FormValue[FieldNo].CardValue;
            IF (NOT SearchForPctColumn(Column.Name, Column.ID)) THEN
                Burp();
                RETURN FALSE;
            END;
        END;

    | CN1,CN2,CN3,CN4,CN5,CN6,CN7,CN8,CN9,CN10,CN11,CN12,CN13,CN14,CN15,CN16 :
        IF (CheckReason = CheckFieldKey) THEN
            IF (CodeIn = EditKey) THEN
                Copy (FormValue[FieldNo].CharValue^, Column.Name);
                IF (NOT SearchForTaskColumn (Column.Name, Column.ID)) THEN
                    Column.ID := 0;
                END;
                HighlightField( Form, FormValue, FieldNo, CursorResting);
                ChartRecord := LayoutOnForm^.Methods^.GetDataObject(LayoutOnForm);  (* 9-Jan-91 PFG *)
                IF (PickTaskColumn (maxcol-29, 3, maxcol, maxrow-10,
                                    Column.ID, Column.Name)) THEN
                    IF (FormValue[FieldNo].CardValue <> Column.ID) THEN
                        T := NIL;                             (* 08-Feb-88 LAA *)
                        GetColumnInfo(NIL,T,Column.ID,ColumnWidth,
                                        maxcol, DataRecord);
                        FormValue[FieldNo].CardValue := Column.ID;
                        (* 
                        FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue + 1; (* RSC 1/27/89 *)
                        *)
                        FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue; (* 21-Mar-91 TGS *)
                        SetFieldProtection(Form,FieldNo+1,FormValue,FALSE);  (* 30-Dec-87 LAA *)
                    END;
                    SetFormChange(Form);

                END;

                (* In case column names were edited, update all column
                    names on form.  Need to do this even if PickTaskColumn
                    returns FALSE, since the user may have changed some 
                    column other than the highlighted one.  *)

                FOR i := CN1 TO CN16 BY 2 DO
                    IF FormValue[i].CardValue <> 0 THEN
                        GetTaskColumnName(  FormValue[i].CardValue,
                                            FormValue[i].CharValue^);
                    ELSE
                        Fill(FormValue[i].CharValue^, " ", 24);
                        FormValue[i + 1].CardValue := 0;
                    END;
                END;

                (*  Redisplay the column names and widths  *)

                FOR i := CN1 TO CN16+1 DO (* 4-Mar-91 TGS "+1" *)
                    ShowValue(Form, i, FormValue);
                END;

                GetTaskColumnName(  FormValue[PCOL].CardValue,
                                    FormValue[PCOL].CharValue^);

                DisposePctColumnsTree();
                PctColumnsTreeOK := CreatePctColumnsTree();

                ShowValue(Form, PCOL, FormValue);

                HighlightField( Form, FormValue, FieldNo, CursorOff);
            ELSIF ((CodeIn = MoveUpKey) AND (FieldNo <> CN1)) THEN
                TempField := FormValue[FieldNo];
                FormValue[FieldNo] := FormValue[FieldNo - 2];
                FormValue[FieldNo - 2] := TempField;
                TempField := FormValue[FieldNo + 1];
                FormValue[FieldNo + 1] := FormValue[FieldNo - 1];
                FormValue[FieldNo - 1] := TempField;
                ShowValue(Form, FieldNo, FormValue);
                ShowValue(Form, FieldNo + 1, FormValue);
                ShowValue(Form, FieldNo - 1, FormValue);
                ShowValue(Form, FieldNo - 2, FormValue);
                Code := 08000H + FieldNo - 2;
                SetFormChange(Form);
            ELSIF ((CodeIn = MoveDownKey) AND (FieldNo <> CN16)) THEN
                TempField := FormValue[FieldNo];
                FormValue[FieldNo] := FormValue[FieldNo + 2];
                FormValue[FieldNo + 2] := TempField;
                TempField := FormValue[FieldNo + 1];
                FormValue[FieldNo + 1] := FormValue[FieldNo + 3];
                FormValue[FieldNo + 3] := TempField;
                ShowValue(Form, FieldNo, FormValue);
                ShowValue(Form, FieldNo + 1, FormValue);
                ShowValue(Form, FieldNo + 2, FormValue);
                ShowValue(Form, FieldNo + 3, FormValue);
                Code := 08000H + FieldNo + 2;
                SetFormChange(Form);
            ELSE
                Burp();
            END;
        END;

        IF ((CheckReason = CheckFormEntry) 
            OR (CheckReason = CheckFieldExit)) THEN
            Copy(FormValue[FieldNo].CharValue^, S2);
            TrimRear(S2);
            IF (LengthOf(S2) = 0) THEN
                FormValue[FieldNo + 1].CardValue := 0;
                SetFieldProtection(Form, FieldNo + 1, FormValue, TRUE);
            ELSE
                SetFieldProtection(Form, FieldNo + 1, FormValue, FALSE);
            END;
        END;

            (* Changed this from "CheckFieldExit" 9/12/89 EGK *)
                                (*    *)

        IF ((CheckReason = CheckFieldChange) OR (CheckReason = CheckFormExit)) THEN
            Copy(FormValue[FieldNo].CharValue^, Column.Name);
            TrimRear(Column.Name);
            Column.ID := FormValue[FieldNo].CardValue;
            IF (LengthOf(Column.Name) > 0) THEN
                IF (NOT SearchForTaskColumn(Column.Name, Column.ID)) THEN
                    Burp();
                    RETURN FALSE;
                ELSIF (Column.ID <> FormValue[FieldNo].CardValue) THEN
                    FormValue[FieldNo].CardValue := Column.ID;    (* 6-Sep-89 WKH *)

                    (* Get Default Column Width *)
                    T := NIL;
                    GetColumnInfo(NIL, 
                                    T, 
                                    Column.ID, 
                                    ColumnWidth, 
                                    3, 
                                    DataRecord);

                    FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue;
                    ShowValue(Form, FieldNo + 1, FormValue);

                END;

            ELSE
                FormValue[FieldNo].CardValue := 0;            (* 23-Dec-87 LAA *)
            END;
        END;

    | CW1,CW2,CW3,CW4,CW5,CW6,CW7,CW8,CW9,CW10,CW11,CW12,CW13,CW14,CW15,CW16 :
        IF ((CheckReason = CheckFieldExit) OR (CheckReason = CheckFormExit)) THEN
            IF (FormValue[FieldNo].CardValue > maxcol + 1) THEN
                GetMessage(ModuleNumber+1,S2);
                Error(S2);
                RETURN FALSE;
            END;
        ELSIF (CheckReason = CheckFieldKey) THEN
            Code := 04000H + CodeIn;
        END;
    ELSE
        IF (CheckReason = CheckFieldKey) THEN
            Code := 04000H + CodeIn;
        END;
    END;

    RETURN TRUE;

END CheckForm;






PROCEDURE DisplayControlForm(    ChartFormat : AChartFormatPtr)
                                                               : ACode;

VAR
    Code                    : ACode;
    i                       : CARDINAL;
    Node                    : ATreeNode;
    CTask                   : ATreeNode;
    j                       : CARDINAL;
    TempScale               : ADuration;
    FormValue               : ARRAY [0..40] OF AFieldValue;
    S                       : ARRAY [0..1] OF CHAR;
    TempScaleUnit           : ADurationUnit;
    TaskColumnsTreeOK       : BOOLEAN;
    PctColumnsTreeOK        : BOOLEAN;
    TextOK                  : BOOLEAN;

    PROCEDURE CheckScale();
    VAR
        s   : ARRAY [0..255] OF CHAR;
    BEGIN
        WITH ChartFormat^ DO
            TempScale     := scale;
            TempScaleUnit := scaleunit;

            AdjustScale( TempScale, TempScaleUnit );

            IF (scale <> TempScale) OR
               (scaleunit <> TempScaleUnit) THEN
                GetMessage( ModuleNumber + 15, s );  (* Scale AFU *)
                IF (scaleunit > Days) OR
                    (NoYes(s)) THEN
                    scale     := TempScale;
                    scaleunit := TempScaleUnit;
                END;
            END;
        END;
    END CheckScale;


BEGIN   (* DisplayControlForm *)

    TaskColumnsTreeOK := CreateTaskColumnsTree();
    PctColumnsTreeOK := CreatePctColumnsTree();                    (* 8/4/89 EGK *)
    TextOK := AssignText (ChartFormat^.Notes, LayoutNotes);

    IF (NOT TaskColumnsTreeOK) OR (NOT PctColumnsTreeOK) OR (NOT TextOK) THEN
        IF (TaskColumnsTreeOK) THEN
            DisposeTaskColumnsTree();
        END;
        IF (PctColumnsTreeOK) THEN
            DisposePctColumnsTree();
        END;
        IF (TextOK) THEN
            DiscardText(LayoutNotes);
        END;
        RETURN CancelKey;
    END;

    WITH ChartFormat^ DO
        NEW(FormValue[NAME].CharValue);
        Copy(Name, FormValue[NAME].CharValue^);
        NEW(FormValue[NOTE].CharValue);
        SetLengthOf(FormValue[NOTE].CharValue^, 0);
        IF TextExists(LayoutNotes) THEN
            CopyLine(LayoutNotes, 0, FormValue[NOTE].CharValue^);
        END;
        TempScaleUnit := scaleunit;
        TempScale := scale;
        LOOP
            i := DownScale(TempScale,TempScaleUnit);
            IF (TempScale = NoDuration ) OR (i > 0) THEN
                EXIT;
            END;
            DEC(TempScaleUnit);
        END;
        FormValue[GANT].CardValue := ORD(GanttShowing);
        FormValue[SCAL].CardValue := i;
        FormValue[UNIT].CardValue := ORD(TempScaleUnit);
        FormValue[AVP].CardValue := ORD(AVPShowing);
        FormValue[SLAC].CardValue := ORD(slackstyle);
        FormValue[PLIN].CardValue := 1-ORD(ProgressLineType);         (* 3/22/89 EGK *)
        FOR i := CN1 TO CN16 BY 2 DO
            NEW(FormValue[i].CharValue);
        END;
        NEW(FormValue[PCOL].CharValue);
        MapColumnSpecsToFormValue(ChartFormat, FormValue);
(* 4-Mar-91 TGS - moved this inside MapColumnSpecsTo.. & MapFormValuesTo..
        FOR i := CN1 TO CN16 BY 2 DO
            IF (FormValue[i + 1].CardValue > 0) THEN
                DEC(FormValue[i + 1].CardValue);
            END;
        END;
*)
    END;
    
    Code := DoForm(0,0,maxcol,GanttWEnd,4,TRUE,FormValue,CheckForm);

    IF (Code = ExitKey) THEN
        WITH ChartFormat^ DO
            Copy(FormValue[NAME].CharValue^, Name);
            TrimRear(Name);                                       (* 11-Sep-89 WKH *)
            DiscardText(Notes);                                   (* 10-Feb-88 LAA *)
            IF (AssignText(LayoutNotes, Notes)) THEN END;
            GanttShowing := FormValue[GANT].CardValue > 0;
            scale := FormValue[SCAL].CardValue;
            scaleunit := VAL(ADurationUnit,FormValue[UNIT].CardValue);
            IF (scale = NoDuration) THEN scale := OneUnitOfDuration END;
            scale := UpScale(scale,scaleunit);
                (* Make sure that the scale will divide things evenly. *)

            CheckScale();

            AVPShowing := FormValue[AVP].CardValue > 0; 
            slackstyle := VAL(ASlackStyle,FormValue[SLAC].CardValue);
            ProgressLineType := VAL(AGanttLineType, 1-FormValue[PLIN].CardValue);     (* 3/22/89 EGK *)
(* 5-Mar-91 TGS - This is in MapFormValueToColumnSpecs now...
            FOR i := CN1 TO CN16 BY 2 DO
                IF (FormValue[i + 1].CardValue > 0) THEN
                    INC(FormValue[i + 1].CardValue);
                END;
            END;
*)
            MapFormValueToColumnSpecs(FormValue, ChartFormat);

                (*  Calculate starting positions and where the Gantt bars will start  *)
            DetermineFirstGantt(ChartFormat);

                (*  Check if the task name is on screen.  *)
            j := 0;
            FOR i := 1 TO ColumnCount DO
                IF ((ColumnSpec[i].ColumnID = TaskNameColumn)
                   AND (j = 0)) THEN                              (* 15-Nov-88 LAA *)
                    j := i;
                END;
            END;

            IF ((j = 0) OR (ColumnSpec[j].Position > maxcol + 1)
               OR (ColumnSpec[j].Width = 0)) THEN
                TaskNameOnScreen := FALSE;
            ELSE
                TaskNameOnScreen := TRUE;
            END;
        END;

        ScheduleSaved := FALSE;                                    (* 12/15/86 LAA *)
        ConfigSaved := FALSE;
        DisplayScheduleLight();         (* 12-Jul-91 PFG *)
    END;
    DISPOSE(FormValue[NAME].CharValue);
    DISPOSE(FormValue[NOTE].CharValue);
    FOR i := CN1 TO CN16 BY 2 DO
        DISPOSE(FormValue[i].CharValue);
    END;
    DISPOSE (FormValue[PCOL].CharValue);
    DiscardText(LayoutNotes);                                     (* 10-Feb-88 LAA *)
    DisposeTaskColumnsTree();
    DisposePctColumnsTree();                    (* 8/4/89 EGK *)

        (*  Remove any left-over messages from the message line.  *)

    SetLengthOf(S, 0);
    Message(S);

    RETURN Code;

END DisplayControlForm;






(*----------------------------------------------------------------------------
    DoLayoutForm --

    Bring up the layout form to allow editing of a layout record.

    Preconditions:
        The layout parameter must be a valid layout node.

    Postconditions:
        The layout record will be changed as directed by the user, unless the
        form is left with ESC.  The code will be returned.
----------------------------------------------------------------------------*)

PROCEDURE DoLayoutForm(    Layout           : ATreeNode)
                                                        : ACode;

BEGIN                       (* DoLayoutForm *)

    (*<DEBUGGING*)
    ValidateTreeNode(Layout);
    (*DEBUGGING*)

    LayoutOnForm := Layout;               (* for usage of CheckProc *)

    RETURN DisplayControlForm(Layout^.Methods^.GetDataObject(Layout));

END DoLayoutForm;




PROCEDURE TLLayoutBody();                                         (* 19-Jan-88 LAA *)
VAR
    Copyright               :   ARRAY[0..50] OF CHAR;
BEGIN                       (* TLLayoutBody *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PrivateOverlayContext := OverlayContext();

    WITH PrivateOverlayContext^ DO
        ReturnCode := DoLayoutForm(LayoutNode);
    END;

END TLLayoutBody;




BEGIN

    OverlayID := ImAnInstallableOverlay(TLLayoutBody, AnOverlayProc(NIL));       (* 19-Jan-88 LAA *)
    TLLayoutBody();

END TLLayout.

