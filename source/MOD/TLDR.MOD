MODULE TLDR;


(*  =========================================================================
    Last Edit : July 29, 1991 4:49PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Detail Report form.

    MODIFICATION HISTORY:

        06-APR-89 KKC First version
        01-May-89 KKC - Fixed the message for "No Successors"
                        Make Headeron and Taskperpage fields not hidden when
                        paged report is off.
        08-May-89 KKC - Display task picking list in different position.
        22-May-89 KKC - Check column names when exiting field.
        24-May-89 LAA - Fixed compile errors caused by mismatched parenthesis,
                        and not using the LengthOf procedure when necessary.
        26-May-89 KKC - Highlight field for picking list.
                      - Add 'A' or 'An' in front of each type name.
                      - Display picking lists in different position.
                      - Update column id if user used delete key to
                        delete part of the column name.
                      - beep if user presses F2 in fields that don't have
                        a picking list.
                      - Set Predecessors/Successors Task name hidden and
                        protect if both Predecessors and Successors are not
                        included.
        30-May-89 KKC - Limit numeric fields width to be half of the page
                        width.
        1-Jun-89  KKC - Change IncludeBnkFields to SuppressBlankFields
                        and reverse all the logic dealing with this variable.
        06-Jun-89 KKC - Print Select filter and highlight filters.
        10-Jun-89 WKH - Added support for variable screen rows
        21-Jun-89 KKC - Redfined BOOLEAN variable IsNumber in
                        PrintColumnHeadingAndData.
                      - Do not truncate task columns on the left side if
                        there are no columns on the right.
        12-Jul-89 KKC - Put the dependency and Parentage-Task Name on the
                        same line.
        20-Jul-89 KKC - Patch blanks after all the short labels so that
                        all task data start at the same column.
                      - Make IsNumber a BOOLEAN function.
        27-Jul-89 KKC - Pop up calculator if F2 key is pressed in a numeric
                        field.
        10-Aug-89 KKC - Add copyright message.
        11-Aug-89 KKC - Pass Pointer instead of address.
                      - Add three blank lines between procedures.
        22-Aug-89 KKC - Print a line with '-' between tasks.
        24-Aug-89 KKC - Default OneTaskPerPage to FALSE.
        14-Sep-89 EGK   Added HoldInDataFile to the HoldTypeSet.
        18-Oct-89 KKC - Left justify all task data
        10-Aug-90 RSC - Ajust for new AssignmentCost proc.
        26-Sep-90 PFG   In case user edited a task column name, check to see
                        if the same name is in any other field.  If it is,
                        redisplay those fields correctly.
         7-Jan-91 AJL - Added the VARYA toggle and code to display the
                        details of each assignment.
        22-Jan-91  RSC  Import LongDurationToString from LongDuration rather
                        than from TimeFormat. 
        23-Jan-91 RSC   Put holder items in flexstor. 
        13-Feb-91 RSC   Added HeapNoOwner to held item. 
        13-Feb-91 AJL - Added optional printing of assignments to the 
                        report form.
       14-Feb-91 AJL  - Rename EndOf ActualDate to EndOfSpentDate.
       19-Mar-91 AJL  - Fatal if we cannot store our config settings.
                      - Initialize the new options.
                      - Make the parameter to StartUsingDetailSettings a
                        VAR so the program won't crash every time I use it.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
         3-Jun-91 PFG   Because the form values are saved from one use of the
                        report form to the next, changes in column names
                        weren't taking effect.  Now we call GetColumnInfo for
                        each task column on the form to update its name.
        10-Jun-91 PFG   Call GetTaskColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a task 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
        2-Jul-91  AJL - Added parameters to FilterNotes.
       29-Jul-91  EGK - Removed what looked like an unnecessary call to
                        SetFormChange from the checkproc.  The result was
                        Eve bug #4821, in which simply esc-ing from the form
                        without making any changes was invoking the confirm-
                        ation dialog box.
       24-Sep-91  LAA - For CheckFieldExit processing for the TaskColumnNames
                        fields, if the string length is zero, set the 
                        CardValue to zero.  For CheckFieldKey, called 
                        SearchForTaskColumn to verify that the column name is
                        ok, and if not set the CardValue to zero.
       03-Mar-92  LAA - In DescribeResourceAss, changed from using CtoS to
                        FormatAsAmount, since the number at of an assignment
                        can now contain a decimal place.
       04-Mar-92  LAA - Expanded the width of the Rate field so it can hold
                        the extra width that may now be possible with a
                        decimal in the NumberAt field.
        6-Apr-92 TGS    Interface to LongDurationToString was changed to 
                        return position of last numeric character.
        6-Apr-92 TGS    Call AssignmentDollars() instead of AssignmentCosts().
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskFilter, ATaskFilterSet, ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM AssgnCalc              IMPORT
    (* PROC *)                  AssignmentDollars;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentPointer,
                                AnAssignmentAttribute,  AnAssignmentAttributeSet,
    (* PROC *)                  ForEachAssignment;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
                                AColumnDataField, ASetOfColumnDataFields,
    (* VAR   *) (* PROC *)      GetColumnString, GetColumnInfo;

FROM Codes                  IMPORT
    (* TYPE  *)                 ACode;

FROM Dialog                 IMPORT
    (* PROC  *)                 FatalError, Error, Burp, NotYetImplemented;

FROM EdgeInfo               IMPORT
    (* PROC  *)                 DescribeEdge;

FROM Edges                   IMPORT
    (* TYPE  *)                 AnEdgePtr;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CreateExtObjectWithSize,
                                SetExtData, GetExtData, GetExtSize; 

    
FROM Filter1                IMPORT
    (* PROC  *)                 TaskFiltersPassed, AssignmentFiltersPassed;

FROM FormCon                IMPORT
    (* TYPE  *)                 AFieldNo;

FROM Forms                  IMPORT
    (* TYPE  *)                 AFieldValue, AForm, ACheckReason,
                                ACursorAttribute, AStringValue,
    (* PROC  *)                 SetFieldHidden, SetFieldProtection,
                                ShowValue, SetFormChange, DoForm,
                                HighlightField;

FROM Gantt                  IMPORT
    (* TYPE  *)                 AGanttLineType;

FROM Holder                 IMPORT
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem, HoldThis, DeleteHeldItem; 

FROM Kbio                   IMPORT
    (* CONST *)                 AbsoluteMaxRow, maxrow, maxcol;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, EditKey, MoveUpKey, MoveDownKey;

FROM KeywdSub               IMPORT
     (* PROC *)                 MakeSubstitutions;

FROM Layout                 IMPORT
    (* VAR   *)                 GanttWEnd;

FROM LongDuration           IMPORT
    (* PROC *)                  LongDurationToString; 

FROM LStrings               IMPORT
    (* PROC  *)                 ConcatLS, Copy, CtoS, Fill, LengthOf,
                                Search, SetLengthOf, SubStr, TrimFront,
                                ConcatS, Insert, LJust, StoC,
                                Procustes, TrimRear, RJust, SetString;

FROM MagicNum               IMPORT
    (* CONST *)                 IsRealValue,
                                IsIntValue,
                                IsCardValue,
                                IsBoolValue,
                                IsCurrency;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage, ConcatMessage;

FROM PrintCaptions          IMPORT
    (* PROC  *)                 FilterNotes, PageHead;

FROM PrintSupport           IMPORT
    (* VAR   *)                 Stopped,
    (* PROC  *)                 PageWidth, PrintLine,  PrintText,
                                EndReport, StartReport, RowsLeft,
                                AllowUnlimitedPageLength;

FROM RealFormat IMPORT
    (* VAR  *)      DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROC *)      FormatAsAmount,      FormatAsCurrency;

FROM RsrcCalc   IMPORT
    (* TYPE *)      AnAssignmentCostType, AnAssignmentCostTypeSet,
    (* PROC *)      AssignmentCost;

FROM RsrcMod                IMPORT
    (* CONST *)                 ResourceNameLength,
    (* TYPE *)                  AResourceType, ACostStyle;

FROM SegWords               IMPORT
    (* PROC *)                  WordNumber;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE  *)                 ADDRESS, ADR, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 WBSColumn,
                                TaskNameColumn,
                                AbbrevParentage,
                                BlanksColumn;

FROM TaskColumns            IMPORT
    (* PROCS *)                 CreateTaskColumnsTree, PickTaskColumn,
                                DisposeTaskColumnsTree, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Text                   IMPORT
    (* PROC  *)                 LineExists, CopyLine;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADurationUnit;

FROM TimeFormat             IMPORT
    (* VAR *)                   EndDateStyle,
    (* PROCS *)                 TimeUtoS, FormatAsEndDateStyle;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnList,
    (* PROC *)                  NumberOfRatesInList, GetVaryingAssgnListEntry;


CONST
    ModuleNumber        =   11700;
    MaxWidth            =   255;
    TLDRFORMID          =   49;
    Normal              =   0;
    Bold                =   1;
    MaxNumberLength     =   15;

    TASKNAMESFMT        =   0;
    FIRSTTASKFLD        =   1;
    LASTTASKFLD         =   10;
    INCNOTE             =   11;
    NNOTELINESINC       =   12;
    INCASSIGN           =   13;
    INCCOSTS            =   14;
    INCPREDECESSORS     =   15;
    INCSUCCESSORS       =   16;
    DEPENDENCYNAMESFMT  =   17;
    INCLUDETITLES       =   18;
    PAGEDREPORT         =   19;
    HEADERON            =   20;
    TASKPERPAGE         =   21;

    LastDetailFormField =   21;

    LASTTASKINFO        =   LASTTASKFLD - FIRSTTASKFLD;
    NTASKCOLUMNSROW     =   ( LASTTASKINFO + 1 ) DIV 2;

    DefaultColWidth     =   30;

    NBottomRowsReserved =   2;

    DependencySize      =   17;     (* 15 + 2.  1 '(' and 1 for ')' *)

TYPE
    ATaskNameFormat         =   (FullOutline, AbbreviatedOutLine, NameOnly, WBSAndName);
    AShowHeaderMethod       =   (FirstPage, EveryPage);
    AnAssignmentFormat      =   (AFNone, AFSummary, AFDetail);

    AColumnInfo      =   RECORD
        ColumnName          :   AStringValue;
        ColumnWidth         :   CARDINAL; (* User can not change this at this moment *)
        ColumnID            :   CARDINAL;
    END;

    ADetailReportInputValues    =   RECORD
        TaskNameFmt         :   ATaskNameFormat;
        TaskColumn          :   ARRAY[0..LASTTASKINFO] OF AColumnInfo;
        IncludeNote         :   BOOLEAN;
        NNoteLines          :   CARDINAL;
        AssignmentFormat    :   AnAssignmentFormat;
        IncludeCosts        :   BOOLEAN;
        IncludePredecessors :   BOOLEAN;
        IncludeSuccessors   :   BOOLEAN;
        DependencyNameFmt   :   ATaskNameFormat;
        SuppressBlankField  :   BOOLEAN;
        PagedReport         :   BOOLEAN;
        HeaderOn            :   AShowHeaderMethod;
        OneTaskPerPage      :   BOOLEAN;
    END;
    ADetailReportInputValuesPtr =   POINTER TO ADetailReportInputValues;

    ADetailReportPrintControls  =   RECORD
        PrintPageWidth      :   CARDINAL;
        ReportPageNumber    :   CARDINAL;
        PageHeaderOn        :   BOOLEAN;
        PageFooterOn        :   BOOLEAN;
        AtTopOfPage         :   BOOLEAN;
        PrintAttribute      :   CARDINAL;
    END;
    ADetailReportPrintControlsPtr   =   POINTER TO ADetailReportPrintControls;

    ADetailReportSettings   =   RECORD
        FormInputsPtr       :   ADetailReportInputValuesPtr;
        FormPrintsPtr       :   ADetailReportPrintControlsPtr;
        EmptyReport         :   BOOLEAN;
        TaskTreeNode        :   ATreeNode;
        TaskPointer         :   ATaskPtr;
    END;
    ADetailReportSettingsPtr    =   POINTER TO ADetailReportSettings;

    AGetColumnDataProc      =   PROCEDURE(ADetailReportSettingsPtr, CARDINAL,
                                          VAR ARRAY OF CHAR);

    AGetColumnNameProc      =   PROCEDURE(ADetailReportSettingsPtr, CARDINAL,
                                          VAR ARRAY OF CHAR,
                                          VAR ARRAY OF CHAR);

    APortionArray =  ARRAY [0..6] OF ARRAY [0..31] OF CHAR;

    (* Substitute portions -- A keyword substitution procedure.

       KeyWord is a string containing a number in the range
       0..HIGH(APortionArray).

       Context is the address of APortionArray.

       Returns the string in the PortionArray indexed by KeyWord.

    *)


PROCEDURE SubstitutePortions( VAR KeyWord : ARRAY OF CHAR;
                              VAR KeyValue: ARRAY OF CHAR;
                                  Context : ADDRESS );
VAR
    Portion : POINTER TO APortionArray;
    i,j     : CARDINAL;
BEGIN
    Portion := Context;
    j       := 1;
    i       := StoC(KeyWord,j);
    Copy(Portion^[i], KeyValue );
END SubstitutePortions;









(***************************************************************************
    NPrintRowsOnCurrentPage  -
        Make sure we can print n lines onto the same page.
****************************************************************************)
PROCEDURE NPrintRowsOnCurrentPage(
                              DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                                 n : CARDINAL
                                 ) : BOOLEAN;
VAR
    i                       :   CARDINAL;
BEGIN
    IF ( NOT DetailRptSettingsPtr^.FormInputsPtr^.PagedReport ) THEN
        RETURN TRUE;
    END;

    i := RowsLeft();
    IF (i = 0) THEN RETURN TRUE; END; (* We are at top of page *)

    RETURN ( i >= (NBottomRowsReserved + n) )
END NPrintRowsOnCurrentPage;




(****************************************************************************
    MovePrintHeadToPageEnd  -
        Force the print head to end of page by sending blank lines to
    the printer.  It will not print on the reserved area on the bottom.
****************************************************************************)
PROCEDURE MovePrintHeadToPageEnd( 
                              DetailRptSettingsPtr : ADetailReportSettingsPtr
                                );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
    i                       :  CARDINAL;
BEGIN
    WITH DetailRptSettingsPtr^ DO
        SetLengthOf(NoCharBuffer, 0);

        IF ( DetailRptSettingsPtr^.FormInputsPtr^.PagedReport ) THEN
            i := RowsLeft();
        ELSE
            i := NBottomRowsReserved + 2;   (* leave 2 blank lines *)
        END;

        WHILE i > NBottomRowsReserved DO
            DEC(i);
            PrintLine( NoCharBuffer, Normal );
        END;
    END;
END MovePrintHeadToPageEnd;




(****************************************************************************
    MovePrintHeadToPageEndIfNeeded  -
        Force the print head to end of page if OneTaskPerPage flag is set.
****************************************************************************)
PROCEDURE MovePrintHeadToPageEndIfNeeded( 
                               DetailRptSettingsPtr : ADetailReportSettingsPtr
                                        );
VAR
    i                       :  CARDINAL;
BEGIN
    IF ( DetailRptSettingsPtr^.FormInputsPtr^.OneTaskPerPage ) THEN
        MovePrintHeadToPageEnd( DetailRptSettingsPtr );
    END;
END MovePrintHeadToPageEndIfNeeded;




(****************************************************************************
    PrintDetailreportHeader -
        Print out all headerer information;
    Set at topofpage flag to false;
****************************************************************************)
PROCEDURE PrintDetailReportHeader( 
                               DetailRptSettingsPtr : ADetailReportSettingsPtr
                                 );
BEGIN
    PageHead();
    FilterNotes(TRUE,    (* Select Filters *)
                TRUE);   (* Highlight Filters *)
    DetailRptSettingsPtr^.FormPrintsPtr^.AtTopOfPage := FALSE;
END PrintDetailReportHeader;




PROCEDURE PrintPageNumber( DetailRptSettingsPtr : ADetailReportSettingsPtr );
VAR
    Portions     : APortionArray;
    Line         :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        IF ( PageFooterOn ) THEN
            INC(ReportPageNumber);
            CtoS(ReportPageNumber, Portions[0]);
            GetMessage(ModuleNumber + 1, Line); (* TIME LINE Detail Report Page *0* *)
            MakeSubstitutions( Line, HIGH(Line), SubstitutePortions,
                               ADR(Portions) );
            PrintLine(Line, Normal);
        ELSE
            SetLengthOf(Line, 0);
            PrintLine(Line, Normal);
        END;
    END;
END PrintPageNumber;




(****************************************************************************
    PrintDetailReportFooter -
        Print out all footer information ( only strip and page number for now)
    Set up the flag for report header. Set at topofpage flag to true;
****************************************************************************)
PROCEDURE PrintDetailReportFooter( 
                               DetailRptSettingsPtr : ADetailReportSettingsPtr
                                 );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
     WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        SetLengthOf(NoCharBuffer, 0);
        PrintLine( NoCharBuffer, Normal );
        PrintPageNumber( DetailRptSettingsPtr );
        AtTopOfPage := TRUE;
        PageHeaderOn := ( HeaderOn = EveryPage );
     END;
    END;
END PrintDetailReportFooter;




(****************************************************************************
    PrintAText  -
        print out text.
        Print report header if at the top of page.
        Print report footer if at the bottom of page.
****************************************************************************)
PROCEDURE PrintAText(
                     DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                 VAR Line : ARRAY OF CHAR;
                                PrintMode : CARDINAL
                    );
BEGIN
    WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        AtTopOfPage := FALSE;
        IF ( RowsLeft() = NBottomRowsReserved ) THEN
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;
        IF ( PageHeaderOn ) THEN
            PageHeaderOn := FALSE;
            PrintDetailReportHeader( DetailRptSettingsPtr );
        END;
        PrintText(Line, PrintMode);
    END;
END PrintAText;




(****************************************************************************
    PrintALine  -
        print a line.
        Print report header if at the top of page.
        Print report footer if at the bottom of page.
****************************************************************************)
PROCEDURE PrintALine(
                     DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                 VAR Line : ARRAY OF CHAR;
                                PrintMode : CARDINAL
                    );
BEGIN
    WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        AtTopOfPage := FALSE;
        IF ( RowsLeft() = NBottomRowsReserved ) THEN
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;
        IF ( PageHeaderOn ) THEN
            PageHeaderOn := FALSE;
            PrintDetailReportHeader( DetailRptSettingsPtr );
        END;
        PrintLine(Line, PrintMode);
    END;
END PrintALine;




PROCEDURE PrintBlankLine( DetailRptSettingsPtr : ADetailReportSettingsPtr );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    SetLengthOf(NoCharBuffer, 0);
    PrintALine(DetailRptSettingsPtr, NoCharBuffer, Normal);
END PrintBlankLine;




(****************************************************************************
    PrintFormatName -
        Print task name in one of the following formats:
            Full OutLine
            Abbreviated outline.
            NameOnly
            WBS & Name
****************************************************************************)
PROCEDURE PrintFormatName(
                          DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                      TaskNode : ATreeNode;
                                          Task : ATaskPtr;
                                    FormatName : ATaskNameFormat
                         );
CONST
    MaxTreeHeight           =   20;
VAR
    i, i2                   :   INTEGER;
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
    ParentNodeList          :   ARRAY [0..MaxTreeHeight] OF ATreeNode;
    TmpNode                 :   ATreeNode;
    TmpTask                 :   ATaskPtr;
BEGIN
    WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        i := PrintPageWidth;
        CASE FormatName OF
        | FullOutline:
            TmpNode := TaskNode;
            IF ( TmpNode = NIL ) THEN RETURN; END;
            i2 := MaxTreeHeight;
            ParentNodeList[i2] := TmpNode;
            WHILE ( (i2 >= 0)  AND (TmpNode <> NIL) ) DO
                TmpNode := TmpNode^.Methods^.Parent (TmpNode);
                DEC(i2);
                ParentNodeList[i2] := TmpNode;
            END;

            (* Make sure we can print all level on same page *)
            IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr,
                                                   MaxTreeHeight - i2 ) ) THEN
                MovePrintHeadToPageEnd( DetailRptSettingsPtr );
                PrintDetailReportFooter( DetailRptSettingsPtr );
            END;

            INC(i2);
            WHILE ( i2 <= MaxTreeHeight ) DO
                TmpNode := ParentNodeList[i2];
                TmpTask := TmpNode^.Methods^.LockFlexStorDataObject (TmpNode);
                IF ( GetColumnString(TmpNode, TmpTask, TaskNameColumn, Plan,
                                                               i, Line) ) THEN
                    PrintALine( DetailRptSettingsPtr, Line, PrintAttribute);
                END;
                TmpNode^.Methods^.UnlockFlexStorDataObject (TmpNode);
                INC(i2);
            END;
            RETURN;
        | AbbreviatedOutLine:
            IF ( GetColumnString(TaskNode, Task, AbbrevParentage, Plan, i,
                                Line) ) THEN
                TrimFront(Line);
                TrimRear(Line);
                ConcatMessage(Line, ModuleNumber + 3); (* ' - ' *)
            END;
        | NameOnly:
            SetLengthOf(Line, 0);
        | WBSAndName:
            IF ( GetColumnString(TaskNode, Task, WBSColumn, Plan, i, Line) )
            THEN
                TrimFront(Line);
                TrimRear(Line);
                ConcatMessage(Line, ModuleNumber + 3); (* ' - ' *)
            END;
        END;
        IF ( GetColumnString(TaskNode, Task, TaskNameColumn, Plan, i, Line2) )
        THEN
            TrimFront(Line2);
            TrimRear(Line2);
            ConcatLS(Line, Line2);
            PrintALine( DetailRptSettingsPtr, Line, PrintAttribute);
        END;
    END;
END PrintFormatName;




(****************************************************************************
    PrintDependencies   -
        Print predecessor and sucecessor informations.
****************************************************************************)
PROCEDURE PrintDependencies(
                            DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                    VAR TaskNode : ATreeNode;
                                   DependentEdge : AnEdgePtr
                           );
VAR
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
    Task                    :   ATaskPtr;
    i                       :   CARDINAL;
BEGIN
    WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        IF ( GetColumnString(TaskNode, Task, TaskNameColumn, Plan,
                                                      PrintPageWidth, Line2) )
        THEN
            TrimFront(Line2);
            TrimRear(Line2);
        END;
        i := PrintPageWidth - DependencySize - LengthOf(Line2);
        CASE DetailRptSettingsPtr^.FormInputsPtr^.DependencyNameFmt OF
        | AbbreviatedOutLine:
            IF ( GetColumnString(TaskNode, Task, AbbrevParentage, Plan, i,
                                Line) ) THEN
                TrimFront(Line);
                TrimRear(Line);
                ConcatMessage(Line, ModuleNumber + 3); (* ' - ' *)
            END;
        | NameOnly:
            SetLengthOf(Line, 0);
        | WBSAndName:
            IF ( GetColumnString(TaskNode, Task, WBSColumn, Plan, i, Line) )
            THEN
                TrimFront(Line);
                TrimRear(Line);
                ConcatMessage(Line, ModuleNumber + 3); (* ' - ' *)
            END;
        END;
        ConcatLS(Line, Line2);
        PrintAText( DetailRptSettingsPtr, Line, PrintAttribute);
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
        Task := NIL;                  (* Safety !!! *)
        DescribeEdge(DependentEdge, FALSE, Line2);
        IF ( LengthOf( Line ) > 0 ) THEN
            GetMessage(ModuleNumber + 5, Line);     (* ' (' *)
            PrintAText( DetailRptSettingsPtr, Line, PrintAttribute);
            PrintAText( DetailRptSettingsPtr, Line2, PrintAttribute);
            GetMessage(ModuleNumber + 6, Line);     (* ') ' *)
            PrintALine( DetailRptSettingsPtr, Line, PrintAttribute);
        END;
    END;
END PrintDependencies;




(****************************************************************************
    PrintTaskSuccessors -
        Print successor informations.
****************************************************************************)
PROCEDURE PrintTaskSuccessors(DetailRptSettingsPtr : ADetailReportSettingsPtr);
VAR
    Successor               :   AnEdgePtr;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    STaskNode               :   ATreeNode;
    i                       :   CARDINAL;
BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
      WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        IF ( NOT IncludeSuccessors ) THEN
            RETURN
        END;

        Successor := TaskPointer^.desctasks;

        IF  ( ( Successor = NIL )
            AND
            ( SuppressBlankField ) ) THEN
            RETURN;
        END;

        IF ( NOT AtTopOfPage ) THEN
            PrintBlankLine( DetailRptSettingsPtr );
        END;

        IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 2 ) ) THEN
            MovePrintHeadToPageEnd( DetailRptSettingsPtr );
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;

        GetMessage(ModuleNumber + 56, Line); (* Successors (tasks which come after) *)
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        i := LengthOf(Line);
        Fill(Line, '-', i);
        PrintALine( DetailRptSettingsPtr, Line, Normal);

        IF (Successor = NIL) THEN
            GetMessage(ModuleNumber + 58, Line); (* No predecessors for this task *)
            PrintALine( DetailRptSettingsPtr, Line, PrintAttribute);
            RETURN;
        END;

        WHILE (Successor <> NIL) DO
            STaskNode := Successor^.tailtask;
            PrintDependencies(DetailRptSettingsPtr, STaskNode, Successor);
            Successor := Successor^.headlink;
        END;

      END;
     END;
    END;

END PrintTaskSuccessors;




(****************************************************************************
    PrintTaskPredecessors -
        Print predecessor informations.
****************************************************************************)
PROCEDURE PrintTaskPredecessors(
                               DetailRptSettingsPtr : ADetailReportSettingsPtr
                               );
VAR
    Predecessor             :   AnEdgePtr;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    PTaskNode               :   ATreeNode;
    i                       :   CARDINAL;
BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
      WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        IF ( NOT FormInputsPtr^.IncludePredecessors ) THEN
            RETURN
        END;

        Predecessor := TaskPointer^.antetasks;

        IF  ( ( Predecessor = NIL )
            AND
            ( FormInputsPtr^.SuppressBlankField ) ) THEN
            RETURN;
        END;

        IF ( NOT FormPrintsPtr^.AtTopOfPage ) THEN
            PrintBlankLine( DetailRptSettingsPtr );
        END;


        IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 2 ) ) THEN
            MovePrintHeadToPageEnd( DetailRptSettingsPtr );
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;

        GetMessage(ModuleNumber + 55, Line); (* Predecessor (tasks which come before) *)
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        i := LengthOf(Line);
        Fill(Line, '-', i);
        PrintALine( DetailRptSettingsPtr, Line, Normal);

        IF (Predecessor = NIL) THEN
            GetMessage(ModuleNumber + 59, Line); (* No predecessors for this task *)
            PrintALine( DetailRptSettingsPtr, Line, PrintAttribute);
            RETURN;
        END;

        WHILE (Predecessor <> NIL) DO
            PTaskNode := Predecessor^.headtask;
            PrintDependencies(DetailRptSettingsPtr, PTaskNode, Predecessor);
            Predecessor := Predecessor^.taillink;
        END;

      END;
     END;
    END;

END PrintTaskPredecessors;




(****************************************************************************
    GetTaskData -
        This procedure calls GetColumnString to get the data for task column.
****************************************************************************)
PROCEDURE GetTaskData(
                      DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                     Index : CARDINAL;
                                  VAR Line : ARRAY OF CHAR
                     );
BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
(*
        IF ( TaskColumn[Index].ColumnID <> TaskNameColumn ) THEN
            IF ( GetColumnString(TaskTreeNode, TaskPointer,
                                TaskColumn[Index].ColumnID, Plan,
                                TaskColumn[Index].ColumnWidth, Line) ) THEN
            ELSE
                GetMessage(ModuleNumber + 2, Line); (* N/A *)
            END;
        ELSE
*)
            IF ( GetColumnString(TaskTreeNode, TaskPointer,
                                TaskColumn[Index].ColumnID, Plan,
                                MaxWidth, Line) ) THEN
                TrimFront(Line);
            ELSE
                GetMessage(ModuleNumber + 2, Line); (* N/A *)
            END;
(*
        END;
*)
        Procustes(Line, TaskColumn[Index].ColumnWidth);
     END;
    END;
END GetTaskData;




(****************************************************************************
    GetTaskColumnHeading    -
        Get the heading for given task.
****************************************************************************)
PROCEDURE GetTaskColumnHeading(
                              DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                             Index : CARDINAL;
                                          VAR Line : ARRAY OF CHAR
                              );

BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
        SetLengthOf( Line, 0 );
        IF ( TaskColumn[Index].ColumnID <> BlanksColumn ) THEN

            GetTaskColumnName(  TaskColumn[Index].ColumnID,
                                Line ); (* 10-Jun-91 PFG *)

            ConcatMessage(Line, ModuleNumber + 4); (* ': ' *)
        ELSE
            Fill( Line, ' ', 1 );
        END;
     END;
    END;
END GetTaskColumnHeading;




(*
(****************************************************************************
    IsNumber    -
        Check if current field is a number.
****************************************************************************)
PROCEDURE IsNumber(
                   DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                  Index : CARDINAL
                  ) : BOOLEAN;
VAR
    DataRecord              :   AColumnDataRecord;
BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
        GetColumnInfo(TaskTreeNode,TaskPointer,
                            TaskColumn[Index].ColumnID,
                                    ColumnDataType, maxcol, DataRecord);
        RETURN (
                ( DataRecord.CardinalValue = IsRealValue )
                    OR
                ( DataRecord.CardinalValue = IsIntValue )
                    OR
                ( DataRecord.CardinalValue = IsCardValue )
                    OR
                ( DataRecord.CardinalValue = IsBoolValue )
                    OR
                ( DataRecord.CardinalValue = IsCurrency )
               );
     END;
    END;
END IsNumber;
*)



(****************************************************************************
    GetTaskColumnHeadingAndData    -
        Get the heading and data for given task.
****************************************************************************)
PROCEDURE PrintColumnHeadingAndData(
                              DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                    Index1, Index2 : CARDINAL
(*
                                 LeftMax, RightMax : CARDINAL
*)
                                   );
VAR
    AddNSpaces              :   CARDINAL;
    HeaderLength            :   CARDINAL;
    i                       :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    SetLengthOf( Line, 0 );
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
      WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO

        IF ( LengthOf(TaskColumn[Index1].ColumnName) <> 0 ) THEN
            GetTaskColumnHeading( DetailRptSettingsPtr, Index1, Line);
(*
            Procustes(Line, LeftMax);
*)
            PrintAText( DetailRptSettingsPtr, Line, Normal );
            HeaderLength := LengthOf( Line );
            IF ( LengthOf(TaskColumn[Index2].ColumnName) <> 0 ) THEN
                TaskColumn[Index1].ColumnWidth :=
                                  ( PrintPageWidth DIV 2 ) - HeaderLength - 1;
            ELSE
                TaskColumn[Index1].ColumnWidth :=
                                            PrintPageWidth - HeaderLength - 1;
            END;

            GetTaskData( DetailRptSettingsPtr, Index1, Line);

(*
            IF ( IsNumber(DetailRptSettingsPtr, Index1) ) THEN
                i := ( PrintPageWidth DIV 2 ) - HeaderLength - 1;
                TrimFront(Line);
                TrimRear(Line);
                Procustes(Line, MaxNumberLength);
                RJust(Line);
                Procustes(Line, i);
            END;
*)
            PrintAText( DetailRptSettingsPtr, Line, PrintAttribute);
            AddNSpaces := 1;
        ELSE
            AddNSpaces := PrintPageWidth DIV 2;
        END;

        IF ( LengthOf(TaskColumn[Index2].ColumnName) <> 0 ) THEN
            Fill( Line, ' ', AddNSpaces );
            PrintAText( DetailRptSettingsPtr, Line, Normal);
            GetTaskColumnHeading( DetailRptSettingsPtr, Index2, Line);
(*
            Procustes(Line, RightMax);
*)
            PrintAText( DetailRptSettingsPtr, Line, Normal );
            TaskColumn[Index2].ColumnWidth :=
                               ( PrintPageWidth DIV 2 ) - LengthOf(Line) - 1;
            GetTaskData( DetailRptSettingsPtr, Index2, Line);
            HeaderLength := LengthOf( Line );
(*
            IF ( IsNumber(DetailRptSettingsPtr, Index1) ) THEN
                i := ( PrintPageWidth DIV 2 ) - HeaderLength - 1;
                TrimFront(Line);
                TrimRear(Line);
                Procustes(Line, MaxNumberLength);
                RJust(Line);
                Procustes(Line, i);
            END;
*)
            PrintAText( DetailRptSettingsPtr, Line, PrintAttribute );
        END;
        PrintBlankLine( DetailRptSettingsPtr );
      END;
     END;
    END;
END PrintColumnHeadingAndData;




(*
(****************************************************************************
    GetTaskColumnHeadingLength    -
        Get the heading length for given task.
****************************************************************************)
PROCEDURE GetTaskColumnHeadingLength(
                              DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                             Index : CARDINAL
                                    ) : CARDINAL;
VAR
    DataRecord              :   AColumnDataRecord;
    Length                  :   CARDINAL;
BEGIN
    Length := 0;
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
        IF ( TaskColumn[Index].ColumnID <> BlanksColumn ) THEN

            GetTaskColumnName(  TaskColumn[Index].ColumnID,
                                DataRecord.StringValue ); (* 10-Jun-91 PFG *)
            Length := LengthOf( DataRecord.StringValue );

        END;
     END;
    END;
    RETURN (Length + 2); (* 1 for ':', 1 for space *)
END GetTaskColumnHeadingLength;
*)



(****************************************************************************
    PrintTaskData.
        Print out task data.
****************************************************************************)
PROCEDURE PrintTaskData( DetailRptSettingsPtr : ADetailReportSettingsPtr );
VAR
    i, i2, i3               :   CARDINAL;
    Length                  :   CARDINAL;
    LeftMax, RightMax       :   CARDINAL;
    NBlankLines             :   CARDINAL;
BEGIN
    NBlankLines := 0;
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
      WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO
        IF ( NOT AtTopOfPage ) THEN
            PrintBlankLine( DetailRptSettingsPtr );
        END;
        i2 := NTASKCOLUMNSROW;
(*
        LeftMax := 0;
        RightMax := 0;
        FOR i := 0 TO NTASKCOLUMNSROW - 1 DO
            IF ( LengthOf(TaskColumn[i].ColumnName) <> 0 ) THEN
                Length := GetTaskColumnHeadingLength(DetailRptSettingsPtr, i);
                IF ( LeftMax < Length ) THEN LeftMax := Length; END;
            END;
            IF ( LengthOf(TaskColumn[i2].ColumnName) <> 0 ) THEN
                Length := GetTaskColumnHeadingLength(DetailRptSettingsPtr, i2);
                IF ( RightMax < Length ) THEN RightMax := Length; END;
            END;
            INC(i2);
        END;
*)
        i2 := NTASKCOLUMNSROW;
        FOR i := 0 TO NTASKCOLUMNSROW - 1 DO
            IF ( ( LengthOf(TaskColumn[i].ColumnName) <> 0 )
                OR
                 ( LengthOf(TaskColumn[i2].ColumnName) <> 0 ) ) THEN
                FOR i3 := 1 TO NBlankLines DO
                    PrintBlankLine( DetailRptSettingsPtr );
                END;
                NBlankLines := 0;
(*
                PrintColumnHeadingAndData(DetailRptSettingsPtr, i, i2, LeftMax, RightMax);
*)
                PrintColumnHeadingAndData(DetailRptSettingsPtr, i, i2);
            ELSE
                NBlankLines := NBlankLines + 1;
            END;
            INC(i2);
        END;
      END;
     END;
    END;
END PrintTaskData;




PROCEDURE PrintTaskNotes( DetailRptSettingsPtr : ADetailReportSettingsPtr );
CONST
    MaxNNoteLines           =   10000;    (* Can be any large number *)
VAR
    i, i2                   :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    NoteExist               :   BOOLEAN;
BEGIN
    WITH DetailRptSettingsPtr^ DO
     WITH DetailRptSettingsPtr^.FormInputsPtr^ DO
      WITH DetailRptSettingsPtr^.FormPrintsPtr^ DO

        IF ( NOT FormInputsPtr^.IncludeNote ) THEN RETURN; END;

        IF ( FormInputsPtr^.SuppressBlankField ) THEN
            NoteExist := FALSE;
            i := 0;
            WHILE ( (NOT NoteExist) AND LineExists(TaskPointer^.notes, i) ) DO
                CopyLine( TaskPointer^.notes, i, Line);
                TrimFront( Line );
                NoteExist := ( LengthOf(Line) <> 0 );
                INC( i );
            END;

            IF ( NOT NoteExist )  THEN
                RETURN
            END;
        END;

        IF ( NOT FormPrintsPtr^.AtTopOfPage ) THEN
            PrintBlankLine( DetailRptSettingsPtr );
        END;
        IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 2 ) ) THEN
            MovePrintHeadToPageEnd( DetailRptSettingsPtr );
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;
        GetMessage(ModuleNumber + 54, Line); (* Notes *)
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        i := LengthOf(Line);
        Fill(Line, '-', i);
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        IF (FormInputsPtr^.NNoteLines = 0) THEN
            i2 := MaxNNoteLines;
        ELSE
            i2 := FormInputsPtr^.NNoteLines;
        END;

        i := 0;
        WHILE ( ( i < i2 ) AND LineExists( TaskPointer^.notes, i ) ) DO
            CopyLine( TaskPointer^.notes, i, Line);
            PrintALine( DetailRptSettingsPtr, Line, PrintAttribute );
            INC( i );
        END;

      END;
     END;
    END;
END PrintTaskNotes;


    (* This set of procedures added 6/21/90 by AJL to display assignment
       details.

       The format and, to a large extent, the contents of the lines are
       controlled by template strings from the phrases file.  These 
       determine the order of the fields which are displayed and their
       decorations.  

     *)


TYPE
    AnAssignmentContext = RECORD
                              StartDate, EndDate   : ADate;
                              DetailReportSettings : ADetailReportSettingsPtr;
                              FullDetails    : BOOLEAN;
                              IncludeCosts   : BOOLEAN;
                              PrintedHeading : BOOLEAN;
                          END;




PROCEDURE DescribeResourceAss( VAR Assignment  : AnAssignmentRecord;
                               VAR Line        : ARRAY OF CHAR;
                                   StartDate,
                                   EndDate     : ADate;
                                   IncludeCosts: BOOLEAN );
CONST
    CurrencySize        = 16;  (* $234,678,012.45 *)
    UnitSize            = 10;
    PeopleSize          = 6;
    PercentSize         = 3;
    DurationSize        = 15;
    NAME  = 0;
    CONFL = 1;
    RATE  = 2;
    QUANT = 3;
    SQUANT= 4;
    BUCKS = 5;
    SBUCKS= 6;
VAR
    CostStyleIndex,
    CostIndex   : CARDINAL;
    P, i        : CARDINAL;
    SpentCost,
    TotalCost,
    R           : REAL;
    LocalUnits  : ADurationUnit;
    s1          : ARRAY [0..9]  OF CHAR;
    Fragment    : ARRAY [0..69] OF CHAR;
    Portions     : APortionArray;


BEGIN

    WITH Assignment DO

        (* Name *)

        Copy( Resource^.LongName, Line );
        TrimRear(Line);
        IF (LengthOf(Line)=0) THEN
            Copy( Resource^.Name, Line );
        END;
        LJust(Line);
        Copy(Line,Portions[NAME]);


        (* Conflict? *)

        IF (Overloaded IN Attributes) THEN
            GetMessage(ModuleNumber+7,Line);  (* "Overbooked" *)
        ELSE
            SetLengthOf(Line,0);
        END;
        Copy(Line,Portions[CONFL]);



        (* $ value *)

        IF (IncludeCosts) THEN
            CostIndex := 1;
            TotalCost := AssignmentDollars( Assignment,
                                StartDate, EndDate,
                                AnAssignmentCostTypeSet{
                                IncludeSpent,
                                IncludeToGo,
                                IncludeExtras,      (* Include extras only once. *)
                                IncludeOvertime} );
    
            FormatAsCurrency(   TotalCost,
                                DefaultCurrencyFormat,
                                Line,
                                CurrencySize,
                                TRUE,                (* Right justify? *)
                                TRUE,                (* Show customary fraction? *)
                                TRUE );              (* Include the currency symbol? *)
            LJust(Line);
            TrimRear(Line);
            Copy(Line,Portions[BUCKS]);


            SpentCost := AssignmentDollars( Assignment,
                                StartDate, EndDate,
                                AnAssignmentCostTypeSet{
                                IncludeSpent,
                                IncludeOvertime} );
    
            FormatAsCurrency(   SpentCost,
                                DefaultCurrencyFormat,
                                Line,
                                CurrencySize,
                                TRUE,                (* Right justify? *)
                                TRUE,                (* Show customary fraction? *)
                                TRUE );              (* Include the currency symbol? *)
            LJust(Line);
            TrimRear(Line);
            Copy(Line,Portions[SBUCKS]);
        ELSE
            CostIndex := 0;
        END;

        CostStyleIndex := ORD(Resource^.CostStyle);

        (* Resource/VarCost specifics: *)

        IF (Resource^.CostStyle = CAmountRateTime) THEN


            P := ORD(PercentageEach);
            IF (P <> 0) THEN
                FormatAsAmount( FLOAT(MaxRatePercent)/FLOAT(P),  (* 03-Mar-92 *)
                                DefaultAmountFormat,
                                Line, HIGH(Line), 0, 4, FALSE );
            ELSE
                SetString( Line, "0" );
            END;
            Procustes( Line, PeopleSize );
            RJust(     Line );
            ConcatS( Line, " @ " );

            CtoS( P,   Fragment );
            Procustes( Fragment, PercentSize );
            RJust(     Fragment );
            ConcatLS(Line,Fragment);
            Copy(Line,Portions[RATE]);


            LocalUnits := ActualTimeUnits;
            LongDurationToString( (ActualQuantity + YetToGoQuantity),
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Line, i );
            TrimRear( Line );
            Copy(Line,Portions[QUANT]);

            LocalUnits := ActualTimeUnits;
            LongDurationToString( ActualQuantity,
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Line, i );
            TrimRear( Line );
            Copy(Line,Portions[SQUANT]);


        (* Unit Cost specifics:  *)

        ELSIF (Resource^.CostStyle = CAmountRate) THEN

            R := (ActualQuantity + YetToGoQuantity);
            FormatAsAmount( R,
                            DefaultAmountFormat,
                            Line,
                            UnitSize,
                            0,          (* Min Decimals   *)
                            1,          (* Max Decimals   *)
                            FALSE );    (* Right Justify? *)
            TrimRear( Line );
            ConcatS(Line," ");
            ConcatLS( Line, Resource^.UnitOfMeasure );
            TrimRear( Line );
            Copy(Line,Portions[QUANT]);

            FormatAsAmount( ActualQuantity,
                            DefaultAmountFormat,
                            Line,
                            UnitSize,
                            0,          (* Min Decimals   *)
                            1,          (* Max Decimals   *)
                            FALSE );    (* Right Justify? *)
            TrimRear( Line );
            ConcatS(Line," ");
            ConcatLS( Line, Resource^.UnitOfMeasure );
            TrimRear( Line );
            Copy(Line,Portions[SQUANT]);
        ELSE
            (* Fixed Cost *) 


        END;

            (* Each of the three cost styles has two templates in the 
               phrases file, one without cost information, on with.
               Get the correct template. *)

        GetMessage( ModuleNumber + 24
                    + (CostIndex*3) + CostStyleIndex, Line );

            (* Substitute the data items into the template string. *)

        MakeSubstitutions( Line, HIGH(Line), SubstitutePortions,
                           ADR(Portions) );

    END;

END DescribeResourceAss;



PROCEDURE DescribeVaryingAssignment( VAR VaryingAssgnList : AVaryingAssgnList;
                                     VAR DetailReportSettings : ADetailReportSettingsPtr;
                                         EndOfSpentDate   : ADate );
CONST
    STARTDATE  = 0;
    ENDDATE    = 1;
    RATE       = 2;
    STHRU      = 3;
    RateSize            = 15;
    
VAR
    i,N         : CARDINAL;              
    StartDate,
    EndDate     : ADate;
    Rate        : REAL;   
    Line        : ARRAY [0..MaxWidth] OF CHAR;
    Portions    : APortionArray;
BEGIN
    IF (VaryingAssgnList <> AVaryingAssgnList(NIL)) THEN
        i := 1;
        WHILE GetVaryingAssgnListEntry(VaryingAssgnList, i, StartDate,EndDate,Rate) DO
            IF (Rate <> 0.0) THEN
                TimeUtoS(StartDate,Portions[STARTDATE]);
                FormatAsEndDateStyle(EndDate,Portions[ENDDATE]);
                FormatAsAmount( Rate,
                                DefaultAmountFormat,
                                Portions[RATE],
                                RateSize,
                                0,          (* Min Decimals   *)
                                4,          (* Max Decimals   *)
                                FALSE );    (* Right Justify? *)
                (*
                CtoS(Rate,Portions[RATE]);
                *)
                IF (EndOfSpentDate >= EndDate) THEN
                    GetMessage(ModuleNumber+31,Portions[STHRU]);  (* "Spent" *)
                ELSIF (StartDate < EndOfSpentDate) THEN
                    GetMessage(ModuleNumber+32,Portions[STHRU]);  (* "Spent thru " *)
                    FormatAsEndDateStyle(EndOfSpentDate,Line);
                    ConcatLS(Portions[STHRU],Line);
                ELSE
                    SetLengthOf(Portions[STHRU],0);
                END;

                    (* Substitute the data items into the template string. *)

                GetMessage( ModuleNumber + 30, Line );
                MakeSubstitutions( Line, HIGH(Line), SubstitutePortions,
                                   ADR(Portions) );

                PrintALine( DetailReportSettings, Line, Normal);
            END;
            INC(i);
        END;
    END;
END DescribeVaryingAssignment;




PROCEDURE DescribeAssignment( VAR Assignment : AnAssignmentRecord;
                                  Context    : ADDRESS ) : BOOLEAN;
VAR
    LContext : POINTER TO AnAssignmentContext;
    FilterSet : ATaskFilterSet;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    S                       :   ARRAY [0..25] OF CHAR;
BEGIN
    LContext := Context;

        (* See if the assignment passes any select filter which is 
           in force.  If not, don't display the assignment. *)

    FilterSet := AssignmentFiltersPassed(
         LContext^.DetailReportSettings^.TaskTreeNode,
         Assignment);

    IF (NOT (Selected IN FilterSet)) THEN
        RETURN TRUE;  (* Return, but allow the caller to keep going. *)
    END;

        (* If we are not supposed to display costs, omit them. *)

    IF (NOT LContext^.IncludeCosts) THEN
        IF (Assignment.Resource^.Type = AccountingOnly) AND
           (Assignment.Resource^.CostStyle = CAmount) THEN (* Fixed cost. *)
            RETURN TRUE;  (* Return, but allow the caller to keep going. *)
        END;
    END;

        (* If the section header for the resource assignments hasn't yet
           been printed, print it now. *)

    WITH LContext^ DO
        IF (NOT PrintedHeading ) THEN
            PrintAssignmentHeading( DetailReportSettings, IncludeCosts );
            PrintedHeading := TRUE;
        END;
    END;


    WITH LContext^ DO
        DescribeResourceAss(Assignment,Line, StartDate,
                                             EndDate,
                                             IncludeCosts);
        PrintALine( DetailReportSettings, Line, Normal);
    END;


    IF (LContext^.FullDetails) AND 
       (Assignment.Resource^.Type <> AccountingOnly) THEN
        (*
        SetString(Line,"End of spent date = ");
        FormatAsEndDateStyle(Assignment.EndOfSpentDate,S);
        ConcatLS(Line,S);
        PrintALine( LContext^.DetailReportSettings, Line, Normal);
        *)
        DescribeVaryingAssignment(Assignment.VaryingAssignment,
                                  LContext^.DetailReportSettings,
                                  Assignment.EndOfSpentDate);
    END;

    RETURN TRUE;                (* Keep going. *)
END DescribeAssignment;



PROCEDURE PrintAssignmentHeading( DetailRptSettingsPtr : ADetailReportSettingsPtr;
                                  IncludeCosts : BOOLEAN );
VAR
    i    : CARDINAL;               
    Line :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN

    IF ( NOT DetailRptSettingsPtr^.FormPrintsPtr^.AtTopOfPage ) THEN
        PrintBlankLine( DetailRptSettingsPtr );
    END;

    IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 2 ) ) THEN
        MovePrintHeadToPageEnd( DetailRptSettingsPtr );
        PrintDetailReportFooter( DetailRptSettingsPtr );
    END;

    i := ORD(IncludeCosts) * 2;
    GetMessage( ModuleNumber + 20 + i, Line);
    PrintALine( DetailRptSettingsPtr, Line, Normal);
    GetMessage( ModuleNumber + 21 + i, Line);
    PrintALine( DetailRptSettingsPtr, Line, Normal);

END PrintAssignmentHeading;



PROCEDURE PrintResourceAssignments( DetailRptSettingsPtr : ADetailReportSettingsPtr );
VAR
    LContext                :   AnAssignmentContext;
BEGIN
    WITH DetailRptSettingsPtr^ DO
        WITH FormInputsPtr^ DO
            WITH FormPrintsPtr^ DO

                IF (AssignmentFormat = AFNone) THEN
                    RETURN
                END;
               
                IF (SuppressBlankField ) THEN
                    LContext.PrintedHeading       := FALSE;  (* Not yet printed. *)
                ELSE
                    PrintAssignmentHeading( DetailRptSettingsPtr, IncludeCosts );
                    LContext.PrintedHeading       := TRUE;
                END;
               
            END;

            IF (TaskPointer^.Plan.Assignments  <> AnExtHandle(NIL)) THEN
                LContext.StartDate   := TaskPointer^.Plan.Dates.EarlyStart;
                LContext.EndDate     := TaskPointer^.Plan.Dates.EarlyEnd;
                    (* Display excruciating details? *)
                LContext.FullDetails :=
                                  (AssignmentFormat = AFDetail);
                LContext.IncludeCosts := FormInputsPtr^.IncludeCosts;
                LContext.DetailReportSettings := DetailRptSettingsPtr;
                ForEachAssignment(TaskPointer^.Plan.Assignments,
                                  DescribeAssignment, ADR(LContext) ); 
            END;
        END;
    END;
END PrintResourceAssignments;





PROCEDURE PrintTaskName( DetailRptSettingsPtr : ADetailReportSettingsPtr );
VAR
    i                       :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH DetailRptSettingsPtr^ DO
        IF ( NOT FormPrintsPtr^.AtTopOfPage ) THEN
            PrintBlankLine( DetailRptSettingsPtr );
        END;
        IF ( NOT NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 2 ) ) THEN
            MovePrintHeadToPageEnd( DetailRptSettingsPtr );
            PrintDetailReportFooter( DetailRptSettingsPtr );
        END;
        GetMessage(ModuleNumber + 53, Line); (* Task Name *)
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        i := LengthOf(Line);
        Fill(Line, '-', i);
        PrintALine( DetailRptSettingsPtr, Line, Normal);
        PrintFormatName( DetailRptSettingsPtr, TaskTreeNode, TaskPointer,
                                                FormInputsPtr^.TaskNameFmt );
    END;
END PrintTaskName;




PROCEDURE PrintOneTaskDetails( 
                              VAR TaskNode : ATreeNode; 
                              DetailRptSettingsPtr : ADetailReportSettingsPtr
                             );
VAR
    TaskFilter              :   ATaskFilterSet;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    IF ( Stopped ) THEN RETURN; END;
    WITH DetailRptSettingsPtr^ DO
        WITH FormPrintsPtr^ DO

            TaskTreeNode := TaskNode;

            TaskFilter := TaskFiltersPassed( TaskTreeNode );
            IF ( TaskFilter * ATaskFilterSet{Highlight3..Highlight5} =
                                                       ATaskFilterSet{} ) THEN
                PrintAttribute := Normal;
            ELSE
                PrintAttribute := Bold;
            END;

            TaskPointer :=
                      TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);

            PrintTaskName( DetailRptSettingsPtr );
            PrintTaskNotes( DetailRptSettingsPtr );
            PrintTaskData( DetailRptSettingsPtr );
            PrintTaskPredecessors( DetailRptSettingsPtr );
            PrintTaskSuccessors( DetailRptSettingsPtr );

            (* Print a detailed list of all the varying assignments to the 
               task. *)
            PrintResourceAssignments( DetailRptSettingsPtr );

            IF ( 
                 ( NOT DetailRptSettingsPtr^.FormInputsPtr^.OneTaskPerPage ) 
                AND
                 ( NPrintRowsOnCurrentPage( DetailRptSettingsPtr, 3 ) )
               ) THEN
                PrintBlankLine( DetailRptSettingsPtr );
                Fill( Line, '-', PrintPageWidth );
                PrintALine( DetailRptSettingsPtr, Line, Normal );
                MovePrintHeadToPageEndIfNeeded( DetailRptSettingsPtr );
            ELSE
                MovePrintHeadToPageEnd( DetailRptSettingsPtr );
            END;


            TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
            TaskTreeNode := NIL;  (* Safety !!! *)
            TaskPointer := NIL;   (* Safety !!! *)
        END;
    END;
END PrintOneTaskDetails;




PROCEDURE PrintAllDetails( 
                          InputsPtr : ADetailReportInputValuesPtr;
                          PrintsPtr : ADetailReportPrintControlsPtr
                         );
VAR
    DetailRptSettings       :   ADetailReportSettings;
    Node                    :   ATreeNode;
BEGIN
    WITH DetailRptSettings DO
        FormInputsPtr := InputsPtr;
        FormPrintsPtr := PrintsPtr;
        AllowUnlimitedPageLength( NOT FormInputsPtr^.PagedReport );
    END;

    Node := TaskTree^.Methods^.GetFirstVisible(TaskTree);
    WHILE ( Node <> NIL ) DO
        PrintOneTaskDetails( Node, ADR(DetailRptSettings) );
        Node := Node^.Methods^.NextForDisplay(Node);
    END;

    IF ( NOT DetailRptSettings.FormPrintsPtr^.AtTopOfPage ) THEN
        MovePrintHeadToPageEnd( ADR(DetailRptSettings) );
        PrintDetailReportFooter( ADR(DetailRptSettings) );
    END
END PrintAllDetails;




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
BEGIN
    Copy(FormValue[FormValueIndex].CharValue^,
                                  ColumnInfoArr[ColumnInfoIndex].ColumnName);
    ColumnInfoArr[ColumnInfoIndex].ColumnID :=
                                        FormValue[FormValueIndex].CardValue;
    TrimFront(ColumnInfoArr[ColumnInfoIndex].ColumnName);
END SetColumnInfo;




PROCEDURE SetPrintControls( 
                           FormInputsPtr : ADetailReportInputValuesPtr;
                           FormPrintsPtr : ADetailReportPrintControlsPtr
                          );
BEGIN
    FormPrintsPtr^.PrintPageWidth := PageWidth();
    FormPrintsPtr^.ReportPageNumber := 0;
    FormPrintsPtr^.AtTopOfPage := TRUE;
    FormPrintsPtr^.PageHeaderOn := TRUE;
    FormPrintsPtr^.PageFooterOn := TRUE;
END SetPrintControls;




PROCEDURE StartDetailReport( InputsPtr : ADetailReportInputValuesPtr );
VAR
    PrintControls           :   ADetailReportPrintControls;
BEGIN
    IF (NOT StartReport()) THEN RETURN; END;
    SetPrintControls( InputsPtr, ADR(PrintControls) );
    PrintAllDetails(InputsPtr, ADR(PrintControls));
    EndReport();
END StartDetailReport;




(****************************************************************************
    SetDetailInputSettings   -
        Set up the DetailReporrtSettings based on the value in FormValueArray.
        FormValueArray contains the information inputed from user.
****************************************************************************)
PROCEDURE SetDetailInputSettings(
                                 VAR FormValue  : ARRAY OF AFieldValue;
                                      InputsPtr : ADetailReportInputValuesPtr
                                );
VAR
    i, i2                   :   CARDINAL;
BEGIN
    WITH InputsPtr^ DO

        TaskNameFmt := VAL(ATaskNameFormat, FormValue[TASKNAMESFMT].CardValue);
        IncludeNote := VAL(BOOLEAN ,FormValue[INCNOTE].CardValue);
        NNoteLines := FormValue[NNOTELINESINC].CardValue;
        AssignmentFormat    := VAL(AnAssignmentFormat,
                                        FormValue[INCASSIGN].CardValue);
        IncludeCosts        :=  VAL(BOOLEAN,
                                        FormValue[INCCOSTS].CardValue);
        IncludePredecessors := VAL(BOOLEAN,
                                        FormValue[INCPREDECESSORS].CardValue);
        IncludeSuccessors := VAL(BOOLEAN, FormValue[INCSUCCESSORS].CardValue);
        DependencyNameFmt := VAL(ATaskNameFormat,
                                 FormValue[DEPENDENCYNAMESFMT].CardValue + 1);
        SuppressBlankField := VAL(BOOLEAN,
                                          FormValue[INCLUDETITLES].CardValue);
        PagedReport := VAL(BOOLEAN, FormValue[PAGEDREPORT].CardValue);
        HeaderOn := VAL(AShowHeaderMethod, FormValue[HEADERON].CardValue);
        OneTaskPerPage := VAL(BOOLEAN, FormValue[TASKPERPAGE].CardValue);

        i2 := 0;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
            SetColumnInfo(TaskColumn, i2, FormValue, i);
            INC(i2);
        END;
    END;
END SetDetailInputSettings;




(* ***************  Form related stuffs start here ***************** *)

(****************************************************************************
    EnoughInputsAndAllInputsOk  -
        Make sure we have all the parameters we need.
****************************************************************************)
PROCEDURE EnoughInputsAndAllInputsOk(
                                     VAR FormValue  : ARRAY OF AFieldValue
                                    ) : BOOLEAN;
VAR
    i                       :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    GotTask                 :   BOOLEAN;
BEGIN

(*  If there is no page break  then header only for first page
    and not one task per page                                 *)

    IF ( FormValue[PAGEDREPORT].CardValue = 0 ) THEN
        FormValue[HEADERON].CardValue := 0;
        FormValue[TASKPERPAGE].CardValue := 0;
    END;
    RETURN TRUE;
END EnoughInputsAndAllInputsOk;




PROCEDURE PickTaskList(
                                Form : AForm;
                             FieldNo : AFieldNo;
                       VAR FormValue : ARRAY OF AFieldValue
                      ) : BOOLEAN;
CONST
    LeftTaskBoxLeft         =   0;
    LeftTaskBoxRight        =   29;
    LeftTaskBoxTop          =   3;
    RightTaskBoxLeft        =   50;
    RightTaskBoxRight       =   79;
    RightTaskBoxTop         =   3;
VAR
    TaskBoxLeft             :   CARDINAL;
    TaskBoxRight            :   CARDINAL;
    TaskBoxTop              :   CARDINAL;
    TaskBoxBottom           :   CARDINAL;
    UseLeftTaskBox          :   BOOLEAN;
    Column                  :   CARDINAL;
    Width                   :   CARDINAL;
    LeftTaskBoxBottom       :   CARDINAL;
    RightTaskBoxBottom      :   CARDINAL;
    i                       :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;

BEGIN

    LeftTaskBoxBottom       :=   maxrow-8;
    RightTaskBoxBottom      :=   maxrow-8;
(* Use right box for left column and left box for right column *)

    UseLeftTaskBox := NOT ( FieldNo < ( FIRSTTASKFLD + NTASKCOLUMNSROW ) );
    IF ( UseLeftTaskBox ) THEN
        TaskBoxLeft := LeftTaskBoxLeft;
        TaskBoxRight := LeftTaskBoxRight;
        TaskBoxTop := LeftTaskBoxTop;
        TaskBoxBottom := LeftTaskBoxBottom ;
    ELSE
        TaskBoxLeft := RightTaskBoxLeft;
        TaskBoxRight := RightTaskBoxRight;
        TaskBoxTop := RightTaskBoxTop;
        TaskBoxBottom := RightTaskBoxBottom ;
    END;
    Column := FormValue[FieldNo].CardValue;
    IF (NOT PickTaskColumn(TaskBoxLeft, TaskBoxTop,
                               TaskBoxRight, TaskBoxBottom, Column, Line)) THEN
        RETURN FALSE
    END;
    FormValue[FieldNo].CardValue := Column;

    RETURN TRUE;
END PickTaskList;




PROCEDURE CheckTLDRForm(
                                 Form : AForm;
                              FieldNo : AFieldNo;
                        VAR FormValue : ARRAY OF AFieldValue;
                          CheckReason : ACheckReason;
                             VAR Code : CARDINAL
                       ) : BOOLEAN;
VAR
    CodeIn                  :   CARDINAL;
    i                       :   CARDINAL;
    TmpColumn               :   CARDINAL;
    TmpString               :   AStringValue;
    TempField               :   AFieldValue;
    AssignmentFormat        :   AnAssignmentFormat;
    NoDependencyName        :   BOOLEAN;
    NoAssignments           :   BOOLEAN;
    IncludeNote             :   BOOLEAN;
    PageBreakOff            :   BOOLEAN;

BEGIN

    CodeIn := Code;
    Code := 0;

    CASE CheckReason OF
          CheckFormExit :     ;
            RETURN(EnoughInputsAndAllInputsOk(FormValue));
        | CheckFieldEntry   :    ;
        | CheckFormEntry,
          CheckFieldChange:
            CASE FieldNo OF
                | INCNOTE:
                    IncludeNote := (FormValue[FieldNo].CardValue = 0);
                    SetFieldHidden(Form, FieldNo + 1, FormValue, IncludeNote);
                    SetFieldProtection(Form, FieldNo + 1, FormValue,
                                                                 IncludeNote);
                | PAGEDREPORT:
                  (* if Page break off *)
                    PageBreakOff := ( FormValue[FieldNo].CardValue = 0 );
                    IF ( PageBreakOff ) THEN
                        FormValue[HEADERON].CardValue := 0;
                        FormValue[TASKPERPAGE].CardValue := 0;
                    END;
                    SetFieldProtection(Form, HEADERON, FormValue,
                                                                PageBreakOff);
                    SetFieldProtection(Form, TASKPERPAGE, FormValue,
                                                                PageBreakOff);
                | INCASSIGN:
                    AssignmentFormat := VAL(AnAssignmentFormat,
                                        FormValue[INCASSIGN].CardValue);
                    NoAssignments := (AssignmentFormat = AFNone);
                    SetFieldProtection(Form, INCCOSTS, FormValue, NoAssignments);
                    SetFieldHidden(Form, INCCOSTS, FormValue, NoAssignments);

                | INCPREDECESSORS, INCSUCCESSORS:
                    NoDependencyName :=
                                ( FormValue[INCPREDECESSORS].CardValue = 0 )
                               AND
                                ( FormValue[INCSUCCESSORS].CardValue = 0 );
                    SetFieldProtection(Form, DEPENDENCYNAMESFMT, FormValue,
                                                            NoDependencyName);
                    SetFieldHidden(Form, DEPENDENCYNAMESFMT, FormValue,
                                                            NoDependencyName);
            ELSE
            END;
            (* SetFormChange(Form);     removed 7/29/91 EGK *)
        | CheckFieldExit    :
            IF ( (FieldNo < FIRSTTASKFLD) OR (FieldNo > LASTTASKFLD) ) THEN
                RETURN TRUE;
            END;
            Copy(FormValue[FieldNo].CharValue^, TmpString);
            TrimFront(TmpString);
            IF ( LengthOf(TmpString)  <> 0 ) THEN     (* 24-May-89 LAA *)
                IF ( SearchForTaskColumn(TmpString, TmpColumn) ) THEN
                    FormValue[FieldNo].CardValue := TmpColumn;
                ELSE
                    Burp;
                    RETURN FALSE;
                END;
            ELSE
                FormValue[FieldNo].CardValue := 0;             (* 24-Sep-91 *)
            END;
        | CheckFieldKey  :
            IF ( (FieldNo < FIRSTTASKFLD) OR (FieldNo > LASTTASKFLD) ) THEN
                Code := 04000H + CodeIn;
                RETURN TRUE;
            END;

            IF ( ( CodeIn = MoveUpKey ) AND ( FieldNo = FIRSTTASKFLD )
                 OR
                 ( CodeIn = MoveDownKey ) AND ( FieldNo = LASTTASKFLD ) ) THEN
                Burp;
                RETURN FALSE;
            END;

            IF ( CodeIn = EditKey ) THEN
                HighlightField( Form, FormValue, FieldNo, CursorResting);
                IF (NOT SearchForTaskColumn (FormValue[FieldNo].CharValue^,   (* 24-Sep-91 *)
                                             FormValue[FieldNo].CardValue)) THEN
                    FormValue[FieldNo].CardValue := 0;
                END;
                IF (PickTaskList(Form, FieldNo, FormValue)) THEN
                    SetFormChange(Form);
                END;

                (* In case column names were edited, update all column
                    names on form.  Need to do this even if PickTaskColumn
                    returns FALSE, since the user may have changed some 
                    column other than the highlighted one.  *)

                FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
                    IF FormValue[i].CardValue <> 0 THEN
                        GetTaskColumnName(  FormValue[i].CardValue,
                                            FormValue[i].CharValue^);
                    ELSE
                        Fill(FormValue[i].CharValue^, " ", 24);
                    END;
                    ShowValue(Form, i, FormValue);
                END;

                HighlightField( Form, FormValue, FieldNo, CursorOff);
                RETURN TRUE;
            END;

            IF ( CodeIn = MoveUpKey ) THEN
                TempField := FormValue[FieldNo];
                FormValue[FieldNo] := FormValue[FieldNo - 1];
                FormValue[FieldNo - 1] := TempField;
                ShowValue(Form, FieldNo - 1, FormValue);
                ShowValue(Form, FieldNo, FormValue);
                Code := 08000H + FieldNo - 1;
                SetFormChange(Form);
                RETURN TRUE;
            END;

            IF ( CodeIn = MoveDownKey ) THEN
                TempField := FormValue[FieldNo];
                FormValue[FieldNo] := FormValue[FieldNo + 1];
                FormValue[FieldNo + 1] := TempField;
                ShowValue(Form, FieldNo, FormValue);
                ShowValue(Form, FieldNo + 1, FormValue);
                Code := 08000H + FieldNo + 1;
                SetFormChange(Form);
                RETURN TRUE;
            END;

            RETURN FALSE;

     END;

     RETURN TRUE;

END CheckTLDRForm;




(****************************************************************************
    TerminateUsingFormValueArray -
        It deallocates storage for all buffers that are allocated in
        StartUsingFormValueArray and set all pointers in FormValue to NIL.
****************************************************************************)
PROCEDURE TerminateUsingFormValueArray(VAR FormValue : ARRAY OF AFieldValue);
VAR
    i                       :   CARDINAL;
BEGIN

    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
        DISPOSE(FormValue[i].CharValue);
        FormValue[i].CharValue := NIL;      (* Safely !!! *)
    END;
END TerminateUsingFormValueArray;




(****************************************************************************
    InitColumnField -
        Initialize the pointers for Column name info in FormValueArray.
    All variable will be set based on the value in FormInputs.
****************************************************************************)
PROCEDURE InitColumnField(
                          VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                            ColumnInfoIndex : CARDINAL;
                          VAR     FormValue : ARRAY OF AFieldValue;
                             FormValueIndex : CARDINAL
                         );
BEGIN
    Copy(ColumnInfoArr[ColumnInfoIndex].ColumnName,
                                        FormValue[FormValueIndex].CharValue^);
    FormValue[FormValueIndex].CardValue :=
                                      ColumnInfoArr[ColumnInfoIndex].ColumnID;
END InitColumnField;




(****************************************************************************
    AllocateFormValue -
        Allocate buffers for form value array.
****************************************************************************)
PROCEDURE AllocateFormValue( VAR FormValue : ARRAY OF AFieldValue );
VAR
    i                       :   CARDINAL;
BEGIN
    FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
        NEW(FormValue[i].CharValue);
    END;
END AllocateFormValue;




(****************************************************************************
    StartUsingFormValueArray -
    Allocate the buffers for form value array.  All variable will be set
    based on the value in FormInputs.
****************************************************************************)
PROCEDURE StartUsingFormValueArray(
                                   VAR FormValue : ARRAY OF AFieldValue;
                                       InputsPtr : ADetailReportInputValuesPtr
                                  );
VAR
    i, i2                   :   CARDINAL;
BEGIN
    AllocateFormValue( FormValue );

    WITH InputsPtr^ DO
        FormValue[TASKNAMESFMT].CardValue := ORD(TaskNameFmt);
        FormValue[INCNOTE].CardValue := ORD(IncludeNote) ;
        FormValue[NNOTELINESINC].CardValue := NNoteLines;
        FormValue[INCASSIGN].CardValue := ORD(AssignmentFormat) ;
        FormValue[INCCOSTS].CardValue := ORD(IncludeCosts) ;
        FormValue[INCPREDECESSORS].CardValue := ORD(IncludePredecessors) ;
        FormValue[INCSUCCESSORS].CardValue := ORD(IncludeSuccessors) ;
        FormValue[DEPENDENCYNAMESFMT].CardValue := ORD(DependencyNameFmt) - 1;
        FormValue[INCLUDETITLES].CardValue := ORD(SuppressBlankField) ;
        FormValue[PAGEDREPORT].CardValue := ORD(PagedReport) ;
        FormValue[HEADERON].CardValue := ORD(HeaderOn) ;
        FormValue[TASKPERPAGE].CardValue := ORD(OneTaskPerPage) ;

        i2 := 0;
        FOR i := FIRSTTASKFLD TO LASTTASKFLD DO
            InitColumnField(TaskColumn, i2, FormValue, i);
            INC(i2);
        END;
    END;

END StartUsingFormValueArray;

(* ***************  Form related stuffs end here ***************** *)




(****************************************************************************
    InitColumnInfo -
        No old settings for ADetailReportInputValues.
        Initialize all Column Info in ADetailReportInputValues.
****************************************************************************)
PROCEDURE InitColumnInfo(
                         VAR ColumnInfoArr : ARRAY OF AColumnInfo;
                           ColumnInfoIndex : CARDINAL
                        );
BEGIN
    SetLengthOf( ColumnInfoArr[ColumnInfoIndex].ColumnName, 0 );
    ColumnInfoArr[ColumnInfoIndex].ColumnWidth := DefaultColWidth;
    ColumnInfoArr[ColumnInfoIndex].ColumnID := 0;
END InitColumnInfo;



VAR Handle : AnExtHandle;




(****************************************************************************
    StartUsingDetailSettings  -
        Retreive the old settings for ADetailReportInputValues.
        If we can not retrieve the old settings then allocate storage
        for the settings and initialize all variable in the settings.
****************************************************************************)
PROCEDURE StartUsingDetailSettings(
                                   VAR Inputs : ADetailReportInputValues
                                  );
VAR
    A                       :   ADDRESS;
    i                       :   CARDINAL;
    ItemName                :   ARRAY [0..21] OF CHAR;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;

BEGIN

    GetMessage(ModuleNumber + 49, ItemName); (* TLDR *)
    Class := 1;
    IF ( LocateHeldItem(ItemName, Class, Category, A, Size) AND
       (Size = TSIZE(ADetailReportInputValues) ) ) AND
       (HoldInFlexStor IN Category) THEN    (* 23-Jan-91 RSC *)
        Handle := AnExtHandle(A);
        IF (GetExtSize(Handle) <> Size) THEN
            FatalError();
        END;
        Size   := GetExtData( Handle, ADR(Inputs) );

        (*  3-Jun-91 PFG  In case any of the column names have been 
            changed since the last time the report form was saved, 
            update them.  *)

        WITH Inputs DO
            FOR i := 0 TO LASTTASKINFO DO
                WITH TaskColumn[i] DO
                    IF (ColumnID <> 0) THEN
                        GetTaskColumnName(ColumnID, ColumnName ); (* 10-Jun-91 PFG *)
                    END;
                END;
            END;
        END;

        RETURN;
    END;

    WITH Inputs DO
        TaskNameFmt := FullOutline;
        IncludeNote := TRUE;
        NNoteLines := 1;
        AssignmentFormat    :=    AFNone;
        IncludeCosts        :=    FALSE;
        IncludePredecessors := TRUE;
        IncludeSuccessors := TRUE;
        DependencyNameFmt := AbbreviatedOutLine;
        SuppressBlankField := TRUE;
        PagedReport := TRUE;
        HeaderOn := EveryPage;
        OneTaskPerPage:= FALSE;
    END;

    FOR i := 0 TO LASTTASKINFO DO
        InitColumnInfo(Inputs.TaskColumn, i);
    END;

    Size := TSIZE(ADetailReportInputValues);

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


END StartUsingDetailSettings;








PROCEDURE DoDetailReport();
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    FormValue               :   ARRAY [0..LastDetailFormField] OF AFieldValue;
    FormInputs              :   ADetailReportInputValues; 
    Code                    :   ACode;
    Copyright               :   ARRAY[0..50] OF CHAR;
    ok                      :   BOOLEAN;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        GetMessage(ModuleNumber + 50, Line);          (* "There are not tasks on which to report." *)
        Error(Line);
        RETURN;
    END;

    IF ( NOT CreateTaskColumnsTree() ) THEN RETURN; END;

    StartUsingDetailSettings(FormInputs);

    StartUsingFormValueArray(FormValue, ADR(FormInputs)); 
    Code := DoForm(0, 0, maxcol, GanttWEnd, TLDRFORMID, TRUE,
                                                    FormValue, CheckTLDRForm);

    IF (Code = ExitKey) THEN
        SetDetailInputSettings(FormValue, ADR(FormInputs)); 
        StartDetailReport(ADR(FormInputs)); 
    END;

    TerminateUsingFormValueArray(FormValue);
    DisposeTaskColumnsTree();

    ok := (Handle <> AnExtHandle(NIL)) AND
           SetExtData( Handle, ADR(FormInputs), 
                       TSIZE(ADetailReportInputValues) ); (* 23-Jan-91 RSC *) 

END DoDetailReport;

BEGIN
    DoDetailReport();
END TLDR.




