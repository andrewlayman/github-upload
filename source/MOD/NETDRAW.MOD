IMPLEMENTATION MODULE NetDraw;

    (*  MODIFICATION HISTORY
        23-Feb-88 LAA   Intercepted help key so we can give help about the
                        network view when it's up.
        29-Feb-88 LAA   Changed location of the QuitDammit code, so we don't
                        get a Burp when Ctrl-F8 is returned from the Gantt
                        menus.
        03-Mar-88 LAA   Redetermine screen placement after a /, because doing
                        a report may change the layout in effect.  Put 409 and
                        440 into allowable codes, as they are generated from
                        the menu for /Schedule Erase and /Filter Clear.
                        Cleaned up the procedure which receives notices.
        04-Mar-88 LAA   Prevent the HistKey from being processed when it comes
                        from the main menu, since there it means to bring up
                        the histogram view.
                        Added changes which Carol EMailed up in the evening.
        06-Mar-88 LAA   Enabled PrjtNotesKey, and made it burp when you
                        ask for resource histograms from the main menu.
        09-Mar-88 EGK   When handling tab keys, compare against original
                        position to prevent endless looping.
        10-Mar-88 LAA   Commented out the animation stuff, and forced the
                        network layout list overlay into the reserved layer.
        31-Mar-88 LAA   Changed the cursor mode to cvideonormal.
         5-May-88 RSC   Added TLG support to the main loop.
        23-Jun-88 LAA   Changed ReportsKey to allow selection of type of tree
                        chart.
        06-Jul-88 LAA   Notices of ScheduleSort cause redrawing.  Necessary
                        for the tree view.
        13-Jul-88 CMH   Fixed drawing order bug where cursor bar under
        TREE BUG FIX    master task was sometimes split, somtimes solid.
        13-Oct-88 CMH   Changed existing calls to GetCell to GetCellInfo,
           SPIKE        updated any direct references to SnetMatrix to the
          ENHANCE       function call, for the net character drawing matrix
                        scheme.
        19-Oct-88 CMH   Added call to new DrawMasterTaskExtension, a utility
           SPIKE        to get either master task outline charaters or an
          ENHANCE       extended master task name characters. Changed edit
                        key to refresh screen (was cell refresh) to correctly
                        update new long master task names.  Split off insert
                        key to act as always.
        21-Oct-88 CMH   (14-Sep-88) Changed call to GetBoxSize to take
           TLGS         the layout pointer as a parameter so it can be used
                        by SPIKE and TLGS.
        22-Nov-88 LAA/CMH   In a loop, a long task name was overwriting task
                            boxes to the right of it.
        24-May-89 WKH   Constants from Actions now come from Keys
         8-Jun-89 EGK   Changed names of notices that NetReceiveNotices
                        responds to, as per our new object-specific notices.
        14-Jun-89 KWC   Put in test for invisible tasks
        22-Jun-89 KWC   Removed use of the ChildrenCruncher procedure
        23-Jun-89 CMH   Added critical path dependency line color
        03-Jul-89 LAA/CMH Changed occurances of count to XX.
        03-Jul-89 EWK   Changed NetReceiveNotices to use the proper step
                        for responding to AddATask and AddAnEdge.
         5-Jul-89 KWC/CMH Added indicator of phantom task to Utility array
        10-Jul-89 CMH   Put TAB keys back into pert view.  Moved code from
                        NetAfter into NetReceiveNotices to handle adding
                        and deleting of dependencies.
        13-Jul-89 CMH   Put OptionsMenuKey into a category that causes a 
                        recalc in case the person changed the pert style.
                        Modified SetCursorInMiddle procedure to only position
                        cursor in the direction that changed instead of both.
                        Made F2 and ctrlF2 work the same for Pert and 
                        Tree views.  Improved display of new Pert/Tree view
                        status lines to steal procedure vector instead of
                        blanking Gantt view first and displaying Pert/Tree
                        view banner next.
        14-Jul-89 CMH   Allow **+ and **- at all times, before could only
                        happen while on a task.
        24-Jul-89 EGK   Removed redundant code in ShowNet that was redrawing
                        summary task frames twice.  Reset PackageOK in
                        MainLoop so that if an overlay sets PackageOK to
                        FALSE, the network view can keep running afterwards.
                        Changed "PrjtNotesKey" to "GotoWBSKey".
        25-Jul-89 KWC   Adjusted calculation of "area".
        31-Jul-89 EGK   Put back call to DrawMasterTaskExtension, but only
                        call it if the master task cell is off-screen.
                        Included GotoWBSKey in the case of keys that update
                        the cursor in NetAfter.
        25-Jul-89 CMH   Now importing ALLOCATE from Space.
         1-Aug-89 CMH   Removed reference to PrjtNotesKey which is no 
                        longer exported from Keys.
         4-Aug-89 CMH   Added call to GetCursorTaskRowandCol after IRAddDep
                        and IRDelDep so cursor goes back to the task it was
                        on last, not the space created by incremental redraw.
        21-Aug-89 CMH   Fixed ShowNet where critical path color was expanding
                        on master task outlines.
                        Now using GetRecordedEvent for the RepeatKey.
                        Moved key procedures to new module, NetKeys.
        28-Aug-89 CMH   Tree View bug fixes : 1) don't LookForAParent in the
                        Tree View, just return the current task, 2) don't call
                        incremental redraw of dependencies in the tree view.
        29-Aug-89 EGK   Check for invisible tasks before calling the
                        incremental draw routines.  Disabled incremental
                        redraw for dependencies, for beta release.
        30-Aug-89 CMH   Removed special handling of undo and redo keys, now 
                        relying on notices.
         5-Sep-89 EGK   Took out processing of OptionsMenuKey and included
                        NetworkSettingChange in the list of notice types
                        that cause a redraw.
         6-Sep-89 CMH   Moved BoxString, MasterTaskExpand, BoxExpand, 
                        GetMasterTaskLabelWidth, and DrawMasterTaskExpansion
                        from NetUtility to new module NetTaskDraw, isolating
                        report printing data and code from TLNBUILD and 
                        graphics. 
         8-Sep-89 CMH   Removed MasterTaskWidth variable;
        11-Sep-89 EGK   Added OptionsMenuKey to the list of keys that
                        "always work".
        14-Sep-89 EGK   Disabled the dependency-changing keys in the
                        tree view.  Removed the TreeControl module, which
                        is no longer used.
        21-Sep-89 LAA   Removed all reference to Animation.
        24-Sep-89 EGK   Set the scroll mode to FALSE before getting each
                        event.  This makes darn sure that if the next event
                        is ChngTskKey, we won't go into spreadsheet editing
                        mode.
        27-Sep-89 EGK   Moved the setting of PackageOK to AFTER the Gantt
                        chart has processed the event.  This ensures that
                        even if something sets PackageOK to FALSE, TLNET
                        can keep running (we use NetworkDone to tell TLNET
                        that we're really finished).
        28-Sep-89 EGK   If HaveInfLoop is set, act as if NetworkType was
                        Conventional.
        16-Oct-89 CMH   Now set pred. and succ. bug while in the network 
                        view only.  Setting dependencies is not allowed in
                        the tree view any more.
        01-Nov-89 EGK   Added call to SaveNetData to allow saving of the last
                        copy of the network data for later reuse if possible.
        21-Nov-89 EGK   In NetAfter, let Ctrl-End switch between the start
                        and end box of a summary task in traditional PERT
                        mode.
        21-Nov-89 CMH   Added ActivateACursorTask for the GoToKey so the
                        banner would be refresed.
        15-Dec-89 EGK   For mouse support, change use of ULYMAX to NetYMax,
                        and maxcol to NetXMax.
        18-Dec-89 EGK   The real mouse support stuff.  Souped up NetBefore
                        to handle mouse events, including locating a task
                        by screen coordinates and paging in all directions.
        22-Dec-89 AJL   Additional mouse tracking.
        29-Dec-89 LAA   Put in code to detect if a mouse down event is on the
                        menu region of the screen, and if so to convert it
                        into the "/" key.  This used to be done by just
                        passing the mouse event down to the Gantt chart, but
                        didn't work because NetDraw needs to notice the "/"
                        key and compensate for it in various ways.
        03-Jan-90 EGK   In NetAfter, set the event code to "OnMenu" on the
                        MouseUp instead of MouseDown.  That keeps the screen
                        from refreshing before the menu actually comes up.
        16-Jan-90 EGK   Renamed DoPageMove to DoCursorMove, and changed
                        all directional keys and scroll-related mouse actions
                        to call that, since it now contains the necessary
                        common code to move the cursor.  Changed the meaning
                        of mouse scrolling so that it acts like the arrow
                        keys.
        05-Feb-90 EGK   Removed unused imports from NetCharacters.
        21-Feb-90 KKC   Remove all unreferenced id from Timeu.
        21-Mar-90 EGK   Renamed GetTaskIDs to GetEdgeDetails, and enhanced
                        it to indicate whether or not the given edge can be
                        displayed in the current view.  In Outline PERT,
                        certain partial dependencies to summary tasks cannot
                        be honored and thus cannot be drawn incrementally.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        07-Jun-90 EGK   Removed more unused imports.
        12-Sep-90 CL    Remove unused SummaryFlag.
                        Replace TaskFlags with TempTaskFlags in order
                        to be compatible with InvisibleFlag.        
         9-Nov-90 TGS   Integrate changes made to 4.0 since 4.5 branched off.
        25-Jan-91 AJL   Remove ManualFilterKey.
        25-Mar-91 TGS   Let ExitKey (a menu key now) through.
        12-Jun-91 PFG   There was a bug (#4512) where requesting a Histogram
                        View while in a PERT or Tree View was simply beeping
                        rather than allowing TLRHIST to put up a message.  I
                        commented out the old code.
        31-Jul-90 LAA   Arrrrgh!  At the last minute, we discovered that  
                        the P and S marker characters are still in this code, 
                        and we've promised the international partners we'll 
                        fix it.  So, I modified SetPredSuccBugs to use a
                        phrase instead.  What a pain!   
        13-Jun-91 LAA   Reapplied the above change from 31-Jul-90, which had
                        somehow got lost!  Arrrrgh again!!
        20-Dec-91 TGS   PFG's 12-Jun-91 fix commented out one line too many,
                        causing bug 5377.
    *)

FROM AccessMatrix           IMPORT
    (* CONST *)                 COLORBIAS,
    (* PROC *)                  ClearDrawingMatrix, GetCellInfo;

FROM ActiveViews            IMPORT
     (* TYPE *)                 AnActiveViewGetEventProc;

FROM Keys                   IMPORT
    (* CONST *)                 PlotGantt, QuitProgram, FileErase,
                                FiltersClear;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag, 
                                ATaskFilter, ATaskFilterSet;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE;

FROM Chart                  IMPORT
    (* TYPE *)                  ATaskStatDisplayProc,
    (* VAR *)                   DisplayTaskStats, 
                                BugTaskA, BugTaskB, GanttChart, CursorTask;

FROM ChartControl           IMPORT
   (* TYPE *)                   AChartState,
   (* PROC *)                   DisplayTheChart, UnSetState;

FROM Codes                  IMPORT ACode, EmptyCodeSet;

FROM Correl                 IMPORT
    (* TYPE *)                  ACorrelationList, ARegionNumber,
    (* PROC *)                  CreateCorrelationList,
                                DisposeCorrelationList,
                                SetRegion, CorrelatePoint;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Burp, Error, Message, FatalError;

FROM Dispatcher             IMPORT
    (* VAR *)                   CurrentLayoutProc;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr;

FROM Endings                IMPORT
    (* VAR *)                   QuitDammitCode;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType,
    (* PROC *)                  GetNextEvent, PushEvent;

FROM GanttHelper            IMPORT
    (* PROC *)                  PutHScrollBar, PutVScrollBar;

FROM GanttOutlines          IMPORT
    (* TYPE *)                  AGanttOutlineSpecificChange,
                                ValidateGanttOutline;

FROM Helper                 IMPORT AScreenAction, GiveHelp;

FROM IncDraw                IMPORT
    (* PROC *)                  IRAddDep, IRDeleteDep;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* TYPE *)                  avidmode, ascreenx, ascreeny,
    (* PROC *)                  EraseLn, FlushKeyboardBuffer, KeyPress,
                                PutString;

FROM Keys                   IMPORT
    (* CONST *)
         ExitKey, DoIt, CancelKey, Fwrd, Reverse, Up,
         Down, Tab, RTab, HelpKey, RollUp, RollDown, RollLeft,
         RollRight, OnMenu, JoinKey, UnJoinKey, UndoKey, AddTaskKey,
         DelTaskKey, ChngTskKey, InsertKey, DeleteKey,
         DsplyKey, AnteKey, SplitKey, GotoKey, ComputeKey,
         GotoTodayKey, Goto1Key, Goto2Key,
         DaysKey, CalFormKey, PgUpKey, PgDnKey, RepeatKey,
         ReportsKey, ResourceFormKey, PrintFormKey, GotoNameKey,
         RedoKey, OptionsMenuKey, JoinPartialKey,
         BackSpace,HomeKey,EndKey,SelectKey,DeathKey,
         GotoCurrentTaskKey, 
         AlternateDisplayKey,
         CopyKey, EditKey, ReInsertKey, OpenKey, CloseKey, MoveUpKey,
         MoveDownKey, PromoteKey, DemoteKey, SelListKey, HistKey,
         HelpIndexKey, TaskNotesKey, GotoWBSKey, HighListKey,
         DependViewKey, AltUndoKey, HighList2Key, HighList3Key,
         EditBigTaskKey, NetworkKey, FileFormKey,
         MouseDown, MouseUp, MouseStillDown, MouseDouble;

FROM Layout                 IMPORT GanttWStart, GanttWEnd, MenuStart, MenuEnd;

FROM Lights                 IMPORT
    (* PROC *)                  QueryLightXY;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SetLengthOf, SetString, CtoS, Procustes,
                                ConcatLS, ConcatS, Insert, LJust, TrimRear, Overlay ;

FROM Mouse                  IMPORT
    (* PROC *)                  CancelDoubleClick, MousePresent;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM NetBanners             IMPORT
    (* PROC *)                  ClearBanner, ClearMessage, 
                                DisplayBanner, NoGanttStatusBanner;

FROM NetCharacters          IMPORT
    (* CONST *)                 blank,
                                VBar2,
                                DoubleLeftTee,
                                DoubleRightTee,
                                VBar1,
                                pastrUL,    pastrUR,
                                pastrLL,    pastrLR,
                                pDPlus,     pDHPlus,
                                pDLeftTee,  pDRightTee,
                                pdash,      pVDash,
                                UpArrow,
                                DownArrow,
                                ThickBar;

FROM NetCopy                IMPORT
    (* PROC *)                  SaveNetData;

FROM NetKeys                IMPORT
    (* TYPE *)                  ADirection,
    (* PROC *)                  NetFwrdKey, NetReverseKey,
                                NetUpKey,   NetDownKey,      
                                NetPgUpKey, NetPgDnKey,  
                                NetRollRightKey,    
                                NetRollLeftKey,
                                Scrolling,    
                                NetTabKey,  NetRTabKey;
    
FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NormalLayoutActive, GetNormalNetLayout,
                                NetworkLight,      
    (* PROC *)                  DisplayNetworkLight, GetBigNetLayout;

FROM NetPhantoms            IMPORT
    (* CONST*)                   InvisibleFlag;

FROM NetSave                IMPORT
    (* PROC *)                  DiscardData;

FROM NetStatic              IMPORT
    (* CONST *)                 DimHeight,   DimWidth,
    (* TYPE *)                  DiagramView,
                                DiagramTask,
    (* VAR *)                   SnetWidth,   SnetHeight,
                                loopnode,
                                SnetRowOne,    SnetColOne,
                                SnetRows,    SnetCols,
                                Xpos, Ypos,
                                Xmaxpos, Ymaxpos,
                                Utility,
                                maxtask,
                                ViewType, HaveInfLoop,
                                NetworkDone, EnoughMemory,
                                DeallocForRecalc;

FROM NetTaskDraw            IMPORT
    (* PROC *)                  BoxExpand, 
                                DrawMasterTaskExtension;
    
FROM NetUtility             IMPORT
    (* CONST *)                 ToScreen, ToPrinter,
                                NormalLayout,  EnlargedLayout,
                                MasterTaskHeight,
                                ULX, ULY, SeperatorLine,
    (* VAR *)                   SnetChars,
                                BoxLayout,
                                CharWidth, CharHeight,
                                BoxWidth, BoxHeight,
                                SnetRowMin,    SnetRowMax,
                                SnetColMin,    SnetColMax,
                                ExpandedSnetHeight, ExpandedSnetWidth,
                                NetXMax, NetYMax,
    (* PROC *)                  GetOutlineType, MasterTaskCheck, 
                                GetBoxSize,
                                GetHorizMin, GetVertMin,
                                GetHorizMax, GetVertMax,
                                GetPad, 
                                ISnetChars, InitSnetHandW,
                                GetMasterTaskLabel,
                                SetFilterVideoModes;

FROM NetVideo               IMPORT
    (* PROC *)                  GetLineColor;

FROM NetworkData            IMPORT
    (* TYPE *)                  ANetworkType,
    (* VAR  *)                  CurrentActiveView,
                                AnnealingChoice, NetworkType;

FROM Notices                IMPORT
    (* PROC *)                  RegisterForNotices,
                                UnRegisterForNotices,
    (* TYPE *)                  AnOccasion, AStep;


FROM Overlays               IMPORT
    (* VAR *)                   PackageOK,
    (* PROC *)                  InstallNewProcedure, CallOverlay;

FROM RunMenu                IMPORT
    (* PROC *)                  SelectAndRunMenu;

FROM SegWords               IMPORT
    (* PROC *)                  WordNumber; 

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS, ADR,
    (* PROC *)                  DOSCALL, TSIZE;

FROM Timei                  IMPORT
    (* PROC *)                  ADate;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode,
    (* PROC *)                  ValidateTreeNode;

CONST
    ModuleNumber            = 20200;

        (* Regions of the screen for mouse hit testing. *)
    Outside         = 0;
    InContent       = 1;
    InPageUp        = 2;
    InPageDown      = 3;
    InPageLeft      = 4;
    InPageRight     = 5;
    InNetworkLight  = 6;
    InMenuArea      = 7;

TYPE
    DrawingActions = (ActivateCursorTask,
                      DrawOnScreen,
                      CompleteScreenRefresh,
                      CellRefresh,
                      RecalcMatrixFirst);

    ADrawingActionsSet = SET OF DrawingActions;

VAR
    PostKeystrokeDrawing        : ADrawingActionsSet;
    SaveCurrentLayoutProc       : ADDRESS;
    CurrentBoxLayout,
    LastBoxLayout               : ANetworkLayout;
    SaveTaskStatDisplayProc     : ATaskStatDisplayProc;
    LastTaskBug                 : ATreeNode;
    LastRow,       LastCol,
    CurrentRow,    CurrentCol,                            
    PosX,          PosY,
    PosXMin,       PosXMax,
    PosYMin,       PosYMax,
    HorizScrollAmt,
    VertScrollAmt               : INTEGER;
    EffectiveOnMenuCode         : ACode;
    Initialized,
    KeyInhibit,
    requesting                  : BOOLEAN;

    RegionList                  : ACorrelationList;
    MouseActiveRegion           : CARDINAL;    (* Which region did the mouse down click happen in? *)


(*--------------------------------------------------------------------------*)
        (*
            GetCursorTaskRowandCol

            Given any treenode for a task in the plan, this
            procedure returns the matrix X and Y location.
            If the X and Y is not good, for example is all
            tasks are not in the matrix as is the case with
            an infinte loop, then the returning X and Y is
            not changed.  The result then is that the cursor
            remains unchanged.
         *)



PROCEDURE GetCursorTaskRowandCol(    LocateTask : ATreeNode;
                                     Phantom    : BOOLEAN;
                                 VAR MatrixRow,
                                     MatrixCol  : INTEGER) : BOOLEAN;

VAR
    task  : ATaskPtr;
    X, Y  : INTEGER;
    error : BOOLEAN;

BEGIN

    IF (LocateTask = NIL) THEN RETURN TRUE; END;

    task:=LocateTask^.Methods^.LockFlexStorDataObject(LocateTask);
    IF(InvisibleFlag IN task^.TempTaskFlags) THEN
        LocateTask^.Methods^.UnlockUnchangedDataObject(LocateTask);
        error:=TRUE;
        RETURN(error);
    END;
    IF (Phantom) THEN           (* 11/21/89 EGK *)
        Y:=Ypos[task^.YY];
        X:=Xpos[task^.YY];
    ELSIF (ViewType = TreeView) THEN
        Y:=task^.YY;
        X:=task^.XX;
    ELSE
        Y:=Ypos[task^.XX];
        X:=Xpos[task^.XX];
    END;
    LocateTask^.Methods^.UnlockUnchangedDataObject(LocateTask);

    error:= FALSE;
    IF (Y < SnetRowOne) OR (Y > SnetRows) THEN
       error:= TRUE;
    ELSE
       MatrixRow:= Y;
    END;

    IF (X < SnetColOne) OR (X > SnetCols) THEN
       error:= TRUE;
    ELSE
       MatrixCol:= X;
    END;

    RETURN error;

END GetCursorTaskRowandCol;



(*--------------------------------------------------------------------------*)
        (*
            ShowNet

            This is the main procedure used to access the internal
            matrix and draw a screen full of network diagram.
            First, the framwork is drawn, the master task outlines
            and the connecting dependency lines.  Next, the task boxes
            are expanded and draw over the framework.
         *)


PROCEDURE ShowNet();

VAR
    i, j, pos,
    row, col,
    erow, ecol,
    rowcl, colcl,
    BoxX, BoxY,
    sOutPos, sEndPos,
    sStartPos,
    MTCol         : CARDINAL;
    ScreenY, cell, k,
    CursorCol, CursorRow,
    MiddleY, MTCell     : INTEGER;
    NormalVidMode,
    CursorVidMode,
    VidMode             : avidmode;
    TaskType            : DiagramTask;
    Task                : ATaskPtr;
    s                   : ARRAY [0..255] OF CHAR;
    left, middle, right : CHAR;
    CursorMode,
    ColsDone, RowsDone,
    rtc,
    CriticalPath        : BOOLEAN;
    BlankLine           : ARRAY [0..81] OF CHAR;
    layout              : ANetworkLayout;

BEGIN                       (* ShowNet *)

  IF (NOT Initialized) THEN
      ClearBanner();
      IF NormalLayoutActive THEN
         BoxLayout:= NormalLayout;
         CurrentBoxLayout:= GetNormalNetLayout();      (* find out which layout is to be used *)    (* 21-Oct-88 CMH *)
      ELSE
         BoxLayout:= EnlargedLayout;
         CurrentBoxLayout:= GetBigNetLayout();
      END;
      DisplayNetworkLight();
      GetBoxSize(CurrentBoxLayout);            (* 21-Oct-88 CMH *)
      InitSnetHandW();
      ISnetChars();
      SnetRowMin:=SnetRowOne;
      SnetColMin:=SnetColOne;
      GetVertMax(SeperatorLine,NetYMax);
      GetHorizMax(ULX,NetXMax+1);
      VertScrollAmt  := ((NetYMax-SeperatorLine) DIV 2);
      IF VertScrollAmt < BoxHeight+1 THEN
         VertScrollAmt:= BoxHeight+1+CharHeight+MasterTaskHeight;
      END;
      HorizScrollAmt := ((NetXMax+1) DIV 2);
      IF HorizScrollAmt < BoxWidth THEN
         HorizScrollAmt:= BoxWidth+CharWidth;
      END;
      IF ((CurrentRow = 0) AND (CurrentCol = 0)) THEN
           SetFirstCursorTask();
      ELSE
           cell:=GetCellInfo(CurrentRow,CurrentCol);
           SetACursorTask(cell);
           SetCursorInMiddle();
      END;
      GetScreenParameters();
      LastTaskBug:= NIL;
      Initialized := TRUE;
  END;

  Fill(BlankLine,blank,maxcol+1);         (* Not NetXMax+1, since the vertical scroll
                                             bar doesn't reach this high  *)
  PutString(BlankLine,0,SeperatorLine,GetLineColor(FALSE));

  BoxY:=ULY;
  ScreenY := ULY;

(*Build screen framework for the visible portion of the internal matrix *)

  SetLengthOf(BlankLine,NetXMax+1);
  FOR row := SnetRowMin TO SnetRowMax DO

      erow:= SnetHeight^[row]; (* number of expansion rows *)

      rowcl:= (erow DIV 2); (* row centerline *)
      IF rowcl = 0 THEN
         rowcl:=1;
      END;

      FOR i := 1 TO erow DO

          sOutPos := 1;
          sEndPos := 0;
          CriticalPath := FALSE;
          PutString(BlankLine,ULX,ScreenY,GetLineColor(FALSE));

          FOR col := SnetColMin TO SnetColMax DO

              ecol:= SnetWidth^[col]; (* number of expansion cols *)
              IF ecol > 0 THEN

                 colcl:= (ecol DIV 2 ) + sOutPos; (* col centerline *)
                 sEndPos:= sOutPos+ecol;
                 cell := GetCellInfo(row,col);

                 IF cell >= 0 THEN     (* if cell is " " or taskid then *)
                    sOutPos:= sEndPos; (*    do nothing, incr to end    *)
                    right:= blank;

                 ELSE                  (* else network character found  *)
                    cell := ABS(cell); (*      make cell a valid index  *)
                 (* check for critcal path color bias *)
                    CriticalPath := FALSE;
                    IF (cell > COLORBIAS) THEN
                        cell := cell-COLORBIAS;
                        CriticalPath := TRUE;
                    END;

                 (* expand characters above, at and below row centerline *)
                    IF i < rowcl THEN  (* if above row centerline... *)
                       left  := blank;
                       right := blank;
                       middle:= GetPad('T',cell);
                    END;
                    IF i = rowcl THEN  (* if at row centerline... *)
                       left   := GetPad('L',cell);
                       middle := GetPad('A',cell);
                       right  := GetPad('R',cell);
                       MiddleY:= ScreenY;
                    END;
                    IF i > rowcl THEN  (* if below row centerline...*)
                       left  := blank;
                       right := blank;
                       middle := GetPad('B',cell);
                       IF (middle = UpArrow) OR (middle = DownArrow) THEN
                           IF (i-rowcl)>1 THEN
                               middle:= VBar1; (* adjust so arrows only draw once*)
                           END;
                       END;
                    END;

                 (* expand characters left, middle and right of col centerline *)
                    sStartPos := sOutPos-1;
                    (*         I replaced this with the IF below - LAA
                    FOR pos := sOutPos TO (colcl-1) DO
                       ConcatS(s,left);
                       INC(sOutPos);
                    END; (*for*)
                    *)
                    IF (sOutPos < colcl) THEN
                       Fill(s, left, colcl - sOutPos);
                       IF ((left = blank) OR (left = VBar2) OR (left = DoubleLeftTee)) THEN
                           PutString(s,sStartPos,ScreenY,GetLineColor(FALSE));
                       ELSE
                           PutString(s,sStartPos,ScreenY,GetLineColor(CriticalPath));
                       END;
                       sOutPos := colcl;
                    END;

                    IF sOutPos = colcl THEN
                       s[0] := CHR(0);
                       ConcatS(s,middle);
                       IF ((middle = blank) OR (middle = VBar2) OR
                            (middle = DoubleLeftTee) OR (middle = DoubleRightTee)) THEN
                            PutString(s,sOutPos-1,ScreenY,GetLineColor(FALSE));
                       ELSE
                            PutString(s,sOutPos-1,ScreenY,GetLineColor(CriticalPath));
                       END;
                       INC(sOutPos);
                    END;

                    (*  Replaced this with the IF below - LAA
                    s[0] := CHR(0);
                    sStartPos := sOutPos-1;
                    FOR pos := sOutPos TO (sEndPos-1) DO
                        ConcatS(s,right);
                        IF ((right = blank) OR (right = VBar2) OR (right = DoubleRightTee)) THEN
                             PutString(s,sStartPos,ScreenY,GetLineColor(FALSE));
                        ELSE
                             PutString(s,sStartPos,ScreenY,GetLineColor(CriticalPath));
                        END;
                        INC(sOutPos);
                    END; (* for *)
                    *)
                    sStartPos := sOutPos-1;
                    IF (sOutPos < sEndPos) THEN
                        Fill( s, right, sEndPos - sOutPos );
                        IF ((right = blank) OR (right = VBar2) OR (right = DoubleRightTee)) THEN
                             PutString(s,sStartPos,ScreenY,GetLineColor(FALSE));
                        ELSE
                             PutString(s,sStartPos,ScreenY,GetLineColor(CriticalPath));
                        END;
                        sOutPos := sEndPos;
                    END;
                 END; (* if cell...*)
              END; (* if ecol... *)
          END; (* for col... *)

          ScreenY := ScreenY+1;

      END; (*for i...*)

      BoxX     := ULX;


   (* Expand tasks into boxes and draw over framework *)

      FOR col := SnetColMin TO SnetColMax DO
          cell:= GetCellInfo(row,col);
          ecol:= SnetWidth^[col];
          CursorMode:= FALSE;
          IF (row = ORD(CurrentRow)) AND (col = ORD(CurrentCol)) THEN
              IF cell > 0 THEN
                 TaskType:= MasterTaskCheck(GetCellInfo(CurrentRow,CurrentCol));
                 IF TaskType = master THEN
                    IF NOT (loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell])) THEN
                       TaskType:= normal;
                    END;
                 END;
              ELSE
                 TaskType:= normal;
              END;
              DrawCursorBar(BoxX,BoxY+ORD(SnetHeight^[CurrentRow]-1),
                            SnetWidth^[CurrentCol],GetLineColor(FALSE),FALSE,
                            TaskType,cell);
              LastRow:=CurrentRow;
              LastCol:=CurrentCol;
              IF cell > 0 THEN
                 IF loopnode^[cell] = CursorTask THEN
                    CursorMode:= TRUE;
                    DisplayBanner();
                 END;
              END;
          END; (* if row... *)

          IF (cell = pdash) THEN  (* master task outline *)
             MTCol:=col;
             REPEAT
               DEC(MTCol);
               IF (MTCol >= ORD(SnetColOne)) THEN
                   MTCell:= GetCellInfo(row,MTCol);
                   IF (MTCell > 0) AND (MTCol < ORD(SnetColMin)) THEN       (* 7/31/89 EGK *)
                       SetFilterVideoModes(MTCell,NormalVidMode,CursorVidMode);
                       rtc:= GetCursorTaskRowandCol(CursorTask,FALSE,CursorRow,CursorCol);
                       VidMode:= NormalVidMode;
                       IF ((row=ORD(CursorRow)) AND (MTCol=ORD(CursorCol))) THEN
                          IF((CursorRow=CurrentRow) AND (CursorCol=CurrentCol)) THEN
                              VidMode:= CursorVidMode;
                          END;
                       END;
                       IF (BoxLayout=NormalLayout) THEN
                           layout:=GetNormalNetLayout();
                       ELSE
                           layout:=GetBigNetLayout();
                       END;
                       GetMasterTaskLabel (s,loopnode^[MTCell],layout,HIGH(s));
                       DrawMasterTaskExtension(row,col,MTCol,s,BoxX,MiddleY,
                                         ToScreen,VidMode);    (* 19-Oct-88 CMH *)
                   END;
               END;
             UNTIL ((MTCell <> pdash) OR (MTCol <= ORD(SnetColOne)) OR (MTCell > 0));  (* 22-Nov-88 LAA/CMH *)

          ELSIF cell > 0  THEN               (* if cell is a taskid then ...  *)
             SetFilterVideoModes(cell,NormalVidMode,CursorVidMode);
             BoxExpand(BoxX,BoxY,cell,
                       CursorMode,
                       NormalVidMode,CursorVidMode,
                       ToScreen,
                       GetOutlineType(cell));
          END;

          BoxX     := BoxX+ecol;

      END; (* for col... *)

      BoxY:= BoxY+erow;

    END; (*for row...*)


 (* blank out remaining rows not used on the screen *)
    FOR i:= ScreenY TO NetYMax DO
        PutString(BlankLine,ULX,i,GetLineColor(FALSE));
    END;


 (* draw the "P" and "S" symbol for joining tasks *)
    SetPredSuccBugs();

END ShowNet;


(*--------------------------------------------------------------------------*)
        (*
            SetFirstCursorTask

            Sets an initial cursor task if one has
            not yet been set by the Gantt chart.
            Adjusts the matrix window so that the
            cursor task is placed in approximately
            the middle area of the screen.
         *)

PROCEDURE SetFirstCursorTask();

VAR
   cell     : INTEGER;
   error    : BOOLEAN;

BEGIN

   CurrentRow:=SnetRowOne;
   CurrentCol:=SnetColOne;

   IF CursorTask <> NIL THEN
      error:= GetCursorTaskRowandCol(CursorTask,FALSE,CurrentRow,CurrentCol);
      IF NOT error THEN
         cell:=GetCellInfo(CurrentRow,CurrentCol);
         SetACursorTask(cell);
         SetCursorInMiddle();
      END;
   END;

END SetFirstCursorTask;


(*--------------------------------------------------------------------------*)
        (*
            GetScreenParameters

            Sets up the screen X and Y positions for the
            minimum and maximum edges, and current cursor
            location.  This allows for the actual drawing
            area to be smaller than the actual screen size.
         *)


PROCEDURE GetScreenParameters();

VAR
    i : INTEGER;

BEGIN

    PosXMin:= ULX;
    PosXMax:= ULX;
    PosX   := ULX;

    FOR i:= SnetColMin TO SnetColMax DO
        IF i = CurrentCol THEN
           PosX:= PosXMax;
        END;
        PosXMax:=PosXMax+SnetWidth^[i];
    END;

    PosYMin:= ULY;
    PosYMax:= ULY;
    PosY   := ULY;

    FOR i:= SnetRowMin TO SnetRowMax DO
        IF i = CurrentRow THEN
           PosY:= PosYMax;
        END;
        PosYMax:=PosYMax+SnetHeight^[i];
    END;

END GetScreenParameters;


(*--------------------------------------------------------------------------*)
        (*
            DrawCursorBar

            Draws a cursor bar, or clears a cursor bar
            area,  at the given location.
         *)

PROCEDURE DrawCursorBar(PosX,PosY,CursorWidth  : INTEGER;
                                       VidMode : avidmode;
                                      ClearBar : BOOLEAN;
                                      TaskType : DiagramTask;
                                      cell     : INTEGER);
VAR
  X  : CARDINAL;
  s  : ARRAY [0..255] OF CHAR;
  s1 : ARRAY [0..255] OF CHAR;

BEGIN

  IF (PosX >= PosXMin) AND (PosY >= PosYMin) THEN
      IF ClearBar THEN
         Fill(s,blank,CursorWidth);
      ELSE
         Fill(s,ThickBar,CursorWidth);
      END;
      IF ViewType = TreeView THEN                          (* 13-Jul-88 CMH *)
         IF TaskType = master THEN
            IF loopnode^[cell]^.Methods^.ChildrenVisible(loopnode^[cell]) THEN
               SetString(s1,VBar1);
               X:=ORD(BoxWidth) DIV 2;
               INC(X);
               Insert(s,s1,X);
               s[0]:=CHR(BoxWidth);
            END;
         END;
      END;
      PutString(s,PosX,PosY,VidMode);
  END;

END DrawCursorBar;


(*--------------------------------------------------------------------------*)
        (*
            ClearLastTask

            Resets the last task box from its cursor highlighting
            to the normal mode.  Clears the old cursor bar area.
         *)


PROCEDURE ClearLastTask();

VAR
      NormalVidMode,
      CursorVidMode    : avidmode;
      TaskType         : DiagramTask;
      i,
      LastX, LastY,
      LastCell         : INTEGER;
      s                : ARRAY [0..255] OF CHAR;

BEGIN

      IF (LastRow >= SnetRowMin) AND (LastRow <= SnetRowMax) AND
         (LastCol >= SnetColMin) AND (LastCol <= SnetColMax) THEN

         LastX   := PosXMax;
         FOR i:= SnetColMax TO LastCol BY -1  DO
             LastX:=LastX-SnetWidth^[i];
         END;

         LastY   := PosYMax;
         FOR i:= SnetRowMax TO LastRow BY -1 DO
             LastY:=LastY-SnetHeight^[i];
         END;

         LastCell:= GetCellInfo(LastRow,LastCol);
         IF LastCell > 0 THEN (* was last cell a task id ?  *)
            SetFilterVideoModes(LastCell,NormalVidMode,CursorVidMode);
            BoxExpand(LastX,LastY,LastCell,
                      FALSE,
                      NormalVidMode,CursorVidMode,
                      ToScreen,
                      GetOutlineType(LastCell));
         END;
         TaskType:= normal;
         IF GetCellInfo(LastRow,LastCol) > 0 THEN
            TaskType:= MasterTaskCheck(GetCellInfo(LastRow,LastCol));
         END;
         DrawCursorBar(LastX,LastY+SnetHeight^[LastRow]-1,
                       SnetWidth^[LastCol],GetLineColor(FALSE),TRUE,
                       TaskType,GetCellInfo(LastRow,LastCol));
         (* Replace drawing character wiped out by cursor bar character *)
         IF LastCell < 0 THEN
             s[0]:=CHR(1);
             LastCell := ABS(LastCell);
             IF (LastCell > COLORBIAS) THEN
                 LastCell := LastCell-COLORBIAS;
             END;
             s[1]:= GetPad('B',LastCell);
             IF (s[1] = UpArrow) OR (s[1] = DownArrow) THEN
                 s[1]:=VBar1;
             END;
             PutString(s,
                       LastX+(SnetWidth^[LastCol] DIV 2),
                       LastY+SnetHeight^[LastRow]-1,
                       GetLineColor(FALSE));
         END;
      END;

END ClearLastTask;


(*--------------------------------------------------------------------------*)
        (*
            OnScreenDrawing

            Draws a task box on the screen when the cursor task
            changes.
        *)


PROCEDURE OnScreenDrawing(cell : INTEGER);

VAR
  LocalCell,
  row, col,
  CursorX, CursorY : INTEGER;
  DrawIt           : BOOLEAN;
  NormalVidMode,
  CursorVidMode    : avidmode;
  TaskType         : DiagramTask;

BEGIN

     DrawIt:= TRUE;
     IF (CurrentRow = LastRow) AND (CurrentCol = LastCol) THEN
         DrawIt:= FALSE;
     END;

     IF DrawIt THEN
        GetScreenParameters();
        IF cell > 0 THEN
           SetFilterVideoModes(cell,NormalVidMode,CursorVidMode);
           BoxExpand(PosX,PosY,cell,
                     TRUE,
                     NormalVidMode,CursorVidMode,
                     ToScreen,
                     GetOutlineType(cell));
        END;
        TaskType:= normal;
        IF GetCellInfo(CurrentRow,CurrentCol) > 0 THEN
           TaskType:= MasterTaskCheck(GetCellInfo(CurrentRow,CurrentCol));
        END;
        DrawCursorBar(PosX,PosY+SnetHeight^[CurrentRow]-1,
                      SnetWidth^[CurrentCol],GetLineColor(FALSE),FALSE,
                      TaskType,GetCellInfo(CurrentRow,CurrentCol));
        ClearLastTask();
        SetPredSuccBugs();
        LastRow:=CurrentRow;
        LastCol:=CurrentCol;
     END;

END OnScreenDrawing;


(*--------------------------------------------------------------------------*)
        (*
            TaskFilteredIn

            Determine if the given task tree node is filtered
            in (showing) or not, as determined by that task's
            visibility, and the visibility of its parents.
         *)

PROCEDURE TaskFilteredIn(    Cell       : INTEGER) : BOOLEAN;

VAR
    TaskNode                : ATreeNode;
    In                      : BOOLEAN;

BEGIN                       (* TaskFilteredIn *)

    IF (Cell <= 0) THEN RETURN FALSE; END;                        (* 03-Mar-88 LAA *)

    TaskNode := loopnode^[Cell];

    ValidateTreeNode(TaskNode);

    In := FALSE;
    IF (TaskNode^.Methods^.Visible(TaskNode)) THEN
        In := TRUE;
        TaskNode := TaskNode^.Methods^.Parent(TaskNode);
        WHILE (TaskNode <> NIL) DO
            IF (TaskNode^.Methods^.Visible(TaskNode)) THEN
                TaskNode := TaskNode^.Methods^.Parent(TaskNode);
            ELSE
                In := FALSE;
                TaskNode := NIL;
            END;
        END;
    END;

    RETURN In;

END TaskFilteredIn;


(*--------------------------------------------------------------------------*)
        (*
            CellIsOutline
         *)

PROCEDURE CellIsOutline(MatrixCharacter : INTEGER) : BOOLEAN;

VAR

    OutlineCellFound : BOOLEAN;

BEGIN

    CASE MatrixCharacter OF
         pastrUL, pastrUR, pastrLL, pastrLR,
         pDPlus, pDHPlus,
         pdash, pVDash,
         pDLeftTee, pDRightTee:

         OutlineCellFound:=TRUE;

    ELSE

         OutlineCellFound:=FALSE;

    END;

    RETURN(OutlineCellFound);

END CellIsOutline;


(*--------------------------------------------------------------------------*)
        (*
            LookForAParent
         *)

PROCEDURE LookForAParent(StartingRow, StartingCol : CARDINAL) : ATreeNode;

VAR
    TaskNode                 : ATreeNode;
    minarea, area, inside, i : CARDINAL;

BEGIN

    TaskNode:= NIL;

    IF ((NetworkType = Conventional) OR
        (ViewType = TreeView))       OR         (* 28-Aug-1989 CMH *)
        (HaveInfLoop)                THEN       (* 9/28/89 EGK *)
         RETURN(TaskNode);
    END;

    minarea:=64000;
    inside:=0;
    FOR i:=1 TO maxtask DO
        IF (Utility[i] > 0) THEN
            IF((ORD(Utility[i])<=StartingCol)  AND (ORD(Xmaxpos[i])>=StartingCol)) THEN
              IF((ORD(Ypos[i])<=StartingRow)  AND (ORD(Ymaxpos[i])>=StartingRow)) THEN
                area:=(Xmaxpos[i]-Utility[i]);                    (* 25-Jul-89 LAA *)
                IF(area<minarea) THEN
                  area:=minarea;
                  inside:=i;
                END;
              END;
            END;
        END;
    END;
    IF(inside=0) THEN
       RETURN (TaskNode);
    END;
    TaskNode:=loopnode^[inside];
    RETURN (TaskNode);

END LookForAParent;


(*--------------------------------------------------------------------------*)
        (*
            SetACursorTask

            Activates a cursor task for the network view.
         *)


PROCEDURE SetACursorTask(cell : INTEGER);

VAR
    TaskNode : ATreeNode;

BEGIN

    IF TaskFilteredIn(cell) THEN
       CursorTask:= loopnode^[cell];
       DisplayBanner();
    ELSE
       TaskNode:= LookForAParent(CurrentRow,CurrentCol);
       IF (TaskNode <> NIL) THEN
           CursorTask:= TaskNode;
           DisplayBanner();
       ELSE
           ClearBanner();
       END;
    END;

END SetACursorTask;



(*--------------------------------------------------------------------------*)
        (*
            BeyondEdgeCheck

            Checks to see if the given row and column
            exceed the current matrix window on the screen.
         *)

PROCEDURE BeyondEdgeCheck(row,col:INTEGER) : BOOLEAN;

BEGIN
     IF (col < SnetColMin) OR (col > SnetColMax) OR
        (row < SnetRowMin) OR (row > SnetRowMax)
     THEN
        RETURN TRUE;
     ELSE
        RETURN FALSE;
     END;

END BeyondEdgeCheck;



(*--------------------------------------------------------------------------*)
        (*
            SetCursorInMiddle

            A new CursorTask has been set and is off screen.
            SetCursorInMiddle will shift the screen so the
            CursorTask is in view.
         *)

PROCEDURE SetCursorInMiddle ();

BEGIN

     IF ((CurrentRow < SnetRowMin) OR (CurrentRow > SnetRowMax)) THEN
          SnetRowMax:=Scrolling(down,CurrentRow,VertScrollAmt);
          GetVertMin();
          IF SnetRowMin = SnetRowOne THEN
             GetVertMax(SeperatorLine,NetYMax);
          END;
          IF (CurrentRow < SnetRowMin) OR (CurrentRow > SnetRowMax)THEN
           (* if placing in the middle failed, then place it in the top row *)
              SnetRowMin:= CurrentRow;
              GetVertMax(SeperatorLine,NetYMax);
          END;
     END;
       
     IF ((CurrentCol < SnetColMin) OR (CurrentCol > SnetColMax)) THEN
          SnetColMax:=Scrolling(right,CurrentCol,HorizScrollAmt);
          GetHorizMin();
          IF SnetColMin = SnetColOne THEN
             GetHorizMax(ULX,NetXMax+1);
          END;
          IF (CurrentCol < SnetColMin) OR (CurrentCol > SnetColMax) THEN
           (* if placing in the middle failed, then place it in the left col *)
              SnetColMin:= CurrentCol;
              GetHorizMax(ULX,NetXMax+1);
          END;
    END;

END SetCursorInMiddle;


(*--------------------------------------------------------------------------*)
        (*
            SetPredSuccBugs

            Draws the "P" and "S" symbol for joining tasks.
            Clears out the area of the last bug.
         *)

PROCEDURE SetPredSuccBugs();

VAR
  SaveCurrentRow,
  SaveCurrentCol : INTEGER;
  s              : ARRAY [0..255] OF CHAR;
  PSMarkers      : ARRAY [0..21] OF CHAR; 
  SetBug,
  BeyondEdge,
  error          : BOOLEAN;

BEGIN

   SaveCurrentRow:= CurrentRow;
   SaveCurrentCol:= CurrentCol;

   IF LastTaskBug <> NIL THEN
      (* clear last bug *)
      error:= GetCursorTaskRowandCol(LastTaskBug,FALSE,CurrentRow,CurrentCol);
      IF NOT error THEN
         IF ((LastTaskBug = CursorTask) AND
             (SaveCurrentRow = CurrentRow) AND
             (SaveCurrentCol = CurrentCol)) THEN
              SetString(s,ThickBar);
         ELSE
              SetString(s,blank);
         END;
         BeyondEdge:= BeyondEdgeCheck(CurrentRow,CurrentCol);
         IF NOT BeyondEdge THEN
            GetScreenParameters();
            PutString(s,PosX,PosY+SnetHeight^[CurrentRow]-1,GetLineColor(FALSE));
         END;
      END; (*if not error... *)
      LastTaskBug:= NIL;
   END; (* if LastTaskBug... *)
   GetMessage( ModuleNumber + 31, PSMarkers );     (* "P,S" *) (* 31-Jul-90 *)

   SetBug:= FALSE;
   IF BugTaskA <> NIL THEN
      error:= GetCursorTaskRowandCol(BugTaskA,FALSE,CurrentRow,CurrentCol);
      IF NOT error THEN
         WordNumber( PSMarkers, 1, s );                     (* "P" *) 
         SetBug:=TRUE;
         LastTaskBug:= BugTaskA;
      END;
   ELSIF BugTaskB <> NIL THEN
      error:= GetCursorTaskRowandCol(BugTaskB,FALSE,CurrentRow,CurrentCol);
      IF NOT error THEN
         WordNumber( PSMarkers, 2, s );                     (* "S" *) 
         SetBug:=TRUE;
         LastTaskBug:= BugTaskB;
      END;
   END;

   IF ((SetBug) AND (ViewType = NetworkView)) THEN   (* 16-Oct-89 CMH *)
     (* set current bug *)
        BeyondEdge:= BeyondEdgeCheck(CurrentRow,CurrentCol);
        IF (NOT BeyondEdge) THEN
            GetScreenParameters();
            PutString(s,PosX,PosY+SnetHeight^[CurrentRow]-1,GetLineColor(FALSE));
        END;
   END;

   (* restore screen parameters *)
   CurrentRow:= SaveCurrentRow;
   CurrentCol:= SaveCurrentCol;
   GetScreenParameters();

END SetPredSuccBugs;




PROCEDURE TestRegions(X:ascreenx; Y:ascreeny):CARDINAL;

VAR
    ulx, lrx : ascreenx;
    uly, lry : ascreeny;
    WhichRegion : CARDINAL;

BEGIN

    WhichRegion := CorrelatePoint (RegionList, X, Y );
    IF (WhichRegion = Outside) AND QueryLightXY(NetworkLight,ulx,uly,lrx,lry) THEN
        IF (ulx <= X) AND (X <= lrx) AND (uly <= Y) AND (Y <= lry) THEN
            WhichRegion := InNetworkLight;
        END;
    END;

    RETURN WhichRegion;

END TestRegions;



(*--------------------------------------------------------------------------*)
        (*
            NetBefore

            Handles all key stroke processing before
            the Gantt chart gets a chance to act.

            The keystroke process is three part.  First,
            Netbefore has the opportunity to intercept
            any keys that are to be processed by the network.
            Clearing the code indicates to the Gantt chart
            code that no further action is required.  If the
            Gantt chart has processing to do, it occurs after
            the procedure.  Any notices for action are sent
            to the network module.  Drawing codes are set
            based on the notice received in NetReceiveNotices.
            Last, the NetAfter procedure is called to process
            the drawing codes set by NetBefore and NetReceiveNotices,
            adding any codes as required.
         *)

PROCEDURE NetBefore ( VAR Event         : AnEvent   );

VAR
    i,
    cell       : INTEGER;
    OldEvent, 
    OlderEvent : AnEvent;
    OldKey, 
    OlderKey   : ACode;
    AtEdge     : BOOLEAN;
    WhichRegion     : ARegionNumber;
    X               : ascreenx;
    Y               : ascreeny;


    PROCEDURE DoCursorMove ( Direction      : ADirection;
                             PageIt         : BOOLEAN   );
    BEGIN
        INCL(PostKeystrokeDrawing,ActivateCursorTask);

        CASE Direction OF
            up :
                IF (PageIt) THEN
                    AtEdge := NetPgUpKey(CurrentRow,CurrentCol,VertScrollAmt);
                ELSE
                    AtEdge := NetUpKey (CurrentRow, CurrentCol);
                END;
        |   down :
                IF (PageIt) THEN
                    AtEdge := NetPgDnKey(CurrentRow,CurrentCol,VertScrollAmt);
                ELSE
                    AtEdge := NetDownKey (CurrentRow, CurrentCol);
                END;
        |   right :
                IF (PageIt) THEN
                    AtEdge := NetRollRightKey(CurrentRow,CurrentCol,HorizScrollAmt);
                ELSE
                    AtEdge := NetFwrdKey (CurrentRow, CurrentCol);
                END;
        |   left :
                IF (PageIt) THEN
                    AtEdge := NetRollLeftKey(CurrentRow,CurrentCol,HorizScrollAmt);
                ELSE
                    AtEdge := NetReverseKey (CurrentRow, CurrentCol);
                END;
        ELSE
            FatalError();
        END;

        IF (AtEdge) THEN
            IF (NOT PageIt) THEN
                SetCursorInMiddle();
            END;
            GetScreenParameters();
            INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
        ELSIF (BeyondEdgeCheck(CurrentRow,CurrentCol)) THEN
            SetCursorInMiddle();
            GetScreenParameters();
            INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
        ELSE
            INCL(PostKeystrokeDrawing,DrawOnScreen);
        END;
    END DoCursorMove;


    PROCEDURE DoEditTask ();
    BEGIN
        IF ((LookForAParent(CurrentRow,CurrentCol) <> NIL) OR
            (TaskFilteredIn(GetCellInfo(CurrentRow, CurrentCol)))) THEN
             INCL(PostKeystrokeDrawing,CellRefresh);
             INCL(PostKeystrokeDrawing,ActivateCursorTask);
        END;
    END DoEditTask;


        (*  DoJumpTo -- given a screen (X,Y) pair, try to find which
                matrix position contains that point.  For each dimension,
                search from the upper left until the coordinate is in
                the right range.  If OK, set the cursor there.
        *)

    PROCEDURE DoJumpTo (    ScreenX         : ascreenx;
                            ScreenY         : ascreeny;
                            Warn            : BOOLEAN  );
    VAR
        X               : ascreenx;
        Y               : ascreeny;
        row, col        : INTEGER;
        Temp            : INTEGER;
        OK              : BOOLEAN;

    BEGIN
        OK := TRUE;

            (*  Look only at the columns on the screen.  The range is
                SnetColMin..SnetColMax.  X is the leftmost screen position
                of the current column, and its origin is ULX.  Stop when
                we find that ScreenX is between the current X and the next X.
            *)

        col := SnetColMin;
        X := ULX;
        LOOP
            IF (col > SnetColMax) THEN
                OK := FALSE;        (* Somehow, we didn't find a space? *)
                EXIT;
            END;
            IF (ScreenX < (X + ORD(SnetWidth^[col]))) THEN
                EXIT;
            END;
            INC (X, SnetWidth^[col]);
            INC (col);
        END;

            (* Now, do the same thing with the rows *)

        row := SnetRowMin;
        Y := ULY;
        LOOP
            IF (row > SnetRowMax) THEN
                OK := FALSE;
                EXIT;
            END;
            IF (ScreenY < (Y + ORD(SnetHeight^[row]))) THEN
                EXIT;
            END;
            INC (Y, SnetHeight^[row]);
            INC (row);
        END;

            (*  We found where we are, but is it a legal spot to put the
                cursor on?  See if the width and height at this spot match
                the dimensions of a box.
            *)

        IF (OK) THEN
            Temp := SnetHeight^[row];
            OK := (SnetWidth^[col] = BoxWidth) AND
                     ((Temp = BoxHeight+1) OR (Temp = MasterTaskHeight));
        END;

        IF (OK) THEN
                (* Change the current cursor to be this location *)
            CurrentCol := col;
            CurrentRow := row;
            INCL(PostKeystrokeDrawing,ActivateCursorTask);
            INCL(PostKeystrokeDrawing,DrawOnScreen);
        ELSE
                (* Sorry, can't put the cursor there *)
            IF (Warn) THEN
                Burp();
            END;
            CancelDoubleClick();
        END;
    END DoJumpTo;




BEGIN                       (* NetBefore *)

    LastBoxLayout:= CurrentBoxLayout;
    KeyInhibit:= FALSE;
    IF (NOT requesting) THEN
        PostKeystrokeDrawing:= ADrawingActionsSet{};
    END;
    AtEdge:=FALSE;

    X := Event.EventX;
    Y := Event.EventY;

    IF (Event.EventType = MouseEvent) THEN
        WhichRegion := TestRegions( X, Y );
    END;

    CASE Event.EventCode OF

      Fwrd :
            DoCursorMove (right, FALSE);
            Event.EventCode := 0;

    | Reverse :
            DoCursorMove (left, FALSE);
            Event.EventCode := 0;

    | Up :
            DoCursorMove (up, FALSE);
            Event.EventCode := 0;

    | Down :
            DoCursorMove (down, FALSE);
            Event.EventCode := 0;

    | PgUpKey :
            DoCursorMove (up, TRUE);
            Event.EventCode := 0;

    | PgDnKey :
            DoCursorMove (down, TRUE);
            Event.EventCode := 0;

    | RollRight :
            DoCursorMove (right, TRUE);
            Event.EventCode := 0;

    | RollLeft :
            DoCursorMove (left, TRUE);
            Event.EventCode := 0;


    | Tab : 

            NetTabKey(CurrentRow, CurrentCol);
            INCL(PostKeystrokeDrawing,ActivateCursorTask);
            INCL(PostKeystrokeDrawing,DrawOnScreen);
            Event.EventCode := 0;


    | RTab : 

            NetRTabKey(CurrentRow,CurrentCol);
            INCL(PostKeystrokeDrawing,ActivateCursorTask);
            INCL(PostKeystrokeDrawing,DrawOnScreen);
            Event.EventCode := 0;


    | MouseUp :
            IF (WhichRegion = MouseActiveRegion) THEN
                IF (WhichRegion=InNetworkLight) THEN 
                    Event.EventCode := DsplyKey;
                    Event.EventType := KeyboardEvent;
                    PushEvent(Event);   
                    Event.EventCode := 0;
                END;
            ELSE
                Event.EventCode := 0;
            END; 

    | MouseDouble:

            IF (WhichRegion = InContent) THEN
                DoEditTask();
                Event.EventCode := ChngTskKey;
                Event.EventType := KeyboardEvent;
            END;

    | MouseDown, MouseStillDown:
            IF (Event.EventCode = MouseDown) THEN
                MouseActiveRegion := WhichRegion;
            ELSIF (WhichRegion <> MouseActiveRegion) THEN
                    (* MouseStillDown is only active on the region that
                       the original down occurred. *) 
                Event.EventCode := 0;
            END;

            IF (Event.EventCode = 0) THEN
                (* ignore it. *)
            ELSIF (WhichRegion = InContent) THEN

                    (* Select a new cursor task. *)

                DoJumpTo (X, Y, (Event.EventCode = MouseDown));
                Event.EventCode := 0;

            ELSIF (WhichRegion = InMenuArea) THEN
                (* Just pass it on, as is *)

            ELSIF (WhichRegion > 0) THEN

                    (* Handle vertical and horizontal scrolling *)

                CASE WhichRegion OF
                    InPageUp :
                        DoCursorMove (up, FALSE);
                |   InPageDown :
                        DoCursorMove (down, FALSE);
                |   InPageLeft :
                        DoCursorMove (left, FALSE);
                |   InPageRight :
                        DoCursorMove (right, FALSE);
                ELSE
                END;
                Event.EventCode := 0;

            END;

    | HistKey : 

            (* Toggle between Standard and Alternate BoxLayout *)
            IF BoxLayout = NormalLayout THEN
               BoxLayout:=EnlargedLayout;
               NormalLayoutActive:= FALSE;
            ELSE (* BoxLayout = EnlargedLayout *)
               BoxLayout:=NormalLayout;
               NormalLayoutActive:= TRUE;
            END;
            DisplayNetworkLight;
            Initialized:= FALSE;
            INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
            Event.EventCode := 0;
            
    | (* These keys always work  *)
      OnMenu, HelpKey, ExitKey, HomeKey, EndKey, GotoKey,
      DsplyKey, HighListKey, HighList2Key, HighList3Key, (* SelListKey, *)
      ComputeKey,  UndoKey, GotoWBSKey,
      CancelKey, DeathKey, RepeatKey, Goto1Key, Goto2Key,
      HelpIndexKey, ResourceFormKey, PrintFormKey,
      FileFormKey, RedoKey, OptionsMenuKey,             (* 9/11/89 EGK *)
      CalFormKey, DaysKey, AlternateDisplayKey, QuitProgram, 0,
      FileErase, FiltersClear :                                (* 03-Mar-88 LAA *)


    | EditBigTaskKey, ChngTskKey: (* EditKey=ChngTskKey*)  (* 13-Jul-89 CMH *)

            DoEditTask();


    | JoinKey, UnJoinKey, SelectKey, JoinPartialKey :

            KeyInhibit:= TRUE;
            IF (ViewType = NetworkView) THEN        (* 9/14/89 EGK *)
                IF ((LookForAParent(CurrentRow,CurrentCol) <> NIL) OR
                    (TaskFilteredIn(GetCellInfo(CurrentRow, CurrentCol)))) THEN
                    KeyInhibit:= FALSE;
                END;
            END;

    | GotoCurrentTaskKey :              (* 11/21/89 EGK *)

            KeyInhibit:= TRUE;
            IF (ViewType = NetworkView) AND (NetworkType = Conventional) THEN
                IF ((LookForAParent(CurrentRow,CurrentCol) <> NIL) OR
                    (TaskFilteredIn(GetCellInfo(CurrentRow, CurrentCol)))) THEN
                    KeyInhibit:= FALSE;
                END;
            END;

    | (* These keys always work WHEN the cursor is on a task.  If
         the cursor is NOT ON A TASK, then the keystroke is inhibited. *)

      DoIt, GotoTodayKey, SplitKey,
      ReInsertKey, AnteKey, TaskNotesKey, 
      DeleteKey, InsertKey, CopyKey, OpenKey, CloseKey,
      DependViewKey :

            KeyInhibit:= TRUE;
            IF ((LookForAParent(CurrentRow,CurrentCol) <> NIL) OR
                (TaskFilteredIn(GetCellInfo(CurrentRow, CurrentCol)))) THEN
                 KeyInhibit:= FALSE;
            END;
            IF ((Event.EventCode = OpenKey) OR (Event.EventCode = CloseKey)) THEN  (* 14-Jul-89 CMH *)
                 GanttChart^.Methods^.GetRecordedEvent(GanttChart,0,OldEvent);
                 GanttChart^.Methods^.GetRecordedEvent(GanttChart,1,OlderEvent);
                 OldKey := OldEvent.EventCode;
                 OlderKey:=OlderEvent.EventCode;
                 IF ((OldKey = RepeatKey) AND (OlderKey = RepeatKey)) THEN
                      KeyInhibit:= FALSE;
                 END;
            END;
             
             
    ELSE (* inhibit anything that is unknown *)

            KeyInhibit:= TRUE;

    END;

    IF KeyInhibit THEN
       Burp();
       Event.EventCode:=0;
    END;

END NetBefore;


(*--------------------------------------------------------------------------*)
        (*
            NetReceiveNotices

            Check occasion and set up for NetAfter,
            adding to actions actions set by NetBefore.
         *)

PROCEDURE NetReceiveNotices(occasion : AnOccasion;
                                step : AStep;
                             address : ADDRESS) : BOOLEAN;
VAR
    TempPointer         : POINTER TO ACode;
    FromTaskID          : INTEGER;
    ToTaskID            : INTEGER;
    rtc,
    OK                  : BOOLEAN;
    Invisible           : BOOLEAN;
    Displayable         : BOOLEAN;
    Event               : AnEvent;


    PROCEDURE CleanupAfterNotice ( Successful       : BOOLEAN   );
    BEGIN
        IF (Successful) THEN
            GetVertMax(SeperatorLine,NetYMax);
            GetHorizMax(ULX,NetXMax+1);
        ELSE
            Initialized:= FALSE;
            CurrentRow := 0;
            CurrentCol := 0;
            INCL(PostKeystrokeDrawing,ActivateCursorTask);
            INCL(PostKeystrokeDrawing,RecalcMatrixFirst);
            DeallocForRecalc:= TRUE;
        END;
        INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
    END CleanupAfterNotice;


    PROCEDURE GetEdgeDetails (    EdgePtr       : AnEdgePtr;
                              VAR FromTaskID    : INTEGER;
                              VAR ToTaskID      : INTEGER;
                              VAR Invisible     : BOOLEAN;
                              VAR Displayable   : BOOLEAN   );
    VAR
        TaskPtr         : ATaskPtr;

    BEGIN
        WITH EdgePtr^ DO

            TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
            FromTaskID := TaskPtr^.XX;
            Invisible := (InvisibleFlag IN TaskPtr^.TempTaskFlags);
            headtask^.Methods^.UnlockUnchangedDataObject (headtask);

            TaskPtr := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
            ToTaskID := TaskPtr^.XX;
            Invisible := Invisible OR (InvisibleFlag IN TaskPtr^.TempTaskFlags);
            tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
            
                (*  If in outline mode, look for dependencies that can't
                    be drawn (e.g., partials to summaries)  *)

            Displayable := TRUE;

            IF (NetworkType <> Conventional) THEN

                    (* Disallow edge from start of a summary *)
                IF (headtask^.Methods^.FirstChild (headtask) <> NIL) AND
                    (FromOffset.Start) THEN
                    Displayable := FALSE;
                END;

                    (* Disallow edge to end of a summary *)
                IF (tailtask^.Methods^.FirstChild (tailtask) <> NIL) AND
                    (NOT ToOffset.Start) THEN
                    Displayable := FALSE;
                END;
            END;
                
        END;

    END GetEdgeDetails;


BEGIN

    IF (step = BeforeActing) THEN                                   (* 03-Mar-88 LAA *)

        IF (RecalcMatrixFirst IN PostKeystrokeDrawing) THEN
            RETURN TRUE;
        END;

        CASE occasion OF

            ChangeATask            : INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
                                     INCL(PostKeystrokeDrawing,ActivateCursorTask);

        |   ScheduleFilter         : INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
                                     INCL(PostKeystrokeDrawing,ActivateCursorTask);

        |   DeleteATask,
            MoveATask,
            OpenATask,
            CloseATask,
            ChangeAnEdge,
            ScheduleSort,
            ModelErase,
            ModelLoad,
            ScheduleCompute        : INCL(PostKeystrokeDrawing,RecalcMatrixFirst);
                                     INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

        |   DeleteAnEdge           : IF (ViewType = NetworkView) THEN (* 28-Aug-89 CMH *)
                                         GetEdgeDetails (AnEdgePtr(address),
                                                     FromTaskID, ToTaskID,
                                                     Invisible, Displayable);
                                         IF (NOT Invisible) THEN
                                             OK := IRDeleteDep (FromTaskID, ToTaskID);
                                             rtc:= GetCursorTaskRowandCol(CursorTask,FALSE,CurrentRow,CurrentCol);
                                             CleanupAfterNotice (OK);
                                         END;
                                     END;

        ELSE
        END;

    ELSIF (step = AfterActing) THEN

        IF (RecalcMatrixFirst IN PostKeystrokeDrawing) THEN
            RETURN TRUE;
        END;

        CASE occasion OF
            AddATask,
            NetworkSettingChange   : INCL(PostKeystrokeDrawing,RecalcMatrixFirst);
                                     INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

        |   AddAnEdge              : IF (ViewType = NetworkView) THEN (* 28-Aug-89 CMH *)
                                         GetEdgeDetails (AnEdgePtr(address),
                                                         FromTaskID, ToTaskID,
                                                         Invisible, Displayable);
                                         IF (NOT Invisible) THEN
                                             IF (Displayable) THEN  (* 3/21/90 EGK *)
                                                 OK := IRAddDep (FromTaskID, ToTaskID);
                                             ELSE
                                                 INCL(PostKeystrokeDrawing,RecalcMatrixFirst);
                                                 INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
                                                 OK := FALSE;
                                             END;
                                             rtc:= GetCursorTaskRowandCol(CursorTask,FALSE,CurrentRow,CurrentCol);
                                             CleanupAfterNotice (OK);
                                         END;
                                     END;    

        ELSE
        END;

    ELSIF (step = RequestPermission) THEN
        IF (occasion = KeyForAltView) THEN
            TempPointer:= address;
            EffectiveOnMenuCode:= TempPointer^;
(* 12-Jun-91 PFG   Commented out to fix inconsistent handling of requests
                    for alternate views.  Alternate view requests are
                    handled by PermitRequest proc in TLNET.MOD.  

            IF (EffectiveOnMenuCode = HistKey) THEN                 (* 04-Mar-88 LAA *)
                Burp();                                              (* 06-Mar-88 LAA *)
                KeyInhibit := TRUE;
            ELSE
*)

                requesting:= TRUE;
                Event.EventCode := EffectiveOnMenuCode;
                Event.EventType := KeyboardEvent;
                NetBefore (Event);
                EffectiveOnMenuCode := Event.EventCode;
                requesting:= FALSE;

(* 12-Jun-91 PFG 
            END;
*)
            (* 20-Dec-91 TGS : next line shouldn't have been commented out *)
            RETURN NOT KeyInhibit;
        END;
    ELSE
    END;

    RETURN TRUE;

END NetReceiveNotices;




(*--------------------------------------------------------------------------*)
        (*
            NetAfter

            Handles all key stroke processing after
            the Gantt chart processing has occured.  Depending
            on the keystroke and the resulting drawing codes,
            one of the following things will happen, (1) nothing,
            (2) a screen refresh, (3) a cell refresh  or (4) an
            internal matrix recalculation including a screen refresh.
         *)



PROCEDURE NetAfter(    Event                : AnEvent );

VAR
    NormalVidMode,
    CursorVidMode    : avidmode;
    cell             : INTEGER;
    WhichRegion      : ARegionNumber;
    BeyondEdge       : BOOLEAN;
    error            : BOOLEAN;
    IsPhantom        : BOOLEAN;
    ReallyTheMenuKey : BOOLEAN;

BEGIN                       (* NetAfter *)

   IF (KeyInhibit) THEN RETURN; END;

   IF (Event.EventCode = MouseUp) THEN                       (* 28-Dec-89 *) (* 3-Jan-90 EGK *)
      WhichRegion := TestRegions( Event.EventX, Event.EventY );
      IF (WhichRegion = InMenuArea) THEN
         Event.EventCode := OnMenu;
      END;
   END;

   ReallyTheMenuKey := (Event.EventCode = OnMenu);             (* 29-Dec-89 *)
   IF Event.EventCode = OnMenu THEN
      Event.EventCode:= EffectiveOnMenuCode;
   END;

   IF NormalLayoutActive THEN
      BoxLayout:= NormalLayout;
      CurrentBoxLayout:= GetNormalNetLayout();  (* find out which layout is to be used *)   
   ELSE
      BoxLayout:= EnlargedLayout;
      CurrentBoxLayout:= GetBigNetLayout();
   END;
   IF (LastBoxLayout <> CurrentBoxLayout) THEN
       Initialized := FALSE;     (* 13-Jul-89 CMH *)  (* 03-Mar-88 LAA *)
   END;

   CASE Event.EventCode OF

         HomeKey, EndKey, GotoKey, DependViewKey, GotoWBSKey,
         GotoCurrentTaskKey :                       (* 7/31/89 EGK *)

             LastRow:=CurrentRow;
             LastCol:=CurrentCol;
             cell:=GetCellInfo(CurrentRow,CurrentCol);
             IsPhantom := (Event.EventCode = GotoCurrentTaskKey) AND (Utility[cell] <> -1);
             error:= GetCursorTaskRowandCol(CursorTask,IsPhantom,       (* 11/21/89 EGK *)
                                            CurrentRow,CurrentCol);
             IF NOT error THEN
                BeyondEdge:= BeyondEdgeCheck(CurrentRow,CurrentCol);
                IF BeyondEdge THEN
                   SetCursorInMiddle();
                   GetScreenParameters();
                   INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
                ELSE
                   INCL(PostKeystrokeDrawing,DrawOnScreen);
                   INCL(PostKeystrokeDrawing,ActivateCursorTask);  (* 21-Nov-1989 CMH *)
                END;
             END; (* if not error... *)

   |     SelectKey  :

             SetPredSuccBugs();
             
   |     TaskNotesKey,  EditBigTaskKey:

             INCL(PostKeystrokeDrawing,CellRefresh);
             INCL(PostKeystrokeDrawing,ActivateCursorTask);

   |     SelListKey :

             IF NOT (TaskFilteredIn(GetCellInfo(CurrentRow, CurrentCol))) THEN  (* 03-Mar-88 LAA *)
                CurrentRow:= SnetRowMin;
                CurrentCol:= SnetColMin;
                CursorTask:=NIL;
                INCL(PostKeystrokeDrawing,ActivateCursorTask);
             END;
             INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

   |     AnteKey,CalFormKey,DaysKey,HighListKey,HighList3Key,HighList2Key :

             INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

   |     DsplyKey  :

             Initialized:= FALSE;
             INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

   ELSE
      IF (ReallyTheMenuKey) THEN                               (* 29-Dec-89 *)
         INCL(PostKeystrokeDrawing,CompleteScreenRefresh);
      END;
   END;  (* case code of *)

   Event.EventCode  := 0;

   IF RecalcMatrixFirst IN PostKeystrokeDrawing THEN
      ClearDrawingMatrix();
      Initialized:=FALSE;
      RETURN;
   END;

   cell:=GetCellInfo(CurrentRow,CurrentCol);
   IF ActivateCursorTask IN PostKeystrokeDrawing THEN
      SetACursorTask(cell);
   END;

   IF CellRefresh IN PostKeystrokeDrawing THEN
      SetFilterVideoModes(cell,NormalVidMode,CursorVidMode);
      BoxExpand(PosX,PosY,cell,
                TRUE,
                NormalVidMode,CursorVidMode,
                ToScreen,
                GetOutlineType(cell));
   END;

   IF DrawOnScreen IN PostKeystrokeDrawing THEN
      OnScreenDrawing(cell);
   END;

   IF CompleteScreenRefresh IN PostKeystrokeDrawing THEN
      ShowNet();
   END;

END NetAfter;



PROCEDURE ChooseTheLayout();

VAR
    s                       : ARRAY [0..31] OF CHAR;

BEGIN                       (* ChooseTheLayout *)

    SetString(s, "|TLNETLIS");                                    (* 10-Mar-88 LAA *)
    IF (CallOverlay(s)) THEN END;
        (* Force the screen to redisplay. *)
    Initialized:= FALSE;
    INCL(PostKeystrokeDrawing,CompleteScreenRefresh);

END ChooseTheLayout;


(*--------------------------------------------------------------------------*)
        (*
            MainLoop

            Controller for the network diagram view.
        *)



PROCEDURE MainLoop();

VAR
    Event                   : AnEvent;
    ReturnEvent             : AnEvent;
    ErrorMarker             : AnErrorMarker;
    OriginalCode            : AnEvent;
    s                       : ARRAY [0..21] OF CHAR;
    Quit                    : BOOLEAN;


    PROCEDURE DoNetworkMenu(): ACode;

    VAR
        Class               : ARRAY [0..81] OF CHAR;
        Prefix              : ARRAY [0..81] OF CHAR;

    BEGIN                   (* DoNetworkMenu *)

        GetMessage(ModuleNumber + 25, Class);    (*  Name of menu in TLWHAT *)
        GetMessage(ModuleNumber + 26, Prefix);

        RETURN SelectAndRunMenu(Class, Prefix);

    END DoNetworkMenu;

BEGIN                       (* MainLoop *)

    Quit := FALSE;

    LOOP
        GanttChart^.Methods^.SetScrollMode (GanttChart, FALSE);    (* 9/24/89 EGK *)

        ErrorMarker := NewMarker();
        GetNextEvent(Event);

        (*<DEBUGGING*)
        ValidateGanttOutline(GanttChart);
        (*DEBUGGING>*)

        IF (Event.EventCode = NetworkKey) THEN
            Event.EventCode := DoNetworkMenu();
        END;

        OriginalCode := Event;
        NetBefore (Event);

        CASE Event.EventCode OF
            (* 25-Mar-91 TGS allow ExitKey through...
            AlternateDisplayKey, ExitKey, CancelKey :
            *)
            AlternateDisplayKey, CancelKey :
                ReturnEvent.EventCode := 0;

        |   HelpKey :                                             (* 23-Feb-88 LAA *)
                SetString(s, "NETVIEW");
                GiveHelp(s, 0, GanttWEnd, RestoreTheScreen);
                ReturnEvent.EventCode := 0;

        ELSE
            UnSetState(Showing);                          (* 19-Aug-87 LAA *)
            GanttChart^.Methods^.ActOnEvent(GanttChart, Event, ReturnEvent);

            IF (ErrorPosted(ErrorMarker)) THEN
                Burp();
            END;
        END;

        PopToMarker(ErrorMarker);

        IF (QuitDammitCode <> 0) THEN  (* RSC 5/4/88 *)
            ReturnEvent.EventCode := QuitDammitCode;
        END;

        CursorTask := GanttChart^.Methods^.GetCursorNode(GanttChart);
        WITH ReturnEvent DO
            CASE EventCode OF
                0, CancelKey : DisplayTheChart();

            |   AlternateDisplayKey,                              (* 29-Feb-88 LAA *)
                PlotGantt : (* RSC 5/4/88 QUIT TO PLOTTING PROGRAM *)
                   NetworkDone := TRUE;
                    RETURN;
            ELSE
                IF (EventCode = QuitProgram) THEN     (* \Quit, Yes *)  (* 29-Feb-88 LAA *)
                    QuitDammitCode := EventCode;
                    NetworkDone:= TRUE;
                    RETURN;
                END;
            END; (* CASE *)
        END;

        PackageOK := TRUE;                  (* 9/27/89 EGK *)

        NetAfter(OriginalCode);

        (*  Send Event to shell: *)
        IF (OriginalCode.EventCode = AlternateDisplayKey) THEN
            NetworkDone:= TRUE;
            RETURN;
        END;

        IF RecalcMatrixFirst IN PostKeystrokeDrawing THEN
            RETURN;
        END;

    END;

END MainLoop;



PROCEDURE SetupRegionList();
VAR
    XMid            : ascreenx;
    YMid            : ascreeny;

BEGIN
    RegionList := CreateCorrelationList();
    SetRegion (RegionList, InContent, ULX, ULY, NetXMax, NetYMax);
    YMid := ULY + (NetYMax - ULY) DIV 2;
    SetRegion (RegionList, InPageUp, NetXMax+1, ULY, NetXMax+1, YMid);
    SetRegion (RegionList, InPageDown, NetXMax+1, YMid+1, NetXMax+1, NetYMax);
    XMid := ULX + (NetXMax - ULX) DIV 2;
    SetRegion (RegionList, InPageLeft, ULX, NetYMax+1, XMid, NetYMax+1);
    SetRegion (RegionList, InPageRight, XMid+1, NetYMax+1, NetXMax+1, NetYMax+1);
    SetRegion (RegionList, InMenuArea, 0, 0, maxcol, 2 );      (* 29-Dec-89 *)
    PutHScrollBar (ULX+1, NetYMax+1, NetXMax, FALSE, FALSE);
    PutVScrollBar (NetXMax+1, ULY, NetYMax);
END SetupRegionList;



(*--------------------------------------------------------------------------*)
        (*
            NetDrawMain

            Main program for the network diagram view.
        *)

PROCEDURE NetDrawMain();

BEGIN

    SaveTaskStatDisplayProc := DisplayTaskStats;  (* 13-Jul-89 CMH *)
    DisplayTaskStats := NoGanttStatusBanner;
    IF EnoughMemory THEN
       CurrentRow:= 0;
       CurrentCol:= 0;
       Initialized := FALSE;
       RegisterForNotices(AllOccasions,NetReceiveNotices);
       InstallNewProcedure(ADR(CurrentLayoutProc),
                           ChooseTheLayout,
                           ADR(SaveCurrentLayoutProc));
       IF (MousePresent()) THEN                                (* 29-Dec-89 *)
           SetupRegionList();
       END;

       ShowNet();
       MainLoop();

       DisposeCorrelationList (RegionList);

            (* Are we leaving?  Then try to save the current data. *)

        IF (NetworkDone) THEN
            IF (ViewType = NetworkView) THEN
                IF (SaveNetData()) THEN          (* 11/2/89 EGK *)
                END;
            END;
        END;

       DeallocForRecalc:=FALSE;
       IF RecalcMatrixFirst IN PostKeystrokeDrawing THEN
          DeallocForRecalc:= TRUE;
       END;
    END;
    DisplayTaskStats := SaveTaskStatDisplayProc;   (* 13-Jul-89 CMH *)

END NetDrawMain;


(*--------------------------------------------------------------------------*)


BEGIN                       (* NetDraw *)

    EffectiveOnMenuCode:= 0;
    requesting:= FALSE;
    RegionList := ACorrelationList(NIL);
    ClearMessage();

END NetDraw.



