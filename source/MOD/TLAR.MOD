MODULE TLAR;     (*  TimeLine Assignments Report   *)
(*
        MODIFICATION History -

        06-APR-89 KKC First version
        03-May-89 KKC - Checking for employable if resource only.
        08-May-89 KKC - Update pagenumber even Page Footer is off.
        19-May-89 KKC - Add One Task Per Page Option
        26-May-89 KKC - Highlight field for picking list.
                      - Add 'A' or 'An' in front of each type name.
                      - Display picking lists in different position.
                      - Update column id if user used delete key to
                        delete part of the column name.
                      - beep if user presses F2 in fields that don't have
                        a picking list.
                      - Display error when column width greater than 255
        05-Jun-89 KKC - Remove all blank columns by shift all non blank
                        columns upward.
        06-Jun-89 KKC - Print Select filter and highlight filters.
        08-Jun-89 KKC - Print out blank lines for report header after strip 1
                        if report header is suppressed.
        12-Jun-89 KKC - Split tlar.ovl into tlar.ovl and tlaroptn.ovl
        16-Jun-89 KKC - If no data have been printed, do not print the page
                        number.
        26-Jun-89 KKC - Take out the call statement to TLAROPTN.  Use
                        LocateHeldItem to get data from TLAROPTN.
        13-Jul-89 KKC - Return TRUE in PrintColumnNamesAndDataByResource so
                        that it will be called by each assignment for given
                        task.
        10-Aug-89 KKC - Add copyright message.
                      - Pass Pointer instead of address.
        11-Aug-89 KKC - Add three blank lines between procedures.
        06-Oct-89 KKC - Print Blank headers on begin of second strip.
        20-Oct-89 KKC - Disallow user from mixing baseline assignments and
                        current assignments.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
        23-Jan-91 RSC   Put Holder items in FlexStor.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
        2-Jul-91  AJL - Added parameters to FilterNotes.
         3-Jul-91 EGK   Optimized usage of stack space by creating a sub-
                        procedure for PrintGroupByTaskAssignment, and
                        removing unused local variables from
                        CheckOneTaskAgainstResources.
        19-Dec-91 TGS   Bug 5379: select filter on task info didn't have any
                        effect if grouping by Resource.  Now a task must be
                        Selected in order to have its assignment appear.
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskFilter, ATaskFilterSet, ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM AssFormat              IMPORT
    (* VAR   *) (* PROC *)      GetAssString, GetAssInfo;

FROM Assignments            IMPORT
    (* PROC  *)                 ForEachAssignment,
    (* TYPE  *)                 AnAssignmentRecord, AnAssignmentArray;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
    (* VAR   *) (* PROC *)      GetColumnString, GetColumnInfo;

FROM Dialog                 IMPORT
    (* PROC  *)                 Error, Burp, FatalError;

FROM Filter1                IMPORT
    (* PROC  *)                 ResourceFiltersPassed, TaskFiltersPassed;

FROM FlexStor               IMPORT
    (* PROC  *)                 LockObjectArray, ReleaseUnchangedObject,
                                GetExtData,
    (* TYPE  *)                 AnExtHandle;

FROM Gantt                  IMPORT
    (* TYPE  *)                 AGanttLineType;

FROM Holder                 IMPORT
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, StoC, TrimFront, Copy, Fill,
                                Procustes, ConcatLS, SetLengthOf, SubStr,
                                Search, TrimRear, SetString;

FROM MagicNum               IMPORT
    (* CONST *)                 BsLnBillable;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage, ConcatMessage;

FROM PageRepeat             IMPORT
    (* TYPE  *)                 APageRepeatSettings,
    (* PROC  *)                 InitPageRepeatSettings,
                                IgnoreLeftMargin, PageBreaksEnable,
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
    (* VAR   *) (* PROC *)      GetRsrcString, GetRsrcInfo;

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
    (* VAR *)                   DefaultDateFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle;

FROM Timei                  IMPORT
    (* TYPE  *)                 ADate, ATimeInfo,
    (* CONST *)                 MinDate, MaxDate,
    (* PROC  *)                 TimeUtoT;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder;

CONST
    ModuleNumber        =   29400;
    MaxWidth            =   255;
    Normal              =   0;
    Bold                =   1;

    LASTTASKINFO        =   4;    (* (LASTTASKFLD - LASTTASKFLD + 1) /2 - 1 = 4 *)
    LASTRESOURCEINFO    =   3;    (* (LASTRESOURCEFLD - LASTRESOURCEFLD + 1) /2 - 1 = 3 *)
    LASTASSIGNINFO      =   9;    (* (LASTASSIGNFLD - LASTASSIGNFLD + 1) /2 - 1 = 9 *)

    NSpcsBetweenFld     =   2;
    NBottomRowsReserved =   2;

    MaxPrintWidth       =   255;

TYPE

    AColumnStringValue  =   ARRAY[0..80] OF CHAR;

    AGroupMethod        =   (ByTasks, ByResources);
    AShowMethod         =   (ShowResources, ShowResourcesAndCosts);

    AColumnInfo         =   RECORD
        ColumnName          :   AColumnStringValue;
        ColumnWidth         :   CARDINAL;
        ColumnID            :   CARDINAL;
        IsBlankColumn       :   BOOLEAN;
    END;

    ADateInfo           =   RECORD
        DateString          :   AColumnStringValue;
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

    AColumnPrintStatus  =   (NotPrintYet, PrintActive, PrintFinish);
    AnAssignReportPrintControls =   RECORD
        PrintPageWidth      :   CARDINAL;
        ReportPageNumber    :   CARDINAL;
        StripNumber         :   CARDINAL;
        PrintHeadPos        :   CARDINAL;
        OneTaskPerPage      :   BOOLEAN;
        AtTopOfPage         :   BOOLEAN;
        OnlyOneStrip        :   BOOLEAN;
        PageHeaderOn        :   BOOLEAN;
        BlankHeaderOn       :   BOOLEAN;
        PageFooterOn        :   BOOLEAN;
        PrintDateRange      :   BOOLEAN;
        PrintAttribute      :   CARDINAL;
        PrintTitle          :   BOOLEAN;
        PrintTaskColumnData :   BOOLEAN;
        PrintRsrcColumnData :   BOOLEAN;
        TaskStart           :   CARDINAL;
        NextTaskStart       :   CARDINAL;
        TaskPrintStatus     :   AColumnPrintStatus;
        ResourceStart       :   CARDINAL;
        NextRsrcStart       :   CARDINAL;
        RsrcPrintStatus     :   AColumnPrintStatus;
        AssignStart         :   CARDINAL;
        NextAssignStart     :   CARDINAL;
        AssignPrintStatus   :   AColumnPrintStatus;
        EndPageHeaderPos    :   CARDINAL;
        ShowBaselineAsgnment:   BOOLEAN;
        ShowCurrentAsgnment :   BOOLEAN;
    END;

    AnAssignReportPrintControlsPtr  = POINTER TO AnAssignReportPrintControls;

    AnAssignReportSettings  =   RECORD
        FormInputs          :   AnAssignFormInputValues;
        FormPrints          :   AnAssignReportPrintControls;
        TaskTreeNode        :   ATreeNode;
        TaskPointer         :   ATaskPtr;
        RsrcNode            :   ATreeNode;
        ResourcePtr         :   AResourcePointer;
        AssignRecord        :   POINTER TO AnAssignmentRecord;
        AssignMatch         :   BOOLEAN;
        EmptyReport         :   BOOLEAN;
        NoAssignments       :   BOOLEAN;
    END;

    AnAssignReportSettingsPtr   =   POINTER TO AnAssignReportSettings;

    AGetColumnDataProc  =   PROCEDURE(VAR AnAssignReportSettings, CARDINAL,
                                      VAR ARRAY OF CHAR);

    AGetColumnNameProc  =   PROCEDURE(VAR AnAssignReportSettings, CARDINAL,
                                      VAR ARRAY OF CHAR,
                                      VAR ARRAY OF CHAR);

(**Begin**** Get a node from node pointer, this may be deleted later  *****)

MODULE RsrcNode;

    IMPORT  AResourcePointer, ResourceTree, ADDRESS, ADR, TSIZE,
            ATreeNode, ATreeOrder, FatalError;

    EXPORT  GetResourceNodeFromPointer;




(****************************************************************************
    GetResourceNodeFromPointer  -
        Given a resource pointer, returns a resource node.
****************************************************************************)
PROCEDURE GetResourceNodeFromPointer(Resource : AResourcePointer) : ATreeNode;
VAR
    RsrcNode                :   ATreeNode;
BEGIN
    RsrcNode := ResourceTree^.Methods^.GetFirst(ResourceTree);
    WHILE ( RsrcNode <> NIL ) DO
        IF ( RsrcNode^.Methods^.GetDataObject( RsrcNode ) = Resource ) THEN
            RETURN RsrcNode;
        END;
        RsrcNode := RsrcNode^.Methods^.GetNext(RsrcNode);
    END;
    FatalError();
END GetResourceNodeFromPointer;
END RsrcNode;

(** End **** Get a node from node pointer, this may be deleted later  *****)




(********* Used both by GroupbyTask and GroupByResource start here *******)

PROCEDURE PrintStripAndPageNumber(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                 );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH AssignRprtSettings.FormPrints DO
        INC(ReportPageNumber);
        IF ( PageFooterOn ) THEN
            GetMessage(ModuleNumber + 5, Line); (* TIME LINE Assignments Report Page *)
            PrintText(Line, Normal);
            CtoS(ReportPageNumber, Line);
            PrintText(Line, Normal);
            IF ( NOT OnlyOneStrip ) THEN
                GetMessage(ModuleNumber + 13, Line); (*  strip  *)
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
    PrintAssignmentreportFooter -
        Print out all footer information ( only strip and page number for now)
    Set up the flag for report header. Set at topofpage flag to true;
****************************************************************************)
PROCEDURE PrintAssignmentReportFooter( VAR AssignRprtSettings : AnAssignReportSettings
                                     );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    WITH AssignRprtSettings.FormPrints DO
     WITH AssignRprtSettings.FormInputs DO
        SetLengthOf(NoCharBuffer, 0);
        PrintLine( NoCharBuffer, Normal );
        PrintStripAndPageNumber( AssignRprtSettings );
        AtTopOfPage := TRUE;
        PageHeaderOn := RepeatPageHeadings(AssignPageCtrl);
        PrintDateRange := TRUE;
     END;
    END;
END PrintAssignmentReportFooter;




(****************************************************************************
    PrintAssignmentreportHeader -
        Print out all headerer information;
    Set at topofpage flag to false;
****************************************************************************)
PROCEDURE PrintAssignmentReportHeader(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                     );
BEGIN
    PageHead();
    FilterNotes(TRUE,    (* Select Filters *)
                TRUE);   (* Highlight Filters *)
    AssignRprtSettings.FormPrints.AtTopOfPage := FALSE;
    AssignRprtSettings.FormPrints.EndPageHeaderPos :=
                                                         GetCurrentPrintRow();
END PrintAssignmentReportHeader;




(****************************************************************************
    PrintBlankHeader   -
        Print out numbers of blank lines so that all strips' positions match.
        It does not use PrintALine or PrintBlanklines because we want to
        print all these blank lines before we print out other data.  That
        means we have to ignore all the flags that will be used in PrintALine
        and PrintBlankLine.
****************************************************************************)
PROCEDURE PrintBlankHeader(
                           VAR AssignRprtSettings : AnAssignReportSettings
                          );
VAR
    i                       :   CARDINAL;
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    StartPage();
    SetLengthOf( NoCharBuffer, 0 );
    i := GetCurrentPrintRow();
    WHILE ( i < AssignRprtSettings.FormPrints.EndPageHeaderPos ) DO
        PrintLine( NoCharBuffer, Normal );
        INC( i );
    END;
END PrintBlankHeader;




(****************************************************************************
    MovePrintHeadToPageEnd  -
        Force the print head to end of page by sending blank lines to
    the printer.  It will not print on the reserved area on the bottom.
****************************************************************************)
PROCEDURE MovePrintHeadToPageEnd( VAR AssignRprtSettings : AnAssignReportSettings
                                );
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
    i                       :   CARDINAL;
BEGIN
    WITH AssignRprtSettings DO
        SetLengthOf(NoCharBuffer, 0);

        IF ( PageBreaksEnable(
              AssignRprtSettings.FormInputs.AssignPageCtrl
                                                                      ) ) THEN
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
PROCEDURE MovePrintHeadToPageEndIfNeeded(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                        );
VAR
    i                       :   CARDINAL;
BEGIN
    IF ( AssignRprtSettings.FormPrints.OneTaskPerPage
        AND
         NOT AssignRprtSettings.EmptyReport ) THEN
        MovePrintHeadToPageEnd( AssignRprtSettings );
    END;
END MovePrintHeadToPageEndIfNeeded;




(****************************************************************************
    NPrintRowsOnCurrentPage  -
        Make sure we can print n lines onto the same page.
****************************************************************************)
PROCEDURE NPrintRowsOnCurrentPage( 
                            VAR AssignRprtSettings : AnAssignReportSettings;
                                                 n : CARDINAL
                                 ) : BOOLEAN;
VAR
    i                       :   CARDINAL;
BEGIN

    IF ( NOT PageBreaksEnable(
           AssignRprtSettings.FormInputs.AssignPageCtrl ) ) THEN
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
PROCEDURE PrintALine(
                 VAR AssignRprtSettings : AnAssignReportSettings;
                              VAR Line : ARRAY OF CHAR;
                             PrintMode : CARDINAL
                    );
VAR
    Line2                   :   ARRAY [0..MaxWidth] OF CHAR;
    TimeInfo                :   ATimeInfo;
BEGIN

    WITH AssignRprtSettings.FormInputs DO
     WITH AssignRprtSettings.FormPrints DO
        AtTopOfPage := FALSE;
        IF ( RowsLeft() = NBottomRowsReserved ) THEN
            PrintAssignmentReportFooter( AssignRprtSettings );
        END;
        IF ( PageHeaderOn ) THEN
            PageHeaderOn := FALSE;
            PrintAssignmentReportHeader( AssignRprtSettings );
        ELSIF ( BlankHeaderOn ) THEN
            BlankHeaderOn := FALSE;
            PrintBlankHeader( AssignRprtSettings );
        END;
        IF ( PrintDateRange ) THEN
            PrintDateRange :=  FALSE;
            IF ( ( EndingDate.DateValue <> MaxDate )
                 OR
                 ( StartingDate.DateValue <> MinDate ) ) THEN

                GetMessage( ModuleNumber + 16, Line2 ); (* Assignment Report *)
                PrintText( Line2, Normal );
                IF (StartingDate.DateValue <> MinDate ) THEN
                    GetMessage ( ModuleNumber + 17, Line2 ); (*  from  *)
                    PrintText( Line2, Normal );
                    TimeUtoT (StartingDate.DateValue, TimeInfo);
                    TimeToString( TimeInfo, DefaultDateFormat, Line2 );
                    PrintText( Line2, Normal );
                END;
                IF (EndingDate.DateValue <> MaxDate ) THEN
                    GetMessage ( ModuleNumber + 18, Line2 ); (* through *)
                    PrintText( Line2, Normal );
                    TimeAsEndDateStyle
                    (
                        EndingDate.DateValue,
                        EndDateStyle,
                        TimeInfo
                    );
                    TimeToString( TimeInfo, DefaultDateFormat, Line2 );
                    PrintText( Line2, Normal );
                END;
                SetLengthOf( Line2, 0 );
                PrintLine( Line2, Normal );
                Fill(Line2, 'Ä', PrintPageWidth);
                PrintLine( Line2, Normal );
                SetLengthOf( Line2, 0 );
                PrintLine( Line2, Normal );
            END;
        END;
        PrintLine(Line, PrintMode);
     END;
    END;
END PrintALine;




PROCEDURE PrintBlankLine( VAR AssignRprtSettings : AnAssignReportSettings);
VAR
    NoCharBuffer            :   ARRAY[0..0] OF CHAR;
BEGIN
    SetLengthOf(NoCharBuffer, 0);
    PrintALine(AssignRprtSettings, NoCharBuffer, Normal);
END PrintBlankLine;




(****************************************************************************
    AppendColumnDataToOneLine -
            Get the data for each column.  For blank columns, a full column width
    of underscore characters will be printed.
        Since Tasks, Resources and Assignements require different method to
    get data from it, a procedure is passed to here to getting the data.

****************************************************************************)
PROCEDURE AppendColumnDataToOneLine(
                                   VAR ColumnInfo : ARRAY OF AColumnInfo;
                                 start, nextstart : CARDINAL;
                                      PrintStatus : AColumnPrintStatus;
                                    GetColumnData : AGetColumnDataProc;
                            VAR AssignRprtSettings: AnAssignReportSettings;
                                  VAR PrintBuffer : ARRAY OF CHAR
                                   );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    i                       :   CARDINAL;
BEGIN
    IF ( PrintStatus <> PrintActive ) THEN RETURN; END;
    FOR  i := start TO nextstart - 1 DO
        IF (ColumnInfo[i].ColumnWidth <> 0) THEN
            IF (ColumnInfo[i].IsBlankColumn) THEN
                Fill(Line, '_', ColumnInfo[i].ColumnWidth);
            ELSE
                GetColumnData(AssignRprtSettings, i, Line);
                Procustes(Line, ColumnInfo[i].ColumnWidth);
            END;
            ConcatLS(PrintBuffer, Line);
            Fill(Line, ' ', NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
        END;
    END;
END AppendColumnDataToOneLine;




(****************************************************************************
    AppendBlankDataToOneLine -
            Get the data for each column.  For blank columns, a full column width
    of underscore characters will be printed.
        Since Tasks, Resources and Assignements require different method to
    get data from it, a procedure is passed to here to getting the data.

****************************************************************************)
PROCEDURE AppendBlankDataToOneLine(
                                   VAR ColumnInfo : ARRAY OF AColumnInfo;
                                 start, nextstart : CARDINAL;
                                      PrintStatus : AColumnPrintStatus;
                            VAR AssignRprtSettings: AnAssignReportSettings;
                                  VAR PrintBuffer : ARRAY OF CHAR
                                   );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    i                       :   CARDINAL;
BEGIN
    IF ( PrintStatus <> PrintActive ) THEN RETURN; END;
    FOR  i := start TO nextstart - 1 DO
        IF (ColumnInfo[i].ColumnWidth <> 0) THEN
            Fill(Line, ' ', ColumnInfo[i].ColumnWidth + NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
        END;
    END;
END AppendBlankDataToOneLine;




(****************************************************************************
    AppendColumnNameToTwoLine -
        Get the name for each column. These are the names which user enter
    into the form.
****************************************************************************)
PROCEDURE AppendColumnNameToTwoLine(
                                   VAR ColumnInfo : ARRAY OF AColumnInfo;
                                 start, nextstart : CARDINAL;
                                      PrintStatus : AColumnPrintStatus;
                                    GetColumnName : AGetColumnNameProc;
                            VAR AssignRprtSettings: AnAssignReportSettings;
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
            GetColumnName(AssignRprtSettings, i, Line, Line2);
            ConcatLS(PrintBuffer, Line);
            ConcatLS(PrintBuffer2, Line2);
            Fill(Line, ' ', NSpcsBetweenFld);
            ConcatLS(PrintBuffer, Line);
            ConcatLS(PrintBuffer2, Line);
        END;
    END;
END AppendColumnNameToTwoLine;




(****************************************************************************
    AppendColumnSeparatorsToOneLine -
        Get a full column width of '-' characters to separate the column
    name and data.
****************************************************************************)
PROCEDURE AppendColumnSeparatorsToOneLine(
                                          VAR ColumnInfo : ARRAY OF AColumnInfo;
                                        start, nextstart : CARDINAL;
                                             PrintStatus : AColumnPrintStatus;
                                         VAR PrintBuffer : ARRAY OF CHAR
                                         );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    i                       :   CARDINAL;
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
END AppendColumnSeparatorsToOneLine;




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
        INC(i);
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
    MoreAssignToPrint -
        If more assignments to be printed return TRUE, otherwise return FALSE.
****************************************************************************)
PROCEDURE MoreAssignToPrint(
                            VAR AssignRprtSettings : AnAssignReportSettings
                           ) : BOOLEAN;
BEGIN

    WITH AssignRprtSettings.FormPrints DO
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
    FindStartAndNextStartAssignColumn -
        Find the number of assignments columns to be printed by finding the
    next starting column and the current starting column.
****************************************************************************)
PROCEDURE FindStartAndNextStartAssignColumn(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                           );
VAR
    NPrintSpcLeft           :   CARDINAL;
BEGIN

    WITH AssignRprtSettings.FormPrints DO

        IF (PrintHeadPos = PrintPageWidth ) THEN RETURN; END;

        IF ( NOT FindStartAndNextStartColumn(AssignStart, NextAssignStart,
                          AssignPrintStatus, PrintPageWidth, PrintHeadPos,
                          NPrintSpcLeft,
                          AssignRprtSettings.FormInputs.AssignColumn,
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
    MoreResourceToPrint -
        If more Resources to be printed, return TRUE, otherwise return FALSE.
****************************************************************************)
PROCEDURE MoreResourceToPrint(
                             VAR AssignRprtSettings : AnAssignReportSettings
                             ) : BOOLEAN;
BEGIN

    WITH AssignRprtSettings.FormPrints DO
        IF ( RsrcPrintStatus = PrintFinish ) THEN
            RETURN FALSE;
        END;
        IF ( NextRsrcStart > LASTRESOURCEINFO ) THEN
            RsrcPrintStatus := PrintFinish;
            RETURN FALSE;
        END;
        RETURN TRUE;
    END;

END MoreResourceToPrint;




(****************************************************************************
    FindStartAndNextStartResourceColumn -
        Find the number of resources columns to be printed by finding the
    next starting column and the current starting column.
****************************************************************************)
PROCEDURE FindStartAndNextStartResourceColumn(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                             );
VAR
    NPrintSpcLeft           :   CARDINAL;
BEGIN

    WITH AssignRprtSettings.FormPrints DO

    (* Start at new line if group by resource *)
        IF (AssignRprtSettings.FormInputs.HowToGroup <> ByResources) THEN
            IF (PrintHeadPos = PrintPageWidth ) THEN RETURN; END;
        ELSE
            PrintHeadPos := 0;
        END;

        IF ( NOT FindStartAndNextStartColumn(ResourceStart, NextRsrcStart,
                          RsrcPrintStatus, PrintPageWidth,
                          PrintHeadPos, NPrintSpcLeft,
                          AssignRprtSettings.FormInputs.ResourceColumn,
                          LASTRESOURCEINFO) ) THEN
            RETURN;
        END;

        IF ( NextRsrcStart <= LASTRESOURCEINFO ) THEN
            PrintHeadPos := PrintPageWidth;
            OnlyOneStrip := FALSE;
        ELSE
            PrintHeadPos := PrintPageWidth - NPrintSpcLeft;
        END;
    END;

END FindStartAndNextStartResourceColumn;




(****************************************************************************
    MoreTaskToPrint -
        If more tasks to be printed return TRUE, otherwise return FALSE.
****************************************************************************)
PROCEDURE MoreTaskToPrint(
                          VAR AssignRprtSettings : AnAssignReportSettings
                         ):BOOLEAN;
BEGIN

    WITH AssignRprtSettings.FormPrints DO
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
    FindStartAndNextStartTaskColumn -
        Find the number of task columns to be printed by finding the
    next starting column and the current starting column.
****************************************************************************)
PROCEDURE FindStartAndNextStartTaskColumn(
                             VAR AssignRprtSettings : AnAssignReportSettings
                                         );
VAR
    NPrintSpcLeft           :   CARDINAL;
BEGIN

    WITH AssignRprtSettings.FormPrints DO

    (* Start at new line *)
        IF (AssignRprtSettings.FormInputs.HowToGroup <> ByTasks) THEN
            IF (PrintHeadPos = PrintPageWidth ) THEN RETURN; END;
        ELSE
            PrintHeadPos := 0;
        END;

        IF ( NOT FindStartAndNextStartColumn(TaskStart, NextTaskStart,
                          TaskPrintStatus, PrintPageWidth,
                          PrintHeadPos, NPrintSpcLeft,
                          AssignRprtSettings.FormInputs.TaskColumn,
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




(****************************************************************************
    GetTaskColumnName-
        This procedure calls GetColumnString to get the data for task column.
****************************************************************************)
PROCEDURE GetTaskColumnName(
                VAR AssignRprtSettings : AnAssignReportSettings;
                                Index : CARDINAL;
                            VAR Line1 : ARRAY OF CHAR;
                            VAR Line2 : ARRAY OF CHAR
                           );
VAR
    DataRecord1             :   AColumnDataRecord;
    DataRecord2             :   AColumnDataRecord;
BEGIN
    WITH AssignRprtSettings DO
     WITH AssignRprtSettings.FormInputs DO

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
                          TaskColumn[Index].ColumnID, ColumnNarrowHeading1,
                          maxcol, DataRecord1);
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
    GetResourceColumnName-
        This procedure calls GetColumnString to get the data for resource
    column.
****************************************************************************)
PROCEDURE GetResourceColumnName(
                            VAR AssignRprtSettings : AnAssignReportSettings;
                                            Index : CARDINAL;
                                        VAR Line1 : ARRAY OF CHAR;
                                        VAR Line2 : ARRAY OF CHAR
                               );
VAR
    DataRecord1             :   AColumnDataRecord;
    DataRecord2             :   AColumnDataRecord;
BEGIN

    WITH AssignRprtSettings.FormInputs DO

        IF ( GetRsrcInfo(ResourceColumn[Index].ColumnID,
                        ColumnHeading1, maxcol, DataRecord1) ) THEN
            Copy(DataRecord1.StringValue, Line1);
            TrimFront(Line1);
        END;

        IF ( GetRsrcInfo(ResourceColumn[Index].ColumnID,
                         ColumnHeading2, maxcol, DataRecord2) ) THEN
            Copy(DataRecord2.StringValue, Line2);
            TrimFront(Line2);
        END;

        TrimRear(Line1);
        TrimRear(Line2);

        IF ( (LengthOf(Line1) > ResourceColumn[Index].ColumnWidth)
                OR
              (LengthOf(Line2) > ResourceColumn[Index].ColumnWidth) ) THEN
            IF ( GetRsrcInfo(ResourceColumn[Index].ColumnID,
                         ColumnNarrowHeading1, maxcol, DataRecord1) ) THEN
                Copy(DataRecord1.StringValue, Line1);
                TrimFront(Line1);
            END;

            IF ( GetRsrcInfo(ResourceColumn[Index].ColumnID,
                            ColumnNarrowHeading2, maxcol, DataRecord2) ) THEN
                Copy(DataRecord2.StringValue, Line2);
                TrimFront(Line2);
            END;
        END;
        Procustes(Line1, ResourceColumn[Index].ColumnWidth);
        Procustes(Line2, ResourceColumn[Index].ColumnWidth);
    END;
END GetResourceColumnName;




(****************************************************************************
    GetAssignColumnName-
        This procedure calls GetColumnString to get the data for Assign
    column.
****************************************************************************)
PROCEDURE GetAssignColumnName(
                            VAR AssignRprtSettings: AnAssignReportSettings;
                                            Index : CARDINAL;
                                        VAR Line1 : ARRAY OF CHAR;
                                        VAR Line2 : ARRAY OF CHAR
                             );
VAR
    DataRecord1             :   AColumnDataRecord;
    DataRecord2             :   AColumnDataRecord;
BEGIN

    WITH AssignRprtSettings.FormInputs DO

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
PROCEDURE GetTaskData(
                      VAR AssignRprtSettings : AnAssignReportSettings;
                                       Index : CARDINAL;
                                    VAR Line : ARRAY OF CHAR
                     );
BEGIN

    WITH AssignRprtSettings DO
     WITH AssignRprtSettings.FormInputs DO
        IF ( TaskColumn[Index].ColumnID <> TaskNameColumn ) THEN
            IF ( NOT GetColumnString(TaskTreeNode, TaskPointer,
                                TaskColumn[Index].ColumnID, Plan,
                                TaskColumn[Index].ColumnWidth, Line) ) THEN
(*                GetMessage(ModuleNumber + 2, Line); (* N/A *)*)
                  Fill(Line, ' ', 1);
            END;
        ELSE
            IF ( GetColumnString(TaskTreeNode, TaskPointer,
                                TaskColumn[Index].ColumnID, Plan,
                                MaxWidth, Line) ) THEN
                TrimFront(Line);
            ELSE
(*                GetMessage(ModuleNumber + 2, Line); (* N/A *)*)
                Fill(Line, ' ', 1);
            END;
        END;
     END;
    END;
END GetTaskData;




(****************************************************************************
    GetResourceData -
        This procedure calls GetColumnString to get the data for task column.
****************************************************************************)
PROCEDURE GetResourceData(
                          VAR AssignRprtSettings : AnAssignReportSettings;
                                          Index : CARDINAL;
                                       VAR Line : ARRAY OF CHAR
                         );
VAR
    ResourceNode            :   ATreeNode;
    Resource                :   AResourcePointer;
BEGIN
    ResourceNode := AssignRprtSettings.RsrcNode;
    Resource := AssignRprtSettings.ResourcePtr;

    WITH AssignRprtSettings.FormInputs DO
        IF (NOT GetRsrcString(ResourceNode,
                          ResourceColumn[Index].ColumnID,
                          ResourceColumn[Index].ColumnWidth, Line)) THEN
(*            GetMessage(ModuleNumber + 2, Line);  (* N/A *) *)
            Fill(Line, ' ', 1);
        END;
    END;
END GetResourceData;




(****************************************************************************
    GetAssignData -
        This procedure calls GetAssString to get the data for task column.
****************************************************************************)
PROCEDURE GetAssignData(
                        VAR AssignRprtSettings : AnAssignReportSettings;
                                        Index : CARDINAL;
                                     VAR Line : ARRAY OF CHAR
                       );
BEGIN

    WITH AssignRprtSettings.FormInputs DO
        IF ( NOT GetAssString(AssignRprtSettings.AssignRecord^,
                          AssignRprtSettings.TaskPointer,
                          AssignColumn[Index].ColumnID,
                          AssignColumn[Index].ColumnWidth,
                          Line) ) THEN
(*            GetMessage(ModuleNumber + 2, Line);  (* N/A *) *)
            Fill(Line, ' ', 1);
        END;
    END;
END GetAssignData;

(********* Used both by GroupbyTask and GroupByResource end here *********)




(******************** Group by Resource start here **************************)

PROCEDURE PrintColumnDataByResource(
                              VAR OneResourceManyTasks : AnAssignReportSettings
                                   );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH OneResourceManyTasks.FormInputs DO
     WITH OneResourceManyTasks.FormPrints DO
        SetLengthOf(Line, 0);
        IF ( PrintRsrcColumnData ) THEN
            PrintRsrcColumnData := FALSE;
            AppendColumnDataToOneLine(ResourceColumn, ResourceStart,
                             NextRsrcStart, RsrcPrintStatus, GetResourceData,
                                                  OneResourceManyTasks, Line);
        ELSE
            AppendBlankDataToOneLine(ResourceColumn, ResourceStart,
                                            NextRsrcStart, RsrcPrintStatus,
                                                 OneResourceManyTasks, Line);
        END;
        AppendColumnDataToOneLine(TaskColumn, TaskStart, NextTaskStart,
                   TaskPrintStatus, GetTaskData, OneResourceManyTasks, Line);
        AppendColumnDataToOneLine(AssignColumn, AssignStart, NextAssignStart,
                AssignPrintStatus, GetAssignData, OneResourceManyTasks, Line);
        PrintALine(OneResourceManyTasks, Line, PrintAttribute);

     END;
    END;
END PrintColumnDataByResource;




PROCEDURE PrintColumnNamesByResource(
                              VAR OneResourceManyTasks : AnAssignReportSettings
                                    );
VAR
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH OneResourceManyTasks.FormInputs DO
     WITH OneResourceManyTasks.FormPrints DO
        IF ( NOT NPrintRowsOnCurrentPage(OneResourceManyTasks, 4) ) THEN
           MovePrintHeadToPageEnd(OneResourceManyTasks);
        END;

        SetLengthOf(Line, 0);
        SetLengthOf(Line2, 0);
        AppendColumnNameToTwoLine(ResourceColumn, ResourceStart,
                             NextRsrcStart,
                             RsrcPrintStatus, GetResourceColumnName,
                             OneResourceManyTasks, Line, Line2);
        AppendColumnNameToTwoLine(TaskColumn, TaskStart, NextTaskStart,
                          TaskPrintStatus, GetTaskColumnName,
                          OneResourceManyTasks, Line, Line2);
        AppendColumnNameToTwoLine(AssignColumn, AssignStart,
                          NextAssignStart,
                          AssignPrintStatus, GetAssignColumnName,
                          OneResourceManyTasks, Line, Line2);
        PrintALine(OneResourceManyTasks, Line, Normal);
        PrintALine(OneResourceManyTasks, Line2, Normal);

        SetLengthOf(Line, 0);
        AppendColumnSeparatorsToOneLine(ResourceColumn, ResourceStart,
                                   NextRsrcStart, RsrcPrintStatus, Line);
        AppendColumnSeparatorsToOneLine(TaskColumn, TaskStart,
                                   NextTaskStart, TaskPrintStatus, Line);
        AppendColumnSeparatorsToOneLine(AssignColumn, AssignStart,
                               NextAssignStart, AssignPrintStatus, Line);
        PrintALine(OneResourceManyTasks, Line, Normal);
        PrintTitle := FALSE;
     END;
    END;
END PrintColumnNamesByResource;




(****************************************************************************
    PrintColumnNamesAndDataByResource _
        Print column names, separators and data for resources and assignments
    grouped by resource.
        If prints execess current page length, then start a new page.
****************************************************************************)
PROCEDURE PrintColumnNamesAndDataByResource(
                                          VAR Assignment : AnAssignmentRecord;
                                     AssignRprtSettingsP : ADDRESS
                                           ) : BOOLEAN;
VAR
    OneResourceManyTasks    :   AnAssignReportSettingsPtr;
BEGIN

    IF ( Stopped ) THEN RETURN FALSE; END;

    OneResourceManyTasks  := AssignRprtSettingsP;

    IF ( Assignment.Resource <> OneResourceManyTasks^.ResourcePtr ) THEN
        RETURN TRUE; (* Continue to next item *)
    END;

    OneResourceManyTasks^.AssignMatch := TRUE;
    OneResourceManyTasks^.AssignRecord := ADR(Assignment);

    WITH OneResourceManyTasks^.FormInputs DO
     WITH OneResourceManyTasks^.FormPrints DO
        IF ( NOT NPrintRowsOnCurrentPage(OneResourceManyTasks^, 1) ) THEN
            MovePrintHeadToPageEnd(OneResourceManyTasks^);
            IF ( NOT PrintTitle ) THEN
               PrintTitle := RepeatColumnHeadings( AssignPageCtrl );
            END;
        END;

        IF (PrintTitle ) THEN
            PrintColumnNamesByResource(OneResourceManyTasks^);
        END;
        PrintColumnDataByResource(OneResourceManyTasks^);
     END;
    END;
    RETURN TRUE; (* do not continue *)
END PrintColumnNamesAndDataByResource;




(****************************************************************************
    CheckTaskAgainstOneResource -
        Print out all assignments for a given resource node and task node.
****************************************************************************)
PROCEDURE CheckTaskAgainstOneResource(
                                             VAR TaskNode : ATreeNode;
                                      AssignRprtSettingsP : ADDRESS
                                     );
VAR
    OneResourceManyTasks    :   AnAssignReportSettingsPtr;
    Task                    :   ATaskPtr;
    AssignHandle            :   AnExtHandle;
BEGIN

    IF ( Stopped ) THEN RETURN; END;

    OneResourceManyTasks := AssignRprtSettingsP;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

    WITH OneResourceManyTasks^.FormInputs DO
        IF  ( (Task^.Plan.Dates.EarlyStart > EndingDate.DateValue)
                OR
              (Task^.Plan.Dates.EarlyEnd < StartingDate.DateValue)
               OR (* 19-Dec-91 TGS added this check: *)
              NOT (Selected IN Task^.FilterSet) ) THEN
            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
            Task := NIL;      (* SAFETY!!! *)
            RETURN;
        END;
    END;

    OneResourceManyTasks^.TaskTreeNode := TaskNode;
    OneResourceManyTasks^.TaskPointer := Task;
    OneResourceManyTasks^.AssignMatch := FALSE;


    IF ( OneResourceManyTasks^.FormPrints.ShowCurrentAsgnment ) THEN
        AssignHandle := Task^.Plan.Assignments;
    ELSE
        AssignHandle := Task^.BaseLine.Assignments;
    END;

    ForEachAssignment( AssignHandle,
                          PrintColumnNamesAndDataByResource, OneResourceManyTasks);
    IF ( OneResourceManyTasks^.AssignMatch ) THEN
        OneResourceManyTasks^.NoAssignments := FALSE;
    END;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    Task := NIL;      (* SAFETY!!! *)
END CheckTaskAgainstOneResource;




PROCEDURE PrintNoTaskColumnDataByResource(
                              VAR OneResourceManyTasks : AnAssignReportSettings
                                         );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH OneResourceManyTasks.FormInputs DO
     WITH OneResourceManyTasks.FormPrints DO
        SetLengthOf(Line, 0);
        AppendColumnDataToOneLine(ResourceColumn, ResourceStart,
                         NextRsrcStart, RsrcPrintStatus, GetResourceData,
                                              OneResourceManyTasks, Line);
        IF ( ( TaskPrintStatus = PrintActive ) AND ( TaskStart = 0 ) ) THEN
            ConcatMessage( Line, ModuleNumber + 2 );     (* N/A *)
        END;
        PrintALine(OneResourceManyTasks, Line, PrintAttribute);
     END;
    END;
END PrintNoTaskColumnDataByResource;




(****************************************************************************
    PrintNoTaskByResource _
        Print Resource name and data and an N/A if there are no tasks for
    given resource.
****************************************************************************)
PROCEDURE PrintNoTaskByResource(
                              VAR OneResourceManyTasks : AnAssignReportSettings
                               );
BEGIN

    IF ( Stopped ) THEN RETURN; END;

    WITH OneResourceManyTasks.FormInputs DO
     WITH OneResourceManyTasks.FormPrints DO
        IF ( NOT NPrintRowsOnCurrentPage(OneResourceManyTasks, 1) ) THEN
            MovePrintHeadToPageEnd(OneResourceManyTasks);
            IF ( NOT PrintTitle ) THEN
               PrintTitle := RepeatColumnHeadings(  AssignPageCtrl );
            END;
        END;

        IF (PrintTitle ) THEN
            PrintColumnNamesByResource(OneResourceManyTasks);
        END;
        PrintNoTaskColumnDataByResource(OneResourceManyTasks);
     END;
    END;
END PrintNoTaskByResource;




PROCEDURE CheckOneResourceAgainstTasks(
                                          VAR ResourceNode : ATreeNode;
                                       AssignRprtSettingsP : ADDRESS
                                      );
VAR
    OneResourceManyTasks    :   AnAssignReportSettingsPtr;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    RsrcFilter              :   ATaskFilterSet;
BEGIN

    IF ( Stopped ) THEN RETURN; END;

    OneResourceManyTasks := AssignRprtSettingsP;

    WITH OneResourceManyTasks^ DO
        RsrcNode := ResourceNode;
        ResourcePtr := ResourceNode^.Methods^.GetDataObject( ResourceNode );

        IF ( ( FormInputs.WhatToShow = ShowResources )
               AND
             ( ResourcePtr^.Type <> Employable ) ) THEN RETURN; END;


        RsrcFilter := ResourceFiltersPassed( ResourceNode );

        IF (NOT ( Selected IN RsrcFilter )) THEN RETURN; END;

        IF ( RsrcFilter * ATaskFilterSet{Highlight3..Highlight5} =
                                                      ATaskFilterSet{} ) THEN
            FormPrints.PrintAttribute := Normal;
        ELSE
            FormPrints.PrintAttribute := Bold;
        END;

        EmptyReport := FALSE;
        NoAssignments := TRUE;
        FormPrints.PrintRsrcColumnData := TRUE;

        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild,
                                        9999, CheckTaskAgainstOneResource,
                                        OneResourceManyTasks);

        IF ( NoAssignments ) THEN
            PrintNoTaskByResource(OneResourceManyTasks^);
        END;

(*  If we have less than 2 lines left then there is no need to print a
    blank line                                                          *)

        IF ( NOT NPrintRowsOnCurrentPage(OneResourceManyTasks^, 2) ) THEN
            MovePrintHeadToPageEnd(OneResourceManyTasks^);
            IF ( NOT FormPrints.PrintTitle ) THEN
                FormPrints.PrintTitle :=
                  RepeatColumnHeadings( FormInputs.AssignPageCtrl );
            END;
        ELSE
            PrintBlankLine( OneResourceManyTasks^ );
        END;
    END;
    MovePrintHeadToPageEndIfNeeded(OneResourceManyTasks^);

END CheckOneResourceAgainstTasks;




(****************************************************************************
    PrintGroupByResourceAssignment -
        Print out all tasks and assignments group by resource.  This procedure
    will traverse throught the whole resource tree for each strip of printing.
****************************************************************************)
PROCEDURE PrintGroupByResourceAssignment(
                              VAR OneResourceManyTasks : AnAssignReportSettings
                                        );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN

    WITH OneResourceManyTasks DO
     WITH OneResourceManyTasks.FormPrints DO

        EmptyReport := TRUE;
        AtTopOfPage := TRUE;
        OnlyOneStrip := TRUE;
        StripNumber := 0;

        ResourceStart := 0;
        NextRsrcStart := 0;
        RsrcPrintStatus := NotPrintYet;
        TaskStart := 0;
        NextTaskStart := 0;
        TaskPrintStatus := NotPrintYet;
        AssignStart := 0;
        NextAssignStart := 0;
        AssignPrintStatus := NotPrintYet;
        PageHeaderOn := TRUE;

        REPEAT
            PrintTitle := TRUE;
            PrintDateRange := TRUE;
            PageFooterOn :=
                RepeatPageFootings( FormInputs.AssignPageCtrl );
            INC (StripNumber);
            ReportPageNumber := 0;
            BlankHeaderOn := NOT PageHeaderOn;
            FindStartAndNextStartResourceColumn( OneResourceManyTasks );
            FindStartAndNextStartTaskColumn( OneResourceManyTasks );
            FindStartAndNextStartAssignColumn( OneResourceManyTasks );

            ResourceTree^.Methods^.TraverseTree(ResourceTree,
                                                ParentBeforeChild, 9999,
                                                CheckOneResourceAgainstTasks,
                                                ADR(OneResourceManyTasks));
            IF ( NOT AtTopOfPage ) THEN
                MovePrintHeadToPageEnd( OneResourceManyTasks );
                PageFooterOn := TRUE;
                PrintAssignmentReportFooter( OneResourceManyTasks );
            END;
            AllowLeftMargin(
                NOT IgnoreLeftMargin(FormInputs.AssignPageCtrl));
            IF ( PageBreaksEnable( FormInputs.AssignPageCtrl ) ) THEN
                PrintTitle := TRUE;
            END;
        UNTIL Stopped
                OR
                (
                   NOT MoreResourceToPrint(OneResourceManyTasks)
                      AND
                   NOT MoreTaskToPrint(OneResourceManyTasks)
                      AND
                   NOT MoreAssignToPrint(OneResourceManyTasks)
                );


        IF ( EmptyReport ) THEN
            GetMessage(ModuleNumber + 4, Line); (* Empty Report *)
            PrintALine(OneResourceManyTasks, Line, Normal);
        END;
     END;
    END;
END PrintGroupByResourceAssignment;

(******************** Group by Resource end here **************************)




(******************** Group by task start here **************************)

PROCEDURE PrintColumnDataByTask(
                              VAR OneTaskManyResources : AnAssignReportSettings
                               );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN

    WITH OneTaskManyResources.FormInputs DO
     WITH OneTaskManyResources.FormPrints DO
        SetLengthOf(Line, 0);
        IF ( PrintTaskColumnData ) THEN
            PrintTaskColumnData := FALSE;
            AppendColumnDataToOneLine(TaskColumn, TaskStart,
                                      NextTaskStart,
                                      TaskPrintStatus, GetTaskData,
                                      OneTaskManyResources, Line);
        ELSE
            AppendBlankDataToOneLine(TaskColumn, TaskStart,
                                 NextTaskStart, TaskPrintStatus,
                                      OneTaskManyResources, Line);
        END;
        AppendColumnDataToOneLine(ResourceColumn, ResourceStart,
                                  NextRsrcStart,
                                  RsrcPrintStatus, GetResourceData,
                                  OneTaskManyResources, Line);
        AppendColumnDataToOneLine(AssignColumn, AssignStart,
                                  NextAssignStart,
                                  AssignPrintStatus, GetAssignData,
                                  OneTaskManyResources, Line);
        PrintALine(OneTaskManyResources, Line, PrintAttribute);
     END;
    END;
END PrintColumnDataByTask;




PROCEDURE PrintColumnNamesByTask(
                              VAR OneTaskManyResources : AnAssignReportSettings
                                );
VAR
    Line, Line2             :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN

    WITH OneTaskManyResources.FormInputs DO
     WITH OneTaskManyResources.FormPrints DO

        IF (NOT NPrintRowsOnCurrentPage(OneTaskManyResources,4)) THEN
           MovePrintHeadToPageEnd(OneTaskManyResources);
        END;
        SetLengthOf(Line, 0);
        SetLengthOf(Line2, 0);
        AppendColumnNameToTwoLine(TaskColumn, TaskStart, NextTaskStart,
                      TaskPrintStatus, GetTaskColumnName,
                      OneTaskManyResources, Line, Line2);
        AppendColumnNameToTwoLine(ResourceColumn, ResourceStart,
                       NextRsrcStart, RsrcPrintStatus, GetResourceColumnName,
                       OneTaskManyResources, Line, Line2);
        AppendColumnNameToTwoLine(AssignColumn, AssignStart, NextAssignStart,
                       AssignPrintStatus, GetAssignColumnName,
                       OneTaskManyResources, Line, Line2);
        PrintALine(OneTaskManyResources, Line, Normal);
        PrintALine(OneTaskManyResources, Line2, Normal);

        SetLengthOf(Line, 0);
        AppendColumnSeparatorsToOneLine(TaskColumn, TaskStart,
                          NextTaskStart, TaskPrintStatus, Line);
        AppendColumnSeparatorsToOneLine(ResourceColumn,
                                  ResourceStart, NextRsrcStart,
                                         RsrcPrintStatus, Line);
        AppendColumnSeparatorsToOneLine(AssignColumn,
                                  AssignStart, NextAssignStart,
                                       AssignPrintStatus, Line);
        PrintALine(OneTaskManyResources, Line, Normal);
        PrintTitle := FALSE;
     END;
    END;
END PrintColumnNamesByTask;




(****************************************************************************
    PrintColumnNamesAndDataByTask  -
        Print column names, separators and data for resources and assignments
    grouped by task.
        If prints execess current page length, then start a new page.
****************************************************************************)
PROCEDURE PrintColumnNamesAndDataByTask(
                              VAR OneTaskManyResources : AnAssignReportSettings;
                                      AssignHandle : AnExtHandle
                                       );
VAR
    AssignmentArray         :   AnAssignmentArray;
    i                       :   CARDINAL;
    Count                   :   CARDINAL;
BEGIN

    Count := LockObjectArray( AssignHandle, AssignmentArray,
                                 TSIZE(AnAssignmentRecord));
    IF ( Count = 0 ) THEN
        ReleaseUnchangedObject( AssignHandle );
        AssignHandle := AnExtHandle(NIL); (* Safety !!! *)
        RETURN;
    END;

    WITH OneTaskManyResources DO

        WITH OneTaskManyResources.FormInputs DO
         WITH OneTaskManyResources.FormPrints DO

            FOR i := 0 TO Count - 1 DO

                IF ( ( WhatToShow <> ShowResources )
                       OR
                   ( AssignmentArray^[ i ].Resource^.Type = Employable ) )
                THEN
                   NoAssignments := FALSE;
                   ResourcePtr := AssignmentArray^[ i ].Resource;
                   RsrcNode := GetResourceNodeFromPointer(ResourcePtr);
                   AssignRecord := ADR(AssignmentArray^[ i ]);
                   IF ( NOT NPrintRowsOnCurrentPage(OneTaskManyResources, 1) )
                   THEN
                      MovePrintHeadToPageEnd(OneTaskManyResources);
                      IF ( NOT PrintTitle ) THEN
                         PrintTitle :=
                                 RepeatColumnHeadings( AssignPageCtrl );
                      END;
                   END;
                   IF ( PrintTitle ) THEN
                      PrintColumnNamesByTask(OneTaskManyResources);
                   END;
                   PrintColumnDataByTask(OneTaskManyResources);
                END;
            END;
         END;
        END;
    END;
    ReleaseUnchangedObject( AssignHandle );
    AssignHandle := AnExtHandle(NIL); (* Safety !!! *)

END PrintColumnNamesAndDataByTask;




PROCEDURE PrintNoResourceColumnDataByTask(
                              VAR OneTaskManyResources : AnAssignReportSettings
                                         );
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    WITH OneTaskManyResources.FormInputs DO
     WITH OneTaskManyResources.FormPrints DO
        SetLengthOf(Line, 0);
        AppendColumnDataToOneLine(TaskColumn, TaskStart,
                         NextTaskStart, TaskPrintStatus, GetTaskData,
                                              OneTaskManyResources, Line);
        IF ( ( RsrcPrintStatus = PrintActive ) AND ( ResourceStart = 0 ) ) THEN
            ConcatMessage( Line, ModuleNumber + 2 );     (* N/A *)
        END;
        PrintALine(OneTaskManyResources, Line, PrintAttribute);
     END;
    END;
END PrintNoResourceColumnDataByTask;




(****************************************************************************
    PrintNoResourceByTask   -
        Print column names, separators and data for resources and assignments
    grouped by resource.
        If prints execess current page length, then start a new page.
****************************************************************************)
PROCEDURE PrintNoResourceByTask(
                              VAR OneTaskManyResources : AnAssignReportSettings
                               );
BEGIN

    IF ( Stopped ) THEN RETURN; END;

    WITH OneTaskManyResources.FormInputs DO
     WITH OneTaskManyResources.FormPrints DO
        IF ( NOT NPrintRowsOnCurrentPage(OneTaskManyResources, 1) ) THEN
            MovePrintHeadToPageEnd(OneTaskManyResources);
            IF ( NOT PrintTitle ) THEN
               PrintTitle := RepeatColumnHeadings( AssignPageCtrl );
            END;
        END;

        IF (PrintTitle ) THEN
            PrintColumnNamesByTask(OneTaskManyResources);
        END;
        PrintNoResourceColumnDataByTask(OneTaskManyResources);
     END;
    END;
END PrintNoResourceByTask;




(****************************************************************************
    CheckOneTaskAgainstResources  -
        Print out all resources and assignments group by task.  This
    procedure will be called for each task.
****************************************************************************)
PROCEDURE CheckOneTaskAgainstResources(
                                              VAR TaskNode : ATreeNode;
                                       AssignRprtSettingsP : ADDRESS
                                      );
VAR
    OneTaskManyResources    :   AnAssignReportSettingsPtr;
    AssignHandle            :   AnExtHandle;
    Task                    :   ATaskPtr;
    TaskFilter              :   ATaskFilterSet;
BEGIN

    IF ( Stopped ) THEN RETURN; END;

    OneTaskManyResources := AssignRprtSettingsP;

    TaskFilter := TaskFiltersPassed( TaskNode );

    IF (NOT ( Selected IN TaskFilter )) THEN RETURN; END;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

    WITH OneTaskManyResources^.FormInputs DO
        IF  ( (Task^.Plan.Dates.EarlyStart > EndingDate.DateValue)
                OR
              (Task^.Plan.Dates.EarlyEnd < StartingDate.DateValue) ) THEN
            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
            Task := NIL;      (* SAFETY!!! *)
            RETURN;
        END;
    END;

    WITH OneTaskManyResources^ DO

        IF ( TaskFilter * ATaskFilterSet{Highlight3..Highlight5}
                                                    = ATaskFilterSet{} ) THEN
            FormPrints.PrintAttribute := Normal;
        ELSE
            FormPrints.PrintAttribute := Bold;
        END;

        EmptyReport := FALSE;
        TaskTreeNode := TaskNode;
        TaskPointer := Task;

        IF ( FormPrints.ShowCurrentAsgnment ) THEN
            AssignHandle := Task^.Plan.Assignments;
        ELSE
            AssignHandle := Task^.BaseLine.Assignments;
        END;

        NoAssignments := TRUE;

        FormPrints.PrintTaskColumnData :=  TRUE;
        PrintColumnNamesAndDataByTask(OneTaskManyResources^, AssignHandle);

        IF ( NoAssignments ) THEN
            PrintNoResourceByTask( OneTaskManyResources^ );
        END;

(*  If we have less than 2 lines left then there is no need to print a
    blank line                                                          *)

        IF ( NOT NPrintRowsOnCurrentPage(OneTaskManyResources^, 2) ) THEN
            MovePrintHeadToPageEnd(OneTaskManyResources^);
            IF ( NOT FormPrints.PrintTitle ) THEN
            FormPrints.PrintTitle :=
                  RepeatColumnHeadings( FormInputs.AssignPageCtrl );
            END;
        ELSE
            PrintBlankLine( OneTaskManyResources^ );
        END;
    END;

    MovePrintHeadToPageEndIfNeeded(OneTaskManyResources^);
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    Task := NIL;      (* SAFETY!!! *)
END CheckOneTaskAgainstResources;




(****************************************************************************
    PrintGroupByTaskAssignment -
        Print out all resources and assignments group by task.  This
    procedure will traverse throught the whole task tree for each strip of
    printing.
****************************************************************************)
PROCEDURE PrintGroupByTaskAssignment(
                              VAR OneTaskManyResources : AnAssignReportSettings
                                    );

        (* Created this to save stack space.  -- EGK 7/3/91 *)

    PROCEDURE EmptyReportMessage();
    VAR
        Line        : ARRAY [0..MaxWidth] OF CHAR;
    BEGIN
        GetMessage(ModuleNumber + 4, Line); (* Empty Report *)
        PrintALine(OneTaskManyResources, Line, Normal);
    END EmptyReportMessage;


BEGIN

    WITH OneTaskManyResources DO
     WITH OneTaskManyResources.FormPrints DO

        EmptyReport := TRUE;
        AtTopOfPage := TRUE;
        OnlyOneStrip := TRUE;
        StripNumber := 0;
        TaskStart := 0;
        NextTaskStart := 0;
        TaskPrintStatus := NotPrintYet;
        ResourceStart := 0;
        NextRsrcStart := 0;
        RsrcPrintStatus := NotPrintYet;
        AssignStart := 0;
        NextAssignStart := 0;
        AssignPrintStatus := NotPrintYet;
        PageHeaderOn := TRUE;
        REPEAT
            PrintTitle := TRUE;
            PrintDateRange := TRUE;
            PageFooterOn := RepeatPageFootings(
                    FormInputs.AssignPageCtrl );
            INC (FormPrints.StripNumber);
            ReportPageNumber := 0;
            BlankHeaderOn := NOT PageHeaderOn;
            FindStartAndNextStartTaskColumn( OneTaskManyResources );
            FindStartAndNextStartResourceColumn( OneTaskManyResources );
            FindStartAndNextStartAssignColumn( OneTaskManyResources );

            TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild,
                                            9999, CheckOneTaskAgainstResources,
                                            ADR(OneTaskManyResources));
            IF ( NOT AtTopOfPage ) THEN
                MovePrintHeadToPageEnd( OneTaskManyResources );
                PageFooterOn := TRUE;
                PrintAssignmentReportFooter( OneTaskManyResources );
            END;
            AllowLeftMargin(NOT IgnoreLeftMargin(
                            FormInputs.AssignPageCtrl));
            IF ( PageBreaksEnable( FormInputs.AssignPageCtrl ) ) THEN
                PrintTitle := TRUE;
            END;
        UNTIL Stopped
                   OR
                   (
                      NOT MoreTaskToPrint( OneTaskManyResources )
                         AND
                      NOT MoreResourceToPrint(OneTaskManyResources)
                         AND
                      NOT MoreAssignToPrint(OneTaskManyResources)
                   );


        IF ( EmptyReport ) THEN
            EmptyReportMessage();       (* 7/3/91 EGK *)
        END;
     END;
    END;
END PrintGroupByTaskAssignment;

(********************** Group by task end here **************************)




(****************************************************************************
    AdjustColumnWidth -
        Adjust all column widths which are greater than the print page width.
****************************************************************************)
PROCEDURE AdjustColumnWidth(
                            VAR Inputs : AnAssignFormInputValues;
                            VAR Prints : AnAssignReportPrintControls
                           );
VAR
    i                       :   CARDINAL;
    Width                   :   CARDINAL;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    ColumnTooWide           :   BOOLEAN;
BEGIN


    Width := Prints.PrintPageWidth;
    ColumnTooWide := FALSE;

    FOR i := 0 TO LASTTASKINFO DO
        IF ( ( Inputs.TaskColumn[i].ColumnWidth + NSpcsBetweenFld )
                                                                > Width ) THEN
            Inputs.TaskColumn[i].ColumnWidth := Width - NSpcsBetweenFld;
            ColumnTooWide := TRUE;
        END;
    END;

    FOR i := 0 TO LASTRESOURCEINFO DO
        IF ( ( Inputs.ResourceColumn[i].ColumnWidth + NSpcsBetweenFld )
                                                                > Width ) THEN
            Inputs.ResourceColumn[i].ColumnWidth :=
                                            Width - NSpcsBetweenFld;
            ColumnTooWide := TRUE;
        END;
    END;

    FOR i := 0 TO LASTASSIGNINFO DO
        IF ( ( Inputs.AssignColumn[i].ColumnWidth + NSpcsBetweenFld )
                                                                > Width ) THEN
            Inputs.AssignColumn[i].ColumnWidth := Width - NSpcsBetweenFld;
            ColumnTooWide := TRUE;
        END;
    END;

    IF ( ColumnTooWide ) THEN
        GetMessage(ModuleNumber + 15, Line);
        Error( Line );
    END;

END AdjustColumnWidth;




PROCEDURE PrintAllAssignments(
                              VAR Inputs : AnAssignFormInputValues;
                              VAR Prints : AnAssignReportPrintControls
                             );
VAR
    AssignRprtSettings      :   AnAssignReportSettings;
BEGIN

    WITH AssignRprtSettings DO
        FormInputs := Inputs;
        FormPrints := Prints;
        AllowUnlimitedPageLength(
                    NOT PageBreaksEnable(FormInputs.AssignPageCtrl));
        IF (FormInputs.HowToGroup = ByTasks) THEN
            PrintGroupByTaskAssignment( AssignRprtSettings );
        ELSE
            PrintGroupByResourceAssignment( AssignRprtSettings );
        END
    END;
END PrintAllAssignments;




PROCEDURE SetPrintControls (
                              VAR FormInputs : AnAssignFormInputValues;
                              VAR FormPrints : AnAssignReportPrintControls
                             );
BEGIN
    FormPrints.PrintPageWidth := PageWidth();
    FormPrints.PrintHeadPos := 0;
    FormPrints.OneTaskPerPage :=
          IsOneTaskOrResourcePerPage( FormInputs.AssignPageCtrl );
    IF ( UnlimitedPageWidth(FormInputs.AssignPageCtrl)
            AND
         (PrintCB.Style = OutToDisk) ) THEN
        FormPrints.PrintPageWidth := MaxPrintWidth;
    END;
    IF ( FormInputs.AssignColumn[0].ColumnID < BsLnBillable ) THEN
        FormPrints.ShowBaselineAsgnment := FALSE;
        FormPrints.ShowCurrentAsgnment  := TRUE;
    ELSE
        FormPrints.ShowBaselineAsgnment := TRUE;
        FormPrints.ShowCurrentAsgnment  := FALSE;
    END;
END SetPrintControls;




PROCEDURE StartAssignmentsReport( VAR Inputs : AnAssignFormInputValues );
VAR
    PrintControls           :   AnAssignReportPrintControls;
BEGIN
    IF (NOT StartReport()) THEN RETURN; END;
    SetPrintControls( Inputs, PrintControls );
    AdjustColumnWidth(Inputs, PrintControls );
    AllowLeftMargin(TRUE);
    PrintAllAssignments(Inputs, PrintControls);
    EndReport();
END StartAssignmentsReport;




(****************************************************************************
    GetAssignSettings  -
        Retreive the old settings for AnAssignFormInputValues.
        If we can not retrieve the old settings then allocate storage
        for the settings and initialize all variable in the settings.
****************************************************************************)
PROCEDURE GetAssignSettings( VAR Inputs : AnAssignFormInputValues
                           ) : BOOLEAN;
VAR
    Pointer                 : ADDRESS;
    Handle                  : AnExtHandle;
    ItemName                :   ARRAY [0..21] OF CHAR;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;
    Result                  :   BOOLEAN;
BEGIN

    SetString(ItemName, "TlarData");
    Class  := 1;
    Result := (
                ( LocateHeldItem(ItemName, Class, Category, Pointer, Size) )
                 AND
                (Size = TSIZE(AnAssignFormInputValues) )
              );
    IF ( Result ) THEN
        Handle := AnExtHandle(Pointer);
        Result := (GetExtData( Handle, ADR(Inputs) ) = Size) AND
                  Inputs.ReturnOK;
    END;

    RETURN Result;

END GetAssignSettings;




PROCEDURE DoAssignmentReport();
VAR
    FormInputs              : AnAssignFormInputValues;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF ( GetAssignSettings(FormInputs) ) THEN
        StartAssignmentsReport(FormInputs);
    END;

END DoAssignmentReport;

BEGIN
    DoAssignmentReport();
END TLAR.


