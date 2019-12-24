MODULE TLRR;     (*  TimeLine Status Report   *)
(*
        MODIFICATION History -
   Oct-24-90 CL  - IMPORT PrintResidueAvailability from ResTrace.
   Nov-3-90  AJL - Make a local copy of PrintResidueAvailability as used
                   to be before the above change.  The problem with 
                   importing from ResTrace is it only works when TRACING
                   is on.
*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskFilter, ATaskFilterSet;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROC *)                  BigTimeToTimeInfo;

FROM DateLists              IMPORT
    (* TYPE *)                  ADateList,
    (* PROC *)                  GetDateListEntry; 

FROM Dialog                 IMPORT
    (* PROC  *)                 Error, FatalError;

FROM Filter1                IMPORT
    (* PROC  *)                 TaskFiltersPassed, ResourceFiltersPassed;

FROM FlexStor               IMPORT
    (* TYPE  *)                 AnExtHandle,
                                LockObject, ReleaseObject, ReleaseUnchangedObject;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol;

FROM LongConvert            IMPORT
    (* PROC *)                  LongToString;

FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, CtoS, Copy, Fill, ConcatS,
                                Procustes, ConcatLS, SetLengthOf, RJust,
                                Search, TrimRear, TrimFront, SetString;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage;

FROM PrintCaptions          IMPORT
    (* PROC  *)                 PageHead;

FROM PrintStatic            IMPORT
    (* TYPE  *)                 APrinterStyle,
    (* VAR   *)                 PrintCB;

FROM PrintSupport           IMPORT
    (* VAR   *)                 Stopped,
    (* PROC  *)                 AllowLeftMargin, PageWidth, PrintLine,
                                PrintText, EndReport, StartReport,
                                RowsLeft, AllowUnlimitedPageLength,
                                GetCurrentPrintRow, StartPage;

FROM RateLists              IMPORT
    (* TYPE *)                  ARateList;

FROM ResCal                 IMPORT
    (* TYPE *)                  AnAvailabilityCell, AnAvailabilityCellPointer;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AResourceCalendarPointer,
                                AnAvailabilityRate, ACalendarEntry;

FROM RsrcMod                IMPORT
    (* TYPE  *)                 AResourcePointer, AResourceType,
    (* VAR   *)                 ResourceTree;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE  *)                 ADDRESS, ADR, TSIZE, SIZE;

FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;

FROM Timei                  IMPORT
    (* CONST *)                 NoDuration,
    (* TYPE  *)                 ADate, ADurationUnit, ATimeInfo,
    (* PROC  *)                 TimeUtoT;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder;

CONST
    ModuleNumber        =   21700;
    MaxWidth            =   255;
    MaxColumnWidth      =   255;
    Normal              =   0;
    Bold                =   1;

    NBottomRowsReserved =   2;

    NSpcsBetweenFld     =   5;
    MaxPrintWidth       =   255;
TYPE


PROCEDURE FormatBigTime( B : ABigTime; VAR S : ARRAY OF CHAR );
VAR
    TimeInfo : ATimeInfo;
BEGIN
    BigTimeToTimeInfo(B,TimeInfo);
    TimeToString(TimeInfo,DefaultDateAndTimeFormat,S);
END FormatBigTime;



PROCEDURE PrintResourceCalendar(Calendar : AResourceCalendarPointer); 
VAR
    Line : ARRAY [0..MaxPrintWidth] OF CHAR;
    S    : ARRAY [0..MaxPrintWidth] OF CHAR;
    DateList   : ADateList;
    N          : CARDINAL;
    BStartDate, BEndDate : ABigTime;
    CalendarEntry : ACalendarEntry;
BEGIN
    IF (Calendar = NIL) THEN
        SetString(Line,"No Calendar");
        PrintLine(Line,Normal);
        RETURN;
    END;

    SetString(Line,"Vacations calendar: ");
    ConcatLS(Line,Calendar^.Name);
    PrintLine(Line,Normal);
    DateList := Calendar^.CalendarIntervals;
    IF (DateList = ADateList(NIL)) THEN
        SetString(Line,"Calendar has no dates.");
        PrintLine(Line,Normal);
        RETURN;
    END;

    N := 1;
    WHILE (GetDateListEntry(DateList,N,BStartDate,BEndDate,CalendarEntry)) DO
        SetString(Line,"    ");
        FormatBigTime(BStartDate,S);
        ConcatLS(Line,S);
        ConcatS(Line," - ");
        FormatBigTime(BEndDate,S);
        ConcatLS(Line,S);
        IF CalendarEntry.Vacation THEN
            ConcatS(Line,"  Vacation");
        ELSE
            ConcatS(Line,"  Work    ");
        END;
        PrintLine(Line,Normal);
        INC(N);
    END;

END PrintResourceCalendar;







PROCEDURE PrintResourceAvailability(Availability : ADateList); 
VAR
    Line : ARRAY [0..MaxPrintWidth] OF CHAR;
    S    : ARRAY [0..MaxPrintWidth] OF CHAR;
    DateList   : ADateList;
    N          : CARDINAL;
    BStartDate, BEndDate : ABigTime;
    AvailabilityRate     : AnAvailabilityRate;
BEGIN
    IF (Availability = ADateList(NIL)) THEN
        SetString(Line,"No varying availability.");
        PrintLine(Line,Normal);
        RETURN;
    END;

    SetString(Line,"Varying Availability: ");
    PrintLine(Line,Normal);

    N := 1;
    WHILE ( GetDateListEntry( Availability, N, BStartDate,BEndDate,AvailabilityRate )) DO
        SetString(Line,"    ");
        FormatBigTime(BStartDate,S);
        ConcatLS(Line,S);
        ConcatS(Line," - ");
        FormatBigTime(BEndDate,S);
        ConcatLS(Line,S);
        ConcatS(Line,"    ");
        CtoS(AvailabilityRate.Amount,S);
        ConcatLS(Line,S);
        ConcatS(Line,"  @  ");
        CtoS(AvailabilityRate.Percent,S);
        ConcatLS(Line,S);
        ConcatS(Line,"%");
        PrintLine(Line,Normal);
        INC(N);
    END;

END PrintResourceAvailability;




PROCEDURE PrintAvailabilityCell( VAR Cell : AnAvailabilityCell );
VAR
    Line : ARRAY [0..MaxPrintWidth] OF CHAR;
    S    : ARRAY [0..MaxPrintWidth] OF CHAR;
BEGIN
    WITH Cell DO
        SetString(Line,"    ");
        TimeUtoS(StartDate,S);
        ConcatLS(Line,S);
        ConcatS(Line," - ");
        TimeUtoS(EndDate,S);
        ConcatLS(Line,S);
        ConcatS(Line,"    ");

        ConcatS(Line,"(");
        CtoS(StartDate,S);
        Procustes(S,5);     (* Pad to 5 chars. *)
        RJust(S);
        ConcatLS(Line,S);
        ConcatS(Line," - ");
        CtoS(EndDate,S);
        Procustes(S,5);     (* Pad to 5 chars. *)
        RJust(S);
        ConcatLS(Line,S);
        ConcatS(Line,")    ");


        LongToString(AmountAvailable,S);
        ConcatLS(Line,S);

        IF ThisIsAVacation THEN
            ConcatS(Line,"  Vacation");
        ELSE
            ConcatS(Line,"          ");
        END;
    END;
    PrintLine(Line,Normal);
END PrintAvailabilityCell;




PROCEDURE PrintResidueAvailability( ResidueAvailProfile : AnExtHandle ); 
VAR
    CellHandle, 
    NextHandle  : AnExtHandle;
    Line        : ARRAY [0..MaxPrintWidth] OF CHAR;
    Cell        : AnAvailabilityCellPointer;
    BackToHead,
    First       : BOOLEAN;
BEGIN
    IF (ResidueAvailProfile = AnExtHandle(NIL)) THEN
        SetString(Line,"No residue availability.");
        PrintLine(Line,Normal);
        RETURN;
    END;

    SetString(Line,"Residue Availability: ");
    PrintLine(Line,Normal);

    CellHandle := ResidueAvailProfile;

    BackToHead := FALSE;
    First := TRUE;
    REPEAT
        IF (LockObject(CellHandle,Cell) <> SIZE(Cell^)) THEN
            FatalError();
        END;
        
        IF (Cell^.IsHeadCell) THEN
            IF (NOT First) THEN
                BackToHead := TRUE;
                SetString(Line,"<<Done>>");
                PrintLine(Line,Normal);
		    ELSE
                First := FALSE;
            END;
        ELSE
            PrintAvailabilityCell(Cell^);
        END;    
    
        NextHandle := Cell^.NextCell;
        ReleaseUnchangedObject(CellHandle);  
        Cell := NIL;
        CellHandle := NextHandle;
    UNTIL BackToHead;

END PrintResidueAvailability;









PROCEDURE PrintOneResource( ResourcePtr : AResourcePointer);
VAR
    Line : ARRAY [0..MaxPrintWidth] OF CHAR;
    S2   : ARRAY [0..MaxPrintWidth] OF CHAR;
BEGIN
    Fill(Line," ",0);
    PrintLine(Line,Normal);
    Fill(Line,"-",PageWidth());
    PrintLine(Line,Normal);

    Copy(ResourcePtr^.Name, Line);
    Fill(S2," ",NSpcsBetweenFld);
    ConcatLS(Line,S2);
    ConcatLS(Line, ResourcePtr^.LongName);
    PrintLine(Line,Bold);

    Fill(Line,"-",PageWidth());
    PrintLine(Line,Normal);

    PrintResourceCalendar( ResourcePtr^.Calendar );
    PrintResourceAvailability( ResourcePtr^.Availability );
    PrintResidueAvailability( ResourcePtr^.ResidueAvailProfile );
END PrintOneResource;



(****************************************************************************
    PrintResourceStatus -
        Print report for each resource.
****************************************************************************)
PROCEDURE PrintResourceStatus(
                                    VAR ResourceNode : ATreeNode;
                                  StatusRptSettingsP : ADDRESS
                                 );
VAR
    RsrcFilter              :   ATaskFilterSet;
    ResourcePtr             :   AResourcePointer;
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    ResourcePtr :=  ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF ( ResourcePtr^.Type <> Employable ) THEN
        RETURN;
    END;

    RsrcFilter := ResourceFiltersPassed( ResourceNode );

    IF (NOT ( Selected IN RsrcFilter )) THEN RETURN; END;

    PrintOneResource( ResourcePtr );

END PrintResourceStatus;




(****************************************************************************
    PrintEachResourceStatus -
        Travese all resouce node in resource tree and print its status.
****************************************************************************)
PROCEDURE PrintEachResourceStatus();
BEGIN
    ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild,
                                               9999, PrintResourceStatus,
                                               NIL);
END PrintEachResourceStatus;





PROCEDURE PrintAllStatus();
BEGIN
    AllowUnlimitedPageLength( FALSE );
    PrintEachResourceStatus() ;
END PrintAllStatus;











PROCEDURE StartStatusReport();
BEGIN
    IF (NOT StartReport()) THEN RETURN; END;
    AllowLeftMargin(TRUE);
    PrintAllStatus();
    EndReport();
END StartStatusReport;








PROCEDURE DoStatusReport();
BEGIN
    StartStatusReport();
END DoStatusReport;




BEGIN
    DoStatusReport();
END TLRR.
