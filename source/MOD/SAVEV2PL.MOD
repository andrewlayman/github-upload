IMPLEMENTATION MODULE SaveV2Plot;


    (* Save V2 Plot  - Save Version 2 Plotter information to the P@0 file.
                       Part of the TLG Kluge for TL 3.0.

       MODIFICATION HISTORY:

       25-Apr-88 RSC    Created from SaveCommon, then hacked back in shape.
       31-Aug-88 EGK    Changed PickCutoffDates to look also at baselines.
        7-Sep-88 EGK    Changed DeleteAfterPlot to FALSE.
        2-Jan-89 RSC    Removed references to Compare() (not used).
        6-Jun-89 AJL    Put filters into FlexStor.
       15-Jun-89 AJL    Removed F7Filtering.
       21-Aug-89 EGK    Import procs from FilterUtility instead of FilterRc.
       21-Feb-90 KKC   Remove all unreferenced id from Timeu.
    *)

    FROM Allocs       IMPORT  TaskTree, ATaskPtr;

    FROM AsOf         IMPORT  AsOfDate, AsOfSettingOption;

    FROM ChartForms   IMPORT
        (* TYPE *)            AChartFormatPtr,
        (* VAR *)             CurrentChartFormat, LayoutTree,
        (* PROCS *)           CurrentLayout;

    FROM FileAux      IMPORT FileResultMeans,
                             FlushBuffer, PrepareForIO, CheckIO;

    FROM FileSystem   IMPORT File;

    FROM FilterRc     IMPORT
        (* TYPE *)             AFilterRecordPointer, AFltrSet, AFltrType,
        (* VAR *)              RevealFilter, HighlightFilter, 
                               FilterTree;

    FROM FilterUtility      IMPORT
        (* PROCS *)            TestFilterBit;

    FROM LStrings     IMPORT ConcatLS, CtoS, StoC,
                             SubStr, LStringToTString, TStringToLString,
                             Fill, Upshift, TrimRear, Copy,
                             Procustes, LengthOf, Search, Remove, SetLengthOf;

    FROM MsgFile      IMPORT GetMessage;

    FROM PlotStatic   IMPORT
            (* TYPES *)    APlotType, ALabelType, AGanttLabelType,
            (* VARS  *)    GanttPlotRecord, NetPlotRecord, 
                           PlotType, PlotterRecord;

    FROM SaveAscii    IMPORT  SaveBoolean, SaveCardinal, SaveReal,
                              SaveTimeUnit;

    FROM Subfiles     IMPORT  StartFileOutput, EndFileOutput,
                              StartSubfileOutput, EndSubfileOutput;

    FROM SYSTEM     IMPORT TSIZE, SIZE, ADR, ADDRESS;

    FROM Timeu      IMPORT ADate, Today, 
                           TimeUtoT,
                           ATimeUnit;

    FROM RecordIO    IMPORT WriteRecord, WriteString;

    FROM TreeObjects IMPORT ATreeNode;





CONST
    MAXCARDINAL  = 65535;
    MAXDATE      = MAXCARDINAL;

     PlotsType   = 18; (* RSC 8/14/87 from PlotGo *)

    ModuleNumber    = 23800;



  (* PLOTTER SETTINGS - ADDED FROM 'PlotGo' IN TLG BY RSC 8/14/87 *)


PROCEDURE PickCutoffDates( VAR StartDate,
                               EndDate : ADate );
VAR
    Task     : ATaskPtr;
    TaskNode : ATreeNode;
    Filter   : AFilterRecordPointer;
BEGIN
            (*  Pick the starting and ending dates for the report. *)


    TaskNode  := TaskTree^.Methods^.GetFirstVisible (TaskTree);
    IF (TaskNode <> NIL) THEN
        StartDate := MAXDATE;
        EndDate   := Today;
        WHILE (TaskNode <> NIL) DO
            Task  := TaskNode^.Methods^.LockFlexStorDataObject (TaskNode);
            WITH Task^ DO
                IF (Plan.Dates.EarlyStart < StartDate) THEN
                    StartDate := Plan.Dates.EarlyStart;
                END;
                IF (Plan.Dates.EarlyEnd   > EndDate) THEN
                    EndDate := Plan.Dates.EarlyEnd;
                END;
                IF (BaseLine.Dates.EarlyStart < StartDate) THEN     (* 8/31/88 EGK *)
                    StartDate := BaseLine.Dates.EarlyStart;
                END;
                IF (BaseLine.Dates.EarlyEnd   > EndDate) THEN
                    EndDate := BaseLine.Dates.EarlyEnd;
                END;
            END;
            TaskNode^.Methods^.UnlockUnchangedDataObject (TaskNode);

            TaskNode := TaskNode^.Methods^.NextForDisplay (TaskNode);
        END; (* While *)
    ELSE
        StartDate := AsOfDate;
        EndDate   := StartDate;
    END;

    IF (RevealFilter <> NIL) THEN
        Filter := RevealFilter^.Methods^.LockFlexStorDataObject(RevealFilter);
        IF (NOT Filter^.Negative) AND
           (
               TestFilterBit(Filter^.fltrset,FDate)
                AND
               (NOT Filter^.Any)
           )
           THEN
            IF (Filter^.startdate > StartDate) THEN
                StartDate := Filter^.startdate;
            ELSE
                StartDate := 0;
            END;
            IF (Filter^.enddate < EndDate) THEN
                EndDate := Filter^.enddate;
            ELSE
                EndDate := MAXCARDINAL;
            END;
        END;
        RevealFilter^.Methods^.UnlockFlexStorDataObject(RevealFilter);   Filter := NIL;
    END;
END PickCutoffDates;






PROCEDURE SaveLinesIndex( VAR F: File;
                              Type : CARDINAL;
                              Yes : BOOLEAN;
                              Period : ATimeUnit );
VAR
    C : CHAR;
BEGIN
    IF (Yes) THEN
        SaveTimeUnit(F,Type,Period);
    ELSE
        C := "N";
        WriteRecord(F,Type,ADR(C),1);
    END;
END SaveLinesIndex;





PROCEDURE SaveDate( VAR f : File; Date : ADate; Type : CARDINAL );
VAR
    y,m,d,h,mn : CARDINAL;
    s          : ARRAY [0..255] OF CHAR;

    PROCEDURE Add( n : CARDINAL );
    VAR
       i      : CARDINAL;
       s1, s2 : ARRAY [0..5]   OF CHAR;
    BEGIN
        CtoS( 100 + n, s1 );
        i     := ORD( s1[0] );
        s2[0] := 2C;
        s2[1] := s1[ i - 1 ];
        s2[2] := s1[ i     ];
        ConcatLS( s,s2 );
    END Add;

BEGIN
    s[0] := 0C;
    TimeUtoT( Date, y,m,d,h,mn );
    Add( y );
    Add( m+1 ); (* We internally store months as 0-11 *)
    Add( d );
    Add( h );
    Add( mn);
    WriteString(f,Type,s);
END SaveDate;



 (* THIS IS A TRIMMED DOWN VERSION FROM WHAT IS IN SaveCommon.  IT IS
    TRIMMED BACK FOR THE V2 FORMAT!!
 *)

PROCEDURE SavePlotterInfo(VAR f:File);
CONST
    TaskNameColumn          = 1; (* SECRET COLUMN NUMBERS FROM CAPTIONS! *)
    RsrcNameColumn          = 3;                                  (* 06-Jan-88 LAA *)
VAR
    StartDate,
    EndDate      : ADate;
    Chart        : AChartFormatPtr;
    TaskNameWidth,
    RsrcNameWidth,
    Loop,
    LabelLength,
    i            : CARDINAL;
    B            : BOOLEAN;
    s            : ARRAY [0..49] OF CHAR;
BEGIN
    StartSubfileOutput(f,PlotsType,0);

        (* To the back-end, Actual-vs-Plan is same as Gantt *)
    IF (PlotType = NetworkPlot) THEN
        i := 0;
    ELSE
        i := 1;
    END;
    SaveCardinal(f,0,i);

    WITH PlotterRecord DO
        WriteString(f,1,EquivalentTo);
        (*
        SaveBoolean(f,2,DeleteAfterPlot);
        *)
        SaveBoolean(f,2,FALSE);
        SaveCardinal(f,3,NumberOfCopies);
        WriteString(f,4,Name);
        SaveBoolean(f,5,SolidBars);             (* RSC 9/2/87 *)
        SaveBoolean(f,6,SolidBarsAllowed);      (* RSC 9/2/87 *)
        WriteRecord(f,11,ADR(PaperSize),SIZE(PaperSize));
        SaveCardinal(f,12,PenSpeed);
        SaveBoolean(f,13,IncreasingSpeed);
        SaveCardinal(f,14,NumberOfPens);
        SaveDate(f,AsOfDate,20);
        FOR i := 1 TO HIGH(HighlightPenNums) DO       (* RSC 9/2/87 *)
            SaveCardinal(f,30+i,HighlightPenNums[i]);
        END;
        SaveCardinal(f,51,BorderPen);
    END;

    PickCutoffDates(StartDate,EndDate);
    IF (StartDate > 0) THEN
        SaveDate(f,StartDate,21);
    END;
    IF (EndDate < MAXCARDINAL) THEN
        SaveDate(f,EndDate,22);
    END;

        (* Will we be extracting a WBS number from the task name? *)

    B := FALSE;
    IF (PlotType = NetworkPlot) THEN
        IF (NetPlotRecord.LowerLeftLabel = WBSNoL) OR
           (NetPlotRecord.LowerRightLabel = WBSNoL) THEN
            B := TRUE;
        END;
    ELSE
        IF (GanttPlotRecord.AdditionalLabel = GWBSNoL) THEN
            B := TRUE;
        END;
    END;
    SaveBoolean(f,23,B);

    WITH NetPlotRecord DO
        SaveTimeUnit(f,101,HorizPeriod);
        SaveReal(f,102,PeriodsPerInch,2,5);
        SaveCardinal(f,103,ActivityPen);
        SaveCardinal(f,108,MilestonePen);
        SaveCardinal(f,109,PlotterRecord.HighlightPenNums[1]);
        SaveCardinal(f,110,LinkPen);
        SaveLinesIndex(f,111,MajorLineYes,MajorLinePeriod);
        SaveLinesIndex(f,112,MinorLineYes,MinorLinePeriod);
        SaveBoolean(f,114,TRUE);         (* Dependencies *)
        SaveBoolean(f,115,TRUE);         (* Highlights *)
        SaveBoolean(f,118,TRUE);         (* Milestones *)
        SaveBoolean(f,121,TaskNames);
        SaveCardinal(f,122,ORD(LowerLeftLabel));
        SaveCardinal(f,123,ORD(LowerRightLabel));
        SaveCardinal(f,124,ORD(DependencyCriterion));
        SaveCardinal(f,130,MajorLinePen);
        SaveCardinal(f,131,MinorLinePen);
    END;

    WITH GanttPlotRecord DO
        SaveTimeUnit(f,201,HorizPeriod);
        SaveReal(f,202,PeriodsPerInch,2,5);
        SaveCardinal(f,203,ActivityPen);
        SaveCardinal(f,204,PlotterRecord.HighlightPenNums[1]);
        SaveCardinal(f,205,MilestonePen);
        SaveBoolean(f,206,TotalFloat);
        SaveBoolean(f,207,Descr);
        SaveBoolean(f,208,VisSpace);        (* VisSpace  *)
        SaveBoolean(f,209,TRUE);            (* Highlights *)
        SaveBoolean(f,210,TRUE);            (* Milestones *)
        SaveBoolean(f,213,DurColumn);
        SaveBoolean(f,214,ESColumn);
        SaveBoolean(f,215,EFColumn);
        SaveBoolean(f,216,LSColumn);
        SaveBoolean(f,217,LFColumn);
        SaveBoolean(f,218,FFColumn);
        SaveBoolean(f,219,TFColumn);
        SaveLinesIndex(f,220,MajorLineYes,MajorLinePeriod);
        SaveLinesIndex(f,221,MinorLineYes,MinorLinePeriod);
        SaveCardinal(f,222,ORD(AdditionalLabel));
        CASE AdditionalLabel OF
            GWBSNoL  : LabelLength := 15;
          | GSeqNoL  : LabelLength := 5;
        ELSE
            LabelLength := 10;
        END;
        SaveCardinal(f,223,LabelLength);

        TaskNameWidth := 0;
        RsrcNameWidth := 0;

        Chart := CurrentLayout();
        IF (Chart <> NIL) THEN
            FOR Loop := 1 TO Chart^.ColumnCount DO
                WITH Chart^.ColumnSpec[Loop] DO
                    IF (ColumnID = TaskNameColumn) THEN
                        TaskNameWidth := Width;
                    ELSIF (ColumnID = RsrcNameColumn) THEN
                        RsrcNameWidth := Width;
                    END;
                END;
            END;
        END;
        IF (TaskNameWidth > 0) THEN
            DEC(TaskNameWidth);       (* Remove room for the column seperator *)
        END;
        IF (RsrcNameWidth > 0) THEN
            DEC(RsrcNameWidth);       (* Remove room for the column seperator *)
        END;
        
        SaveCardinal(f,224,TaskNameWidth);
        SaveCardinal(f,225,RsrcNameWidth);
        SaveBoolean (f,226,StatusColumn );
        SaveCardinal(f,227,2-ORD(Chart^.slackstyle));    (* Reverse order. *)
        IF (PlotterRecord.BorderPen = 0) THEN
            GetMessage (ModuleNumber+11, s);    (* "Not used here" *)
        ELSE
            GetMessage (ModuleNumber+10, s);    (* "Summary task" *)
        END;
        WriteString( f,228,s);
        SaveCardinal(f,230,MajorLinePen);
        SaveCardinal(f,231,MinorLinePen);
    END;

    EndSubfileOutput(f,PlotsType);
END SavePlotterInfo;




BEGIN
END SaveV2Plot.
