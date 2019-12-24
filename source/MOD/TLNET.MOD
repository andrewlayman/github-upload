MODULE TLNet;

(*$S+*)

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY
    
     9/17/87 RSC generic shell for synchronizing with the GANTT chart.
    18-Sep-87 LAA   Changes to make this the basic TLNET.
    09-Dec-87 LAA   Stripped out the main menu.  This overlay now just calls
                    the other two network overlays.
    10-Dec-87 LAA   Added code to use overlay contexts to find other overlays
                    to load.
    21-Jan-88 LAA   Put in the layout light.
    09-Feb-88 LAA   Adjusted for changes to Space.
    15-Feb-88 LAA   Allocate and deallocate memory here, instead of in
                    TLNShow and TLNBuild.
    16-Feb-88 LAA   Removed import of tlnbdata, because of tlncalc overlay.
    18-Feb-88 LAA   Cleaned up to make smaller.
    23-Feb-88 LAA   Made an installable overlay, and set up for printing from
                    the network view.
    29-Feb-88 EGK   Added ProceedWithReport procedure to allow for changing
                    of current layout before printing network report.
    03-Mar-88 LAA   Turn off select filters when going onto the network view.
    06-Mar-88 LAa   In DoTLShell, made it ask if you want to turn the select
                    filters off before turning them off, rather than after!
    02-Nov-88 LAA   Changed variable name InNetworkView to be ViewIsActive,
                    and introduced a new variable, KindOfView, to 
                    differentiate between the Tree and Network views.
                    This is a bit of a kludge;  we should do this in the
                    root, so all parts of TL can know what's active.
                    This mostly involved moving code around in the proc
                    DoReportFromView.
    04-Nov-88 LAA   Imported NetBData so that TLNCALC is small enough for it
                    and TLNBUILD to fix in the reserved layer.
    08-Nov-88 LAA   Merged two versions with the changes from 02 and 04 Nov.
    09-Nov-88 LAA   Fix of bug #8541, where wrong version of reports were
                    coming out if you chose to print while within the Tree or
                    Network views.
    10-Nov-88 LAA   In DoTLShell, I moved the check for select filters into
                    the main loop, so that it can detect this condition after
                    reading in a schedule while already in the net view.
    30-Nov-88 LAA   Made changes to try and decrease module size.
     6-Jan-89 RSC   Moved "AnOverlayProc" reference.
     2-Feb-89 RSC   Changed "ParseCallChain" to "ParseString"
    21-Feb-89 EGK   Moved initialization of NetworkDone to TLNetMain.  It
                    was undefined if you did a network report.
    10-Apr-89 RSC   Support for the Spreadsheet View: Go to Non-ScrollingGantt
                    mode while network is running.
    27-Apr-89 WKH/
              CMH   Deallocate network memory if PackageOK is FALSE.
    19-Jun-89 AJL   Removed FiltersOn boolean, replaced by 
                    SetRevealFilterDisabled, and QueryRevealFilterOn.
    29-Jun-89 WKH   Import GaGa to try to fix VersionConflict problem.
    28-Jan-89 KKC   Set up CurrentActiveView.
    03-Aug-89 LAA   Import NetworkData instead of NetWorkData.
    10-Aug-89 KKC   Add copyright message.
    25-Aug-89 EGK   Wrote FiltersOK procedure so the view and the report
                    can share the dialog allowing select filters to be
                    turned off.
    29-Aug-89 EGK   Moved setting of ViewIsActive to DoTLShell, so that
                    if DoTLShell fails (because of the interlock), we
                    won't mistakenly set ViewIsActive to FALSE.
    21-Sep-89 LAA   Removed the import of NetBData.  It was moved here just
                    to decrease the size of the stuff in the reserved layer,
                    but since Ed's changes which downsized that stuff, we have
                    some room.
    02-Oct-89 EGK   Set PackageOK to FALSE if we fail because of the
                    interlock flag.  If we are being called to do a graph,
                    that will tell the rest of our package not to run.
    02-Nov-89 EGK   In DoTLNetReport, check PackageOK and abort if FALSE.
                    That allows the user to break out of the calculation
                    without running TLNPRINT (which might print garbage).
    14-Nov-89 EGK   Another fix like the one of 10/2/89.  If FiltersOK
                    returns FALSE, then also set PackageOK to FALSE so that
                    the TLGS overlays won't run either.
    22-Nov-89 EGK   Yet another version of the above fixes.  If
                    CallOverlayWithContext returns FALSE (out of memory,
                    for example), set PackageOK to FALSE, so that the
                    TLGS overlays won't run.
    27-Nov-89 EGK   Rewrote DoTLShell to do everything it used to do, plus
                    everything that DoTLNetReport and DoReportFromView used
                    to do.  DoTLShell is now re-entrant and can do any of
                    the reports or graphs while any view is up.  For those
                    cases when it can't be run, put up more specific
                    messages about which combinations aren't allowed.
---------------------------------------------------------------------------*)


FROM AccessMatrix           IMPORT
    (* PROC *)                  ClearDrawingMatrix;

FROM Allocs                 IMPORT
    (* VAR *)                   TaskTree;

FROM Chart                  IMPORT
    (* VAR *)                   GanttChart;

FROM ChartControl           IMPORT AChartState, ChartState, AChartStateSet,
                                   SetState, UnSetState, DisplayTheChart;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Error, Message, MultipleChoiceBox,
                                ContinuationBox, FatalError;
(* <DEBUG>
FROM ErrorUtil              IMPORT
                                PrintSMsg;
   <DEBUG> *)
                                
FROM ExportLinkage          IMPORT
    (* PROC *)                  ParseAFlag;

FROM Filters                IMPORT
    (* PROC *)                  Filter, ShowFilterLight,
                                SetRevealFilterDisabled, QueryRevealFilterOn;

FROM GaGa                   IMPORT
    (* PROC *)                  GetGaGaMessage;  (* 29-Jun-89 WKH *)

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineShowing;

FROM HistStat               IMPORT HistInterlock;

FROM Kbio                   IMPORT maxrow, maxcol, ascreenx, ascreeny,
                                   avidmode, PutString, EraseLn,
                                   GetAnyCode, PutAttribute,
                                   BreakRequested,
                                   PushCode, ClearBreak;

FROM Lights                 IMPORT
    (* TYPE *)                  ALight,
    (* VAR *)                   ActiveLightRegion,
    (* PROC *)                  InstallLight, RemoveLight, DisplayLight;

FROM LStrings               IMPORT SetString, SubStr, ConcatS, ConcatLS, CtoS,
                                   Copy, Insert, Procustes, TrimFront, TrimRear, 
                                   Compare, LJust, Overlay, TStringToLString,
                                   LengthOf, SetLengthOf, Fill, Upshift,
                                   Search;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* VAR  *)                  PackageOK,
    (* PROC *)                  OverlayContext, CallOverlayWithContext,
                                CallOverlay, ImAnInstallableOverlay;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM NetLayouts             IMPORT
    (* VAR *)                   NormalLayoutActive, NetworkLight,
    (* PROC *)                  DisplayNetworkLight;

FROM NetMemory              IMPORT
    (* PROC *)                  AllocNetMemory, DeAllocNetMemory;

FROM NetStatic              IMPORT  
    (* VAR *)                   NetworkDone, EnoughMemory;

FROM NetworkData            IMPORT
    (* TYPE *)                  AnActiveViewType,
    (* VAR  *)                  CurrentActiveView;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM Words                  IMPORT
    (* PROCS *)                 ParseString;


CONST
    ModuleNumber            = 20200;  (* For GetMessage *)  (* ?????????????????? *)
    NetworkLightPriority    = 80;

TYPE
    AViewType           = (PertType, TreeType, HistogramType);
    ANetMode            = (ViewMode, ReportMode, GraphMode);

VAR
    OverlayID          : AnOverlayID;

    ViewIsActive       : BOOLEAN;
    KindOfView         : AViewType;



PROCEDURE AppendKeywords (    NetType       : AViewType;
                              NetMode       : ANetMode;
                          VAR s             : ARRAY OF CHAR );
VAR
    s2              : ARRAY [0..30] OF CHAR;
BEGIN
    ConcatS (s, " ");
    GetMessage (ModuleNumber+10+ORD(NetType), s2);
    ConcatLS (s, s2);
    ConcatS (s, " ");
    GetMessage (ModuleNumber+13+ORD(NetMode), s2);
    ConcatLS (s, s2);
END AppendKeywords;



PROCEDURE WarnAbout(    Problem         : CARDINAL;
                        ViewType        : AViewType;
                        NetMode         : ANetMode  );

VAR
    s                   : ARRAY [0..255] OF CHAR;

BEGIN                   (* WarnAbout *)

    GetMessage(Problem, s);
    AppendKeywords (ViewType, NetMode, s);
    ConcatS (s, ".");
    Error(s);

END WarnAbout;





PROCEDURE FiltersOK ( ViewType      : AViewType;
                      NetMode       : ANetMode  ) : BOOLEAN;
VAR
    s               : ARRAY [0..99] OF CHAR;
    Title           : ARRAY [0..10] OF CHAR;
BEGIN
    IF (QueryRevealFilterOn()) THEN

        GetMessage (ModuleNumber+4, s);
        AppendKeywords (ViewType, NetMode, s);
        ConcatS (s, ".");
        SetLengthOf (Title, 0);
        IF (NOT ContinuationBox (s, Title, NoHelp)) THEN
            RETURN FALSE;
        END;
        SetRevealFilterDisabled();
        Filter();
        ShowFilterLight();
        UnSetState(Showing);
        DisplayTheChart();
    END;

    RETURN TRUE;
END FiltersOK;




PROCEDURE ProceedWithReport() : BOOLEAN;

VAR
    Result                  : BOOLEAN;
    s                       : ARRAY [0..80] OF CHAR;
    Title                   : ARRAY [0..1] OF CHAR;
    Prefix                  : ARRAY [0..20] OF CHAR;
    MenuString              : ARRAY [0..50] OF CHAR;
    Selection               : CARDINAL;
    OverlayName             : ARRAY [0..11] OF CHAR;

BEGIN

    s := "Program Copyright (c) 1989 Symantec Corporation.";

    GetMessage (ModuleNumber+20, s);                (* "Ready?" *)
    SetLengthOf (Title, 0);
    GetMessage (ModuleNumber+22, Prefix);           (* "Options:" *)
    GetMessage (ModuleNumber+23, MenuString);       (* "Go,Choose layout,Quit" *)

    Selection := 1;
    LOOP
        Result := MultipleChoiceBox (s, Title, NoHelp, Prefix,
                                     MenuString, Selection);
        IF (NOT Result) OR (Selection = 3) THEN
            RETURN FALSE;
        ELSIF (Selection = 2) THEN
            SetString (OverlayName, "TLNETLIS");
            IF (CallOverlay(OverlayName)) THEN END;
        ELSIF (Selection = 1) THEN
            RETURN TRUE;
        END;
    END;

END ProceedWithReport;



    (*  DoTLShell --    Do all the work needed to run ANY kind of network
                        function (PERT view, Tree Report, PERT Graph, etc.).
                        The specific action is defined by NetType and
                        NetMode, and the type of view that's already active
                        (if any) is defined by the (global to this module)
                        ViewIsActive and KindOfView.
    *)


PROCEDURE DoTLShell (    NetType        : AViewType;
                         NetMode        : ANetMode;
                     VAR CallChain      : ARRAY OF CHAR );
VAR 
    s1                      : ARRAY [0..1]  OF CHAR;
    OverlayName             : ARRAY [0..81] OF CHAR;
    Context                 : ARRAY [0..81] OF CHAR;
    i                       : CARDINAL;
    Flag                    : CHAR;
    NeedToAllocate          : BOOLEAN;
    OldScrollMode           : BOOLEAN;
    OldActiveView           : AnActiveViewType;

BEGIN

    SetLengthOf(s1, 0);    (* Clear the message area. *)
    Message(s1);

    IF (NetMode = ViewMode) THEN
        ViewIsActive := TRUE;                       (* 23-Feb-88 LAA *)
        HistInterlock := TRUE;
        KindOfView := NetType;
        GanttChart^.Methods^.SetShowing (GanttChart, ShowTaskStats);
    END;

        (*  We need to allocate network memory if:
                (1) we're bringing up a view from scratch, OR
                (2) we're running a graph or report when no view is active.
        *)
    NeedToAllocate := (NetMode = ViewMode) OR (NOT ViewIsActive);

    IF (NeedToAllocate) THEN
        EnoughMemory:=FALSE;
        AllocNetMemory();
        NormalLayoutActive := TRUE;
    END;

        (*  We could fail at this point if we ran out of memory (assuming
            we had to allocate it at all).  *)
    IF (NOT NeedToAllocate) OR (EnoughMemory) THEN

        NetworkDone := FALSE;

        IF (NetMode = ViewMode) THEN
            InstallLight(ActiveLightRegion, NetworkLightPriority, 10, 10, NetworkLight);
            DisplayNetworkLight();
        END;

        OldActiveView := CurrentActiveView;
        CurrentActiveView := Pertview;
        OldScrollMode := GanttChart^.Methods^.QueryScrollMode( GanttChart ); (* RSC 10-Apr-89 *)
        GanttChart^.Methods^.SetScrollMode( GanttChart, FALSE ); (* RSC 10-Apr-89 *)

        LOOP
            IF (NOT FiltersOK (NetType, NetMode)) THEN    (* 8/25/89 EGK *)
                PackageOK := FALSE;                     (* 11/14/89 EGK *)
                EXIT;
            END;

            i := 1;
            ParseAFlag(CallChain, Flag, i);

                (*  If we're doing a report and the view of that same type
                    is already up, then skip the overlay that does the
                    calculations (e.g., TLNCALC or TLNTREE).  If we're doing
                    any type of graph, or a report of a different type than
                    the one that's already up, let those overlays run but
                    notify the existing view that it needs to recalculate
                    itself.  *)

            IF (ViewIsActive) THEN
                IF (NetMode = ReportMode) AND (NetType = KindOfView) THEN
                    ParseString(CallChain, i, OverlayName);
                    ParseString(CallChain, i, Context);
                ELSIF (NetMode <> ViewMode) THEN
                    SendNotices (NetworkSettingChange, AfterActing, NIL);
                    ClearDrawingMatrix();
                END;
            END;

            WHILE (i <= LengthOf(CallChain)) DO
                ParseString(CallChain, i, OverlayName);
                ParseString(CallChain, i, Context);
                IF (LengthOf(OverlayName) > 0) THEN
                    IF (NOT CallOverlayWithContext(OverlayName, ADR(Context))) THEN
                        PackageOK := FALSE;     (* 11/22/89 EGK *)
                    END;
                    IF (NetworkDone) OR (NOT PackageOK) THEN
                        EXIT;
                    END;
                END;
            END; (*while*)

            IF (NetMode <> ViewMode) THEN
                EXIT;                   (* Don't loop if Report or Graph *)
            END;

        END; (*loop*)

        GanttChart^.Methods^.SetScrollMode( GanttChart, OldScrollMode ); (* RSC 10-Apr-89 *)
        CurrentActiveView := OldActiveView;

        IF (NeedToAllocate) THEN
            DeAllocNetMemory();
        END;

    ELSE
        NetworkDone:= TRUE;
        WarnAbout (ModuleNumber, NetType, NetMode);
    END;

    IF (NetMode = ViewMode) THEN
            (* Do the necessary cleanup after a view exits  *)
        GanttChart^.Methods^.SetShowing (GanttChart, ShowEverything);
        UnSetState(Showing);
        DisplayTheChart();
        RemoveLight(NetworkLight);
        HistInterlock := FALSE;
        ViewIsActive := FALSE;
    ELSIF (ViewIsActive) AND (NetworkDone) THEN
            (*  A view is active, but the report or graph has somehow set
                NetworkDone to TRUE.  That isn't fair, because NetworkDone
                is global, and we want the existing view to stay up (it will
                set NetworkDone to TRUE when it really wants to leave).  So
                Set NetworkDone back to FALSE here.     *)
        NetworkDone := FALSE;
    END;

END DoTLShell;


    (*  PermitRequest --    Figure out whether it's possible to do what
                            the user wants (specified by NetType and NetMode).
    *)


PROCEDURE PermitRequest (   NetType     : AViewType;
                            NetMode     : ANetMode  ) : BOOLEAN;
VAR
    s                   : ARRAY [0..255] OF CHAR;
    OK                  : BOOLEAN;
BEGIN
    IF (ViewIsActive) THEN

            (*  Are they trying to run the view that's already up?
                If so, just return.  *)
        IF (NetMode = ViewMode) AND (KindOfView = NetType) THEN
            RETURN FALSE;
        END;

            (*  If a view is up, allow anything that isn't another kind
                of view.    *)
        OK := (NetMode <> ViewMode);
    ELSIF (HistInterlock) THEN

            (*  If histograms are up, allow anything as long as it isn't
                another type of view (i.e., all reports and graphs)    *)
        KindOfView := HistogramType;
        OK := (NetMode <> ViewMode);
    ELSE
        OK := TRUE;     (* No view is up already, so allow anything *)
    END;

        (*  If we rejected their request, tell them why.  *)

    IF (NOT OK) THEN
        GetMessage (ModuleNumber+1, s);     (* "Sorry, can't run the" *)
        AppendKeywords (NetType, NetMode, s);
        ConcatMessage (s, ModuleNumber+2);  (* " from the" *)
        AppendKeywords (KindOfView, ViewMode, s);
        ConcatMessage (s, ModuleNumber+3);  (* ".  Type / Views Gantt" *)
        Error (s);
        RETURN FALSE;
    END;

        (*  Gotta have some tasks to be able to do anything.    *)

    IF (TaskTree^.Methods^.GetFirst (TaskTree) = NIL) THEN
        WarnAbout (ModuleNumber+5, NetType, NetMode);
        RETURN FALSE;
    END;

        (*  Can't run with a select filter on.  *)

    IF (NOT FiltersOK (NetType, NetMode)) THEN
        RETURN FALSE;
    END;

        (*  Put up the report dialog, if they're doing a report.    *)

    IF (NetMode = ReportMode) THEN
        IF (NOT ProceedWithReport()) THEN
            RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END PermitRequest;



PROCEDURE TLNetMain();

VAR
    ContextPointer      : POINTER TO ARRAY [0..255] OF CHAR;
    NetType             : AViewType;
    NetMode             : ANetMode;

BEGIN                       (* TLNetMain *)

    ContextPointer:= OverlayContext();   (* find out which tree they want *)
    IF ContextPointer <> NIL THEN

        CASE ContextPointer^[1] OF
            'P' :
                NetType := PertType;
        |   'T' :
                NetType := TreeType;
        ELSE
            FatalError();       (* Not PERT or tree? *)
        END;

        CASE ContextPointer^[2] OF
            'V' :
                NetMode := ViewMode;
        |   'R' :
                NetMode := ReportMode;
        |   'G' :
                NetMode := GraphMode;
        ELSE
            FatalError();       (* Not View, Report, or Graph? *)
        END;

        IF (PermitRequest (NetType, NetMode)) THEN
            DoTLShell (NetType, NetMode, ContextPointer^);
        ELSE
            PackageOK := FALSE;
        END;
    END;

END TLNetMain;



BEGIN

    ViewIsActive := FALSE;                                        (* 23-Feb-88 LAA *)

    OverlayID := ImAnInstallableOverlay(TLNetMain, AnOverlayProc(NIL));
    TLNetMain();

END TLNet.
