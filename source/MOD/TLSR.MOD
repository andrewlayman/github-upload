MODULE TLSR;     (*  TimeLine Status Report   *)
(*
        MODIFICATION History -

        06-APR-89 KKC First version
        01-May-89 KKC - Make assignment column width hidden when report
                        on each resource.
        03-May-89 KKC - Checking for employable if resource only.
        04-May-89 KKC - Check at least one date range is not empty.
        08-May-89 KKC - Update pagenumber even Page Footer is off.
        15-May-89 KKC - Regardless of its EndDateStyle, milestone will always
                        be printed as StartOfNextDay in each date range.
        19-May-89 KKC - Add One Task Per Page Option
        24-May-89 KKC - Check date range.
        26-May-89 KKC - Highlight field for picking list.
                      - Add 'A' or 'An' in front of each type name.
                      - Display picking lists in different position.
                      - Update column id if user used delete key to
                        delete part of the column name.
                      - beep if user presses F2 in fields that don't have
                        a picking list.
                      - Display error when column width greater than 255
        31-May-89 KKC - Trim all trailing blanks in column names before
                        testing for NULL field names.
        05-Jun-89 KKC - Remove all blank columns by shift all non blank
                        columns upward.
        07-Jun-89 KKC - For Status By Resource.  After calling GetFirstVisible,
                        check for matching assignments.
        08-Jun-89 KKC - Print out blank lines for report header after strip 1
                        if report header is suppressed.
        10-Jun-89 WKH - Added support for variable screen rows
        12-Jun-89 KKC - Since PageRepeat was splited into two modules, I
                        just redefined all the external variables from
                        pagerepeat.
                      - In SetStatusInputSettings, Call StoTimeU only for
                        not empty string.  For some reason, calling StoTimeU
                        with an empty string will cause an error message
                        displayed on the top of screen.
        16-Jun-89 KKC - If no data have been printed, do not print the page
                        number.
        27-Jun-89 KKC - Restrict user from entering zero in column width
                        for a non empty column name.
        04-Jul-89 KKC - Split TLSR into TLSR and TLSROPTN
        10-Aug-89 KKC - Add copyright message.
        11-Aug-89 KKC - Pass Pointer instead of address.
                      - Add three blank lines between procedures.
        06-Oct-89 KKC - Print Blank headers on begin of second strip.
        20-Oct-89 KKC - Disallow user from mixing baseline assignments and
                        current assignments.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        23-Jan-91 RSC   Moved holder item into FlexStor.
        20-Mar-91 AJL - Added more error checking.
                      - Moved the record definitions shared with TLSROPTN
                        to TLSRRec.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
        2-Jul-91  AJL - Added parameters to FilterNotes.
        18-Mar-91 LAA   In MarkTask, we were only marking the direct parent of
                        a marked task, resulting in omitted parentage in some
                        circumstances.  Frequently, the indirect parent WOULD
                        appear on the report because it had another, direct
                        child which was marked.  Created the MarkParents
                        procedure to mark ALL parents via recursion.  Thanks
                        to Patrick for finding this bug.
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 AStartStatus, ATaskFilter, ATaskFilterSet,
                                ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM AssFormat              IMPORT
    (* VAR   *) (* PROC *)      GetAssString, GetAssInfo;

FROM Assignments            IMPORT
    (* PROC  *)                 ForEachAssignment,
    (* TYPE  *)                 AnAssignmentRecord;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
    (* VAR   *) (* PROC *)      GetColumnString, GetColumnInfo;

FROM Dialog                 IMPORT
    (* PROC  *)                 Error, FatalError;

FROM Filter1                IMPORT
    (* PROC  *)                 TaskFiltersPassed, ResourceFiltersPassed;

FROM FlexStor               IMPORT
    (* TYPE  *)                 AnExtHandle,
    (* PROC *)                  GetExtData;

FROM Gantt                  IMPORT
    (* TYPE  *)                 AGanttLineType;

FROM Holder                 IMPORT
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, Copy, Fill,
                                Procustes, ConcatLS, SetLengthOf,
                                Search, TrimRear, TrimFront, SetString;

FROM MagicNum               IMPORT
    (* CONST *)                 BsLnBillable, RsrcName;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage;

FROM PageRepeat             IMPORT
    (* TYPE  *)                 APageRepeatSettings,
    (* PROC  *)                 IgnoreLeftMargin, PageBreaksEnable,
                                IsOneTaskOrResourcePerPage,
                                RepeatColumnHeadings, RepeatPageHeadings,
                                RepeatPageFootings, UnlimitedPageWidth;

FROM PrintCaptions          IMPORT
    (* PROC  *)                 FilterNotes, PageHead;

FROM PrintStatic            IMPORT
    (* TYPE  *)                 APrinterStyle,
    (* VAR   *)                 PrintCB;

FROM PrintSupport           IMPORT
    (* VAR   *)                 Stopped,
    (* PROC  *)                 AllowLeftMargin, PageWidth, PrintLine,
                                PrintText, EndReport, StartReport,
                                RowsLeft, AllowUnlimitedPageLength,
                                GetCurrentPrintRow, StartPage;

FROM RsrcFormat             IMPORT
    (* VAR   *) (* PROC *)      GetRsrcString;

FROM RsrcMod                IMPORT
    (* TYPE  *)                 AResourcePointer, AResourceType,
    (* VAR   *)                 ResourceTree;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE  *)                 ADDRESS, ADR, TSIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 TaskNameColumn;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle;

FROM TimeJump               IMPORT
    (* PROC  *)                 FindNextKeyDate;

FROM Timei                  IMPORT
    (* CONST *)                 NoDuration,
    (* TYPE  *)                 ADate, ADurationUnit, ATimeInfo,
    (* PROC  *)                 TimeUtoT;


FROM TLSRRec                IMPORT
    (* CONST *)                 LASTTASKINFO, LASTASSIGNINFO,
    (* TYPE *)                  AReportChoices, AGroupMethod, AShowMethod   ,
                                ADateInfo, AColumnInfo,
                                AColumnPrintStatus,
                                AStatusFormInputValues, AStatusFormInputValuesPtr,
                                AStatusReportPrintControls, AStatusReportPrintControlsPtr;



FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder;

CONST
    ModuleNumber        =   21700;
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


    AStatusReportSettingsPtr        =   POINTER TO AStatusReportSettings;


    AGetFirstStatusTaskProc = PROCEDURE(AStatusReportSettingsPtr) : ATreeNode;
    AGetNextStatusTaskProc  = PROCEDURE(AStatusReportSettingsPtr) : ATreeNode;

    AStatusReportSettings   =   RECORD
        FormInputsPtr       :   AStatusFormInputValuesPtr;
        FormPrintsPtr       :   AStatusReportPrintControlsPtr;
        GetFirstStatusTask  :   AGetFirstStatusTaskProc;
        GetNextStatusTask   :   AGetNextStatusTaskProc;
        TaskTreeNode        :   ATreeNode;
        TaskPointer         :   ATaskPtr;
        AssignRecord        :   POINTER TO AnAssignmentRecord;
        RsrcNode            :   ATreeNode;
        ResourcePtr         :   AResourcePointer;
        PrintStartDate      :   ADate;
        NextPrintStartDate  :   ADate;
        EmptyReport         :   BOOLEAN;
        ResourceReported    :   BOOLEAN;
        SelectionStatus     :   AStatusSet;
        FoundStatus         :   AStatusSet;
        AssignMatch         :   BOOLEAN;
    END;

    AGetColumnDataProc      = PROCEDURE(VAR AStatusReportSettings,
                                            CARDINAL,
                                        VAR ARRAY OF CHAR);
    AGetColumnNameProc      = PROCEDURE(VAR AStatusReportSettings,
                                            CARDINAL,
                                        VAR ARRAY OF CHAR,
                                        VAR ARRAY OF CHAR);
    ATaskSelectedProc       = PROCEDURE(VAR AStatusReportSettings) : BOOLEAN;


(******* call by (For Tasks) and (For Each Resource) start here **********)




PROCEDURE PrintStripAndPageNumber( VAR StatusRptSettings : AStatusReportSettings
                                 );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH StatusRptSettings.FormPrintsPtr^ DO
        INC(PrintPageNumber);
        IF ( PageFooterOn ) THEN
            GetMessage(ModuleNumber + 17, Line); (* TIME LINE Status Report Page  *)
            PrintText(Line, Normal);
            CtoS(PrintPageNumber, Line);
            PrintText(Line, Normal);
            IF ( NOT OnlyOneStrip ) THEN
                GetMessage(ModuleNumber + 27, Line); (* strip *)
                PrintText(Line, Normal);
                CtoS(StripNumber, Line);
                PrintLine(Line, Normal);
            ELSE
                SetLengthOf(Line, 0);
                PrintLine(Line, Normal);
            END;
        ELSE
            SetLengthOf(Line, 0);
            PrintLine(Line, Normal);
        END;
    END;
END PrintStripAndPageNumber;




(****************************************************************************
    PrintStatusReportFooter -
        Print out all footer information ( only strip and page number for now)
    Set up the flag for report header. Set at topofpage flag to true;
****************************************************************************)
PROCEDURE PrintStatusReportFooter( VAR StatusRptSettings : AStatusReportSettings
                                 );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    WITH StatusRptSettings.FormPrintsPtr^ DO
     WITH StatusRptSettings.FormInputsPtr^ DO
        SetLengthOf(NoCharBuffer, 0);
        PrintLine( NoCharBuffer, Normal );
        PrintStripAndPageNumber( StatusRptSettings );
        AtTopOfPage := TRUE;
        PageHeaderOn := RepeatPageHeadings( StatusPageCtrl );
     END;
    END;
END PrintStatusReportFooter;




(****************************************************************************
    PrintStatusreportHeader -
        Print out all headerer information;
    Set at topofpage flag to false;
****************************************************************************)
PROCEDURE PrintStatusReportHeader( VAR StatusRptSettings : AStatusReportSettings
                                 );
BEGIN
    PageHead();
    FilterNotes(TRUE,    (* Select Filters *)
                TRUE);   (* Highlight Filters *)
    StatusRptSettings.FormPrintsPtr^.AtTopOfPage := FALSE;
    StatusRptSettings.FormPrintsPtr^.EndPageHeaderPos :=
                                                    GetCurrentPrintRow();
END PrintStatusReportHeader;




(****************************************************************************
    PrintBlankHeader   -
        Print out numbers of blank lines so that all strips' positions match.
        It does not use PrintALine or PrintBlanklines because we want to
        print all these blank lines before we print out other data.  That
        means we have to ignore all the flags that will be used in PrintALine
        and PrintBlankLine.
****************************************************************************)
PROCEDURE PrintBlankHeader( VAR StatusRptSettings : AStatusReportSettings
                          );
VAR
    i                       :   CARDINAL;
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    StartPage();
    SetLengthOf( NoCharBuffer, 0 );
    i := GetCurrentPrintRow();
    WHILE ( i < StatusRptSettings.FormPrintsPtr^.EndPageHeaderPos ) DO
        PrintLine( NoCharBuffer, Normal );
        INC( i );
    END;
END PrintBlankHeader;




(****************************************************************************
    MovePrintHeadToPageEnd  -
        Force the print head to end of page by sending blank lines to
    the printer.  It will not print on the reserved area on the bottom.
****************************************************************************)
PROCEDURE MovePrintHeadToPageEnd( VAR StatusRptSettings : AStatusReportSettings
                                );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
    i                       :  CARDINAL;
BEGIN
    WITH StatusRptSettings DO
        SetLengthOf(NoCharBuffer, 0);
        IF ( PageBreaksEnable(
              StatusRptSettings.FormInputsPtr^.StatusPageCtrl  ) ) THEN
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
    Currently, OneTaskPerPage is always false.
****************************************************************************)
PROCEDURE MovePrintHeadToPageEndIfNeeded( VAR StatusRptSettings : AStatusReportSettings
                                        );
VAR
    i                       :  CARDINAL;
BEGIN
    IF ( StatusRptSettings.FormPrintsPtr^.OneTaskPerPage
        AND
         NOT StatusRptSettings.EmptyReport ) THEN
        MovePrintHeadToPageEnd( StatusRptSettings );
    END;
END MovePrintHeadToPageEndIfNeeded;




(***************************************************************************
    NPrintRowsOnCurrentPage  -
        Make sure we can print n lines onto the same page.
****************************************************************************)
PROCEDURE NPrintRowsOnCurrentPage( VAR StatusRptSettings : AStatusReportSettings;
                                       n : CARDINAL
                                 ) : BOOLEAN;
VAR
    i                       :   CARDINAL;
BEGIN
    IF ( NOT PageBreaksEnable(
            StatusRptSettings.FormInputsPtr^.StatusPageCtrl ) ) THEN
        RETURN TRUE;
    END;

    i := RowsLeft();
    IF (i = 0) THEN RETURN TRUE; END; (* We are at top of page *)

    RETURN ( i >= (NBottomRowsReserved + n) )
END NPrintRowsOnCurrentPage;




(****************************************************************************
    PrintALine  -
        print a line.
        Print report header if at the top of page.
        Print report footer if at the bottom of page.
****************************************************************************)
PROCEDURE PrintALine( VAR StatusRptSettings : AStatusReportSettings;
                      VAR Line : ARRAY OF CHAR;
                                PrintMode : CARDINAL
                    );
BEGIN
    WITH StatusRptSettings.FormPrintsPtr^ DO
        AtTopOfPage := FALSE;
        IF ( RowsLeft() = NBottomRowsReserved ) THEN
            PrintStatusReportFooter( StatusRptSettings );
        END;
        IF ( PageHeaderOn ) THEN
            PageHeaderOn := FALSE;
            PrintStatusReportHeader( StatusRptSettings );
        ELSIF ( BlankHeaderOn ) THEN
            BlankHeaderOn := FALSE;
            PrintBlankHeader( StatusRptSettings );
        END;
        PrintLine(Line, PrintMode);
    END;
END PrintALine;




(****************************************************************************
    PrintALine  -
        print out text.
        Print report header if at the top of page.
        Print report footer if at the bottom of page.
****************************************************************************)
PROCEDURE PrintAText(VAR StatusRptSettings : AStatusReportSettings;
                     VAR Line : ARRAY OF CHAR;
                         PrintMode : CARDINAL
                    );
BEGIN
    WITH StatusRptSettings.FormPrintsPtr^ DO
        AtTopOfPage := FALSE;
        IF ( RowsLeft() = NBottomRowsReserved ) THEN
            PrintStatusReportFooter( StatusRptSettings );
        END;
        IF ( PageHeaderOn ) THEN
            PageHeaderOn := FALSE;
            PrintStatusReportHeader( StatusRptSettings );
        ELSIF ( BlankHeaderOn ) THEN
            BlankHeaderOn := FALSE;
            PrintBlankHeader( StatusRptSettings );
        END;
        PrintText(Line, PrintMode);
    END;
END PrintAText;




PROCEDURE PrintBlankLine( VAR StatusRptSettings : AStatusReportSettings );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    SetLengthOf(NoCharBuffer, 0);
    PrintALine(StatusRptSettings, NoCharBuffer, Normal);
END PrintBlankLine;




(****************************************************************************
    FillOneLineWithColumnData -
        Get the data for each column.  For blank columns, a full column width
    of underscore characters will be printed.
        Since Tasks, Resources and Assignements require different method to
    get data from it, a procedure is passed to here to getting the data.

****************************************************************************)
PROCEDURE FillOneLineWithColumnData(
                                     VAR ColumnInfo : ARRAY OF AColumnInfo;
                                   start, nextstart : CARDINAL;
                                        PrintStatus : AColumnPrintStatus;
                                      GetColumnData : AGetColumnDataProc;
                                     VAR StatusRptSettings : AStatusReportSettings;
                                    VAR PrintBuffer : ARRAY OF CHAR
                                       );
VAR
    Line                  :  ARRAY [0..MaxWidth] OF CHAR;
    i                     :  CARDINAL;
BEGIN
    IF ( PrintStatus <> PrintActive ) THEN RETURN; END;
    FOR  i := start TO nextstart - 1 DO
        IF (ColumnInfo[i].ColumnWidth <> 0) THEN
            IF (ColumnInfo[i].IsBlankColumn) THEN
                Fill(Line, '_', ColumnInfo[i].ColumnWidth);
            ELSE
                GetColumnData(StatusRptSettings, i, Line);
                Procustes(Line, ColumnInfo[i].ColumnWidth);
            END;
            ConcatLS(PrintBuffer, Line);
            Fill(Line, ' ', NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
        END;
    END;
END FillOneLineWithColumnData;




(****************************************************************************
    FillOneLineWithColumnSeparators -
        Get a full column width of '-' characters to separate the column
    name and data.
****************************************************************************)
PROCEDURE FillOneLineWithColumnSeparators(
                                     VAR ColumnInfo : ARRAY OF AColumnInfo;
                                   start, nextstart : CARDINAL;
                                        PrintStatus : AColumnPrintStatus;
                                    VAR PrintBuffer : ARRAY OF CHAR
                                         );
VAR
    Line                  :  ARRAY [0..MaxWidth] OF CHAR;
    i                     :  CARDINAL;
BEGIN
    IF ( PrintStatus <> PrintActive ) THEN RETURN; END;
    FOR  i := start TO nextstart - 1 DO
        IF (ColumnInfo[i].ColumnWidth <> 0) THEN
            Fill(Line, '-', ColumnInfo[i].ColumnWidth);
            ConcatLS(PrintBuffer, Line);
            Fill(Line, ' ', NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
        END;
    END;
END FillOneLineWithColumnSeparators;




(****************************************************************************
    FillTwoLinesWithColumnNames -
        Get the name for each column. These are the names which user enter
    into the form.
****************************************************************************)
PROCEDURE FillTwoLinesWithColumnNames(
                                    VAR ColumnInfo : ARRAY OF AColumnInfo;
                                  start, nextstart : CARDINAL;
                                       PrintStatus : AColumnPrintStatus;
                                     GetColumnName : AGetColumnNameProc;
                               VAR StatusRptSettings : AStatusReportSettings;
                                   VAR PrintBuffer : ARRAY OF CHAR;
                                  VAR PrintBuffer2 : ARRAY OF CHAR
                                     );
VAR
    i                       :   CARDINAL;
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    IF ( PrintStatus <> PrintActive ) THEN RETURN; END;
    FOR  i := start TO nextstart - 1 DO
        IF (ColumnInfo[i].ColumnWidth <> 0) THEN
            GetColumnName(StatusRptSettings, i, Line, Line2);
            ConcatLS(PrintBuffer, Line);
            ConcatLS(PrintBuffer2, Line2);
            Fill(Line, ' ', NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
            ConcatLS(PrintBuffer2, Line);
        END;
    END;
END FillTwoLinesWithColumnNames;




(****************************************************************************
    GetAssignData -
        This procedure calls GetAssString to get the data for task column.
****************************************************************************)
PROCEDURE GetAssignData( VAR StatusRptSettings : AStatusReportSettings;
                             Index : CARDINAL;
                         VAR Line : ARRAY OF CHAR
                           );
BEGIN
    WITH StatusRptSettings.FormInputsPtr^ DO
        IF ( NOT (GetAssString(StatusRptSettings.AssignRecord^,
                               StatusRptSettings.TaskPointer,
                               AssignColumn[Index].ColumnID,
                               AssignColumn[Index].ColumnWidth,
                               Line) ) ) THEN
            GetMessage(ModuleNumber + 2, Line); (* N/A *)
        END;
    END;
END GetAssignData;




(****************************************************************************
    GetAssignColumnName-
        This procedure calls GetColumnString to get the data for Assign
    column.
****************************************************************************)
PROCEDURE GetAssignColumnName( VAR StatusRptSettings : AStatusReportSettings;
                                   Index : CARDINAL;
                               VAR Line1 : ARRAY OF CHAR;
                               VAR Line2 : ARRAY OF CHAR
                         );
VAR
    DataRecord1             :   AColumnDataRecord;
    DataRecord2             :   AColumnDataRecord;
BEGIN
    WITH StatusRptSettings.FormInputsPtr^ DO

        IF ( GetAssInfo(AssignColumn[Index].ColumnID,
                        ColumnHeading1, maxcol, DataRecord1) ) THEN
            Copy(DataRecord1.StringValue, Line1);
            TrimFront(Line1);
        END;

        IF ( GetAssInfo(AssignColumn[Index].ColumnID,
                         ColumnHeading2, maxcol, DataRecord2) ) THEN
            Copy(DataRecord2.StringValue, Line2);
            TrimFront(Line2);
        END;

        TrimRear(Line1);
        TrimRear(Line2);

        IF ( (LengthOf(Line1) > AssignColumn[Index].ColumnWidth)
                OR
              (LengthOf(Line2) > AssignColumn[Index].ColumnWidth) ) THEN
            IF ( GetAssInfo(AssignColumn[Index].ColumnID,
                         ColumnNarrowHeading1, maxcol, DataRecord1) ) THEN
                Copy(DataRecord1.StringValue, Line1);
                TrimFront(Line1);
            END;

            IF ( GetAssInfo(AssignColumn[Index].ColumnID,
                            ColumnNarrowHeading2, maxcol, DataRecord2) ) THEN
                Copy(DataRecord2.StringValue, Line2);
                TrimFront(Line2);
            END;
        END;
        Procustes(Line1, AssignColumn[Index].ColumnWidth);
        Procustes(Line2, AssignColumn[Index].ColumnWidth);
    END;
END GetAssignColumnName;




(****************************************************************************
    GetTaskData -
        This procedure calls GetColumnString to get the data for task column.
****************************************************************************)
PROCEDURE GetTaskData( VAR StatusRptSettings : AStatusReportSettings;
                           Index : CARDINAL;
                       VAR Line : ARRAY OF CHAR
                     );
VAR
    PlusCharPos             :   CARDINAL;
    Pattern                 :   ARRAY[0..1] OF CHAR;
BEGIN
    WITH StatusRptSettings.FormInputsPtr^ DO
        IF ( ( TaskColumn[Index].ColumnID <> TaskNameColumn )
            OR
             ( StatusRptSettings.FormPrintsPtr^.IndentOn ) ) THEN
            IF (NOT GetColumnString(StatusRptSettings.TaskTreeNode,
                               StatusRptSettings.TaskPointer,
                               TaskColumn[Index].ColumnID, Plan,
                               TaskColumn[Index].ColumnWidth, Line)) THEN
                GetMessage(ModuleNumber + 2, Line);  (* N/A *)
            END;
        ELSE
            IF ( GetColumnString(StatusRptSettings.TaskTreeNode,
                                 StatusRptSettings.TaskPointer,
                               TaskColumn[Index].ColumnID, Plan,
                               MaxWidth, Line) ) THEN
                GetMessage( ModuleNumber + 32, Pattern); (* '+' *)
                PlusCharPos := Search( Line, Pattern, 1 );
                IF ( PlusCharPos <> 0 ) THEN
                    Line[PlusCharPos] := ' ';
                END;
                TrimFront(Line);
            ELSE
                GetMessage(ModuleNumber + 2, Line); (* N/A *)
            END;
        END;
    END;
END GetTaskData;




(****************************************************************************
    GetTaskColumnName-
        This procedure calls GetColumnString to get the data for task column.
****************************************************************************)
PROCEDURE GetTaskColumnName( VAR StatusRptSettings : AStatusReportSettings;
                                 Index : CARDINAL;
                             VAR Line1 : ARRAY OF CHAR;
                             VAR Line2 : ARRAY OF CHAR
                           );
VAR
    DataRecord1             :   AColumnDataRecord;
    DataRecord2             :   AColumnDataRecord;
BEGIN
    WITH StatusRptSettings DO
     WITH StatusRptSettings.FormInputsPtr^ DO

        GetColumnInfo(TaskTreeNode, TaskPointer, TaskColumn[Index].ColumnID,
                        ColumnHeading1, maxcol, DataRecord1);
        GetColumnInfo(TaskTreeNode, TaskPointer, TaskColumn[Index].ColumnID,
                         ColumnHeading2, maxcol, DataRecord2);

        Copy(DataRecord1.StringValue, Line1);
        Copy(DataRecord2.StringValue, Line2);
        TrimFront(Line1);
        TrimFront(Line2);
        TrimRear(Line1);
        TrimRear(Line2);

        IF ( (LengthOf(Line1) > TaskColumn[Index].ColumnWidth)
                OR
              (LengthOf(Line2) > TaskColumn[Index].ColumnWidth) ) THEN
            GetColumnInfo(TaskTreeNode, TaskPointer,
                          TaskColumn[Index].ColumnID,
                         ColumnNarrowHeading1, maxcol, DataRecord1);
            GetColumnInfo(TaskTreeNode, TaskPointer,
                            TaskColumn[Index].ColumnID,
                            ColumnNarrowHeading2, maxcol, DataRecord2);
            Copy(DataRecord1.StringValue, Line1);
            Copy(DataRecord2.StringValue, Line2);
        END;
        Procustes(Line1, TaskColumn[Index].ColumnWidth);
        Procustes(Line2, TaskColumn[Index].ColumnWidth);
     END;
    END;
END GetTaskColumnName;




(****************************************************************************
    PrintOneTask -
        Task pointer is already locked by the calling procedure.
****************************************************************************)
PROCEDURE PrintOneTask(VAR StatusRptSettings : AStatusReportSettings);
VAR
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN

    WITH StatusRptSettings DO
        WITH StatusRptSettings.FormInputsPtr^ DO
         WITH StatusRptSettings.FormPrintsPtr^ DO

            EmptyReport := FALSE;

            IF ( NOT NPrintRowsOnCurrentPage(StatusRptSettings, 1) ) THEN
                MovePrintHeadToPageEnd(StatusRptSettings);
                IF ( NOT PrintTitle ) THEN
                    PrintTitle := RepeatColumnHeadings( StatusPageCtrl );
                END;
            END;

            IF ( PrintTitle ) THEN
                PrintTitle := FALSE;

                IF (NOT NPrintRowsOnCurrentPage(StatusRptSettings, 4)) THEN
                   MovePrintHeadToPageEnd(StatusRptSettings);
                END;

                SetLengthOf(Line, 0);
                SetLengthOf(Line2, 0);
                FillTwoLinesWithColumnNames(TaskColumn, TaskStart,
                                     NextTaskStart,
                                     TaskPrintStatus, GetTaskColumnName,
                                     StatusRptSettings, Line, Line2);
                FillTwoLinesWithColumnNames(AssignColumn, AssignStart,
                                     NextAssignStart,
                                     AssignPrintStatus, GetAssignColumnName,
                                     StatusRptSettings,Line, Line2);
                PrintALine(StatusRptSettings, Line, Normal);
                PrintALine(StatusRptSettings, Line2, Normal);

                SetLengthOf(Line, 0);
                FillOneLineWithColumnSeparators(TaskColumn, TaskStart,
                                        NextTaskStart, TaskPrintStatus, Line);
                FillOneLineWithColumnSeparators(AssignColumn, AssignStart,
                                    NextAssignStart, AssignPrintStatus, Line);
                PrintALine(StatusRptSettings, Line, Normal);
            END;
            SetLengthOf(Line, 0);
            FillOneLineWithColumnData(TaskColumn, TaskStart, NextTaskStart,
                    TaskPrintStatus, GetTaskData, StatusRptSettings, Line);
            FillOneLineWithColumnData(AssignColumn, AssignStart,
                                   NextAssignStart, AssignPrintStatus,
                                   GetAssignData, StatusRptSettings, Line);
            PrintALine(StatusRptSettings, Line, PrintAttribute);
         END;
        END;
    END;
END PrintOneTask;




(****************************************************************************
    AssignmetsMatch -
        Return True if the given resource and task has an assignment.
               False otherwise.
    This functions is called only when we do report for each resource.
****************************************************************************)
PROCEDURE AssignmentsMatch(
                            VAR Assignment : AnAssignmentRecord;
                                Context : ADDRESS
                          ) : BOOLEAN;
VAR
    StatusRptSettingsPtr    :   AStatusReportSettingsPtr;
BEGIN
    StatusRptSettingsPtr := Context;

    WITH StatusRptSettingsPtr^ DO
        AssignMatch := (Assignment.Resource = ResourcePtr);
        IF ( AssignMatch ) THEN
            StatusRptSettingsPtr^.AssignRecord := ADR(Assignment);
        END;
        RETURN NOT AssignMatch; (* Continue if not match *)
    END;
END AssignmentsMatch;




(****************************************************************************
    SelectedTask    -
        Return True if current task node is selected.
               False otherwise.
****************************************************************************)
PROCEDURE SelectedTask(VAR StatusRptSettings : AStatusReportSettings
                      ) : BOOLEAN;
BEGIN
    RETURN ( ( StatusRptSettings.SelectionStatus * AStatusSet(
                 StatusRptSettings.TaskPointer^.count)) <> AStatusSet{} );
END SelectedTask;




(****************************************************************************
    TaskStartInGivenRange   -
        Return true if task starts in given date range.
               false otherwise.
****************************************************************************)
PROCEDURE TaskStartInGivenRange( VAR StatusRptSettings : AStatusReportSettings
                               ) : BOOLEAN;
BEGIN
    StatusRptSettings.SelectionStatus :=
                                        AStatusSet{SelfStart, InStartList};
    RETURN SelectedTask(StatusRptSettings);
END TaskStartInGivenRange;




(****************************************************************************
    TaskEndInGivenRange   -
        Return true if task ends in given date range.
               false otherwise.
****************************************************************************)
PROCEDURE TaskEndInGivenRange( VAR StatusRptSettings : AStatusReportSettings
                             ) : BOOLEAN;
BEGIN
    StatusRptSettings.SelectionStatus := AStatusSet{SelfEnd, InEndList};
    RETURN SelectedTask(StatusRptSettings);
END TaskEndInGivenRange;




(****************************************************************************
    TaskContInGivenRange   -
        Return true if task continue in given date range.
               false otherwise.
****************************************************************************)
PROCEDURE TaskContInGivenRange( VAR StatusRptSettings : AStatusReportSettings
                              ) : BOOLEAN;
BEGIN
    StatusRptSettings.SelectionStatus :=
                                    AStatusSet{SelfContinue, InContinueList};
    RETURN SelectedTask(StatusRptSettings);
END TaskContInGivenRange;




(****************************************************************************
    TaskDelayedInGivenRange   -
        Return true if task is not completed in given date range.
               false otherwise.
****************************************************************************)
PROCEDURE TaskDelayedInGivenRange( VAR StatusRptSettings : AStatusReportSettings
                                 ) : BOOLEAN;
BEGIN
    StatusRptSettings.SelectionStatus := AStatusSet{SelfDelayed, InDelayedList};
    RETURN SelectedTask(StatusRptSettings);
END TaskDelayedInGivenRange;




(****************************************************************************
    TaskInNotGrpByStartEndCont  -
        Return true if task starts, end, continue or not completed
                                                          in given date range.
               false otherwise.
****************************************************************************)
PROCEDURE TaskInNotGrpByStartEndCont( VAR StatusRptSettings : AStatusReportSettings
                                    ) : BOOLEAN;
BEGIN
    StatusRptSettings.SelectionStatus :=
                                    AStatusSet{InStartList, SelfStart,
                                               InEndList, SelfEnd,
                                               InContinueList, SelfContinue
                                              };
    RETURN SelectedTask(StatusRptSettings);
END TaskInNotGrpByStartEndCont;




(****************************************************************************
    PrintAllTasksStatus -
        Print tasks which are already selected.
****************************************************************************)
PROCEDURE PrintAllTasksStatus(
                               VAR StatusRptSettings : AStatusReportSettings;
                                       TaskSelected : ATaskSelectedProc;
                                          VAR Title : ARRAY OF CHAR
                              );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    TaskFilter              :   ATaskFilterSet;
    PrintDateRangeTitle     :   BOOLEAN;
BEGIN
    PrintDateRangeTitle := TRUE;

    WITH StatusRptSettings DO
     WITH StatusRptSettings.FormPrintsPtr^ DO


        PrintTitle := TRUE;

        TaskTreeNode :=  GetFirstStatusTask(ADR(StatusRptSettings));
        WHILE TaskTreeNode <> NIL DO

            TaskFilter := TaskFiltersPassed( TaskTreeNode );
            IF ( TaskFilter * ATaskFilterSet{Highlight3..Highlight5} =
                                                      ATaskFilterSet{} ) THEN
                PrintAttribute := Normal;
            ELSE
                PrintAttribute := Bold;
            END;

            TaskPointer :=
                TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
            IF ( TaskSelected(StatusRptSettings) ) THEN
                IF ( PrintDateRangeTitle ) THEN
                    IF ( NOT NPrintRowsOnCurrentPage(StatusRptSettings, 2) ) THEN
                        MovePrintHeadToPageEnd(StatusRptSettings);
                    END;

                    PrintBlankLine( StatusRptSettings );
                    Fill(Line, 'Ä', PrintPageWidth);
                    PrintALine(StatusRptSettings, Line, Normal);
                    PrintALine(StatusRptSettings, Title, Normal);
                    PrintBlankLine( StatusRptSettings );
                    PrintDateRangeTitle := FALSE;
                END;
                PrintOneTask(StatusRptSettings);
            END;
            TaskTreeNode^.Methods^.UnlockFlexStorDataObject(TaskTreeNode);
            TaskPointer := NIL;      (* SAFETY!!! *)
            TaskTreeNode :=  GetNextStatusTask(ADR(StatusRptSettings));
        END;
     END;
    END;
END PrintAllTasksStatus;




(****************************************************************************
    PrintDurationUnit   -
        Print tasks for each grouping ( start, end, continue ,delay or none)
****************************************************************************)
PROCEDURE PrintDurationUnit(
                             VAR StatusRptSettings : AStatusReportSettings;
                                 VAR DateInfo : ADateInfo
                       );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    DateUnitString          :   ARRAY [0..MaxWidth] OF CHAR;
    TimeInfo                :   ATimeInfo;
BEGIN
    IF (StatusRptSettings.FoundStatus = AStatusSet{} ) THEN
        RETURN;
    END;

    CASE DateInfo.DateUnit OF
        | Days: GetMessage(ModuleNumber + 18, DateUnitString);  (* 'day '*)
        | Weeks: GetMessage(ModuleNumber + 19, DateUnitString); (* 'week '*)
        | Months: GetMessage(ModuleNumber + 20, DateUnitString);(* 'month '*)
    END;

    IF ( NOT NPrintRowsOnCurrentPage(StatusRptSettings, 4) ) THEN
        MovePrintHeadToPageEnd(StatusRptSettings);
    ELSE
        PrintBlankLine( StatusRptSettings );
    END;

    Fill(Line, 'Ä', StatusRptSettings.FormPrintsPtr^.PrintPageWidth);
    PrintALine( StatusRptSettings, Line, Normal );
    GetMessage(ModuleNumber + 4, Line); (* 'Status Report for ' *)
    PrintAText(StatusRptSettings, Line, Normal);

    WITH StatusRptSettings DO
     WITH StatusRptSettings.FormPrintsPtr^ DO
        IF ( RsrcTitle ) THEN
            IF (GetRsrcString(RsrcNode, RsrcName, MaxWidth, Line))
            THEN
                TrimRear(Line);
                PrintAText(StatusRptSettings, Line, Normal);
            ELSE
                FatalError();
            END;
            GetMessage( ModuleNumber + 31, Line ); (* , *)
            PrintAText ( StatusRptSettings, Line, Normal );
        END;
     END;
    END;

    PrintAText(StatusRptSettings,DateUnitString, Normal);
    GetMessage(ModuleNumber + 5, Line); (* ' of ' *)
    PrintAText(StatusRptSettings, Line, Normal);

    TimeUtoT (StatusRptSettings.PrintStartDate, TimeInfo );

    TimeToString( TimeInfo, DefaultDateFormat, Line );

    PrintAText(StatusRptSettings, Line, Normal);

    IF (DateInfo.DateUnit <> Days ) THEN
        GetMessage(ModuleNumber + 8, Line); (* 'through ' *)
        PrintAText(StatusRptSettings, Line, Normal);
        TimeAsEndDateStyle( StatusRptSettings.NextPrintStartDate,
                               EndDateStyle, TimeInfo );
        TimeToString( TimeInfo, DefaultDateFormat, Line );
        PrintALine(StatusRptSettings, Line, Normal);
    ELSE
        PrintBlankLine( StatusRptSettings );
    END;

    IF ( StatusRptSettings.FormPrintsPtr^.PrintPastDue ) THEN
        GetMessage(ModuleNumber +  24, Line); (* Tasks delayed, prior to this *)
        ConcatLS(Line, DateUnitString);
        PrintAllTasksStatus(StatusRptSettings,
                                               TaskDelayedInGivenRange, Line);
    END;

    IF (StatusRptSettings.FormInputsPtr^.HowToGroup =
                                            NotGroupByStartEndCont) THEN
        SetLengthOf(Line, 0);
        PrintAllTasksStatus(StatusRptSettings,
                                            TaskInNotGrpByStartEndCont, Line);
    ELSE
        GetMessage(ModuleNumber +  21, Line); (* Tasks beginning this  *)
        ConcatLS(Line, DateUnitString);
        PrintAllTasksStatus(StatusRptSettings, TaskStartInGivenRange,
                                                                        Line);
        GetMessage(ModuleNumber +  22, Line); (* Tasks ending this  *)
        ConcatLS(Line, DateUnitString);
        PrintAllTasksStatus(StatusRptSettings, TaskEndInGivenRange, Line);

        GetMessage(ModuleNumber +  23, Line); (* Tasks continuing throughout this *)
        ConcatLS(Line, DateUnitString);
        PrintAllTasksStatus(StatusRptSettings, TaskContInGivenRange, Line);
    END;

    MovePrintHeadToPageEndIfNeeded(StatusRptSettings);

END PrintDurationUnit;




(****************************************************************************
    MarkTask    -
        If given task is started, ended, continued or delayed in given
    time interval, then mark it based on the value in status set.
****************************************************************************)
PROCEDURE MarkTask( VAR StatusRptSettings : AStatusReportSettings );
VAR
    StartDate               :   ADate;
    NextStartDate           :   ADate;
    StatusSet               :   AStatusSet;


    PROCEDURE MarkParents(     Node         : ATreeNode;       (* 18-Mar-92 *)
                               StatusSet    : AStatusSet;
                           VAR FoundSet     : AStatusSet );

    VAR
        ParentNode          :   ATreeNode;
        ParentTask          :   ATaskPtr;
        ParentSet           :   AStatusSet;

    BEGIN                   (* MarkParents *)

        ParentNode := Node^.Methods^.Parent(Node);
        IF (ParentNode <> NIL) THEN
            ParentTask :=
                      ParentNode^.Methods^.LockFlexStorDataObject(ParentNode);
            ParentSet := AStatusSet(ParentTask^.count);
            IF (InDelayedList IN StatusSet) THEN
                INCL (ParentSet, InDelayedList);
            END;
            IF (InStartList IN StatusSet) THEN
                INCL (ParentSet, InStartList);
            END;
            IF (InEndList IN StatusSet) THEN
                INCL (ParentSet, InEndList);
            END;
            IF (InContinueList IN StatusSet) THEN
                INCL (ParentSet, InContinueList);
            END;
            ParentTask^.count := CARDINAL(ParentSet);
            ParentNode^.Methods^.UnlockFlexStorDataObject (ParentNode);
            ParentTask := NIL;                            (* SAFETY!!!! *)
            FoundSet := FoundSet + ParentSet;
            MarkParents( ParentNode, StatusSet, FoundSet );
        END;

    END MarkParents;

BEGIN

(* Only mark all visible nodes *)

    WITH StatusRptSettings DO
        IF ( NOT TaskTreeNode^.Methods^.Visible(TaskTreeNode) ) THEN
            RETURN;
        END;

        IF ( ( NOT StatusRptSettings.FormInputsPtr^.OpenSummary )
            AND
             ( TaskTreeNode^.Methods^.FirstChild(TaskTreeNode)
                                                            <> ATreeNode(NIL))
            AND
             (TaskTreeNode^.Methods^.ChildrenVisible(TaskTreeNode) ) ) THEN
            RETURN;
        END;

        StartDate := StatusRptSettings.PrintStartDate;
        NextStartDate := StatusRptSettings.NextPrintStartDate;

        TaskPointer :=
                 TaskTreeNode^.Methods^.LockFlexStorDataObject (TaskTreeNode);
        StatusSet := AStatusSet (TaskPointer^.count);

        WITH TaskPointer^.Plan.Dates DO
                (* Be we delayed? *)
            IF ( StatusRptSettings.FormPrintsPtr^.PrintPastDue ) THEN
                IF ( (EarlyEnd <= StartDate)
                    AND
                     (TaskPointer^.StartStatus <> DoneS) ) THEN
                    INCL (StatusSet, SelfDelayed);
                    INCL (StatusSet, InDelayedList);
                END;
            END;
            IF ( (EarlyStart >= StartDate)
                AND
                 (EarlyStart < NextStartDate) ) THEN
                INCL (StatusSet, SelfStart);
                INCL (StatusSet, InStartList);
            END;
            (* May 15, 1989, always treat Milestone as StartOfNextDay *)

            IF ( ( EndDateStyle = EndOfDay )
                 AND
                 ( TaskPointer^.duration <> NoDuration ) ) THEN
                IF ( (EarlyEnd > StartDate)
                    AND
                     (EarlyEnd <= NextStartDate) ) THEN
                    INCL (StatusSet, SelfEnd);
                    INCL (StatusSet, InEndList);
                END;
                IF ( (EarlyStart < StartDate)
                    AND
                     (EarlyEnd > NextStartDate) ) THEN
                    INCL (StatusSet, SelfContinue);
                    INCL (StatusSet, InContinueList);
                END;
            ELSE
                IF ( (EarlyEnd >= StartDate)
                    AND
                     (EarlyEnd < NextStartDate) ) THEN
                    INCL (StatusSet, SelfEnd);
                    INCL (StatusSet, InEndList);
                END;
                IF ( (EarlyStart < StartDate)
                    AND
                     (EarlyEnd >= NextStartDate) ) THEN
                    INCL (StatusSet, SelfContinue);
                    INCL (StatusSet, InContinueList);
                END;
            END;
        END;
        TaskPointer^.count := CARDINAL(StatusSet);
        StatusRptSettings.FoundStatus :=
                                StatusRptSettings.FoundStatus + StatusSet;

        TaskTreeNode^.Methods^.UnlockFlexStorDataObject (TaskTreeNode);
        TaskPointer := NIL;                                     (* SAFETY!!!! *)

(*  No need to check parent if we don't report open summary *)

        IF ( NOT StatusRptSettings.FormInputsPtr^.OpenSummary ) THEN
            RETURN;
        END;

        MarkParents( TaskTreeNode, StatusSet, StatusRptSettings.FoundStatus );
    END;
END MarkTask;




(****************************************************************************
    MarkAllTasks    -
        Call Mark task to mark all task.
****************************************************************************)
PROCEDURE MarkAllTasks(VAR StatusRptSettings : AStatusReportSettings);
BEGIN
    WITH StatusRptSettings DO
        TaskTreeNode := GetFirstStatusTask(ADR(StatusRptSettings));
        WHILE ( TaskTreeNode <> NIL) DO
            MarkTask( StatusRptSettings);
            TaskTreeNode := GetNextStatusTask(ADR(StatusRptSettings));
        END;
    END;
END MarkAllTasks;




(****************************************************************************
    ClearTask    -
        Clear the status flag for each task.
****************************************************************************)
PROCEDURE ClearTask(
                      VAR Node : ATreeNode;
                       Context : ADDRESS
                    );
VAR
    Task                    :   ATaskPtr;
BEGIN
     Task := Node^.Methods^.LockFlexStorDataObject (Node);
     Task^.count := CARDINAL(AStatusSet{});
     Node^.Methods^.UnlockFlexStorDataObject (Node);
     Task := NIL;        (* Safety !!! *)
END ClearTask;




(****************************************************************************
    ClearAllTasks -
        Unmark all tasks.  Although MarkAllTasks is not using travers tree
    but this function is.  The reason is that some nodes are marked as
    parent node in MarkAllTasks, and those should be  reset too.
****************************************************************************)
PROCEDURE ClearAllTasks( VAR StatusRptSettings : AStatusReportSettings );
BEGIN
    StatusRptSettings.FoundStatus := AStatusSet{};
    TaskTree^.Methods^.TraverseTree (TaskTree, ParentAfterChild, 9999,
                                        ClearTask, ADR(StatusRptSettings));
END ClearAllTasks;




(****************************************************************************
    DoADurationUnit -
        For each date range, print each time interval.
****************************************************************************)
PROCEDURE DoADurationUnit( VAR StatusRptSettings : AStatusReportSettings;
                           VAR DateInfo : ADateInfo
                     );
VAR
    i                       :   CARDINAL;
BEGIN
    WITH DateInfo DO
        IF (LengthOf(DateString) = 0) THEN RETURN; END;
        WITH StatusRptSettings DO
         WITH StatusRptSettings.FormPrintsPtr^ DO
            PrintPastDue := FormInputsPtr^.IncludePastDue;
            PrintStartDate := DateValue;
            FOR i := 1 TO DateDuration DO
                NextPrintStartDate := FindNextKeyDate(PrintStartDate, DateUnit);
                ClearAllTasks(StatusRptSettings);
                MarkAllTasks(StatusRptSettings);
                PrintDurationUnit(StatusRptSettings, DateInfo);
                PrintStartDate := NextPrintStartDate;
                PrintPastDue := FALSE;
            END;
         END;
        END;
    END;
    ClearAllTasks(StatusRptSettings);
    MovePrintHeadToPageEndIfNeeded( StatusRptSettings );
END DoADurationUnit;




(****************************************************************************
    MoreAssignToPrint -
        If more assignments to be printed return TRUE, otherwise return FALSE.
****************************************************************************)
PROCEDURE MoreAssignToPrint( VAR StatusRptSettings : AStatusReportSettings
                           ): BOOLEAN;
BEGIN
    IF ( StatusRptSettings.FormInputsPtr^.HowToReport = TasksStatus ) THEN
        RETURN FALSE;
    END;

    WITH StatusRptSettings.FormPrintsPtr^ DO
        IF ( AssignPrintStatus = PrintFinish ) THEN
            RETURN FALSE;
        END;
        IF ( NextAssignStart > LASTASSIGNINFO ) THEN
            AssignPrintStatus := PrintFinish;
            RETURN FALSE;
        END;
        RETURN TRUE;
    END;
END MoreAssignToPrint;




(****************************************************************************
    MoreTaskToPrint -
        If more tasks to be printed return TRUE, otherwise return FALSE.
****************************************************************************)
PROCEDURE MoreTaskToPrint( VAR StatusRptSettings : AStatusReportSettings
                         ) : BOOLEAN;
BEGIN

    WITH StatusRptSettings.FormPrintsPtr^ DO
        IF ( TaskPrintStatus = PrintFinish ) THEN
            RETURN FALSE;
        END;
        IF ( NextTaskStart > LASTTASKINFO ) THEN
            TaskPrintStatus := PrintFinish;
            RETURN FALSE;
        END;
        RETURN TRUE;
    END;

END MoreTaskToPrint;




(****************************************************************************
    FindStartAndNextStartColumn
        If all columns have already been printed, then return FALSE;
        Otherwise.
        Find the starting for this print and next print. Then
        number of print columns = Starting for next - Starting for current.
        Return TRUE;
****************************************************************************)
PROCEDURE FindStartAndNextStartColumn(
                                  VAR Start, NextStart : CARDINAL;
                                       VAR PrintStatus : AColumnPrintStatus;
                                            PrintWidth : CARDINAL;
                                              PrintPos : CARDINAL;
                                     VAR NPrintSpcLeft : CARDINAL;
                                        VAR ColumnInfo : ARRAY OF AColumnInfo;
                                           NColumnInfo : CARDINAL
                                     ) : BOOLEAN;
VAR
    i                       :   CARDINAL;
BEGIN

    IF ( PrintStatus = PrintFinish ) THEN
        RETURN FALSE;
    END;

    NPrintSpcLeft := PrintWidth - PrintPos;
    i := NextStart;

    WHILE ( ( i <= NColumnInfo)
             AND
              ( NPrintSpcLeft >= ColumnInfo[i].ColumnWidth + NSpcsBetweenFld )
            ) DO
        IF ( ColumnInfo[i].ColumnWidth <> 0) THEN
            NPrintSpcLeft := NPrintSpcLeft -
                            (ColumnInfo[i].ColumnWidth + NSpcsBetweenFld);
        END;
        INC (i);
    END;

(* We still return true here because there are empty spaces, but
    the column is too big to fit in it                             *)

    IF ( i <> 0  ) THEN
        WHILE ( (i <= NColumnInfo) AND (ColumnInfo[i].ColumnWidth = 0)) DO
            INC(i);
        END;
        PrintStatus := PrintActive;
        Start := NextStart;
        NextStart := i;
    END;

    RETURN TRUE;
END FindStartAndNextStartColumn;




(****************************************************************************
    FindStartAndNextStartAssignColumn -
        Find the number of assignments columns to be printed by finding the
    next starting column and the current starting column.
****************************************************************************)
PROCEDURE FindStartAndNextStartAssignColumn( VAR StatusRptSettings : AStatusReportSettings
                                           );
VAR
    NPrintSpcLeft           :   CARDINAL;
BEGIN

    IF ( StatusRptSettings.FormInputsPtr^.HowToReport = TasksStatus ) THEN
        StatusRptSettings.FormPrintsPtr^.AssignPrintStatus := PrintFinish;
        RETURN;
    END;

    WITH StatusRptSettings.FormPrintsPtr^ DO

        IF (PrintHeadPos = PrintPageWidth ) THEN RETURN; END;

        IF ( NOT FindStartAndNextStartColumn(AssignStart, NextAssignStart,
                          AssignPrintStatus, PrintPageWidth, PrintHeadPos,
                          NPrintSpcLeft,
                          StatusRptSettings.FormInputsPtr^.AssignColumn,
                          LASTASSIGNINFO) ) THEN
            RETURN;
        END;

        IF ( NextAssignStart <= LASTASSIGNINFO ) THEN
            PrintHeadPos := PrintPageWidth;
            OnlyOneStrip := FALSE;
        ELSE
            PrintHeadPos := PrintPageWidth - NPrintSpcLeft;
        END;
    END;

END FindStartAndNextStartAssignColumn;




(****************************************************************************
    FindStartAndNextStartTaskColumn -
        Find the number of task columns to be printed by finding the
    next starting column and the current starting column.
****************************************************************************)
PROCEDURE FindStartAndNextStartTaskColumn( VAR StatusRptSettings: AStatusReportSettings
                                         );
VAR
    NPrintSpcLeft           :   CARDINAL;
BEGIN

    WITH StatusRptSettings.FormPrintsPtr^ DO

    (* Start at new line *)
        PrintHeadPos := 0;

        IF ( NOT FindStartAndNextStartColumn(TaskStart, NextTaskStart,
                          TaskPrintStatus, PrintPageWidth,
                          PrintHeadPos, NPrintSpcLeft,
                          StatusRptSettings.FormInputsPtr^.TaskColumn,
                          LASTTASKINFO) ) THEN
            RETURN;
        END;

        IF ( NextTaskStart <= LASTTASKINFO ) THEN
            PrintHeadPos := PrintPageWidth;
            OnlyOneStrip := FALSE;
        ELSE
            PrintHeadPos := PrintPageWidth - NPrintSpcLeft;
        END;
    END;

END FindStartAndNextStartTaskColumn;




PROCEDURE PrintReport(VAR StatusRptSettings : AStatusReportSettings);
BEGIN
    WITH StatusRptSettings DO
     WITH StatusRptSettings.FormPrintsPtr^ DO

        EmptyReport := TRUE;

(* indent only if we report open summary *)

        IndentOn := FormInputsPtr^.OpenSummary;
        AtTopOfPage := TRUE;
        OnlyOneStrip := TRUE;
        TaskStart := 0;
        NextTaskStart := 0;
        TaskPrintStatus := NotPrintYet;
        AssignStart := 0;
        NextAssignStart := 0;
        StripNumber := 0;
        AssignPrintStatus := NotPrintYet;
        PageHeaderOn := TRUE;
        REPEAT
            PageFooterOn := RepeatPageFootings(
                                        FormInputsPtr^.StatusPageCtrl );
            INC(StripNumber);
            PrintPageNumber := 0;
            BlankHeaderOn := NOT PageHeaderOn;
            FindStartAndNextStartTaskColumn( StatusRptSettings );
            FindStartAndNextStartAssignColumn( StatusRptSettings );
            WITH StatusRptSettings.FormInputsPtr^ DO
                DoADurationUnit(StatusRptSettings, DailyRange);
                DoADurationUnit(StatusRptSettings, WeeklyRange);
                DoADurationUnit(StatusRptSettings, MonthlyRange);
            END;
            IF ( NOT AtTopOfPage ) THEN
                MovePrintHeadToPageEnd( StatusRptSettings );
                PageFooterOn := TRUE;
                PrintStatusReportFooter( StatusRptSettings );
            END;
            AllowLeftMargin(NOT IgnoreLeftMargin(
                                        FormInputsPtr^.StatusPageCtrl));
        UNTIL Stopped
                   OR
                   (
                      NOT MoreTaskToPrint(StatusRptSettings)
                         AND
                      NOT MoreAssignToPrint(StatusRptSettings)
                   );
     END;
    END;
END PrintReport;

(******* call by (For Tasks) and (For Each Resource) end here **********)




(******* For Each Resource start here **********************************)

(****************************************************************************
    GetFirstStatusReportForEachResource  -
        Return first task.  Use GetFirstVisible and NextPreOrder to
        traverse the task tree.
****************************************************************************)
PROCEDURE GetFirstStatusReportForEachResource(
                                StatusRptSettingsPtr : AStatusReportSettingsPtr
                                             ) : ATreeNode;
VAR
    TaskFilter              :   ATaskFilterSet;
    TaskNode                :   ATreeNode;
    TaskPtr                 :   ATaskPtr;
    AssignHandle            :   AnExtHandle;
BEGIN

    WITH StatusRptSettingsPtr^ DO
        TaskNode := TaskTree^.Methods^.GetFirstVisible(TaskTree);
        WHILE (TaskNode <> NIL) DO
            TaskFilter := TaskFiltersPassed( TaskNode );
            IF (Selected IN TaskFilter ) THEN
                AssignMatch := FALSE;
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
                IF ( FormPrintsPtr^.ShowCurrentAsgnment ) THEN
                    AssignHandle := TaskPtr^.Plan.Assignments;
                ELSE
                    AssignHandle := TaskPtr^.BaseLine.Assignments;
                END;
                ForEachAssignment( AssignHandle,
                                   AssignmentsMatch, StatusRptSettingsPtr);
                TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                TaskPtr := NIL;      (* SAFETY!!! *)
                IF ( AssignMatch ) THEN
                    RETURN TaskNode;
                END
            END;
            TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode);
        END;
    END;
    RETURN TaskNode;
END GetFirstStatusReportForEachResource;




(****************************************************************************
    GetNextStatusReportForEachResource  -
        Return next task.  Use NextPreOrder to traverse the task tree.
****************************************************************************)
PROCEDURE GetNextStatusReportForEachResource( StatusRptSettingsPtr : AStatusReportSettingsPtr
                                             ) : ATreeNode;
VAR
    TaskFilter              :   ATaskFilterSet;
    TaskNode                :   ATreeNode;
    TaskPtr                 :   ATaskPtr;
    AssignHandle            :   AnExtHandle;
BEGIN

    WITH StatusRptSettingsPtr^ DO
        TaskNode := TaskTreeNode^.Methods^.NextPreOrder(TaskTreeNode);
        WHILE (TaskNode <> NIL) DO
            TaskFilter := TaskFiltersPassed( TaskNode );
            IF (Selected IN TaskFilter ) THEN
                AssignMatch := FALSE;
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
                IF ( FormPrintsPtr^.ShowCurrentAsgnment ) THEN
                    AssignHandle := TaskPtr^.Plan.Assignments;
                ELSE
                    AssignHandle := TaskPtr^.BaseLine.Assignments;
                END;
                ForEachAssignment( AssignHandle,
                                   AssignmentsMatch, StatusRptSettingsPtr);
                TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
                TaskPtr := NIL;      (* SAFETY!!! *)
                IF ( AssignMatch ) THEN
                    RETURN TaskNode;
                END
            END;
            TaskNode := TaskNode^.Methods^.NextPreOrder(TaskNode);
        END;
    END;
    RETURN TaskNode;
END GetNextStatusReportForEachResource;




(****************************************************************************
    PrintResourceStatus -
        Print report for each resource.
****************************************************************************)
PROCEDURE PrintResourceStatus(
                                    VAR ResourceNode : ATreeNode;
                                  StatusRptSettingsP : ADDRESS
                                 );
VAR
    StatusRptSettingsPtr    :   AStatusReportSettingsPtr;
    RsrcFilter              :   ATaskFilterSet;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    StatusRptSettingsPtr := StatusRptSettingsP;
    StatusRptSettingsPtr^.RsrcNode := ResourceNode;
    StatusRptSettingsPtr^.ResourcePtr :=
                           ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF ( ( StatusRptSettingsPtr^.FormInputsPtr^.WhatToShow = ShowResources )
           AND
         ( StatusRptSettingsPtr^.ResourcePtr^.Type <> Employable ) ) THEN
        RETURN;
    END;

    RsrcFilter := ResourceFiltersPassed( ResourceNode );

    IF (NOT ( Selected IN RsrcFilter )) THEN RETURN; END;

    StatusRptSettingsPtr^.FormPrintsPtr^.RsrcTitle := TRUE;

    PrintReport( StatusRptSettingsPtr^ );

    IF ( NOT StatusRptSettingsPtr^.EmptyReport ) THEN
        StatusRptSettingsPtr^.ResourceReported := TRUE;
    END;

END PrintResourceStatus;




(****************************************************************************
    PrintEachResourceStatus -
        Travese all resouce node in resource tree and print its status.
****************************************************************************)
PROCEDURE PrintEachResourceStatus( VAR StatusRptSettings : AStatusReportSettings
                                 );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH StatusRptSettings DO
     WITH StatusRptSettings.FormPrintsPtr^ DO
        EmptyReport := TRUE;
        ResourceReported := FALSE;
        GetFirstStatusTask := GetFirstStatusReportForEachResource;
        GetNextStatusTask := GetNextStatusReportForEachResource;
        PageHeaderOn := TRUE;
        AtTopOfPage := TRUE;
        ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild,
                                                   9999, PrintResourceStatus,
                                                   ADR( StatusRptSettings) );
        IF ( NOT ResourceReported ) THEN
            GetMessage ( ModuleNumber + 33, Line );
            Error( Line );
        END;
     END;
    END;
END PrintEachResourceStatus;

(******* For Each Resource end here ***************************************)




(******* For Tasks start here ********************************************)

(****************************************************************************
    GetFirstStatusReportForTasks -
        Return first task.  Use GetFirstVisible to traverse the task tree.
****************************************************************************)
PROCEDURE GetFirstStatusReportForTasks( StatusRptSettingsPtr : AStatusReportSettingsPtr
                                      ) : ATreeNode;
BEGIN
    RETURN TaskTree^.Methods^.GetFirstVisible(TaskTree);
END GetFirstStatusReportForTasks;




(****************************************************************************
    GetNextStatusReportForTasks -
        Return next task.  Use NextForDisplay to traverse the task tree.
****************************************************************************)
PROCEDURE GetNextStatusReportForTasks( StatusRptSettingsPtr : AStatusReportSettingsPtr
                                     ) : ATreeNode;
VAR
    TaskNode                :   ATreeNode;
BEGIN
    TaskNode := StatusRptSettingsPtr^.TaskTreeNode;
    RETURN TaskNode^.Methods^.NextForDisplay(TaskNode);
END GetNextStatusReportForTasks;




PROCEDURE PrintTasksStatus( VAR StatusRptSettings : AStatusReportSettings );
BEGIN
    WITH StatusRptSettings DO
        GetFirstStatusTask := GetFirstStatusReportForTasks;
        GetNextStatusTask := GetNextStatusReportForTasks;
        PrintReport(StatusRptSettings);
    END;
END PrintTasksStatus;

(******* For Tasks end here *******************************************)




PROCEDURE PrintAllStatus(
                         InputsPtr : AStatusFormInputValuesPtr;
                         PrintsPtr : AStatusReportPrintControlsPtr
                        );
VAR
    StatusRptSettings       :   AStatusReportSettings;
BEGIN
    WITH StatusRptSettings DO
        FormInputsPtr := InputsPtr;
        FormPrintsPtr := PrintsPtr;
        AllowUnlimitedPageLength(
                NOT PageBreaksEnable(FormInputsPtr^.StatusPageCtrl));

        IF (FormInputsPtr^.HowToReport = TasksStatus) THEN
            PrintTasksStatus( StatusRptSettings );
        ELSE
            PrintEachResourceStatus( StatusRptSettings ) ;
        END;
    END;
END PrintAllStatus;




(****************************************************************************
    AdjustColumnWidth -
        Adjust all column widths which are greater than the print page width.
****************************************************************************)
PROCEDURE AdjustColumnWidth(
                            InputsPtr : AStatusFormInputValuesPtr;
                            PrintsPtr : AStatusReportPrintControlsPtr
                           );
VAR
    Width                   :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    ColumnTooWide           :   BOOLEAN;
    i                       :   CARDINAL;
BEGIN

    Width := PrintsPtr^.PrintPageWidth;
    ColumnTooWide := FALSE;

    FOR i := 0 TO LASTTASKINFO DO
        IF ( ( InputsPtr^.TaskColumn[i].ColumnWidth + NSpcsBetweenFld )
                                                                > Width ) THEN
            InputsPtr^.TaskColumn[i].ColumnWidth := Width - NSpcsBetweenFld;
            ColumnTooWide := TRUE;
        END;
    END;

    FOR i := 0 TO LASTASSIGNINFO DO
        IF ( ( InputsPtr^.AssignColumn[i].ColumnWidth + NSpcsBetweenFld )
                                                                > Width ) THEN
            InputsPtr^.AssignColumn[i].ColumnWidth := Width - NSpcsBetweenFld;
            ColumnTooWide := TRUE;
        END;
    END;

    IF ( ColumnTooWide ) THEN
        GetMessage(ModuleNumber + 29 , Line); (* Column too wide to fit on one page.Column too wide to fit on one page. *)
        Error( Line );
    END;

END AdjustColumnWidth;




PROCEDURE SetPrintControls(
                           FormInputsPtr : AStatusFormInputValuesPtr;
                           FormPrintsPtr : AStatusReportPrintControlsPtr
                          );
BEGIN
    FormPrintsPtr^.PrintPageWidth := PageWidth();
    FormPrintsPtr^.PrintHeadPos := 0;
    FormPrintsPtr^.PrintAttribute := Normal;
    FormPrintsPtr^.RsrcTitle := FALSE;
    FormPrintsPtr^.OneTaskPerPage :=
          IsOneTaskOrResourcePerPage( FormInputsPtr^.StatusPageCtrl );
    IF ( UnlimitedPageWidth(FormInputsPtr^.StatusPageCtrl)
            AND
        (PrintCB.Style = OutToDisk) ) THEN
        FormPrintsPtr^.PrintPageWidth := MaxPrintWidth;
    END;
    IF ( FormInputsPtr^.AssignColumn[0].ColumnID < BsLnBillable ) THEN
        FormPrintsPtr^.ShowBaselineAsgnment := FALSE;
        FormPrintsPtr^.ShowCurrentAsgnment  := TRUE;
    ELSE
        FormPrintsPtr^.ShowBaselineAsgnment := TRUE;
        FormPrintsPtr^.ShowCurrentAsgnment  := FALSE;
    END;
END SetPrintControls;




PROCEDURE StartStatusReport(VAR Inputs : AStatusFormInputValues);
VAR
    PrintControls           :   AStatusReportPrintControls;
BEGIN
    IF (NOT StartReport()) THEN RETURN; END;
    SetPrintControls( ADR(Inputs), ADR(PrintControls) );
    AdjustColumnWidth(ADR(Inputs), ADR(PrintControls));
    AllowLeftMargin(TRUE);
    PrintAllStatus(ADR(Inputs), ADR(PrintControls));
    EndReport();
END StartStatusReport;




(****************************************************************************
    GetStatusSettings  -
        Retreive the old settings for AStatusFormInputValues.
        If we can not retrieve the old settings then allocate storage
        for the settings and initialize all variable in the settings.
****************************************************************************)
PROCEDURE GetStatusSettings(
                            VAR Inputs : AStatusFormInputValues
                           ) : BOOLEAN;
VAR
    Handle                  :   AnExtHandle;
    A                       :   ADDRESS;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;
    S                       :   ARRAY [0..255] OF CHAR;
    Ok                      :   BOOLEAN;
BEGIN

    SetString(S, "TLSR");
    Class := 1;
    Ok    := (
                ( LocateHeldItem(S, Class, Category, A, Size) )
                 AND
                (Size = TSIZE(AStatusFormInputValues) )
             );
    IF ( Ok ) THEN
        Handle := AnExtHandle(A);
        Ok := (GetExtData(Handle, ADR(Inputs) ) = Size);
    END;

    IF NOT Ok THEN
        GetMessage(ModuleNumber+1, S);
        Error(S);
    END;

    RETURN Ok AND Inputs.ReturnOK;

END GetStatusSettings;




PROCEDURE DoStatusReport();
VAR
    FormInputs              :   AStatusFormInputValues;
    Copyright               :   ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF ( GetStatusSettings(FormInputs) ) THEN
        StartStatusReport(FormInputs);
    END;

END DoStatusReport;

BEGIN
    DoStatusReport();
END TLSR.


