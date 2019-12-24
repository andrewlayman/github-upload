IMPLEMENTATION MODULE Tran2;


(*  =========================================================================
    Last Edit : January 29, 1991 3:06PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

    04/25/86 LAA    Changed the project description lines to AText, of very
                    large size.
    05/01/86 LAA    Added code to erase the Clipboard whenever a project is
                    erased.  Clipboard if found using Holder.
    07/30/86 LAA    Removed usage of HotLinkedProjectName.
    11/04/86 LAA    ChartState is now a set, so use UnSetState to make it
                    empty.
    12/02/86 LAA    Call DisplayScheduleLight after blanking the project name.
                    In EraseAll, call DeallocateStorage instead of OpenFile
                    to release the stored messages.
    01/07/87 LAA    Added code to EraseAll to erase the memos, and removed 
                    code which erases the Clipboard.  Also erased filters.
    30-Mar-87 LAA   Removed references to TextLines (no longer used).
    5/6/87  EGK     Changed way in which filters are deleted;  now calls the
                    ForAll method for the filter list object to delete the
                    filters.
    5/19/87 EGK     Modifications to support changes to Resource and Memo
                    modules.
    20-May-87 LAA   Deleting all tasks now goes through the TaskTree.
    21-May-87 LAA   Changed the location of ResetChart in EraseAll.  It must
                    be called after the tasks are removed from the tree in 
                    order to work correctly.
    29-May-87 LAA   Fixed bug in RemoveTheTask.
    04-Jun-87 LAA   Changed parameters to TraverseTree and ForAll.
    29-Jun-87 AJL   Added notices.
    01-Jul-87 LAA   Added call to DisplayTheChart to EraseAll to be sure the
                    blank chart is displayed.
    07-Aug-87 EGK   Added code to erase all named layouts and reset the
                    CurrentChartFormat to NIL.
    30-Sep-87 EGK   Call FlushUndos as part of the schedule/erase action.
     6-Oct-87 RSC   Change UnSetState(Scheduled) to SetState(Scheduled).
    20-Oct-87 RSC   Added a "Please wait" box.
    27-Oct-87 LAA   Set ScheduleEndDate to zero in EraseAll so the end date
                    light goes off.
    11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
    10-Feb-88 EGK   Erase network layouts as part of schedule erase.
    17-Feb-88 LAA   Instead of calling HeapAvailable to update the SpaceLight,
                    call DisplaySpaceLight.  Also import DEALLOCATE from
                    Space instead of Storage.
    07-Mar-88 LAA   Purge all purgable memory whenever you erase the schedule.
    16-Sep-88 WKH   EraseAll now no longer sets AsOfDate to Today
     5-Jan-89 RSC   Moved Actions into Keys.
    07-Apr-89 WKH   EraseAll now unlocks the current schedule.
    04-Jun-89 WKH   Moved the unlock call higher up so that schedule name
                    is blanked out AFTER we unlock the schedule(OOOPS!!).
     4-Jun-89 EGK   Put in call to SendNotices before erasing schedule,
                    since Permission doesn't do it automatically any more.
    06-Jun-89 AJL   Move filters to FlexStor.
    06-Jul-89 LAA   Remove all the non-standard Palettes when the schedule is
                    erased.
    15-Jul-89 RSC   Remove reference to "DeallocateStorage" from MsgFile.
     1-Sep-89 RSC   Add call to "DeleteAllForeignSubfiles".
    21-Sep-89 WKH   Set WarnBeforeManualChange and SortOrderManuallyAltered
                    to FALSE when we erase a schedule.
    25-Sep-89 EGK   Import DiscardNetLayout from NetLUtility instead of
                    NetLayouts.
    28-Sep-89 RSC   Reset ScheduleComputedOk, so CALC ERR goes away on
                    a schedule erase.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
    05-Jun-90 AJL   Add Revision number.
    15-Nov-90 AJL   Added ResetPlannerDefaults.
    29-Jan-91 RSC   Changed Message to PutString.
    11-Apr-91 AJL   Use Thermometers.
    =========================================================================
*)



FROM Allocs                 IMPORT  RemoveTask, ATaskPtr, TaskTree,
                                    QueryNumberOfTasks;

FROM AsOf                   IMPORT  AsOfDate;

(*+3<*)
FROM Changer                IMPORT  InitializeChanger;
(*+3>*)

FROM Chart                  IMPORT  MChToday, ResetChart;

FROM ChartControl           IMPORT  AChartState, DisplayTheChart,
                                    SetState, ChartState;

FROM ChartForms             IMPORT
    (* TYPE *)                  AChartFormatPtr,
    (* VAR  *)                  LayoutTree,
    (* PROC *)                  DiscardLayout;

FROM Codes                  IMPORT  ACode;

FROM Dialog                 IMPORT
     (* TYPE *)                 ABoxHandle,
     (* PROCS *)                ProgressBox, ReleaseBox, Message,
                                FatalError, Error;

FROM Dispatcher             IMPORT  Dispatch;

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterRecordPointer,
    (* VAR  *)                  FilterTree, RevealFilter, HighlightFilter,
    (* PROC *)                  DeleteFilter;

FROM Filters                IMPORT  ResetFilters;

FROM ForeignSubfiles        IMPORT
    (* TYPE *)                  AFileType,
    (* PROC *)                  DeleteAllForeignSubfiles;

FROM Holder                 IMPORT  AHoldType, ForAllHeldItems, LocateHeldItem,
                                    DeleteHeldItem, AHoldTypeSet;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSColorAssignment, ATLGSColorAssignmentPtr,
                                ATLGSChartType,
    (* VAR *)                   PaletteTree;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode,
    (* PROC *)                  PutString;

FROM Keys                   IMPORT  ResetProgram; (* From Actions before 1/5/89.  RSC. *)

FROM LStrings               IMPORT  SetString, ConcatLS, ConcatS,
                                    Insert, SubStr, Fill, Copy, Procustes;

FROM Memos                  IMPORT
    (* VAR *)                   MemoTree,
    (* PROC *)                  DiscardMemo;

FROM Menus                  IMPORT  NoYes;

FROM MsgFile                IMPORT  DisplayMessage, GetMessage;

FROM NetLayouts             IMPORT
    (* TYPE *)                  ANetworkLayout,
    (* VAR *)                   NetLayoutTree;

FROM NetLUtility            IMPORT
    (* PROC *)                  DiscardNetLayout;

FROM Notices      IMPORT
    (* TYPE *)            AnOccasion, AStep,
    (* PROC *)            Permission, SendNotices;

FROM ObjectID               IMPORT
    (* PROC *)                  InitializeIDs;

FROM Palettes               IMPORT
    (* PROC *)                  DiscardPalette;

FROM Planner                IMPORT
    (* VAR *)                   ScheduleEndDate, ScheduleComputedOk,
    (* PROC *)                  ResetPlannerDefaults;

(*+3<*)
FROM PrintStatic            IMPORT  PrintDiskFileName;
(*+3>*)

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;

FROM RsrcMod                IMPORT  AResourcePointer, DeleteResource,
                                    ResourceTree,
                                    QueryNumberOfResources;

FROM Schedule               IMPORT  AScheduleLockClass, ScheduleSaved, 
                                    Loaded, ProjectName, RevisionNumber,
                                    ProjectMedia, SortOrderManuallyAltered,
                                    ProjectText, WarnBeforeManualChange,
                                    PlannedProjectName,
                                    Author, FullScheduleName, DisplayScheduleLight,
                                    UnLockSchedule;

FROM Space                  IMPORT  DisplaySpaceLight, DEALLOCATE;

FROM SYSTEM                 IMPORT  
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR;

FROM Text                   IMPORT
    (* PROC *)                  DiscardText;

FROM Timei                  IMPORT
    (* CONST*)                  MinDate,
    (* VAR *)                   Today,
    (* PROC *)                  FindToday;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder, ATree;

FROM Undo                   IMPORT
    (* PROC *)                  FlushUndos;




CONST
    ModuleNumber = 3300; (* For GetMessage *)

VAR
    Thermometer : AThermometer;


PROCEDURE QuickMessage( VAR s : ARRAY OF CHAR );
VAR
    s1  : ARRAY [0..81] OF CHAR;
BEGIN
    Copy(s,s1);
    Procustes(s1,79);
    PutString(s1,0,0,videonormal);
END QuickMessage;



PROCEDURE RemoveTheTask(VAR TreeNode        : ATreeNode;          (* 20-May-87 LAA *)
                            Context         : ADDRESS  );         (* 04-Jun-87 LAA *)

VAR
    Task                    : ATaskPtr;
    Count                   : POINTER TO CARDINAL;
BEGIN                       (* RemoveTheTask *)

    Task := TreeNode^.Methods^.LockFlexStorDataObject(TreeNode);
    TreeNode^.Methods^.UnlockUnchangedDataObject(TreeNode);       (* 11-Jan-88 LAA *)

    RemoveTask(TreeNode);

    Count := Context;
    INC(Count^);
    IF (Count^ MOD 8) = 0 THEN
        UpdateThermometer(Thermometer,Count^);
    END;

END RemoveTheTask;






PROCEDURE DeleteTransients ( Name     : ARRAY OF CHAR;
                             Class    : CARDINAL;
                             Category : AHoldTypeSet;
                             Where    : ADDRESS;
                             Size     : CARDINAL );
BEGIN
    IF (HoldTransiently IN Category) THEN
        DeleteHeldItem(Name,Class);
    END;
END DeleteTransients;



PROCEDURE DoResourceDelete (VAR Node: ATreeNode;
                                Context     : ADDRESS);           (* 04-Jun-87 LAA *)

VAR
    Resource: AResourcePointer;
    Count                   : POINTER TO CARDINAL;
BEGIN
    Resource := Node^.Methods^.GetDataObject (Node);
    DeleteResource (Node);

    Count := Context;
    INC(Count^);
    UpdateThermometer(Thermometer,Count^);

END DoResourceDelete;



PROCEDURE DoDeleteFilter(VAR FilterNode     : ATreeNode;
                             Context        : ADDRESS  );
VAR
    FilterPtr           : AFilterRecordPointer;
    Permanent           : BOOLEAN; 

BEGIN                       (* DoDeleteFilter *)

    FilterPtr := FilterNode^.Methods^.LockFlexStorDataObject (FilterNode);
    Permanent := 0 IN FilterPtr^.FilterFlags;
    FilterNode^.Methods^.UnlockUnchangedDataObject (FilterNode);
    IF NOT (Permanent) THEN
        DeleteFilter(FilterNode);
    END;

END DoDeleteFilter;



PROCEDURE DoDiscardMemo(VAR MemoNode        : ATreeNode;
                            Context         : ADDRESS  );

BEGIN                       (* DoDiscardMemo *)

    DiscardMemo(MemoNode);

END DoDiscardMemo;



PROCEDURE DoDiscardLayout (VAR Layout           : ATreeNode;
                               Context          : ADDRESS   );
VAR
    LayoutPtr           : AChartFormatPtr;
BEGIN

(*  Don't delete if it's one of the standard layouts    *)

    LayoutPtr := Layout^.Methods^.GetDataObject (Layout);
    IF NOT (0 IN LayoutPtr^.LayoutFlags) THEN
        DiscardLayout (Layout);
    END;

END DoDiscardLayout;






PROCEDURE DoDiscardNetLayout (VAR Layout           : ATreeNode;
                                  Context          : ADDRESS   );
VAR
    LayoutPtr           : ANetworkLayout;
BEGIN

(*  Don't delete if it's one of the standard layouts    *)

    LayoutPtr := Layout^.Methods^.GetDataObject (Layout);
    IF NOT (0 IN LayoutPtr^.NetLFlags) THEN
        DiscardNetLayout (Layout);
    END;

END DoDiscardNetLayout;



PROCEDURE DoDiscardPalette(VAR PaletteNode  : ATreeNode;
                               Context      : ADDRESS  );

VAR
    Palette                 : ATLGSColorAssignmentPtr;
    Standard                : BOOLEAN;

BEGIN                       (* DoDiscardPalette *)

    (*  Don't delete if it's one of the standard palettes  *)

    Palette := PaletteNode^.Methods^.LockFlexStorDataObject(PaletteNode);
    Standard := (0 IN Palette^.PaletteFlags);
    PaletteNode^.Methods^.UnlockUnchangedDataObject(PaletteNode);

    IF (NOT Standard) THEN
        DiscardPalette(PaletteNode);
    END;

END DoDiscardPalette;


PROCEDURE EnoughFree() : BOOLEAN;

BEGIN                       (* EnoughFree *)

    RETURN FALSE;  (* We can NEVER get enough memory! *)

END EnoughFree;




    (*  EraseAll  --  Erase the project from memory.  *)


PROCEDURE EraseAll;
VAR
    i                       : CARDINAL;
    Tree                    : ATree;
    Code                    : ACode;
    BoxHandle               : ABoxHandle;
    category                : AHoldTypeSet;
    ChartKind               : ATLGSChartType;
    Count                   : CARDINAL;
    ok                      : BOOLEAN;
    s                       : ARRAY [0..99] OF CHAR;

BEGIN
    IF (NOT Permission(ModelErase,NIL)) THEN
        RETURN;
    END;

    SendNotices(ModelErase,BeforeActing,NIL);        (* 6/4/89 EGK *)

    GetMessage(ModuleNumber + 3, s ); (* "Please wait one moment" *)
    BoxHandle := ProgressBox( s );

    s[0] := 0C;
    Message(s);

    ResetFilters;
    Dispatch(ResetProgram);
    FlushUndos();

        (* Prepare to display progress. *)
    GetMessage(ModuleNumber+4,s);
    IF (NOT CreateThermometer(Thermometer,0,0,s,QueryNumberOfTasks())) THEN
        Thermometer := AThermometer(NIL);
    END;
    Count := 0;


    TaskTree^.Methods^.                                           (* 04-Jun-87 LAA *)
            TraverseTree(TaskTree, ParentAfterChild, 999, RemoveTheTask, ADR(Count));  

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    ResetChart;                                                   (* 21-May-87 LAA *)

    (*+3<*)
    InitializeChanger;
    (*+3>*)
 
        (* Prepare to display progress. *)
    GetMessage(ModuleNumber+4,s);
    IF (NOT CreateThermometer(Thermometer,0,0,s,QueryNumberOfResources())) THEN
        Thermometer := AThermometer(NIL);
    END;
    Count := 0;

    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentAfterChild,
            9999, DoResourceDelete, ADR(Count));     (* 04-Jun-87 *)

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    (*+3<*)
    PrintDiskFileName[0] := 0C;
    (*+3>*)

    FilterTree^.Methods^.TraverseTree (FilterTree, ParentAfterChild, 9999,
            DoDeleteFilter, NIL);               (* 04-Jun-87 LAA *)

    RevealFilter := NIL;
    FOR i := 1 TO 5 DO
        HighlightFilter[i] := NIL;
    END;


    MemoTree^.Methods^.TraverseTree (MemoTree, ParentAfterChild, 9999,
            DoDiscardMemo, NIL);                (* 04-Jun-87 LAA *)

    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentBeforeChild, 9999,
            DoDiscardLayout, NIL);

    NetLayoutTree^.Methods^.TraverseTree (NetLayoutTree, ParentBeforeChild,
            9999, DoDiscardNetLayout, NIL);

    FOR ChartKind := TLGSGanttChart TO TLGSTreeChart DO           (* 06-Jul-89 LAA *)
        Tree := PaletteTree[ChartKind];
        Tree^.Methods^.TraverseTree(Tree, ParentBeforeChild, 9999,
                                    DoDiscardPalette, NIL);
    END;

    ForAllHeldItems( DeleteTransients );

    DeleteAllForeignSubfiles( ScheduleFile );  (* RSC 1-Sep-89 *)

    UnLockSchedule(DualLock);    (* WKH 4/7/89 *) (* WKH 6/4/89 *)

    ProjectName[0] := 0C;
    DisplayScheduleLight();                                        (* 12/02/86 LAA *)
    DiscardText(ProjectText);
    Author[0]                := 0C;
    FullScheduleName[0]      := 0C;
    ScheduleSaved            := TRUE;
    PlannedProjectName[0]    := 0C;
    Loaded                   := FALSE;
    RevisionNumber           := 0;
    Today                    := FindToday();
    WarnBeforeManualChange   := FALSE;  (* 21-Sep-89 WKH  *)
    SortOrderManuallyAltered := FALSE;

    ResetPlannerDefaults();

    MChToday;

    DisplaySpaceLight();                                          (* 17-Feb-88 LAA *)

    SendNotices(ModelErase,AfterActing,NIL);
    InitializeIDs (0);
    ScheduleEndDate := MinDate;                                         (* 27-Oct-87 LAA *)

    SetState(Scheduled); (* RSC 10/6/87 *)
    ScheduleComputedOk := TRUE; (* Remove any CALC ERRs.  28-Sep-89 RSC *)

    DisplayMessage( ModuleNumber + 1 ); (* "Schedule erased." *)
    ReleaseBox( BoxHandle );

    SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));     (* 07-Mar-88 LAA *)
    DisplayTheChart();       (* Moved here 1/4/88 by RSC to be AFTER box rug is restored *)

END EraseAll;




END Tran2.
