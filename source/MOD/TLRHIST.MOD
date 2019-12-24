(*V1=SEARCHMODE*)   (* Activates CtrlLeft and CtrlRight to be search keys. *)
                    (* These will search the histograms for the next 
                       change in either direction. *)

(*V2=TRACE*)

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    Commnts from 86 through 89 removed.

     2-Jan-90 RSC   1) Removed the double up line on the seperator as per
                       WKH, because it looked ugly when the Gantt mouse
                       scroll buttons were present.
                    2) When mouse events are received, absorb ALL following
                       MouseStillDown events, even when not on our region.
                       This eliminates the "cross polination" of events.
    22-Jan-90 RSC   Fixed problem where we looped forever when at the end
                    of the calendar.
    19-Mar-90 RSC   Histograms don't recalc sometimes when mouse clicks
                    are used exclusively to change the schedule, such as
                    changing the options from CPM to Leveling.  This
                    was because mouse downs were not always signalling
                    a recalc properly (I kinda assumed that I would recalc
                    from some other source, like the ChartStartDay changing).
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    19-Sep-90 RSC   Made the EVE updates.
     2-Oct-90 RSC   Continued working on EVE changes.
    15-Oct-90 RSC   Updated the left side captions and support our vacations
                    videomode.
    17-Oct-90 AJL/CL   Modify ResidualAvailability to use the head cell as
                       a boundary for searching thru the residual list.
    25-Oct-90 RSC   Updates to the speed and the legend.
     8-Nov-90 RSC   Resolved outstanding bugs (I think).  There was a bug
                    in the accumulation of averages and computation of
                    vacations.
    12-Dec-90 RSC   Allow 655.35 people, not 6.5535.
    13-Dec-90 AJL   Show the contribution of the cursor task superimposed
                    over the total usage, and also use up and down arrows
                    to show when the availability changes.
                    Turn off the cursor before processing events.  This 
                    is more agressive than before, can cause a little flicker,
                    but fixes a problem in which clicking the mouse could
                    leave parts of the histogram undrawn.
    14-Dec-90 AJL   Changed the color used for the cursor task contribution
                    to videonormal, the same as the normal task color.
    15-Dec-90 AJL   In SetRecalcCursor, obtain the CurrentLayoutPtr
                    before using it.  It might not have been set.
                    Replace a call to PutAttribute with PutStringWithAttribute
                    in order to reduce histogram flicker when the cursor
                    changes but very little of the histogram is changed.
    24-Dec-90 AJL   Support internationalization by making the symbols
                    used come from the phrases file.
    24-Jan-91 AJL  -Display Histograms synchronized to the cursor task
                    if the overlay context parameter is "1".
                   -Change the Ratio procedure to show x/0 as MAX(CARDINAL).
                   -Double-Click is accepted at any X coordinate.
                   -Double-click on Separator bar synchronizes to cursor task.
    28-Jan-91 AJL  -If the Availability field in the resource record is NIL,
                    use the UpperLimit field to obtain the quantity available.
                   -Change the attribute used for the captions to videographlabel
                    so that the background will match the histogram bar background.
                   -When the cursor is on a vacation day, support the new keyword
                    *V* to show the word "Vacation".
     7-Feb-91 TGS   Well, if Availability field is NIL, use defaults in 
                    RsrcMod, not UpperLimit (which is defunct now).
    22-Feb-91 TGS   Dummy up an assignment list entry for any pre-assignment
                    time.
    22-Mar-91 TGS   Let "ExitKey" pass to ganttoutline so it can be a menukey.
    26-Apr-91 AJL   During periods when the availability on a resource is zero,
                    use the same display colors as for a vacation to make it 
                    real clear that the resource is unavailable.
    12-Jul-91 AJL   Put the text for the resource amounts in videonormal to
                    match its background.
    14-Jul-91 AJL   Modify AverageOverManyPeriods so that, for dates near
                    the end of the calendar, it no longer crashes.
                    Ctrl-Left and Right search the histograms for changes
                    in residual availability.
    17-Jul-91 AJL   ShowHistogram was calling DoOneBar with levels of 
                    0, .6, 1.1 and 1.6 instead of 0, .5, 1.0 and 1.5.
                    This was due to NextAmount erroneously starting at
                    100, not 0.  Bug number 4686.
    27-Jul-91 AJL  -Allow the beginning of the histogram to go as far left
                    as the beginning of the Gantt bars area, even if this 
                    means not displaying all of the text area.
    12-Aug-91 AJL  -The displayed strings at the left of the screen were
                    not long enough to overwrite old displays.
     6-Sep-91 TGS   When we've overflowed the Tics arrays, put up overflow
                    characters instead of a bogus number.
     9-Sep-91 TGS   Ratio proc didn't check for LONGINT overflow.
                    Fixed what looked like a bad index into ResAvails (was
                    checking "[j]", changed it to "[j-Offset]".
                    MAXLONGINT was defined as "07FFFFFFFL", which the
                    compiler in its infinite wisdom turned into "7L" without
                    complaint. Imagine the possibilities.
    10-Sep-91 TGS   Import new HistStat variable, HistogramsAreUp. This
                    allows "F8" (or equiv. menu selection) to bring up the
                    histogram form when histograms are already up and the 
                    menu is up. In such cases, GanttOutlines passes the event
                    back to our MainLoop here instead of dispatching it (and
                    having that invoke DoTLRHist and getting a bogus error).
                    Bug 4785.
    30-Jan-92 TGS   AnAssignmentList now contains REAL. Made minimal changes
                    to reflect this.
----------------------------------------------------------------------------*)

MODULE TLRHist;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, ATaskFilter,
    (* VAR  *)                  TaskTree;

FROM AsOf                   IMPORT
    (* VAR  *)                  AsOfDate;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentAttribute,
                                AnAssignmentRecord, AnAssignmentArray,
    (* PROC *)                  ForEachAssignment;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM Chart                  IMPORT
    (* VAR  *)                  GanttChart, ChartStartDay,
                                CursorDay,
    (* PROC *)                  ShowSched, MChDay;

FROM ChartControl           IMPORT 
                                AChartState, ChartState, AChartStateSet,
                                DisplayTheChart, SetState, UnSetState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr;

FROM Codes                  IMPORT
    (* TYPES *)                 ACode, ASetOfCodes,
    (* CONST *)                 MaxCode,
    (* VAR   *)                 EmptyCodeSet,
    (* PROCS *)                 SetCodeBits;

FROM DateLists              IMPORT
    (* TYPE *)                  ADateList, ADateListIndex,
    (* PROC *)                  LocateDateInDateList, GetDateListEntry;

FROM Dialog                 IMPORT 
                                Error, NotYetImplemented, FatalError, 
                                WarningBox, ADialogOption, Burp, Message,
                                MultipleChoiceBox, ErrorPhrase;

FROM Endings                IMPORT
    (* VAR  *)                  QuitDammitCode;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker,
                                GetErrorDetails;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType, GetNextEvent;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROC *)                  LockObjectArray, LockObject,
                                ReleaseUnchangedObject;

FROM Foreign                IMPORT
    (* PROC *)                  DecodeString;

FROM Gantt                  IMPORT
                                StatWidth, ASlackStyle, DateLines,
                                DateLnDepth, ADStyle, CheckScale,
                                ChartFont;

FROM GanttOutlines          IMPORT
    (* PROC *)                  CreateGanttOutline, ValidateGanttOutline;

FROM Helper                 IMPORT 
                                GiveHelp, AScreenAction;

FROM HistStat               IMPORT 
                                MaxResources, HistResource, HistInterlock,
                                HistogramsAreUp;

FROM Kbio                   IMPORT 
                                maxrow, maxcol, ascreenx, ascreeny,
                                avidmode, PutString, EraseLn,
                                PutColors, vidctrl;

FROM Keys                   IMPORT
    (* CONST *)                 Fwrd, Reverse, InsertKey, DeleteKey, EditKey,
                                CancelKey, Up, Down, PgUpKey, PgDnKey,
                                HomeKey, EndKey, JoinKey, UnJoinKey, GotoKey, 
                                GotoCurrentTaskKey, GotoTodayKey, GotoFirstKey, 
                                GotoLastKey, JoinPartialKey, 
                                EditBigTaskKey, DsplyKey, ComputeKey, 
                                Goto1Key, Goto2Key, OptionsFormKey, 
                                ResourceFormKey, DaysKey, GotoNameKey, 
                                ReportsKey, PromoteKey,
                                FileFormKey, AnteKey, DemoteKey, MoveUpKey,
                                MoveDownKey, OpenKey, CloseKey, DoIt,
                                SelectKey, CopyKey, GotoWBSKey, 
                                TaskNotesKey, HelpKey, HistKey, SelListKey, 
                                HighListKey, HighList2Key, HighList3Key, 
                                DependViewKey, HelpIndexKey,
                                RollLeft, RollRight, RepeatKey,
                                ExitKey, PrintFormKey, AlternateDisplayKey,
                                HistSynchKey,

                                 (* From Actions before 1/5/89.  RSC. *)

                                QuitProgram, FileErase, FiltersClear, FileRetrieve,
                                PlotGantt,

                                MouseDown, MouseDouble, MouseUp, MouseStillDown;

FROM KeywdSub               IMPORT
     (* PROC *)                 MakeSubstitutions;

FROM Layout                 IMPORT 
                                GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM LongConvert            IMPORT
    (* PROC *)                  RealToLong, LongToReal, LongToString;

FROM LStrings               IMPORT 
                                SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                Copy, Insert, Procustes, TrimFront, TrimRear, 
                                Compare, LJust, Overlay, TStringToLString,
                                RJust, LengthOf, SetLengthOf, Fill, Search;

FROM Mouse                  IMPORT
    (* PROC *)                  MousePresent;

FROM MsgFile                IMPORT 
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  RegisterForNotices;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  CallOverlayWithContext, OverlayContext,
                                ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc, AContextListEntry;

FROM RealFormat             IMPORT
    (* VAR  *)                  DefaultAmountFormat,
    (* PROCS *)                 FormatAsAmount;

FROM ResCal                 IMPORT
    (* TYPE *)                  AnAvailabilityCell, AnAvailabilityCellPointer,
    (* PROC *)                  CellContainingDate;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AnAvailabilityRate;

FROM RsrcMod                IMPORT
    (* CONST *)                 ResourceNameLength,
                                DefaultAvailabilityAmount,
                                DefaultAvailabilityPercent,
    (* TYPE *)                  AResourcePointer, AResourceType, ACostStyle,
    (* VAR  *)                  ResourceTree,
    (* PROC *)                  FindResourceByName;

FROM Rugs                   IMPORT 
                                ARug, GetRug, PutRug, ThrowRug;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  TSIZE, SIZE, ADR, ADDRESS;

FROM TimeJump               IMPORT 
                                FindNextKeyDate, FindPriorKeyDate;

FROM Timei                  IMPORT
    (* CONST *)                 MinDate, MaxDate,
    (* TYPE *)                  ADate, ADuration, ADurationUnit;

FROM TimeMath               IMPORT
    (* PROC *)                  DurationInPeriod;

FROM Timeu                  IMPORT
    (* VAR  *)                  FSMUPH;

FROM TimeXlate              IMPORT
    (* PROC *)                  BigTimeToCalendarTime,
                                CalendarTimeToBigTime;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  ValidateTree, ValidateTreeNode;

FROM VaryAssgnment          IMPORT
    (* TYPE *)                  AVaryingAssgnList, AVaryingAssgnListIndex,
    (* PROC *)                  GetVaryingAssgnListEntry,
                                LocateDateInVaryingAssgnList;

FROM Video                  IMPORT
    (* PROC *)                  PutStringWithAttribute;

(*<TRACE
FROM Tracer   IMPORT  PrintString, EndTrace;

VAR
    TraceS, TraceS2 : ARRAY [0..255] OF CHAR;
TRACE>*)


CONST
    ModuleNumber     = 13300;    (* For GetMessage *)

    Zero             = 0.0;
    MAXCARDINAL      = 0FFFFH;
    MAXDATE          = MAXCARDINAL;
    FMAXCARDINAL     = 65535.0;
    MAXLONGINT       = 07FFFFFFFH;  (* 9-Sep-91 TGS was "07FFFFFFFL". Oops. *)
    OneHundred       = 100.0;
    HistEndsAt       = maxcol+1;
    (* These are now vars.
    Underline        = "_";
    OverRange        = "+";
    UpArrow          = 30C;  (* was 36C *)
    DownArrow        = 31C;
    Block            = 333C;
    HalfBlock        = 334C;
    *)



    MinPromptArea    = 6;   (* Minimum  width of the prompt lines can extend *)
    MaxPromptArea    = 41;  (* Farthest the prompt lines can extend *)

TYPE
    AResourceList     = ARRAY [1..MaxResources] OF AResourcePointer;
    AProportionMatrix = ARRAY [1..MaxResources]     OF
                        ARRAY [MinPromptArea..maxcol+1] OF CARDINAL;

VAR
    OverlayID        : AnOverlayID;

    FirstScreenLine  : CARDINAL;  (* Our first line. *)
    LastScreenLine   : CARDINAL;  (* Our last line.  *)
    SeparatorLine    : CARDINAL;  (* Gray bar above histograms. *)
    VHeight          : CARDINAL;  (* Height of each resource in bytes *)
    VSlots           : CARDINAL;  (* Resolution, or VHeight * 2 *)
    HistStartsAt     : CARDINAL;
    HistStartDay     : CARDINAL;  (* Close to ChartStartDay *)
    OldHistStartsAt  : CARDINAL;

    CursorTaskTics,
    VTics            : AProportionMatrix;

        (* Availablity at each date, contains the percentage available
           times the whole number available. *)
    Availability     : ARRAY [1..MaxResources]     OF
                       ARRAY [MinPromptArea..maxcol+1] OF LONGINT;

        (* How many whole resources are available at each date; contains
           the "N" or "N at some percent".  *)
    AvailabilityNum  : ARRAY [1..MaxResources]     OF
                       ARRAY [MinPromptArea..maxcol+1] OF CARDINAL;

    StartingRow      : ARRAY [1..MaxResources]     OF CARDINAL;
    EndingRow        : ARRAY [1..MaxResources]     OF CARDINAL;
    CurrentLayoutPtr : AChartFormatPtr;
    NumberOfResources: CARDINAL;
    PrevNResources   : CARDINAL;
    GMakeNewGanttLY  : ascreeny;
    CursorInfo       : RECORD
        Rug      : ARug;
        RugX     : ascreenx;
        RugTaken : BOOLEAN;
        Filler   : BOOLEAN;     (* Make even lengthed. *)
    END;

    Resources        : AResourceList;

    MidLine          : ARRAY [0..maxcol+1]       OF CHAR;

    AbsorbingMouseEvents    : BOOLEAN;

    VacationList     : ARRAY [1..MaxResources]     OF
                       ARRAY [MinPromptArea..maxcol+1] OF BOOLEAN;

    Line             : ARRAY [0..2]              OF       (* 25-Oct-90 RSC *)
                       ARRAY [0..MaxPromptArea]  OF CHAR;

    Underline,
    OverRange,
    UpArrow,
    DownArrow,
    HalfBlock        : CHAR;



(* RSC 5-Jun-89.  Added this module to help decide when we need to recalc.
*)
MODULE RecalcDecisions;


IMPORT
    (* TYPE *)      ATreeNode,  AStep, AnOccasion, ADate,  ADDRESS,
                    AChartFormatPtr, AContextListEntry, SIZE,
    (* VAR  *)      CurrentLayoutPtr, GanttChart,  ChartStartDay,
    (* PROC *)      RegisterForNotices, SetString, Search,
                    ShowHistograms, ResynchHistogramsToGantt, ShowCursor;


EXPORT
    (* PROC *)      SetRecalcCursor, DoWeRecalc;




VAR
    OldCursorTask       : ATreeNode;
    OldChartStartDay    : ADate;
    OldGanttPosition    : CARDINAL;
    NoticeRecalc        : BOOLEAN;  (* Did we get a suspicious notice? *)





(* Set Recalc Cursor

    When recalcing, set the cursor task node we looked at.
*)
PROCEDURE SetRecalcCursor( CursorNode : ATreeNode );
BEGIN
    OldCursorTask := CursorNode;

    CurrentLayoutPtr := GanttChart^.Methods^.GetLayout( GanttChart );   (* AJL 15-Dec-90 *)
    WITH CurrentLayoutPtr^ DO
        OldChartStartDay := ChartStartDay;
        OldGanttPosition := GanttPosition;
    END;
    NoticeRecalc := FALSE;

END SetRecalcCursor;




PROCEDURE DoWeRecalc( VAR Quit, Recalc, CursorOnly : BOOLEAN );
VAR
    OldLayoutPtr    : AChartFormatPtr;
BEGIN
    Recalc      := FALSE;
    Quit        := FALSE;
    CursorOnly  := FALSE;

    OldLayoutPtr     := CurrentLayoutPtr;
    CurrentLayoutPtr := GanttChart^.Methods^.GetLayout( GanttChart );
    WITH CurrentLayoutPtr^ DO
        IF (NOT GanttShowing) THEN
            Quit       := TRUE;
        ELSE

            Recalc  := ((NoticeRecalc)                      OR
                        (OldGanttPosition <> GanttPosition) OR
                        (ChartStartDay <> OldChartStartDay));

            IF (NOT Recalc) THEN
                CursorOnly := (OldCursorTask <> GanttChart^.Methods^.GetCursorNode( GanttChart ));
                Recalc     := CursorOnly;  (* Set to true if cursor changes. *)
            END;
        END;
    END;

END DoWeRecalc;




(* Notice things happening in the rest of Time Line.

    Ignore some notices as unimportant, the rest are cause for a full recalc.
    This saves us from having to examine every key that floats by.

    Err on the safe side.  That is, if in doubt, recalc!

    (* 25-Oct-90 RSC Remember that the Gantt is checked for changes in date
                     and cursor task, so we don't need to account for that
                     here (like DeleteATask).  We want to watch for deleting
                     resources, but otherwise model changes do not affect us.
    *)
*)
PROCEDURE NoticeThis(    Occasion  : AnOccasion;
                         Step      : AStep;
                         Context   : ADDRESS    ) : BOOLEAN;
TYPE
    ASetOfOccasions = SET OF AnOccasion;
CONST
    IgnoreThisOccasion = ASetOfOccasions{

    (* 25-Oct-90 RSC Added *)   ConfigSave,         DiskFileErase,
                                EMSLowMemory,       QueryMemoryStatus,
                                ExitToDOS,          ModelSave,

                                AddATask,           DeleteATask,
                                ChangeATask,        MoveATask,
                                OpenATask,          CloseATask,
                                AddAResource,
                                AddAnEdge,          DeleteAnEdge,
                                ChangeAnEdge,

                                NetworkSettingChange,
                                FilterChange,       CalendarChange,
    (* 25-Oct-90 RSC End of adds *)

                                LowMemory,          ScheduleSort,
                                ScheduleFilter,     WarningActive,
                                FormActive,         MenuActive,
                                PickListActive,     DialogActive,
                                OverlayCall,        OverlayActive,
                                TakeCursorControl,  ReturnCursorControl,
                                KeyForAltView };

VAR
    Quit                  : BOOLEAN;
BEGIN

    NoticeRecalc := (NoticeRecalc OR (NOT (Occasion IN IgnoreThisOccasion)));

    (* KKC 25-Aug-89 Update Histogram if video changed *)

    IF ( Occasion = VideoSetupChange ) THEN
        ResynchHistogramsToGantt( Quit );
        ShowCursor( FALSE, FALSE );                (* Hide cursor *)
        ShowHistograms(FALSE);
        ShowCursor( TRUE, FALSE );
    END;

    RETURN TRUE;

END NoticeThis;




BEGIN

    SetRecalcCursor(    ATreeNode(NIL) );
    RegisterForNotices( AllOccasions, NoticeThis );

END RecalcDecisions;











PROCEDURE MakeNewGantt(    LowerY           : ascreeny);
VAR
    i   : ascreeny;
BEGIN                       (* MakeNewGantt *)
    IF (LowerY <> GMakeNewGanttLY) THEN

        GMakeNewGanttLY := LowerY;

        FOR i := (LowerY + 1) TO GanttWEnd DO
            EraseLn( i );
        END;

        (* RSC 12/16/88 new call format. *)
        GanttChart^.Methods^.ChangeHeight( GanttChart, GanttWStart + 2, LowerY );
        UnSetState(Showing);
        DisplayTheChart();
    END;
END MakeNewGantt;








PROCEDURE MainLoop();

CONST SlashKey = 47; (* ORD("/") *)

VAR
    Event, HistEvent        : AnEvent;
    ReturnEvent             : AnEvent;
    ErrorMarker             : AnErrorMarker;
    WhichDsplKey            : CARDINAL;
    Code                    : ACode;
    RestingCodes            : ASetOfCodes;
    RestingCursor,
    Quit                    : BOOLEAN;

    PROCEDURE GiveSomeHelp();
    VAR s : ARRAY [0..9] OF CHAR;
    BEGIN
        SetString(s,"HISTO");
        GiveHelp(s,0,GanttWEnd,RestoreTheScreen);
    END GiveSomeHelp;

BEGIN                       (* MainLoop *)
  (* Setup the codes that cause us to go to resting cursor.  These are from
     GanttOutlines!!
  *)
    RestingCodes := EmptyCodeSet;
    FOR Code := 1 TO MaxCode DO
        CASE Code OF
            FileErase, FiltersClear, GotoCurrentTaskKey, 
            GotoTodayKey, DsplyKey, ComputeKey, OptionsFormKey, 
            ResourceFormKey, DaysKey, HistKey, SelListKey, 
            FileRetrieve, HighListKey, HighList2Key, HighList3Key, 
            DependViewKey, FileFormKey, GotoWBSKey, AnteKey, 
            InsertKey, EditKey, DeleteKey, CopyKey, TaskNotesKey,
            GotoKey, EditBigTaskKey, HelpIndexKey,
            RollLeft, RollRight,
            SlashKey :
                SetCodeBits(RestingCodes,Code,Code,TRUE);
        ELSE
        END;
    END;

    Quit := FALSE;

    LOOP
        ShowCursor(TRUE,FALSE);                    (* Show cursor. *)
        GetNextEvent(Event);
        ShowCursor( FALSE, FALSE );                (* Hide cursor *)

        ErrorMarker := NewMarker();

        (*<DEBUGGING
        ValidateGanttOutline(GanttChart);
          DEBUGGING>*)

        HistEvent     := Event;
        ReturnEvent   := Event;
        RestingCursor := FALSE;

        (* RSC 2-Jan-89 Absorb mouse events even if not in our zone if
                        we have seen some in our zone.
        *)
        IF (NOT ((Event.EventType = MouseEvent) AND
                 (AbsorbingMouseEvents OR MouseInOurZone(Event)))) THEN
            AbsorbingMouseEvents := FALSE;  (* Anything other than a mouse event cancels absorption. *)
            Code := Event.EventCode;
            CASE Code OF
                (* 22-Mar-91 TGS let this guy through
                ExitKey             : ReturnEvent.EventCode := 0;
                *)
            |   (*<SEARCHMODE
                   RollLeft,
                   RollRight, SEARCHMODE>*)
                AlternateDisplayKey,                                  (* 02-Mar-88 LAA *)
                HistKey,                                              (* 15-Mar-88 AJL *)
                HistSynchKey        : ;
            |   HelpKey             : GiveSomeHelp();                 (* 26-Feb-88 EGK *)
            ELSE
                UnSetState(Showing);                          (* 19-Aug-87 LAA *)
                IF ((Code MOD 16) IN RestingCodes[ Code DIV 16 ]) THEN
                    RestingCursor := TRUE;
                    ShowCursor( TRUE, TRUE );
                ELSE
                    RestingCursor := FALSE;
                END;
                GanttChart^.Methods^.ActOnEvent(GanttChart, Event, ReturnEvent);

                IF (ErrorPosted(ErrorMarker)) THEN
                    Burp();
                END;
            END;

            PopToMarker(ErrorMarker);

            IF (QuitDammitCode <> 0) THEN      (* RSC 5/4/88 *)
                ReturnEvent.EventCode := QuitDammitCode;
            END;

            WITH ReturnEvent DO
                CASE EventCode OF
                    0, CancelKey : DisplayTheChart();
                |   (*<SEARCHMODE RollLeft,
                       RollRight, SEARCHMODE>*)
                    HistKey,                                       (* 15-Mar-88 AJL *)
                    HistSynchKey        :
                        HistEvent := ReturnEvent; (* 10-Sep-91 TGS *)

                |   AlternateDisplayKey,                              (* 02-Mar-88 LAA *)
                    PlotGantt   :    (* RSC 5/4/88 *)
                        RETURN;
                ELSE
                    IF (EventCode = QuitProgram) THEN (* \Quit, Yes *) (* 02-Mar-88 LAA *)
                        QuitDammitCode := EventCode;
                        RETURN;
                    END;
                END; (* CASE *)
            END;
        ELSE
            PopToMarker(ErrorMarker);                          (* 28-Dec-89 *)
        END;


        (*  Send Event to histograms:
        *)
        HistogramActOnEvent( HistEvent, Quit );

        IF (Quit OR (NumberOfResources = 0)) THEN
            RETURN;
        ELSIF (RestingCursor) THEN
            ShowCursor( TRUE, FALSE );
        END;

    END;

END MainLoop; 






PROCEDURE DoOneBar (     WhichResource : CARDINAL;
                         StartY,
                         EndY,
                         Midpoint,
                         y             : ascreeny;
                         TodayLine,
                         MinimumAmount,
                         HalfTick      : CARDINAL );
TYPE
    AnOccupiedBy = (Nothing,AllTasks,ThisTask,Overlimit);
    ASegment     = (Top,Bottom);
    AGroupOfBarSegments = RECORD
                              Top    : AnOccupiedBy;
                              Bottom : AnOccupiedBy;
                          END;
VAR
    Column,
    Length,
    SLen            : CARDINAL;
    CurrentAvailability,
    LastAvailability: LONGINT;
    s               : ARRAY [0..maxcol+1] OF CHAR;
    s2              : ARRAY [0..maxcol+1] OF CHAR;
    Attributes      : ARRAY [0..maxcol+1] OF BITSET;
    BrightMode,
    DimMode         : avidmode;
    StartingX       : ascreenx;
    Bright,
    TaskColor,
    Dim,
    BackgroundAttribute,
    ForegroundAttribute     : BITSET;
    Attribute, OldAttribute : BITSET;
    OldIndex        : CARDINAL;
    C               : CHAR;
    Occupied        : AGroupOfBarSegments;


       (* Each character position can be used to represent more than
          just "on" or "off" because we can divide the character in 
          half horizontally and give each half a different color.
          Fill in the top and bottom segments of the bar segment
          record to describe how much of the character should be
          filled in, and what is there. 
          *)

    PROCEDURE WhatIsHere( VAR ProportionMatrix : AProportionMatrix; 
                          VAR Occupied         : AGroupOfBarSegments;
                              OccupiedBy       : AnOccupiedBy );
    VAR
        Percent : CARDINAL;
    BEGIN
        Percent := ProportionMatrix[ WhichResource, Column ];
        IF (Percent > HalfTick) THEN
            IF (y < StartY) THEN
                Occupied.Top := Overlimit;
            ELSE
                Occupied.Top := OccupiedBy;
            END;
            Occupied.Bottom := OccupiedBy;
        ELSIF (Percent > MinimumAmount) THEN
            Occupied.Bottom := OccupiedBy;
        END;
    END WhatIsHere;


BEGIN
    

        (* The general desire here is to draw a horizontal band of 
           a histogram.  This band can either be full, half full, or
           empty in the vertical direction, at each horizontal 
           position.

           Here's the trick: the character shown at each position is
           (almost) always the half-block.  We draw the appearance
           of empty, half-full or full by changing the foreground and
           background attributes of the character.
           *)

    LastAvailability := Availability[ WhichResource, HistStartsAt ];

    SLen      := 0;



    FOR Column  := HistStartsAt TO HistEndsAt DO
        INC(SLen);

           (* Has the availability changed since last time? *)

        CurrentAvailability := Availability[ WhichResource, Column ];

            (* Pick a color for the area behind the histogram, (DimMode)
               and a color for the histogram bars (BrightMode). *)
        IF (VacationList[ WhichResource, Column ]) OR 
           (CurrentAvailability <= 0L) THEN
            DimMode := videographvac;
            BrightMode := videographvac;
        ELSE
            BrightMode := videographbar;      (* Some bar showing *)
            IF (y <= Midpoint) THEN
                BrightMode := videographgrid; (* Bright, over 100% *)
            END;
            DimMode := videographlabel;       (* no bar showing. *)
        END;

           (* What is in this small vertical slice? *)
        Occupied.Top    := Nothing;
        Occupied.Bottom := Nothing;

           (* First, what is the total of all tasks at this date? *)

        WhatIsHere( VTics, Occupied, AllTasks );

           (* How much is used by the cursor task? *)

        WhatIsHere( CursorTaskTics, Occupied, ThisTask );

            (* Choose what will appear at this (x,y) position on the histogram,
               and also the color attribute. *)

        IF (y < StartY) AND (CurrentAvailability <> LastAvailability) THEN
                (* The availability changed since the last column?  If
                   we are drawing the top row, show the direction of the
                   change. *)
            IF (CurrentAvailability > LastAvailability) THEN
                C := UpArrow;
            ELSE
                C := DownArrow;
            END;
            Attribute := vidctrl[DimMode];
        ELSIF (Occupied.Bottom = Nothing)   THEN  (* No resource used here. *)
            Attribute := vidctrl[DimMode];
            IF (Column = TodayLine) THEN  (* Unless its the Today line  *)
                C      := ChartFont[9];
            ELSIF (y = Midpoint)    THEN  (* Or its the midline at a key date *)
                IF (CurrentAvailability = LastAvailability) THEN
                    C := MidLine[SLen];      (* No, put a tic mark. *)
                ELSIF (CurrentAvailability > LastAvailability) THEN
                    C := UpArrow;
                ELSE
                    C := DownArrow;
                END;
            ELSIF (y = EndY)       THEN  (* Or its the bottom line *)
                C := Underline;
            ELSE
                C := " ";
            END;
        ELSIF (Occupied.Top = Overlimit) THEN
            C := OverRange;
            Attribute := vidctrl[BrightMode];
        ELSE
                (* The Dim color is the background color from the dim mode.
                   We use it for the area behind the histogram.
                   The Bright color is the forground from the bright mode,
                   used for the histogram bar showing the sum of all tasks.
                   TaskColor comes from the foreground of the normal task
                   bar color, and shows the contribution of the cursor task. *)
            Dim    := BITSET(CARDINAL(vidctrl[DimMode] * BITSET(00F0H)) DIV 16);
            Bright := vidctrl[BrightMode] * BITSET(000FH);
            TaskColor := vidctrl[videonormal] * BITSET(000FH);     (* Normal task color. *)

            ForegroundAttribute := Dim;
            BackgroundAttribute := Dim;
            C := HalfBlock;
            CASE Occupied.Top OF
                AllTasks : BackgroundAttribute := Bright;
               |ThisTask : BackgroundAttribute := TaskColor;
               ELSE;
            END;
            CASE Occupied.Bottom OF
                AllTasks : ForegroundAttribute := Bright;
               |ThisTask : ForegroundAttribute := TaskColor;
               ELSE;
            END;

                (* Make an attribute whose background is the forground component
                   of BackgroundMode, and whose foreground is from ForegroundMode.
                   This isn't really clean, since this is going directly to
                   the screen driver and bypassing Kbio, but it is the only
                   mechanism we have to mix colors explicitly.  *)
            Attribute := BITSET( CARDINAL(BackgroundAttribute) * 16);
            Attribute := Attribute + ForegroundAttribute;
        END;

            (* Store the character and the color attribute into the
               accumulation arrays. *)

        Attributes[SLen] := Attribute;
        s[SLen]          := C; 
    
        LastAvailability := CurrentAvailability;
        
    END;



    s[0] := CHR(SLen);


    (* Now, find the color transitions and output them.  Try to reduce the
       total number of calls to PutString, as calls are more expensive than
       simple computes.
    *)
    SLen          := 1;
    StartingX     := HistStartsAt;
    OldAttribute  := Attributes[1];
    OldIndex      := 1;

    FOR Column := HistStartsAt+1 TO HistEndsAt DO
        INC(SLen);
        Attribute := Attributes[SLen];

        IF (Attribute <> OldAttribute) THEN
            SubStr(s,s2,OldIndex,SLen-OldIndex);
            PutStringWithAttribute(s2,StartingX, y, OldAttribute );
            OldIndex := SLen;
            OldAttribute := Attribute;
            StartingX     := Column;
        END;

    END;

    SubStr(s,s2,OldIndex,SLen-OldIndex);
    PutStringWithAttribute(s2,StartingX, y, OldAttribute );

    (*<TRACE
    CurrentAvailability := Availability[ WhichResource, HistStartsAt ];
    LongToString(CurrentAvailability,TraceS);
    PutString(TraceS,62,StartY,videonormal);
    PrintString(TraceS);
    CtoS(VTics[ WhichResource, HistStartsAt ], TraceS);
    PutString(TraceS,62,StartY-1,videonormal);
    PrintString(TraceS);
    SetString(TraceS,"Min = ");
    CtoS(MinimumAmount, TraceS2);
    ConcatLS(TraceS,TraceS2);
    CtoS(HalfTick, TraceS2);   ConcatS(TraceS,",");
    ConcatLS(TraceS,TraceS2);
    PutString(TraceS,62,StartY-2,videonormal);
    PrintString(TraceS);
    TRACE>*)


END DoOneBar;






PROCEDURE ShowHistogram( StartY,EndY   : ascreeny;
                         Resource      : AResourcePointer;
                         WhichResource : CARDINAL );
VAR
    Scale,
    HalfMore,
    NextAmount,
    TodayLine,
    Amount     : CARDINAL;
    Midpoint,
    y          : ascreeny;
BEGIN
    IF (Resource <> NIL) THEN
        Midpoint   := StartY + ((VHeight DIV 2) - 1);
        IF (AsOfDate >= HistStartDay) THEN
            TodayLine := (HistStartsAt + ((AsOfDate - HistStartDay) DIV CurrentLayoutPtr^.scale));
        ELSE
            TodayLine := MAXCARDINAL;
        END;
        Amount     := 0; 
        Scale      := (200 DIV VSlots) * 10;
        NextAmount := 0;                          (* AJL 7/17/91 *)
        y          := EndY;
        WHILE (y >= StartY) DO
            INC(NextAmount, Scale);
            HalfMore := NextAmount;
            INC(NextAmount, Scale);
            DoOneBar(WhichResource,StartY,EndY,Midpoint,
                     y, TodayLine, Amount,HalfMore);
            DEC(y);
            Amount := NextAmount;
        END;
        INC(Amount);
        DoOneBar(WhichResource,StartY,EndY,Midpoint,
                 y, TodayLine, Amount,Amount);
    END;
END ShowHistogram;



(* *******************************************************************

        Availability, In Use, and Res Availability averages

*)

TYPE

    AnItemHandle    = RECORD
        ExtHandle   : AnExtHandle;
        N           : ADateListIndex;
    END;

    ALocateDateProc = PROCEDURE (     (* DateList   *) AnExtHandle,
                                      (* StartDate  *) ADate,
                                      (* ItemSize   *) CARDINAL,
                                  VAR (* ItemHandle *) AnItemHandle,
                                      (* Context    *) ADDRESS );

    AGetEntryProc = PROCEDURE   (     (* DateList   *) AnExtHandle,
                                  VAR (* ItemHandle *) AnItemHandle,
                                  VAR (* StartDate  *) ADate,
                                  VAR (* EndDate    *) ADate,
                                  VAR (* Amount     *) LONGINT,
                                      (* Context    *) ADDRESS
                                ) : BOOLEAN;

    APeriodSummProc = PROCEDURE (     (* Period     *) CARDINAL,
                                      (* StartDate  *) ADate,
                                      (* Duration   *) ADuration,
                                      (* Context    *) ADDRESS
                                );






  (* ****** Availability sub procs ********* *)


TYPE
    AnAvailabilityContext = RECORD
        CurrentNumber   : CARDINAL;
        BiggestNumbers  : ARRAY [0..80] OF CARDINAL;
    END;



    (* These are the procs to handle the Availability List, a
       true DateList.
    *)

PROCEDURE AvailabilityGetEntryProc(     DateList   : AnExtHandle;
                                    VAR ItemHandle : AnItemHandle;
                                    VAR StartDate  : ADate;
                                    VAR EndDate    : ADate;
                                    VAR Amount     : LONGINT;
                                        Context    : ADDRESS
                                   ) : BOOLEAN;
VAR
    BStartDate,
    BEndDate    : ABigTime;
    Rate        : AnAvailabilityRate;
    ContextPtr  : POINTER TO AnAvailabilityContext;
    ok          : BOOLEAN;
BEGIN
    ok := GetDateListEntry( ADateList(DateList), ItemHandle.N,
                            BStartDate, BEndDate,
                            Rate );
    IF (ok) THEN
        Amount := (VAL(LONGINT,Rate.Amount)
                 * VAL(LONGINT,Rate.Percent));

        StartDate  := BigTimeToCalendarTime( BStartDate );
        EndDate    := BigTimeToCalendarTime( BEndDate   );

        ContextPtr                := Context;
        ContextPtr^.CurrentNumber := Rate.Amount;

        INC(ItemHandle.N);  (* Set up for next time. *)
    END;

    RETURN ok;

END AvailabilityGetEntryProc;




PROCEDURE DateListLocateDateProc(     DateList   : AnExtHandle;
                                      StartDate  : ADate;
                                      ItemSize   : CARDINAL;
                                  VAR ItemHandle : AnItemHandle;
                                      Context    : ADDRESS );
VAR
    BPeriodStart    : ABigTime;
BEGIN
    CalendarTimeToBigTime( StartDate, TRUE, BPeriodStart );
    LocateDateInDateList( ADateList(DateList),
                          BPeriodStart, ItemSize, ItemHandle.N );
END DateListLocateDateProc;




PROCEDURE AvailabilityPeriodSummProc(     Period        : CARDINAL;
                                          StartDate     : ADate;
                                          Duration      : ADuration;
                                          Context       : ADDRESS );
VAR
    ContextPtr  : POINTER TO AnAvailabilityContext;
BEGIN
    ContextPtr  := Context;
    WITH ContextPtr^ DO
        IF (Duration > 0) AND
           (CurrentNumber > BiggestNumbers[Period]) THEN
            BiggestNumbers[Period] := CurrentNumber;
        END;
    END;
END AvailabilityPeriodSummProc;



    (* AveragePeriodAvailability --

       Notes from AJL, Jan 28, 1991:

       PeriodAmounts seems to be an array containing the average quantity of
       the resource available during the period, scaled so that 1 @ 100% 
       is stored as "100," two at 100% would be stored as "200," etc.

       BiggestNumber seems to be an array that represents how many whole
       units of a resource are available during the period.  One at any
       percent would produce "1," two at any percent "2," etc.

    *)


PROCEDURE AveragePeriodAvailability(     Resource       : AResourcePointer;
                                         PeriodStart    : ADate;
                                         PeriodScale    : ADuration;
                                     VAR PeriodAmounts  : ARRAY OF LONGINT;
                                         NumberOfPeriods: CARDINAL;
                                     VAR BiggestNumber  : ARRAY OF CARDINAL
                                   );
VAR
    i       : CARDINAL;
    Amount  : LONGINT;
    UnitsAvailable : CARDINAL;
    Context : AnAvailabilityContext;
BEGIN

    IF (HIGH( PeriodAmounts ) <> HIGH( BiggestNumber )) THEN
        FatalError();
    END;

    IF (Resource^.Availability = ADateList(NIL)) THEN
        Amount := VAL(LONGINT, DefaultAvailabilityAmount * DefaultAvailabilityPercent); (* 7-Feb-91 TGS *)
        UnitsAvailable := DefaultAvailabilityAmount;
        FOR i := 0 TO HIGH(PeriodAmounts) DO
            PeriodAmounts[i] := Amount;       
            BiggestNumber[i] := UnitsAvailable;
        END;
    ELSE
        WITH Context DO
            CurrentNumber := 0;
            FOR i := 0 TO HIGH(BiggestNumbers) DO
                BiggestNumbers[i] := 0;
            END;
        END;

        AverageOverManyPeriods( AnExtHandle(Resource^.Availability),
                                PeriodStart, PeriodScale, PeriodAmounts,
                                NumberOfPeriods,
                                TSIZE(AnAvailabilityRate),
                                DateListLocateDateProc,
                                AvailabilityGetEntryProc,
                                AvailabilityPeriodSummProc,
                                ADR(Context)
                               );

        FOR i := 0 TO HIGH(BiggestNumber) DO
            BiggestNumber[i] := Context.BiggestNumbers[i];
        END;
    END;

END AveragePeriodAvailability;



    (* ******* Residual Availability ***** *)


TYPE
    AResAvailContext = RECORD
        AnyVacation  : BOOLEAN;
        Vacations    : ARRAY [0..80] OF BOOLEAN;
    END;



PROCEDURE CellContainingDateProc(     DateList   : AnExtHandle;
                                      StartDate  : ADate;
                                      ItemSize   : CARDINAL;
                                  VAR ItemHandle : AnItemHandle;
                                      Context    : ADDRESS );
BEGIN
        (* locate the cell which contains PeriodStart
        *)
    ItemHandle.ExtHandle := CellContainingDate( DateList, StartDate );

END CellContainingDateProc;




PROCEDURE CellGetEntryProc(     DateList   : AnExtHandle;
                            VAR ItemHandle : AnItemHandle;
                            VAR StartDate  : ADate;
                            VAR EndDate    : ADate;
                            VAR Amount     : LONGINT;
                                Context    : ADDRESS
                          ) : BOOLEAN;
VAR
    Cell        : AnAvailabilityCellPointer;
    CellHandle  : AnExtHandle;
    ContextPtr  : POINTER TO AResAvailContext;
    ok          : BOOLEAN;
BEGIN
    CellHandle := ItemHandle.ExtHandle;
    ok := (CellHandle <> AnExtHandle(NIL)) AND
          (LockObject(CellHandle, Cell) <> 0);

    IF (ok) THEN
        ok := (NOT Cell^.IsHeadCell);

        IF (ok) THEN
            StartDate               := Cell^.StartDate;
            EndDate                 := Cell^.EndDate;
            Amount                  := Cell^.AmountAvailable;
            ContextPtr              := Context;
            ContextPtr^.AnyVacation := (Cell^.ThisIsAVacation);
            ItemHandle.ExtHandle    := Cell^.NextCell;
        ELSE
            ItemHandle.ExtHandle    := AnExtHandle(NIL);
        END;

        ReleaseUnchangedObject(CellHandle);
    END;

    RETURN ok;

END CellGetEntryProc;





PROCEDURE ResAvailPeriodSummProc(     Period        : CARDINAL;
                                      StartDate     : ADate;
                                      Duration      : ADuration;
                                      Context       : ADDRESS );
VAR
    ContextPtr  : POINTER TO AResAvailContext;
BEGIN
    ContextPtr  := Context;
    WITH ContextPtr^ DO
        IF (Duration > 0) THEN
            Vacations[Period] := Vacations[Period] OR AnyVacation;
        END;
    END;
END ResAvailPeriodSummProc;






PROCEDURE ResidualAvailability(     Resource       : AResourcePointer;
                                    PeriodStart    : ADate;
                                    PeriodScale    : ADuration;
                                VAR PeriodAmounts  : ARRAY OF LONGINT;
                                    NumberOfPeriods: CARDINAL;
                                VAR AnyVacations   : ARRAY OF BOOLEAN
                               );
VAR
    i       : CARDINAL;
    Context : AResAvailContext;
BEGIN

    IF (HIGH( PeriodAmounts ) <> HIGH( AnyVacations )) THEN
        FatalError();
    END;

    IF (Resource^.ResidueAvailProfile = AnExtHandle(NIL)) THEN
        FOR i := 0 TO HIGH(PeriodAmounts) DO
            AnyVacations[i]  := FALSE;
            PeriodAmounts[i] := MAXLONGINT;
        END;
    ELSE
        WITH Context DO
            AnyVacation := FALSE;
            FOR i := 0 TO HIGH(Vacations) DO
                Vacations[i] := FALSE;
            END;
            IF (HIGH(Vacations) < HIGH(AnyVacations)) THEN
                FatalError();
            END;
        END;

        AverageOverManyPeriods( Resource^.ResidueAvailProfile,
                                PeriodStart, PeriodScale, PeriodAmounts,
                                NumberOfPeriods,
                                TSIZE(AnAvailabilityCell),
                                CellContainingDateProc,
                                CellGetEntryProc,
                                ResAvailPeriodSummProc,
                                ADR(Context)
                               );

        FOR i := 0 TO HIGH(AnyVacations) DO
            AnyVacations[i] := Context.Vacations[i];
        END;
    END;

END ResidualAvailability;




    (* ***** Varying Assignments ************** *)





PROCEDURE SmallLocateDateProc(     DateList   : AnExtHandle;
                                   StartDate  : ADate;
                                   ItemSize   : CARDINAL;
                               VAR ItemHandle : AnItemHandle;
                                   Context    : ADDRESS );
VAR
    N               : AVaryingAssgnListIndex;
BEGIN
        (* locate the cell which contains PeriodStart
        *)
    LocateDateInVaryingAssgnList( AVaryingAssgnList(DateList), StartDate, N );
    (* 22-Feb-91 TGS 
    IF (N = 0) THEN
        N := 1;
    END;
    *)
    ItemHandle.N := ADateListIndex(N);

END SmallLocateDateProc;




PROCEDURE SmallGetEntryProc(     DateList   : AnExtHandle;
                             VAR ItemHandle : AnItemHandle;
                             VAR StartDate  : ADate;
                             VAR EndDate    : ADate;
                             VAR Amount     : LONGINT;
                                 Context    : ADDRESS
                            ) : BOOLEAN;
VAR
    Rate        : REAL;
    ok          : BOOLEAN;
BEGIN
    IF (ItemHandle.N = ADateListIndex(0)) THEN
            (* 22-Feb-91 TGS Dummy up an assignment list entry that
                             ends when the first real one starts.
            *)
        INC(ItemHandle.N);
        ok := GetVaryingAssgnListEntry( AVaryingAssgnList(DateList),
                                        AVaryingAssgnListIndex(ItemHandle.N),
                                        StartDate, EndDate,
                                        Rate );
        EndDate     := StartDate;
        StartDate   := 0;
        Amount      := 0L;
    ELSE
        ok := GetVaryingAssgnListEntry( AVaryingAssgnList(DateList),
                                        AVaryingAssgnListIndex(ItemHandle.N),
                                        StartDate, EndDate,
                                        Rate );
        IF (ok) THEN
            INC(ItemHandle.N);  (* Set up for next time. *)
            Amount := RealToLong(Rate);
        END;
    END;

    RETURN ok;

END SmallGetEntryProc;





PROCEDURE NullPeriodSummProc(     Period        : CARDINAL;
                                  StartDate     : ADate;
                                  Duration      : ADuration;
                                  Context       : ADDRESS );
BEGIN
END NullPeriodSummProc;





PROCEDURE AssignmentTics( VAR Assignment     : AnAssignmentRecord;
                              PeriodStart    : ADate;
                              PeriodScale    : ADuration;
                          VAR PeriodAmounts  : ARRAY OF LONGINT;
                              NumberOfPeriods: CARDINAL );
VAR
    i       : CARDINAL;
BEGIN

    IF (Assignment.VaryingAssignment = AVaryingAssgnList(NIL)) THEN
        FOR i := 0 TO HIGH(PeriodAmounts) DO
            PeriodAmounts[i] := 0L;
        END;
    ELSE
        AverageOverManyPeriods( Assignment.VaryingAssignment,
                                PeriodStart, PeriodScale, PeriodAmounts,
                                NumberOfPeriods,
                                TSIZE(CARDINAL),
                                SmallLocateDateProc,
                                SmallGetEntryProc,
                                NullPeriodSummProc,
                                NIL
                               );
    END;

END AssignmentTics;











    (* ***********  Average Over Many Periods *********** *)


(* Compute the average of the item's amount over a number of time
   periods.

   Preconditions:
   
        - PeriodStart + (NumberOfPeriods * PeriodScale) MUST NOT
          EXCEED MAXCARDINAL.

        - HIGH(Periods) >= NumberOfPeriods.

        - DateList need not be a true DateList, but enough of
          one that treating it at a high level as one is ok.

   Postconditions:
   
        - Periods array is filled with the averages from the
          DateList passed.

   Input:

        DateList    Handle to the list of entries.  Shoudn't be NIL.
                    Need not be a "true" date list, although we treat
                    it that way here, as long as all the passed Procs
                    treat it properly.

        PeriodStart The start of the FIRST period in the Periods array.

        PeriodScale The size, in clock tics, of each period.

        NumberOfPeriods  The number of periods to gather data for.
                    Must be > 0.

        ItemSize    The size of each item in the DateList.

        LocateDateProc  Proc that finds the FIRST entry in the DateList
                    for a given small date.

        GetEntryProc Proc that gets an entry for the given DateList, and
                    Sets itself up to get the NEXT entry for that list.

        PeriodSummProc is called once for each non-zero duration period
                    when summing up amounts.

        Context     Flexible context area passed to the various Procs.

   Output:

        Periods     The array of amounts averaged over the period time.

*)
PROCEDURE AverageOverManyPeriods(     DateList        : ADateList;
                                      PeriodStart     : ADate;
                                      PeriodScale     : ADuration;
                                  VAR Periods         : ARRAY OF LONGINT;
                                      NumberOfPeriods : CARDINAL;
                                      ItemSize        : CARDINAL;
                                      LocateDateProc  : ALocateDateProc;
                                      GetEntryProc    : AGetEntryProc;
                                      PeriodSummProc  : APeriodSummProc;
                                      Context         : ADDRESS
                                );
CONST
    MaxPeriods      = 80;
VAR
    EndOfAllPeriods,
    StartOfPeriod,
    EndOfPeriod,
    StartDate,
    EndDate         : ADate;
    Duration        : ADuration;

    MaxNumberOfPeriods,
    Period,
    EndOfPeriodList : CARDINAL;

    Amount          : LONGINT;

    ItemHandle      : AnItemHandle;
    TotalDuration   : ARRAY [0..MaxPeriods-1] OF ADuration;

    StillGoing      : BOOLEAN;
BEGIN

    IF (NumberOfPeriods = 0)              OR
       (NumberOfPeriods > MaxPeriods)     OR
       (NumberOfPeriods > HIGH(Periods)+1) THEN
        FatalError();
    END;

    EndOfPeriodList := NumberOfPeriods - 1;

        (* Initialize the list to contains zeros. *)

    FOR Period := 0 TO EndOfPeriodList DO
        Periods[Period]       := 0L;
        TotalDuration[Period] := 0;
    END;

        (* Check that we aren't running off the end of the calendar. *)

    MaxNumberOfPeriods := (MaxDate - PeriodStart) DIV PeriodScale;
    IF ( NumberOfPeriods > MaxNumberOfPeriods ) THEN
        NumberOfPeriods := MaxNumberOfPeriods;
        EndOfPeriodList := NumberOfPeriods - 1;
    END;

    EndOfAllPeriods := PeriodStart + (NumberOfPeriods * PeriodScale);

    LocateDateProc( DateList,
                    PeriodStart,
                    ItemSize,
                    ItemHandle,
                    Context     );

    WHILE (GetEntryProc( DateList,
                         ItemHandle,
                         StartDate, EndDate,
                         Amount,
                         Context ))     AND
          (StartDate < EndOfAllPeriods) DO
        
        EndOfPeriod := PeriodStart;

          (* EndOfPeriod is StartOfPeriod for the next pass *)

        Period := 0;
        WHILE (Period      <= EndOfPeriodList) AND
              (EndOfPeriod <= EndDate)         DO

            StartOfPeriod := EndOfPeriod;     (* End of the last period *)
            INC( EndOfPeriod, PeriodScale );  (* End of this period     *)


            Duration := DurationInPeriod( StartOfPeriod,
                                          EndOfPeriod,
                                          StartDate,
                                          EndDate );
            IF (Duration > 0) THEN
                Periods[Period] := Periods[Period] + (Amount * VAL(LONGINT,Duration));
                INC(TotalDuration[Period], Duration );
            END;
            PeriodSummProc(Period,StartDate,Duration,Context);

            INC(Period);
        END;
    END;

    FOR Period := 0 TO EndOfPeriodList DO
        IF (TotalDuration[Period] <> 0) THEN
            Periods[Period] := Periods[Period]
                               DIV VAL(LONGINT,TotalDuration[Period]);
        END;
    END;

END AverageOverManyPeriods;





  (* ****************************************************** *)















 (* Compute Histograms - do the calcs for the histograms.

 *)
PROCEDURE ComputeHistograms( StartDate    : ADate;
                             Scale        : ADuration;
                             OnlyCursor   : BOOLEAN );


        (* Return a VTIC ratio, that is, a ratio * 100. 
        *)
    PROCEDURE Ratio( This, OverThis : LONGINT ) : CARDINAL;
    VAR
        L   : LONGINT;
        C   : CARDINAL;
    BEGIN
        IF (This <= 0L) THEN
            C := 0;
        ELSIF (OverThis = 0L) THEN
            C := MAX(CARDINAL);
        ELSE
            IF ((MAXLONGINT DIV 10000L) > This) THEN (* 9-Sep-91 TGS *)
                L := (((This * 10000L) DIV OverThis) + 5L) DIV 10L;    (* 12-Dec-90 RSC *)
                IF (L > 65535L) THEN
                    C := MAX(CARDINAL);
                ELSE
                    C := VAL(CARDINAL,L);
                END;
            ELSE
                C := MAX(CARDINAL);
            END;

        END;

        RETURN C;

    END Ratio;



    PROCEDURE AddToPercentages(     Rsrc         : CARDINAL;
                                    Task         : ATaskPtr;
                                VAR Assignment   : AnAssignmentRecord );
    VAR
        Offset,
        Loop            : CARDINAL;
        T               : CARDINAL;
        AssignmentUse   : ARRAY [MinPromptArea..maxcol+1] OF LONGINT;
    BEGIN
        Offset := (HistStartsAt - MinPromptArea);

        AssignmentTics( Assignment,
                        StartDate, Scale,
                        AssignmentUse,
                        SIZE(AssignmentUse) DIV TSIZE(LONGINT)
                      );

        FOR Loop := HistStartsAt TO HistEndsAt DO

            T := Ratio( AssignmentUse[Loop-Offset], Availability[ Rsrc, Loop ] );

            IF ((MAXCARDINAL - T) < CursorTaskTics[ Rsrc, Loop ]) THEN
                CursorTaskTics[ Rsrc, Loop ] := MAXCARDINAL;
            ELSE
                INC(CursorTaskTics[ Rsrc, Loop ], T);
            END;

        END;

    END AddToPercentages;







    (* Recalc a tree node.  If it is within the window.
    *)
    PROCEDURE RecalcATask( TaskNode     : ATreeNode );
    VAR
        Task            : ATaskPtr;
        j,
        Count           : CARDINAL;
        Assignments     : AnAssignmentArray;
    BEGIN
        IF (TaskNode <> ATreeNode(NIL)) THEN    (* RSC 8-Jul-89 *)
            Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
            IF (Task^.Plan.Assignments <> AnExtHandle(NIL)) THEN  (* Some assignments? *)
                Count := LockObjectArray( Task^.Plan.Assignments,
                                          Assignments, TSIZE( AnAssignmentRecord ) );
                WHILE (Count > 0) DO
                    DEC(Count);
(*$O-*)
                    WITH Assignments^[Count] DO
                        FOR j := 1 TO NumberOfResources DO
                            IF (Resource = Resources[j]) THEN
                                AddToPercentages( j, Task, Assignments^[Count] );
                            END;
                        END;
                    END;
(*$O=*)
                END;
                ReleaseUnchangedObject( Task^.Plan.Assignments );
            END;
            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode ); (* 11-Jan-88 LAA *)
            (* Moved here from two lines below on 28-Jul-89 RSC *)
        END;

    END RecalcATask;



    (* Recalc just the cursor node.
    *)
    PROCEDURE RecalcCursorTask();
    VAR
        i,
        j           : CARDINAL;
        CursorNode  : ATreeNode;

    BEGIN
        CursorNode    := GanttChart^.Methods^.GetCursorNode( GanttChart );
        SetRecalcCursor( CursorNode );
        FOR i := 1 TO NumberOfResources DO
            FOR j := HistStartsAt TO HistEndsAt DO
                CursorTaskTics[ i, j ] := 0;
            END;
        END;

        RecalcATask( CursorNode );

    END RecalcCursorTask;




    PROCEDURE RecalcFullSchedule();
    VAR
        Offset,
        i,
        j           : CARDINAL;
        InUse       : LONGINT;
        ResAvails   : ARRAY [MinPromptArea..maxcol+1] OF LONGINT;
        Vacations   : ARRAY [MinPromptArea..maxcol+1] OF BOOLEAN;
    BEGIN
        Offset := (HistStartsAt - MinPromptArea);

        FOR i := 1 TO NumberOfResources DO

            ResidualAvailability( Resources[i],
                                  StartDate, Scale,
                                  ResAvails,
                                  SIZE(ResAvails) DIV TSIZE(LONGINT),
                                  Vacations );

            FOR j := HistStartsAt TO HistEndsAt DO

                VacationList[i,j] := Vacations[j-Offset];

                IF (ResAvails[j-Offset] = MAXLONGINT) THEN (* 9-Sep-91 TGS fix index *)
                    InUse         := 0L;
                ELSE
                    InUse         := Availability[i,j] - ResAvails[j-Offset];
                END;
                VTics[i,j]        := Ratio(InUse, Availability[i,j]);
            END;
        END;

    END RecalcFullSchedule;






    PROCEDURE ComputeAvailabilities();
    VAR
        Offset,
        i, j            : CARDINAL;
        Avails          : ARRAY [MinPromptArea..maxcol+1] OF LONGINT;
        BiggestNumber   : ARRAY [MinPromptArea..maxcol+1] OF CARDINAL;
    BEGIN
        Offset := (HistStartsAt - MinPromptArea);

        FOR i := 1 TO NumberOfResources DO

            AveragePeriodAvailability( Resources[i],
                                       StartDate, Scale,
                                       Avails,
                                       SIZE(Avails) DIV TSIZE(LONGINT),
                                       BiggestNumber );

            FOR j := HistStartsAt TO HistEndsAt DO

                Availability[i,j]    := Avails[j-Offset];
                AvailabilityNum[i,j] := BiggestNumber[j-Offset];

            END;
        END;

    END ComputeAvailabilities;



BEGIN

    IF (OnlyCursor) THEN
        RecalcCursorTask();
    ELSE
        ShowCursor(FALSE,FALSE); (* Turn off cursor before recalc. *)
        ComputeAvailabilities();
        RecalcFullSchedule();
        RecalcCursorTask();
    END;

END ComputeHistograms;







  (* Find the various dates for the Underline in the middle row of each resource *)

PROCEDURE FindSignificantDates( StartCol : CARDINAL;
                                EndCol   : CARDINAL;
                                StartDay : ADate;
                                Scale    : ADuration;
                                TimeUnit : ADurationUnit );
VAR Loop,
    EndLoop : CARDINAL;
    Date    : ADate;
BEGIN
    Fill(MidLine," ",HIGH(MidLine));

    Date    := FindNextKeyDate( StartDay, TimeUnit );
    Loop    := (1 + ((Date - StartDay) DIV Scale));
    EndLoop := (EndCol - StartCol) + 1;
    WHILE (Loop < EndLoop) AND (Date < MAXCARDINAL) DO   (* 22-Jan-90 *)
        MidLine[ Loop ] := Underline;
        Date            := FindNextKeyDate( Date, TimeUnit );
        Loop            := (1 + ((Date - StartDay) DIV Scale));
    END;

END FindSignificantDates;





PROCEDURE ShowHistograms(    OnlyCursor : BOOLEAN );
VAR
    i              : CARDINAL;
    s              : ARRAY [0..maxcol] OF CHAR;
    s1             : ARRAY [0..5]      OF CHAR;
BEGIN
    IF (HistStartsAt = HistEndsAt) THEN
        RETURN;
    END;

    ComputeHistograms(    HistStartDay, CurrentLayoutPtr^.scale, OnlyCursor );

    IF (NOT OnlyCursor) THEN
        FindSignificantDates( HistStartsAt, HistEndsAt,
                              HistStartDay, CurrentLayoutPtr^.scale,
                              CurrentLayoutPtr^.scaleunit );
    END;

    FOR i := 1 TO NumberOfResources DO
        ShowHistogram(StartingRow[i],EndingRow[i],Resources[i],i);
    END;
END ShowHistograms;








TYPE
    AKeywordContext = RECORD
        Resource    : CARDINAL;
        DayPosition : ascreenx;  (* L-R Position on the screen *)
    END;


(* Provide keywords for the resource prompt area strings.

    Preconditions:

        Context points to AKeywordContext, which has been filled in.

        This is being called from within the "MakeSubstitutions" proc,
        and obeys its conditions and rules.

    Keywords:

        A   Day's Availability Number  (ALWAYS 3 CHARS, RIGHT JUSTIFIED)
        C   Cursor task's rate
        D   Day's rate
        P   Day's Availability Percent (ALWAYS 3 CHARS, RIGHT JUSTIFIED)
        R   Format the Resource Name field.
*)
PROCEDURE GetKeywords( VAR Keyword  : ARRAY OF CHAR;
                       VAR KeyValue : ARRAY OF CHAR;
                           Context  : ADDRESS );
VAR
    MyContext       : POINTER TO AKeywordContext;


    PROCEDURE CtoR( C : CARDINAL );
    CONST
        AVeryBigReal = 1.1E+16;
    VAR
        R   : REAL;
        s   : ARRAY [0..7] OF CHAR; (* nn.mm *) 
    BEGIN 
        IF (C = MAXCARDINAL) THEN (* 6-Sep-91 TGS *)
                (* Overflow time. Make RealFormat serve up asterisks instead
                   of a bogus number *)
            R := AVeryBigReal; 
        ELSE
            WITH MyContext^ DO
                R := ((LongToReal(Availability[Resource, DayPosition])
                      * FLOAT( C )) + 50.0) / 100000.0;
            END;
        END;

        FormatAsAmount( R, DefaultAmountFormat, s, HIGH(s), 0, 2, FALSE );
        Procustes( s, 5 );
        RJust(s); 
        Copy( s, KeyValue );

    END CtoR;


    PROCEDURE Cto3( C : CARDINAL );
    VAR
        s   : ARRAY [0..5] OF CHAR; (* nn.mm *)
    BEGIN
        CtoS( C, s );
        Procustes( s, 3 );
        RJust(s);
        Copy( s, KeyValue );
    END Cto3;


    PROCEDURE DoAvailPercent();
    VAR
        L   : LONGINT;
        C   : CARDINAL;
    BEGIN
        WITH MyContext^ DO
            C := AvailabilityNum[ Resource, DayPosition ];

            IF (C <> 0) THEN
                L := Availability[Resource, DayPosition] DIV VAL(LONGINT,C);
                IF (L  > 999L) THEN
                    C := 999;
                ELSE
                    C := VAL(CARDINAL,L);
                END;
            END;
        END;

        Cto3(C);

    END DoAvailPercent;



BEGIN

    MyContext := Context;

    WITH MyContext^ DO
        CASE CAP(Keyword[1]) OF
            "A" :   Cto3( AvailabilityNum[ Resource, DayPosition ] );

          | "C" :   CtoR( CursorTaskTics[  Resource, DayPosition ] );

          | "D" :   CtoR(          VTics[  Resource, DayPosition ] );

          | "P" :   DoAvailPercent();

          | "R" :   Copy( Resources[Resource]^.Name, KeyValue );

          | "V" :   IF (VacationList[ Resource, DayPosition ]) THEN
                        GetMessage(ModuleNumber+8, KeyValue);    (* Vacation *)
                    ELSE
                        SetLengthOf(KeyValue,0);
                    END;
        ELSE
        END;
    END;

END GetKeywords;





PROCEDURE ResourcePromptArea( WhichResource : CARDINAL;
                              WhichDay      : ascreenx;
                              StartingRow   : ascreeny  );
CONST
    Col1 = 1;   (* Indentation before our display.  Width of left border. *)
VAR
    Context       : AKeywordContext;
    i,MaxLen      : CARDINAL;
    Row           : ascreeny;
    S,
    Display       : ARRAY [0..MaxPromptArea]  OF CHAR;
BEGIN
        (* Compute the width of the display area.  Leave if too
           narrow.  *)

    MaxLen := HistStartsAt - Col1 - 1;   (* Max Size before histograms. *)

    IF (MaxLen < MinPromptArea) THEN
        RETURN;
    END;

        (* Display the text and amounts. *)

    WITH Context DO
        Resource    := WhichResource;
        DayPosition := WhichDay;
    END;

    FOR i := 1 TO 2 DO
        Copy( Line[i], S );
        MakeSubstitutions( S, HIGH(S),
                           GetKeywords, ADR(Context) );
            (* Make a display string that is filled-out with spaces. *)
        Fill(Display," ", MaxPromptArea );
        Overlay(Display,S,1,HIGH(Display));
        

        Row := StartingRow + (i - 1);

            (* Clip the string to within the left area. *)

        IF (MaxLen < LengthOf(Display)) THEN
            SetLengthOf(Display,MaxLen);
        END;

        PutString(  Display, 1, Row, videonormal);
    END;

END ResourcePromptArea;




PROCEDURE ShowAmounts(     XOff     : CARDINAL );
VAR
    i        : CARDINAL;
BEGIN
    FOR i := 1 TO NumberOfResources DO
        ResourcePromptArea( i, XOff, StartingRow[i]-1 );
    END;
END ShowAmounts;




(****************************************************************************
    DiscardRug  -   
        DiscardRug should be called when user deleted one of the  resources
    from the histogram.  Since PutRug will restore the previous cursor, an
    extra cursor may appear on the gantt view.
****************************************************************************)
PROCEDURE DiscardRug();
BEGIN
    WITH CursorInfo DO
        IF (RugTaken) THEN
            ThrowRug( Rug );
            RugTaken := FALSE;
        END;
    END;
END DiscardRug;




PROCEDURE ShowCursor( On, Resting : BOOLEAN );
VAR
    Midpoint,
    i, C : CARDINAL;
    x    : ascreenx;
    Mode : avidmode;
    s1,
    s    : ARRAY [0..19] OF CHAR;
BEGIN
    C := ((VHeight DIV 2) - 1);
    WITH CursorInfo DO
        IF (RugTaken) THEN
            PutRug( RugX,FirstScreenLine, RugX, LastScreenLine, Rug ); 
            RugTaken := FALSE;
        END;
        IF (On) THEN
            WITH CurrentLayoutPtr^ DO
                x := (GanttPosition + ((CursorDay - ChartStartDay) DIV scale));
            END;
            IF (x < HistEndsAt) AND (x >= HistStartsAt) THEN    (* 22-Jan-90 *)

                ShowAmounts(x);

                RugTaken := GetRug( x, FirstScreenLine, x, LastScreenLine, Rug );
                RugX     := x;

                IF (Resting) THEN
                    Mode := videorestingcursor;
                ELSIF (GanttChart^.Methods^.QueryScrollMode(GanttChart)) THEN   (* 21-Nov-89 RSC *)
                    Mode := videosecondarycursor;                               (* 21-Nov-89 RSC *)
                ELSE
                    Mode := cvideonormal;
                END;

                Fill(s,36C,1);

                FOR i := 1 TO NumberOfResources DO
                    Midpoint := StartingRow[i] + C;
                    PutString(s,x,Midpoint,Mode);
                END;

            END;
        END;
    END;

END ShowCursor;










PROCEDURE MouseInOurZone( VAR Event : AnEvent ) : BOOLEAN;
VAR
    ok  : BOOLEAN;
BEGIN
    WITH Event DO
        ok := (EventY >= FirstScreenLine) AND
              (EventY <= LastScreenLine) AND
              (EventX >= HistStartsAt) AND 
              (EventX <  HistEndsAt);       (* 22-Jan-90 RSC *)
    END;

    RETURN ok;

END MouseInOurZone;



    (* ------------------------------------------------------------
       Procedures to support searching for the next change in a 
       histogram.
     -------------------------------------------------------------- *)


(*<SEARCHMODE


PROCEDURE NextChangeDate( Resource : AResourcePointer; Date : ADate ) : ADate;
VAR
    CellHandle : AnExtHandle;
    Cell       : AnAvailabilityCellPointer;
    NextDate   : ADate;
BEGIN
    NextDate := MaxDate;
    IF (Date < MaxDate) THEN
        CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, Date);
        IF (CellHandle <> AnExtHandle(NIL)) THEN 
            IF LockObject(CellHandle, Cell) = 0 THEN 
                FatalError(); 
            END;
            NextDate := Cell^.EndDate;
            ReleaseUnchangedObject(CellHandle);
        ELSE
            ErrorPhrase(0);
        END;
    END;
    RETURN NextDate;
END NextChangeDate;



PROCEDURE PriorChangeDate( Resource : AResourcePointer; Date : ADate ) : ADate;
VAR
    CellHandle : AnExtHandle;
    Cell       : AnAvailabilityCellPointer;
    PriorDate  : ADate;
BEGIN
    PriorDate := MinDate;
    IF (Date > MinDate+1) THEN
        CellHandle := CellContainingDate(Resource^.ResidueAvailProfile, Date-1);
        IF (CellHandle <> AnExtHandle(NIL)) THEN 
            IF LockObject(CellHandle, Cell) = 0 THEN 
                FatalError(); 
            END;
            PriorDate := Cell^.StartDate;
            ReleaseUnchangedObject(CellHandle);
        ELSE
            ErrorPhrase(0);
        END;
    END;
    RETURN PriorDate;
END PriorChangeDate;


    (* NextInterestingDate -- Find the next date, in either the forward
                              or reverse direction, that an interesting 
                              change happens in the resources histograms.
    *)



PROCEDURE NextInterestingDate( Date : ADate; Forward : BOOLEAN ) : ADate;
VAR
    IDate, ChangeDate : ADate;
    Resource : AResourcePointer;
    i     : CARDINAL;
BEGIN
        (* In the forward direction, find the minimum of the change dates
           of the resources.  In the reverse direction, find the 
           maximum. *)

    IF (Forward) THEN
        IDate := MaxDate;
        FOR i := 1 TO NumberOfResources DO
            Resource := Resources[i];
            ChangeDate := NextChangeDate( Resource, Date );
            IF (ChangeDate < IDate) AND (ChangeDate > Date) THEN
                IDate := ChangeDate;
            END;
        END;
        IF (IDate = MaxDate) THEN    (* If we would just go to the end, don't move. *)
            IDate := Date;
            Burp();
        END;
    ELSE
        IDate := MinDate;
        FOR i := 1 TO NumberOfResources DO
            Resource := Resources[i];
            ChangeDate := PriorChangeDate( Resource, Date );
            IF (ChangeDate > IDate) AND (ChangeDate < Date) THEN
                IDate := ChangeDate;
            END;
        END;
        IF (IDate = MinDate) THEN    (* If we would just go to the end, don't move. *)
            IDate := Date;
            Burp();
        END;
    END;
    RETURN IDate;
END NextInterestingDate;

SEARCHMODE>*)




PROCEDURE HistogramActOnEvent( VAR Event : AnEvent; VAR Quit : BOOLEAN );
VAR
    DoRecalc,
    CursorOnly   : BOOLEAN;



    PROCEDURE ChangeCursorDateTo( Date : ADate );
    BEGIN
        IF (GanttChart^.Methods^.QueryScrollMode(GanttChart)) THEN
            GanttChart^.Methods^.SetScrollMode(GanttChart,FALSE);
        END;
        MChDay(Date);
        DisplayTheChart();
        AbsorbingMouseEvents := TRUE;
        CursorOnly := (HistStartDay = ChartStartDay);
        DoRecalc   := TRUE;
    END ChangeCursorDateTo;

BEGIN

    DoRecalc   := FALSE;
    CursorOnly := FALSE;

    CASE Event.EventCode OF

        HistKey              : DisplayControlForm( FALSE, Quit );
                               DoRecalc             := TRUE;
                               AbsorbingMouseEvents := FALSE;

      | MouseDouble          : WITH Event DO
                                   IF (EventY >= SeparatorLine) AND
                                      (EventY <= LastScreenLine) THEN
                                           (* If on the border, synch to task. *)
                                       DisplayControlForm( 
                                           Event.EventY = SeparatorLine,  (* Synch to task? *)
                                           Quit );
                                       DoRecalc             := TRUE;
                                   END;
                               END;
                               AbsorbingMouseEvents := FALSE;

      | HistSynchKey         : 
                               DisplayControlForm( TRUE, Quit );
                               DoRecalc             := TRUE;
                               AbsorbingMouseEvents := FALSE;

      | AlternateDisplayKey  : Quit := TRUE;

      (*<SEARCHMODE
      | RollLeft             :
                                   ChangeCursorDateTo(
                                       NextInterestingDate( CursorDay,
                                                            FALSE (* Forward *) ));

      | RollRight            :
                                   ChangeCursorDateTo(
                                       NextInterestingDate( CursorDay,
                                                            TRUE (* Forward *) ));
      SEARCHMODE>*)

      | MouseDown,
        MouseStillDown       : IF (MouseInOurZone(Event)) THEN
                                   ChangeCursorDateTo( ChartStartDay +
                                             ((Event.EventX - HistStartsAt)
                                             * CurrentLayoutPtr^.scale));
                                   (* 19-Mar-90 RSC Added this: *)
                               ELSE
                                   DoWeRecalc( Quit, DoRecalc, CursorOnly );
                               END;

      | MouseUp              : AbsorbingMouseEvents := FALSE;

                                  (* 19-Mar-90 RSC and this: *)
                               DoWeRecalc( Quit, DoRecalc, CursorOnly );

    ELSE
        DoWeRecalc( Quit, DoRecalc, CursorOnly );
    END;

    IF (DoRecalc) THEN
        IF (NOT CursorOnly) THEN
            ResynchHistogramsToGantt( Quit );
        END;
        ShowHistograms( CursorOnly );
    END;

END HistogramActOnEvent;















PROCEDURE ResynchHistogramsToGantt( VAR Quit : BOOLEAN );
VAR
    i, h, j          : CARDINAL;
    RsrcNode         : ATreeNode;
    ULine,
    s                : ARRAY [0..maxcol+1] OF CHAR;
    s1               : ARRAY [0..1]        OF CHAR;
BEGIN

 (* Resynch with the current chart layout, which may have changed. *)

    CurrentLayoutPtr := GanttChart^.Methods^.GetLayout( GanttChart );
    WITH CurrentLayoutPtr^ DO
        IF (NOT GanttShowing) THEN
            Quit := TRUE;
            RETURN;     (* must be done with us. *)
        END;
    END;

  (* Figure out how many resources, if any, there are. *)

    NumberOfResources := 0;
    FOR i := 1 TO MaxResources DO
        Copy(HistResource[i],s);
        TrimRear(s);
        IF (LengthOf(s) > 0) THEN
            RsrcNode := FindResourceByName( s );
            IF (RsrcNode = NIL) THEN
                Resources[i]      := NIL;
                HistResource[i,0] := 0C;  (* In case the resource went away *)
            ELSE
                INC(NumberOfResources);
                Resources[NumberOfResources] := RsrcNode^.Methods^.GetDataObject( RsrcNode );
                IF (i <> NumberOfResources) THEN
                    Copy(HistResource[i],HistResource[NumberOfResources]);
                    SetLengthOf(HistResource[i],0);
                END;
            END;
        ELSE
            Resources[i]      := NIL;
        END;
    END;

    VHeight := 4;  (* Bytes tall *)
    IF (NumberOfResources > 1) THEN   (* RSC 1/24/88 *)
        VHeight := 2;  (* Bytes tall *)
    END;

    IF (NumberOfResources = 0) THEN  (* Yes, do this AFTER setting VHeight! *)
        RETURN;                      (* Otherwise, ShowCursor may bomb! *)
    END;

 (* Figure out the (possibly new) screen dimensions *)

    VSlots            := VHeight * 2; (* resolution *)
    LastScreenLine    := maxrow - 1;
    FirstScreenLine   := (LastScreenLine - (NumberOfResources * (VHeight + 1))) + 1;
    SeparatorLine     := FirstScreenLine - 1;
    HistStartsAt      := CurrentLayoutPtr^.GanttPosition;
    HistStartDay      := ChartStartDay;
    IF (HistStartsAt > maxcol) THEN
        HistStartsAt  := maxcol;
    ELSE
        WHILE (HistStartsAt <= MinPromptArea) DO
            INC(HistStartsAt);
            INC(HistStartDay, CurrentLayoutPtr^.scale);
        END;
    END;

    IF (PrevNResources <> NumberOfResources) THEN
        DiscardRug();           (* Aug 25, 1989, KKC *)
        MakeNewGantt( SeparatorLine - 1 );
    END;

             (* Draw the top gray line and the name/amount/rate
                lines
             *)

    IF (HistStartsAt   <> OldHistStartsAt)    OR
       (PrevNResources <> NumberOfResources ) THEN

        PrevNResources  := NumberOfResources;
        OldHistStartsAt := HistStartsAt;

        ShowCursor(FALSE,FALSE); (* Turn off cursor before this. *)

        j := HistStartsAt - 1;

        Copy(Line[0], s);                  (* 25-Oct-90 RSC *)
        Procustes(s   ,j );                (* 25-Oct-90 RSC *)
        Fill(s1,   " ",1 );                (* 22-Jan-90 RSC *)
        Fill(ULine," ",HistEndsAt - HistStartsAt );

        PutString(s1,    0,            SeparatorLine, videodatebar );
        PutString(s,     1,            SeparatorLine, videodatebar );
        PutString(ULine, HistStartsAt, SeparatorLine, videodatebar );

        Fill(s, " ", j );    (* 25-Oct-90 RSC *)
        s[j] := 272C;

        FOR i := FirstScreenLine TO LastScreenLine DO
            PutString(s1,    0,            i, videodatebar    );
            PutString(s,     1,            i, videonormal     );
            PutString(ULine, HistStartsAt, i, videographlabel );
        END;

        Fill( ULine, Underline, HistStartsAt - 1 );
        ULine[HistStartsAt - 1] := 272C;

        h := FirstScreenLine; (* Allow for name bar *)
        FOR i := 1 TO NumberOfResources DO
            INC(h);
            StartingRow[i]  := h;
            INC(h, VHeight);
            EndingRow[i]    := h - 1;

            PutString(  ULine, 1, EndingRow[i], videonormal);

(*            FOR j := StartingRow[i]-1 TO EndingRow[i] DO*)
(*                PutString( s1, 0, j, videodatebar );*)
(*            END;*)

        END;
    END;

END ResynchHistogramsToGantt;







    (* SynchHistToTask -- Fill out the histogram form so that it
       will display the resource assignments of the cursor task. *)

PROCEDURE AddName( VAR Assignment : AnAssignmentRecord;
                       Context    : ADDRESS ):BOOLEAN;
VAR
    j : CARDINAL;
    i : POINTER TO CARDINAL;
BEGIN
    i := Context;

    IF (Assignment.Resource^.Type <> AccountingOnly) THEN
        IF (i^ < MaxResources) THEN
            INC(i^);
            Copy(Assignment.Resource^.Name, HistResource[i^] );
        END;
    END;
    RETURN TRUE;
END AddName;


PROCEDURE SynchHistToTask();
VAR
    CursorNode : ATreeNode;
    Task       : ATaskPtr;
    Assignments : AnExtHandle;
    i          : CARDINAL;  
BEGIN
    CursorNode    := GanttChart^.Methods^.GetCursorNode( GanttChart );
    IF (CursorNode = NIL) THEN
        RETURN;
    END;
    Task := CursorNode^.Methods^.LockFlexStorDataObject( CursorNode );
    Assignments := Task^.Plan.Assignments;
    CursorNode^.Methods^.UnlockFlexStorDataObject( CursorNode );  Task := NIL;

        (* Remove old names. *)

    FOR i := 1 TO MaxResources DO
        SetLengthOf(HistResource[i],0);
    END;

        (* Load the names of resources assigned to the cursor task. *)

    i := 0;
    ForEachAssignment( Assignments, AddName, ADR(i) );

END SynchHistToTask;





PROCEDURE DisplayControlForm(     SynchToTask : BOOLEAN;
                              VAR Quit : BOOLEAN );
VAR
    s       : ARRAY [0..29] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    ShowCursor(FALSE,FALSE); (* Turn off cursor before form. *)

    IF (SynchToTask) THEN
        SynchHistToTask();
        Quit := FALSE;
    ELSE
        SetString(s,"\TLFBASE(TLRHFORM)");                            (* 02-Mar-88 LAA *)

        ok := CallOverlayWithContext( s, NIL );
    END;

    ResynchHistogramsToGantt( Quit );
    Quit := (Quit OR (NumberOfResources = 0));
    IF (Quit) THEN
        RETURN;
    END;
    s[0] := 0C;
    Message(s);  (* Blank out any messages. *)

END DisplayControlForm;






PROCEDURE DoTLRHist();
VAR
    Quit    : BOOLEAN;
    SynchMode : BOOLEAN;


    PROCEDURE ReturnCheck( CheckInterlock : BOOLEAN );
    VAR
        s    : ARRAY [0..255] OF CHAR; (* Keep these off the stack of DoTLRHist *)
        s1   : ARRAY [0..29]  OF CHAR;
    BEGIN
        IF (CheckInterlock AND (HistInterlock = TRUE)) THEN
            GetMessage(ModuleNumber+5,s); (* "You already HAVE resource Histograms" *)
            Error(s);
            RETURN;
        END;
        WITH CurrentLayoutPtr^ DO
            IF (NOT GanttShowing) THEN
                GetMessage(ModuleNumber+6,s); (* No Gantt, no histograms. *)
                GetMessage(ModuleNumber+7,s1);
                WarningBox(s,s1,NoHelp);
            END;
        END;
        HistInterlock := FALSE;
    END ReturnCheck;

    PROCEDURE Init(VAR SynchMode : BOOLEAN);
    VAR
        s,s2  : ARRAY [0..25] OF CHAR; (* Keep these off the stack of DoTLRHist *)
        ContextPointer      : POINTER TO ARRAY [0..255] OF CHAR;
        i       : CARDINAL;
    BEGIN
            (* Read the symbols for the histogram from the phrases file. *)
        GetMessage( ModuleNumber + 1, s );
        DecodeString(s,s2);

        Underline  := s2[1];
        OverRange  := s2[2];
        UpArrow    := s2[3];
        DownArrow  := s2[4];
        HalfBlock  := s2[5];

        CursorInfo.RugTaken  := FALSE;
        PrevNResources       := 0;
        GMakeNewGanttLY      := 0;
        Quit                 := FALSE;
        AbsorbingMouseEvents := FALSE;
        OldHistStartsAt      := 0;
    
            (* 25-Oct-90 RSC Line 0 is a title line for the separator bar.
                             Line 1-2 are the lines PER RESOURCE on the histograms.
            *)
        GetMessage( ModuleNumber + 10, Line[0] ); (* "Name             In Use   Avail"    *)
        GetMessage( ModuleNumber + 11, Line[1] ); (* "*R(L)    * Task: *C(L)*"            *)
        GetMessage( ModuleNumber + 12, Line[2] ); (* "           Day : *D(L)* *A* @ *P*%" *)
    
            (* If the context parameter to us is "1", synchronize
               the resource list to the current cursor task. *)

        ContextPointer:= OverlayContext();   (* find out which tree they want *)
        IF (ContextPointer <> NIL) AND (ContextPointer^[1] = "1") THEN
            SynchHistToTask();
            SynchMode := TRUE;
        ELSE
            SynchMode := FALSE;
        END;

    END Init;

BEGIN
    IF (HistInterlock = TRUE) THEN
        ReturnCheck( TRUE );
        RETURN 
    END;
    HistInterlock        := TRUE;

    Init(SynchMode);

    ResynchHistogramsToGantt( Quit );
    IF (Quit) THEN
        ReturnCheck( FALSE );
        RETURN;
    END;

       (* If names are blank, and the user asked us to bring
          up histograms not synchronized to the cursor task,
          display the histogram names form. *)

    IF (NumberOfResources = 0) THEN
        IF (SynchMode) THEN
            Quit := TRUE;
        ELSE
            DisplayControlForm( FALSE, Quit );
        END;
        IF (Quit) THEN
            ReturnCheck( FALSE );
            RETURN;
        END;
    END;

        (* If there are resources, display them. *)

    ShowHistograms( FALSE );

    IF (NumberOfResources > 0) THEN
        HistogramsAreUp := TRUE;    (* 10-Sep-91 TGS *)
        MainLoop();
        HistogramsAreUp := FALSE;   (* 10-Sep-91 TGS *)
    END;

    WITH CursorInfo DO
        IF (RugTaken) THEN
            ThrowRug( Rug );
            RugTaken := FALSE;
        END;
    END;

    MakeNewGantt( GanttWEnd );

    ReturnCheck( FALSE );

END DoTLRHist;




BEGIN
    MidLine := "Program Copyright (c) 1989 Symantec Corporation.";

    OverlayID := ImAnInstallableOverlay(DoTLRHist, AnOverlayProc(NIL)); (* 19-Jan-88 LAA *)

    DoTLRHist();

END TLRHist.
